--[[
  Lot RESEAU-GRAPHE : BUS d'une composante (terminaux, composantes connexes, évaluation du tronc, élagage, croissance, croisements). Suite de
  shared/team/reseau_graphe.lua (découpé en deux fichiers pour tenir sous 500 lignes) : ce fichier ne s'utilise que par lui, via
  `require("shared.team.reseau_bus")(Rg)`, qui pose ses fonctions sur la table Rg. Règle PURE : aucune API du jeu, aucun nom d'objet.
  Conception : docs/conception/RESEAU_GRAPHE.md §2 et §3.
]]

return function(Rg)
local U = Rg._u
local Li = U.Li
local manhattan, copy, without, term_lt = U.manhattan, U.copy, U.without, U.term_lt
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
    arms = math.max(1, math.ceil(rate / Rg.ARM_RATE - Rg.EPS)), extra = math.max(0, t.extra or 0),
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
  local perps, arms, sx, sy, extra = {}, 0, 0, 0, 0
  local per = {}
  for i = 1, #S do
    local t = S[i]
    local c = t[ax.axis]
    if c < lo then lo = c end
    if c > hi then hi = c end
    perps[i] = t[ax.perp]
    arms = arms + t.arms
    extra = extra + (t.extra or 0)
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
  local plaques = tiles * price.belt + arms * price.arm + #S * price.pole + extra
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

U.split, U.make_terminal, U.count_kinds, U.crossings = split, make_terminal, count_kinds, crossings

-- Pour le banc hors jeu seulement (comparaison à l'optimum, mutants) : jamais appelé par le mod.
Rg._internals = { evaluate = evaluate, axis_of = axis_of, along = along, crossings = crossings, segments = segments }
end
