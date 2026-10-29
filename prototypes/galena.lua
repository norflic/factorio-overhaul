-- Lot AMELIO-RESSOURCES (30/10) : plomb (âge 9) et thorium (âge 12) en jeu : objets, combustible, réacteur à sels fondus
-- au visuel PROVISOIRE, recettes, technologies. Données et règles : shared/content/galena.lua (lit le scénario X0). Le
-- gisement et le minerai de galène : prototypes/world.lua (shared/content/world.lua). À charger APRÈS
-- prototypes/superconductors.lua (oxyde de thorium, oxygène, technologie des supraconducteurs).

local lib = require("prototypes.lib")
local P = require("shared.content.galena")
local T = require("shared.content.titanium")
local W = require("shared.content.world")

local out = {}
local GA = W.resources.galena.tint

out[#out + 1] = { type = "item-subgroup", name = "fo-lead", group = "intermediate-products", order = "z[fo]-d[lead]" }
out[#out + 1] = { type = "fuel-category", name = P.FUEL_CATEGORY }

---------------------------------------------------------------------------------------------------
-- Objets : icônes PROVISOIRES (copies vanilla teintées ; F36, F38).
---------------------------------------------------------------------------------------------------
local ICON = {
  ["fo-lead-plate"] = { "item", "iron-plate", { r = 0.62, g = 0.64, b = 0.72 } },
  ["fo-lead-shielding"] = { "item", "steel-plate", { r = 0.55, g = 0.58, b = 0.68 } },
  ["fo-thorium-salt-cell"] = { "item", "uranium-fuel-cell", { r = 0.70, g = 0.95, b = 1.00 } },
  ["fo-spent-salt"] = { "item", "used-up-uranium-fuel-cell", { r = 0.62, g = 0.66, b = 0.70 } },
}

local function icon_of(ptype, name, tint)
  local src = assert(data.raw[ptype][name], "galène : icône source absente " .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

local fuel = P.fuel()
for i, name in ipairs(P.ITEMS) do
  local ic = assert(ICON[name], "galène : icône provisoire absente pour " .. name)
  local item = {
    type = "item",
    name = name,
    localised_name = { "item-name." .. name },
    localised_description = { "item-description." .. name },
    icons = icon_of(ic[1], ic[2], ic[3]),
    subgroup = "fo-lead",
    order = string.format("z[fo]-d[lead]-%02d", i),
    stack_size = P.stack(name),
  }
  local src = data.raw[ic[1]][ic[2]]
  if src.pictures then
    item.pictures = table.deepcopy(src.pictures)
    lib.tint_sprites(item.pictures, ic[3])
  end
  if name == "fo-thorium-salt-cell" then
    item.fuel_category = fuel.category
    item.fuel_value = fuel.mj .. "MJ"
    item.burnt_result = fuel.burnt
  end
  out[#out + 1] = item
end

---------------------------------------------------------------------------------------------------
-- Réacteur à sels fondus : stats de X, visuel PROVISOIRE (réacteur nucléaire vanilla teinté, même emprise 5 × 5).
---------------------------------------------------------------------------------------------------
do
  local x = P.reactor_x()
  local e = lib.copy("reactor", P.REACTOR.copy)
  e.name = P.REACTOR.name
  e.localised_name = { "entity-name." .. e.name }
  e.localised_description = { "entity-description." .. e.name }
  e.minable = { mining_time = 0.5, result = e.name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  e.consumption = x.heat_kw .. "kW"
  e.neighbour_bonus = x.neighbour_bonus
  e.energy_source = table.deepcopy(e.energy_source)
  e.energy_source.fuel_category = x.energy.fuel_category
  e.energy_source.fuel_categories = nil
  e.energy_source.burnt_inventory_size = x.burnt_inventory and 1 or 0
  e.heat_buffer = table.deepcopy(e.heat_buffer)
  e.heat_buffer.max_temperature = x.max_temperature
  e.heat_buffer.max_transfer = x.max_transfer_kw .. "kW"
  for _, key in ipairs({ "picture", "working_light_picture", "lower_layer_picture" }) do
    if e[key] then lib.tint_sprites(e[key], P.REACTOR.tint) end
  end
  lib.set_icons(e, icon_of("item", P.REACTOR.copy, P.REACTOR.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item",
    name = e.name,
    localised_name = { "entity-name." .. e.name },
    localised_description = { "entity-description." .. e.name },
    icons = icon_of("item", P.REACTOR.copy, P.REACTOR.tint),
    subgroup = "fo-lead",
    order = "z[fo]-d[lead]-r",
    place_result = e.name,
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

local function ingredient(n, a)
  if is_fluid(n) then return { type = "fluid", name = n, amount = a } end
  return { type = "item", name = n, amount = a }
end

local function result(r)
  local p = { type = is_fluid(r[1]) and "fluid" or "item", name = r[1], amount = r[2] }
  if r.p then p.probability = r.p end
  return p
end

for i, rr in ipairs(P.RECIPES) do
  local x = P.process_recipe(rr.name)
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
    subgroup = "fo-lead",
    order = string.format("z[fo]-d[lead]-r%02d", i),
    allow_decomposition = true,
  }
  if #res > 1 then r.localised_name = { "recipe-name." .. x.name } end
  out[#out + 1] = r
end

do
  local b = P.reactor_recipe()
  local ings = {}
  for _, ing in ipairs(b.ingredients) do ings[#ings + 1] = ingredient(ing[1], ing[2]) end
  out[#out + 1] = {
    type = "recipe",
    name = P.REACTOR.name,
    category = b.category,
    enabled = false,
    energy_required = b.time,
    ingredients = ings,
    result = P.REACTOR.name,
  }
end

---------------------------------------------------------------------------------------------------
-- Technologies
---------------------------------------------------------------------------------------------------
local ICON_TECH = {
  ["fo-lead-processing"] = { "advanced-material-processing", GA },
  ["fo-galena-roasting"] = { "advanced-material-processing-2", GA },
  ["fo-thorium"] = { "nuclear-power", P.REACTOR.tint },
}
for _, t in ipairs(P.TECHS) do
  local effects = {}
  for _, r in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(r) end
  local ic = ICON_TECH[t.name]
  local src = data.raw.technology[ic[1]]
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = ic[2] } },
    effects = effects,
    prerequisites = t.prerequisites,
    count = t.count,
    packs = t.packs,
    time = t.time,
    order = "z[fo]-d[lead]-" .. t.name,
  })
end

data:extend(out)
