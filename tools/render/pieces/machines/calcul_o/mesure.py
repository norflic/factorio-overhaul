"""MESURE PHOTOMÉTRIQUE des machines du calcul contre des bâtiments HR vanilla (lot DA-CALCUL, 4/11 ; même définition que
tools/render/pieces/metallurgie/mesure.py du lot DA-METALLURGIE, pour comparer les familles) : luminance et saturation moyennes
du CORPS (couche principale, alpha ≥ 0,5, hors pixels couverts par la lueur), aire de lueur.

    py -3.9 tools/render/pieces/machines/calcul_o/mesure.py --src DIR [--src DIR ...] [--noms a,b] [--json sortie.json]

Luminance : Y de Rec. 709 sur les valeurs sRGB (0..1) ; saturation : S du modèle TSV, (max − min) / max. Lueur : aire des pixels
d'alpha ≥ 0,05 en tuiles² (64 px par tuile), part écrêtée (alpha ≥ 0,98), luminance moyenne pondérée par l'alpha.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = "F:/Factorio.v1.1.91 Modding/Factorio.v1.1.91"
ENT = ROOT + "/data/base/graphics/entity"
VANILLA = {   # (fichier, largeur, hauteur de la 1re image)
    "electric-furnace": ("electric-furnace/hr-electric-furnace.png", 239, 219),
    "assembling-machine-2": ("assembling-machine-2/hr-assembling-machine-2.png", 214, 218),
    "assembling-machine-3": ("assembling-machine-3/hr-assembling-machine-3.png", 214, 237),
    "chemical-plant": ("chemical-plant/hr-chemical-plant.png", 220, 292),
    "oil-refinery": ("oil-refinery/hr-oil-refinery.png", 386, 430),
    "centrifuge-C": ("centrifuge/hr-centrifuge-C.png", 237, 214),
    "roboport": ("roboport/hr-roboport-base.png", 228, 277),
    "nuclear-reactor": ("nuclear-reactor/hr-reactor.png", 302, 318),
    "lab": ("lab/hr-lab.png", 194, 174),
}


def stats(rgba, exclure=None):
    a = rgba[..., 3]
    m = a >= 0.5
    if exclure is not None:
        m &= ~exclure
    rgb = rgba[..., :3][m]
    if rgb.size == 0:
        return None
    y = 0.2126 * rgb[:, 0] + 0.7152 * rgb[:, 1] + 0.0722 * rgb[:, 2]
    mx, mn = rgb.max(1), rgb.min(1)
    s = np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)
    return {"lum": float(y.mean()), "sat": float(s.mean()), "std": float(y.std()), "p5": float(np.percentile(y, 5)),
            "p95": float(np.percentile(y, 95)), "px": int(m.sum())}


def load(p, w=None, h=None):
    im = Image.open(p).convert("RGBA")
    if w:
        im = im.crop((0, 0, w, h))
    return np.asarray(im).astype(np.float64) / 255.0


def masque_lueur(d, spec):
    L = spec["layers"]
    if "glow" not in L:
        return None
    m, g = L["main"], L["glow"]
    main = Image.open(os.path.join(d, m["file"]))
    glow = load(os.path.join(d, g["file"]))[..., 3] > 0.05
    out = np.zeros((main.height, main.width), bool)
    ox = int(round((g["shift"][0] - m["shift"][0]) * 64 + (main.width - glow.shape[1]) / 2.0))
    oy = int(round((g["shift"][1] - m["shift"][1]) * 64 + (main.height - glow.shape[0]) / 2.0))
    ys, xs = np.nonzero(glow)
    xs, ys = xs + ox, ys + oy
    k = (xs >= 0) & (ys >= 0) & (xs < main.width) & (ys < main.height)
    out[ys[k], xs[k]] = True
    im = Image.fromarray((out * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    return np.asarray(im) > 0


def une(d):
    spec = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
    r = stats(load(os.path.join(d, spec["layers"]["main"]["file"])), masque_lueur(d, spec))
    if "glow" in spec["layers"]:
        g = load(os.path.join(d, spec["layers"]["glow"]["file"]))
        ga = g[..., 3]
        lit = ga >= 0.05
        r["lueur_tuiles2"] = float(lit.sum()) / 4096.0
        r["lueur_ecretee"] = float((ga[lit] >= 0.98).mean()) if lit.any() else 0.0
        yl = 0.2126 * g[..., 0] + 0.7152 * g[..., 1] + 0.0722 * g[..., 2]
        r["lueur_energie"] = float((yl * ga).sum()) / 4096.0
    else:
        r["lueur_tuiles2"] = r["lueur_ecretee"] = r["lueur_energie"] = 0.0
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", action="append", required=True)
    ap.add_argument("--noms", default="")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    noms = set(x for x in a.noms.split(",") if x)
    res = {"vanilla": {}, "calcul": {}}
    for k, (f, w, h) in VANILLA.items():
        res["vanilla"][k] = stats(load(os.path.join(ENT, f), w, h))
    for src in a.src:
        tag = os.path.basename(os.path.normpath(src))
        for n in sorted(os.listdir(src)):
            d = os.path.join(src, n)
            if (noms and n not in noms) or not os.path.exists(os.path.join(d, "spec.json")):
                continue
            res["calcul"]["%s/%s" % (tag, n)] = une(d)
    fmt = "%-26s lum %.3f  sat %.3f  écart-type %.3f  p5 %.3f  p95 %.3f"
    print("VANILLA HR")
    for k, s in res["vanilla"].items():
        print(fmt % (k, s["lum"], s["sat"], s["std"], s["p5"], s["p95"]))
    print("CALCUL")
    for k, s in res["calcul"].items():
        print(fmt % (k, s["lum"], s["sat"], s["std"], s["p5"], s["p95"])
              + "  lueur %.3f tuile² (énergie %.3f, écrêtée %4.1f %%)" % (s["lueur_tuiles2"], s["lueur_energie"], 100 * s["lueur_ecretee"]))
    v = list(res["vanilla"].values())
    print("plage vanilla : lum %.3f à %.3f (moy. %.3f), sat %.3f à %.3f (moy. %.3f)" % (
        min(s["lum"] for s in v), max(s["lum"] for s in v), np.mean([s["lum"] for s in v]),
        min(s["sat"] for s in v), max(s["sat"] for s in v), np.mean([s["sat"] for s in v])))
    if a.json:
        json.dump(res, open(a.json, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    sys.exit(main())
