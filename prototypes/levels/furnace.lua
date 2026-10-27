--[[
  Visuel des niveaux : FOUR EN ACIER (niveaux 2 à 30 ; le niveau 1 est le four vanilla, jamais modifié).
  Propriétaire : lot F2 (design F2-A, intégration F2-B, 25/10). Interface : en tête de prototypes/levels/common.lua.

  Designs des 15 âges VALIDÉS par le Directeur Créatif (25/10, R-QCM-25h : « Validé, production ») ; sprites de
  production (128 échantillons, ombre à 32 : D-7) mis en feuilles par tools/render/pieces/levels/four_e/feuilles.py dans
  graphics/levels/four/ (PNG hors de git, décision D-6 ; définitions : graphics/levels/four/sprites.lua, généré ;
  contrôle : tests/datastage/four_sheets.lua, dans le harness et levels_test). Fiches : fo-logs/2026-10-25_F2.

  Par niveau n (âge e = époque) :
    - n = 2 (âge 1) : four vanilla inchangé, avec la pièce e01 (tuyau de poêle, râtelier de bûches, lanternes) posée
      SOUS lui (couches insérées en tête : elle dépasse sa silhouette au nord, F42) ; feu et fumée vanilla ;
    - n impair 3 à 29 : le four de l'âge (couche principale et ombre) ;
    - n pair 4 à 30 : le même, TEINTÉ (teinte de l'âge : 0,82 + 0,18 × sa lumière, phase A2), plus la pièce paire.
  Animation de travail (working_visualisations, seulement quand le four chauffe, fadeout) :
    1. feu de la gueule : feuille PARTAGÉE de 16 images (flammes presque blanches), teintée à la lumière de l'âge
       (une teinte multiplie, F36), à la place et à la taille de la bouche de l'âge (sprites.lua, « gueule ») ;
    2. lueur de l'âge (couche glow rendue : braises, lave, voyants, cristaux…), draw_as_glow, additive ;
    3. halo de nuit (couche light rendue), draw_as_light, effet « flicker » comme le four vanilla ;
    4. flaque de lumière au sol devant la gueule (LightDefinition du moteur sur le feu, couleur de l'âge, taille
       suivant l'emprise ; ajoutée en F2-B : de nuit, la couche light rendue seule éclairait bien moins que le vanilla).
  Fumée : particule vanilla (« smoke » ; « turbine-smoke », vapeur, aux âges 9 et 12) à la bouche de fumée relevée au
  rendu, position de jeu ESTIMÉE (x, −(yn + 0,7071 z)) ; à vérifier sur capture.
  Reste et explosion : copies déclarées (ctx.declare) de celles de la vanilla, agrandies à l'emprise. Couleur de carte :
  couleur moyenne du four de l'âge. Icône : celle de l'âge (réduite du four), le numéro du niveau reste celui du kit.
]]

local SPR = require("__factorio-overhaul__/graphics/levels/four/sprites")

local M = {}

local function flags(t, kind)
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
  return t
end

--- Couche d'une image : normale 32 px/tuile + hr_version 64 px/tuile (scale 0,5) ; `teinte` : couche principale du
--- niveau pair.
local function couche(def, kind, teinte)
  local function une(r, hr)
    local t = flags({ filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] },
      priority = "medium" }, kind)
    if hr then t.scale = 0.5 end
    if teinte then t.tint = { r = teinte[1], g = teinte[2], b = teinte[3], a = 1 } end
    return t
  end
  local s = une(def.lr, false)
  s.hr_version = une(def.hr, true)
  return s
end

--- Feu de la gueule : la feuille partagée, mise à la largeur de la bouche de l'âge (image de ref_w × ref_h tuiles,
--- même rapport que les bouches : cotes.py), bas des flammes au bas de la bouche, teinte de la lumière de l'âge.
local function feu(age)
  local F, g = SPR.feu, age.gueule
  local k = g.w / F.ref_w
  local y = g.y + g.h / 2 - F.ref_h * k / 2
  local function une(r, hr)
    return { filename = r.filename, width = r.width, height = r.height, frame_count = F.frame_count,
      line_length = F.line_length, animation_speed = 0.5, shift = { g.x, y }, scale = (hr and 0.5 or 1) * k,
      tint = { r = age.foyer[1], g = age.foyer[2], b = age.foyer[3], a = 1 }, draw_as_glow = true,
      blend_mode = "additive", priority = "high" }
  end
  local s = une(F.lr, false)
  s.hr_version = une(F.hr, true)
  return s
