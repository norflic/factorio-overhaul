"""Test du regard naïf (charte §6.5), préparation : une image par paire de niveaux, zoom 1, jour, pose E, sol
vanilla, même zoom, légendes « A » et « B » SEULEMENT.

    python tools/render/pieces/levels/gun_s_industriel/naif.py <racine>/data <dumps> <outils charte> <sortie>

L'ordre des fichiers (paire-01.png à paire-06.png) et le côté du plus puissant sont tirés au hasard à chaque
exécution (random.SystemRandom, sans graine), avec exactement trois paires où le plus puissant est à gauche.
La CLÉ n'est écrite nulle part sur le disque : elle n'est imprimée que sur la sortie standard.
"""
import argparse
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import planche as PL  # noqa: E402

PAIRS = [(1, 11), (11, 21), (21, 29), (29, 30), (1, 21), (11, 29)]
LEVELS = {11: ("e06-socle", "e06-tete", 3), 21: ("e11-socle", "e11-tete", 5), 29: ("e15-socle", "e15-tete", 6),
          30: ("e15-socle-piece", "e15-tete", 6)}
try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
except OSError:
    FONT = ImageFont.load_default()


def layers(n, D, a, pose="E"):
    if n == 1:
        return PL.vanilla(D, a.dumps, a.data, "ammo-turret_gun-turret",
                          lambda d: [(d["base_picture"], 0, None), (d["prepared_animation"], 0 if pose == "N" else pose, None)]), 2
    socle, tete, side = LEVELS[n]
    return PL.own(socle) + PL.own("%s-%s" % (tete, pose)), side


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data")
    ap.add_argument("dumps")
    ap.add_argument("outils")
    ap.add_argument("out")
    a = ap.parse_args()
    sys.path.insert(0, a.outils)
    import da_lib as D
    os.makedirs(a.out, exist_ok=True)
    rnd = random.SystemRandom()
    order = list(range(len(PAIRS)))
    rnd.shuffle(order)
    left_strong = [True] * 3 + [False] * 3
    rnd.shuffle(left_strong)
    key = []
    for num, idx in enumerate(order, 1):
        weak, strong = PAIRS[idx]
        A, B = (strong, weak) if left_strong[num - 1] else (weak, strong)
        la, sa = layers(A, D, a)
        lb, sb = layers(B, D, a)
        gap = 2.0
        Wt = 1.5 + sa + gap + sb + 1.5
        smax = max(sa, sb)
        Ht = smax + 4.0
        yc = 2.4 + smax / 2.0
        xa = 1.5 + sa / 2.0
        xb = 1.5 + sa + gap + sb / 2.0
        ents = [{"pos": (xa, yc), "layers": la}, {"pos": (xb, yc), "layers": lb}]
        day, _ = PL.compose(a.data, ents, Wt, Ht)
        im = PL.to_im(PL.down2(day))
        dr = ImageDraw.Draw(im)
        for x, lab in ((xa, "A"), (xb, "B")):
            tx, ty = int(x * 32) - 9, int((yc + smax / 2.0 + 0.55) * 32)
            dr.text((tx + 2, ty + 2), lab, fill=(0, 0, 0), font=FONT)
            dr.text((tx, ty), lab, fill=(245, 245, 235), font=FONT)
        fn = os.path.join(a.out, "paire-%02d.png" % num)
        im.save(fn, optimize=True)
        key.append("paire-%02d.png : A = %d, B = %d, plus puissant = %s" % (num, A, B, "A" if A == strong else "B"))
    print("CLÉ (non écrite sur le disque) :")
    print("\n".join(key))


if __name__ == "__main__":
    main()
