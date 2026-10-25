"""Foreuse · Âge 8 · Marais (ère III, 5×5, niveaux 15 et 16). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « bocal de verre, boue jaune, ponton ». Foreuse à BOUE : un grand BOCAL DE VERRE (cylindre de verre toxique
cerclé de cuivre vert-de-gris, couvercle à pompe) plein de BOUE JAUNE lumineuse où montent des bulles couvre le puits ;
des gaines de caoutchouc l'alimentent ; le tablier est un PONTON de planches mouillées porté par des pieux de bois
(les montants) ; deux bonbonnes de verre à l'arrière. Palette (ages.PALETTE[8]) : vert-de-gris / bois mouillé et cuivre
terni / verre toxique ; lumière jaune toxique.
"""
import math

import ages
import corps as cp

EPOQUE = 8
NOM = ages.NOMS[8]
TRIPLET = ("bocal de verre", "boue jaune", "ponton")
FOYER = ages.FOYER[8]
HABILLAGE = dict(ages.CORPS[8])


def matieres(metal, M):
    ages.matieres(8, metal, M)


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    rb = rt * 0.86
    z0, z1 = zt + 0.14, zt + 0.68 * H
    cp.colonne(g, 0, 0, zt, z0, rb + 0.08, M["vdg_capot"], n=32, what="embase")
    # le verre est opaque au rendu (verre_toxique : matière brillante) : la boue lumineuse occupe les 2/3 bas du bocal,
    # le verre vide le tiers haut (ménisque cerclé)
    zl = z0 + (z1 - z0) * 0.64
    cp.colonne(g, 0, 0, z0, zl, rb, M["emit_soft"], n=32, style="flat", what="boue")
    cp.colonne(g, 0, 0, zl, z1, rb, M["verre_toxique"], n=32, what="bocal")
    cp.bague(g, 0, 0, zl, rb, 0.03, M["emit"], ep=0.012, n=32, what="menisque")
    for i in range(7):
        a = 1.3 * i
        r = 0.05 + 0.02 * (i % 3)
        g.sphere((rb * 0.99 * math.cos(a), rb * 0.99 * math.sin(a), z0 + 0.2 + 0.25 * i), r, M["reflet_verre"], n=10,
                 m=6, what="bulle")
    for i in range(4):
        cp.bague(g, 0, 0, z0 + (z1 - z0) * (0.12 + 0.25 * i), rb, 0.05, M["cuivre_terni"], ep=0.025, n=32,
                 what="cerclage")
    for (x, y) in cp.sym4((rb * 0.72, rb * 0.72)):
        cp.poutre(g, (x, y, zt), (x, y, z1 + 0.02), 0.06, M["vdg_capot"], "montant_bocal")
    # couvercle bombé vert-de-gris, pompe et col
    g.sphere((0, 0, z1), rb + 0.05, M["vdg_capot"], n=32, m=12, scale=(1, 1, 0.32), what="couvercle")
    cp.colonne(g, 0, 0, z1 + 0.12, H - 0.25, 0.22, M["cuivre_terni"], n=16, what="pompe")
    cp.bague(g, 0, 0, H - 0.4, 0.22, 0.05, M["vdg_capot"], ep=0.03, n=16, what="collier")
    cp.colonne(g, 0, 0, H - 0.25, H, 0.10, M["vdg_capot"], n=12, what="col")
    cp.halo(g, (0, -rb - 0.3, z0 + 0.6), M, 6.0)
    cp.halo(g, (0, -rb - 0.3, z1 - 0.4), M, 4.0)


def trepan(g, c):
    return None


def montant(g, c, x, y):
    """Pieu de bois mouillé, cerclé de cuivre, qui descend sous le ponton."""
    M = g.M
    r = c.T["montant"]["w"] * 0.62
    cp.colonne(g, x, y, 0.0, c.T["montant"]["h"] + 0.12, r, M["bois_mouille"], n=10, what="pieu")
    cp.bague(g, x, y, c.T["montant"]["h"] - 0.05, r, 0.05, M["cuivre_terni"], ep=0.02, n=10, what="frette")
    g.sphere((x, y, c.T["montant"]["h"] + 0.12), r, M["bois_mousse"], n=10, m=5, scale=(1, 1, 0.5), what="tete_pieu")


def socle(g, c):
    M = g.M
    a, zt = c.a, c.zt
    # bonbonnes de boue (arrière gauche), gaines de caoutchouc vers le bocal
    for i, (x, y) in enumerate(((-a * 0.62, -a * 0.6), (-a * 0.25, -a * 0.72))):
        cp.colonne(g, x, y, zt, zt + 0.28, 0.2, M["emit_soft"], n=16, style="flat", what="boue_b")
        cp.colonne(g, x, y, zt + 0.28, zt + 0.42, 0.2, M["verre_toxique"], n=16, what="bonbonne")
        g.sphere((x, y, zt + 0.42), 0.2, M["verre_toxique"], n=16, m=8, scale=(1, 1, 0.5), what="epaule")
        cp.colonne(g, x, y, zt + 0.48, zt + 0.58, 0.07, M["cuivre_terni"], n=10, what="goulot")
        g.hose([(x, y, zt + 0.58), (x * 0.7, y * 0.7 + 0.1, zt + 0.7), (-c.rt * 0.55, -c.rt * 0.55, zt + 0.5)], 0.035,
               M["rubber"])
    # nappe de boue jaune qui déborde du puits côté avant
    g.cyl((c.rt * 0.2, -c.rt * 0.95, zt + 0.006), "z", 0.28, 0.012, M["emit_soft"], n=14, style="flat", what="flaque")


def liaison(g, pts, r):
    M = g.M
    g.hose(pts, r * 1.05, M["rubber"])
    g.cyl(pts[0], (pts[1][0] - pts[0][0], pts[1][1] - pts[0][1], 0.0001), r * 1.5, 0.06, M["cuivre_terni"], n=14,
          style="hard", what="bride")


def piece(g, c):
    """Ampoule de verre à boue jaune et cage de cuivre, sur le col de la pompe."""
    M = g.M
    z = c.H
    cp.colonne(g, 0, 0, z, z + 0.06, 0.12, M["cuivre_terni"], n=12, what="culot")
    g.sphere((0, 0, z + 0.24), 0.19, M["emit"], n=20, m=10, what="boue")
    g.sphere((0, 0, z + 0.30), 0.2, M["verre_toxique"], n=20, m=10, scale=(1, 1, 0.75), what="ampoule")
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        g.tube([(0.12 * math.cos(a), 0.12 * math.sin(a), z + 0.06), (0.21 * math.cos(a), 0.21 * math.sin(a), z + 0.26),
                (0.0, 0.0, z + 0.47)], 0.014, M["cuivre_terni"], n=6, what="cage")
    cp.halo(g, (0, -0.25, z + 0.25), M, 4.0)
