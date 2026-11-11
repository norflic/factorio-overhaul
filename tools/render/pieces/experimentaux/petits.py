"""PETITS EXPÉRIMENTAUX (lot EXP2, 1/11) : 8 à 18 tuiles, même soin que les géants, plus abordables.
Défense, posés : MÂT-FOUDRE (âge 6), SARRACÉNIE (âge 8), VEILLEUSE (âge 13). Attaque : GÉODE (âge 7), DEMI-VIE (âge 9), MARTINET (âge 11).
"""
import math

import fam as F
import geo as G
import greb as R
import mat as MT

GROUPES = {"mat_foudre": {"arc": ("mf_a",), "hublots": ("mf_h",)}, "geode": {"cristal": ("ge_c",)}, "sarracenie": {"suc": ("sa_s",)},
           "demi_vie": {"uranium": ("dv_u",), "hublots": ("dv_h",)}, "martinet": {"ligne": ("ma_l",)}, "veilleuse": {"plasma": ("ve_p",), "soleil": ("ve_s",)}}


# ------------------------------------------------------------------------------------------------ Mât-Foudre, âge 6
def mat_foudre(S, lot):
    surf = F.surf_de("mf")
    F.patine(ta=0.15, ra=0.2, ec=0.3, nu_k=1.3, ec_col=(0.06, 0.04, 0.025), sans=("cuivre",))
    r = G.Rnd(606)
    k_e = 1.35
    lot.xf = lambda v: (v[0] * k_e, v[1] * k_e, v[2] * k_e)
    M = {}
    M["cera"] = surf("cera", (0.72, 0.7, 0.62), rough=0.22, met=0.0, coulures=0.7, rouille=(0.14, 0.09, 0.05), usure=0.4, nu=(0.88, 0.86, 0.8), crasse=0.7, crasse_col=(0.03, 0.022, 0.014), graine=1)
    M["cera2"] = surf("cera2", (0.27, 0.13, 0.06), rough=0.2, met=0.0, coulures=0.5, rouille=(0.1, 0.06, 0.03), usure=0.4, nu=(0.55, 0.36, 0.22), crasse=0.6, crasse_col=(0.015, 0.008, 0.004), graine=2)
    M["cuivre"] = surf("cuivre", (0.45, 0.19, 0.07), rough=0.33, met=0.85, coulures=0.5, rouille=(0.05, 0.14, 0.1), usure=0.65, nu=(0.85, 0.52, 0.3), crasse=0.7, crasse_col=(0.01, 0.005, 0.003), graine=3)
    M["acier"] = surf("acier", (0.1, 0.09, 0.08), rough=0.45, met=0.7, coulures=0.5, rouille=(0.1, 0.05, 0.02), usure=0.65, nu=(0.45, 0.42, 0.38), crasse=0.7, crasse_col=(0.006, 0.005, 0.004), graine=4)
    M["beton"] = surf("beton", (0.2, 0.18, 0.15), rough=0.85, met=0.0, tole=(1.2, 0.6), joint=0.55, joint_l=0.012, var=0.12, coulures=0.6, rouille=(0.05, 0.035, 0.02), usure=0.6, nu=(0.32, 0.28, 0.24), crasse=0.85,
                    crasse_col=(0.01, 0.008, 0.006), relief=0.4, graine=5)
    M["verre"] = MT.verre("mf_verre", col=(0.012, 0.016, 0.02), reflet=(0.2, 0.25, 0.3))
    M["arc"] = F.trio(S, "mf_a", (0.1, 0.72, 1.0), 1.05, clair=(0.8, 0.97, 1.0))
    M["hublot"] = MT.lumiere(S, "mf_h", (1.0, 0.82, 0.5), 1.1, main=0.28)
    # socle à gradins, porte, tubes d'huile
    lot.put(M["beton"], G.prisme(R.octo((0, 0), 3.9, 8), 0.0, 0.9, top_scale=0.88))
    lot.put(M["acier"], G.prisme(R.octo((0, 0), 3.4, 8), 0.9, 2.1, top_scale=0.8))
    lot.put(M["cuivre"], G.prisme(R.octo((0, 0), 3.55, 8), 0.86, 1.02))
    lot.put(M["cuivre"], G.prisme(R.octo((0, 0), 2.85, 8), 2.05, 2.22))
    for a in [G.TAU * k / 8 + math.pi / 8 for k in range(8)]:
        if not F.vu(a, 0.3):
            continue
        q = (3.15 * math.cos(a), 3.15 * math.sin(a), 1.5)
        n = (math.cos(a), math.sin(a), 0.1)
        R.hublot(lot, M["cuivre"], M["hublot"] if r.f() < 0.6 else M["verre"], q, n, ["ogive", "carre", "double"][r.i(0, 2)], t=0.2)
    # pile d'isolateurs à ailettes, de plus en plus fine
    z = 2.2
    rb = 2.2
    for i in range(9):
        h = 1.05 - 0.04 * i
        ra = rb * (1.0 - 0.06 * i)
        m = M["cera"] if i % 3 != 2 else M["cera2"]
        lot.put(M["acier"], G.tour([(z, ra * 0.42), (z + 0.08, ra * 0.42)], 20, "z", cap0=True, cap1=True))
        prof = [(z + 0.08, ra * 0.36), (z + 0.14, ra * 1.3), (z + 0.2, ra * 1.3), (z + 0.36, ra * 0.5), (z + h * 0.56, ra * 0.5), (z + h * 0.66, ra * 0.96), (z + h * 0.72, ra * 0.96), (z + h * 0.84, ra * 0.42), (z + h, ra * 0.36)]
        lot.put(m, G.tour(prof, 32, "z"))
        if i % 3 == 0:
            lot.put(M["cuivre"], G.tour([(z + 0.1, ra * 0.5), (z + 0.1, ra * 1.1), (z + 0.2, ra * 1.1), (z + 0.2, ra * 0.5)], 32, "z"))
            for k in range(10):
                a = G.TAU * k / 10
                lot.put(M["acier"], G.tour([(z + 0.2, 0.05), (z + 0.26, 0.03), (z + 0.27, 0.0)], 6, "z", (ra * 0.92 * math.cos(a), ra * 0.92 * math.sin(a), 0.0), cap0=True))
        z += h
    # 3 barres de cuivre qui longent la pile, de la bobine au socle, brides
    for k in range(3):
        a = -math.pi / 2 + k * G.TAU / 3 + 0.35
        pts = [(2.65 * math.cos(a), 2.65 * math.sin(a), 2.1), (1.7 * math.cos(a), 1.7 * math.sin(a), 6.0), (1.1 * math.cos(a), 1.1 * math.sin(a), z - 0.5)]
        R.tuyau(lot, M["cuivre"], M["acier"], pts, 0.12, pas_bride=1.5)
    # bobine, tore et éclateurs
    lot.put(M["cuivre"], G.tour([(z, 0.8), (z + 0.2, 1.1), (z + 1.6, 1.1), (z + 1.8, 0.8)], 24, "z"))
    for j in range(9):
        lot.put(M["cera2"] if j % 3 == 0 else M["cuivre"], G.tour([(z + 0.2 + j * 0.16, 1.16), (z + 0.28 + j * 0.16, 1.16), (z + 0.28 + j * 0.16, 1.1), (z + 0.2 + j * 0.16, 1.1)], 24, "z"))
    zt = z + 2.5
    prof = []
    for i in range(17):
        a = G.TAU * i / 16
        prof.append((zt + 0.72 * math.sin(a), 2.45 + 0.72 * math.cos(a)))
    lot.put(M["cuivre"], G.tour(prof, 48, "z"))
    lot.put(M["acier"], G.tour([(zt - 0.6, 0.7), (zt, 1.8), (zt + 0.3, 1.8), (zt + 0.8, 0.3)], 24, "z"))
    for k in range(8):
        a = G.TAU * k / 8 + 0.2
        p = (3.1 * math.cos(a), 3.1 * math.sin(a), zt)
        lot.put(M["acier"], G.oriente(G.tour([(0.0, 0.12), (0.5, 0.08), (0.52, 0.0)], 8, "z"), p, (math.cos(a), math.sin(a), 0.1)))
    # éclateur central : pointe, 3 couches de lumière
    lot.put(M["acier"], G.tour([(zt + 0.6, 0.3), (zt + 2.6, 0.09), (zt + 2.7, 0.0)], 10, "z", cap0=True))
    for (rr, m) in ((0.62, M["arc"][0]), (0.42, M["arc"][1]), (0.2, M["arc"][2])):
        lot.put(m, G.sphere((0, 0, zt + 2.8), rr, 16, 8))
    # fentes sur le tore
    for k in range(12):
        a0 = G.TAU * k / 12
        for (m, dz) in ((M["arc"][0], 0.26), (M["arc"][1], 0.15), (M["arc"][2], 0.06)):
            lot.put(m, G.tour([(zt + 0.72, 2.45 - dz), (zt + 0.72, 2.45 + dz)], 8, "z", a0=a0, a1=a0 + 0.25))
    lot.xf = None
    return {}


