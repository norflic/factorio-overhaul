"""OUTIL COMMUN : planche d'aperçu (jour, sol vanilla, composé hors moteur). FICHIER GELÉ.

    py -3.9 tools/render/pieces/levels/commun/apercu.py --out DIR --dest planche.png [--famille gun_e]
        [--epochs 2,3,k5] [--poses E,N] [--zoom 1|2] [--pair] [--ref passe3|DIR] [--gris] [--nuit] [--titre "…"]
Lot K0 : outil commun ; composition d'un niveau et emprise : profil de la famille (« passe3 » : sprites de la
mitrailleuse, passe 3).

Une ligne par époque (ou témoin du kit « k2 » … « k6 »), une colonne par pose ; avec --ref, chaque pose est montrée
deux fois : à gauche la référence (passe 3 par défaut), à droite les sprites de --out (« avant | après »). Fenêtre
carrée de côté + 3 tuiles centrée sur l'entité, même échelle partout. Les niveaux impairs (pièce paire avec --pair).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402


def side_of(e):
    return int(e[1:]) if isinstance(e, str) else K.SIDE[e]


def cell(src, e, pose, even, zoom, T, nuit=False, gris=False):
    lays = K.level_layers(src, e, pose, even)
    if not lays:
        img = np.full((int(T * 64), int(T * 64), 3), 0.25)
    else:
        day, night, _ = K.compose([{"pos": (T / 2, T / 2), "layers": lays}], T, T)
        img = night if nuit else day
    if zoom == 1:
        img = K.down2(img)
    if gris:
        img = K.grey(img)
    return K.to_im(img)


def parse_e(s):
    return s if s.startswith("k") else int(s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--epochs", default="2,3,4,5,6,7,8,9,10,11,12,13,14,15")
    ap.add_argument("--poses", default="E,N")
    ap.add_argument("--zoom", type=int, default=1)
    ap.add_argument("--pair", action="store_true")
    ap.add_argument("--ref", default="")
    ap.add_argument("--gris", action="store_true")
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--titre", default="")
    K.option_famille(ap)
    a = ap.parse_args()
    PR = K.utiliser(a.famille or None)
    eps = [parse_e(x) for x in a.epochs.split(",") if x]
    poses = [p for p in a.poses.split(",") if p]
    ref = K.PASSE3 if a.ref == "passe3" else (a.ref or None)
    srcs = ([("passe 3" if a.ref == "passe3" else "réf.", ref)] if ref else []) + [("kit", a.out)]
    T = max(side_of(e) for e in eps) + 3.0
    cw = int(T * 64 / (2 if a.zoom == 1 else 1))
    lab = 26
    cols = [(p, nm, s) for p in poses for nm, s in srcs]
    W = len(cols) * (cw + 6) + 6
    H = 40 + len(eps) * (cw + lab + 6) + 6
    sheet = Image.new("RGB", (W, H), (24, 24, 28))
    dr = ImageDraw.Draw(sheet)
    dr.text((8, 8), a.titre or ("Aperçu kit %s · zoom %d · %s" % (PR.NOM, a.zoom, "nuit" if a.nuit else "jour")),
            fill=(255, 200, 110), font=K.font(20))
    y = 40
    for e in eps:
        x = 6
        for p, nm, s in cols:
            im = cell(s, e, p, a.pair, a.zoom, T, a.nuit, a.gris)
            sheet.paste(im, (x, y + lab))
            name = ("témoin kit %s" % e) if isinstance(e, str) else ("%d · %s" % (e, K.NAME[e]))
            dr.text((x + 4, y + 4), "%s · pose %s · %s" % (name, p, nm), fill=(230, 230, 230), font=K.font(15))
            x += cw + 6
        y += cw + lab + 6
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
