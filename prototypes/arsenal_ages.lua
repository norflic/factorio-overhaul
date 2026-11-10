--[[
  Lot ARMES-AGES (9/11) : prototypes de la lignée « Bastion » (une tourelle par âge d'armement, un MODE d'attaque par âge), des
  armes de poing expérimentales et de la frappe orbitale. Données : shared/content/arsenal.lua (A.ages, A.hand_weapons,
  A.cataclysm). Requis par prototypes/arsenal_special.lua (déjà requis par data.lua après l'arsenal : data.lua n'est pas touché).
  Zéro image nouvelle : sprites vanilla copiés, teintés, mis à l'échelle (ce qui mériterait un rendu Blender : rapport du lot).

  Mécaniques 1.1 RÉELLEMENT utilisées, et leurs limites :
  - âge 1 cinétique : ammo-turret (copie de gun-turret), chargeurs « bullet » (reçoit l'effet script des tirs par âge, lot TIRS) ;
  - âge 2 laser : electric-turret, faisceau = copie de laser-beam en textures blanches teintées (K.faisceau_blanc, lot TIRS) ;
  - âge 3 arc en chaîne : electric-turret, attaque « beam ». Le faisceau principal (copie d'electric-beam) frappe la cible, puis, par
    `nested-result` + `area` AUTOUR DE LA CIBLE, livre à chaque ennemi voisin des dégâts (maillon 2) et un faisceau
    (BeamTriggerDelivery, add_to_shooter = false) dont l'action frappe à son tour les voisins de SA cible (maillon 3).
    La géométrie des DÉGÂTS est une vraie chaîne (cible → voisins → voisins des voisins). LIMITE : un faisceau de livraison part
    de la SOURCE du déclencheur ; pour l'action d'un faisceau, c'est la tourelle : les arcs du maillon 2 peuvent partir de la
    tourelle plutôt que de la première cible (à voir en moteur réel). Le Mât-Foudre (script/robots/experimentaux.lua) pose ses
    sauts par script (Xp.chain) : même recette possible ici si le DC veut l'arc qui court de cible en cible (require dans control.lua) ;
  - âge 4 plasma : electric-turret à attaque « projectile » (orbe = copie d'explosive-rocket, guidée), explosion de zone ;
  - lanceur de singularités : smoke-with-trigger (copie de poison-cloud) : dégâts de zone + sticker de ralentissement ; PAS
    d'attraction native en 1.1 : les ennemis sont retenus, pas tirés vers le centre ;
  - projecteur de champ : active-defense-equipment + télécommande (equipment-remote, comme la décharge défensive vanilla) :
    push-back, sticker, anneau de `fire` à durée bornée. LIMITE : un feu n'a pas de filtre de force : le porteur qui marche
    dans l'anneau se brûle aussi ; aucun prototype 1.1 n'a à la fois une collision et une durée de vie (pas de « mur temporaire ») ;
  - frappe orbitale : capsule → projectile → drone de marquage (combat-robot immobile, time_to_live = délai) → destroy_action =
    la frappe. LIMITE : un drone tué avant terme frappe plus tôt (la destroy_action court à la mort comme à l'expiration).
]]

local lib = require("prototypes.lib")
local Evo = require("prototypes.evolution")
local K = require("prototypes.tirs_kit")
local A = require("shared.content.arsenal")

local out = {}
local unlocks = {} -- [nom de technologie] = { recettes }

local function unlock(tech, recipe)
  unlocks[tech] = unlocks[tech] or {}
  table.insert(unlocks[tech], recipe)
end

local function dmg(amount, dtype)
  return { type = "damage", damage = { amount = amount, type = dtype } }
end

local function area(radius, force, deliveries)
  return { type = "nested-result", action = { type = "area", radius = radius, force = force, action_delivery = deliveries } }
end

local function hand(name)
  for _, h in ipairs(A.hand_weapons) do if h.name == name then return h end end
  error("arsenal_ages : arme de poing absente des données : " .. name)
end

--- Prototype d'icône (objet, munition, arme, capsule, technologie).
local function icon_of(name)
  for _, t in ipairs({ "item", "ammo", "gun", "capsule", "tool", "technology" }) do
    local p = data.raw[t] and data.raw[t][name]
    if p and p.icon then return p end
  end
  error("arsenal_ages : icône vanilla introuvable : " .. tostring(name))
end

--- Icône teintée + pastille d'une seconde icône (rôle de l'arme), comme l'arsenal spécial.
local function composed_icons(base, tint, overlay)
  local icons = { { icon = base.icon, icon_size = base.icon_size, icon_mipmaps = base.icon_mipmaps, tint = tint } }
  if overlay then
    icons[#icons + 1] = {
      icon = overlay.icon, icon_size = overlay.icon_size, icon_mipmaps = overlay.icon_mipmaps,
      scale = 0.5 * 32 / (overlay.icon_size or 64) * 1.25, shift = { 8, 8 },
    }
  end
  return icons
end

local function energie(str, k)
  local num, unit = str:match("^([%d%.]+)(%a+)$")
  return tostring(tonumber(num) * k) .. unit
end

local function tint_glow_anim(anim, tint)
  -- animation « draw_as_glow » (roquette) : lib.tint_sprites l'ignore volontairement ; la teinte se pose à la main
  if type(anim) ~= "table" then return end
  if anim.filename then anim.tint = tint end
  if anim.hr_version then anim.hr_version.tint = tint end
  for _, l in ipairs(anim.layers or {}) do tint_glow_anim(l, tint) end
end

---------------------------------------------------------------------------------------------------
-- La lignée Bastion : socle commun
---------------------------------------------------------------------------------------------------
local SPRITE_FIELDS = {
  "base_picture", "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "folding_animation",
}
local ANIM_FIELDS = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "folding_animation" }

local function turret_base(spec)
  local t = lib.copy(spec.copy_type, spec.copy)
  t.name = spec.name
  t.localised_name = { "entity-name." .. spec.name }
  t.localised_description = { "entity-description." .. spec.name }
  t.max_health = spec.hp
  t.minable = { mining_time = 0.5, result = spec.name }
  t.next_upgrade = nil
  for _, f in ipairs(SPRITE_FIELDS) do
    if t[f] then lib.tint_sprites(t[f], spec.tint) end
  end
  if spec.glow then
    for _, f in ipairs(ANIM_FIELDS) do
      if t[f] then
        Evo.glow_masks(t[f], spec.glow, 0.9)
        Evo.light_layers(t[f], spec.glow, 0.45)
      end
    end
    if t.energy_glow_animation then lib.tint_sprites(t.energy_glow_animation, spec.glow) end
  end
  if spec.platform == "artillery" then
    -- âge 4 : socle d'artillerie réduit (silhouette de pièce lourde), la tête laser par-dessus
    local b = table.deepcopy(data.raw["artillery-turret"]["artillery-turret"].base_picture)
    lib.scale_sprites(b, 0.62)
    lib.tint_sprites(b, { r = 0.80, g = 0.72, b = 0.86 })
    t.base_picture = b
  end
  local ic = icon_of(spec.copy)
  lib.set_icons(t, lib.tier_icons(ic.icon, ic.icon_size, spec.tint, spec.age, ic.icon_mipmaps))
  return t
end

local function energy_source(t, buffer, input, drain)
  t.energy_source = table.deepcopy(t.energy_source)
  t.energy_source.buffer_capacity = buffer
  t.energy_source.input_flow_limit = input
  t.energy_source.drain = drain
end

local function finish_turret(t, spec)
  out[#out + 1] = t
  local ic = icon_of(spec.copy)
  local item = lib.copy("item", spec.copy)
  item.name = spec.name
  item.place_result = spec.name
  item.localised_name = { "entity-name." .. spec.name }
  item.localised_description = { "entity-description." .. spec.name }
  item.order = (item.order or "b") .. "-z[fo-bastion]-" .. spec.age
  lib.set_icons(item, lib.tier_icons(ic.icon, ic.icon_size, spec.tint, spec.age, ic.icon_mipmaps))
  out[#out + 1] = item
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, 20)
  unlock(spec.tech.name, spec.name)
end

---------------------------------------------------------------------------------------------------
-- Âge 1 : cinétique (mitrailleuse renforcée, chargeurs « bullet »)
---------------------------------------------------------------------------------------------------
do
  local spec = A.age_turret(1)
  local t = turret_base(spec)
  local ap = t.attack_parameters
  ap.range = spec.range
  ap.cooldown = spec.cooldown
  ap.damage_modifier = (ap.damage_modifier or 1) * spec.damage_modifier
  ap.ammo_category = spec.ammo_category
  finish_turret(t, spec)
end

---------------------------------------------------------------------------------------------------
-- Âge 2 : laser focalisé (faisceau blanc teinté cyan, plus épais, portée et dégâts relevés)
---------------------------------------------------------------------------------------------------
do
  local spec = A.age_turret(2)
  local t = turret_base(spec)
  local beam = lib.copy("beam", spec.beam.copy)
  beam.name = spec.name .. "-beam"
  beam.localised_name = { "entity-name." .. spec.name }
  local te = spec.beam.teinte
  K.faisceau_blanc(beam, { teinte = te, coeur = spec.beam.coeur, epaisseur = spec.beam.epaisseur,
    sol = { te[1] * 0.6, te[2] * 0.6, te[3] * 0.6 } })
  out[#out + 1] = beam
  local ap = t.attack_parameters
  ap.range = spec.range
  ap.cooldown = spec.cooldown
  ap.damage_modifier = spec.damage_modifier
  ap.ammo_type.energy_consumption = spec.energy
  local d = ap.ammo_type.action.action_delivery
  d.beam = beam.name
  d.max_length = spec.range + 2
  local es = t.energy_source
  energy_source(t, energie(es.buffer_capacity, spec.energy_scale), energie(es.input_flow_limit, spec.energy_scale), es.drain)
  finish_turret(t, spec)
end

---------------------------------------------------------------------------------------------------
-- Âge 3 : arcs électriques EN CHAÎNE (cible, voisins, voisins des voisins)
---------------------------------------------------------------------------------------------------
do
  local spec = A.age_turret(3)
  local t = turret_base(spec)
  local arc = spec.arc
  local h1, h2 = arc.hops[1], arc.hops[2]
  local function beam_of(name, copy, interval, effects)
    local b = lib.copy("beam", copy)
    b.name = name
    b.localised_name = { "entity-name." .. spec.name }
    b.damage_interval = interval
    b.action = { type = "direct", action_delivery = { type = "instant", target_effects = effects } }
    return b
  end
  -- maillon 2 (arc visible vers chaque voisin) : son action frappe les voisins de SA cible (maillon 3, dégâts seuls)
  local hop_name = spec.name .. "-arc-2"
  local hop_effects = { { type = "create-entity", entity_name = "explosion-hit" } }
  if h2 then
    hop_effects[#hop_effects + 1] = area(h2.radius, "enemy", { type = "instant", target_effects = { dmg(arc.damage * h2.share, "electric") } })
  end
  out[#out + 1] = beam_of(hop_name, "electric-beam-no-sound", 10, hop_effects)
  -- maillon 1 : la cible, puis les voisins (dégâts garantis par livraison instantanée ; l'arc visible en plus)
  local deliveries = { { type = "instant", target_effects = { dmg(arc.damage * h1.share, "electric") } } }
  if h1.beam then
    deliveries[#deliveries + 1] = { type = "beam", beam = hop_name, max_length = h1.radius + 2, duration = 20, add_to_shooter = false }
  end
  out[#out + 1] = beam_of(spec.name .. "-arc-1", "electric-beam", 20, {
    { type = "create-entity", entity_name = "explosion-hit" },
    dmg(arc.damage, "electric"),
    area(h1.radius, "enemy", deliveries),
  })
  local ap = t.attack_parameters
  ap.range = spec.range
  ap.cooldown = spec.cooldown
  ap.damage_modifier = 1
  ap.ammo_type.category = "electric"
  ap.ammo_type.energy_consumption = spec.energy
  local d = ap.ammo_type.action.action_delivery
  d.beam = spec.name .. "-arc-1"
  d.max_length = spec.range + 2
  -- réserve = 1,5 tir ; recharge d'un tir en ~0,2 s (le tampon copié de la tourelle laser, 801 kJ, ne permettrait aucun tir : F
  -- de la tour à arc, prototypes/arsenal_special.lua)
  energy_source(t, "3MJ", "12000kW", "40kW")
  finish_turret(t, spec)
end

---------------------------------------------------------------------------------------------------
-- Âge 4 : artillerie plasma (orbe guidée, explosion de zone ; socle d'artillerie)
---------------------------------------------------------------------------------------------------
do
  local spec = A.age_turret(4)
  local t = turret_base(spec)
  local P = spec.plasma
  local proj = lib.copy("projectile", "explosive-rocket")
  proj.name = spec.name .. "-orb"
  proj.localised_name = { "entity-name." .. spec.name }
  lib.scale_sprites(proj.animation, 1.6)
  tint_glow_anim(proj.animation, spec.glow)
  proj.light = { intensity = 0.8, size = 8, color = spec.glow }
  proj.action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        { type = "create-entity", entity_name = "big-explosion" },
        dmg(P.direct, "laser"),
        { type = "create-entity", entity_name = "medium-scorchmark-tintable", check_buildability = true },
        area(P.radius, "enemy", { type = "instant", target_effects = { dmg(P.area.laser, "laser"), dmg(P.area.explosion, "explosion") } }),
      },
    },
  }
  out[#out + 1] = proj
  t.attack_parameters = {
    type = "projectile",
    cooldown = spec.cooldown,
    range = spec.range,
    min_range = spec.min_range,
    projectile_creation_distance = 1.4,
    projectile_center = { 0, -0.6 },
    turn_range = 1,
    sound = data.raw.gun["rocket-launcher"].attack_parameters.sound,
    ammo_type = {
      category = "laser",
      energy_consumption = spec.energy,
      action = { type = "direct", action_delivery = { type = "projectile", projectile = proj.name, starting_speed = P.speed } },
    },
  }
  t.prepare_range = spec.range + 4
  energy_source(t, "9MJ", "6000kW", "60kW")
  finish_turret(t, spec)
end

---------------------------------------------------------------------------------------------------
-- Lanceur de singularités : roquette qui ouvre un champ (zone + ralentissement)
---------------------------------------------------------------------------------------------------
do
  local spec = hand("fo-singularity-launcher")
  local F = spec.field
  out[#out + 1] = { type = "ammo-category", name = spec.ammo_category }

  local sticker = lib.copy("sticker", "slowdown-sticker")
  sticker.name = spec.name .. "-sticker"
  sticker.localised_name = { "item-name." .. spec.name }
  sticker.duration_in_ticks = F.slow_ticks
  sticker.target_movement_modifier = F.slow
  out[#out + 1] = sticker

  local cloud = lib.copy("smoke-with-trigger", "poison-cloud")
  cloud.name = spec.name .. "-field"
  cloud.localised_name = { "item-name." .. spec.name }
  cloud.color = { r = 0.40, g = 0.15, b = 0.65, a = 0.69 }
  cloud.duration = F.duration
  cloud.fade_away_duration = 60
  cloud.spread_duration = 10
  cloud.particle_spread = { F.radius * 0.6, F.radius * 0.36 }
  cloud.action_cooldown = F.cooldown
  cloud.created_effect = nil
  cloud.action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        area(F.radius, "enemy", { type = "instant", target_effects = { dmg(F.damage, "electric"), { type = "create-sticker", sticker = sticker.name } } }),
      },
    },
  }
  out[#out + 1] = cloud

  local proj = lib.copy("projectile", "rocket")
  proj.name = spec.name .. "-projectile"
  proj.localised_name = { "item-name." .. spec.name }
  tint_glow_anim(proj.animation, spec.tint)
  proj.light = { intensity = 0.6, size = 6, color = spec.tint }
  proj.action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        { type = "create-entity", entity_name = "medium-explosion" },
        { type = "create-entity", entity_name = cloud.name },
        area(F.radius, "enemy", { type = "instant", target_effects = { dmg(F.burst, "electric"), { type = "create-sticker", sticker = sticker.name } } }),
      },
    },
  }
  out[#out + 1] = proj

  local crystal = icon_of("fo-resonance-crystal")
  local ammo = lib.copy("ammo", "rocket")
  ammo.name = spec.ammo
  ammo.localised_name = { "item-name." .. spec.ammo }
  ammo.localised_description = { "item-description." .. spec.ammo }
  ammo.order = "z[fo]-" .. spec.ammo
  lib.set_icons(ammo, composed_icons(icon_of("rocket"), spec.tint, crystal))
  ammo.ammo_type = {
    category = spec.ammo_category,
    action = {
      type = "direct",
      action_delivery = { type = "projectile", projectile = proj.name, starting_speed = 0.1,
        source_effects = { type = "create-entity", entity_name = "explosion-hit" } },
    },
  }
  out[#out + 1] = ammo
  out[#out + 1] = lib.recipe(spec.ammo, spec.ammo_ingredients, spec.ammo, 1, spec.ammo_energy)
  unlock(spec.tech.name, spec.ammo)

  local gun = lib.copy("gun", spec.copy)
  gun.name = spec.name
  gun.localised_name = { "item-name." .. spec.name }
  gun.localised_description = { "item-description." .. spec.name }
  gun.order = "z[fo]-" .. spec.name
  lib.set_icons(gun, composed_icons(icon_of(spec.copy), spec.tint, crystal))
  gun.attack_parameters.ammo_category = spec.ammo_category
  gun.attack_parameters.range = spec.range
  gun.attack_parameters.cooldown = spec.cooldown
  out[#out + 1] = gun
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, 10)
  unlock(spec.tech.name, spec.name)
end

---------------------------------------------------------------------------------------------------
-- Projecteur de champ : équipement de défense active (onde répulsive + anneau de flammes plasma), télécommande
---------------------------------------------------------------------------------------------------
do
  local spec = hand("fo-field-projector")
  local F = spec.field

  local sticker = lib.copy("sticker", "slowdown-sticker")
  sticker.name = spec.name .. "-sticker"
  sticker.localised_name = { "item-name." .. spec.name }
  sticker.duration_in_ticks = F.slow_ticks
  sticker.target_movement_modifier = F.slow
  out[#out + 1] = sticker

  local flame = lib.copy("fire", "fire-flame")
  flame.name = spec.name .. "-flame"
  flame.localised_name = { "item-name." .. spec.name }
  flame.damage_per_tick = { amount = F.ring.damage_per_tick, type = "electric" }
  flame.spawn_entity = nil
  flame.maximum_spread_count = 0
  flame.initial_lifetime = F.ring.lifetime
  flame.maximum_lifetime = F.ring.lifetime
  flame.lifetime_increase_by = 0
  flame.delay_between_initial_flames = 0
  flame.maximum_damage_multiplier = 1
  flame.damage_multiplier_increase_per_added_fuel = 0
  flame.emissions_per_second = 0
  flame.smoke = nil
  flame.smoke_source_pictures = nil
  flame.burnt_patch_pictures = nil
  flame.burnt_patch_alpha_variations = nil
  lib.tint_sprites(flame.pictures, spec.tint)
  if flame.small_tree_fire_pictures then lib.tint_sprites(flame.small_tree_fire_pictures, spec.tint) end
  flame.light = { intensity = 0.3, size = 6, color = spec.tint }
  out[#out + 1] = flame

  local eq = lib.copy("active-defense-equipment", spec.copy)
  eq.name = spec.name
  eq.localised_name = { "item-name." .. spec.name }
  eq.localised_description = { "item-description." .. spec.name }
  eq.take_result = spec.name
  eq.sprite.tint = spec.tint
  if eq.sprite.hr_version then eq.sprite.hr_version.tint = spec.tint end
  eq.energy_source.buffer_capacity = spec.buffer
  local ap = eq.attack_parameters
  ap.cooldown = spec.cooldown
  ap.range = F.radius
  ap.ammo_type.energy_consumption = spec.energy
  ap.ammo_type.action = {
    {
      type = "area",
      radius = F.radius,
      force = "enemy",
      action_delivery = {
        { type = "instant", target_effects = {
          { type = "create-sticker", sticker = sticker.name },
          { type = "push-back", distance = F.push },
          dmg(F.damage, "electric"),
        } },
        { type = "beam", beam = "electric-beam-no-sound", max_length = F.radius + 4, duration = 15, source_offset = { 0, -0.5 }, add_to_shooter = false },
      },
    },
    {
      type = "cluster",
      cluster_count = F.ring.count,
      distance = F.ring.distance,
      distance_deviation = 0.3,
      action_delivery = {
        type = "instant",
        target_effects = { { type = "create-fire", entity_name = flame.name, initial_ground_flame_count = 1, show_in_tooltip = false } },
      },
    },
  }
  out[#out + 1] = eq

  local shield = icon_of("energy-shield-equipment")
  local item = lib.copy("item", spec.copy)
  item.name = spec.name
  item.placed_as_equipment_result = spec.name
  item.localised_name = { "item-name." .. spec.name }
  item.localised_description = { "item-description." .. spec.name }
  item.order = "z[fo]-" .. spec.name
  lib.set_icons(item, composed_icons(icon_of(spec.copy), spec.tint, shield))
  out[#out + 1] = item
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, 15)
  unlock(spec.tech.name, spec.name)

  local remote = lib.copy("capsule", "discharge-defense-remote")
  remote.name = spec.remote
  remote.localised_name = { "item-name." .. spec.remote }
  remote.localised_description = { "item-description." .. spec.remote }
  remote.order = "z[fo]-" .. spec.remote
  remote.capsule_action = { type = "equipment-remote", equipment = spec.name }
  lib.set_icons(remote, composed_icons(icon_of("discharge-defense-remote"), spec.tint, shield))
  out[#out + 1] = remote
  out[#out + 1] = lib.recipe(spec.remote, spec.remote_ingredients, spec.remote, 1, 0.5)
  unlock(spec.tech.name, spec.remote)
end

---------------------------------------------------------------------------------------------------
-- Frappe orbitale (cataclysmique, activable) : capsule, drone de marquage à retardement, frappe
---------------------------------------------------------------------------------------------------
do
  local spec = A.cataclysm

  local flash = lib.copy("explosion", "nuke-explosion")
  flash.name = spec.name .. "-flash"
  flash.localised_name = { "item-name." .. spec.name }
  lib.tint_sprites(flash.animations, spec.tint)
  flash.light = { intensity = 1, size = 60, color = spec.tint }
  out[#out + 1] = flash

  local strike = {
    { type = "create-entity", entity_name = flash.name },
    { type = "create-entity", entity_name = "huge-scorchmark-tintable", check_buildability = true },
    { type = "camera-effect", effect = "screen-burn", duration = 60, ease_in_duration = 5, ease_out_duration = 60, delay = 0,
      strength = 6, full_strength_max_distance = 200, max_distance = 800 },
  }
  for _, b in ipairs(spec.blast) do
    local te = {}
    if b.laser then te[#te + 1] = dmg(b.laser, "laser") end
    if b.explosion then te[#te + 1] = dmg(b.explosion, "explosion") end
    strike[#strike + 1] = area(b.radius, "not-same", { type = "instant", target_effects = te })
  end

  local marker = lib.copy("combat-robot", spec.marker_copy)
  marker.name = spec.name .. "-marker"
  marker.localised_name = { "item-name." .. spec.name }
  marker.time_to_live = spec.delay
  marker.speed = 0
  marker.follows_player = false
  marker.range_from_player = 0
  marker.working_sound = nil
  marker.max_health = 30
  marker.dying_explosion = nil
  marker.light = { intensity = 0.8, size = 14, color = spec.tint }
  marker.attack_parameters.cooldown = 100000
  marker.attack_parameters.ammo_type.action = nil
  for _, f in ipairs({ "idle", "in_motion" }) do
    if marker[f] then lib.tint_sprites(marker[f], spec.tint) end
  end
  marker.destroy_action = { type = "direct", action_delivery = { type = "instant", source_effects = strike } }
  out[#out + 1] = marker

  local proj = lib.copy("projectile", "poison-capsule")
  proj.name = spec.name .. "-projectile"
  proj.localised_name = { "item-name." .. spec.name }
  lib.tint_sprites(proj.animation, spec.tint)
  proj.action = {
    type = "direct",
    action_delivery = { type = "instant", target_effects = { { type = "create-entity", entity_name = marker.name } } },
  }
  out[#out + 1] = proj

  local cap = lib.copy("capsule", spec.copy)
  cap.name = spec.name
  cap.localised_name = { "item-name." .. spec.name }
  cap.localised_description = { "item-description." .. spec.name }
  cap.order = "z[fo]-" .. spec.name
  lib.set_icons(cap, composed_icons(icon_of(spec.copy), spec.tint, icon_of("atomic-bomb")))
  local ap = cap.capsule_action.attack_parameters
  ap.cooldown = spec.cooldown
  ap.range = spec.range
  ap.ammo_type.action[1].action_delivery.projectile = proj.name
  out[#out + 1] = cap
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, spec.energy)
  unlock(spec.tech.name, spec.name)
end

---------------------------------------------------------------------------------------------------
-- Lot ASSAUTS-TITANESQUES (10/11) : BARRIÈRE ÉNERGÉTIQUE DE PÉRIMÈTRE (A.perimetre). Tourelle électrique 1×1 (emprise d'un mur) à portée
-- courte : arc de champ (copie d'electric-beam teintée) sur l'ennemi qui franchit, dégâts électriques de ZONE autour de lui + autocollant de
-- ralentissement ; sans courant le moteur l'éteint (energy_source électrique). Socle : rendu Blender (graphics/arsenal/barriere/sprites.lua,
-- tools/render/pieces/arsenal/barriere.py, PNG hors git D-6 sauf sprites.lua) ; la tête tournante reste celle de la tourelle laser,
-- réduite et teintée (le moteur tourne la tête ; le socle ne tourne pas).
---------------------------------------------------------------------------------------------------
do
  local spec = A.perimetre
  local F = spec.field
  local SPR = require("__factorio-overhaul__/graphics/arsenal/barriere/sprites")
  local v = SPR.variants["barriere-borne"]
  assert(v, "arsenal_ages : sprites de la barrière absents (python -P tools/render/render.py tools/render/pieces/arsenal/barriere.py)")
  local function couche(c, extra)
    local l = { filename = c.lr.filename, width = c.lr.width, height = c.lr.height, shift = c.lr.shift, scale = 1,
      hr_version = { filename = c.hr.filename, width = c.hr.width, height = c.hr.height, shift = c.hr.shift, scale = 0.5 } }
    for k, x in pairs(extra or {}) do l[k] = x; l.hr_version[k] = x end
    return l
  end
  local t = turret_base(spec)
  t.collision_box = { { -0.29, -0.29 }, { 0.29, 0.29 } }
  t.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
  t.base_picture = { layers = {
    couche(v.shadow, { draw_as_shadow = true }),
    couche(v.main),
    couche(v.glow, { draw_as_glow = true, blend_mode = "additive" }),
    couche(v.light, { draw_as_light = true, blend_mode = "additive" }),
  } }
  for _, f in ipairs({ "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "ending_animation", "energy_glow_animation" }) do
    if t[f] then
      lib.scale_sprites(t[f], 0.45)
      -- la tête est posée au sommet de la borne (sphère d'émission à 1,5 unité : 1,5 × 45,25 px HR = 1,06 tuile)
      local function monte(x, seen)
        if type(x) ~= "table" or seen[x] then return end
        seen[x] = true
        if x.filename and x.shift then x.shift = { x.shift[1], x.shift[2] - 1.0 } end
        for _, y in pairs(x) do monte(y, seen) end
      end
      monte(t[f], {})
    end
  end
  local sticker = lib.copy("sticker", "slowdown-sticker")
  sticker.name = spec.name .. "-sticker"
  sticker.localised_name = { "entity-name." .. spec.name }
  sticker.duration_in_ticks = F.slow_ticks
  sticker.target_movement_modifier = F.slow
  out[#out + 1] = sticker
  local arc = lib.copy("beam", "electric-beam")
  arc.name = spec.name .. "-arc"
  arc.localised_name = { "entity-name." .. spec.name }
  arc.damage_interval = spec.cooldown
  arc.action = { type = "direct", action_delivery = { type = "instant", target_effects = {
    { type = "create-entity", entity_name = "explosion-hit" },
    dmg(F.damage, F.dtype),
    { type = "create-sticker", sticker = sticker.name },
    area(F.radius, "enemy", { type = "instant", target_effects = { dmg(F.damage * 0.5, F.dtype), { type = "create-sticker", sticker = sticker.name } } }),
  } } }
  out[#out + 1] = arc
  local ap = t.attack_parameters
  ap.range = spec.range
  ap.cooldown = spec.cooldown
  ap.damage_modifier = 1
  ap.ammo_type.category = "electric"
  ap.ammo_type.energy_consumption = spec.energy
  ap.source_direction_count = nil
  ap.source_offset = { 0, -1.0 }
  local d = ap.ammo_type.action.action_delivery
  d.beam = arc.name
  d.max_length = spec.range + 1
  d.duration = spec.cooldown
  d.source_offset = { 0, -1.0 }
  t.prepare_range = spec.range + 2
  energy_source(t, spec.buffer, spec.input, spec.drain)
  finish_turret(t, spec)
  -- l'icône : celle du rendu (lib.tier_icons de turret_base remplacée)
  local icone = { { icon = SPR.icon.filename, icon_size = SPR.icon.icon_size, icon_mipmaps = SPR.icon.icon_mipmaps } }
  lib.set_icons(t, icone)
  lib.set_icons(out[#out - 1], icone) -- l'objet (finish_turret : tourelle, objet, recette)
end

---------------------------------------------------------------------------------------------------
-- Technologies (une par entrée à `tech` complet ; le fusil à rail garde la sienne, session 4)
---------------------------------------------------------------------------------------------------
local function technology(tech, tint, tier)
  local src = data.raw.technology[tech.icon_from]
  assert(src, "arsenal_ages : technologie d'icône absente : " .. tostring(tech.icon_from))
  -- une technologie vanilla porte `icon` ou une liste `icons` (energy-shield-equipment) : la première icône sert de base
  local ic = src.icon and src or src.icons[1]
  local effects = {}
  for _, r in ipairs(unlocks[tech.name] or {}) do effects[#effects + 1] = lib.unlock(r) end
  out[#out + 1] = lib.technology({
    name = tech.name,
    localised_name = { "technology-name." .. tech.name },
    localised_description = { "technology-description." .. tech.name },
    icons = lib.tier_icons(ic.icon, ic.icon_size or src.icon_size, tint, tier, ic.icon_mipmaps or src.icon_mipmaps),
    effects = effects,
    prerequisites = tech.prerequisites,
    count = tech.count,
    packs = tech.packs,
    time = tech.time,
    order = "e-z[fo-ages]-" .. tech.name,
  })
end

for _, spec in ipairs(A.ages) do technology(spec.tech, spec.tint, spec.age) end
for _, spec in ipairs(A.hand_weapons) do
  if not spec.existing then technology(spec.tech, spec.tint, spec.age) end
end
technology(A.cataclysm.tech, A.cataclysm.tint, A.cataclysm.age)
technology(A.perimetre.tech, A.perimetre.tint, A.perimetre.age) -- lot ASSAUTS-TITANESQUES

data:extend(out)
log("[FO-ARMES-AGES] " .. #out .. " prototype(s) : lignée Bastion (" .. #A.ages .. " âges), armes de poing, frappe orbitale")
