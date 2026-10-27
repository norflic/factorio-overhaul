--[[
  Lot X3 (27/10) : graphe de fabrication plus réaliste et minerais par âge. PROPOSITION, PAS EN JEU.
  Pur Lua, AUCUNE API Factorio. AUCUN fichier du jeu ne lit ce module (ni data.lua, ni control.lua, ni prototypes/, ni
  script/) : il ne vit que hors jeu, par tests/x3_test.lua. Scénario lisible : docs/SCENARIO_EPOQUES.md §3.7.

  Ce module ENRICHIT le scénario approuvé des 15 âges (lot X0, shared/content/epochs.lua) sans le modifier :
  X3.merge(X) prend une copie FRAÎCHE de X (dofile, jamais le module de require) et lui ajoute, EN FIN DE LISTE :
  ressources, objets, bâtiments, recettes et technologies d'X3, puis les extensions de technologies X0 (déblocages et
  prérequis ajoutés) et le recalage des unités de recherche (X3.tech_units). En fin de liste : la règle T.maker de
  shared/content/titanium.lua (première recette X qui produit un objet) ne change pas.

  Version 2 (correction du 27/10, après deux critiques adverses) : RÈGLE « DES VOIES, JAMAIS UNE PORTE ».
  AUCUNE recette d'X0 n'est modifiée (X3.retouches est vide) : chaque voie réaliste qui touche un objet d'X0 est une
  VARIANTE (variant_of, nom propre, placée après la recette d'X0). Une ressource nouvelle n'est donc jamais obligatoire :
  ni pour un Codex, ni pour un pack, ni pour la ligne principale du palier T5 ; une faction (ou le joueur) qui ne l'a pas
  trouvée garde la voie d'X0 (tests/x3_test.lua le prouve en dépliant le cerveau général avec les ressources d'X3
  inconnues). Version 1 : 13 recettes d'X0 retouchées, dont la tranche de silicium (quartz obligatoire au Codex X), le
  manomètre (blende au Codex III), le Codex IV (cassitérite) et 6 bâtiments des âges 12 à 15 (bauxite et les trois
  chaînes pour la Compaction T5).

  Trois chaînes marquantes, et ailleurs presque rien :
    A. « Imprimer les puces » (âges 4, 7, 10) : étain → carte imprimée ; laser à cristal ; quartz → creuset → lingot →
       tranches sciées ; lithographie → tranche gravée → processeur gravé, mémoire, carte graphique ;
    B. « Calculer » (âge 10, puis 11 et 13) : cartes graphiques → centre de calcul → calcul (fluide) → noyau de pilotage ;
       procédé Siemens à l'âge 11 ; noyaux dans les machines pilotées de l'âge 13 ;
    C. « Monter des machines, se défendre » (âges 6, 7, 10, 12) : bauxite → alumine → aluminium ; servomoteur, capteur,
       contrôleur → drone laser ; noyau → drone de garde ; actionneur à aimants, barreau Nd:YAG, module laser → robot de
       combat.
  Quatre ressources nouvelles (au plus une par âge) : blende (3), cassitérite (4), bauxite (6), quartz filonien (10).

  Conventions : celles d'epochs.lua (préfixe fo-, tableaux parcourus par ipairs, durées en s à la vitesse 1, kW, MJ,
  rho en MU par objet). Formats : R(nom, époque, catégorie, durée, ingrédients, produits, options), I, F, B{}, T.
  Statut : PROPOSITION à valider par le Directeur Créatif (questions Q-X3-1 à Q-X3-3 ci-dessous).
]]

local X3 = {}

X3.VERSION = 2
X3.LOT = "X3"
X3.STATUS_FR = "proposition hors jeu (27/10, version 2) : aucun prototype, aucune locale, aucun fichier du jeu ne lit ce module"
X3.RULE_FR = "des voies, jamais une porte : aucune recette d'X0 modifiée, toute voie réaliste qui touche un objet d'X0 est une variante"

-- Mêmes listes que shared/content/epochs.lua (locales là-bas ; tests/x3_test.lua contrôle qu'elles n'ont pas dérivé).
local DRILLS = { "character", "burner-mining-drill", "fo-steam-drill", "electric-mining-drill", "fo-heavy-drill", "fo-concentrate-drill", "fo-core-drill" }
local HARD_DRILLS = { "electric-mining-drill", "fo-heavy-drill", "fo-concentrate-drill", "fo-core-drill" }
X3.DRILLS, X3.HARD_DRILLS = DRILLS, HARD_DRILLS

