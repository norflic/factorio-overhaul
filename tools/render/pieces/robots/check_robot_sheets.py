"""CONTRÔLE DES FEUILLES DES ROBOTS (lot RB-V1) : py -3.9 tools/render/pieces/robots/check_robot_sheets.py [--dest DIR] [--mutants]

Manifeste contre fichiers (sha256), rectangles de sprites.lua contre la taille des images, aucune image vide en couche principale, origine
de l'entité dans la case, image la plus grande sous 8 192 px (F144). --mutants : chaque défaut injecté sur une copie doit être refusé.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
DEST_DEFAUT = os.path.join(MOD, "graphics", "robots")


def lire_table(dest):
    """Lit sprites.lua par motif (le format est celui de feuilles.py) : anim, couche, w, h, fichier hr, lr."""
    txt = open(os.path.join(dest, "sprites.lua"), encoding="utf-8").read()
    out = []
    for m in re.finditer(r'(glow|main|mask|shadow) = \{\s*h = (\d+),\s*hr = "[^"]*/([^"/]+)",\s*lh = (\d+),\s*lr = "[^"]*/([^"/]+)",\s*lw = (\d+),\s*shift = \{ ([-\d.]+), ([-\d.]+) \},\s*w = (\d+),', txt):
        out.append({"couche": m.group(1), "h": int(m.group(2)), "hr": m.group(3), "lh": int(m.group(4)), "lr": m.group(5), "lw": int(m.group(6)),
                    "sx": float(m.group(7)), "sy": float(m.group(8)), "w": int(m.group(9))})
    return out


def controle(dest):
    err = []
    man = json.load(open(os.path.join(dest, "MANIFEST.json"), encoding="utf-8"))
    for n, s in sorted(man["fichiers"].items()):
        p = os.path.join(dest, n)
        if not os.path.isfile(p):
            err.append("manquant : " + n)
        elif hashlib.sha256(open(p, "rb").read()).hexdigest() != s:
            err.append("sha256 : " + n)
    if err:
        return err
    tab = lire_table(dest)
    if not tab:
        err.append("sprites.lua : aucune couche lue")
    for t in tab:
        run = "-run-" in t["hr"]
        col, lig = (8, 16) if run else (8, 4)
        for f, w, h in ((t["hr"], t["w"], t["h"]), (t["lr"], t["lw"], t["lh"])):
            im = Image.open(os.path.join(dest, f))
            if im.size != (col * w, lig * h):
                err.append("%s : %s au lieu de %d × %d cases de %d × %d" % (f, im.size, col, lig, w, h))
            if max(im.size) > 8192:
                err.append("%s : plus de 8 192 px" % f)
        if t["couche"] == "main":
            a = np.asarray(Image.open(os.path.join(dest, t["hr"])).convert("RGBA"))[..., 3]
            for r in range(lig):
                for c in range(col):
                    if (a[r * t["h"]:(r + 1) * t["h"], c * t["w"]:(c + 1) * t["w"]] > 128).sum() < 200:
                        err.append("%s : image %d, %d presque vide" % (t["hr"], r, c))
            # l'origine de l'entité dans la case (px HR)
            ox, oy = t["w"] / 2.0 - t["sx"] * 64.0, t["h"] / 2.0 - t["sy"] * 64.0
            if not (0 <= ox <= t["w"] and 0 <= oy <= t["h"]):
                err.append("%s : origine hors de la case" % t["hr"])
    return err


def mutants(dest):
    ok = 0
    tests = []

    def m_sha(d):
        f = sorted(x for x in os.listdir(d) if x.endswith(".png"))[0]
        Image.open(os.path.join(d, f)).convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(d, f))

    def m_manquant(d):
        os.remove(os.path.join(d, sorted(x for x in os.listdir(d) if x.endswith(".png"))[0]))

    def m_case(d):
        p = os.path.join(d, "sprites.lua")
        s = open(p, encoding="utf-8").read()
        s2 = re.sub(r"(main = \{\s*h = )(\d+)", lambda m: m.group(1) + str(int(m.group(2)) + 4), s, count=1)
        assert s != s2
        open(p, "w", encoding="utf-8", newline="\n").write(s2)

    def m_vide(d):
        p = os.path.join(d, "hr-trotte-run-main.png")
        im = Image.open(p).convert("RGBA")
        arr = np.asarray(im).copy()
        arr[:arr.shape[0] // 16, :arr.shape[1] // 8, 3] = 0
        Image.fromarray(arr, "RGBA").save(p)
        man = json.load(open(os.path.join(d, "MANIFEST.json"), encoding="utf-8"))
        man["fichiers"]["hr-trotte-run-main.png"] = hashlib.sha256(open(p, "rb").read()).hexdigest()
        json.dump(man, open(os.path.join(d, "MANIFEST.json"), "w", encoding="utf-8"))

    def m_origine(d):
        p = os.path.join(d, "sprites.lua")
        s = open(p, encoding="utf-8").read()
        s2 = re.sub(r"(main = \{[^}]*?shift = \{ )([-\d.]+)", lambda m: m.group(1) + "40", s, count=1, flags=re.S)
        assert s != s2
        open(p, "w", encoding="utf-8", newline="\n").write(s2)
    tests = [("image changée", m_sha), ("fichier manquant", m_manquant), ("case fausse", m_case), ("image vide", m_vide), ("origine hors de la case", m_origine)]
    for nom, fn in tests:
        t = tempfile.mkdtemp(prefix="rbm_")
        d = os.path.join(t, "r")
        shutil.copytree(dest, d)
        fn(d)
        e = controle(d)
        shutil.rmtree(t)
        if e:
            ok += 1
        else:
            print("MUTANT NON VU :", nom)
    return ok, len(tests)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--mutants", action="store_true")
    a = ap.parse_args()
    if not os.path.isfile(os.path.join(a.dest, "MANIFEST.json")):
        print("[FO-CHECK-ROBOTS] feuilles absentes : py -3.9 tools/render/pieces/robots/feuilles.py")
        return 1
    err = controle(a.dest)
    for e in err[:30]:
        print("ECHEC :", e)
    tab = lire_table(a.dest)
    res = "[FO-CHECK-ROBOTS] BILAN : %d couche(s), %d erreur(s)" % (len(tab), len(err))
    if a.mutants:
        ok, n = mutants(a.dest)
        res += " ; mutants %d/%d refusés" % (ok, n)
        err += [""] * (n - ok)
    print(res)
    return 1 if err else 0


if __name__ == "__main__":
    sys.exit(main())
