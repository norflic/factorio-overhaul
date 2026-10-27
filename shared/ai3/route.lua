--[[
  Lot IA3-k : ITINÉRAIRE GROSSIER d'un PNJ (docs/IA3K_COMPORTEMENTS.md §3). PUR : aucune API Factorio
  (tests/ia3k_route_test.lua).

  Le pathfinder du moteur (request_path) ne prend aucun coût de danger : on lui donne des POINTS DE PASSAGE.
  - Sans danger dans la boîte du trajet : deux points de passage tirés par tournée, au tiers et aux deux tiers du trajet,
    décalés latéralement de h, |h| dans [V_MIN, V_MAX] × D, côté changé d'une tournée à l'autre avec une chance de FLIP
    pour mille, borné à CAP_LO-CAP_HI tuiles (C1 : on ne suit pas toujours la même ligne ; allongement prévu ≤ 9,1 %,
    mesuré en moteur réel ≈ 2 h, voir CAP_HI).
  - Avec danger : A* déterministe sur les cases de shared/ai3/danger.lua (8 voisins, coût 10 / 14 × (1 + danger / 100),
    case ≥ B infranchissable sauf départ et but), bruit de tournée ≤ NOISE pour mille par case (variété, allongement
    borné : longueur ≤ coût ≤ (1 + NOISE) × coût du meilleur chemin sans bruit), au plus MAX_EXPAND développements ;
    égalités tranchées par la clé de case (aucun ordre de pairs). Le chemin de cases est réduit à ses tournants : un
    segment est gardé droit tant qu'il ne touche aucune case marquée (contrôle tous les SAMPLE tuiles).
  Racines carrées seulement (aucune trigonométrie).
]]

local D = require("shared.ai3.danger")
local Tr = require("shared.faction.traits")

local R = {}