# ------------------------------------------------------------------------------------------------ Géode, âge 7
def geode(S, lot):
    surf = F.surf_de("ge")
    F.patine(ta=0.2, ra=0.15, ec=0.3, nu_k=1.3, ec_col=(0.03, 0.028, 0.03), sans=("bronze",))
    r = G.Rnd(707)
    M = {}
    M["roche"] = surf("roche", (0.1, 0.085, 0.08), rough=0.9, met=0.0, coulures=0.5, rouille=(0.04, 0.03, 0.03), usure=0.7, nu=(0.28, 0.25, 0.25), crasse=0.85, crasse_col=(0.008, 0.006, 0.007), graine=1)
    M["roche2"] = surf("roche2", (0.2, 0.17, 0.15), rough=0.85, met=0.0, usure=0.7, nu=(0.38, 0.34, 0.32), crasse=0.8, crasse_col=(0.01, 0.008, 0.008), graine=2)
    M["bronze"] = surf("bronze", (0.34, 0.2, 0.07), rough=0.36, met=0.8, coulures=0.7, rouille=(0.05, 0.16, 0.12), usure=0.65, nu=(0.82, 0.62, 0.32), crasse=0.8, crasse_col=(0.01, 0.006, 0.003), graine=3)
    M["cri"] = MT.verre("ge_cri_v", col=(0.11, 0.015, 0.25), reflet=(0.6, 0.35, 0.95))
    M["cristal"] = F.trio(S, "ge_c", (0.55, 0.1, 1.0), 1.05, clair=(0.95, 0.75, 1.0))
    cz = 9.5
    Ray = 5.3
    # coque de roche : une sphère dont un quartier sud-est est arraché
    def perturbe(q, s=1.0):
        return 1.0 + 0.11 * math.sin(q[0] * 1.6 + 1.3) * math.sin(q[1] * 1.9 + 0.3) + 0.07 * math.sin(q[2] * 2.7 + q[0] * 1.1)

    def bloc_roche(la0, la1, lo0, lo1, e0, e1, m):
        rings = []
        n = 6
        for i in range(n + 1):
            la = la0 + (la1 - la0) * i / n
            ring = []
            for j in list(range(n + 1)):
                lo = lo0 + (lo1 - lo0) * j / n
                q = (math.cos(la) * math.cos(lo), math.cos(la) * math.sin(lo), math.sin(la))
                ring.append((Ray * e1 * perturbe(q) * q[0], Ray * e1 * perturbe(q) * q[1] * 1.15, cz + Ray * e1 * perturbe(q) * q[2]))
            for j in list(range(n, -1, -1)):
                lo = lo0 + (lo1 - lo0) * j / n
                q = (math.cos(la) * math.cos(lo), math.cos(la) * math.sin(lo), math.sin(la))
                ring.append((Ray * e0 * perturbe(q) * q[0], Ray * e0 * perturbe(q) * q[1] * 1.15, cz + Ray * e0 * perturbe(q) * q[2]))
            rings.append(ring)
        lot.put(m, G.loft(rings, True, True))

    az_trou = -math.pi / 3.2
    nl, nlo = 7, 13
    for i in range(nl):
        la0 = -math.pi / 2 + 0.05 + i * (math.pi - 0.1) / nl
        la1 = la0 + (math.pi - 0.1) / nl - 0.035
        for j in range(nlo):
            lo0 = G.TAU * j / nlo + 0.12 * i
            lo1 = lo0 + G.TAU / nlo - 0.03
            lam, lom = (la0 + la1) / 2, (lo0 + lo1) / 2
            # distance angulaire au centre de l'ouverture
            d = math.acos(max(-1.0, min(1.0, math.cos(lam - 0.36) * math.cos(lom - az_trou))))
            if d < 0.86:
                continue
            bloc_roche(la0, la1, lo0, lo1, 0.8, r.f(0.96, 1.08), M["roche"] if r.f() < 0.62 else M["roche2"])
    # intérieur : tapis de cristaux violets, gros au centre de l'ouverture, qui dépassent en pointes asymétriques
    lot.put(M["cristal"][0], G.sphere((0.0, 0.0, cz), Ray * 0.76, 24, 12))
    lot.put(M["cri"], G.sphere((0.0, 0.0, cz), Ray * 0.78, 24, 12))
    nz = (math.cos(0.36) * math.cos(az_trou), math.cos(0.36) * math.sin(az_trou), math.sin(0.36))
    for i in range(38):
        th = r.f(-1.1, 1.1)
        ph = r.f(-1.1, 1.1)
        d = G.norm((nz[0] + th * 0.8 * -nz[1], nz[1] + th * 0.8 * nz[0], nz[2] + ph * 0.75))
        base = G.add((0.0, 0.0, cz), G.mul(d, Ray * 0.55))
        L = r.f(1.3, 4.2) * (1.25 - 0.5 * (abs(th) + abs(ph)))
        rc = r.f(0.28, 0.55)
        F.eclat_cristal(lot, M["cri"], base, d, L, rc, r, 6)
        # cœur lumineux dans chaque gros cristal
        if rc > 0.36:
            F.eclat_cristal(lot, M["cristal"][1], G.add(base, G.mul(d, 0.1)), d, L * 0.82, rc * 0.45, r, 5)
            F.eclat_cristal(lot, M["cristal"][2], G.add(base, G.mul(d, 0.2)), d, L * 0.52, rc * 0.18, r, 4)
    # pointes de l'autre côté, sur le dessus : l'asymétrie
    for (a, b, L, rc) in ((0.9, 1.0, 4.4, 0.62), (2.4, 0.9, 3.4, 0.5), (0.2, 1.2, 2.8, 0.44), (3.5, 0.5, 2.8, 0.46)):
        d = (math.cos(b) * math.cos(a), math.cos(b) * math.sin(a), math.sin(b))
        base = G.add((0.0, 0.0, cz), G.mul(d, Ray * 0.82))
        F.eclat_cristal(lot, M["cri"], base, d, L, rc, r, 6)
        F.eclat_cristal(lot, M["cristal"][1], base, d, L * 0.78, rc * 0.42, r, 5)
    # cerclage de bronze : 3 bandes à griffes, qui la tiennent fermée, et 4 ailettes de stabilisation
    for (a0, a1, inc) in ((1.2, 4.4, 0.0), (0.6, 3.8, 0.52), (2.4, 5.1, -0.45)):
        pts = []
        for j in range(32):
            a = a0 + (a1 - a0) * j / 31.0
            q = (math.cos(a) * math.cos(inc), math.sin(a), math.cos(a) * math.sin(inc) * 0.9)
            k = Ray * 1.09
            pts.append((q[0] * k, q[1] * k * 1.15, cz + q[2] * k))
        lot.put(M["bronze"], G.tube(pts, 0.17, 6))
        for t in (0, 15, 31):
            lot.put(M["bronze"], G.sphere(pts[t], 0.32, 10, 5))
    # sous le ventre : le moteur de lévitation, bronze et chaînes
    lot.put(M["bronze"], G.tour([(cz - Ray * 1.02, 2.2), (cz - Ray * 1.2, 1.6), (cz - Ray * 1.32, 0.6), (cz - Ray * 1.5, 0.0)], 20, "z", cap1=False))
    for k in range(5):
        a = G.TAU * k / 5 + 0.3
        p = (2.0 * math.cos(a), 2.0 * math.sin(a), cz - Ray * 1.1)
        L = r.f(1.5, 3.0)
        F.eclat_cristal(lot, M["cri"], p, (0.1 * math.cos(a), 0.1 * math.sin(a), -1.0), L, 0.28, r, 5)
    # éclats qui gravitent
    for k in range(9):
        a = r.f(0, G.TAU)
        rr = Ray * r.f(1.4, 1.75)
        p = (rr * math.cos(a), rr * math.sin(a) * 1.15, cz + r.f(-3, 3))
        d = G.norm((r.f(-1, 1), r.f(-1, 1), r.f(-0.3, 1)))
        F.eclat_cristal(lot, M["cri"], p, d, r.f(0.5, 1.2), r.f(0.14, 0.26), r, 5)
    return {}


