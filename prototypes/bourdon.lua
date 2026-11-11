-- LE BOURDON, expérimental de l'âge 15 (lot BOURDON, 1er/11) : cloche-cathédrale en lévitation. Le prototype existe toujours (réglage
-- fo-war-robots non requis). Depuis le lot ROBOTS-JEU (3/11), il se FABRIQUE au Portique (objet, recette, technologie : fin de ce
-- fichier) ; les commandes de démonstration (script/robots/bourdon.lua) restent.
--
-- `spider-vehicle` (RB-0, E3, E9) : marche sans chemin, autopilote, télécommande de vanilla. Toute l'image passe par `rendering`
-- (script/robots/bourdon.lua) : flottement, chaînes, ancres et Glas en dépendent, et l'entité, son `position`, reste invisible.
-- Pattes sans image, de collision nulle : elle passe partout, eau comprise.

local SPR = require("__factorio-overhaul__/graphics/robots/bourdon/sprites")
local Ech = require("shared.robots.echelle")
local AGE_BOURDON = require("shared.robots.bourdon").AGE

local protos = {}

local function bloc(e, s)
  local b = { filename = e.filename, width = e.width, height = e.height, scale = e.scale }
  if s.blend then b.blend_mode = s.blend end
  if s.ombre then b.draw_as_shadow = true end
  if s.lueur then b.draw_as_glow = true end
  return b
end

