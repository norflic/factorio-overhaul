--[[
  Lot LEVIATHAN-SEG (11/11) : banc hors jeu du corps articulé (shared/robots/serpent.lua). Lua 5.2, depuis la racine du mod :
      lua5.2 tests/serpent_test.lua
    §1 directions : table des 16 vecteurs unitaires (nord = 0, sens horaire, y vers le sud), choix du plus proche (16 et 8 directions),
       orientation d'entité -> direction ;
    §2 historique : ligne droite derrière la tête, échantillonnage en DISTANCE (un point tous les `pas`, quelle que soit la vitesse),
       plafond de points (les plus anciens tombent), saut plus long que l'historique = ligne droite refaite ;
    §3 pose : sur une trajectoire droite, chaque pièce est à sa distance d'arc derrière la tête et regarde vers la tête ; sur un virage à
       90°, les pièces passées le coude prennent la direction d'avant le virage (chaîne cinématique), celles d'avant le coude la
       nouvelle ; tête immobile : les pièces gardent la direction de la tête ;
    §4 règle du Léviathan (shared/robots/titans.lua) : abscisses croissantes, queue derrière le dernier segment, points gardés suffisants,
       ondulation bornée et déphasée de la tête à la queue ;
    §5 forme : aucun pairs, aucune fonction trigonométrique, aucun require dans une fonction, `global` jamais nommé ;
    §6 mutants : chaque règle a un mutant, tous refusés.
]]

package.path = "./?.lua;" .. package.path

