"""Lecture des aperçus rendus de la foreuse (lot V3, phase 1) : couches posées sur une toile commune.

Python système (numpy + Pillow). Toile : 64 px par tuile (couches hr, scale 0,5), origine = position de
l'entité ; chaque couche est posée à origine + shift × 64 - taille / 2 (entier exact, vérifié).
Niveau 1 = foreuse vanilla composée par vanilla.py (sans integration_patch : D1-3 amendé, Q13).
Niveau 2 = foreuse vanilla + couches de la pièce (chevalement), masquées au pixel par render_levels.py.
"""
import json
import os

import numpy as np
from PIL import Image

import vanilla

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(RENDER, "out", "levels", "drill")
SPEC = os.path.join(OUT, "spec.json")
DIRS = ("N", "E", "S", "W")
PPT = 64
# toile commune (tuiles) : assez large pour la flaque du halo du niveau 30 (rayon nul 3,1 tuiles)
X0, X1, Y0, Y1 = -3.5, 3.5, -5.5, 3.5
W, H = int((X1 - X0) * PPT), int((Y1 - Y0) * PPT)
ORIGIN = (int(-X0 * PPT), int(-Y0 * PPT))

_img_cache = {}


def load_spec():
    with open(SPEC, encoding="utf-8") as f:
        return json.load(f)


def _img(path):
    if path not in _img_cache:
        _img_cache[path] = np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0
    return _img_cache[path]


def place(img, shift, canvas=None):
    """Pose une image RGBA (alpha droit) sur une toile vide (H, W, 4) ; renvoie la toile."""
    out = np.zeros((H, W, 4)) if canvas is None else canvas
    h, w = img.shape[:2]
    x0 = ORIGIN[0] + shift[0] * PPT - w / 2.0
    y0 = ORIGIN[1] + shift[1] * PPT - h / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    assert abs(xi - x0) < 1e-6 and abs(yi - y0) < 1e-6, ("hors grille", shift, w, h)
    xs0, ys0 = max(0, -xi), max(0, -yi)
    xd0, yd0 = max(0, xi), max(0, yi)
    ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
    if ww > 0 and hh > 0:
        out[yd0:yd0 + hh, xd0:xd0 + ww] = img[ys0:ys0 + hh, xs0:xs0 + ww]
    return out


def over_srgb(top, bottom):
    """« Par-dessus » dans l'espace du tampon (sRGB codé), comme le moteur ; alpha droit."""
    ta, ba = top[..., 3:4], bottom[..., 3:4]
    a = ta + ba * (1 - ta)
    pm = top[..., :3] * ta + bottom[..., :3] * ba * (1 - ta)
    rgb = np.where(a > 1e-8, pm / np.maximum(a, 1e-8), 0)
    return np.concatenate([rgb, a], -1)


def vanilla_level1(d):
    """Niveau 1 (vanilla) sur la toile : main (RGBA), shadow (alpha)."""
    c = vanilla.compose(d, canvas=(H, W), origin=ORIGIN)
    return {"main": c["main"], "shadow": c["shadow"], "glow": None, "light": None}


def own_layers(entry):
    """Couches d'un niveau rendu (entrée de spec.json pour une direction) sur la toile."""
    out = {"main": None, "shadow": None, "glow": None, "light": None}
    for k in out:
        sd = entry.get(k)
        if not sd:
            continue
        img = _img(os.path.join(RENDER, sd["file"]))
        lay = place(img, sd["shift"])
        out[k] = lay[..., 3] if k == "shadow" else lay
    return out


def level_layers(spec, level, d, quick=False):
    """Couches du niveau `level` (1 à 30) en direction d : dict main/shadow/glow/light (toile commune).
    quick : aperçus rapides (couche principale seule)."""
    if level == 1:
        return vanilla_level1(d)
    if quick:
        key = "L%02d-%s" % (level, "N" if level == 2 else d)
        if key not in spec.get("quick", {}):
            return None
        lay = own_layers(spec["quick"][key])
        if level == 2:
            # aperçu rapide : la pièce n'est pas masquée ; on la pose DERRIÈRE le vanilla (même rendu
            # qu'un masque par l'alpha vanilla)
            v = vanilla_level1(d)
            lay["main"] = over_srgb(v["main"], lay["main"])
            lay["shadow"] = v["shadow"]
        return lay
    lv = spec["levels"].get("L%02d" % level, {})
    if d not in lv:
        return None
    lay = own_layers(lv[d])
    if level == 2:
        v = vanilla_level1(d)
        # la pièce est déjà masquée par l'alpha vanilla : l'ordre de dessin ne change rien
        lay["main"] = over_srgb(lay["main"], v["main"]) if lay["main"] is not None else v["main"]
        sh = v["shadow"] if lay["shadow"] is None else np.maximum(v["shadow"], lay["shadow"])
        lay["shadow"] = sh
    return lay
