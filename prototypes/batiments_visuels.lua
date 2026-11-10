-- Lot POLISSAGE-FX (10/11) : vrais visuels de trois bâtiments génériques (copies vanilla teintées jusqu'ici), rendus par le kit
-- tools/render/pieces/batiments dans la direction artistique des titans (argent iridescent, conduits et cœurs cyan, accents magenta) :
--   coffre d'équipe (fo-team-chest, container 1×1, prototypes/faction.lua) ;
--   pylône haute tension (fo-ht-pylon, electric-pole 2×2, prototypes/bauxite.lua) : UNE direction (symétrie carrée), points d'attache
--     des fils lus dans la feuille (ancrages calculés depuis le modèle 3D : fil et ombre) ;
--   cuve d'électrolyse ignée (fo-reduction-cell, assembling-machine 4×4, prototypes/bauxite.lua) : image fixe, lueur du bain au travail.
-- Feuilles : graphics/batiments/ (PNG hors de git, D-6 : tools/render/pieces/batiments/feuilles.py), décrites par le sprites.lua généré.
--   lot POLISSAGE-2 (10/11) : cinq tourelles électriques (Bastion II à IV, tour à arc, tourelle laser lourde), section en fin de fichier.
--   lot POLISSAGE-3 (10/11) : quatre tourelles à munitions (Bastion I, tourelle lourde, canon, mortier), tête tournante à 64 directions,
--     section en fin de fichier.
-- Chargé à la fin de prototypes/faction.lua (après le coffre, les bâtiments de la bauxite et tout l'arsenal de data.lua). Emprises, boîtes, recettes et statistiques
-- INCHANGÉES : seules les images changent. Un bâtiment absent de sprites.lua garde son visuel provisoire.

local lib = require("prototypes.lib")
local SPR = require("__factorio-overhaul__/graphics/batiments/sprites")

--- Couche d'une feuille : normale (32 px/tuile) + hr_version (64 px/tuile, scale 0,5). kind : main, shadow, glow.
local function couche(def, kind)
  local function une(r, hr)
    local t = { filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] }, priority = "high" }
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

local function boite(u) return { { u.boite[1][1], u.boite[1][2] }, { u.boite[2][1], u.boite[2][2] } } end
local function icones(u) return { { icon = u.icone.filename, icon_size = u.icone.icon_size, icon_mipmaps = u.icone.icon_mipmaps } } end

local function habiller(e, u)
  e.map_color = { r = u.map_color[1], g = u.map_color[2], b = u.map_color[3] }
  e.friendly_map_color = e.map_color
  e.drawing_box = boite(u)
  e.water_reflection = nil
  lib.set_icons(e, icones(u))
  local it = data.raw.item[e.name]
  if it then lib.set_icons(it, icones(u)) end
end

