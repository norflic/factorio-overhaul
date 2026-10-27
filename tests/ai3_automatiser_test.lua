--[[
  Lot IA3-e « automatiser ce qui revient » : banc HORS JEU de la règle main → machine (shared/ai3/automatiser.lua) et de
  son branchement dans le cerveau par besoins (shared/ai3/cerveau.lua). Lancement : lua5.2 tests/ai3_automatiser_test.lua
  (depuis la racine du mod).

  Sections :
    1. mesures de la fenêtre (charge, débit, logistique) ;
    2. décision : fenêtre incomplète, charge faible, demande dimensionnée au débit, menace (horizon 5 min), objet
       impossible (recherche), ordre fer et cuivre d'abord, un module ouvert à la fois, refus (même contexte / contexte
       changé), modules finis ;
    3. coût et gain : la centrale comptée au premier module électrique, le prix mesuré des plaques, la logistique qui reste ;
    4. le cerveau : un module demandé est un PROJET (compté dans K), ses manques sont des sous-buts fabriqués à la main,
       un chantier bloqué est un projet bloqué, un module fini compte comme capacité d'extraction et retire les tournées
       des avant-postes qu'il remplace ;
    5. déterminisme (deux décisions identiques) ;
    6. mutants : chaque règle retirée fait échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local B = require("shared.ai3.buts")
local P = require("shared.ai3.projets")
local C = require("shared.ai3.cerveau")
local A = require("shared.ai3.automatiser")
local MAX_OPEN0 = A.MAX_OPEN -- valeur du lot (les mutants changent A.MAX_OPEN, pas les attentes)

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end

local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)
-- Livre « début de partie » : sans la recette du poteau moyen (technologie electric-energy-distribution-1).
local book_early = Book.new(recipes, { allowed = function(n) return n ~= "medium-electric-pole" and n ~= "big-electric-pole" end })

local function win(n, loads, mades, logis)
  local w = {}
  for i = 1, n do
    local b = { m = i, load = {}, made = {}, logi = {} }
    for k, v in pairs(loads or {}) do b.load[k] = v end
    for k, v in pairs(mades or {}) do b.made[k] = v end
    for k, v in pairs(logis or {}) do b.logi[k] = v end
    w[i] = b
  end
  return w
end
local function all_ok() return true end
local function verdict(res, product)
  for _, v in ipairs(res.verdicts) do if v.product == product then return v end end
  return nil
end
local function req(res, product)
  for _, r in ipairs(res.requests) do if r.product == product then return r end end
  return nil
end

local function run_all()
---------------------------------------------------------------------------------------------------
section("1. Mesures de la fenêtre")
---------------------------------------------------------------------------------------------------
do
  local w = win(12, { ["iron-plate"] = 3600 }, { ["iron-plate"] = 50 }, { ["iron-plate"] = 360 })
  local L, D, Lres, n = A.measure(w, "iron-plate")
  check(n == A.WINDOW, "fenêtre : les " .. A.WINDOW .. " dernières minutes seulement (" .. n .. ")")
  check(math.abs(L - 1) < 1e-9 and math.abs(D - 50) < 1e-9 and math.abs(Lres - 0.1) < 1e-9,
    string.format("charge 1 PNJ, débit 50/min, logistique 0,1 PNJ (%.3f %.1f %.3f)", L, D, Lres))
  local L0, D0, _, n0 = A.measure({}, "iron-plate")
  check(L0 == 0 and D0 == 0 and n0 == 0, "fenêtre vide : rien")
end

