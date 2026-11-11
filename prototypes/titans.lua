--[[
  Lot TITANS (9/11, étendu le 10/11) : les titans ALLIÉS (T.ALLIES : JUGGERNAUT, SENTINELLE, LÉVIATHAN), entrées nouvelles de la famille
  des géants (appelé en fin de prototypes/experimentaux_geants.lua).
  Règles pures : shared/robots/titans.lua (T) ; feuilles : graphics/robots/titans/sprites.lua (généré par tools/render/pieces/titans/
  feuilles_titans.py, PNG hors de git, D-6) ; script : script/robots/titans.lua.
  - UN `spider-vehicle` PAR PALIER d'âge et PAR ARCHÉTYPE (T.PALIERS : âges 10 à 15) : PV, plaques (résistances), masse (vitesse) de la
    règle ; le script pose le palier de l'âge de la force et le remplace au changement d'âge (évolution dynamique). Un seul objet par
    archétype (palier 1 à la pose).
  - Corps : UNE image posée par `rendering` (comme les géants, Xp.GIANT_BODY), trois STADES d'images (T.stage) ; lueur fondue ; ombre.
    Léviathan : ses drones d'escorte sont des `rendering` de plus (sprite fo-titan-leviathan-drone), aucune entité.
  - Pattes : celles des géants (Xp.PREFIX .. "geant-patte-n", sans image ni collision) ; ils flottent.
  - Armes : effets par script : canon annulaire = rayon laser vanilla teinté cyan (fo-titan-canon) ; griffes = explosion d'éclair
    (sprite éclair-blanc des expérimentaux) teintée ; singularité = la même explosion + autocollant de ralentissement (fo-titan-singularite) ;
    salve de drones = fusée vanilla teintée, un projectile par palier (fo-titan-drone-tir-<palier>, dégâts de zone sur les ennemis) ;
    salve de zone = cratères des géants (fo-xp-cratere-<âge>).
  - Chaîne : 10 segments au Dock (catégorie des robots de palier 3), assemblage à l'usine de son âge, technologie après celle du robot
    de référence (Dock, Finback, Lévite).
]]

local lib = require("prototypes.lib")
local T = require("shared.robots.titans")
local Xp = require("shared.robots.experimentaux")
local Ro = require("shared.content.robots")
local C = require("shared.content.crafts")
local SPR = require("__factorio-overhaul__/graphics/robots/titans/sprites")
local XSPR = require("__factorio-overhaul__/graphics/robots/experimentaux/sprites")
-- LEVIATHAN-SEG (11/11) : un titan ARTICULÉ (règle `segmente`) a ses propres feuilles (tools/render/pieces/titans/feuilles_leviathan.py) :
-- `tete` (animée, 16 directions), une entrée par pièce fixe (segment, queue), icône du titan entier composée.
local SEG = {}
for _, r in ipairs(T.ALLIES) do
  if r.segmente then SEG[r.id] = require("__factorio-overhaul__/graphics/robots/titans/" .. r.id .. "/sprites") end
end

local out = {}

