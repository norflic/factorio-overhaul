"""Lot INDUSTRIE I4 (31/10) : COPIE JETABLE du mod avec un MINI-MOD inventé, preuve « peu importe le mod ».

    py -3.9 tools/autotest/ind/jetable.py --dest <dossier neuf, hors du dépôt> [--src <racine du mod>]

1. Recopie la source du mod (par défaut : la racine de ce dépôt ou de ce worktree) dans --dest, sans .git, .claude,
   tools/render ni __pycache__ (mêmes exclusions que fo-autotest.bat et tools/autotest/iag/jetable.py).
2. Y ajoute ind_jetable_data.lua et l'appelle dans data-final-fixes.lua AVANT les recettes par lots (MOD-2) :
     a. une catégorie de fabrication neuve « fo-ind-jetable-cat » ;
     b. une machine d'assemblage inventée « fo-ind-jetable-machine » (copie d'un niveau de l'assembleur du mod : 4 × 4, une
        boîte à fluide d'entrée et une de sortie), de sa catégorie neuve et de trois catégories du jeu, 4 ingrédients solides au plus ;
     c. un objet inventé « fo-ind-jetable-noyau » à 3 ingrédients solides et 1 fluide, fabriqué dans cette machine ;
     d. un bras inventé « fo-ind-jetable-bras » (copie du bras de base, une plaque de fer), le moins cher du kit.
   Aucune ligne du code du cerveau ne change : seules les DONNÉES des prototypes changent. L'attendu (scénario ind-lecture)
   est écrit dans tools/autotest/fo-autotest/scenarios/ind-lecture.lua (section 6).
Le banc se lance ensuite sur cette copie. Le mod livré n'est jamais modifié.
"""
import argparse
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
EXCLUS = {".git", ".claude", "__pycache__"}

DATA = r'''--[[
  Lot INDUSTRIE I4 : MINI-MOD inventé de la copie jetable (tools/autotest/ind/jetable.py). Appelé par data-final-fixes.lua
  avant prototypes.lots. Ne sert qu'à prouver que la lecture générique des machines et des recettes (cat.fab, cat.kit)
  prend un mod qu'elle n'a jamais vu.
]]
local raw = data.raw

-- a. catégorie neuve
data:extend({ { type = "recipe-category", name = "fo-ind-jetable-cat" } })

-- b. machine inventée : copie d'un niveau de l'assembleur du mod (4 x 4, fluid_boxes entrée + sortie)
local src = raw["assembling-machine"]["fo-lvl-assembler-7"]
assert(src, "fo-lvl-assembler-7 introuvable : la copie jetable suppose le mod livré")
local m = table.deepcopy(src)
m.name = "fo-ind-jetable-machine"
-- sa catégorie neuve, plus trois catégories du jeu de base : la machine ne prend alors QUE les recettes à 4 solides au plus et
-- à 1 fluide d'entrée, 1 de sortie (la lecture écarte les autres ; le scénario le contrôle contre le moteur)
m.crafting_categories = { "fo-ind-jetable-cat", "crafting", "advanced-crafting", "crafting-with-fluid" }
m.ingredient_count = 4
m.minable = { mining_time = 0.2, result = "fo-ind-jetable-machine" }
m.fast_replaceable_group = nil
m.next_upgrade = nil
m.corpse = nil
m.dying_explosion = nil
m.localised_name = "Machine inventee"
m.localised_description = nil
data:extend({ m })

local function item_like(base, name)
  local it = table.deepcopy(raw.item[base])
  it.name = name
  it.localised_name = name
  it.localised_description = nil
  return it
end

local im = item_like("assembling-machine-3", "fo-ind-jetable-machine")
im.place_result = "fo-ind-jetable-machine"
data:extend({ im })

-- c. objet inventé : 3 solides + 1 fluide
data:extend({
  item_like("iron-plate", "fo-ind-jetable-noyau"),
  {
    type = "recipe", name = "fo-ind-jetable-noyau", category = "fo-ind-jetable-cat", enabled = true, energy_required = 4,
    ingredients = {
      { type = "item", name = "iron-plate", amount = 2 },
      { type = "item", name = "copper-plate", amount = 1 },
      { type = "item", name = "stone-brick", amount = 1 },
      { type = "fluid", name = "water", amount = 20 },
    },
    results = { { type = "item", name = "fo-ind-jetable-noyau", amount = 1 } },
  },
})
-- la machine inventée se fabrique à la main (comme toute machine posée par le scénario)
data:extend({ { type = "recipe", name = "fo-ind-jetable-machine", enabled = true, energy_required = 1,
  ingredients = { { type = "item", name = "iron-plate", amount = 1 } }, results = { { type = "item", name = "fo-ind-jetable-machine", amount = 1 } } } })

-- d. bras inventé (une plaque de fer : le moins cher du kit)
local bras = table.deepcopy(raw.inserter["inserter"])
bras.name = "fo-ind-jetable-bras"
bras.minable = { mining_time = 0.1, result = "fo-ind-jetable-bras" }
bras.fast_replaceable_group = nil
bras.next_upgrade = nil
bras.localised_name = "Bras invente"
bras.localised_description = nil
data:extend({ bras })
local ib = item_like("inserter", "fo-ind-jetable-bras")
ib.place_result = "fo-ind-jetable-bras"
data:extend({ ib, { type = "recipe", name = "fo-ind-jetable-bras", enabled = true, energy_required = 0.5,
  ingredients = { { type = "item", name = "iron-plate", amount = 1 } }, results = { { type = "item", name = "fo-ind-jetable-bras", amount = 1 } } } })
log("[FO-IND-JETABLE] mini-mod : categorie neuve, machine 4x4, objet a 3 solides et 1 fluide, bras inventé")
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
    with open(os.path.join(dest, "ind_jetable_data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(DATA)
    dff = os.path.join(dest, "data-final-fixes.lua")
    with open(dff, "r", encoding="utf-8") as f:
        s = f.read()
    marque = 'require("prototypes.lots")'
    if s.count(marque) != 1:
        raise SystemExit("data-final-fixes.lua : %s introuvable ou en double" % marque)
    s = s.replace(marque, 'require("ind_jetable_data") -- lot INDUSTRIE I4 : copie jetable\n' + marque)
    with open(dff, "w", encoding="utf-8", newline="\n") as f:
        f.write(s)
    print("[IND-JETABLE] copie : %s (mini-mod : categorie neuve, machine 4x4 inventee, objet a 3 solides et 1 fluide, bras inventé)" % dest)


if __name__ == "__main__":
    main()
