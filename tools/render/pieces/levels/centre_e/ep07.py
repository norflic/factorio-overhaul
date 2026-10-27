"""Centre de commandement · Âge 7 · Cristal (6×6, niveau 7). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« ziggourat, cristal géant, griffes de bronze » : ziggourat ronde de pierre claire en trois étages et
gradins, grand cristal tenu par trois griffes de bronze.
"""
import math

import ages
import corps as cp

EPOQUE = 7
NOM = ages.NOMS[7]
TRIPLET = ('ziggourat', 'cristal géant', 'griffes de bronze')
FOYER = ages.FOYER[7]
HABILLAGE = dict(ages.CORPS[7], plan="rond", etages=3, toit="gradins", mat_e1="pierre_claire", mat_e2="pierre_claire2",
                 mat_e3="bronze_capot", mat_toit="bronze_sombre")

RAYON_MAT = 0.29   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)


def matieres(metal, M):
    ages.matieres(7, metal, M)

def mat(g, c, z):
    M = g.M
    hc = 1.0
    cp.colonne(g, 0, 0, z, z + 0.1, 0.24, M["bronze_sombre"], n=6, style="hard", what="serti")
    g.cyl((0, 0, z + 0.1 + hc * 0.35), "z", 0.17, hc * 0.7, M["emit"], n=6, style="hard", what="cristal")
    g.cyl((0, 0, z + 0.1 + hc * 0.7 + 0.15), "z", 0.17, 0.3, M["emit"], n=6, r2=0.0, style="hard",
          what="pointe_cristal")
    for k in range(3):
        a = math.tau * k / 3 - math.pi / 2
        u = (math.cos(a), math.sin(a))
        pts = [(u[0] * 0.24, u[1] * 0.24, z + 0.08), (u[0] * 0.34, u[1] * 0.34, z + 0.35),
               (u[0] * 0.22, u[1] * 0.22, z + 0.65), (u[0] * 0.15, u[1] * 0.15, z + 0.75)]
        g.tube(pts, 0.04, M["bronze_capot"], n=8, radii=[0.05, 0.045, 0.035, 0.02], what="griffe")
    cp.halo(g, (0, -0.25, z + 0.6), M, 4.0)
