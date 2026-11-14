package.path = "./?.lua;" .. package.path
local G = require("shared.team.route_garde")
local ok, n = 0, 0
local function check(c, msg) n = n + 1 if c then ok = ok + 1 else print("ECHEC : " .. msg) end end
-- clé triée
check(G.pair_key({ x = 1, y = 2 }, { x = 5, y = 3 }) == G.pair_key({ x = 5, y = 3 }, { x = 1, y = 2 }), "cle triee")
-- attente exponentielle bornée
check(G.wait(1) == G.BASE, "wait 1")
check(G.wait(2) == 2 * G.BASE, "wait 2")
check(G.wait(3) == 4 * G.BASE, "wait 3")
check(G.wait(50) == G.CAP, "wait borne")
-- mémo
local memo, k = {}, G.pair_key({ x = 0, y = 0 }, { x = 9, y = 9 })
check(not G.blocked(memo, k, 0), "libre au depart")
G.fail(memo, k, 100)
check(G.blocked(memo, k, 100 + G.BASE - 1), "attente 1")
check(not G.blocked(memo, k, 100 + G.BASE), "fin attente 1")
G.fail(memo, k, 100 + G.BASE)
check(G.blocked(memo, k, 100 + 3 * G.BASE - 1) and memo[k].n == 2, "attente doublee")
G.success(memo, k)
check(memo[k] == nil, "succes efface")
-- purge bornée
local m2 = {}
for i = 1, G.MEMO_MAX + 5 do m2["k" .. i] = { n = 1, until_tick = 0 } end
G.fail(m2, "neuf", 10 * G.CAP)
local c = 0 for _ in pairs(m2) do c = c + 1 end
check(c == 1 and m2.neuf, "purge des echues")
-- plafond global par tick
local box = {}
check(G.tick_left(box, 5) == G.TICK_MAX, "tick neuf")
G.spend(box, 5, 1000); G.spend(box, 5, 2000)
check(G.tick_left(box, 5) == G.TICK_MAX - 3000, "cumul du tick")
check(G.tick_left(box, 6) == G.TICK_MAX, "remis a zero au tick suivant")
-- boucle
check(not G.has_loop({ { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 1, y = 1 } }), "trace simple")
check(G.has_loop({ { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 1, y = 1 }, { x = 0, y = 1 }, { x = 0, y = 0 } }), "boucle")
print(string.format("s45_astar-budget : %d/%d OK", ok, n))
if ok ~= n then os.exit(1) end
