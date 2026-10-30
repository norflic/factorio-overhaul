"""Mur · Âge 2 · FORGE (ère I). MUR-OPUS v4, 30/10. S'exécute DANS Blender.

DA écrite (docs/DESIGN_EPOQUES.md, époque 2) : « pierre plaquée d'acier boulonné ; merlons d'acier sur la crête (2 par
tuile, bord supérieur crénelé) » ; acier #5C6168, cerclage #2E2C2A, rivets de laiton #8C7440 ; de jour aucune lueur.
v4 (critiques de la v3) : CHÂSSIS EN TALUS du vanilla : pied évasé (profil concave), crête mince (0,13 tuile), bouts
chanfreinés ; la signature d'époque est sur la crête (merlons d'acier) et en habillage de face, à contraste faible ;
matière chaude et sale : acier rouillé, coulures sous les boulons, tôles de deux valeurs ; bande réfractaire montée
d'un rang au-dessus du pied noir ; pied fondu dans une jupe de terre.
"""
import math

import geo
from geo import surface

EPOQUE = 2
NOM = "Forge"
FORME = "horiz"
Z_W, Z_CAP, Z_M = 0.80, 0.84, 0.97          # haut du talus, dessus du couronnement, merlons
Z_F, Z_RB0, Z_RB1 = 0.12, 0.07, 0.25        # cassure du pied évasé, bande réfractaire (au-dessus du pied noir)
# profil concave : (z, demi-épaisseur en tuiles)
PROFIL = ((0.0, 0.49), (Z_F, 0.40), (Z_W, 0.13))
SQ2 = math.sqrt(2.0)
RIV = 0.016
RIV_G = 0.026                                # rivets de laiton des tôles : ≥ 2 px au zoom 1
PIED = ((0.004, 0.003, 0.003), 0.07, 1.0)    # v5 : seul le contact au sol est noir (le corps reste clair)


def hw(z):
    (z0, h0), (z1, h1), (z2, h2) = PROFIL
    if z <= z1:
        return h0 + (h1 - h0) * (z - z0) / (z1 - z0)
    return h1 + (h2 - h1) * min(1.0, (z - z1) / (z2 - z1))


