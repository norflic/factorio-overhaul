--[[
  PvP : les factions IA prennent le JOUEUR pour cible d'elles-mêmes, selon un niveau de difficulté
  (OBJECTIFS.md C4 ; réponse du Directeur Créatif à Q4, 21/10 18 h 07 : « oui (et différents niveaux de
  difficulté) »). Lot IA0.

  - Réglage de partie « fo-pvp-difficulty » (runtime-global, modifiable en cours de partie) :
    Paisible, Facile, Normal (défaut), Difficile, Impitoyable. Paramètres : shared/faction/config.lua.
  - Décision PURE (shared/faction/strategy.lua, S.decide) : délai de grâce, préavis, déclaration de
    guerre, cible (le joueur quand il est « dû », sinon la rivale), effectif. Ce module ne fait que
    construire la vue et appliquer les actions.
  - Repérage des installations du joueur à coût BORNÉ et ÉTALÉ : voie « fo-pvp-scan », 1 secteur de
    64 × 64 tuiles toutes les 8 ticks (un count_entities_filtered), sur un disque de 24 secteurs
    (1 536 tuiles) autour du point de départ du joueur, balayé en 4 min. Rien n'est compté en « Paisible ».
  - Cible : secteur repéré le plus proche du QG de la faction (le secteur de départ du joueur en dernier,
    comme un QG), installation réelle la plus proche, défense = 8 × tourelles à 40 tuiles.
  - Provocation : seule la destruction d'une entité de la faction SOUS cessez-le-feu en est une. En guerre
    ouverte, abattre un attaquant (tourelle, compagnon) est de la légitime défense : aucun effet.
  - Messages au joueur : préavis, déclaration de guerre, départ de chaque attaque (lien [gps]), trêve,
    changement de difficulté, hostilité héritée d'une sauvegarde plus ancienne. Lignes « [FO-PVP] » en
    clair dans le journal (bancs).

  LIMITES (documentées, non traitées) :
  - seule la force « player » est visée et repérée : en multijoueur avec plusieurs forces de joueurs
    (équipes), les autres forces ne sont jamais attaquées et leur cessez-le-feu n'est pas géré ;
  - une installation au-delà du disque de repérage (1 536 tuiles du point de départ) n'est jamais ciblée.

  Lot IA0b (base défendue) : la décision pure assiège (« siege » : la faction garde ses soldats pour le
  joueur), se dit dissuadée (« deterred ») ou se joint à un assaut coordonné (« join », Difficile et
  Impitoyable). Ce module tient la fenêtre d'assaut coordonné (war.pvp.rally_until, ouverte par une attaque
  prête contre le joueur, et war.pvp.rally_target : position et défense estimée de la cible de cette
  attaque, CIBLE COMMUNE des attaques jointes), marque les attaques jointes, retient la dernière attaque
  contre une faction (f.pvp.last_rival : fin de l'impasse de la règle du déficit) et journalise chaque
  entrée en siège ou en dissuasion (« [FO-PVP] siege », « [FO-PVP] dissuasion »). Aucun calcul par tick :
  tout se fait dans la pensée du commandant.

  État persistant : war.pvp (niveau, ancre de la grâce, secteurs repérés, curseur, pertes du joueur, fenêtre
  d'assaut coordonné et sa cible), f.pvp par faction (déclarée, provoquée, héritée, préavis, fin de grâce au
  plus tôt, dernière attaque contre le joueur et sa cible, dernière attaque contre une faction, soldats
  envoyés, plan en cours, sièges, attaques jointes), war.pvp_forced (niveau imposé par l'interface distante,
  bancs seulement). Aucune fonction dans global. Sauvegarde antérieure : champs absents lus comme nil ou 0.
]]

local Events = require("script.core.events")
local Scheduler = require("script.core.scheduler")
local Profiler = require("script.core.profiler")
local F = require("shared.faction.config")
local S = require("shared.faction.strategy")
local State = require("script.faction.state")
local Military = require("script.faction.military")
local Character = require("script.faction.character")

