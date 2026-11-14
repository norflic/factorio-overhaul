--[[
  Sprint s43 (cc-garde) : les deux entrées de combustible (lot s42 charbon-centrale) sans sa gêne (shared/team/charbon_centrale.lua).
    1. Cc.second_ok : seconde entrée seulement avec une centrale finie, un réseau sain et Cc.SECOND_COAL charbons au stock ;
    2. Cc.refill : planchers Cc.MIN_LOW / Cc.MIN_FILL par centrale, partagés entre ses coffres (deux coffres : 200 + 200, pas 400 + 400) ;
       un coffre : la règle d'avant ; au-dessus des planchers, la consommation décide comme avant ;
    3. MUTANT : planchers non partagés : vu.
  Usage : lua5.2 tests/s43_cc-garde_test.lua
]]
package.path = "./?.lua;" .. package.path
local Cc = require("shared.team.charbon_centrale")
local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
check(Cc.second_ok({ plants_done = 0, healthy = true, coal = 5000 }) == false, "1. premiere centrale : une seule entree")
check(Cc.second_ok({ plants_done = 1, healthy = false, coal = 5000 }) == false, "1. reseau malade : une seule entree")
check(Cc.second_ok({ plants_done = 1, healthy = true, coal = Cc.SECOND_COAL - 1 }) == (Cc.SECOND_COAL <= 0), "1. charbon sous le seuil : une seule entree (seuil nul : sans objet)")
check(Cc.second_ok({ plants_done = 1, healthy = true, coal = Cc.SECOND_COAL }) == true, "1. centrale finie, reseau sain, charbon : deux entrees")
check(Cc.second_ok(nil) == false, "1. sans relevé : une seule entree")
local one = Cc.refill(0, 0.01, 1000, nil, false)
local two = Cc.refill(0, 0.005, 1000, nil, false, 2)
check(one.target == Cc.MIN_FILL and one.low == Cc.MIN_LOW, "2. un coffre : planchers d'avant")
check(two.target == math.ceil(Cc.MIN_FILL / 2) and two.low == math.ceil(Cc.MIN_LOW / 2), "2. deux coffres : planchers partages (" .. two.target .. ", " .. two.low .. ")")
local big = Cc.refill(0, 1.0, 5000, nil, false, 2)
check(big.target == math.ceil(1.0 * Cc.FILL_S), "2. consommation forte : la consommation decide")
local src = assert(io.open("shared/team/charbon_centrale.lua", "rb")):read("*a")
local mut = src:gsub("math%.ceil%(Cc%.MIN_FILL / share%)", "Cc.MIN_FILL", 1)
local Cm = assert(load(mut, "=cc-mutant", "t"))()
check(Cm.refill(0, 0.005, 1000, nil, false, 2).target == Cc.MIN_FILL, "3. MUTANT planchers non partages : vu")
print(string.format("[S43-CC-GARDE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
