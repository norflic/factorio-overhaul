-- Monde : biomes (tuiles), ressources à effets, objets, fluide, recettes associées.
-- Données : shared/content/world.lua.

local noise = require("noise")
local resource_autoplace = require("resource-autoplace")
local lib = require("prototypes.lib")
local W = require("shared.content.world")

local out = {}

---------------------------------------------------------------------------------------------------
-- Régions de biome : bruit multi-octave basse fréquence (taches de ~200 tuiles), conditionné au climat
-- (humidité, aux) et à l'altitude (jamais sous l'eau). Valeur dans [0, 1].
---------------------------------------------------------------------------------------------------
local region_layers = {}

local function region_mask(region)
  if not region_layers[region.seed] then
    region_layers[region.seed] = true
    out[#out + 1] = { type = "noise-layer", name = region.seed }
  end
  local n = noise.function_application("factorio-multioctave-noise", {
    x = noise.var("x"),
    y = noise.var("y"),
    persistence = 0.6,
    seed0 = noise.var("map_seed"),
    seed1 = noise.noise_layer_name_to_id(region.seed),
    input_scale = region.scale,
    output_scale = 1,
    octaves = 3,
  })
  local mask = noise.clamp((n - region.threshold) * 6, 0, 1)
  if region.moisture_max then mask = mask * noise.clamp((region.moisture_max - noise.var("moisture")) * 8, 0, 1) end
  if region.moisture_min then mask = mask * noise.clamp((noise.var("moisture") - region.moisture_min) * 8, 0, 1) end
  if region.aux_min then mask = mask * noise.clamp((noise.var("aux") - region.aux_min) * 8, 0, 1) end
  return mask * noise.clamp(noise.var("elevation") * 0.25, 0, 1)
end

local biome_by_name = {}
for _, b in ipairs(W.biomes) do biome_by_name[b.name] = b end

---------------------------------------------------------------------------------------------------
-- Tuiles de biome
---------------------------------------------------------------------------------------------------
for _, b in ipairs(W.biomes) do
  local tile = lib.copy("tile", b.copy_from)
  tile.name = b.name
  tile.order = "b[natural]-z[fo]-" .. b.name
  tile.layer = b.layer
  tile.tint = b.tint
  tile.map_color = b.map_color
  tile.walking_speed_modifier = b.walking_speed_modifier
  tile.vehicle_friction_modifier = b.vehicle_friction_modifier
  tile.pollution_absorption_per_second = b.pollution_absorption_per_second
  tile.localised_name = { "tile-name." .. b.name }
  tile.autoplace = { probability_expression = region_mask(b.region) * 4 - 2 }
  if b.effect_color then tile.effect_color = b.effect_color end
  if b.effect_color_secondary then tile.effect_color_secondary = b.effect_color_secondary end
  if b.no_splash then tile.trigger_effect = nil end
  if b.sound_from and data.raw.tile[b.sound_from] then
    tile.walking_sound = table.deepcopy(data.raw.tile[b.sound_from].walking_sound)
  end
  if b.ground then
    -- Texture d'eau peu profonde, mais terrain ferme : on y marche, on y construit, on y pose des gisements.
    tile.collision_mask = { "ground-tile" }
  end
  out[#out + 1] = tile
end

---------------------------------------------------------------------------------------------------
-- Décor des biomes : entités (roches, cristaux, arbres) et décoratifs placés sur la seule tuile du biome.
---------------------------------------------------------------------------------------------------
local function glow_layers(pictures, tint, glow)
  -- Chaque variante devient { couche teintée, même image en additif « draw_as_glow » } : luit la nuit.
  for i, v in ipairs(pictures) do
    local base = table.deepcopy(v)
    lib.tint_sprites(base, tint)
    if glow then
      local g = table.deepcopy(v)
      local function mark(sp)
        sp.tint = glow
        sp.blend_mode = "additive"
        sp.draw_as_glow = true
        if sp.hr_version then mark(sp.hr_version) end
      end
      mark(g)
      pictures[i] = { layers = { base, g } }
    else
      pictures[i] = base
    end
  end
end

local function decor_autoplace(order, density, tile)
  return {
    order = order,
    probability_expression = noise.to_noise_expression(density),
    tile_restriction = { tile },
  }
end

for _, b in ipairs(W.biomes) do
  local decor = W.decor and W.decor[b.name]
  if decor then
    for i, d in ipairs(decor.entities or {}) do
      local e = lib.copy(d.type, d.copy)
      e.name = d.name
      e.localised_name = { "entity-name." .. d.name }
      e.order = "z[fo]-" .. d.name
      e.autoplace = decor_autoplace("a[doodad]-z[fo]-" .. i, d.density, b.name)
      if d.type == "tree" then
        -- Arbres : variantes { trunk, leaves, shadow } ; on assombrit tronc et feuillage.
        for _, v in ipairs(e.variations or {}) do
          if v.trunk then lib.tint_sprites(v.trunk, d.tint) end
          if v.leaves then lib.tint_sprites(v.leaves, d.tint) end
        end
        if e.pictures then lib.tint_sprites(e.pictures, d.tint) end
        -- Les arbres à « variations » EXIGENT `colors` (moteur réel : « Key colors not found ») : on
        -- garde la palette vanilla du feuillage, assombrie par la teinte du biome.
        if e.colors then
          for _, c in ipairs(e.colors) do
            c.r, c.g, c.b = (c.r or 1) * d.tint.r, (c.g or 1) * d.tint.g, (c.b or 1) * d.tint.b
          end
        end
      else
        glow_layers(e.pictures, d.tint, d.glow)
      end
      if d.mined then
        local results = {}
        for _, r in ipairs(d.mined) do results[#results + 1] = { name = r[1], amount_min = math.floor(r[2] / 2), amount_max = r[2] } end
        e.minable = { mining_time = (e.minable and e.minable.mining_time) or 1, results = results }
      end
      lib.set_icons(e, { { icon = e.icon, icon_size = e.icon_size, icon_mipmaps = e.icon_mipmaps, tint = d.tint } })
      out[#out + 1] = e
    end
    for i, d in ipairs(decor.decoratives or {}) do
      local dec = lib.copy("optimized-decorative", d.copy)
      dec.name = d.name
      dec.order = "z[fo]-" .. d.name
      dec.autoplace = decor_autoplace("a[doodad]-z[fo]-d" .. i, d.density, b.name)
      glow_layers(dec.pictures, d.tint, d.glow)
      out[#out + 1] = dec
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Ressources solides : tungstène (dur) et cristal de résonance (combustible accélérateur)
---------------------------------------------------------------------------------------------------
out[#out + 1] = { type = "resource-category", name = "fo-hard-solid" }

local function tinted_item(name, copy_item, tint)
  local item = lib.copy("item", copy_item)
  item.name = name
  item.localised_name = { "item-name." .. name }
  item.localised_description = { "item-description." .. name }
  item.order = "z[fo]-" .. name
  local icon = item.icon
  local size = item.icon_size
  local mip = item.icon_mipmaps
  if item.pictures then
    lib.tint_sprites(item.pictures, tint)
  end
  lib.set_icons(item, { { icon = icon, icon_size = size, icon_mipmaps = mip, tint = tint } })
  return item
end

local function autoplace_control(name, order)
  return {
    type = "autoplace-control",
    name = name,
    localised_name = { "", "[entity=" .. name .. "] ", { "entity-name." .. name } },
    richness = true,
    order = "b-z-" .. order,
    category = "resource",
  }
end

---------------------------------------------------------------------------------------------------
-- Gisements liés à un biome.
-- Moteur réel (session 3, graine 20261020) : multiplier la probabilité par le masque du biome donnait
-- 0 gisement de tungstène et de cristal sur 1 174 chunks : les gisements vanilla sont placés sans tenir
-- compte du biome, puis presque tous effacés par le masque. Correction : dans le bruit "spot-noise" qui
-- choisit les centres de gisements, la FAVORABILITÉ devient le masque du biome (les centres tombent dans
-- le biome quand la région en contient), avec plus de points candidats et une graine propre.
---------------------------------------------------------------------------------------------------
local PATCH_SET_COUNT = "regular-resource-patch-set-count"

local function bind_spots_to_region(ap, mask, seed1)
  local seen, bound = {}, 0
  local function walk(node)
    if type(node) ~= "table" or seen[node] then return end
    seen[node] = true
    if node.type == "function-application" and node.function_name == "spot-noise" then
      local a = node.arguments
      a.spot_favorability_expression = noise.literal_expression(mask)
      a.candidate_spot_count = noise.to_noise_expression(96)
      a.skip_span = noise.to_noise_expression(1)   -- jeu de gisements propre : pas de partage avec vanilla
      a.skip_offset = noise.to_noise_expression(0)
      a.seed1 = noise.to_noise_expression(seed1)
      bound = bound + 1
    end
    for _, v in pairs(node) do walk(v) end
  end
  walk(ap.probability_expression)
  walk(ap.richness_expression)
  assert(bound > 0, "factorio-overhaul : spot-noise introuvable dans l'autoplace (resource-autoplace a changé ?)")
  ap.probability_expression = ap.probability_expression * mask
  return ap
end

--- Autoplace d'un gisement lié à un biome, sans toucher au placement des minerais vanilla : le compteur de
--- jeux de gisements partagé (skip_span des minerais vanilla) est restauré après coup.
local function biome_bound_autoplace(params, region, seed1)
  local counter = data.raw["noise-expression"][PATCH_SET_COUNT]
  local saved = counter and counter.expression
  local ap = resource_autoplace.resource_autoplace_settings(params)
  if counter then counter.expression = saved end
  return bind_spots_to_region(ap, region_mask(region), seed1)
end

local function solid_resource(spec, order)
  local res = lib.copy("resource", spec.copy_resource)
  res.name = spec.resource
  res.localised_name = { "entity-name." .. spec.resource }
  res.order = "a-b-z-" .. order
  res.category = spec.category
  res.map_color = spec.map_color
  res.mining_visualisation_tint = spec.tint
  res.minable = {
    mining_particle = res.minable.mining_particle,
    mining_time = spec.mining_time,
    result = spec.item,
  }
  local raw_stages = table.deepcopy(res.stages)
  lib.tint_sprites(res.stages, spec.tint)
  if spec.glint then
    -- Éclats : la texture du gisement LUI-MÊME, en additif, teintée et pulsée (même découpe, mêmes
    -- variantes). Mesuré sur les fichiers du jeu : la texture d'éclat de l'uranium est vert pur
    -- (0,45 ; 1 ; 0), aucune teinte n'en tire du bleu ou du violet (F38).
    local u = data.raw.resource["uranium-ore"]
    res.stages_effect = raw_stages
    lib.tint_sprites(res.stages_effect, spec.glint.tint)
    local function additive(t, seen)
      seen = seen or {}
      if type(t) ~= "table" or seen[t] then return end
      seen[t] = true
      if t.filename or t.filenames then t.blend_mode = "additive" end
      for _, v in pairs(t) do additive(v, seen) end
    end
    additive(res.stages_effect)
    res.effect_animation_period = spec.glint.period
    res.effect_animation_period_deviation = 1
    res.effect_darkness_multiplier = u.effect_darkness_multiplier
    res.min_effect_alpha = spec.glint.min
    res.max_effect_alpha = spec.glint.max
  elseif res.stages_effect then
    lib.tint_sprites(res.stages_effect, spec.tint)
  end
  lib.set_icons(res, { { icon = res.icon, icon_size = res.icon_size, icon_mipmaps = res.icon_mipmaps, tint = spec.tint } })

  res.autoplace = biome_bound_autoplace({
    name = spec.resource,
    order = "d",
    base_density = spec.autoplace.base_density,
    base_spots_per_km2 = spec.autoplace.base_spots_per_km2,
    has_starting_area_placement = false,
    random_spot_size_minimum = spec.autoplace.random_spot_size_minimum,
    random_spot_size_maximum = spec.autoplace.random_spot_size_maximum,
    regular_rq_factor_multiplier = 1,
  }, biome_by_name[spec.biome].region, spec.autoplace.seed1)
  return res
end

local tungsten = W.resources.tungsten
out[#out + 1] = autoplace_control(tungsten.resource, "a")
local tungsten_res = solid_resource(tungsten, "a")
out[#out + 1] = tungsten_res
out[#out + 1] = tinted_item(tungsten.item, tungsten.copy_icon, tungsten.tint)
out[#out + 1] = tinted_item(tungsten.plate.item, tungsten.plate.copy_icon, tungsten.tint)
out[#out + 1] = lib.recipe(tungsten.plate.item, { { tungsten.item, tungsten.plate.ore_per_plate } },
  tungsten.plate.item, 1, tungsten.plate.energy, { category = "smelting" })

local crystal = W.resources.crystal
out[#out + 1] = autoplace_control(crystal.resource, "b")
local crystal_res = solid_resource(crystal, "b")
out[#out + 1] = crystal_res
local crystal_item = tinted_item(crystal.item, crystal.copy_icon, crystal.tint)
crystal_item.fuel_value = crystal.fuel.value
crystal_item.fuel_category = crystal.fuel.category
crystal_item.fuel_acceleration_multiplier = crystal.fuel.acceleration
crystal_item.fuel_top_speed_multiplier = crystal.fuel.top_speed
crystal_item.fuel_emissions_multiplier = crystal.fuel.emissions
out[#out + 1] = crystal_item

---------------------------------------------------------------------------------------------------
-- Méthane : ressource fluide des marais, carburant de lance-flammes, craquable en gaz
---------------------------------------------------------------------------------------------------
local methane = W.resources.methane
local fluid = lib.copy("fluid", methane.copy_fluid)
fluid.name = methane.fluid
fluid.localised_name = { "fluid-name." .. methane.fluid }
fluid.base_color = methane.tint
fluid.flow_color = { r = math.min(1, methane.tint.r + 0.3), g = math.min(1, methane.tint.g + 0.1), b = math.min(1, methane.tint.b + 0.3) }
fluid.fuel_value = methane.fuel_value
fluid.order = "a[fluid]-z[fo-methane]"
lib.set_icons(fluid, { { icon = fluid.icon, icon_size = fluid.icon_size, icon_mipmaps = fluid.icon_mipmaps, tint = methane.tint } })
out[#out + 1] = fluid

local well = lib.copy("resource", methane.copy_resource)
well.name = methane.resource
well.localised_name = { "entity-name." .. methane.resource }
well.order = "a-b-z-c"
well.map_color = methane.map_color
well.minable.results = { { type = "fluid", name = methane.fluid, amount_min = 10, amount_max = 10, probability = 1 } }
lib.tint_sprites(well.stages, methane.tint)
lib.set_icons(well, { { icon = well.icon, icon_size = well.icon_size, icon_mipmaps = well.icon_mipmaps, tint = methane.tint } })
well.autoplace = biome_bound_autoplace({
  name = methane.resource,
  order = "d",
  base_density = methane.autoplace.base_density,
  base_spots_per_km2 = methane.autoplace.base_spots_per_km2,
  random_probability = methane.autoplace.random_probability,
  random_spot_size_minimum = 1,
  random_spot_size_maximum = 1,
  additional_richness = methane.autoplace.additional_richness,
  has_starting_area_placement = false,
  regular_rq_factor_multiplier = 1,
}, biome_by_name[methane.biome].region, methane.autoplace.seed1)
out[#out + 1] = well
out[#out + 1] = autoplace_control(methane.resource, "c")

out[#out + 1] = {
  type = "recipe",
  name = "fo-methane-cracking",
  category = "chemistry",
  enabled = false,
  energy_required = methane.cracking.energy,
  ingredients = { { type = "fluid", name = methane.fluid, amount = methane.cracking.methane } },
  results = { { type = "fluid", name = "petroleum-gas", amount = methane.cracking.petroleum } },
  main_product = "petroleum-gas",
  subgroup = "fluid-recipes",
  order = "z[fo]-a[methane-cracking]",
  icons = { { icon = fluid.icons[1].icon, icon_size = fluid.icons[1].icon_size, icon_mipmaps = fluid.icons[1].icon_mipmaps, tint = methane.tint } },
}

---------------------------------------------------------------------------------------------------
-- Technologies
---------------------------------------------------------------------------------------------------
local tech_tungsten = data.raw.technology["advanced-material-processing"]
out[#out + 1] = lib.technology({
  name = "fo-tungsten-processing",
  icons = { { icon = tech_tungsten.icon, icon_size = tech_tungsten.icon_size, icon_mipmaps = tech_tungsten.icon_mipmaps, tint = tungsten.tint } },
  effects = { lib.unlock(tungsten.plate.item) },
  prerequisites = { "advanced-material-processing", "electric-energy-distribution-1" },
  count = 150,
  packs = { "automation-science-pack", "logistic-science-pack" },
  time = 30,
  order = "c-c-z[fo-tungsten]",
})
local tech_oil = data.raw.technology["advanced-oil-processing"]
out[#out + 1] = lib.technology({
  name = "fo-methane-processing",
  icons = { { icon = tech_oil.icon, icon_size = tech_oil.icon_size, icon_mipmaps = tech_oil.icon_mipmaps, tint = methane.tint } },
  effects = { lib.unlock("fo-methane-cracking") },
  prerequisites = { "oil-processing" },
  count = 100,
  packs = { "automation-science-pack", "logistic-science-pack" },
  time = 30,
  order = "d-a-z[fo-methane]",
})

data:extend(out)
