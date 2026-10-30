-- Lot AMELIO-CRAFTS (nuit du 29 au 30/10) : chaînes des âges 2, 3, 4, 6, 8, 10 et 11 en jeu (objets, catégories, machines au
-- visuel PROVISOIRE, recettes, technologies) et débouchés des sous-produits du titane. Données et règles :
-- shared/content/crafts.lua (lit le scénario X0, shared/content/epochs.lua). Chargé à la fin de prototypes/titanium.lua
-- (il réutilise le coke, le four à coke, le four à arc et les fluides de la saumure).

local lib = require("prototypes.lib")
local C = require("shared.content.crafts")
local T = require("shared.content.titanium")

local out = {}

out[#out + 1] = { type = "item-subgroup", name = "fo-crafts", group = "intermediate-products", order = "z[fo]-a[crafts]" }
out[#out + 1] = { type = "item-subgroup", name = "fo-crafts-machines", group = "production", order = "z[fo]-a[crafts]" }

---------------------------------------------------------------------------------------------------
-- Objets : icônes PROVISOIRES (copies vanilla teintées, F36, F38).
---------------------------------------------------------------------------------------------------
local ICON = {
  ["fo-slag"] = { "item", "stone", { r = 0.46, g = 0.46, b = 0.52 } },
  ["fo-cement"] = { "item", "stone-brick", { r = 0.86, g = 0.86, b = 0.84 } },
  ["fo-sand"] = { "item", "stone", { r = 1.00, g = 0.88, b = 0.56 } },
  ["fo-glass"] = { "item", "plastic-bar", { r = 0.70, g = 0.92, b = 1.00 } },
  ["fo-manometer"] = { "item", "pipe-to-ground", { r = 0.85, g = 0.92, b = 1.00 } },
  ["fo-graphite"] = { "item", "solid-fuel", { r = 0.36, g = 0.37, b = 0.42 } },
  ["fo-magnetic-steel"] = { "item", "steel-plate", { r = 0.72, g = 0.78, b = 0.95 } },
  ["fo-enameled-wire"] = { "item", "copper-cable", { r = 0.85, g = 0.38, b = 0.26 } },
  ["fo-coil"] = { "item", "iron-gear-wheel", { r = 1.00, g = 0.66, b = 0.36 } },
  ["fo-titanium-composite"] = { "item", "plastic-bar", { r = 0.78, g = 0.80, b = 0.88 } },
  ["fo-metallurgical-silicon"] = { "item", "stone", { r = 0.55, g = 0.58, b = 0.66 } },
  ["fo-pure-silicon"] = { "item", "iron-plate", { r = 0.62, g = 0.66, b = 0.80 } },
  ["fo-silicon-wafer"] = { "item", "copper-plate", { r = 0.55, g = 0.62, b = 0.95 } },
  ["fo-iron-concentrate"] = { "item", "iron-ore", { r = 0.70, g = 0.78, b = 0.92 } },
  ["fo-copper-concentrate"] = { "item", "copper-ore", { r = 1.00, g = 0.80, b = 0.62 } },
  ["fo-tungsten-concentrate"] = { "item", "fo-tungsten-ore", { r = 0.80, g = 0.80, b = 0.86 } },
  ["fo-iron-plate-r8"] = { "item", "steel-plate", { r = 0.82, g = 0.86, b = 0.96 } },
  ["fo-copper-plate-r8"] = { "item", "steel-plate", { r = 1.00, g = 0.66, b = 0.46 } },
  ["fo-tungsten-plate-r8"] = { "item", "steel-plate", { r = 0.60, g = 0.62, b = 0.70 } },
  ["fo-cut-crystal"] = { "item", "fo-resonance-crystal", { r = 0.85, g = 0.95, b = 1.00 } },
  ["fo-crystal-powder"] = { "item", "stone", { r = 0.72, g = 0.86, b = 1.00 } },
  ["fo-resonance-lens"] = { "item", "fo-resonance-crystal", { r = 0.70, g = 0.95, b = 1.00 } },
  ["fo-crystal-oscillator"] = { "item", "advanced-circuit", { r = 0.70, g = 0.86, b = 1.00 } },
}

local function icon_of(ptype, name, tint)
  local src = data.raw[ptype][name]
  assert(src, "crafts : icône de " .. ptype .. "/" .. name)
  if src.icons then
    -- objet du mod décrit par couches (cristal de résonance) : chaque couche, teintée
    local l = {}
    for _, c in ipairs(src.icons) do
      local d = table.deepcopy(c)
      d.icon_size = d.icon_size or src.icon_size
      d.icon_mipmaps = d.icon_mipmaps or src.icon_mipmaps
      d.tint = tint
      l[#l + 1] = d
    end
    return l
  end
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

for i, name in ipairs(C.ITEMS) do
  local x = assert(T.x_item(name), "crafts : objet X0 absent " .. name)
  local ic = assert(ICON[name], "crafts : icône provisoire absente pour " .. name)
  local item = {
    type = "item",
    name = name,
    localised_name = { "item-name." .. name },
    localised_description = { "item-description." .. name },
    icons = icon_of(ic[1], ic[2], ic[3]),
    subgroup = "fo-crafts",
    order = string.format("z[fo]-a[crafts]-%02d", i),
    stack_size = x.stack,
  }
  local src = data.raw[ic[1]][ic[2]]
  if src.pictures then
    item.pictures = table.deepcopy(src.pictures)
    lib.tint_sprites(item.pictures, ic[3])
  end
  out[#out + 1] = item
end

-- Fluides (copie de l'eau, icône de la vapeur teintée, comme X1).
local FLUID_TINT = { ["fo-ethylene"] = { r = 0.80, g = 0.95, b = 0.70 }, ["fo-carbon-dioxide"] = { r = 0.62, g = 0.64, b = 0.66 } }
for i, name in ipairs(C.FLUIDS) do
  local f = lib.copy("fluid", "water")
  local tint = assert(FLUID_TINT[name], "crafts : teinte absente pour " .. name)
  f.name = name
  f.localised_name = { "fluid-name." .. name }
  f.base_color = { r = tint.r * 0.6, g = tint.g * 0.6, b = tint.b * 0.6 }
  f.flow_color = tint
  f.order = "a[fluid]-z[fo]-a[crafts]-" .. i
  local steam = data.raw.fluid["steam"]
  lib.set_icons(f, { { icon = steam.icon, icon_size = steam.icon_size, icon_mipmaps = steam.icon_mipmaps, tint = tint } })
  out[#out + 1] = f
end

-- Sols (étape 6) : copie teintée d'un sol vanilla, modificateurs de X0 ; objet qui le pose.
for i, spec in ipairs(C.TILES) do
  local x = assert(C.x_tile(spec.name), "crafts : sol X0 absent " .. spec.name)
  local t = lib.copy("tile", spec.copy)
  t.name = spec.name
  t.localised_name = { "item-name." .. spec.name }
  t.minable = { mining_time = 0.1, result = spec.name }
  t.layer = spec.layer
  t.tint = spec.tint
  t.map_color = spec.map_color
  t.walking_speed_modifier = x.walking_speed_modifier
  t.vehicle_friction_modifier = x.vehicle_friction_modifier
  t.next_direction = nil
  t.placeable_by = nil
  t.transition_merges_with_tile = nil
  out[#out + 1] = t
  local src = data.raw.item[spec.copy]
  local xi = assert(T.x_item(spec.name), "crafts : objet X0 absent " .. spec.name)
  local pat = table.deepcopy(src.place_as_tile)
  pat.result = spec.name
  out[#out + 1] = {
    type = "item",
    name = spec.name,
    localised_name = { "item-name." .. spec.name },
    localised_description = { "item-description." .. spec.name },
    icons = icon_of("item", spec.copy, spec.tint),
    subgroup = "fo-crafts",
    order = string.format("z[fo]-b[tiles]-%02d", i),
    stack_size = xi.stack,
    place_as_tile = pat,
  }
end

for _, c in ipairs(C.new_categories()) do
  out[#out + 1] = { type = "recipe-category", name = c }
end

---------------------------------------------------------------------------------------------------
-- Machines : stats de X0, visuel PROVISOIRE (copie teintée et mise à l'échelle), sans niveaux.
---------------------------------------------------------------------------------------------------
local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }

local function boxes(side)
  local h = side / 2
  return { { -h + 0.3, -h + 0.3 }, { h - 0.3, h - 0.3 } }, { { -h, -h }, { h, h } }
end

local function fluid_box(kind, side, dx, model)
  local h = side / 2
  local y = kind == "input" and -(h + 0.5) or (h + 0.5)
  return {
    production_type = kind,
    pipe_picture = table.deepcopy(model.pipe_picture),
    pipe_covers = table.deepcopy(model.pipe_covers),
    base_area = 10,
    base_level = kind == "input" and -1 or 1,
    pipe_connections = { { type = kind, position = { dx, y } } },
    secondary_draw_orders = { north = -1 },
  }
end

local function machine(spec)
  local x = T.x_building(spec.name)
  local e = lib.copy(spec.copy[1], spec.copy[2])
  e.type = "assembling-machine"
  -- une copie de four devient une machine à recette : ses inventaires de four n'ont plus de sens
  e.source_inventory_size, e.result_inventory_size = nil, nil
  local side = x.size[1]
  e.name = spec.name
  e.localised_name = { "entity-name." .. spec.name }
  e.localised_description = { "entity-description." .. spec.name }
  e.minable = { mining_time = 0.3, result = spec.name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  e.crafting_categories = table.deepcopy(x.categories)
  e.crafting_speed = x.speed
  e.energy_usage = x.kw .. "kW"
  e.collision_box, e.selection_box = boxes(side)
  e.drawing_box = nil
  e.water_reflection = nil
  local k = side / spec.side
  for _, key in ipairs(VISUAL_KEYS) do
    if e[key] then
      if k ~= 1 then lib.scale_sprites(e[key], k) end
      lib.tint_sprites(e[key], spec.tint)
    end
  end
  if x.energy.type == "burner" then
    local es = table.deepcopy(data.raw.furnace["stone-furnace"].energy_source)
    es.fuel_category = x.energy.fuel_category
    e.energy_source = es
  else
    e.energy_source = { type = "electric", usage_priority = "secondary-input", emissions_per_minute = 2 }
  end
  local model = data.raw["assembling-machine"]["assembling-machine-2"].fluid_boxes[1]
  local fbs = {}
  local nin, nout = x.fluid_in or 0, x.fluid_out or 0
  local cols = { [1] = { 0 }, [2] = { -1, 1 } }
  if side == 4 then cols = { [1] = { -0.5 }, [2] = { -1.5, 0.5 } } end
  if side == 2 then cols = { [1] = { -0.5 }, [2] = { -0.5, 0.5 } } end
  for i = 1, nin do fbs[#fbs + 1] = fluid_box("input", side, cols[nin][i], model) end
  for i = 1, nout do fbs[#fbs + 1] = fluid_box("output", side, cols[nout][i], model) end
  if #fbs > 0 then
    fbs.off_when_no_fluid_recipe = true
    e.fluid_boxes = fbs
  else
    e.fluid_boxes = nil
  end
  local icons = icon_of("item", spec.copy[2], spec.tint)
  lib.set_icons(e, icons)
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item",
    name = spec.name,
    localised_name = { "entity-name." .. spec.name },
    localised_description = { "entity-description." .. spec.name },
    icons = icon_of("item", spec.copy[2], spec.tint),
    subgroup = "fo-crafts-machines",
    order = "z[fo]-a[crafts]-" .. spec.name,
    place_result = spec.name,
    stack_size = 10,
  }
end

for _, spec in ipairs(C.BUILDINGS) do machine(spec) end

-- Balises (étape 8) : copie teintée de la balise vanilla, stats de X0.
for _, spec in ipairs(C.BEACONS) do
  local x = T.x_building(spec.name)
  local b = lib.copy("beacon", "beacon")
  b.name = spec.name
  b.localised_name = { "entity-name." .. spec.name }
  b.localised_description = { "entity-description." .. spec.name }
  b.minable = { mining_time = 0.2, result = spec.name }
  b.next_upgrade = nil
  b.fast_replaceable_group = nil
  b.energy_usage = x.kw .. "kW"
  b.distribution_effectivity = x.distribution
  b.supply_area_distance = x.supply_distance
  b.module_specification = table.deepcopy(b.module_specification or {})
  b.module_specification.module_slots = x.slots
  for _, key in ipairs({ "graphics_set", "animation", "base_picture" }) do
    if b[key] then lib.tint_sprites(b[key], spec.tint) end
  end
  lib.set_icons(b, icon_of("item", "beacon", spec.tint))
  out[#out + 1] = b
  out[#out + 1] = {
    type = "item",
    name = spec.name,
    localised_name = { "entity-name." .. spec.name },
    localised_description = { "entity-description." .. spec.name },
    icons = icon_of("item", "beacon", spec.tint),
    subgroup = "fo-crafts-machines",
    order = "z[fo]-b[beacons]-" .. spec.name,
    place_result = spec.name,
    stack_size = 10,
  }
end

---------------------------------------------------------------------------------------------------
-- Recettes
---------------------------------------------------------------------------------------------------
local function is_fluid(name)
  local x = T.x_item(name)
  if x then return x.type == "fluid" end
  return data.raw.fluid[name] ~= nil and data.raw.item[name] == nil
end

local function ingredient(n, a, catalyst)
  local o
  if is_fluid(n) then o = { type = "fluid", name = n, amount = a } else o = { type = "item", name = n, amount = a } end
  if catalyst then o.catalyst_amount = catalyst end
  return o
end

local function result(r)
  local p = { type = is_fluid(r[1]) and "fluid" or "item", name = r[1], amount = r[2] }
  if r.p then p.probability = r.p end
  if r.catalyst then p.catalyst_amount = r.catalyst end
  return p
end

--- Couches d'icône d'un objet ou fluide (déjà défini dans data.raw ou dans `out` de ce fichier), copiées.
local function layers_of(name)
  local p = data.raw.item[name] or data.raw.fluid[name] or data.raw.tool[name] or data.raw.module[name]
  if not p then
    for _, o in ipairs(out) do if o.name == name and (o.type == "item" or o.type == "fluid") then p = o end end
  end
  if not p then return nil end
  if p.icons then
    local l = {}
    for _, c in ipairs(p.icons) do
      local d = table.deepcopy(c)
      d.icon_size = d.icon_size or p.icon_size
      d.icon_mipmaps = d.icon_mipmaps or p.icon_mipmaps
      l[#l + 1] = d
    end
    return l
  end
  return { { icon = p.icon, icon_size = p.icon_size, icon_mipmaps = p.icon_mipmaps } }
end

for i, x in ipairs(C.all_recipes()) do
  local ings, res = {}, {}
  for _, ing in ipairs(x.ingredients) do ings[#ings + 1] = ingredient(ing[1], ing[2], ing.catalyst) end
  for _, r in ipairs(x.results) do res[#res + 1] = result(r) end
  local main = x.main or (#res == 1 and res[1].name) or nil
  local r = {
    type = "recipe",
    name = x.name,
    category = x.category,
    enabled = false,
    energy_required = x.time,
    ingredients = ings,
    results = res,
    main_product = main,
    subgroup = "fo-crafts",
    order = string.format("z[fo]-a[crafts]-r%02d", i),
    allow_decomposition = true,
  }
  -- Nom propre : les recettes nommées par X0, les variantes (produit vanilla) et les recettes hors X0.
  if x.fr or not x.x0 or #x.subst > 0 then
    r.localised_name = { "recipe-name." .. x.name }
    r.localised_description = { "recipe-description." .. x.name }
  end
  -- Une variante de produit vanilla se distingue de la recette vanilla : icône du produit + petite icône de
  -- l'ingrédient caractéristique (le premier ingrédient du mod) dans le coin.
  if main and not main:find("^fo%-") then
    local mark
    for _, ing in ipairs(x.ingredients) do
      if not mark and ing[1]:find("^fo%-") then mark = ing[1] end
    end
    local prod_layers = layers_of(main)
    local mark_layers = mark and layers_of(mark)
    if prod_layers and mark_layers then
      local icons = prod_layers
      for _, l in ipairs(mark_layers) do
        l.scale = 0.5 * (32 / (l.icon_size or 32))
        l.shift = { 8, 8 }
        icons[#icons + 1] = l
      end
      r.icons = icons
    end
  end
  -- Torchère : aucun produit ; icône du fluide brûlé + petite torchère dans le coin.
  if #res == 0 then
    local icons = layers_of(x.ingredients[1][1])
    for _, l in ipairs(layers_of("fo-flare-stack") or {}) do
      l.scale = 0.5 * (32 / (l.icon_size or 32))
      l.shift = { 8, 8 }
      icons[#icons + 1] = l
    end
    r.icons = icons
  end
  out[#out + 1] = r
end

-- Poteaux (étape 9) : copie teintée du grand poteau vanilla, portée de X0.
for _, spec in ipairs(C.POLES) do
  local x = T.x_building(spec.name)
  local p = lib.copy("electric-pole", spec.copy)
  p.name = spec.name
  p.localised_name = { "entity-name." .. spec.name }
  p.localised_description = { "entity-description." .. spec.name }
  p.minable = { mining_time = 0.1, result = spec.name }
  p.next_upgrade = nil
  p.fast_replaceable_group = nil
  p.maximum_wire_distance = x.wire_distance
  p.supply_area_distance = x.supply_distance
  if p.pictures then lib.tint_sprites(p.pictures, spec.tint) end
  lib.set_icons(p, icon_of("item", spec.copy, spec.tint))
  out[#out + 1] = p
  out[#out + 1] = {
    type = "item",
    name = spec.name,
    localised_name = { "entity-name." .. spec.name },
    localised_description = { "entity-description." .. spec.name },
    icons = icon_of("item", spec.copy, spec.tint),
    subgroup = "fo-crafts-machines",
    order = "z[fo]-c[poles]-" .. spec.name,
    place_result = spec.name,
    stack_size = 50,
  }
end

local building_specs = {}
for _, spec in ipairs(C.BUILDINGS) do building_specs[#building_specs + 1] = spec end
for _, spec in ipairs(C.BEACONS) do building_specs[#building_specs + 1] = spec end
for _, spec in ipairs(C.POLES) do building_specs[#building_specs + 1] = spec end
for _, spec in ipairs(building_specs) do
  local b = C.building_recipe(spec.name)
  local ings = {}
  for _, ing in ipairs(b.ingredients) do ings[#ings + 1] = ingredient(ing[1], ing[2]) end
  out[#out + 1] = {
    type = "recipe",
    name = spec.name,
    category = b.category,
    enabled = false,
    energy_required = b.time,
    ingredients = ings,
    result = spec.name,
  }
end

---------------------------------------------------------------------------------------------------
-- Technologies (packs vanilla de la fenêtre X0 de l'âge)
---------------------------------------------------------------------------------------------------
local TECH_ICON = {
  ["fo-coking"] = { "advanced-material-processing", { r = 0.78, g = 0.58, b = 0.46 } },
  ["fo-blast-furnace"] = { "advanced-material-processing", { r = 0.80, g = 0.62, b = 0.52 } },
  ["fo-crushing"] = { "concrete", { r = 0.78, g = 0.70, b = 0.58 } },
  ["fo-cement-concrete"] = { "concrete", { r = 0.86, g = 0.86, b = 0.84 } },
  ["fo-glassworks"] = { "advanced-material-processing", { r = 0.70, g = 0.92, b = 1.00 } },
  ["fo-flaring"] = { "fluid-handling", { r = 1.00, g = 0.55, b = 0.40 } },
  ["fo-steam-cracking"] = { "plastics", { r = 0.80, g = 0.95, b = 0.70 } },
  ["fo-arc-smelting"] = { "advanced-material-processing-2", { r = 0.80, g = 0.93, b = 1.00 } },
  ["fo-electrical-steel"] = { "electric-engine", { r = 0.98, g = 0.80, b = 0.55 } },
  ["fo-titanium-alloys"] = { "low-density-structure", { r = 0.85, g = 0.88, b = 0.96 } },
  ["fo-brine-byproducts"] = { "advanced-oil-processing", { r = 0.86, g = 0.90, b = 1.00 } },
  ["fo-methane-reforming"] = { "advanced-oil-processing", { r = 0.62, g = 0.82, b = 0.70 } },
  ["fo-carbonation"] = { "concrete", { r = 0.70, g = 0.72, b = 0.74 } },
  ["fo-silicon"] = { "advanced-electronics-2", { r = 0.80, g = 0.86, b = 1.00 } },
  ["fo-siemens-process"] = { "advanced-electronics-2", { r = 0.70, g = 0.95, b = 0.75 } },
  ["fo-concentration"] = { "advanced-material-processing-2", { r = 0.85, g = 0.80, b = 0.70 } },
  ["fo-billets"] = { "advanced-material-processing-2", { r = 0.80, g = 0.86, b = 1.00 } },
  ["fo-asphalt"] = { "concrete", { r = 0.45, g = 0.45, b = 0.48 } },
  ["fo-lapidary"] = { "effect-transmission", { r = 0.62, g = 0.86, b = 1.00 } },
  ["fo-jaw-crusher"] = { "concrete", { r = 0.70, g = 0.72, b = 0.80 } },
  ["fo-resonance-amplifier"] = { "effect-transmission", { r = 0.85, g = 0.95, b = 1.00 } },
}
for _, t in ipairs(C.TECHS) do
  local effects = {}
  for _, r in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(r) end
  local ti = assert(TECH_ICON[t.name], "crafts : icône de technologie " .. t.name)
  local src = assert(data.raw.technology[ti[1]], "crafts : technologie vanilla " .. ti[1])
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = ti[2] } },
    effects = effects,
    prerequisites = t.prerequisites,
    count = C.tech_count(t),
    packs = C.packs(t.epoch),
    time = t.time,
    order = "z[fo]-a[crafts]-" .. t.name,
  })
end

data:extend(out)

-- Modules de productivité : data-final-fixes.lua recopie la limitation du module vanilla de productivité 3 vers les
-- modules du mod ; les recettes « prod » de X0 de ce lot y sont ajoutées ici (aucune n'est réversible).
for _, mname in ipairs({ "productivity-module", "productivity-module-2", "productivity-module-3" }) do
  local m = data.raw.module[mname]
  if m and type(m.limitation) == "table" then
    local present = {}
    for _, r in ipairs(m.limitation) do present[r] = true end
    for _, r in ipairs(C.productivity_recipes()) do
      if not present[r] then m.limitation[#m.limitation + 1] = r; present[r] = true end
    end
  end
end
