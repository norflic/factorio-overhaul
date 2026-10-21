--[[
  Époques, branches avancées, ressources, bâtiments et arbres de fabrication (lot X0). Pur Lua : AUCUNE
  API Factorio. Lisible à l'étape data (génération des prototypes par les lots X1 à X15), en control
  (verrou d'époque, Serment, systèmes de branche) et hors jeu (tests/epochs_test.lua).

  Scénario, justification et arbres lisibles : docs/SCENARIO_EPOQUES.md (mêmes noms, mêmes chiffres).

  Conventions
  - Tout ce qui est nouveau porte le préfixe « fo- ». Un nom sans préfixe est un nom vanilla exact,
    vérifié dans data/base/prototypes (item.lua, fluid.lua, recipe.lua) de la version 1.1.91.
  - Objets en unités entières (le moteur les stocke en uint16) ; fluides en unités (double).
  - Durées en secondes à la vitesse 1 ; puissances en kW ; valeurs de combustion en MJ.
  - rho = densité en MU par objet (BALANCE_SHEET §3 : 1 MU = 1 plaque de fer vanilla).
  - Toutes les collections sont des TABLEAUX parcourus avec ipairs : jamais l'ordre de pairs.
  - Statut : PROPOSITION ❔ à valider par le Directeur Créatif. Rien n'est implémenté en jeu.
  - Version 2 (correction du lot X0, 21/10) : difficulté alignée sur le lot IA0, monnaies au format V2,
    foreuses de concentré T4 et T5, technologies, garanties de placement, niveaux des bâtiments, chaîne de
    chaleur à 5 000 °C, recettes denses calibrées sur shared/balance_model.lua, branche C bornée.
]]

local X = {}

X.VERSION = 2
X.EPOCHS = 15
X.PREFIX = "fo-"

---------------------------------------------------------------------------------------------------
-- 1. Limites moteur 1.1.91 respectées par ces données (relues dans doc-html/prototype-api.json ;
--    tests/epochs_test.lua relit les phrases citées quand la doc est présente).
---------------------------------------------------------------------------------------------------
X.LIMITS = {
  item_amount_max = 65535,      -- RecipePrototype.ingredients : « The maximum ingredient amount is 65535 » ; ItemIngredientPrototype.amount et ItemProductPrototype.amount : uint16
  energy_required_min = 0.001,  -- RecipePrototype.energy_required : « Must be `> 0.001` »
  name_max_length = 200,        -- PrototypeBase.name : « May not contain a dot, nor exceed a length of 200 characters »
  wire_distance_max = 64,       -- ElectricPolePrototype.maximum_wire_distance : « Max value is 64 »
  supply_distance_max = 64,     -- ElectricPolePrototype.supply_area_distance et BeaconPrototype.supply_area_distance : 64 au plus
  furnace_item_inputs_max = 1,  -- FurnacePrototype.source_inventory_size : « not more than 1 »
  assembler_ingredients_max = 255, -- AssemblingMachinePrototype.ingredient_count : uint8, 255 par défaut
  new_building_side_max = 10,   -- pas une limite moteur : réponse du Directeur Créatif à Q9 (« une usine de 10x10 »)
  heat_connections_max = 32,    -- HeatBuffer.connections : « May contain up to 32 connections »
  vanilla_heat_pipe_max_c = 1000, -- data/base/prototypes/entity/entities.lua l. 15071 (caloduc : 1 000 °C, 1 GW)
}
--- Phrases et valeurs relues dans doc-html/prototype-api.json PROPRIÉTÉ PAR PROPRIÉTÉ (owner = prototype
--- ou type de la doc, prop = propriété) : text = phrase de sa description ; default = valeur par défaut ;
--- type_has = noms qui doivent figurer dans son type ; required = propriété obligatoire.
X.DOC_PHRASES = {
  { key = "item_amount_max", owner = "RecipePrototype", prop = "ingredients", text = "The maximum ingredient amount is 65535" },
  { key = "empty_ingredients", owner = "RecipePrototype", prop = "ingredients", text = "Can be set to an empty table to create a recipe that needs no ingredients" },
  { key = "empty_results", owner = "RecipePrototype", prop = "results", text = "Can be set to an empty table to create a recipe that produces nothing" },
  { key = "duplicate_ingredients", owner = "RecipePrototype", prop = "ingredients", text = "Duplicate ingredients, e.g. two entries with the same name, are *not* allowed" },
  { key = "energy_required_min", owner = "RecipePrototype", prop = "energy_required", text = "Must be `> 0.001`" },
  { key = "crafting_no_fluid", owner = "RecipePrototype", prop = "category", text = "can not contain recipes with fluid ingredients or products" },
  { key = "name_max_length", owner = "PrototypeBase", prop = "name", text = "May not contain a dot, nor exceed a length of 200 characters" },
  { key = "wire_distance_max", owner = "ElectricPolePrototype", prop = "maximum_wire_distance", text = "Max value is 64" },
  { key = "supply_distance_max", owner = "ElectricPolePrototype", prop = "supply_area_distance", text = "Max value is 64" },
  { key = "furnace_item_inputs_max", owner = "FurnacePrototype", prop = "source_inventory_size", text = "The number of input slots, but not more than 1" },
  { key = "reactor_no_heat", owner = "ReactorPrototype", prop = "energy_source", text = "May not be a heat energy source" },
  { key = "locomotive_burner", owner = "LocomotivePrototype", prop = "energy_source", type_has = { "BurnerEnergySource", "VoidEnergySource" } },
  { key = "silo_products_ignored", owner = "RocketSiloPrototype", prop = "rocket_parts_required", text = "Recipe products are ignored" },
  { key = "silo_active_energy", owner = "RocketSiloPrototype", prop = "active_energy_usage", text = "Additional energy used during the following parts of the" },
  { key = "silo_result_inventory_default", owner = "RocketSiloPrototype", prop = "rocket_result_inventory_size", default = 0 },
  { key = "probability_range", owner = "ItemProductPrototype", prop = "probability", text = "Value between 0 and 1" },
  { key = "energy_usage_positive", owner = "CraftingMachinePrototype", prop = "energy_usage", text = "Energy usage has to be positive" },
  { key = "crafting_categories_required", owner = "CraftingMachinePrototype", prop = "crafting_categories", required = true },
  { key = "drill_mixed_categories", owner = "MiningDrillPrototype", prop = "resource_categories", text = "may not work as expected" },
  { key = "heat_connections_max", owner = "HeatBuffer", prop = "connections", text = "May contain up to 32 connections" },
  { key = "heat_max_temperature_required", owner = "HeatBuffer", prop = "max_temperature", required = true },
  { key = "heat_max_transfer_required", owner = "HeatBuffer", prop = "max_transfer", required = true },
  { key = "neighbour_bonus_default", owner = "ReactorPrototype", prop = "neighbour_bonus", default = 1 },
  { key = "meltdown_90", owner = "ReactorPrototype", prop = "meltdown_action", text = "at over 90% of max temperature" },
  { key = "boiler_separate_pipe", owner = "BoilerPrototype", prop = "mode", text = "output-to-separate-pipe" },
  { key = "generator_max_temperature", owner = "GeneratorPrototype", prop = "maximum_temperature", text = "The maximum temperature to which the efficiency can increase" },
  { key = "linked_inventory_positive", owner = "LinkedContainerPrototype", prop = "inventory_size", text = "Must be > 0." },
  { key = "auto_barrel_default", owner = "FluidPrototype", prop = "auto_barrel", default = true },
  { key = "fixed_recipe_silo", owner = "AssemblingMachinePrototype", prop = "fixed_recipe", text = "rocket silo" },
}
--- Types de prototype 1.1.91 employés par ces données (repli quand la doc est absente ; sinon le banc relit
--- la liste complète des « typename » de prototype-api.json).
X.PROTO_TYPES = {
  "accumulator", "ammo-turret", "assembling-machine", "beacon", "boiler", "burner-generator", "container",
  "electric-energy-interface", "electric-pole", "electric-turret", "furnace", "generator", "heat-pipe", "inserter",
  "lab", "linked-container", "locomotive", "mining-drill", "radar", "reactor", "rocket-silo", "simple-entity-with-owner", "wall",
}

---------------------------------------------------------------------------------------------------
-- 2. Les 15 époques (liste d'OBJECTIFS §6 validée par Q7). Durée : F1-3 + greffe P2 (0,5 h × k,
--    plafonnée à 7 h : 59,5 h au total). Palier logistique : un toutes les 3 époques (Q5).
---------------------------------------------------------------------------------------------------
X.TIER_DENSITY = { 1, 2, 4, 8, 32 } -- ρ des paliers T1 à T5 (BALANCE_SHEET §3)

X.epochs = {
  { n = 1, key = "pioneer", fr = "Pionnier", en = "Pioneer", act = 1,
    pack = "automation-science-pack", currency = nil, signature = "iron-plate",
    energy_fr = "brûleurs (charbon, bois)",
    reveal_fr = "Sur la carte, des anomalies gravimétriques qu'aucun instrument ne lit.",
    pressure_fr = "délai de grâce, petits déchiqueteurs",
    codex_fr = "Jour 1. L'Arche-5 est une épave ; son noyau tient encore. Les gravimètres de bord affichent des anomalies que rien n'explique : la chute les aurait-elle faussés ?",
    codex_en = "Day 1. The Ark-5 is a wreck; its core still holds. The onboard gravimeters show anomalies nothing can explain: did the crash damage them?",
    milestones = { construction = { "fo-burner-assembler", 4 }, exploration = { chart = 64 } } },
  { n = 2, key = "forge", fr = "Forge", en = "Forge", act = 1,
    pack = "logistic-science-pack", currency = "steel-plate",
    energy_fr = "coke",
    reveal_fr = "Les balises des quatre autres équipages du Convoi : ils ont survécu.",
    pressure_fr = "premières patrouilles des factions",
    codex_fr = "Quatre balises répondent sur la fréquence du Convoi. Les autres équipages ont survécu, et ils s'arment.",
    codex_en = "Four beacons answer on the Convoy frequency. The other crews survived, and they are arming.",
    milestones = { construction = { "fo-blast-furnace", 2 }, exploration = { chart = 128 } } },
  { n = 3, key = "steam", fr = "Vapeur", en = "Steam", act = 1,
    pack = "military-science-pack", currency = "engine-unit",
    energy_fr = "vapeur : 1,8 MW par chaudière",
    reveal_fr = "La planète rayonne plus de chaleur qu'elle n'en reçoit.",
    pressure_fr = "raids de déchiqueteurs plus gros",
    codex_fr = "Le bilan thermique ne ferme pas : Érèbe rayonne plus de chaleur que son étoile ne lui en donne. Quelque chose chauffe la planète par en dessous.",
    codex_en = "The heat balance does not close: Erebus radiates more heat than its star gives it. Something heats the planet from below.",
    milestones = { construction = { "fo-steam-hammer", 4 }, exploration = { chart = 192 } } },
  { n = 4, key = "oil", fr = "Pétrole", en = "Oil", act = 1,
    pack = "chemical-science-pack", currency = "plastic-bar",
    energy_fr = "combustible solide, vapocraquage",
    reveal_fr = "Le pétrole d'Érèbe est trop jeune : il se forme encore, chauffé d'en dessous.",
    pressure_fr = "premières attaques organisées des factions (Normal)",
    codex_fr = "Le pétrole d'Érèbe est jeune : il se forme encore, à quelques kilomètres sous nos pieds. Les géologues de l'Arche refusent d'y croire.",
    codex_en = "Erebus oil is young: it is still forming, a few kilometres beneath our feet. The Ark's geologists refuse to believe it.",
    milestones = { construction = { "fo-steam-cracker", 2 }, exploration = { resource = "crude-oil" } } },
  { n = 5, key = "volcano", fr = "Volcan", en = "Volcano", act = 2,
    pack = "fo-geological-pack", currency = "fo-tungsten-plate",
    energy_fr = "géothermie : 4,2 MW par fumerolle, infinie",
    reveal_fr = "Le flux géothermique est 40 fois trop fort : quelque chose chauffe le manteau.",
    pressure_fr = "blindés et ignés (cendres)",
    codex_fr = "Le flux géothermique est quarante fois trop fort. Le manteau est chauffé de l'intérieur, comme par un cœur.",
    codex_en = "The geothermal flux is forty times too strong. The mantle is heated from within, as if by a heart.",
    milestones = { construction = { "fo-geothermal-tap", 3 }, exploration = { resource = "fo-fumarole" } } },
  { n = 6, key = "electricity", fr = "Électricité", en = "Electricity", act = 2,
    pack = "production-science-pack", currency = "battery",
    energy_fr = "accumulateurs, haute tension",
    reveal_fr = "Les orages magnétiques suivent les anomalies.",
    pressure_fr = "foudroyants attirés par les réseaux",
    codex_fr = "Les orages magnétiques ne suivent pas les vents : ils suivent les anomalies gravimétriques. Nos réseaux les attirent.",
    codex_en = "Magnetic storms do not follow the winds: they follow the gravimetric anomalies. Our grids attract them.",
    milestones = { construction = { "fo-arc-furnace", 2 }, exploration = { chart = 384 } } },
  { n = 7, key = "crystal", fr = "Cristal", en = "Crystal", act = 2,
    pack = "fo-resonance-pack", currency = "fo-resonance-crystal",
    energy_fr = "cristal chargé (énergie transportable, 80 %)",
    reveal_fr = "Les cristaux chantent sans source : la Ligue Azur publie l'hypothèse de la Caustique (A-I).",
    pressure_fr = "foudroyants renforcés",
    codex_fr = "Les cristaux chantent sans source. La Ligue Azur publie une hypothèse : Érèbe traverse une caustique de matière noire.",
    codex_en = "The crystals sing with no source. The Azure League publishes a hypothesis: Erebus is crossing a dark matter caustic.",
    milestones = { construction = { "fo-resonance-amplifier", 4 }, exploration = { resource = "fo-resonance-crystal" } } },
  { n = 8, key = "marsh", fr = "Marais", en = "Marsh", act = 2,
    pack = "fo-biochemical-pack", currency = "fo-biopolymer",
    energy_fr = "turbine à gaz : 10 MW",
    reveal_fr = "La vie d'Érèbe digère le méthane du sous-sol chauffé.",
    pressure_fr = "couvées",
    codex_fr = "La vie d'Érèbe respire le méthane qu'exhale un sous-sol chauffé. Tout ici se nourrit de la même chaleur.",
    codex_en = "Erebus life breathes the methane exhaled by a heated subsoil. Everything here feeds on the same heat.",
    milestones = { construction = { "fo-bioreactor", 4 }, exploration = { resource = "fo-methane" } } },
  { n = 9, key = "atom", fr = "Atome", en = "Atom", act = 2,
    pack = "fo-isotopic-pack", currency = "uranium-238",
    energy_fr = "fission : 40 MW par réacteur",
    reveal_fr = "Le cuivre irradié émet des positons : premier piège d'antimatière (B-I).",
    pressure_fr = "l'Ordre Écarlate cherche l'arme absolue",
    codex_fr = "Le cuivre irradié émet des positons : nous avons piégé notre premier grain d'antimatière. L'Ordre Écarlate y voit déjà une arme.",
    codex_en = "Irradiated copper emits positrons: we have trapped our first speck of antimatter. The Scarlet Order already sees a weapon in it.",
    milestones = { construction = { "nuclear-reactor", 1 }, exploration = { resource = "fo-galena" } } },
  { n = 10, key = "hightech", fr = "Haute technologie", en = "High technology", act = 3,
    pack = "utility-science-pack", currency = "processing-unit",
    energy_fr = "aucune source nouvelle ; concentrés ρ8",
    reveal_fr = "Un réseau de cristal gravé oscille sans énergie : premier cristal temporel (C-I).",
    pressure_fr = "exo-fantassins laser des factions",
    codex_fr = "Un réseau de cristal gravé oscille sans énergie : un cristal temporel. La Dynastie Ambre y voit l'éternité.",
    codex_en = "An etched crystal lattice oscillates with no power: a time crystal. The Amber Dynasty sees eternity in it.",
    milestones = { construction = { "fo-concentrate-drill", 4 }, exploration = { chart = 640 } } },
  { n = 11, key = "titanium", fr = "Titane", en = "Titanium", act = 3,
    pack = "fo-structural-pack", currency = "fo-titanium-plate",
    energy_fr = "aucune source nouvelle ; structures légères",
    reveal_fr = "La brèche des cratères contient des inclusions trop denses : de la matière étrange (D-I).",
    pressure_fr = "nids de famille plus loin, plus gros",
    codex_fr = "Les inclusions de la brèche sont bien trop denses : de la matière étrange, venue d'une météorite que quelque chose a attirée. Le Consortium Émeraude veut tout transmuter.",
    codex_en = "The breccia inclusions are far too dense: strange matter, from a meteorite something pulled in. The Emerald Consortium wants to transmute everything.",
    milestones = { construction = { "fo-kroll-reactor", 2 }, exploration = { resource = "fo-ilmenite" } } },
  { n = 12, key = "superconductors", fr = "Supraconducteurs", en = "Superconductors", act = 3,
    pack = "fo-magnetic-pack", currency = "fo-superconducting-coil",
    energy_fr = "sels fondus : 160 MW ; accumulateur supraconducteur",
    reveal_fr = "L'haloscope capte la matière noire ; la Caustique a une marée (A-II).",
    pressure_fr = "les factions passent à l'époque 12 selon la difficulté",
    codex_fr = "L'haloscope capte enfin le champ d'axions. La Caustique a une marée, et cette marée suit la rotation du noyau.",
    codex_en = "The haloscope finally detects the axion field. The Caustic has a tide, and that tide follows the rotation of the core.",
    milestones = { construction = { "fo-molten-salt-reactor", 1 }, exploration = { resource = "fo-caustic-vein" } } },
  { n = 13, key = "fusion", fr = "Fusion", en = "Fusion", act = 3,
    pack = "fo-plasma-pack", currency = "fo-plasma-cell",
    energy_fr = "fusion D-³He : 800 MW",
    reveal_fr = "Antimatière en quantité, strangelets (B-II, D-II). Le Serment : le joueur choisit sa doctrine.",
    pressure_fr = "la rivale jurée attaque davantage",
    codex_fr = "Antimatière en quantité, strangelets en cuve : la Caustique ne tolère qu'une seule grande perturbation. Il faut choisir sa doctrine : le Serment.",
    codex_en = "Antimatter in bulk, strangelets in vats: the Caustic tolerates only one great disturbance. A doctrine must be chosen: the Oath.",
    milestones = { construction = { "fo-fusion-reactor", 1 }, exploration = { resource = "fo-mantle-vent" } } },
  { n = 14, key = "orbit", fr = "Orbite", en = "Orbit", act = 4,
    pack = "space-science-pack", currency = "fo-superalloy",
    energy_fr = "orbitale : 200 MW par centrale lancée",
    reveal_fr = "Révélation : le Convoi venait ouvrir une Porte sur le trou noir du Cœur.",
    pressure_fr = "pluies de météorites, course à la Porte des factions",
    codex_fr = "Les archives orbitales de l'Arche parlent enfin : le Convoi venait ancrer une Porte sur le trou noir du Cœur. Sans elle, personne ne rentre.",
    codex_en = "The Ark's orbital archives finally speak: the Convoy came to anchor a Gate on the black hole at the Core. Without it, no one goes home.",
    milestones = { construction = { "fo-rectenna", 2 }, exploration = { resource = "fo-meteor-impact" } } },
  { n = 15, key = "legend", fr = "Légende", en = "Legend", act = 4,
    pack = "fo-exotic-pack", currency = "fo-stabilized-exotic-matter", signature = "fo-superalloy", signature_value = 45,
    energy_fr = "annihilation : 2 GW (maîtrise B-III)",
    reveal_fr = "Le Cœur s'éveille : failles, primordiaux, Marée du Cœur.",
    pressure_fr = "Marée du Cœur (siège final)",
    milestones = { construction = { "fo-casimir-stabilizer", 2 }, exploration = { resource = "fo-core-rift" } } },
}

--- Textes vus par le joueur (FR et EN). Canal : l'introduction et chaque Codex s'affichent par
--- LuaGameScript.show_message_dialog (vérifié) au début de partie et à la livraison du Codex au centre ;
--- le texte du Codex est aussi sa description d'objet (localised_description) ; la victoire et la défaite
--- passent par l'écran de fin de LuaGameScript.set_game_state (vérifié). Fichiers .cfg : lots X1 à X15.
X.story = {
  intro_fr = "L'Arche-5 s'est écrasée sur Érèbe. Son noyau devient votre centre de commandement : nourrissez-le, et il vous fera traverser les époques.",
  intro_en = "The Ark-5 has crashed on Erebus. Its core becomes your command center: feed it, and it will carry you through the epochs.",
  victory_fr = "La Porte tient. Le trou de ver s'ouvre sur le système natal, à quarante années-lumière. Érèbe est à vous.",
  victory_en = "The Gate holds. The wormhole opens onto the home system, forty light-years away. Erebus is yours.",
  defeat_fr = "Une autre Porte s'est ouverte avant la vôtre. Le Convoi rentrera sans vous.",
  defeat_en = "Another Gate opened before yours. The Convoy will go home without you.",
  channel_fr = "message de LuaGameScript.show_message_dialog (introduction, Codex livré) ; description de l'objet Codex ; écran de fin de set_game_state",
}

X.acts = {
  { n = 1, fr = "Survivre", en = "Survive", epochs = { 1, 4 } },
  { n = 2, fr = "La planète est étrange", en = "The planet is wrong", epochs = { 5, 9 } },
  { n = 3, fr = "Dompter les nouvelles physiques", en = "Taming the new physics", epochs = { 10, 13 } },
  { n = 4, fr = "La vérité et la Porte", en = "The truth and the Gate", epochs = { 14, 15 } },
}

--- Durée de l'époque k en heures (greffe P2 : 0,5 h × k, plafonnée à 7 h).
--- ÉCART connu : le lot V2 (shared/levels/config.lua, L.target.epoch_hours) vise 0,5 × 1,261^(k-1) h
--- (12,9 h pour l'époque 15) ; même total d'environ 60 h, répartition différente (QX7, §9 du scénario).
function X.epoch_hours(k) return math.min(0.5 * k, 7) end
--- Heure (cumulée, nominale) à laquelle le joueur ATTEINT l'époque k.
function X.reach_hour(k)
  local h = 0
  for j = 1, k - 1 do h = h + X.epoch_hours(j) end
  return h
end
--- Palier logistique (Compaction) de l'époque k : T1 aux époques 1-3, T2 aux 4-6… T5 aux 13-15.
function X.logistics_tier(k) return math.floor((k - 1) / 3) + 1 end
--- Ouvriers d'amélioration : un de plus toutes les 3 époques (1 à 5) ; +1 avec l'Horloge éternelle (QX6).
function X.builders(k, has_eternal_clock) return X.logistics_tier(k) + (has_eternal_clock and 1 or 0) end
--- Niveau maximal d'un bâtiment quand le centre est à l'époque k (Q6 : 2 niveaux par époque).
function X.max_building_level(k) return 2 * k end

--- Débit visé de l'usine du joueur en MU/s à la FIN de l'époque k (greffe P2 : de 3 à 14 000 MU/s,
--- géométrique, ×1,83 par époque).
X.RATE_FIRST, X.RATE_LAST = 3, 14000
function X.rate(k) return X.RATE_FIRST * (X.RATE_LAST / X.RATE_FIRST) ^ ((k - 1) / (X.EPOCHS - 1)) end
--- Débit MOYEN de l'époque k (croissance géométrique de rate(k-1) à rate(k)) :
--- (rate(k) - rate(k-1)) / ln(rate(k) / rate(k-1)). Pour l'époque 1, rate(0) = rate(1) / 1,83.
function X.rate_avg(k)
  local hi, lo = X.rate(k), X.rate(k - 1)
  return (hi - lo) / math.log(hi / lo)
end
--- Budget de l'époque k en MU : débit MOYEN × durée (corrigé : le débit de fin d'époque surestimait de 33 %).
function X.budget(k) return X.rate_avg(k) * 3600 * X.epoch_hours(k) end
--- Passage du centre de k à k+1 (gabarit P3) : un Codex k plus un lot de monnaie d'époque de 10 % du
--- budget de l'époque, en MU. ÉCART connu : V2 (L.epochs[k].value_mult × epoch_value 150) chiffre ce
--- passage 50 à 100 fois plus bas ; à trancher entre les deux lots (§10 du scénario).
X.CODEX_LOT_SHARE = 0.10
function X.cc_upgrade_mu(k) return X.CODEX_LOT_SHARE * X.budget(k) end

--- Monnaies de niveau au format du lot V2 (L.epoch_materials) : UNE monnaie principale par époque ; un
--- niveau payé à l'époque e coûte 60 % de sa valeur en monnaie de e et 40 % en monnaie de e-1 (V2).
--- value = valeur fixe en MU-équivalent (taux de change, écrit une fois ici et repris par V2) ;
--- stack = taille de pile (V2 exige 50 au moins) ; v2_item = l'objet de V2 aujourd'hui (main) ;
--- cap_per_s = débit plafonné par la carte (objets/s), si la source est bornée.
--- Époque 1 : pas de monnaie (V2 : le panier de base de chaque famille paie l'époque 1).
X.currencies = {
  { epoch = 2, item = "steel-plate", value = 5, stack = 100, v2_item = "steel-plate" },
  { epoch = 3, item = "engine-unit", value = 9, stack = 50, v2_item = "engine-unit" },
  { epoch = 4, item = "plastic-bar", value = 3, stack = 100, v2_item = "plastic-bar" },
  { epoch = 5, item = "fo-tungsten-plate", value = 4, stack = 100, v2_item = "fo-tungsten-plate" },
  { epoch = 6, item = "battery", value = 9, stack = 200, v2_item = "battery" },
  { epoch = 7, item = "fo-resonance-crystal", value = 3, stack = 50, v2_item = "fo-resonance-crystal" },
  { epoch = 8, item = "fo-biopolymer", value = 4, stack = 100, v2_item = "fo-methane-barrel",
    why_fr = "le baril de méthane de V2 s'empile par 10 (< 50) ; le biopolymère (PHB) est le produit signature du marais" },
  { epoch = 9, item = "uranium-238", value = 14, stack = 100, v2_item = "uranium-238" },
  { epoch = 10, item = "processing-unit", value = 75, stack = 100, v2_item = "processing-unit" },
  { epoch = 11, item = "fo-titanium-plate", value = 20, stack = 100, v2_item = "low-density-structure",
    why_fr = "le matériau voulu par V2 (want_item fo-titanium-plate)" },
  { epoch = 12, item = "fo-superconducting-coil", value = 60, stack = 100, v2_item = "electric-engine-unit",
    why_fr = "V2 attendait « fo-superconductor » : la bobine supraconductrice est ce supraconducteur" },
  { epoch = 13, item = "fo-plasma-cell", value = 25, stack = 100, v2_item = "uranium-235",
    why_fr = "V2 attendait l'hélium-3, un FLUIDE (impossible à déposer dans le coffre du centre) ; la cellule de plasma le contient (valeur : sa matière, plus la chaleur de 50 plasmas)" },
  { epoch = 14, item = "fo-superalloy", value = 45, stack = 50, v2_item = "rocket-control-unit",
    why_fr = "V2 attendait « fo-meteorite » ; le superalliage ρ32 se coule aussi sans météorite (bloc de fer), donc sans plafond de carte" },
  { epoch = 15, item = "fo-stabilized-exotic-matter", value = 1500, stack = 50, v2_item = "space-science-pack", cap_per_s = 0.3,
    why_fr = "V2 attendait « fo-exotic-matter » ; rare : 3 failles garanties × 5 matières brutes/s ÷ 50 = 0,3 par seconde, et 30 GJ de stabilisation par unité" },
}
function X.currency_of(k)
  for _, c in ipairs(X.currencies) do if c.epoch == k then return c end end
  return nil
end
--- Jalon de production (greffe P3, corrigé) : 2 % du budget de l'époque, converti en monnaie. Époque 1 :
--- plaques de fer (1 MU) ; époque 15 : superalliage (la matière exotique, bornée par les failles, va à la
--- Porte et aux packs).
X.MILESTONE_PRODUCTION_SHARE = 0.02
function X.milestone_production(k)
  local e, c = X.epochs[k], X.currency_of(k)
  local item = e.signature or (c and c.item)
  local value = e.signature_value or (not e.signature and c and c.value) or 1
  return item, math.ceil(X.MILESTONE_PRODUCTION_SHARE * X.budget(k) / value), value
end

---------------------------------------------------------------------------------------------------
-- 3. Verrou d'époque natif (greffe P3) : une technologie cachée fo-epoch-k (enabled = false), passée en
--    researched = true par le script quand le centre atteint le niveau k ; elle est prérequis de toutes
--    les technologies de l'époque k. LuaTechnology.enabled (écriture vérifiée) reste réservé au Serment.
---------------------------------------------------------------------------------------------------
X.epoch_lock = { prefix = "fo-epoch-", first = 2, last = 15 }
function X.epoch_lock_tech(k) return X.epoch_lock.prefix .. tostring(k) end

--- Fenêtre glissante des packs (greffe P2) : une technologie de l'époque k consomme les packs k, k-1 et
--- k-2 (plus le pack militaire pour le combat) ; une technologie de branche consomme sa donnée de branche
--- et le pack de l'époque courante. Jamais plus de 4 sortes de packs pour une technologie.
function X.pack_window(k, opts)
  opts = opts or {}
  local out = {}
  if opts.branch_data then
    out[1] = opts.branch_data
    out[2] = X.epochs[k].pack
    return out
  end
  for j = k, math.max(1, k - 2), -1 do out[#out + 1] = X.epochs[j].pack end
  if opts.military then
    -- Correction : le pack militaire n'est ajouté que s'il manque (époques 3 à 5 : déjà dans la fenêtre).
    local present = false
    for _, p in ipairs(out) do if p == "military-science-pack" then present = true end end
    if not present and k > 3 then out[#out + 1] = "military-science-pack" end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- 4. Branches avancées (Q7). Niveaux I et II cumulables ; niveau III : le Serment (centre au niveau 13)
--    ouvre UNE maîtrise à l'époque 14, les trois autres à l'époque 15. La Porte consomme un produit de
--    niveau II de chaque branche.
---------------------------------------------------------------------------------------------------
X.branches = {
  { key = "A", id = "dark-matter", fr = "Matière noire", en = "Dark matter", faction = "azure",
    data = "fo-gravimetric-survey", mechanic = "tide", epochs = { 7, 12, 14 },
    gate_item = "fo-axion-condensate",
    mechanic_fr = "marée : rendement des veines de 50 à 150 % sur le cycle jour-nuit",
    yields_fr = "minage infini n'importe où (puits gravitique), carte gravimétrique, bouclier de marée, Observatoire",
    wonder = "fo-caustic-observatory",
    cost_risk_fr = "haloscope 20 MW + 2 condenseurs 15 MW ; hélium liquide ; la marée oblige à surconstruire (rendement 50 % à midi)" },
  { key = "B", id = "antimatter", fr = "Antimatière", en = "Antimatter", faction = "scarlet",
    data = "fo-annihilation-data", mechanic = "confinement", epochs = { 9, 13, 14 },
    gate_item = "fo-antihydrogen-trap",
    mechanic_fr = "confinement : 5 s sans courant et les pièges pleins s'annihilent",
    yields_fr = "énergie de fin de partie, grenade à positons, obus et lance d'annihilation, sonde profonde, Bastion",
    wonder = "fo-annihilation-bastion",
    cost_risk_fr = "synchrotron 150 MW ; 5 s sans courant : les pièges pleins explosent (2 000 dégâts chacun, rayon 8)" },
  { key = "C", id = "chronodynamics", fr = "Chronodynamique", en = "Chronodynamics", faction = "amber",
    data = "fo-chronometric-data", mechanic = "dilation", epochs = { 10, 11, 14 },
    gate_item = "fo-stable-time-crystal",
    mechanic_fr = "dilatation : accélère UNE machine voisine contre une consommation accrue ; un sablier par chantier",
    yields_fr = "vitesse contre énergie, chantiers raccourcis (plafonnés), coffres intriqués (1 case, 2 à 4 paires), 6e ouvrier (QX6)",
    wonder = "fo-eternal-clock",
    cost_risk_fr = "chambre 5 MW (II) ou 10 MW (III) + consommation de la machine ×2 (II) ou ×3,5 (III) ; un cristal stable déphasé toutes les 120 s ; sans courant, la chambre perd son cristal (rupture de phase)" },
  { key = "D", id = "strange-matter", fr = "Matière étrange", en = "Strange matter", faction = "emerald",
    data = "fo-hadronic-data", mechanic = "contagion", epochs = { 11, 13, 14 },
    gate_item = "fo-strange-plate",
    mechanic_fr = "croissance autocatalytique ; une cuve qui déborde, manque de courant ou s'entasse contamine le sol",
    yields_fr = "transmutation de la pierre en minerais rares, puits des déchets, munitions à inclusion, murs et armure, Monolithe",
    wonder = "fo-strange-monolith",
    cost_risk_fr = "compresseur 100 MW, plasma ; contagion : sol étrange et 50 dégâts/s autour d'une cuve pleine 60 s, privée de courant 10 s, ou à plus de 8 cuves dans un rayon de 16" },
}
X.SERMENT_EPOCH = 13       -- choix de doctrine (centre au niveau 13), irréversible
X.MASTERY_CHOSEN_EPOCH = 14
X.MASTERY_OTHERS_EPOCH = 15

--- Époque d'ouverture du niveau III d'une branche selon le Serment.
function X.mastery_epoch(branch_key, oath_branch_key)
  if branch_key == oath_branch_key then return X.MASTERY_CHOSEN_EPOCH end
  return X.MASTERY_OTHERS_EPOCH
end

---------------------------------------------------------------------------------------------------
-- 5. Ressources de la carte. kind : "ore" (solide), "fluid", "special" (créée par script ou par
--    événement). La ressource est exploitée par les machines dont les catégories l'acceptent.
---------------------------------------------------------------------------------------------------
X.resources = {
  { name = "fo-fumarole", epoch = 5, kind = "fluid", category = "fo-fumarole", products = { "fo-volcanic-gas" },
    biome = "fo-volcanic-ash", infinite = true, minimum_share = 0.2,
    fr = "Fumerolle", en = "Fumarole", where_fr = "cendres volcaniques",
    placement = { autoplace = "fo-volcanic-ash", guaranteed = { count = 2, distance = { 250, 600 },
      what_fr = "2 fumerolles posées par script dans la première zone de cendres trouvée, ou sur une tache de cendres créée à cette distance si la graine n'en a pas" } } },
  { name = "fo-galena", epoch = 9, kind = "ore", category = "basic-solid", products = { "fo-galena" },
    min_distance = 300, fr = "Galène", en = "Galena", where_fr = "gisements classiques à plus de 300 tuiles du départ",
    placement = { autoplace = "vanilla-like", guaranteed = { count = 2, distance = { 300, 600 },
      what_fr = "2 gisements de 200 000 posés par script si l'autoplace n'en a mis aucun à cette distance" } } },
  { name = "fo-ilmenite", epoch = 11, kind = "ore", category = "fo-hard-solid", products = { "fo-ilmenite-ore" },
    biome = "fo-crater-fields", fr = "Ilménite", en = "Ilmenite", where_fr = "champs de cratères (nouveau biome)",
    placement = { autoplace = "fo-crater-fields", guaranteed = { count = 1, distance = { 400, 900 }, field = "crater",
      what_fr = "au moins un champ de cratères complet (ilménite, lac de saumure, rempart de brèche) posé par script à 400-900 tuiles s'il n'en existe aucun" } } },
  { name = "fo-brine", epoch = 11, kind = "fluid", category = "basic-fluid", products = { "fo-brine" },
    biome = "fo-crater-fields", infinite = true, minimum_share = 0.2,
    fr = "Lac de saumure", en = "Brine lake", where_fr = "fond des cratères",
    placement = { autoplace = "fo-crater-fields", guaranteed = { count = 1, distance = { 400, 900 }, field = "crater",
      what_fr = "dans le champ de cratères garanti (3 lacs)" } } },
  { name = "fo-impact-breccia", epoch = 11, kind = "ore", category = "basic-solid", products = { "stone" },
    biome = "fo-crater-fields", branch = "D", level = 1,
    fr = "Brèche d'impact", en = "Impact breccia", where_fr = "remparts des cratères",
    placement = { autoplace = "fo-crater-fields", guaranteed = { count = 1, distance = { 400, 900 }, field = "crater",
      what_fr = "dans le champ de cratères garanti (rempart)" } } },
  { name = "fo-monazite", epoch = 12, kind = "ore", category = "basic-solid", products = { "fo-monazite-ore" },
    biome = "fo-black-sands", fr = "Monazite", en = "Monazite", where_fr = "sables noirs (rivages, ou dunes sur carte sèche)",
    placement = { autoplace = "fo-black-sands", guaranteed = { count = 2, distance = { 400, 900 },
      what_fr = "2 taches de sables noirs à monazite posées par script, même sans eau (dunes de sable noir)" } } },
  { name = "fo-caustic-vein", epoch = 12, kind = "special", category = "fo-caustic", products = { "fo-dark-flux" },
    infinite = true, branch = "A", level = 2,
    fr = "Veine de caustique", en = "Caustic vein",
    where_fr = "partout ; 2 veines près du départ, puis 1 veine pour 20 à 25 chunks balayés au radar",
    placement = { script = "on_sector_scanned", guaranteed = { count = 2, distance = { 80, 200 },
      what_fr = "2 veines « visibles mais illisibles » posées au début de partie (hachage de la graine)" } } },
  { name = "fo-mantle-vent", epoch = 13, kind = "fluid", category = "fo-mantle", products = { "fo-helium-3" },
    biome = "fo-volcanic-ash", infinite = true, minimum_share = 0.1,
    fr = "Évent mantellique", en = "Mantle vent", where_fr = "cœur des cendres volcaniques, rare",
    placement = { autoplace = "fo-volcanic-ash", guaranteed = { count = 2, distance = { 500, 1000 },
      what_fr = "2 évents posés par script au cœur de la plus grande zone de cendres à cette distance" } } },
  { name = "fo-meteor-impact", epoch = 14, kind = "special", category = "fo-hard-solid", products = { "fo-ferrous-meteorite" },
    infinite = true, minimum_share = 0.2, tiles = { 20, 40 }, sites_per_shower = 2,
    fr = "Impact météoritique", en = "Meteor impact",
    where_fr = "créé par les pluies de météorites (toutes les 20 à 40 min) ; infini (minimum 20 %)",
    placement = { script = "meteor_shower", guaranteed = { count = 2, distance = { 150, 400 },
      what_fr = "la première pluie tombe à l'entrée dans l'époque 14, à 150-400 tuiles du centre" } } },
  { name = "fo-core-rift", epoch = 15, kind = "special", category = "fo-rift", products = { "fo-raw-exotic-matter" },
    infinite = true, count = { 3, 5 }, distance = { 600, 1200 },
    fr = "Faille du Cœur", en = "Core rift", where_fr = "3 à 5 failles posées au réveil du Cœur, gardées par des primordiaux",
    placement = { script = "core_awakening", guaranteed = { count = 3, distance = { 600, 1200 },
      what_fr = "3 à 5 failles à des positions tirées de la graine" } } },
}
-- Remontées profondes (correction : une ressource 1.1 n'a qu'un produit de minage, il en faut une par
-- minerai). Créées par le script sous le puits : 25 tuiles du minerai choisi dans une interface propre
-- au puits (on_gui_opened), puis LuaEntity.update_connections() sur le puits (méthode vérifiée dans
-- runtime-api.json ; la doc cite les foreuses ; effet sur une ressource créée : non vérifié en moteur).
-- Catégorie fo-deep (fer, cuivre : puits I et II) ; fo-deep-rare (minerais rares : puits II seulement).
for _, u in ipairs({ { "iron", "fer", "Iron", "fo-iron-concentrate", "fo-deep", 12, 2 },
                     { "copper", "cuivre", "Copper", "fo-copper-concentrate", "fo-deep", 12, 2 },
                     { "tungsten", "tungstène", "Tungsten", "fo-tungsten-concentrate", "fo-deep-rare", 14, 3 },
                     { "ilmenite", "ilménite", "Ilmenite", "fo-ilmenite-concentrate", "fo-deep-rare", 14, 3 },
                     { "monazite", "monazite", "Monazite", "fo-monazite-concentrate", "fo-deep-rare", 14, 3 } }) do
  X.resources[#X.resources + 1] = { name = "fo-deep-upwelling-" .. u[1], epoch = u[6], kind = "special", category = u[5],
    products = { u[4] }, infinite = true, branch = "A", level = u[7],
    fr = "Remontée profonde : " .. u[2], en = "Deep upwelling: " .. u[3]:lower(),
    where_fr = "créée par le script sous un puits gravitique (minerai choisi par le joueur)",
    placement = { script = "under_gravity_well", guaranteed = { by_construction = true,
      what_fr = "créée sous chaque puits posé : jamais absente" } } }
end

--- Ressources vanilla et ressources déjà livrées par le mod (shared/content/world.lua), avec leur époque.
--- placement : « vanilla-start » (zone de départ vanilla), « vanilla » (autoplace vanilla, non garanti
--- sur une carte réglée sans pétrole ni uranium : choix du joueur), ou garantie PROPOSÉE pour l'existant
--- (world.lua ne pose aujourd'hui ces biomes que par bruit, sans garantie).
X.base_resources = {
  { name = "iron-ore", epoch = 1, placement = { vanilla = "start" } }, { name = "copper-ore", epoch = 1, placement = { vanilla = "start" } },
  { name = "coal", epoch = 1, placement = { vanilla = "start" } }, { name = "stone", epoch = 1, placement = { vanilla = "start" } },
  { name = "wood", epoch = 1, placement = { vanilla = "start" } }, { name = "raw-fish", epoch = 1, placement = { vanilla = "autoplace" } },
  { name = "water", epoch = 3, placement = { vanilla = "start" } }, { name = "crude-oil", epoch = 4, placement = { vanilla = "autoplace" } },
  { name = "fo-tungsten-ore", epoch = 5, existing = true, placement = { autoplace = "fo-volcanic-ash", guaranteed = { count = 1, distance = { 200, 500 },
      what_fr = "PROPOSÉ (lot X5) : un gisement de tungstène dans la zone de cendres garantie des fumerolles" } } },
  { name = "fo-resonance-crystal", epoch = 7, existing = true, placement = { autoplace = "fo-crystal-flats", guaranteed = { count = 1, distance = { 250, 600 },
      what_fr = "PROPOSÉ (lot X7) : une plaine de cristal posée par script si la graine n'en a pas à cette distance" } } },
  { name = "fo-methane", epoch = 8, existing = true, placement = { autoplace = "fo-toxic-marsh", guaranteed = { count = 2, distance = { 250, 700 },
      what_fr = "PROPOSÉ (lot X8) : 2 puits de méthane posés par script, même hors marais" } } },
  { name = "uranium-ore", epoch = 9, placement = { vanilla = "autoplace" } },
}

X.tiles = {
  { name = "fo-asphalt", epoch = 4, fr = "Asphalte", en = "Asphalt", walking_speed_modifier = 1.4, vehicle_friction_modifier = 0.6 },
  { name = "fo-crater-fields", epoch = 11, fr = "Champs de cratères", en = "Crater fields", biome = true },
  { name = "fo-black-sands", epoch = 12, fr = "Sables noirs", en = "Black sands", biome = true },
  { name = "fo-strange-ground", epoch = 13, fr = "Sol étrange", en = "Strange ground", hazard = "contagion" },
  { name = "fo-core-abyss", epoch = 15, fr = "Abysse du Cœur", en = "Core abyss" },
}

---------------------------------------------------------------------------------------------------
-- 6. Objets et fluides nouveaux.
--    use : "pack" (laboratoire), "data" (donnée de branche, laboratoire), "codex" (livré au centre),
--    "ammo", "armor", "tile", "consumable" (appliqué par script), "launch" (charge utile), "fuel".
--    material = true : matière en vrac, soumise à la règle MU ≥ 0,75 × rho.
--    stack = taille de pile (objets) ; par défaut selon l'usage (packs et munitions 200, Codex 10, charges
--    utiles et armures 1, combustibles et ρ32 50, le reste 100).
--    Fluides : barrel = auto_barrel (vrai par défaut en 1.1.91, vérifié) : le data-updates de base crée
--    alors un objet « baril de X » et deux recettes ; false pour ce qui doit rester local.
--    counter_only = true : produit d'une recette de silo, ignoré par le moteur (« Recipe products are
--    ignored ») : un compteur, pas un objet réel ; il n'entre pas dans le compte des objets.
---------------------------------------------------------------------------------------------------
--- Valeur en MU d'une unité de fluide extrait (convention du lot V2 : 10 unités de fluide = 1 MU) ; l'eau et
--- la vapeur ne portent aucune matière. Le banc s'en sert pour le calcul des MU (packs, monnaies).
X.FLUID_MU = 0.1
X.FREE_FLUIDS = { "water", "steam" }
local items = {}
local STACK_BY_USE = { pack = 200, data = 200, ammo = 200, codex = 10, launch = 1, armor = 1, tile = 100, consumable = 50 }
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

-- Époque 1
I("fo-biter-tissue", 1, "Tissu de déchiqueteur", "Biter tissue", { source = "loot" })
I("fo-codex-1", 1, "Codex I : journal du pionnier", "Codex I: pioneer's log", { use = "codex" })
-- Époque 2
I("fo-coke", 2, "Coke", "Coke", { material = true, rho = 1, fuel = 5, fuel_category = "chemical" })
I("fo-slag", 2, "Laitier", "Slag")
I("fo-cement", 2, "Ciment", "Cement", { material = true, rho = 1 })
I("fo-sand", 2, "Sable", "Sand")
I("fo-codex-2", 2, "Codex II : carnet de forge", "Codex II: forge book", { use = "codex" })
-- Époque 3
I("fo-glass", 3, "Verre", "Glass", { material = true, rho = 1 })
I("fo-manometer", 3, "Manomètre", "Pressure gauge")
I("fo-codex-3", 3, "Codex III : registre des chaudières", "Codex III: boiler register", { use = "codex" })
-- Époque 4
F("fo-ethylene", 4, "Éthylène", "Ethylene")
I("fo-asphalt", 4, "Asphalte", "Asphalt", { use = "tile" })
I("fo-codex-4", 4, "Codex IV : relevés de forage", "Codex IV: drilling records", { use = "codex" })
-- Époque 5
F("fo-volcanic-gas", 5, "Gaz volcanique", "Volcanic gas", { temperature = 300 })
I("fo-tungsten-carbide", 5, "Carbure de tungstène", "Tungsten carbide", { material = true, rho = 1 })
I("fo-carbide-bit", 5, "Trépan en carbure", "Carbide drill bit")
I("fo-geological-pack", 5, "Pack géologique", "Geological science pack", { use = "pack" })
I("fo-codex-5", 5, "Codex V : atlas des cendres", "Codex V: ash atlas", { use = "codex" })
-- Époque 6
I("fo-graphite", 6, "Graphite", "Graphite", { material = true, rho = 1 })
I("fo-magnetic-steel", 6, "Tôle magnétique", "Electrical steel", { material = true, rho = 1 })
I("fo-enameled-wire", 6, "Fil émaillé", "Enameled wire")
I("fo-coil", 6, "Bobine", "Coil")
I("fo-codex-6", 6, "Codex VI : schémas du réseau", "Codex VI: grid schematics", { use = "codex" })
-- Époque 7
I("fo-cut-crystal", 7, "Cristal taillé", "Cut crystal")
I("fo-crystal-powder", 7, "Poudre de cristal", "Crystal powder")
I("fo-resonance-lens", 7, "Lentille de résonance", "Resonance lens")
I("fo-crystal-oscillator", 7, "Oscillateur à cristal", "Crystal oscillator")
I("fo-resonance-pack", 7, "Pack de résonance", "Resonance science pack", { use = "pack" })
I("fo-charged-crystal", 7, "Cristal chargé", "Charged crystal",
  { fuel = 16, fuel_category = "fo-electric-storage", burnt = "fo-cut-crystal", storage = true })
I("fo-gravimetric-survey", 7, "Relevé gravimétrique", "Gravimetric survey", { use = "data", branch = "A", level = 1 })
I("fo-gravimetric-map", 7, "Carte gravimétrique", "Gravimetric map", { use = "consumable", branch = "A", level = 1,
  effect_fr = "révèle les veines de caustique et les gisements garantis dans un rayon de 8 chunks (script)" })
I("fo-codex-7", 7, "Codex VII : partitions du cristal", "Codex VII: crystal scores", { use = "codex" })
-- Époque 8
I("fo-swamp-sample", 8, "Échantillon de vase", "Swamp sample", { source = "gather" })
I("fo-methanotroph-culture", 8, "Culture méthanotrophe", "Methanotroph culture")
I("fo-biopolymer", 8, "Biopolymère", "Biopolymer")
I("fo-biochemical-pack", 8, "Pack biochimique", "Biochemical science pack", { use = "pack" })
F("fo-hydrogen", 8, "Hydrogène", "Hydrogen")
F("fo-oxygen", 8, "Oxygène", "Oxygen")
F("fo-carbon-dioxide", 8, "Dioxyde de carbone", "Carbon dioxide")
I("fo-codex-8", 8, "Codex VIII : herbier du marais", "Codex VIII: marsh herbarium", { use = "codex" })
-- Époque 9
I("fo-galena", 9, "Galène", "Galena", { source = "mining" })
I("fo-lead-plate", 9, "Plaque de plomb", "Lead plate", { material = true, rho = 1 })
I("fo-lead-shielding", 9, "Blindage plombé", "Lead shielding")
I("fo-isotopic-pack", 9, "Pack isotopique", "Isotopic science pack", { use = "pack" })
I("fo-activated-copper", 9, "Cuivre activé", "Activated copper", { branch = "B", level = 1 })
I("fo-magnetic-trap", 9, "Piège magnétique", "Magnetic trap", { branch = "B", level = 1 })
I("fo-positron-trap", 9, "Piège à positons", "Positron trap", { branch = "B", level = 1 })
I("fo-annihilation-data", 9, "Données d'annihilation", "Annihilation data", { use = "data", branch = "B", level = 1 })
I("fo-positron-grenade", 9, "Grenade à positons", "Positron grenade", { use = "ammo", branch = "B", level = 1,
  effect_fr = "capsule : 600 dégâts explosifs en rayon 5 (le piège est consommé)" })
I("fo-cooled-spent-cell", 9, "Cellule usée refroidie", "Cooled spent cell")
I("fo-vitrified-waste", 9, "Colis vitrifié", "Vitrified waste package")
I("fo-codex-9", 9, "Codex IX : cahier du réacteur", "Codex IX: reactor logbook", { use = "codex" })
-- Époque 10
I("fo-metallurgical-silicon", 10, "Silicium métallurgique", "Metallurgical silicon", { material = true, rho = 1 })
I("fo-pure-silicon", 10, "Silicium pur", "Pure silicon")
I("fo-silicon-wafer", 10, "Tranche de silicium", "Silicon wafer")
I("fo-unstable-time-crystal", 10, "Cristal temporel instable", "Unstable time crystal", { branch = "C", level = 1 })
I("fo-chronometric-data", 10, "Données chronométriques", "Chronometric data", { use = "data", branch = "C", level = 1 })
I("fo-iron-concentrate", 10, "Concentré de fer ρ8", "Iron concentrate ρ8", { material = true, rho = 8 })
I("fo-copper-concentrate", 10, "Concentré de cuivre ρ8", "Copper concentrate ρ8", { material = true, rho = 8 })
I("fo-tungsten-concentrate", 10, "Concentré de tungstène ρ8", "Tungsten concentrate ρ8", { material = true, rho = 8 })
I("fo-iron-plate-r8", 10, "Billette de fer ρ8", "Iron billet ρ8", { material = true, rho = 8 })
I("fo-copper-plate-r8", 10, "Billette de cuivre ρ8", "Copper billet ρ8", { material = true, rho = 8 })
I("fo-tungsten-plate-r8", 10, "Billette de tungstène ρ8", "Tungsten billet ρ8", { material = true, rho = 8 })
I("fo-codex-10", 10, "Codex X : plans de la salle blanche", "Codex X: cleanroom blueprints", { use = "codex" })
-- Époque 11
I("fo-ilmenite-ore", 11, "Minerai d'ilménite", "Ilmenite ore", { source = "mining" })
I("fo-ilmenite-concentrate", 11, "Concentré d'ilménite ρ8", "Ilmenite concentrate ρ8", { material = true, rho = 8 })
I("fo-titanium-slag", 11, "Laitier titanifère ρ8", "Titanium slag ρ8", { material = true, rho = 8 })
I("fo-titanium-sponge", 11, "Éponge de titane ρ8", "Titanium sponge ρ8", { material = true, rho = 8 })
I("fo-titanium-plate", 11, "Plaque de titane ρ8", "Titanium plate ρ8", { material = true, rho = 8 })
I("fo-caustic-soda", 11, "Soude caustique", "Caustic soda")
I("fo-magnesium-chloride", 11, "Chlorure de magnésium", "Magnesium chloride", { rho = 0.5 })
I("fo-magnesium", 11, "Magnésium", "Magnesium")
I("fo-titanium-composite", 11, "Composite titane", "Titanium composite")
I("fo-structural-pack", 11, "Pack structurel", "Structural science pack", { use = "pack" })
I("fo-cryostat", 11, "Cryostat", "Cryostat")
I("fo-strange-inclusion", 11, "Inclusion étrange", "Strange inclusion", { branch = "D", level = 1 })
I("fo-hadronic-data", 11, "Données hadroniques", "Hadronic data", { use = "data", branch = "D", level = 1 })
I("fo-inclusion-rounds", 11, "Chargeur à inclusion", "Inclusion rounds magazine", { use = "ammo", branch = "D", level = 1,
  effect_fr = "chargeur : dégâts de l'uranium + 20 % (inclusion dense)" })
I("fo-stable-time-crystal", 11, "Cristal temporel stable", "Stable time crystal", { branch = "C", level = 2 })
I("fo-quantum-hourglass", 11, "Sablier quantique", "Quantum hourglass", { use = "consumable", branch = "C", level = 2 })
F("fo-brine", 11, "Saumure", "Brine")
F("fo-chlorine", 11, "Chlore", "Chlorine")
F("fo-titanium-tetrachloride", 11, "Tétrachlorure de titane", "Titanium tetrachloride", { rho = 0.2 })
I("fo-codex-11", 11, "Codex XI : carte des cratères", "Codex XI: crater map", { use = "codex" })
-- Époque 12
I("fo-monazite-ore", 12, "Minerai de monazite", "Monazite ore", { source = "mining" })
I("fo-monazite-concentrate", 12, "Concentré de monazite ρ8", "Monazite concentrate ρ8", { material = true, rho = 8 })
I("fo-rare-earth-concentrate", 12, "Concentré de terres rares", "Rare earth concentrate")
I("fo-thorium-oxide", 12, "Oxyde de thorium", "Thorium oxide")
I("fo-neodymium", 12, "Néodyme", "Neodymium")
I("fo-yttrium", 12, "Yttrium", "Yttrium")
I("fo-superconducting-tape", 12, "Ruban supraconducteur", "Superconducting tape")
I("fo-permanent-magnet", 12, "Aimant permanent", "Permanent magnet")
I("fo-superconducting-coil", 12, "Bobine supraconductrice", "Superconducting coil")
I("fo-thorium-salt-cell", 12, "Cellule de sel au thorium", "Thorium salt cell",
  { fuel = 32000, fuel_category = "fo-thorium", burnt = "fo-spent-salt", whitelist_fr = "fission : source d'énergie primaire" })
I("fo-spent-salt", 12, "Sel usé", "Spent salt")
I("fo-magnetic-pack", 12, "Pack magnétique", "Magnetic science pack", { use = "pack" })
I("fo-smes-cell-empty", 12, "Cellule SMES vide", "Empty SMES cell")
I("fo-smes-cell", 12, "Cellule SMES chargée", "Charged SMES cell",
  { fuel = 400, fuel_category = "fo-electric-storage", burnt = "fo-smes-cell-empty", storage = true })
I("fo-resonance-cavity", 12, "Cavité de résonance", "Resonance cavity", { branch = "A", level = 2 })
I("fo-axion-condensate", 12, "Condensat d'axions", "Axion condensate",
  { branch = "A", level = 2, fuel = 120, fuel_category = "fo-axion", burnt = "fo-resonance-cavity" })
F("fo-liquid-nitrogen", 12, "Azote liquide", "Liquid nitrogen", { temperature = -196 })
F("fo-liquid-oxygen", 12, "Oxygène liquide", "Liquid oxygen", { temperature = -183 })
F("fo-helium", 12, "Hélium", "Helium")
F("fo-liquid-helium", 12, "Hélium liquide", "Liquid helium", { temperature = -269 })
F("fo-dark-flux", 12, "Flux sombre", "Dark flux", { branch = "A", level = 2, barrel = false })
I("fo-codex-12", 12, "Codex XII : traité des aimants", "Codex XII: treatise on magnets", { use = "codex" })
-- Époque 13
I("fo-degassed-ilmenite", 13, "Ilménite dégazée ρ8", "Degassed ilmenite ρ8", { material = true, rho = 8 })
I("fo-fusion-pellet", 13, "Pastille de fusion", "Fusion pellet",
  { fuel = 80000, fuel_category = "fo-fusion", whitelist_fr = "fusion : source d'énergie primaire" })
I("fo-catalyzed-fusion-pellet", 13, "Pastille de fusion catalysée", "Catalyzed fusion pellet",
  { fuel = 120000, fuel_category = "fo-fusion", branch = "B", level = 2,
    whitelist_fr = "fusion catalysée par l'antimatière : fiction déclarée (voir branche B)" })
I("fo-plasma-cell", 13, "Cellule de plasma", "Plasma cell")
I("fo-plasma-pack", 13, "Pack plasma", "Plasma science pack", { use = "pack" })
I("fo-antiproton-trap", 13, "Piège à antiprotons", "Antiproton trap", { branch = "B", level = 2 })
I("fo-antihydrogen-trap", 13, "Piège d'antihydrogène", "Antihydrogen trap",
  { branch = "B", level = 2, fuel = 50000, fuel_category = "fo-antimatter", burnt = "fo-magnetic-trap",
    whitelist_fr = "annihilation à rendement positif : fiction déclarée, rendue possible par la Caustique" })
I("fo-antimatter-microcharge", 13, "Micro-charge d'antimatière", "Antimatter microcharge", { branch = "B", level = 2, use = "ammo" })
I("fo-annihilation-shell", 13, "Obus d'annihilation", "Annihilation shell", { branch = "B", level = 2, use = "ammo" })
I("fo-confined-strangelet", 13, "Strangelet confiné", "Confined strangelet", { branch = "D", level = 2 })
I("fo-strange-plate", 13, "Plaque étrange", "Strange plate", { branch = "D", level = 2 })
I("fo-iron-block-r32", 13, "Bloc de fer ρ32", "Iron block ρ32", { material = true, rho = 32 })
I("fo-copper-block-r32", 13, "Bloc de cuivre ρ32", "Copper block ρ32", { material = true, rho = 32 })
F("fo-helium-3", 13, "Hélium-3", "Helium-3")
F("fo-heavy-water", 13, "Eau lourde", "Heavy water")
F("fo-deuterium", 13, "Deutérium", "Deuterium")
F("fo-plasma", 13, "Plasma", "Plasma", { default_temperature = 15, max_temperature = 5000, heat_capacity_kj = 1,
  heat_mj_per_unit = 4.985, barrel = true,
  barrel_fr = "baril permis : le plasma en baril retombe à 15 °C (sa chaleur est perdue, la turbine MHD n'en tire rien) ; il sert de matière aux failles et aux fonderies éloignées" })
I("fo-codex-13", 13, "Codex XIII : journal du confinement", "Codex XIII: confinement journal", { use = "codex" })
-- Époque 14
I("fo-ferrous-meteorite", 14, "Météorite ferreuse ρ8", "Ferrous meteorite ρ8", { material = true, rho = 8, source = "mining", stack = 200 })
I("fo-strange-meteorite", 14, "Météorite étrange ρ8", "Strange meteorite ρ8", { rho = 8, stack = 50 })
I("fo-nickel-iron", 14, "Ferronickel ρ8", "Nickel-iron ρ8", { material = true, rho = 8 })
I("fo-iridium", 14, "Iridium", "Iridium", { rho = 8, stack = 200, note_fr = "ρ8 : le métal le plus dense ; sa part de MU au concassage suit sa densité" })
I("fo-superalloy", 14, "Superalliage ρ32", "Superalloy ρ32", { material = true, rho = 32 })
I("fo-iridium-mirror", 14, "Miroir d'iridium", "Iridium mirror")
I("fo-cryogenic-propellant", 14, "Ergol cryogénique", "Cryogenic propellant")
I("fo-orbital-tug", 14, "Remorqueur orbital", "Orbital tug", { use = "launch" })
I("fo-orbital-solar-plant", 14, "Centrale solaire orbitale", "Orbital solar plant", { use = "launch" })
I("fo-deep-probe", 14, "Sonde profonde", "Deep probe", { use = "launch", branch = "B", level = 3 })
I("fo-strange-armor", 14, "Armure étrange", "Strange armor", { use = "armor", branch = "D", level = 3 })
F("fo-liquid-hydrogen", 14, "Hydrogène liquide", "Liquid hydrogen", { temperature = -253 })
I("fo-light-rocket-part", 14, "Pièce de lanceur léger", "Light launcher part", { counter_only = true,
  note_fr = "« pièce » du lanceur orbital : produit ignoré par le moteur, compté comme une pièce de fusée" })
I("fo-codex-14", 14, "Codex XIV : archives orbitales de l'Arche", "Codex XIV: the Ark's orbital archives", { use = "codex" })
-- Époque 15
F("fo-raw-exotic-matter", 15, "Matière exotique brute", "Raw exotic matter", { barrel = false })
I("fo-casimir-cavity", 15, "Cavité de Casimir", "Casimir cavity")
I("fo-stabilized-exotic-matter", 15, "Matière exotique stabilisée", "Stabilized exotic matter", { stack = 50 })
I("fo-exotic-pack", 15, "Pack exotique", "Exotic science pack", { use = "pack" })
I("fo-ring-segment", 15, "Segment d'anneau", "Ring segment", { counter_only = true, note_fr = "« pièce » de la Porte : produit ignoré par le moteur, compté comme une pièce de fusée" })
I("fo-phase-key", 15, "Clé de phase", "Phase key", { use = "launch" })

X.items = items

---------------------------------------------------------------------------------------------------
-- 7. Bâtiments nouveaux. Chaque bâtiment est aussi un objet (même nom), fabriqué par une recette.
--    proto = type de prototype 1.1 ; energy = { type, fuel_category } ; kw = consommation ;
--    fluid_in / fluid_out = boîtes de fluide de recette ; size = { largeur, hauteur } en tuiles.
---------------------------------------------------------------------------------------------------
local buildings = {}
local function B(o) buildings[#buildings + 1] = o; return o end
local ELEC = { type = "electric" }
local BURN = { type = "burner", fuel_category = "chemical" }
--- Niveaux (Q6, V2) : levels = { family = clé } : le bâtiment a sa propre chaîne de prototypes de niveau
--- (un prototype par niveau, ARCHITECTURE §7 bis), règles de statistiques et de coût de la famille V2 ou
--- de la famille proposée ; il NAÎT au premier niveau de son époque (first = 2e - 1) et monte jusqu'à 30.
--- levels = { none_fr = raison } : pièce sans niveau.
--- Familles V2 existantes : drill, furnace, assembler, wall (et gun, laser, command). Familles proposées
--- (E3-5) : process (procédés à fluides), lab, radar, energy (générateurs), special-turret, inserter.
local function LV(family) return { family = family } end
local function NOLV(reason) return { none_fr = reason } end
local NOLV_REACTOR = "puissance fixée par le bilan d'énergie P5 : un niveau changerait l'énergie tirée d'un combustible"
local NOLV_WONDER = "merveille : pièce unique, effet de force appliqué par script"
local NOLV_SCRIPT = "comportement porté par le script ; un niveau n'aurait pas d'effet propre"

B{ name = "fo-burner-assembler", epoch = 1, fr = "Atelier à combustion", en = "Burner workshop",
   proto = "assembling-machine", size = { 3, 3 }, energy = BURN, kw = 150, speed = 0.5,
   categories = { "crafting", "basic-crafting", "advanced-crafting" }, levels = LV("assembler") }
B{ name = "fo-burner-lab", epoch = 1, fr = "Laboratoire à combustion", en = "Burner laboratory",
   proto = "lab", size = { 3, 3 }, energy = BURN, kw = 120, speed = 0.5,
   inputs = { "automation-science-pack", "logistic-science-pack" }, levels = LV("lab") }
B{ name = "fo-coke-oven", epoch = 2, fr = "Four à coke", en = "Coke oven",
   proto = "assembling-machine", size = { 3, 3 }, energy = BURN, kw = 180, speed = 1, categories = { "fo-coking" }, levels = LV("furnace") }
B{ name = "fo-blast-furnace", epoch = 2, fr = "Haut fourneau", en = "Blast furnace",
   proto = "assembling-machine", size = { 4, 4 }, energy = BURN, kw = 600, speed = 1, categories = { "fo-blast-furnace" }, levels = LV("furnace") }
B{ name = "fo-crusher", epoch = 2, fr = "Concasseur", en = "Crusher",
   proto = "assembling-machine", size = { 2, 2 }, energy = BURN, kw = 120, speed = 1, categories = { "fo-crushing" }, levels = LV("assembler") }
B{ name = "fo-steam-hammer", epoch = 3, fr = "Marteau-pilon à vapeur", en = "Steam hammer",
   proto = "assembling-machine", size = { 3, 3 }, energy = { type = "fluid", fluid = "steam" }, kw = 900, speed = 1,
   categories = { "fo-forging" }, levels = LV("assembler") }
B{ name = "fo-steam-drill", epoch = 3, fr = "Foreuse à vapeur", en = "Steam drill",
   proto = "mining-drill", size = { 3, 3 }, energy = { type = "fluid", fluid = "steam" }, kw = 450, mining_speed = 0.75,
   resource_categories = { "basic-solid" }, levels = LV("drill") }
B{ name = "fo-flare-stack", epoch = 4, fr = "Torchère", en = "Flare stack",
   proto = "furnace", size = { 2, 2 }, energy = ELEC, kw = 50, speed = 1, categories = { "fo-flaring" }, fluid_in = 1,
   levels = NOLV("puits de fluide : aucun débit utile à améliorer") }
B{ name = "fo-steam-cracker", epoch = 4, fr = "Vapocraqueur", en = "Steam cracker",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 600, speed = 1, categories = { "fo-cracking" },
   fluid_in = 2, fluid_out = 1, levels = LV("process") }
B{ name = "fo-geothermal-tap", epoch = 5, fr = "Capteur géothermique", en = "Geothermal tap",
   proto = "mining-drill", size = { 3, 3 }, energy = ELEC, kw = 300, mining_speed = 1,
   resource_categories = { "fo-fumarole" }, output_fluid = true, levels = LV("drill") }
B{ name = "fo-sintering-furnace", epoch = 5, fr = "Four de frittage", en = "Sintering furnace",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 600, speed = 1, categories = { "fo-sintering" },
   fluid_in = 1, fluid_out = 1, levels = LV("furnace") }
B{ name = "fo-heavy-drill", epoch = 5, fr = "Foreuse lourde", en = "Heavy drill",
   proto = "mining-drill", size = { 3, 3 }, energy = ELEC, kw = 400, mining_speed = 1,
   resource_categories = { "basic-solid", "fo-hard-solid" }, levels = LV("drill") }
B{ name = "fo-arc-furnace", epoch = 6, fr = "Four à arc", en = "Arc furnace",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 4400, speed = 2, categories = { "fo-arc-smelting" },
   fluid_in = 1, levels = LV("furnace"), note_fr = "4,4 MW : 147 kJ/MU à 30 MU/s (BALANCE_SHEET §3, T4)" }
B{ name = "fo-coil-winder", epoch = 6, fr = "Bobineuse", en = "Coil winder",
   proto = "assembling-machine", size = { 2, 2 }, energy = ELEC, kw = 200, speed = 1, categories = { "fo-winding" },
   fluid_in = 1, levels = LV("assembler") }
B{ name = "fo-ht-pylon", epoch = 6, fr = "Pylône haute tension", en = "High-voltage pylon",
   proto = "electric-pole", size = { 2, 2 }, wire_distance = 64, supply_distance = 0.5,
   levels = NOLV("pylône : portée déjà au plafond moteur de 64") }
B{ name = "fo-jaw-crusher", epoch = 6, fr = "Broyeur à mâchoires", en = "Jaw crusher",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 500, speed = 2, categories = { "fo-crushing" }, levels = LV("assembler") }
B{ name = "fo-lapidary", epoch = 7, fr = "Taillerie", en = "Lapidary",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 400, speed = 1, categories = { "fo-lapidary" },
   fluid_in = 1, levels = LV("assembler") }
B{ name = "fo-resonance-amplifier", epoch = 7, fr = "Amplificateur de résonance", en = "Resonance amplifier",
   proto = "beacon", size = { 3, 3 }, energy = ELEC, kw = 600, slots = 3, distribution = 0.75, supply_distance = 3,
   levels = NOLV("balise : son effet vient des modules ; un niveau contournerait la règle des modules") }
B{ name = "fo-caustic-resonator", epoch = 7, fr = "Résonateur de caustique", en = "Caustic resonator",
   proto = "assembling-machine", size = { 2, 2 }, energy = ELEC, kw = 500, speed = 1, categories = { "fo-caustic-sensing" },
   fixed_recipe = "fo-gravimetric-survey", branch = "A", level = 1, rule_fr = "actif seulement à 64 tuiles au plus d'une veine",
   levels = LV("assembler") }
B{ name = "fo-charging-station", epoch = 7, fr = "Station de charge", en = "Charging station",
   proto = "assembling-machine", size = { 2, 2 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-charging" },
   levels = NOLV("rendement de charge fixé à 80 % par la règle d'énergie P5") }
B{ name = "fo-crystal-generator", epoch = 7, fr = "Générateur à cristal", en = "Crystal generator",
   proto = "burner-generator", size = { 2, 2 }, energy = { type = "burner", fuel_category = "fo-electric-storage" },
   burnt_inventory = true, output_kw = 1000, levels = LV("energy") }
B{ name = "fo-reformer", epoch = 8, fr = "Reformeur", en = "Reformer",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 1000, speed = 1, categories = { "fo-reforming" },
   fluid_in = 2, fluid_out = 2, levels = LV("process") }
B{ name = "fo-electrolyzer", epoch = 8, fr = "Électrolyseur", en = "Electrolyzer",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 3000, speed = 1, categories = { "fo-electrolysis" },
   fluid_in = 1, fluid_out = 2, levels = LV("process") }
B{ name = "fo-bioreactor", epoch = 8, fr = "Bioréacteur", en = "Bioreactor",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 300, speed = 1, categories = { "fo-bioprocessing" },
   fluid_in = 2, fluid_out = 1, levels = LV("process") }
B{ name = "fo-gas-turbine", epoch = 8, fr = "Turbine à gaz", en = "Gas turbine",
   proto = "generator", size = { 3, 5 }, burns_fluid = "fo-methane", output_kw = 10000, fluid_per_s = 6.7, levels = LV("energy") }
B{ name = "fo-irradiator", epoch = 9, fr = "Irradiateur", en = "Irradiator",
   proto = "assembling-machine", size = { 3, 3 }, energy = { type = "heat", min_temperature = 500, max_temperature = 1000 }, kw = 10000, speed = 1,
   heat_from = { "nuclear-reactor", "heat-pipe", "fo-ht-heat-pipe" },
   categories = { "fo-irradiation" }, branch = "B", level = 1, levels = LV("assembler") }
B{ name = "fo-positron-moderator", epoch = 9, fr = "Modérateur de positons", en = "Positron moderator",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 2000, speed = 1, categories = { "fo-positron" },
   branch = "B", level = 1, confinement = true, levels = LV("assembler") }
B{ name = "fo-cooling-pool", epoch = 9, fr = "Piscine d'entreposage", en = "Cooling pool",
   proto = "assembling-machine", size = { 4, 4 }, energy = { type = "void" }, kw = 0.001, speed = 1, categories = { "fo-cooling" },
   note_fr = "1 W : CraftingMachinePrototype.energy_usage doit être positif (vérifié), même avec une source void",
   levels = NOLV("stockage à durée fixe : le temps de refroidissement fait le jeu") }
B{ name = "fo-geological-repository", epoch = 9, fr = "Dépôt géologique", en = "Geological repository",
   proto = "container", size = { 6, 6 }, inventory = 200, levels = NOLV("coffre") }
B{ name = "fo-cleanroom", epoch = 10, fr = "Salle blanche", en = "Cleanroom",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 4000, speed = 1, categories = { "fo-cleanroom" },
   fluid_in = 1, levels = LV("assembler") }
B{ name = "fo-phased-array-radar", epoch = 10, fr = "Radar à réseau phasé", en = "Phased-array radar",
   proto = "radar", size = { 3, 3 }, energy = ELEC, kw = 1200, sector_range_factor = 3, levels = LV("radar") }
B{ name = "fo-ore-concentrator", epoch = 10, fr = "Concentrateur", en = "Ore concentrator",
   proto = "assembling-machine", size = { 2, 2 }, energy = ELEC, kw = 1500, speed = 3.75, categories = { "fo-concentrating" },
   rule_fr = "alimenté 1:1 en insertion directe par la foreuse de concentré (30 minerais/s → 3,75 concentrés/s) ; derrière des foreuses lourdes, par tapis (30 foreuses par concentrateur)",
   levels = LV("assembler") }
B{ name = "fo-concentrate-drill", epoch = 10, fr = "Foreuse de concentré", en = "Concentrate drill",
   proto = "mining-drill", size = { 5, 5 }, energy = ELEC, kw = 3000, mining_speed = 30,
   resource_categories = { "basic-solid", "fo-hard-solid" }, feeds = "fo-ore-concentrator", tier = 4,
   rule_fr = "sortie (vector_to_place_result) dans un concentrateur accolé : 30 MU/s par ensemble, 32 ensembles par tapis T4",
   levels = LV("drill") }
B{ name = "fo-phase-bench", epoch = 10, fr = "Banc de phase", en = "Phase bench",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 800, speed = 1, categories = { "fo-phase" },
   branch = "C", level = 1, levels = LV("assembler") }
B{ name = "fo-kroll-reactor", epoch = 11, fr = "Réacteur de Kroll", en = "Kroll reactor",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 2000, speed = 1, categories = { "fo-kroll" },
   fluid_in = 1, levels = LV("furnace") }
B{ name = "fo-titanium-pylon", epoch = 11, fr = "Pylône léger en titane", en = "Light titanium pylon",
   proto = "electric-pole", size = { 2, 2 }, wire_distance = 32, supply_distance = 9,
   rule_fr = "sous-station légère : fil 32, zone 18 × 18", levels = NOLV("pylône") }
B{ name = "fo-titanium-inserter", epoch = 11, fr = "Bras léger en titane", en = "Light titanium inserter",
   proto = "inserter", size = { 1, 1 }, energy = ELEC, kw = 60, rotation_speed = 0.06, stack_bonus = 12,
   rule_fr = "bras long rapide à pile (portée 2) : alimente les machines T4 sans bras empileur", levels = LV("inserter") }
B{ name = "fo-observation-tower", epoch = 11, fr = "Tour d'observation", en = "Observation tower",
   proto = "radar", size = { 2, 2 }, energy = ELEC, kw = 300, sector_range_factor = 0, nearby_chunks = 5,
   rule_fr = "vue rapprochée continue de 11 × 11 chunks, aucun balayage lointain : la sentinelle des avant-postes", levels = LV("radar") }
B{ name = "fo-inclusion-sorter", epoch = 11, fr = "Trieur d'inclusions", en = "Inclusion sorter",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 1500, speed = 1, categories = { "fo-sorting" },
   branch = "D", level = 1, levels = LV("assembler") }
B{ name = "fo-temporal-resonator", epoch = 11, fr = "Résonateur temporel", en = "Temporal resonator",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 8000, speed = 1, categories = { "fo-temporal" },
   fluid_in = 1, branch = "C", level = 2, levels = LV("assembler") }
B{ name = "fo-dilation-chamber", epoch = 11, fr = "Chambre de dilatation", en = "Dilation chamber",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 5000, speed = 1, categories = { "fo-dilation" },
   fixed_recipe = "fo-phase-maintenance", branch = "C", level = 2, aura_radius = 3,
   dilation = { speed = 1.0, consumption = 1.0 }, levels = NOLV("effet de zone réglé par la branche C : un niveau multiplierait la dilatation") }
B{ name = "fo-entangled-chest", epoch = 11, fr = "Coffre intriqué", en = "Entangled chest",
   proto = "linked-container", size = { 1, 1 }, inventory = 1, branch = "C", level = 2,
   rule_fr = "1 case ; 2 paires par force au niveau II, 4 au niveau III ; chaque paire active tire 20 MW (interface électrique cachée)",
   levels = NOLV("coffre") }
B{ name = "fo-cryogenic-unit", epoch = 12, fr = "Unité cryogénique", en = "Cryogenic unit",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 4000, speed = 1, categories = { "fo-cryogenics" },
   fluid_in = 2, fluid_out = 3, levels = LV("process") }
B{ name = "fo-extraction-column", epoch = 12, fr = "Colonne d'extraction", en = "Extraction column",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 500, speed = 1, categories = { "fo-solvent-extraction" },
   fluid_in = 1, levels = LV("process") }
B{ name = "fo-molten-salt-reactor", epoch = 12, fr = "Réacteur à sels fondus", en = "Molten salt reactor",
   proto = "reactor", size = { 5, 5 }, energy = { type = "burner", fuel_category = "fo-thorium" }, burnt_inventory = true,
   heat_kw = 160000, neighbour_bonus = 0, max_temperature = 1000, max_transfer_kw = 1000000, levels = NOLV(NOLV_REACTOR) }
B{ name = "fo-sc-accumulator", epoch = 12, fr = "Accumulateur supraconducteur", en = "Superconducting accumulator",
   proto = "accumulator", size = { 3, 3 }, buffer_mj = 200, flow_kw = 50000, levels = LV("energy") }
B{ name = "fo-maglev-locomotive", epoch = 12, fr = "Locomotive maglev", en = "Maglev locomotive",
   proto = "locomotive", size = { 2, 6 }, energy = { type = "burner", fuel_category = "fo-electric-storage" },
   burnt_inventory = true, max_speed_factor = 2, levels = NOLV("véhicule") }
B{ name = "fo-haloscope", epoch = 12, fr = "Haloscope", en = "Haloscope",
   proto = "mining-drill", size = { 5, 5 }, energy = ELEC, kw = 20000, mining_speed = 1,
   resource_categories = { "fo-caustic" }, output_fluid = true, branch = "A", level = 2, levels = LV("drill") }
B{ name = "fo-gravitic-condenser", epoch = 12, fr = "Condenseur gravitique", en = "Gravitic condenser",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 15000, speed = 1, categories = { "fo-gravitic" },
   fluid_in = 2, branch = "A", level = 2, levels = LV("assembler") }
B{ name = "fo-gravity-well", epoch = 12, fr = "Puits gravitique", en = "Gravity well",
   proto = "mining-drill", size = { 5, 5 }, energy = { type = "burner", fuel_category = "fo-axion" }, burnt_inventory = true,
   kw = 2000, mining_speed = 1, resource_categories = { "fo-deep" }, branch = "A", level = 2, levels = LV("drill") }
B{ name = "fo-isotope-column", epoch = 13, fr = "Colonne isotopique", en = "Isotope column",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 2000, speed = 1, categories = { "fo-isotope" },
   fluid_in = 1, fluid_out = 1, levels = LV("process") }
B{ name = "fo-fusion-reactor", epoch = 13, fr = "Réacteur à fusion", en = "Fusion reactor",
   proto = "reactor", size = { 7, 7 }, energy = { type = "burner", fuel_category = "fo-fusion" }, heat_kw = 800000,
   neighbour_bonus = 0, max_temperature = 5000, max_transfer_kw = 2000000, injectors = 4,
   rule_fr = "4 injecteurs en contact direct (un par face) ou par caloduc haute température", levels = NOLV(NOLV_REACTOR) }
B{ name = "fo-plasma-injector", epoch = 13, fr = "Injecteur de plasma", en = "Plasma injector",
   proto = "boiler", size = { 3, 3 }, energy = { type = "heat", min_temperature = 1000, max_temperature = 5000 }, kw = 200000,
   mode = "output-to-separate-pipe", output_fluid = "fo-plasma", input_fluid = "fo-hydrogen", target_temperature = 5000,
   heat_from = { "fo-fusion-reactor", "fo-annihilation-reactor", "fo-ht-heat-pipe" },
   rule_fr = "chaudière en mode « output-to-separate-pipe » (vérifié) : hydrogène → plasma 1:1, porté de 15 à 5 000 °C",
   levels = NOLV("débit réglé sur la chaleur du réacteur") }
B{ name = "fo-mhd-turbine", epoch = 13, fr = "Turbine MHD", en = "MHD turbine",
   proto = "generator", size = { 5, 5 }, output_kw = 200000, fluid_per_s = 40, fluid = "fo-plasma", maximum_temperature = 5000,
   rule_fr = "puissance = (min(T, 5 000) - 15) × 40/s × 1 kJ ≈ 200 MW ; un plasma retombé à 15 °C (baril) ne donne rien",
   levels = LV("energy") }
B{ name = "fo-ht-heat-pipe", epoch = 13, fr = "Caloduc haute température", en = "High-temperature heat pipe",
   proto = "heat-pipe", size = { 1, 1 }, max_temperature = 5000, max_transfer_kw = 2000000,
   rule_fr = "le caloduc vanilla plafonne à 1 000 °C : il ne peut pas alimenter un injecteur", levels = NOLV("caloduc") }
B{ name = "fo-plasma-foundry", epoch = 13, fr = "Fonderie à plasma", en = "Plasma foundry",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-plasma-casting" },
   fluid_in = 1, levels = LV("furnace") }
B{ name = "fo-deep-drill", epoch = 13, fr = "Foreuse profonde", en = "Deep drill",
   proto = "mining-drill", size = { 5, 5 }, energy = ELEC, kw = 5000, mining_speed = 1,
   resource_categories = { "fo-mantle" }, output_fluid = true, levels = LV("drill") }
B{ name = "fo-core-drill", epoch = 13, fr = "Foreuse de noyau", en = "Core drill",
   proto = "mining-drill", size = { 7, 7 }, energy = ELEC, kw = 8000, mining_speed = 120,
   resource_categories = { "basic-solid", "fo-hard-solid" }, feeds = "fo-plasma-foundry", tier = 5,
   rule_fr = "sortie dans une fonderie à plasma accolée (32 minerais + plasma → bloc ρ32) : 120 MU/s par ensemble, 32 par tapis T5",
   levels = LV("drill") }
B{ name = "fo-synchrotron", epoch = 13, fr = "Synchrotron", en = "Synchrotron",
   proto = "assembling-machine", size = { 9, 9 }, energy = ELEC, kw = 150000, speed = 1, categories = { "fo-synchrotron" },
   fluid_in = 1, branch = "B", level = 2, confinement = true, levels = LV("assembler") }
B{ name = "fo-recombiner", epoch = 13, fr = "Recombineur", en = "Recombiner",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-recombination" },
   branch = "B", level = 2, confinement = true, levels = LV("assembler") }
B{ name = "fo-hadron-compressor", epoch = 13, fr = "Compresseur hadronique", en = "Hadron compressor",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 100000, speed = 1, categories = { "fo-hadron" },
   fluid_in = 1, branch = "D", level = 2, levels = LV("assembler") }
B{ name = "fo-catalysis-vat", epoch = 13, fr = "Cuve de catalyse", en = "Catalysis vat",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 30000, speed = 1, categories = { "fo-catalysis" },
   branch = "D", level = 2, contagion = true, levels = LV("assembler") }
B{ name = "fo-transmuter", epoch = 13, fr = "Transmutateur", en = "Transmuter",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 15000, speed = 1, categories = { "fo-transmutation" },
   branch = "D", level = 2, levels = LV("assembler") }
B{ name = "fo-strange-wall", epoch = 13, fr = "Mur étrange", en = "Strange wall",
   proto = "wall", size = { 1, 1 }, hp = 12000, branch = "D", level = 2, levels = LV("wall") }
B{ name = "fo-rectenna", epoch = 14, fr = "Rectenna", en = "Rectenna",
   proto = "electric-energy-interface", size = { 6, 6 }, output_kw = 200000,
   rule_fr = "reçoit UNE centrale solaire orbitale (200 MW chacune) : power_production réglée par script (écriture vérifiée)",
   levels = NOLV(NOLV_SCRIPT) }
B{ name = "fo-deflector-shield", epoch = 14, fr = "Bouclier de déviation", en = "Deflector shield",
   proto = "electric-energy-interface", size = { 4, 4 }, kw = 30000, radius = 48, scripted = true,
   rule_fr = "consommation par power_usage (écriture vérifiée) ; déviation des météorites par script", levels = NOLV(NOLV_SCRIPT) }
B{ name = "fo-orbital-launcher", epoch = 14, fr = "Lanceur orbital", en = "Orbital launcher",
   proto = "rocket-silo", size = { 9, 9 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-light-launch" },
   fixed_recipe = "fo-light-rocket-part", rocket_parts_required = 10, result_inventory = 3,
   rule_fr = "lanceur léger pour les charges utiles du mod (10 pièces bon marché) ; le silo vanilla garde le satellite",
   levels = NOLV("silo : pièce unique de lancement") }
B{ name = "fo-gravity-well-2", epoch = 14, fr = "Puits gravitique II", en = "Gravity well II",
   proto = "mining-drill", size = { 5, 5 }, energy = { type = "burner", fuel_category = "fo-axion" }, burnt_inventory = true,
   kw = 4000, mining_speed = 4, resource_categories = { "fo-deep", "fo-deep-rare" }, branch = "A", level = 3, levels = LV("drill") }
B{ name = "fo-tidal-shield", epoch = 14, fr = "Bouclier de marée", en = "Tidal shield",
   proto = "electric-turret", size = { 4, 4 }, energy = ELEC, kw = 20000, radius = 30, slow = 0.7, branch = "A", level = 3,
   levels = LV("special-turret") }
B{ name = "fo-caustic-observatory", epoch = 14, fr = "Observatoire de la Caustique", en = "Caustic Observatory",
   proto = "simple-entity-with-owner", size = { 9, 9 }, wonder = true, branch = "A", level = 3,
   effect_fr = "+20 % de productivité minière (mining_drill_productivity_bonus) ; marée bloquée à 150 %", levels = NOLV(NOLV_WONDER) }
B{ name = "fo-annihilation-reactor", epoch = 14, fr = "Réacteur à annihilation", en = "Annihilation reactor",
   proto = "reactor", size = { 10, 10 }, energy = { type = "burner", fuel_category = "fo-antimatter" }, burnt_inventory = true,
   heat_kw = 2000000, neighbour_bonus = 0, max_temperature = 5000, max_transfer_kw = 4000000, injectors = 10,
   branch = "B", level = 3, confinement = true, confinement_kw = 20000,
   rule_fr = "10 injecteurs autour (32 connexions de chaleur au plus) ; confinement : interface électrique cachée de 20 MW sous le réacteur",
   levels = NOLV(NOLV_REACTOR) }
B{ name = "fo-annihilation-lance", epoch = 14, fr = "Lance d'annihilation", en = "Annihilation lance",
   proto = "ammo-turret", size = { 4, 4 }, ammo = "fo-antimatter-microcharge", damage = 20000, range = 60, branch = "B", level = 3,
   levels = LV("special-turret") }
B{ name = "fo-annihilation-bastion", epoch = 14, fr = "Bastion d'annihilation", en = "Annihilation Bastion",
   proto = "simple-entity-with-owner", size = { 9, 9 }, wonder = true, branch = "B", level = 3,
   effect_fr = "+30 % de dégâts des munitions explosives et d'annihilation (LuaForce.set_ammo_damage_modifier, vérifié)",
   levels = NOLV(NOLV_WONDER) }
B{ name = "fo-dilation-chamber-2", epoch = 14, fr = "Chambre de dilatation II", en = "Dilation chamber II",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-dilation" },
   fixed_recipe = "fo-phase-maintenance", branch = "C", level = 3, aura_radius = 3,
   dilation = { speed = 2.0, consumption = 2.5 }, levels = NOLV("effet de zone réglé par la branche C") }
B{ name = "fo-eternal-clock", epoch = 14, fr = "Horloge éternelle", en = "Eternal Clock",
   proto = "simple-entity-with-owner", size = { 9, 9 }, wonder = true, branch = "C", level = 3,
   effect_fr = "6e ouvrier (QX6), 2 sabliers par chantier au lieu de 1, laboratoires +50 % (laboratory_speed_modifier)",
   levels = NOLV(NOLV_WONDER) }
B{ name = "fo-neutronium-wall", epoch = 14, fr = "Mur de neutronium", en = "Neutronium wall",
   proto = "wall", size = { 1, 1 }, hp = 50000, branch = "D", level = 3, levels = LV("wall") }
B{ name = "fo-strange-monolith", epoch = 14, fr = "Monolithe étrange", en = "Strange Monolith",
   proto = "simple-entity-with-owner", size = { 9, 9 }, wonder = true, branch = "D", level = 3,
   effect_fr = "active les 4 recettes de transmutation résonante (40 pierres → 40 minerais) : LuaRecipe.enabled (écriture vérifiée)",
   levels = NOLV(NOLV_WONDER) }
B{ name = "fo-rift-anchor", epoch = 15, fr = "Ancre de faille", en = "Rift anchor",
   proto = "mining-drill", size = { 7, 7 }, energy = ELEC, kw = 100000, mining_speed = 1,
   resource_categories = { "fo-rift" }, output_fluid = true, input_fluid = true,
   fallback = { proto = "assembling-machine", categories = { "fo-rift-tapping" }, fixed_recipe = "fo-rift-tapping",
     rule_fr = "REPLI si la foreuse à entrée et sortie de fluide échoue en moteur (lot X15) : machine 7×7 à recette fixe (20 plasmas → 5 matières brutes/s), rendue active (LuaEntity.active, écriture vérifiée) seulement posée sur une faille ; la faille devient alors une ressource décorative non minable" },
   levels = NOLV("une ancre par faille : pièce de fin de partie") }
B{ name = "fo-casimir-stabilizer", epoch = 15, fr = "Stabilisateur de Casimir", en = "Casimir stabilizer",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 500000, speed = 1, categories = { "fo-casimir" },
   fluid_in = 1, levels = LV("assembler") }
B{ name = "fo-erebus-gate", epoch = 15, fr = "Porte d'Érèbe", en = "Erebus Gate",
   proto = "rocket-silo", size = { 10, 10 }, energy = ELEC, kw = 50000, speed = 1, categories = { "fo-gate" },
   fixed_recipe = "fo-ring-segment", rocket_parts_required = 100, result_inventory = 0, charge_minutes = 30, charge_kw = 5000000,
   rule_fr = "50 MW pendant la pose des segments ; la charge de 30 min tire 5 GW par une interface électrique cachée (power_usage, écriture vérifiée), lue toutes les 60 ticks : suspendue si l'énergie manque ; en cas d'échec, Porte debout : rocket_parts remis à 100 (écriture vérifiée)",
   levels = NOLV("pièce unique de fin de partie") }

for _, b in ipairs(buildings) do
  if b.levels and b.levels.family then b.levels.first = 2 * b.epoch - 1 end
end
X.buildings = buildings

--- Familles de niveaux (règles de statistiques et de coût). v2 = famille existante du lot V2 ; sinon
--- famille PROPOSÉE par X0 (E3-5) : le lot V2 décide de ses statistiques.
X.level_families = {
  { key = "drill", v2 = true, fr = "foreuses (V2 : vitesse de minage +10 %/niveau)" },
  { key = "furnace", v2 = true, fr = "fours (V2 : vitesse +8 %/niveau)" },
  { key = "assembler", v2 = true, fr = "machines d'assemblage (V2 : vitesse +8 %/niveau)" },
  { key = "wall", v2 = true, fr = "murs (V2 : PV +50 %/niveau)" },
  { key = "process", fr = "procédés à fluides (vitesse, comme l'assembleur)" },
  { key = "lab", fr = "laboratoires (vitesse de recherche)" },
  { key = "radar", fr = "radars (portée, cadence de balayage)" },
  { key = "energy", fr = "générateurs et stockage (débit ; jamais le rendement : règle P5)" },
  { key = "special-turret", fr = "tourelles spéciales (dégâts dégressifs, comme V2)" },
  { key = "inserter", fr = "bras (vitesse de rotation, pile)" },
}
--- Re-rangement des familles V2 vanilla (Q6 face aux époques) : RATTRAPAGE. Un bâtiment vanilla qui
--- arrive après l'époque 1 naît au niveau 1 et peut monter aussitôt jusqu'à 2 × époque du centre
--- (L.max_level de V2, inchangé) en payant les bandes antérieures avec leurs monnaies, déjà produites.
--- Aucun niveau n'est perdu ; les silhouettes des premières époques (bible V1) restent visibles pendant
--- ce rattrapage. Question au Directeur Créatif : QX8.
X.v2_family_epochs = {
  { family = "gun", base = "gun-turret", epoch = 1 }, { family = "wall", base = "stone-wall", epoch = 2 },
  { family = "furnace", base = "steel-furnace", epoch = 2 }, { family = "drill", base = "electric-mining-drill", epoch = 3 },
  { family = "assembler", base = "assembling-machine-2", epoch = 3 }, { family = "laser", base = "laser-turret", epoch = 6 },
  { family = "command", base = "fo-command-center", epoch = 1 },
}

---------------------------------------------------------------------------------------------------
-- 8. Machines vanilla (et centre existant) utiles au graphe : catégories et puissance, relevées dans
--    data/base/prototypes/entity/entities.lua et mining-drill.lua (1.1.91).
---------------------------------------------------------------------------------------------------
X.base_machines = {
  { name = "character", hand = true, categories = { "crafting" }, resource_categories = { "basic-solid" }, kw = 0, speed = 1, mining_speed = 0.5 },
  { name = "stone-furnace", categories = { "smelting" }, kw = 90, speed = 1, furnace = true },
  { name = "steel-furnace", categories = { "smelting" }, kw = 90, speed = 2, furnace = true },
  { name = "electric-furnace", categories = { "smelting" }, kw = 180, speed = 2, furnace = true },
  { name = "assembling-machine-1", categories = { "crafting", "basic-crafting", "advanced-crafting" }, kw = 75, speed = 0.5 },
  { name = "assembling-machine-2", categories = { "basic-crafting", "crafting", "advanced-crafting", "crafting-with-fluid" }, kw = 150, speed = 0.75, fluid_in = 1, fluid_out = 1 },
  { name = "assembling-machine-3", categories = { "basic-crafting", "crafting", "advanced-crafting", "crafting-with-fluid" }, kw = 375, speed = 1.25, fluid_in = 1, fluid_out = 1 },
  { name = "chemical-plant", categories = { "chemistry" }, kw = 210, speed = 1, fluid_in = 2, fluid_out = 2 },
  { name = "oil-refinery", categories = { "oil-processing" }, kw = 420, speed = 1, fluid_in = 2, fluid_out = 3 },
  { name = "centrifuge", categories = { "centrifuging" }, kw = 350, speed = 1 },
  { name = "rocket-silo", categories = { "rocket-building" }, kw = 4000, speed = 1, result_inventory = 1 },
  { name = "burner-mining-drill", resource_categories = { "basic-solid" }, mining_speed = 0.25 },
  { name = "electric-mining-drill", resource_categories = { "basic-solid", "fo-hard-solid" }, mining_speed = 0.5 },
  { name = "pumpjack", resource_categories = { "basic-fluid" }, output_fluid = true },
  { name = "offshore-pump" },
  { name = "boiler" },
  { name = "heat-exchanger" },
  { name = "heat-pipe", max_temperature = 1000 },
  { name = "nuclear-reactor", fuel_category = "nuclear", burnt_inventory = true, max_temperature = 1000 },
}

--- Combustibles déjà présents (MJ) : vanilla (item.lua) et mod (world.lua).
X.base_fuel = {
  { name = "wood", fuel = 2 }, { name = "coal", fuel = 4 }, { name = "solid-fuel", fuel = 12 },
  { name = "rocket-fuel", fuel = 100 }, { name = "nuclear-fuel", fuel = 1210 }, { name = "uranium-fuel-cell", fuel = 8000 },
  { name = "fo-resonance-crystal", fuel = 20 }, { name = "fo-methane", fuel = 1.5 },
}
X.base_fluids = { "water", "steam", "crude-oil", "heavy-oil", "light-oil", "petroleum-gas", "lubricant", "sulfuric-acid", "fo-methane" }

---------------------------------------------------------------------------------------------------
-- 9. Recettes. R(nom, époque, catégorie, durée, ingrédients, produits, options).
--    Ingrédient / produit : { nom, quantité [, catalyst = n] [, p = probabilité] }.
--    Options : kind ("recipe" par défaut ; "building" déduit ; "mining", "gather", "loot", "burn",
--    "launch", "heat", "sink" pour les pseudo-recettes, qui donnent alors machines = { ... }),
--    branch / level, dense (variantes ρ générées par le lot C), prod (productivité permise),
--    process ("compaction", "decompaction", "catalytic", "conversion", "transmutation"), whitelist_fr.
---------------------------------------------------------------------------------------------------
local recipes = {}
local function R(name, epoch, category, time, ingredients, results, o)
  o = o or {}
  o.name, o.epoch, o.category, o.time, o.ingredients, o.results = name, epoch, category, time, ingredients, results
  o.kind = o.kind or "recipe"
  recipes[#recipes + 1] = o
  return o
end
-- Le personnage mine à la main la catégorie basic-solid (entities.lua : mining_categories).
local DRILLS = { "character", "burner-mining-drill", "fo-steam-drill", "electric-mining-drill", "fo-heavy-drill", "fo-concentrate-drill", "fo-core-drill" }
local HARD_DRILLS = { "electric-mining-drill", "fo-heavy-drill", "fo-concentrate-drill", "fo-core-drill" }
local HAND = { "character" }

-- Époque 1 · Pionnier ------------------------------------------------------------------------------
R("fo-burner-assembler", 1, "crafting", 2, { { "iron-plate", 6 }, { "iron-gear-wheel", 5 }, { "stone-brick", 6 } }, { { "fo-burner-assembler", 1 } })
R("fo-burner-lab", 1, "crafting", 3, { { "iron-gear-wheel", 10 }, { "copper-cable", 10 }, { "stone-brick", 6 }, { "wood", 4 } }, { { "fo-burner-lab", 1 } })
R("fo-biter-tissue-loot", 1, nil, 1, {}, { { "fo-biter-tissue", 1, p = 0.02 } },
  { kind = "loot", machines = HAND, fr = "Butin : tissu de déchiqueteur", en = "Loot: biter tissue",
    note_fr = "EntityWithHealthPrototype.loot : 2 % (petit) à 8 % (primordial) ; nid 5 à 20" })
R("fo-codex-1", 1, "crafting", 30, { { "automation-science-pack", 10 }, { "electronic-circuit", 20 }, { "iron-plate", 20 }, { "stone-brick", 20 } }, { { "fo-codex-1", 1 } })

-- Époque 2 · Forge ---------------------------------------------------------------------------------
R("fo-coke-oven", 2, "crafting", 3, { { "stone-brick", 20 }, { "iron-plate", 10 } }, { { "fo-coke-oven", 1 } })
R("fo-crusher", 2, "crafting", 2, { { "iron-plate", 10 }, { "iron-gear-wheel", 10 }, { "stone-brick", 5 } }, { { "fo-crusher", 1 } })
R("fo-blast-furnace", 2, "crafting", 5, { { "stone-brick", 40 }, { "steel-plate", 10 }, { "iron-gear-wheel", 10 } }, { { "fo-blast-furnace", 1 } })
R("fo-coke", 2, "fo-coking", 4, { { "coal", 3 } }, { { "fo-coke", 2 } }, { dense = true, prod = true, fr = "Cokéfaction", en = "Coking" })
R("fo-blast-furnace-steel", 2, "fo-blast-furnace", 12, { { "iron-plate", 4 }, { "fo-coke", 1 } }, { { "steel-plate", 1 }, { "fo-slag", 1 } },
  { dense = true, fr = "Acier au haut fourneau", en = "Blast furnace steel" })
R("fo-slag-cement", 2, "fo-crushing", 2, { { "fo-slag", 2 }, { "stone", 1 } }, { { "fo-cement", 2 } }, { dense = true, fr = "Ciment de laitier", en = "Slag cement" })
R("fo-sand", 2, "fo-crushing", 1, { { "stone", 1 } }, { { "fo-sand", 2 } }, { dense = true, fr = "Sable", en = "Sand" })
R("fo-codex-2", 2, "crafting", 30, { { "steel-plate", 20 }, { "fo-cement", 20 }, { "logistic-science-pack", 10 }, { "fo-coke", 10 } }, { { "fo-codex-2", 1 } })

-- Époque 3 · Vapeur --------------------------------------------------------------------------------
R("fo-glass", 3, "smelting", 3.2, { { "fo-sand", 4 } }, { { "fo-glass", 1 } }, { dense = true, prod = true, fr = "Verre", en = "Glass" })
R("fo-manometer", 3, "crafting", 2, { { "fo-glass", 1 }, { "iron-gear-wheel", 1 }, { "pipe", 1 } }, { { "fo-manometer", 1 } }, { prod = true })
R("fo-steam-hammer", 3, "crafting", 5, { { "steel-plate", 10 }, { "pipe", 4 }, { "fo-manometer", 2 }, { "iron-gear-wheel", 10 } }, { { "fo-steam-hammer", 1 } })
R("fo-steam-drill", 3, "crafting", 4, { { "steel-plate", 10 }, { "pipe", 5 }, { "fo-manometer", 2 }, { "iron-gear-wheel", 10 } }, { { "fo-steam-drill", 1 } })
R("fo-forged-gear", 3, "fo-forging", 1, { { "iron-plate", 3 } }, { { "iron-gear-wheel", 2 } }, { prod = true, fr = "Engrenage forgé", en = "Forged gear" })
R("fo-cement-concrete", 3, "crafting-with-fluid", 10, { { "fo-cement", 4 }, { "fo-sand", 6 }, { "water", 50 } }, { { "concrete", 10 } },
  { dense = true, fr = "Béton au ciment", en = "Cement concrete" })
R("fo-codex-3", 3, "crafting", 30, { { "fo-manometer", 10 }, { "concrete", 20 }, { "military-science-pack", 10 }, { "fo-glass", 10 } }, { { "fo-codex-3", 1 } })

-- Époque 4 · Pétrole -------------------------------------------------------------------------------
R("fo-flare-stack", 4, "crafting", 3, { { "steel-plate", 10 }, { "pipe", 5 }, { "fo-manometer", 2 } }, { { "fo-flare-stack", 1 } })
R("fo-steam-cracker", 4, "crafting", 5, { { "steel-plate", 10 }, { "pipe", 10 }, { "fo-manometer", 5 }, { "electronic-circuit", 5 }, { "stone-brick", 20 } }, { { "fo-steam-cracker", 1 } })
R("fo-steam-cracking", 4, "fo-cracking", 2, { { "petroleum-gas", 30 }, { "steam", 20 } }, { { "fo-ethylene", 30 } }, { fr = "Vapocraquage", en = "Steam cracking" })
R("fo-polyethylene", 4, "chemistry", 1, { { "fo-ethylene", 20 }, { "coal", 1 } }, { { "plastic-bar", 3 } }, { prod = true, fr = "Polyéthylène", en = "Polyethylene" })
R("fo-asphalt", 4, "chemistry", 4, { { "heavy-oil", 10 }, { "fo-sand", 5 } }, { { "fo-asphalt", 10 } }, { fr = "Asphalte", en = "Asphalt" })
R("fo-codex-4", 4, "crafting", 30, { { "plastic-bar", 20 }, { "advanced-circuit", 10 }, { "chemical-science-pack", 10 }, { "fo-asphalt", 20 } }, { { "fo-codex-4", 1 } })

-- Époque 5 · Volcan --------------------------------------------------------------------------------
R("fo-geothermal-tap", 5, "crafting", 8, { { "fo-tungsten-plate", 10 }, { "pipe", 20 }, { "fo-manometer", 4 }, { "electronic-circuit", 5 } }, { { "fo-geothermal-tap", 1 } })
R("fo-capture-fumarole", 5, nil, 1, {}, { { "fo-volcanic-gas", 200 } },
  { kind = "mining", resource = "fo-fumarole", machines = { "fo-geothermal-tap" }, fr = "Captage : fumerolle", en = "Tapping: fumarole" })
R("fo-volcanic-gas-separation", 5, "chemistry", 1, { { "fo-volcanic-gas", 100 } }, { { "steam", 70 }, { "sulfur", 1 } },
  { fr = "Séparation du gaz volcanique", en = "Volcanic gas separation", note_fr = "vapeur produite à 165 °C" })
R("fo-sintering-furnace", 5, "crafting", 6, { { "stone-brick", 20 }, { "fo-tungsten-plate", 10 }, { "electronic-circuit", 10 }, { "concrete", 5 } }, { { "fo-sintering-furnace", 1 } })
R("fo-tungsten-carbide", 5, "fo-sintering", 8, { { "fo-tungsten-plate", 2 }, { "fo-coke", 1 } }, { { "fo-tungsten-carbide", 2 } }, { prod = true })
R("fo-carbide-bit", 5, "crafting", 4, { { "fo-tungsten-carbide", 1 }, { "steel-plate", 2 } }, { { "fo-carbide-bit", 1 } }, { prod = true })
R("fo-heavy-drill", 5, "crafting", 8, { { "electric-mining-drill", 1 }, { "fo-carbide-bit", 4 }, { "steel-plate", 10 }, { "engine-unit", 5 } }, { { "fo-heavy-drill", 1 } })
R("fo-geological-pack", 5, "crafting", 12, { { "fo-carbide-bit", 4 }, { "engine-unit", 2 }, { "sulfur", 2 }, { "stone", 4 } }, { { "fo-geological-pack", 2 } })
R("fo-codex-5", 5, "crafting", 30, { { "fo-tungsten-plate", 20 }, { "fo-tungsten-carbide", 10 }, { "fo-geological-pack", 10 }, { "fo-carbide-bit", 5 } }, { { "fo-codex-5", 1 } })

-- Époque 6 · Électricité ---------------------------------------------------------------------------
R("fo-arc-furnace", 6, "crafting", 10, { { "steel-plate", 20 }, { "concrete", 10 }, { "advanced-circuit", 10 }, { "copper-cable", 40 } }, { { "fo-arc-furnace", 1 } })
R("fo-coil-winder", 6, "crafting", 4, { { "steel-plate", 10 }, { "electronic-circuit", 5 }, { "iron-gear-wheel", 10 } }, { { "fo-coil-winder", 1 } })
R("fo-graphite", 6, "fo-arc-smelting", 6, { { "fo-coke", 4 } }, { { "fo-graphite", 3 } }, { dense = true, prod = true })
R("fo-arc-steel", 6, "fo-arc-smelting", 3, { { "iron-plate", 3 }, { "fo-graphite", 1 } }, { { "steel-plate", 1 } }, { dense = true, fr = "Acier électrique", en = "Electric steel" })
R("fo-magnetic-steel", 6, "fo-arc-smelting", 4, { { "steel-plate", 2 }, { "fo-sand", 1 } }, { { "fo-magnetic-steel", 2 } }, { dense = true, prod = true })
R("fo-enameled-wire", 6, "fo-winding", 2, { { "copper-cable", 2 }, { "plastic-bar", 1 } }, { { "fo-enameled-wire", 4 } }, { prod = true })
R("fo-coil", 6, "fo-winding", 3, { { "fo-enameled-wire", 4 }, { "fo-magnetic-steel", 2 } }, { { "fo-coil", 1 } }, { prod = true })
R("fo-ht-pylon", 6, "crafting", 2, { { "steel-plate", 10 }, { "copper-cable", 4 }, { "fo-coil", 2 } }, { { "fo-ht-pylon", 1 } })
R("fo-jaw-crusher", 6, "crafting", 4, { { "fo-crusher", 1 }, { "steel-plate", 10 }, { "fo-coil", 2 }, { "electronic-circuit", 5 } }, { { "fo-jaw-crusher", 1 } })
R("fo-wound-electric-engine", 6, "crafting-with-fluid", 10, { { "engine-unit", 1 }, { "fo-coil", 1 }, { "electronic-circuit", 2 }, { "lubricant", 10 } }, { { "electric-engine-unit", 1 } },
  { fr = "Moteur électrique bobiné", en = "Wound electric engine", variant_of = "electric-engine-unit" })
R("fo-codex-6", 6, "crafting", 30, { { "fo-coil", 10 }, { "battery", 20 }, { "production-science-pack", 10 }, { "fo-graphite", 10 } }, { { "fo-codex-6", 1 } })

-- Époque 7 · Cristal (A-I) -------------------------------------------------------------------------
R("fo-lapidary", 7, "crafting", 6, { { "fo-tungsten-plate", 10 }, { "fo-tungsten-carbide", 5 }, { "advanced-circuit", 10 }, { "fo-coil", 2 } }, { { "fo-lapidary", 1 } })
R("fo-crystal-cutting", 7, "fo-lapidary", 5, { { "fo-resonance-crystal", 2 }, { "water", 20 } }, { { "fo-cut-crystal", 1 }, { "fo-crystal-powder", 1 } },
  { fr = "Taille du cristal", en = "Crystal cutting" })
R("fo-resonance-lens", 7, "fo-lapidary", 6, { { "fo-cut-crystal", 1 }, { "fo-glass", 2 } }, { { "fo-resonance-lens", 1 } }, { prod = true })
R("fo-crystal-oscillator", 7, "crafting", 3, { { "fo-crystal-powder", 1 }, { "electronic-circuit", 1 }, { "fo-enameled-wire", 2 } }, { { "fo-crystal-oscillator", 2 } }, { prod = true })
R("fo-resonance-amplifier", 7, "crafting", 8, { { "beacon", 1 }, { "fo-resonance-lens", 4 }, { "fo-crystal-oscillator", 10 } }, { { "fo-resonance-amplifier", 1 } })
R("fo-resonance-pack", 7, "crafting", 14, { { "fo-resonance-lens", 1 }, { "fo-crystal-oscillator", 3 }, { "fo-coil", 3 }, { "advanced-circuit", 5 }, { "battery", 2 } }, { { "fo-resonance-pack", 1 } })
R("fo-caustic-resonator", 7, "crafting", 8, { { "fo-resonance-lens", 4 }, { "fo-crystal-oscillator", 10 }, { "radar", 1 }, { "fo-tungsten-plate", 10 } }, { { "fo-caustic-resonator", 1 } },
  { branch = "A", level = 1 })
R("fo-gravimetric-survey", 7, "fo-caustic-sensing", 30, { { "fo-crystal-oscillator", 2 } }, { { "fo-gravimetric-survey", 1 } },
  { branch = "A", level = 1, fr = "Relevé gravimétrique", en = "Gravimetric survey" })
R("fo-gravimetric-map", 7, "crafting", 10, { { "fo-gravimetric-survey", 5 }, { "radar", 1 } }, { { "fo-gravimetric-map", 1 } },
  { branch = "A", level = 1, fr = "Carte gravimétrique", en = "Gravimetric map" })
R("fo-charging-station", 7, "crafting", 6, { { "steel-plate", 10 }, { "fo-coil", 4 }, { "advanced-circuit", 5 }, { "accumulator", 2 } }, { { "fo-charging-station", 1 } })
R("fo-crystal-charging", 7, "fo-charging", 2, { { "fo-cut-crystal", 1 } }, { { "fo-charged-crystal", 1 } },
  { fr = "Charge du cristal", en = "Crystal charging", note_fr = "10 MW × 2 s = 20 MJ pour 16 MJ rendus (80 %)" })
R("fo-crystal-generator", 7, "crafting", 5, { { "steel-plate", 10 }, { "fo-coil", 5 }, { "fo-resonance-lens", 2 }, { "steam-engine", 1 } }, { { "fo-crystal-generator", 1 } })
R("fo-burn-charged-crystal", 7, nil, 16, { { "fo-charged-crystal", 1 } }, { { "fo-cut-crystal", 1 } },
  { kind = "burn", machines = { "fo-crystal-generator", "fo-maglev-locomotive" }, fr = "Décharge : cristal chargé", en = "Discharge: charged crystal" })
R("fo-codex-7", 7, "crafting", 30, { { "fo-resonance-lens", 5 }, { "fo-crystal-oscillator", 10 }, { "fo-resonance-pack", 10 }, { "fo-cut-crystal", 5 } }, { { "fo-codex-7", 1 } })

-- Époque 8 · Marais --------------------------------------------------------------------------------
R("fo-swamp-harvest", 8, nil, 1, {}, { { "wood", 4 }, { "fo-swamp-sample", 1, p = 0.3 } },
  { kind = "gather", machines = HAND, fr = "Abattage d'arbre des marais", en = "Swamp tree harvest",
    note_fr = "fo-marsh-tree et fo-marsh-snag (world.lua) : 30 % d'échantillon en plus du bois" })
R("fo-reformer", 8, "crafting", 6, { { "steel-plate", 15 }, { "pipe", 10 }, { "fo-tungsten-plate", 5 }, { "advanced-circuit", 5 } }, { { "fo-reformer", 1 } })
R("fo-electrolyzer", 8, "crafting", 8, { { "steel-plate", 10 }, { "fo-coil", 10 }, { "advanced-circuit", 10 }, { "plastic-bar", 10 } }, { { "fo-electrolyzer", 1 } })
R("fo-bioreactor", 8, "crafting", 5, { { "fo-glass", 10 }, { "steel-plate", 10 }, { "pipe", 5 }, { "electronic-circuit", 5 } }, { { "fo-bioreactor", 1 } })
R("fo-gas-turbine", 8, "crafting", 8, { { "steel-plate", 20 }, { "fo-tungsten-plate", 10 }, { "fo-coil", 5 }, { "electric-engine-unit", 2 } }, { { "fo-gas-turbine", 1 } })
R("fo-methane-reforming", 8, "fo-reforming", 2, { { "fo-methane", 50 }, { "steam", 100 } }, { { "fo-hydrogen", 200 }, { "fo-carbon-dioxide", 50 } },
  { fr = "Reformage du méthane", en = "Methane reforming" })
R("fo-water-electrolysis", 8, "fo-electrolysis", 2, { { "water", 100 } }, { { "fo-hydrogen", 100 }, { "fo-oxygen", 50 } },
  { fr = "Électrolyse de l'eau", en = "Water electrolysis" })
R("fo-culture-from-sample", 8, "fo-bioprocessing", 30, { { "fo-swamp-sample", 5 }, { "water", 50 } }, { { "fo-methanotroph-culture", 1 } },
  { fr = "Mise en culture (vase)", en = "Inoculation (swamp sample)" })
R("fo-culture-from-tissue", 8, "fo-bioprocessing", 30, { { "fo-biter-tissue", 5 }, { "water", 50 } }, { { "fo-methanotroph-culture", 1 } },
  { fr = "Mise en culture (tissu)", en = "Inoculation (biter tissue)" })
R("fo-culture-growth", 8, "fo-bioprocessing", 20, { { "fo-methanotroph-culture", 10, catalyst = 10 }, { "fo-methane", 100 }, { "water", 50 } },
  { { "fo-methanotroph-culture", 12, catalyst = 10 } }, { process = "catalytic", fr = "Croissance de la culture", en = "Culture growth" })
R("fo-biopolymer", 8, "fo-bioprocessing", 10, { { "fo-methanotroph-culture", 1 }, { "fo-methane", 60 }, { "fo-oxygen", 40 } },
  { { "fo-biopolymer", 4 }, { "fo-carbon-dioxide", 20 } }, { fr = "Biopolymère (PHB)", en = "Biopolymer (PHB)" })
R("fo-digester-methane", 8, "fo-bioprocessing", 20, { { "fo-biter-tissue", 10 }, { "water", 50 } }, { { "fo-methane", 60 } },
  { fr = "Méthane de digesteur", en = "Digester methane", whitelist_fr = "entrée = butin de combat, bornée par les attaques" })
R("fo-slag-carbonation", 8, "chemistry", 4, { { "fo-carbon-dioxide", 50 }, { "fo-slag", 2 } }, { { "fo-cement", 3 } },
  { fr = "Carbonatation du laitier", en = "Slag carbonation" })
R("fo-biochemical-pack", 8, "chemistry", 15, { { "fo-methanotroph-culture", 4 }, { "fo-biopolymer", 20 }, { "advanced-circuit", 4 }, { "sulfuric-acid", 20 } }, { { "fo-biochemical-pack", 1 } })
R("fo-codex-8", 8, "crafting", 30, { { "fo-biopolymer", 20 }, { "fo-methanotroph-culture", 5 }, { "fo-biochemical-pack", 10 } }, { { "fo-codex-8", 1 } })

-- Époque 9 · Atome (B-I) ---------------------------------------------------------------------------
R("fo-mine-galena", 9, nil, 1, {}, { { "fo-galena", 1 } }, { kind = "mining", resource = "fo-galena", machines = DRILLS, fr = "Minage : galène", en = "Mining: galena" })
R("fo-lead-plate", 9, "smelting", 3.2, { { "fo-galena", 2 } }, { { "fo-lead-plate", 1 } }, { dense = true, prod = true, fr = "Plomb", en = "Lead" })
R("fo-galena-roasting", 9, "fo-arc-smelting", 4, { { "fo-galena", 4 }, { "fo-oxygen", 20 } }, { { "fo-lead-plate", 3 }, { "sulfur", 1 } },
  { dense = true, fr = "Grillage de la galène", en = "Galena roasting" })
R("fo-lead-shielding", 9, "crafting", 3, { { "fo-lead-plate", 3 }, { "steel-plate", 1 } }, { { "fo-lead-shielding", 1 } }, { prod = true })
R("fo-isotopic-pack", 9, "crafting", 15, { { "fo-lead-shielding", 4 }, { "uranium-238", 4 }, { "fo-crystal-oscillator", 4 }, { "advanced-circuit", 6 } }, { { "fo-isotopic-pack", 1 } })
R("fo-irradiator", 9, "crafting", 10, { { "fo-lead-shielding", 20 }, { "heat-pipe", 20 }, { "advanced-circuit", 10 } }, { { "fo-irradiator", 1 } }, { branch = "B", level = 1 })
R("fo-positron-moderator", 9, "crafting", 10, { { "fo-lead-shielding", 10 }, { "fo-coil", 10 }, { "fo-tungsten-plate", 10 }, { "advanced-circuit", 10 } }, { { "fo-positron-moderator", 1 } },
  { branch = "B", level = 1 })
R("fo-copper-activation", 9, "fo-irradiation", 30, { { "copper-plate", 10 } }, { { "fo-activated-copper", 10 } },
  { branch = "B", level = 1, fr = "Activation du cuivre", en = "Copper activation" })
R("fo-magnetic-trap", 9, "crafting", 10, { { "fo-coil", 4 }, { "fo-lead-shielding", 2 }, { "advanced-circuit", 2 } }, { { "fo-magnetic-trap", 1 } }, { branch = "B", level = 1 })
R("fo-positron-capture", 9, "fo-positron", 60, { { "fo-activated-copper", 10 }, { "fo-magnetic-trap", 1 } }, { { "fo-positron-trap", 1 }, { "copper-plate", 10, back = true } },
  { branch = "B", level = 1, fr = "Capture de positons", en = "Positron capture" })
R("fo-controlled-annihilation", 9, "fo-positron", 20, { { "fo-positron-trap", 1 } }, { { "fo-magnetic-trap", 1, back = true }, { "fo-annihilation-data", 4 } },
  { branch = "B", level = 1, fr = "Annihilation contrôlée", en = "Controlled annihilation" })
R("fo-positron-grenade", 9, "crafting", 8, { { "fo-positron-trap", 1 }, { "grenade", 1 } }, { { "fo-positron-grenade", 1 } },
  { branch = "B", level = 1, fr = "Grenade à positons", en = "Positron grenade" })
R("fo-cooling-pool", 9, "crafting", 10, { { "concrete", 50 }, { "fo-lead-shielding", 20 }, { "pipe", 10 }, { "offshore-pump", 1 } }, { { "fo-cooling-pool", 1 } })
R("fo-spent-fuel-cooling", 9, "fo-cooling", 600, { { "used-up-uranium-fuel-cell", 10 } }, { { "fo-cooled-spent-cell", 10 } },
  { fr = "Refroidissement en piscine", en = "Pool cooling" })
R("fo-vitrification", 9, "fo-arc-smelting", 20, { { "fo-cooled-spent-cell", 2 }, { "fo-glass", 4 } }, { { "fo-vitrified-waste", 1 }, { "uranium-238", 1 } },
  { fr = "Vitrification", en = "Vitrification" })
R("fo-geological-repository", 9, "crafting", 10, { { "concrete", 100 }, { "fo-lead-shielding", 50 }, { "steel-plate", 20 } }, { { "fo-geological-repository", 1 } })
R("fo-codex-9", 9, "crafting", 30, { { "fo-lead-shielding", 20 }, { "uranium-fuel-cell", 2 }, { "fo-isotopic-pack", 10 } }, { { "fo-codex-9", 1 } })

-- Époque 10 · Haute technologie (C-I) --------------------------------------------------------------
R("fo-cleanroom", 10, "advanced-crafting", 15, { { "concrete", 50 }, { "steel-plate", 20 }, { "advanced-circuit", 20 }, { "fo-glass", 10 }, { "fo-coil", 10 } }, { { "fo-cleanroom", 1 } })
R("fo-metallurgical-silicon", 10, "fo-arc-smelting", 6, { { "fo-sand", 4 }, { "fo-graphite", 1 } }, { { "fo-metallurgical-silicon", 1 } }, { dense = true, prod = true })
R("fo-pure-silicon", 10, "chemistry", 8, { { "fo-metallurgical-silicon", 2 }, { "fo-hydrogen", 30 } }, { { "fo-pure-silicon", 1 } }, { prod = true })
R("fo-silicon-wafer", 10, "fo-cleanroom", 10, { { "fo-pure-silicon", 1 } }, { { "fo-silicon-wafer", 4 } }, { prod = true })
R("fo-cleanroom-processor", 10, "fo-cleanroom", 15, { { "electronic-circuit", 10 }, { "advanced-circuit", 2 }, { "fo-silicon-wafer", 1 }, { "sulfuric-acid", 5 } },
  { { "processing-unit", 2 } }, { prod = true, fr = "Processeur en salle blanche", en = "Cleanroom processor", variant_of = "processing-unit" })
R("fo-phased-array-radar", 10, "advanced-crafting", 10, { { "radar", 1 }, { "processing-unit", 10 }, { "fo-crystal-oscillator", 20 }, { "fo-magnetic-steel", 10 } }, { { "fo-phased-array-radar", 1 } })
R("fo-unstable-time-crystal", 10, "fo-cleanroom", 30, { { "fo-cut-crystal", 1 }, { "fo-silicon-wafer", 2 }, { "processing-unit", 1 } }, { { "fo-unstable-time-crystal", 1 } },
  { branch = "C", level = 1 })
R("fo-phase-bench", 10, "advanced-crafting", 10, { { "fo-crystal-oscillator", 20 }, { "processing-unit", 5 }, { "steel-plate", 20 }, { "fo-glass", 10 } }, { { "fo-phase-bench", 1 } },
  { branch = "C", level = 1 })
R("fo-phase-measurement", 10, "fo-phase", 20, { { "fo-unstable-time-crystal", 1 } }, { { "fo-chronometric-data", 4 }, { "fo-crystal-powder", 1 } },
  { branch = "C", level = 1, fr = "Mesure de phase", en = "Phase measurement" })
R("fo-clocked-phased-array-radar", 10, "fo-phase", 10, { { "radar", 1 }, { "processing-unit", 4 }, { "fo-unstable-time-crystal", 1 }, { "fo-magnetic-steel", 10 } },
  { { "fo-phased-array-radar", 1 } }, { branch = "C", level = 1, fr = "Radar à réseau phasé (horloge de phase)", en = "Phased-array radar (phase clock)",
    variant_of = "fo-phased-array-radar", note_fr = "usage hors recherche du niveau C-I : 4 processeurs au lieu de 10, 20 oscillateurs économisés" })
R("fo-ore-concentrator", 10, "advanced-crafting", 8, { { "steel-plate", 10 }, { "fo-coil", 4 }, { "processing-unit", 5 }, { "fo-tungsten-carbide", 10 } }, { { "fo-ore-concentrator", 1 } })
R("fo-concentrate-drill", 10, "advanced-crafting", 15, { { "fo-heavy-drill", 1 }, { "fo-carbide-bit", 10 }, { "processing-unit", 10 }, { "fo-coil", 10 }, { "steel-plate", 20 } },
  { { "fo-concentrate-drill", 1 } })
R("fo-iron-concentrate", 10, "fo-concentrating", 1, { { "iron-ore", 8 } }, { { "fo-iron-concentrate", 1 } }, { process = "compaction" })
R("fo-copper-concentrate", 10, "fo-concentrating", 1, { { "copper-ore", 8 } }, { { "fo-copper-concentrate", 1 } }, { process = "compaction" })
R("fo-tungsten-concentrate", 10, "fo-concentrating", 1, { { "fo-tungsten-ore", 8 } }, { { "fo-tungsten-concentrate", 1 } }, { process = "compaction" })
R("fo-iron-plate-r8", 10, "fo-arc-smelting", 0.533, { { "fo-iron-concentrate", 1 } }, { { "fo-iron-plate-r8", 1 } }, { dense = true, fr = "Fonte de concentré de fer", en = "Iron concentrate smelting" })
R("fo-copper-plate-r8", 10, "fo-arc-smelting", 0.533, { { "fo-copper-concentrate", 1 } }, { { "fo-copper-plate-r8", 1 } }, { dense = true, fr = "Fonte de concentré de cuivre", en = "Copper concentrate smelting" })
R("fo-tungsten-plate-r8", 10, "fo-arc-smelting", 1.066, { { "fo-tungsten-concentrate", 1 } }, { { "fo-tungsten-plate-r8", 1 } }, { dense = true, fr = "Fonte de concentré de tungstène", en = "Tungsten concentrate smelting" })
R("fo-iron-plate-r8-unpacking", 10, "crafting", 1, { { "fo-iron-plate-r8", 1 } }, { { "iron-plate", 8 } }, { process = "decompaction", fr = "Découpe de billette de fer", en = "Iron billet cutting" })
R("fo-copper-plate-r8-unpacking", 10, "crafting", 1, { { "fo-copper-plate-r8", 1 } }, { { "copper-plate", 8 } }, { process = "decompaction", fr = "Découpe de billette de cuivre", en = "Copper billet cutting" })
R("fo-tungsten-plate-r8-unpacking", 10, "crafting", 1, { { "fo-tungsten-plate-r8", 1 } }, { { "fo-tungsten-plate", 8 } }, { process = "decompaction", fr = "Découpe de billette de tungstène", en = "Tungsten billet cutting" })
R("fo-codex-10", 10, "crafting", 30, { { "processing-unit", 20 }, { "fo-silicon-wafer", 10 }, { "utility-science-pack", 10 } }, { { "fo-codex-10", 1 } })

-- Époque 11 · Titane (D-I ; C-II avancée : greffe « étaler les époques 12 à 14 ») -------------------
R("fo-mine-ilmenite", 11, nil, 2, {}, { { "fo-ilmenite-ore", 1 } }, { kind = "mining", resource = "fo-ilmenite", machines = HARD_DRILLS, fr = "Minage : ilménite", en = "Mining: ilmenite" })
R("fo-ilmenite-concentrate", 11, "fo-concentrating", 1, { { "fo-ilmenite-ore", 8 } }, { { "fo-ilmenite-concentrate", 1 } }, { process = "compaction" })
R("fo-pump-brine", 11, nil, 1, {}, { { "fo-brine", 10 } }, { kind = "mining", resource = "fo-brine", machines = { "pumpjack" }, fr = "Pompage : saumure", en = "Pumping: brine" })
R("fo-mine-breccia", 11, nil, 2, {}, { { "stone", 1 }, { "fo-strange-inclusion", 1, p = 0.005 } },
  { kind = "mining", resource = "fo-impact-breccia", machines = HARD_DRILLS, branch = "D", level = 1, fr = "Minage : brèche d'impact", en = "Mining: impact breccia" })
R("fo-kroll-reactor", 11, "advanced-crafting", 12, { { "steel-plate", 30 }, { "fo-tungsten-plate", 20 }, { "fo-coil", 10 }, { "processing-unit", 10 } }, { { "fo-kroll-reactor", 1 } })
R("fo-ilmenite-smelting", 11, "fo-arc-smelting", 1, { { "fo-ilmenite-concentrate", 2 }, { "fo-coke", 2 } }, { { "fo-titanium-slag", 1 }, { "iron-plate", 6 } },
  { dense = true, fr = "Fusion de l'ilménite", en = "Ilmenite smelting" })
R("fo-brine-electrolysis", 11, "fo-electrolysis", 3, { { "fo-brine", 100 } },
  { { "fo-chlorine", 40 }, { "fo-hydrogen", 40 }, { "fo-caustic-soda", 1 }, { "fo-magnesium-chloride", 1 } },
  { fr = "Électrolyse de la saumure", en = "Brine electrolysis" })
R("fo-chlorination", 11, "chemistry", 5, { { "fo-titanium-slag", 1 }, { "fo-coke", 1 }, { "fo-chlorine", 60 } }, { { "fo-titanium-tetrachloride", 40 } },
  { fr = "Chloration", en = "Chlorination" })
R("fo-kroll-reduction", 11, "fo-kroll", 0.5, { { "fo-titanium-tetrachloride", 40 }, { "fo-magnesium", 2 } }, { { "fo-titanium-sponge", 1 }, { "fo-magnesium-chloride", 2 } },
  { fr = "Réduction de Kroll", en = "Kroll reduction", note_fr = "boucle du magnésium fermée par l'électrolyse" })
R("fo-magnesium-electrolysis", 11, "fo-electrolysis", 3, { { "fo-magnesium-chloride", 1 } }, { { "fo-magnesium", 1 }, { "fo-chlorine", 15 } },
  { fr = "Électrolyse du chlorure de magnésium", en = "Magnesium chloride electrolysis" })
R("fo-titanium-plate", 11, "fo-arc-smelting", 0.533, { { "fo-titanium-sponge", 1 } }, { { "fo-titanium-plate", 1 } },
  { dense = true, prod = true, fr = "Refusion sous vide", en = "Vacuum arc remelting" })
R("fo-wet-tungsten", 11, "chemistry", 8, { { "fo-tungsten-ore", 5 }, { "fo-caustic-soda", 1 }, { "fo-hydrogen", 40 } }, { { "fo-tungsten-plate", 4 } },
  { dense = true, fr = "Tungstène par voie humide", en = "Hydrometallurgical tungsten" })
R("fo-cryostat", 11, "crafting", 10, { { "fo-titanium-plate", 1 }, { "fo-biopolymer", 2 }, { "processing-unit", 1 } }, { { "fo-cryostat", 1 } }, { prod = true })
R("fo-titanium-composite", 11, "crafting", 15, { { "fo-titanium-plate", 1 }, { "fo-biopolymer", 2 }, { "fo-graphite", 1 } }, { { "fo-titanium-composite", 2 } }, { prod = true })
R("fo-titanium-lds", 11, "crafting", 15, { { "fo-titanium-composite", 1 }, { "copper-plate", 4 } }, { { "low-density-structure", 2 } },
  { prod = true, fr = "Structure basse densité au titane", en = "Titanium low density structure", variant_of = "low-density-structure" })
R("fo-structural-pack", 11, "crafting", 20, { { "fo-titanium-composite", 4 }, { "fo-titanium-plate", 4 }, { "fo-tungsten-carbide", 4 }, { "processing-unit", 1 } }, { { "fo-structural-pack", 1 } })
R("fo-inclusion-sorter", 11, "advanced-crafting", 10, { { "fo-titanium-plate", 2 }, { "fo-jaw-crusher", 1 }, { "processing-unit", 5 }, { "fo-magnetic-steel", 10 } },
  { { "fo-inclusion-sorter", 1 } }, { branch = "D", level = 1 })
R("fo-inclusion-rounds", 11, "crafting", 10, { { "fo-strange-inclusion", 1 }, { "uranium-rounds-magazine", 10 } }, { { "fo-inclusion-rounds", 10 } },
  { branch = "D", level = 1, fr = "Chargeur à inclusion", en = "Inclusion rounds magazine" })
R("fo-inclusion-analysis", 11, "fo-sorting", 60, { { "fo-strange-inclusion", 1 }, { "processing-unit", 1 } }, { { "fo-hadronic-data", 4 } },
  { branch = "D", level = 1, fr = "Analyse d'inclusion", en = "Inclusion analysis" })
R("fo-temporal-resonator", 11, "advanced-crafting", 20, { { "fo-titanium-plate", 2 }, { "fo-cryostat", 1 }, { "fo-crystal-oscillator", 10 }, { "processing-unit", 10 } },
  { { "fo-temporal-resonator", 1 } }, { branch = "C", level = 2 })
R("fo-stable-time-crystal", 11, "fo-temporal", 80, { { "fo-unstable-time-crystal", 2 }, { "fo-crystal-oscillator", 4 } }, { { "fo-stable-time-crystal", 1 } },
  { branch = "C", level = 2, fr = "Cristal temporel stable (verrouillage de phase)", en = "Stable time crystal (phase locking)" })
R("fo-quantum-hourglass", 11, "fo-cleanroom", 30, { { "fo-stable-time-crystal", 1 }, { "fo-crystal-oscillator", 2 }, { "processing-unit", 1 }, { "fo-titanium-plate", 10 } }, { { "fo-quantum-hourglass", 1 } },
  { branch = "C", level = 2 })
R("fo-dilation-chamber", 11, "advanced-crafting", 20, { { "fo-resonance-amplifier", 1 }, { "fo-stable-time-crystal", 2 }, { "fo-coil", 10 }, { "fo-titanium-composite", 5 } },
  { { "fo-dilation-chamber", 1 } }, { branch = "C", level = 2 })
R("fo-phase-maintenance", 11, "fo-dilation", 120, { { "fo-stable-time-crystal", 1 } }, { { "fo-unstable-time-crystal", 1 } },
  { branch = "C", level = 2, fr = "Maintien de phase", en = "Phase maintenance", note_fr = "le cristal se déphase en travaillant" })
R("fo-entangled-chest", 11, "advanced-crafting", 20, { { "fo-stable-time-crystal", 2 }, { "fo-titanium-plate", 4 }, { "processing-unit", 5 } }, { { "fo-entangled-chest", 2 } },
  { branch = "C", level = 2 })
R("fo-titanium-pylon", 11, "crafting", 4, { { "fo-titanium-plate", 2 }, { "copper-cable", 10 }, { "advanced-circuit", 2 } }, { { "fo-titanium-pylon", 1 } })
R("fo-titanium-inserter", 11, "crafting", 2, { { "stack-inserter", 1 }, { "fo-titanium-plate", 1 }, { "fo-coil", 1 } }, { { "fo-titanium-inserter", 1 } })
R("fo-observation-tower", 11, "crafting", 6, { { "radar", 1 }, { "fo-titanium-composite", 4 }, { "fo-resonance-lens", 2 } }, { { "fo-observation-tower", 1 } })
R("fo-codex-11", 11, "crafting", 30, { { "fo-titanium-plate", 5 }, { "fo-titanium-composite", 10 }, { "fo-structural-pack", 10 } }, { { "fo-codex-11", 1 } })

-- Époque 12 · Supraconducteurs (A-II) --------------------------------------------------------------
R("fo-mine-monazite", 12, nil, 2, {}, { { "fo-monazite-ore", 1 } }, { kind = "mining", resource = "fo-monazite", machines = HARD_DRILLS, fr = "Minage : monazite", en = "Mining: monazite" })
R("fo-monazite-concentrate", 12, "fo-concentrating", 1, { { "fo-monazite-ore", 8 } }, { { "fo-monazite-concentrate", 1 } }, { process = "compaction" })
R("fo-cryogenic-unit", 12, "advanced-crafting", 15, { { "steel-plate", 40 }, { "fo-titanium-plate", 3 }, { "electric-engine-unit", 10 }, { "processing-unit", 10 }, { "pipe", 20 } }, { { "fo-cryogenic-unit", 1 } })
R("fo-extraction-column", 12, "advanced-crafting", 8, { { "fo-titanium-plate", 3 }, { "fo-glass", 10 }, { "pipe", 10 }, { "processing-unit", 5 } }, { { "fo-extraction-column", 1 } })
R("fo-monazite-leaching", 12, "chemistry", 8, { { "fo-monazite-concentrate", 1 }, { "sulfuric-acid", 20 } }, { { "fo-rare-earth-concentrate", 4 }, { "fo-thorium-oxide", 1 } },
  { fr = "Lessivage de la monazite", en = "Monazite leaching" })
R("fo-solvent-extraction", 12, "fo-solvent-extraction", 6, { { "fo-rare-earth-concentrate", 4 }, { "light-oil", 10 } }, { { "fo-neodymium", 2 }, { "fo-yttrium", 1 } },
  { fr = "Extraction par solvant", en = "Solvent extraction" })
R("fo-air-distillation", 12, "fo-cryogenics", 2, {}, { { "fo-liquid-nitrogen", 50 }, { "fo-liquid-oxygen", 15 } },
  { fr = "Distillation de l'air", en = "Air distillation", note_fr = "recette sans ingrédient : l'air est partout" })
R("fo-cryogenic-gas-separation", 12, "fo-cryogenics", 1, { { "fo-volcanic-gas", 100 }, { "fo-liquid-nitrogen", 10 } }, { { "steam", 70 }, { "sulfur", 1 }, { "fo-helium", 5 } },
  { fr = "Séparation cryogénique du gaz volcanique", en = "Cryogenic volcanic gas separation" })
R("fo-helium-liquefaction", 12, "fo-cryogenics", 4, { { "fo-helium", 20 }, { "fo-liquid-nitrogen", 20 } }, { { "fo-liquid-helium", 10 } },
  { fr = "Liquéfaction de l'hélium", en = "Helium liquefaction" })
R("fo-superconducting-tape", 12, "fo-sintering", 6, { { "fo-yttrium", 1 }, { "copper-plate", 3 }, { "fo-oxygen", 20 } }, { { "fo-superconducting-tape", 4 } },
  { prod = true, fr = "Ruban supraconducteur (YBCO)", en = "Superconducting tape (YBCO)" })
R("fo-permanent-magnet", 12, "fo-sintering", 6, { { "fo-neodymium", 1 }, { "iron-plate", 2 } }, { { "fo-permanent-magnet", 2 } },
  { prod = true, fr = "Aimant permanent (NdFeB)", en = "Permanent magnet (NdFeB)" })
R("fo-superconducting-coil", 12, "fo-winding", 10, { { "fo-superconducting-tape", 4 }, { "fo-cryostat", 1 }, { "fo-liquid-nitrogen", 20 } }, { { "fo-superconducting-coil", 1 } }, { prod = true })
R("fo-thorium-salt-cell", 12, "chemistry", 20, { { "fo-thorium-oxide", 4 }, { "uranium-235", 1 }, { "fo-chlorine", 20 } }, { { "fo-thorium-salt-cell", 1 } })
R("fo-burn-thorium-salt", 12, nil, 200, { { "fo-thorium-salt-cell", 1 } }, { { "fo-spent-salt", 1 } },
  { kind = "burn", machines = { "fo-molten-salt-reactor" }, fr = "Combustion : sel au thorium (160 MW)", en = "Burning: thorium salt (160 MW)" })
R("fo-salt-reprocessing", 12, "centrifuging", 30, { { "fo-spent-salt", 2 } }, { { "fo-thorium-oxide", 1 }, { "uranium-238", 1 } },
  { fr = "Retraitement du sel", en = "Salt reprocessing" })
R("fo-molten-salt-reactor", 12, "advanced-crafting", 60, { { "fo-lead-shielding", 200 }, { "fo-titanium-plate", 10 }, { "processing-unit", 50 }, { "concrete", 100 } }, { { "fo-molten-salt-reactor", 1 } })
R("fo-sc-accumulator", 12, "advanced-crafting", 10, { { "fo-superconducting-coil", 4 }, { "accumulator", 10 }, { "fo-cryostat", 2 } }, { { "fo-sc-accumulator", 1 } })
R("fo-maglev-locomotive", 12, "advanced-crafting", 20, { { "locomotive", 1 }, { "fo-permanent-magnet", 8 }, { "fo-superconducting-coil", 4 }, { "fo-titanium-composite", 10 } }, { { "fo-maglev-locomotive", 1 } })
R("fo-smes-cell-empty", 12, "crafting", 10, { { "fo-superconducting-coil", 2 }, { "fo-cryostat", 1 }, { "fo-titanium-plate", 1 } }, { { "fo-smes-cell-empty", 1 } })
R("fo-smes-charging", 12, "fo-charging", 50, { { "fo-smes-cell-empty", 1 } }, { { "fo-smes-cell", 1 } },
  { fr = "Charge de cellule SMES", en = "SMES cell charging", note_fr = "10 MW × 50 s = 500 MJ pour 400 MJ rendus (80 %)" })
R("fo-burn-smes-cell", 12, nil, 1, { { "fo-smes-cell", 1 } }, { { "fo-smes-cell-empty", 1 } },
  { kind = "burn", machines = { "fo-maglev-locomotive", "fo-crystal-generator" }, fr = "Décharge : cellule SMES", en = "Discharge: SMES cell" })
R("fo-magnetic-pack", 12, "crafting", 20, { { "fo-superconducting-coil", 2 }, { "fo-permanent-magnet", 4 }, { "fo-titanium-plate", 2 }, { "processing-unit", 1 } }, { { "fo-magnetic-pack", 1 } })
R("fo-haloscope", 12, "advanced-crafting", 30, { { "fo-superconducting-coil", 4 }, { "fo-cryostat", 2 }, { "fo-resonance-lens", 10 }, { "processing-unit", 20 }, { "fo-titanium-plate", 5 } },
  { { "fo-haloscope", 1 } }, { branch = "A", level = 2 })
R("fo-capture-caustic-vein", 12, nil, 1, {}, { { "fo-dark-flux", 20 } },
  { kind = "mining", resource = "fo-caustic-vein", machines = { "fo-haloscope" }, branch = "A", level = 2,
    fr = "Captage : veine de caustique", en = "Tapping: caustic vein", note_fr = "rendement modulé par la marée (X.tide)" })
R("fo-gravitic-condenser", 12, "advanced-crafting", 20, { { "fo-superconducting-coil", 4 }, { "fo-cut-crystal", 20 }, { "processing-unit", 10 }, { "fo-cryostat", 2 } },
  { { "fo-gravitic-condenser", 1 } }, { branch = "A", level = 2 })
R("fo-resonance-cavity", 12, "crafting", 15, { { "fo-resonance-lens", 2 }, { "fo-superconducting-coil", 1 }, { "fo-cryostat", 1 } }, { { "fo-resonance-cavity", 1 } },
  { branch = "A", level = 2 })
R("fo-axion-condensation", 12, "fo-gravitic", 20, { { "fo-dark-flux", 200 }, { "fo-resonance-cavity", 1 }, { "fo-liquid-helium", 5 } }, { { "fo-axion-condensate", 1 } },
  { branch = "A", level = 2, fr = "Condensation d'axions", en = "Axion condensation" })
R("fo-condensate-survey", 12, "fo-gravitic", 10, { { "fo-axion-condensate", 1 } }, { { "fo-resonance-cavity", 1, back = true }, { "fo-gravimetric-survey", 10 } },
  { branch = "A", level = 2, fr = "Relevé de condensat", en = "Condensate survey" })
R("fo-gravity-well", 12, "advanced-crafting", 30, { { "fo-heavy-drill", 1 }, { "fo-axion-condensate", 4 }, { "fo-superconducting-coil", 10 }, { "fo-titanium-composite", 20 } },
  { { "fo-gravity-well", 1 } }, { branch = "A", level = 2 })
R("fo-burn-axion-condensate", 12, nil, 60, { { "fo-axion-condensate", 1 } }, { { "fo-resonance-cavity", 1 } },
  { kind = "burn", machines = { "fo-gravity-well", "fo-gravity-well-2" }, branch = "A", level = 2,
    fr = "Combustion : condensat (puits, 2 MW)", en = "Burning: condensate (well, 2 MW)" })
R("fo-upwelling-iron", 12, nil, 1, {}, { { "fo-iron-concentrate", 1 } },
  { kind = "mining", resource = "fo-deep-upwelling-iron", machines = { "fo-gravity-well", "fo-gravity-well-2" }, branch = "A", level = 2, fr = "Remontée profonde : fer", en = "Deep upwelling: iron" })
R("fo-upwelling-copper", 12, nil, 1, {}, { { "fo-copper-concentrate", 1 } },
  { kind = "mining", resource = "fo-deep-upwelling-copper", machines = { "fo-gravity-well", "fo-gravity-well-2" }, branch = "A", level = 2, fr = "Remontée profonde : cuivre", en = "Deep upwelling: copper" })
R("fo-stable-time-crystal-cryo", 12, "fo-temporal", 40, { { "fo-unstable-time-crystal", 2 }, { "fo-liquid-helium", 5 } }, { { "fo-stable-time-crystal", 1 } },
  { branch = "C", level = 2, fr = "Cristal temporel stable (hélium liquide)", en = "Stable time crystal (liquid helium)" })
R("fo-codex-12", 12, "crafting", 30, { { "fo-superconducting-coil", 5 }, { "fo-permanent-magnet", 10 }, { "fo-magnetic-pack", 10 } }, { { "fo-codex-12", 1 } })

-- Époque 13 · Fusion (B-II, D-II) ------------------------------------------------------------------
R("fo-isotope-column", 13, "advanced-crafting", 10, { { "steel-plate", 20 }, { "fo-titanium-plate", 2 }, { "pipe", 10 }, { "processing-unit", 5 } }, { { "fo-isotope-column", 1 } })
R("fo-fusion-reactor", 13, "advanced-crafting", 120,
  { { "fo-superconducting-coil", 200 }, { "fo-titanium-composite", 100 }, { "fo-cryostat", 100 }, { "fo-lead-shielding", 200 }, { "concrete", 500 } }, { { "fo-fusion-reactor", 1 } })
R("fo-plasma-injector", 13, "advanced-crafting", 20, { { "fo-superconducting-coil", 10 }, { "fo-tungsten-plate", 10 }, { "heat-pipe", 10 } }, { { "fo-plasma-injector", 1 } })
R("fo-mhd-turbine", 13, "advanced-crafting", 20, { { "fo-permanent-magnet", 20 }, { "fo-superconducting-coil", 10 }, { "fo-tungsten-plate", 20 }, { "fo-titanium-composite", 20 } }, { { "fo-mhd-turbine", 1 } })
R("fo-plasma-foundry", 13, "advanced-crafting", 30, { { "fo-tungsten-plate", 50 }, { "fo-superconducting-coil", 20 }, { "concrete", 20 }, { "processing-unit", 10 } }, { { "fo-plasma-foundry", 1 } })
R("fo-deep-drill", 13, "advanced-crafting", 20, { { "fo-heavy-drill", 1 }, { "fo-tungsten-carbide", 20 }, { "fo-superconducting-coil", 10 }, { "processing-unit", 10 } }, { { "fo-deep-drill", 1 } })
R("fo-capture-mantle-vent", 13, nil, 1, {}, { { "fo-helium-3", 4 } },
  { kind = "mining", resource = "fo-mantle-vent", machines = { "fo-deep-drill" }, fr = "Captage : évent mantellique", en = "Tapping: mantle vent" })
R("fo-regolith-degassing", 13, "fo-sintering", 0.267, { { "fo-ilmenite-concentrate", 1 } }, { { "fo-degassed-ilmenite", 1 }, { "fo-helium-3", 0.1 } },
  { fr = "Dégazage du régolithe", en = "Regolith degassing" })
R("fo-degassed-ilmenite-smelting", 13, "fo-arc-smelting", 1, { { "fo-degassed-ilmenite", 2 }, { "fo-coke", 2 } }, { { "fo-titanium-slag", 1 }, { "iron-plate", 6 } },
  { dense = true, fr = "Fusion de l'ilménite dégazée", en = "Degassed ilmenite smelting" })
R("fo-helium-isotope-distillation", 13, "fo-cryogenics", 5, { { "fo-helium", 100, catalyst = 90 }, { "fo-liquid-nitrogen", 10 } },
  { { "fo-helium", 90, catalyst = 90 }, { "fo-helium-3", 1 } },
  { process = "catalytic", fr = "Distillation isotopique de l'hélium", en = "Helium isotope distillation" })
R("fo-heavy-water", 13, "fo-isotope", 10, { { "water", 1000 } }, { { "fo-heavy-water", 10 } }, { fr = "Eau lourde (procédé Girdler)", en = "Heavy water (Girdler process)" })
R("fo-heavy-water-electrolysis", 13, "fo-electrolysis", 2, { { "fo-heavy-water", 100 } }, { { "fo-deuterium", 100 }, { "fo-oxygen", 50 } },
  { fr = "Électrolyse de l'eau lourde", en = "Heavy water electrolysis" })
R("fo-fusion-pellet", 13, "fo-cryogenics", 10, { { "fo-deuterium", 50 }, { "fo-helium-3", 50 }, { "fo-titanium-composite", 1 } }, { { "fo-fusion-pellet", 1 } })
R("fo-burn-fusion-pellet", 13, nil, 100, { { "fo-fusion-pellet", 1 } }, {},
  { kind = "burn", machines = { "fo-fusion-reactor" }, fr = "Combustion : pastille (800 MW)", en = "Burning: pellet (800 MW)" })
R("fo-plasma-ionization", 13, nil, 1, { { "fo-hydrogen", 40 } }, { { "fo-plasma", 40 } },
  { kind = "heat", machines = { "fo-plasma-injector" }, fr = "Ionisation (injecteur)", en = "Ionization (injector)",
    note_fr = "chaudière à source de chaleur ≥ 1 000 °C : 200 MW chauffent 40 unités/s de 15 à 5 000 °C (capacité 1 kJ/°C) ; non vérifié en moteur" })
R("fo-plasma-cell", 13, "fo-plasma-casting", 5, { { "fo-permanent-magnet", 1 }, { "fo-titanium-composite", 1 }, { "fo-plasma", 50 } }, { { "fo-plasma-cell", 1 } }, { prod = true })
R("fo-plasma-pack", 13, "crafting", 25, { { "fo-plasma-cell", 2 }, { "fo-superconducting-coil", 2 }, { "processing-unit", 2 } }, { { "fo-plasma-pack", 1 } })
R("fo-iron-block-r32", 13, "fo-plasma-casting", 0.267, { { "fo-iron-concentrate", 4 }, { "fo-plasma", 0.5 } }, { { "fo-iron-block-r32", 1 } },
  { dense = true, fr = "Coulée de bloc de fer", en = "Iron block casting" })
R("fo-copper-block-r32", 13, "fo-plasma-casting", 0.267, { { "fo-copper-concentrate", 4 }, { "fo-plasma", 0.5 } }, { { "fo-copper-block-r32", 1 } },
  { dense = true, fr = "Coulée de bloc de cuivre", en = "Copper block casting" })
R("fo-iron-ore-casting", 13, "fo-plasma-casting", 0.267, { { "iron-ore", 32 }, { "fo-plasma", 0.5 } }, { { "fo-iron-block-r32", 1 } },
  { fr = "Coulée directe de minerai de fer", en = "Direct iron ore casting", note_fr = "alimentée par la foreuse de noyau en insertion directe (T5)" })
R("fo-copper-ore-casting", 13, "fo-plasma-casting", 0.267, { { "copper-ore", 32 }, { "fo-plasma", 0.5 } }, { { "fo-copper-block-r32", 1 } },
  { fr = "Coulée directe de minerai de cuivre", en = "Direct copper ore casting" })
R("fo-core-drill", 13, "advanced-crafting", 30, { { "fo-concentrate-drill", 1 }, { "fo-superconducting-coil", 20 }, { "fo-tungsten-carbide", 40 }, { "processing-unit", 20 } },
  { { "fo-core-drill", 1 } })
R("fo-ht-heat-pipe", 13, "crafting", 2, { { "heat-pipe", 1 }, { "fo-tungsten-plate", 4 }, { "fo-superconducting-tape", 1 } }, { { "fo-ht-heat-pipe", 1 } })
R("fo-iron-block-unpacking", 13, "crafting", 1, { { "fo-iron-block-r32", 1 } }, { { "fo-iron-plate-r8", 4 } }, { process = "decompaction", fr = "Découpe de bloc de fer", en = "Iron block cutting" })
R("fo-copper-block-unpacking", 13, "crafting", 1, { { "fo-copper-block-r32", 1 } }, { { "fo-copper-plate-r8", 4 } }, { process = "decompaction", fr = "Découpe de bloc de cuivre", en = "Copper block cutting" })
R("fo-synchrotron", 13, "advanced-crafting", 120,
  { { "fo-superconducting-coil", 100 }, { "fo-permanent-magnet", 50 }, { "fo-cryostat", 50 }, { "processing-unit", 100 }, { "concrete", 200 } }, { { "fo-synchrotron", 1 } },
  { branch = "B", level = 2 })
R("fo-recombiner", 13, "advanced-crafting", 20, { { "fo-superconducting-coil", 10 }, { "fo-cryostat", 4 }, { "processing-unit", 10 }, { "fo-lead-shielding", 10 } }, { { "fo-recombiner", 1 } },
  { branch = "B", level = 2 })
R("fo-antiproton-production", 13, "fo-synchrotron", 30, { { "fo-magnetic-trap", 1 }, { "fo-hydrogen", 100 } }, { { "fo-antiproton-trap", 1 } },
  { branch = "B", level = 2, fr = "Production d'antiprotons (150 MW)", en = "Antiproton production (150 MW)" })
R("fo-recombination", 13, "fo-recombination", 10, { { "fo-antiproton-trap", 1 }, { "fo-positron-trap", 1 } }, { { "fo-antihydrogen-trap", 1 }, { "fo-magnetic-trap", 1, back = true } },
  { branch = "B", level = 2, fr = "Recombinaison (antihydrogène)", en = "Recombination (antihydrogen)" })
R("fo-antimatter-microcharge", 13, "fo-recombination", 20, { { "fo-antihydrogen-trap", 1 }, { "fo-tungsten-plate", 10 }, { "fo-superconducting-tape", 10 } },
  { { "fo-antimatter-microcharge", 10 }, { "fo-magnetic-trap", 1, back = true } }, { branch = "B", level = 2 })
R("fo-annihilation-shell", 13, "crafting", 10, { { "artillery-shell", 1 }, { "fo-antimatter-microcharge", 1 } }, { { "fo-annihilation-shell", 1 } }, { branch = "B", level = 2 })
R("fo-annihilation-measurement", 13, "fo-recombination", 10, { { "fo-antihydrogen-trap", 1 } }, { { "fo-magnetic-trap", 1, back = true }, { "fo-annihilation-data", 20 } },
  { branch = "B", level = 2, fr = "Mesure d'annihilation", en = "Annihilation measurement" })
R("fo-catalyzed-fusion-pellet", 13, "fo-recombination", 20, { { "fo-fusion-pellet", 2 }, { "fo-antihydrogen-trap", 2 } },
  { { "fo-catalyzed-fusion-pellet", 2 }, { "fo-magnetic-trap", 2, back = true } }, { branch = "B", level = 2, fr = "Fusion catalysée par l'antimatière", en = "Antimatter-catalyzed fusion",
    whitelist_fr = "fusion catalysée : +40 GJ par piège d'antihydrogène (2 pastilles de 80 → 120 GJ), moins que les 50 GJ du réacteur à annihilation (fiction déclarée)" })
R("fo-burn-catalyzed-pellet", 13, nil, 200, { { "fo-catalyzed-fusion-pellet", 1 } }, {},
  { kind = "burn", machines = { "fo-fusion-reactor" }, branch = "B", level = 2, fr = "Combustion : pastille catalysée", en = "Burning: catalyzed pellet" })
R("fo-hadron-compressor", 13, "advanced-crafting", 60, { { "fo-superconducting-coil", 50 }, { "fo-tungsten-plate", 50 }, { "fo-cryostat", 20 }, { "processing-unit", 50 } },
  { { "fo-hadron-compressor", 1 } }, { branch = "D", level = 2 })
R("fo-catalysis-vat", 13, "advanced-crafting", 30, { { "fo-lead-shielding", 20 }, { "fo-superconducting-coil", 20 }, { "fo-cryostat", 10 }, { "fo-titanium-composite", 10 } },
  { { "fo-catalysis-vat", 1 } }, { branch = "D", level = 2 })
R("fo-strangelet-germination", 13, "fo-hadron", 60, { { "fo-strange-inclusion", 1 }, { "fo-plasma", 200 } }, { { "fo-confined-strangelet", 1 } },
  { branch = "D", level = 2, fr = "Germination d'un strangelet", en = "Strangelet germination" })
R("fo-strange-growth", 13, "fo-catalysis", 30, { { "fo-confined-strangelet", 2, catalyst = 2 }, { "stone", 10 }, { "fo-sand", 10 } },
  { { "fo-confined-strangelet", 3, catalyst = 2 } }, { branch = "D", level = 2, process = "catalytic", fr = "Croissance étrange", en = "Strange growth" })
for _, w in ipairs({ { "fo-slag", "laitier", "slag" }, { "fo-sand", "sable", "sand" }, { "stone", "pierre", "stone" },
                     { "fo-vitrified-waste", "colis vitrifiés", "vitrified waste" }, { "fo-spent-salt", "sel usé", "spent salt" } }) do
  R("fo-strange-conversion-" .. w[3]:gsub(" ", "-"), 13, "fo-catalysis", 30, { { "fo-confined-strangelet", 1, catalyst = 1 }, { w[1], 32 } },
    { { "fo-confined-strangelet", 2, catalyst = 1 } },
    { branch = "D", level = 2, process = "conversion", fr = "Croissance étrange : conversion de " .. w[2], en = "Strange growth: " .. w[3] .. " conversion" })
end
R("fo-strange-plate", 13, "fo-catalysis", 20, { { "fo-confined-strangelet", 1 }, { "fo-tungsten-plate", 4 } }, { { "fo-strange-plate", 2 } },
  { branch = "D", level = 2, fr = "Plaque de matière étrange", en = "Strange matter plate" })
R("fo-hadronic-measurement", 13, "fo-hadron", 10, { { "fo-confined-strangelet", 1 } }, { { "fo-hadronic-data", 12 } },
  { branch = "D", level = 2, fr = "Mesure hadronique", en = "Hadronic measurement" })
R("fo-transmuter", 13, "advanced-crafting", 60, { { "fo-strange-plate", 50 }, { "fo-superconducting-coil", 20 }, { "processing-unit", 20 } }, { { "fo-transmuter", 1 } },
  { branch = "D", level = 2 })
-- Transmutation (corrigée) : 40 pierres → 20 minerais en 5 s au transmutateur de 15 MW, soit 3,75 MJ par
-- minerai (contre 50 avant). Variantes « résonantes » (× 2) activées par script à la pose du Monolithe.
-- Le cristal de résonance est RETIRÉ des cibles : combustible de 20 MJ, il rendait 400 MJ pour 75 MJ
-- investis (règle d'énergie P5, trouvé par le banc).
for _, t in ipairs({ { "fo-tungsten-ore", "tungsten", "tungstène", "Tungsten" }, { "fo-ilmenite-ore", "ilmenite", "ilménite", "Ilmenite" },
                     { "fo-monazite-ore", "monazite", "monazite", "Monazite" }, { "uranium-ore", "uranium", "uranium", "Uranium" } }) do
  R("fo-transmutation-" .. t[2], 13, "fo-transmutation", 5, { { "fo-confined-strangelet", 1, catalyst = 1 }, { "stone", 40 } },
    { { "fo-confined-strangelet", 1, catalyst = 1 }, { t[1], 20 } },
    { branch = "D", level = 2, process = "transmutation", fr = "Transmutation : " .. t[3], en = "Transmutation: " .. t[4]:lower() })
  R("fo-resonant-transmutation-" .. t[2], 14, "fo-transmutation", 5, { { "fo-confined-strangelet", 1, catalyst = 1 }, { "stone", 40 } },
    { { "fo-confined-strangelet", 1, catalyst = 1 }, { t[1], 40 } },
    { branch = "D", level = 3, process = "transmutation", unlock = "wonder", wonder = "fo-strange-monolith",
      fr = "Transmutation résonante : " .. t[3], en = "Resonant transmutation: " .. t[4]:lower() })
end
R("fo-strange-wall", 13, "crafting", 5, { { "fo-armored-wall", 1 }, { "fo-strange-plate", 2 } }, { { "fo-strange-wall", 1 } }, { branch = "D", level = 2 })
R("fo-codex-13", 13, "crafting", 30, { { "fo-fusion-pellet", 2 }, { "fo-plasma-cell", 5 }, { "fo-plasma-pack", 10 } }, { { "fo-codex-13", 1 } })

-- Époque 14 · Orbite (maîtrises III) ---------------------------------------------------------------
R("fo-mine-meteor-impact", 14, nil, 3, {}, { { "fo-ferrous-meteorite", 1 } },
  { kind = "mining", resource = "fo-meteor-impact", machines = HARD_DRILLS, fr = "Minage : impact météoritique", en = "Mining: meteor impact" })
R("fo-hydrogen-liquefaction", 14, "fo-cryogenics", 2, { { "fo-hydrogen", 100 }, { "fo-liquid-nitrogen", 10 } }, { { "fo-liquid-hydrogen", 50 } },
  { fr = "Liquéfaction de l'hydrogène", en = "Hydrogen liquefaction" })
R("fo-cryogenic-propellant", 14, "chemistry", 10, { { "fo-liquid-hydrogen", 40 }, { "fo-liquid-oxygen", 20 }, { "fo-titanium-composite", 1 } }, { { "fo-cryogenic-propellant", 2 } },
  { fr = "Ergol cryogénique", en = "Cryogenic propellant", note_fr = "sans valeur de combustion (règle d'énergie)" })
R("fo-light-rocket-part", 14, "fo-light-launch", 3, { { "fo-titanium-composite", 2 }, { "fo-cryogenic-propellant", 2 }, { "processing-unit", 1 } }, { { "fo-light-rocket-part", 1 } },
  { fr = "Pièce de lanceur léger", en = "Light launcher part" })
R("fo-orbital-launcher", 14, "advanced-crafting", 60, { { "concrete", 200 }, { "fo-titanium-composite", 50 }, { "fo-superconducting-coil", 50 }, { "processing-unit", 50 }, { "steel-plate", 100 } },
  { { "fo-orbital-launcher", 1 } })
R("fo-orbital-tug", 14, "advanced-crafting", 30, { { "fo-titanium-composite", 10 }, { "fo-superconducting-coil", 4 }, { "processing-unit", 4 }, { "fo-cryogenic-propellant", 10 } }, { { "fo-orbital-tug", 1 } })
R("fo-launch-orbital-tug", 14, nil, 1, { { "fo-orbital-tug", 1 }, { "fo-light-rocket-part", 10 } }, { { "fo-ferrous-meteorite", 400 }, { "fo-strange-meteorite", 50 } },
  { kind = "launch", extraction = true, machines = { "fo-orbital-launcher" }, fr = "Lancement : remorqueur orbital", en = "Launch: orbital tug" })
R("fo-orbital-solar-plant", 14, "advanced-crafting", 60, { { "solar-panel", 50 }, { "fo-titanium-composite", 10 }, { "fo-superconducting-coil", 10 }, { "processing-unit", 10 } }, { { "fo-orbital-solar-plant", 1 } })
R("fo-launch-orbital-solar-plant", 14, nil, 1, { { "fo-orbital-solar-plant", 1 }, { "fo-light-rocket-part", 10 } }, {},
  { kind = "launch", machines = { "fo-orbital-launcher" }, power_kw = 200000, fr = "Lancement : centrale solaire orbitale (+200 MW, reçus par une rectenna)", en = "Launch: orbital solar plant (+200 MW, received by one rectenna)" })
R("fo-meteorite-crushing", 14, "fo-crushing", 1.6, { { "fo-ferrous-meteorite", 4 } }, { { "fo-nickel-iron", 3 }, { "fo-iridium", 1 }, { "stone", 2 } },
  { fr = "Concassage météoritique", en = "Meteorite crushing" })
R("fo-strange-meteorite-crushing", 14, "fo-crushing", 10, { { "fo-strange-meteorite", 1 } }, { { "fo-strange-inclusion", 5 }, { "stone", 2 } },
  { fr = "Concassage d'une météorite étrange", en = "Strange meteorite crushing" })
R("fo-superalloy", 14, "fo-plasma-casting", 0.267, { { "fo-nickel-iron", 3 }, { "fo-titanium-plate", 1 }, { "fo-tungsten-carbide", 1 }, { "fo-plasma", 0.5 } }, { { "fo-superalloy", 1 } },
  { prod = true, fr = "Superalliage (ferronickel météoritique)", en = "Superalloy (meteoritic nickel-iron)" })
R("fo-synthetic-superalloy", 14, "fo-plasma-casting", 0.267, { { "fo-iron-block-r32", 1 }, { "fo-titanium-plate", 1 }, { "fo-tungsten-carbide", 2 }, { "fo-plasma", 0.5 } }, { { "fo-superalloy", 1 } },
  { fr = "Superalliage de synthèse", en = "Synthetic superalloy", note_fr = "sans météorite : la monnaie de l'époque 14 n'a pas de plafond de carte" })
R("fo-iridium-mirror", 14, "fo-cleanroom", 20, { { "fo-iridium", 2 }, { "fo-glass", 1 }, { "fo-titanium-composite", 1 } }, { { "fo-iridium-mirror", 1 } }, { prod = true })
R("fo-rectenna", 14, "advanced-crafting", 30, { { "fo-permanent-magnet", 20 }, { "fo-enameled-wire", 100 }, { "fo-titanium-composite", 20 }, { "processing-unit", 10 } }, { { "fo-rectenna", 1 } })
R("fo-deflector-shield", 14, "advanced-crafting", 30, { { "fo-superconducting-coil", 20 }, { "fo-superalloy", 2 }, { "processing-unit", 10 }, { "fo-cryostat", 4 } }, { { "fo-deflector-shield", 1 } })
R("fo-gravity-well-2", 14, "advanced-crafting", 60, { { "fo-gravity-well", 1 }, { "fo-axion-condensate", 10 }, { "fo-superalloy", 5 } }, { { "fo-gravity-well-2", 1 } },
  { branch = "A", level = 3 })
for _, u in ipairs({ { "fo-tungsten-concentrate", "tungsten", "tungstène" }, { "fo-ilmenite-concentrate", "ilmenite", "ilménite" },
                     { "fo-monazite-concentrate", "monazite", "monazite" } }) do
  R("fo-upwelling-" .. u[2], 14, nil, 1, {}, { { u[1], 1 } },
    { kind = "mining", resource = "fo-deep-upwelling-" .. u[2], machines = { "fo-gravity-well-2" }, branch = "A", level = 3,
      fr = "Remontée profonde : " .. u[3], en = "Deep upwelling: " .. u[2] })
end
R("fo-tidal-shield", 14, "advanced-crafting", 40, { { "fo-axion-condensate", 10 }, { "fo-superconducting-coil", 10 }, { "fo-superalloy", 5 } }, { { "fo-tidal-shield", 1 } },
  { branch = "A", level = 3 })
R("fo-caustic-observatory", 14, "advanced-crafting", 600, { { "fo-axion-condensate", 200 }, { "fo-resonance-lens", 500 }, { "fo-superalloy", 50 }, { "processing-unit", 300 } },
  { { "fo-caustic-observatory", 1 } }, { branch = "A", level = 3 })
R("fo-annihilation-reactor", 14, "advanced-crafting", 180, { { "fo-superconducting-coil", 300 }, { "fo-superalloy", 50 }, { "fo-lead-shielding", 500 }, { "fo-cryostat", 100 } },
  { { "fo-annihilation-reactor", 1 } }, { branch = "B", level = 3 })
R("fo-annihilation-bastion", 14, "advanced-crafting", 600, { { "fo-antihydrogen-trap", 100 }, { "fo-lead-shielding", 500 }, { "fo-superalloy", 50 }, { "processing-unit", 300 } },
  { { "fo-annihilation-bastion", 1 } }, { branch = "B", level = 3 })
R("fo-burn-antihydrogen", 14, nil, 25, { { "fo-antihydrogen-trap", 1 } }, { { "fo-magnetic-trap", 1 } },
  { kind = "burn", machines = { "fo-annihilation-reactor" }, branch = "B", level = 3, fr = "Combustion : antihydrogène (2 GW)", en = "Burning: antihydrogen (2 GW)" })
R("fo-annihilation-lance", 14, "advanced-crafting", 60, { { "fo-superconducting-coil", 40 }, { "fo-superalloy", 10 }, { "processing-unit", 20 }, { "fo-antimatter-microcharge", 20 } },
  { { "fo-annihilation-lance", 1 } }, { branch = "B", level = 3 })
R("fo-deep-probe", 14, "advanced-crafting", 60, { { "fo-antihydrogen-trap", 2 }, { "fo-titanium-composite", 10 }, { "processing-unit", 5 } }, { { "fo-deep-probe", 1 } },
  { branch = "B", level = 3 })
R("fo-launch-deep-probe", 14, nil, 1, { { "fo-deep-probe", 1 }, { "fo-light-rocket-part", 10 } }, { { "fo-strange-meteorite", 50 }, { "fo-iridium", 400 } },
  { kind = "launch", extraction = true, machines = { "fo-orbital-launcher" }, branch = "B", level = 3, fr = "Lancement : sonde profonde", en = "Launch: deep probe" })
R("fo-dilation-chamber-2", 14, "advanced-crafting", 30, { { "fo-dilation-chamber", 1 }, { "fo-stable-time-crystal", 4 }, { "fo-superalloy", 2 } }, { { "fo-dilation-chamber-2", 1 } },
  { branch = "C", level = 3 })
R("fo-eternal-clock", 14, "advanced-crafting", 600, { { "fo-stable-time-crystal", 100 }, { "fo-quantum-hourglass", 200 }, { "fo-superalloy", 50 }, { "processing-unit", 300 } },
  { { "fo-eternal-clock", 1 } }, { branch = "C", level = 3 })
R("fo-neutronium-wall", 14, "crafting", 10, { { "fo-strange-wall", 1 }, { "fo-strange-plate", 8 }, { "fo-superalloy", 1 } }, { { "fo-neutronium-wall", 1 } },
  { branch = "D", level = 3 })
R("fo-strange-armor", 14, "advanced-crafting", 60, { { "fo-strange-plate", 40 }, { "fo-titanium-composite", 20 }, { "fo-superconducting-coil", 10 } }, { { "fo-strange-armor", 1 } },
  { branch = "D", level = 3 })
R("fo-strange-monolith", 14, "advanced-crafting", 600, { { "fo-strange-plate", 500 }, { "fo-confined-strangelet", 50 }, { "fo-superalloy", 50 }, { "processing-unit", 300 } },
  { { "fo-strange-monolith", 1 } }, { branch = "D", level = 3 })
R("fo-codex-14", 14, "crafting", 30, { { "fo-superalloy", 5 }, { "fo-iridium-mirror", 5 }, { "space-science-pack", 10 } }, { { "fo-codex-14", 1 } })

-- Époque 15 · Légende (convergence) ----------------------------------------------------------------
R("fo-rift-anchor", 15, "advanced-crafting", 120,
  { { "fo-axion-condensate", 4 }, { "fo-strange-plate", 4 }, { "fo-antihydrogen-trap", 2 }, { "fo-stable-time-crystal", 2 }, { "fo-superalloy", 10 }, { "fo-superconducting-coil", 20 } },
  { { "fo-rift-anchor", 1 } })
R("fo-capture-core-rift", 15, nil, 1, { { "fo-plasma", 20 } }, { { "fo-raw-exotic-matter", 5 } },
  { kind = "mining", resource = "fo-core-rift", machines = { "fo-rift-anchor" }, fr = "Captage : faille du Cœur", en = "Tapping: Core rift",
    note_fr = "foreuse à entrée de fluide (minable.required_fluid) : non vérifié pour une ressource fluide ; repli conçu (X.fallback_recipes)" })
R("fo-casimir-stabilizer", 15, "advanced-crafting", 60, { { "fo-iridium-mirror", 50 }, { "fo-superconducting-coil", 20 }, { "fo-superalloy", 10 }, { "processing-unit", 50 } },
  { { "fo-casimir-stabilizer", 1 } })
R("fo-casimir-cavity", 15, "fo-cleanroom", 30, { { "fo-iridium-mirror", 2 }, { "fo-stable-time-crystal", 1 }, { "fo-superconducting-coil", 1 } }, { { "fo-casimir-cavity", 1 } })
R("fo-exotic-stabilization", 15, "fo-casimir", 60, { { "fo-raw-exotic-matter", 50 }, { "fo-casimir-cavity", 1, catalyst = 1 } },
  { { "fo-stabilized-exotic-matter", 1 }, { "fo-casimir-cavity", 1, catalyst = 1 } },
  { process = "catalytic", fr = "Stabilisation de la matière exotique (500 MW)", en = "Exotic matter stabilization (500 MW)" })
R("fo-exotic-pack", 15, "fo-cleanroom", 60, { { "fo-stabilized-exotic-matter", 1 }, { "fo-superalloy", 35 }, { "processing-unit", 30 }, { "fo-iridium-mirror", 10 } }, { { "fo-exotic-pack", 20 } },
  { note_fr = "une matière exotique pour 20 packs : la recherche de l'époque 15 tient dans le débit des failles" })
R("fo-erebus-gate", 15, "advanced-crafting", 300,
  { { "concrete", 500 }, { "fo-superalloy", 50 }, { "fo-superconducting-coil", 100 }, { "fo-iridium-mirror", 50 }, { "fo-stabilized-exotic-matter", 20 }, { "processing-unit", 100 } },
  { { "fo-erebus-gate", 1 } })
R("fo-ring-segment", 15, "fo-gate", 60,
  { { "fo-stabilized-exotic-matter", 2 }, { "fo-superalloy", 1 }, { "fo-strange-plate", 2 }, { "fo-axion-condensate", 1 }, { "fo-antihydrogen-trap", 1 }, { "fo-stable-time-crystal", 1 } },
  { { "fo-ring-segment", 1 } }, { fr = "Segment d'anneau", en = "Ring segment" })
R("fo-phase-key", 15, "advanced-crafting", 120, { { "fo-stabilized-exotic-matter", 10 }, { "fo-iridium-mirror", 10 }, { "fo-quantum-hourglass", 10 } }, { { "fo-phase-key", 1 } })
R("fo-open-gate", 15, nil, 1, { { "fo-phase-key", 1 }, { "fo-ring-segment", 100 } }, {},
  { kind = "launch", machines = { "fo-erebus-gate" }, fr = "Ouverture de la Porte (charge de 30 min sous assaut, 5 GW)", en = "Opening the Gate (30 min charge under siege, 5 GW)" })

-- Torchère : un puits pour chaque fluide nouveau (le four choisit la recette d'après le fluide entrant).
X.flare_fluids = { "fo-ethylene", "fo-volcanic-gas", "fo-hydrogen", "fo-oxygen", "fo-carbon-dioxide", "fo-brine", "fo-chlorine",
  "fo-titanium-tetrachloride", "fo-liquid-nitrogen", "fo-liquid-oxygen", "fo-helium", "fo-liquid-helium", "fo-dark-flux",
  "fo-helium-3", "fo-heavy-water", "fo-deuterium", "fo-liquid-hydrogen" }
do
  local item_of = {}
  for _, it in ipairs(items) do item_of[it.name] = it end
  for _, fl in ipairs(X.flare_fluids) do
    local it = item_of[fl]
    R("fo-flare-" .. fl:sub(4), math.max(4, it.epoch), "fo-flaring", 1, { { fl, 100 } }, {},
      { kind = "sink", branch = it.branch, level = it.level, fr = "Torchère : " .. it.fr:lower(), en = "Flaring: " .. it.en:lower() })
  end
end

X.recipes = recipes

--- Recettes de REPLI, hors du graphe tant qu'elles ne sont pas retenues (lot X15) : l'ancre de faille en
--- machine à recette fixe si la foreuse à entrée et sortie de fluide échoue en moteur réel.
X.fallback_recipes = {
  { name = "fo-rift-tapping", epoch = 15, category = "fo-rift-tapping", time = 1, ingredients = { { "fo-plasma", 20 } },
    results = { { "fo-raw-exotic-matter", 5 } }, kind = "recipe", fallback_of = "fo-capture-core-rift", machines = { "fo-rift-anchor" },
    fr = "Captage de faille (repli)", en = "Rift tapping (fallback)" },
}

-- Le kind « building » se déduit : une recette dont le produit unique est un bâtiment.
do
  local is_building = {}
  for _, b in ipairs(buildings) do is_building[b.name] = true end
  for _, r in ipairs(recipes) do
    if r.kind == "recipe" and #r.results == 1 and is_building[r.results[1][1]] then r.kind = "building" end
  end
end

---------------------------------------------------------------------------------------------------
-- 10. Pseudo-recettes du contenu vanilla et existant (minage, pompage, combustion, lancement).
---------------------------------------------------------------------------------------------------
X.base_pseudo = {
  { name = "mine-iron-ore", epoch = 1, kind = "mining", machines = DRILLS, time = 1, ingredients = {}, results = { { "iron-ore", 1 } } },
  { name = "mine-copper-ore", epoch = 1, kind = "mining", machines = DRILLS, time = 1, ingredients = {}, results = { { "copper-ore", 1 } } },
  { name = "mine-coal", epoch = 1, kind = "mining", machines = DRILLS, time = 1, ingredients = {}, results = { { "coal", 1 } } },
  { name = "mine-stone", epoch = 1, kind = "mining", machines = DRILLS, time = 1, ingredients = {}, results = { { "stone", 1 } } },
  { name = "gather-wood", epoch = 1, kind = "gather", machines = HAND, time = 1, ingredients = {}, results = { { "wood", 4 } } },
  { name = "gather-raw-fish", epoch = 1, kind = "gather", machines = HAND, time = 1, ingredients = {}, results = { { "raw-fish", 1 } } },
  { name = "offshore-water", epoch = 3, kind = "mining", machines = { "offshore-pump" }, time = 1, ingredients = {}, results = { { "water", 1200 } } },
  { name = "boil-water", epoch = 3, kind = "heat", machines = { "boiler", "heat-exchanger" }, time = 1, ingredients = { { "water", 60 } }, results = { { "steam", 60 } } },
  { name = "pump-crude-oil", epoch = 4, kind = "mining", machines = { "pumpjack" }, time = 1, ingredients = {}, results = { { "crude-oil", 10 } } },
  { name = "mine-tungsten", epoch = 5, kind = "mining", machines = HARD_DRILLS, time = 2, ingredients = {}, results = { { "fo-tungsten-ore", 1 } } },
  { name = "mine-resonance-crystal", epoch = 7, kind = "mining", machines = DRILLS, time = 1.5, ingredients = {}, results = { { "fo-resonance-crystal", 1 } } },
  { name = "pump-methane", epoch = 8, kind = "mining", machines = { "pumpjack" }, time = 1, ingredients = {}, results = { { "fo-methane", 10 } } },
  { name = "mine-uranium-ore", epoch = 9, kind = "mining", machines = HARD_DRILLS, time = 2, ingredients = { { "sulfuric-acid", 1 } }, results = { { "uranium-ore", 1 } } },
  { name = "burn-uranium-fuel-cell", epoch = 9, kind = "burn", machines = { "nuclear-reactor" }, time = 200, ingredients = { { "uranium-fuel-cell", 1 } }, results = { { "used-up-uranium-fuel-cell", 1 } } },
  { name = "launch-satellite", epoch = 14, kind = "launch", machines = { "rocket-silo" }, time = 1, ingredients = { { "satellite", 1 }, { "rocket-part", 100 } }, results = { { "space-science-pack", 1000 } } },
}

---------------------------------------------------------------------------------------------------
-- 11. Re-rangement du contenu vanilla et existant par époque (verrou fo-epoch-k). Chaque recette de
--     tests/fixtures/recipes.lua et de l'arsenal y a une époque. Corrections de l'existant (§11 bis).
---------------------------------------------------------------------------------------------------
X.base_recipe_epochs = {
  { 1, { "automation-science-pack", "burner-inserter", "burner-mining-drill", "copper-cable", "copper-plate", "electronic-circuit",
         "firearm-magazine", "gun-turret", "inserter", "iron-chest", "iron-gear-wheel", "iron-plate", "iron-stick", "pipe", "pipe-to-ground",
         "pistol", "repair-pack", "stone-brick", "stone-furnace", "transport-belt", "underground-belt", "splitter", "wooden-chest",
         "light-armor", "submachine-gun", "shotgun", "shotgun-shell", "fo-command-center" } },
  { 2, { "steel-plate", "steel-chest", "steel-furnace", "stone-wall", "gate", "logistic-science-pack", "piercing-rounds-magazine",
         "heavy-armor", "grenade", "landfill", "combat-shotgun", "piercing-shotgun-shell" } },
  { 3, { "boiler", "steam-engine", "offshore-pump", "small-electric-pole", "medium-electric-pole", "big-electric-pole",
         "electric-mining-drill", "assembling-machine-1", "assembling-machine-2", "lab", "radar", "small-lamp", "long-handed-inserter",
         "fast-inserter", "filter-inserter", "engine-unit", "car", "locomotive", "cargo-wagon", "rail", "train-stop", "rail-signal",
         "rail-chain-signal", "concrete", "hazard-concrete", "military-science-pack", "red-wire", "green-wire", "arithmetic-combinator",
         "decider-combinator", "constant-combinator", "power-switch", "programmable-speaker" } },
  { 4, { "pumpjack", "oil-refinery", "chemical-plant", "basic-oil-processing", "advanced-oil-processing", "heavy-oil-cracking",
         "light-oil-cracking", "coal-liquefaction", "plastic-bar", "sulfur", "sulfuric-acid", "lubricant", "solid-fuel-from-heavy-oil",
         "solid-fuel-from-light-oil", "solid-fuel-from-petroleum-gas", "advanced-circuit", "chemical-science-pack", "explosives",
         "cliff-explosives", "storage-tank", "pump", "empty-barrel", "fill-crude-oil-barrel", "fill-heavy-oil-barrel", "fill-light-oil-barrel",
         "fill-lubricant-barrel", "fill-petroleum-gas-barrel", "fill-sulfuric-acid-barrel", "fill-water-barrel", "empty-crude-oil-barrel",
         "empty-heavy-oil-barrel", "empty-light-oil-barrel", "empty-lubricant-barrel", "empty-petroleum-gas-barrel",
         "empty-sulfuric-acid-barrel", "empty-water-barrel", "fast-transport-belt", "fast-underground-belt", "fast-splitter",
         "rocket-launcher", "rocket", "explosive-rocket", "land-mine", "poison-capsule", "slowdown-capsule", "defender-capsule",
         "modular-armor", "night-vision-equipment", "belt-immunity-equipment", "fluid-wagon", "refined-concrete", "refined-hazard-concrete",
         "stack-inserter", "stack-filter-inserter" } },
  { 5, { "tank", "cannon-shell", "explosive-cannon-shell", "fo-tungsten-plate", "fo-tungsten-rounds-magazine", "fo-explosive-rounds-magazine",
         "fo-heavy-machine-gun", "fo-heavy-gun-turret", "fo-reinforced-wall", "fo-armored-wall", "fo-cannon-turret", "fo-mortar-turret",
         "fo-mortar-shell", "fo-tungsten-cannon-shell", "fo-launcher-grenade", "fo-grenade-launcher" } },
  { 6, { "battery", "accumulator", "solar-panel", "substation", "electric-engine-unit", "laser-turret", "electric-furnace",
         "production-science-pack", "speed-module", "productivity-module", "effectivity-module", "distractor-capsule", "assembling-machine-3",
         "battery-equipment", "solar-panel-equipment", "energy-shield-equipment", "fo-tesla-turret", "fo-arc-cell", "fo-arc-gun" } },
  { 7, { "beacon", "express-transport-belt", "express-underground-belt", "express-splitter", "fo-heavy-laser-turret" } },
  { 8, { "flamethrower", "flamethrower-ammo", "flamethrower-turret", "fill-fo-methane-barrel", "empty-fo-methane-barrel",
         "fo-incendiary-rounds-magazine", "fo-methane-cracking", "fo-acid-sprayer" } },
  { 9, { "nuclear-reactor", "centrifuge", "heat-pipe", "heat-exchanger", "steam-turbine", "uranium-processing", "kovarex-enrichment-process",
         "uranium-fuel-cell", "nuclear-fuel-reprocessing", "uranium-rounds-magazine", "uranium-cannon-shell", "explosive-uranium-cannon-shell" } },
  { 10, { "processing-unit", "utility-science-pack", "flying-robot-frame", "construction-robot", "logistic-robot", "roboport",
          "logistic-chest-active-provider", "logistic-chest-passive-provider", "logistic-chest-storage", "logistic-chest-buffer",
          "logistic-chest-requester", "personal-roboport-equipment", "personal-roboport-mk2-equipment", "power-armor", "power-armor-mk2",
          "exoskeleton-equipment", "personal-laser-defense-equipment", "energy-shield-mk2-equipment", "battery-mk2-equipment",
          "discharge-defense-equipment", "discharge-defense-remote", "speed-module-2", "productivity-module-2",
          "effectivity-module-2", "speed-module-3", "productivity-module-3", "effectivity-module-3",
          "low-density-structure", "rocket-control-unit", "rocket-fuel", "nuclear-fuel", "artillery-turret", "artillery-shell",
          "artillery-wagon", "artillery-targeting-remote", "destroyer-capsule", "atomic-bomb", "cluster-grenade",
          "fo-plasma-rounds-magazine", "fo-speed-module-4", "fo-speed-module-5", "fo-productivity-module-4", "fo-productivity-module-5",
          "fo-effectivity-module-4", "fo-effectivity-module-5" } },
  { 12, { "fo-railgun", "fo-rail-slug" } },
  { 13, { "fusion-reactor-equipment", "spidertron", "spidertron-remote" } },
  { 14, { "rocket-silo", "satellite", "fo-speed-module-6", "fo-speed-module-7", "fo-speed-module-8", "fo-speed-module-9",
          "fo-speed-module-10", "fo-productivity-module-6", "fo-productivity-module-7", "fo-productivity-module-8", "fo-productivity-module-9",
          "fo-productivity-module-10", "fo-effectivity-module-6", "fo-effectivity-module-7", "fo-effectivity-module-8",
          "fo-effectivity-module-9", "fo-effectivity-module-10" } },
}
--- Recettes de base qui ne reçoivent AUCUNE époque et restent hors du graphe (correction) :
--- l'interface électrique vanilla est l'objet de triche (500 GW pour 2 plaques et 5 circuits : elle
--- annulerait les 5 GW de la Porte et la règle P5) ; les chargeurs vanilla sont hidden = true dans
--- recipe.lua. Les chargeurs ne quittent cette liste que sur décision explicite du lot C.
X.base_recipe_never = { "electric-energy-interface", "loader", "fast-loader", "express-loader" }
--- Recette cachée tolérée : la pièce de fusée vanilla, recette fixe du silo (époque 14).
X.base_recipe_hidden_allowed = { { "rocket-part", 14 } }

--- Technologies vanilla dont les recettes tombent dans des époques différentes (relevé sur
--- data/base/prototypes/technology.lua par tests/epochs_test.lua) : le verrou fo-epoch-k ne peut pas les
--- ranger d'un bloc ; le lot qui les re-range les SCINDE ainsi (une technologie par époque).
X.vanilla_tech_splits = {
  { tech = "concrete", parts = { { 3, { "concrete", "hazard-concrete" } }, { 4, { "refined-concrete", "refined-hazard-concrete" } } } },
  { tech = "military-3", parts = { { 2, { "combat-shotgun" } }, { 4, { "poison-capsule", "slowdown-capsule" } } } },
  { tech = "military-4", parts = { { 2, { "piercing-shotgun-shell" } }, { 10, { "cluster-grenade" } } } },
  { tech = "kovarex-enrichment-process", parts = { { 9, { "kovarex-enrichment-process" } }, { 10, { "nuclear-fuel" } } } },
}
--- Technologies vanilla sans recette re-rangées explicitement (les autres suivent leurs packs).
--- Productivité minière : elle multiplie les foreuses de concentré, d'où son étalement sur les paliers.
X.vanilla_tech_epochs = {
  { "mining-productivity-1", 4 }, { "mining-productivity-2", 7 }, { "mining-productivity-3", 10 }, { "mining-productivity-4", 13 },
}

-- 11 bis. Corrections de l'existant (à appliquer par l'intégrateur dans shared/content/arsenal.lua).
-- La tour à arc et l'arc portatif exigent du cristal de résonance (époque 7) alors que la liste
-- validée (§6) place la tour à arc à l'époque 6 : on remplace le cristal par des bobines (époque 6).
X.existing_overrides = {
  { name = "fo-tesla-turret", ingredients = { { "laser-turret", 1 }, { "fo-coil", 10 }, { "copper-cable", 60 }, { "advanced-circuit", 10 } },
    was = "15 fo-resonance-crystal (époque 7) : anachronisme à l'époque 6" },
  { name = "fo-arc-gun", ingredients = { { "submachine-gun", 1 }, { "fo-coil", 5 }, { "battery", 10 } },
    was = "10 fo-resonance-crystal (époque 7) : anachronisme à l'époque 6" },
}

-- Re-rangement des technologies existantes (verrou d'époque) ; les packs suivent X.pack_window.
X.existing_tech_epochs = {
  { "fo-tungsten-processing", 5 }, { "fo-heavy-weapons-1", 5 }, { "fo-siege-weapons", 5 },
  { "fo-heavy-weapons-2", 5, split_fr = "scinder : murs blindés et balles explosives (5), tourelle laser lourde (7), balles incendiaires (8)" },
  { "fo-arc-and-acid", 6, split_fr = "scinder : tour à arc et arc portatif (6, recettes corrigées), pulvérisateur d'acide (8)" },
  { "fo-methane-processing", 8 }, { "fo-heavy-weapons-3", 10 }, { "fo-railgun", 12 },
  { "fo-speed-module-4", 10, note_fr = "modules 4 et 5 : processeurs (époque 10) ; modules 6 à 10 : pack espace (époque 14)" },
}

---------------------------------------------------------------------------------------------------
-- 11 ter. Technologies nouvelles (Q7, F1-6). Chaque recette réelle nouvelle est débloquée par
--     EXACTEMENT une technologie de son époque (contrôlé), sauf les recettes de départ (X.start_recipes)
--     et les variantes activées par une merveille (unlock = "wonder"). Prérequis implicites : le verrou
--     fo-epoch-k (k ≥ 2) et, pour toute technologie de l'époque k qui n'est pas celle du pack, la
--     technologie du pack nouveau de l'époque k. Packs (X.pack_window) : technologie de pack = fenêtre de
--     l'époque k-1 (le pack n'existe pas encore) ; branche I = fenêtre de k ; branches II et III = donnée
--     de la branche + pack de l'époque. Coût : units = X.TECH_UNITS[k] × poids (pack et ordinaire 1,
--     Codex 0,5, branche I 1,5, II 2, III 3, Porte 0,25 : ses packs exotiques sont bornés par les failles).
---------------------------------------------------------------------------------------------------
X.start_recipes = { "fo-burner-assembler", "fo-burner-lab" }
--- Unités par technologie ordinaire de l'époque k (calibré par tests/epochs_test.lua : la recherche de
--- l'époque, vanilla re-rangée comprise, consomme 30 à 40 % de X.budget(k)).
X.TECH_UNITS = { 550, 90, 65, 100, 290, 180, 255, 720, 710, 1175, 3760, 5950, 10200, 12430, 184100 }
--- Re-rangement du vanilla : le nombre d'unités des technologies vanilla de l'époque k est multiplié par
--- ce facteur (leurs packs suivent déjà la fenêtre). Calibré par le banc pour que la recherche vanilla
--- prenne environ 17,5 % du budget de l'époque. CONSTAT : aux époques 2 à 4, la recherche vanilla, payée
--- avec la fenêtre de packs, coûte 1,3 à 4,7 fois le budget de l'époque (courbe de 3 à 14 000 MU/s) ;
--- il faut la diviser jusqu'à 25 (ou relever le débit des premières époques : question QX9).
X.VANILLA_UNIT_SCALE = { 0.9, 0.15, 0.07, 0.04, 1, 0.15, 1, 1, 1, 0.25, 1, 1, 1, 1, 1 }
local TECH_WEIGHT = { pack = 1, normal = 1, codex = 0.5, branch1 = 1.5, branch2 = 2, branch3 = 3, gate = 0.25 }
local technologies = {}
local function T(name, epoch, fr, en, unlocks, o)
  o = o or {}
  o.name, o.epoch, o.fr, o.en, o.unlocks = name, epoch, fr, en, unlocks
  o.prereq = o.prereq or {}
  o.role = o.role or (o.branch and ("branch" .. o.level)) or "normal"
  technologies[#technologies + 1] = o
  return o
end
-- Époque 1
T("fo-pioneer-log", 1, "Journal du pionnier", "Pioneer's log", { "fo-codex-1" }, { role = "codex" })
-- Époque 2
T("fo-coking", 2, "Cokéfaction", "Coking", { "fo-coke-oven", "fo-coke" })
T("fo-blast-furnace", 2, "Haut fourneau", "Blast furnace", { "fo-blast-furnace", "fo-blast-furnace-steel" }, { prereq = { "fo-coking" } })
T("fo-crushing", 2, "Concassage", "Crushing", { "fo-crusher", "fo-sand", "fo-slag-cement" }, { prereq = { "fo-blast-furnace" } })
T("fo-forge-book", 2, "Carnet de forge", "Forge book", { "fo-codex-2" }, { role = "codex", prereq = { "fo-crushing" } })
-- Époque 3
T("fo-glassworks", 3, "Verrerie", "Glassworks", { "fo-glass", "fo-manometer" }, { prereq = { "fo-crushing" } })
T("fo-steam-forging", 3, "Forge à vapeur", "Steam forging", { "fo-steam-hammer", "fo-forged-gear", "fo-steam-drill" }, { prereq = { "fo-glassworks" } })
T("fo-cement-concrete", 3, "Béton au ciment", "Cement concrete", { "fo-cement-concrete" }, { prereq = { "fo-crushing" } })
T("fo-boiler-register", 3, "Registre des chaudières", "Boiler register", { "fo-codex-3" }, { role = "codex", prereq = { "fo-steam-forging" } })
-- Époque 4
T("fo-flaring", 4, "Torchère", "Flaring", { "fo-flare-stack" }, { prereq = { "fo-glassworks" }, flare_epoch = 4 })
T("fo-steam-cracking", 4, "Vapocraquage", "Steam cracking", { "fo-steam-cracker", "fo-steam-cracking", "fo-polyethylene" }, { prereq = { "fo-flaring" } })
T("fo-asphalt", 4, "Asphalte", "Asphalt", { "fo-asphalt" })
T("fo-drilling-records", 4, "Relevés de forage", "Drilling records", { "fo-codex-4" }, { role = "codex", prereq = { "fo-steam-cracking" } })
-- Époque 5
T("fo-geological-pack", 5, "Pack géologique", "Geological science pack",
  { "fo-sintering-furnace", "fo-tungsten-carbide", "fo-carbide-bit", "fo-geological-pack" }, { role = "pack" })
T("fo-geothermal", 5, "Géothermie", "Geothermal power", { "fo-geothermal-tap", "fo-volcanic-gas-separation" }, { flare_epoch = 5 })
T("fo-heavy-drilling", 5, "Forage lourd", "Heavy drilling", { "fo-heavy-drill" })
T("fo-ash-atlas", 5, "Atlas des cendres", "Ash atlas", { "fo-codex-5" }, { role = "codex", prereq = { "fo-geothermal", "fo-heavy-drilling" } })
-- Époque 6
T("fo-arc-smelting", 6, "Fusion à l'arc", "Arc smelting", { "fo-arc-furnace", "fo-graphite", "fo-arc-steel" })
T("fo-electrical-steel", 6, "Tôle magnétique et bobinage", "Electrical steel and winding",
  { "fo-magnetic-steel", "fo-coil-winder", "fo-enameled-wire", "fo-coil", "fo-wound-electric-engine" }, { prereq = { "fo-arc-smelting" } })
T("fo-high-voltage", 6, "Haute tension", "High voltage", { "fo-ht-pylon" }, { prereq = { "fo-electrical-steel" } })
T("fo-jaw-crusher", 6, "Broyeur à mâchoires", "Jaw crusher", { "fo-jaw-crusher" }, { prereq = { "fo-electrical-steel" } })
T("fo-grid-schematics", 6, "Schémas du réseau", "Grid schematics", { "fo-codex-6" }, { role = "codex", prereq = { "fo-high-voltage" } })
-- Époque 7
T("fo-resonance-pack", 7, "Pack de résonance", "Resonance science pack",
  { "fo-lapidary", "fo-crystal-cutting", "fo-resonance-lens", "fo-crystal-oscillator", "fo-resonance-pack" }, { role = "pack" })
T("fo-resonance-amplifier", 7, "Amplificateur de résonance", "Resonance amplifier", { "fo-resonance-amplifier" })
T("fo-crystal-energy", 7, "Énergie cristalline", "Crystal energy", { "fo-charging-station", "fo-crystal-charging", "fo-crystal-generator" })
T("fo-crystal-scores", 7, "Partitions du cristal", "Crystal scores", { "fo-codex-7" }, { role = "codex", prereq = { "fo-crystal-energy" } })
T("fo-dark-matter-1", 7, "Matière noire I : résonateur de caustique", "Dark matter I: caustic resonator",
  { "fo-caustic-resonator", "fo-gravimetric-survey", "fo-gravimetric-map" }, { branch = "A", level = 1 })
-- Époque 8
T("fo-biochemical-pack", 8, "Pack biochimique", "Biochemical science pack",
  { "fo-bioreactor", "fo-culture-from-sample", "fo-culture-from-tissue", "fo-culture-growth", "fo-electrolyzer",
    "fo-water-electrolysis", "fo-biopolymer", "fo-biochemical-pack" }, { role = "pack", flare_epoch = 8 })
T("fo-methane-reforming", 8, "Reformage du méthane", "Methane reforming", { "fo-reformer", "fo-methane-reforming" })
T("fo-gas-turbine", 8, "Turbine à gaz", "Gas turbine", { "fo-gas-turbine" })
T("fo-digester", 8, "Digesteur et carbonatation", "Digester and carbonation", { "fo-digester-methane", "fo-slag-carbonation" })
T("fo-marsh-herbarium", 8, "Herbier du marais", "Marsh herbarium", { "fo-codex-8" }, { role = "codex", prereq = { "fo-methane-reforming" } })
-- Époque 9
T("fo-isotopic-pack", 9, "Pack isotopique", "Isotopic science pack", { "fo-lead-plate", "fo-lead-shielding", "fo-isotopic-pack" }, { role = "pack" })
T("fo-galena-roasting", 9, "Grillage de la galène", "Galena roasting", { "fo-galena-roasting" })
T("fo-spent-fuel", 9, "Combustible usé", "Spent fuel", { "fo-cooling-pool", "fo-spent-fuel-cooling", "fo-vitrification", "fo-geological-repository" })
T("fo-reactor-logbook", 9, "Cahier du réacteur", "Reactor logbook", { "fo-codex-9" }, { role = "codex", prereq = { "fo-spent-fuel" } })
T("fo-antimatter-1", 9, "Antimatière I : positons", "Antimatter I: positrons",
  { "fo-irradiator", "fo-positron-moderator", "fo-copper-activation", "fo-magnetic-trap", "fo-positron-capture",
    "fo-controlled-annihilation", "fo-positron-grenade" }, { branch = "B", level = 1 })
-- Époque 10
T("fo-silicon", 10, "Silicium et salle blanche", "Silicon and cleanroom",
  { "fo-metallurgical-silicon", "fo-pure-silicon", "fo-cleanroom", "fo-silicon-wafer", "fo-cleanroom-processor" })
T("fo-phased-array-radar", 10, "Radar à réseau phasé", "Phased-array radar", { "fo-phased-array-radar" }, { prereq = { "fo-silicon" } })
T("fo-concentration", 10, "Foreuses de concentré (T4)", "Concentrate drills (T4)",
  { "fo-ore-concentrator", "fo-concentrate-drill", "fo-iron-concentrate", "fo-copper-concentrate", "fo-tungsten-concentrate" })
T("fo-billets", 10, "Billettes ρ8", "ρ8 billets",
  { "fo-iron-plate-r8", "fo-copper-plate-r8", "fo-tungsten-plate-r8", "fo-iron-plate-r8-unpacking", "fo-copper-plate-r8-unpacking",
    "fo-tungsten-plate-r8-unpacking" }, { prereq = { "fo-concentration" } })
T("fo-cleanroom-plans", 10, "Plans de la salle blanche", "Cleanroom blueprints", { "fo-codex-10" }, { role = "codex", prereq = { "fo-silicon", "fo-billets" } })
T("fo-chronodynamics-1", 10, "Chronodynamique I : cristal temporel", "Chronodynamics I: time crystal",
  { "fo-unstable-time-crystal", "fo-phase-bench", "fo-phase-measurement", "fo-clocked-phased-array-radar" },
  { branch = "C", level = 1, prereq = { "fo-silicon" } })
-- Époque 11
T("fo-structural-pack", 11, "Pack structurel (titane)", "Structural science pack (titanium)",
  { "fo-ilmenite-concentrate", "fo-kroll-reactor", "fo-ilmenite-smelting", "fo-brine-electrolysis", "fo-chlorination",
    "fo-kroll-reduction", "fo-magnesium-electrolysis", "fo-titanium-plate", "fo-titanium-composite", "fo-structural-pack" },
  { role = "pack", flare_epoch = 11 })
T("fo-cryostat", 11, "Cryostat", "Cryostat", { "fo-cryostat", "fo-titanium-lds" })
T("fo-wet-tungsten", 11, "Tungstène par voie humide", "Hydrometallurgical tungsten", { "fo-wet-tungsten" })
T("fo-light-structures", 11, "Structures légères", "Light structures", { "fo-titanium-pylon", "fo-titanium-inserter", "fo-observation-tower" })
T("fo-crater-map", 11, "Carte des cratères", "Crater map", { "fo-codex-11" }, { role = "codex", prereq = { "fo-light-structures" } })
T("fo-strange-matter-1", 11, "Matière étrange I : inclusions", "Strange matter I: inclusions",
  { "fo-inclusion-sorter", "fo-inclusion-analysis", "fo-inclusion-rounds" }, { branch = "D", level = 1 })
T("fo-chronodynamics-2", 11, "Chronodynamique II : verrouillage de phase", "Chronodynamics II: phase locking",
  { "fo-temporal-resonator", "fo-stable-time-crystal", "fo-quantum-hourglass", "fo-dilation-chamber", "fo-phase-maintenance", "fo-entangled-chest" },
  { branch = "C", level = 2, prereq = { "fo-chronodynamics-1", "fo-cryostat" } })
-- Époque 12
T("fo-magnetic-pack", 12, "Pack magnétique", "Magnetic science pack",
  { "fo-monazite-concentrate", "fo-extraction-column", "fo-monazite-leaching", "fo-solvent-extraction", "fo-cryogenic-unit",
    "fo-air-distillation", "fo-superconducting-tape", "fo-permanent-magnet", "fo-superconducting-coil", "fo-magnetic-pack" },
  { role = "pack", flare_fluids = { "fo-liquid-nitrogen", "fo-liquid-oxygen" } })
T("fo-helium", 12, "Hélium", "Helium", { "fo-cryogenic-gas-separation", "fo-helium-liquefaction" }, { flare_fluids = { "fo-helium", "fo-liquid-helium" } })
T("fo-thorium", 12, "Sels fondus au thorium", "Thorium molten salts", { "fo-thorium-salt-cell", "fo-salt-reprocessing", "fo-molten-salt-reactor" })
T("fo-superconducting-storage", 12, "Stockage supraconducteur", "Superconducting storage", { "fo-sc-accumulator", "fo-smes-cell-empty", "fo-smes-charging" })
T("fo-maglev", 12, "Maglev", "Maglev", { "fo-maglev-locomotive" }, { prereq = { "fo-superconducting-storage" } })
T("fo-magnet-treatise", 12, "Traité des aimants", "Treatise on magnets", { "fo-codex-12" }, { role = "codex", prereq = { "fo-thorium" } })
T("fo-dark-matter-2", 12, "Matière noire II : haloscope", "Dark matter II: haloscope",
  { "fo-haloscope", "fo-gravitic-condenser", "fo-resonance-cavity", "fo-axion-condensation", "fo-condensate-survey", "fo-gravity-well" },
  { branch = "A", level = 2, prereq = { "fo-dark-matter-1", "fo-helium" }, flare_fluids = { "fo-dark-flux" } })
T("fo-chronodynamics-2-cryo", 12, "Chronodynamique II : cristal à l'hélium liquide", "Chronodynamics II: liquid-helium crystal",
  { "fo-stable-time-crystal-cryo" }, { branch = "C", level = 2, prereq = { "fo-chronodynamics-2", "fo-helium" } })
-- Époque 13
T("fo-fusion", 13, "Fusion D-³He et pack plasma", "D-³He fusion and plasma pack",
  { "fo-isotope-column", "fo-heavy-water", "fo-heavy-water-electrolysis", "fo-deep-drill", "fo-helium-isotope-distillation",
    "fo-fusion-pellet", "fo-fusion-reactor", "fo-plasma-injector", "fo-ht-heat-pipe", "fo-plasma-foundry", "fo-plasma-cell", "fo-plasma-pack" },
  { role = "pack", flare_epoch = 13 })
T("fo-mhd", 13, "Turbine MHD", "MHD turbine", { "fo-mhd-turbine" })
T("fo-regolith-degassing", 13, "Dégazage du régolithe", "Regolith degassing", { "fo-regolith-degassing", "fo-degassed-ilmenite-smelting" })
T("fo-plasma-casting", 13, "Coulée au plasma (T5)", "Plasma casting (T5)",
  { "fo-iron-block-r32", "fo-copper-block-r32", "fo-iron-ore-casting", "fo-copper-ore-casting", "fo-iron-block-unpacking",
    "fo-copper-block-unpacking", "fo-core-drill" })
T("fo-confinement-journal", 13, "Journal du confinement", "Confinement journal", { "fo-codex-13" }, { role = "codex", prereq = { "fo-mhd" } })
T("fo-antimatter-2", 13, "Antimatière II : antihydrogène", "Antimatter II: antihydrogen",
  { "fo-synchrotron", "fo-recombiner", "fo-antiproton-production", "fo-recombination", "fo-antimatter-microcharge",
    "fo-annihilation-shell", "fo-annihilation-measurement", "fo-catalyzed-fusion-pellet" }, { branch = "B", level = 2, prereq = { "fo-antimatter-1" } })
do
  local d2 = { "fo-hadron-compressor", "fo-catalysis-vat", "fo-strangelet-germination", "fo-strange-growth", "fo-strange-plate",
    "fo-hadronic-measurement", "fo-transmuter", "fo-strange-wall" }
  for _, w in ipairs({ "slag", "sand", "stone", "vitrified-waste", "spent-salt" }) do d2[#d2 + 1] = "fo-strange-conversion-" .. w end
  for _, t in ipairs({ "tungsten", "ilmenite", "monazite", "uranium" }) do d2[#d2 + 1] = "fo-transmutation-" .. t end
  T("fo-strange-matter-2", 13, "Matière étrange II : strangelets", "Strange matter II: strangelets", d2,
    { branch = "D", level = 2, prereq = { "fo-strange-matter-1" } })
end
-- Époque 14
T("fo-superalloy", 14, "Superalliage", "Superalloy", { "fo-superalloy", "fo-synthetic-superalloy" })
T("fo-meteoritics", 14, "Météoritique", "Meteoritics", { "fo-meteorite-crushing", "fo-strange-meteorite-crushing" })
T("fo-orbital-launch", 14, "Lanceur orbital", "Orbital launcher",
  { "fo-hydrogen-liquefaction", "fo-cryogenic-propellant", "fo-light-rocket-part", "fo-orbital-launcher", "fo-orbital-tug" }, { flare_epoch = 14 })
T("fo-orbital-power", 14, "Énergie orbitale", "Orbital power", { "fo-orbital-solar-plant", "fo-rectenna" }, { prereq = { "fo-orbital-launch" } })
T("fo-iridium-optics", 14, "Optique à l'iridium", "Iridium optics", { "fo-iridium-mirror" }, { prereq = { "fo-meteoritics" } })
T("fo-deflector-shield", 14, "Bouclier de déviation", "Deflector shield", { "fo-deflector-shield" }, { prereq = { "fo-superalloy" } })
T("fo-orbital-archives", 14, "Archives orbitales de l'Arche", "The Ark's orbital archives", { "fo-codex-14" },
  { role = "codex", prereq = { "fo-orbital-launch", "fo-superalloy" } })
T("fo-dark-matter-3", 14, "Maîtrise de la matière noire", "Dark matter mastery", { "fo-gravity-well-2", "fo-tidal-shield", "fo-caustic-observatory" },
  { branch = "A", level = 3, mastery = true, prereq = { "fo-dark-matter-2", "fo-superalloy" } })
T("fo-antimatter-3", 14, "Maîtrise de l'antimatière", "Antimatter mastery",
  { "fo-annihilation-reactor", "fo-annihilation-bastion", "fo-annihilation-lance", "fo-deep-probe" },
  { branch = "B", level = 3, mastery = true, prereq = { "fo-antimatter-2", "fo-superalloy", "fo-orbital-launch" } })
T("fo-chronodynamics-3", 14, "Maîtrise de la chronodynamique", "Chronodynamics mastery", { "fo-dilation-chamber-2", "fo-eternal-clock" },
  { branch = "C", level = 3, mastery = true, prereq = { "fo-chronodynamics-2-cryo", "fo-superalloy" } })
T("fo-strange-matter-3", 14, "Maîtrise de la matière étrange", "Strange matter mastery",
  { "fo-neutronium-wall", "fo-strange-armor", "fo-strange-monolith" }, { branch = "D", level = 3, mastery = true, prereq = { "fo-strange-matter-2", "fo-superalloy" } })
-- Époque 15
T("fo-exotic-matter", 15, "Matière exotique et pack exotique", "Exotic matter and exotic pack",
  { "fo-rift-anchor", "fo-casimir-stabilizer", "fo-casimir-cavity", "fo-exotic-stabilization", "fo-exotic-pack" },
  { role = "pack", prereq = { "fo-dark-matter-2", "fo-antimatter-2", "fo-chronodynamics-2", "fo-strange-matter-2", "fo-iridium-optics" } })
T("fo-erebus-gate", 15, "La Porte d'Érèbe", "The Erebus Gate", { "fo-erebus-gate", "fo-ring-segment", "fo-phase-key" },
  { role = "gate", prereq = { "fo-orbital-archives" } })

-- Torchères : chaque recette de torchère rejoint la technologie qui ouvre son fluide (flare_epoch pour la
-- ligne principale de l'époque, flare_fluids pour une liste explicite).
do
  local by_fluid, by_epoch = {}, {}
  for _, t in ipairs(technologies) do
    for _, fl in ipairs(t.flare_fluids or {}) do by_fluid[fl] = t end
    if t.flare_epoch then by_epoch[t.flare_epoch] = t end
  end
  for _, r in ipairs(recipes) do
    if r.kind == "sink" then
      local fl = r.ingredients[1][1]
      local t = by_fluid[fl] or by_epoch[r.epoch]
      if t then t.unlocks[#t.unlocks + 1] = r.name end
    end
  end
end
for _, t in ipairs(technologies) do
  t.units = math.floor(X.TECH_UNITS[t.epoch] * TECH_WEIGHT[t.role] + 0.5)
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
X.technologies = technologies
--- Recherches infinies du mode Légende (pack exotique, époque 15 ; formule de coût à la vanilla).
X.infinite_techs = {
  { name = "fo-legend-mining-productivity", fr = "Productivité minière légendaire", count_formula = "2^(L-1)*5000" },
  { name = "fo-legend-research-speed", fr = "Recherche légendaire", count_formula = "2^(L-1)*5000" },
  { name = "fo-legend-energy-weapons", fr = "Armes à énergie légendaires", count_formula = "2^(L-1)*5000" },
  { name = "fo-legend-physical-projectiles", fr = "Projectiles légendaires", count_formula = "2^(L-1)*5000" },
  { name = "fo-legend-worker-robots", fr = "Robots légendaires", count_formula = "2^(L-1)*5000" },
  { name = "fo-legend-dilation", fr = "Dilatation légendaire", count_formula = "2^(L-1)*5000" },
  { name = "fo-legend-confinement", fr = "Confinement légendaire", count_formula = "2^(L-1)*5000" },
  { name = "fo-legend-transmutation", fr = "Transmutation légendaire", count_formula = "2^(L-1)*5000" },
}

---------------------------------------------------------------------------------------------------
-- 12. Compaction ×4 (BALANCE_SHEET §3) : quelles formes denses existent. Règle anti-explosion + P4
--     (« densité née du palier ») : une matière née à l'époque e avec la densité rho n'existe qu'en rho
--     et aux densités des paliers STRICTEMENT supérieurs à celui de sa naissance.
---------------------------------------------------------------------------------------------------
X.compaction = {
  tiers = {
    { tier = 1, epoch = 1, belt = 15, rho = 1, form_fr = "plaque (vanilla)" },
    { tier = 2, epoch = 4, belt = 30, rho = 2, form_fr = "paquet" },
    { tier = 3, epoch = 7, belt = 60, rho = 4, form_fr = "lingot" },
    { tier = 4, epoch = 10, belt = 120, rho = 8, form_fr = "billette ou concentré" },
    { tier = 5, epoch = 13, belt = 120, rho = 32, form_fr = "bloc" },
  },
  -- Intermédiaires denses (greffe P2) : calibrés à 3,75 objets/s par machine (BALANCE_SHEET §3).
  intermediates = { "iron-gear-wheel", "copper-cable", "electronic-circuit", "advanced-circuit", "processing-unit", "pipe" },
  intermediate_rho = { 8, 32 },
  -- Vanilla et existant compactés (époque de naissance, ρ de naissance).
  base_materials = {
    { "iron-plate", 1 }, { "copper-plate", 1 }, { "steel-plate", 2 }, { "stone", 1 }, { "stone-brick", 1 }, { "coal", 1 },
    { "plastic-bar", 4 }, { "concrete", 3 }, { "fo-tungsten-plate", 5 }, { "sulfur", 4 },
  },
  no_productivity_fr = "jamais de productivité sur compaction, décompaction, catalyse, conversion et transmutation (BALANCE §6)",
  -- Chaînes de la ligne principale aux paliers T4 et T5 (B1 : « des foreuses de concentré aux paliers
  -- hauts »). Le banc calcule, sur les recettes, les machines et les MW réels par tapis (§4.2 du scénario).
  chains = {
    { tier = 4, product = "fo-iron-plate-r8", drill = "fo-concentrate-drill", ore = "iron-ore",
      steps = { "fo-iron-concentrate", "fo-iron-plate-r8" } },
    { tier = 5, product = "fo-iron-block-r32", drill = "fo-core-drill", ore = "iron-ore",
      steps = { "fo-iron-ore-casting" } },
  },
  --- Plafond de foreuses de la ligne principale : X.rate(k) ÷ (MU/s de la meilleure foreuse de l'époque k).
  drill_cap = 2000,
}

--- Formes denses d'une matière née à l'époque e avec la densité rho_born.
function X.dense_forms(epoch_born, rho_born)
  local born_tier = X.logistics_tier(epoch_born)
  local out = { rho_born }
  for t = born_tier + 1, #X.TIER_DENSITY do
    local d = X.TIER_DENSITY[t]
    if d > rho_born then out[#out + 1] = d end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- 13. Systèmes de script (API runtime 1.1.91 vérifiée dans doc-html/runtime-api.json).
---------------------------------------------------------------------------------------------------
-- Marée de la Caustique : 24 phases, sans trigonométrie (règle §2.5). LuaSurface.daytime vaut 0 à midi
-- et 0,5 à minuit : phase i = floor(daytime × 24). Rendement 0,5 à midi, 1,5 à minuit, linéaire.
X.tide = {}
for i = 0, 23 do X.tide[i + 1] = 1.5 - math.abs(i - 12) / 12 end
X.TIDE_PERIOD_TICKS = 600

X.systems = {
  { key = "epoch-lock", api = "LuaTechnology.researched (écriture)", period_fr = "à chaque niveau du centre", cost_fr = "nul" },
  { key = "oath", api = "LuaTechnology.enabled (écriture), LuaForce.set_cease_fire, LuaForce.set_friend", period_fr = "une fois", cost_fr = "nul" },
  { key = "tide", api = "LuaEntity.amount (écriture)",
    period_fr = "registre des veines SOUS un haloscope (tenu à la pose et au retrait : find_entities_filtered sur la zone de minage) ; écritures réparties en tourniquet sur 600 ticks, un lot par tick",
    cost_fr = "O(tuiles sous haloscope ÷ 600) par tick, sans pic" },
  { key = "veins", api = "on_sector_scanned, LuaSurface.create_entity", period_fr = "à chaque secteur balayé ; 2 veines au début de partie", cost_fr = "faible" },
  { key = "upwelling-and-rifts", api = "on_gui_opened (interface propre du puits), LuaSurface.create_entity (25 tuiles de la ressource choisie), LuaEntity.update_connections()",
    period_fr = "à la pose ou au changement de minerai, au réveil du Cœur", cost_fr = "nul" },
  { key = "dilation", api = "balise cachée créée UNE fois à la pose de la chambre (énergie void, sans masque de collision), détruite au retrait ; effet coupé ou rendu par le module caché inséré ou retiré (LuaEntity.get_module_inventory) ; une seule chambre active par machine",
    period_fr = "60 ticks, hystérésis : coupure après 3 contrôles successifs non « working »", cost_fr = "O(chambres)" },
  { key = "confinement", api = "LuaEntity.energy, LuaEntity.status, LuaEntity.damage ; réacteur à annihilation : interface électrique cachée de 20 MW (power_usage, écriture vérifiée) dont on lit energy",
    period_fr = "60 ticks", cost_fr = "O(bâtiments à pièges)" },
  { key = "contagion", api = "LuaEntity.status, LuaEntity.energy, LuaSurface.set_tiles", period_fr = "60 ticks", cost_fr = "O(cuves)" },
  { key = "entangled", api = "LuaEntity.link_id (écriture), interface électrique cachée par paire (power_usage)", period_fr = "à la pose", cost_fr = "nul" },
  { key = "rectenna", api = "LuaEntity.power_production (écriture)", period_fr = "à chaque lancement ou pose", cost_fr = "nul" },
  { key = "meteor-showers", api = "LuaSurface.create_entity", period_fr = "toutes les 20 à 40 min", cost_fr = "pic ponctuel" },
  { key = "evolution-window", api = "LuaForce.evolution_factor (écriture)", period_fr = "3 600 ticks", cost_fr = "nul" },
  { key = "perturbation", api = "LuaForce.item_production_statistics, LuaFlowStatistics.get_input_count", period_fr = "36 000 ticks", cost_fr = "nul" },
  { key = "wonders", api = "LuaForce.mining_drill_productivity_bonus, LuaForce.laboratory_speed_modifier (écriture), LuaForce.set_ammo_damage_modifier, LuaRecipe.enabled (écriture : Monolithe)",
    period_fr = "à la pose", cost_fr = "nul" },
  { key = "gate", api = "on_rocket_launched, interface électrique cachée de 5 GW (power_usage, energy), LuaEntity.rocket_parts (écriture), script/td/director.lua, LuaGameScript.set_game_state ; silo-script set_no_victory",
    period_fr = "événement ; charge lue toutes les 60 ticks", cost_fr = "celui des vagues (E19 : 0,06 ms)" },
  { key = "story", api = "LuaGameScript.show_message_dialog", period_fr = "début de partie, livraison d'un Codex", cost_fr = "nul" },
}
X.SCRIPT_BUDGET_MS = 0.05 -- hypothèse H-X1 : tous les systèmes X ≤ 0,05 ms/tick à l'époque 15 (à mesurer)

X.branch_params = {
  confinement = { grace_ticks = 300, damage_per_trap = 2000, radius = 8, period_ticks = 60, reactor_coil_kw = 20000 },
  contagion = { overflow_ticks = 3600, unpowered_ticks = 600, crowd = { radius = 16, max_vats = 8 },
    radius_per_minute = 1, radius_max = 12, damage_per_second = 50, period_ticks = 60 },
  -- Dilatation (corrigée) : la vitesse se paie en énergie ; une seule chambre par machine (script) ;
  -- effets permis seulement sur les machines de fabrication : ni foreuses, ni laboratoires, ni bâtiments à
  -- confinement (allowed_effects du module caché et liste du script).
  dilation = { aura_radius = 3, level2 = { speed = 1.0, consumption = 1.0 }, level3 = { speed = 2.0, consumption = 2.5 },
    period_ticks = 60, off_after_checks = 3, one_per_machine = true,
    excluded_protos = { "mining-drill", "lab" }, excluded_flags = { "confinement" }, maintenance_s = 120 },
  -- Sablier (corrigé) : 1 par fabrication, une monnaie d'époque (titane) dans son coût ; au plus 1 par
  -- chantier, 2 avec l'Horloge éternelle.
  hourglass = { share = 0.25, min_minutes = 10, per_craft = 1, max_per_job = 1, max_per_job_clock = 2 },
  -- Coffres intriqués (corrigés) : 1 case ; 2 paires par force au niveau II, 4 au niveau III ; chaque
  -- paire active tire 20 MW (le moteur n'expose pas les transferts : un prélèvement par objet est
  -- impossible à mesurer à bas coût, d'où un prélèvement constant).
  entangled = { inventory = 1, pairs_level2 = 2, pairs_level3 = 4, pair_kw = 20000 },
  meteor = { interval_minutes = { 20, 40 }, sites_per_shower = 2, tiles = { 20, 40 }, infinite = true, minimum_share = 0.2, deflector_radius = 48 },
  gate = { segments = 100, charge_minutes = 30, power_mw = 5000, crafting_mw = 50, waves = 12, boss_every = 3, faction_rebate = 0.30 },
}

--- Perturbation (la Caustique) : hausse de l'évolution par unité produite, plafonnée par la fenêtre.
X.perturbation = {
  { item = "fo-axion-condensate", per_unit = 0.00005 },
  { item = "fo-antihydrogen-trap", per_unit = 0.00005 },
  { item = "fo-confined-strangelet", per_unit = 0.00005 },
  { item = "fo-stabilized-exotic-matter", per_unit = 0.0002 },
}

---------------------------------------------------------------------------------------------------
-- 14. Déchiqueteurs : fenêtre d'évolution bornée par l'époque du joueur (greffe P3), palier maximal
--     des vagues de défense de tours, butin.
---------------------------------------------------------------------------------------------------
X.evolution_window = {
  { 0.00, 0.10 }, { 0.05, 0.18 }, { 0.10, 0.25 }, { 0.15, 0.32 }, { 0.20, 0.40 }, { 0.26, 0.47 }, { 0.32, 0.54 },
  { 0.38, 0.61 }, { 0.45, 0.68 }, { 0.52, 0.75 }, { 0.59, 0.81 }, { 0.66, 0.87 }, { 0.73, 0.92 }, { 0.79, 0.96 }, { 0.85, 1.00 },
}
X.EVOLUTION_PERIOD_TICKS = 3600
--- Évolution bornée : la valeur moteur est ramenée dans la fenêtre de l'époque, décalée selon la difficulté.
function X.clamp_evolution(evolution, epoch, difficulty_offset)
  local w = X.evolution_window[epoch]
  local off = difficulty_offset or 0
  local lo = math.max(0, math.min(1, w[1] + off))
  local hi = math.max(0, math.min(1, w[2] + off))
  if evolution < lo then return lo end
  if evolution > hi then return hi end
  return evolution
end
X.td_max_tier = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 8 }
X.loot = { tissue = "fo-biter-tissue", unit_probability = { 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.075, 0.08 }, nest = { 5, 20 } }

---------------------------------------------------------------------------------------------------
-- 15. Factions IA (Q4) : doctrines, ajouts d'époque à la difficulté du lot IA0, économie d'archive.
---------------------------------------------------------------------------------------------------
X.doctrines = {
  { faction = "scarlet", personality = "conqueror", branch = "B", sworn_rival = "amber", elite_fr = "Lancier d'annihilation", elite_en = "Annihilation lancer" },
  { faction = "azure", personality = "technocrat", branch = "A", sworn_rival = "emerald", elite_fr = "Arpenteur gravitique", elite_en = "Gravitic strider" },
  { faction = "emerald", personality = "builder", branch = "D", sworn_rival = "azure", elite_fr = "Colosse étrange", elite_en = "Strange colossus" },
  { faction = "amber", personality = "balanced", branch = "C", sworn_rival = "scarlet", elite_fr = "Spectre chronique", elite_en = "Chrono wraith" },
}
X.OATH_ALLY_SHARE = 0.5   -- part des forces de la faction de même doctrine dirigée contre le joueur (× 0,5)
X.OATH_RIVAL_SHARE = 1.5  -- rivale jurée (× 1,5)

--- Difficulté (Q4) : UNE seule source, celle du lot IA0. shared/faction/config.lua possède F.pvp_order
--- (peaceful, easy, normal, hard, merciless) et F.pvp (grâce, intervalle minimal, part, taille, réserve).
--- X0 n'ajoute ici que ce qui est propre aux époques, indexé par les MÊMES clés (contrôlé par le banc) :
---   evolution_offset : décalage de la fenêtre d'évolution des déchiqueteurs ;
---   epoch_offset     : plafond de l'époque d'une faction = époque du joueur + décalage ;
---   credit           : multiplie les MU réellement livrées au QG de la faction ;
---   gate_build_hours : durée du chantier de Porte d'une faction (nil : pas de course à la Porte).
X.PVP_KEYS = { "peaceful", "easy", "normal", "hard", "merciless" } -- miroir de F.pvp_order (lot IA0)
X.difficulty = {
  { key = "peaceful", fr = "Paisible", en = "Peaceful", evolution_offset = -0.05, epoch_offset = -2, credit = 0.6 },
  { key = "easy", fr = "Facile", en = "Easy", evolution_offset = -0.05, epoch_offset = -1, credit = 0.7 },
  { key = "normal", fr = "Normal", en = "Normal", evolution_offset = 0, epoch_offset = 0, credit = 0.85 },
  { key = "hard", fr = "Difficile", en = "Hard", evolution_offset = 0.03, epoch_offset = 0, credit = 1.3, gate_build_hours = 9 },
  { key = "merciless", fr = "Impitoyable", en = "Merciless", evolution_offset = 0.06, epoch_offset = 1, credit = 1.6, gate_build_hours = 6,
    beats_nominal_fr = "voulu : en Impitoyable, une faction ouvre sa Porte 1 h avant le joueur qui suit le rythme nominal ; il faut aller plus vite ou raser son chantier" },
}
function X.difficulty_of(key)
  for _, d in ipairs(X.difficulty) do if d.key == key then return d end end
  return nil
end

--- Course à la Porte (Difficile, Impitoyable ; QX3). Le chantier d'une faction COMMENCE quand le joueur
--- atteint l'époque 15 (centre au niveau 15) ; il dure gate_build_hours ; le détruire le remet à ZÉRO et
--- rend au joueur 30 % des matériaux investis (raid façon Clash of Clans).
X.gate_race = { start_fr = "le joueur atteint l'époque 15 (centre au niveau 15)", reset_on_destroy = true, refund = 0.30 }
--- Heure nominale d'ouverture de la Porte du joueur (fin de l'époque 15).
function X.player_gate_hour() return X.reach_hour(X.EPOCHS) + X.epoch_hours(X.EPOCHS) end

--- Économie d'archive hybride (greffe P3, seuils corrigés) : le minage RÉEL des avant-postes (MU livrées au
--- QG) fait progresser l'époque de la faction ; la difficulté pondère le crédit ; l'époque est plafonnée
--- par celle du joueur décalée. Seuil de l'époque k INDEXÉ SUR LE CALENDRIER : débit de référence d'une
--- faction (2,5 MU/s, mesuré en moteur réel : 1,4 à 3,2 MU/s à 60 min, BALANCE_SHEET §10) × heure
--- nominale où le joueur atteint k. Une faction Normal (crédit 0,85) arrive donc à chaque époque environ
--- 18 % après le joueur, sans buter sur son plafond.
X.FACTION_REF_MU_S = 2.5
function X.faction_threshold(k)
  return X.FACTION_REF_MU_S * 3600 * X.reach_hour(k)
end
function X.faction_epoch(mu_delivered, player_epoch, difficulty)
  local cap = math.max(1, math.min(X.EPOCHS, player_epoch + difficulty.epoch_offset))
  local credited = mu_delivered * difficulty.credit
  local e = 1
  while e < cap and credited >= X.faction_threshold(e + 1) do e = e + 1 end
  return e
end
--- Époque du joueur nominal à l'heure h.
function X.nominal_epoch_at(h)
  local k = 1
  while k < X.EPOCHS and X.reach_hour(k + 1) <= h do k = k + 1 end
  return k
end

X.faction_units = {
  { epoch = 1, fr = "Fusilier", en = "Rifleman", existing = true },
  { epoch = 2, fr = "Mitrailleur", en = "Machine gunner", existing = true },
  { epoch = 3, fr = "Grenadier", en = "Grenadier", existing = true },
  { epoch = 8, fr = "Lance-flammes", en = "Flame trooper" },
  { epoch = 10, fr = "Exo-fantassin laser", en = "Laser exo-trooper" },
  { epoch = 13, fr = "Mécha léger", en = "Light mech" },
}

---------------------------------------------------------------------------------------------------
-- 16. Boucle « presque idle » (greffe P3) : 5 jalons par époque, médaille, score de puissance.
---------------------------------------------------------------------------------------------------
X.milestone_kinds = { "production", "construction", "research", "defense", "exploration" }
X.MILESTONE_RESEARCH_SHARE = 0.6        -- 60 % des technologies de l'époque
--- Jalon de recherche : 60 % des technologies nouvelles de l'époque (dénominateur : X.technologies).
function X.milestone_research(k)
  local n = 0
  for _, t in ipairs(X.technologies) do if t.epoch == k then n = n + 1 end end
  return math.ceil(X.MILESTONE_RESEARCH_SHARE * n), n
end
function X.milestone_defense_nests(k) return 2 + k end
X.MILESTONE_CRATE_SHARE = 0.05          -- caisse : 5 % du lot de passage du centre
function X.milestone_speedup_minutes(k) return 5 * k end
X.medal_bonus = {
  { key = "mining", fr = "+2 % de productivité minière", modifier = "mining_drill_productivity_bonus", value = 0.02 },
  { key = "research", fr = "+5 % de vitesse de recherche", modifier = "laboratory_speed_modifier", value = 0.05 },
  { key = "crafting", fr = "+5 % de fabrication manuelle", modifier = "manual_crafting_speed_modifier", value = 0.05 },
}
X.power_score = { per_epoch = 500, per_wonder = 2000, per_milestone = 50 }
function X.power(levels_weighted, epoch, wonders, milestones)
  return levels_weighted + X.power_score.per_epoch * epoch + X.power_score.per_wonder * wonders + X.power_score.per_milestone * milestones
end
-- Chantiers de zone (greffe P3, à valider par V2) : un ouvrier améliore jusqu'à 10 bâtiments identiques
-- dans un rayon de 20 tuiles ; familles de production seulement, les défenses restent à l'unité.
X.zone_upgrade = { max_buildings = 10, radius = 20, time_per_extra = 0.1 }
function X.zone_upgrade_factors(n) return 1 + X.zone_upgrade.time_per_extra * (n - 1), n end

---------------------------------------------------------------------------------------------------
-- 17. Index (construits avec ipairs ; à appeler une fois).
---------------------------------------------------------------------------------------------------
function X.index()
  local idx = { item = {}, building = {}, recipe = {}, resource = {}, epoch = {}, branch = {} }
  for _, it in ipairs(X.items) do idx.item[it.name] = it end
  for _, b in ipairs(X.buildings) do idx.building[b.name] = b end
  for _, r in ipairs(X.recipes) do idx.recipe[r.name] = r end
  for _, res in ipairs(X.resources) do idx.resource[res.name] = res end
  for _, e in ipairs(X.epochs) do idx.epoch[e.n] = e end
  for _, br in ipairs(X.branches) do idx.branch[br.key] = br end
  return idx
end

return X
