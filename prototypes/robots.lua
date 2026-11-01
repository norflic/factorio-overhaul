--[[
  Lot RB-1 CHAÎNE (31/10) : prototypes des robots. Données : shared/content/robots.lua ; exécution : script/robots/*.

  - Atelier d'automates : `assembling-machine` (copie teintée de l'assembleur 2, 0 image neuve), catégorie de fabrication
    « fo-robots-1 » ; ni fluide, ni productivité (le kit pèse 1 case, RB0-3).
  - Kit : objet de pile 1, produit de la recette du robot (ingrédients d'au plus 100 chacun : RB0-1). Pas de `place_result` :
    poser un kit à la main viendra avec l'outil du joueur (RB-2).
  - Unité : `unit` par PROPRIÉTAIRE (le joueur et les 4 factions) : une unité n'a pas de couleur au jeu (PLAN §3). Lot RB-V1 (1/11) : un robot
    qui a une feuille (champ `sheet`, graphics/robots/sprites.lua, généré par tools/render/pieces/robots/feuilles.py, PNG hors de git, D-6) a
    ses vraies images : marche 16 directions, tir, ombre, lueur et une couche de PEINTURE teinte par propriétaire. Sans feuille : visuel
    PROVISOIRE, le cracheur vanilla en gris acier (une teinte ne fait que multiplier, F36).
  - Arme : tir à portée (balles physiques) de catégorie « fo-robot » ; PV et DPS du plan, à recaler (RB-4).
  - Technologie « Automates à vapeur » : débloque l'atelier et le Trotte-Vapeur (âge 3).
  À charger APRÈS prototypes/enemies.lua (les globales des animations du petit cracheur) : voir data.lua.
]]

local lib = require("prototypes.lib")
local Ro = require("shared.content.robots")
local F = require("shared.faction.config")
local C = require("shared.content.crafts")
local SPR = require("__factorio-overhaul__/graphics/robots/sprites")

local out = {}

out[#out + 1] = { type = "item-subgroup", name = Ro.SUBGROUP, group = "combat", order = "z[fo]-robots" }
out[#out + 1] = { type = "ammo-category", name = Ro.AMMO_CATEGORY }
for _, c in ipairs(Ro.CATEGORIES) do out[#out + 1] = { type = "recipe-category", name = c } end

local STEEL = { r = 0.62, g = 0.67, b = 0.74 }
local KIT_TINT = { r = 0.75, g = 0.80, b = 0.90 }

local function icons_of(ptype, name, tint)
  local src = assert(data.raw[ptype][name], "robots : icône source absente " .. ptype .. "/" .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

local function ingredients(list)
  local out_l = {}
  for _, g in ipairs(list) do out_l[#out_l + 1] = { type = "item", name = g[1], amount = g[2] } end
  return out_l
end

---------------------------------------------------------------------------------------------------
-- Ateliers
---------------------------------------------------------------------------------------------------
local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }

for i, w in ipairs(Ro.WORKSHOPS) do
  local e = lib.copy("assembling-machine", w.copy)
  local h = w.size / 2
  e.name = w.name
  e.localised_name = { "entity-name." .. w.name }
  e.localised_description = { "entity-description." .. w.name }
  e.minable = { mining_time = 0.5, result = w.name }
  e.next_upgrade = nil
  e.fast_replaceable_group = nil
  e.fixed_recipe = nil
  e.crafting_categories = { w.category }
  e.crafting_speed = w.speed
  e.energy_usage = w.kw .. "kW"
  e.energy_source = { type = "electric", usage_priority = "secondary-input", emissions_per_minute = 4 }
  e.collision_box = { { -h + 0.3, -h + 0.3 }, { h - 0.3, h - 0.3 } }
  e.selection_box = { { -h, -h }, { h, h } }
  e.module_specification = { module_slots = w.module_slots }
  e.allowed_effects = { "consumption", "speed", "pollution" } -- jamais de productivité : le kit n'a qu'une case (RB0-3)
  e.fluid_boxes = nil
  for _, key in ipairs(VISUAL_KEYS) do
    if e[key] then lib.tint_sprites(e[key], w.tint) end
  end
  lib.set_icons(e, icons_of("item", w.copy, w.tint))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item", name = w.name,
    localised_name = { "entity-name." .. w.name }, localised_description = { "entity-description." .. w.name },
    icons = icons_of("item", w.copy, w.tint), subgroup = Ro.SUBGROUP, order = string.format("a[workshop]-%02d", i),
    place_result = w.name, stack_size = 10,
  }
  out[#out + 1] = {
    type = "recipe", name = w.name, enabled = false, energy_required = 10,
    ingredients = ingredients(w.ingredients), results = { { type = "item", name = w.name, amount = 1 } },
    main_product = w.name,
  }
end

---------------------------------------------------------------------------------------------------
-- Robots : kit, recette, une unité par propriétaire
---------------------------------------------------------------------------------------------------
local function owner_tint(owner)
  if owner == Ro.PLAYER_OWNER then return STEEL end
  for _, f in ipairs(F.factions) do
    if f.key == owner then
      return { r = (STEEL.r + f.color.r) / 2, g = (STEEL.g + f.color.g) / 2, b = (STEEL.b + f.color.b) / 2 }
    end
  end
  error("robots : propriétaire inconnu " .. tostring(owner))
end

local function rgba(c) return { r = c.r, g = c.g, b = c.b, a = 1 } end

-- Couleur de la peinture d'un propriétaire (couche « mask » des feuilles) : le laiton de la bible pour le joueur, sa couleur pour une faction.
local BRASS = { r = 0.86, g = 0.66, b = 0.27 }
local function paint(owner)
  if owner == Ro.PLAYER_OWNER then return BRASS end
  for _, f in ipairs(F.factions) do
    if f.key == owner then return { r = f.color.r, g = f.color.g, b = f.color.b } end
  end
  error("robots : propriétaire inconnu " .. tostring(owner))
end

--- Une couche d'une feuille : basse définition (16 px par tuile, scale 2), hr (64 px par tuile, scale 0,5). Mêmes cases, même origine.
local function sheet_layer(c, anim, directions)
  return {
    filename = c.lr, width = c.lw, height = c.lh, line_length = anim.line_length, frame_count = anim.frame_count, direction_count = directions,
    shift = c.shift, scale = 2,
    hr_version = {
      filename = c.hr, width = c.w, height = c.h, line_length = anim.line_length, frame_count = anim.frame_count, direction_count = directions,
      shift = c.shift, scale = 0.5,
    },
  }
end

local function both(l, key, v)
  l[key] = v
  l.hr_version[key] = v
end

--- Animation complète : ombre, corps, peinture du propriétaire, lueur.
local function sheet_animation(sheet, anim_name, owner)
  local anim = sheet.anims[anim_name]
  local layers = {}
  local k = anim.couches
  local sh = sheet_layer(k.shadow, anim, sheet.directions)
  both(sh, "draw_as_shadow", true)
  layers[#layers + 1] = sh
  layers[#layers + 1] = sheet_layer(k.main, anim, sheet.directions)
  local m = sheet_layer(k.mask, anim, sheet.directions)
  both(m, "tint", rgba(paint(owner)))
  layers[#layers + 1] = m
  if k.glow then
    local g = sheet_layer(k.glow, anim, sheet.directions)
    both(g, "draw_as_glow", true)
    both(g, "blend_mode", "additive")
    layers[#layers + 1] = g
  end
  return { layers = layers }
end

--- Une machine, pas un insecte : ni cadavre ni cri de cracheur (le copié en vient).
local function as_machine(u, sheet)
  local turret = assert(data.raw["ammo-turret"]["gun-turret"], "robots : gun-turret absente")
  u.corpse = "small-remnants"
  u.dying_explosion = "explosion"
  u.damaged_trigger_effect = turret.damaged_trigger_effect
  u.dying_sound, u.working_sound, u.walking_sound, u.running_sound_animation_positions, u.water_reflection = nil, nil, nil, nil, nil
  u.alternative_attacking_frame_sequence = nil -- celle du cracheur vise ses 16 images (« Frame index 3 is out of range », 1/11)
  u.distance_per_frame = sheet.distance_per_frame
  lib.set_icons(u, { { icon = sheet.icone, icon_size = 64, icon_mipmaps = 4 } })
end

-- Tir : balles physiques, comme les soldats (prototypes/faction.lua), de catégorie « fo-robot ».
local function robot_ammo(damage)
  return {
    category = Ro.AMMO_CATEGORY,
    action = {
      type = "direct",
      action_delivery = {
        type = "instant",
        source_effects = { type = "create-explosion", entity_name = "explosion-gunshot" },
        target_effects = {
          { type = "create-entity", entity_name = "explosion-hit" },
          { type = "damage", damage = { amount = damage, type = "physical" } },
        },
      },
    },
  }
end

local smg = data.raw.gun["submachine-gun"]

for i, r in ipairs(Ro.ROBOTS) do
  local ings = ingredients(r.ingredients)
  out[#out + 1] = {
    type = "item", name = r.kit,
    localised_name = { "item-name." .. r.kit }, localised_description = { "item-description." .. r.kit },
    icons = r.sheet and { { icon = SPR[r.sheet].icone, icon_size = 64, icon_mipmaps = 4 } } or icons_of("item", "engine-unit", KIT_TINT),
    subgroup = Ro.SUBGROUP, order = string.format("b[kit]-%02d", i),
    stack_size = 1,
  }
  out[#out + 1] = {
    type = "recipe", name = r.recipe, category = Ro.WORKSHOPS[1].category, enabled = false, energy_required = r.time,
    ingredients = ings, results = { { type = "item", name = r.kit, amount = 1 } }, main_product = r.kit,
    localised_name = { "item-name." .. r.kit },
  }
  for _, owner in ipairs(Ro.OWNERS) do
    local u = lib.copy("unit", "medium-spitter")
    local tint = owner_tint(owner)
    local t1, t2 = rgba(tint), rgba({ r = tint.r * 0.7, g = tint.g * 0.7, b = tint.b * 0.7 })
    local scale = _G.scale_spitter_medium
    u.name = Ro.unit_name(owner, r.id)
    u.localised_name = { "fo-robots.unit-name", { "fo-robots.name-" .. r.id } }
    u.localised_description = { "fo-robots.unit-desc", { "fo-robots.name-" .. r.id } }
    u.order = string.format("z[fo-robot]-%s-%02d", owner, i)
    u.subgroup = Ro.SUBGROUP
    u.max_health = r.hp
    u.resistances = nil
    u.healing_per_tick = 0.02
    local hb = r.half
    u.collision_box = { { -hb, -hb }, { hb, hb } }
    u.selection_box = { { -hb - 0.1, -hb - 0.3 }, { hb + 0.1, hb + 0.3 } }
    u.movement_speed = r.speed
    u.vision_distance = 30 -- jamais au-delà de 45 (PLAN §3 : comportement non documenté)
    u.distraction_cooldown = 300
    u.min_pursue_time = 10 * 60
    u.max_pursue_distance = 50
    u.pollution_to_join_attack = 1
    u.spawning_time_modifier = nil
    u.absorptions_to_join_attack = nil
    u.attack_parameters = {
      type = "projectile",
      ammo_category = Ro.AMMO_CATEGORY,
      range = r.range,
      cooldown = r.shot.cooldown,
      cooldown_deviation = 0.1,
      projectile_creation_distance = 0.6,
      range_mode = "bounding-box-to-bounding-box",
      ammo_type = robot_ammo(r.shot.damage),
      animation = r.sheet and sheet_animation(SPR[r.sheet], "tir", owner) or spitterattackanimation(scale, t1, t2),
      sound = smg.attack_parameters.sound,
    }
    u.run_animation = r.sheet and sheet_animation(SPR[r.sheet], "run", owner) or spitterrunanimation(scale, t1, t2)
    u.ai_settings = { destroy_when_commands_fail = false, allow_try_return_to_spawner = false, do_separation = true }
    if r.sheet then
      as_machine(u, SPR[r.sheet])
    else
      lib.set_icons(u, icons_of("unit", "medium-spitter", tint))
    end
    out[#out + 1] = u
  end
end

---------------------------------------------------------------------------------------------------
-- Technologie
---------------------------------------------------------------------------------------------------
do
  local t = Ro.TECH
  local effects = {}
  for _, rn in ipairs(Ro.tech_unlocks()) do effects[#effects + 1] = lib.unlock(rn) end
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = icons_of("technology", "engine", KIT_TINT),
    effects = effects, prerequisites = t.prerequisites, count = C.tech_count(t), packs = C.packs(t.epoch), time = t.time,
    order = "z[fo]-robots-" .. t.name,
  })
end

data:extend(out)
