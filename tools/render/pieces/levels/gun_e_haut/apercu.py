"""Aperçu de travail : socle + tête composés sur le sol vanilla (ombre, principal, lueur), jour, zoom 2 (64 px par
tuile), avec agrandissement entier facultatif pour l'inspection (lot V3-E).

    py -3.9 tools/render/pieces/levels/gun_e_haut/apercu.py <sortie.png (relative : <travail>/apercus)> e11-socle+e11-tete-E [...]
           [--scale 2] [--crop x0,y0,x1,y1] [--night]
Chaque argument « a+b » est UNE entité (couches superposées), posées de gauche à droite.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import planche as PL  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--data", default="H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/data")
    ap.add_argument("ents", nargs="+")
    ap.add_argument("--scale", type=int, default=1)
    ap.add_argument("--crop", default="")
    ap.add_argument("--night", action="store_true")
    a = ap.parse_args()
    if not os.path.isabs(a.out):
        a.out = os.path.join(PL.WORK, "apercus", a.out)
        os.makedirs(os.path.dirname(a.out), exist_ok=True)
    ents = []
    x = 0.5
    sides = []
    for spec in a.ents:
        names = spec.split("+")
        lay = []
        for n in names:
            lay += PL.own(n)
        side = PL.SIDE_OF(names[0])
        x += side / 2.0 + 0.5
        ents.append({"pos": (x, side / 2.0 + 2.5), "layers": lay})
        x += side / 2.0 + 0.5
        sides.append(side)
    W = x + 1.5
    H = max(sides) + 4.5
    day, night = PL.compose(a.data, ents, W, H)
    img = night if a.night else day
    im = PL.to_im(img)
    if a.crop:
        im = im.crop(tuple(int(v) for v in a.crop.split(",")))
    if a.scale > 1:
        im = im.resize((im.width * a.scale, im.height * a.scale), Image.NEAREST)
    im.save(a.out)
    print(a.out, im.size)


if __name__ == "__main__":
    main()
