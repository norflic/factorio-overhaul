--[[
  Armées de faction : agents DE MASSE. Le script ne pilote que des GROUPES (LuaUnitGroup) ; marche,
  ciblage et combat sont assurés par l'IA moteur (C++).

  Cycle d'un groupe : garnison (errance autour du QG) -> ITINÉRAIRE (une requête de chemin pour tout le
  groupe) -> "attack" (marche de point en point le long de l'itinéraire puis attaque de zone) -> "return"
  (retour au QG) -> dissous, les survivants rejoignent la garnison.

  Moteur réel (session 3) : des étapes en ligne droite (même recalées sur la terre ferme) faisaient échouer
  la plupart des attaques à la première étape (lac, falaises, isthme). L'itinéraire est désormais calculé
  par le pathfinder (grille grossière, coût unique par attaque) ; une cible sans itinéraire est écartée
  10 minutes et la faction choisit une autre cible.
  Filet de sécurité : un groupe sans nouvelles depuis GROUP_TIMEOUT est rappelé puis dissous.

  Lot PNJ-VÉRIF (24/10, moteur réel, banc `default`) : trois corrections du retour des groupes.
  - Une fin de commande NÉE D'UNE DISTRACTION (`was_distracted`) n'est plus prise pour la fin de l'attaque :
    le groupe reprend seul sa commande après le combat. Avant, le premier accrochage renvoyait le groupe.
  - Le retour au QG est une seule commande `go_to_location` ; d'un groupe arrêté vers 1 000 tuiles, au milieu
    d'une base ennemie, le moteur l'abandonne en 1 tick (résultat « fail » ; de 560 à 620 tuiles, il a réussi). Avant, le groupe était alors dissous SUR PLACE : 27 soldats d'Écarlate sont restés à
    960 tuiles de leur QG. Désormais, les survivants forment un groupe NEUF qui rentre par l'itinéraire de
    l'aller, à l'envers, en une commande composée (donner les étapes une à une au même groupe échouait aussi,
    en 1 tick chacune) ; un retour direct qui dépasse GROUP_TIMEOUT est traité de même.
  - Un soldat « en garnison » loin du QG (plus de GATHER_RADIUS tuiles du point de rassemblement) n'est plus
    pris dans une attaque : le moteur le retire du groupe en quelques ticks et l'attaque partait VIDE, relancée
    à chaque pensée (32 « attaques » fantômes de suite, toutes les 300 ticks). Sans soldat proche, l'attaque
    est remise de ATTACK_RETRY_TICKS.

  Lot PNJ-VÉRIF, correction après vérification adverse (défauts M3, M4) :
  - Des soldats restaient pour toujours au loin : un groupe dissous loin du QG (attaque en échec sur un groupe
    devenu invalide, groupe vidé) les laissait sur place, et les membres que le moteur retire d'un groupe EN ROUTE
    n'étaient jamais regroupés. Désormais, à chaque entretien : (1) un soldat qui n'est plus membre de son groupe
    revient à la garnison, là où il est ; (2) RAPPEL : les soldats de garnison à plus de GATHER_RADIUS tuiles du
    rassemblement sont regroupés par paquets proches (RECALL_CLUSTER), un itinéraire est demandé au pathfinder
    jusqu'au QG, et un groupe NEUF rentre par ses étapes (comme l'aller) ; un paquet par faction toutes les
    RECALL_PERIOD ticks, et un soldat rappelé sans succès attend de plus en plus longtemps avant le suivant.
  - La garnison qui décide une attaque (et celle qu'estime un adversaire) ne compte plus que les soldats proches du
    rassemblement (Military.garrison_near) : 18 soldats bloqués au loin faisaient partir 9 soldats au lieu de 21.
]]

local Events = require("script.core.events")
local F = require("shared.faction.config")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")
local Profiler = require("script.core.profiler")
local PathService = require("script.core.path_service")
local Journal = require("script.faction.journal")

local Military = {}

local GROUP_TIMEOUT = 6 * 60 * 60
local GARRISON_RADIUS = 18
local ATTACK_RETRY_TICKS = 3600 -- après un échec de commande de groupe (moteur réel : 212 « attaques » mort-nées)
local UNREACHABLE_TARGET_TICKS = 36000
local ROUTE_HANDLER = "fo-war-route"
local WAYPOINT_SPACING = 64
local GATHER_RADIUS = 160 -- lot PNJ-VÉRIF : au-delà, un soldat sans groupe n'est pas rassemblé (le moteur l'écarte)
local MAX_REROUTES = 3    -- lot PNJ-VÉRIF : retours par l'itinéraire tentés au plus, par groupe
local RECALL_HANDLER = "fo-war-recall"
local RECALL_CLUSTER = 32   -- rappel : soldats lointains à moins de 32 tuiles du premier forment un paquet
local RECALL_PERIOD = 600   -- rappel : une demande d'itinéraire au plus par faction toutes les 600 ticks
local RECALL_BACKOFF = 3600 -- rappel : attente d'un soldat déjà rappelé, × le nombre de rappels (5 au plus)
local DISSOLVE_TICKS = 600  -- lot IA2-a : un groupe d'attaque vidé avant 600 ticks a été défait au départ (F174)

