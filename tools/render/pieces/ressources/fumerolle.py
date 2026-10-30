"""Feuille PROPRE de la fumerolle (lot AMELIO-RESSOURCES, piste GÉOTHERMIE, 30/10). Python + Pillow, sans Blender,
déterministe ; même méthode que la saumure (saumure.py) : la SILHOUETTE de la flaque de pétrole vanilla (4 variantes,
même découpe, le capteur s'y pose comme le chevalet) recolorée. Ici : une bouche sombre de cendre brûlée (le relief vanilla
gardé, tiré vers un brun chaud), bordée d'une large CROÛTE DE SOUFRE jaune (anneau et halo), semée de cristaux de soufre
jaune vif. Choix provisoire, sans verdict du DC.

    py -3.9 tools/render/pieces/ressources/fumerolle.py "<racine>/data" graphics/ressources/fumerolle
    -> fumerolle.png (296 × 60), hr-fumerolle.png (592 × 120), MANIFEST.json
"""
import hashlib
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import saumure  # noqa: E402

BOUCHE = (34, 28, 24)         # bouche de la fumerolle : cendre brûlée
BOUCHE_CLAIRE = (126, 92, 52)  # relief chaud (reflets vanilla)
SOUFRE = (226, 204, 70)        # croûte de soufre
SOUFRE_OMBRE = (150, 136, 74)
CRISTAL = (255, 238, 96)
ANNEAU = 10
GRAINE = 7108                  # la graine de la fumerolle (shared/content/world.lua)


def main():
    data, sortie = sys.argv[1], sys.argv[2]
    os.makedirs(sortie, exist_ok=True)
    src = Image.open(os.path.join(data, "base", "graphics", "entity", "crude-oil", "hr-crude-oil.png")).convert("RGBA")
    hr = saumure.recolorer(src, eau=BOUCHE, eau_claire=BOUCHE_CLAIRE, sel=SOUFRE, sel_ombre=SOUFRE_OMBRE, anneau=ANNEAU,
                           graine=GRAINE, cristal=CRISTAL, gain_eau=0.45)
    lr = hr.resize((hr.size[0] // 2, hr.size[1] // 2), Image.LANCZOS)
    fichiers = {"hr-fumerolle.png": hr, "fumerolle.png": lr}
    man = {"outil": "tools/render/pieces/ressources/fumerolle.py", "source": "__base__/graphics/entity/crude-oil/hr-crude-oil.png",
           "format": {"frame_count": 4, "variation_count": 1, "width": 74, "height": 60, "hr_width": 148, "hr_height": 120},
           "couleurs": {"bouche": BOUCHE, "bouche_claire": BOUCHE_CLAIRE, "soufre": SOUFRE, "soufre_ombre": SOUFRE_OMBRE,
                        "cristal": CRISTAL, "anneau_px": ANNEAU},
           "sha256": {}}
    for nom, im in sorted(fichiers.items()):
        p = os.path.join(sortie, nom)
        im.save(p, optimize=True)
        man["sha256"][nom] = hashlib.sha256(open(p, "rb").read()).hexdigest()
    with open(os.path.join(sortie, "MANIFEST.json"), "w", encoding="utf-8") as f:
        json.dump(man, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("[FO-FUMEROLLE] %s : %s" % (sortie, ", ".join("%s %dx%d" % (n, i.size[0], i.size[1]) for n, i in sorted(fichiers.items()))))


if __name__ == "__main__":
    main()
