-- Lot AMELIO-RESSOURCES, piste ÉTAIN (30/10) : la carte de circuit imprimé (chaîne A d'X3, âge 4) en jeu : objets,
-- résine, imprimante de circuits au visuel PROVISOIRE, recettes, technologie. Données : shared/content/tin.lua. Le
-- gisement et le minerai de cassitérite : prototypes/world.lua. À charger APRÈS prototypes/crafts.lua (verre, éthylène,
-- technologies de la verrerie et du vapocraquage).

local lib = require("prototypes.lib")
local Sn = require("shared.content.tin")
local W = require("shared.content.world")

local out = {}
local TINT = W.resources.cassiterite.tint

out[#out + 1] = { type = "item-subgroup", name = "fo-tin", group = "intermediate-products", order = "z[fo]-e[tin]" }

local ICON = {
  ["fo-tin-plate"] = { "item", "iron-plate", { r = 0.86, g = 0.88, b = 0.84 } },
  ["fo-copper-clad-laminate"] = { "item", "copper-plate", { r = 1.00, g = 0.86, b = 0.62 } },
  ["fo-printed-circuit-board"] = { "item", "electronic-circuit", { r = 0.55, g = 1.00, b = 0.55 } },
}
local FLUID_TINT = { ["fo-epoxy-resin"] = { r = 0.95, g = 0.80, b = 0.40 } }

local function icon_of(ptype, name, tint)
  local src = assert(data.raw[ptype][name], "étain : icône source absente " .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

for i, name in ipairs(Sn.ITEMS) do
  local x = assert(Sn.x3_item(name), "étain : objet X3 absent " .. name)
  local ic = ICON[name]
  local item = {
    type = "item", name = name,
    localised_name = { "item-name." .. name }, localised_description = { "item-description." .. name },
    icons = icon_of(ic[1], ic[2], ic[3]), subgroup = "fo-tin", order = string.format("z[fo]-e[tin]-%02d", i),
    stack_size = x.stack,
  }
  local src = data.raw[ic[1]][ic[2]]
  if src.pictures then
    item.pictures = table.deepcopy(src.pictures)
    lib.tint_sprites(item.pictures, ic[3])
  end
  out[#out + 1] = item
end

for i, name in ipairs(Sn.FLUIDS) do
  local f = lib.copy("fluid", "heavy-oil")
  local tint = FLUID_TINT[name]
  f.name = name
  f.localised_name = { "fluid-name." .. name }
  f.base_color = { r = tint.r * 0.6, g = tint.g * 0.6, b = tint.b * 0.6 }
  f.flow_color = tint
  f.fuel_value = nil
  f.order = "a[fluid]-z[fo]-e[tin]-" .. i
  lib.set_icons(f, { { icon = f.icon, icon_size = f.icon_size, icon_mipmaps = f.icon_mipmaps, tint = tint } })
  out[#out + 1] = f
end

---------------------------------------------------------------------------------------------------
-- Imprimante de circuits : stats d'X3, visuel PROVISOIRE (assembleur 2 teinté, comme X3 le dit).
---------------------------------------------------------------------------------------------------
for _, spec in ipairs(Sn.BUILDINGS) do
  local x = Sn.x3_building(spec.name)
  for _, c in ipairs(x.categories) do
    if not data.raw["recipe-category"][c] then out[#out + 1] = { type = "recipe-category", name = c } end
  end
  local e = lib.copy("assembling-machine", spec.copy)
  e.name = spec.name
  e.localised_name = { "entity-name." .. spec.name }
  e.localised_description = { "entity-description." .. spec.name }
  e.minable = { mining_time = 0.3, result = spec.name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  e.crafting_categories = table.deepcopy(x.categories)
  e.crafting_speed = x.speed
  e.energy_usage = x.kw .. "kW"
  for _, key in ipairs({ "animation", "idle_animation", "working_visualisations" }) do
    if e[key] then lib.tint_sprites(e[key], spec.tint) end
  end
  -- Une entrée de fluide (X3 : fluid_in 1) : la boîte d'entrée de l'assembleur 2 copié, seule.
  local fb = nil
  for _, b in ipairs(e.fluid_boxes or {}) do
    if type(b) == "table" and b.production_type == "input" and not fb then fb = table.deepcopy(b) end
  end
  assert(fb, "étain : boîte d'entrée absente de " .. spec.copy)
  e.fluid_boxes = { fb, off_when_no_fluid_recipe = true }
  lib.set_icons(e, icon_of("item", spec.copy, spec.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item", name = spec.name,
    localised_name = { "entity-name." .. spec.name }, localised_description = { "entity-description." .. spec.name },
    icons = icon_of("item", spec.copy, spec.tint), subgroup = "fo-tin", order = "z[fo]-e[tin]-m",
    place_result = spec.name, stack_size = 50,
  }
end

---------------------------------------------------------------------------------------------------
-- Recettes (celles d'X3) ; la recette de la machine aussi.
---------------------------------------------------------------------------------------------------
local function is_fluid(n)
  local f = Sn.is_fluid(n)
  if f ~= nil then return f end
  return data.raw.fluid[n] ~= nil and data.raw.item[n] == nil
end
local function ingredient(n, a) return { type = is_fluid(n) and "fluid" or "item", name = n, amount = a } end

local all = {}
for _, rr in ipairs(Sn.RECIPES) do all[#all + 1] = rr end
for _, b in ipairs(Sn.BUILDINGS) do all[#all + 1] = { name = b.name, building = true } end
for i, rr in ipairs(all) do
  local x = Sn.x3_recipe(rr.name)
  local ings, res = {}, {}
  for _, ing in ipairs(x.ingredients) do ings[#ings + 1] = ingredient(ing[1], ing[2]) end
  for _, r in ipairs(x.results) do res[#res + 1] = ingredient(r[1], r[2]) end
  local r = {
    type = "recipe", name = x.name, category = x.category, enabled = false, energy_required = x.time,
    ingredients = ings, results = res, main_product = res[1].name,
    subgroup = "fo-tin", order = string.format("z[fo]-e[tin]-r%02d", i), allow_decomposition = not rr.variant,
  }
  if rr.variant then
    -- Variante (X3) : nom propre, icône du produit vanilla marquée de la carte imprimée.
    r.localised_name = { "recipe-name." .. x.name }
    local a = data.raw.item[rr.variant]
    local p = data.raw.item["electronic-circuit"]
    r.icons = { { icon = a.icon, icon_size = a.icon_size, icon_mipmaps = a.icon_mipmaps },
                { icon = p.icon, icon_size = p.icon_size, icon_mipmaps = p.icon_mipmaps, scale = 0.25, shift = { -8, -8 },
                  tint = ICON["fo-printed-circuit-board"][3] } }
    r.subgroup = "intermediate-product"
    r.order = "f[advanced-circuit]-z[fo-pcb]"
  end
  out[#out + 1] = r
end

---------------------------------------------------------------------------------------------------
-- Technologie
---------------------------------------------------------------------------------------------------
local src = data.raw.technology["advanced-electronics"]
for _, t in ipairs(Sn.TECHS) do
  local effects = {}
  for _, u in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(u) end
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = TINT } },
    effects = effects, prerequisites = t.prerequisites, count = Sn.tech_count(t), packs = Sn.packs(t.epoch), time = t.time,
    order = "z[fo]-e[tin]-" .. t.name,
  })
end

data:extend(out)
