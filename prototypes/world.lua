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
  -- Lot X1-TITANE : une région NEUVE prend une graine NUMÉRIQUE (region.seed1) : une noise-layer de plus décalerait les
  -- couches de bruit existantes et changerait la forêt vanilla partout (F198). Les trois régions d'avant gardent leur
  -- noise-layer nommée (sinon leurs biomes changeraient de place).
  local seed1
  if region.seed1 then
    seed1 = noise.to_noise_expression(region.seed1)
  else
    if not region_layers[region.seed] then
      region_layers[region.seed] = true
      out[#out + 1] = { type = "noise-layer", name = region.seed }
    end
    seed1 = noise.noise_layer_name_to_id(region.seed)
  end
  local n = noise.function_application("factorio-multioctave-noise", {
    x = noise.var("x"),
    y = noise.var("y"),
    persistence = 0.6,
    seed0 = noise.var("map_seed"),
    seed1 = seed1,
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

---------------------------------------------------------------------------------------------------
-- Grain fin des frontières (lot B0, verdict du DC « B3 B ») : le MÊME bruit que celui que vanilla ajoute à chaque sol
-- naturel (base/prototypes/tile/tiles.lua, noise_layer_expression : échelle 1/6, influence 2/3, persistance 0,7,
-- 4 octaves). Seulement dans la probabilité de la TUILE : le masque des régions, qui place les gisements liés au biome
-- (bind_spots_to_region), reste celui d'avant.
-- Graine NUMÉRIQUE (W.grain.seed1), PAS de nouveau prototype noise-layer : moteur réel (lot B0, 24/10), trois
-- noise-layer de plus (« fo-grain-* ») ont changé la forêt vanilla partout (arbres +15 % à 400 tuiles du départ, sur
-- toutes les tuiles) : les numéros des couches de bruit existantes se décalent (F198 proposé).
---------------------------------------------------------------------------------------------------
local function tile_grain(b)
  local seed1 = W.grain.seed1[b.name]
  assert(seed1, "factorio-overhaul : graine du grain fin absente pour " .. b.name)
  return noise.function_application("factorio-multioctave-noise", {
    x = noise.var("x"),
    y = noise.var("y"),
    persistence = W.grain.persistence,
    seed0 = noise.var("map_seed"),
    seed1 = noise.to_noise_expression(seed1),
    input_scale = noise.fraction(1, W.grain.period),
    output_scale = W.grain.influence,
    octaves = W.grain.octaves,
  })
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
  local p = region_mask(b.region) * 4 - 2
  if W.grain then p = p + tile_grain(b) end
  tile.autoplace = { probability_expression = p }
  if b.texture then
    -- Image recolorée (lot B0) : on ne remplace que les fichiers de la texture ; découpe, variantes, masques et
    -- transitions restent ceux de la tuile vanilla copiée (bords irréguliers comme les sols vanilla).
    local swapped = 0
    local seen = {}
    local function swap(t)
      if type(t) ~= "table" or seen[t] then return end
      seen[t] = true
      if type(t.picture) == "string" and b.texture[t.picture] then
        t.picture = b.texture[t.picture]
        swapped = swapped + 1
      end
      for _, v in pairs(t) do swap(v) end
    end
    swap(tile.variants)
    assert(swapped > 0, "factorio-overhaul : texture de " .. b.name .. " introuvable dans " .. b.copy_from)
  end
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
-- Aucun décor VANILLA sur certains biomes (lot B0, verdict du DC « B4 B » : touffes vertes et plaques brunes retirées
-- de la plaine de cristal). Les décoratifs vanilla placés à la génération sans restriction de tuile reçoivent la liste
-- des tuiles naturelles SAUF ces biomes ; ceux qui ont déjà une liste en perdent ces biomes. Les décors du mod
-- (« fo-* », W.decor) ne sont pas touchés.
---------------------------------------------------------------------------------------------------
if W.no_vanilla_decor and #W.no_vanilla_decor > 0 then
  local banned = {}
  for _, n in ipairs(W.no_vanilla_decor) do banned[n] = true end
  local allowed = {}
  for name, t in pairs(data.raw.tile) do
    if t.autoplace and not banned[name] then allowed[#allowed + 1] = name end
  end
  for _, b in ipairs(W.biomes) do
    if not banned[b.name] then allowed[#allowed + 1] = b.name end
  end
  table.sort(allowed)
  local names = {}
  for name, d in pairs(data.raw["optimized-decorative"]) do
    if d.autoplace and not name:find("^fo%-") then names[#names + 1] = name end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local ap = data.raw["optimized-decorative"][name].autoplace
    if ap.tile_restriction then
      local kept = {}
      for _, t in ipairs(ap.tile_restriction) do
        if type(t) ~= "string" or not banned[t] then kept[#kept + 1] = t end
      end
      ap.tile_restriction = kept
    else
      ap.tile_restriction = table.deepcopy(allowed)
    end
  end
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
--- Masque de DISTANCE (lot AMELIO-RESSOURCES, galène : « à plus de 300 tuiles du départ », sans biome) : 0 avant
--- distance_min, 1 au-delà de distance_min + 64 tuiles ; jamais sous l'eau (même facteur d'altitude que region_mask).
local function distance_mask(distance_min)
  return noise.clamp((noise.var("distance") - distance_min) / 64, 0, 1) * noise.clamp(noise.var("elevation") * 0.25, 0, 1)
end

local function biome_bound_autoplace(params, region, seed1, mask)
  local counter = data.raw["noise-expression"][PATCH_SET_COUNT]
  local saved = counter and counter.expression
  local ap = resource_autoplace.resource_autoplace_settings(params)
  if counter then counter.expression = saved end
  return bind_spots_to_region(ap, mask or region_mask(region), seed1)
end

--- Région de placement d'une ressource : son biome, ou (sans biome) le masque de distance.
local function resource_region(spec)
  if spec.biome then return biome_by_name[spec.biome].region, nil end
  assert(spec.autoplace.distance_min, "factorio-overhaul : ressource sans biome ni distance_min : " .. spec.resource)
  return nil, distance_mask(spec.autoplace.distance_min)
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
  if spec.sheet then
    -- Feuille de gisement PROPRE (lot M1, kit tools/render/pieces/ressources) : format exact des minerais vanilla
    -- (8 variantes × 8 stades, cadre 64 px et hr 128 px), sans teinte ; couche d'effet additive facultative.
    local sh = spec.sheet
    local function feuille(suffixe, additif)
      local function def(prefix, size, scale)
        local t = { filename = sh.dir .. "/" .. prefix .. sh.name .. suffixe .. ".png", priority = "extra-high", size = size,
                    frame_count = 8, variation_count = 8, scale = scale }
        if additif then
          -- comme hr-uranium-ore-glow.png (data/base/prototypes/entity/resources.lua)
          t.blend_mode = "additive"
          t.flags = { "light" }
        end
        return t
      end
      local t = def("", 64, nil)
      t.hr_version = def("hr-", 128, 0.5)
      return { sheet = t }
    end
    res.stages = feuille("", false)
    res.stage_counts = sh.stage_counts or res.stage_counts
    res.mining_visualisation_tint = sh.mining_visualisation_tint or res.mining_visualisation_tint
    if sh.effet then
      res.stages_effect = feuille("-effet", true)
      res.effect_animation_period = sh.effet.period
      res.effect_animation_period_deviation = sh.effet.deviation or 1
      res.effect_darkness_multiplier = sh.effet.darkness_multiplier
      res.min_effect_alpha = sh.effet.min
      res.max_effect_alpha = sh.effet.max
    else
      res.stages_effect = nil
    end
    res.icon, res.icon_size, res.icon_mipmaps, res.icons = sh.dir .. "/icone.png", 64, 4, nil
  else
    -- Visuel d'avant M1 (teinte d'une copie vanilla) : cristal (M3 le remplacera par une feuille propre).
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
  end

  local region, mask = resource_region(spec)
  res.autoplace = biome_bound_autoplace({
    name = spec.resource,
    order = "d",
    base_density = spec.autoplace.base_density,
    base_spots_per_km2 = spec.autoplace.base_spots_per_km2,
    has_starting_area_placement = false,
    random_spot_size_minimum = spec.autoplace.random_spot_size_minimum,
    random_spot_size_maximum = spec.autoplace.random_spot_size_maximum,
    regular_rq_factor_multiplier = 1,
  }, region, spec.autoplace.seed1, mask)
  return res
end

--- Minerai (kind = "ore") : contrôle d'autoplacement, gisement, objet du minerai (combustible si spec.fuel),
--- plaque et sa recette au four (si spec.plate).
local function ore_prototypes(spec, letter)
  out[#out + 1] = autoplace_control(spec.resource, letter)
  out[#out + 1] = solid_resource(spec, letter)
  local item = tinted_item(spec.item, spec.copy_icon, spec.tint)
  if spec.sheet then
    -- Icône et images au sol de la feuille M1 (format des minerais vanilla : 64 px + 3 mipmaps, 4 images).
    local dir = spec.sheet.dir
    item.icons = nil
    item.icon, item.icon_size, item.icon_mipmaps = dir .. "/icone.png", 64, 4
    item.pictures = {
      { size = 64, filename = dir .. "/icone.png", scale = 0.25, mipmap_count = 4 },
      { size = 64, filename = dir .. "/icone-1.png", scale = 0.25, mipmap_count = 4 },
      { size = 64, filename = dir .. "/icone-2.png", scale = 0.25, mipmap_count = 4 },
      { size = 64, filename = dir .. "/icone-3.png", scale = 0.25, mipmap_count = 4 },
    }
  end
  if spec.fuel then
    item.fuel_value = spec.fuel.value
    item.fuel_category = spec.fuel.category
    item.fuel_acceleration_multiplier = spec.fuel.acceleration
    item.fuel_top_speed_multiplier = spec.fuel.top_speed
    item.fuel_emissions_multiplier = spec.fuel.emissions
  end
  out[#out + 1] = item
  if spec.plate then
    out[#out + 1] = tinted_item(spec.plate.item, spec.plate.copy_icon, spec.tint)
    out[#out + 1] = lib.recipe(spec.plate.item, { { spec.item, spec.plate.ore_per_plate } },
      spec.plate.item, 1, spec.plate.energy, { category = "smelting" })
  end
end

--- Fluide (kind = "fluid") : fluide, puits (sortie de fluide liée au biome), contrôle d'autoplacement, recette de
--- craquage (si spec.cracking).
local function fluid_prototypes(spec, key, letter)
  local fluid = lib.copy("fluid", spec.copy_fluid)
  fluid.name = spec.fluid
  fluid.localised_name = { "fluid-name." .. spec.fluid }
  fluid.base_color = spec.tint
  fluid.flow_color = { r = math.min(1, spec.tint.r + 0.3), g = math.min(1, spec.tint.g + 0.1), b = math.min(1, spec.tint.b + 0.3) }
  fluid.fuel_value = spec.fuel_value
  fluid.order = "a[fluid]-z[" .. spec.fluid .. "]"
  lib.set_icons(fluid, { { icon = fluid.icon, icon_size = fluid.icon_size, icon_mipmaps = fluid.icon_mipmaps, tint = spec.tint } })
  out[#out + 1] = fluid

  local well = lib.copy("resource", spec.copy_resource)
  well.name = spec.resource
  well.localised_name = { "entity-name." .. spec.resource }
  well.order = "a-b-z-" .. letter
  well.map_color = spec.map_color
  well.minable.results = { { type = "fluid", name = spec.fluid, amount_min = 10, amount_max = 10, probability = 1 } }
  lib.tint_sprites(well.stages, spec.tint)
  lib.set_icons(well, { { icon = well.icon, icon_size = well.icon_size, icon_mipmaps = well.icon_mipmaps, tint = spec.tint } })
  well.autoplace = biome_bound_autoplace({
    name = spec.resource,
    order = "d",
    base_density = spec.autoplace.base_density,
    base_spots_per_km2 = spec.autoplace.base_spots_per_km2,
    random_probability = spec.autoplace.random_probability,
    random_spot_size_minimum = 1,
    random_spot_size_maximum = 1,
    additional_richness = spec.autoplace.additional_richness,
    has_starting_area_placement = false,
    regular_rq_factor_multiplier = 1,
  }, biome_by_name[spec.biome].region, spec.autoplace.seed1)
  out[#out + 1] = well
  out[#out + 1] = autoplace_control(spec.resource, letter)

  local c = spec.cracking
  if c then
    out[#out + 1] = {
      type = "recipe",
      name = "fo-" .. key .. "-cracking",
      category = "chemistry",
      enabled = false,
      energy_required = c.energy,
      ingredients = { { type = "fluid", name = spec.fluid, amount = c.input } },
      results = { { type = "fluid", name = c.product, amount = c.output } },
      main_product = c.product,
      subgroup = "fluid-recipes",
      order = "z[fo]-a[" .. key .. "-cracking]",
      icons = { { icon = fluid.icons[1].icon, icon_size = fluid.icons[1].icon_size, icon_mipmaps = fluid.icons[1].icon_mipmaps, tint = spec.tint } },
    }
  end
end

---------------------------------------------------------------------------------------------------
-- Ressources générées depuis les données (lot M0) : une entrée de W.resources par clé de W.resource_order, selon
-- son genre. La lettre d'ordre (a, b, c...) suit l'ordre de la liste (celui des époques).
---------------------------------------------------------------------------------------------------
for i, key in ipairs(W.resource_order) do
  local spec = W.resources[key]
  local letter = string.char(string.byte("a") + i - 1)
  if spec.kind == "ore" then
    ore_prototypes(spec, letter)
  elseif spec.kind == "fluid" then
    fluid_prototypes(spec, key, letter)
  else
    error("factorio-overhaul : genre de ressource inconnu pour " .. key .. " : " .. tostring(spec.kind))
  end
end

local tungsten = W.resources.tungsten
local methane = W.resources.methane

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
