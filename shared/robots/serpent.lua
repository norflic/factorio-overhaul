--[[
  Lot LEVIATHAN-SEG (mandat du DC, 11/11) : le corps ARTICULÉ d'un titan serpentin (Léviathan), règle PURE (Lua pur, aucune API du jeu,
  testée par tests/serpent_test.lua). Directive du DC : « le Léviathan ne doit en aucun cas être un sprite rigide unique : tête maîtresse +
  N segments de corps + queue terminale suivant une chaîne cinématique le long de la trajectoire ».
  - La tête est l'entité qui se déplace ; la règle garde l'HISTORIQUE de ses positions, échantillonné en DISTANCE (un point tous les `pas`
    tuiles, jamais en temps) : `hist`, du plus ancien au plus récent.
  - Chaque pièce (segments puis queue) est posée à une distance d'arc fixe derrière la tête le long de cet historique (`abscisses`), son
    orientation est la direction locale de la courbe (du point de derrière vers celui de devant), choisie parmi les directions des
    feuilles par comparaison de vecteurs (table des 16 directions : aucune trigonométrie dans la simulation).
  - Une tête qui vient d'apparaître (ou qui a sauté plus loin que la queue) repart d'une ligne droite derrière elle, dans son orientation.
  Repère du jeu : x vers l'est, y vers le SUD ; direction 0 = nord, sens horaire (comme l'orientation des entités).
  Déterminisme : listes, aucun pairs, aucun hasard ; math.sqrt seulement (distance), aucune fonction trigonométrique.
]]

local Se = {}

--- Les 16 directions (0 = nord, sens horaire), vecteurs unitaires du repère du jeu (y vers le sud) : constantes, pas de trigonométrie.
Se.DIRS16 = {
  { 0.0, -1.0 }, { 0.38268, -0.92388 }, { 0.70711, -0.70711 }, { 0.92388, -0.38268 },
  { 1.0, 0.0 }, { 0.92388, 0.38268 }, { 0.70711, 0.70711 }, { 0.38268, 0.92388 },
  { 0.0, 1.0 }, { -0.38268, 0.92388 }, { -0.70711, 0.70711 }, { -0.92388, 0.38268 },
  { -1.0, 0.0 }, { -0.92388, -0.38268 }, { -0.70711, -0.70711 }, { -0.38268, -0.92388 },
}

