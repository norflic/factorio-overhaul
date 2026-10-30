"""Mur · Âge 2 · FORGE (ère I). MUR-OPUS, 29/10 (essai e2 : section en coin). S'exécute DANS Blender.

Un glacis de brique de forge : soubassement de pierre sombre percé de barbacanes, talus de brique rouge (section en
COIN comme le mur vanilla : pied 0,44 tuile, faîte 0,15), bandeau de fer noir riveté, couronnement de pierre et petits
CRÉNEAUX de brique (un merlon par demi-case). Joint de case : plat de fer riveté. Milieu de case (lignes est-ouest) :
contrefort de pierre. Extrémités et angles : TOUR carrée en talus, 4 merlons d'angle, cornières de fer, meurtrière et
foyer où rougeoient les braises (seule lumière de l'âge, famille « rouge-orange de forge »).
"""
import math

import geo
from geo import surface

EPOQUE = 2
NOM = "Forge"
Z_PL, Z_W, Z_CAP, Z_M = 0.11, 0.80, 0.86, 1.02      # soubassement, haut du talus, dessus du couronnement, merlons
HW0, HW1 = 0.44, 0.15                                 # demi-épaisseur du talus (tuiles) en bas / en haut
SQ2 = math.sqrt(2.0)
RIV = 0.017                                           # rayon des rivets (≥ 2 px HR de diamètre)


def hw(z):
    return HW0 + (HW1 - HW0) * (z - Z_PL) / (Z_W - Z_PL)


def mats(S):
    M = {}
    M["brique"] = surface("m2_brique", (0.27, 0.072, 0.04), (0.14, 0.038, 0.022), rough=0.9, var=0.6, var_scale=3.0,
                          grain=0.22, bump=0.6, bump_scale=55.0,
                          brick=dict(w=0.125, h=0.055, mortar=0.014, c1=(0.31, 0.083, 0.046), c2=(0.13, 0.035, 0.021),
                                     col_m=(0.17, 0.15, 0.12)),
                          edge=((0.55, 0.30, 0.18), 0.6, 0.02), cavity=0.65, streak=0.8,
                          stain=((0.04, 0.02, 0.012), 0.7, 4.0),
                          bottom=((0.05, 0.04, 0.03), 0.30, 0.6), top=((0.33, 0.27, 0.21), 0.4))
    M["pierre"] = surface("m2_pierre", (0.17, 0.155, 0.13), (0.09, 0.083, 0.072), rough=0.92, var=0.7, var_scale=5.0,
                          grain=0.25, bump=0.7, bump_scale=40.0,
                          brick=dict(w=0.25, h=0.06, mortar=0.012, c1=(0.19, 0.17, 0.145), c2=(0.10, 0.092, 0.08),
                                     col_m=(0.05, 0.045, 0.04)),
                          edge=((0.40, 0.37, 0.32), 0.7, 0.02), cavity=0.55, streak=0.35,
                          stain=((0.03, 0.025, 0.02), 0.5, 5.0), bottom=((0.04, 0.032, 0.025), 0.2, 0.6))
    M["dalle"] = surface("m2_dalle", (0.50, 0.44, 0.35), (0.31, 0.27, 0.21), rough=0.88, var=0.7, var_scale=7.0,
                         grain=0.28, bump=0.7, bump_scale=45.0,
                         edge=((0.70, 0.64, 0.54), 0.7, 0.02), cavity=0.55, streak=0.5,
                         stain=((0.12, 0.10, 0.08), 0.5, 6.0))
    M["dalle_s"] = surface("m2_dalle_s", (0.30, 0.26, 0.21), (0.16, 0.14, 0.11), rough=0.9, var=0.8, var_scale=7.0,
                           grain=0.3, bump=0.7, bump_scale=45.0, edge=((0.50, 0.46, 0.38), 0.7, 0.02), cavity=0.6,
                           streak=0.6, stain=((0.06, 0.05, 0.04), 0.6, 6.0))
    M["chaine"] = surface("m2_chaine", (0.44, 0.39, 0.31), (0.27, 0.24, 0.19), rough=0.9, var=0.7, var_scale=6.0,
                          grain=0.28, bump=0.7, bump_scale=40.0, edge=((0.52, 0.48, 0.42), 0.7, 0.02), cavity=0.55,
                          streak=0.5, stain=((0.06, 0.05, 0.04), 0.5, 5.0))
    M["fer"] = surface("m2_fer", (0.035, 0.034, 0.033), (0.09, 0.045, 0.022), rough=0.45, rough2=0.85, metal=0.8,
                       var=0.6, var_scale=9.0, grain=0.3, bump=0.4, bump_scale=120.0,
                       edge=((0.30, 0.29, 0.27), 0.8, 0.015), cavity=0.3,
                       stain=((0.16, 0.06, 0.02), 0.45, 7.0))
    M["vide"] = surface("m2_vide", (0.008, 0.006, 0.005), rough=1.0, var=0.0, grain=0.0, bump=0.0, cavity=0.0, spec=0.0)
    M["braise"] = geo.emissive(S, "m2_braise", (1.0, 0.22, 0.04), strength=1.0, base=(0.05, 0.012, 0.004),
                               crust=(40.0, 0.7, 3.0))
    return M


