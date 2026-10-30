"""Mur · Âge 2 · FORGE (ère I). MUR-OPUS v3, 30/10. S'exécute DANS Blender.

DA écrite (docs/DESIGN_EPOQUES.md, époque 2) : « pierre plaquée d'acier boulonné ; merlons d'acier sur la crête (2 par
tuile, bord supérieur crénelé) » ; matériaux acier #5C6168, cerclage #2E2C2A, rivets de laiton #8C7440 ; de jour aucune
lueur (la lueur de forge par des fentes est une couche de NUIT, non faite ici). Lien avec la mitrailleuse validée :
bande basse de brique réfractaire rouge (au plus 25 % de la façade).
Section en COIN comme le mur vanilla (pied 0,46 tuile, faîte 0,15). Par case : 2 tôles boulonnées, contrefort au
milieu (dans le pied, sans saillie au sud du pied), plat de cerclage au joint. Extrémités : bastion ≤ +20 % de la crête ;
angles : pile du mur, merlon d'acier à peine plus haut.
"""
import math

import geo
from geo import surface

EPOQUE = 2
NOM = "Forge"
FORME = "horiz"
Z_RB, Z_W, Z_CAP, Z_M = 0.20, 0.80, 0.85, 1.00        # haut de la bande réfractaire, du talus, couronnement, merlons
HW0, HW1 = 0.46, 0.15
SQ2 = math.sqrt(2.0)
RIV = 0.016
PIED = ((0.02, 0.017, 0.014), 0.13, 0.92)            # pied sale : jusqu'à L ≈ 0,07 sur ~8 px HR


def hw(z):
    return HW0 + (HW1 - HW0) * z / Z_W


def mats(S):
    M = {}
    M["pierre"] = surface("m2_pierre", (0.115, 0.105, 0.095), (0.06, 0.055, 0.05), rough=0.92, var=0.7, var_scale=5.0,
                          grain=0.28, bump=0.8, bump_scale=40.0,
                          brick=dict(w=0.25, h=0.115, mortar=0.010, c1=(0.13, 0.12, 0.105), c2=(0.065, 0.06, 0.052),
                                     col_m=(0.03, 0.027, 0.024)),
                          edge=((0.30, 0.28, 0.24), 0.7, 0.02), cavity=0.65, streak=0.7,
                          stain=((0.025, 0.02, 0.016), 0.6, 5.0), bottom=PIED)
    M["refractaire"] = surface("m2_refr", (0.25, 0.065, 0.036), (0.12, 0.034, 0.02), rough=0.9, var=0.6, var_scale=4.0,
                               grain=0.25, bump=0.6, bump_scale=55.0,
                               brick=dict(w=0.125, h=0.05, mortar=0.012, c1=(0.27, 0.07, 0.04), c2=(0.11, 0.03, 0.018),
                                          col_m=(0.10, 0.085, 0.07)),
                               edge=((0.45, 0.24, 0.14), 0.6, 0.02), cavity=0.6, streak=0.5,
                               stain=((0.03, 0.015, 0.01), 0.6, 4.0), bottom=PIED)
    # acier #5C6168 (sRGB) ≈ (0.107, 0.120, 0.141) linéaire
    M["acier"] = surface("m2_acier", (0.107, 0.120, 0.141), (0.06, 0.062, 0.066), rough=0.48, rough2=0.75, metal=0.7,
                         var=0.6, var_scale=6.0, grain=0.22, bump=0.35, bump_scale=110.0,
                         edge=((0.42, 0.44, 0.47), 0.85, 0.015), cavity=0.5, streak=0.6,
                         stain=((0.10, 0.05, 0.025), 0.5, 7.0))
    # dessus des merlons et du couronnement : acier usé plus clair (L 0,55-0,65 éclairé)
    M["acier_dessus"] = surface("m2_acier_d", (0.30, 0.31, 0.33), (0.17, 0.175, 0.18), rough=0.55, metal=0.55, var=0.7,
                                var_scale=8.0, grain=0.25, bump=0.4, bump_scale=110.0,
                                edge=((0.60, 0.61, 0.62), 0.85, 0.015), cavity=0.5, streak=0.4,
                                stain=((0.09, 0.06, 0.04), 0.45, 7.0))
    # cerclage #2E2C2A ≈ (0.027, 0.025, 0.023)
    M["cerclage"] = surface("m2_cerclage", (0.027, 0.025, 0.023), (0.06, 0.035, 0.02), rough=0.5, metal=0.8, var=0.5,
                            grain=0.3, bump=0.4, bump_scale=120.0, edge=((0.25, 0.24, 0.22), 0.8, 0.015), cavity=0.3)
    # laiton #8C7440 ≈ (0.262, 0.178, 0.051)
    M["laiton"] = surface("m2_laiton", (0.262, 0.178, 0.051), (0.15, 0.10, 0.03), rough=0.42, metal=1.0, var=0.4,
                          grain=0.15, bump=0.0, edge=((0.5, 0.38, 0.15), 0.5, 0.01), cavity=0.3)
    M["vide"] = surface("m2_vide", (0.008, 0.006, 0.005), rough=1.0, var=0.0, grain=0.0, bump=0.0, cavity=0.0, spec=0.0)
    return M


