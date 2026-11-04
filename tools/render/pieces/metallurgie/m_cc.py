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
    """Table de Wilfley (v2, critique du 3/11) : tête à secousses et alimentation au NORD-EST, surélevées ; pente vers le sud ;
    trois bandes nettes en éventail (concentré graphite à l'ouest, mixtes rouille, gangue sable au sud-est), pellicule d'eau au
    nord, rifles sombres ; fenêtre d'armoire et gyrophare ambrés (lueur ≥ 0,10 tuile²)."""
    ang = math.radians(-14.0)
    c = (-0.1, 0.08, 0.55)
    L, W = 1.4, 1.15
    D_ = K.D

    def P(u, v, dz=0.0):
        """u : 0 à la tête (EST) → 1 au bout (OUEST) ; v : 0 au bord d'alimentation (NORD) → 1 au bord de décharge (SUD)."""
        p = G.rot_z(((0.5 - u) * L, (0.5 - v) * W, 0.0), ang)
        return (c[0] + p[0], c[1] + p[1], c[2] + dz - v * 0.13 + u * 0.03)

    def quad(mat, u0, v0, u1, v1, dz):
        sq = [P(u0, v0, dz), P(u1, v0, dz), P(u1, v1, dz), P(u0, v1, dz)]
        lot.put(M[mat], (sq, [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)]))

    q = [P(0, 0), P(1, 0), P(1, 1), P(0, 1)]
    lot.put(M["vert"], G.merge((q, [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)]),
                               G.loft([q + [q[0]], [G.add(p, (0, 0, -0.06)) for p in q + [q[0]]]], closed=False)))
    # bandes : secteurs vus depuis le point d'alimentation (coin nord-est)
    nu, nv = 14, 11
    fu, fv = 0.06, 0.06
    for i in range(nu):
        for j in range(nv):
            u0, u1 = i / float(nu), (i + 1) / float(nu)
            v0, v1 = j / float(nv), (j + 1) / float(nv)
            uc, vc = (u0 + u1) / 2, (v0 + v1) / 2
            du, dv = (uc - fu) * L, (vc - fv) * W * D_ / D_
            d = math.hypot(du, dv)
            t = math.atan2(dv, du)
            if vc < 0.2:
                continue                                   # pellicule d'eau, posée plus bas
            if d < 0.3:
                mat = "minerai"
            elif t < 0.5:
                mat = "graphite"
            elif t < 0.95:
                mat = "rouille"
            else:
                mat = "sable"
            quad(mat, u0, v0, u1, v1, 0.012)
            if mat == "graphite" and (i + j) % 3 == 0:
                p = P(uc + 0.01, vc, 0.02)
                lot.put(M["acier_clair"], G.boite(p, (0.025, 0.02, 0.008), rnd.f(0.0, 3.0)))
    quad("eau", 0.0, 0.0, 1.0, 0.2, 0.016)
    quad("minerai", 0.0, 0.0, 0.25, 0.2, 0.012)
    # rifles sombres et épais, de plus en plus courts vers le sud
    for k in range(9):
        v = 0.12 + k * 0.09
        lot.put(M["noir"], G.tube([P(0.04, v, 0.026), P(0.96 - 0.55 * v, v, 0.026)], 0.014, 5))
    # bâti
    for (u, v) in ((0.05, 0.1), (0.95, 0.1), (0.05, 0.9), (0.95, 0.9), (0.5, 0.1), (0.5, 0.9)):
        p = P(u, v, -0.06)
        lot.put(M["acier2"], G.boite((p[0], p[1], p[2] / 2 + 0.03), (0.07, 0.07, p[2])))
    # tête à secousses (est) : carter, volant, bielle ; moteur surélevé sur chevalet, courroie, gyrophare
    h = P(-0.07, 0.45)
    K.caisson(lot, M["jaune"], h[0], h[1], 0.06, 0.24, 0.42, 0.66, 0.02)
    lot.put(M["fonte"], G.tour([(h[1] - 0.25, 0.18), (h[1] - 0.22, 0.18)], 20, "y", (h[0], 0.0, 0.5), cap0=True, cap1=True))
    lot.put(M["acier_clair"], G.tube([(h[0] - 0.12, h[1], 0.5), P(0.02, 0.45, -0.02)], 0.035, 8))
    mx, my = h[0] - 0.02, h[1] + 0.32
    for (dx, dy) in ((-0.14, -0.12), (0.14, -0.12), (-0.14, 0.12), (0.14, 0.12)):
        lot.put(M["acier2"], G.tube([(mx + dx, my + dy, 0.06), (mx + dx * 0.8, my + dy * 0.8, 1.3)], 0.022, 5))
    lot.put(M["acier2"], G.boite((mx, my, 1.32), (0.34, 0.3, 0.04)))
    lot.put(M["bleu"], G.tour([(my - 0.14, 0.12), (my + 0.14, 0.12)], 18, "y", (mx, 0.0, 1.48), cap0=True, cap1=True))
    for k in range(6):
        lot.put(M["bleu"], G.tour([(my - 0.12 + k * 0.05, 0.13), (my - 0.1 + k * 0.05, 0.13)], 18, "y", (mx, 0.0, 1.48)))
    lot.put(M["fonte"], G.tour([(my - 0.2, 0.08), (my - 0.16, 0.08)], 16, "y", (mx, 0.0, 1.48), cap0=True, cap1=True))
    lot.put(M["noir"], G.tube([(mx, my - 0.18, 1.56), (h[0], h[1] - 0.23, 0.68)], 0.018, 5))
    lot.put(M["noir"], G.tube([(mx, my - 0.18, 1.4), (h[0], h[1] - 0.23, 0.32)], 0.018, 5))
    K.rev(lot, M["fonte"], mx, my + 0.05, [(1.6, 0.06), (1.64, 0.06)], 12)
    lot.put(M["lampe"], G.sphere((mx, my + 0.05, 1.72), 0.09, 14, 7))
    # alimentation surélevée au nord-est : trémie sur pieds, goulotte vers la boîte d'alimentation du plateau
    tx, ty = 0.55, 1.05
    for (dx, dy) in ((-0.2, -0.16), (0.2, -0.16), (-0.2, 0.16), (0.2, 0.16)):
        lot.put(M["acier2"], G.tube([(tx + dx, ty + dy, 0.06), (tx + dx, ty + dy, 1.4)], 0.022, 5))
    K.rev(lot, M["acier"], tx, ty, [(1.25, 0.07), (1.5, 0.27), (1.92, 0.27)], 4, cap=False)
    K.tas(lot, M["minerai"], (tx, ty, 1.85), 0.2, 0.2, 0.08, rnd, 20, 0.02, 0.035)
    f = P(0.1, 0.02)
    K.caisson(lot, M["acier"], f[0], f[1], f[2] + 0.04, 0.36, 0.16, 0.16, 0.02)
    lot.put(M["acier"], G.tube([(tx, ty, 1.25), (f[0], f[1] + 0.02, f[2] + 0.22)], 0.05, 8))
    # eau de lavage : rampe bleue le long du bord nord, buses
    O.tuyau(lot, M["bleu"], M["acier2"], [(-0.95, 1.3, 0.3), (-0.6, 1.3, 0.3), (-0.6, 1.3, 0.8), P(0.9, -0.05, 0.12)], 0.025, rb=0.06, pas_bride=2.0)
    lot.put(M["bleu"], G.tube([P(0.9, -0.05, 0.12), P(0.22, -0.05, 0.12)], 0.022, 6))
    for k in range(7):
        a = P(0.3 + k * 0.09, -0.05, 0.1)
        lot.put(M["acier2"], G.tube([a, G.add(a, (0.0, -0.06, -0.07))], 0.012, 4))
    # goulottes de décharge (sud, ouest) ; le concentré sort au sud
    lot.put(M["acier"], G.tube([P(0.0, 1.07, -0.05), P(1.07, 1.07, -0.12)], 0.06, 8))
    lot.put(M["acier"], G.tube([P(1.07, 0.0, -0.05), P(1.07, 1.07, -0.12)], 0.06, 8))
    for u in (0.3, 0.62):
        lot.put(M["acier2"], G.boite(P(u, 1.07, -0.03), (0.03, 0.14, 0.1), ang))
    goulotte_sud(lot, M, rnd, -0.45)
    # armoire au sud-est : fenêtre éclairée (lueur de travail)
    K.armoire(lot, M, 0.66, -1.0, 0.06, 0.34, 0.2, 0.5)
    lot.put(M["lampe"], G.boite((0.66, -1.112, 0.36), (0.26, 0.012, 0.2)))
    # passerelle et garde-corps à l'ouest
    lot.put(M["acier2"], G.boite((-0.86, 0.0, 0.3), (0.2, 2.2, 0.03)))
    for y in (-1.0, -0.3, 0.4, 1.1):
        lot.put(M["acier2"], G.tube([(-0.86, y, 0.06), (-0.86, y, 0.3)], 0.02, 5))
    K.rambarde(lot, M["jaune"], [(-0.95, -1.05), (-0.95, 1.15)], 0.31, 0.24)


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