def _talus_box(g, M, mat, x0, x1, z0, z1, d_out, d_in, hwf):
    """Pièce plaquée sur un talus de demi-épaisseur hwf(z) (face avant, normale vers -Y) : de z0 à z1, épaisseur d_out
    en saillie et d_in d'ancrage (unités, déjà multipliées par k)."""
    pa = [(x0, -(hwf(z0) + d_out)), (x1, -(hwf(z0) + d_out)), (x1, -(hwf(z0) - d_in)), (x0, -(hwf(z0) - d_in))]
    pb = [(x0, -(hwf(z1) + d_out)), (x1, -(hwf(z1) + d_out)), (x1, -(hwf(z1) - d_in)), (x0, -(hwf(z1) - d_in))]
    return g.loft_z(pa, z0, z1, mat, poly1=pb, bev=0.004)


def bras(g, M, B):
    k, x0, L = B.k, B.x0, B.L
    S_ = B.cote == "S"

    def hwk(z):
        return hw(z) * k
    # soubassement de pierre en glacis (v2 : plus de dalle à bord net), éboulis au pied
    g.prism([(-0.47 * k, 0.0), (0.47 * k, 0.0), (HW0 * k + 0.015, Z_PL), (-(HW0 * k + 0.015), Z_PL)], x0, L,
            M["pierre"], bev=0.008)
    for s_ in ((-1, 1) if S_ else (-1,)):
        g.push(g.Sc(1, s_, 1))
        geo.eboulis(g, (M["pierre"], M["dalle"], M["chaine"]), max(x0, 0.0), L - B.eps, -0.47 * k, 3 if not S_ else 4,
                    r=0.03)
        g.pop()
    # talus de brique
    g.prism([(-HW0 * k, Z_PL - 0.01), (HW0 * k, Z_PL - 0.01), (HW1 * k, Z_W), (-HW1 * k, Z_W)], x0, L, M["brique"],
            bev=0.006)
    # couronnement de pierre en surplomb, une pierre par quart de case
    for i in range(-1, int(round(B.Lt / 0.25)) + 1):
        sp = B.span(i * 0.25, (i + 1) * 0.25)
        if not sp:
            continue
        a, b = B.x(sp[0]), min(B.x(sp[1]), L)
        ja = 0.005 if sp[0] > B.t0 + 1e-4 else 0.0
        jb = 0.005 if sp[1] < B.t1 - 1e-4 else 0.0
        dz = g.rnd(-0.008, 0.006)
        g.prism([(-(HW1 + 0.05) * k, Z_W - 0.01), ((HW1 + 0.05) * k, Z_W - 0.01), ((HW1 + 0.05) * k, Z_W + 0.03),
                 ((HW1 + 0.03) * k, Z_CAP + dz), (-(HW1 + 0.03) * k, Z_CAP + dz), (-(HW1 + 0.05) * k, Z_W + 0.03)],
                a + ja, b - jb, M["dalle_s"] if S_ else M["dalle"], bev=0.01, ends=True)
    # merlons de brique (centres 0, 0,5, 1,0 tuile), chapeau de pierre
    for c in (0.0, 0.5, 1.0):
        if c == 0.0 and not S_:
            continue
        sp = B.span(c - 0.125, c + 0.125)
        if not sp:
            continue
        a, b = B.x(sp[0]), min(B.x(sp[1]), L)
        dz = -g.rnd(0.0, 0.05) if S_ else -g.rnd(0.0, 0.02)       # merlons ébréchés, inégaux (surtout nord-sud)
        g.prism([(-0.13 * k, Z_CAP - 0.01), (0.13 * k, Z_CAP - 0.01), (0.12 * k, Z_M - 0.03 + dz),
                 (-0.12 * k, Z_M - 0.03 + dz)], a, b, M["brique"], bev=0.005)
        if not (S_ and g.rnd() < 0.35):
            g.prism([(-0.145 * k, Z_M - 0.035 + dz), (0.145 * k, Z_M - 0.035 + dz), (0.145 * k, Z_M - 0.01 + dz),
                     (0.12 * k, Z_M + dz), (-0.12 * k, Z_M + dz), (-0.145 * k, Z_M - 0.01 + dz)], a, b,
                    M["dalle_s"] if S_ else M["dalle"], bev=0.006)
    # bandeau de fer riveté (suit le talus)
    za, zb = 0.40, 0.46
    g.prism([(-(hw(za) * k + 0.02), za), (-(hw(zb) * k + 0.02), zb), ((hw(zb) * k + 0.02), zb),
             ((hw(za) * k + 0.02), za)], x0, L, M["fer"], bev=0.005)
    zr = 0.5 * (za + zb)
    for s in ((-1, 1) if S_ else (-1,)):
        g.push(g.Sc(1, s, 1))
        n = max(1, int(round(B.Lt / 0.125)))
        g.rivets([(B.x((i + 0.5) * 0.125), -(hw(zr) * k + 0.024), zr, "y") for i in range(n)
                  if B.t0 < (i + 0.5) * 0.125 < B.t1], RIV, M["fer"])
        # plat de fer au joint de case (t = 0,5), du soubassement au couronnement
        if B.t0 < 0.5 < B.t1:
            xj = B.x(0.5)
            _talus_box(g, M, M["fer"], xj - 0.03, xj + 0.03, Z_PL, Z_W - 0.01, 0.014, 0.02, hwk)
            g.rivets([(xj, -(hw(z) * k + 0.018), z, "y") for z in (0.2, 0.31, 0.58, 0.70)], RIV, M["fer"])
        g.pop()
    # barbacanes (évacuations) dans le soubassement, au milieu des demi-cases
    if not S_:
        for t in (0.25,):
            x = B.x(t)
            g.box(x - 0.05, x + 0.05, -(0.46 * k + 0.003), -(0.46 * k - 0.05), 0.015, 0.065, M["vide"], bev=0)


