"""PLANCHE D'UN ÉTAT DU QG (refonte du 30/10) : l'état, ses voisins, l'ancienne v6 et des sprites vanilla, sur le même sol,
à la même échelle (zoom 1 = 32 px par tuile, zoom 2 = 64), ombres et lueur composées comme en jeu (commun/compo.py).
L'emprise est tracée au sol en pointillé, et une flèche dit où pointe le nez (règle du DC : à DROITE).

    py -3.9 planche_qg.py --dest p.png --zoom 1 --case "Âge 1 (essai 1)|8x4|<dossier>|qg01|nez" --case "van:vaisseau" ...

Une case : « titre|LxH|dossier contenant <nom>/spec.json|nom[|nez] » ou « van:<vaisseau|raffinerie|roboport|assembleur3> ».
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402
import planche as PL  # noqa: E402

VAN = dict(PL.VANILLA)
VAN["roboport"] = ("roboport/hr-roboport-base.png", (0, 0, 228, 277), (2, 7.75), "roboport/hr-roboport-shadow.png",
                   (0, 0, 294, 201), (28.5, 19.25), (4, 4), "Vanilla : roboport (4×4, le centre actuel en jeu)")


def couches(c):
    if c["van"]:
        f, r, sh, fs, rs, shs, emp, _ = VAN[c["van"]]
        return [{"img": PL._png(fs, rs), "shift": (shs[0] / 32.0, shs[1] / 32.0), "kind": "shadow"},
                {"img": PL._png(f, r), "shift": (sh[0] / 32.0, sh[1] / 32.0), "kind": "main"}]
    return K.own(c["dir"], c["nom"], ("shadow", "main", "glow"))


def parse(s):
    if s.startswith("van:"):
        v = VAN[s[4:]]
        return {"van": s[4:], "titre": v[7], "emp": v[6], "nez": False}
    t = s.split("|")
    w, h = (float(q) for q in t[1].lower().split("x"))
    return {"van": None, "titre": t[0], "emp": (w, h), "dir": t[2], "nom": t[3], "nez": len(t) > 4 and t[4] == "nez"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--case", action="append", required=True)
    ap.add_argument("--zoom", type=int, default=1, choices=(1, 2))
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--titre", default="")
    ap.add_argument("--haut", type=float, default=11.0)
    ap.add_argument("--oy", type=float, default=7.0)
    a = ap.parse_args()
    cases = [parse(s) for s in a.case]
    ppt = 64 if a.zoom == 2 else 32
    ch = int(a.haut * ppt)
    gap, hd, lab = 6, 40, 30
    cw = [int((c["emp"][0] + 4) * ppt) for c in cases]
    Wd = sum(cw) + (len(cases) + 1) * gap
    H = hd + ch + lab + gap
    sheet = Image.new("RGB", (Wd, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), a.titre or "QG · zoom %d · %s" % (a.zoom, "nuit" if a.nuit else "jour"), fill=(255, 205, 120),
            font=K.font(22 if a.zoom == 2 else 18))
    x = gap
    for i, c in enumerate(cases):
        Wt = cw[i] / float(ppt)
        lays = couches(c)
        if lays:
            day, night, _ = K.compose([{"pos": (Wt / 2.0, a.oy), "layers": lays}], Wt, a.haut)
            img = night if a.nuit else day
            if a.zoom == 1:
                img = K.down2(img)
            sheet.paste(K.to_im(img), (x, hd))
        else:
            dr.text((x + 10, hd + 40), "(absent)", fill=(200, 80, 80), font=K.font(16))
        ew, eh = c["emp"]
        cx, cy = x + cw[i] / 2.0, hd + a.oy * ppt
        x0, x1, y0, y1 = cx - ew / 2 * ppt, cx + ew / 2 * ppt, cy - eh / 2 * ppt, cy + eh / 2 * ppt
        for k in range(int(x0), int(x1), 8):
            dr.line([(k, y0), (min(k + 4, x1), y0)], fill=(255, 255, 255))
            dr.line([(k, y1), (min(k + 4, x1), y1)], fill=(255, 255, 255))
        for k in range(int(y0), int(y1), 8):
            dr.line([(x0, k), (x0, min(k + 4, y1))], fill=(255, 255, 255))
            dr.line([(x1, k), (x1, min(k + 4, y1))], fill=(255, 255, 255))
        if c["nez"]:
            ya = hd + ch - 22
            dr.line([(cx - 40, ya), (cx + 40, ya)], fill=(120, 255, 120), width=3)
            dr.polygon([(cx + 40, ya - 7), (cx + 52, ya), (cx + 40, ya + 7)], fill=(120, 255, 120))
            dr.text((cx + 58, ya - 9), "nez", fill=(120, 255, 120), font=K.font(14))
        dr.text((x + 6, hd + ch + 4), "%s · %gx%g" % (c["titre"], ew, eh), fill=(235, 235, 235), font=K.font(18 if a.zoom == 2 else 13))
        x += cw[i] + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
