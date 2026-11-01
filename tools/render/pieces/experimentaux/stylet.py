"""STYLET, expérimental de l'âge 11 (Titane) : une lance de 45 tuiles qui plane POINTE EN BAS, à un souffle du sol. Lot EXP2, 1/11.
Bible : ailerons triangulaires, silhouette en flèche, alliage blanc patiné, lignes bleu-blanc qui courent. Section à 3 pans : une image par symétrie
(elle ne se retourne jamais, elle glisse). Elle écrit au sol : son effet est un circuit lumineux, pas une explosion.
"""
import math

import fam as F
import geo as G
import greb as R
import mat as MT

GROUPES = {"ligne": ("st_l",), "jets": ("st_j",), "hublots": ("st_h",)}
Z_POINTE = 2.2
Z_EPAULE = 45.0
Z_HAUT = 64.0


def largeur(z):
    """Demi-largeur de la lance à la hauteur z : pointe très fine, s'élargit, étranglement sous l'épaule, puis fût."""
    if z <= Z_EPAULE:
        t = (z - Z_POINTE) / (Z_EPAULE - Z_POINTE)
        return 0.05 + 9.5 * t ** 1.25
    t = (z - Z_EPAULE) / (Z_HAUT - Z_EPAULE)
    return 9.55 * (1 - t) ** 0.8 * 0.62 + 0.3


def section(z, k=1.0, dec=0.0):
    """Section à 3 pans, chacun creusé (6 points) : l'arête est une ligne de lumière, le pan une gouttière."""
    a = largeur(z) * k
    pts = []
    for i in range(3):
        th = dec + -math.pi / 2 + G.TAU * i / 3
        pts.append((a * math.cos(th), a * math.sin(th), z))
        th2 = th + G.TAU / 6
        pts.append((a * 0.72 * math.cos(th2), a * 0.72 * math.sin(th2), z))
    return pts


def matieres(S):
    surf = F.surf_de("st")
    F.patine(ta=0.16, ra=0.3, ec=0.34, nu_k=1.25, ec_col=(0.07, 0.06, 0.05), sans=())
    M = {}
    M["blanc"] = surf("blanc", (0.78, 0.77, 0.72), rough=0.34, met=0.1, tole=(2.6, 1.3), joint=0.35, joint_l=0.012, var=0.09, coulures=0.85, rouille=(0.11, 0.09, 0.07), usure=0.5,
                      nu=(0.92, 0.92, 0.9), crasse=0.55, crasse_col=(0.03, 0.026, 0.022), relief=0.5, graine=1)
    M["blanc2"] = surf("blanc2", (0.52, 0.51, 0.47), rough=0.36, met=0.2, tole=(1.3, 0.7), joint=0.35, joint_l=0.02, var=0.12, coulures=0.8, rouille=(0.09, 0.07, 0.05), usure=0.5,
                       nu=(0.78, 0.78, 0.76), crasse=0.6, crasse_col=(0.024, 0.02, 0.018), relief=0.5, graine=2)
    M["titane"] = surf("titane", (0.2, 0.2, 0.21), rough=0.38, met=0.7, coulures=0.4, rouille=(0.1, 0.07, 0.04), usure=0.6, nu=(0.62, 0.62, 0.64), crasse=0.75, crasse_col=(0.008, 0.008, 0.009), graine=3)
    M["noir"] = surf("noir", (0.022, 0.022, 0.026), rough=0.5, met=0.4, usure=0.4, nu=(0.2, 0.2, 0.22), crasse=0.6, crasse_col=(0.003, 0.003, 0.004), graine=4)
    M["brule"] = surf("brule", (0.09, 0.075, 0.065), rough=0.5, met=0.6, usure=0.6, nu=(0.5, 0.42, 0.36), crasse=0.7, crasse_col=(0.006, 0.005, 0.004), graine=5)
    M["verre"] = MT.verre("st_verre", col=(0.01, 0.014, 0.02), reflet=(0.16, 0.22, 0.3))
    M["ligne"] = F.trio(S, "st_l", (0.16, 0.5, 1.0), 1.05, clair=(0.8, 0.92, 1.0))
    M["jet"] = F.trio(S, "st_j", (0.2, 0.55, 1.0), 1.2, clair=(0.9, 0.96, 1.0))
    M["hublot"] = MT.lumiere(S, "st_h", (0.8, 0.9, 1.0), 1.1, main=0.28)
    return M


def plaque_pan(lot, m, i, z0, z1, u0, u1, ep):
    """Plaque posée sur le pan i (u 0..1, de l'arête vers le creux du pan), entre z0 et z1."""
    rings = []
    for z in (z0, z1):
        s = section(z)
        a, b, c = s[2 * i], s[2 * i + 1], s[(2 * i + 2) % 6]
        def sur(u):
            # u de 0 à 1 traverse le pan entier : arête, creux, arête
            if u < 0.5:
                return G.lerp(a, b, u * 2)
            return G.lerp(b, c, (u - 0.5) * 2)
        p0, p1 = sur(u0), sur(u1)
        ax = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        n = G.norm((ax[0], ax[1], 0.0))
        rings.append([p0, p1, G.add(p1, G.mul(n, ep)), G.add(p0, G.mul(n, ep))])
    lot.put(m, G.loft(rings, True, True))