local PvP = {}

PvP.SETTING = "fo-pvp-difficulty"
PvP.SCAN_LANE = "fo-pvp-scan"

local R = F.pvp_rules

-- Installations du joueur qui comptent comme cibles (production, énergie, défense, stockage). Les
-- convoyeurs, bras, poteaux, tuyaux et murs n'en sont pas : ils n'indiquent pas une base.
local INSTALL_TYPES = {
  "assembling-machine", "furnace", "mining-drill", "lab", "boiler", "generator", "reactor", "solar-panel",
  "accumulator", "radar", "rocket-silo", "roboport", "beacon", "storage-tank", "container", "logistic-container",
  "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret",
}
local TURRET_TYPES = { "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret" }

-- Disque de repérage (en secteurs), du plus proche au plus lointain du point de départ.
local OFFSETS = {}
do
  local r = R.scan_radius
  for dx = -r, r do
    for dy = -r, r do
      local d2 = dx * dx + dy * dy
      if d2 <= r * r then OFFSETS[#OFFSETS + 1] = { dx = dx, dy = dy, d2 = d2 } end
    end
  end
  table.sort(OFFSETS, function(p, q)
    if p.d2 ~= q.d2 then return p.d2 < q.d2 end
    if p.dy ~= q.dy then return p.dy < q.dy end
    return p.dx < q.dx
  end)
end
PvP.SECTORS = #OFFSETS

local function fname(f) return { "fo-faction.name-" .. f.key } end
local function level_name(level) return { "fo-pvp.level-" .. level } end

local function say(msg, plain)
  game.print(msg)
  log(plain)
end

local function sector_key(sx, sy) return State.chunk_key(sx, sy) end
local function sector_xy(key)
  local sx = math.floor(key / 65536) - 32768
  return sx, key - (sx + 32768) * 65536 - 32768
end

local function gps(surface, pos)
  local x, y = math.floor(pos.x + 0.5), math.floor(pos.y + 0.5)
  if surface and surface.name ~= "nauvis" then return string.format("[gps=%d,%d,%s]", x, y, surface.name) end
  return string.format("[gps=%d,%d]", x, y)
end

---------------------------------------------------------------------------------------------------
-- Niveau et état
---------------------------------------------------------------------------------------------------
--- Niveau en vigueur : imposé par l'interface distante (bancs), sinon le réglage de partie.
function PvP.difficulty()
  local war = State.war()
  local forced = war and war.pvp_forced
  if forced and F.pvp[forced] then return forced end
  local s = settings.global[PvP.SETTING]
  local v = s and s.value
  if F.pvp[v] then return v end
  return F.pvp_default
end

local function faction_state(f)
  local fp = f.pvp
  if not fp then
    fp = {
      declared = false, provoked = false, warned = false, declared_at = nil, last_attack = nil, due_since = nil,
      sent_player = 0, sent_total = 0, attacks = 0, soldiers = 0, kills = 0, target = nil, saves = 0,
      plan = nil, sieges = 0, deterred = 0, joins = 0,
    }
    f.pvp = fp
  end
  return fp
end
PvP.faction_state = faction_state

local function new_state(war, tick, level)
  local surface = game.surfaces[war.surface]
  local spawn = game.forces.player.get_spawn_position(surface)
  return {
    difficulty = level, anchor = tick, sectors = {}, score = 0, cursor = 1, sweeps = 0, losses = 0,
    home = { x = math.floor(spawn.x / R.sector), y = math.floor(spawn.y / R.sector) },
  }
end

local function ceasefire_on(f)
  return game.forces[f.force].get_cease_fire(game.forces.player)
end

local function set_relations(f, ceasefire)
  local force, player = game.forces[f.force], game.forces.player
  force.set_cease_fire(player, ceasefire)
  player.set_cease_fire(force, ceasefire)
end

--- Fin de la grâce d'une faction (tick), nil en « Paisible ».
local function grace_end(p, fp, level, f)
  return S.grace_end(p.anchor, fp.grace_floor, level, Character.of(f)) -- lot IA2-0 : caractère tiré
end

--- Plus court délai de grâce parmi les factions vivantes (ticks), nil en « Paisible ».
local function earliest_grace(war, level)
  local best
  for _, id in ipairs(State.alive()) do
    local g = S.grace_ticks(level, Character.of(war.factions[id]))
    if g and (not best or g < best) then best = g end
  end
  return best
end

--- État PvP d'une guerre en cours. Une guerre lancée avant le lot IA0 (sauvegarde plus ancienne) reçoit
--- son état ici : la grâce part du chargement (pas du lancement de la guerre), et le joueur est prévenu.
--- HOSTILITÉ HÉRITÉE : une faction déjà sans cessez-le-feu avec le joueur (provocation, ou ancien réglage
--- fo-war-player-ceasefire décoché) est marquée provoquée : elle reste hostile en « Paisible » (comme avant
--- IA0) ; hors « Paisible », elle est en guerre déclarée dès la reprise, sans grâce et sans nouvelle
--- déclaration (un message dit qu'elle l'était déjà).
function PvP.ensure(tick)
  local war = State.war()
  if war.pvp then return war.pvp end
  local level = PvP.difficulty()
  local p = new_state(war, tick, level)
  war.pvp = p
  for _, id in ipairs(State.sorted_keys(war.factions)) do faction_state(war.factions[id]) end
  Scheduler.add(PvP.SCAN_LANE, 1)
  say({ "fo-pvp.resumed", level_name(level) }, "[FO-PVP] reprise d'une guerre anterieure : difficulte " .. level .. ", grace depuis le tick " .. tick)
  local aggressive = F.pvp_params(level).aggressive
  for _, id in ipairs(State.alive()) do
    local f = war.factions[id]
    if not ceasefire_on(f) then
      local fp = faction_state(f)
      fp.provoked, fp.inherited = true, true
      if aggressive then fp.declared, fp.warned, fp.declared_at = true, true, tick end
      say({ "fo-pvp.inherited", fname(f) }, string.format("[FO-PVP] hostilite heritee tick %d %s", tick, f.key))
    end
  end
  return p
end

--- Appelé par War.start_at, après la diplomatie : état neuf, repérage, message d'introduction.
function PvP.on_war_started(tick)
  local war = State.war()
  local level = PvP.difficulty()
  war.pvp = new_state(war, tick, level)
  for _, id in ipairs(State.sorted_keys(war.factions)) do
    war.factions[id].pvp = nil
    faction_state(war.factions[id])
  end
  Scheduler.add(PvP.SCAN_LANE, 1)
  local g = earliest_grace(war, level)
  if g then
    say({ "fo-pvp.intro", level_name(level), math.ceil(g / 3600) },
      string.format("[FO-PVP] guerre lancee : difficulte %s, premiere declaration possible au tick %d", level, tick + g))
  else
    say({ "fo-pvp.intro-peaceful", level_name(level) }, "[FO-PVP] guerre lancee : difficulte peaceful")
  end
end

function PvP.on_war_stopped()
  local war = State.war()
  war.pvp = nil
  Scheduler.remove(PvP.SCAN_LANE, 1)
end

---------------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------------
local function declare(f, reason, tick)
  local fp = faction_state(f)
  fp.declared, fp.warned, fp.declared_at, fp.grace_floor = true, true, tick, nil
  fp.sent_player, fp.sent_total, fp.due_since = 0, 0, nil -- la part visée se compte depuis la déclaration
  if ceasefire_on(f) then set_relations(f, false) end
  local key = reason == "provoked" and "fo-pvp.declare-provoked" or "fo-pvp.declare"
  say({ key, fname(f) }, string.format("[FO-PVP] declaration tick %d %s (%s)", tick, f.key, reason))
end

local function truce(f, tick)
  local fp = faction_state(f)
  fp.declared, fp.warned = false, false
  fp.target, fp.due_since, fp.plan = nil, nil, nil
  if not ceasefire_on(f) then set_relations(f, true) end
  Military.recall_player_groups(f, tick)
  say({ "fo-pvp.truce", fname(f) }, string.format("[FO-PVP] treve tick %d %s", tick, f.key))
end

--- Changement de niveau (réglage, interface distante) : effet immédiat et propre.
---   - vers « Paisible » : trêve des factions déclarées par la difficulté (pas des provoquées), rappel de
---     toutes les attaques en route contre le joueur ;
---   - depuis « Paisible » vers un niveau agressif : la grâce repart de maintenant ;
---   - entre niveaux agressifs : même ancre, nouveaux paramètres dès la pensée suivante ; une faction non
---     déclarée dont la nouvelle grâce finirait dans moins de warn_ticks (ou serait déjà écoulée) ne
---     déclare la guerre qu'après un préavis complet (fin de grâce au plus tôt : maintenant + warn_ticks).
function PvP.sync(tick)
  local war = State.war()
  if not war.active then return end
  local p = PvP.ensure(tick)
  local level = PvP.difficulty()
  if p.difficulty == level then return end
  local was = F.pvp_params(p.difficulty).aggressive
  p.difficulty = level
  local d = F.pvp_params(level)
  if d.aggressive and not was then p.anchor = tick end
  if S.rally_ticks(level) <= 0 then p.rally_until, p.rally_target = nil, nil end -- Difficile et Impitoyable seulement
  say({ "fo-pvp.changed", level_name(level) }, string.format("[FO-PVP] difficulte %s au tick %d", level, tick))
  for _, id in ipairs(State.alive()) do
    local f = war.factions[id]
    local fp = faction_state(f)
    if not fp.declared then
      fp.warned, fp.grace_floor = false, nil
      if d.aggressive and was and not fp.provoked and grace_end(p, fp, level, f) < tick + R.warn_ticks then
        fp.grace_floor = tick + R.warn_ticks
      end
    end
    if not d.aggressive then
      if fp.declared and not fp.provoked then
        truce(f, tick)
      else
        fp.declared = false
        Military.recall_player_groups(f, tick)
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Repérage des installations du joueur (coût borné, étalé)
---------------------------------------------------------------------------------------------------
local function sector_set(p, key, n)
  local old = p.sectors[key] or 0
  if n > 0 then p.sectors[key] = n else p.sectors[key] = nil end
  local was_q, now_q = old >= R.sector_min, n >= R.sector_min
  if now_q and not was_q then p.score = p.score + 1 elseif was_q and not now_q then p.score = p.score - 1 end
end

local function sector_area(sx, sy)
  local x0, y0 = sx * R.sector, sy * R.sector
  return { { x0, y0 }, { x0 + R.sector, y0 + R.sector } }
end

--- Une passe : `scan_per_pass` secteurs, chacun compté par UN appel moteur (aucun objet Lua créé).
function PvP.scan_step(surface, p)
  for _ = 1, R.scan_per_pass do
    local k = p.cursor or 1
    if k > #OFFSETS then
      k = 1
      p.sweeps = (p.sweeps or 0) + 1
    end
    p.cursor = k + 1
    local o = OFFSETS[k]
    local sx, sy = p.home.x + o.dx, p.home.y + o.dy
    local n = 0
    if surface.is_chunk_generated({ x = sx * 2, y = sy * 2 }) then
      n = surface.count_entities_filtered({ area = sector_area(sx, sy), force = "player", type = INSTALL_TYPES, limit = 64 })
    end
    sector_set(p, sector_key(sx, sy), n)
  end
end

Scheduler.define_lane(PvP.SCAN_LANE, R.scan_period, function(_, tick)
  local war = State.war()
  local p = war.active and war.pvp
  if not p then
    Scheduler.remove(PvP.SCAN_LANE, 1)
    return
  end
  if not F.pvp_params(p.difficulty).aggressive then return end -- « Paisible » : aucun coût
  local surface = game.surfaces[war.surface]
  if not surface then return end
  Profiler.start("pvp:scan")
  PvP.scan_step(surface, p)
  Profiler.stop("pvp:scan")
end)

--- Cible joueur d'une faction : secteur qualifié le plus proche de son QG (le secteur de départ du
--- joueur en dernier), recompté exactement ; installation réelle la plus proche du QG ; défense locale.
local function find_player_target(f, surface, p, tick)
  local home = sector_key(p.home.x, p.home.y)
  local keys = State.sorted_keys(p.sectors)
  for _ = 1, 3 do
    local best, best_d
    for _, key in ipairs(keys) do
      if (p.sectors[key] or 0) >= R.sector_min then
        local sx, sy = sector_xy(key)
        local dx = sx * R.sector + R.sector / 2 - f.hq_pos.x
        local dy = sy * R.sector + R.sector / 2 - f.hq_pos.y
        local dd = dx * dx + dy * dy
        if key == home then dd = dd + 1e12 end
        if not best_d or dd < best_d then best, best_d = key, dd end
      end
    end
    if not best then return nil end
    local sx, sy = sector_xy(best)
    local list = surface.find_entities_filtered({ area = sector_area(sx, sy), force = "player", type = INSTALL_TYPES, limit = 16 })
    if #list >= R.sector_min then
      local pos, pd
      for _, e in ipairs(list) do
        local ep = e.position
        local dx, dy = ep.x - f.hq_pos.x, ep.y - f.hq_pos.y
        local dd = dx * dx + dy * dy
        if not pd or dd < pd or (dd == pd and (ep.x < pos.x or (ep.x == pos.x and ep.y < pos.y))) then
          pos, pd = { x = ep.x, y = ep.y }, dd
        end
      end
      local turrets = surface.count_entities_filtered({ position = pos, radius = R.defense_radius, force = "player", type = TURRET_TYPES })
      return { pos = pos, sector = best, turrets = turrets, defense = R.defense_per_turret * turrets, tick = tick }
    end
    sector_set(p, best, #list) -- le repérage datait : secteur corrigé, on essaie le suivant
  end
  return nil
end

--- Vue « joueur » d'une faction, évaluée seulement quand elle peut servir (niveau agressif, guerre
--- déclarée ou grâce écoulée, intervalle entre deux attaques écoulé). nil sinon.
local function player_view(f, surface, p, fp, tick, level)
  if not F.pvp_params(level).aggressive or p.score <= 0 then return nil end
  if not fp.declared and not fp.provoked and tick < grace_end(p, fp, level, f) then return nil end
  if fp.last_attack and tick - fp.last_attack < S.cooldown_ticks(level) then return nil end
  if Military.target_unreachable(f, "player", tick) then return { score = p.score, defense = 0, reachable = false } end
  local t = fp.target
  if not t or tick - t.tick >= R.target_ttl or (p.sectors[t.sector] or 0) < R.sector_min then
    t = find_player_target(f, surface, p, tick)
    fp.target = t
  end
  if not t then return nil end
  return { score = p.score, defense = t.defense, reachable = true }
