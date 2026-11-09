--[[
  Lot TITANS (9/11) : le JUGGERNAUT, titan ALLIÉ, entrée nouvelle de la famille des géants (appelé en fin de prototypes/experimentaux_geants.lua).
  Règles pures : shared/robots/titans.lua (T) ; feuilles : graphics/robots/titans/sprites.lua (généré par tools/render/pieces/titans/
  feuilles_titans.py, PNG hors de git, D-6) ; script : script/robots/titans.lua.
  - UN `spider-vehicle` PAR PALIER d'âge (T.PALIERS : âges 10 à 15) : PV, plaques (résistances), masse (vitesse) de la règle ; le script
    pose le palier de l'âge de la force et le remplace au changement d'âge (évolution dynamique). Un seul objet (palier 1 à la pose).
  - Corps : UNE image posée par `rendering` (comme les géants, Xp.GIANT_BODY), trois STADES d'images (T.stage) ; lueur fondue ; ombre.
  - Pattes : celles des géants (Xp.PREFIX .. "geant-patte-n", sans image ni collision) ; il flotte.
  - Armes : effets par script : canon annulaire = rayon laser vanilla teinté cyan (fo-titan-canon) ; griffes = explosion d'éclair
    (sprite éclair-blanc des expérimentaux) teintée ; salve de zone = cratères des géants (fo-xp-cratere-<âge>).
  - Chaîne : 10 segments au Dock (catégorie des robots de palier 3), assemblage à l'usine de son âge, technologie après celle du Dock.
]]

local lib = require("prototypes.lib")
local T = require("shared.robots.titans")
local Xp = require("shared.robots.experimentaux")
local Ro = require("shared.content.robots")
local C = require("shared.content.crafts")
local SPR = require("__factorio-overhaul__/graphics/robots/titans/sprites")
local XSPR = require("__factorio-overhaul__/graphics/robots/experimentaux/sprites")

local out = {}
local r = T.JUGGERNAUT

