"""IXION, expérimental de l'âge 13 (Fusion) : une ROUE DE FEU de 45 tuiles de haut à l'écran. Lot RB-V0, 31/10.

Aucune patte, aucun canon central : un tokamak dressé sur la tranche, qui roule. La bible de l'âge 13 (DESIGN_EPOQUES,
époque 13 : tore de plasma, sphère de confinement, céramique blanche et cuivre, plasma magenta à cœur orange) est mise à
la verticale : le tore EST la roue, la sphère EST le moyeu.
- Jante : coque de céramique en plaques, bobines de cuivre en D tous les 20°, rainure intérieure où court le plasma,
  anneau de plasma visible sur chaque flanc, bande de roulement en chevrons (36 × 2 pavés) qui fait une roue dentée.
- Moyeu : soleil captif dans une cage de plaques, anneaux armillaires, rayons tendus croisés (roue de vélo : le vide
  occupe l'essentiel de la silhouette), 2 volants gyroscopiques au bout de l'essieu.
- 2 side-cars pendus à l'essieu (ils ne tournent pas) : tours de commandement à étages, ponts, canons à plasma.

Repère LOCAL : x = sens de marche, y = essieu, z = haut. PSI : lacet (la marche vient vers le sud-est). FO_GRIS=1 : masses.
"""
import math
import os

import geo as G
import greb as R
import mat as MT

PSI = -math.radians(38.0)      # assez de biais pour que le soleil traverse la roue : l'ombre garde ses vides
# ART-GEANTS (11/11, F525) : FO_IXION_CAP = cap de marche en degrés (0 = nord, sens horaire) des feuilles multidirectionnelles
# (feuilles_ixion_dirs.py) ; x local = sens de marche, donc PSI = 90° - cap. Sans la variable : -38°, la vue unique du 1/11 (cap 128°).
if os.environ.get("FO_IXION_CAP"):
    PSI = math.radians(90.0 - float(os.environ["FO_IXION_CAP"]))
R_EXT = 28.0                  # rayon extérieur de la coque
DENT = 1.7                    # hauteur des pavés
ZC = R_EXT + DENT - 0.3       # axe (la roue mord un peu le sol)
W = 3.8                       # demi-largeur de la jante
KE = 0.85                     # échelle générale : 50 tuiles de haut à l'écran
GRIS = os.environ.get("FO_GRIS", "") == "1"


def XF(v):
    p = G.rot_z(v, PSI)
    return (p[0] * KE, p[1] * KE, max(0.0, p[2] * KE))


def P(th, r, a):
    return (r * math.cos(th), a, ZC + r * math.sin(th))


def arc(th0, th1, r0, r1, a0, a1, pas=1.0, n=None):
    """Bloc courbe fermé de la jante (θ, rayon, axial)."""
    n = n or max(2, int(abs(th1 - th0) * r1 / pas) + 1)
    rings = []
    for i in range(n + 1):
        t = th0 + (th1 - th0) * i / float(n)
        rings.append([P(t, r0, a0), P(t, r1, a0), P(t, r1, a1), P(t, r0, a1)])
    return G.loft(rings, True, True)


def pose_mur(mesh, th, r, s, a=W):
    """Maille modélisée à plat (X tangente, Y radial, Z sortant du flanc) posée sur le flanc s (±1) au rayon r."""
    c = P(th, r, s * a)
    t = (-math.sin(th), 0.0, math.cos(th))
    n = (math.cos(th), 0.0, math.sin(th))
    o = (0.0, float(s), 0.0)
    v, f, u = mesh
    return [G.add(c, G.add(G.add(G.mul(t, q[0]), G.mul(n, q[1])), G.mul(o, q[2]))) for q in v], f, u


def calotte(c, la0, la1, lo0, lo1, r0, r1, n=8):
    """Plaque de sphère fermée (latitudes la, longitudes lo, rayons r0 < r1) autour de c (axe du tour : x)."""
    def q(la, lo, r):
        return (c[0] + r * math.sin(la), c[1] + r * math.cos(la) * math.cos(lo), c[2] + r * math.cos(la) * math.sin(lo))
    rings = []
    for i in range(n + 1):
        la = la0 + (la1 - la0) * i / float(n)
        ring = [q(la, lo0 + (lo1 - lo0) * j / float(n), r1) for j in range(n + 1)]
        ring += [q(la, lo1 - (lo1 - lo0) * j / float(n), r0) for j in range(n + 1)]
        rings.append(ring)
    return G.loft(rings, True, True)


