--[[
  Zone sûre du départ des factions (lot EQUILIBRE, retour du DC du 31/10 : « la safe zone de base est très proche
  des bases des factions »). Lua PUR. Mesure du retour : nids vus à 88 à 342 tuiles des QG (FO-RECO), alors que le
  QG ne dégageait que 80 tuiles et que la pollution de 2 h de jeu porte plus loin.

  Règle : tout ce qui appartient à la force « enemy » (nids, vers, unités) à moins de Z.RADIUS tuiles d'un QG est
  retiré, à la fondation du QG et à chaque chunk généré ensuite (les nids de la carte non encore créée n'arrivent
  jamais au contact). Rien d'autre n'est touché : ressources, sites garantis (lot M0) et décor restent intacts.
  Distance euclidienne au carré, entiers/flottants simples : aucune trigonométrie (déterminisme).
]]

local Z = {}

Z.OLD_RADIUS = 80       -- avant le lot EQUILIBRE (script/faction/war.lua : ENEMY_CLEAR_RADIUS)
Z.RADIUS = 256          -- tuiles : 8 chunks autour du QG
Z.CHUNK = 32

--- Carré englobant {{x0,y0},{x1,y1}} de la zone sûre d'un QG.
function Z.area(hq, radius)
  local r = radius or Z.RADIUS
  return { { hq.x - r, hq.y - r }, { hq.x + r, hq.y + r } }
end

--- Le point (x, y) est-il dans la zone sûre du QG ? (disque fermé)
function Z.inside(hq, x, y, radius)
  local r = radius or Z.RADIUS
  local dx, dy = x - hq.x, y - hq.y
  return dx * dx + dy * dy <= r * r
end

--- Un chunk (cx, cy en coordonnées de chunk) touche-t-il la zone sûre d'un QG ? (rectangle du chunk contre disque)
function Z.chunk_touches(hq, cx, cy, radius)
  local r = radius or Z.RADIUS
  local x0, y0 = cx * Z.CHUNK, cy * Z.CHUNK
  local x1, y1 = x0 + Z.CHUNK, y0 + Z.CHUNK
  local nx = math.max(x0, math.min(hq.x, x1))
  local ny = math.max(y0, math.min(hq.y, y1))
  return Z.inside(hq, nx, ny, r)
end

--- Premier QG de la liste dont la zone sûre contient le point, ou nil.
function Z.which(hqs, x, y, radius)
  for i, hq in ipairs(hqs) do
    if Z.inside(hq, x, y, radius) then return i end
  end
  return nil
end

--- Distance (au carré) du plus proche nid connu au QG, pour le journal : (nid le plus proche, distance) ou nil.
function Z.nearest(hq, nests)
  local best, bd2
  for _, n in ipairs(nests) do
    local dx, dy = n.x - hq.x, n.y - hq.y
    local d2 = dx * dx + dy * dy
    if not bd2 or d2 < bd2 then best, bd2 = n, d2 end
  end
  if not best then return nil end
  return best, math.sqrt(bd2)
end

return Z
