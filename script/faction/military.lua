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
]]

local Events = require("script.core.events")
local F = require("shared.faction.config")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")
local Profiler = require("script.core.profiler")
local PathService = require("script.core.path_service")

local Military = {}

local GROUP_TIMEOUT = 6 * 60 * 60
local GARRISON_RADIUS = 18
local ATTACK_RETRY_TICKS = 3600 -- après un échec de commande de groupe (moteur réel : 212 « attaques » mort-nées)
local UNREACHABLE_TARGET_TICKS = 36000
local ROUTE_HANDLER = "fo-war-route"
local WAYPOINT_SPACING = 64

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

--- Cible d'attaque : avant-poste le plus proche de la faction visée, sinon son QG.
function Military.target_of(target_faction, from)
  return Outposts.nearest(target_faction, from) or target_faction.hq_pos
end

--- Prépare une attaque : demande l'itinéraire (asynchrone). Le groupe part quand le chemin arrive.
function Military.attack(f, surface, target_faction, count, tick)
  if f.route_pending then return false end
  local target = Military.target_of(target_faction, f.hq_pos)
  local name = F.unit_name(f.key, F.best_soldier(f.tech))
  local gather = surface.find_non_colliding_position(name, { x = f.hq_pos.x, y = f.hq_pos.y + 14 }, 20, 1)
    or { x = f.hq_pos.x, y = f.hq_pos.y + 14 }
  f.route_pending = {
    target_faction = target_faction.id, count = count, target = target, gather = gather, tick = tick,
  }
  f.route_pending.ticket = PathService.request(ROUTE_HANDLER, f.id, {
    surface = surface.index, proto = name, pad = 0, start = gather, goal = target, force = f.force,
    radius = 16, flags = { cache = false, low_priority = false }, res = -2,
  })
  return true
end

--- Lance le groupe le long de l'itinéraire calculé.
local function launch_group(f, surface, target_faction, rp, path, tick)
  local ids = State.sorted_keys(f.soldiers)
  local chosen = {}
  for _, id in ipairs(ids) do
    if #chosen >= rp.count then break end
    local s = f.soldiers[id]
    if not s.group and s.entity.valid then chosen[#chosen + 1] = id end
  end
  if #chosen == 0 then return false end
  local group = surface.create_unit_group({ position = rp.gather, force = f.force })
  for _, id in ipairs(chosen) do
    group.add_member(f.soldiers[id].entity)
    f.soldiers[id].group = group.group_number
  end
  f.garrison_count = f.garrison_count - #chosen
  local cmds = {}
  for _, p in ipairs(waypoints_along(path)) do
    cmds[#cmds + 1] = {
      type = defines.command.go_to_location, destination = p, radius = 12,
      distraction = defines.distraction.by_enemy,
    }
  end
  cmds[#cmds + 1] = {
    type = defines.command.attack_area,
    destination = rp.target,
    radius = F.military.attack_radius,
    distraction = defines.distraction.by_enemy,
  }
  group.set_command({ type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds })
  group.start_moving()
  f.groups[group.group_number] = { group = group, state = "attack", target = rp.target, target_faction = target_faction.id, started = tick, size = #chosen }
  f.stats.attacks = f.stats.attacks + 1
  if Military.on_launched then Military.on_launched(f, target_faction, #chosen, rp, tick) end
  if Profiler.enabled() then -- journal de diagnostic (bancs de test uniquement)
    local dx, dy = rp.target.x - rp.gather.x, rp.target.y - rp.gather.y
    log(string.format("[FO-ATTACK] tick %d %s -> %s : %d soldats, %d tuiles a vol d'oiseau, chemin %d noeuds, %d etapes",
      tick, f.key, target_faction.key, #chosen, math.floor(math.sqrt(dx * dx + dy * dy)), #path, #cmds - 1))
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

local function disband(f, gid)
  local g = f.groups[gid]
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
  g.state = "return"
  g.started = tick
  g.group.set_command({
    type = defines.command.go_to_location,
    destination = { x = f.hq_pos.x, y = f.hq_pos.y + 14 },
    radius = 16,
    distraction = defines.distraction.by_enemy,
  })
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

--- Entretien périodique (appelé par le commandant) : groupes vides ou bloqués.
function Military.maintain(f, tick)
  for _, gid in ipairs(State.sorted_keys(f.groups)) do
    local g = f.groups[gid]
    if not g.group.valid or #g.group.members == 0 then
      disband(f, gid)
    elseif tick - g.started > GROUP_TIMEOUT then
      if g.state == "attack" then order_return(f, gid, tick) else disband(f, gid) end
    end
  end
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
function Military.garrison_strength(f, strength_fn)
  return f.garrison_count * strength_fn(F.best_soldier(f.tech), f.tech, f.upgrades)
end

Events.on(defines.events.on_ai_command_completed, function(e)
  local war = State.war()
  if not war.active then return end
  for _, id in ipairs(State.alive()) do
    local f = war.factions[id]
    local g = f.groups[e.unit_number]
    if g then
      if g.state == "attack" then
        -- Échec presque immédiat = commande impossible (terrain) : on ne relance pas en boucle.
        if e.result == defines.behavior_result.fail and e.tick - g.started < 600 then
          f.stats.attack_fail = (f.stats.attack_fail or 0) + 1
          f.attack_block_until = e.tick + ATTACK_RETRY_TICKS
        end
        order_return(f, e.unit_number, e.tick)
      else
        disband(f, e.unit_number)
      end
      return
    end
  end
end)

return Military
