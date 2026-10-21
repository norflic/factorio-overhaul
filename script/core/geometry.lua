--[[
  Géométrie déterministe.

  Pas de fonctions transcendantes (atan2, sin, cos) dans la logique de simulation : seules les opérations
  IEEE de base (+ - * / sqrt) sont garanties identiques sur toutes les plateformes d'un même multijoueur.
]]

local Geometry = {}

local T = 0.41421356237309503 -- tan(22.5°)

--- Direction 8 voies (defines.direction) du vecteur (dx, dy). Repère Factorio : y croît vers le sud.
function Geometry.direction8(dx, dy)
  local D = defines.direction
  local ax = dx < 0 and -dx or dx
  local ay = dy < 0 and -dy or dy
  if ax <= ay * T then
    return dy < 0 and D.north or D.south
  end
  if ay <= ax * T then
    return dx > 0 and D.east or D.west
  end
  if dx > 0 then
    return dy < 0 and D.northeast or D.southeast
  end
  return dy < 0 and D.northwest or D.southwest
end

function Geometry.dist2(ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  return dx * dx + dy * dy
end

return Geometry
