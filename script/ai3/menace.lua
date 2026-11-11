--[[
  Lot FIX-P5 (failles 1 et 2) : unité ennemie la plus proche d'un point (menace sur un QG).
  find_nearest_enemy rend n'importe quel ennemi : un ver ou un nid plus proche masquait une vague d'unités derrière lui, et la
  réponse (défense, mise à l'abri) n'avait pas lieu. Ici, seules les UNITÉS et les PERSONNAGES des forces ennemies (force.is_enemy)
  comptent ; la plus proche parmi au plus Mn.LIMIT trouvées dans le rayon.
]]
local Mn = {}

Mn.TYPES = { "unit", "character" }
Mn.LIMIT = 32

--- Noms des forces ennemies de `force` (nom ou LuaForce), triés.
function Mn.enemy_forces(force)
  local me = type(force) == "string" and game.forces[force] or force
  local list = {}
  if not me then return list end
  for _, of in pairs(game.forces) do
    if of ~= me and of.name ~= me.name and me.is_enemy(of) then list[#list + 1] = of.name end
  end
  table.sort(list)
  return list
end

--- Unité ennemie la plus proche de `pos` à moins de `radius` tuiles, ou nil.
function Mn.nearest_unit(surface, force, pos, radius)
  local forces = Mn.enemy_forces(force)
  if #forces == 0 then return nil end
  local found = surface.find_entities_filtered({ position = pos, radius = radius, force = forces, type = Mn.TYPES,
    limit = Mn.LIMIT })
  local best, bd
  for _, u in ipairs(found) do
    if u.valid then
      local dx, dy = u.position.x - pos.x, u.position.y - pos.y
      local d = dx * dx + dy * dy
      if not bd or d < bd then best, bd = u, d end
    end
  end
  return best
end

return Mn
