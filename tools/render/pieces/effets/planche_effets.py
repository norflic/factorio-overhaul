"""PLANCHE DES EFFETS (lot POLISSAGE-FX, 10/11) : par arme, les sprites d'effet tels que le prototype les teinte (couleur de la table de
l'arme) : flash de bouche, impact (quatre images de l'explosion vanilla source teintée et mise à l'échelle), onde de choc et vortex
(feuilles procédurales), de JOUR (sur sable, alpha) et de NUIT (fond sombre, additif). Python 3.9, Pillow + numpy, hors Blender.

    py -3.9 tools/render/pieces/effets/planche_effets.py --packs <fx-packs.json> --dest <planche.png> [--zoom 2]

<fx-packs.json> : export des packs par lua5.2 (voir le rapport du lot) : nom, mode, couleur, source et échelle de l'impact, échelles de
l'onde et des vortex. La planche n'est qu'une maquette : le jeu compose avec ses propres lumières.
"""
import argparse
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
DATA = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data\base\graphics\entity"
# explosion vanilla : fichier (résolution normale), largeur, hauteur, images, images par ligne
VANILLA = {
    "laser-bubble": ("laser-bubble/laser-bubble.png", 8, 8, 5, 5),
    "explosion-hit": ("explosion-hit/explosion-hit.png", 34, 38, 13, 13),
    "big-explosion": ("big-explosion/big-explosion.png", 197, 245, 47, 6),
    "medium-explosion": ("medium-explosion/medium-explosion-1.png", 62, 112, 30, 6),
}
SABLE = (120, 86, 52)
NUIT = (14, 14, 18)


def font(size, bold=True):
    for f in (("arialbd.ttf" if bold else "arial.ttf"), "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def frame(path, w, h, k, ll):
    im = Image.open(path).convert("RGBA")
    x, y = (k % ll) * w, (k // ll) * h
    return np.asarray(im.crop((x, y, x + w, y + h))).astype(np.float64) / 255.0


def teinte(a, c):
    out = a.copy()
    out[..., :3] *= np.array(c)[None, None, :]
    return out


def compose(a, fond, nuit, k):
    """Sprite (RGBA 0-1) teinté, mis à l'échelle k, sur un fond : jour = alpha ; nuit = additif (couche lueur)."""
    h, w = a.shape[:2]
    im = Image.fromarray((np.clip(a, 0, 1) * 255).round().astype(np.uint8), "RGBA")
    if k != 1.0:
        im = im.resize((max(1, int(round(w * k))), max(1, int(round(h * k)))), Image.LANCZOS)
    a = np.asarray(im).astype(np.float64) / 255.0
    bg = np.ones((a.shape[0], a.shape[1], 3)) * (np.array(fond) / 255.0)
    if nuit:
        rgb = np.clip(bg + a[..., :3] * a[..., 3:4] * 1.4, 0, 1)
    else:
        rgb = bg * (1 - a[..., 3:4]) + a[..., :3] * a[..., 3:4]
    return Image.fromarray((rgb * 255).round().astype(np.uint8), "RGB")


def cellule(images, fond, nuit, k, side):
    """Ligne d'images sur un fond carré de `side` px chacune, centrées."""
    out = Image.new("RGB", (side * len(images), side), fond)
    for i, a in enumerate(images):
        im = compose(a, fond, nuit, k)
        if im.width > side or im.height > side:
            r = min(side / im.width, side / im.height)
            im = im.resize((max(1, int(im.width * r)), max(1, int(im.height * r))), Image.LANCZOS)
        out.paste(im, (i * side + (side - im.width) // 2, (side - im.height) // 2))
    return out


def feuille(nom, k):
    p = os.path.join(MOD, "graphics", "effets", "%s.png" % nom)
    return frame(p, 128, 128, k, 8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--packs", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--zoom", type=float, default=2.0)
    a = ap.parse_args()
    packs = json.load(open(a.packs, encoding="utf-8"))
    z = a.zoom
    side = int(96 * z / 2)
    rows = []
    for p in packs:
        c = (p["r"], p["g"], p["b"])
        titre = "%s · mode %s · couleur de la table (%.2f, %.2f, %.2f)" % (p["nom"], p["mode"], *c)
        if p["delegue"]:
            rows.append((titre + " · délégué au lot TIRS (flammes de bouche, dards, impacts par âge)", []))
            continue
        cols = []
        if p["bouche"]:
            f, w, h, n, ll = VANILLA["explosion-hit"]
            imgs = [teinte(frame(os.path.join(DATA, f), w, h, k, ll), c) for k in (2, 5)]
            cols.append(("bouche", imgs, 1.2 * z))
        if p["impact_source"]:
            f, w, h, n, ll = VANILLA[p["impact_source"]]
            ks = [int(n * t) for t in (0.1, 0.3, 0.55, 0.8)]
            imgs = [teinte(frame(os.path.join(DATA, f), w, h, k, ll), c) for k in ks]
            cols.append(("impact : %s × %.1f" % (p["impact_source"], p["impact_echelle"]), imgs, p["impact_echelle"] * z))
        if p["onde"]:
            imgs = [teinte(feuille("onde", k), c) for k in (1, 3, 5, 7)]
            cols.append(("onde Ø %.0f tuiles" % p["onde"], imgs, p["onde"] / 4.0 * z * 0.5))
        for cle, lab in (("vortex_proj", "vortex du projectile"), ("vortex_champ", "vortex du champ"), ("vortex_sing", "vortex de la singularité")):
            if p[cle]:
                imgs = [teinte(feuille("vortex", k), c) for k in (0, 2, 4, 6)]
                cols.append(("%s Ø %.1f" % (lab, p[cle]), imgs, p[cle] / 4.0 * z * 0.5 if p[cle] > 2 else p[cle] / 4.0 * z * 2))
        rows.append((titre, cols))
    gap, th, lab = 6, 26, 18
    fs = 13
    W = max([sum(side * len(ims) * 2 + gap for _, ims, _ in cols) + gap for _, cols in rows] + [900])
    H = 40 + sum(th + (side + lab if cols else 0) + gap for _, cols in rows)
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), "POLISSAGE-FX · effets par arme (maquette : jour sur sable, nuit en additif) · zoom %g · couleurs lues dans les tables des armes" % z,
            fill=(255, 205, 120), font=font(18))
    y = 40
    for titre, cols in rows:
        dr.text((gap + 2, y + 2), titre, fill=(150, 210, 255), font=font(fs + 1))
        y += th
        if not cols:
            y += gap
            continue
        x = gap
        for nom, ims, k in cols:
            jour = cellule(ims, SABLE, False, k, side)
            nuit = cellule(ims, NUIT, True, k, side)
            sheet.paste(jour, (x, y))
            sheet.paste(nuit, (x + jour.width, y))
            dr.text((x + 3, y + side + 2), nom + " · jour | nuit", fill=(235, 235, 235), font=font(fs - 1, False))
            x += jour.width * 2 + gap
        y += side + lab + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    tel = a.dest[:-4] + "-telephone.png"
    r = min(1.0, 1600.0 / sheet.width)
    sheet.resize((int(sheet.width * r), int(sheet.height * r)), Image.LANCZOS).save(tel, optimize=True)
    print(a.dest, sheet.size, tel)


if __name__ == "__main__":
    main()
