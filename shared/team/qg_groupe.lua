--[[
  Lot QG-GROUPE2 (4/11 ; le DC, QCM du 4/11, question 4 : « Placement groupé dès la pose », sans téléport) : les tourelles du QG de votre
  équipe sont POSÉES en lignes serrées qui se couvrent, à nombre CONSTANT ; la défense du QG se compte au point le plus faible.
  PUR (aucune API Factorio, aucun nom d'objet : les appelants, script/team/team.lua et script/team/qg_groupe.lua, passent des positions et des
  nombres). Testé hors jeu : tests/qggroupe2_test.lua (avec mutants).

  Mesuré (fo-logs/2026-11-03_QGSURVIE/RAPPORT.md §6, journal [FO-QG-TOURELLE], verif-guide 1618033988, deux chutes du QG, 17 tourelles mortes) :
    * tourelles du QG posées une par côté (shared/team/depart.lua, D.HQ_OFFSETS : N, S, E, O à 10 à 12 tuiles), 19 à 24 tuiles entre voisines ;
      dans 14 morts sur 17, AUCUNE autre tourelle n'avait le tueur à portée (portée 18) ;
    * une vague de 82 à 162 unités (environ 2 000 PV) en prend une à la fois, puis fait le tour : 6 à 7 tourelles perdues en 18 à 24 s ;
    * Sq.peril additionnait 574 PV par tourelle (3 448 à 4 023 PV, « hors de péril ») : face à un point, la défense réelle valait UNE tourelle.
  Le DC ne veut pas plus de tourelles autour du QG (« quantité faramineuse ») et ne veut pas de téléport (QCM du 4/11).

  Règle 1, POSE (G.prior, G.note, G.rank, G.choose_sides, G.sizes, G.slots, G.free) : les tourelles du QG vont en lignes de G.GROUP_MAX au
    plus, écart = l'écart de pose voulu (Pose.gap : 6 tuiles à portée 18, la règle PD-ESPACEMENT du DC reste tenue), perpendiculaires au côté,
    centrées à G.RADIUS tuiles du coffre (la ligne couvre le coffre : son bout est à 13,5 tuiles, sous la portée) ; 5 à 8 tourelles : deux
    lignes, sur deux côtés à 135° au moins (G.MIN_SIDE_GAP ; à 90°, les bouts de deux lignes se touchent : (9, 10) et (10, 9) au S et à l'E),
    le côté opposé s'il n'y a qu'un côté retenu ; jamais plus de G.GROUP_MAX par ligne (au-delà de 2 lignes pleines, les tourelles en trop n'ont
    pas de place : la pose reprend les emplacements d'avant, Outposts.fortify). Le pas de la ligne est ENTIER (G.step). Sur une DIAGONALE (NE, SE,
    SO, NO), pas de ligne mais un CARRÉ de 2 × 2 au pas de l'écart, aligné sur la grille et centré sur la diagonale (SE : (4, 4), (10, 4), (4, 10),
    (10, 10)) : une ligne de 4 en diagonale au pas (5, 5) faisait 21,2 tuiles de bout en bout (au-dessus de la portée : ses bouts ne se couvraient
    pas) ; au pas (4, 4), 5,66 tuiles, sous l'écart voulu ; à 3 par ligne, 4 tourelles se coupaient en 3 + 1 ou 2 + 2. Le carré : 8,5 tuiles au
    plus entre deux tourelles, la plus loin à 14,1 tuiles du coffre, appui de 2 tourelles au point le plus faible comme la ligne d'un côté droit. Côté : celui des pertes près du coffre (marques, G.MARK_R tuiles, G.MEMORY ticks) ; sans marque,
    celui des nids connus les plus proches (G.prior) ; sans rien, G.DEFAULT_SIDE. Une tourelle déjà posée n'est JAMAIS déplacée : seules
    les places libres (G.free) reçoivent les tourelles neuves.
  Règle 2, APPUI (G.support, G.facing) : la défense du QG face à une vague est celle de son point le plus faible : pour chaque tourelle qui
    couvre le coffre (point d'entrée), la somme des parts armées (‰) des tourelles qui ont à portée son TUEUR, placé à G.REACH tuiles d'elle
    vers l'extérieur (le petit cracheur tire de 11,7 à 13,7 tuiles, mesuré) ; la valeur armée du recensement est réduite dans le rapport
    (point le plus faible) / (somme de toutes les parts). Lue par Sq.peril (champ `facing`, shared/team/survie_qg.lua).

  Déterminisme : aucune horloge mesurée, aucun hasard, aucun `pairs`, aucune trigonométrie (huit vecteurs constants, pente tan 22,5°).
]]

