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
#  - 2e passe (aperçu à 32 échantillons, 21/10 22 h) : L50 48, 48, 56, 61, 42, 43, 84, 61, 59, 93, 87, 51,
#    110, 87, 141 ; corrigé aux époques 7, 10, 11, 13, 15 (même formule), 6 (toit d'acier au lieu d'acier
#    sombre) et 12 (gain propre du noir : 3,0 → 4,3, dans centre_ere4.py).
ALBEDO_GAIN = {1: 0.9, 2: 0.75, 3: 1.0, 4: 1.0, 5: 1.35, 6: 0.9, 7: 0.7, 8: 0.7, 9: 1.0, 10: 0.32, 11: 0.72,
               12: 1.6, 13: 0.30, 14: 0.95, 15: 0.28}

# Multiplicateur d'albédo de la correction V3 du 22/10, appliqué à TOUTES les matières de l'époque (gain ci-dessus
# et gains propres des matières) : la nouvelle politique de patine (crasse, taches, coulures, rouille) assombrit
# le rendu. Calcul : 2,0 (gain de l'essai T4) × (cible / (1,15 × L50 de la passe 1))^2,2, puis -10 % aux
# ères IV et V (crasse plus légère). Corps visés un peu sous la cible aux époques 5, 10, 13, 14 (marge de la
# lueur D2-1). À vérifier sur le rendu (mesures_d1.py, colonne L50).
# Passe 3 : époque 11 (L50 87 pour 100) et 15 (99 pour 108) : crasse plus légère (DIRT_LEVEL de centre_kit).
GAIN_MUL = {1: 1.94, 2: 1.76, 3: 2.22, 4: 1.48, 5: 1.48, 6: 1.96, 7: 3.74, 8: 1.36, 9: 1.88, 10: 1.6, 11: 5.0,
            12: 2.1, 13: 3.0, 14: 1.5, 15: 2.9}

# Lumière de NUIT seulement aux époques 1 et 2 (bible §5 : lanterne, forge) ; lueur de jour dès l'époque 3.
NIGHT_ONLY = {1, 2}

# ---------------------------------------------------------------------------------------------------------
# Lueur de jour CALIBRÉE (correction V3 du 22/10, vérification adverse : double comptage de l'émission, teintes
# faussées, D2-1 non prouvé). La couche principale est rendue émissifs ÉTEINTS (presque noirs) ; la couche
# draw_as_glow, additive, porte seule l'éclat. Sa couleur de cœur (sRGB, sur 255) est choisie ici :
#   - même TEINTE (HSV) que la couleur émissive de la bible §1.5 (écart visé : 0°) ;
#   - canal le plus fort = GLOW_V (230 au plus) : le composite reste sous 250 (aucune saturation, aucun blanc) ;
#   - luminance du cœur = médiane cible du corps + GLOW_MARGIN (D2-1 demande +80 au moins ; la marge couvre
#     les pixels de bord, plus sombres, que la médiane sur la zone de lueur inclut), obtenue en baissant la
#     saturation (HSV) depuis celle de la bible, jamais en dessous de GLOW_SMIN (la couleur doit rester lue).
# Chiffres vérifiés sur le rendu par mesures_d1.py (colonnes « lueur − L50 », « saturés % », « teinte »).
GLOW_V = 228
GLOW_MARGIN = 100
GLOW_SMIN = 0.30
LUMA = (0.2126, 0.7152, 0.0722)


def _hex(c):
    h = c.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


# Luminance de cœur imposée par époque (sinon cible du corps + GLOW_MARGIN) : époque 5, la braise #FF4A10 ne
# peut pas être à la fois claire de +100 et saturée ; corps visé plus sombre (36 à 38, fourchette 32 à 52) et
# cœur à 128 : marge D2-1 de +88 environ, saturation HSV 0,72 (au lieu de 0,61 à la passe 1).
GLOW_LUM = {5: 128}
# Canal max du cœur par époque (passe 2 : 7,7 % et 6,7 % de pixels saturés aux époques 11 et 15, où la lueur fine
# borde un corps très clair) ; sinon GLOW_V
GLOW_V_E = {11: 212, 15: 212}


def glow_core(e, hexcol, lum=None, V=None):
    """Couleur sRGB (0-255) du cœur de lueur de l'époque e pour la teinte hexcol (voir ci-dessus)."""
    V = GLOW_V_E.get(e, GLOW_V) if V is None else V
    lum = GLOW_LUM.get(e, LUM_TARGET[e] + GLOW_MARGIN) if lum is None else lum
    c = _hex(hexcol)
    mx, mn = max(c), min(c)
    f = [(x - mn) / (mx - mn) if mx > mn else 1.0 for x in c]
    s0 = (mx - mn) / mx if mx else 0.0
    k = sum(w * (1 - fi) for w, fi in zip(LUMA, f))
    s = (1 - lum / V) / k if k > 0 else 0.0
    s = max(min(GLOW_SMIN, s0), min(s0, s))
    return tuple(V * (1 - s * (1 - fi)) for fi in f)


