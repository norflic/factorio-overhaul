--[[
  Lot INSTRUMENT-CENTRALE : journal [FO-CENTRALE-MORT] à la mort d'une chaudière, d'une machine à vapeur ou d'une pompe de rive d'une
  équipe (types du moteur : shared/ai3/reglages.lua, Rg.PLANT_TYPES). LECTURE SEULE : aucune décision n'en dépend, rien dans global,
  aucun appel qui change la partie. La ligne est faite par la règle pure shared/team/centrale_mort.lua.
  Abonnement au bus d'événements, au niveau du fichier (ce module est chargé par script/team/plant_arms.lua, lui-même chargé par
  build.lua : control.lua inchangé). Coût : un test de type par mort.
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local Rg = require("shared.ai3.reglages")
local C = require("shared.team.centrale_mort")

local PLANT, TURRET = {}, {}
for _, ty in ipairs(Rg.PLANT_TYPES) do PLANT[ty] = true end
for _, ty in ipairs(Rg.TURRET_TYPES) do TURRET[ty] = true end

local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

local function dist(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return math.sqrt(dx * dx + dy * dy)
end

local function hq_pos(f)
  if f.hq_pos then return f.hq_pos end
  if f.hq and f.hq.valid then return f.hq.position end
  return nil
end

local function on_died(e)
  local ent = e.entity
  if not (ent and ent.valid and PLANT[ent.type]) then return end
  local force = ent.force and ent.force.name
  local f = force and team_of(force)
  if not f then return end
  local pos, surface = ent.position, ent.surface
  local rec = { minute = e.tick / 3600, force = force, type = ent.type, name = ent.name, x = pos.x, y = pos.y,
    killer_force = e.force and e.force.name or nil, damage = e.damage_type and e.damage_type.name or nil }
  local c = e.cause
  if c and c.valid then rec.cause = { name = c.name, type = c.type, force = c.force and c.force.name or nil } end
  local hq = hq_pos(f)
  if hq then rec.hq_dist = dist(pos.x, pos.y, hq.x, hq.y) end
  rec.turrets = {}
  for _, t in ipairs(surface.find_entities_filtered({ position = pos, radius = C.TURRET_R, force = ent.force, type = Rg.TURRET_TYPES })) do
    local kind, rounds = "fluide", nil
    if t.type == "ammo-turret" then
      kind = "munitions"
      local inv = t.get_inventory(defines.inventory.turret_ammo)
      rounds = inv and inv.get_item_count() or 0
    elseif t.type == "electric-turret" then
      kind = "electrique"
    end
    rec.turrets[#rec.turrets + 1] = { kind = kind, rounds = rounds, dist = dist(pos.x, pos.y, t.position.x, t.position.y) }
  end
  local en = surface.find_nearest_enemy({ position = pos, max_distance = C.ENEMY_R, force = ent.force })
  if en and en.valid then
    rec.enemy = { type = en.type, name = en.name, dist = dist(pos.x, pos.y, en.position.x, en.position.y) }
  end
  log(C.line(rec))
end

Events.on(defines.events.on_entity_died, on_died)

return {}
