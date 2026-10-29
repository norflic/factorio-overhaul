"""Mur · Âge 13 · Antimatière (ère V). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « sphère de confinement, bobines, tube de verre ». Poteau : fût d'acier canon portant une SPHÈRE de verre
fumé, ceinte de bobines de cuivre, noyau d'annihilation violet. Bras : soubassement d'acier noir et TUBE DE VERRE fumé à
âme lumineuse, tenu par des étriers. Palette (ages.PALETTE[13]) : acier canon / cuivre rouge / lueur violette et bleue.
"""
import ages
from corps import B, cellules

EPOQUE = 13
NOM = ages.NOMS[13]
TRIPLET = ("sphère de confinement", "bobines", "tube de verre")
FOYER = ages.FOYER[13]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.45, 0.95, 0.46, 0.3
ZT = 0.74


def matieres(metal, M):
    ages.matieres(13, metal, M)


def poteau(g, c):
    M = g.M
    B(g, -0.22, 0.22, -0.22, 0.22, 0.0, 0.2, M["acier_noir"])
    g.cyl((0, 0, 0.5), "z", 0.1, 0.62, M["acier_canon"], n=14, what="fut")
    g.sphere((0, 0, 1.02), 0.27, M["verre_fume"], what="sphere")
    g.sphere((0, 0, 1.02), 0.12, M["emit"], what="noyau")
    for k, (z, r) in enumerate(((0.9, 0.262), (1.02, 0.27), (1.14, 0.256))):
        g.torus((0, 0, z), "z", r + 0.01, 0.026, M["cuivre_bobine"], n=26, m=6, what="bobine")
    g.cyl((0, 0, 1.31), "z", 0.05, 0.1, M["chrome_fin"], n=10, what="pointe")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.15, 0.15, 0.0, 0.46, M["acier_noir"])
    B(g, 0, L, -0.16, 0.16, 0.44, 0.5, M["acier_canon2"], what="platine")
    g.cyl((L / 2, 0, ZT), "x", 0.15, L, M["verre_fume"], n=20, what="tube")
    g.cyl((L / 2, 0, ZT), "x", 0.05, L, M["emit2"], n=10, style="flat", what="ame")
    for i, (a, b) in enumerate(cellules(L, n)):
        m = 0.5 * (a + b)
        g.cyl((m, 0, ZT), "x", 0.07, 0.012, M["emit"], n=10, style="flat", what="perle")
        if i:
            g.torus((a, 0, ZT), "x", 0.152, 0.022, M["acier_canon"], n=20, m=6, what="etrier")
            B(g, a - 0.015, a + 0.015, -0.03, 0.03, 0.5, ZT - 0.12, M["acier_canon"], what="montant")
    g.torus((L, 0, ZT), "x", 0.152, 0.022, M["acier_canon"], n=20, m=6, what="etrier")
