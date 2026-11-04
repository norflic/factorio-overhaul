-- Lot DA-ATELIERS (phase 3) : visuels des bâtiments d'atelier « à part » (un seul design par bâtiment, sans âge ; retour du DC,
-- fo-logs/2026-11-04_DA/BRIEF_DA.md). Images de graphics/machines/ateliers (PNG hors de git, D-6 : sprites.lua, généré par
-- tools/render/pieces/ateliers/feuilles.py). Appelé par prototypes/crafts.lua (machine) : remplace la copie vanilla teintée.
-- Vue unique, façade au sud ; machine à fluide : un tronçon de raccord par direction (pipe_picture), le nord sous le corps.
-- Torchère : flamme du jeu = animations vanilla fire-flame (additives, draw_as_glow, déjà chargées par le jeu : rien de plus dans
-- l'atlas, plein au plancher, F186), fumée sombre au-dessus, deux lumières qui scintillent (au sol et dans la flamme).

local SPR = require("__factorio-overhaul__/graphics/machines/ateliers/sprites")

local V = {}

-- prototype : nom de la pièce dans sprites.lua
local PIECE = { ["fo-flare-stack"] = "torchere", ["fo-crusher"] = "concasseur", ["fo-jaw-crusher"] = "machoires",
                ["fo-coil-winder"] = "bobineuse", ["fo-lapidary"] = "taillerie" }

--- Couche d'une feuille : normale 32 px/tuile + hr_version 64 px/tuile (scale 0,5), comme prototypes/robots.lua (usine_couche).
local function couche(def, kind)
  local function une(r, hr)
    local t = { filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] }, priority = "high", frame_count = 1 }
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
    if hr then t.scale = 0.5 end
    return t
  end
  local s = une(def.lr, false)
  s.hr_version = une(def.hr, true)
  return s
end

