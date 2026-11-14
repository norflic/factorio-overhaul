--[[
  Sprint s44, « fours-acier » : la pièce d'un remplacement de FOUR (type d'entité lu au prototype) est demandée UNE à la fois à la
  priorité forte (Cap.ahead_prio), les suivantes au rang du projet. Lancement : lua5.2 tests/s44_fours-acier_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end

local Cap = require("shared.ai3.capital")

-- t1 : la garde
check(Cap.furnace_first({ replace = true, furnace = true, unit = { { "x", 1 } }, fab = 3 }) == true, "t1 : four à remplacer")
check(Cap.furnace_first({ replace = true, unit = { { "x", 1 } }, fab = 3 }) == false, "t1 : tapis ou bras : rien ne change")
check(Cap.furnace_first({ replace = true, furnace = true }) == false, "t1 : sans pièce à fabriquer : rien")
check(Cap.furnace_first(nil) == false, "t1 : sans but")

-- t2 : la décision porte le drapeau (type du prototype, jamais un nom)
local d = { replace = { from = "a", to = "b", n = 1 }, furnace = true, key = "remplacer:k", cost = { { "b", 1 } } }
local g = Cap.goal(d, nil)
check(g and g.furnace == true, "t2 : le but d'un remplacement de four est marqué")
local g2 = Cap.goal({ replace = { from = "a", to = "b", n = 1 }, key = "remplacer:k2", cost = { { "b", 1 } } }, nil)
check(g2 and g2.furnace == nil, "t2 : remplacement ordinaire non marqué")

-- t3 : émission : une pièce à la priorité forte, le reste au rang du projet
local wants = {}
local P = {
  want = function(E, proj, cost, prio) wants[#wants + 1] = { n = cost[1][2], prio = prio } end,
  take = function() return false end,
  prio_of = function() return 90 end,
}
local E = { avail = {}, view = { workers_idle = 0 }, book = { plan = function() return { raw = {} } end } }
local emit = Cap.emit(P)
local res = emit(E, { prio = 10 }, { key = "capital:k", target = "k", cost = { { "b", 1 } }, replace = true, furnace = true,
  unit = { { "b", 1 } }, fab = 3, n = 1 })
check(res == "matiere", "t3 : non payé : matière demandée")
check(#wants == 2 and wants[1].n == 1 and wants[1].prio == 89, "t3 : une seule pièce à la priorité forte")
check(wants[2] and wants[2].n == 2 and wants[2].prio == 10, "t3 : les suivantes au rang du projet")

wants = {}
emit(E, { prio = 10 }, { key = "capital:k3", target = "k3", cost = { { "b", 1 } }, replace = true,
  unit = { { "b", 1 } }, fab = 3, n = 1 })
check(#wants == 1 and wants[1].n == 3 and wants[1].prio == 10, "t3 : sans four : demande inchangée")

print(string.format("s44_fours-acier : %d OK, %d ECHEC", passes, failures))
if failures > 0 then os.exit(1) end
