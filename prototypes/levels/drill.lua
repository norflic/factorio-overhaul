--[[
  Visuel des niveaux : FOREUSE ÉLECTRIQUE (niveaux 2 à 30 ; le niveau 1 est la foreuse vanilla, jamais modifiée).
  Propriétaire : lot F4 (design F4-A, rondes F4-A2 à F4-A4 ; intégration F4-B, 27/10). Interface : en tête de
  prototypes/levels/common.lua.

  Mise en jeu décidée par l'intégrateur SANS verdict du DC sur les planches (direction du DC : « Oui, enrichir
  nettement », R-QCM-25h), pour sortir la foreuse du « seule la teinte change » banni le 25/10 ; choix PROVISOIRE et
  réversible. Sprites de production mis en feuilles par tools/render/pieces/levels/foreuse_e/feuilles.py dans
  graphics/levels/foreuse/ (PNG hors de git, décision D-6 ; définitions : graphics/levels/foreuse/sprites.lua, généré ;
  contrôle : tests/datastage/drill_sheets.lua, dans le harness et levels_test). Fiches et notes : fo-logs/2026-10-25_F4.

  Par niveau n (âge e = époque), dans les 4 directions (graphics_set ET wet_mining_graphics_set) :
    - n = 2 (âge 1) : foreuse vanilla inchangée (animations, tête de forage), avec la pièce e01 (chèvre de bois, lanterne
      sur sa potence) posée PAR-DESSUS, la même dans les 4 directions ; sa lanterne en halo de nuit ;
    - n impair 3 à 29 : la foreuse de l'âge tournée vers la direction (couches principale, ombre, lueur draw_as_glow, halo
      de nuit draw_as_light) ;
    - n pair 4 à 30 : la même, TEINTÉE (epoques.TEINTE_PAIR : 0,78 + 0,22 × la lumière de l'âge), plus la pièce paire au
      sommet de la tour (une image pour les 4 directions).
  Travail au MOINDRE COÛT (aucune image de plus en mémoire vidéo) : la lueur de l'âge rejouée en working_visualisations
  (fadeout, « flicker ») et une lumière dynamique de la couleur de l'âge, sans image. La tête de forage vanilla animée
  n'est plus dessinée aux niveaux 3 à 30 (la tour de l'âge la remplace).
  Points de jeu : ceux de la règle des points (shared/levels/points.lua) ; la goulotte et les brides DESSINÉES y sont
  (foreuse_e/corps.py, tests/test_foreuse.py). Reste et explosion : copies déclarées, agrandies à l'emprise. Couleur de
  carte et icône : celles de l'âge (corps N).
]]

local SPR = require("__factorio-overhaul__/graphics/levels/foreuse/sprites")

local M = {}

local DIRS = { north = "N", east = "E", south = "S", west = "O" }
local DIR_ORDER = { "north", "east", "south", "west" }

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
--- niveau pair ; `repeat_count` : couche fixe ajoutée à une animation vanilla de N images.
local function couche(def, kind, teinte, repeat_count)
  local function une(r, hr)
    local t = flags({ filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] },
      priority = "medium", frame_count = 1 }, kind)
    if repeat_count then t.repeat_count = repeat_count end
    if hr then t.scale = 0.5 end
    if teinte then t.tint = { r = teinte[1], g = teinte[2], b = teinte[3], a = 1 } end
    return t
  end
  local s = une(def.lr, false)
  s.hr_version = une(def.hr, true)
  return s
end

