--[[
  Arsenal spécial (session 4) : nouvelles familles d'armes à SILHOUETTE COMPOSÉE.
  Aucun fichier image ajouté : chaque silhouette assemble des pièces graphiques du jeu de base (socle d'une
  tourelle, tête d'une autre, canon d'artillerie raccourci...), puis les teinte et les met à l'échelle.
  Données et rôles : shared/content/arsenal.lua (A.special_*).
]]

local lib = require("prototypes.lib")
local A = require("shared.content.arsenal")

local out = {}
local unlocks = {}

local function unlock(tech, recipe)
  unlocks[tech] = unlocks[tech] or {}
  table.insert(unlocks[tech], recipe)
end

local SPRITE_FIELDS = {
  "base_picture", "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation",
  "folding_animation", "energy_glow_animation", "ending_attack_animation", "starting_attack_animation",
}

local function shift_sprites(t, dx, dy, seen)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.filename or t.filenames or t.stripes then
    local s = t.shift or { 0, 0 }
    local x, y = s[1] or s.x or 0, s[2] or s.y or 0
    t.shift = { x + dx, y + dy }
  end
  for k, v in pairs(t) do
    if k ~= "shift" then shift_sprites(v, dx, dy, seen) end
  end
end

--- Icône composée : icône vanilla teintée + pastille d'une seconde icône (rôle de l'arme).
local function composed_icons(base_proto, overlay_proto, tint)
  local icons = {
    { icon = base_proto.icon, icon_size = base_proto.icon_size, icon_mipmaps = base_proto.icon_mipmaps, tint = tint },
  }
  if overlay_proto then
    icons[#icons + 1] = {
      icon = overlay_proto.icon, icon_size = overlay_proto.icon_size, icon_mipmaps = overlay_proto.icon_mipmaps,
      scale = 0.5 * 32 / (overlay_proto.icon_size or 64) * 1.25, shift = { 8, 8 },
    }
  end
  return icons
end

local function turret_item(spec, icon_base, icon_overlay)
  local item = lib.copy("item", "gun-turret")
  item.name = spec.name
  item.place_result = spec.name
  item.localised_name = { "entity-name." .. spec.name }
  item.localised_description = { "entity-description." .. spec.name }
  item.order = "b[turret]-z[fo]-" .. spec.name
  lib.set_icons(item, composed_icons(icon_base, icon_overlay, spec.tint))
  return item
end

