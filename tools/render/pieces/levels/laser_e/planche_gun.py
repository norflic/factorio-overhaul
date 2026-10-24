"""PLANCHE « LASER À CÔTÉ DE LA MITRAILLEUSE DU MÊME ÂGE » (lot F1-A, 24/10). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/laser_e/planche_gun.py --laser DIR [--laser DIR2 …] --dest planche.png
        [--ages 3,9,15] [--poses E,N] [--zoom 1|2] [--nuit] [--pair] [--titre "…"]

Une ligne par âge : mitrailleuse VALIDÉE (sprites de production, sources de graphics/levels/gun : passe 5 et ère V),
puis le laser (sprites de --laser ; plusieurs --laser : le premier qui a l'âge), pour chaque pose. Même fenêtre, même
échelle, sol vanilla, composé hors moteur (commun/compo.py) : sert à vérifier qu'un joueur ne CONFOND JAMAIS les deux
tourelles d'un même âge et qu'elles se reconnaissent cousines (même matière, même lumière). Âge « kS » : témoin du kit
laser (sans mitrailleuse en face).
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


def couches(famille, src, e, pose, even):
    K.utiliser(famille)
    return K.level_layers(src, e, pose, even)


def cellule(lays, T, zoom, nuit):
    if not lays:
        img = np.full((int(T * 64), int(T * 64), 3), 0.2)
    else:
        day, night, _ = K.compose([{"pos": (T / 2, T / 2), "layers": lays}], T, T)
        img = night if nuit else day
    if zoom == 1:
        img = K.down2(img)
    return K.to_im(img)


def src_laser(dirs, e):
    pre = e if isinstance(e, str) else ("e01" if e == 1 else "e%02d" % e)
    for d in dirs:
        if any(n.startswith(pre + "-") for n in os.listdir(d)):
            return d
    return dirs[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--laser", action="append", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--ages", default="3,9,15")
    ap.add_argument("--poses", default="E,N")
    ap.add_argument("--zoom", type=int, default=1)
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--pair", action="store_true")
    ap.add_argument("--titre", default="")
    a = ap.parse_args()
    ages = [x if x.startswith("k") else int(x) for x in a.ages.split(",") if x]
    poses = [p for p in a.poses.split(",") if p]
    K.utiliser("laser_e")
    T = max((int(e[1:]) if isinstance(e, str) else K.SIDE[e]) for e in ages) + 3.0
    cw = int(T * 64 / (2 if a.zoom == 1 else 1))
    lab = 24
    cols = [(p, fam) for p in poses for fam in ("gun_e", "laser_e")]
    W = len(cols) * (cw + 6) + 6
    H = 40 + len(ages) * (cw + lab + 6) + 6
    sheet = Image.new("RGB", (W, H), (24, 24, 28))
    dr = ImageDraw.Draw(sheet)
    dr.text((8, 8), a.titre or "Mitrailleuse validée | laser F1-A (essai) · zoom %d · %s" % (a.zoom, "nuit" if a.nuit
                                                                                             else "jour"),
            fill=(255, 200, 110), font=K.font(20))
    y = 40
    for e in ages:
        x = 6
        for p, fam in cols:
            if fam == "gun_e":
                lays = [] if isinstance(e, str) else couches("gun_e", GUN[e], e, p, a.pair or e == 1)
                nom = "mitrailleuse"
            else:
                lays = couches("laser_e", src_laser(a.laser, e), e, p, a.pair or e == 1)
                nom = "LASER"
            sheet.paste(cellule(lays, T, a.zoom, a.nuit), (x, y + lab))
            age = ("témoin %s" % e) if isinstance(e, str) else ("%d · %s" % (e, K.NAME[e]))
            dr.text((x + 4, y + 3), "%s · %s · pose %s" % (age, nom, p), fill=(230, 230, 230), font=K.font(15))
            x += cw + 6
        y += cw + lab + 6
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
