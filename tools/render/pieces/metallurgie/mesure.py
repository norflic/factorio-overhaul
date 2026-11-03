"""MESURE PHOTOMÉTRIQUE de la famille MÉTALLURGIE contre des bâtiments HR vanilla (note du lead, 3/11 23 h) : luminance moyenne et
saturation moyenne du CORPS (couche principale, alpha ≥ 0,5, hors pixels couverts par la lueur), même définition des deux côtés.

    py -3.9 tools/render/pieces/metallurgie/mesure.py --src DIR [--json sortie.json]

Luminance : Y de Rec. 709 sur les valeurs sRGB (0..1) ; saturation : S du modèle TSV, (max − min) / max ; médiane donnée aussi.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = "F:/Factorio.v1.1.91 Modding/Factorio.v1.1.91"
ENT = ROOT + "/data/base/graphics/entity"
VANILLA = {   # (fichier, largeur, hauteur de la 1re image)
    "stone-furnace": ("stone-furnace/hr-stone-furnace.png", 151, 146),
    "steel-furnace": ("steel-furnace/hr-steel-furnace.png", 171, 174),
    "electric-furnace": ("electric-furnace/hr-electric-furnace.png", 239, 219),
    "assembling-machine-1": ("assembling-machine-1/hr-assembling-machine-1.png", 214, 226),
    "assembling-machine-2": ("assembling-machine-2/hr-assembling-machine-2.png", 214, 218),
    "chemical-plant": ("chemical-plant/hr-chemical-plant.png", 220, 292),
    "oil-refinery": ("oil-refinery/hr-oil-refinery.png", 386, 430),
    "boiler": ("boiler/hr-boiler-N-idle.png", 269, 221),
    "big-electric-pole": ("big-electric-pole/hr-big-electric-pole.png", 148, 312),
    "centrifuge-C": ("centrifuge/hr-centrifuge-C.png", 237, 214),
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
    # teinte (degrés) ; « chaud » : rouge à orange-jaune (0 à 50°), saturation ≥ 0,25, pas noir
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    hue = np.degrees(np.arctan2(np.sqrt(3.0) * (g - b), 2.0 * r - g - b)) % 360.0
    chaud = ((hue <= 50.0) | (hue >= 345.0)) & (s >= 0.25) & (y >= 0.05)
    return {"lum": float(y.mean()), "lum_med": float(np.median(y)), "sat": float(s.mean()), "sat_med": float(np.median(s)),
            "std": float(y.std()), "p5": float(np.percentile(y, 5)), "p95": float(np.percentile(y, 95)),
            "chaud": float(chaud.mean()), "px": int(m.sum())}


def load(p, w=None, h=None):
    im = Image.open(p).convert("RGBA")
    if w:
        im = im.crop((0, 0, w, h))
    return np.asarray(im).astype(np.float64) / 255.0


def masque_lueur(d, spec):
    """Pixels de la couche principale couverts par la lueur (alpha de lueur > 0,05), recalés par les shifts."""
    L = spec["layers"]
    if "glow" not in L:
        return None
    m, g = L["main"], L["glow"]
    main = Image.open(os.path.join(d, m["file"]))
    glow = load(os.path.join(d, g["file"]))[..., 3] > 0.05
    out = np.zeros((main.height, main.width), bool)
    # centre de l'image = position + shift ; coin haut-gauche de la lueur dans le repère de la principale
    ox = int(round((g["shift"][0] - m["shift"][0]) * 64 + (main.width - glow.shape[1]) / 2.0))
    oy = int(round((g["shift"][1] - m["shift"][1]) * 64 + (main.height - glow.shape[0]) / 2.0))
    ys, xs = np.nonzero(glow)
    xs, ys = xs + ox, ys + oy
    k = (xs >= 0) & (ys >= 0) & (xs < main.width) & (ys < main.height)
    out[ys[k], xs[k]] = True
    # marge de 2 px : le bord de la lueur déborde sur le corps clair
    from PIL import ImageFilter
    im = Image.fromarray((out * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    return np.asarray(im) > 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    res = {"vanilla": {}, "met": {}}
    for k, (f, w, h) in VANILLA.items():
        res["vanilla"][k] = stats(load(os.path.join(ENT, f), w, h))
    for n in sorted(os.listdir(a.src)):
        d = os.path.join(a.src, n)
        p = os.path.join(d, "spec.json")
        if not os.path.exists(p):
            continue
        spec = json.load(open(p, encoding="utf-8"))
        main_ = load(os.path.join(d, spec["layers"]["main"]["file"]))
        res["met"][n] = stats(main_, masque_lueur(d, spec))
        if "glow" in spec["layers"]:
            ga = load(os.path.join(d, spec["layers"]["glow"]["file"]))[..., 3]
            lit = ga >= 0.05
            res["met"][n]["lueur_ecretee"] = float((ga[lit] >= 0.98).mean()) if lit.any() else 0.0
            res["met"][n]["lueur_tuiles2"] = float(lit.sum()) / 4096.0
        res["met"][n]["atlas"] = [spec["layers"][k]["width"] * spec["layers"][k]["height"] for k in sorted(spec["layers"])]
    fmt = "%-22s lum %.3f  sat %.3f  écart-type %.3f  p5 %.3f  p95 %.3f  chaud %4.1f %%"
    print("VANILLA HR")
    for k, s in res["vanilla"].items():
        print(fmt % (k, s["lum"], s["sat"], s["std"], s["p5"], s["p95"], 100 * s["chaud"]))
    print("MÉTALLURGIE")
    for k, s in res["met"].items():
        print(fmt % (k, s["lum"], s["sat"], s["std"], s["p5"], s["p95"], 100 * s["chaud"])
              + ("  lueur écrêtée %4.1f %% sur %.2f tuile²" % (100 * s["lueur_ecretee"], s["lueur_tuiles2"]) if "lueur_ecretee" in s else ""))
    v = [s for s in res["vanilla"].values()]
    m = [s for s in res["met"].values()]
    print("moyennes : vanilla lum %.3f sat %.3f ; métallurgie lum %.3f sat %.3f" % (
        np.mean([s["lum"] for s in v]), np.mean([s["sat"] for s in v]), np.mean([s["lum"] for s in m]), np.mean([s["sat"] for s in m])))
    if a.json:
        json.dump(res, open(a.json, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    sys.exit(main())
