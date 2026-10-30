-- Lot AMELIO-RESSOURCES, piste GÉOTHERMIE (30/10) : capteur géothermique (visuel PROVISOIRE : chevalet de pompage teinté),
-- séparation du gaz volcanique (vapeur à 165 °C et soufre), torchère du gaz, technologie « Géothermie ». Données :
-- shared/content/geothermal.lua. La fumerolle et le gaz volcanique : prototypes/world.lua. À charger APRÈS
-- prototypes/crafts.lua (manomètre, torchère, technologies de la verrerie et de la torchère).

local lib = require("prototypes.lib")
local Gt = require("shared.content.geothermal")
local W = require("shared.content.world")

local out = {}
local TINT = W.resources.fumarole.tint

local function layers_of(name)
  local p = data.raw.item[name] or data.raw.fluid[name]
  assert(p, "géothermie : icône absente " .. name)
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

---------------------------------------------------------------------------------------------------
-- Capteur géothermique : stats d'X0 (3 × 3, 300 kW, vitesse 1, catégorie fo-fumarole, sortie de fluide).
---------------------------------------------------------------------------------------------------
for _, spec in ipairs(Gt.BUILDINGS) do
  local x = Gt.building(spec.name)
  local e = lib.copy(spec.copy[1], spec.copy[2])
  e.name = spec.name
  e.localised_name = { "entity-name." .. spec.name }
  e.localised_description = { "entity-description." .. spec.name }
  e.minable = { mining_time = 0.5, result = spec.name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  e.resource_categories = table.deepcopy(x.resource_categories)
  e.mining_speed = x.mining_speed
  e.energy_usage = x.kw .. "kW"
  for _, key in ipairs({ "base_picture", "animations", "graphics_set" }) do
    if e[key] then lib.tint_sprites(e[key], spec.tint) end
  end
  local icons = layers_of(spec.copy[2])
  for _, l in ipairs(icons) do l.tint = spec.tint end
  lib.set_icons(e, icons)
  out[#out + 1] = e
  local src = data.raw.item[spec.copy[2]]
  out[#out + 1] = {
    type = "item", name = spec.name,
    localised_name = { "entity-name." .. spec.name }, localised_description = { "entity-description." .. spec.name },
    icons = table.deepcopy(icons), subgroup = src.subgroup, order = (src.order or "") .. "-z[fo-geothermal-tap]",
    place_result = spec.name, stack_size = src.stack_size or 20,
  }
  local b = Gt.recipe(spec.name)
  local ings = {}
  for _, ing in ipairs(b.ingredients) do ings[#ings + 1] = { type = "item", name = ing[1], amount = ing[2] } end
  out[#out + 1] = { type = "recipe", name = spec.name, category = b.category, enabled = false, energy_required = b.time,
    ingredients = ings, result = spec.name }
end

---------------------------------------------------------------------------------------------------
-- Recettes d'X0 : séparation (vapeur à 165 °C, X0 : « vapeur produite à 165 °C »), torchère.
---------------------------------------------------------------------------------------------------
local function is_fluid(n)
  local x = Gt.x_item(n)
  if x then return x.type == "fluid" end
  return data.raw.fluid[n] ~= nil and data.raw.item[n] == nil
end

for i, rr in ipairs(Gt.RECIPES) do
  local x = Gt.recipe(rr.name)
  local ings, res = {}, {}
  for _, ing in ipairs(x.ingredients) do
    ings[#ings + 1] = { type = is_fluid(ing[1]) and "fluid" or "item", name = ing[1], amount = ing[2] }
  end
  for _, p in ipairs(x.results) do
    local r = { type = is_fluid(p[1]) and "fluid" or "item", name = p[1], amount = p[2] }
    if p[1] == "steam" then r.temperature = 165 end
    res[#res + 1] = r
  end
  local r = {
    type = "recipe", name = x.name, category = x.category, enabled = false, energy_required = x.time,
    ingredients = ings, results = res, subgroup = "fluid-recipes", order = string.format("z[fo]-g[geothermal]-%02d", i),
    localised_name = { "recipe-name." .. x.name }, localised_description = { "recipe-description." .. x.name },
  }
  local icons = layers_of(Gt.FLUID)
  local mark = rr.flare and "fo-flare-stack" or "sulfur"
  for _, l in ipairs(layers_of(mark)) do
    l.scale = 0.5 * (32 / (l.icon_size or 32))
    l.shift = { 8, 8 }
    icons[#icons + 1] = l
  end
  r.icons = icons
  out[#out + 1] = r
end

---------------------------------------------------------------------------------------------------
-- Technologie « Géothermie » (X0, âge 5)
---------------------------------------------------------------------------------------------------
do
  local t = Gt.TECH
  local src = data.raw.technology["oil-processing"]
  local effects = {}
  for _, u in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(u) end
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = TINT } },
    effects = effects, prerequisites = t.prerequisites, count = Gt.tech_count(t), packs = Gt.packs(t.epoch), time = t.time,
    order = "z[fo]-g[geothermal]",
  })
end

data:extend(out)
