"""Mur · Âge 15 · NÉANT (ère V). MUR-OPUS v3, 30/10. S'exécute DANS Blender.

DA : docs/DESIGN_EPOQUES.md (époque 15) : « plinthe et créneaux flottants en or blanc ; vides entre les merlons et sous
la crête » ; or blanc #E8DCB0, nacre #D8D2C8 ; flèche de couronne ; et ADN de la mitrailleuse validée de l'âge 15
(plaques noires rivetées, bandes d'or, sphère noire cerclée d'or). Arbitrage de l'orchestrateur (30/10) : lisible par
le HAUT (crête claire, p95 ≥ 0,60), plinthe sombre (L ≤ 0,30).
Section en COIN (même profil est-ouest et nord-sud). Façade : 2 plaques noires laquées par case, joints de 1 px, rivets
d'or, deux bandes d'or ; couronnement de nacre ; au-dessus, VIDE lumineux (fissure blanc-or) puis créneaux flottants en
or blanc (2 par case). Milieu de case : flèche de couronne sur la crête. Extrémités : obélisque ≤ +20 %, petit orbe
noir cerclé d'or ; angles : pile du mur, merlon flottant.
"""
import math

import geo
from geo import surface

EPOQUE = 15
NOM = "Néant"
FORME = "horiz"
Z_PL, Z_W, Z_CAP = 0.12, 0.88, 0.93          # plinthe, haut du talus, dessus du couronnement de nacre
Z_F0, Z_F1 = 1.02, 1.16                      # créneaux flottants (vide de 0,09 sous eux)
HW0, HW1 = 0.49, 0.13       # v4 : talus concave
SQ2 = math.sqrt(2.0)
RIV = 0.016
PIED = ((0.004, 0.004, 0.005), 0.20, 1.0)


def hw(z):
    if z <= Z_PL:
        return HW0 + (0.40 - HW0) * z / Z_PL
    return 0.40 + (HW1 - 0.40) * min(1.0, (z - Z_PL) / (Z_W - Z_PL))


def mats(S):
    M = {}
    M["laque"] = surface("m15_laque", (0.05, 0.045, 0.042), (0.028, 0.025, 0.023), rough=0.22, rough2=0.4, metal=0.0,
                         spec=0.8, var=0.6, var_scale=5.0, grain=0.25, bump=0.15, bump_scale=60.0,
                         edge=((0.22, 0.21, 0.24), 0.7, 0.015), cavity=0.5, streak=0.35,
                         stain=((0.006, 0.006, 0.007), 0.5, 6.0), bottom=PIED)
    # or patiné sombre de la plinthe (L ≤ 0,30)
    M["or_patine"] = surface("m15_orp", (0.20, 0.13, 0.045), (0.08, 0.055, 0.02), rough=0.55, metal=0.9, var=0.7,
                             var_scale=8.0, grain=0.25, bump=0.3, bump_scale=80.0, edge=((0.45, 0.32, 0.12), 0.6, 0.015),
                             cavity=0.5, stain=((0.02, 0.018, 0.015), 0.6, 6.0), bottom=PIED)
    M["or"] = surface("m15_or", (0.80, 0.58, 0.22), (0.60, 0.42, 0.15), rough=0.32, rough2=0.45, metal=0.5, var=0.5,
                      var_scale=10.0, grain=0.12, bump=0.1, edge=((1.0, 0.85, 0.55), 0.4, 0.015), cavity=0.35)
    # or blanc #E8DCB0 ≈ (0.807, 0.716, 0.431) ; nacre #D8D2C8 ≈ (0.686, 0.644, 0.578)
    M["or_blanc"] = surface("m15_orb", (0.50, 0.53, 0.58), (0.36, 0.38, 0.42), rough=0.3, rough2=0.42, metal=0.4,
                            var=0.5, var_scale=9.0, grain=0.12, bump=0.1, edge=((1.0, 0.95, 0.8), 0.5, 0.015),
                            cavity=0.4)
    M["nacre"] = surface("m15_nacre", (0.46, 0.50, 0.56), (0.33, 0.36, 0.41), rough=0.35, metal=0.1, spec=0.7,
                         var=0.6, var_scale=7.0, grain=0.15, bump=0.15, bump_scale=60.0,
                         edge=((0.9, 0.88, 0.84), 0.5, 0.015), cavity=0.45, streak=0.3,
                         stain=((0.32, 0.30, 0.27), 0.4, 6.0))
    M["obsidienne"] = surface("m15_obs", (0.042, 0.038, 0.036), (0.06, 0.054, 0.05), rough=0.16, rough2=0.3, spec=0.9,
                              var=0.7, var_scale=5.0, grain=0.3, bump=0.15, edge=((0.16, 0.15, 0.18), 0.5, 0.02),
                              cavity=0.3)
    M["feu"] = geo.emissive(S, "m15_feu", (1.0, 0.80, 0.50), strength=0.35, base=(0.05, 0.04, 0.02))
    return M


