"""CONCENTRATEUR DE MINERAI (fo-ore-concentrator), 2×2 (x ±1 ; y ±1,41). CONCEPT §6.

Trois idées de la même fonction (enrichir le minerai brut versé par la foreuse accolée) :
A cellules de FLOTTATION : deux cuves à écume grise qui déborde dans la goulotte sud, moteurs d'agitateurs sur pont, hydrocyclone ;
B TABLE À SECOUSSES (Wilfley) : plateau en diagonale à rifles, éventail de bandes (concentré sombre, mixte, stérile clair), mécanisme ;
C SPIRALES : quatre hélices sur un bâti, répartiteur au sommet, goulottes au pied.
Feu de travail ambré sur l'armoire (D2) ; le concentré sort au SUD.
"""
import math

import commun as K
import geo as G
import outils as O

TAU = G.TAU
PALETTE = "minerai"            # commun.PALETTES ; « calcul » = palette des états clés du 3/11


def socle(lot, M):
    lot.put(M["beton"], G.prisme([(-0.97, -1.37), (0.97, -1.37), (0.97, 1.37), (-0.97, 1.37)], 0.0, 0.06))
    K.chevrons(lot, M, -0.95, 0.95, -1.33, 0.06, 0.05)


def goulotte_sud(lot, M, rnd, x=0.0):
    """Goulotte de concentré qui sort au sud, trémie et tas de concentré."""
    K.rev(lot, M["acier"], x, -1.05, [(0.06, 0.06), (0.32, 0.2), (0.42, 0.2)], 4, cap=False)
    lot.put(M["noir"], G.boite((x, -1.05, 0.4), (0.26, 0.26, 0.01)))
    K.tas(lot, M["minerai"], (x, -1.05, 0.36), 0.12, 0.12, 0.05, rnd, 12, 0.018, 0.03)
    for s in (-1, 1):
        lot.put(M["acier2"], G.tube([(x + s * 0.17, -1.22, 0.06), (x + s * 0.17, -1.22, 0.38)], 0.014, 4))