# ------------------------------------------------------------------------------------------------ Sarracénie, âge 8
def _urne(lot, M, c, z0, H, ray, r, inc=0.0):
    """Une urne de verre, à col et opercule : liquide luminescent dedans (3 couches), nervures de vert-de-gris."""
    x, y = c
    prof = [(z0, ray * 0.26), (z0 + H * 0.08, ray * 0.55), (z0 + H * 0.26, ray * 0.95), (z0 + H * 0.46, ray), (z0 + H * 0.66, ray * 0.76), (z0 + H * 0.82, ray * 0.48), (z0 + H * 0.92, ray * 0.46), (z0 + H, ray * 0.68)]
    P = F.Prof(prof)
    # liquide : 3 couches emboîtées, niveau à 58 % de la hauteur
    for (k, m) in ((0.9, M["suc"][0]), (0.72, M["suc"][1]), (0.42, M["suc"][2])):
        pts = [(z0 + H * t, P.rz(z0 + H * t) * k) for t in (0.07, 0.2, 0.34, 0.46, 0.56)]
        lot.put(m, G.tour([(z0 + H * 0.06, 0.0)] + pts + [(z0 + H * 0.58, 0.0)], 28, "z", (x, y, 0.0)))
    # verre
    lot.put(M["verre"], G.tour(P.pts, 40, "z", (x, y, 0.0)))
    # nervures, cerclages
    for k in range(10):
        a = G.TAU * k / 10 + 0.2
        pts = [(x + (P.rz(z0 + H * t) + 0.05) * math.cos(a), y + (P.rz(z0 + H * t) + 0.05) * math.sin(a), z0 + H * t) for t in [j / 16.0 for j in range(17)]]
        lot.put(M["vert"], G.tube(pts, 0.05 + ray * 0.012, 6))
    for t, e in ((0.12, 0.13), (0.3, 0.09), (0.66, 0.1), (0.9, 0.2), (1.0, 0.16)):
        z = z0 + H * t
        lot.put(M["vert"] if t != 0.9 else M["laiton"], G.tour([(z - e, P.rz(z) - 0.02), (z - e, P.rz(z) + 0.08), (z + e, P.rz(z) + 0.08), (z + e, P.rz(z) - 0.02)], 32, "z", (x, y, 0.0)))
    # opercule ouvert, charnière, buse : l'urne crache par le col
    zt = z0 + H
    rt = P.rz(zt)
    v, f, u = G.tour([(0.0, rt * 1.2), (0.12, rt * 1.15), (0.26, rt * 0.7), (0.3, 0.0)], 24, "z")
    v = [G.add(G.rot_y(q, -0.8), (x - rt * 0.76, y, zt + rt * 0.8)) for q in v]
    lot.put(M["vert"], (v, f, u))
    lot.put(M["laiton"], G.tube([(x - rt, y - 0.3, zt), (x - rt, y + 0.3, zt)], 0.14, 8))
    lot.put(M["noir"], G.tour([(zt - 0.2, rt * 0.82), (zt + 0.02, rt * 0.82)], 20, "z", (x, y, 0.0), cap1=True))
    lot.put(M["suc"][2], G.tour([(zt + 0.03, rt * 0.3), (zt + 0.04, 0.0)], 16, "z", (x, y, 0.0)))
    lot.put(M["suc"][1], G.tour([(zt + 0.03, rt * 0.62), (zt + 0.03, rt * 0.3)], 16, "z", (x, y, 0.0)))


