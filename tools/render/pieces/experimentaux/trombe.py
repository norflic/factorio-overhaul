"""TROMBE, expérimental de l'âge 12 (Supraconducteurs) : une tornade de 15 anneaux qui ne se touchent pas. Lot EXP2, 1/11.
Bible : anneaux en lévitation, premiers vides, noir profond, chrome, givre, anneaux cyan. Un entonnoir vide, pointe en bas ; au centre, une aiguille de
glace en hélice. Tout est froid : givre sur les pièces, stalactites sous les anneaux. Une image (les anneaux tournent à l'écran par une seule couche lumineuse).
"""
import math

import fam as F
import geo as G
import greb as R
import mat as MT

GROUPES = {"cyan": ("tr_c",), "hublots": ("tr_h",)}
N_ANN = 15
Z0, Z1 = 4.5, 50.0


def r_ann(i):
    t = i / float(N_ANN - 1)
    return 1.8 + 17.2 * t ** 1.55


def z_ann(i):
    t = i / float(N_ANN - 1)
    return Z0 + (Z1 - Z0) * t ** 0.92


def bascule(i):
    """Chaque anneau est un peu penché, et la pente tourne d'un anneau à l'autre : la tornade se tord."""
    return 0.11 + 0.05 * math.sin(i * 1.3), i * 0.75


def xf_ann(i):
    inc, ph = bascule(i)
    dx = 0.55 * math.sin(i * 0.8) * (1.0 + i * 0.05)
    dy = 0.55 * math.cos(i * 0.8) * (1.0 + i * 0.05)
    z = z_ann(i)

    def f(v):
        p = G.rot_z(G.rot_x(G.rot_z(v, -ph), inc), ph)
        return (p[0] + dx, p[1] + dy, p[2] + z)
    return f


def matieres(S):
    surf = F.surf_de("tr")
    F.patine(ta=0.12, ra=0.25, ec=0.6, nu_k=1.4, ec_col=(0.62, 0.72, 0.78), sans=("glace",))
    M = {}
    M["noir"] = surf("noir", (0.02, 0.022, 0.028), rough=0.32, met=0.8, tole=(2.2, 0.8), joint=0.5, joint_l=0.012, var=0.2, coulures=0.7, rouille=(0.55, 0.65, 0.7), usure=0.6, nu=(0.55, 0.6, 0.65), crasse=0.5,
                    crasse_col=(0.003, 0.003, 0.005), relief=0.5, graine=1)
    M["chrome"] = surf("chrome", (0.62, 0.65, 0.7), rough=0.18, met=0.92, coulures=0.4, rouille=(0.6, 0.7, 0.76), usure=0.4, nu=(0.92, 0.94, 0.96), crasse=0.4, crasse_col=(0.02, 0.022, 0.03), graine=2)
    M["acier"] = surf("acier", (0.09, 0.1, 0.12), rough=0.38, met=0.75, coulures=0.5, rouille=(0.5, 0.6, 0.66), usure=0.6, nu=(0.5, 0.54, 0.6), crasse=0.6, crasse_col=(0.005, 0.005, 0.007), graine=3)
    M["givre"] = surf("givre", (0.66, 0.74, 0.8), rough=0.75, met=0.0, usure=0.2, nu=(0.9, 0.94, 0.97), crasse=0.5, crasse_col=(0.2, 0.3, 0.38), graine=4)
    M["glace"] = MT.verre("tr_glace", col=(0.12, 0.26, 0.34), reflet=(0.6, 0.78, 0.86))
    M["verre"] = MT.verre("tr_verre", col=(0.008, 0.012, 0.02), reflet=(0.16, 0.24, 0.3))
    M["cyan"] = F.trio(S, "tr_c", (0.05, 0.75, 1.0), 1.0, clair=(0.72, 0.96, 1.0))
    M["hublot"] = MT.lumiere(S, "tr_h", (0.7, 0.92, 1.0), 1.05, main=0.28)
    return M


