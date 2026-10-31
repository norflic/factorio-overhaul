"""ÈRE I DU QG (âges 1 à 3, série du 31/10) : ce qui est commun à l'épave réparée, au bastion et à l'hôtel de la vapeur.
Emprise 8×4. NEZ À DROITE (+X). Les deux tronçons de l'épave (qg00 : mêmes stations de coque, mêmes tôles, mêmes matières
de carcasse) sont ici redressés et rapprochés d'âge en âge : la carcasse reste celle de l'âge 0 ; ses poses vont vers celle
de l'âge 8 (dos montré, roulis 0,17). Seules les pièces ajoutées changent : voir qg01, qg02, qg03.
"""
import math

import forme as F
import geo as G
import qg00 as Q

TAU = G.TAU


# ------------------------------------------------------------------------------------------------ repères et petites pièces
def repere(cx, cy, rz=0.0):
    """Bâtiment de niveau tourné de rz (rz < 0 : la face est se montre à la caméra) et posé en (cx, cy)."""
    def f(p):
        q = G.rot_z(p, rz)
        return (q[0] + cx, q[1] + cy, p[2])
    return f


def rondin(lot, M, Mb, a, b, r, seg=9):
    lot.put(M, G.tube([a, b], r, seg, cap0=False, cap1=False))
    d = G.norm(G.sub(b, a))
    for p, n in ((a, G.mul(d, -1.0)), (b, d)):
        lot.put(Mb, G.oriente(G.tour([(0.0, r * 0.99), (0.004, r * 0.6), (0.006, 0.0)], seg, "z", cap0=True), p, n))


def sac(c, L, Wd, H, rz=0.0, ry=0.0, n=10, m=6):
    """Sac de sable : superellipsoïde aplati, ventre affaissé."""
    rings = []
    for i in range(m + 1):
        th = -math.pi / 2 + math.pi * i / m
        ct, st = math.cos(th), math.sin(th)
        ring = []
        for j in range(n):
            ph = TAU * j / n
            cp, sp = math.cos(ph), math.sin(ph)
            x = L / 2 * math.copysign(abs(ct) ** 0.45, ct) * math.copysign(abs(cp) ** 0.3, cp)
            y = Wd / 2 * math.copysign(abs(ct) ** 0.45, ct) * math.copysign(abs(sp) ** 0.4, sp)
            z = H / 2 * math.copysign(abs(st) ** 0.6, st)
            z -= 0.18 * H * max(0.0, st) * (1.0 - abs(cp))
            ring.append(G.add(G.rot_z(G.rot_y((x, y, z), ry), rz), c))
        rings.append(ring)
    return G.loft(rings, closed=True)


def rang_sacs(lot, mats, a, b, z0, rangs, rnd, L=0.3, Wd=0.17, H=0.11):
    """Rempart de sacs entre a et b (x, y) : rangs décalés, sacs inégaux, un peu de travers ; dessus irrégulier."""
    d = (b[0] - a[0], b[1] - a[1])
    Lg = math.hypot(*d)
    rz = math.atan2(d[1], d[0])
    u = (d[0] / Lg, d[1] / Lg)
    for k in range(rangs):
        s = (L * 0.5 if k % 2 else 0.0) + rnd.f(-0.02, 0.02)
        while s < Lg - 0.04:
            ll = L * rnd.f(0.85, 1.12)
            if rnd.f() > 0.08 or k < rangs - 1:
                c = (a[0] + u[0] * (s + ll / 2), a[1] + u[1] * (s + ll / 2), z0 + H * 0.5 + k * H * 0.82 + rnd.f(-0.006, 0.006))
                lot.put(mats[rnd.i(0, len(mats) - 1)], sac(c, ll, Wd * rnd.f(0.9, 1.08), H * rnd.f(0.9, 1.1), rz + rnd.f(-0.12, 0.12), rnd.f(-0.06, 0.06)))
            s += ll * 0.96