def _tour(g, M):
    """Tour d'angle ou d'extrémité : pilier carré en talus, plus haut que la courtine, 4 merlons d'angle, foyer."""
    zc, zm = 1.06, 1.26
    ky = SQ2
    a0, a1 = 0.45, 0.30

    def ha(z):
        return a0 + (a1 - a0) * (z - 0.13) / (zc - 0.07 - 0.13)

    def carre(h, kx=1.0):
        return [(-h, -h * ky), (h, -h * ky), (h, h * ky), (-h, h * ky)]
    g.loft_z(carre(0.485), 0.0, 0.14, M["pierre"], poly1=carre(0.455), bev=0.008)
    geo.eboulis(g, (M["pierre"], M["dalle"], M["chaine"]), -0.42, 0.42, -0.485 * ky, 4, r=0.035)
    g.loft_z(carre(a0), 0.13, zc - 0.07, M["brique"], poly1=carre(a1), bev=0.006)
    # corbeaux sous le couronnement (face avant et côtés)
    for i in range(5):
        x = -0.24 + i * 0.12
        g.box(x - 0.026, x + 0.026, -(a1 + 0.06) * ky, -(a1 - 0.03) * ky, zc - 0.14, zc - 0.07, M["pierre"], bev=0.005)
    # couronnement
    g.loft_z(carre(a1 + 0.05), zc - 0.075, zc, M["dalle"], poly1=carre(a1 + 0.04), bev=0.012)
    # 4 merlons d'angle
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (a1 - 0.06), sy * (a1 - 0.06) * ky
            hx, hy = 0.085, 0.085 * ky
            g.box(cx - hx, cx + hx, cy - hy, cy + hy, zc - 0.01, zm - 0.035, M["brique"], bev=0.005)
            g.box(cx - hx - 0.012, cx + hx + 0.012, cy - hy - 0.012, cy + hy + 0.012, zm - 0.035, zm, M["dalle"],
                  bev=0.006)
    # plate-forme : trappe de fer rivetée et tuyau de forge à chapeau (la braise ne se voit que par la meurtrière)
    g.box(-0.11, 0.11, -0.11 * ky, 0.11 * ky, zc - 0.005, zc + 0.012, M["fer"], bev=0.004)
    g.rivets([(x, y * ky, zc + 0.014, "z") for x in (-0.085, 0.085) for y in (-0.085, 0.085)], RIV, M["fer"])
    g.cyl((0.06, 0.12 * ky, zc + 0.12), "z", 0.045, 0.24, M["fer"], n=16, bev=0.003)
    g.cyl((0.06, 0.12 * ky, zc + 0.255), "z", 0.075, 0.03, M["fer"], n=16, r2=0.02, bev=0.003)
    # bandeau de fer de la tour et rivets
    za, zb = 0.40, 0.46
    g.loft_z(carre(ha(za) + 0.018), za, zb, M["fer"], poly1=carre(ha(zb) + 0.018), bev=0.005)
    zr = 0.5 * (za + zb)
    g.rivets([(x, -(ha(zr) + 0.018) * ky - 0.012, zr, "y") for x in (-0.3, -0.18, -0.06, 0.06, 0.18, 0.3)], RIV,
             M["fer"])
    # chaînage d'angle : pierres claires alternées (longue, courte) aux deux arêtes avant
    zq = 0.14
    n = 0
    while zq < zc - 0.16:
        z1 = min(zq + 0.09, zc - 0.16)
        if not (za - 0.01 < 0.5 * (zq + z1) < zb + 0.01):
            lo = 0.15 if n % 2 == 0 else 0.08
            for sx in (-1, 1):
                pa = [(sx * (ha(zq) + 0.012), -(ha(zq) + 0.012) * ky), (sx * (ha(zq) - lo), -(ha(zq) + 0.012) * ky),
                      (sx * (ha(zq) - lo), -(ha(zq) - 0.05) * ky), (sx * (ha(zq) + 0.012), -(ha(zq) - 0.05) * ky)]
                pb = [(sx * (ha(z1) + 0.012), -(ha(z1) + 0.012) * ky), (sx * (ha(z1) - lo), -(ha(z1) + 0.012) * ky),
                      (sx * (ha(z1) - lo), -(ha(z1) - 0.05) * ky), (sx * (ha(z1) + 0.012), -(ha(z1) - 0.05) * ky)]
                g.loft_z(pa, zq + 0.005, z1 - 0.005, M["chaine"], poly1=pb, bev=0.008)
        zq = z1
        n += 1
    # meurtrière à braises (face avant)
    z0, z1 = 0.56, 0.80
    y = -(ha(0.68)) * ky
    g.box(-0.06, 0.06, y - 0.03, y + 0.02, z0 - 0.04, z0, M["dalle"], bev=0.005)
    g.box(-0.06, 0.06, y - 0.045, y + 0.02, z1, z1 + 0.04, M["dalle"], bev=0.005)
    g.box(-0.026, 0.026, y - 0.02, y + 0.06, z0, z1, M["vide"], bev=0)
    g.box(-0.018, 0.018, y - 0.008, y + 0.04, z0, z0 + 0.09, M["braise"], bev=0)
    # barbacane
    g.box(-0.06, 0.06, -0.475 * ky - 0.003, -0.475 * ky + 0.05, 0.015, 0.07, M["vide"], bev=0)


