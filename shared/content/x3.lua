--[[
  Lot X3 (27/10) : graphe de fabrication plus réaliste et minerais par âge. PROPOSITION, PAS EN JEU.
  Pur Lua, AUCUNE API Factorio. AUCUN fichier du jeu ne lit ce module (ni data.lua, ni control.lua, ni prototypes/, ni
  script/) : il ne vit que hors jeu, par tests/x3_test.lua. Scénario lisible : docs/SCENARIO_EPOQUES.md §3.7.

  Ce module ENRICHIT le scénario approuvé des 15 âges (lot X0, shared/content/epochs.lua) sans le modifier :
  X3.merge(X) prend une copie FRAÎCHE de X (dofile, jamais le module de require) et lui ajoute, EN FIN DE LISTE :
  ressources, objets, bâtiments, recettes et technologies d'X3, puis applique les retouches (recettes X0 complétées),
  les extensions de technologies X0 et le recalage des unités de recherche (X3.tech_units). En fin de liste : la règle
  T.maker de shared/content/titanium.lua (première recette X qui produit un objet) ne change pas.

  Synthèse de trois propositions de concepteurs (« puces, optique, impression et calcul », « minerais et géologie par
  âge », « usages, machines assemblées et robots de défense »). Trois chaînes marquantes, et ailleurs presque rien :
    A. « Imprimer les puces » (âges 4, 7, 10) : étain → carte imprimée ; laser à cristal ; quartz → creuset → lingot →
       tranches → lithographie → tranche gravée → processeur, mémoire, carte graphique ;
    B. « Calculer » (âge 10, puis 11 à 15) : cartes graphiques → centre de calcul → calcul (fluide) → noyau de pilotage ;
       procédé Siemens à l'âge 11 ; noyaux et cartes dans les bâtiments des âges 13 à 15 ;
    C. « Monter des machines, se défendre » (âges 6, 7, 10, 12) : bauxite → alumine → aluminium → servomoteur ; capteur,
       contrôleur, drone laser ; drone de garde ; actionneur à aimants, barreau Nd:YAG, module laser → robot de combat.
  Quatre ressources nouvelles (au plus une par âge) : blende (3), cassitérite (4), bauxite (6), quartz filonien (10).

  Conventions : celles d'epochs.lua (préfixe fo-, tableaux parcourus par ipairs, durées en s à la vitesse 1, kW, MJ,
  rho en MU par objet). Formats : R(nom, époque, catégorie, durée, ingrédients, produits, options), I, F, B{}, T.
  Statut : PROPOSITION à valider par le Directeur Créatif (questions Q-X3-1 à Q-X3-3 ci-dessous).
]]

local X3 = {}

X3.VERSION = 1
X3.LOT = "X3"
X3.STATUS_FR = "proposition hors jeu (27/10) : aucun prototype, aucune locale, aucun fichier du jeu ne lit ce module"

-- Mêmes listes que shared/content/epochs.lua (locales là-bas ; tests/x3_test.lua contrôle qu'elles n'ont pas dérivé).
local DRILLS = { "character", "burner-mining-drill", "fo-steam-drill", "electric-mining-drill", "fo-heavy-drill", "fo-concentrate-drill", "fo-core-drill" }
local HARD_DRILLS = { "electric-mining-drill", "fo-heavy-drill", "fo-concentrate-drill", "fo-core-drill" }
X3.DRILLS, X3.HARD_DRILLS = DRILLS, HARD_DRILLS

---------------------------------------------------------------------------------------------------
-- 1. Ressources de la carte (au plus 2 nouvelles par âge ; ici une seule, aux âges 3, 4, 6 et 10).
--    Aucune n'est en jeu : il faudra pour chacune une entrée de shared/content/world.lua, une garantie M0 et un kit
--    minerai M1 (8 stades), mesurés au plancher de mémoire vidéo (F186) avant intégration.
---------------------------------------------------------------------------------------------------
X3.resources = {
  { name = "fo-sphalerite", epoch = 3, kind = "ore", category = "basic-solid", products = { "fo-sphalerite" },
    min_distance = 150, fr = "Blende", en = "Sphalerite",
    where_fr = "filons des collines rocheuses (sol vanilla), à plus de 150 tuiles du départ",
    look_fr = "tétraèdres résineux couleur miel à rouge rubis",
    placement = { autoplace = "vanilla-like", guaranteed = { count = 2, distance = { 150, 400 },
      what_fr = "2 gisements de 200 000 posés par script si l'autoplace n'en a mis aucun à cette distance" } } },
  { name = "fo-cassiterite", epoch = 4, kind = "ore", category = "basic-solid", products = { "fo-cassiterite" },
    min_distance = 120, fr = "Cassitérite", en = "Cassiterite",
    where_fr = "placers allongés au bord de l'eau (sol vanilla), à plus de 120 tuiles du départ",
    look_fr = "galets brun chocolat à éclat adamantin, éclats blancs de quartz (pour ne pas la confondre avec le charbon)",
    placement = { autoplace = "vanilla-like", guaranteed = { count = 2, distance = { 120, 350 },
      what_fr = "2 gisements de 150 000 posés par script si l'autoplace n'en a mis aucun à cette distance" } } },
  { name = "fo-bauxite", epoch = 6, kind = "ore", category = "basic-solid", products = { "fo-bauxite" },
    min_distance = 300, fr = "Bauxite", en = "Bauxite",
    where_fr = "désert rouge vanilla (latérites), à plus de 300 tuiles du départ",
    look_fr = "pisolithes mates brique-ocre dans une terre rouille",
    placement = { autoplace = "vanilla-like", guaranteed = { count = 3, distance = { 300, 600 },
      what_fr = "3 gisements de 300 000 posés par script si l'autoplace n'en a mis aucun à cette distance" } } },
  { name = "fo-vein-quartz", epoch = 10, kind = "ore", category = "fo-hard-solid", products = { "fo-vein-quartz" },
    biome = "fo-crystal-flats", fr = "Quartz filonien", en = "Vein quartz",
    where_fr = "veines blanches de la plaine de cristal (biome en jeu depuis le lot B0)",
    look_fr = "prismes hexagonaux blanc laiteux en gerbes, sans lueur (pour ne pas le confondre avec le cristal de résonance violet)",
    placement = { autoplace = "fo-crystal-flats", guaranteed = { count = 2, distance = { 400, 800 },
      what_fr = "2 veines de 200 000 posées par script sur une plaine de cristal à cette distance (celle de la garantie M0 si elle y est)" } } },
}

