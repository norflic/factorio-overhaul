--[[
  Tests hors jeu du solveur de débits et du diagnostic (shared/team/production.lua, lot IA1-e1, docs/EQUIPES_PNJ.md
  §6.1 à §6.3, §6.6 (6), §16). Usage, depuis la racine du mod :   lua5.2 tests/ia1_production_test.lua

  Livre RÉEL : tests/fixtures/recipes_ia1e.lua, produit par `lua5.2 tests/datastage/harness.lua "<racine>/data" .
  --dump-recipes tests/fixtures/recipes_ia1e.lua` sur 0.4.25 (vanilla 1.1.91 + mod : recettes par lots MOD-2
  comprises) ; le scénario `ia1-diag` le compare recette par recette à game.recipe_prototypes. Vérifie : recettes du
  modèle des gabarits = livre réel ; vitesses réelles (niveaux, modules MULTIPLIÉS de MOD-1) ; jeu d'essai du §6.1
  (10 circuits rouges par minute) ; plafond de 60 fabrications/s levé par les lots ; productivité ; énergie fermée
  (charbon) ; valeurs MU (règle X0) ; diagnostic du cas de preuve P.ARENA (manque de capacité, module affamé, témoin) ;
  options, retour sur investissement, choix et hystérésis ; règle d'automatisation = O.needs_automation ;
  déterminisme ; MUTANTS : chaque défaut injecté dans le source du solveur doit faire échouer la suite.
]]

package.path = "./?.lua;" .. package.path
local PROD_PATH = "shared/team/production.lua"
local Real = require("shared.team.production")
local Mod = require("shared.team.modules")
local L = require("shared.levels.config")
local O = require("shared.team.org")
local RL = require("shared.content.recipe_lots")
local FIX = require("tests.fixtures.recipes_ia1e")
local OLD = require("tests.fixtures.recipes")

local function near(a, b, tol) return a ~= nil and b ~= nil and math.abs(a - b) <= (tol or 1e-6) end

local function ser(v)
  if type(v) ~= "table" then
    if type(v) == "number" then return string.format("%.10g", v) end
    return tostring(v)
  end
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(ks) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
  return "{" .. table.concat(parts, ",") .. "}"
end

