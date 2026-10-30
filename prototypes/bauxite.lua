-- Lot AMELIO-RESSOURCES, piste BAUXITE (30/10) : l'aluminium (chaîne C d'X3, âge 6) en jeu : objets, cuve d'électrolyse
-- ignée et pylône haute tension (X0) au visuel PROVISOIRE, recettes, technologies. Données : shared/content/bauxite.lua.
-- Le gisement et le minerai de bauxite : prototypes/world.lua. À charger APRÈS prototypes/crafts.lua (graphite, four à
-- arc, concasseur, ciment, bobine, laitier ; technologies fo-arc-smelting et fo-electrical-steel).

local lib = require("prototypes.lib")
local B = require("shared.content.bauxite")
local W = require("shared.content.world")

local out = {}
local TINT = W.resources.bauxite.tint

out[#out + 1] = { type = "item-subgroup", name = "fo-bauxite", group = "intermediate-products", order = "z[fo]-f[bauxite]" }
out[#out + 1] = { type = "item-subgroup", name = "fo-bauxite-machines", group = "production", order = "z[fo]-f[bauxite]" }

-- Icônes PROVISOIRES (copies vanilla teintées : une teinte ne fait que multiplier, F36, F38).
local ICON = {
  ["fo-alumina"] = { "item", "plastic-bar", { r = 1.00, g = 0.97, b = 0.94 } },
  ["fo-red-mud"] = { "item", "stone", { r = 0.90, g = 0.38, b = 0.24 } },
  ["fo-aluminium-plate"] = { "item", "steel-plate", { r = 0.92, g = 0.95, b = 1.00 } },
}

local function icon_of(ptype, name, tint)
  local src = assert(data.raw[ptype][name], "bauxite : icône source absente " .. ptype .. "/" .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

for i, name in ipairs(B.ITEMS) do
  local x = assert(B.x3_item(name), "bauxite : objet X3 absent " .. name)
  local ic = ICON[name]
  local item = {
    type = "item", name = name,
    localised_name = { "item-name." .. name }, localised_description = { "item-description." .. name },
    icons = icon_of(ic[1], ic[2], ic[3]), subgroup = "fo-bauxite", order = string.format("z[fo]-f[bauxite]-%02d", i),
    stack_size = x.stack,
  }
  local src = data.raw[ic[1]][ic[2]]
  if src.pictures then
    item.pictures = table.deepcopy(src.pictures)
    lib.tint_sprites(item.pictures, ic[3])
  end
  out[#out + 1] = item
end

---------------------------------------------------------------------------------------------------
-- Cuve d'électrolyse ignée : stats d'X3 (4 × 4, 6 MW), visuel PROVISOIRE (four électrique teinté, mis à l'échelle 4/3,
-- devenu machine à recette comme le haut fourneau d'AMELIO-CRAFTS).
---------------------------------------------------------------------------------------------------
local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }

local function cell(spec)
  local x = B.building(spec.name)
  for _, c in ipairs(x.categories) do
    if not data.raw["recipe-category"][c] then out[#out + 1] = { type = "recipe-category", name = c } end
  end
  local e = lib.copy(spec.copy[1], spec.copy[2])
  e.type = "assembling-machine"
  e.source_inventory_size, e.result_inventory_size = nil, nil
  local side = x.size[1]
  local h = side / 2
  e.name = spec.name
  e.localised_name = { "entity-name." .. spec.name }
  e.localised_description = { "entity-description." .. spec.name }
  e.minable = { mining_time = 0.3, result = spec.name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  e.crafting_categories = table.deepcopy(x.categories)
  e.crafting_speed = x.speed
  e.energy_usage = x.kw .. "kW"
  e.energy_source = { type = "electric", usage_priority = "secondary-input", emissions_per_minute = 4 }
  e.collision_box = { { -h + 0.3, -h + 0.3 }, { h - 0.3, h - 0.3 } }
  e.selection_box = { { -h, -h }, { h, h } }
  e.drawing_box = nil
  e.water_reflection = nil
  e.fluid_boxes = nil
  local k = side / spec.side
  for _, key in ipairs(VISUAL_KEYS) do
    if e[key] then
      if k ~= 1 then lib.scale_sprites(e[key], k) end
      lib.tint_sprites(e[key], spec.tint)
    end
  end
  lib.set_icons(e, icon_of("item", spec.copy[2], spec.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item", name = spec.name,
    localised_name = { "entity-name." .. spec.name }, localised_description = { "entity-description." .. spec.name },
    icons = icon_of("item", spec.copy[2], spec.tint), subgroup = "fo-bauxite-machines", order = "z[fo]-f[bauxite]-" .. spec.name,
    place_result = spec.name, stack_size = 10,
  }
end

---------------------------------------------------------------------------------------------------
-- Pylône haute tension (X0) : fil de 64 (plafond moteur), zone d'alimentation 0,5 ; grand poteau teinté (PROVISOIRE).
---------------------------------------------------------------------------------------------------
local function pylon(spec)
  local x = B.building(spec.name)
  local e = lib.copy(spec.copy[1], spec.copy[2])
  e.name = spec.name
  e.localised_name = { "entity-name." .. spec.name }
  e.localised_description = { "entity-description." .. spec.name }
  e.minable = { mining_time = 0.2, result = spec.name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  e.maximum_wire_distance = x.wire_distance
  e.supply_area_distance = x.supply_distance
  if e.pictures then lib.tint_sprites(e.pictures, spec.tint) end
  lib.set_icons(e, icon_of("item", spec.copy[2], spec.tint))
  out[#out + 1] = e
  local src = data.raw.item[spec.copy[2]]
  out[#out + 1] = {
    type = "item", name = spec.name,
    localised_name = { "entity-name." .. spec.name }, localised_description = { "entity-description." .. spec.name },
    icons = icon_of("item", spec.copy[2], spec.tint), subgroup = src.subgroup, order = (src.order or "") .. "-z[fo-ht-pylon]",
    place_result = spec.name, stack_size = src.stack_size or 50,
  }
end

for _, spec in ipairs(B.BUILDINGS) do
  if B.building(spec.name).proto == "electric-pole" then pylon(spec) else cell(spec) end
end

---------------------------------------------------------------------------------------------------
-- Recettes (celles d'X3 ; le pylône : celle d'X0) ; la recette de chaque bâtiment aussi.
---------------------------------------------------------------------------------------------------
local function is_fluid(n)
  local it = B.x3_item(n)
  if it then return it.type == "fluid" end
  return data.raw.fluid[n] ~= nil and data.raw.item[n] == nil
end
local function ingredient(n, a) return { type = is_fluid(n) and "fluid" or "item", name = n, amount = a } end

local function proto_icon(n)
  local p = data.raw.item[n] or data.raw.fluid[n]
  assert(p, "bauxite : icône absente " .. n)
  if p.icons then return table.deepcopy(p.icons) end
  return { { icon = p.icon, icon_size = p.icon_size, icon_mipmaps = p.icon_mipmaps } }
end

-- Les icônes des objets d'avant sont posées par data:extend : les nôtres sont dans `out`, les autres dans data.raw.
local own = {}
for _, p in ipairs(out) do if p.type == "item" then own[p.name] = p end end
local function icons_of_item(n)
  local p = own[n]
  if p then return table.deepcopy(p.icons) end
  return proto_icon(n)
end

for i, rr in ipairs(B.all_recipes()) do
  local x = B.recipe(rr.name)
  local ings, res = {}, {}
  for _, ing in ipairs(x.ingredients) do ings[#ings + 1] = ingredient(ing[1], ing[2]) end
  for _, r in ipairs(x.results) do res[#res + 1] = ingredient(r[1], r[2]) end
  local r = {
    type = "recipe", name = x.name, category = x.category, enabled = false, energy_required = x.time,
    ingredients = ings, results = res, main_product = res[1].name,
    subgroup = rr.building and "fo-bauxite-machines" or "fo-bauxite",
    order = string.format("z[fo]-f[bauxite]-r%02d", i), allow_decomposition = not rr.variant,
  }
  if rr.building and rr.name == "fo-ht-pylon" then r.subgroup = nil end
  if x.fr and not rr.building then r.localised_name = { "recipe-name." .. x.name } end
  if rr.variant then
    -- Variante : nom propre, icône du produit marquée de l'ingrédient nouveau (boue rouge ou aluminium).
    r.localised_name = { "recipe-name." .. x.name }
    local mark = rr.variant == "fo-ht-pylon" and "fo-aluminium-plate" or "fo-red-mud"
    local icons = icons_of_item(rr.variant)
    for _, l in ipairs(icons_of_item(mark)) do
      l.scale = 0.25 * 64 / (l.icon_size or 64)
      l.shift = { -8, -8 }
      icons[#icons + 1] = l
    end
    r.icons = icons
    r.main_product = ""
  end
  out[#out + 1] = r
end

---------------------------------------------------------------------------------------------------
-- Technologies
---------------------------------------------------------------------------------------------------
local TECH_ICON = { ["fo-high-voltage"] = "electric-energy-distribution-2", ["fo-aluminium"] = "advanced-material-processing-2" }
for _, t in ipairs(B.TECHS) do
  local src = data.raw.technology[TECH_ICON[t.name]]
  local effects = {}
  for _, u in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(u) end
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps,
                tint = t.name == "fo-aluminium" and { r = 0.90, g = 0.93, b = 1.00 } or TINT } },
    effects = effects, prerequisites = t.prerequisites, count = B.tech_count(t), packs = B.packs(t.epoch), time = t.time,
    order = "z[fo]-f[bauxite]-" .. t.name,
  })
end

data:extend(out)
