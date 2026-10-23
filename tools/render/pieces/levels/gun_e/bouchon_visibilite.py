"""Visibilité du bouchon arrière (lot A2) dans les poses validées N et E. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/bouchon_visibilite.py --force DOSSIER --non DOSSIER [--planche PNG]

Les deux dossiers sont des sorties de rendre.py pour les mêmes variantes eNN-tete-d00/d16, l'une rendue avec
FO_BOUCHON=force (bouchon posé aussi en N et E), l'autre avec FO_BOUCHON=non (sans bouchon). Même échantillonnage,
même graine : sans bouchon visible, les couches seraient égales. Le rapport donne, par variante et par couche (hr),
le nombre de pixels qui changent (écart RGBA > 2 sur 255) et l'écart maximal. Ce n'est PAS la preuve d'identité des
poses validées (le bouchon n'y est jamais posé : identite.py) ; c'est la mesure de ce qu'il ferait s'il y était,
utile pour les 64 directions (lot A3 : à quelles poses le poser sans saut visible).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image


def charge(d, n, lay):
    s = json.load(open(os.path.join(d, n, "spec.json"), encoding="utf-8"))
    L = s["layers"].get(lay)
    if not L:
        return None, None
    im = np.asarray(Image.open(os.path.join(d, n, L["file"])).convert("RGBA")).astype(int)
    return im, (L["width"], L["height"], tuple(L["shift"]))


def poser(im, geo, W, H, ox, oy):
    """Pose une couche sur un canevas commun (origine ox, oy en px hr)."""
    w, h, (sx, sy) = geo
    x0 = int(round(ox + sx * 64 - w / 2))
    y0 = int(round(oy + sy * 64 - h / 2))
    c = np.zeros((H, W, 4), int)
    c[y0:y0 + h, x0:x0 + w] = im
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", required=True)
    ap.add_argument("--non", required=True)
    ap.add_argument("--planche", default="")
    a = ap.parse_args()
    noms = sorted(n for n in os.listdir(a.force) if os.path.isdir(os.path.join(a.force, n)))
    tuiles = []
    for n in noms:
        for lay in ("main", "shadow", "glow"):
            A, ga = charge(a.force, n, lay)
            B, gb = charge(a.non, n, lay)
            if A is None or B is None:
                print("%-14s %-6s absente" % (n, lay))
                continue
            W, H = 1200, 1000
            A2, B2 = poser(A, ga, W, H, 600, 600), poser(B, gb, W, H, 600, 600)
            d = np.abs(A2 - B2).max(-1)
            nb = int((d > 2).sum())
            print("%-14s %-6s géométrie %s / %s ; %6d px changés (> 2/255), écart max %3d" % (
                n, lay, ga, gb, nb, int(d.max())))
            if lay == "main" and a.planche:
                ys, xs = np.nonzero((A2[..., 3] > 0) | (B2[..., 3] > 0))
                box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
                crop = lambda X: X[box[1]:box[3], box[0]:box[2]]
                fond = np.array([115, 115, 115])

                def compo(X):
                    al = X[..., 3:4] / 255.0
                    return (X[..., :3] * al + fond * (1 - al)).astype(np.uint8)
                m = crop(d) > 2
                dd = compo(crop(A2)).copy()
                dd[m] = [255, 0, 0]
                tuiles.append((n, [compo(crop(B2)), compo(crop(A2)), dd]))
    if a.planche and tuiles:
        rows = []
        for n, ims in tuiles:
            h = max(i.shape[0] for i in ims)
            row = np.full((h, sum(i.shape[1] for i in ims) + 20, 3), 30, np.uint8)
            x = 0
            for i in ims:
                row[:i.shape[0], x:x + i.shape[1]] = i
                x += i.shape[1] + 10
            rows.append(row)
        Wt = max(r.shape[1] for r in rows)
        out = np.full((sum(r.shape[0] + 10 for r in rows), Wt, 3), 30, np.uint8)
        y = 0
        for r in rows:
            out[y:y + r.shape[0], :r.shape[1]] = r
            y += r.shape[0] + 10
        Image.fromarray(out).save(a.planche)
        print("planche (par ligne : sans bouchon, avec bouchon, pixels changés en rouge) :", a.planche)
    return 0


if __name__ == "__main__":
    sys.exit(main())
