-- Lot CALCUL-V2 (30/10) : une machine par étape et le centre de calcul MODULAIRE. Données : shared/content/compute_chain.lua ;
-- règle du centre : shared/content/compute_rack.lua ; script : script/compute/compute.lua.
-- À charger JUSTE APRÈS prototypes/compute.lua (v1) : ce fichier y prend le centre, les baies v1 et les technologies v1.
-- Visuels des machines PROVISOIRES (Cv.PROVISIONAL) : copies vanilla teintées (une teinte ne fait que multiplier, F36, F38),
-- à dessiner après le workflow design-calcul-* ; icônes des objets, fluides, baies et technologies : dédiées (lot ICONES-CALCUL,
-- prototypes/calcul_icones.lua), la copie teintée ne sert plus qu'aux machines.

local lib = require("prototypes.lib")
local Cv = require("shared.content.compute_chain")
local Cr = require("shared.content.compute_rack")
local Cp = require("shared.content.compute")
local Vis = require("prototypes.calcul_icones")

local out = {}

out[#out + 1] = { type = "item-subgroup", name = "fo-compute-racks", group = "intermediate-products", order = "z[fo]-j[compute]-b" }
out[#out + 1] = { type = "module-category", name = Cv.MODULE_CATEGORY }
for _, c in ipairs(Cv.NEW_CATEGORIES) do
  if not data.raw["recipe-category"][c] then out[#out + 1] = { type = "recipe-category", name = c } end
end

local function icon_of(ptype, name, tint)
  local src = assert(data.raw[ptype][name], "calcul v2 : icône source absente " .. ptype .. "/" .. name)
  if src.icons then
    local l = table.deepcopy(src.icons)
    for _, layer in ipairs(l) do layer.tint = tint; layer.icon_size = layer.icon_size or src.icon_size end
    return l
  end
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

---------------------------------------------------------------------------------------------------
-- Objets, fluides (icônes PROVISOIRES)
---------------------------------------------------------------------------------------------------
local ICON = {
  ["fo-silicon-ingot"] = { "item", "steel-plate", { r = 0.62, g = 0.66, b = 0.85 } },
  ["fo-exposed-wafer"] = { "item", "processing-unit", { r = 0.95, g = 0.80, b = 0.55 } },
  ["fo-nand-die"] = { "item", "advanced-circuit", { r = 1.00, g = 0.75, b = 0.40 } },
  ["fo-flash-drive"] = { "item", "battery", { r = 0.80, g = 0.80, b = 1.00 } },
  ["fo-optical-fiber"] = { "item", "copper-cable", { r = 0.60, g = 1.00, b = 1.00 } },
  ["fo-network-switch"] = { "item", "constant-combinator", { r = 0.60, g = 0.90, b = 1.00 } },
}
for i, it in ipairs(Cv.ITEMS) do
  local ic = ICON[it.name]
  out[#out + 1] = {
    type = "item", name = it.name,
    localised_name = { "item-name." .. it.name }, localised_description = { "item-description." .. it.name },
    icons = Vis.icones_objet(it.name) or icon_of(ic[1], ic[2], ic[3]), subgroup = "fo-compute", order = string.format("z[fo]-j[compute]-v2-%02d", i),
    stack_size = it.stack,
  }
end

for i, fl in ipairs(Cv.FLUIDS) do
  local f = lib.copy("fluid", fl.base)
  f.name = fl.name
  f.localised_name = { "fluid-name." .. fl.name }
  f.base_color = { r = fl.tint.r * 0.6, g = fl.tint.g * 0.6, b = fl.tint.b * 0.6 }
  f.flow_color = fl.tint
  f.fuel_value = nil
  f.auto_barrel = false
  f.order = "a[fluid]-z[fo]-j[compute]-v2-" .. i
  lib.set_icons(f, Vis.icones_objet(fl.name) or { { icon = f.icon, icon_size = f.icon_size, icon_mipmaps = f.icon_mipmaps, tint = fl.tint } })
  out[#out + 1] = f
end

---------------------------------------------------------------------------------------------------
-- Baies : des MODULES de catégorie fo-baie. Les deux baies v1 (objets) deviennent des modules SOUS LE MÊME NOM.
---------------------------------------------------------------------------------------------------
local RACK_TINT = {
  ["fo-server-blade"] = { r = 0.60, g = 0.65, b = 0.85 }, ["fo-memory-rack"] = { r = 0.45, g = 0.95, b = 0.55 },
  ["fo-storage-rack"] = { r = 0.85, g = 0.80, b = 0.55 }, ["fo-network-rack"] = { r = 0.60, g = 0.95, b = 1.00 },
  ["fo-cooling-rack"] = { r = 0.70, g = 0.85, b = 1.00 }, ["fo-gpu-blade"] = { r = 0.95, g = 0.55, b = 0.50 },
  ["fo-quantum-rack"] = { r = 1.00, g = 0.45, b = 1.00 },
}
local limitation = Cv.cooling_recipes()
for i, rk in ipairs(Cv.RACKS) do
  local old = data.raw.item[rk.name]
  if old then data.raw.item[rk.name] = nil end
  out[#out + 1] = {
    type = "module", name = rk.name,
    localised_name = { "item-name." .. rk.name }, localised_description = { "item-description." .. rk.name },
    icons = Vis.icones_objet(rk.name) or icon_of("item", "beacon", RACK_TINT[rk.name]),
    subgroup = "fo-compute-racks", order = string.format("z[fo]-j[compute]-rack-%02d", i),
    category = Cv.MODULE_CATEGORY, tier = 1, stack_size = rk.stack,
    effect = { pollution = { bonus = Cv.RACK_POLLUTION } },
    limitation = table.deepcopy(limitation), limitation_message_key = "fo-baie",
  }
  assert(Cr.BY_NAME[rk.name], "calcul v2 : baie sans règle " .. rk.name)
end

---------------------------------------------------------------------------------------------------
-- Machines (une par étape) : copies teintées, mises à l'échelle (PROVISOIRE)
---------------------------------------------------------------------------------------------------
local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }
local TEMPLATE_BOX = (function()
  for _, b in ipairs(data.raw["assembling-machine"]["assembling-machine-3"].fluid_boxes or {}) do
    if type(b) == "table" and b.production_type == "input" then return b end
  end
  error("calcul v2 : boîte d'entrée absente de l'assembleur 3")
end)()

local function box(kind, pos)
  local b = table.deepcopy(TEMPLATE_BOX)
  b.production_type = kind
  b.base_level = kind == "input" and -1 or 1
  b.pipe_connections = { { type = kind, position = pos } }
  return b
end

local function fluid_boxes(pipes)
  if not pipes then return nil end
  local boxes = { off_when_no_fluid_recipe = true }
  for _, p in ipairs(pipes.inn or {}) do boxes[#boxes + 1] = box("input", p) end
  for _, p in ipairs(pipes.out or {}) do boxes[#boxes + 1] = box("output", p) end
  return boxes
end

local function machine(m)
  local e = lib.copy("assembling-machine", m.copy)
  local h = m.size / 2
  e.name = m.name
  e.localised_name = { "entity-name." .. m.name }
  e.localised_description = { "entity-description." .. m.name }
  e.minable = { mining_time = 0.5, result = m.name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  e.crafting_categories = table.deepcopy(m.categories)
  e.crafting_speed = 1
  e.energy_usage = m.kw .. "kW"
  e.energy_source = { type = "electric", usage_priority = "secondary-input", emissions_per_minute = 4 }
  e.collision_box = { { -h + 0.3, -h + 0.3 }, { h - 0.3, h - 0.3 } }
  e.selection_box = { { -h, -h }, { h, h } }
  e.drawing_box = nil
  e.water_reflection = nil
  e.fixed_recipe = nil
  e.fluid_boxes = fluid_boxes(m.pipes)
  if m.slots then
    -- Grand centre de calcul : des emplacements de BAIES seulement (allowed_effects = pollution : tout module d'effet
    -- est refusé, balises comprises).
    e.module_specification = { module_slots = m.slots, module_info_icon_shift = { 0, 0.8 } }
    e.allowed_effects = { "pollution" }
  else
    -- Aucune machine du calcul ne prend de module d'effet (DC : « PAS de modules d'effet (vitesse/productivité) pour le
    -- calcul ») : aucun emplacement, aucune balise (même règle que le centre v1).
    e.module_specification = { module_slots = 0 }
    e.allowed_effects = {}
  end
  local k = m.size / m.side
  for _, key in ipairs(VISUAL_KEYS) do
    if e[key] then
      if k ~= 1 then lib.scale_sprites(e[key], k) end
      lib.tint_sprites(e[key], m.tint)
    end
  end
  lib.set_icons(e, icon_of("item", m.copy, m.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item", name = m.name,
    localised_name = { "entity-name." .. m.name }, localised_description = { "entity-description." .. m.name },
    icons = icon_of("item", m.copy, m.tint), subgroup = "fo-compute-machines", order = "z[fo]-j[compute]-v2-" .. m.name,
    place_result = m.name, stack_size = 10,
  }
end
for _, m in ipairs(Cv.MACHINES) do machine(m) end

-- Le centre v1 devient MODULAIRE (même nom, même 4 × 4, mêmes deux entrées).
do
  local d = Cv.DATA_CENTER
  local e = assert(data.raw["assembling-machine"][d.name], "calcul v2 : centre v1 absent (prototypes/compute.lua d'abord)")
  e.crafting_categories = table.deepcopy(d.categories)
  e.energy_usage = d.kw .. "kW"
  e.module_specification = { module_slots = d.slots, module_info_icon_shift = { 0, 0.6 } }
  e.allowed_effects = { "pollution" }
  for _, p in ipairs(d.out) do e.fluid_boxes[#e.fluid_boxes + 1] = box("output", p) end
end

-- Compagnons d'énergie : une interface électrique cachée sous chaque centre ; sa puissance (power_usage) est écrite par
-- le script = somme des kW des baies. Même emprise que le centre (alimentée par les mêmes poteaux), aucune collision.
for _, cname in ipairs({ "fo-data-center", "fo-data-center-2" }) do
  local c = data.raw["assembling-machine"][cname]
  for _, p in ipairs(out) do if p.type == "assembling-machine" and p.name == cname then c = p end end
  local h = (c.selection_box[2][1] - c.selection_box[1][1]) / 2
  out[#out + 1] = {
    type = "electric-energy-interface", name = cname .. "-power",
    localised_name = { "entity-name.fo-data-center-power" },
    localised_description = { "entity-description.fo-data-center-power" },
    icons = table.deepcopy(c.icons), icon_size = c.icon_size,
    flags = { "placeable-neutral", "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable", "hidden",
              "not-selectable-in-game", "no-copy-paste", "not-upgradable", "not-in-kill-statistics", "hide-alt-info",
              "not-repairable", "not-flammable" },
    collision_box = { { -h + 0.3, -h + 0.3 }, { h - 0.3, h - 0.3 } },
    collision_mask = {},
    selection_box = nil,
    max_health = 1000,
    energy_source = { type = "electric", usage_priority = "secondary-input", buffer_capacity = "1MJ",
                      input_flow_limit = "1GW", output_flow_limit = "0W" },
    energy_usage = "0kW",
    energy_production = "0kW",
    gui_mode = "none",
    allow_copy_paste = false,
    picture = { filename = "__core__/graphics/empty.png", priority = "extra-high", width = 1, height = 1 },
  }
end

---------------------------------------------------------------------------------------------------
-- Recettes
---------------------------------------------------------------------------------------------------
local function ingredient(n, a) return { type = Cv.is_fluid(n) and "fluid" or "item", name = n, amount = a } end
local own = {}
for _, p in ipairs(out) do if p.type == "item" or p.type == "fluid" or p.type == "module" then own[p.name] = p end end
local function icons_of(n)
  local p = own[n] or data.raw.item[n] or data.raw.fluid[n] or data.raw.module[n] or data.raw.tool[n]
  assert(p, "calcul v2 : icône absente " .. n)
  if p.icons then return table.deepcopy(p.icons) end
  return { { icon = p.icon, icon_size = p.icon_size, icon_mipmaps = p.icon_mipmaps } }
end
local function with_mark(base, mark)
  local icons = icons_of(base)
  for _, l in ipairs(icons_of(mark)) do
    l.scale = 0.5 * 32 / (l.icon_size or 64)
    l.shift = { 8, 8 }
    icons[#icons + 1] = l
  end
  return icons
end

local function recipe(x, i, building)
  local ings, res = {}, {}
  for _, g in ipairs(x.ingredients) do ings[#ings + 1] = ingredient(g[1], g[2]) end
  for _, p in ipairs(x.results) do res[#res + 1] = ingredient(p[1], p[2]) end
  local r = {
    type = "recipe", name = x.name, category = x.category, enabled = false, energy_required = x.time,
    ingredients = ings, results = res,
    subgroup = building and "fo-compute-machines" or (x.name:find("^fo%-rack%-") and "fo-compute-racks" or "fo-compute"),
    order = string.format("z[fo]-j[compute]-v2-r%02d", i), allow_decomposition = not x.variant,
  }
  if #res >= 1 then r.main_product = res[1].name end
  if x.fr then r.localised_name = { "recipe-name." .. x.name } end
  if x.variant then
    r.icons = with_mark(x.variant, x.ingredients[1][1])
    r.main_product = ""
  elseif x.cooling then
    r.localised_description = { "recipe-description." .. x.name }
    r.icons = with_mark(x.ingredients[1][1], "fo-data-center")
    r.hide_from_player_crafting = true
    if #res == 0 then r.main_product = nil end
  end
  if x.fr and #res >= 1 and not x.variant and not x.cooling then
    -- Recette v2 d'un objet v1 (nom propre) : icône du produit, marque de la machine v2.
    r.icons = icons_of(res[1].name)
  end
  return r
end
for i, x in ipairs(Cv.RECIPES) do out[#out + 1] = recipe(x, i, false) end
for i, x in ipairs(Cv.BUILDING_RECIPES) do out[#out + 1] = recipe(x, 60 + i, true) end

---------------------------------------------------------------------------------------------------
-- Technologies : deux neuves ; les cinq v1 ouvrent en plus leurs recettes v2 (déblocages v1 gardés).
---------------------------------------------------------------------------------------------------
local TECH_ICON = {
  ["fo-wafer-fab"] = { "advanced-electronics", { r = 0.90, g = 0.80, b = 1.00 } },
  ["fo-data-centers-2"] = { "research-speed-1", { r = 0.45, g = 0.55, b = 1.00 } },
}
for _, t in ipairs(Cv.TECHS) do
  local effects = {}
  for _, u in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(u) end
  if t.new then
    local ti = TECH_ICON[t.name]
    local src = assert(data.raw.technology[ti[1]], "calcul v2 : technologie source absente " .. ti[1])
    local icons = Vis.icones_tech(t.name) -- dessinée (lot ICONES-CALCUL) ; sinon copie teintée
    if icons then
      -- rien à faire
    elseif src.icons then
      icons = table.deepcopy(src.icons)
      for _, layer in ipairs(icons) do layer.tint = ti[2]; layer.icon_size = layer.icon_size or src.icon_size end
    else
      icons = { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = ti[2] } }
    end
    out[#out + 1] = lib.technology({
      name = t.name, localised_name = { "technology-name." .. t.name },
      localised_description = { "technology-description." .. t.name },
      icons = icons, effects = effects, prerequisites = t.prerequisites, count = Cp.tech_count(t), packs = Cp.packs(t.epoch),
      time = t.time, order = "z[fo]-j[compute]-" .. t.name,
    })
  else
    local tech = assert(data.raw.technology[t.name], "calcul v2 : technologie v1 absente " .. t.name)
    for _, e in ipairs(effects) do tech.effects[#tech.effects + 1] = e end
    for _, p in ipairs(t.add_prerequisites or {}) do tech.prerequisites[#tech.prerequisites + 1] = p end
  end
end

data:extend(out)

-- Recettes v1 cachées pour un nouveau choix (Q-CV2-1) : toujours valides dans les machines qui les font.
for _, n in ipairs(Cv.HIDE_V1) do
  local r = assert(data.raw.recipe[n], "calcul v2 : recette v1 absente " .. n)
  r.hidden = true
end

-- Modules de productivité : AUCUNE recette v2 n'y est ajoutée (les machines du calcul n'ont pas d'emplacement ; DC : pas
-- de modules d'effet pour le calcul). Les recettes « prod » de la v1 (salle blanche) gardent leur droit (prototypes/compute.lua).
