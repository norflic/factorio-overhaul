"""PLANCHE D'ÉTATS CLÉS de la famille MÉTALLURGIE : une rangée par machine, à gauche le sprite qu'elle remplace TEL QU'IL EST EN JEU
aujourd'hui (copie vanilla HR mise à l'échelle de l'emprise et teintée, comme lib.scale_sprites et lib.tint_sprites), puis les
variantes A, B, C ; même sol, même échelle, ombres et lueur composées comme en jeu (levels/commun/compo.py).

    py -3.9 tools/render/pieces/metallurgie/planche.py --src DIR --dest etats-cles.png [--zoom 2] [--nuit]
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

_spec = importlib.util.spec_from_file_location("met_piece", os.path.join(HERE, "piece.py"))
piece = importlib.util.module_from_spec(_spec)   # chargé par chemin : compo importe un autre « piece »
_spec.loader.exec_module(piece)

ENT = os.path.join(K.DATA, "base", "graphics", "entity")
# machine : (titre du sprite remplacé, facteur d'échelle en jeu, teinte, [(fichier, (l, h), shift by_pixel, type)] dans l'ordre du jeu)
AM1 = [("assembling-machine-1/hr-assembling-machine-1-shadow.png", (190, 165), (8.5, 5), "shadow"),
       ("assembling-machine-1/hr-assembling-machine-1.png", (214, 226), (0, 2), "main")]
VANILLA = {
    "hf": ("four en acier ×2, teinté", 2.0, (0.80, 0.62, 0.52), [
        ("steel-furnace/hr-steel-furnace-shadow.png", (277, 85), (39.25, 11.25), "shadow"),
        ("steel-furnace/hr-steel-furnace.png", (171, 174), (-1.25, 2), "main")]),
    "co": ("assembleur 1, teinté", 1.0, (0.78, 0.58, 0.46), AM1),
    "rc": ("four électrique ×4/3, teinté", 4 / 3.0, (0.80, 0.86, 0.95), [
        ("electric-furnace/hr-electric-furnace-shadow.png", (227, 171), (11.25, 7.75), "shadow"),
        ("electric-furnace/hr-electric-furnace.png", (239, 219), (0.75, 5.75), "main")]),
    "py": ("grand poteau, teinté", 1.0, (0.78, 0.84, 0.92), [
        ("big-electric-pole/hr-big-electric-pole-shadow.png", (374, 94), (60, 0), "shadow"),
        ("big-electric-pole/hr-big-electric-pole.png", (148, 312), (0, -51), "main")]),
    "kr": ("centrifugeuse ×4/3, teintée", 4 / 3.0, (0.95, 0.94, 0.90), [
        ("centrifuge/hr-centrifuge-C-shadow.png", (279, 152), (16.75, -10), "shadow"),
        ("centrifuge/hr-centrifuge-B-shadow.png", (251, 149), (63.25, 15.25), "shadow"),
        ("centrifuge/hr-centrifuge-A-shadow.png", (230, 124), (8.5, 23.5), "shadow"),
        ("centrifuge/hr-centrifuge-C.png", (237, 214), (-0.25, -26.5), "main"),
        ("centrifuge/hr-centrifuge-B.png", (156, 234), (23, 6.5), "main"),
        ("centrifuge/hr-centrifuge-A.png", (139, 246), (-26.25, 3.5), "main")]),
    "cc": ("assembleur 1 ×2/3, teinté", 2 / 3.0, (0.72, 0.80, 0.95), AM1),
}
HAUT = {"hf": 10.5, "co": 8.5, "rc": 7.5, "py": 10.0, "kr": 8.0, "cc": 5.5}


def vanilla(m):
    titre, k, tint, lays = VANILLA[m]
    out = []
    for (f, (w, h), s, kind) in lays:
        im = Image.open(os.path.join(ENT, f)).convert("RGBA").crop((0, 0, w, h))
        if k != 1.0:
            im = im.resize((max(1, int(round(w * k))), max(1, int(round(h * k)))), Image.LANCZOS)
        a = np.asarray(im).astype(np.float64) / 255.0
        if kind == "main":
            a[..., :3] *= np.array(tint)
        out.append({"img": a, "shift": (s[0] / 32.0 * k, s[1] / 32.0 * k), "kind": kind})
    return out, "%s %d×%d|en jeu : %s" % (piece.MACHINES[m][2], piece.MACHINES[m][1], piece.MACHINES[m][1], titre)


def ligne(m, src, ppt, nuit, gap):
    side = piece.MACHINES[m][1]
    haut = HAUT[m]
    Wt = side + 3.0
    cells = []
    for c in ["van"] + list(piece.VARIANTES):
        if c == "van":
            lay, t = vanilla(m)
        else:
            lay = K.own(src, "%s_%s" % (m, c), ("shadow", "main", "glow"))
            t = "variante %s|%s" % (c.upper(), piece.MACHINES[m][0])
            if not lay:
                t += " (absent)"
        oy = haut - side / 2.0 - 1.0
        day, night, _ = K.compose([{"pos": (Wt / 2.0, oy), "layers": lay}], Wt, haut, ppt=64)
        img = night if nuit else day
        if ppt == 32:
            img = K.down2(img)
        cells.append((K.to_im(img), t))
    return cells, side


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--zoom", type=int, default=2)
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--machines", default="hf,co,rc,py,kr,cc")
    a = ap.parse_args()
    ppt = 32 * a.zoom
    gap, lab = 6, 34
    rows = [ligne(m, a.src, ppt, a.nuit, gap) for m in a.machines.split(",")]
    W = max(sum(im.width for im, _ in cells) + gap * (len(cells) + 1) for cells, _ in rows)
    H = 34 + sum(max(im.height for im, _ in cells) + lab + gap for cells, _ in rows)
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), "DA-METALLURGIE : états clés (16 échantillons), zoom %d du jeu%s ; à gauche, le sprite remplacé tel qu'il est en jeu"
            % (a.zoom, ", NUIT" if a.nuit else ", jour"), fill=(255, 205, 120), font=K.font(15))
    y = 34
    for cells, side in rows:
        x = gap
        h = max(im.height for im, _ in cells)
        for im, t in cells:
            sheet.paste(im, (x, y))
            for i, part in enumerate(t.split("|")):
                dr.text((x + 4, y + h + 3 + 14 * i), part, fill=(235, 235, 235) if i == 0 else (170, 170, 175), font=K.font(12 if a.zoom == 2 else 10, i == 0))
            x += im.width + gap
        y += h + lab + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
