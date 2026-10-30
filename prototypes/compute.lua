-- Lot CALCUL (30/10) : la chaîne du calcul par étapes (puces, processeur, mémoire, carte mère, baies, carte graphique,
-- processeur quantique) et le CENTRE DE CALCUL. Données : shared/content/compute.lua ; le calcul lui-même est tenu par
-- script (script/compute/compute.lua, D-20 (4)). Visuels et icônes PROVISOIRES : copies vanilla teintées (une teinte ne
-- fait que multiplier, F36, F38), en attendant les modèles comparés au vanilla (lot CALC-D).
-- À charger APRÈS prototypes/crafts.lua (salle blanche, taillerie, verre, silicium), prototypes/tin.lua (carte imprimée,
-- résine époxy, imprimante de circuits), prototypes/bauxite.lua (aluminium) et prototypes/superconductors.lua (cryostat,
-- bande supraconductrice, unité cryogénique, four de frittage).

local lib = require("prototypes.lib")
local Cp = require("shared.content.compute")

local out = {}

out[#out + 1] = { type = "item-subgroup", name = "fo-compute", group = "intermediate-products", order = "z[fo]-j[compute]" }
out[#out + 1] = { type = "item-subgroup", name = "fo-compute-machines", group = "production", order = "z[fo]-j[compute]" }
for _, c in ipairs(Cp.NEW_CATEGORIES) do
  if not data.raw["recipe-category"][c] then out[#out + 1] = { type = "recipe-category", name = c } end
end

-- Icônes PROVISOIRES : { type, nom vanilla, teinte }.
local ICON = {
  ["fo-photomask"] = { "item", "solar-panel", { r = 0.80, g = 0.92, b = 1.00 } },
  ["fo-etched-wafer"] = { "item", "processing-unit", { r = 0.78, g = 0.86, b = 1.00 } },
  ["fo-crystal-laser"] = { "item", "laser-turret", { r = 0.70, g = 0.90, b = 1.00 } },
  ["fo-logic-die"] = { "item", "processing-unit", { r = 1.00, g = 0.85, b = 0.45 } },
  ["fo-dram-die"] = { "item", "advanced-circuit", { r = 0.55, g = 1.00, b = 0.80 } },
  ["fo-sram-die"] = { "item", "advanced-circuit", { r = 0.85, g = 0.60, b = 1.00 } },
  ["fo-heat-sink"] = { "item", "heat-pipe", { r = 0.90, g = 0.92, b = 1.00 } },
  ["fo-memory-module"] = { "item", "electronic-circuit", { r = 0.45, g = 0.95, b = 0.55 } },
  ["fo-motherboard"] = { "item", "advanced-circuit", { r = 0.40, g = 0.75, b = 0.45 } },
  ["fo-server-blade"] = { "item", "beacon", { r = 0.60, g = 0.65, b = 0.85 } },
  ["fo-graphics-card"] = { "item", "processing-unit", { r = 1.00, g = 0.45, b = 0.40 } },
  ["fo-gpu-blade"] = { "item", "beacon", { r = 0.95, g = 0.55, b = 0.50 } },
  ["fo-degassed-ilmenite"] = { "item", "stone", { r = 0.55, g = 0.50, b = 0.52 } },
  ["fo-qubit-chip"] = { "item", "processing-unit", { r = 0.40, g = 1.00, b = 1.00 } },
  ["fo-dilution-stage"] = { "item", "accumulator", { r = 0.75, g = 0.95, b = 1.00 } },
  ["fo-quantum-processor"] = { "item", "processing-unit", { r = 1.00, g = 0.45, b = 1.00 } },
}
local FLUID = {
  ["fo-photoresist"] = { "heavy-oil", { r = 0.90, g = 0.55, b = 0.20 } },
  ["fo-helium-3"] = { "petroleum-gas", { r = 0.95, g = 0.95, b = 0.60 } },
}

local function icon_of(ptype, name, tint)
  local src = assert(data.raw[ptype][name], "calcul : icône source absente " .. ptype .. "/" .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

for i, it in ipairs(Cp.ITEMS) do
  local ic = ICON[it.name]
  out[#out + 1] = {
    type = "item", name = it.name,
    localised_name = { "item-name." .. it.name }, localised_description = { "item-description." .. it.name },
    icons = icon_of(ic[1], ic[2], ic[3]), subgroup = "fo-compute", order = string.format("z[fo]-j[compute]-%02d", i),
    stack_size = it.stack,
  }
end

for i, fl in ipairs(Cp.FLUIDS) do
  local spec = FLUID[fl.name]
  local f = lib.copy("fluid", spec[1])
  local tint = spec[2]
  f.name = fl.name
  f.localised_name = { "fluid-name." .. fl.name }
  f.base_color = { r = tint.r * 0.6, g = tint.g * 0.6, b = tint.b * 0.6 }
  f.flow_color = tint
  f.fuel_value = nil
  f.auto_barrel = false
  f.order = "a[fluid]-z[fo]-j[compute]-" .. i
  lib.set_icons(f, { { icon = f.icon, icon_size = f.icon_size, icon_mipmaps = f.icon_mipmaps, tint = tint } })
  out[#out + 1] = f
end

---------------------------------------------------------------------------------------------------
-- Bâtiments : lithographe (X3) et centre de calcul (plan). Copie teintée de l'assembleur 3, mise à l'échelle 4 × 4.
---------------------------------------------------------------------------------------------------
local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }

local function machine(name)
  local x = Cp.building(name)
  local spec = x.spec
  local e = lib.copy("assembling-machine", spec.copy)
  local side = x.size[1]
  local h = side / 2
  local src_boxes = e.fluid_boxes
  e.name = name
  e.localised_name = { "entity-name." .. name }
  e.localised_description = { "entity-description." .. name }
  e.minable = { mining_time = 0.5, result = name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  e.crafting_categories = {}
  for _, c in ipairs(x.categories) do e.crafting_categories[#e.crafting_categories + 1] = c end
  e.crafting_speed = x.speed
  e.energy_usage = x.kw .. "kW"
  e.energy_source = { type = "electric", usage_priority = "secondary-input", emissions_per_minute = 4 }
  e.collision_box = { { -h + 0.3, -h + 0.3 }, { h - 0.3, h - 0.3 } }
  e.selection_box = { { -h, -h }, { h, h } }
  e.drawing_box = nil
  e.water_reflection = nil
  e.fixed_recipe = nil
  if name == "fo-data-center" then
    -- Le centre ne prend aucun module : son calcul se lit par script, à la vitesse nominale (D-20 (4)).
    e.module_specification = { module_slots = 0 }
    e.allowed_effects = {}
  end
  local k = side / spec.side
  for _, key in ipairs(VISUAL_KEYS) do
    if e[key] then
      if k ~= 1 then lib.scale_sprites(e[key], k) end
      lib.tint_sprites(e[key], spec.tint)
    end
  end
  -- Entrées de fluide : la première boîte d'entrée de la machine copiée, une par entrée ; raccords au milieu du bord nord
  -- puis du bord sud (côté pair : x = -0,5 et 0,5), juste hors de l'emprise.
  e.fluid_boxes = nil
  if x.fluid_in > 0 then
    local fb
    for _, b in ipairs(src_boxes or {}) do
      if type(b) == "table" and b.production_type == "input" and not fb then fb = b end
    end
    assert(fb, "calcul : boîte d'entrée absente de " .. spec.copy)
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
  lib.set_icons(e, icon_of("item", spec.copy, spec.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item", name = name,
    localised_name = { "entity-name." .. name }, localised_description = { "entity-description." .. name },
    icons = icon_of("item", spec.copy, spec.tint), subgroup = "fo-compute-machines", order = "z[fo]-j[compute]-" .. name,
    place_result = name, stack_size = 10,
  }
end

for _, b in ipairs(Cp.BUILDINGS) do machine(b.name) end

---------------------------------------------------------------------------------------------------
-- Recettes
---------------------------------------------------------------------------------------------------
local function ingredient(n, a) return { type = Cp.is_fluid(n) and "fluid" or "item", name = n, amount = a } end

local own = {}
for _, p in ipairs(out) do if p.type == "item" or p.type == "fluid" then own[p.name] = p end end
local function icons_of(n)
  local p = own[n] or data.raw.item[n] or data.raw.fluid[n]
  assert(p, "calcul : icône absente " .. n)
  if p.icons then return table.deepcopy(p.icons) end
  return { { icon = p.icon, icon_size = p.icon_size, icon_mipmaps = p.icon_mipmaps } }
end
local function with_mark(base, mark)
  local icons = icons_of(base)
  for _, l in ipairs(icons_of(mark)) do
    l.scale = 0.5 * 32 / (l.icon_size or 64)
    l.shift = { 8, 8 }
    icons[#icons + 1] = l
  end
  return icons
end

local function recipe(x, i, building)
  local ings, res = {}, {}
  for _, g in ipairs(x.ingredients) do ings[#ings + 1] = ingredient(g[1], g[2]) end
  for _, p in ipairs(x.results) do res[#res + 1] = ingredient(p[1], p[2]) end
  local r = {
    type = "recipe", name = x.name, category = x.category, enabled = false, energy_required = x.time,
    ingredients = ings, results = res,
    subgroup = building and "fo-compute-machines" or "fo-compute",
    order = string.format("z[fo]-j[compute]-r%02d", i), allow_decomposition = not x.variant,
  }
  if #res >= 1 then r.main_product = res[1].name end
  if x.variant then
    -- Variante d'un objet vanilla : icône du produit + la puce logique dans le coin ; nom propre.
    r.localised_name = { "recipe-name." .. x.name }
    r.icons = with_mark(x.variant, "fo-logic-die")
    r.main_product = ""
  elseif #res == 0 then
    -- Recette du centre (aucun produit) : icône de la baie + le centre dans le coin.
    r.localised_name = { "recipe-name." .. x.name }
    r.localised_description = { "recipe-description." .. x.name }
    r.icons = with_mark(x.ingredients[1][1], "fo-data-center")
    r.hide_from_player_crafting = true
  elseif #res > 1 then
    r.localised_name = { "recipe-name." .. x.name }
  end
  return r
end

for i, x in ipairs(Cp.all_recipes()) do out[#out + 1] = recipe(x, i, false) end
for i, x in ipairs(Cp.building_recipes()) do out[#out + 1] = recipe(x, 50 + i, true) end

---------------------------------------------------------------------------------------------------
-- Technologies (icônes PROVISOIRES : technologies vanilla teintées)
---------------------------------------------------------------------------------------------------
local TECH_ICON = {
  ["fo-chip-foundry"] = { "advanced-electronics-2", { r = 0.78, g = 0.86, b = 1.00 } },
  ["fo-data-centers"] = { "research-speed-1", { r = 0.60, g = 0.70, b = 1.00 } },
  ["fo-gpu-computing"] = { "advanced-electronics-2", { r = 1.00, g = 0.55, b = 0.50 } },
  ["fo-regolith-degassing"] = { "nuclear-power", { r = 0.95, g = 0.95, b = 0.60 } },
  ["fo-quantum-computing"] = { "advanced-electronics-2", { r = 1.00, g = 0.50, b = 1.00 } },
}
for _, t in ipairs(Cp.TECHS) do
  local effects = {}
  for _, u in ipairs(t.unlocks) do effects[#effects + 1] = lib.unlock(u) end
  local ti = TECH_ICON[t.name]
  local src = assert(data.raw.technology[ti[1]], "calcul : technologie source absente " .. ti[1])
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = (function()
      if src.icons then
        local l = table.deepcopy(src.icons)
        for _, layer in ipairs(l) do layer.tint = ti[2] end
        return l
      end
      return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = ti[2] } }
    end)(),
    effects = effects, prerequisites = t.prerequisites, count = Cp.tech_count(t), packs = Cp.packs(t.epoch), time = t.time,
    order = "z[fo]-j[compute]-" .. t.name,
  })
end

data:extend(out)

-- Modules de productivité : les recettes « prod » du lot (puces, processeur gravé, mémoire, carte mère, cartes graphiques,
-- puces à qubits), jamais une recette de bâtiment ni de calcul ; data-final-fixes.lua les recopie vers les modules du mod.
for _, mname in ipairs({ "productivity-module", "productivity-module-2", "productivity-module-3" }) do
  local m = data.raw.module[mname]
  if m and type(m.limitation) == "table" then
    local present = {}
    for _, r in ipairs(m.limitation) do present[r] = true end
    for _, r in ipairs(Cp.productivity_recipes()) do
      if not present[r] then m.limitation[#m.limitation + 1] = r; present[r] = true end
    end
  end
end
