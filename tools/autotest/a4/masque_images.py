"""Essai du masque d'équipe (lot A4) : couleur prise par la mitrailleuse selon sa force, mesurée sur les captures.
Python 3.9.

    py -3.9 tools/autotest/a4/masque_images.py <captures a4-masque de la copie AVEC masque> <captures du mod SANS masque>

Pour chaque capture : pixels qui diffèrent (somme RGB > 30) entre la copie avec masque et le mod livré = zone teintée ;
couleur moyenne de cette zone avec et sans masque, et sa teinte (degrés). Les mitrailleuses vanilla (masque vanilla
dans les deux cas) servent de témoin : aucune différence attendue.
"""
import colorsys
import csv
import glob
import os
import sys

import numpy as np
from PIL import Image

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def charge(d, nom):
    return np.asarray(Image.open(glob.glob(os.path.join(d, "[0-9][0-9][0-9]-%s.png" % nom))[0]).convert("RGB")).astype(
        np.int32)


def main():
    avec, sans = sys.argv[1], sys.argv[2]
    for s in csv.DictReader(open(os.path.join(avec, "a4-masque-sites.tsv"), encoding="utf-8"), delimiter="\t"):
        a, b = charge(avec, s["capture"]), charge(sans, s["capture"])
        z = np.abs(a - b).sum(-1) > 30
        if not z.any():
            print("[FO-A4-MASQUE-IMG] %-34s : aucune différence (%s)" % (s["capture"], s["nom"]))
            continue
        ma, mb = a[z].mean(0) / 255.0, b[z].mean(0) / 255.0
        ha = colorsys.rgb_to_hsv(*ma)
        hb = colorsys.rgb_to_hsv(*mb)
        print("[FO-A4-MASQUE-IMG] %-34s : %d px teintés ; couleur moyenne avec masque (%.2f, %.2f, %.2f) teinte %3.0f° "
              "sat %.2f ; sans masque (%.2f, %.2f, %.2f) teinte %3.0f° sat %.2f" % (
                  s["capture"], int(z.sum()), ma[0], ma[1], ma[2], ha[0] * 360, ha[1], mb[0], mb[1], mb[2],
                  hb[0] * 360, hb[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