def mats(S):
    M = {}
    M["pierre"] = surface("m2_pierre", (0.20, 0.172, 0.14), (0.105, 0.09, 0.074), rough=0.92, var=0.75, var_scale=4.0,
                          grain=0.3, bump=0.8, bump_scale=40.0,
                          brick=dict(w=0.25, h=0.115, mortar=0.010, c1=(0.21, 0.18, 0.15), c2=(0.12, 0.10, 0.083),
                                     col_m=(0.012, 0.01, 0.008)),
                          edge=((0.42, 0.38, 0.32), 0.75, 0.02), cavity=0.9, cavity_dist=0.14, streak=0.75,
                          stain=((0.04, 0.03, 0.022), 0.6, 4.0), bottom=PIED)
    M["refractaire"] = surface("m2_refr", (0.30, 0.08, 0.042), (0.16, 0.042, 0.024), rough=0.9, var=0.6, var_scale=4.0,
                               grain=0.25, bump=0.6, bump_scale=55.0,
                               brick=dict(w=0.125, h=0.05, mortar=0.012, c1=(0.32, 0.085, 0.045),
                                          c2=(0.15, 0.04, 0.022), col_m=(0.12, 0.10, 0.08)),
                               edge=((0.50, 0.27, 0.15), 0.6, 0.02), cavity=0.6, streak=0.5,
                               stain=((0.04, 0.02, 0.012), 0.5, 4.0), bottom=PIED)
    # acier chaud et rouillé (#5C6168 réchauffé par la rouille et la crasse, comme les aciers vanilla)
    for nom, c1, c2 in (("acier", (0.17, 0.165, 0.16), (0.09, 0.08, 0.07)),
                        ("acier2", (0.13, 0.12, 0.112), (0.07, 0.06, 0.05))):
        M[nom] = surface("m2_" + nom, c1, c2, rough=0.55, rough2=0.85, metal=0.3, var=0.7, var_scale=6.0, grain=0.25,
                         bump=0.4, bump_scale=110.0, edge=((0.40, 0.38, 0.35), 0.8, 0.015), cavity=0.55, streak=0.85,
                         stain=((0.21, 0.085, 0.03), 0.6, 5.0), bottom=PIED)
    M["acier_dessus"] = surface("m2_acier_d", (0.50, 0.47, 0.42), (0.30, 0.28, 0.24), rough=0.6, metal=0.2, var=0.75,
                                var_scale=8.0, grain=0.28, bump=0.4, bump_scale=110.0,
                                edge=((0.62, 0.60, 0.56), 0.85, 0.015), cavity=0.55, streak=0.4,
                                stain=((0.20, 0.09, 0.035), 0.5, 6.0))
    M["cerclage"] = surface("m2_cerclage", (0.035, 0.03, 0.026), (0.09, 0.045, 0.02), rough=0.55, metal=0.5, var=0.6,
                            grain=0.3, bump=0.4, bump_scale=120.0, edge=((0.28, 0.25, 0.22), 0.8, 0.015), cavity=0.3,
                            stain=((0.16, 0.06, 0.02), 0.5, 7.0))
    M["laiton"] = surface("m2_laiton", (0.48, 0.34, 0.11), (0.30, 0.21, 0.07), rough=0.45, metal=0.45, var=0.4,
                          grain=0.15, bump=0.0, edge=((0.5, 0.38, 0.15), 0.5, 0.01), cavity=0.3,
                          stain=((0.12, 0.16, 0.10), 0.4, 9.0))
    # terre du pied : brun du sol vanilla (hr-dirt), qui fond le mur dans le terrain
    M["terre"] = surface("m2_terre", (0.26, 0.13, 0.055), (0.12, 0.06, 0.025), rough=1.0, var=0.8, var_scale=9.0,
                         grain=0.35, bump=1.0, bump_scale=60.0, cavity=0.5, spec=0.1)
    M["rouille"] = surface("m2_rouille", (0.30, 0.10, 0.03), (0.13, 0.05, 0.02), rough=0.9, var=0.8,
                           var_scale=20.0, grain=0.3, bump=0.3, cavity=0.2)
    M["vide"] = surface("m2_vide", (0.008, 0.006, 0.005), rough=1.0, var=0.0, grain=0.0, bump=0.0, cavity=0.0, spec=0.0)
    return M


def _profil(k, z0=0.0, z1=Z_W, d=0.0):
    """Polygone (y, z) du talus entre z0 et z1, gonflé de d (unités)."""
    zs = [z for z in (0.0, Z_F, Z_W) if z0 - 1e-6 <= z <= z1 + 1e-6]
    zs = sorted(set([z0, z1] + zs))
    right = [(hw(z) * k + d, z) for z in zs]
    left = [(-(hw(z) * k + d), z) for z in reversed(zs)]
    return right + left


def _plaque(g, mat, x0, x1, z0, z1, k, d_out, d_in):
    pa = [(x0, -(hw(z0) * k + d_out)), (x1, -(hw(z0) * k + d_out)), (x1, -(hw(z0) * k - d_in)), (x0, -(hw(z0) * k - d_in))]
    pb = [(x0, -(hw(z1) * k + d_out)), (x1, -(hw(z1) * k + d_out)), (x1, -(hw(z1) * k - d_in)), (x0, -(hw(z1) * k - d_in))]
    return g.loft_z(pa, z0, z1, mat, poly1=pb, bev=0.004)


