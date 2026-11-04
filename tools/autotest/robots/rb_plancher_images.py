"""Lot ROBOTS-JEU (3/11) : MISE AU NET des robots au plancher, relue sur les captures du scénario rb-plancher (F205).

    py -3.9 -B tools/autotest/robots/rb_plancher_images.py <dossier fo-shots> [<dossier fo-shots du témoin>]

Pour chaque vue (tous-z1, terrestres-z2), prises t0 à t5 à 130 ticks d'écart, robots figés : netteté (énergie du gradient) et écart
moyen absolu (0 à 255) avec la prise précédente. L'image est « au net » à la première prise dont l'écart avec la suivante est sous
SEUIL et qui ne change plus ensuite ; le temps de mise au net est rendu en ticks depuis t0 (t0 = déjà nette : 0). Témoin facultatif
(même scénario sur main) : mêmes chiffres, côte à côte.
"""
import glob
import os
import re
import sys

import numpy as np
from PIL import Image

SEUIL = 0.5
PAS_TICKS = 130


def gradient(a):
    g = a.astype("float32").mean(axis=2)
    return float(np.abs(np.diff(g, axis=0)).mean() + np.abs(np.diff(g, axis=1)).mean())


def lire(shots):
    vues = {}
    for f in sorted(glob.glob(os.path.join(shots, "*.png"))):
        m = re.search(r"\d+-(tous-z1|terrestres-z2)-t(\d+)\.png$", f)
        if m:
            vues.setdefault(m.group(1), {})[int(m.group(2))] = np.asarray(Image.open(f).convert("RGB")).astype("int16")
    return vues


def analyse(shots):
    out = {}
    for vue, prises in sorted(lire(shots).items()):
        ts = sorted(prises)
        net = [gradient(prises[t]) for t in ts]
        ecarts = [float(np.abs(prises[ts[i + 1]] - prises[ts[i]]).mean()) for i in range(len(ts) - 1)]
        au_net = None
        for i in range(len(ts)):
            if all(e < SEUIL for e in ecarts[i:]):
                au_net = i
                break
        out[vue] = {"t": ts, "nettete": net, "ecarts": ecarts, "au_net": au_net}
    return out


def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit(__doc__)
    res = [("lot", analyse(sys.argv[1]))] + ([("temoin", analyse(sys.argv[2]))] if len(sys.argv) == 3 else [])
    code = 0
    for nom, r in res:
        if not r:
            print("[RB-PLANCHER] %s : aucune capture tous-z1/terrestres-z2" % nom)
            code = 1
        for vue, d in r.items():
            n = " ".join("%.2f" % x for x in d["nettete"])
            e = " ".join("%.2f" % x for x in d["ecarts"])
            if d["au_net"] is None:
                quand = "PAS AU NET en %d prises" % len(d["t"])
            else:
                quand = "au net a t%d (%d ticks apres la premiere prise)" % (d["au_net"], d["au_net"] * PAS_TICKS)
            print("[RB-PLANCHER] %-6s %-14s nettete %s ; ecarts successifs %s ; %s" % (nom, vue, n, e, quand))
    return code


if __name__ == "__main__":
    sys.exit(main())
