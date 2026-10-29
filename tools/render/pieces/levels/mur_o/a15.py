"""Mur · Âge 15 · NÉANT (ère V). MUR-OPUS, 29/10. S'exécute DANS Blender.

Un rempart d'obsidienne : socle noir à bandeau d'or, corps à FACETTES qui monte en lame (arête vive), panneaux noirs
laqués séparés par des filets d'or, nervure d'or plus forte au joint de case. Au-dessus de l'arête, une CRÊTE FLOTTANTE
(lames d'obsidienne à tranche d'or, séparées du mur par un vide où luit une fissure d'incandescence blanc-or : la
lumière de l'âge). Milieu de case : aileron d'obsidienne à tranche d'or. Extrémités et angles : OBÉLISQUE facetté,
coiffe d'or, et au-dessus, en lévitation, un orbe noir laqué ceint d'un anneau d'or (écho du dôme de la mitrailleuse
validée de l'âge 15 : noir laqué, or, incandescence).
"""
import math

import geo
from geo import surface

EPOQUE = 15
NOM = "Néant"
Z_B, Z_K, Z_A = 0.13, 0.86, 1.42       # socle, cassure des facettes, arête
Z_C0, Z_C1 = 1.52, 1.72                # crête flottante
SQ2 = math.sqrt(2.0)
# profil (demi-épaisseur en tuiles, z) : socle droit, corps en deux facettes
P_BAS, P_K, P_A = 0.44, 0.38, 0.05


def mats(S):
    M = {}
    M["obsidienne"] = surface("m15_obs", (0.014, 0.013, 0.016), (0.03, 0.026, 0.034), rough=0.16, rough2=0.3,
                              metal=0.0, spec=0.9, var=0.7, var_scale=5.0, grain=0.3, bump=0.15, bump_scale=30.0,
                              edge=((0.16, 0.15, 0.18), 0.5, 0.02), cavity=0.3)
    M["obs_mat"] = surface("m15_obsm", (0.03, 0.028, 0.034), (0.012, 0.011, 0.014), rough=0.45, metal=0.0, spec=0.6,
                           var=0.6, var_scale=9.0, grain=0.3, bump=0.3, bump_scale=60.0,
                           edge=((0.18, 0.17, 0.2), 0.6, 0.02), cavity=0.4)
    M["or"] = surface("m15_or", (0.80, 0.55, 0.20), (0.55, 0.36, 0.12), rough=0.28, rough2=0.42, metal=1.0, var=0.5,
                      var_scale=10.0, grain=0.12, bump=0.1, edge=((1.0, 0.85, 0.55), 0.4, 0.015), cavity=0.35)
    M["or_sombre"] = surface("m15_ors", (0.45, 0.30, 0.10), rough=0.35, metal=1.0, var=0.3, grain=0.1, cavity=0.3)
    M["vide"] = surface("m15_vide", (0.004, 0.003, 0.005), rough=1.0, var=0.0, grain=0.0, bump=0.0, cavity=0.0,
                        spec=0.0)
    M["feu"] = geo.emissive(S, "m15_feu", (1.0, 0.86, 0.6), strength=7.0, base=(0.05, 0.04, 0.02))
    return M


def _profil(k, inset=0.0):
    a, b, c = (P_BAS - inset) * k, (P_K - inset) * k, (P_A - inset * 0.3) * k
    return [(-a, Z_B), (a, Z_B), (b, Z_K), (c, Z_A), (-c, Z_A), (-b, Z_K)]