---------------------------------------------------------------------------------------------------
-- 1. Ressources de la carte (au plus 2 nouvelles par âge, X0 compris ; ici une seule, aux âges 3, 4, 6 et 10).
--    Aucune n'est en jeu : il faudra pour chacune une entrée de shared/content/world.lua, une garantie M0 et un kit
--    minerai M1 (8 stades), mesurés au plancher de mémoire vidéo (F186) avant intégration.
--
--    Placement (correction du défaut « autoplace vanilla-like ») : un appel à resource_autoplace_settings incrémente le
--    compteur PARTAGÉ regular-resource-patch-set-count (data/core/lualib/resource-autoplace.lua, l. 6 à 12), qui sert de
--    skip_span et de skip_offset à TOUS les minerais (l. 263, 264) : trois jeux de gisements de plus déplaceraient fer,
--    cuivre, charbon, pierre, uranium et pétrole sur toutes les graines (sauvegardes en cours comprises, pour leurs
--    chunks neufs). Chaque ressource d'X3 prend donc un JEU DE GISEMENTS PROPRE (`patch_set`), sur le modèle de
--    biome_bound_autoplace (prototypes/world.lua) : compteur restauré après l'appel, skip_span 1, skip_offset 0, graine
--    seed1 NUMÉRIQUE (F198 : jamais de noise-layer nommée), favorabilité des centres = un masque de région à graine
--    numérique propre (`region`, mêmes champs que les régions de biome de shared/content/world.lua). Hypothèse H-X3-4.
---------------------------------------------------------------------------------------------------
X3.resources = {
  { name = "fo-sphalerite", epoch = 3, kind = "ore", category = "basic-solid", products = { "fo-sphalerite" },
    min_distance = 150, fr = "Blende", en = "Sphalerite",
    where_fr = "districts miniers tirés d'un bruit propre (aucun terrain de la 1.1 n'est « collines rocheuses ») : taches de 200 tuiles environ, à plus de 150 tuiles du départ",
    look_fr = "tétraèdres résineux couleur miel à rouge rubis",
    placement = { autoplace = "jeu de gisements propre",
      patch_set = { seed1 = 7301, base_density = 4, base_spots_per_km2 = 1.2, random_spot_size_minimum = 1, random_spot_size_maximum = 2,
        region = { seed1 = 7311, threshold = 0.5, scale = 1 / 220 } },
      guaranteed = { count = 2, distance = { 150, 400 },
        what_fr = "2 gisements de 200 000 posés par script si l'autoplace n'en a mis aucun à cette distance (ressource facultative : voie du laiton)" } } },
  { name = "fo-cassiterite", epoch = 4, kind = "ore", category = "basic-solid", products = { "fo-cassiterite" },
    min_distance = 120, fr = "Cassitérite", en = "Cassiterite",
    where_fr = "placers au bord de l'eau : région à graine propre restreinte aux basses terres (élévation de 0 à 6), à plus de 120 tuiles du départ",
    look_fr = "galets brun chocolat à éclat adamantin, éclats blancs de quartz (pour ne pas la confondre avec le charbon)",
    placement = { autoplace = "jeu de gisements propre",
      patch_set = { seed1 = 7302, base_density = 4, base_spots_per_km2 = 1.4, random_spot_size_minimum = 1, random_spot_size_maximum = 2,
        region = { seed1 = 7312, threshold = 0.45, scale = 1 / 180, elevation_max = 6,
          elevation_max_fr = "champ NOUVEAU de region_mask (prototypes/world.lua n'a que moisture_max, moisture_min et aux_min) : à ajouter à l'intégration" } },
      guaranteed = { count = 2, distance = { 120, 350 },
        what_fr = "2 gisements de 150 000 posés par script si l'autoplace n'en a mis aucun à cette distance (ressource facultative : voie des cartes imprimées)" } } },
  { name = "fo-bauxite", epoch = 6, kind = "ore", category = "basic-solid", products = { "fo-bauxite" },
    min_distance = 300, fr = "Bauxite", en = "Bauxite",
    where_fr = "climat du désert rouge vanilla (aux ≥ 0,6, humidité ≤ 0,3 : red-desert-1 à 3, data/base/prototypes/tile/tiles.lua), à plus de 300 tuiles du départ",
    look_fr = "pisolithes mates brique-ocre dans une terre rouille",
    placement = { autoplace = "jeu de gisements propre",
      patch_set = { seed1 = 7303, base_density = 5, base_spots_per_km2 = 1.2, random_spot_size_minimum = 1, random_spot_size_maximum = 3,
        region = { seed1 = 7313, threshold = 0.4, scale = 1 / 240, moisture_max = 0.3, aux_min = 0.6 } },
      guaranteed = { count = 3, distance = { 300, 600 },
        what_fr = "3 gisements de 300 000 posés par script si l'autoplace n'en a mis aucun à cette distance (ressource facultative : l'aluminium ne sert qu'aux voies d'X3)" } } },
  { name = "fo-vein-quartz", epoch = 10, kind = "ore", category = "basic-solid", products = { "fo-vein-quartz" },
    fr = "Quartz filonien", en = "Vein quartz", mining_time = 3,
    where_fr = "veines blanches de la plaine de cristal (biome en jeu depuis le lot B0), posées par la SEULE garantie (aucune autoplace)",
    look_fr = "prismes hexagonaux blanc laiteux en gerbes, sans lueur (pour ne pas le confondre avec le cristal de résonance violet)",
    mining_fr = "minable à la main (lent : 3 s) et par toute foreuse : 6 quartz font un creuset, 1 creuset fait 40 tranches",
    placement = { autoplace = "aucune (garantie seule)",
      autoplace_none_fr = "deux jeux de gisements sur le masque de la plaine se disputeraient les tuiles : le cristal de résonance (monnaie de l'âge 7, en jeu depuis M0) baisserait sur toutes les graines",
      guaranteed = { count = 2, distance = { 400, 800 },
        what_fr = "2 veines de 200 000 posées par script en bordure de la première plaine de cristal trouvée à cette distance ; si la graine n'en a pas, sur un disque de plaine de cristal créé à cette distance (comme le disque de cendres du tungstène, M0). Facultatif : les tranches d'X0 restent" } } },
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

-- Âge 3 · Vapeur : le laiton du manomètre (variante)
I("fo-sphalerite", 3, "Blende", "Sphalerite", { source = "mining" })
I("fo-zinc-plate", 3, "Plaque de zinc", "Zinc plate", { material = true, rho = 1 })
I("fo-brass", 3, "Laiton", "Brass", { note_fr = "tube de Bourdon du manomètre en laiton (variante)" })
-- Âge 4 · Pétrole : l'imprimerie des cartes (chaîne A)
I("fo-cassiterite", 4, "Cassitérite", "Cassiterite", { source = "mining" })
I("fo-tin-plate", 4, "Plaque d'étain", "Tin plate", { material = true, rho = 1, note_fr = "étamage et soudure des cartes" })
F("fo-epoxy-resin", 4, "Résine époxy", "Epoxy resin", { note_fr = "liant des stratifiés ; base de la résine photosensible (âge 10)" })
I("fo-copper-clad-laminate", 4, "Stratifié cuivré", "Copper-clad laminate")
I("fo-printed-circuit-board", 4, "Carte de circuit imprimé", "Printed circuit board")
-- Âge 6 · Électricité : l'aluminium (chaîne C)
I("fo-bauxite", 6, "Bauxite", "Bauxite", { source = "mining" })
I("fo-alumina", 6, "Alumine", "Alumina")
I("fo-red-mud", 6, "Boue rouge", "Red mud", { note_fr = "sous-produit du frittage ; deux exutoires : ciment de boue rouge et fer de la boue rouge (four à arc)" })
I("fo-aluminium-plate", 6, "Plaque d'aluminium", "Aluminium plate", { material = true, rho = 1 })
-- Âge 7 · Cristal : servomoteur, premier laser, capteur, contrôleur, premier robot de défense (chaînes A et C)
I("fo-servo-motor", 7, "Servomoteur", "Servo motor", { note_fr = "actionneur de 1re génération (âge 7 : son premier usage, le drone laser, est du même âge)" })
I("fo-crystal-laser", 7, "Laser à cristal", "Crystal laser", { note_fr = "la lentille de résonance sert enfin à un laser" })
I("fo-optical-sensor", 7, "Capteur optique", "Optical sensor")
I("fo-controller", 7, "Contrôleur programmable", "Programmable controller")
I("fo-laser-drone-capsule", 7, "Capsule de drone laser", "Laser drone capsule", { use = "ammo", stack = 100,
  effect_fr = "capsule : fait naître un robot de combat (prototype combat-robot, faisceau de la tourelle laser) qui SUIT son lanceur 3 min (time_to_live 10 800), comme le défenseur vanilla (follows_player = true, range_from_player 6 ; lui vit 45 s ; le distracteur, speed = 0, ne suit pas) ; compte dans LuaForce.maximum_following_robot_count (bonus de force à décider)" })
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
  note_fr = "fluide PRODUIT par le centre de calcul : 10 MW → 5 unités/s (2 MJ l'unité) ; sans baril (auto_barrel = false), sans valeur de combustion ; il se STOCKE (un réservoir tient 25 000 unités, 50 GJ) et voyage en wagon-citerne (FluidWagonPrototype n'a aucun filtre) ; boîtes filtrées (H-X3-3)" })
