--[[
  Lot COLLECTE : colle script/team/rappel_urgent.lua (Rp.stops) sur un tableau, un registre et des PNJ simulés (modules du jeu remplacés par des
  doublures : Board, Registry, State). Usage : lua5.2 tests/rappel_urgent_glue_test.lua
]]
package.path = "./?.lua;" .. package.path
local logs = {}
log = function(m) logs[#logs + 1] = m end

local agents = {}
package.loaded["script.companion.registry"] = { get = function(id) return agents[id] end }
package.loaded["script.faction.state"] = { sorted_keys = function(t)
  local k = {}
  for key in pairs(t) do k[#k + 1] = key end
  table.sort(k)
  return k
end }
local tasks_list = {}
package.loaded["script.team.board"] = { get = function() return { list = tasks_list } end, prenable = function(_, t) return t.prenable ~= false end }

local Rp = require("script.team.rappel_urgent")
local passes, failures = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end

local function ent(x, y) return { valid = true, position = { x = x, y = y } } end
local f = { key = "player", hq_pos = { x = 0, y = 0 }, stats = {}, team = {}, engineers = { [1] = true, [2] = true } }
agents[1] = { entity = ent(-50, -50), task = { kind = "explore", key = "ai3f:tour:1" } }
agents[2] = { entity = ent(-50, 40), task = { kind = "mine", key = "ia3:mine:stone:2", prio = 70 } }
tasks_list[1] = { key = "ia1d:1:o:1", kind = "carry", prio = 94, created = 99000, ia1d = { ax = 75, ay = 0 } }

local r = Rp.stops(f, 100000)
check(#r == 1 and r[1] == agents[2], "collecte : le minage de pierre est rappelé, l'exploration reste")
check(f.team.rappel_at == 100000 and f.stats.rappels == 1, "date et compte du rappel notés")
check(#logs == 1 and logs[1]:find("ia1d:1:o:1", 1, true) and logs[1]:find("PNJ 2", 1, true) and logs[1]:find("ia3:mine:stone:2", 1, true),
  "une ligne de journal nomme la tâche urgente, le PNJ rappelé et sa tâche abandonnée")
check(#Rp.stops(f, 100000 + 600) == 0, "30 s de pause : pas de second rappel 600 ticks après")
check(#Rp.stops(f, 100000 + 1800) == 1, "30 s écoulées : le rappel est de nouveau permis")

agents[2].task.defend = true
f.team.rappel_at = nil
r = Rp.stops(f, 200000)
check(#r == 1 and r[1] == agents[1], "PNJ 2 en défense : seul l'éclaireur reste rappelable")
agents[1].task.kind = "garrison"
check(#Rp.stops(f, 300000) == 0, "tous en défense : personne")
agents[1].task.kind = "explore"
agents[2].task = nil
check(#Rp.stops(f, 400000) == 0, "un PNJ libre prendra la tâche : aucun rappel")
agents[2].task = { kind = "mine", key = "m", prio = 70, defend = nil }
agents[2].failed = true
check(#Rp.stops(f, 500000) == 0, "un PNJ qui rentre après un échec compte comme libre")
agents[2].failed = nil
tasks_list[1].prenable = false
check(#Rp.stops(f, 600000) == 0, "tâche sans matière libre : aucun rappel inutile")
tasks_list[1].prenable = true
tasks_list[1].prio = 80
check(#Rp.stops(f, 700000) == 0, "sous 90 : pas une urgence")
print(string.format("[RAPPEL-GLUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
