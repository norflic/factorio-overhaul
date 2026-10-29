--[[
  Factions IA : QG et soldats. Données : shared/faction/config.lua.

  Soldats = prototypes "unit" (IA moteur : pathfinding, combat, groupes) habillés avec les animations du
  personnage vanilla (course et visée armée), le calque de couleur teinté aux couleurs de la faction.
  Niveau d'armure visuel : fusilier = armure 1, mitrailleur = armure 2, grenadier = armure 3.
]]

local lib = require("prototypes.lib")
local F = require("shared.faction.config")

local out = {}

---------------------------------------------------------------------------------------------------
-- QG : l'épave du vaisseau du début de partie, renforcée.
---------------------------------------------------------------------------------------------------
local hq = lib.copy("container", "crash-site-spaceship")
hq.name = "fo-faction-hq"
hq.localised_name = { "entity-name.fo-faction-hq" }
hq.localised_description = { "entity-description.fo-faction-hq" }
hq.max_health = 25000
hq.minable = nil
-- Session 4 : le QG est le STOCK de l'équipe (économie réelle) ; l'épave vanilla n'a que 5 cases.
hq.inventory_size = require("shared.team.config").hq_inventory
hq.resistances = {
  { type = "physical", decrease = 10, percent = 30 },
  { type = "explosion", decrease = 10, percent = 30 },
  { type = "fire", percent = 60 },
  { type = "acid", percent = 30 },
}
out[#out + 1] = hq

---------------------------------------------------------------------------------------------------
-- Coffre d'équipe du joueur (session 4) : le stock de vos compagnons ouvriers.
---------------------------------------------------------------------------------------------------
do
  local tint = { r = 1.0, g = 0.85, b = 0.35 }
  local chest = lib.copy("container", "steel-chest")
  chest.name = "fo-team-chest"
  chest.localised_name = { "entity-name.fo-team-chest" }
  chest.localised_description = { "entity-description.fo-team-chest" }
  chest.minable = { mining_time = 0.3, result = "fo-team-chest" }
  chest.inventory_size = 96
  chest.max_health = 800
  lib.tint_sprites(chest.picture, tint)
  lib.set_icons(chest, { { icon = chest.icon, icon_size = chest.icon_size, icon_mipmaps = chest.icon_mipmaps, tint = tint } })
  out[#out + 1] = chest
  local item = lib.copy("item", "steel-chest")
  item.name = "fo-team-chest"
  item.place_result = "fo-team-chest"
  item.localised_name = { "entity-name.fo-team-chest" }
  item.localised_description = { "entity-description.fo-team-chest" }
  item.order = "a[items]-z[fo-team-chest]"
  lib.set_icons(item, { { icon = item.icon, icon_size = item.icon_size, icon_mipmaps = item.icon_mipmaps, tint = tint } })
  out[#out + 1] = item
  out[#out + 1] = lib.recipe("fo-team-chest", { { "iron-chest", 2 }, { "electronic-circuit", 5 } }, "fo-team-chest", 1, 2, { enabled = true })
end

---------------------------------------------------------------------------------------------------
-- Soldats
---------------------------------------------------------------------------------------------------
local character = data.raw.character.character
local smg = data.raw.gun["submachine-gun"]

local function faction_tinted(anim, color)
  local a = table.deepcopy(anim)
  local function visit(t, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    if t.apply_runtime_tint then
      t.apply_runtime_tint = false
      t.tint = { r = color.r, g = color.g, b = color.b, a = 1 }
    end
    for _, v in pairs(t) do visit(v, seen) end
  end
  visit(a, {})
  return a
end

local function bullet_ammo(damage)
  return {
    category = "bullet",
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

-- Grenadier (session 4) : son équipement réel est fait de grenades (fer + charbon, sans pétrole) ; il les
-- lance comme la grenade vanilla (projectile "grenade", explosion de zone de 35).
-- Lot GRENADES (retour du DC du 29/10) : l'explosion de la grenade vanilla est un déclencheur « area » sans filtre de camp
-- (ForceCondition par défaut : toutes les forces), donc elle blesse aussi les bâtiments et les soldats du lanceur. Le
-- grenadier lance une COPIE dont chaque déclencheur de zone ne touche que les camps ennemis du lanceur.
local GRENADE_PROJECTILE = "fo-grenadier-grenade"
do
  local proj = lib.copy("projectile", "grenade")
  proj.name = GRENADE_PROJECTILE
  local n_area = 0
  for _, trigger in ipairs(proj.action) do
    if trigger.type == "area" then
      trigger.force = "enemy"
      n_area = n_area + 1
    end
  end
  assert(n_area > 0, "fo-faction : la grenade vanilla n'a plus de déclencheur de zone")
  out[#out + 1] = proj
end

local function grenade_ammo()
  return {
    category = "grenade",
    target_type = "position",
    action = {
      type = "direct",
      action_delivery = { type = "projectile", projectile = GRENADE_PROJECTILE, starting_speed = 0.3 },
    },
  }
end

for _, faction in ipairs(F.factions) do
  for _, key in ipairs(F.soldier_order) do
    local s = F.soldiers[key]
    local anims = character.animations[s.armor] or character.animations[1]
    local name = F.unit_name(faction.key, key)
    local attack = {
      type = "projectile",
      ammo_category = s.rocket and "grenade" or "bullet",
      range = s.range,
      cooldown = s.cooldown,
      cooldown_deviation = 0.1,
      projectile_creation_distance = 0.6,
      range_mode = "bounding-box-to-bounding-box",
      ammo_type = s.rocket and grenade_ammo() or bullet_ammo(s.damage),
      animation = faction_tinted(anims.idle_with_gun, faction.color),
      sound = smg.attack_parameters.sound,
    }
    if s.rocket then attack.damage_modifier = s.damage / 35 end -- grenade vanilla : 35 dégâts de zone

    out[#out + 1] = {
      type = "unit",
      name = name,
      localised_name = { "", { "fo-faction.name-" .. faction.key }, " — ", { "fo-faction.soldier-" .. key } },
      icons = { { icon = character.icon, icon_size = character.icon_size, icon_mipmaps = character.icon_mipmaps, tint = faction.color } },
      flags = { "placeable-player", "placeable-enemy", "placeable-off-grid", "breaths-air", "not-repairable" },
      subgroup = "enemies",
      order = "z[fo-faction]-" .. faction.key .. "-" .. key,
      max_health = s.hp,
      healing_per_tick = 0.02,
      collision_box = { { -0.2, -0.2 }, { 0.2, 0.2 } },
      selection_box = { { -0.4, -1.4 }, { 0.4, 0.2 } },
      sticker_box = { { -0.2, -1 }, { 0.2, 0 } },
      vision_distance = 30,
      movement_speed = s.speed,
      distance_per_frame = character.distance_per_frame or 0.13,
      pollution_to_join_attack = 1,
      distraction_cooldown = 300,
      min_pursue_time = 10 * 60,
      max_pursue_distance = 50,
      dying_explosion = "blood-explosion-big",
      run_animation = faction_tinted(anims.running_with_gun, faction.color),
      attack_parameters = attack,
      ai_settings = { destroy_when_commands_fail = false, allow_try_return_to_spawner = false, do_separation = true },
    }
  end
end

data:extend(out)
