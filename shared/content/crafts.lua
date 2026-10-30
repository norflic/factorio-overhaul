--[[
  Lot AMELIO-CRAFTS (nuit du 29 au 30/10) : chaînes de fabrication des âges 2, 3, 4, 6, 8, 10 et 11 EN JEU, tirées du scénario X0
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
  "fo-metallurgical-silicon", "fo-pure-silicon", "fo-silicon-wafer", -- âge 10 (silicium et salle blanche, étape 4)
  -- âge 10 (étape 5) : concentrés et billettes ρ8 (une billette = 8 plaques : 8 fois moins d'objets sur les tapis)
  "fo-iron-concentrate", "fo-copper-concentrate", "fo-tungsten-concentrate",
  "fo-iron-plate-r8", "fo-copper-plate-r8", "fo-tungsten-plate-r8",
}
-- Fluides de X0 mis en jeu par ce lot.
C.FLUIDS = { "fo-ethylene", "fo-carbon-dioxide" }

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
  -- Étape 4 (âges 8 et 10).
  { name = "fo-reformer", copy = { "assembling-machine", "chemical-plant" }, side = 3, tint = { r = 0.62, g = 0.82, b = 0.70 } },
  { name = "fo-cleanroom", copy = { "assembling-machine", "assembling-machine-3" }, side = 3, tint = { r = 0.90, g = 0.96, b = 1.00 } },
}

-- Sols de X0 mis en jeu (étape 6). Visuel PROVISOIRE : copie teintée d'un sol vanilla ; layer libre de vanilla (63).
-- Un sol posé est un usage final (comme un bâtiment) : tests/crafts_test.lua le compte ainsi.
C.TILES = {
  { name = "fo-asphalt", copy = "concrete", layer = 63, tint = { r = 0.40, g = 0.40, b = 0.43 },
    map_color = { r = 0.20, g = 0.20, b = 0.22 } },
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
  -- ÉCART de coût (audit AMELIO-CRAFTS) : dans X0, la bobine ne remplace que 5 lubrifiants sur 15, pour environ 10 fers,
  -- 10 gaz et 1 cuivre de plus : une variante que personne ne prendrait. Ici elle SUPPRIME le lubrifiant (assemblage
  -- sans fluide, en assembleur sans tuyau) : un vrai choix, solides contre pétrole. Catégorie « advanced-crafting » : en
  -- assembleur SEULEMENT, comme le moteur électrique vanilla (jamais à la main ; étape 7, revue des biais).
  { name = "fo-wound-electric-engine", drop = { "lubricant" }, category = "advanced-crafting" },
  { name = "fo-titanium-composite", subst = { ["fo-biopolymer"] = "plastic-bar" } },
  { name = "fo-titanium-lds" },
  -- Torchères (X0 : une recette « sink » par fluide neuf) pour les fluides du mod en jeu : aucun fluide de sous-produit
  -- ne peut plus bloquer une usine.
  { name = "fo-flare-ethylene", flare = true },
  { name = "fo-flare-hydrogen", flare = true },
  { name = "fo-flare-chlorine", flare = true },
  { name = "fo-flare-brine", flare = true },
  { name = "fo-flare-titanium-tetrachloride", flare = true },
  -- Étape 4, âge 8 (Méthane) : le reformage fait de l'hydrogène dès l'âge 8 (hydrocraquage) ; son dioxyde de carbone
  -- carbonate le laitier en ciment, ou part à la torchère.
  { name = "fo-methane-reforming", main = "fo-hydrogen" },
  { name = "fo-slag-carbonation" },
  { name = "fo-flare-carbon-dioxide", flare = true },
  -- Étape 4, âge 10 (Silicium) : sable + graphite -> silicium métallurgique -> silicium pur (mange l'hydrogène) ->
  -- tranches -> processeur en salle blanche (variante du processeur vanilla, monnaie de l'âge 10).
  { name = "fo-metallurgical-silicon" },
  { name = "fo-pure-silicon" },
  { name = "fo-silicon-wafer" },
  -- ÉCART de rendement : X0 donne 2 processeurs pour 10 circuits verts, 2 rouges, 1 tranche et 5 acides, soit 4 fois
  -- moins de circuits verts que la recette vanilla. Le processeur est la MONNAIE de l'âge 10 (shared/levels/config.lua,
  -- valeur 75) : la variante de X0 diviserait par 2,5 environ le coût réel des niveaux de l'âge 10. Ici 1 processeur :
  -- la tranche remplace 10 circuits verts sur 20 (calcul : C.bilan, tests/crafts_test.lua §5 bis).
  { name = "fo-cleanroom-processor", results = { { "processing-unit", 1 } },
    ecart = "1 processeur au lieu de 2 (monnaie de l'âge 10)" },
  -- Étape 5, âge 10 (forme dense ρ8, X0 « fo-concentration » et « fo-billets ») : 8 minerais -> 1 concentré (concentrateur
  -- du titane) -> 1 billette (four à arc) -> 8 plaques (découpe, à la main ou en assembleur). Même matière que la fonte
  -- vanilla (8 minerais, 8 plaques) : la voie gagne de la PLACE (un concentrateur et un four à arc font le travail
  -- d'environ 48 fours en acier) et du transport (8 fois moins d'objets), pas de matière.
  { name = "fo-iron-concentrate" },
  { name = "fo-copper-concentrate" },
  { name = "fo-tungsten-concentrate" },
  { name = "fo-iron-plate-r8" },
  { name = "fo-copper-plate-r8" },
  { name = "fo-tungsten-plate-r8" },
  { name = "fo-iron-plate-r8-unpacking" },
  { name = "fo-copper-plate-r8-unpacking" },
  { name = "fo-tungsten-plate-r8-unpacking" },
  -- Étape 6, âge 4 (Pétrole) : asphalte (sol rapide pour les véhicules), un débouché de l'huile lourde et du sable.
  { name = "fo-asphalt" },
}

-- Recettes HORS X0 (fermeture des boucles en jeu). Même format que les recettes de X0.
C.EXTRA_RECIPES = {
  -- Laitier : sans béton à faire, le haut fourneau se bloquerait. Le remblai l'absorbe sans limite
  -- (vanilla : 20 pierres pour 1 remblai ; ici 20 laitiers, un déchet).
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
  -- Âge 8 depuis l'étape 4 : le reformage du méthane fait de l'hydrogène dès l'âge 8 (11 avant : seule la saumure).
  { name = "fo-hydrocracking", epoch = 8, category = "chemistry", time = 2,
    ingredients = { { "heavy-oil", 40 }, { "fo-hydrogen", 30 } }, results = { { "light-oil", 40 } },
    fr = "Hydrocraquage", en = "Hydrocracking" },
  -- Procédé Siemens : recette du scénario X3 (« chaîne B », variante du silicium pur), reprise
  -- TELLE QUELLE (x3 = true, contrôlé par tests/crafts_test.lua). Le chlore tourne en boucle (catalyseur), 2 sont
  -- perdus par fabrication : un débouché du chlore et de l'hydrogène de la saumure à l'âge 11.
  { name = "fo-siemens-silicon", epoch = 11, category = "chemistry", time = 8, x3 = true,
    ingredients = { { "fo-metallurgical-silicon", 3 }, { "fo-chlorine", 12, catalyst = 10 }, { "fo-hydrogen", 75 } },
    results = { { "fo-pure-silicon", 2 }, { "fo-chlorine", 10, catalyst = 10 } }, main = "fo-pure-silicon",
    fr = "Silicium pur (procédé Siemens)", en = "Pure silicon (Siemens process)" },
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
  -- Étape 4.
  { name = "fo-methane-reforming", x0 = "fo-methane-reforming", epoch = 8, count = 200, time = 30,
    prerequisites = { "fo-flaring", "fo-methane-processing", "fo-tungsten-processing", "advanced-oil-processing",
                      "advanced-electronics", "production-science-pack" },
    unlocks = { "fo-reformer", "fo-methane-reforming", "fo-hydrocracking", "fo-flare-hydrogen", "fo-flare-carbon-dioxide" } },
  -- X0 « fo-digester » : le digesteur (tissu de déchiqueteur, absent du jeu) n'est pas repris ; seule la carbonatation.
  { name = "fo-carbonation", x0 = "fo-digester", epoch = 8, count = 150, time = 30,
    prerequisites = { "fo-methane-reforming", "fo-crushing" },
    unlocks = { "fo-slag-carbonation" } },
  { name = "fo-silicon", x0 = "fo-silicon", epoch = 10, count = 400, time = 30,
    prerequisites = { "fo-methane-reforming", "fo-electrical-steel", "fo-glassworks", "sulfur-processing",
                      "utility-science-pack", "concrete" },
    unlocks = { "fo-metallurgical-silicon", "fo-pure-silicon", "fo-cleanroom", "fo-silicon-wafer", "fo-cleanroom-processor" } },
  { name = "fo-siemens-process", epoch = 11, count = 200, time = 30,
    prerequisites = { "fo-silicon", "fo-brine-byproducts" },
    unlocks = { "fo-siemens-silicon" } },
  -- Étape 5. Le concentrateur (lot X1) n'était ouvert qu'à l'âge 11 par la technologie du titane : il l'est aussi ici
  -- (âge 10 dans X0). La foreuse de concentré de X0 n'est pas en jeu (famille des foreuses à niveaux).
  { name = "fo-concentration", x0 = "fo-concentration", epoch = 10, count = 300, time = 30,
    prerequisites = { "fo-arc-smelting", "fo-electrical-steel", "fo-tungsten-processing", "utility-science-pack" },
    unlocks = { "fo-ore-concentrator", "fo-iron-concentrate", "fo-copper-concentrate", "fo-tungsten-concentrate" } },
  { name = "fo-asphalt", x0 = "fo-asphalt", epoch = 4, count = 100, time = 30,
    prerequisites = { "fo-crushing", "oil-processing", "concrete", "chemical-science-pack" },
    unlocks = { "fo-asphalt" } },
  { name = "fo-billets", x0 = "fo-billets", epoch = 10, count = 300, time = 30,
    prerequisites = { "fo-concentration" },
    unlocks = { "fo-iron-plate-r8", "fo-copper-plate-r8", "fo-tungsten-plate-r8", "fo-iron-plate-r8-unpacking",
                "fo-copper-plate-r8-unpacking", "fo-tungsten-plate-r8-unpacking" } },
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
for _, t in ipairs(C.TILES) do IN_GAME[t.name] = true end

--- Spécification de X0 d'un sol (X.tiles) : { name, epoch, walking_speed_modifier, vehicle_friction_modifier, ... }.
function C.x_tile(name)
  for _, t in ipairs(X.tiles) do if t.name == name then return t end end
  return nil
end

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
             fr = e.fr, en = e.en, epoch = e.epoch, x0 = false, x3 = e.x3 == true, subst = {}, prod = false, main = e.main }
  end
  local x = assert(T.x_recipe(name), "crafts : recette X0 absente " .. name)
  local ings, subst, dropped = {}, {}, {}
  local drop = {}
  for _, d in ipairs(spec.drop or {}) do drop[d] = true end
  for _, i in ipairs(x.ingredients) do
    local to = spec.subst and spec.subst[i[1]]
    if drop[i[1]] then
      dropped[#dropped + 1] = i[1]
    elseif to then
      subst[#subst + 1] = { i[1], to }
      ings[#ings + 1] = { to, i[2] }
    else
      ings[#ings + 1] = { i[1], i[2] }
    end
  end
  return { name = x.name, category = spec.category or x.category, time = x.time, ingredients = ings,
           results = spec.results or x.results, ecart = spec.ecart,
           fr = x.fr, en = x.en, epoch = x.epoch, x0 = true, subst = subst, dropped = dropped, prod = x.prod == true,
           main = spec.main, flare = spec.flare == true }
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


---------------------------------------------------------------------------------------------------
-- Calcul : coût en matières premières des variantes contre la recette vanilla (BALANCE_SHEET, partie AMELIO-CRAFTS)
---------------------------------------------------------------------------------------------------
-- Matières premières comptées (le reste se déplie) ; les sous-produits du mod sont gratuits (on les a de toute façon).
-- (Les billettes ρ8 ne changent pas la matière : elles se comptent en débit, C.rates, pas ici.)
C.RAW = { ["iron-plate"] = "fer", ["iron-ore"] = "fer", ["copper-plate"] = "cuivre", ["stone"] = "pierre", ["coal"] = "charbon",
          ["petroleum-gas"] = "gaz", ["heavy-oil"] = "huile lourde", ["water"] = "eau", ["steam"] = "eau",
          ["fo-titanium-plate"] = "titane", ["engine-unit"] = "moteur", ["sulfuric-acid"] = "acide" }
C.FREE = { ["fo-slag"] = true, ["fo-magnesium-chloride"] = true, ["fo-caustic-soda"] = true, ["fo-hydrogen"] = true }
C.RAW_ORDER = { "fer", "cuivre", "pierre", "charbon", "gaz", "huile lourde", "eau", "acide", "titane", "moteur" }
-- Recettes vanilla 1.1.91 de référence (data/base/prototypes/recipe.lua, mode normal) : { ingrédients }, quantité produite.
C.VANILLA_REF = {
  ["steel-plate"] = { { { "iron-plate", 5 } }, 1 },
  ["stone-brick"] = { { { "stone", 2 } }, 1 },
  ["concrete"] = { { { "stone-brick", 5 }, { "iron-ore", 1 }, { "water", 100 } }, 10 },
  ["refined-concrete"] = { { { "concrete", 20 }, { "iron-stick", 8 }, { "steel-plate", 1 }, { "water", 100 } }, 10 },
  ["iron-stick"] = { { { "iron-plate", 1 } }, 2 },
  ["iron-gear-wheel"] = { { { "iron-plate", 2 } }, 1 },
  ["pipe"] = { { { "iron-plate", 1 } }, 1 },
  ["plastic-bar"] = { { { "petroleum-gas", 20 }, { "coal", 1 } }, 2 },
  ["copper-cable"] = { { { "copper-plate", 1 } }, 2 },
  ["electronic-circuit"] = { { { "iron-plate", 1 }, { "copper-cable", 3 } }, 1 },
  ["low-density-structure"] = { { { "steel-plate", 2 }, { "copper-plate", 20 }, { "plastic-bar", 5 } }, 1 },
  ["electric-engine-unit"] = { { { "engine-unit", 1 }, { "lubricant", 15 }, { "electronic-circuit", 2 } }, 1 },
  ["lubricant"] = { { { "heavy-oil", 10 } }, 10 },
  ["landfill"] = { { { "stone", 20 } }, 1 },
  ["light-oil"] = { { { "heavy-oil", 40 }, { "water", 30 } }, 30 },
  ["advanced-circuit"] = { { { "plastic-bar", 2 }, { "copper-cable", 4 }, { "electronic-circuit", 2 } }, 1 },
  ["processing-unit"] = { { { "electronic-circuit", 20 }, { "advanced-circuit", 2 }, { "sulfuric-acid", 5 } }, 1 },
}

--- Coût en matières premières d'UNE unité de `item` : table { [matière] = quantité }. `via` : nom de la recette du lot
--- à employer pour cet objet (sinon recette vanilla de référence, puis recette du lot ou de X1 qui le fabrique).
function C.raw_cost(item, via, depth)
  depth = depth or 0
  assert(depth < 12, "crafts : dépliage trop profond pour " .. item)
  local out = {}
  local function add(t, k)
    for _, m in ipairs(C.RAW_ORDER) do if t[m] then out[m] = (out[m] or 0) + t[m] * k end end
  end
  if C.FREE[item] then return out end
  if C.RAW[item] then out[C.RAW[item]] = 1; return out end
  local ings, per
  if via then
    local r = C.process_recipe(via)
    ings = r.ingredients
    for _, p in ipairs(r.results) do if p[1] == item then per = p[2] end end
  elseif C.VANILLA_REF[item] then
    ings, per = C.VANILLA_REF[item][1], C.VANILLA_REF[item][2]
  else
    local maker
    for _, r in ipairs(C.all_recipes()) do
      for _, p in ipairs(r.results) do if p[1] == item and not maker then maker, per = r, p[2] end end
    end
    if not maker then
      for _, rr in ipairs(T.RECIPES) do
        local r = T.process_recipe(rr.name)
        for _, p in ipairs(r.results) do if p[1] == item and not maker then maker, per = r, p[2] end end
      end
    end
    assert(maker, "crafts : aucune recette pour " .. item)
    ings = maker.ingredients
  end
  assert(per and per > 0, "crafts : quantité produite inconnue pour " .. item)
  for _, i in ipairs(ings) do add(C.raw_cost(i[1], nil, depth + 1), i[2] / per) end
  return out
end

--- Machine de référence d'une catégorie : { nom, vitesse }. Catégories du mod : la première machine en jeu (X1 puis ce
--- lot) qui la fait, vitesse de X0 ; catégories vanilla : assembleur 3, usine chimique, four en acier.
C.VANILLA_MACHINES = {
  crafting = { "assembling-machine-3", 1.25 }, ["crafting-with-fluid"] = { "assembling-machine-3", 1.25 },
  ["advanced-crafting"] = { "assembling-machine-3", 1.25 }, chemistry = { "chemical-plant", 1 },
  smelting = { "steel-furnace", 2 }, ["oil-processing"] = { "oil-refinery", 1 },
}
function C.machine_of(category)
  if C.VANILLA_MACHINES[category] then return C.VANILLA_MACHINES[category][1], C.VANILLA_MACHINES[category][2] end
  local lists = { T.BUILDINGS, C.BUILDINGS }
  for _, l in ipairs(lists) do
    for _, b in ipairs(l) do
      local x = T.x_building(b.name)
      for _, c in ipairs(x and x.categories or {}) do if c == category then return b.name, x.speed end end
    end
  end
  return nil, nil
end

--- Débits : pour chaque recette du lot, { recipe, machine, speed, per_min = produit principal par minute et par machine,
--- main } (sans module ; une torchère : fabrications par minute, main = nil).
function C.rates()
  local rows = {}
  for _, r in ipairs(C.all_recipes()) do
    local m, sp = C.machine_of(r.category)
    local main = r.main or (#r.results == 1 and r.results[1][1]) or nil
    local q = 1
    for _, p in ipairs(r.results) do if p[1] == main then q = p[2] end end
    rows[#rows + 1] = { recipe = r.name, machine = m, speed = sp, main = main,
                        per_min = sp and (60 * sp / r.time * (main and q or 1)) or nil, epoch = r.epoch }
  end
  return rows
end

--- Bilan des variantes (recettes du lot dont le produit principal est vanilla) : liste triée de
--- { recipe, product, variant = coût, vanilla = coût, saves = { matière économisée }, costs = { matière en plus } }.
function C.bilan()
  local rows = {}
  for _, r in ipairs(C.all_recipes()) do
    local main = r.main or (#r.results == 1 and r.results[1][1]) or nil
    if main and not main:find("^fo%-") and C.VANILLA_REF[main] then
      local v = C.raw_cost(main, r.name)
      local w = C.raw_cost(main)
      local saves, costs = {}, {}
      for _, m in ipairs(C.RAW_ORDER) do
        local a, b = v[m] or 0, w[m] or 0
        if a < b - 1e-9 then saves[#saves + 1] = m elseif a > b + 1e-9 then costs[#costs + 1] = m end
      end
      rows[#rows + 1] = { recipe = r.name, product = main, variant = v, vanilla = w, saves = saves, costs = costs }
    end
  end
  return rows
end

--- MU d'une matière première (BALANCE_SHEET §3 : 1 MU = 1 plaque de fer ; fluides X.FLUID_MU, eau gratuite ; titane et
--- moteur à leur valeur de monnaie).
C.MU = { ["fer"] = 1, ["cuivre"] = 1, ["pierre"] = 1, ["charbon"] = 1, ["gaz"] = X.FLUID_MU, ["huile lourde"] = X.FLUID_MU,
         ["eau"] = 0, ["acide"] = X.FLUID_MU, ["titane"] = 20, ["moteur"] = 9 }
function C.mu(cost)
  local s = 0
  for _, m in ipairs(C.RAW_ORDER) do s = s + (cost[m] or 0) * (C.MU[m] or 0) end
  return s
end

--- Effet du lot sur les MONNAIES des niveaux (shared/levels/config.lua, L.epoch_materials) : pour chaque monnaie qu'une
--- variante du lot fabrique, MU des matières premières par la recette vanilla et par la variante. Un niveau se paie en
--- objets : une variante moins chère en matière rend les niveaux de l'âge moins chers à qui la construit.
function C.currency_impact(epoch_materials)
  local rows = {}
  local ks = {}
  for k in pairs(epoch_materials) do ks[#ks + 1] = k end
  table.sort(ks)
  for _, k in ipairs(ks) do
    local item = epoch_materials[k].item
    for _, r in ipairs(C.all_recipes()) do
      local main = r.main or (#r.results == 1 and r.results[1][1]) or nil
      if main == item and C.VANILLA_REF[item] then
        local v, w = C.mu(C.raw_cost(item)), C.mu(C.raw_cost(item, r.name))
        rows[#rows + 1] = { epoch = k, item = item, recipe = r.name, vanilla_mu = v, variant_mu = w, delta = (w - v) / v }
      end
    end
  end
  return rows
end

return C