I("fo-guidance-core", 10, "Noyau de pilotage", "Guidance core", { note_fr = "modèle de pilotage entraîné par le calcul (20 calculs, 40 MJ) ; premier usage : le drone de garde, du même âge" })
I("fo-guard-drone-capsule", 10, "Capsule de drone de garde", "Guard drone capsule", { use = "ammo", stack = 50,
  effect_fr = "capsule : fait naître un robot de combat laser (prototype combat-robot, follows_player = false) qui garde le point de lancer 10 min ; pour un PNJ : LuaItemStack.use_capsule(personnage, position) (H-X3-1)" })
-- Âge 12 · Supraconducteurs : le robot de combat (C)
I("fo-magnetic-actuator", 12, "Actionneur à aimants", "Magnet actuator", { note_fr = "actionneur de 2e génération : l'aimant permanent entre enfin dans un moteur" })
I("fo-ndyag-rod", 12, "Barreau laser Nd:YAG", "Nd:YAG laser rod", { note_fr = "grenat Y₃Al₅O₁₂ dopé au néodyme : yttrium, néodyme et alumine" })
I("fo-laser-module", 12, "Module laser", "Laser module")
I("fo-combat-robot", 12, "Robot de combat", "Combat robot", { use = "ammo", stack = 10,
  effect_fr = "capsule lancée : fait naître une unité de combat (prototype unit, ai_settings = { allow_try_return_to_spawner = false, destroy_when_commands_fail = false }, valeurs par défaut en 1.1.91) de la force du lanceur, qui tient sa place (H-X3-2) ; plafond proposé : 4 robots vivants par atelier de robotique de la force (Q-X3-2)" })

X3.items = items

---------------------------------------------------------------------------------------------------
-- 3. Bâtiments nouveaux (6). Visuel PROVISOIRE : copie teintée d'une machine vanilla (comme T.BUILDINGS du titane) ;
--    un vrai modèle passera par le verdict du DC sur capture. Niveaux : la famille « assembler » ou « furnace » prend,
--    au-dessus du niveau 1, l'image de l'assembleur ou du four de son âge (prototypes/levels/assembler.lua et
--    furnace.lua) : seule l'imprimante (3 × 3, une machine d'assemblage) la garde ; les cinq autres prennent la famille
--    « process » (procédés, pas de module visuel en jeu aujourd'hui : leur image propre reste).
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
   levels = LV("process"), sprite_fr = "copie teintée du four électrique, étirée en 4 × 4 (provisoire)",
   note_fr = "la plus gourmande de l'âge 6 (le four à arc tire 4,4 MW) : l'âge de l'électricité se voit sur le réseau" }
B{ name = "fo-crystal-puller", epoch = 10, fr = "Tireuse de cristal", en = "Crystal puller",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 1500, speed = 1, categories = { "fo-crystal-pulling" },
   levels = LV("process"), sprite_fr = "copie teintée de la centrifugeuse" }
B{ name = "fo-crystal-lithograph", epoch = 10, fr = "Lithographe à cristal", en = "Crystal lithograph",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 3000, speed = 1, categories = { "fo-lithography" },
   fluid_in = 2, levels = LV("process"), sprite_fr = "copie teintée d'assembling-machine-3, étirée en 4 × 4 (provisoire)",
   note_fr = "ultraviolet obtenu par conversion de fréquence dans le cristal taillé (cristal non linéaire)" }
B{ name = "fo-data-center", epoch = 10, fr = "Centre de calcul", en = "Data center",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-computing" },
   fluid_in = 1, fluid_out = 1, fluid_filters = { input = { "water" }, output = { "fo-compute" } },
   fixed_recipe = "fo-computing", levels = LV("process"), sprite_fr = "copie teintée d'assembling-machine-3, étirée en 4 × 4 (provisoire)",
   rule_fr = "recette fixe : 10 eau/s → 5 calcul/s ; boîtes filtrées (FluidBox.filter : eau en entrée, calcul en sortie) ; ses niveaux (famille des procédés) donnent plus de calcul par bâtiment" }
B{ name = "fo-robotics-bay", epoch = 10, fr = "Atelier de robotique", en = "Robotics bay",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 2500, speed = 1, categories = { "fo-robotics" },
   fluid_in = 1, fluid_filters = { input = { "fo-compute" } }, levels = LV("process"), sprite_fr = "copie teintée du roboport",
   rule_fr = "reçoit le calcul par tuyau (boîte filtrée sur fo-compute) ; le calcul se stocke et voyage en wagon-citerne : l'atelier n'est pas forcé de se poser à côté du centre" }

for _, b in ipairs(buildings) do
  if b.levels and b.levels.family then b.levels.first = 2 * b.epoch - 1 end
end
X3.buildings = buildings

