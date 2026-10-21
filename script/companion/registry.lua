--[[
  Couche DONNÉES du compagnon : création, recherche et destruction des agents.

  Un agent = un enregistrement sérialisable dans le stockage + un corps physique (entité fo-companion).
  Les autres couches (cerveau, locomotion, rendu) s'abonnent à Registry.on_removed pour nettoyer leur état :
  le registre ne connaît aucune d'entre elles.

  Piège moteur vérifié (doc 1.1.91, LuaEntity::associated_player) : un character ASSOCIÉ à un joueur est
  déconnecté avec lui en multijoueur. Les corps de compagnons ne sont donc jamais associés ; le
  propriétaire est mémorisé ici (agent.owner = index du joueur).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local C = require("script.companion.constants")

local Registry = {}

local removed_hooks = {}
local spawned_hooks = {}

local PALETTE = {
  { r = 0.95, g = 0.55, b = 0.10 }, { r = 0.20, g = 0.70, b = 0.95 }, { r = 0.45, g = 0.85, b = 0.30 },
  { r = 0.90, g = 0.30, b = 0.60 }, { r = 0.95, g = 0.85, b = 0.20 }, { r = 0.60, g = 0.45, b = 0.95 },
}

Storage.declare("companion", function()
  return {
    agents = {}, by_unit = {}, next_id = 0, count = 0,
    stats = { dist = 0, move_ticks = 0, stuck = 0, path_fail = 0, since = 0 },
  }
end)

function Registry.on_removed(fn)
  removed_hooks[#removed_hooks + 1] = fn
end

function Registry.on_spawned(fn)
  spawned_hooks[#spawned_hooks + 1] = fn
end

--- Crée un agent près de `position`. Retourne l'agent ou nil si aucune place libre.
function Registry.spawn(surface, position, force, owner_index, opts)
  local pos = surface.find_non_colliding_position(C.BODY, position, 16, 0.5)
  if not pos then return nil end
  local e = surface.create_entity({ name = C.BODY, position = pos, force = force })
  if not e then return nil end

  local S = Storage.ns("companion")
  S.next_id = S.next_id + 1
  local id = S.next_id
  e.color = opts.color or PALETTE[(id - 1) % #PALETTE + 1]

  local agent = {
    id = id,
    entity = e,
    unit = e.unit_number,
    surface = surface.index,
    owner = owner_index,
    machine = opts.machine,
    faction = opts.faction,
    behavior = opts.behavior or "wander",
    home = { x = pos.x, y = pos.y },
    wander_radius = opts.wander_radius or 32,
    state = "none",
    state_tick = game.tick,
    -- locomotion
    path = nil, wp = 0, wpn = 0, dir = -1,
    -- cerveau
    goal = nil, ticket = 0, pause_until = 0, stuck = 0,
    last_x = pos.x, last_y = pos.y, last_check = game.tick,
    -- rendu
    label = nil,
  }
  S.agents[id] = agent
  S.by_unit[e.unit_number] = id
  S.count = S.count + 1
  script.register_on_entity_destroyed(e)
  for i = 1, #spawned_hooks do spawned_hooks[i](agent) end
  return agent
end

function Registry.get(id)
  return Storage.ns("companion").agents[id]
end

function Registry.count()
  return Storage.ns("companion").count
end

function Registry.stats()
  return Storage.ns("companion").stats
end

--- Identifiants triés (itération déterministe et indépendante de pairs).
function Registry.ids()
  local ids = {}
  for id in pairs(Storage.ns("companion").agents) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

function Registry.remove(id, destroy_entity)
  local S = Storage.ns("companion")
  local agent = S.agents[id]
  if not agent then return end
  S.agents[id] = nil
  if agent.unit then S.by_unit[agent.unit] = nil end
  S.count = S.count - 1
  for i = 1, #removed_hooks do removed_hooks[i](agent) end
  if destroy_entity and agent.entity.valid then agent.entity.destroy() end
end

--- Causes de mort observées : { ["cause/force:type_de_degats"] = n } (diagnostic moteur réel).
function Registry.deaths()
  return Storage.ns("companion").deaths or {}
end

function Registry.sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

Events.on(defines.events.on_entity_died, function(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.type == "character") then return end
  local S = Storage.ns("companion")
  if not S.by_unit[ent.unit_number] then return end
  local cause = "aucune"
  if e.cause and e.cause.valid then cause = e.cause.name .. "/" .. e.cause.force.name end
  local key = cause .. ":" .. (e.damage_type and e.damage_type.name or "?")
  S.deaths = S.deaths or {}
  S.deaths[key] = (S.deaths[key] or 0) + 1
end)

-- Mort, minage ou destruction par un autre mod : le corps disparaît, l'agent aussi.
Events.on(defines.events.on_entity_destroyed, function(e)
  if not e.unit_number then return end
  local id = Storage.ns("companion").by_unit[e.unit_number]
  if id then Registry.remove(id, false) end
end)

return Registry
