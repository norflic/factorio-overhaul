--[[
  Lot EXPERIMENTAUX (3/11), palier 3 : les 5 GÉANTS (Cairn, Stylet, Trombe, Ixion, Tournesol). Appelé en fin de prototypes/experimentaux.lua.
  - `spider-vehicle` sans arme : l'effet part du script (script/robots/experimentaux_geants.lua), à la cadence, vers l'ennemi à portée.
  - Corps : UNE image, posée par le script (`rendering`, attachée à l'entité : prouvé par le Bourdon, BO-2) ou par le prototype selon
    l'essai E-XP1 (Xp.GIANT_BODY) ; lueurs fondues en une couche (vue de nuit) ; ombre.
  - Pattes : 4, SANS image et sans collision (celles du Bourdon : E-XP2, BO-5) : il flotte, passe l'eau, les murs, les falaises.
  - Chaîne : 10 segments au Dock (catégorie fo-robots-3), puis l'assemblage final à l'usine de son âge (Dock ou Portique), 60 s.
  - Rayons des effets : rayon électrique vanilla (Cairn), rayon laser vanilla teinté or (Tournesol) ; explosions : éclair blanc teinté
    (Stylet), « big-explosion » vanilla (Ixion) ; tout le reste est du `rendering`.
]]

local lib = require("prototypes.lib")
local Xp = require("shared.robots.experimentaux")
local Ech = require("shared.robots.echelle")
local Ro = require("shared.content.robots")
local C = require("shared.content.crafts")
local SPR = require("__factorio-overhaul__/graphics/robots/experimentaux/sprites")
-- ART-GEANTS (11/11, F525) : feuilles multidirectionnelles d'Ixion (générées, tools/render/pieces/experimentaux/feuilles_ixion_dirs.py)
local DIRS = { ixion = require("__factorio-overhaul__/graphics/robots/experimentaux/ixion_dirs") }
-- ART-GEANTS (F525, comme les titans F507) : le TORSE tourne vers la marche, à la vitesse de celui de l'araignée vanilla (données du jeu) :
-- c'est la seule orientation qu'un spider-vehicle tient à jour ; le script pose le corps dans sa direction (Xp.pose). À 0 (avant), le
-- torse restait fixe et le corps d'Ixion glissait, toujours tourné vers le sud-est.
local ARAIGNEE = data.raw["spider-vehicle"]["spidertron"]
assert(ARAIGNEE and ARAIGNEE.torso_rotation_speed and ARAIGNEE.torso_rotation_speed > 0, "experimentaux : torse de l'araignée vanilla absent")

local out = {}

local function ingredients(list)
  local l = {}
  for _, g in ipairs(list) do l[#l + 1] = { type = "item", name = g[1], amount = g[2] } end
  return l
end

local function icones(id)
  local i = SPR.corps[id].icone
  return { { icon = i.filename, icon_size = i.size } }
end

--- Couche du torse (prototype) : RotatedAnimation d'1 direction.
local function couche(def, opts)
  local function une(r)
    local t = { filename = r.filename, width = r.width, height = r.height, scale = r.scale, shift = { def.shift[1], def.shift[2] },
      direction_count = 1, frame_count = 1, priority = "medium" }
    if opts.ombre then t.draw_as_shadow = true elseif opts.lueur then t.draw_as_glow = true; t.blend_mode = "additive" end
    return t
  end
  local t = une(def.lr)
  t.hr_version = une(def.hr)
  return t
end

-- Sprites du corps pour `rendering` (mode « rendering ») : principale, lueur, ombre de chaque géant.
local function sprite(nom, def, opts)
  local function une(r)
    local t = { filename = r.filename, width = r.width, height = r.height, scale = r.scale, shift = { def.shift[1], def.shift[2] }, priority = "medium" }
    if opts.ombre then t.draw_as_shadow = true elseif opts.lueur then t.draw_as_glow = true; t.blend_mode = "additive" end
    return t
  end
  local t = une(def.lr)
  t.hr_version = une(def.hr)
  t.type = "sprite"
  t.name = nom
  t.flags = { "group=none" }
  return t
end

-- Pattes du Bourdon (sans image, sans collision) : une série pour tous les géants.
local POSES = { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }
local legs = {}
for n = 1, 4 do
  out[#out + 1] = {
    type = "spider-leg", name = Xp.PREFIX .. "geant-patte-" .. n, localised_name = { "entity-name." .. Xp.PREFIX .. "geant-patte" },
    collision_box = { { -0.05, -0.05 }, { 0.05, 0.05 } }, selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    icon = "__base__/graphics/icons/spidertron.png", icon_size = 64, icon_mipmaps = 4,
    collision_mask = {}, selectable_in_game = false,
    flags = { "not-on-map", "not-blueprintable", "not-deconstructable", "hidden", "not-flammable" },
    target_position_randomisation_distance = 0.25, minimal_step_size = 1, part_length = 3.5,
    initial_movement_speed = 0.025, movement_acceleration = 0.012, max_health = 100, movement_based_position_selection_distance = 4,
    graphics_set = {},
  }
  legs[n] = { leg = Xp.PREFIX .. "geant-patte-" .. n, mount_position = { POSES[n][1] * 0.3, POSES[n][2] * 0.3 }, ground_position = POSES[n],
    blocking_legs = { 5 - n } }
end

-- Rayons et explosions des effets (0 image neuve, sauf l'éclair blanc procédural)
do
  local cairn = table.deepcopy(data.raw.beam["electric-beam-no-sound"])
  cairn.name = Xp.PREFIX .. "cairn-arc"
  cairn.localised_name = { "entity-name." .. Xp.PREFIX .. "cairn" }
  cairn.action = nil
  cairn.damage_interval = 1000
  out[#out + 1] = cairn
  local foyer = table.deepcopy(data.raw.beam["laser-beam"])
  foyer.name = Xp.PREFIX .. "tournesol-foyer"
  foyer.localised_name = { "entity-name." .. Xp.PREFIX .. "tournesol" }
  foyer.action = nil
  foyer.damage_interval = 1000
  lib.tint_sprites(foyer, { r = 1.0, g = 0.9, b = 0.55 })
  out[#out + 1] = foyer
  local e = SPR.effets["eclair-blanc"]
  out[#out + 1] = {
    type = "explosion", name = Xp.PREFIX .. "stylet-pilier", flags = { "not-on-map", "hidden" }, subgroup = "explosions",
    localised_name = { "entity-name." .. Xp.PREFIX .. "stylet" },
    animations = { { filename = e.lr.filename, width = e.lr.width, height = e.lr.height, scale = e.lr.scale * 0.8, frame_count = 1, line_length = 1,
      animation_speed = 1 / 16, blend_mode = "additive", draw_as_glow = true, tint = { r = 0.7, g = 0.85, b = 1.0 }, shift = { 0, -1.5 },
      hr_version = { filename = e.hr.filename, width = e.hr.width, height = e.hr.height, scale = e.hr.scale * 0.8, frame_count = 1, line_length = 1,
        animation_speed = 1 / 16, blend_mode = "additive", draw_as_glow = true, tint = { r = 0.7, g = 0.85, b = 1.0 }, shift = { 0, -1.5 } } } },
    scale_initial = 0.3, scale_end = 1.0, scale_in_duration = 5, fade_out_duration = 12,
    light = { intensity = 0.8, size = 12, color = { r = 0.6, g = 0.8, b = 1.0 } },
    sound = data.raw.explosion["big-explosion"].sound,
  }
end

-- E4 (règle d'échelle, shared/robots/echelle.lua) : explosion du cratère au point visé, un prototype par âge à zone (10 à 15 : géants de cette
-- famille ET de robotsjeu). Elle ne pose plus le sol : le SOL du cratère est posé et rendu par script (séquelles d'1 h, QCM-7/11,
-- script/robots/experimentaux_geants.lua cratere/resorber) ; elle retire les décoratifs.
for age = Ech.AGE_ZONE_MIN, Ech.AGE_MAX do
  local rc = Ech.cratere(age)
  local x = table.deepcopy(data.raw.explosion["big-explosion"])
  x.name = Xp.PREFIX .. "cratere-" .. age
  x.localised_name = { "entity-name." .. Xp.PREFIX .. "cratere" }
  x.created_effect = { type = "direct", action_delivery = { type = "instant", target_effects = {
    { type = "destroy-decoratives", radius = rc },
  } } }
  out[#out + 1] = x
end

-- Brûlures au sol d'1 h (séquelles, QCM-7/11) : copies des brûlures du jeu de base (10 min), même image, durée Ech.TRACE_TICKS.
for _, x in ipairs({ { "small-scorchmark", Xp.PREFIX .. "small-scorchmark" }, { "medium-scorchmark", Xp.PREFIX .. "medium-scorchmark" },
    { "big-scorchmark", Xp.PREFIX .. "big-scorchmark" }, { "huge-scorchmark", Xp.PREFIX .. "huge-scorchmark" } }) do
  local nom = x[1]
  local b = table.deepcopy(data.raw.corpse[nom])
  b.name = x[2]
  b.localised_name = { "entity-name." .. nom }
  b.time_before_removed = Ech.TRACE_TICKS
  out[#out + 1] = b
end

for i, r in ipairs(Xp.GEANTS) do
  local s = SPR.corps[r.id]
  assert(s, "experimentaux : geant sans feuille " .. r.id)
  out[#out + 1] = sprite(Xp.PREFIX .. r.id .. "-corps", s.main, {})
  for k, g in ipairs(s.lueurs) do out[#out + 1] = sprite(Xp.PREFIX .. r.id .. "-lueur-" .. k, g, { lueur = true }) end
  out[#out + 1] = sprite(Xp.PREFIX .. r.id .. "-ombre", s.ombre, { ombre = true })
  -- F525 : une pose par sprite (couches dans Xp.CORPS_COUCHES), si le géant a un corps orienté
  local cd = Xp.CORPS_DIRS[r.id]
  if cd then
    local fd = DIRS[r.id]
    assert(fd and fd.directions == cd.directions and #fd.poses == cd.poses, "experimentaux : feuilles orientees incoherentes " .. r.id)
    for k, p in ipairs(fd.poses) do
      assert(#p.lueurs == 1, "experimentaux : une lueur par pose " .. r.id)
      out[#out + 1] = sprite(Xp.sprite_corps(r.id, "corps", k - 1), p.main, {})
      out[#out + 1] = sprite(Xp.sprite_corps(r.id, "lueur-1", k - 1), p.lueurs[1], { lueur = true })
      out[#out + 1] = sprite(Xp.sprite_corps(r.id, "ombre", k - 1), p.ombre, { ombre = true })
    end
  end
  local gs = { render_layer = "air-object", base_render_layer = "object", autopilot_destination_visualisation_render_layer = "object" }
  if Xp.GIANT_BODY == "prototype" then
    local layers = { couche(s.main, {}) }
    for _, g in ipairs(s.lueurs) do layers[#layers + 1] = couche(g, { lueur = true }) end
    layers[#layers + 1] = couche(s.ombre, { ombre = true })
    gs.animation = { layers = layers }
  end
  -- boîte de sélection : la moitié basse du corps (le moteur exige qu'elle passe à moins de 0,5 de l'origine, BO-3)
  local hw = math.floor(s.main.lr.width * s.main.lr.scale / 32 / 4)
  local top = math.floor(s.main.shift[2])
  out[#out + 1] = {
    type = "spider-vehicle", name = r.name,
    localised_name = { "entity-name." .. r.name }, localised_description = { "entity-description." .. r.name },
    icons = icones(r.id),
    collision_box = { { -2, -2 }, { 2, 2 } }, collision_mask = {}, sticker_box = { { -4, -4 }, { 4, 4 } },
    selection_box = { { -hw, top }, { hw, 0 } }, selection_priority = 20,
    drawing_box = { { -30, -60 }, { 30, 20 } },
    flags = { "placeable-neutral", "player-creation", "placeable-off-grid", "not-blueprintable", "not-flammable" },
    minable = { mining_time = 2, result = r.name },
    max_health = r.hp, healing_per_tick = r.hp / 60 / 600, resistances = table.deepcopy(r.resistances), -- règle d'échelle par âge
    dying_explosion = "massive-explosion",
    map_color = { r = r.lueur.r, g = r.lueur.g, b = r.lueur.b }, friendly_map_color = { r = r.lueur.r, g = r.lueur.g, b = r.lueur.b },
    enemy_map_color = { r = 1.0, g = 0.2, b = 0.1 },
    weight = 1, braking_force = 1, friction_force = 1, energy_per_hit_point = 1,
    allow_passengers = false, inventory_size = 0, trash_inventory_size = 0, energy_source = { type = "void" },
    chunk_exploration_radius = 3, automatic_weapon_cycling = false, chain_shooting_cooldown_modifier = 1,
    movement_energy_consumption = "1kW", height = 0, torso_bob_speed = 0, torso_rotation_speed = ARAIGNEE.torso_rotation_speed,
    sound_minimum_speed = 0.05, sound_scaling_ratio = 0.6,
    working_sound = { sound = { filename = "__base__/sound/spidertron/spidertron-vox.ogg", volume = 0.4 }, match_speed_to_activity = true },
    spider_engine = { legs = legs, military_target = "spidertron-military-target" },
    graphics_set = gs,
    order = string.format("z[fo-xp]-g%02d", r.age),
  }
  -- objet (pose), segment, recettes, technologie
  out[#out + 1] = {
    type = "item-with-entity-data", name = r.name, localised_name = { "entity-name." .. r.name },
    localised_description = { "item-description." .. r.name }, icons = icones(r.id), subgroup = Xp.SUBGROUP,
    order = string.format("c[xp-geant]-%02d", i), place_result = r.name, stack_size = 1,
  }
  local seg_icons = icones(r.id)
  seg_icons[#seg_icons + 1] = { icon = "__base__/graphics/icons/low-density-structure.png", icon_size = 64, icon_mipmaps = 4, scale = 0.25, shift = { -8, 8 } }
  out[#out + 1] = {
    type = "item", name = r.segment_item, localised_name = { "item-name." .. r.segment_item },
    localised_description = { "item-description." .. r.segment_item }, icons = seg_icons, subgroup = Xp.SUBGROUP,
    order = string.format("d[xp-segment]-%02d", i), stack_size = 10,
  }
  local seg_cat = Ro.factory(Xp.SEGMENT_FACTORY).category
  out[#out + 1] = {
    type = "recipe", name = r.segment_recipe, category = seg_cat, enabled = false, energy_required = r.segment.time,
    ingredients = ingredients(r.segment.ingredients), results = { { type = "item", name = r.segment_item, amount = 1 } },
    main_product = r.segment_item, localised_name = { "item-name." .. r.segment_item },
  }
  out[#out + 1] = {
    type = "recipe", name = r.recipe, category = Xp.category(r), enabled = false, energy_required = r.time,
    ingredients = ingredients(r.ingredients), results = { { type = "item", name = r.name, amount = 1 } }, main_product = r.name,
    localised_name = { "entity-name." .. r.name },
  }
  local after = Ro.tech(r.after)
  assert(after, "experimentaux : technologie de robot absente " .. tostring(r.after))
  out[#out + 1] = lib.technology({
    name = r.tech,
    localised_name = { "technology-name." .. r.tech }, localised_description = { "technology-description." .. r.tech },
    icons = { { icon = s.icone.filename, icon_size = 64 } },
    effects = { lib.unlock(r.segment_recipe), lib.unlock(r.recipe) }, prerequisites = { r.after },
    count = Xp.tech_units(C.tech_count(after)), packs = C.packs(r.age), time = 30,
    order = "z[fo]-robots-xp-g" .. string.format("%02d", r.age),
  })
end

data:extend(out)

-- Lot TITANS : le Juggernaut, titan allié de la famille des géants
require("prototypes.titans")
