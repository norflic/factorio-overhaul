--[[
  Lot RESEAU-GRAPHE : BUS DE PRODUITS entre les blocs producteurs et les quais des consommateurs. Règle PURE : aucune API du jeu, aucun nom
  d'objet (un objet est une chaîne opaque) ; lue hors jeu (tests/reseau_graphe_test.lua). Conception : docs/conception/RESEAU_GRAPHE.md.

  Demande du DC (8/11, en jouant la 0.6.65) : les PNJ usent les coffres posés aux fonderies, mais « il faut faire pas mal de trajets pour aller
  les chercher » ; « un problème de théorie des graphes, relier un maximum les ressources aux assembleurs », « blocs et graphes connexes »,
  « un problème de maximisation avec les K-max ... le nombre de bus ». Aujourd'hui (shared/team/liaison.lua) un quai n'est relié qu'à UN coffre
  de sortie à 40 tuiles au plus : sur la sauvegarde du DC (255 min), 1 quai servi par tapis sur 33 à 59 par équipe.

  Modèle. Producteurs = coffres de sortie (objet, tuile, débit disponible en objets/min), consommateurs = quais d'entrée (objet, tuile, débit
  demandé). Le QG est le moyeu : sans tapis, un objet fait DEUX trajets de PNJ (collecte sortie -> QG, remplissage QG -> quai). Un BUS est un
  tapis droit (tronc) qui suit un axe de rue, avec des branches perpendiculaires vers chaque coffre (arbre « en peigne ») ; une file de tapis a 2
  voies, une voie porte un objet. Le tapis va dans un seul sens : un consommateur ne reçoit que de ce qui est en amont.

  1. LEGS (Rg.leg) : coût d'un trajet par objet porté = (2 d / marche + prise) / lot, lots de la collecte (200) et du remplissage (340).
  2. COMPOSANTES (components) : par objet, graphe des terminaux relié si Manhattan <= Rg.LINK_R (ou dist(a, b) rend un nombre, nil = interdit) ;
     composantes connexes par union-find ; au-delà de Rg.N_MAX terminaux, coupe à la médiane de l'axe le plus étendu (récursif).
  3. BUS D'UNE COMPOSANTE (Rg.bus_of) : axe et sens = déplacement du centre des producteurs vers celui des consommateurs ; balayage (evaluate)
     le long du tronc : le débit dans la voie monte aux producteurs (borné par Rg.LANE_CAP), descend aux consommateurs ; le gain est la somme
     des trajets évités (PNJ-secondes par minute). Tronc à la médiane des coordonnées perpendiculaires (minimise la somme des branches).
     Élagage glouton à rebours (peel) : on retire le terminal dont le départ améliore le plus la valeur nette tmax x gain - coût, tant que
     cela améliore et jusqu'à tenir dans Rg.MAX_TRUNK.
  4. CHOIX (select_run) : au plus k files de tapis (2 voies chacune) ; deux objets de même axe, sens et rue (Rg.SHARE_PERP) dont les troncs se
     recouvrent partagent une file et ne payent qu'une fois le recouvrement ; deux ordres (valeur nette, valeur nette / coût),
     on garde le meilleur total. Sortie : bus ordonnés (ordre de pose), prises ordonnées par contribution.

  Entrées (inp) : producers = { { key, item, x, y, rate } }, consumers = { { key, item, x, y, rate } } (rate en objets/min), hub = { x, y }, k
  (files, défaut Rg.BELTS), budget (plaques, nil = sans borne), hub_share (part des sorties laissée au QG, défaut Rg.HUB_SHARE), labor, price,
  tmax. Le crochet dist(a, b) est passé à Rg.step / Rg.plan (jamais rangé dans le travail : le travail est sérialisable).

  Découpage : Rg.begin / Rg.step(job, unités, dist) / Rg.result ; une unité = un objet (composantes) ou un bus ; le travail ne contient que
  des nombres, chaînes et tables. Rg.plan = begin + step jusqu'au bout.

  Déterminisme : listes triées avec départage par clé, aucune trigonométrie, aucune horloge, aucun hasard. Valeurs NON MESURÉES : Rg.HUB_SHARE,
  Rg.LANE_CAP (tapis de base : 15 objets/s sur 2 voies), Rg.ARM_RATE (bras électrique de base, coffre à tapis).
]]

local Li = require("shared.team.liaison")

