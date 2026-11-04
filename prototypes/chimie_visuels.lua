--[[
  Visuels des MACHINES DE CHIMIE à fluides (lot DA-CHIMIE, 4/11) : vapocraqueur, reformeur, électrolyseur, colonne
  d'extraction. Remplacent l'usine chimique teintée (lib.tint_sprites) par les rendus du kit tools/render/pieces/chimie :
  corps FIXE dans les 4 directions (les raccords de fluides tournent avec la machine, comme l'usine chimique vanilla),
  ombre, lueur additive (draw_as_glow, en fondu au travail), halo de nuit au sol pour le vapocraqueur (draw_as_light,
  idiome de la flaque du four en pierre vanilla). Images de graphics/machines/chimie (PNG hors de git, D-6 : sprites.lua,
  généré par tools/render/pieces/chimie/feuilles.py).

  Appelé par machine() de prototypes/crafts.lua, titanium.lua et superconductors.lua : habiller(e) pose les visuels si la
  machine en a, icones(nom) rend les icônes de la machine (entité et objet).
]]

local SPR = require("__factorio-overhaul__/graphics/machines/chimie/sprites")

local V = {}

V.FEUILLE = {
  ["fo-steam-cracker"] = "craqueur",
  ["fo-reformer"] = "reformeur",
  ["fo-electrolyzer"] = "electrolyseur",
  ["fo-extraction-column"] = "colonne",
}

-- Lumière au travail (F37), couleur de la lueur de chaque machine.
local LUMIERE = {
  craqueur = { color = { r = 1.0, g = 0.42, b = 0.12 }, size = 7, intensity = 0.45 },
  reformeur = { color = { r = 1.0, g = 0.5, b = 0.2 }, size = 6, intensity = 0.4 },
  electrolyseur = { color = { r = 0.3, g = 0.82, b = 1.0 }, size = 6, intensity = 0.4 },
  colonne = { color = { r = 0.72, g = 0.42, b = 1.0 }, size = 7, intensity = 0.45 },
}

local DIRS = { { "north", "n" }, { "east", "e" }, { "south", "s" }, { "west", "w" } }

--- Couche d'une feuille : normale 32 px/tuile + hr_version 64 px/tuile (scale 0,5).
local function couche(def, kind)
  local function une(r, hr)
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
      t.draw_as_sprite = false
      t.blend_mode = "additive"
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

--- Pose les visuels de la machine e (si elle en a) ; rend vrai si c'est fait.
function V.habiller(e)
  local nom = V.FEUILLE[e.name]
  if not nom then return false end
  local m = SPR.machines[nom]
  assert(m, "chimie : machine sans feuille " .. nom)
  local anim, glow, light = {}, {}, {}
  local a_light = false
  for _, dd in ipairs(DIRS) do
    local dir, d = dd[1], dd[2]
    local c = m[d]
    assert(c and c.main and c.shadow, "chimie : " .. nom .. " sans couches en " .. d)
    anim[dir] = { layers = { couche(c.main, "main"), couche(c.shadow, "shadow") } }
    if c.glow then glow[dir .. "_animation"] = couche(c.glow, "glow") end
    if c.light then
      light[dir .. "_animation"] = couche(c.light, "light")
      a_light = true
    end
  end
  e.animation = anim
  e.idle_animation = nil
  e.integration_patch = nil
  local lum = LUMIERE[nom]
  local v1 = { fadeout = true, light = { intensity = lum.intensity, size = lum.size, color = lum.color, shift = { 0, -0.6 } } }
  for _, dd in ipairs(DIRS) do v1[dd[1] .. "_animation"] = glow[dd[1] .. "_animation"] end
  local vis = { v1 }
  if a_light then
    local v2 = { fadeout = true, effect = "flicker", draw_as_light = true, draw_as_sprite = false }
    for _, dd in ipairs(DIRS) do v2[dd[1] .. "_animation"] = light[dd[1] .. "_animation"] end
    vis[#vis + 1] = v2
  end
  e.working_visualisations = vis
  -- Raccords : les brides sont dans le rendu (comme l'usine chimique vanilla) ; on garde les caches, pas les tronçons d'AM2.
  if e.fluid_boxes then
    for _, fb in ipairs(e.fluid_boxes) do fb.pipe_picture = nil end
  end
  e.drawing_box = { { m.boite[1][1], m.boite[1][2] }, { m.boite[2][1], m.boite[2][2] } }
  e.map_color = { r = m.map_color[1], g = m.map_color[2], b = m.map_color[3] }
  e.friendly_map_color = e.map_color
  e.scale_entity_info_icon = true
  local ic = V.icones(e.name)
  e.icon, e.icon_size, e.icon_mipmaps = nil, nil, nil
  e.icons = ic
  return true
end

--- Icônes de la machine (entité et objet), ou nil si elle n'a pas de feuille.
function V.icones(name)
  local nom = V.FEUILLE[name]
  if not nom then return nil end
  local i = SPR.machines[nom].icone
  return { { icon = i.filename, icon_size = i.icon_size, icon_mipmaps = i.icon_mipmaps } }
end

return V
