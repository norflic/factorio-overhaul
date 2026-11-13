--[[
  Lot s41 energie (DC, 13/11 : « la centrale sature dès que les fours tournent ») : la centrale se dimensionne sur la demande
  S.demand = max(production mesurée, S.DRAW × puissance installée des consommateurs finis), plus sur la seule mesure.
  Usage, depuis la racine du mod :   lua5.2 tests/s41_energie_test.lua
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
_G.log = function() end
_G.game = { tick = 0 }
package.loaded["script.team.stock"] = { count = function(f) return f.stock or 0 end }
local S = require("shared.team.sante_centrale")
local C = require("shared.team.centrale")
local Sante = dofile("script/team/sante_centrale.lua")

-- 1. règle pure
check(S.demand(900, 0) == 900 and S.demand(900, nil) == 900, "sans puissance installee : la mesure")
check(S.demand(0, 2000) == S.DRAW * 2000, "machines a l'arret : la puissance installee a S.DRAW")
check(S.demand(1500, 2000) == 1500, "mesure au-dessus : la mesure")
check(S.demand(nil, nil) == 0 and S.demand(-5, -5) == 0 and S.demand(0 / 0, math.huge) == 0, "entrees invalides : 0")

-- 2. puissance installee : consommateurs finis seulement, jamais une centrale ni un chantier
local function team(cap_j)
  return { key = "azure", force = "fo-azure", build = { order = {}, projects = {}, grow = { capacity = cap_j, power = 0 } } }
end
local function add(f, p) f.build.projects[p.id] = p; f.build.order[#f.build.order + 1] = p.id end
local f = team(30000) -- 1800 kW
add(f, { id = 1, state = "fini", power_kw = 9999 }) -- la centrale
add(f, { id = 2, state = "fini", power_kw = 1000 })
add(f, { id = 3, state = "chantier", power_kw = 500, admitted = true })
add(f, { id = 4, state = "fini", power_kw = 700, abandoned = true })
add(f, { id = 5, state = "fini" })
add(f, { id = 6, state = "fini", power_kw = 9999 }) -- centrale de plus
f.build.plant, f.build.extra_plants = 1, { 6 }
check(Sante.installed(f) == 1000, "installee = consommateurs finis, ni centrale, ni chantier, ni abandon (lu " .. tostring(Sante.installed(f)) .. ")")

-- 3. croissance : 0 kW mesure, machines posees a l'arret -> la demande les compte et l'avance part
local fin = { id = 1, state = "fini", ents = {} }
local ant, _, used, comm, cap = Sante.growth(f, 100, { fin }, 0, 30000)
check(used == S.DRAW * 1000 and comm == 500 and cap == 1800, "demande = S.DRAW x installee (lu " .. tostring(used) .. ")")
check(ant == false, "600 + 300 < 70 % de 1800 : pas d'avance")
add(f, { id = 7, state = "fini", power_kw = 1000 })
for _ = 1, S.ANTICIPATE_CHECKS do ant, _, used = Sante.growth(f, 100, { fin }, 0, 30000) end
check(ant == true and used == S.DRAW * 2000, "1200 + 300 >= 70 % de 1800, 30 s de suite : avance, sans un kW mesure")
-- la porte de la demande mesuree (C.GROW_LOAD) lit la meme demande (plant_arms)
local load = C.grow_load(math.max(0, used * 1000 / 60), 30000, 0)
check(load ~= nil and load < C.GROW_LOAD, "1200 / 1800 : sous la porte, rien de plus")
add(f, { id = 8, state = "fini", power_kw = 500 })
_, _, used = Sante.growth(f, 100, { fin }, 0, 30000)
check(C.grow_load(used * 1000 / 60, 30000, 0) >= C.GROW_LOAD, "1500 / 1800 : la porte passe")
check(C.grow_load(used * 1000 / 60, 30000, 30000) < C.GROW_LOAD, "une centrale neuve en chantier compte : pas de seconde demande")
-- la mesure garde la main quand elle est au-dessus
_, _, used = Sante.growth(f, 100, { fin }, 29000, 30000)
check(used == 1740, "mesure au-dessus de l'installee : la mesure")
-- regle coupee : rien
f.build.opts = { no_sante = true }
ant, _, used = Sante.growth(f, 100, { fin }, 0, 30000)
check(ant == false and used == 0, "no_sante : pas d'avance")

-- 4. chaine statique : PA.watch donne la demande a la porte
local src = io.open("script/team/plant_arms.lua"):read("*a")
check(src:find("C.grow_load(math.max(power + reopened_power, (used_kw or 0) * 1000 / 60)", 1, true) ~= nil, "plant_arms : la porte lit la demande")

print(string.format("s41_energie_test : %d OK, %d echec(s)", passes, failures))
os.exit(failures == 0 and 0 or 1)
