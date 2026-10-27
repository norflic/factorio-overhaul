"""OUTIL COMMUN : composition hors moteur (sol vanilla, ombres, entités, lueur, halo, nuit par la LUT de game.frag),
à 64 px/tuile, réduction au zoom 1 en lumière linéaire. Utilisé par apercu.py, vignettes.py, gris.py, mesures.py,
ilots.py. Python 3.9 (numpy). FICHIER GELÉ.

lightMul/lightAdd du moteur inconnus (pris à 1 et 0) : la nuit n'est qu'une approximation hors moteur.
Sources de sprites : un dossier de sortie de rendre.py (variantes eNN-…, kS-…). Pour comparer à la passe 3, un
dossier « passe 3 » se donne comme couple (bas, haut) : ref_dirs() les reconnaît.
LOT K0 (23/10) : outil COMMUN des familles. Ce qui est propre à une famille (composition d'un niveau, noms des
variantes, référence vanilla, emprise par âge) vient de son profil (commun/famille.py, <famille>/profil.py) : PROFIL,
choisi par utiliser(nom) (option --famille des outils ; défaut : variable FO_FAMILLE, sinon gun_e). level_layers()
appelle PROFIL.level_layers ; SIDE et NAME suivent le profil (noms des âges : commun/ages.py).
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
ROOT = "F:/Factorio.v1.1.91 Modding/Factorio.v1.1.91"
DATA = ROOT + "/data"
DUMPS = ROOT + "/fo-logs/2026-10-22_V3S/industriel/dumps"
PASSE3 = (ROOT + "/fo-logs/2026-10-22_V3E/bas/sprites", ROOT + "/fo-logs/2026-10-22_V3E/haut/sprites")
OUTILS = os.path.join(MOD, "tools", "da")
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(RENDER, "calib"))
sys.path.insert(0, OUTILS)
import ages  # noqa: E402
import famille as FAM  # noqa: E402
import fo_post as P  # noqa: E402
from maquette import lut_apply  # noqa: E402
import da_lib as D  # noqa: E402

PROFIL = None
SIDE = {}
NAME = {e: ages.NOMS[e] for e in range(0, 16)}


def utiliser(nom=None):
    """Choisit la famille des outils (profil.py) ; rend le profil. SIDE suit l'emprise de la famille."""
    global PROFIL
    PROFIL = FAM.charger(nom)
    SIDE.clear()
    SIDE.update({e: PROFIL.COTE[e] for e in PROFIL.AGES})
    return PROFIL


def option_famille(ap):
    """Ajoute --famille à un argparse (défaut : FO_FAMILLE, sinon gun_e)."""
    ap.add_argument("--famille", default="", help="famille (dossier frère de commun/ avec un profil.py ; défaut : "
                                                  "variable FO_FAMILLE, sinon gun_e)")


def font(size, bold=True):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/%s.ttf" % ("arialbd" if bold else "arial"), size)
    except OSError:
        return ImageFont.load_default()


def _dir(out, name):
    """out : dossier, ou couple (bas, haut) de la passe 3 (la variante est cherchée dans le premier qui l'a)."""
    if isinstance(out, (tuple, list)):
        for o in out:
            if os.path.exists(os.path.join(o, name, "spec.json")):
                return os.path.join(o, name)
        return os.path.join(out[0], name)
    return os.path.join(out, name)


def own(out, name, kinds=("shadow", "main", "glow", "light")):
    d = _dir(out, name)
    p = os.path.join(d, "spec.json")
    if not os.path.exists(p):
        return []
    spec = json.load(open(p, encoding="utf-8"))
    res = []
    for k in kinds:
        if k in spec["layers"]:
            s = spec["layers"][k]
            img = np.asarray(Image.open(os.path.join(d, s["file"])).convert("RGBA")).astype(np.float64) / 255
            res.append({"img": img, "shift": tuple(s["shift"]), "kind": k, "file": s["file"]})
    return res


def spec_of(out, name):
    p = os.path.join(_dir(out, name), "spec.json")
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else None


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


def level_layers(out, e, pose, even=False, kinds=("shadow", "main", "glow", "light")):
    """Couches d'un niveau composé de la famille choisie (PROFIL.level_layers ; mitrailleuse : socle (+ pièce paire)
    + tête, âge 1 : vanilla + pièce du niveau 2 dessinée SOUS le vanilla, « k2 » … « k6 » : témoin du kit)."""
    return PROFIL.level_layers(sys.modules[__name__], out, e, pose, even, kinds)


def ground_tile():
    return np.asarray(Image.open(os.path.join(DATA, "base", "graphics", "terrain", "hr-dirt-4.png"))
                      .convert("RGB")).astype(np.float64)[320:576] / 255.0


def compose(ents, W_t, H_t, ppt=64, ground=True):
    """ents : [{"pos": (x, y) en tuiles, "layers": […]}] ; renvoie (jour, nuit) en sRGB 0..1 et l'alpha du corps."""
    W, H = int(W_t * ppt), int(H_t * ppt)
    if ground:
        gt = ground_tile()
        gh, gw = gt.shape[:2]
        day = np.tile(gt, (H // gh + 1, W // gw + 1, 1))[:H, :W].copy()
    else:
        day = np.zeros((H, W, 3))
    alpha = np.zeros((H, W))
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
                alpha[d] = a[..., 0] + alpha[d] * (1 - a[..., 0])
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
    return day, night, alpha


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


def grey(rgb):
    g = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    return np.stack([g, g, g], -1)


# famille par défaut à l'import (FO_FAMILLE, sinon gun_e) ; un outil la change par utiliser(a.famille)
utiliser()
