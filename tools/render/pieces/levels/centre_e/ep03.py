"""Centre de commandement · Âge 3 · Vapeur (4×4, niveau 3). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« rotonde de cuivre, horloge, sifflet » : rotonde verte à coupole de cuivre, lanterneau à quatre cadrans,
sifflets de laiton et cheminée.
"""
import math

import ages
import corps as cp

EPOQUE = 3
NOM = ages.NOMS[3]
TRIPLET = ('rotonde de cuivre', 'horloge', 'sifflet')
FOYER = ages.FOYER[3]
HABILLAGE = dict(ages.CORPS[3], plan="rond", etages=2, toit="coupole", mat_e1="vert_loco", mat_e2="cuivre_capot",
                 mat_toit="cuivre_capot")


def matieres(metal, M):
    ages.matieres(3, metal, M)

def mat(g, c, z):
    """Lanterneau à quatre cadrans sur la coupole, sifflets de laiton, cheminée."""
    M = g.M
    cp.colonne(g, 0, 0, z - 0.05, z + 0.38, 0.17, M["vert_loco"], n=16, what="lanterneau")
    for k in range(4):
        a = math.tau * k / 4 - math.pi / 2
        x, y = 0.172 * math.cos(a), 0.172 * math.sin(a)
        g.cyl((x, y, z + 0.24), (math.cos(a), math.sin(a), 0), 0.1, 0.012, M["cream"], n=16, what="cadran")
        g.cyl((x * 1.04, y * 1.04, z + 0.24), (math.cos(a), math.sin(a), 0), 0.105, 0.006, M["laiton_capot"], n=16,
              what="lunette")
        cp.poutre(g, (x * 1.08, y * 1.08, z + 0.24), (x * 1.08, y * 1.08, z + 0.31), 0.012, M["blackiron"], "aiguille")
    g.cyl((0, 0, z + 0.5), "z", 0.21, 0.24, M["cuivre_capot"], n=16, r2=0.0, what="toit_lanterneau")
    for (x, h) in ((-0.3, 0.32), (-0.38, 0.24)):
        cp.colonne(g, x, 0.12, z - 0.1, z + h, 0.035, M["laiton_capot"], n=10, what="sifflet")
        cp.colonne(g, x, 0.12, z + h, z + h + 0.04, 0.05, M["laiton_capot"], n=10, what="pavillon")
    cp.colonne(g, 0.32, 0.18, z - 0.15, z + 0.55, 0.06, M["blackiron"], n=12, what="cheminee")
    cp.colonne(g, 0.32, 0.18, z + 0.55, z + 0.6, 0.08, M["laiton_capot"], n=12, what="couronne_cheminee")
    g.dome((0, 0, z + 0.62), (0, 0, 1), 0.04, M["emit"], what="fanal")
    cp.halo(g, (0, -0.3, z + 0.3), M, 2.5)
