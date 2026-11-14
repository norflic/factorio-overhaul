--[[
  Lot s43-robots (14/11) : banc hors jeu des VARIANTES complémentaires (shared/robots/variantes.lua, ajoutées à Ro.ROBOTS par
  shared/content/robots.lua).
    §1 règle de coût : V.mu redonne le but des robots du plan (±2 %) ; coût d'une variante = V.mu × prime de vitesse ; recette à ±20 %
       du but (monnaies de tests/robots_test.lua), au plus 100 de chaque, sans doublon ;
    §2 dérivation pure : forme, portée, vitesse, cadence tirées du parent par les facteurs de V.SPECS ; mêmes entrées, même sortie ;
    §3 calibrage : PV, dégâts et soin écrits = ceux de shared/robots/duel.lua (le même contrôle que les 12) ;
    §4 rôles lus aux NOMBRES par le cerveau (shared/ai3/robots.lua) : soutien, ligne ; aucune portée minimale ;
    §5 RANG figé de chaque variante parmi les 12 unités non géantes (9 du plan + 3) : PV / coût, DPS / coût, portée, vitesse ;
    §6 la frappe lourde du Perce-Blindage : meilleure qu'une rafale de même DPS (blindés du palier 4, palier 5 ordinaire) ;
    §7 choix du cerveau par âge (candidats lus aux données, coût = but) : les variantes n'écrasent pas la ligne de leur âge ;
    §8 visuel : la feuille du parent existe, échelle et teinte ; technologies et usines ;
    §9 mutants : chaque règle faussée est vue.
  CHIFFRES PROVISOIRES (le DC tranchera) : ce banc FIGE l'état livré pour qu'un changement se voie, il ne le valide pas.
  Usage : lua5.2 tests/s43_robots_test.lua   (depuis la racine du mod) ; `--table` imprime la table de rang.
]]
package.path = "./?.lua;" .. package.path

local X = require("shared.content.epochs")
local Lv = require("shared.levels.config")
local Cp = require("shared.content.compute")
local Pt = require("shared.content.robot_parts")
local Ro = require("shared.content.robots")
local V = require("shared.robots.variantes")
local D = require("shared.robots.duel")
local Rb = require("shared.ai3.robots")

local pass, fail = 0, 0
local function check(c, m)
  if c then pass = pass + 1 else fail = fail + 1 print("[S43-ROBOTS] ECHEC " .. m) end
end

-- monnaies (même valuation que tests/robots_test.lua §1)
local value = {}
for _, c in ipairs(X.currencies) do value[c.item] = c.value end
for e = 2, 12 do local m = Lv.epoch_materials[e]; if m then value[m.item] = m.value end end
local memo = {}
local function mu_of(item)
  if memo[item] then return memo[item] end
  local v
  if Pt.present(item) then
    local rr = Pt.recipe(item)
    local s = 0
    for _, g in ipairs(rr.ingredients) do s = s + mu_of(g[1]) * g[2] end
    v = s / rr.results[1][2]
  elseif value[item] then v = value[item]
  elseif Ro.MU_ASSUMED[item] then v = Ro.MU_ASSUMED[item]
  else v = Cp.mu(item) end
  memo[item] = v
  return v
end
local function cost(list) local s = 0 for _, g in ipairs(list) do s = s + mu_of(g[1]) * g[2] end return s end

