"""Mur · Âge 2 · FORGE (ère I). MUR-OPUS, 29/10. S'exécute DANS Blender.

Un rempart de briques de forge : soubassement de pierre sombre, courtine de brique rouge en léger talus, cordon de fer
noir riveté, couronnement de dalles de pierre claire et CRÉNEAUX (merlons de brique à chapeau de pierre, un merlon par
demi-case). Joints de case : plat de fer riveté. Pilastre de pierre au milieu de chaque case. Extrémités et angles :
TOUR carrée plus haute, 4 merlons d'angle, cornières de fer, meurtrière où rougeoient les braises de la forge (seule
lumière de l'âge, famille « rouge-orange de forge »). Même ADN que la mitrailleuse validée de l'âge 2 (brique rouge,
fer martelé noir, braise).
"""
import math

import geo
from geo import surface

EPOQUE = 2
NOM = "Forge"
Z_PL, Z_W, Z_CAP, Z_M = 0.17, 0.98, 1.06, 1.30      # soubassement, haut de courtine, dessus des dalles, merlons
HW0, HW1 = 0.40, 0.33                                 # demi-épaisseur de la courtine (tuiles) en bas / en haut
SQ2 = math.sqrt(2.0)


def hw(z):
    return HW0 + (HW1 - HW0) * (z - Z_PL) / (Z_W - Z_PL)


def mats(S):
    M = {}
    M["brique"] = surface("m2_brique", (0.30, 0.072, 0.04), (0.17, 0.045, 0.028), rough=0.88, var=0.55, var_scale=4.0,
                          grain=0.2, bump=0.5, bump_scale=55.0,
                          brick=dict(w=0.125, h=0.0625, mortar=0.012, c1=(0.33, 0.085, 0.048), c2=(0.16, 0.042, 0.026),
                                     col_m=(0.23, 0.2, 0.16)),
                          edge=((0.45, 0.24, 0.15), 0.45, 0.03), cavity=0.5, streak=0.45,
                          bottom=((0.045, 0.035, 0.028), 0.42, 0.55), top=((0.30, 0.25, 0.20), 0.35))
    M["pierre"] = surface("m2_pierre", (0.17, 0.155, 0.13), (0.10, 0.092, 0.08), rough=0.92, var=0.6, var_scale=5.0,
                          grain=0.22, bump=0.6, bump_scale=40.0,
                          brick=dict(w=0.25, h=0.085, mortar=0.010, c1=(0.18, 0.165, 0.14), c2=(0.11, 0.10, 0.085),
                                     col_m=(0.06, 0.055, 0.05)),
                          edge=((0.36, 0.33, 0.28), 0.6, 0.03), cavity=0.55, streak=0.3,
                          bottom=((0.04, 0.032, 0.025), 0.25, 0.6))
    M["dalle"] = surface("m2_dalle", (0.34, 0.31, 0.27), (0.22, 0.20, 0.17), rough=0.85, var=0.6, var_scale=6.0,
                         grain=0.2, bump=0.5, bump_scale=45.0,
                         edge=((0.55, 0.52, 0.46), 0.5, 0.025), cavity=0.5, streak=0.5,
                         top=((0.42, 0.39, 0.34), 0.35))
    M["fer"] = surface("m2_fer", (0.032, 0.031, 0.030), (0.07, 0.035, 0.018), rough=0.48, rough2=0.8, metal=0.8,
                       var=0.55, var_scale=9.0, grain=0.25, bump=0.35, bump_scale=120.0,
                       edge=((0.22, 0.21, 0.20), 0.7, 0.02), cavity=0.3, streak=0.0)
    M["vide"] = surface("m2_vide", (0.008, 0.006, 0.005), rough=1.0, var=0.0, grain=0.0, bump=0.0, cavity=0.0, spec=0.0)
    M["braise"] = geo.emissive(S, "m2_braise", (1.0, 0.2, 0.03), strength=9.0, base=(0.05, 0.012, 0.004))
    return M


def _rivets_front(g, x0, x1, z, k, y_face, pas, M, r=0.011):
    n = max(1, int(round((x1 - x0) / pas)))
    pts = [(x0 + (i + 0.5) * (x1 - x0) / n, y_face, z, "y") for i in range(n)]
    g.rivets(pts, r, M["fer"])


