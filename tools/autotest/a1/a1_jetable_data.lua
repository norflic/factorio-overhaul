-- Lot A1 (23/10), expériences E67 et E70 : prototypes de TEST, chargés SEULEMENT par la copie jetable du mod que
-- fabrique tools/autotest/a1/jetable.py (ce fichier y est recopié à la racine et appelé en fin de
-- data-final-fixes.lua). JAMAIS dans le mod livré.
--
-- E67 (durée réelle de preparing) : copies de la mitrailleuse vanilla qui ne diffèrent QUE par l'animation de levée
-- (preparing_animation) et sa vitesse. Prédictions pour la durée de la levée, en ticks :
--   nom                 images  repeat  vitesse   doc 1.1.91 (1 / vitesse)   garde du kit (images x repeat / vitesse)
--   a1-e67-v5             5       1      0,08          12,5                          62,5
--   a1-e67-i1             1       1      0,08          12,5                          12,5
--   a1-e67-r5             1       5      0,08          12,5                          62,5
--   a1-e67-i1-lent        1       1      0,016         62,5                          62,5
--   a1-e67-v5-lent        5       1      0,016         62,5                         312,5
--
-- E70 (orientation imposée par shooting_target ; origine et sens des directions) : a1-e70-fleche, mitrailleuse
-- dont la tête levée (prepared et attacking) est une FLÈCHE NUMÉROTÉE en 64 directions (image k : flèche tournée de
-- k x 360/64 degrés dans le sens horaire depuis le haut, numéro k écrit dessus, en ROUGE), et dont la tête repliée
-- (folded, preparing, folding) est la même flèche en BLEU. Sur une capture, la couleur dit l'état (levée ou repliée)
-- et le numéro dit quelle image le moteur dessine pour l'orientation de la tête.

local base = data.raw["ammo-turret"]["gun-turret"]

local function copie(nom)
  local t = table.deepcopy(base)
  t.name = nom
  t.localised_name = { "", nom }
  t.minable = nil
  t.placeable_by = nil
  t.fast_replaceable_group = nil
  t.next_upgrade = nil
  -- vitesses vanilla écrites en clair (le mod pourrait avoir touché à la mitrailleuse vanilla)
  t.rotation_speed = 0.015
  t.preparing_speed = 0.08
  t.folding_speed = 0.08
  t.attacking_speed = 0.5
  return t
end

-- Couches de levée à UNE image (celles de folded_animation vanilla), avec repeat_count facultatif.
local function une_image(repeat_count)
  local a = table.deepcopy(base.folded_animation)
  if repeat_count then
    for _, l in ipairs(a.layers) do
      l.repeat_count = repeat_count
      if l.hr_version then l.hr_version.repeat_count = repeat_count end
    end
  end
  return a
end

local protos = {}

local v5 = copie("a1-e67-v5")
protos[#protos + 1] = v5

local i1 = copie("a1-e67-i1")
i1.preparing_animation = une_image()
protos[#protos + 1] = i1

local r5 = copie("a1-e67-r5")
r5.preparing_animation = une_image(5)
protos[#protos + 1] = r5

local i1l = copie("a1-e67-i1-lent")
i1l.preparing_animation = une_image()
i1l.preparing_speed = 0.016
protos[#protos + 1] = i1l

local v5l = copie("a1-e67-v5-lent")
v5l.preparing_speed = 0.016
protos[#protos + 1] = v5l

-- E70 : flèches numérotées
local FLECHES = {
  filename = "__factorio-overhaul__/graphics/a1/fleches-64.png",
  priority = "medium",
  width = 128,
  height = 128,
  direction_count = 64,
  frame_count = 1,
  line_length = 8,
  axially_symmetrical = false,
  shift = { 0, -0.75 },
  scale = 0.5,
}
-- Tête repliée (folded, preparing, folding) : les MÊMES flèches en bleu, en 64 directions : une capture dit si le
-- moteur choisit aussi l'image du repli selon l'orientation de la tête (premier passage : carré « REPLI » à une
-- direction, sans réponse à cette question).
local REPLI = table.deepcopy(FLECHES)
REPLI.filename = "__factorio-overhaul__/graphics/a1/fleches-64-repli.png"
local fl = copie("a1-e70-fleche")
fl.prepared_animation = table.deepcopy(FLECHES)
fl.attacking_animation = table.deepcopy(FLECHES)
fl.folded_animation = table.deepcopy(REPLI)
fl.preparing_animation = table.deepcopy(REPLI)
fl.folding_animation = table.deepcopy(REPLI)
fl.base_picture = nil
protos[#protos + 1] = fl

data:extend(protos)
log("[A1-JETABLE] prototypes de test : " .. #protos)
