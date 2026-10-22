--[[
  Vitrine : pièces graphiques rendues (pipeline tools/render/, hypothèse H-V1), posées en jeu à côté
  de bâtiments vanilla pour être jugées sur capture. Rien ici n'est fabricable par le joueur.
  Fichier possédé par le lot V0 (OBJECTIFS.md §7).

  Pièce V0 : cheminée rivetée à couronne de braises (tools/render/pieces/cheminee.py).
  - fo-vitrine-v0-cheminee      : la cheminée seule, entité 1×1 (simple-entity-with-owner) ;
  - fo-vitrine-v0-cheminee-four : un four en acier vanilla qui la porte derrière son corps (copie du four,
                                  emprise 2×2 inchangée ; le four est dessiné PAR-DESSUS la cheminée, qui
                                  ne se voit qu'au-dessus du toit : elle DÉPASSE la silhouette, F42 ; lueur
                                  et halo en visualisations de marche, éteints four arrêté : lot V0b).
  Quatre couches par pièce : principale, ombre (draw_as_shadow), lueur (draw_as_glow, additive : visible
  de jour, et dans la carte des lumières la nuit), halo (draw_as_light, additive : la nuit seulement).
  Tailles et décalages : graphics/vitrine/cheminee/sprites.lua, GÉNÉRÉ par tools/render/render.py.
]]

local SPR = require("__factorio-overhaul__/graphics/vitrine/cheminee/sprites")

local NAME_SEULE = "fo-vitrine-v0-cheminee"
local NAME_FOUR = "fo-vitrine-v0-cheminee-four"

-- Drapeaux de chaque couche (clés écrites une à une : aucun parcours de table).
local function apply_flags(t, kind)
  if kind == "shadow" then
    t.draw_as_shadow = true
  elseif kind == "glow" then
    t.draw_as_glow = true
    t.blend_mode = "additive"
  elseif kind == "light" then
    t.draw_as_light = true
    t.blend_mode = "additive"
  end
  return t
end

--- Couche Sprite (normale 32 px/tuile + hr_version 64 px/tuile à l'échelle 0,5). flags : SpriteFlags
--- facultatifs (essai V0b du filtrage au zoom 1).
local function sprite_layer(def, kind, flags)
  local lr, hr = def.lr, def.hr
  local s = apply_flags({
    filename = lr.filename,
    width = lr.width,
    height = lr.height,
    shift = { lr.shift[1], lr.shift[2] },
    priority = "medium",
    flags = flags,
  }, kind)
  s.hr_version = apply_flags({
    filename = hr.filename,
    width = hr.width,
    height = hr.height,
    shift = { hr.shift[1], hr.shift[2] },
    scale = 0.5,
    priority = "medium",
    flags = flags,
  }, kind)
  return s
end

local LAYER_ORDER = { "shadow", "main", "glow", "light" }

-- V0b : drapeau de filtrage de la couche principale. Sans lui, la couche HR est échantillonnée au PLUS
-- PROCHE au zoom 1 (rapport V0 ; mesuré de nouveau au lot V0b : écart 0,056 au plus proche contre 0,088 en
-- moyenne 2×2) ; avec un drapeau de filtrage, filtrée 2×2 comme les bâtiments vanilla. Captures :
-- <racine>\fo-logs\2026-10-21_V0b_vitrine\ (haute, diagnostic-sans-essais, filtre).
local MAIN_FLAGS = { "linear-minification" }
-- Correcteur V0b : même drapeau sur la LUEUR (draw_as_glow), qui n'en avait pas (vérification V0b : au zoom 1,
-- échantillonnage au plus proche probable, scintillement des braises non mesuré). Le halo (draw_as_light) n'est
-- dessiné que dans la carte des lumières : sans drapeau.
local GLOW_FLAGS = { "linear-minification" }

local function flags_of(kind)
  if kind == "main" then return MAIN_FLAGS end
  if kind == "glow" then return GLOW_FLAGS end
  return nil
end

