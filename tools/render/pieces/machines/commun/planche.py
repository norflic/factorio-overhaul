"""PLANCHE DE COMPARAISON du kit machines (lot DESIGN-CALCUL CALC-MACHINES-AMONT) : nos essais À CÔTÉ de sprites
vanilla HR et de l'AVANT provisoire, même sol, même échelle, ombres et lueur composées comme en jeu
(levels/commun/compo.py, gelé, non modifié). Python 3.9, hors Blender. Copie adaptée de levels/vaisseau_o/planche.py.

    py -3.9 tools/render/pieces/machines/commun/planche.py --src DIR --dest planche.png
        --noms avant:cryo,van:raffinerie,a,b,c [--zoom 1|2] [--nuit] [--titre "…"]

« van:<clé> » : sprite vanilla (1re image), posé à son shift du jeu. « avant:<clé> » : le visuel PROVISOIRE de main
reconstitué hors moteur exactement comme le prototype le fait (sprite vanilla × teinte, mis à l'échelle k : F36,
une teinte ne fait que multiplier) ; ce n'est pas une capture en jeu. Autre nom : un essai rendu (<src>/<nom>/spec.json).
La nuit est approchée (LUT de nuit du jeu, lightMul/lightAdd pris à 1 et 0) ; les lumières vanilla ne sont pas
composées (seuls les sprites).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(HERE)), "levels", "commun"))
import compo as K  # noqa: E402

ENT = os.path.join(K.DATA, "base", "graphics", "entity")
# clé : (principal, rect 1re image, shift px jeu (32/tuile), ombre, rect, shift, emprise, titre)
VANILLA = {
    "raffinerie": ("oil-refinery/hr-oil-refinery.png", (0, 0, 386, 430), (0, -7.5),
                   "oil-refinery/hr-oil-refinery-shadow.png", (0, 0, 674, 426), (82.5, 26.5), 5, "raffinerie (5×5)"),
    "assembleur2": ("assembling-machine-2/hr-assembling-machine-2.png", (0, 0, 214, 218), (0, 4),
                    "assembling-machine-2/hr-assembling-machine-2-shadow.png", (0, 0, 196, 163), (12, 4.75), 3,
                    "assembleur 2 (3×3)"),
    "assembleur3": ("assembling-machine-3/hr-assembling-machine-3.png", (0, 0, 214, 237), (0, -0.75),
                    "assembling-machine-3/hr-assembling-machine-3-shadow.png", (0, 0, 260, 162), (28, 4), 3,
                    "assembleur 3 (3×3)"),
    "four_elec": ("electric-furnace/hr-electric-furnace.png", (0, 0, 239, 219), (0.75, 5.75),
                  "electric-furnace/hr-electric-furnace-shadow.png", (0, 0, 227, 171), (11.25, 7.75), 3,
                  "four électrique (3×3)"),
    "four_acier": ("steel-furnace/hr-steel-furnace.png", (0, 0, 171, 174), (-1.25, 2),
                   "steel-furnace/hr-steel-furnace-shadow.png", (0, 0, 277, 85), (39.25, 11.25), 2, "four en acier (2×2)"),
    "roboport": ("roboport/hr-roboport-base.png", (0, 0, 228, 277), (2, 7.75),
                 "roboport/hr-roboport-shadow.png", (0, 0, 294, 201), (28.5, 19.25), 4, "roboport (4×4, socle seul)"),
    "chimie": ("chemical-plant/hr-chemical-plant.png", (0, 0, 220, 292), (0.5, -9),
               "chemical-plant/hr-chemical-plant-shadow.png", (0, 0, 312, 222), (27, 6), 3, "usine chimique (3×3)"),
}
# visuels PROVISOIRES de main (prototypes/superconductors.lua, tin.lua, titanium.lua) : (vanilla, teinte, échelle, emprise)
AVANT = {
    "cryo": ("raffinerie", (0.70, 0.86, 1.00), 1.0, 5, "AVANT : raffinerie teintée"),
    "imprimante": ("assembleur2", (0.62, 0.92, 0.70), 1.0, 3, "AVANT : assembleur 2 teinté"),
    "frittage": ("assembleur3", (1.00, 0.66, 0.48), 1.0, 3, "AVANT : assembleur 3 teinté"),
    "four_arc": ("assembleur2", (0.80, 0.93, 1.00), 4.0 / 3.0, 4, "AVANT : assembleur 2 ×4/3 teinté"),
}


def _png(rel, rect, k=1.0):
    im = Image.open(os.path.join(ENT, rel)).convert("RGBA").crop(rect)
    if k != 1.0:
        im = im.resize((int(round(im.width * k)), int(round(im.height * k))), Image.LANCZOS)
    return np.asarray(im).astype(np.float64) / 255.0


def couches(src, nom):
    if nom.startswith("van:") or nom.startswith("avant:"):
        tint, k = (1.0, 1.0, 1.0), 1.0
        key = nom.split(":", 1)[1]
        if nom.startswith("avant:"):
            key, tint, k = AVANT[key][0], AVANT[key][1], AVANT[key][2]
        f, r, sh, fs, rs, shs, _, _ = VANILLA[key]
        main = _png(f, r, k)
        main[..., :3] *= np.array(tint)
        return [{"img": _png(fs, rs, k), "shift": (shs[0] * k / 32.0, shs[1] * k / 32.0), "kind": "shadow"},
                {"img": main, "shift": (sh[0] * k / 32.0, sh[1] * k / 32.0), "kind": "main"}]
    return K.own(src, nom, ("shadow", "main", "glow", "light"))


def meta(src, nom):
    if nom.startswith("van:"):
        v = VANILLA[nom[4:]]
        return v[6], "Vanilla : " + v[7]
    if nom.startswith("avant:"):
        v = AVANT[nom[6:]]
        return v[3], v[4]
    s = json.load(open(os.path.join(src, nom, "spec.json"), encoding="utf-8"))
    return s["side"], s.get("titre", nom)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="")
    ap.add_argument("--dest", required=True)
    ap.add_argument("--noms", required=True)
    ap.add_argument("--zoom", type=int, default=1, choices=(1, 2))
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--titre", default="")
    ap.add_argument("--haut", type=float, default=0.0, help="hauteur d'une case en tuiles (0 : max emprise + 4)")
    a = ap.parse_args()
    noms = [n for n in a.noms.split(",") if n]
    metas = [meta(a.src, n) for n in noms]
    big = max(m[0] for m in metas)
    haut = a.haut or big + 4.0
    oy = haut - big / 2.0 - 1.0
    ppt = 64 if a.zoom == 2 else 32
    ch = int(haut * ppt)
    gap, hd, lab = 6, 34, 26
    cw = [int((m[0] + 3) * ppt) for m in metas]
    W = sum(cw) + (len(noms) + 1) * gap
    H = hd + ch + lab + gap
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), a.titre or "zoom %d · %s" % (a.zoom, "nuit" if a.nuit else "jour"), fill=(255, 205, 120),
            font=K.font(20 if a.zoom == 2 else 16))
    x = gap
    for i, n in enumerate(noms):
        Wt = cw[i] / float(ppt)
        day, night, _ = K.compose([{"pos": (Wt / 2.0, oy), "layers": couches(a.src, n)}], Wt, haut)
        img = night if a.nuit else day
        if a.zoom == 1:
            img = K.down2(img)
        sheet.paste(K.to_im(img), (x, hd))
        dr.text((x + 4, hd + ch + 4), metas[i][1], fill=(235, 235, 235), font=K.font(16 if a.zoom == 2 else 12))
        x += cw[i] + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size)


if __name__ == "__main__":
    main()
