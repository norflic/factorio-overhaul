"""MESURES photométriques du centre-vaisseau contre des sprites vanilla (critère 5 de la grille CENTRE-OPUS).
Corps = pixels d'alpha ≥ 0,5 de la couche principale HR ; luminance sRGB (Rec. 709 sur les valeurs codées, comme
fo_calib.PHOTO_RANGES) ; saturation HSV moyenne ; densité de détail = moyenne |laplacien| / écart-type.

    py -3.9 tools/render/pieces/levels/vaisseau_o/mesure.py --src <sprites> [--noms epave,age01,age08,age15]
"""
import argparse
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.environ.get("FO_DATA_DIR", r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
VAN = {"vanilla:epave-vaisseau": ("crash-site-spaceship/hr-spaceship.png", (0, 0, 1228, 790)),
       "vanilla:raffinerie": ("oil-refinery/hr-oil-refinery.png", (0, 0, 386, 430)),
       "vanilla:assembleur3": ("assembling-machine-3/hr-assembling-machine-3.png", (0, 0, 214, 237))}


def stats(rgba):
    a = rgba[..., 3]
    m = a >= 0.5
    rgb = rgba[..., :3]
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    L = lum[m]
    lap = np.abs(4 * lum[1:-1, 1:-1] - lum[:-2, 1:-1] - lum[2:, 1:-1] - lum[1:-1, :-2] - lum[1:-1, 2:])
    mi = m[1:-1, 1:-1] & m[:-2, 1:-1] & m[2:, 1:-1] & m[1:-1, :-2] & m[1:-1, 2:]
    return {"px": int(m.sum()), "p05": float(np.percentile(L, 5)), "p50": float(np.percentile(L, 50)),
            "p95": float(np.percentile(L, 95)), "moy": float(L.mean()), "ecart": float(L.std()),
            "sat": float(sat[m].mean()), "detail": float(lap[mi].mean() / max(L.std(), 1e-6))}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--noms", default="epave,age01,age08,age15")
    a = ap.parse_args()
    rows = {}
    for k, (f, r) in VAN.items():
        im = Image.open(os.path.join(DATA, "base", "graphics", "entity", f)).convert("RGBA").crop(r)
        rows[k] = stats(np.asarray(im).astype(np.float64) / 255.0)
    for n in [x for x in a.noms.split(",") if x]:
        spec = json.load(open(os.path.join(a.src, n, "spec.json"), encoding="utf-8"))
        im = Image.open(os.path.join(a.src, n, spec["layers"]["main"]["file"])).convert("RGBA")
        rows[n] = stats(np.asarray(im).astype(np.float64) / 255.0)
    print("%-24s %8s %6s %6s %6s %6s %6s %6s %7s" % ("sprite", "px", "p05", "p50", "p95", "moy", "écart", "sat", "détail"))
    for k, s in rows.items():
        print("%-24s %8d %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %7.3f" % (k, s["px"], s["p05"], s["p50"], s["p95"], s["moy"],
                                                                      s["ecart"], s["sat"], s["detail"]))
    print("cibles vanilla (fo_calib.PHOTO_RANGES) : écart 0,177-0,243 ; p95 0,657-0,847 ; p05 0-0,105 ; moyenne 0,178-0,361")


if __name__ == "__main__":
    main()
