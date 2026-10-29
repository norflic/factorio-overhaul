"""Mur · Âge 7 · Cristal (ère III). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « obélisque, cristaux, pierre claire ». Poteau : obélisque de pierre claire à base large, bague de bronze,
GRAND CRISTAL violet au sommet. Bras : muret de pierre claire coiffé d'un listel de bronze, d'où poussent des éclats de
cristal inclinés (silhouette en épines). Palette (ages.PALETTE[7]) : bronze doré / pierre claire / violet.
"""
import math

import ages
import formes as F
from corps import B, tronc, cellules, alea

EPOQUE = 7
NOM = ages.NOMS[7]
TRIPLET = ("obélisque", "cristaux", "pierre claire")
FOYER = ages.FOYER[7]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.6, 0.95, 0.5, 0.34


def matieres(metal, M):
    ages.matieres(7, metal, M)


def poteau(g, c):
    M = g.M
    B(g, -0.27, 0.27, -0.27, 0.27, 0.0, 0.14, M["pierre_claire2"])
    tronc(g, -0.23, 0.23, -0.23, 0.23, 0.14, 1.0, 0.62, M["pierre_claire"])
    g.tube_shell((0, 0, 0.62), "z", 0.28, 0.2, 0.05, M["bronze_capot"], n=4, what="bague", style="hard")
    tronc(g, -0.145, 0.145, -0.145, 0.145, 1.0, 1.1, 0.8, M["bronze_clair"], what="chapiteau")
    F.crystal(g, (0, 0, 1.08), (0.0, 0.0, 1.0), 0.1, 0.5, M["crystal"], tip=0.4, n=6, what="grand_cristal")
    F.crystal(g, (0.07, -0.05, 1.08), (0.35, -0.2, 1.0), 0.05, 0.28, M["emit_soft"], tip=0.4, n=6, what="eclat")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.16, 0.16, 0.0, 0.1, M["pierre_claire2"])
    B(g, 0, L, -0.14, 0.14, 0.1, 0.56, M["pierre_claire"])
    for i, (a, b) in enumerate(cellules(L, n)):
        if i:
            B(g, a - 0.008, a + 0.008, -0.145, 0.145, 0.1, 0.56, M["joint_violet"], style="flat", what="joint")
    B(g, 0, L, -0.17, 0.17, 0.56, 0.62, M["bronze_capot"])
    for i, (a, b) in enumerate(cellules(L, n)):
        m = 0.5 * (a + b)
        d = (alea(g, -0.25, 0.25), alea(g, -0.5, 0.5) * 0.4, 1.0)
        F.crystal(g, (m, alea(g, -0.05, 0.05), 0.6), d, 0.055, alea(g, 0.22, 0.4), M["crystal"], tip=0.4, n=6,
                  what="eclat")
        if i % 2:
            F.crystal(g, (m + 0.05, 0.06, 0.6), (0.3, 0.2, 1.0), 0.032, 0.17, M["emit_soft"], tip=0.4, n=6, what="eclat")
