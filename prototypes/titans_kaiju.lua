--[[
  Lot TITANS (9/11) : le KAIJU cristallin lourd, titan ENNEMI (appelé en fin de prototypes/enemies.lua). Règles pures : shared/robots/titans.lua
  (T.kaiju(era)) ; feuilles : graphics/robots/titans/sprites.lua (feuilles_titans.py, PNG hors de git, D-6).
  - Un `unit` PAR ÈRE du jeu (T.ERAS, lues dans shared/levels/config.lua) : PV, plaques, vitesse, échelle de l'image (masse), arme et
    couleur de la lueur (couleur de l'ère) suivent la règle ; les vagues choisissent l'ère par l'âge de la partie (shared/td/waves.lua),
    les nids vanilla le proposent tard dans l'évolution (T.kaiju_curve).
  - Animations : course 8 directions × 8 images, attaque 8 × 4, en `filenames` + `lines_per_file` (convention vanilla des déchiqueteurs),
    couches : corps, lueur (rendue blanche, TEINTÉE ici par l'ère, draw_as_glow additive), ombre.
  - Armes par ère : morsure (ère 1), griffes de zone au contact (2), impulsion de la gueule-canon (projectile de zone, 3 et plus).
]]

local lib = require("prototypes.lib")
local T = require("shared.robots.titans")
local E = require("shared.content.enemies")
local SPR = require("__factorio-overhaul__/graphics/robots/titans/sprites")

local out = {}
local K = SPR.kaiju
assert(K and K.course and K.attaque, "titans : feuilles du Kaiju absentes (py -3.9 tools/render/pieces/titans/feuilles_titans.py)")

--- Une couche d'une animation : `c` (feuille), `a` (animation), `k` échelle du jeu, `extra` posé sur la couche et sa hr_version.
local function couche(c, a, k, extra)
  local d = a.densite
  local layer = {
    filenames = c.lr, lines_per_file = c.lpf, line_length = c.ll, width = c.lw, height = c.lh, frame_count = a.images, direction_count = K.directions,
    shift = { c.sx * k, c.sy * k }, scale = k * 32 / (d / K.reduc),
    hr_version = {
      filenames = c.hr, lines_per_file = c.lpf, line_length = c.ll, width = c.w, height = c.h, frame_count = a.images, direction_count = K.directions,
      shift = { c.sx * k, c.sy * k }, scale = k * 32 / d,
    },
  }
  for key, v in pairs(extra or {}) do
    layer[key] = v
    layer.hr_version[key] = v
  end
  return layer
end

local function animation(nom, j, vitesse)
  local a = K[nom]
  local k = j.scale
  local g = j.glow
  local lueur = { draw_as_glow = true, blend_mode = "additive", tint = { r = j.tint.r * g, g = j.tint.g * g, b = j.tint.b * g, a = g } }
  local ombre = { draw_as_shadow = true }
  local principal = {}
  if vitesse then principal.animation_speed, lueur.animation_speed, ombre.animation_speed = vitesse, vitesse, vitesse end
  return { layers = {
    couche(a.couches.main, a, k, principal),
    couche(a.couches.glow, a, k, lueur),
    couche(a.couches.shadow, a, k, ombre),
  } }
end

local function degats(amount, dtype)
  return { type = "damage", damage = { amount = amount, type = dtype } }
end

-- projectile de l'impulsion (ères 3 et plus) : fusée vanilla recolorée, explosion de zone cyan (un prototype par ère, copié de ce modèle)
local impulsion
do
  local p = lib.copy("projectile", "rocket")
  p.name = T.PREFIX .. "impulsion"
  p.localised_name = { "entity-name." .. T.PREFIX .. "impulsion" }
  p.acceleration = 0.02
  p.turn_speed = 0.02
  p.light = { intensity = 0.8, size = 10, color = { r = 0.3, g = 0.9, b = 1.0 } }
  lib.tint_sprites(p, { r = 0.3, g = 0.95, b = 1.0 })
  p.action = nil -- posé par ère ci-dessous (copie par ère)
  impulsion = p
end

local base_icon = data.raw.unit["behemoth-biter"]
for era = 1, T.ERAS do
  local j = T.kaiju(era)
  local u = lib.copy("unit", "behemoth-biter")
  u.name = j.name
  u.order = string.format("b-a-z[fo]-titan-%d", era)
  u.localised_name = { "entity-name." .. j.name }
  u.localised_description = { "entity-description." .. T.PREFIX .. T.KAIJU.id }
  u.max_health = j.hp
  u.healing_per_tick = j.hp / 60 / 1200
  u.movement_speed = j.speed
  u.resistances = table.deepcopy(j.resistances)
  u.vision_distance = j.vision
  u.pollution_to_join_attack = j.pollution
  u.collision_box = { { -E.BOX_HALF_MAX, -E.BOX_HALF_MAX }, { E.BOX_HALF_MAX, E.BOX_HALF_MAX } }
  u.selection_box = { { -4 * j.scale, -4.5 * j.scale }, { 4 * j.scale, 1.5 * j.scale } }
  u.sticker_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }
  u.run_animation = animation("course", j)
  u.distance_per_frame = K.foulee * K.K * j.scale / K.course.images
  u.water_reflection = nil
  u.dying_explosion = "massive-explosion"
  u.map_color = { r = j.tint.r, g = j.tint.g, b = j.tint.b }
  u.affected_by_tides = nil
  -- arme de l'ère
  local ap = u.attack_parameters
  ap.animation = animation("attaque", j, 0.25)
  ap.damage_modifier = nil
  if j.arme == "impulsion" then
    local proj = table.deepcopy(impulsion)
    proj.name = T.PREFIX .. "impulsion-" .. era
    proj.action = { type = "area", radius = j.impulsion_radius, action_delivery = { type = "instant", target_effects = {
      degats(j.morsure * 0.6, "explosion"), degats(j.morsure * 0.6, "laser"),
      { type = "create-entity", entity_name = "big-explosion" },
    } } }
    out[#out + 1] = proj
    u.attack_parameters = {
      type = "projectile", range = j.impulsion_range, min_attack_distance = 6, cooldown = j.impulsion_cooldown, cooldown_deviation = 0.1,
      ammo_category = "melee", projectile_creation_distance = 3.5 * j.scale,
      ammo_type = { category = "melee", target_type = "position", clamp_position = true,
        action = { type = "direct", action_delivery = { type = "projectile", projectile = proj.name, starting_speed = 0.35 } } },
      animation = ap.animation, sound = ap.sound, range_mode = "bounding-box-to-bounding-box",
    }
  else
    ap.range = 3.0 * j.scale
    ap.cooldown = j.morsure_cooldown
    ap.range_mode = "bounding-box-to-bounding-box"
    if j.arme == "griffes" then
      ap.ammo_type = { category = "melee", target_type = "entity",
        action = { type = "area", radius = j.griffes_radius, force = "not-same", action_delivery = { type = "instant", target_effects = {
          degats(j.morsure, "physical"), { type = "create-entity", entity_name = T.PREFIX .. "griffe" } } } } }
    else
      ap.ammo_type = { category = "melee", target_type = "entity",
        action = { type = "direct", action_delivery = { type = "instant", target_effects = { degats(j.morsure, "physical") } } } }
    end
  end
  -- dépouille : celle du béhémoth à l'échelle du titan, teintée de l'ère
  local corpse = lib.copy("corpse", "behemoth-biter-corpse")
  corpse.name = j.name .. "-corpse"
  local t2 = { r = j.tint.r, g = j.tint.g, b = j.tint.b, a = 1 }
  add_biter_die_animation(4.0 * j.scale, { r = 0.04, g = 0.03, b = 0.06, a = 1 }, t2, corpse)
  corpse.localised_name = { "", u.localised_name, " (", { "fo-enemy.corpse" }, ")" }
  u.corpse = corpse.name
  lib.set_icons(u, { { icon = K.icone.filename, icon_size = K.icone.size } })
  lib.set_icons(corpse, lib.tier_icons(base_icon.icon, base_icon.icon_size, t2, nil, base_icon.icon_mipmaps))
  out[#out + 1] = u
  out[#out + 1] = corpse
  -- nids vanilla : le Kaiju de l'ère, tard dans l'évolution, rare
  table.insert(data.raw["unit-spawner"]["biter-spawner"].result_units, { j.name, T.kaiju_curve(era) })
end

data:extend(out)
