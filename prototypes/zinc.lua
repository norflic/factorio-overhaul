-- Lot AMELIO-RESSOURCES, piste ZINC (30/10) : zinc, laiton, manomètre à tube de Bourdon (X3, âge 3). Données :
-- shared/content/zinc.lua. Le gisement et le minerai de blende : prototypes/world.lua. À charger APRÈS
-- prototypes/crafts.lua (verre, manomètre, four à coke, haut fourneau, technologie fo-glassworks).

local lib = require("prototypes.lib")
local Z = require("shared.content.zinc")

local out = {}

out[#out + 1] = { type = "item-subgroup", name = "fo-zinc", group = "intermediate-products", order = "z[fo]-h[zinc]" }

-- Icônes PROVISOIRES (copies vanilla teintées, F36, F38).
local ICON = {
  ["fo-zinc-plate"] = { "item", "iron-plate", { r = 0.80, g = 0.86, b = 0.90 } },
  ["fo-brass"] = { "item", "copper-plate", { r = 1.00, g = 0.86, b = 0.40 } },
}

local function icon_of(ptype, name, tint)
  local src = assert(data.raw[ptype][name], "zinc : icône source absente " .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

for i, name in ipairs(Z.ITEMS) do
  local x = assert(Z.x3_item(name), "zinc : objet X3 absent " .. name)
  local ic = ICON[name]
  local item = {
    type = "item", name = name,
    localised_name = { "item-name." .. name }, localised_description = { "item-description." .. name },
    icons = icon_of(ic[1], ic[2], ic[3]), subgroup = "fo-zinc", order = string.format("z[fo]-h[zinc]-%02d", i),
    stack_size = x.stack,
  }
  local src = data.raw[ic[1]][ic[2]]
  if src.pictures then
    item.pictures = table.deepcopy(src.pictures)
    lib.tint_sprites(item.pictures, ic[3])
  end
  out[#out + 1] = item
end

local function layers_of(name)
  for _, o in ipairs(out) do if o.type == "item" and o.name == name then return table.deepcopy(o.icons) end end
  local p = assert(data.raw.item[name], "zinc : icône absente " .. name)
  if p.icons then return table.deepcopy(p.icons) end
  return { { icon = p.icon, icon_size = p.icon_size, icon_mipmaps = p.icon_mipmaps } }
end

for i, rr in ipairs(Z.RECIPES) do
  local x = Z.recipe(rr.name)
  local ings, res = {}, {}
  for _, ing in ipairs(x.ingredients) do ings[#ings + 1] = { type = "item", name = ing[1], amount = ing[2] } end
  for _, p in ipairs(x.results) do res[#res + 1] = { type = "item", name = p[1], amount = p[2] } end
  local r = {
    type = "recipe", name = x.name, category = x.category, enabled = false, energy_required = x.time,
    ingredients = ings, results = res, main_product = res[1].name,
    subgroup = "fo-zinc", order = string.format("z[fo]-h[zinc]-r%02d", i), allow_decomposition = not rr.variant,
  }
  if x.fr then r.localised_name = { "recipe-name." .. x.name } end
  if rr.variant then
    -- Variante : icône du manomètre marquée du laiton.
    local icons = layers_of(rr.variant)
    for _, l in ipairs(layers_of("fo-brass")) do
      l.scale = 0.25 * 64 / (l.icon_size or 64)
      l.shift = { -8, -8 }
      icons[#icons + 1] = l
    end
    r.icons = icons
    r.main_product = ""
  end
  out[#out + 1] = r
end

data:extend(out)

-- X3.extends : la verrerie (AMELIO-CRAFTS) débloque aussi la cornue, le laiton et le manomètre à tube de Bourdon.
local tech = assert(data.raw.technology[Z.EXTEND.tech], "zinc : technologie absente " .. Z.EXTEND.tech)
tech.effects = tech.effects or {}
for _, u in ipairs(Z.EXTEND.unlocks) do tech.effects[#tech.effects + 1] = lib.unlock(u) end
