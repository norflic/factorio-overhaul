-- Lot AMELIO-RESSOURCES, piste ÉTAIN (30/10) : combustible usé de l'âge 9 (X0) en jeu. Données :
-- shared/content/spent_fuel.lua. À charger après prototypes/galena.lua (blindage plombé) et prototypes/crafts.lua (verre,
-- technologies de l'arc et de la verrerie).

local lib = require("prototypes.lib")
local F = require("shared.content.spent_fuel")

local out = {}
out[#out + 1] = { type = "item-subgroup", name = "fo-spent-fuel", group = "intermediate-products", order = "z[fo]-d[lead]-b" }

local ICON = {
  ["fo-cooled-spent-cell"] = { "used-up-uranium-fuel-cell", { r = 0.60, g = 0.85, b = 1.00 } },
  ["fo-vitrified-waste"] = { "uranium-fuel-cell", { r = 0.45, g = 0.40, b = 0.34 } },
}
local function icon_of(name, tint)
  local src = assert(data.raw.item[name], "combustible usé : icône absente " .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

for i, n in ipairs(F.ITEMS) do
  local ic = ICON[n]
  out[#out + 1] = {
    type = "item", name = n, localised_name = { "item-name." .. n }, localised_description = { "item-description." .. n },
    icons = icon_of(ic[1], ic[2]), subgroup = "fo-spent-fuel", order = string.format("z[fo]-d[lead]-b%02d", i),
    stack_size = F.item(n).stack,
  }
end

local function boxes(side)
  local h = side / 2
  return { { -h + 0.3, -h + 0.3 }, { h - 0.3, h - 0.3 } }, { { -h, -h }, { h, h } }
end

for _, spec in ipairs(F.BUILDINGS) do
  local x = F.building(spec.name)
  local e = lib.copy(spec.copy[1], spec.copy[2])
  e.type = spec.copy[1]
  e.name = spec.name
  e.localised_name = { "entity-name." .. spec.name }
  e.localised_description = { "entity-description." .. spec.name }
  e.minable = { mining_time = 0.5, result = spec.name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  local side = x.size[1]
  e.collision_box, e.selection_box = boxes(side)
  e.drawing_box = nil
  local k = side / spec.side
  if x.proto == "assembling-machine" then
    for _, c in ipairs(x.categories) do
      if not data.raw["recipe-category"][c] then out[#out + 1] = { type = "recipe-category", name = c } end
    end
    e.crafting_categories = table.deepcopy(x.categories)
    e.crafting_speed = x.speed
    e.energy_source = { type = "void" }
    e.energy_usage = "1W" -- X0 : 1 W, energy_usage doit être positif même avec une source void
    e.fluid_boxes = nil
    e.module_specification = nil
    e.allowed_effects = nil
    e.working_sound = nil
    for _, key in ipairs({ "animation", "idle_animation", "working_visualisations", "shadow" }) do
      if e[key] then lib.scale_sprites(e[key], k); lib.tint_sprites(e[key], spec.tint) end
    end
  else
    e.inventory_size = x.inventory
    if e.picture then lib.scale_sprites(e.picture, k); lib.tint_sprites(e.picture, spec.tint) end
  end
  lib.set_icons(e, icon_of(spec.copy[2], spec.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item", name = spec.name, localised_name = { "entity-name." .. spec.name },
    localised_description = { "entity-description." .. spec.name }, icons = icon_of(spec.copy[2], spec.tint),
    subgroup = "fo-spent-fuel", order = "z[fo]-d[lead]-b-" .. spec.name, place_result = spec.name, stack_size = 10,
  }
end

local function ing(n, a) return { type = "item", name = n, amount = a } end
local all = {}
for _, r in ipairs(F.RECIPES) do all[#all + 1] = r end
for _, b in ipairs(F.BUILDINGS) do all[#all + 1] = { name = b.name } end
for i, rr in ipairs(all) do
  local x = F.recipe(rr.name)
  local ings, res = {}, {}
  for _, a in ipairs(x.ingredients) do ings[#ings + 1] = ing(a[1], a[2]) end
  for _, a in ipairs(x.results) do res[#res + 1] = ing(a[1], a[2]) end
  local r = {
    type = "recipe", name = x.name, category = x.category, enabled = false, energy_required = x.time, ingredients = ings,
    results = res, main_product = rr.main or res[1].name, subgroup = "fo-spent-fuel", order = string.format("z[fo]-d[lead]-b-r%02d", i),
  }
  if x.fr then r.localised_name = { "recipe-name." .. x.name } end
  out[#out + 1] = r
end

local t = F.TECH
local effects = {}
for _, u in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(u) end
local src = data.raw.technology["nuclear-fuel-reprocessing"]
out[#out + 1] = lib.technology({
  name = t.name, localised_name = { "technology-name." .. t.name }, localised_description = { "technology-description." .. t.name },
  icons = { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = { r = 0.62, g = 0.64, b = 0.72 } } },
  effects = effects, prerequisites = t.prerequisites, count = F.tech_count(t), packs = F.packs(t.epoch), time = t.time,
  order = "z[fo]-d[lead]-b-" .. t.name,
})

data:extend(out)
