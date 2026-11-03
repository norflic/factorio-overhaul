"""PLANCHE D'ÉTATS CLÉS du kit chimie (lot DA-CHIMIE) : une rangée par machine, l'usine chimique vanilla (le sprite
qu'elle remplace) À GAUCHE, puis la machine dans ses 4 directions (N, E, S, O : les raccords tournent), même sol, même
échelle, ombres et lueur composées comme en jeu (levels/commun/compo.py). Flèches : entrées (bleu) et sorties (orange)
aux positions exactes des boîtes de fluide du prototype. Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/chimie/planche.py --src DIR --dest etats-cles.png [--machines craqueur,…] [--zoom 1|2]
        [--nuit] [--dirs n,e,s,w]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "levels", "commun"))
import compo as K  # noqa: E402

sys.path.insert(0, HERE)
import piece as PC  # noqa: E402

ENT = os.path.join(K.DATA, "base", "graphics", "entity")
# usine chimique vanilla : 24 images par direction, 12 par rangée de 220 × 292 ; ombre : 4 images de 312 × 222
CHIMIE = ("chemical-plant/hr-chemical-plant.png", (220, 292), (0.5, -4.5),
          "chemical-plant/hr-chemical-plant-shadow.png", (312, 222), (27, 3))
# boîtes de fluide (prototypes) : (entrées nord, sorties sud), colonnes x
FLUIDES = {"craqueur": ((-1, 1), (0,)), "reformeur": ((-1, 1), (-1, 1)), "electrolyseur": ((0,), (-1, 1)),
           "colonne": ((0,), ())}
NOMS = {"craqueur": "Vapocraqueur", "reformeur": "Reformeur", "electrolyseur": "Électrolyseur",
        "colonne": "Colonne d'extraction"}
DNOM = {"n": "nord", "e": "est", "s": "sud", "w": "ouest"}


def vanilla(d):
    f, (w, h), sh, fs, (ws, hs), shs = CHIMIE
    im = Image.open(os.path.join(ENT, f)).convert("RGBA")
    row = 2 * "nesw".index(d)
    main = np.asarray(im.crop((0, h * row, w, h * row + h))).astype(np.float64) / 255.0
    sim = Image.open(os.path.join(ENT, fs)).convert("RGBA")
    i = "nesw".index(d)
    shadow = np.asarray(sim.crop((ws * i, 0, ws * i + ws, hs))).astype(np.float64) / 255.0
    return [{"img": shadow, "shift": (shs[0] / 32.0, shs[1] / 32.0), "kind": "shadow"},
            {"img": main, "shift": (sh[0] / 32.0, sh[1] / 32.0), "kind": "main"}]


def rot(x, y, d):
    for _ in range("nesw".index(d)):
        x, y = -y, x
    return x, y


def fleches(dr, nom, d, cx, cy, ppt):
    """Flèches des raccords : position du tuyau voisin (bord ± 0,5 tuile), entrée vers la machine, sortie vers dehors."""
    ins, outs = FLUIDES[nom]
    for cols, y, col, sens in ((ins, -2.0, (90, 170, 255), 1), (outs, 2.0, (255, 150, 40), -1)):
        for c in cols:
            x0, y0 = rot(c, y, d)
            x1, y1 = rot(c, y * 0.8, d)
            p0 = (cx + x0 * ppt, cy + y0 * ppt)
            p1 = (cx + x1 * ppt, cy + y1 * ppt)
            if sens < 0:
                p0, p1 = p1, p0
            dr.line([p0, p1], fill=col, width=3)
            dx, dy = p1[0] - p0[0], p1[1] - p0[1]
            n = max(1e-6, (dx * dx + dy * dy) ** 0.5)
            ux, uy = dx / n, dy / n
            a = (p1[0] - ux * 8 - uy * 5, p1[1] - uy * 8 + ux * 5)
            b = (p1[0] - ux * 8 + uy * 5, p1[1] - uy * 8 - ux * 5)
            dr.polygon([p1, a, b], fill=col)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--machines", default="craqueur,reformeur,electrolyseur,colonne")
    ap.add_argument("--dirs", default="n,e,s,w")
    ap.add_argument("--zoom", type=int, default=2, choices=(1, 2))
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--fleches", action="store_true")
    ap.add_argument("--haut", type=float, default=9.0, help="hauteur d'une case en tuiles")
    ap.add_argument("--oy", type=float, default=6.3, help="y de la position de l'entité dans la case (tuiles)")
    ap.add_argument("--large", type=float, default=6.0, help="largeur d'une case en tuiles")
    ap.add_argument("--titre", default="")
    a = ap.parse_args()
    machines = [m for m in a.machines.split(",") if m]
    dirs = [d for d in a.dirs.split(",") if d]
    ppt = 64 if a.zoom == 2 else 32
    cw, ch = int(a.large * ppt), int(a.haut * ppt)
    gap, hd, lab = 6, 36, 24
    W = (len(dirs) + 1) * (cw + gap) + gap
    H = hd + len(machines) * (ch + lab + gap)
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    fs = 18 if a.zoom == 2 else 13
    dr.text((10, 8), a.titre or "DA-CHIMIE · états clés · zoom %d · %s · à gauche : usine chimique vanilla (même direction que la 1re case)"
            % (a.zoom, "nuit" if a.nuit else "jour"), fill=(255, 205, 120), font=K.font(fs + 2))
    for r, m in enumerate(machines):
        y = hd + r * (ch + lab + gap)
        cases = [("van", dirs[0])] + [(m, d) for d in dirs]
        for i, (nom, d) in enumerate(cases):
            x = gap + i * (cw + gap)
            lays = vanilla(d) if nom == "van" else K.own(a.src, "%s_%s" % (nom, d), ("shadow", "main", "glow"))
            day, night, _ = K.compose([{"pos": (a.large / 2.0, a.oy), "layers": lays}], a.large, a.haut)
            img = night if a.nuit else day
            if a.zoom == 1:
                img = K.down2(img)
            sheet.paste(K.to_im(img), (x, y))
            if a.fleches and nom != "van":
                fleches(dr, nom, d, x + a.large / 2.0 * ppt, y + a.oy * ppt, ppt)
            t = ("Vanilla : usine chimique (%s)" % DNOM[d]) if nom == "van" else "%s · %s · %s" % (NOMS[m], PC.MACHINES[m][0], DNOM[d])
            dr.text((x + 4, y + ch + 3), t, fill=(235, 235, 235), font=K.font(fs - 3))
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size, "%.2f Mo" % (os.path.getsize(a.dest) / 1e6))


if __name__ == "__main__":
    main()