def sarracenie(S, lot):
    surf = F.surf_de("sa")
    F.patine(ta=0.18, ra=0.15, ec=0.35, nu_k=1.3, ec_col=(0.03, 0.06, 0.04), sans=("verre",))
    r = G.Rnd(808)
    M = {}
    M["vert"] = surf("vert", (0.1, 0.22, 0.15), rough=0.45, met=0.55, coulures=0.7, rouille=(0.2, 0.3, 0.2), usure=0.55, nu=(0.55, 0.45, 0.25), crasse=0.8, crasse_col=(0.008, 0.012, 0.008), graine=1)
    M["laiton"] = surf("laiton", (0.36, 0.24, 0.07), rough=0.36, met=0.75, coulures=0.7, rouille=(0.08, 0.2, 0.14), usure=0.6, nu=(0.82, 0.68, 0.32), crasse=0.75, crasse_col=(0.01, 0.008, 0.003), graine=2)
    M["vase"] = surf("vase", (0.07, 0.075, 0.035), rough=0.8, met=0.0, coulures=0.5, rouille=(0.1, 0.12, 0.05), usure=0.5, nu=(0.22, 0.22, 0.12), crasse=0.85, crasse_col=(0.006, 0.007, 0.003), graine=3)
    M["noir"] = surf("noir", (0.02, 0.022, 0.016), rough=0.5, met=0.4, usure=0.4, nu=(0.2, 0.2, 0.16), crasse=0.6, crasse_col=(0.003, 0.003, 0.002), graine=4)
    M["verre"] = MT.verre("sa_verre", col=(0.08, 0.17, 0.06), reflet=(0.65, 0.85, 0.55))
    M["suc"] = F.trio(S, "sa_s", (0.5, 0.95, 0.08), 1.05, clair=(0.95, 1.0, 0.55))
    # plateforme de vase et de tuyaux, pattes-racines qui s'accrochent au sol
    lot.put(M["vase"], G.prisme(R.octo((0, 0), 5.2, 8), 0.0, 0.8, top_scale=0.82))
    lot.put(M["vert"], G.prisme(R.octo((0, 0), 4.3, 8), 0.8, 1.6, top_scale=0.88))
    lot.put(M["laiton"], G.prisme(R.octo((0, 0), 4.45, 8), 0.76, 0.92))
    for k in range(9):
        a = G.TAU * k / 9 + 0.15
        p0 = (3.8 * math.cos(a), 3.8 * math.sin(a), 1.0)
        p1 = (5.4 * math.cos(a + 0.1), 5.4 * math.sin(a + 0.1) * 1.2, 1.1)
        p2 = (7.0 * math.cos(a + 0.2), 7.0 * math.sin(a + 0.2) * 1.3, 0.05)
        lot.put(M["vert"], G.tube(G.catmull([p0, p1, p2], 6), 0.26, 8, rfun=lambda s_, i: 0.3 - 0.012 * i))
        lot.put(M["laiton"], G.sphere(p2, 0.24, 8, 4))
    # 3 urnes de tailles et d'inclinaisons différentes
    _urne(lot, M, (-0.9, 1.2), 1.6, 12.8, 2.9, r)
    _urne(lot, M, (2.8, -0.3), 1.6, 8.8, 2.1, r)
    _urne(lot, M, (-2.8, -1.9), 1.6, 6.4, 1.65, r)
    # conduits annelés entre les urnes et bulbes de transfert
    R.flexible(lot, M["laiton"], M["vert"], [(-0.4, 0.1, 3.3), (1.0, -1.0, 5.2), (2.0, -1.0, 4.6), (2.5, -0.9, 3.1)], 0.14, pas=0.22)
    R.flexible(lot, M["laiton"], M["vert"], [(-1.7, 0.4, 3.0), (-2.5, -0.4, 4.4), (-2.9, -1.4, 3.8), (-3.0, -1.7, 2.9)], 0.12, pas=0.22)
    for (x, y) in ((1.0, 2.4), (3.0, 1.9), (-3.9, 1.0), (0.3, -3.2)):
        lot.put(M["verre"], G.sphere((x, y, 2.3), 0.72, 16, 8))
        lot.put(M["suc"][1], G.sphere((x, y, 2.15), 0.42, 12, 6))
        lot.put(M["vert"], G.tour([(1.6, 0.3), (1.7, 0.5), (1.95, 0.42)], 12, "z", (x, y, 0.0)))
    return {}


