--[[
  Lot CALCUL (30/10, retour du DC du matin : « n'oubliez pas les centres de calcul avec les différentes étapes, de
  processeur, de mémoire, caches, cartes graphique, carte mère etc etc, processeur quantique aussi »). Plan de
  l'architecte : <racine>/fo-logs/2026-10-30_RETOUR-MATIN/CALCUL/PLAN.md. Décisions : D-19 (le calcul est une ressource de
  réseau, produite par un centre qui consomme courant et refroidissement), D-20 (4) (calcul NON stockable, tenu par script).

  Lua PUR (tests/compute_test.lua) ; prototypes : prototypes/compute.lua ; script : script/compute/compute.lua.

  LA CHAÎNE, par étapes :
    âge 10  [lithographe à cristal] tranches de silicium + photomasque + résine photosensible + acide → TRANCHES GRAVÉES
            [salle blanche, découpe] tranche gravée → 4 puces logiques | 8 puces DRAM | 8 puces de cache SRAM
            radiateur d'aluminium ; PROCESSEUR GRAVÉ (variante du processeur vanilla : 1 puce logique + 2 caches + carte
            imprimée + radiateur + circuits) ; BARRETTE DE MÉMOIRE VIVE (8 DRAM) ; CARTE MÈRE (cartes imprimées +
            oscillateur à cristal, l'horloge) ; BAIE DE SERVEURS (carte mère + 2 processeurs + 4 barrettes + 2 radiateurs) ;
            CENTRE DE CALCUL (4 × 4, 10 MW) : eau + 1 baie usée / 300 s → 100 unités de calcul / s
    âge 11  CARTE GRAPHIQUE (4 logiques + 8 DRAM + titane) → BAIE D'ACCÉLÉRATEURS → 400 unités / s
    âge 13  hélium-3 par le DÉGAZAGE DU RÉGOLITHE de X0 (ilménite → ilménite dégazée + hélium-3, four de frittage) ;
            PUCE À QUBITS (tranche gravée + bande supraconductrice) ; ÉTAGE À DILUTION (cryostat + hélium-3 + azote
            liquide) ; PROCESSEUR QUANTIQUE → 2 000 unités / s

  Origine de chaque morceau (rien n'est caché) :
    - X3 tel quel (shared/content/x3.lua, proposition ; repris de la branche parquée corr-x3-minerais, SANS le quartz,
      parqué par Q26) : résine photosensible, photomasque, laser à cristal, lithographe à cristal, tranche gravée ;
    - X0 tel quel (shared/content/epochs.lua) : dégazage du régolithe et fusion de l'ilménite dégazée (technologie
      fo-regolith-degassing de l'âge 13), l'ilménite dégazée et l'hélium-3 ;
    - PLAN CALCUL (inventé par l'architecte le 30/10, quantités à recaler par les bancs) : puces, radiateur, processeur
      gravé, barrette, carte mère, baies, carte graphique, puce à qubits, étage à dilution, processeur quantique, centre de
      calcul et ses 3 recettes. ÉCARTS À X3, déclarés (Cp.X3_DEVIATIONS) : la barrette et la carte graphique ont d'autres
      recettes qu'X3 ; le centre ne rend plus de fluide « fo-compute » (D-20 (4)) ; la carte graphique passe de 10 à 11.

  Règle X3 « des voies, jamais une porte » : le processeur gravé est une VARIANTE du processeur vanilla, qui reste ; D-20 (1)
  (fonderie obligatoire) n'est PAS appliquée (question Q-CALC-3 au DC ; liste Cp.MANDATORY_STEP).
]]

local X = require("shared.content.epochs")
local X3 = require("shared.content.x3")
local T = require("shared.content.titanium")
local C = require("shared.content.crafts")
local Sn = require("shared.content.tin")
local B = require("shared.content.bauxite")
local SC = require("shared.content.superconductors")

local Cp = {}

---------------------------------------------------------------------------------------------------
-- Objets, fluides, bâtiments
---------------------------------------------------------------------------------------------------
-- { name, epoch, stack, src = "x3" | "x0" | "plan", fr, en }
Cp.ITEMS = {
  { name = "fo-photomask", epoch = 10, stack = 50, src = "x3" },
  { name = "fo-etched-wafer", epoch = 10, stack = 100, src = "x3" },
  { name = "fo-crystal-laser", epoch = 10, stack = 50, src = "x3" },
  { name = "fo-logic-die", epoch = 10, stack = 200, src = "plan", fr = "Puce logique", en = "Logic die" },
  { name = "fo-dram-die", epoch = 10, stack = 200, src = "plan", fr = "Puce de mémoire DRAM", en = "DRAM die" },
  { name = "fo-sram-die", epoch = 10, stack = 200, src = "plan", fr = "Puce de cache SRAM", en = "SRAM cache die" },
  { name = "fo-heat-sink", epoch = 10, stack = 100, src = "plan", fr = "Radiateur d'aluminium", en = "Aluminium heat sink" },
  { name = "fo-memory-module", epoch = 10, stack = 100, src = "plan", fr = "Barrette de mémoire vive", en = "RAM module" },
  { name = "fo-motherboard", epoch = 10, stack = 50, src = "plan", fr = "Carte mère", en = "Motherboard" },
  { name = "fo-server-blade", epoch = 10, stack = 20, src = "plan", fr = "Baie de serveurs", en = "Server blade" },
  { name = "fo-graphics-card", epoch = 11, stack = 50, src = "plan", fr = "Carte graphique", en = "Graphics card" },
  { name = "fo-gpu-blade", epoch = 11, stack = 20, src = "plan", fr = "Baie d'accélérateurs", en = "Accelerator blade" },
  { name = "fo-degassed-ilmenite", epoch = 13, stack = 50, src = "x0" },
  { name = "fo-qubit-chip", epoch = 13, stack = 100, src = "plan", fr = "Puce à qubits", en = "Qubit chip" },
  { name = "fo-dilution-stage", epoch = 13, stack = 10, src = "plan", fr = "Étage à dilution", en = "Dilution stage" },
  { name = "fo-quantum-processor", epoch = 13, stack = 10, src = "plan", fr = "Processeur quantique", en = "Quantum processor" },
}
Cp.FLUIDS = {
  { name = "fo-photoresist", epoch = 10, src = "x3" },
  { name = "fo-helium-3", epoch = 13, src = "x0" },
}

-- Bâtiments. Visuel PROVISOIRE : copie teintée d'une machine vanilla mise à l'échelle (le DC exige un vrai modèle comparé
-- au vanilla AVANT la série : lot CALC-D). side : côté de la machine copiée.
Cp.BUILDINGS = {
  -- X3 : 4 × 4, 3 MW, 2 entrées de fluide (résine photosensible, acide).
  { name = "fo-crystal-lithograph", src = "x3", epoch = 10, copy = "assembling-machine-3", side = 3,
    tint = { r = 0.70, g = 0.88, b = 1.00 } },
  -- PLAN : 4 × 4, 10 MW, 2 entrées de fluide (eau de refroidissement, hélium-3 pour le calcul quantique), aucun module.
  { name = "fo-data-center", src = "plan", epoch = 10, copy = "assembling-machine-3", side = 3,
    tint = { r = 0.55, g = 0.62, b = 0.80 },
    size = { 4, 4 }, kw = 10000, speed = 1, categories = { "fo-computing" }, fluid_in = 2,
    fr = "Centre de calcul", en = "Data center" },
}

---------------------------------------------------------------------------------------------------
-- Recettes : { name, epoch, src, category, time, ingredients, results, variant, compute, prod, fr, en }
--   compute : unités de calcul rendues par UNE fabrication (recettes du centre, sans produit) ;
--   variant : la recette rend un objet vanilla par une autre voie (le vanilla reste).
---------------------------------------------------------------------------------------------------
local P = {} -- recettes du PLAN, à leur place dans Cp.RECIPES
Cp.RECIPES = {
  -- Âge 10 : lithographie (X3)
  { name = "fo-photoresist", src = "x3" },
  { name = "fo-photomask", src = "x3" },
  { name = "fo-crystal-laser", src = "x3" },
  { name = "fo-etched-wafer", src = "x3" },
  -- Âge 10 : découpe et test en salle blanche (PLAN)
  { name = "fo-logic-die", src = "plan", epoch = 10, category = "fo-cleanroom", time = 5,
    ingredients = { { "fo-etched-wafer", 1 } }, results = { { "fo-logic-die", 2 } }, prod = true },
  { name = "fo-dram-die", src = "plan", epoch = 10, category = "fo-cleanroom", time = 5,
    ingredients = { { "fo-etched-wafer", 1 } }, results = { { "fo-dram-die", 4 } }, prod = true },
  { name = "fo-sram-die", src = "plan", epoch = 10, category = "fo-cleanroom", time = 5,
    ingredients = { { "fo-etched-wafer", 1 } }, results = { { "fo-sram-die", 4 } }, prod = true },
  -- Âge 10 : boîtier, mémoire, carte mère, baie (PLAN)
  { name = "fo-heat-sink", src = "plan", epoch = 10, category = "crafting", time = 2,
    ingredients = { { "fo-aluminium-plate", 2 }, { "copper-plate", 1 } }, results = { { "fo-heat-sink", 1 } } },
  { name = "fo-chip-processor", src = "plan", epoch = 10, category = "fo-cleanroom", time = 10, variant = "processing-unit",
    ingredients = { { "fo-logic-die", 1 }, { "fo-sram-die", 2 }, { "fo-printed-circuit-board", 1 }, { "fo-heat-sink", 1 },
                    { "electronic-circuit", 12 }, { "advanced-circuit", 2 } },
    results = { { "processing-unit", 1 } }, prod = true,
    fr = "Processeur gravé (puces)", en = "Processor from dies" },
  { name = "fo-memory-module", src = "plan", epoch = 10, category = "fo-cleanroom", time = 10,
    ingredients = { { "fo-dram-die", 8 }, { "fo-printed-circuit-board", 1 }, { "fo-tin-plate", 1 } },
    results = { { "fo-memory-module", 2 } }, prod = true },
  { name = "fo-motherboard", src = "plan", epoch = 10, category = "fo-circuit-printing", time = 10,
    ingredients = { { "fo-printed-circuit-board", 2 }, { "fo-crystal-oscillator", 1 }, { "advanced-circuit", 2 }, { "copper-cable", 4 } },
    results = { { "fo-motherboard", 1 } }, prod = true },
  { name = "fo-server-blade", src = "plan", epoch = 10, category = "crafting", time = 15,
    ingredients = { { "fo-motherboard", 1 }, { "processing-unit", 2 }, { "fo-memory-module", 4 }, { "fo-heat-sink", 2 },
                    { "steel-plate", 5 } },
    results = { { "fo-server-blade", 1 } } },
  -- Âge 10 : exploitation du centre (PLAN) : 10 eau/s, 1 baie usée / 300 s, 100 unités/s
  { name = "fo-compute-classic", src = "plan", epoch = 10, category = "fo-computing", time = 300,
    ingredients = { { "fo-server-blade", 1 }, { "water", 3000 } }, results = {}, compute = 30000,
    fr = "Calcul classique", en = "Classic computing" },
  -- Âge 11 : accélérateurs (PLAN)
  { name = "fo-graphics-card", src = "plan", epoch = 11, category = "fo-cleanroom", time = 15,
    ingredients = { { "fo-logic-die", 4 }, { "fo-dram-die", 8 }, { "fo-printed-circuit-board", 1 }, { "fo-heat-sink", 2 },
                    { "fo-titanium-plate", 1 } },
    results = { { "fo-graphics-card", 1 } }, prod = true },
  { name = "fo-gpu-blade", src = "plan", epoch = 11, category = "crafting", time = 15,
    ingredients = { { "fo-motherboard", 1 }, { "processing-unit", 1 }, { "fo-graphics-card", 4 }, { "fo-memory-module", 2 } },
    results = { { "fo-gpu-blade", 1 } } },
  { name = "fo-compute-accelerated", src = "plan", epoch = 11, category = "fo-computing", time = 300,
    ingredients = { { "fo-gpu-blade", 1 }, { "water", 3000 } }, results = {}, compute = 120000,
    fr = "Calcul accéléré", en = "Accelerated computing" },
  -- Âge 13 : hélium-3 (X0) et processeur quantique (PLAN)
  { name = "fo-regolith-degassing", src = "x0" },
  { name = "fo-degassed-ilmenite-smelting", src = "x0" },
  { name = "fo-qubit-chip", src = "plan", epoch = 13, category = "fo-lithography", time = 20,
    ingredients = { { "fo-etched-wafer", 1 }, { "fo-superconducting-tape", 2 } }, results = { { "fo-qubit-chip", 2 } }, prod = true },
  { name = "fo-dilution-stage", src = "plan", epoch = 13, category = "fo-cryogenics", time = 20,
    ingredients = { { "fo-cryostat", 1 }, { "fo-helium-3", 20 }, { "fo-liquid-nitrogen", 10 } }, results = { { "fo-dilution-stage", 1 } } },
  { name = "fo-quantum-processor", src = "plan", epoch = 13, category = "fo-cleanroom", time = 30,
    ingredients = { { "fo-qubit-chip", 4 }, { "fo-dilution-stage", 1 }, { "fo-logic-die", 2 }, { "fo-sram-die", 4 },
                    { "fo-motherboard", 1 } },
    results = { { "fo-quantum-processor", 1 } } },
  -- Hélium-3 : 300 par 600 s (0,5/s, pertes d'un cryostat à dilution en circuit fermé), soit environ 1,3 four de frittage
  -- sur le dégazage de X0 (0,1 par 0,267 s). Relecture du 30/10 : 3 000 (5/s) demandait environ 13 fours et 100 minerais
  -- d'ilménite par seconde pour UN centre, sans commune mesure avec le centre classique (eau seule).
  { name = "fo-compute-quantum", src = "plan", epoch = 13, category = "fo-computing", time = 600,
    ingredients = { { "fo-quantum-processor", 1 }, { "water", 6000 }, { "fo-helium-3", 300 } }, results = {}, compute = 1200000,
    fr = "Calcul quantique", en = "Quantum computing" },
}

-- Recettes des bâtiments : X3 pour le lithographe, PLAN pour le centre (X3 : cartes graphiques + contrôleurs, absents).
Cp.BUILDING_RECIPES = {
  { name = "fo-crystal-lithograph", src = "x3" },
  { name = "fo-data-center", src = "plan", epoch = 10, category = "crafting", time = 30,
    ingredients = { { "fo-server-blade", 4 }, { "steel-plate", 20 }, { "concrete", 20 }, { "pipe", 10 } },
    results = { { "fo-data-center", 1 } } },
}

---------------------------------------------------------------------------------------------------
-- Technologies (packs vanilla de la fenêtre de l'âge, règle des lots CRAFTS ; unités par C.tech_count)
---------------------------------------------------------------------------------------------------
Cp.TECHS = {
  -- X3 « fonderie de puces », sans la partie quartz (parquée, Q26) ; prérequis de la branche parquée.
  { name = "fo-chip-foundry", epoch = 10, count = 400, time = 30, src = "x3",
    prerequisites = { "fo-silicon", "fo-aluminium", "fo-printed-circuits", "fo-lapidary", "advanced-electronics-2" },
    unlocks = { "fo-photoresist", "fo-photomask", "fo-crystal-laser", "fo-crystal-lithograph", "fo-etched-wafer",
                "fo-logic-die", "fo-dram-die", "fo-sram-die", "fo-heat-sink", "fo-chip-processor" },
    fr = "Fonderie de puces", en = "Chip foundry" },
  { name = "fo-data-centers", epoch = 10, count = 400, time = 30, src = "plan",
    prerequisites = { "fo-chip-foundry" },
    unlocks = { "fo-memory-module", "fo-motherboard", "fo-server-blade", "fo-data-center", "fo-compute-classic" },
    fr = "Centres de calcul", en = "Data centers" },
  { name = "fo-gpu-computing", epoch = 11, count = 500, time = 30, src = "plan",
    prerequisites = { "fo-data-centers", "fo-titanium-processing" },
    unlocks = { "fo-graphics-card", "fo-gpu-blade", "fo-compute-accelerated" },
    fr = "Calcul accéléré", en = "Accelerated computing" },
  -- X0 tel quel (nom, âge, déblocages) ; prérequis : le four de frittage et la chaîne de l'ilménite.
  { name = "fo-regolith-degassing", epoch = 13, count = 800, time = 30, src = "x0",
    prerequisites = { "fo-superconductors", "fo-titanium-processing" },
    unlocks = { "fo-regolith-degassing", "fo-degassed-ilmenite-smelting" } },
  { name = "fo-quantum-computing", epoch = 13, count = 1200, time = 30, src = "plan",
    prerequisites = { "fo-gpu-computing", "fo-regolith-degassing", "fo-superconductors" },
    unlocks = { "fo-qubit-chip", "fo-dilution-stage", "fo-quantum-processor", "fo-compute-quantum" },
    fr = "Calcul quantique", en = "Quantum computing" },
}

-- Écarts à la proposition X3 (rien n'est modifié dans x3.lua ; l'intégrateur décidera de l'y reporter).
Cp.X3_DEVIATIONS = {
  { what = "fo-compute", fr = "fluide « calcul » d'X3 retiré : le calcul n'est pas stockable, il est tenu par script (D-20 (4))" },
  { what = "fo-memory-module", fr = "X3 : 1 tranche gravée + carte + étain → 2 ; ici 8 puces DRAM + carte + étain → 2 (étape de découpe)" },
  { what = "fo-graphics-card", fr = "X3 : âge 10, 4 tranches gravées + 2 barrettes... ; ici âge 11, 4 logiques + 8 DRAM + 2 radiateurs + titane" },
  { what = "fo-data-center", fr = "X3 : 10 cartes graphiques + 4 contrôleurs (absents) ; ici 4 baies de serveurs ; 2 entrées de fluide, aucune sortie" },
  { what = "fo-chip-processor", fr = "X3 (fo-etched-processor) : 2 tranches gravées + 2 cartes + 9 verts + 1 rouge ; ici puces découpées (logique, cache)" },
}

-- Pour D-20 (1) (fonderie OBLIGATOIRE à l'âge 10), le jour où le DC répond à Q-CALC-3 : proposition, non appliquée.
Cp.MANDATORY_STEP = {
  hide = { "processing-unit", "fo-cleanroom-processor" },
  becomes_mandatory = { "fo-cassiterite", "fo-bauxite" },
  why_fr = "le processeur gravé demande une carte imprimée (étain) et un radiateur d'aluminium (bauxite)",
}

---------------------------------------------------------------------------------------------------
-- Résolution des recettes (X3, X0, PLAN)
---------------------------------------------------------------------------------------------------
local x3_recipe, x3_building, x3_item = {}, {}, {}
for _, r in ipairs(X3.recipes) do if not x3_recipe[r.name] then x3_recipe[r.name] = r end end
for _, b in ipairs(X3.buildings) do x3_building[b.name] = b end
for _, it in ipairs(X3.items) do x3_item[it.name] = it end

local function resolve(spec)
  if spec.src == "x3" then
    local r = assert(x3_recipe[spec.name], "calcul : recette X3 absente " .. spec.name)
    return { name = r.name, epoch = r.epoch, src = "x3", category = r.category, time = r.time, ingredients = r.ingredients,
             results = r.results, prod = r.prod == true }
  elseif spec.src == "x0" then
    local r = assert(T.x_recipe(spec.name), "calcul : recette X0 absente " .. spec.name)
    return { name = r.name, epoch = r.epoch, src = "x0", category = r.category, time = r.time, ingredients = r.ingredients,
             results = r.results, prod = r.prod == true, fr = r.fr, en = r.en }
  end
  return spec
end

--- Recette de procédé du lot (résolue).
function Cp.recipe(name)
  for _, s in ipairs(Cp.RECIPES) do if s.name == name then return resolve(s) end end
  for _, s in ipairs(Cp.BUILDING_RECIPES) do if s.name == name then return resolve(s) end end
  error("calcul : recette inconnue " .. name)
end

--- Toutes les recettes de procédé (résolues), ordre de Cp.RECIPES.
function Cp.all_recipes()
  local out = {}
  for _, s in ipairs(Cp.RECIPES) do out[#out + 1] = resolve(s) end
  return out
end

--- Recettes des bâtiments (résolues).
function Cp.building_recipes()
  local out = {}
  for _, s in ipairs(Cp.BUILDING_RECIPES) do out[#out + 1] = resolve(s) end
  return out
end

--- Bâtiment : stats (taille, kW, vitesse, catégories, entrées de fluide), d'X3 ou du plan.
function Cp.building(name)
  for _, b in ipairs(Cp.BUILDINGS) do
    if b.name == name then
      if b.src == "x3" then
        local x = assert(x3_building[name], "calcul : bâtiment X3 absent " .. name)
        return { name = name, size = x.size, kw = x.kw, speed = x.speed, categories = x.categories, fluid_in = x.fluid_in or 0,
                 epoch = x.epoch, spec = b }
      end
      return { name = name, size = b.size, kw = b.kw, speed = b.speed, categories = b.categories, fluid_in = b.fluid_in or 0,
               epoch = b.epoch, spec = b }
    end
  end
  error("calcul : bâtiment inconnu " .. name)
end

--- Objet X3 ou X0 (pour la pile et les noms) ; nil pour un objet du plan.
function Cp.x_item(name) return x3_item[name] or T.x_item(name) end

local IN_GAME = {}
for _, it in ipairs(Cp.ITEMS) do IN_GAME[it.name] = true end
for _, f in ipairs(Cp.FLUIDS) do IN_GAME[f.name] = true end
for _, b in ipairs(Cp.BUILDINGS) do IN_GAME[b.name] = true end
local FLUID = {}
for _, f in ipairs(Cp.FLUIDS) do FLUID[f.name] = true end

--- En jeu avec ce lot et ceux dont il dépend (X1, CRAFTS, étain, bauxite, X2) ?
function Cp.present(name)
  return IN_GAME[name] == true or C.present(name) or Sn.present(name) or B.present(name) or SC.present(name)
end

local OTHER_FLUIDS = { water = true, steam = true, ["sulfuric-acid"] = true, ["light-oil"] = true, ["heavy-oil"] = true,
                       ["petroleum-gas"] = true, lubricant = true }
--- Fluide ? (lot, X3, X0, vanilla connus)
function Cp.is_fluid(name)
  if FLUID[name] or OTHER_FLUIDS[name] then return true end
  local x = x3_item[name] or T.x_item(name)
  return x ~= nil and x.type == "fluid"
end

--- Catégories neuves (créées par ce lot).
Cp.NEW_CATEGORIES = { "fo-lithography", "fo-computing" }

--- Unités de calcul par fabrication d'une recette du centre (0 sinon).
function Cp.compute_per_craft(name)
  for _, s in ipairs(Cp.RECIPES) do if s.name == name then return s.compute or 0 end end
  return 0
end

--- Unités de calcul par seconde d'un centre à pleine marche sur une recette.
function Cp.compute_rate(name)
  local r = Cp.recipe(name)
  local speed = Cp.building("fo-data-center").speed
  return Cp.compute_per_craft(name) * speed / r.time
end

--- Recettes du centre (ordre fixe).
function Cp.compute_recipes()
  local out = {}
  for _, s in ipairs(Cp.RECIPES) do if s.compute then out[#out + 1] = s.name end end
  return out
end

--- Recettes éligibles à la productivité : « prod » (X3 ou plan), jamais une recette de bâtiment ni de calcul.
function Cp.productivity_recipes()
  local out = {}
  for _, r in ipairs(Cp.all_recipes()) do
    if r.prod and Cp.compute_per_craft(r.name) == 0 and #(r.results or {}) > 0 then out[#out + 1] = r.name end
  end
  return out
end

--- Unités et packs d'une technologie (règles des lots CRAFTS).
function Cp.tech_count(t) return C.tech_count(t) end
-- Âge 13 : la fenêtre X0 n'a plus que des packs du mod (absents du jeu) et C.packs(13) rend rouge, vert, militaire
-- seulement (moins que l'âge 10) ; ÉCART déclaré : les packs vanilla de l'âge 12 (tous sauf le spatial).
function Cp.packs(k) return C.packs(math.min(k, 12)) end

---------------------------------------------------------------------------------------------------
-- LE CALCUL PAR SCRIPT (D-20 (4)) : règles pures, appelées par script/compute/compute.lua
---------------------------------------------------------------------------------------------------
Cp.WINDOW_TICKS = 60               -- une fenêtre de mesure par seconde
-- Bonus de vitesse de recherche (Q-CALC-2, PROVISOIRE) : +1 % par 5 unités/s, plafond +200 %.
-- Un centre classique (100/s) : +20 % ; accéléré (400/s) : +80 % ; un centre quantique (2 000/s) atteint le plafond.
Cp.LAB_BONUS_PER_UNIT = 0.01 / 5
Cp.LAB_BONUS_CAP = 2.0

--- Avancement total d'un centre : fabrications finies + avancement de la fabrication en cours (0 à 1).
function Cp.progress(products_finished, crafting_progress)
  return (products_finished or 0) + (crafting_progress or 0)
end

--- Calcul produit par un centre entre deux lectures : (avancement_now - avancement_prev) × unités par fabrication de la
--- recette en cours. Une lecture précédente absente (centre neuf), une recette changée ou un recul (machine reconstruite)
--- ne comptent RIEN : on ne fabrique jamais de calcul à partir d'un état inconnu.
function Cp.delta(prev, now)
  if not prev or not now or prev.recipe ~= now.recipe or not now.recipe then return 0 end
  local d = now.progress - prev.progress
  if d <= 0 then return 0 end
  return d * Cp.compute_per_craft(now.recipe)
end

--- Débit d'une fenêtre (unités / s) à partir de la somme des deltas de la fenêtre et de sa durée en ticks.
function Cp.rate(sum_units, ticks)
  if not ticks or ticks <= 0 then return 0 end
  return sum_units * 60 / ticks
end

--- Bonus de recherche (fraction) pour un débit de calcul (unités / s), plafonné. Jamais négatif.
function Cp.lab_bonus(rate)
  if not rate or rate <= 0 then return 0 end
  return math.min(Cp.LAB_BONUS_CAP, rate * Cp.LAB_BONUS_PER_UNIT)
end

--- Nouvelle valeur de laboratory_speed_modifier : on retire la part posée à la fenêtre précédente et on pose la nouvelle.
--- La part des technologies (écrite par le moteur dans le même champ) est ainsi gardée, même si une recherche finit entre
--- deux fenêtres. Le résultat n'est jamais sous la base des technologies (current - applied_prev), ni sous 0.
function Cp.lab_modifier(current, applied_prev, applied_new)
  local base = (current or 0) - (applied_prev or 0)
  if base < 0 then base = 0 end
  return base + (applied_new or 0), base
end

---------------------------------------------------------------------------------------------------
-- MU (BALANCE_SHEET §3) : coût en matières premières, pour comparer le processeur gravé au vanilla
---------------------------------------------------------------------------------------------------
-- Matières premières et objets d'autres lots non dépliés ici : valeur en MU (1 MU = 1 plaque de fer). Les ressources du
-- monde valent 1 (minerai) ou X.FLUID_MU (fluide), comme le minerai vanilla. Valeurs d'autres lots : leur recette dépliée à
-- la main (sources dans le commentaire), arrondies.
Cp.MU_LEAF = {
  ["fo-resonance-crystal"] = 1, ["fo-tungsten-ore"] = 1, ["fo-ilmenite-ore"] = 1, ["fo-cassiterite"] = 1, ["fo-bauxite"] = 1,
  ["fo-monazite-ore"] = 1, sulfur = 1, -- soufre vanilla : 30 gaz + 30 eau → 2 soufres, 1,5 MU ; compté 1 (pétrole)
  ["fo-titanium-plate"] = 20,          -- monnaie de l'âge 11 (C.MU)
  ["fo-superconducting-tape"] = 5,     -- X2 : 1 yttrium + 3 cuivres + 20 oxygène → 4 ; yttrium de la monazite : environ 5 MU
  ["fo-cryostat"] = 98,                -- S.DEVIATIONS : 98 MU
  ["fo-liquid-nitrogen"] = 0.02,       -- distillation de l'air, sans ingrédient : énergie seule
  ["fo-ilmenite-concentrate"] = 2,     -- X1 : 2 minerais d'ilménite par concentré (environ)
  ["fo-coke"] = 1,                     -- X1 : charbon → coke, environ 1 MU
  ["fo-helium-3"] = X.FLUID_MU,        -- sous-produit du dégazage (l'ilménite dégazée rend 3 fers par unité, plus que son coût)
}

local function first_maker(item)
  for _, r in ipairs(Cp.all_recipes()) do
    if not r.variant and not (Cp.compute_per_craft(r.name) > 0) then
      for _, p in ipairs(r.results or {}) do if p[1] == item then return r, p[2] end end
    end
  end
  for _, r in ipairs(X3.recipes) do
    if (r.kind == "recipe" or r.kind == nil) and not r.variant_of then
      for _, p in ipairs(r.results or {}) do if p[1] == item then return r, p[2] end end
    end
  end
  local m, q = T.maker(item)
  if m then return m, q end
  return nil
end

--- MU d'une unité de `item` (via : recette du lot à employer pour cet objet).
function Cp.mu(item, via, depth)
  depth = depth or 0
  assert(depth < 14, "calcul : MU trop profond pour " .. item)
  if Cp.MU_LEAF[item] then return Cp.MU_LEAF[item] end
  if not via then
    local ok, c = pcall(C.raw_cost, item)
    if ok then return C.mu(c) end
  end
  local r, per
  if via then
    r = Cp.recipe(via)
    for _, p in ipairs(r.results) do if p[1] == item then per = p[2] end end
  else
    r, per = first_maker(item)
  end
  assert(r and per and per > 0, "calcul : MU sans recette pour " .. item)
  local s = 0
  for _, i in ipairs(r.ingredients) do
    local v = (i[1] == "water" or i[1] == "steam") and 0 or Cp.mu(i[1], nil, depth + 1)
    s = s + v * i[2]
  end
  -- Sous-produits rendus avec le produit : non déduits (prudent : le produit porte tout le coût).
  return s / per
end

return Cp
