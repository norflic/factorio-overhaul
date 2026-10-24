"""Têtes de la production A3 marquées « HORS REGLE » (trou enfermé au-delà de l'acceptation) : liste et gros plans
(lot A3-jeu, 24/10). Python 3.9 (numpy, Pillow, scipy).

    py -3.9 tools/render/pieces/levels/gun_e/hors_regle.py [--a3 DIR] [--planche FICHIER.png] [--zoom 3]

feuilles.py garde à 4 directions tout âge dont une tête est « HORS REGLE » (produire_a3.py : code 3, « à regarder »),
sauf si on la nomme après l'avoir REGARDÉE : dans feuilles.HORS_REGLE_OK_DEFAUT (pour que la commande sans option du
MANIFEST reproduise les feuilles commitées) ou, pour un essai, dans --hors-regle-ok. Cet outil liste ces têtes (âge, direction, trou,
plafond de l'acceptation), dessine une planche (rendu sur fond vert, plus grand trou enfermé en ROUGE, agrandi) et
imprime l'argument --hors-regle-ok tout prêt. Il ne décide rien.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import feuilles as FE  # noqa: E402

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

QUATRE = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)


def gros_plan(d, zoom):
    s = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
    im = Image.open(os.path.join(d, s["layers"]["main"]["file"])).convert("RGBA")
    a = np.asarray(im)
    lab, n = ndimage.label(a[..., 3] < 128, structure=QUATRE)
    bord = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    tailles = np.bincount(lab.ravel())
    trous = [k for k in range(1, n + 1) if k not in bord]
    fond = Image.new("RGBA", im.size, (60, 120, 60, 255))
    fond.alpha_composite(im)
    c = np.asarray(fond).copy()
    if trous:
        k = max(trous, key=lambda k: tailles[k])
        c[lab == k] = [255, 0, 0, 255]
    return Image.fromarray(c).resize((im.size[0] * zoom, im.size[1] * zoom), Image.NEAREST)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--a3", default=FE.A3_DEFAUT)
    ap.add_argument("--planche", default=None)
    ap.add_argument("--zoom", type=int, default=3)
    a = ap.parse_args()
    liste = []
    for nom in sorted(os.listdir(a.a3)):
        c = os.path.join(a.a3, nom, "controle.json")
        if not os.path.exists(c):
            continue
        cj = json.load(open(c, encoding="utf-8"))
        t = cj.get("trous") or {}
        if t.get("verdict") == "HORS REGLE":
            liste.append((nom, t.get("plus_grand"), t.get("detail")))
    for nom, px, det in liste:
        print("[FO-HORS-REGLE] %s : trou %s px (%s)" % (nom, px, det))
    print("[FO-HORS-REGLE] %d tête(s) « HORS REGLE » ; après les avoir REGARDÉES : --hors-regle-ok %s" % (
        len(liste), ",".join(n for n, _, _ in liste) or "(aucune)"))
    if a.planche and liste:
        ims = [(nom, px, gros_plan(os.path.join(a.a3, nom), a.zoom)) for nom, px, _ in liste]
        W = max(i.size[0] for _, _, i in ims)
        H = max(i.size[1] for _, _, i in ims) + 18
        cols = min(4, len(ims))
        out = Image.new("RGB", (cols * W, -(-len(ims) // cols) * H), (30, 30, 30))
        dr = ImageDraw.Draw(out)
        for i, (nom, px, im) in enumerate(ims):
            x, y = (i % cols) * W, (i // cols) * H
            out.paste(im, (x, y + 18))
            dr.text((x + 4, y + 3), "%s : trou %s px (rouge)" % (nom, px), fill=(240, 240, 240))
        out.save(a.planche)
        print("[FO-HORS-REGLE] planche : %s" % a.planche)
    return 0


if __name__ == "__main__":
    sys.exit(main())