# ------------------------------------------------------------------------------------------------ Demi-Vie, âge 9
def demi_vie(S, lot):
    surf = F.surf_de("dv")
    F.patine(ta=0.2, ra=0.25, ec=0.42, nu_k=1.3, ec_col=(0.03, 0.028, 0.025), sans=())
    r = G.Rnd(909)
    k_e = 1.25
    lot.xf = lambda v: (v[0] * k_e, v[1] * k_e, v[2] * k_e)
    M = {}
    M["plomb"] = surf("plomb", (0.17, 0.17, 0.18), rough=0.55, met=0.5, tole=(1.3, 0.8), joint=0.45, joint_l=0.02, var=0.14, coulures=0.7, rouille=(0.06, 0.07, 0.05), usure=0.65, nu=(0.46, 0.46, 0.46), crasse=0.8,
                     crasse_col=(0.008, 0.008, 0.007), relief=0.5, graine=1)
    M["plomb2"] = surf("plomb2", (0.08, 0.08, 0.085), rough=0.5, met=0.55, coulures=0.6, rouille=(0.05, 0.06, 0.04), usure=0.65, nu=(0.34, 0.34, 0.36), crasse=0.75, crasse_col=(0.005, 0.005, 0.005), graine=2)
    M["jaune"] = surf("jaune", (0.72, 0.5, 0.03), rough=0.5, met=0.2, bandes=(1.1, (0.015, 0.014, 0.012), 0.5), coulures=0.7, rouille=(0.12, 0.05, 0.015), usure=0.7, nu=(0.5, 0.45, 0.35), crasse=0.8,
                     crasse_col=(0.012, 0.009, 0.004), graine=3)
    M["beton"] = surf("beton", (0.38, 0.36, 0.3), rough=0.85, met=0.0, tole=(0.9, 0.5), joint=0.6, joint_l=0.012, var=0.12, coulures=0.85, rouille=(0.06, 0.05, 0.03), usure=0.6, nu=(0.52, 0.5, 0.45), crasse=0.85,
                    crasse_col=(0.015, 0.013, 0.01), relief=0.4, graine=4)
    M["noir"] = surf("noir", (0.02, 0.02, 0.018), rough=0.55, met=0.4, usure=0.5, nu=(0.2, 0.2, 0.18), crasse=0.6, crasse_col=(0.003, 0.003, 0.003), graine=5)
    M["verre"] = MT.verre("dv_verre", col=(0.01, 0.03, 0.012), reflet=(0.25, 0.5, 0.25))
    M["ura"] = F.trio(S, "dv_u", (0.25, 1.0, 0.1), 1.05, clair=(0.82, 1.0, 0.6))
    M["hublot"] = MT.lumiere(S, "dv_h", (1.0, 0.82, 0.3), 1.2, main=0.3)
    # traîneau chanfreiné, 4 patins, pare-chocs en plomb
    lot.put(M["plomb2"], G.prisme(R.octo((0, 0), 5.0, 8), 0.8, 2.2, top_scale=0.86))
    lot.put(M["plomb"], G.prisme(R.octo((0, 0), 4.3, 8), 2.2, 3.1, top_scale=0.84))
    lot.put(M["jaune"], G.prisme(R.octo((0, 0), 5.05, 8), 1.0, 1.42))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        c = (4.3 * math.cos(a), 4.3 * math.sin(a) * 1.15)
        lot.put(M["plomb2"], G.prisme(R.octo(c, 1.9, 8), 0.0, 0.8, top_scale=0.72))
        for (rr, m) in ((1.05, M["ura"][0]), (0.68, M["ura"][1]), (0.3, M["ura"][2])):
            lot.put(m, G.tour([(0.82, rr), (0.86, 0.0)], 14, "z", (c[0], c[1], 0.0)))
    for a in [G.TAU * k / 16 for k in range(16)]:
        if F.vu(a, 0.3):
            lot.put(M["plomb"], G.oriente(G.boite((0, 0, 0.12), (0.7, 0.8, 0.24)), (4.82 * math.cos(a), 4.82 * math.sin(a), 1.82), (math.cos(a), math.sin(a), 0.22)))
    # la tour de refroidissement, hyperboloïde en béton : coulures, échafaudage, bande de danger, et la lueur au col
    P = F.Prof([(3.1, 3.9), (4.5, 3.25), (6.5, 2.65), (8.8, 2.36), (10.8, 2.44), (12.6, 2.82)])
    lot.put(M["beton"], G.tour(P.pts, 56, "z"))
    # paroi intérieure, sombre, puis lumière au fond
    lot.put(M["noir"], G.tour([(12.6, 2.82), (12.4, 2.55), (10.5, 2.25), (8.0, 2.1)], 40, "z"))
    for (rr, m) in ((2.15, M["ura"][0]), (1.45, M["ura"][1]), (0.62, M["ura"][2])):
        lot.put(m, G.tour([(9.2 + 0.1 * (2.15 - rr), rr), (9.25 + 0.1 * (2.15 - rr), 0.0)], 40, "z"))
    for z, e in ((4.0, 0.1), (5.3, 0.06), (8.8, 0.08), (11.7, 0.08), (12.6, 0.12)):
        lot.put(M["plomb2"], G.tour([(z - e, P.rz(z) - 0.02), (z - e, P.rz(z) + 0.08), (z + e, P.rz(z) + 0.08), (z + e, P.rz(z) - 0.02)], 48, "z"))
    # bande jaune et noire
    lot.put(M["jaune"], F.patch(P, 0.0, G.TAU, 6.8, 7.6, -0.01, 0.05, n=64))
    # 3 octogones-réacteurs posés sur le pont, sas, cheminées d'évents
    for (a, h, rr) in ((-2.25, 1.9, 1.05), (-0.75, 1.4, 0.9), (2.6, 1.6, 0.8)):
        c = (3.55 * math.cos(a), 3.55 * math.sin(a))
        lot.put(M["plomb"], G.prisme(R.octo(c, rr, 8), 3.0, 3.0 + h, top_scale=0.84))
        lot.put(M["jaune"], G.prisme(R.octo(c, rr + 0.05, 8), 3.0 + h * 0.46, 3.0 + h * 0.6))
        lot.put(M["ura"][1], G.prisme(R.octo(c, rr * 0.5, 8), 3.0 + h, 3.04 + h))
        lot.put(M["ura"][2], G.prisme(R.octo(c, rr * 0.22, 8), 3.04 + h, 3.06 + h))
    # échafaudage sud et échelle (l'échelle d'un personnage)
    R.echafaudage(lot, M["plomb2"], M["jaune"], -1.2, 1.2, -4.0, -3.0, 3.0, 8.4, etages=4)
    pts = [(1.6, -3.2, 3.1), (1.6, -2.4, 12.6)]
    for x in (1.35, 1.85):
        lot.put(M["plomb2"], G.tube([(x, -3.2, 3.1), (x, -2.6, 8.5), (x, -2.65, 12.6)], 0.035, 5))
    for k in range(14):
        z = 3.4 + 0.65 * k
        y = -3.2 + (z - 3.1) / 5.4 * 0.6 if z < 8.5 else -2.6
        lot.put(M["plomb2"], G.tube([(1.35, y, z), (1.85, y, z)], 0.02, 4))
    # voyants, trèfle de danger stylisé : 3 pastilles
    for k in range(12):
        a = -math.pi / 2 + (k - 5.5) * 0.3
        R.hublot(lot, M["plomb2"], M["hublot"], P.pt(a, 3.7, 0.04), P.n(a, 3.7), "carre", t=0.17)
    lot.xf = None
    return {}


