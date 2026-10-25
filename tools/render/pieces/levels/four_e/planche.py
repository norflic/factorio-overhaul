"""PLANCHES DU FOUR pour le Directeur Créatif (lot F2-A, 25/10). Python 3.9, hors Blender (commun/compo.py).

    py -3.9 tools/render/pieces/levels/four_e/planche.py --four DIR [--four DIR2 …] --dest planche.png
        [--mode ages|gun] [--zoom 1|2] [--nuit] [--pair] [--ages 1,…,15] [--titre "…"]

--mode ages : les 15 âges côte à côte, une LIGNE PAR ÈRE (trois âges de même emprise), même échelle partout (32 px par
              tuile au zoom 1), fenêtre de chaque ligne = côté de l'ère + 3 tuiles ; niveau impair (--pair : niveau
              pair, pièce comprise ; l'âge 1 montre toujours le niveau 2, son niveau 1 est le four vanilla).
--mode gun  : la mitrailleuse VALIDÉE du même âge (pose E, sprites de production : passe 5 et ère V) à gauche de
              chaque four : cohérence de gamme (mêmes matières, même lumière) et non-confusion.
Plusieurs --four : le premier dossier qui a l'âge est pris (ronde de corrections par-dessus la ronde 1).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
sys.path.insert(0, COMMUN)
import compo as K  # noqa: E402

ROOT = K.ROOT + "/fo-logs"
GUN = {e: ROOT + "/2026-10-23_V3E-p5/bas/sprites" for e in range(1, 10)}
GUN.update({e: ROOT + "/2026-10-23_V3E-p5/haut/sprites" for e in (10, 11, 12)})
GUN.update({e: ROOT + "/2026-10-23_V3E-ereV/sprites" for e in (13, 14, 15)})
COTE = {1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4, 10: 5, 11: 5, 12: 5, 13: 6, 14: 6, 15: 6}


def couches(famille, src, e, even):
    K.utiliser(famille)
    return K.level_layers(src, e, "E", even)


def cellule(lays, T, zoom, nuit):
    if not lays:
        img = np.full((int(T * 64), int(T * 64), 3), 0.2)
    else:
        day, night, _ = K.compose([{"pos": (T / 2, T / 2), "layers": lays}], T, T)
        img = night if nuit else day
    if zoom == 1:
        img = K.down2(img)
    return K.to_im(img)


def src_four(dirs, e):
    pre = "e01" if e == 1 else "e%02d" % e
    for d in dirs:
        if os.path.isdir(d) and any(n.startswith(pre + "-") for n in os.listdir(d)):
            return d
    return dirs[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--four", action="append", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--mode", default="ages", choices=("ages", "gun"))
    ap.add_argument("--zoom", type=int, default=1)
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--pair", action="store_true")
    ap.add_argument("--ages", default=",".join(str(e) for e in range(1, 16)))
    ap.add_argument("--titre", default="")
    a = ap.parse_args()
    ages = [int(x) for x in a.ages.split(",") if x]
    eres = []
    for e in ages:
        if not eres or COTE[eres[-1][0]] != COTE[e]:
            eres.append([e])
        else:
            eres[-1].append(e)
    ppt = 64 // (2 if a.zoom == 1 else 1)
    lab = 22
    ncol = max(len(r) for r in eres) * (2 if a.mode == "gun" else 1)
    wmax = max(COTE[r[0]] + 3 for r in eres) * ppt
    W = ncol * (wmax + 6) + 6
    H = 40 + sum((COTE[r[0]] + 3) * ppt + lab + 6 for r in eres) + 6
    sheet = Image.new("RGB", (W, H), (24, 24, 28))
    dr = ImageDraw.Draw(sheet)
    dr.text((8, 8), a.titre or ("Four (lot F2-A, aperçus 32 éch.) · %s · zoom %d · %s · niveau %s" % (
        "15 âges" if a.mode == "ages" else "mitrailleuse validée | four", a.zoom, "nuit" if a.nuit else "jour",
        "pair" if a.pair else "impair")), fill=(255, 200, 110), font=K.font(19))
    y = 40
    for r in eres:
        T = COTE[r[0]] + 3.0
        cw = int(T * ppt)
        x = 6
        for e in r:
            cols = ([("gun_e", GUN[e], "mitrailleuse")] if a.mode == "gun" else []) + [
                ("four_e", src_four(a.four, e), "FOUR")]
            for fam, src, nom in cols:
                even = (a.pair or e == 1) if fam == "four_e" else (e == 1)
                im = cellule(couches(fam, src, e, even), T, a.zoom, a.nuit)
                sheet.paste(im, (x + (wmax - cw) // 2, y + lab))
                dr.text((x + 4, y + 3), "%d · %s · %s" % (e, K.NAME[e], nom), fill=(230, 230, 230), font=K.font(14))
                x += wmax + 6
        y += cw + lab + 6
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size, "%.1f Mo" % (os.path.getsize(a.dest) / 1e6))


if __name__ == "__main__":
    main()
