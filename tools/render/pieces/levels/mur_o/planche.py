"""Planches du MUR (MUR-OPUS) : mêmes tracés de mur, posés comme le moteur les pose, côte à côte avec le mur vanilla.

    py -3.9 tools/render/pieces/levels/mur_o/planche.py --sprites DIR --out DIR [--ages 2,8,15] [--titre v1]

Composition (ordre du moteur, comme calib/maquette.py) : sol hr-dirt-4 ; ombres au maximum des alphas, sol × (1 − 0,5 a) ;
entités triées par y puis x ; lueur additive. Forme de chaque case d'après ses voisins E, O, S (le nord ne compte pas),
comme WallPictures. Zoom 2 = sprites HR à 1:1 (64 px/tuile) ; zoom 1 = réduction 2×2 (32 px/tuile, approximation des
mipmaps du jeu, notée dans le RAPPORT).
"""
import argparse
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RACINE = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
VAN = os.path.join(RACINE, "data", "base", "graphics", "entity", "wall")
SOL = os.path.join(RACINE, "data", "base", "graphics", "terrain", "hr-dirt-4.png")

# (fichier, w, h, shift HR px) principal, puis ombre — prototypes/entity/entities.lua (stone-wall) ; NVAR : variations
VANILLA = {
    "single": (("hr-wall-single.png", 64, 86, (0, -10)), ("hr-wall-single-shadow.png", 98, 60, (20, 34))),
    "vert": (("hr-wall-vertical.png", 64, 134, (0, 16)), ("hr-wall-vertical-shadow.png", 98, 110, (20, 58))),
    "horiz": (("hr-wall-horizontal.png", 64, 92, (0, -4)), ("hr-wall-horizontal-shadow.png", 124, 68, (28, 30))),
    "corR": (("hr-wall-corner-right.png", 64, 128, (0, 14)), ("hr-wall-corner-right-shadow.png", 124, 120, (34, 56))),
    "corL": (("hr-wall-corner-left.png", 64, 134, (0, 14)), ("hr-wall-corner-left-shadow.png", 102, 120, (18, 56))),
    "tee": (("hr-wall-t.png", 64, 134, (0, 14)), ("hr-wall-t-shadow.png", 124, 120, (28, 56))),
    "endR": (("hr-wall-ending-right.png", 64, 92, (0, -6)), ("hr-wall-ending-right-shadow.png", 124, 68, (34, 30))),
    "endL": (("hr-wall-ending-left.png", 64, 92, (0, -6)), ("hr-wall-ending-left-shadow.png", 102, 68, (18, 30))),
}

NVAR = {"single": 2, "vert": 5, "horiz": 6, "corR": 2, "corL": 2, "tee": 4, "endR": 2, "endL": 2}

TRACE = [
    "............",
    ".#######..#.",
    ".#.....#....",
    ".#..########",
    ".#.....#..#.",
    ".####..#..#.",
    "............",
]
TRACE_LIGNE = ["......", ".####.", "......"]


def forme(T, x, y):
    def at(i, j):
        return 0 <= j < len(T) and 0 <= i < len(T[j]) and T[j][i] == "#"
    e, o, s = at(x + 1, y), at(x - 1, y), at(x, y + 1)
    return {(0, 0, 0): "single", (0, 0, 1): "vert", (1, 1, 0): "horiz", (1, 0, 1): "corR", (0, 1, 1): "corL",
            (1, 1, 1): "tee", (1, 0, 0): "endR", (0, 1, 0): "endL"}[(int(e), int(o), int(s))]


def image(jeu, T, x, y):
    """Forme de la case puis variante (le moteur la tire au hasard par case ; ici, d'après la position)."""
    f = forme(T, x, y)
    if jeu.nom == "vanilla":
        v = (x * 7 + y * 3) % NVAR[f]
        return jeu.f[f if v == 0 else "%s#%d" % (f, v)]
    if f == "horiz" and "horiz2" in jeu.f and (x + y) % 2 == 1:
        return jeu.f["horiz2"]
    return jeu.f[f]


def lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def load(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255.0


class Jeu:
    """Sprites d'un mur : forme -> (couches {main, shadow, glow} : (image, x0, y0) relatifs au centre de la case)."""

    def __init__(self, nom):
        self.nom, self.f = nom, {}

    @staticmethod
    def vanilla():
        j = Jeu("vanilla")
        for f, ((fm, w, h, sh), (fs, ws, hs, shs)) in VANILLA.items():
            full = load(os.path.join(VAN, fm))
            s = load(os.path.join(VAN, fs))[:hs, :ws]
            for v in range(NVAR[f]):
                m = full[:h, v * w:(v + 1) * w]
                j.f[f if v == 0 else "%s#%d" % (f, v)] = {"main": (m, sh[0] - w // 2, sh[1] - h // 2),
                                                          "shadow": (s, shs[0] - ws // 2, shs[1] - hs // 2)}
        return j

    @staticmethod
    def rendu(d, age):
        j = Jeu("âge %d" % age)
        for f in list(VANILLA) + ["horiz2"]:
            sd = os.path.join(d, "a%02d-%s" % (age, f))
            if not os.path.exists(sd):
                continue
            spec = json.load(open(os.path.join(sd, "spec.json"), encoding="utf-8"))
            j.f[f] = {}
            for layer, L in spec["layers"].items():
                j.f[f][layer] = (load(os.path.join(sd, L["file"])), L["box_px"][0], L["box_px"][1])
        return j


def sol(W, H):
    t = load(SOL)
    t = t[320:576] if t.shape[0] >= 576 else t
    reps = (H // t.shape[0] + 1, W // t.shape[1] + 1, 1)
    return np.tile(t, reps)[:H, :W, :3].copy()


def compose(jeu, T, marge=(1.0, 1.6), gris=False):
    nx, ny = len(T[0]), len(T)
    W, H = int(nx * 64), int((ny + marge[1]) * 64)
    oy = int(marge[1] * 64)
    img = sol(W, H)
    cases = [(x, y) for y in range(ny) for x in range(nx) if T[y][x] == "#"]
    centre = {c: (int(c[0] * 64 + 32), int(oy + c[1] * 64 + 32)) for c in cases}
    sha = np.zeros((H, W))
    for c in cases:
        L = image(jeu, T, *c)
        if "shadow" in L:
            a, x0, y0 = L["shadow"]
            cx, cy = centre[c]
            X, Y = cx + x0, cy + y0
            h, w = a.shape[:2]
            ys, xs = slice(max(Y, 0), min(Y + h, H)), slice(max(X, 0), min(X + w, W))
            sub = a[ys.start - Y:ys.stop - Y, xs.start - X:xs.stop - X, 3]
            sha[ys, xs] = np.maximum(sha[ys, xs], sub)
    img = lin(img) * (1 - 0.5 * sha[..., None])
    img = srgb(img)
    glow = np.zeros((H, W, 3))
    for c in sorted(cases, key=lambda c: (c[1], c[0])):
        L = image(jeu, T, *c)
        cx, cy = centre[c]
        for layer in ("main", "glow"):
            if layer not in L:
                continue
            a, x0, y0 = L[layer]
            X, Y = cx + x0, cy + y0
            h, w = a.shape[:2]
            ys, xs = slice(max(Y, 0), min(Y + h, H)), slice(max(X, 0), min(X + w, W))
            sub = a[ys.start - Y:ys.stop - Y, xs.start - X:xs.stop - X]
            if layer == "main":
                al = sub[..., 3:4]
                img[ys, xs] = sub[..., :3] * al + img[ys, xs] * (1 - al)
            else:
                glow[ys, xs] += sub[..., :3] * sub[..., 3:4]
    img = np.clip(img + glow, 0, 1)
    if gris:
        l = 0.2126 * img[..., 0] + 0.7152 * img[..., 1] + 0.0722 * img[..., 2]
        img = np.repeat(l[..., None], 3, -1)
    return img


def z1(img):
    H, W = img.shape[:2]
    H, W = H - H % 2, W - W % 2
    a = lin(img[:H, :W])
    a = 0.25 * (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2])
    return srgb(a)


def im(a):
    return Image.fromarray(np.clip(np.round(a * 255), 0, 255).astype(np.uint8), "RGB")


def police(n):
    for f in ("arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(f, n)
        except OSError:
            pass
    return ImageFont.load_default()


def grille(rows, titre, fond=(22, 22, 26)):
    """rows : [[(image PIL, légende), …], …] -> planche."""
    F, Ft = police(15), police(20)
    pad, lab = 12, 22
    widths = [sum(i.width for i, _ in r) + pad * (len(r) + 1) for r in rows]
    heights = [max(i.height for i, _ in r) + lab + pad for r in rows]
    W, H = max(widths), sum(heights) + 40
    out = Image.new("RGB", (W, H), fond)
    d = ImageDraw.Draw(out)
    d.text((pad, 8), titre, fill=(240, 200, 120), font=Ft)
    y = 40
    for r, hh in zip(rows, heights):
        x = pad
        for i, t in r:
            d.text((x, y), t, fill=(225, 225, 225), font=F)
            out.paste(i, (x, y + lab))
            x += i.width + pad
        y += hh
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sprites", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--ages", default="2,8,15")
    ap.add_argument("--titre", default="")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    ages = [int(x) for x in a.ages.split(",") if x]
    van = Jeu.vanilla()
    jeux = [van] + [Jeu.rendu(a.sprites, e) for e in ages]
    noms = ["vanilla (mur de pierre)"] + ["âge %d" % e for e in ages]
    z2 = [compose(j, TRACE) for j in jeux]
    # 1. zoom 2 : vanilla et chaque âge
    rows = [[(im(z2[0]), noms[0] + " · zoom 2"), (im(z2[i]), noms[i] + " · zoom 2")] for i in range(1, len(jeux))]
    grille(rows, "Mur %s · zoom 2 (64 px/tuile) · jour · même tracé que le vanilla" % a.titre).save(
        os.path.join(a.out, "planche-zoom2.png"))
    # 2. zoom 1 : tous côte à côte, et agrandi ×2 au plus proche (lecture)
    z1s = [im(z1(x)) for x in z2]
    rows = [[(z1s[i], noms[i] + " · zoom 1") for i in range(len(jeux))],
            [(z.resize((z.width * 2, z.height * 2), Image.NEAREST), noms[i] + " · zoom 1, ×2 au plus proche")
             for i, z in enumerate(z1s[:2])],
            [(z.resize((z.width * 2, z.height * 2), Image.NEAREST), noms[i + 2] + " · zoom 1, ×2 au plus proche")
             for i, z in enumerate(z1s[2:])]]
    rows = [r for r in rows if r]
    grille(rows, "Mur %s · zoom 1 (32 px/tuile, réduction 2×2) · jour" % a.titre).save(
        os.path.join(a.out, "planche-zoom1.png"))
    # 3. gros plan : une ligne courte, zoom 2 agrandi ×2
    lg = [compose(j, TRACE_LIGNE, marge=(1.0, 1.6)) for j in jeux]
    rows = [[(im(x).resize((im(x).width * 2, im(x).height * 2), Image.LANCZOS), noms[i] + " · zoom 2 ×2")
             for i, x in enumerate(lg[:2])],
            [(im(x).resize((im(x).width * 2, im(x).height * 2), Image.LANCZOS), noms[i + 2] + " · zoom 2 ×2")
             for i, x in enumerate(lg[2:])]]
    grille(rows, "Mur %s · gros plan (bout, courtine, bout)" % a.titre).save(os.path.join(a.out, "planche-gros-plan.png"))
    # 4. niveaux de gris, zoom 1 (test du gris D1-1)
    gz = [im(z1(compose(j, TRACE, gris=True))) for j in jeux]
    grille([[(g, noms[i] + " · gris") for i, g in enumerate(gz)]], "Mur %s · gris, zoom 1" % a.titre).save(
        os.path.join(a.out, "planche-gris.png"))
    for i, x in enumerate(z2):
        im(x).save(os.path.join(a.out, "z2-%s.png" % ("vanilla" if i == 0 else "a%02d" % ages[i - 1])))
    print("[FO-PLANCHE] %s" % a.out)


if __name__ == "__main__":
    main()
