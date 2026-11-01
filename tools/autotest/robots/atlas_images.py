"""Lot RB-0, essai E8 : relit les captures du scénario rb0-atlas et les compare aux feuilles de remplissage sources.

    py -3.9 -B tools/autotest/robots/atlas_images.py <dossier fo-shots> <copie jetable avec remplissage>

Pour chaque capture `NNN-e8-fill-<k>-<a|b>.png` (640 x 640, zoom 2, la feuille k à l'échelle 0,5 : 1 pixel écran = 1 pixel source),
écart moyen absolu (0 à 255) entre le carré central de 640 px et le carré central de la source, nettete relative (énergie du
gradient, capture / source) et écart entre les deux prises a et b (mise au net, F205). Une image « fautive » a un
écart moyen au-dessus de 12 ou une netteté sous 0,6 : le jeu l'a dessinée floue, vide ou fausse.
"""
import glob
import os
import re
import sys

import numpy as np
from PIL import Image


def gradient(a):
    g = a.astype("float32").mean(axis=2)
    return float(np.abs(np.diff(g, axis=0)).mean() + np.abs(np.diff(g, axis=1)).mean())


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    shots, copie = sys.argv[1], sys.argv[2]
    fautives = 0
    n = 0
    prises = {}
    for f in sorted(glob.glob(os.path.join(shots, "*e8-fill-*.png"))):
        m = re.search(r"e8-fill-(\d+)-([ab])\.png$", f)
        if not m:
            continue
        k, ab = int(m.group(1)), m.group(2)
        src = Image.open(os.path.join(copie, "graphics", "rb0", "fill-%d.png" % k)).convert("RGB")
        sw, sh = src.size
        src = src.crop((sw // 2 - 320, sh // 2 - 320, sw // 2 + 320, sh // 2 + 320))
        im = Image.open(f).convert("RGB")
        w, h = im.size
        c = im.crop((w // 2 - 320, h // 2 - 320, w // 2 + 320, h // 2 + 320))
        a, s = np.asarray(c), np.asarray(src)
        ecart = float(np.abs(a.astype("float32") - s.astype("float32")).mean())
        net = gradient(a) / max(gradient(s), 1e-6)
        prises[(k, ab)] = a
        bad = ecart > 12 or net < 0.6
        fautives += bad
        n += 1
        print("fill-%d %s : ecart moyen=%.2f nettete relative=%.2f %s" % (k, ab, ecart, net, "FAUTIVE" if bad else "ok"))
    for k in sorted({k for k, _ in prises}):
        if (k, "a") in prises and (k, "b") in prises:
            d = float(np.abs(prises[(k, "a")].astype("float32") - prises[(k, "b")].astype("float32")).mean())
            print("fill-%d : ecart entre prise a et prise b=%.2f" % (k, d))
    print("BILAN : %d capture(s), %d fautive(s)" % (n, fautives))
    return 0 if n and not fautives else 1


if __name__ == "__main__":
    sys.exit(main())
