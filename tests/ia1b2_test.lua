--[[
  Lot IA1-b2 (décision D-17 du 25/10 : « défendre d'abord », « laisser grandir », « garder 20 % », « couper les
  gardes ») : bancs HORS JEU des parties pures.
    - cerveau (shared/team/planner.lua, view.defend_first) : tourelles d'un avant-poste non défendu en urgence, pas
      d'agrandissement avant elles, nouvel avant-poste bâti AVEC ses tourelles, règle de repli sans tourelle (premier
      avant-poste de chaque ressource seulement), recrues retenues après une perte (view.hold_recruits) ; sans
      view.defend_first, plan d'avant ;
    - fond (shared/team/fond.lua) : ni agrandissement ni garde vers un avant-poste non défendu, pas de construction
      sans tourelles, pas de garde d'avant-poste pour votre équipe (no_outpost_guard), réserve sans plancher sous
      « défendre d'abord » ; plafond du minage à la main inchangé (20 % dès la recherche 1) ;
    - mutants : chaque règle retirée fait échouer au moins un contrôle.
  Lancement : lua5.2 tests/ia1b2_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local O = require("shared.team.org")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local Fond = require("shared.team.fond")
local S = require("shared.team.scale")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
-- Livre SANS la recette des tourelles (votre force sans la recherche « Tourelles »).
local norec = {}
for _, k in ipairs((function() local ks = {} for k in pairs(recipes) do ks[#ks + 1] = k end table.sort(ks) return ks end)()) do
  if k ~= "gun-turret" then norec[k] = recipes[k] end
end
local book_no = Book.new(norec)

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = { coal = true, iron = true, copper = true, stone = true },
    deferred = {}, stock = {}, incoming = {}, outposts = {}, pending = {}, sites = {}, smelters = 2,
    smelters_pending = 0, smelter_task = false, smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0,
    turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 8, workers_max = 30, workers_idle = 0,
    threatened = false, open = {}, workers_wanted = 30, no_research = true, ladder = T.player_ladder,
    hq_turrets = T.defend_hq, -- QG défendu (sauf contrôle du QG)
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function op(id, kind, drills, turrets, over)
  local o = { id = id, kind = kind, drills = drills, full = false, turrets = turrets or 0, coal_needed = 0,
    fuel_low = false, output = 0, idle_ticks = 0, has_task = true, has_fortify = false }
  for k, x in pairs(over or {}) do o[k] = x end
  return o
end
local function find(plan, pred)
  for _, t in ipairs(plan.tasks) do if pred(t) then return t end end
  return nil
end
local function items_of(t, name)
  for _, it in ipairs(t and t.items or {}) do if it[1] == name then return it[2] end end
  return 0
end
local function sig(plan)
  local out = {}
  for _, t in ipairs(plan.tasks) do
    local its = {}
    for _, it in ipairs(t.items or {}) do its[#its + 1] = it[1] .. "x" .. it[2] end
    out[#out + 1] = t.key .. "@" .. tostring(t.prio) .. "[" .. table.concat(its, ",") .. "]"
  end
  local m = {}
  for _, x in ipairs(plan.missing) do m[#m + 1] = x[1] .. "x" .. x[2] end
  return table.concat(out, ";") .. "|" .. table.concat(m, ",") .. "|" .. tostring(plan.recruit_workers)
end
local rich = { ["iron-plate"] = 3000, ["copper-plate"] = 1000, coal = 500, stone = 500, ["firearm-magazine"] = 60,
  ["burner-mining-drill"] = 20, ["stone-furnace"] = 20, ["iron-chest"] = 8 }
local function with(base, extra)
  local s = {}
  for k, x in pairs(base) do s[k] = x end
  for k, x in pairs(extra or {}) do s[k] = x end
  return s
end

---------------------------------------------------------------------------------------------------
section("Cerveau : constantes de « défendre d'abord »")
check(T.defend_turrets(2) == 1 and T.defend_turrets(8) == 2 and T.defend_turrets(20) == 3,
  "tourelles voulues : 1 + 1 par tranche de 8 foreuses (2 -> 1, 8 -> 2, 20 -> 3)")
check(T.defend_prio >= O.URGENT_PRIO, "priorité des tourelles d'abord >= urgence (" .. T.defend_prio .. ")")
check(T.defend_ammo == T.turret_ammo_target, "tourelle posée pleine (" .. T.defend_ammo .. " chargeurs)")

---------------------------------------------------------------------------------------------------
section("Cerveau : avant-poste non défendu, recette connue")
local outs = { op(1, "coal", 4, 0), op(2, "iron", 8, 1), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local v1 = view({ defend_first = true, stock = with(rich, { ["gun-turret"] = 4 }), outposts = outs })
local p1 = Planner.plan(v1, book)
local f1 = find(p1, function(t) return t.key == "fortify:1" end)
check(f1 ~= nil and f1.prio == T.defend_prio and items_of(f1, "gun-turret") == 1 and items_of(f1, "firearm-magazine") == 20,
  "charbon (4 foreuses, 0 tourelle) : 1 tourelle pleine en urgence")
local f2 = find(p1, function(t) return t.key == "fortify:2" end)
check(f2 ~= nil and items_of(f2, "gun-turret") == 1, "fer (8 foreuses, 1 tourelle sur 2) : la 2e tourelle")
check(find(p1, function(t) return t.key == "fortify:3" or t.key == "fortify:4" end) == nil,
  "cuivre et pierre défendus (1 tourelle) : rien")
check(p1.defend and p1.defend.undefended == 2 and p1.defend.craftable, "publié : 2 avant-postes non défendus, recette connue")
-- Les tourelles manquent au stock : fabrication demandée en urgence.
local p1b = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs }), book)
check(find(p1b, function(t) return t.kind == "craft" and t.item == "gun-turret" and t.tag == "defense" and t.prio == T.defend_prio end) ~= nil
  and find(p1b, function(t) return t.kind == "fortify" end) == nil,
  "tourelles absentes : fabrication « defense » en urgence, la pose suit (pensée suivante)")
-- Avant-poste en cours de fortification : pas de deuxième tâche.
local outs_f = { op(1, "coal", 4, 0, { has_fortify = true }), op(2, "iron", 8, 2), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local p1c = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs_f }), book)
check(find(p1c, function(t) return t.key == "fortify:1" end) == nil, "fortification déjà en cours : pas de doublon")

---------------------------------------------------------------------------------------------------
section("Cerveau : pas d'agrandissement avant les tourelles")
-- Objectif iron2 (fer 2 avant-postes équivalents, charbon 2) : l'avant-poste de fer à 8 foreuses doit s'agrandir.
local outs2 = { op(1, "coal", 4, 1), op(2, "iron", 8, 1), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local done2 = { coal = true, iron = true, copper = true, stone = true, defense = true }
local p2 = Planner.plan(view({ defend_first = true, stock = with(rich, { ["gun-turret"] = 2 }), outposts = outs2, done = done2,
  sites = { iron = 1 } }), book)
check(find(p2, function(t) return t.key == "extend:2" end) == nil, "fer non défendu (1 tourelle sur 2) : pas d'agrandissement")
check(find(p2, function(t) return t.key == "build:iron" end) == nil, "ni nouvel avant-poste de fer à la place")
check(find(p2, function(t) return t.key == "fortify:2" end) ~= nil, "la tourelle du fer d'abord")
local p2b = Planner.plan(view({ stock = rich, outposts = outs2, done = done2, sites = { iron = 1 } }), book)
check(find(p2b, function(t) return t.key == "extend:2" end) ~= nil, "sans « défendre d'abord » : agrandissement (règle d'avant)")
local outs2d = { op(1, "coal", 4, 1), op(2, "iron", 8, 2), op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local p2c = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs2d, done = done2, sites = { iron = 1 } }), book)
check(find(p2c, function(t) return t.key == "extend:2" end) ~= nil, "fer défendu (2 tourelles) : agrandissement")

---------------------------------------------------------------------------------------------------
section("Cerveau : nouvel avant-poste bâti avec ses tourelles")
-- Fer plein : l'objectif iron2 demande un 2e avant-poste de fer (site connu).
local outs3 = { op(1, "coal", 12, 2, { full = true }), op(2, "iron", 8, 2, { full = true }), op(3, "copper", 3, 1),
  op(4, "stone", 2, 1) }
local stock3 = with(rich, { ["gun-turret"] = 4 })
local p3 = Planner.plan(view({ defend_first = true, stock = stock3, outposts = outs3, done = done2, sites = { iron = 1 } }), book)
local b3 = find(p3, function(t) return t.key == "build:iron" end)
check(b3 ~= nil and items_of(b3, "gun-turret") == T.defend_turrets(8) and items_of(b3, "burner-mining-drill") == 8,
  "2e avant-poste de fer : 8 foreuses et " .. T.defend_turrets(8) .. " tourelles portées ensemble")
-- Tourelles absentes mais fabricables : la construction attend, les tourelles se fabriquent.
local p3b = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs3, done = done2, sites = { iron = 1 } }), book)
check(find(p3b, function(t) return t.key == "build:iron" end) == nil, "tourelles absentes : la construction attend")
check(find(p3b, function(t) return t.kind == "craft" and t.item == "gun-turret" end) ~= nil, "les tourelles se fabriquent")

