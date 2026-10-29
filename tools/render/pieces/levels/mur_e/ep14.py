"""Mur · Âge 14 · La Porte (ère V). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « monolithe, dalles flottantes, horizon ». Poteau : MONOLITHE d'indigo, haut et mince, filet de blanc lunaire,
étoile à son sommet. Bras : deux dalles superposées, la haute DÉCALÉE et séparée de la basse par un filet d'horizon
lumineux, tenue par de petits piliers. Palette (ages.PALETTE[14]) : indigo de nuit / blanc lunaire / étoile.
"""
import ages
import formes as F
from corps import B, cellules, tronc

EPOQUE = 14
NOM = ages.NOMS[14]
TRIPLET = ("monolithe", "dalles flottantes", "horizon")
FOYER = ages.FOYER[14]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.75, 0.95, 0.34, 0.3


def matieres(metal, M):
    ages.matieres(14, metal, M)


def poteau(g, c):
    M = g.M
    B(g, -0.2, 0.2, -0.2, 0.2, 0.0, 0.1, M["roche"])
    tronc(g, -0.16, 0.16, -0.16, 0.16, 0.1, 1.55, 0.72, M["indigo_nuit"], what="monolithe")
    B(g, -0.012, 0.012, -0.162, -0.15, 0.2, 1.4, M["blanc_lunaire"], style="flat", what="filet")
    B(g, -0.1, 0.1, -0.162, -0.152, 0.62, 0.64, M["blanc_lunaire"], style="flat", what="filet")
    F.prism(g, [(-0.07, 0.0), (0.0, -0.07), (0.07, 0.0), (0.0, 0.07)], 1.55, 1.62, M["indigo_nuit2"], what="pointe")
    g.sphere((0, 0, 1.76), 0.045, M["emit"], what="etoile")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.15, 0.15, 0.0, 0.34, M["indigo_nuit2"], what="dalle_basse")
    B(g, 0, L, -0.153, 0.153, 0.34, 0.36, M["blanc_lunaire"], what="liseré")
    B(g, 0, L, -0.1, 0.1, 0.36, 0.46, M["emit_soft"], style="flat", what="horizon")
    for i, (a, b) in enumerate(cellules(L, n)):
        m = 0.5 * (a + b)
        B(g, m - 0.02, m + 0.02, -0.12, -0.06, 0.36, 0.46, M["roche"], what="pilier")
        B(g, m - 0.02, m + 0.02, 0.06, 0.12, 0.36, 0.46, M["roche"], what="pilier")
    B(g, 0, L, -0.1, 0.18, 0.46, 0.92, M["indigo_nuit"], what="dalle_haute")
    B(g, 0, L, -0.1, 0.18, 0.92, 0.94, M["blanc_lunaire"], style="flat", what="arete")
    for k in range(3):
        g.sphere((L * (0.25 + 0.25 * k), -0.103, 0.46 + 0.1 + 0.12 * (k % 2)), 0.014, M["emit"], n=6, m=4, what="etoile")