def matieres(S):
    def surf(name, col, **kw):
        if GRIS:
            return MT.surface("ix_g_" + name, (0.2, 0.2, 0.2), rough=0.6, met=0.1, usure=0.3, crasse=0.6, graine=kw.get("graine", 0))
        return MT.surface("ix_" + name, col, **kw)
    MT.ECH[0] = 3.0
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.12, ra=0.2, ec=0.22, nu_k=1.25, ec_col=(0.075, 0.05, 0.03), sans=("cuivre", "plasma"))
    M = {}
    M["cera"] = surf("cera", (0.6, 0.58, 0.52), rough=0.42, met=0.0, tole=(2.3, 1.15), joint=0.45, joint_l=0.012, var=0.09, coulures=0.7,
                     rouille=(0.09, 0.06, 0.035), usure=0.45, nu=(0.78, 0.76, 0.7), crasse=0.6, crasse_col=(0.03, 0.022, 0.015), relief=0.5, graine=1)
    M["cera2"] = surf("cera2", (0.36, 0.34, 0.3), rough=0.45, met=0.0, tole=(1.2, 0.8), joint=0.45, joint_l=0.02, var=0.14, coulures=0.7,
                      rouille=(0.07, 0.045, 0.025), usure=0.5, nu=(0.62, 0.6, 0.54), crasse=0.65, crasse_col=(0.022, 0.016, 0.011), relief=0.5, graine=2)
    M["cera3"] = surf("cera3", (0.74, 0.71, 0.64), rough=0.38, met=0.0, coulures=0.5, rouille=(0.12, 0.08, 0.045), usure=0.4,
                      nu=(0.86, 0.84, 0.78), crasse=0.5, crasse_col=(0.035, 0.026, 0.017), graine=3)
    M["brule"] = surf("brule", (0.075, 0.056, 0.044), rough=0.65, met=0.4, coulures=0.4, rouille=(0.09, 0.04, 0.02), usure=0.7,
                      nu=(0.3, 0.26, 0.22), crasse=0.8, crasse_col=(0.004, 0.003, 0.002), graine=4)
    M["noyau"] = surf("noyau", (0.05, 0.045, 0.04), rough=0.55, met=0.6, usure=0.3, crasse=0.8, crasse_col=(0.002, 0.002, 0.002), graine=5)
    M["cuivre"] = surf("cuivre", (0.3, 0.11, 0.04), rough=0.36, met=0.88, coulures=0.5,
                       rouille=(0.05, 0.11, 0.08), usure=0.65, nu=(0.78, 0.46, 0.26), crasse=0.75, crasse_col=(0.01, 0.005, 0.003), graine=6)
    M["cuivre2"] = surf("cuivre2", (0.2, 0.075, 0.028), rough=0.4, met=0.85, coulures=0.4, rouille=(0.05, 0.1, 0.07), usure=0.55,
                        nu=(0.7, 0.4, 0.2), crasse=0.75, crasse_col=(0.01, 0.005, 0.003), graine=7)
    M["acier"] = surf("acier", (0.12, 0.11, 0.1), rough=0.5, met=0.6, coulures=0.4, rouille=(0.08, 0.04, 0.02), usure=0.6, nu=(0.34, 0.32, 0.3),
                      crasse=0.7, crasse_col=(0.006, 0.005, 0.004), graine=8)
    M["pont"] = surf("pont", (0.1, 0.085, 0.07), rough=0.7, met=0.3, tole=(0.9, 0.9), joint=0.4, joint_l=0.03, var=0.3, usure=0.5, nu=(0.2, 0.18, 0.15),
                     crasse=0.8, crasse_col=(0.004, 0.003, 0.002), relief=0.5, graine=9)
    M["or_riv"] = surf("riv", (0.5, 0.3, 0.14), rough=0.35, met=0.8, usure=0.7, nu=(0.85, 0.6, 0.4), crasse=0.2, graine=10)
    M["verre"] = MT.verre("ix_verre", col=(0.012, 0.012, 0.014), reflet=(0.2, 0.18, 0.22))
    # règle de la critique du 1/11 : aucune surface émissive sans dégradé. Une fente = 3 couches emboîtées (bord sombre, milieu, cœur clair)
    M["plasma_e"] = S.mat_emissive("ix_plasma_e", (0.5, 0.012, 0.27), strength=0.55, base=(0.04, 0.002, 0.02), main_scale=0.2)
    M["plasma_m"] = S.mat_emissive("ix_plasma_m", (1.0, 0.06, 0.58), strength=1.0, base=(0.08, 0.005, 0.05), main_scale=0.2, crust=(1.3, 0.35, 1))
    M["plasma_c"] = S.mat_emissive("ix_plasma_c", (1.0, 0.6, 0.82), strength=1.25, base=(0.2, 0.08, 0.14), main_scale=0.35)
    M["soleil"] = S.mat_emissive("ix_soleil", (1.0, 0.2, 0.02), strength=1.1, base=(0.1, 0.03, 0.005), main_scale=0.28, crust=(1.4, 0.6, 2))
    M["feu"] = S.mat_emissive("ix_feu", (1.0, 0.3, 0.03), strength=1.5, base=(0.1, 0.03, 0.005), main_scale=0.5)
    M["hublot"] = MT.lumiere(S, "ix_hublot", (1.0, 0.82, 0.55), 1.4, main=0.25)
    M["balise"] = MT.lumiere(S, "ix_hublot_balise", (1.0, 0.1, 0.62), 1.6, main=0.3)
    return M


def fente_dessus(lot, M, th0, th1, r, ac, demi):
    """Fente vue de dessus ou de dessous : cadre sombre, bord, milieu, cœur clair, emboîtés en rayon et en largeur."""
    sg = 1.0 if r > 25.0 else -1.0
    d = 0.12 / abs(r)
    lot.put(M["acier"], arc(th0 - d, th1 + d, min(r, r + sg * 0.1), max(r, r + sg * 0.1), ac - demi - 0.1, ac + demi + 0.1, 1.0))
    for (m, k, e, z) in ((M["plasma_e"], 1.0, 0.0, 0.1), (M["plasma_m"], 0.6, 0.8, 0.14), (M["plasma_c"], 0.24, 1.8, 0.18)):
        t0, t1 = th0 + e * d, th1 - e * d
        lot.put(m, arc(t0, t1, min(r + sg * (z - 0.03), r + sg * z), max(r + sg * (z - 0.03), r + sg * z), ac - demi * k, ac + demi * k, 0.8))