---------------------------------------------------------------------------------------------------
section("Cerveau : règle de repli (aucune tourelle, recette inconnue) et avant-postes meurtriers")
local p4 = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs3, done = done2, sites = { iron = 1 } }), book_no)
check(find(p4, function(t) return t.key == "build:iron" end) ~= nil, "repli : 2e avant-poste de fer bâti comme avant")
check(find(p4, function(t) return t.kind == "fortify" end) == nil, "repli : aucune fortification demandée")
local p4b = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs2, done = done2, sites = { iron = 1 } }), book_no)
check(find(p4b, function(t) return t.key == "extend:2" end) ~= nil, "repli : agrandissement comme avant")
-- Avant-poste meurtrier (un PNJ tué en y allant) : ni tournée, ni agrandissement, tourelle possible ou non.
local outs_l = { op(1, "coal", 4, 1), op(2, "iron", 8, 1, { lethal = true, has_task = false, fuel_low = true }),
  op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local p4l = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs_l, done = done2, sites = { iron = 1 } }), book_no)
check(find(p4l, function(t) return t.key == "service:2" or t.key == "extend:2" end) == nil and (p4l.lethal_skip or 0) == 1,
  "repli, fer meurtrier : ni tournée (même à sec), ni agrandissement")
local p4m = Planner.plan(view({ defend_first = true, stock = with(rich, { ["gun-turret"] = 4 }), outposts = outs_l, done = done2 }), book)
check(find(p4m, function(t) return t.key == "fortify:2" or t.key == "service:2" end) == nil,
  "recette connue, fer meurtrier : sa pause passe avant ses tourelles")
