--[[
  Visuel des niveaux : TOURELLE LASER (niveaux 2 à 30 ; le niveau 1 est la tourelle vanilla, jamais modifiée).
  Propriétaire : lot F1-C (4/11 ; avant : visuel provisoire du lot V2, rejeté en E25). Interface : en tête de
  prototypes/levels/common.lua.

  Designs F1-C VALIDÉS par le Directeur Créatif (QCM-4/11-LASER-F1C, « Valider, lancer la production ») ; sprites de
  production (128 échantillons, ombre des têtes à 32 : D-7) mis en feuilles par tools/render/pieces/levels/laser_e/feuilles.py
  dans graphics/levels/laser/ (PNG hors de git, décision D-6 ; définitions : graphics/levels/laser/sprites.lua, généré ;
  contrôle : check_laser_sheets.py et le harnais de l'étape data).

  Par niveau n (âge e = époque) :
    - n = 2 (âge 1) : laser vanilla inchangé, avec la pièce e01 posée SOUS son socle (couches insérées en tête) ;
    - n impair 3 à 29 : socle de l'âge (base_picture) + tête de l'âge ;
    - n pair 4 à 30 : socle + pièce paire de l'âge (couche ajoutée au socle) + tête.
  Tête : RotatedAnimation de 64 ou 32 directions selon l'âge (sprites.lua, direction_count et line_length 8), une image,
  apply_projection laissé VRAI (F121 : têtes rendues en rotation uniforme dKK) ; TOUJOURS LEVÉE, comme la mitrailleuse
  (folded = preparing = prepared = folding = la même image ; les vitesses, clés de JEU, restent celles de la vanilla : seul le
  nombre d'images change, E67). La lueur de la vanilla (energy_glow_animation, dessinée pour SA tête) est retirée : la lueur
  de l'âge est une couche de la tête.
  Couches : principale (filtrage linéaire), lueur (draw_as_glow, additive), halo (draw_as_light, additive, socle et
  pièce), ombre (draw_as_shadow). Pas de masque de couleur d'équipe (D-4 non tranchée).
  Faisceau : celui du lot TIRS (shared/tirs/ages.lua, champ `laser` : copie déclarée de laser-beam teintée et épaissie) ;
  il part de la BOUCHE de l'âge, mesurée sur la géométrie de la tête (tools/render/pieces/levels/laser_e/bouches.py) :
  attack_parameters.source_offset = {0, −L} (tourné avec la tête, source_direction_count vanilla 64) et
  action_delivery.source_offset = {0, −H} (hauteur à l'écran) ; sous-clés graphiques (common.lua, VISUAL_SUBKEYS).
  Reste et explosion : copies déclarées (ctx.declare) de celles de la vanilla, agrandies à l'emprise.
]]

local SPR = require("__factorio-overhaul__/graphics/levels/laser/sprites")
-- Lot TIRS (27/10) : faisceau de l'âge (table shared/tirs/ages.lua, champ `laser`).
local TIRS = require("shared.tirs.ages")
local TK = require("prototypes.tirs_kit")

local M = {}

-- Drapeaux de chaque couche (même convention que prototypes/levels/gun.lua).
local function flags_couche(t, kind)
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

--- Couche d'une image (socle, pièce) : normale 32 px/tuile + hr_version 64 px/tuile (scale 0,5).
local function couche_fixe(def, kind)
  local lr, hr = def.lr, def.hr
  local s = flags_couche({ filename = lr.filename, width = lr.width, height = lr.height,
    shift = { lr.shift[1], lr.shift[2] }, priority = "medium" }, kind)
  s.hr_version = flags_couche({ filename = hr.filename, width = hr.width, height = hr.height,
    shift = { hr.shift[1], hr.shift[2] }, scale = 0.5, priority = "medium" }, kind)
  return s
end

--- Couche de tête : RotatedAnimation de direction_count images rangées par line_length, une image par direction.
local function couche_tete(def, kind)
  local function une(r, hr)
    local t = flags_couche({ filename = r.filename, width = r.width, height = r.height,
      shift = { r.shift[1], r.shift[2] }, direction_count = r.direction_count, line_length = r.line_length,
      frame_count = 1, axially_symmetrical = false, priority = "medium" }, kind)
    if hr then t.scale = 0.5 end
    return t
  end
  local s = une(def.lr, false)
  s.hr_version = une(def.hr, true)
  return s
end

local ORDRE = { "main", "glow", "light", "shadow" }

local function couches_fixes(liste, partie)
  for _, kind in ipairs(ORDRE) do
    if partie[kind] then liste[#liste + 1] = couche_fixe(partie[kind], kind) end
  end
end

local function tete(age)
  local layers = {}
  for _, kind in ipairs({ "main", "glow", "shadow" }) do
    if age.tete[kind] then layers[#layers + 1] = couche_tete(age.tete[kind], kind) end
  end
  return { layers = layers }
end

local TETE = { "folded_animation", "preparing_animation", "prepared_animation", "folding_animation" }

function M.dress(p, ctx)
  local e = ctx.epoch
  local d = p.attack_parameters.ammo_type.action.action_delivery
  local A = TIRS.ages[e]
  local spec = A and A.laser
  if spec then
    d.beam = ctx.declare("beam", d.beam, "faisceau", function(c) TK.faisceau_blanc(c, spec) end)
  end
  if e == 1 then
    -- Niveau 2 : la pièce e01 SOUS le laser vanilla (couches insérées en tête du socle vanilla).
    local base = p.base_picture
    local avant = {}
    couches_fixes(avant, SPR.ages[1].piece)
    for i = #avant, 1, -1 do table.insert(base.layers, 1, avant[i]) end
    return
  end
  local age = SPR.ages[e]
  assert(age, "laser.lua : âge " .. e .. " absent de graphics/levels/laser/sprites.lua")
  -- Socle entier, puis la pièce paire au second niveau de l'âge (même ordre que la composition validée).
  local base = {}
  couches_fixes(base, age.socle)
  if ctx.step == 2 then couches_fixes(base, age.piece) end
  p.base_picture = { layers = base }
  for _, k in ipairs(TETE) do p[k] = tete(age) end
  p.energy_glow_animation = nil
  p.drawing_box = { { age.boite[1][1], age.boite[1][2] }, { age.boite[2][1], age.boite[2][2] } }
  -- Bouche du faisceau (bouches.py) : portée le long du tir, tournée avec la tête ; hauteur à l'écran.
  p.attack_parameters.source_offset = { age.tir.source_offset[1], age.tir.source_offset[2] }
  d.source_offset = { 0, -age.tir.hauteur }
  -- Reste et explosion agrandis à l'emprise (copies déclarées ; les sources vanilla ne changent pas).
  local f = ctx.footprint / ctx.family.size
  if f ~= 1 then
    p.corpse = ctx.declare("corpse", p.corpse, "restes", function(c) ctx.kit.scale(c.animation, f) end)
    p.dying_explosion = ctx.declare("explosion", p.dying_explosion, "explosion",
      function(c) ctx.kit.scale(c.animations, f) end)
  end
end

--- Icônes : l'icône de l'âge (socle + tête E, feuilles.py) à la place de l'icône vanilla teintée ; le numéro du
--- niveau (couches suivantes) reste celui du kit. Âge 1 : icône vanilla.
function M.icons(icons, ctx)
  local age = SPR.ages[ctx.epoch]
  if ctx.epoch == 1 or not age or not age.icone then return icons end
  icons[1] = { icon = age.icone.filename, icon_size = age.icone.icon_size, icon_mipmaps = age.icone.icon_mipmaps }
  return icons
end

return M
