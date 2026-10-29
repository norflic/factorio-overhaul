"""REGISTRE DES ÂGES et CONTRAT des modules epNN.py du MUR (lot F6, 29/10). Python pur (importable hors Blender).

Le mur est une famille 1×1 : UN poteau au centre de la case et des BRAS vers les voisins. Comme le mur vanilla, une case ne
dessine que les bras EST, OUEST et SUD (le bras nord est dessiné par le voisin du nord, dont le bras sud descend jusqu'au
centre de cette case et passe SOUS son poteau) : 8 formes de raccord (TYPES). Un âge donne :
  EPOQUE = N ; NOM ; TRIPLET = (« mot 1 », « mot 2 », « mot 3 ») ;
  FOYER = ages.FOYER[N]                  même lumière que la mitrailleuse du même âge ;
  def matieres(metal, M)                 ages.matieres(N, metal, M) d'abord, puis les alias de rôle ;
  def poteau(g, c)                       le poteau, centré sur l'origine, posé au sol (z = 0) ;
  def bras(g, c, L, n)                   UN bras dans son repère : il part du centre du poteau (x = 0) et va jusqu'à x = L,
                                         largeur sur y, hauteur sur z ; n cellules de pas L / n. Bras est et ouest : L = 0,5
                                         (le joint avec le voisin est à x = L, section identique des deux côtés) ; bras
                                         sud : L = 1,414 (le centre de la case voisine : 1 case de jeu vers le sud = 1,414
                                         unité en Y) ; le poteau voisin le recouvre : il doit être au moins aussi large et
                                         aussi haut que le bras (HAUT_BRAS, HAUT_POTEAU, LARG_BRAS, LARG_POTEAU).
c (piece.Ctx) porte : M (matières), rng. Les mêmes fonctions servent aux 8 formes : un âge ne décrit JAMAIS une forme de
raccord à part (c'est ce qui garantit des raccords propres).
"""
import importlib
import os
import sys

_ICI = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(_ICI), "commun")
for _d in (COMMUN, _ICI):
    if _d not in sys.path:
        sys.path.insert(0, _d)
import ages  # noqa: E402

NOMS = ages.NOMS
FAMILLES = ages.FAMILLES
ERE = ages.ERE
AGES = tuple(range(2, 16))      # l'âge 1 est le mur de pierre vanilla (niveau 1) ; sa pièce de niveau 2 : voir RAPPORT

# les 8 formes (bras dessinés par la case) ; correspondance avec les images vanilla (WallPictures)
TYPES = {
    "single": (),          # single
    "vert": ("S",),        # straight_vertical
    "horiz": ("E", "O"),   # straight_horizontal
    "corR": ("E", "S"),    # corner_right_down
    "corL": ("O", "S"),    # corner_left_down
    "tee": ("E", "O", "S"),  # t_up
    "endR": ("E",),        # ending_right
    "endL": ("O",),        # ending_left
}
ORDRE_TYPES = ("single", "vert", "horiz", "corR", "corL", "tee", "endR", "endL")
# bras : angle du repère (rz), longueur (unités Blender), cellules
BRAS = {"E": (0.0, 0.5, 2), "O": (3.141592653589793, 0.5, 2), "S": (-1.5707963267948966, 1.4142135623730951, 6)}

# lecture « en 3 mots » de l'âge (fiches : fo-logs/2026-10-29_NUIT/MUR-F6/FICHES_MUR.md)
TRIPLETS = {
    2: ("brique rouge", "créneaux", "sangles de fer"),
    3: ("chaudière", "tuyaux de laiton", "dômes"),
    4: ("fûts de pétrole", "tôle ondulée", "barbelés"),
    5: ("orgues de basalte", "blocs de lave", "fissures rougeoyantes"),
    6: ("isolateurs", "disques de porcelaine", "arcs"),
    7: ("obélisque", "cristaux", "pierre claire"),
    8: ("palissade", "rondins moussus", "lanterne toxique"),
    9: ("béton", "profil Jersey", "plomb"),
    10: ("pylônes fins", "panneaux", "voyants"),
    11: ("dents de scie", "plaques de titane", "aileron orange"),
    12: ("chrome", "givre", "conduit cryogénique"),
    13: ("sphère de confinement", "bobines", "tube de verre"),
    14: ("monolithe", "dalles flottantes", "horizon"),
    15: ("éclat d'obsidienne", "arête lame", "fissure d'or"),
}


def module(e):
    return importlib.import_module("ep%02d" % e)
