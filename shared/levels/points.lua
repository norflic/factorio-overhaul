--[[
  Niveaux : POINTS DE JEU d'un bâtiment qui change d'emprise (lot V3-T2, correction des défauts 1 et 6 du
  correcteur). Pur Lua, testable hors jeu (tests/levels_test.lua). Lu par prototypes/levels/common.lua (points des
  prototypes à l'étape data) et script/levels/levels.lua (place d'un agrandissement).

  Points de jeu : point de dépôt d'une foreuse (vector_to_place_result), raccords de tuyau de toutes les boîtes à
  fluide (assembleur, fluide de minage de la foreuse). Ils sont posés UNE FOIS par prototype, mesurés depuis le
  centre et écrits pour l'orientation NORD ; le moteur les tourne avec la direction du bâtiment.

  Règle des points d'un prototype (côté a → côté b ; avant le lot V3-T2 dans prototypes/levels/common.lua, déplacée
  ici telle quelle) :
    - une coordonnée AU-DELÀ du bord (|v| ≥ a/2) garde son écart au bord : signe(v) × (|v| − a/2 + b/2) ;
    - une coordonnée À L'INTÉRIEUR (le long du bord) est portée à la même proportion du côté, puis calée sur le
      centre de tuile le plus proche du nouveau côté (centres entiers pour un côté impair, demi-entiers pour un
      côté pair ; à égalité, le plus petit) : 0 sur un 3×3 → −0,5 sur un 4×4 ou un 6×6.

  Conséquence payée en moteur réel (défauts 1 et 6, 22/10) : sur un côté PAIR, un point « au milieu » d'un bord est
  décalé d'une demi-tuile vers −x (vers l'ouest pour l'orientation nord) ; tourné de 180°, ce décalage va vers +x.
  La règle de position (shared/levels/footprint.lua) ne connaît pas la direction : pour une foreuse tournée vers le
  sud ou l'ouest, la position préférée déplaçait le point de dépôt d'une tuile (le coffre n'était plus servi, sans
  refus ni message) ; de même pour le raccord d'un assembleur à fluide tourné de 180°.

  RÈGLE DES POINTS SERVIS (lot V3-T2), complément de la règle de position :
    un point de jeu de l'ancien bâtiment est SERVI si une entité qui bloquerait le bâtiment (couche de collision
    partagée ; pour un raccord de tuyau : une entité à boîte à fluide) se trouve à ce point. Une position candidate
    qui fait sortir un point servi de la boîte de collision de l'entité qui le sert (le coffre, le tuyau ; pour un
    dépôt sur un CONVOYEUR, de tout convoyeur : le minerai part sur la ligne) n'est PAS libre : elle est traitée comme bloquée par cette entité (la retirer libère la position ; le
    contour la montre). La première position libre de l'ordre de préférence reste retenue ; aucune : refus
    « no-room ».
  Pour chaque orientation, il existe une position qui garde un point servi sur sa tuile (la règle des points est
  une homothétie calée, la candidate opposée au décalage le compense) : seule la place autour en décide.
]]

local P = {}

P.EPS = 1e-6

--- Centre de tuile le plus proche de `raw` pour un côté b (entiers si b impair, demi-entiers si b pair ; à égalité,
--- le plus petit).
local function snap_center(raw, b)
  if b % 2 == 0 then return math.ceil(raw) - 0.5 end
  local v = math.ceil(raw - 0.5)
  return v == 0 and 0 or v  -- jamais « -0 » (math.ceil(-0,5) en Lua 5.2)
end

--- Une coordonnée d'un point (centre = origine), du côté a au côté b.
function P.move_coord(v, a, b)
  local ha, hb = a / 2, b / 2
  if math.abs(v) >= ha - 1e-9 then
    local out = math.abs(v) - ha + hb
    return v < 0 and -out or out
  end
  return snap_center(v * b / a, b)
end

--- Point { x, y } ou { [1], [2] } d'un prototype (centre = origine), du côté a au côté b ; même forme rendue.
function P.move_point(pt, a, b)
  if type(pt) ~= "table" then return pt end
  if pt.x ~= nil or pt.y ~= nil then return { x = P.move_coord(pt.x or 0, a, b), y = P.move_coord(pt.y or 0, a, b) } end
  return { P.move_coord(pt[1] or 0, a, b), P.move_coord(pt[2] or 0, a, b) }
end

