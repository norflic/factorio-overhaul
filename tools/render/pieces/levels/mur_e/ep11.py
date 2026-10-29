"""Mur · Âge 11 · Titane (ère IV). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « dents de scie, plaques de titane, aileron orange ». Poteau : prisme FACETTÉ en proue (losange), arête
d'aileron orange. Bras : plaques de titane à DENTS DE SCIE (une rampe par cellule, haute vers le poteau), sous-face
sombre. Silhouette : dentelée, anguleuse, sans courbe. Palette (ages.PALETTE[11]) : bleu titane / alliage pâle / orange.
"""
import ages
import formes as F
from corps import B, cellules

EPOQUE = 11
NOM = ages.NOMS[11]
TRIPLET = ("dents de scie", "plaques de titane", "aileron orange")
FOYER = ages.FOYER[11]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.45, 0.95, 0.42, 0.3


def matieres(metal, M):
    ages.matieres(11, metal, M)


def poteau(g, c):
    M = g.M
    F.prism(g, [(-0.04, -0.24), (0.2, 0.0), (-0.04, 0.24), (-0.22, 0.0)], 0.0, 0.5, M["titane_dk"], what="embase")
    F.prism(g, [(-0.02, -0.2), (0.17, 0.0), (-0.02, 0.2), (-0.17, 0.0)], 0.5, 1.2, M["titane_md"], what="proue")
    F.prism(g, [(0.0, -0.13), (0.1, 0.0), (0.0, 0.13), (-0.1, 0.0)], 1.2, 1.42, M["titane_cl"], what="cime")
    B(g, -0.012, 0.012, -0.19, -0.1, 0.5, 1.22, M["orange_aero"], style="flat", what="aileron")
    B(g, -0.012, 0.012, 0.1, 0.19, 0.5, 1.22, M["orange_aero"], style="flat", what="aileron")
    g.cyl((0, -0.17, 0.9), "y", 0.026, 0.02, M["emit"], n=10, style="flat", what="voyant")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.1, 0.1, 0.0, 0.3, M["bleu_nuit"])
    for i, (a, b) in enumerate(cellules(L, n)):
        g.hexa([(a, -0.15, 0.3), (b, -0.15, 0.3), (b, 0.15, 0.3), (a, 0.15, 0.3),
                (a, -0.15, 0.95), (b, -0.15, 0.55), (b, 0.15, 0.55), (a, 0.15, 0.95)],
               M["tole_ti"] if i % 2 else M["tole_ti2"], "hard", what="dent")
        B(g, a - 0.006, a + 0.006, -0.156, -0.148, 0.3, 0.95, M["orange_aero"], style="flat", what="liseré")
    B(g, 0, L, -0.152, -0.148, 0.28, 0.32, M["titane_cl"], style="flat", what="arete")
