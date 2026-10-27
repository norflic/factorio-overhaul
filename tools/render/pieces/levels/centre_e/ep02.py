"""Centre de commandement · Âge 2 · Forge (4×4, niveau 2). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« donjon de briques, beffroi, brasero » : donjon carré à quatre tours d'angle crénelé, beffroi de briques à
cloche de fer, brasero rouge devant.
"""
import math

import ages
import corps as cp

EPOQUE = 2
NOM = ages.NOMS[2]
TRIPLET = ('donjon de briques', 'beffroi', 'brasero')
FOYER = ages.FOYER[2]
HABILLAGE = dict(ages.CORPS[2], plan="tours", etages=2, toit="crenele", mat_e1="brique", mat_e2="brique",
                 mat_toit="fer_martele")


def matieres(metal, M):
    ages.matieres(2, metal, M)

def mat(g, c, z):
    """Beffroi : fût de briques, abat-son de fer, cloche, flèche ; brasero sur le toit, face au sud."""
    M = g.M
    b = 0.2
    cp.dalle(g, -b, -b, b, b, z, z + 0.55, M["brique"], what="beffroi")
    for k in range(4):
        x, y = cp.quart((0.0, -b - 0.004), k)[:2]
        sx, sy = (0.16, 0.01) if k % 2 == 0 else (0.01, 0.16)
        g.box((x, y, z + 0.42), (sx, sy, 0.16), M["fer_noir"], "hard", what="abat_son")
    cp.dalle(g, -b - 0.03, -b - 0.03, b + 0.03, b + 0.03, z + 0.55, z + 0.6, M["fer_martele"], what="corniche")
    g.cyl((0, 0, z + 0.75), "z", 0.3, 0.3, M["fer_martele"], n=4, r2=0.0, phase=math.pi / 4, style="hard",
          what="fleche")
    g.sphere((0, -b - 0.06, z + 0.36), 0.07, M["fer_noir"], n=12, m=8, scale=(1, 1, 1.2), what="cloche")
    cp.colonne(g, 0, -0.42, z, z + 0.08, 0.1, M["fer_noir"], n=10, what="brasero")
    g.sphere((0, -0.42, z + 0.1), 0.085, M["emit"], n=10, m=6, scale=(1, 1, 0.5), what="braises")
    cp.halo(g, (0, -0.6, z + 0.2), M, 3.0)