def tole_ondulee(o, eu, ev, Lu, Lv, pas=0.09, amp=0.014, k=5):
    n = G.norm(G.cross(eu, ev))
    if n[2] < 0:
        n = G.mul(n, -1.0)
    nu = max(2, int(Lu / pas * k))
    verts, faces, uvs = [], [], []
    for i in range(nu + 1):
        u = Lu * i / nu
        off = amp * math.sin(TAU * u / pas)
        for v in (0.0, Lv):
            verts.append(G.add(G.add(G.add(o, G.mul(eu, u)), G.mul(ev, v)), G.mul(n, off)))
            uvs.append((u, v))
    for i in range(nu):
        a = 2 * i
        faces.append((a, a + 2, a + 3, a + 1))
    return verts, faces, uvs


def tonneau(lot, M, Mc, c, r=0.13, h=0.36, couche=False, rz=0.0):
    prof = [(0.0, r * 0.92), (0.02, r), (h * 0.5, r * 1.06), (h - 0.02, r), (h, r * 0.92)]
    if couche:
        pose = lambda p: G.add(G.rot_z(p, rz), (c[0], c[1], c[2] + r))
        lot.put(M, G.tour(prof, 14, "x", cap0=True, cap1=True), pose)
        for z in (0.06, h - 0.06):
            lot.put(Mc, G.tour([(z - 0.014, r * 1.05), (z + 0.014, r * 1.05)], 14, "x"), pose)
        return
    lot.put(M, G.tour(prof, 14, "z", c, cap0=True, cap1=True))
    for z in (0.06, h * 0.5, h - 0.06):
        rr = r * (1.06 if abs(z - h * 0.5) < 0.01 else 1.0) + 0.006
        lot.put(Mc, G.tour([(z - 0.014, rr), (z + 0.014, rr)], 14, "z", c))


def caisse(lot, M, M2, Mf, c, s, rz=0.0):
    """Caisse de planches cerclée : planches inégales sur la face sud, deux feuillards."""
    x, y, z = c
    lot.put(M, G.boite((x, y, z + s[2] / 2), s, rz))
    nb = 3 + int(s[0] / 0.16)
    for i in range(nb):
        t = (i + 0.5) / nb - 0.5
        q = G.rot_z((t * s[0], -s[1] / 2 - 0.006, 0.0), rz)
        lot.put(M2 if i % 2 else M, G.boite((x + q[0], y + q[1], z + s[2] / 2), (s[0] / nb - 0.012, 0.012, s[2] - 0.02), rz))
    for t in (-0.38, 0.36):
        q = G.rot_z((t * s[0], 0.0, 0.0), rz)
        lot.put(Mf, G.boite((x + q[0], y + q[1], z + s[2] / 2), (0.022, s[1] + 0.018, s[2] + 0.018), rz))
    lot.put(M2, G.boite((x, y, z + s[2] + 0.006), (s[0] - 0.05, s[1] - 0.05, 0.012), rz))


def lanterne(lot, Mfer, Mverre, p):
    x, y, z = p
    lot.put(Mfer, G.tour([(0.0, 0.035), (0.012, 0.04), (0.02, 0.025), (0.09, 0.025), (0.1, 0.04), (0.13, 0.012), (0.16, 0.004)],
                         8, "z", (x, y, z - 0.16), cap0=True))
    lot.put(Mverre, G.tour([(0.02, 0.032), (0.09, 0.032)], 8, "z", (x, y, z - 0.16)))
    lot.put(Mfer, G.tube([(x, y, z), (x, y, z + 0.05)], 0.006, 4))


def echelle(lot, M, a, b, larg=0.26, pas=0.17, r=0.016, rb=0.011):
    """Échelle de a à b (montants écartés en x)."""
    for s in (-1, 1):
        lot.put(M, G.tube([G.add(a, (s * larg / 2, 0, 0)), G.add(b, (s * larg / 2, 0, 0))], r, 5))
    n = max(2, int(G.length(G.sub(b, a)) / pas))
    for k in range(1, n):
        q = G.lerp(a, b, k / float(n))
        lot.put(M, G.tube([G.add(q, (-larg / 2, 0, 0)), G.add(q, (larg / 2, 0, 0))], rb, 4))


