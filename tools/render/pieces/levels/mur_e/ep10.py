"""Mur · Âge 10 · Haute technologie (ère IV). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « pylônes fins, panneaux, voyants ». Poteau : pylône SVELTE ivoire à embase anthracite, antenne, colonne de
voyants bleus. Bras : panneau BAS anthracite dans un cadre ivoire, deux câbles (rouge, bleu) sur la face, bandeau de
voyants. Silhouette : mur bas et nu, pylônes minces et hauts. Palette (ages.PALETTE[10]) : ivoire / anthracite / câbles.
"""
import ages
from corps import B, cellules

EPOQUE = 10
NOM = ages.NOMS[10]
TRIPLET = ("pylônes fins", "panneaux", "voyants")
FOYER = ages.FOYER[10]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.55, 0.62, 0.3, 0.2


def matieres(metal, M):
    ages.matieres(10, metal, M)


def poteau(g, c):
    M = g.M
    B(g, -0.19, 0.19, -0.19, 0.19, 0.0, 0.2, M["anthracite"])
    B(g, -0.14, 0.14, -0.14, 0.14, 0.2, 1.3, M["blanc_casse"])
    B(g, -0.15, 0.15, -0.15, 0.15, 1.3, 1.36, M["gris_tech"])
    for k in range(5):
        B(g, -0.03, 0.03, -0.147, -0.14, 0.35 + 0.17 * k, 0.4 + 0.17 * k, M["emit"], style="flat", what="voyant")
    B(g, -0.1, 0.1, -0.142, -0.138, 0.2, 1.28, M["acier_tech"], style="flat", what="fente")
    g.cyl((0, 0, 1.5), "z", 0.014, 0.28, M["acier_tech"], n=8, what="antenne")
    g.sphere((0, 0, 1.65), 0.03, M["emit"], what="balise")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.1, 0.1, 0.0, 0.1, M["anthracite"])
    B(g, 0, L, -0.09, 0.09, 0.1, 0.56, M["anthracite"])
    B(g, 0, L, -0.1, 0.1, 0.56, 0.62, M["blanc_casse"], what="cadre")
    B(g, 0, L, -0.1, 0.1, 0.1, 0.14, M["blanc_casse"], what="cadre")
    g.cyl((L / 2, -0.105, 0.26), "x", 0.02, L, M["cable_r"], n=8, what="cable")
    g.cyl((L / 2, -0.105, 0.34), "x", 0.02, L, M["cable_b"], n=8, what="cable")
    for i, (a, b) in enumerate(cellules(L, n)):
        m = 0.5 * (a + b)
        B(g, m - 0.035, m + 0.035, -0.108, -0.1, 0.43, 0.48, M["emit"], style="flat", what="voyant")
        if i:
            B(g, a - 0.01, a + 0.01, -0.1, 0.1, 0.14, 0.56, M["gris_tech"], style="flat", what="joint")
