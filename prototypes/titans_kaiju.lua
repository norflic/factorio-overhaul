--[[
  Lot TITANS (9/11) : le KAIJU cristallin lourd, titan ENNEMI (appelé en fin de prototypes/enemies.lua). Règles pures : shared/robots/titans.lua
  (T.kaiju(era, k)) ; feuilles : graphics/robots/titans/sprites.lua (feuilles_titans.py, PNG hors de git, D-6).
  Lot KAIJUS-MUTANTS (10/11) : TOUS les archétypes de Kaiju (T.KAIJUS : cristallin, ÉCORCHEUR) et les ÉCORCHÉS (T.ECORCHE : mordeurs mutants,
  trois variantes) sortent de ce fichier, par les données : un `unit` par archétype et par ère (dès `era_min`), un `unit` par variante
  d'Écorché et par ère.
  - PV, plaques, vitesse, échelle de l'image (masse), arme et couleur de la lueur (couleur de l'ère) suivent la règle ; les vagues et les
    assauts choisissent l'archétype par T.kaiju_pour (rotation), les nids vanilla les proposent tard dans l'évolution (T.kaiju_curve,
    T.ecorche_curve).
  - Animations : course 8 directions × 8 images, attaque 8 × 4, en `filenames` + `lines_per_file` (convention vanilla des déchiqueteurs),
    couches : corps, lueur (rendue blanche, TEINTÉE ici par l'ère, draw_as_glow additive), ombre.
  - Armes : cristallin : morsure (ère 1), griffes de zone au contact (2), impulsion de la gueule-canon (projectile de zone, 3 et plus) ;
    Écorcheur : morsure (1), tir du bras-canon (projectile de zone, 2 et plus), PONTE (3 et plus : script/robots/kaijus.lua, aucune arme
    moteur de plus) ; Écorchés : morsure, le hurleur frappe en zone (cri).
]]

local lib = require("prototypes.lib")
local T = require("shared.robots.titans")
local E = require("shared.content.enemies")
local SPR = require("__factorio-overhaul__/graphics/robots/titans/sprites")

local out = {}

local function feuille_anime(id)
  local A = SPR[id]
  assert(A and A.course and A.attaque, "titans : feuilles de " .. tostring(id) .. " absentes (py -3.9 tools/render/pieces/titans/feuilles_titans.py)")
  return A, A
end

--- Une couche d'une animation : `c` (feuille), `a` (animation), `k` échelle du jeu, `extra` posé sur la couche et sa hr_version ; `A` : racine
--- de la feuille (directions, reduc). Forme vanilla des déchiqueteurs (biterrunanimation) : `filenames` + `lines_per_file` + `line_length` +
--- `slice` (OBLIGATOIRE avec `filenames`, prototype-api.json ; le moteur refusait « Key "slice" not found », banc content V0677) ; la grille
--- d'un fichier est exactement ll × lpf = images d'UNE direction (lecture continue, direction par direction).
local function couche(A, c, a, k, extra)
  local d = c.dens or a.densite  -- densité de la couche (px par tuile de la feuille hr ; FINITIONS : propre à chaque couche)
  local layer = {
    filenames = c.lr, lines_per_file = c.lpf, line_length = c.ll, slice = c.ll, width = c.lw, height = c.lh, frame_count = a.images, direction_count = A.directions,
    shift = { c.sx * k, c.sy * k }, scale = k * 32 / (d / A.reduc),
    hr_version = {
      filenames = c.hr, lines_per_file = c.lpf, line_length = c.ll, slice = c.ll, width = c.w, height = c.h, frame_count = a.images, direction_count = A.directions,
      shift = { c.sx * k, c.sy * k }, scale = k * 32 / d,
    },
  }
  for key, v in pairs(extra or {}) do
    layer[key] = v
    layer.hr_version[key] = v
  end
  return layer
end