def anneau_tornade(lot, M, i, r):
    ra = r_ann(i)
    f = xf_ann(i)
    # section d'autant plus lourde que l'anneau est grand
    h = 0.32 + 0.095 * i
    w = 0.42 + 0.14 * i
    lot.xf = f
    # âme
    prof = [(-h * 0.5, ra - w * 0.55), (-h * 0.82, ra), (-h * 0.5, ra + w * 0.62), (h * 0.3, ra + w * 0.62), (h * 0.62, ra + w * 0.2), (h * 0.62, ra - w * 0.25), (h * 0.3, ra - w * 0.55), (-h * 0.5, ra - w * 0.55)]
    lot.put(M["noir"], G.tour(prof, 72 + i * 8, "z"))
    # segments : plaques de chrome, de noir, de givre, tiges en bout
    n = 10 + i * 2
    for k in range(n):
        a0 = G.TAU * k / n + 0.008
        a1 = a0 + G.TAU / n - 0.018
        x = r.f()
        m = M["chrome"] if x < 0.26 else M["acier"] if x < 0.68 else M["givre"]
        e = r.f(0.03, 0.14) + 0.012 * i
        lot.put(m, G.tour([(h * 0.62, ra - w * 0.22), (h * 0.62 + e, ra - w * 0.18), (h * 0.62 + e, ra + w * 0.16), (h * 0.62, ra + w * 0.2), (h * 0.62, ra - w * 0.22)], 8, "z", a0=a0, a1=a1))
        lot.put(m if x > 0.26 else M["acier"], G.tour([(-h * 0.46, ra + w * 0.62), (-h * 0.46, ra + w * 0.62 + e), (h * 0.28, ra + w * 0.62 + e), (h * 0.28, ra + w * 0.62), (-h * 0.46, ra + w * 0.62)], 8, "z", a0=a0, a1=a1))
        if i >= 4 and k % 3 == 0:
            # pinces de cuivre froid, bobines : des blocs qui dépassent et cassent le cercle
            am = (a0 + a1) / 2
            p = (ra * math.cos(am), ra * math.sin(am), 0.0)
            lot.put(M["chrome"], G.oriente(G.boite((0, 0, w * 0.1), (0.5 + 0.03 * i, h * 1.7, w * 1.65)), p, (math.cos(am), math.sin(am), 0.0)))
            lot.put(M["acier"], G.oriente(G.boite((0, 0, w * 0.82), (0.32 + 0.02 * i, h * 0.95, 0.28)), p, (math.cos(am), math.sin(am), 0.0)))
    # fentes cyan à dégradé, sur le dessus
    nf = 6 + i
    for k in range(nf):
        a0 = G.TAU * k / nf + 0.1 * i
        a1 = a0 + G.TAU / nf * 0.56
        for (m, kk, e) in ((M["cyan"][0], 1.0, 0.03), (M["cyan"][1], 0.55, 0.06), (M["cyan"][2], 0.2, 0.09)):
            dw = w * 0.14 * kk
            lot.put(m, G.tour([(h * 0.62 + e, ra - dw), (h * 0.62 + e, ra + dw), (h * 0.62 + e - 0.03, ra + dw), (h * 0.62 + e - 0.03, ra - dw), (h * 0.62 + e, ra - dw)], 8, "z", a0=a0 + 0.015 * (1 - kk), a1=a1 - 0.015 * (1 - kk)))
    # baies sur la paroi extérieure (l'échelle) à partir de l'anneau 6
    if i >= 6:
        nb = int(ra * 3.4)
        formes = ["carre", "fente", "double", "rond", "octo"]
        for k in range(nb):
            a = G.TAU * (k + 0.5) / nb
            if r.f() < 0.42:
                continue
            n_ = (math.cos(a), math.sin(a), 0.0)
            R.hublot(lot, M["acier"], M["hublot"] if r.f() < 0.75 else M["verre"], (ra * math.cos(a) + n_[0] * (w * 0.66), ra * math.sin(a) + n_[1] * (w * 0.66), -h * 0.08), n_, formes[r.i(0, 4)], t=r.f(0.12, 0.18))
    # stalactites de glace sous l'anneau
    nst = 5 + i * 2
    for k in range(nst):
        a = r.f(0, G.TAU)
        rr = ra + r.f(-w * 0.3, w * 0.5)
        L = r.f(0.5, 1.2 + 0.2 * i)
        rs = r.f(0.07, 0.14 + 0.012 * i)
        lot.put(M["glace"], G.tour([(-h * 0.5, rs), (-h * 0.5 - L * 0.45, rs * 0.55), (-h * 0.5 - L, 0.0)], 6, "z", (rr * math.cos(a), rr * math.sin(a), 0.0), cap0=True))
    lot.xf = None


