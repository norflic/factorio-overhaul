--[[
  Lot ADOPTE (fours dormants à la source) : la fabrication D'AVANCE des projets d'extraction (shared/ai3/projets.lua, EMIT.outpost).
    - sans site viable, rien n'est fabriqué d'avance pour un type qui a déjà un avant-poste (le premier de son type : démarrage) ;
    - un avant-poste meurtrier (o.lethal) ou en attente (o.full) n'est pas agrandi : rien n'est fabriqué pour lui ;
    - avec un site viable ou un avant-poste agrandissable : la fabrication se fait comme avant ;
    - les tâches de fabrication portent la branche (build, extend, avance).
  Lancement : lua5.2 tests/ahead_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local P = require("shared.ai3.projets")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- Livre de recettes simulé : tout se fabrique à la main, sans matière brute manquante.
local book = {}
book.handcraftable = function() return true end
book.plan = function(_, list, avail)
  local a = {}
  for k, v in pairs(avail or {}) do a[k] = v end
  local uses = {}
  for _, it in ipairs(list) do
    a[it[1]] = math.max(0, (a[it[1]] or 0) - it[2])
    uses[it[1]] = it[2]
  end
  return { raw = {}, crafts = { { energy = 1 } }, uses = uses, avail = a }
end

local function run(view, ctx)
  local E = P.context({}, book, view, {})
  local proj = { id = 1, key = "extraction:iron", prio = 60, goal = { kind = "outpost", outpost = "iron" }, missing = {} }
  local status, cause = P.EMIT.outpost(E, proj, proj.goal, ctx or {})
  return E, proj, status, cause
end
local function crafted(E, item)
  local n = 0
  for _, t in ipairs(E.tasks) do if t.kind == "craft" and t.item == item then n = n + t.count end end
  return n
end

local base = { pending = {}, sites = { iron = 0 }, outposts = {}, open = {} }
do
  local E, proj, st, cause = run({ pending = {}, sites = { iron = 0 }, outposts = { { id = 1, kind = "iron", drills = 8, full = true } }, open = {} })
  check(st == "bloque" and cause == "site:iron" and crafted(E, T.SMELTER) == 0 and crafted(E, T.DRILL) == 0,
    "sans site viable, un type qui a déjà un avant-poste : rien n'est fabriqué d'avance (" .. crafted(E, T.SMELTER) .. ")")
end
do
  local E, proj, st = run({ pending = {}, sites = { iron = 0 }, outposts = {}, open = {} })
  check(st == "bloque" and crafted(E, T.SMELTER) > 0 and proj.branch == "avance",
    "aucun avant-poste de ce type : la préparation du démarrage reste (branche avance, " .. crafted(E, T.SMELTER) .. " fours)")
  local tagged = false
  for _, t in ipairs(E.tasks) do if t.kind == "craft" and t.branch == "avance" then tagged = true end end
  check(tagged, "les tâches de fabrication portent leur branche")
end
do
  local E, proj, st = run({ pending = {}, sites = { iron = 1 }, outposts = { { id = 1, kind = "iron", drills = 8, full = true } }, open = {} })
  check(st == "matiere" and crafted(E, T.SMELTER) > 0 and proj.branch == "build", "site viable : fabrication comme avant (branche build)")
end
do
  local view = { pending = {}, sites = { iron = 0 }, outposts = { { id = 1, kind = "iron", drills = 4 } }, open = {} }
  local E, proj, st = run(view)
  check(st == "matiere" and crafted(E, T.SMELTER) > 0 and proj.branch == "extend", "avant-poste agrandissable : fabrication comme avant (branche extend)")
  view.outposts[1].lethal = true
  local E2, _, st2, cause2 = run(view)
  check(st2 == "bloque" and crafted(E2, T.SMELTER) == 0 and crafted(E2, T.DRILL) == 0,
    "avant-poste meurtrier (o.lethal) : pas agrandi, rien fabriqué (" .. tostring(st2) .. ")")
  view.outposts[1].lethal, view.outposts[1].full = nil, true
  local E3, _, st3 = run(view)
  check(st3 == "bloque" and crafted(E3, T.SMELTER) == 0, "avant-poste en attente (o.full) : rien fabriqué")
end
print(string.format("[AHEAD] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