local function finish_turret(t, spec, icon_base, icon_overlay)
  t.name = spec.name
  t.localised_name = { "entity-name." .. spec.name }
  t.localised_description = { "entity-description." .. spec.name }
  t.max_health = spec.hp
  t.minable = { mining_time = 0.5, result = spec.name }
  t.corpse = t.corpse
  lib.set_icons(t, composed_icons(icon_base, icon_overlay, spec.tint))
  out[#out + 1] = t
  out[#out + 1] = turret_item(spec, icon_base, icon_overlay)
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, 20)
  unlock(spec.tech, spec.name)
end

local function spec_of(list, name)
  for _, s in ipairs(list) do if s.name == name then return s end end
  error("arsenal spécial : " .. name .. " absent de shared/content/arsenal.lua")
end

---------------------------------------------------------------------------------------------------
-- Catégories de munitions nouvelles
---------------------------------------------------------------------------------------------------
for _, cat in ipairs({ "fo-mortar", "fo-launcher-grenade", "fo-rail-slug", "fo-arc-cell", "fo-acid" }) do
  out[#out + 1] = { type = "ammo-category", name = cat }
end

---------------------------------------------------------------------------------------------------
-- Tourelle-canon : socle de mitrailleuse agrandi + tourelle de char (64 orientations)
---------------------------------------------------------------------------------------------------
do
  local spec = spec_of(A.special_turrets, "fo-cannon-turret")
  local t = lib.copy("ammo-turret", "gun-turret")
  local tank = data.raw.car.tank
  local head = table.deepcopy(tank.turret_animation)
  lib.scale_sprites(head, 1.0)
  shift_sprites(head, 0, 0.35)
  lib.scale_sprites(t.base_picture, 1.5)
  lib.tint_sprites(t.base_picture, spec.tint)
  t.folded_animation = table.deepcopy(head)
  t.preparing_animation = table.deepcopy(head)
  t.prepared_animation = table.deepcopy(head)
  t.attacking_animation = table.deepcopy(head)
  t.folding_animation = table.deepcopy(head)
  t.collision_box = { { -1.2, -1.2 }, { 1.2, 1.2 } }
  t.selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }
  t.rotation_speed = 0.006
  t.preparing_speed = 0.05
  t.folding_speed = 0.05
  t.inventory_size = 2
  t.automated_ammo_count = 5
  local cannon = data.raw.gun["tank-cannon"].attack_parameters
  t.attack_parameters = {
    type = "projectile",
    ammo_category = "cannon-shell",
    cooldown = spec.cooldown,
    range = spec.range,
    min_range = spec.min_range,
    projectile_creation_distance = 1.9,
    projectile_center = { 0, -0.9 },
    sound = cannon.sound,
    turn_range = 1,
  }
  finish_turret(t, spec, data.raw.item["gun-turret"], data.raw.car.tank)
end

---------------------------------------------------------------------------------------------------
-- Mortier : socle et fût d'artillerie réduits (fût court = obusier), tir en cloche à longue portée
---------------------------------------------------------------------------------------------------
do
  local spec = spec_of(A.special_turrets, "fo-mortar-turret")
  local art = data.raw["artillery-turret"]["artillery-turret"]
  local t = lib.copy("ammo-turret", "gun-turret")
  local base = table.deepcopy(art.base_picture)
  lib.scale_sprites(base, 0.75)
  lib.tint_sprites(base, spec.tint)
  local barrel = table.deepcopy(art.cannon_barrel_pictures)
  -- RotatedSprite -> RotatedAnimation : une animation à fichiers multiples exige « slice » (moteur réel :
  -- « Key "slice" not found »). Une image par orientation : slice = images par ligne.
  local function add_slice(t, seen)
    seen = seen or {}
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    if t.filenames and not t.slice then t.slice = t.line_length or 1 end
    for _, v in pairs(t) do add_slice(v, seen) end
  end
  add_slice(barrel)
  lib.scale_sprites(barrel, 0.55)
  lib.tint_sprites(barrel, spec.tint)
  shift_sprites(barrel, 0, 0.45)
  t.base_picture = base
  t.folded_animation = table.deepcopy(barrel)
  t.preparing_animation = table.deepcopy(barrel)
  t.prepared_animation = table.deepcopy(barrel)
  t.attacking_animation = table.deepcopy(barrel)
  t.folding_animation = table.deepcopy(barrel)
  t.collision_box = { { -1.2, -1.2 }, { 1.2, 1.2 } }
  t.selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }
  t.rotation_speed = 0.004
  t.preparing_speed = 0.04
  t.folding_speed = 0.04
  t.inventory_size = 2
  t.automated_ammo_count = 5
  t.prepare_range = spec.range + 4
  t.attack_parameters = {
    type = "projectile",
    ammo_category = "fo-mortar",
    cooldown = spec.cooldown,
    range = spec.range,
    min_range = spec.min_range,
    projectile_creation_distance = 1.6,
    projectile_center = { 0, -0.6 },
    sound = data.raw.gun["tank-cannon"].attack_parameters.sound,
    turn_range = 1,
  }
  finish_turret(t, spec, art, data.raw.ammo["explosive-cannon-shell"])
end

---------------------------------------------------------------------------------------------------
-- Tour à arc électrique : tourelle laser au bleu électrique, arc qui frappe une zone autour de la cible
---------------------------------------------------------------------------------------------------
local function arc_beam(name, damage, radius)
  local beam = lib.copy("beam", "electric-beam")
  beam.name = name
  beam.damage_interval = 20
  beam.action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        { type = "create-entity", entity_name = "explosion-hit" },
        {
          type = "nested-result",
          action = {
            type = "area",
            radius = radius,
            force = "enemy",
            action_delivery = {
              type = "instant",
              target_effects = { { type = "damage", damage = { amount = damage, type = "electric" } } },
            },
          },
        },
      },
    },
  }
  return beam