local outs_l2 = { op(1, "coal", 4, 1), op(2, "iron", 8, 2, { lethal = true, has_task = false, fuel_low = true }),
  op(3, "copper", 3, 1), op(4, "stone", 2, 1) }
local p4n = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs_l2, done = done2 }), book_no)
check(find(p4n, function(t) return t.key == "service:2" end) ~= nil, "meurtrier mais défendu : la tournée reste")
local p4o = Planner.plan(view({ stock = rich, outposts = outs_l, done = done2 }), book_no)
check(find(p4o, function(t) return t.key == "service:2" end) ~= nil, "sans « défendre d'abord » : tournée comme avant")
-- Premier avant-poste d'une ressource (départ) : bâti sans tourelle quand il n'y en a pas.
local p4c = Planner.plan(view({ defend_first = true, stock = rich, outposts = {}, done = {}, ladder = T.player_ladder,
  sites = { coal = 1 } }), book)
local b4 = find(p4c, function(t) return t.key == "build:coal" end)
check(b4 ~= nil and items_of(b4, "gun-turret") == 0, "premier avant-poste de charbon : bâti sans tourelle quand il n'y en a pas")
-- Le QG d'abord.
local p4q = Planner.plan(view({ defend_first = true, hq_turrets = 0, stock = with(rich, { ["gun-turret"] = 3 }), outposts = outs }), book)
local fq = find(p4q, function(t) return t.key == "fortify:hq" end)
check(fq ~= nil and items_of(fq, "gun-turret") == T.defend_hq and fq.prio == T.defend_prio, "QG sans tourelle : les siennes d'abord")
local p4r = Planner.plan(view({ defend_first = true, hq_turrets = 0, hq_fortify = true, stock = with(rich, { ["gun-turret"] = 3 }),
  outposts = outs }), book)
