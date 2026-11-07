--[[
  Lot CALCUL-V2 (30/10) : UNE MACHINE PAR ÉTAPE et le centre de calcul MODULAIRE. Plan de l'architecte :
  <racine>/fo-logs/2026-10-30_CALCUL-V2/PLAN.md. Base : la chaîne v1 (shared/content/compute.lua, lot CALCUL, 0.6.27).

  DC (30/10 ~11 h) : « n'oubliez pas les centres de calcul avec les différentes étapes, de processeur, de mémoire, caches,
  cartes graphique, carte mère etc etc, processeur quantique aussi » ; « en fait il va falloir en théorie beaucoup de
  machines et modules différents pour le concept de calcul ». Au QCU : « modules » = « Modules du centre de calcul » (baies)
  ET « Une machine par étape ». PAS de modules d'effet (vitesse, productivité) pour le calcul.

  Lua PUR (tests/compute_v2_test.lua). Prototypes : prototypes/compute_v2.lua (après prototypes/compute.lua). Règle du
  centre : shared/content/compute_rack.lua. Script : script/compute/compute.lua.

  LA CHAÎNE v2 (âge 10 sauf mention) :
    silicium pur ─[tireuse]► lingot ─[scie à fil]► tranches ─[lithographe]► insolée ─[graveur-dopeur]► GRAVÉE
    GRAVÉE ─[banc de découpe et test]► logique │ DRAM │ SRAM │ NAND
    puces ─[mise en boîtier]► PROCESSEUR (variante) │ DISQUE FLASH ; verre ─[fibrage]► FIBRE
    ─[pose CMS]► CARTE MÈRE │ BARRETTE │ COMMUTATEUR │ (11) CARTE GRAPHIQUE
    ─[atelier d'intégration]► baies CPU, MÉMOIRE, STOCKAGE, RÉSEAU, REFROIDISSEMENT, (11) GPU, (13) QUANTIQUE
    eau ─[groupe froid]► eau glacée ─► [CENTRE + baies] ─► eau chaude ─[tour de refroidissement]► eau (−2 %)
    (12) grand centre, azote liquide ; (13) He-3 + azote ─[réfrigérateur à dilution]► mélange ─► centre (dilution) ;
    puces à qubits et processeur quantique au labo quantique.

  Les recettes v1 restent EN JEU (mêmes noms, catégories, ingrédients, produits : tests/fixtures/calcul_v1_0627.lua), mais
  CACHÉES pour un nouveau choix (Cv.HIDE_V1) : une machine d'une sauvegarde 0.6.27 qui les fait les fait toujours.
]]

local Cp = require("shared.content.compute")

local Cv = {}

---------------------------------------------------------------------------------------------------
-- Machines (une par étape) : visuel PROVISOIRE (copie teintée d'une machine vanilla, mise à l'échelle), liste
-- dessinés au lot CALCUL-DESIGN (01/11).
--   copy : assembleur vanilla copié ; side : son côté ; pipes : entrées (in) et sorties (out) de fluide, positions des
--   raccords (juste hors de l'emprise).
---------------------------------------------------------------------------------------------------
local function edge_in(side, n)  -- n raccords d'entrée au bord nord
  local h = side / 2 + 0.5
  if n == 1 then return { { side % 2 == 0 and -0.5 or 0, -h } } end
  local a = (side % 2 == 0) and 0.5 or 1
  return { { -a, -h }, { a, -h } }
end
local function edge_out(side, n) -- n raccords de sortie au bord sud
  local h = side / 2 + 0.5
  if n == 1 then return { { side % 2 == 0 and 0.5 or 0, h } } end
  local a = (side % 2 == 0) and 0.5 or 1
  return { { -a, h }, { a, h } }
end

Cv.MACHINES = {
  { name = "fo-crystal-puller", epoch = 10, size = 3, kw = 1500, categories = { "fo-crystal-pulling" },
    copy = "centrifuge", side = 3, tint = { r = 0.80, g = 0.82, b = 1.00 },
    fr = "Tireuse de cristal", en = "Crystal puller", src = "x3" },
  { name = "fo-wire-saw", epoch = 10, size = 3, kw = 600, categories = { "fo-wire-sawing" },
    copy = "assembling-machine-2", side = 3, tint = { r = 0.85, g = 0.80, b = 0.70 }, pipes = { inn = edge_in(3, 1) },
    fr = "Scie à fil", en = "Wire saw" },
  { name = "fo-plasma-etcher", epoch = 10, size = 3, kw = 2000, categories = { "fo-plasma-etching" },
    copy = "assembling-machine-2", side = 3, tint = { r = 0.95, g = 0.60, b = 1.00 }, pipes = { inn = edge_in(3, 2) },
    fr = "Graveur-dopeur à plasma", en = "Plasma etcher" },
  { name = "fo-die-prober", epoch = 10, size = 3, kw = 800, categories = { "fo-die-testing" },
    copy = "assembling-machine-2", side = 3, tint = { r = 1.00, g = 0.90, b = 0.55 },
    fr = "Banc de découpe et test", en = "Die prober" },
  { name = "fo-packaging-line", epoch = 10, size = 3, kw = 1000, categories = { "fo-packaging" },
    copy = "assembling-machine-2", side = 3, tint = { r = 0.60, g = 0.95, b = 0.70 },
    fr = "Ligne de mise en boîtier", en = "Packaging line" },
  { name = "fo-smt-line", epoch = 10, size = 4, kw = 1200, categories = { "fo-smt" },
    copy = "assembling-machine-3", side = 3, tint = { r = 0.45, g = 0.85, b = 0.55 },
    fr = "Ligne de câblage (pose CMS)", en = "SMT line" },
  { name = "fo-fiber-tower", epoch = 10, size = 3, kw = 1000, categories = { "fo-fiber-drawing" },
    copy = "centrifuge", side = 3, tint = { r = 0.70, g = 1.00, b = 1.00 },
    fr = "Tour de fibrage", en = "Fiber drawing tower" },
  { name = "fo-rack-integrator", epoch = 10, size = 4, kw = 800, categories = { "fo-rack-integration" },
    copy = "assembling-machine-3", side = 3, tint = { r = 0.70, g = 0.72, b = 0.95 },
    fr = "Atelier d'intégration des baies", en = "Rack integration bay" },
  { name = "fo-chiller", epoch = 10, size = 4, kw = 2000, categories = { "fo-chilling" },
    copy = "assembling-machine-3", side = 3, tint = { r = 0.60, g = 0.85, b = 1.00 },
    pipes = { inn = edge_in(4, 1), out = edge_out(4, 1) },
    fr = "Groupe froid", en = "Chiller" },
  { name = "fo-cooling-tower", epoch = 10, size = 5, kw = 300, categories = { "fo-heat-rejection" },
    copy = "assembling-machine-3", side = 3, tint = { r = 0.80, g = 0.85, b = 0.88 },
    pipes = { inn = edge_in(5, 1), out = edge_out(5, 1) },
    fr = "Tour de refroidissement", en = "Cooling tower" },
  { name = "fo-data-center-2", epoch = 12, size = 6, kw = 600, categories = { "fo-dc-cooling", "fo-dc-cryo" },
    copy = "assembling-machine-3", side = 3, tint = { r = 0.45, g = 0.50, b = 0.75 }, slots = 12,
    pipes = { inn = { { -0.5, -3.5 }, { 0.5, 3.5 } }, out = { { 3.5, 0.5 } } },
    fr = "Grand centre de calcul", en = "Large data center" },
  { name = "fo-dilution-fridge", epoch = 13, size = 3, kw = 2500, categories = { "fo-dilution" },
    copy = "centrifuge", side = 3, tint = { r = 0.75, g = 0.95, b = 1.00 },
    pipes = { inn = edge_in(3, 2), out = edge_out(3, 1) },
    fr = "Réfrigérateur à dilution", en = "Dilution refrigerator" },
  { name = "fo-quantum-lab", epoch = 13, size = 5, kw = 4000, categories = { "fo-quantum-fab" },
    copy = "centrifuge", side = 3, tint = { r = 1.00, g = 0.55, b = 1.00 },
    fr = "Labo quantique", en = "Quantum lab" },
}
-- Le centre v1 (prototypes/compute.lua) devient MODULAIRE : même nom, même 4 × 4, mêmes deux entrées (raccords de la
-- v1 gardés : une sauvegarde 0.6.27 garde ses tuyaux), une SORTIE en plus (eau chaude), 6 emplacements de baies.
Cv.DATA_CENTER = { name = "fo-data-center", kw = 300, slots = 6, categories = { "fo-computing", "fo-dc-cooling" },
                   out = { { 2.5, 0.5 } } }

--- Visuels provisoires restants : aucun depuis le lot CALCUL-DESIGN (01/11, prototypes/calcul_visuels.lua).
Cv.PROVISIONAL = {}

---------------------------------------------------------------------------------------------------
-- Objets, fluides, baies
---------------------------------------------------------------------------------------------------
Cv.ITEMS = {
  { name = "fo-silicon-ingot", epoch = 10, stack = 20, fr = "Lingot de silicium monocristallin", en = "Monocrystalline silicon ingot" },
  { name = "fo-exposed-wafer", epoch = 10, stack = 100, fr = "Tranche insolée", en = "Exposed wafer" },
  { name = "fo-nand-die", epoch = 10, stack = 200, fr = "Puce de mémoire flash NAND", en = "NAND flash die" },
  { name = "fo-flash-drive", epoch = 10, stack = 100, fr = "Disque flash", en = "Flash drive" },
  { name = "fo-optical-fiber", epoch = 10, stack = 200, fr = "Fibre optique", en = "Optical fiber" },
  { name = "fo-network-switch", epoch = 10, stack = 50, fr = "Commutateur réseau", en = "Network switch" },
}
Cv.FLUIDS = {
  { name = "fo-chilled-water", epoch = 10, fr = "Eau glacée", en = "Chilled water", base = "water", tint = { r = 0.55, g = 0.85, b = 1.00 } },
  { name = "fo-warm-water", epoch = 10, fr = "Eau chaude", en = "Warm water", base = "water", tint = { r = 1.00, g = 0.65, b = 0.45 } },
  { name = "fo-dilution-mix", epoch = 13, fr = "Mélange hélium-3 / hélium-4", en = "Helium-3/helium-4 mixture", base = "petroleum-gas",
    tint = { r = 0.85, g = 0.95, b = 1.00 } },
}
-- Baies (type « module », catégorie fo-baie). fo-server-blade et fo-gpu-blade : noms de la v1 GARDÉS (objet → module).
Cv.MODULE_CATEGORY = "fo-baie"
Cv.RACKS = {
  { name = "fo-server-blade", epoch = 10, stack = 20, v1 = true },
  { name = "fo-memory-rack", epoch = 10, stack = 20, fr = "Baie de mémoire", en = "Memory rack" },
  { name = "fo-storage-rack", epoch = 10, stack = 20, fr = "Baie de stockage", en = "Storage rack" },
  { name = "fo-network-rack", epoch = 10, stack = 20, fr = "Baie de réseau", en = "Network rack" },
  { name = "fo-cooling-rack", epoch = 10, stack = 20, fr = "Baie de refroidissement", en = "Cooling rack" },
  { name = "fo-gpu-blade", epoch = 11, stack = 20, v1 = true },
  { name = "fo-quantum-rack", epoch = 13, stack = 10, fr = "Baie quantique", en = "Quantum rack" },
}
-- Effet moteur des baies : +5 % de pollution (seul effet, voulu : un centre chargé pollue plus). C'est la CLÉ
-- d'exclusivité : le centre n'admet que « pollution » (allowed_effects), et tout module vanilla ou du mod porte un autre
-- effet : refusé par le centre, balises comprises (EffectTypeLimitation).
Cv.RACK_POLLUTION = 0.05

---------------------------------------------------------------------------------------------------
-- Recettes v2 : { name, epoch, category, time, ingredients, results, variant, fr, en }
---------------------------------------------------------------------------------------------------
Cv.RECIPES = {
  -- Âge 10 : la tranche
  { name = "fo-silicon-ingot", epoch = 10, category = "fo-crystal-pulling", time = 40,
    ingredients = { { "fo-pure-silicon", 10 }, { "fo-graphite", 1 } }, results = { { "fo-silicon-ingot", 1 } } },
  { name = "fo-ingot-sawing", epoch = 10, category = "fo-wire-sawing", time = 20, variant = "fo-silicon-wafer",
    ingredients = { { "fo-silicon-ingot", 1 }, { "fo-crystal-powder", 2 }, { "water", 40 } }, results = { { "fo-silicon-wafer", 42 } },
    fr = "Tranches sciées dans le lingot", en = "Wafers sawn from the ingot" },
  { name = "fo-wafer-exposure", epoch = 10, category = "fo-lithography", time = 20,
    ingredients = { { "fo-silicon-wafer", 10 }, { "fo-photomask", 1 }, { "fo-photoresist", 5 } }, results = { { "fo-exposed-wafer", 10 } } },
  -- Gravure au plasma : acide sulfurique et HYDROGÈNE (le chlore n'est en jeu qu'à l'âge 11, chaîne du titane).
  { name = "fo-plasma-etching", epoch = 10, category = "fo-plasma-etching", time = 10,
    ingredients = { { "fo-exposed-wafer", 10 }, { "sulfuric-acid", 10 }, { "fo-hydrogen", 20 } }, results = { { "fo-etched-wafer", 10 } },
    fr = "Gravure et dopage au plasma", en = "Plasma etching and doping" },
  -- Découpe et test
  { name = "fo-die-test-logic", epoch = 10, category = "fo-die-testing", time = 5,
    ingredients = { { "fo-etched-wafer", 1 } }, results = { { "fo-logic-die", 2 } } },
  { name = "fo-die-test-dram", epoch = 10, category = "fo-die-testing", time = 5,
    ingredients = { { "fo-etched-wafer", 1 } }, results = { { "fo-dram-die", 4 } } },
  { name = "fo-die-test-sram", epoch = 10, category = "fo-die-testing", time = 5,
    ingredients = { { "fo-etched-wafer", 1 } }, results = { { "fo-sram-die", 4 } } },
  { name = "fo-die-test-nand", epoch = 10, category = "fo-die-testing", time = 5,
    ingredients = { { "fo-etched-wafer", 1 } }, results = { { "fo-nand-die", 4 } } },
  -- Mise en boîtier
  { name = "fo-packaged-processor", epoch = 10, category = "fo-packaging", time = 10, variant = "processing-unit",
    ingredients = { { "fo-logic-die", 1 }, { "fo-sram-die", 2 }, { "fo-printed-circuit-board", 1 }, { "fo-heat-sink", 1 },
                    { "electronic-circuit", 12 }, { "advanced-circuit", 2 } },
    results = { { "processing-unit", 1 } }, fr = "Processeur mis en boîtier", en = "Packaged processor" },
  { name = "fo-flash-drive", epoch = 10, category = "fo-packaging", time = 10,
    ingredients = { { "fo-nand-die", 8 }, { "fo-printed-circuit-board", 1 }, { "plastic-bar", 2 } }, results = { { "fo-flash-drive", 2 } } },
  -- Fibre
  { name = "fo-optical-fiber", epoch = 10, category = "fo-fiber-drawing", time = 4,
    ingredients = { { "fo-glass", 2 }, { "fo-crystal-powder", 1 } }, results = { { "fo-optical-fiber", 4 } } },
  -- Pose des composants (CMS)
  { name = "fo-smt-motherboard", epoch = 10, category = "fo-smt", time = 10,
    ingredients = { { "fo-printed-circuit-board", 2 }, { "fo-crystal-oscillator", 1 }, { "advanced-circuit", 2 }, { "copper-cable", 4 } },
    results = { { "fo-motherboard", 1 } }, fr = "Carte mère (pose CMS)", en = "Motherboard (SMT)" },
  { name = "fo-smt-memory-module", epoch = 10, category = "fo-smt", time = 10,
    ingredients = { { "fo-dram-die", 8 }, { "fo-printed-circuit-board", 1 }, { "fo-tin-plate", 1 } },
    results = { { "fo-memory-module", 2 } }, fr = "Barrette (pose CMS)", en = "RAM module (SMT)" },
  { name = "fo-network-switch", epoch = 10, category = "fo-smt", time = 10,
    ingredients = { { "fo-optical-fiber", 8 }, { "fo-logic-die", 2 }, { "fo-printed-circuit-board", 1 }, { "copper-cable", 4 } },
    results = { { "fo-network-switch", 1 } } },
  -- Intégration des baies (âge 10)
  { name = "fo-rack-cpu", epoch = 10, category = "fo-rack-integration", time = 15,
    ingredients = { { "fo-motherboard", 1 }, { "processing-unit", 2 }, { "fo-memory-module", 2 }, { "fo-heat-sink", 2 }, { "steel-plate", 5 } },
    results = { { "fo-server-blade", 1 } }, fr = "Baie de serveurs (CPU)", en = "Server blade (CPU)" },
  { name = "fo-rack-memory", epoch = 10, category = "fo-rack-integration", time = 15,
    ingredients = { { "fo-motherboard", 1 }, { "fo-memory-module", 30 }, { "fo-heat-sink", 2 }, { "steel-plate", 5 } },
    results = { { "fo-memory-rack", 1 } } },
  { name = "fo-rack-storage", epoch = 10, category = "fo-rack-integration", time = 15,
    ingredients = { { "fo-motherboard", 1 }, { "fo-flash-drive", 16 }, { "processing-unit", 1 }, { "steel-plate", 5 } },
    results = { { "fo-storage-rack", 1 } } },
  { name = "fo-rack-network", epoch = 10, category = "fo-rack-integration", time = 15,
    ingredients = { { "fo-network-switch", 6 }, { "fo-optical-fiber", 20 }, { "processing-unit", 1 }, { "steel-plate", 5 } },
    results = { { "fo-network-rack", 1 } } },
  { name = "fo-rack-cooling", epoch = 10, category = "fo-rack-integration", time = 15,
    ingredients = { { "fo-heat-sink", 6 }, { "pipe", 10 }, { "electric-engine-unit", 4 }, { "fo-aluminium-plate", 10 }, { "steel-plate", 5 } },
    results = { { "fo-cooling-rack", 1 } } },
  -- Froid du centre (âge 10)
  { name = "fo-water-chilling", epoch = 10, category = "fo-chilling", time = 2,
    ingredients = { { "water", 100 } }, results = { { "fo-chilled-water", 100 } } },
  { name = "fo-warm-water-cooling", epoch = 10, category = "fo-heat-rejection", time = 2,
    ingredients = { { "fo-warm-water", 200 } }, results = { { "water", 196 } }, fr = "Refroidissement de l'eau chaude", en = "Warm water cooling" },
  { name = "fo-dc-chilled-water", epoch = 10, category = "fo-dc-cooling", time = 10, cooling = true,
    ingredients = { { "fo-chilled-water", 100 } }, results = { { "fo-warm-water", 100 } },
    fr = "Refroidissement à l'eau glacée", en = "Chilled-water cooling" },
  -- Âge 11 : accélérateurs
  { name = "fo-smt-graphics-card", epoch = 11, category = "fo-smt", time = 15,
    ingredients = { { "fo-logic-die", 4 }, { "fo-dram-die", 8 }, { "fo-printed-circuit-board", 1 }, { "fo-heat-sink", 2 }, { "fo-titanium-plate", 1 } },
    results = { { "fo-graphics-card", 1 } }, fr = "Carte graphique (pose CMS)", en = "Graphics card (SMT)" },
  { name = "fo-rack-gpu", epoch = 11, category = "fo-rack-integration", time = 15,
    ingredients = { { "fo-motherboard", 1 }, { "processing-unit", 1 }, { "fo-graphics-card", 4 }, { "fo-memory-module", 2 } },
    results = { { "fo-gpu-blade", 1 } }, fr = "Baie d'accélérateurs (GPU)", en = "Accelerator blade (GPU)" },
  -- Âge 12 : grand centre, azote liquide
  { name = "fo-dc-liquid-nitrogen", epoch = 12, category = "fo-dc-cryo", time = 10, cooling = true,
    ingredients = { { "fo-liquid-nitrogen", 50 } }, results = {},
    fr = "Refroidissement à l'azote liquide", en = "Liquid-nitrogen cooling" },
  -- Âge 13 : quantique
  { name = "fo-dilution-mix", epoch = 13, category = "fo-dilution", time = 5,
    ingredients = { { "fo-helium-3", 1 }, { "fo-liquid-nitrogen", 10 } }, results = { { "fo-dilution-mix", 10 } } },
  { name = "fo-fridge-dilution-stage", epoch = 13, category = "fo-dilution", time = 20,
    ingredients = { { "fo-cryostat", 1 }, { "fo-helium-3", 20 }, { "fo-liquid-nitrogen", 10 } }, results = { { "fo-dilution-stage", 1 } },
    fr = "Étage à dilution (réfrigérateur)", en = "Dilution stage (refrigerator)" },
  { name = "fo-qlab-qubit-chip", epoch = 13, category = "fo-quantum-fab", time = 20,
    ingredients = { { "fo-etched-wafer", 1 }, { "fo-superconducting-tape", 2 } }, results = { { "fo-qubit-chip", 2 } },
    fr = "Puce à qubits (labo quantique)", en = "Qubit chip (quantum lab)" },
  { name = "fo-qlab-quantum-processor", epoch = 13, category = "fo-quantum-fab", time = 30,
    ingredients = { { "fo-qubit-chip", 4 }, { "fo-dilution-stage", 1 }, { "fo-logic-die", 2 }, { "fo-sram-die", 4 }, { "fo-motherboard", 1 } },
    results = { { "fo-quantum-processor", 1 } }, fr = "Processeur quantique (labo quantique)", en = "Quantum processor (quantum lab)" },
  { name = "fo-rack-quantum", epoch = 13, category = "fo-rack-integration", time = 20,
    ingredients = { { "fo-quantum-processor", 1 }, { "fo-heat-sink", 2 }, { "steel-plate", 10 } },
    results = { { "fo-quantum-rack", 1 } } },
  { name = "fo-dc-dilution", epoch = 13, category = "fo-dc-cryo", time = 10, cooling = true,
    ingredients = { { "fo-chilled-water", 100 }, { "fo-dilution-mix", 10 } }, results = { { "fo-warm-water", 100 } },
    fr = "Refroidissement à dilution (quantique)", en = "Dilution cooling (quantum)" },
}

-- Recettes des bâtiments.
Cv.BUILDING_RECIPES = {
  -- Tireuse : recette d'X3 telle quelle (aucun quartz).
  { name = "fo-crystal-puller", epoch = 10, category = "advanced-crafting", time = 10,
    ingredients = { { "steel-plate", 10 }, { "fo-graphite", 10 }, { "fo-coil", 5 }, { "advanced-circuit", 5 }, { "fo-glass", 10 } } },
  { name = "fo-wire-saw", epoch = 10, category = "advanced-crafting", time = 10,
    ingredients = { { "steel-plate", 10 }, { "iron-gear-wheel", 10 }, { "electric-engine-unit", 4 }, { "fo-tungsten-plate", 4 } } },
  { name = "fo-plasma-etcher", epoch = 10, category = "advanced-crafting", time = 10,
    ingredients = { { "steel-plate", 15 }, { "fo-coil", 10 }, { "advanced-circuit", 10 }, { "pipe", 10 }, { "fo-glass", 10 } } },
  { name = "fo-die-prober", epoch = 10, category = "advanced-crafting", time = 10,
    ingredients = { { "steel-plate", 10 }, { "processing-unit", 4 }, { "fo-crystal-laser", 1 }, { "iron-gear-wheel", 10 } } },
  { name = "fo-packaging-line", epoch = 10, category = "advanced-crafting", time = 10,
    ingredients = { { "steel-plate", 10 }, { "electric-engine-unit", 4 }, { "advanced-circuit", 10 }, { "iron-gear-wheel", 10 } } },
  { name = "fo-smt-line", epoch = 10, category = "advanced-crafting", time = 15,
    ingredients = { { "steel-plate", 20 }, { "electric-engine-unit", 8 }, { "advanced-circuit", 10 }, { "fo-crystal-laser", 1 } } },
  { name = "fo-fiber-tower", epoch = 10, category = "advanced-crafting", time = 15,
    ingredients = { { "steel-plate", 20 }, { "fo-glass", 20 }, { "fo-coil", 10 }, { "advanced-circuit", 5 } } },
  { name = "fo-rack-integrator", epoch = 10, category = "advanced-crafting", time = 15,
    ingredients = { { "steel-plate", 20 }, { "electric-engine-unit", 6 }, { "advanced-circuit", 10 }, { "iron-gear-wheel", 20 } } },
  { name = "fo-chiller", epoch = 10, category = "advanced-crafting", time = 15,
    ingredients = { { "steel-plate", 20 }, { "pipe", 20 }, { "electric-engine-unit", 6 }, { "advanced-circuit", 4 } } },
  { name = "fo-cooling-tower", epoch = 10, category = "advanced-crafting", time = 15,
    ingredients = { { "concrete", 50 }, { "steel-plate", 20 }, { "pipe", 20 }, { "electric-engine-unit", 4 } } },
  -- Centre : le bâti seul (les baies se posent ensuite). La recette v1 (4 baies usées dans le bâti) est cachée.
  { name = "fo-data-center-frame", product = "fo-data-center", epoch = 10, category = "advanced-crafting", time = 30,
    ingredients = { { "steel-plate", 20 }, { "concrete", 20 }, { "pipe", 10 }, { "fo-motherboard", 2 }, { "fo-network-switch", 1 } },
    fr = "Centre de calcul (bâti)", en = "Data center (frame)" },
  { name = "fo-data-center-2", epoch = 12, category = "advanced-crafting", time = 60,
    ingredients = { { "steel-plate", 50 }, { "concrete", 50 }, { "pipe", 20 }, { "fo-motherboard", 4 }, { "fo-network-switch", 4 },
                    { "fo-superconducting-tape", 10 } } },
  { name = "fo-dilution-fridge", epoch = 13, category = "advanced-crafting", time = 20,
    ingredients = { { "fo-cryostat", 2 }, { "steel-plate", 20 }, { "pipe", 10 }, { "processing-unit", 4 } } },
  { name = "fo-quantum-lab", epoch = 13, category = "advanced-crafting", time = 30,
    ingredients = { { "steel-plate", 50 }, { "concrete", 40 }, { "fo-superconducting-tape", 20 }, { "processing-unit", 10 }, { "fo-crystal-laser", 4 } } },
}
for _, b in ipairs(Cv.BUILDING_RECIPES) do b.results = { { b.product or b.name, 1 } } end

-- Recettes v1 CACHÉES pour un nouveau choix (toujours valides là où elles sont posées ; Q-CV2-1 au DC : vider cette liste
-- remet la v1 en voie). Restent visibles de la v1 : résine, photomasque, laser, radiateur, dégazage, ilménite dégazée,
-- lithographe.
Cv.HIDE_V1 = { "fo-etched-wafer", "fo-logic-die", "fo-dram-die", "fo-sram-die", "fo-chip-processor", "fo-memory-module",
               "fo-motherboard", "fo-server-blade", "fo-graphics-card", "fo-gpu-blade", "fo-qubit-chip", "fo-dilution-stage",
               "fo-quantum-processor", "fo-compute-classic", "fo-compute-accelerated", "fo-compute-quantum", "fo-data-center" }

---------------------------------------------------------------------------------------------------
-- Technologies : les 5 de la v1 gardent leur nom et leurs déblocages v1 (recettes cachées comprises), et ouvrent en plus
-- les recettes v2 ; deux neuves. Une sauvegarde où une technologie v1 est recherchée reçoit ses déblocages v2 et les
-- prérequis neufs (migrations/calcul-v2.lua).
---------------------------------------------------------------------------------------------------
Cv.TECHS = {
  { name = "fo-wafer-fab", epoch = 10, count = 400, time = 30, new = true,
    prerequisites = { "fo-chip-foundry", "fo-methane-reforming" },
    unlocks = { "fo-crystal-puller", "fo-silicon-ingot", "fo-wire-saw", "fo-ingot-sawing", "fo-wafer-exposure", "fo-plasma-etcher",
                "fo-plasma-etching", "fo-die-prober", "fo-die-test-logic", "fo-die-test-dram", "fo-die-test-sram", "fo-die-test-nand",
                "fo-packaging-line", "fo-packaged-processor", "fo-flash-drive" },
    fr = "Fonderie de tranches", en = "Wafer fab" },
  { name = "fo-data-centers", epoch = 10, add_prerequisites = { "fo-wafer-fab" },
    unlocks = { "fo-smt-line", "fo-smt-motherboard", "fo-smt-memory-module", "fo-fiber-tower", "fo-optical-fiber", "fo-network-switch",
                "fo-rack-integrator", "fo-rack-cpu", "fo-rack-memory", "fo-rack-storage", "fo-rack-network", "fo-rack-cooling",
                "fo-chiller", "fo-water-chilling", "fo-cooling-tower", "fo-warm-water-cooling", "fo-dc-chilled-water", "fo-data-center-frame" } },
  { name = "fo-gpu-computing", epoch = 11, unlocks = { "fo-smt-graphics-card", "fo-rack-gpu" } },
  { name = "fo-data-centers-2", epoch = 12, count = 600, time = 30, new = true,
    prerequisites = { "fo-gpu-computing", "fo-superconductors" },
    unlocks = { "fo-data-center-2", "fo-dc-liquid-nitrogen" },
    fr = "Grands centres de calcul", en = "Large data centers" },
  { name = "fo-quantum-computing", epoch = 13, add_prerequisites = { "fo-data-centers-2" },
    unlocks = { "fo-dilution-fridge", "fo-dilution-mix", "fo-fridge-dilution-stage", "fo-quantum-lab", "fo-qlab-qubit-chip",
                "fo-qlab-quantum-processor", "fo-rack-quantum", "fo-dc-dilution" } },
}

--- Technologie v2 par nom.
function Cv.tech(name)
  for _, t in ipairs(Cv.TECHS) do if t.name == name then return t end end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Écarts au plan de l'architecte (déclarés, à valider)
---------------------------------------------------------------------------------------------------
Cv.PLAN_DEVIATIONS = {
  { what = "fo-plasma-etching", fr = "acide sulfurique + HYDROGÈNE, pas de chlore : le chlore n'est en jeu qu'à l'âge 11 (électrolyse de la saumure du titane)" },
  { what = "fo-network-switch", fr = "fabriqué à la ligne de pose CMS (une carte), pas à la tour de fibrage (qui tire le verre)" },
  { what = "fo-silicon-ingot", fr = "creuset de quartz remplacé par 1 graphite (quartz parqué par Q26)" },
  { what = "fo-baie", fr = "une catégorie de module unique, rang 1 pour toutes les baies (Ctrl+clic ne remplace jamais une baie par une autre)" },
  { what = "fo-data-center-frame", fr = "le centre se construit en bâti seul (la recette v1 usait 4 baies) ; la v1 est cachée" },
}

---------------------------------------------------------------------------------------------------
-- Présence, fluides, MU
---------------------------------------------------------------------------------------------------
local IN_GAME, FLUID = {}, {}
for _, it in ipairs(Cv.ITEMS) do IN_GAME[it.name] = true end
for _, f in ipairs(Cv.FLUIDS) do IN_GAME[f.name] = true; FLUID[f.name] = true end
for _, r in ipairs(Cv.RACKS) do IN_GAME[r.name] = true end
for _, m in ipairs(Cv.MACHINES) do IN_GAME[m.name] = true end

--- En jeu avec ce lot (v1 et v2) et ceux dont il dépend ?
function Cv.present(name) return IN_GAME[name] == true or Cp.present(name) end

local MORE_FLUIDS = { ["fo-hydrogen"] = true, ["fo-liquid-nitrogen"] = true, ["fo-helium-3"] = true }
function Cv.is_fluid(name) return FLUID[name] == true or MORE_FLUIDS[name] == true or Cp.is_fluid(name) end

--- Catégories neuves (créées par ce lot).
Cv.NEW_CATEGORIES = { "fo-crystal-pulling", "fo-wire-sawing", "fo-plasma-etching", "fo-die-testing", "fo-packaging", "fo-smt",
                      "fo-fiber-drawing", "fo-rack-integration", "fo-chilling", "fo-heat-rejection", "fo-dc-cooling", "fo-dc-cryo",
                      "fo-dilution", "fo-quantum-fab" }

--- Recette v2 (procédé ou bâtiment) par nom.
function Cv.recipe(name)
  for _, r in ipairs(Cv.RECIPES) do if r.name == name then return r end end
  for _, r in ipairs(Cv.BUILDING_RECIPES) do if r.name == name then return r end end
  return nil
end

--- Machine v2 par nom (ou le centre modulaire).
function Cv.machine(name)
  for _, m in ipairs(Cv.MACHINES) do if m.name == name then return m end end
  return nil
end

--- Recettes de refroidissement du centre (limitation des baies).
function Cv.cooling_recipes()
  local out = {}
  for _, r in ipairs(Cv.RECIPES) do if r.cooling then out[#out + 1] = r.name end end
  return out
end

-- MU (BALANCE_SHEET §3) d'un objet par la voie v2 : recette v2 qui le fabrique (pas une variante), sinon Cp.mu (v1,
-- crafts, X3, X0). Les fluides d'eau ne coûtent rien.
local FREE = { water = true, steam = true, ["fo-chilled-water"] = true, ["fo-warm-water"] = true }
function Cv.mu(item, via, depth)
  depth = depth or 0
  assert(depth < 16, "calcul v2 : MU trop profond pour " .. item)
  if FREE[item] then return 0 end
  local r, per
  if via then
    r = assert(Cv.recipe(via), "calcul v2 : recette inconnue " .. via)
  else
    for _, x in ipairs(Cv.RECIPES) do
      if not x.variant and not r then
        for _, p in ipairs(x.results) do if p[1] == item then r = x end end
      end
    end
  end
  if not r then return Cp.mu(item) end
  for _, p in ipairs(r.results) do if p[1] == item then per = p[2] end end
  assert(per and per > 0, "calcul v2 : " .. r.name .. " ne rend pas " .. item)
  local s = 0
  for _, i in ipairs(r.ingredients) do s = s + Cv.mu(i[1], nil, depth + 1) * i[2] end
  return s / per
end

return Cv
