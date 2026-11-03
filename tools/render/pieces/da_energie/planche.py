"""PLANCHE DES ÉTATS CLÉS du kit da_energie (lot DA-ENERGIE) : par bâtiment, l'image d'aujourd'hui (sprite vanilla mis à
l'échelle et teinté par le prototype, comme en jeu) À CÔTÉ des variantes, même sol, même échelle, ombres et lueur
composées comme en jeu (commun/compo.py). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/da_energie/planche.py --src DIR --dest planche.png [--zoom 1|2] [--nuit both|no|only]
        [--batiments piscine,depot,msr,geo,reso] [--variantes a,b,c]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "levels", "commun"))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location("den_piece", os.path.join(HERE, "piece.py"))
PC = importlib.util.module_from_spec(_spec)   # nom propre : compo.py charge déjà un autre « piece »
_spec.loader.exec_module(PC)

ENT = os.path.join(K.DATA, "base", "graphics", "entity")
# Image d'aujourd'hui : couches (fichier, rectangle HR, shift en px à 32 px/tuile, genre), échelle, teinte, titre.
VANILLA = {
    "assembleur2": ([("assembling-machine-2/hr-assembling-machine-2-shadow.png", (0, 0, 196, 163), (12, 4.75), "shadow"),
                     ("assembling-machine-2/hr-assembling-machine-2.png", (0, 0, 214, 218), (0, 4), "main")],
                    4.0 / 3.0, (0.55, 0.80, 1.00), "Aujourd'hui : assembleur 2 ×4/3 teinté"),
    "coffre_acier": ([("steel-chest/hr-steel-chest-shadow.png", (0, 0, 110, 46), (12.25, 8), "shadow"),
                      ("steel-chest/hr-steel-chest.png", (0, 0, 64, 80), (-0.25, -0.5), "main")],
                     6.0, (0.62, 0.62, 0.66), "Aujourd'hui : coffre d'acier ×6 teinté"),
    "reacteur": ([("nuclear-reactor/hr-reactor-shadow.png", (0, 0, 525, 323), (52, 0), "shadow"),
                  ("nuclear-reactor/hr-reactor-pipes.png", (0, 0, 320, 316), (-1, -5), "main"),
                  ("nuclear-reactor/hr-reactor.png", (0, 0, 302, 318), (-5, -7), "main"),
                  ("nuclear-reactor/hr-reactor-lights-color.png", (0, 0, 320, 320), (-1, -6), "glow")],
                 1.0, (0.62, 0.86, 1.00), "Aujourd'hui : réacteur nucléaire teinté"),
    "chevalet": ([("pumpjack/hr-pumpjack-base-shadow.png", (440, 0, 660, 220), (6, 0.5), "shadow"),
                  ("pumpjack/hr-pumpjack-horsehead-shadow.png", (0, 0, 309, 82), (17.75, 14.5), "shadow"),
                  ("pumpjack/hr-pumpjack-base.png", (522, 0, 783, 273), (-2.25, -4.75), "main"),
                  ("pumpjack/hr-pumpjack-horsehead.png", (0, 0, 206, 202), (-4, -24), "main")],
                 1.0, (0.95, 0.82, 0.62), "Aujourd'hui : chevalet de pompage teinté (sud)"),
    "balise": ([("beacon/hr-beacon-shadow.png", (0, 0, 244, 176), (12.5, 0.5), "shadow"),
                ("beacon/hr-beacon-bottom.png", (0, 0, 212, 192), (0.5, 1), "main"),
                ("beacon/hr-beacon-top.png", (0, 0, 96, 140), (3, -19), "main"),
                ("beacon/hr-beacon-light.png", (0, 0, 110, 186), (0.5, -18), "glow")],
               1.0, (0.62, 0.86, 1.00), "Aujourd'hui : balise teintée"),
}
# bâtiment : (hauteur de la case en tuiles, y de l'entité dans la case)
CASE = {"piscine": (7.0, 4.3), "depot": (11.5, 7.6), "msr": (8.5, 5.3), "geo": (6.8, 4.4), "reso": (6.8, 4.5)}


def _vanilla(cle):
    lays, k, tint, _ = VANILLA[cle]
    out = []
    for f, rect, sh, kind in lays:
        im = Image.open(os.path.join(ENT, f)).convert("RGBA").crop(rect)
        if k != 1.0:
            im = im.resize((max(1, int(round(im.width * k))), max(1, int(round(im.height * k)))), Image.LANCZOS)
        a = np.asarray(im).astype(np.float64) / 255.0
        if kind != "shadow":
            a[..., :3] *= np.array(tint)
        out.append({"img": a, "shift": (sh[0] / 32.0 * k, sh[1] / 32.0 * k), "kind": kind})
    return out


def _cellule(src, bat, nom, ppt, nuit):
    side = PC.BATIMENTS[bat][2]
    W = side + 3.0
    Hc, oy = CASE[bat]
    lays = _vanilla(PC.BATIMENTS[bat][4]) if nom is None else K.own(src, nom, ("shadow", "main", "glow"))
    day, night, _ = K.compose([{"pos": (W / 2.0, oy), "layers": lays}], W, Hc)
    img = night if nuit else day
    if ppt == 32:
        img = K.down2(img)
    return K.to_im(img)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--zoom", type=int, default=1, choices=(1, 2))
    ap.add_argument("--nuit", default="both", choices=("both", "no", "only"))
    ap.add_argument("--batiments", default="piscine,depot,msr,geo,reso")
    ap.add_argument("--variantes", default="a,b,c")
    ap.add_argument("--titre", default="")
    a = ap.parse_args()
    ppt = 64 if a.zoom == 2 else 32
    bats = [b for b in a.batiments.split(",") if b]
    vs = [v for v in a.variantes.split(",") if v]
    modes = {"both": (False, True), "no": (False,), "only": (True,)}[a.nuit]
    gap, hd, lab = 6, 34, 22 if a.zoom == 1 else 30
    fs = 13 if a.zoom == 1 else 18
    NOMS = {"piscine": "Piscine d'entreposage", "depot": "Dépôt géologique", "msr": "Réacteur à sels fondus",
            "geo": "Capteur géothermique", "reso": "Amplificateur de résonance"}
    rows = []
    for b in bats:
        cells = []
        for nuit in modes:
            cells.append((_cellule(a.src, b, None, ppt, nuit), ("nuit · " if nuit else "") + "aujourd'hui"))
            for v in vs:
                cells.append((_cellule(a.src, b, "%s_%s" % (b, v), ppt, nuit), ("nuit · " if nuit else "") + v))
        t = "%s · %s · %d×%d · âge %d · aujourd'hui = %s" % (NOMS[b], PC.BATIMENTS[b][0], PC.BATIMENTS[b][2], PC.BATIMENTS[b][2],
                                                               PC.BATIMENTS[b][1], VANILLA[PC.BATIMENTS[b][4]][3].split(": ", 1)[1])
        rows.append((t, cells))
    th = 24 if a.zoom == 1 else 32
    W = max(sum(c[0].width for c in r[1]) + gap * (len(r[1]) + 1) for r in rows)
    H = hd + sum(th + max(c[0].height for c in r[1]) + lab + gap for r in rows)
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), a.titre or "DA-ENERGIE · états clés (rendus à 16 éch.) · zoom %d · %s · 1re case : l'image d'aujourd'hui" %
            (a.zoom, {"both": "jour puis nuit", "no": "jour", "only": "nuit"}[a.nuit]), fill=(255, 205, 120), font=K.font(18 if a.zoom == 1 else 24))
    y = hd
    for t, r in rows:
        dr.text((gap + 2, y + 2), t, fill=(150, 210, 255), font=K.font(fs + 2))
        y += th
        x = gap
        hh = max(c[0].height for c in r)
        for im, lb in r:
            sheet.paste(im, (x, y))
            dr.text((x + 4, y + hh + 3), lb, fill=(235, 235, 235), font=K.font(fs, False))
            x += im.width + gap
        y += hh + lab + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size, "%.2f Mo" % (os.path.getsize(a.dest) / 1e6))


if __name__ == "__main__":
    main()