check(find(p4r, function(t) return t.key == "fortify:hq" end) == nil, "QG en cours de fortification : pas de doublon")
-- Plancher de fer : la défense ne fabrique pas sous T.defend_iron_floor plaques.
local poor = { ["iron-plate"] = T.defend_iron_floor + 30, ["copper-plate"] = 200 }
local p4s = Planner.plan(view({ defend_first = true, stock = poor, outposts = outs }), book)
check(find(p4s, function(t) return t.kind == "craft" and t.item == "gun-turret" end) == nil,
  "fer " .. (T.defend_iron_floor + 30) .. " : aucune tourelle fabriquée (plancher " .. T.defend_iron_floor .. ")")
-- Une tourelle au coffre (mise par le joueur) : elle sert, recette inconnue ou non.
local p4d = Planner.plan(view({ defend_first = true, stock = with(rich, { ["gun-turret"] = 1 }), outposts = outs }), book_no)
check(find(p4d, function(t) return t.key == "fortify:1" end) ~= nil, "tourelle au coffre, recette inconnue : posée")
-- Premier avant-poste avec tourelles au stock : portées avec la construction.
local p4e = Planner.plan(view({ defend_first = true, stock = with(rich, { ["gun-turret"] = 2 }), outposts = {}, done = {},
  sites = { coal = 1 } }), book)
check(items_of(find(p4e, function(t) return t.key == "build:coal" end), "gun-turret") == 1,
  "premier avant-poste, tourelle au stock : portée avec la construction")

---------------------------------------------------------------------------------------------------
section("Cerveau : recrues retenues après une perte")
local p5 = Planner.plan(view({ defend_first = true, hold_recruits = true, workers = 3, recover_floor = 8, stock = rich,
  outposts = outs2d }), book)
check(not p5.recruit_workers and p5.recruit_hold_loss, "perte récente, 3 sur 8 : aucune recrue (ni de survie)")
local p5b = Planner.plan(view({ defend_first = true, workers = 3, recover_floor = 8, stock = rich, outposts = outs2d }), book)
check(p5b.recruit_workers == 1, "sans perte récente : recrue de survie comme avant")
local p5c = Planner.plan(view({ hold_recruits = true, workers = 0, stock = {} }), book)
check(not p5c.recruit_workers, "perte récente, équipe vide : on attend la fin de la minute")

---------------------------------------------------------------------------------------------------
section("Cerveau : sans view.defend_first, plan d'avant ; déterminisme")
local va = view({ stock = rich, outposts = outs, done = done2, sites = { iron = 1 } })
local pa = Planner.plan(va, book)
check(find(pa, function(t) return t.kind == "fortify" and t.prio == T.defend_prio end) == nil,
  "sans la règle : aucune fortification d'urgence")
local pb = Planner.plan(view({ stock = rich, outposts = outs, done = done2, sites = { iron = 1 } }), book)
check(sig(pa) == sig(pb), "sans la règle : deux pensées identiques")
local pc = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs, done = done2, sites = { iron = 1 } }), book)
local pd = Planner.plan(view({ defend_first = true, stock = rich, outposts = outs, done = done2, sites = { iron = 1 } }), book)
check(sig(pc) == sig(pd), "avec la règle : deux pensées identiques")

---------------------------------------------------------------------------------------------------
section("Fond : défendre d'abord, gardes coupées, réserve")
local fv = view({ outposts = { op(1, "coal", 4, 0), op(2, "iron", 8, 2) }, sites = { copper = 1 } })
local und = Planner.undefended(view({ defend_first = true, outposts = fv.outposts }))
check(und[1] and not und[2], "P.undefended : charbon sans tourelle, fer défendu")
local function cands(ctx, stock)
  local free = Fond.free_stock(stock or rich, {})
  ctx.book = book
  ctx.mine_left = ctx.mine_left or 2
  return Fond.candidates(fv, free, ctx)
end
local c0 = cands({})
local c1 = cands({ defend_first = true, undefended = und, no_outpost_guard = true, turrets_ok = true })
local function has_key(list, key) for _, t in ipairs(list) do if t.key == key then return true end end return false end
check(has_key(c0.extraction, "extend:1") and not has_key(c1.extraction, "extend:1"),
  "agrandir : le charbon non défendu sort du fond (" .. tostring(has_key(c0.extraction, "extend:1")) .. ")")
check(has_key(c1.extraction, "extend:2"), "agrandir : le fer défendu reste")
check(has_key(c0.extraction, "build:copper") and not has_key(c1.extraction, "build:copper"),
  "construire sur un site connu : refusé sans tourelles au stock")
