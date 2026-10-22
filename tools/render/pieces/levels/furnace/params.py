"""Paramètres des 30 niveaux du four en acier (lot V3, famille « furnace », phase 1). Python PUR.

Importé à la fois par Blender (modèle, furnace_levels.py) et par le Python système (pilote de rendu,
mesures D1, planches, manifeste). Source des règles : docs/DESIGN_EPOQUES.md (bible, qui fait règle),
§1.4 (enveloppes), §1.5 (palette), §1.6 (lumière), §2.7 (fiche du four), §4 (rangs), §5 (fiches).

Repère : tuiles de jeu, origine = position de l'entité, x vers l'est, y vers le SUD ; z = hauteur en
unités Blender (1 unité de hauteur = 45,25 px HR = 0,7071 tuile à l'écran). Un point (x, y, z) se voit à
l'écran en (x, y - 0,7071·z) tuiles (projection orthographique à 45°, CALIBRATION.md §2).

Choix de la famille (écrits ici pour être relus par V4 et le Directeur Créatif) :
- O (dépassement au-dessus du bord haut de l'emprise) est rendu NON DÉCROISSANT sur les 30 niveaux,
  pas seulement sur les 15 niveaux impairs : une amélioration ne rapetisse jamais le bâtiment.
- ÉCART À LA BIBLE (§4), justifié par F42/F45 : le haut du four vanilla est PLAT sur toute sa largeur
  (-1,09 à -1,28 tuile, mesuré colonne par colonne). Une pièce du niveau 2 qui ne dépasse pas O 0,28 est
  invisible (premier modeleur : hotte presque entièrement masquée). La pièce du niveau 2 monte donc à
  O ≈ 0,55, et les époques 2 à 6 sont relevées (0,60 ; 0,64 ; 0,68 ; 0,72 ; 0,76 au lieu de 0,37 ; 0,47 ;
  0,56 ; 0,66 ; 0,75) pour rester monotones. À partir de l'époque 7, valeurs de la bible ; époque 15 :
  1,53 (niveau 29) puis 1,60 (niveau 30, plafond Q9).
- Les hauteurs « +0,45 », « +0,30 »… des pièces paires (bible §5) sont lues comme la hauteur de la pièce
  au-dessus de son point d'attache, plafonnée par O(époque + 1).
"""
import math

K = math.sqrt(2.0)          # une tuile de jeu vers le sud = K unités Blender en -Y
S45 = math.sqrt(0.5)        # sin 45° = cos 45°
FOOTPRINT = 2               # emprise 2×2 (collision ±0,7, sélection x ±0,8 / y ±1 : inchangées, D1-4)

# --- enveloppes de la bible §4 (four) : O / L / V par rang d'époque ---------------------------------
O_BIBLE = [0.28, 0.37, 0.47, 0.56, 0.66, 0.75, 0.85, 0.94, 1.03, 1.13, 1.22, 1.32, 1.41, 1.51, 1.60]
# cibles retenues pour la famille (niveaux impairs ; voir l'écart justifié ci-dessus)
O_FAMILY = [0.28, 0.60, 0.64, 0.68, 0.72, 0.76, 0.85, 0.94, 1.03, 1.13, 1.22, 1.32, 1.41, 1.51, 1.53]
L_BIBLE = [1.97, 1.99, 2.00, 2.02, 2.04, 2.05, 2.07, 2.08, 2.10, 2.12, 2.13, 2.15, 2.17, 2.18, 2.20]
V_BIBLE = [0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 10, 15, 20, 25, 30]          # % du masque du niveau 1 laissé vide
O_CEIL, L_CEIL = 1.60, 2.20

