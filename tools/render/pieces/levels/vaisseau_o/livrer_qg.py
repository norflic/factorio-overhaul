"""IMAGES D'UN ÂGE DU QG (série du 31/10) : mêmes planches que page_3etats.py (zoom 1 à côté de l'épave vanilla et de la
raffinerie ; gros plan au zoom 2). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/vaisseau_o/livrer_qg.py --src <sorties de rendre.py> --nom qg01 --emprise 8x4 --titre "Âge 1 · Pionnier" --z1 a.png --gros b.png
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import planche as PL  # noqa: E402

K = PL.K


def z1_etat(src, nom, emp, titre, dest):
    cas = [(K.own(src, nom, ("shadow", "main", "glow")), emp, titre), (PL.couches("", "van:vaisseau"), (16, 8), "Vanilla : épave du vaisseau"),
           (PL.couches("", "van:raffinerie"), (5, 5), "Vanilla : raffinerie")]
    ppt, haut, oy, gap = 32, 12.0, 7.5, 6
    cw = [int((e[0] + 4) * ppt) for _, e, _ in cas]
    sheet = Image.new("RGB", (sum(cw) + gap * 4, int(haut * ppt) + 30), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    x = gap
    for (lay, e, t), w in zip(cas, cw):
        Wt = w / float(ppt)
        day, _, _ = K.compose([{"pos": (Wt / 2.0, oy), "layers": lay}], Wt, haut)
        sheet.paste(K.to_im(K.down2(day)), (x, 0))
        dr.text((x + 6, int(haut * ppt) + 6), "%s · %d×%d" % (t, e[0], e[1]), fill=(235, 235, 235), font=K.font(13))
        x += w + gap
    sheet.save(dest, optimize=True)


def gros_plan(src, nom, emp, dest):
    Wt, Ht = emp[0] + 2.0, emp[1] + 6.0
    day, _, _ = K.compose([{"pos": (Wt / 2.0, Ht - emp[1] / 2.0 - 1.0), "layers": K.own(src, nom, ("shadow", "main", "glow"))}], Wt, Ht)
    im = K.to_im(day)
    w, h = im.size
    cw, ch = min(w, 1100), min(h, 760)
    x0, y0 = (w - cw) // 2, max(0, h - ch - 20)
    im.crop((x0, y0, x0 + cw, y0 + ch)).save(dest, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--nom", required=True)
    ap.add_argument("--emprise", default="8x4")
    ap.add_argument("--titre", default="")
    ap.add_argument("--z1", required=True)
    ap.add_argument("--gros", required=True)
    a = ap.parse_args()
    emp = tuple(int(x) for x in a.emprise.split("x"))
    z1_etat(a.src, a.nom, emp, a.titre or a.nom, a.z1)
    gros_plan(a.src, a.nom, emp, a.gros)
    print(a.z1, a.gros)


if __name__ == "__main__":
    main()
