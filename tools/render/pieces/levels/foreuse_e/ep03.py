"""Foreuse · Âge 3 · Vapeur (ère I, 3×3, niveaux 5 et 6). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « chaudière de cuivre, volant, pistons ». Une CHAUDIÈRE DE CUIVRE verticale (fût cerclé de laiton, dôme
rivé, dôme de vapeur) couvre le puits ; deux grands VOLANTS à rayons, montés en diagonale de part et d'autre (lisibles en
ellipse dans les 4 directions), sont menés par deux cylindres à PISTONS de laiton debout sur le tablier peint en vert
locomotive. Palette (ages.PALETTE[3]) : cuivre rose / vert locomotive / laiton ; lumière ambre.
"""
import math

from mathutils import Vector

import ages
import corps as cp

EPOQUE = 3
NOM = ages.NOMS[3]
TRIPLET = ("chaudière de cuivre", "volant", "pistons")
FOYER = ages.FOYER[3]
HABILLAGE = dict(ages.CORPS[3])
PIED = 1.5    # volants et pistons débordent de la chaudière


def matieres(metal, M):
    ages.matieres(3, metal, M)


def _volant(g, p, axe, R, M):
    a = Vector(axe).normalized()
    g.torus(p, a, R, 0.065, M["laiton_capot"], n=32, m=8, what="jante")
    g.torus(p, a, R - 0.07, 0.03, M["cuivre_sombre"], n=32, m=6, what="jante_int")
    g.cyl(p, a, 0.07, 0.10, M["laiton_capot"], n=12, what="moyeu")
    u = a.cross(Vector((0, 0, 1))).normalized()
    w = a.cross(u).normalized()
    for k in range(6):
        t = math.tau * k / 6
        d = u * math.cos(t) + w * math.sin(t)
        cp.poutre(g, Vector(p) + d * 0.06, Vector(p) + d * (R - 0.05), 0.04, M["cuivre_sombre"], "rayon")


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    rb = rt * 0.82
    zb = zt + 0.62 * H
    # socle de fonte et fût de la chaudière
    cp.colonne(g, 0, 0, zt, zt + 0.10, rb + 0.06, M["cuivre_sombre"], n=24, what="assise")
    cp.colonne(g, 0, 0, zt + 0.10, zb, rb, M["cuivre_capot"], n=32, what="chaudiere")
    for i in range(5):
        cp.bague(g, 0, 0, zt + 0.16 + (zb - zt - 0.2) * i / 4.0, rb, 0.035, M["laiton_capot"], ep=0.022, n=32,
                 what="cerclage")
    for i in range(4):
        z = zt + 0.3 + (zb - zt - 0.5) * i / 3.0
        for k in range(16):
            a = math.tau * (k + 0.5) / 16
            g.dome((rb * math.cos(a), rb * math.sin(a), z), (math.cos(a), math.sin(a), 0), 0.014, M["laiton_rivet"])
    # dôme rivé, dôme de vapeur et soupape
    g.sphere((0, 0, zb), rb, M["cuivre_capot"], n=32, m=12, scale=(1, 1, 0.45), what="dome")
    cp.bague(g, 0, 0, zb + 0.01, rb, 0.04, M["laiton_capot"], ep=0.02, n=32, what="ourlet")
    cp.colonne(g, 0, 0, zb + 0.2, H - 0.12, 0.16, M["laiton_capot"], n=20, what="dome_vapeur")
    g.sphere((0, 0, H - 0.12), 0.16, M["laiton_capot"], n=20, m=8, scale=(1, 1, 0.5), what="dome_vapeur")
    cp.colonne(g, 0, 0, H - 0.12, H, 0.05, M["cuivre_sombre"], n=10, what="soupape")
    # manomètre ambre sur le fût (face sud) et hublot de niveau
    g.cyl((0, -rb - 0.02, zt + 0.42 * H), (0, -1, 0), 0.1, 0.03, M["laiton_capot"], n=16, what="manometre")
    g.cyl((0, -rb - 0.04, zt + 0.42 * H), (0, -1, 0), 0.075, 0.01, M["emit"], n=16, style="flat", what="cadran")
    cp.halo(g, (0, -rb - 0.25, zt + 0.42 * H), M, 2.5)
    # deux volants en diagonale (avant), deux cylindres à pistons (arrière), bielles croisant le tablier
    for s in (-1, 1):
        px, py = s * rt * 1.05, -rt * 0.95
        zc = zt + 0.36
        _volant(g, (px, py, zc + 0.04), (1, s, 0), 0.36, M)
        g.box((px, py, zt + 0.04), (0.16, 0.16, 0.08), M["cuivre_sombre"], "hard", what="palier")
        cp.poutre(g, (px, py, zt), (px, py, zc), 0.06, M["cuivre_sombre"], "chaise")
        qx, qy = s * rt * 1.0, rt * 0.75
        cp.colonne(g, qx, qy, zt, zt + 0.42, 0.11, M["laiton_capot"], n=16, what="cylindre")
        cp.bague(g, qx, qy, zt + 0.42, 0.11, 0.04, M["cuivre_sombre"], ep=0.02, n=16, what="couvercle")
        cp.colonne(g, qx, qy, zt + 0.42, zt + 0.70, 0.03, M["steel_hi"], n=8, what="tige_piston")
        cp.poutre(g, (qx, qy, zt + 0.70), (px, py, zc + 0.2), 0.035, M["steel_hi"], "bielle")
    # conduites de vapeur cuivre de la chaudière aux cylindres
    for s in (-1, 1):
        g.pipe([(s * rb * 0.75, rb * 0.6, zt + 0.55 * H), (s * rt * 1.0, rt * 0.75, zt + 0.55 * H),
                (s * rt * 1.0, rt * 0.75, zt + 0.46)], 0.035, M["cuivre_capot"], fl_mat=M["laiton_capot"],
               bolt_mat=None, what="vapeur")


