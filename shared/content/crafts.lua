--[[
  Lot AMELIO-CRAFTS (nuit du 29 au 30/10) : chaînes de fabrication des âges 2, 3, 6 et 11 EN JEU, tirées du scénario X0
  (shared/content/epochs.lua, docs/SCENARIO_EPOQUES.md), et débouchés des sous-produits de la chaîne du titane (lot X1,
  shared/content/titanium.lua). Lua PUR : données et règles, testables hors jeu (tests/crafts_test.lua) ; génération des
  prototypes : prototypes/crafts.lua.

  Règle X3 « des voies, jamais une porte » : chaque recette neuve est une VARIANTE qui produit aussi un objet vanilla
  (acier, béton, moteur électrique, structure basse densité, huile légère, béton armé, remblai) ou un intermédiaire
  dont toute la descendance en jeu finit sur un objet vanilla. Rien ne devient obligatoire, aucun coût existant ne
  change, aucun sous-produit n'est sans débouché (tests/crafts_test.lua le vérifie sur le graphe en jeu).

  Ce qui vient de X0 tel quel : objets, bâtiments (taille, puissance, vitesse, catégories, boîtes de fluide),
  recettes (ingrédients, produits, durées, catégories) et technologies (nom, âge, déblocages, prérequis X0).
  Écarts, tous marqués ici :
    - SUBST : un ingrédient X0 absent du jeu remplacé PROVISOIREMENT par un objet vanilla (composite titane : le
      biopolymère de l'âge 8 n'est pas en jeu, remplacé par du plastique, comme les monnaies « provisional ») ;
    - EXTRA_RECIPES : 3 recettes HORS X0, pour fermer des boucles que X0 laisse ouvertes en jeu (laitier, chlorure de
      magnésium et soude, hydrogène) ; elles sont dites « hors X0 » dans leur description ;
    - les technologies se paient en packs VANILLA (fenêtre X0 de l'âge, packs du mod absents du jeu retirés) ;
    - visuels PROVISOIRES (copies teintées de machines vanilla, comme X1) et SANS niveaux (question S4).
]]

local X = require("shared.content.epochs")
local T = require("shared.content.titanium")

local C = {}

-- Objets de X0 mis en jeu par ce lot (le coke, le four à coke et le four à arc sont déjà en jeu par X1).
C.ITEMS = {
  "fo-slag", "fo-cement", "fo-sand",                       -- âge 2 (haut fourneau, concassage)
  "fo-glass", "fo-manometer",                              -- âge 3 (verrerie)
  "fo-graphite", "fo-magnetic-steel", "fo-enameled-wire", "fo-coil", -- âge 6 (arc, bobinage)
  "fo-titanium-composite",                                 -- âge 11 (débouché du titane)
}
-- Fluides de X0 mis en jeu par ce lot.
C.FLUIDS = { "fo-ethylene" }

-- Bâtiments de X0 mis en jeu par ce lot. Visuel PROVISOIRE : copie teintée d'une machine vanilla (palette de
-- docs/DESIGN_EPOQUES.md §1.5 ; F36, F38 : une teinte multiplie).
--   copy = { type, nom } de la machine vanilla copiée ; side = côté de la copie (tuiles).
C.BUILDINGS = {
  { name = "fo-blast-furnace", copy = { "furnace", "steel-furnace" }, side = 2, tint = { r = 0.80, g = 0.62, b = 0.52 } },
  { name = "fo-crusher", copy = { "assembling-machine", "assembling-machine-1" }, side = 3, tint = { r = 0.78, g = 0.70, b = 0.58 } },
  { name = "fo-coil-winder", copy = { "assembling-machine", "assembling-machine-2" }, side = 3, tint = { r = 0.98, g = 0.80, b = 0.55 } },
  -- Torchère : X0 en fait un FOUR qui choisirait sa recette d'après le fluide entrant ; un four du moteur 1.1.91 choisit
  -- sa recette d'après l'OBJET de son entrée (une recette sans objet n'y serait jamais choisie : non prouvé en moteur
  -- réel, prudence). ÉCART : machine à recette, le joueur choisit le fluide à brûler.
  { name = "fo-flare-stack", copy = { "assembling-machine", "assembling-machine-1" }, side = 3, tint = { r = 1.00, g = 0.55, b = 0.40 },
    as_assembler = true },
  { name = "fo-steam-cracker", copy = { "assembling-machine", "chemical-plant" }, side = 3, tint = { r = 0.92, g = 0.86, b = 0.62 } },
}

