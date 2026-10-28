"""Lot IA-G (27/10) : COPIE JETABLE du mod aux DONNÉES CHANGÉES, preuve de généralisation du cerveau général.

    py -3.9 tools/autotest/iag/jetable.py --dest <dossier neuf, hors du dépôt> [--src <racine du mod>]

1. Recopie la source du mod (par défaut : la racine de ce dépôt ou de ce worktree) dans --dest, sans .git, .claude,
   tools/render ni __pycache__ (mêmes exclusions que fo-autotest.bat ; les feuilles hors de git sont COPIÉES).
2. Y ajoute iag_jetable_data.lua et l'appelle dans data-final-fixes.lua AVANT les recettes par lots (MOD-2) :
     a. l'engrenage demande aussi une plaque de cuivre ;
     b. le pack rouge demande une brique au lieu de la plaque de cuivre (une ressource, la pierre, nécessaire plus tôt) ;
     c. la technologie du pack vert exige désormais « logistics » (un prérequis change).
   Aucune ligne du code du cerveau ne change : seules les DONNÉES des prototypes changent.
Le banc se lance ensuite sur cette copie (scénario iag-jetable). Le mod livré n'est jamais modifié.
"""
import argparse
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
EXCLUS = {".git", ".claude", "__pycache__"}

DATA = r'''--[[
  Lot IA-G : DONNÉES CHANGÉES de la copie jetable (tools/autotest/iag/jetable.py). Appelé par data-final-fixes.lua
  avant prototypes.lots. Ne sert qu'à prouver que le cerveau général lit l'arbre d'avancement dans les prototypes.
]]
local function each_ingredients(recipe, fn)
  if recipe.ingredients then fn(recipe.ingredients) end
  if recipe.normal and recipe.normal.ingredients then fn(recipe.normal.ingredients) end
  if recipe.expensive and recipe.expensive.ingredients then fn(recipe.expensive.ingredients) end
end
local function name_of(i) return i.name or i[1] end
local function set_name(i, n) if i.name then i.name = n else i[1] = n end end

-- a. L'engrenage demande aussi une plaque de cuivre.
each_ingredients(data.raw.recipe["iron-gear-wheel"], function(list)
  list[#list + 1] = { type = "item", name = "copper-plate", amount = 1 }
end)
-- b. Le pack rouge : une brique au lieu de la plaque de cuivre.
each_ingredients(data.raw.recipe["automation-science-pack"], function(list)
  for _, i in ipairs(list) do if name_of(i) == "copper-plate" then set_name(i, "stone-brick") end end
end)
-- c. La technologie du pack vert exige « logistics ».
local t = data.raw.technology["logistic-science-pack"]
t.prerequisites = t.prerequisites or {}
table.insert(t.prerequisites, "logistics")
log("[FO-IAG-JETABLE] donnees changees : engrenage + cuivre, pack rouge a la brique, pack vert apres logistics")
'''

# Variante « fort » (lot GENERAL, 28/10) : les trois changements ci-dessus, plus quatre qui touchent l'électrification, la
# recherche et l'armée (les décisions du cerveau qui ne passent pas par le pack rouge ou vert).
DATA_FORT = r'''
-- d. Le laboratoire demande 5 briques de plus (la pierre devient nécessaire avant toute recherche).
each_ingredients(data.raw.recipe["lab"], function(list)
  list[#list + 1] = { type = "item", name = "stone-brick", amount = 5 }
end)
-- e. La foreuse électrique demande 2 briques de plus (l'électrification des factions passe par la pierre).
each_ingredients(data.raw.recipe["electric-mining-drill"], function(list)
  list[#list + 1] = { type = "item", name = "stone-brick", amount = 2 }
end)
-- f. Le chargeur : 3 plaques de fer et 1 plaque de cuivre au lieu de 4 plaques de fer (la munition change de ressource).
each_ingredients(data.raw.recipe["firearm-magazine"], function(list)
  for _, i in ipairs(list) do if name_of(i) == "iron-plate" then if i.name then i.amount = 3 else i[2] = 3 end end end
  list[#list + 1] = { type = "item", name = "copper-plate", amount = 1 }
end)
-- g. Technologies : « automation » coûte 25 packs au lieu de 10 ; « logistics » exige « automation ».
local function unit_of(tech) return tech.unit or (tech.normal and tech.normal.unit) end
local ta = data.raw.technology["automation"]
if unit_of(ta) then unit_of(ta).count = 25 end
local tl = data.raw.technology["logistics"]
tl.prerequisites = tl.prerequisites or {}
table.insert(tl.prerequisites, "automation")
log("[FO-IAG-JETABLE] variante fort : laboratoire + brique, foreuse electrique + brique, chargeur au cuivre, automation 25 packs, logistics apres automation")
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--src", default=MOD)
    ap.add_argument("--variante", choices=("base", "fort"), default="base",
                    help="base : trois changements (lot IA-G) ; fort : sept changements (lot GENERAL)")
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
    with open(os.path.join(dest, "iag_jetable_data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(DATA + (DATA_FORT if a.variante == "fort" else ""))
    dff = os.path.join(dest, "data-final-fixes.lua")
    with open(dff, "r", encoding="utf-8") as f:
        s = f.read()
    marque = 'require("prototypes.lots")'
    if s.count(marque) != 1:
        raise SystemExit("data-final-fixes.lua : %s introuvable ou en double" % marque)
    s = s.replace(marque, 'require("iag_jetable_data") -- lot IA-G : copie jetable\n' + marque)
    with open(dff, "w", encoding="utf-8", newline="\n") as f:
        f.write(s)
    print("[IAG-JETABLE] copie : %s (variante %s ; donnees changees : engrenage + cuivre, pack rouge a la brique, pack vert apres logistics%s)"
          % (dest, a.variante, " ; laboratoire + brique, foreuse electrique + brique, chargeur au cuivre, automation 25 packs, logistics apres automation" if a.variante == "fort" else ""))


if __name__ == "__main__":
    main()
