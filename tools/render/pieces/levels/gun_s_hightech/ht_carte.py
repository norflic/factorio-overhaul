"""Carte de diagnostic d'un rendu (même code que da_lib.measure, recopié pour l'affichage seulement) :
  - vert : petites pièces comptées par D3 (taches DoG claires et sombres de 4 à 256 px) ;
  - rouge : surfaces planes (P4 : Sobel < 6 sur l'intérieur) ;
  - magenta : zone lumineuse (L1, dilatée de 3 px).
Sert à voir OÙ la densité manque, sans changer la mesure.

    python ht_carte.py --renders <dossier> --level 29 --pose E --out <png>
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ht_mesure as HM  # noqa: E402

D = HM.D


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--renders", required=True)
    ap.add_argument("--level", type=int, default=29)
    ap.add_argument("--pose", default="E")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    comp, _ = HM.compose_level(a.level, a.pose, a.renders)
    body = comp["body"]
    M = body[..., 3] >= 0.5
    Mi = D.erode(M, 5)
    Mf = M.astype(np.float32)
    rgb = body[..., :3]
    L = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) * 255.0
    dog = D.masked_blur(L, Mf, 1.0) - D.masked_blur(L, Mf, 3.0)
    keep = np.zeros(M.shape, bool)
    for sign in (1, -1):
        blob = ((sign * dog) > 10.0) & Mi
        sizes, lab = D.components(blob, conn8=True)
        ok = [k for k, s in sizes.items() if 4 <= s <= 256]
        keep |= np.isin(lab, ok)
    sm = D.sobel_mag(D.gblur(L, 0.7))
    flat = (sm < 6.0) & Mi
    out = (np.clip(rgb, 0, 1) * 255 * 0.55).astype(np.uint8)
    out[flat] = (out[flat] * 0.4 + np.array([200, 30, 30]) * 0.6).astype(np.uint8)
    out[keep] = (60, 230, 60)
    out[~M] = (30, 30, 30)
    Image.fromarray(out).save(a.out)
    print("plat %.3f ; pièces (px) %.3f" % (flat.sum() / Mi.sum(), keep.sum() / Mi.sum()))


if __name__ == "__main__":
    main()
