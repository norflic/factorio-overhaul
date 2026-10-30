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
Z_B, Z_K, Z_A = 0.13, 0.70, 1.36       # socle, cassure des facettes, arête (e2 : plus raide)
Z_C0, Z_C1 = 1.46, 1.80                # crête flottante
SQ2 = math.sqrt(2.0)
# profil (demi-épaisseur en tuiles, z) : socle droit, corps en deux facettes
P_BAS, P_K, P_A = 0.44, 0.29, 0.06


FORME = "horiz"     # posé par piece.build : graine des fissures d'or (horiz et horiz2 différentes)
SEMIS = {"single": 1.0, "vert": 2.0, "horiz": 3.0, "horiz2": 7.0, "corR": 4.0, "corL": 5.0, "tee": 6.0, "endR": 8.0,
         "endL": 9.0}


def mats(S):
    M = {}
    M["obsidienne"] = surface("m15_obs", (0.022, 0.02, 0.026), (0.045, 0.04, 0.05), rough=0.16, rough2=0.3,
                              metal=0.0, spec=0.9, var=0.7, var_scale=5.0, grain=0.3, bump=0.15, bump_scale=30.0,
                              edge=((0.16, 0.15, 0.18), 0.5, 0.02), cavity=0.3,
                              cracks=((0.95, 0.68, 0.28), 0.022, 1.3, SEMIS.get(FORME, 0.0)))
    M["obs_mat"] = surface("m15_obsm", (0.03, 0.028, 0.034), (0.012, 0.011, 0.014), rough=0.45, metal=0.0, spec=0.6,
                           var=0.6, var_scale=9.0, grain=0.3, bump=0.3, bump_scale=60.0,
                           edge=((0.18, 0.17, 0.2), 0.6, 0.02), cavity=0.4)
    M["or"] = surface("m15_or", (0.95, 0.70, 0.30), (0.70, 0.48, 0.18), rough=0.32, rough2=0.5, metal=1.0, var=0.5,
                      var_scale=10.0, grain=0.12, bump=0.1, edge=((1.0, 0.85, 0.55), 0.4, 0.015), cavity=0.35)
    M["or_sombre"] = surface("m15_ors", (0.45, 0.30, 0.10), rough=0.35, metal=1.0, var=0.3, grain=0.1, cavity=0.3)
    M["vide"] = surface("m15_vide", (0.004, 0.003, 0.005), rough=1.0, var=0.0, grain=0.0, bump=0.0, cavity=0.0,
                        spec=0.0)
    M["feu"] = geo.emissive(S, "m15_feu", (1.0, 0.78, 0.45), strength=0.85, base=(0.05, 0.04, 0.02))
    return M


def _profil(k, inset=0.0):
    a, b, c = (P_BAS - inset) * k, (P_K - inset) * k, (P_A - inset * 0.3) * k
    return [(-a, Z_B), (a, Z_B), (b, Z_K), (c, Z_A), (-c, Z_A), (-b, Z_K)]


