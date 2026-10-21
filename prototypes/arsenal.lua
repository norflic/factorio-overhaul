-- Arsenal : munitions, armes, tourelles lourdes 3×3, murs. Données : shared/content/arsenal.lua.

local lib = require("prototypes.lib")
local Evo = require("prototypes.evolution")
local A = require("shared.content.arsenal")

local out = {}
local unlocks = {} -- [indice de tech] = { recettes }

local function unlock(tech, recipe)
  unlocks[tech] = unlocks[tech] or {}
  table.insert(unlocks[tech], recipe)
end

local function item_from(ptype, copy, name, place_result, tint, tier)
  local item = lib.copy(ptype, copy)
  item.name = name
  item.place_result = place_result
  item.localised_name = { (ptype == "item" and place_result) and ("entity-name." .. name) or ("item-name." .. name) }
  item.localised_description = { (ptype == "item" and place_result) and ("entity-description." .. name) or ("item-description." .. name) }
  item.order = (item.order or "z") .. "-z[fo]-" .. name
  lib.set_icons(item, lib.tier_icons(item.icon, item.icon_size, tint, tier, item.icon_mipmaps))
  return item
end

---------------------------------------------------------------------------------------------------
-- Munitions
---------------------------------------------------------------------------------------------------
for _, spec in ipairs(A.ammo) do
  local ammo = item_from("ammo", "uranium-rounds-magazine", spec.name, nil, spec.tint, spec.tier)
  local effects = ammo.ammo_type.action.action_delivery.target_effects
  local base_effect = effects[1] -- impact visuel
  local new_effects = { base_effect }
  for dtype, amount in pairs(spec.damage) do
    new_effects[#new_effects + 1] = { type = "damage", damage = { amount = amount, type = dtype } }
  end
  if spec.splash then
    new_effects[#new_effects + 1] = { type = "create-entity", entity_name = "explosion" }
    new_effects[#new_effects + 1] = {
      type = "nested-result",
      action = {
        type = "area",
        radius = spec.splash.radius,
        action_delivery = {
          type = "instant",
          target_effects = { { type = "damage", damage = { amount = spec.splash.amount, type = spec.splash.type } } },
        },
      },
    }
  end
  if spec.sticker then
    new_effects[#new_effects + 1] = { type = "create-sticker", sticker = spec.sticker }
  end
  ammo.ammo_type.action.action_delivery.target_effects = new_effects
  out[#out + 1] = ammo
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, spec.energy, { category = spec.category })
  unlock(spec.tech, spec.name)
end

---------------------------------------------------------------------------------------------------
-- Armes portatives
---------------------------------------------------------------------------------------------------
for _, spec in ipairs(A.guns) do
  local gun = item_from("gun", spec.copy, spec.name, nil, spec.tint, nil)
  gun.attack_parameters.cooldown = spec.cooldown
  gun.attack_parameters.range = spec.range
  gun.attack_parameters.movement_slow_down_factor = spec.movement_slow_down_factor
  out[#out + 1] = gun
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, 10)
  unlock(spec.tech, spec.name)
end

---------------------------------------------------------------------------------------------------
-- Tourelles lourdes (3×3) : graphismes vanilla agrandis ×1.5 et teintés
---------------------------------------------------------------------------------------------------
local SPRITE_FIELDS = {
  "base_picture", "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation",
  "folding_animation", "energy_glow_animation", "water_reflection",
}

for _, spec in ipairs(A.turrets) do
  local t = lib.copy(spec.copy_type, spec.copy)
  t.name = spec.name
  t.localised_name = { "entity-name." .. spec.name }
  t.localised_description = { "entity-description." .. spec.name }
  t.max_health = spec.hp
  t.minable = { mining_time = 1, result = spec.name }
  t.collision_box = { { -1.2, -1.2 }, { 1.2, 1.2 } }
  t.selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }
  for _, field in ipairs(SPRITE_FIELDS) do
    if t[field] then
      lib.scale_sprites(t[field], spec.scale)
      if field ~= "water_reflection" then lib.tint_sprites(t[field], spec.tint) end
    end
  end
  -- Évolution visuelle : un AUTRE socle (pièce d'une autre machine), pas le socle d'origine agrandi.
  if spec.platform == "artillery" then
    local b = table.deepcopy(data.raw["artillery-turret"]["artillery-turret"].base_picture)
    lib.scale_sprites(b, 0.9)
    lib.tint_sprites(b, { r = 0.78, g = 0.80, b = 0.86 })
    t.base_picture = b
  elseif spec.platform == "beacon" then
    local b = table.deepcopy(data.raw.beacon.beacon.graphics_set.animation_list[1].animation)
    lib.scale_sprites(b, 1.05)
    lib.tint_sprites(b, { r = 0.85, g = 0.80, b = 0.95 })
    t.base_picture = b
  end
  if spec.glow then
    for _, field in ipairs({ "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "folding_animation" }) do
      if t[field] then
        Evo.glow_masks(t[field], spec.glow, 0.9)
        Evo.light_layers(t[field], spec.glow, 0.45)
      end
    end
    if t.energy_glow_animation then lib.tint_sprites(t.energy_glow_animation, spec.glow) end
  end
  local ap = t.attack_parameters
  ap.range = spec.range
  ap.damage_modifier = (ap.damage_modifier or 1) * spec.damage_modifier
  if spec.cooldown then ap.cooldown = spec.cooldown end
  if ap.projectile_creation_distance then ap.projectile_creation_distance = ap.projectile_creation_distance * spec.scale end
  if ap.projectile_center then ap.projectile_center = { ap.projectile_center[1] * spec.scale, ap.projectile_center[2] * spec.scale } end
  if ap.source_offset then ap.source_offset = { ap.source_offset[1] * spec.scale, ap.source_offset[2] * spec.scale } end
  if ap.ammo_type and ap.ammo_type.action and ap.ammo_type.action.action_delivery then
    local d = ap.ammo_type.action.action_delivery
    if d.max_length then d.max_length = spec.range + 2 end
    if d.source_offset then d.source_offset = { d.source_offset[1] * spec.scale, d.source_offset[2] * spec.scale } end
  end
  if spec.energy_scale and t.energy_source then
    local function scale_energy(s)
      local num, unit = s:match("^([%d%.]+)(%a+)$")
      return tostring(tonumber(num) * spec.energy_scale) .. unit
    end
    local es = t.energy_source
    if es.buffer_capacity then es.buffer_capacity = scale_energy(es.buffer_capacity) end
    if es.input_flow_limit then es.input_flow_limit = scale_energy(es.input_flow_limit) end
    if es.drain then es.drain = scale_energy(es.drain) end
    if ap.ammo_type and ap.ammo_type.energy_consumption then
      ap.ammo_type.energy_consumption = scale_energy(ap.ammo_type.energy_consumption)
    end
  end
  out[#out + 1] = t
  out[#out + 1] = item_from("item", spec.copy, spec.name, spec.name, spec.tint, nil)
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, 20)
  unlock(spec.tech, spec.name)
end

---------------------------------------------------------------------------------------------------
-- Murs
---------------------------------------------------------------------------------------------------
for _, spec in ipairs(A.walls) do
  local w = lib.copy("wall", "stone-wall")
  w.name = spec.name
  w.localised_name = { "entity-name." .. spec.name }
  w.localised_description = { "entity-description." .. spec.name }
  w.max_health = spec.hp
  w.minable = { mining_time = 0.3, result = spec.name }
  lib.tint_sprites(w.pictures, spec.tint)
  local res = w.resistances
  for dtype, v in pairs(spec.resist_bonus) do
    local found = false
    for _, r in ipairs(res) do
      if r.type == dtype then
        r.decrease = (r.decrease or 0) + v[1]
        r.percent = math.min(100, (r.percent or 0) + v[2])
        found = true
      end
    end
    if not found then res[#res + 1] = { type = dtype, decrease = v[1], percent = v[2] } end
  end
  out[#out + 1] = w
  out[#out + 1] = item_from("item", "stone-wall", spec.name, spec.name, spec.tint, nil)
  out[#out + 1] = lib.recipe(spec.name, spec.ingredients, spec.name, 1, 1)
  unlock(spec.tech, spec.name)
end

---------------------------------------------------------------------------------------------------
-- Technologies
---------------------------------------------------------------------------------------------------
for i, spec in ipairs(A.techs) do
  local src = data.raw.technology[spec.icon_from]
  local effects = {}
  for _, r in ipairs(unlocks[i] or {}) do effects[#effects + 1] = lib.unlock(r) end
  out[#out + 1] = lib.technology({
    name = spec.name,
    localised_name = { "technology-name.fo-heavy-weapons", tostring(i) },
    localised_description = { "technology-description.fo-heavy-weapons" },
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
