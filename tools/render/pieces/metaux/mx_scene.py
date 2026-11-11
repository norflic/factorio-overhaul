"""Point d'entrée Blender des icônes des MÉTAUX (lot ICONES-DISTINCTES). Lancé par icones.py (jamais à la main) :
    blender -b --factory-startup -noaudio -P mx_scene.py -- --quoi a,b,c --out <dossier> --samples N --taille PX
Sortie : <out>/<quoi>.png (sRGB 16 bits, alpha). Socle de rendu, lumières et matières : ceux des icônes du calcul
(tools/render/pieces/calcul/scene_base.py), pour un style commun."""
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, "..", "calcul"))
sys.path.insert(0, ICI)
import scene_base as P  # noqa: E402
import mx_couleurs  # noqa: E402,F401  (ajoute les matières des métaux à celles du calcul)
import mx_pieces as M  # noqa: E402

# nom : (fonction, élévation, azimut, remplissage du cadre)
SCENES = {
    "fo-magnetic-steel": (M.ic_tole_magnetique, 26, 24, 0.93),
    "fo-iron-plate-r8": (M.ic_billette_fer, 32, 24, 0.93),
    "fo-copper-plate-r8": (M.ic_billette_cuivre, 32, 24, 0.93),
    "fo-tungsten-plate-r8": (M.ic_billette_tungstene, 30, 28, 0.93),
    "fo-titanium-plate": (M.ic_plaques_titane, 50, 18, 0.93),
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    quoi, out, samples, taille = None, None, 16, 512
    for i in range(0, len(argv), 2):
        k, v = argv[i], argv[i + 1]
        if k == "--quoi":
            quoi = v.split(",")
        elif k == "--out":
            out = v
        elif k == "--samples":
            samples = int(v)
        elif k == "--taille":
            taille = int(v)
    os.makedirs(out, exist_ok=True)
    for q in quoi:
        fn, el, az, remplir = SCENES[q]
        P.rendre(fn, os.path.join(out, q + ".png"), samples, taille, el, az, remplir, q)


main()