def _jupe(g, M, x0, x1, k, y0):
    """Jupe de terre au pied (face avant) : mottes irrégulières qui cassent l'arête du pied contre le sol."""
    n = max(2, int(round((x1 - x0) / 0.12)))
    for i in range(n):
        a = x0 + i * (x1 - x0) / n
        b = x0 + (i + 1) * (x1 - x0) / n
        h = g.rnd(0.015, 0.035)
        pts = []
        for x in (a - 0.02, b + 0.02, 0.5 * (a + b)):
            pts += [(x, y0 - g.rnd(0.02, 0.05), 0.0), (x, y0 + 0.03, 0.0), (x, y0 + 0.01, h * g.rnd(0.6, 1.0))]
        g.hull(pts, M["terre"], bev=0.01, seg=1)


def bras(g, M, B):
    k, x0, L = B.k, B.x0, B.L
    S_ = B.cote == "S"
    faces = (1, -1) if S_ else (1,)
    # talus : pied noir (pierre crassée), bande réfractaire au-dessus, puis pierre jusqu'à la crête
    g.prism(_profil(k, 0.0, Z_RB0), x0, L, M["pierre"], bev=0.005)
    g.prism(_profil(k, Z_RB0 - 0.004, Z_RB1, d=0.004), x0, L, M["refractaire"], bev=0.005)
    g.prism(_profil(k, Z_RB1 - 0.004, Z_W), x0, L, M["pierre"], bev=0.006)
    for s in faces:
        g.push(g.Sc(1, s, 1))
        # cerclage sombre au-dessus de la bande réfractaire
        _plaque(g, M["cerclage"], x0, L, Z_RB1, Z_RB1 + 0.04, k, 0.014, 0.02)
        if not S_:
            # une tôle boulonnée par demi-case (2 par case), deux valeurs d'acier, rivets de laiton
            sp = B.span(0.12, 0.385)
            if sp:
                xa, xb = B.x(sp[0]), min(B.x(sp[1]), L)
                mat = M["acier"] if g.rnd() < 0.5 else M["acier2"]
                _plaque(g, mat, xa, xb, 0.36, 0.66, k, 0.012, 0.02)
                g.rivets([(x, -(hw(z) * k + 0.016), z, "y") for x in (xa + 0.05, xb - 0.05) for z in (0.40, 0.62)],
                         RIV_G, M["laiton"])
                # coulures de rouille sous les boulons du bas (contrastées, lisibles au zoom 1)
                for x in (xa + 0.05, xb - 0.05, 0.5 * (xa + xb) + g.rnd(-0.04, 0.04)):
                    zb, zt = g.rnd(0.19, 0.30), 0.385
                    wt, wb = g.rnd(0.014, 0.02), 0.004          # coulure effilée vers le bas
                    xo = g.rnd(-0.01, 0.01)
                    g.loft_z([(x + xo - wb, -(hw(zb) * k + 0.0145)), (x + xo + wb, -(hw(zb) * k + 0.0145)),
                              (x + xo + wb, -(hw(zb) * k - 0.004)), (x + xo - wb, -(hw(zb) * k - 0.004))], zb, zt,
                             M["rouille"], poly1=[(x - wt, -(hw(zt) * k + 0.0145)), (x + wt, -(hw(zt) * k + 0.0145)),
                                                  (x + wt, -(hw(zt) * k - 0.004)), (x - wt, -(hw(zt) * k - 0.004))],
                             bev=0)
        else:
            # flancs nord-sud (v5) : contreforts en saillie et blocs débordants (flanc modelé, silhouette dentelée)
            hwk = lambda z: hw(z) * k  # noqa: E731
            for t in (0.25, 0.75):
                geo.contrefort_flanc(g, M["pierre"], M["acier"], B.x(t) + g.rnd(-0.03, 0.03), hwk, 0.66)
            geo.blocs_debordants(g, (M["pierre"], M["acier2"]), B.x(0.05), B.x(0.95), hwk, (0.32, 0.62), 3)
        # contrefort de pierre au joint de case (C2 : 2 par case avec celui du milieu), cornière d'acier rivetée
        if B.t0 < 0.5 < B.t1 and not S_:
            _contrefort_x(g, M, B.x(0.5), k)
        _jupe(g, M, max(x0, 0.0), L - B.eps, k, -hw(0.0) * k)
        g.pop()
    # couronnement d'acier mince et merlons d'acier (2 par case), la signature d'époque
    g.prism([(-(0.13 + 0.025) * k, Z_W - 0.01), ((0.13 + 0.025) * k, Z_W - 0.01), ((0.13 + 0.02) * k, Z_CAP),
             (-(0.13 + 0.02) * k, Z_CAP)], x0, L, M["acier"] if S_ else M["acier_dessus"], bev=0.008)
    for c in (0.0, 0.5, 1.0):
        if c == 0.0 and not S_:
            continue
        sp = B.span(c - 0.11, c + 0.11)
        if sp:
            _merlon(g, M, B.x(sp[0]), min(B.x(sp[1]), L), k, B.x(c), -g.rnd(0.0, 0.025))


