"""Mur · Âge 6 · Électricité (ère II). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « isolateurs, disques de porcelaine, arcs ». Poteau : mât d'isolateurs (pile de disques de porcelaine sur âme
bleue), boule de cuivre et étincelle. Bras : coffre de transformateur bleu à rail de porcelaine, bobines de cuivre ; un
ARC électrique relie les sommets des mâts. Palette (ages.PALETTE[6]) : porcelaine / bleu / cuivre et arcs.
"""
import ages
from corps import B, cellules

EPOQUE = 6
NOM = ages.NOMS[6]
TRIPLET = ("isolateurs", "disques de porcelaine", "arcs")
FOYER = ages.FOYER[6]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.45, 0.7, 0.44, 0.3
ZARC = 1.38


def matieres(metal, M):
    ages.matieres(6, metal, M)


def poteau(g, c):
    M = g.M
    B(g, -0.22, 0.22, -0.22, 0.22, 0.0, 0.16, M["fonte_bleue"])
    g.cyl((0, 0, 0.7), "z", 0.07, 1.3, M["bleu_machine"], n=12, what="ame")
    for k in range(8):
        z = 0.22 + 0.125 * k
        g.cyl((0, 0, z), "z", 0.2 - 0.008 * k, 0.05, M["porcelaine_capot"], n=22, what="disque")
        g.tube_shell((0, 0, z - 0.03), "z", 0.1, 0.05, 0.03, M["porcelaine"], n=14, what="jupe")
    g.sphere((0, 0, ZARC), 0.075, M["copper_pol"], what="boule")
    g.sphere((0, 0, ZARC + 0.075), 0.035, M["emit"], what="etincelle")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.15, 0.15, 0.0, 0.52, M["bleu_machine"])
    B(g, 0, L, -0.16, 0.16, 0.52, 0.58, M["porcelaine_capot"])
    for i, (a, b) in enumerate(cellules(L, n)):
        m = 0.5 * (a + b)
        g.cyl((m, -0.155, 0.26), "y", 0.07, 0.03, M["copper_pol"], n=14, what="bobine")
        g.cyl((m, -0.165, 0.26), "y", 0.035, 0.02, M["emit"], n=10, style="flat", what="arc_voyant")
        g.cyl((m, 0, 0.64), "z", 0.04, 0.1, M["porcelaine"], n=10, what="isolateur")
    g.cable((0, 0, ZARC), (L, 0, ZARC), 0.1, 0.017, M["emit"], n=6, what="arc")