def bras(g, M, B):
    k, x0, L = B.k, B.x0, B.L
    S_ = B.cote == "S"
    # soubassement de pierre (chanfrein en tête)
    g.prism([(-0.47 * k, 0.0), (0.47 * k, 0.0), (0.47 * k, 0.12), (0.43 * k, Z_PL), (-0.43 * k, Z_PL),
             (-0.47 * k, 0.12)], x0, L, M["pierre"], bev=0.01)
    # courtine de brique en talus
    g.prism([(-HW0 * k, Z_PL - 0.01), (HW0 * k, Z_PL - 0.01), (HW1 * k, Z_W), (-HW1 * k, Z_W)], x0, L, M["brique"],
            bev=0.008)
    # cordon de fer (bandeau) à mi-hauteur
    za, zb = 0.56, 0.615
    g.prism([(-(hw(za) + 0.018) * k, za), (-(hw(zb) + 0.018) * k, zb), ((hw(zb) + 0.018) * k, zb),
             ((hw(za) + 0.018) * k, za)], x0, L, M["fer"], bev=0.006)
    yf = -(hw(0.5 * (za + zb)) + 0.018) * k
    _rivets_front(g, max(x0, 0.0), L - B.eps, 0.5 * (za + zb), k, yf - 0.002, 0.0625 * B.ka, M)
    if S_:
        g.push(g.Sc(1, -1, 1))
        _rivets_front(g, max(x0, 0.0), L, 0.5 * (za + zb), k, yf - 0.002, 0.0625 * B.ka, M)
        g.pop()
    # couronnement : dalles en surplomb (une dalle par demi-case, joints marqués)
    nd = int(round(B.Lt / 0.25))
    for i in range(-1, nd + 1):
        sp = B.span(i * 0.25, (i + 1) * 0.25)
        if not sp:
            continue
        a, b = B.x(sp[0]), B.x(sp[1])
        if b > L:
            b = L
        ja = 0.004 if sp[0] > B.t0 + 1e-4 else 0.0
        jb = 0.004 if sp[1] < B.t1 - 1e-4 else 0.0
        dz = g.rnd(-0.006, 0.006)
        g.prism([(-0.38 * k, Z_W), (0.38 * k, Z_W), (0.38 * k, Z_W + 0.045 + dz), (0.35 * k, Z_CAP + dz),
                 (-0.35 * k, Z_CAP + dz), (-0.38 * k, Z_W + 0.045 + dz)], a + ja, b - jb, M["dalle"], bev=0.01,
                ends=True)
    # merlons : centres à 0 (porté par le nœud ou le bras sud), 0,5, 1,0 tuile ; demi-largeur 0,125 tuile
    for c in (0.0, 0.5, 1.0):
        if c == 0.0 and not S_:
            continue
        sp = B.span(c - 0.125, c + 0.125)
        if not sp:
            continue
        a, b = B.x(sp[0]), min(B.x(sp[1]), L)
        g.prism([(-0.29 * k, Z_CAP - 0.01), (0.29 * k, Z_CAP - 0.01), (0.27 * k, Z_M - 0.045),
                 (-0.27 * k, Z_M - 0.045)], a, b, M["brique"], bev=0.006)
        g.prism([(-0.31 * k, Z_M - 0.05), (0.31 * k, Z_M - 0.05), (0.31 * k, Z_M - 0.015), (0.27 * k, Z_M),
                 (-0.27 * k, Z_M), (-0.31 * k, Z_M - 0.015)], a, b, M["dalle"], bev=0.008)
    # plat de fer riveté au joint de case (t = 0,5 pour E et O, au milieu du bras sud)
    tj = 0.5
    xj = B.x(tj)
    faces = (-1, 1) if S_ else (-1,)
    for s in faces:
        g.push(g.Sc(1, s, 1))
        z0, z1 = Z_PL, Z_W - 0.01
        pa = [(xj - 0.024, -(hw(z0) * k + 0.012)), (xj + 0.024, -(hw(z0) * k + 0.012)),
              (xj + 0.024, -(hw(z0) * k - 0.02)), (xj - 0.024, -(hw(z0) * k - 0.02))]
        pb = [(xj - 0.024, -(hw(z1) * k + 0.012)), (xj + 0.024, -(hw(z1) * k + 0.012)),
              (xj + 0.024, -(hw(z1) * k - 0.02)), (xj - 0.024, -(hw(z1) * k - 0.02))]
        g.loft_z(pa, z0, z1, M["fer"], poly1=pb, bev=0.004)
        g.rivets([(xj, -(hw(z) * k + 0.014), z, "y") for z in (0.27, 0.42, 0.72, 0.88)], 0.012, M["fer"])
        g.pop()
    # trous de boulin sous les dalles (petites ombres régulières), face avant
    if not S_:
        for t in (0.25,):
            x = B.x(t)
            g.box(x - 0.022, x + 0.022, -(hw(0.86) * k + 0.004), -(hw(0.86) * k - 0.03), 0.84, 0.88, M["vide"], bev=0)
        # barbacane au pied (évacuation) : petite voûte sombre dans le soubassement
        x = B.x(0.25)
        g.box(x - 0.035, x + 0.035, -(0.47 * k + 0.003), -(0.47 * k - 0.04), 0.03, 0.09, M["vide"], bev=0)


