--[[
  Lot ADOPTE (plafond seul) : un agrandissement d'avant-poste ne demande jamais plus de paires que de places restantes.
  Lancement : lua5.2 tests/plafond_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local P = require("shared.ai3.projets")
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local book = {}
book.handcraftable = function() return true end
book.plan = function(_, list, avail)
  local a = {}
  for k, v in pairs(avail or {}) do a[k] = v end
  local uses = {}
  for _, it in ipairs(list) do a[it[1]] = math.max(0, (a[it[1]] or 0) - it[2]); uses[it[1]] = it[2] end
  return { raw = {}, crafts = { { energy = 1 } }, uses = uses, avail = a }
end
local function run(drills, avail)
  local view = { pending = {}, sites = { iron = 0 }, outposts = { { id = 1, kind = "iron", drills = drills } }, open = {} }
  local E = P.context(avail or {}, book, view, {})
  local proj = { id = 1, key = "extraction:iron", prio = 60, goal = { kind = "outpost", outpost = "iron" }, missing = {} }
  P.EMIT.outpost(E, proj, proj.goal, {})
  local n = 0
  for _, t in ipairs(E.tasks) do if t.kind == "craft" and t.item == T.DRILL then n = n + t.count end end
  return E, n
end
local spec = T.outposts.iron
local _, n_full = run(4)
check(n_full == spec.drills, "avant-poste à 4 foreuses : le lot entier (" .. n_full .. ")")
local _, n3 = run(T.max_drills("iron") - 3)
check(n3 == 3, "3 places restantes : 3 foreuses, pas " .. spec.drills .. " (" .. n3 .. ")")
local _, n1 = run(T.max_drills("iron") - 1)
check(n1 == 1, "1 place restante : 1 foreuse (" .. n1 .. ")")
local E, n = run(T.max_drills("iron") - 3, { [T.DRILL] = 3, [T.outposts.iron.sink] = 3, [T.fuel] = 500 })
local took
for _, t in ipairs(E.tasks) do if t.kind == "extend" then took = t end end
check(took and took.items[1][2] == 3 and n == 0, "3 foreuses et 3 réceptacles au stock : l'agrandissement part avec 3 paires, rien n'est fabriqué")
print(string.format("[PLAFOND] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
