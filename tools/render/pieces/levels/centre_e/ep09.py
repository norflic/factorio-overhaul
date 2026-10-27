"""Centre de commandement · Âge 9 · Atome (6×6, niveau 9). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« bunker, dôme de confinement, radôme » : bunker octogonal de béton à dôme de confinement, radôme blanc et
cheminée de ventilation cerclée de vert.
"""
import math

import ages
import corps as cp

EPOQUE = 9
NOM = ages.NOMS[9]
TRIPLET = ('bunker', 'dôme de confinement', 'radôme')
FOYER = ages.FOYER[9]
HABILLAGE = dict(ages.CORPS[9], plan="octo", etages=2, toit="coupole", mat_e1="beton_capot", mat_e2="concrete",
                 mat_toit="beton_capot")

RAYON_MAT = 0.66   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)
ECHELLE_MAT = 1.5   # coupole : le pied du mât entre dans la coupole (vérifié aux cotes), échelle imposée

ARCHI = True   # ronde F5-A2 : contreforts, baies, balcon, verrière (corps.architecture)


def matieres(metal, M):
    ages.matieres(9, metal, M)

def mat(g, c, z):
    M = g.M
    cp.colonne(g, 0, 0, z - 0.1, z + 0.35, 0.12, M["lead"], n=12, what="fut_radome")
    g.sphere((0, 0, z + 0.55), 0.26, M["cream"], n=24, m=12, what="radome")
    cp.bague(g, 0, 0, z + 0.4, 0.2, 0.03, M["plomb_sombre"], ep=0.03, n=24, what="joint_radome")
    x, y = 0.55, 0.15
    cp.colonne(g, x, y, z - 0.35, z + 0.75, 0.09, M["concrete"], n=16, what="cheminee")
    for f in (0.25, 0.5, 0.75):
        cp.bague(g, x, y, z - 0.35 + 1.1 * f, 0.09, 0.03, M["emit"], ep=0.012, n=16, what="anneau_vert")
    cp.halo(g, (0, -0.35, z + 0.3), M, 3.0)