def _meurtriere(g, M, x, y_face, z0, z1, braise=True):
    """Meurtrière dans une face avant (normale -Y) en y_face : encadrement de pierre, fente sombre, braises au fond."""
    g.box(x - 0.05, x + 0.05, y_face - 0.012, y_face + 0.02, z0 - 0.035, z0, M["dalle"], bev=0.005)
    g.box(x - 0.05, x + 0.05, y_face - 0.012, y_face + 0.02, z1, z1 + 0.035, M["dalle"], bev=0.005)
    g.box(x - 0.022, x + 0.022, y_face - 0.003, y_face + 0.03, z0, z1, M["vide"], bev=0)
    if braise:
        g.box(x - 0.016, x + 0.016, y_face - 0.001, y_face + 0.02, z0, z0 + 0.4 * (z1 - z0), M["braise"], bev=0)


def _tour(g, M):
    """Tour d'angle ou d'extrémité : pilier carré en talus, plus haut que la courtine, 4 merlons d'angle."""
    zc, zm = 1.18, 1.46
    ky = SQ2
    # soubassement
    g.loft_z([(-0.49, -0.49 * ky), (0.49, -0.49 * ky), (0.49, 0.49 * ky), (-0.49, 0.49 * ky)], 0.0, 0.2,
             M["pierre"], poly1=[(-0.47, -0.47 * ky), (0.47, -0.47 * ky), (0.47, 0.47 * ky), (-0.47, 0.47 * ky)],
             bev=0.01)
    a0, a1 = 0.43, 0.37
    g.loft_z([(-a0, -a0 * ky), (a0, -a0 * ky), (a0, a0 * ky), (-a0, a0 * ky)], 0.19, zc - 0.07,
             M["brique"], poly1=[(-a1, -a1 * ky), (a1, -a1 * ky), (a1, a1 * ky), (-a1, a1 * ky)], bev=0.008)
    # mâchicoulis : rang de corbeaux sous le couronnement, face avant et côtés
    for i in range(7):
        x = -0.36 + i * 0.12
        g.box(x - 0.025, x + 0.025, -(a1 + 0.05) * ky, -(a1 - 0.02) * ky, zc - 0.13, zc - 0.07, M["pierre"], bev=0.004)
    # couronnement
    c0 = 0.42
    g.loft_z([(-c0, -c0 * ky), (c0, -c0 * ky), (c0, c0 * ky), (-c0, c0 * ky)], zc - 0.07, zc, M["dalle"], bev=0.012)
    # 4 merlons d'angle
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * 0.28, sy * 0.28 * ky
            hx, hy = 0.12, 0.12 * ky
            g.box(cx - hx, cx + hx, cy - hy, cy + hy, zc - 0.01, zm - 0.05, M["brique"], bev=0.006)
            g.box(cx - hx - 0.015, cx + hx + 0.015, cy - hy - 0.015, cy + hy + 0.015, zm - 0.05, zm, M["dalle"],
                  bev=0.008)
    # braises du foyer au centre (on les voit entre les merlons)
    g.cyl((0, 0, zc + 0.03), "z", 0.16, 0.06, M["fer"], n=20, r2=0.19, bev=0.004)
    g.cyl((0, 0, zc + 0.062), "z", 0.15, 0.012, M["braise"], n=20, bev=0)
    # cornières de fer aux arêtes avant et rivets
    for sx in (-1, 1):
        z0, z1 = 0.2, zc - 0.14
        for (za, zb) in ((z0, z1),):
            xa, xb = sx * (a0 + 0.006), sx * (a1 + 0.006)
            g.loft_z([(xa - 0.035 * sx, -(a0 + 0.006) * ky), (xa, -(a0 + 0.006) * ky), (xa, -(a0 - 0.05) * ky),
                      (xa - 0.012 * sx, -(a0 - 0.05) * ky), (xa - 0.012 * sx, -(a0 - 0.006) * ky),
                      (xa - 0.035 * sx, -(a0 - 0.006) * ky)][::sx], za, zb, M["fer"],
                     poly1=[(xb - 0.035 * sx, -(a1 + 0.006) * ky), (xb, -(a1 + 0.006) * ky), (xb, -(a1 - 0.05) * ky),
                            (xb - 0.012 * sx, -(a1 - 0.05) * ky), (xb - 0.012 * sx, -(a1 - 0.006) * ky),
                            (xb - 0.035 * sx, -(a1 - 0.006) * ky)][::sx], bev=0.003)
        g.rivets([(sx * (0.40 - 0.02 * (z - 0.2)), -(0.43 - 0.06 * (z - 0.2)) * ky - 0.016, z, "y")
                  for z in (0.32, 0.55, 0.78)], 0.012, M["fer"])
    # cordon de fer de la tour
    za, zb = 0.56, 0.615
    fa = a0 + (a1 - a0) * (za - 0.19) / (zc - 0.26) + 0.015
    fb = a0 + (a1 - a0) * (zb - 0.19) / (zc - 0.26) + 0.015
    g.loft_z([(-fa, -fa * ky), (fa, -fa * ky), (fa, fa * ky), (-fa, fa * ky)], za, zb, M["fer"],
             poly1=[(-fb, -fb * ky), (fb, -fb * ky), (fb, fb * ky), (-fb, fb * ky)], bev=0.005)
    # meurtrière à braises sur la face avant
    yfm = -(a0 + (a1 - a0) * (0.82 - 0.19) / (zc - 0.26)) * ky
    _meurtriere(g, M, 0.0, yfm, 0.70, 0.92)