# ------------------------------------------------------------------------------------------------ Martinet, âge 11
def martinet(S, lot):
    surf = F.surf_de("ma")
    F.patine(ta=0.16, ra=0.3, ec=0.34, nu_k=1.25, ec_col=(0.07, 0.06, 0.05))
    r = G.Rnd(1117)
    M = {}
    M["blanc"] = surf("blanc", (0.68, 0.67, 0.62), rough=0.34, met=0.1, tole=(1.4, 0.8), joint=0.35, joint_l=0.02, var=0.09, coulures=0.8, rouille=(0.11, 0.09, 0.07), usure=0.5, nu=(0.88, 0.88, 0.86), crasse=0.85,
                     crasse_col=(0.025, 0.022, 0.02), relief=0.5, graine=1)
    M["blanc2"] = surf("blanc2", (0.44, 0.43, 0.4), rough=0.36, met=0.2, tole=(0.8, 0.5), joint=0.35, joint_l=0.03, var=0.12, coulures=0.8, rouille=(0.09, 0.07, 0.05), usure=0.5, nu=(0.75, 0.75, 0.73), crasse=0.85,
                      crasse_col=(0.02, 0.018, 0.016), relief=0.5, graine=2)
    M["titane"] = surf("titane", (0.18, 0.18, 0.19), rough=0.38, met=0.7, coulures=0.4, rouille=(0.1, 0.07, 0.04), usure=0.6, nu=(0.62, 0.62, 0.64), crasse=0.75, crasse_col=(0.008, 0.008, 0.009), graine=3)
    M["noir"] = surf("noir", (0.02, 0.02, 0.024), rough=0.45, met=0.4, usure=0.4, nu=(0.2, 0.2, 0.22), crasse=0.6, crasse_col=(0.003, 0.003, 0.004), graine=4)
    M["brule"] = surf("brule", (0.09, 0.075, 0.065), rough=0.5, met=0.6, usure=0.6, nu=(0.5, 0.42, 0.36), crasse=0.7, crasse_col=(0.006, 0.005, 0.004), graine=5)
    M["verre"] = MT.verre("ma_verre", col=(0.01, 0.015, 0.03), reflet=(0.2, 0.3, 0.45))
    M["ligne"] = F.trio(S, "ma_l", (0.16, 0.5, 1.0), 1.05, clair=(0.8, 0.92, 1.0))
    # une aile en flèche, sans fuselage franc, comme l'oiseau : nez vers l'est-sud-est. Modèle : x vers l'avant.
    psi = -math.radians(24.0)
    Z = 8.0

    def xf(v):
        p = G.rot_z(G.rot_x(v, 0.16), psi)
        return (p[0], p[1], p[2] + Z)
    lot.xf = xf
    def panneau(a, b, c, d, e0, e1, m):
        """Plaque quadrangle de a,b,c,d (sens direct, vue de dessus), épaisseur e0 → e1 (dessus)."""
        v = [G.add(p, (0, 0, e1)) for p in (a, b, c, d)] + [G.add(p, (0, 0, e0)) for p in (a, b, c, d)]
        f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
        u = [(p[0], p[1]) for p in v]
        lot.put(m, (v, f, u))

    N = (9.5, 0.0)        # nez
    # une aile : bord d'attaque de N vers B, bout B, bord de fuite vers le creux Q
    for s in (-1, 1):
        B = (-6.5, s * 16.0)
        Q = (-4.0, s * 1.8)
        cols = 8
        rangs = 4
        for i in range(cols):
            for j in range(rangs):
                t0, t1 = i / float(cols) + 0.006, (i + 1) / float(cols) - 0.006
                u0, u1 = j / float(rangs) + 0.006, (j + 1) / float(rangs) - 0.006
                def pos(t, u):
                    bord = (N[0] + (B[0] - N[0]) * t, N[1] + (B[1] - N[1]) * t)
                    fuite = (Q[0] + (B[0] - Q[0]) * t, Q[1] + (B[1] - Q[1]) * t)
                    return (bord[0] + (fuite[0] - bord[0]) * u, bord[1] + (fuite[1] - bord[1]) * u, (1 - t) * 0.5 - 0.1)
                a, b, c, d = pos(t0, u0), pos(t1, u0), pos(t1, u1), pos(t0, u1)
                x = r.f()
                m = M["blanc"] if x < 0.66 else M["blanc2"] if x < 0.9 else M["titane"]
                panneau(a, b, c, d, -0.1, r.f(0.04, 0.2), m)
        # bord d'attaque brûlé, ligne lumineuse juste derrière
        A = (N[0], 0.0, 0.5)
        Bb = (B[0], B[1], -0.1)
        lot.put(M["brule"], G.tube([A, Bb], 0.2, 8))
        lot.put(M["ligne"][0], G.tube([G.lerp(A, Bb, 0.16), G.lerp(A, Bb, 0.9)], 0.11, 6))
        lot.put(M["ligne"][1], G.tube([G.add(G.lerp(A, Bb, 0.18), (0, 0, 0.03)), G.add(G.lerp(A, Bb, 0.88), (0, 0, 0.03))], 0.07, 6))
        lot.put(M["ligne"][2], G.tube([G.add(G.lerp(A, Bb, 0.2), (0, 0, 0.05)), G.add(G.lerp(A, Bb, 0.86), (0, 0, 0.05))], 0.03, 6))
        # aileron dorsal, bout d'aile relevé, canon de bord d'attaque
        tip = (B[0] - 1.8, B[1] * 1.03, 2.0)
        panneau((B[0], B[1], 0.0), (B[0] + 2.6, B[1] * 0.86, 0.3), (tip[0] + 0.6, tip[1], tip[2]), (tip[0], tip[1], tip[2]), -0.05, 0.05, M["blanc2"])
        for t in (0.34, 0.58):
            p = G.lerp(A, Bb, t)
            lot.put(M["titane"], G.tube([G.add(p, (-0.9, 0, 0.0)), G.add(p, (1.8, 0, 0.0))], 0.13, 8))
            lot.put(M["ligne"][2], G.sphere(G.add(p, (1.82, 0, 0.0)), 0.1, 6, 3))
    # dos : carène, verrière, 2 réacteurs
    prof = [(9.2, 0.0), (7.0, 0.8), (3.5, 1.45), (-1.5, 1.9), (-4.8, 1.5), (-5.2, 1.0)]
    lot.put(M["blanc"], G.tour(prof, 24, "x", (0.0, 0.0, 0.25)))
    for x in (4.5, 2.0, -0.5, -3.0):
        rr = 1.5 + 0.1 * (4.5 - x) * 0.6
        lot.put(M["titane"], G.tour([(x - 0.1, rr), (x + 0.1, rr)], 24, "x", (0.0, 0.0, 0.25)))
    lot.put(M["verre"], G.sphere((4.0, 0.0, 1.5), 0.68, 16, 8))
    for s in (-1, 1):
        y = s * 1.9
        lot.put(M["titane"], G.tour([(-1.2, 0.6), (-1.5, 1.0), (-6.0, 1.05), (-7.0, 0.85), (-7.05, 0.7), (-6.2, 0.4)], 20, "x", (0.0, y, 0.75)))
        for (m, rr, dx) in ((M["ligne"][0], 0.72, 0.0), (M["ligne"][1], 0.46, 0.04), (M["ligne"][2], 0.2, 0.08)):
            lot.put(m, G.tour([(-6.3 + dx, rr), (-6.3 + dx, 0.0)], 16, "x", (0.0, y, 0.75)))
    # 2 dérives
    for s in (-1, 1):
        panneau((-3.0, s * 2.7, 0.8), (-6.4, s * 3.1, 0.8), (-7.2, s * 4.1, 3.2), (-5.7, s * 3.9, 3.2), -0.04, 0.04, M["blanc2"])
    # ventre : soute, rampe de roquettes
    lot.put(M["noir"], G.boite((0.0, 0.0, -0.32), (9.0, 7.0, 0.3)))
    lot.xf = None
    return {}


