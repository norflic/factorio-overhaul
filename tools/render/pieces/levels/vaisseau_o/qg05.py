"""QG ÂGE 5 : VOLCAN (ère II Lourde, série du 31/10). Emprise 10×5. NEZ À DROITE (+X), tuyères à gauche.

Bible (DESIGN_EPOQUES §5, époque 5) : « Citadelle volcanique : pyramide tronquée à gradins en blindage sombre ; contreforts
inclinés aux 4 coins ; porte en ogive rougeoyante ; 2 pointes de basalte » ; tungstène #3E3D42, rouille brûlée #5A3A2A,
fentes de braise #FF4A10, luminance 42 (la plus sombre) ; écailles, troncs de pyramide, rivets lourds.

Lecture : le vaisseau s'est enfoncé dans sa citadelle. Trois gradins d'écailles le prennent jusqu'aux flancs ; le dos,
les côtes, le crâne et les tuyères en sortent ; sous la cage des côtes, le puits de braise (le cœur). Devant, la porte en
ogive et sa coulée ; autour, contreforts, colonnes de basalte, creuset, cendres.
"""
import math

import carcasse as C
import ere2 as E
import geo as G
import mat as MT

PAL = dict(jaunes=[(0.27, 0.15, 0.014), (0.17, 0.095, 0.011), (0.36, 0.22, 0.03), (0.21, 0.09, 0.012)], sec=(0.075, 0.072, 0.082), sec2=(0.05, 0.048, 0.055),
           conduit=(0.1, 0.09, 0.09), rapiece=(0.17, 0.08, 0.04), rapiece2=(0.135, 0.056, 0.03), acier=(0.075, 0.07, 0.072), acier_clair=(0.2, 0.19, 0.185),
           cuivre=(0.2, 0.085, 0.035), bois=(0.08, 0.055, 0.04), poutre=(0.03, 0.026, 0.024), pierre=(0.05, 0.048, 0.05), toit=(0.06, 0.055, 0.06), ond=(0.07, 0.065, 0.07),
           boue=(0.035, 0.032, 0.034), flaque=(0.012, 0.011, 0.012), lum=(1.0, 0.069, 0.006), rouille=(0.2, 0.075, 0.03), nu=(0.6, 0.56, 0.52), veil=(0.08, 0.02, 0.005),
           riv=(0.1, 0.08, 0.07))
PATINE = dict(ta=0.2, ra=0.3, ec=0.85, nu_k=1.6, ec_col=(0.02, 0.012, 0.008))
COQUE = [(0.3, "jaune0"), (0.44, "jaune1"), (0.5, "jaune2"), (0.58, "jaune3"), (0.86, "vdg"), (0.93, "rapiece"), (1.0, "rapiece2")]
LAC = E.POSE["lacet"]
CT = (0.0, 0.55, 0.0)


def matieres(S):
    M = E.matieres(S, "q5", PAL, PATINE)
    sf = MT.surface
    cr = (0.006, 0.0055, 0.005)
    for (k, c, gr) in (("t0", (0.105, 0.1, 0.112), 61), ("t1", (0.078, 0.075, 0.085), 62), ("t2", (0.135, 0.127, 0.13), 63), ("r0", (0.2, 0.085, 0.038), 64), ("r1", (0.3, 0.12, 0.048), 65)):
        M[k] = sf("q5_" + k, c, rough=0.46, met=0.35, coulures=0.7, rouille=(0.24, 0.09, 0.03), usure=0.72, nu=(0.5, 0.45, 0.4), crasse=0.8, crasse_col=cr, grain=0.14, graine=gr)
    for (k, c, gr) in (("pl0", (0.085, 0.08, 0.088), 68), ("pl1", (0.062, 0.058, 0.064), 69), ("pl2", (0.15, 0.068, 0.034), 70)):
        M[k] = sf("q5_" + k, c, rough=0.55, met=0.3, usure=0.22, nu=(0.3, 0.27, 0.25), crasse=0.85, crasse_col=cr, coulures=0.5, rouille=(0.2, 0.08, 0.03), grain=0.16, graine=gr)
    M["basalte"] = sf("q5_basalte", (0.05, 0.05, 0.056), rough=0.7, met=0.0, usure=0.9, nu=(0.32, 0.31, 0.32), crasse=0.8, crasse_col=cr, grain=0.2, graine=66)
    M["cendre"] = sf("q5_cendre", (0.075, 0.07, 0.068), rough=0.95, met=0.0, usure=0.0, crasse=0.5, crasse_col=(0.015, 0.014, 0.013), grain=0.3, graine=67)
    M["lave"] = S.mat_emissive("q5_lave", (1.0, 0.07, 0.004), strength=2.2, base=(0.05, 0.01, 0.002), main_scale=0.3, crust=(8.0, 0.8, 3.0))
    M["fente"] = MT.lumiere(S, "q5_fente", (1.0, 0.06, 0.003), 2.4, main=0.22)
    M["flamme"] = M["fente"]
    return M


