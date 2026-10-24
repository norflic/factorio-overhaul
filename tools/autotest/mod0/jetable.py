"""Lot MOD-0 (24/10) : COPIE JETABLE du mod pour la levée des risques des modules multiplicatifs (scénario greffé
mod0-risques ; expériences E133 à E135).

    py -3.9 tools/autotest/mod0/jetable.py --dest <dossier neuf, hors du dépôt> [--src <racine du mod>]

1. Recopie la source du mod (par défaut : la racine de ce dépôt ou de ce worktree) dans --dest, sans .git, .claude,
   tools/render ni __pycache__ (mêmes exclusions que fo-autotest.bat).
2. Y ajoute mod0_jetable_data.lua (prototypes de test, voir son en-tête) et l'appelle en fin de data-final-fixes.lua.
Le banc se lance ensuite sur cette copie : fo-autotest.bat nopause 1900 mod0-risques "<dest>" (et fo-captures.bat
mod0-risques "<dest>" pour les images de R4 et R6). Le mod livré n'est jamais modifié. Effacer la copie après usage.
"""
import argparse
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
EXCLUS = {".git", ".claude", "__pycache__"}


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
    if os.path.commonpath([src, dest]) == src:
        raise SystemExit("--dest est DANS la source : %s" % dest)
    render = os.path.join(src, "tools", "render")

    def ignorer(d, noms):
        return [n for n in noms if n in EXCLUS or os.path.join(d, n) == render]

    shutil.copytree(src, dest, ignore=ignorer)
    shutil.copy2(os.path.join(HERE, "mod0_jetable_data.lua"), os.path.join(dest, "mod0_jetable_data.lua"))
    dff = os.path.join(dest, "data-final-fixes.lua")
    with open(dff, "ab") as f:
        f.write(b"\n-- COPIE JETABLE du lot MOD-0 (tools/autotest/mod0/jetable.py) : prototypes de test E133 a E135\n"
                b"require(\"mod0_jetable_data\")\n")
    print("copie jetable prête : %s (source %s)" % (dest, src))


if __name__ == "__main__":
    sys.exit(main())
