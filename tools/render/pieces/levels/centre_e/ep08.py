"""Centre de commandement · Âge 8 · Marais (6×6, niveau 8). Lot F5-A (27/10), ronde 1. S'exécute DANS Blender.

« pilotis, serre, bocal vert » : maison de bois mouillé et de vert-de-gris, galerie sur pilotis, toit à deux
pans, grand bocal vert lumineux et sa serre sur le faîte.
"""
import math

import ages
import corps as cp

EPOQUE = 8
NOM = ages.NOMS[8]
TRIPLET = ('pilotis', 'serre', 'bocal vert')
FOYER = ages.FOYER[8]
HABILLAGE = dict(ages.CORPS[8], plan="carre", etages=2, toit="pans", mat_e1="bois_mouille", mat_e2="vdg_capot",
                 mat_toit="vdg_capot")


def matieres(metal, M):
    ages.matieres(8, metal, M)

def facade(g, c):
    """Pilotis : pieux sous la galerie avant du premier étage."""
    M = g.M
    h1 = c.T["h"][0]
    w = c.T["porte"]["w"] / 2 + 0.12
    t = -h1
    while t <= h1:
        if abs(t) > w:
            cp.colonne(g, t, -h1 - 0.16, c.zt, c.zt + 0.45, 0.04, M["bois_mouille"], n=8, what="pieu")
        t += 0.32
    cp.dalle(g, -h1, -h1 - 0.22, h1, -h1, c.zt + 0.42, c.zt + 0.47, M["bois_mousse"], what="galerie")


def mat(g, c, z):
    M = g.M
    cp.dalle(g, -0.32, -0.22, 0.32, 0.22, z - 0.08, z + 0.05, M["vdg_capot"], what="caisson_serre")
    cp.colonne(g, 0, 0, z + 0.05, z + 0.55, 0.22, M["verre_toxique"], n=24, what="bocal")
    cp.colonne(g, 0, 0, z + 0.07, z + 0.35, 0.226, M["emit"], n=24, what="liquide")
    cp.colonne(g, 0, 0, z + 0.55, z + 0.62, 0.24, M["cuivre_terni"], n=24, style="hard", what="couvercle")
    cp.colonne(g, 0, 0, z + 0.62, z + 1.05, 0.02, M["cuivre_terni"], n=6, what="antenne")
    g.dome((0, 0, z + 1.05), (0, 0, 1), 0.035, M["emit"], what="feu_antenne")
    cp.halo(g, (0, -0.35, z + 0.25), M, 3.0)
