"""Tourelle laser, lot V3 phase 1 : composition hors moteur des niveaux (Python système, numpy + Pillow).

Assemble les couches d'un niveau (vanilla pour le niveau 1, vanilla + pièce pour le niveau 2, rendus d'aperçu
ensuite) dans l'ordre du moteur, comme tools/render/calib/maquette.py (fonctions importées sans modification) :
1. ombres de toutes les entités (maximum des alphas), sol × (1 − 0,5 × alpha) (shadow-a8.frag) ;
2. couche lower-object (socles) de toutes les entités, puis couche object (têtes), triées par y puis x ;
3. lueur (draw_as_glow) additive, ajoutée au jour et à la carte des lumières ;
4. nuit : mix(LUT_nuit(jour), jour, lumière) (game.frag), lumière = halos + lueurs, bornée à [0, 1].
lightMul et lightAdd du moteur sont inconnus (pris à 1 et 0) : la nuit hors moteur n'est PAS une preuve.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "calib"))
import fo_post as P  # noqa: E402
import laser_design as D  # noqa: E402
from maquette import lut_apply, down2  # noqa: E402

OUT = os.path.join(RENDER, "out", "levels", "laser")
DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
_cache = {}


def load_rgba(path):
    if path not in _cache:
        _cache[path] = np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0
    return _cache[path]


def vanilla_layer(key, frame=0, kind="main", order="lower"):
    s = D.VANILLA[key]
    im = load_rgba(os.path.join(DATA, "base", "graphics", "entity", s["file"]))
    ll = s.get("line_length", 1)
    fx, fy = frame % ll, frame // ll
    img = im[fy * s["h"]:(fy + 1) * s["h"], fx * s["w"]:(fx + 1) * s["w"]]
    x0 = s["shift"][0] * 64 - s["w"] / 2.0
    y0 = s["shift"][1] * 64 - s["h"] / 2.0
    assert abs(x0 - round(x0)) < 1e-6 and abs(y0 - round(y0)) < 1e-6, (key, x0, y0)
    return {"img": img, "x0": int(round(x0)), "y0": int(round(y0)), "kind": kind, "order": order}


def own_layer(level, part, layer, order):
    p = os.path.join(OUT, "L%02d" % level, "%s-%s.png" % (part, layer))
    if not os.path.exists(p):
        return None
    return {"img": load_rgba(p), "x0": -D.ORIGIN_PX[0], "y0": -D.ORIGIN_PX[1], "kind": layer, "order": order}


def level_layers(level, direction="E", with_glow=True):
    """Couches d'un niveau dans une direction de tête (N, E, S, W)."""
    lays = []
    fr = D.DIR_FRAME[direction]
    if level <= 2:
        lays.append(vanilla_layer("base_shadow", kind="shadow"))
        lays.append(vanilla_layer("base", order="lower"))
        lays.append(vanilla_layer("head_shadow", frame=fr, kind="shadow"))
        lays.append(vanilla_layer("head", frame=fr, order="object"))
        if level == 2:
            for k in ("shadow", "main", "glow", "light"):
                l2 = own_layer(2, "base", k, "lower")
                if l2 is not None and (with_glow or k in ("shadow", "main")):
                    lays.append(l2)
        return lays
    odd = level if level % 2 else level - 1
    for k in ("shadow", "main", "glow", "light"):
        l2 = own_layer(level, "base", k, "lower")
        if l2 is not None and (with_glow or k in ("shadow", "main")):
            lays.append(l2)
    for k in ("shadow", "main", "glow", "light"):
        l2 = own_layer(odd, direction, k, "object")
        if l2 is not None and (with_glow or k in ("shadow", "main")):
            lays.append(l2)
    return lays


def ground(W, H):
    g = load_rgba(os.path.join(DATA, "base", "graphics", "terrain", "hr-dirt-4.png"))[320:576, :, :3]
    gh, gw = g.shape[:2]
    return np.tile(g, (H // gh + 1, W // gw + 1, 1))[:H, :W].copy()


def compose(entities, W, H, bg=None):
    """entities : [{pos: (px_x, px_y) au zoom 2 (64 px/tuile), layers: [...]}]. Renvoie (jour, nuit, alpha des objets)."""
    day = ground(W, H) if bg is None else np.ones((H, W, 3)) * np.array(bg)
    shadow = np.zeros((H, W))
    light = np.zeros((H, W, 3))
    cover = np.zeros((H, W))

    def region(lay, pos):
        h, w = lay["img"].shape[:2]
        xi, yi = int(pos[0]) + lay["x0"], int(pos[1]) + lay["y0"]
        xs0, ys0 = max(0, -xi), max(0, -yi)
        xd0, yd0 = max(0, xi), max(0, yi)
        ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
        if ww <= 0 or hh <= 0:
            return None, None
        return (slice(ys0, ys0 + hh), slice(xs0, xs0 + ww)), (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))

    for e in entities:
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                s, d = region(lay, e["pos"])
                if s is not None:
                    shadow[d] = np.maximum(shadow[d], lay["img"][s][..., 3])
    day = day * (1 - 0.5 * shadow)[..., None]
    for order in ("lower", "object"):
        for e in sorted(entities, key=lambda e: (e["pos"][1], e["pos"][0])):
            for lay in e["layers"]:
                if lay["kind"] == "shadow" or lay["order"] != order:
                    continue
                s, d = region(lay, e["pos"])
                if s is None:
                    continue
                src = lay["img"][s]
                a = src[..., 3:4]
                if lay["kind"] == "main":
                    day[d] = src[..., :3] * a + day[d] * (1 - a)
                    cover[d] = a[..., 0] + cover[d] * (1 - a[..., 0])
                elif lay["kind"] == "glow":
                    day[d] = np.clip(day[d] + src[..., :3] * a, 0, 1)
                    light[d] += src[..., :3] * a
                elif lay["kind"] == "light":
                    light[d] += src[..., :3] * a
    light = np.clip(light, 0, 1)
    night_lut = lut_apply(day, os.path.join(DATA, "core", "graphics", "color_luts", "lut-night.png"))
    night = night_lut * (1 - light) + day * light
    return day, night, cover


def mask_of(level, direction, thr=0.5):
    """Masque D1 (alpha ≥ 128) des couches principales (socle + tête), sur le canevas fixe, 64 px/tuile.
    Sans ombre, lueur ni halo (bible §1.4) ; aucune couche plate au sol n'existe dans ces rendus."""
    W, H = D.CANVAS_W, D.CANVAS_H
    a = np.zeros((H, W))
    lays = [l for l in level_layers(level, direction, with_glow=False) if l["kind"] == "main"]
    for order in ("lower", "object"):
        for lay in lays:
            if lay["order"] != order:
                continue
            h, w = lay["img"].shape[:2]
            xi, yi = D.ORIGIN_PX[0] + lay["x0"], D.ORIGIN_PX[1] + lay["y0"]
            src = lay["img"][..., 3]
            a[yi:yi + h, xi:xi + w] = src + a[yi:yi + h, xi:xi + w] * (1 - src)
    return a >= thr


def to_img(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")