def fente_flanc(lot, M, th0, th1, r, demi, s):
    """Fente d'un flanc (s = ±1), emboîtée en rayon et en hauteur."""
    d = 0.1 / abs(r)

    def bloc(m, t0, t1, k, a0, a1):
        lot.put(m, arc(t0, t1, r - demi * k, r + demi * k, (W + a0) if s > 0 else (-W - a1), (W + a1) if s > 0 else (-W - a0), 0.8))
    bloc(M["acier"], th0 - d, th1 + d, 1.35, 0.0, 0.12)
    bloc(M["plasma_e"], th0, th1, 1.0, 0.0, 0.15)
    bloc(M["plasma_m"], th0 + d, th1 - d, 0.58, 0.0, 0.18)
    bloc(M["plasma_c"], th0 + 2.2 * d, th1 - 2.2 * d, 0.22, 0.0, 0.21)


def carcasse(lot, M):
    """Coque de base (noyau sombre) : profil fermé (axial, rayon) révolu autour de l'essieu."""
    prof = [(-W, 23.2), (-W, 27.0), (-W + 0.9, R_EXT), (W - 0.9, R_EXT), (W, 27.0), (W, 23.2), (W - 1.0, 21.7), (2.0, 21.5), (2.0, 23.9),
            (-2.0, 23.9), (-2.0, 21.5), (-W + 1.0, 21.7), (-W, 23.2)]
    lot.put(M["noyau"], G.tour(prof, 300, "y", (0.0, 0.0, ZC)))


def plaques_flanc(lot, M, r):
    """Blindage des flancs : 18 secteurs, 3 bandes, plaques d'épaisseurs et de matières différentes (jamais 2 pareilles)."""
    bandes = [(26.98, 27.92, 0.16, 0.34), (25.0, 26.96, 0.32, 0.72), (23.2, 24.5, 0.14, 0.5)]
    for s in (-1, 1):
        for k in range(18):
            th0 = G.TAU * k / 18.0
            d = G.TAU / 18.0
            for (r0, r1, e0, e1) in bandes:
                n = r.i(1, 3)
                cuts = sorted([0.0, 1.0] + [r.f(0.2, 0.8) for _ in range(n - 1)])
                for i in range(len(cuts) - 1):
                    t0 = th0 + d * (0.07 + 0.86 * cuts[i]) + 0.004
                    t1 = th0 + d * (0.07 + 0.86 * cuts[i + 1]) - 0.004
                    e = r.f(e0, e1)
                    x = r.f()
                    m = M["cera"] if x < 0.55 else M["cera3"] if x < 0.78 else M["cera2"] if x < 0.95 else M["cuivre2"]
                    a0, a1 = (W, W + e) if s > 0 else (-W - e, -W)
                    lot.put(m, arc(t0, t1, r0, r1, a0, a1, 0.9))
                    # arête d'étanchéité, sombre, entre le blindage et le noyau
                    if e > 0.45:
                        lot.put(M["acier"], arc(t0 + 0.006, t1 - 0.006, r0 + 0.1, r1 - 0.1, a1 if s > 0 else a0 - 0.05, (a1 + 0.05) if s > 0 else a0, 1.2))
            # anneau de plasma visible sur le flanc (coupé par les bobines)
            for q in range(3):
                pas_f = (d - 0.1) / 3.0
                t0 = th0 + 0.05 + pas_f * q
                fente_flanc(lot, M, t0 + 0.012, t0 + pas_f * 0.62, 24.72, 0.26, s)


def bobines(lot, M, r):
    """18 bobines en D (l'image du tokamak) : cuivre enroulé autour de toute la section, brides de céramique."""
    for k in range(18):
        th = G.TAU * k / 18.0
        d = 0.8 / R_EXT
        for s in (-1, 1):
            a0, a1 = (W + 0.72, W + 1.42) if s > 0 else (-W - 1.42, -W - 0.72)
            lot.put(M["cuivre"], arc(th - d, th + d, 22.7, 28.3, a0, a1, 0.8))
            # brides et boulons
            for rr in (23.1, 25.5, 27.9):
                lot.put(M["cera3"], arc(th - d * 1.5, th + d * 1.5, rr - 0.25, rr + 0.25, a0 - 0.1 if s > 0 else a1 - 0.2, a1 + 0.2 if s > 0 else a1 + 0.1, 1.0))
                for q in (-1, 1):
                    lot.put(M["acier"], pose_mur(G.tour([(0.0, 0.1), (0.14, 0.08), (0.2, 0.0)], 6, "z", cap0=True), th + q * d * 1.1, rr, s, W + 1.54))
            # rivets sur les 2 bords de la bande, comme le cuivre du Portique
            for i in range(9):
                rr = 23.0 + i * 0.64
                for q in (-1, 1):
                    lot.put(M["or_riv"], pose_mur(G.tour([(0.0, 0.11), (0.1, 0.09), (0.15, 0.0)], 7, "z", cap0=True), th + q * d * 0.72, rr, s, W + 1.42))
            for rr in (24.2, 26.7):
                lot.put(M["acier"], arc(th - d * 1.08, th + d * 1.08, rr - 0.1, rr + 0.1, a0 - 0.04, a1 + 0.06, 1.0))
            # le flanc reçoit la bobine : pied en biais
            lot.put(M["cuivre2"], arc(th - d, th + d, 22.7, 28.3, W - 0.05 if s > 0 else -W - 0.75, W + 0.75 if s > 0 else -W + 0.05, 1.0))
        lot.put(M["cuivre"], arc(th - d, th + d, 28.0, 28.55, -W - 1.42, W + 1.42, 1.0))
        lot.put(M["cuivre"], arc(th - d, th + d, 21.0, 21.55, -W - 1.42, -2.1, 1.0))
        lot.put(M["cuivre"], arc(th - d, th + d, 21.0, 21.55, 2.1, W + 1.42, 1.0))
        for s in (-1, 1):
            lot.put(M["cuivre2"], arc(th - d, th + d, 21.0, 22.7, s * (W + 0.72) if s > 0 else -W - 1.42, W + 1.42 if s > 0 else -W - 0.72, 1.0))