---------------------------------------------------------------------------------------------------
section("2. Décision")
---------------------------------------------------------------------------------------------------
-- Cas type : 2 PNJ passent leur temps aux plaques de fer (tournées, fonte, minage), 60 plaques/min livrées.
local hot = win(10, { ["iron-plate"] = 7200 }, { ["iron-plate"] = 60 })
do
  local r = A.decide({ window = win(9, { ["iron-plate"] = 7200 }, { ["iron-plate"] = 60 }), obtainable = all_ok, book = book })
  check(verdict(r, "iron-plate").verdict == "attente" and #r.requests == 0, "fenêtre incomplète (9 min) : on attend")
  local rr = A.decide({ window = win(5, { ["iron-plate"] = 7200 }, { ["iron-plate"] = 60 }), book = book_early,
    obtainable = function(i) return book_early:handcraftable(i) end })
  check(#rr.requests == 0 and verdict(rr, "iron-plate").verdict == "recherche" and rr.wanted["medium-electric-pole"],
    "demi-fenêtre (5 min) : l'objet impossible est déjà voulu (la recherche prend du temps), aucune demande")
  local rr4 = A.decide({ window = win(4, { ["iron-plate"] = 7200 }, { ["iron-plate"] = 60 }), book = book_early,
    obtainable = function(i) return book_early:handcraftable(i) end })
  check(next(rr4.wanted) == nil, "4 min de fenêtre : rien n'est encore voulu")
  local r2 = A.decide({ window = win(10, { ["iron-plate"] = 600 }, { ["iron-plate"] = 60 }), obtainable = all_ok, book = book })
  check(verdict(r2, "iron-plate").verdict == "non" and #r2.requests == 0, "charge 0,17 PNJ : à la main (pas de module)")
  local r3 = A.decide({ window = hot, obtainable = all_ok, book = book })
  local q = req(r3, "iron-plate")
  check(q ~= nil and q.gen == "smelter" and q.args[2] == "iron-ore", "charge 2 PNJ : fonderie de fer DEMANDÉE")
  check(q and q.rate_nom >= 60 * 1.25 - 1e-6 and q.args[3] == 2,
    string.format("dimensionnée au débit + 25 %% : %s rangées, %.1f plaques/min", q and tostring(q.args[3]) or "?", q and q.rate_nom or 0))
  local v = verdict(r3, "iron-plate")
  check(v.T and v.T <= A.H_SAFE and v.G > 0 and v.C > 0, string.format("retour %.1f min <= %d (coût %.0f PNJ-s, gain %.2f PNJ)", v.T or -1, A.H_SAFE, v.C or 0, v.G or 0))
  -- Menace : horizon 5 min.
  local r4 = A.decide({ window = hot, threatened = true, obtainable = all_ok, book = book })
  check(#r4.requests == 0 and verdict(r4, "iron-plate").verdict == "non", "menacé : horizon 5 min, le module attend (" .. tostring(verdict(r4, "iron-plate").why) .. ")")
  -- Menacé, mais les matériaux sont au coffre (seule la pose coûte) : retour sous 5 min, demandé.
  local full = {}
  for k, n in pairs(q.items) do full[k] = n + 50 end
  full["steam-engine"], full["boiler"], full["offshore-pump"], full["burner-inserter"] = 2, 1, 1, 2
  local r5 = A.decide({ window = hot, threatened = true, obtainable = all_ok, book = book, stock = full })
  check(req(r5, "iron-plate") ~= nil, "menacé, matériaux au coffre : retour sous 5 min, demandé (" .. tostring(verdict(r5, "iron-plate").why) .. ")")
  -- Objet impossible : le poteau moyen sans sa technologie.
  local r6 = A.decide({ window = hot, obtainable = function(i) return book_early:handcraftable(i) end, book = book_early })
  check(#r6.requests == 0 and verdict(r6, "iron-plate").verdict == "recherche" and r6.wanted["medium-electric-pole"],
    "poteau moyen impossible : verdict recherche, objet voulu rendu (" .. tostring(verdict(r6, "iron-plate").why) .. ")")
  -- Seuil de charge : 0,24 PNJ, module tout près et matériaux au coffre (retour sous 20 min) : à la main quand même ;
  -- 0,30 PNJ : demandé.
  local r5b = A.decide({ window = win(10, { ["iron-plate"] = 0.24 * 3600 }, { ["iron-plate"] = 10 }), obtainable = all_ok,
    book = book, stock = full, dist = 10, has_plant = true })
  check(#r5b.requests == 0 and verdict(r5b, "iron-plate").verdict == "non", "charge 0,24 PNJ sous le seuil : à la main (" .. tostring(verdict(r5b, "iron-plate").why) .. ")")
  local r5c = A.decide({ window = win(10, { ["iron-plate"] = 0.30 * 3600 }, { ["iron-plate"] = 10 }), obtainable = all_ok,
    book = book, stock = full, dist = 10, has_plant = true })
  check(req(r5c, "iron-plate") ~= nil, "charge 0,30 PNJ, retour sous 20 min : demandé (" .. tostring(verdict(r5c, "iron-plate").why) .. ")")
  -- Ordre : fer d'abord ; les packs attendent même s'ils pèsent plus.
  local both = win(10, { ["iron-plate"] = 7200, ["automation-science-pack"] = 3 * 3600 }, { ["iron-plate"] = 60, ["automation-science-pack"] = 10 })
  local r7 = A.decide({ window = both, obtainable = all_ok, book = book })
  check(req(r7, "iron-plate") ~= nil and req(r7, "automation-science-pack") == nil and verdict(r7, "automation-science-pack").verdict == "ordre",
    "ordre : fonderie de fer d'abord, les packs attendent leur rang")
  -- Fer « non » (charge faible) : les packs passent.
  local packs = win(10, { ["iron-plate"] = 300, ["automation-science-pack"] = 3 * 3600 }, { ["iron-plate"] = 60, ["automation-science-pack"] = 10 })
  local r8 = A.decide({ window = packs, obtainable = all_ok, book = book })
  check(req(r8, "automation-science-pack") ~= nil, "fer non rentable : les packs sont demandés (" .. tostring(verdict(r8, "automation-science-pack").why) .. ")")
  -- A.MAX_OPEN modules ouverts : rien d'autre (le cuivre attend) ; un de moins : le cuivre est demandé avec le fer.
  local cu = win(10, { ["iron-plate"] = 7200, ["copper-plate"] = 7200 }, { ["iron-plate"] = 60, ["copper-plate"] = 60 })
  local opened = {}
  for i = 1, MAX_OPEN0 do opened[i] = { product = "iron-plate", state = "chantier" } end
  local r9 = A.decide({ window = cu, obtainable = all_ok, book = book, modules = opened })
  check(#r9.requests == 0 and verdict(r9, "iron-plate").verdict == "en_cours" and verdict(r9, "copper-plate").verdict == "attente",
    MAX_OPEN0 .. " module(s) ouvert(s) : le cuivre attend (" .. tostring(verdict(r9, "copper-plate").why) .. ")")
  local r9b = A.decide({ window = cu, obtainable = all_ok, book = book })
  check(#r9b.requests == math.min(2, MAX_OPEN0) and req(r9b, "iron-plate") ~= nil,
    "fer et cuivre rentables : " .. math.min(2, MAX_OPEN0) .. " demande(s) à la fois, le fer d'abord (" .. #r9b.requests .. ")")
  -- Refus : même contexte, coût infini ; contexte changé, revu.
  local mods = { { product = "iron-plate", state = "refuse", reason = "pas de lot", sig = "r5:t3:e0" } }
  local r10 = A.decide({ window = hot, obtainable = all_ok, book = book, modules = mods, sig = "r5:t3:e0" })
  check(#r10.requests == 0 and verdict(r10, "iron-plate").verdict == "refuse", "refusé, même contexte : pas de nouvelle demande")
  local r11 = A.decide({ window = hot, obtainable = all_ok, book = book, modules = mods, sig = "r5:t4:e0" })
  check(req(r11, "iron-plate") ~= nil, "refusé, contexte changé (technologie) : demandé de nouveau")
  -- Modules finis : au plus A.MAX_PER_PRODUCT ; un fini et la charge reste : un second.
  local r12 = A.decide({ window = hot, obtainable = all_ok, book = book, modules = { { product = "iron-plate", state = "fini" } } })
  check(req(r12, "iron-plate") ~= nil, "un module fini, la charge reste forte : un second est demandé")
  local fin2 = { { product = "iron-plate", state = "fini" }, { product = "iron-plate", state = "fini" } }
  local r13 = A.decide({ window = hot, obtainable = all_ok, book = book, modules = fin2 })
  check(req(r13, "iron-plate") == nil and verdict(r13, "iron-plate").verdict == "fini", "deux modules finis : plus de demande")
end

---------------------------------------------------------------------------------------------------
section("3. Coût et gain")
---------------------------------------------------------------------------------------------------
do
  local meth = A.METHODS[1]
  local g = A.sized(meth, 75)
  local C1, items1, n1 = A.cost(meth, g, { book = book, has_plant = false })
  local C2, items2, n2 = A.cost(meth, g, { book = book, has_plant = true })
  check(C1 > C2 and n1 > n2 and (items1["steam-engine"] or 0) >= 1 and not items2["steam-engine"],
    string.format("sans centrale, le premier module électrique en paie une (%.0f contre %.0f PNJ-s)", C1, C2))
  check((items1["electric-mining-drill"] or 0) >= 4 and (items1["transport-belt"] or 0) >= A.BELT_LEN,
    "fonderie de fer : foreuses électriques et tapis comptés (voie de minerai au-delà de 60/min)")
  local Cp = A.cost(meth, g, { book = book, has_plant = true, price = { ["iron-plate"] = 4 } })
  check(Cp > C2, "plaques plus chères à la main (mesure) : module plus cher")
  local stock = {}
  for k, v in pairs(items2) do stock[k] = v end
  local Cs = A.cost(meth, g, { book = book, has_plant = true, stock = stock })
  check(Cs < C2, "matériaux au coffre : seul le chantier coûte")
  local _, _, _, det = A.cost(meth, g, { book = book, has_plant = true })
  local res = A.residual(det, 75, A.DIST)
  check(res > 0 and res < 1, string.format("logistique qui reste (quais) : %.2f PNJ", res))
end

---------------------------------------------------------------------------------------------------
section("4. Le cerveau : projets « module »")
---------------------------------------------------------------------------------------------------
local function view(over)
  local v = {
    tech = 1, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
    pending = {}, sites = {}, smelters = 4, smelters_pending = 0, smelter_task = false, smelter_output = 0,
    smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 20, soldiers_max = 30, workers = 8,
    workers_max = 10, workers_idle = 2, threatened = false, open = {}, workers_wanted = 8, no_research = true,
    ladder = T.ladder, hq_turrets = 0, defend_first = true,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function op(id, kind, drills, over)
  local o = { id = id, kind = kind, drills = drills, full = false, turrets = 1, coal_needed = 0, fuel_low = false,
    output = 60, idle_ticks = 0, has_task = false, has_fortify = false }
  for k, x in pairs(over or {}) do o[k] = x end
  return o
end
local function count(plan, pred)
  local n = 0
  for _, t in ipairs(plan.tasks) do if pred(t) then n = n + 1 end end
  return n
end
local base_stock = { ["iron-plate"] = 300, ["copper-plate"] = 200, coal = 300, stone = 200, ["firearm-magazine"] = 80 }
local outs = { op(1, "coal", 4), op(2, "iron", 8, { output = 80 }), op(3, "copper", 3), op(4, "stone", 2) }
local function ctx_of(auto)
  return { tick = 3600 * 20, weights = B.weights({}, nil), reach = { ["iron-ore"] = 48, ["copper-ore"] = 48, coal = 48, stone = 48 },
    army_target = 18, auto = auto }
end
do
  -- (a) module en réserve, il manque des foreuses électriques et des bras : projet actif, sous-buts fabriqués.
  local st = C.new_state(0)
  local auto = { modules = { { product = "iron-plate", state = "reserve", missing = { { "electric-mining-drill", 4 }, { "inserter", 6 } } } },
    cap = {}, covered = {} }
  local plan = C.think(view({ stock = base_stock, outposts = outs }), book, st, ctx_of(auto))
  local proj = nil
  for _, p in ipairs(st.projects) do if p.key == "auto:iron-plate" then proj = p end end
  check(proj ~= nil and proj.state == "actif", "un module demandé est un PROJET actif du cerveau (" .. tostring(proj and proj.state) .. ")")
  local crafts = count(plan, function(t) return t.kind == "craft" and t.item == "electric-mining-drill" and t.ia3 == (proj and proj.id) end)
  check(crafts >= 1, "ses manques (foreuses électriques) sont fabriqués à la main pour lui (" .. crafts .. " tâche(s))")
  check(count(plan, function(t) return t.kind == "craft" and t.item == "inserter" and t.why == "auto:iron-plate" end) >= 1,
    "… et ses bras, avec sa raison")
  -- Compté dans K : 8 PNJ, K = 4.
  check(plan.ia3.K == P.K(8) and plan.ia3.active <= plan.ia3.K, "compté dans les K projets ouverts (K = " .. plan.ia3.K .. ")")
  -- (b) chantier bloqué : projet bloqué, cause lisible, il ne prend pas de place.
  local st2 = C.new_state(0)
  local auto2 = { modules = { { product = "iron-plate", state = "bloque", reason = "fantome refuse (stone-furnace en 3,4)" } }, cap = {}, covered = {} }
  C.think(view({ stock = base_stock, outposts = outs }), book, st2, ctx_of(auto2))
  local p2 = nil
  for _, p in ipairs(st2.projects) do if p.key == "auto:iron-plate" then p2 = p end end
  check(p2 and p2.state == "bloque" and p2.cause and p2.cause:find("^module:fantome refuse"), "chantier bloqué : projet bloqué, raison lisible (" .. tostring(p2 and p2.cause) .. ")")
  -- (c) module fini, fer couvert : plus de tournée ordinaire à l'avant-poste de fer ; ses tournées de charbon restent.
  local st3 = C.new_state(0)
  local v3 = view({ stock = base_stock, outposts = { op(1, "coal", 4, { output = 80 }), op(2, "iron", 8, { output = 80 }), op(3, "copper", 3), op(4, "stone", 2) } })
  local plan_a = C.think(v3, book, C.new_state(0), ctx_of({ modules = {}, cap = {}, covered = {} }))
  local svc_iron_a = count(plan_a, function(t) return t.kind == "service" and t.outpost == 2 end)
  local auto3 = { modules = { { product = "iron-plate", state = "fini" } }, cap = { iron = 0.94 }, covered = { ["iron-plate"] = true } }
  local plan3 = C.think(v3, book, st3, ctx_of(auto3))
  local svc_iron = count(plan3, function(t) return t.kind == "service" and t.outpost == 2 and t.prio < 90 end)
  local svc_coal = count(plan3, function(t) return t.kind == "service" and t.outpost == 1 end)
  check(svc_iron_a >= 1, "témoin : l'avant-poste de fer a sa tournée (" .. svc_iron_a .. ")")
  check(svc_iron == 0, "module fini, fer couvert : plus de tournée ordinaire à l'avant-poste de fer")
  check(svc_coal == count(plan_a, function(t) return t.kind == "service" and t.outpost == 1 end), "les tournées de charbon ne changent pas")
  -- (d) capacité : sans avant-poste de fer, un module fini empêche l'amorçage d'un avant-poste de fer.
  local v4 = view({ stock = base_stock, outposts = { op(1, "coal", 4), op(3, "copper", 3), op(4, "stone", 2) } })
  local s4 = C.situation(v4, C.new_state(0), ctx_of({ modules = {}, cap = { iron = 0.94 }, covered = {} }))
  local g4 = B.generate(s4, C.new_state(0))
  local wants_iron = false
  for _, g in ipairs(g4) do if g.key == "extraction:iron" then wants_iron = true end end
  local s4b = C.situation(v4, C.new_state(0), ctx_of(nil))
  local g4b = B.generate(s4b, C.new_state(0))
  local wants_b = false
  for _, g in ipairs(g4b) do if g.key == "extraction:iron" then wants_b = true end end
  check(wants_b and not wants_iron, "module fini = capacité d'extraction : plus d'avant-poste de fer à amorcer")
  -- (e) automatisation éteinte (ctx.auto nil) : le plan est celui d'IA-V2, à l'octet près.
  local function sig(p)
    local o = {}
    for _, t in ipairs(p.tasks) do o[#o + 1] = t.key .. "@" .. tostring(t.prio) end
    return table.concat(o, ";")
  end
  local pa = C.think(view({ stock = base_stock, outposts = outs }), book, C.new_state(0), ctx_of(nil))
  local pb = C.think(view({ stock = base_stock, outposts = outs }), book, C.new_state(0), ctx_of({ modules = {}, cap = {}, covered = {} }))
  check(sig(pa) == sig(pb), "aucun module : même plan qu'avant le lot (neutralité)")
end

---------------------------------------------------------------------------------------------------
section("5. Déterminisme")
---------------------------------------------------------------------------------------------------
do
  local function dump(r)
    local o = {}
    for _, v in ipairs(r.verdicts) do o[#o + 1] = v.product .. ":" .. v.verdict .. ":" .. tostring(v.why) end
    for _, q in ipairs(r.requests) do o[#o + 1] = q.product .. ":" .. table.concat((function() local a = {} for i, x in ipairs(q.args) do a[i] = tostring(x) end return a end)(), ",") end
    return table.concat(o, "|")
  end
  local w = win(10, { ["iron-plate"] = 7200, ["copper-plate"] = 5000 }, { ["iron-plate"] = 60, ["copper-plate"] = 40 })
  local d1 = dump(A.decide({ window = w, obtainable = all_ok, book = book }))
  A.reset_cache()
  local d2 = dump(A.decide({ window = w, obtainable = all_ok, book = book }))
  check(d1 == d2 and #d1 > 0, "deux décisions sur les mêmes mesures (cache vidé entre les deux) : identiques")
end
end -- run_all

run_all()

---------------------------------------------------------------------------------------------------
-- 6. Mutants : chaque règle retirée fait échouer au moins un contrôle.
---------------------------------------------------------------------------------------------------
print("== 6. Mutants")
local function mutant(name, patch, unpatch)
  local p0, f0 = passes, failures
  quiet = true
  patch()
  local ok, err = pcall(run_all)
  unpatch()
  A.reset_cache()
  local caught = (not ok) or failures > f0
  quiet = false
  passes, failures = p0, f0
  check(caught, "mutant « " .. name .. " » refusé" .. (ok and "" or (" (erreur : " .. tostring(err) .. ")")))
end
local L0 = A.LOAD_MIN
mutant("seuil de charge nul", function() A.LOAD_MIN = 0 end, function() A.LOAD_MIN = L0 end)
local HT = A.H_THREAT
mutant("menace ignorée (horizon 20 min menacé)", function() A.H_THREAT = A.H_SAFE end, function() A.H_THREAT = HT end)
local MO = A.MAX_OPEN
mutant("modules ouverts sans plafond", function() A.MAX_OPEN = 9 end, function() A.MAX_OPEN = MO end)
local RW = A.RESEARCH_WINDOW
mutant("recherche à la fenêtre pleine seulement", function() A.RESEARCH_WINDOW = A.WINDOW end, function() A.RESEARCH_WINDOW = RW end)
local MPP = A.MAX_PER_PRODUCT
mutant("modules finis sans plafond", function() A.MAX_PER_PRODUCT = 99 end, function() A.MAX_PER_PRODUCT = MPP end)
local W0 = A.WINDOW
mutant("fenêtre d'une minute", function() A.WINDOW = 1 end, function() A.WINDOW = W0 end)
local meth0 = {}
for i, m in ipairs(A.METHODS) do meth0[i] = m end
mutant("sans ordre des rangs", function() for _, m in ipairs(A.METHODS) do m.rank0 = m.rank; m.rank = 1 end end,
  function() for _, m in ipairs(A.METHODS) do m.rank = m.rank0; m.rank0 = nil end end)
local cost0 = A.cost
mutant("coût nul", function() A.cost = function(meth, g, ctx) local c, i, n, d = cost0(meth, g, ctx); return 0, i, n, d end end,
  function() A.cost = cost0 end)
local res0 = A.residual
mutant("logistique du module oubliée", function() A.residual = function() return 0 end end, function() A.residual = res0 end)
local emit0 = P.EMIT.module
mutant("projet module sans sous-buts", function() P.EMIT.module = function() return "en_cours" end end, function() P.EMIT.module = emit0 end)
local goals0 = A.goals
mutant("module hors des projets", function() A.goals = function(g) return g end end, function() A.goals = goals0 end)
local plant = A.PLANT
mutant("centrale jamais comptée", function() A.PLANT = { gen = "inconnu", args = {} } end, function() A.PLANT = plant end)

print(string.format("[AI3-AUTOMATISER] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
