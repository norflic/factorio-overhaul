--[[
  Lot MACHINES-CALCUL (3/11) : les 20 machines de la chaîne du calcul prennent leur VRAI visuel (rendus du lot CALCUL-DESIGN,
  fo-logs/2026-11-01_CALCUL-DESIGN/final) à la place des copies vanilla teintées (DC, 3/11 : « on a changé juste la couleur [...]
  C'est pas du tout ce qu'il fallait avoir »).
  Feuilles : graphics/machines/calcul/ (PNG GÉNÉRÉS hors de git, D-6, par tools/render/pieces/calcul/feuilles.py ; sprites.lua
  généré, lu ici). Appelé à la fin de prototypes/compute_v2.lua, quand les 20 machines existent (crafts, superconductors, tin,
  compute, compute_v2) ; rien ne les retouche ensuite (le système de niveaux ne prend que les familles vanilla).

  Ce qui change : couches (animation, idle_animation, working_visualisations, integration_patch), boîte de dessin, couleur de
  carte, icônes de la machine, de son objet et des recettes qui la portent en marque (centre de calcul). Ce qui ne change PAS :
  emprise, boîtes de collision et de sélection, boîtes de fluide et leurs raccords, énergie, sons, catégories.
  Une seule vue pour les 4 directions. Corps et ombre toujours ; pièce mobile (12 machines) dans les couches du corps : elle tourne
  quand la machine travaille et reste en place à l'arrêt ; lueur (draw_as_glow, visible de jour) et lumière seulement au travail.
  Raccords de fluide : le dessin est unique, ils sont donc tracés par le moteur dans chaque direction (pipe_picture de
  l'assembleur 3, couvercles des tuyaux) ; une boîte qui en a déjà garde les siens.
]]

local SPR = require("__factorio-overhaul__/graphics/machines/calcul/sprites")

local M = {}

M.SPRITES = SPR
M.ANIMATION_SPEED = 0.25 -- 8 images de la pièce mobile en 32 ticks

-- couleur de la lumière de nuit, par âge (âges présents dans la chaîne du calcul)
M.LUMIERE = {
  [4] = { r = 1.0, g = 0.55, b = 0.2 }, [5] = { r = 1.0, g = 0.4, b = 0.12 }, [6] = { r = 0.7, g = 0.8, b = 1.0 },
  [10] = { r = 0.3, g = 0.6, b = 1.0 }, [12] = { r = 0.3, g = 0.9, b = 1.0 }, [13] = { r = 1.0, g = 0.3, b = 0.85 },
}

--- Une couche (normale 32 px/tuile + hr_version 64 px/tuile, scale 0,5). kind : main, shadow, glow, mobile ;
--- rep : nombre d'images des autres couches de la même animation (repeat_count d'une couche fixe).
local function couche(c, kind, rep)
  local function une(r, hr)
    local t = { filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] }, priority = "high" }
    if kind == "mobile" then
      t.frame_count, t.line_length, t.animation_speed = c.images, c.images, M.ANIMATION_SPEED
    else
      t.frame_count = 1
      -- couche fixe d'une animation à pièce mobile : répétée sur le cycle, à la même vitesse que la pièce
      if rep and rep > 1 then t.repeat_count, t.animation_speed = rep, M.ANIMATION_SPEED end
    end
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
  local s = une(c.lr, false)
  s.hr_version = une(c.hr, true)
  return s
end
M.couche = couche

--- Icônes d'une machine dessinée, ou nil.
function M.icones(name)
  local sp = SPR[name]
  if not sp then return nil end
  return { { icon = sp.icone.icon, icon_size = sp.icone.icon_size, icon_mipmaps = sp.icone.icon_mipmaps } }
end

local PIPE_PICTURE, PIPE_COVERS
local function raccords_vanilla()
  if PIPE_PICTURE then return end
  for _, b in ipairs(data.raw["assembling-machine"]["assembling-machine-3"].fluid_boxes or {}) do
    if type(b) == "table" and b.pipe_picture then
      PIPE_PICTURE, PIPE_COVERS = b.pipe_picture, b.pipe_covers
      break
    end
  end
  assert(PIPE_PICTURE, "calcul : pipe_picture de l'assembleur 3 introuvable")