def tuyere(lot, M, th, a):
    """Tuyère radiale à la place d'un crampon : socle brûlé, cloche de cuivre, cœur de feu (la flamme elle-même est une animation)."""
    n = (math.cos(th), 0.0, math.sin(th))
    lot.put(M["brule"], arc(th - 0.045, th + 0.045, 28.0, 28.75, a - 1.15, a + 1.15, 1.0))
    p = P(th, 28.6, a)
    lot.put(M["cuivre2"], G.oriente(G.tour([(0.0, 1.15), (0.35, 0.95), (0.7, 0.62), (1.55, 1.02), (1.6, 0.92), (0.95, 0.48), (0.8, 0.0)], 18, "z"), p, n))
    lot.put(M["cuivre"], G.oriente(G.tour([(0.62, 0.72), (0.66, 0.84), (0.78, 0.84), (0.82, 0.68)], 18, "z"), p, n))
    lot.put(M["feu"], G.oriente(G.tour([(0.98, 0.5), (1.02, 0.0)], 14, "z", cap0=True), p, n))


def roulement(lot, M, r):
    """Le dessus de la jante, ce que la caméra voit le plus. Pour rester un tokamak et non un pneu : 2 RAILS de pavés seulement,
    sur les bords ; au milieu, céramique en plaques, bobines de cuivre qui passent par-dessus, fente de plasma, hublots."""
    N = 36
    for k in range(N):
        th = G.TAU * k / N
        d = G.TAU / N * 0.27
        for s in (-1, 1):
            dec = s * G.TAU / N * 0.25
            a0, a1 = (W - 1.9, W + 0.85) if s > 0 else (-W - 0.85, -W + 1.9)
            if k % 4 == 0:
                tuyere(lot, M, th + dec, (a0 + a1) / 2.0)
                continue
            h = DENT * (1.0, 1.0, 0.72, 1.14)[k % 4]
            e = 0.0 if k % 4 != 2 else 0.25
            lot.put(M["brule"], arc(th + dec - d, th + dec + d, 28.0, R_EXT + h * 0.72, a0 + e, a1 - e, 1.0))
            lot.put(M["brule"], arc(th + dec - d * 0.8, th + dec + d * 0.8, R_EXT + h * 0.72, R_EXT + h, a0 + 0.2 + e, a1 - 0.2 - e, 1.0))
            if k % 4 == 3:
                lot.put(M["cuivre2"], arc(th + dec - d * 0.22, th + dec + d * 0.22, R_EXT + h, R_EXT + h + 0.22, a0 + 0.2, a1 - 0.2, 1.2))
            else:
                lot.put(M["acier"], arc(th + dec - d * 0.5, th + dec + d * 0.5, R_EXT + h, R_EXT + h + 0.1, a0 + 0.55, a1 - 0.55, 1.2))
    formes = ["carre", "fente", "double", "rond", "octo", "ogive"]
    for k in range(18):
        th0 = G.TAU * k / 18.0
        dth = G.TAU / 18.0
        for s in (-1, 1):
            for (a0, a1) in ((0.82, 1.6), (1.66, W - 1.95)):
                n = r.i(2, 4)
                cuts = sorted([0.0, 1.0] + [r.f(0.15, 0.85) for _ in range(n - 1)])
                for i in range(len(cuts) - 1):
                    t0 = th0 + dth * (0.05 + 0.9 * cuts[i]) + 0.003
                    t1 = th0 + dth * (0.05 + 0.9 * cuts[i + 1]) - 0.003
                    e = r.f(0.12, 0.42)
                    x = r.f()
                    m = M["cera"] if x < 0.5 else M["cera3"] if x < 0.82 else M["cera2"]
                    lot.put(m, arc(t0, t1, R_EXT - 0.05, R_EXT + e, a0 if s > 0 else -a1, a1 if s > 0 else -a0, 0.9))
            # hublots sur le dessus, le long de la fente
            for i in range(14):
                if r.f() < 0.25:
                    continue
                t = th0 + dth * (i + 0.5) / 14.0
                p = P(t, R_EXT + 0.32, s * 1.2)
                R.hublot(lot, M["acier"], M["hublot"] if r.f() < 0.7 else M["verre"], p, (math.cos(t), 0.0, math.sin(t)), formes[r.i(0, 5)], t=r.f(0.13, 0.19), up=(-math.sin(t), 0.0, math.cos(t)))
        # la bobine passe par-dessus, entre les rails
        d = 0.85 / R_EXT
        lot.put(M["cuivre"], arc(th0 - d, th0 + d, 28.2, 29.15, -W + 1.85, W - 1.85, 1.0))
        lot.put(M["cera3"], arc(th0 - d * 1.5, th0 + d * 1.5, 29.05, 29.3, -0.9, 0.9, 1.0))
    # fente centrale : plasma entre 2 rails d'acier
    for k in range(72):
        if k % 4 == 0:
            continue
        t0 = G.TAU * k / 72.0 + 0.006
        fente_dessus(lot, M, t0, t0 + G.TAU / 72.0 * 0.66, R_EXT + 0.02, 0.0, 0.5)
    for s in (-1, 1):
        lot.put(M["acier"], G.tour([(s * 0.64, R_EXT), (s * 0.64, R_EXT + 0.5), (s * 0.84, R_EXT + 0.5), (s * 0.84, R_EXT)], 240, "y", (0.0, 0.0, ZC)))


