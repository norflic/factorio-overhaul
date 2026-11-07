-- Lot DESIGN-ATTAQUES (5/11, nuit) : prototypes de la 2e attaque des géants (shared/robots/attaques2.lua). ZÉRO image neuve : des fichiers
-- de vanilla (cœur, base) et des feuilles du Bourdon déjà dans l'atlas. Aucun prototype ne fait de dégâts : tout passe par le script
-- (script/robots/attaques2.lua), qui ne touche que les forces ennemies.
-- Couleurs (F36 : une teinte MULTIPLIE) : le bleu et le cyan viennent de la lumière ronde de vanilla (grise, neutre, mesurée) ; l'or, l'orange
-- et le blanc chaud de l'étoile du Bourdon, à sa couleur d'origine (halo mesuré 1,00 / 0,86 / 0,56). Critique du 5/11 : l'étoile teintée
-- en bleu sortait vert-de-gris.
local A = require("shared.robots.attaques2")
local BSPR = require("__factorio-overhaul__/graphics/robots/bourdon/sprites")
local smoke = require("__base__/prototypes/entity/smoke-animations")

local P = A.PREFIX
local out = {}

-- 1. Halo : la lumière ronde de vanilla en sprite additif (aussi dans la carte des lumières) : une couleur PURE à la teinte du script.
for _, h in ipairs({ { "halo", "__core__/graphics/light-medium.png", 300 }, { "halo-petit", "__core__/graphics/light-small.png", 150 } }) do
  out[#out + 1] = { type = "sprite", name = P .. h[1], filename = h[2], width = h[3], height = h[3], scale = 1, blend_mode = "additive",
    draw_as_glow = true, flags = { "group=none" } }
end

-- 2. Éclats (explosions d'une image qui grandit puis s'éteint).
local function eclat(nom, fichier, l, h, echelle, tint, duree, lumiere)
  local function une(f, w, ht, s)
    return { filename = f, width = w, height = ht, scale = s, frame_count = 1, line_length = 1, animation_speed = 1 / duree,
      blend_mode = "additive", draw_as_glow = true, tint = tint }
  end
  local a
  if fichier == "etoile" then
    local f = BSPR.flash
    a = une(f.lr.filename, f.lr.width, f.lr.height, f.lr.scale * echelle)
    a.hr_version = une(f.hr.filename, f.hr.width, f.hr.height, f.hr.scale * echelle)
  else
    a = une(fichier, l, h, echelle)
  end
  out[#out + 1] = {
    type = "explosion", name = P .. nom, flags = { "not-on-map", "hidden" }, subgroup = "explosions",
    localised_name = { "entity-name." .. P .. "eclat" },
    animations = { a }, scale_initial = 0.3, scale_end = 1.0, scale_in_duration = 3, fade_out_duration = math.floor(duree * 0.75),
    light = lumiere and { intensity = 0.9, size = lumiere, color = tint } or nil,
  }
end
local HALO = "__core__/graphics/light-medium.png"
eclat("eclat-bleu", HALO, 300, 300, 0.9, { r = 0.35, g = 0.65, b = 1.0, a = 1 }, 20, 14)
eclat("eclat-bleu-grand", HALO, 300, 300, 2.0, { r = 0.32, g = 0.55, b = 0.8, a = 1 }, 36, 30)
-- éclat du climax du Cairn sur 5 poteaux sur 6 (additif : une teinte sombre = un éclat faible ; captures du 7/11, nappe blanche)
eclat("eclat-bleu-sombre", HALO, 300, 300, 1.0, { r = 0.14, g = 0.26, b = 0.45, a = 1 }, 24, 8)
eclat("eclat-glace", HALO, 300, 300, 1.2, { r = 0.7, g = 0.92, b = 1.0, a = 1 }, 24, 12)
eclat("eclat-or", "etoile", nil, nil, 0.5, { r = 1, g = 1, b = 1, a = 1 }, 40, 30)
eclat("eclat-feu", "etoile", nil, nil, 0.35, { r = 1.0, g = 0.7, b = 0.45, a = 1 }, 26, 16)
eclat("eclat-blanc", "etoile", nil, nil, 0.9, { r = 1, g = 1, b = 1, a = 1 }, 60, 60)