def bras(g, M, B):
    k, x0, L = B.k, B.x0, B.L
    S_ = B.cote == "S"
    # socle noir mat et bandeau d'or
    g.prism([(-0.47 * k, 0.0), (0.47 * k, 0.0), (0.47 * k, Z_B - 0.025), (-0.47 * k, Z_B - 0.025)], x0, L,
            M["obs_mat"], bev=0.008)
    g.prism([(-0.475 * k, Z_B - 0.025), (0.475 * k, Z_B - 0.025), (0.46 * k, Z_B + 0.005), (-0.46 * k, Z_B + 0.005)],
            x0, L, M["or"], bev=0.004)
    # âme d'or (se voit dans les filets entre panneaux)
    g.prism(_profil(k, inset=0.012), x0, L, M["or_sombre"], bev=0)
    # panneaux d'obsidienne : un par quart de case ; filet de 0,012 ; panneau du joint de case plus étroit
    cuts = [B.t0] + [t for t in (0.25, 0.5, 0.75) if B.t0 < t < B.t1 - 1e-3] + [B.t1]
    for a, b in zip(cuts[:-1], cuts[1:]):
        xa, xb = B.x(a), min(B.x(b), L)
        ia = 0.008 if a > B.t0 + 1e-3 else 0.0
        ib = 0.008 if b < B.t1 - 1e-3 else 0.0
        if abs(a - 0.5) < 1e-3:
            ia = 0.02
        if abs(b - 0.5) < 1e-3:
            ib = 0.02
        g.prism(_profil(k), xa + ia, xb - ib, M["obsidienne"], bev=0.006, ends=bool(ia or ib))
    # nervure d'or au joint de case (t = 0,5) : suit le profil, légèrement en saillie
    xj = B.x(0.5)
    if B.t0 < 0.5 < B.t1:
        prof = [(y * 1.0, z) for (y, z) in _profil(k, inset=-0.015)]
        g.prism(prof, xj - 0.016, xj + 0.016, M["or"], bev=0.004, ends=True)
    # crête flottante : lames d'obsidienne (une par demi-case), tranche d'or, fissure de feu dessous
    for c in (0.0, 0.5, 1.0):
        sp = B.span(c - 0.21, c + 0.21) if (c > 0.0 or S_) else None
        if not sp:
            continue
        xa, xb = B.x(sp[0]), min(B.x(sp[1]), L)
        ta = 0.03 if sp[0] > B.t0 + 1e-3 and abs(sp[0] - (c - 0.21)) < 1e-6 else 0.0
        tb = 0.03 if sp[1] < B.t1 - 1e-3 and abs(sp[1] - (c + 0.21)) < 1e-6 else 0.0
        g.prism([(-0.06 * k, Z_C0), (0.06 * k, Z_C0), (0.035 * k, Z_C1 - 0.03), (0.0, Z_C1),
                 (-0.035 * k, Z_C1 - 0.03)], xa + ta, xb - tb, M["obsidienne"], bev=0.004, ends=True)
        g.prism([(-0.012 * k, Z_C1 - 0.02), (0.012 * k, Z_C1 - 0.02), (0.0, Z_C1 + 0.012)], xa + ta, xb - tb,
                M["or"], bev=0, ends=True)
    # fissure d'incandescence sur l'arête (continue)
    g.prism([(-0.018 * k, Z_A - 0.004), (0.018 * k, Z_A - 0.004), (0.01 * k, Z_A + 0.012), (-0.01 * k, Z_A + 0.012)],
            x0, L, M["feu"], bev=0)
    # boulons d'or sur le bandeau (face avant ; deux flancs du bras sud)
    for s in ((-1, 1) if S_ else (-1,)):
        g.push(g.Sc(1, s, 1))
        n = int(round(B.Lt / 0.125))
        g.rivets([(B.x((i + 0.5) * 0.125), -0.462 * k - 0.004, Z_B - 0.01, "y") for i in range(n)
                  if B.t0 < (i + 0.5) * 0.125 < B.t1], 0.011, M["or"])
        g.pop()


def _aileron(g, M):
    """Aileron d'obsidienne au milieu de la case, tranche d'or, fente de feu."""
    k = SQ2
    yb = -(P_BAS + 0.16) * k
    pa = [(-0.035, yb), (0.035, yb), (0.06, -0.2 * k), (-0.06, -0.2 * k)]
    g.loft_z(pa, 0.0, 1.05, M["obsidienne"], poly1=[(-0.02, -(P_K * 0.9) * k), (0.02, -(P_K * 0.9) * k),
                                                     (0.04, -0.1 * k), (-0.04, -0.1 * k)], bev=0.006)
    # tranche d'or (arête avant)
    g.loft_z([(-0.012, yb - 0.012), (0.012, yb - 0.012), (0.012, yb + 0.02), (-0.012, yb + 0.02)], Z_B, 1.05,
             M["or"], poly1=[(-0.01, -(P_K * 0.9) * k - 0.012), (0.01, -(P_K * 0.9) * k - 0.012),
                             (0.01, -(P_K * 0.9) * k + 0.02), (-0.01, -(P_K * 0.9) * k + 0.02)], bev=0)
    # fente de feu de part et d'autre de l'aileron
    for s in (-1, 1):
        x = s * 0.1
        y = -(P_BAS - (P_BAS - P_K) * (0.55 - Z_B) / (Z_K - Z_B)) * k
        g.box(x - 0.012, x + 0.012, y - 0.004, y + 0.03, 0.40, 0.70, M["vide"], bev=0)
        g.box(x - 0.007, x + 0.007, y - 0.006, y + 0.02, 0.43, 0.67, M["feu"], bev=0)
    # lame flottante centrale (le bras n'en porte pas en t = 0)
    g.prism([(-0.06 * k, Z_C0), (0.06 * k, Z_C0), (0.035 * k, Z_C1 - 0.03), (0.0, Z_C1), (-0.035 * k, Z_C1 - 0.03)],
            -0.18, 0.18, M["obsidienne"], bev=0.004, ends=True)
    g.prism([(-0.012 * k, Z_C1 - 0.02), (0.012 * k, Z_C1 - 0.02), (0.0, Z_C1 + 0.012)], -0.18, 0.18, M["or"], bev=0,
            ends=True)