--- Ondulation verticale (douze crans d'une onde, constantes) : chaque pièce flotte avec un déphasage, l'onde court de la tête à la queue.
Se.ONDE = { 0.0, 0.5, 0.86603, 1.0, 0.86603, 0.5, 0.0, -0.5, -0.86603, -1.0, -0.86603, -0.5 }

--- Direction d'une orientation d'entité (dans [0, 1[) parmi `n` directions (n divise 16) : le secteur le plus proche.
function Se.direction_orientation(orientation, n)
  local o = tonumber(orientation) or 0
  n = n or 16
  return math.floor(o * n + 0.5) % n
end

--- Direction (0 .. n-1, n divise 16) la plus proche du vecteur (dx, dy) : produit scalaire maximal ; nil pour le vecteur nul.
function Se.direction(dx, dy, n)
  n = n or 16
  if dx == 0 and dy == 0 then return nil end
  local step = 16 / n
  local best, bi = nil, nil
  for i = 0, n - 1 do
    local v = Se.DIRS16[i * step + 1]
    local d = dx * v[1] + dy * v[2]
    if best == nil or d > best then best, bi = d, i end
  end
  return bi
end

--- Vecteur unitaire de la direction `dir` parmi `n`.
function Se.vecteur(dir, n)
  n = n or 16
  return Se.DIRS16[(dir % n) * (16 / n) + 1]
end

--- Historique initial : `npts` points en ligne droite DERRIÈRE la tête (position `pos`, direction `dir` parmi `n`), espacés de `pas`,
--- du plus ancien au plus récent (le plus récent est à `pas` de la tête).
function Se.init(pos, dir, n, npts, pas)
  local v = Se.vecteur(dir or 0, n)
  local hist = {}
  for i = npts, 1, -1 do
    hist[#hist + 1] = { pos.x - v[1] * pas * i, pos.y - v[2] * pas * i }
  end
  return hist
end

--- Fait avancer l'historique jusqu'à la tête en `pos` : ajoute un point tous les `pas` sur le segment du dernier point à la tête, garde
--- au plus `max` points (les plus anciens tombent). Un saut plus long que l'historique entier (téléportation, remplacement) le refait en
--- ligne droite dans la direction `dir` (n directions). Rend le nombre de points ajoutés (-1 : historique refait).
function Se.avancer(hist, pos, pas, max, dir, n)
  local last = hist[#hist]
  if not last then
    local h = Se.init(pos, dir, n, max, pas)
    for i = 1, #h do hist[i] = h[i] end
    return -1
  end
  local dx, dy = pos.x - last[1], pos.y - last[2]
  local d2 = dx * dx + dy * dy
  if d2 < pas * pas then return 0 end
  local d = math.sqrt(d2)
  local k = math.floor(d / pas)
  if k > max then
    local h = Se.init(pos, dir, n, max, pas)
    for i = #hist, 1, -1 do hist[i] = nil end
    for i = 1, #h do hist[i] = h[i] end
    return -1
  end
  for i = 1, k do
    local t = i * pas / d
    hist[#hist + 1] = { last[1] + dx * t, last[2] + dy * t }
  end
  local trop = #hist - max
  if trop > 0 then
    for i = 1, #hist - trop do hist[i] = hist[i + trop] end
    for i = #hist, #hist - trop + 1, -1 do hist[i] = nil end
  end
  return k
end

--- Point de la trajectoire à la distance d'arc `s` derrière la tête : la tête `pos`, puis le point le plus récent (à d0 de la tête), puis
--- les autres tous les `pas`. Au-delà du plus ancien, la trajectoire est prolongée en ligne droite (direction des deux derniers points).
local function point(hist, pos, d0, pas, s)
  local nh = #hist
  if s <= d0 or nh == 0 then
    if nh == 0 or d0 <= 0 then return pos.x, pos.y end
    local t = s / d0
    local p = hist[nh]
    return pos.x + (p[1] - pos.x) * t, pos.y + (p[2] - pos.y) * t
  end
  local r = (s - d0) / pas
  local j = math.floor(r)
  local f = r - j
  if j + 1 < nh then
    local a, b = hist[nh - j], hist[nh - j - 1]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f
  end
  -- prolongement derrière le plus ancien point
  local a = hist[1]
  local b = hist[2] or { pos.x, pos.y }
  local e = (r - (nh - 1))
  return a[1] + (a[1] - b[1]) * e, a[2] + (a[2] - b[2]) * e
end
Se.point = point

--- Pose des pièces : pour chaque abscisse d'arc de `abscisses` (distances derrière la tête), position { x, y } et direction (parmi `n`)
--- de la tangente locale (du point à s + h vers le point à s - h : la pièce regarde vers la tête). `dir_tete` sert si la courbe est
--- dégénérée (tête immobile depuis la pose : points confondus).
function Se.placer(hist, pos, pas, abscisses, n, dir_tete)
  local nh = #hist
  local d0 = 0
  if nh > 0 then
    local p = hist[nh]
    local dx, dy = p[1] - pos.x, p[2] - pos.y
    d0 = math.sqrt(dx * dx + dy * dy)
  end
  local h = pas
  local out = {}
  local prev = dir_tete
  for i, s in ipairs(abscisses) do
    local x, y = point(hist, pos, d0, pas, s)
    local ax, ay = point(hist, pos, d0, pas, math.max(0, s - h))
    local bx, by = point(hist, pos, d0, pas, s + h)
    local dir = Se.direction(ax - bx, ay - by, n) or prev or 0
    out[i] = { x = x, y = y, dir = dir }
    prev = dir
  end
  return out
end

--- CAP de la tête : direction (parmi `n`) de sa trajectoire, du point à `pas` tuiles derrière elle vers elle (la tête d'un titan
--- articulé regarde où elle va, quelle que soit l'orientation de l'entité) ; `defaut` si l'historique est dégénéré (points confondus).
function Se.cap(hist, pos, pas, n, defaut)
  local nh = #hist
  local d0 = 0
  if nh > 0 then
    local p = hist[nh]
    local dx, dy = p[1] - pos.x, p[2] - pos.y
    d0 = math.sqrt(dx * dx + dy * dy)
  end
  local bx, by = point(hist, pos, d0, pas, pas)
  return Se.direction(pos.x - bx, pos.y - by, n) or defaut
end

--- Abscisses d'arc des pièces : `n` segments (le premier à `premier` tuiles de la tête, puis tous les `espacement`) et la queue
--- (`queue` derrière le dernier segment).
function Se.abscisses(spec)
  local a = {}
  for k = 1, spec.n do a[k] = spec.premier + (k - 1) * spec.espacement end
  a[spec.n + 1] = a[spec.n] + spec.queue
  return a
end

--- Nombre de points d'historique à garder : la queue entière, plus une marge d'un espacement.
function Se.points_max(spec)
  local a = Se.abscisses(spec)
  return math.floor((a[#a] + spec.espacement) / spec.pas) + 2
end

--- ORDRE DE DESSIN (vue de 3/4 depuis le sud) : la pièce la plus au nord (y le plus petit) d'abord, la plus au sud par-dessus ; à y égal,
--- l'indice le plus petit d'abord. `ys` : ordonnées au sol (1 = la tête, puis les pièces). Rend la liste des indices.
function Se.ordre(ys)
  local o = {}
  for i = 1, #ys do o[i] = i end
  table.sort(o, function(a, b)
    if ys[a] ~= ys[b] then return ys[a] < ys[b] end
    return a < b
  end)
  return o
end

--- L'ordre `ordre` est-il encore juste pour les ordonnées `ys`, à `tol` tuiles près ? Faux dès qu'une pièce dessinée avant une autre est
--- plus au sud qu'elle de plus de `tol` (tolérance : deux pièces presque à la même ordonnée ne font pas refaire le dessin à chaque pas).
function Se.ordre_valide(ordre, ys, tol)
  if not ordre or #ordre ~= #ys then return false end
  for p = 1, #ordre - 1 do
    local yp = ys[ordre[p]]
    for q = p + 1, #ordre do
      if yp > ys[ordre[q]] + tol then return false end
    end
  end
  return true
end

--- Décalage vertical d'ondulation de la pièce k (1 = premier segment) au cran `cran` (entier, avance d'un cran par mise à jour), en
--- tuiles : amplitude `amp`, l'onde court de la tête vers la queue (deux crans de retard par pièce).
function Se.ondulation(cran, k, amp)
  local i = (cran - 2 * k) % #Se.ONDE + 1
  return Se.ONDE[i] * amp
end

return Se