def _contrefort(g, M):
    """Contrefort de pierre au milieu d'une case de courtine (face avant), merlon central."""
    k = SQ2

    def hc(z):
        return (hw(z) + 0.035 + 0.05 * (1 - z / Z_W)) * k
    _talus_box(g, M, M["pierre"], -0.085, 0.085, 0.0, Z_W, 0.0, 0.06 * k, hc)
    # chaperon
    g.box(-0.095, 0.095, -(hc(Z_W) + 0.01), -(HW1 - 0.02) * k, Z_W - 0.01, Z_W + 0.04, M["dalle"], bev=0.006)
    # ferrure en travers
    za, zb = 0.40, 0.46
    _talus_box(g, M, M["fer"], -0.095, 0.095, za, zb, 0.012, 0.02, hc)
    g.rivets([(x, -(hc(0.43) + 0.016), 0.43, "y") for x in (-0.06, 0.0, 0.06)], RIV, M["fer"])
    # merlon central
    g.prism([(-0.13 * k, Z_CAP - 0.01), (0.13 * k, Z_CAP - 0.01), (0.12 * k, Z_M - 0.03), (-0.12 * k, Z_M - 0.03)],
            -0.125, 0.125, M["brique"], bev=0.005)
    g.prism([(-0.145 * k, Z_M - 0.035), (0.145 * k, Z_M - 0.035), (0.145 * k, Z_M - 0.01), (0.12 * k, Z_M),
             (-0.12 * k, Z_M), (-0.145 * k, Z_M - 0.01)], -0.125, 0.125, M["dalle"], bev=0.006)


