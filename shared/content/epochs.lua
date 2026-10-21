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
]]

local X = {}

X.VERSION = 1
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
}
X.DOC_PHRASES = {
  { key = "item_amount_max", proto = "RecipePrototype.ingredients", text = "The maximum ingredient amount is 65535" },
  { key = "empty_ingredients", proto = "RecipePrototype.ingredients", text = "Can be set to an empty table to create a recipe that needs no ingredients" },
  { key = "empty_results", proto = "RecipePrototype.results", text = "Can be set to an empty table to create a recipe that produces nothing" },
  { key = "duplicate_ingredients", proto = "RecipePrototype.ingredients", text = "Duplicate ingredients, e.g. two entries with the same name, are *not* allowed" },
  { key = "energy_required_min", proto = "RecipePrototype.energy_required", text = "Must be `> 0.001`" },
  { key = "crafting_no_fluid", proto = "RecipePrototype.category", text = "can not contain recipes with fluid ingredients or products" },
  { key = "name_max_length", proto = "PrototypeBase.name", text = "May not contain a dot, nor exceed a length of 200 characters" },
  { key = "wire_distance_max", proto = "ElectricPolePrototype.maximum_wire_distance", text = "Max value is 64" },
  { key = "furnace_item_inputs_max", proto = "FurnacePrototype.source_inventory_size", text = "The number of input slots, but not more than 1" },
  { key = "reactor_no_heat", proto = "ReactorPrototype.energy_source", text = "May not be a heat energy source" },
  { key = "locomotive_burner", proto = "LocomotivePrototype.energy_source", text = "BurnerEnergySource" },
  { key = "silo_products_ignored", proto = "RocketSiloPrototype.rocket_parts_required", text = "Recipe products are ignored" },
  { key = "probability_range", proto = "ItemProductPrototype.probability", text = "Value between 0 and 1" },
}

---------------------------------------------------------------------------------------------------
-- 2. Les 15 époques (liste d'OBJECTIFS §6 validée par Q7). Durée : F1-3 + greffe P2 (0,5 h × k,
--    plafonnée à 7 h : 59,5 h au total). Palier logistique : un toutes les 3 époques (Q5).
---------------------------------------------------------------------------------------------------
X.TIER_DENSITY = { 1, 2, 4, 8, 32 } -- ρ des paliers T1 à T5 (BALANCE_SHEET §3)

X.epochs = {
  { n = 1, key = "pioneer", fr = "Pionnier", en = "Pioneer", act = 1,
    pack = "automation-science-pack",
    currency = { "iron-plate", "copper-plate", "stone-brick", "electronic-circuit" },
    energy_fr = "brûleurs (charbon, bois)",
    reveal_fr = "Sur la carte, des anomalies gravimétriques qu'aucun instrument ne lit.",
    pressure_fr = "délai de grâce, petits déchiqueteurs",
    milestones = { production = { "iron-plate", 1000 }, construction = { "fo-burner-assembler", 4 }, exploration = { chart = 64 } } },
  { n = 2, key = "forge", fr = "Forge", en = "Forge", act = 1,
    pack = "logistic-science-pack",
    currency = { "steel-plate", "fo-cement" },
    energy_fr = "coke",
    reveal_fr = "Les balises des quatre autres équipages du Convoi : ils ont survécu.",
    pressure_fr = "premières patrouilles des factions",
    milestones = { production = { "steel-plate", 400 }, construction = { "fo-blast-furnace", 2 }, exploration = { chart = 128 } } },
  { n = 3, key = "steam", fr = "Vapeur", en = "Steam", act = 1,
    pack = "military-science-pack",
    currency = { "fo-manometer", "concrete" },
    energy_fr = "vapeur : 1,8 MW par chaudière",
    reveal_fr = "La planète rayonne plus de chaleur qu'elle n'en reçoit.",
    pressure_fr = "raids de déchiqueteurs plus gros",
    milestones = { production = { "concrete", 1000 }, construction = { "fo-steam-hammer", 4 }, exploration = { chart = 192 } } },
  { n = 4, key = "oil", fr = "Pétrole", en = "Oil", act = 1,
    pack = "chemical-science-pack",
    currency = { "plastic-bar", "advanced-circuit" },
    energy_fr = "combustible solide, vapocraquage",
    reveal_fr = "Le pétrole d'Érèbe est trop jeune : il se forme encore, chauffé d'en dessous.",
    pressure_fr = "premières attaques organisées des factions (Normal)",
    milestones = { production = { "plastic-bar", 1000 }, construction = { "fo-steam-cracker", 2 }, exploration = { resource = "crude-oil" } } },
  { n = 5, key = "volcano", fr = "Volcan", en = "Volcano", act = 2,
    pack = "fo-geological-pack",
    currency = { "fo-tungsten-plate", "fo-tungsten-carbide" },
    energy_fr = "géothermie : 4,2 MW par fumerolle, infinie",
    reveal_fr = "Le flux géothermique est 40 fois trop fort : quelque chose chauffe le manteau.",
    pressure_fr = "blindés et ignés (cendres)",
    milestones = { production = { "fo-tungsten-plate", 500 }, construction = { "fo-geothermal-tap", 3 }, exploration = { resource = "fo-fumarole" } } },
  { n = 6, key = "electricity", fr = "Électricité", en = "Electricity", act = 2,
    pack = "production-science-pack",
    currency = { "fo-coil", "battery" },
    energy_fr = "accumulateurs, haute tension",
    reveal_fr = "Les orages magnétiques suivent les anomalies.",
    pressure_fr = "foudroyants attirés par les réseaux",
    milestones = { production = { "fo-coil", 300 }, construction = { "fo-arc-furnace", 2 }, exploration = { chart = 384 } } },
  { n = 7, key = "crystal", fr = "Cristal", en = "Crystal", act = 2,
    pack = "fo-resonance-pack",
    currency = { "fo-resonance-lens", "fo-crystal-oscillator" },
    energy_fr = "cristal chargé (énergie transportable, 80 %)",
    reveal_fr = "Les cristaux chantent sans source : la Ligue Azur publie l'hypothèse de la Caustique (A-I).",
    pressure_fr = "foudroyants renforcés",
    milestones = { production = { "fo-resonance-lens", 200 }, construction = { "fo-resonance-amplifier", 4 }, exploration = { resource = "fo-resonance-crystal" } } },
  { n = 8, key = "marsh", fr = "Marais", en = "Marsh", act = 2,
    pack = "fo-biochemical-pack",
    currency = { "fo-biopolymer", "fo-methanotroph-culture" },
    energy_fr = "turbine à gaz : 10 MW",
    reveal_fr = "La vie d'Érèbe digère le méthane du sous-sol chauffé.",
    pressure_fr = "couvées",
    milestones = { production = { "fo-biopolymer", 400 }, construction = { "fo-bioreactor", 4 }, exploration = { resource = "fo-methane" } } },
  { n = 9, key = "atom", fr = "Atome", en = "Atom", act = 2,
    pack = "fo-isotopic-pack",
    currency = { "fo-lead-shielding", "uranium-fuel-cell" },
    energy_fr = "fission : 40 MW par réacteur",
    reveal_fr = "Le cuivre irradié émet des positons : premier piège d'antimatière (B-I).",
    pressure_fr = "l'Ordre Écarlate cherche l'arme absolue",
    milestones = { production = { "fo-lead-shielding", 300 }, construction = { "nuclear-reactor", 1 }, exploration = { resource = "fo-galena" } } },
  { n = 10, key = "hightech", fr = "Haute technologie", en = "High technology", act = 3,
    pack = "utility-science-pack",
    currency = { "processing-unit", "fo-silicon-wafer" },
    energy_fr = "aucune source nouvelle ; concentrés ρ8",
    reveal_fr = "Un réseau de cristal gravé oscille sans énergie : premier cristal temporel (C-I).",
    pressure_fr = "exo-fantassins laser des factions",
    milestones = { production = { "processing-unit", 300 }, construction = { "fo-cleanroom", 2 }, exploration = { chart = 640 } } },
  { n = 11, key = "titanium", fr = "Titane", en = "Titanium", act = 3,
    pack = "fo-structural-pack",
    currency = { "fo-titanium-plate", "fo-titanium-composite" },
    energy_fr = "aucune source nouvelle",
    reveal_fr = "La brèche des cratères contient des inclusions trop denses : de la matière étrange (D-I).",
    pressure_fr = "nids de famille plus loin, plus gros",
    milestones = { production = { "fo-titanium-plate", 100 }, construction = { "fo-kroll-reactor", 2 }, exploration = { resource = "fo-ilmenite" } } },
  { n = 12, key = "superconductors", fr = "Supraconducteurs", en = "Superconductors", act = 3,
    pack = "fo-magnetic-pack",
    currency = { "fo-superconducting-coil", "fo-permanent-magnet" },
    energy_fr = "sels fondus : 160 MW ; accumulateur supraconducteur",
    reveal_fr = "L'haloscope capte la matière noire ; la Caustique a une marée (A-II).",
    pressure_fr = "les factions passent à l'époque 12 selon la difficulté",
    milestones = { production = { "fo-superconducting-coil", 100 }, construction = { "fo-molten-salt-reactor", 1 }, exploration = { resource = "fo-caustic-vein" } } },
  { n = 13, key = "fusion", fr = "Fusion", en = "Fusion", act = 3,
    pack = "fo-plasma-pack",
    currency = { "fo-fusion-pellet", "fo-plasma-cell" },
    energy_fr = "fusion D-³He : 800 MW",
    reveal_fr = "Antimatière en quantité, strangelets (B-II, D-II). Le Serment : le joueur choisit sa doctrine.",
    pressure_fr = "la rivale jurée attaque davantage",
    milestones = { production = { "fo-plasma-cell", 100 }, construction = { "fo-fusion-reactor", 1 }, exploration = { resource = "fo-mantle-vent" } } },
  { n = 14, key = "orbit", fr = "Orbite", en = "Orbit", act = 4,
    pack = "space-science-pack",
    currency = { "fo-superalloy", "fo-iridium-mirror" },
    energy_fr = "orbitale : 50 MW par centrale lancée",
    reveal_fr = "Révélation : le Convoi venait ouvrir une Porte sur le trou noir du Cœur.",
    pressure_fr = "pluies de météorites, course à la Porte des factions",
    milestones = { production = { "fo-superalloy", 50 }, construction = { "fo-rectenna", 2 }, exploration = { resource = "fo-meteor-impact" } } },
  { n = 15, key = "legend", fr = "Légende", en = "Legend", act = 4,
    pack = "fo-exotic-pack",
    currency = { "fo-stabilized-exotic-matter" },
    energy_fr = "annihilation : 2 GW (maîtrise B-III)",
    reveal_fr = "Le Cœur s'éveille : failles, primordiaux, Marée du Cœur.",
    pressure_fr = "Marée du Cœur (siège final)",
    milestones = { production = { "fo-stabilized-exotic-matter", 50 }, construction = { "fo-casimir-stabilizer", 2 }, exploration = { resource = "fo-core-rift" } } },
}