def _merlon(g, M, a, b, k, xc, dz=0.0, extra=0.0):
    """Merlon d'acier en coin (suit le talus), dents sur le bord supérieur, rivets de laiton."""
    zt = Z_M + extra + dz
    g.prism([(-0.13 * k, Z_CAP - 0.01), (0.13 * k, Z_CAP - 0.01), (0.09 * k, zt - 0.03), (-0.09 * k, zt - 0.03)],
            a, b, M["acier"], bev=0.006)
    for (u0, u1) in ((xc - 0.11, xc - 0.02), (xc + 0.02, xc + 0.11)):
        lo, hi = max(a, u0), min(b, u1)
        if hi - lo > 0.01:
            g.prism([(-0.095 * k, zt - 0.035), (0.095 * k, zt - 0.035), (0.085 * k, zt), (-0.085 * k, zt)], lo, hi,
                    M["acier_dessus"], bev=0.005)


def _contrefort_x(g, M, xc, k, fente=False):
    """Contrefort en saillie (0,07 tuile au milieu), pied affleurant, cornière d'acier rivetée sur l'arête avant."""
    hwk = lambda z: hw(z) * k  # noqa: E731
    geo.contrefort_flanc(g, M["pierre"], M["acier"], xc, hwk, Z_W - 0.04, w0=0.11, w1=0.055, sail=0.07 * k)
    z0, z1 = Z_RB1 + 0.02, Z_W - 0.08
    ya = lambda z: -(hwk(z) + 0.07 * k * (z / (Z_W - 0.04))) - 0.006  # noqa: E731
    g.loft_z([(xc - 0.03, ya(z0) - 0.012), (xc + 0.03, ya(z0) - 0.012), (xc + 0.03, ya(z0) + 0.02),
              (xc - 0.03, ya(z0) + 0.02)], z0, z1, M["acier"],
             poly1=[(xc - 0.025, ya(z1) - 0.012), (xc + 0.025, ya(z1) - 0.012), (xc + 0.025, ya(z1) + 0.02),
                    (xc - 0.025, ya(z1) + 0.02)], bev=0.003)
    g.rivets([(xc, ya(z) - 0.014, z, "y") for z in (z0 + 0.06, 0.5 * (z0 + z1), z1 - 0.05)], 0.02, M["laiton"])
    if fente:
        z0, z1 = 0.36, 0.56
        g.box(xc - 0.016, xc + 0.016, ya(0.46) - 0.004, ya(0.46) + 0.05, z0, z1, M["vide"], bev=0)


