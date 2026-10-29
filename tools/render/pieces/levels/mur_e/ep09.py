"""Mur · Âge 9 · Atome (ère III). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « béton, profil Jersey, plomb ». Poteau : massif de béton à dessus de plomb et ceinture jaune de danger,
trèfle de radioactivité. Bras : bloc de béton de PROFIL JERSEY (pied large, flancs inclinés), joints de plomb, trèfle.
Palette (ages.PALETTE[9]) : béton blanc cassé / plomb gris-bleu / vert uranium.
"""
import ages
import formes as F
from corps import B, cellules, tronc

EPOQUE = 9
NOM = ages.NOMS[9]
TRIPLET = ("béton", "profil Jersey", "plomb")
FOYER = ages.FOYER[9]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.2, 0.95, 0.54, 0.46


def matieres(metal, M):
    ages.matieres(9, metal, M)


def poteau(g, c):
    M = g.M
    tronc(g, -0.27, 0.27, -0.27, 0.27, 0.0, 1.12, 0.9, M["beton_capot"])
    B(g, -0.245, 0.245, -0.292, -0.26, 0.5, 0.64, M["hazy"], style="flat", what="danger")
    B(g, -0.245, 0.245, -0.292, -0.26, 0.74, 0.86, M["hazk"], style="flat", what="danger")
    B(g, -0.31, 0.31, -0.31, 0.31, 1.12, 1.22, M["lead"])
    g.cyl((0, 0, 1.23), "z", 0.07, 0.02, M["emit"], n=12, style="flat", what="voyant")


def bras(g, c, L, n):
    M = g.M
    tronc(g, 0, L, -0.23, 0.23, 0.0, 0.62, 1.0, M["beton_dalle"], ky=0.68, what="jersey_bas")
    tronc(g, 0, L, -0.157, 0.157, 0.62, 0.95, 1.0, M["beton_dalle2"], ky=0.74, what="jersey_haut")
    for i, (a, b) in enumerate(cellules(L, n)):
        if i:
            tronc(g, a - 0.015, a + 0.015, -0.234, 0.234, 0.0, 0.62, 1.0, M["lead"], ky=0.68, what="joint_plomb")
            tronc(g, a - 0.015, a + 0.015, -0.16, 0.16, 0.62, 0.96, 1.0, M["lead"], ky=0.74, what="joint_plomb")
    B(g, 0, L, -0.045, 0.045, 0.95, 0.99, M["lead"], what="arete")
    F.trefoil(g, (0.5 * L, -0.176, 0.5), (0, -1, 0.3), 0.07)