def _plaque_talus(g, mat, x0, x1, z0, z1, k, d_out, d_in, hwf=hw):
    """Pièce plaquée sur le talus (face avant, normale -Y) de z0 à z1, en saillie d_out (unités)."""
    pa = [(x0, -(hwf(z0) * k + d_out)), (x1, -(hwf(z0) * k + d_out)), (x1, -(hwf(z0) * k - d_in)),
          (x0, -(hwf(z0) * k - d_in))]
    pb = [(x0, -(hwf(z1) * k + d_out)), (x1, -(hwf(z1) * k + d_out)), (x1, -(hwf(z1) * k - d_in)),
          (x0, -(hwf(z1) * k - d_in))]
    return g.loft_z(pa, z0, z1, mat, poly1=pb, bev=0.004)


def _tole(g, M, xa, xb, za, zb, k):
    """Tôle d'acier boulonnée sur le talus : rivets de laiton à 4 px (0,06) des bords."""
    _plaque_talus(g, M["acier"], xa, xb, za, zb, k, 0.014, 0.02)
    pts = []
    for x in (xa + 0.06, 0.5 * (xa + xb), xb - 0.06):
        for z in (za + 0.05, zb - 0.05):
            pts.append((x, -(hw(z) * k + 0.018), z, "y"))
    g.rivets(pts, RIV, M["laiton"])


def bras(g, M, B):
    k, x0, L = B.k, B.x0, B.L
    S_ = B.cote == "S"
    faces = (-1, 1) if S_ else (-1,)
    # pied en glacis (pierre), bande réfractaire, talus de pierre sombre
    g.prism([(-HW0 * k - 0.012, 0.0), (HW0 * k + 0.012, 0.0), (hw(Z_RB) * k, Z_RB), (-hw(Z_RB) * k, Z_RB)], x0, L,
            M["refractaire"], bev=0.006)
    g.prism([(-hw(Z_RB) * k, Z_RB - 0.005), (hw(Z_RB) * k, Z_RB - 0.005), (HW1 * k, Z_W), (-HW1 * k, Z_W)], x0, L,
            M["pierre"], bev=0.006)
    # cerclage sombre (3 px) au-dessus de la bande réfractaire
    za, zb = Z_RB, Z_RB + 0.045
    g.prism([(-(hw(za) * k + 0.016), za), (-(hw(zb) * k + 0.016), zb), ((hw(zb) * k + 0.016), zb),
             ((hw(za) * k + 0.016), za)], x0, L, M["cerclage"], bev=0.004)
    for s in faces:
        g.push(g.Sc(1, s, 1))
        # deux tôles boulonnées par case (une par demi-case, entre le contrefort du milieu et le joint)
        for (ta, tb) in ((0.15, 0.45),) if not S_ else ((0.06, 0.44), (0.56, 0.94)):
            sp = B.span(ta, tb)
            if sp:
                _tole(g, M, B.x(sp[0]), min(B.x(sp[1]), L), 0.30, 0.68, k)
        # plat de cerclage riveté au joint de case (t = 0,5)
        if B.t0 < 0.5 < B.t1:
            xj = B.x(0.5)
            _plaque_talus(g, M["cerclage"], xj - 0.028, xj + 0.028, 0.0, Z_W - 0.01, k, 0.016, 0.02)
            g.rivets([(xj, -(hw(z) * k + 0.02), z, "y") for z in (0.12, 0.38, 0.62)], RIV, M["laiton"])
        # éboulis au pied
        geo.eboulis(g, (M["pierre"], M["refractaire"], M["acier"]), max(x0, 0.0), L - B.eps, -HW0 * k - 0.005,
                    2 if not S_ else 4, r=0.028)
        g.pop()
    # couronnement d'acier (dessus clair) en surplomb
    g.prism([(-(HW1 + 0.04) * k, Z_W - 0.01), ((HW1 + 0.04) * k, Z_W - 0.01), ((HW1 + 0.04) * k, Z_W + 0.02),
             ((HW1 + 0.03) * k, Z_CAP), (-(HW1 + 0.03) * k, Z_CAP), (-(HW1 + 0.04) * k, Z_W + 0.02)], x0, L,
            M["acier_dessus"], bev=0.008)
    # merlons d'acier (centres 0, 0,5, 1,0 tuile ; demi-largeur 0,12), bord supérieur crénelé (2 dents)
    for c in (0.0, 0.5, 1.0):
        if c == 0.0 and not S_:
            continue
        sp = B.span(c - 0.12, c + 0.12)
        if sp:
            _merlon(g, M, B.x(sp[0]), min(B.x(sp[1]), L), k, B.x(c), -g.rnd(0.0, 0.03) if S_ else 0.0)


