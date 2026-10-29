"""PLANCHES DU MUR pour le Directeur Créatif (lot F6, 29/10). Python 3.9, hors Blender (commun/compo.py).

    py -3.9 tools/render/pieces/levels/mur_e/planche.py --mur DIR --dest planche.png --mode ages [--zoom 1|2] [--nuit]
    py -3.9 tools/render/pieces/levels/mur_e/planche.py --mur DIR --dest raccords.png --mode raccords --ages 2,5,8,11,14
    py -3.9 tools/render/pieces/levels/mur_e/planche.py --mur DIR --dest gris.png --mode gris

--mode ages     : les 15 âges, chacun sur le MÊME plan (un fortin qui contient les 8 formes de raccord), peint à l'échelle
                  du jeu (zoom 2 = 64 px par tuile, zoom 1 = 32 px) ; l'âge 1 est le mur de pierre vanilla (niveau 1) ;
--mode raccords : pour chaque âge demandé, les 8 formes une par une (single, vert, horiz, corR, corL, tee, endR, endL) puis
                  une ligne droite de 5 cases, un angle et un T : les raccords tels que le moteur les pose ;
--mode gris     : test du gris de OBJECTIFS D1 : les 15 âges (single et horiz côte à côte) en niveaux de gris, zoom 1.
Le plan reproduit la règle du moteur : forme d'une case = ses voisins EST, OUEST et SUD (le nord est dessiné par le
voisin du nord). Plusieurs --mur : le premier dossier qui a la variante est pris.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
sys.path.insert(0, COMMUN)
import compo as K  # noqa: E402   (charge gun_e/epoques.py sous le nom « epoques » : le nôtre est chargé à part)
import importlib.util as _iu  # noqa: E402
_sp = _iu.spec_from_file_location("mur_epoques", os.path.join(HERE, "epoques.py"))
E = _iu.module_from_spec(_sp)
_sp.loader.exec_module(E)

VANILLA = K.ROOT + "/data/base/graphics/entity/wall/"
# type -> (fichier, largeur d'une variante HR, shift principal en px 32, fichier d'ombre, shift de l'ombre)
VAN = {
    "single": ("single", 64, (0, -5), (10, 17)),
    "vert": ("vertical", 64, (0, 8), (10, 29)),
    "horiz": ("horizontal", 64, (0, -2), (14, 15)),
    "corR": ("corner-right", 64, (0, 7), (17, 28)),
    "corL": ("corner-left", 64, (0, 7), (9, 28)),
    "tee": ("t", 64, (0, 7), (14, 28)),
    "endR": ("ending-right", 64, (0, -3), (17, 15)),
    "endL": ("ending-left", 64, (0, -3), (9, 15)),
}
# plan de démonstration : '#' = mur. Contient les 8 formes (vérifié à l'exécution).
PLAN = [
    "###.#####",
    "#..#...#.",
    "#..#...##",
    "####.#...",
    "...#.#.#.",
]
PLAN_MIN = PLAN


def forme(plan, x, y):
    def m(xx, yy):
        return 0 <= yy < len(plan) and 0 <= xx < len(plan[yy]) and plan[yy][xx] == "#"
    e, o, s = m(x + 1, y), m(x - 1, y), m(x, y + 1)
    return {(0, 0, 0): "single", (0, 0, 1): "vert", (1, 1, 0): "horiz", (1, 0, 1): "corR", (0, 1, 1): "corL",
            (1, 1, 1): "tee", (1, 0, 0): "endR", (0, 1, 0): "endL"}[(int(e), int(o), int(s))]


def formes_du_plan(plan):
    return sorted({forme(plan, x, y) for y, r in enumerate(plan) for x, c in enumerate(r) if c == "#"})


def couches_vanilla(t):
    from PIL import Image as I
    nom, w, sh, shs = VAN[t]
    im = np.asarray(I.open(VANILLA + "hr-wall-%s.png" % nom).convert("RGBA")).astype(np.float64) / 255
    im = im[:, :w]
    sd = np.asarray(I.open(VANILLA + "hr-wall-%s-shadow.png" % nom).convert("RGBA")).astype(np.float64) / 255
    return [{"img": sd, "shift": (shs[0] / 32.0, shs[1] / 32.0), "kind": "shadow", "file": "v"},
            {"img": im, "shift": (sh[0] / 32.0, sh[1] / 32.0), "kind": "main", "file": "v"}]


def couches(dirs, e, t):
    if e == 1:
        return couches_vanilla(t)
    name = "e%02d-%s" % (e, t)
    for d in dirs:
        if os.path.exists(os.path.join(d, name, "spec.json")):
            return K.own(d, name, ("shadow", "main", "glow"))
    return []


def peindre(dirs, e, plan, nuit=False, zoom=2, marge=1):
    W, H = len(plan[0]) + 2 * marge, len(plan) + 2 * marge
    ents = []
    for y, r in enumerate(plan):
        for x, c in enumerate(r):
            if c == "#":
                ents.append({"pos": (x + marge + 0.5, y + marge + 0.5), "layers": couches(dirs, e, forme(plan, x, y))})
    day, night, _ = K.compose(ents, W, H)
    img = night if nuit else day
    if zoom == 1:
        img = K.down2(img)
    return K.to_im(img)


def cadre(titre, ims, ncol, lab=24, pad=6, fond=(24, 24, 28), titre_h=36):
    cw = max(i.size[0] for _, i in ims)
    ch = max(i.size[1] for _, i in ims)
    nrow = (len(ims) + ncol - 1) // ncol
    sheet = Image.new("RGB", (ncol * (cw + pad) + pad, titre_h + nrow * (ch + lab + pad) + pad), fond)
    dr = ImageDraw.Draw(sheet)
    dr.text((8, 7), titre, fill=(255, 200, 110), font=K.font(18))
    for k, (nom, im) in enumerate(ims):
        x = pad + (k % ncol) * (cw + pad)
        y = titre_h + (k // ncol) * (ch + lab + pad)
        dr.text((x + 4, y + 3), nom, fill=(230, 230, 230), font=K.font(14))
        sheet.paste(im, (x, y + lab))
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mur", action="append", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--mode", default="ages", choices=("ages", "raccords", "gris"))
    ap.add_argument("--zoom", type=int, default=2)
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--ages", default=",".join(str(e) for e in range(1, 16)))
    ap.add_argument("--titre", default="")
    ap.add_argument("--cols", type=int, default=3)
    a = ap.parse_args()
    ages = [int(x) for x in a.ages.split(",") if x]
    manque = set(E.ORDRE_TYPES) - set(formes_du_plan(PLAN))
    if manque:
        raise SystemExit("le plan ne contient pas les formes %s" % sorted(manque))
    jn = "nuit" if a.nuit else "jour"
    if a.mode == "ages":
        ims = [("%d · %s%s" % (e, K.NAME[e], "  (vanilla, niveau 1)" if e == 1 else ""),
                peindre(a.mur, e, PLAN, a.nuit, a.zoom)) for e in ages]
        sh = cadre(a.titre or "Mur (lot F6, v1, aperçus) · 15 âges · zoom %d · %s" % (a.zoom, jn), ims, a.cols)
    elif a.mode == "raccords":
        ims = []
        for e in ages:
            ligne = ["....", "...."]
            for t in E.ORDRE_TYPES:
                pass
            # une ligne par âge : les 8 formes isolées (posées sur un plan témoin 2x1 chacune), puis le plan droit
            tiles = []
            for t in E.ORDRE_TYPES:
                tiles.append((t, couches(a.mur, e, t)))
            W = 8 + 2
            ents = [{"pos": (1 + k + 0.5 + (0.0), 1.5), "layers": l} for k, (t, l) in enumerate(tiles)]
            day, night, _ = K.compose(ents, W, 3)
            img = night if a.nuit else day
            if a.zoom == 1:
                img = K.down2(img)
            ims.append(("%d · %s : single, vert, horiz, corR, corL, tee, endR, endL" % (e, K.NAME[e]), K.to_im(img)))
            droit = ["#####", "#...#", "#####"]
            ims.append(("%d · %s : en ligne, angles et T posés par le plan" % (e, K.NAME[e]),
                        peindre(a.mur, e, ["#####.#", "#...###", "#####.#"], a.nuit, a.zoom)))
        sh = cadre(a.titre or "Mur · raccords · zoom %d · %s" % (a.zoom, jn), ims, 2)
    else:
        ims = []
        for e in ages:
            im = peindre(a.mur, e, ["#.##", "..#."], False, 1).convert("L").convert("RGB")
            ims.append(("%d · %s" % (e, K.NAME[e]), im))
        sh = cadre(a.titre or "Mur · test du gris · zoom 1", ims, 5)
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sh.save(a.dest, optimize=True)
    print(a.dest, sh.size, "%.1f Mo" % (os.path.getsize(a.dest) / 1e6))


if __name__ == "__main__":
    main()