end

do
  local spec = spec_of(A.special_turrets, "fo-tesla-turret")
  local t = lib.copy("electric-turret", "laser-turret")
  -- Silhouette NOUVELLE (retour du Directeur Créatif : pas une tourelle laser recolorée) : une pile
  -- d'accumulateurs surmontée de l'antenne d'une balise, parcourue d'arcs de charge lumineux, avec un halo
  -- bleu la nuit. Aucune pièce de la tourelle laser n'est visible.
  local acc = table.deepcopy(data.raw.accumulator.accumulator.picture)
  lib.tint_sprites(acc, { r = 0.80, g = 0.88, b = 1.00 })
  local bset = data.raw.beacon.beacon.graphics_set.animation_list
  local antenna = table.deepcopy(bset[2].animation)
  local function still(sp)
    sp.repeat_count = nil
    sp.frame_count = 1
    sp.animation_speed = nil
    if sp.hr_version then still(sp.hr_version) end
  end
  still(antenna)
  shift_sprites(antenna, -0.09, -0.62)
  t.base_picture = { layers = { acc.layers[1], antenna, acc.layers[2] } }
  -- Bobine : arcs de charge de l'accumulateur (texture à vraie couche alpha, lumineuse) sur la pile, et
  -- halo de nuit. Moteur réel (2 captures) : la texture de lumière de la balise, essayée d'abord, ne
  -- s'affiche pas hors de la balise (alpha moyen 0,003 : rien après prémultiplication), ni en tête ni sur
  -- le socle (F38).
  local charge = data.raw.accumulator.accumulator.charge_animation.layers[2]
  local function coil(level, animated)
    local function mk(sp, tint, light)
      if animated then sp.direction_count = 1 else
        sp.frame_count = 1
        sp.animation_speed = nil
      end
      sp.tint = tint
      if light then
        sp.draw_as_light = true
        sp.draw_as_glow = nil
        sp.blend_mode = "additive"
      else
        sp.draw_as_glow = true
      end
      if sp.hr_version then mk(sp.hr_version, tint, light) end
    end
    local glow = table.deepcopy(charge)
    mk(glow, { r = 0.75 * level + 0.25, g = 0.95, b = 1.0, a = 1 }, false)
    local halo = table.deepcopy(charge)
    local function enlarge(sp) -- agrandi autour du même centre (le décalage n'est pas multiplié)
      sp.scale = (sp.scale or 1) * 1.8
      if sp.hr_version then enlarge(sp.hr_version) end
    end
    enlarge(halo)
    mk(halo, { r = 0.30 * level, g = 0.60 * level, b = 1.0 * level, a = 1 }, true)
    return { layers = { glow, halo } }
  end
  t.folded_animation = coil(0.6, true)
  t.folding_animation = coil(0.7, true)
  t.preparing_animation = coil(0.8, true)
  t.prepared_animation = coil(0.9, true)
  t.attacking_animation = coil(1.0, true)
  -- Le socle est toujours dessiné : la pile y porte ses arcs (image fixe), même tourelle au repos.
  for _, l in ipairs(coil(0.8, false).layers) do t.base_picture.layers[#t.base_picture.layers + 1] = l end
  t.energy_glow_animation = nil
  t.glow_light_intensity = 0.8
  out[#out + 1] = arc_beam("fo-arc-beam", spec.arc_damage, spec.arc_radius)
  -- Un arc consomme spec.energy : la réserve copiée de la tourelle laser (801 kJ) ne permettait AUCUN tir
  -- (banc de contenu, moteur réel : 0 dégât). Réserve = 1,25 tir, débit pour recharger en ~0,25 s.
  t.energy_source = table.deepcopy(t.energy_source)
  t.energy_source.buffer_capacity = "1500kJ"
  t.energy_source.input_flow_limit = "12000kW"
  t.energy_source.drain = "30kW"
  t.attack_parameters = {
    type = "beam",
    cooldown = spec.cooldown,
    range = spec.range,
    source_direction_count = 1,
    source_offset = { 0, -1.9 },
    ammo_type = {
      category = "electric",
      energy_consumption = spec.energy,
      action = {
        type = "direct",
        action_delivery = { type = "beam", beam = "fo-arc-beam", max_length = spec.range + 2, duration = 40, source_offset = { 0, -1.5 } },
      },
    },
  }
  finish_turret(t, spec, data.raw["electric-turret"]["laser-turret"], data.raw.item.battery)
end

---------------------------------------------------------------------------------------------------
-- Pulvérisateur d'acide : lance-flammes vert, jet d'acide (acide sulfurique) qui ronge et ralentit
---------------------------------------------------------------------------------------------------
do
  local spec = spec_of(A.special_turrets, "fo-acid-sprayer")
  local t = lib.copy("fluid-turret", "flamethrower-turret")
  -- Silhouette NOUVELLE : à l'arrière du socle, un petit réacteur chimique (usine chimique réduite, sa
  -- propre orientation) qui prépare l'acide ; socle en acier brut, buse d'origine. Plus de teinte verte.
  local plant = data.raw["assembling-machine"]["chemical-plant"].animation
  local REAR = { north = { 0, 0.62 }, south = { 0, -0.62 }, east = { -0.62, 0 }, west = { 0.62, 0 } }
  for dir, off in pairs(REAR) do
    local layers = t.base_picture[dir].layers
    lib.tint_sprites(layers, { r = 0.72, g = 0.74, b = 0.76 })
    local body = table.deepcopy(plant[dir].layers[1])
    local shadow = table.deepcopy(plant[dir].layers[2])
    for _, sp in ipairs({ body, shadow }) do
      local function still(x)
        x.frame_count = 1
        x.repeat_count = nil
        x.line_length = nil
        if x.hr_version then still(x.hr_version) end
      end
      still(sp)
      lib.scale_sprites(sp, 0.55)
      shift_sprites(sp, off[1], off[2] - 0.15)
    end
    table.insert(layers, 1, shadow)
    table.insert(layers, body)
  end
  t.resistances = { { type = "acid", percent = 100 } }

  local sticker = lib.copy("sticker", "acid-sticker-big")
  sticker.name = "fo-acid-sticker"
  sticker.target_movement_modifier = spec.slow
  sticker.duration_in_ticks = 3 * 60
  sticker.damage_per_tick = { amount = spec.acid_damage / 30, type = "acid" }
  out[#out + 1] = sticker

  local stream = lib.copy("stream", "acid-stream-spitter-big")
  stream.name = "fo-acid-spray-stream"
  stream.action = {
    {
      type = "area",
      radius = 2.5,
      force = "enemy",
      action_delivery = {
        type = "instant",
        target_effects = {
          { type = "damage", damage = { amount = spec.acid_damage, type = "acid" } },
          { type = "create-sticker", sticker = "fo-acid-sticker" },
        },
      },
    },
  }
  out[#out + 1] = stream

  local ap = t.attack_parameters
  ap.range = spec.range
  ap.min_range = spec.min_range
  ap.fluids = { { type = spec.fluid } }
  ap.fluid_consumption = 0.25
  ap.ammo_type = {
    category = "fo-acid",
    action = {
      type = "direct",
      action_delivery = { type = "stream", stream = "fo-acid-spray-stream", source_offset = { 0.15, -0.5 } },
    },
  }
  finish_turret(t, spec, data.raw["fluid-turret"]["flamethrower-turret"], data.raw.fluid["sulfuric-acid"])
end

---------------------------------------------------------------------------------------------------
-- Munitions
---------------------------------------------------------------------------------------------------
local function ammo_item(spec, copy_type)
  local proto = data.raw.ammo[spec.copy_icon] or data.raw.item[spec.copy_icon] or data.raw.capsule[spec.copy_icon]
  local item = lib.copy("ammo", "firearm-magazine")
  item.name = spec.name
  item.localised_name = { "item-name." .. spec.name }
  item.localised_description = { "item-description." .. spec.name }
  item.order = "z[fo]-" .. spec.name
  item.magazine_size = 1
  item.stack_size = 100
  lib.set_icons(item, { { icon = proto.icon, icon_size = proto.icon_size, icon_mipmaps = proto.icon_mipmaps, tint = spec.tint } })
  return item
end

-- Obus de mortier : projectile de grenade alourdi, explosion de zone.
do
  local spec = spec_of(A.special_ammo, "fo-mortar-shell")
  local proj = lib.copy("projectile", "grenade")
  proj.name = "fo-mortar-projectile"
  proj.acceleration = 0
  lib.scale_sprites(proj.animation, 1.6)
  lib.tint_sprites(proj.animation, spec.tint)
  proj.action = {
    {
      type = "direct",
      action_delivery = {
        type = "instant",
        target_effects = {
          { type = "create-entity", entity_name = "big-explosion" },
          { type = "create-entity", entity_name = "medium-scorchmark-tintable", check_buildability = true },
          { type = "invoke-tile-trigger", repeat_count = 1 },
        },
      },
    },
    {
      type = "area",
      radius = spec.radius,
      action_delivery = {
        type = "instant",
        target_effects = {
          { type = "damage", damage = { amount = spec.explosion, type = "explosion" } },
          { type = "damage", damage = { amount = spec.physical, type = "physical" } },
        },
      },
    },
  }
  out[#out + 1] = proj
  local item = ammo_item(spec)
  item.ammo_type = {
    category = "fo-mortar",
    target_type = "position",
    action = {
      type = "direct",
      action_delivery = {
        type = "projectile", projectile = "fo-mortar-projectile", starting_speed = 0.55,
        direction_deviation = 0.05, range_deviation = 0.08, max_range = 50, min_range = 10,
      },
    },
  }
  out[#out + 1] = item
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, spec.energy)
  unlock(spec.tech, spec.name)
end

-- Obus de char en tungstène : perforant lourd (traverse plusieurs cibles).
do
  local spec = spec_of(A.special_ammo, "fo-tungsten-cannon-shell")
  local proj = lib.copy("projectile", "cannon-projectile")
  proj.name = "fo-tungsten-cannon-projectile"
  proj.piercing_damage = spec.physical * spec.pierce
  proj.action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        { type = "damage", damage = { amount = spec.physical, type = "physical" } },
        { type = "damage", damage = { amount = spec.explosion or 0, type = "explosion" } },
        { type = "create-entity", entity_name = "explosion" },
      },
    },
  }
  lib.tint_sprites(proj.animation, spec.tint)
  out[#out + 1] = proj
  local item = lib.copy("ammo", "cannon-shell")
  item.name = spec.name
  item.localised_name = { "item-name." .. spec.name }
  item.localised_description = { "item-description." .. spec.name }
  item.order = "d[cannon-shell]-z[fo]-" .. spec.name
  lib.set_icons(item, { { icon = item.icon, icon_size = item.icon_size, icon_mipmaps = item.icon_mipmaps, tint = spec.tint } })
  item.ammo_type.action.action_delivery.projectile = "fo-tungsten-cannon-projectile"
  out[#out + 1] = item
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, spec.energy)
  unlock(spec.tech, spec.name)
end

-- Grenade de lanceur : grenade vanilla tirée à l'arme.
do
  local spec = spec_of(A.special_ammo, "fo-launcher-grenade")
  local proj = lib.copy("projectile", "grenade")
  proj.name = "fo-launcher-grenade-projectile"
  proj.action[2].radius = spec.radius
  for _, eff in ipairs(proj.action[2].action_delivery.target_effects) do
    if eff.type == "damage" then eff.damage.amount = spec.explosion end
  end
  out[#out + 1] = proj
  local item = ammo_item(spec)
  item.ammo_type = {
    category = "fo-launcher-grenade",
    target_type = "position",
    action = {
      type = "direct",
      action_delivery = { type = "projectile", projectile = "fo-launcher-grenade-projectile", starting_speed = 0.45, max_range = 26 },
    },
  }
  item.magazine_size = 1
  out[#out + 1] = item
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, spec.energy)
  unlock(spec.tech, spec.name)
end

-- Balle de fusil à rail : traverse TOUT sur une ligne (action « line »), trace lumineuse.
do
  local spec = spec_of(A.special_ammo, "fo-rail-slug")
  local item = ammo_item(spec)
  item.ammo_type = {
    category = "fo-rail-slug",
    action = {
      {
        type = "line",
        range = spec.line_range,
        width = 1.2,
        force = "enemy",
        source_effects = { type = "create-explosion", entity_name = "explosion-gunshot" },
        action_delivery = {
          type = "instant",
          target_effects = { { type = "damage", damage = { amount = spec.physical, type = "physical" } } },
        },
      },
      {
        type = "direct",
        action_delivery = { type = "beam", beam = "electric-beam-no-sound", max_length = spec.line_range, duration = 8 },
      },
    },
  }
  out[#out + 1] = item
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, spec.energy)
  unlock(spec.tech, spec.name)
end

-- Cellule d'arc : munition de l'arc portatif (même arc que la tour, plus faible).
do
  local spec = spec_of(A.special_ammo, "fo-arc-cell")
  out[#out + 1] = arc_beam("fo-arc-beam-handheld", spec.arc_damage, spec.arc_radius)
  local item = ammo_item(spec)
  item.magazine_size = 10
  item.ammo_type = {
    category = "fo-arc-cell",
    action = {
      type = "direct",
      action_delivery = { type = "beam", beam = "fo-arc-beam-handheld", max_length = 18, duration = 20 },
    },
  }
  out[#out + 1] = item
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, spec.energy)
  unlock(spec.tech, spec.name)
end

---------------------------------------------------------------------------------------------------
-- Armes portatives
---------------------------------------------------------------------------------------------------
for _, spec in ipairs(A.special_guns) do
  local gun = lib.copy("gun", spec.copy)
  gun.name = spec.name
  gun.localised_name = { "item-name." .. spec.name }
  gun.localised_description = { "item-description." .. spec.name }
  gun.order = "a[basic-clips]-z[fo]-" .. spec.name
  local ammo_spec = spec_of(A.special_ammo, spec.ammo)
  local overlay = data.raw.ammo[ammo_spec.copy_icon] or data.raw.item[ammo_spec.copy_icon] or data.raw.capsule[ammo_spec.copy_icon]
  lib.set_icons(gun, composed_icons(data.raw.gun[spec.copy], overlay, spec.tint))
  local ap = gun.attack_parameters
  ap.ammo_category = ammo_spec.category
  ap.cooldown = spec.cooldown
  ap.range = spec.range
  ap.min_range = nil
  if ammo_spec.arc_damage then
    -- Munition à rayon (arc) : le moteur n'applique une livraison « beam » qu'avec des paramètres
    -- d'attaque de type « beam » (banc de contenu, moteur réel : 0 dégât avec un fusil « projectile »).
    ap.type = "beam"
    ap.projectile_creation_distance = nil
    ap.projectile_center = nil
    ap.shell_particle = nil
    ap.source_direction_count = 1
  end
  out[#out + 1] = gun
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, 10)
  unlock(spec.tech, spec.name)
end

---------------------------------------------------------------------------------------------------
-- Technologies 4-6
---------------------------------------------------------------------------------------------------
for i, spec in pairs(A.special_techs) do
  local src = data.raw.technology[spec.icon_from]
  local effects = {}
  for _, r in ipairs(unlocks[i] or {}) do effects[#effects + 1] = lib.unlock(r) end
  out[#out + 1] = lib.technology({
    name = spec.name,
    localised_name = { "technology-name." .. spec.name },
    localised_description = { "technology-description." .. spec.name },
    icons = lib.tier_icons(src.icon, src.icon_size, A.tungsten_tint, i, src.icon_mipmaps),
    effects = effects,
    prerequisites = spec.prerequisites,
    count = spec.count,
    packs = spec.packs,
    time = spec.time,
    order = "e-z[fo]-" .. i,
  })
end

data:extend(out)
