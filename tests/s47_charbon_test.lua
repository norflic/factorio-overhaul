-- s47 : coupe du tracé de charbon en échec (plafond d'états ROUTE_STATES, refus immédiat au-delà de ROUTE_MAX en Manhattan).
-- Lancement : lua5.2 tests/s47_charbon_test.lua (depuis la racine du mod).
package.path = "./?.lua;" .. package.path
local Co = dofile("shared/team/champ_colonne.lua")
local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end
check(Co.ROUTE_STATES and Co.ROUTE_STATES < Co.ROUTE_CAP, "ROUTE_STATES sous ROUTE_CAP")
check(Co.ROUTE_STATES >= 40 * Co.ROUTE_MAX, "ROUTE_STATES borné par un multiple large de ROUTE_MAX (0.7.107 : 48 x, tracés valides de champ_colonne_test gardés)")
-- échec coûteux : un mur quasi fermé (passage en zigzag) dans une grande boîte, l'arrivée dans une poche sans entrée
Co.PREUVE = false
local box = { u0 = 0, v0 = 0, u1 = 400, v1 = 400 }
local function free(u, v) return not (u >= 300 and u <= 310 and v >= 300 and v <= 310 and not (u == 305 and v == 305)) end
local span = function() return true end
local s, t = { u = 10, v = 10 }, { u = 305, v = 305 }
local t0 = os.clock(); local r1, w1 = Co.route(s, 1, t, 1, free, span, nil, box, Co.ROUTE_CAP); local a = os.clock() - t0
t0 = os.clock(); local r2, w2 = Co.route(s, 1, t, 1, free, span, nil, box, Co.ROUTE_STATES); local b = os.clock() - t0
print(string.format("  echec : avant %.3f s (%s) -> apres %.3f s (%s)", a, tostring(w1), b, tostring(w2)))
check(r1 == nil and r2 == nil, "les deux échouent")
check(b <= a, "plus rapide")
-- un tracé court réussit toujours sous le plafond
local r3 = Co.route({ u = 10, v = 10 }, 1, { u = 60, v = 40 }, 1, function() return true end, span, nil, box, Co.ROUTE_STATES)
check(r3 ~= nil and #r3 <= Co.ROUTE_MAX, "tracé court réussi sous ROUTE_STATES")
-- garde Manhattan présente avant l'appel
local SRC = io.open("shared/team/champ_colonne.lua"):read("*a")
check(SRC:find("if man + 1 > Co.ROUTE_MAX then", 1, true) ~= nil, "refus Manhattan avant la recherche")
print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