local Se = require("shared.robots.serpent")
local T = require("shared.robots.titans")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("  ECHEC : " .. msg) end
end
local function read(p)
  local f = assert(io.open(p, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

---------------------------------------------------------------------------------------------------
-- §1 directions
---------------------------------------------------------------------------------------------------
check(#Se.DIRS16 == 16, "§1 seize directions")
for i, v in ipairs(Se.DIRS16) do
  check(near(v[1] * v[1] + v[2] * v[2], 1, 1e-4), "§1 direction " .. (i - 1) .. " : vecteur unitaire")
end
check(Se.DIRS16[1][2] == -1 and Se.DIRS16[5][1] == 1 and Se.DIRS16[9][2] == 1 and Se.DIRS16[13][1] == -1, "§1 nord, est, sud, ouest (y vers le sud)")
check(Se.direction(0, -1, 16) == 0 and Se.direction(1, 0, 16) == 4 and Se.direction(0, 1, 16) == 8 and Se.direction(-1, 0, 16) == 12,
  "§1 direction : nord 0, est 4, sud 8, ouest 12 (16 directions)")
check(Se.direction(1, -1, 16) == 2 and Se.direction(1, 1, 8) == 3 and Se.direction(-1, -1, 8) == 7, "§1 direction : diagonales (16 et 8)")
check(Se.direction(0.2, -1, 16) == 1 and Se.direction(0.1, -1, 16) == 0, "§1 direction : la plus proche")
check(Se.direction(0, 0, 16) == nil, "§1 direction : vecteur nul -> nil")
check(Se.direction(10, 0, 16) == Se.direction(1, 0, 16), "§1 direction : indépendante de la longueur")
check(Se.direction_orientation(0, 16) == 0 and Se.direction_orientation(0.25, 16) == 4 and Se.direction_orientation(0.5, 16) == 8
  and Se.direction_orientation(0.97, 16) == 0 and Se.direction_orientation(0.03, 16) == 0 and Se.direction_orientation(0.04, 16) == 1,
  "§1 orientation -> direction : secteur le plus proche, 1 revient à 0")
check(Se.direction_orientation(0.25, 8) == 2 and Se.direction_orientation(nil, 16) == 0, "§1 orientation -> direction : 8 directions, nil")
for d = 0, 15 do
  local v = Se.vecteur(d, 16)
  check(Se.direction(v[1], v[2], 16) == d, "§1 vecteur puis direction : identité (" .. d .. ")")
end
check(Se.vecteur(2, 8) == Se.DIRS16[5], "§1 vecteur : 8 directions = une sur deux des 16")

---------------------------------------------------------------------------------------------------
-- §2 historique
---------------------------------------------------------------------------------------------------
local pas = 0.5
local h = Se.init({ x = 10, y = 20 }, 4, 16, 6, pas)   -- tête vers l'est : la ligne part vers l'ouest
check(#h == 6, "§2 init : nombre de points")
check(near(h[6][1], 9.5) and near(h[6][2], 20) and near(h[1][1], 7.0), "§2 init : du plus ancien (le plus loin) au plus récent, derrière la tête")
-- avancer à vitesse irrégulière : les points restent espacés de `pas`
h = Se.init({ x = 0, y = 0 }, 4, 16, 10, pas)
local pos = { x = 0, y = 0 }
local ajoutes = 0
for _, dx in ipairs({ 0.1, 0.3, 1.7, 0.05, 2.2, 0.6 }) do
  pos = { x = pos.x + dx, y = 0 }
  ajoutes = ajoutes + Se.avancer(h, pos, pas, 10, 4, 16)
end
check(ajoutes == math.floor((4.95 + pas) / pas), "§2 avancer : un point tous les `pas` parcourus depuis le dernier point, quelle que soit la vitesse (" .. ajoutes .. ")")
local ok = true
for i = 2, #h do
  local dx, dy = h[i][1] - h[i - 1][1], h[i][2] - h[i - 1][2]
  if not near(math.sqrt(dx * dx + dy * dy), pas, 1e-9) then ok = false end
end
check(ok, "§2 avancer : points espacés de `pas` exactement")
check(#h == 10, "§2 avancer : plafond de points tenu (les plus anciens tombent)")
check(near(h[#h][1], 4.5) and pos.x - h[#h][1] < pas, "§2 avancer : le plus récent à moins d'un `pas` de la tête")
check(Se.avancer(h, { x = pos.x + 0.02, y = 0 }, pas, 10, 4, 16) == 0, "§2 avancer : rien sous un `pas`")
-- saut (téléportation) : historique refait en ligne droite
local r = Se.avancer(h, { x = 500, y = 500 }, pas, 10, 8, 16)
check(r == -1 and #h == 10 and near(h[10][1], 500) and near(h[10][2], 499.5), "§2 saut plus long que l'historique : ligne droite refaite derrière la tête (vers le sud)")
local vide = {}
check(Se.avancer(vide, { x = 3, y = 3 }, pas, 4, 0, 16) == -1 and #vide == 4 and near(vide[4][2], 3.5), "§2 historique vide : refait derrière la tête")

---------------------------------------------------------------------------------------------------
-- §3 pose
---------------------------------------------------------------------------------------------------
-- trajectoire droite vers l'est
h = Se.init({ x = 0, y = 0 }, 4, 16, 80, pas)
pos = { x = 0, y = 0 }
for _ = 1, 40 do pos = { x = pos.x + 0.37, y = 0 }; Se.avancer(h, pos, pas, 80, 4, 16) end
local abs = { 6, 11, 16, 21, 26 }
local P = Se.placer(h, pos, pas, abs, 16, 4)
for i, s in ipairs(abs) do
  check(near(P[i].x, pos.x - s, 1e-6) and near(P[i].y, 0, 1e-9), "§3 droite : pièce " .. i .. " à " .. s .. " tuiles derrière la tête")
  check(P[i].dir == 4, "§3 droite : pièce " .. i .. " regarde vers la tête (est)")
end
-- virage à 90° : la tête allait vers l'est, puis vers le sud sur 8 tuiles
h = Se.init({ x = 0, y = 0 }, 4, 16, 80, pas)
pos = { x = 0, y = 0 }
for _ = 1, 30 do pos = { x = pos.x + 0.4, y = pos.y }; Se.avancer(h, pos, pas, 80, 4, 16) end
local coude = { x = pos.x, y = pos.y }
for _ = 1, 20 do pos = { x = pos.x, y = pos.y + 0.4 }; Se.avancer(h, pos, pas, 80, 8, 16) end
P = Se.placer(h, pos, pas, { 3, 13, 20 }, 16, 8)
check(near(P[1].x, coude.x, 1e-6) and near(P[1].y, pos.y - 3, 1e-6) and P[1].dir == 8, "§3 virage : avant le coude, la pièce suit la nouvelle direction (sud)")
check(near(P[2].y, coude.y, 1e-6) and near(P[2].x, coude.x - 5, 1e-6) and P[2].dir == 4, "§3 virage : passé le coude, la pièce garde l'ancienne direction (est)")
check(P[3].dir == 4 and near(P[3].x, coude.x - 12, 1e-6), "§3 virage : la queue suit le chemin de la tête, pas une ligne droite")
-- au coude même : direction intermédiaire (diagonale)
local Pc = Se.placer(h, pos, pas, { 8 }, 16, 8)
check(Pc[1].dir == 6, "§3 virage : au coude, la pièce prend la diagonale (sud-est)")
-- tête immobile depuis la pose : les pièces gardent la direction de la tête
h = Se.init({ x = 5, y = 5 }, 12, 16, 60, pas)
P = Se.placer(h, { x = 5, y = 5 }, pas, abs, 16, 12)
check(P[1].dir == 12 and P[5].dir == 12 and near(P[1].x, 11, 1e-6), "§3 tête immobile : pièces derrière elle, dans sa direction (ouest)")
-- au-delà du plus ancien point : prolongement en ligne droite
h = Se.init({ x = 0, y = 0 }, 4, 16, 4, pas)
P = Se.placer(h, { x = 0, y = 0 }, pas, { 10 }, 16, 4)
check(near(P[1].x, -10, 1e-6) and P[1].dir == 4, "§3 au-delà de l'historique : prolongement droit")
-- 8 directions
h = Se.init({ x = 0, y = 0 }, 2, 8, 40, pas)
P = Se.placer(h, { x = 0, y = 0 }, pas, { 5 }, 8, 2)
check(P[1].dir == 2, "§3 huit directions : même règle")

-- cap de la tête : sens de la trajectoire, quelle que soit l'orientation de l'entité
h = Se.init({ x = 0, y = 0 }, 0, 16, 80, pas)   -- posée vers le nord
pos = { x = 0, y = 0 }
for _ = 1, 12 do pos = { x = pos.x, y = pos.y + 0.4 }; Se.avancer(h, pos, pas, 80, 0, 16) end
check(Se.cap(h, pos, pas, 16, 0) == 8, "§3 cap : la tête qui descend vers le sud regarde le sud (orientation de l'entité ignorée)")
for _ = 1, 12 do pos = { x = pos.x + 0.3, y = pos.y + 0.3 }; Se.avancer(h, pos, pas, 80, 0, 16) end
check(Se.cap(h, pos, pas, 16, 0) == 6, "§3 cap : en diagonale vers le sud-est, le sud-est")
check(Se.cap(Se.init({ x = 3, y = 3 }, 12, 16, 10, pas), { x = 3, y = 3 }, pas, 16, 12) == 12, "§3 cap : tête immobile depuis la pose, direction de la pose")
check(Se.cap({}, { x = 0, y = 0 }, pas, 16, 5) == 5, "§3 cap : historique vide, défaut")

-- ordre de dessin : la plus au nord d'abord, la plus au sud par-dessus ; tolérance
local o = Se.ordre({ 3.0, -2.0, 5.0, -2.0, 0.0 })
check(o[1] == 2 and o[2] == 4 and o[3] == 5 and o[4] == 1 and o[5] == 3, "§3 ordre : y croissant, à y égal l'indice le plus petit")
check(Se.ordre_valide(o, { 3.0, -2.0, 5.0, -2.0, 0.0 }, 1.0), "§3 ordre juste : valide")
check(Se.ordre_valide(o, { 3.0, -2.0, 5.0, -2.0, 3.8 }, 1.0), "§3 ordre presque juste (0,8 < tolérance) : gardé")
check(not Se.ordre_valide(o, { 3.0, -2.0, 5.0, -2.0, 4.2 }, 1.0), "§3 ordre faux au-delà de la tolérance : refait")
check(not Se.ordre_valide(o, { 3.0, -2.0 }, 1.0) and not Se.ordre_valide(nil, { 1 }, 1.0), "§3 ordre de taille différente ou absent : refait")
-- tête qui monte vers le nord : elle est dessinée en premier, la queue (au sud) en dernier ; vers le sud : l'inverse
h = Se.init({ x = 0, y = 0 }, 0, 16, 80, pas)
P = Se.placer(h, { x = 0, y = 0 }, pas, abs, 16, 0)
local ys = { 0 }
for i, q in ipairs(P) do ys[i + 1] = q.y end
o = Se.ordre(ys)
check(o[1] == 1 and o[#o] == #ys, "§3 vers le nord : la tête dessous, la queue par-dessus")
h = Se.init({ x = 0, y = 0 }, 8, 16, 80, pas)
P = Se.placer(h, { x = 0, y = 0 }, pas, abs, 16, 8)
ys = { 0 }
for i, q in ipairs(P) do ys[i + 1] = q.y end
o = Se.ordre(ys)
check(o[1] == #ys and o[#o] == 1, "§3 vers le sud : la queue dessous, la tête par-dessus")

---------------------------------------------------------------------------------------------------
-- §4 règle du Léviathan
---------------------------------------------------------------------------------------------------
local S = T.LEVIATHAN.segmente
check(type(S) == "table" and S.n >= 2 and S.premier > 0 and S.espacement > 0 and S.queue > 0 and S.pas > 0 and S.pas < S.espacement,
  "§4 Léviathan segmenté : segments, premier, espacement, queue, pas")
check(S.periode >= 1 and S.periode % 1 == 0 and S.periode <= 30, "§4 Léviathan : période de mise à jour entière, bornée")
check(S.tol > 0 and S.tol < S.espacement, "§4 Léviathan : tolérance de l'ordre de dessin, plus petite qu'un segment")
check(S.directions == 16 and T.LEVIATHAN.anime.directions == S.directions, "§4 Léviathan : 16 directions, tête et pièces")
local A = Se.abscisses(S)
check(#A == S.n + 1 and A[1] == S.premier and near(A[S.n + 1] - A[S.n], S.queue), "§4 abscisses : n segments puis la queue")
local croissant = true
for i = 2, #A do if A[i] <= A[i - 1] then croissant = false end end
check(croissant, "§4 abscisses croissantes")
check(Se.points_max(S) * S.pas >= A[#A] + S.espacement, "§4 points gardés : la queue entière et une marge")
local mx, mn = -1, 1
for c = 0, 23 do
  local o = Se.ondulation(c, 1, S.onde)
  mx, mn = math.max(mx, o), math.min(mn, o)
end
check(near(mx, S.onde) and near(mn, -S.onde) and S.onde > 0 and S.onde < 1, "§4 ondulation bornée par l'amplitude de la règle")
check(Se.ondulation(5, 2, 1) == Se.ondulation(3, 1, 1) and Se.ondulation(5, 2, 1) ~= Se.ondulation(5, 1, 1), "§4 ondulation : deux crans de retard par pièce")
local LE = read("tools/render/pieces/titans/leviathan.py")
local DEMI = tonumber(LE:match("\nDEMI = ([%d%.]+)"))
check(DEMI and near(S.espacement, 2 * DEMI) and near(S.premier, (DEMI + 1.0) + DEMI) and near(S.queue, 2 * DEMI),
  "§4 longueurs de la règle = pièces du modèle (leviathan.py : segment de 2 × DEMI, joint de la tête à DEMI + 1, joint de la queue à DEMI)")
local PI = LE:match("\nPIECES = {(.-)}\n")
check(PI and PI:find('"segment"') and PI:find('"queue"') and #S.pieces == 2 and S.pieces[1] == "segment" and S.pieces[2] == "queue",
  "§4 pièces de la règle = PIECES du modèle (segment, queue)")
check(LE:match('\nSERIE = {[^\n]*"dirs": 16') ~= nil, "§4 tête rendue en 16 directions (SERIE du modèle)")
check(T.piece_name(T.LEVIATHAN, "segment", 2, 7, "corps") == "fo-titan-leviathan-segment-2-7-corps", "§4 nom d'une pièce : préfixe, archétype, pièce, stade, direction, couche")
check(T.direction(0.25, 16) == 4 and T.direction(0.25, 8) == 2 and T.direction(0.97, 16) == 0, "§4 T.direction : n directions")

---------------------------------------------------------------------------------------------------
-- §5 forme
---------------------------------------------------------------------------------------------------
local SRC = read("shared/robots/serpent.lua")
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
check(not code:find("pairs%(") or not code:find("[^i]pairs%("), "§5 aucun pairs (ipairs seulement)")
check(not code:find("math%.sin") and not code:find("math%.cos") and not code:find("math%.atan") and not code:find("math%.tan"), "§5 aucune fonction trigonométrique")
check(not code:find("require"), "§5 aucun require")
check(not code:find("global"), "§5 `global` jamais nommé")
check(not code:find("game%.") and not code:find("rendering%."), "§5 aucune API du jeu")

---------------------------------------------------------------------------------------------------
-- §6 mutants
---------------------------------------------------------------------------------------------------
local function refuse(M)
  return not pcall(function()
    assert(M.direction(1, 0, 16) == 4 and M.direction(0.2, -1, 16) == 1 and M.direction(1, 1, 8) == 3, "direction")
    assert(M.direction_orientation(0.04, 16) == 1 and M.direction_orientation(0.97, 16) == 0, "orientation")
    local hh = M.init({ x = 0, y = 0 }, 4, 16, 10, 0.5)
    assert(hh[10][1] == -0.5 and hh[1][1] == -5, "init derrière la tête")
    local p = { x = 0, y = 0 }
    local n = 0
    for _ = 1, 9 do p = { x = p.x + 0.3, y = 0 }; n = n + M.avancer(hh, p, 0.5, 10, 4, 16) end
    assert(n == 6 and #hh == 10, "échantillonnage en distance, plafond")
    assert(math.abs(hh[10][1] - 2.5) < 1e-9, "point le plus récent")
    hh = M.init({ x = 0, y = 0 }, 4, 16, 80, 0.5)
    p = { x = 0, y = 0 }
    for _ = 1, 30 do p = { x = p.x + 0.4, y = p.y }; M.avancer(hh, p, 0.5, 80, 4, 16) end
    for _ = 1, 20 do p = { x = p.x, y = p.y + 0.4 }; M.avancer(hh, p, 0.5, 80, 8, 16) end
    local q = M.placer(hh, p, 0.5, { 3, 13 }, 16, 8)
    assert(q[1].dir == 8 and q[2].dir == 4, "chaîne cinématique")
    assert(math.abs(q[2].x - (12 - 5)) < 1e-6 and math.abs(q[2].y - 0) < 1e-6, "position sur le chemin")
    local a = M.abscisses({ n = 3, premier = 6, espacement = 5, queue = 4, pas = 0.5 })
    assert(#a == 4 and a[1] == 6 and a[3] == 16 and a[4] == 20, "abscisses")
    assert(M.ondulation(5, 2, 1) == M.ondulation(3, 1, 1), "déphasage de l'ondulation")
    assert(M.avancer(M.init({ x = 0, y = 0 }, 4, 16, 10, 0.5), { x = 300, y = 0 }, 0.5, 10, 4, 16) == -1, "saut refait")
    local hc = M.init({ x = 0, y = 0 }, 0, 16, 40, 0.5)
    local pc = { x = 0, y = 0 }
    for _ = 1, 12 do pc = { x = pc.x, y = pc.y + 0.4 }; M.avancer(hc, pc, 0.5, 40, 0, 16) end
    assert(M.cap(hc, pc, 0.5, 16, 0) == 8, "cap de la tête")
    local oo = M.ordre({ 3.0, -2.0, 5.0, -2.0, 0.0 })
    assert(oo[1] == 2 and oo[2] == 4 and oo[5] == 3, "ordre de dessin")
    assert(M.ordre_valide(oo, { 3.0, -2.0, 5.0, -2.0, 3.8 }, 1.0) and not M.ordre_valide(oo, { 3.0, -2.0, 5.0, -2.0, 4.2 }, 1.0), "tolérance de l'ordre")
  end)
end
check(not refuse(Se), "§6 la règle juste passe le juge des mutants")
local mutants = {
  { "direction : produit scalaire minimal", "if best == nil or d > best then", "if best == nil or d < best then" },
  { "orientation : troncature au lieu du plus proche", "return math.floor(o * n + 0.5) % n", "return math.floor(o * n) % n" },
  { "init : devant la tête", "pos.x - v[1] * pas * i, pos.y - v[2] * pas * i", "pos.x + v[1] * pas * i, pos.y + v[2] * pas * i" },
  { "avancer : échantillonnage en temps (un point par appel)", "local k = math.floor(d / pas)", "local k = 1" },
  { "avancer : plafond ignoré", "local trop = #hist - max", "local trop = 0" },
  { "placer : la pièce regarde la queue", "local dir = Se.direction(ax - bx, ay - by, n) or prev or 0", "local dir = Se.direction(bx - ax, by - ay, n) or prev or 0" },
  { "placer : ligne droite au lieu du chemin", "if j + 1 < nh then", "if false then" },
  { "abscisses : queue collée au dernier segment", "a[spec.n + 1] = a[spec.n] + spec.queue", "a[spec.n + 1] = a[spec.n]" },
  { "ondulation : pas de déphasage", "local i = (cran - 2 * k) % #Se.ONDE + 1", "local i = cran % #Se.ONDE + 1" },
  { "saut : jamais refait", "if k > max then", "if false then" },
  { "cap : la tête regarde derrière elle", "return Se.direction(pos.x - bx, pos.y - by, n) or defaut", "return Se.direction(bx - pos.x, by - pos.y, n) or defaut" },
  { "ordre : le sud d'abord", "if ys[a] ~= ys[b] then return ys[a] < ys[b] end", "if ys[a] ~= ys[b] then return ys[a] > ys[b] end" },
  { "ordre : tolérance ignorée", "if yp > ys[ordre[q]] + tol then return false end", "if yp > ys[ordre[q]] then return false end" },
  { "ordre : jamais refait", "      if yp > ys[ordre[q]] + tol then return false end", "      if false then return false end" },
}
for _, m in ipairs(mutants) do
  local s, n = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")), 1)
  check(n == 1, "§6 mutant « " .. m[1] .. " » : motif trouvé")
  local f = load(s, "=serpent-mutant", "t", _ENV)
  local ok2, M2 = pcall(f)
  check(not ok2 or refuse(M2), "§6 mutant « " .. m[1] .. " » refusé")
end

print(string.format("[SERPENT] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
