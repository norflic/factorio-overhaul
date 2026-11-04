--[[
  Lot BI-V1 : SOUCHES, un squelette rendu par espèce (PLAN §5 ter). Le palier reste une échelle, une teinte, des chiffres.
  Images : graphics/biters/ (PNG hors de git, décision D-6 ; tailles et décalages : graphics/biters/sprites.lua, généré par
  tools/render/pieces/biters/feuilles.py). Mêmes couches que biterrunanimation : corps, masque, ombre.
  `g` : échelle de jeu, celle de vanilla (0,5 pour le petit déchiqueteur) ; le modèle est en tuiles, multipliées par m = K × g.
]]

local S = require("__factorio-overhaul__/graphics/biters/sprites")

local M = {}

M.ATTAQUE_VITESSE = { moucheron = 0.11, ecraseur = 0.045 }

--- Facteur modèle -> tuiles à l'échelle de jeu g.
local function facteur(id, g) return S[id].K * g end

local function couche(c, a, m, extra)
  local layer = {
    filename = c.lr, width = c.lw, height = c.lh, frame_count = a.images, line_length = c.ll, direction_count = 16,
    shift = { c.sx * m, c.sy * m }, scale = m * 32 / (a.densite / a.reduc),
    hr_version = {
      filename = c.hr, width = c.w, height = c.h, frame_count = a.images, line_length = c.ll, direction_count = 16,
      shift = { c.sx * m, c.sy * m }, scale = m * 32 / a.densite,
    },
  }
  for k, v in pairs(extra or {}) do
    layer[k] = v
    layer.hr_version[k] = v
  end
  return layer
end

--- Une animation (course ou attaque) ; `teinte` : teinte du masque des plaques (a = 0 : le masque ne sert qu'à porter la lueur d'évolution).
local function animation(id, nom, g, teinte, vitesse)
  local a = S[id][nom]
  local m = facteur(id, g)
  local v = vitesse and { animation_speed = vitesse } or {}
  local principal, masque, ombre = {}, { flags = { "mask" }, tint = teinte }, { draw_as_shadow = true }
  for k, x in pairs(v) do principal[k], masque[k], ombre[k] = x, x, x end
  return { layers = {
    couche(a.couches.main, a, m, principal),
    couche(a.couches.mask, a, m, masque),
    couche(a.couches.shadow, a, m, ombre),
  } }
end

function M.course(id, g, teinte) return animation(id, "course", g, teinte) end

function M.attaque(id, g, teinte) return animation(id, "attaque", g, teinte, M.ATTAQUE_VITESSE[id]) end

--- distance_per_frame : le pied d'appui reste fixe au sol, à l'échelle g.
function M.distance_par_image(id, g)
  return S[id].foulee * facteur(id, g) / S[id].course.images
end

return M