def bras(g, M, B):
    k, x0, L = B.k, B.x0, B.L
    S_ = B.cote == "S"
    # pied noir mat en glacis (v2 : plus de dalle à bord net), filet d'or mince (lignes est-ouest seulement),
    # éclats d'obsidienne tombés au pied
    g.prism([(-0.47 * k, 0.0), (0.47 * k, 0.0), (P_BAS * k + 0.004, Z_B), (-(P_BAS * k + 0.004), Z_B)], x0, L,
            M["obs_mat"], bev=0.006)
    if not S_:
        g.prism([(-(P_BAS * k + 0.012), Z_B - 0.012), ((P_BAS * k + 0.012), Z_B - 0.012), ((P_BAS * k + 0.008), Z_B + 0.01),
                 (-(P_BAS * k + 0.008), Z_B + 0.01)], x0, L, M["or"], bev=0.003)
    for s_ in ((-1, 1) if S_ else (-1,)):
        g.push(g.Sc(1, s_, 1))
        geo.eboulis(g, (M["obsidienne"], M["obs_mat"]), max(x0, 0.0), L - B.eps, -0.47 * k, 2, r=0.03)
        g.pop()
    # âme d'or (se voit dans les filets entre panneaux)
    g.prism(_profil(k, inset=0.012), x0, L, M["or_sombre"], bev=0)
    # panneaux d'obsidienne : un par quart de case ; filet de 0,012 ; panneau du joint de case plus étroit
    cuts = [B.t0] + [t for t in (0.5,) if B.t0 < t < B.t1 - 1e-3] + [B.t1]
    for a, b in zip(cuts[:-1], cuts[1:]):
        xa, xb = B.x(a), min(B.x(b), L)
        ia = 0.016 if a > B.t0 + 1e-3 else 0.0
        ib = 0.016 if b < B.t1 - 1e-3 else 0.0
        if abs(a - 0.5) < 1e-3:
            ia = 0.03
        if abs(b - 0.5) < 1e-3:
            ib = 0.03
        g.prism(_profil(k), xa + ia, xb - ib, M["obsidienne"], bev=0.006, ends=bool(ia or ib))
    # nervure d'or au joint de case (t = 0,5) : suit le profil, légèrement en saillie
    xj = B.x(0.5)
    if B.t0 < 0.5 < B.t1 and not S_:          # v2 : pas de nervure sur les lignes nord-sud (« rails »)
        prof = [(y * 1.0, z) for (y, z) in _profil(k, inset=-0.015)]
        g.prism(prof, xj - 0.026, xj + 0.026, M["or"], bev=0.006, ends=True)
    # crête flottante : éclats d'obsidienne en losange (un par demi-case), arête d'or, au-dessus d'un vide
    for c in (0.0, 0.5, 1.0):
        if c == 0.0 and not S_:
            continue
        _eclat(g, M, B.x(c), 0.13 * B.ka, k, B.x(B.t0), L)
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


def _eclat(g, M, xc, h, k, xa, xb):
    """Éclat flottant en losange centré en xc (demi-longueur h), borné à [xa, xb] (coupe nette au bord de case)."""
    zm = 0.5 * (Z_C0 + Z_C1)
    w = 0.05 * k

    def sec(x, f):
        return [(x, -w * f, zm), (x, w * f, zm), (x, 0.0, zm - (zm - Z_C0) * f), (x, 0.0, zm + (Z_C1 - zm) * f)]
    pts = []
    for x in (xc - h, xc, xc + h):
        f = 1.0 - abs(x - xc) / h
        if x < xa:
            x, f = xa, 1.0 - abs(xa - xc) / h
        if x > xb:
            x, f = xb, 1.0 - abs(xb - xc) / h
        if f <= 0.0:
            pts.append((x, 0.0, zm))
        else:
            pts += sec(x, f)
    if max(p[0] for p in pts) - min(p[0] for p in pts) < 0.02:
        return
    g.hull(pts, M["obsidienne"], bev=0.004, seg=1)
    # arête d'or sur le dessus de l'éclat
    top = [p for p in pts if p[2] >= zm + 1e-6] or [(xc, 0.0, Z_C1)]
    xs = [p[0] for p in pts]
    x0, x1 = max(min(xs), xc - 0.7 * h), min(max(xs), xc + 0.7 * h)
    if x1 - x0 > 0.02:
        f0, f1 = 1 - abs(x0 - xc) / h, 1 - abs(x1 - xc) / h
        g.hull([(x0, -0.012, zm + (Z_C1 - zm) * f0 - 0.01), (x0, 0.012, zm + (Z_C1 - zm) * f0 - 0.01),
                (x0, 0.0, zm + (Z_C1 - zm) * f0 + 0.012),
                (xc, -0.014, Z_C1 - 0.01) if x0 < xc < x1 else (x1, -0.012, zm + (Z_C1 - zm) * f1 - 0.01),
                (xc, 0.014, Z_C1 - 0.01) if x0 < xc < x1 else (x1, 0.012, zm + (Z_C1 - zm) * f1 - 0.01),
                (xc, 0.0, Z_C1 + 0.014) if x0 < xc < x1 else (x1, 0.0, zm + (Z_C1 - zm) * f1 + 0.012),
                (x1, -0.012, zm + (Z_C1 - zm) * f1 - 0.01), (x1, 0.012, zm + (Z_C1 - zm) * f1 - 0.01),
                (x1, 0.0, zm + (Z_C1 - zm) * f1 + 0.012)], M["or"], bev=0, seg=1)


