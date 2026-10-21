"""Tourelle laser, lot V3 (clé « laser »), phase 1 : données de design PURES (aucune dépendance).

Importé par Blender (laser_model.py, render_laser.py) et par le Python système (post, mesures,
planches, manifeste). Source de vérité : docs/DESIGN_EPOQUES.md (bible V1), §1.2 (ères), §1.4
(enveloppes), §1.5 (palette), §1.6 (lumière), §2.4 (fiche laser), §4 (rangs), §5 (fiches d'époque).

Identité invariante de la famille (bible §0) : tête tournante SANS CANON, une LENTILLE ou un
émetteur qui s'allume ; socle à condensateurs. Même structure socle / tête que la mitrailleuse.
Niveaux (Q6) : époque e = niveaux 2e-1 (impair : nouvelle silhouette) et 2e (pair : + une pièce).
Niveau 1 = sprite vanilla inchangé (Q11) ; niveau 2 = vanilla + pièce d'époque 1, masquée au pixel
par l'alpha du socle vanilla (procédé de la variante « four » de V0).
"""
import os

LEVELS = list(range(1, 31))
EPOCHS = list(range(1, 16))


def epoch_of(level):
    return (level + 1) // 2


def hex_srgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_lin1(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexlin(h, gain=1.0):
    """Couleur sRGB #RRGGBB -> linéaire (Blender), multipliée par gain et bornée à 1."""
    return tuple(min(1.0, srgb_to_lin1(c) * gain) for c in hex_srgb(h))


# --- Rangs §4, colonne Laser : O (dépassement au-dessus de l'emprise, tuiles) / L (largeur) / V (vide %)
O_TARGET = {1: 1.02, 2: 1.13, 3: 1.25, 4: 1.36, 5: 1.47, 6: 1.58, 7: 1.70, 8: 1.81, 9: 1.92, 10: 2.04,
            11: 2.15, 12: 2.26, 13: 2.37, 14: 2.49, 15: 2.60}
L_TARGET = {1: 1.72, 2: 1.75, 3: 1.77, 4: 1.80, 5: 1.83, 6: 1.86, 7: 1.88, 8: 1.91, 9: 1.94, 10: 1.96,
            11: 1.99, 12: 2.02, 13: 2.05, 14: 2.07, 15: 2.10}
V_TARGET = {10: 1, 11: 2, 12: 2, 13: 3, 14: 4, 15: 5}
O_CEILING = 2.60          # plafond Q9 (époque 15), tourelle laser
FOOTPRINT = 2             # emprise 2×2 (collision ±0,7, sélection ±1 : turrets.lua:891-892)

# --- Palette §1.5 : luminance médiane cible du corps (sRGB, sur 255), émissif d'époque
LUM_TARGET = {1: 50, 2: 52, 3: 58, 4: 60, 5: 42, 6: 64, 7: 55, 8: 60, 9: 56, 10: 82, 11: 100, 12: 60,
              13: 92, 14: 88, 15: 108}
EMISSIVE = {1: "#FFB060", 2: "#FF6A20", 3: "#FFC060", 4: "#FF8C1A", 5: "#FF4A10", 6: "#60D0FF",
            7: "#B070FF", 8: "#A8FF3A", 9: "#5CFF4A", 10: "#3AA8FF", 11: "#BFE6FF", 12: "#4AF0FF",
            13: "#FF4FD8", 14: "#2F6BFF", 15: "#FFF2C0"}
# époques 1 et 2 : lumière de NUIT seulement (lanterne, fentes de forge) ; lueur de jour dès l'époque 3 (D2-1)
NIGHT_ONLY = {1, 2}

ERA = {e: (e - 1) // 3 + 1 for e in EPOCHS}
ERA_NAME = {1: "I Industrielle", 2: "II Lourde", 3: "III Exotique", 4: "IV Haute techno", 5: "V Stellaire"}

EPOCH_NAME = {1: "Pionnier", 2: "Forge", 3: "Vapeur", 4: "Pétrole", 5: "Volcan", 6: "Électricité",
              7: "Cristal", 8: "Marais", 9: "Atome", 10: "Haute technologie", 11: "Titane",
              12: "Supraconducteurs", 13: "Fusion", 14: "Orbite", 15: "Légende"}

# Fiche §5, colonne « Laser » : silhouette impaire et pièce paire (texte de la bible, résumé fidèle)
ODD_DESIGN = {
    1: "vanilla (sprite inchangé, Q11)",
    2: "tête carénée de plaques rivetées autour de la lentille, avec visière ; socle cerclé",
    3: "tête refroidie par serpentins de cuivre et évent court ; lentille cerclée de laiton ; cheminée ronde au socle",
    4: "tête avec cuve de refroidissement horizontale dorsale et tuyaux ; plate-forme à garde-corps",
    5: "capot trapézoïdal à fente d'émission rougeoyante et ailettes ; socle en tronc de pyramide",
    6: "émetteur entouré d'isolateurs empilés (mini-bobine Tesla), bobine annulaire ; cou en pile d'isolateurs",
    7: "la lentille devient un grand prisme de cristal saillant ; socle de pierre à éclats violets",
    8: "émetteur dans une ampoule de verre frontale à plasma vert ; bulbes au socle",
    9: "tête octogonale plombée, cœur vert par un hublot ; socle chanfreiné à tour hyperboloïde",
    10: "tête-dôme à fente bleue, antenne courte ; socle caréné sur 3 pieds courts",
    11: "tête en fuseau à ailerons ; socle tripode",
    12: "lentille en lévitation entre 2 anneaux ; socle fragmenté, anneau flottant",
    13: "émetteur au centre d'un tore de plasma vertical ; trépied à sphère",
    14: "émetteur en parabole dorée ; plate-forme sur pieds, mât-balise",
    15: "couronne de prismes émetteurs et halo ; base flottante",
}
EVEN_PIECE = {
    1: "muret de sacs de sable devant le socle + câble d'alimentation en tranchée (dépasse de 0,15 au sud)",
    2: "jupe de blindage boulonnée sur l'avant du socle (dépasse de 0,15 sous l'emprise)",
    3: "chaudière auxiliaire basse devant le socle (dépasse de 0,15 au sud)",
    4: "fût de liquide de refroidissement et vanne au coin avant gauche",
    5: "pointes de basalte aux coins avant",
    6: "bobine au sol devant le socle, reliée par un arc",
    7: "anneau de petits cristaux devant le socle",
    8: "condensateurs en bulbes aux coins avant",
    9: "évents annelés aux coins avant",
    10: "batterie carénée devant le socle",
    11: "aileron-condensateur devant le socle",
    12: "pylônes aux coins avant",
    13: "petit tore de plasma au sol",
    14: "panneaux solaires devant le socle",
    15: "anneau-halo au sol",
}

# --- Géométrie commune au modèle (Blender) et au manifeste (Python système) ---
# Hauteur du pivot (haut de la colonne fixe = bas de la tête, unités Blender) par époque : réglée pour que O
# suive le §4 (mesuré par geo_check.py puis measure_laser.py).
PIVOT = {2: 1.32, 3: 1.93, 4: 2.06, 5: 2.19, 6: 2.32, 7: 2.35, 8: 2.65, 9: 2.75, 10: 2.80, 11: 2.90, 12: 2.96,
         13: 3.18, 14: 3.20, 15: 3.21}
# Pivot le plus bas admis par la géométrie du socle (colonnes de hauteur positive, tête au-dessus des pièces du socle).
PIVOT_MIN = {2: 0.85, 3: 1.45, 4: 1.0, 5: 0.95, 6: 0.95, 7: 1.0, 8: 1.1, 9: 1.1, 10: 1.0, 11: 1.4, 12: 1.6, 13: 1.3,
             14: 1.0, 15: 1.4}
# Échelle de la tête autour du pivot. Retouche V3 (reprise, 21/10) : aux ères I à III, les têtes de la 1re passe
# étaient deux fois plus étroites que la tête vanilla (0,5 tuile contre environ 1,3 de face) et perchées sur un
# mât fin (« sucette ») ; elles gagnent 15 à 30 % et le pivot descend pour garder O sur la cible du §4.
HEAD_SCALE = {2: 1.30, 3: 1.25, 4: 1.30, 5: 1.30, 6: 1.25, 7: 1.15, 8: 1.20, 9: 1.30, 10: 1.30, 11: 1.10, 12: 1.15,
              13: 1.15, 14: 1.20, 15: 1.20}
# Pivots réglés par `run_laser.py tune` (O mesuré sur la géométrie -> cible §4) : surchargent PIVOT.
PIVOT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pivot_regle.txt")
try:
    with open(PIVOT_FILE, encoding="utf-8") as _f:
        for _line in _f:
            _p = _line.split("#")[0].split()
            if len(_p) == 2:
                PIVOT[int(_p[0])] = float(_p[1])
except OSError:
    pass
# Centre de la face émettrice (lentille, fente, prisme...) dans le repère de la tête AVANT échelle : (x, y avant,
# z au-dessus du pivot). Sert à proposer attack_parameters.source_offset et beam.source_offset (bible §1.8-6).
LENS_LOCAL = {2: (0.0, 0.80, 0.31), 3: (0.0, 0.70, 0.265), 4: (0.0, 0.73, 0.205), 5: (0.0, 0.69, 0.28),
              6: (0.0, 0.775, 0.26), 7: (0.0, 1.15, 0.25), 8: (0.0, 0.81, 0.22), 9: (0.0, 0.62, 0.32),
              10: (0.0, 0.53, 0.37), 11: (0.0, 0.86, 0.24), 12: (0.0, 0.30, 0.62), 13: (0.0, 0.50, 0.57),
              14: (0.0, 0.60, 0.615), 15: (0.0, 0.76, 0.81)}

# Poses de référence de la phase 1 (Q12 : seules les poses de référence sont rendues en phase 1)
# tête « prepared » : N, E, S, O = images 0, 16, 32, 48 de la feuille vanilla de 64 directions
DIRECTIONS = {"N": 0.0, "E": 90.0, "S": 180.0, "W": 270.0}   # cap en degrés, sens horaire depuis le nord
DIR_FRAME = {"N": 0, "E": 16, "S": 32, "W": 48}

# --- Halo de nuit proportionnel au niveau (bible §1.6, D2-3, proposition) ---
def halo_intensity(level):
    return 0.05 + 0.02 * level


def halo_size(level, s=FOOTPRINT):
    return s * (1.0 + 0.05 * level)


# --- Canevas fixe des rendus d'aperçu (64 px par tuile, origine = position de l'entité au sol) ---
PPT = 64
CANVAS_TILES = (-2.0, 6.0, -4.5, 2.0)        # x0, x1, y0, y1 en tuiles (les ombres partent plein est)
CANVAS_W = int((CANVAS_TILES[1] - CANVAS_TILES[0]) * PPT)   # 512
CANVAS_H = int((CANVAS_TILES[3] - CANVAS_TILES[2]) * PPT)   # 416
ORIGIN_PX = (int(-CANVAS_TILES[0] * PPT), int(-CANVAS_TILES[2] * PPT))   # (128, 288)

# --- Vanilla (turrets.lua:883-1041) : couches hr, scale 0,5 ---
VANILLA = {
    "base": {"file": "laser-turret/hr-laser-turret-base.png", "w": 138, "h": 104, "shift": (-0.5 / 32, 2 / 32)},
    "base_shadow": {"file": "laser-turret/hr-laser-turret-base-shadow.png", "w": 132, "h": 82, "shift": (6 / 32, 3 / 32)},
    "head": {"file": "laser-turret/hr-laser-turret-shooting.png", "w": 126, "h": 120, "shift": (0.0, -35 / 32),
             "line_length": 8},
    "head_shadow": {"file": "laser-turret/hr-laser-turret-shooting-shadow.png", "w": 170, "h": 92,
                    "shift": (50.5 / 32, 2.5 / 32), "line_length": 8},
    "head_glow": {"file": "laser-turret/hr-laser-turret-shooting-light.png", "w": 122, "h": 116,
                  "shift": (-0.5 / 32, -35 / 32), "line_length": 8},
    "lr_base": {"file": "laser-turret/laser-turret-base.png", "w": 70, "h": 52, "shift": (0.0, 2 / 32)},
}