# --- palette de la bible §1.5 (sRGB) et luminance médiane cible du corps -------------------------
PALETTE = {
    1: {"fer": "#5A5048", "bois": "#6B4F35", "toile": "#8A7A5A", "emit": "#FFB060", "L50": 50},
    2: {"acier": "#5C6168", "cerclage": "#2E2C2A", "laiton": "#8C7440", "brique": "#6A3B2C", "emit": "#FF6A20", "L50": 52},
    3: {"cuivre": "#8A5A3A", "laiton": "#9C7E45", "fonte": "#3A3634", "emit": "#FFC060", "L50": 58},
    4: {"jaune": "#8C7A3A", "galva": "#6E7378", "noir": "#2A2826", "emit": "#FF8C1A", "L50": 60},
    5: {"tungstene": "#3E3D42", "rouille": "#5A3A2A", "emit": "#FF4A10", "L50": 42},
    6: {"ceramique": "#D8D4C8", "cuivre": "#B0703A", "acier": "#5C6168", "emit": "#60D0FF", "L50": 64},
    7: {"bronze": "#6A5236", "pierre": "#4A4038", "cristal": "#9A5CFF", "emit": "#B070FF", "L50": 55},
    8: {"verre": "#8FBF4A", "vdg": "#4F6B5A", "caoutchouc": "#2A2A28", "emit": "#A8FF3A", "L50": 60},
    9: {"plomb": "#4A5058", "jaune": "#C9A227", "beton": "#7A7670", "emit": "#5CFF4A", "L50": 56},
    10: {"carenage": "#A8ADB3", "noir": "#222428", "emit": "#3AA8FF", "L50": 82},
    11: {"alliage": "#C9C6BE", "titane": "#8E9AA6", "emit": "#BFE6FF", "L50": 100},
    12: {"noir": "#26282E", "chrome": "#9AA3AD", "givre": "#DDEEFF", "emit": "#4AF0FF", "L50": 60},
    13: {"ceramique": "#D9D6CF", "cuivre": "#B0703A", "emit": "#FF4FD8", "coeur": "#FF9A3A", "L50": 92},
    14: {"or": "#C9A23A", "blanc": "#CFCBC2", "cellules": "#1E2A55", "emit": "#FF2A2A", "cellemit": "#2F6BFF", "L50": 88},
    15: {"orblanc": "#E8DCB0", "nacre": "#D8D2C8", "cristal": "#E8F0F4", "emit": "#FFF2C0", "L50": 108},
}
# Correction d'albédo par époque (multiplie la couleur de TOUTES les surfaces non émissives) : la luminance
# médiane du corps rendu doit suivre la cible de la bible §1.5 (±10). Valeurs fixées sur les mesures des
# rendus (measure_d1.py, photométrie du corps hors zones émissives) : voir mesures_d1.txt.
# Reprise 2 : les valeurs laissées par l'interruption (0,36 à 1,22) n'avaient été appliquées à aucun rendu
# conservé ; remises à 1,0, tout est rendu, puis K est recalculé sur la mesure du corps hors zones émissives
# (measure_d1.py) : K = lin(cible) / lin(mesure) × K précédent (rendu linéaire en albédo, au premier ordre).
# Le recalcul a retrouvé l'ordre de grandeur des valeurs du premier modeleur (époque 8 : 0,38 ; époque 6 :
# 0,40) : ses facteurs étaient justes ; seul manquait le rendu qui les vérifie.
# Mesure du 22/10 (rendus à K = 1, 32 échantillons) -> facteurs appliqués aux époques hors tolérance (±10) ;
# époque 1 (pièce du niveau 2) : cible 58 (haut de la tolérance, pour se détacher du four vanilla sombre),
# gain déjà abaissé de 2,7 à 1,9 dans furnace_levels.e1_piece, d'où 0,60 et non 0,43.
ALBEDO_K = {e: 1.0 for e in range(1, 16)}
ALBEDO_K.update({1: 0.60, 4: 0.595, 5: 0.456, 6: 0.407, 8: 0.405, 9: 0.666, 13: 0.459, 14: 0.76})
# Feu de la bouche (identité du four : « bouche lumineuse au sud ») ; vanilla : (99,49,3) à (241,144,2)
FIRE = "#FF8A1E"