def t_mats(M):
    t = (("t0", 0.42), ("t1", 0.7), ("t2", 0.84), ("r0", 0.94), ("r1", 1.0))

    def f(rnd):
        x = rnd.f()
        for (k, s) in t:
            if x < s:
                return M[k]
        return M["t0"]
    return f


def gradin(lot, M, mf, r, U0, U1, V0, V1, z0, z1, ins, rangs, larg=(0.3, 0.5), ouest=True):
    """Tronc de pyramide en écailles : noyau, 4 faces de rangs d'écailles, chaperon d'acier au sommet. Repère courant (u, v, z)."""
    b = [(U0, V0, z0), (U1, V0, z0), (U1, V1, z0), (U0, V1, z0)]
    t = [(U0 + ins, V0 + ins, z1), (U1 - ins, V0 + ins, z1), (U1 - ins, V1 - ins, z1), (U0 + ins, V1 - ins, z1)]
    lot.put(M["noyau"], G.loft([b, t]))
    lot.put(M["t1"], G.boite(((t[0][0] + t[2][0]) / 2, (t[0][1] + t[2][1]) / 2, z1 - 0.008), (t[2][0] - t[0][0], t[2][1] - t[0][1], 0.016)))
    for i in range(4):
        j = (i + 1) % 4
        E.ecailles(lot, mf, b[i], b[j], t[j], t[i], r, rangs, larg, saut=0.015, rivet=M["riv"])
    pts = t + [t[0]]
    lot.put(M["t2"], G.tube([G.add(p, (0, 0, 0.012)) for p in pts], 0.035, 5))
    return t


def plaques_plat(lot, M, r, u0, u1, v0, v1, z, trou=None):
    """Plancher de gradin : tôles lourdes de tailles tirées, joints noirs, quelques rivets."""
    lot.put(M["noyau"], G.boite(((u0 + u1) / 2, (v0 + v1) / 2, z - 0.015), (u1 - u0, v1 - v0, 0.03)))
    u = u0
    while u < u1 - 0.02:
        w = min(r.f(0.16, 0.5), u1 - u)
        v = v0
        while v < v1 - 0.02:
            h = min(r.f(0.14, 0.42), v1 - v)
            if not (trou and trou(u + w / 2, v + h / 2)):
                k = ("pl0", "pl1", "pl1", "pl2", "pl1", "pl0", "pl1")[r.i(0, 6)]
                lot.put(M[k], G.boite((u + w / 2, v + h / 2, z + 0.012 + r.f(0, 0.012)), (w - 0.022, h - 0.022, 0.03), r.f(-0.03, 0.03), r.f(-0.015, 0.015), r.f(-0.015, 0.015)))
            v += h
        u += w


def merlon(lot, M, x, y, z, s, h, rz=0.0):
    poly = [(-s, -s * 0.7), (s, -s * 0.7), (s, s * 0.7), (-s, s * 0.7)]
    with E.dans(lot, (x, y, z), rz):
        lot.put(M["t1"], G.prisme(poly, 0.0, h, top_scale=0.62))
        lot.put(M["t2"], G.prisme([(p[0] * 0.66, p[1] * 0.66) for p in poly], h, h + 0.03, top_scale=0.86))


def contrefort(lot, M, mf, r, c, rz, L, H, w):
    """Contrefort incliné : coin plein, pied dehors (s = 0), tête contre le gradin (s = L) ; pente en écailles, joues rivetées."""
    with E.dans(lot, c, rz):
        lot.put(M["t1"], C.prisme_plan([(0.0, 0.0), (L, 0.0), (L, H)], w))
        A, B, Cc, D = (0.0, w / 2, 0.0), (0.0, -w / 2, 0.0), (L, -w / 2, H), (L, w / 2, H)
        E.ecailles(lot, mf, A, B, Cc, D, r, max(4, int(math.hypot(L, H) / 0.26)), (0.26, 0.4), rivet=M["riv"])
        for s in (-1, 1):
            y = s * (w / 2 + 0.008)
            lot.put(M["riv"], G.rivets_le_long([((L * t, y, H * t * 0.45 + 0.08), (0, s, 0)) for t in (0.3, 0.45, 0.6, 0.75, 0.9)], 0.04, 0.026))
            lot.put(M["r0"], C.prisme_plan([(L * 0.52, 0.0), (L, 0.0), (L, H * 0.5)], 0.03, y0=s * (w / 2 + 0.002)))
        lot.put(M["pierre"], G.boite((L * 0.1, 0.0, 0.06), (L * 0.42, w + 0.18, 0.12)))


