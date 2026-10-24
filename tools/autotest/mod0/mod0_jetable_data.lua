-- Lot MOD-0 (24/10) : prototypes de TEST de la levée des risques « modules multiplicatifs » (scénario greffé
-- mod0-risques). Chargés SEULEMENT par la copie jetable du mod que fabrique tools/autotest/mod0/jetable.py (ce
-- fichier y est recopié à la racine et appelé en fin de data-final-fixes.lua). JAMAIS dans le mod livré.
--
-- Recettes (catégorie « mod0 », SANS ingrédient, produit mod0-jeton) : mod0-r05 (0,5 s), mod0-r10 (10 s),
--   mod0-r100 (100 s), mod0-r1000 (1 000 s) ; mod0-four (catégorie « mod0-four », 1 minerai de fer → 1 jeton, 0,5 s).
-- Machines (copies de assembling-machine-2, 34 emplacements de modules, tous effets permis, 100 kW, drain 0) :
--   mod0-asm-1, -10, -100, -1000 (crafting_speed 1, 10, 100, 1 000) ; mod0-asm-1gw, mod0-asm-1tw (1 GW, 1 TW) ;
--   mod0-asm-flux (100 kW, input_flow_limit 10 kW) ; mod0-asm-1tw-flux (1 TW, input_flow_limit 1 MW) ;
--   mod0-asm-tampon (100 kW, buffer_capacity 10 MJ).
-- Fours (copies de electric-furnace) mod0-four-1, -10, -100, -1000 ; foreuses (copies de electric-mining-drill)
--   mod0-foreuse-1, -10, -100, -1000 (mining_speed).
-- Balise CACHÉE mod0-balise-cachee : énergie void, boîte de 0,2 tuile sans collision, invisible, non sélectionnable,
--   supply_area_distance 0,3, distribution_effectivity 1, 20 emplacements, tous effets permis.
-- Source mod0-source (interface électrique invisible, sortie seule) et poteau mod0-poteau (zone de 13 x 13, fil de
--   1 tuile : chaque cellule du banc a SON réseau, mesuré par le scénario).
-- Modules de test (sans limitation) : mod0-v50, mod0-v80, mod0-v110 (paliers du DC), mod0-v115-brut (1.15 sans
--   epsilon : troncature), mod0-p10 (productivité +10 %), mod0-cplt-v100 (complément +100 %), valeurs extrêmes
--   mod0-v1000 / -v10000 / -v100000 (vitesse +10, +100, +1 000), mod0-v32767, mod0-v32768, mod0-v20000,
--   mod0-c1000 / -c10000 / -c100000 (consommation), mod0-p1000 / -p10000 / -p100000 (productivité).

local EMPTY = { filename = "__core__/graphics/empty.png", priority = "extra-high", width = 1, height = 1 }
local EMPTY_ANIM = { filename = "__core__/graphics/empty.png", priority = "extra-high", width = 1, height = 1,
  frame_count = 1 }
local HIDDEN = { "placeable-neutral", "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable",
  "not-selectable-in-game", "hidden", "not-upgradable", "not-in-kill-statistics", "hide-alt-info", "no-copy-paste",
  "no-automated-item-removal", "no-automated-item-insertion" }
local ALL = { "speed", "productivity", "consumption", "pollution" }
local GEAR = data.raw.item["iron-gear-wheel"]

