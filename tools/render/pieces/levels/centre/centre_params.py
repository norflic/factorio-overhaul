"""Paramètres du centre de commandement, 15 niveaux (niveau = époque ; Q6, bible §1.1).

Python PUR : lu par Blender (centre.py), par le pilote de rendu, par la mesure D1 et par les planches.
Sources : docs/DESIGN_EPOQUES.md §1.4 (plafonds), §1.5 (palette, luminance cible), §1.6 (lumière),
§4 (enveloppes O / L / V par rang), §5 (fiches d'époque, ligne « Centre »).
"""

FOOTPRINT = 4                       # emprise 4×4 (collision ±1,7 ; sélection ±2), inchangée (D1-4)
O_CEILING = 3.60                    # plafond Q9 du centre (époque 15)
L_MAX = 3.90

# Enveloppes du §4 (rang = époque) : O cible, L max, V minimal (% du masque du niveau 1 laissé vide)
ENVELOPE = {
    1: (0.41, 3.41, 0), 2: (0.64, 3.45, 0), 3: (0.87, 3.48, 0), 4: (1.09, 3.52, 0), 5: (1.32, 3.55, 0),
    6: (1.55, 3.58, 0), 7: (1.78, 3.62, 0), 8: (2.00, 3.66, 0), 9: (2.23, 3.69, 0), 10: (2.46, 3.73, 4),
    11: (2.69, 3.76, 8), 12: (2.92, 3.79, 12), 13: (3.14, 3.83, 17), 14: (3.37, 3.86, 21), 15: (3.60, 3.90, 25),
}

# Luminance médiane cible du corps (sur 255, ±10 ; bible §1.5) et part émissive proposée (§1.6)
LUM_TARGET = {1: 50, 2: 52, 3: 58, 4: 60, 5: 42, 6: 64, 7: 55, 8: 60, 9: 56, 10: 82, 11: 100, 12: 60, 13: 92,
              14: 88, 15: 108}
EMISSIVE_SHARE = {3: 0.01, 5: 0.03, 7: 0.05, 10: 0.07, 13: 0.10, 15: 0.12}

