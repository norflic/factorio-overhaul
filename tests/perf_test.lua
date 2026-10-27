--[[
  Lot PERF (27/10) : ÉQUIVALENCE des accélérations du coût script (K10) avec les versions de main 0.6.1 (2d6cb75).
  Chaque fonction accélérée doit rendre EXACTEMENT le même résultat que la version d'origine (aucune décision changée,
  K11) sur des cartes tirées au sort à la TAILLE DU JEU (trajets de 100 à 400 tuiles, jusqu'à 48 menaces, 32 morts,
  256 cases mobiles), avec et sans bruit de tournée :
    - R.astar (tas en tableaux parallèles) : mêmes cases, même nombre de développements ;
    - R.danger_pt (coins déroulés) : même danger, même clé, y compris sur les bords de cases ;
    - R.plan (A* + réduction + découpage + profil) : mêmes points, longueur, profil, blocage, sortie ;
    - D.field (cases mobiles par pairs, sans tri) : mêmes cases, mêmes valeurs, même nombre ;
    - D.exact_prep / D.exact_at : même danger exact que D.danger_exact en chaque point du rectangle ;
    - script/ai3/comportement.lua M.plan (moteur simulé minimal) : même résultat complet qu'avec D.danger_exact.
  Référence : tests/fixtures/perf/route_0_6_1.lua (copie exacte de shared/ai3/route.lua à 2d6cb75) ; D.field et
  D.danger_exact d'origine recopiés ci-dessous. Les temps imprimés (os.clock) sont indicatifs (machine partagée).
  Lancement : lua5.2 tests/perf_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local D = require("shared.ai3.danger")
local R = require("shared.ai3.route")
local Tr = require("shared.faction.traits")

-- Référence : route.lua de 2d6cb75, chargé comme un module séparé (il partage D et Tr, inchangés pour lui).
local Rref = assert(loadfile("tests/fixtures/perf/route_0_6_1.lua"))()

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local MIN = 3600

-- D.field d'origine (2d6cb75) : cases mobiles par clés TRIÉES.
local function mobile_now(c, tick) return math.floor(c.m * D.dec10(tick - c.t) / 1000) end
local function death_w(d, tick)
  local age = tick - d.t
  if age < D.DEATH_FULL then return D.DEATH_W end
  return math.floor(D.DEATH_W * D.dec10(age - D.DEATH_FULL) / 1000)
end
local function field_ref(map, tick, box)
  local out, n = {}, 0
  local floor = math.floor
  local C, OFF = D.CELL, D.OFF
  local bx0, by0, bx1, by1 = -1e9, -1e9, 1e9, 1e9
  if box then bx0, by0, bx1, by1 = box[1], box[2], box[3], box[4] end
  local function disc(x, y, r, w)
    local c0x, c1x = floor((x - r) / C), floor((x + r) / C)
    local c0y, c1y = floor((y - r) / C), floor((y + r) / C)
    if c0x < bx0 then c0x = bx0 end
    if c1x > bx1 then c1x = bx1 end
    if c0y < by0 then c0y = by0 end
    if c1y > by1 then c1y = by1 end
    local r2 = r * r
    for cy = c0y, c1y do
      local y0 = cy * C
      local y1 = y0 + C
      local dy = (y < y0) and (y0 - y) or ((y > y1) and (y - y1) or 0)
      local dy2 = dy * dy
      if dy2 <= r2 then
        for cx = c0x, c1x do
          local x0 = cx * C
          local x1 = x0 + C
          local dx = (x < x0) and (x0 - x) or ((x > x1) and (x - x1) or 0)
          if dx * dx + dy2 <= r2 then
            local k = (cx + OFF) * 65536 + (cy + OFF)
            local v = out[k]
            if not v then n = n + 1 v = 0 end
            out[k] = v + w
          end
        end
      end
    end
  end
  for _, t in ipairs(map.threats) do
    local K = D.KINDS[t.k] or D.KINDS.unit
    local w = floor(K.w * (K.fast and D.dec10(tick - t.t) or D.dec2(tick - t.t)) / 1000)
    if w > 0 then disc(t.x, t.y, t.r + D.MARGIN, w) end
  end
  for _, d in ipairs(map.deaths) do
    local w = d.home and 0 or death_w(d, tick)
    if w > 0 then disc(d.x, d.y, D.DEATH_R, w) end
  end
  local keys = {}
  for k in pairs(map.cells) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local cx, cy = D.unkey(k)
    local w = mobile_now(map.cells[k], tick)
    if w > 0 and cx >= bx0 and cy >= by0 and cx <= bx1 and cy <= by1 then
      local v = out[k]
      if not v then n = n + 1 v = 0 end
      out[k] = v + w
    end
  end
  return out, n
end

local function same_field(a, na, b, nb)
  if na ~= nb then return false end
  for k, v in pairs(a) do if b[k] ~= v then return false end end
  for k, v in pairs(b) do if a[k] ~= v then return false end end
  return true
end

-- Carte tirée au sort, taille du jeu (menaces groupées comme des nids et leurs vers, unités vues, morts, attaques).
local function random_map(rnd, tick)
  local map = D.new()
  local kinds = { "worm", "spawner", "turret", "pack" }
  for c = 1, 4 + rnd(10) do
    local cx, cy = rnd(900) - 450, rnd(900) - 450
    for j = 1, 1 + rnd(5) do
      D.mark_seen(map, cx + rnd(48) - 24 + rnd(256) / 256, cy + rnd(48) - 24 + rnd(256) / 256, kinds[rnd(4)],
        (rnd(3) == 1) and (14 + rnd(30)) or nil, tick - rnd(60) * MIN)
    end
  end
  for j = 1, rnd(40) do D.mark_seen(map, rnd(800) - 400 + rnd(97) / 97, rnd(800) - 400, "unit", nil, tick - rnd(40) * MIN) end
  for j = 1, rnd(12) do D.mark_attack(map, rnd(600) - 300, rnd(600) - 300, tick - rnd(20) * MIN) end
  for j = 1, rnd(14) - 1 do D.mark_death(map, rnd(600) - 300 + rnd(7) / 8, rnd(600) - 300, tick - rnd(90) * MIN, rnd(6) == 1) end
  return map
end

local st = Tr.new_stream(20261027, 4711)
local function rnd(n) return Tr.range(st, 1, n) end

---------------------------------------------------------------------------------------------------
section("R.astar : tas en tableaux parallèles = version de 2d6cb75 (cases et développements)")
do
  local same, cases, found, blocked, capped = 0, 0, 0, 0, 0
  local t_new, t_ref = 0, 0
  for c = 1, 400 do
    local tick = 70 * MIN
    local map = random_map(rnd, tick)
    local field = field_ref(map, tick)
    local sc = { rnd(30) - 15, rnd(30) - 15 }
    local gc = { rnd(50) - 25, rnd(50) - 25 }
    local B = ({ 400, 600, 750, 1e9 })[rnd(4)]
    local seed = (c % 2 == 0) and rnd(Tr.MOD - 2) or nil
    local cap = (c % 7 == 0) and (50 + rnd(400)) or nil
    local t0 = os.clock()
    local p1, n1 = R.astar(field, sc, gc, B, seed, cap)
    local t1 = os.clock()
    local p2, n2 = Rref.astar(field, sc, gc, B, seed, cap)
    local t2 = os.clock()
    t_new, t_ref = t_new + (t1 - t0), t_ref + (t2 - t1)
    cases = cases + 1
    local eq = n1 == n2 and ((p1 == nil) == (p2 == nil))
    if eq and p1 then
      if #p1 ~= #p2 then eq = false else
        for i = 1, #p1 do if p1[i][1] ~= p2[i][1] or p1[i][2] ~= p2[i][2] then eq = false break end end
      end
    end
    if p1 then found = found + 1 else blocked = blocked + 1 end
    if n1 > (cap or R.MAX_EXPAND) then capped = capped + 1 end
    if eq then same = same + 1 end
  end
  check(same == cases and found > 100 and blocked > 10 and capped > 5,
    string.format("A* : %d / %d cas identiques (%d chemins, %d sans issue, %d au plafond)", same, cases, found, blocked, capped))
  print(string.format("  temps : nouveau %.0f ms, origine %.0f ms (x %.2f)", 1000 * t_new, 1000 * t_ref, t_ref / math.max(1e-9, t_new)))
end

---------------------------------------------------------------------------------------------------
section("R.danger_pt : coins déroulés = version de 2d6cb75 (bords de cases compris)")
do
  local same, cases = 0, 0
  for c = 1, 60 do
    local tick = 50 * MIN
    local map = random_map(rnd, tick)
    local field = field_ref(map, tick)
    for i = 1, 200 do
      local x, y
      if i % 3 == 0 then x, y = (rnd(60) - 30) * D.CELL, (rnd(60) - 30) * D.CELL -- coin exact de case
      elseif i % 3 == 1 then x, y = (rnd(60) - 30) * D.CELL + (rnd(3) - 2) * 0.01, rnd(900) - 450 + rnd(256) / 256
      else x, y = rnd(900) - 450 + rnd(1000) / 1000, rnd(900) - 450 - rnd(1000) / 1000 end
      local d1, k1 = R.danger_pt(field, x, y)
      local d2, k2 = Rref.danger_pt(field, x, y)
      cases = cases + 1
      if d1 == d2 and k1 == k2 then same = same + 1 end
    end
  end
  check(same == cases, string.format("danger_pt : %d / %d points identiques", same, cases))
end

---------------------------------------------------------------------------------------------------
section("R.plan : itinéraire complet = version de 2d6cb75 (points, longueur, profil, blocage, sortie)")
local function same_plan(a, b)
  if a.astar ~= b.astar or a.blocked ~= b.blocked or (a.partial or false) ~= (b.partial or false) then return false end
  if a.len ~= b.len or a.direct ~= b.direct or a.max_d ~= b.max_d or a.goal_d ~= b.goal_d then return false end
  if a.expand ~= b.expand or a.h ~= b.h or a.side ~= b.side then return false end
  if (a.escape == nil) ~= (b.escape == nil) then return false end
  if a.escape and (a.escape.x ~= b.escape.x or a.escape.y ~= b.escape.y) then return false end
  if #a.pts ~= #b.pts then return false end
  for i = 1, #a.pts do if a.pts[i].x ~= b.pts[i].x or a.pts[i].y ~= b.pts[i].y then return false end end
  return true
end
do
  local same, cases, nastar, nblocked = 0, 0, 0, 0
  local t_new, t_ref = 0, 0
  for c = 1, 400 do
    local tick = 80 * MIN
    local map = random_map(rnd, tick)
    local p = { x = rnd(40) - 20 + rnd(256) / 256, y = rnd(40) - 20 + rnd(256) / 256 }
    local L = 60 + rnd(360)
    local goal = { x = rnd(2 * L) - L + rnd(256) / 256, y = rnd(2 * L) - L + rnd(256) / 256 }
    local m = R.BOX_MARGIN + 1
    local box = { math.min(D.cell(p.x), D.cell(goal.x)) - m, math.min(D.cell(p.y), D.cell(goal.y)) - m,
      math.max(D.cell(p.x), D.cell(goal.x)) + m, math.max(D.cell(p.y), D.cell(goal.y)) + m }
    local field, n = field_ref(map, tick, box)
    local B = ({ 400, 600, 650, 750, 1e9 })[rnd(5)]
    local seed = (c % 2 == 0) and rnd(Tr.MOD - 2) or nil
    local s1, s2 = Tr.new_stream(c, 470), Tr.new_stream(c, 470)
    local d1 = (c % 3 ~= 0) and function(k) return Tr.range(s1, 1, k) end or nil
    local d2 = (c % 3 ~= 0) and function(k) return Tr.range(s2, 1, k) end or nil
    local side = ({ nil, 1, -1 })[rnd(3)]
    local t0 = os.clock()
    local a = R.plan(p, goal, { field = field, n = n, B = B, seed = seed, draw = d1, side = side })
    local t1 = os.clock()
    local b = Rref.plan(p, goal, { field = field, n = n, B = B, seed = seed, draw = d2, side = side })
    local t2 = os.clock()
    t_new, t_ref = t_new + (t1 - t0), t_ref + (t2 - t1)
    cases = cases + 1
    if a.astar then nastar = nastar + 1 end
    if a.blocked or a.escape then nblocked = nblocked + 1 end
    if same_plan(a, b) then same = same + 1 end
  end
  check(same == cases and nastar > 150 and nblocked > 5,
    string.format("plan : %d / %d itinéraires identiques (%d par A*, %d bloqués ou avec sortie)", same, cases, nastar, nblocked))
  print(string.format("  temps : nouveau %.0f ms, origine %.0f ms (x %.2f)", 1000 * t_new, 1000 * t_ref, t_ref / math.max(1e-9, t_new)))
end

---------------------------------------------------------------------------------------------------
section("D.field : cases mobiles par pairs = version triée de 2d6cb75")
do
  local same, cases, cells = 0, 0, 0
  local t_new, t_ref = 0, 0
  for c = 1, 300 do
    local tick = (30 + rnd(60)) * MIN
    local map = random_map(rnd, tick)
    -- beaucoup de cases mobiles (jusqu'à 256 après ménage)
    for j = 1, rnd(120) do D.mark_seen(map, rnd(900) - 450, rnd(900) - 450, "character", nil, tick - rnd(30) * MIN) end
    local box = (c % 4 ~= 0) and { rnd(30) - 30, rnd(30) - 30, rnd(30), rnd(30) } or nil
    local t0 = os.clock()
    local a, na = D.field(map, tick, box)
    local t1 = os.clock()
    local b, nb = field_ref(map, tick, box)
    local t2 = os.clock()
    t_new, t_ref = t_new + (t1 - t0), t_ref + (t2 - t1)
    cases = cases + 1
    cells = cells + na
    if same_field(a, na, b, nb) then same = same + 1 end
  end
  check(same == cases and cells > 5000, string.format("champ : %d / %d cartes identiques (%d cases)", same, cases, cells))
  print(string.format("  temps : nouveau %.0f ms, origine %.0f ms (x %.2f)", 1000 * t_new, 1000 * t_ref, t_ref / math.max(1e-9, t_new)))
end

---------------------------------------------------------------------------------------------------
section("D.exact_prep / D.exact_at = D.danger_exact en chaque point du rectangle")
do
  local same, cases, nonzero = 0, 0, 0
  for c = 1, 200 do
    local tick = (20 + rnd(80)) * MIN
    local map = random_map(rnd, tick)
    local x0, y0 = rnd(600) - 300 + rnd(256) / 256, rnd(600) - 300
    local x1, y1 = x0 + rnd(300), y0 + rnd(300) + rnd(256) / 256
    local prep = D.exact_prep(map, tick, x0, y0, x1, y1)
    for i = 1, 60 do
      local x = (i % 10 == 0) and x0 or ((i % 10 == 1) and x1 or (x0 + (x1 - x0) * rnd(1000) / 1000))
      local y = (i % 10 == 2) and y0 or ((i % 10 == 3) and y1 or (y0 + (y1 - y0) * rnd(1000) / 1000))
      local a = D.exact_at(prep, x, y)
      local b = D.danger_exact(map, x, y, tick)
      cases = cases + 1
      if a > 0 then nonzero = nonzero + 1 end
      if a == b then same = same + 1 end
    end
  end
  check(same == cases and nonzero > 500, string.format("danger exact préparé : %d / %d points identiques (%d non nuls)", same, cases, nonzero))
end

---------------------------------------------------------------------------------------------------
-- M.plan de script/ai3/comportement.lua : chargé sur un moteur simulé MINIMAL (seules les fonctions pures servent) ; le
-- profil exact préparé doit rendre le même résultat que le profil d'origine (recalculé ici avec D.danger_exact).
section("comportement.lua M.plan : profil exact préparé = profil d'origine")
do
  -- Le module complet exige le bus d'événements et le stockage : on reproduit M.plan à partir de ses sources (même
  -- texte que comportement.lua) plutôt que de charger tout le mod hors jeu. Contrôle : la fonction préparée est celle
  -- qu'appelle comportement.lua (texte cherché dans le fichier).
  local f = io.open("script/ai3/comportement.lua", "r")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  check(src:find("D.exact_prep(t2, tick, x0, y0, x1, y1)", 1, true) ~= nil and src:find("D.exact_at(prep, q.x, q.y)", 1, true) ~= nil
    and src:find("D.exact_at(prep, goal.x, goal.y)", 1, true) ~= nil,
    "comportement.lua M.plan appelle D.exact_prep et D.exact_at")
  local function d2(a, b) local dx, dy = a.x - b.x, a.y - b.y return dx * dx + dy * dy end
  local same, cases = 0, 0
  for c = 1, 300 do
    local tick = (20 + rnd(80)) * MIN
    local map = random_map(rnd, tick)
    local p = { x = rnd(40) - 20 + rnd(256) / 256, y = rnd(40) - 20 }
    local L = 60 + rnd(300)
    local goal = { x = rnd(2 * L) - L, y = rnd(2 * L) - L + rnd(256) / 256 }
    local m = R.BOX_MARGIN + 1
    local box = { math.min(D.cell(p.x), D.cell(goal.x)) - m, math.min(D.cell(p.y), D.cell(goal.y)) - m,
      math.max(D.cell(p.x), D.cell(goal.x)) + m, math.max(D.cell(p.y), D.cell(goal.y)) + m }
    local field, n = D.field(map, tick, box)
    local res = R.plan(p, goal, { field = field, n = n, B = 650 })
    -- origine
    local mx = 0
    for _, q in ipairs(R.samples(p, res.pts, goal, R.SAMPLE)) do
      if d2(q, p) > 36 then
        local v = D.danger_exact(map, q.x, q.y, tick)
        if v > mx then mx = v end
      end
    end
    local eg = D.danger_exact(map, goal.x, goal.y, tick)
    -- préparé (même texte que comportement.lua)
    local mx2 = 0
    local qs = R.samples(p, res.pts, goal, R.SAMPLE)
    local x0, y0, x1, y1 = goal.x, goal.y, goal.x, goal.y
    for _, q in ipairs(qs) do
      if q.x < x0 then x0 = q.x elseif q.x > x1 then x1 = q.x end
      if q.y < y0 then y0 = q.y elseif q.y > y1 then y1 = q.y end
    end
    local prep = D.exact_prep(map, tick, x0, y0, x1, y1)
    for _, q in ipairs(qs) do
      if d2(q, p) > 36 then
        local v = D.exact_at(prep, q.x, q.y)
        if v > mx2 then mx2 = v end
      end
    end
    local eg2 = D.exact_at(prep, goal.x, goal.y)
    cases = cases + 1
    if mx == mx2 and eg == eg2 then same = same + 1 end
  end
  check(same == cases, string.format("profil exact : %d / %d itinéraires identiques", same, cases))
end

---------------------------------------------------------------------------------------------------
-- MUTANT : une réduction fausse (plafond des développements décalé de 1) doit être vue par le contrôle d'équivalence.
section("mutant : un A* qui s'arrête un développement plus tôt est vu")
do
  local diff = 0
  for c = 1, 100 do
    local tick = 70 * MIN
    local map = random_map(rnd, tick)
    local field = field_ref(map, tick)
    local sc, gc = { rnd(30) - 15, rnd(30) - 15 }, { rnd(50) - 25, rnd(50) - 25 }
    local cap = 30 + rnd(300)
    local _, n1 = R.astar(field, sc, gc, 600, nil, cap - 1)
    local _, n2 = Rref.astar(field, sc, gc, 600, nil, cap)
    if n1 ~= n2 then diff = diff + 1 end
  end
  check(diff > 10, string.format("mutant vu : %d cas sur 100 différents", diff))
end

---------------------------------------------------------------------------------------------------
-- A* ÉTALÉ (R.search_new / R.search_step, brique non branchée) : quel que soit le budget par appel, même chemin et mêmes
-- développements que R.astar ; travail par appel borné par le budget ; état sans fonction (rangeable dans global).
section("A* étalé : même résultat que R.astar quel que soit le découpage, état rangeable")
do
  local function serializable(v, depth)
    if depth > 6 then return true end
    local tv = type(v)
    if tv == "function" or tv == "userdata" or tv == "thread" then return false end
    if tv == "table" then
      for k, x in pairs(v) do
        if type(k) ~= "number" and type(k) ~= "string" then return false end
        if not serializable(x, depth + 1) then return false end
      end
    end
    return true
  end
  local same, cases, bounded, ser, calls_max = 0, 0, 0, 0, 0
  for c = 1, 300 do
    local tick = 70 * MIN
    local map = random_map(rnd, tick)
    local field = field_ref(map, tick)
    local sc = { rnd(30) - 15, rnd(30) - 15 }
    local gc = { rnd(50) - 25, rnd(50) - 25 }
    local B = ({ 400, 600, 750, 1e9 })[rnd(4)]
    local seed = (c % 2 == 0) and rnd(Tr.MOD - 2) or nil
    local cap = (c % 7 == 0) and (50 + rnd(400)) or nil
    local budget = ({ 1, 7, 50, 200, 100000 })[rnd(5)]
    local p1, n1 = R.astar(field, sc, gc, B, seed, cap)
    local st = R.search_new(field, sc, gc, B, seed, cap)
    local calls, ok_bound = 0, true
    while true do
      local w0 = st.work
      local done = R.search_step(st, budget)
      calls = calls + 1
      if st.work - w0 > budget then ok_bound = false end
      if done then break end
      if calls == 3 and not serializable(st, 0) then ok_bound = false end
    end
    if calls > calls_max then calls_max = calls end
    cases = cases + 1
    if ok_bound then bounded = bounded + 1 end
    if serializable(st, 0) then ser = ser + 1 end
    local p2, n2 = st.path, st.expand
    local eq = n1 == n2 and ((p1 == nil) == (p2 == nil))
    if eq and p1 then
      if #p1 ~= #p2 then eq = false else
        for i = 1, #p1 do if p1[i][1] ~= p2[i][1] or p1[i][2] ~= p2[i][2] then eq = false break end end
      end
    end
    if eq then same = same + 1 end
  end
  check(same == cases and calls_max > 100, string.format("A* étalé = R.astar : %d / %d cas (jusqu'à %d appels)", same, cases, calls_max))
  check(bounded == cases and ser == cases, string.format("travail par appel borné (%d / %d), état sans fonction (%d / %d)", bounded, cases, ser, cases))
end

print(string.format("[PERF] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
