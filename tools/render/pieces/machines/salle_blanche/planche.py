"""PLANCHES DE COMPARAISON de la salle blanche (lot CALC-SALLE-BLANCHE, 30/10) : nos rendus posés À LA MÊME ÉCHELLE que
les sprites HR vanilla (raffinerie 5x5, assembleur 3, usine chimique, centrifugeuse, labo) et que le visuel PROVISOIRE
(assembleur 3 ×5/3 teinté (0,90 ; 0,96 ; 1,00), prototypes/crafts.lua), sur le sol vanilla, de jour et de nuit (LUT de
game.frag, commun/compo.py), aux zooms 2 (64 px/tuile) et 1 (32 px/tuile), plus une rangée de SILHOUETTES pleines.

    py -3.9 tools/render/pieces/machines/salle_blanche/planche.py --src DIR --out DIR [--only s1,s2,s3,s4] [--tag t]
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..", "levels", "commun")))
import compo as K  # noqa: E402

DATA = K.DATA
ENT = DATA + "/base/graphics/entity/"


def _img(path, x=0, y=0, w=None, h=None, scale=1.0, tint=None):
    im = Image.open(path).convert("RGBA")
    if w is not None:
        im = im.crop((x, y, x + w, y + h))
    if scale != 1.0:
        im = im.resize((int(round(im.width * scale)), int(round(im.height * scale))), Image.LANCZOS)
    a = np.asarray(im).astype(np.float64) / 255.0
    if tint is not None:
        a[..., :3] *= np.array(tint)
    return a


def L(path, w, h, sx, sy, kind="main", scale=1.0, tint=None, x=0, y=0):
    """Couche vanilla HR : image 0 de la feuille, shift en px « by_pixel » (1/32 de tuile)."""
    return {"img": _img(ENT + path, x, y, w, h, scale, tint), "shift": (sx / 32.0 * scale, sy / 32.0 * scale),
            "kind": kind}


def vanilla():
    return {
        "raffinerie (5x5)": [L("oil-refinery/hr-oil-refinery-shadow.png", 674, 426, 82.5, 26.5, "shadow"),
                             L("oil-refinery/hr-oil-refinery.png", 386, 430, 0, -7.5)],
        "assembleur 3 (3x3)": [L("assembling-machine-3/hr-assembling-machine-3-shadow.png", 260, 162, 28, 4, "shadow"),
                               L("assembling-machine-3/hr-assembling-machine-3.png", 214, 237, 0, -0.75)],
        "usine chimique (3x3)": [L("chemical-plant/hr-chemical-plant-shadow.png", 312, 222, 27, 6, "shadow"),
                                 L("chemical-plant/hr-chemical-plant.png", 220, 292, 0.5, -9)],
        "centrifugeuse (3x3)": [L("centrifuge/hr-centrifuge-C-shadow.png", 279, 152, 16.75, -10, "shadow"),
                                L("centrifuge/hr-centrifuge-B-shadow.png", 251, 149, 63.25, 15.25, "shadow"),
                                L("centrifuge/hr-centrifuge-A-shadow.png", 230, 124, 8.5, 23.5, "shadow"),
                                L("centrifuge/hr-centrifuge-C.png", 237, 214, -0.25, -26.5),
                                L("centrifuge/hr-centrifuge-B.png", 156, 234, 23, 6.5),
                                L("centrifuge/hr-centrifuge-A.png", 139, 246, -26.25, 3.5)],
        "labo (3x3)": [L("lab/hr-lab-shadow.png", 242, 136, 13, 11, "shadow"), L("lab/hr-lab.png", 194, 174, 0, 1.5)],
    }


def provisoire():
    k, t = 5.0 / 3.0, (0.90, 0.96, 1.00)
    return [L("assembling-machine-3/hr-assembling-machine-3-shadow.png", 260, 162, 28, 4, "shadow", scale=k, tint=t),
            L("assembling-machine-3/hr-assembling-machine-3.png", 214, 237, 0, -0.75, scale=k, tint=t)]


def ours(src, name, kinds=("shadow", "main", "glow", "light")):
    return K.own(src, name, kinds)


def bande(items, pas=7.5, haut=8.0, night=True):
    """items : [(titre, couches)] posés côte à côte ; renvoie images (jour, nuit) au zoom 2 et alpha."""
    ents = [{"pos": (pas * (i + 0.5), haut * 0.62), "layers": lays} for i, (_, lays) in enumerate(items)]
    day, nig, alpha = K.compose(ents, pas * len(items), haut)
    return day, nig, alpha


def silhouettes(items, pas=7.5, haut=8.0):
    W, H = int(pas * len(items) * 64), int(haut * 64)
    out = np.ones((H, W, 3)) * 0.93
    for i, (_, lays) in enumerate(items):
        for lay in lays:
            if lay["kind"] != "main":
                continue
            img = lay["img"]
            h, w = img.shape[:2]
            x0 = int(round((pas * (i + 0.5) + lay["shift"][0]) * 64 - w / 2))
            y0 = int(round((haut * 0.62 + lay["shift"][1]) * 64 - h / 2))
            a = img[..., 3:4]
            sl = out[max(0, y0):y0 + h, max(0, x0):x0 + w]
            aa = a[max(0, -y0):max(0, -y0) + sl.shape[0], max(0, -x0):max(0, -x0) + sl.shape[1]]
            out[max(0, y0):y0 + h, max(0, x0):x0 + w] = sl * (1 - aa) + 0.12 * aa
    return out


def titres(im, items, pas, ppt, couleur=(255, 255, 255)):
    d = ImageDraw.Draw(im)
    f = K.font(max(12, int(ppt * 0.32)))
    for i, (t, _) in enumerate(items):
        d.text((int(pas * i * ppt) + 8, 6), t, fill=couleur, font=f)
    return im


def grille(im, n, pas, ppt, cote=5, haut=8.0):
    """Repère de l'emprise (cadre pointillé de cote×cote tuiles) sous chaque objet : aide à juger l'échelle."""
    d = ImageDraw.Draw(im)
    for i in range(n):
        cx, cy = pas * (i + 0.5) * ppt, haut * 0.62 * ppt
        h = cote / 2.0 * ppt
        for k in range(0, int(2 * h), 6):
            d.point((cx - h + k, cy + h), fill=(255, 220, 0))
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", default="s1,s2,s3,s4")
    ap.add_argument("--tag", default="sil")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    V = vanilla()
    nos = [(n, ours(a.src, n)) for n in a.only.split(",") if n]
    rangs = {
        "5x5": [("raffinerie vanilla (5x5)", V["raffinerie (5x5)"]), ("PROVISOIRE (asm3 ×5/3)", provisoire())]
        + [("salle blanche " + n, l) for n, l in nos],
        "3x3": [(k, v) for k, v in V.items() if "3x3" in k] + [("salle blanche " + n, l) for n, l in nos[:1]],
    }
    res = {}
    for rang, items in rangs.items():
        pas = 7.5
        day, nig, _ = bande(items, pas)
        for nom, img in (("jour", day), ("nuit", nig)):
            im = K.to_im(img)
            titres(im, items, pas, 64)
            p = os.path.join(a.out, "%s-%s-%s-z2.png" % (a.tag, rang, nom))
            im.save(p)
            im1 = K.to_im(K.down2(img))
            titres(im1, items, pas, 32)
            p1 = os.path.join(a.out, "%s-%s-%s-z1.png" % (a.tag, rang, nom))
            im1.save(p1)
            res["%s-%s" % (rang, nom)] = [os.path.basename(p), os.path.basename(p1)]
        sil = K.to_im(silhouettes(items, pas))
        titres(sil, items, pas, 64, (40, 40, 40))
        grille(sil, len(items), pas, 64)
        ps = os.path.join(a.out, "%s-%s-silhouettes.png" % (a.tag, rang))
        sil.save(ps)
        res["%s-silhouettes" % rang] = [os.path.basename(ps)]
    with open(os.path.join(a.out, "%s-planches.json" % a.tag), "w", encoding="utf-8") as f:
        json.dump(res, f, indent=1)
    print("[FO-PLANCHE] %s" % json.dumps(res, ensure_ascii=False))


if __name__ == "__main__":
    main()
