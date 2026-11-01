"""IMAGES d'un âge du QG (série du 31/10), mêmes cadrages que les états validés (page_3etats.py, branche design-qg-age00) :
ageNN-z1.png (état | épave vanilla | raffinerie, 32 px par tuile) et ageNN-gros.png (zoom 2, recadré). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/vaisseau_o/images_qg.py --src <dossier de rendu> --nom qg04 --emprise 10x5 --titre "Âge 4 · Pétrole" --z1 z1.png --gros gros.png
"""
import argparse

from PIL import Image, ImageDraw

import planche as PL

K = PL.K


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--nom", required=True)
    ap.add_argument("--emprise", required=True)
    ap.add_argument("--titre", required=True)
    ap.add_argument("--z1", required=True)
    ap.add_argument("--gros", required=True)
    a = ap.parse_args()
    emp = tuple(int(x) for x in a.emprise.split("x"))
    lay = K.own(a.src, a.nom, ("shadow", "main", "glow"))
    cas = [(lay, emp, a.titre), (PL.couches("", "van:vaisseau"), (16, 8), "Vanilla : épave du vaisseau"), (PL.couches("", "van:raffinerie"), (5, 5), "Vanilla : raffinerie")]
    ppt, haut, oy, gap = 32, 12.0, 7.5, 6
    cw = [int((e[0] + 4) * ppt) for _, e, _ in cas]
    sheet = Image.new("RGB", (sum(cw) + gap * 4, int(haut * ppt) + 30), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    x = gap
    for (l, e, t), w in zip(cas, cw):
        Wt = w / float(ppt)
        day, _, _ = K.compose([{"pos": (Wt / 2.0, oy), "layers": l}], Wt, haut)
        sheet.paste(K.to_im(K.down2(day)), (x, 0))
        dr.text((x + 6, int(haut * ppt) + 6), "%s · %d×%d" % (t, e[0], e[1]), fill=(235, 235, 235), font=K.font(13))
        x += w + gap
    sheet.save(a.z1, optimize=True)
    Wt, Ht = emp[0] + 2.0, emp[1] + 6.0
    day, _, _ = K.compose([{"pos": (Wt / 2.0, Ht - emp[1] / 2.0 - 1.0), "layers": lay}], Wt, Ht)
    im = K.to_im(day)
    w, h = im.size
    cwg, chg = min(w, 1100), min(h, 760)
    x0, y0 = (w - cwg) // 2, max(0, h - chg - 20)
    im.crop((x0, y0, x0 + cwg, y0 + chg)).save(a.gros, optimize=True)
    print(a.z1, sheet.size, a.gros)


if __name__ == "__main__":
    main()