def basalte(lot, M, r, cx, cy, h, n=7, R=0.3):
    """Colonnes de basalte : prismes à 5 ou 6 pans, têtes en biais, la plus haute en pointe."""
    for k in range(n):
        a = r.f(0, G.TAU)
        d = 0.0 if k == 0 else R * r.f(0.8, 1.5)
        x, y = cx + d * math.cos(a), cy + d * math.sin(a)
        hh = h if k == 0 else h * r.f(0.2, 0.58)
        rb = (R if k == 0 else R * r.f(0.45, 0.7))
        ns = r.i(5, 6)
        ph = r.f(0, 3.0)
        poly = [(x + rb * math.cos(G.TAU * j / ns + ph), y + rb * math.sin(G.TAU * j / ns + ph)) for j in range(ns)]
        lot.put(M["basalte"], G.prisme(poly, 0.0, hh, top_scale=0.18 if k == 0 else r.f(0.55, 0.8), top_shift=(r.f(-0.05, 0.05), r.f(-0.05, 0.05))))


def fente(lot, M, c, w, h, rz=0.0, rx=-0.47):
    """Fente de braise : cadre d'acier, lueur, barreau ; penchée comme la pente (rx)."""
    lot.put(M["t2"], G.boite(c, (w + 0.11, 0.05, h + 0.09), rz, rx))
    q = G.add(c, G.rot_z(G.rot_x((0.0, -0.022, 0.0), rx), rz))
    lot.put(M["fente"], G.boite(q, (w, 0.03, h), rz, rx))


def ogive(w, h, n=8):
    """Contour d'une ogive (x, z) de bas gauche à bas droit, pointe en haut."""
    d = []
    for i in range(n + 1):
        t = i / float(n)
        d.append((-w + w * (1.0 - math.cos(t * math.pi / 2)) * 0.98, h * (0.45 + 0.55 * math.sin(t * math.pi / 2))))
    g = [(-w, 0.0)] + d + [(0.0, h)]
    return g + [(-p[0], p[1]) for p in reversed(g[:-1])]


def porte(lot, M, r, u, v, z):
    """Porte en ogive rougeoyante : avant-corps en coin, voussures, herse, marches d'où part la coulée."""
    w, hh = 0.5, 1.26
    with E.dans(lot, (u, v, z)):
        lot.put(M["t1"], G.prisme([(-0.95, -0.28), (0.95, -0.28), (1.02, 1.0), (-1.02, 1.0)], 0.0, 1.55, top_scale=0.74, top_shift=(0.0, 0.26)))
        E.ecailles(lot, t_mats(M), (-0.95, -0.28, 0.0), (-0.46, -0.28, 0.0), (-0.44, -0.0, 1.55), (-0.72, -0.0, 1.55), r, 6, (0.16, 0.26), rivet=M["riv"])
        E.ecailles(lot, t_mats(M), (0.46, -0.28, 0.0), (0.95, -0.28, 0.0), (0.72, -0.0, 1.55), (0.44, -0.0, 1.55), r, 6, (0.16, 0.26), rivet=M["riv"])
        C_ = ogive(w, hh)
        # intérieur : lueur + fond sombre
        fan = [(p[0], -0.3, p[1]) for p in C_]
        lot.put(M["fente"], E.dalle(fan, (0, -1, 0), 0.0, 0.01))
        for (k, ep) in ((1.0, 0.06), (1.22, 0.05)):
            pts = [(p[0] * k, -0.33 + (k - 1.0) * 0.1, p[1] * (1.0 + (k - 1.0) * 0.55)) for p in C_]
            lot.put(M["t2"] if k == 1.0 else M["r1"], G.tube(pts, ep, 6))
        for x in (-0.3, -0.1, 0.1, 0.3):                                 # herse
            zt = hh * (1.0 - (abs(x) / w) ** 1.6)
            lot.put(M["noir"], G.boite((x, -0.34, zt / 2 + 0.25), (0.038, 0.03, zt - 0.5)))
        for z_ in (0.28, 0.62):
            lot.put(M["noir"], G.boite((0.0, -0.345, z_), (0.82, 0.03, 0.035)))
        lot.put(M["riv"], G.rivets_le_long([((x, -0.37, 0.28), (0, -1, 0)) for x in (-0.3, -0.1, 0.1, 0.3)], 0.034, 0.022))
        # clé d'arc, lames de fronton
        lot.put(M["t2"], G.prisme([(-0.09, -0.42), (0.09, -0.42), (0.14, -0.28), (-0.14, -0.28)], hh * 1.05, hh * 1.42, top_scale=0.5))
        for k in range(4):                                                # marches, de biais
            lot.put(M["t1"] if k % 2 else M["t0"], G.boite((0.0, -0.45 - 0.18 * k, -z + 0.11 + (3 - k) * 0.06 + z * 0.0), (1.3 + 0.2 * k, 0.2, 0.22 + (3 - k) * 0.12)))