def plasma(lot, M, r):
    """Le tore de plasma dans sa rainure intérieure, derrière une grille de barres de céramique."""
    for k in range(30):
        t0 = G.TAU * k / 30.0 + 0.01
        fente_dessus(lot, M, t0, t0 + G.TAU / 30.0 * 0.58, 22.7, 0.0, 1.55)
    for k in range(72):
        th = G.TAU * k / 72.0
        d = 0.09 / 21.5 * (2.2 if k % 4 == 0 else 1.0)
        lot.put(M["cera3"] if k % 4 == 0 else M["acier"], arc(th - d, th + d, 21.25, 21.5, -2.2, 2.2, 1.0))
    for s in (-1, 1):
        lot.put(M["cera2"], G.tour([(s * 2.0, 21.3), (s * 2.0, 21.75), (s * (W - 0.9), 21.75), (s * (W - 0.9), 21.3), (s * 2.0, 21.3)], 240, "y", (0.0, 0.0, ZC)))


def modules_flanc(lot, M, r):
    """Ce que porte le flanc entre 2 bobines : baies vitrées et coursive (l'échelle), radiateurs, réservoirs, trappes,
    tuyères. Un module différent à chaque secteur, tirés sans répétition proche."""
    types = ["baies", "radiateur", "reservoirs", "trappe", "baies", "tuyere", "radiateur", "baies", "reservoirs"]
    for s in (-1, 1):
        for k in range(18):
            th0 = (k + 0.5) * G.TAU / 18.0
            m = types[(k * 5 + (0 if s < 0 else 3)) % len(types)]
            if m == "baies":
                # rangée de hublots tous différents et coursive à garde-corps
                formes = ["ogive", "carre", "double", "fente", "rond", "octo"]
                n = 15
                for i in range(n):
                    t = th0 + (i - n / 2.0) * 0.0178
                    if r.f() < 0.12:
                        continue
                    pp = P(t, 26.2, s * (W + 0.5))
                    R.hublot(lot, M["acier"], M["hublot"] if r.f() < 0.72 else M["verre"], pp, (0.0, float(s), 0.0), formes[r.i(0, 5)], t=r.f(0.14, 0.22),
                             up=(math.cos(t), 0.0, math.sin(t)))
                a0, a1 = (W + 0.4, W + 1.25) if s > 0 else (-W - 1.25, -W - 0.4)
                lot.put(M["pont"], arc(th0 - 0.135, th0 + 0.135, 25.42, 25.52, a0, a1, 0.9))
                pts = [P(th0 - 0.135 + 0.27 * i / 8.0, 25.52, s * (W + 1.22)) for i in range(9)]
                R.garde_corps(lot, M["acier"], pts, h=0.38, pas=0.5, r=0.03)
            elif m == "radiateur":
                n = 18
                for i in range(n):
                    t = th0 + (i - n / 2.0) * 0.0135
                    a0, a1 = (W + 0.3, W + 1.0) if s > 0 else (-W - 1.0, -W - 0.3)
                    lot.put(M["cuivre2"] if i % 3 == 0 else M["acier"], arc(t - 0.0028, t + 0.0028, 25.2, 26.8, a0, a1, 1.0))
                for rr in (25.25, 26.75):
                    a0, a1 = (W + 0.2, W + 1.1) if s > 0 else (-W - 1.1, -W - 0.2)
                    lot.put(M["cera2"], arc(th0 - 0.13, th0 + 0.13, rr - 0.1, rr + 0.1, a0, a1, 1.0))
            elif m == "reservoirs":
                for i in range(3):
                    rr = 25.35 + i * 0.68
                    pts = [P(th0 - 0.12 + 0.24 * j / 10.0, rr, s * (W + 0.82)) for j in range(11)]
                    lot.put(M["cera3"] if i != 1 else M["cuivre2"], G.tube(pts, 0.32, 12))
                    for t in (-0.1, 0.0, 0.1):
                        lot.put(M["acier"], pose_mur(G.tour([(-0.06, 0.38), (0.06, 0.38)], 10, "x", cap0=True, cap1=True), th0 + t, rr, s, W + 0.82))
            elif m == "trappe":
                lot.put(M["acier"], pose_mur(G.boite((0, 0, 0.3), (3.6, 1.7, 0.6)), th0, 26.0, s, W + 0.3))
                lot.put(M["cera3"], pose_mur(G.boite((-0.55, 0, 0.72), (1.6, 1.4, 0.25)), th0, 26.0, s, W + 0.3))
                lot.put(M["noyau"], pose_mur(G.boite((1.0, 0, 0.65), (1.1, 1.1, 0.12)), th0, 26.0, s, W + 0.3))
                for q in (-1.5, 0.45):
                    lot.put(M["cuivre2"], pose_mur(G.boite((q, 0, 0.82), (0.18, 1.5, 0.22)), th0, 26.0, s, W + 0.3))
            elif m == "tuyere":
                for t in (-0.07, 0.07):
                    prof = [(0.0, 0.75), (0.5, 0.62), (0.75, 0.42), (1.3, 0.6), (1.32, 0.52), (0.85, 0.3), (0.6, 0.0)]
                    lot.put(M["cuivre2"], pose_mur(G.tour(prof, 16, "z"), th0 + t, 25.9, s, W + 0.2))
                    lot.put(M["balise"], pose_mur(G.tour([(0.7, 0.32), (0.74, 0.0)], 12, "z"), th0 + t, 25.9, s, W + 0.2))