def _obelisque(g, M):
    """Obélisque facetté (8 faces), coiffe d'or, orbe noir laqué en lévitation dans un anneau d'or."""
    ky = SQ2
    # socle carré à bandeau d'or
    g.loft_z([(-0.49, -0.49 * ky), (0.49, -0.49 * ky), (0.49, 0.49 * ky), (-0.49, 0.49 * ky)], 0.0, Z_B - 0.025,
             M["obs_mat"], bev=0.01)
    g.loft_z([(-0.495, -0.495 * ky), (0.495, -0.495 * ky), (0.495, 0.495 * ky), (-0.495, 0.495 * ky)], Z_B - 0.025,
             Z_B + 0.01, M["or"], poly1=[(-0.48, -0.48 * ky), (0.48, -0.48 * ky), (0.48, 0.48 * ky),
                                         (-0.48, 0.48 * ky)], bev=0.004)

    def octo(r, ry):
        return [(r * math.cos(a), ry * math.sin(a)) for a in [math.pi / 8 + i * math.pi / 4 for i in range(8)]]
    # fût facetté en deux tronçons (cassure dorée)
    g.loft_z(octo(0.47, 0.47 * ky), Z_B + 0.01, 0.95, M["obsidienne"], poly1=octo(0.36, 0.36 * ky), bev=0.008)
    g.loft_z(octo(0.375, 0.375 * ky), 0.95, 1.0, M["or"], bev=0.004)
    g.loft_z(octo(0.34, 0.34 * ky), 1.0, 1.62, M["obsidienne"], poly1=octo(0.14, 0.14 * ky), bev=0.006)
    g.loft_z(octo(0.15, 0.15 * ky), 1.62, 1.70, M["or"], poly1=octo(0.02, 0.02 * ky), bev=0.003)
    # filets d'or sur les arêtes avant (deux arêtes face au sud)
    for a in (-3 * math.pi / 8, -5 * math.pi / 8):
        for (z0, z1, r0, r1) in ((Z_B + 0.01, 0.95, 0.47, 0.36), (1.0, 1.62, 0.34, 0.14)):
            p0 = (r0 * math.cos(a), r0 * ky * math.sin(a), z0)
            p1 = (r1 * math.cos(a), r1 * ky * math.sin(a), z1)
            w = 0.012
            g.hull([(p0[0] - w, p0[1] - w, p0[2]), (p0[0] + w, p0[1] - w, p0[2]), (p0[0], p0[1] + w, p0[2]),
                    (p1[0] - w, p1[1] - w, p1[2]), (p1[0] + w, p1[1] - w, p1[2]), (p1[0], p1[1] + w, p1[2])],
                   M["or"], bev=0)
    # fissure de feu sur la face avant
    y = -0.415 * ky * math.sin(3 * math.pi / 8) * 0.98
    g.box(-0.018, 0.018, y - 0.01, y + 0.04, 0.32, 0.80, M["vide"], bev=0)
    g.box(-0.009, 0.009, y - 0.013, y + 0.02, 0.35, 0.77, M["feu"], bev=0)
    # orbe en lévitation et anneau d'or
    g.sphere((0, 0, 1.95), 0.15, M["obsidienne"], seg=32, rings=16)
    g.S.torus(0.215, 0.016, (0, 0, 1.95), M["or"], rot=(math.radians(62), 0, math.radians(18)), major_seg=48,
              minor_seg=8)



def noeud(g, M, forme, bras):
    if forme in ("single", "corR", "corL", "endR", "endL"):
        _obelisque(g, M)
    elif forme == "horiz":
        _aileron(g, M)
    elif forme == "tee":
        g.prism([(-0.06 * SQ2, Z_C0), (0.06 * SQ2, Z_C0), (0.035 * SQ2, Z_C1 - 0.03), (0.0, Z_C1),
                 (-0.035 * SQ2, Z_C1 - 0.03)], -0.18, 0.18, M["obsidienne"], bev=0.004, ends=True)