local function sprite_tuyau(p)
  local l = { couche(p.main, "main") }
  if p.shadow then l[#l + 1] = couche(p.shadow, "shadow") end
  return { layers = l }
end

-- Torchère : tête de torchère du rendu (m_torchere.py, variante e : xs = 0,22, ys = Y(0,32), sommet de la tête z = 4,59 unités),
-- soit x = 0,24 et y = −(0,4525 + 4,55) × 0,7071 = −3,54 tuiles à l'écran (base de la flamme).
local FLAMME = { x = 0.24, y = -3.54 }

local function flamme_vanilla(n, scale, dx, vitesse)
  -- fire-flame-NN : 25 images de 60 × 118 px, 8 par ligne (data/base/prototypes/fire-util.lua) ; l'image vanilla est décalée de
  -- (−0,039 ; −0,906) tuile à l'échelle 0,5 pour poser la base de la flamme sur l'entité.
  local w = { [12] = { 63, 116 }, [13] = { 60, 118 } }
  local k = scale / 0.5
  return {
    filename = string.format("__base__/graphics/entity/fire-flame/fire-flame-%02d.png", n),
    line_length = 8, width = w[n][1], height = w[n][2], frame_count = 25, animation_speed = vitesse,
    scale = scale, blend_mode = "additive", draw_as_glow = true, priority = "high",
    shift = { FLAMME.x + dx - 0.039 * k, FLAMME.y - 0.906 * k },
  }
end

local function torchere(e, p)
  e.working_visualisations = {
    { fadeout = true, animation = couche(p.glow, "glow") },
    -- flamme : deux langues vanilla superposées, plus large à la base, qui ondulent à deux vitesses
    { fadeout = true, animation = { layers = { flamme_vanilla(13, 0.46, -0.05, 0.55), flamme_vanilla(12, 0.38, 0.07, 0.8) } } },
    -- fumée sombre à la pointe (smoke vanilla teintée, comme la cheminée de l'atelier de robots)
    { fadeout = true, animation = {
      filename = "__base__/graphics/entity/smoke/smoke.png", width = 152, height = 120, line_length = 5, frame_count = 60,
      animation_speed = 0.22, scale = 0.6, shift = { FLAMME.x + 0.25, FLAMME.y - 1.85 }, priority = "high", flags = { "smoke" },
      tint = { r = 0.32, g = 0.28, b = 0.25, a = 0.55 },
    } },
    -- lumières qui scintillent : flaque au sol (environ 9 tuiles de rayon) et cœur de la flamme
    { fadeout = true, effect = "flicker", light = { intensity = 0.7, size = 18, color = { r = 1.0, g = 0.58, b = 0.24 }, shift = { FLAMME.x, -0.3 } } },
    { fadeout = true, effect = "flicker", light = { intensity = 0.9, size = 5, color = { r = 1.0, g = 0.66, b = 0.3 }, shift = { FLAMME.x, FLAMME.y - 0.4 } } },
  }
  local b = p.boite
  e.drawing_box = { { math.min(b[1][1], -1.0), math.min(b[1][2], FLAMME.y - 2.6) }, { math.max(b[2][1], 1.0), math.max(b[2][2], 1.0) } }
end

-- Concasseur (m_concasseur.py, version d) : sommet de la cheminée en (0,77 ; 0,59 unité), z = 2,82, soit (0,77 ; −2,41) à l'écran ;
-- porte du foyer sur la face sud-est de la chaudière, (0,98 ; −0,46) à l'écran.
local function concasseur(e, p)
  local vis = { { fadeout = true, animation = couche(p.glow, "glow") } }
  if p.light then vis[#vis + 1] = { fadeout = true, animation = couche(p.light, "light") } end
  vis[#vis + 1] = { fadeout = true, effect = "flicker", light = { intensity = 0.45, size = 3.5, color = { r = 1.0, g = 0.5, b = 0.15 }, shift = { 0.98, -0.25 } } }
  e.working_visualisations = vis
  local es = e.energy_source
  if es and es.smoke then
    for _, sm in ipairs(es.smoke) do sm.position = { 0.77, -2.45 } ; sm.north_position, sm.east_position, sm.south_position, sm.west_position = nil, nil, nil, nil end
  end
end

-- Broyeur (m_machoires.py, version d) : milieu de la chambre entre les mâchoires (x = −0,09, z ≈ 0,9), soit (−0,09 ; −0,64) à
-- l'écran ; gyrophare sur l'armoire est, (1,2 ; −1,14). La lumière de la chambre pose la tache chaude sur les pierres la nuit
-- (contre-relecture : « chambre éclairée la nuit ») ; une couche cuite ne le peut pas (aucun halo sur la pièce, règle V0b).
local function machoires(e, p)
  local vis = { { fadeout = true, animation = couche(p.glow, "glow") } }
  if p.light then vis[#vis + 1] = { fadeout = true, animation = couche(p.light, "light") } end
  vis[#vis + 1] = { fadeout = true, light = { intensity = 0.55, size = 4, color = { r = 1.0, g = 0.85, b = 0.6 }, shift = { -0.09, -0.6 } } }
  vis[#vis + 1] = { fadeout = true, light = { intensity = 0.5, size = 2.5, color = { r = 1.0, g = 0.6, b = 0.1 }, shift = { 1.2, -1.14 } } }
  e.working_visualisations = vis
end

-- Bobineuse et taillerie (versions d) : lueur et halo cuits (bac d'émail, hublots ; cristaux) + une lumière de jeu à la source.
-- Bac d'émail : (−0,48 ; 1,13 unité, z 0,3), soit (−0,48 ; 0,59) à l'écran ; cristal du mandrin de la taillerie : (−0,04 ; −0,96).
local LUMIERE = {
  bobineuse = { intensity = 0.4, size = 3, color = { r = 1.0, g = 0.6, b = 0.18 }, shift = { -0.48, 0.75 } },
  taillerie = { intensity = 0.45, size = 3.5, color = { r = 0.3, g = 0.8, b = 1.0 }, shift = { -0.05, -0.7 } },
}
local function simple(e, p, nom)
  local vis = { { fadeout = true, animation = couche(p.glow, "glow") } }
  if p.light then vis[#vis + 1] = { fadeout = true, animation = couche(p.light, "light") } end
  vis[#vis + 1] = { fadeout = true, light = LUMIERE[nom] }
  e.working_visualisations = vis
end

--- Habille le prototype e (copie d'assembleur de prototypes/crafts.lua) s'il a un visuel d'atelier. Rend les icônes, ou nil.
function V.appliquer(e)
  local nom = PIECE[e.name]
  if not nom then return nil end
  local p = SPR.pieces[nom]
  if not p then return nil end   -- feuille pas encore produite (feuilles.py) : la copie teintée reste
  e.animation = { layers = { couche(p.main, "main"), couche(p.shadow, "shadow") } }
  e.idle_animation = nil
  e.integration_patch = nil
  e.shadow = nil
  if nom == "torchere" then torchere(e, p) elseif nom == "concasseur" then concasseur(e, p) elseif nom == "machoires" then machoires(e, p)
  elseif LUMIERE[nom] then simple(e, p, nom) end
  -- raccords : un tronçon par direction ; le nord est dessiné sous le corps (secondary_draw_orders du modèle)
  if e.fluid_boxes then
    local t = { north = SPR.pieces[nom .. "_tuyau_n"], east = SPR.pieces[nom .. "_tuyau_e"], south = SPR.pieces[nom .. "_tuyau_s"],
                west = SPR.pieces[nom .. "_tuyau_o"] }
    if t.north and t.east and t.south and t.west then
      for _, fb in ipairs(e.fluid_boxes) do
        fb.pipe_picture = { north = sprite_tuyau(t.north), east = sprite_tuyau(t.east), south = sprite_tuyau(t.south), west = sprite_tuyau(t.west) }
      end
    end
  end
  e.map_color = { r = p.map_color[1], g = p.map_color[2], b = p.map_color[3] }
  e.friendly_map_color = e.map_color
  e.scale_entity_info_icon = true
  local i = p.icone
  return { { icon = i.filename, icon_size = i.icon_size, icon_mipmaps = i.icon_mipmaps } }
end

return V