def moteur(g, c):
    """La machine à vapeur (pistons et volants) remplace le moteur électrique : à sa place, la soute à charbon."""
    M = g.M
    T = c.T["moteur"]
    mx, my = 0.42 * c.a, T["y"]
    cp.dalle(g, mx - 0.2, my - 0.16, mx + 0.2, my + 0.16, c.zt, c.zt + 0.22, M["cuivre_sombre"], what="soute")
    for (dx, dy) in ((-0.08, 0.0), (0.06, 0.04), (0.0, -0.06)):
        g.sphere((mx + dx, my + dy, c.zt + 0.23), 0.08, M["soot"], n=8, m=5, scale=(1, 1, 0.5), what="charbon")


def trepan(g, c):
    """Le trépan est dans la chaudière (sa tige sort sous le fût, invisible) : rien au puits."""
    return None


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r, M["cuivre_capot"], fl_mat=M["laiton_capot"], bolt_mat=M["laiton_rivet"], what="raccord")


def piece(g, c):
    """Sifflet de laiton à cloche et lanterne ambre, sur la soupape."""
    M = g.M
    z = c.H
    cp.colonne(g, 0, 0, z, z + 0.08, 0.08, M["cuivre_sombre"], n=12, what="embase")
    cp.colonne(g, 0, 0, z + 0.08, z + 0.38, 0.07, M["laiton_capot"], n=16, r2=0.09, what="sifflet")
    g.sphere((0, 0, z + 0.4), 0.09, M["laiton_capot"], n=16, m=8, scale=(1, 1, 0.6), what="cloche")
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        g.box((0.075 * math.cos(a), 0.075 * math.sin(a), z + 0.22), (0.02, 0.02, 0.12), M["emit"], "flat",
              what="fente")
    cp.halo(g, (0, -0.15, z + 0.25), M, 3.0)