def panneau(lot, mats, Mriv, o, eu, ev, ez, Lu, Lv, rnd, lu=(0.3, 0.72), lv=(0.26, 0.55), ep=(0.012, 0.034), riv=0.65, doub=0.2, trou=None):
    """Mur en plaques boulonnées, IRRÉGULIÈRES : rangs de hauteur tirée, coupes décalées, plaques d'épaisseur tirée, un peu
    gauchies, doublures à cheval sur les joints, rivets sur une partie des bords. trou(u, v) -> True : pas de plaque.
    Repère du mur : o coin bas gauche, eu le long du mur, ev vers le haut, ez vers l'extérieur."""
    def plaque(uc, vc, w, h, e, rz=0.0):
        lot.put(mats[rnd.i(0, len(mats) - 1)], F.local(G.boite((uc, vc, e / 2), (w, h, e), rz=rz), o, eu, ev, ez))
    v = 0.0
    while v < Lv - 0.02:
        h = min(rnd.f(*lv), Lv - v)
        if Lv - v - h < lv[0] * 0.6:
            h = Lv - v
        u = -rnd.f(0.0, lu[0] * 0.6)
        while u < Lu - 0.02:
            w = rnd.f(*lu)
            a, b = max(0.0, u), min(Lu, u + w)
            u += w
            if b - a < 0.05:
                continue
            uc, vc = (a + b) / 2, v + h / 2
            if trou and trou(uc, vc):
                continue
            e = rnd.f(*ep)
            plaque(uc, vc, b - a - 0.016, h - 0.016, e, rnd.f(-0.006, 0.006))
            if rnd.f() < riv:
                nr = max(2, int((b - a) / 0.11))
                vr = vc + (h / 2 - 0.035) * (1 if rnd.f() < 0.6 else -1)
                for k in range(nr):
                    p = (a + (b - a) * (k + 0.5) / nr, vr, e + 0.002)
                    lot.put(Mriv, F.local(G.sphere(p, 0.015, 6, 3), o, eu, ev, ez))
            if rnd.f() < doub:
                wd, hd = rnd.f(0.12, 0.3), rnd.f(0.08, 0.2)
                pd = (b + rnd.f(-0.08, 0.02), vc + rnd.f(-h / 3, h / 3))
                if 0.05 < pd[0] < Lu - 0.05 and not (trou and trou(*pd)):
                    plaque(pd[0], pd[1], wd, hd, e + 0.018, rnd.f(-0.02, 0.02))
        v += h


def menus(lot, mats, rnd, n, x0, x1, y0, y1, z):
    """Menus détails au sol ou sur un plancher (3 à 10 px) : cales, boulons, ferraille."""
    for k in range(n):
        lot.put(mats[k % len(mats)], G.boite((rnd.f(x0, x1), rnd.f(y0, y1), z + 0.012), (rnd.f(0.04, 0.13), rnd.f(0.03, 0.1), 0.028), rnd.f(0.0, 3.0)))


def coque_menus(lot, M, C, x0, x1, t0, t1, rnd, n):
    """Regards et équerres posés sur la coque (cassent les aplats des tôles)."""
    for k in range(n):
        o, ex, ey, ez = C.repere(rnd.f(x0, x1), rnd.f(t0, t1), 0.05)
        lot.put([M["acier"], M["noyau"], M["nu"], M["bague"]][k % 4],
                F.local(G.boite((0, 0, 0.02), (rnd.f(0.05, 0.13), rnd.f(0.04, 0.1), 0.05), rz=rnd.f(-0.8, 0.8)), o, ex, ey, ez))


# ------------------------------------------------------------------------------------------------ carcasse commune
ST_AR = [(-3.3, 0.8, 0.7, 0.58, 0.0, 0.0), (-2.9, 0.88, 0.8, 0.64, 0.0, 0.04), (-2.45, 0.95, 0.88, 0.7, 0.0, 0.06),
         (-2.0, 1.0, 0.94, 0.72, 0.0, 0.08), (-1.55, 1.03, 0.95, 0.72, 0.0, 0.08), (-1.1, 1.0, 0.92, 0.72, 0.0, 0.07),
         (-0.65, 0.98, 0.9, 0.72, 0.0, 0.06), (0.0, 0.96, 0.88, 0.72, 0.0, 0.05)]