local G = {}

G.GROUP_MAX = 4          -- tourelles par ligne au plus (4 à 6 tuiles : 18 tuiles de bout en bout, la portée)
G.RADIUS = 10            -- tuiles : centre d'une ligne à cette distance du coffre (D.HQ_OFFSETS d'avant : 10 à 12)
G.REACH = 13             -- tuiles : le tueur d'une tourelle, vers l'extérieur du coffre (petit cracheur : 11,7 à 13,7 mesurés). MESURÉ
G.MARK_R = 40            -- tuiles : une perte plus proche du coffre marque son côté (F.NEAR_HQ = 40, shared/team/front.lua)
G.MEMORY = 30 * 3600     -- ticks : durée d'une marque (comme Sq.WINDOW)
G.MARKS_MAX = 64         -- marques gardées au plus (les plus récentes)
G.MIN_SIDE_GAP = 3       -- huitièmes de tour : deux lignes sur des côtés à 135° au moins (à 90°, leurs bouts se touchent)
G.KEEP_PCT = 75          -- % : les côtés retenus restent tant que leur poids vaut au moins cela du plus lourd (pas de va-et-vient)
G.W_TURRET = 2           -- poids d'une tourelle perdue
G.W_OTHER = 1            -- poids d'une autre pièce perdue
G.FREE_R = 2             -- tuiles : une place à moins de cela d'une tourelle est prise
G.DEFAULT_SIDE = 5       -- côté sans marque ni nid connu (S) : arbitraire, mais fixe (déterminisme)

-- Huit côtés, y vers le bas (comme le moteur) : N, NE, E, SE, S, SO, O, NO.
local H = 0.70710678
G.DIRS = { { 0, -1 }, { H, -H }, { 1, 0 }, { H, H }, { 0, 1 }, { -H, H }, { -1, 0 }, { -H, -H } }
G.NAMES = { "N", "NE", "E", "SE", "S", "SO", "O", "NO" }
local TAN = 0.41421356   -- tan(22,5°)

local function num(x)
  if type(x) ~= "number" or x ~= x then return 0 end
  return x
end

local function round(x) return math.floor(x + 0.5) end

--- Côté (1 à 8) du point (dx, dy) vu du coffre ; nil au centre.
function G.side(dx, dy)
  dx, dy = num(dx), num(dy)
  if dx == 0 and dy == 0 then return nil end
  local ax, ay = math.abs(dx), math.abs(dy)
  if ax <= TAN * ay then return dy < 0 and 1 or 5 end
  if ay <= TAN * ax then return dx > 0 and 3 or 7 end
  if dx > 0 then return dy < 0 and 2 or 4 end
  return dy > 0 and 6 or 8
end

--- Écart entre deux côtés (0 à 4 huitièmes de tour).
function G.gap_sides(a, b)
  local d = math.abs(a - b) % 8
  return d > 4 and 8 - d or d
end

