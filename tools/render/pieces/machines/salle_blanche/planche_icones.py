"""Planche des ICÔNES de la salle blanche (lot CALC-SALLE-BLANCHE, 30/10) : l'icône livrée (graphics/machines/
salle-blanche/sb-icone.png) à 64 et 32 px, dans des fentes d'inventaire de 40 px (fond et cadre approchés du jeu),
à côté des icônes vanilla de machines (assembleur 3, raffinerie, usine chimique, centrifugeuse, labo) et du provisoire
(assembleur 3 teinté (0,90 ; 0,96 ; 1,00)).

    py -3.9 tools/render/pieces/machines/salle_blanche/planche_icones.py --out FICHIER.png
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..", "levels", "commun")))
import compo as K  # noqa: E402

ICONS = K.DATA + "/base/graphics/icons/"


def mip(path, size, tint=None):
    im = Image.open(path).convert("RGBA")
    x = {64: 0, 32: 64, 16: 96, 8: 112}[size] if im.width >= 120 else 0
    im = im.crop((x, 0, x + size, size)) if im.width >= 120 else im.resize((size, size), Image.LANCZOS)
    if tint:
        a = np.asarray(im).astype(np.float64)
        a[..., :3] *= np.array(tint)
        im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    items = [("salle blanche", os.path.join(MOD, "graphics", "machines", "salle-blanche", "sb-icone.png"), None),
             ("provisoire", ICONS + "assembling-machine-3.png", (0.90, 0.96, 1.00)),
             ("assembleur 3", ICONS + "assembling-machine-3.png", None),
             ("raffinerie", ICONS + "oil-refinery.png", None),
             ("usine chimique", ICONS + "chemical-plant.png", None),
             ("centrifugeuse", ICONS + "centrifuge.png", None),
             ("labo", ICONS + "lab.png", None)]
    W, H = 130 * len(items), 210
    im = Image.new("RGB", (W, H), (36, 35, 36))
    d = ImageDraw.Draw(im)
    f = K.font(13, bold=False)
    for i, (t, p, tint) in enumerate(items):
        x = 130 * i + 10
        d.text((x, 6), t, fill=(230, 230, 230), font=f)
        im.paste(mip(p, 64, tint), (x + 20, 30), mip(p, 64, tint))
        # fente d'inventaire de 40 px (icône à 32 px)
        d.rectangle((x + 32, 110, x + 72, 150), fill=(49, 48, 49), outline=(20, 20, 20))
        ic = mip(p, 32, tint)
        im.paste(ic, (x + 36, 114), ic)
        d.rectangle((x + 36, 160, x + 60, 184), fill=(49, 48, 49), outline=(20, 20, 20))
        ic = mip(p, 16, tint)
        im.paste(ic, (x + 40, 164), ic)
    im.save(a.out)
    print("[FO-ICONES-SB] %s" % a.out)


if __name__ == "__main__":
    main()
