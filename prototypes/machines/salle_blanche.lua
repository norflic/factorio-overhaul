--[[
  Visuel de la SALLE BLANCHE (fo-cleanroom, 5x5, âge 10, sans niveaux) : lot CALC-SALLE-BLANCHE (30/10). Remplace le
  visuel PROVISOIRE (assembleur 3 ×5/3 teinté) posé par prototypes/crafts.lua.

  Sprites rendus par tools/render/pieces/machines/salle_blanche/ (modele.py, rendre.py) et mis en feuilles par
  feuilles.py dans graphics/machines/salle-blanche/ (sprites.lua GÉNÉRÉ). DESIGN NON VALIDÉ par le Directeur Créatif tant
  qu'OBJECTIFS.md ne dit pas le contraire.

  Couches :
    - animation (toujours dessinée) : corps (baies éteintes) et ombre ;
    - working_visualisations (fadeout : elles s'éteignent avec la machine) : lueur des baies ambre et du hublot du sas
      (draw_as_glow), voyants bleus qui clignotent (8 images, frame_sequence de l'âge 10), halo de nuit au sol
      (draw_as_light) et une lumière dynamique ambre.
  Raccords de fluide : ceux du provisoire (images de l'assembleur 2), inchangés.
]]

local SPR = require("__factorio-overhaul__/graphics/machines/salle-blanche/sprites")

local M = {}

local function une(def, kind, extra)
  local function f(r, hr)
    local t = { filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] },
      priority = "high", frame_count = 1 }
    if kind == "shadow" then
      t.draw_as_shadow = true
    elseif kind == "glow" then
      t.draw_as_glow = true
      t.blend_mode = "additive"
      t.flags = { "linear-minification" }
    elseif kind == "light" then
      t.draw_as_light = true
      t.blend_mode = "additive"
    else
      t.flags = { "linear-minification" }
    end
    if extra then
      t.frame_count, t.line_length, t.animation_speed = extra.frame_count, extra.line_length, extra.animation_speed
    end
    if hr then t.scale = 0.5 end
    return t
  end
  local s = f(def.lr, false)
  s.hr_version = f(def.hr, true)
  return s
end

function M.dress(e)
  e.animation = { layers = { une(SPR.main, "main"), une(SPR.shadow, "shadow") } }
  e.idle_animation = nil
  local wv = {}
  wv[#wv + 1] = { fadeout = true, animation = une(SPR.fenetres, "glow") }
  if SPR.voyants then
    wv[#wv + 1] = { fadeout = true, animation = une(SPR.voyants, "glow",
      { frame_count = SPR.images_voyants, line_length = SPR.images_voyants, animation_speed = 0.12 }) }
  end
  if SPR.light then
    wv[#wv + 1] = { fadeout = true, animation = une(SPR.light, "light") }
  end
  wv[#wv + 1] = { fadeout = true, light = { intensity = 0.35, size = 9, shift = { 0.4, 1.6 },
    color = { r = 1.0, g = 0.72, b = 0.3 } } }
  e.working_visualisations = wv
  e.integration_patch = nil
  e.drawing_box = { { SPR.boite[1][1], SPR.boite[1][2] }, { SPR.boite[2][1], SPR.boite[2][2] } }
  e.map_color = { r = SPR.map_color[1], g = SPR.map_color[2], b = SPR.map_color[3] }
end

function M.icons()
  return { { icon = SPR.icone.filename, icon_size = SPR.icone.icon_size, icon_mipmaps = SPR.icone.icon_mipmaps } }
end

return M
