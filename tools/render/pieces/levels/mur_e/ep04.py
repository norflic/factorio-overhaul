"""Mur · Âge 4 · Pétrole (ère II). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « fûts de pétrole, tôle ondulée, barbelés ». Poteau : deux fûts empilés (jaune et noir) coiffés d'un
bec de torchère. Bras : soubassement de tôle larmée, TÔLE ONDULÉE galvanisée, lisse de danger jaune et noir, rouleau de
fil barbelé. Palette (ages.PALETTE[4]) : jaune de signalisation / noir et galva / rouge.
"""
import ages
import formes as F
from corps import B, cellules

EPOQUE = 4
NOM = ages.NOMS[4]
TRIPLET = ("fûts de pétrole", "tôle ondulée", "barbelés")
FOYER = ages.FOYER[4]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.3, 1.0, 0.46, 0.3


def matieres(metal, M):
    ages.matieres(4, metal, M)


def poteau(g, c):
    M = g.M
    F.drum(g, (0, 0, 0.0), 0.225, 0.58, M["jaune_capot"], M["noir_capot"])
    F.drum(g, (0, 0, 0.58), 0.225, 0.52, M["noir_capot"], M["galva_sombre"])
    g.tube_shell((0, 0, 1.12), "z", 0.19, 0.14, 0.1, M["galva_capot"], n=20, what="collerette")
    g.cyl((0, 0, 1.22), "z", 0.05, 0.16, M["galva"], n=10, what="event")
    g.sphere((0, 0, 1.31), 0.06, M["emit"], what="flamme", scale=(1, 1, 1.4))
    F.hazard_ring(g, (0, 0, 0.28), "z", 0.225, 0.07, n=12)


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.15, 0.15, 0.0, 0.18, M["tole_larmee"])
    B(g, 0, L, -0.11, 0.11, 0.18, 0.72, M["galva_sombre"])
    pas = 0.06
    k = 0
    x = 0.0
    while x < L - 1e-6:
        B(g, x, min(L, x + pas * 0.55), -0.135 if k % 2 else -0.115, 0.135 if k % 2 else 0.115, 0.18, 0.72,
          M["galva"], style="flat", what="ondulation")
        x += pas
        k += 1
    B(g, 0, L, -0.14, 0.14, 0.72, 0.8, M["galva_capot"])
    for i, (a, b) in enumerate(cellules(L, n * 2)):
        B(g, a, b, -0.145, 0.145, 0.8, 0.88, M["jaune_capot"] if i % 2 else M["noir_capot"], style="flat", what="danger")
    x = 0.04
    while x < L:
        g.torus((x, 0, 0.99), "x", 0.085, 0.017, M["galva"], n=14, m=4, what="barbele")
        x += 0.075
