--[[
  perf-frame (carte du DC à 600 % : étapes du plan de gisement de 0,1 à 1,1 s dans UN tick) : les recherches longues d'une étape
  (tracés Co.route et preuve d'impossibilité, colonnes ailleurs Co.away, lignes de charbon Co.coal_line, réseau Co.network, recherche de
  phase, relais, relevé du contexte) s'arrêtent au budget de travail du pas (Ch.STEP_WORK : un COMPTE, jamais un temps) et reprennent au
  pas suivant. Ce test vérifie, sur des cas purs et sur les deux cadres relevés dans la partie du DC :
  1. plan découpé (budget petit) == plan d'un bloc (budget infini) == Ch.plan : même empreinte ;
  2. le découpage a lieu (plus de pas), l'état reste sans fonction entre deux pas ;
  3. travail d'un pas borné : au plus le budget plus UNE unité indivisible (un état, une rangée, une ligne, un tour de relais) ;
  4. Co.route reprenable == Co.route d'un bloc sur des grilles tirées (chemins, « trop long », « aucun chemin » prouvé) ;
  5. Ch.plan_steps (plusieurs étapes d'une même variante par appel, sous un budget de tick) : même plan.
  Usage, depuis la racine du mod :   lua5.2 tests/perf_frame_test.lua
]]
package.path = "./?.lua;" .. package.path
local Ch = require("shared.team.champ")
local Co = require("shared.team.champ_colonne")

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
local function hash(s)
  local h = 0
  for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
  return h
end
local function ph(p, why) return p and hash(ser(p, {})) or ("nil:" .. tostring(why)) end
local function find_fn(v, path, seen)
  if type(v) == "function" then return path end
  if type(v) ~= "table" or seen[v] then return nil end
  seen[v] = true
  for k, x in pairs(v) do
    if k ~= "spec" and k ~= "memo" and (type(x) == "table" or type(x) == "function") then
      local r = find_fn(x, path .. "." .. tostring(k), seen)
      if r then return r end
    end
  end
  return nil
end

local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function ellipse(cx, cy, a, b)
  local out = {}
  for x = cx - a, cx + a do for y = cy - b, cy + b do if ((x - cx) / a) ^ 2 + ((y - cy) / b) ^ 2 <= 1 then out[#out + 1] = x; out[#out + 1] = y end end end
  return out
end
local function spec46(ore, o)
  return { ore = ore, blocked = o.blocked or {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = o.furnace or { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 },
    target = { x = 1000, y = 0 }, max_side = 8, design = "colonne", axis = o.axis,
    coal = o.coal and { tiles = o.coal, rate = 0.5 } or nil, logistics = { splitter = true, underground = 5 }, window = o.window }
end
-- rivière qui coupe le champ (tracés longs, colonnes ailleurs) et fenêtre lue bornée
local function river()
  local b = {}
  for y = -40, 40 do for x = 44, 47 do if y ~= 3 then b[Ch.key(x, y)] = "eau" end end end
  return b
end

local CASES = {
  { "ellipse 45x30 + charbon", function() return spec46(ellipse(0, 0, 45, 30), { coal = ellipse(0, 50, 8, 8) }) end },
  { "ellipse 60x25 riviere", function() return spec46(ellipse(0, 0, 60, 25), { coal = ellipse(10, 45, 7, 7), blocked = river(),
    window = { -90, -60, 90, 70 } }) end },
  { "four electrique", function() return spec46(ellipse(0, 0, 30, 16), { furnace = { size = 2, rate = 0.625, fuel = false } }) end },
}
for _, fx in ipairs({ { "dc joueur fer 1", "tests/fixtures/champ_joueur_dc.lua" }, { "dc emerald fer 3", "tests/fixtures/champ_emerald_dc.lua" } }) do
  local h = io.open(fx[2], "r")
  if h then
    h:close()
    CASES[#CASES + 1] = { fx[1], function() return dofile(fx[2]).spec end, dofile(fx[2]).cfg }
  end
end

local CFG0 = {}
for k, v in pairs(Ch.CFG) do CFG0[k] = v end
local W0 = Ch.STEP_WORK
local function run(mk, work)
  Ch.STEP_WORK = work
  local st = Ch.plan_begin(mk())
  local steps, maxw, fn_at = 0, 0, nil
  local done = false
  while not done and steps < 200000 do
    done = Ch.plan_step(st)
    steps = steps + 1
    if Co.WORK > maxw then maxw = Co.WORK end
    if not done and steps % 7 == 0 then fn_at = fn_at or find_fn(st, "st", {}) end
  end
  Ch.STEP_WORK = W0
  return ph(Ch.plan_result(st)), steps, maxw, fn_at, done
end

print("== perf-frame : plan découpé au budget du pas == plan d'un bloc")
for _, cs in ipairs(CASES) do
  for k, v in pairs(CFG0) do Ch.CFG[k] = v end
  for k, v in pairs(cs[3] or {}) do Ch.CFG[k] = v end
  local h_big, n_big = run(cs[2], math.huge)
  local h_small, n_small, maxw, fn_at, done = run(cs[2], 200)
  local h_def, n_def, maxw_def = run(cs[2], W0)
  local hp = ph(Ch.plan(cs[2]()))
  check(done, cs[1] .. " : séquence découpée finie")
  check(h_small == h_big and h_def == h_big and hp == h_big,
    string.format("%s : empreintes découpé %s, défaut %s, d'un bloc %s, Ch.plan %s", cs[1], tostring(h_small), tostring(h_def), tostring(h_big), tostring(hp)))
  check(n_small > n_big, string.format("%s : découpage effectif (%d pas au budget 200, %d d'un bloc)", cs[1], n_small, n_big))
  check(fn_at == nil, string.format("%s : état sans fonction entre deux pas (%s)", cs[1], tostring(fn_at)))
  print(string.format("  %s : %d pas d'un bloc, %d au budget %d (travail max %d), %d au budget 200 (travail max %d), empreinte %s",
    cs[1], n_big, n_def, W0, maxw_def, n_small, maxw, tostring(h_big)))
end
for k, v in pairs(CFG0) do Ch.CFG[k] = v end

print("== perf-frame : travail d'un pas borné")
do
  -- au budget 200, un pas dépasse le budget d'au plus une unité indivisible : une ligne de charbon (sommes d'une colonne de la
  -- fenêtre), une rangée de foreuses (largeur x décalages), un tour de relais ; jamais tout un tracé
  local mk = CASES[2][2]
  local _, _, maxw = run(mk, 200)
  -- (compte d'un pas : budget + forfaits d'étape Ch.HEAVY_WORK et Ch.STEP_BASE + lectures de place libre + une unité indivisible)
  local bound = 200 + Ch.HEAVY_WORK + Ch.STEP_BASE + 3000
  check(maxw < bound, string.format("travail max d'un pas au budget 200 : %d (borne %d)", maxw, bound))
end

print("== perf-frame : Co.route reprenable == d'un bloc")
do
  local seed = 12345
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
  local same, n = 0, 0
  local kinds = {}
  for trial = 1, 24 do
    local blocked = {}
    local dens = 0.15 + 0.05 * (trial % 5)
    for u = -40, 40 do for v = -40, 40 do if rnd() < dens then blocked[Co.tk(u, v)] = true end end end
    -- mur : aucun chemin (preuve) ; perf-astar : 6 tuiles d'épaisseur (ces essais ont des souterrains de 4 : un mur d'une tuile se sautait,
    -- aucun « aucun chemin » n'était jamais essayé)
    if trial % 6 == 0 then for v = -40, 40 do for u = -3, 2 do blocked[Co.tk(u, v)] = true end end end
    local function free(u, v) return not blocked[Co.tk(u, v)] end
    local box = { u0 = -40, v0 = -40, u1 = 40, v1 = 40 }
    local s = { u = -30 + math.floor(rnd() * 20), v = math.floor(rnd() * 60) - 30 }
    local t = { u = 10 + math.floor(rnd() * 20), v = math.floor(rnd() * 60) - 30 }
    blocked[Co.tk(s.u, s.v)] = nil; blocked[Co.tk(t.u, t.v)] = nil
    local cap = (trial % 4 == 0) and 1500 or 8000
    if trial % 6 == 0 then cap = 30000 end -- (perf-astar : plafond au-dessus des états du côté du départ : la preuve peut conclure)
    local ug = (trial % 2 == 0) and 4 or nil
    Co.WORK_LIM = nil
    local r1, w1 = Co.route(s, 2, t, 2, free, nil, ug, box, cap)
    local job, r2, w2, k = {}, nil, nil, 0
    repeat
      Co.WORK, Co.WORK_LIM = 0, 150
      r2, w2 = Co.route(s, 2, t, 2, free, nil, ug, box, cap, nil, nil, job)
      k = k + 1
    until w2 ~= Co.SUSPEND or k > 10000
    Co.WORK_LIM = nil
    n = n + 1
    if ser(r1 or {}, {}) == ser(r2 or {}, {}) and tostring(w1) == tostring(w2) and job.R == nil then same = same + 1 end
    kinds[r1 and "chemin" or tostring(w1)] = true
  end
  check(same == n, string.format("Co.route reprenable : %d/%d tracés identiques", same, n))
  check(kinds["chemin"] and kinds["trop long"] and kinds["aucun chemin"], "tracés essayés : chemins, « trop long » et « aucun chemin »")
end

print("== perf-frame : Ch.plan_steps (étapes d'une même variante groupées sous un budget de tick)")
do
  for _, cs in ipairs({ CASES[1], CASES[2] }) do
    local h_ref = ph(Ch.plan(cs[2]()))
    local st = Ch.plan_begin(cs[2]())
    local calls, done = 0, false
    while not done and calls < 200000 do done = Ch.plan_steps(st, 5000); calls = calls + 1 end
    check(ph(Ch.plan_result(st)) == h_ref, string.format("%s : Ch.plan_steps, même plan (%d appels, %d pas)", cs[1], calls, st.k))
    check(calls < st.k, string.format("%s : plusieurs étapes par appel (%d appels pour %d pas)", cs[1], calls, st.k))
  end
end

print(string.format("perf-frame : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
