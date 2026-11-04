"""ICÔNE DU BOURDON (lot ROBOTS-JEU, 3/11) : objet, recette et technologie du Bourdon fabricable. Hors Blender, Python 3.9.

    py -3.9 tools/render/pieces/experimentaux/icone_bourdon.py [--check]      (depuis la racine du mod)

Source : la feuille du corps du jeu, graphics/robots/bourdon/hr-corps.png, et le vitrail en lueur (hr-vitrail.png) posé à sa place
(shift de sprites.lua), régénérées par tools/render/pieces/experimentaux/feuilles.py (D-6). Sortie : graphics/robots/icones/fo-bourdon.png,
COMMITÉE (petite icône, comme graphics/modules) : 64 px et 3 niveaux de mipmaps (32, 16, 8), sur une bande de 120 × 64 (icon_mipmaps = 4).
--check : régénère en mémoire et compare au fichier commité (0 écart attendu).
"""
import argparse
import io
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
SRC = os.path.join(MOD, "graphics", "robots", "bourdon")
DEST = os.path.join(MOD, "graphics", "robots", "icones", "fo-bourdon.png")
TAILLES = (64, 32, 16, 8)


def lire(nom):
    p = os.path.join(SRC, nom)
    if not os.path.isfile(p):
        raise SystemExit("[FO-ICONE-BOURDON] feuille absente : %s\n  py -3.9 tools/render/pieces/experimentaux/feuilles.py" % p)
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255.0


def composer():
    """Corps, puis le vitrail additif posé à sa place (mêmes px HR, scale 0,8 des deux ; décalage des shift en tuiles × 64 / 0,8)."""
    corps = lire("hr-corps.png")
    vit = lire("hr-vitrail.png")
    k = 64.0 / 0.8                                   # px de la feuille par tuile
    sc, sv = (0.0, -23.3), (0.0, -29.3625)           # shift de sprites.lua (corps, vitrail)
    hc, wc = corps.shape[:2]
    hv, wv = vit.shape[:2]
    cx, cy = wc / 2.0 + (sv[0] - sc[0]) * k, hc / 2.0 + (sv[1] - sc[1]) * k
    x0, y0 = int(round(cx - wv / 2.0)), int(round(cy - hv / 2.0))
    out = corps.copy()
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(wc, x0 + wv), min(hc, y0 + hv)
    part = vit[ya - y0:yb - y0, xa - x0:xb - x0]
    a = out[ya:yb, xa:xb, 3:4]
    # additif sur le corps seulement (hors du corps, rien : l'icône garde la silhouette de la cloche)
    out[ya:yb, xa:xb, :3] = np.clip(out[ya:yb, xa:xb, :3] + part[..., :3] * part[..., 3:4] * a, 0.0, 1.0)
    return out


def bande(img):
    a = img[..., 3] > 0.5
    ys, xs = np.nonzero(a)
    img = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = img.shape[:2]
    cote = max(h, w)
    car = np.zeros((cote, cote, 4))
    car[(cote - h) // 2:(cote - h) // 2 + h, (cote - w) // 2:(cote - w) // 2 + w] = img
    pm = Image.fromarray(np.clip(np.round(car * 255.0), 0, 255).astype(np.uint8), "RGBA")
    b = Image.new("RGBA", (sum(TAILLES), TAILLES[0]), (0, 0, 0, 0))
    x = 0
    for t in TAILLES:
        b.paste(pm.resize((t, t), Image.LANCZOS), (x, 0))
        x += t
    return b


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    b = bande(composer())
    if a.check:
        if not os.path.isfile(DEST):
            print("[FO-ICONE-BOURDON] ECHEC : %s absent" % DEST)
            return 1
        ecart = np.abs(np.asarray(b).astype(int) - np.asarray(Image.open(DEST).convert("RGBA")).astype(int)).max()
        print("[FO-ICONE-BOURDON] --check : écart maximal %d (0 attendu)" % ecart)
        return 0 if ecart == 0 else 1
    os.makedirs(os.path.dirname(DEST), exist_ok=True)
    buf = io.BytesIO()
    b.save(buf, "PNG", optimize=True)
    open(DEST, "wb").write(buf.getvalue())
    print("[FO-ICONE-BOURDON] %s : %d × %d, %d octets" % (os.path.relpath(DEST, MOD), b.size[0], b.size[1], len(buf.getvalue())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