local function layers_of(variant)
  local v = SPR.variants[variant]
  if not v then error("vitrine : variante de sprites absente : " .. variant) end
  local out = {}
  for _, kind in ipairs(LAYER_ORDER) do
    if v[kind] then out[#out + 1] = sprite_layer(v[kind], kind, flags_of(kind)) end
  end
  return out
end

local out = {}

---------------------------------------------------------------------------------------------------
-- 1. Cheminée seule (1×1).
---------------------------------------------------------------------------------------------------
out[#out + 1] = {
  type = "simple-entity-with-owner",
  name = NAME_SEULE,
  icon = SPR.icon.filename,
  icon_size = SPR.icon.icon_size,
  icon_mipmaps = SPR.icon.icon_mipmaps,
  flags = { "placeable-neutral", "player-creation" },
  subgroup = "other",
  order = "z[fo-vitrine]-a[cheminee]",
  max_health = 250,
  collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } },
  selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
  -- boîte d'affichage (fiche de l'entité) : la cheminée monte à 2,4 unités, soit 1,7 tuile à l'écran
  drawing_box = { { -0.6, -2.3 }, { 0.6, 0.5 } },
  render_layer = "object",
  picture = { layers = layers_of("cheminee-seule") },
}

---------------------------------------------------------------------------------------------------
-- 2. Four en acier équipé de la cheminée (copie du four vanilla, mêmes statistiques, emprise 2×2).
---------------------------------------------------------------------------------------------------
local four = table.deepcopy(data.raw.furnace["steel-furnace"])
four.name = NAME_FOUR
four.minable = nil          -- vitrine : ne rend pas un four en acier au minage
four.placeable_by = nil
four.next_upgrade = nil
four.fast_replaceable_group = nil
four.localised_name = nil
four.localised_description = nil
four.order = "z[fo-vitrine]-b[cheminee-four]"
four.icon, four.icon_size, four.icon_mipmaps = nil, nil, nil
four.icons = {
  { icon = data.raw.furnace["steel-furnace"].icon, icon_size = 64, icon_mipmaps = 4 },
  { icon = SPR.icon.filename, icon_size = SPR.icon.icon_size, icon_mipmaps = SPR.icon.icon_mipmaps,
    scale = 0.3, shift = { -6, -6 } },
}
four.drawing_box = { { -1.0, -2.9 }, { 1.0, 1.0 } }
-- V0b : ombre et couche principale de la cheminée insérées AVANT les couches du four : le jeu dessine le
-- four PAR-DESSUS (V0 : couche découpée par l'alpha du four puis dessinée après lui, d'où un liseré de 1 px
-- sur 75 px de bord). La couche principale n'est donc plus découpée (render.py).
local v = SPR.variants["cheminee-four"]
if not v then error("vitrine : variante de sprites absente : cheminee-four") end
local pos = 1
for _, kind in ipairs({ "shadow", "main" }) do
  if v[kind] then
    table.insert(four.animation.layers, pos, sprite_layer(v[kind], kind, flags_of(kind)))
    pos = pos + 1
  end
end
-- V0b : lueur et halo de la cheminée en visualisations de marche (comme le feu vanilla du four) : ils
-- s'éteignent avec le four (fondu). Lueur : dessinée comme sprite ET dans la carte des lumières
-- (draw_as_light au niveau de la visualisation, idiome vanilla d'entities.lua) ; halo : carte des lumières
-- seulement (draw_as_sprite = false).
four.working_visualisations = four.working_visualisations or {}
local function anim_of(def, flags)
  local lr, hr = def.lr, def.hr
  return {
    filename = lr.filename, width = lr.width, height = lr.height, shift = { lr.shift[1], lr.shift[2] },
    priority = "medium", frame_count = 1, blend_mode = "additive", flags = flags,
    hr_version = {
      filename = hr.filename, width = hr.width, height = hr.height, shift = { hr.shift[1], hr.shift[2] },
      priority = "medium", frame_count = 1, blend_mode = "additive", scale = 0.5, flags = flags,
    },
  }
end
if v.glow then
  table.insert(four.working_visualisations,
    { fadeout = true, draw_as_light = true, animation = anim_of(v.glow, GLOW_FLAGS) })
end
if v.light then
  table.insert(four.working_visualisations,
    { fadeout = true, draw_as_light = true, draw_as_sprite = false, animation = anim_of(v.light, nil) })
end
out[#out + 1] = four

data:extend(out)
