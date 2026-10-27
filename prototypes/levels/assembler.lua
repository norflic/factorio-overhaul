--[[
  Visuel des niveaux : MACHINE D'ASSEMBLAGE 2 (niveaux 2 à 30 ; le niveau 1 est la machine vanilla, jamais modifiée).
  Propriétaire : lot F3 (design F3-A, rondes F3-A2 et F3-A3 ; intégration F3-B, 25/10). Interface : en tête de
  prototypes/levels/common.lua.

  Designs des 15 âges VALIDÉS par le Directeur Créatif (25/10, R-QCM-25l : « Validé, production ») ; sprites de
  production (128 échantillons, ombre à 32 : D-7) mis en feuilles par tools/render/pieces/levels/assembleur_e/feuilles.py
  dans graphics/levels/assembleur/ (PNG hors de git, décision D-6 ; définitions : graphics/levels/assembleur/sprites.lua,
  généré ; contrôle : tests/datastage/asm_sheets.lua, dans le harness et levels_test). Fiches et notes :
  fo-logs/2026-10-25_F3.

  Par niveau n (âge e = époque) :
    - n = 2 (âge 1) : machine vanilla inchangée (animation de 32 images), avec la pièce e01 (établi, caisses, tourets,
      lanterne) posée PAR-DESSUS aux deux coins avant (couches ajoutées en fin, 1 image répétée 32 fois comme l'ombre
      vanilla) ; sa lanterne en halo de nuit (draw_as_light) ;
    - n impair 3 à 29 : la machine de l'âge (couches principale, ombre, lueur draw_as_glow, halo de nuit draw_as_light) ;
    - n pair 4 à 30 : la même, TEINTÉE (epoques.teinte_pair : 0,8 + 0,2 × la lumière de l'âge), plus la pièce paire.
  Animation de travail au MOINDRE COÛT (aucune image de plus en mémoire vidéo) : la couche de lueur de l'âge est rejouée
  en working_visualisations (fadeout, effet « flicker ») : quand la machine travaille, ses voyants, écrans, braises et
  cristaux s'avivent et scintillent ; une lumière dynamique de la couleur de l'âge s'allume avec eux (sans image).
  Raccords de tuyau : ceux de la vanilla, déplacés par la règle des points (shared/levels/points.lua : x = −0,5 aux
  côtés pairs) ; les brides dessinées sont à ces raccords (assembleur_e/corps.port_x) ; images de raccord vanilla.
  Reste et explosion : copies déclarées (ctx.declare) de celles de la vanilla, agrandies à l'emprise. Couleur de carte :
  couleur moyenne de la machine de l'âge. Icône : celle de l'âge (réduite de la machine), le numéro du niveau reste
  celui du kit.
]]

local SPR = require("__factorio-overhaul__/graphics/levels/assembleur/sprites")

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

--- Nombre d'images de l'animation vanilla (première couche), pour répéter une couche fixe ajoutée.
local function images(anim)
  local l = anim and (anim.layers and anim.layers[1] or anim)
  return (l and l.frame_count or 1) * (l and l.repeat_count or 1)
end

function M.dress(p, ctx)
  local e = ctx.epoch
  if e == 1 then
    -- Niveau 2 : la pièce e01 PAR-DESSUS l'assembleur vanilla (coins avant) ; sa lanterne en halo de nuit.
    local n = images(p.animation)
    local apres = {}
    couches(apres, { SPR.ages[1].piece }, "main", nil, n)
    couches(apres, { SPR.ages[1].piece }, "shadow", nil, n)
    couches(apres, { SPR.ages[1].piece }, "light", nil, n)
    for _, c in ipairs(apres) do p.animation.layers[#p.animation.layers + 1] = c end
    return
  end
  local age = SPR.ages[e]
  assert(age, "assembler.lua : âge " .. e .. " absent de graphics/levels/assembleur/sprites.lua")
  local parties = ctx.step == 2 and { age.machine, age.piece } or { age.machine }
  local teinte = ctx.step == 2 and age.teinte or nil
  local corps = {}
  couches(corps, parties, "main", teinte)
  couches(corps, parties, "shadow")
  couches(corps, parties, "glow")
  couches(corps, parties, "light")
  p.animation = { layers = corps }
  -- Travail : la lueur rejouée (s'avive et scintille), lumière dynamique de l'âge (sans image).
  local lueur = {}
  couches(lueur, parties, "glow")
  local f = age.foyer
  local wv = {}
  if #lueur > 0 then
    wv[#wv + 1] = { animation = { layers = lueur }, fadeout = true, effect = "flicker" }
  end
  wv[#wv + 1] = { light = { intensity = 0.45, size = 1.5 * ctx.footprint, color = { r = f[1], g = f[2], b = f[3] } },
    fadeout = true }
  p.working_visualisations = wv
  p.water_reflection = nil
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

--- Icônes : l'icône de l'âge (réduite de la machine, feuilles.py) à la place de l'icône vanilla teintée ; le numéro du
--- niveau (couches suivantes) reste celui du kit. Âge 1 : icône vanilla.
function M.icons(icons, ctx)
  local age = SPR.ages[ctx.epoch]
  if ctx.epoch == 1 or not age or not age.icone then return icons end
  icons[1] = { icon = age.icone.filename, icon_size = age.icone.icon_size, icon_mipmaps = age.icone.icon_mipmaps }
  return icons
end

return M