---------------------------------------------------------------------------------------------------
-- 2. Objets et fluides nouveaux (mêmes champs qu'epochs.lua : use, material, rho, stack, source, barrel...).
---------------------------------------------------------------------------------------------------
local STACK_BY_USE = { pack = 200, data = 200, ammo = 200, codex = 10, launch = 1, armor = 1, tile = 100, consumable = 50 }
local items = {}
local function I(name, epoch, fr, en, o)
  o = o or {}
  o.name, o.epoch, o.fr, o.en = name, epoch, fr, en
  o.type = o.type or "item"
  if o.type == "item" and not o.stack then
    o.stack = STACK_BY_USE[o.use or ""] or ((o.fuel or (o.rho or 0) >= 32) and 50) or 100
  end
  items[#items + 1] = o
  return o
end
local function F(name, epoch, fr, en, o)
  o = o or {}
  o.type = "fluid"
  if o.barrel == nil then o.barrel = true end
  return I(name, epoch, fr, en, o)
end

-- Âge 3 · Vapeur : le laiton du manomètre
I("fo-sphalerite", 3, "Blende", "Sphalerite", { source = "mining" })
I("fo-zinc-plate", 3, "Plaque de zinc", "Zinc plate", { material = true, rho = 1 })
I("fo-brass", 3, "Laiton", "Brass", { note_fr = "tube de Bourdon du manomètre" })
-- Âge 4 · Pétrole : l'imprimerie des cartes (chaîne A)
I("fo-cassiterite", 4, "Cassitérite", "Cassiterite", { source = "mining" })
I("fo-tin-plate", 4, "Plaque d'étain", "Tin plate", { material = true, rho = 1, note_fr = "étamage et soudure des cartes" })
F("fo-epoxy-resin", 4, "Résine époxy", "Epoxy resin", { note_fr = "liant des stratifiés ; base de la résine photosensible (âge 10)" })
I("fo-copper-clad-laminate", 4, "Stratifié cuivré", "Copper-clad laminate")
I("fo-printed-circuit-board", 4, "Carte de circuit imprimé", "Printed circuit board")
-- Âge 6 · Électricité : l'aluminium et le servomoteur (chaîne C)
I("fo-bauxite", 6, "Bauxite", "Bauxite", { source = "mining" })
I("fo-alumina", 6, "Alumine", "Alumina")
I("fo-red-mud", 6, "Boue rouge", "Red mud", { note_fr = "sous-produit du frittage, rendu en ciment (aucun stock qui dort)" })
I("fo-aluminium-plate", 6, "Plaque d'aluminium", "Aluminium plate", { material = true, rho = 1 })
I("fo-servo-motor", 6, "Servomoteur", "Servo motor", { note_fr = "actionneur de 1re génération" })
-- Âge 7 · Cristal : premier laser, capteur, contrôleur, premier robot de défense (chaînes A et C)
I("fo-crystal-laser", 7, "Laser à cristal", "Crystal laser", { note_fr = "la lentille de résonance sert enfin à un laser" })
I("fo-optical-sensor", 7, "Capteur optique", "Optical sensor")
I("fo-controller", 7, "Contrôleur programmable", "Programmable controller")
I("fo-laser-drone-capsule", 7, "Capsule de drone laser", "Laser drone capsule", { use = "ammo", stack = 100,
  effect_fr = "capsule : fait naître un robot de combat (prototype combat-robot, faisceau de la tourelle laser) qui suit son lanceur 3 min, comme le distracteur vanilla" })
-- Âge 10 · Haute technologie : la fonderie de puces (A) et le calcul (B)
I("fo-vein-quartz", 10, "Quartz filonien", "Vein quartz", { source = "mining" })
I("fo-quartz-crucible", 10, "Creuset de quartz", "Quartz crucible", { note_fr = "perdu à chaque tirage, comme en usine" })
I("fo-silicon-ingot", 10, "Lingot de silicium monocristallin", "Monocrystalline silicon ingot")
F("fo-photoresist", 10, "Résine photosensible", "Photoresist")
I("fo-photomask", 10, "Photomasque", "Photomask", { note_fr = "motif sur verre, absorbeur en tungstène ; s'use à la lithographie" })
I("fo-etched-wafer", 10, "Tranche gravée", "Etched wafer", { note_fr = "insolation, gravure et découpe en une recette" })
I("fo-memory-module", 10, "Module de mémoire", "Memory module")
I("fo-graphics-card", 10, "Carte graphique", "Graphics card", { note_fr = "puces gravées, mémoire, carte, radiateur d'aluminium" })
F("fo-compute", 10, "Calcul", "Compute", { barrel = false,
  note_fr = "ressource PRODUITE comme l'électricité : un centre de calcul de 10 MW rend 50 unités/s (200 kJ l'unité) ; sans baril, par tuyau seulement ; sans valeur de combustion" })
I("fo-guidance-core", 10, "Noyau de pilotage", "Guidance core", { note_fr = "modèle de pilotage entraîné par le calcul" })
I("fo-guard-drone-capsule", 10, "Capsule de drone de garde", "Guard drone capsule", { use = "ammo", stack = 50,
  effect_fr = "capsule : fait naître un robot de combat laser (prototype combat-robot, follows_player = false) qui garde le point de lancer 10 min" })
-- Âge 12 · Supraconducteurs : le robot de combat (C)
I("fo-magnetic-actuator", 12, "Actionneur à aimants", "Magnet actuator", { note_fr = "actionneur de 2e génération : l'aimant permanent entre enfin dans un moteur" })
I("fo-ndyag-rod", 12, "Barreau laser Nd:YAG", "Nd:YAG laser rod", { note_fr = "grenat Y₃Al₅O₁₂ dopé au néodyme : yttrium, néodyme et alumine" })
I("fo-laser-module", 12, "Module laser", "Laser module")
I("fo-combat-robot", 12, "Robot de combat", "Combat robot", { use = "ammo", stack = 10,
  effect_fr = "capsule lancée : fait naître une unité de combat (prototype unit) de la force du lanceur, qui tient sa place (H-X3-2)" })

X3.items = items

---------------------------------------------------------------------------------------------------
-- 3. Bâtiments nouveaux (6). Visuel PROVISOIRE : copie teintée d'une machine vanilla (comme T.BUILDINGS du titane),
--    0 page d'atlas en plus ; un vrai modèle passera par le verdict du DC sur capture.
---------------------------------------------------------------------------------------------------
local buildings = {}
local function B(o) buildings[#buildings + 1] = o; return o end
local ELEC = { type = "electric" }
local function LV(family) return { family = family } end

B{ name = "fo-circuit-printer", epoch = 4, fr = "Imprimante de circuits", en = "Circuit printer",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 300, speed = 1, categories = { "fo-circuit-printing" },
   fluid_in = 1, levels = LV("assembler"), sprite_fr = "copie teintée d'assembling-machine-2" }
B{ name = "fo-reduction-cell", epoch = 6, fr = "Cuve d'électrolyse ignée", en = "Fused-salt reduction cell",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 6000, speed = 1, categories = { "fo-fused-salt-electrolysis" },
   levels = LV("furnace"), sprite_fr = "copie teintée du four électrique",
   note_fr = "la plus gourmande de l'âge 6 (le four à arc tire 4,4 MW) : l'âge de l'électricité se voit sur le réseau" }
B{ name = "fo-crystal-puller", epoch = 10, fr = "Tireuse de cristal", en = "Crystal puller",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 1500, speed = 1, categories = { "fo-crystal-pulling" },
   levels = LV("furnace"), sprite_fr = "copie teintée de la centrifugeuse" }
B{ name = "fo-crystal-lithograph", epoch = 10, fr = "Lithographe à cristal", en = "Crystal lithograph",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 6000, speed = 1, categories = { "fo-lithography" },
   fluid_in = 2, levels = LV("assembler"), sprite_fr = "copie teintée d'assembling-machine-3",
   note_fr = "ultraviolet obtenu par conversion de fréquence dans le cristal taillé (cristal non linéaire)" }
B{ name = "fo-data-center", epoch = 10, fr = "Centre de calcul", en = "Data center",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-computing" },
   fluid_in = 1, fluid_out = 1, fixed_recipe = "fo-computing", levels = LV("process"), sprite_fr = "copie teintée d'assembling-machine-3",
   rule_fr = "recette fixe : 10 eau/s → 50 calcul/s ; ses niveaux (famille des procédés) donnent plus de calcul par bâtiment" }
B{ name = "fo-robotics-bay", epoch = 10, fr = "Atelier de robotique", en = "Robotics bay",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 2500, speed = 1, categories = { "fo-robotics" },
   fluid_in = 1, levels = LV("assembler"), sprite_fr = "copie teintée du roboport",
   rule_fr = "reçoit le calcul par tuyau : il se pose à côté d'un centre de calcul (le calcul n'a pas de baril)" }

for _, b in ipairs(buildings) do
  if b.levels and b.levels.family then b.levels.first = 2 * b.epoch - 1 end
end
X3.buildings = buildings

---------------------------------------------------------------------------------------------------
-- 4. Recettes nouvelles. R(nom, époque, catégorie, durée, ingrédients, produits, options) ; « building » se déduit à la
--    fusion (produit unique = bâtiment). Rendements choisis pour garder les MU d'X0 (tests/x3_test.lua les compare).
---------------------------------------------------------------------------------------------------
local recipes = {}
local function R(name, epoch, category, time, ingredients, results, o)
  o = o or {}
  o.name, o.epoch, o.category, o.time, o.ingredients, o.results = name, epoch, category, time, ingredients, results
  o.kind = o.kind or "recipe"
  recipes[#recipes + 1] = o
  return o
end

-- Âge 3 · blende → zinc → laiton (tube de Bourdon du manomètre)
R("fo-mine-sphalerite", 3, nil, 1, {}, { { "fo-sphalerite", 1 } },
  { kind = "mining", resource = "fo-sphalerite", machines = DRILLS, fr = "Minage : blende", en = "Mining: sphalerite" })
R("fo-zinc-retort", 3, "fo-coking", 6, { { "fo-sphalerite", 4 }, { "coal", 1 } }, { { "fo-zinc-plate", 2 }, { "fo-slag", 1 } },
  { fr = "Cornue à zinc", en = "Zinc retort",
    note_fr = "grillage et réduction au charbon en cornue ; le soufre part en fumée (le soufre n'arrive qu'à l'âge 4)" })
R("fo-brass", 3, "fo-blast-furnace", 3, { { "copper-plate", 2 }, { "fo-zinc-plate", 1 } }, { { "fo-brass", 3 } }, { prod = true })

-- Âge 4 · chaîne A : cassitérite → étain ; éthylène → résine ; stratifié → carte imprimée
R("fo-mine-cassiterite", 4, nil, 1, {}, { { "fo-cassiterite", 1 } },
  { kind = "mining", resource = "fo-cassiterite", machines = DRILLS, fr = "Minage : cassitérite", en = "Mining: cassiterite" })
R("fo-tin-plate", 4, "smelting", 3.2, { { "fo-cassiterite", 2 } }, { { "fo-tin-plate", 1 } }, { prod = true, fr = "Étain", en = "Tin" })
R("fo-epoxy-resin", 4, "chemistry", 3, { { "fo-ethylene", 20 }, { "heavy-oil", 10 } }, { { "fo-epoxy-resin", 20 } })
R("fo-copper-clad-laminate", 4, "chemistry", 4, { { "copper-plate", 2 }, { "fo-glass", 1 }, { "fo-epoxy-resin", 20 } },
  { { "fo-copper-clad-laminate", 2 } }, { prod = true })
R("fo-circuit-printer", 4, "crafting", 5, { { "steel-plate", 10 }, { "electronic-circuit", 10 }, { "iron-gear-wheel", 10 }, { "fo-glass", 4 } },
  { { "fo-circuit-printer", 1 } })
R("fo-printed-circuit-board", 4, "fo-circuit-printing", 3, { { "fo-copper-clad-laminate", 1 }, { "fo-tin-plate", 1 }, { "sulfuric-acid", 5 } },
  { { "fo-printed-circuit-board", 2 } }, { prod = true, note_fr = "impression du motif, gravure du cuivre à l'acide, étamage des pastilles" })
R("fo-pcb-advanced-circuit", 4, "crafting", 6, { { "fo-printed-circuit-board", 1 }, { "electronic-circuit", 2 }, { "plastic-bar", 1 } },
  { { "advanced-circuit", 1 } }, { fr = "Circuit avancé sur carte imprimée", en = "Advanced circuit on printed board", variant_of = "advanced-circuit",
    note_fr = "variante à MU égale du circuit avancé vanilla (8,7 MU) : 4 câbles et 1 plastique en moins, une carte en plus" })

-- Âge 6 · chaîne C : bauxite → alumine (+ boue rouge → ciment) → aluminium ; servomoteur
R("fo-mine-bauxite", 6, nil, 1, {}, { { "fo-bauxite", 1 } },
  { kind = "mining", resource = "fo-bauxite", machines = DRILLS, fr = "Minage : bauxite", en = "Mining: bauxite" })
R("fo-reduction-cell", 6, "crafting", 10, { { "steel-plate", 20 }, { "stone-brick", 30 }, { "fo-graphite", 10 }, { "copper-cable", 40 } },
  { { "fo-reduction-cell", 1 } })
R("fo-lime-sinter-alumina", 6, "chemistry", 6, { { "fo-bauxite", 5 }, { "stone", 1 }, { "water", 20 } }, { { "fo-alumina", 2 }, { "fo-red-mud", 2 } },
  { fr = "Frittage de la bauxite à la chaux", en = "Lime sintering of bauxite",
    note_fr = "à la place du procédé Bayer, qui exige la soude caustique de l'âge 11 (aucun anachronisme)" })
R("fo-red-mud-cement", 6, "fo-crushing", 2, { { "fo-red-mud", 2 }, { "stone", 1 } }, { { "fo-cement", 2 } },
  { fr = "Ciment de boue rouge", en = "Red mud cement" })
R("fo-hall-heroult", 6, "fo-fused-salt-electrolysis", 6, { { "fo-alumina", 4 }, { "fo-graphite", 1 } }, { { "fo-aluminium-plate", 2 } },
  { prod = true, fr = "Électrolyse ignée (Hall-Héroult)", en = "Fused-salt electrolysis (Hall-Héroult)",
    note_fr = "anode de graphite consommée ; 2 alumines et 0,5 anode par plaque, proche du réel ; 6 MW × 6 s = 18 MJ par plaque" })
R("fo-servo-motor", 6, "crafting", 5,
  { { "electric-engine-unit", 1 }, { "fo-coil", 1 }, { "iron-gear-wheel", 2 }, { "electronic-circuit", 1 }, { "fo-aluminium-plate", 1 } },
  { { "fo-servo-motor", 1 } }, { prod = true })

-- Âge 7 · chaînes A et C : laser à cristal, capteur, contrôleur, drone laser
R("fo-crystal-laser", 7, "crafting", 10, { { "fo-cut-crystal", 1 }, { "fo-resonance-lens", 2 }, { "fo-coil", 2 }, { "fo-aluminium-plate", 1 } },
  { { "fo-crystal-laser", 1 } })
R("fo-optical-sensor", 7, "crafting", 6, { { "fo-resonance-lens", 1 }, { "fo-crystal-oscillator", 2 }, { "fo-printed-circuit-board", 1 } },
  { { "fo-optical-sensor", 2 } }, { prod = true })
R("fo-controller", 7, "crafting", 8, { { "advanced-circuit", 2 }, { "fo-crystal-oscillator", 2 }, { "fo-printed-circuit-board", 1 } },
  { { "fo-controller", 1 } }, { prod = true })
R("fo-laser-drone-capsule", 7, "crafting", 15, { { "distractor-capsule", 1 }, { "fo-crystal-laser", 1 }, { "battery", 2 } },
  { { "fo-laser-drone-capsule", 1 } })

-- Âge 10 · chaîne A : quartz → creuset ; silicium pur → lingot → tranches ; lithographie → tranche gravée → puces
R("fo-mine-vein-quartz", 10, nil, 2, {}, { { "fo-vein-quartz", 1 } },
  { kind = "mining", resource = "fo-vein-quartz", machines = HARD_DRILLS, fr = "Minage : quartz filonien", en = "Mining: vein quartz" })
R("fo-quartz-crucible", 10, "fo-arc-smelting", 4, { { "fo-vein-quartz", 6 } }, { { "fo-quartz-crucible", 1 } },
  { fr = "Creuset de quartz fondu", en = "Fused quartz crucible" })
R("fo-crystal-puller", 10, "advanced-crafting", 10,
  { { "steel-plate", 10 }, { "fo-graphite", 10 }, { "fo-coil", 5 }, { "advanced-circuit", 5 }, { "fo-glass", 10 } }, { { "fo-crystal-puller", 1 } })
R("fo-silicon-ingot", 10, "fo-crystal-pulling", 40, { { "fo-pure-silicon", 10 }, { "fo-quartz-crucible", 1 } }, { { "fo-silicon-ingot", 1 } },
  { fr = "Tirage Czochralski", en = "Czochralski pulling" })
R("fo-photoresist", 10, "chemistry", 4, { { "fo-epoxy-resin", 20 }, { "light-oil", 10 }, { "sulfur", 1 } }, { { "fo-photoresist", 20 } })
R("fo-photomask", 10, "fo-cleanroom", 20, { { "fo-glass", 2 }, { "fo-tungsten-plate", 1 }, { "advanced-circuit", 1 } }, { { "fo-photomask", 1 } },
  { note_fr = "sans processeur dans sa recette : aucun cycle processeur → masque → processeur" })
R("fo-crystal-lithograph", 10, "advanced-crafting", 30,
  { { "fo-crystal-laser", 4 }, { "fo-cut-crystal", 10 }, { "fo-resonance-lens", 10 }, { "processing-unit", 20 }, { "steel-plate", 20 } },
  { { "fo-crystal-lithograph", 1 } })
R("fo-etched-wafer", 10, "fo-lithography", 30,
  { { "fo-silicon-wafer", 10 }, { "fo-photomask", 1 }, { "fo-photoresist", 50 }, { "sulfuric-acid", 20 } }, { { "fo-etched-wafer", 10 } },
  { prod = true, fr = "Lithographie et gravure", en = "Lithography and etching" })
R("fo-memory-module", 10, "fo-cleanroom", 10, { { "fo-etched-wafer", 1 }, { "fo-printed-circuit-board", 1 }, { "fo-tin-plate", 1 } },
  { { "fo-memory-module", 2 } }, { prod = true })
R("fo-graphics-card", 10, "fo-cleanroom", 15,
  { { "fo-etched-wafer", 4 }, { "fo-memory-module", 2 }, { "fo-printed-circuit-board", 1 }, { "fo-aluminium-plate", 1 }, { "fo-tin-plate", 1 } },
  { { "fo-graphics-card", 1 } }, { prod = true })

-- Âge 10 · chaîne B : centre de calcul → calcul → noyau de pilotage ; chaîne C : atelier de robotique, drone de garde
R("fo-data-center", 10, "advanced-crafting", 30,
  { { "fo-graphics-card", 10 }, { "fo-controller", 4 }, { "steel-plate", 20 }, { "concrete", 20 }, { "pipe", 10 } }, { { "fo-data-center", 1 } })
R("fo-computing", 10, "fo-computing", 1, { { "water", 10 } }, { { "fo-compute", 50 } },
  { fr = "Calcul", en = "Computing", note_fr = "recette fixe du centre de calcul ; l'eau évaporée est le refroidissement, rien à évacuer" })
R("fo-robotics-bay", 10, "advanced-crafting", 20,
  { { "fo-servo-motor", 10 }, { "fo-controller", 6 }, { "fo-optical-sensor", 10 }, { "steel-plate", 40 }, { "concrete", 40 } }, { { "fo-robotics-bay", 1 } })
R("fo-guidance-core", 10, "fo-robotics", 20,
  { { "fo-controller", 1 }, { "fo-graphics-card", 1 }, { "fo-optical-sensor", 2 }, { "fo-compute", 200 } }, { { "fo-guidance-core", 1 } },
  { note_fr = "200 calculs, soit 40 MJ d'électricité, par noyau" })
R("fo-guard-drone-capsule", 10, "fo-robotics", 10,
  { { "fo-servo-motor", 2 }, { "fo-optical-sensor", 1 }, { "fo-controller", 1 }, { "battery", 2 }, { "fo-compute", 20 } },
  { { "fo-guard-drone-capsule", 1 } })

-- Âge 11 · chaîne B : procédé Siemens (exutoire de l'hydrogène et du chlore de la saumure)
R("fo-siemens-silicon", 11, "chemistry", 8,
  { { "fo-metallurgical-silicon", 3 }, { "fo-chlorine", 40, catalyst = 30 }, { "fo-hydrogen", 30 } },
  { { "fo-pure-silicon", 2 }, { "fo-chlorine", 30, catalyst = 30 } },
  { process = "catalytic", variant_of = "fo-pure-silicon", fr = "Silicium pur (procédé Siemens)", en = "Pure silicon (Siemens process)",
    note_fr = "trichlorosilane : le chlore tourne en boucle (catalyseur déclaré), 10 sont perdus ; l'hydrogène, sans exutoire en jeu depuis X1, en trouve un" })

-- Âge 12 · chaîne C : actionneur à aimants, barreau Nd:YAG, module laser, robot de combat
R("fo-magnetic-actuator", 12, "crafting", 8, { { "fo-servo-motor", 1 }, { "fo-permanent-magnet", 4 }, { "fo-titanium-composite", 1 } },
  { { "fo-magnetic-actuator", 1 } }, { prod = true })
R("fo-ndyag-rod", 12, "fo-crystal-pulling", 30, { { "fo-neodymium", 1 }, { "fo-yttrium", 1 }, { "fo-alumina", 2 } }, { { "fo-ndyag-rod", 2 } },
  { fr = "Tirage du grenat Nd:YAG", en = "Nd:YAG garnet pulling",
    note_fr = "tiré par Czochralski comme le silicium (creuset d'iridium en réalité : l'iridium n'arrive qu'à l'âge 14, il n'est pas consommé ici)" })
R("fo-laser-module", 12, "crafting", 10, { { "fo-ndyag-rod", 1 }, { "fo-resonance-lens", 1 }, { "fo-coil", 2 }, { "fo-controller", 1 } },
  { { "fo-laser-module", 1 } }, { prod = true })
R("fo-combat-robot", 12, "fo-robotics", 30,
  { { "fo-magnetic-actuator", 4 }, { "fo-guidance-core", 1 }, { "fo-laser-module", 2 }, { "fo-titanium-composite", 10 }, { "battery", 10 } },
  { { "fo-combat-robot", 1 } })

X3.recipes = recipes

---------------------------------------------------------------------------------------------------
-- 5. Retouches de recettes X0 (APPROFONDIR, rien n'est remplacé ; la recette garde son nom, son époque et sa
--    technologie). ingredients / results / category / time : valeurs complètes après retouche. Aucune ne touche les
--    recettes que shared/content/titanium.lua déplie (four à coke, four à arc, électrolyseur, concentrateur, réacteur de
--    Kroll et leurs ingrédients absents du jeu) : tests/x3_test.lua le contrôle.
---------------------------------------------------------------------------------------------------
X3.retouches = {
  { recipe = "fo-manometer", ingredients = { { "fo-glass", 1 }, { "iron-gear-wheel", 1 }, { "pipe", 1 }, { "fo-brass", 1 } },
    why_fr = "tube de Bourdon en laiton : le laiton passe dans 6 bâtiments des âges 3 à 5 et dans le Codex III" },
  { recipe = "fo-codex-4", ingredients = { { "plastic-bar", 20 }, { "advanced-circuit", 10 }, { "chemical-science-pack", 10 }, { "fo-asphalt", 20 },
      { "fo-printed-circuit-board", 10 } },
    why_fr = "l'imprimerie devient un passage obligé, à petit volume (10 cartes)" },
  { recipe = "fo-ht-pylon", ingredients = { { "steel-plate", 10 }, { "fo-aluminium-plate", 4 }, { "fo-coil", 2 } },
    why_fr = "conducteur aluminium-acier à la place des 4 câbles de cuivre" },
  { recipe = "fo-silicon-wafer", category = "fo-lapidary", time = 20,
    ingredients = { { "fo-silicon-ingot", 1 }, { "fo-crystal-powder", 2 }, { "water", 40 } }, results = { { "fo-silicon-wafer", 20 } },
    why_fr = "sciage du lingot à la scie à fil (taillerie), la poudre de cristal sert d'abrasif ; avant : 1 silicium pur → 4 tranches en salle blanche" },
  { recipe = "fo-cleanroom-processor", time = 12,
    ingredients = { { "fo-etched-wafer", 4 }, { "fo-printed-circuit-board", 2 }, { "plastic-bar", 4 } }, results = { { "processing-unit", 2 } },
    why_fr = "mise en boîtier de puces gravées : plus de « 10 circuits verts + 2 avancés » dans un processeur ; variante, la recette vanilla reste (QX4)" },
  { recipe = "fo-phased-array-radar", ingredients = { { "radar", 1 }, { "processing-unit", 6 }, { "fo-graphics-card", 2 }, { "fo-crystal-oscillator", 20 },
      { "fo-magnetic-steel", 10 } },
    why_fr = "traitement du signal : 2 cartes graphiques pour 4 processeurs" },
  { recipe = "fo-cryogenic-unit", ingredients = { { "steel-plate", 40 }, { "fo-titanium-plate", 3 }, { "fo-magnetic-actuator", 3 }, { "processing-unit", 10 },
      { "pipe", 20 } },
    why_fr = "compresseurs entraînés par actionneurs à aimants (3) à la place de 10 moteurs électriques" },
  { recipe = "fo-deep-drill", ingredients = { { "fo-heavy-drill", 1 }, { "fo-tungsten-carbide", 20 }, { "fo-superconducting-coil", 10 },
      { "fo-magnetic-actuator", 3 }, { "fo-guidance-core", 1 } },
    why_fr = "une machine montée : 3 actionneurs et 1 noyau de pilotage à la place de 10 processeurs" },
  { recipe = "fo-plasma-foundry", ingredients = { { "fo-tungsten-plate", 50 }, { "fo-superconducting-coil", 20 }, { "concrete", 20 },
      { "fo-magnetic-actuator", 3 }, { "fo-guidance-core", 1 } },
    why_fr = "pilotage du plasma : 3 actionneurs et 1 noyau à la place de 10 processeurs (la fusion exige le calcul)" },
  { recipe = "fo-core-drill", ingredients = { { "fo-concentrate-drill", 1 }, { "fo-superconducting-coil", 20 }, { "fo-tungsten-carbide", 20 },
      { "fo-magnetic-actuator", 6 }, { "fo-guidance-core", 2 }, { "fo-laser-module", 2 } },
    why_fr = "forage assisté par laser : 6 actionneurs, 2 noyaux et 2 modules laser à la place de 20 processeurs et 20 carbures" },
  { recipe = "fo-orbital-launcher", ingredients = { { "concrete", 200 }, { "fo-titanium-composite", 50 }, { "fo-superconducting-coil", 50 },
      { "processing-unit", 10 }, { "fo-guidance-core", 10 }, { "steel-plate", 100 } },
    why_fr = "guidage du lanceur : 10 noyaux de pilotage à la place de 40 des 50 processeurs" },
  { recipe = "fo-orbital-tug", ingredients = { { "fo-titanium-composite", 10 }, { "fo-superconducting-coil", 4 }, { "fo-guidance-core", 1 },
      { "fo-cryogenic-propellant", 10 } },
    why_fr = "remorqueur autonome : 1 noyau de pilotage à la place de 4 processeurs" },
  { recipe = "fo-erebus-gate", ingredients = { { "concrete", 500 }, { "fo-superalloy", 50 }, { "fo-superconducting-coil", 100 }, { "fo-iridium-mirror", 50 },
      { "fo-stabilized-exotic-matter", 20 }, { "processing-unit", 60 }, { "fo-graphics-card", 10 } },
    why_fr = "calcul de la Porte : 10 cartes graphiques à la place de 40 des 100 processeurs" },
}

---------------------------------------------------------------------------------------------------
-- 6. Technologies : 4 nouvelles (une par âge au plus), le reste en EXTENSIONS de technologies X0 (déblocages et
--    prérequis ajoutés, nom changé si le contenu l'exige). Packs et unités : calculés à la fusion comme dans X0
--    (X.pack_window, X.TECH_UNITS × poids du rôle), avec le recalage X3.tech_units.
---------------------------------------------------------------------------------------------------
local technologies = {}
local function T(name, epoch, fr, en, unlocks, o)
  o = o or {}
  o.name, o.epoch, o.fr, o.en, o.unlocks = name, epoch, fr, en, unlocks
  o.prereq = o.prereq or {}
  o.role = o.role or (o.branch and ("branch" .. o.level)) or "normal"
  technologies[#technologies + 1] = o
  return o
end
T("fo-printed-circuits", 4, "Circuits imprimés", "Printed circuits",
  { "fo-tin-plate", "fo-epoxy-resin", "fo-copper-clad-laminate", "fo-circuit-printer", "fo-printed-circuit-board", "fo-pcb-advanced-circuit" },
  { prereq = { "fo-steam-cracking" } })
T("fo-aluminium", 6, "Aluminium et servomoteurs", "Aluminium and servo motors",
  { "fo-reduction-cell", "fo-lime-sinter-alumina", "fo-red-mud-cement", "fo-hall-heroult", "fo-servo-motor" },
  { prereq = { "fo-arc-smelting", "fo-electrical-steel" } })
T("fo-computing", 10, "Calcul et robotique", "Computing and robotics",
  { "fo-graphics-card", "fo-data-center", "fo-computing", "fo-robotics-bay", "fo-guidance-core", "fo-guard-drone-capsule" },
  { prereq = { "fo-silicon" } })
T("fo-combat-robots", 12, "Robots de combat", "Combat robots", { "fo-ndyag-rod", "fo-laser-module", "fo-combat-robot" },
  { prereq = { "fo-magnetic-pack", "fo-computing" } })
X3.technologies = technologies

X3.extends = {
  { tech = "fo-glassworks", unlocks = { "fo-zinc-retort", "fo-brass" }, fr = "Verrerie et laiton", en = "Glassworks and brass",
    why_fr = "le manomètre, débloqué ici, prend un tube en laiton" },
  { tech = "fo-drilling-records", prereq = { "fo-printed-circuits", "fo-asphalt" },
    why_fr = "le Codex IV demande 10 cartes imprimées ; « fo-asphalt » répare au passage un défaut d'X0 trouvé par x3_test (l'asphalte du Codex IV n'était pas dans ses prérequis)" },
  { tech = "fo-high-voltage", prereq = { "fo-aluminium" }, why_fr = "le pylône prend un conducteur en aluminium" },
  { tech = "fo-resonance-pack", unlocks = { "fo-optical-sensor", "fo-controller" }, why_fr = "lentilles et oscillateurs : la vue et le cerveau des machines" },
  { tech = "fo-resonance-amplifier", unlocks = { "fo-crystal-laser", "fo-laser-drone-capsule" },
    fr = "Amplificateur de résonance et laser à cristal", en = "Resonance amplifier and crystal laser",
    why_fr = "amplifier la lumière dans le cristal : le premier laser" },
  { tech = "fo-silicon", unlocks = { "fo-quartz-crucible", "fo-crystal-puller", "fo-silicon-ingot", "fo-photoresist", "fo-photomask",
      "fo-crystal-lithograph", "fo-etched-wafer", "fo-memory-module" },
    fr = "Silicium et fonderie de puces", en = "Silicon and chip foundry", why_fr = "la fonderie de puces complète la salle blanche" },
  { tech = "fo-phased-array-radar", prereq = { "fo-computing" }, why_fr = "le radar prend 2 cartes graphiques" },
  { tech = "fo-wet-tungsten", unlocks = { "fo-siemens-silicon" }, fr = "Voie humide : tungstène et silicium", en = "Wet processes: tungsten and silicon",
    why_fr = "deux exutoires des produits de la saumure (soude, hydrogène, chlore) ; en jeu, T.TECHS du titane n'est PAS changé" },
  { tech = "fo-magnetic-pack", unlocks = { "fo-magnetic-actuator" }, why_fr = "l'unité cryogénique, débloquée ici, prend des actionneurs" },
  -- Deux défauts d'X0 trouvés par x3_test (un objet du même âge requis hors des prérequis), réparés dans la fusion :
  { tech = "fo-superalloy", prereq = { "fo-meteoritics" },
    why_fr = "défaut d'X0 : le superalliage météoritique prend du ferronickel, débloqué par la météoritique" },
  { tech = "fo-orbital-archives", prereq = { "fo-iridium-optics" },
    why_fr = "défaut d'X0 : le Codex XIV prend des miroirs d'iridium, débloqués par l'optique à l'iridium" },
}

--- Recalage des unités de recherche (règle d'epochs_test : la recherche de chaque époque reste entre 30 et 40 % de son
--- budget ; visée 35 %, comme X0, valeur « unités pour 35 % » que le banc imprime sur la fusion, arrondie à la dizaine).
--- Valeur = unités d'une technologie ordinaire de l'époque, à la place de X.TECH_UNITS[k], dans la FUSION seulement.
--- Sans recalage : 40,1 % à l'âge 4 (hors règle), 39,3 % à l'âge 6, 37,3 % à l'âge 10, 36,0 % à l'âge 12 (technologie
--- nouvelle) ; 33,6 %, 30,9 %, 31,6 % et 31,0 % aux âges 11, 13, 14 et 15 (packs moins chers : le processeur gravé).
X3.tech_units = { [4] = 77, [6] = 146, [10] = 1040, [11] = 3910, [12] = 5790, [13] = 11630, [14] = 13820, [15] = 207800 }

---------------------------------------------------------------------------------------------------
-- 7. Les trois chaînes marquantes (lecture, profondeur et dépliage contrôlés par tests/x3_test.lua).
---------------------------------------------------------------------------------------------------
X3.chains = {
  { key = "A", fr = "Imprimer les puces", epochs = { 4, 7, 10 }, target = "fo-graphics-card",
    path = { "fo-cassiterite", "fo-tin-plate", "fo-printed-circuit-board", "fo-crystal-laser", "fo-vein-quartz", "fo-quartz-crucible",
      "fo-silicon-ingot", "fo-silicon-wafer", "fo-etched-wafer", "fo-memory-module", "fo-graphics-card" },
    schema_fr = {
      "âge 4  : cassitérite → étain ; éthylène + huile lourde → résine époxy ; cuivre + verre + résine → stratifié → [imprimante] carte imprimée",
      "âge 7  : cristal taillé + 2 lentilles + 2 bobines + aluminium → laser à cristal",
      "âge 10 : quartz → creuset ; 10 silicium pur + creuset → [tireuse] lingot → [taillerie, scie à fil] 20 tranches",
      "         résine + huile légère → résine photosensible ; verre + tungstène + circuit avancé → photomasque",
      "         [lithographe à cristal : 4 lasers] 10 tranches + masque + résine + acide → 10 tranches gravées",
      "         → processeur (4 gravées + 2 cartes + 4 plastiques → 2), mémoire, carte graphique",
    } },
  { key = "B", fr = "Calculer", epochs = { 10, 11, 13 }, target = "fo-guidance-core",
    path = { "fo-graphics-card", "fo-data-center", "fo-compute", "fo-guidance-core" },
    schema_fr = {
      "âge 10 : 10 cartes graphiques + 4 contrôleurs → [centre de calcul, 10 MW] eau → calcul (fluide, 50/s)",
      "         contrôleur + carte graphique + 2 capteurs + 200 calcul → [atelier de robotique] noyau de pilotage",
      "âge 11 : silicium métallurgique + chlore (boucle) + hydrogène → silicium pur (Siemens)",
      "âges 13 à 15 : noyaux dans les foreuses profonde et de noyau, la fonderie à plasma, le lanceur et le remorqueur ; cartes dans la Porte",
    } },
  { key = "C", fr = "Monter des machines, se défendre", epochs = { 6, 7, 10, 12 }, target = "fo-combat-robot",
    path = { "fo-bauxite", "fo-alumina", "fo-aluminium-plate", "fo-servo-motor", "fo-optical-sensor", "fo-controller", "fo-guard-drone-capsule",
      "fo-magnetic-actuator", "fo-ndyag-rod", "fo-laser-module", "fo-combat-robot" },
    schema_fr = {
      "âge 6  : bauxite + pierre → alumine + boue rouge (→ ciment) ; [cuve ignée, 6 MW] alumine + graphite → aluminium",
      "         moteur électrique + bobine + engrenages + circuit + aluminium → servomoteur",
      "âge 7  : lentille + oscillateurs + carte → capteur ; circuits avancés + oscillateurs + carte → contrôleur ; distracteur + laser → drone laser",
      "âge 10 : 2 servomoteurs + capteur + contrôleur + batteries + 20 calcul → drone de garde",
      "âge 12 : servomoteur + 4 aimants + composite → actionneur ; néodyme + yttrium + alumine → [tireuse] barreau Nd:YAG → module laser",
      "         4 actionneurs + noyau + 2 modules laser + composite + batteries → [atelier de robotique] robot de combat",
    } },
}

--- Ce qui n'est PAS fait (doc §3.7) : écarté par les concepteurs ou par la synthèse, et pourquoi.
X3.not_done = {
  "rien en jeu : aucun prototype, aucune locale, aucune garantie de placement, aucun kit minerai ; le jeu ne change pas",
  "lithographie EUV, imprimante 3D métal, carte multicouche, plaque froide (proposition « puces ») : un 4e endroit lourd, aux âges 13 et 7 ; reportés",
  "aluminium par le procédé Bayer et spath fluor (fluorure d'hydrogène) : la soude n'arrive qu'à l'âge 11 ; frittage à la chaux, sans fluor",
  "latérite (nickel, cobalt), spodumène (lithium), gallium, germanium, argent de la galène, barytine : 6 ressources ou sous-produits de plus pour des usages uniques",
  "lance-drones (tourelle dont la munition est un drone) et obus guidé : comportement moteur non prouvé (H-X3-1, H-X3-3), reportés au lot qui intégrera",
  "laboratoire accéléré par le calcul : un laboratoire 1.1.91 ne prend aucun fluide ; pack d'utilité simulé écarté (il baisserait un pack)",
  "niveaux payés en pièces (servomoteur, contrôleur, noyau) : touche shared/levels/config.lua (fichier de l'intégrateur) ; à décider (Q-X3-3)",
  "processeur vanilla caché pour rendre la fonderie obligatoire : entorse à QX4 (Q-X3-1)",
  "cadre de robot piloté : plus cher que le cadre vanilla avec un noyau, sans intérêt ; retiré",
}

--- Hypothèses à prouver en moteur réel quand une chaîne entrera en jeu.
X3.hypotheses = {
  { key = "H-X3-1", fr = "un combat-robot lancé par une capsule à recette d'usine (drone laser, drone de garde) naît dans la force du lanceur et combat sans script" },
  { key = "H-X3-2", fr = "une unité (prototype unit) née d'une capsule tient sa place sans commande ; filet : la commande de garnison du code de guerre, une fois à la naissance" },
  { key = "H-X3-3", fr = "le calcul (fluide sans baril) se transporte par tuyau sans se mêler à l'eau : le joueur sépare ses réseaux (un tuyau 1.1 n'a pas de catégorie de raccord)" },
}

--- Questions au Directeur Créatif (à poser en QCM, exemple chiffré).
X3.questions = {
  { key = "Q-X3-1", fr = "La fonderie de puces doit-elle devenir OBLIGATOIRE à l'âge 10 (processeur vanilla caché, entorse à QX4) ? Proposé : non, la voie gravée est une variante (16,6 MU le processeur, contre 22,5 par la salle blanche d'X0 et 68 en vanilla)." },
  { key = "Q-X3-2", fr = "Les robots de combat : unités qui gardent leur place (proposé), ou qui suivent le joueur (mécanique vanilla des drones) ?" },
  { key = "Q-X3-3", fr = "Payer une part des niveaux en pièces montées (servomoteur, contrôleur, noyau de pilotage, module laser) pour que ces chaînes tournent sans cesse ?" },
}

---------------------------------------------------------------------------------------------------
-- 8. Fusion (pure) : X3.merge(X) modifie EN PLACE une copie fraîche de X (dofile("shared/content/epochs.lua")) et la
--    rend. Jamais le module de require, que le jeu et les autres bancs lisent.
---------------------------------------------------------------------------------------------------
--- Poids des rôles de technologie : copie de TECH_WEIGHT (locale dans epochs.lua ; x3_test contrôle qu'elle redonne
--- les unités de X0 à l'identique).
X3.TECH_WEIGHT = { pack = 1, normal = 1, codex = 0.5, branch1 = 1.5, branch2 = 2, branch3 = 3, gate = 0.25 }

local function deep(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = deep(x) end
  return out
end
X3.deep_copy = deep

--- Unités et packs d'une technologie, comme la fin de la section 11 ter d'epochs.lua.
function X3.tech_cost(X, t)
  t.units = math.floor(X.TECH_UNITS[t.epoch] * X3.TECH_WEIGHT[t.role] + 0.5)
  if t.role == "pack" then
    t.packs = X.pack_window(t.epoch - 1)
  elseif t.branch and t.level >= 2 then
    local br
    for _, b in ipairs(X.branches) do if b.key == t.branch then br = b end end
    t.packs = X.pack_window(t.epoch, { branch_data = br.data })
  else
    t.packs = X.pack_window(t.epoch)
  end
end

function X3.merge(X, data)
  data = data or X3
  local loaded = package and package.loaded and package.loaded["shared.content.epochs"]
  assert(X ~= loaded, "X3.merge : passer une copie fraîche (dofile), jamais le module de require lu par le jeu")
  local function find(list, name)
    for _, e in ipairs(list) do if e.name == name then return e end end
    return nil
  end
  local added = { items = {}, buildings = {}, recipes = {}, technologies = {}, resources = {} }
  for _, coll in ipairs({ "resources", "items", "buildings", "recipes", "technologies" }) do
    for _, e in ipairs(data[coll] or {}) do
      local c = deep(e)
      X[coll][#X[coll] + 1] = c
      added[coll][#added[coll] + 1] = c.name
    end
  end
  -- « building » déduit (produit unique = bâtiment), comme epochs.lua ; niveau de naissance des bâtiments.
  local is_building = {}
  for _, b in ipairs(X.buildings) do is_building[b.name] = true end
  for _, n in ipairs(added.recipes) do
    local r = find(X.recipes, n)
    if r.kind == "recipe" and #r.results == 1 and is_building[r.results[1][1]] then r.kind = "building" end
  end
  for _, n in ipairs(added.buildings) do
    local b = find(X.buildings, n)
    if b.levels and b.levels.family then b.levels.first = 2 * b.epoch - 1 end
  end
  -- Retouches : la recette X0 garde nom, époque, technologie ; on garde l'état d'avant pour la doc et le banc.
  local retouched = {}
  for _, rt in ipairs(data.retouches or {}) do
    local r = assert(find(X.recipes, rt.recipe), "X3.merge : retouche d'une recette absente " .. tostring(rt.recipe))
    r.x3_before = { ingredients = deep(r.ingredients), results = deep(r.results), category = r.category, time = r.time }
    for _, f in ipairs({ "ingredients", "results", "category", "time" }) do
      if rt[f] ~= nil then r[f] = deep(rt[f]) end
    end
    r.x3_why_fr = rt.why_fr
    retouched[#retouched + 1] = r.name
  end
  -- Extensions de technologies X0.
  local extended = {}
  for _, ex in ipairs(data.extends or {}) do
    local t = assert(find(X.technologies, ex.tech), "X3.merge : extension d'une technologie absente " .. tostring(ex.tech))
    for _, u in ipairs(ex.unlocks or {}) do t.unlocks[#t.unlocks + 1] = u end
    for _, p in ipairs(ex.prereq or {}) do t.prereq[#t.prereq + 1] = p end
    if ex.fr then t.x3_fr_before, t.fr = t.fr, ex.fr end
    if ex.en then t.en = ex.en end
    extended[#extended + 1] = t.name
  end
  -- Recalage des unités, puis unités et packs de TOUTES les technologies (identiques à X0 aux époques non recalées).
  local tu = {}
  for k = 1, X.EPOCHS do tu[k] = (data.tech_units or {})[k] or X.TECH_UNITS[k] end
  X.TECH_UNITS = tu
  for _, t in ipairs(X.technologies) do X3.tech_cost(X, t) end
  X.x3 = { added = added, retouched = retouched, extended = extended, version = X3.VERSION }
  return X
end

return X3
