-- Lot X1-TITANE (25/10) : la chaîne du titane de l'âge 11 en jeu (objets, fluides, catégories, machines au visuel
-- PROVISOIRE, recettes, technologies). Données et règles : shared/content/titanium.lua (lit le scénario X0,
-- shared/content/epochs.lua). Le minerai d'ilménite, la saumure et le biome des cratères : prototypes/world.lua
-- (shared/content/world.lua).

local lib = require("prototypes.lib")
local T = require("shared.content.titanium")
local W = require("shared.content.world")

local out = {}
local TI = W.resources.ilmenite.tint

out[#out + 1] = { type = "item-subgroup", name = "fo-titanium", group = "intermediate-products", order = "z[fo]-b[titanium]" }
out[#out + 1] = { type = "item-subgroup", name = "fo-titanium-machines", group = "production", order = "z[fo]-b[titanium]" }

---------------------------------------------------------------------------------------------------
-- Objets : icônes PROVISOIRES (copies vanilla teintées, F36, F38 : une teinte multiplie). Le minerai d'ilménite a sa
-- feuille propre (prototypes/world.lua) et n'est pas refait ici.
---------------------------------------------------------------------------------------------------
local ICON = {
  ["fo-ilmenite-concentrate"] = { "item", "iron-ore", { r = 0.42, g = 0.36, b = 0.34 } },
  ["fo-titanium-slag"] = { "item", "stone", { r = 0.62, g = 0.50, b = 0.42 } },
  ["fo-titanium-sponge"] = { "item", "solid-fuel", { r = 0.85, g = 0.86, b = 0.90 } },
  ["fo-titanium-plate"] = { "item", "steel-plate", { r = 0.96, g = 0.97, b = 1.00 } },
  ["fo-caustic-soda"] = { "item", "plastic-bar", { r = 1.00, g = 1.00, b = 0.94 } },
  ["fo-magnesium-chloride"] = { "item", "stone", { r = 1.00, g = 0.96, b = 0.96 } },
  ["fo-magnesium"] = { "item", "steel-plate", { r = 0.82, g = 0.96, b = 0.84 } },
  ["fo-coke"] = { "item", "coal", { r = 0.62, g = 0.62, b = 0.68 } },
}
local FLUID_TINT = {
  ["fo-chlorine"] = { r = 0.78, g = 0.92, b = 0.32 },
  ["fo-titanium-tetrachloride"] = { r = 0.95, g = 0.90, b = 0.62 },
  ["fo-hydrogen"] = { r = 0.86, g = 0.90, b = 1.00 },
}

local function icon_of(ptype, name, tint)
  local src = data.raw[ptype][name]
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

for i, name in ipairs(T.ITEMS) do
  if name ~= W.resources.ilmenite.item then
    local x = T.x_item(name)
    local ic = assert(ICON[name], "titane : icône provisoire absente pour " .. name)
    local item = {
      type = "item",
      name = name,
      localised_name = { "item-name." .. name },
      localised_description = { "item-description." .. name },
      icons = icon_of(ic[1], ic[2], ic[3]),
      subgroup = "fo-titanium",
      order = string.format("z[fo]-b[titanium]-%02d", i),
      stack_size = x.stack,
    }
    -- images au sol : celles de l'objet copié, teintées (sinon l'icône seule)
    local src = data.raw[ic[1]][ic[2]]
    if src.pictures then
      item.pictures = table.deepcopy(src.pictures)
      lib.tint_sprites(item.pictures, ic[3])
    end
    if x.fuel then
      item.fuel_value = x.fuel .. "MJ"
      item.fuel_category = x.fuel_category
    end
    out[#out + 1] = item
  end
end

-- Fluides (la saumure est créée avec son gisement, prototypes/world.lua) : copie de l'eau, icône de la vapeur teintée.
for i, name in ipairs(T.FLUIDS) do
  if name ~= W.resources.brine.fluid then
    local f = lib.copy("fluid", "water")
    local tint = assert(FLUID_TINT[name], "titane : teinte absente pour " .. name)
    f.name = name
    f.localised_name = { "fluid-name." .. name }
    f.base_color = { r = tint.r * 0.6, g = tint.g * 0.6, b = tint.b * 0.6 }
    f.flow_color = tint
    f.order = "a[fluid]-z[fo]-b[titanium]-" .. i
    local steam = data.raw.fluid["steam"]
    lib.set_icons(f, { { icon = steam.icon, icon_size = steam.icon_size, icon_mipmaps = steam.icon_mipmaps, tint = tint } })
    out[#out + 1] = f
  end
end

for _, c in ipairs(T.new_categories()) do
  out[#out + 1] = { type = "recipe-category", name = c }
end

---------------------------------------------------------------------------------------------------
-- Machines : stats de X (taille, puissance, vitesse, catégories, boîtes de fluide), visuel PROVISOIRE (copie teintée
-- et mise à l'échelle d'une machine vanilla, dit dans la description). Sans niveaux (question S4).
---------------------------------------------------------------------------------------------------
local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }

local function boxes(side)
  local h = side / 2
  return { { -h + 0.3, -h + 0.3 }, { h - 0.3, h - 0.3 } }, { { -h, -h }, { h, h } }
end

--- Boîte de fluide sur le bord nord (entrée) ou sud (sortie) d'une machine de côté `side`, à la colonne `dx`.
local function fluid_box(kind, side, dx, model)
  local h = side / 2
  local y = kind == "input" and -(h + 0.5) or (h + 0.5)
  return {
    production_type = kind,
    pipe_picture = model and table.deepcopy(model.pipe_picture) or nil,
    pipe_covers = model and table.deepcopy(model.pipe_covers) or nil,
    base_area = 10,
    base_level = kind == "input" and -1 or 1,
    pipe_connections = { { type = kind, position = { dx, y } } },
    secondary_draw_orders = { north = -1 },
  }
end

local function machine(spec)
  local x = T.x_building(spec.name)
  local e = lib.copy("assembling-machine", spec.copy)
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
  end
  -- Boîtes de fluide de X : entrées au nord, sorties au sud (colonnes réparties).
  local model = data.raw["assembling-machine"]["assembling-machine-2"].fluid_boxes[1]
  local fbs = {}
  local nin, nout = x.fluid_in or 0, x.fluid_out or 0
  local cols = { [1] = { -0.5 }, [2] = { -1, 1 } }
  if side == 4 then cols = { [1] = { -0.5 }, [2] = { -1.5, 0.5 } } end
  if side == 2 then cols = { [1] = { -0.5 }, [2] = { -0.5, 0.5 } } end
  if side == 3 then cols[1] = { 0 } end
  for i = 1, nin do fbs[#fbs + 1] = fluid_box("input", side, cols[nin][i], model) end
  for i = 1, nout do fbs[#fbs + 1] = fluid_box("output", side, cols[nout][i], model) end
  if #fbs > 0 then
    fbs.off_when_no_fluid_recipe = true
    e.fluid_boxes = fbs
  else
    e.fluid_boxes = nil
  end
  local src_icon = data.raw.item[spec.copy]
  lib.set_icons(e, icon_of("item", spec.copy, spec.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item",
    name = spec.name,
    localised_name = { "entity-name." .. spec.name },
    localised_description = { "entity-description." .. spec.name },
    icons = icon_of("item", spec.copy, spec.tint),
    subgroup = "fo-titanium-machines",
    order = "z[fo]-b[titanium]-" .. spec.name,
    place_result = spec.name,
    stack_size = 10,
  }
  assert(src_icon, "titane : icône de " .. spec.copy)
end

for _, spec in ipairs(T.BUILDINGS) do machine(spec) end

---------------------------------------------------------------------------------------------------
-- Recettes
---------------------------------------------------------------------------------------------------
local function is_fluid(name)
  local x = T.x_item(name)
  if x then return x.type == "fluid" end
  return data.raw.fluid[name] ~= nil and data.raw.item[name] == nil
end

local function ingredient(n, a)
  if is_fluid(n) then return { type = "fluid", name = n, amount = a } end
  return { type = "item", name = n, amount = a }
end

local function result(r)
  local t = is_fluid(r[1]) and "fluid" or "item"
  local p = { type = t, name = r[1], amount = r[2] }
  if r.p then p.probability = r.p end
  return p
end

for i, rr in ipairs(T.RECIPES) do
  local x = T.process_recipe(rr.name)
  local ings, res = {}, {}
  for _, ing in ipairs(x.ingredients) do ings[#ings + 1] = ingredient(ing[1], ing[2]) end
  for _, r in ipairs(x.results) do res[#res + 1] = result(r) end
  local r = {
    type = "recipe",
    name = x.name,
    category = x.category,
    enabled = false,
    energy_required = x.time,
    ingredients = ings,
    results = res,
    main_product = rr.main or (#res == 1 and res[1].name) or nil,
    subgroup = "fo-titanium",
    order = string.format("z[fo]-b[titanium]-r%02d", i),
    allow_decomposition = true,
  }
  if x.fr then r.localised_name = { "recipe-name." .. x.name } end
  out[#out + 1] = r
end

for _, spec in ipairs(T.BUILDINGS) do
  local b = T.building_recipe(spec.name)
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
-- Technologies
---------------------------------------------------------------------------------------------------
local tech_icon = data.raw.technology["advanced-material-processing-2"]
for _, t in ipairs(T.TECHS) do
  local effects = {}
  for _, r in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(r) end
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = { { icon = tech_icon.icon, icon_size = tech_icon.icon_size, icon_mipmaps = tech_icon.icon_mipmaps, tint = TI } },
    effects = effects,
    prerequisites = t.prerequisites,
    count = t.count,
    packs = T.PACKS,
    time = t.time,
    order = "z[fo]-b[titanium]-" .. t.name,
  })
end

data:extend(out)