def _merlon_central(g, M):
    k = SQ2
    g.prism([(-0.13 * k, Z_CAP - 0.01), (0.13 * k, Z_CAP - 0.01), (0.12 * k, Z_M - 0.03), (-0.12 * k, Z_M - 0.03)],
            -0.125, 0.125, M["brique"], bev=0.005)
    g.prism([(-0.145 * k, Z_M - 0.035), (0.145 * k, Z_M - 0.035), (0.145 * k, Z_M - 0.01), (0.12 * k, Z_M),
             (-0.12 * k, Z_M), (-0.145 * k, Z_M - 0.01)], -0.125, 0.125, M["dalle"], bev=0.006)


def _archere(g, M):
    """Variante du segment droit : archère cruciforme dans le talus, encadrement de pierre, suie au-dessus."""
    k = SQ2

    def hwk(z):
        return hw(z) * k
    z0, z1 = 0.24, 0.66
    _talus_box(g, M, M["chaine"], -0.075, 0.075, z0 - 0.05, z0, 0.012, 0.03, hwk)
    _talus_box(g, M, M["chaine"], -0.075, 0.075, z1, z1 + 0.05, 0.012, 0.03, hwk)
    _talus_box(g, M, M["chaine"], -0.07, -0.035, z0, z1, 0.008, 0.03, hwk)
    _talus_box(g, M, M["chaine"], 0.035, 0.07, z0, z1, 0.008, 0.03, hwk)
    _talus_box(g, M, M["vide"], -0.022, 0.022, z0, z1, 0.002, 0.04, hwk)
    _talus_box(g, M, M["vide"], -0.06, 0.06, 0.43, 0.47, 0.002, 0.04, hwk)
    _merlon_central(g, M)


def noeud(g, M, forme, bras):
    if forme in ("single", "corR", "corL", "endR", "endL"):
        _tour(g, M)
    elif forme == "horiz":
        _contrefort(g, M)
    elif forme == "horiz2":
        _archere(g, M)
    elif forme == "tee":
        k = SQ2
        g.prism([(-0.13 * k, Z_CAP - 0.01), (0.13 * k, Z_CAP - 0.01), (0.12 * k, Z_M - 0.03),
                 (-0.12 * k, Z_M - 0.03)], -0.125, 0.125, M["brique"], bev=0.005)
        g.prism([(-0.145 * k, Z_M - 0.035), (0.145 * k, Z_M - 0.035), (0.145 * k, Z_M - 0.01), (0.12 * k, Z_M),
                 (-0.12 * k, Z_M), (-0.145 * k, Z_M - 0.01)], -0.125, 0.125, M["dalle"], bev=0.006)
