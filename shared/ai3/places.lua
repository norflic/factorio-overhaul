--[[
  Lot SCALE (correction après revue, 27/10) : PLACES DU QG EN RANGÉES, calculées depuis l'EMPRISE du prototype posé
  (sa collision_box, lue au runtime) : aucune position ni aucun pas écrit pour une taille de bâtiment. Revue adverse du
  lot : « les pas de 4 et 2 tuiles supposent la taille vanilla du laboratoire et du four de pierre au lieu de la lire
  dans le prototype ; or les familles du mod grandissent par niveaux (V3-T2) ».

  PUR (aucune API Factorio), aucun nom du jeu (règle anti-échelle d'IA-G, tests/iag_test.lua §8). Les DISPOSITIONS
  (origine, sens des rangées, allées, longueur des rangées, bloc de départ) sont des données justifiées de
  shared/team/config.lua (T.hq_rows) ; l'appelant lit l'emprise du prototype (Pl.tiles) et demande `need` places.

  Disposition d'une famille (spec) :
    origin = { x, y }   première place, en tuiles depuis le centre du QG (f.hq_pos) ;
    dir = { sx, sy }    sens des colonnes (sx) et des rangées (sy), +1 ou -1 ;
    gap = { gx, gy }    tuiles libres entre deux machines d'une rangée (gx) et entre deux rangées (gy : l'allée) ;
    first = { cols, n } bloc de départ : n places en rangées de cols (les places de main 0.6.1, dans leur ordre) ;
    per_row             longueur des rangées de la suite.
  Pas d'une colonne = largeur + gx ; pas d'une rangée = hauteur + gy. La liste : le bloc de départ, puis les rangées de
  per_row (places déjà données sautées), rangée par rangée, jusqu'à au moins `need` places (la rangée est finie).
  PRÉFIXE STABLE : la liste pour un `need` plus grand commence par la liste pour un `need` plus petit (une partie qui
  grandit garde l'ordre de ses places). Avec les emprises du jeu de base (four 2 × 2, laboratoire 3 × 3), la règle rend
  EXACTEMENT les places écrites avant cette correction (tests/scale_test.lua §8).

  Déterminisme : entiers ; la table des places vues est une table de recherche, jamais parcourue (aucun pairs).
]]

local Pl = {}

local function coord(p, k, i)
  if p == nil then return 0 end
  local v = p[k]
  if v == nil then v = p[i] end
  return v or 0
end

--- Emprise en tuiles (largeur, hauteur) d'une boîte de collision (BoundingBox du moteur : { left_top = {x, y},
--- right_bottom = {x, y} } ou { {x, y}, {x, y} }) : côté arrondi à la tuile supérieure, au moins 1. nil : 1 × 1.
function Pl.tiles(box)
  if box == nil then return 1, 1 end
  local lt = box.left_top or box[1]
  local rb = box.right_bottom or box[2]
  local w = math.ceil(coord(rb, "x", 1) - coord(lt, "x", 1))
  local h = math.ceil(coord(rb, "y", 2) - coord(lt, "y", 2))
  if w < 1 then w = 1 end
  if h < 1 then h = 1 end
  return w, h
end

--- Places (décalages { x, y } depuis le centre du QG) d'une famille `spec` pour une emprise w × h tuiles : au moins
--- `need` places (le bloc de départ en entier, puis des rangées entières).
function Pl.rows(spec, w, h, need)
  local px = w + spec.gap[1]
  local py = h + spec.gap[2]
  local sx, sy = spec.dir[1], spec.dir[2]
  local ox, oy = spec.origin[1], spec.origin[2]
  local out, seen = {}, {}
  local function add(c, r)
    local k = c .. ":" .. r
    if seen[k] then return end
    seen[k] = true
    out[#out + 1] = { ox + sx * c * px, oy + sy * r * py }
  end
  local fc, fn = spec.first[1], spec.first[2]
  for i = 0, fn - 1 do add(i % fc, math.floor(i / fc)) end
  local r = 0
  while #out < (need or 0) do
    for c = 0, spec.per_row - 1 do add(c, r) end
    r = r + 1
  end
  return out
end

--- Places à générer pour poser `count` machines de plus quand `have` sont déjà là : T.hq_rows_slack fois le total (une
--- place sur deux peut être prise : coffre, tourelles, foreuses, chantier).
function Pl.need(have, count, slack)
  return (slack or 1) * ((have or 0) + (count or 0))
end

return Pl
