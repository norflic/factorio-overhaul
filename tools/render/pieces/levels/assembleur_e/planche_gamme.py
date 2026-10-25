"""PLANCHES POUR LE DIRECTEUR CRÉATIF (lot F3-A, 25/10). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/assembleur_e/planche_gamme.py --asm DIR [--asm DIR2 …] --dest planche.png
        [--mode ages|gamme] [--ages 1,…,15] [--zoom 1|2] [--nuit] [--pair] [--titre "…"]

mode « ages » : les 15 âges côte à côte, par ère (une ligne par ère), niveau impair (âge 1 : niveau 2), jour ou nuit ;
avec --pair, le niveau pair (pièce comprise) ; mode « gamme » : par âge, la mitrailleuse VALIDÉE (pose E, niveau impair)
puis l'assembleur du même âge, même fenêtre et même échelle (cohérence de gamme : mêmes matières, même lumière ; aucune
confusion). Composé hors moteur (commun/compo.py), sol vanilla. Plusieurs --asm : le premier qui a l'âge.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
sys.path.insert(0, COMMUN)
import compo as K  # noqa: E402

ROOT = K.ROOT + "/fo-logs"
GUN = {e: ROOT + "/2026-10-23_V3E-p5/bas/sprites" for e in range(1, 10)}
GUN.update({e: ROOT + "/2026-10-23_V3E-p5/haut/sprites" for e in (10, 11, 12)})
GUN.update({e: ROOT + "/2026-10-23_V3E-ereV/sprites" for e in (13, 14, 15)})
ERES = [(1, (1, 2, 3)), (2, (4, 5, 6)), (3, (7, 8, 9)), (4, (10, 11, 12)), (5, (13, 14, 15))]


def src_asm(dirs, e):
    pre = "e%02d" % e
    for d in dirs:
        if os.path.isdir(d) and any(n.startswith(pre + "-") for n in os.listdir(d)):
            return d
    return dirs[0]


def cellule(fam, src, e, pose, even, T, zoom, nuit):
    K.utiliser(fam)
    lays = K.level_layers(src, e, pose, even)
    if not lays:
        img = np.full((int(T * 64), int(T * 64), 3), 0.2)
    else:
        day, night, _ = K.compose([{"pos": (T / 2, T / 2), "layers": lays}], T, T)
        img = night if nuit else day
    if zoom == 1:
        img = K.down2(img)
    return K.to_im(img)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--asm", action="append", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--mode", default="ages", choices=("ages", "gamme"))
    ap.add_argument("--ages", default="")
    ap.add_argument("--zoom", type=int, default=1)
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--pair", action="store_true")
    ap.add_argument("--titre", default="")
    a = ap.parse_args()
    choix = [int(x) for x in a.ages.split(",") if x] or list(range(1, 16))
    T = 9.0
    cw = int(T * 64 / (2 if a.zoom == 1 else 1))
    lab = 22
    if a.mode == "ages":
        lignes = [(ere, [e for e in ages if e in choix]) for ere, ages in ERES]
        lignes = [(ere, ages) for ere, ages in lignes if ages]
        ncol = max(len(ages) for _, ages in lignes)
    else:
        lignes = [(None, [e]) for e in choix]
        ncol = 2
    W = ncol * (cw + 6) + 6
    H = 46 + len(lignes) * (cw + lab + 30) + 6
    sheet = Image.new("RGB", (W, H), (24, 24, 28))
    dr = ImageDraw.Draw(sheet)
    titre = a.titre or ("Assembleur F3-A · %s · zoom %d · %s%s" % (
        "15 âges" if a.mode == "ages" else "mitrailleuse validée | assembleur", a.zoom, "nuit" if a.nuit else "jour",
        " · niveau pair" if a.pair else " · niveau impair"))
    dr.text((8, 10), titre, fill=(255, 200, 110), font=K.font(20))
    y = 46
    for ere, ages in lignes:
        if ere is not None:
            dr.text((8, y + 4), "Ère %d" % ere, fill=(200, 200, 210), font=K.font(16))
        y += 26
        x = 6
        for e in ages:
            if a.mode == "ages":
                cells = [("assembleur_e", src_asm(a.asm, e), "F", a.pair or e == 1, "assembleur")]
            else:
                cells = [("gun_e", GUN[e], "E", e == 1, "mitrailleuse"),
                         ("assembleur_e", src_asm(a.asm, e), "F", e == 1, "assembleur")]
            for fam, src, pose, even, nom in cells:
                sheet.paste(cellule(fam, src, e, pose, even, T, a.zoom, a.nuit), (x, y + lab))
                niv = 2 * e if even else 2 * e - 1
                dr.text((x + 4, y + 3), "%d · %s · %s · niv. %d" % (e, K.NAME[e], nom, niv), fill=(230, 230, 230),
                        font=K.font(14))
                x += cw + 6
        y += cw + lab + 4
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