def flottation(lot, M, rnd):
    for xc in (-0.45, 0.45):
        y0, y1, zt = -0.55, 1.15, 0.72
        K.caisson(lot, M["acier"], xc, (y0 + y1) / 2, 0.06, 0.82, y1 - y0, zt - 0.06, 0.02)
        for k in range(5):
            y = y0 + 0.1 + k * (y1 - y0 - 0.2) / 4
            for s in (-1, 1):
                lot.put(M["acier2"], G.boite((xc + s * 0.42, y, 0.4), (0.03, 0.05, 0.66)))
        # écume : surface et grappes de bulles grises
        lot.put(M["ecume"], G.boite((xc, (y0 + y1) / 2 + 0.05, zt - 0.01), (0.74, y1 - y0 - 0.15, 0.02)))
        for k in range(55):
            p = (xc + rnd.f(-0.34, 0.34), rnd.f(y0 + 0.05, y1 - 0.08), zt + 0.01)
            lot.put(M["ecume"], G.sphere(p, rnd.f(0.022, 0.045), 7, 3, zmin=0.0))
        # lèvre de débordement et goulotte inclinée vers le centre sud
        lot.put(M["acier2"], G.boite((xc, y0 - 0.02, zt + 0.02), (0.8, 0.04, 0.05)))
        a, b = (xc, y0 - 0.13, zt - 0.08), (0.0, y0 - 0.2, zt - 0.2)
        lot.put(M["acier"], G.boite(G.lerp(a, b, 0.5), (0.86, 0.18, 0.04)))
        lot.put(M["ecume"], G.boite(G.add(G.lerp(a, b, 0.5), (0, 0, 0.025)), (0.78, 0.12, 0.01)))
        # pont, moteur d'agitateur, carter de courroie
        lot.put(M["jaune"], G.boite((xc, 0.4, zt + 0.12), (0.84, 0.08, 0.06)))
        lot.put(M["jaune"], G.boite((xc, 0.62, zt + 0.12), (0.84, 0.08, 0.06)))
        K.rev(lot, M["acier2"], xc, 0.51, [(zt + 0.15, 0.13), (zt + 0.25, 0.13), (zt + 0.27, 0.1)], 20)
        K.rev(lot, M["bleu"], xc, 0.51, [(zt + 0.27, 0.12), (zt + 0.62, 0.12), (zt + 0.66, 0.08)], 24)
        for k in range(12):
            a2 = TAU * k / 12
            lot.put(M["bleu"], G.boite((xc + 0.125 * math.cos(a2), 0.51 + 0.125 * math.sin(a2), zt + 0.45), (0.02, 0.02, 0.32), a2))
        K.rev(lot, M["noir"], xc, 0.51, [(zt + 0.66, 0.06), (zt + 0.7, 0.04)], 12)
        lot.put(M["jaune"], G.boite((xc + 0.18, 0.51, zt + 0.42), (0.1, 0.28, 0.32)))
        K.rev(lot, M["acier_clair"], xc, 0.51, [(zt - 0.02, 0.025), (zt + 0.16, 0.025)], 8)
    # hydrocyclone au nord-ouest, conduite d'alimentation depuis le nord
    hx, hy = -0.7, 1.22
    K.rev(lot, M["caoutchouc"], hx, hy, [(0.95, 0.025), (1.45, 0.11), (1.6, 0.11), (1.65, 0.06)], 16)
    for s in (-1, 1):
        lot.put(M["acier2"], G.tube([(hx + s * 0.14, hy, 0.06), (hx + s * 0.12, hy, 1.5)], 0.016, 4))
    O.tuyau(lot, M["acier_clair"], M["acier2"], [(hx, hy, 1.65), (hx, hy, 1.78), (-0.45, hy - 0.2, 1.78), (-0.45, 0.95, 0.9)], 0.03, rb=0.08, pas_bride=2.0)
    O.tuyau(lot, M["caoutchouc"], M["acier2"], [(hx + 0.11, hy, 1.5), (hx + 0.3, 1.36, 1.5), (hx + 0.3, 1.36, 0.06)], 0.035, rb=0.08, pas_bride=2.0)
    # soufflante à air au nord-est
    K.caisson(lot, M["acier2"], 0.72, 1.18, 0.06, 0.3, 0.26, 0.22, 0.02)
    lot.put(M["bleu"], G.tour([(1.05, 0.12), (1.31, 0.12)], 18, "y", (0.72, 0.0, 0.42), cap0=True, cap1=True))
    O.tuyau(lot, M["acier_clair"], M["acier2"], [(0.72, 1.2, 0.55), (0.72, 1.2, 1.2), (0.45, 0.51, 1.2), (-0.45, 0.51, 1.2)], 0.025, rb=0.06, pas_bride=2.0)
    for xc in (-0.45, 0.45):
        lot.put(M["acier_clair"], G.tube([(xc, 0.51, 1.2), (xc, 0.51, 1.4)], 0.022, 5))
    K.armoire(lot, M, 0.72, -0.85, 0.06, 0.3, 0.18, 0.42)


