"""Lot A3 (24/10) : planche des trous enfermés, pour les REGARDER. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/trous_planche.py --rendus DIR --masques DIR [--age-masques 4-7=DIR]
        --noms e02-tete-d30,… --dest FICHIER.png [--zoom 2] [--cols 5]

Pour chaque tête : le rendu (couche principale, dossier de rendre.py, par exemple un essai rapide) sur fond gris, les
pixels du trou enfermé du MASQUE (règle des rendus, bouchon selon la production) en rouge, à côté du même rendu sans
marque ; agrandi --zoom fois (pixels nets). Légende : nom, plus grand trou, pixels enfermés.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import masques as MQ  # noqa: E402


def trou_masque(a01):
    free = a01 < 0.5
    lab, n = ndimage.label(free, structure=MQ.QUATRE)
    bord = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    return np.isin(lab, [i for i in range(1, n + 1) if i not in bord])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rendus", required=True)
    ap.add_argument("--masques", required=True)
    ap.add_argument("--age-masques", action="append", default=[])
    ap.add_argument("--noms", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--zoom", type=int, default=2)
    ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--gros", type=int, default=0, help="gros plan de ce rayon (px hr) autour du plus grand trou")
    a = ap.parse_args()
    MQ.AUTRES.update(MQ.plages(a.age_masques))
    tuiles = []
    for n in [x for x in a.noms.split(",") if x]:
        e, d = int(n[1:3]), n.split("-")[-1]
        z = MQ.charge(a.masques, e, d)
        W, H = (int(v) for v in z["canvas"])
        ox, oy = (int(v) for v in z["origin"])
        s = json.load(open(os.path.join(a.rendus, n, "spec.json"), encoding="utf-8"))
        L = s["layers"]["main"]
        im = np.asarray(Image.open(os.path.join(a.rendus, n, L["file"])).convert("RGBA")).astype(float)
        x0 = int(round(ox + L["shift"][0] * 64 - L["width"] / 2))
        y0 = int(round(oy + L["shift"][1] * 64 - L["height"] / 2))
        can = np.zeros((H, W, 4))
        can[y0:y0 + im.shape[0], x0:x0 + im.shape[1]] = im
        al = can[..., 3:4] / 255.0
        rgb = can[..., :3] * al + np.array([128.0, 128.0, 128.0]) * (1 - al)
        hole = trou_masque(MQ.alpha_prod(z, e, d))
        marque = rgb.copy()
        marque[hole] = [255, 0, 0]
        ys, xs = np.nonzero(can[..., 3] > 0)
        sl = (slice(max(0, ys.min() - 4), ys.max() + 5), slice(max(0, xs.min() - 4), xs.max() + 5))
        if a.gros and hole.any():
            # gros plan autour du plus grand trou
            lab, nl = ndimage.label(hole, structure=MQ.QUATRE)
            k = 1 + int(np.argmax(np.bincount(lab.ravel())[1:]))
            hy, hx = np.nonzero(lab == k)
            cy, cx = int(hy.mean()), int(hx.mean())
            sl = (slice(max(0, cy - a.gros), cy + a.gros), slice(max(0, cx - a.gros), cx + a.gros))
        pair = np.concatenate([rgb[sl], np.full((sl[0].stop - sl[0].start, 6, 3), 30.0), marque[sl]], 1)
        t = Image.fromarray(pair.clip(0, 255).astype(np.uint8))
        t = t.resize((t.width * a.zoom, t.height * a.zoom), Image.NEAREST)
        n_px, ng, big = MQ.plus_grand_trou(MQ.alpha_prod(z, e, d))
        tuiles.append(("%s : plus grand trou %d px (%d px en %d groupes)" % (n, big, n_px, ng), t))
    cw = max(t.width for _, t in tuiles) + 8
    rows = [tuiles[i:i + a.cols] for i in range(0, len(tuiles), a.cols)]
    hh = [max(t.height for _, t in r) + 22 for r in rows]
    out = Image.new("RGB", (cw * min(a.cols, len(tuiles)), sum(hh)), (24, 24, 28))
    dr = ImageDraw.Draw(out)
    y = 0
    for r, h in zip(rows, hh):
        for i, (lab, t) in enumerate(r):
            dr.text((i * cw + 4, y + 4), lab, fill=(235, 235, 235))
            out.paste(t, (i * cw + 4, y + 20))
        y += h
    out.save(a.dest)
    print("planche %s (%dx%d), %d têtes" % (a.dest, out.width, out.height, len(tuiles)))


if __name__ == "__main__":
    main()