def creuset(lot, M, x, y, rz=-0.35):
    """Creuset basculant sur tourillons et portique à palan : braise dans le bec."""
    with E.dans(lot, (x, y, 0.0), rz):
        lot.put(M["t1"], G.boite((0.0, 0.0, 0.09), (1.5, 1.0, 0.18)))
        for s in (-1, 1):
            lot.put(M["t2"], G.prisme([(-0.14, s * 0.46 - 0.05), (0.14, s * 0.46 - 0.05), (0.14, s * 0.46 + 0.05), (-0.14, s * 0.46 + 0.05)], 0.18, 0.86, top_scale=0.6))
        lot.put(M["acier"], G.tour([(-0.52, 0.045), (0.52, 0.045)], 10, "y", (0.0, 0.0, 0.82)))
        v, f, u = G.tour([(0.0, 0.2), (0.12, 0.3), (0.42, 0.38), (0.46, 0.4), (0.46, 0.33), (0.2, 0.2), (0.21, 0.0)], 22, "z")
        v = [G.add(G.rot_y((p[0], p[1], p[2] - 0.22), 0.34), (0.0, 0.0, 0.8)) for p in v]
        lot.put(M["t0"], (v, f, u))
        for z in (0.16, 0.34):
            v, f, u = G.tour([(z - 0.02, 0.28 + z * 0.3), (z + 0.02, 0.28 + z * 0.3)], 22, "z")
            v = [G.add(G.rot_y((p[0], p[1], p[2] - 0.22), 0.34), (0.0, 0.0, 0.8)) for p in v]
            lot.put(M["r1"], (v, f, u))
        v, f, u = G.tour([(0.2, 0.32), (0.21, 0.0)], 18, "z")
        v = [G.add(G.rot_y((p[0], p[1], p[2] - 0.22), 0.34), (0.0, 0.0, 0.8)) for p in v]
        lot.put(M["lave"], (v, f, u))
        # portique en A et palan
        for s in (-1, 1):
            lot.put(M["acier"], G.tube([(-0.72, s * 0.5, 0.18), (-0.05, s * 0.15, 1.75)], 0.03, 5))
            lot.put(M["acier"], G.tube([(0.72, s * 0.5, 0.18), (0.05, s * 0.15, 1.75)], 0.03, 5))
        lot.put(M["t2"], G.boite((0.0, 0.0, 1.76), (0.26, 0.42, 0.07)))
        lot.put(M["noir"], G.tube([(0.0, 0.0, 1.74), (0.0, 0.0, 1.22)], 0.008, 3))
        lot.put(M["acier"], G.boite((0.0, 0.0, 1.2), (0.09, 0.09, 0.1)))


def wagonnet(lot, M, r, x0, y0, rz):
    """Rails sur traverses et wagonnet de minerai (tungstène brut, basalte en vrac)."""
    with E.dans(lot, (x0, y0, 0.0), rz):
        for k in range(10):
            lot.put(M["poutre"], G.boite((-1.2 + 0.26 * k, 0.0, 0.025), (0.09, 0.52, 0.05)))
        for s in (-1, 1):
            lot.put(M["acier_clair"], G.boite((0.0, s * 0.17, 0.065), (2.5, 0.03, 0.04)))
        lot.put(M["t1"], G.prisme([(-0.36, -0.22), (0.36, -0.22), (0.36, 0.22), (-0.36, 0.22)], 0.12, 0.42, top_scale=1.22))
        lot.put(M["r0"], G.boite((0.0, -0.245, 0.3), (0.6, 0.02, 0.12)))
        for s in (-1, 1):
            for x_ in (-0.2, 0.2):
                lot.put(M["acier"], G.tour([(-0.02, 0.09), (0.02, 0.09)], 10, "y", (x_, s * 0.2, 0.09), cap0=True, cap1=True))
        for k in range(8):
            lot.put(M["basalte"], G.boite((r.f(-0.3, 0.3), r.f(-0.18, 0.18), 0.45 + r.f(0, 0.06)), (r.f(0.08, 0.15), r.f(0.08, 0.13), r.f(0.07, 0.13)), r.f(0, 3), r.f(-0.4, 0.4)))