def _aileron(g, M):
    """Aileron d'obsidienne au milieu de la case, tranche d'or, fente de feu."""
    k = SQ2
    yb = -(P_BAS + 0.16) * k
    pa = [(-0.035, yb), (0.035, yb), (0.06, -0.2 * k), (-0.06, -0.2 * k)]
    g.loft_z(pa, 0.0, 1.05, M["obsidienne"], poly1=[(-0.02, -(P_K * 0.9) * k), (0.02, -(P_K * 0.9) * k),
                                                     (0.04, -0.1 * k), (-0.04, -0.1 * k)], bev=0.006)
    # éclat flottant central (le bras n'en porte pas en t = 0)
    _eclat(g, M, 0.0, 0.13, k, -1.0, 1.0)


def _sceau(g, M):
    """Variante du segment droit : sceau d'or en losange sur la facette basse, cœur incandescent, éclat central."""
    k = SQ2
    zc = 0.42
    yf = -(P_BAS - (P_BAS - P_K) * (zc - Z_B) / (Z_K - Z_B)) * k
    r = 0.11
    g.hull([(0, yf - 0.02, zc + r), (r, yf - 0.02, zc), (0, yf - 0.02, zc - r), (-r, yf - 0.02, zc),
            (0, yf + 0.03, zc + r), (r, yf + 0.03, zc), (0, yf + 0.03, zc - r), (-r, yf + 0.03, zc)], M["or"],
           bev=0.006, seg=1)
    r2 = 0.06
    g.hull([(0, yf - 0.03, zc + r2), (r2, yf - 0.03, zc), (0, yf - 0.03, zc - r2), (-r2, yf - 0.03, zc),
            (0, yf - 0.015, zc + r2), (r2, yf - 0.015, zc), (0, yf - 0.015, zc - r2), (-r2, yf - 0.015, zc)],
           M["obs_mat"], bev=0.003, seg=1)
    g.box(-0.016, 0.016, yf - 0.036, yf - 0.02, zc - 0.035, zc + 0.035, M["feu"], bev=0)
    _eclat(g, M, 0.0, 0.13, k, -1.0, 1.0)


def _obelisque(g, M):
    """Obélisque facetté (8 faces), coiffe d'or, orbe noir laqué en lévitation dans un anneau d'or."""
    ky = SQ2
    def octo(r, ry):
        return [(r * math.cos(a), ry * math.sin(a)) for a in [math.pi / 8 + i * math.pi / 4 for i in range(8)]]
    # pied octogonal en glacis (v2 : plus de dalle carrée), anneau d'or mince, éclats tombés
    g.loft_z(octo(0.52, 0.52 * ky), 0.0, Z_B + 0.01, M["obs_mat"], poly1=octo(0.475, 0.475 * ky), bev=0.006)
    g.loft_z(octo(0.482, 0.482 * ky), Z_B - 0.004, Z_B + 0.016, M["or"], bev=0.003)
    geo.eboulis(g, (M["obsidienne"], M["obs_mat"]), -0.4, 0.4, -0.5 * ky, 3, r=0.035)
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
    elif forme == "horiz2":
        _sceau(g, M)
    elif forme == "tee":
        _eclat(g, M, 0.0, 0.13, SQ2, -1.0, 1.0)
