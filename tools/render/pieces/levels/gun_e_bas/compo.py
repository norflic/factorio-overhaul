"""Composition hors moteur (lot V3-E, époques 1 à 9) : sol vanilla, ombres, entités, lueur, halo, nuit (LUT de
game.frag), à 64 px/tuile ; réduction au zoom 1 en lumière linéaire. Reprend planche.py de la lignée (même
méthode que tools/render/calib/maquette.py) ; utilisé par planches.py, vignettes.py et apercu.py.

lightMul/lightAdd du moteur inconnus (pris à 1 et 0) : la nuit n'est qu'une approximation hors moteur.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
ROOT = "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91"
DATA = ROOT + "/data"
DUMPS = ROOT + "/fo-logs/2026-10-22_V3S/industriel/dumps"
OUTILS = os.path.join(MOD, "tools", "da")
WORK = os.environ.get("FO_IND_WORK", ROOT + "/fo-logs/2026-10-22_V3E/bas")
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "calib"))
sys.path.insert(0, OUTILS)
import fo_post as P  # noqa: E402
from maquette import lut_apply  # noqa: E402
import da_lib as D  # noqa: E402

SIDE = {1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4}
NAME = {1: "Pionnier", 2: "Forge", 3: "Vapeur", 4: "Pétrole", 5: "Volcan", 6: "Électricité", 7: "Cristal",
        8: "Marais", 9: "Atome"}


def font(size, bold=True):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/%s.ttf" % ("arialbd" if bold else "arial"), size)
    except OSError:
        return ImageFont.load_default()


def own(out, name, kinds=("shadow", "main", "glow", "light")):
    p = os.path.join(out, name, "spec.json")
    if not os.path.exists(p):
        return []
    spec = json.load(open(p, encoding="utf-8"))
    res = []
    for k in kinds:
        if k in spec["layers"]:
            s = spec["layers"][k]
            img = np.asarray(Image.open(os.path.join(out, name, s["file"])).convert("RGBA")).astype(np.float64) / 255
            res.append({"img": img, "shift": tuple(s["shift"]), "kind": k, "file": s["file"]})
    return res


_VAN = {}


def vanilla(dump, fn, key):
    if key in _VAN:
        return _VAN[key]
    d = D.parse_dump(open(os.path.join(DUMPS, dump + ".txt"), encoding="utf-8", errors="replace").read())
    nodes = [n for n in fn(d) if n[0] is not None]
    lays = D.vanilla_layers(nodes, DATA)
    r = [{"img": l["img"].astype(np.float64), "shift": l["shift"], "kind": l["kind"]} for l in lays]
    _VAN[key] = r
    return r


def vanilla_gun(pose):
    return vanilla("ammo-turret_gun-turret",
                   lambda d: [(d["base_picture"], 0, None), (d["prepared_animation"], 0 if pose == "N" else pose, None)],
                   "gun-" + pose)


def vanilla_reactor():
    return vanilla("reactor_nuclear-reactor", lambda d: [(d["lower_layer_picture"], 0, None), (d["picture"], 0, None),
                                                         (d["working_light_picture"], 0, "light")], "reactor")


def level_layers(out, e, pose, even=False, kinds=("shadow", "main", "glow", "light")):
    """Couches d'un niveau : socle (+ pièce paire) + tête ; époque 1 : vanilla (+ pièce du niveau 2)."""
    if e == 1:
        lays = list(vanilla_gun(pose))
        if even:
            # la pièce du niveau 2 (plancher, sacs de sable, caisse) est dessinée SOUS le vanilla (spec : sous_vanilla)
            lays = own(out, "e01-piece", kinds) + [l for l in lays]
        return lays
    lays = own(out, "e%02d-socle" % e, kinds)
    if even:
        lays += own(out, "e%02d-piece" % e, kinds)
    lays += own(out, "e%02d-tete-%s" % (e, pose), kinds)
    return lays


def ground_tile():
    return np.asarray(Image.open(os.path.join(DATA, "base", "graphics", "terrain", "hr-dirt-4.png"))
                      .convert("RGB")).astype(np.float64)[320:576] / 255.0


def compose(ents, W_t, H_t, ppt=64):
    W, H = int(W_t * ppt), int(H_t * ppt)
    ground = ground_tile()
    gh, gw = ground.shape[:2]
    day = np.tile(ground, (H // gh + 1, W // gw + 1, 1))[:H, :W].copy()
    shadow = np.zeros((H, W))
    light = np.zeros((H, W, 3))

    def place(lay, pos):
        img = lay["img"]
        h, w = img.shape[:2]
        x0 = int(round(pos[0] * ppt + lay["shift"][0] * ppt - w / 2.0))
        y0 = int(round(pos[1] * ppt + lay["shift"][1] * ppt - h / 2.0))
        xs0, ys0 = max(0, -x0), max(0, -y0)
        xd0, yd0 = max(0, x0), max(0, y0)
        ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
        if ww <= 0 or hh <= 0:
            return None, None
        return img[ys0:ys0 + hh, xs0:xs0 + ww], (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))

    for e in ents:
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                src, d = place(lay, e["pos"])
                if src is not None:
                    shadow[d] = np.maximum(shadow[d], src[..., 3])
    day = day * (1 - 0.5 * shadow)[..., None]
    for e in sorted(ents, key=lambda e: (e["pos"][1], e["pos"][0])):
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                continue
            src, d = place(lay, e["pos"])
            if src is None:
                continue
            a = src[..., 3:4]
            if lay["kind"] == "main":
                day[d] = src[..., :3] * a + day[d] * (1 - a)
            elif lay["kind"] == "mask":
                lum = src[..., :3].mean(-1, keepdims=True)
                day[d] = lum * np.array((0.869, 0.5, 0.13)) * a + day[d] * (1 - a)
            elif lay["kind"] == "glow":
                day[d] = np.clip(day[d] + src[..., :3] * a, 0, 1)
                light[d] += src[..., :3] * a
            elif lay["kind"] == "light":
                light[d] += src[..., :3] * a
    light = np.clip(light, 0, 1)
    night = lut_apply(day, os.path.join(DATA, "core", "graphics", "color_luts", "lut-night.png"))
    night = night * (1 - light) + day * light
    return day, night


def down2(rgb):
    h, w = rgb.shape[:2]
    lin = P.srgb_to_lin(rgb[:h // 2 * 2, :w // 2 * 2])
    return P.lin_to_srgb(lin.reshape(h // 2, 2, w // 2, 2, 3).mean((1, 3)))


def to_im(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def body_comp(lays):
    """Composition « corps seul » de da_lib (main, glow, light), pour les mesures."""
    L = [{"img": l["img"].copy(), "shift": l["shift"], "kind": l["kind"]} for l in lays
         if l["kind"] in ("main", "glow", "light")]
    return D.compose(L)