--- Note une perte au point (dx, dy) relatif au coffre, de poids w, au tick `tick`. marks : liste { { t, side, w } } (ordre d'arrivée),
--- modifiée sur place : hors de G.MARK_R, rien ; les marques plus vieilles que G.MEMORY et au-delà de G.MARKS_MAX (les plus anciennes)
--- partent. Rend le côté noté (ou nil).
function G.note(marks, tick, dx, dy, w)
  dx, dy, w, tick = num(dx), num(dy), num(w), num(tick)
  if w <= 0 or dx * dx + dy * dy > G.MARK_R * G.MARK_R then return nil end
  local s = G.side(dx, dy)
  if not s then return nil end
  local keep = {}
  for _, m in ipairs(marks) do
    if tick - m.t <= G.MEMORY then keep[#keep + 1] = m end
  end
  keep[#keep + 1] = { t = tick, side = s, w = w }
  local first = math.max(1, #keep - G.MARKS_MAX + 1)
  for i = #marks, 1, -1 do marks[i] = nil end
  for i = first, #keep do marks[#marks + 1] = keep[i] end
  return s
end

local function ranked_of(w)
  local out = {}
  for s = 1, 8 do
    if w[s] > 0 then out[#out + 1] = { side = s, w = w[s] } end
  end
  table.sort(out, function(a, b)
    if a.w ~= b.w then return a.w > b.w end
    return a.side < b.side
  end)
  return out
end

--- Poids des côtés dans la mémoire : liste { { side, w } } des côtés de poids > 0, du plus lourd au plus léger (côté croissant à égalité).
function G.rank(marks, tick)
  local w = { 0, 0, 0, 0, 0, 0, 0, 0 }
  for _, m in ipairs(marks or {}) do
    if m.side and num(tick) >= num(m.t) and num(tick) - num(m.t) <= G.MEMORY then w[m.side] = w[m.side] + num(m.w) end
  end
  return ranked_of(w)
end

--- Côtés des nids connus, vus du coffre : points = { { dx, dy } } ; poids entier floor(10^6 / d²) (le plus proche pèse le plus : la vague
--- naît des nids que la pollution atteint d'abord). Même forme que G.rank.
function G.prior(points)
  local w = { 0, 0, 0, 0, 0, 0, 0, 0 }
  for _, p in ipairs(points or {}) do
    local dx, dy = num(p.dx), num(p.dy)
    local s = G.side(dx, dy)
    if s then w[s] = w[s] + math.floor(1000000 / math.max(1, dx * dx + dy * dy)) end
  end
  return ranked_of(w)
end

--- Côtés des lignes (au plus k) : le plus lourd, puis le suivant à G.MIN_SIDE_GAP huitièmes de tour au moins de ceux déjà pris. `prev` (côtés retenus avant) est gardé
--- tant que le poids de son premier côté vaut au moins G.KEEP_PCT % du plus lourd (pas de va-et-vient). Sans poids : `prev`, sinon
--- { G.DEFAULT_SIDE }. Rend une liste non vide.
function G.choose_sides(ranked, k, prev)
  ranked = ranked or {}
  if #ranked == 0 then
    if prev and prev[1] then return prev end
    return { G.DEFAULT_SIDE }
  end
  if prev and prev[1] then
    local wp = 0
    for _, r in ipairs(ranked) do if r.side == prev[1] then wp = r.w end end
    if wp * 100 >= ranked[1].w * G.KEEP_PCT then return prev end
  end
  local out = {}
  for _, r in ipairs(ranked) do
    if #out >= k then break end
    local ok = true
    for _, s in ipairs(out) do if G.gap_sides(s, r.side) < G.MIN_SIDE_GAP then ok = false end end
    if ok then out[#out + 1] = r.side end
  end
  return out
end

--- Tailles des lignes pour n tourelles sur `nsides` côtés : ceil(n / G.GROUP_MAX) lignes (au moins 1, au plus nsides), le reste aux
--- premières, jamais plus de G.GROUP_MAX par ligne. Rend une liste de tailles (somme = min(n, nsides × G.GROUP_MAX)).
function G.sizes(n, nsides)
  n, nsides = math.floor(num(n)), math.floor(num(nsides))
  if n <= 0 or nsides <= 0 then return {} end
  local ng = math.min(nsides, math.max(1, math.ceil(n / G.GROUP_MAX)))
  if n > ng * G.GROUP_MAX then n = ng * G.GROUP_MAX end
  local out = {}
  local base, extra = math.floor(n / ng), n % ng
  for g = 1, ng do out[g] = base + (g <= extra and 1 or 0) end
  return out
end

--- Composante entière du pas d'une ligne : v × gap arrondi vers l'extérieur (jamais plus court que l'écart voulu une fois arrondi).
function G.step(v, gap)
  local x = num(v) * num(gap)
  if math.abs(x) < 1e-9 then return 0 end
  if x >= 0 then return math.ceil(x - 1e-9) end
  return -math.ceil(-x - 1e-9)
end

--- Côté opposé (1 à 8).
function G.opposite(s) return (s + 3) % 8 + 1 end

--- Texte de journal des groupes posés (mêmes côtés et tailles que G.slots) : « 4 en carre cote SO », « 4 en ligne cote S + 2 en ligne cote N ».
--- Une diagonale (NE, SE, SO, NO) est un carré, un côté droit une ligne ; « - » sans groupe. ASCII (journal du jeu).
function G.shape_text(n, sides)
  if not sides or #sides == 0 then return "-" end
  if #sides == 1 and num(n) > G.GROUP_MAX then sides = { sides[1], G.opposite(sides[1]) } end
  local parts = {}
  for g, m in ipairs(G.sizes(n, #sides)) do
    local s = sides[g]
    parts[#parts + 1] = string.format("%d en %s cote %s", m, s % 2 == 0 and "carre" or "ligne", G.NAMES[s])
  end
  if #parts == 0 then return "-" end
  return table.concat(parts, " + ")
end

--- Places des tourelles (relatives au coffre) : { { dx, dy, group, side } }, ligne 1 d'abord, du centre de la ligne vers ses bouts (une ligne
--- incomplète reste serrée). n tourelles, `sides` (G.choose_sides ; un seul côté et plus de G.GROUP_MAX tourelles : son opposé en plus), `gap`
--- écart voulu entre centres (tuiles). Pas ENTIER (G.step) : deux places d'une ligne sont exactement à un multiple du pas, arrondi compris.
--- #rendu = min(n, 2 lignes de G.GROUP_MAX) (0 sans côté).
function G.slots(n, sides, gap)
  local out = {}
  if not sides or #sides == 0 then return out end
  gap = num(gap)
  if gap <= 0 then return out end
  if #sides == 1 and num(n) > G.GROUP_MAX then sides = { sides[1], G.opposite(sides[1]) } end
  for g, m in ipairs(G.sizes(n, #sides)) do
    local s = sides[g]
    local u = G.DIRS[s]
    local cx, cy = u[1] * G.RADIUS, u[2] * G.RADIUS
    if s % 2 == 0 then
      -- diagonale : carré de 2 × 2 au pas 2h >= gap, centré sur la diagonale ; ordre : les deux coins de côté, le coin extérieur, le coin intérieur
      local h = math.ceil(gap / 2 - 1e-9)
      local sx, sy = u[1] > 0 and 1 or -1, u[2] > 0 and 1 or -1
      local ox, oy = round(cx), round(cy)
      local corners = { { sx, -sy }, { -sx, sy }, { sx, sy }, { -sx, -sy } }
      for i = 1, m do out[#out + 1] = { dx = ox + corners[i][1] * h, dy = oy + corners[i][2] * h, group = g, side = s } end
    else
    local tx, ty = G.step(-u[2], gap), G.step(u[1], gap)
    local ranks = {}
    for k = 0, m - 1 do ranks[#ranks + 1] = k - (m - 1) / 2 end
    table.sort(ranks, function(a, b)
      if math.abs(a) ~= math.abs(b) then return math.abs(a) < math.abs(b) end
      return a < b
    end)
    for _, r in ipairs(ranks) do
      out[#out + 1] = { dx = round(cx + tx * r), dy = round(cy + ty * r), group = g, side = s }
    end
    end
  end
  return out
end

--- Places libres : `slots` (absolues, { x, y }) dont aucune tourelle de `turrets` ({ x, y }) n'est à moins de G.FREE_R tuiles. Ordre gardé.
function G.free(slots, turrets)
  local out = {}
  for _, p in ipairs(slots or {}) do
    local taken = false
    for _, t in ipairs(turrets or {}) do
      local dx, dy = num(t.x) - num(p.x), num(t.y) - num(p.y)
      if dx * dx + dy * dy < G.FREE_R * G.FREE_R then taken = true end
    end
    if not taken then out[#out + 1] = p end
  end
  return out
end

--- Appui : list = { { x, y, s, p } } (s = part armée en ‰, 0 à 1000 ; p = vrai si la tourelle couvre le coffre, point d'entrée de la vague),
--- portée `range`, coffre (cx, cy). Le tueur de la tourelle i est à G.REACH tuiles d'elle, sur la demi-droite qui part du coffre (au coffre :
--- sur elle). Rend weakest (la plus petite somme, sur les points d'entrée, des parts des tourelles qui ont ce tueur à portée, bornes
--- comprises), total (somme de toutes les parts), worst (indice), entries (nombre de points d'entrée).
function G.support(list, range, cx, cy)
  list = list or {}
  cx, cy = num(cx), num(cy)
  local r2 = num(range) * num(range)
  local total, weakest, worst, entries = 0, nil, nil, 0
  for _, a in ipairs(list) do total = total + num(a.s) end
  for i, a in ipairs(list) do
    if a.p then
      entries = entries + 1
      local ux, uy = num(a.x) - cx, num(a.y) - cy
      local l = math.sqrt(ux * ux + uy * uy)
      local px, py = num(a.x), num(a.y)
      if l > 0 then px, py = px + ux / l * G.REACH, py + uy / l * G.REACH end
      local sum = 0
      for _, b in ipairs(list) do
        local dx, dy = px - num(b.x), py - num(b.y)
        if dx * dx + dy * dy <= r2 then sum = sum + num(b.s) end
      end
      if weakest == nil or sum < weakest then weakest, worst = sum, i end
    end
  end
  return weakest or 0, total, worst, entries
end

--- La tourelle en (x, y) couvre-t-elle le coffre (cx, cy) ? (distance <= portée, bornes comprises)
function G.covers(x, y, cx, cy, range)
  local dx, dy = num(x) - num(cx), num(y) - num(cy)
  return dx * dx + dy * dy <= num(range) * num(range)
end

--- Valeur armée du QG face à une vague : value × weakest / total (entier). 0 sans part armée ou sans point d'entrée.
function G.facing(value, weakest, total)
  value, weakest, total = num(value), num(weakest), num(total)
  if total <= 0 or value <= 0 then return 0 end
  if weakest >= total then return math.floor(value) end
  return math.floor(value * weakest / total)
end

--- Dispersion d'une pose (journal) : targets = { { x, y } } places voulues, placed = { { x, y } | false } positions obtenues (même indice ;
--- false : rien posé). Rend moved (plus grand décalage d'une tourelle à sa place, tuiles), gap (plus petit écart entre deux tourelles posées ;
--- nil sous deux), n (posées).
function G.dispersion(targets, placed)
  local moved, gapmin, n = 0, nil, 0
  local pts = {}
  for i, p in ipairs(placed or {}) do
    local t = targets and targets[i]
    if p and t then
      n = n + 1
      local d = math.sqrt((num(p.x) - num(t.x)) ^ 2 + (num(p.y) - num(t.y)) ^ 2)
      if d > moved then moved = d end
      pts[#pts + 1] = p
    end
  end
  for i = 1, #pts do
    for j = i + 1, #pts do
      local d = math.sqrt((num(pts[i].x) - num(pts[j].x)) ^ 2 + (num(pts[i].y) - num(pts[j].y)) ^ 2)
      if gapmin == nil or d < gapmin then gapmin = d end
    end
  end
  return moved, gapmin, n
end

return G
