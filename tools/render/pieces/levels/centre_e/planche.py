"""PLANCHES DU CENTRE DE COMMANDEMENT (lot F5-A, 27/10 ; copie de foreuse_e/planche.py). Python 3.9, hors Blender. Composition hors moteur (commun/compo.py : sol
vanilla, ombres, lueur, nuit par la LUT du jeu), même fenêtre et même échelle pour toutes les cases.

    py -3.9 tools/render/pieces/levels/foreuse_e/planche.py --src DIR --dest planche.png [--ages 1,…,15]
        [--poses N,E] [--cols 5] [--zoom 1|2] [--nuit] [--jour-nuit] [--pair] [--gun] [--avant DIR] [--titre "…"]

Une case par (âge, pose) ; --jour-nuit : chaque case deux fois (jour | nuit) ; --gun : la mitrailleuse VALIDÉE du même âge
et de la même pose à côté de la foreuse (sprites de production, comme laser_e/planche_gun.py) ; --pair : niveau pair
(pièce paire posée).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
import compo as K  # noqa: E402

LOGS = K.ROOT + "/fo-logs"
GUN = {e: LOGS + "/2026-10-23_V3E-p5/bas/sprites" for e in range(1, 10)}
GUN.update({e: LOGS + "/2026-10-23_V3E-p5/haut/sprites" for e in (10, 11, 12)})
GUN.update({e: LOGS + "/2026-10-23_V3E-ereV/sprites" for e in (13, 14, 15)})


def cellule(famille, src, e, pose, even, T, zoom, nuit):
    K.utiliser(famille)
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
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--ages", default=",".join(str(e) for e in range(1, 16)))
    ap.add_argument("--poses", default="F")
    ap.add_argument("--cols", type=int, default=5)
    ap.add_argument("--zoom", type=int, default=1)
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--jour-nuit", action="store_true")
    ap.add_argument("--pair", action="store_true")
    ap.add_argument("--gun", action="store_true")
    ap.add_argument("--avant", default="", help="dossier de sprites d'une ronde précédente : chaque case montre avant | après")
    ap.add_argument("--fenetre", type=float, default=0.0, help="fenêtre en tuiles (défaut : plus grand côté + 2,5)")
    ap.add_argument("--titre", default="")
    a = ap.parse_args()
    ages = [int(x) for x in a.ages.split(",") if x]
    poses = [p for p in a.poses.split(",") if p]
    K.utiliser("centre_e")
    T = a.fenetre or (max(K.SIDE[e] for e in ages) + 2.5)
    cw = int(T * 64 / (2 if a.zoom == 1 else 1))
    lab = 22
    cases = []
    for e in ages:
        for p in poses:
            sous = []
            if a.gun:
                sous.append(("mitrailleuse", "gun_e", GUN[e], a.pair or e == 1, a.nuit))
            if a.avant:
                sous.append(("avant", "centre_e", a.avant, a.pair or e == 1, a.nuit))
            if a.jour_nuit:
                sous += [("centre jour", "centre_e", a.src, a.pair or e == 1, False),
                         ("centre nuit", "centre_e", a.src, a.pair or e == 1, True)]
            else:
                sous.append(("après" if a.avant else "centre", "centre_e", a.src, a.pair or e == 1, a.nuit))
            cases.append((e, p, sous))
    nsub = len(cases[0][2])
    cols = max(1, a.cols)
    rows = (len(cases) + cols - 1) // cols
    W = cols * (nsub * (cw + 4) + 10) + 6
    H = 40 + rows * (cw + lab + 8) + 6
    sheet = Image.new("RGB", (W, H), (24, 24, 28))
    dr = ImageDraw.Draw(sheet)
    dr.text((8, 8), a.titre or "Centre F5-A · zoom %d · %s" % (a.zoom, "nuit" if a.nuit else "jour"),
            fill=(255, 200, 110), font=K.font(20))
    for i, (e, p, sous) in enumerate(cases):
        r, cc = divmod(i, cols)
        x = 6 + cc * (nsub * (cw + 4) + 10)
        y = 40 + r * (cw + lab + 8)
        dr.text((x + 2, y + 2), "%d · %s · %s · niv. %d" % (e, K.NAME[e], p, e),
                fill=(230, 230, 230), font=K.font(14))
        for j, (nom, fam, src, even, nuit) in enumerate(sous):
            sheet.paste(cellule(fam, src, e, "N" if fam == "gun_e" else p, even, T, a.zoom, nuit), (x + j * (cw + 4), y + lab))
            if nsub > 1:
                dr.text((x + j * (cw + 4) + 4, y + lab + 2), nom, fill=(200, 200, 200), font=K.font(12))
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