NAMES = {
    1: "Poste de pionnier", 2: "Bastion d'acier", 3: "Hôtel de la vapeur", 4: "QG de raffinerie",
    5: "Citadelle volcanique", 6: "Centrale de commandement", 7: "Sanctuaire de résonance",
    8: "Serre-laboratoire", 9: "Bunker atomique", 10: "QG radar", 11: "Tour blanche", 12: "Nexus",
    13: "Citadelle-réacteur", 14: "Spatioport de commandement", 15: "Palais",
}
ERA = {e: (e - 1) // 3 + 1 for e in range(1, 16)}

# Gain d'albédo par époque (multiplie la couleur linéaire de la bible) : réglé sur la luminance médiane
# MESURÉE du rendu (mesures_d1.py, colonne « L50 »). Journal :
#  - valeurs du premier modeleur (jamais mesurées) : 1,9 / 1,7 / 1,6 / 1,6 / 1,7 / 1,15 / 1,6 / 1,5 / 1,5 /
#    1,25 / 1,15 / 1,6 / 1,1 / 1,15 / 1,05 → L50 mesurée (aperçu à 8 échantillons, 21/10 20 h 50) : 71, 76,
#    72, 75, 47, 160, 103, 87, 68, 143, 148, 41, 162, 97, 179 pour des cibles 50, 52, 58, 60, 42, 64, 55, 60,
#    56, 82, 100, 60, 92, 88, 108 : trop clair partout sauf aux époques 5 et 12 ;
#  - correction : gain × (cible / L50)^2,2 (sRGB → linéaire), puis arrondi ; époques 6, 7, 11, 13, 15
#    corrigées à part (toit blanc de l'époque 6 refait ; lueurs trop fortes réduites partout).
ALBEDO_GAIN = {1: 0.9, 2: 0.75, 3: 1.0, 4: 1.0, 5: 1.35, 6: 0.9, 7: 1.0, 8: 0.7, 9: 1.0, 10: 0.4, 11: 0.55,
               12: 1.6, 13: 0.45, 14: 0.95, 15: 0.45}

# Lumière de NUIT seulement aux époques 1 et 2 (bible §5 : lanterne, forge) ; lueur de jour dès l'époque 3.
NIGHT_ONLY = {1, 2}


def halo_script(e):
    """Halo de nuit proportionnel au niveau (bible §1.6) : I(N) = 0,05 + 0,02·N ; S(N) = s·(1 + 0,05·N),
    N = 2e pour le centre, s = 4. À poser par script en phase 2 (rendering.draw_light, F44)."""
    n = 2 * e
    return {"intensity": round(0.05 + 0.02 * n, 3), "size": round(FOOTPRINT * (1 + 0.05 * n), 3)}


# Sources de la passe halo (draw_as_light) : (x, ty, z, couleur, puissance W, rayon plein, rayon nul)
# - fenêtre « src » autour de la source projetée ; fenêtre « sol » à l'aplomb (z = 0), si rsol > 0.
# Positions identiques à celles des pièces lumineuses de centre_ere*.py (lues par build).
HALO = {
    1: [(0.42, 0.50, 0.63, "#FFB060", 7.0, 0.35, 0.9, 1.0, 2.0),
        (-0.68, 0.45, 0.52, "#FFB060", 2.5, 0.2, 0.6, 0.6, 1.4)],
    2: [(0.0, 0.12, 1.16, "#FF6A20", 6.0, 0.4, 1.0, 0.0, 0.0),
        (-1.36, 1.2, 0.54, "#FF6A20", 4.0, 0.3, 0.8, 0.7, 1.5),
        (1.36, 1.2, 0.54, "#FF6A20", 4.0, 0.3, 0.8, 0.7, 1.5),
        (0.0, 1.24, 0.68, "#FF6A20", 5.0, 0.3, 0.8, 0.9, 1.8)],
    3: [(0.0, 1.2, 1.06, "#FFC060", 10.0, 0.45, 1.1, 1.0, 2.0),
        (-0.97, 1.05, 0.74, "#FFC060", 5.0, 0.3, 0.9, 0.0, 0.0),
        (0.97, 1.05, 0.74, "#FFC060", 5.0, 0.3, 0.9, 0.0, 0.0)],
    4: [(1.35, -1.35, 4.28, "#FF8C1A", 22.0, 0.5, 1.4, 0.0, 0.0),
        (0.0, 1.45, 0.5, "#FF8C1A", 7.0, 0.35, 0.9, 1.0, 2.0)],
    5: [(0.0, 1.7, 0.38, "#FF4A10", 12.0, 0.4, 1.0, 1.1, 2.2),
        (0.0, 0.9, 1.1, "#FF4A10", 6.0, 0.4, 1.0, 0.0, 0.0),
        (0.0, -0.3, 2.4, "#FF4A10", 5.0, 0.35, 0.9, 0.0, 0.0)],
    6: [(0.0, -0.45, 3.48, "#60D0FF", 26.0, 0.55, 1.5, 0.0, 0.0),
        (-1.3, -0.35, 3.0, "#60D0FF", 9.0, 0.35, 1.0, 0.0, 0.0),
        (1.3, -0.35, 3.0, "#60D0FF", 9.0, 0.35, 1.0, 0.0, 0.0),
        (0.0, 1.45, 0.62, "#60D0FF", 6.0, 0.3, 0.8, 1.0, 2.0)],
    7: [(0.05, -0.55, 2.4, "#B070FF", 30.0, 0.6, 1.6, 1.4, 2.6),
        (0.0, 1.3, 1.1, "#B070FF", 6.0, 0.3, 0.8, 0.0, 0.0)],
    8: [(-0.3, -0.85, 2.1, "#A8FF3A", 26.0, 0.6, 1.6, 1.3, 2.5),
        (-1.15, 0.65, 1.0, "#A8FF3A", 9.0, 0.4, 1.0, 0.0, 0.0),
        (1.25, -0.5, 1.25, "#A8FF3A", 7.0, 0.35, 0.9, 0.0, 0.0)],
    9: [(0.0, 1.6, 0.45, "#5CFF4A", 12.0, 0.4, 1.0, 1.2, 2.4),
        (0.0, -0.05, 1.25, "#5CFF4A", 12.0, 0.45, 1.2, 0.0, 0.0),
        (0.0, -0.05, 6.25, "#5CFF4A", 6.0, 0.25, 0.7, 0.0, 0.0)],
    10: [(0.0, 1.15, 0.9, "#3AA8FF", 14.0, 0.45, 1.2, 1.3, 2.6),
         (0.45, -0.65, 3.07, "#3AA8FF", 12.0, 0.5, 1.4, 0.0, 0.0),
         (-1.3, -0.95, 6.77, "#3AA8FF", 5.0, 0.2, 0.6, 0.0, 0.0)],
    11: [(0.0, -0.35, 3.0, "#BFE6FF", 26.0, 0.6, 1.7, 1.5, 2.8),
         (0.0, 0.25, 1.7, "#BFE6FF", 10.0, 0.4, 1.0, 0.0, 0.0)],
    12: [(0.0, -0.3, 1.55, "#4AF0FF", 20.0, 0.6, 1.7, 1.5, 2.8),
         (0.0, -0.3, 2.9, "#4AF0FF", 14.0, 0.5, 1.4, 0.0, 0.0),
         (0.0, -0.3, 4.2, "#4AF0FF", 10.0, 0.45, 1.2, 0.0, 0.0)],
    13: [(0.0, -0.35, 4.65, "#FF4FD8", 60.0, 0.9, 2.2, 1.6, 3.0),
         (0.0, 1.5, 0.5, "#FF9A3A", 8.0, 0.35, 0.9, 0.0, 0.0)],
    14: [(0.0, -0.5, 7.25, "#FF2A2A", 8.0, 0.25, 0.7, 0.0, 0.0),
         (-1.85, -0.5, 3.9, "#FF2A2A", 4.0, 0.2, 0.6, 0.0, 0.0),
         (1.85, -0.5, 3.9, "#FF2A2A", 4.0, 0.2, 0.6, 0.0, 0.0),
         (0.0, 1.55, 0.55, "#2F6BFF", 10.0, 0.4, 1.0, 1.3, 2.6)],
    15: [(0.0, -0.1, 1.0, "#FFF2C0", 45.0, 0.6, 1.6, 1.7, 3.0),
         (0.0, -0.1, 5.35, "#FFF2C0", 30.0, 0.8, 2.0, 0.0, 0.0),
         (0.0, 0.42, 3.1, "#FFF2C0", 10.0, 0.4, 1.0, 0.0, 0.0)],
}

# Pièce animée par script en phase 2 (F44 : un container n'est pas animable par prototype)
ANIMATION = {
    1: None, 2: None, 3: "panache de vapeur (facultatif, 16 images)", 4: "flamme de torchère (16 images)",
    5: "pulsation des braises (8 à 16 images)", 6: "arcs entre les piles et le tore (16 images)",
    7: "respiration du cristal (16 images)", 8: "bulles montantes (16 à 24 images)",
    9: "pulsation verte (uranium-glow équivalent)", 10: "parabole tournante + voyants (frame_sequence)",
    11: "chenillard le long des ailerons", 12: "rotation des 3 anneaux", 13: "plasma qui tourne (16 à 32 images)",
    14: "balises qui clignotent, reflet des cellules", 15: "particules partagées (32 à 60 images)",
}
