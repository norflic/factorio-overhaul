"""PLANCHE AVANT / APRÈS des tourelles à munitions MARQUÉES (lot VISUELS-DISTINCTS, 10/11) : par tourelle, l'image de la 0.6.80 livrée
(feuilles du dossier du mod déployé) à côté des feuilles marquées (socle de forme propre, liseré et motif de toit de fonction), même sol,
même échelle (zoom 2 = 64 px par tuile), jour et nuit ; puis une rangée « DE LOIN » (zoom 0,5 = 16 px par tuile) : les quatre côte à
côte avant, puis après. Python 3.9, Pillow + numpy, hors Blender (fonctions de planche.py).

    py -3.9 tools/render/pieces/batiments/planche_marques.py --dest <planche.png> [--avant <racine du mod livré>]
"""
import argparse
import json
import os

import numpy as np
from PIL import Image, ImageDraw

import planche as P

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = P.MOD
AVANT_DEFAUT = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\mods\factorio-overhaul"
NOMS = ("bastion1", "lourde", "canon", "mortier")
DIRECTION = 8      # nord-est : la tête de biais, le toit et le socle lisibles


def couches(racine, cle, kinds=("shadow", "main", "glow"), direction=DIRECTION):
    """Couches hr (px relatifs au pied) du socle et de la tête d'une tourelle, lues dans <racine>/graphics/batiments."""
    tab = json.load(open(os.path.join(racine, "graphics", "batiments", "sprites.json"), encoding="utf-8"))[cle]
    out = []
    for k in kinds:
        if k in tab:
            h = tab[k]["hr"]
            p = os.path.join(racine, h["filename"].replace("__factorio-overhaul__/", "").replace("/", os.sep))
            out.append((P.lire(p), (h["shift"][0] * 64, h["shift"][1] * 64), k))
        t = tab.get("tete")
        if t and k in t:
            hh = t[k]["hr"]
            b, r = divmod(direction, tab["rangs"])
            pt = os.path.join(racine, hh["stripes"][b].replace("__factorio-overhaul__/", "").replace("/", os.sep))
            w, ht = hh["width"], hh["height"]
            out.append((P.lire(pt, (0, r * ht, w, (r + 1) * ht)), (hh["shift"][0] * 64, hh["shift"][1] * 64), k))
    return out, tab.get("marque")


def reduit(im, k):
    return im.resize((max(1, int(round(im.width * k))), max(1, int(round(im.height * k)))), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--avant", default=AVANT_DEFAUT)
    a = ap.parse_args()
    f1, f2 = P.font(22), P.font(15, False)
    W, Hh = 300, 300
    blocs = []
    for cle in NOMS:
        titre, proto, cote = P.NOMS[cle]
        av, _ = couches(a.avant, cle)
        ap_, mq = couches(MOD, cle)
        cells = [(P.compose(av, W, Hh, False), "jour · 0.6.80 livrée"), (P.compose(ap_, W, Hh, False), "jour · marquée"),
                 (P.compose(av, W, Hh, True), "nuit · 0.6.80 livrée"), (P.compose(ap_, W, Hh, True), "nuit · marquée")]
        sous = ""
        if mq:
            sous = "socle %s · liseré %s (%.0f°) · toit %s" % (mq["forme"], mq["fonction"], mq["mesure"]["teinte"], mq["toit"])
        blocs.append(("%s · %s · %d×%d" % (titre, proto, cote, cote), sous, cells))
    # de loin : zoom 0,5 (16 px par tuile), les quatre côte à côte
    loin = []
    for racine, lib in ((a.avant, "0.6.80 livrée"), (MOD, "marquées")):
        row = Image.new("RGB", (4 * 150, 150), P.SABLE)
        for i, cle in enumerate(NOMS):
            lays, _ = couches(racine, cle)
            row.paste(reduit(P.compose(lays, 600, 600, False), 0.25), (i * 150, 0))
        loin.append((row, "de loin (zoom 0,5) · " + lib))
    H = 46 + sum(30 + 22 + Hh + 26 for _ in blocs) + sum(30 + 150 + 10 for _ in loin)
    out = Image.new("RGB", (4 * W + 50, H), (22, 22, 27))
    d = ImageDraw.Draw(out)
    d.text((14, 10), "VISUELS-DISTINCTS · tourelles à munitions marquées (socle, liseré de fonction, motif de toit) · zoom 2 · même sol, même échelle",
           fill=(255, 210, 120), font=f1)
    y = 46
    for titre, sous, cells in blocs:
        d.text((14, y), titre, fill=(150, 205, 255), font=f1)
        d.text((14, y + 28), sous, fill=(220, 220, 220), font=f2)
        y += 52
        for i, (im, lib) in enumerate(cells):
            out.paste(im, (10 + i * (W + 10), y))
            d.text((14 + i * (W + 10), y + Hh + 4), lib, fill=(230, 230, 230), font=f2)
        y += Hh + 26
    for im, lib in loin:
        d.text((14, y), lib, fill=(150, 205, 255), font=f1)
        out.paste(im, (10, y + 30))
        y += 190
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    out.save(a.dest, optimize=True)
    tel = a.dest.replace(".png", "-telephone.png")
    if out.width > 1600:
        reduit(out, 1600.0 / out.width).save(tel, optimize=True)
    else:
        out.save(tel, optimize=True)
    print("[FO-PLANCHE] %s (%d × %d) et %s" % (a.dest, out.width, out.height, tel))


if __name__ == "__main__":
    main()