def table(lot, M, rnd):
    ang = math.radians(-14.0)
    c = (-0.05, 0.12, 0.55)
    L, W = 1.55, 1.3

    def P(u, v, dz=0.0):
        """Point du plateau : u le long (0 tête, 1 bout), v en travers (0 alimentation, 1 décharge) ; pente vers le sud."""
        x = (u - 0.5) * L
        y = (0.5 - v) * W
        p = G.rot_z((x, y, 0.0), ang)
        return (c[0] + p[0], c[1] + p[1], c[2] + dz - v * 0.12 + u * 0.03)

    q = [P(0, 0), P(1, 0), P(1, 1), P(0, 1)]
    lot.put(M["vert"], G.merge((q, [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)]), G.loft([q + [q[0]], [G.add(p, (0, 0, -0.05)) for p in q + [q[0]]]], closed=False)))
    # bandes de minerai en éventail : concentré sombre, mixte, stérile clair
    for (v0, v1, mat, u0) in ((0.05, 0.35, "minerai", 0.45), (0.35, 0.6, "coke", 0.2), (0.6, 0.95, "sable", 0.0)):
        for k in range(12):
            u = u0 + (1.0 - u0) * k / 12.0
            u2 = u + (1.0 - u0) / 12.0
            vv0 = v0 + (v1 - v0) * 0.3 * (1 - u)
            sq = [P(u, vv0, 0.012), P(u2, vv0, 0.012), P(u2, v1, 0.012), P(u, v1, 0.012)]
            lot.put(M[mat], (sq, [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)]))
    for i in range(10):
        v = 0.06 + i * 0.085
        lot.put(M["acier_clair"], G.tube([P(0.03, v, 0.02), P(0.95 - 0.5 * v, v, 0.02)], 0.008, 4))
    # bâti, mécanisme à secousses (tête, est), moteur et courroie
    for (u, v) in ((0.05, 0.1), (0.95, 0.1), (0.05, 0.9), (0.95, 0.9)):
        p = P(u, v, -0.05)
        lot.put(M["acier2"], G.boite((p[0], p[1], p[2] / 2 + 0.03), (0.06, 0.06, p[2])))
    h = P(-0.02, 0.5)
    K.caisson(lot, M["jaune"], h[0] - 0.1, h[1], 0.06, 0.26, 0.42, 0.62, 0.02)
    K.rev(lot, M["bleu"], h[0] - 0.12, h[1] + 0.46, [(0.06, 0.13), (0.4, 0.13), (0.42, 0.09)], 18)
    lot.put(M["noir"], G.tube([(h[0] - 0.12, h[1] + 0.46, 0.35), (h[0] - 0.1, h[1] + 0.1, 0.55)], 0.025, 6))
    lot.put(M["acier_clair"], G.tube([(h[0] + 0.03, h[1], 0.5), P(0.02, 0.5, 0.0)], 0.03, 6))
    # boîte d'alimentation (nord-est) et rampe d'eau de lavage
    f = P(0.12, -0.02)
    K.caisson(lot, M["acier"], f[0], f[1] + 0.1, f[2] + 0.05, 0.42, 0.18, 0.18, 0.02)
    K.tas(lot, M["minerai"], (f[0], f[1] + 0.1, f[2] + 0.22), 0.14, 0.06, 0.03, rnd, 8, 0.015, 0.025)
    lot.put(M["acier_clair"], G.tube([P(0.25, -0.03, 0.12), P(0.95, -0.03, 0.12)], 0.016, 6))
    for k in range(8):
        a = P(0.3 + k * 0.08, -0.03, 0.1)
        lot.put(M["acier_clair"], G.tube([a, G.add(a, (0.0, -0.05, -0.08))], 0.005, 3))
    # goulottes de décharge (sud et ouest) à séparateurs ; concentré vers le sud
    lot.put(M["acier"], G.tube([P(0.0, 1.06, -0.04), P(1.05, 1.06, -0.1)], 0.06, 8))
    lot.put(M["acier"], G.tube([P(1.06, 0.0, -0.04), P(1.06, 1.06, -0.1)], 0.06, 8))
    for u in (0.35, 0.65):
        lot.put(M["acier2"], G.boite(P(u, 1.06, -0.02), (0.02, 0.14, 0.1), ang))
    goulotte_sud(lot, M, rnd, -0.45)
    K.armoire(lot, M, 0.72, -0.95, 0.06, 0.28, 0.18, 0.42)
    # répartiteur d'alimentation au nord : bac sur pieds, goulotte vers la boîte d'alimentation, conduite d'eau
    K.caisson(lot, M["acier"], 0.55, 1.12, 0.62, 0.5, 0.3, 0.26, 0.02)
    K.tas(lot, M["minerai"], (0.55, 1.12, 0.86), 0.2, 0.1, 0.05, rnd, 14, 0.018, 0.03)
    for (dx, dy) in ((-0.22, -0.12), (0.22, -0.12), (-0.22, 0.12), (0.22, 0.12)):
        lot.put(M["acier2"], G.tube([(0.55 + dx, 1.12 + dy, 0.06), (0.55 + dx, 1.12 + dy, 0.62)], 0.016, 4))
    lot.put(M["acier"], G.tube([(0.4, 0.98, 0.7), (f[0] + 0.1, f[1] + 0.12, f[2] + 0.22)], 0.05, 8))
    O.tuyau(lot, M["bleu"], M["acier2"], [(-0.95, 1.3, 0.3), (-0.6, 1.3, 0.3), (-0.6, 1.3, 0.82), P(0.25, -0.03, 0.12)], 0.025, rb=0.06, pas_bride=2.0)
    # passerelle et garde-corps à l'ouest, pour le réglage des séparateurs
    lot.put(M["acier2"], G.boite((-0.85, 0.0, 0.3), (0.2, 2.2, 0.03)))
    for y in (-1.0, -0.3, 0.4, 1.1):
        lot.put(M["acier2"], G.tube([(-0.85, y, 0.06), (-0.85, y, 0.3)], 0.014, 4))
    K.rambarde(lot, M["jaune"], [(-0.95, -1.05), (-0.95, 1.15)], 0.31, 0.24, 0.3)
    # seconde table, au-dessous (installation à deux étages) : on n'en voit que le bord et les rifles
    for k in range(6):
        a = P(0.1 + k * 0.15, 1.18, -0.3)
        lot.put(M["vert"], G.boite(a, (0.14, 0.05, 0.02), ang))