def build(S, lot0):
    M = matieres(S)
    lot = E.LotK(lot0)
    P = C.Pose(**E.POSE)
    r = G.Rnd(5055)
    mc = E.coque(M, COQUE)
    mf = t_mats(M)

    # ======================================================================== sol : cendres sous la citadelle (dessous de tout)
    for (cx, cy, a_, b_) in ((-4.05, -3.05, 0.7, 0.42), (4.0, -2.95, 0.85, 0.5), (4.3, 2.0, 0.5, 0.36)):
        lot.put(M["cendre"], G.butte_polaire((cx, cy, 0.0), a_, b_, 0.03, r, 4, 40, 0.15, 0.22))
    # ======================================================================== carcasse, sortie des gradins
    E.carcasse(lot, M, P, r, mc)
    E.menus_coque(lot, M, P, G.Rnd(5089))
    E.grille_coque(lot, M, P, ((3.0, math.pi / 2 - 0.7, 0.32, 0.4), (3.9, math.pi / 2 + 0.95, 0.26, 0.36), (-2.9, math.pi / 2 + 0.2, 0.3, 0.5)))
    E.mat_nez(lot, M, P)

    # ======================================================================== la pyramide à gradins (repère u, v de la coque, de niveau)
    rg = G.Rnd(5100)
    with E.dans(lot, CT, LAC):
        T0 = (-3.3, 2.95, -4.1, 1.95)
        T1 = (-2.65, 2.35, -3.42, 1.42)
        T2 = (-2.0, 1.72, -2.68, 1.06)
        gradin(lot, M, mf, rg, T0[0], T0[1], T0[2], T0[3], 0.0, 0.82, 0.42, 3, (0.34, 0.56))
        plaques_plat(lot, M, rg, T0[0] + 0.42, T0[1] - 0.42, T0[2] + 0.42, T1[2], 0.83)
        gradin(lot, M, mf, rg, T1[0], T1[1], T1[2], T1[3], 0.82, 1.58, 0.38, 3, (0.3, 0.5))
        plaques_plat(lot, M, rg, T1[0] + 0.38, T1[1] - 0.38, T1[2] + 0.38, T2[2], 1.59)
        gradin(lot, M, mf, rg, T2[0], T2[1], T2[2], T2[3], 1.58, 2.16, 0.26, 3, (0.26, 0.42))
        # toit de T2, sous la cage : le PUITS DE BRAISE (LE CŒUR)
        pu, pv, pa, pb = -0.05, -0.42, 1.0, 0.66
        plaques_plat(lot, M, rg, T2[0] + 0.26, T2[1] - 0.26, T2[2] + 0.26, T2[3] - 0.26, 2.17,
                     trou=lambda a, b: ((a - pu) / (pa + 0.1)) ** 2 + ((b - pv) / (pb + 0.1)) ** 2 < 1.0)
        def ell(k, z, n=40):
            return [(pu + pa * k * math.cos(G.TAU * j / n), pv + pb * k * math.sin(G.TAU * j / n), z) for j in range(n)]
        lot.put(M["lave"], G.loft([ell(0.0, 2.19), ell(1.0, 2.19)]))
        lot.put(M["noir"], G.loft([ell(1.0, 2.185), ell(1.04, 2.22)]))
        lot.put(M["t2"], G.loft([ell(1.03, 2.22), ell(1.12, 2.27), ell(1.2, 2.2)]))
        for j in range(16):                                             # dents de la margelle (irrégulières)
            a = G.TAU * j / 16 + rg.f(-0.08, 0.08)
            merlon(lot, M, pu + pa * 1.12 * math.cos(a), pv + pb * 1.12 * math.sin(a), 2.25, rg.f(0.05, 0.09), rg.f(0.06, 0.16), a)
        lot.put(M["acier"], G.tube([(pu - pa * 1.2, pv + 0.1, 2.3), (pu + pa * 1.2, pv - 0.12, 2.3)], 0.04, 5))
        lot.put(M["acier"], G.tube([(pu + 0.35, pv - pb * 1.2, 2.3), (pu + 0.3, pv + pb * 1.2, 2.3)], 0.04, 5))
        # merlons du bord sud de T1 et de T0, pas tirés
        u = T1[0] + 0.5
        while u < T1[1] - 0.45:
            if abs(u + 0.3) > 0.72:
                merlon(lot, M, u, T1[2] + 0.42, 1.585, rg.f(0.08, 0.13), rg.f(0.14, 0.26))
            u += rg.f(0.34, 0.72)
        u = T0[0] + 0.55
        while u < T0[1] - 0.5:
            if abs(u + 0.3) > 1.18:
                merlon(lot, M, u, T0[2] + 0.45, 0.83, rg.f(0.09, 0.14), rg.f(0.12, 0.22))
            u += rg.f(0.45, 0.95)
        # porte
        porte(lot, M, rg, -0.3, T0[2] + 0.16, 0.0)
        # rampe centrale de T0 à T2, tôle de rouille, rails de chenilles
        lot.put(M["r0"], G.loft([[(-0.72, T1[2] - 0.02, 1.0), (0.12, T1[2] - 0.02, 1.0)], [(-0.68, T2[2] + 0.05, 2.17), (0.08, T2[2] + 0.05, 2.17)]], closed=False))
        for u in (-0.6, -0.04):
            lot.put(M["acier"], G.tube([(u, T1[2] - 0.02, 1.03), (u, T2[2] + 0.05, 2.2)], 0.03, 5))
        # fentes de braise : peu nombreuses, inégales, pas alignées
        for (u, v, z, w, h, rz) in ((-2.25, T0[2] + 0.2, 0.42, 0.42, 0.05, 0.0), (1.45, T0[2] + 0.17, 0.35, 0.3, 0.05, 0.0),
                                    (1.05, T1[2] + 0.2, 1.25, 0.46, 0.05, 0.0), (-1.1, T2[2] + 0.12, 1.84, 0.22, 0.035, 0.0)):
            fente(lot, M, (u, v - 0.05, z + 0.03), w, h, rz, -0.47)
        # casemates en coin (troncs de pyramide rapportés, de biais), hublots en meurtrière
        for (u, v, z, s, h, rz) in ((1.25, T1[2] + 0.56, 1.59, 0.42, 0.42, 0.38), (-1.7, T1[2] + 0.62, 1.59, 0.34, 0.36, -0.42)):
            with E.dans(lot, (u, v, z), rz):
                lot.put(M["t1"], G.prisme([(-s, -s * 0.75), (s, -s * 0.75), (s, s * 0.75), (-s, s * 0.75)], 0.0, h, top_scale=0.68))
                E.ecailles(lot, mf, (-s, -s * 0.75, 0.0), (s, -s * 0.75, 0.0), (s * 0.68, -s * 0.51, h), (-s * 0.68, -s * 0.51, h), rg, 3, (0.14, 0.2), rivet=M["riv"])
                lot.put(M["t2"], G.boite((0.0, 0.0, h + 0.015), (s * 1.34, s, 0.03)))
                C.evente(lot, M["acier"], M["noir"], (0.0, 0.03, h + 0.03), 0.16, 0.26, 3, 0.0, 0.08)
        # tuyauterie lourde sur les terrasses (brides épaisses)
        C.tuyau(lot, M["conduit"], M["r1"], [(-2.25, T1[2] + 0.2, 1.72), (-2.25, -0.95, 1.72), (-2.4, -0.95, 1.2)], 0.09, rb=0.18, pas_bride=0.42)
        C.tuyau(lot, M["conduit"], M["r1"], [(1.75, T1[2] + 0.46, 1.68), (1.75, -1.15, 1.68), (1.3, -1.15, 2.3)], 0.075, rb=0.16, pas_bride=0.42)
        C.tuyau(lot, M["acier"], M["r1"], [(-2.92, -1.9, 0.9), (-2.92, -3.3, 0.9), (-1.35, -3.5, 0.9)], 0.05, rb=0.14, pas_bride=0.5)
        C.tuyau(lot, M["cuivre"], M["t2"], [(0.5, T0[2] + 0.45, 0.88), (2.3, T0[2] + 0.45, 0.88), (2.5, -2.55, 0.88), (2.5, -1.8, 0.88)], 0.045, rb=0.12, pas_bride=0.5)
        # 3 chemins de marches étroites sur les pentes ouest et est
        E.escalier(lot, M, (2.92, -2.7, 0.06), (2.5, -1.2, 0.84), 0.26)
        E.escalier(lot, M, (-3.28, -3.2, 0.06), (-2.88, -1.75, 0.84), 0.26)
        # 2 évents sur T1
        C.evente(lot, M["acier"], M["noir"], (-0.95, T1[2] + 0.7, 1.6), 0.24, 0.42, 4, 0.0, 0.12)
        C.evente(lot, M["t2"], M["noir"], (0.5, T1[2] + 0.66, 1.6), 0.22, 0.3, 3, 0.0, 0.12)
        # CONTREFORTS aux 4 coins : pied dehors, tête contre T1
        for (c, rz, L, H, w) in (((3.5, -4.4, 0.0), math.radians(135), 1.45, 1.42, 0.88), ((-3.8, -4.38, 0.0), math.radians(45), 1.4, 1.36, 0.82),
                                 ((3.45, 2.5, 0.0), math.radians(225), 1.35, 1.4, 0.8), ((-3.75, 2.4, 0.0), math.radians(-45), 1.25, 1.3, 0.76)):
            contrefort(lot, M, mf, rg, c, rz, L, H, w)
        # cheminée de forge au nord (tronc de pyramide haut), bouche rougeoyante
        ch = (0.72, 1.62)
        lot.put(M["t1"], G.prisme([(ch[0] - 0.46, ch[1] - 0.42), (ch[0] + 0.46, ch[1] - 0.42), (ch[0] + 0.46, ch[1] + 0.42), (ch[0] - 0.46, ch[1] + 0.42)], 0.8, 3.62, top_scale=0.42))
        z_ = 3.62
        E.ecailles(lot, mf, (ch[0] - 0.46, ch[1] - 0.42, 0.8), (ch[0] + 0.46, ch[1] - 0.42, 0.8), (ch[0] + 0.19, ch[1] - 0.18, z_), (ch[0] - 0.19, ch[1] - 0.18, z_), rg, 10, (0.17, 0.26), rivet=M["riv"])
        E.ecailles(lot, mf, (ch[0] + 0.46, ch[1] - 0.42, 0.8), (ch[0] + 0.46, ch[1] + 0.42, 0.8), (ch[0] + 0.19, ch[1] + 0.18, z_), (ch[0] + 0.19, ch[1] - 0.18, z_), rg, 10, (0.17, 0.26))
        E.ecailles(lot, mf, (ch[0] - 0.46, ch[1] + 0.42, 0.8), (ch[0] - 0.46, ch[1] - 0.42, 0.8), (ch[0] - 0.19, ch[1] - 0.18, z_), (ch[0] - 0.19, ch[1] + 0.18, z_), rg, 10, (0.17, 0.26))
        lot.put(M["t2"], G.prisme([(ch[0] - 0.24, ch[1] - 0.22), (ch[0] + 0.24, ch[1] - 0.22), (ch[0] + 0.24, ch[1] + 0.22), (ch[0] - 0.24, ch[1] + 0.22)], z_, z_ + 0.14))
        lot.put(M["noir"], G.boite((ch[0], ch[1], z_ + 0.145), (0.34, 0.3, 0.012)))
        lot.put(M["fente"], G.boite((ch[0], ch[1], z_ + 0.15), (0.12, 0.1, 0.008)))
        for k in range(3):
            lot.put(M["acier"], G.boite((ch[0] - 0.09 + 0.09 * k, ch[1], z_ + 0.165), (0.025, 0.3, 0.025)))

    # ======================================================================== basalte, creuset, wagonnet, coulée
    rb = G.Rnd(5500)
    basalte(lot, M, rb, -4.0, -3.0, 3.15, 8, 0.3)
    basalte(lot, M, rb, 4.15, 2.15, 3.6, 8, 0.34)
    basalte(lot, M, rb, 5.15, -2.75, 0.8, 5, 0.17)
    for (x, y, h, n, R) in ((-2.75, -4.05, 0.85, 4, 0.13), (1.9, -4.15, 1.1, 5, 0.15), (3.0, -3.9, 0.7, 4, 0.12), (-5.5, -2.9, 0.95, 4, 0.14), (-0.9, 3.0, 1.2, 4, 0.16), (5.7, -0.6, 0.75, 4, 0.12)):
        basalte(lot, M, rb, x, y, h, n, R)
    creuset(lot, M, 4.0, -2.55)
    wagonnet(lot, M, rb, -4.85, -2.15, 1.25)
    # coulée : ruban qui part des marches de la porte vers le creuset, bords de scorie, s'élargit en flaque
    pts_c = [(-0.2, -3.92), (0.15, -4.02), (0.95, -3.98), (1.8, -3.72), (2.45, -3.5), (2.85, -3.25)]
    pts_c = G.catmull([(x, y, 0.0) for (x, y) in pts_c], 6)
    bords, bordn = [], []
    for i, p in enumerate(pts_c):
        d = G.norm(G.sub(pts_c[min(i + 1, len(pts_c) - 1)], pts_c[max(0, i - 1)]))
        n = (-d[1], d[0], 0.0)
        w = 0.05 + 0.03 * math.sin(i * 1.7) + 0.05 * i / len(pts_c)
        bords.append(G.add(p, G.add(G.mul(n, w), (0, 0, 0.012))))
        bordn.append(G.add(p, G.add(G.mul(n, -w), (0, 0, 0.012))))
    lot.put(M["lave"], G.loft([bords, bordn], closed=False))
    lot.put(M["basalte"], G.tube([G.add(q, (0, 0, -0.005)) for q in bords], 0.024, 4))
    lot.put(M["basalte"], G.tube([G.add(q, (0, 0, -0.005)) for q in bordn], 0.024, 4))
    # blocs de scories, câbles, flexibles
    for k in range(34):
        x, y = rb.f(-5.8, 5.8), rb.f(-4.55, 3.7)
        if -3.8 < x < 3.5 and -4.3 < y < 2.2:
            continue
        s = rb.f(0.06, 0.22)
        lot.put(M["basalte"] if k % 3 else M["r0"], G.boite((x, y, s * 0.4), (s, s * rb.f(0.7, 1.1), s * 0.8), rb.f(0, 3), rb.f(-0.5, 0.5), rb.f(-0.5, 0.5)))
    for (a_, b_, c_) in (((-4.55, -1.4, 1.15), (-4.85, -1.2, 0.3), (-4.6, -0.9, 0.2)), ((-3.8, -1.25, 1.2), (-3.75, -1.55, 0.7), (-3.2, -1.9, 0.6)),
                         ((3.0, -0.4, 1.15), (3.35, -1.1, 0.55), (3.9, -2.05, 0.5)), ((1.6, 2.2, 0.5), (2.05, 2.5, 0.2), (2.65, 2.2, 0.6)), ((-3.2, 2.25, 0.5), (-3.65, 2.05, 0.2), (-4.1, 2.15, 0.7)),
                         ((3.3, -3.0, 0.3), (3.45, -3.3, 0.05), (3.7, -3.1, 0.25))):
        C.flexible(lot, M["caoutchouc"], [a_, b_, c_], 0.05)
    ra = G.Rnd(5305)
    for (a_, b_, fl) in ((P.xf((2.4, -0.9, 0.5)), P.xf((3.8, -0.75, 0.35)), 0.18), (P.xf((-3.3, -0.9, 0.3)), P.xf((-2.3, -1.05, 0.1)), 0.2),
                         (P.xf((-1.0, 0.25, C.z_dessus(-1.0) + 0.4)), P.xf((1.1, 0.25, C.z_dessus(1.1) + 0.4)), 0.42), (P.xf((-3.4, 0.0, C.z_dessus(-3.4) + 0.3)), P.xf((-1.4, 0.3, C.z_dessus(-1.4) + 0.3)), 0.3),
                         (P.xf((3.3, 0.5, C.z_dessus(3.3) + 0.05)), (4.0, 2.05, 2.1), 0.25), (P.xf((1.9, -0.2, 0.8)), (0.9, -1.0, 2.2), 0.2)):
        C.faisceau(lot, M["rouge"], M["noir"], a_, b_, fl, 3, 0.011, 0.028, ra)
    for x in (-1.3, 1.1):
        p = P.xf((x, 0.0, C.z_dessus(x) + 0.25))
        lot.put(M["acier"], G.tube([p, G.add(p, (0.0, 0.0, 0.9))], 0.012, 4))
    nez = P.xf((5.0, 0.0, -0.3))
    lot.put(M["basalte"], G.butte_polaire((nez[0] + 0.15, nez[1] - 0.1, 0.0), 1.05, 1.45, 0.6, r, 12, 48, 0.32, 0.16))
    E.debris(lot, M, [("plaque", -5.75, -1.6, 0.55, 0.38, 0.4), ("plaque", 5.45, -1.75, 0.5, 0.32, -0.7), ("plaque", -5.5, 2.3, 0.6, 0.42, 0.9),
                      ("fut", -5.55, -3.4, 0.3), ("fut", 5.45, 1.55, 0.0), ("caisse", 5.2, -3.7, 0.3, 0.26, 0.5), ("tuyau", 4.6, -3.9, 0.9, 0.05, 0.25), ("pneu", -5.1, -3.75, 0.17)])
    E.ferraille(lot, M, G.Rnd(5306), 24, (-5.9, 5.9, -4.5, 3.8), 3.9, 3.8)
    return {"pose": E.POSE}