def _lin(v):
    v = v / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def glow_emission(e, hexcol):
    """(couleur linéaire normalisée, intensité) d'un matériau émissif Cycles dont la passe lueur (transformée
    « Standard », sans lumière) donne exactement glow_core(e, hexcol) : pixel = sRGB(couleur × intensité)."""
    lin = [_lin(x) for x in glow_core(e, hexcol)]
    m = max(lin)
    return tuple(x / m for x in lin), m


def hue_deg(rgb):
    """Teinte HSV en degrés d'une couleur (r, g, b) sur 255."""
    import colorsys
    return colorsys.rgb_to_hsv(*[x / 255.0 for x in rgb])[0] * 360.0


# Couleurs émissives de la bible §1.5 par époque (contrôle de teinte du composite, mesures_d1.py)
EMISSIVE = {1: ["#FFB060"], 2: ["#FF6A20"], 3: ["#FFC060"], 4: ["#FF8C1A"], 5: ["#FF4A10"], 6: ["#60D0FF"],
            7: ["#B070FF"], 8: ["#A8FF3A"], 9: ["#5CFF4A"], 10: ["#3AA8FF"], 11: ["#BFE6FF"], 12: ["#4AF0FF"],
            13: ["#FF4FD8", "#FF9A3A"], 14: ["#FF2A2A", "#2F6BFF"], 15: ["#FFF2C0"]}


def halo_script(e):
    """Halo de nuit proportionnel au niveau (bible §1.6) : I(N) = 0,05 + 0,02·N ; S(N) = s·(1 + 0,05·N),
    N = 2e pour le centre, s = 4. À poser par script en phase 2 (rendering.draw_light, F44)."""
    n = 2 * e
    return {"intensity": round(0.05 + 0.02 * n, 3), "size": round(FOOTPRINT * (1 + 0.05 * n), 3)}