--- Animation complète (corps, lueur teintée par `j.tint` à l'alpha `j.glow`, ombre) de l'entrée `S` (course/attaque) d'une feuille `A`.
local function animation(A, S, nom, j, vitesse)
  local a = S[nom]
  local k = j.scale
  local g = j.glow
  local lueur = { draw_as_glow = true, blend_mode = "additive", tint = { r = j.tint.r * g, g = j.tint.g * g, b = j.tint.b * g, a = g } }
  local ombre = { draw_as_shadow = true }
  local principal = {}
  if vitesse then principal.animation_speed, lueur.animation_speed, ombre.animation_speed = vitesse, vitesse, vitesse end
  return { layers = {
    couche(A, a.couches.main, a, k, principal),
    couche(A, a.couches.glow, a, k, lueur),
    couche(A, a.couches.shadow, a, k, ombre),
  } }
end

local function degats(amount, dtype)
  return { type = "damage", damage = { amount = amount, type = dtype } }
end

-- projectile des armes à distance (impulsion du cristallin ères 3 et plus, tir de l'Écorcheur ères 2 et plus) : fusée vanilla recolorée,
-- explosion de zone cyan (un prototype par archétype et par ère, copié de ce modèle)
local projectile
do
  local p = lib.copy("projectile", "rocket")
  p.name = T.PREFIX .. "impulsion"
  p.localised_name = { "entity-name." .. T.PREFIX .. "impulsion" }
  p.acceleration = 0.02
  p.turn_speed = 0.02
  p.light = { intensity = 0.8, size = 10, color = { r = 0.3, g = 0.9, b = 1.0 } }
  lib.tint_sprites(p, { r = 0.3, g = 0.95, b = 1.0 })
  p.action = nil -- posé par ère ci-dessous (copie par ère)
  projectile = p
end

local base_icon = data.raw.unit["behemoth-biter"]

--- Arme à distance d'un Kaiju : projectile de zone (nom `nom`, portée, rayon, cadence) sur l'attaque `ap` d'avant (animation et son gardés).
local function arme_projectile(u, j, nom, range, radius, cooldown, dist)
  local proj = table.deepcopy(projectile)
  proj.name = nom
  proj.action = { type = "area", radius = radius, action_delivery = { type = "instant", target_effects = {
    degats(j.morsure * 0.6, "explosion"), degats(j.morsure * 0.6, "laser"),
    { type = "create-entity", entity_name = "big-explosion" },
  } } }
  out[#out + 1] = proj
  local ap = u.attack_parameters
  u.attack_parameters = {
    type = "projectile", range = range, min_attack_distance = 6, cooldown = cooldown, cooldown_deviation = 0.1,
    ammo_category = "melee", projectile_creation_distance = dist,
    ammo_type = { category = "melee", target_type = "position", clamp_position = true,
      action = { type = "direct", action_delivery = { type = "projectile", projectile = proj.name, starting_speed = 0.35 } } },
    animation = ap.animation, sound = ap.sound, range_mode = "bounding-box-to-bounding-box",
  }
end

--- Arme de contact : morsure directe, ou coup de zone (`radius`) avec l'éclair des griffes.
local function arme_contact(u, j, range, cooldown, radius)
  local ap = u.attack_parameters
  ap.range = range
  ap.cooldown = cooldown
  ap.range_mode = "bounding-box-to-bounding-box"
  if radius then
    ap.ammo_type = { category = "melee", target_type = "entity",
      action = { type = "area", radius = radius, force = "not-same", action_delivery = { type = "instant", target_effects = {
        degats(j.morsure, "physical"), { type = "create-entity", entity_name = T.PREFIX .. "griffe" } } } } }
  else
    ap.ammo_type = { category = "melee", target_type = "entity",
      action = { type = "direct", action_delivery = { type = "instant", target_effects = { degats(j.morsure, "physical") } } } }
  end
end

--- Dépouille : celle du béhémoth à l'échelle, teintée de l'ère.
local function depouille(u, j, taille)
  local corpse = lib.copy("corpse", "behemoth-biter-corpse")
  corpse.name = j.name .. "-corpse"
  local t2 = { r = j.tint.r, g = j.tint.g, b = j.tint.b, a = 1 }
  add_biter_die_animation(taille, { r = 0.04, g = 0.03, b = 0.06, a = 1 }, t2, corpse)
  corpse.localised_name = { "", u.localised_name, " (", { "fo-enemy.corpse" }, ")" }
  u.corpse = corpse.name
  lib.set_icons(corpse, lib.tier_icons(base_icon.icon, base_icon.icon_size, t2, nil, base_icon.icon_mipmaps))
  out[#out + 1] = corpse
end

---------------------------------------------------------------------------------------------------
-- Kaijus : un `unit` par archétype et par ère ouverte
---------------------------------------------------------------------------------------------------
for ik, kk in ipairs(T.KAIJUS) do
  local A, S = feuille_anime(kk.id)
  for era = kk.era_min, T.ERAS do
    local j = T.kaiju(era, kk)
    local u = lib.copy("unit", "behemoth-biter")
    u.name = j.name
    u.order = string.format("b-a-z[fo]-titan-%d-%d", ik, era)
    u.localised_name = { "entity-name." .. j.name }
    u.localised_description = { "entity-description." .. T.PREFIX .. kk.id }
    u.max_health = j.hp
    u.healing_per_tick = j.hp / 60 / 1200
    u.movement_speed = j.speed
    u.resistances = table.deepcopy(j.resistances)
    u.vision_distance = j.vision
    u.pollution_to_join_attack = j.pollution
    u.collision_box = { { -E.BOX_HALF_MAX, -E.BOX_HALF_MAX }, { E.BOX_HALF_MAX, E.BOX_HALF_MAX } }
    u.selection_box = { { -4 * j.scale, -4.5 * j.scale }, { 4 * j.scale, 1.5 * j.scale } }
    u.sticker_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }
    u.run_animation = animation(A, S, "course", j)
    u.distance_per_frame = A.foulee * A.K * j.scale / S.course.images
    u.water_reflection = nil
    u.dying_explosion = "massive-explosion"
    u.map_color = { r = j.tint.r, g = j.tint.g, b = j.tint.b }
    u.affected_by_tides = nil
    u.attack_parameters.animation = animation(A, S, "attaque", j, 0.25)
    u.attack_parameters.damage_modifier = nil
    if j.arme == "impulsion" then
      arme_projectile(u, j, T.PREFIX .. "impulsion-" .. era, j.impulsion_range, j.impulsion_radius, j.impulsion_cooldown, 3.5 * j.scale)
    elseif j.armes.tir then
      -- Écorcheur : le tir du bras-canon dès l'ère 2 ; la ponte (ère 3 et plus) est au script, l'arme moteur reste le tir
      arme_projectile(u, j, T.PREFIX .. kk.id .. "-tir-" .. era, j.tir_range, j.tir_radius, j.tir_cooldown, 3.0 * j.scale)
    elseif j.arme == "griffes" then
      arme_contact(u, j, 3.0 * j.scale, j.morsure_cooldown, j.griffes_radius)
    else
      arme_contact(u, j, 3.0 * j.scale, j.morsure_cooldown, nil)
    end
    depouille(u, j, 4.0 * j.scale)
    lib.set_icons(u, { { icon = A.icone.filename, icon_size = A.icone.size } })
    out[#out + 1] = u
    -- nids vanilla : le Kaiju de l'ère, tard dans l'évolution, rare
    table.insert(data.raw["unit-spawner"]["biter-spawner"].result_units, { j.name, T.kaiju_curve(era, kk) })
  end
end

---------------------------------------------------------------------------------------------------
-- Écorchés : un `unit` par variante et par ère ouverte (feuilles : stade = variante)
---------------------------------------------------------------------------------------------------
do
  local A = SPR[T.ECORCHE.id]
  assert(A and A.anime, "titans : feuilles des Écorchés absentes (py -3.9 tools/render/pieces/titans/feuilles_titans.py)")
  for iv, v in ipairs(T.ECORCHE.variants) do
    local S = A[tostring(iv)]
    assert(S and S.course and S.attaque, "titans : feuille de l'Écorché " .. v.id .. " absente")
    for era = T.ECORCHE.era_min, T.ERAS do
      local m = T.ecorche(v, era)
      local u = lib.copy("unit", "behemoth-biter")
      u.name = m.name
      u.order = string.format("b-a-z[fo]-ecorche-%d-%d", iv, era)
      u.localised_name = { "entity-name." .. m.name }
      u.localised_description = { "entity-description." .. T.PREFIX .. T.ECORCHE.id .. "-" .. v.id }
      u.max_health = m.hp
      u.healing_per_tick = m.hp / 60 / 600
      u.movement_speed = m.speed
      u.resistances = table.deepcopy(m.resistances)
      u.vision_distance = m.vision
      u.pollution_to_join_attack = m.pollution
      local hb = math.min(E.BOX_HALF_MAX, 0.55 * m.scale)
      u.collision_box = { { -hb, -hb }, { hb, hb } }
      u.selection_box = { { -1.4 * m.scale, -1.6 * m.scale }, { 1.4 * m.scale, 0.6 * m.scale } }
      u.sticker_box = { { -0.6, -0.6 }, { 0.6, 0.6 } }
      u.run_animation = animation(A, S, "course", m)
      u.distance_per_frame = A.foulee * m.scale / S.course.images
      u.water_reflection = nil
      u.dying_explosion = "medium-explosion"
      u.map_color = { r = m.tint.r, g = m.tint.g, b = m.tint.b }
      u.affected_by_tides = nil
      u.attack_parameters.animation = animation(A, S, "attaque", m, 0.3)
      u.attack_parameters.damage_modifier = nil
      arme_contact(u, m, 1.2 * m.scale, m.cooldown, m.cri_radius)
      depouille(u, m, 1.4 * m.scale)
      lib.set_icons(u, { { icon = S.icone.filename, icon_size = S.icone.size } })
      out[#out + 1] = u
      table.insert(data.raw["unit-spawner"]["biter-spawner"].result_units, { m.name, T.ecorche_curve(v, era) })
    end
  end
end

data:extend(out)
