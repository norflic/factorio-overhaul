"""Chargement des couches d'un niveau du mur (aperçus V3 phase 1 et sprites vanilla du niveau 1).

Python système (numpy + Pillow). Une couche = {"img": RGBA float (alpha droit), "shift": (sx, sy) tuiles,
"kind": main|shadow|glow|light}. Les aperçus sont lus dans tools/render/out/levels/wall/ d'après
render_results.json ; le niveau 1 vient des sprites vanilla (image 0), le niveau 2 = vanilla + pièce.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(RENDER, "out", "levels", "wall")
RESULTS = os.path.join(OUT, "render_results.json")
DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
sys.path.insert(0, HERE)
import wall_piece  # noqa: E402

_cache = {}


def load_png(path):
    if path not in _cache:
        _cache[path] = np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0
    return _cache[path]


def results():
    with open(RESULTS, encoding="utf-8") as f:
        return json.load(f)


def vanilla_layers(pose, res="hr"):
    v = wall_piece.VANILLA[pose]
    out = []
    rel, w, h, shift = v["shadow_" + res]
    img = load_png(os.path.join(DATA, "base", "graphics", "entity", rel))[:h, :w].copy()
    if img[..., :3].max() > 0.2:      # ombres en gris + alpha : on garde l'alpha, couleur noire
        img[..., :3] = 0.0
    out.append({"img": img, "shift": shift, "kind": "shadow"})
    rel, w, h, shift = v[res]
    out.append({"img": load_png(os.path.join(DATA, "base", "graphics", "entity", rel))[:h, :w], "shift": shift,
                "kind": "main"})
    return out


def level_layers(level, pose, res="hr", res_db=None):
    """Couches d'un niveau, dans l'ordre de dessin (ombre, principale, lueur, halo)."""
    if level == 1:
        return vanilla_layers(pose, res)
    db = res_db or results()
    r = db["n%02d-%s" % (level, pose)]
    out = []
    if level == 2:
        out += vanilla_layers(pose, res)
    for layer in ("shadow", "main", "glow", "light"):
        if layer in r["spec"]:
            sd = r["spec"][layer][res]
            out.append({"img": load_png(os.path.join(OUT, r["dir"], sd["filename"])), "shift": tuple(sd["shift"]),
                        "kind": layer})
    return out