local function calques(u)
  local L = { couche(u.main, "main"), couche(u.shadow, "shadow") }
  if u.glow then L[#L + 1] = couche(u.glow, "glow") end
  return L
end

local habilles = 0

---------------------------------------------------------------------------------------------------
-- Coffre d'équipe (container 1×1) : image fixe, cœur-serrure et runes en lueur
---------------------------------------------------------------------------------------------------
do
  local u, e = SPR.coffre, data.raw.container["fo-team-chest"]
  if u and e then
    e.picture = { layers = calques(u) }
    habiller(e, u)
    habilles = habilles + 1
  end
end

---------------------------------------------------------------------------------------------------
-- Pylône haute tension (electric-pole 2×2) : une direction, ancrages des fils lus dans la feuille
---------------------------------------------------------------------------------------------------
do
  local u, e = SPR.pylone, data.raw["electric-pole"]["fo-ht-pylon"]
  if u and e and u.ancrages then
    local L = calques(u)
    for _, l in ipairs(L) do
      l.direction_count = 1
      l.hr_version.direction_count = 1
    end
    e.pictures = { layers = L }
    local a = u.ancrages
    local function pt(v) return { v[1], v[2] } end
    e.connection_points = { {
      wire = { copper = pt(a.copper.fil), red = pt(a.red.fil), green = pt(a.green.fil) },
      shadow = { copper = pt(a.copper.ombre), red = pt(a.red.ombre), green = pt(a.green.ombre) },
    } }
    habiller(e, u)
    habilles = habilles + 1
  end
end

---------------------------------------------------------------------------------------------------
-- Cuve d'électrolyse ignée (assembling-machine 4×4) : image fixe, lueur du bain et des conduits au travail
---------------------------------------------------------------------------------------------------
do
  local u, e = SPR.cuve, data.raw["assembling-machine"]["fo-reduction-cell"]
  if u and e then
    e.animation = { layers = { couche(u.main, "main"), couche(u.shadow, "shadow") } }
    e.idle_animation = nil
    e.working_visualisations = u.glow and { { fadeout = true, animation = couche(u.glow, "glow"),
      light = { intensity = 0.5, size = 8, color = { r = u.map_color[1], g = u.map_color[2], b = u.map_color[3] } } } } or nil
    e.shadow, e.integration_patch = nil, nil
    habiller(e, u)
    habilles = habilles + 1
  end
end

---------------------------------------------------------------------------------------------------
-- Lot POLISSAGE-2 (10/11) : tourelles électriques encore copiées de vanilla et teintées (lignée Bastion II à IV, tour à arc,
-- tourelle laser lourde), refaites en ÉMETTEURS À SYMÉTRIE DE RÉVOLUTION : le corps entier est le socle (image fixe), la tête n'est
-- que la lueur pulsée (bande de PULSE images, direction_count 1 : la tête ne tourne pas à l'écran, mécanisme de la tour à arc de
-- prototypes/arsenal_special.lua, éprouvé en moteur). Intensité par état lue ici (tint d'une lueur additive). Le faisceau part de
-- l'ANCRAGE « emetteur » calculé depuis le modèle 3D (source_direction_count 1) ; les tirs à projectile gardent leur origine.
-- Emprise, boîtes, portée, dégâts, énergie, recettes : INCHANGÉS. Icône : la nouvelle, plus les chiffres d'âge de l'ancienne.
---------------------------------------------------------------------------------------------------
local TOURELLES = {
  { cle = "bastion2", name = "fo-bastion-2" },
  { cle = "bastion3", name = "fo-bastion-3" },
  { cle = "bastion4", name = "fo-bastion-4" },
  { cle = "tesla", name = "fo-tesla-turret" },
  { cle = "laser_lourd", name = "fo-heavy-laser-turret" },
}
-- états de la tête : intensité de la lueur (tint), images jouées (1 = première image de la bande), vitesse
local ETATS = {
  folded_animation = { k = 0.35, images = 1 },
  preparing_animation = { k = 0.6, images = 0, vitesse = 0.25 },
  folding_animation = { k = 0.6, images = 0, vitesse = 0.25 },
  prepared_animation = { k = 0.85, images = 0, vitesse = 0.2 },
  attacking_animation = { k = 1.0, images = 0, vitesse = 0.5 },
}
local ORDRE_ETATS = { "folded_animation", "preparing_animation", "folding_animation", "prepared_animation", "attacking_animation" }

--- Couche de lueur pulsée : bande u.pulse (normale + hr), direction_count 1 ; light = couche de lumière (halo de nuit, plus large).
local function pulse(u, etat, light)
  local function une(r, hr)
    local n = etat.images > 0 and etat.images or r.frame_count
    local k = light and etat.k * 0.5 or etat.k
    local t = { filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] }, priority = "high",
      frame_count = n, line_length = r.line_length, direction_count = 1, animation_speed = etat.vitesse or 1,
      blend_mode = "additive", tint = { r = k, g = k, b = k, a = 1 } }
    if light then t.draw_as_light = true else t.draw_as_glow = true end
    t.scale = (hr and 0.5 or 1) * (light and 1.6 or 1)
    return t
  end
  local s = une(u.pulse.lr, false)
  s.hr_version = une(u.pulse.hr, true)
  return s
end

local function vecteur(v) return { v[1], v[2] } end

for _, t in ipairs(TOURELLES) do
  local u, e = SPR[t.cle], data.raw["electric-turret"][t.name]
  if u and e and u.pulse and u.ancrages and u.ancrages.emetteur then
    e.base_picture = { layers = { couche(u.main, "main"), couche(u.shadow, "shadow") } }
    for _, f in ipairs(ORDRE_ETATS) do
      e[f] = { layers = { pulse(u, ETATS[f], false), pulse(u, ETATS[f], true) } }
    end
    e.energy_glow_animation = nil
    e.water_reflection = nil
    e.drawing_box = boite(u)
    local ap = e.attack_parameters
    if ap and ap.type == "beam" then
      local em = vecteur(u.ancrages.emetteur.fil)
      ap.source_direction_count = 1
      ap.source_offset = em
      local d = ap.ammo_type and ap.ammo_type.action and ap.ammo_type.action.action_delivery
      if d and d.type == "beam" then d.source_offset = vecteur(em) end
    end
    -- icône : la nouvelle en premier calque, les chiffres d'âge (calques suivants) gardés
    local function icones_tourelle(p)
      local old = p.icons or {}
      local ic = icones(u)
      for i = 2, #old do ic[#ic + 1] = old[i] end
      lib.set_icons(p, ic)
    end
    icones_tourelle(e)
    if data.raw.item[t.name] then icones_tourelle(data.raw.item[t.name]) end
    habilles = habilles + 1
  end
