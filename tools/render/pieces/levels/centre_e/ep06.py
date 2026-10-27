"""Centre de commandement · Âge 6 · Électricité (5×5, niveau 6). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« tour Tesla, isolateurs, arcs bleus » : centrale en croix de porcelaine et de bleu machine, tour
d'isolateurs couronnée d'un tore plein et d'une boule de décharge, arcs bleus.
"""
import math

import ages
import corps as cp

EPOQUE = 6
NOM = ages.NOMS[6]
TRIPLET = ('tour Tesla', 'isolateurs', 'arcs bleus')
FOYER = ages.FOYER[6]
HABILLAGE = dict(ages.CORPS[6], plan="croix", etages=2, toit="plat", mat_e1="porcelaine_capot", mat_e2="bleu_machine")

RAYON_MAT = 0.52   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)


def matieres(metal, M):
    ages.matieres(6, metal, M)

def mat(g, c, z):
    M = g.M
    cp.colonne(g, 0, 0, z, z + 0.12, 0.2, M["bleu_machine"], n=16, style="hard", what="socle_tesla")
    zz = z + 0.12
    for i in range(7):
        cp.colonne(g, 0, 0, zz, zz + 0.06, 0.11, M["porcelaine"], n=16, what="isolateur")
        cp.colonne(g, 0, 0, zz + 0.06, zz + 0.1, 0.06, M["porcelaine_capot"], n=12, what="fut_isolateur")
        zz += 0.1
    g.torus((0, 0, zz + 0.06), "z", 0.22, 0.07, M["fonte_bleue"], n=32, m=10, what="tore")
    cp.colonne(g, 0, 0, zz + 0.02, zz + 0.1, 0.2, M["bleu_machine"], n=32, what="voile")
    g.sphere((0, 0, zz + 0.2), 0.1, M["emit"], n=16, m=8, what="boule")
    for s in (-1, 1):
        pts = [(s * 0.1, -0.05, zz + 0.18), (s * 0.25, -0.12, zz + 0.05), (s * 0.3, -0.25, zz - 0.1),
               (s * 0.42, -0.3, z + 0.05)]
        g.tube(pts, 0.012, M["emit"], n=5, what="arc")
    cp.halo(g, (0, -0.2, zz + 0.2), M, 3.5)
