"""Pièce « mur » du pipeline de rendu (lot V3, famille wall, phase 1) : 29 niveaux × 2 poses.

Fichier de pièce au format de tools/render/blender/render_piece.py (PIECE + build), rendu variante par
variante par render_wall.py (ce dossier). Le niveau 1 est le sprite VANILLA (Q11) : aucune image.

Variantes : « nNN-<pose> », NN = niveau 2 à 30, pose = droit (straight_horizontal) ou isole (single).
- Niveau 2 : seule la pièce d'époque 1 (rouleau de barbelé) est rendue ; le post-traitement la pose sur
  le sprite vanilla, masquée au pixel par l'alpha vanilla là où la face vanilla est DEVANT la pièce
  (sous le bord avant de la chape), comme la variante « four » de la cheminée V0.
- Niveaux 3 à 30 : rendu complet (corps de l'époque, plus la pièce aux niveaux pairs).
N'importe pas bpy au niveau du module (lu aussi par le Python système).
"""
import os
import sys

LEVELS = list(range(2, 31))
POSES = ("droit", "isole")

# Sprites vanilla du niveau 1 (entities.lua:4992-5129) : fichier, taille d'une image, shift (tuiles).
VANILLA = {
    "droit": {"hr": ("wall/hr-wall-horizontal.png", 64, 92, (0.0, -2 / 32)),
              "lr": ("wall/wall-horizontal.png", 32, 50, (0.0, -4 / 32)),
              "shadow_hr": ("wall/hr-wall-horizontal-shadow.png", 124, 68, (14 / 32, 15 / 32)),
              "shadow_lr": ("wall/wall-horizontal-shadow.png", 62, 36, (14 / 32, 14 / 32))},
    "isole": {"hr": ("wall/hr-wall-single.png", 64, 86, (0.0, -5 / 32)),
              "lr": ("wall/wall-single.png", 32, 46, (0.0, -6 / 32)),
              "shadow_hr": ("wall/hr-wall-single-shadow.png", 98, 60, (10 / 32, 17 / 32)),
              "shadow_lr": ("wall/wall-single-shadow.png", 50, 32, (10 / 32, 16 / 32))},
}
# Niveau 2 : la face vanilla n'est devant le rouleau que sous le bord avant du dessus de la chape
# (mesuré sur les sprites : chape claire de -0,75 à -0,53 ; bord avant du dessus vers -0,62).
L2_CUT_V = -0.62


def epoch(level):
    return (level + 1) // 2


def halo_spec(level):
    """Halo de nuit (bible §1.6, D2-3) : intensité I(N) = 0,05 + 0,02·N ; rayon S(N) = 0,5·(1 + 0,05·N)
    tuile, borné à 1 tuile pour le mur (des centaines de murs = des centaines de lumières)."""
    s = min(1.0, 0.5 * (1 + 0.05 * level))
    return {"I": round(0.05 + 0.02 * level, 3), "S": round(s, 3),
            "windows": [{"at": (0.0, 0.35, 0.0), "r": (0.45 * s, s)}, {"at": (0.0, 0.35, 1.0), "r": (0.3 * s, 0.75 * s)}]}


def _variants():
    out = {}
    for lv in LEVELS:
        for pose in POSES:
            v = {"dest": "levels/wall/n%02d" % lv, "anchor_tiles": (0.0, 0.0), "level": lv, "pose": pose,
                 "epoch": epoch(lv), "halo": halo_spec(lv)}
            if lv == 2:
                v["overlay_on_vanilla"] = {"hr": VANILLA[pose]["hr"], "lr": VANILLA[pose]["lr"], "cut_v": L2_CUT_V}
            out["n%02d-%s" % (lv, pose)] = v
    return out


PIECE = {"name": "wall", "variants": _variants(), "margin_px": 72,
         "halo": [{"at": (0.0, 0.35, 0.0), "r": (0.5, 1.0)}]}


def build(S, C, variant):
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)
    import wall_kit
    import wall_epochs
    v = PIECE["variants"][variant]
    k = wall_kit.Kit(S, C)
    wall_epochs.build_level(k, v["level"], v["pose"])