def rayons(lot, M, r):
    """Rayons tendus et croisés (lecture immédiate : une roue), rayons maîtres de céramique."""
    n = 24
    for i in range(n):
        th = G.TAU * i / n
        s = 1 if i % 2 == 0 else -1
        croise = 0.55 * (1 if i % 4 < 2 else -1)
        a = P(th + croise, 4.4, s * 8.6)
        b = P(th, 21.1, s * 3.4)
        lot.put(M["acier"], G.tube([a, b], 0.17, 8))
        m = G.lerp(a, b, 0.62)
        lot.put(M["cuivre2"], G.oriente(G.tour([(-0.28, 0.3), (0.28, 0.3)], 10, "z", cap0=True, cap1=True), m, G.sub(b, a)))
    for i in range(6):
        th = G.TAU * (i + 0.25) / 6.0
        for s in (-1, 1):
            a = P(th, 3.2, s * 9.2)
            b = P(th, 21.2, s * 3.2)
            d = G.norm(G.sub(b, a))
            rr = lambda sd, ii: 0.62 - 0.26 * min(1.0, sd / 18.0)
            lot.put(M["cera3"], G.tube([G.lerp(a, b, t / 8.0) for t in range(9)], 0.6, 10, rfun=rr))
            for t in (0.2, 0.5, 0.8):
                lot.put(M["cuivre"], G.oriente(G.tour([(-0.34, 0.68 - 0.2 * t), (0.34, 0.68 - 0.2 * t)], 12, "z", cap0=True, cap1=True), G.lerp(a, b, t), d))


def moyeu(lot, M, r):
    """Le soleil captif, sa cage, les anneaux armillaires, l'essieu et les volants."""
    C = (0.0, 0.0, ZC)
    lot.put(M["soleil"], G.sphere(C, 5.7, 32, 16))
    # cage : plaques en quinconce, jours de plus en plus serrés vers les pôles
    for j in range(7):
        la0 = -math.pi / 2 + 0.16 + j * (math.pi - 0.32) / 7.0
        la1 = la0 + (math.pi - 0.32) / 7.0 - 0.06
        n = 10 if abs(j - 3) < 2 else 8
        for i in range(n):
            lo0 = G.TAU * (i + 0.5 * (j % 2)) / n
            lo1 = lo0 + G.TAU / n * (0.52 if abs(j - 3) < 2 else 0.74)
            m = M["cera2"] if (i + j) % 3 else M["cera"]
            lot.put(m, calotte(C, la0, la1, lo0, lo1, 6.15, 6.75 + 0.15 * ((i + j) % 2)))
            # nervure de cuivre le long de chaque plaque
            lot.put(M["cuivre2"], calotte(C, la0 - 0.02, la1 + 0.02, lo0 - 0.02, lo0 + 0.03, 6.0, 6.95, 4))
    # anneaux armillaires (3 plans différents)
    for (ax, ang, rr, e, m) in (("x", 0.42, 9.3, 0.42, "cuivre2"), ("z", -0.5, 10.7, 0.36, "cera3"), ("y", 0.0, 8.1, 0.3, "acier")):
        ring = G.tour([(-e, rr), (e, rr), (e, rr + e), (-e, rr + e), (-e, rr)], 96, "z")
        v, f, u = ring
        if ax == "x":
            v = [G.rot_x(q, math.pi / 2 + ang) for q in v]
        elif ax == "z":
            v = [G.rot_y(q, math.pi / 2 + ang) for q in v]
        else:
            v = [G.rot_x(G.rot_y(q, 0.7), 0.35) for q in v]
        v = [G.add(q, C) for q in v]
        lot.put(M[m], (v, f, u))
    # essieu et cônes de moyeu
    lot.put(M["acier"], G.tour([(-19.0, 0.0), (-19.0, 1.3), (-17.5, 1.7), (-9.4, 2.2), (9.4, 2.2), (17.5, 1.7), (19.0, 1.3), (19.0, 0.0)], 48, "y", C))
    for s in (-1, 1):
        prof = [(s * 6.6, 1.6), (s * 7.2, 4.0), (s * 9.6, 5.0), (s * 10.2, 2.4)]
        lot.put(M["cera"], G.tour(prof, 64, "y", C))
        lot.put(M["cuivre"], G.tour([(s * 8.8, 4.9), (s * 8.8, 5.3), (s * 9.4, 5.3), (s * 9.4, 4.9)], 64, "y", C))
        for i in range(24):
            th = G.TAU * i / 24.0
            q = P(th, 4.75, s * 9.0)
            lot.put(M["acier"], G.oriente(G.tour([(0.0, 0.2), (0.32, 0.15), (0.42, 0.0)], 8, "z", cap0=True), q, (math.cos(th), 0.0, math.sin(th))))
        # volant gyroscopique, à rayons et masselottes
        ya = s * 13.6
        prof = [(ya - 0.9, 2.0), (ya - 0.6, 5.6), (ya - 1.1, 7.2), (ya - 1.1, 8.6), (ya + 1.1, 8.6), (ya + 1.1, 7.2), (ya + 0.6, 5.6), (ya + 0.9, 2.0)]
        lot.put(M["cera2"], G.tour(prof, 96, "y", (0.0, 0.0, ZC)))
        lot.put(M["cuivre2"], G.tour([(ya - 1.3, 7.5), (ya - 1.3, 8.0), (ya + 1.3, 8.0), (ya + 1.3, 7.5)], 96, "y", (0.0, 0.0, ZC)))
        for i in range(20):
            t0 = G.TAU * i / 20.0
            for q in (-1, 1):
                aa = ya + q * 1.13
                lot.put(M["plasma_e"], arc(t0, t0 + 0.18, 8.1, 8.47, aa - 0.02, aa + 0.02, 1.0))
                lot.put(M["plasma_c"], arc(t0 + 0.03, t0 + 0.15, 8.22, 8.35, aa - 0.04, aa + 0.04, 1.0))
        for i in range(12):
            th = G.TAU * i / 12.0
            ra = ya + s * 1.15
            lot.put(M["acier"], G.tube([P(th, 2.2, ya + s * 0.95), P(th, 7.0, ra)], 0.22, 8))
            q = P(th + 0.26, 6.6, ra)
            lot.put(M["cera3"], G.oriente(G.boite((0, 0, 0.3), (1.5, 0.9, 0.6)), q, (0.0, float(s), 0.0)))


