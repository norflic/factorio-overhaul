"""Mur · Âge 15 · Néant (ère V). Lot F6 (29/10). S'exécute DANS Blender.
En 3 mots : « éclat d'obsidienne, arête lame, fissure d'or ». Poteau : grand ÉCLAT d'obsidienne noire, penché, mince et
anguleux, goutte d'or en fusion au pied. Bras : LAME couchée à arête vive (prisme triangulaire, arête en haut) fendue d'une
fissure d'or incandescent, tessons dressés. Palette (ages.PALETTE[15]) : noir chaud / or chauffé / incandescence.
"""
import ages
import formes as F
from corps import B, alea, cellules

EPOQUE = 15
NOM = ages.NOMS[15]
TRIPLET = ("éclat d'obsidienne", "arête lame", "fissure d'or")
FOYER = ages.FOYER[15]
HAUT_POTEAU, HAUT_BRAS, LARG_POTEAU, LARG_BRAS = 1.7, 0.85, 0.4, 0.34


def matieres(metal, M):
    ages.matieres(15, metal, M)


def poteau(g, c):
    M = g.M
    g.cyl((0, 0, 0.04), "z", 0.27, 0.08, M["noir_profond"], n=9, style="soft", what="assise")
    # éclat principal : fût à 5 pans qui s'effile et penche
    g.cyl((0.03, 0.0, 0.7), "z", 0.17, 1.3, M["noir_chaud"], n=5, r2=0.03, what="eclat", style="hard")
    g.cyl((-0.12, 0.08, 0.4), "z", 0.1, 0.76, M["noir_chaud2"], n=5, r2=0.018, what="eclat2", style="hard")
    g.cyl((0.13, -0.1, 0.3), "z", 0.085, 0.56, M["noir_chaud"], n=5, r2=0.014, what="eclat3", style="hard")
    B(g, 0.015, 0.045, -0.185, -0.165, 0.1, 1.1, M["emit"], style="flat", what="fissure")
    g.sphere((0.03, -0.16, 0.14), 0.05, M["emit2"], what="goutte")
    B(g, -0.08, 0.08, -0.262, -0.25, 0.04, 0.07, M["or_chauffe"], style="flat", what="liseré_or")


def bras(g, c, L, n):
    M = g.M
    B(g, 0, L, -0.16, 0.16, 0.0, 0.08, M["noir_profond"], what="assise")
    # lame couchée : prisme triangulaire, arête en haut
    g.hexa([(0, -0.15, 0.08), (L, -0.15, 0.08), (L, 0.15, 0.08), (0, 0.15, 0.08),
            (0, -0.012, 0.8), (L, -0.012, 0.8), (L, 0.012, 0.8), (0, 0.012, 0.8)], M["noir_chaud"], "hard", what="lame")
    B(g, 0, L, -0.008, 0.008, 0.76, 0.82, M["emit2"], style="flat", what="arete_or")
    B(g, 0, L, -0.158, -0.14, 0.2, 0.26, M["emit"], style="flat", what="fissure")
    for i, (a, b) in enumerate(cellules(L, n)):
        m = 0.5 * (a + b)
        h = alea(g, 0.12, 0.3)
        F.crystal(g, (m, alea(g, -0.06, 0.06), 0.76), (alea(g, -0.2, 0.2), 0.0, 1.0), 0.04, h, M["noir_chaud2"], tip=0.5,
                  n=4, what="tesson")
