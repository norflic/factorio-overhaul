--[[
  Lot NAV2 (3/11) : point d'accès d'un avant-poste ATTEIGNABLE depuis l'extérieur de son champ.

  Défaut (lot CHARBON-MAIN, partie lot-271828182) : la tournée d'Écarlate vers son avant-poste de charbon de 29 foreuses rend 90 fois
  « chemin introuvable (no_path) » ; but libre pour le corps, sol sans eau ; 29 foreuses à sec à côté de 2 265 charbons. Toutes
  équipes : 1 700 refus « inaccessible » dans la partie (tournées, agrandissements, fortifications).
  Cause MESURÉE (banc nav2-marge, moteur réel) : le point d'accès d'un avant-poste est l'endroit où se tenait le bâtisseur ; les
  agrandissements posent les paires foreuse + réceptacle, jointives, tout autour : le point d'accès finit dans une POCHE fermée par
  les emprises. Chemin vers ce point : 0 sur 8 avec la boîte élargie, 0 sur 8 sans marge, 0 sur 8 en grille fine ; avec un rayon
  d'arrivée de 7 tuiles : 3 sur 8 (fin de chemin à 7 tuiles, au bord du champ).
  Règle : on remplit (4-voisinage) les tuiles libres d'un rectangle qui entoure le champ, depuis son bord ; si le point d'accès n'est
  pas atteint, le but de la marche devient la tuile atteinte la plus proche (distance au carré, puis y, puis x). Une tuile est
  bloquée si une boîte la recouvre au sens strict (shared/team/pose_paires.lua, F96) ou si elle est dans la liste donnée (eau).
  Modèle PRUDENT : un interstice plus étroit qu'une tuile ne compte pas comme un passage (le pathfinder ne l'a pas pris au banc).
  PUR : aucune API Factorio, aucun nom d'objet ; le runtime donne les boîtes, les tuiles bloquées et le rectangle.
]]
local Paires = require("shared.team.pose_paires")

local A = {}

A.MARGIN = 3      -- tuiles libres laissées autour des bâtiments de l'avant-poste (le bord du rectangle, d'où part le remplissage)
A.MAX_SIDE = 200  -- garde-fou : rectangle plus grand non parcouru (l'accès reste tel quel)
A.FIELD_RADIUS = 32 -- tuiles autour du centre de l'avant-poste où les bâtiments de l'équipe comptent dans le rectangle (= rayon
                    -- d'agrandissement, shared/team/pose_paires.lua EXTEND_RADIUS) : un champ passé à l'électrique n'est plus dans les
                    -- listes de l'avant-poste

local key = Paires.key
local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }

--- Rectangle en tuiles (x0, y0, x1, y1 inclus) qui entoure les boîtes { lx, ty, rx, by } et le point `p`, élargi de `margin`.
function A.rect(boxes, p, margin)
  local lx, ty, rx, by = p.x, p.y, p.x, p.y
  for _, b in ipairs(boxes) do
    if b[1] < lx then lx = b[1] end
    if b[2] < ty then ty = b[2] end
    if b[3] > rx then rx = b[3] end
    if b[4] > by then by = b[4] end
  end
  return { math.floor(lx) - margin, math.floor(ty) - margin, math.ceil(rx) - 1 + margin, math.ceil(by) - 1 + margin }
end

--- Point d'accès atteignable. boxes : { { lx, ty, rx, by }, ... } (obstacles du rectangle) ; tiles : { { x, y }, ... } (tuiles
--- bloquées) ; access : { x, y } ; rect : { x0, y0, x1, y1 } (tuiles, inclus).
--- Rend { x, y, moved, enclosed, reached } : moved = le but a changé (centre de la tuile choisie) ; enclosed = l'accès n'est pas
--- atteint depuis le bord ; reached = tuiles atteintes. Sans tuile atteinte, ou rectangle trop grand : l'accès tel quel.
function A.reach(boxes, tiles, access, rect)
  local x0, y0, x1, y1 = rect[1], rect[2], rect[3], rect[4]
  if x1 < x0 or y1 < y0 or x1 - x0 > A.MAX_SIDE or y1 - y0 > A.MAX_SIDE then
    return { x = access.x, y = access.y, moved = false, enclosed = false, reached = 0 }
  end
  local blocked = {}
  for _, b in ipairs(boxes) do
    for _, k in ipairs(Paires.box_tiles(b[1], b[2], b[3], b[4])) do blocked[k] = true end
  end
  for _, t in ipairs(tiles or {}) do blocked[key(math.floor(t.x), math.floor(t.y))] = true end
  local seen, list = {}, {}
  local function push(x, y)
    local k = key(x, y)
    if seen[k] or blocked[k] then return end
    seen[k] = true
    list[#list + 1] = { x, y }
  end
  -- bord du rectangle, dans un ordre fixe (haut, bas, gauche, droite)
  for x = x0, x1 do push(x, y0) push(x, y1) end
  for y = y0 + 1, y1 - 1 do push(x0, y) push(x1, y) end
  local i = 1
  while i <= #list do
    local c = list[i]
    i = i + 1
    for _, d in ipairs(DIRS) do
      local nx, ny = c[1] + d[1], c[2] + d[2]
      if nx >= x0 and nx <= x1 and ny >= y0 and ny <= y1 then push(nx, ny) end
    end
  end
  local ax, ay = math.floor(access.x), math.floor(access.y)
  if seen[key(ax, ay)] then
    return { x = access.x, y = access.y, moved = false, enclosed = false, reached = #list }
  end
  local best, bd
  for _, c in ipairs(list) do
    local dx, dy = c[1] + 0.5 - access.x, c[2] + 0.5 - access.y
    local d = dx * dx + dy * dy
    if not best or d < bd or (d == bd and (c[2] < best[2] or (c[2] == best[2] and c[1] < best[1]))) then best, bd = c, d end
  end
  if not best then return { x = access.x, y = access.y, moved = false, enclosed = true, reached = 0 } end
  return { x = best[1] + 0.5, y = best[2] + 0.5, moved = true, enclosed = true, reached = #list }
end

return A