--- Point de rassemblement du QG (destination des retours).
local function home(f) return { x = f.hq_pos.x, y = f.hq_pos.y + 14 } end

--- Comportement de garnison : "wander" (errance, vivant) ou "stop" (au repos, réagit aux ennemis).
--- Réglable par l'interface distante (option "garrison_mode") pour les mesures de coût moteur.
local function wander(unit, radius)
  local s = State.war().settings
  if s and s.garrison_mode == "stop" then
    unit.set_command({ type = defines.command.stop, distraction = defines.distraction.by_enemy })
    return
  end
  unit.set_command({ type = defines.command.wander, radius = radius or GARRISON_RADIUS, distraction = defines.distraction.by_enemy })
end

function Military.train(f, surface, key, count)
  Profiler.start("military:train")
  local name = F.unit_name(f.key, key)
  local made = 0
  for i = 1, count do
    local probe = { x = f.hq_pos.x + ((i % 5) - 2) * 3, y = f.hq_pos.y + 10 + math.floor(i / 5) * 2 }
    local pos = surface.find_non_colliding_position(name, probe, 30, 0.5)
    if pos then
      local u = surface.create_entity({ name = name, position = pos, force = f.force })
      if u then
        f.soldiers[u.unit_number] = { entity = u, group = nil }
        f.soldiers_count = f.soldiers_count + 1
        f.garrison_count = f.garrison_count + 1
        State.own(u, f.id, "soldier")
        wander(u)
        made = made + 1
      end
    end
  end
  Profiler.stop("military:train")
  return made
end