def _plaque(g, mat, x0, x1, z0, z1, k, d_out, d_in):
    pa = [(x0, -(hw(z0) * k + d_out)), (x1, -(hw(z0) * k + d_out)), (x1, -(hw(z0) * k - d_in)), (x0, -(hw(z0) * k - d_in))]
    pb = [(x0, -(hw(z1) * k + d_out)), (x1, -(hw(z1) * k + d_out)), (x1, -(hw(z1) * k - d_in)), (x0, -(hw(z1) * k - d_in))]
    return g.loft_z(pa, z0, z1, mat, poly1=pb, bev=0.004)


def _merlon_flottant(g, M, a, b, k, gap_glow=True):
    """Créneau flottant en or blanc au-dessus du couronnement ; fissure de feu dans le vide dessous."""
    g.prism([(-0.13 * k, Z_F0), (0.13 * k, Z_F0), (0.13 * k, Z_F1 - 0.03), (0.10 * k, Z_F1), (-0.10 * k, Z_F1),
             (-0.13 * k, Z_F1 - 0.03)], a, b, M["or_blanc"], bev=0.008, ends=True)


def bras(g, M, B):
    k, x0, L = B.k, B.x0, B.L
    S_ = B.cote == "S"
    # plinthe d'or patiné en glacis (sombre), talus de laque noire
    g.prism([(-HW0 * k - 0.012, 0.0), (HW0 * k + 0.012, 0.0), (hw(Z_PL) * k + 0.006, Z_PL),
             (-(hw(Z_PL) * k + 0.006), Z_PL)], x0, L, M["or_patine"], bev=0.005)
    g.prism([(-hw(Z_PL) * k, Z_PL - 0.005), (hw(Z_PL) * k, Z_PL - 0.005), (HW1 * k, Z_W), (-HW1 * k, Z_W)], x0, L,
            M["obsidienne"], bev=0.004)
    for s in ((1, -1) if S_ else (1,)):
        g.push(g.Sc(1, s, 1))
        # deux plaques laquées par case (joints de 1 px : 0,016), rivets d'or aux coins
        bornes = (0.0, 0.5, 1.0) if S_ else (0.0, 0.5)
        for ta, tb in zip(bornes[:-1], bornes[1:]):
            sp = B.span(ta + 0.008, tb - 0.008)
            if not sp:
                continue
            xa, xb = B.x(sp[0]), min(B.x(sp[1]), L)
            _plaque(g, M["laque"], xa, xb, Z_PL + 0.015, Z_W - 0.02, k, 0.012, 0.02)
            g.rivets([(x, -(hw(z) * k + 0.016), z, "y") for x in (xa + 0.05, xb - 0.05) for z in (Z_PL + 0.06, Z_W - 0.07)
                      if xb - xa > 0.12], RIV, M["or"])
        # deux bandes d'or (2 px) à travers les plaques
        for zb in (0.50,):
            _plaque(g, M["or"], x0, L, zb, zb + 0.03, k, 0.018, 0.02)
        geo.eboulis(g, (M["obsidienne"], M["laque"]), max(x0, 0.0), L - B.eps, -HW0 * k - 0.005, 2, r=0.028)
        g.pop()
    # couronnement de nacre (dessus clair, ~10-12 px HR) et fissure de feu sur son dessus (dans le vide)
    g.prism([(-(HW1 + 0.03) * k, Z_W - 0.01), ((HW1 + 0.03) * k, Z_W - 0.01), ((HW1 + 0.03) * k, Z_W + 0.02),
             ((HW1 + 0.01) * k, Z_CAP), (-(HW1 + 0.01) * k, Z_CAP), (-(HW1 + 0.03) * k, Z_W + 0.02)], x0, L,
            M["nacre"], bev=0.008)
    g.prism([(-0.02 * k, Z_CAP - 0.004), (0.02 * k, Z_CAP - 0.004), (0.012 * k, Z_CAP + 0.01),
             (-0.012 * k, Z_CAP + 0.01)], x0, L, M["feu"], bev=0)
    # créneaux flottants : centres 0, 0,5, 1,0 tuile, demi-largeur 0,12
    for c in (0.5,):                       # v4 : un créneau flottant par case (au joint), moins de « palissade »
        sp = B.span(c - 0.12, c + 0.12)
        if sp:
            _merlon_flottant(g, M, B.x(sp[0]), min(B.x(sp[1]), L), k)