--- Coordonnée au côté de BASE `base` dont le point au côté `side` est `v` (inverse de move_coord) : exacte au-delà du
--- bord ; à l'intérieur, d'abord parmi les CENTRES DE TUILE du côté de base (entiers pour un côté impair,
--- demi-entiers pour un côté pair : les points vanilla le long d'un bord y sont), puis parmi les autres multiples de
--- 0,5, celui que move_coord envoie sur v, le plus proche de la proportion (v × base / side), puis le plus petit
--- (move_coord n'est pas injective sur les multiples de 0,5 : −0,5 et 0 donnent tous deux −0,5 sur un 4×4). Aucun :
--- la proportion (point hors des règles de l'étape data ; jamais attendu).
--- Égalités à P.TOL près : le moteur range les positions en virgule fixe (1/256 de tuile ; moteur réel, 22/10 : dépôt
--- d'une foreuse 4×4 tournée vers l'est relu à −0,49609375 au lieu de −0,5 ; sans tolérance, l'inverse échouait et la
--- règle prédisait un dépôt faux d'une tuile).
P.TOL = 1 / 64
function P.base_coord(v, base, side)
  if base == side then return v end
  local hs, hb = side / 2, base / 2
  if math.abs(v) >= hs - P.TOL then
    local out = math.abs(v) - hs + hb
    return v < 0 and -out or out
  end
  local want = v * base / side
  for pass = 1, 2 do
    local best
    for k = -2 * base, 2 * base do
      local u = k / 2
      local center = math.abs((u + hb) % 1 - 0.5) < 1e-9
      if (pass == 2 or center) and math.abs(u) < hb - 1e-9 and math.abs(P.move_coord(u, base, side) - v) < P.TOL then
        if not best or math.abs(u - want) < math.abs(best - want) - 1e-9 then best = u end
      end
    end
    if best ~= nil then return best == 0 and 0 or best end
  end
  return want
end

--- Point { x, y } au côté de base (inverse de move_point, voir base_coord).
function P.base_point(pt, base, side)
  return { x = P.base_coord(pt.x, base, side), y = P.base_coord(pt.y, base, side) }
end

local function z(v) return v == 0 and 0 or v end

--- Point { x, y } (orientation nord, centre = origine) tourné selon la direction du moteur 1.1.91 (defines.direction :
--- nord 0, est 2, sud 4, ouest 6 ; sens horaire à l'écran, y vers le bas : le nord (0, −1) devient l'est (1, 0)). Une
--- diagonale (jamais pour un bâtiment) est traitée comme le nord.
function P.rotate(pt, dir)
  local d = (dir or 0) % 8
  local x, y = pt.x, pt.y
  if d == 2 then return { x = z(-y), y = z(x) } end
  if d == 4 then return { x = z(-x), y = z(-y) } end
  if d == 6 then return { x = z(y), y = z(-x) } end
  return { x = z(x), y = z(y) }
end

--- Inverse de rotate : un point lu sur une entité tournée, ramené à l'orientation nord.
function P.unrotate(pt, dir)
  return P.rotate(pt, (8 - (dir or 0) % 8) % 8)
end

--- Le point (x, y) est-il dans le rectangle { x0, y0, x1, y1 } (bords compris, à EPS près) ?
function P.inside(box, x, y)
  return x >= box.x0 - P.EPS and x <= box.x1 + P.EPS and y >= box.y0 - P.EPS and y <= box.y1 + P.EPS
end

--- Points servis d'un bâtiment, du côté `from` au côté `to`, pour une orientation `dir` : chaque point lu sur
--- l'entité (`raw`, relatif au centre, déjà ramené à l'orientation nord, au côté actuel du prototype `cur`) donne
--- { old = point à l'ancien côté, new = point au nouveau côté }, tous deux relatifs au centre et TOURNÉS selon dir.
--- Côté égal au côté actuel : le point lu tel quel (aucun aller-retour par la base).
function P.transpose(raw, base, cur, from, to, dir)
  local b = P.base_point(raw, base, cur)
  local o = (from == cur) and raw or P.move_point(b, base, from)
  local n = (to == cur) and raw or P.move_point(b, base, to)
  return { old = P.rotate(o, dir), new = P.rotate(n, dir) }
end

--- Marque les candidates (shared/levels/footprint.lua F.candidates) qui déplacent un point servi : `points` =
--- { { rel = {x, y} (point au nouveau côté, relatif au nouveau centre, tourné), box = {x0, y0, x1, y1} (boîte de
--- collision de l'entité qui sert le point, carte), entity = enregistrement de l'entité (celui de la liste des
--- gênes de Foot.evaluate s'il y est : même table) } }. Chaque candidate reçoit `moved` : les entités dont un point
--- sortirait de leur boîte (sans doublon, dans l'ordre de `points`). Foot.evaluate la traite comme bloquée.
--- Un point peut aussi avoir `alt` : boîtes d'autres entités qui le servent aussi bien (convoyeurs autour du point de
--- dépôt d'une foreuse qui dépose sur un convoyeur : le minerai part sur la même ligne) ; le point y reste servi.
function P.mark(cands, points)
  for _, c in ipairs(cands) do
    local moved, seen = {}, {}
    for _, p in ipairs(points or {}) do
      local x, y = c.x + p.rel.x, c.y + p.rel.y
      local kept = P.inside(p.box, x, y)
      for _, b in ipairs(p.alt or {}) do
        if kept then break end
        kept = P.inside(b, x, y)
      end
      if not kept and not seen[p.entity] then
        seen[p.entity] = true
        moved[#moved + 1] = p.entity
      end
    end
    c.moved = moved
  end
  return cands
end

return P