local out = {}
local function add(p) out[#out + 1] = p end

add({ type = "recipe-category", name = "mod0" })
add({ type = "recipe-category", name = "mod0-four" })
add({ type = "item", name = "mod0-jeton", icon = GEAR.icon, icon_size = GEAR.icon_size, icon_mipmaps = GEAR.icon_mipmaps,
  subgroup = "intermediate-product", order = "z[mod0]-a", stack_size = 100000 })

local function recette(nom, cat, t, ing)
  add({ type = "recipe", name = nom, category = cat, energy_required = t, enabled = true, ingredients = ing or {},
    result = "mod0-jeton", result_count = 1, allow_decomposition = false, hide_from_player_crafting = true })
end
recette("mod0-r05", "mod0", 0.5)
recette("mod0-r10", "mod0", 10)
recette("mod0-r100", "mod0", 100)
recette("mod0-r1000", "mod0", 1000)
recette("mod0-four", "mod0-four", 0.5, { { "iron-ore", 1 } })

local function nettoie(p, nom)
  p.name = nom
  p.localised_name = { "", nom }
  p.localised_description = nil
  p.minable = nil
  p.placeable_by = nil
  p.fast_replaceable_group = nil
  p.next_upgrade = nil
  return p
end

local function elec(usage, extra)
  local s = { type = "electric", usage_priority = "secondary-input", drain = "0W" }
  for k, v in pairs(extra or {}) do s[k] = v end
  return s, usage
end

local function asm(nom, vitesse, usage, extra, item)
  local a = nettoie(table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"]), nom)
  a.crafting_categories = { "mod0" }
  a.crafting_speed = vitesse
  a.energy_source, a.energy_usage = elec(usage, extra)
  a.module_specification = { module_slots = 34, module_info_icon_shift = { 0, 0.4 }, module_info_max_icons_per_row = 6,
    module_info_max_icon_rows = 6 }
  a.allowed_effects = ALL
  a.base_productivity = nil
  a.fluid_boxes = nil
  a.fixed_recipe = nil
  if item then
    a.minable = { mining_time = 0.1, result = nom }
    a.flags = { "placeable-neutral", "placeable-player", "player-creation" }
    add({ type = "item", name = nom, icon = data.raw.item["assembling-machine-2"].icon, icon_size = 64, icon_mipmaps = 4,
      subgroup = "production-machine", order = "z[mod0]-" .. nom, place_result = nom, stack_size = 50 })
  end
  add(a)
end
asm("mod0-asm-1", 1, "100kW", nil, true)
asm("mod0-asm-10", 10, "100kW")
asm("mod0-asm-100", 100, "100kW")
asm("mod0-asm-1000", 1000, "100kW")
asm("mod0-asm-1gw", 1, "1GW")
asm("mod0-asm-1tw", 1, "1TW")
asm("mod0-asm-flux", 1, "100kW", { input_flow_limit = "10kW" })
asm("mod0-asm-1tw-flux", 1, "1TW", { input_flow_limit = "1MW" })
asm("mod0-asm-tampon", 1, "100kW", { buffer_capacity = "10MJ" })

local base_four = assert(data.raw.furnace["electric-furnace"], "mod0 : electric-furnace absent")
for _, v in ipairs({ 1, 10, 100, 1000 }) do
  local f = nettoie(table.deepcopy(base_four), "mod0-four-" .. v)
  f.crafting_categories = { "mod0-four" }
  f.crafting_speed = v
  f.energy_source, f.energy_usage = elec("100kW")
  f.module_specification = { module_slots = 2 }
  f.allowed_effects = ALL
  f.base_productivity = nil
  add(f)

  local d = nettoie(table.deepcopy(data.raw["mining-drill"]["electric-mining-drill"]), "mod0-foreuse-" .. v)
  d.mining_speed = v
  d.energy_source, d.energy_usage = elec("100kW")
  d.allowed_effects = ALL
  d.base_productivity = nil
  d.resource_categories = { "basic-solid" }
  d.input_fluid_box = nil
  d.output_fluid_box = nil
  add(d)
end

-- Balise cachée de complément (R3).
local b = nettoie(table.deepcopy(data.raw.beacon.beacon), "mod0-balise-cachee")
b.flags = HIDDEN
b.collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } }
b.collision_mask = {}
b.selection_box = nil
b.drawing_box = { { -0.1, -0.1 }, { 0.1, 0.1 } }
b.energy_source = { type = "void" }
b.energy_usage = "1W"
b.supply_area_distance = 0.3
b.distribution_effectivity = 1
b.module_specification = { module_slots = 20 }
b.allowed_effects = ALL
b.graphics_set = nil
b.base_picture = EMPTY
b.animation = EMPTY_ANIM
b.radius_visualisation_picture = nil
b.water_reflection = nil
b.corpse = nil
b.dying_explosion = nil
b.damaged_trigger_effect = nil
b.vehicle_impact_sound = nil
b.working_sound = nil
b.open_sound = nil
b.close_sound = nil
b.alert_when_damaged = false
b.map_color = nil
add(b)