local function couches(liste, parties, kind, teinte, repeat_count)
  for i, partie in ipairs(parties) do
    if partie[kind] then
      liste[#liste + 1] = couche(partie[kind], kind, i == 1 and teinte or nil, repeat_count)
    end
  end
end

--- Nombre d'images de l'animation vanilla d'une direction (première couche), pour répéter une couche fixe ajoutée.
local function images(anim)
  local l = anim and (anim.layers and anim.layers[1] or anim)
  return (l and l.frame_count or 1) * (l and l.repeat_count or 1)
end

--- Âge 1 (niveau 2) : la pièce e01 PAR-DESSUS l'animation vanilla de chaque direction.
local function age1(gs)
  if not (gs and gs.animation) then return end
  local piece = SPR.ages[1].piece
  for _, d in ipairs(DIR_ORDER) do
    local anim = gs.animation[d]
    if anim then
      if not anim.layers then
        local l = anim
        anim = { layers = { l } }
        gs.animation[d] = anim
      end
      local n = images(anim)
      local apres = {}
      couches(apres, { piece }, "main", nil, n)
      couches(apres, { piece }, "shadow", nil, n)
      couches(apres, { piece }, "light", nil, n)
      for _, c in ipairs(apres) do anim.layers[#anim.layers + 1] = c end
    end
  end
end

--- Jeu de graphismes de l'âge e (niveau impair : step 1 ; pair : step 2, teinte et pièce).
local function jeu(e, step, footprint)
  local age = SPR.ages[e]
  assert(age, "drill.lua : âge " .. e .. " absent de graphics/levels/foreuse/sprites.lua")
  local teinte = step == 2 and age.teinte or nil
  local animation, glow = {}, {}
  for _, d in ipairs(DIR_ORDER) do
    local parties = step == 2 and { age[DIRS[d]], age.piece } or { age[DIRS[d]] }
    local corps = {}
    couches(corps, parties, "main", teinte)
    couches(corps, parties, "shadow")
    couches(corps, parties, "glow")
    couches(corps, parties, "light")
    animation[d] = { layers = corps }
    local lueur = {}
    couches(lueur, parties, "glow")
    glow[d] = #lueur > 0 and { layers = lueur } or nil
  end
  local f = age.foyer
  local wv = {}
  if glow.north then
    wv[#wv + 1] = { fadeout = true, effect = "flicker", north_animation = glow.north, east_animation = glow.east,
      south_animation = glow.south, west_animation = glow.west }
  end
  wv[#wv + 1] = { light = { intensity = 0.45, size = 1.5 * footprint, color = { r = f[1], g = f[2], b = f[3] } },
    fadeout = true }
  return { animation = animation, working_visualisations = wv }
end

function M.dress(p, ctx)
  local e = ctx.epoch
  if e == 1 then
    -- Niveau 2 : la pièce e01 PAR-DESSUS la foreuse vanilla, dans les 4 directions, sèche et humide.
    age1(p.graphics_set)
    age1(p.wet_mining_graphics_set)
    return
  end
  local age = SPR.ages[e]
  assert(age, "drill.lua : âge " .. e .. " absent de graphics/levels/foreuse/sprites.lua")
  -- Graphismes de l'âge, secs et humides (fluide de minage) : la même foreuse (le fluide passe par les brides).
  p.graphics_set = jeu(e, ctx.step, ctx.footprint)
  p.wet_mining_graphics_set = jeu(e, ctx.step, ctx.footprint)
  p.drawing_box = { { age.boite[1][1], age.boite[1][2] }, { age.boite[2][1], age.boite[2][2] } }
  p.map_color = { r = age.map_color[1], g = age.map_color[2], b = age.map_color[3] }
  -- Reste et explosion agrandis à l'emprise (copies déclarées ; les sources vanilla ne changent pas).
  local k = ctx.footprint / ctx.family.size
  if k ~= 1 then
    p.corpse = ctx.declare("corpse", p.corpse, "restes", function(c) ctx.kit.scale(c.animation, k) end)
    p.dying_explosion = ctx.declare("explosion", p.dying_explosion, "explosion",
      function(c) ctx.kit.scale(c.animations, k) end)
  end
end

--- Icônes : l'icône de l'âge (réduite du corps N, feuilles.py) à la place de l'icône vanilla teintée ; le numéro du
--- niveau (couches suivantes) reste celui du kit. Âge 1 : icône vanilla.
function M.icons(icons, ctx)
  local age = SPR.ages[ctx.epoch]
  if ctx.epoch == 1 or not age or not age.icone then return icons end
  icons[1] = { icon = age.icone.filename, icon_size = age.icone.icon_size, icon_mipmaps = age.icone.icon_mipmaps }
  return icons
end

return M