ST_AV = [(0.0, 0.96, 0.88, 0.72, 0.0, 0.05), (0.5, 1.0, 0.94, 0.72, 0.0, 0.06), (1.0, 0.99, 1.02, 0.7, 0.0, 0.04),
         (1.5, 0.93, 1.06, 0.66, 0.0, 0.02), (2.0, 0.83, 0.98, 0.6, -0.03, 0.03), (2.5, 0.68, 0.8, 0.5, -0.07, 0.04),
         (2.9, 0.52, 0.62, 0.4, -0.12, 0.04), (3.25, 0.34, 0.42, 0.3, -0.16, 0.03), (3.5, 0.19, 0.25, 0.19, -0.2, 0.02),
         (3.68, 0.05, 0.07, 0.06, -0.22, 0.0)]


def carcasse(lot, M, r, ra, E):
    """Les deux tronçons de l'épave, posés selon E (voir chaque âge) ; choix(rr, x, t, patch) donne la matière d'une tôle.
    Rend (pose_ar, pose_av, AR, AV). Le cœur, le sol et le module d'âge sont posés par l'âge."""
    AR = F.Coque(Q._st(ST_AR))
    AV = F.Coque(Q._st(ST_AV))
    choix = E["choix"]
    jaunes = [M["j0"], M["j1"], M["j2"], M["j3"]]

    def lim_ar(t):
        return -1.05 + 0.2 * math.sin(t * 2.7) + 0.1 * math.sin(t * 5.3 + 1.0)

    def ouvert_ar(x, t):
        t %= 12
        return 5.2 < t < 9.8 and x > lim_ar(t)

    def trou_ar(x, t):
        return E.get("trou_dos", True) and -2.15 < x < -1.45 and 2.0 < t < 3.3

    pose_ar = F.pose(roulis=E["roul_ar"], tangage=E["tang_ar"], lacet=E["lacet_ar"], t=E["t_ar"])
    lot.xf = pose_ar
    xs_ar = [-3.3, -2.5, -1.72, -1.08, -0.5, 0.0]
    Q.noyau(lot, M["noyau"], AR, -3.3, 0.0, ouvert_ar)
    lot.put(M["noyau"], G.loft([[AR(-3.3, k * 0.5, -0.012) for k in range(24)]], cap0=True))
    Q.toles(lot, M, AR, xs_ar, r, ouvert_ar, lambda rr, x, t, patch=False: choix(rr, x, t, patch, "ar"), trou_ar)
    Q.bords_dechires(lot, M, AR, xs_ar, ra, ouvert_ar, 1.0)
    Q.epine(lot, M, AR, -3.1, -0.15, r, saut=lambda x: trou_ar(x, 2.6))
    for x, tb in ((-0.9, 10.1), (-0.58, 9.3), (-0.26, 10.1)):
        lot.put(M["acier"], F.cote(AR, x, 4.9, tb, 0.3, r=0.042))
    lot.put(M["bague"], F.cote(AR, -0.03, -2.0, 5.3, 0.12, r=0.05, n=30))
    if E.get("trou_dos", True):
        for x in (-2.0, -1.62):
            lot.put(M["acier"], F.cote(AR, x, 2.0, 3.3, 0.12, r=0.03, g=0.0))
    lot.put(M["acier"], G.boite((-0.55, -0.05, -0.36), (1.1, 1.35, 0.04)))
    Q.caisson(lot, M, (-0.75, -0.35, -0.22), (0.3, 0.26, 0.26), 0.2, r, voyant=True)
    Q.caisson(lot, M, (-0.35, 0.3, -0.2), (0.26, 0.34, 0.3), -0.1, r)
    F.tuyau(lot, M["acier"], M["bague"], [(-1.2, 0.55, 0.35), (-0.6, 0.62, 0.32), (-0.3, 0.55, 0.05), (-0.1, 0.4, -0.25)], 0.05)
    # tuyères : cantées autour de leur avant pour que la cloche reste ouverte vers la caméra quand la coque se redresse
    cant = E.get("cant", 0.0)

    def nac(p):
        q = G.rot_z((p[0] + 1.25, p[1], p[2]), cant)
        return pose_ar((q[0] - 1.25, q[1], q[2]))
    lot.xf = nac
    Q.nacelle(lot, M, r, 1.12, -0.12, 0.62, chev=True)
    Q.nacelle(lot, M, r, -1.12, -0.05, 0.6)
    lot.xf = pose_ar
    F.tuyau(lot, M["acier"], M["bague"], [AR(-3.0, 7.0, 0.02), AR(-2.85, 7.0, 0.12), AR(-1.55, 7.25, 0.12), AR(-1.3, 7.25, 0.03)], 0.034)
    F.tuyau(lot, M[E.get("tuyau_ar", "cuivre")], M["bague"], [AR(-2.75, 7.75, 0.02), AR(-2.62, 7.75, 0.14), AR(-1.25, 7.85, 0.14),
                                                             G.add(AR(-1.0, 7.9, 0.14), (0.05, -0.12, -0.25))], 0.05)
    # bosse dorsale et caisson latéral
    for (x, t, L, W, Hh, m) in ((-1.25, 4.1, 1.55, 0.95, 0.42, E.get("bosse", "j2")), (-2.45, 8.5, 0.8, 0.38, 0.24, "j0")):
        o, ex, ey, ez = AR.repere(x, t, 0.03)
        poly = [(-L / 2, -W / 2), (L / 2, -W / 2), (L / 2, W / 2), (-L / 2, W / 2)]
        lot.put(M["primaire"], F.local(G.prisme(poly, 0.0, Hh * 0.45, top_scale=0.95), o, ex, ey, ez))
        lot.put(M[m], F.local(G.prisme([(p[0] * 0.95, p[1] * 0.95) for p in poly], Hh * 0.42, Hh, top_scale=0.62), o, ex, ey, ez))
        oo = G.add(o, G.mul(ez, Hh + 0.005))
        F.grille(lot, M["acier"], M["noir"], oo, ex, ey, ez, L * 0.45, W * 0.5, 4, 0.04)
        lot.put(M["riv"], G.rivets_le_long([(G.add(oo, G.add(G.mul(ex, L * (0.25 + 0.06 * q)), G.mul(ey, -W * 0.3))), ez) for q in range(4)], 0.026, 0.015))
    for (x, t, L, H, n) in ((-2.45, 6.45, 0.44, 0.28, 6), (-1.75, 8.25, 0.36, 0.22, 5), (-2.75, 2.4, 0.34, 0.26, 5)):
        o, ex, ey, ez = AR.repere(x, t, 0.05)
        F.grille(lot, M["acier"], M["noir"], o, ex, ey, ez, L, H, n)
    Q.hublot(lot, M, AR, -2.0, 6.7, "fente", M[E.get("hublot_ar", "hublot_r")])
    # dérive dressée
    z0 = AR(-2.4, 3.5)[2] - 0.02
    Ad, Bd, B1d, A1d = (-3.2, -0.04, z0), (-1.4, -0.04, z0), (-2.85, -0.04, z0 + 2.45), (-3.75, -0.04, z0 + 2.3)
    Q.aile_panneau(lot, M, r, Ad, Bd, B1d, A1d, ep=0.07, casse=E.get("derive_casse", True))
    lot.put(M["chevron"], G.tube([G.add(Bd, (0, -0.05, 0)), G.add(B1d, (0, -0.05, 0))], 0.06, 6))
    F.membrure(lot, M["nu"], [(-2.9, -0.12, z0 + 0.5), (-2.6, -0.2, z0 + 1.0), (-2.75, -0.3, z0 + 1.5)], 0.016, 0.05)
    lot.put(M["voyant"], G.sphere((-3.1, -0.05, z0 + 2.32), 0.04, 8, 4))
    Q.machinerie(lot, M, G.Rnd(2041), (-1.0, -0.05), (-0.85, 0.55), (-0.62, 0.3), 14)
    # aile nord : pliée à l'âge 0, redressée d'âge en âge (angle du second panneau E["aile_pli"])
    A, B = AR(-2.75, 0.7, 0.0), AR(-0.75, 0.7, 0.0)
    d1 = (0.0, math.cos(0.45), math.sin(0.45))
    A1 = G.add(A, G.add((-0.45, 0, 0), G.mul(d1, 1.15)))
    B1 = G.add(B, G.add((-0.95, 0, 0), G.mul(d1, 1.15)))
    Q.aile_panneau(lot, M, r, A, B, B1, A1)
    pli = E.get("aile_pli", 1.2)
    d2 = (0.0, math.cos(pli), math.sin(pli))
    A2 = G.add(A1, G.add((-0.3, 0, 0), G.mul(d2, 1.1)))
    B2 = G.add(B1, G.add((-0.7, 0, 0), G.mul(d2, 1.1)))
    Q.aile_panneau(lot, M, r, A1, B1, B2, A2, casse=E.get("aile_casse", True))
    lot.put(M["bague"], G.tube([G.lerp(A1, B1, 0.1), G.lerp(A1, B1, 0.9)], 0.05, 8))
    # moignon de l'aile sud
    A, B = AR(-2.25, 6.55, 0.0), AR(-1.35, 6.55, 0.0)
    d = (0.0, -math.cos(0.3), math.sin(0.3))
    A1, B1 = G.add(A, G.mul(d, 0.62)), G.add(B, G.add((-0.25, 0, 0), G.mul(d, 0.78)))
    Q.aile_panneau(lot, M, r, A, B, B1, A1, chev=False, casse=True)
    lot.put(M["acier"], G.tube([G.lerp(A, B, 0.5), G.add(G.lerp(A1, B1, 0.5), G.mul(d, 0.32))], 0.035, 6))
    F.faisceau(lot, [M["rouge"], M["noir"], M["noir"]], G.lerp(A1, B1, 0.3), G.add(G.lerp(A1, B1, 0.3), (0.2, -0.35, -0.7)), 0.15, 0.014, 3, 0.03, r)
    Q.surcouche(lot, M, AR, -3.0, -1.15, r, jaunes)
    Q.antenne(lot, M, AR, -0.85, 2.5, 0.62, 0.18, r, plat=True)
    F.flexible(lot, M["gaine"], [(-1.6, 1.3, 0.1), (-1.35, 1.2, 0.45), (-1.05, 0.95, 0.72)], 0.04)

    # ================================================================ TRONÇON AVANT (crâne)
    def lim_av(t):
        return 0.78 + 0.16 * math.sin(t * 2.9) + 0.08 * math.sin(t * 6.1 + 2.0)

    def ouvert_av(x, t):
        t %= 12
        return (4.6 < t < 9.8 and x < lim_av(t)) or (3.3 < t < 4.6 and x < 0.35)

    def verriere(x, t):
        return 1.0 < x < 2.35 and 1.9 < t < 5.1

    pose_av = F.pose(roulis=E["roul_av"], tangage=E["tang_av"], lacet=E["lacet_av"], t=E["t_av"])
    lot.xf = pose_av
    xs_av = [0.0, 0.62, 1.32, 2.1, 2.72, 3.24, 3.68]
    Q.noyau(lot, M["noyau"], AV, 0.0, 3.68, ouvert_av)
    Q.toles(lot, M, AV, xs_av, r, ouvert_av, lambda rr, x, t, patch=False: choix(rr, x, t, patch, "av"), verriere)
    Q.bords_dechires(lot, M, AV, xs_av, ra, ouvert_av, -1.0)
    Q.epine(lot, M, AV, 0.45, 1.0, r)
    Q.epine(lot, M, AV, 2.35, 3.2, r)
    for x, tb in ((0.3, 9.8), (0.62, 8.9)):
        lot.put(M["acier"], F.cote(AV, x, 4.4, tb, 0.3, r=0.042))
    lot.put(M["bague"], F.cote(AV, 0.03, -2.0, 4.6, 0.12, r=0.05, n=30))
    Q.surcouche(lot, M, AV, 0.9, 3.1, G.Rnd(2052), jaunes)
    # verrière
    rangs = (((2.0, 3.0), (1.12, 1.6, 2.2)), ((3.0, 4.0), (1.05, 1.42, 1.86, 2.3)), ((4.0, 5.0), (1.15, 1.72, 2.22)))
    casse_v = E.get("vitre_cassee", True)
    for (ta, tb), cuts in rangs:
        for i in range(len(cuts) - 1):
            casse = casse_v and (ta, i) == (3.0, 1)
            mesh, P = F.plaque(AV, cuts[i] + 0.02, cuts[i + 1] - 0.02, ta + 0.04, tb - 0.04, 0.0, 0.05, (0.06, -0.04))
            if not casse:
                lot.put(M["verre"], mesh)
            lot.put(M["bague"], G.tube([AV(cuts[i], ta, 0.06), AV(cuts[i] + 0.06, tb, 0.06)], 0.026, 4))
        lot.put(M["bague"], G.tube([AV(cuts[0], ta, 0.065), AV(cuts[-1], ta, 0.065)], 0.03, 4))
    lot.put(M["bague"], G.tube([AV(1.05, 5.0, 0.065), AV(2.25, 5.0, 0.065)], 0.03, 4))
    for k in range(5):
        lot.put(M["riv"], G.sphere(AV(1.2 + 0.22 * k, 1.95, 0.07), 0.02, 6, 3))
    # hublots du crâne (tous différents), canards, antenne
    Q.hublot(lot, M, AV, 1.32, 6.2, "carre", M[E.get("hublot_av", "hublot_a")])
    if E.get("sas"):      # sas ouvert, éclairé de l'intérieur (âge 0) : foyer lisible au zoom 1
        o, ex, ey, ez = AV.repere(0.95, 6.55, 0.06)
        lot.put(M["bague"], F.local(G.boite((0, 0, 0.02), (0.52, 0.36, 0.04)), o, ex, ey, ez))
        lot.put(M["hublot_a"], F.local(G.boite((0, 0, 0.043), (0.44, 0.28, 0.006)), o, ex, ey, ez))
        lot.put(M["acier"], F.local(G.boite((0.04, 0, 0.05), (0.03, 0.24, 0.01)), o, ex, ey, ez))
    Q.hublot(lot, M, AV, 1.85, 6.35, "carre", M["hublot_r"])
    Q.hublot(lot, M, AV, 2.45, 6.1, "rond", M["noir"])
    o, ex, ey, ez = AV.repere(2.05, 7.35, 0.05)
    F.grille(lot, M["acier"], M["noir"], o, ex, ey, ez, 0.36, 0.2, 5)
    for tt, L, cas in ((0.35, 1.35, False), (6.7, 0.75, True)):
        A, B = AV(2.3, tt, 0.0), AV(2.85, tt, 0.0)
        nn = AV.n(2.55, tt)
        dd = G.norm(G.add(nn, (0, 0, -0.3)))
        A1, B1 = G.add(A, G.add((-0.25, 0, 0), G.mul(dd, L))), G.add(B, G.add((-0.38, 0, 0), G.mul(dd, L)))
        Q.aile_panneau(lot, M, r, A, B, B1, A1, ep=0.045, casse=cas)
    Q.antenne(lot, M, AV, 0.62, 2.8, 0.55, 0.3, r)
    lot.put(M["voyant"], G.sphere(AV(2.95, 5.6, 0.06), 0.03, 8, 4))
    lot.put(M["acier"], G.boite((0.4, 0.0, -0.38), (0.8, 1.3, 0.04)))
    Q.machinerie(lot, M, G.Rnd(2042), (0.08, 0.75), (-0.85, 0.5), (-0.62, 0.25), 10)
    Q.caisson(lot, M, (0.42, -0.3, -0.22), (0.34, 0.24, 0.26), 0.15, r, voyant=True)
    F.tuyau(lot, M["acier"], M["bague"], [(0.05, 0.5, 0.4), (0.6, 0.55, 0.45), (0.95, 0.4, 0.2)], 0.034)
    lot.xf = None
    return pose_ar, pose_av, AR, AV


