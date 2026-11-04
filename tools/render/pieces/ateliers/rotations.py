"""CONTRÔLE HORS JEU DES RACCORDS (lot DA-ATELIERS) : le corps d'une machine à fluide et, pour chacune des 4 rotations, le tronçon de
raccord (pipe_picture) posé au point de connexion du prototype, plus un tuyau vanilla sur la tuile voisine ; repère rouge au point
de connexion. Ordre de dessin du moteur : tronçon nord SOUS le corps (secondary_draw_orders north = −1), les autres par-dessus.
La preuve reste la capture en jeu des 4 rotations (demande du lead, 3/11).

    py -3.9 tools/render/pieces/ateliers/rotations.py --src DIR --dest planche.png [--batiments bobineuse,torchere,taillerie]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "levels", "commun"))
import compo as K  # noqa: E402

# connexion d'entrée (x, y du JEU, y sud +) dans chaque direction de la machine ; prototypes/crafts.lua fluid_box (dx, −(h + 0,5))
# tourné par le moteur : nord (dx, −h−½), est (h+½, dx), sud (−dx, h+½), ouest (−h−½, −dx)
COTE_DX = {"bobineuse": (2, -0.5), "torchere": (2, -0.5), "taillerie": (3, 0.0)}
PIPE = os.path.join(K.DATA, "base", "graphics", "entity", "pipe", "hr-pipe-straight-vertical.png")
PIPE_H = os.path.join(K.DATA, "base", "graphics", "entity", "pipe", "hr-pipe-straight-horizontal.png")


def connexions(bat):
    side, dx = COTE_DX[bat]
    h = side / 2.0
    return {"n": (dx, -h - 0.5), "e": (h + 0.5, dx), "s": (-dx, h + 0.5), "o": (-h - 0.5, -dx)}


def tuyau_vanilla(d):
    im = Image.open(PIPE if d in ("n", "s") else PIPE_H).convert("RGBA")
    return {"img": np.asarray(im).astype(np.float64) / 255.0, "shift": (0.0, 0.0), "kind": "main"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--batiments", default="bobineuse,torchere,taillerie")
    ap.add_argument("--variante", default="a")
    a = ap.parse_args()
    bats = [b for b in a.batiments.split(",") if b]
    ppt, CW, CH = 64, 6.0, 7.0
    W, H = int(4 * CW * ppt) + 5 * 6, len(bats) * (int(CH * ppt) + 30) + 40
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), "DA-ATELIERS · raccords des 4 rotations (corps : vue unique ; tronçon au point de connexion ; repère rouge)",
            fill=(255, 205, 120), font=K.font(20))
    y = 40
    for bat in bats:
        corps = K.own(a.src, "%s_%s" % (bat, a.variante), ("shadow", "main", "glow"))
        x = 6
        for d, (cx, cy) in connexions(bat).items():
            rac = K.own(a.src, "raccord_%s_%s" % (bat, d), ("shadow", "main"))
            pos0 = (CW / 2.0, CH * 0.62)
            posc = (pos0[0] + cx, pos0[1] + cy)
            pipe = {"pos": posc, "layers": [tuyau_vanilla(d)]}
            if d == "n":           # tronçon nord sous le corps : l'ordre en y de compo suffit (connexion au nord du corps)
                day = K.compose([pipe, {"pos": posc, "layers": rac}, {"pos": pos0, "layers": corps}], CW, CH)[0]
            else:                  # tronçon par-dessus le corps : composé à part puis posé dessus
                day = K.compose([pipe, {"pos": pos0, "layers": corps}], CW, CH)[0]
                over = K.compose([{"pos": posc, "layers": [l for l in rac if l["kind"] != "shadow"]}], CW, CH, ground=False)
                a3 = over[2][..., None]
                day = over[0] * a3 + day * (1 - a3)
            im = K.to_im(day)
            g = ImageDraw.Draw(im)
            px, py = posc[0] * ppt, posc[1] * ppt
            g.ellipse((px - 4, py - 4, px + 4, py + 4), outline=(255, 40, 40), width=2)
            sheet.paste(im, (x, y))
            dr.text((x + 6, y + int(CH * ppt) + 4), "%s %s : connexion (%.1f ; %.1f)" % (bat, d.upper(), cx, cy), fill=(235, 235, 235),
                    font=K.font(15))
            x += int(CW * ppt) + 6
        y += int(CH * ppt) + 30
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
