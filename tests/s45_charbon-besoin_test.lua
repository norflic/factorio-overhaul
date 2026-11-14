-- lot s45 charbon-besoin : besoin nominal du combustible (fours vides comptés), max(mesure, nominal).
package.path = "./?.lua;" .. package.path
local Bc = require("shared.team.bilan_charbon")
local ok, n = 0, 0
local function check(c, msg) n = n + 1; if c then ok = ok + 1 else print("ECHEC : " .. msg) end end
local S = { working = 1, no_fuel = 2, no_ingredients = 3, waiting_for_source_items = 4 }

check(Bc.consumer_counts("furnace", S.no_ingredients, S), "four vide compte")
check(Bc.consumer_counts("furnace", S.waiting_for_source_items, S), "four sans minerai compte")
check(Bc.consumer_counts("boiler", nil, S), "chaudiere compte")
check(Bc.consumer_counts("mining-drill", S.working, S), "foreuse active compte")
check(not Bc.consumer_counts("mining-drill", S.no_ingredients, S), "foreuse arretee ne compte pas")
-- 4 fours de 90 kW (dont 3 vides) + 1 chaudiere 1,8 MW, combustible 4 MJ
local nominal = Bc.cap({ 90e3, 90e3, 90e3, 90e3, 1.8e6 }, nil, 4e6).need
local measured = Bc.cap({ 90e3, 1.8e6 }, nil, 4e6).need
check(math.abs(nominal - 2.16e6 / 4e6) < 1e-9, "nominal = somme / fuel_value")
check(Bc.need(measured, nominal) == nominal, "max retient le nominal")
check(Bc.need(0.9, 0.5) == 0.9, "max retient la mesure si plus haute")
check(Bc.need(nil, nil) == 0, "rien = 0")
-- le plafond s'ouvre : 0,3 objet/s extrait suffit a la mesure (0,47) ? non ; au nominal (0,54) avec 0,5 extrait : place
check(Bc.room({ need = Bc.need(0.45, nominal), capacity = 0.5 }), "nominal ouvre une foreuse de plus")
check(not Bc.room({ need = 0.45, capacity = 0.5 }), "mesure seule la refusait")
print(string.format("s45 charbon-besoin : %d/%d OK", ok, n))
if ok ~= n then os.exit(1) end