def coeur(lot, M, CO, rayon=0.29, lum=22.0, cage="entiere"):
    """Le cœur-réacteur dans sa cage (mêmes anneaux qu'à l'âge 0), berceau ; les réparations sont posées par l'âge."""
    lot.put(M["coeur"], G.sphere(CO, rayon, 16, 8))
    for (axe, ang, a0, a1, rr) in (("x", 0.0, 3.3, 7.7, 0.4), ("y", 0.4, 2.5, 6.9, 0.43), ("z", 0.0, 0.3, 4.0, 0.39)):
        pts = []
        for k in range(25):
            a = a0 + (a1 - a0) * k / 24.0
            u, v = rr * math.cos(a), rr * math.sin(a)
            p = {"x": (0.0, u, v), "y": (u, 0.0, v), "z": (u, v, 0.0)}[axe]
            pts.append(G.add(CO, G.rot_z(p, ang)))
        lot.put(M["bague"], G.tube(pts, 0.04, 8))
    for k in range(6):
        a = TAU * k / 6.0 + 0.3
        top = G.add(CO, (0.3 * math.cos(a), 0.3 * math.sin(a), 0.32))
        bot = G.add(CO, (0.33 * math.cos(a), 0.33 * math.sin(a), -0.38))
        mid = G.add(G.lerp(top, bot, 0.5), (0.12 * math.cos(a), 0.12 * math.sin(a), 0.0))
        if math.sin(a) < -0.2 and cage != "fermee":
            lot.put(M["acier"], G.tube([bot, G.lerp(bot, mid, 0.5)], 0.025, 5))
            continue
        lot.put(M["acier"], G.tube([bot, mid, top], 0.025, 5))
    for (dx, dy, rz) in ((-0.22, 0.0, 0.2), (0.24, 0.02, -0.1)):
        lot.put(M["acier"], G.boite((CO[0] + dx, CO[1] + dy, CO[2] - 0.46), (0.14, 0.7, 0.24), rz))
    Q.lumiere_coeur(G.add(CO, (0.0, -0.32, 0.18)), lum)