---------------------------------------------------------------------------------------------------
-- La suite, paramétrée par le module testé (vrai ou mutant). Rend passes, échecs.
---------------------------------------------------------------------------------------------------
local function suite(P, quiet)
  local passes, failures = 0, 0
  local function check(cond, msg)
    if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  end
  local function section(name) if not quiet then print("== " .. name) end end
  local function info(msg) if not quiet then print("   " .. msg) end end

  local book = P.book(FIX)

  section("Livre réel (vanilla 1.1.91 + mod, 0.4.25)")
  -- Lot X2 (livre régénéré) : + 13 recettes de la chaîne de la bobine (9 de procédé, 4 machines), + 6 recettes de
  -- barils (oxygène, azote et oxygène liquides), + 24 lots MOD-2 de 10 et 100 (catégories vanilla : lessivage, cryostat,
  -- 4 machines, 6 barils ; les catégories « fo-* » restent exclues).
  check(#book.names == 825, "825 recettes au livre (" .. #book.names .. ")")
  local n_lots = 0
  for _, rn in ipairs(book.names) do if RL.parse(rn) then n_lots = n_lots + 1 end end
  check(n_lots == 524, "524 recettes par lots (MOD-2) au livre (" .. n_lots .. ")")
  check(ser(book.lots["iron-gear-wheel"]) == "{1=1,2=10,3=100}", "lots de l'engrenage : 1, 10, 100")
  local lot = book.recipes["fo-lot10-iron-gear-wheel"]
  check(lot and lot.hidden and near(lot.energy, 5) and lot.products[1].amount == 10 and lot.ingredients[1].amount == 20,
    "lot ×10 de l'engrenage : 20 plaques → 10 engrenages en 5 s (mêmes rapports)")
  -- recettes vanilla : le nouveau livre = l'ancien jeu de données (21/10) pour toutes les recettes hors fo-
  local diff = {}
  for name, r in pairs(OLD) do
    if not name:find("^fo%-") and ser(r) ~= ser(FIX[name]) then diff[#diff + 1] = name end
  end
  table.sort(diff)
  check(#diff == 0, "recettes vanilla identiques à tests/fixtures/recipes.lua (" .. table.concat(diff, ", ") .. ")")
  -- le modèle des gabarits (modules.lua) contre le livre réel
  local mbad = {}
  for _, rn in ipairs(Mod.recipe_names()) do
    local m, r = Mod.RECIPES[rn], book.recipes[rn]
    if not r then mbad[#mbad + 1] = rn .. " absente"
    else
      if not near(m.time, r.energy) or m.category ~= r.category then mbad[#mbad + 1] = rn .. " durée/catégorie" end
      for i, x in ipairs(m.ingredients) do
        local y = r.ingredients[i]
        if not y or y.name ~= x.name or not near(y.amount, x.amount) then mbad[#mbad + 1] = rn .. " ingrédient " .. i end
      end
      for i, x in ipairs(m.products) do
        local y = r.products[i]
        if not y or y.name ~= x.name or not near(y.amount, x.amount) then mbad[#mbad + 1] = rn .. " produit " .. i end
      end
    end
  end
  check(#mbad == 0, "les " .. #Mod.recipe_names() .. " recettes des gabarits (IA1-c) = livre réel (" .. table.concat(mbad, " | ") .. ")")

  section("Machines à leur vitesse réelle (niveaux, modules multipliés MOD-1, barème D-17 du lot MOD-3)")
  local a2 = P.machine("assembling-machine-2")
  check(near(a2.speed, 0.75) and near(a2.usage_kw, 150) and near(a2.drain_kw, 5), "assembleur 2 : 0,75, 150 kW + 5 kW de ponction")
  check(near(P.machine("fo-lvl-assembler-7").speed, 0.75 * 1.48), "assembleur au niveau 7 : 0,75 × (1 + 6 × 8 %) = 1,11")
  check(near(P.machine("fo-lvl-furnace-7").speed, 2 * 1.48), "four au niveau 7 : 2 × 1,48")
  check(near(P.machine("fo-lvl-drill-7").speed, 0.5 * 1.6), "foreuse au niveau 7 : 0,5 × (1 + 6 × 10 %) = 0,8")
  local sp = P.machine("assembling-machine-2", { { family = "speed", tier = 1 }, { family = "speed", tier = 1 } })
  check(near(sp.speed_factor, 1.44) and near(sp.speed, 1.08), "2 modules de vitesse 1 (+20 %, D-17) : × 1,44 (Π (1 + b), pas × 1,40)")
  check(near(sp.energy_factor, 1.25) and near(sp.usage_kw, 150 * 1.25), "énergie : × 1,12² = 1,2544, arrondi au centième : 1,25")
  check(near(sp.drain_kw, 5), "ponction non multipliée (F202)")
  local pm = P.machine("assembling-machine-2", { { family = "productivity", tier = 1 }, { family = "productivity", tier = 1 } })
  check(near(pm.prod, 0.21) and near(pm.speed_factor, 0.96), "2 modules de productivité 1 : × 1,1² = +21 % (multipliée, D-17), vitesse × 0,98² = 0,9604 (malus réduit de moitié, R-QCM-25b) arrondi au centième comme le moteur : 0,96")
  local big = P.machine("fo-lvl-assembler-30", { { family = "speed", tier = 10 }, { family = "speed", tier = 10 },
    { family = "speed", tier = 10 }, { family = "speed", tier = 10 } })
  check(near(big.speed_factor, 19.45), "4 modules de vitesse 10 : × 2,1⁴ = 19,45 (D-17) : " .. string.format("%.2f", big.speed_factor))
  local s10 = {}
  for i = 1, 8 do s10[i] = { family = "speed", tier = 10 } end
  local huge = P.machine("fo-lvl-assembler-30", s10)
  check(near(huge.speed_factor, 328.67), "8 modules de vitesse 10 : 2,1⁸ = 378 → plafond du moteur × 328,67 : " .. string.format("%.2f", huge.speed_factor))
  -- Correctif de MOD-3 appliqué au lot IA1-b2 : au plafond, le solveur suit la règle de l'écart du jeu (MM.complements).
  check(near(huge.energy_factor, 52.38), "8 modules de vitesse 10 : énergie × 52,38 au plafond (règle de l'écart, D-17) : "
    .. string.format("%.2f", huge.energy_factor))

  section("Jeu d'essai du §6.1 : 10 circuits rouges par minute")
  local plan, why = P.solve(book, { ["advanced-circuit"] = 10 })
  check(plan ~= nil, "plan rendu (" .. tostring(why) .. ")")
  if plan then
    local function mc(item) local n = P.node(plan, item); return n and n.machines_ceil end
    local function mx(item) local n = P.node(plan, item); return n and n.machines end
    check(mc("advanced-circuit") == 2 and near(mx("advanced-circuit"), 4 / 3), "circuits rouges : 1,333 → 2 assembleurs 2")
    check(mc("electronic-circuit") == 1 and near(P.node(plan, "electronic-circuit").per_min, 20), "circuits verts : 20/min, 1 assembleur")
    check(mc("copper-cable") == 1 and near(P.node(plan, "copper-cable").per_min, 100), "câbles : 40 + 60 = 100/min, 1 assembleur")
    check(mc("plastic-bar") == 1 and near(P.node(plan, "plastic-bar").per_min, 20), "plastique : 20/min, 1 usine chimique")
    local gas = P.node(plan, "petroleum-gas")
    check(gas and gas.recipe == "basic-oil-processing" and gas.machines_ceil == 1 and near(gas.per_min, 200), "gaz : 200/min, raffinage de base, 1 raffinerie")
    local crude = P.raw_row(plan, "crude-oil")
    check(crude and near(crude.per_min, 4000 / 9, 1e-6) and near(crude.count, 0.7407407, 1e-6), "pétrole brut : 444,4/min, 0,741 chevalet (un gisement à 74 % suffit)")
    check(mc("copper-plate") == 3 and mc("iron-plate") == 2, "plaques : 3 fours de cuivre + 2 fours de fer (18,75/min chacun)")
    local pj = P.machine("pumpjack")
    check(near(plan.power.usage_max_kw + crude.count_ceil * pj.usage_kw, 1320), "électricité des machines : 4 × 150 + 210 + 420 + 90 = 1,32 MW (§6.1)")
    check(near(P.raw_row(plan, "iron-ore").count, 2 / 3) and near(P.raw_row(plan, "copper-ore").count, 5 / 3), "foreuses : fer 0,667, cuivre 1,667 (0,5 minerai/s)")
    check(near(plan.coal.recipes, 10), "charbon du plastique : 10/min")
    check(near(plan.coal.burners, (8 / 3 + 16 / 15) * 90 * 60 / 4000), "charbon des fours (activité réelle) : 3,73 fours × 90 kW = 5,04/min")
    check(near(plan.coal.total, plan.coal.recipes + plan.coal.burners + plan.coal.electricity, 1e-6), "charbon total = plastique + fours + chaudières")
    local coal_row = P.raw_row(plan, "coal")
    check(coal_row and near(coal_row.per_min, plan.coal.total, 1e-6), "le charbon des chaudières est extrait (foreuses comprises dans l'électricité)")
    -- point fixe : repasser le charbon trouvé ne change rien
    check(plan.passes > 1 and plan.passes < P.FIXPOINT_PASSES, "énergie fermée en " .. plan.passes .. " passes")
    check(plan.coal.total > 25 and plan.coal.total < 35, string.format("charbon en régime : %.1f/min", plan.coal.total))
    check(plan.coal.at_max > 40 and plan.coal.at_max < 45, string.format("charbon à la puissance installée : %.1f/min (le §6.1 estimait ~45, P1 ~70)", plan.coal.at_max))
    info(string.format("charbon : %.2f/min en régime (plastique %.2f, fours %.2f, chaudières %.2f) ; %.2f/min à la puissance installée ; puissance moyenne %.0f kW, installée %.0f kW",
      plan.coal.total, plan.coal.recipes, plan.coal.burners, plan.coal.electricity, plan.coal.at_max, plan.power.avg_kw, plan.power.max_kw))
    -- automatisation
    local n_auto = P.automation(plan, { minutes = 60, distance = 28 })
    local cable_flow
    for _, f in ipairs(plan.flows) do if f.item == "copper-cable" and f.to == "electronic-circuit" then cable_flow = f end end
    check(cable_flow and near(cable_flow.per_min, 60) and cable_flow.automate == false, "câbles vers les circuits verts : 60/min, pas plus de 60 : non automatisé")
    local cu, crude_f
    for _, f in ipairs(plan.flows) do
      if f.item == "copper-plate" then cu = f end
      if f.item == "crude-oil" then crude_f = f end
    end
    check(cu and near(cu.per_min, 50) and cu.automate == false, "cuivre vers les câbles : 50/min : non automatisé")
    check(crude_f and crude_f.automate == true, "pétrole brut vers la raffinerie : 444/min sur 28 tuiles pendant 60 min : conduite")
    local far = P.solve(book, { ["advanced-circuit"] = 10 })
    P.automation(far, { minutes = 60, distance = 100 })
    local any = false
    for _, f in ipairs(far.flows) do if f.automate then any = true end end
    check(not any, "à 100 tuiles : aucun flux automatisé par la règle (porteurs ou projet longue distance)")
    info("flux à automatiser (60 min, 28 tuiles) : " .. n_auto .. " sur " .. #plan.flows)
    -- déterminisme : deux calculs, et liste d'objectifs au lieu d'une table
    local plan2 = P.solve(book, { { "advanced-circuit", 10 } })
    P.automation(plan2, { minutes = 60, distance = 28 })
    check(ser(plan) == ser(plan2), "déterminisme : même plan, objectifs en table ou en liste")
  end
  local bad, why2 = P.solve(book, { ["iron-plate"] = 10 }, { machines = { smelting = false } })
  check(bad == nil and why2 and why2:find("aucune recette"), "catégorie sans machine : refus (" .. tostring(why2) .. ")")

  section("Plafond de 60 fabrications/s, recettes par lots (MOD-2)")
  local gears = book.recipes["iron-gear-wheel"]
  local cps, k, capped = P.crafts_per_s(huge, gears, book.lots["iron-gear-wheel"])
  check(near(cps, huge.speed / 0.5) and k == 100 and not capped, string.format("machine rapide (%.0f fab./s voulues) : lot 100, débit entier", huge.speed / 0.5))
  local cpsm, km = P.crafts_per_s(big, gears, book.lots["iron-gear-wheel"])
  check(near(cpsm, big.speed / 0.5) and km == 10, string.format("machine de %.0f fab./s : lot 10", big.speed / 0.5))
  local cps1, k1, capped1 = P.crafts_per_s(huge, gears, nil)
  check(near(cps1, 60) and k1 == 1 and capped1, "sans lot au livre : plafonnée à 60 fab./s")
  local cps2, k2 = P.crafts_per_s(a2, gears, book.lots["iron-gear-wheel"])
  check(near(cps2, 1.5) and k2 == 1, "assembleur 2 : 1,5 fab./s, lot 1")
  local fast = P.solve(book, { ["iron-gear-wheel"] = 60000 }, { machines = { crafting = huge }, power = "externe" })
  local gn = fast and P.node(fast, "iron-gear-wheel")
  check(gn and gn.lot == 100 and near(gn.machines, 1000 / (huge.speed / 0.5), 1e-9), "60 000 engrenages/min : machines = débit ÷ vitesse réelle (lot 100)")

  section("Productivité (multipliée, D-17)")
  local pplan = P.solve(book, { ["advanced-circuit"] = 10 }, { machines = { crafting = pm, ["advanced-crafting"] = pm, ["crafting-with-fluid"] = pm } })
  local pn = pplan and P.node(pplan, "advanced-circuit")
  check(pn and near(pn.crafts_per_s, (10 / 60) / 1.21), "circuits rouges avec × 1,21 : fabrications ÷ 1,21")
  check(pplan and near(P.node(pplan, "electronic-circuit").per_min, 2 * 10 / 1.21), "circuits verts demandés : 2 × 10 / 1,21")

  section("Valeurs en MU (règle X0 : la plaque de fer vaut 1 MU)")
  local v = P.values(book)
  for _, it in ipairs({ "iron-plate", "copper-plate", "iron-gear-wheel", "electronic-circuit", "stone-brick", "steel-plate", "engine-unit" }) do
    check(near(v[it], L.item_value[it]), it .. " : " .. tostring(v[it]) .. " MU = L.item_value " .. tostring(L.item_value[it]))
  end
  check(near(v["petroleum-gas"], 0.08) and near(v["plastic-bar"], 1.3), "gaz 0,08 MU (raffinage avancé, le moins cher), plastique 1,3 MU")
  check(v["water"] == 0 and near(v["crude-oil"], 0.1), "eau gratuite, pétrole brut 0,1 MU l'unité")
  check(v["fo-liquid-nitrogen"] and v["fo-liquid-nitrogen"] > 0.05 and v["fo-oxygen"] > 0.05 and v["empty-barrel"] >= 0.5,
    "lot X2 : recette sans ingrédient de valeur (distillation de l'air, électrolyse de l'eau) = extraction, baril vide intact ("
    .. tostring(v["fo-liquid-nitrogen"]) .. ", " .. tostring(v["empty-barrel"]) .. ")")
  check(near(v["assembling-machine-2"], 54) and near(v["fast-inserter"], 12.5) and near(v["transport-belt"], 1.5), "assembleur 2 : 54 MU ; bras rapide 12,5 ; tapis 1,5")
  info(string.format("écart connu : plastique %.2f MU au chemin le moins cher, %s dans L.item_value (valeur de matériau d'époque)", v["plastic-bar"], tostring(L.item_value["plastic-bar"])))
  local fam = L.by_key.assembler
  check(near(P.entity_mu("fo-lvl-assembler-2", v), 54 + P.cost_mu(L.cost(fam, 2), v)), "assembleur posé au niveau 2 : objet de base + coût du niveau 2")
  local v2 = P.values(book)
  check(ser(v) == ser(v2), "valeurs déterministes")
  -- catalyseur (même objet des deux côtés) : seule la part nette compte (règle X0)
  local cat = P.book({
    ["x-cata"] = { category = "crafting", energy = 1, ingredients = { { type = "item", name = "iron-ore", amount = 100 } },
      products = { { type = "item", name = "x-cata", amount = 1 } } },
    ["x-prod"] = { category = "crafting", energy = 1, ingredients = { { type = "item", name = "iron-ore", amount = 1 },
      { type = "item", name = "x-cata", amount = 10 } }, products = { { type = "item", name = "x-cata", amount = 10 },
      { type = "item", name = "x-prod", amount = 1 } } },
  })
  local vc = P.values(cat)
  check(near(vc["x-prod"], 1) and near(vc["x-cata"], 100), "catalyseur rendu : produit à 1 MU (minerai seul), catalyseur à 100 MU")
  local cplan = P.solve(cat, { ["x-prod"] = 60 }, { power = "externe" })
  check(cplan and near(P.raw_row(cplan, "iron-ore").per_min, 60) and P.node(cplan, "x-cata") == nil, "catalyseur rendu : le solveur ne demande que le minerai")

  section("Diagnostic du cas de preuve (P.ARENA, modèle)")
  local ctx = { values = v, max_level = P.ARENA_MAX_LEVEL, free_lots = 1, book = book }
  local ds = {}
  for i, c in ipairs(P.ARENA) do ds[i] = P.diagnose_one(P.model_module(c), ctx) end
  local A, B, C = ds[1], ds[2], ds[3]
  check(A.verdict == "capacite" and near(A.deficit_per_min, 120) and near(A.ratio, 1), "A : manque de capacité (360/min pour 480 voulus, déficit 25 %)")
  check(A.choice and A.choice.kind == "agrandir" and A.choice.n == 5, "A : choix « agrandir 4 → 5 » (" .. tostring(A.choice and A.choice.label) .. ")")
  local byk = {}
  for _, o in ipairs(A.options or {}) do byk[o.kind] = o end
  check(byk.agrandir and near(byk.agrandir.cost_mu, 117.5) and near(byk.agrandir.added_per_min, 90), "agrandir : +1 assembleur 2, +3 bras rapides, +5 tapis = 117,5 MU, +90/min")
  check(byk.ameliorer and near(byk.ameliorer.cost_mu, 4 * 19.5) and near(byk.ameliorer.added_per_min, 28.8), "améliorer : 4 × 19,5 MU, +8 % = +28,8/min")
  check(byk.construire and near(byk.construire.cost_mu, 439) and near(byk.construire.score, 439 * 1.2 / 120), "construire : 439 MU, +20 % de pénalité, débit utile = déficit (120)")
  check(byk.remplacer == nil, "remplacer refusé : palier 7 au-dessus du plafond 6")
  for _, o in ipairs(A.options or {}) do
    check(near(o.roi_min, o.cost_mu / (o.added_per_min * 2)), o.kind .. " : T = coût ÷ (débit ajouté × 2 MU) = " .. string.format("%.3f", o.roi_min) .. " min")
  end
  check(B.verdict == "affame" and B.lacking == "iron-plate" and near(B.ratio, 0.4), "B : affamé (40 % du nominal), le fer manque")
  check(B.upstream and B.upstream.item == "iron-plate" and near(B.upstream.deficit_per_min, 108), "B : amont = 108 plaques de fer/min de plus (180 voulues, 72 livrées)")
  check(B.choice == nil and B.options == nil, "B : aucune option sur le module lui-même (on ne construit pas en aval)")
  local up_f
  for _, p in ipairs((B.upstream and B.upstream.plan) or {}) do if p.item == "iron-plate" then up_f = p end end
  check(up_f and up_f.machines_ceil == 6, "B : plan amont du solveur : 108/min = 5,76 → 6 fours en pierre")
  check(C.verdict == "ok", "C : à l'aise (360/min pour 300 voulus)")

  section("Seuils, blocage, hystérésis")
  local function synth(measured, demand, wit)
    local g = Mod.get("engrenages")
    return P.diagnose_one({ id = "S", g = g, item = "iron-gear-wheel", demand_per_min = demand, measured_per_min = measured,
      inputs = {}, witness = wit or { samples = 10, shortage = { ["iron-plate"] = 10 }, output_full = 0 } }, ctx)
  end
  check(synth(306, 360).verdict == "ok", "déficit de 15 % : ok")
  check(synth(305, 360).verdict == "capacite", "déficit de 15,3 % : manque de capacité")
  check(synth(216, 360).verdict == "capacite", "60 % du nominal, ingrédient manquant : pas affamé (seuil strict)")
  check(synth(215, 360).verdict == "affame", "59,7 % du nominal, ingrédient manquant : affamé")
  check(synth(100, 360, { samples = 10, shortage = { ["iron-plate"] = 4 }, output_full = 0 }).verdict == "capacite", "ingrédient manquant à 4 relevés sur 10 : pas affamé")
  check(synth(100, 360, { samples = 10, shortage = {}, output_full = 8 }).verdict == "bloque", "sortie pleine à 8 relevés sur 10 : bloqué en aval")
  local opts = { { kind = "agrandir", n = 5, score = 1.0, valid = true }, { kind = "construire", n = 1, score = 1.19, valid = true },
    { kind = "ameliorer", n = 2, score = 1.21, valid = true } }
  check(P.choose(opts).kind == "agrandir", "choix : le meilleur score")
  check(P.choose(opts, { kind = "construire" }).kind == "construire", "hystérésis : l'option engagée à 19 % du meilleur est gardée")
  check(P.choose(opts, { kind = "ameliorer" }).kind == "agrandir", "hystérésis : l'option engagée à 21 % du meilleur est quittée")
  local d1 = synth(360, 480)
  local d2 = synth(360, 480)
  check(ser(d1) == ser(d2), "diagnostic déterministe")

  section("Règle d'automatisation = O.needs_automation (org.lua)")
  local same = true
  for _, f in ipairs({ 0, 59.9, 60, 60.1, 200 }) do
    for _, m in ipairs({ 5, 10, 10.1, 60 }) do
      for _, d in ipairs({ 10, 64, 64.1, 200 }) do
        if P.needs_automation(f, m, d) ~= O.needs_automation(f, m, d) then same = false end
      end
    end
  end
  check(same, "mêmes seuils que O.needs_automation sur 80 cas")
  return passes, failures
end

---------------------------------------------------------------------------------------------------
print("[IA1-E1] solveur et diagnostic (shared/team/production.lua)")
local passes, failures = suite(Real, false)

---------------------------------------------------------------------------------------------------
-- Mutants : un défaut injecté dans le source doit faire échouer la suite.
---------------------------------------------------------------------------------------------------
print("== Mutants")
local f = assert(io.open(PROD_PATH, "rb"))
local SRC = f:read("*a")
f:close()
local MUTANTS = {
  { "modules additionnés", "local fs, fc = comp.speed.t / 100, comp.consumption.t / 100",
    "local fs, fc = 1, comp.consumption.t / 100; for _, x in ipairs(per) do fs = fs + x.speed / 100 end" },
  { "productivité ignorée", "local out = product_amount(r, item) * (1 + m.prod)", "local out = product_amount(r, item)" },
  { "lots ignorés (plafond 60 toujours)", "local kmax = avail[#avail]", "local kmax = 1" },
  { "aucun plafond de 60/s", "if w > RL.CAP * kmax + P.EPS then", "if false then" },
  { "énergie non fermée", "extra[fuel] = want", "extra[fuel] = 0" },
  { "ordre des nœuds inversé", "for i = #order, 1, -1 do", "for i = 1, #order do" },
  { "ponction multipliée", "drain_kw = s.drain and (s.usage_kw / 30) or 0", "drain_kw = s.drain and (s.usage_kw * fc / 30) or 0" },
  { "seuil d'affamé à 30 %", "P.STARVED_RATIO = 0.60", "P.STARVED_RATIO = 0.30" },
  { "tolérance de déficit à 30 %", "P.DEFICIT_TOLERANCE = 0.15", "P.DEFICIT_TOLERANCE = 0.30" },
  { "débit utile = débit ajouté", "o.useful_per_min = math.min(o.added_per_min, deficit)", "o.useful_per_min = o.added_per_min" },
  { "pas de pénalité du module neuf", "penalty = P.NEW_MODULE_PENALTY, added_per_min = nom0", "penalty = 1, added_per_min = nom0" },
  { "sans hystérésis", "o.score <= best.score * P.HYSTERESIS + 1e-9", "o.score <= best.score + 1e-9" },
  { "fluides gratuits", "return free[n] and 0 or (rho[n] or X.FLUID_MU or 0.1)", "return 0" },
  { "foreuse à 1 minerai/s", "row.extractor, row.count = d.name, q / 60 / (d.speed * (1 + d.prod) / mt)", "row.extractor, row.count = d.name, q / 60" },
  { "amont sur la sortie au lieu de l'entrée", "local item_in = ext[lacking] and lacking or nil", "local item_in = mod.item" },
  { "ROI sur le débit utile", "o.gain_mu_per_min = o.added_per_min * item_mu", "o.gain_mu_per_min = math.min(o.added_per_min, deficit) * item_mu" },
  { "catalyseur non déduit (valeurs)", "for _, p in ipairs(r.products) do if p.name == i.name then net = net - p.amount end end", "" },
  { "seuil d'automatisation à 30/min", "P.AUTOMATION = { flow = 60, minutes = 10, distance = 64 }", "P.AUTOMATION = { flow = 30, minutes = 10, distance = 64 }" },
}
local killed = 0
for _, mu in ipairs(MUTANTS) do
  local a, b = SRC:find(mu[2], 1, true)
  if not a then
    failures = failures + 1
    print("  ECHEC : mutant « " .. mu[1] .. " » : motif introuvable")
  else
    local src = SRC:sub(1, a - 1) .. mu[3] .. SRC:sub(b + 1)
    local chunk, err = load(src, "=mutant", "t", _ENV)
    if not chunk then
      failures = failures + 1
      print("  ECHEC : mutant « " .. mu[1] .. " » : ne se charge pas (" .. tostring(err) .. ")")
    else
      local okc, Pm = pcall(chunk)
      local fails = 0
      if okc then
        local okr, p2, f2 = pcall(suite, Pm, true)
        if okr then fails = f2 else fails = 1 end
      else
        fails = 1
      end
      if fails > 0 then killed = killed + 1; passes = passes + 1; print("   mutant « " .. mu[1] .. " » refusé (" .. fails .. " contrôle(s) en échec)")
      else failures = failures + 1; print("  ECHEC : mutant « " .. mu[1] .. " » SURVIT") end
    end
  end
end
print(string.format("   mutants refusés : %d / %d", killed, #MUTANTS))

print(string.format("[IA1-E1] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
