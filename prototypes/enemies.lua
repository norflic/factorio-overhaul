--[[
  Déchiqueteurs : paliers 5-8, familles (blindée, ignée, couvée, foudroyante), nids de famille, vers 5-8,
  et redistribution des courbes d'apparition des nids vanilla. Données : shared/content/enemies.lua.

  Aucune nouvelle image : les animations vanilla sont régénérées par les fonctions globales du jeu
  (biterrunanimation, spitterrunanimation, worm_*, spawner_*) avec d'autres tailles et teintes.
]]

local lib = require("prototypes.lib")
local Evo = require("prototypes.evolution")
local E = require("shared.content.enemies")
local enemy_autoplace = require("__base__/prototypes/entity/enemy-autoplace-utils")

local out = {}

local SPITTER_ATTACK = {
  small = spitter_attack_parameters,
  medium = spitter_mid_attack_parameters,
  big = spitter_big_attack_parameters,
  behemoth = spitter_behemoth_attack_parameters,
}

local function rgba(c) return { r = c.r, g = c.g, b = c.b, a = 1 } end

-- Taille et teintes vanilla par palier (globales posées par base).
local function vanilla_look(kind, tn)
  if kind == "biter" then
    return _G[tn .. "_biter_scale"], _G[tn .. "_biter_tint1"], _G[tn .. "_biter_tint2"]
  end
  return _G["scale_spitter_" .. tn], _G["tint_1_spitter_" .. tn], _G["tint_2_spitter_" .. tn]
end