local function ingredients(list)
  local l = {}
  for _, g in ipairs(list) do l[#l + 1] = { type = "item", name = g[1], amount = g[2] } end
  return l
end

local function feuille(id, stage)
  local f = SPR[id]
  if SEG[id] and stage ~= "drone" then f = SEG[id].tete end   -- LEVIATHAN-SEG : la tête porte les feuilles animées et l'icône
  local s = f and (f[tostring(stage)] or f[stage])
  assert(s, "titans : feuille absente pour " .. tostring(id) .. " stade " .. tostring(stage) .. " (py -3.9 tools/render/pieces/titans/feuilles_titans.py)")
  return s
end

local function icones(id)
  local i = feuille(id, 1).icone
  return { { icon = i.filename, icon_size = i.size } }
end

-- Sprites du corps pour `rendering` : principale, lueur, ombre de chaque stade.
local function sprite(nom, def, opts)
  local function une(x)
    local t = { filename = x.filename, width = x.width, height = x.height, scale = x.scale, shift = { def.shift[1], def.shift[2] }, priority = "medium" }
    if opts.ombre then t.draw_as_shadow = true elseif opts.lueur then t.draw_as_glow = true; t.blend_mode = "additive" end
    return t
  end
  local t = une(def.lr)
  t.hr_version = une(def.hr)
  t.type = "sprite"
  t.name = nom
  t.flags = { "group=none" }
  return t
end

local function sprites_de(prefixe, s)
  out[#out + 1] = sprite(prefixe .. "-corps", s.main, {})
  for k, g in ipairs(s.lueurs) do out[#out + 1] = sprite(prefixe .. "-lueur-" .. k, g, { lueur = true }) end
  out[#out + 1] = sprite(prefixe .. "-ombre", s.ombre, { ombre = true })
end

-- Corps ANIMÉ (FINITIONS 10/11 : Juggernaut) : une `animation` par stade, animation (course, attaque), direction (8) et couche (corps,
-- lueur, ombre), dessinée par `rendering.draw_animation` (script/robots/titans.lua choisit la direction et la vitesse) ; un fichier par
-- direction (grille ll × lpf = images, lecture continue), densité propre à chaque couche (`dens`, l'ombre à demi-densité).
local function animations_de(r, stage, s)
  local A = SEG[r.id] and SEG[r.id].tete or SPR[r.id]
  for _, anim in ipairs({ "course", "attaque" }) do
    local a = s[anim]
    for dir = 0, A.directions - 1 do
      for _, c in ipairs({ { "corps", a.couches.main, {} }, { "lueur", a.couches.glow, { draw_as_glow = true, blend_mode = "additive" } },
        { "ombre", a.couches.shadow, { draw_as_shadow = true } } }) do
        local cc, extra = c[2], c[3]
        local function une(f, w, h, dens)
          local t = { filename = f, width = w, height = h, frame_count = a.images, line_length = cc.ll, scale = 32 / dens, shift = { cc.sx, cc.sy }, priority = "medium" }
          for k, v in pairs(extra) do t[k] = v end
          return t
        end
        local t = une(cc.lr[dir + 1], cc.lw, cc.lh, cc.dens / A.reduc)
        t.hr_version = une(cc.hr[dir + 1], cc.w, cc.h, cc.dens)
        t.type = "animation"
        t.name = T.anim_name(r, stage, anim, dir, c[1])
        out[#out + 1] = t
      end
    end
  end
end

--- LEVIATHAN-SEG : pièces FIXES d'un titan articulé (segment, queue) : un `sprite` par stade, direction et couche, posé par
--- script/robots/titans_serpent.lua (rendering.draw_sprite) ; nom T.piece_name(r, pièce, stade, direction, couche).
local function pieces_de(r, stage)
  local F = SEG[r.id]
  for _, piece in ipairs(r.segmente.pieces) do
    local P = F[piece]
    local a = P[tostring(stage)].pose
    for dir = 0, P.directions - 1 do
      for _, c in ipairs({ { "corps", a.couches.main, {} }, { "lueur", a.couches.glow, { draw_as_glow = true, blend_mode = "additive" } },
        { "ombre", a.couches.shadow, { draw_as_shadow = true } } }) do
        local cc, extra = c[2], c[3]
        local function une(f, w, h, dens)
          local t = { filename = f, width = w, height = h, scale = 32 / dens, shift = { cc.sx, cc.sy }, priority = "medium" }
          for k, v in pairs(extra) do t[k] = v end
          return t
        end
        local t = une(cc.lr[dir + 1], cc.lw, cc.lh, cc.dens / P.reduc)
        t.hr_version = une(cc.hr[dir + 1], cc.w, cc.h, cc.dens)
        t.type = "sprite"
        t.name = T.piece_name(r, piece, stage, dir, c[1])
        t.flags = { "group=none" }
        out[#out + 1] = t
      end
    end
  end
end

--- Gabarit d'un stade (largeur et haut de l'image en tuiles, depuis la position au sol), feuille fixe ou animée.
local function gabarit(s)
  if s.course then
    local c = s.course.couches.main
    return c.w / c.dens, c.sy - c.h / c.dens / 2
  end
  return s.main.lr.width * s.main.lr.scale / 32, s.main.shift[2]
end

for _, r in ipairs(T.ALLIES) do
  for stage = 1, T.STAGES do
    local s = feuille(r.id, stage)
    if s.course then animations_de(r, stage, s) else sprites_de(T.PREFIX .. r.id .. "-" .. stage, s) end
    if r.segmente then pieces_de(r, stage) end
  end
end
-- drone d'escorte du Léviathan (une image, sans ombre : il vole ; la lueur suit)
sprites_de(T.PREFIX .. "leviathan-drone", feuille("leviathan", "drone"))

-- Effets : rayon du canon annulaire (laser vanilla teinté cyan, sans dégâts moteur), éclair des griffes et de la singularité (sprite des
-- expérimentaux), autocollant de ralentissement de la singularité, projectiles des drones (un par palier : dégâts de zone sur les ennemis)
do
  local canon = table.deepcopy(data.raw.beam["laser-beam"])
  canon.name = T.PREFIX .. "canon"
  canon.localised_name = { "entity-name." .. T.PREFIX .. "canon" }
  canon.action = nil
  canon.damage_interval = 1000
  lib.tint_sprites(canon, { r = 0.35, g = 0.95, b = 1.0 })
  out[#out + 1] = canon
  local e = XSPR.effets["eclair-blanc"]
  local function eclair(nom, k, tint)
    return {
      type = "explosion", name = nom, flags = { "not-on-map", "hidden" }, subgroup = "explosions",
      localised_name = { "entity-name." .. nom },
      animations = { { filename = e.lr.filename, width = e.lr.width, height = e.lr.height, scale = e.lr.scale * k, frame_count = 1, line_length = 1,
        animation_speed = 1 / 12, blend_mode = "additive", draw_as_glow = true, tint = tint, shift = { 0, -0.5 },
        hr_version = { filename = e.hr.filename, width = e.hr.width, height = e.hr.height, scale = e.hr.scale * k, frame_count = 1, line_length = 1,
          animation_speed = 1 / 12, blend_mode = "additive", draw_as_glow = true, tint = tint, shift = { 0, -0.5 } } } },
      scale_initial = 0.4, scale_end = 1.2, scale_in_duration = 4, fade_out_duration = 10,
      light = { intensity = 0.7, size = 14, color = { r = tint.r, g = tint.g, b = tint.b } },
      sound = data.raw.explosion["big-explosion"].sound,
    }
  end
  out[#out + 1] = eclair(T.PREFIX .. "griffe", 1.4, { r = 0.3, g = 0.95, b = 1.0 })
  out[#out + 1] = eclair(T.PREFIX .. "singularite-eclair", 2.2, { r = 0.5, g = 0.85, b = 1.0 })
  local sg = T.SENTINELLE.singularite
  local sticker = lib.copy("sticker", "slowdown-sticker")
  sticker.name = T.PREFIX .. "singularite"
  sticker.localised_name = { "entity-name." .. T.PREFIX .. "singularite" }
  sticker.duration_in_ticks = sg.slow_ticks
  sticker.target_movement_modifier = sg.slow
  if sticker.animation then lib.tint_sprites(sticker.animation, { r = 0.3, g = 0.9, b = 1.0 }) end
  out[#out + 1] = sticker
  -- projectile des drones : fusée vanilla teintée, dégâts de zone (laser) sur les seuls ENNEMIS de la force qui tire ; un par palier
  local dr = T.LEVIATHAN.drones
  for palier = 1, T.PALIERS do
    local j = T.allie(T.LEVIATHAN, T.age_of_palier(palier))
    local p = lib.copy("projectile", "rocket")
    p.name = T.PREFIX .. "drone-tir-" .. palier
    p.localised_name = { "entity-name." .. T.PREFIX .. "drone-tir" }
    p.acceleration = 0.01
    p.turn_speed = 0.03
    p.light = { intensity = 0.6, size = 8, color = { r = 0.3, g = 0.9, b = 1.0 } }
    lib.tint_sprites(p, { r = 0.3, g = 0.95, b = 1.0 })
    p.action = { type = "area", radius = dr.radius, force = "enemy", action_delivery = { type = "instant", target_effects = {
      { type = "damage", damage = { amount = j.salve * dr.part / j.n_drones, type = j.dtype } },
      { type = "create-entity", entity_name = T.PREFIX .. "griffe" },
    } } }
    out[#out + 1] = p
  end
  -- KAIJUS-MUTANTS : projectiles de la mitraille du Ravageur (obus de canon vanilla teinté, vif, petite zone), un par palier
  local mi = T.RAVAGEUR.mitraille
  for palier = 1, T.PALIERS do
    local j = T.allie(T.RAVAGEUR, T.age_of_palier(palier))
    local p = lib.copy("projectile", "cannon-projectile")
    p.name = T.PREFIX .. "mitraille-" .. palier
    p.localised_name = { "entity-name." .. T.PREFIX .. "mitraille" }
    p.light = { intensity = 0.5, size = 6, color = { r = 0.3, g = 0.9, b = 1.0 } }
    lib.tint_sprites(p, { r = 0.4, g = 0.95, b = 1.0 })
    p.action = { type = "area", radius = 1.5, force = "enemy", action_delivery = { type = "instant", target_effects = {
      { type = "damage", damage = { amount = j.salve * mi.part / mi.n, type = j.dtype } },
      { type = "create-entity", entity_name = "explosion-hit" },
    } } }
    p.final_action = nil
    out[#out + 1] = p
  end
end

-- Pattes : celles des géants, déjà déclarées par prototypes/experimentaux_geants.lua
local POSES = { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }
local legs = {}
for n = 1, 4 do
  local nom = Xp.PREFIX .. "geant-patte-" .. n
  assert(data.raw["spider-leg"][nom], "titans : patte des géants absente " .. nom)
  legs[n] = { leg = nom, mount_position = { POSES[n][1] * 0.3, POSES[n][2] * 0.3 }, ground_position = POSES[n], blocking_legs = { 5 - n } }
end

-- ART-16DIR (11/11, F507) : le TORSE tourne vers la marche, à la vitesse du torse de l'araignée vanilla (données du jeu) : c'est la seule
-- orientation qu'un spider-vehicle tient à jour (LuaEntity.orientation reste 0 en marche, banc titans-marche) ; le script dessine le corps
-- dans la direction du torse. À 0 (avant), le torse restait à 0,375 et le corps glissait en marche, toujours tourné vers le nord.
local ARAIGNEE = data.raw["spider-vehicle"]["spidertron"]
assert(ARAIGNEE and ARAIGNEE.torso_rotation_speed and ARAIGNEE.torso_rotation_speed > 0, "titans : torse de l'araignée vanilla absent")

for ia, r in ipairs(T.ALLIES) do
  -- Un spider-vehicle par palier (évolution dynamique : le script remplace l'entité au changement d'âge)
  for palier = 1, T.PALIERS do
    local j = T.allie(r, T.age_of_palier(palier))
    local largeur, haut = gabarit(feuille(r.id, j.stage))
    local hw = math.max(2, math.floor(largeur / 4))
    local top = math.min(-2, math.floor(haut))
    out[#out + 1] = {
      type = "spider-vehicle", name = j.name,
      localised_name = { "entity-name." .. j.name }, localised_description = { "entity-description." .. r.name },
      icons = icones(r.id),
      collision_box = { { -2, -2 }, { 2, 2 } }, collision_mask = {}, sticker_box = { { -4, -4 }, { 4, 4 } },
      selection_box = { { -hw, top }, { hw, 0 } }, selection_priority = 20,
      drawing_box = { { -30, -60 }, { 30, 20 } },
      flags = { "placeable-neutral", "player-creation", "placeable-off-grid", "not-blueprintable", "not-flammable" },
      minable = { mining_time = 2, result = r.name },
      max_health = j.hp, healing_per_tick = j.hp / 60 / 600, resistances = table.deepcopy(j.resistances),
      dying_explosion = "massive-explosion",
      map_color = { r = r.lueur.r, g = r.lueur.g, b = r.lueur.b }, friendly_map_color = { r = r.lueur.r, g = r.lueur.g, b = r.lueur.b },
      enemy_map_color = { r = 1.0, g = 0.2, b = 0.1 },
      weight = 1, braking_force = 1, friction_force = 1, energy_per_hit_point = 1,
      allow_passengers = false, inventory_size = 0, trash_inventory_size = 0, energy_source = { type = "void" },
      chunk_exploration_radius = 3, automatic_weapon_cycling = false, chain_shooting_cooldown_modifier = 1,
      movement_energy_consumption = "1kW", height = 0, torso_bob_speed = 0, torso_rotation_speed = ARAIGNEE.torso_rotation_speed,
      sound_minimum_speed = 0.05, sound_scaling_ratio = 0.6,
      working_sound = { sound = { filename = "__base__/sound/spidertron/spidertron-vox.ogg", volume = 0.4 }, match_speed_to_activity = true },
      spider_engine = { legs = table.deepcopy(legs), military_target = "spidertron-military-target" },
      graphics_set = { render_layer = "air-object", base_render_layer = "object", autopilot_destination_visualisation_render_layer = "object" },
      order = string.format("z[fo-titan]-%d-%02d", ia, palier),
    }
  end

  -- objet (pose : palier 1, le script met le palier de l'âge), segment, recettes, technologie
  out[#out + 1] = {
    type = "item-with-entity-data", name = r.name, localised_name = { "entity-name." .. r.name },
    localised_description = { "item-description." .. r.name }, icons = icones(r.id), subgroup = T.SUBGROUP,
    order = string.format("c[xp-geant]-99-titan-%d", ia), place_result = T.allie_name(r, 1), stack_size = 1,
  }
  local seg_icons = icones(r.id)
  seg_icons[#seg_icons + 1] = { icon = "__base__/graphics/icons/low-density-structure.png", icon_size = 64, icon_mipmaps = 4, scale = 0.25, shift = { -8, 8 } }
  out[#out + 1] = {
    type = "item", name = r.segment_item, localised_name = { "item-name." .. r.segment_item },
    localised_description = { "item-description." .. r.segment_item }, icons = seg_icons, subgroup = T.SUBGROUP,
    order = string.format("d[xp-segment]-99-titan-%d", ia), stack_size = 10,
  }
  local seg_cat = Ro.factory(Xp.SEGMENT_FACTORY).category
  out[#out + 1] = {
    type = "recipe", name = r.segment_recipe, category = seg_cat, enabled = false, energy_required = r.segment.time,
    ingredients = ingredients(r.segment.ingredients), results = { { type = "item", name = r.segment_item, amount = 1 } },
    main_product = r.segment_item, localised_name = { "item-name." .. r.segment_item },
  }
  out[#out + 1] = {
    type = "recipe", name = r.recipe, category = T.category(r), enabled = false, energy_required = r.time,
    ingredients = ingredients(r.ingredients), results = { { type = "item", name = r.name, amount = 1 } }, main_product = r.name,
    localised_name = { "entity-name." .. r.name },
  }
  local after = Ro.tech(r.after)
  assert(after, "titans : technologie de robot absente " .. tostring(r.after))
  out[#out + 1] = lib.technology({
    name = r.tech,
    localised_name = { "technology-name." .. r.tech }, localised_description = { "technology-description." .. r.tech },
    icons = { { icon = feuille(r.id, T.STAGES).icone.filename, icon_size = 64 } },
    effects = { lib.unlock(r.segment_recipe), lib.unlock(r.recipe) }, prerequisites = { r.after },
    count = Xp.tech_units(C.tech_count(after)), packs = C.packs(r.age), time = 30,
    order = "z[fo]-robots-xp-titan-" .. ia,
  })
end

data:extend(out)
