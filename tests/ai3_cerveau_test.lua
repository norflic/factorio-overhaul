--[[
  Lot IA3-c « le cerveau par besoins » : banc HORS JEU des parties pures (shared/ai3/buts.lua, projets.lua,
  cerveau.lua). Lancement : lua5.2 tests/ai3_cerveau_test.lua (depuis la racine du mod).

  Sections :
    1. le CAS DU DC (25/10, 18 h 40 et 18 h 45) : votre équipe, « Objectif : Charbon — il manque : 62 Plaque de fer »,
       aucun four, pierre et charbon à foison, gisement de fer connu : l'ANCIEN cerveau ne fait rien pour le fer (défaut
       reproduit) ; le NOUVEAU fabrique des fours avec la pierre, mine le fer à plusieurs, fond, mène plusieurs projets,
       n'extrait plus la pierre ni le charbon saturés ; sans gisement de fer connu : « explorer » ;
    2. projets : K = 2 + ⌊PNJ ÷ 4⌋, inertie, un projet bloqué ne prend pas de place ;
    3. caractère : le technocrate met la recherche devant l'armée, le conquérant l'inverse (poids du chef) ;
    4. recherche (laboratoire du QG) : laboratoire et packs fabriqués ; recherche IMPAYABLE : aucun pack (K6) ; garde
       de l'économie (plancher de fer) ;
    5. déterminisme et état persistant (nombres, chaînes, tables : rien d'autre dans global) ;
    6. mutants : chaque règle retirée fait échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local S = require("shared.team.scale")
local B = require("shared.ai3.buts")
local P = require("shared.ai3.projets")
local C = require("shared.ai3.cerveau")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
    pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 10,
    workers_max = 30, workers_idle = 10, threatened = false, open = {}, workers_wanted = 10, no_research = true,
    ladder = T.player_ladder, hq_turrets = T.defend_hq, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function op(id, kind, drills, over)
  local o = { id = id, kind = kind, drills = drills, full = false, turrets = 1, coal_needed = 0, fuel_low = false,
    output = 50, idle_ticks = 0, has_task = false, has_fortify = false }
  for k, x in pairs(over or {}) do o[k] = x end
  return o
end
local function count(plan, pred)
  local n = 0
  for _, t in ipairs(plan.tasks) do if pred(t) then n = n + 1 end end
  return n
end
local function find(plan, pred)
  for _, t in ipairs(plan.tasks) do if pred(t) then return t end end
  return nil
end
local function sig(plan)
  local out = {}
  for _, t in ipairs(plan.tasks) do out[#out + 1] = t.key .. "@" .. tostring(t.prio) .. ":" .. tostring(t.count) end
  local m = {}
  for _, x in ipairs(plan.missing) do m[#m + 1] = x[1] .. "x" .. x[2] end
  return table.concat(out, ";") .. "|" .. table.concat(m, ",") .. "|" .. tostring(plan.goal)
end
local function deep_ok(t, seen)
  seen = seen or {}
  if seen[t] then return true end
  seen[t] = true
  for k, v in pairs(t) do
    local tk, tv = type(k), type(v)
    if tk ~= "string" and tk ~= "number" then return false end
    if tv == "table" then
      if getmetatable(v) ~= nil or not deep_ok(v, seen) then return false end
    elseif tv ~= "string" and tv ~= "number" and tv ~= "boolean" then return false end
  end
  return true
end

---------------------------------------------------------------------------------------------------
section("1. Le cas du DC : « Objectif : Charbon — il manque : 62 Plaque de fer »")
---------------------------------------------------------------------------------------------------
-- Votre équipe : 10 PNJ, aucun four au QG, pierre et charbon à foison, un avant-poste de pierre qui tourne, sites de
-- charbon et de fer connus, minerai de fer à 150 tuiles.
local dc_stock = { stone = 600, coal = 800, ["firearm-magazine"] = 60 }
local function dc_view(over)
  local v = view({ is_player = true, stock = dc_stock, outposts = { op(1, "stone", 2) },
    sites = { coal = 1, iron = 1, copper = 0, stone = 1 }, done = { stone = true } })
  for k, x in pairs(over or {}) do v[k] = x end
  return v
end
-- Ancien cerveau : échelle de votre équipe, objectif charbon.
local old = Planner.plan(dc_view({ ladder = { { key = "coal", need = { outposts = { coal = 1 } } },
  { key = "iron", need = { outposts = { iron = 1 } } } } }), book)
local old_iron = 0
for _, m in ipairs(old.missing) do if m[1] == "iron-plate" then old_iron = m[2] end end
check(old.goal == "coal" and old_iron > 0, "ancien cerveau : objectif charbon, il manque du fer (" .. old_iron .. ")")
check(count(old, function(t) return t.kind == "mine" and t.resource == "iron-ore" end) == 0,
  "ancien cerveau : AUCUN minage de fer (défaut reproduit)")
check(count(old, function(t) return t.kind == "smelters" or (t.kind == "craft" and t.item == "stone-furnace") end) == 0,
  "ancien cerveau : aucun four fabriqué ni posé (défaut reproduit)")
-- Nouveau cerveau.
local st = C.new_state(0)
local ctx = { tick = 0, is_player = true, weights = B.weights({}, nil), reach = { ["iron-ore"] = 150, stone = 40, coal = 80 } }
local plan = C.think(dc_view(), book, st, ctx)
local mines = count(plan, function(t) return t.kind == "mine" and t.resource == "iron-ore" end)
check(mines >= 2, "nouveau : le fer est miné à la main par PLUSIEURS PNJ (" .. mines .. " tâches)")
local furnace = find(plan, function(t) return t.kind == "craft" and t.item == T.SMELTER end)
  or find(plan, function(t) return t.kind == "smelters" end)
check(furnace ~= nil, "nouveau : des fours sont fabriqués avec la pierre du coffre (ou posés)")
check((plan.smelt["iron-plate"] or 0) > 0, "nouveau : la fonderie doit produire des plaques de fer")
check(plan.ia3.active >= 2, "nouveau : au moins 2 projets actifs à 10 PNJ (" .. plan.ia3.active .. ")")
local mine_t = find(plan, function(t) return t.kind == "mine" and t.resource == "iron-ore" end)
check(mine_t and mine_t.radius == 150, "nouveau : le minage vise le gisement connu (rayon 150)")
check(mine_t and mine_t.ia3 ~= nil and mine_t.why ~= nil, "nouveau : la tâche porte son projet et sa raison")
check(plan.ia3.saturated.stone and plan.ia3.saturated.coal, "nouveau : pierre et charbon SATURÉS (stock bien au-delà du besoin)")
local svc = count(plan, function(t) return t.kind == "service" and t.outpost == 1 end)
check(svc == 0, "nouveau : plus de tournée de collecte à l'avant-poste de pierre saturé")
-- Mêmes données, aucun gisement de fer connu : explorer, aucun minage de fer.
local st2 = C.new_state(0)
local plan2 = C.think(dc_view({ sites = { coal = 1, iron = 0, copper = 0, stone = 1 } }), book, st2,
  { tick = 0, is_player = true, weights = B.weights({}, nil), reach = { stone = 40, coal = 80 } })
check(count(plan2, function(t) return t.kind == "mine" and t.resource == "iron-ore" end) == 0,
  "sans fer connu : aucun minage de fer")
check((plan2.ia3.explore["iron-ore"] or 0) > 0, "sans fer connu : exploration du minerai de fer demandée")
check((plan2.site_needs.iron or 0) > 0, "sans fer connu : site de fer recherché (prospection)")
-- Pensées suivantes : fours posés (2) et minerai au coffre : la fonderie tourne, le minage continue si besoin.
local v3 = dc_view({ smelters = 2, stock = { stone = 590, coal = 790, ["iron-ore"] = 40 } })
local plan3 = C.think(v3, book, st, { tick = 300, is_player = true, weights = B.weights({}, nil),
  reach = { ["iron-ore"] = 150, stone = 40, coal = 80 } })
check(find(plan3, function(t) return t.kind == "smelt" end) ~= nil, "fours posés : tournée de fonderie")
check(count(plan3, function(t) return t.kind == "mine" and t.resource == "iron-ore" end) >= 1,
  "fours posés, minerai insuffisant : le minage continue")
-- Le fer arrive : 200 plaques ; la construction du charbon part (tâche build).
local v4 = dc_view({ smelters = 2, stock = { stone = 590, coal = 790, ["iron-plate"] = 200 } })
local plan4 = C.think(v4, book, st, { tick = 600, is_player = true, weights = B.weights({}, nil),
  reach = { ["iron-ore"] = 150, stone = 40, coal = 80 } })
check(find(plan4, function(t) return t.kind == "build" and t.outpost_kind == "coal" end) ~= nil
  or find(plan4, function(t) return t.kind == "craft" and t.item == T.DRILL end) ~= nil,
  "fer au coffre : l'avant-poste de charbon se prépare (foreuses) ou part")
check(find(plan4, function(t) return t.kind == "build" and t.outpost_kind == "iron" end) ~= nil
  or find(plan4, function(t) return t.kind == "craft" and t.item == T.DRILL and t.why == "extraction:iron" end) ~= nil,
  "fer au coffre : l'avant-poste de fer se prépare EN PARALLÈLE")

---------------------------------------------------------------------------------------------------
section("2. Projets : K, inertie, projet bloqué")
---------------------------------------------------------------------------------------------------
check(P.K(4) == 3 and P.K(8) == 4 and P.K(30) == 9 and P.K(100) == 10, "K = 2 + PNJ / 4, au plus 10")
local stK = { projects = {} }
local goals = {}
for i = 1, 8 do goals[#goals + 1] = { key = "g" .. i, family = "extraction", kind = "stock", value = 90 - i } end
local order, K = P.update(stK, goals, 0, 8)
check(K == 4 and #order == 4, "8 PNJ : 4 projets actifs sur 8 buts (" .. #order .. ")")
-- Un projet bloqué ne prend pas de place.
stK.projects[1].state = "bloque"
local order2 = P.update(stK, goals, 300, 8)
local n_act = 0
for _, p in ipairs(order2) do if p.state == "actif" then n_act = n_act + 1 end end
check(n_act == 4 and #order2 == 5, "un projet bloqué reste ouvert sans prendre de place (4 actifs + 1 bloqué)")
-- Inertie : un but ouvert garde sa place face à un but neuf un peu meilleur (+ 20 %).
local stI = { projects = {} }
P.update(stI, { { key = "a", family = "x", kind = "stock", value = 50 } }, 0, 0)
local o3 = P.update(stI, { { key = "a", family = "x", kind = "stock", value = 50 },
  { key = "b", family = "x", kind = "stock", value = 55 }, { key = "c", family = "x", kind = "stock", value = 56 } }, 300, 0)
local keys = {}
for _, p in ipairs(o3) do keys[#keys + 1] = p.key end
check(table.concat(keys, ",") == "a,c", "inertie : le projet ouvert (50 + 20 %) passe devant un but neuf de 55 (" .. table.concat(keys, ",") .. ")")
-- Fin d'un projet : son but disparaît, il est fermé et annoncé.
P.update(stI, { { key = "c", family = "x", kind = "stock", value = 56 } }, 600, 0)
local fini = false
for _, e in ipairs(stI.log) do if e.kind == "fini" and e.key == "a" then fini = true end end
check(fini, "un projet dont le but a disparu est fermé et annoncé")

---------------------------------------------------------------------------------------------------
section("3. Caractère : poids du chef")
---------------------------------------------------------------------------------------------------
local wt = B.weights({ { key = "technologie", w = 700 }, { key = "capitalisation", w = 300 } }, { curiosite = 1400, agressivite = 700 })
local wc = B.weights({ { key = "assaut", w = 700 }, { key = "armee", w = 300 } }, { curiosite = 700, agressivite = 1400 })
check(wt.recherche > wt.armee and wc.armee > wc.recherche, "technocrate : recherche > armée ; conquérant : armée > recherche")
local function fac_s(w)
  return { is_player = false, workers = 8, soldiers = 0, soldiers_max = 30, stock = { ["firearm-magazine"] = 60, stone = 50 },
    cap = { coal = 1, iron = 2, copper = 1, stone = 1 }, pending = {}, sites = {}, smelters = 4, smelters_pending = 0,
    weights = w, research = { tech = "t-pack", palier = true }, army_target = 18, economy_done = true }
end
local function rank_of(goals2, key)
  for i, g in ipairs(goals2) do if g.key == key then return i end end
  return 99
end
local gt = B.generate(fac_s(wt), { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true })
local gc = B.generate(fac_s(wc), { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true })
check(rank_of(gt, "recherche") < rank_of(gt, "armee"), "technocrate : la recherche passe devant l'armée")
check(rank_of(gc, "armee") < rank_of(gc, "recherche"), "conquérant : l'armée passe devant la recherche")
-- En guerre, l'armée vaut plus (× B.ARMY_WAR_PCT) ; armée et munitions sont PERMANENTES (hors des K projets).
local sw = fac_s(B.weights({}, nil))
sw.soldiers = 12
local g_peace = B.generate(sw, { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true })
sw.at_war = true
local g_war = B.generate(sw, { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true })
local function goal_of(goals2, key) for _, g in ipairs(goals2) do if g.key == key then return g end end end
check(goal_of(g_war, "armee").value > goal_of(g_peace, "armee").value and goal_of(g_war, "armee").permanent,
  "en guerre : l'armée vaut plus, et reste permanente")

---------------------------------------------------------------------------------------------------
section("4. Recherche (laboratoire du QG) : packs, impayable, garde de l'économie")
---------------------------------------------------------------------------------------------------
local fstock = { ["iron-plate"] = 400, ["copper-plate"] = 200, coal = 200, stone = 200, ["firearm-magazine"] = 60,
  ["burner-mining-drill"] = 4, ["stone-furnace"] = 4 }
local function fview(over)
  local v = view({ is_player = false, stock = fstock, workers = 8, soldiers = 10, soldiers_max = 30, smelters = 4,
    outposts = { op(1, "coal", 8), op(2, "iron", 16), op(3, "copper", 3), op(4, "stone", 2) },
    ladder = T.ladder, defend_first = true, hq_turrets = 0, hq_defend = 0 })
  for k, x in pairs(over or {}) do v[k] = x end
  return v
end
local rinfo = { tech = "automation", payable = true, palier = true, lab_item = "lab", labs_craft = 1,
  packs = { { "automation-science-pack", 10 } } }
local stR = C.new_state(0)
local pr = C.think(fview(), book, stR, { tick = 0, weights = B.weights({}, nil), research = rinfo, reach = {}, iron_floor = 0 })
check(find(pr, function(t) return t.kind == "craft" and t.item == "automation-science-pack" end) ~= nil, "packs rouges fabriqués")
check(find(pr, function(t) return t.kind == "craft" and t.item == "lab" end) ~= nil, "laboratoire du QG fabriqué")
-- Technologie impayable (une feuille sans source : pétrole) dont un pack, lui, se fabrique : rien n'est fabriqué.
local rimp = { tech = "chemical", payable = false, causes = { "crude-oil" },
  packs = { { "automation-science-pack", 10 }, { "chemical-science-pack", 10 } } }
local stR2 = C.new_state(0)
local pr2 = C.think(fview(), book, stR2, { tick = 0, weights = B.weights({}, nil), research = rimp, reach = {} })
check(count(pr2, function(t) return t.kind == "craft" and (t.item == "chemical-science-pack"
  or t.item == "automation-science-pack") end) == 0, "recherche impayable : AUCUN pack fabriqué, même le pack faisable (K6)")
local blocked = false
for _, p in ipairs(stR2.projects) do if p.key == "recherche" and p.state == "bloque" then blocked = true end end
check(blocked, "recherche impayable : projet bloqué, cause dite")
-- Garde de l'économie : 100 fer au coffre, plancher 100 : aucun pack fabriqué avec ce fer.
local stR3 = C.new_state(0)
local pr3 = C.think(fview({ stock = { ["iron-plate"] = 100, ["copper-plate"] = 200, ["firearm-magazine"] = 60, coal = 200, stone = 200 } }),
  book, stR3, { tick = 0, weights = B.weights({}, nil), research = { tech = "automation", payable = true,
  packs = { { "automation-science-pack", 30 } } }, reach = {}, iron_floor = 100 })
check(count(pr3, function(t) return t.kind == "craft" and t.item == "automation-science-pack" end) == 0,
  "garde de l'économie : aucun pack sous le plancher de fer")

---------------------------------------------------------------------------------------------------
section("5. Déterminisme, état persistant")
---------------------------------------------------------------------------------------------------
local function run_twice()
  local a, b = C.new_state(0), C.new_state(0)
  local s1, s2 = {}, {}
  for i = 0, 5 do
    local c = { tick = i * 300, is_player = true, weights = B.weights({}, nil), reach = { ["iron-ore"] = 150, stone = 40, coal = 80 } }
    s1[#s1 + 1] = sig(C.think(dc_view(), book, a, c))
    s2[#s2 + 1] = sig(C.think(dc_view(), book, b, c))
  end
  return table.concat(s1, "#"), table.concat(s2, "#"), a
end
local x1, x2, stx = run_twice()
check(x1 == x2, "deux passages identiques : mêmes plans")
check(deep_ok(stx), "état persistant : nombres, chaînes, booléens, tables (aucune fonction, aucune métatable)")
-- Livre construit depuis les recettes dans un autre ordre d'insertion : mêmes plans.
local rev = {}
local names = {}
for k in pairs(recipes) do names[#names + 1] = k end
table.sort(names, function(a, b) return a > b end)
for _, k in ipairs(names) do rev[k] = recipes[k] end
local p_rev = C.think(dc_view(), Book.new(rev), C.new_state(0), { tick = 0, is_player = true, weights = B.weights({}, nil),
  reach = { ["iron-ore"] = 150, stone = 40, coal = 80 } })
local p_fwd = C.think(dc_view(), book, C.new_state(0), { tick = 0, is_player = true, weights = B.weights({}, nil),
  reach = { ["iron-ore"] = 150, stone = 40, coal = 80 } })
check(sig(p_rev) == sig(p_fwd), "recettes dans l'ordre inverse : même plan")

---------------------------------------------------------------------------------------------------
section("6. Mutants")
---------------------------------------------------------------------------------------------------
local function mutant(name, patch, unpatch, test)
  patch()
  local ok, res = pcall(test)
  unpatch()
  check(ok and res == false, "mutant « " .. name .. " » refusé")
end
-- (a) sans approvisionnement (P.supply vide) : plus de minage de fer dans le cas du DC.
local supply0 = P.supply
mutant("sans approvisionnement", function() P.supply = function() end end, function() P.supply = supply0 end, function()
  local p = C.think(dc_view(), book, C.new_state(0), ctx)
  return count(p, function(t) return t.kind == "mine" and t.resource == "iron-ore" end) >= 2
end)
-- (b) sans saturation : la tournée de pierre revient.
local sat0 = B.saturated
mutant("sans saturation", function() B.saturated = function() return false end end, function() B.saturated = sat0 end, function()
  local p = C.think(dc_view(), book, C.new_state(0), ctx)
  return count(p, function(t) return t.kind == "service" and t.outpost == 1 end) == 0
end)
-- (c) K = 1 : un seul projet actif.
local k0 = P.K
mutant("un seul projet", function() P.K = function() return 1 end end, function() P.K = k0 end, function()
  local p = C.think(dc_view(), book, C.new_state(0), ctx)
  return p.ia3.active >= 2
end)
-- (d) recherche sans contrôle de payabilité : packs chimiques fabriqués.
local em = nil
mutant("impayable ignoré", function()
  rimp.payable = true
end, function() rimp.payable = false end, function()
  local p = C.think(fview(), book, C.new_state(0), { tick = 0, weights = B.weights({}, nil), research = rimp, reach = {} })
  return count(p, function(t) return t.kind == "craft" and t.item == "automation-science-pack" end) == 0
end)
-- (e) poids du chef ignorés : le conquérant met la recherche devant.
local w0 = B.weights
mutant("poids ignorés", function() B.weights = function() local o = {} for _, f in ipairs(B.FAMILIES) do o[f] = 1000 end return o end end,
  function() B.weights = w0 end, function()
  local g1 = B.generate(fac_s(B.weights({ { key = "technologie", w = 1000 } }, { curiosite = 1500 })), { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true })
  local g2 = B.generate(fac_s(B.weights({ { key = "assaut", w = 1000 } }, { agressivite = 1500 })), { targets = { coal = 2, iron = 2, copper = 1, stone = 1 }, iron2_set = true })
  return rank_of(g1, "recherche") < rank_of(g1, "armee") and rank_of(g2, "armee") < rank_of(g2, "recherche")
end)

print(string.format("[AI3-CERVEAU] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
