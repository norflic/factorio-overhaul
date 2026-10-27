"""Centre de commandement · TÉMOIN DU KIT (la lignée seule). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

Lignée nue : socle, deux étages, toit plat, porte, satellites, mât d'acier à petite antenne.
"""
import math

import ages
import corps as cp

EPOQUE = 0
NOM = "témoin"
TRIPLET = None
FOYER = dict(rgb=(1.0, 0.6, 0.2))
HABILLAGE = dict()

RAYON_MAT = 0.20   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)

SATELLITES_3D = True   # témoin : les petites tourelles de la lignée (pas de mitrailleuse d'âge)


def matieres(metal, M):
    pass

def mat(g, c, z):
    M = g.M
    hm = 0.5 + 0.12 * c.side
    cp.colonne(g, 0, 0, z, z + 0.08, 0.16, c.m("steel_dk"), n=16, style="hard", what="embase_mat")
    cp.colonne(g, 0, 0, z + 0.08, z + hm, 0.06, c.m("steel"), n=12, what="mat", r2=0.035)
    g.dome((0, 0, z + hm), (0, 0, 1), 0.05, M["emit"], what="feu_mat")
    cp.halo(g, (0, -0.1, z + hm + 0.05), M, 1.5)