def _fleche(g, M, h=0.30):
    """Flèche de couronne (≥ 4 px de large) posée sur la crête, au centre de la case."""
    k = SQ2
    _merlon_flottant(g, M, -0.12, 0.12, k)
    w = 0.045
    g.hull([(-w, -w * k, Z_F1 - 0.01), (w, -w * k, Z_F1 - 0.01), (w, w * k, Z_F1 - 0.01), (-w, w * k, Z_F1 - 0.01),
            (0.0, 0.0, Z_F1 + h)], M["or_blanc"], bev=0.004, seg=1)


def _contrefort(g, M):
    """Contrefort noir au milieu de la case, dans le pied, arêtes d'or."""
    k = SQ2

    def hc(z):
        return hw(z) + 0.05 * (z / Z_W) ** 0.7
    pa = [(-0.1, -hc(0.0) * k), (0.1, -hc(0.0) * k), (0.1, -0.1 * k), (-0.1, -0.1 * k)]
    pb = [(-0.05, -hc(Z_W) * k), (0.05, -hc(Z_W) * k), (0.05, -0.1 * k), (-0.05, -0.1 * k)]
    g.loft_z(pa, Z_PL, Z_W, M["laque"], poly1=pb, bev=0.008)
    g.loft_z([(-0.012, -hc(Z_PL) * k - 0.012), (0.012, -hc(Z_PL) * k - 0.012), (0.012, -hc(Z_PL) * k + 0.02),
              (-0.012, -hc(Z_PL) * k + 0.02)], Z_PL, Z_W - 0.02, M["or"],
             poly1=[(-0.012, -hc(Z_W) * k - 0.012), (0.012, -hc(Z_W) * k - 0.012), (0.012, -hc(Z_W) * k + 0.02),
                    (-0.012, -hc(Z_W) * k + 0.02)], bev=0)


def _sceau(g, M):
    """Sceau d'or en losange sur la plaque (variante), cœur de feu."""
    k = SQ2
    zc, r = 0.50, 0.075
    yf = -(hw(zc) * k + 0.014)
    g.hull([(0, yf - 0.012, zc + r), (r, yf - 0.012, zc), (0, yf - 0.012, zc - r), (-r, yf - 0.012, zc),
            (0, yf + 0.03, zc + r), (r, yf + 0.03, zc), (0, yf + 0.03, zc - r), (-r, yf + 0.03, zc)], M["or"],
           bev=0.005, seg=1)
    g.box(-0.014, 0.014, yf - 0.022, yf - 0.008, zc - 0.03, zc + 0.03, M["feu"], bev=0)


def _pile(g, M, zt, obelisque=False):
    ky = SQ2
    a0, a1 = HW0 + 0.012, HW1 + 0.01

    def ha(z):
        return a0 + (a1 - a0) * z / zt

    def carre(h):
        return [(-h, -h * ky), (h, -h * ky), (h, h * ky), (-h, h * ky)]
    g.loft_z(carre(a0), 0.0, Z_PL, M["or_patine"], poly1=carre(ha(Z_PL)), bev=0.005)
    g.loft_z(carre(ha(Z_PL)), Z_PL - 0.005, zt, M["laque"], poly1=carre(a1), bev=0.006)
    for zb in (0.50,):
        g.loft_z(carre(ha(zb) + 0.016), zb, zb + 0.03, M["or"], poly1=carre(ha(zb + 0.03) + 0.016), bev=0.003)
    g.loft_z(carre(a1 + 0.03), zt - 0.01, zt + 0.05, M["nacre"], poly1=carre(a1 + 0.015), bev=0.008)
    if obelisque:
        # flèche d'obélisque (or blanc) et petit orbe noir cerclé d'or en lévitation
        g.loft_z(carre(0.07), zt + 0.05, zt + 0.22, M["or_blanc"], poly1=carre(0.012), bev=0.003)
        g.sphere((0, 0, zt + 0.33), 0.075, M["obsidienne"], seg=24, rings=12)
        g.S.torus(0.11, 0.012, (0, 0, zt + 0.33), M["or"], rot=(math.radians(62), 0, math.radians(18)), major_seg=40,
                  minor_seg=6)
        geo.eboulis(g, (M["obsidienne"], M["laque"]), -0.4, 0.4, -a0 * ky, 3, r=0.03)
    else:
        _merlon_flottant(g, M, -0.12, 0.12, SQ2)


def noeud(g, M, forme, bras):
    if forme in ("single", "endR", "endL"):
        _pile(g, M, 0.98, obelisque=True)
    elif forme in ("corR", "corL"):
        _pile(g, M, Z_W)
    elif forme == "horiz":
        _contrefort(g, M)
        _fleche(g, M)
    elif forme == "horiz2":
        _fleche(g, M, h=0.22)
        _sceau(g, M)
    elif forme == "horiz3":
        _contrefort(g, M)
