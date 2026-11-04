"""MESURES DES RENDUS (lot DA-ATELIERS), mêmes définitions que la critique du 3/11 (CRITIQUE.md, « Méthode ») : sur la couche main
(alpha > 0,5), luminance moyenne (Rec. 709 sur les valeurs codées), p90, saturation moyenne ((max − min) / max) ; bornes en tuiles
depuis le centre de l'entité (alpha > 0,1) ; lueur (somme max RGB × alpha, px-éq.) ; halo (pic, aire alpha ≥ 0,1).
Cibles : luminance moyenne ≥ 0,24, p90 ≥ 0,50 ; vanilla 2×2 x ±1,02 à ±1,06, y bas 1,17 à 1,28 ; 3×3 x ±1,41, y bas 1,59 à 1,61 ;
halo : pic 0,30 à 0,55 (LIGHT_PEAK_RANGE).

    py -3.9 tools/render/pieces/ateliers/mesure.py <dossier de rendus> [variantes séparées par des virgules]
"""
import json
import os
import sys

import numpy as np
from PIL import Image


def mesure(d, n):
    s = json.load(open(os.path.join(d, n, "spec.json"), encoding="utf-8"))
    out = {}
    for k in ("main", "glow", "light"):
        L = s["layers"].get(k)
        if not L:
            continue
        a = np.asarray(Image.open(os.path.join(d, n, L["file"])).convert("RGBA")).astype(float) / 255
        al = a[..., 3]
        h, w = al.shape
        ys, xs = np.nonzero(al > 0.1)
        if k == "main":
            out["x"] = ((xs.min() - w / 2) / 64 + L["shift"][0], (xs.max() + 1 - w / 2) / 64 + L["shift"][0])
            out["y_bas"] = (ys.max() + 1 - h / 2) / 64 + L["shift"][1]
            rgb = a[..., :3][al > 0.5]
            lum = 0.2126 * rgb[:, 0] + 0.7152 * rgb[:, 1] + 0.0722 * rgb[:, 2]
            mx, mn = rgb.max(1), rgb.min(1)
            sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
            out["lum"], out["p90"], out["sat"] = lum.mean(), np.percentile(lum, 90), sat.mean()
        elif k == "glow":
            out["lueur"] = (a[..., :3].max(-1) * al).sum()
        else:
            out["halo_pic"], out["halo_aire"] = al.max(), (al >= 0.1).sum() / 4096.0
    return out


def main():
    d = sys.argv[1]
    noms = sys.argv[2].split(",") if len(sys.argv) > 2 else sorted(x for x in os.listdir(d) if os.path.isfile(os.path.join(d, x, "spec.json")))
    for n in noms:
        m = mesure(d, n)
        if "lum" not in m:
            continue
        ok = "OK " if m["lum"] >= 0.24 and m["p90"] >= 0.5 else "BAS"
        hal = (" halo pic %.2f aire %.1f t2" % (m["halo_pic"], m["halo_aire"])) if "halo_pic" in m else ""
        print("%-22s %s lum %.3f p90 %.3f sat %.3f | x [%.2f ; %.2f] y bas %.2f | lueur %.0f px-éq%s"
              % (n, ok, m["lum"], m["p90"], m["sat"], m["x"][0], m["x"][1], m["y_bas"], m.get("lueur", 0), hal))


if __name__ == "__main__":
    main()
