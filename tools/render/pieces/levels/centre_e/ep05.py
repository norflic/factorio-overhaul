"""Centre de commandement · Âge 5 · Volcan (5×5, niveau 5). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« citadelle de basalte, obélisque, lave » : citadelle octogonale crénelée de basalte, obélisque noir fendu
de lave, vasque de lave au pied.
"""
import math

import ages
import corps as cp

EPOQUE = 5
NOM = ages.NOMS[5]
TRIPLET = ('citadelle de basalte', 'obélisque', 'lave')
FOYER = ages.FOYER[5]
HABILLAGE = dict(ages.CORPS[5], plan="octo", etages=2, toit="crenele", mat_e1="basalte_capot", mat_e2="basalte_dalle",
                 mat_toit="fonte_v")

RAYON_MAT = 0.61   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)


def matieres(metal, M):
    ages.matieres(5, metal, M)

def mat(g, c, z):
    M = g.M
    hm = 1.15
    g.cyl((0, 0, z + hm / 2), "z", 0.2, hm, M["fonte_noire"], n=4, r2=0.05, phase=math.pi / 4, style="hard",
          what="obelisque")
    for (sx, sy) in ((0, -1), (1, 0)):
        for f in (0.2, 0.45, 0.7):
            r = 0.2 - 0.15 * f
            zz = z + hm * f
            g.box((sx * (r * 0.72 + 0.005), sy * (r * 0.72 + 0.005), zz),
                  (0.012 if sx else r * 0.9, 0.012 if sy else r * 0.9, 0.05), M["emit"], "flat", what="fente_lave")
    g.cyl((0, 0, z + hm + 0.06), "z", 0.06, 0.12, M["emit"], n=4, r2=0.0, phase=math.pi / 4, style="flat",
          what="pointe")
    cp.colonne(g, 0, -0.45, z, z + 0.1, 0.16, M["basalte_capot"], n=10, style="hard", what="vasque")
    cp.colonne(g, 0, -0.45, z + 0.1, z + 0.105, 0.13, M["emit"], n=10, style="flat", what="lave")
    cp.halo(g, (0, -0.6, z + 0.2), M, 3.0)
    cp.halo(g, (0, -0.2, z + hm), M, 2.0)
