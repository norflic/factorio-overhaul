--[[
  Lot RB-1 CHAÎNE (31/10) : prototypes des robots. Données : shared/content/robots.lua ; exécution : script/robots/*.

  - Atelier d'automates : `assembling-machine` (copie teintée de l'assembleur 2, 0 image neuve), catégorie de fabrication
    « fo-robots-1 » ; ni fluide, ni productivité (le kit pèse 1 case, RB0-3).
  - Kit : objet de pile 1, produit de la recette du robot (ingrédients d'au plus 100 chacun : RB0-1). Pas de `place_result` :
    poser un kit à la main viendra avec l'outil du joueur (RB-2).
  - Unité : `unit` par PROPRIÉTAIRE (le joueur et les 4 factions) : une unité n'a pas de couleur au jeu (PLAN §3). Visuel PROVISOIRE
    (Ro.PROVISIONAL) : animations du petit cracheur vanilla régénérées en gris acier (une teinte ne fait que multiplier, F36 : on
    repasse par les fonctions globales du jeu avec d'autres teintes, comme prototypes/enemies.lua), mêlées d'un peu de la couleur de la faction.
  - Arme : tir à portée (balles physiques) de catégorie « fo-robot » ; PV et DPS du plan, à recaler (RB-4).
  - Technologie « Automates à vapeur » : débloque l'atelier et le Trotte-Vapeur (âge 3).
  À charger APRÈS prototypes/enemies.lua (les globales des animations du petit cracheur) : voir data.lua.
]]

local lib = require("prototypes.lib")
local Ro = require("shared.content.robots")
local F = require("shared.faction.config")
local C = require("shared.content.crafts")

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
    icons = icons_of("item", "engine-unit", KIT_TINT), subgroup = Ro.SUBGROUP, order = string.format("b[kit]-%02d", i),
    stack_size = 1,
    -- Lot RB-3 : le kit « pose » l'unité du joueur (prototype `unit`) : le cerveau lit ce lien dans les prototypes (items_to_place_this),
    -- sans nom ; un kit posé à la main est inscrit au registre par script/robots/usine.lua.
    place_result = Ro.unit_name(Ro.PLAYER_OWNER, r.id),
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
      animation = spitterattackanimation(scale, t1, t2),
      sound = smg.attack_parameters.sound,
    }
    u.run_animation = spitterrunanimation(scale, t1, t2)
    u.ai_settings = { destroy_when_commands_fail = false, allow_try_return_to_spawner = false, do_separation = true }
    lib.set_icons(u, icons_of("unit", "medium-spitter", tint))
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

---------------------------------------------------------------------------------------------------
-- Outils du joueur (lot RB-2) : outil d'ordre, outil de ralliement, raccourci « Armée » et touche
---------------------------------------------------------------------------------------------------
do
  local function colour(r, g, b) return { r = r, g = g, b = b, a = 0.5 } end
  local function tool(name, tint, order, modes, filters, reverse_filters)
    local t = {
      type = "selection-tool", name = name,
      localised_name = { "item-name." .. name }, localised_description = { "item-description." .. name },
      icons = icons_of("deconstruction-item", "deconstruction-planner", tint),
      flags = { "hidden", "only-in-cursor", "spawnable" }, subgroup = "tool", order = order, stack_size = 1,
      selection_color = colour(0.2, 0.9, 0.2), alt_selection_color = colour(0.9, 0.8, 0.2),
      reverse_selection_color = colour(0.9, 0.2, 0.2), alt_reverse_selection_color = colour(0.2, 0.4, 0.9),
      chart_selection_color = colour(0.2, 0.9, 0.2), chart_alt_selection_color = colour(0.9, 0.8, 0.2),
      chart_reverse_selection_color = colour(0.9, 0.2, 0.2), chart_alt_reverse_selection_color = colour(0.2, 0.4, 0.9),
      selection_count_button_color = colour(0.2, 0.9, 0.2), alt_selection_count_button_color = colour(0.9, 0.8, 0.2),
      reverse_selection_count_button_color = colour(0.9, 0.2, 0.2), alt_reverse_selection_count_button_color = colour(0.2, 0.4, 0.9),
      selection_cursor_box_type = "entity", alt_selection_cursor_box_type = "entity",
      reverse_selection_cursor_box_type = "not-allowed", alt_reverse_selection_cursor_box_type = "not-allowed",
      selection_mode = modes[1], alt_selection_mode = modes[2], reverse_selection_mode = modes[3], alt_reverse_selection_mode = modes[4],
      entity_type_filters = filters, reverse_entity_type_filters = reverse_filters,
    }
    return t
  end
  -- Ordre : glisser = mes robots ; Maj + glisser = une zone (marche-attaque) ; bouton droit = ce qui est ennemi ; Maj + droit = une zone.
  out[#out + 1] = tool(Ro.TOOL_ORDER, { r = 1, g = 0.78, b = 0.45 }, "z[fo-robot-order]",
    { { "same-force" }, { "nothing" }, { "enemy" }, { "nothing" } },
    { "unit", "spider-vehicle" }, { "unit", "unit-spawner", "turret", "spider-vehicle" })
  -- Ralliement : une zone, sans entité.
  out[#out + 1] = tool(Ro.TOOL_RALLY, { r = 0.55, g = 1, b = 0.6 }, "z[fo-robot-rally]",
    { { "nothing" }, { "nothing" }, { "nothing" }, { "nothing" } })

  local function sprite(file, size)
    return { filename = "__factorio-overhaul__/graphics/gui/" .. file, priority = "extra-high-no-scale", size = size, scale = 0.5,
      mipmap_count = 2, flags = { "gui-icon" } }
  end
  out[#out + 1] = {
    type = "custom-input", name = Ro.SHORTCUT, key_sequence = Ro.INPUT_KEY, consuming = "none", action = "spawn-item",
    item_to_spawn = Ro.TOOL_ORDER, order = "b[fo-robot-order]",
  }
  out[#out + 1] = {
    type = "shortcut", name = Ro.SHORTCUT, order = "a[fo-team]-b[robots]", action = "spawn-item", item_to_spawn = Ro.TOOL_ORDER,
    associated_control_input = Ro.SHORTCUT, technology_to_unlock = Ro.TECH.name,
    localised_name = { "shortcut-name." .. Ro.SHORTCUT },
    icon = sprite("robot-x32.png", 32), small_icon = sprite("robot-x24.png", 24),
    disabled_icon = sprite("robot-x32-white.png", 32), disabled_small_icon = sprite("robot-x24-white.png", 24),
  }
end

data:extend(out)
