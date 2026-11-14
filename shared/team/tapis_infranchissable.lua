--[[ s45 astar-tapis (Lua pur) : un nouveau tracé de tapis ne pose RIEN sur une tuile qui porte déjà un tapis (n'importe quel sens),
     une pièce souterraine (entrée ou sortie) ou un séparateur. Journal du DC 0.7.103 : l'A* empruntait des tapis de même sens (il
     coupait des lignes actives) et écrasait des souterrains posés.
     La règle passe par la fonction de coût de Tv.route : une tuile interdite (coût nil) ne reçoit ni tapis ni bout de souterrain,
     mais une paire neuve peut passer PAR-DESSOUS (Tv.route ne demande free() qu'aux deux bouts ; le garde de même axe reste à ug_axis).
     Les deux extrémités s et t du tracé restent exemptes (contrat des appelants : un raccord se termine sur sa cible).
     - Ti.TYPES : types d'entité infranchissables (lus du type, aucun nom d'objet).
     - Ti.tiles(boxes) -> set de clés "x,y" couvertes par des boîtes { x0, y0, x1, y1 } (coordonnées monde, bornes exclues en haut).
     - Ti.guard(cost, occupied, s, t) -> cost'(x, y) : nil si occupied(x, y) (sauf s et t), sinon cost(x, y). ]]
local Ti = {}

Ti.TYPES = { "transport-belt", "underground-belt", "splitter" }
local SET = {}
for _, ty in ipairs(Ti.TYPES) do SET[ty] = true end
function Ti.is_belt_type(ty) return SET[ty] == true end

local function key(x, y) return x .. "," .. y end
Ti.key = key

--- Tuiles couvertes par des boîtes (une boîte de séparateur couvre 2 tuiles). Une boîte vide couvre au moins la tuile de son coin.
function Ti.tiles(boxes)
  local set = {}
  for _, b in ipairs(boxes) do
    local x0, y0 = math.floor(b.x0 + 0.01), math.floor(b.y0 + 0.01)
    local x1, y1 = math.ceil(b.x1 - 0.01) - 1, math.ceil(b.y1 - 0.01) - 1
    if x1 < x0 then x1 = x0 end
    if y1 < y0 then y1 = y0 end
    for x = x0, x1 do for y = y0, y1 do set[key(x, y)] = true end end
  end
  return set
end

function Ti.guard(cost, occupied, s, t)
  if not occupied then return cost end
  return function(x, y)
    if not ((s and x == s.x and y == s.y) or (t and x == t.x and y == t.y)) and occupied(x, y) then return nil end
    return cost(x, y)
  end
end

return Ti
