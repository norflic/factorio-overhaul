--[[
  Lots RB-1 CHAÎNE (31/10), RB-4 GAMME et RB-5 GÉANTS (1/11) : prototypes des robots. Données : shared/content/robots.lua ;
  exécution : script/robots/*.

  - 4 usines (Atelier, Hall, Dock, Portique) : `assembling-machine` (comportement d'un assembleur vanilla, images de
    graphics/robots/usines, lot US-V1 ; PNG hors de git, D-6 : sprites.lua, généré par tools/render/pieces/usines_robots/feuilles.py),
    une catégorie de fabrication chacune « fo-robots-1 » à « -4 » ; ni fluide, ni productivité (le kit pèse 1 case, RB0-3). Image fixe,
    ombre séparée ; au travail, la lueur s'allume, avec une lumière, et l'atelier fume (fumée vanilla : 0 image neuve).
  - Kit : objet de pile 1, produit de la recette du robot (ingrédients d'au plus 100 chacun : RB0-1). Son `place_result` est
    l'unité du joueur (le cerveau lit ce lien ; un kit posé à la main est inscrit au registre par script/robots/usine.lua).
  - Unité : `unit` par PROPRIÉTAIRE (le joueur et les 4 factions) : une unité n'a pas de couleur au jeu (PLAN §3). Sans feuille (repli
    seulement, aucun robot depuis ROBOTS-JEU) : animations des cracheurs vanilla régénérées avec d'autres teintes et tailles (F36).
  - Arme : tir à portée de catégorie « fo-robot », PV et dégâts CALIBRÉS par shared/robots/duel.lua ; zone (`area`), portée minimale
    (artillerie), aucun dégât (Cloche : le soin est un script, script/robots/soutien.lua).
  - Géant (âges 13 à 15) : `spider-vehicle` fabriqué par `create_spidertron` (fonction du jeu de base), un canon de portée 100 (RB0 :
    zones mortes au-delà de l'échelle 3 avec un canon de 60), munition posée par script (script/robots/geant.lua) ; 10 segments (dock)
    puis un assemblage final (portique).
  - Lot RB-V1 (1/11) : un robot qui a une feuille (SPR[r.id]) a ses vraies images : marche, tir, ombre, lueur et une couche de PEINTURE teinte
    par propriétaire (unité) ou à l'exécution (géant : torse à plusieurs directions, pièces de pattes communes). Sans feuille : visuel provisoire.
    Lot ROBOTS-JEU (3/11) : les 12 robots ont leur feuille (Trotte-Vapeur et Lévite à 16 directions, Écaille et Bobineur aussi depuis RB16 (4/11), les 5 autres terrestres à 8, les 3 géants :
    torse à 16 directions et pattes dessinées) ; la RotatedAnimation d'une unité accepte 8 directions (prototype-api : direction_count).
  - Technologies : une par palier, plus celles des pièces (prototypes/robot_parts.lua).
  À charger APRÈS prototypes/enemies.lua (les globales des animations des cracheurs) et prototypes/robot_parts.lua : voir data.lua.
]]

local lib = require("prototypes.lib")
local Ro = require("shared.content.robots")
local F = require("shared.faction.config")
local C = require("shared.content.crafts")
local SPR_US = require("__factorio-overhaul__/graphics/robots/usines/sprites") -- lot US-V1 : usines (tools/render/pieces/usines_robots/feuilles.py)
local Vis = require("prototypes.robotique_icones") -- icônes dédiées (lot DA-ICONES) : segments, technologies ; kits en repli
local SPR = require("__factorio-overhaul__/graphics/robots/sprites") -- lot RB-V1 : feuilles par identifiant de robot (tools/render/pieces/robots/feuilles.py)

local out = {}

out[#out + 1] = { type = "item-subgroup", name = Ro.SUBGROUP, group = "combat", order = "z[fo]-robots" }
out[#out + 1] = { type = "ammo-category", name = Ro.AMMO_CATEGORY }
out[#out + 1] = { type = "ammo-category", name = Ro.SHELL_CATEGORY }
for _, c in ipairs(Ro.CATEGORIES) do out[#out + 1] = { type = "recipe-category", name = c } end

local STEEL = { r = 0.62, g = 0.67, b = 0.74 }
local KIT_TINT = { r = 0.75, g = 0.80, b = 0.90 }

local function icons_of(ptype, name, tint)
  local src = data.raw[ptype][name] or (ptype == "item" and data.raw["item-with-entity-data"][name])
  assert(src, "robots : icône source absente " .. ptype .. "/" .. name)
  return { { icon = src.icon, icon_size = src.icon_size, icon_mipmaps = src.icon_mipmaps, tint = tint } }
end

local function ingredients(list)
  local out_l = {}
  for _, g in ipairs(list) do out_l[#out_l + 1] = { type = "item", name = g[1], amount = g[2] } end
  return out_l
end

---------------------------------------------------------------------------------------------------
-- Usines
---------------------------------------------------------------------------------------------------
local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }

--- Couche d'une feuille : normale 32 px/tuile + hr_version 64 px/tuile (scale 0,5). Ombre et lueur : sur le modèle de levels/command.lua.
local function usine_couche(def, kind)
  local function une(r, hr)
    local t = { filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] }, priority = "high", frame_count = 1 }
    if kind == "shadow" then
      t.draw_as_shadow = true
    elseif kind == "glow" then
      t.draw_as_glow = true
      t.blend_mode = "additive"
      t.flags = { "linear-minification" }
    else
      t.flags = { "linear-minification" }
    end
    if hr then t.scale = 0.5 end
    return t
  end
  local s = une(def.lr, false)
  s.hr_version = une(def.hr, true)
  return s
end

-- Lumière au travail (F37) : couleur de l'âge, rayon à la taille de l'usine. Hall : les cristaux respirent (effet du moteur).
local USINE_LUMIERE = {
  atelier = { color = { r = 1.0, g = 0.75, b = 0.38 }, size = 8, intensity = 0.5 },
  hall = { color = { r = 0.69, g = 0.44, b = 1.0 }, size = 14, intensity = 0.6, effect = "uranium-glow" },
  dock = { color = { r = 0.23, g = 0.66, b = 1.0 }, size = 16, intensity = 0.55 },
  portique = { color = { r = 1.0, g = 0.31, b = 0.85 }, size = 24, intensity = 0.7 },
}

--- Images d'une usine : image fixe (principale et ombre) ; lueur et lumière au travail seulement, en fondu ; fumée à la cheminée de l'atelier.
local function habiller_usine(e, w)
  local u = SPR_US.usines[w.sheet]
  assert(u, "robots : usine sans feuille " .. tostring(w.sheet))
  e.animation = { layers = { usine_couche(u.main, "main"), usine_couche(u.shadow, "shadow") } }
  local lum = USINE_LUMIERE[w.sheet]
  local vis = { { fadeout = true, effect = lum.effect, animation = usine_couche(u.glow, "glow"),
    light = { intensity = lum.intensity, size = lum.size, color = lum.color, shift = { 0, -w.size * 0.2 } } } }
  if w.sheet == "atelier" then
    -- Haut de la cheminée : x = -0,96, y = 1,42, z = 3,88 en unités du rendu (atelier.py), soit 3,75 tuiles au-dessus de l'origine à l'écran.
    vis[#vis + 1] = { fadeout = true, animation = {
      filename = "__base__/graphics/entity/smoke/smoke.png", width = 152, height = 120, line_length = 5, frame_count = 60,
      animation_speed = 0.25, scale = 0.55, shift = { -0.96 - 0.3, -3.75 - 0.45 }, priority = "high", flags = { "smoke" },
      tint = { r = 0.85, g = 0.85, b = 0.85, a = 0.55 },
    } }
  end
  e.working_visualisations = vis
  e.drawing_box = { { u.boite[1][1], u.boite[1][2] }, { u.boite[2][1], u.boite[2][2] } }
  e.map_color = { r = u.map_color[1], g = u.map_color[2], b = u.map_color[3] }
  e.friendly_map_color = e.map_color
  e.scale_entity_info_icon = true
  return u
end

local function usine_icones(w)
  local i = SPR_US.usines[w.sheet].icone
  return { { icon = i.filename, icon_size = i.icon_size, icon_mipmaps = i.icon_mipmaps } }
end

for i, w in ipairs(Ro.FACTORIES) do
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
  for _, key in ipairs(VISUAL_KEYS) do e[key] = nil end
  habiller_usine(e, w)
  lib.set_icons(e, usine_icones(w))
  out[#out + 1] = e
  out[#out + 1] = {
    type = "item", name = w.name,
    localised_name = { "entity-name." .. w.name }, localised_description = { "entity-description." .. w.name },
    icons = usine_icones(w), subgroup = Ro.SUBGROUP, order = string.format("a[factory]-%02d", i),
    place_result = w.name, stack_size = 10,
  }
  out[#out + 1] = {
    type = "recipe", name = w.name, enabled = false, energy_required = w.time,
    ingredients = ingredients(w.ingredients), results = { { type = "item", name = w.name, amount = 1 } },
    main_product = w.name,
  }
end

---------------------------------------------------------------------------------------------------
-- Robots : kit, recette, une unité par propriétaire (un géant : une araignée)
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
local function mul(c, k) return { r = math.min(1, c.r * k), g = math.min(1, c.g * k), b = math.min(1, c.b * k) } end

-- Teinte propre à chaque robot (visuel PROVISOIRE : le robot se reconnaît à sa couleur et à sa taille, pas encore à sa forme).
local ROBOT_TINT = {
  ["steam-trotter"] = { r = 0.80, g = 0.62, b = 0.40 }, ["scalehide"] = { r = 0.62, g = 0.36, b = 0.28 },
  ["coiler"] = { r = 0.45, g = 0.70, b = 0.95 }, ["needle"] = { r = 0.70, g = 0.50, b = 0.95 },
  ["bellwether"] = { r = 0.55, g = 0.95, b = 0.80 }, ["chamfer"] = { r = 0.75, g = 0.75, b = 0.45 },
  ["trowel"] = { r = 0.95, g = 0.85, b = 0.35 }, ["finback"] = { r = 0.90, g = 0.95, b = 1.00 },
  ["levite"] = { r = 0.55, g = 0.85, b = 0.95 }, ["toroid"] = { r = 0.95, g = 0.55, b = 0.85 },
  ["heliast"] = { r = 1.00, g = 0.80, b = 0.35 }, ["crowned"] = { r = 1.00, g = 0.95, b = 0.80 },
}
-- Taille de l'image par classe : petit, moyen, gros cracheur.
local CLASS_SCALE = { P = "scale_spitter_medium", M = "scale_spitter_big", G = "scale_spitter_behemoth" }
local CLASS_BASE = { P = "medium-spitter", M = "big-spitter", G = "behemoth-spitter" }

local smg = data.raw.gun["submachine-gun"]

-- Couleur de la peinture d'un propriétaire (couche « mask » des feuilles) : du laiton pour le joueur, sa couleur pour une faction.
local BRASS = { r = 0.86, g = 0.66, b = 0.27 }
local function paint(owner)
  if owner == Ro.PLAYER_OWNER then return BRASS end
  for _, f in ipairs(F.factions) do
    if f.key == owner then return { r = f.color.r, g = f.color.g, b = f.color.b } end
  end
  error("robots : propriétaire inconnu " .. tostring(owner))
end

--- Une couche d'une feuille : basse définition (16 px par tuile, scale 2), hr (64 px par tuile, scale 0,5). Mêmes cases, même origine.
--- `k` (facultatif, lot s43-robots) : échelle d'une variante qui reprend la feuille de son parent (image et décalage multipliés).
local function sheet_layer(c, anim, directions, k)
  k = k or 1
  local shift = c.shift and { c.shift[1] * k, c.shift[2] * k } or nil
  return {
    filename = c.lr, width = c.lw, height = c.lh, line_length = anim.line_length, frame_count = anim.frame_count, direction_count = directions,
    shift = shift, scale = 2 * k,
    hr_version = {
      filename = c.hr, width = c.w, height = c.h, line_length = anim.line_length, frame_count = anim.frame_count, direction_count = directions,
      shift = shift, scale = (c.hs or 0.5) * k,
    },
  }
end

local function both(l, key, v)
  l[key] = v
  l.hr_version[key] = v
end

--- Animation complète : ombre, corps, peinture du propriétaire, lueur. `look` (facultatif, variante du lot s43-robots) :
--- { scale, tint } : la feuille du parent mise à l'échelle, son corps teinté.
local function sheet_animation(sheet, anim_name, owner, look)
  local anim = sheet.anims[anim_name]
  local layers = {}
  local k = anim.couches
  local sc = look and look.scale or nil
  local sh = sheet_layer(k.shadow, anim, sheet.directions, sc)
  both(sh, "draw_as_shadow", true)
  layers[#layers + 1] = sh
  local body = sheet_layer(k.main, anim, sheet.directions, sc)
  if look and look.tint then both(body, "tint", rgba(look.tint)) end
  layers[#layers + 1] = body
  local m = sheet_layer(k.mask, anim, sheet.directions, sc)
  both(m, "tint", rgba(paint(owner)))
  layers[#layers + 1] = m
  if k.glow then
    local g = sheet_layer(k.glow, anim, sheet.directions, sc)
    both(g, "draw_as_glow", true)
    both(g, "blend_mode", "additive")
    layers[#layers + 1] = g
  end
  return { layers = layers }
end

--- Une pièce fixe d'une patte de géant (bout haut, milieu, bout bas, articulation).
local function piece_sprite(c, ombre)
  local l = {
    filename = ombre and c.lro or c.lr, width = c.lw, height = c.lh, shift = c.shift, scale = 2,
    hr_version = { filename = ombre and c.hro or c.hr, width = c.w, height = c.h, shift = c.shift, scale = 0.5 },
  }
  if ombre then both(l, "draw_as_shadow", true) end
  return l
end

--- Partie d'une patte : les bouts gardent leur taille, le milieu s'étire entre eux (SpiderLegPart).
local function leg_part(pt, ombre)
  return {
    top_end = piece_sprite(pt.parts.top, ombre), middle = piece_sprite(pt.parts.mid, ombre), bottom_end = piece_sprite(pt.parts.bot, ombre),
    top_end_length = pt.bout, bottom_end_length = pt.bout, middle_offset_from_top = pt.bout, middle_offset_from_bottom = pt.bout,
  }
end

--- Géant à feuille : torse à plusieurs directions remonté de `hauteur` (le rendu est en place au sol), peinture teinte à l'exécution (LuaEntity.color),
--- ombre au sol, positions de hanches et de pieds de la forme, une seule pièce de patte par partie.
local function giant_graphics(s, sheet, nm)
  local t = sheet.torse
  local function raised(c)
    local l = sheet_layer(c, t, sheet.directions)
    local sh = { c.shift[1], c.shift[2] + sheet.hauteur }
    both(l, "shift", sh)
    return l
  end
  local layers = { raised(t.couches.main) }
  local m = raised(t.couches.mask)
  both(m, "apply_runtime_tint", true)
  layers[#layers + 1] = m
  if t.couches.glow then
    local g = raised(t.couches.glow)
    both(g, "draw_as_glow", true)
    both(g, "blend_mode", "additive")
    layers[#layers + 1] = g
  end
  local shadow = sheet_layer(t.couches.shadow, t, sheet.directions)
  both(shadow, "draw_as_shadow", true)
  local g_set = s.graphics_set
  g_set.animation = { layers = layers }
  g_set.shadow_animation = shadow
  g_set.base_animation, g_set.shadow_base_animation, g_set.light_positions, g_set.eye_light, g_set.light = nil, nil, nil, nil, nil
  s.height = sheet.hauteur
  -- Moins de pattes que create_spidertron (Torique, 6) : les autres sont retirées, chacune bloque ses 2 voisines de cercle.
  local n = #sheet.jambes
  while #s.spider_engine.legs > n do table.remove(s.spider_engine.legs) end
  for k, leg in ipairs(s.spider_engine.legs) do
    if n < 8 then
      leg.blocking_legs = { (k % n) + 1, ((k + n - 2) % n) + 1 }
    end
    local j = sheet.jambes[k]
    leg.mount_position = { j.mx, j.my }
    leg.ground_position = { j.gx, j.gy }
    local proto = data.raw["spider-leg"][nm .. "-leg-" .. k]
    proto.part_length = sheet.part_length
    proto.graphics_set = {
      upper_part = leg_part(sheet.pattes.haut, false), lower_part = leg_part(sheet.pattes.bas, false),
      upper_part_shadow = leg_part(sheet.pattes.haut, true), lower_part_shadow = leg_part(sheet.pattes.bas, true),
      joint = piece_sprite(sheet.pattes.genou, false), joint_turn_offset = 0,
    }
  end
end

--- Une machine, pas un insecte : ni cadavre ni cri de cracheur (le copié en vient).
local function as_machine(u, sheet, class, look)
  local turret = assert(data.raw["ammo-turret"]["gun-turret"], "robots : gun-turret absente")
  u.corpse = class == "P" and "small-remnants" or "medium-remnants"
  u.dying_explosion = class == "G" and "big-explosion" or "explosion"
  u.damaged_trigger_effect = turret.damaged_trigger_effect
  u.dying_sound, u.working_sound, u.walking_sound, u.running_sound_animation_positions, u.water_reflection = nil, nil, nil, nil, nil
  u.alternative_attacking_frame_sequence = nil -- celle du cracheur vise ses 16 images (« Frame index 3 is out of range », 1/11)
  u.distance_per_frame = sheet.distance_per_frame * (look and look.scale or 1)
  lib.set_icons(u, { { icon = sheet.icone, icon_size = 64, icon_mipmaps = 4, tint = look and look.tint and rgba(look.tint) or nil } })
end

--- Effet d'un tir : dégâts du robot (par type), en zone si `area`. Un robot sans dégâts (soutien) n'a que l'effet visuel.
local function robot_ammo(r)
  local damage = { type = "damage", damage = { amount = r.shot.damage, type = r.dtype } }
  local hit = { type = "create-entity", entity_name = "explosion-hit" }
  local target_effects
  if r.shot.damage <= 0 then
    target_effects = { hit }
  elseif r.area then
    target_effects = {
      { type = "create-entity", entity_name = "big-explosion" },
      { type = "nested-result", action = {
        type = "area", radius = r.area, force = "enemy",
        action_delivery = { type = "instant", target_effects = { damage } },
      } },
    }
  else
    target_effects = { hit, damage }
  end
  return {
    category = Ro.AMMO_CATEGORY,
    action = {
      type = "direct",
      action_delivery = {
        type = "instant",
        source_effects = { type = "create-explosion", entity_name = "explosion-gunshot" },
        target_effects = target_effects,
      },
    },
  }
end

--- Une unité de robot pour un propriétaire.
local function make_unit(r, owner, i)
  local u = lib.copy("unit", CLASS_BASE[r.class])
  local tint = owner_tint(owner)
  local own = ROBOT_TINT[r.id] or r.look.tint
  local sheet = SPR[r.look and r.look.sheet or r.id] -- lot s43-robots : une variante reprend la feuille de son parent
  tint = { r = (tint.r + own.r) / 2, g = (tint.g + own.g) / 2, b = (tint.b + own.b) / 2 }
  local t1, t2 = rgba(tint), rgba(mul(tint, 0.7))
  local scale = _G[CLASS_SCALE[r.class]] * (r.class == "P" and 0.9 or 1)
  u.name = Ro.unit_name(owner, r.id)
  u.localised_name = { "fo-robots.unit-name", { "fo-robots.name-" .. r.id } }
  u.localised_description = { "fo-robots.desc-" .. r.id }
  u.order = string.format("z[fo-robot]-%s-%02d", owner, i)
  u.subgroup = Ro.SUBGROUP
  u.max_health = r.hp
  u.resistances = nil
  u.healing_per_tick = 0.02
  local hb = r.half
  u.collision_box = { { -hb, -hb }, { hb, hb } }
  u.selection_box = { { -hb - 0.1, -hb - 0.3 }, { hb + 0.1, hb + 0.3 } }
  u.movement_speed = r.speed
  u.vision_distance = math.min(45, math.max(30, r.range)) -- jamais au-delà de 45 (PLAN §3 : comportement non documenté)
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
    min_range = r.min_range,
    cooldown = r.shot.cooldown,
    cooldown_deviation = 0.1,
    projectile_creation_distance = 0.6,
    range_mode = "bounding-box-to-bounding-box",
    ammo_type = robot_ammo(r),
    animation = sheet and sheet_animation(sheet, "tir", owner, r.look) or spitterattackanimation(scale, t1, t2),
    sound = smg.attack_parameters.sound,
  }
  u.run_animation = sheet and sheet_animation(sheet, "run", owner, r.look) or spitterrunanimation(scale, t1, t2)
  u.ai_settings = { destroy_when_commands_fail = false, allow_try_return_to_spawner = false, do_separation = true }
  if sheet then
    as_machine(u, sheet, r.class, r.look)
  else
    lib.set_icons(u, icons_of("unit", CLASS_BASE[r.class], tint))
  end
  return u
end

--- Un géant : araignée du jeu de base à l'échelle voulue, un canon de portée 100 et sa munition (posée par script).
local function make_giant(r, i)
  local g = r.giant
  local nm = Ro.unit_name(Ro.PLAYER_OWNER, r.id)
  local gun_name, shell_name = Ro.gun_name(r.id), Ro.shell_name(r.id)
  -- Munition : un chargeur de 1 000 coups, caché ; le script en garde toujours 2 à 4 dans le magasin.
  local effect = robot_ammo(r)
  out[#out + 1] = {
    type = "ammo", name = shell_name,
    localised_name = { "item-name." .. shell_name }, localised_description = { "item-description." .. shell_name },
    icons = icons_of("ammo", "explosive-rocket", ROBOT_TINT[r.id]), flags = { "hidden" }, subgroup = Ro.SUBGROUP,
    order = string.format("c[shell]-%02d", i), stack_size = 10, magazine_size = 1000,
    ammo_type = {
      category = Ro.SHELL_CATEGORY,
      action = effect.action,
    },
  }
  local rocket = data.raw.gun["spidertron-rocket-launcher-1"]
  out[#out + 1] = {
    type = "gun", name = gun_name,
    localised_name = { "item-name." .. gun_name },
    icons = icons_of("gun", "spidertron-rocket-launcher-1", ROBOT_TINT[r.id]), flags = { "hidden" }, subgroup = "gun",
    order = string.format("z[fo-robot-gun]-%02d", i), stack_size = 1,
    attack_parameters = {
      type = "projectile", ammo_category = Ro.SHELL_CATEGORY, cooldown = r.shot.cooldown, range = r.range,
      projectile_creation_distance = 0, sound = rocket.attack_parameters.sound,
    },
  }
  return nm, gun_name, g
end

--- Icône d'un kit sans icône dédiée : l'icône de la feuille (celle du parent pour une variante, teinte), sinon un objet teinté.
local function kit_icons(r)
  local sheet = SPR[r.look and r.look.sheet or r.id]
  if sheet then
    return { { icon = sheet.icone, icon_size = 64, icon_mipmaps = 4, tint = r.look and r.look.tint and rgba(r.look.tint) or nil } }
  end
  return icons_of("item", r.is_giant and "spidertron" or "engine-unit", ROBOT_TINT[r.id])
end

local STUB = {} -- araignées à créer après data:extend (create_spidertron écrit dans data.raw)

for i, r in ipairs(Ro.ROBOTS) do
  local ings = ingredients(r.ingredients)
  local place = Ro.unit_name(Ro.PLAYER_OWNER, r.id)
  out[#out + 1] = {
    type = "item", name = r.kit,
    localised_name = { "item-name." .. r.kit }, localised_description = { "item-description." .. r.kit },
    -- choix du DC (4/11, QCM : « Caisse de famille ») : l'icône de kit de DA-ICONES (caisse de famille + signature) d'abord ;
    -- l'icône du robot (lot RB-V1) en repli (tests/robotique_icones_test.lua refuse l'ordre inverse)
    icons = Vis.icones_objet(r.kit) or kit_icons(r),
    subgroup = Ro.SUBGROUP, order = string.format("b[kit]-%02d", i), stack_size = 1,
    -- Lot RB-3 : le kit « pose » l'unité du joueur (prototype `unit` ou `spider-vehicle`) : le cerveau lit ce lien dans les
    -- prototypes (items_to_place_this), sans nom ; un kit posé à la main est inscrit au registre par script/robots/usine.lua.
    place_result = place,
  }
  out[#out + 1] = {
    type = "recipe", name = r.recipe, category = Ro.factory(r.factory).category, enabled = false, energy_required = r.time,
    ingredients = ings, results = { { type = "item", name = r.kit, amount = 1 } }, main_product = r.kit,
    localised_name = { "item-name." .. r.kit },
  }
  if r.segment then
    -- Segment d'un géant : fabriqué au dock (catégorie du dock), consommé 10 par assemblage final au portique.
    out[#out + 1] = {
      type = "item", name = r.segment_item,
      localised_name = { "item-name." .. r.segment_item }, localised_description = { "item-description." .. r.segment_item },
      icons = Vis.icones_objet(r.segment_item) or icons_of("item", "low-density-structure", ROBOT_TINT[r.id]), subgroup = Ro.SUBGROUP,
      order = string.format("b[segment]-%02d", i), stack_size = 10,
    }
    out[#out + 1] = {
      type = "recipe", name = r.segment_recipe, category = "fo-robots-3", enabled = false, energy_required = r.segment.time,
      ingredients = ingredients(r.segment.ingredients), results = { { type = "item", name = r.segment_item, amount = 1 } },
      main_product = r.segment_item, localised_name = { "item-name." .. r.segment_item },
    }
  end
  if r.is_giant then
    STUB[#STUB + 1] = { r = r, i = i, nm = make_giant(r, i) }
  else
    for _, owner in ipairs(Ro.OWNERS) do out[#out + 1] = make_unit(r, owner, i) end
  end
end

---------------------------------------------------------------------------------------------------
-- Technologies
---------------------------------------------------------------------------------------------------
-- Lot s43-robots : la technologie d'une variante (un seul robot, r.variant) prend l'icône dédiée de celle de son parent, teinte.
local function variant_of_tech(t)
  local r = t.robots and #t.robots == 1 and not t.factories and Ro.robot(t.robots[1]) or nil
  return r and r.variant and r or nil
end
local function icon_tech(t)
  local r = variant_of_tech(t)
  if not r then return t.name end
  for _, u in ipairs(Ro.TECHS) do
    for _, id in ipairs(u.robots or {}) do if id == r.variant then return u.name end end
  end
  return t.name
end
local function icon_tint(t)
  local r = variant_of_tech(t)
  return r and r.look.tint or nil
end
local function tinted(icons, tint)
  if not icons or not tint then return icons end
  local out = {}
  for i, ic in ipairs(icons) do
    out[i] = { icon = ic.icon, icon_size = ic.icon_size, icon_mipmaps = ic.icon_mipmaps, tint = rgba(tint) }
  end
  return out
end

for _, t in ipairs(Ro.TECHS) do
  local effects = {}
  for _, rn in ipairs(Ro.tech_unlocks(t)) do effects[#effects + 1] = lib.unlock(rn) end
  out[#out + 1] = lib.technology({
    name = t.name,
    localised_name = { "technology-name." .. t.name },
    localised_description = { "technology-description." .. t.name },
    icons = tinted(Vis.icones_tech(icon_tech(t)), icon_tint(t)) or icons_of("technology", "engine", KIT_TINT),
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

---------------------------------------------------------------------------------------------------
-- Géants : araignées du jeu de base (create_spidertron écrit dans data.raw : après data:extend, les canons existent)
---------------------------------------------------------------------------------------------------
for _, g in ipairs(STUB) do
  local r, i = g.r, g.i
  local nm = Ro.unit_name(Ro.PLAYER_OWNER, r.id)
  local cfg = r.giant
  create_spidertron({ name = nm, scale = cfg.scale, leg_scale = cfg.leg_scale, leg_thickness = 1, leg_movement_speed = cfg.leg_speed })
  local s = data.raw["spider-vehicle"][nm]
  s.localised_name = { "fo-robots.unit-name", { "fo-robots.name-" .. r.id } }
  s.localised_description = { "fo-robots.desc-" .. r.id }
  s.order = string.format("z[fo-robot]-giant-%02d", i)
  s.subgroup = Ro.SUBGROUP
  s.minable = { mining_time = 1, result = r.kit }
  s.max_health = r.hp -- règle d'échelle (shared/content/robots.lua : Ech.pv de l'âge)
  s.resistances = table.deepcopy(r.resistances) -- E1 : résistances d'écart d'âge (Ech.resistances)
  s.equipment_grid = nil
  s.inventory_size = 4
  s.trash_inventory_size = 0
  s.guns = { Ro.gun_name(r.id) }
  s.chain_shooting_cooldown_modifier = 1 -- l'araignée du jeu de base tire 2 fois plus vite en rafale (0,5) : RB-5 a mesuré des duels deux fois trop courts
  s.icons = SPR[r.id] and { { icon = SPR[r.id].icone, icon_size = 64, icon_mipmaps = 4 } } or icons_of("item", "spidertron", ROBOT_TINT[r.id])
  s.icon, s.icon_size, s.icon_mipmaps = nil, nil, nil
  if SPR[r.id] then giant_graphics(s, SPR[r.id], nm) end
  for k = 1, 8 do
    local leg = data.raw["spider-leg"][nm .. "-leg-" .. k]
    if leg then leg.localised_name = { "fo-robots.unit-name", { "fo-robots.name-" .. r.id } } end
  end
end