X.acts = {
  { n = 1, fr = "Survivre", en = "Survive", epochs = { 1, 4 } },
  { n = 2, fr = "La planète est étrange", en = "The planet is wrong", epochs = { 5, 9 } },
  { n = 3, fr = "Dompter les nouvelles physiques", en = "Taming the new physics", epochs = { 10, 13 } },
  { n = 4, fr = "La vérité et la Porte", en = "The truth and the Gate", epochs = { 14, 15 } },
}

--- Durée de l'époque k en heures (greffe P2 : 0,5 h × k, plafonnée à 7 h).
function X.epoch_hours(k) return math.min(0.5 * k, 7) end
--- Palier logistique (Compaction) de l'époque k : T1 aux époques 1-3, T2 aux 4-6… T5 aux 13-15.
function X.logistics_tier(k) return math.floor((k - 1) / 3) + 1 end
--- Ouvriers d'amélioration : un de plus toutes les 3 époques (1 à 5) ; +1 avec l'Horloge éternelle.
function X.builders(k, has_eternal_clock) return X.logistics_tier(k) + (has_eternal_clock and 1 or 0) end
--- Niveau maximal d'un bâtiment quand le centre est à l'époque k (Q6 : 2 niveaux par époque).
function X.max_building_level(k) return 2 * k end

--- Débit visé de l'usine du joueur en MU/s à l'époque k (greffe P2 : de 3 à 14 000 MU/s, géométrique).
X.RATE_FIRST, X.RATE_LAST = 3, 14000
function X.rate(k) return X.RATE_FIRST * (X.RATE_LAST / X.RATE_FIRST) ^ ((k - 1) / (X.EPOCHS - 1)) end
--- Budget de l'époque k en MU : débit × durée.
function X.budget(k) return X.rate(k) * 3600 * X.epoch_hours(k) end
--- Passage du centre de k à k+1 (gabarit P3) : un Codex k plus un lot de monnaie d'époque de 10 % du
--- budget de l'époque, en MU (à convertir par V2 en objets : L.tier_costs, niveaux 2k-1 et 2k).
X.CODEX_LOT_SHARE = 0.10
function X.cc_upgrade_mu(k) return X.CODEX_LOT_SHARE * X.budget(k) end

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
  if opts.military and k > 3 then out[#out + 1] = "military-science-pack" end
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
    yields_fr = "minage infini n'importe où (puits gravitique), bouclier de marée, Observatoire" },
  { key = "B", id = "antimatter", fr = "Antimatière", en = "Antimatter", faction = "scarlet",
    data = "fo-annihilation-data", mechanic = "confinement", epochs = { 9, 13, 14 },
    gate_item = "fo-antihydrogen-trap",
    mechanic_fr = "confinement : 5 s sans courant et les pièges pleins s'annihilent",
    yields_fr = "énergie de fin de partie, obus et lance d'annihilation, sonde profonde" },
  { key = "C", id = "chronodynamics", fr = "Chronodynamique", en = "Chronodynamics", faction = "amber",
    data = "fo-chronometric-data", mechanic = "dilation", epochs = { 10, 11, 14 },
    gate_item = "fo-stable-time-crystal",
    mechanic_fr = "dilatation : accélère les machines voisines ; sabliers sur les chantiers",
    yields_fr = "vitesse, chantiers et recherche accélérés, coffres intriqués, 6e ouvrier" },
  { key = "D", id = "strange-matter", fr = "Matière étrange", en = "Strange matter", faction = "emerald",
    data = "fo-hadronic-data", mechanic = "contagion", epochs = { 11, 13, 14 },
    gate_item = "fo-strange-plate",
    mechanic_fr = "croissance autocatalytique ; une cuve qui déborde contamine le sol",
    yields_fr = "transmutation de la pierre en minerais rares, puits des déchets, murs et armure" },
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
  { name = "fo-fumarole", epoch = 5, kind = "fluid", category = "fo-fumarole", product = "fo-volcanic-gas",
    biome = "fo-volcanic-ash", infinite = true, minimum_share = 0.2,
    fr = "Fumerolle", en = "Fumarole", where_fr = "cendres volcaniques" },
  { name = "fo-galena", epoch = 9, kind = "ore", category = "basic-solid", product = "fo-galena",
    biome = nil, min_distance = 300,
    fr = "Galène", en = "Galena", where_fr = "gisements classiques à plus de 300 tuiles du départ" },
  { name = "fo-ilmenite", epoch = 11, kind = "ore", category = "fo-hard-solid", product = "fo-ilmenite-ore",
    biome = "fo-crater-fields", fr = "Ilménite", en = "Ilmenite", where_fr = "champs de cratères (nouveau biome)" },
  { name = "fo-brine", epoch = 11, kind = "fluid", category = "basic-fluid", product = "fo-brine",
    biome = "fo-crater-fields", infinite = true, minimum_share = 0.2,
    fr = "Lac de saumure", en = "Brine lake", where_fr = "fond des cratères" },
  { name = "fo-impact-breccia", epoch = 11, kind = "ore", category = "basic-solid", product = "stone",
    biome = "fo-crater-fields", branch = "D", level = 1,
    fr = "Brèche d'impact", en = "Impact breccia", where_fr = "remparts des cratères" },
  { name = "fo-monazite", epoch = 12, kind = "ore", category = "basic-solid", product = "fo-monazite-ore",
    biome = "fo-black-sands", fr = "Monazite", en = "Monazite", where_fr = "sables noirs (rivages)" },
  { name = "fo-caustic-vein", epoch = 12, kind = "special", category = "fo-caustic", product = "fo-dark-flux",
    biome = nil, infinite = true, branch = "A", level = 2, placement = "on_sector_scanned",
    fr = "Veine de caustique", en = "Caustic vein",
    where_fr = "partout ; posée par le script au balayage d'un secteur radar (1 veine garantie pour 20 à 25 chunks)" },
  { name = "fo-deep-upwelling", epoch = 12, kind = "special", category = "fo-deep", product = "fo-iron-concentrate",
    infinite = true, branch = "A", level = 2, placement = "under_gravity_well",
    fr = "Remontée profonde", en = "Deep upwelling", where_fr = "créée par le script sous un puits gravitique" },
  { name = "fo-mantle-vent", epoch = 13, kind = "fluid", category = "fo-mantle", product = "fo-helium-3",
    biome = "fo-volcanic-ash", infinite = true, minimum_share = 0.1,
    fr = "Évent mantellique", en = "Mantle vent", where_fr = "cœur des cendres volcaniques, rare" },
  { name = "fo-meteor-impact", epoch = 14, kind = "special", category = "fo-hard-solid", product = "fo-ferrous-meteorite",
    placement = "meteor_shower", tiles = { 5, 15 }, amount_per_tile = { 100, 300 },
    fr = "Impact météoritique", en = "Meteor impact", where_fr = "créé par les pluies de météorites (toutes les 20 à 40 min)" },
  { name = "fo-core-rift", epoch = 15, kind = "special", category = "fo-rift", product = "fo-raw-exotic-matter",
    infinite = true, placement = "core_awakening", count = { 3, 5 }, distance = { 600, 1200 },
    fr = "Faille du Cœur", en = "Core rift", where_fr = "3 à 5 failles posées au réveil du Cœur, gardées par des primordiaux" },
}