def side_car(lot, M, r, s):
    """Tour de commandement pendue à l'essieu (ne tourne pas) : pivot, bras, étages en porte-à-faux, canons à plasma.
    s = -1 : côté caméra. Les détails denses vont du côté vu."""
    y = s * 19.2
    zb = 7.0                         # dessous de la tour
    zh = ZC - 7.5                    # dessus de la tour, sous le pivot
    # pivot sur le bout d'essieu
    lot.put(M["cera2"], G.tour([(y - 2.1, 0.0), (y - 2.1, 2.8), (y + 2.1, 2.8), (y + 2.1, 0.0)], 48, "y", (0.0, 0.0, ZC)))
    for q in (-1, 1):
        lot.put(M["cuivre2"], G.tour([(y + q * 2.15, 0.0), (y + q * 2.15, 0.9), (y + q * 2.3, 0.7), (y + q * 2.3, 0.0)], 32, "y", (0.0, 0.0, ZC)))
        for i in range(12):
            a = G.TAU * i / 12.0
            lot.put(M["acier"], G.tour([(y + q * 2.1, 0.24), (y + q * 2.3, 0.2)], 8, "y", (1.9 * math.cos(a), 0.0, ZC + 1.9 * math.sin(a)), cap0=True, cap1=True))
    lot.put(M["cuivre"], G.tour([(y - 1.0, 2.75), (y - 1.0, 3.1), (y + 1.0, 3.1), (y + 1.0, 2.75)], 48, "y", (0.0, 0.0, ZC)))
    # bras en lyre, de chaque côté du pivot
    for q in (-1, 1):
        pts = G.catmull([(q * 2.3, y, ZC + 1.0), (q * 2.6, y, ZC - 2.0), (q * 3.2, y, zh + 2.0), (q * 3.4, y, zh - 1.6)], 8)
        lot.put(M["cera3"], G.tube(pts, 0.55, 12))
    # toit : dôme de céramique à nervures de cuivre, galerie vitrée
    lot.put(M["cera3"], G.tour([(zh, 4.3), (zh + 0.6, 4.1), (zh + 1.4, 3.3), (zh + 2.0, 2.0), (zh + 2.3, 0.0)], 40, "z", (0.0, y, 0.0)))
    lot.put(M["hublot"], G.tour([(zh + 0.16, 4.33), (zh + 0.44, 4.2)], 40, "z", (0.0, y, 0.0)))
    for i in range(10):
        a = G.TAU * i / 10.0
        pts = [((rr * math.cos(a)), y + rr * math.sin(a), zz) for (rr, zz) in ((4.36, zh + 0.05), (4.15, zh + 0.65), (3.35, zh + 1.45), (2.05, zh + 2.05), (0.5, zh + 2.32))]
        lot.put(M["cuivre2"], G.tube(G.catmull(pts, 4), 0.09, 6))
    # le fût, à étages : octogones qui se resserrent vers le bas, comme une ruche renversée
    etages = [(zh - 3.4, 4.5, 0), (zh - 6.6, 3.8, 0), (zh - 9.6, 3.3, 0), (zh - 12.3, 3.9, 0), (zb + 0.6, 2.7, 0)]
    z = zh
    for i, (z1, rh, rb) in enumerate(etages):
        oct_haut = R.octo((0.0, y), rh, 8)
        lot.put(M["cera"] if i % 2 == 0 else M["cera2"], G.prisme(oct_haut, z1, z, top_scale=1.0))
        lot.put(M["acier"], G.prisme(R.octo((0.0, y), rh + 0.32, 8), z - 0.24, z, top_scale=0.99))
        lot.put(M["cuivre2"], G.prisme(R.octo((0.0, y), rh + 0.14, 8), z1 + 0.06, z1 + 0.32, top_scale=0.99))
        # baies : tous côtés vus (nord exclu)
        for j in range(8):
            a = math.pi / 8 + G.TAU * j / 8
            if s < 0 and math.sin(a) > 0.5:
                continue
            ap = rh * math.cos(math.pi / 8)
            cen = (ap * math.cos(a), y + ap * math.sin(a))
            n = (math.cos(a), math.sin(a), 0.0)
            lg = 2 * rh * math.sin(math.pi / 8)
            nb = max(2, int(lg / 0.62))
            for lv in range(max(1, int((z - z1 - 0.9) / 0.95))):
                zz = z1 + 0.75 + lv * 0.95
                for b in range(nb):
                    if r.f() < 0.1:
                        continue
                    d = (b - (nb - 1) / 2.0) * 0.6
                    pp = (cen[0] - math.sin(a) * d, cen[1] + math.cos(a) * d, zz)
                    R.hublot(lot, M["acier"], M["hublot"] if r.f() < 0.65 else M["verre"], pp, n, "ogive" if lv == 0 else ["carre", "fente", "double"][r.i(0, 2)], t=r.f(0.13, 0.2))
        # pont à garde-corps
        if i in (0, 2, 3):
            lot.put(M["pont"], G.prisme(R.octo((0.0, y), rh + 0.95, 8), z1 + 0.5, z1 + 0.68))
            pts = [((rh + 0.9) * math.cos(a0 * G.TAU / 16), y + (rh + 0.9) * math.sin(a0 * G.TAU / 16), z1 + 0.68) for a0 in range(17)]
            R.garde_corps(lot, M["acier"], pts, h=0.42, pas=0.55, r=0.03)
            for j in range(8):
                a = G.TAU * j / 8 + 0.2
                lot.put(M["acier"], G.tube([((rh + 0.85) * math.cos(a), y + (rh + 0.85) * math.sin(a), z1 + 0.5), (rh * 0.98 * math.cos(a), y + rh * 0.98 * math.sin(a), z1 - 0.9)], 0.07, 6))
        z = z1
    # quille : pointe de cuivre et capteur
    lot.put(M["cuivre2"], G.tour([(z, 2.0), (z - 1.3, 0.7), (z - 2.3, 0.14), (z - 2.3, 0.0)], 24, "z", (0.0, y, 0.0), cap0=True))
    lot.put(M["balise"], G.sphere((0.0, y, z - 2.35), 0.2, 10, 5))
    # canons à plasma de flanc (tête sphérique ceinturée d'un tore, 2 canons courts : bible, mitrailleuse d'époque 13)
    for (dx, dz) in ((-1, zh - 4.6), (1, zh - 4.6), (-1, zh - 11.3), (1, zh - 11.3)):
        cx = dx * 4.7
        cy = y - 1.1 * (1 if s < 0 else -1)
        lot.put(M["acier"], G.boite((cx * 0.9, cy, dz), (2.0, 1.2, 0.8)))
        lot.put(M["cera3"], G.sphere((cx, cy, dz), 1.05, 16, 8))
        lot.put(M["plasma_m"], G.tour([(dz - 0.11, 1.12), (dz + 0.11, 1.12)], 20, "z", (cx, cy, 0.0)))
        lot.put(M["cuivre2"], G.tour([(dz - 0.26, 1.03), (dz - 0.13, 1.28), (dz + 0.13, 1.28), (dz + 0.26, 1.03)], 20, "z", (cx, cy, 0.0)))
        for q in (-0.32, 0.32):
            p0 = (cx + dx * 0.7, cy, dz + q)
            p1 = (cx + dx * 2.2, cy - 0.5, dz + q + 0.4)
            lot.put(M["acier"], G.tube([p0, p1], 0.17, 8))
            lot.put(M["balise"], G.sphere(p1, 0.14, 8, 4))
    # tuyauterie, antennes, radiateur
    for q in (-1, 1):
        R.tuyau(lot, M["cuivre2"], M["acier"], [(q * 3.6, y - s * 2.4, zh - 0.2), (q * 3.2, y - s * 2.6, zh - 6.2), (q * 2.4, y - s * 2.7, zh - 9.4), (q * 2.7, y - s * 2.4, zb + 1.6)], 0.2, pas_bride=1.6)
    if s < 0:
        for (dx, dy, h) in ((-2.4, -1.0, 4.4), (2.6, -0.6, 3.2), (0.6, -2.4, 2.4)):
            R.mat_antenne(lot, M["acier"], M["acier"], M["balise"], (dx, y + dy, zh + 1.3), h, r)


def build(S, lot):
    M = matieres(S)
    lot.xf = XF
    r = G.Rnd(1313)
    R.raz()
    carcasse(lot, M)
    plaques_flanc(lot, M, r)
    bobines(lot, M, r)
    roulement(lot, M, r)
    plasma(lot, M, r)
    modules_flanc(lot, M, r)
    rayons(lot, M, r)
    moyeu(lot, M, r)
    for s in (-1, 1):
        side_car(lot, M, r, s)
    return dict(R.COMPTE)
