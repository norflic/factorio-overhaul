"""Foreuse · Âge 1 · Pionnier (ère I, 3×3, niveaux 1 et 2). Lot F4-A (25/10). S'exécute DANS Blender.

Niveau 1 : la foreuse vanilla, inchangée. Niveau 2 : une CHÈVRE DE BOIS (trépied de perches liées) posée SUR la foreuse,
POULIE de fer au sommet, corde jusqu'au centre, LANTERNE à huile pendue sous la poulie (foyer de NUIT, #FFB060). La
pièce dépasse la silhouette vanilla par le haut (F42) ; une seule image pour les 4 directions (trépied rond).
"""
import math

import ages
import corps as cp

EPOQUE = 1
NOM = ages.NOMS[1]
TRIPLET = ("chèvre de bois", "poulie", "lanterne")
FOYER = ages.FOYER[1]
HABILLAGE = {}


def matieres(metal, M):
    ages.matieres(1, metal, M)


def piece(g, c):
    M = g.M
    za = 2.15                       # sommet du trépied (au-dessus du corps vanilla, dont le haut est vers 1,1)
    R = 1.22
    for k in range(3):
        a = math.radians(90 + 120 * k + 30)
        p0 = (R * math.cos(a), R * math.sin(a), 0.32)
        p1 = (0.10 * math.cos(a), 0.10 * math.sin(a), za)
        g.tube([p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2), p1], 0.045, M["wood"], n=8,
               what="perche")
        g.cyl(p0, "z", 0.075, 0.08, M["wood2"], n=8, style="hard", what="sabot")
        for t in (0.35, 0.62):
            q = (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, p0[2] + (p1[2] - p0[2]) * t)
            g.cyl(q, (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]), 0.056, 0.035, M["canvas"], n=8, what="ligature")
    # tête liée et poulie
    g.cyl((0, 0, za + 0.02), "z", 0.13, 0.12, M["canvas2"], n=10, what="liure")
    g.cyl((0, 0, za - 0.12), "x", 0.13, 0.05, M["rawiron"], n=16, what="poulie")
    g.cyl((0, 0, za - 0.12), "x", 0.04, 0.09, M["blackiron"], n=8, what="axe")
    # corde et lanterne
    g.tube([(0.0, 0.0, za - 0.25), (0.0, 0.0, 1.55), (0.0, 0.0, 1.32)], 0.012, M["canvas2"], n=6, what="corde")
    g.cyl((0, 0, 1.24), "z", 0.075, 0.16, M["emit"], n=10, style="flat", what="lanterne")
    g.cyl((0, 0, 1.335), "z", 0.09, 0.03, M["blackiron"], n=10, what="chapeau")
    g.cyl((0, 0, 1.145), "z", 0.085, 0.03, M["blackiron"], n=10, what="fond")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        g.cyl((0.08 * math.cos(a), 0.08 * math.sin(a), 1.24), "z", 0.012, 0.19, M["blackiron"], n=5, what="barreau")
    cp.halo(g, (0, -0.15, 1.2), M, 4.0)
