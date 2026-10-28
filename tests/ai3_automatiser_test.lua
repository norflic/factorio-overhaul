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
    2 bis. graphe des recettes et objets quelconques (consigne du DC du 27/10, 7 h 10) : profondeurs, module GÉNÉRÉ depuis
       la recette (tuyau), limites écrites (3 ingrédients, objet brut, recette de four), un objet attend SES entrées
       (tapis derrière les engrenages ; le cuivre ne retient plus les chargeurs), interface A.decide_item ;
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
  check(#r5b.requests == 0 and verdict(r5b, "iron-plate").verdict == "non" and tostring(verdict(r5b, "iron-plate").why):find("^charge"),
    "charge 0,24 PNJ sous le seuil : à la main (" .. tostring(verdict(r5b, "iron-plate").why) .. ")")
  local r5c = A.decide({ window = win(10, { ["iron-plate"] = 0.30 * 3600 }, { ["iron-plate"] = 10 }), obtainable = all_ok,
    book = book, stock = full, dist = 10, has_plant = true })
  check(req(r5c, "iron-plate") ~= nil, "charge 0,30 PNJ, retour sous 20 min : demandé (" .. tostring(verdict(r5c, "iron-plate").why) .. ")")
  -- 10 plaques/min visées (12,5 avec la marge) : une rangée suffirait, mais sa voie de minerai (0,625/s) serait un QUAI
  -- rempli depuis le coffre, où il n'y a pas de minerai (e6-usine) : la plus petite fonderie servie par tapis (2 rangées).
  local q5c = req(r5c, "iron-plate")
  local g5c = q5c and A.template(q5c.gen, q5c.args)
  check(q5c and q5c.args[3] == 2 and g5c and g5c.inputs["iron-ore"] >= A.BELT_FLOW - 1e-9,
    string.format("fonderie servie par tapis : %s rangée(s), minerai %.2f/s", q5c and tostring(q5c.args[3]) or "?", g5c and g5c.inputs["iron-ore"] or 0))
  -- Fonderie au débit de 150 plaques/min sans bras rapides : réduite à ce qu'un bras simple décharge à chaque quai.
  local big = win(10, { ["iron-plate"] = 3 * 3600 }, { ["iron-plate"] = 120 })
  local book_nofast = Book.new(recipes, { allowed = function(n) return n ~= "fast-inserter" end })
  local rb = A.decide({ window = big, obtainable = function(i) return book_nofast:handcraftable(i) end, book = book_nofast })
  local qb = req(rb, "iron-plate")
  check(qb ~= nil and qb.args[3] <= 2 and not qb.items["fast-inserter"],
    "sans bras rapides : fonderie réduite à " .. tostring(qb and qb.args[3]) .. " rangée(s), sans bras rapide (" .. tostring(verdict(rb, "iron-plate").why) .. ")")
  local rb2 = A.decide({ window = big, obtainable = all_ok, book = book })
  local qb2 = req(rb2, "iron-plate")
  check(qb2 ~= nil and qb2.args[3] >= 4 and qb2.items["fast-inserter"], "avec bras rapides : fonderie à la taille du débit (" .. tostring(qb2 and qb2.args[3]) .. " rangées)")
  -- Munitions (rang 2) : la rangée d'assembleurs demande des bras rapides ; sans leur technologie, recherche.
  local mag = win(10, { ["iron-plate"] = 300, ["firearm-magazine"] = 2 * 3600 }, { ["iron-plate"] = 60, ["firearm-magazine"] = 60 })
  local book_mag = Book.new(recipes, { allowed = function(n) return n ~= "fast-inserter" end })
  local rm = A.decide({ window = mag, obtainable = function(i) return book_mag:handcraftable(i) end, book = book_mag })
  check(verdict(rm, "firearm-magazine").verdict == "recherche" and rm.wanted["fast-inserter"] and #rm.requests == 0,
    "munitions : bras rapides impossibles, recherche voulue (" .. tostring(verdict(rm, "firearm-magazine").why) .. ")")
  local rm2 = A.decide({ window = mag, obtainable = all_ok, book = book })
  local qm = req(rm2, "firearm-magazine")
  check(qm ~= nil and qm.gen == "simple" and qm.args[2] >= 2, "munitions : 2 PNJ à la main, rangée d'assembleurs demandée (" .. tostring(verdict(rm2, "firearm-magazine").why) .. ")")
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
  local r9 = A.decide({ window = cu, obtainable = all_ok, book = book, mods = opened })
  check(#r9.requests == 0 and verdict(r9, "iron-plate").verdict == "en_cours" and verdict(r9, "copper-plate").verdict == "attente",
    MAX_OPEN0 .. " module(s) ouvert(s) : le cuivre attend (" .. tostring(verdict(r9, "copper-plate").why) .. ")")
  local r9b = A.decide({ window = cu, obtainable = all_ok, book = book })
  check(#r9b.requests == math.min(2, MAX_OPEN0) and req(r9b, "iron-plate") ~= nil,
    "fer et cuivre rentables : " .. math.min(2, MAX_OPEN0) .. " demande(s) à la fois, le fer compris (" .. #r9b.requests .. ")")
  -- Refus : même contexte, coût infini ; contexte changé, revu.
  local mods = { { product = "iron-plate", state = "refuse", reason = "pas de lot", sig = "r5:t3:e0" } }
  local r10 = A.decide({ window = hot, obtainable = all_ok, book = book, mods = mods, sig = "r5:t3:e0" })
  check(#r10.requests == 0 and verdict(r10, "iron-plate").verdict == "refuse", "refusé, même contexte : pas de nouvelle demande")
  local r11 = A.decide({ window = hot, obtainable = all_ok, book = book, mods = mods, sig = "r5:t4:e0" })
  check(req(r11, "iron-plate") ~= nil, "refusé, contexte changé (technologie) : demandé de nouveau")
  -- Modules finis : au plus A.MAX_PER_PRODUCT ; un fini et la charge reste : un second.
  local r12 = A.decide({ window = hot, obtainable = all_ok, book = book, mods = { { product = "iron-plate", state = "fini" } } })
  check(req(r12, "iron-plate") ~= nil, "un module fini, la charge reste forte : un second est demandé")
  local r12b = A.decide({ window = hot, obtainable = all_ok, book = book, mods = { { product = "iron-plate", state = "fini", finished_m = 6 } } })
  check(req(r12b, "iron-plate") == nil and verdict(r12b, "iron-plate").verdict == "attente",
    "module fini à la minute 6 : la charge d'avant ne compte pas, on attend une fenêtre après lui (" .. tostring(verdict(r12b, "iron-plate").why) .. ")")
  local r12h = A.decide({ window = hot, obtainable = all_ok, book = book, hold = "repli jusqu'a 50 min" })
  check(#r12h.requests == 0 and verdict(r12h, "iron-plate").verdict == "attente", "repli de l'équipe (réserves affamées) : aucune demande (" ..
    tostring(verdict(r12h, "iron-plate").why) .. ")")
  local fin2 = { { product = "iron-plate", state = "fini" }, { product = "iron-plate", state = "fini" } }
  local r13 = A.decide({ window = hot, obtainable = all_ok, book = book, mods = fin2 })
  check(req(r13, "iron-plate") == nil and verdict(r13, "iron-plate").verdict == "fini", "deux modules finis : plus de demande")
end

---------------------------------------------------------------------------------------------------
section("2 bis. Graphe des recettes et objets quelconques")
---------------------------------------------------------------------------------------------------
do
  local function d(i) return A.depth(i, book) end
  check(d("iron-ore") == 0 and d("iron-plate") == 1 and d("iron-gear-wheel") == 2 and d("electronic-circuit") == 2
    and d("automation-science-pack") == 2 and d("logistic-science-pack") == 3 and d("transport-belt") == 3 and d("pipe") == 2,
    string.format("profondeurs du graphe : minerai %d, fer %d, engrenages %d, circuits %d, packs rouges %d, verts %d, tapis %d, tuyau %d",
      d("iron-ore"), d("iron-plate"), d("iron-gear-wheel"), d("electronic-circuit"), d("automation-science-pack"),
      d("logistic-science-pack"), d("transport-belt"), d("pipe")))
  -- Un objet SANS gabarit écrit (tuyau), fabriqué à la main 1 PNJ, 30/min : module généré depuis sa recette.
  local wp = win(10, { ["pipe"] = 3600 }, { ["pipe"] = 30 })
  local rp = A.decide({ window = wp, obtainable = all_ok, book = book, has_plant = true })
  local vp, qp = verdict(rp, "pipe"), req(rp, "pipe")
  check(vp ~= nil and vp.generic and qp ~= nil and qp.gen == "simple" and type(qp.args[1]) == "table" and qp.args[1].name == "pipe"
    and qp.args[3] == "assembling-machine-2",
    "tuyau (aucun gabarit écrit) : rangée d'assembleurs GÉNÉRÉE depuis sa recette, sur la MEILLEURE machine débloquée (lot PLANDIR T1), demandée (" .. tostring(vp and vp.why) .. ")")
  check(qp and qp.rate_nom >= 30 * 1.25 - 1e-6 and qp.items["assembling-machine-2"] == qp.args[2],
    string.format("tuyau : débit visé 37,5/min, nominal %.1f, %s assembleur(s)", qp and qp.rate_nom or 0, qp and tostring(qp.args[2]) or "?"))
  -- Lot PLANDIR (T1) : la machine suit ce qui est débloqué (jamais un nom écrit dans le cerveau)
  local no2 = function(n) return n ~= "assembling-machine-2" and book:handcraftable(n) end
  local m_no2 = A.method_for("pipe", book, no2)
  check(m_no2 and m_no2.args[3] == "assembling-machine-1", "tuyau : machine 2 pas débloquée -> la machine 1")
  local m_none = A.method_for("pipe", book, function() return false end)
  check(m_none and m_none.args[3] == "assembling-machine-1", "rien d'utilisable : la première machine de la liste (l'objet impossible fait rechercher)")
  check(A.method_for("pipe", book).args[3] == "assembling-machine-1", "sans filtre : comportement d'avant (première machine)")
  local mc = A.method_for("electronic-circuit", book, all_ok)
  check(mc and mc.gen == "circuits" and mc.args[1] == "assembling-machine-2", "circuits (gabarit écrit) : machine 2 quand elle est débloquée")
  check(A.method_for("electronic-circuit", book, no2).args[1] == "assembling-machine-1", "circuits : machine 1 sinon")
  check(A.method_for("iron-plate", book, all_ok).args[1] == "stone-furnace", "fonderie : aucune machine de fabrication substituée")
  local g = A.template(qp.gen, qp.args)
  check(g ~= nil and (g.inputs["iron-plate"] or 0) > 0, "le gabarit généré reçoit les plaques de fer par son quai")
  -- Limites écrites.
  local wi = win(10, { ["inserter"] = 3600, ["stone"] = 3600, ["stone-brick"] = 3600 }, { ["inserter"] = 10 })
  local ri = A.decide({ window = wi, obtainable = all_ok, book = book, has_plant = true })
  local vi, vs, vb = verdict(ri, "inserter"), verdict(ri, "stone"), verdict(ri, "stone-brick")
  check(vi and vi.verdict == "limite" and tostring(vi.why):find("3 ingredients", 1, true) and req(ri, "inserter") == nil,
    "bras (3 ingrédients) : verdict « limite », raison écrite (" .. tostring(vi and vi.why) .. ")")
  check(vs and vs.verdict == "limite" and tostring(vs.why):find("brut", 1, true), "pierre minée à la main : « limite » objet brut (" .. tostring(vs and vs.why) .. ")")
  check(vb and vb.verdict == "limite" and tostring(vb.why):find("smelting", 1, true), "briques (four) : « limite » hors de la main (" .. tostring(vb and vb.why) .. ")")
  -- Un objet attend SES entrées : le tapis (engrenages + fer) derrière un module d'engrenages en chantier ; les chargeurs
  -- (fer seul) ne sont plus retenus par un module de cuivre (l'ancienne liste de rangs les retenait).
  local wb = win(10, { ["transport-belt"] = 3600, ["firearm-magazine"] = 3600 }, { ["transport-belt"] = 30, ["firearm-magazine"] = 30 })
  local rb = A.decide({ window = wb, obtainable = all_ok, book = book, has_plant = true,
    mods = { { product = "iron-gear-wheel", state = "chantier" } } })
  local vt = verdict(rb, "transport-belt")
  check(vt and vt.verdict == "ordre" and tostring(vt.why):find("iron-gear-wheel", 1, true),
    "tapis : attend son entrée « engrenages » en chantier (" .. tostring(vt and vt.why) .. ")")
  local rc = A.decide({ window = wb, obtainable = all_ok, book = book, has_plant = true,
    mods = { { product = "copper-plate", state = "chantier" } } })
  check(req(rc, "firearm-magazine") ~= nil, "chargeurs (fer seul) : un module de cuivre en chantier ne les retient pas (" ..
    tostring(verdict(rc, "firearm-magazine").why) .. ")")
  local sorted = true
  for i = 2, #rc.verdicts do if (rc.verdicts[i].depth or 0) < (rc.verdicts[i - 1].depth or 0) then sorted = false end end
  check(sorted, "verdicts pesés par profondeur croissante")
  -- Interface d'un objet (IA-G) : pesé même sans charge mesurée.
  local v1, q1 = A.decide_item({ window = win(10, {}, {}), obtainable = all_ok, book = book }, "pipe")
  check(v1 and v1.product == "pipe" and v1.verdict == "non" and q1 == nil, "A.decide_item : tuyau sans charge, verdict « non » (" .. tostring(v1 and v1.why) .. ")")
  local v2, q2 = A.decide_item({ window = wp, obtainable = all_ok, book = book, has_plant = true }, "pipe")
  check(v2 and v2.verdict == "demande" and q2 and q2.gen == "simple", "A.decide_item : tuyau chargé, demande rendue")
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
  -- (a ter) recherche ouverte (packs rouges) : un module de fer passe APRÈS elle ; un module de packs rouges la sert.
  local gs = { { key = "recherche", family = "recherche", kind = "research", tech = "automation", value = 70 } }
  local auto = { mods = { { product = "iron-plate", state = "reserve", gain = 3 },
    { product = "automation-science-pack", state = "reserve", gain = 3 } } }
  local research = { tech = "automation", packs = { { "automation-science-pack", 10 } } }
  local out = A.goals(gs, auto, { capital = 1000 }, research)
  local vi, vp = 0, 0
  for _, g in ipairs(out) do
    if g.key == "auto:iron-plate" then vi = g.value elseif g.key == "auto:automation-science-pack" then vp = g.value end
  end
  check(vi < 70 and vp >= 70, string.format("recherche ouverte (70) : module de fer après elle (%d), module de packs rouges non plafonné (%d)", vi, vp))
  local out2 = A.goals({ { key = "recherche", value = 70 } }, auto, { capital = 1000 }, { tech = "x", packs = {}, for_auto = true })
  local vi2 = 0
  for _, g in ipairs(out2) do if g.key == "auto:iron-plate" then vi2 = g.value end end
  check(vi2 >= 70, "recherche voulue par l'automatisation (poteau moyen) : rien de plafonné (" .. vi2 .. ")")
end
do
  -- (a bis) module FINI dont le quai de circuits est vide au coffre : but « alimenter », circuits fabriqués pour lui.
  local st = C.new_state(0)
  local auto = { mods = { { product = "logistic-science-pack", state = "fini" } }, cap = {}, covered = {},
    feeds = { { product = "logistic-science-pack", id = 5, items = { { "electronic-circuit", 200 } }, gain = 1 } } }
  local plan = C.think(view({ stock = base_stock, outposts = outs }), book, st, ctx_of(auto))
  local proj = nil
  for _, p in ipairs(st.projects) do if p.key == "alim:logistic-science-pack" then proj = p end end
  check(proj ~= nil and proj.state == "actif", "module fini sans circuits au coffre : projet « alimenter » actif (" .. tostring(proj and proj.state) .. ")")
  check(count(plan, function(t) return t.kind == "craft" and t.item == "electronic-circuit" and t.ia3 == (proj and proj.id) end) >= 1,
    "… ses circuits sont fabriqués pour lui")
end
do
  -- (a) module en réserve, il manque des foreuses électriques et des bras : projet actif, sous-buts fabriqués.
  local st = C.new_state(0)
  local auto = { mods = { { product = "iron-plate", state = "reserve", missing = { { "electric-mining-drill", 4 }, { "inserter", 6 } } } },
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
  -- (a2) la centrale est un projet comme un module (ses chaudière et machines à vapeur sont fabriquées) ; la valeur d'un
  -- module grandit avec les PNJ qu'il libère.
  local stc = C.new_state(0)
  local autoc = { mods = { { product = "centrale", state = "reserve", missing = { { "steam-engine", 2 }, { "boiler", 1 } }, gain = 2 },
    { product = "iron-plate", state = "attente", missing = {}, gain = 2 } }, cap = {}, covered = {} }
  local planc = C.think(view({ stock = base_stock, outposts = outs }), book, stc, ctx_of(autoc))
  check(count(planc, function(t) return t.kind == "craft" and t.item == "steam-engine" and t.why == "auto:centrale" end) >= 1,
    "centrale : ses machines à vapeur sont fabriquées pour son projet")
  local g_lo = A.goals({}, { mods = { { product = "iron-plate", state = "plan", gain = 0 } } }, {})
  local g_hi = A.goals({}, { mods = { { product = "iron-plate", state = "plan", gain = 2 } } }, {})
  check(g_hi[1].value > g_lo[1].value and g_hi[1].value == A.VALUE + 2 * A.VALUE_PER_PNJ,
    string.format("valeur d'un module : %d sans gain, %d pour 2 PNJ libérés", g_lo[1].value, g_hi[1].value))
  -- (b) chantier bloqué : projet bloqué, cause lisible, il ne prend pas de place.
  local st2 = C.new_state(0)
  local auto2 = { mods = { { product = "iron-plate", state = "bloque", reason = "fantome refuse (stone-furnace en 3,4)" } }, cap = {}, covered = {} }
  C.think(view({ stock = base_stock, outposts = outs }), book, st2, ctx_of(auto2))
  local p2 = nil
  for _, p in ipairs(st2.projects) do if p.key == "auto:iron-plate" then p2 = p end end
  check(p2 and p2.state == "bloque" and p2.cause and p2.cause:find("^module:fantome refuse"), "chantier bloqué : projet bloqué, raison lisible (" .. tostring(p2 and p2.cause) .. ")")
  -- (c) module fini, fer couvert : plus de tournée ordinaire à l'avant-poste de fer ; ses tournées de charbon restent.
  local st3 = C.new_state(0)
  local v3 = view({ stock = base_stock, outposts = { op(1, "coal", 4, { output = 80 }), op(2, "iron", 8, { output = 80 }), op(3, "copper", 3), op(4, "stone", 2) } })
  local plan_a = C.think(v3, book, C.new_state(0), ctx_of({ mods = {}, cap = {}, covered = {} }))
  local svc_iron_a = count(plan_a, function(t) return t.kind == "service" and t.outpost == 2 end)
  local auto3 = { mods = { { product = "iron-plate", state = "fini" } }, cap = { iron = 0.94 }, covered = { ["iron-plate"] = true } }
  local plan3 = C.think(v3, book, st3, ctx_of(auto3))
  local svc_iron = count(plan3, function(t) return t.kind == "service" and t.outpost == 2 and t.prio < 90 end)
  local svc_coal = count(plan3, function(t) return t.kind == "service" and t.outpost == 1 end)
  check(svc_iron_a >= 1, "témoin : l'avant-poste de fer a sa tournée (" .. svc_iron_a .. ")")
  check(svc_iron == 0, "module fini, fer couvert : plus de tournée ordinaire à l'avant-poste de fer")
  check(svc_coal == count(plan_a, function(t) return t.kind == "service" and t.outpost == 1 end), "les tournées de charbon ne changent pas")
  -- (d) capacité : sans avant-poste de fer, un module fini empêche l'amorçage d'un avant-poste de fer.
  local v4 = view({ stock = base_stock, outposts = { op(1, "coal", 4), op(3, "copper", 3), op(4, "stone", 2) } })
  local s4 = C.situation(v4, C.new_state(0), ctx_of({ mods = {}, cap = { iron = 0.94 }, covered = {} }))
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
  local pb = C.think(view({ stock = base_stock, outposts = outs }), book, C.new_state(0), ctx_of({ mods = {}, cap = {}, covered = {} }))
  check(sig(pa) == sig(pb), "aucun module : même plan qu'avant le lot (neutralité)")
end

do
  -- (f) recherche d'un objet voulu par l'automatisation (r.for_auto) : valeur non plafonnée avant « fer II », packs sans
  -- plancher de fer.
  local function s_of(r)
    return { is_player = false, workers = 8, soldiers = 20, soldiers_max = 30, stock = { ["firearm-magazine"] = 80 },
      cap = { coal = 1, iron = 1, copper = 1, stone = 1 }, pending = {}, sites = {}, smelters = 4, smelters_pending = 0,
      weights = B.weights({}, nil), research = r, army_target = 18, economy_done = false }
  end
  local function research_value(r)
    for _, g in ipairs(B.generate(s_of(r), { targets = { coal = 1, iron = 1, copper = 1, stone = 1 }, iron2_set = true })) do
      if g.key == "recherche" then return g.value end
    end
    return nil
  end
  local base_r = { tech = "electronics", payable = true, iron_cost = 200 }
  local auto_r = { tech = "electronics", payable = true, iron_cost = 200, for_auto = true }
  check(research_value(base_r) == B.RESEARCH_PRE and research_value(auto_r) > B.RESEARCH_PRE,
    string.format("recherche pour l'automatisation : non plafonnée avant fer II (%s contre %s)", tostring(research_value(auto_r)), tostring(research_value(base_r))))
  -- extraction déjà faite (fer et charbon à 2 capacités) : le fer du coffre (90, sous le plancher de 100) n'a pas d'autre
  -- usage que les packs
  local fv = view({ stock = { ["iron-plate"] = 90, ["copper-plate"] = 200, coal = 300, stone = 200, ["firearm-magazine"] = 80 },
    outposts = { op(1, "coal", 8), op(2, "iron", 16), op(3, "copper", 3), op(4, "stone", 2) } })
  local function packs_of(r)
    local plan = C.think(fv, book, C.new_state(0), { tick = 0, weights = B.weights({}, nil), reach = {}, iron_floor = 100,
      research = r, army_target = 18 })
    return count(plan, function(t) return t.kind == "craft" and t.item == "automation-science-pack" end)
  end
  local rp = { tech = "electronics", payable = true, packs = { { "automation-science-pack", 10 } } }
  local rpa = { tech = "electronics", payable = true, packs = { { "automation-science-pack", 10 } }, for_auto = true }
  check(packs_of(rp) == 0 and packs_of(rpa) >= 1, string.format("fer sous le plancher : packs seulement pour l'automatisation (%d contre %d)", packs_of(rpa), packs_of(rp)))
end

do
  -- (g) centrale sur une rive naturelle étroite : 2 colonnes d'eau seulement au bord ouest du lot. L'ancienne règle
  -- (60 % d'un rectangle de 6 × 5 devant la pompe) la refusait ; la nouvelle (2 tuiles devant la pompe, 20 %) l'accepte.
  local Plan = require("shared.team.plan")
  local M = require("shared.team.modules")
  local g = M.GEN.steam(1)
  local water = {}
  for y = -50, 50 do for x = -2, -1 do water[Plan.tkey(x, y)] = true end end
  local function free(tx, ty) return not water[Plan.tkey(tx, ty)] end
  local fit = Plan.fit(g, { x0 = 0, y0 = 0, x1 = 24, y1 = 24 }, { free = free, water = water, margin = 0, toward = { x = 0, y = 12 } })
  check(fit ~= nil, "centrale sur une rive étroite (2 colonnes d'eau) : placée")
  local w0 = Plan.PLANT_WET
  Plan.PLANT_WET = 0.6
  local fit0 = Plan.fit(g, { x0 = 0, y0 = 0, x1 = 24, y1 = 24 }, { free = free, water = water, margin = 0, toward = { x = 0, y = 12 } })
  Plan.PLANT_WET = w0
  check(fit0 == nil, "témoin : à 60 % d'eau (règle d'avant), la même rive est refusée")
  local dry = function() return true end
  local fit_dry = Plan.fit(g, { x0 = 0, y0 = 0, x1 = 24, y1 = 24 }, { free = dry, water = {}, margin = 0 })
  check(fit_dry == nil, "sans eau : pas de centrale")
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
local inputs0 = A.inputs_of
mutant("ordre sans le graphe (aucune entrée)", function() A.inputs_of = function() return {} end end, function() A.inputs_of = inputs0 end)
local mf0 = A.method_for
mutant("aucun module généré (gabarits écrits seulement)", function()
  A.method_for = function(item, b)
    for _, m in ipairs(A.METHODS) do if m.product == item then return m end end
    return nil, "limite : pas de gabarit"
  end
end, function() A.method_for = mf0 end)
local BF = A.BELT_FLOW
mutant("fonderie à quai de minerai", function() A.BELT_FLOW = 0 end, function() A.BELT_FLOW = BF end)
local cost0 = A.cost
mutant("coût nul", function() A.cost = function(meth, g, ctx) local c, i, n, d = cost0(meth, g, ctx); return 0, i, n, d end end,
  function() A.cost = cost0 end)
local res0 = A.residual
mutant("logistique du module oubliée", function() A.residual = function() return 0 end end, function() A.residual = res0 end)
local emit0 = P.EMIT.module
mutant("projet module sans sous-buts", function() P.EMIT.module = function() return "en_cours" end end, function() P.EMIT.module = emit0 end)
local goals0 = A.goals
mutant("module devant la recherche ouverte", function()
  A.goals = function(g, auto, w) return goals0(g, auto, w, nil) end
end, function() A.goals = goals0 end)
mutant("module fini jamais nourri", function()
  A.goals = function(g, auto, w)
    if not auto then return goals0(g, auto, w) end
    local a2 = {}
    for k, x in pairs(auto) do a2[k] = x end
    a2.feeds = nil
    return goals0(g, a2, w)
  end
end, function() A.goals = goals0 end)
mutant("module hors des projets", function() A.goals = function(g) return g end end, function() A.goals = goals0 end)
local vpp = A.VALUE_PER_PNJ
mutant("valeur sans le gain", function() A.VALUE_PER_PNJ = 0 end, function() A.VALUE_PER_PNJ = vpp end)
local plant = A.PLANT
mutant("centrale jamais comptée", function() A.PLANT = { gen = "inconnu", args = {} } end, function() A.PLANT = plant end)

print(string.format("[AI3-AUTOMATISER] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
