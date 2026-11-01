"""PLANCHES DES EXPÉRIMENTAUX (lot RB-V0, 31/10) : échelle du jeu (à côté du vrai silo, du QG validé, d'un vrai béhémoth) et gros plan.

    py -3.9 tools/render/pieces/experimentaux/planches.py --src <sprites> --dest <dossier> [--noms ixion,bourdon] [--suffixe ""]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scene as SC  # noqa: E402
import effets as EF  # noqa: E402

TITRES = {"ixion": "IXION, expérimental d'âge 13 : roue de feu", "bourdon": "BOURDON, expérimental d'âge 15 : cloche-cathédrale en lévitation"}
TITRES.update({"cairn": "CAIRN, expérimental d'âge 10 : pile de galets en lévitation", "stylet": "STYLET, expérimental d'âge 11 : lance pointe en bas", "trombe": "TROMBE, expérimental d'âge 12 : tornade d'anneaux",
               "tournesol": "TOURNESOL, expérimental d'âge 14 : miroir sur échasses", "mat_foudre": "MÂT-FOUDRE, petit expérimental d'âge 6, défense", "geode": "GÉODE, petit expérimental d'âge 7, attaque",
               "sarracenie": "SARRACÉNIE, petite expérimentale d'âge 8, défense", "demi_vie": "DEMI-VIE, petit expérimental d'âge 9, attaque", "veilleuse": "VEILLEUSE, petite expérimentale d'âge 13, défense"})
PETITS = ("mat_foudre", "geode", "sarracenie", "demi_vie", "veilleuse")
ORDRE = {"ixion": ("main", "glow_plasma", "glow_soleil", "glow_hublots", "glow_feu"), "bourdon": ("battant_main", "battant_glow", "main", "glow_vitrail", "glow_cristal")}


def couches(src, nom, ppt):
    g = SC.geant(src, nom, ppt)
    ORDRE.setdefault(nom, ["main"] + sorted(k for k in g if k.startswith("glow")))
    if nom == "bourdon":
        b = SC.geant(src, "battant", ppt)
        g["battant_main"] = b["main"]
        if "glow_battant" in b:
            g["battant_glow"] = b["glow_battant"]
    return g


def z1(src, nom, dest):
    ppt = 32
    W_t, H_t, gx, gy = 138, 72, 86, 58
    if nom == "bourdon":
        W_t, H_t, gx, gy = 150, 84, 88, 56
    elif nom in PETITS:
        W_t, H_t, gx, gy = 84, 46, 62, 32
    elif nom in ("cairn", "stylet", "trombe"):
        W_t, H_t, gx, gy = 138, 76, 84, 62
    elif nom == "tournesol":
        W_t, H_t, gx, gy = 150, 78, 82, 64
    sc = SC.Scene(W_t, H_t, ppt, seed=11)
    sol_y = gy
    ents = [{"pos": (9, sol_y), "layers": SC.vanilla("silo", ppt)}, {"pos": (23, sol_y + 1), "layers": SC.behemoth(ppt)}, {"pos": (37, sol_y), "layers": SC.qg(ppt)}]
    img = sc.rendu(ents, [{"pos": (gx, gy), "layers": couches(src, nom, ppt), "ordre": ORDRE[nom]}],
                   air_fn=(lambda i: EF.flammes_tuyeres(i, gx, gy, 0.35, 0, ppt)) if nom == "ixion" else None)
    im = SC.to_im(img)
    d = ImageDraw.Draw(im)
    f = SC.police(22)
    d.text((16, 12), TITRES[nom] + " · zoom 1 du jeu (32 px/tuile)", fill=(255, 225, 150), font=f)
    f2 = SC.police(15)
    y = int((sol_y + 8) * ppt)
    d.text((int(2 * ppt), y), "Vanilla : rocket-silo 9×9", fill=(245, 245, 245), font=f2)
    d.text((int(19.5 * ppt), y), "Vanilla : behemoth-biter", fill=(245, 245, 245), font=f2)
    d.text((int(30 * ppt), y), "QG âge 15, validé : 16×8", fill=(245, 245, 245), font=f2)
    im.save(os.path.join(dest, "%s-z1.png" % nom), optimize=True)
    return im.size


def gros(src, nom, dest):
    ppt = 40
    if nom in PETITS:
        ppt = 48
        W_t, H_t, gx, gy = 34, 30, 16, 24
    elif nom in ("cairn", "stylet", "trombe"):
        W_t, H_t, gx, gy = 64, 62, 30, 56
    elif nom == "tournesol":
        W_t, H_t, gx, gy = 66, 64, 34, 58
    elif nom == "ixion":
        W_t, H_t, gx, gy = 72, 56, 37, 50
    else:
        W_t, H_t, gx, gy = 50, 62, 25, 53
    sc = SC.Scene(W_t, H_t, ppt, seed=12)
    img = sc.rendu([], [{"pos": (gx, gy), "layers": couches(src, nom, ppt), "ordre": ORDRE[nom]}],
                   air_fn=(lambda i: EF.flammes_tuyeres(i, gx, gy, 0.35, 0, ppt)) if nom == "ixion" else None)
    im = SC.to_im(img)
    ImageDraw.Draw(im).text((14, 10), TITRES[nom] + " · gros plan, %d px/tuile (rendu du corps)" % ppt, fill=(255, 225, 150), font=SC.police(30))
    im.save(os.path.join(dest, "%s-gros.png" % nom), optimize=True)
    return im.size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--noms", default="ixion,bourdon")
    ap.add_argument("--sans-gros", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    for n in [x for x in a.noms.split(",") if x]:
        print(n, "z1", z1(a.src, n, a.dest), flush=True)
        if not a.sans_gros:
            print(n, "gros", gros(a.src, n, a.dest), flush=True)


if __name__ == "__main__":
    main()