end

---------------------------------------------------------------------------------------------------
-- Lot POLISSAGE-3 (10/11) : tourelles à MUNITIONS encore copiées de vanilla et teintées (Bastion I, tourelle lourde, canon, mortier),
-- refaites : SOCLE fixe (corps, ombre, lueur des conduits) et TÊTE TOURNANTE à 64 directions lue dans des BANDES (« stripes » de
-- u.rangs directions × u.images colonnes, une ligne par direction, comme la mitrailleuse vanilla) : les états au repos (replié,
-- déploiement, prêt, repli) lisent la PREMIÈRE colonne (width_in_frames = 1), le tir toutes les images (u.images : 2 pour le Bastion I
-- et la tourelle lourde, recul et éclair ; 1 pour le canon et le mortier, comme aujourd'hui). Couches de tête : corps, ombre, lueur
-- (intensité par état, même échelle que POLISSAGE-2) et lumière de nuit. Origine des projectiles LUE DU MODÈLE 3D (u.bouche :
-- tools/render/pieces/batiments/tourelle_tete.py) : projectile_creation_distance et projectile_center. Emprise, boîtes, santé, portée,
-- dégâts, munitions, rotation, vitesses de déploiement, douilles : INCHANGÉS.
---------------------------------------------------------------------------------------------------
local TOURELLES_MUNITIONS = {
  { cle = "bastion1", name = "fo-bastion-1" },
  { cle = "lourde", name = "fo-heavy-gun-turret" },
  { cle = "canon", name = "fo-cannon-turret" },
  { cle = "mortier", name = "fo-mortar-turret" },
}
-- états de la tête : intensité de la lueur ; tir = toutes les images de la bande
local ETATS_TETE = {
  { champ = "folded_animation", k = 0.35 },
  { champ = "preparing_animation", k = 0.6 },
  { champ = "folding_animation", k = 0.6 },
  { champ = "prepared_animation", k = 0.85 },
  { champ = "attacking_animation", k = 1.0, tir = true },
}

--- Couche de tête (RotatedAnimation à bandes), n images jouées ; kind : main, shadow, glow, light (la lueur dessinée en lumière).
local function couche_tete(u, kind, etat, n)
  local src = u.tete[kind == "light" and "glow" or kind]
  local function une(r, hr)
    local bandes = {}
    for i, f in ipairs(r.stripes) do bandes[i] = { filename = f, width_in_frames = n, height_in_frames = u.rangs } end
    local t = { stripes = bandes, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] }, priority = "high",
      direction_count = u.directions, frame_count = n }
    if kind == "shadow" then
      t.draw_as_shadow = true
    elseif kind == "main" then
      t.flags = { "linear-minification" }
    else
      local k = kind == "light" and etat.k * 0.5 or etat.k
      t.blend_mode = "additive"
      t.tint = { r = k, g = k, b = k, a = 1 }
      if kind == "light" then t.draw_as_light = true else t.draw_as_glow = true end
    end
    if hr then t.scale = 0.5 end
    return t
  end
  local s = une(src.lr, false)
  s.hr_version = une(src.hr, true)
  return s
end

--- Icônes : la nouvelle en premier calque, les calques suivants d'aujourd'hui (chiffre d'âge, pastille de rôle) gardés.
local function icones_munitions(p, u)
  local ancien = p.icons or {}
  local ic = icones(u)
  for j = 2, #ancien do ic[#ic + 1] = ancien[j] end
  lib.set_icons(p, ic)
end

for _, t in ipairs(TOURELLES_MUNITIONS) do
  local u, e = SPR[t.cle], data.raw["ammo-turret"][t.name]
  if u and e and u.tete and u.bouche then
    local socle = { couche(u.main, "main"), couche(u.shadow, "shadow") }
    if u.glow then socle[#socle + 1] = couche(u.glow, "glow") end
    e.base_picture = { layers = socle }
    for _, etat in ipairs(ETATS_TETE) do
      local n = etat.tir and u.images or 1
      e[etat.champ] = { layers = { couche_tete(u, "main", etat, n), couche_tete(u, "shadow", etat, n), couche_tete(u, "glow", etat, n),
        couche_tete(u, "light", etat, n) } }
    end
    e.water_reflection = nil
    e.drawing_box = boite(u)
    local ap = e.attack_parameters
    ap.projectile_creation_distance = u.bouche.distance
    ap.projectile_center = { u.bouche.centre[1], u.bouche.centre[2] }
    icones_munitions(e, u)
    if data.raw.item[t.name] then icones_munitions(data.raw.item[t.name], u) end
    habilles = habilles + 1
  end
end

log("[FO-BATIMENTS] " .. habilles .. " bâtiment(s) habillé(s) par les feuilles de graphics/batiments")
