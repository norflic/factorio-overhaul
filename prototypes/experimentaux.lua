--[[
  Lot EXPERIMENTAUX (3/11) : prototypes des robots expérimentaux de la famille EXP2. Données et règles : shared/robots/experimentaux.lua ;
  exécution : script/robots/experimentaux.lua ; images : graphics/robots/experimentaux (D-6, PNG hors de git, régénérés par
  tools/render/pieces/experimentaux/feuilles_xp.py ; sprites.lua et MANIFEST.json commités).

  Palier 1, les 5 petits, chacun en UNE image de corps (FAISABILITE : « tous tiennent en 1 image de corps pour tous les caps ») :
  - Mât-Foudre : `electric-turret`, arc d'un rayon électrique vanilla ; le script fait sauter l'arc vers 2 autres cibles ;
  - Sarracénie : `turret` (sans munition, comme un ver), jet d'acide vanilla teinté et flaques ; le script lance 2 jets de plus ;
  - Veilleuse : `turret`, une goutte magenta lancée en cloche (un jet) qui éclate ; plaque de verre au sol ;
  - Géode, Demi-Vie : `unit` à 1 image, LANCÉES par une capsule (le script pose l'unité au point visé, de la force du lanceur) ;
    Géode : pointes violettes qui courent vers la cible ; Demi-Vie : fusion verte (explosion nucléaire vanilla teintée), zone contaminée.
  Le corps est dans les animations de la tourelle (couche « object », triée en profondeur), pas dans `base_picture` (couche basse : un
  déchiqueteur passerait devant la tour). L'attaque du moteur ne lève qu'un effet `script` : tous les dégâts sont du script (mesurés).
  À charger APRÈS prototypes/robots.lua (catégories des usines, technologies des robots) : voir data.lua.
]]

local lib = require("prototypes.lib")
local Xp = require("shared.robots.experimentaux")
local Ro = require("shared.content.robots")
local C = require("shared.content.crafts")
local SPR = require("__factorio-overhaul__/graphics/robots/experimentaux/sprites")

local out = {}

out[#out + 1] = { type = "item-subgroup", name = Xp.SUBGROUP, group = "combat", order = "z[fo]-robots-xp" }
out[#out + 1] = { type = "ammo-category", name = Xp.AMMO_CATEGORY }

local VIDE = "__core__/graphics/empty.png"

---------------------------------------------------------------------------------------------------
-- Images
---------------------------------------------------------------------------------------------------
--- Une couche de corps : RotatedAnimation d'1 direction, 1 image ; normale (plancher) + hr_version.
local function couche(def, opts)
  local function une(r)
    local t = { filename = r.filename, width = r.width, height = r.height, scale = r.scale, shift = { def.shift[1], def.shift[2] },
      direction_count = 1, frame_count = 1, priority = "high" }
    if opts.ombre then
      t.draw_as_shadow = true
    elseif opts.lueur then
      t.draw_as_glow = true
      t.blend_mode = "additive"
    end
    return t
  end
  local t = une(def.lr)
  t.hr_version = une(def.hr)
  return t
end

--- Le corps complet d'un expérimental : principale, lueurs (vues de nuit), ombre.
local function corps(id)
  local s = SPR.corps[id]
  assert(s, "experimentaux : corps sans feuille " .. id)
  local layers = { couche(s.main, {}) }
  for _, g in ipairs(s.lueurs) do layers[#layers + 1] = couche(g, { lueur = true }) end
  layers[#layers + 1] = couche(s.ombre, { ombre = true })
  return { layers = layers }
end

local function icones(id)
  local i = SPR.corps[id].icone
  return { { icon = i.filename, icon_size = i.size } }
end

local function vide_rot()
  return { filename = VIDE, width = 1, height = 1, direction_count = 1, frame_count = 1, priority = "low" }
end

--- Un effet procédural (sprite) : feuille normale + hr_version.
local function effet_sprite(cle)
  local e = SPR.effets[cle]
  local function une(r)
    local t = { filename = r.filename, width = r.width, height = r.height, scale = r.scale, shift = { e.shift[1], e.shift[2] }, priority = "medium" }
    if e.additif then t.blend_mode = "additive"; t.draw_as_glow = true end
    return t
  end
  local t = une(e.lr)
  t.hr_version = une(e.hr)
  return t
end

for _, cle in ipairs({ "pointe", "pointe-lueur", "eclair", "verre" }) do
  local s = effet_sprite(cle)
  s.type = "sprite"
  s.name = Xp.PREFIX .. cle
  s.flags = { "group=none" }
  out[#out + 1] = s
end

---------------------------------------------------------------------------------------------------
-- Effets du moteur réutilisés (0 image neuve)
---------------------------------------------------------------------------------------------------
local function script_action(effect_id, extra)
  local te = { { type = "script", effect_id = effect_id } }
  for _, e in ipairs(extra or {}) do te[#te + 1] = e end
  return { type = "direct", action_delivery = { type = "instant", target_effects = te } }
end

-- Mât-Foudre : rayon électrique vanilla ; l'arc de la tourelle (effet script) et le saut (visuel seul, posé par le script).
do
  local arc = table.deepcopy(data.raw.beam["electric-beam"])
  arc.name = Xp.PREFIX .. "arc"
  arc.localised_name = { "entity-name." .. Xp.PREFIX .. "mat-foudre" }
  arc.damage_interval = 20
  arc.action = script_action(Xp.EFFECT.arc)
  out[#out + 1] = arc
  local saut = table.deepcopy(data.raw.beam["electric-beam-no-sound"])
  saut.name = Xp.PREFIX .. "arc-saut"
  saut.localised_name = { "entity-name." .. Xp.PREFIX .. "mat-foudre" }
  saut.action = nil
  saut.damage_interval = 1000
  out[#out + 1] = saut
end

--- Un jet (fonctions globales vanilla `acid_stream`, `acid_splash_fire` de spitter-projectiles.lua) dont l'arrivée lève un effet script.
local function jet(name, tint, effect_id, fire_name, scale, owner)
  local s = acid_stream({
    name = name, scale = scale, tint = tint, corpse_name = "acid-splash-worm-big", spit_radius = 1.5,
    particle_spawn_interval = 1, particle_spawn_timeout = 6, splash_fire_name = fire_name or "acid-splash-fire-worm-big",
    sticker_name = "acid-sticker-big",
  })
  local te = { { type = "script", effect_id = effect_id } }
  if fire_name then te[#te + 1] = { type = "create-fire", entity_name = fire_name, tile_collision_mask = { "water-tile" }, show_in_tooltip = true } end
  s.initial_action = { { type = "direct", action_delivery = { type = "instant", target_effects = te } } }
  s.special_neutral_target_damage = nil
  s.localised_name = { "entity-name." .. Xp.PREFIX .. owner }
  return s
end

-- Sarracénie : acide vif, flaques qui piquent les unités ennemies au sol (le seul dégât du moteur, hors journal).
local SARR = Xp.robot("sarracenie")
local SARR_TINT = { r = 0.55, g = 1.0, b = 0.25, a = 0.9 }
do
  local flaque = acid_splash_fire({
    name = Xp.PREFIX .. "sarracenie-flaque", scale = 1.1, tint = SARR_TINT, ground_patch_scale = 1.1 * 0.65, patch_tint_multiplier = 0.7,
    splash_damage_per_tick = SARR.dps * SARR.puddle_share / 60, sticker_name = "acid-sticker-big",
  })
  flaque.localised_name = { "entity-name." .. Xp.PREFIX .. "sarracenie-flaque" }
  out[#out + 1] = flaque
  out[#out + 1] = jet(Xp.PREFIX .. "sarracenie-jet", SARR_TINT, Xp.EFFECT.crachat, flaque.name, 1.1, "sarracenie")
  out[#out + 1] = jet(Xp.PREFIX .. "sarracenie-jet2", SARR_TINT, Xp.EFFECT.jet, flaque.name, 0.9, "sarracenie")
end

-- Veilleuse : la goutte (un jet magenta, sans flaque) et son éclair.
do
  out[#out + 1] = jet(Xp.PREFIX .. "veilleuse-goutte", { r = 1.0, g = 0.3, b = 0.85, a = 0.9 }, Xp.EFFECT.goutte, nil, 1.3, "veilleuse")
  out[#out + 1] = {
    type = "explosion", name = Xp.PREFIX .. "veilleuse-eclair", flags = { "not-on-map", "hidden" }, subgroup = "explosions",
    localised_name = { "entity-name." .. Xp.PREFIX .. "veilleuse-eclair" },
    animations = { { filename = SPR.effets.eclair.lr.filename, width = SPR.effets.eclair.lr.width, height = SPR.effets.eclair.lr.height,
      scale = SPR.effets.eclair.lr.scale, frame_count = 1, line_length = 1, animation_speed = 1 / 18, blend_mode = "additive", draw_as_glow = true,
      hr_version = { filename = SPR.effets.eclair.hr.filename, width = SPR.effets.eclair.hr.width, height = SPR.effets.eclair.hr.height,
        scale = SPR.effets.eclair.hr.scale, frame_count = 1, line_length = 1, animation_speed = 1 / 18, blend_mode = "additive", draw_as_glow = true } } },
    scale_initial = 0.4, scale_end = 1.3, scale_in_duration = 6, fade_out_duration = 14,
    light = { intensity = 0.9, size = 14, color = { r = 1.0, g = 0.3, b = 0.85 } },
    sound = data.raw.explosion["big-explosion"].sound,
  }
end

-- Demi-Vie : explosion nucléaire vanilla teintée en vert ; nuage de contamination vanilla teinté (visuel seul : les dégâts sont du script).
local DV = Xp.robot("demi-vie")
do
  local f = table.deepcopy(data.raw.explosion["nuke-explosion"])
  f.name = Xp.PREFIX .. "demi-vie-fusion"
  f.localised_name = { "entity-name." .. f.name }
  lib.tint_sprites(f.animations, { r = 0.55, g = 1.0, b = 0.45 })
  f.light = { intensity = 1, size = 40, color = { r = 0.45, g = 1.0, b = 0.3 } }
  out[#out + 1] = f
  local nuage = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud-visual-dummy"])
  nuage.name = Xp.PREFIX .. "demi-vie-nuage"
  nuage.duration = DV.contamination.duration
  nuage.color = { r = 0.25, g = 0.6, b = 0.05, a = 0.35 }
  nuage.action = nil
  nuage.localised_name = { "entity-name." .. f.name }
  out[#out + 1] = nuage
  local zone = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud"])
  zone.name = Xp.PREFIX .. "demi-vie-zone"
  zone.duration = DV.contamination.duration
  zone.color = { r = 0.35, g = 0.9, b = 0.1, a = 0.6 }
  zone.action = nil
  zone.localised_name = { "entity-name." .. f.name }
  -- nuages du jeu de base, sans leur son (l'explosion a le sien)
  for _, cl in ipairs(zone.created_effect or {}) do
    local keep = {}
    for _, te in ipairs(cl.action_delivery and cl.action_delivery.target_effects or {}) do
      if te.type == "create-smoke" then
        te.entity_name = nuage.name
        keep[#keep + 1] = te
      end
    end
    cl.action_delivery.target_effects = keep
  end
  out[#out + 1] = zone
end

---------------------------------------------------------------------------------------------------
-- Les 5 petits : entité, objet, recette, technologie
---------------------------------------------------------------------------------------------------
local function boite(foot, marge)
  local h = foot / 2 - marge
  return { { -h, -h }, { h, h } }
end

local function ingredients(list)
  local l = {}
  for _, g in ipairs(list) do l[#l + 1] = { type = "item", name = g[1], amount = g[2] } end
  return l
end

--- Bouche d'une tourelle : haut de la lueur (arc, urnes, soleil captif) ou du corps.
local function bouche(id, nom_lueur)
  local s = SPR.corps[id]
  for _, g in ipairs(s.lueurs) do
    if g.nom == nom_lueur then return { 0, g.shift[2] } end
  end
  return { 0, s.main.shift[2] }
end

local function base_tourelle(r, type_)
  local body = corps(r.id)
  local t = {
    type = type_, name = r.name,
    localised_name = { "entity-name." .. r.name }, localised_description = { "entity-description." .. r.name },
    icons = icones(r.id),
    flags = { "placeable-player", "player-creation" },
    minable = { mining_time = 1, result = r.name },
    max_health = r.hp,
    collision_box = boite(r.foot, 0.3), selection_box = boite(r.foot, 0),
    corpse = "big-remnants", dying_explosion = "big-explosion",
    call_for_help_radius = 40,
    rotation_speed = 1,
    folded_animation = body, preparing_animation = body, prepared_animation = body, folding_animation = body,
    preparing_speed = 0.2, folding_speed = 0.2,
    map_color = { r = r.lueur.r * 0.8, g = r.lueur.g * 0.8, b = r.lueur.b * 0.8 },
    friendly_map_color = { r = r.lueur.r, g = r.lueur.g, b = r.lueur.b },
    alert_when_attacking = true,
    vehicle_impact_sound = data.raw["ammo-turret"]["gun-turret"].vehicle_impact_sound,
    damaged_trigger_effect = data.raw["ammo-turret"]["gun-turret"].damaged_trigger_effect,
    order = string.format("z[fo-xp]-%02d", r.age),
  }
  return t
end

local function mat_foudre(r)
  local t = base_tourelle(r, "electric-turret")
  local src = bouche(r.id, "arc")
  t.energy_source = { type = "electric", buffer_capacity = "3MJ", input_flow_limit = "6MW", drain = "40kW", usage_priority = "primary-input" }
  t.attack_parameters = {
    type = "beam", ammo_category = Xp.AMMO_CATEGORY, cooldown = r.cooldown, range = r.range,
    source_direction_count = 1, source_offset = src,
    ammo_type = {
      category = Xp.AMMO_CATEGORY, energy_consumption = "1500kJ",
      action = { type = "direct", action_delivery = { type = "beam", beam = Xp.PREFIX .. "arc", max_length = r.range + 12, duration = 20,
        source_offset = src } },
    },
  }
  return t
end

local function crachat(r, stream, urne)
  local t = base_tourelle(r, "turret")
  local src = bouche(r.id, urne)
  t.attack_parameters = {
    type = "stream", ammo_category = Xp.AMMO_CATEGORY, cooldown = r.cooldown, range = r.range, min_range = 0,
    gun_center_shift = src, gun_barrel_length = 0,
    lead_target_for_projectile_speed = 0.2 * 0.75 * 1.5 * 1.5,
    ammo_type = { category = Xp.AMMO_CATEGORY, action = { type = "direct", action_delivery = { type = "stream", stream = stream, source_offset = { 0, 0 } } } },
  }
  return t
end

--- Unité lancée : 1 image de corps (course et attaque), l'attaque ne lève que l'effet script.
local function unite(r, effect_id)
  local body = corps(r.id)
  local hb = r.half
  return {
    type = "unit", name = r.name,
    localised_name = { "entity-name." .. r.name }, localised_description = { "entity-description." .. r.name },
    icons = icones(r.id),
    flags = { "placeable-player", "placeable-off-grid", "not-repairable", "not-blueprintable", "not-deconstructable" },
    max_health = r.hp, healing_per_tick = 0,
    collision_box = { { -hb, -hb }, { hb, hb } }, selection_box = { { -hb - 0.3, -hb - 1.5 }, { hb + 0.3, hb + 0.3 } },
    sticker_box = { { -hb, -hb }, { hb, hb } },
    movement_speed = r.speed, distance_per_frame = 0.1, run_animation = body,
    distraction_cooldown = 300, min_pursue_time = 600, max_pursue_distance = 50,
    vision_distance = 30, pollution_to_join_attack = 1,
    dying_explosion = "big-explosion", corpse = "medium-remnants",
    rotation_speed = 0.1,
    attack_parameters = {
      type = "projectile", ammo_category = Xp.AMMO_CATEGORY, range = r.range, cooldown = r.cooldown, cooldown_deviation = 0,
      projectile_creation_distance = 0.6, range_mode = "bounding-box-to-bounding-box",
      ammo_type = { category = Xp.AMMO_CATEGORY, action = script_action(effect_id) },
      animation = body,
    },
    ai_settings = { destroy_when_commands_fail = false, allow_try_return_to_spawner = false, do_separation = true },
    map_color = { r = r.lueur.r, g = r.lueur.g, b = r.lueur.b },
    friendly_map_color = { r = r.lueur.r, g = r.lueur.g, b = r.lueur.b },
    order = string.format("z[fo-xp]-%02d", r.age),
    subgroup = Xp.SUBGROUP,
  }
end

--- La capsule qui lance un attaquant (le script pose l'unité au point visé : on_player_used_capsule).
local function capsule(r, i)
  return {
    type = "capsule", name = r.name,
    localised_name = { "entity-name." .. r.name }, localised_description = { "item-description." .. r.name },
    icons = icones(r.id), subgroup = Xp.SUBGROUP, order = string.format("b[xp]-%02d", i), stack_size = 5,
    capsule_action = {
      type = "throw", uses_stack = true,
      attack_parameters = {
        type = "projectile", activation_type = "throw", ammo_category = "capsule", cooldown = 30, projectile_creation_distance = 0.6, range = 30,
        ammo_type = { category = "capsule", target_type = "position",
          action = script_action(Xp.launch_effect(r.id), { { type = "create-entity", entity_name = "explosion-hit" } }) },
      },
    },
  }
end

for i, r in ipairs(Xp.ROBOTS) do
  local cat = Xp.category(r)
  assert(cat, "experimentaux : usine inconnue " .. tostring(r.factory))
  if r.id == "mat-foudre" then
    out[#out + 1] = mat_foudre(r)
  elseif r.id == "sarracenie" then
    out[#out + 1] = crachat(r, Xp.PREFIX .. "sarracenie-jet", "suc")
  elseif r.id == "veilleuse" then
    out[#out + 1] = crachat(r, Xp.PREFIX .. "veilleuse-goutte", "soleil")
  elseif r.id == "geode" then
    out[#out + 1] = unite(r, Xp.EFFECT.buisson)
  elseif r.id == "demi-vie" then
    out[#out + 1] = unite(r, Xp.EFFECT.fusion)
  else
    error("experimentaux : robot sans prototype " .. r.id)
  end
  if r.is_unit then
    out[#out + 1] = capsule(r, i)
  else
    out[#out + 1] = {
      type = "item", name = r.name, localised_name = { "entity-name." .. r.name }, localised_description = { "item-description." .. r.name },
      icons = icones(r.id), subgroup = Xp.SUBGROUP, order = string.format("a[xp]-%02d", i), place_result = r.name, stack_size = 5,
    }
  end
  out[#out + 1] = {
    type = "recipe", name = r.recipe, category = cat, enabled = false, energy_required = r.time,
    ingredients = ingredients(r.ingredients), results = { { type = "item", name = r.name, amount = 1 } }, main_product = r.name,
    localised_name = { "entity-name." .. r.name },
  }
  local after = Ro.tech(r.after)
  assert(after, "experimentaux : technologie de robot absente " .. tostring(r.after))
  out[#out + 1] = lib.technology({
    name = r.tech,
    localised_name = { "technology-name." .. r.tech }, localised_description = { "technology-description." .. r.tech },
    icons = { { icon = SPR.corps[r.id].icone.filename, icon_size = 64 } },
    effects = { lib.unlock(r.recipe) }, prerequisites = { r.after },
    count = C.tech_count({ epoch = r.age, count = after.count }), packs = C.packs(r.age), time = 30,
    order = "z[fo]-robots-xp-" .. string.format("%02d", r.age),
  })
end

data:extend(out)
