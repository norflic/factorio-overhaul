"""PLANCHE DE COMPARAISON du centre-vaisseau (kit vaisseau_o, lot CENTRE-OPUS) : nos états À CÔTÉ de sprites vanilla,
même sol, même échelle, ombres et lueur composées comme en jeu (commun/compo.py). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/vaisseau_o/planche.py --src DIR --dest planche.png
        --noms van:vaisseau,epave,age01,van:raffinerie [--zoom 1|2] [--nuit] [--largeur 0] [--titre "…"]

« van:<nom> » : sprite vanilla posé à son shift du jeu (VANILLA ci-dessous). Échelle 1 = zoom 1 du jeu (32 px par
tuile), échelle 2 = zoom 2 (64 px par tuile). --largeur 0 (défaut) : aucune réduction (une planche à zoom 2 réduite
n'est plus à zoom 2).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(HERE)), "levels", "commun"))
import compo as K  # noqa: E402

ENT = os.path.join(K.DATA, "base", "graphics", "entity")
# nom : (fichier principal, rectangle de la 1re image, shift en px du jeu (32/tuile), ombre, rect, shift, emprise, titre)
VANILLA = {
    "vaisseau": ("crash-site-spaceship/hr-spaceship.png", (0, 0, 1228, 790), (-13, 34),
                 "crash-site-spaceship/hr-spaceship-shadow.png", (0, 0, 1340, 842), (-23, 50), (16, 8),
                 "Vanilla : épave du vaisseau (crash-site-spaceship)"),
    "raffinerie": ("oil-refinery/hr-oil-refinery.png", (0, 0, 386, 430), (0, -7.5),
                   "oil-refinery/hr-oil-refinery-shadow.png", (0, 0, 674, 426), (82.5, 26.5), (5, 5),
                   "Vanilla : raffinerie (5×5)"),
    "chimie": ("chemical-plant/hr-chemical-plant.png", (0, 0, 220, 292), (0.5, -4.5),
               "chemical-plant/hr-chemical-plant-shadow.png", (0, 0, 312, 222), (27, 3), (3, 3), "Vanilla : usine chimique (3×3)"),
    "centrifugeuse": ("centrifuge/hr-centrifuge-C.png", (0, 0, 237, 214), (-0.5, -13.5),
                      "centrifuge/hr-centrifuge-C-shadow.png", (0, 0, 276, 200), (29, 3), (3, 3), "Vanilla : centrifugeuse (3×3)"),
    "assembleur3": ("assembling-machine-3/hr-assembling-machine-3.png", (0, 0, 214, 237), (0, -0.75),
                    "assembling-machine-3/hr-assembling-machine-3-shadow.png", (0, 0, 260, 162), (28, 4), (3, 3),
                    "Vanilla : assembleur 3 (3×3)"),
    # DA-CALCUL (4/11) : références de même emprise (data/base/prototypes/entity/entities.lua)
    "roboport": ("roboport/hr-roboport-base.png", (0, 0, 228, 277), (2, 7.75),
                 "roboport/hr-roboport-shadow.png", (0, 0, 294, 201), (28.5, 19.25), (4, 4), "Vanilla : roboport (4×4)"),
    "reacteur": ("nuclear-reactor/hr-reactor.png", (0, 0, 302, 318), (-5, -7),
                 "nuclear-reactor/hr-reactor-shadow.png", (0, 0, 525, 323), (52, 0), (5, 5), "Vanilla : réacteur (5×5)"),
}
sys.path.insert(0, HERE)
import piece as PC  # noqa: E402
EMPRISE = {n: (v[2], v[2]) for n, v in PC.MACHINES.items()}
TITRES = {n: v[0] for n, v in PC.MACHINES.items()}


def _png(rel, rect):
    im = Image.open(os.path.join(ENT, rel)).convert("RGBA").crop(rect)
    return np.asarray(im).astype(np.float64) / 255.0


def _decoupe(nom, src):
    """« nom|dossier|titre » : un état pris dans un autre dossier (ex. l'ancienne v6), titre facultatif."""
    if "|" not in nom:
        return nom, src, None
    p = nom.split("|")
    return p[0], p[1], (p[2] if len(p) > 2 else None)


def couches(src, nom):
    nom, src, _ = _decoupe(nom, src)
    if nom.startswith("van:"):
        f, r, sh, fs, rs, shs, emp, _ = VANILLA[nom[4:]]
        return [{"img": _png(fs, rs), "shift": (shs[0] / 32.0, shs[1] / 32.0), "kind": "shadow"},
                {"img": _png(f, r), "shift": (sh[0] / 32.0, sh[1] / 32.0), "kind": "main"}]
    return K.own(src, nom, ("shadow", "main", "glow"))


def emprise(nom):
    nom = _decoupe(nom, "")[0]
    return VANILLA[nom[4:]][6] if nom.startswith("van:") else EMPRISE[nom]


def titre(nom):
    nom, _, t = _decoupe(nom, "")
    if t:
        return t
    return VANILLA[nom[4:]][7] if nom.startswith("van:") else TITRES.get(nom, nom)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--noms", default="van:vaisseau,epave,age01,age08,age15,van:raffinerie")
    ap.add_argument("--zoom", type=int, default=1, choices=(1, 2))
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--largeur", type=int, default=0)
    ap.add_argument("--titre", default="")
    ap.add_argument("--haut", type=float, default=11.0, help="hauteur d'une case en tuiles")
    ap.add_argument("--oy", type=float, default=7.0, help="y de la position de l'entité dans la case (tuiles)")
    a = ap.parse_args()
    noms = [n for n in a.noms.split(",") if n]
    ppt = 64 if a.zoom == 2 else 32
    ch = int(a.haut * ppt)
    gap, hd, lab = 6, 40, 30
    cw = [int((emprise(n)[0] + 4) * ppt) for n in noms]
    W = sum(cw) + (len(noms) + 1) * gap
    H = hd + ch + lab + gap
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), a.titre or "Centre-vaisseau CENTRE-OPUS · zoom %d · %s · nez à droite" % (a.zoom, "nuit" if a.nuit else "jour"),
            fill=(255, 205, 120), font=K.font(22 if a.zoom == 2 else 18))
    x = gap
    for i, n in enumerate(noms):
        Wt = cw[i] / float(ppt)
        day, night, _ = K.compose([{"pos": (Wt / 2.0, a.oy), "layers": couches(a.src, n)}], Wt, a.haut)
        img = night if a.nuit else day
        if a.zoom == 1:
            img = K.down2(img)
        sheet.paste(K.to_im(img), (x, hd))
        e = emprise(n)
        dr.text((x + 6, hd + ch + 4), "%s · %d×%d" % (titre(n), e[0], e[1]), fill=(235, 235, 235),
                font=K.font(18 if a.zoom == 2 else 13))
        x += cw[i] + gap
    if a.largeur and W > a.largeur:
        k = a.largeur / float(W)
        sheet = sheet.resize((a.largeur, int(H * k)), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size, "%.2f Mo" % (os.path.getsize(a.dest) / 1e6))


if __name__ == "__main__":
    main()