local Rg = {}

Rg.BELTS = 2            -- files de tapis (« k bus ») par défaut ; une file = 2 voies
Rg.LANES_PER_BELT = 2
Rg.LANE_CAP = 450       -- objets/min par voie (7,5/s : tapis de base 15/s sur 2 voies)
Rg.ARM_RATE = 50        -- objets/min par bras électrique (0,83/s)
Rg.MAX_ARMS = 4         -- bras au plus par coffre (débit d'un terminal borné à MAX_ARMS x ARM_RATE)
Rg.COLLECT_BATCH = 200  -- objets par trajet de collecte (Build.COLLECT_AT, script/team/build.lua)
Rg.FILL_BATCH = 340     -- objets par trajet de remplissage (Build.QUAI_FILL - Build.QUAI_LOW)
Rg.LINK_R = 160         -- tuiles (Manhattan) : deux terminaux d'un même objet plus proches sont de la même composante
Rg.MAX_TRUNK = 220      -- tuiles de tapis (tronc et branches) au plus par bus
Rg.N_MAX = 32           -- terminaux au plus par composante (au-delà : coupe)
Rg.PEEL_MAX = 40        -- retraits (ou ajouts) au plus de l'élagage et de la croissance
Rg.DEPTH_MAX = 3        -- bus au plus par composante (le premier, puis les restes)
Rg.HUB_SHARE = 0.3      -- part du débit des sorties laissée à la collecte vers le QG (construction et fabrication à la main)
Rg.DETOUR = Li.EST_FACTOR
Rg.SHARE_PERP = 4       -- tuiles : deux troncs à cet écart au plus sont dans la même rue
Rg.OVERLAP_MIN = 0.5    -- part du plus court tronc qui doit être recouverte pour partager une file
Rg.MIN_RATE = 1         -- objets/min : en dessous, un terminal ou un bus ne compte pas
Rg.EPOCH_STEP = 3       -- une file de plus toutes les EPOCH_STEP époques (proposition, à valider par le DC)
Rg.BELT_TILES = 150     -- tuiles de tapis tenues en réserve par file ouverte (un bus type de l'exemple : 130 à 190 tuiles)
Rg.CROSS_PLAQUES = 20   -- plaques-équivalent d'un croisement de deux bus (une paire de tapis souterrains) ; NON MESURÉ
Rg.EPS = 1e-6

local function manhattan(ax, ay, bx, by) return math.abs(ax - bx) + math.abs(ay - by) end

local function copy(list)
  local o = {}
  for i = 1, #list do o[i] = list[i] end
  return o
end

local function without(list, skip)
  local o = {}
  for i = 1, #list do if i ~= skip then o[#o + 1] = list[i] end end
  return o
end

local function term_lt(a, b)
  if a.key ~= b.key then return a.key < b.key end
  return a.kind < b.kind
end

--- Coût, en PNJ-secondes par objet, d'un trajet aller-retour à la distance d (tuiles) pour un lot de `batch` objets.
function Rg.leg(d, batch)
  return (2 * d / Li.WALK + Li.HANDLE_S) / math.max(1, batch)
end

---------------------------------------------------------------------------------------------------
-- 1. Terminaux et composantes
---------------------------------------------------------------------------------------------------
local function make_terminal(t, kind, hub, hub_share)
  local rate = t.rate or 0
  if kind == "p" then rate = rate * (1 - hub_share) end
  rate = math.min(rate, Rg.MAX_ARMS * Rg.ARM_RATE)
  if rate < Rg.MIN_RATE then return nil end
  local d = manhattan(hub.x, hub.y, t.x, t.y)
  return { key = tostring(t.key), kind = kind, item = t.item, x = t.x, y = t.y, rate = rate,
    arms = math.max(1, math.ceil(rate / Rg.ARM_RATE - Rg.EPS)),
    leg = Rg.leg(d, kind == "p" and Rg.COLLECT_BATCH or Rg.FILL_BATCH) }
end

--- Composantes connexes d'une liste de terminaux triée par clé : union-find, arête si Manhattan <= Rg.LINK_R (ou dist rend un nombre
--- <= Rg.LINK_R ; nil = interdit). Rend une liste de listes, dans l'ordre du plus petit élément de chaque composante.
function Rg.components(ts, dist)
  local n = #ts
  local parent = {}
  for i = 1, n do parent[i] = i end
  local function find(i)
    while parent[i] ~= i do
      parent[i] = parent[parent[i]]
      i = parent[i]
    end
    return i
  end
  for i = 1, n - 1 do
    local a = ts[i]
    for j = i + 1, n do
      local b = ts[j]
      local d
      if dist then d = dist(a, b) else d = manhattan(a.x, a.y, b.x, b.y) end
      if d ~= nil and d <= Rg.LINK_R then
        local ri, rj = find(i), find(j)
        if ri ~= rj then
          if ri < rj then parent[rj] = ri else parent[ri] = rj end
        end
      end
    end
  end
  local groups, order = {}, {}
  for i = 1, n do
    local r = find(i)
    if not groups[r] then groups[r] = {}; order[#order + 1] = r end
    table.insert(groups[r], ts[i])
  end
  local out = {}
  for _, r in ipairs(order) do out[#out + 1] = groups[r] end
  return out
end

--- Coupe une composante trop grosse à la médiane de son axe le plus étendu (récursif). Ajoute à `out`.
local function split(comp, out)
  if #comp <= Rg.N_MAX then out[#out + 1] = comp return end
  local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
  for _, t in ipairs(comp) do
    x0, x1 = math.min(x0, t.x), math.max(x1, t.x)
    y0, y1 = math.min(y0, t.y), math.max(y1, t.y)
  end
  local axis = (x1 - x0) >= (y1 - y0) and "x" or "y"
  local s = copy(comp)
  table.sort(s, function(a, b)
    if a[axis] ~= b[axis] then return a[axis] < b[axis] end
    return term_lt(a, b)
  end)
  local h = math.floor(#s / 2)
  local left, right = {}, {}
  for i = 1, #s do
    if i <= h then left[#left + 1] = s[i] else right[#right + 1] = s[i] end
  end
  split(left, out)
  split(right, out)
end

---------------------------------------------------------------------------------------------------
-- 2. Bus d'une composante
---------------------------------------------------------------------------------------------------
--- Axe et sens du bus : du centre (pondéré par le débit) des producteurs vers celui des consommateurs. nil sans producteur ou sans consommateur.
local function axis_of(comp)
  local wp, wc, px, py, cx, cy = 0, 0, 0, 0, 0, 0
  for _, t in ipairs(comp) do
    if t.kind == "p" then wp, px, py = wp + t.rate, px + t.rate * t.x, py + t.rate * t.y
    else wc, cx, cy = wc + t.rate, cx + t.rate * t.x, cy + t.rate * t.y end
  end
  if wp <= 0 or wc <= 0 then return nil end
  local dx, dy = cx / wc - px / wp, cy / wc - py / wp
  if math.abs(dx) >= math.abs(dy) then return { axis = "x", perp = "y", sign = dx >= 0 and 1 or -1 } end
  return { axis = "y", perp = "x", sign = dy >= 0 and 1 or -1 }
end

local function along(ax)
  return function(a, b)
    local pa, pb = ax.sign * a[ax.axis], ax.sign * b[ax.axis]
    if pa ~= pb then return pa < pb end
    if a.kind ~= b.kind then return a.kind == "p" end
    return a.key < b.key
  end
end

--- Évaluation d'un ensemble S de terminaux triés le long du tronc. Rend { served, gain (PNJ-s/min), trunk (tuiles de tronc et de branches),
--- tiles, plaques, pay_s (PNJ-s), payback_min, net (PNJ-s sur l'horizon), line, lo, hi, arms, per = { [i] = servi du terminal i } }.
local function evaluate(S, ax, o)
  local pool, pleg = 0, 0
  local served, gain = 0, 0
  local lo, hi = math.huge, -math.huge
  local perps, arms, sx, sy = {}, 0, 0, 0
  local per = {}
  for i = 1, #S do
    local t = S[i]
    local c = t[ax.axis]
    if c < lo then lo = c end
    if c > hi then hi = c end
    perps[i] = t[ax.perp]
    arms = arms + t.arms
    sx, sy = sx + t.x, sy + t.y
    per[i] = 0
    if t.kind == "p" then
      local q = math.min(t.rate, math.max(0, Rg.LANE_CAP - pool))
      if q > 0 then
        pleg = (pool * pleg + q * t.leg) / (pool + q)
        pool = pool + q
      end
      per[i] = q
    else
      local take = math.min(pool, t.rate)
      if take > 0 then
        pool = pool - take
        served = served + take
        gain = gain + take * (t.leg + pleg)
        per[i] = take
      end
      if pool <= Rg.EPS then pool, pleg = 0, 0 end
    end
  end
  table.sort(perps)
  local line = perps[math.ceil(#perps / 2)] or 0
  local stubs = 0
  for i = 1, #perps do stubs = stubs + math.abs(perps[i] - line) end
  local trunk = math.ceil((hi - lo + stubs) * Rg.DETOUR)
  local tiles = trunk + 2 * #S
  local price = o.price
  local plaques = tiles * price.belt + arms * price.arm + #S * price.pole
  local n_ent = tiles + arms + #S
  local n = math.max(1, #S)
  local trip_s = 2 * manhattan(o.hub.x, o.hub.y, sx / n, sy / n) / Li.WALK + Li.HANDLE_S
  local build_s = n_ent * Li.POSE_S + math.ceil(n_ent / Li.BATCH) * trip_s
  local pay_s = plaques / o.labor + build_s
  local payback = gain > 0 and pay_s / gain or math.huge
  return { served = served, gain = gain, trunk = trunk, tiles = tiles, plaques = plaques, pay_s = pay_s, payback_min = payback,
    net = o.tmax * gain - pay_s, line = line, lo = lo, hi = hi, arms = arms, per = per }
end

local function count_kinds(S)
  local np, nc = 0, 0
  for _, t in ipairs(S) do if t.kind == "p" then np = np + 1 else nc = nc + 1 end end
  return np, nc
end

--- Une passe de l'élagage glouton à rebours : retire le terminal dont le départ améliore le plus la valeur nette (ou, si le bus est trop long,
--- celui qui raccourcit le plus). Rend S2, ev2, ou nil si rien ne change.
local function peel_pass(S, ev, ax, o)
  if #S <= 2 then return nil end
  local np, nc = count_kinds(S)
  local feas = ev.trunk <= Rg.MAX_TRUNK
  local bi, bev
  for i = 1, #S do
    local t = S[i]
    if not ((t.kind == "p" and np <= 1) or (t.kind == "c" and nc <= 1)) then
      local e = evaluate(without(S, i), ax, o)
      local take
      if feas then
        take = e.net > (bev and bev.net or ev.net) + Rg.EPS -- retirer un terminal ne rallonge jamais le tronc (médiane, portée)
      else
        take = (not bev) or e.trunk < bev.trunk or (e.trunk == bev.trunk and e.net > bev.net + Rg.EPS)
      end
      if take then bi, bev = i, e end
    end
  end
  if not bi then return nil end
  return without(S, bi), bev
end

--- Croissance gloutonne, départ : la meilleure paire (producteur en amont, consommateur en aval). F : tous les terminaux, triés le long du
--- tronc. Rend le masque { [indice] = true } et son évaluation, ou nil sans paire qui tienne.
local function grow_seed(F, ax, o)
  local n = #F
  local bs, bev
  for i = 1, n do
    if F[i].kind == "p" then
      for j = i + 1, n do
        if F[j].kind == "c" then
          local e = evaluate({ F[i], F[j] }, ax, o)
          if e.trunk <= Rg.MAX_TRUNK and e.served > 0 and (not bev or e.net > bev.net + Rg.EPS) then bs, bev = { i, j }, e end
        end
      end
    end
  end
  if not bs then return nil end
  local mask = {}
  mask[bs[1]], mask[bs[2]] = true, true
  return mask, bev
end

--- Une passe de croissance : ajoute le terminal qui améliore le plus la valeur nette. Rend mask, ev, ou nil si rien ne s'ajoute.
local function grow_pass(F, mask, bev, ax, o)
  local n = #F
  local bi, be
  for i = 1, n do
    if not mask[i] then
      local T = {}
      for j = 1, n do if mask[j] or j == i then T[#T + 1] = F[j] end end
      local e = evaluate(T, ax, o)
      if e.trunk <= Rg.MAX_TRUNK and e.net > (be and be.net or bev.net) + Rg.EPS then bi, be = i, e end
    end
  end
  if not bi then return nil end
  mask[bi] = true
  return mask, be
end

--- Segments d'un bus (tronc et branches), pour compter les croisements : { o = "h" | "v", k = coordonnée fixe, a, b = bornes }.
local function segments(axis, line, lo, hi, taps)
  local out = { { o = axis == "x" and "h" or "v", k = line, a = lo, b = hi } }
  for _, t in ipairs(taps) do
    local along_c = axis == "x" and t.x or t.y
    local perp_c = axis == "x" and t.y or t.x
    if perp_c ~= line then
      out[#out + 1] = { o = axis == "x" and "v" or "h", k = along_c, a = math.min(perp_c, line), b = math.max(perp_c, line) }
    end
  end
  return out
end

--- Croisements de deux listes de segments (un horizontal et un vertical qui se coupent à l'intérieur de leurs deux bornes).
local function crossings(sa, sb)
  if not sa or not sb then return 0 end
  local n = 0
  for _, a in ipairs(sa) do
    for _, b in ipairs(sb) do
      if a.o ~= b.o then
        local h, v = a, b
        if a.o == "v" then h, v = b, a end
        if h.a < v.k and v.k < h.b and v.a < h.k and h.k < v.b then n = n + 1 end
      end
    end
  end
  return n
end

--- Bus d'une composante, par PASSES (une passe = au plus N_MAX évaluations du tronc ; Rg.step en fait une par unité). L'état est fait de
--- nombres, chaînes et tables. o = { hub, labor, price, tmax }.
function Rg.bus_start(comp, o)
  local ax = axis_of(comp)
  if not ax then return { phase = "done", why = "sans producteur ou sans consommateur" } end
  local F = copy(comp)
  table.sort(F, along(ax))
  return { phase = "peel", ax = ax, F = F, S = copy(F), ev = evaluate(F, ax, o), pass = 0 }
end

local function bus_finish(st, o)
  local ax, F = st.ax, st.F
  local S2, ev = st.S, st.ev
  if S2 and ev.trunk > Rg.MAX_TRUNK then S2, ev = nil, nil end
  if st.mask then
    local S3 = {}
    for j = 1, #F do if st.mask[j] then S3[#S3 + 1] = F[j] end end
    if not S2 or st.gev.net > ev.net + Rg.EPS then S2, ev = S3, st.gev end
  end
  if not S2 then st.why = "aucun producteur en amont d'un consommateur dans la limite de tronc" return end
  local np, nc = count_kinds(S2)
  if np < 1 or nc < 1 or ev.served < Rg.MIN_RATE then st.why = "rien de servi" return end
  if ev.net <= 0 then st.why = string.format("ne se paie pas (retour %.0f min > %.0f)", ev.payback_min, o.tmax) return end
  -- contribution de chaque terminal : gain perdu à son retrait (ordre de pose : les plus utiles d'abord)
  local taps = {}
  for i, t in ipairs(S2) do
    local e = evaluate(without(S2, i), ax, o)
    taps[#taps + 1] = { key = t.key, kind = t.kind, x = t.x, y = t.y, rate = t.rate, served = ev.per[i], contrib = ev.gain - e.gain, pos = i }
  end
  table.sort(taps, function(a, b)
    if a.contrib ~= b.contrib then return a.contrib > b.contrib end
    if a.pos ~= b.pos then return a.pos < b.pos end
    return a.key < b.key
  end)
  st.bus = { item = S2[1].item, axis = ax.axis, sign = ax.sign, line = ev.line, lo = ev.lo, hi = ev.hi, tiles = ev.tiles, trunk = ev.trunk,
    plaques = ev.plaques, pay_s = ev.pay_s, served = ev.served, gain = ev.gain, payback_min = ev.payback_min, net = ev.net,
    n_prod = np, n_cons = nc, taps = taps }
  st.bus.segs = segments(ax.axis, ev.line, ev.lo, ev.hi, taps)
end

--- Une passe. Rend vrai quand l'état est fini (st.bus ou st.why).
function Rg.bus_step(st, o)
  if st.phase == "peel" then
    st.pass = st.pass + 1
    local S2, e2
    if st.pass <= Rg.PEEL_MAX then S2, e2 = peel_pass(st.S, st.ev, st.ax, o) end
    if S2 then st.S, st.ev = S2, e2 else st.phase = "seed" end
  elseif st.phase == "seed" then
    local mask, e = grow_seed(st.F, st.ax, o)
    if mask then st.mask, st.gev, st.gpass, st.phase = mask, e, 0, "grow" else st.phase = "fin" end
  elseif st.phase == "grow" then
    st.gpass = st.gpass + 1
    local m2, e2
    if st.gpass <= Rg.PEEL_MAX then m2, e2 = grow_pass(st.F, st.mask, st.gev, st.ax, o) end
    if m2 then st.mask, st.gev = m2, e2 else st.phase = "fin" end
  elseif st.phase == "fin" then
    bus_finish(st, o)
    st.phase = "done"
  end
  return st.phase == "done"
end

--- Bus d'une composante, d'un coup : bus, ou nil, raison.
function Rg.bus_of(comp, o)
  local st = Rg.bus_start(comp, o)
  while not Rg.bus_step(st, o) do end
  return st.bus, st.why
end

---------------------------------------------------------------------------------------------------
-- 3. Choix des bus sous k files
---------------------------------------------------------------------------------------------------
local function first_key(c) return c.taps[1].key end

local function cand_lt(a, b)
  if a.item ~= b.item then return a.item < b.item end
  local ka, kb = first_key(a), first_key(b)
  if ka ~= kb then return ka < kb end
  return a.line < b.line
end

--- Un passage glouton dans l'ordre `order` (liste de candidats). Rend { picks = { { c, belt, ov, mnet, mplaq } }, belts, net, plaques }.
local function select_run(order, k, budget, o)
  local belts, picks = {}, {}
  local spent, net_total = 0, 0
  for _, c in ipairs(order) do
    local bb, bov = nil, 0
    for bi, b in ipairs(belts) do
      if b.axis == c.axis and b.sign == c.sign and #b.lanes < Rg.LANES_PER_BELT and not b.items[c.item]
        and math.abs(b.line - c.line) <= Rg.SHARE_PERP then
        local ov = math.min(b.hi, c.hi) - math.max(b.lo, c.lo)
        local short = math.min(b.hi - b.lo, c.hi - c.lo)
        if ov >= Rg.OVERLAP_MIN * math.max(1, short) and ov > bov then bb, bov = bi, ov end
      end
    end
    local mplaq, mnet = c.plaques, c.net
    if bb then
      local shared = math.ceil(bov * Rg.DETOUR)
      mplaq = math.max(0, c.plaques - shared * o.price.belt)
      mnet = c.net + shared * (o.price.belt / o.labor + Li.POSE_S)
    end
    -- croisements avec les bus déjà posés sur d'AUTRES files : une paire de souterrains chacun, payée par le bus qui arrive
    local nx = 0
    for _, q in ipairs(picks) do
      if q.belt ~= bb then nx = nx + crossings(q.c.segs, c.segs) end
    end
    mplaq = mplaq + nx * Rg.CROSS_PLAQUES
    mnet = mnet - nx * (Rg.CROSS_PLAQUES / o.labor + 2 * Li.POSE_S)
    if (bb or #belts < k) and (not budget or spent + mplaq <= budget) and mnet > 0 then
      if not bb then
        belts[#belts + 1] = { axis = c.axis, sign = c.sign, line = c.line, lo = c.lo, hi = c.hi, lanes = {}, items = {} }
        bb = #belts
      end
      local b = belts[bb]
      b.lanes[#b.lanes + 1] = c
      b.items[c.item] = true
      b.lo, b.hi = math.min(b.lo, c.lo), math.max(b.hi, c.hi)
      picks[#picks + 1] = { c = c, belt = bb, lane = #b.lanes, ov = bov, mnet = mnet, mplaq = mplaq, nx = nx }
      spent = spent + mplaq
      net_total = net_total + mnet
    end
  end
  return { picks = picks, belts = belts, net = net_total, plaques = spent }
end

local function choose(cands, k, budget, o)
  local A = copy(cands)
  table.sort(A, function(a, b)
    if a.net ~= b.net then return a.net > b.net end
    return cand_lt(a, b)
  end)
  local B = copy(cands)
  table.sort(B, function(a, b)
    local ra, rb = a.net / math.max(1, a.pay_s), b.net / math.max(1, b.pay_s)
    if ra ~= rb then return ra > rb end
    return cand_lt(a, b)
  end)
  -- A contient déjà le meilleur bus seul (premier de sa liste, s'il tient) : le meilleur des deux ordres vaut au moins max(meilleur seul,
  -- glouton par valeur / coût), donc la moitié de l'optimum du sac à dos quand les bus sont indépendants.
  local ra, rb = select_run(A, k, budget, o), select_run(B, k, budget, o)
  local best, which = ra, "net"
  if rb.net > best.net + Rg.EPS then best, which = rb, "net/cout" end
  return best, which
end

---------------------------------------------------------------------------------------------------
-- 4. Travail découpé
---------------------------------------------------------------------------------------------------
--- Prépare le travail. Rend le job (nombres, chaînes, tables ; aucune fonction).
function Rg.begin(inp)
  local opts = {
    hub = inp.hub or { x = 0, y = 0 },
    labor = inp.labor or Li.LABOR_VALUE,
    price = inp.price or Li.PRICE,
    tmax = inp.tmax or Li.TMAX,
    k = inp.k or Rg.BELTS,
    budget = inp.budget,
    hub_share = inp.hub_share or Rg.HUB_SHARE,
  }
  local seen, items, by = {}, {}, {}
  local demand, supply = 0, 0
  local function add(t, kind)
    local m = make_terminal(t, kind, opts.hub, kind == "p" and opts.hub_share or 0)
    if not m then return end
    if kind == "c" then demand = demand + m.rate else supply = supply + m.rate end
    if not seen[m.item] then seen[m.item] = true; items[#items + 1] = m.item; by[m.item] = {} end
    table.insert(by[m.item], m)
  end
  for _, t in ipairs(inp.producers or {}) do add(t, "p") end
  for _, t in ipairs(inp.consumers or {}) do add(t, "c") end
  table.sort(items)
  local queue, ceiling = {}, 0
  for _, it in ipairs(items) do
    table.sort(by[it], term_lt)
    queue[#queue + 1] = { t = "item", item = it, list = by[it] }
    local sp, sc = 0, 0
    for _, m in ipairs(by[it]) do if m.kind == "p" then sp = sp + m.rate else sc = sc + m.rate end end
    ceiling = ceiling + math.min(sp, sc)
  end
  return { opts = opts, queue = queue, qi = 1, cands = {}, n_comp = 0, rejects = {}, phase = "queue", demand = demand, supply = supply,
    ceiling = ceiling, n_items = #items }
end

local function reject(job, why)
  job.rejects[#job.rejects + 1] = why
end

--- Avance de `units` unités (nil = tout). dist : crochet facultatif (voir Rg.components). Rend vrai quand le travail est fini.
function Rg.step(job, units, dist)
  local left = units or math.huge
  while left > 0 and job.phase ~= "done" do
    if job.phase == "queue" then
      local task = job.queue[job.qi]
      if not task then
        job.phase = "select"
      else
        left = left - 1
        if task.t == "item" then
          job.qi = job.qi + 1
          for _, comp in ipairs(Rg.components(task.list, dist)) do
            local parts = {}
            split(comp, parts)
            for _, part in ipairs(parts) do
              job.n_comp = job.n_comp + 1
              job.queue[#job.queue + 1] = { t = "bus", item = task.item, comp = part }
            end
          end
          task.list = nil
        else
          -- tâche « bus » : une passe par unité (l'état est gardé dans la tâche)
          task.st = task.st or Rg.bus_start(task.comp, job.opts)
          if Rg.bus_step(task.st, job.opts) then
            job.qi = job.qi + 1
            local bus, why = task.st.bus, task.st.why
            if bus then
              job.cands[#job.cands + 1] = bus
              -- les terminaux laissés par ce bus forment, s'ils portent producteur et consommateur, une composante résiduelle (un autre bus)
              local taken = {}
              for _, t in ipairs(bus.taps) do taken[t.kind .. t.key] = true end
              local rest = {}
              for _, t in ipairs(task.comp) do if not taken[t.kind .. t.key] then rest[#rest + 1] = t end end
              local np, nc = count_kinds(rest)
              if np > 0 and nc > 0 and (task.depth or 1) < Rg.DEPTH_MAX then
                job.queue[#job.queue + 1] = { t = "bus", item = task.item, comp = rest, depth = (task.depth or 1) + 1 }
              end
            else
              reject(job, task.item .. " : " .. tostring(why))
            end
            task.comp, task.st = nil, nil
          end
        end
      end
    else -- select
      left = left - 1
      job.result = Rg.finish(job)
      job.phase = "done"
    end
  end
  return job.phase == "done"
end

--- Choix final et statistiques.
function Rg.finish(job)
  local o = job.opts
  local run, which = choose(job.cands, o.k, o.budget, o)
  -- ordre de pose : fichier par fichier (la valeur nette par coût de la voie de base d'abord ; la voie qui PARTAGE le tronc après celle qui le
  -- pose), puis voie par voie
  local picks = copy(run.picks)
  local dens = {}
  for _, p in ipairs(picks) do
    if p.lane == 1 then dens[p.belt] = p.mnet / math.max(1, p.c.pay_s) end
  end
  table.sort(picks, function(a, b)
    if a.belt ~= b.belt then
      if dens[a.belt] ~= dens[b.belt] then return dens[a.belt] > dens[b.belt] end
      return a.belt < b.belt
    end
    return a.lane < b.lane
  end)
  local buses, links, belt_id, belt_list = {}, {}, {}, {}
  local served, gain, tiles, plaques, crossed = 0, 0, 0, 0, 0
  for i, p in ipairs(picks) do
    local c = p.c
    if not belt_id[p.belt] then belt_list[#belt_list + 1] = p.belt; belt_id[p.belt] = #belt_list end
    local b = { id = i, item = c.item, belt = belt_id[p.belt], lane = p.lane, axis = c.axis, sign = c.sign, line = c.line, lo = c.lo, hi = c.hi,
      tiles = c.tiles, shared_tiles = math.ceil(p.ov * Rg.DETOUR), plaques = p.mplaq, served = c.served, gain = c.gain,
      payback_min = c.payback_min, net = p.mnet, n_prod = c.n_prod, n_cons = c.n_cons, taps = c.taps, crossings = p.nx }
    buses[i] = b
    served, gain, plaques = served + c.served, gain + c.gain, plaques + p.mplaq
    crossed = crossed + p.nx
    tiles = tiles + c.tiles - b.shared_tiles
    for j, t in ipairs(c.taps) do
      links[#links + 1] = { bus = i, belt = b.belt, item = c.item, key = t.key, kind = t.kind, x = t.x, y = t.y, order = j, contrib = t.contrib }
    end
  end
  local belts = {}
  for bi, raw in ipairs(belt_list) do
    local b = run.belts[raw]
    local lanes = {}
    for _, bus in ipairs(buses) do if bus.belt == bi then lanes[#lanes + 1] = bus.id end end
    belts[bi] ={ id = bi, axis = b.axis, sign = b.sign, line = b.line, lo = b.lo, hi = b.hi, lanes = lanes }
  end
  return { buses = buses, belts = belts, links = links, which = which,
    stats = { demand = job.demand, supply = job.supply, served = served, share = job.demand > 0 and served / job.demand or 0,
      ceiling = job.ceiling, ceiling_share = job.ceiling > 0 and served / job.ceiling or 0, gain_s_min = gain, pnj_equiv = gain / 60,
      trips_avoided_min = served / Rg.FILL_BATCH + served / Rg.COLLECT_BATCH, plaques = plaques, tiles = tiles, belts = #belts, buses = #buses,
      components = job.n_comp, candidates = #job.cands, crossings = crossed, rejects = job.rejects } }
end

function Rg.result(job) return job.result end

--- Nombre de files (« k bus ») permises : une de plus toutes les Rg.EPOCH_STEP époques (au moins 1 dès qu'il y a du tapis), bornée par le stock
--- de tapis du QG (Rg.BELT_TILES tuiles par file). epoch : 0 à 14 (X0) ; belt_stock : tapis au coffre. Proposition NON MESURÉE.
function Rg.k_for(epoch, belt_stock)
  local cap = 1 + math.floor(math.max(0, epoch or 0) / Rg.EPOCH_STEP)
  local by_stock = math.floor(math.max(0, belt_stock or 0) / Rg.BELT_TILES)
  return math.max(0, math.min(cap, by_stock))
end

--- Tout d'un coup (bancs hors jeu, petites instances).
function Rg.plan(inp, dist)
  local job = Rg.begin(inp)
  Rg.step(job, nil, dist)
  return job.result
end

-- Pour le banc hors jeu seulement (comparaison à l'optimum, mutants) : jamais appelé par le mod.
Rg._internals = { evaluate = evaluate, axis_of = axis_of, along = along, choose = choose, select_run = select_run, crossings = crossings, segments = segments }

return Rg