# Sources de la passe halo (draw_as_light) : (x, ty, z, couleur, puissance W, rayon plein, rayon nul)
# - fenêtre « src » autour de la source projetée ; fenêtre « sol » à l'aplomb (z = 0), si rsol > 0.
# Positions identiques à celles des pièces lumineuses de centre_ere*.py (lues par build).
HALO = {
    # époque 1 : lanterne agrandie et puissances relevées (planche de nuit du 22/10 : lanterne presque invisible)
    1: [(0.44, 0.50, 0.665, "#FFB060", 30.0, 0.45, 1.2, 1.2, 2.4),
        (-0.68, 0.45, 0.52, "#FFB060", 10.0, 0.3, 0.8, 0.8, 1.6)],
    2: [(0.0, 0.12, 1.16, "#FF6A20", 6.0, 0.4, 1.0, 0.0, 0.0),
        (-1.36, 1.05, 0.54, "#FF6A20", 4.0, 0.3, 0.8, 0.7, 1.5),
        (1.36, 1.05, 0.54, "#FF6A20", 4.0, 0.3, 0.8, 0.7, 1.5),
        (0.0, 1.09, 0.68, "#FF6A20", 5.0, 0.3, 0.8, 0.9, 1.8)],
    3: [(0.0, 1.16, 1.06, "#FFC060", 10.0, 0.45, 1.1, 1.0, 2.0),
        (-0.93, 0.46, 0.74, "#FFC060", 5.0, 0.3, 0.9, 0.0, 0.0),
        (0.93, 0.46, 0.74, "#FFC060", 5.0, 0.3, 0.9, 0.0, 0.0),
        (-1.50, 0.22, 0.42, "#FFC060", 4.0, 0.25, 0.7, 0.6, 1.2)],
    4: [(1.45, -1.55, 4.3, "#FF8C1A", 22.0, 0.5, 1.4, 0.0, 0.0),
        (0.0, 1.47, 0.5, "#FF8C1A", 7.0, 0.35, 0.9, 1.0, 2.0)],
    5: [(0.0, 1.7, 0.38, "#FF4A10", 12.0, 0.4, 1.0, 1.1, 2.2),
        (0.0, 0.9, 1.1, "#FF4A10", 6.0, 0.4, 1.0, 0.0, 0.0),
        (0.0, -0.3, 2.4, "#FF4A10", 5.0, 0.35, 0.9, 0.0, 0.0)],
    6: [(0.0, -0.2, 3.78, "#60D0FF", 26.0, 0.55, 1.5, 0.0, 0.0),
        (-1.56, 0.15, 2.9, "#60D0FF", 9.0, 0.35, 1.0, 0.0, 0.0),
        (1.56, 0.15, 2.9, "#60D0FF", 9.0, 0.35, 1.0, 0.0, 0.0),
        (0.0, 0.66, 0.81, "#60D0FF", 6.0, 0.3, 0.8, 1.0, 2.0)],
    7: [(0.05, -0.55, 2.4, "#B070FF", 30.0, 0.6, 1.6, 1.4, 2.6),
        (0.0, 1.3, 1.1, "#B070FF", 6.0, 0.3, 0.8, 0.0, 0.0)],
    8: [(-0.05, -0.55, 0.9, "#A8FF3A", 26.0, 0.7, 1.8, 1.3, 2.5),
        (1.33, -0.25, 0.5, "#A8FF3A", 8.0, 0.35, 0.9, 0.0, 0.0),
        (-1.40, 0.62, 0.42, "#A8FF3A", 7.0, 0.3, 0.8, 0.0, 0.0),
        (-0.05, -0.55, 5.38, "#A8FF3A", 4.0, 0.2, 0.6, 0.0, 0.0)],
    9: [(0.0, 1.6, 0.45, "#5CFF4A", 12.0, 0.4, 1.0, 1.2, 2.4),
        (0.0, -0.05, 1.25, "#5CFF4A", 12.0, 0.45, 1.2, 0.0, 0.0),
        (0.0, -0.05, 6.25, "#5CFF4A", 6.0, 0.25, 0.7, 0.0, 0.0)],
    10: [(0.0, 1.05, 1.0, "#3AA8FF", 14.0, 0.45, 1.2, 1.3, 2.6),
         (0.5, -0.2, 2.78, "#3AA8FF", 12.0, 0.5, 1.4, 0.0, 0.0),
         (-1.35, -0.75, 6.77, "#3AA8FF", 5.0, 0.2, 0.6, 0.0, 0.0)],
    11: [(0.0, -0.35, 3.0, "#BFE6FF", 26.0, 0.6, 1.7, 1.5, 2.8),
         (0.0, 0.25, 1.7, "#BFE6FF", 10.0, 0.4, 1.0, 0.0, 0.0)],
    12: [(0.0, -0.3, 1.55, "#4AF0FF", 40.0, 0.9, 2.2, 1.6, 3.0),
         (0.0, -0.3, 2.9, "#4AF0FF", 28.0, 0.8, 2.0, 0.0, 0.0),
         (0.0, -0.3, 4.2, "#4AF0FF", 20.0, 0.7, 1.8, 0.0, 0.0)],
    13: [(0.0, -0.35, 4.62, "#FF4FD8", 60.0, 0.9, 2.2, 1.6, 3.0),
         (0.0, 1.45, 0.5, "#FF9A3A", 8.0, 0.35, 0.9, 0.0, 0.0)],
    14: [(0.0, -0.5, 7.25, "#FF2A2A", 8.0, 0.25, 0.7, 0.0, 0.0),
         (-1.83, -0.5, 3.95, "#FF2A2A", 4.0, 0.2, 0.6, 0.0, 0.0),
         (1.83, -0.5, 3.95, "#FF2A2A", 4.0, 0.2, 0.6, 0.0, 0.0),
         (0.0, 1.5, 0.6, "#2F6BFF", 10.0, 0.4, 1.0, 1.3, 2.6),
         (-1.17, -0.62, 4.4, "#2F6BFF", 6.0, 0.3, 0.8, 0.0, 0.0),
         (1.17, -0.62, 4.4, "#2F6BFF", 6.0, 0.3, 0.8, 0.0, 0.0)],
    15: [(0.0, -0.15, 0.3, "#FFF2C0", 45.0, 0.6, 1.6, 1.7, 3.0),
         (0.0, 0.05, 4.95, "#FFF2C0", 8.0, 0.35, 0.9, 0.0, 0.0),
         (0.0, -0.35, 5.05, "#FFF2C0", 30.0, 0.8, 2.0, 0.0, 0.0),
         (0.0, 0.50, 3.75, "#FFF2C0", 10.0, 0.4, 1.0, 0.0, 0.0),
         (0.0, -0.15, 2.45, "#FFF2C0", 10.0, 0.4, 1.0, 0.0, 0.0)],
}

# Énergie de la couche light du sprite (t², somme de la luminance prémultipliée / 64²) : NORMALISÉE au
# post-traitement sur cette courbe croissante (D2-3 : halo de nuit proportionnel au niveau ; la vérification
# adverse du 22/10 a mesuré des énergies non croissantes : 0,94 à l'époque 1, 0,48 à l'époque 14). Le halo par
# script (halo_script) s'y ajoute en jeu.
def light_target(e):
    return round(0.55 + 0.12 * (e - 1), 3)


# Pièce animée par script en phase 2 (F44 : un container n'est pas animable par prototype)
ANIMATION = {
    1: None, 2: None, 3: "panache de vapeur (facultatif, 16 images)", 4: "flamme de torchère (16 images)",
    5: "pulsation des braises (8 à 16 images)", 6: "arcs entre les piles et le tore (16 images)",
    7: "respiration du cristal (16 images)", 8: "bulles montantes (16 à 24 images)",
    9: "pulsation verte (uranium-glow équivalent)", 10: "parabole tournante + voyants (frame_sequence)",
    11: "chenillard le long des ailerons", 12: "rotation des 3 anneaux", 13: "plasma qui tourne (16 à 32 images)",
    14: "balises qui clignotent, reflet des cellules", 15: "particules partagées (32 à 60 images)",
}
