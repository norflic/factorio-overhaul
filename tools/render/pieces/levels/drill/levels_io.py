"""Lecture des aperçus rendus de la foreuse (lot V3, phase 1) : couches posées sur une toile commune.

Python système (numpy + Pillow). Toile : 64 px par tuile (couches hr, scale 0,5), origine = position de
l'entité ; chaque couche est posée à origine + shift × 64 - taille / 2 (entier exact, vérifié).
Niveau 1 = foreuse vanilla composée par vanilla.py (sans integration_patch : D1-3 amendé, Q13).
Niveau 2 = foreuse vanilla + couches de la pièce (chevalement), masquées au pixel par render_levels.py.

Halo de nuit (D2-3, bible §1.6 ; correction V3 du 22/10 après vérification adverse) : LightDefinition de
working_visualisations (always_draw), PAS une couche rendue :
  intensité I(N) = 0,05 + 0,02·N ; rayon (champ `size` de LightDefinition, « radius of the light in tiles »,
  prototype-api.json 1.1.91) S(N) = s × (1 + 0,05·N) avec s = 1,5 tuile (demi-côté de l'emprise 3×3,
  proposition ❔) ; couleur = émissif de l'époque (catalogue.py), ramenée à une luminance de 0,55 (teinte
  gardée) pour que l'énergie perçue suive I(N) et S(N) quelle que soit la teinte ; texture du moteur
  __core__/graphics/light-medium.png (300 × 300 px pour 2·S tuiles de côté). Niveau 1 (vanilla, Q11) :
  aucun halo de niveau. Les lumières vanilla de la foreuse (DEL d'état, lumière de travail) sont communes à
  tous les niveaux et ne sont pas composées (foreuse à l'arrêt). Énergie du halo E(N) = I × luminance de la
  couleur × moyenne de la texture × (2·S)² (tuiles², « tuile pleine blanche ») : strictement croissante.
"""
import json
import os

import numpy as np
from PIL import Image

import catalogue
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

LIGHT_TEX = os.path.join(vanilla.DATA, "core", "graphics", "light-medium.png")
HALO_S0 = 1.5          # s (tuiles) : demi-côté de l'emprise 3×3 (proposition)
HALO_LUM = 0.55        # luminance commune des couleurs de halo (Rec. 709 sur sRGB)
LUMA = np.array([0.2126, 0.7152, 0.0722])
_tex = []


def halo_intensity(level):
    return 0.05 + 0.02 * level


def halo_radius(level):
    return HALO_S0 * (1.0 + 0.05 * level)


def halo_color(epoch):
    """Couleur émissive de l'époque, teinte gardée, ramenée à la luminance HALO_LUM."""
    h = catalogue.EPOCHS[epoch]["emissif"].lstrip("#")
    c = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    c = c / c.max()
    lum = float(c @ LUMA)
    if lum >= HALO_LUM:
        c = c * HALO_LUM / lum
    else:
        t = (HALO_LUM - lum) / (1.0 - lum)
        c = c + t * (1.0 - c)
    return [round(float(x), 4) for x in c]


def _texture():
    if not _tex:
        a = np.asarray(Image.open(LIGHT_TEX).convert("LA")).astype(np.float64) / 255.0
        _tex.append(a[..., 0])
    return _tex[0]


def level_halo(level):
    """LightDefinition du halo de nuit du niveau (None au niveau 1, vanilla)."""
    if level < 2:
        return None
    e = (level + 1) // 2
    col = halo_color(e)
    I, S = halo_intensity(level), halo_radius(level)
    energy = I * float(np.array(col) @ LUMA) * float(_texture().mean()) * (2 * S) ** 2
    return {"type": "basic", "intensity": round(I, 4), "size": round(S, 4), "color": {"r": col[0], "g": col[1],
            "b": col[2]}, "shift": [0, 0], "minimum_darkness": 0.1, "energy_t2": round(energy, 4)}


def halo_map(level, shape=None, origin=None):
    """Carte de lumière (RGB prémultiplié, toile commune) du halo du niveau, comme le moteur : texture
    light-medium étirée sur 2·S tuiles, × intensité × couleur."""
    h = level_halo(level)
    hh, ww = shape or (H, W)
    ox, oy = origin or ORIGIN
    out = np.zeros((hh, ww, 3))
    if h is None:
        return out
    side = 2 * h["size"] * PPT
    n = int(round(side))
    tex = np.asarray(Image.fromarray(np.uint8(np.round(_texture() * 255))).resize((n, n), Image.BILINEAR)
                     ).astype(np.float64) / 255.0
    x0, y0 = int(round(ox - n / 2.0)), int(round(oy - n / 2.0))
    xs0, ys0 = max(0, -x0), max(0, -y0)
    xd0, yd0 = max(0, x0), max(0, y0)
    w2, h2 = min(n - xs0, ww - xd0), min(n - ys0, hh - yd0)
    col = np.array([h["color"][k] for k in "rgb"])
    out[yd0:yd0 + h2, xd0:xd0 + w2] = tex[ys0:ys0 + h2, xs0:xs0 + w2, None] * h["intensity"] * col
    return out


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
    return {"main": c["main"], "shadow": c["shadow"], "glow": None, "light": None, "halo": None}


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
    lay = _level_layers(spec, level, d, quick)
    if lay is not None:
        lay["halo"] = halo_map(level)
    return lay


def _level_layers(spec, level, d, quick=False):
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