end

local function couches(liste, parties, kind, teinte)
  for i, partie in ipairs(parties) do
    if partie[kind] then liste[#liste + 1] = couche(partie[kind], kind, i == 1 and teinte or nil) end
  end
end

function M.dress(p, ctx)
  local e = ctx.epoch
  if e == 1 then
    -- Niveau 2 : la pièce e01 SOUS le four vanilla (principale et ombre en tête des couches) ; ses lanternes en halo de
    -- nuit (draw_as_light, la lueur de l'âge 1 n'existe que la nuit).
    local avant = {}
    couches(avant, { SPR.ages[1].piece }, "main")
    couches(avant, { SPR.ages[1].piece }, "shadow")
    for i = #avant, 1, -1 do table.insert(p.animation.layers, 1, avant[i]) end
    local l = {}
    couches(l, { SPR.ages[1].piece }, "light")
    for _, c in ipairs(l) do p.animation.layers[#p.animation.layers + 1] = c end
    return
  end
  local age = SPR.ages[e]
  assert(age, "furnace.lua : âge " .. e .. " absent de graphics/levels/four/sprites.lua")
  local parties = ctx.step == 2 and { age.socle, age.piece } or { age.socle }
  local teinte = ctx.step == 2 and age.teinte or nil
  local corps = {}
  couches(corps, parties, "main", teinte)
  couches(corps, parties, "shadow")
  p.animation = { layers = corps }
  local lueur, halo = {}, {}
  couches(lueur, parties, "glow")
  couches(halo, parties, "light")
  -- Flaque de lumière au sol devant la gueule (lumière du moteur, aucune image de plus) : la couche light rendue est
  -- une bande mince (56 à 62 px hr) qui éclaire peu (captures f2-fours de nuit, F2-B) ; la flaque vanilla du four en
  -- acier fait environ 2,4 × 2 tuiles.
  local g, s = age.gueule, ctx.footprint
  local flaque = { intensity = 0.5, size = 2 + 1.7 * s, shift = { g.x, g.y + g.h / 2 + 0.25 * s },
    color = { r = age.foyer[1], g = age.foyer[2], b = age.foyer[3] } }
  local wv = { { animation = feu(age), fadeout = true, effect = "flicker", light = flaque } }
  if #lueur > 0 then wv[#wv + 1] = { animation = { layers = lueur }, fadeout = true } end
  if #halo > 0 then wv[#wv + 1] = { animation = { layers = halo }, fadeout = true, effect = "flicker" } end
  p.working_visualisations = wv
  p.water_reflection = nil
  p.drawing_box = { { age.boite[1][1], age.boite[1][2] }, { age.boite[2][1], age.boite[2][2] } }
  p.map_color = { r = age.map_color[1], g = age.map_color[2], b = age.map_color[3] }
  -- Fumée : la particule vanilla, à la bouche de l'âge (sous-clé « smoke » de energy_source : visuelle).
  local smoke = p.energy_source.smoke
  if smoke and smoke[1] then
    smoke[1].name = age.fumee_nom
    smoke[1].position = { age.fumee.position[1], age.fumee.position[2] }
  end
  -- Reste et explosion agrandis à l'emprise (copies déclarées ; les sources vanilla ne changent pas).
  local f = ctx.footprint / ctx.family.size
  if f ~= 1 then
    p.corpse = ctx.declare("corpse", p.corpse, "restes", function(c) ctx.kit.scale(c.animation, f) end)
    p.dying_explosion = ctx.declare("explosion", p.dying_explosion, "explosion",
      function(c) ctx.kit.scale(c.animations, f) end)
  end
end

--- Icônes : l'icône de l'âge (réduite du four, feuilles.py) à la place de l'icône vanilla teintée ; le numéro du niveau
--- (couches suivantes) reste celui du kit. Âge 1 : icône vanilla.
function M.icons(icons, ctx)
  local age = SPR.ages[ctx.epoch]
  if ctx.epoch == 1 or not age or not age.icone then return icons end
  icons[1] = { icon = age.icone.filename, icon_size = age.icone.icon_size, icon_mipmaps = age.icone.icon_mipmaps }
  return icons
end

return M
