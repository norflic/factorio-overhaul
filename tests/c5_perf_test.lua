--[[
  C5-PERF (chantier 5 du DC : aucun tick au-dessus de 15 ms dû à champ:frame). Partie 0.9.4 du DC : 238 pics, tous champ:frame ; pas
  « bare » (Co.away -> Co.route) jusqu'à 62 ms pour 2 749 de travail compté. Cause : la MÉMOIRE allouée dans un appel (le ramasse-miettes
  du jeu la paie dans le même tick), pas le travail compté : tables d'états de l'A* recopiées d'un bloc à chaque doublement (1,3 Mo
  d'un coup), colonnes Co.layout refaites à chaque reprise, entrées du tas et lectures gardées jamais comptées au budget.
  Ce test vérifie, hors jeu :
  1. MÊME PLAN : empreintes des plans des deux cadres relevés dans la partie du DC (fixtures) au budget du jeu == empreintes de 0.9.5
     (83761e6d, avant le lot), et plan découpé == plan d'un bloc sur une forme non triviale (ellipse coupée d'une rivière, fenêtre bornée) ;
  2. MÉMOIRE BORNÉE par appel de Ch.plan_steps (ramasse-miettes arrêté) : au plus C5.MAX_KB Ko, contre 4,7 Mo avant ;
  3. Co.route reprenable : chaque tranche alloue au plus ROUTE_KB Ko et fait au plus le budget + une unité indivisible ; même tracé ;
  4. lectures de la spec reprenables (shared/team/champ_lecture.lua) == versions d'un bloc (Paires.nearest_component, coal_from).
  Usage, depuis la racine du mod :   lua5.2 tests/c5_perf_test.lua
]]
package.path = "./?.lua;" .. package.path
local Ch = require("shared.team.champ")
local Co = require("shared.team.champ_colonne")
local Lu = require("shared.team.champ_lecture")
local Pa = require("shared.team.pose_paires")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function ser(v, seen)
  if type(v) ~= "table" then return tostring(v) end
  if seen[v] then return "<cyc>" end
  seen[v] = true
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  local o = {}
  for _, k in ipairs(ks) do local x = v[k]; if type(x) ~= "function" then o[#o + 1] = tostring(k) .. "=" .. ser(x, seen) end end
  seen[v] = nil
  return "{" .. table.concat(o, ",") .. "}"
end
local function hash(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end return h end
local function ph(p, why) return p and hash(ser(p, {})) or ("nil:" .. tostring(why)) end

local MAX_KB = 1200 -- Ko alloués au plus par appel de Ch.plan_steps (avant le lot : 4 739 Ko, fixture emerald)
local CFG0 = {}
for k, v in pairs(Ch.CFG) do CFG0[k] = v end
-- empreintes de la fusion integ-096 (3101a193 : C1 tapis de base, C2 pavage, C3, C4, C5) avant C5B : Ch.plan_steps au budget du jeu (2 200)
-- == Ch.plan d'un bloc (même sérialisation ; 0.9.5 : 119286278 / 1 286 et 521882340 / 2 098 pièces, avant le pavage de C2)
local REF = { ["tests/fixtures/champ_joueur_dc.lua"] = { 41996054, 3144 }, ["tests/fixtures/champ_emerald_dc.lua"] = { 309663340, 4183 } }

print("== C5-PERF : même plan (fixtures du DC), mémoire bornée par appel")
for _, fx in ipairs({ "tests/fixtures/champ_joueur_dc.lua", "tests/fixtures/champ_emerald_dc.lua" }) do
  local d = dofile(fx)
  for k, v in pairs(CFG0) do Ch.CFG[k] = v end
  for k, v in pairs(d.cfg or {}) do Ch.CFG[k] = v end
  local st = Ch.plan_begin(d.spec)
  local done, calls, maxkb, at = false, 0, 0, "-"
  collectgarbage("collect")
  while not done and calls < 100000 do
    collectgarbage("stop")
    local m0 = collectgarbage("count")
    done = Ch.plan_steps(st, 2200)
    local kb = collectgarbage("count") - m0
    collectgarbage("restart")
    calls = calls + 1
    if kb > maxkb then maxkb, at = kb, (Ch.LAST_STEP or "-"):match("^%S+") end
    if calls % 50 == 0 then collectgarbage("collect") end
  end
  local p, why = Ch.plan_result(st)
  check(done and p ~= nil, fx .. " : plan fini")
  check(p and ph(p) == ph(Ch.plan(d.spec)), fx .. " : plan découpé (budget du jeu) == Ch.plan d'un bloc")
  check(p and ph(p) == REF[fx][1] and #p.ents == REF[fx][2], string.format("%s : empreinte %s (%d pièces), référence : %d (%d pièces)", fx,
    tostring(p and ph(p)), p and #p.ents or -1, REF[fx][1], REF[fx][2]))
  check(maxkb <= MAX_KB, string.format("%s : %.0f Ko alloués au plus par appel (%s), borne %d", fx, maxkb, at, MAX_KB))
  print(string.format("  %s : %d appels, empreinte %s, au plus %.0f Ko par appel (%s)", fx, calls, tostring(p and ph(p)), maxkb, at))
end
for k, v in pairs(CFG0) do Ch.CFG[k] = v end

print("== C5-PERF : plan découpé == plan d'un bloc (ellipse coupée d'une rivière)")
do
  local function ellipse(cx, cy, a, b)
    local out = {}
    for x = cx - a, cx + a do for y = cy - b, cy + b do if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 then out[#out + 1] = x; out[#out + 1] = y end end end
    return out
  end
  local function mk()
    local bl = {}
    for y = -40, 40 do for x = 44, 47 do if y ~= 3 then bl[Ch.key(x, y)] = "eau" end end end
    return { ore = ellipse(0, 0, 60, 25), blocked = bl, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
      belts = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }, furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 },
      inserter = { rate = 0.83 }, target = { x = 1000, y = 0 }, max_side = 8, design = "colonne",
      coal = { tiles = ellipse(10, 45, 7, 7), rate = 0.5 }, logistics = { splitter = true, underground = 5 }, window = { -90, -60, 90, 70 } }
  end
  local h1 = ph(Ch.plan(mk()))
  local st = Ch.plan_begin(mk())
  local done, calls = false, 0
  while not done and calls < 100000 do done = Ch.plan_steps(st, 300); calls = calls + 1 end
  local h2 = ph(Ch.plan_result(st))
  check(h1 == h2, string.format("rivière : plan découpé (budget 300, %d appels) %s == d'un bloc %s", calls, tostring(h2), tostring(h1)))
end

print("== C5-PERF : Co.route reprenable, mémoire et travail bornés par tranche")
do
  -- grand tracé : obstacles tirés, « trop long » au plafond de 20 000 états (le cas des pas « bare » de la partie du DC)
  local seed = 4242
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
  local blocked = {}
  for u = -150, 150 do for v = -150, 150 do if rnd() < 0.18 then blocked[Co.tk(u, v)] = true end end end
  local function free(u, v) return not blocked[Co.tk(u, v)] end
  local box = { u0 = -150, v0 = -150, u1 = 150, v1 = 150 }
  local s, t = { u = -140, v = 0 }, { u = 140, v = 3 }
  blocked[Co.tk(s.u, s.v)] = nil; blocked[Co.tk(t.u, t.v)] = nil
  Co.WORK_LIM = nil
  local r1, w1 = Co.route(s, 2, t, 2, free, nil, 5, box, 20000)
  local job, r2, w2, k = {}, nil, nil, 0
  local LIM, maxkb, maxw = 1600, 0, 0
  collectgarbage("collect")
  repeat
    collectgarbage("stop")
    local m0 = collectgarbage("count")
    Co.WORK, Co.WORK_LIM = 0, LIM
    r2, w2 = Co.route(s, 2, t, 2, free, nil, 5, box, 20000, nil, nil, job)
    local kb = collectgarbage("count") - m0
    collectgarbage("restart")
    if k > 0 and kb > maxkb then maxkb = kb end -- (la première tranche alloue les tableaux du départ)
    if Co.WORK > maxw then maxw = Co.WORK end
    k = k + 1
  until w2 ~= Co.SUSPEND or k > 100000
  Co.WORK_LIM = nil
  check(ser(r1 or {}, {}) == ser(r2 or {}, {}) and tostring(w1) == tostring(w2), string.format("tracé reprenable == d'un bloc (%s / %s)",
    tostring(w1), tostring(w2)))
  check(k > 20, string.format("tracé découpé : %d tranches", k))
  local ROUTE_KB = 400
  check(maxkb <= ROUTE_KB, string.format("mémoire d'une tranche de tracé : %.0f Ko au plus (borne %d ; une table d'états recopiée d'un bloc : > 1 Mo)", maxkb, ROUTE_KB))
  -- une unité indivisible : un état développé, ses arêtes (3 tapis + 4 souterrains) et leurs lectures gardées
  local bound = LIM + 1 + 7 * Co.PUSH_WORK + 12 * Co.PUSH_WORK
  check(maxw <= bound, string.format("travail d'une tranche de tracé : %d au plus (borne %d)", maxw, bound))
  print(string.format("  tracé %s : %d tranches, au plus %.0f Ko et %d de travail par tranche", tostring(w1), k, maxkb, maxw))
end

print("== C5-PERF : lectures reprenables == d'un bloc (composante du gisement, fenêtres de charbon)")
do
  local seed = 7
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
  local same_c, same_k, n = 0, 0, 0
  for trial = 1, 40 do
    local res = {}
    local cx, cy = math.floor(rnd() * 40) - 20, math.floor(rnd() * 40) - 20
    local R = 10 + math.floor(rnd() * 70)
    local dens = 0.2 + rnd() * 0.8
    for x = -R, R do for y = -R, R do if rnd() < dens and x * x + y * y <= R * R then res[#res + 1] = { x = x + 0.5, y = y + 0.5 } end end end
    for i = #res, 2, -1 do local j = 1 + math.floor(rnd() * i); res[i], res[j] = res[j], res[i] end
    local a = Pa.nearest_component(res, Pa.GAP, { x = cx, y = cy })
    local J = Lu.component_begin(res, Pa.GAP, { x = cx, y = cy }, Pa.SEED_MAX)
    local fin, b, steps = false, nil, 0
    while not fin do fin, b = Lu.component_step(J, 50 + trial * 13); steps = steps + 1 end
    local ok = #a == #b and (steps > 1 or #res < 50)
    for i = 1, #a do if not ok or a[i].x ~= b[i].x or a[i].y ~= b[i].y then ok = false break end end
    if ok then same_c = same_c + 1 end
    local W = 5 + trial % 30
    local f1, b1 = Lu.coal_from(res, { x = cx, y = cy }, W)
    local C = Lu.coal_begin(res, { x = cx, y = cy }, W)
    local f2, b2
    fin = false
    while not fin do fin, f2, b2 = Lu.coal_step(C, 40 + trial * 7) end
    local ok2 = (f1 == nil) == (f2 == nil) and ser(f1 or {}, {}) == ser(f2 or {}, {}) and ser(b1 or {}, {}) == ser(b2 or {}, {})
    if ok2 then same_k = same_k + 1 end
    n = n + 1
  end
  check(same_c == n, string.format("composante reprenable == Paires.nearest_component : %d/%d", same_c, n))
  check(same_k == n, string.format("fenêtres de charbon reprenables == coal_from : %d/%d", same_k, n))
  -- tri fusion reprenable : ordre strict, tableaux tirés, budgets variés
  local okm = 0
  for trial = 1, 30 do
    local a, b = {}, {}
    for i = 1, trial * 37 do local x = math.floor(rnd() * 1e6) * 1000 + i; a[i] = x; b[i] = x end
    table.sort(a)
    local S = Lu.msort_begin(b, function(x, y) return x < y end)
    while not Lu.msort_step(S, 1 + trial * 5) do end
    if ser(a, {}) == ser(b, {}) then okm = okm + 1 end
  end
  check(okm == 30, string.format("tri fusion reprenable == table.sort : %d/30", okm))
end

print(string.format("C5-PERF : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
