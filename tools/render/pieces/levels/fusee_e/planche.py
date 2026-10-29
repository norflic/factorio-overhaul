"""PLANCHE DE LA FUSÉE (lot CENTRE-FUSEE) : les états côte à côte sur le sol vanilla (commun/compo.py : ombres, lueur).
Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/fusee_e/planche.py --src DIR --dest planche.png [--noms epave,age01,…]
        [--zoom 1|2] [--nuit] [--largeur 2400] [--titre "…"]

Une case par état, même fenêtre et même échelle pour toutes ; l'échelle 1 est celle du jeu au zoom 1 (32 px par tuile),
l'échelle 2 celle du zoom 2 (64 px par tuile, haute résolution).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
import compo as K  # noqa: E402

TITRES = {"epave": "Épave (âge 0) : le vaisseau écrasé", "age01": "Réparé (âge 1) : encore un vaisseau",
          "age04": "Âge 4 : moitié vaisseau, moitié bâtiment", "age08": "Âge 8 : un bâtiment, la coque aux deux bouts",
          "age15": "Âge 15 : citadelle sur la carcasse"}
EMPRISE = {"epave": 4, "age01": 4, "age04": 5, "age08": 6, "age15": 8}   # largeur ; longueur = 2 × largeur
AGE = {"epave": 0, "age01": 1, "age04": 4, "age08": 8, "age15": 15}


def cellule(src, nom, Wt, Ht, oy, zoom, nuit):
    lays = K.own(src, nom, ("shadow", "main", "glow"))
    day, night, _ = K.compose([{"pos": (Wt / 2.0, oy), "layers": lays}], Wt, Ht)
    img = night if nuit else day
    if zoom == 1:
        img = K.down2(img)
    return K.to_im(img)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--noms", default="epave,age01,age04,age08,age15")
    ap.add_argument("--zoom", type=int, default=2, choices=(1, 2))
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--largeur", type=int, default=2400)
    ap.add_argument("--titre", default="")
    ap.add_argument("--fen", default="3,13,8.4", help="marge en largeur (tuiles, ajoutée à la longueur), hauteur de la case et y du centre de l'emprise")
    a = ap.parse_args()
    noms = [n for n in a.noms.split(",") if n]
    Wt0, Ht, oy = [float(x) for x in a.fen.split(",")]
    ppt = 64 if a.zoom == 2 else 32
    ch = int(Ht * ppt)
    gap, hd, lab = 6, 46, 44
    cw = [int((2 * EMPRISE[n] + Wt0) * ppt) for n in noms]
    W = sum(cw) + (len(noms) + 1) * gap
    H = hd + ch + lab + gap
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), a.titre or "Centre de commandement = la fusée de départ, vaisseau couché qui devient bâtiment · concept v2 · zoom %d · %s" % (
        a.zoom, "nuit" if a.nuit else "jour"), fill=(255, 205, 120), font=K.font(24 if a.zoom == 2 else 20))
    x = gap
    for i, n in enumerate(noms):
        sheet.paste(cellule(a.src, n, cw[i] / float(ppt), Ht, oy, a.zoom, a.nuit), (x, hd))
        dr.text((x + 8, hd + ch + 4), TITRES.get(n, n), fill=(240, 240, 240), font=K.font(21 if a.zoom == 2 else 15))
        e = AGE[n]
        sub = "emprise %d×%d tuiles" % (2 * EMPRISE[n], EMPRISE[n]) + ("" if e == 0 else " · %s" % K.NAME[e])
        dr.text((x + 8, hd + ch + 4 + (26 if a.zoom == 2 else 19)), sub, fill=(170, 170, 175), font=K.font(16 if a.zoom == 2 else 12, False))
        x += cw[i] + gap
    if W > a.largeur:
        k = a.largeur / float(W)
        sheet = sheet.resize((a.largeur, int(H * k)), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size, "%.2f Mo" % (os.path.getsize(a.dest) / 1e6))


if __name__ == "__main__":
    main()
