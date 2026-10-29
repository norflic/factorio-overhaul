--[[
  RANGEES (lot AGENCEMENT, retour du DC du 29/10 en jouant la 0.6.16) : foreuses en RANGEES qui couvrent le gisement.
  PUR : aucune API Factorio, aucun nom d'objet (côtés, portées et débits arrivent en DONNÉES : tests/iag_test.lua §8).

  Le DC : « pas de maximisation au niveau des gisements. Toujours pareil, vraiment ces quatre foreuses [...] Non non, là on veut
  des rangées de foreuses en fait, c'est ça qu'il faut. » Une ligne de foreuses du plan directeur (générateur « drills » de
  shared/team/modules.lua) est DÉJÀ une double rangée de part et d'autre d'un tapis collecteur ; ce qui la gardait à 4
  foreuses, c'est sa taille : n paires = le débit des fours demandés (jamais le gisement). Ce module décide :

  Rg.reach(radius, side)                         -> tuiles minées au-delà du corps d'une foreuse (portée de minage).
  Rg.area(side, n, reach)                        -> tuiles minées par une ligne de n paires.
  Rg.pairs_for_tiles(tiles, side, reach, cover, max_pairs)
                                                 -> la plus longue ligne dont la zone minée porte du minerai sur au moins `cover`
                                                    de ses tuiles, d'après les tuiles de minerai du lot (0 : même une paire non).
  Rg.rows_for_pairs(pairs, drill_rate, cap)      -> rangées de fours (2 fours chacune) qu'absorbent `pairs` paires de foreuses.
  Rg.pairs_for_rows(rows, drill_rate, cap)       -> paires de foreuses qui nourrissent `rows` rangées de fours.
  Rg.attempts(top, bottom, covers)               -> liste ordonnée d'essais { n, cover } pour poser la ligne : d'abord les plus
                                                    longues lignes à la couverture visée (80 %), puis toutes les tailles à la
                                                    couverture minimale (celle d'avant : jamais pire).
]]
local R = {}

local EPS = 1e-9
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

R.COVER_HIGH = 0.8  -- « 80 % des tuiles quand c'est possible » (DC)
R.LADDER_STEPS = 3  -- tailles essayées à la couverture visée (chaque essai relit les lots : coût borné)

--- Tuiles minées au-delà du corps d'une foreuse de côté `side` et de rayon de minage `radius` (le corps occupe les tuiles
--- 0 à side−1, centré sur side/2) : même calcul que M.resource_tiles (floor(c − r) à ceil(c + r) − 1).
function R.reach(radius, side)
  if type(radius) ~= "number" or type(side) ~= "number" or side < 1 then return 0 end
  local c = side / 2
  local lo = floor(c - radius + EPS)
  local hi = ceil(c + radius - EPS) - 1
  return max(0, -lo, hi - (side - 1))
end

--- Zone minée d'une ligne de n paires : la largeur couvre les deux colonnes de foreuses et le tapis (2·side + 1) ; la longueur
--- n·side ; la portée déborde de `reach` de chaque côté.
function R.area(side, n, reach)
  return (2 * side + 1 + 2 * reach) * (n * side + 2 * reach)
end

--- Plus grand n ≤ max_pairs dont la zone minée a au moins `cover` de ses tuiles en minerai, d'après `tiles` (tuiles de minerai
--- du lot). L'aire croît avec n : balayage de 1 à max_pairs, arrêt au premier n qui ne tient plus.
function R.pairs_for_tiles(tiles, side, reach, cover, max_pairs)
  if type(tiles) ~= "number" or tiles <= 0 or type(max_pairs) ~= "number" then return 0 end
  local best = 0
  for n = 1, floor(max_pairs + EPS) do
    if cover * R.area(side, n, reach) <= tiles + EPS then best = n else break end
  end
  return best
end

--- Rangées de fours (2 fours par rangée) absorbées par `pairs` paires de foreuses (2 foreuses par paire) : `drill_rate` objets/s
--- par foreuse, `cap` objets/s absorbés par un four. Arrondi PAR DÉFAUT : les fours ne dépassent jamais ce que les foreuses
--- livrent (pairs_for_rows(rows_for_pairs(p)) ≤ p).
function R.rows_for_pairs(pairs, drill_rate, cap)
  if type(pairs) ~= "number" or type(drill_rate) ~= "number" or type(cap) ~= "number" or pairs <= 0 or drill_rate <= 0 or cap <= 0 then return 0 end
  return floor(pairs * drill_rate / cap + EPS)
end

--- Paires de foreuses qui nourrissent `rows` rangées de fours (arrondi par excès : aucun four privé de minerai).
function R.pairs_for_rows(rows, drill_rate, cap)
  if type(rows) ~= "number" or type(drill_rate) ~= "number" or type(cap) ~= "number" or rows <= 0 or drill_rate <= 0 or cap <= 0 then return 0 end
  return max(1, ceil(rows * cap / drill_rate - EPS))
end

--- Tailles essayées à la couverture visée : `top`, le milieu de `top` et `bottom` (arrondi par excès), puis `bottom` (au moins
--- 1), strictement décroissantes et sans doublon, au plus `steps` (3 par défaut : chaque essai relit les lots du gisement).
function R.ladder(top, bottom, steps)
  top = floor((top or 0) + EPS)
  bottom = max(1, floor((bottom or 1) + EPS))
  if top < bottom then top = bottom end
  local want = { top, ceil((top + bottom) / 2 - EPS), bottom }
  local out, last = {}, math.huge
  for _, n in ipairs(want) do
    if n < last and #out < (steps or R.LADDER_STEPS) then out[#out + 1] = n; last = n end
  end
  return out
end

--- Essais ordonnés { n, cover } (cover = nil : la couverture minimale du plan, P.DRILL_COVER). Phase 1 : l'échelle de tailles
--- (de `top` à `bottom`) à la couverture visée `covers.high` ; phase 2 : TOUTES les tailles de `top` à 1 à la couverture
--- minimale, c'est-à-dire exactement l'ancien parcours (n, n−1, … 1), pour ne jamais faire moins qu'avant.
function R.attempts(top, bottom, covers)
  local high = covers and covers.high or R.COVER_HIGH
  top = max(1, floor((top or 1) + EPS))
  local out = {}
  for _, n in ipairs(R.ladder(top, min(bottom or 1, top), R.LADDER_STEPS)) do out[#out + 1] = { n = n, cover = high } end
  for n = top, 1, -1 do out[#out + 1] = { n = n, cover = nil } end
  return out
end

return R
