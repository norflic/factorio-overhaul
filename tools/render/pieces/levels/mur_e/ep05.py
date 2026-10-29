"""Mur · Âge 5 · Volcan (ère II). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « orgues de basalte, blocs de lave, fissures rougeoyantes ». Poteau : trois orgues basaltiques hexagonales de
hauteurs inégales, évent de lave au sommet. Bras : blocs de basalte BRUTS et irréguliers (silhouette déchirée) ; la lave
affleure aux joints. Palette (ages.PALETTE[5]) : basalte noir / fonte brûlée / lave.
"""
import math

import ages
import formes as F
from corps import B, cellules, alea

EPOQUE = 5
NOM = ages.NOMS[5]
TRIPLET = ("orgues de basalte", "blocs de lave", "fissures rougeoyantes")
FOYER = ages.FOYER[5]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.3, 0.85, 0.5, 0.34


def matieres(metal, M):
    ages.matieres(5, metal, M)


def _orgue(g, x, y, r, h, mat):
    pts = [(x + r * math.cos(math.pi / 3 * k + 0.3), y + r * math.sin(math.pi / 3 * k + 0.3)) for k in range(6)]
    F.prism(g, pts, 0.0, h, mat, what="orgue")
    top = [(x + r * 0.8 * math.cos(math.pi / 3 * k + 0.3), y + r * 0.8 * math.sin(math.pi / 3 * k + 0.3))
           for k in range(6)]
    F.prism(g, top, h, h + 0.04, g.M["basalte_dalle2"], what="orgue_tete")


def poteau(g, c):
    M = g.M
    g.cyl((0, 0, 0.06), "z", 0.3, 0.12, M["fonte_v"], n=10, style="soft", what="assise")
    _orgue(g, -0.1, -0.06, 0.17, 1.05, M["basalte_capot"])
    _orgue(g, 0.12, 0.05, 0.16, 1.28, M["basalte_dalle"])
    _orgue(g, 0.02, -0.17, 0.14, 0.82, M["basalte_capot"])
    g.cyl((0.12, 0.05, 1.31), "z", 0.1, 0.03, M["emit"], n=10, style="flat", what="lave")
    B(g, -0.1, 0.02, -0.235, -0.225, 0.05, 0.4, M["emit"], style="flat", what="fissure")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.14, 0.14, 0.0, 0.16, M["fonte_noire"])
    B(g, 0, L, -0.12, 0.12, 0.1, 0.2, M["emit"], style="flat", what="joint_lave")
    for i, (a, b) in enumerate(cellules(L, n)):
        m = 0.5 * (a + b)
        for k in range(2):
            h = alea(g, 0.5, 0.86)
            F.lump(g, (m + alea(g, -0.04, 0.04), (-0.07 if k else 0.07), 0.12), 0.13 + 0.03 * g.rng.random(),
                   M["basalte_dalle" if (i + k) % 2 else "basalte_capot"], sz=h / 0.16, n=8, m=5, jit=0.22, what="bloc")
    B(g, 0, L, -0.1, 0.1, 0.5, 0.52, M["fonte_v"], style="flat", what="liaison")