def _contrefort(g, M, fente=False):
    """Contrefort de pierre en talus au milieu de la case (faible contraste), dans le pied."""
    k = SQ2

    def hc(z):
        return hw(z) + 0.05 * min(1.0, z / Z_W) ** 0.6
    pa = [(-0.12, -hc(0.0) * k), (0.12, -hc(0.0) * k), (0.12, -0.1 * k), (-0.12, -0.1 * k)]
    pm = [(-0.10, -hc(Z_F) * k), (0.10, -hc(Z_F) * k), (0.10, -0.1 * k), (-0.10, -0.1 * k)]
    pb = [(-0.055, -hc(Z_W) * k), (0.055, -hc(Z_W) * k), (0.055, -0.1 * k), (-0.055, -0.1 * k)]
    g.loft_z(pa, 0.0, Z_F, M["pierre"], poly1=pm, bev=0.006)
    g.loft_z(pm, Z_F, Z_W, M["pierre"], poly1=pb, bev=0.008)
    if fente:
        z0, z1 = 0.40, 0.62
        g.loft_z([(-0.018, -hc(z0) * k - 0.003), (0.018, -hc(z0) * k - 0.003), (0.018, -hc(z0) * k + 0.04),
                  (-0.018, -hc(z0) * k + 0.04)], z0, z1, M["vide"],
                 poly1=[(-0.018, -hc(z1) * k - 0.003), (0.018, -hc(z1) * k - 0.003), (0.018, -hc(z1) * k + 0.04),
                        (-0.018, -hc(z1) * k + 0.04)], bev=0)
    _merlon(g, M, -0.11, 0.11, k, 0.0, extra=0.02)


def _bout(g, M, extra):
    """Bout de ligne / pièce isolée : pyramide tronquée au même talus dans les deux directions (bouts chanfreinés),
    pied noir, bande réfractaire, merlon d'acier sur la crête (≤ +10 % de la crête)."""
    ky = SQ2

    def carre(h):
        return [(-h, -h * ky), (h, -h * ky), (h, h * ky), (-h, h * ky)]
    g.loft_z(carre(hw(0.0)), 0.0, Z_F, M["pierre"], poly1=carre(hw(Z_F)), bev=0.005)
    g.loft_z(carre(hw(Z_F)), Z_F - 0.002, Z_RB0, M["pierre"], poly1=carre(hw(Z_RB0)), bev=0.005)
    g.loft_z(carre(hw(Z_RB0) + 0.004), Z_RB0, Z_RB1, M["refractaire"], poly1=carre(hw(Z_RB1) + 0.004), bev=0.005)
    g.loft_z(carre(hw(Z_RB1)), Z_RB1 - 0.004, Z_W, M["pierre"], poly1=carre(hw(Z_W)), bev=0.006)
    g.loft_z(carre(hw(Z_RB1) + 0.014), Z_RB1, Z_RB1 + 0.04, M["cerclage"], poly1=carre(hw(Z_RB1 + 0.04) + 0.014),
             bev=0.004)
    g.loft_z(carre(0.13 + 0.025), Z_W - 0.01, Z_CAP, M["acier_dessus"], poly1=carre(0.13 + 0.02), bev=0.008)
    h = 0.12
    g.loft_z(carre(h), Z_CAP - 0.01, Z_M + extra - 0.03, M["acier"], poly1=carre(h - 0.03), bev=0.006)
    g.loft_z(carre(h - 0.02), Z_M + extra - 0.035, Z_M + extra, M["acier_dessus"], poly1=carre(h - 0.035), bev=0.005)
    g.rivets([(x, -(hw(0.5) * ky + 0.012), 0.5, "y") for x in (-0.1, 0.1)], RIV, M["laiton"])
    for s in (1,):
        _jupe(g, M, -0.42, 0.42, ky, -hw(0.0) * ky)


def noeud(g, M, forme, bras):
    if forme in ("single", "endR", "endL"):
        _bout(g, M, 0.05)
    elif forme in ("corR", "corL"):
        _bout(g, M, 0.0)
    elif forme in ("horiz", "horiz2", "horiz3"):
        # C2 : contrefort en saillie au milieu de chaque segment droit (variantes : fente, barbacane)
        _contrefort_x(g, M, 0.0, SQ2, fente=(forme == "horiz2"))
        _merlon(g, M, -0.11, 0.11, SQ2, 0.0, extra=0.02)
        if forme == "horiz3":
            _plaque(g, M["vide"], 0.17, 0.27, 0.02, 0.06, SQ2, 0.003, 0.05)     # barbacane
    elif forme == "tee":
        _merlon(g, M, -0.11, 0.11, SQ2, 0.0)
