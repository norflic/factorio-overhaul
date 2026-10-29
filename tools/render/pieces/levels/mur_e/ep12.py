"""Mur · Âge 12 · Supraconducteurs (ère IV). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « chrome, givre, conduit cryogénique ». Poteau : colonne de chrome ceinte de bagues de givre, couronne cyan
lumineuse, aiguilles de glace. Bras : dalle de noir miroir sous un rail de chrome, CONDUIT cryogénique cyan sur la face,
ÉPINES de givre sur le dessus. Palette (ages.PALETTE[12]) : blanc glacé / noir miroir et chrome / cyan.
"""
import ages
import formes as F
from corps import B, cellules, alea

EPOQUE = 12
NOM = ages.NOMS[12]
TRIPLET = ("chrome", "givre", "conduit cryogénique")
FOYER = ages.FOYER[12]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.5, 0.95, 0.4, 0.26


def matieres(metal, M):
    ages.matieres(12, metal, M)


def poteau(g, c):
    M = g.M
    g.cyl((0, 0, 0.06), "z", 0.25, 0.12, M["noir_miroir"], n=20, style="soft", what="assise")
    g.cyl((0, 0, 0.7), "z", 0.14, 1.2, M["chrome_mat"], n=22, what="colonne")
    for z in (0.3, 0.62, 0.94):
        g.cyl((0, 0, z), "z", 0.19, 0.1, M["frost"], n=18, r2=0.15, what="givre")
    g.torus((0, 0, 1.22), "z", 0.17, 0.028, M["emit"], n=26, m=6, what="couronne")
    g.cyl((0, 0, 1.32), "z", 0.14, 0.08, M["noir_miroir2"], n=22, what="chapeau")
    for k, (dx, dy, h) in enumerate(((0.0, 0.0, 0.34), (0.07, 0.04, 0.22), (-0.07, -0.03, 0.2))):
        F.crystal(g, (dx, dy, 1.34), (dx * 2, dy * 2, 1.0), 0.03, h, M["frost"], tip=0.5, n=5, what="aiguille")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.13, 0.13, 0.0, 0.62, M["noir_miroir"])
    B(g, 0, L, -0.145, 0.145, 0.62, 0.72, M["chrome_mat"], what="rail")
    B(g, 0, L, -0.14, 0.14, 0.0, 0.1, M["noir_miroir2"], what="semelle")
    g.cyl((L / 2, -0.15, 0.36), "x", 0.045, L, M["grille_chrome"], n=12, what="conduit")
    g.cyl((L / 2, -0.152, 0.36), "x", 0.024, L, M["emit"], n=8, style="flat", what="ame")
    for i, (a, b) in enumerate(cellules(L, n)):
        m = 0.5 * (a + b)
        if i:
            g.torus((a, -0.15, 0.36), "x", 0.047, 0.016, M["chrome_mat"], n=12, m=4, what="collier")
        for k in range(2):
            F.crystal(g, (m + 0.045 * (k - 0.5), 0.05 * (1 - 2 * k), 0.71), (0.0, 0.0, 1.0), 0.036, alea(g, 0.16, 0.34),
                      M["frost"], tip=0.5, n=5, what="epine")