local c2 = cands({ defend_first = true, undefended = und, turrets_ok = true }, with(rich, { ["gun-turret"] = 3 }))
local bc
for _, t in ipairs(c2.extraction) do if t.key == "build:copper" then bc = t end end
check(bc ~= nil and items_of(bc, "gun-turret") == 1, "construire : avec 1 tourelle quand le stock l'a")
check(has_key(c0.territoire, "fond:garde:1:1") and not has_key(c1.territoire, "fond:garde:2:1")
  and not has_key(c1.territoire, "fond:garde:1:1"), "garde d'avant-poste coupée (votre équipe)")
check(has_key(c1.territoire, "fond:garde:hq:1"), "garde du QG gardée (la décision coupe les gardes d'avant-postes)")
-- Réserve : sans rien à poser (avant-postes non défendus, aucun site constructible), aucune foreuse d'avance.
local fv2 = view({ outposts = { op(1, "coal", 4, 0) }, sites = {} })
local free2 = Fond.free_stock(with(rich, { ["burner-mining-drill"] = 0, ["stone-furnace"] = 0 }), {})
local c3 = Fond.candidates(fv2, free2, { book = book, defend_first = true, undefended = { [1] = true }, turrets_ok = false })
local drills = false
for _, t in ipairs(c3.base) do if t.item == "burner-mining-drill" or t.item == "stone-furnace" then drills = true end end
check(not drills, "réserve : rien à poser, aucune foreuse ni four d'avance")
local free3 = Fond.free_stock(with(rich, { ["burner-mining-drill"] = 0, ["stone-furnace"] = 0 }), {})
local c4 = Fond.candidates(fv2, free3, { book = book })
local drills0 = false
for _, t in ipairs(c4.base) do if t.item == "burner-mining-drill" then drills0 = true end end
check(drills0, "sans « défendre d'abord » : plancher de réserve d'avant (8 foreuses)")
check(O.manual_cap(30, 2) == 6 and O.manual_cap(10, 2) == 2, "minage à la main : plafond 20 % dès la recherche 1 (gardé)")

---------------------------------------------------------------------------------------------------
section("Cerveau : équipe décimée, le QG d'abord")
local pdz = Planner.plan(view({ defend_first = true, hq_turrets = 0, workers = 5, recover_floor = 8,
  stock = with(rich, { ["gun-turret"] = 6 }), outposts = outs }), book)
check(find(pdz, function(t) return t.key == "fortify:hq" end) ~= nil, "5 PNJ sur 8 : tourelles du QG")
check(find(pdz, function(t) return t.key == "fortify:1" or t.key == "fortify:2" end) == nil, "5 PNJ sur 8 : aucune tourelle d'avant-poste")
local pdy = Planner.plan(view({ defend_first = true, workers = 5, recover_floor = 8, stock = with(rich, { ["gun-turret"] = 4 }),
  outposts = outs3, done = done2, sites = { iron = 1 } }), book)
check(find(pdy, function(t) return t.key == "build:iron" end) == nil, "5 PNJ sur 8 : pas de nouvel avant-poste")
local pdx = Planner.plan(view({ defend_first = true, workers = 8, recover_floor = 8, stock = with(rich, { ["gun-turret"] = 4 }),
  outposts = outs }), book)
check(find(pdx, function(t) return t.key == "fortify:1" end) ~= nil, "8 PNJ sur 8 : les avant-postes reprennent")

---------------------------------------------------------------------------------------------------
section("Mutants : chaque règle retirée est vue")
do
  local saved = T.defend_turrets
  T.defend_turrets = function() return 0 end
  local m1 = Planner.plan(view({ defend_first = true, stock = with(rich, { ["gun-turret"] = 4 }), outposts = outs }), book)
  T.defend_turrets = saved
  check(find(m1, function(t) return t.key == "fortify:1" end) == nil, "mutant « 0 tourelle voulue » : la fortification disparaît")
  local m2 = Planner.plan(view({ defend_first = nil, stock = rich, outposts = outs2, done = done2, sites = { iron = 1 } }), book)
  check(find(m2, function(t) return t.key == "extend:2" end) ~= nil, "mutant « règle coupée » : agrandissement non défendu revu")
  local m3 = Planner.plan(view({ defend_first = true, hold_recruits = nil, workers = 3, recover_floor = 8, stock = rich,
    outposts = outs2d }), book)
  check(m3.recruit_workers == 1, "mutant « pas de retenue » : la recrue revient")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
