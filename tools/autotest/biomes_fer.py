"""Lot BIOMES-SUIVI (30/10) : lisibilité du MINERAI DE FER vanilla sur un sol, mesurée sur les captures du banc b0-biomes.

Le scénario pose trois carrés de 22 tuiles (givre de la plaine de cristal, herbe, désert rouge), chacun avec un gisement de
fer de 12 × 12 tuiles dont la quantité croît d'ouest en est (colonne 1 : 60, colonne 12 : 30 000 ; tous les stades de
l'image). Captures « fer-<fond>-z2 » : zoom 2 (64 px par tuile), centrées sur le carré, de jour.

Mesures (CIE Lab, D65, sRGB) :
- sol : moyenne d'une bande de sol nu à 7,5 à 10 tuiles du centre (à gauche et à droite, lignes −5 à +5) ;
- par colonne du gisement (lignes −5 à +5) : ΔE76 entre la moyenne de la colonne et le sol, et part des pixels de la
  colonne à plus de 20 de ΔE du sol (« pixels qui se détachent ») ;
- contraste de LUMINANCE moyen |L(minerai) − L(sol)| sur les pixels qui se détachent.
Comparaison : le fer sur le givre contre le fer sur l'herbe et le désert rouge (sols vanilla où il se lit bien).

Usage : py -3.9 tools/autotest/biomes_fer.py <dossier fo-shots> [<dossier fo-shots> ...]
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

TUILE = 64  # zoom 2
FONDS = [("givre", "fer-givre-z2"), ("herbe", "fer-grass-2-z2"), ("desert rouge", "fer-red-desert-0-z2")]
SEUIL = 20.0


def lab(rgb):
    c = rgb / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def mesure(png):
    im = np.asarray(Image.open(png).convert("RGB"), dtype=np.float64)
    h, w = im.shape[:2]
    cx, cy = w / 2, h / 2
    L = lab(im)
    y0, y1 = int(cy - 5 * TUILE), int(cy + 5 * TUILE)
    sol = np.concatenate([
        L[y0:y1, int(cx - 10 * TUILE):int(cx - 7.5 * TUILE)].reshape(-1, 3),
        L[y0:y1, int(cx + 7.5 * TUILE):int(cx + 10 * TUILE)].reshape(-1, 3)])
    s = sol.mean(0)
    cols = []
    for k in range(12):
        x0 = int(cx + (k - 6) * TUILE)
        px = L[y0:y1, x0:x0 + TUILE].reshape(-1, 3)
        d = np.linalg.norm(px - s, axis=1)
        det = d > SEUIL
        dl = np.abs(px[det, 0] - s[0]).mean() if det.any() else 0.0
        cols.append((float(np.linalg.norm(px.mean(0) - s)), float(det.mean()), float(dl)))
    return s, cols


def main():
    for dossier in sys.argv[1:]:
        print("== " + dossier)
        res = {}
        for nom, motif in FONDS:
            f = glob.glob(os.path.join(dossier, "*-" + motif + ".png"))
            if not f:
                print("  %-13s : capture absente" % nom)
                continue
            s, cols = mesure(f[0])
            res[nom] = cols
            print("  %-13s : sol Lab (%.0f ; %.0f ; %.0f)" % (nom, s[0], s[1], s[2]))
            print("    dE colonne  : " + " ".join("%5.1f" % c[0] for c in cols))
            print("    part > %d   : " % SEUIL + " ".join("%5.2f" % c[1] for c in cols))
            print("    |dL| detache: " + " ".join("%5.1f" % c[2] for c in cols))
        for nom in res:
            cols = res[nom]
            maigres = cols[:4]
            print("  BILAN %-13s : dE moyen %.1f (4 colonnes maigres %.1f), part qui se detache %.2f (maigres %.2f)" % (
                nom, np.mean([c[0] for c in cols]), np.mean([c[0] for c in maigres]),
                np.mean([c[1] for c in cols]), np.mean([c[1] for c in maigres])))


if __name__ == "__main__":
    main()
