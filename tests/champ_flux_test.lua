--[[
  Tests hors jeu du flux d'un champ (lot CHAMP, corr-champ2 ; règle pure shared/team/champ_flux.lua). Usage, depuis la racine du mod :
    lua5.2 tests/champ_flux_test.lua
  1. cas écrits (sorties vidées au-dessus du seuil, combustible donné aux plus vides, plancher du stock, budgets) ;
  2. invariants sur 400 tirages (RNG maison) : jamais plus que le contenu, jamais sous le plancher, jamais au-dessus de la cible, budgets,
     conservation, résultat indépendant de l'ordre des listes ;
  3. mutants : chaque règle faussée est refusée.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local Fx = require("shared.team.champ_flux")
local C = Fx.CFG

local function sum(l) local s = 0 for _, x in ipairs(l) do s = s + x[2] end return s end
local function as_map(l) local m = {} for _, x in ipairs(l) do m[x[1]] = (m[x[1]] or 0) + x[2] end return m end

-- 1. cas écrits
print("== 1. cas")
do
  local r = Fx.plan({ { id = 1, n = 10 }, { id = 2, n = 300 }, { id = 3, n = 50 } }, {}, 0)
  local m = as_map(r.take)
  check(m[1] == nil and m[2] == 300 and m[3] == 50 and r.out == 350, "sorties : vidées au-dessus de out_min, pas en dessous")
  local r2 = Fx.plan({}, { { id = 1, n = 0 }, { id = 2, n = 30 }, { id = 3, n = 10 } }, 10000)
  local g = as_map(r2.give)
  check(g[1] == C.fuel_target and g[2] == nil and g[3] == C.fuel_target - 10, "combustible : les coffres sous fuel_low remplis jusqu'à fuel_target")
  local r3 = Fx.plan({}, { { id = 1, n = 0 } }, C.fuel_floor + 5)
  check(r3.fuel == 5, "plancher : seul le combustible au-dessus de fuel_floor est donné (" .. r3.fuel .. ")")
  local r4 = Fx.plan({}, { { id = 1, n = 0 } }, C.fuel_floor)
  check(r4.fuel == 0 and #r4.give == 0, "plancher : rien sous fuel_floor")
  -- peu de combustible : tous d'abord jusqu'à fuel_low, les plus vides d'abord
  local q = {}
  for i = 1, 5 do q[i] = { id = i, n = 2 * i } end -- 2, 4, 6, 8, 10
  local r5 = Fx.plan({}, q, C.fuel_floor + 5 * C.fuel_low)
  local g5 = as_map(r5.give)
  local all_low = true
  for i = 1, 5 do if 2 * i + (g5[i] or 0) < C.fuel_low then all_low = false end end
  check(all_low, "peu de combustible : chaque coffre atteint fuel_low avant qu'un autre aille au-delà")
  local r6 = Fx.plan({ { id = 1, n = C.budget_out + 500 } }, {}, 0)
  check(r6.out == C.budget_out, "budget des sorties")
  local big = {}
  for i = 1, 100 do big[i] = { id = i, n = 0 } end
  local r7 = Fx.plan({}, big, 1e9)
  check(r7.fuel == C.budget_fuel, "budget du combustible")
end

-- 2. invariants
print("== 2. invariants (400 tirages)")
local seed = 12345
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
local function invariants(fn, verbose)
  local bad = 0
  seed = 12345
  for _ = 1, 400 do
    local outs, quais = {}, {}
    for i = 1, rnd(12) do outs[#outs + 1] = { id = i, n = rnd(600) } end
    for i = 1, rnd(30) do quais[#quais + 1] = { id = i, n = rnd(70) } end
    local fuel = rnd(3000)
    local r = fn(outs, quais, fuel)
    local ok = true
    local om, qm = {}, {}
    for _, c in ipairs(outs) do om[c.id] = c.n end
    for _, c in ipairs(quais) do qm[c.id] = c.n end
    for _, t in ipairs(r.take) do if t[2] <= 0 or t[2] > om[t[1]] or om[t[1]] < C.out_min then ok = false end end
    for _, g in ipairs(r.give) do if g[2] <= 0 or qm[g[1]] >= C.fuel_low or qm[g[1]] + g[2] > C.fuel_target then ok = false end end
    if sum(r.take) ~= r.out or sum(r.give) ~= r.fuel then ok = false end
    if r.out > C.budget_out or r.fuel > C.budget_fuel or fuel - r.fuel < math.min(fuel, C.fuel_floor) then ok = false end
    -- ordre des listes : le même plan sur les listes renversées
    local ro, rq = {}, {}
    for i = #outs, 1, -1 do ro[#ro + 1] = outs[i] end
    for i = #quais, 1, -1 do rq[#rq + 1] = quais[i] end
    local r2 = fn(ro, rq, fuel)
    local a, b = as_map(r.take), as_map(r2.take)
    for k, v in pairs(a) do if b[k] ~= v then ok = false end end
    a, b = as_map(r.give), as_map(r2.give)
    for k, v in pairs(a) do if b[k] ~= v then ok = false end end
    if not ok then bad = bad + 1 end
  end
  if verbose then print(string.format("  %d tirage(s) en défaut", bad)) end
  return bad
end
check(invariants(Fx.plan, true) == 0, "invariants sur 400 tirages")

-- 3. mutants
print("== 3. mutants")
local function with_cfg(k, v)
  return function(o, q, f)
    local c2 = {}
    for kk, vv in pairs(C) do c2[kk] = vv end
    c2[k] = v
    return Fx.plan(o, q, f, c2)
  end
end
local mutants = {
  { "plancher ignoré", with_cfg("fuel_floor", 0) },
  { "sorties vidées sous le seuil", with_cfg("out_min", 0) },
  { "remplissage au-delà de la cible", with_cfg("fuel_target", 90) },
  { "budget des sorties ignoré", with_cfg("budget_out", 1e9) },
  { "budget du combustible ignoré", with_cfg("budget_fuel", 1e9) },
  { "tout coffre de combustible servi", with_cfg("fuel_low", 1000) },
}
local survivors = 0
for _, mu in ipairs(mutants) do
  -- un mutant est refusé s'il viole un invariant OU un cas écrit (rejoué sous le mutant)
  -- invariants mesurés avec les seuils de la VRAIE règle
  local bad = invariants(function(o, q, f) return mu[2](o, q, f) end, false)
  local r = mu[2]({}, { { id = 1, n = 0 } }, C.fuel_floor)
  if r.fuel > 0 then bad = bad + 1 end
  -- cas écrits des budgets, rejoués sous le mutant
  if mu[2]({ { id = 1, n = C.budget_out + 500 } }, {}, 0).out > C.budget_out then bad = bad + 1 end
  local big = {}
  for i = 1, 100 do big[i] = { id = i, n = 0 } end
  if mu[2]({}, big, 1e9).fuel > C.budget_fuel then bad = bad + 1 end
  check(bad > 0, "mutant refusé : " .. mu[1])
  if bad == 0 then survivors = survivors + 1 end
end
print(string.format("[CHAMP-FLUX] mutants : %d refusés sur %d", #mutants - survivors, #mutants))

print(string.format("[CHAMP-FLUX] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