# --- descriptions (bible §5, colonne « Four ») -----------------------------------------------------
EPOCHS = {
    1: {"nom": "Pionnier", "ere": "I", "corps": "vanilla (four en acier inchangé, Q11)",
        "piece": "Hotte et conduit de fumée en tôle rivetée à l'arrière, posés DERRIÈRE le corps vanilla "
                 "(masque au pixel par l'alpha du sprite vanilla, comme la variante « four » de V0) ; "
                 "la fumée part du haut du conduit"},
    2: {"nom": "Forge", "ere": "I", "corps": "Four en briques réfractaires cerclé d'acier, créneaux d'acier, "
        "première cheminée carrée haute à l'arrière droit, porte à volets",
        "piece": "Soufflet de forge sur le flanc gauche (dépasse à gauche), levier en bois"},
    3: {"nom": "Vapeur", "ere": "I", "corps": "Haut-fourneau rond en fonte cerclé de laiton, cheminée ronde à "
        "collerette plus haute, tuyère de cuivre, hublot ambré, manomètre",
        "piece": "Chaudière de récupération (cylindre horizontal riveté, dôme de vapeur) sur le flanc gauche"},
    4: {"nom": "Pétrole", "ere": "II", "corps": "Brûleur au fioul : foyer en cylindre horizontal (axe nord-sud, "
        "bouche ronde au sud), réservoir de fioul latéral, cheminée galvanisée à bandes noires, passerelle et "
        "garde-corps", "piece": "Torchère greffée sur la cheminée (tube, couronne de brûleur, flamme)"},
    5: {"nom": "Volcan", "ere": "II", "corps": "Four-forge en tronc de pyramide noir, blindage en écailles, "
        "rivets lourds, bouche de lave, fissures rougeoyantes, cheminée blindée inclinée",
        "piece": "Rigole de coulée de lave qui déborde à l'avant (dépasse au sud)"},
    6: {"nom": "Électricité", "ere": "II", "corps": "Four à arc : cuve ronde, couvercle bombé, 3 électrodes "
        "verticales sur bras isolés, piles d'isolateurs, arcs cyan ; trou de coulée lumineux ; extraction des "
        "fumées à l'arrière droit", "piece": "Transformateur à ailettes et traversées en céramique sur le flanc gauche"},
    7: {"nom": "Cristal", "ere": "III", "corps": "Creuset de bronze tenu par 4 griffes de cristal pointées vers le "
        "haut, sur socle de pierre taillée ; cheminée de bronze sertie de cristal",
        "piece": "Prisme focalisateur au-dessus du creuset, tenu par deux bras de bronze"},
    8: {"nom": "Marais", "ere": "III", "corps": "Creuset-alambic sphérique de verre sur base vert-de-gris, liquide "
        "luminescent, col de cygne qui monte puis redescend en cheminée à l'arrière droit",
        "piece": "Second alambic (petite sphère sur trépied) sur le flanc gauche, relié par un tube"},
    9: {"nom": "Atome", "ere": "III", "corps": "Base octogonale plombée chanfreinée, dôme chanfreiné, cœur vert "
        "par hublots, bande d'avertissement, petite tour de refroidissement hyperboloïde à l'arrière droit",
        "piece": "Conduit annelé sur le flanc droit, de la base à la tour"},
    10: {"nom": "Haute technologie", "ere": "IV", "corps": "Four à induction : capsule lisse verticale, anneaux "
         "bleus, sur anneau de base et 4 pieds courts (vide dessous), mât d'évacuation caréné à l'arrière droit",
         "piece": "Écran latéral sur bras et antenne fouet, flanc gauche"},
    11: {"nom": "Titane", "ere": "IV", "corps": "Four vertical élancé en alliage blanc à 4 ailerons de "
         "refroidissement, sur 4 pieds (vides), lignes bleu-blanc ; évent effilé à l'arrière droit",
         "piece": "Aileron dorsal (grand aileron triangulaire au sommet)"},
    12: {"nom": "Supraconducteurs", "ere": "IV", "corps": "Creuset noir en lévitation entre 2 anneaux magnétiques "
         "chromés (vide dessous), socle hexagonal noir, colonne d'évacuation en blocs flottants à l'arrière droit",
         "piece": "Pylône cryogénique givré à gauche, bobine cyan au sommet"},
    13: {"nom": "Fusion", "ere": "V", "corps": "Sphère de céramique sur trépied de cuivre, tore de plasma horizontal "
         "(grand vide sous la sphère), injecteurs, flèche d'évacuation à l'arrière droit",
         "piece": "Second tore de plasma incliné autour de la sphère"},
    14: {"nom": "Orbite", "ere": "V", "corps": "Four solaire : colonne blanche, creuset éclatant au foyer d'une "
         "corolle de pétales-miroirs dorés (la plus large), mât-balise à l'arrière droit",
         "piece": "Pétale supplémentaire à l'arrière, plus redressé"},
    15: {"nom": "Légende", "ere": "V", "corps": "Creuset en couronne de flèches d'or blanc, flottant au-dessus d'un "
         "disque flottant (vide maximal), anneau-halo ; la flèche arrière droite est la cheminée",
         "piece": "Seconde couronne flottante au-dessus de la première"},
}


