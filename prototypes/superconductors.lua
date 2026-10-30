-- Lot X2 (25/10) : la chaîne de la monnaie de l'âge 12 (bobine supraconductrice) en jeu : objets, fluides,
-- catégories, machines au visuel PROVISOIRE, recettes, technologies. Données et règles : shared/content/superconductors.lua
-- (lit le scénario X0, shared/content/epochs.lua). Le minerai de monazite et les sables noirs : prototypes/world.lua
-- (shared/content/world.lua). À charger APRÈS prototypes/titanium.lua (électrolyseur, concentrateur, technologie du
-- titane).

local lib = require("prototypes.lib")
local S = require("shared.content.superconductors")
local T = require("shared.content.titanium")
local W = require("shared.content.world")

local out = {}
local MZ = W.resources.monazite.tint

out[#out + 1] = { type = "item-subgroup", name = "fo-superconductors", group = "intermediate-products", order = "z[fo]-c[superconductors]" }
out[#out + 1] = { type = "item-subgroup", name = "fo-superconductors-machines", group = "production", order = "z[fo]-c[superconductors]" }

---------------------------------------------------------------------------------------------------
-- Objets : icônes PROVISOIRES (copies vanilla teintées, F36, F38 : une teinte multiplie). Le minerai de monazite a sa
-- feuille propre (prototypes/world.lua).
---------------------------------------------------------------------------------------------------
local ICON = {
  ["fo-monazite-concentrate"] = { "item", "iron-ore", { r = 0.78, g = 0.56, b = 0.30 } },
  ["fo-rare-earth-concentrate"] = { "item", "stone", { r = 1.00, g = 0.82, b = 0.78 } },
  ["fo-thorium-oxide"] = { "item", "stone", { r = 0.96, g = 0.97, b = 0.90 } },
  ["fo-neodymium"] = { "item", "steel-plate", { r = 0.88, g = 0.90, b = 0.80 } },
  ["fo-yttrium"] = { "item", "steel-plate", { r = 0.92, g = 0.92, b = 1.00 } },
  ["fo-superconducting-tape"] = { "item", "copper-cable", { r = 0.45, g = 0.45, b = 0.52 } },
  ["fo-permanent-magnet"] = { "item", "iron-gear-wheel", { r = 0.72, g = 0.76, b = 0.88 } },
  ["fo-cryostat"] = { "item", "storage-tank", { r = 0.86, g = 0.93, b = 1.00 } },
  ["fo-superconducting-coil"] = { "item", "copper-cable", { r = 0.62, g = 0.86, b = 1.00 } },
}
local FLUID_TINT = {
  ["fo-oxygen"] = { r = 1.00, g = 0.80, b = 0.80 },
  ["fo-liquid-nitrogen"] = { r = 0.78, g = 0.96, b = 1.00 },
  ["fo-liquid-oxygen"] = { r = 0.52, g = 0.68, b = 1.00 },
}

local function icon_of(ptype, name, tint)
  local src = assert(data.raw[ptype][name], "supraconducteurs : icône source absente " .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

for i, name in ipairs(S.ITEMS) do
  local x = T.x_item(name)
  local ic = assert(ICON[name], "supraconducteurs : icône provisoire absente pour " .. name)
  local item = {
    type = "item",
    name = name,
    localised_name = { "item-name." .. name },
    localised_description = { "item-description." .. name },
    icons = icon_of(ic[1], ic[2], ic[3]),
    subgroup = "fo-superconductors",
    order = string.format("z[fo]-c[superconductors]-%02d", i),
    stack_size = x.stack,
  }
  local src = data.raw[ic[1]][ic[2]]
  if src.pictures then
    item.pictures = table.deepcopy(src.pictures)
    lib.tint_sprites(item.pictures, ic[3])
  end
  out[#out + 1] = item
end

-- Fluides : copie de l'eau, icône de la vapeur teintée ; température de X (azote et oxygène liquides) comme température
-- par défaut (la température maximale de l'eau, 100, reste : « default_temperature has to be lower than max »).
for i, name in ipairs(S.FLUIDS) do
  local x = T.x_item(name)
  local f = lib.copy("fluid", "water")
  local tint = assert(FLUID_TINT[name], "supraconducteurs : teinte absente pour " .. name)
  f.name = name
  f.localised_name = { "fluid-name." .. name }
  f.base_color = { r = tint.r * 0.6, g = tint.g * 0.6, b = tint.b * 0.6 }
  f.flow_color = tint
  f.order = "a[fluid]-z[fo]-c[superconductors]-" .. i
  if x.temperature then f.default_temperature = x.temperature end
  local steam = data.raw.fluid["steam"]
  lib.set_icons(f, { { icon = steam.icon, icon_size = steam.icon_size, icon_mipmaps = steam.icon_mipmaps, tint = tint } })
  out[#out + 1] = f
end

for _, c in ipairs(S.new_categories()) do
  out[#out + 1] = { type = "recipe-category", name = c }
end

---------------------------------------------------------------------------------------------------
-- Machines : stats de X (taille, puissance, vitesse, catégories, boîtes de fluide), visuel PROVISOIRE (copie teintée
-- et mise à l'échelle d'une machine vanilla, dit dans la description). Sans niveaux (question S4, comme au lot X1).
---------------------------------------------------------------------------------------------------
local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }

local function boxes(side)
  local h = side / 2
  return { { -h + 0.3, -h + 0.3 }, { h - 0.3, h - 0.3 } }, { { -h, -h }, { h, h } }
end

--- Boîte de fluide sur le bord nord (entrée) ou sud (sortie) d'une machine de côté `side`, à la colonne `dx` (lot X1).
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
  if spec.keep_fluid_boxes then
    -- Boîtes de la copie (raffinerie : 2 entrées, 3 sorties = X fluid_in 2, fluid_out 3), contrôlées.
    local nin, nout = 0, 0
    for _, fb in ipairs(e.fluid_boxes) do
      if fb.production_type == "input" then nin = nin + 1 elseif fb.production_type == "output" then nout = nout + 1 end
    end
    assert(nin == (x.fluid_in or 0) and nout == (x.fluid_out or 0),
      "supraconducteurs : boîtes de fluide de " .. spec.copy .. " différentes de X pour " .. spec.name)
  else
    local model = data.raw["assembling-machine"]["assembling-machine-2"].fluid_boxes[1]
    local fbs = {}
    local nin, nout = x.fluid_in or 0, x.fluid_out or 0
    local cols = { [1] = { -0.5 }, [2] = { -1, 1 } }
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
  end
  lib.set_icons(e, icon_of("item", spec.copy, spec.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item",
    name = spec.name,
    localised_name = { "entity-name." .. spec.name },
    localised_description = { "entity-description." .. spec.name },
    icons = icon_of("item", spec.copy, spec.tint),
    subgroup = "fo-superconductors-machines",
    order = "z[fo]-c[superconductors]-" .. spec.name,
    place_result = spec.name,
    stack_size = 10,
  }
end

for _, spec in ipairs(S.BUILDINGS) do
  if not spec.external then machine(spec) end
end

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

for i, rr in ipairs(S.RECIPES) do
  local x = S.process_recipe(rr.name)
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
    subgroup = "fo-superconductors",
    order = string.format("z[fo]-c[superconductors]-r%02d", i),
    allow_decomposition = true,
  }
  if x.fr then r.localised_name = { "recipe-name." .. x.name } end
  out[#out + 1] = r
end

for _, spec in ipairs(S.BUILDINGS) do
  if spec.external then goto continue end
  local b = S.building_recipe(spec.name)
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
  ::continue::
end

---------------------------------------------------------------------------------------------------
-- Technologies
---------------------------------------------------------------------------------------------------
local tech_icon = data.raw.technology["advanced-material-processing-2"]
for _, t in ipairs(S.TECHS) do
  local effects = {}
  for _, r in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(r) end
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = { { icon = tech_icon.icon, icon_size = tech_icon.icon_size, icon_mipmaps = tech_icon.icon_mipmaps, tint = MZ } },
    effects = effects,
    prerequisites = t.prerequisites,
    count = t.count,
    packs = S.PACKS,
    time = t.time,
    order = "z[fo]-c[superconductors]-" .. t.name,
  })
end

data:extend(out)
