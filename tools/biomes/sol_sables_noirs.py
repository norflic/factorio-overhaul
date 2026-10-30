"""Lot X2 (25/10) : texture du sol des SABLES NOIRS (fo-black-sands, âge 12), recolorée depuis un sol vanilla, par la
méthode du lot B0 (tools/biomes/sol_cristal.py : la luminance de la texture vanilla est remappée sur une rampe de
couleurs ; relief, grain, découpe, variantes et masques de transition gardés ; alpha gardé).

Source : sand-1 (sable fin vanilla : ses vaguelettes deviennent des dunes de sable noir). Rampe : noir de magnétite
légèrement chaud, du creux presque noir au grain le plus clair gris-brun ; plus sombre que les cendres volcaniques
(gris froid) et que tous les sols vanilla, pour que la monazite miel s'y lise de jour comme de nuit. Choix provisoire,
sans verdict du DC.

Sortie (commitée) : graphics/terrain/sables-noirs/sol-sables-noirs.png et hr-sol-sables-noirs.png, même taille que la
source.
Usage : py -3.9 tools/biomes/sol_sables_noirs.py [--data <racine>/data] [--dest <mod>/graphics/terrain/sables-noirs]
"""
import argparse
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import sol_cristal as B0  # noqa: E402

SOURCE = "sand-1"
RAMPE = [
    (0.00, (17, 16, 16)),
    (0.35, (36, 34, 33)),
    (0.65, (52, 49, 47)),
    (0.85, (70, 66, 62)),
    (1.00, (98, 92, 86)),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=B0.DATA_DEFAUT)
    ap.add_argument("--dest", default=os.path.join(B0.MOD, "graphics", "terrain", "sables-noirs"))
    a = ap.parse_args()
    os.makedirs(a.dest, exist_ok=True)
    terr = os.path.join(a.data, "base", "graphics", "terrain")
    for pre in ("", "hr-"):
        src = os.path.join(terr, pre + SOURCE + ".png")
        dst = os.path.join(a.dest, pre + "sol-sables-noirs.png")
        taille, moy = B0.recolore(src, dst, RAMPE)
        print("[FO-X2-SOL] %s -> %s : %dx%d, couleur moyenne (alpha pondéré) %s, %d octets"
              % (os.path.basename(src), os.path.relpath(dst, B0.MOD), taille[0], taille[1], moy, os.path.getsize(dst)))


if __name__ == "__main__":
    main()
