-- s51 poteaux : le tracé de poteaux (Fl.pole_route) passe par la garde globale des tracés (plafond d'états par tick, mémo d'échec).
package.path = "./?.lua;" .. package.path
local G = require("shared.team.route_garde")
local Fl = require("shared.ai3.fluides")
local ok, n = 0, 0
local function check(c, msg) n = n + 1 if c then ok = ok + 1 else print("ECHEC : " .. msg) end end
local a, b = { x = 316.5, y = 67.5 }, { x = 419.5, y = 196.5 }
local calls = 0
local open = function() calls = calls + 1 return true end
-- 165 tuiles, terrain libre : tracé trouvé, coût compté au tick
Fl.POLE_BOX, Fl.POLE_MEMO = { tick = -1, spent = 0 }, {}
local t0 = os.clock()
local p = Fl.pole_route_guarded(a, b, 7.5, open, Fl.POLE_ASTAR_MAX, 10)
local dt = os.clock() - t0
check(p and #p > 0, "trace libre trouve")
check(Fl.POLE_BOX.spent > 0 and Fl.POLE_BOX.spent <= Fl.POLE_ASTAR_MAX, "etats comptes au tick")
print(string.format("s51 : trace 165 tuiles libre %.4f s, %d etats, %d appels free", dt, Fl.POLE_BOX.spent, calls))
-- échec (mur infranchissable) : mémorisé, puis rappel au tick suivant SANS recherche
local wall = function(x, y) calls = calls + 1 return x < 360 or x > 380 end
Fl.POLE_BOX, Fl.POLE_MEMO = { tick = -1, spent = 0 }, {}
calls = 0
t0 = os.clock()
local q, why = Fl.pole_route_guarded(a, b, 7.5, wall, Fl.POLE_ASTAR_MAX, 20)
dt = os.clock() - t0
check(q == nil and why == "echec", "mur : echec")
print(string.format("s51 : echec (mur) %.4f s, %d appels free", dt, calls))
calls = 0
local q2, why2 = Fl.pole_route_guarded(a, b, 7.5, wall, Fl.POLE_ASTAR_MAX, 21)
check(q2 == nil and why2 == "attente" and calls == 0, "rappel au tick suivant : attente, aucune recherche")
check(not G.blocked(Fl.POLE_MEMO, G.pair_key(a, b), 20 + G.BASE), "attente bornee : reessai apres BASE ticks")
-- plafond global du tick : épuisé par les tapis ou d'autres lignes, plus aucun état développé ce tick
Fl.POLE_BOX, Fl.POLE_MEMO = { tick = 30, spent = G.TICK_MAX }, {}
calls = 0
local r, why3 = Fl.pole_route_guarded(a, b, 7.5, open, Fl.POLE_ASTAR_MAX, 30)
check(r == nil and why3 == "budget" and calls == 0, "plafond du tick epuise : aucune recherche")
check(next(Fl.POLE_MEMO) == nil, "plafond du tick : pas un echec memorise")
local r2 = Fl.pole_route_guarded(a, b, 7.5, open, Fl.POLE_ASTAR_MAX, 31)
check(r2 and #r2 > 0, "tick suivant : compteur remis a zero, trace trouve")
print(string.format("s51_poteaux : %d/%d", ok, n))
if ok ~= n then error("s51_poteaux en echec") end
return ok == n
