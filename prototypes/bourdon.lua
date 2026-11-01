-- LE BOURDON, expérimental de l'âge 15 (lot BOURDON, 1er/11) : cloche-cathédrale en lévitation. Le prototype existe toujours (réglage
-- fo-war-robots non requis), rien ne le pose hors des commandes de démonstration (script/robots/bourdon.lua) tant que le Portique
-- (lot RB-5) n'existe pas.
--
-- `spider-vehicle` (RB-0, E3, E9) : marche sans chemin, autopilote, télécommande de vanilla. Toute l'image passe par `rendering`
-- (script/robots/bourdon.lua) : flottement, chaînes, ancres et Glas en dépendent, et l'entité, son `position`, reste invisible.
-- Pattes sans image, de collision nulle : elle passe partout, eau comprise.

local SPR = require("__factorio-overhaul__/graphics/robots/bourdon/sprites")

local protos = {}

local function bloc(e, s)
  local b = { filename = e.filename, width = e.width, height = e.height, scale = e.scale }
  if s.blend then b.blend_mode = s.blend end
  if s.ombre then b.draw_as_shadow = true end
  if s.lueur then b.draw_as_glow = true end
  return b
end

local cles = {}
for k in pairs(SPR) do cles[#cles + 1] = k end
table.sort(cles)
for _, k in ipairs(cles) do
  local s = SPR[k]
  local p = bloc(s.lr, s)
  p.type = "sprite"
  p.name = "fo-bourdon-" .. k
  p.flags = { "group=none" }
  p.hr_version = bloc(s.hr, s)
  protos[#protos + 1] = p
end

local ICONE = "__base__/graphics/icons/spidertron.png"

local function patte(n)
  return {
    type = "spider-leg",
    name = "fo-bourdon-patte-" .. n,
    localised_name = { "entity-name.fo-bourdon" },
    collision_box = { { -0.05, -0.05 }, { 0.05, 0.05 } },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    icon = ICONE, icon_size = 64, icon_mipmaps = 4,
    collision_mask = {},
    selectable_in_game = false,
    flags = { "not-on-map", "not-blueprintable", "not-deconstructable", "hidden", "not-flammable" },
    target_position_randomisation_distance = 0.25,
    minimal_step_size = 1,
    part_length = 3.5,
    initial_movement_speed = 0.025,
    movement_acceleration = 0.012,
    max_health = 100,
    movement_based_position_selection_distance = 4,
    graphics_set = {},
  }
end

local pattes = {}
local POSES = { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }
for n = 1, 4 do
  protos[#protos + 1] = patte(n)
  local opp = { 4, 3, 2, 1 }
  pattes[n] = {
    leg = "fo-bourdon-patte-" .. n,
    mount_position = { POSES[n][1] * 0.3, POSES[n][2] * 0.3 },
    ground_position = POSES[n],
    blocking_legs = { opp[n] },
  }
end

protos[#protos + 1] = {
  type = "spider-vehicle",
  name = "fo-bourdon",
  localised_name = { "entity-name.fo-bourdon" },
  localised_description = { "entity-description.fo-bourdon" },
  icon = ICONE, icon_size = 64, icon_mipmaps = 4,
  collision_box = { { -2, -2 }, { 2, 2 } },
  collision_mask = {},
  sticker_box = { { -4, -4 }, { 4, 4 } },
  selection_box = { { -11, -44 }, { 11, 0 } }, -- le moteur exige que la boîte passe à moins de 0,5 de l'origine
  selection_priority = 20, -- le bâtiment dessous reste cliquable
  drawing_box = { { -40, -66 }, { 40, 26 } },
  flags = { "placeable-neutral", "player-creation", "placeable-off-grid", "not-blueprintable", "not-deconstructable", "not-flammable", "not-repairable" },
  max_health = 60000,
  healing_per_tick = 0.5,
  resistances = {
    { type = "physical", decrease = 30, percent = 70 },
    { type = "impact", decrease = 50, percent = 90 },
    { type = "explosion", decrease = 30, percent = 70 },
    { type = "fire", decrease = 20, percent = 80 },
    { type = "acid", decrease = 10, percent = 60 },
    { type = "laser", decrease = 10, percent = 50 },
    { type = "electric", decrease = 10, percent = 50 },
  },
  dying_explosion = "massive-explosion",
  map_color = { r = 0.95, g = 0.8, b = 0.42 },
  friendly_map_color = { r = 1.0, g = 0.85, b = 0.45 },
  enemy_map_color = { r = 1.0, g = 0.2, b = 0.1 },
  weight = 1,
  braking_force = 1,
  friction_force = 1,
  energy_per_hit_point = 1,
  allow_passengers = false,
  inventory_size = 0,
  trash_inventory_size = 0,
  energy_source = { type = "void" },
  chunk_exploration_radius = 3,
  automatic_weapon_cycling = false,
  chain_shooting_cooldown_modifier = 1,
  movement_energy_consumption = "1kW",
  height = 0,
  torso_bob_speed = 0,
  torso_rotation_speed = 0,
  sound_minimum_speed = 0.05,
  sound_scaling_ratio = 0.6,
  working_sound = {
    sound = { filename = "__base__/sound/spidertron/spidertron-vox.ogg", volume = 0.5 },
    match_speed_to_activity = true,
  },
  spider_engine = { legs = pattes, military_target = "spidertron-military-target" },
  graphics_set = {
    render_layer = "air-object",
    base_render_layer = "object",
    autopilot_destination_visualisation_render_layer = "object",
  },
}

-- Poussière de l'onde, levée le long du front ; braises et fumée sur les ruines : trivial-smoke, sans entité.
local smoke = require("__base__/prototypes/entity/smoke-animations")
protos[#protos + 1] = {
  type = "trivial-smoke",
  name = "fo-bourdon-poussiere",
  animation = smoke.trivial_smoke_fast({ animation_speed = 1 / 5, scale = 1.1 }),
  duration = 70,
  fade_in_duration = 6,
  fade_away_duration = 40,
  start_scale = 0.8,
  end_scale = 2.4,
  spread_duration = 40,
  affected_by_wind = false,
  movement_slow_down_factor = 0.96,
  render_layer = "smoke",
  show_when_smoke_off = true,
  color = { r = 0.42, g = 0.32, b = 0.2, a = 0.7 },
}
protos[#protos + 1] = {
  type = "trivial-smoke",
  name = "fo-bourdon-fumee",
  animation = smoke.trivial_smoke_fast({ animation_speed = 1 / 8, scale = 1.6 }),
  duration = 420,
  fade_in_duration = 30,
  fade_away_duration = 200,
  start_scale = 0.6,
  end_scale = 3.2,
  spread_duration = 300,
  affected_by_wind = true,
  movement_slow_down_factor = 0.96,
  render_layer = "smoke",
  show_when_smoke_off = true,
  color = { r = 0.1, g = 0.085, b = 0.075, a = 0.75 },
}

-- Flamme sur une ruine ennemie : une image de feu de vanilla, sans dégâts, jamais un `fire` (ne se propage pas, ne touche personne).
protos[#protos + 1] = {
  type = "explosion",
  name = "fo-bourdon-flamme",
  flags = { "not-on-map", "hidden" },
  subgroup = "explosions",
  render_layer = "object",
  animations = {
    {
      filename = "__base__/graphics/entity/fire-flame/fire-flame-13.png",
      line_length = 8, width = 60, height = 118, frame_count = 25,
      animation_speed = 0.16, scale = 1.25, shift = { 0, -1.2 }, blend_mode = "additive",
    },
  },
}

protos[#protos + 1] = {
  type = "explosion",
  name = "fo-bourdon-flamme2",
  localised_name = { "entity-name.fo-bourdon-flamme" },
  flags = { "not-on-map", "hidden" },
  subgroup = "explosions",
  render_layer = "object",
  animations = {
    {
      filename = "__base__/graphics/entity/fire-flame/fire-flame-13.png",
      line_length = 8, width = 60, height = 118, frame_count = 25,
      animation_speed = 0.12, scale = 0.9, shift = { 0, -0.9 }, blend_mode = "additive",
    },
  },
}

-- La cloche : l'explosion nucléaire de vanilla, jouée bas (pas de pipeline de son, S0).
protos[#protos + 1] = {
  type = "sound",
  name = "fo-bourdon-glas",
  category = "environment",
  aggregation = { max_count = 2, remove = false },
  audible_distance_modifier = 8,
  speed = 0.55,
  filename = "__base__/sound/fight/nuclear-explosion-1.ogg",
  volume = 1.0,
}
protos[#protos + 1] = {
  type = "sound",
  name = "fo-bourdon-ancre",
  category = "environment",
  aggregation = { max_count = 3, remove = false },
  audible_distance_modifier = 4,
  speed = 0.6,
  filename = "__base__/sound/fight/large-explosion-1.ogg",
  volume = 0.9,
}

-- Le coup vers le curseur (une commande ne connaît pas le curseur, l'événement de touche si).
protos[#protos + 1] = {
  type = "custom-input",
  name = "fo-bourdon-glas",
  key_sequence = "CONTROL + SHIFT + G",
  consuming = "none",
  order = "c[fo-bourdon]-a",
}

data:extend(protos)
