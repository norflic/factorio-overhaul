"""Mur · Âge 3 · Vapeur (ère I). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « chaudière, tuyaux de laiton, dômes ». Poteau : chaudière verticale de cuivre cerclée de laiton, dôme et
soupape. Bras : soubassement vert locomotive portant DEUX GROS TUYAUX de cuivre à brides de laiton (silhouette ronde).
Palette (ages.PALETTE[3]) : cuivre / vert locomotive / laiton.
"""
import ages
from corps import B, cellules

EPOQUE = 3
NOM = ages.NOMS[3]
TRIPLET = ("chaudière", "tuyaux de laiton", "dômes")
FOYER = ages.FOYER[3]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.45, 0.92, 0.46, 0.34


def matieres(metal, M):
    ages.matieres(3, metal, M)


def poteau(g, c):
    M = g.M
    g.cyl((0, 0, 0.05), "z", 0.28, 0.1, M["vert_loco"], n=20, style="soft", what="socle")
    g.cyl((0, 0, 0.62), "z", 0.23, 1.04, M["cuivre_capot"], n=22, what="chaudiere")
    for z in (0.2, 0.62, 1.04):
        g.torus((0, 0, z), "z", 0.232, 0.024, M["laiton_capot"], n=26, m=6, what="cerclage")
    g.sphere((0, 0, 1.14), 0.232, M["cuivre_capot"], scale=(1, 1, 0.55), what="dome")
    g.cyl((0, 0, 1.33), "z", 0.034, 0.16, M["laiton_pont"], n=10, what="soupape")
    g.sphere((0, 0, 1.43), 0.05, M["laiton_capot"], what="bille")
    g.cyl((0.12, -0.12, 1.28), "z", 0.025, 0.12, M["laiton_pont2"], n=8, what="sifflet")
    g.cyl((0, -0.235, 0.62), "y", 0.07, 0.03, M["emit"], n=14, style="flat", what="voyant")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.16, 0.16, 0.0, 0.36, M["vert_loco"])
    B(g, 0, L, -0.17, 0.17, 0.33, 0.38, M["laiton_pont"])
    B(g, 0, L, -0.1, 0.1, 0.36, 0.52, M["cuivre_sombre"])
    g.cyl((L / 2, -0.02, 0.58), "x", 0.125, L, M["cuivre_capot"], n=18, what="tuyau")
    g.cyl((L / 2, 0.0, 0.8), "x", 0.1, L, M["cuivre_capot"], n=18, what="tuyau")
    for i, (a, b) in enumerate(cellules(L, n)):
        if i:
            g.torus((a, -0.02, 0.58), "x", 0.125, 0.022, M["laiton_capot"], n=18, m=6, what="bride")
            g.torus((a, 0.0, 0.8), "x", 0.1, 0.02, M["laiton_capot"], n=18, m=6, what="bride")
    g.torus((L, -0.02, 0.58), "x", 0.125, 0.022, M["laiton_capot"], n=18, m=6, what="bride")
    g.torus((L, 0.0, 0.8), "x", 0.1, 0.02, M["laiton_capot"], n=18, m=6, what="bride")
