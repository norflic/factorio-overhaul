"""Lot INDUSTRIE I5 (31/10) : COPIE JETABLE du mod avec les formes que le jeu ne donne pas, preuve des patrons « peu importe le mod ».

    py -3.9 tools/autotest/ind/jetable_patrons.py --dest <dossier neuf, hors du dépôt> [--src <racine du mod>]

1. Recopie la source du mod (par défaut : la racine de ce dépôt ou de ce worktree) dans --dest, sans .git, .claude,
   tools/render ni __pycache__ (mêmes exclusions que tools/autotest/ind/jetable.py).
2. Y ajoute ind_i5_data.lua et l'appelle dans data-final-fixes.lua AVANT les recettes par lots (MOD-2) :
     a. une catégorie de fabrication neuve « fo-i5-cat » ;
     b. une machine d'assemblage inventée « fo-i5-onze » de 11 × 11 (copie d'un niveau de l'assembleur du mod, agrandie, sans boîte
        à fluide), de cette seule catégorie, 8 ingrédients solides au plus ;
     c. des recettes bon marché à 5, 7 et 8 ingrédients solides (une unité de chaque, une seconde) : le jeu n'a aucune recette à 7
        entrées, et sa seule recette à 8 demande 150 objets d'une matière (3 000 ticks ne les livrent pas).
   Aucune ligne du code de la règle ne change : seules les DONNÉES des prototypes changent. Le scénario ind-patrons détecte la
   machine inventée et y joue les formes à 5, 7 et 8 entrées sur une machine de 11 de côté (largeur lue : ROBOTS en a besoin).
Le banc se lance ensuite sur cette copie. Le mod livré n'est jamais modifié.
"""
import argparse
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
EXCLUS = {".git", ".claude", "__pycache__"}

DATA = r'''--[[
  Lot INDUSTRIE I5 : MINI-MOD de la copie jetable (tools/autotest/ind/jetable_patrons.py). Appelé par data-final-fixes.lua avant
  prototypes.lots. Une machine de 11 x 11 et trois recettes (5, 7, 8 ingrédients solides) pour prouver les formes que le jeu
  livré ne permet pas de jouer.
]]
local raw = data.raw

data:extend({ { type = "recipe-category", name = "fo-i5-cat" } })

local function item_like(base, name)
  local it = table.deepcopy(raw.item[base])
  it.name = name
  it.localised_name = name
  it.localised_description = nil
  return it
end

-- machine de 11 x 11 : copie d'un niveau de l'assembleur du mod, agrandie (images à l'échelle, plus de boîte à fluide)
local src = raw["assembling-machine"]["fo-lvl-assembler-19"]
assert(src, "fo-lvl-assembler-19 introuvable : la copie jetable suppose le mod livré")
local m = table.deepcopy(src)
m.name = "fo-i5-onze"
m.crafting_categories = { "fo-i5-cat" }
m.ingredient_count = 8
m.crafting_speed = 1
m.energy_usage = "500kW"
m.collision_box = { { -5.4, -5.4 }, { 5.4, 5.4 } }
m.selection_box = { { -5.5, -5.5 }, { 5.5, 5.5 } }
m.drawing_box = nil
m.tile_width, m.tile_height = 11, 11
m.fluid_boxes = nil
m.fluid_boxes_off_when_no_fluid_recipe = nil
m.minable = { mining_time = 0.2, result = "fo-i5-onze" }
m.fast_replaceable_group = nil
m.next_upgrade = nil
m.corpse = nil
m.dying_explosion = nil
m.localised_name = "Machine de onze"
m.localised_description = nil
local k = 11 / 6
local function scale_layers(a)
  if type(a) ~= "table" then return end
  if a.filename or a.stripes then
    a.scale = (a.scale or 1) * k
    if a.shift then a.shift = { a.shift[1] * k, a.shift[2] * k } end
    if a.hr_version then scale_layers(a.hr_version) end
  end
  if a.layers then for _, l in ipairs(a.layers) do scale_layers(l) end end
  for _, key in ipairs({ "animation", "picture", "idle_animation", "working_visualisations" }) do
    if type(a[key]) == "table" and a[key] ~= a then scale_layers(a[key]) end
  end
end
pcall(scale_layers, m.animation)
data:extend({ m })

local im = item_like("assembling-machine-3", "fo-i5-onze")
im.place_result = "fo-i5-onze"
data:extend({ im })

-- recettes bon marché : une unité de chaque matière, une seconde
local mats = { "iron-plate", "copper-plate", "stone", "coal", "iron-gear-wheel", "copper-cable", "stone-brick", "iron-stick" }
for _, n in ipairs({ 5, 7, 8 }) do
  local ing = {}
  for i = 1, n do ing[i] = { type = "item", name = mats[i], amount = 1 } end
  data:extend({
    item_like("iron-plate", "fo-i5-o" .. n),
    { type = "recipe", name = "fo-i5-r" .. n, category = "fo-i5-cat", enabled = true, energy_required = 1, ingredients = ing,
      results = { { type = "item", name = "fo-i5-o" .. n, amount = 1 } } },
  })
end
-- la machine se fabrique à la main (comme toute machine posée par le scénario)
data:extend({ { type = "recipe", name = "fo-i5-onze", enabled = true, energy_required = 1,
  ingredients = { { type = "item", name = "iron-plate", amount = 1 } }, results = { { type = "item", name = "fo-i5-onze", amount = 1 } } } })
log("[FO-IND-JETABLE-I5] mini-mod : machine de 11 x 11, categorie neuve, recettes a 5, 7 et 8 ingredients solides")
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--src", default=MOD)
    a = ap.parse_args()
    src, dest = os.path.abspath(a.src), os.path.abspath(a.dest)
    if os.path.exists(dest):
        raise SystemExit("--dest existe déjà (copie jetable : dossier NEUF) : %s" % dest)
    if not os.path.exists(os.path.join(src, "info.json")):
        raise SystemExit("source sans info.json : %s" % src)
    render = os.path.join(src, "tools", "render")

    def ignorer(d, noms):
        return [n for n in noms if n in EXCLUS or os.path.join(d, n) == render]

    shutil.copytree(src, dest, ignore=ignorer)
    with open(os.path.join(dest, "ind_i5_data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(DATA)
    dff = os.path.join(dest, "data-final-fixes.lua")
    with open(dff, "r", encoding="utf-8") as f:
        s = f.read()
    marque = 'require("prototypes.lots")'
    if s.count(marque) != 1:
        raise SystemExit("data-final-fixes.lua : %s introuvable ou en double" % marque)
    s = s.replace(marque, 'require("ind_i5_data") -- lot INDUSTRIE I5 : copie jetable\n' + marque)
    with open(dff, "w", encoding="utf-8", newline="\n") as f:
        f.write(s)
    print("[IND-JETABLE-I5] copie : %s (mini-mod : machine 11x11, recettes a 5, 7 et 8 ingredients solides)" % dest)


if __name__ == "__main__":
    main()
