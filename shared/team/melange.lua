--[[
  MELANGE (retour du DC du 3/11, 2 h 30 de jeu) : « les foreuses récoltent sur une zone, dans cette zone il est possible qu'il y ait
  2 minerais ou plus [...] lorsque le four a environ 5 de charbon, il n'est plus mis dedans, et les minerais de charbon prennent la
  place des minerais de fer sur les convoyeurs [...] Ce qu'il faut faire est dans un premier temps d'analyser la zone couverte par
  les foreuses pour ne plus faire cette erreur. »
  PUR : aucune API Factorio, aucun nom d'objet (les noms arrivent en DONNÉES : tests/iag_test.lua §8 bis).

  Zone d'une foreuse (règle du moteur) : carré de côté 2 × rayon (resource_searching_radius du prototype) centré sur la foreuse ; une
  ressource est minée si son CENTRE (milieu de tuile) y tombe. Foreuse électrique de base : corps 3 × 3, rayon 2,49 -> 5 × 5 tuiles
  (portée 1 au-delà du corps) ; niveaux agrandis : rayon 2,49 + (côté − 3) / 2 -> portée 1 ; foreuse thermique : 2 × 2, rayon 0,99 ->
  portée 0.

  M.reach(size, radius)                    -> tuiles minées au-delà du corps, de chaque côté
  M.zone(x0, y0, size, reach)              -> x0, y0, x1, y1 (inclusifs) : tuiles minées d'une foreuse dont le corps part de (x0, y0)
  M.in_zone(dx, dy, radius)                -> le centre d'une ressource décalé de (dx, dy) du centre de la foreuse est-il miné
  M.count(x0, y0, x1, y1, pred)            -> tuiles du rectangle où pred(x, y) est vrai
  M.zone_verdict(found, targets)           -> "ok" | "melange", { { name, n } } étrangers triés ; found = { { name, n } } des ressources
                                              MINABLES vues dans la zone (celles que la foreuse ne sait pas miner n'y sont pas)
  M.belt_items(ore, products, carried)     -> { [nom] = true } : objets ADMIS sur les tapis d'une bande (minerai, produit fondu, charbon de la colonne)
  M.belt_verdict(contents, targets)        -> { target, foreign, clear = { { name, n } } triée, majority } ; contents = { [nom] = n }
  Déterminisme : listes triées par nom, entiers, aucune trigonométrie.
]]

local M = {}

M.EPS = 1e-9

--- Tuiles minées au-delà du corps : la j-ième tuile hors du corps a son centre à côté / 2 − 0,5 + j du centre ; minée si < rayon.
function M.reach(size, radius)
  if not (size and radius) or size <= 0 then return 0 end
  local j = math.ceil(radius - size / 2 + 0.5 - M.EPS) - 1
  return math.max(0, j)
end

function M.zone(x0, y0, size, reach)
  return x0 - reach, y0 - reach, x0 + size - 1 + reach, y0 + size - 1 + reach
end

function M.in_zone(dx, dy, radius)
  return math.abs(dx) < radius - M.EPS and math.abs(dy) < radius - M.EPS
end

function M.count(x0, y0, x1, y1, pred)
  local n = 0
  for x = x0, x1 do for y = y0, y1 do if pred(x, y) then n = n + 1 end end end
  return n
end

local function by_name(a, b) return a[1] < b[1] end

--- `targets` : { [nom] = true } (le minerai de la bande, ou les produits de sa ressource).
function M.zone_verdict(found, targets)
  local out = {}
  for _, it in ipairs(found or {}) do
    if it[2] and it[2] > 0 and not targets[it[1]] then out[#out + 1] = { it[1], it[2] } end
  end
  table.sort(out, by_name)
  return #out > 0 and "melange" or "ok", out
end

--- Objets admis sur les tapis d'une bande : le minerai visé (`ore`, { [nom] = true }), le PRODUIT de sa ressource (`products`, liste de
--- noms : la colonne à tapis porte ses plaques sur un tapis `champ-tapis`, MELANGE2 B1 : retirées, elles volaient la production de la
--- fonderie) et, pour la colonne seulement, ce que porte sa seconde voie (`carried`, liste : charbon, combustible).
function M.belt_items(ore, products, carried)
  local out = {}
  for name in pairs(ore or {}) do out[name] = true end
  for _, name in ipairs(products or {}) do out[name] = true end
  for _, name in ipairs(carried or {}) do out[name] = true end
  return out
end

--- Contenu d'un tapis de bande : objets étrangers à relever (tous), et « encombré » quand l'étranger y est MAJORITAIRE (le minerai de la
--- bande n'y passe plus : c'est ce que le DC a vu).
function M.belt_verdict(contents, targets)
  local names = {}
  for name in pairs(contents or {}) do names[#names + 1] = name end
  table.sort(names)
  local r = { target = 0, foreign = 0, clear = {} }
  for _, name in ipairs(names) do
    local n = contents[name] or 0
    if n > 0 then
      if targets[name] then r.target = r.target + n
      else r.foreign = r.foreign + n; r.clear[#r.clear + 1] = { name, n } end
    end
  end
  r.majority = r.foreign > r.target
  return r
end

--- Point 40 (audit des 50 angles morts) : le contrôle anti-mélange retient le NOM de l'entité contrôlée (e.mel_ok) ; une foreuse dont
--- le nom a changé (niveau qui agrandit la zone) ou une ancienne marque booléenne est relue.
function M.needs_check(mel_ok, name)
  return mel_ok ~= name
end

return M