local VAR = {}
for _, r in ipairs(Ro.ROBOTS) do if r.variant then VAR[#VAR + 1] = r end end

--- La suite sur un module de variantes `Vm` (mutants) et les variantes `vars` qu'il dérive.
local function suite(Vm, vars, quiet)
  local qfail = 0
  local function ck(c, m) if quiet then if not c then qfail = qfail + 1 end else check(c, m) end end
  local by = {}
  for _, r in ipairs(vars) do by[r.id] = r end

  -- §1 règle de coût
  local rule_ok = true
  for i = 2, Ro.PLAN_COUNT do
    local r = Ro.ROBOTS[i]
    if not r.is_giant and not r.heal and r.id ~= "bellwether" then
      local m = Vm.mu(r.class, r.age)
      if math.abs(m - r.mu) / r.mu > 0.02 then rule_ok = false end
    end
  end
  ck(rule_ok and Vm.mu("P", 3) == 200, "§1 V.mu = secondes de la classe × débit de fin d'âge : le but des robots du plan à ±2 %, plancher 200")
  ck(Vm.prime(1) == 1 and Vm.prime(0.8) == 1 and math.abs(Vm.prime(1.6) - 2.56) < 1e-9, "§1 prime de vitesse : (v ÷ v du parent)², jamais une remise")
  for _, s in ipairs(Vm.SPECS) do
    local r = by[s.id]
    ck(r ~= nil and r.mu == Vm.cost(s), "§1 " .. s.id .. " : but = V.cost")
    if r then
      local c = cost(r.ingredients)
      ck(c / r.mu >= 0.8 and c / r.mu <= 1.2, "§1 " .. s.id .. string.format(" : recette %.0f MU contre un but de %d (±20 %%)", c, r.mu))
      local seen, worst, dup = {}, 0, false
      for _, g in ipairs(r.ingredients) do
        worst = math.max(worst, g[2])
        if seen[g[1]] then dup = true end
        seen[g[1]] = true
      end
      ck(worst <= 100 and not dup, "§1 " .. s.id .. " : au plus 100 de chaque ingrédient, aucun doublon")
    end
  end
  ck(by.mender and by.mender.mu == 290 and by.skitter and by.skitter.mu == 870 and by.lancer and by.lancer.mu == 4100,
    "§1 buts livrés : Rafistoleur 290, Furet 870 (340 × 1,6² : prime de vitesse), Perce-Blindage 4 100 MU")

  -- §2 dérivation
  local again = Vm.build(Ro.robot)
  local same = #again == #vars
  for i, r in ipairs(again) do
    local o = vars[i]
    if not o or r.id ~= o.id or r.hp ~= o.hp or r.shot.damage ~= o.shot.damage or r.shot.cooldown ~= o.shot.cooldown or r.range ~= o.range
        or r.speed ~= o.speed or r.mu ~= o.mu then same = false end
  end
  ck(same, "§2 dérivation pure : mêmes entrées, même sortie")
  local tr, ne, be = Ro.robot("steam-trotter"), Ro.robot("needle"), Ro.robot("bellwether")
  local sk, la, me = by.skitter, by.lancer, by.mender
  ck(sk and sk.speed == 0.224 and sk.range == 22 and sk.shot.cooldown == 20 and sk.hp0 == 540 and sk.dmg0 == 20 and sk.class == "P",
    "§2 Furet : 1,6 × la vitesse du Trotte-Vapeur (0,224), portée 22, cadence 20, forme 540 / 20")
  ck(la and la.range == 42 and la.shot.cooldown == 150 and la.dmg0 == 3000 and la.hp0 == 3200 and la.speed == 0.08 and la.dtype == "physical",
    "§2 Perce-Blindage : portée 42, cadence 150, forme 3 200 / 3 000 (Aiguille × 0,8 / × 2,5), physique, 0,08")
  ck(me and me.heal and me.heal.radius == 8 and me.heal.max == 6 and me.shot.damage == 0 and me.dps == 0 and me.range == 8 and me.class == "P",
    "§2 Rafistoleur : soin rayon 8, 6 cibles au plus, aucun dégât, portée 8, petit")
  ck(sk and sk.speed < Ro.robot("finback").speed and sk.speed > tr.speed, "§2 le Furet reste plus lent que l'Aileron (âge 11), plus vif que tout robot de son âge")
  ck(la and la.range > ne.range and la.range <= 45 and me and me.heal.radius < be.heal.radius and me.heal.max < be.heal.max,
    "§2 rangs de parenté : Perce-Blindage plus loin que l'Aiguille (≤ 45) ; Rafistoleur plus court et moins de cibles que la Cloche")

  -- §3 calibrage
  local cal = D.calibrate_all(vars)
  for _, r in ipairs(vars) do
    local c = cal[r.id]
    ck(c.hp == r.hp, "§3 PV écrits = PV calibrés : " .. r.id .. " (" .. tostring(r.hp) .. " contre " .. tostring(c.hp) .. ")")
    if r.heal then ck(c.heal == r.heal.amount, "§3 soin écrit = soin calibré : " .. r.id)
    else ck(c.damage == r.shot.damage, "§3 dégâts écrits = dégâts calibrés : " .. r.id .. " (" .. tostring(r.shot.damage) .. " contre " .. tostring(c.damage) .. ")") end
    ck(c.tier == D.tier_of_age(r.age), "§3 palier du duel = palier de l'âge : " .. r.id)
  end

  -- §4 rôles lus aux nombres
  local function cand(r)
    return { item = r.kit, hp = r.hp, dps = r.dps, range = r.range, min_range = r.min_range, zone = r.area, points = r.points, cost = r.mu, usable = true }
  end
  ck(me and Rb.kind(cand(me)) == "soutien" and sk and Rb.kind(cand(sk)) == "ligne" and la and Rb.kind(cand(la)) == "ligne",
    "§4 le cerveau lit : Rafistoleur = soutien (DPS 0), Furet et Perce-Blindage = ligne (aucune portée minimale)")

  -- §5 rang parmi les unités non géantes
  local units = {}
  for _, r in ipairs(Ro.ROBOTS) do if not r.is_giant then units[#units + 1] = r end end
  for _, r in ipairs(vars) do
    local found = false
    for _, u in ipairs(units) do if u.id == r.id then found = true end end
    if not found then units[#units + 1] = r end
  end
  local function rank(id, key)
    local list = {}
    for i, u in ipairs(units) do list[#list + 1] = { id = u.id, v = key(u), i = i } end
    table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.i < b.i end)
    for k, e in ipairs(list) do if e.id == id then return k end end
  end
  local HPC = function(u) return u.hp / u.mu end
  local DPC = function(u) return u.dps / u.mu end
  local RNG = function(u) return u.range end
  local SPD = function(u) return u.speed end
  -- rangs figés (1 = premier sur 12) : PV / coût, DPS / coût, portée, vitesse
  local WANT = { mender = { 4, 12, 12, 5 }, skitter = { 9, 8, 6, 2 }, lancer = { 11, 1, 2, 11 } }
  for _, r in ipairs(vars) do
    local got = { rank(r.id, HPC), rank(r.id, DPC), rank(r.id, RNG), rank(r.id, SPD) }
    local w = WANT[r.id] or {}
    ck(#units == 12 and got[1] == w[1] and got[2] == w[2] and got[3] == w[3] and got[4] == w[4],
      "§5 rang de " .. r.id .. " sur " .. #units .. " (PV/coût, DPS/coût, portée, vitesse) : " .. table.concat(got, ", ")
      .. " contre " .. table.concat(w, ", "))
  end

  -- §6 frappe lourde contre une rafale de même DPS
  if la then
    local twin = {}
    for k, v in pairs(la) do twin[k] = v end
    twin.shot = { damage = la.shot.damage * 60 / la.shot.cooldown, cooldown = 60 }
    local a4 = D.run(la, la.hp, la.shot.damage, 4, nil, "armored")
    local w4 = D.run(twin, twin.hp, twin.shot.damage, 4, nil, "armored")
    local a5 = D.run(la, la.hp, la.shot.damage, 5)
    local w5 = D.run(twin, twin.hp, twin.shot.damage, 5)
    ck(a4.win and w4.win and a4.fraction_subject > w4.fraction_subject, "§6 contre 3 blindés du palier 4 : la frappe lourde garde plus de PV"
      .. string.format(" (%.3f contre %.3f)", a4.fraction_subject, w4.fraction_subject))
    ck(a5.win and not w5.win, "§6 palier 5 : la frappe lourde gagne, la rafale de même DPS perd (le premier coup part avant le contact)")
  end

  -- §7 choix du cerveau par âge (candidats lus aux données, aucun nom dans le cerveau)
  local function pick(age)
    local c = {}
    for _, u in ipairs(units) do if u.age <= age then c[#c + 1] = cand(u) end end
    local ch = Rb.choose(c, { have = {} })
    return ch and ch.item
  end
  ck(pick(4) == tr.kit and pick(5) == tr.kit and pick(6) == tr.kit, "§7 âges 4 à 6 : le Trotte-Vapeur reste le choix (Furet : niche, prime de vitesse)")
  ck(pick(7) == ne.kit and la and pick(8) == la.kit, "§7 âge 7 : l'Aiguille ; âge 8 : le Perce-Blindage la remplace (valeur ÷ coût 1,42 contre 1,02)")

  return qfail
end

if arg and arg[1] == "--table" then
  print(string.format("%-14s %3s %2s %7s %8s %8s %4s %6s %6s", "robot", "âge", "cl", "MU", "PV/MU", "DPS/MU", "port", "vit", "score"))
  for _, r in ipairs(Ro.ROBOTS) do
    if not r.is_giant then
      local u = { item = r.kit, hp = r.hp, dps = r.dps, range = r.range, min_range = r.min_range, cost = r.mu }
      print(string.format("%-14s %3d %2s %7d %8.2f %8.3f %4d %6.3f %6.3f%s", r.id, r.age, r.class, r.mu, r.hp / r.mu, r.dps / r.mu, r.range, r.speed,
        Rb.score(u), r.variant and ("  variante de " .. r.variant) or ""))
    end
  end
  os.exit(0)
end

suite(V, VAR)

-- §8 visuel, technologies, usines
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local SPR = read("graphics/robots/sprites.lua")
for _, r in ipairs(VAR) do
  local key = r.look.sheet:find("-", 1, true) and ('["' .. r.look.sheet .. '"] = {') or ("  " .. r.look.sheet .. " = {")
  check(SPR:find(key, 1, true) ~= nil and r.look.scale > 0.5 and r.look.scale < 1.5 and r.look.tint ~= nil,
    "§8 " .. r.id .. " : feuille du parent " .. r.look.sheet .. ", échelle " .. r.look.scale .. ", teinte")
  check(Ro.factory(r.factory) and Ro.factory(r.factory).age <= r.age, "§8 " .. r.id .. " : son usine arrive au plus tard à son âge")
  local t
  for _, x in ipairs(Ro.TECHS) do for _, id in ipairs(x.robots or {}) do if id == r.id then t = x end end end
  check(t and t.epoch == r.age and #Ro.tech_unlocks(t) == 1 and Ro.tech_unlocks(t)[1] == r.recipe, "§8 " .. r.id .. " : une technologie de son âge, qui n'ouvre que lui")
  local pre_ok = t ~= nil
  for _, pre in ipairs(t and t.prerequisites or {}) do
    local pt = Ro.tech(pre)
    if not pt or pt.epoch > t.epoch then pre_ok = false end
  end
  check(pre_ok, "§8 " .. r.id .. " : prérequis du lot, d'un âge antérieur ou égal")
end
-- s43-robots2 : le Furet se distingue du Trotte-Vapeur à l'œil (capture du 14/11 : teinte claire et 0,85 indiscernables) : nettement plus
-- petit, corps teinté bleu (le parent est laiton : rouge dominant), écart de teinte d'au moins 0,5 sur le bleu et sur le rouge.
do
  local sk = Ro.robot("skitter")
  local t = sk and sk.look.tint
  check(sk and sk.look.scale <= 0.75 and t and t.b - t.r >= 0.5, "§8 Furet distinct du Trotte-Vapeur : échelle " .. tostring(sk and sk.look.scale)
    .. " (≤ 0,75), teinte bleue (b − r ≥ 0,5)")
end
check(#VAR == 3 and Ro.PLAN_COUNT == 12 and Ro.ROBOTS[12].id == "crowned" and Ro.ROBOTS[13].id == "mender", "§8 les 12 du plan d'abord (indices inchangés), puis les 3 variantes")
local P = read("prototypes/robots.lua")
check(P:find("SPR[r.look and r.look.sheet or r.id]", 1, true) ~= nil and P:find('both(body, "tint", rgba(look.tint))', 1, true) ~= nil,
  "§8 prototypes/robots.lua : la variante prend la feuille du parent, corps teinté")
-- aucun nom de variante dans le cerveau
for _, path in ipairs({ "shared/ai3/robots.lua", "shared/ai3/catalogue.lua", "script/robots/faction.lua" }) do
  local ok, src = pcall(read, path)
  local clean = true
  if ok then for _, r in ipairs(VAR) do if src:find('"' .. r.id .. '"', 1, true) or src:find("-" .. r.id, 1, true) then clean = false end end end
  check(ok and clean, "§8 " .. path .. " : aucun nom de variante (identifiant cité ou suffixe d'un nom de prototype)")
end

-- §9 mutants : chaque règle faussée est vue
local function mutant(name, change)
  local Vm = {}
  for k, v in pairs(V) do Vm[k] = v end
  change(Vm)
  local ok, f = pcall(function() return suite(Vm, Vm.build(Ro.robot), true) end)
  local seen = (not ok) or f > 0
  check(seen, "§9 mutant refusé : " .. name)
  return seen
end
local function deep(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = deep(v) end return o end
local n, ok = 0, 0
local function M(name, change) n = n + 1 if mutant(name, change) then ok = ok + 1 end end
M("prime de vitesse oubliée", function(Vm) Vm.prime = function() return 1 end end)
M("prime de vitesse linéaire", function(Vm) Vm.prime = function(f) return math.max(1, f or 1) end end)
M("coût de classe P doublé", function(Vm) Vm.SECONDS = { P = 20, M = 20, G = 30 } end)
M("Furet calibré à la main", function(Vm) Vm.SPECS = deep(V.SPECS) Vm.SPECS[2].calibre.hp = 2000 end)
M("Perce-Blindage en rafale", function(Vm) Vm.SPECS = deep(V.SPECS) Vm.SPECS[3].f.cooldown = 1 Vm.SPECS[3].f.dmg0 = 1 end)
M("Rafistoleur qui tire", function(Vm) Vm.SPECS = deep(V.SPECS) Vm.SPECS[1].heal = nil Vm.SPECS[1].calibre.damage = 10 end)
M("Furet plus vif que l'Aileron", function(Vm) Vm.VITESSE_MAX = 1 Vm.SPECS = deep(V.SPECS) Vm.SPECS[2].f.speed = 2 end)
print(string.format("[S43-ROBOTS] mutants refusés : %d sur %d", ok, n))
print(string.format("[S43-ROBOTS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
