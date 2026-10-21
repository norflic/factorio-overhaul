--[[
  État persistant de la guerre des factions + registre de propriété des entités.

  war = {
    active, started, surface, settings = { soldiers_max, engineers_max, distance, think_period },
    factions = { [id] = faction }, by_force = { [nom de force] = id },
    owners = { [unit_number] = { f = id, kind = "hq"|"drill"|"turret"|"soldier", oid = id_avant_poste } },
    claims = { [clé de site] = id_faction },
  }
  faction = {
    id, key, force, personality, color, hq, hq_pos, rival, label, eliminated,
    mu, tech, upgrades, last_think, threatened_until, sites_blocked_until,
    engineers = { [agent_id] = true }, engineers_count,
    outposts = { [oid] = { id, pos, key, drills, entities = {...}, turrets = {...} } }, outposts_count, next_oid, pending,
    turrets = { [unit_number] = entity },
    soldiers = { [unit_number] = { entity, group } }, soldiers_count, garrison_count,
    groups = { [group_number] = { group, state, target, started, size } },
    stats = { attacks, outposts_built, outposts_lost, soldiers_lost, kills },
  }
]]

local Storage = require("script.core.storage")

local State = {}

Storage.declare("war", function()
  return { active = false, started = 0, surface = nil, settings = {}, factions = {}, by_force = {}, owners = {}, claims = {} }
end)

function State.war()
  return Storage.ns("war")
end

Storage.declare("pteam", function() return { team = nil } end)

--- Faction IA (id numérique) ou équipe du joueur (id "player", namespace "pteam").
function State.faction(id)
  if id == "player" then return Storage.ns("pteam").team end
  return Storage.ns("war").factions[id]
end

function State.by_force(name)
  local w = Storage.ns("war")
  local id = w.by_force[name]
  return id and w.factions[id] or nil
end

--- Identifiants des factions encore en vie, triés.
function State.alive()
  local ids = {}
  for id, f in pairs(Storage.ns("war").factions) do
    if not f.eliminated then ids[#ids + 1] = id end
  end
  table.sort(ids)
  return ids
end

--- Enregistre la propriété d'une entité et s'abonne à sa destruction.
function State.own(entity, faction_id, kind, oid)
  if not (entity and entity.valid and entity.unit_number) then return end
  Storage.ns("war").owners[entity.unit_number] = { f = faction_id, kind = kind, oid = oid }
  script.register_on_entity_destroyed(entity)
end

function State.owner(unit_number)
  return unit_number and Storage.ns("war").owners[unit_number] or nil
end

function State.disown(unit_number)
  Storage.ns("war").owners[unit_number] = nil
end

--- Clé NUMÉRIQUE de chunk. Moteur réel (session 3) : la clé chaîne "cx:cy" coûtait ~4 µs par lookup
--- (conversion nombre -> chaîne), soit 88 % du coût de la prospection. Valable pour |cx|, |cy| < 32768.
function State.chunk_key(cx, cy)
  return (cx + 32768) * 65536 + (cy + 32768)
end

function State.site_key(pos)
  return State.chunk_key(math.floor(pos.x / 32), math.floor(pos.y / 32))
end

--- Clés triées d'une table (itération déterministe).
function State.sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

return State
