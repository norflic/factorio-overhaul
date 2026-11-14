-- s50 centrale-75 : la croissance part quand la demande (max mesure, nominal installé) dépasse 75 % de la capacité finie, sauf manque
-- de charbon (chaudières à sec : signalé, pas de centrale). Lancement : lua5.2 "tests/s50_centrale-75_test.lua" (racine du mod).
package.path = "./?.lua;" .. package.path
local C = require("shared.team.centrale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- règle pure
check(C.grow_demand_load(7200, 30000, 7200) > 4, "7,2 MW produits, 30 MW installes sur 7,2 MW : charge > 1")
check(C.grow_demand_load(0, 6000, 7200) >= C.GROW_LOAD, "machines a l'arret (0 kW) : la demande nominale compte")
check(C.grow_demand_load(4000, 5000, 7200) < C.GROW_LOAD, "5 MW sur 7,2 MW : sous le seuil")
check(C.grow_demand_load(6000, 0, 7200) >= C.GROW_LOAD, "mesure seule au-dessus du seuil")
check(C.grow_demand_load(100, 100, 0) == nil, "sans capacite finie : nil")
check(C.grow_demand_load(0 / 0, math.huge, 7200) == 0, "entrees invalides : 0")

-- C.growth : charge au-dessus du seuil, une centrale finie, rien d'ouvert
local function n(extra)
  local t = { load = 4.2, done = 3, pending = 0, refused = 0, anticipate = true }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local nb, why = C.growth({ saturated = true, sat = 10 }, n())
check(nb ~= nil, "demande > 75 % : croissance demandee (" .. tostring(why) .. ")")
nb, why = C.growth({ saturated = true, sat = 10 }, n({ coal_short = true }))
check(nb == nil and why == C.COAL_REASON, "chaudieres a sec : retenue, cause charbon")
nb, why = C.growth({ saturated = true, sat = 10 }, n({ load = 0.5 }))
check(nb == nil and why == C.LOAD_REASON, "sous 75 % : bride F491 conservee")
nb, why = C.growth({ saturated = true, sat = 10 }, n({ coal_short = true, load = 0.5 }))
check(why == C.LOAD_REASON, "sous le seuil : raison de charge d'abord")

print(string.format("s50 centrale-75 : %d OK, %d ECHEC", passes, failures))
if failures > 0 then os.exit(1) end
