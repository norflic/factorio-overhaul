"""Centre de commandement · Âge 13 · Antimatière (8×8, niveau 13). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« cuve de confinement, bouteilles couchées, éclairs violets » : bastion en croix d'acier canon, cuve de
confinement verticale ceinte de six bouteilles couchées à fente violette, éclairs entre les bouteilles.
"""
import math

import ages
import corps as cp

EPOQUE = 13
NOM = ages.NOMS[13]
TRIPLET = ('cuve de confinement', 'bouteilles couchées', 'éclairs violets')
FOYER = ages.FOYER[13]
HABILLAGE = dict(ages.CORPS[13], plan="croix", etages=2, toit="plat", mat_e1="acier_canon", mat_e2="acier_canon2")


def matieres(metal, M):
    ages.matieres(13, metal, M)

def mat(g, c, z):
    M = g.M
    hc = 1.1
    cp.colonne(g, 0, 0, z, z + 0.12, 0.42, M["acier_noir"], n=24, style="hard", what="socle_cuve")
    cp.colonne(g, 0, 0, z + 0.12, z + hc, 0.3, M["acier_noir"], n=24, what="cuve")
    g.sphere((0, 0, z + hc), 0.3, M["acier_noir"], n=24, m=12, scale=(1, 1, 0.6), what="dome_cuve")
    for f in (0.3, 0.55, 0.8):
        cp.bague(g, 0, 0, z + hc * f, 0.3, 0.04, M["cuivre_bobine"], ep=0.025, n=24, what="spire")
    for k in range(6):
        a = math.tau * (k + 0.5) / 6
        u = (math.cos(a), math.sin(a), 0.0)
        p = (u[0] * 0.62, u[1] * 0.62, z + 0.25)
        g.cyl(p, u, 0.11, 0.42, M["acier_canon2"], n=16, what="bouteille")
        g.sphere((p[0] + u[0] * 0.21, p[1] + u[1] * 0.21, p[2]), 0.11, M["acier_canon2"], n=12, m=6, what="fond_bouteille")
        g.cyl((p[0], p[1], p[2] + 0.1), u, 0.02, 0.32, M["emit"], n=8, what="fente")
        cp.bague(g, p[0], p[1], p[2] - 0.11, 0.08, 0.02, M["chrome_fin"], ep=0.01, n=12, what="berceau")
    for k in range(6):
        a0, a1 = math.tau * (k + 0.5) / 6, math.tau * (k + 1.5) / 6
        m = (math.cos((a0 + a1) / 2) * 0.48, math.sin((a0 + a1) / 2) * 0.48, z + 0.5)
        g.tube([(math.cos(a0) * 0.58, math.sin(a0) * 0.58, z + 0.36), m,
                (math.cos(a1) * 0.58, math.sin(a1) * 0.58, z + 0.36)], 0.01, M["emit"], n=5, what="eclair")
    cp.halo(g, (0, -0.6, z + 0.5), M, 4.0)