-- Recettes de procédé de X0 mises en jeu (ordre d'affichage) ; main = produit principal d'une recette à plusieurs
-- produits ; subst = ingrédient X0 absent remplacé (provisoire, dit dans la description de la recette).
C.RECIPES = {
  { name = "fo-blast-furnace-steel", main = "steel-plate" },
  { name = "fo-sand" },
  { name = "fo-slag-cement" },
  { name = "fo-cement-concrete" },
  { name = "fo-glass" },
  { name = "fo-manometer" },
  { name = "fo-steam-cracking" },
  { name = "fo-polyethylene" },
  { name = "fo-graphite" },
  { name = "fo-arc-steel" },
  { name = "fo-magnetic-steel" },
  { name = "fo-enameled-wire" },
  { name = "fo-coil" },
  { name = "fo-wound-electric-engine" },
  { name = "fo-titanium-composite", subst = { ["fo-biopolymer"] = "plastic-bar" } },
  { name = "fo-titanium-lds" },
  -- Torchères (X0 : une recette « sink » par fluide neuf) pour les fluides du mod en jeu : aucun fluide de sous-produit
  -- ne peut plus bloquer une usine.
  { name = "fo-flare-ethylene", flare = true },
  { name = "fo-flare-hydrogen", flare = true },
  { name = "fo-flare-chlorine", flare = true },
  { name = "fo-flare-brine", flare = true },
  { name = "fo-flare-titanium-tetrachloride", flare = true },
}

-- Recettes HORS X0 (fermeture des boucles en jeu). Même format que les recettes de X0.
C.EXTRA_RECIPES = {
  -- Laitier : sans béton à faire, le haut fourneau se bloquerait. Le remblai l'absorbe sans limite
  -- (vanilla : 50 pierres pour 1 remblai).
  { name = "fo-slag-landfill", epoch = 2, category = "crafting", time = 0.5,
    ingredients = { { "fo-slag", 20 } }, results = { { "landfill", 1 } },
    fr = "Remblai de laitier", en = "Slag landfill" },
  -- Ciment de Sorel (oxychlorure de magnésium : MgO de la soude + MgCl2) : consomme À PARTS ÉGALES le chlorure de
  -- magnésium et la soude que la saumure laisse (0,75 de chaque par plaque de titane).
  { name = "fo-sorel-concrete", epoch = 11, category = "chemistry", time = 10,
    ingredients = { { "fo-magnesium-chloride", 2 }, { "fo-caustic-soda", 2 }, { "concrete", 10 }, { "water", 40 } },
    results = { { "refined-concrete", 10 } },
    fr = "Béton de Sorel", en = "Sorel concrete" },
  -- Hydrocraquage : l'hydrogène de la saumure (30 par plaque de titane) remplace l'eau du craquage de l'huile lourde,
  -- avec un rendement meilleur (vanilla : 40 lourde + 30 eau -> 30 légère).
  { name = "fo-hydrocracking", epoch = 11, category = "chemistry", time = 2,
    ingredients = { { "heavy-oil", 40 }, { "fo-hydrogen", 30 } }, results = { { "light-oil", 40 } },
    fr = "Hydrocraquage", en = "Hydrocracking" },
}

-- Technologies. x0 = technologie de X0 reprise (déblocages EN JEU seulement) ; epoch = âge (fenêtre de packs) ;
-- count = unités AVANT l'allègement QX9 de l'âge (C.tech_count : même règle que la recherche vanilla) ;
-- prerequisites = prérequis en jeu (ceux de X0 en jeu + la technologie vanilla qui ouvre le pack et les ingrédients).
C.TECHS = {
  { name = "fo-coking", x0 = "fo-coking", epoch = 2, count = 100, time = 15,
    prerequisites = { "logistic-science-pack" },
    unlocks = { "fo-coke-oven", "fo-coke" } },
  { name = "fo-blast-furnace", x0 = "fo-blast-furnace", epoch = 2, count = 150, time = 15,
    prerequisites = { "fo-coking", "steel-processing" },
    unlocks = { "fo-blast-furnace", "fo-blast-furnace-steel", "fo-slag-landfill" } },
  { name = "fo-crushing", x0 = "fo-crushing", epoch = 2, count = 150, time = 15,
    prerequisites = { "fo-blast-furnace" },
    unlocks = { "fo-crusher", "fo-sand", "fo-slag-cement" } },
  { name = "fo-cement-concrete", x0 = "fo-cement-concrete", epoch = 3, count = 200, time = 20,
    prerequisites = { "fo-crushing", "concrete", "military-science-pack" },
    unlocks = { "fo-cement-concrete" } },
  { name = "fo-glassworks", x0 = "fo-glassworks", epoch = 3, count = 150, time = 20,
    prerequisites = { "fo-crushing", "military-science-pack" },
    unlocks = { "fo-glass", "fo-manometer" } },
  { name = "fo-flaring", x0 = "fo-flaring", epoch = 4, count = 100, time = 30,
    prerequisites = { "fo-glassworks", "chemical-science-pack", "fluid-handling" },
    unlocks = { "fo-flare-stack", "fo-flare-ethylene" } },
  { name = "fo-steam-cracking", x0 = "fo-steam-cracking", epoch = 4, count = 200, time = 30,
    prerequisites = { "fo-flaring", "oil-processing" },
    unlocks = { "fo-steam-cracker", "fo-steam-cracking", "fo-polyethylene" } },
  { name = "fo-arc-smelting", x0 = "fo-arc-smelting", epoch = 6, count = 200, time = 30,
    prerequisites = { "production-science-pack", "military-science-pack", "fo-coking", "concrete" },
    unlocks = { "fo-arc-furnace", "fo-graphite", "fo-arc-steel" } },
  { name = "fo-electrical-steel", x0 = "fo-electrical-steel", epoch = 6, count = 250, time = 30,
    prerequisites = { "fo-arc-smelting", "fo-crushing", "electric-engine", "plastics" },
    unlocks = { "fo-magnetic-steel", "fo-coil-winder", "fo-enameled-wire", "fo-coil", "fo-wound-electric-engine" } },
  { name = "fo-titanium-alloys", x0 = "fo-cryostat", epoch = 11, count = 300, time = 30,
    prerequisites = { "fo-titanium-processing", "fo-arc-smelting", "low-density-structure" },
    unlocks = { "fo-titanium-composite", "fo-titanium-lds" } },
  { name = "fo-brine-byproducts", epoch = 11, count = 200, time = 30,
    prerequisites = { "fo-titanium-processing", "advanced-oil-processing", "concrete", "fo-flaring" },
    unlocks = { "fo-hydrocracking", "fo-sorel-concrete", "fo-flare-hydrogen", "fo-flare-chlorine", "fo-flare-brine",
                "fo-flare-titanium-tetrachloride" } },
}

---------------------------------------------------------------------------------------------------
-- Index
---------------------------------------------------------------------------------------------------
local extra_by = {}
for _, r in ipairs(C.EXTRA_RECIPES) do extra_by[r.name] = r end

local IN_GAME = {}
for _, n in ipairs(C.ITEMS) do IN_GAME[n] = true end
for _, n in ipairs(C.FLUIDS) do IN_GAME[n] = true end
for _, b in ipairs(C.BUILDINGS) do IN_GAME[b.name] = true end

--- L'objet existe-t-il en jeu avec ce lot et X1 ? (nom vanilla, objet du mod en jeu)
function C.present(name)
  return T.present(name) or IN_GAME[name] == true
end

--- Packs vanilla de la fenêtre X0 de l'âge k (pack militaire ajouté dès l'âge 4 : X.pack_window), ordre de
--- lib.SCIENCE (du rouge au spatial). Les packs du mod (fo-*) ne sont pas en jeu : retirés.
local ORDER = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "chemical-science-pack",
                "production-science-pack", "utility-science-pack", "space-science-pack" }
