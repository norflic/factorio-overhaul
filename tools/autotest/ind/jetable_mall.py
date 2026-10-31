"""Lot INDUSTRIE I6 (31/10) : COPIE JETABLE du mod avec un MINI-MOD pour le CHOIX DE MALL, preuve « peu importe le mod ».

    py -3.9 tools/autotest/ind/jetable_mall.py --dest <dossier neuf, hors du dépôt> [--src <racine du mod>]

1. Recopie la source du mod (par défaut : la racine de ce dépôt ou de ce worktree) dans --dest, sans .git, .claude,
   tools/render ni __pycache__ (mêmes exclusions que tools/autotest/ind/jetable.py).
2. Y ajoute ind_i6_data.lua et l'appelle dans data-final-fixes.lua AVANT les recettes par lots (MOD-2) :
     a. une catégorie de fabrication neuve « fo-i6-cat » ;
     b. une machine d'assemblage inventée « fo-i6-machine » (copie d'un niveau de l'assembleur du mod : 4 × 4), de cette seule
        catégorie, 6 ingrédients solides au plus, neuf fois plus rapide que l'assembleur de base (la plus rapide du jeu : le bloc la
        choisit) ; sa recette se fabrique à la main (une plaque de fer) ;
     c. trois objets inventés à 2, 3 et 4 entrées solides : « fo-i6-vis » (fer, charbon), « fo-i6-aile » (fer, cuivre, brique),
        « fo-i6-piece » (fer, cuivre, brique, charbon). Leurs quatre matières tiennent sur les 4 voies communes d'un bloc.
   Aucune ligne du code du cerveau ne change : seules les DONNÉES des prototypes changent. Le scénario ind-jetable (fichier
   scenarios/ind_mall_common.lua) détecte la machine inventée et y demande un bloc de mall pour ces trois objets.
Le banc se lance ensuite sur cette copie. Le mod livré n'est jamais modifié.
"""
import argparse
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
EXCLUS = {".git", ".claude", "__pycache__"}

DATA = r'''--[[
  Lot INDUSTRIE I6 : MINI-MOD de la copie jetable (tools/autotest/ind/jetable_mall.py). Appelé par data-final-fixes.lua avant
  prototypes.lots. Une machine inventée de catégorie neuve et trois objets inventés (2, 3 et 4 entrées solides) pour prouver
  que le choix d'un patron ne connaît aucun nom du jeu.
]]
local raw = data.raw

data:extend({ { type = "recipe-category", name = "fo-i6-cat" } })

local function item_like(base, name)
  local it = table.deepcopy(raw.item[base])
  it.name = name
  it.localised_name = name
  it.localised_description = nil
  return it
end

local src = raw["assembling-machine"]["fo-lvl-assembler-7"]
assert(src, "fo-lvl-assembler-7 introuvable : la copie jetable suppose le mod livre")
local m = table.deepcopy(src)
m.name = "fo-i6-machine"
m.crafting_categories = { "fo-i6-cat" }
m.ingredient_count = 6
m.crafting_speed = 9
m.minable = { mining_time = 0.2, result = "fo-i6-machine" }
m.fast_replaceable_group = nil
m.next_upgrade = nil
m.corpse = nil
m.dying_explosion = nil
m.fluid_boxes = nil
m.localised_name = "Machine inventee (I6)"
m.localised_description = nil
data:extend({ m })

local im = item_like("assembling-machine-3", "fo-i6-machine")
im.place_result = "fo-i6-machine"
data:extend({ im, { type = "recipe", name = "fo-i6-machine", enabled = true, energy_required = 1,
  ingredients = { { type = "item", name = "iron-plate", amount = 1 } }, results = { { type = "item", name = "fo-i6-machine", amount = 1 } } } })

local function objet(name, energy, ings)
  local list = {}
  for _, i in ipairs(ings) do list[#list + 1] = { type = "item", name = i[1], amount = i[2] } end
  data:extend({
    item_like("iron-plate", name),
    { type = "recipe", name = name, category = "fo-i6-cat", enabled = true, energy_required = energy, ingredients = list,
      results = { { type = "item", name = name, amount = 1 } } },
  })
end
objet("fo-i6-vis", 1, { { "iron-plate", 1 }, { "coal", 1 } })
objet("fo-i6-aile", 2, { { "iron-plate", 1 }, { "copper-plate", 1 }, { "stone-brick", 1 } })
objet("fo-i6-piece", 3, { { "iron-plate", 2 }, { "copper-plate", 1 }, { "stone-brick", 1 }, { "coal", 1 } })
log("[FO-IND-JETABLE] mini-mod I6 : categorie neuve, machine 4x4, objets a 2, 3 et 4 entrees solides")
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
    with open(os.path.join(dest, "ind_i6_data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(DATA)
    dff = os.path.join(dest, "data-final-fixes.lua")
    with open(dff, "r", encoding="utf-8") as f:
        s = f.read()
    marque = 'require("prototypes.lots")'
    if s.count(marque) != 1:
        raise SystemExit("data-final-fixes.lua : %s introuvable ou en double" % marque)
    s = s.replace(marque, 'require("ind_i6_data") -- lot INDUSTRIE I6 : copie jetable\n' + marque)
    with open(dff, "w", encoding="utf-8", newline="\n") as f:
        f.write(s)
    print("[IND-JETABLE-I6] copie : %s (mini-mod : categorie neuve, machine 4x4 inventee, objets a 2, 3 et 4 entrees)" % dest)


if __name__ == "__main__":
    main()
