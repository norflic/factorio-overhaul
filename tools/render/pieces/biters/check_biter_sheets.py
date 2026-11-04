"""Contrôle des feuilles des souches (lot BI-V1) : manifeste, sommes, tailles, cellules, aucun brouillon. Hors jeu.
    PYTHONUTF8=1 py -3.9 -B tools/render/pieces/biters/check_biter_sheets.py [--mutants]
Sans les PNG (worktree neuf, D-6), il imprime la commande qui les refait.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile

from PIL import Image

Image.MAX_IMAGE_PIXELS = None
HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
DIR = os.path.join(MOD, "graphics", "biters")
REGEN = "PYTHONUTF8=1 py -3.9 tools/render/pieces/biters/feuilles.py"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def controle(d):
    """Liste des écarts."""
    e = []
    with open(os.path.join(d, "MANIFEST.json"), encoding="utf-8") as f:
        man = json.load(f)
    if man.get("brouillon"):
        e.append("feuilles de brouillon")
    for nom, x in sorted(man["fichiers"].items()):
        p = os.path.join(d, nom)
        if not os.path.exists(p):
            e.append("manquant : %s (%s)" % (nom, REGEN))
            continue
        if os.path.getsize(p) != x["taille"] or sha(p) != x["sha256"]:
            e.append("somme : " + nom)
        with Image.open(p) as im:
            if list(im.size) != [x["largeur"], x["hauteur"]]:
                e.append("taille : " + nom)
            if max(im.size) > 8192:
                e.append("plus de 8 192 px (F144) : " + nom)
    with open(os.path.join(d, "sprites.lua"), encoding="utf-8") as f:
        lua = f.read()
    # cellule × (images par ligne, lignes) = taille de la feuille
    for anim_images, couches in re.findall(r"(?:course|attaque) = \{ images = (\d+), densite = [\d.]+, reduc = \d+, couches = \{(.*?)\} \},", lua, flags=re.S):
        n = int(anim_images)
        for hr, lr, w, h, lw, lh, ll in re.findall(r'hr = "[^"]*/([^"]+)", lr = "[^"]*/([^"]+)", w = (\d+), h = (\d+), lw = (\d+), lh = (\d+), ll = (\d+)', couches):
            ll = int(ll)
            lignes = (16 * n + ll - 1) // ll
            for nom, cw, ch in ((hr, int(w), int(h)), (lr, int(lw), int(lh))):
                x = man["fichiers"].get(nom)
                if not x or x["largeur"] != cw * ll or x["hauteur"] != ch * lignes:
                    e.append("cellule : " + nom)
    return e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mutants", action="store_true")
    a = ap.parse_args()
    ok = 0
    ec = controle(DIR)
    print(("OK   " if not ec else "ECHEC ") + "feuilles conformes", ec[:6])
    ok += not ec
    ko = len(ec) > 0
    if a.mutants:
        with open(os.path.join(DIR, "MANIFEST.json"), encoding="utf-8") as f:
            man = json.load(f)
        premier = sorted(man["fichiers"])[0]

        def mut_png(d):
            with open(os.path.join(d, premier), "ab") as f:
                f.write(b"x")

        def mut_absent(d):
            os.remove(os.path.join(d, premier))

        def mut_brouillon(d):
            man2 = dict(man, brouillon=True)
            with open(os.path.join(d, "MANIFEST.json"), "w", encoding="utf-8") as f:
                json.dump(man2, f)

        def mut_cellule(d):
            p = os.path.join(d, "sprites.lua")
            with open(p, encoding="utf-8") as f:
                t = f.read()
            with open(p, "w", encoding="utf-8") as f:
                f.write(re.sub(r"w = (\d+),", lambda m: "w = %d," % (int(m.group(1)) + 4), t, count=1))

        for nom, fn in (("PNG modifié", mut_png), ("PNG absent", mut_absent), ("brouillon", mut_brouillon), ("cellule fausse", mut_cellule)):
            t = tempfile.mkdtemp(prefix="biters-")
            try:
                d = os.path.join(t, "b")
                shutil.copytree(DIR, d)
                fn(d)
                refus = len(controle(d)) > 0
                print(("OK   " if refus else "ECHEC ") + "mutant refusé : " + nom)
                ok += refus
                ko = ko or not refus
            finally:
                shutil.rmtree(t, ignore_errors=True)
    print("[BITERS-FEUILLES] BILAN : %d OK, %s" % (ok, "ECHEC" if ko else "0 ECHEC(S)"))
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
