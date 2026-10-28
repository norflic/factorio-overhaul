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
-- Lots partiels : le lot de 8 paires du fer n'est pas servi (plaques insuffisantes) : le projet vise le plus grand lot servi.
do
  local plates = 90
  local pbook = {}
  pbook.handcraftable = function(_, item) return item == T.DRILL or item == T.outposts.iron.sink end
  pbook.plan = function(_, list, avail)
    local a = {}
    for k, v in pairs(avail or {}) do a[k] = v end
    local need, uses = 0, {}
    for _, it in ipairs(list) do need = need + it[2] * 9; uses[it[1]] = it[2] end
    local raw = {}
    local have = a["iron-plate"] or 0
    if need > have then raw["iron-plate"] = need - have end
    a["iron-plate"] = math.max(0, have - need)
    return { raw = raw, crafts = { { energy = 1 } }, uses = uses, avail = a }
  end
  local function runp(avail_plates, lethal)
    local view = { pending = {}, sites = { iron = 0 }, outposts = { { id = 1, kind = "iron", drills = 4 } }, open = {} }
    local E = P.context({ ["iron-plate"] = avail_plates, [T.fuel] = 500 }, pbook, view, {})
    local proj = { id = 1, key = "extraction:iron", prio = 60, goal = { kind = "outpost", outpost = "iron" }, missing = {} }
    local st = P.EMIT.outpost(E, proj, proj.goal, {})
    return E, proj, st
  end
  local E, proj, st = runp(90)
  check(st == "matiere" and proj.branch == "extend-partiel" and crafted(E, T.DRILL) == 5,
    "plaques pour 5 paires : le lot visé est de 5 paires, pas 8 (" .. crafted(E, T.DRILL) .. " foreuses, branche " .. tostring(proj.branch) .. ")")
  local E2, proj2 = runp(20)
  check(crafted(E2, T.DRILL) <= P.MIN_LOT, "plaques pour moins d'une paire : au plus un lot minimal fabriqué (" .. crafted(E2, T.DRILL) .. " foreuses)")
  local E3, proj3 = runp(100000)
  check(proj3.branch == "extend" and crafted(E3, T.DRILL) == 8, "plaques en abondance : le lot entier de 8 paires, comme avant")
  -- places restantes de l'avant-poste : jamais plus de paires que de places (12 foreuses au plus, il en a 11)
  local view = { pending = {}, sites = { iron = 0 }, outposts = { { id = 1, kind = "iron", drills = T.max_drills("iron") - 3 } }, open = {} }
  local E4 = P.context({ ["iron-plate"] = 100000, [T.fuel] = 500 }, pbook, view, {})
  local proj4 = { id = 1, key = "extraction:iron", prio = 60, goal = { kind = "outpost", outpost = "iron" }, missing = {} }
  P.EMIT.outpost(E4, proj4, proj4.goal, {})
  check(crafted(E4, T.DRILL) == 3, "3 places restantes : 3 paires visées, pas 8 (" .. crafted(E4, T.DRILL) .. ")")
  -- lot déjà au stock : pris tel quel
  local view5 = { pending = {}, sites = { iron = 0 }, outposts = { { id = 1, kind = "iron", drills = 4 } }, open = {} }
  local E5 = P.context({ [T.DRILL] = 5, [T.outposts.iron.sink] = 5, [T.fuel] = 500, ["iron-plate"] = 0 }, pbook, view5, {})
  local proj5 = { id = 1, key = "extraction:iron", prio = 60, goal = { kind = "outpost", outpost = "iron" }, missing = {} }
  local st5 = P.EMIT.outpost(E5, proj5, proj5.goal, {})
  local took = nil
  for _, t in ipairs(E5.tasks) do if t.kind == "extend" then took = t end end
  check(st5 == "ok" and took and took.items[1][2] == 5, "5 foreuses et 5 réceptacles au stock : l'agrandissement part tout de suite avec 5 paires (au lieu d'attendre 45 min)")
end
print(string.format("[AHEAD] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