def corps(lot, M, r):
    # âme sombre
    zs = [Z_POINTE + (Z_HAUT - Z_POINTE) * t / 60.0 for t in range(61)]
    lot.put(M["noir"], G.loft([section(z, 0.98) for z in zs], True, True))
    # étages de plaques entre les colliers
    niveaux = [6.5, 11.5, 17.0, 23.0, 29.5, 36.0, 42.0, 45.0, 50.0, 55.0, 60.0]
    bas = Z_POINTE + 0.6
    for n_i, haut in enumerate(niveaux):
        for i in range(3):
            # seuls les pans vus reçoivent tout le détail
            n = 3 + n_i // 3
            for j in range(n):
                z0 = bas + (haut - bas) * j / n + 0.05
                z1 = bas + (haut - bas) * (j + 1) / n - 0.05
                k = r.i(1, 3)
                cu = sorted([0.0, 1.0] + [r.f(0.2, 0.8) for _ in range(k - 1)])
                for q in range(len(cu) - 1):
                    u0, u1 = 0.05 + 0.9 * cu[q] + 0.006, 0.05 + 0.9 * cu[q + 1] - 0.006
                    x = r.f()
                    m = M["blanc"] if x < 0.62 else M["blanc2"] if x < 0.9 else M["titane"]
                    plaque_pan(lot, m, i, z0, z1, u0, u1, r.f(0.05, 0.3))
        # collier d'étage : anneau à 3 pans, à chaque collier des échappements
        lot.put(M["titane"], G.loft([section(haut - 0.22, 1.06), section(haut + 0.22, 1.06)], True, True))
        lot.put(M["brule"], G.loft([section(haut + 0.22, 1.02), section(haut + 0.4, 0.98)], True, True))
        bas = haut + 0.25
    # lignes bleu-blanc le long des 3 arêtes, en segments qui « courent »
    for i in range(3):
        th = -math.pi / 2 + G.TAU * i / 3
        n = G.norm((math.cos(th), math.sin(th), 0.0))
        t = (-n[1], n[0], 0.0)
        z = 4.0
        while z < Z_HAUT - 2.0:
            L = 1.5 + 2.0 * (z / Z_HAUT)
            for (m, k, ep) in ((M["ligne"][0], 1.0, 0.12), (M["ligne"][1], 0.55, 0.16), (M["ligne"][2], 0.22, 0.2)):
                a0 = largeur(z + 0.1)
                a1 = largeur(z + L)
                w = 0.06 + 0.12 * (z / Z_EPAULE) * k + 0.05 * k
                rings = [[G.add(G.mul(n, a + 0.1), G.add((0, 0, zz), G.mul(t, -w))), G.add(G.mul(n, a + 0.1), G.add((0, 0, zz), G.mul(t, w))),
                          G.add(G.mul(n, a + 0.1 + ep), G.add((0, 0, zz), G.mul(t, w))), G.add(G.mul(n, a + 0.1 + ep), G.add((0, 0, zz), G.mul(t, -w)))] for (a, zz) in ((a0, z + 0.1), (a1, z + L))]
                lot.put(m, G.loft(rings, True, True))
            z += L + 0.7
    # baies du pan sud-ouest et sud-est : rangées serrées, l'échelle d'un personnage
    formes = ["carre", "fente", "double", "ogive", "octo"]
    for z in [10 + 3.2 * i for i in range(16)]:
        a = largeur(z)
        if a < 1.5:
            continue
        for i in (0, 2):
            th = -math.pi / 2 + G.TAU * i / 3 + G.TAU / 6 * (1 if i == 0 else -1)
            n = (math.cos(th), math.sin(th), 0.0)
            t = (-n[1], n[0], 0.0)
            nb = int(a * 1.5)
            for b in range(nb):
                if r.f() < 0.3:
                    continue
                d = (b - (nb - 1) / 2.0) * 0.62
                p = G.add((n[0] * a * 0.76, n[1] * a * 0.76, z), G.mul(t, d))
                R.hublot(lot, M["titane"], M["hublot"] if r.f() < 0.75 else M["verre"], G.add(p, G.mul(n, 0.3)), n, formes[r.i(0, 4)], t=r.f(0.14, 0.2))