def _merlon(g, M, a, b, k, xc, dz=0.0, extra=0.0):
    """Merlon d'acier : corps sombre, dessus clair, deux dents sur le bord supérieur (vide au milieu)."""
    zt = Z_M + extra + dz
    g.prism([(-0.13 * k, Z_CAP - 0.01), (0.13 * k, Z_CAP - 0.01), (0.115 * k, zt - 0.035), (-0.115 * k, zt - 0.035)],
            a, b, M["acier"], bev=0.006)
    # dents : deux blocs de chaque côté du centre du merlon
    for (u0, u1) in ((xc - 0.12, xc - 0.025), (xc + 0.025, xc + 0.12)):
        lo, hi = max(a, u0), min(b, u1)
        if hi - lo > 0.01:
            g.prism([(-0.12 * k, zt - 0.04), (0.12 * k, zt - 0.04), (0.11 * k, zt), (-0.11 * k, zt)], lo, hi,
                    M["acier_dessus"], bev=0.006)


def _contrefort(g, M):
    """Contrefort de pierre au milieu de la case : 0,25 tuile au pied (16 px), 0,125 en haut, saillie 0,06 ; reste
    DANS le pied (aucune saillie au sud du pied) ; cornières d'acier aux arêtes avant."""
    k = SQ2

    def hc(z):
        return hw(z) + 0.06 * (z / Z_W) ** 0.7
    pa = [(-0.125, -hc(0.0) * k), (0.125, -hc(0.0) * k), (0.125, -0.1 * k), (-0.125, -0.1 * k)]
    pb = [(-0.0625, -hc(Z_W) * k), (0.0625, -hc(Z_W) * k), (0.0625, -0.1 * k), (-0.0625, -0.1 * k)]
    g.loft_z(pa, 0.0, Z_W, M["pierre"], poly1=pb, bev=0.008)
    for sx in (-1, 1):
        ca = [(sx * 0.125 - sx * 0.03, -hc(0.0) * k - 0.012), (sx * 0.125 + sx * 0.008, -hc(0.0) * k - 0.012),
              (sx * 0.125 + sx * 0.008, -hc(0.0) * k + 0.03), (sx * 0.125 - sx * 0.03, -hc(0.0) * k + 0.03)]
        cb = [(sx * 0.0625 - sx * 0.03, -hc(Z_W) * k - 0.012), (sx * 0.0625 + sx * 0.008, -hc(Z_W) * k - 0.012),
              (sx * 0.0625 + sx * 0.008, -hc(Z_W) * k + 0.03), (sx * 0.0625 - sx * 0.03, -hc(Z_W) * k + 0.03)]
        g.loft_z(ca if sx > 0 else ca[::-1], Z_RB, Z_W - 0.02, M["acier"], poly1=cb if sx > 0 else cb[::-1], bev=0.003)
    _merlon(g, M, -0.12, 0.12, k, 0.0, extra=0.03)


