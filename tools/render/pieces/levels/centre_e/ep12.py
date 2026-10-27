"""Centre de commandement · Âge 12 · Supraconducteurs (7×7, niveau 12). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« anneau supraconducteur, givre, voyants cyan » : tour octogonale noir miroir à trois étages, anneau
supraconducteur chromé couché sur trois tenons, voile noir et bande cyan, conduites givrées.
"""
import math

import ages
import corps as cp

EPOQUE = 12
NOM = ages.NOMS[12]
TRIPLET = ('anneau supraconducteur', 'givre', 'voyants cyan')
FOYER = ages.FOYER[12]
HABILLAGE = dict(ages.CORPS[12], plan="octo", etages=3, toit="plat", mat_e1="noir_miroir", mat_e2="frost",
                 mat_e3="chrome_mat")

RAYON_MAT = 0.65   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)

ARCHI = True   # ronde F5-A2 : contreforts, baies, balcon, verrière (corps.architecture)


def matieres(metal, M):
    ages.matieres(12, metal, M)

def mat(g, c, z):
    M = g.M
    R = 0.55
    zr = z + 0.5
    for k in range(3):
        a = math.tau * k / 3 + math.pi / 2
        cp.colonne(g, R * 0.8 * math.cos(a), R * 0.8 * math.sin(a), z, zr, 0.05, M["chrome_mat"], n=10, what="tenon")
    g.torus((0, 0, zr), "z", R, 0.09, M["chrome_mat"], n=48, m=12, what="anneau_supra")
    cp.colonne(g, 0, 0, zr - 0.03, zr + 0.03, R, M["noir_miroir"], n=48, what="voile")
    g.torus((0, 0, zr + 0.04), "z", R * 0.85, 0.025, M["emit"], n=48, m=8, what="bande_cyan")
    cp.colonne(g, 0, 0, z, zr + 0.65, 0.04, M["chrome_mat"], n=10, what="antenne_cryo")
    g.dome((0, 0, zr + 0.65), (0, 0, 1), 0.04, M["emit"], what="feu_antenne")
    for k in range(8):
        a = math.tau * k / 8
        g.dome((R * 1.13 * math.cos(a), R * 1.13 * math.sin(a), zr), (math.cos(a), math.sin(a), 0), 0.03, M["emit"],
               what="voyant")
    for s in (-1, 1):
        g.hose([(s * R, -0.05, zr - 0.05), (s * (R + 0.15), -0.1, zr - 0.25), (s * (R + 0.05), -0.2, z + 0.02)], 0.045,
               M["frost"])
    cp.halo(g, (0, -0.5, zr), M, 3.5)
