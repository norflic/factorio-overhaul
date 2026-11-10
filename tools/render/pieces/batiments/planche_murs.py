"""Lot MURS-2 : planche avant/apres des murs renforce et blinde (jour, nuit), troncon de mur avec coins et T, plus les feuilles.

Usage : py -3.9 -B tools/render/pieces/batiments/planche_murs.py <dossier data du jeu> <dossier du mod> <dossier de sortie>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

TILE = 64  # zoom 2 : feuilles hr a l'echelle 1
SABLE = (120, 86, 52)
NUIT = 0.22
# piece : (fichier, decalage vanilla en pixels normaux)
P = {
    "single": ("wall-single", (0, -6)), "v": ("wall-vertical", (0, 8)), "h": ("wall-horizontal", (0, -4)),
    "cr": ("wall-corner-right", (0, 6)), "cl": ("wall-corner-left", (0, 6)), "t": ("wall-t", (0, 6)),
    "er": ("wall-ending-right", (0, -4)), "el": ("wall-ending-left", (0, -4)),
}
OMBRE = {"single": (10, 16), "v": (10, 28), "h": (14, 14), "cr": (14, 28), "cl": (14, 28), "t": (14, 28), "er": (14, 14), "el": (14, 14)}
# troncon : angle, ligne, T, ligne, angle ; deux montants ; extremites
TRONCON = [
    (0, 0, "cr"), (1, 0, "h"), (2, 0, "t"), (3, 0, "h"), (4, 0, "cl"),
    (0, 1, "v"), (2, 1, "v"), (4, 1, "v"),
    (0, 2, "er"), (1, 2, "h"), (2, 2, "h"), (3, 2, "h"), (4, 2, "el"), (6, 1, "single"),
]
TEINTES = {"renforce": (0.78, 0.80, 0.88), "blinde": (0.48, 0.55, 0.75)}


def charge(p):
    return np.array(Image.open(p).convert("RGBA")).astype(np.float32) / 255.0


def frame(sheet, n_var, i):
    w = sheet.shape[1] // n_var
    return sheet[:, i * w:(i + 1) * w]


def colle(fond, img, cx, cy, additif=False, ombre=False):
    h, w = img.shape[:2]
    x0, y0 = int(round(cx - w / 2)), int(round(cy - h / 2))
    H, W = fond.shape[:2]
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if xa >= xb or ya >= yb:
        return
    sub = img[ya - y0:yb - y0, xa - x0:xb - x0]
    a = sub[..., 3:4]
    if ombre:
        fond[ya:yb, xa:xb, :3] *= (1 - 0.55 * a)
    elif additif:
        fond[ya:yb, xa:xb, :3] = np.clip(fond[ya:yb, xa:xb, :3] + sub[..., :3] * a, 0, 1)
    else:
        fond[ya:yb, xa:xb, :3] = fond[ya:yb, xa:xb, :3] * (1 - a) + sub[..., :3] * a


def variantes(f):
    return {"wall-single": 2, "wall-vertical": 5, "wall-horizontal": 6, "wall-corner-right": 2, "wall-corner-left": 2,
            "wall-t": 4, "wall-ending-right": 2, "wall-ending-left": 2}[f]


def troncon(src_dir, mur_dir, teinte, nuit):
    W, H = 8 * TILE, 4 * TILE
    fond = np.ones((H, W, 3), np.float32) * (np.array(SABLE, np.float32) / 255.0)
    if nuit:
        fond *= NUIT
    vanilla = mur_dir is None
    for (x, y, k) in TRONCON:  # ombres d'abord
        f, _ = P[k]
        sh = frame(charge(os.path.join(src_dir, "hr-" + f + "-shadow.png")), variantes(f), 0)
        so = OMBRE[k]
        colle(fond, sh, x * TILE + TILE / 2 + 2 * so[0] + 32, y * TILE + TILE / 2 + 2 * so[1] + 32, ombre=True)
    for (x, y, k) in sorted(TRONCON, key=lambda t: (t[1], t[0])):
        f, s = P[k]
        n = variantes(f)
        if vanilla:
            img = frame(charge(os.path.join(src_dir, "hr-" + f + ".png")), n, (x + y) % n)
            img[..., :3] *= np.array(teinte, np.float32)
        else:
            img = frame(charge(os.path.join(mur_dir, "hr-" + f + ".png")), n, (x + y) % n)
        if nuit:
            img = img.copy()
            img[..., :3] *= NUIT
        cx, cy = x * TILE + TILE / 2 + 2 * s[0] + 32, y * TILE + TILE / 2 + 2 * s[1] + 32
        colle(fond, img, cx, cy)
        if nuit and not vanilla:
            g = frame(charge(os.path.join(mur_dir, "hr-" + f + "-glow.png")), n, (x + y) % n)
            colle(fond, g, cx, cy, additif=True)
    return (np.clip(fond, 0, 1) * 255 + 0.5).astype(np.uint8)


def main(data_dir, mod_dir, out_dir):
    src = os.path.join(data_dir, "base", "graphics", "entity", "wall")
    os.makedirs(out_dir, exist_ok=True)
    lignes = []
    for cle, titre in (("renforce", "Mur renforce (fo-reinforced-wall) : lisere cyan"),
                       ("blinde", "Mur blinde (fo-armored-wall) : lisere magenta")):
        mur = os.path.join(mod_dir, "graphics", "batiments", "murs", cle)
        cases = [("jour : 0.6.84 livre (vanilla teinte)", troncon(src, None, TEINTES[cle], False)),
                 ("jour : refait", troncon(src, mur, None, False)),
                 ("nuit : 0.6.84 livre", troncon(src, None, TEINTES[cle], True)),
                 ("nuit : refait (lueur du lisere)", troncon(src, mur, None, True))]
        lignes.append((titre, cases))
    cw, ch = 8 * TILE, 4 * TILE
    pad, tete = 10, 26
    W = 2 * (cw + pad) + pad
    H = len(lignes) * (tete + 2 * (ch + 20 + pad)) + pad + 30
    pl = Image.new("RGB", (W, H), (20, 20, 26))
    dr = ImageDraw.Draw(pl)
    dr.text((pad, 8), "MURS-2 : murs renforce et blinde refaits (meme geometrie de raccord que le vanilla) - zoom 2 - troncon avec coins, T et extremites",
            fill=(255, 210, 120))
    y = 30
    for titre, cases in lignes:
        dr.text((pad, y + 4), titre, fill=(140, 200, 255))
        y += tete
        for i, (leg, im) in enumerate(cases):
            x = pad + (i % 2) * (cw + pad)
            yy = y + (i // 2) * (ch + 20 + pad)
            pl.paste(Image.fromarray(im), (x, yy))
            dr.text((x, yy + ch + 3), leg, fill=(210, 210, 210))
        y += 2 * (ch + 20 + pad)
    p = os.path.join(out_dir, "planche-murs.png")
    pl.save(p, optimize=True)
    r = 1600 / pl.width if pl.width > 1600 else 1.0
    pl.resize((int(pl.width * r), int(pl.height * r)), Image.LANCZOS).save(os.path.join(out_dir, "planche-murs-telephone.png"), optimize=True)
    print(p, pl.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
