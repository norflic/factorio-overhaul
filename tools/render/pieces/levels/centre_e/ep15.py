"""Centre de commandement · Âge 15 · Néant (8×8, niveau 15). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« sphère noire, disque segmenté, entretoises d'or » : tour octogonale noire à trois étages et couronne d'or
chauffé, sphère noire au sommet, disque de douze segments jointifs sur entretoises d'or, liseré incandescent.
"""
import math

import ages
import corps as cp

EPOQUE = 15
NOM = ages.NOMS[15]
TRIPLET = ('sphère noire', 'disque segmenté', "entretoises d'or")
FOYER = ages.FOYER[15]
HABILLAGE = dict(ages.CORPS[15], plan="octo", etages=3, toit="plat", mat_e1="noir_chaud", mat_e2="noir_chaud2",
                 mat_e3="or_chauffe")

RAYON_MAT = 0.15   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)
ECHELLE_MAT = 2.0   # échelle imposée : les pièces en porte-à-faux restent au-dessus du dernier étage

ARCHI = True   # ronde F5-A2 : contreforts, baies, balcon, verrière (corps.architecture)

# ronde 2c (charte sous 25 en 2b) : châssis de verrière et cadres des lanterneaux CLAIRS, rang de hublots aux façades sud
CHASSIS = "steel_hi"
CADRE_TOIT = "steel_hi"
HUBLOTS = True
PAS_TOIT = 0.22   # ronde 2c : rangées des terrasses plus serrées (0,28 par défaut)
MOTIF_SECTEUR = True   # ronde 2c : plaquettes claires le long des secteurs visibles du socle


def matieres(metal, M):
    ages.matieres(15, metal, M)

def mat(g, c, z):
    M = g.M
    zs = z + 0.75
    cp.colonne(g, 0, 0, z, zs - 0.3, 0.12, M["or_chauffe"], n=12, what="fut_sphere")
    R0, R1 = 0.42, 0.85
    for k in range(12):
        a0, a1 = math.tau * k / 12, math.tau * (k + 1) / 12
        quad = [(R0 * math.cos(a0), R0 * math.sin(a0)), (R1 * math.cos(a0), R1 * math.sin(a0)),
                (R1 * math.cos(a1), R1 * math.sin(a1)), (R0 * math.cos(a1), R0 * math.sin(a1))]
        cp.prisme(g, quad, zs - 0.04, zs + 0.02, M["or_vif"] if k % 2 else M["or_chauffe"], what="segment")
        am = (a0 + a1) / 2
        cp.poutre(g, (0.1 * math.cos(am), 0.1 * math.sin(am), zs - 0.35),
                  (R1 * 0.9 * math.cos(am), R1 * 0.9 * math.sin(am), zs - 0.04), 0.03, M["or_chauffe"], "entretoise")
    cp.colonne(g, 0, 0, zs - 0.04, zs + 0.02, R0, M["noir_profond"], n=36, what="voile")
    g.torus((0, 0, zs + 0.025), "z", (R0 + R1) / 2, 0.012, M["emit"], n=48, m=6, what="lisere")
    g.sphere((0, 0, zs + 0.3), 0.36, M["noir_profond"], n=32, m=16, what="sphere_noire")
    g.torus((0, 0, zs + 0.3), "z", 0.37, 0.018, M["emit"], n=48, m=6, what="equateur")
    cp.halo(g, (0, -0.6, zs + 0.2), M, 4.0)
