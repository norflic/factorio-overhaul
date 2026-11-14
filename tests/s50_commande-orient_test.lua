-- s50 commande-orient : « Amélioration » met le remplacement devant (Co.upgrade_goal). lua5.2 tests/s50_commande-orient_test.lua
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")
local n = 0
local function ok(c, m) assert(c, m); n = n + 1 end
local rep = { key = "capital:x", value = 48, replace = true }
local g = Co.upgrade_goal(rep, "amelioration")
ok(g.front == true and g.value == Co.UPGRADE_VALUE, "remplacement releve")
ok(rep.front == nil and rep.value == 48, "cache intact")
ok(Co.upgrade_goal(rep, "aucune") == rep, "aucune : inchange")
ok(Co.upgrade_goal(rep, nil) == rep, "nil : inchange")
ok(Co.upgrade_goal(rep, "defense") == rep, "defense : inchange")
local bl = Co.upgrade_goal({ value = 30, bloc = "p1", n = 3 }, "amelioration")
ok(bl.front and bl.value == 60 and bl.n == 3, "bloc releve")
local hi = Co.upgrade_goal({ value = 80, replace = true }, "amelioration")
ok(hi.value == 80, "valeur haute gardee")
local c = { value = 40, center = true, replace = true }
ok(Co.upgrade_goal(c, "amelioration") == c, "centre jamais releve")
local p = { value = 40 }
ok(Co.upgrade_goal(p, "amelioration") == p, "pose ordinaire inchangee")
ok(Co.upgrade_goal(nil, "amelioration") == nil, "nil")
ok(Co.UPGRADE_VALUE > 55 and Co.UPGRADE_VALUE < Co.ORDER_VALUE, "borne")
print("s50 commande-orient : " .. n .. " OK")
