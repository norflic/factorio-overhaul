--[[
  Lot QGSURVIE2 : journal [FO-QG-TOURELLE] à la mort d'une tourelle d'équipe à moins de Q.QG_R tuiles de son QG (règle pure et ligne :
  shared/team/qg_tourelle.lua). LECTURE SEULE : aucune décision n'en dépend, rien dans global, aucun appel qui change la partie.
  Abonnement au bus d'événements au niveau du fichier (chargé par script/team/survie_qg.lua : control.lua inchangé). Coût : un test de
  type par mort, puis trois recherches d'entités pour une tourelle du QG seulement.
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local Rg = require("shared.ai3.reglages")
local Q = require("shared.team.qg_tourelle")

local TURRET = {}
for _, ty in ipairs(Rg.TURRET_TYPES) do TURRET[ty] = true end
local SUPPORT_R = 40 -- tuiles : tourelles cherchées autour de la cause (au-delà de toute portée de tourelle de base)

local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

local function range_of(ent)
  local ok, r = pcall(function() return ent.prototype.attack_parameters.range end)
  return ok and r or nil
end

local function rounds_of(t)
  if t.type ~= "ammo-turret" then return nil end
  local inv = t.get_inventory(defines.inventory.turret_ammo)
  return inv and inv.get_item_count() or 0
end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function on_died(e)
  local ent = e.entity
  if not (ent and ent.valid and TURRET[ent.type]) then return end
  local force = ent.force and ent.force.name
  local f = force and team_of(force)
  local hq = f and (f.hq_pos or (f.hq and f.hq.valid and f.hq.position))
  if not hq then return end
  local pos, surface = ent.position, ent.surface
  if dist(pos, hq) > Q.QG_R then return end
  local un = ent.unit_number
  local rec = { minute = e.tick / 3600, team = f.key or force, name = ent.name, dx = pos.x - hq.x, dy = pos.y - hq.y,
    rounds = rounds_of(ent), range = range_of(ent), damage = e.damage_type and e.damage_type.name or nil, support = {}, units = {} }
  local c = e.cause
  if c and c.valid then
    rec.cause = { name = c.name, type = c.type, force = c.force and c.force.name or nil }
    rec.cause_dist = dist(c.position, pos)
    rec.cause_range = range_of(c)
    for _, t in ipairs(surface.find_entities_filtered({ position = c.position, radius = SUPPORT_R, force = ent.force, type = Rg.TURRET_TYPES })) do
      if t.unit_number ~= un then
        rec.support[#rec.support + 1] = { dist = dist(t.position, c.position), range = range_of(t), rounds = rounds_of(t) }
      end
    end
  end
  local left, armed = 0, 0
  for _, t in ipairs(surface.find_entities_filtered({ position = hq, radius = Q.QG_R, force = ent.force, type = Rg.TURRET_TYPES })) do
    if t.unit_number ~= un then
      left = left + 1
      local r = rounds_of(t)
      if r == nil or r > 0 then armed = armed + 1 end
    end
  end
  rec.qg_left, rec.qg_armed = left, armed
  local sx, sy, n = 0, 0, 0
  for _, u in ipairs(surface.find_entities_filtered({ position = pos, radius = Q.WAVE_R, force = "enemy", type = "unit" })) do
    rec.units[u.name] = (rec.units[u.name] or 0) + 1
    sx, sy, n = sx + u.position.x, sy + u.position.y, n + 1
  end
  if n > 0 then rec.wave_dx, rec.wave_dy = sx / n - hq.x, sy / n - hq.y end
  log(Q.line(rec))
end

-- Lot MORTS : les types de tourelle (ceux du test TURRET ci-dessus), jamais la force « enemy » (team_of : player ou une faction).
Events.on_died(on_died, { types = Rg.TURRET_TYPES, ennemi = false })

return {}
