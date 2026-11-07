--[[
  Commandant de faction : boucle stratégique, une pensée par faction toutes les think_period ticks
  (voie "fo-commander" de l'ordonnanceur, donc étalée sur les ticks).

  Session 4 (économie réelle) : une pensée = (1) entretien des groupes armés, (2) CERVEAU D'ÉQUIPE
  (script/team/team.lua : objectif, tâches des ouvriers, recrutement, équipement des soldats, recherche, le
  tout payé avec les objets du stock), (3) décision d'attaque (shared/faction/strategy.lua, pure).

  Lot IA0 : la décision d'attaque passe par script/faction/pvp.lua (S.decide) : le joueur peut être pris
  pour cible selon le niveau de difficulté ; en « Paisible », la décision est celle d'avant IA0.
]]

local Events = require("script.core.events")
local Scheduler = require("script.core.scheduler")
local Profiler = require("script.core.profiler")
local F = require("shared.faction.config")
local S = require("shared.faction.strategy")
local State = require("script.faction.state")
local Sites = require("script.faction.sites")
local Military = require("script.faction.military")
local Outposts = require("script.faction.outposts")
local Team = require("script.team.team")
local PvP = require("script.faction.pvp")
local Character = require("script.faction.character")
local Chef = require("script.faction.chef")
local Veille = require("script.faction.veille") -- lot VEILLE : bilans de la reconnaissance régulière (mission : script/ai3/exploration.lua)
local Cd = require("shared.faction.cadence") -- lot X10-S10 : factions lointaines et calmes plus lentes (règle pure)
local DefChoix = require("script.faction.defchoix") -- lot X10-S10 : ennemi près du QG (lu au créneau)

local Commander = {}

Commander.LANE = "fo-commander"

local THREAT_TICKS = require("shared.team.defchoix").THREAT_TICKS -- lot DEFENSE-CHOIX : 900, une seule source (Dc.base relit l'alerte)
local THREAT_RADIUS = 90

local function surface_of(war) return game.surfaces[war.surface] end

--- Rival : prochaine faction vivante ET atteignable dans le cycle (voisin désigné).
local function rival_of(f, tick)
  local alive = State.alive()
  local n = #alive
  if n < 2 then return nil end
  local start = 1
  for i, id in ipairs(alive) do
    if id == f.id then start = i break end
  end
  for k = 1, n - 1 do
    local id = alive[(start - 1 + k) % n + 1]
    if not Military.target_unreachable(f, id, tick) then return id end
  end
  return nil
end

local function pick_target(f, tick)
  local others = {}
  for _, id in ipairs(State.alive()) do
    if id ~= f.id and not Military.target_unreachable(f, id, tick) then
      others[#others + 1] = { id = id, outposts = State.faction(id).outposts_count }
    end
  end
  local rival = rival_of(f, tick)
  if not rival then return nil end
  return State.faction(F.pick_target(f.outposts_count, rival, others))
end

local function enemy_defense(t)
  local garrison = Military.garrison_strength(t, S.soldier_strength)
  local turrets = 0
  for _, tt in pairs(t.turrets) do if tt.valid then turrets = turrets + 1 end end
  if t.outposts_count > 0 then
    return 8 * math.min(turrets, 2 * t.outposts_count) / math.max(1, t.outposts_count) + 0.3 * garrison
  end
  return 8 * turrets + garrison
end

function Commander.view(f, tick)
  -- Lot IA2-a : la rivale visée est celle du CHEF (valeur ÷ défense estimée sous brouillard, rancune, ouverture,
  -- mémoire) et sa défense est celle qu'il a VUE (script/faction/chef.lua) ; sans chef (avant sa première pensée),
  -- règle d'avant (coalition contre le leader, sinon voisin ; défense lue directement).
  local target = Chef.target(f, tick)
  local defense = target and Chef.defense(f, target.id)
  -- Lot IA2-a2 : TRÊVE du chef (toutes les rivales atteignables épargnées par satiété) : la rivale reste désignée
  -- (vue PvP inchangée) ; S.attack et S.raid lisent `chef.hold` (Chef.decision_fields).
  if not target then target = pick_target(f, tick) end
  if target and not defense then defense = enemy_defense(target) end
  -- Lot IA2-0 : caractère tiré de la graine (traits bornés à l'enveloppe des archétypes) et seuil de la prochaine
  -- attaque entre factions (±20 %). Partie existante : traits tirés ici à la première pensée (Character.of).
  local character = Character.of(f)
  return {
    tech = f.tech, personality = f.personality, upgrades = f.upgrades,
    character = character, attack_jitter = f.attack_jitter,
    -- Lot PNJ-VÉRIF (M4) : seuls les soldats proches du rassemblement (ceux qu'une attaque peut emmener).
    garrison = Military.garrison_near(f), soldiers_max = State.war().settings.soldiers_max,
    can_attack = tick >= (f.attack_block_until or 0) and not f.route_pending,
    enemy_defense = target and defense or math.huge,
    chef = Chef.decision_fields(f, target, tick), -- lot IA2-a : multiplicateur du seuil, raid (nil sans chef)
  }, target
end

---------------------------------------------------------------------------------------------------
-- Lot X10-S10 : cadence des factions lointaines et calmes (shared/faction/cadence.lua ; décision du DC du 7/11, 17 h 47)
---------------------------------------------------------------------------------------------------
-- Une faction loin de tout joueur et sans menace SAUTE son créneau tant que sa dernière pensée date de moins de Cd.SLOW ticks
-- (une pensée sur deux à la période de 300) ; endormie (créneau sauté), elle est guettée à chaque tick et repense AU TICK SUIVANT dès
-- qu'une cause la réveille (joueur proche, menace, attaque, perte). Les étapes E1 à E4 de sa pensée ne changent pas (Team.think).
-- État : f.cadence = { last, asleep, box, base_alert, mode, logs } (nombres, chaînes, booléens, une table de 4 nombres).
Commander.CADENCE = true          -- faux : la cadence d'avant (une pensée par créneau), banc témoin
Commander.CADENCE_LOGS = 20       -- lignes [FO-CADENCE] au plus par faction

local function cadence_of(f)
  local cs = f.cadence
  if not cs then
    cs = { logs = 0 }
    f.cadence = cs
  end
  return cs
end

--- Entrée de la règle : joueurs connectés de la surface de la guerre (ordre du moteur), zone et alertes de la faction.
local function cadence_input(f, tick)
  local war = State.war()
  local players = {}
  for _, p in ipairs(game.connected_players) do
    if p.valid and p.surface and p.surface.index == war.surface then
      local pos = p.position
      players[#players + 1] = { x = pos.x, y = pos.y }
    end
  end
  local cs = cadence_of(f)
  return { is_player = f.is_player, box = cs.box, players = players, threatened_until = f.threatened_until,
    attack_t = f.attack_alert_t, lost_t = f.lost_t, base_alert = cs.base_alert }
end

--- Zone de la faction (QG et avant-postes, triés par clé) : relue à chaque pensée jouée.
local function cadence_zone(f)
  local pts = {}
  if f.hq_pos then pts[1] = { x = f.hq_pos.x, y = f.hq_pos.y } end
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if o and o.pos then pts[#pts + 1] = { x = o.pos.x, y = o.pos.y } end
  end
  return Cd.zone(pts, Cd.NEAR)
end

local function cadence_say(f, cs, mode, why, tick)
  if cs.mode == mode then return end
  cs.mode = mode
  cs.logs = (cs.logs or 0) + 1
  if cs.logs > Commander.CADENCE_LOGS then return end
  log(string.format("[FO-CADENCE] %s : cadence %s (%s) a %.1f min", tostring(f.key), mode == "lente" and ("LENTE, une pensee toutes les " .. Cd.SLOW .. " ticks") or "NORMALE",
    tostring(why), tick / 3600))
end

function Commander.think(id, tick)
  local war = State.war()
  local f = war.factions[id]
  if not war.active or not f or f.eliminated then
    Scheduler.remove(Commander.LANE, id)
    return
  end
  if not (f.hq and f.hq.valid) then return end -- l'élimination est traitée par l'événement de destruction
  if not Scheduler.has(Sites.LANE, id) then Sites.track(f) end
  local surface = surface_of(war)
  -- Lot X10-S10 : au créneau, l'ennemi près du QG est relu (DefChoix.base, compte limité à 1) ; une faction lointaine et calme saute la pensée.
  if Commander.CADENCE then
    local cs = cadence_of(f)
    if cs.last == tick then return end -- déjà pensé à ce tick (réveil et créneau au même tick)
    cs.base_alert = DefChoix.base(f, surface, tick).insecure or nil
    local skip, why = Cd.skip(cs, cadence_input(f, tick), tick)
    if skip then
      cs.asleep = true
      cadence_say(f, cs, "lente", why, tick)
      return
    end
    cs.asleep, cs.last = false, tick
    if why ~= "loin et calme" and why ~= "premiere pensee" then cadence_say(f, cs, "normale", why, tick) end
    cs.box = cadence_zone(f)
  end
  Profiler.start("faction:think")
  f.last_think = tick
  Profiler.start("faction:maintain")
  Military.maintain(f, tick)
  Profiler.stop("faction:maintain")
  Profiler.start("faction:team")
  -- Lot DÉCOUPAGE-PENSÉE : la pensée d'équipe se joue en 4 étapes (T à T + 3) ; la queue (chef, veille, attaque) suit sa
  -- dernière étape, dans le même ordre qu'avant. Team.think rend false quand ses étapes restent à jouer.
  local done = Team.think(f, surface, tick, "commander")
  Profiler.stop("faction:team")
  if done ~= false then Commander.tail(f, surface, tick) end
  Profiler.stop("faction:think")
end

--- Fin de la pensée d'une faction, après sa pensée d'équipe (lot DÉCOUPAGE-PENSÉE : jouée par la dernière étape, à T + 3).
function Commander.tail(f, surface, tick)
  Chef.think(f, tick) -- lot IA2-a : une pensée par minute (rien avant l'échéance)
  Veille.report(f, tick) -- lot VEILLE : une ligne de bilan toutes les 10 min par faction
  Profiler.start("faction:attack")
  local view, target = Commander.view(f, tick)
  PvP.think(f, surface, tick, view, target)
  Profiler.stop("faction:attack")
end
Team.define_tail("commander", function(f, tick) Commander.tail(f, surface_of(State.war()), tick) end)

Scheduler.define_lane(Commander.LANE, function()
  local s = State.war().settings
  return (s and s.think_period) or F.defaults.think_period
end, Commander.think)

---------------------------------------------------------------------------------------------------
-- Lot ÉTALEMENT (5/11) : pensées des factions ESPACÉES sur la période
---------------------------------------------------------------------------------------------------
-- Le DC (5/11, 21 h 55) : « des freezes [...] d'une demi-seconde [...] très périodique [...] c'est vraiment que le mode ». MESURÉ par
-- perf3 sur sa partie (0.6.53) : les 4 pensées de faction tombaient à 4 ticks CONSÉCUTIFS (créneaux tournants de Scheduler.add, phases
-- 0 à 3 modulo 300), 55 ms chacune en début de partie, 124 ms à 175 min : un bloc de 0,22 à 0,5 s toutes les 300 ticks, soit toutes
-- les 0,5 s à ×10. La faction de rang k (0 à n - 1) pense désormais à la phase floor(k × P / n) + PHASE0 (7, 82, 157, 232 pour 4) :
-- un pic par faction, séparés de P / n ticks. PHASE0 = 7, comme la phase 174 de votre équipe (PERF3, script/team/player_team.lua) :
-- hors des multiples de 5 (build:pulse, toutes les équipes), de 15, et des restes 0 à 3 de 30 (prospection) ; 157 et 232 restent
-- à 17 et 58 ticks de 174. Décisions : même règle, autre horaire (accepté par le lead, déterministe : la place ne dépend que du rang
-- de la faction et de la période).
Commander.PHASE0 = 7

--- Créneau (1..P) de la faction de rang `i` (1..n) sur une période de `P` ticks.
function Commander.slot_for(i, n, P)
  return (math.floor((i - 1) * P / n) + Commander.PHASE0) % P + 1
end

--- Place chaque faction de la guerre à son créneau espacé (appelé au lancement de la guerre, et au chargement d'une partie qui les
--- avait à la suite : migration). Sans effet pour une faction déjà à sa place.
function Commander.spread()
  local war = State.war()
  local list = war and war.factions
  if not (list and #list > 0) then return 0 end
  local n = #list
  local P = Scheduler.period(Commander.LANE)
  local moved = 0
  for i = 1, n do
    if Scheduler.has(Commander.LANE, i) then
      local s = Commander.slot_for(i, n, P)
      if Scheduler.slot(Commander.LANE, i) ~= s then
        Scheduler.add_at(Commander.LANE, i, s)
        moved = moved + 1
      end
    end
  end
  return moved
end

-- Lot X10-S10 : guet des factions endormies, à chaque tick : au premier tick où une cause la réveille (le joueur entré dans sa zone, une
-- attaque, une perte), la faction repense TOUT DE SUITE (Commander.think, puis ses étapes E2 à E4 aux ticks suivants, comme d'habitude).
-- Aucune faction endormie : une boucle sur la liste des factions, sans lecture du moteur.
Events.on_nth_tick(1, function(e)
  if not Commander.CADENCE then return end
  local war = State.war()
  if not (war and war.active and war.factions) then return end
  for id, f in ipairs(war.factions) do
    local cs = f.cadence
    if cs and cs.asleep and not f.eliminated then
      local up, why = Cd.wake(cs, cadence_input(f, e.tick), e.tick)
      if up then
        cadence_say(f, cs, "normale", why, e.tick)
        Commander.think(id, e.tick)
      end
    end
  end
end)

-- Migration : une partie d'avant ce lot a ses factions à des créneaux consécutifs ; elles sont replacées au chargement du mod changé.
Events.on_configuration_changed(function()
  local war = State.war()
  if not (war and war.active) then return end
  local moved = Commander.spread()
  if moved > 0 then
    log(string.format("[FO-ETALEMENT] pensees des factions replacees : %d faction(s) deplacee(s), phases (tick %% %d) : %s",
      moved, Scheduler.period(Commander.LANE), (function()
        local out = {}
        for i = 1, #war.factions do
          local s = Scheduler.slot(Commander.LANE, i)
          if s then out[#out + 1] = tostring(war.factions[i].key) .. " " .. tostring(s - 1) end
        end
        return table.concat(out, ", ")
      end)()))
  end
end)

---------------------------------------------------------------------------------------------------
-- Destructions et menaces
---------------------------------------------------------------------------------------------------
Commander.on_eliminated = nil -- branché par war.lua

Events.on(defines.events.on_entity_destroyed, function(e)
  local owner = State.owner(e.unit_number)
  if not owner then return end
  State.disown(e.unit_number)
  local f = State.faction(owner.f)
  if not f then return end
  if owner.kind == "soldier" then
    Military.on_soldier_lost(f, e.unit_number)
  elseif owner.kind == "drill" then
    Outposts.on_drill_lost(f, owner.oid)
  elseif owner.kind == "turret" then
    f.turrets[e.unit_number] = nil
  elseif owner.kind == "hq" and not f.eliminated then
    f.eliminated = true
    if Commander.on_eliminated then Commander.on_eliminated(f, e.tick) end
  end
end)

-- Une perte près du QG ou d'un avant-poste met la faction en alerte (défense prioritaire).
-- Lot MORTS : jamais la force « enemy » (seules les entités d'une force de faction comptent : State.by_force).
Events.on_died(function(e)
  local war = State.war()
  if not war.active then return end
  local entity = e.entity
  local f = State.by_force(entity.force.name)
  if not f or f.eliminated then return end
  f.lost_t = e.tick -- lot X10-S10 : une perte, où qu'elle soit, réveille une faction endormie (shared/faction/cadence.lua, « perte »)
  local p = entity.position
  local dx, dy = p.x - f.hq_pos.x, p.y - f.hq_pos.y
  if dx * dx + dy * dy < THREAT_RADIUS * THREAT_RADIUS then
    f.threatened_until = e.tick + THREAT_TICKS
  end
  -- Lot VEILLE : mort d'un soldat de faction (cause, lieu, distance au QG) : un journal qui date les effondrements de garnison (la base
  -- n'avait pas ce journal : RECON, Azure 271828182).
  if entity.unit_number and f.soldiers and f.soldiers[entity.unit_number] then
    f.stats.soldier_deaths = (f.stats.soldier_deaths or 0) + 1
    log(string.format("[FO-VEILLE] soldat mort tick %d %s : par %s (%s) en (%d, %d), a %d tuiles du QG", e.tick, f.key,
      e.cause and e.cause.valid and e.cause.name or "?", e.force and e.force.name or "?", math.floor(p.x), math.floor(p.y),
      math.floor(math.sqrt(dx * dx + dy * dy))))
  end
  if e.force and e.force.name == "player" and Commander.on_player_hostility then
    Commander.on_player_hostility(f, e.tick)
  end
end, { ennemi = false })

return Commander
