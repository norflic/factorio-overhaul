--[[
  Visuel des niveaux : MITRAILLEUSE (niveaux 2 à 30 ; le niveau 1 est la tourelle vanilla, jamais modifiée).
  Propriétaire : lot V3-b (intégration en jeu : lot A2, 24/10). Interface : en tête de prototypes/levels/common.lua.

  Designs V3-E VALIDÉS par le Directeur Créatif (23/10) ; sprites de production (128 échantillons) mis en feuilles par
  tools/render/pieces/levels/gun_e/feuilles.py dans graphics/levels/gun/ (PNG hors de git, décision D-6 ; définitions :
  graphics/levels/gun/sprites.lua, généré ; contrôle : check_gun_sheets.py).

  Par niveau n (âge e = époque) :
    - n = 2 (âge 1) : mitrailleuse vanilla inchangée, avec la pièce e01 posée SOUS son socle (couches insérées en tête) ;
    - n impair 3 à 29 : socle de l'âge (base_picture) + tête de l'âge ;
    - n pair 4 à 30 : socle + pièce paire de l'âge (couche ajoutée au socle) + tête.
  Tête : RotatedAnimation à 64 directions (lot A3-jeu : feuille 8 × 8, d00 à d63, line_length 8) quand les 64 poses
  de l'âge sont produites et contrôlées, sinon 4 directions (N, E, S, O en colonne, line_length 1 : lot A2) ; le
  nombre de directions et line_length viennent de sprites.lua, âge par âge (feuilles.py) ; apply_projection laissé
  VRAI (F121 : les têtes sont rendues en rotation uniforme dKK), une image ; TOUJOURS LEVÉE (réponse du DC : folded = preparing =
  prepared = attacking = folding = la même image) ; les vitesses (clés de JEU) restent celles de la vanilla : seul le
  nombre d'images change (E67, garde corrigée par INT-GARDE). Éclat de tir : celui de la munition (vanilla).
  Couches : principale (filtrage linéaire), lueur (draw_as_glow, additive), halo (draw_as_light, additive, socle et
  pièce), ombre (draw_as_shadow). Pas de masque de couleur d'équipe (D-4 non tranchée).
  Bouche (E68) : projectile_creation_distance et projectile_center mesurés par âge sur les sprites (sprites.lua,
  « tir » : étalonnage sur la vanilla, feuilles.py ; moindres carrés sur toutes les directions de l'âge, 4 ou 64) ;
  douilles : point vanilla à l'échelle de l'emprise.
  Reste et explosion : copies déclarées (ctx.declare) de celles de la vanilla, agrandies à l'emprise.
  Son du tir (lot S0) : attack_parameters.sound de l'ÈRE de l'âge (ère = (âge − 1) // 3 + 1 : âges 1-3, 4-6, 7-9,
  10-12, 13-15), 4 variations dérivées des 4 tirs vanilla, volume du prototype vanilla (0,4) ; fichiers et liste :
  sound/levels/gun/ (sons.lua généré par tools/sound/sons.py ; volume jamais au-dessus de la vanilla, mesuré).
]]

local SPR = require("__factorio-overhaul__/graphics/levels/gun/sprites")
local SONS = require("__factorio-overhaul__/sound/levels/gun/sons")

local M = {}

--- Son du tir de l'âge : les variations de son ère (même forme que sounds.gun_turret_gunshot de la vanilla).
local function son_tir(age)
  local ere = math.floor((age - 1) / 3) + 1
  local liste = SONS.eres[ere]
  assert(liste and #liste > 0, "gun.lua : ère " .. ere .. " absente de sound/levels/gun/sons.lua")
  local s = {}
  local vol = SONS.volumes and SONS.volumes[ere] or SONS.volume -- par ère depuis S0-suite (marge des rafales)
  for i, f in ipairs(liste) do s[i] = { filename = f, volume = vol } end
  return s
end

-- Drapeaux de chaque couche (même convention que prototypes/vitrine.lua, lot V0b).
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

--- Couche de tête : RotatedAnimation à 64 directions (8 × 8) ou 4 (colonne N, E, S, O), une image ; direction_count
--- et line_length lus dans sprites.lua.
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

local TETE = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation",
  "folding_animation" }

function M.dress(p, ctx)
  local e = ctx.epoch
  -- Son du tir (lot S0) : seul champ sonore touché ; le niveau 1 (vanilla) n'est jamais habillé.
  p.attack_parameters.sound = son_tir(e)
  if e == 1 then
    -- Niveau 2 : la pièce e01 SOUS la mitrailleuse vanilla (couches insérées en tête du socle vanilla).
    local base = p.base_picture
    local avant = {}
    couches_fixes(avant, SPR.ages[1].piece)
    for i = #avant, 1, -1 do table.insert(base.layers, 1, avant[i]) end
    return
  end
  local age = SPR.ages[e]
  assert(age, "gun.lua : âge " .. e .. " absent de graphics/levels/gun/sprites.lua")
  -- Socle ENTIER (principale, lueur, halo, ombre), PUIS la pièce paire au second niveau de l'âge : même ordre que la
  -- composition validée (profil.level_layers = socle puis pièce, compo.compose dans cet ordre) ; la pièce couvre donc
  -- la lueur additive du socle (correction A2 : l'ordre couche par couche posait la lueur du socle sur la pièce).
  local base = {}
  couches_fixes(base, age.socle)
  if ctx.step == 2 then couches_fixes(base, age.piece) end
  p.base_picture = { layers = base }
  -- Tête : la même image pour les 5 animations (tête toujours levée).
  for _, k in ipairs(TETE) do p[k] = tete(age) end
  -- Boîte d'affichage : socle, pièce et toutes les poses de tête (4 ou 64 ; couches principale et lueur), mesurée par
  -- feuilles.py.
  p.drawing_box = { { age.boite[1][1], age.boite[1][2] }, { age.boite[2][1], age.boite[2][2] } }
  -- Points de tir (sous-clés graphiques) : douilles à l'échelle de l'emprise (kit), puis bouche mesurée (E68).
  local f = ctx.footprint / ctx.family.size
  ctx.kit.scale_muzzle(p, f)
  p.attack_parameters.projectile_creation_distance = age.tir.projectile_creation_distance
  p.attack_parameters.projectile_center = { age.tir.projectile_center[1], age.tir.projectile_center[2] }
  -- Reste et explosion agrandis à l'emprise (copies déclarées ; les sources vanilla ne changent pas).
  if f ~= 1 then
    p.corpse = ctx.declare("corpse", p.corpse, "restes", function(c) ctx.kit.scale(c.animation, f) end)
    p.dying_explosion = ctx.declare("explosion", p.dying_explosion, "explosion",
      function(c) ctx.kit.scale(c.animations, f) end)
  end
end

--- Icônes : l'icône de l'âge (socle + tête E, feuilles.py) à la place de l'icône vanilla teintée ; le numéro du
--- niveau (couches suivantes) reste celui du kit. Âge 1 : icône vanilla.
local annonce = false

function M.icons(icons, ctx)
  local age = SPR.ages[ctx.epoch]
  if ctx.epoch == 1 or not age or not age.icone then return icons end
  icons[1] = { icon = age.icone.filename, icon_size = age.icone.icon_size, icon_mipmaps = age.icone.icon_mipmaps }
  if not annonce then
    -- Marqueur du journal lu par tools/autotest/tests/run_d4m.py (F125 : avec ces icônes, l'atlas [icon] peut perdre
    -- « linear-mip-level » en qualité normale, selon le rangement de l'atlas ; toléré seulement si ce marqueur est là).
    annonce = true
    local n = 0
    for e = 2, 15 do if SPR.ages[e] and SPR.ages[e].icone then n = n + 1 end end
    log("[FO-GUN-ICONES] icones d'age de la mitrailleuse chargees : " .. n .. " (graphics/levels/gun, lot A2)")
  end
  return icons
end

return M