R.V_MIN = 80       -- pour mille de la distance
R.V_MAX = 180
R.FLIP = 667       -- chance (pour mille) de changer de côté par rapport à la tournée précédente
-- Écart borné à 8-20 tuiles : en moteur réel, un aller vers des points de passage décalés de h s'allonge d'environ 2 h (le
-- chemin suivi ne prend pas la diagonale prévue) ; à 12-28 tuiles, 10 allers sur 24 dépassaient + 15 % (C1) sur 320
-- tuiles (final-f8c44de variete-20261020 : 343 à 381 tuiles) ; à 20 au plus : ≈ 360 + quelques tuiles, sous 374.
R.CAP_LO = 8       -- tuiles
R.CAP_HI = 20
R.V_FROM = 40      -- pas de variation sous 40 tuiles
R.NOISE = 100      -- bruit de tournée (pour mille du coût d'une case), A* seulement
R.MAX_EXPAND = 1500
R.BOX_MARGIN = 8   -- cases autour de la boîte départ-but
R.SAMPLE = 4
R.MARKED = 4       -- une case est « marquée » pour la réduction au-dessus de B / MARKED

local function dist(ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  return math.sqrt(dx * dx + dy * dy)
end
R.dist = dist

--- Longueur d'une polyligne départ, points, but.
function R.length(start, pts, goal)
  local L, px, py = 0, start.x, start.y
  for _, p in ipairs(pts) do
    L = L + dist(px, py, p.x, p.y)
    px, py = p.x, p.y
  end
  return L + dist(px, py, goal.x, goal.y)
end

--- Points échantillonnés tous les `step` tuiles le long de la polyligne (départ et but compris).
function R.samples(start, pts, goal, step)
  local out = { { x = start.x, y = start.y } }
  local px, py = start.x, start.y
  local all = {}
  for _, p in ipairs(pts) do all[#all + 1] = p end
  all[#all + 1] = goal
  for _, p in ipairs(all) do
    local d = dist(px, py, p.x, p.y)
    local n = math.max(1, math.ceil(d / step))
    for i = 1, n do
      out[#out + 1] = { x = px + (p.x - px) * i / n, y = py + (p.y - py) * i / n }
    end
    px, py = p.x, p.y
  end
  return out
end

--- Danger lu en un point : un point posé sur une frontière de cases (un coin, un bord) appartient à toutes les cases qu'il
--- touche ; on prend la moins dangereuse (sinon un coin de deux cases sûres est lu dans la case marquée voisine). Rend
--- aussi la clé de la case retenue.
local EPS = 0.01
local CORNERS = { { -EPS, -EPS }, { EPS, -EPS }, { -EPS, EPS }, { EPS, EPS } } -- constante : aucune table par appel (coût)
function R.danger_pt(field, x, y)
  local best, bk = nil, nil
  for _, o in ipairs(CORNERS) do
    local k = D.key(D.cell(x + o[1]), D.cell(y + o[2]))
    local d = field[k] or 0
    if not best or d < best or (d == best and k < bk) then best, bk = d, k end
  end
  return best, bk
end

--- Danger maximal le long de la polyligne (case du départ exclue), danger de la case du but.
function R.profile(field, start, pts, goal)
  local sk = D.key(D.cell(start.x), D.cell(start.y))
  local mx = 0
  for _, s in ipairs(R.samples(start, pts, goal, R.SAMPLE)) do
    local d, k = R.danger_pt(field, s.x, s.y)
    if k ~= sk and d > mx then mx = d end
  end
  return mx, field[D.key(D.cell(goal.x), D.cell(goal.y))] or 0
end

--- Points de passage de la variation (C1) : tirage `draw(n)` -> entier de 1 à n (flux de la tournée) ; `prev` : côté de
--- la tournée précédente (1, -1 ou nil). Renvoie la liste des 2 points (nil sous V_FROM), l'écart h, le côté.
function R.via(start, goal, draw, prev)
  local D0 = dist(start.x, start.y, goal.x, goal.y)
  if D0 < R.V_FROM or not draw then return nil, 0, prev end
  -- Écart en tuiles : [V_MIN, V_MAX] × D, borné à [CAP_LO, CAP_HI] tuiles (un long trajet ne s'écarte pas de 50 tuiles
  -- dans l'inconnu).
  local lo = math.min(R.V_MIN * D0 / 1000, R.CAP_LO)
  local hi = math.min(R.V_MAX * D0 / 1000, R.CAP_HI)
  local mag = lo + (hi - lo) * (draw(1001) - 1) / 1000
  local side
  if prev == 1 or prev == -1 then
    side = (draw(1000) <= R.FLIP) and -prev or prev
  else
    side = draw(2) == 1 and 1 or -1
  end
  local h = side * mag
  local ux, uy = (goal.x - start.x) / D0, (goal.y - start.y) / D0
  local out = {}
  for k = 1, 2 do
    local bx, by = start.x + (goal.x - start.x) * k / 3, start.y + (goal.y - start.y) * k / 3
    out[k] = { x = bx - uy * h, y = by + ux * h }
  end
  return out, h, side
end

-- Tas binaire min sur { f, k } (égalité : clé croissante).
-- Tas binaire (ordre : f, puis clé). Comparaisons écrites en ligne (coût), mêmes résultats que less(a, b).
local function push(h, it)
  local i = #h + 1
  h[i] = it
  local f, k = it.f, it.k
  while i > 1 do
    local p = (i - i % 2) / 2
    local hp = h[p]
    if f < hp.f or (f == hp.f and k < hp.k) then h[i], h[p] = hp, it; i = p else break end
  end
end
local function pop(h)
  local top = h[1]
  local n = #h
  local last = h[n]
  h[n] = nil
  n = n - 1
  if n > 0 then
    h[1] = last
    local i = 1
    while true do
      local l, r, m = 2 * i, 2 * i + 1, i
      local hm = h[m]
      if l <= n then
        local hl = h[l]
        if hl.f < hm.f or (hl.f == hm.f and hl.k < hm.k) then m, hm = l, hl end
      end
      if r <= n then
        local hr = h[r]
        if hr.f < hm.f or (hr.f == hm.f and hr.k < hm.k) then m, hm = r, hr end
      end
      if m == i then break end
      h[i], h[m] = hm, h[i]
      i = m
    end
  end
  return top
end

local NB = { { 1, 0, 10 }, { -1, 0, 10 }, { 0, 1, 10 }, { 0, -1, 10 }, { 1, 1, 14 }, { 1, -1, 14 }, { -1, 1, 14 }, { -1, -1, 14 } }

local function octile(ax, ay, bx, by)
  local dx, dy = math.abs(ax - bx), math.abs(ay - by)
  local mn, mx = dx < dy and dx or dy, dx < dy and dy or dx
  return 14 * mn + 10 * (mx - mn)
end

--- A* sur les cases. Renvoie la liste des cases { cx, cy } du départ au but, ou nil (bloqué ou trop cher), puis le
--- nombre de développements.
-- Coût (banc final-3958412 verif-guide-1618033988 : 3 020 pics de 7,7 ms) : clés et bruit calculés en ligne, bruit d'une
-- case mémorisé pendant l'appel, voisins par indice ; mêmes opérations, dans le même ordre, que la version d'origine
-- (tests/ia3k_regles_test.lua compare les deux sur des cartes tirées au sort).
local OFF = D.OFF
function R.astar(field, sc, gc, B, seed, max_expand)
  local floor = math.floor
  local cx0 = math.min(sc[1], gc[1]) - R.BOX_MARGIN
  local cy0 = math.min(sc[2], gc[2]) - R.BOX_MARGIN
  local cx1 = math.max(sc[1], gc[1]) + R.BOX_MARGIN
  local cy1 = math.max(sc[2], gc[2]) + R.BOX_MARGIN
  local gx, gy = gc[1], gc[2]
  local sk, gk = (sc[1] + OFF) * 65536 + (sc[2] + OFF), (gx + OFF) * 65536 + (gy + OFF)
  local g, from, closed = { [sk] = 0 }, {}, {}
  local open = {}
  push(open, { f = octile(sc[1], sc[2], gx, gy), k = sk, cx = sc[1], cy = sc[2] })
  local expand = 0
  local cap = max_expand or R.MAX_EXPAND
  local M1, NZ = Tr.MOD - 1, R.NOISE + 1
  local TM = Tr.MOD
  local nzc = {}
  while #open > 0 do
    local cur = pop(open)
    local ck = cur.k
    if ck == gk then
      local path, k = {}, gk
      while k do
        local x, y = D.unkey(k)
        table.insert(path, 1, { x, y })
        k = from[k]
      end
      return path, expand
    end
    if not closed[ck] then
      closed[ck] = true
      expand = expand + 1
      if expand > cap then return nil, expand end
      local ccx, ccy, gcur = cur.cx, cur.cy, g[ck]
      for q = 1, 8 do
        local nb = NB[q]
        local nx, ny = ccx + nb[1], ccy + nb[2]
        if nx >= cx0 and nx <= cx1 and ny >= cy0 and ny <= cy1 then
          local nk = (nx + OFF) * 65536 + (ny + OFF)
          local dg = field[nk] or 0
          if not closed[nk] and (dg < B or nk == gk) then
            local noise = 0
            if seed then
              noise = nzc[nk]
              if not noise then
                -- Tr.mulmod(nk % (MOD - 1) + 1, seed), en ligne
                local a = nk % M1 + 1
                local hi, lo = floor(seed / 65536), seed % 65536
                noise = ((a * hi % TM) * 65536 % TM + a * lo) % TM % NZ
                nzc[nk] = noise
              end
            end
            local step = nb[3] * (1000 + dg * 10 + noise) / 1000
            local ng = gcur + step
            local gn = g[nk]
            if not gn or ng < gn then
              g[nk] = ng
              from[nk] = ck
              push(open, { f = ng + octile(nx, ny, gx, gy), k = nk, cx = nx, cy = ny })
            end
          end
        end
      end
    end
  end
  return nil, expand
end

--- Un segment (a -> b) ne touche-t-il aucune case de danger ≥ lim (case du départ exclue) ?
-- Mêmes points que R.samples(a, {}, b, R.SAMPLE), sans table par point (coût : la réduction essaie O(n²) segments ; banc
-- final-3958412 verif-guide-1618033988 : 3 020 pics de 7,7 ms en moyenne).
local function clear(field, a, b, lim, sk)
  local d0, k0 = R.danger_pt(field, a.x, a.y)
  if k0 ~= sk and d0 >= lim then return false end
  local px, py = a.x, a.y
  local n = math.max(1, math.ceil(dist(px, py, b.x, b.y) / R.SAMPLE))
  for i = 1, n do
    local d, k = R.danger_pt(field, px + (b.x - px) * i / n, py + (b.y - py) * i / n)
    if k ~= sk and d >= lim then return false end
  end
  return true
end

--- Réduction du chemin de cases aux tournants (string pulling glouton) : points intermédiaires (départ et but exclus).
function R.reduce(field, start, cells, goal, lim)
  local pts = {}
  for i = 2, #cells - 1 do
    local x, y = D.center(cells[i][1], cells[i][2])
    pts[#pts + 1] = { x = x, y = y }
  end
  local chain = { start }
  for _, p in ipairs(pts) do chain[#chain + 1] = p end
  chain[#chain + 1] = goal
  local sk = D.key(D.cell(start.x), D.cell(start.y))
  local out, i = {}, 1
  while i < #chain do
    local j = #chain
    while j > i + 1 and not clear(field, chain[i], chain[j], lim, sk) do j = j - 1 end
    -- Premier segment accepté d'office (aucun plus loin n'est sûr) mais qui coupe l'angle d'une case marquée : il part de
    -- la position RÉELLE du PNJ, pas d'un centre de case. Si la case de départ est sûre, on passe d'abord par son centre
    -- (entre centres de cases de l'A*, les diagonales sont sûres par construction). Banc final-a05e690 : entrée de 5,8
    -- tuiles dans la zone d'un ver.
    if i == 1 and j == 2 and (field[sk] or 0) < lim and not clear(field, chain[1], chain[2], lim, sk) then
      local cx, cy = D.center(D.cell(start.x), D.cell(start.y))
      out[#out + 1] = { x = cx, y = cy }
    end
    if j < #chain then out[#out + 1] = chain[j] end
    i = j
  end
  return out
end

R.SEG_MAX = 24
--- Points intermédiaires pour qu'aucun segment départ -> pts -> but ne dépasse `maxlen` tuiles (le but n'est pas ajouté).
function R.subdivide(start, pts, goal, maxlen)
  local chain = { start }
  for _, p in ipairs(pts) do chain[#chain + 1] = p end
  chain[#chain + 1] = goal
  local out = {}
  for i = 1, #chain - 1 do
    local a, b = chain[i], chain[i + 1]
    local L = dist(a.x, a.y, b.x, b.y)
    local n = math.ceil(L / maxlen)
    for k = 1, n - 1 do
      out[#out + 1] = { x = a.x + (b.x - a.x) * k / n, y = a.y + (b.y - a.y) * k / n }
    end
    if i < #chain - 1 then out[#out + 1] = b end
  end
  return out
end

--- Case SÛRE la plus proche (danger < lim), par anneaux de cases autour de p (au plus R.ESCAPE_RINGS), à égalité la plus
--- faible puis la plus petite clé ; centre de la case, ou nil.
R.ESCAPE_RINGS = 6
function R.escape(field, p, lim)
  local cx, cy = D.cell(p.x), D.cell(p.y)
  if (field[D.key(cx, cy)] or 0) < lim then return nil end
  for ring = 1, R.ESCAPE_RINGS do
    local best, bd, bk = nil, nil, nil
    for dy = -ring, ring do
      for dx = -ring, ring do
        if math.max(math.abs(dx), math.abs(dy)) == ring then
          local k = D.key(cx + dx, cy + dy)
          local d = field[k] or 0
          if d < lim and (not bd or d < bd or (d == bd and k < bk)) then best, bd, bk = { cx + dx, cy + dy }, d, k end
        end
      end
    end
    if best then
      local x, y = D.center(best[1], best[2])
      return { x = x, y = y }
    end
  end
  return nil
end

--- Itinéraire de start à goal. opts = { field (D.field), n (cases non nulles du champ), B (blocage), seed (bruit de
--- tournée, entier ≥ 1, ou nil), draw (tirage de la variation, ou nil), side (côté de la tournée précédente), max_expand }.
--- Renvoie { pts, len, direct, max_d, goal_d, blocked, astar, h, side, expand }.
function R.plan(start, goal, opts)
  local field = opts.field or {}
  local direct = dist(start.x, start.y, goal.x, goal.y)
  local sc = { D.cell(start.x), D.cell(start.y) }
  local gc = { D.cell(goal.x), D.cell(goal.y) }
  -- Danger dans la boîte du trajet ?
  local any = false
  if (opts.n or 1) > 0 then
    local cx0, cx1 = math.min(sc[1], gc[1]) - R.BOX_MARGIN, math.max(sc[1], gc[1]) + R.BOX_MARGIN
    local cy0, cy1 = math.min(sc[2], gc[2]) - R.BOX_MARGIN, math.max(sc[2], gc[2]) + R.BOX_MARGIN
    for k, v in pairs(field) do -- existence seulement : le résultat ne dépend pas de l'ordre
      if v > 0 then
        local x, y = D.unkey(k)
        if x >= cx0 and x <= cx1 and y >= cy0 and y <= cy1 then any = true break end
      end
    end
  end
  local B = opts.B or 600
  local res = { direct = direct, pts = {}, blocked = false, astar = false, h = 0, expand = 0 }
  if not any then
    local v, h, side = R.via(start, goal, opts.draw, opts.side)
    if v then res.pts = v end
    res.h, res.side = h, side
  else
    res.astar = true
    local lim = math.max(1, math.floor(B / R.MARKED))
    local cells, n = R.astar(field, sc, gc, B, opts.seed, opts.max_expand)
    res.expand = n
    if not cells then
      -- Bloqué (le PNJ est déjà dans une zone marquée, ou le but est encerclé) : d'abord SORTIR vers la case sûre la plus
      -- proche (jamais traverser le danger pour gagner du chemin), puis l'itinéraire depuis elle.
      res.blocked = true
      res.pts = {}
      local esc = R.escape(field, start, lim)
      if esc then
        res.escape = esc
        local ec = { D.cell(esc.x), D.cell(esc.y) }
        local cells2, n2 = R.astar(field, ec, gc, B, opts.seed, opts.max_expand)
        res.expand = n + n2
        res.pts = { esc }
        if cells2 then
          res.blocked = false
          for _, p in ipairs(R.reduce(field, esc, cells2, goal, lim)) do res.pts[#res.pts + 1] = p end
        else
          res.partial = true -- sortir d'abord ; l'itinéraire sera recalculé depuis la case sûre
        end
      end
    else
      res.pts = R.reduce(field, start, cells, goal, lim)
    end
    -- F300 : entre deux points non alignés sur un axe, le chemin du moteur fait « diagonale puis tout droit » et s'écarte du
    -- segment d'environ 0,21 × sa longueur. Les segments d'un itinéraire qui contourne un danger sont donc découpés en
    -- tronçons de R.SEG_MAX tuiles au plus (écart ≤ 5 tuiles) : le chemin suivi reste dans le couloir sûr prévu.
    res.pts = R.subdivide(start, res.pts, goal, R.SEG_MAX)
  end
  res.len = R.length(start, res.pts, goal)
  res.max_d, res.goal_d = R.profile(field, start, res.pts, goal)
  return res
end

--- Écart latéral (tuiles) d'un point p à la droite start -> goal (signé : à gauche positif).
function R.lateral(start, goal, p)
  local D0 = dist(start.x, start.y, goal.x, goal.y)
  if D0 <= 0 then return 0 end
  return ((goal.x - start.x) * (p.y - start.y) - (goal.y - start.y) * (p.x - start.x)) / D0
end

--- Position le long de la droite start -> goal (tuiles depuis start).
function R.along(start, goal, p)
  local D0 = dist(start.x, start.y, goal.x, goal.y)
  if D0 <= 0 then return 0 end
  return ((goal.x - start.x) * (p.x - start.x) + (goal.y - start.y) * (p.y - start.y)) / D0
end

--- Écart latéral MÉDIAN entre deux trajets (listes de positions) vers le même but, mesuré par tranches de `bin` tuiles le
--- long de la droite start -> goal (tranches présentes dans les deux). Renvoie l'écart médian, le nombre de tranches.
function R.median_gap(start, goal, a, b, bin)
  bin = bin or 8
  local function profile(list)
    local acc = {}
    for _, p in ipairs(list) do
      local s = math.floor(R.along(start, goal, p) / bin)
      local l = R.lateral(start, goal, p)
      local e = acc[s]
      if not e then acc[s] = { sum = l, n = 1 } else e.sum, e.n = e.sum + l, e.n + 1 end
    end
    return acc
  end
  local pa, pb = profile(a), profile(b)
  local keys = {}
  for s in pairs(pa) do if pb[s] then keys[#keys + 1] = s end end
  table.sort(keys)
  local D0 = dist(start.x, start.y, goal.x, goal.y)
  local gaps = {}
  for _, s in ipairs(keys) do
    -- tranches du milieu seulement (10 % à 90 % du trajet) : départ et arrivée sont communs
    local mid = (s + 0.5) * bin
    if mid >= 0.1 * D0 and mid <= 0.9 * D0 then
      gaps[#gaps + 1] = math.abs(pa[s].sum / pa[s].n - pb[s].sum / pb[s].n)
    end
  end
  if #gaps == 0 then return 0, 0 end
  table.sort(gaps)
  local m = #gaps
  local med = (m % 2 == 1) and gaps[(m + 1) / 2] or (gaps[m / 2] + gaps[m / 2 + 1]) / 2
  return med, m
end

return R
