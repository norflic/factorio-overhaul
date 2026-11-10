--[[
  Lot MALL-DIRECTIONS (directive du DC du 10/11, priorité 2 : « autorise l'extension du Mall en série vers toutes les directions
  cardinales, et non plus uniquement vers l'Est ») : la DIRECTION d'une série de mall (ruban en sections de lot en lot, rangée de
  cellules) est une décision PURE et déterministe : parmi les quatre lots voisins du lot courant dans le treillis, ceux qui sont libres,
  rangés par continuité (la direction déjà prise par la série), puis distance au bus (le point de collecte : QG ou tête de bus), puis
  l'ordre canonique est, sud, ouest, nord. Aucune API du jeu, aucun nom d'objet, aucun `pairs` : testé hors jeu (tests/serie_dirs_test.lua).

  Conventions : directions du moteur (0 nord, 2 est, 4 sud, 6 ouest) ; k = quarts de tour horaires qui envoient l'est sur la direction
  (Sd.frame, l'inverse de Sd.dir_of) ; le repère canonique d'un gabarit ou d'une rangée va vers l'est (+x), ses lignes de corridor sont
  des décalages `y` en travers (Sd.cross les suit dans la rotation).
]]

local Sd = {}

Sd.DIRS = { 2, 4, 6, 0 } -- ordre canonique : est, sud, ouest, nord
Sd.DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
Sd.NOM = { [0] = "nord", [2] = "est", [4] = "sud", [6] = "ouest" }
Sd.NAME = { [0] = "north", [2] = "east", [4] = "south", [6] = "west" }

local function is_dir(d) return d == 0 or d == 2 or d == 4 or d == 6 end

--- Quarts de tour horaires qui envoient l'est sur `dir` (0, 1, 2, 3).
function Sd.frame(dir)
  if not is_dir(dir) then error("contrat : direction 0, 2, 4 ou 6 attendue (" .. tostring(dir) .. ")", 2) end
  return ((dir - 2) % 8) / 2
end

--- Direction de l'est tourné de k quarts de tour.
function Sd.dir_of(k) return (2 + 2 * (k % 4)) % 8 end

--- Décalage EN TRAVERS d'une ligne de corridor après rotation : dans le repère canonique (largeur w, hauteur h) la ligne est la rangée
--- de tuiles y = off ; après k quarts de tour horaires (M.rotate : (x, y) -> (h - y, x)), elle devient une colonne (k impair) ou une rangée
--- (k pair) dont l'indice en travers de l'axe de la série est : k = 0 : off ; k = 1 : h − 1 − off ; k = 2 : h − 1 − off ; k = 3 : off.
function Sd.cross(off, k, h)
  k = k % 4
  if k == 1 or k == 2 then return h - 1 - off end
  return off
end

--- Lot voisin de { i, j } dans la direction `dir`.
function Sd.voisin(lot, dir)
  local v = Sd.DV[dir]
  if not v then error("contrat : direction 0, 2, 4 ou 6 attendue (" .. tostring(dir) .. ")", 2) end
  return { i = lot.i + v[1], j = lot.j + v[2] }
end

--- Candidats : les quatre voisins de `lot` = { i, j }, rangés. `rect_of(i, j) -> x0, y0, x1, y1` (le rectangle du lot, x1/y1 exclus) ;
--- `occupation(i, j) -> libre (bool), cause (texte)` (nil, cause : hors du treillis) ; opts = { prefer = direction déjà prise (d'abord),
--- bus = { x, y } (le plus proche du centre du lot d'abord), key = fn(i, j) -> clé du lot (défaut « i:j ») }.
--- Rend (cands = { { dir, nom, k, i, j, key, rect = { x0, y0, x1, y1 }, d } }, refus = { { dir, nom, cause } }). Ordre stable : préférée,
--- distance croissante, ordre canonique ; aucune égalité ne dépend d'une table.
function Sd.candidats(lot, rect_of, occupation, opts)
  opts = opts or {}
  local cands, refus = {}, {}
  for rank, dir in ipairs(Sd.DIRS) do
    local v = Sd.voisin(lot, dir)
    local libre, cause = occupation(v.i, v.j)
    if libre then
      local x0, y0, x1, y1 = rect_of(v.i, v.j)
      local d = 0
      if opts.bus then d = math.abs((x0 + x1) / 2 - opts.bus.x) + math.abs((y0 + y1) / 2 - opts.bus.y) end
      cands[#cands + 1] = { dir = dir, nom = Sd.NOM[dir], k = Sd.frame(dir), i = v.i, j = v.j, key = (opts.key or Sd.key)(v.i, v.j),
        rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, d = d, rank = rank, prefer = (dir == opts.prefer) }
    else
      refus[#refus + 1] = { dir = dir, nom = Sd.NOM[dir], cause = cause or "occupe" }
    end
  end
  table.sort(cands, function(a, b)
    if a.prefer ~= b.prefer then return a.prefer end
    if a.d ~= b.d then return a.d < b.d end
    return a.rank < b.rank
  end)
  return cands, refus
end

function Sd.key(i, j) return i .. ":" .. j end

--- Le premier candidat, ou nil et la raison écrite (une cause par direction refusée).
function Sd.choisir(cands, refus)
  if cands and cands[1] then return cands[1] end
  local parts = {}
  for _, r in ipairs(refus or {}) do parts[#parts + 1] = r.nom .. " : " .. tostring(r.cause) end
  return nil, "aucun lot voisin libre (" .. table.concat(parts, ", ") .. ")"
end

--- Rotations (k) à essayer pour la première section d'une série, dans l'ordre des candidats : la série ira vers le premier voisin libre.
--- Sans candidat, les quatre dans l'ordre canonique (le gabarit se pose, la série s'arrêtera proprement).
function Sd.rotations(cands)
  local out, seen = {}, {}
  for _, c in ipairs(cands or {}) do
    if not seen[c.k] then seen[c.k] = true; out[#out + 1] = c.k end
  end
  for _, dir in ipairs(Sd.DIRS) do
    local k = Sd.frame(dir)
    if not seen[k] then seen[k] = true; out[#out + 1] = k end
  end
  return out
end

--- Projection d'un point le long d'une direction (le plus avancé a la plus grande valeur).
function Sd.along(x, y, dir)
  local v = Sd.DV[dir]
  return x * v[1] + y * v[2]
end

return Sd