-- 3. La foudre du Cairn : l'arc électrique de vanilla, sans action (bleu-blanc d'origine, non teinté).
do
  local b = table.deepcopy(data.raw.beam["electric-beam-no-sound"])
  b.name = P .. "foudre"
  b.localised_name = { "entity-name." .. P .. "rayon" }
  b.action = nil
  b.damage_interval = 1000
  out[#out + 1] = b
end

-- 4. Bombes de lave d'Ixion : le jet du lance-flammes de vanilla (orange d'origine), sans action, trois fois plus rapide.
do
  local s = table.deepcopy(data.raw.stream["flamethrower-fire-stream"])
  s.name = P .. "bombe"
  s.localised_name = { "entity-name." .. P .. "rayon" }
  s.action = nil
  s.particle_horizontal_speed = s.particle_horizontal_speed * 3
  s.particle_vertical_acceleration = s.particle_vertical_acceleration * 2
  s.particle_start_scale = 0.6
  out[#out + 1] = s
end

-- 5. Fumées : nuage d'orage (Cairn), poussière de tornade et suie (Trombe), vapeur (Ixion).
local function fumee(nom, couleur, duree, debut, fin, vent, echelle)
  out[#out + 1] = {
    type = "trivial-smoke", name = P .. nom,
    animation = smoke.trivial_smoke_fast({ animation_speed = 1 / 6, scale = echelle }),
    duration = duree, fade_in_duration = 10, fade_away_duration = math.floor(duree * 0.5),
    start_scale = debut, end_scale = fin, spread_duration = duree, affected_by_wind = vent,
    movement_slow_down_factor = 0.96, render_layer = "smoke", show_when_smoke_off = true, color = couleur,
  }
end
fumee("nuage", { r = 0.14, g = 0.15, b = 0.22, a = 0.85 }, 260, 1.6, 4.5, true, 2.4)
fumee("tornade", { r = 0.36, g = 0.29, b = 0.21, a = 0.8 }, 50, 0.8, 2.6, false, 1.4)
fumee("vapeur", { r = 0.35, g = 0.3, b = 0.28, a = 0.7 }, 360, 0.8, 3.5, true, 1.6)

-- 6. Brasier : le feu de vanilla, SANS dégâts ni propagation (comme les flammes du Bourdon), qui dure 60 s.
do
  local f = table.deepcopy(data.raw.fire["fire-flame"])
  f.name = P .. "brasier"
  f.localised_name = { "entity-name." .. P .. "brasier" }
  f.damage_per_tick = { amount = 0, type = "fire" }
  f.spawn_entity = nil
  f.maximum_spread_count = 0
  f.spread_delay = 1000000
  f.initial_lifetime = 3600
  f.maximum_lifetime = 3600
  f.lifetime_increase_by = 0
  f.on_damage_tick_effect = nil
  f.flags = { "not-on-map", "placeable-off-grid" }
  out[#out + 1] = f
  local g = table.deepcopy(f)
  g.name = P .. "brasier-court"
  g.initial_lifetime = 600 -- le sol brûle 10 s sous le rayon du Stylet (Ech.BALAYAGE_FEU_TICKS)
  g.maximum_lifetime = 600
  out[#out + 1] = g
end

-- 7. Sols. Lave (Ixion) : le sol de cratère de vanilla, rouge sombre (une croûte, couverte de fissures chaudes par le script) ; verre chaud
--    (Tournesol) : le sable vanilla, rouge orangé ; tous deux INFRANCHISSABLES et INCONSTRUCTIBLES (masque « object-layer », sans
--    « water-tile » : ni remblai ni pompe) ; le minerai reste dessous (pas de « resource-layer »). Ils refroidissent : la lave en sol de
--    cratère vanilla, le verre chaud en verre doré, constructible, qui reste (une trace sur la carte).
local DUR = { "object-layer", "player-layer", "item-layer", "doodad-layer" }
local function sol(nom, base, tint, carte, dur)
  local t = table.deepcopy(data.raw.tile[base])
  t.name = P .. nom
  t.localised_name = { "tile-name." .. P .. nom }
  t.order = "z[fo-att2]-" .. nom
  t.autoplace = nil
  t.tint = tint
  t.map_color = carte
  t.minable = nil
  t.placeable_by = nil
  t.pollution_absorption_per_second = 0
  if dur then t.collision_mask = table.deepcopy(DUR) end
  out[#out + 1] = t
end
sol("lave", "nuclear-ground", { r = 1.0, g = 0.5, b = 0.35, a = 1 }, { r = 200, g = 60, b = 20 }, true)
sol("verre-chaud", "sand-1", { r = 1.0, g = 0.5, b = 0.28, a = 1 }, { r = 230, g = 110, b = 30 }, true)
sol("verre", "sand-1", { r = 1.0, g = 0.9, b = 0.6, a = 1 }, { r = 235, g = 190, b = 90 }, false)

-- 8. Sons (vanilla), un par géant.
local function son(nom, fichier, volume)
  out[#out + 1] = { type = "sound", name = P .. nom, filename = fichier, volume = volume, audible_distance_modifier = 3 }
end
son("cairn", "__base__/sound/fight/electric-beam.ogg", 0.9)
son("cairn-fin", "__base__/sound/fight/large-explosion-1.ogg", 1.0)
son("stylet", "__base__/sound/fight/large-explosion-2.ogg", 0.9)
son("trombe", "__base__/sound/wind/wind.ogg", 1.0)
son("ixion", "__base__/sound/fight/flamethrower-start.ogg", 1.0)
son("ixion-fin", "__base__/sound/fight/large-explosion-1.ogg", 1.0)
son("tournesol", "__base__/sound/fight/laser-beam.ogg", 0.9)
son("tournesol-fin", "__base__/sound/fight/nuclear-explosion-3.ogg", 0.8)

-- 9. La touche du joueur : vos géants à portée lancent leur grande attaque vers le curseur.
out[#out + 1] = { type = "custom-input", name = P .. "grande", key_sequence = "CONTROL + SHIFT + H", consuming = "none", order = "c[fo-att2]-a" }

data:extend(out)
