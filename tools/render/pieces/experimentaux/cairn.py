"""CAIRN, expérimental de l'âge 10 (Haute technologie) : une pile de galets en lévitation, en équilibre impossible. Lot EXP2, 1/11.
Bible : dômes lisses, antennes fouet, carénage gris clair, noir mat, voyants bleus, « les corps se lèvent ». 6 lentilles qui ne se touchent pas,
décalées les unes des autres ; entre elles, du vide et des colonnes de champ. Des dizaines d'antennes fouet en font un saule d'acier.
Une image pour toutes les directions (elle ne se retourne pas).
"""
import math

import fam as F
import geo as G
import greb as R
import mat as MT

GROUPES = {"bleu": ("ca_b",), "hublots": ("ca_h",)}
# centre (x, y, z), demi-largeur, demi-hauteur
GALETS = [((0.0, 0.0, 10.5), 6.5, 2.1), ((3.6, 0.8, 21.5), 13.0, 2.9), ((-3.2, -0.6, 33.5), 10.5, 2.7), ((3.4, 0.5, 44.0), 7.6, 2.3), ((-2.5, -0.4, 52.5), 5.0, 1.8), ((1.2, 0.2, 59.2), 3.0, 1.15)]


def matieres(S):
    surf = F.surf_de("ca")
    F.patine(ta=0.14, ra=0.25, ec=0.32, nu_k=1.3, ec_col=(0.03, 0.03, 0.035), sans=("noir",))
    M = {}
    M["car"] = surf("car", (0.56, 0.57, 0.59), rough=0.3, met=0.1, tole=(3.2, 1.7), joint=0.32, joint_l=0.012, var=0.07, coulures=0.7, rouille=(0.06, 0.055, 0.05), usure=0.4,
                    nu=(0.8, 0.8, 0.82), crasse=0.8, crasse_col=(0.02, 0.02, 0.022), relief=0.5, graine=1)
    M["car2"] = surf("car2", (0.36, 0.37, 0.39), rough=0.34, met=0.2, tole=(1.6, 0.9), joint=0.35, joint_l=0.02, var=0.1, coulures=0.7, rouille=(0.05, 0.045, 0.04), usure=0.45,
                     nu=(0.7, 0.7, 0.72), crasse=0.8, crasse_col=(0.015, 0.015, 0.017), relief=0.5, graine=2)
    M["noir"] = surf("noir", (0.02, 0.021, 0.024), rough=0.5, met=0.4, usure=0.5, nu=(0.24, 0.25, 0.28), crasse=0.5, crasse_col=(0.003, 0.003, 0.004), graine=3)
    M["acier"] = surf("acier", (0.12, 0.125, 0.135), rough=0.42, met=0.7, usure=0.65, nu=(0.5, 0.5, 0.52), crasse=0.7, crasse_col=(0.006, 0.006, 0.007), graine=4)
    M["blanc"] = surf("blanc", (0.76, 0.77, 0.78), rough=0.28, met=0.0, coulures=0.5, rouille=(0.08, 0.075, 0.07), usure=0.3, nu=(0.9, 0.9, 0.9), crasse=0.6, crasse_col=(0.03, 0.03, 0.03), graine=5)
    M["verre"] = MT.verre("ca_verre", col=(0.01, 0.014, 0.02), reflet=(0.16, 0.22, 0.3))
    M["bleu"] = F.trio(S, "ca_b", (0.1, 0.42, 1.0), 1.0, clair=(0.7, 0.88, 1.0))
    M["hublot"] = MT.lumiere(S, "ca_h", (0.72, 0.86, 1.0), 1.1, main=0.28)
    M["voyant"] = MT.lumiere(S, "ca_h_v", (0.2, 0.55, 1.0), 2.0, main=0.4)
    return M


def lentille(c, a, h):
    """Profil d'une lentille : ventre plat, dôme lisse ; points (z, r)."""
    z = c[2]
    return [(z - h, 0.02), (z - h * 0.86, a * 0.42), (z - h * 0.5, a * 0.8), (z - h * 0.16, a * 0.98), (z, a), (z + h * 0.18, a * 0.97), (z + h * 0.55, a * 0.76), (z + h * 0.86, a * 0.42), (z + h, 0.02)]


def fouet(lot, M, p, az, L, rnd):
    """Antenne fouet : part de l'équateur, monte, retombe en arc ; voyant au bout ; bagues sur le pied."""
    ca, sa = math.cos(az), math.sin(az)
    m = rnd.f(0.25, 0.7)
    q1 = G.add(p, (ca * L * 0.4, sa * L * 0.4, L * m * 0.5))
    q2 = G.add(p, (ca * L * 0.8, sa * L * 0.8, L * m * 0.46))
    q3 = G.add(p, (ca * L, sa * L, L * (m * 0.1 - 0.1)))
    pts = G.catmull([p, q1, q2, q3], 6)
    lot.put(M["acier"], G.tube(pts, 0.13, 6, rfun=lambda s_, i: max(0.025, 0.14 - 0.11 * i / 18.0)))
    lot.put(M["noir"], G.tour([(0.0, 0.38), (0.35, 0.28), (0.8, 0.18), (0.8, 0.0)], 8, "z", p, cap0=True))
    lot.put(M["voyant"], G.sphere(q3, 0.12, 8, 4))