def aiguille(lot, M, r):
    """L'aiguille de glace centrale, en hélice, à cœur de lumière ; elle ne touche aucun anneau."""
    z0, z1 = 1.8, Z1 - 3.0
    n = 80
    for b in range(3):
        pts = []
        for j in range(n + 1):
            t = j / float(n)
            z = z0 + (z1 - z0) * t
            a = 0.2 + t * 8.5 + b * G.TAU / 3
            rr = 0.4 + 3.1 * t ** 1.5
            pts.append((rr * math.cos(a), rr * math.sin(a), z))
        lot.put(M["glace"], G.tube(pts, 0.3, 8, rfun=lambda s_, i: 0.14 + 0.42 * (i / float(n))))
        for j in range(4, n, 4):
            p = pts[j]
            d = G.norm((p[0], p[1], 0.7))
            F.eclat_cristal(lot, M["glace"], p, G.add(d, (r.f(-0.4, 0.4), r.f(-0.4, 0.4), 0.0)), r.f(0.7, 1.4 + 2.2 * j / n), r.f(0.1, 0.24 + 0.14 * j / n), r, 5)
    for (rr, m) in ((0.34, M["cyan"][0]), (0.2, M["cyan"][1]), (0.08, M["cyan"][2])):
        lot.put(m, G.tube([(0.0, 0.0, z0 + (z1 - z0) * t / 8.0) for t in range(9)], rr, 8))


def couronne(lot, M, r):
    """Sur l'anneau du haut : 9 pics de givre et de chrome qui ferment la silhouette en couronne glacée, plus 4 cuves de gaz liquide."""
    ra = r_ann(N_ANN - 1)
    f = xf_ann(N_ANN - 1)
    lot.xf = f
    for k in range(18):
        a = G.TAU * k / 18.0 + 0.1
        p = (ra * math.cos(a), ra * math.sin(a), 1.4)
        L = (3.5 if k % 2 == 0 else 2.0) + r.f(0, 1.2)
        F.eclat_cristal(lot, M["glace"] if k % 3 else M["chrome"], p, (math.cos(a) * 0.45, math.sin(a) * 0.45, 1.0), L, 0.32, r, 6)
    for k in range(4):
        a = G.TAU * (k + 0.5) / 4 - 0.4
        c = ((ra + 1.1) * math.cos(a), (ra + 1.1) * math.sin(a))
        lot.put(M["givre"], G.sphere((c[0], c[1], 1.5), 0.95, 16, 8))
        lot.put(M["acier"], G.tour([(0.2, 0.7), (1.0, 0.9), (1.05, 0.98), (1.2, 0.98)], 16, "z", (c[0], c[1], 0.0)))
    lot.xf = None


def build(S, lot, variante="trombe"):
    M = matieres(S)
    r = G.Rnd(1212)
    R.raz()
    for i in range(N_ANN):
        anneau_tornade(lot, M, i, r)
    aiguille(lot, M, r)
    couronne(lot, M, r)
    return dict(R.COMPTE)
