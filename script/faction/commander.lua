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
local Charge = require("script.core.charge") -- lot TV-VAPEUR (V89) : dégradation graduée, la cadence lente s'allonge sous charge
local Cd = require("shared.faction.cadence") -- lot X10-S10 : factions lointaines et calmes plus lentes (règle pure)
local BdRt = require("script.ai3.budget_defense") -- lot S42-DEFENSE : niveau de pertes recentes (part de la defense)
local DefChoix = require("script.faction.defchoix") -- lot X10-S10 : ennemi près du QG (lu au créneau)
local Storage = require("script.core.storage") -- lot X10-S10 : état des soldats de l'IA3 (nettoyage, expédition), lu sans le créer
local Ia3k = require("script.ai3.comportement") -- lot X10-S10 : clé de l'équipe dans cet état (Ia3k.team_key)

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
-- qu'une cause la réveille (joueur proche, menace, attaque, perte). Les étapes de sa pensée (Team.think, shared/team/etapes.lua) ne changent pas.
-- État : f.cadence = { last, asleep, box, base_alert, mode, logs } (nombres, chaînes, booléens, une table de 4 nombres).
Commander.CADENCE = true          -- faux : la cadence d'avant (une pensée par créneau), banc témoin
Commander.CADENCE_LOGS = 20       -- lignes [FO-CADENCE] au plus par faction
-- Lot LOURD (point 2 c ; filet proposé par revue-s, accord du lead du 8/11) : une pensée en cours depuis plus de Commander.FILET ticks
-- est tenue pour PERDUE (une étape sans minuteur vivant : aucun chemin connu, la borne d'une pensée est 103 ticks). Elle ne bloque
-- alors plus ni le créneau ni le réveil : Commander.think appelle Team.think, qui la rattrape d'un bloc.
Commander.FILET = 2 * Cd.SLOW

--- Lot LOURD (point 2 c) : vrai si une pensée de `f` est EN COURS (f.team.etape) depuis au plus Commander.FILET ticks (garde du créneau et
--- du réveil). Au-delà : faux (filet), et `say` écrit la ligne [FO-ETAPES] FILET (il ne devrait jamais servir ; s'il sert, il se voit).
function Commander.busy(f, tick, say)
  local et = f.team and f.team.etape
  if not et then return false end
  if tick - (et.t0 or tick) <= Commander.FILET then return true end
  if say then
    log(string.format("[FO-ETAPES] %s : FILET : pensee du tick %s encore en cours a l'etape %s au tick %d (plus de %d ticks : minuteur perdu ?) : garde levee, la pensee est rattrapee d'un bloc",
      tostring(f.key), tostring(et.t0), tostring(et.n), tick, Commander.FILET))
  end
  return false
end

local function cadence_of(f)
  local cs = f.cadence
  if not cs then
    cs = { logs = 0 }
    f.cadence = cs
  end
  return cs
end

--- Joueurs connectés de la surface d'index `surface_index` (ordre du moteur) : { {x, y}, ... }. Appels au moteur : 1 (la liste), puis
--- 2 par joueur connecté (surface_index, position). Le guet la lit UNE fois par tick pour toutes les factions (réserve de la revue).
function Commander.players_on(surface_index)
  local out = {}
  for _, p in ipairs(game.connected_players) do
    if p.surface_index == surface_index then
      local pos = p.position
      out[#out + 1] = { x = pos.x, y = pos.y }
    end
  end
  return out
end

--- Une force de la faction est-elle hors du QG, ou s'y prépare-t-elle ? (Cd.army_out : groupes armés, attaque préparée, opération de
--- nettoyage et expédition des soldats de l'IA3, armée de la prévision en alerte ou au regroupement.) Lecture seule, aucun appel au
--- moteur : l'état des soldats de l'IA3 n'est pas créé s'il manque. Rend (dehors, cause). Réutilisable (lot x10-gel).
function Commander.army_out(f)
  local ns = Storage.ns("ia3k")
  local t = ns and ns.teams and ns.teams[Ia3k.team_key(f)]
  local sd = t and t.sd
  return Cd.army_out({ groups = f.groups, route_pending = f.route_pending, nt = sd and sd.nt, clearing = sd and sd.clearing,
    armee = f.armee })
end

--- Entrée de la règle : joueurs `players` (Commander.players_on), zone et alertes de la faction, état de son armée.
local function cadence_input(f, players)
  local cs = cadence_of(f)
  local army_out, army_why = Commander.army_out(f)
  return { is_player = f.is_player, box = cs.box, players = players, threatened_until = f.threatened_until,
    attack_t = f.attack_alert_t, hit_t = f.hit_t, lost_t = f.lost_t, base_alert = cs.base_alert, army_out = army_out,
    army_why = army_why }
end

--- Cause écrite au journal : celle de la règle, et le détail de l'armée dehors.
local function cause_of(why, inp)
  if why == "armee dehors" and inp.army_why then return why .. " : " .. inp.army_why end
  return why
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

--- Pensée d'une faction : à son créneau (voie fo-commander, `woken` nil), ou réveillée par le guet (Commander.wake, `woken` vrai).
function Commander.think(id, tick, woken)
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
    -- Revue de 87ac84fe : un créneau qui tombe PENDANT les étapes de la pensée précédente (un réveil quelques ticks avant) est
    -- laissé, sans endormir la faction (sinon ces étapes se rejouent d'un bloc) ; seuil : l'écart des étapes (Cd.STEP_SPAN), pas la période.
    -- Lot LOURD (point 2 c ; garde accordée par le lead, remarque de video-l5) : une pensée EN COURS (étapes sous le jeton, décalées
    -- au-delà de T + Et.SPAN) : ni créneau ni réveil n'en commencent une autre (sinon Team.think rattraperait le reste d'un bloc).
    -- Posée AVANT le test « woken » : un réveil refusé ici laisse la faction endormie, le guet redemande au tick suivant.
    -- Filet (Commander.busy) : au-delà de Commander.FILET ticks, la garde se lève et le dit au journal.
    if Commander.busy(f, tick, true) then return end
    if not woken and Cd.recent(cs, tick) then return end
    local inp = cadence_input(f, Commander.players_on(war.surface))
    local skip, why = Cd.skip(cs, inp, tick, Charge.stretch(Cd.SLOW)) -- (lot TV-VAPEUR : Cd.SLOW sous charge nulle)
    if skip then
      cs.asleep = true
      cadence_say(f, cs, "lente", why, tick)
      return
    end
    cs.asleep, cs.last = false, tick
    if why ~= "loin et calme" and why ~= "premiere pensee" then cadence_say(f, cs, "normale", cause_of(why, inp), tick) end
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

--- Lot X10-S10 : RÉVEIL d'une faction endormie (rang `id` dans war.factions) pour la cause `cause`, au tick `tick`. SEUL point d'appel de
--- la pensée hors créneau : le lot S6 (jeton des travaux lourds, script/core/lourd.lua) le fera passer par son minuteur (Cd.skip décide
--- SI la faction pense, le jeton décide QUAND ; consigne du lead, 7/11).
--- Lot LOURD (point 2 c, 8/11 ; décision Q1 du lead) : le jeton des travaux lourds est pris par la PREMIÈRE ÉTAPE de la pensée (E1a,
--- Team.think, script/team/team.lua), pour le réveil comme pour le créneau : une seule prise par pensée (le point 2 b la prenait ici ;
--- retiré avec S10 de la 0.6.63, il n'est pas repris). Une pensée encore en cours (f.team.etape) laisse le réveil sans effet (garde de
--- Commander.think) : la faction reste endormie, le guet redemande au tick suivant (Cd.wake est un niveau). Filet : Commander.busy (le
--- journal FILET est écrit par Commander.think, une ligne par garde levée).
function Commander.wake(f, id, cause, tick)
  if Commander.busy(f, tick, false) then return end -- (pensée en cours : aucun journal « NORMALE » d'un réveil qui n'a pas lieu)
  cadence_say(f, cadence_of(f), "normale", cause, tick)
  Commander.think(id, tick, true)
end

--- Lot X10-S10 : GUET des factions endormies, joué à chaque tick : au premier tick où une cause la réveille (le joueur entré dans sa
--- zone, une attaque, un coup sur une tourelle, une perte, une armée sortie), Commander.wake. Aucune faction endormie : une boucle sur
--- la liste des factions, sans appel au moteur ; sinon les joueurs sont lus UNE fois pour toutes les factions de ce tick.
function Commander.guard(tick)
  if not Commander.CADENCE then return end
  local war = State.war()
  if not (war and war.active and war.factions) then return end
  local players = nil
  for id, f in ipairs(war.factions) do
    local cs = f.cadence
    if cs and cs.asleep and not f.eliminated then
      players = players or Commander.players_on(war.surface)
      local inp = cadence_input(f, players)
      local up, why = Cd.wake(cs, inp, tick)
      if up then Commander.wake(f, id, cause_of(why, inp), tick) end
    end
  end
end
Events.on_nth_tick(1, function(e) Commander.guard(e.tick) end)

-- Lot X10-S10 : lecture de la cadence par le mod de test (scénario s10-cadence ; aucune écriture).
remote.add_interface("fo-cadence", {
  --- Une entrée par faction, dans l'ordre de la guerre : { key, force, last (dernière pensée), asleep, mode, hq = { x, y } }.
  list = function()
    local war = State.war()
    local out = {}
    for _, f in ipairs((war and war.factions) or {}) do
      local cs = f.cadence
      out[#out + 1] = { key = f.key, force = f.force, last = f.last_think, asleep = (cs and cs.asleep) == true,
        mode = cs and cs.mode, hq = f.hq_pos and { x = f.hq_pos.x, y = f.hq_pos.y } or nil }
    end
    return out
  end,
})

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
  BdRt.note(f, entity, e.tick) -- lot S42-DEFENSE : la part de la defense suit les pertes recentes (shared/ai3/budget_defense.lua)
  f.lost_t = e.tick -- lot X10-S10 : une perte, où qu'elle soit, réveille une faction endormie (shared/faction/cadence.lua, « perte »)
  local p = entity.position
  local dx, dy = p.x - f.hq_pos.x, p.y - f.hq_pos.y
  if dx * dx + dy * dy < THREAT_RADIUS * THREAT_RADIUS then
    f.threatened_until = e.tick + THREAT_TICKS
    f.threat_loss_t = e.tick -- lot L12 (partie 3) : dernière perte près du QG, lue par la menace tenue (script/team/menace_equipe.lua)
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
