"""Lot X1-TITANE (25/10) : texture du sol des CHAMPS DE CRATÈRES (fo-crater-fields, âge 11), recolorée depuis un sol
vanilla, par la méthode du lot B0 (tools/biomes/sol_cristal.py : la luminance de la texture vanilla est remappée sur une
rampe de couleurs ; relief, grain, découpe, variantes et masques de transition gardés ; alpha gardé).

Source : dirt-4 (terre à mottes : le relief bosselé devient un régolithe d'impact grumeleux). Rampe : gris neutre
légèrement froid, du creux sombre à la poussière claire ; plus clair que les cendres volcaniques (charbon de bois) et
que l'herbe, pour que l'ilménite noire et sa croûte crème s'y lisent. Choix provisoire, sans verdict du DC.

Sortie (commitée) : graphics/terrain/crateres/sol-crateres.png et hr-sol-crateres.png, même taille que la source.
Usage : py -3.9 tools/biomes/sol_crateres.py [--data <racine>/data] [--dest <mod>/graphics/terrain/crateres]
"""
import argparse
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import sol_cristal as B0  # noqa: E402

SOURCE = "dirt-4"
RAMPE = [
    (0.00, (50, 51, 55)),
    (0.35, (99, 100, 103)),
    (0.65, (128, 128, 129)),
    (0.85, (152, 151, 149)),
    (1.00, (182, 180, 175)),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=B0.DATA_DEFAUT)
    ap.add_argument("--dest", default=os.path.join(B0.MOD, "graphics", "terrain", "crateres"))
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    terr = os.path.join(a.data, "base", "graphics", "terrain")
    for pre in ("", "hr-"):
        src = os.path.join(terr, pre + SOURCE + ".png")
        dst = os.path.join(a.dest, pre + "sol-crateres.png")
        taille, moy = B0.recolore(src, dst, RAMPE)
        print("[FO-X1-SOL] %s -> %s : %dx%d, couleur moyenne (alpha pondéré) %s, %d octets"
              % (os.path.basename(src), os.path.relpath(dst, B0.MOD), taille[0], taille[1], moy, os.path.getsize(dst)))


if __name__ == "__main__":
    main()