local cles = {}
for k in pairs(SPR) do cles[#cles + 1] = k end
table.sort(cles)
for _, k in ipairs(cles) do
  local s = SPR[k]
  local p = bloc(s.lr, s)
  p.type = "sprite"
  p.name = "fo-bourdon-" .. k
  p.flags = { "group=none" }
  p.hr_version = bloc(s.hr, s)
  protos[#protos + 1] = p
end

local ICONE = "__factorio-overhaul__/graphics/robots/icones/fo-bourdon.png" -- lot ROBOTS-JEU : icône de la cloche (tools/render/pieces/experimentaux/icone_bourdon.py)

local function patte(n)
  return {
    type = "spider-leg",
    name = "fo-bourdon-patte-" .. n,
    localised_name = { "entity-name.fo-bourdon" },
    collision_box = { { -0.05, -0.05 }, { 0.05, 0.05 } },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    icon = ICONE, icon_size = 64, icon_mipmaps = 4,
    collision_mask = {},
    selectable_in_game = false,
    flags = { "not-on-map", "not-blueprintable", "not-deconstructable", "hidden", "not-flammable" },
    target_position_randomisation_distance = 0.25,
    minimal_step_size = 1,
    part_length = 3.5,
    initial_movement_speed = 0.025,
    movement_acceleration = 0.012,
    max_health = 100,
    movement_based_position_selection_distance = 4,
    graphics_set = {},
  }
end

local pattes = {}
local POSES = { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }
for n = 1, 4 do
  protos[#protos + 1] = patte(n)
  local opp = { 4, 3, 2, 1 }
  pattes[n] = {
    leg = "fo-bourdon-patte-" .. n,
    mount_position = { POSES[n][1] * 0.3, POSES[n][2] * 0.3 },
    ground_position = POSES[n],
    blocking_legs = { opp[n] },
  }
end

protos[#protos + 1] = {
  type = "spider-vehicle",
  name = "fo-bourdon",
  localised_name = { "entity-name.fo-bourdon" },
  localised_description = { "entity-description.fo-bourdon" },
  icon = ICONE, icon_size = 64, icon_mipmaps = 4,
  collision_box = { { -2, -2 }, { 2, 2 } },
  collision_mask = {},
  sticker_box = { { -4, -4 }, { 4, 4 } },
  selection_box = { { -11, -44 }, { 11, 0 } }, -- le moteur exige que la boîte passe à moins de 0,5 de l'origine
  selection_priority = 20, -- le bâtiment dessous reste cliquable
  drawing_box = { { -40, -66 }, { 40, 26 } },
  flags = { "placeable-neutral", "player-creation", "placeable-off-grid", "not-blueprintable", "not-deconstructable", "not-flammable", "not-repairable" },
  -- Règle d'échelle (lot EXPERIMENTAUX-PUISSANCE ; réponses du DC du 5/11, accord du lead) : PV et résistances de son âge (15) ;
  -- avant : 60 000 PV, résistances 10 à 50 fixes et 50 à 90 % par type. L'attaque (Glas) reste telle quelle.
  max_health = Ech.pv(AGE_BOURDON),
  healing_per_tick = Ech.soin(Ech.pv(AGE_BOURDON), 0.5, 60000), -- même part du maximum qu'avant (0,5 pour 60 000 : 33 min 20 s pour tout reprendre)
  resistances = Ech.resistances(AGE_BOURDON),
  dying_explosion = "massive-explosion",
  map_color = { r = 0.95, g = 0.8, b = 0.42 },
  friendly_map_color = { r = 1.0, g = 0.85, b = 0.45 },
  enemy_map_color = { r = 1.0, g = 0.2, b = 0.1 },
  weight = 1,
  braking_force = 1,
  friction_force = 1,
  energy_per_hit_point = 1,
  allow_passengers = false,
  inventory_size = 0,
  trash_inventory_size = 0,
  energy_source = { type = "void" },
  chunk_exploration_radius = 3,
  automatic_weapon_cycling = false,
  chain_shooting_cooldown_modifier = 1,
  movement_energy_consumption = "1kW",
  height = 0,
  torso_bob_speed = 0,
  torso_rotation_speed = 0,
  sound_minimum_speed = 0.05,
  sound_scaling_ratio = 0.6,
  working_sound = {
    sound = { filename = "__base__/sound/spidertron/spidertron-vox.ogg", volume = 0.5 },
    match_speed_to_activity = true,
  },
  spider_engine = { legs = pattes, military_target = "spidertron-military-target" },
  graphics_set = {
    render_layer = "air-object",
    base_render_layer = "object",
    autopilot_destination_visualisation_render_layer = "object",
  },
}

-- ------------------------------------------------------------------------------------------------ le Méga-Bourdon (lot MEGA-BOURDON, 11/11)
-- La même cloche, cuirassée et armée (règles et valeurs : shared/robots/bourdon.lua, B.MEGA). Même `spider-vehicle` invisible, mêmes pattes ;
-- PV doublés (il compte pour deux géants). Son image (corps cuirassé, casemates, anneau magnétique, lueur cyan) : graphics/robots/megabourdon.
local VEHICULE = protos[#protos]
assert(VEHICULE.name == "fo-bourdon", "bourdon : le véhicule doit précéder le Méga-Bourdon")
do
  local Bm = require("shared.robots.bourdon")
  local mega = table.deepcopy(VEHICULE)
  mega.name = Bm.MEGA.NOM
  mega.localised_name = { "entity-name." .. Bm.MEGA.NOM }
  mega.localised_description = { "entity-description." .. Bm.MEGA.NOM }
  mega.icon = nil
  mega.icons = { { icon = "__factorio-overhaul__/graphics/robots/megabourdon/icone.png", icon_size = 64, icon_mipmaps = 4 } }
  mega.max_health = Bm.pv_mega(VEHICULE.max_health)
  mega.healing_per_tick = Bm.pv_mega(VEHICULE.healing_per_tick)
  mega.map_color = { r = 0.35, g = 0.9, b = 1.0 }
  mega.friendly_map_color = { r = 0.4, g = 0.95, b = 1.0 }
  -- lot ART-MEGA2 : boîtes de sélection, de dessin et d'autocollants à l'échelle de ses feuilles (sprites.lua, « echelle », rendue à
  -- B.MEGA.ECHELLE) ; la boîte de collision reste celle du Bourdon (masque vide : elle ne touche rien)
  local SPRE = require("__factorio-overhaul__/graphics/robots/megabourdon/sprites")
  if SPRE.echelle then
    assert(math.abs(SPRE.echelle - Bm.MEGA.ECHELLE) < 1e-9, "mega-bourdon : feuilles à l'échelle " .. tostring(SPRE.echelle))
    mega.selection_box = Bm.boite_mega(VEHICULE.selection_box)
    mega.drawing_box = Bm.boite_mega(VEHICULE.drawing_box)
    mega.sticker_box = Bm.boite_mega(VEHICULE.sticker_box)
  end
  protos[#protos + 1] = mega
end

-- Poussière de l'onde, levée le long du front ; braises et fumée sur les ruines : trivial-smoke, sans entité.
local smoke = require("__base__/prototypes/entity/smoke-animations")
protos[#protos + 1] = {
  type = "trivial-smoke",
  name = "fo-bourdon-poussiere",
  animation = smoke.trivial_smoke_fast({ animation_speed = 1 / 5, scale = 1.1 }),
  duration = 70,
  fade_in_duration = 6,
  fade_away_duration = 40,
  start_scale = 0.8,
  end_scale = 2.4,
  spread_duration = 40,
  affected_by_wind = false,
  movement_slow_down_factor = 0.96,
  render_layer = "smoke",
  show_when_smoke_off = true,
  color = { r = 0.42, g = 0.32, b = 0.2, a = 0.7 },
}
protos[#protos + 1] = {
  type = "trivial-smoke",
  name = "fo-bourdon-fumee",
  animation = smoke.trivial_smoke_fast({ animation_speed = 1 / 8, scale = 1.6 }),
  duration = 420,
  fade_in_duration = 30,
  fade_away_duration = 200,
  start_scale = 0.6,
  end_scale = 3.2,
  spread_duration = 300,
  affected_by_wind = true,
  movement_slow_down_factor = 0.96,
  render_layer = "smoke",
  show_when_smoke_off = true,
  color = { r = 0.1, g = 0.085, b = 0.075, a = 0.75 },
}

-- Flamme sur une ruine ennemie : une image de feu de vanilla, sans dégâts, jamais un `fire` (ne se propage pas, ne touche personne).
protos[#protos + 1] = {
  type = "explosion",
  name = "fo-bourdon-flamme",
  flags = { "not-on-map", "hidden" },
  subgroup = "explosions",
  render_layer = "object",
  animations = {
    {
      filename = "__base__/graphics/entity/fire-flame/fire-flame-13.png",
      line_length = 8, width = 60, height = 118, frame_count = 25,
      animation_speed = 0.16, scale = 1.25, shift = { 0, -1.2 }, blend_mode = "additive",
    },
  },
}

protos[#protos + 1] = {
  type = "explosion",
  name = "fo-bourdon-flamme2",
  localised_name = { "entity-name.fo-bourdon-flamme" },
  flags = { "not-on-map", "hidden" },
  subgroup = "explosions",
  render_layer = "object",
  animations = {
    {
      filename = "__base__/graphics/entity/fire-flame/fire-flame-13.png",
      line_length = 8, width = 60, height = 118, frame_count = 25,
      animation_speed = 0.12, scale = 0.9, shift = { 0, -0.9 }, blend_mode = "additive",
    },
  },
}

-- La cloche : l'explosion nucléaire de vanilla, jouée bas (pas de pipeline de son, S0).
protos[#protos + 1] = {
  type = "sound",
  name = "fo-bourdon-glas",
  category = "environment",
  aggregation = { max_count = 2, remove = false },
  audible_distance_modifier = 8,
  speed = 0.55,
  filename = "__base__/sound/fight/nuclear-explosion-1.ogg",
  volume = 1.0,
}
protos[#protos + 1] = {
  type = "sound",
  name = "fo-bourdon-ancre",
  category = "environment",
  aggregation = { max_count = 3, remove = false },
  audible_distance_modifier = 4,
  speed = 0.6,
  filename = "__base__/sound/fight/large-explosion-1.ogg",
  volume = 0.9,
}

-- Le coup vers le curseur (une commande ne connaît pas le curseur, l'événement de touche si).
protos[#protos + 1] = {
  type = "custom-input",
  name = "fo-bourdon-glas",
  key_sequence = "CONTROL + SHIFT + G",
  consuming = "none",
  order = "c[fo-bourdon]-a",
}

-- ------------------------------------------------------------------------------------------------ fabrication (lot ROBOTS-JEU, 3/11)
-- Objet fabriqué au Portique, posé à la main : il pose le RELAIS `fo-bourdon-pose`, que script/robots/bourdon.lua remplace aussitôt par
-- la descente du Bourdon (plafond de géants vérifié ; refusé : l'objet est rendu). Raisons et données : shared/robots/bourdon.lua.
do
  local B = require("shared.robots.bourdon")
  local Ro = require("shared.content.robots")
  local C = require("shared.content.crafts")
  local lib = require("prototypes.lib")
  local ICONES = { { icon = "__factorio-overhaul__/graphics/robots/icones/fo-bourdon.png", icon_size = 64, icon_mipmaps = 4 } }
  local usine = assert(Ro.factory(B.USINE), "bourdon : usine inconnue " .. B.USINE)
  local ings = {}
  for _, g in ipairs(B.FAB.ingredients) do ings[#ings + 1] = { type = "item", name = g[1], amount = g[2] } end
  protos[#protos + 1] = {
    type = "item", name = B.OBJET,
    localised_name = { "entity-name.fo-bourdon" }, localised_description = { "item-description." .. B.OBJET },
    icons = ICONES, subgroup = Ro.SUBGROUP, order = "b[kit]-99[bourdon]", stack_size = 1,
    place_result = B.POSE,
  }
  protos[#protos + 1] = {
    type = "simple-entity-with-owner", name = B.POSE,
    localised_name = { "entity-name.fo-bourdon" }, localised_description = { "item-description." .. B.OBJET },
    icons = ICONES,
    flags = { "placeable-neutral", "player-creation", "placeable-off-grid", "not-blueprintable", "not-deconstructable", "not-on-map" },
    collision_box = { { -1.9, -1.9 }, { 1.9, 1.9 } }, collision_mask = {},
    selection_box = { { -2, -2 }, { 2, 2 } },
    max_health = 100, render_layer = "object",
    picture = { filename = ICONES[1].icon, width = 64, height = 64, scale = 2, shift = { 0, -1 } },
  }
  protos[#protos + 1] = {
    type = "recipe", name = B.RECETTE, category = usine.category, enabled = false, energy_required = B.FAB.temps,
    ingredients = ings, results = { { type = "item", name = B.OBJET, amount = 1 } }, main_product = B.OBJET,
    localised_name = { "entity-name.fo-bourdon" },
  }
  protos[#protos + 1] = lib.technology({
    name = B.TECH.name,
    localised_name = { "technology-name." .. B.TECH.name }, localised_description = { "technology-description." .. B.TECH.name },
    icons = ICONES,
    effects = { lib.unlock(B.RECETTE) }, prerequisites = B.TECH.prerequisites,
    count = C.tech_count(B.TECH), packs = C.packs(B.TECH.epoch), time = B.TECH.time,
    order = "z[fo]-robots-" .. B.TECH.name,
  })
end

-- ------------------------------------------------------------------------------------------------ Méga-Bourdon : images, orbe, fabrication
do
  local Bm = require("shared.robots.bourdon")
  local A = require("shared.content.arsenal")
  local Ech2 = require("shared.robots.echelle")
  local Ro = require("shared.content.robots")
  local C = require("shared.content.crafts")
  local lib = require("prototypes.lib")
  -- images (feuilles générées : tools/render/pieces/experimentaux/feuilles_mega.py)
  local SPRM = require("__factorio-overhaul__/graphics/robots/megabourdon/sprites")
  local cles_m = {}
  for k in pairs(SPRM) do if type(SPRM[k]) == "table" and SPRM[k].hr then cles_m[#cles_m + 1] = k end end
  table.sort(cles_m)
  for _, k in ipairs(cles_m) do
    local s = SPRM[k]
    if s.hr.tuiles then
      -- lot ART-MEGA2 : feuille découpée en tuiles (au-delà de 4096 px de côté). En 1.1, le prototype `sprite` n'a ni `layers` ni `stripes`
      -- (schéma 1.1.91, tests/datastage/schema.lua) : UN sprite par tuile, fo-mega-bourdon-<cle>-t<i>, hr_version tuile par tuile ; le
      -- script les dessine ensemble, chacune à son décalage (script/robots/bourdon.lua, dessine_v).
      assert(s.lr.tuiles and #s.lr.tuiles == #s.hr.tuiles, "mega-bourdon : tuiles " .. k)
      for i, th in ipairs(s.hr.tuiles) do
        local pm = bloc(s.lr.tuiles[i], s)
        pm.hr_version = bloc(th, s)
        pm.type = "sprite"
        pm.name = Bm.MEGA.NOM .. "-" .. k .. "-t" .. i
        pm.flags = { "group=none" }
        protos[#protos + 1] = pm
      end
    else
      local pm = bloc(s.lr, s)
      pm.hr_version = bloc(s.hr, s)
      pm.type = "sprite"
      pm.name = Bm.MEGA.NOM .. "-" .. k
      pm.flags = { "group=none" }
      protos[#protos + 1] = pm
    end
  end
  -- l'orbe des casemates : celle du Bastion d'armement 4, plus grosse, cyan, aux dégâts de l'âge de la cloche
  -- Lot MEGA-BALISTIQUE : l'essaim du mod, lu dans data.raw (après prototypes.enemies et les titans) : les unités que produisent les
  -- nids, titans exclus (T.PREFIX : Kaijus, Écorchés), avec leurs PV et leurs résistances laser et explosion. Noms triés.
  local function essaim()
    local T = require("shared.robots.titans")
    local nids, vus, cibles = {}, {}, {}
    for nn in pairs(data.raw["unit-spawner"]) do nids[#nids + 1] = nn end
    table.sort(nids)
    local noms = {}
    for _, nn in ipairs(nids) do
      for _, ru in ipairs(data.raw["unit-spawner"][nn].result_units or {}) do
        local un = ru[1] or ru.unit
        if type(un) == "string" and not vus[un] and un:sub(1, #T.PREFIX) ~= T.PREFIX then
          vus[un] = true
          noms[#noms + 1] = un
        end
      end
    end
    table.sort(noms)
    for _, un in ipairs(noms) do
      local u = assert(data.raw.unit[un], "mega-bourdon : unité d'essaim absente " .. un)
      local res = {}
      for _, r in ipairs(u.resistances or {}) do
        if r.type == "laser" or r.type == "explosion" then res[r.type] = { decrease = r.decrease or 0, percent = r.percent or 0 } end
      end
      cibles[#cibles + 1] = { nom = un, pv = assert(u.max_health, "mega-bourdon : PV de " .. un), res = res }
    end
    assert(#cibles > 0, "mega-bourdon : aucune unité d'essaim dans les nids")
    return cibles
  end
  local spec = A.age_turret(Bm.MEGA.ARME_AGE)
  local cibles = essaim()
  local arme = assert(Bm.arme_mega(spec, Ech2.salve(Bm.AGE, "laser"), Ech2.salve(Bm.AGE, "explosion"), cibles), "mega-bourdon : arme")
  for _, c in ipairs(cibles) do
    assert(Bm.zone_tue(arme.zone_laser, arme.zone_explosion, c), "mega-bourdon : la zone d'un tir ne tue pas " .. c.nom)
    assert(Bm.direct_tue(arme.direct, c), "mega-bourdon : le coup direct ne tue pas " .. c.nom)
  end
  assert(arme.rayon == spec.plasma.radius * Bm.MEGA.RAYON_X, "mega-bourdon : rayon")
  log(string.format("[FO-MEGA] orbe : rayon %g (Bastion %g) ; direct %d, zone laser %d, zone explosion %d (facteur %.3f) ; %d unités"
    .. " d'essaim ; plus forte (zone) %s ; plus blindée (direct) %s", arme.rayon, spec.plasma.radius, arme.direct, arme.zone_laser,
    arme.zone_explosion, arme.facteur, #cibles, tostring(arme.plus_forte), tostring(arme.plus_blindee)))
  local base = assert(data.raw.projectile[spec.name .. "-orb"], "mega-bourdon : orbe du Bastion absente")
  local orbe = table.deepcopy(base)
  orbe.name = Bm.MEGA.ORBE
  orbe.localised_name = { "entity-name." .. Bm.MEGA.NOM }
  lib.scale_sprites(orbe.animation, 1.5)
  local CYAN = { r = 0.35, g = 0.95, b = 1.0, a = 1.0 }
  local function teinte(a)
    if type(a) ~= "table" then return end
    if a.filename or a.stripes then a.tint = CYAN end
    if a.hr_version then teinte(a.hr_version) end
    if a.layers then for _, l in ipairs(a.layers) do teinte(l) end end
  end
  teinte(orbe.animation)
  orbe.light = { intensity = 0.9, size = 12, color = CYAN }
  orbe.action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        { type = "create-entity", entity_name = "big-explosion" },
        { type = "damage", damage = { amount = arme.direct, type = "laser" } },
        { type = "create-entity", entity_name = "medium-scorchmark-tintable", check_buildability = true },
        { type = "nested-result", action = { type = "area", radius = arme.rayon, force = "enemy",
          action_delivery = { type = "instant", target_effects = {
            { type = "damage", damage = { amount = arme.zone_laser, type = "laser" } },
            { type = "damage", damage = { amount = arme.zone_explosion, type = "explosion" } } } } } },
      },
    },
  }
  protos[#protos + 1] = orbe
  -- fabrication : au Portique, après le Bourdon
  local ICM = { { icon = "__factorio-overhaul__/graphics/robots/megabourdon/icone.png", icon_size = 64, icon_mipmaps = 4 } }
  local usine = assert(Ro.factory(Bm.USINE), "mega-bourdon : usine inconnue " .. Bm.USINE)
  local ings = {}
  for _, g in ipairs(Bm.FAB_MEGA.ingredients) do ings[#ings + 1] = { type = "item", name = g[1], amount = g[2] } end
  protos[#protos + 1] = {
    type = "item", name = Bm.MEGA.OBJET,
    localised_name = { "entity-name." .. Bm.MEGA.NOM }, localised_description = { "item-description." .. Bm.MEGA.OBJET },
    icons = ICM, subgroup = Ro.SUBGROUP, order = "b[kit]-99[bourdon]-b[mega]", stack_size = 1,
    place_result = Bm.MEGA.POSE,
  }
  protos[#protos + 1] = {
    type = "simple-entity-with-owner", name = Bm.MEGA.POSE,
    localised_name = { "entity-name." .. Bm.MEGA.NOM }, localised_description = { "item-description." .. Bm.MEGA.OBJET },
    icons = ICM,
    flags = { "placeable-neutral", "player-creation", "placeable-off-grid", "not-blueprintable", "not-deconstructable", "not-on-map" },
    collision_box = { { -1.9, -1.9 }, { 1.9, 1.9 } }, collision_mask = {},
    selection_box = { { -2, -2 }, { 2, 2 } },
    max_health = 100, render_layer = "object",
    picture = { filename = ICM[1].icon, width = 64, height = 64, scale = 2, shift = { 0, -1 } },
  }
  protos[#protos + 1] = {
    type = "recipe", name = Bm.MEGA.RECETTE, category = usine.category, enabled = false, energy_required = Bm.FAB_MEGA.temps,
    ingredients = ings, results = { { type = "item", name = Bm.MEGA.OBJET, amount = 1 } }, main_product = Bm.MEGA.OBJET,
    localised_name = { "entity-name." .. Bm.MEGA.NOM },
  }
  protos[#protos + 1] = lib.technology({
    name = Bm.TECH_MEGA.name,
    localised_name = { "technology-name." .. Bm.TECH_MEGA.name }, localised_description = { "technology-description." .. Bm.TECH_MEGA.name },
    icons = ICM,
    effects = { lib.unlock(Bm.MEGA.RECETTE) }, prerequisites = Bm.TECH_MEGA.prerequisites,
    count = C.tech_count(Bm.TECH_MEGA), packs = C.packs(Bm.TECH_MEGA.epoch), time = Bm.TECH_MEGA.time,
    order = "z[fo]-robots-" .. Bm.TECH_MEGA.name,
  })
end

data:extend(protos)
