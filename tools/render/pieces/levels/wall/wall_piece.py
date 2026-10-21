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


# Gain d'albédo par époque (Kit.gain, multiplie les albédos de la bible §1.5) : le mur est surtout une FAÇADE
# SUD, qui ne reçoit ni le soleil (ouest) ni l'appoint (zénith) : façade/dessus = 0,368 (CALIBRATION §3.3).
# Réglé par mesure sur les aperçus (measure_wall.py --gains : luminance médiane rendue du corps contre la cible
# de l'époque). Valeurs de reprise (premier modeleur, non mesurées) : 3,0 4,5 3,2 4,2 3,5 4,0 3,0 3,0 3,5 2,4
# 2,2 2,6 2,0 1,8 2,0 ; l'époque 2 sortait à des dessus blancs saturés (255).
# Passe 1 (21/10, 32 échantillons) : L50 mesurée 82 64 91 69 74 48 63 64 88 114 58 115 85 97 (époques 2 à 15).
# Passe 2 : 53 58 64 45 62 42 57 68 67 90 35 76 89 90 ; passe 3 ci-dessous (borne d'albédo qui garde la teinte).
EGAIN = {1: 3.0, 2: 1.75, 3: 2.6, 4: 1.55, 5: 1.3, 6: 2.0, 7: 4.5, 8: 2.8, 9: 1.9, 10: 3.2, 11: 2.0, 12: 4.5, 13: 2.0,
         14: 1.85, 15: 2.6}
# Luminance médiane visée du corps rendu (bible §1.5, sur 255, tolérance ±10).
L50_TARGET = {1: 50, 2: 52, 3: 58, 4: 60, 5: 42, 6: 64, 7: 55, 8: 60, 9: 56, 10: 82, 11: 100, 12: 60, 13: 92, 14: 88,
              15: 108}


# Clés WallPictures (prototype-api.json, WallPictures) rendues en phase 1 : les 2 poses de référence.
# Les 7 autres clés et les 2 raccords (Sprite4Way) viennent en phase 2.
POSE_KEYS = {"droit": "straight_horizontal", "isole": "single"}
PHASE2_KEYS = ("straight_vertical", "corner_right_down", "corner_left_down", "t_up", "ending_right", "ending_left",
               "filling", "water_connection_patch", "gate_connection_patch")

# Contenu de chaque époque (bible docs/DESIGN_EPOQUES.md §5, ligne « Mur ») tel que MODÉLISÉ dans
# wall_epochs.py : silhouette du niveau impair, pièce du niveau pair, couleur émissive, signature de l'ère.
EPOCH_INFO = {
    1: {"cle": "pioneer", "silhouette": "vanilla (mur de pierre, Q11)",
        "piece": "rouleau de barbelé (concertina) sur la chape, agrafes", "emissif": None},
    2: {"cle": "forge", "silhouette": "pierre plaquée d'acier boulonné, 2 merlons d'acier par tuile (crête crénelée)",
        "piece": "pique d'acier au centre, lisse et pointes sur les merlons", "emissif": None},
    3: {"cle": "steam", "silhouette": "brique, tuyau de cuivre le long de la crête, colonnette-cheminée ronde, manomètre",
        "piece": "lanterne à vapeur (globe ambré, cage, chapeau) et arrivée de vapeur", "emissif": "#FFC060"},
    4: {"cle": "oil", "silhouette": "béton à bandes jaunes et noires, poteaux en H et garde-corps sur la crête",
        "piece": "feux d'avertissement orange sur les poteaux, panneau", "emissif": "#FF8C1A"},
    5: {"cle": "volcano", "silhouette": "glacis bas en écailles de tungstène, crête en scie (grande dent au centre, "
                                        "demi-dents aux joints), évent et joints de braise",
        "piece": "orgue de basalte : colonne centrale au-dessus de la dent, colonnes dans les creux de la scie",
        "emissif": "#FF4A10"},
    6: {"cle": "electricity", "silhouette": "clôture électrique : muret, poteau à pile d'isolateurs, fils, éclateur",
        "piece": "traverse et isolateur double, plaque « danger »", "emissif": "#60D0FF"},
    7: {"cle": "crystal", "silhouette": "muret de moellons, 3 pointes de cristal violet serties de bronze",
        "piece": "grand cristal central et éclats", "emissif": "#B070FF"},
    8: {"cle": "swamp", "silhouette": "panneau de verre bombé rempli de liquide luminescent, armature vert-de-gris",
        "piece": "globe de verre sur col, conduit de crête", "emissif": "#A8FF3A"},
    9: {"cle": "atom", "silhouette": "bloc de plomb bas chanfreiné, tour de refroidissement à 8 pans (taille de "
                                     "guêpe, lèvre), anneau d'avertissement, bande verte, fenêtre verte, trèfle",
        "piece": "évents annelés sur les épaules, conduit annelé", "emissif": "#5CFF4A"},
    10: {"cle": "hightech", "silhouette": "carénage arrondi sur pieds (vide sous le corps), bandeau bleu, écran, "
                                          "capteur en dôme",
         "piece": "antennes (fouet et dipôles) sur embases", "emissif": "#3AA8FF"},
    11: {"cle": "titanium", "silhouette": "ailerons en dents de scie inclinés, ajours entre les dents, poutre basse",
         "piece": "aileron central plus haut", "emissif": "#BFE6FF"},
    12: {"cle": "superconductor", "silhouette": "plinthe et bloc noir givré en lévitation (vide), anneau chromé",
         "piece": "gyroscope flottant : anneau horizontal, anneau vertical, noyau noir", "emissif": "#4AF0FF"},
    13: {"cle": "fusion", "silhouette": "plinthe, pylône de céramique à bobines, tore de plasma, champ de plasma",
         "piece": "sphère de confinement à hublot, anneau de plasma incliné au sommet du pylône", "emissif": "#FF4FD8"},
    14: {"cle": "orbit", "silhouette": "bouclier de panneaux inclinés (or froissé, cellules), ajouré, parabole",
         "piece": "mât-balise à feux rouges", "emissif": "#FF2A2A / #2F6BFF"},
    15: {"cle": "legend", "silhouette": "plinthe nacrée et pinacles flottants à 8 pans en or blanc (couronne de "
                                        "flèches), anneau-halo, vides sous et entre les pinacles",
         "piece": "couronne : grand halo d'or blanc, flèche centrale, couronnes à fleurons", "emissif": "#FFF2C0"},
}


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