def epoch_of(n):
    return (n + 1) // 2


def is_even(n):
    return n % 2 == 0


def o_target(n):
    """Cible de O (masses) du niveau n : O_FAMILY pour les impairs ; pour les pairs, 60 % du chemin vers
    l'époque suivante ; niveau 2 : 0,55 (pièce posée sur le vanilla) ; niveau 30 : plafond 1,60."""
    e = epoch_of(n)
    if n == 2:
        return 0.55
    if n == 30:
        return O_CEIL
    base = O_FAMILY[e - 1]
    if not is_even(n):
        return base
    nxt = o_target(n + 1)
    return base + 0.6 * (nxt - base)


def l_target(n):
    e = epoch_of(n)
    return L_BIBLE[e - 1] if not is_even(n) else (L_BIBLE[e] if e < 15 else L_CEIL)


def screen(x, y, z):
    """Point de jeu (tuiles, y sud) à la hauteur z (unités Blender) -> écran (tuiles)."""
    return (x, y - S45 * z)


def z_for_top(o, y_back):
    """Hauteur z (unités) d'un bord situé en y_back (tuiles) pour qu'il affleure O = o."""
    return (o + 1.0 + y_back) / S45


def halo_intensity(n):
    """Bible §1.6 (D2-3) : I(N) = 0,05 + 0,02·N ; rayon S(N) = s × (1 + 0,05·N) tuiles, s = 2 (emprise).
    Valeurs de la LightDefinition proposée au manifeste (phase 2) ; la couche halo rendue suit halo_layer()."""
    return 0.05 + 0.02 * n, FOOTPRINT * (1 + 0.05 * n)


def halo_layer(n):
    """Couche halo rendue (draw_as_light), croissante avec le niveau et jamais plus faible que le vanilla :
    maximum 0,80 (= flaque au sol du four vanilla, 0,79 mesuré) au niveau 3 jusqu'à 0,95 au niveau 30 ;
    flaque au sol centrée 1,15 tuile au sud (vanilla : 1,5 tuile, 152 × 126 px HR), rayon plein r0 et nul r1
    (tuiles) : niveau 3 = 0,62 / 1,42 (≈ taille vanilla), niveau 30 = 1,16 / 2,50."""
    return {"max": 0.80 + 0.15 * (n - 3) / 27.0, "center": (0.0, 1.15),
            "r0": 0.56 + 0.02 * n, "r1": 1.30 + 0.04 * n}


# --- points d'ancrage de jeu (bible §1.8) : sortie de fumée, en tuiles de jeu à l'écran -------------
# (x, y_sol, z) du haut de la cheminée de chaque époque ; complété par furnace_levels.py (mêmes valeurs)
SMOKE = {
    1: [(0.70, -1.20, None)],                 # vanilla (entities.lua:7268), le niveau 2 ajoute son conduit
}

# Fenêtres du halo (couche draw_as_light) : [(x, y_sol, z, r_plein, r_nul)] en tuiles ; la flaque au sol
# est devant la bouche ; les autres fenêtres entourent les zones émissives (halo sur le corps).
def halo_windows(n, extra):
    h = halo_layer(n)
    w = [(h["center"][0], h["center"][1], 0.0, h["r0"], h["r1"])]
    w += extra
    return w


def hex_lin(h, gain=1.0):
    """Couleur sRGB « #RRGGBB » -> linéaire (Blender), multipliée par gain (borné à 1)."""
    h = h.lstrip("#")
    out = []
    for k in range(3):
        c = int(h[2 * k:2 * k + 2], 16) / 255.0
        c = c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
        out.append(min(1.0, c * gain))
    return tuple(out)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[2 * k:2 * k + 2], 16) for k in range(3))


LEVELS = list(range(1, 31))
RENDERED = list(range(2, 31))            # le niveau 1 est le sprite vanilla (Q11)
