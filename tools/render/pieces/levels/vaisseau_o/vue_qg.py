"""VUES D'UN ÉTAT DU QG (série du 31/10) : -z1 (échelle du jeu, à côté de l'épave vanilla et de la raffinerie, même
format que les planches du 31/10, sans en-tête, légende dessous) et -gros (zoom 2, recadré sur l'entité). Python 3.9.

    py -3.9 tools/render/pieces/levels/vaisseau_o/vue_qg.py --src <sprites> --nom qg10 --dest <préfixe> [--titre "…"]
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

import planche as PL

K = PL.K


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--nom", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--titre", default="")
    ap.add_argument("--haut", type=float, default=12.0)
    ap.add_argument("--oy", type=float, default=7.8)
    a = ap.parse_args()
    noms = [a.nom, "van:vaisseau", "van:raffinerie"]
    ppt, gap, lab = 32, 6, 30
    ch = int(a.haut * ppt)
    cw = [int((PL.emprise(n)[0] + 4) * ppt) for n in noms]
    sheet = Image.new("RGB", (sum(cw) + (len(noms) + 1) * gap, ch + lab), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    x = gap
    for i, n in enumerate(noms):
        Wt = cw[i] / float(ppt)
        day, _, _ = K.compose([{"pos": (Wt / 2.0, a.oy), "layers": PL.couches(a.src, n)}], Wt, a.haut)
        sheet.paste(K.to_im(K.down2(day)), (x, 0))
        e = PL.emprise(n)
        tt = (a.titre or PL.titre(n)) if i == 0 else {"van:vaisseau": "Vanilla : épave du vaisseau", "van:raffinerie": "Vanilla : raffinerie"}[n]
        dr.text((x + 6, ch + 6), "%s · %d×%d" % (tt, e[0], e[1]), fill=(235, 235, 235), font=K.font(13))
        x += cw[i] + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest + "-z1.png", optimize=True)
    # gros plan : zoom 2, recadré sur le sprite principal (marge 0,6 tuile)
    lays = PL.couches(a.src, a.nom)
    main_l = [l for l in lays if l["kind"] == "main"][0]
    al = main_l["img"][..., 3] > 0.5                      # l'alpha faible de la couche déborde : on cadre sur le corps
    ys, xs = np.where(al)
    h, w = main_l["img"].shape[:2]
    x0, x1, y0, y1 = xs.min() / 64.0, xs.max() / 64.0, ys.min() / 64.0, ys.max() / 64.0
    Wt, Ht = x1 - x0 + 2.4, y1 - y0 + 1.6
    # coin du corps dans la toile : position de l'entité + shift - moitié du sprite + (x0, y0) = (0,8 ; 0,8)
    pos = (0.8 - x0 - main_l["shift"][0] + w / 128.0, 0.8 - y0 - main_l["shift"][1] + h / 128.0)
    day, _, _ = K.compose([{"pos": pos, "layers": lays}], Wt, Ht)
    K.to_im(day).save(a.dest + "-gros.png", optimize=True)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
