"""Taille des RESTES et de l'EXPLOSION de la mitrailleuse, mesurée sur les captures du scénario a4-ruines (lot A4).
Python 3.9 (numpy, Pillow, scipy).

    py -3.9 tools/autotest/a4_ruines_images.py "<fo-shots de fo-captures.bat a4-ruines>"

Sol de laboratoire BLANC uniforme (lab-white) : un pixel « non blanc » (écart > SEUIL à la couleur médiane du sol) est
du reste ou de l'explosion. On garde la plus grande composante connexe (les débris éparpillés, particules vanilla NON
agrandies, sont écartés ; pour l'explosion, seuls les pixels de la BOULE DE FEU, jaune-orange, comptent : la
composante entière y mêlerait le reste, la fumée et les débris) et on mesure sa largeur et sa hauteur en tuiles (zoom 2 : 64 px par tuile). Taille relative
= largeur du niveau / largeur du niveau 1 (vanilla) ; attendue : emprise / 2 (kit.scale × emprise / 2, lot A2), à
TOLERANCE près (la composante comprend l'ombre et peut ou non toucher un débris). Code 0 si toutes les tailles des
RESTES sont dans la tolérance ; la boule de feu de l'explosion est mesurée à titre INFORMATIF (une variation tirée au
hasard par explosion : une seule capture ne compare pas deux tailles ; le facteur d'échelle des animations
d'explosion se lit dans les données, harness --dump-final explosion/fo-lvl-gun-N-explosion).
"""
import csv
import glob
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PX = 64.0
SEUIL = 40
TOLERANCE = 0.15


def mesure(p, flamme=False):
    a = np.asarray(Image.open(p).convert("RGB")).astype(np.int32)
    fond = np.median(a.reshape(-1, 3), axis=0)
    m = np.abs(a - fond).max(-1) > SEUIL
    if flamme:
        # boule de feu seule (rouge et vert forts, bleu nettement plus bas) : ni reste, ni fumée, ni débris
        m = (a[..., 0] > 200) & (a[..., 1] > 110) & (a[..., 2] < a[..., 1] - 60)
    lab, n = ndimage.label(m)
    if n == 0:
        return None
    tailles = ndimage.sum(m, lab, range(1, n + 1))
    k = int(np.argmax(tailles)) + 1
    ys, xs = np.nonzero(lab == k)
    return (xs.max() - xs.min() + 1) / PX, (ys.max() - ys.min() + 1) / PX, int(tailles[k - 1]), n


def main():
    d = sys.argv[1]
    sites = list(csv.DictReader(open(os.path.join(d, "a4-ruines-sites.tsv"), encoding="utf-8"), delimiter="\t"))
    res = {}
    for s in sites:
        if s["sol"] != "lab-white" or s["etat"] not in ("restes", "mort+27"):
            continue
        f = glob.glob(os.path.join(d, "[0-9][0-9][0-9]-%s.png" % s["capture"]))
        if len(f) != 1:
            print("[FO-A4-RUINES-IMG] ECHEC  %s : capture absente" % s["capture"])
            continue
        res[(s["etat"], int(s["niveau"]))] = (mesure(f[0], flamme=s["etat"] != "restes"), float(s["cote"]))
    ko = 0
    for etat in ("restes", "mort+27"):
        ref = res.get((etat, 1))
        if not ref or not ref[0]:
            print("[FO-A4-RUINES-IMG] ECHEC  %s : référence vanilla (niveau 1) absente" % etat)
            ko += 1
            continue
        for (et, n), (m, cote) in sorted(res.items()):
            if et != etat or m is None:
                continue
            w, h, npx, ncomp = m
            rel_w, rel_h = w / ref[0][0], h / ref[0][1]
            att = cote / 2.0
            ok = abs(rel_w - att) <= TOLERANCE * att and abs(rel_h - att) <= TOLERANCE * att
            if etat == "restes":
                ko += not ok
                verdict = "OK    " if ok else "ECHEC "
            else:
                # explosion : INFORMATIF (24/10, premier passage) : medium_explosion tire une variation au hasard et
                # la boule de feu d'une seule capture varie du simple au quadruple d'une explosion à l'autre ; la
                # taille de l'explosion se contrôle sur les données (scale des animations) et à l'œil
                verdict = "INFO  "
            print("[FO-A4-RUINES-IMG] %s %s niveau %2d (emprise %g x %g) : %.2f x %.2f tuiles, taille relative au niveau 1 "
                  "%.2f x %.2f, attendue %.2f (± %d %%) ; %d px dans la composante, %d composantes (débris compris)" % (
                      verdict, "restes" if etat == "restes" else "boule de feu (mort + 27 ticks, informatif)",
                      n, cote, cote, w, h, rel_w, rel_h, att, TOLERANCE * 100, npx, ncomp))
    print("[FO-A4-RUINES-IMG] BILAN : %d ECHEC(S)" % ko)
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
