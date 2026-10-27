"""Foreuse · TÉMOIN DU KIT (âge 0) : la lignée seule (tablier, montants, puits, goulotte, moteur, raccords, trépan) et la
tour de la lignée (derrick à 4 jambes). S'exécute DANS Blender."""
import corps
from habillage import habille

EPOQUE = 0
NOM = "Lignée seule"
FOYER = dict(rgb=(1.0, 0.45, 0.06))
HABILLAGE = {}


def matieres(metal, M):
    return None


def tour(g, c):
    with habille(g, c):
        corps.tour_lignee(g, c)


def piece(g, c):
    """Lanterne d'acier sur le sommet (témoin)."""
    M = g.M
    corps.colonne(g, 0, 0, c.H + 0.16, c.H + 0.40, 0.10, M["steel_dk"], n=12)
    corps.colonne(g, 0, 0, c.H + 0.40, c.H + 0.50, 0.07, M["emit"], n=12, style="flat")
    corps.halo(g, (0, 0, c.H + 0.45), M, 3.0)