def _pilastre(g, M):
    """Pilastre de pierre au milieu d'une case de courtine (face avant), merlon central plus haut."""
    k = SQ2
    z0, z1 = 0.0, Z_W
    pa = [(-0.11, -(0.47 + 0.05) * k), (0.11, -(0.47 + 0.05) * k), (0.11, -0.2 * k), (-0.11, -0.2 * k)]
    pb = [(-0.09, -(HW1 + 0.04) * k), (0.09, -(HW1 + 0.04) * k), (0.09, -0.2 * k), (-0.09, -0.2 * k)]
    g.loft_z(pa, z0, z1, M["pierre"], poly1=pb, bev=0.01)
    # chaperon du pilastre
    g.box(-0.11, 0.11, -(HW1 + 0.07) * k, 0.0, Z_W, Z_W + 0.05, M["dalle"], bev=0.008)
    # merlon central (un peu plus haut que ceux de la courtine)
    g.prism([(-0.30 * k, Z_CAP - 0.01), (0.30 * k, Z_CAP - 0.01), (0.28 * k, Z_M + 0.02), (-0.28 * k, Z_M + 0.02)],
            -0.13, 0.13, M["brique"], bev=0.006)
    g.box(-0.145, 0.145, -0.32 * k, 0.32 * k, Z_M + 0.02, Z_M + 0.065, M["dalle"], bev=0.008)
    # meurtrière (sans braise : la braise est réservée aux tours) et ferrure
    yf = -(0.47 + 0.05 + (HW1 + 0.04 - 0.47 - 0.05) * 0.62) * k
    _meurtriere(g, M, 0.0, yf, 0.50, 0.68, braise=False)
    g.box(-0.1, 0.1, yf - 0.03, yf + 0.01, 0.30, 0.335, M["fer"], bev=0.004)
    g.rivets([(x, yf - 0.033, 0.318, "y") for x in (-0.07, 0.0, 0.07)], 0.011, M["fer"])


def noeud(g, M, forme, bras):
    if forme in ("single", "corR", "corL", "endR", "endL"):
        _tour(g, M)
    elif forme == "horiz":
        _pilastre(g, M)
    elif forme == "tee":
        # merlon central au croisement (le bras sud porte déjà son merlon en t = 0)
        k = SQ2
        g.prism([(-0.29 * k, Z_CAP - 0.01), (0.29 * k, Z_CAP - 0.01), (0.27 * k, Z_M - 0.045),
                 (-0.27 * k, Z_M - 0.045)], -0.125, 0.125, M["brique"], bev=0.006)
        g.prism([(-0.31 * k, Z_M - 0.05), (0.31 * k, Z_M - 0.05), (0.31 * k, Z_M - 0.015), (0.27 * k, Z_M),
                 (-0.27 * k, Z_M), (-0.31 * k, Z_M - 0.015)], -0.125, 0.125, M["dalle"], bev=0.008)