def _fente(g, M):
    """Fente de forge dans la pierre (lueur de NUIT seulement : non rendue ici) avec linteau d'acier."""
    k = SQ2
    _plaque_talus(g, M["vide"], -0.022, 0.022, 0.34, 0.62, k, 0.002, 0.04,
                  hwf=lambda z: hw(z) + 0.06 * (z / Z_W) ** 0.7)


def _barbacane(g, M):
    k = SQ2
    _plaque_talus(g, M["vide"], 0.17, 0.26, 0.04, 0.10, k, 0.003, 0.05)
    _plaque_talus(g, M["acier"], 0.15, 0.28, 0.10, 0.13, k, 0.012, 0.02)


def _pile(g, M, zt, zm_extra, bastion=False):
    """Pile carrée du mur (même talus, en tronc de pyramide) : angles et extrémités. bastion : tôles et merlons d'angle."""
    ky = SQ2
    a0, a1 = HW0 + 0.01, HW1 + 0.01

    def ha(z):
        return a0 + (a1 - a0) * z / zt

    def carre(h):
        return [(-h, -h * ky), (h, -h * ky), (h, h * ky), (-h, h * ky)]
    g.loft_z(carre(a0 + 0.012), 0.0, Z_RB, M["refractaire"], poly1=carre(ha(Z_RB)), bev=0.006)
    g.loft_z(carre(ha(Z_RB)), Z_RB - 0.005, zt, M["pierre"], poly1=carre(a1), bev=0.006)
    g.loft_z(carre(ha(Z_RB) + 0.016), Z_RB, Z_RB + 0.045, M["cerclage"], poly1=carre(ha(Z_RB + 0.045) + 0.016),
             bev=0.004)
    g.loft_z(carre(a1 + 0.04), zt - 0.01, zt + 0.05, M["acier_dessus"], poly1=carre(a1 + 0.03), bev=0.008)
    if bastion:
        # tôle boulonnée sur la face avant du bastion
        _plaque_talus(g, M["acier"], -0.26, 0.26, 0.30, 0.70, ky, 0.014, 0.02, hwf=ha)
        g.rivets([(x, -(ha(z) * ky + 0.018), z, "y") for x in (-0.2, 0.0, 0.2) for z in (0.35, 0.65)], RIV,
                 M["laiton"])
        # merlons d'acier aux 4 angles du sommet
        for sx in (-1, 1):
            for sy in (-1, 1):
                cx, cy = sx * (a1 - 0.03), sy * (a1 - 0.03) * ky
                h = 0.07
                g.box(cx - h, cx + h, cy - h * ky, cy + h * ky, zt + 0.04, zt + 0.05 + zm_extra - 0.03, M["acier"],
                      bev=0.005)
                g.box(cx - h - 0.01, cx + h + 0.01, cy - (h + 0.01) * ky, cy + (h + 0.01) * ky,
                      zt + 0.05 + zm_extra - 0.035, zt + 0.05 + zm_extra, M["acier_dessus"], bev=0.005)
        geo.eboulis(g, (M["pierre"], M["refractaire"], M["acier"]), -0.4, 0.4, -(a0 + 0.012) * ky, 3, r=0.03)
    else:
        _merlon(g, M, -0.12, 0.12, SQ2, 0.0, extra=0.05)


def noeud(g, M, forme, bras):
    if forme in ("single", "endR", "endL"):
        _pile(g, M, 0.92, 0.12, bastion=True)          # sommet ≈ +20 % de la crête des courtines
    elif forme in ("corR", "corL"):
        _pile(g, M, Z_W, 0.0)
    elif forme == "horiz":
        _contrefort(g, M)
    elif forme == "horiz2":
        _contrefort(g, M)
        _fente(g, M)
    elif forme == "horiz3":
        _contrefort(g, M)
        _barbacane(g, M)
    elif forme == "tee":
        _merlon(g, M, -0.12, 0.12, SQ2, 0.0, extra=0.03)
