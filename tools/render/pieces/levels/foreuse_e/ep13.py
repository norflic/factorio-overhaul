"""Foreuse · Âge 13 · Antimatière (ère V, 6×6, niveaux 25 et 26). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « bobinages, bouteilles couchées, puits violet ». Le trépan est enfermé dans une colonne de BOBINAGES de cuivre
rouge (spires serrées en 4 bobines) tenue par 4 montants d'acier canon ; quatre BOUTEILLES magnétiques COUCHÉES en X
sur les diagonales (fût d'acier canon, bagues de cuivre, fente violette) ; le PUITS VIOLET (annihilation au
fond) brille par la margelle. La lumière est enfermée EN POINTS (ère V). Palette (ages.PALETTE[13]) : acier canon / cuivre
rouge des bobinages / violet et bleu d'annihilation.
"""
import math

import ages
import corps as cp

EPOQUE = 13
NOM = ages.NOMS[13]
TRIPLET = ("bobinages", "bouteilles couchées", "puits violet")
FOYER = ages.FOYER[13]
HABILLAGE = dict(ages.CORPS[13])


def matieres(metal, M):
    ages.matieres(13, metal, M)


def _bouteille(g, p, axe, L, r, M):
    x, y, z = p
    g.cyl(p, axe, r, L, M["acier_canon"], n=24, what="bouteille")
    for s in (-1, 1):
        g.sphere((x + axe[0] * s * L / 2, y + axe[1] * s * L / 2, z), r, M["acier_canon2"], n=20, m=10,
                 what="calotte")
    for t in (-0.32, -0.12, 0.12, 0.32):
        g.tube_shell((x + axe[0] * t * L, y + axe[1] * t * L, z), axe, r * 1.12, r * 0.95, 0.06, M["cuivre_bobine"],
                     n=24, what="bague")
    g.box((x, y, z + r * 0.98), (0.05 + abs(axe[0]) * L * 0.25, 0.05 + abs(axe[1]) * L * 0.25, 0.02), M["emit"], "flat",
          what="fente")
    cp.halo(g, (x, y - 0.2, z + r + 0.1), M, 2.5)


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    zb0, zb1 = zt + 0.18, zt + 0.86 * H
    rb = rt * 0.48
    # 4 montants d'acier canon et socle
    cp.colonne(g, 0, 0, zt, zb0, rt * 0.7, M["acier_noir"], n=8, phase=math.pi / 8, style="hard", what="socle")
    for (x, y) in cp.sym4((rb * 1.15, rb * 1.15)):
        cp.dalle(g, x - 0.09, y - 0.09, x + 0.09, y + 0.09, zb0, zb1 + 0.1, M["acier_canon"], what="montant")
    # 4 bobines de spires serrées
    nb = 4
    hb = (zb1 - zb0) / nb
    for i in range(nb):
        z0 = zb0 + hb * i
        cp.colonne(g, 0, 0, z0, z0 + 0.05, rb * 1.08, M["acier_canon2"], n=24, what="joue")
        n_sp = 7
        for j in range(n_sp):
            g.torus((0, 0, z0 + 0.08 + (hb - 0.12) * (j + 0.5) / n_sp), "z", rb, (hb - 0.12) / n_sp * 0.55,
                    M["cuivre_bobine"], n=32, m=6, what="spire")
        g.sphere((rb * 1.02, -rb * 0.3, z0 + hb * 0.5), 0.035, M["emit2"], n=8, m=4, what="point")
    cp.colonne(g, 0, 0, zb0, zb1, rb * 0.85, M["acier_noir"], n=24, what="noyau")
    cp.colonne(g, 0, 0, zb1, zb1 + 0.1, rb * 1.3, M["acier_canon"], n=8, phase=math.pi / 8, style="hard", what="chapeau")
    cp.colonne(g, 0, 0, zb1 + 0.1, H, 0.12, M["chrome_fin"], n=16, what="sommet")
    # 4 bouteilles couchées sur les diagonales (en X : les raccords de fluide et la goulotte restent libres)
    L, r = rt * 0.6, 0.17
    for k in range(4):
        cx, cy = cp.quart((rt * 0.87, rt * 0.87), k)[:2]
        ax = cp.quart((0.7071, 0.7071), k)[:2]
        _bouteille(g, (cx, cy, zt + r + 0.08), (ax[0], ax[1], 0.0), L, r, M)
        for t in (-0.3, 0.3):
            g.box((cx + ax[0] * t * L, cy + ax[1] * t * L, zt + 0.06), (0.14, 0.14, 0.12), M["acier_noir"], "hard",
                  what="berceau")


def trepan(g, c):
    """Puits violet : margelle doublée d'un anneau d'annihilation, cœur lumineux au fond."""
    M = g.M
    zt, rw = c.zt, c.rw
    g.cyl((0, 0, zt + 0.012), "z", rw * 0.75, 0.01, M["emit"], n=32, style="flat", what="fond_violet")
    cp.bague(g, 0, 0, zt + 0.05, rw * 0.95, 0.04, M["emit2"], ep=0.025, n=32, what="anneau")
    cp.halo(g, (0, -rw - 0.2, zt + 0.2), M, 4.0)


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r, M["acier_canon"], fl_mat=M["cuivre_plaque"], bolt_mat=M["chrome_fin"], what="raccord")


def piece(g, c):
    """Petite bouteille magnétique debout (point violet) entre deux bobines, sur le sommet."""
    M = g.M
    z = c.H
    cp.colonne(g, 0, 0, z, z + 0.42, 0.11, M["acier_canon"], n=20, what="fut")
    g.sphere((0, 0, z + 0.42), 0.11, M["acier_canon2"], n=20, m=8, what="calotte")
    for zz in (z + 0.1, z + 0.32):
        g.torus((0, 0, zz), "z", 0.14, 0.035, M["cuivre_bobine"], n=24, m=6, what="bobine")
    g.box((0, -0.11, z + 0.21), (0.05, 0.01, 0.1), M["emit"], "flat", what="point")
    g.sphere((0, 0, z + 0.55), 0.05, M["emit2"], n=10, m=5, what="point2")
    cp.halo(g, (0, -0.2, z + 0.3), M, 3.0)
