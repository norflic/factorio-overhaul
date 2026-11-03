--[[
  Lot QGGROUPE (3/11) : les tourelles du QG de votre équipe en GROUPES qui se couvrent, sur les côtés attaqués, à nombre CONSTANT.
  PUR (aucune API Factorio, aucun nom d'objet : l'appelant, script/team/qg_groupe.lua, passe des positions et des nombres). Testé hors jeu :
  tests/qggroupe_test.lua (avec mutants).

  Mesuré (fo-logs/2026-11-03_QGSURVIE/RAPPORT.md §6, journal [FO-QG-TOURELLE], verif-guide 1618033988, deux chutes du QG, 17 tourelles mortes) :
    * les tourelles du QG sont posées une par côté (shared/team/depart.lua, D.HQ_OFFSETS : N, S, E, O à 10 à 12 tuiles), 19 à 24 tuiles
      entre voisines : dans 14 morts sur 17, AUCUNE autre tourelle n'avait le tueur à portée (portée 18) ;
    * une vague de 82 à 162 unités (environ 2 000 PV) en prend une à la fois puis fait le tour : 6 à 7 tourelles perdues en 18 à 24 s ;
    * Sq.peril additionne 574 PV par tourelle (3 448 à 4 023 PV, « hors de péril ») : face à un point, la défense réelle vaut UNE tourelle.
  Le DC ne veut PAS plus de tourelles autour du QG (« quantité faramineuse ») : la règle les DÉPLACE, elle n'en ajoute aucune.

  Règle 1 (G.support, G.facing) : la défense du QG face à une vague = celle du point le PLUS FAIBLE : pour chaque tourelle du QG, la somme
    des parts armées (‰) des tourelles qui ont à portée le TUEUR de celle-ci, placé à G.REACH tuiles d'elle vers l'extérieur du QG (le petit
    cracheur tire de 11,7 à 13,7 tuiles, mesuré), elle comprise ; la valeur armée du QG est réduite dans le rapport (point le plus faible) / (somme de toutes les parts). Une seule tourelle
    isolée suffit à faire baisser la défense : c'est par elle que la vague entre.
  Règle 2 (G.note, G.rank, G.choose_sides, G.slots, G.assign) : les pertes à moins de G.MARK_R tuiles du QG, au point du tueur, marquent
    leur côté (8 côtés) pendant G.MEMORY ticks ; les tourelles du QG vont en groupes de G.GROUP_MAX au plus, en ligne serrée (écart =
    l'écart de pose voulu, Pose.gap, 6 tuiles à portée 18 : la règle PD-ESPACEMENT du DC reste tenue) perpendiculaire au côté, à G.RADIUS
    tuiles du QG, sur les deux côtés les plus marqués (le second à 90° au moins du premier, sinon les groupes se chevauchent). Sans marque :
    rien ne change (emplacements d'avant). Le nombre de places rendues est EXACTEMENT le nombre de tourelles.

  Déterminisme : aucune horloge mesurée, aucun hasard, aucun `pairs`, aucune trigonométrie (huit vecteurs constants, pente tan 22,5°).
]]

local G = {}

G.GROUP_MAX = 4          -- tourelles par groupe au plus (une ligne de 4 à 6 tuiles : 18 tuiles de bout en bout, la portée)
G.RADIUS = 10            -- tuiles : centre d'un groupe à cette distance du QG (D.HQ_OFFSETS : 10 à 12)
G.SUPPORT_PCT = 100      -- % de la portée de la tourelle (bornes comprises)
G.REACH = 13             -- tuiles : le tueur d'une tourelle, vers l'extérieur du QG (petit cracheur : 11,7 à 13,7 mesurés, QGSURVIE2). MESURÉ
G.MARK_R = 40            -- tuiles : une perte plus proche du QG marque son côté (F.NEAR_HQ = 40, shared/team/front.lua)
G.MEMORY = 30 * 3600     -- ticks : durée d'une marque (comme Sq.WINDOW)
G.MARKS_MAX = 64         -- marques gardées au plus (les plus récentes)
G.PERIOD = 5 * 3600      -- ticks : un regroupement au plus toutes les 5 min
G.MOVE_MIN = 2           -- tuiles : une tourelle plus près que cela de sa place ne bouge pas
G.KEEP_PCT = 75          -- % : les côtés retenus restent tant que leur poids vaut au moins cela du poids des meilleurs (pas de va-et-vient)
G.W_TURRET = 2           -- poids d'une tourelle perdue
G.W_OTHER = 1            -- poids d'une autre pièce perdue

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

--- Côté (1 à 8) du point (dx, dy) vu du QG ; nil au centre.
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

--- Note une perte au point (dx, dy) relatif au QG, de poids w, au tick `tick`. marks : liste { { t, side, w } } (ordre d'arrivée), modifiée
--- sur place : hors de G.MARK_R, rien ; les marques plus vieilles que G.MEMORY et au-delà de G.MARKS_MAX (les plus anciennes) partent.
--- Rend le côté noté (ou nil).
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

--- Poids des côtés dans la mémoire : liste { { side, w } } des côtés de poids > 0, du plus lourd au plus léger (côté croissant à égalité).
function G.rank(marks, tick)
  local w = { 0, 0, 0, 0, 0, 0, 0, 0 }
  for _, m in ipairs(marks or {}) do
    if m.side and num(tick) - num(m.t) <= G.MEMORY and num(tick) >= num(m.t) then w[m.side] = w[m.side] + num(m.w) end
  end
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

--- Côtés des groupes (au plus k) : le plus marqué, puis le suivant à 90° au moins de ceux déjà pris. `prev` (côtés retenus avant, liste) est
--- gardé tel quel tant que le poids de son premier côté vaut au moins G.KEEP_PCT % du plus lourd (pas de va-et-vient). Rend une liste.
function G.choose_sides(ranked, k, prev)
  ranked = ranked or {}
  if #ranked == 0 then return {} end
  if prev and prev[1] then
    local wp = 0
    for _, r in ipairs(ranked) do if r.side == prev[1] then wp = r.w end end
    if wp * 100 >= ranked[1].w * G.KEEP_PCT then
      local out = {}
      for i = 1, math.min(k, #prev) do out[i] = prev[i] end
      return out
    end
  end
  local out = {}
  for _, r in ipairs(ranked) do
    if #out >= k then break end
    local ok = true
    for _, s in ipairs(out) do if G.gap_sides(s, r.side) < 2 then ok = false end end
    if ok then out[#out + 1] = r.side end
  end
  return out
end

--- Tailles des groupes pour n tourelles sur `nsides` côtés : ceil(n / G.GROUP_MAX) groupes au plus (au moins 1, au plus nsides), le reste
--- aux premiers groupes. Rend une liste de tailles (somme = n).
function G.sizes(n, nsides)
  n, nsides = math.floor(num(n)), math.floor(num(nsides))
  if n <= 0 or nsides <= 0 then return {} end
  local ng = math.min(nsides, math.max(1, math.ceil(n / G.GROUP_MAX)))
  local out = {}
  local base, extra = math.floor(n / ng), n % ng
  for g = 1, ng do out[g] = base + (g <= extra and 1 or 0) end
  return out
end

--- Places des tourelles (relatives au QG) : { { dx, dy, group, side } }, groupe 1 d'abord, du centre de la ligne vers ses bouts (un groupe
--- incomplet reste serré). n tourelles, `sides` (G.choose_sides), `gap` écart entre centres (tuiles). Liste vide sans côté. #rendu = n.
function G.slots(n, sides, gap)
  local out = {}
  if not sides or #sides == 0 then return out end
  gap = num(gap)
  if gap <= 0 then return out end
  for g, m in ipairs(G.sizes(n, #sides)) do
    local s = sides[g]
    local u = G.DIRS[s]
    local cx, cy = u[1] * G.RADIUS, u[2] * G.RADIUS
    local tx, ty = -u[2], u[1]
    -- du centre vers les bouts : rangs (k - (m - 1) / 2), triés par valeur absolue (négatif d'abord à égalité)
    local ranks = {}
    for k = 0, m - 1 do ranks[#ranks + 1] = k - (m - 1) / 2 end
    table.sort(ranks, function(a, b)
      if math.abs(a) ~= math.abs(b) then return math.abs(a) < math.abs(b) end
      return a < b
    end)
    for _, r in ipairs(ranks) do
      out[#out + 1] = { dx = round(cx + tx * r * gap), dy = round(cy + ty * r * gap), group = g, side = s }
    end
  end
  return out
end

--- Appui de chaque tourelle : list = { { x, y, s } } (s = part armée en ‰, 0 à 1000), portée `range`, centre du QG (cx, cy). Le tueur de la
--- tourelle i est à G.REACH tuiles d'elle, sur la demi-droite qui part du centre (au centre : sur elle). Rend weakest (la plus petite somme
--- des parts des tourelles qui ont ce tueur à portée, elle comprise si elle l'a), total (somme des parts), worst (indice).
function G.support(list, range, cx, cy)
  list = list or {}
  cx, cy = num(cx), num(cy)
  local r = num(range) * G.SUPPORT_PCT / 100
  local r2 = r * r
  local total, weakest, worst = 0, nil, nil
  for _, a in ipairs(list) do total = total + num(a.s) end
  for i, a in ipairs(list) do
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
  return weakest or 0, total, worst
end

--- Valeur armée du QG face à une vague : value × weakest / total (entier). 0 sans part armée.
function G.facing(value, weakest, total)
  value, weakest, total = num(value), num(weakest), num(total)
  if total <= 0 or value <= 0 then return 0 end
  if weakest >= total then return math.floor(value) end
  return math.floor(value * weakest / total)
end

--- Déplacements : turrets = { { x, y, id } } (positions absolues), places absolues `targets` = { { x, y } } dans l'ordre. Chaque place, dans
--- l'ordre, prend la tourelle libre la plus proche (numéro croissant à égalité). Rend { { i (indice dans turrets), x, y, d } } des tourelles
--- à plus de G.MOVE_MIN tuiles de leur place, dans l'ordre des places. Au plus min(#turrets, #targets) affectations : jamais une de plus.
function G.assign(turrets, targets)
  local used, moves = {}, {}
  for _, p in ipairs(targets or {}) do
    local best, bd, bid
    for i, t in ipairs(turrets or {}) do
      if not used[i] then
        local dx, dy = num(t.x) - num(p.x), num(t.y) - num(p.y)
        local d = dx * dx + dy * dy
        if bd == nil or d < bd or (d == bd and num(t.id) < num(bid)) then best, bd, bid = i, d, t.id end
      end
    end
    if not best then break end
    used[best] = true
    if bd > G.MOVE_MIN * G.MOVE_MIN then moves[#moves + 1] = { i = best, x = p.x, y = p.y, d = math.sqrt(bd) } end
  end
  return moves
end

--- Un regroupement est-il dû ? a = { on, calm (aucun ennemi près du QG), tick, last (tick du dernier), sides (nombre de côtés choisis) }.
function G.due(a)
  a = a or {}
  if not a.on or not a.calm or num(a.sides) <= 0 then return false end
  if a.last ~= nil and num(a.tick) - num(a.last) < G.PERIOD then return false end
  return true
end

return G
