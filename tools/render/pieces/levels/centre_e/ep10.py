"""Centre de commandement · Âge 10 · Haute technologie (7×7, niveau 10). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« tour de contrôle, paraboles, vitrage » : immeuble ivoire et gris à trois étages, tour de contrôle à
cabine vitrée lumineuse, deux paraboles et antenne.
"""
import math

import ages
import corps as cp

EPOQUE = 10
NOM = ages.NOMS[10]
TRIPLET = ('tour de contrôle', 'paraboles', 'vitrage')
FOYER = ages.FOYER[10]
HABILLAGE = dict(ages.CORPS[10], plan="carre", etages=3, toit="plat", mat_e1="blanc_casse", mat_e2="gris_tech",
                 mat_e3="blanc_casse")

RAYON_MAT = 0.92   # rayon du pied du mât (avant échelle) : borne de l'échelle du mât (corps.centre)

ARCHI = True   # ronde F5-A2 : contreforts, baies, balcon, verrière (corps.architecture)

FENETRES = "emit"   # ronde F5-A2 : nuit de l'âge 10 (presque noire en ronde 1)


def matieres(metal, M):
    ages.matieres(10, metal, M)

def _parabole(g, M, x, y, z, a):
    g.push((x, y, z), rz=a, ry=math.radians(-35))
    g.sphere((0, 0, 0), 0.3, M["blanc_casse"], n=20, m=8, scale=(1, 1, 0.3), what="parabole")
    cp.colonne(g, 0, 0, 0.0, 0.14, 0.012, M["anthracite"], n=6, what="cornet")
    g.pop()


def mat(g, c, z):
    M = g.M
    cp.colonne(g, 0, 0, z, z + 0.6, 0.2, M["gris_tech"], n=16, what="fut_tour")
    cp.prisme(g, cp.octogone(0.5), z + 0.6, z + 0.66, M["anthracite"], what="plancher_cabine")
    cp.prisme(g, cp.octogone(0.47), z + 0.66, z + 0.86, M["emit_soft"], what="vitrage")
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        cp.poutre(g, (0.48 * math.cos(a), 0.48 * math.sin(a), z + 0.66), (0.48 * math.cos(a), 0.48 * math.sin(a), z + 0.86),
                  0.02, M["blanc_casse"], "meneau")
    cp.prisme(g, cp.octogone(0.53), z + 0.86, z + 0.92, M["blanc_casse"], what="toit_cabine")
    cp.colonne(g, 0, 0, z + 0.92, z + 1.4, 0.015, M["anthracite"], n=6, what="antenne")
    g.dome((0, 0, z + 1.4), (0, 0, 1), 0.03, M["emit"], what="feu_antenne")
    _parabole(g, M, -0.62, 0.3, z + 0.25, math.radians(200))     # coordonnées avant l'échelle du mât
    _parabole(g, M, 0.62, 0.34, z + 0.25, math.radians(-20))
    for (bx, by) in ((-0.55, -0.45), (0.55, -0.45)):
        cp.colonne(g, bx, by, z, z + 0.3, 0.02, M["anthracite"], n=6, what="mat_balise")
        g.dome((bx, by, z + 0.3), (0, 0, 1), 0.035, M["emit"], what="balise")
    cp.halo(g, (0, -0.4, z + 0.75), M, 3.0)