function C.packs(k)
  local want = {}
  for _, p in ipairs(X.pack_window(k, { military = true })) do want[p] = true end
  -- La fenêtre glisse : l'âge k exige aussi les packs vanilla plus anciens encore utilisés en jeu (les technologies
  -- vanilla de l'âge k les exigent toutes), du rouge jusqu'au pack de l'âge.
  local top = 0
  for i, p in ipairs(ORDER) do if want[p] then top = i end end
  local out = {}
  for i = 1, top do
    local p = ORDER[i]
    if p ~= "military-science-pack" or want[p] or k >= 3 then out[#out + 1] = p end
  end
  return out
end

--- Unités de recherche d'une technologie du lot : count × X.VANILLA_UNIT_SCALE de son âge (règle QX9 de la recherche
--- vanilla, data-final-fixes.lua), au moins 10, arrondi au-dessus.
function C.tech_count(t)
  return math.max(10, math.ceil(t.count * X.VANILLA_UNIT_SCALE[t.epoch] - 1e-9))
end

--- Recette de procédé en jeu (X0, avec substitutions, ou hors X0) : { name, category, time, ingredients, results,
--- fr, en, x0 = bool, subst = { {de, vers} }, prod }.
function C.process_recipe(name)
  local spec
  for _, rr in ipairs(C.RECIPES) do if rr.name == name then spec = rr end end
  if not spec then
    local e = assert(extra_by[name], "crafts : recette inconnue " .. name)
    return { name = e.name, category = e.category, time = e.time, ingredients = e.ingredients, results = e.results,
             fr = e.fr, en = e.en, epoch = e.epoch, x0 = false, subst = {}, prod = false }
  end
  local x = assert(T.x_recipe(name), "crafts : recette X0 absente " .. name)
  local ings, subst = {}, {}
  for _, i in ipairs(x.ingredients) do
    local to = spec.subst and spec.subst[i[1]]
    if to then
      subst[#subst + 1] = { i[1], to }
      ings[#ings + 1] = { to, i[2] }
    else
      ings[#ings + 1] = { i[1], i[2] }
    end
  end
  return { name = x.name, category = x.category, time = x.time, ingredients = ings, results = x.results,
           fr = x.fr, en = x.en, epoch = x.epoch, x0 = true, subst = subst, prod = x.prod == true, main = spec.main,
           flare = spec.flare == true }
end

--- Toutes les recettes de procédé du lot (X0 puis hors X0), dans l'ordre d'affichage.
function C.all_recipes()
  local out = {}
  for _, rr in ipairs(C.RECIPES) do out[#out + 1] = C.process_recipe(rr.name) end
  for _, e in ipairs(C.EXTRA_RECIPES) do out[#out + 1] = C.process_recipe(e.name) end
  return out
end

--- Recette en jeu d'un bâtiment du lot : celle de X0 (aucun dépliage nécessaire : contrôlé par le banc).
function C.building_recipe(name)
  local r = assert(T.x_recipe(name), "crafts : recette X0 absente pour " .. name)
  return { name = r.name, category = r.category, time = r.time, ingredients = r.ingredients }
end

--- Catégories de fabrication NEUVES (celles des bâtiments du lot qui ne sont pas déjà en jeu par X1).
function C.new_categories()
  local known = {}
  for _, c in ipairs(T.new_categories()) do known[c] = true end
  local out = {}
  for _, b in ipairs(C.BUILDINGS) do
    for _, c in ipairs(T.x_building(b.name).categories or {}) do
      if not known[c] then known[c] = true; out[#out + 1] = c end
    end
  end
  return out
end

--- Recettes du lot éligibles aux modules de productivité : celles que X0 marque « prod », jamais une recette
--- hors X0 ni une recette réversible.
function C.productivity_recipes()
  local out = {}
  for _, r in ipairs(C.all_recipes()) do if r.prod then out[#out + 1] = r.name end end
  return out
end

return C