# ------------------------------------------------------------------------------------------------ Veilleuse, âge 13
def veilleuse(S, lot):
    surf = F.surf_de("ve")
    F.patine(ta=0.13, ra=0.2, ec=0.24, nu_k=1.25, ec_col=(0.07, 0.05, 0.03), sans=("cuivre",))
    r = G.Rnd(1313)
    M = {}
    M["cera"] = surf("cera", (0.62, 0.6, 0.54), rough=0.42, met=0.0, tole=(1.3, 0.8), joint=0.45, joint_l=0.018, var=0.1, coulures=0.7, rouille=(0.09, 0.06, 0.035), usure=0.45, nu=(0.8, 0.78, 0.72), crasse=0.65,
                    crasse_col=(0.03, 0.022, 0.015), relief=0.5, graine=1)
    M["cera2"] = surf("cera2", (0.36, 0.34, 0.3), rough=0.45, met=0.0, coulures=0.7, rouille=(0.07, 0.045, 0.025), usure=0.5, nu=(0.62, 0.6, 0.54), crasse=0.7, crasse_col=(0.022, 0.016, 0.011), graine=2)
    M["cuivre"] = surf("cuivre", (0.3, 0.11, 0.04), rough=0.36, met=0.88, coulures=0.5, rouille=(0.05, 0.12, 0.09), usure=0.65, nu=(0.78, 0.46, 0.26), crasse=0.75, crasse_col=(0.01, 0.005, 0.003), graine=3)
    M["acier"] = surf("acier", (0.12, 0.11, 0.1), rough=0.5, met=0.6, coulures=0.4, rouille=(0.08, 0.04, 0.02), usure=0.6, nu=(0.34, 0.32, 0.3), crasse=0.7, crasse_col=(0.006, 0.005, 0.004), graine=4)
    M["brule"] = surf("brule", (0.06, 0.045, 0.036), rough=0.6, met=0.5, usure=0.6, nu=(0.3, 0.25, 0.2), crasse=0.8, crasse_col=(0.004, 0.003, 0.002), graine=5)
    M["plasma"] = F.trio(S, "ve_p", (1.0, 0.06, 0.58), 1.0, clair=(1.0, 0.6, 0.82))
    M["soleil"] = F.trio(S, "ve_s", (1.0, 0.27, 0.025), 1.25, clair=(1.0, 0.72, 0.3))
    # dalle, 3 pieds hauts et grêles (bible : trépied), jambes à vérins
    C = (0.0, 0.0, 17.5)
    for k in range(3):
        a = -math.pi / 2 + k * G.TAU / 3
        g = (5.0 * math.cos(a), 5.0 * math.sin(a) * 1.1, 0.75)
        ge = (3.5 * math.cos(a), 3.5 * math.sin(a), 8.6)
        h = (1.6 * math.cos(a), 1.6 * math.sin(a), C[2] - 4.2)
        lot.put(M["cera"], G.tube([g, ge], 0.46, 10, rfun=lambda s_, i: 0.5 - 0.016 * s_))
        lot.put(M["acier"], G.tube([ge, h], 0.28, 8))
        lot.put(M["cuivre"], G.sphere(ge, 0.55, 12, 6))
        lot.put(M["acier"], G.tube([G.add(g, (0, 0, 2.0)), G.lerp(ge, h, 0.55)], 0.08, 6))
        lot.put(M["brule"], G.prisme(R.octo((g[0], g[1]), 2.1, 8), 0.0, 0.55, top_scale=0.82))
        lot.put(M["cera2"], G.prisme(R.octo((g[0], g[1]), 1.55, 8), 0.55, 0.85, top_scale=0.8))
        lot.put(M["cuivre"], G.prisme(R.octo((g[0], g[1]), 1.1, 6), 0.7, 1.1, top_scale=0.7))
    # sphère : soleil captif, cage en quart d'orange qui laisse passer la lumière
    for (rr, m) in ((3.75, M["soleil"][0]), (3.5, M["soleil"][1])):
        lot.put(m, G.sphere(C, rr, 28, 14))
    for j in range(5):
        la0 = -math.pi / 2 + 0.2 + j * (math.pi - 0.4) / 5
        la1 = la0 + (math.pi - 0.4) / 5 - 0.06
        n = 12
        for i in range(n):
            lo0 = G.TAU * i / n + 0.2 * j
            lo1 = lo0 + G.TAU / n * (0.5 if j == 2 else 0.68)
            rings = []
            for t in range(5):
                la = la0 + (la1 - la0) * t / 4.0
                ring = []
                for q in range(5):
                    lo = lo0 + (lo1 - lo0) * q / 4.0
                    ring.append(G.add(C, (4.4 * math.cos(la) * math.cos(lo), 4.4 * math.cos(la) * math.sin(lo), 4.4 * math.sin(la))))
                for q in range(4, -1, -1):
                    lo = lo0 + (lo1 - lo0) * q / 4.0
                    ring.append(G.add(C, (4.0 * math.cos(la) * math.cos(lo), 4.0 * math.cos(la) * math.sin(lo), 4.0 * math.sin(la))))
                rings.append(ring)
            lot.put(M["cera"] if r.f() < 0.7 else M["cera2"], G.loft(rings, True, True))
    # tore de plasma, penché : section à 3 couches, en fentes, sur un anneau de céramique et de cuivre
    def t_xf(v):
        return G.add(G.rot_y(G.rot_x(v, -0.42), 0.34), C)
    lot.xf = t_xf
    Ra = 7.0
    lot.put(M["cera2"], G.tour([(-0.36, Ra - 0.7), (-0.5, Ra), (-0.36, Ra + 0.7), (0.36, Ra + 0.7), (0.5, Ra), (0.36, Ra - 0.7), (-0.36, Ra - 0.7)], 64, "z"))
    for k in range(10):
        a0 = G.TAU * k / 10
        lot.put(M["cuivre"], G.oriente(G.tour([(0.0, 0.58), (0.3, 0.58)], 12, "z", cap0=True, cap1=True), (Ra * math.cos(a0), Ra * math.sin(a0), 0.0), (-math.sin(a0), math.cos(a0), 0.0)))
        a1 = a0 + G.TAU / 10 * 0.64
        for (m, dw, e) in ((M["plasma"][0], 0.48, 0.05), (M["plasma"][1], 0.28, 0.08), (M["plasma"][2], 0.11, 0.11)):
            lot.put(m, G.tour([(0.65 + e, Ra - dw), (0.65 + e, Ra + dw), (0.62, Ra + dw), (0.62, Ra - dw), (0.65 + e, Ra - dw)], 10, "z", a0=a0 + 0.1, a1=a1))
    for k in range(3):
        a = 0.5 + G.TAU * k / 3
        lot.put(M["acier"], G.tube([(4.2 * math.cos(a), 4.2 * math.sin(a), 0.0), ((Ra - 0.7) * math.cos(a), (Ra - 0.7) * math.sin(a), 0.0)], 0.16, 8))
    lot.xf = None
    # 2 canons courts, injecteurs
    for dx in (-0.8, 0.8):
        p = (dx, -3.6, C[2] + 0.2)
        lot.put(M["acier"], G.tube([p, (dx * 1.1, -7.2, C[2] + 1.5)], 0.25, 10))
        lot.put(M["cuivre"], G.oriente(G.tour([(0.0, 0.34), (0.6, 0.34), (0.68, 0.46), (0.9, 0.46)], 12, "z"), (dx * 1.1, -7.0, C[2] + 1.44), (0.0, -0.9, 0.36)))
        lot.put(M["plasma"][1], G.sphere((dx * 1.1, -7.25, C[2] + 1.52), 0.2, 8, 4))
    return {}


BUILD = {"mat_foudre": mat_foudre, "geode": geode, "sarracenie": sarracenie, "demi_vie": demi_vie, "martinet": martinet, "veilleuse": veilleuse}