-- Source et poteau d'une cellule (réseau électrique propre à chaque cellule, mesuré).
local src = nettoie(table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"]), "mod0-source")
src.flags = HIDDEN
src.collision_mask = {}
src.selection_box = nil
src.drawing_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
src.picture = EMPTY
src.pictures = nil
src.animation = nil
src.animations = nil
src.gui_mode = "none"
src.water_reflection = nil
src.energy_source = { type = "electric", buffer_capacity = "1GJ", usage_priority = "primary-output",
  input_flow_limit = "0W" }
src.energy_production = "0W"
src.energy_usage = "0W"
add(src)

local pole = nettoie(table.deepcopy(data.raw["electric-pole"]["substation"]), "mod0-poteau")
pole.flags = HIDDEN
pole.collision_mask = {}
pole.selection_box = nil
pole.drawing_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
pole.supply_area_distance = 6.5
pole.maximum_wire_distance = 1
pole.pictures = { filename = "__core__/graphics/empty.png", priority = "extra-high", width = 1, height = 1,
  direction_count = 1 }
pole.connection_points = { pole.connection_points[1] }
pole.water_reflection = nil
pole.draw_copper_wires = false
pole.draw_circuit_wires = false
add(pole)

-- Modules de test (aucune limitation). L'epsilon garantit le pourcent entier voulu (shared/content/modules.lua) ;
-- mod0-v115-brut n'en a pas, exprès.
local function module(nom, effet, cat)
  local m = table.deepcopy(data.raw.module["speed-module"])
  m.name = nom
  m.localised_name = { "", nom }
  m.localised_description = nil
  m.effect = effet
  m.category = cat or "speed"
  m.tier = 1
  m.limitation = nil
  m.limitation_message_key = nil
  m.order = "z[mod0]-" .. nom
  add(m)
end
local E = 1e-6
module("mod0-v50", { speed = { bonus = 0.5 + E } })
module("mod0-v80", { speed = { bonus = 0.8 + E } })
module("mod0-v110", { speed = { bonus = 1.1 + E } })
module("mod0-v115-brut", { speed = { bonus = 1.15 } })
module("mod0-p10", { productivity = { bonus = 0.1 + E } }, "productivity")
module("mod0-cplt-v100", { speed = { bonus = 1 + E } })
module("mod0-v1000", { speed = { bonus = 10 + E } })
module("mod0-v10000", { speed = { bonus = 100 + E } })
module("mod0-v100000", { speed = { bonus = 1000 + E } })
module("mod0-v32767", { speed = { bonus = 327.67 + E } })
module("mod0-v32768", { speed = { bonus = 327.68 + E } })
module("mod0-v20000", { speed = { bonus = 200 + E } })
module("mod0-c1000", { consumption = { bonus = 10 + E } }, "effectivity")
module("mod0-c10000", { consumption = { bonus = 100 + E } }, "effectivity")
module("mod0-c100000", { consumption = { bonus = 1000 + E } }, "effectivity")
module("mod0-p1000", { productivity = { bonus = 10 + E } }, "productivity")
module("mod0-p10000", { productivity = { bonus = 100 + E } }, "productivity")
module("mod0-p100000", { productivity = { bonus = 1000 + E } }, "productivity")

data:extend(out)
