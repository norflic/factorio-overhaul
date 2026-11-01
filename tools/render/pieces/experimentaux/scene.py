"""COMPOSITION HORS MOTEUR des expérimentaux (lot RB-V0, 31/10) : sol, vrais sprites HR vanilla, ombres, géant, effets.
Python 3.9, numpy, PIL. RIEN qu'un effet de jeu ne saurait faire : couches normales, ombres au maximum puis 50 %, additif en
sRGB comme le moteur (shadow-a8.frag, F47) ; ni flou global, ni halo d'écran, ni distorsion : Factorio 1.1 n'a pas de post-traitement.
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = "F:/Factorio.v1.1.91 Modding/Factorio.v1.1.91"
BASE = ROOT + "/data/base"
ENT = BASE + "/graphics/entity/"
QG = ROOT + "/fo-logs/2026-10-31_QG/age15/final/age15"

# nom : liste de (fichier, rect (x, y, w, h), shift px à 32 px/tuile, type, échelle du fichier). Valeurs lues dans data/base/prototypes.
_AM3 = [("assembling-machine-3/hr-assembling-machine-3-shadow.png", (0, 0, 260, 162), (28, 4), "shadow"),
        ("assembling-machine-3/hr-assembling-machine-3.png", (0, 0, 214, 237), (0, -0.75), "main")]
VANILLA = {
    "assembleur": _AM3,
    "assembleur_r": [("assembling-machine-3/remnants/hr-assembling-machine-3-remnants.png", (0, 0, 328, 282), (0, 9.5), "main")],
    "four": [("electric-furnace/hr-electric-furnace-shadow.png", (0, 0, 227, 171), (11.25, 19.25), "shadow"),
             ("electric-furnace/hr-electric-furnace.png", (0, 0, 239, 219), (0.75, 5.75), "main")],
    "four_r": [("electric-furnace/remnants/hr-electric-furnace-remnants.png", (0, 0, 454, 448), (-3.25, 7.25), "main")],
    "tourelle": [("gun-turret/hr-gun-turret-base.png", (0, 0, 150, 118), (0.5, -1), "main"),
                 ("gun-turret/hr-gun-turret-shooting-1.png", (0, 260, 132, 130), (0, -32), "main")],
    "tourelle_r": [("gun-turret/remnants/hr-gun-turret-remnants.png", (0, 0, 252, 242), (3, -1.5), "main")],
    "radar": [("radar/hr-radar-shadow.png", (0, 0, 343, 186), (39.25, 3), "shadow"),
              ("radar/hr-radar.png", (0, 0, 196, 254), (1, -16), "main")],
    "radar_r": [("radar/remnants/hr-radar-remnants.png", (0, 0, 282, 212), (12, 4.5), "main")],
    "labo": [("lab/hr-lab-shadow.png", (0, 0, 243, 136), (13.75, 5.75), "shadow"),
             ("lab/hr-lab.png", (0, 0, 194, 174), (0, 1.5), "main")],
    "labo_r": [("lab/remnants/hr-lab-remnants.png", (0, 0, 266, 196), (7, 5.5), "main")],
    "raffinerie": [("oil-refinery/hr-oil-refinery-shadow.png", (0, 0, 674, 426), (82.5, 26.5), "shadow"),
                   ("oil-refinery/hr-oil-refinery.png", (0, 0, 386, 430), (0, -7.5), "main")],
    "raffinerie_r": [("oil-refinery/remnants/hr-refinery-remnants.png", (0, 0, 467, 415), (-0.25, -0.25), "main")],
    "poteau": [("big-electric-pole/hr-big-electric-pole-shadow.png", (0, 0, 374, 94), (60, 0), "shadow"),
               ("big-electric-pole/hr-big-electric-pole.png", (0, 0, 148, 312), (0, -51), "main")],
    "petit_poteau": [("medium-electric-pole/hr-medium-electric-pole.png", (0, 0, 84, 252), (1.75, -40), "main")],
    "mur": [("wall/hr-wall-horizontal.png", (0, 0, 64, 92), (0, -6), "main")],
    "panneau": [("solar-panel/hr-solar-panel-shadow.png", (0, 0, 220, 180), (9.5, 6), "shadow"),
                ("solar-panel/hr-solar-panel.png", (0, 0, 230, 224), (-1.5, 1.75), "main")],
    "tapis": [("transport-belt/hr-transport-belt.png", (0, 0, 128, 128), (0, 0), "floor")],
    "silo": [("rocket-silo/hr-00-rocket-silo-shadow.png", (0, 0, 612, 578), (7, 2), "shadow"),
             ("rocket-silo/hr-01-rocket-silo-hole.png", (0, 0, 400, 270), (-5, 16), "main"),
             ("rocket-silo/hr-04-door-back.png", (0, 0, 312, 286), (37, 12), "main"),
             ("rocket-silo/hr-05-door-front.png", (0, 0, 332, 300), (-28, 33), "main"),
             ("rocket-silo/hr-06-rocket-silo.png", (0, 0, 608, 596), (3, -1), "main"),
             ("rocket-silo/hr-14-rocket-silo-front.png", (0, 0, 580, 262), (-1, 78), "main")],
}
_NCACHE = {}


def _charge(rel, rect, ppt, scale=0.5):
    cle = (rel, rect, ppt, scale)
    if cle in _NCACHE:
        return _NCACHE[cle]
    im = Image.open(os.path.join(ENT, rel)).convert("RGBA").crop((rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]))
    k = scale * ppt / 32.0
    if abs(k - 1.0) > 1e-6:
        pm = np.asarray(im, np.float32) / 255.0
        pm[..., :3] *= pm[..., 3:4]
        bands = [Image.fromarray(pm[..., i], "F").resize((max(1, int(round(im.width * k))), max(1, int(round(im.height * k)))), Image.LANCZOS if k > 1 else Image.BOX) for i in range(4)]
        a = np.stack([np.asarray(b, np.float32) for b in bands], -1)
        al = np.clip(a[..., 3:4], 1e-4, 1)
        a[..., :3] = np.clip(a[..., :3] / al, 0, 1)
        a[..., 3] = np.clip(a[..., 3], 0, 1)
    else:
        a = np.asarray(im, np.float32) / 255.0
    _NCACHE[cle] = a
    return a


def vanilla(nom, ppt=32):
    res = []
    for (rel, rect, sh, kind) in VANILLA[nom]:
        res.append({"img": _charge(rel, rect, ppt), "shift": (sh[0] / 32.0, sh[1] / 32.0), "kind": kind})
    return res


def behemoth(ppt=32, direction=4):
    """Vrai `behemoth-biter` : corps + 2 masques teintés (enemies.lua, biter-animations.lua), direction d, image 0."""
    k = 1.2
    tint1, tint2 = (0.21, 0.19, 0.25), (0.657, 0.95, 0.432)
    res = []
    y = direction * 310 if direction < 8 else 0
    a = _charge("biter/hr-biter-run-01.png", (0, y, 398, 310), ppt, 0.5 * k)
    res.append({"img": a, "shift": (-1 * k / 32.0, -5 * k / 32.0), "kind": "main"})
    m1 = _charge("biter/hr-biter-run-mask1-01.png", (0, direction * 182, 238, 182), ppt, 0.5 * k).copy()
    m1[..., :3] = m1[..., :3] * np.array(tint1, np.float32)
    res.append({"img": m1, "shift": (-1 * k / 32.0, -37 * k / 32.0), "kind": "main"})
    m2 = _charge("biter/hr-biter-run-mask2-01.png", (0, direction * 184, 232, 184), ppt, 0.5 * k).copy()
    m2[..., :3] = m2[..., :3] * np.array(tint2, np.float32)
    res.append({"img": m2, "shift": (0.0, -38 * k / 32.0), "kind": "main"})
    return res


def qg(ppt=32):
    """Le QG d'âge 15 validé par le DC (fo-logs/2026-10-31_QG), couches telles quelles."""
    spec = json.load(open(os.path.join(QG, "spec.json"), encoding="utf-8"))
    res = []
    for k in ("shadow", "main", "glow"):
        s = spec["layers"][k]
        im = Image.open(os.path.join(QG, s["file"])).convert("RGBA")
        res.append({"img": _reduit(im, ppt / 64.0), "shift": tuple(s["shift"]), "kind": k})
    return res