local function ingredients(list)
  local l = {}
  for _, g in ipairs(list) do l[#l + 1] = { type = "item", name = g[1], amount = g[2] } end
  return l
end

local function feuille(stage)
  local s = SPR.juggernaut[tostring(stage)] or SPR.juggernaut[stage]
  assert(s, "titans : feuille du Juggernaut absente pour le stade " .. tostring(stage))
  return s
end

local function icones()
  local i = feuille(1).icone
  return { { icon = i.filename, icon_size = i.size } }
end

-- Sprites du corps pour `rendering` : principale, lueur, ombre de chaque stade.
local function sprite(nom, def, opts)
  local function une(x)
    local t = { filename = x.filename, width = x.width, height = x.height, scale = x.scale, shift = { def.shift[1], def.shift[2] }, priority = "medium" }
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

for stage = 1, T.STAGES do
  local s = feuille(stage)
  out[#out + 1] = sprite(T.PREFIX .. r.id .. "-" .. stage .. "-corps", s.main, {})
  for k, g in ipairs(s.lueurs) do out[#out + 1] = sprite(T.PREFIX .. r.id .. "-" .. stage .. "-lueur-" .. k, g, { lueur = true }) end
  out[#out + 1] = sprite(T.PREFIX .. r.id .. "-" .. stage .. "-ombre", s.ombre, { ombre = true })
end

-- Effets : rayon du canon annulaire (laser vanilla teinté cyan, sans dégâts moteur), éclair des griffes (sprite des expérimentaux)
do
  local canon = table.deepcopy(data.raw.beam["laser-beam"])
  canon.name = T.PREFIX .. "canon"
  canon.localised_name = { "entity-name." .. T.PREFIX .. "canon" }
  canon.action = nil
  canon.damage_interval = 1000
  lib.tint_sprites(canon, { r = 0.35, g = 0.95, b = 1.0 })
  out[#out + 1] = canon
  local e = XSPR.effets["eclair-blanc"]
  out[#out + 1] = {
    type = "explosion", name = T.PREFIX .. "griffe", flags = { "not-on-map", "hidden" }, subgroup = "explosions",
    localised_name = { "entity-name." .. T.PREFIX .. "griffe" },
    animations = { { filename = e.lr.filename, width = e.lr.width, height = e.lr.height, scale = e.lr.scale * 1.4, frame_count = 1, line_length = 1,
      animation_speed = 1 / 12, blend_mode = "additive", draw_as_glow = true, tint = { r = 0.3, g = 0.95, b = 1.0 }, shift = { 0, -0.5 },
      hr_version = { filename = e.hr.filename, width = e.hr.width, height = e.hr.height, scale = e.hr.scale * 1.4, frame_count = 1, line_length = 1,
        animation_speed = 1 / 12, blend_mode = "additive", draw_as_glow = true, tint = { r = 0.3, g = 0.95, b = 1.0 }, shift = { 0, -0.5 } } } },
    scale_initial = 0.4, scale_end = 1.2, scale_in_duration = 4, fade_out_duration = 10,
    light = { intensity = 0.7, size = 14, color = { r = 0.3, g = 0.9, b = 1.0 } },
    sound = data.raw.explosion["big-explosion"].sound,
  }
end

-- Pattes : celles des géants, déjà déclarées par prototypes/experimentaux_geants.lua
local POSES = { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }
local legs = {}
for n = 1, 4 do
  local nom = Xp.PREFIX .. "geant-patte-" .. n
  assert(data.raw["spider-leg"][nom], "titans : patte des géants absente " .. nom)
  legs[n] = { leg = nom, mount_position = { POSES[n][1] * 0.3, POSES[n][2] * 0.3 }, ground_position = POSES[n], blocking_legs = { 5 - n } }
end

-- Un spider-vehicle par palier (évolution dynamique : le script remplace l'entité au changement d'âge)
for palier = 1, T.PALIERS do
  local j = T.juggernaut(T.age_of_palier(palier))
  local s = feuille(j.stage)
  local hw = math.floor(s.main.lr.width * s.main.lr.scale / 32 / 4)
  local top = math.floor(s.main.shift[2])
  out[#out + 1] = {
    type = "spider-vehicle", name = j.name,
    localised_name = { "entity-name." .. j.name }, localised_description = { "entity-description." .. r.name },
    icons = icones(),
    collision_box = { { -2, -2 }, { 2, 2 } }, collision_mask = {}, sticker_box = { { -4, -4 }, { 4, 4 } },
    selection_box = { { -hw, top }, { hw, 0 } }, selection_priority = 20,
    drawing_box = { { -30, -60 }, { 30, 20 } },
    flags = { "placeable-neutral", "player-creation", "placeable-off-grid", "not-blueprintable", "not-flammable" },
    minable = { mining_time = 2, result = r.name },
    max_health = j.hp, healing_per_tick = j.hp / 60 / 600, resistances = table.deepcopy(j.resistances),
    dying_explosion = "massive-explosion",
    map_color = { r = r.lueur.r, g = r.lueur.g, b = r.lueur.b }, friendly_map_color = { r = r.lueur.r, g = r.lueur.g, b = r.lueur.b },
    enemy_map_color = { r = 1.0, g = 0.2, b = 0.1 },
    weight = 1, braking_force = 1, friction_force = 1, energy_per_hit_point = 1,
    allow_passengers = false, inventory_size = 0, trash_inventory_size = 0, energy_source = { type = "void" },
    chunk_exploration_radius = 3, automatic_weapon_cycling = false, chain_shooting_cooldown_modifier = 1,
    movement_energy_consumption = "1kW", height = 0, torso_bob_speed = 0, torso_rotation_speed = 0,
    sound_minimum_speed = 0.05, sound_scaling_ratio = 0.6,
    working_sound = { sound = { filename = "__base__/sound/spidertron/spidertron-vox.ogg", volume = 0.4 }, match_speed_to_activity = true },
    spider_engine = { legs = table.deepcopy(legs), military_target = "spidertron-military-target" },
    graphics_set = { render_layer = "air-object", base_render_layer = "object", autopilot_destination_visualisation_render_layer = "object" },
    order = string.format("z[fo-titan]-%02d", palier),
  }
end

-- objet (pose : palier 1, le script met le palier de l'âge), segment, recettes, technologie
out[#out + 1] = {
  type = "item-with-entity-data", name = r.name, localised_name = { "entity-name." .. r.name },
  localised_description = { "item-description." .. r.name }, icons = icones(), subgroup = T.SUBGROUP,
  order = "c[xp-geant]-99-titan", place_result = T.juggernaut_name(1), stack_size = 1,
}
local seg_icons = icones()
seg_icons[#seg_icons + 1] = { icon = "__base__/graphics/icons/low-density-structure.png", icon_size = 64, icon_mipmaps = 4, scale = 0.25, shift = { -8, 8 } }
out[#out + 1] = {
  type = "item", name = r.segment_item, localised_name = { "item-name." .. r.segment_item },
  localised_description = { "item-description." .. r.segment_item }, icons = seg_icons, subgroup = T.SUBGROUP,
  order = "d[xp-segment]-99-titan", stack_size = 10,
}
local seg_cat = Ro.factory(Xp.SEGMENT_FACTORY).category
out[#out + 1] = {
  type = "recipe", name = r.segment_recipe, category = seg_cat, enabled = false, energy_required = r.segment.time,
  ingredients = ingredients(r.segment.ingredients), results = { { type = "item", name = r.segment_item, amount = 1 } },
  main_product = r.segment_item, localised_name = { "item-name." .. r.segment_item },
}
out[#out + 1] = {
  type = "recipe", name = r.recipe, category = T.category(r), enabled = false, energy_required = r.time,
  ingredients = ingredients(r.ingredients), results = { { type = "item", name = r.name, amount = 1 } }, main_product = r.name,
  localised_name = { "entity-name." .. r.name },
}
local after = Ro.tech(r.after)
assert(after, "titans : technologie de robot absente " .. tostring(r.after))
out[#out + 1] = lib.technology({
  name = r.tech,
  localised_name = { "technology-name." .. r.tech }, localised_description = { "technology-description." .. r.tech },
  icons = { { icon = feuille(T.STAGES).icone.filename, icon_size = 64 } },
  effects = { lib.unlock(r.segment_recipe), lib.unlock(r.recipe) }, prerequisites = { r.after },
  count = Xp.tech_units(C.tech_count(after)), packs = C.packs(r.age), time = 30,
  order = "z[fo]-robots-xp-titan",
})

data:extend(out)
