--[[
  Visuel des niveaux : CENTRE DE COMMANDEMENT (15 niveaux = 15 âges) et QG des factions (lot QG-JEU, 1/11).
  Propriétaire : lot QG-JEU. Interface : en tête de prototypes/levels/common.lua.

  Le centre est le vaisseau de départ devenu bâtiment : 16 états, l'ÉPAVE (âge 0) et les âges 1 à 15, validés par la
  direction artistique (fo-logs/2026-11-01_CRITIQUE/VERDICTS-2.md : 14 VALIDE, 2 ÉCARTER dont l'âge 14, qui entre avec
  ses défauts dits) ; sources : fo-logs/2026-10-31_QG (kit vaisseau_o, 64 échantillons), copiées dans
  fo-logs/2026-11-01_QG-JEU/production/sprites. Mis en feuilles par tools/render/pieces/levels/qg_e/feuilles.py dans
  graphics/levels/centre/ (PNG hors de git, décision D-6 ; définitions : graphics/levels/centre/sprites.lua, généré ;
  contrôle : tests/datastage/centre_sheets.lua, dans le harness et levels_test).

  Par niveau n (= âge n) : trois couches du rendu, la principale, l'ombre (couche séparée, plein est, F47) et la lueur
  (draw_as_glow additive, F37) ; boîte de dessin élargie (les masses dépassent l'emprise en hauteur) ; couleur de carte
  et icône de l'âge. Emprise 2 : 1 (shared/levels/config.lua, L.footprints.command, aspect 2) : 8×4 aux âges 1 à 3,
  10×5 aux âges 4 à 6, 12×6 aux âges 7 à 9, 14×7 aux âges 10 à 12, 16×8 aux âges 13 à 15. Nez à droite, une seule
  orientation (un conteneur ne tourne pas).

  L'âge 0 sert deux fois : le prototype fo-command-wreck (l'épave de votre équipe au départ, réparée en niveau 1 ;
  script/levels/centre.lua) et le QG de faction fo-faction-hq (prototypes/faction.lua, 8×4 comme l'épave).
  Aucun progrès visuel n'est revendiqué au-delà du verdict de la direction artistique : les défauts dits (âge 14 :
  nacelle haute sans tuyère lisible, carrelage or et gris) restent.
]]

local SPR = require("__factorio-overhaul__/graphics/levels/centre/sprites")

local M = {}

local function flags(t, kind)
  if kind == "shadow" then
    t.draw_as_shadow = true
  elseif kind == "glow" then
    t.draw_as_glow = true
    t.blend_mode = "additive"
    t.flags = { "linear-minification" }
  else
    t.flags = { "linear-minification" }
  end
  return t
end

--- Couche d'une image : normale 32 px/tuile + hr_version 64 px/tuile (scale 0,5).
local function couche(def, kind)
  local function une(r, hr)
    local t = flags({ filename = r.filename, width = r.width, height = r.height, shift = { r.shift[1], r.shift[2] },
      priority = "high", frame_count = 1 }, kind)
    if hr then t.scale = 0.5 end
    return t
  end
  local s = une(def.lr, false)
  s.hr_version = une(def.hr, true)
  return s
end

local function age_of(age)
  local a = SPR.ages[age]
  assert(a, "command.lua : âge " .. age .. " absent de graphics/levels/centre/sprites.lua")
  return a
end

--- Image du bâtiment de l'âge `age` (0 = l'épave) : principale, ombre, lueur.
function M.picture(age)
  local a = age_of(age)
  local layers = { couche(a.main, "main") }
  if a.shadow then layers[#layers + 1] = couche(a.shadow, "shadow") end
  if a.glow then layers[#layers + 1] = couche(a.glow, "glow") end
  return { layers = layers }
end

--- Boîte de dessin (tuiles) de l'âge : l'union des couches.
function M.drawing_box(age)
  local b = age_of(age).boite
  return { { b[1][1], b[1][2] }, { b[2][1], b[2][2] } }
end

function M.map_color(age)
  local c = age_of(age).map_color
  return { r = c[1], g = c[2], b = c[3] }
end

--- Habille le prototype `p` (niveau n du centre = âge n).
function M.dress(p, ctx)
  local age = ctx.level
  p.picture = M.picture(age)
  p.drawing_box = M.drawing_box(age)
  p.map_color = M.map_color(age)
end

--- Icône de l'âge à la place de celle du roboport ; le numéro du niveau (couches suivantes) reste celui du kit.
function M.icons(icons, ctx)
  local a = SPR.ages[ctx.level]
  if not (a and a.icone) then return icons end
  icons[1] = { icon = a.icone.filename, icon_size = a.icone.icon_size, icon_mipmaps = a.icone.icon_mipmaps }
  return icons
end

--- Prototype de l'ÉPAVE du centre (âge 0) : une copie du niveau 1 (même coffre, mêmes boîtes, même groupe de
--- remplacement rapide : la réparation la remplace par le niveau 1 en gardant la place), image de l'épave, ni objet ni
--- plan. `first` : le prototype du niveau 1, déjà habillé.
function M.wreck(first, name)
  local w = table.deepcopy(first)
  w.name = name
  w.localised_name = { "entity-name." .. name }
  w.localised_description = { "entity-description." .. name }
  w.minable = nil
  w.placeable_by = nil
  w.picture = M.picture(0)
  w.drawing_box = M.drawing_box(0)
  w.map_color = M.map_color(0)
  w.flags = { "placeable-player", "player-creation", "not-blueprintable" }
  local a = SPR.ages[0]
  w.icons = { { icon = a.icone.filename, icon_size = a.icone.icon_size, icon_mipmaps = a.icone.icon_mipmaps } }
  w.icon, w.icon_size, w.icon_mipmaps = nil, nil, nil
  return w
end

return M
