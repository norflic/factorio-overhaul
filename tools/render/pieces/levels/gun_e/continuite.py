"""Lot A3 (24/10) : CONTINUITÉ de la rotation d'une tête sur ses 64 directions (pas de saut d'échelle, de cadre, d'ombre
ni d'éclairage entre deux directions voisines, poses validées comprises). Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/continuite.py --age 5 --tetes DIR [--sources-valides] [--dest FICHIER]

Pour chaque direction (d00 à d63, sources comme planche64.py) : aire de la couche principale (alpha ≥ 0,5, px hr),
centre de gravité de la silhouette relatif à l'origine, aire et centre de l'ombre, luminance moyenne de la couche
principale (éclairage) et part de la lueur. Puis, entre directions voisines (d63 -> d00 compris), les écarts ; le
rapport « saut / médiane des sauts » repère une direction qui détonne (un saut d'échelle ou de cadre donnerait un
rapport élevé aux frontières des sources : d00, d16, d32, d48).
"""
import argparse
import json
import os
import statistics as st
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import planche64 as P  # noqa: E402


def mesure(d, n):
    s = json.load(open(os.path.join(d, n, "spec.json"), encoding="utf-8"))
    res = {}
    for lay in ("main", "shadow", "glow"):
        L = s["layers"].get(lay)
        if not L:
            continue
        im = np.asarray(Image.open(os.path.join(d, n, L["file"])).convert("RGBA")).astype(float)
        a = im[..., 3] / 255.0
        gx = L["shift"][0] * 64 - L["width"] / 2.0
        gy = L["shift"][1] * 64 - L["height"] / 2.0
        ys, xs = np.nonzero(a >= 0.5) if lay != "glow" else np.nonzero(a > 0.02)
        res[lay] = {"aire": int(len(xs)), "cx": float(xs.mean() + gx) if len(xs) else 0.0,
                    "cy": float(ys.mean() + gy) if len(xs) else 0.0}
        if lay == "main":
            lum = (0.2126 * im[..., 0] + 0.7152 * im[..., 1] + 0.0722 * im[..., 2])[a >= 0.5]
            res[lay]["lum"] = float(lum.mean())
        if lay == "shadow":
            res[lay]["alpha_moy"] = float(a[a > 0].mean()) if (a > 0).any() else 0.0
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--age", type=int, required=True)
    ap.add_argument("--tetes", action="append", default=[])
    ap.add_argument("--sources-valides", action="store_true")
    ap.add_argument("--dest", default="")
    a = ap.parse_args()
    e = a.age
    dossiers = list(a.tetes) + ([P.VALIDES[e], P.A2] if a.sources_valides else [])
    rows = []
    for k in range(64):
        d, n = P.trouve(e, k, dossiers)
        if d is None:
            print("d%02d absente" % k)
            return 1
        r = mesure(d, n)
        r["k"], r["src"] = k, P.etiquette(d)
        rows.append(r)
    grandeurs = [("main", "aire"), ("main", "cx"), ("main", "cy"), ("main", "lum"), ("shadow", "aire"),
                 ("shadow", "cx"), ("shadow", "cy"), ("shadow", "alpha_moy"), ("glow", "aire")]
    L = ["Continuité de la rotation, âge %d (%s)" % (e, ", ".join(dossiers)),
         "dir src   " + " ".join("%12s" % ("%s.%s" % g) for g in grandeurs)]
    for r in rows:
        L.append("d%02d %-4s " % (r["k"], r["src"]) + " ".join("%12.2f" % r[c][g] for c, g in grandeurs))
    L.append("")
    L.append("sauts entre directions voisines (valeur absolue) : médiane, max (où) et max / médiane ; aux frontières de "
             "source (V, A2 / A3) : max / médiane")
    for c, g in grandeurs:
        sauts = [(abs(rows[(k + 1) % 64][c][g] - rows[k][c][g]), k) for k in range(64)]
        med = st.median(s for s, _ in sauts) or 1e-9
        mx, kx = max(sauts)
        front = [s for s, k in sauts if rows[k]["src"] != rows[(k + 1) % 64]["src"]]
        L.append("  %-16s médiane %8.2f ; max %8.2f (d%02d->d%02d) = %.1f × ; frontières : max %.1f ×" % (
            "%s.%s" % (c, g), med, mx, kx, (kx + 1) % 64, mx / med, (max(front) / med) if front else 0.0))
    txt = "\n".join(L)
    print(txt)
    if a.dest:
        open(a.dest, "w", encoding="utf-8").write(txt + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
