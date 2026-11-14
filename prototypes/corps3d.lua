--[[
  s43 : CORPS 3D des familles de déchiqueteurs (champ `corps3d` de shared/content/enemies.lua) : animations de course et d'attaque
  lues dans graphics/robots/titans/sprites.lua (feuilles_titans.py, PNG hors de git, D-6), au format des Écorchés : 8 directions,
  `filenames` + `lines_per_file`, couches corps (teinté par la variante), lueur (rendue blanche, teinte et alpha de la variante,
  additive) et ombre. Le modèle est en tuiles à l'échelle 1 : l'échelle de jeu `k` est celle de l'unité (palier × taille de la famille).
]]

local SPR = require("__factorio-overhaul__/graphics/robots/titans/sprites")

local M = {}

M.ATTAQUE_VITESSE = 0.3

local function couche(A, c, a, k, extra)
  local d = c.dens or a.densite
  local layer = {
    filenames = c.lr, lines_per_file = c.lpf, line_length = c.ll, slice = c.ll, width = c.lw, height = c.lh, frame_count = a.images,
    direction_count = A.directions, shift = { c.sx * k, c.sy * k }, scale = k * 32 / (d / A.reduc),
    hr_version = {
      filenames = c.hr, lines_per_file = c.lpf, line_length = c.ll, slice = c.ll, width = c.w, height = c.h, frame_count = a.images,
      direction_count = A.directions, shift = { c.sx * k, c.sy * k }, scale = k * 32 / d,
    },
  }
  for key, v in pairs(extra or {}) do
    layer[key] = v
    layer.hr_version[key] = v
  end
  return layer
end

--- Feuilles du corps `id` (nil si absentes).
function M.feuilles(id)
  return SPR[id]
end

--- Animation `nom` (« course » ou « attaque ») du corps `id` à l'échelle `k` ; `corps` : teinte de la couche du corps ;
--- `lueur` : couleur de la lueur, `alpha` : sa force.
function M.animation(id, nom, k, corps, lueur, alpha, vitesse)
  local A = assert(SPR[id], "corps3d : feuilles absentes pour " .. tostring(id))
  local a = A[nom]
  local principal = { tint = { r = corps.r, g = corps.g, b = corps.b, a = 1 } }
  local gl = { draw_as_glow = true, blend_mode = "additive", tint = { r = lueur.r * alpha, g = lueur.g * alpha, b = lueur.b * alpha, a = alpha } }
  local ombre = { draw_as_shadow = true }
  if vitesse then principal.animation_speed, gl.animation_speed, ombre.animation_speed = vitesse, vitesse, vitesse end
  return { layers = { couche(A, a.couches.main, a, k, principal), couche(A, a.couches.glow, a, k, gl), couche(A, a.couches.shadow, a, k, ombre) } }
end

--- Animation du CADAVRE (corpse.animation) du corps `id` : une image par direction (pièce « mort »), lueur résiduelle ; nil sans feuille.
function M.cadavre(id, k, corps, lueur, alpha)
  local A = SPR[id]
  local C = A and A.cadavre
  if not (C and C.mort) then return nil end
  local a = C.mort
  local principal = { tint = { r = corps.r, g = corps.g, b = corps.b, a = 1 } }
  local gl = { draw_as_glow = true, blend_mode = "additive", tint = { r = lueur.r * alpha, g = lueur.g * alpha, b = lueur.b * alpha, a = alpha } }
  return { layers = { couche(A, a.couches.main, a, k, principal), couche(A, a.couches.glow, a, k, gl), couche(A, a.couches.shadow, a, k, { draw_as_shadow = true }) } }
end

--- Icône rendue du corps `id` ({ filename, size }) ou nil.
function M.icone(id)
  local A = SPR[id]
  return A and A.icone
end

--- distance_per_frame : le pied d'appui reste fixe au sol, à l'échelle k.
function M.distance_par_image(id, k)
  local A = SPR[id]
  return A.foulee * k / A.course.images
end

return M
