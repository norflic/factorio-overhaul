"""Composition hors moteur des niveaux du four (lot V3, phase 1) : couches, masques, scènes jour et nuit.

Python système (numpy, Pillow). Reprend les formules de tools/render/calib/maquette.py (lot V0), sans
modifier ce fichier :
- ombres : maximum des alphas, sol × (1 − 0,5 × alpha) (core/graphics/shaders/shadow-a8.frag) ;
- entités triées par y puis x, couches dans l'ordre du prototype ;
- lueur (draw_as_glow, additive) ajoutée de jour et à la carte des lumières ; halo (draw_as_light) dans la
  seule carte des lumières ;
- nuit : mix(LUT_nuit(jour), jour, lumière) avec core/graphics/color_luts/lut-night.png (game.frag) ;
  lightMul et lightAdd du moteur inconnus, pris à 1 et 0 : NON PROUVÉ hors moteur.
Le niveau 1 est le four en acier vanilla EN MARCHE (feu, intérieur allumé, lumière au sol), pour comparer
à égalité avec les niveaux rendus, montrés allumés.
Correction V3 : couches « patch » (plaque au sol, integration_patch : dessinée sous les ombres et les
corps), « glowdeco » (lueurs de décor, always_draw : visibles four à l'arrêt) ; level_layers(n, working=False)
montre le four À L'ARRÊT (ni feu « glow » ni halo « light », comme le vanilla sans ses working_visualisations).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "calib"))
sys.path.insert(0, RENDER)
OUT = os.path.join(RENDER, "out", "levels", "furnace")
DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
ENT = os.path.join(DATA, "base", "graphics", "entity")
PPT = 64


def bp(x, y):
    return (x / 32.0, y / 32.0)


def load(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


def frame(img, w, h, fx=0, fy=0):
    return img[fy * h:(fy + 1) * h, fx * w:(fx + 1) * w]


def vanilla_layers(working=True):
    """Four en acier vanilla (entities.lua:7278-7425), couches HR avec leur shift."""
    d = os.path.join(ENT, "steel-furnace")
    L = [{"img": load(os.path.join(d, "hr-steel-furnace-shadow.png")), "shift": bp(39.25, 11.25), "kind": "shadow"},
         {"img": load(os.path.join(d, "hr-steel-furnace.png")), "shift": bp(-1.25, 2), "kind": "main"}]
    if working:
        L.append({"img": frame(load(os.path.join(d, "hr-steel-furnace-fire.png")), 57, 81), "shift": bp(-0.75, 5.75),
                  "kind": "main+light"})
        L.append({"img": load(os.path.join(d, "hr-steel-furnace-working.png")), "shift": bp(0, -5), "kind": "glow"})
        L.append({"img": load(os.path.join(d, "hr-steel-furnace-ground-light.png")), "shift": bp(1, 48), "kind": "light"})
    return L


def spec(n):
    with open(os.path.join(OUT, "n%02d" % n, "spec.json"), encoding="utf-8") as f:
        return json.load(f)


def own_layers(n, kinds=("patch", "shadow", "main", "glow", "glowdeco", "light")):
    sp = spec(n)
    out = []
    for k in kinds:
        if k in sp["layers"]:
            s = sp["layers"][k]
            out.append({"img": load(os.path.join(OUT, "n%02d" % n, s["filename"])), "shift": tuple(s["shift"]), "kind": k})
    return out


def level_layers(n, working=True):
    if n == 1:
        return vanilla_layers(working)
    if n == 2:
        v = vanilla_layers(working)
        # la pièce du niveau 2 est DERRIÈRE le corps (déjà masquée au pixel) : ombre avec les ombres,
        # couche principale avant le corps vanilla dans l'ordre de dessin
        own = own_layers(2)
        return [l for l in own if l["kind"] == "shadow"] + [l for l in own if l["kind"] != "shadow"] + \
            [l for l in v if l["kind"] != "shadow"] + [l for l in v if l["kind"] == "shadow"]
    kinds = ("patch", "shadow", "main", "glow", "glowdeco", "light") if working else ("patch", "shadow", "main", "glowdeco")
    return own_layers(n, kinds)


def mask_canvas(x0=-2.5, x1=2.5, y0=-3.5, y1=1.75):
    W, H = int((x1 - x0) * PPT), int((y1 - y0) * PPT)
    return {"x0": x0, "y0": y0, "W": W, "H": H}


def paste_alpha(cv, acc, img_a, shift, thr=0.5):
    h, w = img_a.shape
    xx = (shift[0] - cv["x0"]) * PPT - w / 2.0
    yy = (shift[1] - cv["y0"]) * PPT - h / 2.0
    xi, yi = int(round(xx)), int(round(yy))
    assert abs(xx - xi) < 1e-6 and abs(yy - yi) < 1e-6, (shift, w, h)
    xs0, ys0 = max(0, -xi), max(0, -yi)
    xd0, yd0 = max(0, xi), max(0, yi)
    ww, hh = min(w - xs0, cv["W"] - xd0), min(h - ys0, cv["H"] - yd0)
    acc[yd0:yd0 + hh, xd0:xd0 + ww] |= img_a[ys0:ys0 + hh, xs0:xs0 + ww] >= thr


def objmask(n, cv):
    """Masque de silhouette D1 (alpha >= 0,5, couches principales sans liseré de contact, sans ombre, lueur
    ni halo). Niveau 1 : alpha du sprite vanilla (son liseré est cuit dedans : environ 3 px au seuil 0,5)."""
    m = np.zeros((cv["H"], cv["W"]), bool)
    if n in (1, 2):
        v = vanilla_layers(False)[1]
        paste_alpha(cv, m, v["img"][..., 3], v["shift"])
    if n >= 2:
        s = spec(n)["layers"]["objmask"]
        a = load(os.path.join(OUT, "n%02d" % n, s["filename"]))[..., 3]
        paste_alpha(cv, m, a, s["shift"])
    return m


def ground_tile():
    return load(os.path.join(DATA, "base", "graphics", "terrain", "hr-dirt-4.png"))[320:576, :, :3]


def compose(entities, W_t, H_t, ppt=PPT):
    """entities : [{pos: (x, y) tuiles, layers}] ; renvoie (jour RGB, lumière RGB), 64 px/tuile."""
    W, H = int(W_t * ppt), int(H_t * ppt)
    g = ground_tile()
    day = np.tile(g, (H // g.shape[0] + 1, W // g.shape[1] + 1, 1))[:H, :W].copy()
    shadow = np.zeros((H, W))
    light = np.zeros((H, W, 3))

    def place(lay, pos):
        img = lay["img"]
        h, w = img.shape[:2]
        x0 = pos[0] * ppt + lay["shift"][0] * ppt - w / 2.0
        y0 = pos[1] * ppt + lay["shift"][1] * ppt - h / 2.0
        xi, yi = int(round(x0)), int(round(y0))
        assert abs(xi - x0) < 1e-6 and abs(yi - y0) < 1e-6, (x0, y0)
        xs0, ys0 = max(0, -xi), max(0, -yi)
        xd0, yd0 = max(0, xi), max(0, yi)
        ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
        return img[ys0:ys0 + hh, xs0:xs0 + ww], (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))

    # plaques au sol (integration_patch, couche lower-object) : sous les ombres et sous tous les corps
    for e in entities:
        for lay in e["layers"]:
            if lay["kind"] == "patch":
                src, d = place(lay, e["pos"])
                a = src[..., 3:4]
                day[d] = src[..., :3] * a + day[d] * (1 - a)
    for e in entities:
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                src, d = place(lay, e["pos"])
                shadow[d] = np.maximum(shadow[d], src[..., 3])
    day = day * (1 - 0.5 * shadow)[..., None]
    for e in sorted(entities, key=lambda e: (e["pos"][1], e["pos"][0])):
        for lay in e["layers"]:
            k = lay["kind"]
            if k in ("shadow", "patch"):
                continue
            src, d = place(lay, e["pos"])
            a = src[..., 3:4]
            if k in ("main", "main+light"):
                day[d] = src[..., :3] * a + day[d] * (1 - a)
                if k == "main+light":
                    light[d] += src[..., :3] * a
            elif k in ("glow", "glowdeco"):
                day[d] = np.clip(day[d] + src[..., :3] * a, 0, 1)
                light[d] += src[..., :3] * a
            elif k == "light":
                light[d] += src[..., :3] * a
    return day, np.clip(light, 0, 1)


def night(day, light):
    from maquette import lut_apply  # tools/render/calib/maquette.py (lecture seule)
    nl = lut_apply(day, os.path.join(DATA, "core", "graphics", "color_luts", "lut-night.png"))
    return nl * (1 - light) + day * light


def down2(rgb):
    import fo_post as P
    h, w = rgb.shape[:2]
    lin = P.srgb_to_lin(rgb[:h // 2 * 2, :w // 2 * 2])
    lin = lin.reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3))
    return P.lin_to_srgb(lin)


def gray(rgb):
    L = rgb @ np.array([0.2126, 0.7152, 0.0722])
    return np.repeat(L[..., None], 3, -1)


def to_img(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")