def aileron(lot, M, th, z0, z1, L, r_base, ep, r):
    """Aileron triangulaire balayé vers le haut : caisson, longeron, plaques, bord d'attaque brûlé, ligne lumineuse."""
    n = (math.cos(th), math.sin(th), 0.0)
    t = (-n[1], n[0], 0.0)
    A = (n[0] * r_base, n[1] * r_base, z0)
    B = (n[0] * r_base, n[1] * r_base, z1)
    C = (n[0] * (r_base + L), n[1] * (r_base + L), z1 + (z1 - z0) * 0.55)
    verts = []
    for s in (-1, 1):
        for p in (A, B, C):
            verts.append(G.add(p, G.mul(t, s * ep * (0.2 if p is C else 1.0))))
    f = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    u = [(v[2], G.dot(v, n)) for v in verts]
    lot.put(M["blanc2"], (verts, f, u))
    # écailles de plaques sur la face vue
    sg = -1 if t[1] > 0 else 1
    for i in range(7):
        for j in range(1, 6):
            uu, vv = (i + 0.5) / 7.0, (j - 0.2) / 6.0
            if uu + vv > 1.0:
                continue
            p = G.add(G.add(A, G.mul(G.sub(B, A), uu)), G.mul(G.sub(C, A), vv))
            p = G.add(p, G.mul(t, sg * ep * (1.0 - vv * 0.8)))
            sz = (L * 0.135, (z1 - z0) * 0.12, r.f(0.05, 0.18))
            pl = R.pose(G.boite((0, 0, sz[2] / 2), sz), p, G.mul(t, sg), up=(0.0, 0.0, 1.0))
            lot.put(M["blanc"] if r.f() < 0.65 else M["titane"], pl)
    # bord d'attaque : longeron brûlé et ligne
    lot.put(M["brule"], G.tube([A, C], 0.34 + ep * 0.2, 8))
    q = G.lerp(B, C, 0.5)
    lot.put(M["titane"], G.tube([B, C], 0.2 + ep * 0.15, 8))
    lot.put(M["ligne"][1], G.tube([G.lerp(A, C, 0.2), G.lerp(A, C, 0.82)], 0.13, 6))
    lot.put(M["ligne"][2], G.tube([G.lerp(A, C, 0.28), G.lerp(A, C, 0.74)], 0.06, 6))
    # feu de bout d'aile
    lot.put(M["hublot"], G.sphere(C, 0.2, 8, 4))


def reacteurs(lot, M, r):
    """Tuyères en couronne sous l'épaule : elles poussent vers le bas, le long de la lance."""
    z = Z_EPAULE - 1.0
    a = largeur(z)
    for i in range(3):
        th0 = -math.pi / 2 + G.TAU * i / 3 + G.TAU / 6
        for k in (-1, 0, 1):
            th = th0 + k * 0.42
            rr = a * 0.86 + 1.15
            p = (rr * math.cos(th), rr * math.sin(th), z)
            lot.put(M["titane"], G.tour([(0.0, 1.05), (-0.6, 1.1), (-1.4, 0.95), (-2.3, 0.72), (-3.0, 0.92), (-3.04, 0.8), (-2.4, 0.4), (-2.2, 0.0)], 18, "z", p))
            lot.put(M["brule"], G.tour([(0.1, 1.1), (0.0, 1.16), (-0.5, 1.16), (-0.55, 1.06)], 18, "z", p))
            lot.put(M["jet"][1], G.tour([(-2.45, 0.42), (-2.42, 0.0)], 14, "z", p, cap0=True))
            lot.put(M["jet"][2], G.tour([(-2.5, 0.2), (-2.47, 0.0)], 10, "z", p, cap0=True))


def build(S, lot, variante="stylet"):
    M = matieres(S)
    r = G.Rnd(1111)
    R.raz()
    corps(lot, M, r)
    for i in range(3):
        th = -math.pi / 2 + G.TAU * i / 3
        aileron(lot, M, th, 34.0, 48.0, 14.0, largeur(40.0) * 0.86, 0.55, r)
        aileron(lot, M, th + G.TAU / 6, 53.0, 61.0, 8.5, 2.6, 0.32, r)
        aileron(lot, M, th, 13.5, 21.0, 5.5, largeur(16.0) * 0.82, 0.28, r)
    reacteurs(lot, M, r)
    # tête : poignée de la lance, couronne de capteurs, mât
    lot.put(M["titane"], G.tour([(Z_HAUT - 2, 1.4), (Z_HAUT - 0.8, 1.1), (Z_HAUT + 1.6, 0.55), (Z_HAUT + 6.0, 0.05)], 10, "z", cap0=True, cap1=True))
    lot.put(M["hublot"], G.sphere((0, 0, Z_HAUT + 6.1), 0.2, 8, 4))
    # pointe : gaine brûlée, ligne au bout
    lot.put(M["brule"], G.tour([(Z_POINTE - 1.6, 0.0), (Z_POINTE + 1.0, 0.22), (Z_POINTE + 3.8, 0.95)], 14, "z"))
    lot.put(M["jet"][2], G.sphere((0, 0, Z_POINTE - 1.6), 0.16, 10, 5))
    return dict(R.COMPTE)
