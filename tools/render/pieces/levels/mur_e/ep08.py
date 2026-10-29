"""Mur · Âge 8 · Marais (ère III). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « palissade, rondins moussus, lanterne toxique ». Poteau : gros rondin pourri cerclé de cuivre terni, mousse,
lanterne de verre jaune toxique. Bras : PALISSADE de rondins verticaux de hauteurs inégales, deux lisses, mousse.
Palette (ages.PALETTE[8]) : vert-de-gris / bois mouillé et cuivre / jaune toxique.
"""
import ages
import formes as F
from corps import B, alea, cellules

EPOQUE = 8
NOM = ages.NOMS[8]
TRIPLET = ("palissade", "rondins moussus", "lanterne toxique")
FOYER = ages.FOYER[8]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.35, 1.0, 0.42, 0.22


def matieres(metal, M):
    ages.matieres(8, metal, M)


def poteau(g, c):
    M = g.M
    g.cyl((0, 0, 0.62), "z", 0.19, 1.24, M["bois_mouille"], n=14, what="rondin")
    for z in (0.3, 0.95):
        g.torus((0, 0, z), "z", 0.195, 0.022, M["cuivre_terni"], n=18, m=6, what="cercle")
    F.lump(g, (-0.05, -0.08, 1.2), 0.17, M["bois_mousse"], sz=0.5, n=9, m=5, jit=0.3, what="mousse")
    F.lump(g, (0.08, 0.03, 0.12), 0.2, M["bois_mousse"], sz=0.5, n=9, m=5, jit=0.3, what="mousse")
    g.cyl((0, -0.2, 0.82), "y", 0.02, 0.1, M["cuivre_terni"], n=6, what="potence")
    g.sphere((0, -0.27, 0.8), 0.075, M["verre_toxique"], what="lanterne")
    g.sphere((0, -0.27, 0.8), 0.045, M["emit_soft"], what="foyer")
    g.cyl((0, -0.27, 0.9), "z", 0.04, 0.03, M["cuivre_terni"], n=8, what="chapeau")


def bras(g, c, L, n):
    M = g.M
    pas = 0.125
    k = 0
    x = 0.07
    while x < L + 0.05:
        h = alea(g, 0.7, 1.0)
        yy = 0.035 * (1 if k % 2 else -1)
        mat = M["bois_mouille"] if k % 3 else M["bois_mousse"]
        g.cyl((min(x, L), yy, h / 2), "z", 0.068, h, mat, n=10, what="piquet")
        if k % 4 == 1:
            F.lump(g, (min(x, L), yy, h - 0.02), 0.07, M["bois_mousse"], sz=0.6, n=7, m=4, jit=0.3, what="mousse")
        x += pas
        k += 1
    for z in (0.28, 0.58):
        B(g, 0, L, -0.09, 0.09, z, z + 0.05, M["cuivre_terni"], what="lisse")
    B(g, 0, L, -0.13, 0.13, 0.0, 0.07, M["bois_mousse"], what="pied")
