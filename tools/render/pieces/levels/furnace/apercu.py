"""Aperçu de travail (lot V3, four) : quelques niveaux côte à côte au zoom 2 (64 px/tuile), jour en haut,
nuit en bas, composés comme les planches (compose.py). Sortie dans tools/render/out/levels/furnace/ (ignoré
par git). Outil d'itération du modeleur ; les planches livrées sont produites par planches.py.

    python -P tools/render/pieces/levels/furnace/apercu.py 1,2,27,29 [--src quick] [--out nom.png]
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose as CP  # noqa: E402
import planches as PL  # noqa: E402
from PIL import Image  # noqa: E402


def quick_measures(lv, src):
    """Indicateurs D1 rapides (mêmes fonctions que measure_d1.py) sur une liste de niveaux d'un dossier."""
    import measure_d1 as M
    l1 = M.Level(1, src)
    for n in lv:
        if n == 1:
            continue
        L_ = M.Level(n, src)
        mass = M.h_open(L_.mask, 10)
        bb = M.bbox(mass)
        line = "n%02d : O %.2f (cible %.2f) ; L %.2f ; aire %.2f t2 ; IoU n1 %.3f ; V %.0f %%" % (
            n, -bb["top"] - 1.0, M.PRM.o_target(n), bb["right"] - bb["left"], L_.mask.sum() / M.TILE2,
            M.iou(l1.mask, L_.mask), 100 * (l1.mask & ~L_.mask).sum() / l1.mask.sum())
        if os.path.exists(os.path.join(src, "n%02d" % (n - 1), "spec.json")) or n - 1 == 1:
            prev = M.Level(n - 1, src).mask
            line += " ; IoU préc. %.3f ; ajout %.3f t2" % (M.iou(prev, L_.mask), (L_.mask & ~prev).sum() / M.TILE2)
        if n >= 29:
            si, k = M.scaled_iou(l1.mask, L_.mask)
            line += " ; IoU normalisée %.3f (k %.2f)" % (si, k)
        print(line)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("levels")
    ap.add_argument("--out", default="apercu.png")
    ap.add_argument("--src", default="")
    ap.add_argument("--mesure", action="store_true")
    a = ap.parse_args()
    root = CP.OUT
    if a.src:
        CP.OUT = os.path.join(CP.OUT, a.src)
    lv = [int(x) for x in a.levels.split(",")]
    if a.mesure:
        quick_measures(lv, CP.OUT)
    day, light, _ = PL.gallery([[n] for n in lv], col_w=3.6, row_h=4.9, top_pad=0.15)
    nig = CP.night(day, light)
    d, n = CP.to_img(day), CP.to_img(nig)
    c = Image.new("RGB", (d.width, d.height * 2 + 4), (20, 20, 20))
    c.paste(d, (0, 0))
    c.paste(n, (0, d.height + 4))
    PL.label(c, [(int(i * 3.6 * 64) + 6, 4, "n%d" % x) for i, x in enumerate(lv)], 15)
    p = os.path.join(root, a.out)
    c.save(p)
    print(p)


if __name__ == "__main__":
    main()