def galet(lot, M, i, c, a, h, rnd):
    P = F.Prof(lentille(c, a, h))
    cc = (c[0], c[1])
    lot.put(M["noir"], G.tour(F.Prof(lentille(c, a * 0.97, h * 0.86)).pts, 96, "z", (c[0], c[1], 0.0)))
    z = c[2]
    # carénage lisse, en grandes plaques : dessus et ventre, ceinture noire à l'équateur
    F.blindage(lot, [M["car"], M["blanc"], M["car2"]], P, z + h * 0.2, z + h * 0.9, 2, 12 + 2 * i, rnd, e=(0.06, 0.2), vis=0.85, c=cc, poids=[0.55, 0.3, 0.15], Mdet=M["car2"])
    F.blindage(lot, [M["car2"], M["car"]], P, z - h * 0.82, z - h * 0.24, 2, 10 + 2 * i, rnd, e=(0.06, 0.24), vis=0.6, c=cc)
    lot.put(M["acier"], F.patch(P, 0.0, G.TAU, z - h * 0.24, z - h * 0.16, -0.05, 0.3, cc, n=96))
    lot.put(M["acier"], F.patch(P, 0.0, G.TAU, z + h * 0.16, z + h * 0.22, -0.05, 0.26, cc, n=96))
    F.fentes(lot, M["bleu"], P, z, int(a * 2.4), 0.62, h * 0.11, M["acier"], vis=0.7, dec=0.1 * i, c=cc)
    F.baies(lot, M["acier"], M["hublot"], M["verre"], P, z + h * 0.34, int(a * 8), rnd, ouvert=0.72, vis=0.6, c=cc)
    F.baies(lot, M["acier"], M["hublot"], M["verre"], P, z - h * 0.36, int(a * 6), rnd, ouvert=0.5, vis=0.5, c=cc)
    # le dessus : petit quartier (dômes, trappes, pistes, coursives) qui donne l'échelle
    ztop = z + h * 0.72
    rt = P.rz(ztop)
    F.anneau(lot, M["acier"], ztop + 0.05, rt * 0.86, rt + 0.04, 0.12, c=cc, n=96)
    F.rail(lot, M["acier"], rt, ztop + 0.12, cc, n=48, vis=0.8)
    for k in range(4 + i % 3):
        th = rnd.f(0, G.TAU)
        rr = rnd.f(0.15, 0.62) * rt
        q = (c[0] + rr * math.cos(th), c[1] + rr * math.sin(th))
        zq = max(ztop, z + h * (0.95 - 0.3 * (rr / rt) ** 2) - 0.1)
        s = rnd.f(0.7, 1.5)
        lot.put(M["blanc"], G.tour([(zq, s), (zq + s * 0.5, s * 0.8), (zq + s * 0.85, s * 0.35), (zq + s * 0.95, 0.0)], 20, "z", (q[0], q[1], 0.0)))
        lot.put(M["acier"], G.tour([(zq - 0.02, s + 0.1), (zq + 0.1, s + 0.1), (zq + 0.1, s - 0.04)], 20, "z", (q[0], q[1], 0.0)))
    # antennes fouet sur tout le pourtour
    n = int(a * 2.6)
    for k in range(n):
        az = G.TAU * (k + 0.5) / n + 0.05 * i
        p = P.pt(az, z + h * 0.08, 0.0, cc)
        fouet(lot, M, p, az, rnd.f(a * 0.34, a * 0.72) + 2.0, rnd)
    # sous le ventre : pince de levage, projecteur
    lot.put(M["acier"], G.tour([(z - h - 0.4, 0.0), (z - h - 0.3, a * 0.2), (z - h * 0.7, a * 0.26)], 24, "z", (c[0], c[1], 0.0)))
    lot.put(M["voyant"], G.sphere((c[0], c[1], z - h - 0.45), 0.22, 10, 5))


def champ(lot, M, a, b, ra, rb, rnd):
    """Entre 2 galets, rien ne touche : 6 aiguilles de guidage et une colonne de lumière à dégradé."""
    for k in range(6):
        th = G.TAU * k / 6 + 0.3
        r0 = ra * 0.28
        p0 = (a[0] + r0 * math.cos(th), a[1] + r0 * math.sin(th), a[2])
        p1 = (b[0] + r0 * 0.7 * math.cos(th), b[1] + r0 * 0.7 * math.sin(th), b[2])
        mid0 = G.lerp(p0, p1, 0.42)
        mid1 = G.lerp(p0, p1, 0.58)
        lot.put(M["acier"], G.tube([p0, mid0], 0.12, 6))
        lot.put(M["acier"], G.tube([mid1, p1], 0.12, 6))
    for (rr, m) in ((0.6, M["bleu"][0]), (0.34, M["bleu"][1]), (0.14, M["bleu"][2])):
        pts = [G.lerp(a, b, t / 6.0) for t in range(7)]
        lot.put(m, G.tube(pts, rr, 10))


def build(S, lot, variante="cairn"):
    M = matieres(S)
    r = G.Rnd(1010)
    R.raz()
    for i, (c, a, h) in enumerate(GALETS):
        galet(lot, M, i, c, a, h, r)
    for i in range(len(GALETS) - 1):
        (c0, a0, h0), (c1, a1, h1) = GALETS[i], GALETS[i + 1]
        champ(lot, M, (c0[0], c0[1], c0[2] + h0), (c1[0], c1[1], c1[2] - h1), a0, a1, r)
    # pointe : mât de tête, parabole, bouquet d'antennes
    c, a, h = GALETS[-1]
    zt = c[2] + h
    lot.put(M["acier"], G.tour([(zt - 0.1, 0.5), (zt + 3.5, 0.16), (zt + 7.5, 0.03)], 10, "z", (c[0], c[1], 0.0), cap0=True, cap1=True))
    lot.put(M["voyant"], G.sphere((c[0], c[1], zt + 7.6), 0.2, 10, 5))
    lot.put(M["blanc"], G.oriente(G.tour([(0.0, 0.0), (0.2, 0.8), (0.55, 1.5)], 24, "z"), (c[0], c[1], zt + 2.0), (0.4, -0.5, 0.8)))
    return dict(R.COMPTE)
