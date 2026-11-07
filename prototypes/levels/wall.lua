--[[
  Visuel des niveaux : MUR (niveaux 2 à 30 ; le niveau 1 est le mur de pierre vanilla, jamais modifié).
  Série des 15 âges (1/11) : kit tools/render/pieces/levels/mur_o, feuilles par mur_o/feuilles.py dans graphics/levels/mur/
  (PNG hors de git, décision D-6 ; définitions : graphics/levels/mur/sprites.lua, généré ; contrôle :
  tests/datastage/mur_sheets.lua, dans le harness et levels_test).

  Par niveau n (âge e = époque) :
    - n = 2 (âge 1) : mur vanilla, avec la pièce e01 (rouleau de barbelé) en surcouche sur chaque clé qui a des couches ;
    - n impair 3 à 29 : le mur de l'âge ;
    - n pair 4 à 30 : le même, teinté (0,82 + 0,18 × lumière de l'âge, comme le four), plus la pièce paire en surcouche.
  Les clés sont en tableaux de Sprite (SpriteVariations) ; les 3 segments droits sont 3 variantes. Une lueur est une
  couche draw_as_glow fixe : un mur n'est pas animable par prototype (F44), et il n'a pas de couche draw_as_light (des
  milliers de murs posent des milliers de lumières, DESIGN_EPOQUES §1.6).
]]

local SPR = require("__factorio-overhaul__/graphics/levels/mur/sprites")

local M = {}

local CLES = {
  single = { "single" },
  straight_vertical = { "vert" },
  straight_horizontal = { "horiz", "horiz2", "horiz3" },
  corner_right_down = { "corR" },
  corner_left_down = { "corL" },
  t_up = { "tee" },
  ending_right = { "endR" },
  ending_left = { "endL" },
}

local function couche(def, kind, teinte, repeat_count)
  local function une(r, hr)
    local t = { filename = r.filename, x = r.x, y = r.y, width = r.width, height = r.height,
      shift = { r.shift[1], r.shift[2] }, priority = "medium", repeat_count = repeat_count }
    if hr then t.scale = 0.5 end
    if kind == "shadow" then
      t.draw_as_shadow = true
    elseif kind == "glow" then
      t.draw_as_glow = true
      t.blend_mode = "additive"
      t.flags = { "linear-minification" }
    else
      t.flags = { "linear-minification" }
      if teinte then t.tint = { r = teinte[1], g = teinte[2], b = teinte[3], a = 1 } end
    end
    return t
  end
  local s = une(def.lr, false)
  s.hr_version = une(def.hr, true)
  return s
end

--- Couches d'une partie (forme ou pièce), à ajouter à `liste`.
local function ajoute(liste, partie, teinte, repeat_count)
  if partie.main then liste[#liste + 1] = couche(partie.main, "main", teinte, repeat_count) end
  if partie.shadow then liste[#liste + 1] = couche(partie.shadow, "shadow", nil, repeat_count) end
  if partie.glow then liste[#liste + 1] = couche(partie.glow, "glow", nil, repeat_count) end
end

local function sprite(age, forme, step)
  local layers = {}
  local teinte = step == 2 and age.teinte or nil
  ajoute(layers, age[forme], teinte)
  if step == 2 then ajoute(layers, age.piece, teinte) end
  return { layers = layers }
end

function M.dress(p, ctx)
  local age = SPR.ages[ctx.epoch]
  assert(age, "wall.lua : âge " .. ctx.epoch .. " absent de graphics/levels/mur/sprites.lua")
  if ctx.epoch == 1 then
    -- Niveau 2 : les clés vanilla, en feuilles à plusieurs variantes, gardent leurs variantes : la pièce se répète.
    for _, cle in ipairs({ "single", "straight_vertical", "straight_horizontal", "corner_right_down", "corner_left_down",
      "t_up", "ending_right", "ending_left" }) do
      local c = p.pictures[cle]
      ajoute(c.layers, age.piece, nil, c.layers[1].variation_count)
    end
    return
  end
  local pics = {
    filling = { sprite(age, "filling", 1) },
    water_connection_patch = { north = sprite(age, "jN", 1), east = sprite(age, "jE", 1),
      south = sprite(age, "jS", 1), west = sprite(age, "jO", 1) },
    gate_connection_patch = { north = sprite(age, "jN", 1), east = sprite(age, "jE", 1),
      south = sprite(age, "jS", 1), west = sprite(age, "jO", 1) },
  }
  for cle, formes in pairs(CLES) do
    local v = {}
    for i, f in ipairs(formes) do v[i] = sprite(age, f, ctx.step) end
    pics[cle] = v
  end
  p.pictures = pics
  p.drawing_box = { { age.boite[1][1], age.boite[1][2] }, { age.boite[2][1], age.boite[2][2] } }
  p.map_color = { r = age.map_color[1], g = age.map_color[2], b = age.map_color[3] }
end

--- Icônes : celle de l'âge (réduite du segment droit), le numéro du niveau (couches suivantes) reste celui du kit. Âge 1 :
--- icône vanilla.
function M.icons(icons, ctx)
  local age = SPR.ages[ctx.epoch]
  if ctx.epoch == 1 or not age or not age.icone then return icons end
  icons[1] = { icon = age.icone.filename, icon_size = age.icone.icon_size, icon_mipmaps = age.icone.icon_mipmaps }
  return icons
end

return M