--- Ressources vanilla et ressources déjà livrées par le mod (shared/content/world.lua), avec leur époque.
X.base_resources = {
  { name = "iron-ore", epoch = 1 }, { name = "copper-ore", epoch = 1 }, { name = "coal", epoch = 1 },
  { name = "stone", epoch = 1 }, { name = "wood", epoch = 1 }, { name = "raw-fish", epoch = 1 },
  { name = "water", epoch = 3 }, { name = "crude-oil", epoch = 4 },
  { name = "fo-tungsten-ore", epoch = 5 }, { name = "fo-resonance-crystal", epoch = 7 },
  { name = "fo-methane", epoch = 8 }, { name = "uranium-ore", epoch = 9 },
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
---------------------------------------------------------------------------------------------------
local items = {}
local function I(name, epoch, fr, en, o)
  o = o or {}
  o.name, o.epoch, o.fr, o.en = name, epoch, fr, en
  o.type = o.type or "item"
  items[#items + 1] = o
  return o
end
local function F(name, epoch, fr, en, o)
  o = o or {}
  o.type = "fluid"
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
F("fo-dark-flux", 12, "Flux sombre", "Dark flux", { branch = "A", level = 2 })
I("fo-codex-12", 12, "Codex XII : traité des aimants", "Codex XII: treatise on magnets", { use = "codex" })
-- Époque 13
I("fo-degassed-ilmenite", 13, "Ilménite dégazée ρ8", "Degassed ilmenite ρ8", { material = true, rho = 8 })
I("fo-fusion-pellet", 13, "Pastille de fusion", "Fusion pellet",
  { fuel = 80000, fuel_category = "fo-fusion", whitelist_fr = "fusion : source d'énergie primaire" })
I("fo-catalyzed-fusion-pellet", 13, "Pastille de fusion catalysée", "Catalyzed fusion pellet",
  { fuel = 160000, fuel_category = "fo-fusion", branch = "B", level = 2,
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
F("fo-plasma", 13, "Plasma", "Plasma", { temperature = 5000 })
I("fo-codex-13", 13, "Codex XIII : journal du confinement", "Codex XIII: confinement journal", { use = "codex" })
-- Époque 14
I("fo-ferrous-meteorite", 14, "Météorite ferreuse ρ8", "Ferrous meteorite ρ8", { material = true, rho = 8, source = "mining" })
I("fo-strange-meteorite", 14, "Météorite étrange ρ8", "Strange meteorite ρ8", { rho = 8 })
I("fo-nickel-iron", 14, "Ferronickel ρ8", "Nickel-iron ρ8", { material = true, rho = 8 })
I("fo-iridium", 14, "Iridium", "Iridium")
I("fo-superalloy", 14, "Superalliage ρ32", "Superalloy ρ32", { material = true, rho = 32 })
I("fo-iridium-mirror", 14, "Miroir d'iridium", "Iridium mirror")
I("fo-cryogenic-propellant", 14, "Ergol cryogénique", "Cryogenic propellant")
I("fo-orbital-tug", 14, "Remorqueur orbital", "Orbital tug", { use = "launch" })
I("fo-orbital-solar-plant", 14, "Centrale solaire orbitale", "Orbital solar plant", { use = "launch" })
I("fo-deep-probe", 14, "Sonde profonde", "Deep probe", { use = "launch", branch = "B", level = 3 })
I("fo-strange-armor", 14, "Armure étrange", "Strange armor", { use = "armor", branch = "D", level = 3 })
F("fo-liquid-hydrogen", 14, "Hydrogène liquide", "Liquid hydrogen", { temperature = -253 })
I("fo-codex-14", 14, "Codex XIV : archives orbitales de l'Arche", "Codex XIV: the Ark's orbital archives", { use = "codex" })
-- Époque 15
F("fo-raw-exotic-matter", 15, "Matière exotique brute", "Raw exotic matter")
I("fo-casimir-cavity", 15, "Cavité de Casimir", "Casimir cavity")
I("fo-stabilized-exotic-matter", 15, "Matière exotique stabilisée", "Stabilized exotic matter")
I("fo-exotic-pack", 15, "Pack exotique", "Exotic science pack", { use = "pack" })
I("fo-ring-segment", 15, "Segment d'anneau", "Ring segment", { note_fr = "« pièce » de la Porte : produit ignoré par le moteur, compté comme une pièce de fusée" })
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

B{ name = "fo-burner-assembler", epoch = 1, fr = "Atelier à combustion", en = "Burner workshop",
   proto = "assembling-machine", size = { 3, 3 }, energy = BURN, kw = 150, speed = 0.5,
   categories = { "crafting", "basic-crafting", "advanced-crafting" } }
B{ name = "fo-burner-lab", epoch = 1, fr = "Laboratoire à combustion", en = "Burner laboratory",
   proto = "lab", size = { 3, 3 }, energy = BURN, kw = 120, speed = 0.5,
   inputs = { "automation-science-pack", "logistic-science-pack" } }
B{ name = "fo-coke-oven", epoch = 2, fr = "Four à coke", en = "Coke oven",
   proto = "assembling-machine", size = { 3, 3 }, energy = BURN, kw = 180, speed = 1, categories = { "fo-coking" } }
B{ name = "fo-blast-furnace", epoch = 2, fr = "Haut fourneau", en = "Blast furnace",
   proto = "assembling-machine", size = { 4, 4 }, energy = BURN, kw = 600, speed = 1, categories = { "fo-blast-furnace" } }
B{ name = "fo-crusher", epoch = 2, fr = "Concasseur", en = "Crusher",
   proto = "assembling-machine", size = { 2, 2 }, energy = BURN, kw = 120, speed = 1, categories = { "fo-crushing" } }
B{ name = "fo-steam-hammer", epoch = 3, fr = "Marteau-pilon à vapeur", en = "Steam hammer",
   proto = "assembling-machine", size = { 3, 3 }, energy = { type = "fluid", fluid = "steam" }, kw = 900, speed = 1,
   categories = { "fo-forging" } }
B{ name = "fo-flare-stack", epoch = 4, fr = "Torchère", en = "Flare stack",
   proto = "furnace", size = { 2, 2 }, energy = ELEC, kw = 50, speed = 1, categories = { "fo-flaring" }, fluid_in = 1 }
B{ name = "fo-steam-cracker", epoch = 4, fr = "Vapocraqueur", en = "Steam cracker",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 600, speed = 1, categories = { "fo-cracking" },
   fluid_in = 2, fluid_out = 1 }
B{ name = "fo-geothermal-tap", epoch = 5, fr = "Capteur géothermique", en = "Geothermal tap",
   proto = "mining-drill", size = { 3, 3 }, energy = ELEC, kw = 300, mining_speed = 1,
   resource_categories = { "fo-fumarole" }, output_fluid = true }
B{ name = "fo-sintering-furnace", epoch = 5, fr = "Four de frittage", en = "Sintering furnace",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 600, speed = 1, categories = { "fo-sintering" },
   fluid_in = 1, fluid_out = 1 }
B{ name = "fo-heavy-drill", epoch = 5, fr = "Foreuse lourde", en = "Heavy drill",
   proto = "mining-drill", size = { 3, 3 }, energy = ELEC, kw = 400, mining_speed = 1,
   resource_categories = { "basic-solid", "fo-hard-solid" } }
B{ name = "fo-arc-furnace", epoch = 6, fr = "Four à arc", en = "Arc furnace",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 3000, speed = 2, categories = { "fo-arc-smelting" },
   fluid_in = 1 }
B{ name = "fo-coil-winder", epoch = 6, fr = "Bobineuse", en = "Coil winder",
   proto = "assembling-machine", size = { 2, 2 }, energy = ELEC, kw = 200, speed = 1, categories = { "fo-winding" },
   fluid_in = 1 }
B{ name = "fo-ht-pylon", epoch = 6, fr = "Pylône haute tension", en = "High-voltage pylon",
   proto = "electric-pole", size = { 2, 2 }, wire_distance = 64, supply_distance = 0.5 }
B{ name = "fo-jaw-crusher", epoch = 6, fr = "Broyeur à mâchoires", en = "Jaw crusher",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 500, speed = 2, categories = { "fo-crushing" } }
B{ name = "fo-lapidary", epoch = 7, fr = "Taillerie", en = "Lapidary",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 400, speed = 1, categories = { "fo-lapidary" },
   fluid_in = 1 }
B{ name = "fo-resonance-amplifier", epoch = 7, fr = "Amplificateur de résonance", en = "Resonance amplifier",
   proto = "beacon", size = { 3, 3 }, energy = ELEC, kw = 600, slots = 3, distribution = 0.75, supply_distance = 3 }
B{ name = "fo-caustic-resonator", epoch = 7, fr = "Résonateur de caustique", en = "Caustic resonator",
   proto = "assembling-machine", size = { 2, 2 }, energy = ELEC, kw = 500, speed = 1, categories = { "fo-caustic-sensing" },
   fixed_recipe = "fo-gravimetric-survey", branch = "A", level = 1, rule_fr = "actif seulement à 64 tuiles au plus d'une veine" }
B{ name = "fo-charging-station", epoch = 7, fr = "Station de charge", en = "Charging station",
   proto = "assembling-machine", size = { 2, 2 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-charging" } }
B{ name = "fo-crystal-generator", epoch = 7, fr = "Générateur à cristal", en = "Crystal generator",
   proto = "burner-generator", size = { 2, 2 }, energy = { type = "burner", fuel_category = "fo-electric-storage" },
   burnt_inventory = true, output_kw = 1000 }
B{ name = "fo-reformer", epoch = 8, fr = "Reformeur", en = "Reformer",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 1000, speed = 1, categories = { "fo-reforming" },
   fluid_in = 2, fluid_out = 2 }
B{ name = "fo-electrolyzer", epoch = 8, fr = "Électrolyseur", en = "Electrolyzer",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 3000, speed = 1, categories = { "fo-electrolysis" },
   fluid_in = 1, fluid_out = 2 }
B{ name = "fo-bioreactor", epoch = 8, fr = "Bioréacteur", en = "Bioreactor",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 300, speed = 1, categories = { "fo-bioprocessing" },
   fluid_in = 2, fluid_out = 1 }
B{ name = "fo-gas-turbine", epoch = 8, fr = "Turbine à gaz", en = "Gas turbine",
   proto = "generator", size = { 3, 5 }, burns_fluid = "fo-methane", output_kw = 10000, fluid_per_s = 6.7 }
B{ name = "fo-irradiator", epoch = 9, fr = "Irradiateur", en = "Irradiator",
   proto = "assembling-machine", size = { 3, 3 }, energy = { type = "heat", min_temperature = 500 }, kw = 10000, speed = 1,
   categories = { "fo-irradiation" }, branch = "B", level = 1 }
B{ name = "fo-positron-moderator", epoch = 9, fr = "Modérateur de positons", en = "Positron moderator",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 2000, speed = 1, categories = { "fo-positron" },
   branch = "B", level = 1, confinement = true }
B{ name = "fo-cooling-pool", epoch = 9, fr = "Piscine d'entreposage", en = "Cooling pool",
   proto = "assembling-machine", size = { 4, 4 }, energy = { type = "void" }, kw = 0, speed = 1, categories = { "fo-cooling" } }
B{ name = "fo-geological-repository", epoch = 9, fr = "Dépôt géologique", en = "Geological repository",
   proto = "container", size = { 6, 6 }, inventory = 200 }
B{ name = "fo-cleanroom", epoch = 10, fr = "Salle blanche", en = "Cleanroom",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 4000, speed = 1, categories = { "fo-cleanroom" },
   fluid_in = 1 }
B{ name = "fo-phased-array-radar", epoch = 10, fr = "Radar à réseau phasé", en = "Phased-array radar",
   proto = "radar", size = { 3, 3 }, energy = ELEC, kw = 1200, sector_range_factor = 3 }
B{ name = "fo-ore-concentrator", epoch = 10, fr = "Concentrateur", en = "Ore concentrator",
   proto = "assembling-machine", size = { 2, 2 }, energy = ELEC, kw = 1000, speed = 1, categories = { "fo-concentrating" },
   rule_fr = "accolé à une foreuse lourde, en insertion directe (BALANCE_SHEET §4)" }
B{ name = "fo-kroll-reactor", epoch = 11, fr = "Réacteur de Kroll", en = "Kroll reactor",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 2000, speed = 1, categories = { "fo-kroll" },
   fluid_in = 1 }
B{ name = "fo-temporal-resonator", epoch = 11, fr = "Résonateur temporel", en = "Temporal resonator",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 8000, speed = 1, categories = { "fo-temporal" },
   fluid_in = 1, branch = "C", level = 2 }
B{ name = "fo-dilation-chamber", epoch = 11, fr = "Chambre de dilatation", en = "Dilation chamber",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 5000, speed = 1, categories = { "fo-dilation" },
   fixed_recipe = "fo-phase-maintenance", branch = "C", level = 2, speed_bonus_aura = 1.0, aura_radius = 3 }
B{ name = "fo-entangled-chest", epoch = 11, fr = "Coffre intriqué", en = "Entangled chest",
   proto = "linked-container", size = { 1, 1 }, inventory = 32, branch = "C", level = 2 }
B{ name = "fo-cryogenic-unit", epoch = 12, fr = "Unité cryogénique", en = "Cryogenic unit",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 4000, speed = 1, categories = { "fo-cryogenics" },
   fluid_in = 2, fluid_out = 3 }
B{ name = "fo-extraction-column", epoch = 12, fr = "Colonne d'extraction", en = "Extraction column",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 500, speed = 1, categories = { "fo-solvent-extraction" },
   fluid_in = 1 }
B{ name = "fo-molten-salt-reactor", epoch = 12, fr = "Réacteur à sels fondus", en = "Molten salt reactor",
   proto = "reactor", size = { 5, 5 }, energy = { type = "burner", fuel_category = "fo-thorium" }, burnt_inventory = true,
   heat_kw = 160000 }
B{ name = "fo-sc-accumulator", epoch = 12, fr = "Accumulateur supraconducteur", en = "Superconducting accumulator",
   proto = "accumulator", size = { 3, 3 }, buffer_mj = 200, flow_kw = 50000 }
B{ name = "fo-maglev-locomotive", epoch = 12, fr = "Locomotive maglev", en = "Maglev locomotive",
   proto = "locomotive", size = { 2, 6 }, energy = { type = "burner", fuel_category = "fo-electric-storage" },
   burnt_inventory = true, max_speed_factor = 2 }
B{ name = "fo-haloscope", epoch = 12, fr = "Haloscope", en = "Haloscope",
   proto = "mining-drill", size = { 5, 5 }, energy = ELEC, kw = 20000, mining_speed = 1,
   resource_categories = { "fo-caustic" }, output_fluid = true, branch = "A", level = 2 }
B{ name = "fo-gravitic-condenser", epoch = 12, fr = "Condenseur gravitique", en = "Gravitic condenser",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 15000, speed = 1, categories = { "fo-gravitic" },
   fluid_in = 2, branch = "A", level = 2 }
B{ name = "fo-gravity-well", epoch = 12, fr = "Puits gravitique", en = "Gravity well",
   proto = "mining-drill", size = { 5, 5 }, energy = { type = "burner", fuel_category = "fo-axion" }, burnt_inventory = true,
   kw = 2000, mining_speed = 1, resource_categories = { "fo-deep" }, branch = "A", level = 2 }
B{ name = "fo-isotope-column", epoch = 13, fr = "Colonne isotopique", en = "Isotope column",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 2000, speed = 1, categories = { "fo-isotope" },
   fluid_in = 1, fluid_out = 1 }
B{ name = "fo-fusion-reactor", epoch = 13, fr = "Réacteur à fusion", en = "Fusion reactor",
   proto = "reactor", size = { 7, 7 }, energy = { type = "burner", fuel_category = "fo-fusion" }, heat_kw = 800000,
   max_temperature = 5000 }
B{ name = "fo-plasma-injector", epoch = 13, fr = "Injecteur de plasma", en = "Plasma injector",
   proto = "boiler", size = { 3, 3 }, energy = { type = "heat", min_temperature = 1000 }, kw = 200000, target_temperature = 5000 }
B{ name = "fo-mhd-turbine", epoch = 13, fr = "Turbine MHD", en = "MHD turbine",
   proto = "generator", size = { 5, 5 }, output_kw = 200000, fluid_per_s = 40 }
B{ name = "fo-plasma-foundry", epoch = 13, fr = "Fonderie à plasma", en = "Plasma foundry",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 20000, speed = 1, categories = { "fo-plasma-casting" },
   fluid_in = 1 }
B{ name = "fo-deep-drill", epoch = 13, fr = "Foreuse profonde", en = "Deep drill",
   proto = "mining-drill", size = { 5, 5 }, energy = ELEC, kw = 5000, mining_speed = 1,
   resource_categories = { "fo-mantle" }, output_fluid = true }
B{ name = "fo-synchrotron", epoch = 13, fr = "Synchrotron", en = "Synchrotron",
   proto = "assembling-machine", size = { 9, 9 }, energy = ELEC, kw = 150000, speed = 1, categories = { "fo-synchrotron" },
   fluid_in = 1, branch = "B", level = 2, confinement = true }
B{ name = "fo-recombiner", epoch = 13, fr = "Recombineur", en = "Recombiner",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-recombination" },
   branch = "B", level = 2, confinement = true }
B{ name = "fo-hadron-compressor", epoch = 13, fr = "Compresseur hadronique", en = "Hadron compressor",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 100000, speed = 1, categories = { "fo-hadron" },
   fluid_in = 1, branch = "D", level = 2 }
B{ name = "fo-catalysis-vat", epoch = 13, fr = "Cuve de catalyse", en = "Catalysis vat",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 30000, speed = 1, categories = { "fo-catalysis" },
   branch = "D", level = 2, contagion = true }
B{ name = "fo-transmuter", epoch = 13, fr = "Transmutateur", en = "Transmuter",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 50000, speed = 1, categories = { "fo-transmutation" },
   branch = "D", level = 2 }
B{ name = "fo-strange-wall", epoch = 13, fr = "Mur étrange", en = "Strange wall",
   proto = "wall", size = { 1, 1 }, hp = 12000, branch = "D", level = 2 }
B{ name = "fo-rectenna", epoch = 14, fr = "Rectenna", en = "Rectenna",
   proto = "electric-energy-interface", size = { 6, 6 }, output_kw = 200000 }
B{ name = "fo-deflector-shield", epoch = 14, fr = "Bouclier de déviation", en = "Deflector shield",
   proto = "assembling-machine", size = { 4, 4 }, energy = ELEC, kw = 30000, radius = 48, scripted = true }
B{ name = "fo-gravity-well-2", epoch = 14, fr = "Puits gravitique II", en = "Gravity well II",
   proto = "mining-drill", size = { 5, 5 }, energy = { type = "burner", fuel_category = "fo-axion" }, burnt_inventory = true,
   kw = 4000, mining_speed = 4, resource_categories = { "fo-deep" }, branch = "A", level = 3 }
B{ name = "fo-tidal-shield", epoch = 14, fr = "Bouclier de marée", en = "Tidal shield",
   proto = "electric-turret", size = { 4, 4 }, energy = ELEC, kw = 20000, radius = 30, slow = 0.7, branch = "A", level = 3 }
B{ name = "fo-caustic-observatory", epoch = 14, fr = "Observatoire de la Caustique", en = "Caustic Observatory",
   proto = "wonder", size = { 9, 9 }, wonder = true, branch = "A", level = 3 }
B{ name = "fo-annihilation-reactor", epoch = 14, fr = "Réacteur à annihilation", en = "Annihilation reactor",
   proto = "reactor", size = { 10, 10 }, energy = { type = "burner", fuel_category = "fo-antimatter" }, burnt_inventory = true,
   heat_kw = 2000000, branch = "B", level = 3, confinement = true }
B{ name = "fo-annihilation-lance", epoch = 14, fr = "Lance d'annihilation", en = "Annihilation lance",
   proto = "ammo-turret", size = { 4, 4 }, ammo = "fo-antimatter-microcharge", damage = 20000, range = 60, branch = "B", level = 3 }
B{ name = "fo-dilation-chamber-2", epoch = 14, fr = "Chambre de dilatation II", en = "Dilation chamber II",
   proto = "assembling-machine", size = { 3, 3 }, energy = ELEC, kw = 10000, speed = 1, categories = { "fo-dilation" },
   fixed_recipe = "fo-phase-maintenance", branch = "C", level = 3, speed_bonus_aura = 2.0, aura_radius = 3 }
B{ name = "fo-eternal-clock", epoch = 14, fr = "Horloge éternelle", en = "Eternal Clock",
   proto = "wonder", size = { 9, 9 }, wonder = true, branch = "C", level = 3 }
B{ name = "fo-neutronium-wall", epoch = 14, fr = "Mur de neutronium", en = "Neutronium wall",
   proto = "wall", size = { 1, 1 }, hp = 50000, branch = "D", level = 3 }
B{ name = "fo-strange-monolith", epoch = 14, fr = "Monolithe étrange", en = "Strange Monolith",
   proto = "wonder", size = { 9, 9 }, wonder = true, branch = "D", level = 3 }
B{ name = "fo-rift-anchor", epoch = 15, fr = "Ancre de faille", en = "Rift anchor",
   proto = "mining-drill", size = { 7, 7 }, energy = ELEC, kw = 100000, mining_speed = 1,
   resource_categories = { "fo-rift" }, output_fluid = true, input_fluid = true }
B{ name = "fo-casimir-stabilizer", epoch = 15, fr = "Stabilisateur de Casimir", en = "Casimir stabilizer",
   proto = "assembling-machine", size = { 5, 5 }, energy = ELEC, kw = 500000, speed = 1, categories = { "fo-casimir" },
   fluid_in = 1 }
B{ name = "fo-erebus-gate", epoch = 15, fr = "Porte d'Érèbe", en = "Erebus Gate",
   proto = "rocket-silo", size = { 10, 10 }, energy = ELEC, kw = 5000000, speed = 1, categories = { "fo-gate" },
   fixed_recipe = "fo-ring-segment", rocket_parts_required = 100, charge_minutes = 30 }

X.buildings = buildings

---------------------------------------------------------------------------------------------------
-- 8. Machines vanilla (et centre existant) utiles au graphe : catégories et puissance, relevées dans
--    data/base/prototypes/entity/entities.lua et mining-drill.lua (1.1.91).
---------------------------------------------------------------------------------------------------
X.base_machines = {
  { name = "character", hand = true, categories = { "crafting" }, resource_categories = { "basic-solid" }, kw = 0, speed = 1 },
  { name = "stone-furnace", categories = { "smelting" }, kw = 90, speed = 1, furnace = true },
  { name = "steel-furnace", categories = { "smelting" }, kw = 90, speed = 2, furnace = true },
  { name = "electric-furnace", categories = { "smelting" }, kw = 180, speed = 2, furnace = true },
  { name = "assembling-machine-1", categories = { "crafting", "basic-crafting", "advanced-crafting" }, kw = 75, speed = 0.5 },
  { name = "assembling-machine-2", categories = { "basic-crafting", "crafting", "advanced-crafting", "crafting-with-fluid" }, kw = 150, speed = 0.75, fluid_in = 1, fluid_out = 1 },
  { name = "assembling-machine-3", categories = { "basic-crafting", "crafting", "advanced-crafting", "crafting-with-fluid" }, kw = 375, speed = 1.25, fluid_in = 1, fluid_out = 1 },
  { name = "chemical-plant", categories = { "chemistry" }, kw = 210, speed = 1, fluid_in = 2, fluid_out = 2 },
  { name = "oil-refinery", categories = { "oil-processing" }, kw = 420, speed = 1, fluid_in = 2, fluid_out = 3 },
  { name = "centrifuge", categories = { "centrifuging" }, kw = 350, speed = 1 },
  { name = "rocket-silo", categories = { "rocket-building" }, kw = 4000, speed = 1 },
  { name = "burner-mining-drill", resource_categories = { "basic-solid" } },
  { name = "electric-mining-drill", resource_categories = { "basic-solid", "fo-hard-solid" } },
  { name = "pumpjack", resource_categories = { "basic-fluid" }, output_fluid = true },
  { name = "offshore-pump" },
  { name = "boiler" },
  { name = "heat-exchanger" },
  { name = "nuclear-reactor", fuel_category = "nuclear", burnt_inventory = true },
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
local DRILLS = { "character", "burner-mining-drill", "electric-mining-drill", "fo-heavy-drill" }
local HARD_DRILLS = { "electric-mining-drill", "fo-heavy-drill" }
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
R("fo-geological-pack", 5, "crafting", 12, { { "fo-carbide-bit", 1 }, { "sulfur", 1 }, { "stone", 2 } }, { { "fo-geological-pack", 2 } })
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
R("fo-resonance-pack", 7, "crafting", 14, { { "fo-resonance-lens", 1 }, { "fo-crystal-oscillator", 2 }, { "fo-coil", 1 } }, { { "fo-resonance-pack", 2 } })
R("fo-caustic-resonator", 7, "crafting", 8, { { "fo-resonance-lens", 4 }, { "fo-crystal-oscillator", 10 }, { "radar", 1 }, { "fo-tungsten-plate", 10 } }, { { "fo-caustic-resonator", 1 } },
  { branch = "A", level = 1 })
R("fo-gravimetric-survey", 7, "fo-caustic-sensing", 30, { { "fo-crystal-oscillator", 2 } }, { { "fo-gravimetric-survey", 1 } },
  { branch = "A", level = 1, fr = "Relevé gravimétrique", en = "Gravimetric survey" })
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
R("fo-biochemical-pack", 8, "chemistry", 15, { { "fo-methanotroph-culture", 1 }, { "fo-biopolymer", 2 }, { "sulfuric-acid", 20 } }, { { "fo-biochemical-pack", 2 } })
R("fo-codex-8", 8, "crafting", 30, { { "fo-biopolymer", 20 }, { "fo-methanotroph-culture", 5 }, { "fo-biochemical-pack", 10 } }, { { "fo-codex-8", 1 } })

-- Époque 9 · Atome (B-I) ---------------------------------------------------------------------------
R("fo-mine-galena", 9, nil, 1, {}, { { "fo-galena", 1 } }, { kind = "mining", resource = "fo-galena", machines = DRILLS, fr = "Minage : galène", en = "Mining: galena" })
R("fo-lead-plate", 9, "smelting", 3.2, { { "fo-galena", 2 } }, { { "fo-lead-plate", 1 } }, { dense = true, prod = true, fr = "Plomb", en = "Lead" })
R("fo-galena-roasting", 9, "fo-arc-smelting", 4, { { "fo-galena", 4 }, { "fo-oxygen", 20 } }, { { "fo-lead-plate", 3 }, { "sulfur", 1 } },
  { dense = true, fr = "Grillage de la galène", en = "Galena roasting" })
R("fo-lead-shielding", 9, "crafting", 3, { { "fo-lead-plate", 3 }, { "steel-plate", 1 } }, { { "fo-lead-shielding", 1 } }, { prod = true })
R("fo-isotopic-pack", 9, "crafting", 15, { { "fo-lead-plate", 2 }, { "uranium-238", 1 }, { "fo-crystal-oscillator", 1 } }, { { "fo-isotopic-pack", 2 } })
R("fo-irradiator", 9, "crafting", 10, { { "fo-lead-shielding", 20 }, { "heat-pipe", 20 }, { "advanced-circuit", 10 } }, { { "fo-irradiator", 1 } }, { branch = "B", level = 1 })
R("fo-positron-moderator", 9, "crafting", 10, { { "fo-lead-shielding", 10 }, { "fo-coil", 10 }, { "fo-tungsten-plate", 10 }, { "advanced-circuit", 10 } }, { { "fo-positron-moderator", 1 } },
  { branch = "B", level = 1 })
R("fo-copper-activation", 9, "fo-irradiation", 30, { { "copper-plate", 10 } }, { { "fo-activated-copper", 10 } },
  { branch = "B", level = 1, fr = "Activation du cuivre", en = "Copper activation" })
R("fo-magnetic-trap", 9, "crafting", 10, { { "fo-coil", 4 }, { "fo-lead-shielding", 2 }, { "advanced-circuit", 2 } }, { { "fo-magnetic-trap", 1 } }, { branch = "B", level = 1 })
R("fo-positron-capture", 9, "fo-positron", 60, { { "fo-activated-copper", 10 }, { "fo-magnetic-trap", 1 } }, { { "fo-positron-trap", 1 }, { "copper-plate", 10 } },
  { branch = "B", level = 1, fr = "Capture de positons", en = "Positron capture" })
R("fo-controlled-annihilation", 9, "fo-positron", 20, { { "fo-positron-trap", 1 } }, { { "fo-magnetic-trap", 1 }, { "fo-annihilation-data", 4 } },
  { branch = "B", level = 1, fr = "Annihilation contrôlée", en = "Controlled annihilation" })
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
R("fo-phase-measurement", 10, "fo-cleanroom", 20, { { "fo-unstable-time-crystal", 1 } }, { { "fo-chronometric-data", 4 }, { "fo-crystal-powder", 1 } },
  { branch = "C", level = 1, fr = "Mesure de phase", en = "Phase measurement" })
R("fo-ore-concentrator", 10, "advanced-crafting", 8, { { "steel-plate", 10 }, { "fo-coil", 4 }, { "processing-unit", 5 }, { "fo-tungsten-carbide", 10 } }, { { "fo-ore-concentrator", 1 } })
R("fo-iron-concentrate", 10, "fo-concentrating", 1, { { "iron-ore", 8 } }, { { "fo-iron-concentrate", 1 } }, { process = "compaction" })
R("fo-copper-concentrate", 10, "fo-concentrating", 1, { { "copper-ore", 8 } }, { { "fo-copper-concentrate", 1 } }, { process = "compaction" })
R("fo-tungsten-concentrate", 10, "fo-concentrating", 1, { { "fo-tungsten-ore", 8 } }, { { "fo-tungsten-concentrate", 1 } }, { process = "compaction" })
R("fo-iron-plate-r8", 10, "fo-arc-smelting", 12.8, { { "fo-iron-concentrate", 1 } }, { { "fo-iron-plate-r8", 1 } }, { dense = true, fr = "Fonte de concentré de fer", en = "Iron concentrate smelting" })
R("fo-copper-plate-r8", 10, "fo-arc-smelting", 12.8, { { "fo-copper-concentrate", 1 } }, { { "fo-copper-plate-r8", 1 } }, { dense = true, fr = "Fonte de concentré de cuivre", en = "Copper concentrate smelting" })
R("fo-tungsten-plate-r8", 10, "fo-arc-smelting", 25.6, { { "fo-tungsten-concentrate", 1 } }, { { "fo-tungsten-plate-r8", 1 } }, { dense = true, fr = "Fonte de concentré de tungstène", en = "Tungsten concentrate smelting" })
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
R("fo-ilmenite-smelting", 11, "fo-arc-smelting", 10, { { "fo-ilmenite-concentrate", 2 }, { "fo-coke", 2 } }, { { "fo-titanium-slag", 1 }, { "iron-plate", 6 } },
  { dense = true, fr = "Fusion de l'ilménite", en = "Ilmenite smelting" })
R("fo-brine-electrolysis", 11, "fo-electrolysis", 3, { { "fo-brine", 100 } },
  { { "fo-chlorine", 40 }, { "fo-hydrogen", 40 }, { "fo-caustic-soda", 1 }, { "fo-magnesium-chloride", 1 } },
  { fr = "Électrolyse de la saumure", en = "Brine electrolysis" })
R("fo-chlorination", 11, "chemistry", 5, { { "fo-titanium-slag", 1 }, { "fo-coke", 1 }, { "fo-chlorine", 60 } }, { { "fo-titanium-tetrachloride", 40 } },
  { fr = "Chloration", en = "Chlorination" })
R("fo-kroll-reduction", 11, "fo-kroll", 15, { { "fo-titanium-tetrachloride", 40 }, { "fo-magnesium", 2 } }, { { "fo-titanium-sponge", 1 }, { "fo-magnesium-chloride", 2 } },
  { fr = "Réduction de Kroll", en = "Kroll reduction", note_fr = "boucle du magnésium fermée par l'électrolyse" })
R("fo-magnesium-electrolysis", 11, "fo-electrolysis", 3, { { "fo-magnesium-chloride", 1 } }, { { "fo-magnesium", 1 }, { "fo-chlorine", 15 } },
  { fr = "Électrolyse du chlorure de magnésium", en = "Magnesium chloride electrolysis" })
R("fo-titanium-plate", 11, "fo-arc-smelting", 4, { { "fo-titanium-sponge", 1 } }, { { "fo-titanium-plate", 1 } },
  { dense = true, prod = true, fr = "Refusion sous vide", en = "Vacuum arc remelting" })
R("fo-wet-tungsten", 11, "chemistry", 8, { { "fo-tungsten-ore", 5 }, { "fo-caustic-soda", 1 }, { "fo-hydrogen", 40 } }, { { "fo-tungsten-plate", 4 } },
  { dense = true, fr = "Tungstène par voie humide", en = "Hydrometallurgical tungsten" })
R("fo-cryostat", 11, "crafting", 10, { { "fo-titanium-plate", 1 }, { "fo-biopolymer", 2 }, { "processing-unit", 1 } }, { { "fo-cryostat", 1 } }, { prod = true })
R("fo-titanium-composite", 11, "crafting", 15, { { "fo-titanium-plate", 1 }, { "fo-biopolymer", 2 }, { "fo-graphite", 1 } }, { { "fo-titanium-composite", 2 } }, { prod = true })
R("fo-titanium-lds", 11, "crafting", 15, { { "fo-titanium-composite", 1 }, { "copper-plate", 4 } }, { { "low-density-structure", 2 } },
  { prod = true, fr = "Structure basse densité au titane", en = "Titanium low density structure", variant_of = "low-density-structure" })
R("fo-structural-pack", 11, "crafting", 20, { { "fo-titanium-composite", 1 }, { "fo-titanium-plate", 1 }, { "fo-tungsten-plate", 1 } }, { { "fo-structural-pack", 3 } })
R("fo-inclusion-analysis", 11, "fo-cleanroom", 60, { { "fo-strange-inclusion", 1 }, { "processing-unit", 1 } }, { { "fo-hadronic-data", 4 } },
  { branch = "D", level = 1, fr = "Analyse d'inclusion", en = "Inclusion analysis" })
R("fo-temporal-resonator", 11, "advanced-crafting", 20, { { "fo-titanium-plate", 2 }, { "fo-cryostat", 1 }, { "fo-crystal-oscillator", 10 }, { "processing-unit", 10 } },
  { { "fo-temporal-resonator", 1 } }, { branch = "C", level = 2 })
R("fo-stable-time-crystal", 11, "fo-temporal", 80, { { "fo-unstable-time-crystal", 2 }, { "fo-crystal-oscillator", 4 } }, { { "fo-stable-time-crystal", 1 } },
  { branch = "C", level = 2, fr = "Cristal temporel stable (verrouillage de phase)", en = "Stable time crystal (phase locking)" })
R("fo-quantum-hourglass", 11, "fo-cleanroom", 30, { { "fo-stable-time-crystal", 1 }, { "fo-crystal-oscillator", 2 }, { "processing-unit", 1 } }, { { "fo-quantum-hourglass", 4 } },
  { branch = "C", level = 2 })
R("fo-dilation-chamber", 11, "advanced-crafting", 20, { { "fo-resonance-amplifier", 1 }, { "fo-stable-time-crystal", 2 }, { "fo-coil", 10 }, { "fo-titanium-composite", 5 } },
  { { "fo-dilation-chamber", 1 } }, { branch = "C", level = 2 })
R("fo-phase-maintenance", 11, "fo-dilation", 300, { { "fo-stable-time-crystal", 1 } }, { { "fo-unstable-time-crystal", 1 } },
  { branch = "C", level = 2, fr = "Maintien de phase", en = "Phase maintenance", note_fr = "le cristal se déphase en travaillant" })
R("fo-entangled-chest", 11, "advanced-crafting", 20, { { "fo-stable-time-crystal", 2 }, { "fo-titanium-plate", 4 }, { "processing-unit", 5 } }, { { "fo-entangled-chest", 2 } },
  { branch = "C", level = 2 })
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
R("fo-magnetic-pack", 12, "crafting", 20, { { "fo-superconducting-coil", 1 }, { "fo-permanent-magnet", 2 }, { "fo-titanium-plate", 1 } }, { { "fo-magnetic-pack", 3 } })
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
R("fo-condensate-survey", 12, "fo-gravitic", 10, { { "fo-axion-condensate", 1 } }, { { "fo-resonance-cavity", 1 }, { "fo-gravimetric-survey", 10 } },
  { branch = "A", level = 2, fr = "Relevé de condensat", en = "Condensate survey" })
R("fo-gravity-well", 12, "advanced-crafting", 30, { { "fo-heavy-drill", 1 }, { "fo-axion-condensate", 4 }, { "fo-superconducting-coil", 10 }, { "fo-titanium-composite", 20 } },
  { { "fo-gravity-well", 1 } }, { branch = "A", level = 2 })
R("fo-burn-axion-condensate", 12, nil, 60, { { "fo-axion-condensate", 1 } }, { { "fo-resonance-cavity", 1 } },
  { kind = "burn", machines = { "fo-gravity-well", "fo-gravity-well-2" }, branch = "A", level = 2,
    fr = "Combustion : condensat (puits, 2 MW)", en = "Burning: condensate (well, 2 MW)" })
R("fo-upwelling-iron", 12, nil, 1, {}, { { "fo-iron-concentrate", 1 } },
  { kind = "mining", resource = "fo-deep-upwelling", machines = { "fo-gravity-well" }, branch = "A", level = 2, fr = "Remontée profonde : fer", en = "Deep upwelling: iron" })
R("fo-upwelling-copper", 12, nil, 1, {}, { { "fo-copper-concentrate", 1 } },
  { kind = "mining", resource = "fo-deep-upwelling", machines = { "fo-gravity-well" }, branch = "A", level = 2, fr = "Remontée profonde : cuivre", en = "Deep upwelling: copper" })
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
R("fo-regolith-degassing", 13, "fo-sintering", 10, { { "fo-ilmenite-concentrate", 1 } }, { { "fo-degassed-ilmenite", 1 }, { "fo-helium-3", 2 } },
  { fr = "Dégazage du régolithe", en = "Regolith degassing" })
R("fo-degassed-ilmenite-smelting", 13, "fo-arc-smelting", 10, { { "fo-degassed-ilmenite", 2 }, { "fo-coke", 2 } }, { { "fo-titanium-slag", 1 }, { "iron-plate", 6 } },
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
R("fo-plasma-pack", 13, "crafting", 25, { { "fo-plasma-cell", 1 }, { "fo-superconducting-coil", 1 }, { "processing-unit", 1 } }, { { "fo-plasma-pack", 3 } })
R("fo-iron-block-r32", 13, "fo-plasma-casting", 4, { { "fo-iron-concentrate", 4 }, { "fo-plasma", 20 } }, { { "fo-iron-block-r32", 1 } },
  { dense = true, fr = "Coulée de bloc de fer", en = "Iron block casting" })
R("fo-copper-block-r32", 13, "fo-plasma-casting", 4, { { "fo-copper-concentrate", 4 }, { "fo-plasma", 20 } }, { { "fo-copper-block-r32", 1 } },
  { dense = true, fr = "Coulée de bloc de cuivre", en = "Copper block casting" })
R("fo-iron-block-unpacking", 13, "crafting", 1, { { "fo-iron-block-r32", 1 } }, { { "fo-iron-plate-r8", 4 } }, { process = "decompaction", fr = "Découpe de bloc de fer", en = "Iron block cutting" })
R("fo-copper-block-unpacking", 13, "crafting", 1, { { "fo-copper-block-r32", 1 } }, { { "fo-copper-plate-r8", 4 } }, { process = "decompaction", fr = "Découpe de bloc de cuivre", en = "Copper block cutting" })
R("fo-synchrotron", 13, "advanced-crafting", 120,
  { { "fo-superconducting-coil", 100 }, { "fo-permanent-magnet", 50 }, { "fo-cryostat", 50 }, { "processing-unit", 100 }, { "concrete", 200 } }, { { "fo-synchrotron", 1 } },
  { branch = "B", level = 2 })
R("fo-recombiner", 13, "advanced-crafting", 20, { { "fo-superconducting-coil", 10 }, { "fo-cryostat", 4 }, { "processing-unit", 10 }, { "fo-lead-shielding", 10 } }, { { "fo-recombiner", 1 } },
  { branch = "B", level = 2 })
R("fo-antiproton-production", 13, "fo-synchrotron", 30, { { "fo-magnetic-trap", 1 }, { "fo-hydrogen", 100 } }, { { "fo-antiproton-trap", 1 } },
  { branch = "B", level = 2, fr = "Production d'antiprotons (150 MW)", en = "Antiproton production (150 MW)" })
R("fo-recombination", 13, "fo-recombination", 10, { { "fo-antiproton-trap", 1 }, { "fo-positron-trap", 1 } }, { { "fo-antihydrogen-trap", 1 }, { "fo-magnetic-trap", 1 } },
  { branch = "B", level = 2, fr = "Recombinaison (antihydrogène)", en = "Recombination (antihydrogen)" })
R("fo-antimatter-microcharge", 13, "fo-recombination", 20, { { "fo-antihydrogen-trap", 1 }, { "fo-tungsten-plate", 10 }, { "fo-superconducting-tape", 10 } },
  { { "fo-antimatter-microcharge", 10 }, { "fo-magnetic-trap", 1 } }, { branch = "B", level = 2 })
R("fo-annihilation-shell", 13, "crafting", 10, { { "artillery-shell", 1 }, { "fo-antimatter-microcharge", 1 } }, { { "fo-annihilation-shell", 1 } }, { branch = "B", level = 2 })
R("fo-annihilation-measurement", 13, "fo-recombination", 10, { { "fo-antihydrogen-trap", 1 } }, { { "fo-magnetic-trap", 1 }, { "fo-annihilation-data", 20 } },
  { branch = "B", level = 2, fr = "Mesure d'annihilation", en = "Annihilation measurement" })
R("fo-catalyzed-fusion-pellet", 13, "fo-recombination", 20, { { "fo-fusion-pellet", 2 }, { "fo-antihydrogen-trap", 2 } },
  { { "fo-catalyzed-fusion-pellet", 2 }, { "fo-magnetic-trap", 2 } }, { branch = "B", level = 2, fr = "Fusion catalysée par l'antimatière", en = "Antimatter-catalyzed fusion",
    whitelist_fr = "fusion catalysée : 2 × 80 GJ de gain pour 2 × 50 GJ d'antihydrogène (fiction déclarée)" })
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
for _, t in ipairs({ { "fo-tungsten-ore", "tungsten" }, { "fo-ilmenite-ore", "ilmenite" }, { "fo-monazite-ore", "monazite" },
                     { "uranium-ore", "uranium" }, { "fo-resonance-crystal", "crystal" } }) do
  R("fo-transmutation-" .. t[2], 13, "fo-transmutation", 20, { { "fo-confined-strangelet", 1, catalyst = 1 }, { "stone", 40 } },
    { { "fo-confined-strangelet", 1, catalyst = 1 }, { t[1], 20 } },
    { branch = "D", level = 2, process = "transmutation", fr = "Transmutation : " .. t[2], en = "Transmutation: " .. t[2] })
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
R("fo-orbital-tug", 14, "advanced-crafting", 60, { { "fo-titanium-composite", 50 }, { "fo-superconducting-coil", 20 }, { "processing-unit", 10 }, { "fo-cryogenic-propellant", 20 } }, { { "fo-orbital-tug", 1 } })
R("fo-launch-orbital-tug", 14, nil, 1, { { "fo-orbital-tug", 1 }, { "rocket-part", 100 } }, { { "fo-ferrous-meteorite", 50 }, { "fo-strange-meteorite", 5 } },
  { kind = "launch", machines = { "rocket-silo" }, fr = "Lancement : remorqueur orbital", en = "Launch: orbital tug" })
R("fo-orbital-solar-plant", 14, "advanced-crafting", 60, { { "solar-panel", 100 }, { "fo-titanium-composite", 50 }, { "fo-superconducting-coil", 20 }, { "processing-unit", 20 } }, { { "fo-orbital-solar-plant", 1 } })
R("fo-launch-orbital-solar-plant", 14, nil, 1, { { "fo-orbital-solar-plant", 1 }, { "rocket-part", 100 } }, {},
  { kind = "launch", machines = { "rocket-silo" }, fr = "Lancement : centrale solaire orbitale (+50 MW)", en = "Launch: orbital solar plant (+50 MW)" })
R("fo-meteorite-crushing", 14, "fo-crushing", 8, { { "fo-ferrous-meteorite", 4 } }, { { "fo-nickel-iron", 3 }, { "fo-iridium", 1 }, { "stone", 2 } },
  { fr = "Concassage météoritique", en = "Meteorite crushing" })
R("fo-strange-meteorite-crushing", 14, "fo-crushing", 10, { { "fo-strange-meteorite", 1 } }, { { "fo-strange-inclusion", 5 }, { "stone", 2 } },
  { fr = "Concassage d'une météorite étrange", en = "Strange meteorite crushing" })
R("fo-superalloy", 14, "fo-arc-smelting", 8, { { "fo-nickel-iron", 3 }, { "fo-titanium-plate", 1 }, { "fo-tungsten-carbide", 1 } }, { { "fo-superalloy", 1 } },
  { dense = true, prod = true })
R("fo-iridium-mirror", 14, "fo-cleanroom", 20, { { "fo-iridium", 2 }, { "fo-glass", 1 }, { "fo-titanium-composite", 1 } }, { { "fo-iridium-mirror", 1 } }, { prod = true })
R("fo-rectenna", 14, "advanced-crafting", 30, { { "fo-permanent-magnet", 20 }, { "fo-enameled-wire", 100 }, { "fo-titanium-composite", 20 }, { "processing-unit", 10 } }, { { "fo-rectenna", 1 } })
R("fo-deflector-shield", 14, "advanced-crafting", 30, { { "fo-superconducting-coil", 20 }, { "fo-superalloy", 2 }, { "processing-unit", 10 }, { "fo-cryostat", 4 } }, { { "fo-deflector-shield", 1 } })
R("fo-gravity-well-2", 14, "advanced-crafting", 60, { { "fo-gravity-well", 1 }, { "fo-axion-condensate", 10 }, { "fo-superalloy", 5 } }, { { "fo-gravity-well-2", 1 } },
  { branch = "A", level = 3 })
for _, u in ipairs({ { "fo-tungsten-concentrate", "tungsten" }, { "fo-ilmenite-concentrate", "ilmenite" }, { "fo-monazite-concentrate", "monazite" } }) do
  R("fo-upwelling-" .. u[2], 14, nil, 1, {}, { { u[1], 1 } },
    { kind = "mining", resource = "fo-deep-upwelling", machines = { "fo-gravity-well-2" }, branch = "A", level = 3,
      fr = "Remontée profonde : " .. u[2], en = "Deep upwelling: " .. u[2] })
end
R("fo-tidal-shield", 14, "advanced-crafting", 40, { { "fo-axion-condensate", 10 }, { "fo-superconducting-coil", 10 }, { "fo-superalloy", 5 } }, { { "fo-tidal-shield", 1 } },
  { branch = "A", level = 3 })
R("fo-caustic-observatory", 14, "advanced-crafting", 600, { { "fo-axion-condensate", 200 }, { "fo-resonance-lens", 500 }, { "fo-superalloy", 50 }, { "processing-unit", 300 } },
  { { "fo-caustic-observatory", 1 } }, { branch = "A", level = 3 })
R("fo-annihilation-reactor", 14, "advanced-crafting", 180, { { "fo-superconducting-coil", 300 }, { "fo-superalloy", 50 }, { "fo-lead-shielding", 500 }, { "fo-cryostat", 100 } },
  { { "fo-annihilation-reactor", 1 } }, { branch = "B", level = 3 })
R("fo-burn-antihydrogen", 14, nil, 25, { { "fo-antihydrogen-trap", 1 } }, { { "fo-magnetic-trap", 1 } },
  { kind = "burn", machines = { "fo-annihilation-reactor" }, branch = "B", level = 3, fr = "Combustion : antihydrogène (2 GW)", en = "Burning: antihydrogen (2 GW)" })
R("fo-annihilation-lance", 14, "advanced-crafting", 60, { { "fo-superconducting-coil", 40 }, { "fo-superalloy", 10 }, { "processing-unit", 20 }, { "fo-antimatter-microcharge", 20 } },
  { { "fo-annihilation-lance", 1 } }, { branch = "B", level = 3 })
R("fo-deep-probe", 14, "advanced-crafting", 60, { { "fo-antihydrogen-trap", 5 }, { "fo-titanium-composite", 50 }, { "processing-unit", 20 } }, { { "fo-deep-probe", 1 } },
  { branch = "B", level = 3 })
R("fo-launch-deep-probe", 14, nil, 1, { { "fo-deep-probe", 1 }, { "rocket-part", 100 } }, { { "fo-strange-meteorite", 50 }, { "fo-iridium", 50 } },
  { kind = "launch", machines = { "rocket-silo" }, branch = "B", level = 3, fr = "Lancement : sonde profonde", en = "Launch: deep probe" })
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
    note_fr = "foreuse à entrée de fluide (minable.required_fluid) : non vérifié pour une ressource fluide" })
R("fo-casimir-stabilizer", 15, "advanced-crafting", 60, { { "fo-iridium-mirror", 50 }, { "fo-superconducting-coil", 20 }, { "fo-superalloy", 10 }, { "processing-unit", 50 } },
  { { "fo-casimir-stabilizer", 1 } })
R("fo-casimir-cavity", 15, "fo-cleanroom", 30, { { "fo-iridium-mirror", 2 }, { "fo-stable-time-crystal", 1 }, { "fo-superconducting-coil", 1 } }, { { "fo-casimir-cavity", 1 } })
R("fo-exotic-stabilization", 15, "fo-casimir", 60, { { "fo-raw-exotic-matter", 50 }, { "fo-casimir-cavity", 1, catalyst = 1 } },
  { { "fo-stabilized-exotic-matter", 1 }, { "fo-casimir-cavity", 1, catalyst = 1 } },
  { process = "catalytic", fr = "Stabilisation de la matière exotique (500 MW)", en = "Exotic matter stabilization (500 MW)" })
R("fo-exotic-pack", 15, "fo-cleanroom", 30, { { "fo-stabilized-exotic-matter", 1 }, { "fo-superalloy", 1 }, { "processing-unit", 1 } }, { { "fo-exotic-pack", 5 } })
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
         "light-armor", "submachine-gun", "shotgun", "shotgun-shell", "loader", "fo-command-center" } },
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
         "empty-sulfuric-acid-barrel", "empty-water-barrel", "fast-transport-belt", "fast-underground-belt", "fast-splitter", "fast-loader",
         "rocket-launcher", "rocket", "explosive-rocket", "land-mine", "poison-capsule", "slowdown-capsule", "defender-capsule",
         "modular-armor", "night-vision-equipment", "belt-immunity-equipment", "fluid-wagon", "refined-concrete", "refined-hazard-concrete",
         "stack-inserter", "stack-filter-inserter" } },
  { 5, { "tank", "cannon-shell", "explosive-cannon-shell", "fo-tungsten-plate", "fo-tungsten-rounds-magazine", "fo-explosive-rounds-magazine",
         "fo-heavy-machine-gun", "fo-heavy-gun-turret", "fo-reinforced-wall", "fo-armored-wall", "fo-cannon-turret", "fo-mortar-turret",
         "fo-mortar-shell", "fo-tungsten-cannon-shell", "fo-launcher-grenade", "fo-grenade-launcher" } },
  { 6, { "battery", "accumulator", "solar-panel", "substation", "electric-engine-unit", "laser-turret", "electric-furnace",
         "production-science-pack", "speed-module", "productivity-module", "effectivity-module", "distractor-capsule", "assembling-machine-3",
         "battery-equipment", "solar-panel-equipment", "energy-shield-equipment", "fo-tesla-turret", "fo-arc-cell", "fo-arc-gun" } },
  { 7, { "beacon", "express-transport-belt", "express-underground-belt", "express-splitter", "express-loader", "fo-heavy-laser-turret" } },
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
  { 14, { "rocket-silo", "rocket-part", "satellite", "fo-speed-module-6", "fo-speed-module-7", "fo-speed-module-8", "fo-speed-module-9",
          "fo-speed-module-10", "fo-productivity-module-6", "fo-productivity-module-7", "fo-productivity-module-8", "fo-productivity-module-9",
          "fo-productivity-module-10", "fo-effectivity-module-6", "fo-effectivity-module-7", "fo-effectivity-module-8",
          "fo-effectivity-module-9", "fo-effectivity-module-10" } },
  { 15, { "electric-energy-interface" } },
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
  { key = "tide", api = "LuaEntity.amount (écriture)", period_fr = "600 ticks, table de 24 phases", cost_fr = "O(tuiles de veine)" },
  { key = "veins", api = "on_sector_scanned, LuaSurface.create_entity", period_fr = "à chaque secteur balayé", cost_fr = "faible" },
  { key = "upwelling-and-rifts", api = "LuaSurface.create_entity (ressource)", period_fr = "à la pose, au réveil du Cœur", cost_fr = "nul" },
  { key = "dilation", api = "balise cachée créée ou retirée selon LuaEntity.status (speed_bonus est en lecture seule)", period_fr = "60 ticks", cost_fr = "O(chambres)" },
  { key = "confinement", api = "LuaEntity.energy, LuaEntity.status, LuaEntity.damage", period_fr = "60 ticks", cost_fr = "O(bâtiments à pièges)" },
  { key = "contagion", api = "LuaEntity.status, LuaSurface.set_tiles", period_fr = "60 ticks", cost_fr = "O(cuves)" },
  { key = "rectenna", api = "LuaEntity.power_production (écriture)", period_fr = "à chaque lancement ou pose", cost_fr = "nul" },
  { key = "meteor-showers", api = "LuaSurface.create_entity", period_fr = "toutes les 20 à 40 min", cost_fr = "pic ponctuel" },
  { key = "evolution-window", api = "LuaForce.evolution_factor (écriture)", period_fr = "3 600 ticks", cost_fr = "nul" },
  { key = "perturbation", api = "LuaForce.item_production_statistics, LuaFlowStatistics.get_input_count", period_fr = "36 000 ticks", cost_fr = "nul" },
  { key = "wonders", api = "LuaForce.mining_drill_productivity_bonus, LuaForce.laboratory_speed_modifier (écriture)", period_fr = "à la pose", cost_fr = "nul" },
  { key = "gate", api = "on_rocket_launched, script/td/director.lua, LuaGameScript.set_game_state ; silo-script set_no_victory", period_fr = "événement", cost_fr = "celui des vagues (E19 : 0,06 ms)" },
}
X.SCRIPT_BUDGET_MS = 0.05 -- hypothèse H-X1 : tous les systèmes X ≤ 0,05 ms/tick à l'époque 15 (à mesurer)

X.branch_params = {
  confinement = { grace_ticks = 300, damage_per_trap = 2000, radius = 8, period_ticks = 60 },
  contagion = { overflow_ticks = 3600, radius_per_minute = 1, radius_max = 12, damage_per_second = 50, period_ticks = 60 },
  dilation = { aura_radius = 3, bonus_level2 = 1.0, bonus_level3 = 2.0, period_ticks = 60 },
  hourglass = { share = 0.25, min_minutes = 10 },
  meteor = { interval_minutes = { 20, 40 }, tiles = { 5, 15 }, amount_per_tile = { 100, 300 }, deflector_radius = 48 },
  gate = { segments = 100, charge_minutes = 30, power_mw = 5000, waves = 12, boss_every = 3, faction_rebate = 0.30 },
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
-- 15. Factions IA (Q4) : doctrines, difficulté, économie d'archive. Chiffres proposés au lot IA0 ❔.
---------------------------------------------------------------------------------------------------
X.doctrines = {
  { faction = "scarlet", personality = "conqueror", branch = "B", sworn_rival = "amber", elite_fr = "Lancier d'annihilation", elite_en = "Annihilation lancer" },
  { faction = "azure", personality = "technocrat", branch = "A", sworn_rival = "emerald", elite_fr = "Arpenteur gravitique", elite_en = "Gravitic strider" },
  { faction = "emerald", personality = "builder", branch = "D", sworn_rival = "azure", elite_fr = "Colosse étrange", elite_en = "Strange colossus" },
  { faction = "amber", personality = "balanced", branch = "C", sworn_rival = "scarlet", elite_fr = "Spectre chronique", elite_en = "Chrono wraith" },
}
X.OATH_ALLY_SHARE = 0.5   -- part des forces de la faction de même doctrine dirigée contre le joueur (× 0,5)
X.OATH_RIVAL_SHARE = 1.5  -- rivale jurée (× 1,5)

X.difficulty = {
  { key = "peaceful", fr = "Paisible", en = "Peaceful", grace_until_epoch = nil, grace_minutes = nil, attack_every_minutes = nil,
    size = 0, share = 0.00, evolution_offset = -0.05, epoch_offset = nil, gate_race_hours = nil, credit = 0.5 },
  { key = "easy", fr = "Facile", en = "Easy", grace_until_epoch = 4, attack_every_minutes = 30,
    size = 0.75, share = 0.15, evolution_offset = -0.05, epoch_offset = -2, gate_race_hours = nil, credit = 0.5 },
  { key = "normal", fr = "Normal", en = "Normal", grace_until_epoch = 3, attack_every_minutes = 20,
    size = 1.0, share = 0.30, evolution_offset = 0, epoch_offset = -1, gate_race_hours = nil, credit = 1.0 },
  { key = "hard", fr = "Difficile", en = "Hard", grace_until_epoch = 2, attack_every_minutes = 12,
    size = 1.4, share = 0.45, evolution_offset = 0.03, epoch_offset = 0, gate_race_hours = 4, credit = 1.5 },
  { key = "ruthless", fr = "Impitoyable", en = "Ruthless", grace_minutes = 15, attack_every_minutes = 8,
    size = 2.0, share = 0.60, evolution_offset = 0.06, epoch_offset = 1, gate_race_hours = 2.5, credit = 2.5 },
}

--- Économie d'archive hybride (greffe P3) : le minage RÉEL des avant-postes (MU livrées au QG) fait
--- progresser l'époque de la faction ; la difficulté pondère le crédit ; l'époque est plafonnée par celle
--- du joueur décalée selon la difficulté. Seuil de l'époque k : 300 MU × 1,6^(k-2), cumulés.
X.FACTION_BASE_MU, X.FACTION_GROWTH = 300, 1.6
function X.faction_threshold(k)
  local total = 0
  for j = 2, k do total = total + X.FACTION_BASE_MU * X.FACTION_GROWTH ^ (j - 2) end
  return total
end
function X.faction_epoch(mu_delivered, player_epoch, difficulty)
  if difficulty.epoch_offset == nil then return 1 end
  local cap = math.max(1, math.min(X.EPOCHS, player_epoch + difficulty.epoch_offset))
  local credited = mu_delivered * difficulty.credit
  local e = 1
  while e < cap and credited >= X.faction_threshold(e + 1) do e = e + 1 end
  return e
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
