"""Mur · Âge 2 · Forge (ère I). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « brique rouge, créneaux, sangles de fer ». Poteau : pilier de briques coiffé d'un brasero de fonte (braise =
la lumière de l'âge). Bras : mur de briques à CRÉNEAUX (un merlon par cellule) ceinturé de sangles de fer noir.
Palette 60/30/10 (ages.PALETTE[2]) : fer martelé et brique / mortier / braise rouge.
"""
import ages
import formes as F
from corps import B, cellules

EPOQUE = 2
NOM = ages.NOMS[2]
TRIPLET = ("brique rouge", "créneaux", "sangles de fer")
FOYER = ages.FOYER[2]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.2, 0.86, 0.5, 0.32


def matieres(metal, M):
    ages.matieres(2, metal, M)


def _briques(g, x0, x1, z0, z1, y):
    M = g.M
    F.courses(g, [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)],
              [M["brique"], M["brique_pave"], M["brique_pave2"]], bw=0.12, bh=0.058, t=0.016)


def poteau(g, c):
    M = g.M
    B(g, -0.25, 0.25, -0.25, 0.25, 0.0, 1.0, M["mortier"])
    _briques(g, -0.25, 0.25, 0.01, 1.0, -0.25)
    B(g, -0.29, 0.29, -0.29, 0.29, 1.0, 1.08, M["fer_martele"])
    for sx in (-1, 1):
        B(g, sx * 0.27 - 0.025, sx * 0.27 + 0.025, -0.31, -0.26, 0.2, 1.06, M["fer_noir"], what="cornière")
    g.tube_shell((0, 0, 1.12), "z", 0.19, 0.15, 0.08, M["fer_noir"], n=20, what="brasero")
    g.cyl((0, 0, 1.13), "z", 0.155, 0.07, M["emit"], n=20, style="flat", what="braise")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.16, 0.16, 0.0, 0.7, M["mortier"])
    _briques(g, 0, L, 0.01, 0.7, -0.16)
    B(g, 0, L, -0.18, 0.18, 0.7, 0.75, M["fer_martele"])
    for i, (a, b) in enumerate(cellules(L, n)):
        m = 0.5 * (a + b)
        w = 0.3 * (b - a)
        B(g, m - w, m + w, -0.15, 0.15, 0.75, 0.88, M["brique_pave"])
        if i > 0:
            B(g, a - 0.014, a + 0.014, -0.175, 0.175, 0.0, 0.76, M["fer_noir"], what="sangle")