def butte_nez(lot, M, r, k=1.0):
    """Butte de terre où le nez reste planté (elle fond d'âge en âge : k)."""
    lot.xf = F.pose(zmin=0.002)
    for (c, rx, ry, h, m, n) in (((4.0, -0.45, 0.0), 0.72 * k, 1.15 * k, 0.48 * k, "terre", 48), ((3.3, -1.55, 0.0), 0.6 * k, 0.45 * k, 0.2 * k, "terre2", 18),
                                 ((3.55, 0.75, 0.0), 0.55 * k, 0.5 * k, 0.22 * k, "terre2", 18)):
        lot.put(M[m], F.tertre(c, rx, ry, h, r, na=max(28, n), nr=9))
    lot.xf = None


def cailloux(lot, M, r, n, x0, x1, y0, y1, sauf=None):
    for i in range(n):
        x, y = r.f(x0, x1), r.f(y0, y1)
        if sauf and sauf(x, y):
            continue
        rr = r.f(0.04, 0.11)
        lot.put(M["roc"] if i % 3 else M["terre2"], G.sphere((x, y, rr * 0.25), rr, 7, 4))


def toles_sol(lot, M, r, plaques):
    """Tôles arrachées au sol : ((x, y), taille, matière, relevé)."""
    for (x, y), s, m, lev in plaques:
        n = r.i(5, 7)
        poly = [(s * (0.7 + 0.3 * r.f()) * math.cos(TAU * k / n), s * 0.7 * (0.7 + 0.3 * r.f()) * math.sin(TAU * k / n)) for k in range(n)]
        rz, rx = r.f(0, 3.0), lev

        def xf(p, x=x, y=y, rz=rz, rx=rx, s=s):
            q = G.rot_z(G.rot_x(p, rx), rz)
            return (q[0] + x, q[1] + y, max(0.002, q[2] + 0.02 + (s * 0.5 * math.sin(rx) if rx else 0.0)))
        lot.put(M[m], F.poly_dalle(poly, 0.03), xf)
