"""PLANCHE D'ENSEMBLE de la famille (lot EXP2, 1/11), à l'échelle du jeu : tous les expérimentaux, le Bourdon, Ixion, le vrai silo, un vrai béhémoth.

    py -3.9 tools/render/pieces/experimentaux/ensemble.py --src <sprites des nouveaux> --ref <sprites Ixion, Bourdon> --dest <png> [--noms …]
"""
import argparse
import os
import sys

import numpy as np
from PIL import ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scene as SC  # noqa: E402

GRANDS = [("cairn", "Cairn, âge 10", 30), ("stylet", "Stylet, âge 11", 42), ("trombe", "Trombe, âge 12", 40), ("ixion", "Ixion, âge 13 (fait)", 46), ("tournesol", "Tournesol, âge 14", 50), ("bourdon", "Bourdon, âge 15 (fait)", 62)]
PETITS = [("mat_foudre", "Mât-Foudre, âge 6, défense", 15), ("geode", "Géode, âge 7, attaque", 18), ("sarracenie", "Sarracénie, âge 8, défense", 18), ("demi_vie", "Demi-Vie, âge 9, attaque", 18), ("veilleuse", "Veilleuse, âge 13, défense", 22)]


def couches(src, ref, nom, ppt):
    base = ref if nom in ("ixion", "bourdon") else src
    g = SC.geant(base, nom, ppt)
    ordre = [k for k in ("main",) if k in g] + sorted(k for k in g if k.startswith("glow"))
    if nom == "bourdon":
        b = SC.geant(base, "battant", ppt)
        g["battant_main"] = b["main"]
        ordre = ["battant_main"] + ordre
    return g, ordre


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--ref", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--ppt", type=int, default=16)
    a = ap.parse_args()
    ppt = a.ppt
    # rangée du fond : les géants ; rangée de devant : silo, béhémoth, les petits
    W = sum(l for _, _, l in GRANDS) + 40
    Y1, Y2 = 58, 98
    sc = SC.Scene(W, Y2 + 12, ppt, seed=5)
    gs, ents, lab = [], [], []
    x = 20
    for nom, titre, l in GRANDS:
        px = x + l / 2.0
        if os.path.exists(os.path.join(a.src if nom not in ("ixion", "bourdon") else a.ref, nom, "spec.json")):
            g, o = couches(a.src, a.ref, nom, ppt)
            gs.append({"pos": (px, Y1), "layers": g, "ordre": o})
        lab.append((px - l / 2.0 + 1, Y1 + 5 if nom != "bourdon" else Y1 + 25, titre))
        x += l
    # le silo et le béhémoth au premier rang, puis les petits
    ents.append({"pos": (12, Y2), "layers": SC.vanilla("silo", ppt)})
    ents.append({"pos": (24, Y2 + 1), "layers": SC.behemoth(ppt)})
    lab.append((5, Y2 + 7, "Vanilla : rocket-silo 9×9"))
    lab.append((21, Y2 + 7, "behemoth-biter"))
    ents.append({"pos": (40, Y2), "layers": SC.qg(ppt)})
    lab.append((32, Y2 + 7, "QG âge 15 : 16×8"))
    x = 56
    for nom, titre, l in PETITS:
        px = x + l / 2.0
        if os.path.exists(os.path.join(a.src, nom, "spec.json")):
            g, o = couches(a.src, a.ref, nom, ppt)
            gs.append({"pos": (px, Y2), "layers": g, "ordre": o})
        lab.append((px - l / 2.0 + 1, Y2 + 7, titre))
        x += l + 4
    gs.sort(key=lambda q: q["pos"][1])
    img = sc.rendu(ents, gs)
    im = SC.to_im(img)
    d = ImageDraw.Draw(im)
    f = SC.police(max(13, ppt - 2))
    for (lx, ly, t) in lab:
        d.text((int(lx * ppt), int(ly * ppt)), t, fill=(255, 240, 200), font=f)
    im.save(a.dest, optimize=True)
    print(a.dest, im.size)


if __name__ == "__main__":
    main()