end

local function player_groups(f)
  local n = 0
  for _, gid in ipairs(State.sorted_keys(f.groups)) do
    local g = f.groups[gid]
    if g.target_faction == "player" and g.state == "attack" then n = n + 1 end
  end
  if f.route_pending and f.route_pending.target_faction == "player" then n = n + 1 end
  return n
end

--- Pensée PvP d'une faction (appelée par le commandant à la place de l'ancienne décision d'attaque).
--- view, target : vue et cible faction calculées par le commandant (logique d'avant IA0).
function PvP.think(f, surface, tick, view, target)
  local war = State.war()
  PvP.sync(tick)
  local p = war.pvp
  local fp = faction_state(f)
  local level = p.difficulty
  local leader = 0
  for _, id in ipairs(State.alive()) do
    if id ~= f.id then
      local o = war.factions[id].outposts_count
      if o > leader then leader = o end
    end
  end
  view.rival = target and { id = target.id, outposts = target.outposts_count } or nil
  view.own_outposts = f.outposts_count
  view.leader_outposts = leader
  view.pvp = {
    difficulty = level, tick = tick, anchor = p.anchor, grace_floor = fp.grace_floor,
    declared = fp.declared, provoked = fp.provoked,
    warned = fp.warned, last_attack = fp.last_attack, sent_player = fp.sent_player, sent_total = fp.sent_total,
    player_groups = player_groups(f), due_since = fp.due_since, last_rival = fp.last_rival,
    rally_until = p.rally_until, rally_defense = p.rally_until and p.rally_target and p.rally_target.defense or nil,
  }
  view.player = player_view(f, surface, p, fp, tick, level)
  local a = S.decide(view)
  if a.due_since ~= nil then fp.due_since = a.due_since or nil end
  if a.plan == "save" then fp.saves = (fp.saves or 0) + 1 end
  -- Lot IA0b : entrée en siège ou en dissuasion (une ligne de journal par entrée, pas par pensée).
  if a.plan ~= fp.plan then
    if a.plan == "siege" then
      fp.sieges = (fp.sieges or 0) + 1
      log(string.format("[FO-PVP] siege tick %d %s : besoin %d, disponibles %d, defense estimee %d, tech %d",
        tick, f.key, a.need or 0, a.count or 0, view.player and view.player.defense or 0, f.tech or 0))
    elseif a.plan == "deterred" then
      fp.deterred = (fp.deterred or 0) + 1
      log(string.format("[FO-PVP] dissuasion tick %d %s : besoin %d, disponibles %d, defense estimee %d, tech %d",
        tick, f.key, a.need or 0, a.count or 0, view.player and view.player.defense or 0, f.tech or 0))
    end
  end
  fp.plan = a.plan

  if a.warn then
    fp.warned = true
    say({ "fo-pvp.warn", fname(f), a.warn }, string.format("[FO-PVP] preavis tick %d %s : %d min", tick, f.key, a.warn))
  end
  if a.declare then declare(f, a.declare, tick) end
  if a.truce then truce(f, tick) end
  if a.recall then Military.recall_player_groups(f, tick) end
  if a.attack then
    if a.attack.target == "player" and fp.target then
      -- Attaque jointe : la cible de la fenêtre (cible commune), sinon celle de la faction.
      local rt = a.attack.join and p.rally_target or nil
      local pos = rt and { x = rt.x, y = rt.y } or fp.target.pos
      local defense = rt and rt.defense or fp.target.defense
      if Military.attack(f, surface, { id = "player", key = "player", hq_pos = pos, outposts = {} }, a.attack.count, tick)
        and f.route_pending then
        f.route_pending.join, f.route_pending.need, f.route_pending.defense = a.attack.join or nil, a.need, defense
        if a.rally then
          -- Difficile, Impitoyable : fenêtre d'assaut coordonné pour les autres factions qui assiègent ; la
          -- dernière attaque prête fixe la cible commune.
          local u = tick + S.rally_ticks(level)
          if not p.rally_until or u > p.rally_until then p.rally_until = u end
          p.rally_by = f.key
          p.rally_target = { x = pos.x, y = pos.y, defense = defense }
          log(string.format("[FO-PVP] assaut coordonne ouvert tick %d par %s jusqu'au tick %d, cible (%d, %d), defense estimee %d",
            tick, f.key, p.rally_until, math.floor(pos.x), math.floor(pos.y), defense or 0))
        end
      end
    elseif target and a.attack.target == target.id then
      Military.attack(f, surface, target, a.attack.count, tick)
    end
  end
  return a
end

--- Le joueur a détruit une entité de la faction. Sous cessez-le-feu, c'est une provocation : cessez-le-feu
--- rompu (comme avant IA0) et, hors « Paisible », la faction le prend aussitôt pour cible (fin de la grâce
--- pour elle). En guerre ouverte (déclarée par la difficulté, provoquée ou héritée), abattre un attaquant
--- est de la légitime défense : rien ne change (pas de provocation, trêve de « Paisible » toujours
--- possible, grâce intacte au retour à un niveau agressif, aucun message).
function PvP.on_provoked(f, tick)
  local war = State.war()
  if not war.active then return end
  local p = PvP.ensure(tick)
  if not ceasefire_on(f) then return end
  local fp = faction_state(f)
  fp.provoked = true
  set_relations(f, false)
  if F.pvp_params(p.difficulty).aggressive and not fp.declared then
    fp.declared, fp.warned, fp.declared_at, fp.grace_floor = true, true, tick, nil
    fp.sent_player, fp.sent_total, fp.due_since = 0, 0, nil
  end
  say({ "fo-pvp.declare-provoked", fname(f) }, string.format("[FO-PVP] declaration tick %d %s (provoked)", tick, f.key))
end

---------------------------------------------------------------------------------------------------
-- Crochets du module militaire
---------------------------------------------------------------------------------------------------
--- Une route vers le joueur arrive : l'attaque part-elle encore (niveau, guerre déclarée) ?
Military.player_target_allowed = function(f)
  local p = State.war().pvp
  return p ~= nil and F.pvp_params(p.difficulty).aggressive and f.pvp ~= nil and f.pvp.declared
end

--- Un groupe part : comptes de la part visée ; message au joueur si l'attaque le vise.
Military.on_launched = function(f, target_faction, n, rp, tick)
  local fp = faction_state(f)
  fp.sent_total = fp.sent_total + n
  if target_faction.id ~= "player" then
    fp.last_rival = tick -- lot IA0b : fin de l'impasse de la règle du déficit (S.rival_stalled)
    Character.redraw(f) -- lot IA2-0 : seuil de la prochaine attaque entre factions, tiré à ±20 %
    return
  end
  fp.sent_player = fp.sent_player + n
  fp.attacks = fp.attacks + 1
  fp.soldiers = fp.soldiers + n
  fp.last_attack = tick
  fp.due_since, fp.plan = nil, nil
  fp.last_target = { x = rp.target.x, y = rp.target.y, defense = rp.defense }
  local surface = game.surfaces[State.war().surface]
  if rp.join then fp.joins = (fp.joins or 0) + 1 end
  say({ rp.join and "fo-pvp.attack-joined" or "fo-pvp.attack", fname(f), n, gps(surface, rp.target) },
    string.format("[FO-PVP] attaque tick %d %s -> joueur : %d soldats vers (%d, %d), defense estimee %d, besoin %d, tech %d%s",
      tick, f.key, n, math.floor(rp.target.x), math.floor(rp.target.y), rp.defense or (fp.target and fp.target.defense) or 0,
      rp.need or 0, f.tech or 0, rp.join and " (assaut coordonne)" or ""))
end

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
Events.on(defines.events.on_runtime_mod_setting_changed, function(e)
  if e.setting ~= PvP.SETTING then return end
  local war = State.war()
  if war and war.active then PvP.sync(e.tick) end
end)

-- Pertes du joueur causées par les factions (preuve des attaques, statut). Coût : le tueur est testé
-- d'abord (champ de l'événement, puis un seul appel d'API pour son nom) ; l'entité morte n'est lue que si
-- le tueur est une faction.
Events.on(defines.events.on_entity_died, function(e)
  local killer = e.force
  if not killer then return end
  local war = State.war()
  if not (war.active and war.pvp) then return end
  local f = State.by_force(killer.name)
  if not f then return end
  local ent = e.entity
  if not (ent and ent.valid) or ent.force.name ~= "player" then return end
  war.pvp.losses = (war.pvp.losses or 0) + 1
  local fp = faction_state(f)
  fp.kills = fp.kills + 1
end)

-- Sauvegarde d'une version antérieure avec une guerre en cours : état PvP créé au chargement.
Events.on_configuration_changed(function()
  local war = State.war()
  if war and war.active and not war.pvp and not war.reset_v03 then PvP.ensure(game.tick) end
end)

---------------------------------------------------------------------------------------------------
-- Statut et interface distante
---------------------------------------------------------------------------------------------------
function PvP.status(tick)
  local war = State.war()
  local p = war.pvp
  local level = PvP.difficulty()
  local out = {
    active = war.active, difficulty = level, forced = war.pvp_forced, anchor = p and p.anchor,
    score = p and p.score or 0, sweeps = p and p.sweeps or 0, losses = p and p.losses or 0,
    sectors = 0, factions = {}, rally_until = p and p.rally_until,
    rally_target = p and p.rally_target and { x = p.rally_target.x, y = p.rally_target.y, defense = p.rally_target.defense } or nil,
  }
  if p then for _ in pairs(p.sectors) do out.sectors = out.sectors + 1 end end
  for _, id in ipairs(State.sorted_keys(war.factions or {})) do
    local f = war.factions[id]
    local fp = f.pvp or {}
    out.factions[#out.factions + 1] = {
      key = f.key, personality = f.personality, eliminated = f.eliminated,
      declared = fp.declared or false, provoked = fp.provoked or false, inherited = fp.inherited or false,
      declared_at = fp.declared_at,
      grace_end = p and S.grace_end(p.anchor, fp.grace_floor, level, Character.of(f)) or nil,
      attacks = fp.attacks or 0, soldiers = fp.soldiers or 0,
      sent_player = fp.sent_player or 0, sent_total = fp.sent_total or 0, last_attack = fp.last_attack,
      kills = fp.kills or 0,
      target = fp.target and { x = fp.target.pos.x, y = fp.target.pos.y, defense = fp.target.defense } or nil,
      last_target = fp.last_target and { x = fp.last_target.x, y = fp.last_target.y, defense = fp.last_target.defense } or nil,
      last_rival = fp.last_rival, plan = fp.plan, sieges = fp.sieges or 0, deterred = fp.deterred or 0, joins = fp.joins or 0, tech = f.tech,
    }
  end
  return out
end

function PvP.status_line(tick)
  local st = PvP.status(tick)
  local parts = {}
  for _, fs in ipairs(st.factions) do
    parts[#parts + 1] = string.format("%s %s%s att %d (%d soldats, %d jointes) sieges %d pertes infligees %d", fs.key,
      fs.declared and "GUERRE" or "treve", fs.provoked and "*" or "", fs.attacks, fs.soldiers, fs.joins, fs.sieges, fs.kills)
  end
  return string.format("  PvP : difficulte %s | secteurs du joueur %d (cibles %d, balayages %d) | pertes du joueur %d | %s",
    st.difficulty, st.sectors, st.score, st.sweeps, st.losses, table.concat(parts, " ; "))
end

--- Impose un niveau sans joueur (bancs). Écrit le réglage du mod (un mod peut changer ses propres
--- réglages) ; si le moteur le refuse, le niveau est imposé dans l'état (war.pvp_forced). nil = rendre
--- la main au réglage.
function PvP.set_difficulty(level)
  local war = State.war()
  if level == nil then
    war.pvp_forced = nil
  else
    if not F.pvp[level] then return false end
    local ok = pcall(function() settings.global[PvP.SETTING] = { value = level } end)
    if ok and settings.global[PvP.SETTING].value == level then
      war.pvp_forced = nil
    else
      war.pvp_forced = level
    end
  end
  if war.active then PvP.sync(game.tick) end
  return true
end

remote.add_interface("fo-pvp", {
  status = function() return PvP.status(game.tick) end,
  set_difficulty = function(level) return PvP.set_difficulty(level) end,
})

return PvP
