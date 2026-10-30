-- Lot X3-MINERAIS (30/10) : la fonderie de puces d'X3 (chaîne A, âge 10) en jeu : objets, résine photosensible, tireuse de
-- cristal et lithographe à cristal au visuel PROVISOIRE, recettes, technologie. Données : shared/content/quartz.lua. Le
-- gisement et le minerai de quartz filonien : prototypes/world.lua (W.resources.quartz). À charger APRÈS prototypes/crafts.lua
-- (verre, four à arc, taillerie, salle blanche, silicium), prototypes/tin.lua (résine époxy, carte imprimée) et
-- prototypes/bauxite.lua (aluminium).

local lib = require("prototypes.lib")
local Q = require("shared.content.quartz")
local W = require("shared.content.world")

local out = {}
local TINT = W.resources.quartz.tint

out[#out + 1] = { type = "item-subgroup", name = "fo-quartz", group = "intermediate-products", order = "z[fo]-i[quartz]" }
out[#out + 1] = { type = "item-subgroup", name = "fo-quartz-machines", group = "production", order = "z[fo]-i[quartz]" }

-- Icônes PROVISOIRES (copies vanilla teintées : une teinte ne fait que multiplier, F36, F38 ; sources claires choisies).
local ICON = {
  ["fo-quartz-crucible"] = { "item", "stone-brick", { r = 1.00, g = 1.00, b = 1.00 } },
  ["fo-silicon-ingot"] = { "item", "steel-plate", { r = 0.70, g = 0.74, b = 0.86 } },
  ["fo-photomask"] = { "item", "solar-panel", { r = 0.80, g = 0.92, b = 1.00 } },
  ["fo-etched-wafer"] = { "item", "processing-unit", { r = 0.78, g = 0.86, b = 1.00 } },
  ["fo-crystal-laser"] = { "item", "laser-turret", { r = 0.70, g = 0.90, b = 1.00 } },
}
local FLUID_TINT = { ["fo-photoresist"] = { r = 0.90, g = 0.55, b = 0.20 } }

local function icon_of(ptype, name, tint)
  local src = assert(data.raw[ptype][name], "quartz : icône source absente " .. ptype .. "/" .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

for i, name in ipairs(Q.ITEMS) do
  local x = assert(Q.x3_item(name), "quartz : objet X3 absent " .. name)
  local ic = ICON[name]
  local item = {
    type = "item", name = name,
    localised_name = { "item-name." .. name }, localised_description = { "item-description." .. name },
    icons = icon_of(ic[1], ic[2], ic[3]), subgroup = "fo-quartz", order = string.format("z[fo]-i[quartz]-%02d", i),
    stack_size = x.stack,
  }
  out[#out + 1] = item
end

for i, name in ipairs(Q.FLUIDS) do
  local f = lib.copy("fluid", "heavy-oil")
  local tint = FLUID_TINT[name]
  f.name = name
  f.localised_name = { "fluid-name." .. name }
  f.base_color = { r = tint.r * 0.6, g = tint.g * 0.6, b = tint.b * 0.6 }
  f.flow_color = tint
  f.fuel_value = nil
  f.order = "a[fluid]-z[fo]-i[quartz]-" .. i
  lib.set_icons(f, { { icon = f.icon, icon_size = f.icon_size, icon_mipmaps = f.icon_mipmaps, tint = tint } })
  out[#out + 1] = f
end

---------------------------------------------------------------------------------------------------
-- Bâtiments : stats d'X3 (côté, kW, catégories, entrées de fluide), visuel PROVISOIRE (centrifugeuse et assembleur 3 teintés,
-- mis à l'échelle du côté d'X3, comme la cuve d'électrolyse de la piste BAUXITE).
---------------------------------------------------------------------------------------------------
local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }

local function machine(spec)
  local x = Q.building(spec.name)
  for _, c in ipairs(x.categories) do
    if not data.raw["recipe-category"][c] then out[#out + 1] = { type = "recipe-category", name = c } end
  end
  local e = lib.copy(spec.copy[1], spec.copy[2])
  local side = x.size[1]
  local h = side / 2
  local src_boxes = e.fluid_boxes
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
  e.fixed_recipe = nil
  local k = side / spec.side
  for _, key in ipairs(VISUAL_KEYS) do
    if e[key] then
      if k ~= 1 then lib.scale_sprites(e[key], k) end
      lib.tint_sprites(e[key], spec.tint)
    end
  end
  -- Entrées de fluide (X3 : fluid_in) : la première boîte d'entrée de la machine copiée, une par entrée, raccords au milieu
  -- du bord nord puis du bord sud (côté pair : x = -0,5 et 0,5 ; impair : 0), juste hors de l'emprise.
  e.fluid_boxes = nil
  if (x.fluid_in or 0) > 0 then
    local fb = nil
    for _, b in ipairs(src_boxes or {}) do
      if type(b) == "table" and b.production_type == "input" and not fb then fb = b end
    end
    assert(fb, "quartz : boîte d'entrée absente de " .. spec.copy[2])
    local edge = h + 0.5
    local mid = (side % 2 == 0) and 0.5 or 0
    local spots = { { -mid, -edge }, { mid, edge } }
    local boxes = { off_when_no_fluid_recipe = true }
    for i = 1, x.fluid_in do
      local b = table.deepcopy(fb)
      b.pipe_connections = { { type = "input", position = spots[i] } }
      boxes[#boxes + 1] = b
    end
    e.fluid_boxes = boxes
  end
  lib.set_icons(e, icon_of("item", spec.copy[2], spec.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item", name = spec.name,
    localised_name = { "entity-name." .. spec.name }, localised_description = { "entity-description." .. spec.name },
    icons = icon_of("item", spec.copy[2], spec.tint), subgroup = "fo-quartz-machines", order = "z[fo]-i[quartz]-" .. spec.name,
    place_result = spec.name, stack_size = 10,
  }
end

for _, spec in ipairs(Q.BUILDINGS) do machine(spec) end

---------------------------------------------------------------------------------------------------
-- Recettes (celles d'X3) ; la recette de chaque bâtiment aussi.
---------------------------------------------------------------------------------------------------
local function is_fluid(n)
  local f = Q.is_fluid(n)
  if f ~= nil then return f end
  return data.raw.fluid[n] ~= nil and data.raw.item[n] == nil
end
local function ingredient(n, a) return { type = is_fluid(n) and "fluid" or "item", name = n, amount = a } end

local own = {}
for _, p in ipairs(out) do if p.type == "item" then own[p.name] = p end end
local function icons_of_item(n)
  local p = own[n] or data.raw.item[n]
  assert(p, "quartz : icône absente " .. n)
  if p.icons then return table.deepcopy(p.icons) end
  return { { icon = p.icon, icon_size = p.icon_size, icon_mipmaps = p.icon_mipmaps } }
end
-- Marque d'une variante : l'ingrédient nouveau de la voie (lingot pour les tranches sciées, tranche gravée pour le processeur).
local MARK = { ["fo-wafer-sawing"] = "fo-silicon-ingot", ["fo-etched-processor"] = "fo-etched-wafer" }

for i, rr in ipairs(Q.all_recipes()) do
  local x = Q.recipe(rr.name)
  local ings, res = {}, {}
  for _, g in ipairs(x.ingredients) do ings[#ings + 1] = ingredient(g[1], g[2]) end
  for _, p in ipairs(x.results) do res[#res + 1] = ingredient(p[1], p[2]) end
  local r = {
    type = "recipe", name = x.name, category = x.category, enabled = false, energy_required = x.time,
    ingredients = ings, results = res, main_product = res[1].name,
    subgroup = rr.building and "fo-quartz-machines" or "fo-quartz",
    order = string.format("z[fo]-i[quartz]-r%02d", i), allow_decomposition = not rr.variant,
  }
  if x.fr and not rr.building then r.localised_name = { "recipe-name." .. x.name } end
  if rr.variant then
    r.localised_name = { "recipe-name." .. x.name }
    local icons = icons_of_item(rr.variant)
    for _, l in ipairs(icons_of_item(MARK[rr.name])) do
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
-- Technologie
---------------------------------------------------------------------------------------------------
local src = data.raw.technology["advanced-electronics-2"]
for _, t in ipairs(Q.TECHS) do
  local effects = {}
  for _, u in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(u) end
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = TINT } },
    effects = effects, prerequisites = t.prerequisites, count = Q.tech_count(t), packs = Q.packs(t.epoch), time = t.time,
    order = "z[fo]-i[quartz]-" .. t.name,
  })
end

data:extend(out)

-- Modules de productivité (relecture du 30/10) : les recettes « prod » d'X3 du lot (lithographie, processeur gravé) sont
-- ajoutées à la limitation des modules vanilla, que data-final-fixes.lua recopie vers les modules du mod (même règle que
-- prototypes/crafts.lua ; aucune n'est réversible).
for _, mname in ipairs({ "productivity-module", "productivity-module-2", "productivity-module-3" }) do
  local m = data.raw.module[mname]
  if m and type(m.limitation) == "table" then
    local present = {}
    for _, r in ipairs(m.limitation) do present[r] = true end
    for _, r in ipairs(Q.productivity_recipes()) do
      if not present[r] then m.limitation[#m.limitation + 1] = r; present[r] = true end
    end
  end
end
