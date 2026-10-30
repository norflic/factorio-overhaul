"""APERÇU EN MASSES (sans Blender, sans verrou) du QG âge 13 : rastérisation par peintre des faces de la géométrie, vue
de la caméra du jeu (orthographique, 45°, +Y nord = vers le haut de l'écran), ombrage plat soleil d'ouest à 48°,
couleur moyenne par matière. Sert à juger la COMPOSITION (silhouette, recouvrements, nez à droite) pendant que le
verrou de rendu est occupé ; ne remplace PAS un rendu Cycles.

    py -3.9 tools/render/pieces/levels/qg13/apercu13.py --dest apercu.png [--ppt 32] [--gris]
"""
import argparse
import math
import os
import sys
import types

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.modules["bpy"] = types.ModuleType("bpy")
import mat as MT  # noqa: E402


class _M:
    def __init__(self, name):
        self.name = name


MT.surface = lambda name, *a, **k: _M(name)
MT.verre = lambda name, *a, **k: _M(name)
MT.lumiere = lambda S, name, *a, **k: _M(name)
import geo as G  # noqa: E402

COUL = {"ceram": (200, 192, 176), "ceram2": (165, 155, 138), "ceram3": (214, 204, 184), "noire": (40, 36, 34),
        "cuivre": (190, 105, 55), "cuivre_s": (120, 62, 34), "vdg": (70, 110, 90), "toit": (150, 80, 40),
        "acier": (70, 66, 62), "noir": (25, 24, 24), "grille": (60, 58, 54), "caout": (28, 27, 26),
        "cable_r": (150, 30, 20), "os": (150, 135, 110), "chevron": (200, 150, 20), "jaune": (190, 140, 20),
        "terre": (110, 80, 50), "brule": (30, 22, 24), "verre": (40, 25, 40), "plasma": (255, 90, 220),
        "coeur": (255, 170, 70), "hublot": (255, 200, 130), "balise": (255, 90, 220)}
EMIS = ("plasma", "coeur", "hublot", "balise")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--ppt", type=int, default=32)
    ap.add_argument("--module", default="age13")
    ap.add_argument("--gris", action="store_true")
    a = ap.parse_args()
    mod = __import__(a.module)
    if hasattr(mod, "_emis"):
        mod._emis = lambda S, name, *a_, **k: _M(name)
    lot = G.Lot(None, "ap")
    mod.build(None, lot)
    d = np.array([0.0, -0.70711, 0.70711])
    Ls = np.array([-math.cos(math.radians(48)), 0.0, math.sin(math.radians(48))])
    polys = []
    for key in lot.parts:
        mname = key.split("_", 1)[1] if "_" in key else key
        col = np.array(COUL.get(mname, (128, 0, 128)), float)
        verts = np.array(lot.parts[key][1], float)
        for f in lot.parts[key][2]:
            P = verts[list(f)]
            if len(P) < 3:
                continue
            n = np.cross(P[1] - P[0], P[2] - P[0])
            if len(P) > 3:
                n = n + np.cross(P[2] - P[0], P[3] - P[0])
            ln = np.linalg.norm(n)
            if ln < 1e-12:
                continue
            n /= ln
            if n @ d < 0:
                n = -n
            if mname in EMIS:
                c = col
            else:
                lam = max(0.0, float(n @ Ls))
                c = col * (0.28 + 0.8 * lam)
            if a.gris:
                g = c.mean() if mname not in EMIS else 255
                c = np.array([g, g, g])
            depth = float((P @ d).mean())
            uv = [(p[0], -(p[1] + p[2]) * 0.70711) for p in P]
            polys.append((depth, uv, tuple(int(max(0, min(255, x))) for x in c)))
    polys.sort(key=lambda t: t[0])
    W_t, H_t, ox, oy = 18.0, 15.0, 9.0, 10.5
    ppt = a.ppt
    im = Image.new("RGB", (int(W_t * ppt), int(H_t * ppt)), (120, 92, 60))
    dr = ImageDraw.Draw(im)
    # ombre approximative : projection des faces sur le sol plein est (non dessinée) ; emprise 16×8
    x0, x1 = (ox - 8) * ppt, (ox + 8) * ppt
    y0, y1 = (oy - 4) * ppt, (oy + 4) * ppt
    dr.rectangle([x0, y0, x1, y1], outline=(255, 255, 255))
    for _, uv, c in polys:
        dr.polygon([((u + ox) * ppt, (v + oy) * ppt) for u, v in uv], fill=c)
    dr.text((6, 4), "APERÇU EN MASSES (rastérisation, pas Cycles) · nez à droite · emprise 16×8 tracée", fill=(255, 230, 160))
    im.save(a.dest)
    print(a.dest, im.size, len(polys), "faces")


if __name__ == "__main__":
    main()