def _reduit(im, k):
    if abs(k - 1.0) < 1e-6:
        return np.asarray(im, np.float32) / 255.0
    pm = np.asarray(im, np.float32) / 255.0
    pm = pm.copy()
    pm[..., :3] *= pm[..., 3:4]
    W, H = max(1, int(round(im.width * k))), max(1, int(round(im.height * k)))
    bands = [Image.fromarray(pm[..., i], "F").resize((W, H), Image.BOX) for i in range(4)]
    a = np.stack([np.asarray(b, np.float32) for b in bands], -1)
    al = np.clip(a[..., 3:4], 1e-4, 1)
    a[..., :3] = np.clip(a[..., :3] / al, 0, 1)
    return a


def geant(dossier, nom, ppt=32):
    """Couches d'un géant rendu par rendre.py. Rend {couche: {img, shift, kind}}."""
    d = os.path.join(dossier, nom)
    spec = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
    res = {}
    for k, s in spec["layers"].items():
        im = Image.open(os.path.join(d, s["file"])).convert("RGBA")
        kind = "main" if k == "main" else "shadow" if k == "shadow" else "glow"
        res[k] = {"img": _reduit(im, ppt / float(spec["px"])), "shift": tuple(s["shift"]), "kind": kind}
    return res


def fbm(H, W, seed, cell=64.0, oct=5, persist=0.55):
    """Bruit fractal 0..1 déterministe, H×W."""
    out = np.zeros((H, W), np.float32)
    amp, tot = 1.0, 0.0
    rng = np.random.RandomState(seed)
    c = float(cell)
    for _ in range(oct):
        gh, gw = int(H / c) + 3, int(W / c) + 3
        g = rng.rand(gh, gw).astype(np.float32)
        im = Image.fromarray(g, "F").resize((int(gw * c), int(gh * c)), Image.BICUBIC)
        out += amp * np.asarray(im, np.float32)[:H, :W]
        tot += amp
        amp *= persist
        c = max(1.0, c / 2.0)
    out /= tot
    lo, hi = np.percentile(out, 1), np.percentile(out, 99)
    return np.clip((out - lo) / max(1e-5, hi - lo), 0, 1)