--- Points de passage espacés d'environ WAYPOINT_SPACING tuiles le long d'un chemin du pathfinder.
local function waypoints_along(path)
  local pts, acc = {}, 0
  local prev = path[1].position
  for i = 2, #path do
    local p = path[i].position
    local dx, dy = p.x - prev.x, p.y - prev.y
    acc = acc + math.sqrt(dx * dx + dy * dy)
    if acc >= WAYPOINT_SPACING and i < #path then
      pts[#pts + 1] = { x = p.x, y = p.y }
      acc = 0
    end
    prev = p
  end
  return pts
end

-- Crochets branchés par script/faction/pvp.lua (lot IA0) : le joueur peut être une cible.
--   Military.player_target_allowed(f) -> bool : une route vers le joueur arrive, l'attaque part-elle encore ?
--   Military.on_launched(f, cible, n, rp, tick) : un groupe de n soldats part (comptes, message au joueur).
-- Une cible « joueur » est une pseudo-faction { id = "player", key = "player", hq_pos = position visée,
-- outposts = {} } : Military.target_of rend donc directement la position visée.
Military.player_target_allowed = nil
Military.on_launched = nil
-- Crochets branchés par script/faction/chef.lua (lot IA2-a) :
--   Military.on_chef_launch(f, cible, n, rp, tick, gid) : un groupe part (mémoire du chef) ;
--   Military.on_attack_ended(f, g, survivants, tick) : fin de la phase d'attaque d'un groupe (issue).
Military.on_chef_launch = nil
Military.on_attack_ended = nil
-- Crochets branchés par script/faction/vision.lua et script/faction/chef.lua (lot IA2-c) :
--   Military.on_rally(f, g, tick) -> bool : le groupe est au rassemblement avancé ; true = il attaque (go), false = il
--     renonce (la défense vue a grossi) et rentre ;
--   Military.on_player_attack_ended(f, g, survivants, tick, vivants) : fin de la phase d'attaque contre le joueur ;
--   Military.on_scout_done(f, g, tick, arrivé) : un éclaireur a fini son aller (arrivé = true) ou l'a manqué.
--   Military.on_scout_lost(f, g, tick, vivants) : un éclaireur (ou une patrouille) a été perdu en route.
Military.on_rally = nil
Military.on_player_attack_ended = nil
Military.on_scout_done = nil
Military.on_scout_lost = nil

--- Cible d'attaque : avant-poste le plus proche de la faction visée, sinon son QG.
function Military.target_of(target_faction, from)
  return Outposts.nearest(target_faction, from) or target_faction.hq_pos
end

local function request_route(f, surface, rp, name)
  rp.ticket = PathService.request(ROUTE_HANDLER, f.id, {
    surface = surface.index, proto = name, pad = 0, start = rp.gather, goal = rp.approach or rp.target, force = f.force,
    radius = 16, flags = { cache = false, low_priority = false }, res = -2,
  })
end

--- Prépare une attaque : demande l'itinéraire (asynchrone). Le groupe part quand le chemin arrive.
--- Lot IA2-a, `opts` (chef, attaques contre une rivale) : { target = point visé, approach = rassemblement avancé
--- (le groupe y passe avant d'attaquer : côté d'arrivée), octant, raid, rule }. Le départ reste près de la garnison
--- (QG + (0, 14)) : F173 (unités ajoutées à un groupe lointain) et F174 (membres perdus à la création).
function Military.attack(f, surface, target_faction, count, tick, opts)
  if f.route_pending then return false end
  opts = opts or {}
  local target = opts.target or Military.target_of(target_faction, f.hq_pos)
  local name = F.unit_name(f.key, F.best_soldier(f.tech))
  local gather = surface.find_non_colliding_position(name, { x = f.hq_pos.x, y = f.hq_pos.y + 14 }, 20, 1)
    or { x = f.hq_pos.x, y = f.hq_pos.y + 14 }
  local approach = opts.approach and surface.find_non_colliding_position(name, opts.approach, 24, 2) or nil
  f.route_pending = {
    target_faction = target_faction.id, count = count, target = target, gather = gather, tick = tick,
    approach = approach and { x = approach.x, y = approach.y } or nil, octant = approach and opts.octant or nil,
    raid = opts.raid or nil, rule = opts.rule,
    -- Lot IA2-c : défense estimée au départ (go / no-go au rassemblement), défense du côté choisi et du côté le plus
    -- défendu (journal), secteur visé (mémoire des attaques contre le joueur).
    launch_def = opts.launch_def, side_def = opts.side_def, side_max = opts.side_max, key = opts.key, direct = opts.direct,
  }
  request_route(f, surface, f.route_pending, name)
  return true
end

--- Lot IA2-c : ÉCLAIREUR. Un soldat de la garnison part vers `dest` (itinéraire du pathfinder, comme une attaque),
--- regarde, puis rentre par le même chemin. Ce qu'il voit (en route : son groupe est un œil ; à l'arrivée :
--- Military.on_scout_done) est la seule source de ce qu'une faction sait d'un adversaire lointain (brouillard, D-16).
--- Un éclaireur à la fois par faction (f.scout_pending, puis un groupe à l'état « scout »). Renvoie true s'il part.
local SCOUT_HANDLER = "fo-war-scout"
function Military.scout(f, surface, dest, tick, tag, size)
  if f.scout_pending then return false end
  for _, gid in ipairs(State.sorted_keys(f.groups)) do
    if f.groups[gid].state == "scout" then return false end
  end
  size = size or 1
  if Military.garrison_near(f) < size then return false end
  local name = F.unit_name(f.key, F.best_soldier(f.tech))
  local gather = surface.find_non_colliding_position(name, home(f), 20, 1) or home(f)
  f.scout_pending = { gather = { x = gather.x, y = gather.y }, dest = { x = dest.x, y = dest.y }, tick = tick, tag = tag, size = size }
  f.scout_pending.ticket = PathService.request(SCOUT_HANDLER, f.id, {
    surface = surface.index, proto = name, pad = 0, start = f.scout_pending.gather, goal = f.scout_pending.dest, force = f.force,
    radius = 24, flags = { cache = false, low_priority = true }, res = -2,
  })
  return true
end

--- Lance le groupe le long de l'itinéraire calculé.
local function launch_group(f, surface, target_faction, rp, path, tick)
  local ids = State.sorted_keys(f.soldiers)
  local chosen, far = {}, 0
  local r2 = GATHER_RADIUS * GATHER_RADIUS
  for _, id in ipairs(ids) do
    if #chosen >= rp.count then break end
    local s = f.soldiers[id]
    if not s.group and s.entity.valid then
      local p = s.entity.position
      local dx, dy = p.x - rp.gather.x, p.y - rp.gather.y
      if dx * dx + dy * dy <= r2 then chosen[#chosen + 1] = id else far = far + 1 end
    end
  end
  if #chosen == 0 then
    f.attack_block_until = tick + ATTACK_RETRY_TICKS
    if Profiler.enabled() then
      log(string.format("[FO-ATTACK] tick %d %s -> %s : aucun soldat pres du QG (%d loin), attaque remise", tick, f.key,
        target_faction.key, far))
    end
    return false
  end
  local group = surface.create_unit_group({ position = rp.gather, force = f.force })
  for _, id in ipairs(chosen) do
    group.add_member(f.soldiers[id].entity)
    f.soldiers[id].group = group.group_number
  end
  f.garrison_count = f.garrison_count - #chosen
  local cmds = {}
  local route = waypoints_along(path)
  -- Lot IA2-a : le chemin mène au rassemblement avancé (côté d'arrivée choisi par le chef), qui devient la
  -- dernière étape ; le retour reprendra ces étapes à l'envers.
  if rp.approach then route[#route + 1] = { x = rp.approach.x, y = rp.approach.y } end
  for _, p in ipairs(route) do
    cmds[#cmds + 1] = {
      type = defines.command.go_to_location, destination = p, radius = 12,
      distraction = defines.distraction.by_enemy,
    }
  end
  -- Lot IA2-c : GO / NO-GO. Avec un rassemblement avancé, la commande s'arrête au rassemblement (dernière étape) ;
  -- à l'arrivée, Military.on_rally décide : attaque (attack_area) ou renonce (retour). Sans crochet : comme IA2-a.
  local rally = rp.approach ~= nil and Military.on_rally ~= nil
  if not rally then
    cmds[#cmds + 1] = {
      type = defines.command.attack_area,
      destination = rp.target,
      radius = F.military.attack_radius,
      distraction = defines.distraction.by_enemy,
    }
  end
  group.set_command({ type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds })
  group.start_moving()
  -- route : étapes de l'aller (nombres seulement), reprises à l'envers si le retour direct échoue.
  f.groups[group.group_number] = { group = group, state = "attack", target = rp.target, target_faction = target_faction.id, started = tick, size = #chosen,
    route = route, gid = group.group_number, raid = rp.raid, ids = chosen,
    rally = rally or nil, launch_def = rp.launch_def or rp.defense, octant = rp.octant, key = rp.key }
  rp.gid = group.group_number
  f.stats.attacks = f.stats.attacks + 1
  Journal.attack(f, target_faction, #chosen, rp, tick) -- lot IA2-0 : ligne publiée (métriques M2)
  if Military.on_launched then Military.on_launched(f, target_faction, #chosen, rp, tick) end
  if Military.on_chef_launch then Military.on_chef_launch(f, target_faction, #chosen, rp, tick, group.group_number) end
  if Profiler.enabled() then -- journal de diagnostic (bancs de test uniquement)
    local dx, dy = rp.target.x - rp.gather.x, rp.target.y - rp.gather.y
    log(string.format("[FO-ATTACK] tick %d %s -> %s : %d soldats, %d tuiles a vol d'oiseau, chemin %d noeuds, %d etapes%s",
      tick, f.key, target_faction.key, #chosen, math.floor(math.sqrt(dx * dx + dy * dy)), #path, #cmds - 1,
      far > 0 and string.format(" (%d soldats loin du QG laisses)", far) or ""))
  end
  return true
end

local Trace = require("script.core.trace")

local function launch(f, surface, target_faction, rp, path, tick)
  Trace.log("attack", f.key, rp.count)
  Profiler.start("military:launch")
  local ok = launch_group(f, surface, target_faction, rp, path, tick)
  Profiler.stop("military:launch")
  return ok
end

PathService.register_handler(ROUTE_HANDLER, function(fid, path, ticket, reason, tick)
  local war = State.war()
  local f = war.factions and war.factions[fid]
  if not f or not f.route_pending or f.route_pending.ticket ~= ticket then return end -- périmé
  local rp = f.route_pending
  f.route_pending = nil
  if not war.active or f.eliminated then return end
  local tf
  if rp.target_faction == "player" then
    -- Le niveau a pu passer à « Paisible » pendant le calcul de la route : l'attaque ne part pas.
    if not (Military.player_target_allowed and Military.player_target_allowed(f)) then return end
    tf = { id = "player", key = "player" }
  else
    tf = war.factions[rp.target_faction]
    if not tf or tf.eliminated then return end
  end
  if (not path or #path == 0) and rp.approach then
    -- Lot IA2-a : le rassemblement avancé est injoignable (lac, falaises) : une seconde demande, droit sur la cible.
    rp.approach, rp.octant = nil, nil
    f.route_pending = rp
    request_route(f, game.surfaces[war.surface], rp, F.unit_name(f.key, F.best_soldier(f.tech)))
    f.stats.approach_fail = (f.stats.approach_fail or 0) + 1
    return
  end
  if not path or #path == 0 then
    f.stats.route_fail = (f.stats.route_fail or 0) + 1
    f.attack_block_until = tick + ATTACK_RETRY_TICKS
    f.unreachable_targets = f.unreachable_targets or {}
    f.unreachable_targets[rp.target_faction] = tick + UNREACHABLE_TARGET_TICKS
    if Profiler.enabled() then
      log(string.format("[FO-ATTACK] tick %d %s -> %s : aucun itineraire (%s)", tick, f.key, tf.key, tostring(reason)))
    end
    return
  end
  launch(f, game.surfaces[war.surface], tf, rp, path, tick)
end)

--- Une cible est-elle (encore) considérée inaccessible pour cette faction ?
function Military.target_unreachable(f, target_id, tick)
  local u = f.unreachable_targets and f.unreachable_targets[target_id]
  return u ~= nil and tick < u
end

--- Lot IA2-a : fin de la phase d'attaque d'un groupe (issue pour la mémoire du chef), une seule fois par groupe.
local function attack_ended(f, g, tick)
  if not g or g.state ~= "attack" or g.ended then return end
  g.ended = true
  local hook = Military.on_attack_ended
  if g.target_faction == "player" then hook = Military.on_player_attack_ended end -- lot IA2-c
  if hook then
    local survivors = (g.group and g.group.valid) and #g.group.members or 0
    -- Soldats partis encore vivants (dans le groupe ou rendus à la garnison) : un groupe vidé sans morts est un
    -- groupe défait par le moteur (F174), pas une attaque repoussée.
    local alive = 0
    for _, id in ipairs(g.ids or {}) do if f.soldiers[id] then alive = alive + 1 end end
    hook(f, g, survivors, tick, g.ids and alive or nil)
  end
end

local function disband(f, gid)
  local g = f.groups[gid]
  attack_ended(f, g, game.tick)
  f.groups[gid] = nil
  for _, id in ipairs(State.sorted_keys(f.soldiers)) do
    local s = f.soldiers[id]
    if s.group == gid then
      s.group = nil
      f.garrison_count = f.garrison_count + 1
      if s.entity.valid then wander(s.entity) end
    end
  end
  if g and g.group.valid then g.group.destroy() end
end

local function order_return(f, gid, tick)
  local g = f.groups[gid]
  if not g.group.valid then
    disband(f, gid)
    return
  end
  attack_ended(f, g, tick)
  if g.state == "attack" and #g.group.members > 0 then f.dissolved_streak = nil end -- lot IA2-a : attaque arrivée au bout
  g.state = "return"
  g.started = tick
  g.group.set_command({
    type = defines.command.go_to_location,
    destination = { x = f.hq_pos.x, y = f.hq_pos.y + 14 },
    radius = 16,
    distraction = defines.distraction.by_enemy,
  })
  if Profiler.enabled() then
    local p = g.group.position
    local dx, dy = p.x - f.hq_pos.x, p.y - f.hq_pos.y
    log(string.format("[FO-ATTACK] tick %d %s : retour direct au QG, %d soldats a %d tuiles", tick, f.key, #g.group.members,
      math.floor(math.sqrt(dx * dx + dy * dy))))
  end
end

--- Lot PNJ-VÉRIF : le retour direct a échoué (moteur réel : un go_to_location d'environ 1 000 tuiles est
--- abandonné, et donner ensuite des étapes une à une au MÊME groupe échoue aussi, en 1 tick chacune). Les
--- survivants forment un groupe NEUF, qui rentre par l'itinéraire de l'aller à l'envers, en une commande
--- composée (comme l'aller, qui, lui, arrive). Au plus MAX_REROUTES fois par groupe (chaque reprise repart de
--- l'étape la plus proche de l'endroit où le groupe s'est arrêté). Renvoie true si le nouveau groupe
--- est parti, false sinon (l'appelant dissout alors le groupe, comme avant).
local function return_by_route(f, gid, result, tick)
  local g = f.groups[gid]
  if not (g and g.group.valid) or (g.rerouted or 0) >= MAX_REROUTES or result ~= defines.behavior_result.fail then return false end
  local route = g.route
  if not route or #route == 0 then return false end
  local members = g.group.members
  if #members == 0 then return false end
  local surface, p = g.group.surface, g.group.position
  local best, bd
  for k, q in ipairs(route) do
    local dx, dy = q.x - p.x, q.y - p.y
    local d = dx * dx + dy * dy
    if not bd or d < bd then best, bd = k, d end
  end
  local cmds = {}
  for k = best, 1, -1 do
    cmds[#cmds + 1] = { type = defines.command.go_to_location, destination = { x = route[k].x, y = route[k].y }, radius = 12,
      distraction = defines.distraction.by_enemy }
  end
  cmds[#cmds + 1] = { type = defines.command.go_to_location, destination = { x = f.hq_pos.x, y = f.hq_pos.y + 14 }, radius = 16,
    distraction = defines.distraction.by_enemy }
  local in_group = {}
  for _, m in ipairs(members) do in_group[m.unit_number] = true end
  g.group.destroy()
  -- Le centre du groupe peut tomber dans un obstacle (bâtiment, eau) : le moteur abandonne alors tout trajet
  -- en 1 tick. Le groupe neuf part d'une case libre proche.
  local start = surface.find_non_colliding_position(members[1].name, p, 32, 1) or p
  local ng = surface.create_unit_group({ position = start, force = f.force })
  for _, m in ipairs(members) do
    if m.valid then ng.add_member(m) end
  end
  f.groups[gid] = nil
  for _, id in ipairs(State.sorted_keys(f.soldiers)) do
    local s = f.soldiers[id]
    if s.group == gid then
      if in_group[id] then
        s.group = ng.group_number
      else
        -- Soldat déjà écarté du groupe par le moteur : rendu à la garnison là où il est (comme avant).
        s.group = nil
        f.garrison_count = f.garrison_count + 1
      end
    end
  end
  ng.set_command({ type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds })
  ng.start_moving()
  f.groups[ng.group_number] = { group = ng, state = "return", started = tick, target = g.target, target_faction = g.target_faction,
    size = g.size, route = route, rerouted = (g.rerouted or 0) + 1 }
  if Profiler.enabled() then
    log(string.format("[FO-ATTACK] tick %d %s : retour direct echoue, retour par l'itineraire de l'aller (%d etapes, %d soldats, depart decale de %.1f tuiles)",
      tick, f.key, best, #ng.members, math.sqrt((start.x - p.x) ^ 2 + (start.y - p.y) ^ 2)))
  end
  return true
end

--- Rappelle les groupes en route contre le joueur et annule une route en attente vers lui (passage en
--- « Paisible », trêve). Renvoie le nombre de groupes rappelés.
function Military.recall_player_groups(f, tick)
  local n = 0
  for _, gid in ipairs(State.sorted_keys(f.groups)) do
    local g = f.groups[gid]
    if g and g.target_faction == "player" and g.state == "attack" then
      order_return(f, gid, tick)
      n = n + 1
    end
  end
  if f.route_pending and f.route_pending.target_faction == "player" then f.route_pending = nil end
  return n
end

--- Lot PNJ-VÉRIF (M3) : les soldats d'un groupe que le moteur a retirés du groupe (en route, à la création)
--- reviennent à la garnison là où ils sont ; le rappel les ramène s'ils sont loin. Renvoie leur nombre.
local function release_strays(f, gid, g)
  local in_group = {}
  for _, m in ipairs(g.group.members) do in_group[m.unit_number] = true end
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.soldiers)) do
    local s = f.soldiers[id]
    if s.group == gid and not in_group[id] then
      s.group = nil
      f.garrison_count = f.garrison_count + 1
      if s.entity.valid then wander(s.entity) end
      n = n + 1
    end
  end
  return n
end

--- Soldats de garnison (sans groupe) proches du rassemblement, et lointains (Lot PNJ-VÉRIF, M4).
function Military.garrison_split(f)
  local h = home(f)
  local r2 = GATHER_RADIUS * GATHER_RADIUS
  local near, far = 0, 0
  for _, id in ipairs(State.sorted_keys(f.soldiers)) do
    local s = f.soldiers[id]
    if not s.group and s.entity.valid then
      local p = s.entity.position
      local dx, dy = p.x - h.x, p.y - h.y
      if dx * dx + dy * dy <= r2 then near = near + 1 else far = far + 1 end
    end
  end
  return near, far
end

--- Garnison utile : soldats sans groupe à moins de GATHER_RADIUS tuiles du rassemblement.
function Military.garrison_near(f)
  return (Military.garrison_split(f))
end

--- Lot PNJ-VÉRIF (M3) : RAPPEL d'un paquet de soldats de garnison lointains. Demande un itinéraire (asynchrone) ;
--- le groupe part quand il arrive (gestionnaire RECALL_HANDLER).
local function recall_far(f, tick)
  if f.recall_pending or tick < (f.recall_block_until or 0) then return end
  local h = home(f)
  local r2 = GATHER_RADIUS * GATHER_RADIUS
  local far = {}
  for _, id in ipairs(State.sorted_keys(f.soldiers)) do
    local s = f.soldiers[id]
    if not s.group and s.entity.valid then
      local p = s.entity.position
      local dx, dy = p.x - h.x, p.y - h.y
      if dx * dx + dy * dy > r2 then
        -- Lot IA3-k : un soldat qui a un rôle (escorte, garde d'avant-poste, nettoyage : s.ia3k) n'est pas rappelé.
        if tick >= (s.recall_after or 0) and not s.ia3k then far[#far + 1] = { id = id, x = p.x, y = p.y } end
      elseif s.recalls then
        s.recalls, s.recall_after = nil, nil -- rentré : les attentes repartent de zéro
      end
    end
  end
  if #far == 0 then return end
  local a = far[1]
  local ids, c2 = {}, RECALL_CLUSTER * RECALL_CLUSTER
  for _, it in ipairs(far) do
    local dx, dy = it.x - a.x, it.y - a.y
    if dx * dx + dy * dy <= c2 then ids[#ids + 1] = it.id end
  end
  local war = State.war()
  local surface = game.surfaces[war.surface]
  local name = f.soldiers[a.id].entity.name
  local start = surface.find_non_colliding_position(name, { x = a.x, y = a.y }, 32, 1) or { x = a.x, y = a.y }
  f.recall_block_until = tick + RECALL_PERIOD
  f.recall_pending = { ids = ids, start = { x = start.x, y = start.y }, tick = tick }
  f.recall_pending.ticket = PathService.request(RECALL_HANDLER, f.id, {
    surface = surface.index, proto = name, pad = 0, start = f.recall_pending.start, goal = h, force = f.force,
    radius = 16, flags = { cache = false, low_priority = false }, res = -2,
  })
end

PathService.register_handler(RECALL_HANDLER, function(fid, path, ticket, reason, tick)
  local war = State.war()
  local f = war.factions and war.factions[fid]
  if not f or not f.recall_pending or f.recall_pending.ticket ~= ticket then return end -- périmé
  local rc = f.recall_pending
  f.recall_pending = nil
  if not war.active or f.eliminated or not (f.hq and f.hq.valid) then return end
  local chosen = {}
  local r2 = (RECALL_CLUSTER + 16) * (RECALL_CLUSTER + 16)
  for _, id in ipairs(rc.ids) do
    local s = f.soldiers[id]
    if s then
      s.recalls = (s.recalls or 0) + 1
      s.recall_after = tick + RECALL_BACKOFF * math.min(s.recalls, 5)
      if not s.group and s.entity.valid then
        local p = s.entity.position
        local dx, dy = p.x - rc.start.x, p.y - rc.start.y
        if dx * dx + dy * dy <= r2 then chosen[#chosen + 1] = id end
      end
    end
  end
  local h = home(f)
  local dx0, dy0 = rc.start.x - h.x, rc.start.y - h.y
  local dist = math.floor(math.sqrt(dx0 * dx0 + dy0 * dy0))
  if not path or #path == 0 then
    if Profiler.enabled() then
      log(string.format("[FO-ATTACK] tick %d %s : rappel impossible, aucun itineraire (%s) pour %d soldats a %d tuiles du QG",
        tick, f.key, tostring(reason), #rc.ids, dist))
    end
    return
  end
  if #chosen == 0 then return end
  local surface = game.surfaces[war.surface]
  local group = surface.create_unit_group({ position = rc.start, force = f.force })
  for _, id in ipairs(chosen) do
    group.add_member(f.soldiers[id].entity)
    f.soldiers[id].group = group.group_number
  end
  f.garrison_count = f.garrison_count - #chosen
  local pts = waypoints_along(path)
  local cmds = {}
  for _, p in ipairs(pts) do
    cmds[#cmds + 1] = { type = defines.command.go_to_location, destination = p, radius = 12, distraction = defines.distraction.by_enemy }
  end
  cmds[#cmds + 1] = { type = defines.command.go_to_location, destination = h, radius = 16, distraction = defines.distraction.by_enemy }
  group.set_command({ type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds })
  group.start_moving()
  -- route : du QG vers le paquet (ordre de l'aller d'une attaque), pour que return_by_route la prenne à l'envers.
  local route = {}
  for k = #pts, 1, -1 do route[#route + 1] = pts[k] end
  f.groups[group.group_number] = { group = group, state = "return", started = tick, size = #chosen, route = route,
    rerouted = 0, recall = true }
  f.stats.recalls = (f.stats.recalls or 0) + 1
  if Profiler.enabled() then
    log(string.format("[FO-ATTACK] tick %d %s : rappel de %d soldats a %d tuiles du QG (%d etapes)", tick, f.key, #chosen, dist, #pts))
  end
end)

-- Lot IA2-c : itinéraire d'un éclaireur arrivé : un soldat proche du rassemblement part (groupe d'un membre).
PathService.register_handler(SCOUT_HANDLER, function(fid, path, ticket, reason, tick)
  local war = State.war()
  local f = war.factions and war.factions[fid]
  if not f or not f.scout_pending or f.scout_pending.ticket ~= ticket then return end -- périmé
  local sp = f.scout_pending
  f.scout_pending = nil
  if not war.active or f.eliminated or not (f.hq and f.hq.valid) then return end
  if not path or #path == 0 then
    f.stats.scout_fail = (f.stats.scout_fail or 0) + 1
    if Military.on_scout_done then Military.on_scout_done(f, { dest = sp.dest, tag = sp.tag, nopath = true }, tick, false) end
    return
  end
  local chosen = {}
  local r2 = GATHER_RADIUS * GATHER_RADIUS
  for _, id in ipairs(State.sorted_keys(f.soldiers)) do
    if #chosen >= (sp.size or 1) then break end
    local s = f.soldiers[id]
    if not s.group and s.entity.valid then
      local p = s.entity.position
      local dx, dy = p.x - sp.gather.x, p.y - sp.gather.y
      if dx * dx + dy * dy <= r2 then chosen[#chosen + 1] = id end
    end
  end
  if #chosen == 0 then return end
  local surface = game.surfaces[war.surface]
  local group = surface.create_unit_group({ position = sp.gather, force = f.force })
  for _, id in ipairs(chosen) do
    group.add_member(f.soldiers[id].entity)
    f.soldiers[id].group = group.group_number
  end
  f.garrison_count = f.garrison_count - #chosen
  local route = waypoints_along(path)
  -- Un éclaireur seul passe sans combattre ; une PATROUILLE (après des éclaireurs perdus) riposte.
  local dist = #chosen > 1 and defines.distraction.by_enemy or defines.distraction.none
  local cmds = {}
  for _, p in ipairs(route) do
    cmds[#cmds + 1] = { type = defines.command.go_to_location, destination = p, radius = 12, distraction = dist }
  end
  cmds[#cmds + 1] = { type = defines.command.go_to_location, destination = sp.dest, radius = 16, distraction = dist }
  group.set_command({ type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds })
  group.start_moving()
  f.groups[group.group_number] = { group = group, state = "scout", started = tick, size = #chosen, route = route, ids = chosen,
    dest = sp.dest, tag = sp.tag, gid = group.group_number }
  f.stats.scouts = (f.stats.scouts or 0) + 1
  log(string.format("[FO-PVP] eclaireur tick %d %s : en route (groupe %d, %d soldat(s), %d etapes)", tick, f.key, group.group_number,
    #chosen, #route))
end)

--- Entretien périodique (appelé par le commandant) : groupes vides ou bloqués, soldats égarés, rappel.
function Military.maintain(f, tick)
  local strays = 0
  for _, gid in ipairs(State.sorted_keys(f.groups)) do
    local g = f.groups[gid]
    if g.group.valid and #g.group.members > 0 then strays = strays + release_strays(f, gid, g) end
  end
  if strays > 0 and Profiler.enabled() then
    log(string.format("[FO-ATTACK] tick %d %s : %d soldat(s) retire(s) de leur groupe par le moteur, rendus a la garnison", tick, f.key, strays))
  end
  for _, gid in ipairs(State.sorted_keys(f.groups)) do
    local g = f.groups[gid]
    if not g.group.valid or #g.group.members == 0 then
      if g.state == "scout" then
        -- Lot IA2-c : éclaireur perdu en route (tués, ou retirés du groupe par le moteur : F174).
        local alive = 0
        for _, id in ipairs(g.ids or {}) do if f.soldiers[id] then alive = alive + 1 end end
        f.stats.scouts_lost = (f.stats.scouts_lost or 0) + 1
        log(string.format("[FO-PVP] eclaireur tick %d %s : perdu apres %d ticks (groupe %d, %d soldat(s) vivant(s) sur %d)", tick, f.key,
          tick - g.started, gid, alive, g.size or 1))
        if Military.on_scout_lost then Military.on_scout_lost(f, g, tick, alive) end
      end
      if g.state == "attack" and tick - g.started < DISSOLVE_TICKS then
        -- Lot IA2-a : groupe vidé juste après son départ (F174 : membres retirés par le moteur, sans mort). Moteur
        -- réel (graine 777) : relancé à chaque pensée, 328 fois en 2 h. Attente croissante avant la suivante
        -- (1, 2, 4, puis 8 min au plus), remise à zéro par une attaque qui arrive au bout.
        f.dissolved_streak = (f.dissolved_streak or 0) + 1
        local wait = ATTACK_RETRY_TICKS * ({ 1, 2, 4, 8 })[math.min(4, f.dissolved_streak)]
        f.attack_block_until = math.max(f.attack_block_until or 0, tick + wait)
        f.stats.dissolved = (f.stats.dissolved or 0) + 1
      end
      disband(f, gid)
    elseif tick - g.started > (g.rerouted and 2 * GROUP_TIMEOUT or GROUP_TIMEOUT) then
      -- Lot PNJ-VÉRIF : un retour direct trop long est traité comme un échec (retour par l'itinéraire) ; un
      -- retour par l'itinéraire a deux fois plus de temps (l'aller de 1 000 tuiles a pris 4 min en moteur réel).
      if g.state == "attack" then
        order_return(f, gid, tick)
      elseif not return_by_route(f, gid, defines.behavior_result.fail, tick) then
        disband(f, gid)
      end
    end
  end
  if f.hq and f.hq.valid then recall_far(f, tick) end
end

function Military.on_soldier_lost(f, unit_number)
  local s = f.soldiers[unit_number]
  if not s then return end
  f.soldiers[unit_number] = nil
  f.soldiers_count = f.soldiers_count - 1
  if not s.group then f.garrison_count = f.garrison_count - 1 end
  f.stats.soldiers_lost = f.stats.soldiers_lost + 1
end

--- Force de la garnison en équivalents fusiliers (pour l'estimation adverse).
--- Lot PNJ-VÉRIF (M4) : seuls les soldats proches du QG le défendent.
function Military.garrison_strength(f, strength_fn)
  return Military.garrison_near(f) * strength_fn(F.best_soldier(f.tech), f.tech, f.upgrades)
end

Events.on(defines.events.on_ai_command_completed, function(e)
  local war = State.war()
  if not war.active then return end
  -- Lot PNJ-VÉRIF : fin d'une commande née d'une distraction (combat en route) ; le groupe reprend seul la
  -- sienne. Moteur réel (24/10) : « success, was_distracted = true » pendant l'attaque, puis la vraie fin.
  if e.was_distracted then return end
  for _, id in ipairs(State.alive()) do
    local f = war.factions[id]
    local g = f.groups[e.unit_number]
    if g then
      if g.state == "attack" and g.rally and not g.rallied and e.result ~= defines.behavior_result.fail
        and g.group.valid and #g.group.members > 0 then
        -- Lot IA2-c : arrivé au rassemblement avancé : go / no-go (défense vue maintenant, crochet du chef ou du
        -- modèle du joueur). Go : attaque de zone sur le point visé ; renonce : retour (issue « renonce »).
        g.rallied = true
        if Military.on_rally(f, g, e.tick) ~= false then
          g.group.set_command({ type = defines.command.attack_area, destination = g.target, radius = F.military.attack_radius,
            distraction = defines.distraction.by_enemy })
          g.group.start_moving()
        else
          g.renonce = true
          f.stats.renonce = (f.stats.renonce or 0) + 1
          order_return(f, e.unit_number, e.tick)
        end
      elseif g.state == "scout" then
        -- Lot IA2-c : fin de l'aller d'un éclaireur (arrivé ou non) : ce qu'il a vu, puis retour.
        if Military.on_scout_done then Military.on_scout_done(f, g, e.tick, e.result ~= defines.behavior_result.fail) end
        order_return(f, e.unit_number, e.tick)
      elseif g.state == "attack" then
        -- Échec presque immédiat = commande impossible (terrain) : on ne relance pas en boucle.
        if e.result == defines.behavior_result.fail and e.tick - g.started < 600 then
          f.stats.attack_fail = (f.stats.attack_fail or 0) + 1
          f.attack_block_until = e.tick + ATTACK_RETRY_TICKS
        end
        order_return(f, e.unit_number, e.tick)
      elseif not return_by_route(f, e.unit_number, e.result, e.tick) then
        if g.rerouted and Profiler.enabled() then
          local p = g.group.valid and g.group.position
          local dx, dy = p and (p.x - f.hq_pos.x) or 0, p and (p.y - f.hq_pos.y) or 0
          log(string.format("[FO-ATTACK] tick %d %s : fin du retour par l'itineraire (%s), %d soldats a %d tuiles du QG", e.tick, f.key,
            e.result == defines.behavior_result.success and "arrive" or "echec", g.group.valid and #g.group.members or 0,
            math.floor(math.sqrt(dx * dx + dy * dy))))
        end
        disband(f, e.unit_number)
      end
      return
    end
  end
end)

return Military