local function scaled_resistances(base, flat, pct)
  local out_r = {}
  local seen = {}
  for _, r in ipairs(base or {}) do
    out_r[#out_r + 1] = { type = r.type, decrease = (r.decrease or 0) + flat, percent = math.min(95, (r.percent or 0) + pct) }
    seen[r.type] = true
  end
  for _, t in ipairs({ "physical", "explosion", "acid" }) do
    if not seen[t] and (flat > 0 or pct > 0) then
      out_r[#out_r + 1] = { type = t, decrease = flat, percent = math.min(95, pct) }
    end
  end
  return out_r
end

local function add_family_resistances(res, family, tier)
  for dtype, v in pairs(E.family_resist(family, tier)) do
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
end

local function tint_for(tier, family, kind)
  if family then
    local f = E.families[family]
    return f.tint1, f.tint2
  end
  local nt = E.new_tiers[tier]
  return nt.tint1, nt.tint2
end

--- Génère une unité (biter ou spitter) pour un palier et une famille optionnelle.
local function make_unit(kind, tier, family)
  local tn = E.tier_names[tier]
  local src_tier = math.min(tier, E.VANILLA_TIERS)
  local src_name = E.tier_names[src_tier] .. "-" .. kind
  local u = lib.copy("unit", src_name)
  local name = E.unit_name(kind, tier, family)
  u.name = name
  u.order = string.format("b-%s-z[fo]-%s-%d", kind == "biter" and "a" or "b", family or "base", tier)

  local scale, t1, t2 = vanilla_look(kind, E.tier_names[src_tier])
  local nt = E.new_tiers[tier]
  local hp, dmg, speed = u.max_health, 1, u.movement_speed
  if nt then
    scale = scale * nt.scale / 1.2
    hp = hp * nt.hp
    dmg = nt.damage
    speed = speed * nt.speed
    u.resistances = scaled_resistances(u.resistances, nt.resist, nt.resist)
    u.pollution_to_join_attack = u.pollution_to_join_attack * nt.poll
    local box_factor = math.min(scale / 1.2, 1.9)
    u.collision_box = lib.scale_box(u.collision_box, box_factor)
    u.selection_box = lib.scale_box(u.selection_box, box_factor)
    if u.sticker_box then u.sticker_box = lib.scale_box(u.sticker_box, box_factor) end
  end
  if family or nt then t1, t2 = tint_for(tier, family, kind) end
  t1, t2 = rgba(t1), rgba(t2)

  local f = family and E.families[family]
  if f then
    hp = hp * f.hp
    dmg = dmg * f.damage
    speed = speed * f.speed
    u.resistances = u.resistances or {}
    add_family_resistances(u.resistances, f, tier)
    if f.death_fire then
      u.dying_trigger_effect = { { type = "create-fire", entity_name = "fire-flame", initial_ground_flame_count = 2 } }
    end
  end
  u.max_health = hp
  u.movement_speed = speed

  -- Animations régénérées par les fonctions vanilla.
  local corpse = lib.copy("corpse", E.tier_names[src_tier] .. "-" .. kind .. "-corpse")
  corpse.name = name .. "-corpse"
  if kind == "biter" then
    u.run_animation = biterrunanimation(scale, t1, t2)
    u.attack_parameters.animation = biterattackanimation(scale, t1, t2)
    u.water_reflection = biter_water_reflection(scale)
    u.attack_parameters.damage_modifier = dmg
    if f and f.damage_type then lib.retype_damage(u.attack_parameters.ammo_type, f.damage_type) end
    add_biter_die_animation(scale, t1, t2, corpse)
  else
    local base_tn = E.tier_names[src_tier]
    local range = _G["range_spitter_" .. base_tn] + (nt and 2 * (tier - E.VANILLA_TIERS) or 0)
    u.attack_parameters = SPITTER_ATTACK[base_tn]({
      acid_stream_name = "acid-stream-spitter-" .. base_tn,
      range = range,
      min_attack_distance = 10,
      cooldown = 100,
      cooldown_deviation = 0.15,
      damage_modifier = _G["damage_modifier_spitter_" .. base_tn] * dmg,
      scale = scale,
      tint1 = t1,
      tint2 = t2,
      roarvolume = 0.6,
      range_mode = "bounding-box-to-bounding-box",
    })
    u.run_animation = spitterrunanimation(scale, t1, t2)
    u.water_reflection = spitter_water_reflection(scale)
    add_spitter_die_animation(scale, t1, t2, corpse)
  end
  u.corpse = corpse.name

  -- Évolution visuelle : les plaques de carapace luisent, de plus en plus fort avec le palier ; la couleur
  -- de la lueur dit la famille (braise, arcs, œufs, acier). Les paliers vanilla sans famille restent intacts.
  local glow = (f and f.glow) or (nt and nt.tint2)
  if glow then
    local alpha = f and Evo.tier_alpha(tier, 0.22, 0.08) or Evo.tier_alpha(tier - E.VANILLA_TIERS, 0.35, 0.13)
    Evo.glow_masks(u.run_animation, glow, alpha)
    Evo.glow_masks(u.attack_parameters.animation, glow, alpha)
  end

  local base_icon = data.raw.unit[src_name]
  lib.set_icons(u, lib.tier_icons(base_icon.icon, base_icon.icon_size, t2, tier, base_icon.icon_mipmaps))
  lib.set_icons(corpse, lib.tier_icons(base_icon.icon, base_icon.icon_size, t2, nil, base_icon.icon_mipmaps))

  -- Noms : vanilla "Gros déchiqueteur" + adjectif de famille, ou nom du nouveau palier.
  local base_name = nt and { "entity-name.fo-" .. tn .. "-" .. kind } or { "entity-name." .. src_name }
  if family then
    u.localised_name = { "", base_name, " ", { "fo-enemy.family-" .. family } }
  else
    u.localised_name = base_name
  end
  corpse.localised_name = { "", u.localised_name, " (", { "fo-enemy.corpse" }, ")" }

  out[#out + 1] = u
  out[#out + 1] = corpse
  return name
end

--- Courbe d'apparition (copie) au format moteur.
local function curve(tier)
  local c = {}
  for _, p in ipairs(E.spawn_curves[tier]) do c[#c + 1] = { p[1], p[2] } end
  return c
end

---------------------------------------------------------------------------------------------------
-- Unités : paliers 5-8 sans famille, puis 8 paliers × 4 familles
---------------------------------------------------------------------------------------------------
local base_units = { biter = {}, spitter = {} }
for _, kind in ipairs({ "biter", "spitter" }) do
  for tier = 1, E.TIERS do
    base_units[kind][tier] = (tier <= E.VANILLA_TIERS) and E.unit_name(kind, tier) or make_unit(kind, tier, nil)
  end
end

local family_units = {}
for _, family in ipairs(E.FAMILY_ORDER) do
  family_units[family] = { biter = {}, spitter = {} }
  for _, kind in ipairs({ "biter", "spitter" }) do
    for tier = 1, E.TIERS do
      family_units[family][kind][tier] = make_unit(kind, tier, family)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Nids vanilla : 8 paliers redistribués sur l'évolution
---------------------------------------------------------------------------------------------------
local function result_units(units_by_kind, mix)
  local r = {}
  for tier = 1, E.TIERS do
    for _, kind in ipairs(mix) do
      r[#r + 1] = { units_by_kind[kind][tier], curve(tier) }
    end
  end
  return r
end

-- Le nid de déchiqueteurs ne produit que des déchiqueteurs ; le nid de cracheurs garde ses petits
-- déchiqueteurs de début de partie puis produit des cracheurs.
data.raw["unit-spawner"]["biter-spawner"].result_units = result_units(base_units, { "biter" })
local spitter_nest = result_units(base_units, { "spitter" })
table.insert(spitter_nest, 1, { "small-biter", { { 0.0, 0.3 }, { 0.35, 0 } } })
data.raw["unit-spawner"]["spitter-spawner"].result_units = spitter_nest

---------------------------------------------------------------------------------------------------
-- Nids de famille : mêmes courbes, unités de la famille, plus loin du départ
---------------------------------------------------------------------------------------------------
for _, family in ipairs(E.FAMILY_ORDER) do
  local f = E.families[family]
  local nest = lib.copy("unit-spawner", "biter-spawner")
  local name = E.nest_name(family)
  nest.name = name
  nest.order = "b-d-z[fo]-" .. family
  nest.localised_name = { "entity-name." .. name }
  local tint = { r = f.tint2.r, g = f.tint2.g, b = f.tint2.b, a = 0.6 }
  nest.animations = {
    spawner_idle_animation(0, tint), spawner_idle_animation(1, tint),
    spawner_idle_animation(2, tint), spawner_idle_animation(3, tint),
  }
  if f.glow then Evo.glow_masks(nest.animations, f.glow, 0.7) end
  nest.max_health = nest.max_health * 2
  nest.result_units = result_units(family_units[family], { "biter", "spitter" })
  nest.autoplace = enemy_autoplace.enemy_spawner_autoplace(f.nest_distance)
  nest.autoplace.probability_expression = nest.autoplace.probability_expression * E.family_nest_share

  local corpse = lib.copy("corpse", "biter-spawner-corpse")
  corpse.name = name .. "-corpse"
  corpse.animation = {
    spawner_die_animation(0, tint), spawner_die_animation(1, tint),
    spawner_die_animation(2, tint), spawner_die_animation(3, tint),
  }
  corpse.localised_name = { "", { "entity-name." .. name }, " (", { "fo-enemy.corpse" }, ")" }
  nest.corpse = corpse.name

  local icon = data.raw["unit-spawner"]["biter-spawner"]
  lib.set_icons(nest, lib.tier_icons(icon.icon, icon.icon_size, f.tint2, nil, icon.icon_mipmaps))
  lib.set_icons(corpse, lib.tier_icons(icon.icon, icon.icon_size, f.tint2, nil, icon.icon_mipmaps))
  out[#out + 1] = nest
  out[#out + 1] = corpse
end

---------------------------------------------------------------------------------------------------
-- Vers : paliers 5-8
---------------------------------------------------------------------------------------------------
for tier = E.VANILLA_TIERS + 1, E.TIERS do
  local spec = E.worm_tiers[tier]
  local tn = E.tier_names[tier]
  local w = lib.copy("turret", "behemoth-worm-turret")
  local name = E.worm_name(tier)
  w.name = name
  w.order = "b-c-z[fo]-" .. tier
  w.localised_name = { "entity-name." .. name }
  local scale = scale_worm_behemoth * spec.scale
  local nt = E.new_tiers[tier]
  local tint = { r = nt.tint2.r, g = nt.tint2.g, b = nt.tint2.b, a = 0.8 }
  w.max_health = w.max_health * spec.hp
  w.resistances = scaled_resistances(w.resistances, nt.resist, nt.resist)
  w.folded_animation = worm_folded_animation(scale, tint)
  w.preparing_animation = worm_preparing_animation(scale, tint, "forward")
  w.prepared_animation = worm_prepared_animation(scale, tint)
  w.prepared_alternative_animation = worm_prepared_alternative_animation(scale, tint)
  w.starting_attack_animation = worm_start_attack_animation(scale, tint)
  w.ending_attack_animation = worm_end_attack_animation(scale, tint)
  w.folding_animation = worm_preparing_animation(scale, tint, "backward")
  w.integration = worm_integration(scale)
  local wglow = Evo.tier_alpha(tier - E.VANILLA_TIERS, 0.35, 0.13)
  for _, field in ipairs({ "folded_animation", "preparing_animation", "prepared_animation", "prepared_alternative_animation",
    "starting_attack_animation", "ending_attack_animation", "folding_animation" }) do
    Evo.glow_masks(w[field], nt.tint2, wglow)
  end
  local range = range_worm_behemoth + spec.range
  w.attack_parameters.range = range
  w.attack_parameters.damage_modifier = damage_modifier_worm_behemoth * spec.damage
  w.attack_parameters.projectile_creation_parameters = worm_shoot_shiftings(scale, scale * scale_worm_stream)
  w.prepare_range = range + prepare_range_worm_behemoth
  local box_factor = spec.scale
  w.collision_box = lib.scale_box(w.collision_box, box_factor)
  w.selection_box = lib.scale_box(w.selection_box, box_factor)
  w.map_generator_bounding_box = lib.scale_box(w.map_generator_bounding_box, box_factor)
  w.build_base_evolution_requirement = spec.evo
  w.autoplace = enemy_autoplace.enemy_worm_autoplace(spec.autoplace_distance)

  local corpse = lib.copy("corpse", "behemoth-worm-corpse")
  corpse.name = name .. "-corpse"
  corpse.animation = worm_die_animation(scale, tint)
  corpse.localised_name = { "", { "entity-name." .. name }, " (", { "fo-enemy.corpse" }, ")" }
  w.corpse = corpse.name

  local icon = data.raw.turret["behemoth-worm-turret"]
  lib.set_icons(w, lib.tier_icons(icon.icon, icon.icon_size, tint, tier, icon.icon_mipmaps))
  lib.set_icons(corpse, lib.tier_icons(icon.icon, icon.icon_size, tint, nil, icon.icon_mipmaps))
  out[#out + 1] = w
  out[#out + 1] = corpse
end

data:extend(out)