end

--- Pose les couches d'une machine ; rend vrai si elle a des feuilles.
function M.habiller(e)
  local sp = SPR[e.name]
  if not sp then return false end
  local c = sp.couches
  local n = c.mobile and c.mobile.images or 1
  local corps = { couche(c.main, "main", n) }
  if c.mobile then corps[#corps + 1] = couche(c.mobile, "mobile") end
  corps[#corps + 1] = couche(c.shadow, "shadow", n)
  e.animation = { layers = corps }
  e.idle_animation = nil
  e.always_draw_idle_animation = nil
  e.integration_patch = nil
  e.integration_patch_render_layer = nil
  e.water_reflection = nil
  local wv = {}
  if c.glow then wv[#wv + 1] = { fadeout = true, animation = couche(c.glow, "glow") } end
  local lum = M.LUMIERE[sp.age]
  if lum then
    wv[#wv + 1] = { fadeout = true, light = { intensity = 0.35, size = sp.cote * 2.2, color = lum } }
  end
  e.working_visualisations = wv
  e.drawing_box = { { sp.boite[1][1], sp.boite[1][2] }, { sp.boite[2][1], sp.boite[2][2] } }
  e.map_color = { r = sp.map_color[1], g = sp.map_color[2], b = sp.map_color[3] }
  e.friendly_map_color = e.map_color
  e.scale_entity_info_icon = true
  if e.fluid_boxes then
    raccords_vanilla()
    for _, b in ipairs(e.fluid_boxes) do
      if type(b) == "table" then
        b.pipe_picture = b.pipe_picture or table.deepcopy(PIPE_PICTURE)
        b.pipe_covers = b.pipe_covers or table.deepcopy(PIPE_COVERS)
      end
    end
  end
  e.icons = M.icones(e.name)
  e.icon, e.icon_size, e.icon_mipmaps = nil, nil, nil
  return true
end

--- Une couche d'icône est-elle l'ancienne icône teintée d'une machine (même fichier, même teinte) ?
local function meme_icone(l, old)
  if type(l) ~= "table" or l.icon ~= old.icon then return false end
  local a, b = l.tint, old.tint
  if a == nil or b == nil then return a == b end
  return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a
end

--- Passe finale : habille les 20 machines, leurs objets, et remplace l'ancienne icône teintée dans les recettes qui la portent.
function M.appliquer()
  local noms = {}
  for n in pairs(SPR) do noms[#noms + 1] = n end
  table.sort(noms)
  local anciennes = {}
  for _, n in ipairs(noms) do
    local e = assert(data.raw["assembling-machine"][n] or data.raw.furnace[n], "calcul : machine dessinée absente " .. n)
    local it = data.raw.item[n]
    if it and it.icons and it.icons[1] and it.icons[1].tint then
      anciennes[#anciennes + 1] = { old = table.deepcopy(it.icons[1]), new = M.icones(n)[1] }
    end
    M.habiller(e)
    if it then
      it.icons, it.icon, it.icon_size, it.icon_mipmaps = M.icones(n), nil, nil, nil
    end
  end
  -- recettes à marque (centre de calcul dans le coin, prototypes/compute.lua et compute_v2.lua) : même échelle à l'écran
  local rnoms = {}
  for rn in pairs(data.raw.recipe) do rnoms[#rnoms + 1] = rn end
  table.sort(rnoms)
  local remplacees = 0
  for _, rn in ipairs(rnoms) do
    local r = data.raw.recipe[rn]
    for _, l in ipairs(r.icons or {}) do
      for _, a in ipairs(anciennes) do
        if meme_icone(l, a.old) then
          local old_size = l.icon_size or r.icon_size or a.old.icon_size or 64
          if l.scale then l.scale = l.scale * old_size / a.new.icon_size end
          l.icon, l.icon_size, l.icon_mipmaps, l.tint = a.new.icon, a.new.icon_size, a.new.icon_mipmaps, nil
          remplacees = remplacees + 1
          break
        end
      end
    end
  end
  M.remplacees = remplacees
  return #noms
end

return M
