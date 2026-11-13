--[[
  TRONCONS (lot BUS-LONG, 9/11) : le tracé d'une LIAISON LONGUE (tapis de 100 à 600 tuiles), découpé en tronçons planifiés sur plusieurs pensées. Règle PURE :
  aucune API du jeu, aucun nom d'objet ; lue hors jeu (tests/troncons_test.lua) et en jeu (script/team/rapatriement.lua).

  Mesuré (partie à 600 %, scarlet, 120 min) : 44 demandes de lignes, 3 finies, 12 refus « trop long » (A* de 60 302 noeuds), 13 « aucun chemin » ; le fer voyage à la main.
  Un A* fin d'un seul tenant explore l'aire entre les deux bouts, et ces lignes n'avaient aucun souterrain : une rangée de tapis en travers les arrêtait.

  RÈGLE
  1. PLAN GROSSIER : la boîte est lue à l'échelle de cases de Tc.CELL tuiles (Tc.SAMPLE_CELLS cases par appel, 16 points par case ; seul le lourd compte : eau,
     bâtiments, réserves ; un tapis isolé ne bouche pas une case). A* de cases (Tc.COARSE_NODES par appel) depuis la pointe du tracé : le couloir.
  2. TRONÇONS : un point de passage toutes les Tc.LEG_CELLS cases (une tuile libre dont la suivante, vers le tronçon d'après, est libre) ; chaque tronçon est un
     Tv.route par tranches (Tc.SLICE états par appel, souterrains compris), dans sa petite boîte, avec un budget PROPRE (Tc.LEG_BUDGET) : un tronçon ne prend rien aux autres.
     Raccord : la dernière tuile d'un tronçon est tournée vers la première du suivant (sens d'arrivée = ce sens) : la preuve Tv.verify de la ligne entière tient.
  3. RÉPARATION : un tronçon raté (bouché, trop d'états, pureté refusée) interdit la case de son point d'arrivée et refait le plan depuis la pointe (Tc.MAX_REPAIRS
     réparations au plus). Trois échecs de suite à la même pointe : le dernier tronçon est défait (retour d'un cran). Interdictions épuisées : levées une fois, budget triplé.
  4. ÉTAT : st (nombres, chaînes, tables ; AUCUNE fonction) vit dans le projet, donc dans global ; ctx (fonctions du monde) est refait à chaque appel. Le monde peut changer entre deux
     appels : le coût est RELU à chaque tranche, Tv.search abandonne une tuile devenue prise, et la VALIDATION finale relit chaque tronçon (tuiles, pureté) : une tuile prise défait ce tronçon et ceux qui suivent.
  5. PREUVE (Tv.verify sur la ligne entière) : tuiles distinctes, chaque maillon mène au suivant, paires justes, aucune pièce souterraine de même axe dessous.

  Déterminisme : parcours en ordre fixe, tas à départage (f, h, clé), aucun `pairs` dans une décision, aucune trigonométrie, aucun temps mesuré.
  Coordonnées : tuiles entières ; direction : code du jeu (0 N, 2 E, 4 S, 6 O).
]]

local Tv = require("shared.team.traversee")

local Tc = {}

Tc.CELL = 8                -- tuiles par case du plan grossier
Tc.LEG_CELLS = 5           -- cases par tronçon (40 tuiles : un A* local de quelques centaines d'états en terrain libre)
Tc.SHORT = 48              -- tuiles (Manhattan) : en deçà, un seul tronçon, sans plan grossier
Tc.LEG_BUDGET = 4000       -- états développés au plus par tronçon (PROPRE à chaque tronçon ; multiplié à chaque échec à la même pointe)
Tc.LEG_MARGIN = 20         -- tuiles autour des deux bouts d'un tronçon (la boîte de sa recherche)
Tc.SLICE = 180             -- états développés au plus par appel (mesuré par debug.sethook : 1 500 instructions par état, souterrains compris ; le coût réel du monde est plus cher que la doublure)
Tc.SAMPLE_CELLS = 48       -- cases lues au plus par appel (une case = 16 points ; au plus 3 chunks neufs par appel)
Tc.COARSE_NODES = 500      -- cases développées au plus par appel (780 instructions par case mesurées : 390 000 par appel au pire)
Tc.MIN_FREE = 2            -- points libres (sur 16) sous lesquels une case est bouchée
Tc.ORE_COST = 3            -- surcoût d'une case de gisement au plan grossier (le couloir évite les champs sans en payer le prix à l'A* fin)
Tc.MAX_REPAIRS = 24        -- réparations SANS tronçon réussi au plus (bandes de 5 cases : au plus environ 480 tuiles de décalage de chaque côté ; au-delà, la barrière est réelle)
Tc.MAX_REPAIRS_TOTAL = 120 -- réparations sur toute la ligne (un labyrinthe de murs successifs reste borné)
Tc.BAN_HALF = 2            -- cases interdites de chaque côté du point de passage (une case décalait le couloir d'une seule case par échec)
Tc.SPOT_R = 6              -- tuiles : recherche d'un point de passage libre autour du centre de la case
Tc.TIP_FAILS = 8           -- échecs de suite à la même pointe avant de défaire le dernier tronçon
Tc.POCKET = 300            -- tuiles : un bout entouré de moins de tuiles libres que cela (souterrains compris) est dans une POCHE : refus immédiat, avec sa cause

local floor, abs = math.floor, math.abs
local D4, CODE = Tv.D4, Tv.CODE

local function ck(cx, cy) return (cx + 65536) * 131072 + (cy + 65536) end
local tk = Tv.tkey

-- Tas binaire à départage (f, h, clé)
local function less(a, b) return a.f < b.f or (a.f == b.f and (a.h < b.h or (a.h == b.h and a.k < b.k))) end
local function push(h, n)
  h[#h + 1] = n
  local i = #h
  while i > 1 do
    local p = floor(i / 2)
    if not less(h[i], h[p]) then break end
    h[p], h[i] = h[i], h[p]
    i = p
  end
end
local function pop(h)
  local top, last = h[1], h[#h]
  h[#h] = nil
  local n = #h
  if n > 0 then
    h[1] = last
    local i = 1
    while true do
      local l, r, m = 2 * i, 2 * i + 1, i
      if l <= n and less(h[l], h[m]) then m = l end
      if r <= n and less(h[r], h[m]) then m = r end
      if m == i then break end
      h[m], h[i] = h[i], h[m]
      i = m
    end
  end
  return top
end

local function cell_of(x, y) return floor(x / Tc.CELL), floor(y / Tc.CELL) end
local function dir_idx(code) return code / 2 + 1 end

--- Sens (index 1 à 4) de l'axe dominant de (ax, ay) vers (bx, by) (départage : l'axe des x).
local function dominant(ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  if abs(dx) >= abs(dy) then return dx >= 0 and 2 or 4 end
  return dy >= 0 and 3 or 1
end

--- Début d'un tracé. o = { s = {x, y}, t = {x, y}, t_dir (code), sd (code du sens d'arrivée en s, facultatif), box = {x0, y0, x1, y1}, lim (longueur physique au plus : ellipse),
--- grid (cases déjà lues d'un essai précédent sur la même boîte, facultatif) }. L'état ne contient que des nombres, des chaînes et des tables.
function Tc.new(o)
  local b = o.box
  local st = { s = { x = o.s.x, y = o.s.y }, t = { x = o.t.x, y = o.t.y }, t_dir = o.t_dir, sd = o.sd, box = { x0 = b.x0, y0 = b.y0, x1 = b.x1, y1 = b.y1 }, lim = o.lim,
    grid = o.grid or { cost = {}, done = false }, ban = {}, tiles = {}, taken = {}, ugs = {}, legs = {}, repairs = 0, tip_fails = 0, total = 0, calls = 0, relaxed = false, last_why = "aucun chemin" }
  local x0c, y0c = cell_of(b.x0, b.y0)
  local x1c, y1c = cell_of(b.x1, b.y1)
  st.c0, st.c1 = { x = x0c, y = y0c }, { x = x1c, y = y1c }
  st.cur = { x = x0c, y = y0c }
  st.short = abs(o.s.x - o.t.x) + abs(o.s.y - o.t.y) <= Tc.SHORT
  st.phase = "pocket"
  return st
end

-- Remplissage borné autour de (x0, y0) (4 voisins et sorties de paires souterraines, comme Tv.unreachable, dans la boîte). Rend le nombre de tuiles atteintes et vrai si la file s'est vidée avant Tc.POCKET.
local function flood(st, ctx, x0, y0)
  local b = st.box
  local seen, qx, qy, h, n = { [tk(x0, y0)] = true }, { x0 }, { y0 }, 1, 1
  local function add(x, y)
    if x < b.x0 or x > b.x1 or y < b.y0 or y > b.y1 then return end
    local k = tk(x, y)
    if not seen[k] and ctx.cost(x, y) then
      seen[k] = true
      qx[#qx + 1], qy[#qy + 1] = x, y
      n = n + 1
    end
  end
  while h <= #qx and n < Tc.POCKET do
    local x, y = qx[h], qy[h]
    h = h + 1
    for i = 1, 4 do
      local v = D4[i]
      add(x + v[1], y + v[2])
      if ctx.maxd then
        for kk = 2, ctx.maxd do add(x + kk * v[1], y + kk * v[2]) end
      end
    end
  end
  return n, h > #qx
end

--- Ligne courte ou plan grossier ? (après le contrôle des poches)
local function after_pocket(st)
  if st.short then
    st.phase = "leg" -- ligne courte : un seul tronçon, jusqu'à la cible
    st.way, st.wi = {}, 1
  elseif st.grid.done then
    st.phase = "coarse"
  else
    st.phase = "sample"
  end
end

-- Une case est-elle dans l'ellipse de la longueur permise ?
local function in_ellipse(st, cx, cy)
  if not st.lim then return true end
  local x, y = cx * Tc.CELL + Tc.CELL / 2, cy * Tc.CELL + Tc.CELL / 2
  return abs(x - st.s.x) + abs(y - st.s.y) + abs(x - st.t.x) + abs(y - st.t.y) <= st.lim + 2 * Tc.CELL
end

-- Lecture de Tc.SAMPLE_CELLS cases au plus. Rend vrai quand la boîte est entièrement lue.
local function sample(st, ctx)
  local g = st.grid
  local c, n = st.cur, 0
  local C, stepv = Tc.CELL, Tc.CELL / 4
  while c.y <= st.c1.y do
    while c.x <= st.c1.x do
      if n >= Tc.SAMPLE_CELLS then return false end
      local cx, cy = c.x, c.y
      c.x = cx + 1
      if in_ellipse(st, cx, cy) then
        n = n + 1
        local free, ore = 0, 0
        for iy = 0, 3 do
          for ix = 0, 3 do
            local x, y = cx * C + floor(stepv * ix + 1), cy * C + floor(stepv * iy + 1)
            if not ctx.solid(x, y) then
              free = free + 1
              if ctx.ore and ctx.ore(x, y) then ore = ore + 1 end
            end
          end
        end
        if free >= Tc.MIN_FREE then
          local cost = 1 + (16 - free) / 8
          if ore >= 4 then cost = cost + Tc.ORE_COST end
          g.cost[ck(cx, cy)] = cost
        end
      end
    end
    c.x = st.c0.x
    c.y = c.y + 1
  end
  g.done = true
  return true
end

-- La pointe du tracé : prochaine tuile à poser et sens d'arrivée (code). Rend x, y, sens.
local function tip(st)
  local n = #st.tiles
  if n == 0 then return st.s.x, st.s.y, st.sd end
  local l = st.tiles[n]
  local v = D4[dir_idx(l.dir)]
  return l.x + v[1], l.y + v[2], l.dir
end

-- A* de cases depuis la pointe, Tc.COARSE_NODES au plus par appel. Rend "more", "found" (st.way) ou "none".
local function coarse(st)
  local g = st.grid
  local tx, ty = tip(st)
  local gcx, gcy = cell_of(st.t.x, st.t.y)
  local sx, sy = cell_of(tx, ty)
  if not st.co then
    local h0 = abs(sx - gcx) + abs(sy - gcy)
    st.co = { open = {}, g = { [ck(sx, sy)] = 0 }, prev = {}, closed = {}, n = 0 }
    push(st.co.open, { x = sx, y = sy, f = h0, h = h0, k = ck(sx, sy) })
  end
  local co = st.co
  local left = Tc.COARSE_NODES
  while #co.open > 0 do
    if left <= 0 then return "more" end
    local cur = pop(co.open)
    if not co.closed[cur.k] then
      co.closed[cur.k] = true
      left = left - 1
      co.n = co.n + 1
      if cur.x == gcx and cur.y == gcy then
        local rev, kk, x, y = {}, cur.k, cur.x, cur.y
        while true do
          rev[#rev + 1] = { x, y }
          local p = co.prev[kk]
          if not p then break end
          x, y = p[1], p[2]
          kk = ck(x, y)
        end
        local way = {}
        for i = #rev, 1, -1 do way[#way + 1] = rev[i] end
        st.path, st.co = way, nil
        return "found"
      end
      for i = 1, 4 do
        local v = D4[i]
        local nx, ny = cur.x + v[1], cur.y + v[2]
        local nk = ck(nx, ny)
        if nx >= st.c0.x and nx <= st.c1.x and ny >= st.c0.y and ny <= st.c1.y and not co.closed[nk] then
          local cc = g.cost[nk]
          if (nx == gcx and ny == gcy) and not cc then cc = 1 end -- la case de la cible est toujours permise
          if cc and not st.ban[nk] then
            local ng = co.g[cur.k] + cc
            if co.g[nk] == nil or ng < co.g[nk] then
              co.g[nk] = ng
              co.prev[nk] = { cur.x, cur.y }
              local h = abs(nx - gcx) + abs(ny - gcy)
              push(co.open, { x = nx, y = ny, f = ng + h, h = h, k = nk })
            end
          end
        end
      end
    end
  end
  st.co = nil
  return "none"
end

-- Waypoints du couloir : une case toutes les Tc.LEG_CELLS, jamais la dernière (la cible est le dernier tronçon). way = { {cx, cy} }.
local function waypoints(st)
  local way = {}
  local p = st.path
  local i = Tc.LEG_CELLS
  while i < #p - 1 do
    way[#way + 1] = p[i + 1]
    i = i + Tc.LEG_CELLS
  end
  st.way, st.wi, st.path = way, 1, nil
end

-- Point de passage de la case w : tuile libre près du centre, dont la tuile suivante (sens d vers le tronçon d'après) est libre. Rend x, y, sens (code), ou nil.
local function pick_wp(st, cost, w, nx, ny)
  local C = Tc.CELL
  local px, py = w[1] * C + C / 2, w[2] * C + C / 2
  local di = dominant(px, py, nx, ny)
  local v = D4[di]
  for r = 0, Tc.SPOT_R do
    for dy = -r, r do
      local rem = r - abs(dy)
      for dx = (rem == 0) and 0 or -rem, rem, (rem == 0) and 1 or 2 * rem do
        local x, y = px + dx, py + dy
        if cost(x, y) and cost(x + v[1], y + v[2]) then return x, y, CODE[di] end
      end
    end
  end
  return nil
end

-- Le coût vu par le tracé : le monde (relu à chaque appel) moins nos propres tuiles posées.
local function cost_of(st, ctx)
  local taken = st.taken
  return function(x, y)
    if taken[tk(x, y)] then return nil end
    return ctx.cost(x, y)
  end
end

-- Bande de cases interdites : la case du point d'arrivée et ses deux voisines perpendiculaires au tronçon (un mur fin et long se contourne en décalant le couloir de 3 cases par
-- échec ; une seule case le décalerait d'une case et useraient les réparations).
local function ban_stripe(st, wp, sx, sy)
  if not wp.cx then return end
  st.ban[ck(wp.cx, wp.cy)] = true
  local ax, ay = 0, 1
  if abs(wp.x - sx) < abs(wp.y - sy) then ax, ay = 1, 0 end
  for i = 1, Tc.BAN_HALF do
    st.ban[ck(wp.cx + i * ax, wp.cy + i * ay)] = true
    st.ban[ck(wp.cx - i * ax, wp.cy - i * ay)] = true
  end
end

-- Case interdite, ou retour d'un cran après Tc.TIP_FAILS échecs à la même pointe. Rend "more" ou "fail", raison.
local function drop_last_leg(st)
  local n = #st.legs
  if n == 0 then return false end
  local keep = n > 1 and st.legs[n - 1].n or 0
  for i = #st.tiles, keep + 1, -1 do
    local t = st.tiles[i]
    local k = tk(t.x, t.y)
    st.taken[k], st.ugs[k] = nil, nil
    st.tiles[i] = nil
  end
  local leg = st.legs[n]
  st.legs[n] = nil
  if leg.cx then st.ban[ck(leg.cx, leg.cy)] = true end
  return true
end

local function repair(st, why, goal)
  st.repairs = st.repairs + 1
  st.last_why = tostring(why)
  st.rs, st.co, st.path, st.wp, st.way = nil, nil, nil, nil, nil
  st.repairs_total = (st.repairs_total or 0) + 1
  if st.repairs > Tc.MAX_REPAIRS or st.repairs_total > Tc.MAX_REPAIRS_TOTAL then
    return "fail", string.format("%d reparations epuisees (dernier echec : %s)", st.repairs_total, st.last_why), false
  end
  st.tip_fails = st.tip_fails + 1
  if st.tip_fails >= Tc.TIP_FAILS then
    if #st.legs == 0 then
      if goal then return "fail", st.last_why, false end -- le tronçon vers la cible, depuis le départ : aucun autre essai ne change la donne
      st.tip_fails = 0
    else
      drop_last_leg(st)
      st.tip_fails = 0
    end
  end
  st.phase = st.grid.done and "coarse" or "sample" -- (une ligne courte n'a pas de plan grossier avant son premier échec)
  return "more"
end

-- Le tronçon courant : point de passage choisi au début, puis Tv.route par tranches.
local function run_leg(st, ctx)
  local cost = cost_of(st, ctx)
  local sx, sy, sd = tip(st)
  local way = st.way
  if not st.wp then
    local w = way and way[st.wi]
    if w then
      local nw = way[st.wi + 1]
      local nx, ny = st.t.x, st.t.y
      if nw then nx, ny = nw[1] * Tc.CELL + Tc.CELL / 2, nw[2] * Tc.CELL + Tc.CELL / 2 end
      local x, y, d = pick_wp(st, cost, w, nx, ny)
      if not x then
        if st.ban[ck(w[1], w[2])] == nil then st.ban[ck(w[1], w[2])] = true end
        return repair(st, "point de passage bouche")
      end
      st.wp = { x = x, y = y, dir = d, cx = w[1], cy = w[2] }
    else
      st.wp = { x = st.t.x, y = st.t.y, dir = st.t_dir, goal = true }
    end
  end
  local wp = st.wp
  -- Prochaine tuile prise par un tronçon d'avant (un point de passage sur nos propres pas) : tronçon impossible
  if st.taken[tk(sx, sy)] then
    if wp.cx then st.ban[ck(wp.cx, wp.cy)] = true end
    return repair(st, "depart sur nos propres tuiles")
  end
  local M = Tc.LEG_MARGIN
  local b = st.box
  local box = { x0 = math.max(b.x0, math.min(sx, wp.x) - M), y0 = math.max(b.y0, math.min(sy, wp.y) - M),
    x1 = math.min(b.x1, math.max(sx, wp.x) + M), y1 = math.min(b.y1, math.max(sy, wp.y) + M) }
  local budget = Tc.LEG_BUDGET * (1 + math.min(st.long_fails or 0, 3)) * (st.relaxed and 3 or 1) -- (un tronçon qui manque d'états, pas un tronçon sans issue)
  local ugs = st.ugs
  local rctx = { maxd = ctx.maxd, ore = ctx.ore, sd = sd, weight = Tv.GAME_WEIGHT, max = budget, slice = ctx.slice or Tc.SLICE, resume = st.rs, no_detour = true }
  if ctx.maxd then
    local ax = ctx.ug_axis
    rctx.ug_axis = function(x, y)
      local a = ugs[tk(x, y)]
      if a then return a end
      return ax and ax(x, y) or nil
    end
  end
  local tiles, info, state = Tv.route({ x = sx, y = sy }, { x = wp.x, y = wp.y }, wp.dir, box, cost, rctx)
  if not tiles and info == "pending" then
    st.rs = state
    return "more"
  end
  st.rs = nil
  if not tiles then
    -- pointe bouchée par le monde (« depart ») : le fautif est le dernier tronçon posé, pas la cible. Il est défait tout de suite, sans interdire la bande de la cible
    -- (avant : Tc.TIP_FAILS réparations et autant de bandes interdites à tort avant de le défaire)
    if info == "depart" and #st.legs > 0 then
      drop_last_leg(st)
      st.tip_fails = 0
      return repair(st, info, false)
    end
    ban_stripe(st, wp, sx, sy)
    if info == "trop long" then st.long_fails = (st.long_fails or 0) + 1 end
    return repair(st, info, wp.goal)
  end
  -- preuve de pureté du tronçon (causes a, b, c, d), lecture fraîche du monde ; la dernière tuile verse sur la première du tronçon suivant
  local v = D4[dir_idx(wp.dir)]
  if ctx.check_leg then
    local ok, why = ctx.check_leg(tiles, wp.goal and nil or { x = wp.x + v[1], y = wp.y + v[2] })
    if not ok then
      ban_stripe(st, wp, sx, sy)
      return repair(st, why, wp.goal)
    end
  end
  st.total = st.total + (info.expanded or 0)
  for _, t in ipairs(tiles) do
    st.tiles[#st.tiles + 1] = t
    local k = tk(t.x, t.y)
    st.taken[k] = true
    if t.ug then st.ugs[k] = (t.dir == 0 or t.dir == 4) and 1 or 2 end
  end
  st.legs[#st.legs + 1] = { n = #st.tiles, cx = wp.cx, cy = wp.cy, goal = wp.goal }
  st.tip_fails, st.long_fails, st.wp, st.repairs = 0, 0, nil, 0 -- un tronçon réussi : les réparations repartent de zéro (MAX_REPAIRS_TOTAL borne la ligne entière)
  if wp.goal then
    st.phase, st.vi = "validate", 1
    return "more"
  end
  st.wi = st.wi + 1 -- (plus de case : le tronçon suivant vise la cible)
  return "more"
end

-- Validation finale, un tronçon par appel : tuiles encore libres, pureté. Un tronçon cassé est défait avec tous ceux qui suivent, et le plan repart.
local function validate(st, ctx)
  local i = st.vi
  local leg = st.legs[i]
  if not leg then
    local bad = Tv.verify(st.tiles, st.s, st.t, st.t_dir, ctx.maxd or 0, nil, { ug_axis = ctx.ug_axis })
    if #bad > 0 then return "fail", "geometrie fausse : " .. bad[1], false end
    st.done = true
    return "done"
  end
  local from = (i > 1 and st.legs[i - 1].n or 0) + 1
  local broke
  local list = {}
  for j = from, leg.n do
    local t = st.tiles[j]
    list[#list + 1] = t
    if not ctx.cost(t.x, t.y) then broke = true break end
  end
  if not broke and ctx.check_leg then
    local nxt = st.tiles[leg.n + 1]
    local ok = ctx.check_leg(list, nxt and { x = nxt.x, y = nxt.y } or nil)
    if not ok then broke = true end
  end
  if not broke then
    st.vi = i + 1
    return "more"
  end
  while #st.legs >= i do drop_last_leg(st) end
  st.tip_fails = 0
  return repair(st, "monde change sous un troncon fini")
end

--- Un appel : au plus une tranche de travail. ctx = { cost = f(x, y) -> nil | coût (tuile où poser une pièce, lue au monde à chaque appel), solid = f(x, y) -> bool (case bouchée : eau, bâtiment,
--- réserve), ore = f(x, y) -> bool (facultatif), maxd (portée des souterrains, nil : aucun), ug_axis = f(x, y) -> nil | 1 | 2 | true (souterrain à cette tuile), check_leg = f(tiles, nxt) -> ok, raison (facultatif),
--- slice (facultatif) }. Rend "more", "done" (st.tiles : la ligne), ou "fail", raison, barriere (vrai : aucun couloir n'existe, les autres bouts échoueraient de même).
function Tc.step(st, ctx)
  st.calls = st.calls + 1
  if st.phase == "pocket" then
    -- (une cible ou un départ pris : Tv.route le dira au premier tronçon, avec sa cause)
    if ctx.cost(st.t.x, st.t.y) then
      local n, shut = flood(st, ctx, st.t.x, st.t.y)
      if shut then return "fail", string.format("arrivee enfermee (poche de %d tuiles libres autour du tampon)", n), false end
    end
    if ctx.cost(st.s.x, st.s.y) then
      local n, shut = flood(st, ctx, st.s.x, st.s.y)
      if shut then return "fail", string.format("depart enferme (poche de %d tuiles libres autour de la sortie)", n), false end
    end
    after_pocket(st)
    return "more"
  elseif st.phase == "sample" then
    if sample(st, ctx) then st.phase = "coarse" end
    return "more"
  elseif st.phase == "coarse" then
    local r = coarse(st)
    if r == "more" then return "more" end
    if r == "none" then
      if not st.relaxed and next(st.ban) ~= nil then -- (next : seul le fait que la table soit vide compte)
        st.relaxed, st.ban = true, {}
        return "more"
      end
      return "fail", "aucun chemin (aucun couloir dans la boite)", true
    end
    waypoints(st)
    st.phase = "leg"
    return "more"
  elseif st.phase == "leg" then
    return run_leg(st, ctx)
  elseif st.phase == "validate" then
    return validate(st, ctx)
  end
  return "fail", "etat inconnu", false
end

return Tc
