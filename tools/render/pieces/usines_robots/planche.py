"""PLANCHES DES USINES DE ROBOTS : à l'échelle du jeu, à côté de vrais sprites HR vanilla et du QG gelé (âge 8, DC : « je valide
les designs »), même sol, ombres et lueur composées comme en jeu (levels/commun/compo.py). Gros plan : zoom 2 du jeu ou plus.

    py -3.9 tools/render/pieces/usines_robots/planche.py --src DIR --etat atelier --z1 atelier-z1.png --gros atelier-gros.png
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "levels", "commun"))
import compo as K  # noqa: E402

ENT = os.path.join(K.DATA, "base", "graphics", "entity")
ROOT = K.ROOT
QG = ROOT + "/fo-logs/2026-10-31_QG/age08/final"
EMPRISE = {"atelier": 3, "dock": 7, "portique": 11}
TITRES = {"atelier": "Atelier d'automates · âge 3", "dock": "Dock de pilotage · âge 10", "portique": "Portique · âge 13"}
# (fichier, (x, y, l, h) de la 1re image, shift en px du zoom 1, type) ; ordre de dessin du jeu
VANILLA = {
    "assembleur3": ("Vanilla : assembleur 3", (3, 3), [
        ("assembling-machine-3/hr-assembling-machine-3-shadow.png", (0, 0, 260, 162), (28, 4), "shadow"),
        ("assembling-machine-3/hr-assembling-machine-3.png", (0, 0, 214, 237), (0, -0.75), "main")]),
    "silo": ("Vanilla : silo à fusée", (9, 9), [
        ("rocket-silo/hr-00-rocket-silo-shadow.png", (0, 0, 612, 578), (7, 2), "shadow"),
        ("rocket-silo/hr-01-rocket-silo-hole.png", (0, 0, 400, 270), (-5, 16), "main"),
        ("rocket-silo/hr-04-door-back.png", (0, 0, 312, 286), (37, 12.5), "main"),
        ("rocket-silo/hr-05-door-front.png", (0, 0, 332, 300), (-28, 33), "main"),
        ("rocket-silo/hr-06-rocket-silo.png", (0, 0, 608, 596), (3, -1), "main"),
        ("rocket-silo/hr-14-rocket-silo-front.png", (0, 0, 580, 262), (-1, 78), "main")]),
}


def _png(rel, rect):
    x, y, w, h = rect
    im = Image.open(os.path.join(ENT, rel)).convert("RGBA").crop((x, y, x + w, y + h))
    return np.asarray(im).astype(np.float64) / 255.0


def couches(nom, src):
    if nom.startswith("van:"):
        return [{"img": _png(f, r), "shift": (s[0] / 32.0, s[1] / 32.0), "kind": k} for (f, r, s, k) in VANILLA[nom[4:]][2]]
    if nom == "qg08":
        return K.own(QG, "qg08", ("shadow", "main", "glow"))
    return K.own(src, nom, ("shadow", "main", "glow"))


def infos(nom):
    if nom.startswith("van:"):
        v = VANILLA[nom[4:]]
        return v[0], v[1]
    if nom == "qg08":
        return "QG gelé · âge 8 (validé)", (12, 6)
    e = EMPRISE[nom]
    return TITRES[nom], (e, e)


def planche(noms, src, dest, zoom, haut, titre):
    ppt = 32 * zoom
    gap, hd, lab = 6, 30, 26
    largeurs = [int((infos(n)[1][0] + 3) * ppt) for n in noms]
    W = sum(largeurs) + (len(noms) + 1) * gap
    H = hd + int(haut * ppt) + lab + gap
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 6), titre, fill=(255, 205, 120), font=K.font(16))
    x = gap
    for i, n in enumerate(noms):
        Wt = largeurs[i] / float(ppt)
        ey = infos(n)[1][1]
        # chaque case pose le pied de l'emprise au même niveau : même sol, même échelle
        oy = haut - ey / 2.0 - 1.2
        day = K.compose([{"pos": (Wt / 2.0, oy), "layers": couches(n, src)}], Wt, haut)[0]
        sheet.paste(K.to_im(K.down2(day) if zoom == 1 else day), (x, hd))
        t, e = infos(n)
        dr.text((x + 6, hd + int(haut * ppt) + 4), "%s · %d×%d" % (t, e[0], e[1]), fill=(235, 235, 235), font=K.font(13))
        x += largeurs[i] + gap
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    sheet.save(dest, optimize=True)
    print(dest, sheet.size)


def gros(nom, src, dest, ppt_final, marge=1.2):
    e = EMPRISE[nom]
    lay = couches(nom, src)
    H = e + marge * 2 + 8.0 * (e / 11.0 + 0.45)
    W = e + marge * 2 + 2.0
    oy = H - e / 2.0 - marge
    day = K.compose([{"pos": (W / 2.0 - 0.4, oy), "layers": lay}], W, H)[0]
    im = K.to_im(day)
    # cadre serré sur le bâtiment et son ombre (alpha du corps, marge d'une demi-tuile), puis agrandi d'un facteur fixe
    a = K.compose([{"pos": (W / 2.0 - 0.4, oy), "layers": [l for l in lay if l["kind"] != "shadow"]}], W, H, ground=False)[2]
    ys, xs = np.where(a > 0.05)
    x0, x1 = max(0, xs.min() - 32), min(im.width, xs.max() + 96)
    y0, y1 = max(0, ys.min() - 32), min(im.height, ys.max() + 32)
    im = im.crop((x0, y0, x1, y1))
    k = ppt_final / 64.0
    if k != 1.0:
        im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    im.save(dest, optimize=True)
    print(dest, im.size)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--etat", required=True)
    ap.add_argument("--z1", default="")
    ap.add_argument("--gros", default="")
    a = ap.parse_args()
    n = a.etat
    ref = {"atelier": ["van:assembleur3", "atelier", "qg08"], "dock": ["van:assembleur3", "dock", "qg08"], "portique": ["van:silo", "portique", "qg08"]}[n]
    haut = {"atelier": 12.0, "dock": 12.0, "portique": 18.0}[n]
    if a.z1:
        planche(ref, a.src, a.z1, 1, haut, "%s, à l'échelle du jeu (zoom 1), à côté de vrais sprites vanilla et du QG gelé" % TITRES[n])
    if a.gros:
        gros(n, a.src, a.gros, {"atelier": 160, "dock": 96, "portique": 64}[n])


if __name__ == "__main__":
    main()