class Scene:
    """Monde de W×H tuiles à ppt px/tuile. Position (x, y) en tuiles depuis le coin haut gauche."""

    def __init__(self, W_t, H_t, ppt=32, seed=7):
        self.W, self.H = int(W_t * ppt), int(H_t * ppt)
        self.ppt = ppt
        self.W_t, self.H_t = W_t, H_t
        rng = np.random.RandomState(seed)
        sheet = np.asarray(Image.open(BASE + "/graphics/terrain/hr-dirt-4.png").convert("RGB"), np.float32) / 255.0
        cols = sheet.shape[1] // 256
        patch = 256 * ppt // 64
        self.sol = np.zeros((self.H + patch, self.W + patch, 3), np.float32)
        cache = {}
        for gy in range(0, self.H + 1, patch):
            for gx in range(0, self.W + 1, patch):
                c = int(rng.randint(0, cols))
                if c not in cache:
                    p = sheet[320:576, c * 256:(c + 1) * 256]
                    im = Image.fromarray(np.uint8(p * 255), "RGB").resize((patch, patch), Image.BOX)
                    cache[c] = np.asarray(im, np.float32) / 255.0
                self.sol[gy:gy + patch, gx:gx + patch] = cache[c]
        self.sol = self.sol[:self.H, :self.W]
        xs = (np.arange(self.W, dtype=np.float32) + 0.5) / ppt
        ys = (np.arange(self.H, dtype=np.float32) + 0.5) / ppt
        self.X, self.Y = np.meshgrid(xs, ys)

    def _place(self, lay, pos):
        img = lay["img"]
        h, w = img.shape[:2]
        x0 = int(round(pos[0] * self.ppt + lay["shift"][0] * self.ppt - w / 2.0))
        y0 = int(round(pos[1] * self.ppt + lay["shift"][1] * self.ppt - h / 2.0))
        xs0, ys0 = max(0, -x0), max(0, -y0)
        xd0, yd0 = max(0, x0), max(0, y0)
        ww, hh = min(w - xs0, self.W - xd0), min(h - ys0, self.H - yd0)
        if ww <= 0 or hh <= 0:
            return None, None
        return img[ys0:ys0 + hh, xs0:xs0 + ww], (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))

    def rendu(self, ents, geants=(), sol_fn=None, air_fn=None, sous_geant=None):
        """ents : [{pos, layers}] ; geants : [{pos, layers (dict), mult: {couche: k}, ordre}] dessinés par-dessus les bâtiments.
        sol_fn(img) : décalques au sol (sous les ombres et bâtiments). sous_geant(img) : effets entre bâtiments et géant.
        air_fn(img) : effets au-dessus de tout (explosions, fumées)."""
        img = self.sol.copy()
        if sol_fn:
            sol_fn(img)
        ombre = np.zeros((self.H, self.W), np.float32)
        for e in ents:
            for lay in e["layers"]:
                if lay["kind"] == "shadow":
                    src, d = self._place(lay, e["pos"])
                    if src is not None:
                        ombre[d] = np.maximum(ombre[d], src[..., 3])
        for g in geants:
            lay = g["layers"].get("shadow")
            if lay is not None and g.get("ombre", True):
                src, d = self._place(lay, g["pos"])
                if src is not None:
                    ombre[d] = np.maximum(ombre[d], src[..., 3])
        img *= (1 - 0.5 * ombre)[..., None]
        for lay_e in sorted(ents, key=lambda e: (e["pos"][1], e["pos"][0])):
            if any(l["kind"] == "floor" for l in lay_e["layers"]):
                self._dessine(img, lay_e)
        for e in sorted(ents, key=lambda e: (e["pos"][1], e["pos"][0])):
            if not any(l["kind"] == "floor" for l in e["layers"]):
                self._dessine(img, e)
        if sous_geant:
            sous_geant(img)
        for g in geants:
            for k in g.get("ordre", ("main",)):
                lay = g["layers"].get(k)
                if lay is None:
                    continue
                src, d = self._place(lay, g["pos"])
                if src is None:
                    continue
                a = src[..., 3:4]
                if lay["kind"] == "glow":
                    img[d] = np.clip(img[d] + src[..., :3] * a * g.get("mult", {}).get(k, 1.0), 0, 1)
                else:
                    img[d] = src[..., :3] * a + img[d] * (1 - a)
        if air_fn:
            air_fn(img)
        return np.clip(img, 0, 1)

    def _dessine(self, img, e):
        for lay in e["layers"]:
            if lay["kind"] == "shadow":
                continue
            src, d = self._place(lay, e["pos"])
            if src is None:
                continue
            a = src[..., 3:4]
            if lay["kind"] == "glow":
                img[d] = np.clip(img[d] + src[..., :3] * a, 0, 1)
            else:
                img[d] = src[..., :3] * a + img[d] * (1 - a)


def to_im(rgb):
    return Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def ent(nom, x, y, ppt=32):
    return {"pos": (x, y), "layers": vanilla(nom, ppt), "nom": nom}


def police(size, bold=True):
    from PIL import ImageFont
    return ImageFont.truetype("C:/Windows/Fonts/%s.ttf" % ("arialbd" if bold else "arial"), size)