---------------------------------------------------------------------------------------------------
-- 4. Recettes nouvelles. R(nom, époque, catégorie, durée, ingrédients, produits, options) ; « building » se déduit à la
--    fusion (produit unique = bâtiment). variant_of : la recette produit un objet d'X0 par une autre voie (la voie d'X0
--    reste ; tests/x3_test.lua compare MU, coût de choix du cerveau, énergie et temps-machine des deux voies).
---------------------------------------------------------------------------------------------------
local recipes = {}
local function R(name, epoch, category, time, ingredients, results, o)
  o = o or {}
  o.name, o.epoch, o.category, o.time, o.ingredients, o.results = name, epoch, category, time, ingredients, results
  o.kind = o.kind or "recipe"
  recipes[#recipes + 1] = o
  return o
end

-- Âge 3 · blende → zinc → laiton → manomètre à tube de Bourdon (variante)
R("fo-mine-sphalerite", 3, nil, 1, {}, { { "fo-sphalerite", 1 } },
  { kind = "mining", resource = "fo-sphalerite", machines = DRILLS, fr = "Minage : blende", en = "Mining: sphalerite" })
R("fo-zinc-retort", 3, "fo-coking", 6, { { "fo-sphalerite", 4 }, { "coal", 1 } }, { { "fo-zinc-plate", 2 }, { "fo-slag", 1 } },
  { fr = "Cornue à zinc", en = "Zinc retort",
    note_fr = "grillage et réduction au charbon en cornue ; le soufre part en fumée (le soufre n'arrive qu'à l'âge 4)" })
R("fo-brass", 3, "fo-blast-furnace", 3, { { "copper-plate", 2 }, { "fo-zinc-plate", 1 } }, { { "fo-brass", 3 } }, { prod = true })
R("fo-manometer-brass", 3, "crafting", 3, { { "fo-glass", 2 }, { "iron-gear-wheel", 2 }, { "fo-brass", 1 } }, { { "fo-manometer", 2 } },
  { variant_of = "fo-manometer", fr = "Manomètre à tube de Bourdon", en = "Bourdon-tube pressure gauge",
    note_fr = "le tube de Bourdon en laiton remplace le tuyau : 2 manomètres pour 1 laiton, sans les 2 tuyaux ; la voie d'X0 reste" })

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
R("fo-pcb-advanced-circuit", 4, "crafting", 6, { { "fo-printed-circuit-board", 1 }, { "electronic-circuit", 4 }, { "plastic-bar", 4 }, { "copper-cable", 2 } },
  { { "advanced-circuit", 2 } }, { fr = "Circuit avancé sur carte imprimée", en = "Advanced circuit on printed board", variant_of = "advanced-circuit",
    note_fr = "2 circuits en 6 s (le double du débit vanilla par machine) : la carte remplace 6 des 8 câbles ; MU égale au vanilla à 1 % près (le calendrier ne bouge pas)" })

-- Âge 6 · chaîne C : bauxite → alumine (+ boue rouge → ciment ou fer) → aluminium ; pylône en aluminium (variante)
R("fo-mine-bauxite", 6, nil, 1, {}, { { "fo-bauxite", 1 } },
  { kind = "mining", resource = "fo-bauxite", machines = DRILLS, fr = "Minage : bauxite", en = "Mining: bauxite" })
R("fo-reduction-cell", 6, "crafting", 10, { { "steel-plate", 20 }, { "stone-brick", 30 }, { "fo-graphite", 10 }, { "copper-cable", 40 } },
  { { "fo-reduction-cell", 1 } })
R("fo-lime-sinter-alumina", 6, "chemistry", 6, { { "fo-bauxite", 5 }, { "stone", 1 }, { "water", 20 } }, { { "fo-alumina", 2 }, { "fo-red-mud", 2 } },
  { fr = "Frittage de la bauxite à la chaux", en = "Lime sintering of bauxite",
    note_fr = "à la place du procédé Bayer, qui exige la soude caustique de l'âge 11 (aucun anachronisme)" })
R("fo-red-mud-cement", 6, "fo-crushing", 2, { { "fo-red-mud", 2 }, { "stone", 1 } }, { { "fo-cement", 2 } },
  { fr = "Ciment de boue rouge", en = "Red mud cement" })
R("fo-red-mud-iron", 6, "fo-arc-smelting", 4, { { "fo-red-mud", 4 }, { "fo-graphite", 1 } }, { { "iron-plate", 2 }, { "fo-slag", 1 } },
  { fr = "Fer de la boue rouge", en = "Iron from red mud",
    note_fr = "réduction de la boue rouge au four à arc (procédé réel) : second exutoire, sans plafond (le fer se consomme partout)" })
R("fo-hall-heroult", 6, "fo-fused-salt-electrolysis", 6, { { "fo-alumina", 4 }, { "fo-graphite", 1 } }, { { "fo-aluminium-plate", 2 } },
  { prod = true, fr = "Électrolyse ignée (Hall-Héroult)", en = "Fused-salt electrolysis (Hall-Héroult)",
    note_fr = "anode de graphite consommée ; 2 alumines et 0,5 anode par plaque, proche du réel ; 6 MW × 6 s = 36 MJ pour 2 plaques" })
R("fo-ht-pylon-aluminium", 6, "crafting", 2, { { "steel-plate", 6 }, { "fo-aluminium-plate", 2 }, { "fo-coil", 2 } }, { { "fo-ht-pylon", 1 } },
  { variant_of = "fo-ht-pylon", fr = "Pylône à conducteur aluminium-acier", en = "Aluminium-steel conductor pylon",
    note_fr = "conducteur aluminium-acier : 2 plaques d'aluminium à la place des 4 câbles de cuivre et de 4 aciers ; la voie d'X0 reste" })

-- Âge 7 · chaînes A et C : servomoteur, laser à cristal, capteur, contrôleur, drone laser (tous consommés à l'âge 7)
R("fo-servo-motor", 7, "crafting", 5,
  { { "electric-engine-unit", 1 }, { "fo-coil", 1 }, { "iron-gear-wheel", 2 }, { "electronic-circuit", 1 }, { "fo-aluminium-plate", 1 } },
  { { "fo-servo-motor", 1 } }, { prod = true })
R("fo-crystal-laser", 7, "crafting", 10, { { "fo-cut-crystal", 1 }, { "fo-resonance-lens", 2 }, { "fo-coil", 2 }, { "fo-aluminium-plate", 1 } },
  { { "fo-crystal-laser", 1 } })
R("fo-optical-sensor", 7, "crafting", 6, { { "fo-resonance-lens", 1 }, { "fo-crystal-oscillator", 2 }, { "fo-printed-circuit-board", 1 } },
  { { "fo-optical-sensor", 2 } }, { prod = true })
R("fo-controller", 7, "crafting", 8, { { "advanced-circuit", 2 }, { "fo-crystal-oscillator", 2 }, { "fo-printed-circuit-board", 1 } },
  { { "fo-controller", 1 } }, { prod = true })
R("fo-laser-drone-capsule", 7, "crafting", 15,
  { { "fo-servo-motor", 1 }, { "fo-optical-sensor", 1 }, { "fo-controller", 1 }, { "fo-crystal-laser", 1 }, { "battery", 2 } },
  { { "fo-laser-drone-capsule", 1 } }, { note_fr = "un drone monté : servomoteur, capteur, contrôleur et laser (version 1 : un distracteur vanilla et un laser)" })

-- Âge 10 · chaîne A, la fonderie de puces : quartz → creuset ; silicium pur → lingot → tranches sciées (variante) ;
-- lithographie → tranche gravée → processeur gravé (variante), mémoire, carte graphique
R("fo-mine-vein-quartz", 10, nil, 3, {}, { { "fo-vein-quartz", 1 } },
  { kind = "mining", resource = "fo-vein-quartz", machines = DRILLS, fr = "Minage : quartz filonien", en = "Mining: vein quartz" })
R("fo-quartz-crucible", 10, "fo-arc-smelting", 4, { { "fo-vein-quartz", 6 } }, { { "fo-quartz-crucible", 1 } },
  { fr = "Creuset de quartz fondu", en = "Fused quartz crucible" })
R("fo-crystal-puller", 10, "advanced-crafting", 10,
  { { "steel-plate", 10 }, { "fo-graphite", 10 }, { "fo-coil", 5 }, { "advanced-circuit", 5 }, { "fo-glass", 10 } }, { { "fo-crystal-puller", 1 } })
R("fo-silicon-ingot", 10, "fo-crystal-pulling", 40, { { "fo-pure-silicon", 10 }, { "fo-quartz-crucible", 1 } }, { { "fo-silicon-ingot", 1 } },
  { fr = "Tirage Czochralski", en = "Czochralski pulling" })
R("fo-wafer-sawing", 10, "fo-lapidary", 20, { { "fo-silicon-ingot", 1 }, { "fo-crystal-powder", 2 }, { "water", 40 } }, { { "fo-silicon-wafer", 40 } },
  { variant_of = "fo-silicon-wafer", fr = "Tranches sciées dans le lingot", en = "Wafers sawn from the ingot",
    note_fr = "scie à fil (taillerie), la poudre de cristal sert d'abrasif : 4 tranches par silicium pur, comme en salle blanche (X0, qui reste), mais environ 1,7 MJ la tranche au lieu de 10 : un échange matière contre énergie, pas un rabais (le cerveau garde la voie d'X0 pour quelques tranches)" })
R("fo-photoresist", 10, "chemistry", 4, { { "fo-epoxy-resin", 20 }, { "light-oil", 10 }, { "sulfur", 1 } }, { { "fo-photoresist", 20 } })
R("fo-photomask", 10, "fo-cleanroom", 20, { { "fo-glass", 2 }, { "fo-tungsten-plate", 1 }, { "advanced-circuit", 1 } }, { { "fo-photomask", 1 } },
  { note_fr = "sans processeur dans sa recette : aucun cycle processeur → masque → processeur" })
R("fo-crystal-lithograph", 10, "advanced-crafting", 30,
  { { "fo-crystal-laser", 4 }, { "fo-cut-crystal", 10 }, { "fo-resonance-lens", 10 }, { "processing-unit", 20 }, { "steel-plate", 20 } },
  { { "fo-crystal-lithograph", 1 } })
R("fo-etched-wafer", 10, "fo-lithography", 20,
  { { "fo-silicon-wafer", 10 }, { "fo-photomask", 1 }, { "fo-photoresist", 5 }, { "sulfuric-acid", 10 } }, { { "fo-etched-wafer", 10 } },
  { prod = true, fr = "Lithographie et gravure", en = "Lithography and etching" })
R("fo-memory-module", 10, "fo-cleanroom", 10, { { "fo-etched-wafer", 1 }, { "fo-printed-circuit-board", 1 }, { "fo-tin-plate", 1 } },
  { { "fo-memory-module", 2 } }, { prod = true })
R("fo-etched-processor", 10, "fo-cleanroom", 10, { { "fo-etched-wafer", 2 }, { "fo-printed-circuit-board", 2 }, { "electronic-circuit", 9 }, { "advanced-circuit", 1 } },
  { { "processing-unit", 2 } }, { prod = true, variant_of = "processing-unit", fr = "Processeur gravé", en = "Etched processor",
    note_fr = "mise en boîtier de puces gravées sur carte imprimée : 9 circuits verts et 1 circuit avancé, contre 10 et 2 en salle blanche (X0, qui reste), en 10 s au lieu de 15 ; MU à 5 % près (le calendrier ne bouge pas)" })
R("fo-graphics-card", 10, "fo-cleanroom", 15,
  { { "fo-etched-wafer", 4 }, { "fo-memory-module", 2 }, { "fo-printed-circuit-board", 1 }, { "fo-aluminium-plate", 1 }, { "fo-tin-plate", 1 } },
  { { "fo-graphics-card", 1 } }, { prod = true })

-- Âge 10 · chaîne B : centre de calcul → calcul → noyau de pilotage ; chaîne C : atelier de robotique, drone de garde
R("fo-data-center", 10, "advanced-crafting", 30,
  { { "fo-graphics-card", 10 }, { "fo-controller", 4 }, { "steel-plate", 20 }, { "concrete", 20 }, { "pipe", 10 } }, { { "fo-data-center", 1 } })
R("fo-computing", 10, "fo-computing", 1, { { "water", 10 } }, { { "fo-compute", 5 } },
  { fr = "Calcul", en = "Computing", note_fr = "recette fixe du centre de calcul (10 MW : 2 MJ l'unité) ; l'eau évaporée est le refroidissement, rien à évacuer" })
R("fo-robotics-bay", 10, "advanced-crafting", 20,
  { { "fo-servo-motor", 10 }, { "fo-controller", 6 }, { "fo-optical-sensor", 10 }, { "steel-plate", 40 }, { "concrete", 40 } }, { { "fo-robotics-bay", 1 } })
R("fo-guidance-core", 10, "fo-robotics", 20,
  { { "fo-controller", 1 }, { "fo-graphics-card", 1 }, { "fo-optical-sensor", 2 }, { "fo-compute", 20 } }, { { "fo-guidance-core", 1 } },
  { note_fr = "20 calculs, soit 40 MJ d'électricité, par noyau" })
R("fo-guard-drone-capsule", 10, "fo-robotics", 10,
  { { "fo-guidance-core", 1 }, { "fo-servo-motor", 2 }, { "battery", 2 }, { "fo-compute", 2 } },
  { { "fo-guard-drone-capsule", 1 } }, { note_fr = "le noyau de pilotage sert dès l'âge 10 : un drone qui garde seul" })

-- Âge 11 · chaîne B : procédé Siemens (variante du silicium pur ; exutoire de l'hydrogène et du chlore de la saumure)
R("fo-siemens-silicon", 11, "chemistry", 8,
  { { "fo-metallurgical-silicon", 3 }, { "fo-chlorine", 12, catalyst = 10 }, { "fo-hydrogen", 75 } },
  { { "fo-pure-silicon", 2 }, { "fo-chlorine", 10, catalyst = 10 } },
  { process = "catalytic", variant_of = "fo-pure-silicon", fr = "Silicium pur (procédé Siemens)", en = "Pure silicon (Siemens process)",
    note_fr = "trichlorosilane : le chlore tourne en boucle (catalyseur déclaré), 2 sont perdus ; 1,5 silicium métallurgique par silicium pur au lieu de 2, mais 37,5 hydrogènes au lieu de 30 : il MANGE l'hydrogène (X0, qui reste) ; MU à 5 % près" })

-- Âge 12 · chaîne C : actionneur à aimants, barreau Nd:YAG, module laser, robot de combat ; unité cryogénique actionnée (variante)
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
R("fo-cryogenic-unit-actuated", 12, "advanced-crafting", 15,
  { { "steel-plate", 40 }, { "fo-titanium-plate", 3 }, { "fo-magnetic-actuator", 2 }, { "processing-unit", 10 }, { "pipe", 20 } },
  { { "fo-cryogenic-unit", 1 } }, { variant_of = "fo-cryogenic-unit", fr = "Unité cryogénique actionnée", en = "Actuated cryogenic unit",
    note_fr = "compresseurs entraînés par 2 actionneurs à aimants à la place de 10 moteurs électriques ; la voie d'X0 reste (pack 12)" })

-- Âge 13 · machines pilotées (variantes de bâtiments de la ligne principale T5 : la voie d'X0 reste)
R("fo-deep-drill-guided", 13, "advanced-crafting", 20,
  { { "fo-heavy-drill", 1 }, { "fo-tungsten-carbide", 20 }, { "fo-superconducting-coil", 10 }, { "fo-magnetic-actuator", 1 }, { "fo-guidance-core", 1 } },
  { { "fo-deep-drill", 1 } }, { variant_of = "fo-deep-drill", fr = "Foreuse profonde pilotée", en = "Guided deep drill",
    note_fr = "une machine montée : 1 actionneur et 1 noyau de pilotage à la place de 10 processeurs (moins cher en MU, en énergie et en temps-machine)" })
R("fo-plasma-foundry-guided", 13, "advanced-crafting", 30,
  { { "fo-tungsten-plate", 50 }, { "fo-superconducting-coil", 20 }, { "concrete", 20 }, { "fo-magnetic-actuator", 1 }, { "fo-guidance-core", 1 } },
  { { "fo-plasma-foundry", 1 } }, { variant_of = "fo-plasma-foundry", fr = "Fonderie à plasma pilotée", en = "Guided plasma foundry",
    note_fr = "pilotage du plasma : 1 actionneur et 1 noyau à la place de 10 processeurs" })
R("fo-core-drill-laser", 13, "advanced-crafting", 30,
  { { "fo-concentrate-drill", 1 }, { "fo-superconducting-coil", 20 }, { "fo-tungsten-carbide", 20 }, { "fo-magnetic-actuator", 2 },
    { "fo-guidance-core", 1 }, { "fo-laser-module", 2 } },
  { { "fo-core-drill", 1 } }, { variant_of = "fo-core-drill", fr = "Foreuse de noyau assistée par laser", en = "Laser-assisted core drill",
    note_fr = "forage assisté par laser : 2 actionneurs, 1 noyau et 2 modules laser à la place de 20 processeurs et 20 carbures" })

X3.recipes = recipes

---------------------------------------------------------------------------------------------------
-- 5. Retouches de recettes X0 : AUCUNE (règle « des voies, jamais une porte »). Le mécanisme reste dans X3.merge (les
--    mutants du banc s'en servent) ; une retouche future devra viser une recette HORS du chemin obligatoire (ni Codex,
--    ni pack, ni ligne principale) et aucune recette que shared/content/titanium.lua déplie : tests/x3_test.lua le
--    contrôle.
---------------------------------------------------------------------------------------------------
X3.retouches = {}

---------------------------------------------------------------------------------------------------
-- 6. Technologies : 7 nouvelles, toutes FACULTATIVES (ni pack, ni Codex), et 5 extensions de technologies X0
--    (déblocages ajoutés ; prérequis seulement pour réparer trois défauts d'X0 et pour la variante de l'âge 11).
--    Les prérequis qui traversent les âges sont déclarés (l'arbre affiché en jeu les montre). Packs et unités :
--    calculés à la fusion comme dans X0 (X.pack_window, X.TECH_UNITS × poids du rôle), avec le recalage X3.tech_units.
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
T("fo-aluminium", 6, "Aluminium", "Aluminium",
  { "fo-reduction-cell", "fo-lime-sinter-alumina", "fo-red-mud-cement", "fo-red-mud-iron", "fo-hall-heroult", "fo-ht-pylon-aluminium" },
  { prereq = { "fo-arc-smelting", "fo-electrical-steel", "fo-high-voltage" } })
T("fo-servo-mechanisms", 7, "Servomécanismes et laser à cristal", "Servomechanisms and crystal laser",
  { "fo-servo-motor", "fo-crystal-laser", "fo-optical-sensor", "fo-controller", "fo-laser-drone-capsule" },
  { prereq = { "fo-aluminium", "fo-printed-circuits" } })
T("fo-chip-foundry", 10, "Fonderie de puces", "Chip foundry",
  { "fo-quartz-crucible", "fo-crystal-puller", "fo-silicon-ingot", "fo-wafer-sawing", "fo-photoresist", "fo-photomask",
    "fo-crystal-lithograph", "fo-etched-wafer", "fo-memory-module", "fo-etched-processor", "fo-graphics-card" },
  { prereq = { "fo-silicon", "fo-servo-mechanisms" } })
T("fo-computing", 10, "Calcul et robotique", "Computing and robotics",
  { "fo-data-center", "fo-computing", "fo-robotics-bay", "fo-guidance-core", "fo-guard-drone-capsule" },
  { prereq = { "fo-chip-foundry" } })
T("fo-combat-robots", 12, "Robots de combat", "Combat robots",
  { "fo-magnetic-actuator", "fo-ndyag-rod", "fo-laser-module", "fo-combat-robot", "fo-cryogenic-unit-actuated" },
  { prereq = { "fo-computing" } })
T("fo-guided-machinery", 13, "Machines pilotées", "Guided machinery",
  { "fo-deep-drill-guided", "fo-plasma-foundry-guided", "fo-core-drill-laser" },
  { prereq = { "fo-combat-robots", "fo-concentration" } })
X3.technologies = technologies

X3.extends = {
  { tech = "fo-glassworks", unlocks = { "fo-zinc-retort", "fo-brass", "fo-manometer-brass" }, fr = "Verrerie et laiton", en = "Glassworks and brass",
    why_fr = "le manomètre, débloqué ici, a une variante à tube de Bourdon en laiton (déblocages seulement : la verrerie reste sur le chemin du Codex III sans rien demander de plus)" },
  { tech = "fo-wet-tungsten", unlocks = { "fo-siemens-silicon" }, prereq = { "fo-silicon" }, fr = "Voie humide : tungstène et silicium", en = "Wet processes: tungsten and silicon",
    why_fr = "deux exutoires des produits de la saumure (soude, hydrogène, chlore) ; prérequis fo-silicon (silicium métallurgique, âge 10) ; en jeu, T.TECHS du titane n'est PAS changé (à faire à l'intégration)" },
  -- Trois défauts d'X0 trouvés par x3_test (un objet du même âge requis hors des prérequis), réparés dans la fusion :
  { tech = "fo-drilling-records", prereq = { "fo-asphalt" }, repair_x0 = true,
    why_fr = "défaut d'X0 : le Codex IV prend de l'asphalte, débloqué par fo-asphalt, absent de ses prérequis" },
  { tech = "fo-superalloy", prereq = { "fo-meteoritics" }, repair_x0 = true,
    why_fr = "défaut d'X0 : le superalliage météoritique prend du ferronickel, débloqué par la météoritique" },
  { tech = "fo-orbital-archives", prereq = { "fo-iridium-optics" }, repair_x0 = true,
    why_fr = "défaut d'X0 : le Codex XIV prend des miroirs d'iridium, débloqués par l'optique à l'iridium" },
}

--- Recalage des unités de recherche (règle d'epochs_test : la recherche de chaque époque reste entre 30 et 40 % de son
--- budget ; visée 35 %, comme X0, valeur « unités pour 35 % » que le banc imprime sur la fusion, arrondie). Valeur =
--- unités d'une technologie ordinaire de l'époque, à la place de X.TECH_UNITS[k], dans la FUSION seulement, aux SEULS
--- âges qui reçoivent une technologie d'X3 (4, 6, 7, 10, 12, 13). Aux autres âges, les unités d'X0 restent : la voie
--- d'X0 (celle d'une faction qui n'a pas les ressources d'X3) garde sa part de recherche, et tests/x3_test.lua contrôle
--- la part sur les deux voies (avec et sans les variantes).
X3.tech_units = { [4] = 77, [6] = 147, [7] = 211, [10] = 885, [12] = 5290, [13] = 8790 }

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
      "âge 10 : quartz → creuset ; 10 silicium pur + creuset → [tireuse] lingot → [taillerie, scie à fil] 40 tranches (variante : 6 fois moins d'énergie)",
      "         résine + huile légère → résine photosensible ; verre + tungstène + circuit avancé → photomasque",
      "         [lithographe à cristal : 4 lasers] 10 tranches + masque + résine + acide → 10 tranches gravées",
      "         → processeur gravé (variante), mémoire, carte graphique",
    } },
  { key = "B", fr = "Calculer", epochs = { 10, 11, 13 }, target = "fo-guidance-core",
    path = { "fo-graphics-card", "fo-data-center", "fo-compute", "fo-guidance-core" },
    schema_fr = {
      "âge 10 : 10 cartes graphiques + 4 contrôleurs → [centre de calcul, 10 MW] eau → calcul (fluide, 5/s)",
      "         contrôleur + carte graphique + 2 capteurs + 20 calcul → [atelier de robotique] noyau de pilotage → drone de garde",
      "âge 11 : silicium métallurgique + chlore (boucle) + hydrogène → silicium pur (Siemens, variante)",
      "âge 13 : noyaux dans les foreuses profonde et de noyau et la fonderie à plasma pilotées (variantes)",
    } },
  { key = "C", fr = "Monter des machines, se défendre", epochs = { 6, 7, 10, 12 }, target = "fo-combat-robot",
    path = { "fo-bauxite", "fo-alumina", "fo-aluminium-plate", "fo-servo-motor", "fo-optical-sensor", "fo-controller", "fo-laser-drone-capsule",
      "fo-guard-drone-capsule", "fo-magnetic-actuator", "fo-ndyag-rod", "fo-laser-module", "fo-combat-robot" },
    schema_fr = {
      "âge 6  : bauxite + pierre → alumine + boue rouge (→ ciment ou fer) ; [cuve ignée, 6 MW] alumine + graphite → aluminium → pylône (variante)",
      "âge 7  : moteur électrique + bobine + engrenages + circuit + aluminium → servomoteur ; lentille + oscillateurs + carte → capteur ;",
      "         circuits avancés + oscillateurs + carte → contrôleur ; servomoteur + capteur + contrôleur + laser + batteries → drone laser",
      "âge 10 : noyau de pilotage + 2 servomoteurs + batteries + 2 calcul → drone de garde",
      "âge 12 : servomoteur + 4 aimants + composite → actionneur ; néodyme + yttrium + alumine → [tireuse] barreau Nd:YAG → module laser",
      "         4 actionneurs + noyau + 2 modules laser + composite + batteries → [atelier de robotique] robot de combat",
    } },
}

--- Ce qui n'est PAS fait (doc §3.7) : écarté par les concepteurs ou par la synthèse, et pourquoi.
X3.not_done = {
  "rien en jeu : aucun prototype, aucune locale, aucune garantie de placement, aucun kit minerai ; le jeu ne change pas",
  "aucune voie d'X3 n'est obligatoire (règle « des voies, jamais une porte ») : la rendre obligatoire est une décision du DC (Q-X3-1)",
  "lithographie EUV, imprimante 3D métal, carte multicouche, plaque froide (proposition « puces ») : un 4e endroit lourd, aux âges 13 et 7 ; reportés",
  "aluminium par le procédé Bayer et spath fluor (fluorure d'hydrogène) : la soude n'arrive qu'à l'âge 11 ; frittage à la chaux, sans fluor",
  "latérite (nickel, cobalt), spodumène (lithium), gallium, germanium, argent de la galène, barytine : 6 ressources ou sous-produits de plus pour des usages uniques",
  "lance-drones (tourelle dont la munition est un drone) et obus guidé : comportement moteur non prouvé (H-X3-1, H-X3-3), reportés au lot qui intégrera",
  "laboratoire accéléré par le calcul : un laboratoire 1.1.91 ne prend aucun fluide ; pack d'utilité simulé écarté (il baisserait un pack)",
  "débouché CONTINU du calcul (noyaux pour les robots détruits au combat, seul usage qui se renouvelle) : un pack calculé ferait une porte ; part des niveaux en pièces : à décider (Q-X3-3)",
  "niveaux payés en pièces (servomoteur, contrôleur, noyau) : touche shared/levels/config.lua (fichier de l'intégrateur) ; à décider (Q-X3-3)",
  "variantes du lanceur orbital, du remorqueur et de la Porte d'Érèbe (version 1) : retirées ; une technologie de plus aux âges 14 et 15 pour des bâtiments construits une fois",
  "variante du radar à réseau phasé (version 1 : 2 cartes graphiques) : retirée ; X0 en a déjà une (horloge de phase, branche C)",
  "robots de combat pour les PNJ : aucun exécutant ne lance de capsule aujourd'hui ; poste de garde robotisé (bâtiment lisible par l'étape « construire ») proposé au DC (Q-X3-2)",
  "processeur vanilla caché pour rendre la fonderie obligatoire : entorse à QX4 (Q-X3-1)",
  "cadre de robot piloté : plus cher que le cadre vanilla avec un noyau, sans intérêt ; retiré",
}

--- Hypothèses à prouver en moteur réel quand une chaîne entrera en jeu.
X3.hypotheses = {
  { key = "H-X3-1", fr = "un combat-robot lancé par une capsule à recette d'usine (drone laser, drone de garde) naît dans la force du lanceur et combat sans script ; le drone laser suit son lanceur comme le défenseur vanilla (follows_player = true, range_from_player 6) et compte dans LuaForce.maximum_following_robot_count ; voie des PNJ : LuaItemStack.use_capsule(personnage, position) depuis l'inventaire du personnage, puis lecture de combat_robot_owner (API 1.1.91)" },
  { key = "H-X3-2", fr = "une unité (prototype unit, ai_settings = { allow_try_return_to_spawner = false, destroy_when_commands_fail = false }, valeurs par défaut de la 1.1.91) née d'une capsule tient sa place sans commande et riposte : seules l'immobilité et la riposte restent à prouver ; filet : la commande de garnison du code de guerre, une fois à la naissance" },
  { key = "H-X3-3", fr = "le calcul (fluide sans baril) ne se mêle pas à l'eau : FluidBox.filter (prototype-api.json 1.1.91) = « water » à l'entrée du centre de calcul, « fo-compute » à sa sortie et à l'entrée de l'atelier de robotique ; il se stocke (réservoir) et voyage en wagon-citerne, ce qui est voulu (un calcul non stockable exigerait un script)" },
  { key = "H-X3-4", fr = "les 3 jeux de gisements propres (compteur restauré, skip_span 1, seed1 numérique, masque de région propre) ne déplacent AUCUN minerai : 0 écart sur le compte des entités de fer, cuivre, charbon, pierre, uranium, pétrole, tungstène, cristal, méthane, ilménite et saumure sur les 5 graines du scénario monde, avant et après ; le quartz n'a pas d'autoplace (garantie seule)" },
}

--- Questions au Directeur Créatif (à poser en QCM, exemple chiffré).
X3.questions = {
  { key = "Q-X3-1", fr = "Les voies réalistes (processeur gravé, tranches sciées, manomètre en laiton, circuit avancé sur carte imprimée, pylône en aluminium, machines pilotées) sont des VARIANTES : la voie d'X0 reste, aucune ressource nouvelle n'est obligatoire. Faut-il en rendre une obligatoire (par exemple cacher le processeur vanilla à l'âge 10, entorse à QX4) ? Proposé : non ; chaque obligation ajoute une expédition par faction (F235, F251) et change le chemin critique approuvé." },
  { key = "Q-X3-2", fr = "Les robots de combat : (a) capsules du joueur seul, comme le vanilla ; (b) poste de garde robotisé posé (un bâtiment qui fait naître et entretient 4 robots, que les PNJ savent construire) ; (c) les deux. Proposé : (c)." },
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

--- X0 RÉPARÉ seulement (les trois prérequis manquants d'X0, sans rien d'X3) : la référence honnête du banc pour le
--- cerveau (les réparations ajoutent des recherches aux âges 4 et 14 ; elles ne sont pas le fait des chaînes d'X3).
function X3.repairs_only(data)
  local d = { resources = {}, items = {}, buildings = {}, recipes = {}, technologies = {}, retouches = {}, extends = {} }
  for _, e in ipairs((data or X3).extends) do if e.repair_x0 then d.extends[#d.extends + 1] = deep(e) end end
  return d
end

--- Les variantes d'X3 retirées (voie d'X0 seule, celle d'une faction qui n'a pas les ressources d'X3) : copie des
--- données sans les recettes `variant_of`, ni leurs déblocages. Sert au banc (part de la recherche sur la voie d'X0).
function X3.without_variants(data)
  local d = deep(data or X3)
  local gone = {}
  for i = #d.recipes, 1, -1 do
    if d.recipes[i].variant_of then gone[d.recipes[i].name] = true; table.remove(d.recipes, i) end
  end
  local function strip(list)
    for i = #list, 1, -1 do if gone[list[i]] then table.remove(list, i) end end
  end
  for _, t in ipairs(d.technologies) do strip(t.unlocks) end
  for _, e in ipairs(d.extends) do if e.unlocks then strip(e.unlocks) end end
  return d
end

return X3