def spirale(lot, M, cx, cy, z0, z1, tours=4.5, r0=0.06, r1=0.24):
    n = int(tours * 28)
    inner, outer, rim = [], [], []
    for i in range(n + 1):
        t = i / float(n)
        a = TAU * tours * t
        z = z1 - (z1 - z0) * t
        c, s = math.cos(a), math.sin(a)
        inner.append((cx + r0 * c, cy + r0 * s, z))
        outer.append((cx + r1 * c, cy + r1 * s, z - 0.03))
        rim.append((cx + r1 * c, cy + r1 * s, z + 0.02))
    lot.put(M["jaune"], G.loft([inner, outer], closed=False))
    lot.put(M["jaune"], G.tube(rim, 0.014, 5))
    mid = [G.lerp(a, b, 0.4) for a, b in zip(inner, outer)]
    lot.put(M["minerai"], G.loft([[G.add(p, (0, 0, 0.004)) for p in inner[4:]], [G.add(p, (0, 0, 0.004)) for p in mid[4:]]], closed=False))
    K.rev(lot, M["acier_clair"], cx, cy, [(z0 - 0.15, 0.045), (z1 + 0.12, 0.045)], 10)


def spirales(lot, M, rnd):
    z0, z1 = 0.42, 1.85
    pos = [(-0.45, -0.25), (0.45, -0.25), (-0.45, 0.62), (0.45, 0.62)]
    for (x, y) in pos:
        spirale(lot, M, x, y, z0, z1)
        K.caisson(lot, M["acier"], x, y, 0.06, 0.34, 0.34, 0.3, 0.02)
        lot.put(M["minerai"], G.boite((x, y, 0.355), (0.24, 0.24, 0.01)))
    # bâti : 4 poteaux, poutres, plancher haut, garde-corps
    for (x, y) in ((-0.88, -0.6), (0.88, -0.6), (-0.88, 1.0), (0.88, 1.0)):
        lot.put(M["acier2"], G.boite((x, y, 1.05), (0.06, 0.06, 2.0)))
    for z in (1.0, 2.02):
        for y in (-0.6, 1.0):
            lot.put(M["acier2"], G.boite((0.0, y, z), (1.8, 0.05, 0.06)))
        for x in (-0.88, 0.88):
            lot.put(M["acier2"], G.boite((x, 0.2, z), (0.05, 1.65, 0.06)))
    lot.put(M["acier"], G.boite((0.0, 0.2, 2.07), (1.8, 0.4, 0.03)))
    K.rambarde(lot, M["jaune"], [(-0.88, 0.0), (0.88, 0.0)], 2.08, 0.2, 0.3)
    # répartiteur : bac central et 4 tuyaux souples
    K.rev(lot, M["acier"], 0.0, 0.2, [(2.08, 0.1), (2.3, 0.2), (2.4, 0.2)], 16, cap=False)
    lot.put(M["minerai"], G.tour([(2.36, 0.19), (2.37, 0.0)], 16, "z", (0.0, 0.2, 0.0)))
    for (x, y) in pos:
        O.flexible(lot, M["caoutchouc"], [(0.0 + 0.6 * x * 0.25, 0.2 + (y - 0.2) * 0.25, 2.12), ((x * 0.6), (y + 0.2) / 2, 2.0), (x, y, z1 + 0.05)], 0.02)
    # goulottes au pied vers le sud
    lot.put(M["acier"], G.tube([(-0.6, -0.55, 0.25), (0.6, -0.55, 0.25)], 0.06, 8))
    goulotte_sud(lot, M, rnd, 0.0)
    K.armoire(lot, M, 0.72, 1.2, 0.06, 0.3, 0.16, 0.42)


def build(S, lot, v):
    M = K.matieres(S, PALETTE)
    rnd = G.Rnd(8808)
    socle(lot, M)
    if v == "a":
        flottation(lot, M, rnd)
        goulotte_sud(lot, M, rnd, 0.0)
    elif v == "b":
        table(lot, M, rnd)
    else:
        spirales(lot, M, rnd)
    return {}
