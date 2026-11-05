"""Lot DESIGN-MODULES (5/11) : COPIE JETABLE du mod où les MODULES DES GÉANTS sont branchés, pour le micro-banc xpm-grille.

    py -3.9 tools/autotest/xpm/jetable.py --dest <dossier neuf, hors du dépôt> --branche <experimentaux_geants.branche.lua>
                                          [--base <checkout du mod avec ses PNG hors de git>] [--src <ce worktree>]

Le lot ne touche ni data.lua, ni control.lua (fichiers de l'intégrateur), ni script/robots/experimentaux_geants.lua (lot EXPERIMENTAUX).
Cette copie les modifie, elle seule :
1. recopie --base (par défaut le checkout principal du mod, qui porte les PNG hors de git, D-6), sans .git, .claude, tools/render ni
   __pycache__ (exFAT : copie, jamais de lien dur) ;
2. y pose les fichiers de ce lot, pris dans --src (le worktree design-modules) ;
3. ajoute `require("prototypes.experimentaux_modules")` après `require("prototypes.experimentaux")` dans data.lua, et
   `require("script.robots.experimentaux_modules")` après `require("script.robots.experimentaux")` dans control.lua ;
4. remplace script/robots/experimentaux_geants.lua par --branche (le fichier branché proposé au lot EXPERIMENTAUX), seulement si la base
   porte encore le fichier d'origine attendu (empreinte vérifiée), sinon refuse.
Banc : py -3.9 -B tools/autotest/banc.py --out <archive> --qui DESIGN-MODULES -- 2500 xpm-grille "<dest>"
"""
import argparse
import hashlib
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
RACINE = os.path.join("F:" + os.sep, "Factorio.v1.1.91 Modding", "Factorio.v1.1.91")
BASE = os.path.join(RACINE, "mods", "factorio-overhaul")
EXCLUS = {".git", ".claude", "__pycache__"}
FICHIERS = [
    "shared/robots/experimentaux_modules.lua",
    "prototypes/experimentaux_modules.lua",
    "script/robots/experimentaux_modules.lua",
    "locale/fr/experimentaux_modules.cfg",
    "locale/en/experimentaux_modules.cfg",
    "tools/autotest/fo-autotest/scenarios/xpm-grille.lua",
]
DOSSIERS = ["graphics/modules-geants"]


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def inserer(chemin, apres, ligne):
    s = open(chemin, encoding="utf-8", newline="").read()
    if ligne in s:
        return
    i = s.find(apres)
    if i < 0:
        raise SystemExit("ancre absente dans %s : %s" % (chemin, apres))
    j = s.find("\n", i)
    s = s[:j + 1] + ligne + "\n" + s[j + 1:]
    open(chemin, "w", encoding="utf-8", newline="").write(s)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dest", required=True)
    ap.add_argument("--branche", required=True)
    ap.add_argument("--base", default=BASE)
    ap.add_argument("--src", default=SRC)
    a = ap.parse_args()
    dest, base, src = os.path.abspath(a.dest), os.path.abspath(a.base), os.path.abspath(a.src)
    if os.path.exists(dest):
        raise SystemExit("--dest existe déjà (copie jetable : dossier NEUF) : %s" % dest)
    # le fichier branché part du fichier d'origine de --src (même commit de base) : la base doit porter le même
    orig_src = os.path.join(src, "script", "robots", "experimentaux_geants.lua")
    orig_base = os.path.join(base, "script", "robots", "experimentaux_geants.lua")
    if sha(orig_src) != sha(orig_base):
        raise SystemExit("la base ne porte pas le experimentaux_geants.lua d'origine du worktree : branchement refusé")

    def ignorer(d, noms):
        rel = os.path.relpath(d, base).replace(os.sep, "/")
        out = [n for n in noms if n in EXCLUS]
        if rel == "tools" and "render" in noms:
            out.append("render")
        return out
    shutil.copytree(base, dest, ignore=ignorer)
    for rel in FICHIERS:
        p = os.path.join(dest, *rel.split("/"))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        shutil.copyfile(os.path.join(src, *rel.split("/")), p)
    for rel in DOSSIERS:
        d = os.path.join(dest, *rel.split("/"))
        if os.path.exists(d):
            shutil.rmtree(d)
        shutil.copytree(os.path.join(src, *rel.split("/")), d)
    inserer(os.path.join(dest, "data.lua"), 'require("prototypes.experimentaux")', 'require("prototypes.experimentaux_modules") -- COPIE JETABLE DESIGN-MODULES')
    inserer(os.path.join(dest, "control.lua"), 'require("script.robots.experimentaux")',
            'require("script.robots.experimentaux_modules") -- COPIE JETABLE DESIGN-MODULES')
    shutil.copyfile(a.branche, os.path.join(dest, "script", "robots", "experimentaux_geants.lua"))
    print("[XPM-JETABLE] copie prête : %s (base %s, lot %s)" % (dest, base, src))
    return 0


if __name__ == "__main__":
    sys.exit(main())
