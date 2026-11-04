-- Lot DA-METALLURGIE (4/11) : les vrais visuels des bâtiments de métallurgie, à la place des copies vanilla teintées.
-- Feuilles : graphics/metallurgie/sprites.lua, généré par tools/render/pieces/metallurgie/feuilles.py (PNG hors de git, D-6).
-- Appliqué par appliquer(), appelé à la FIN de prototypes/bauxite.lua (dernier des trois fichiers qui créent ces bâtiments :
-- titanium, crafts, bauxite) : les fonctions partagées machine() et pylon() ne sont pas touchées ; seuls les visuels, la boîte de
-- dessin, la couleur de carte et les icônes changent. Emprises, boîtes de collision, énergie, recettes et fluides : inchangés.
local SPR = require("__factorio-overhaul__/graphics/metallurgie/sprites")

local M = {}

local VISUAL_KEYS = { "animation", "idle_animation", "working_visualisations", "integration_patch", "shadow" }

--- Couche d'une feuille : normale 32 px par tuile + hr_version 64 px par tuile (scale 0,5) ; idiome de prototypes/robots.lua.
local function couche(def, kind)
  local function une(r, hr)
    local t = { filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] }, priority = "high" }
    if r.direction_count then t.direction_count = r.direction_count else t.frame_count = 1 end
    if kind == "shadow" then
      t.draw_as_shadow = true
    elseif kind == "glow" then
      t.draw_as_glow = true
      t.blend_mode = "additive"       -- critique du 3/11 : sans cela, la lueur s'affiche en aplat orange opaque
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

local function icones(d)
  return { { icon = d.icone.filename, icon_size = d.icone.icon_size, icon_mipmaps = d.icone.icon_mipmaps } }
end

-- Lumière au sol au travail (critique : comme la lumière au sol du four en acier), position en tuiles à l'écran, d'après les
-- modèles (m_hf.py : cour de coulée ; m_co.py : porte ouverte ; m_kr.py : puits ouvert). Fumée des machines à combustible : au
-- sommet des prises de gaz du haut fourneau (z 5,3) et de la cheminée du four à coke (z 4,5), projetées à l'écran.
local AU_TRAVAIL = {
  ["fo-blast-furnace"] = { light = { intensity = 0.85, size = 9, color = { r = 1.0, g = 0.55, b = 0.2 }, shift = { 0.0, 1.2 } },
                           smoke = { { -0.29, -4.25 }, { 0.59, -4.25 } } },
  ["fo-coke-oven"] = { light = { intensity = 0.45, size = 5, color = { r = 1.0, g = 0.5, b = 0.18 }, shift = { 0.0, 0.9 } },
                       smoke = { { -0.62, -4.4 } } },
  ["fo-kroll-reactor"] = { light = { intensity = 0.55, size = 6, color = { r = 1.0, g = 0.6, b = 0.25 }, shift = { -0.2, -0.6 } } },
  ["fo-ore-concentrator"] = { light = { intensity = 0.3, size = 3, color = { r = 1.0, g = 0.7, b = 0.3 }, shift = { 0.5, -0.8 } } },
  ["fo-reduction-cell"] = { light = { intensity = 0.7, size = 7, color = { r = 1.0, g = 0.55, b = 0.2 }, shift = { 0.45, 1.0 } } },
}

--- Une machine (assembling-machine) : image fixe principale + ombre ; lueur et lumière au sol au travail seulement, en fondu.
function M.habiller_machine(e, d)
  for _, k in ipairs(VISUAL_KEYS) do e[k] = nil end
  e.animation = { layers = { couche(d.main, "main"), couche(d.shadow, "shadow") } }
  local t = AU_TRAVAIL[e.name] or {}
  local vis = {}
  if d.glow then
    vis[#vis + 1] = { fadeout = true, animation = couche(d.glow, "glow"), light = t.light }
  elseif t.light then
    vis[#vis + 1] = { fadeout = true, light = t.light }
  end
  e.working_visualisations = vis
  if t.smoke and e.energy_source and e.energy_source.type == "burner" then
    local sm = {}
    for _, p in ipairs(t.smoke) do
      sm[#sm + 1] = { name = "smoke", frequency = 10, position = { p[1], p[2] }, starting_vertical_speed = 0.08,
                      starting_frame_deviation = 60 }
    end
    e.energy_source.smoke = sm
  end
  e.drawing_box = { { d.boite[1][1], d.boite[1][2] }, { d.boite[2][1], d.boite[2][2] } }
  e.water_reflection = nil
  e.map_color = { r = d.map_color[1], g = d.map_color[2], b = d.map_color[3] }
  e.friendly_map_color = e.map_color
  e.scale_entity_info_icon = true
  e.icons, e.icon, e.icon_size, e.icon_mipmaps = icones(d), nil, nil, nil
end

--- Un poteau (electric-pole) : 4 directions de la tête, points de fil au bas des chaînes ; feux de balisage en lueur.
function M.habiller_poteau(e, d)
  local layers = { couche(d.main, "main"), couche(d.shadow, "shadow") }
  if d.glow then layers[#layers + 1] = couche(d.glow, "glow") end
  e.pictures = { layers = layers }
  local cps = {}
  for i, cp in ipairs(d.connection_points) do
    cps[i] = { wire = { copper = cp.wire.copper, red = cp.wire.red, green = cp.wire.green },
               shadow = { copper = cp.shadow.copper, red = cp.shadow.red, green = cp.shadow.green } }
  end
  e.connection_points = cps
  e.drawing_box = { { d.boite[1][1], d.boite[1][2] }, { d.boite[2][1], d.boite[2][2] } }
  e.water_reflection = nil
  e.map_color = { r = d.map_color[1], g = d.map_color[2], b = d.map_color[3] }
  e.icons, e.icon, e.icon_size, e.icon_mipmaps = icones(d), nil, nil, nil
end

-- Recettes VARIANTES dont l'icône est celle du bâtiment marquée d'un ingrédient (prototypes/bauxite.lua) : 1re couche remplacée.
local VARIANTES = { ["fo-ht-pylon"] = { "fo-ht-pylon-aluminium" } }

local function objet(nom, d)
  local it = data.raw.item[nom]
  if it then it.icons, it.icon, it.icon_size, it.icon_mipmaps = icones(d), nil, nil, nil end
  for _, rn in ipairs(VARIANTES[nom] or {}) do
    local r = data.raw.recipe[rn]
    if r and r.icons and r.icons[1] then r.icons[1] = icones(d)[1] end
  end
end

local function trie(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Applique toutes les feuilles présentes dans sprites.lua ; une entité absente est une erreur (renvoie le nombre habillé).
function M.appliquer()
  local n = 0
  for _, nom in ipairs(trie(SPR.machines)) do
    local e = data.raw["assembling-machine"][nom]
    assert(e, "metallurgie : machine absente " .. nom)
    M.habiller_machine(e, SPR.machines[nom])
    objet(nom, SPR.machines[nom])
    n = n + 1
  end
  for _, nom in ipairs(trie(SPR.poteaux)) do
    local e = data.raw["electric-pole"][nom]
    assert(e, "metallurgie : poteau absent " .. nom)
    M.habiller_poteau(e, SPR.poteaux[nom])
    objet(nom, SPR.poteaux[nom])
    n = n + 1
  end
  return n
end

return M
