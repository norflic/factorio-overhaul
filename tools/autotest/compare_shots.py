#!/usr/bin/env python3
r"""
Compare deux séries de captures (même nommage), pixel à pixel (lot P1).

    python tools/autotest/compare_shots.py <dossier A> <dossier B>

Pour chaque PNG présent des deux côtés : identique, ou nombre de pixels différents, écart maximal par
canal et rectangle des différences. Code de sortie : 0 si toutes les captures communes sont identiques
et si les deux dossiers ont les mêmes fichiers, 1 sinon.
Dépendance : Pillow.
"""
import os
import sys

from PIL import Image, ImageChops


def pngs(d):
    return {f for f in os.listdir(d) if f.endswith(".png") and not f.startswith("planche-")}


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    a, b = sys.argv[1], sys.argv[2]
    fa, fb = pngs(a), pngs(b)
    common = sorted(fa & fb)
    same, diff = 0, []
    for f in common:
        with Image.open(os.path.join(a, f)) as ia, Image.open(os.path.join(b, f)) as ib:
            ia, ib = ia.convert("RGB"), ib.convert("RGB")
            if ia.size != ib.size:
                diff.append((f, "tailles %s / %s" % (ia.size, ib.size)))
                continue
            d = ImageChops.difference(ia, ib)
            box = d.getbbox()
            if box is None:
                same += 1
                continue
            r, g, bl = d.split()
            m = ImageChops.lighter(ImageChops.lighter(r, g), bl)  # écart maximal des trois canaux
            hist = m.histogram()
            px = sum(hist[1:])
            mx = max(i for i, n in enumerate(hist) if n)
            diff.append((f, "%d pixels differents (%.3f %%), ecart max %d, zone %s" % (
                px, 100.0 * px / (ia.size[0] * ia.size[1]), mx, box)))
    print("communes %d : identiques %d, differentes %d ; seulement dans A %d, seulement dans B %d" % (
        len(common), same, len(diff), len(fa - fb), len(fb - fa)))
    for f, why in diff:
        print("  DIFF " + f + " : " + why)
    for f in sorted(fa - fb):
        print("  seulement A : " + f)
    for f in sorted(fb - fa):
        print("  seulement B : " + f)
    return 0 if not diff and fa == fb else 1


if __name__ == "__main__":
    sys.exit(main())
