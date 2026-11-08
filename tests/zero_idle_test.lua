--[[
  Lot ZERO-IDLE : banc HORS JEU de shared/ai3/zero_idle.lua (agrandissement de fonderie par PNJ libre) et de son branchement dans la
  pensée pure (shared/ai3/cerveau.lua, C.think). Lancement : lua5.2 tests/zero_idle_test.lua (depuis la racine du mod).

  Sections :
    1. le cas du DC (partie 0.6.66 du 8/11, votre équipe vers 25 min) : PNJ sans tâche, fer et cuivre SATURÉS, avant-postes de fonderie
       avec place : la règle d'avant n'agrandit rien (défaut reproduit) ; la règle émet des agrandissements et fait fabriquer les
       foreuses et les fours, sans minage à la main pour eux ;
    2. plafond = PNJ libres (jamais une constante) ; 3. plafond = stock ; 4. causes (combustible, stock, plein, en cours, non défendu,
       menace, palier) ; 5. ordre du besoin et avant-poste le plus proche ; 6. émission (pose, fabrication, jamais de minage) ;
    7. journal [FO-ZERO-IDLE] ; 8. déterminisme, état en données pures, aucun nom du jeu, aucun pairs() décisionnel ;
    9. coût : pire cas en instructions (debug.sethook) sous le budget de 5 ms par pensée ; 10. mutants.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local B = require("shared.ai3.buts")
local P = require("shared.ai3.projets")
local C = require("shared.ai3.cerveau")
local ZI0 = require("shared.ai3.zero_idle")

local passes, failures = 0, 0
local QUIET = false
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not QUIET then print("  ECHEC : " .. msg) end
  end
  return cond
end
local function section(name) if not QUIET then print("== " .. name) end end

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
    pending = {}, sites = {}, smelters = 2, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 13,
    workers_max = 30, workers_idle = 5, threatened = false, open = {}, workers_wanted = 13, no_research = true,
    ladder = T.player_ladder, hq_turrets = T.defend_hq, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function op(id, kind, drills, over)
  local o = { id = id, kind = kind, drills = drills, full = false, turrets = 4, coal_needed = 0, fuel_low = false,
    output = 10, idle_ticks = 0, has_task = false, has_fortify = false, d2 = id * 100 }
  for k, x in pairs(over or {}) do o[k] = x end
  return o
end
local function count(plan, pred)
  local n = 0
  for _, t in ipairs(plan.tasks) do if pred(t) then n = n + 1 end end
  return n
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

local IRON_PLATE = T.outposts.iron.product
local COPPER_PLATE = T.outposts.copper.product
local STONE = T.outposts.stone.product
local FUEL = T.fuel

-- Stock riche (votre équipe vers 25 min : « sature [copper-plate iron-plate] », 2 116 objets au coffre).
local RICH = { [IRON_PLATE] = 900, [COPPER_PLATE] = 900, [STONE] = 1500, [FUEL] = 600 }
local function dc_view(over)
  local v = view({ is_player = true, stock = RICH, outposts = { op(1, "coal", 20), op(2, "iron", 26), op(3, "copper", 9),
    op(4, "stone", 14) }, sites = { coal = 1, iron = 1, copper = 1, stone = 1 }, done = { coal = true, iron = true, copper = true, stone = true } })
  for k, x in pairs(over or {}) do v[k] = x end
  return v
end
local function dc_ctx() return { tick = 0, is_player = true, weights = B.weights({}, nil), reach = { ["iron-ore"] = 60, ["copper-ore"] = 60, stone = 40, coal = 40 } } end
local function grows(plan)
  return count(plan, function(t)
    return t.kind == "extend" or (t.kind == "craft" and (t.item == T.DRILL or t.item == T.outposts.iron.sink))
  end)
end

---------------------------------------------------------------------------------------------------
-- Suite pure (rejouée par chaque mutant) : rend le nombre d'échecs.
---------------------------------------------------------------------------------------------------
local function kinds_of(ZI, over)
  local v = dc_view(over)
  local s = { key = { order = { "iron", "copper" } } }
  return ZI.input(v, s, book, v.stock, nil)
end

local function suite(ZI)
  local f0 = failures

  section("2. Plafond = PNJ libres")
  do
    local outs = {}
    for i = 1, 6 do outs[#outs + 1] = op(10 + i, "iron", 8) end
    local big = { [IRON_PLATE] = 100000, [STONE] = 100000, [FUEL] = 100000, [COPPER_PLATE] = 1000 }
    for _, idle in ipairs({ 0, 1, 2, 5 }) do
      local inp = kinds_of(ZI, { outposts = outs, stock = big, workers_idle = idle })
      local r = ZI.decide(inp)
      check(#r.orders == idle, string.format("%d PNJ libre(s) -> %d agrandissement(s) (rendu %d)", idle, idle, #r.orders))
    end
    local inp = kinds_of(ZI, { outposts = outs, stock = big, workers_idle = 2, workers_fond = 3 })
    check(#ZI.decide(inp).orders == 5, "2 sans tâche + 3 au fond doux -> 5 agrandissements")
    local inp2 = kinds_of(ZI, { outposts = outs, stock = big, workers_idle = 30 })
    check(#ZI.decide(inp2).orders == 6, "30 PNJ libres, 6 avant-postes de fer avec place -> 6 (un agrandissement par avant-poste)")
  end

  section("3. Plafond = stock")
  do
    local outs = { op(11, "iron", 8), op(12, "iron", 8), op(13, "iron", 8) }
    local kit = ZI.tiers("iron")[1].kit
    -- exactement un kit : les objets du kit eux-mêmes
    local one = {}
    for _, it in ipairs(kit) do one[it[1]] = it[2] end
    local r = ZI.decide(kinds_of(ZI, { outposts = outs, stock = one, workers_idle = 10 }))
    check(#r.orders == 1, "stock d'un kit pour 10 PNJ libres -> 1 agrandissement (rendu " .. #r.orders .. ")")
    check(r.left == 9, "9 PNJ restent sans agrandissement (rendu " .. tostring(r.left) .. ")")
    check(r.causes.iron == "stock" or r.causes.iron == "combustible", "cause du fer : stock épuisé (rendu " .. tostring(r.causes.iron) .. ")")
    local none = ZI.decide(kinds_of(ZI, { outposts = outs, stock = {}, workers_idle = 4 }))
    check(#none.orders == 0 and none.causes.iron == "stock", "coffre vide -> rien, cause « stock »")
    check(next(none.missing) ~= nil, "le manque du kit est écrit")
  end

  section("4. Causes")
  do
    local outs = { op(11, "iron", 8) }
    local nofuel = { [IRON_PLATE] = 10000, [STONE] = 10000 }
    local r = ZI.decide(kinds_of(ZI, { outposts = outs, stock = nofuel, workers_idle = 2 }))
    check(#r.orders == 0 and r.causes.iron == "combustible", "plaques et pierre sans combustible -> « combustible » (rendu " .. tostring(r.causes.iron) .. ")")
    check(r.missing[FUEL] ~= nil and r.missing[IRON_PLATE] == nil, "le manque nomme le combustible seul")
    local full = ZI.decide(kinds_of(ZI, { outposts = { op(11, "iron", 8, { full = true }) }, stock = RICH, workers_idle = 2 }))
    check(full.causes.iron == "plein", "avant-poste plein -> « plein » (rendu " .. tostring(full.causes.iron) .. ")")
    local busy = ZI.decide(kinds_of(ZI, { outposts = outs, stock = RICH, workers_idle = 2, open = { ["extend:11"] = true } }))
    check(busy.causes.iron == "en_cours" and #busy.orders == 0, "agrandissement déjà pris -> rien de plus, « en_cours » pour le fer")
    local und = ZI.decide(kinds_of(ZI, { outposts = { op(11, "iron", 8, { turrets = 0, lethal = true }) }, stock = RICH, workers_idle = 2 }))
    check(und.causes.iron == "non_defendu", "avant-poste non défendu et meurtrier -> « non_defendu » (rendu " .. tostring(und.causes.iron) .. ")")
    local thr = ZI.decide(kinds_of(ZI, { outposts = outs, stock = RICH, workers_idle = 3, hq_threat = true }))
    check(#thr.orders == 0 and thr.causes.iron == "menace", "QG menacé -> rien, « menace »")
    local v = dc_view({ outposts = outs, workers_idle = 2 })
    local inp = ZI.input(v, { key = { order = { "iron" } } }, book, v.stock,
      { zi_tiers = { iron = { { name = "thermique", kit = ZI.tiers("iron")[1].kit, ok = false, why = "electrique-impose" } } } })
    local pr = ZI.decide(inp)
    check(pr.causes.iron == "palier:electrique-impose" and #pr.orders == 0 or false, "palier refusé -> « palier:<raison> » (rendu " .. tostring(pr.causes.iron) .. ")")
    local el = ZI.input(v, { key = { order = { "iron" } } }, book, v.stock,
      { zi_tiers = { iron = { { name = "electrique", kit = { { T.DRILL_ELECTRIC, 2 } }, ok = false, why = "kW" },
        { name = "thermique", kit = ZI.tiers("iron")[1].kit, ok = true } } } })
    local er = ZI.decide(el)
    check(#er.orders >= 1 and er.orders[1].tier == "thermique", "électrique refusé (kW) -> le palier permis suivant (thermique)")
    local vc = dc_view({ outposts = outs, workers_idle = 2 })
    local cv = ZI.decide(ZI.input(vc, { key = { order = { "iron" } } }, book, vc.stock, nil, { [IRON_PLATE] = true }))
    check(#cv.orders == 0 and cv.causes.iron == "palier:couvert-electrique", "fer couvert par un module électrique : plus de paires thermiques (rendu " .. tostring(cv.causes.iron) .. ")")
    local toff = ZI.decide(kinds_of(ZI, { outposts = outs, stock = RICH, workers_idle = 2, thermal_off = { iron = "centrale" } }))
    check(#toff.orders == 0 and toff.causes.iron == "palier:electrique:centrale", "bascule électrique (view.thermal_off) : plus de paires thermiques de fer (rendu " .. tostring(toff.causes.iron) .. ")")
    local zero = ZI.decide(kinds_of(ZI, { outposts = outs, stock = RICH, workers_idle = 0 }))
    check(#zero.orders == 0 and next(zero.causes) == nil, "aucun PNJ libre -> rien, aucune cause")
  end

  section("5. Ordre du besoin, avant-poste le plus proche")
  do
    local outs = { op(21, "iron", 8, { d2 = 900 }), op(22, "iron", 8, { d2 = 100 }), op(23, "copper", 3, { d2 = 50 }) }
    local v = dc_view({ outposts = outs, workers_idle = 1 })
    local r1 = ZI.decide(ZI.input(v, { key = { order = { "iron", "copper" } } }, book, v.stock, nil))
    check(#r1.orders == 1 and r1.orders[1].kind == "iron" and r1.orders[1].outpost == 22, "fer d'abord, le plus proche (22)")
    local r2 = ZI.decide(ZI.input(v, { key = { order = { "copper", "iron" } } }, book, v.stock, nil))
    check(#r2.orders == 1 and r2.orders[1].kind == "copper", "ordre du besoin : cuivre d'abord")
    local v3 = dc_view({ outposts = outs, workers_idle = 3 })
    local r3 = ZI.decide(ZI.input(v3, { key = { order = { "iron", "copper" } } }, book, v3.stock, nil))
    check(#r3.orders == 3 and r3.orders[1].outpost == 22 and r3.orders[2].kind == "copper" and r3.orders[3].outpost == 21,
      "tour à tour : fer 22, cuivre 23, fer 21")
    local kinds = ZI.smelter_kinds({ "stone", "coal", "iron" })
    local only = true
    for _, k in ipairs(kinds) do if T.outposts[k].product == T.outposts[k].resource then only = false end end
    check(only and kinds[1] == "iron", "seules les fonderies (paire avec four), dans l'ordre du besoin")
  end

  section("6. Émission (pose, fabrication, jamais de minage)")
  do
    local goals = ZI.goals({ orders = { { kind = "iron", outpost = 22, tier = "thermique", items = ZI.tiers("iron")[1].kit, product = IRON_PLATE },
      { kind = "iron", outpost = 21, tier = "thermique", items = ZI.tiers("iron")[1].kit, product = IRON_PLATE } } })
    check(#goals == 2 and goals[1].key == "zero-idle:iron:1" and goals[2].key == "zero-idle:iron:2" and goals[1].fond == true,
      "buts de fond à clé stable par type et rang")
    local kit = ZI.tiers("iron")[1].kit
    local have = {}
    for _, it in ipairs(kit) do have[it[1]] = it[2] end
    local E = P.context(have, book, view({}), {})
    local proj = { id = 7, key = goals[1].key, prio = 61 }
    local st1 = P.EMIT.zero_idle(E, proj, goals[1])
    check(st1 == "ok" and #E.tasks == 1 and E.tasks[1].kind == "extend" and E.tasks[1].key == "extend:22" and E.tasks[1].prio == 61 + P.FINISH_BONUS,
      "kit au stock : tâche « extend:22 » posée")
    local st2 = P.EMIT.zero_idle(E, proj, goals[1])
    check(st2 == "en_cours" and #E.tasks == 1, "même avant-poste : une seule pose")
    local E2 = P.context({ [IRON_PLATE] = 1000, [STONE] = 1000, [FUEL] = 1000 }, book, view({}), {})
    local st3 = P.EMIT.zero_idle(E2, proj, goals[2])
    local crafts, mines = 0, 0
    for _, t in ipairs(E2.tasks) do
      if t.kind == "craft" then crafts = crafts + 1 end
      if t.kind == "mine" then mines = mines + 1 end
    end
    check(st3 == "matiere" and crafts > 0 and mines == 0 and next(E2.raw) == nil, "plaques au stock : foreuses et fours FABRIQUÉS, aucun minage")
    local E3 = P.context({ [IRON_PLATE] = 3 }, book, view({}), {})
    local st4 = P.EMIT.zero_idle(E3, proj, goals[2])
    check(st4 == "matiere" and #E3.tasks == 0 and next(E3.raw) == nil, "stock virtuel insuffisant : rien, aucun manque brut (pas de minage à la main)")
  end

  section("7. Journal [FO-ZERO-IDLE]")
  do
    local acc = ZI.note(nil, ZI.summary({ idle = 3, fond = 1, left = 2, orders = { { kind = "iron", outpost = 2, tier = "thermique" }, { kind = "copper", outpost = 3, tier = "thermique" } },
      causes = { iron = "stock" }, missing = { [FUEL] = 40 } }))
    acc = ZI.note(acc, ZI.summary({ idle = 0, fond = 0, left = 0, orders = {}, causes = {}, missing = {} }))
    local line = ZI.line("player", 25, acc)
    check(line ~= nil and line:find("[FO-ZERO-IDLE] player minute 25", 1, true) ~= nil and line:find("emis 2", 1, true) ~= nil
      and line:find("iron=stock(x1)", 1, true) ~= nil and line:find(FUEL .. " 40", 1, true) ~= nil, "ligne de la minute : émis, cause, manque (" .. tostring(line) .. ")")
    check(ZI.line("player", 26, ZI.note(nil, ZI.summary({ idle = 0, fond = 0, left = 0, orders = {}, causes = {}, missing = {} }))) == nil,
      "aucun PNJ libre de la minute : aucune ligne")
    local all = ZI.line("player", 27, ZI.note(nil, ZI.summary({ idle = 2, fond = 0, left = 0, orders = { { kind = "iron", outpost = 2, tier = "thermique" } }, causes = {}, missing = {} })))
    check(all ~= nil and all:find("cause aucune", 1, true) ~= nil, "tous servis : « cause aucune »")
  end

  section("8. Déterminisme, données pures")
  do
    local outs = { op(11, "iron", 8), op(12, "iron", 8), op(13, "copper", 3) }
    local a = ZI.decide(kinds_of(ZI, { outposts = outs, workers_idle = 4 }))
    local b = ZI.decide(kinds_of(ZI, { outposts = outs, workers_idle = 4 }))
    local sa, sb = {}, {}
    for _, o in ipairs(a.orders) do sa[#sa + 1] = o.kind .. o.outpost end
    for _, o in ipairs(b.orders) do sb[#sb + 1] = o.kind .. o.outpost end
    check(table.concat(sa, ",") == table.concat(sb, ",") and #sa > 0, "même entrée, même décision")
    check(deep_ok(ZI.summary(a)), "résumé gardé dans global : nombres, chaînes, tables")
  end
  return failures - f0
end

---------------------------------------------------------------------------------------------------
section("1. Le cas du DC : PNJ libres, fer et cuivre saturés, fonderies avec place")
---------------------------------------------------------------------------------------------------
do
  ZI0.ON = false
  local st = C.new_state(0)
  local before = C.think(dc_view(), book, st, dc_ctx())
  check(before.ia3.saturated[IRON_PLATE] and before.ia3.saturated[COPPER_PLATE], "fer et cuivre saturés (stock ≥ 3 × besoin)")
  check(grows(before) == 0, "règle d'avant : AUCUN agrandissement ni foreuse fabriquée (défaut reproduit ; rendu " .. grows(before) .. ")")
  ZI0.ON = true
  local st2 = C.new_state(0)
  local after = C.think(dc_view(), book, st2, dc_ctx())
  check(grows(after) > 0, "règle ZERO-IDLE : foreuses et fours fabriqués ou posés (" .. grows(after) .. " tâche(s))")
  local zmine = count(after, function(t) return t.kind == "mine" and type(t.why) == "string" and t.why:find("zero-idle", 1, true) == 1 end)
  check(zmine == 0, "aucun minage à la main pour un agrandissement")
  check(st2.zi_last and st2.zi_last.emitted == 2 and deep_ok(st2.zi_last), "résumé de la pensée : 2 agrandissements (fer, cuivre), données pures")
  local stown = C.new_state(0)
  local busy = C.think(dc_view({ workers_idle = 0 }), book, stown, dc_ctx())
  check(grows(busy) == 0 and stown.zi_last.emitted == 0, "aucun PNJ libre : rien de plus")
  -- une faction aussi (Ambre, 40 min : 4 510 fers libres, 6 PNJ sur 8 libres)
  local stf = C.new_state(0)
  local fv = dc_view({ is_player = false, workers = 8, workers_idle = 6, stock = { [IRON_PLATE] = 4500, [COPPER_PLATE] = 2000, [STONE] = 3000, [FUEL] = 1400 } })
  local fp = C.think(fv, book, stf, { tick = 0, is_player = false, weights = B.weights({}, nil), reach = { ["iron-ore"] = 60 } })
  check(stf.zi_last.emitted >= 2 and grows(fp) > 0, "une faction : agrandissements émis (" .. stf.zi_last.emitted .. ")")
end

suite(ZI0)

---------------------------------------------------------------------------------------------------
section("8 bis. Aucun nom du jeu, aucun pairs() décisionnel")
---------------------------------------------------------------------------------------------------
local fh = io.open("shared/ai3/zero_idle.lua", "rb")
local SRC = fh:read("*a")
fh:close()
do
  local names = { T.DRILL, T.DRILL_ELECTRIC, T.SMELTER, T.fuel, IRON_PLATE, COPPER_PLATE, "gun-turret" }
  local hits = {}
  for _, n in ipairs(names) do if n and SRC:find('"' .. n .. '"', 1, true) then hits[#hits + 1] = n end end
  check(#hits == 0, "aucun nom du jeu dans le module (" .. table.concat(hits, " ") .. ")")
  local code = SRC:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local n_pairs = 0
  for _ in code:gmatch("[^i]pairs%(") do n_pairs = n_pairs + 1 end
  check(n_pairs == 1 and not code:find("math.random", 1, true), "pairs() dans sorted_keys seulement, aucun hasard")
end

---------------------------------------------------------------------------------------------------
section("9. Coût : pire cas en instructions (budget 5 ms ≈ 300 000 instructions, ~60 M/s)")
---------------------------------------------------------------------------------------------------
do
  local outs = {}
  for i = 1, 40 do outs[#outs + 1] = op(100 + i, (i % 2 == 0) and "iron" or "copper", 8, { d2 = (i * 7919) % 1000 }) end
  local big = { [IRON_PLATE] = 100000, [STONE] = 100000, [FUEL] = 100000, [COPPER_PLATE] = 100000 }
  local worst = 0
  for _, idle in ipairs({ 1, 10, 30, 60 }) do
    local v = dc_view({ outposts = outs, stock = big, workers_idle = idle, workers_fond = idle })
    local s = { key = { order = { "iron", "copper" } } }
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 1000)
    local r = ZI0.decide(ZI0.input(v, s, book, v.stock, nil))
    local g = ZI0.goals(r)
    debug.sethook()
    if n > worst then worst = n end
    if not QUIET then print(string.format("  %d PNJ libres + %d au fond, 40 avant-postes : %d agrandissement(s), %d plans, %d milliers d'instructions", idle, idle, #g, r.plans, n)) end
  end
  check(worst * 1000 <= 300000, string.format("pire cas %d milliers d'instructions <= 300 (5 ms)", worst))
  -- La pensée ENTIÈRE (C.think), règle allumée contre éteinte : le surcoût comprend l'émission (prises, fabrications des kits).
  local function think_cost(on, idle)
    ZI0.ON = on
    local st = C.new_state(0)
    local v = dc_view({ outposts = outs, stock = big, workers = 30, workers_idle = idle, workers_fond = 0 })
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 1000)
    C.think(v, book, st, dc_ctx())
    debug.sethook()
    ZI0.ON = true
    return n
  end
  local dworst = 0
  for _, idle in ipairs({ 5, 30 }) do
    local off, on = think_cost(false, idle), think_cost(true, idle)
    if not QUIET then print(string.format("  pensée entière, %d PNJ libres : %d milliers d'instructions éteinte, %d allumée (+%d)", idle, off, on, on - off)) end
    if on - off > dworst then dworst = on - off end
  end
  check(dworst * 1000 <= 300000, string.format("surcoût de la pensée entière %d milliers d'instructions <= 300 (5 ms)", dworst))
end

---------------------------------------------------------------------------------------------------
section("10. Mutants")
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "plafond des PNJ libres ignoré", "local left = hands\n", "local left = 1e9\n" },
  { "fond doux non compté", "local hands = math.max(0, (inp.idle or 0) + (inp.fond or 0))", "local hands = math.max(0, inp.idle or 0)" },
  { "stock ignoré", "if next(p.raw) ~= nil then\n              s.done = true", "if false then\n              s.done = true" },
  { "stock non décompté", "avail = p.avail\n", "\n" },
  { "combustible confondu", "res.causes[k.kind] = only_fuel and \"combustible\" or \"stock\"", "res.causes[k.kind] = \"stock\"" },
  { "agrandissement pris ignoré", "if (k.open or {})[c.id] then s.n_open = s.n_open + 1", "if false then s.n_open = s.n_open + 1" },
  { "défendre d'abord ignoré", "elseif (k.no_go or {})[c.id] then s.n_nogo = s.n_nogo + 1", "elseif false then s.n_nogo = s.n_nogo + 1" },
  { "menace ignorée", "if inp.threat then", "if false then" },
  { "palier refusé ignoré", "if t.ok then tier = t break end", "tier = t break" },
  { "avant-poste plein compté", "if o.kind == kind and not o.full and", "if o.kind == kind and" },
  { "le plus loin d'abord", "if a.d2 ~= b.d2 then return a.d2 < b.d2 end", "if a.d2 ~= b.d2 then return a.d2 > b.d2 end" },
  { "pose sans prise au stock", "if P.take(E, g.items) then", "if true then" },
  { "minage à la main pour le kit", "if next(p.raw) ~= nil then return \"matiere\" end", "" },
  { "clé instable", "ZI.KEY .. o.kind .. \":\" .. rank[o.kind]", "ZI.KEY .. tostring(o.outpost)" },
  { "ligne sans cause", "acc.causes[c] = (acc.causes[c] or 0) + 1", "" },
  { "couverture électrique ignorée", "ok = not (cov or off),", "ok = not off," },
  { "bascule électrique ignorée", "local off = thermal_off and thermal_off[kind]", "local off = nil" },
}
local refused, kept = 0, {}
local saved_p, saved_f0 = passes, failures
QUIET = true
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local msrc = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local chunk = load(msrc, "=zero_idle_mutant", "t")
    local nf = 1
    if chunk then
      local ok, mz = pcall(chunk)
      if ok and mz then
        local ok2, r = pcall(suite, mz)
        nf = ok2 and r or 1
      end
    end
    if nf > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
-- le module d'origine reprend sa place (P.EMIT.zero_idle)
dofile("shared/ai3/zero_idle.lua")
QUIET = false
passes, failures = saved_p, saved_f0
local saved_f = failures
failures = 0
check(#kept == 0, "mutants NON refusés : " .. table.concat(kept, " ; "))
failures = saved_f + failures
print(string.format("[ZERO-IDLE] mutants refusés : %d sur %d", refused, #MUTANTS))

print(string.format("[ZERO-IDLE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
