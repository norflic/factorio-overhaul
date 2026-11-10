-- Lot POLISSAGE-FX (10/11) : vrais visuels de trois bâtiments génériques (copies vanilla teintées jusqu'ici), rendus par le kit
-- tools/render/pieces/batiments dans la direction artistique des titans (argent iridescent, conduits et cœurs cyan, accents magenta) :
--   coffre d'équipe (fo-team-chest, container 1×1, prototypes/faction.lua) ;
--   pylône haute tension (fo-ht-pylon, electric-pole 2×2, prototypes/bauxite.lua) : UNE direction (symétrie carrée), points d'attache
--     des fils lus dans la feuille (ancrages calculés depuis le modèle 3D : fil et ombre) ;
--   cuve d'électrolyse ignée (fo-reduction-cell, assembling-machine 4×4, prototypes/bauxite.lua) : image fixe, lueur du bain au travail.
-- Feuilles : graphics/batiments/ (PNG hors de git, D-6 : tools/render/pieces/batiments/feuilles.py), décrites par le sprites.lua généré.
-- Chargé à la fin de prototypes/faction.lua (après le coffre et les bâtiments de la bauxite). Emprises, boîtes, recettes et statistiques
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

log("[FO-BATIMENTS] " .. habilles .. " bâtiment(s) habillé(s) par les feuilles de graphics/batiments")
