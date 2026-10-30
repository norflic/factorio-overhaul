"""Lot B0 (biomes) : texture du sol de la PLAINE DE CRISTAL (fo-crystal-flats), recolorée depuis un sol vanilla.

Une teinte de prototype ne fait que MULTIPLIER (F36, F38) : aucune teinte ne tire du mauve d'un sable brun. Ici, la
luminance de la texture vanilla (même découpe, mêmes variantes, mêmes masques de transition) est remappée sur une rampe
de couleurs (« gradient map ») : le relief et le grain sont gardés, la couleur est neuve. L'alpha est gardé tel quel.

Sortie (commitée) : graphics/terrain/cristal/sol-cristal.png et hr-sol-cristal.png, même taille que la source.
Usage : py -3.9 tools/biomes/sol_cristal.py [--data <racine>/data] [--dest <mod>/graphics/terrain/cristal]
"""
import argparse
import os

import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(ICI, "..", ".."))
DATA_DEFAUT = os.path.normpath(os.path.join(MOD, "..", "..", "data"))
if not os.path.isdir(DATA_DEFAUT):  # worktree : <racine>/mods/factorio-overhaul/.claude/worktrees/<nom>
    DATA_DEFAUT = os.path.normpath(os.path.join(MOD, "..", "..", "..", "..", "..", "data"))

SOURCE = "sand-3"  # sable ridé : le relief en vaguelettes devient une croûte vitrifiée
# Rampe (luminance normalisée -> sRGB), piste AMELIO-BIOMES (30/10, retour du DC : « le fond rose est moche et on a
# l'impression que des biomes sont mélangés », « les bleues claires sont jolies ») : GIVRE, gris-bleu froid, de la famille
# des éclats aqua (fo-crystal-shard, Lab mesuré 35 ; −16 ; 3). Moyenne visée Lab (≈ 50 ; −6 ; −11) : ΔE ≈ 50 de l'herbe
# (30 ; −2 ; 33), plus clair que les cratères (53 ; 0 ; 0) d'une teinte franche (b ≈ −11 contre 0).
RAMPE = [
    (0.00, (34, 46, 56)),
    (0.35, (74, 95, 110)),
    (0.65, (104, 129, 145)),
    (0.85, (136, 159, 174)),
    (1.00, (186, 202, 213)),
]
# Rampe « mauve bruyère » (lot B0, verdict B1 D du 24/10 ; livrée jusqu'à 0.6.18) : Lab mesuré en jeu (43 ; 11 ; −7).
# Option --mauve, pour la planche avant / après.
RAMPE_MAUVE = [
    (0.00, (37, 27, 40)),
    (0.35, (81, 63, 82)),
    (0.65, (113, 91, 110)),
    (0.85, (139, 119, 134)),
    (1.00, (166, 151, 164)),
]
# Premier essai (24/10, « pâle », capturé dans fo-logs/2026-10-24_B0/apres-pale) : Lab mesuré (53 ; 14 ; −15), ΔE 47-50.
RAMPE_PALE = [
    (0.00, (44, 33, 54)),
    (0.35, (96, 78, 110)),
    (0.65, (134, 112, 148)),
    (0.85, (164, 146, 178)),
    (1.00, (198, 186, 210)),
]
P_BAS, P_HAUT = 2, 98  # centiles de luminance ramenés à 0 et 1


def recolore(src, dst, rampe):
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im, dtype=np.float64)
    rgb, alpha = a[..., :3], a[..., 3]
    y = rgb @ np.array([0.299, 0.587, 0.114])
    vis = alpha > 0
    lo, hi = np.percentile(y[vis], [P_BAS, P_HAUT])
    t = np.clip((y - lo) / max(1e-6, hi - lo), 0, 1)
    xs = [s[0] for s in rampe]
    out = np.empty_like(rgb)
    for c in range(3):
        out[..., c] = np.interp(t, xs, [s[1][c] for s in rampe])
    res = np.dstack([np.clip(np.round(out), 0, 255), alpha]).astype(np.uint8)
    Image.fromarray(res, "RGBA").save(dst, optimize=True)
    w = alpha[vis] / 255.0
    moy = [(out[..., c][vis] * w).sum() / w.sum() for c in range(3)]
    return im.size, [round(v) for v in moy]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=DATA_DEFAUT)
    ap.add_argument("--dest", default=os.path.join(MOD, "graphics", "terrain", "cristal"))
    ap.add_argument("--pale", action="store_true", help="premier essai (rampe pâle), pour comparaison")
    ap.add_argument("--mauve", action="store_true", help="rampe livrée par B0 (mauve bruyère), pour comparaison")
    a = ap.parse_args()
    rampe = RAMPE_PALE if a.pale else (RAMPE_MAUVE if a.mauve else RAMPE)
    os.makedirs(a.dest, exist_ok=True)
    terr = os.path.join(a.data, "base", "graphics", "terrain")
    for pre in ("", "hr-"):
        src = os.path.join(terr, pre + SOURCE + ".png")
        dst = os.path.join(a.dest, pre + "sol-cristal.png")
        taille, moy = recolore(src, dst, rampe)
        print("[FO-B0-SOL] %s -> %s : %dx%d, couleur moyenne (alpha pondéré) %s, %d octets"
              % (os.path.basename(src), os.path.relpath(dst, MOD), taille[0], taille[1], moy, os.path.getsize(dst)))


if __name__ == "__main__":
    main()
