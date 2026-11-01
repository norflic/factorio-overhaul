"""ÈRE III (âges 7 et 9, série des QG du 31/10) : la carcasse validée de l'âge 8 (qg08.py, GELÉ, non importé), reprise à
l'identique dans la même pose pour que les âges se suivent, et les outils communs des deux âges.

Ce qui change par âge : la part de peau (ouverture du dos, tirage des tôles), les matières (clés de M), le contenu de
la cage et tout ce qui est devant, derrière et au sol. Clés de M attendues : noyau, jaune0..3, patch, rapiece, rapiece2,
chevron, riv, acier, anneau, brule, verre_sombre, hublot, veilleuse, voyant, noir, rouge, caoutchouc.
"""
import math

import carcasse as C
import geo as G

POSE = dict(T=(0.0, 0.55, 1.45), lacet=-0.105, tangage=0.04, roulis=0.17)     # la pose de qg08.py
COTES = (-1.95, -0.85, 0.55, 1.55)
BALAI = 0.48
A_TOP = math.pi / 2


def carcasse(lot, M, P, r, mats_coque, ouverture=(-1.5, 1.85)):
    """Crâne, verrière, queue, peau dorsale (ouverte entre ouverture[0] et [1]), épine, côtes, dérive, ailes, tuyères et
    jambes. Renvoie les pieds des côtes (monde)."""
    lot.xf = P.xf
    sc = C.surf_coque
    TAU = G.TAU
    xa, xb = ouverture
    verriere = (3.05, 4.3, A_TOP - 0.6, A_TOP + 0.62)

    # -- crâne --
    C.noyau(lot, M["noyau"], sc, 2.2, 5.5, 0.0, TAU)
    C.blindage(lot, sc, 2.22, 5.45, -0.3, TAU - 0.3, mats_coque, r, Mriv=M["riv"], larg=(0.45, 0.95), arcs=(0.4, 0.85),
               saut=lambda x, a: verriere[0] < x < verriere[1] and verriere[2] < a < verriere[3])
    rings = []
    nx, na = 14, 16
    for i in range(nx + 1):
        x = verriere[0] + (verriere[1] - verriere[0]) * i / nx
        t = i / float(nx)
        bump = math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7
        ring = []
        for j in range(na + 1):
            a = verriere[2] + (verriere[3] - verriere[2]) * j / na
            s = math.sin(math.pi * j / na)
            ring.append(C.point(x, a, 0.02 + 0.16 * bump * s ** 0.6))
        rings.append(ring)
    lot.put(M["verre_sombre"], G.loft(rings, closed=False))
    for i in (0, 4, 9, nx):
        lot.put(M["acier"], G.tube([G.add(p, (0, 0, 0.01)) for p in rings[i]], 0.035, 6))
    for j in (0, 6, 11, na):
        lot.put(M["acier"], G.tube([G.add(rr_[j], (0, 0, 0.01)) for rr_ in rings], 0.035, 6))
    C.bande(lot, sc, M["chevron"], 2.72, 2.9, A_TOP - 0.85, A_TOP + 0.85, 0.0, 0.08)
    tip = C.point(5.5, A_TOP, 0.0)
    lot.put(M["acier"], G.tour([(5.38, 0.13), (5.5, 0.12), (5.72, 0.04), (5.8, 0.0)], 12, "x", (0.0, 0.0, tip[2] - 0.05)))
    lot.put(M["voyant"], G.sphere((5.62, 0.0, tip[2] + 0.02), 0.025, 6, 3))
    for s in (-1, 1):
        y0 = s * 0.95
        poly = [(3.55, y0), (3.05, y0), (3.2, y0 + s * 0.75), (3.5, y0 + s * 0.8)]
        poly = poly if s > 0 else list(reversed(poly))
        v, f, u = G.prisme(poly, -0.03, 0.03)
        v = [(p[0], p[1], p[2] - 0.35 + abs(p[1] - y0) * 0.15) for p in v]
        lot.put(M["jaune1"] if s > 0 else M["patch"], (v, f, u))
        lot.put(M["chevron"], G.tube([(3.22, y0 + s * 0.72, -0.24), (3.5, y0 + s * 0.78, -0.23)], 0.035, 6))
    for (x, a, forme, lum, rr_) in ((2.62, A_TOP + 1.0, "rond", "hublot", 0.085), (3.35, A_TOP + 1.12, "ovale", "veilleuse", 0.07),
                                    (4.1, A_TOP + 1.05, "octo", "veilleuse", 0.06), (2.55, A_TOP - 1.1, "carre", "veilleuse", 0.07)):
        C.hublot(lot, forme, M["acier"], M[lum], sc(x, a, 0.05), C.normale_s(sc, x, a), rr_)
    p = sc(3.7, A_TOP + 1.35, 0.06)
    n = C.normale_s(sc, 3.7, A_TOP + 1.35)
    lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (0.62, 0.5, 0.05)), p, n))
    lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.03), (0.5, 0.38, 0.03)), p, n))
    lot.put(M["jaune1"], C.pose_plane(G.boite((0.3, 0.0, 0.2), (0.06, 0.4, 0.4), 0.0, 0.9), p, n))

    # -- queue --
    C.noyau(lot, M["noyau"], sc, -3.5, -2.18, -0.45, math.pi + 0.45)
    C.blindage(lot, sc, -2.2, -3.48, -0.42, math.pi + 0.42, mats_coque, r, Mriv=M["riv"], larg=(0.45, 0.9), arcs=(0.4, 0.85))
    lot.put(M["noyau"], G.loft([[sc(-3.5, -0.45 + (math.pi + 0.9) * j / 24.0, 0.0) for j in range(25)],
                                [(-3.52, 0.0, -0.2)] * 25], closed=False))

    # -- dos ouvert --
    def saut_dos(x, a):
        return xa < x < xb and not (a < A_TOP - 0.6 and (x < xa + 0.5 or x > xb - 1.1))
    C.noyau(lot, M["noyau"], sc, -2.2, xa, A_TOP - 0.95, A_TOP + 0.98, g=-0.01)
    C.noyau(lot, M["noyau"], sc, xb, 2.24, A_TOP - 0.95, A_TOP + 1.05, g=-0.01)
    C.blindage(lot, sc, -2.2, 2.24, A_TOP - 0.95, A_TOP + 0.98, mats_coque, r, Mriv=M["riv"], saut=saut_dos, gondole=0.3,
               larg=(0.42, 0.9), arcs=(0.4, 0.8))
    C.blindage(lot, sc, -2.2, xa, A_TOP + 0.98, A_TOP + 1.25, mats_coque, r, Mriv=M["riv"], gondole=0.5)
    for (a, rl) in ((A_TOP - 0.62, 0.045), (A_TOP + 0.6, 0.05), (A_TOP + 1.12, 0.04)):
        lot.put(M["acier"], G.tube([sc(x, a, 0.09) for x in [xa - 0.05 + (xb - xa + 0.05) * i / 20.0 for i in range(21)]], rl, 6))
    for (x, a, l, w) in ((xa + 0.08, A_TOP + 0.4, 0.55, 0.3), (xa + 0.1, A_TOP + 0.95, 0.5, 0.26), (xb + 0.07, A_TOP + 0.75, 0.45, 0.28),
                         (xa + 0.6, A_TOP - 0.66, 0.4, 0.3)):
        e = sc(x, a, 0.04)
        v, f, u = G.boite((w / 2 if x > 0 else -w / 2, 0.0, -l / 2), (w, 0.03, l))
        v = [G.add(e, G.rot_z(G.rot_x((q[0], q[1], q[2] + 0.05), -0.5 - 0.25 * r.f()), 0.3 * (1 if x > 0 else -1))) for q in v]
        lot.put(M["jaune1"] if r.f() < 0.6 else M["rapiece"], (v, f, u))

    # -- épine et vertèbres --
    ep = [(x, 0.0, C.z_dessus(x) + 0.13) for x in [-3.45 + 0.25 * i for i in range(31)] if x < 4.3]
    lot.put(M["acier"], G.tube(ep, 0.13, 4))
    lot.put(M["jaune2"], G.tube([G.add(p, (0, 0, 0.1)) for p in ep[2:-3]], 0.05, 6))
    for x in [-3.2, -2.55] + list(COTES) + [2.2, 2.75]:
        z0 = C.z_dessus(x) + 0.2
        h = 0.28 if x in COTES else 0.18
        lot.put(M["acier"], C.prisme_plan([(x + 0.14, z0), (x - 0.2, z0), (x - 0.34, z0 + h)], 0.05))

    # -- côtes balayées (((( --
    pieds = []
    for xt in COTES:
        e0, e1 = C.cote(lot, M["acier"], M["riv"], xt, -0.2, math.pi + 0.2, BALAI, g=0.1, haut=0.32)
        pieds.append((P.xf(e0), P.xf(e1)))
    for xt in (-2.2, 2.24):
        C.cote(lot, M["acier"], M["riv"], xt, -0.35, math.pi + 0.35, 0.12, g=0.06, prof=0.2, aile=0.26)

    # -- dérive --
    z0 = C.z_dessus(-2.4)
    z1 = C.z_dessus(-3.45)
    lot.put(M["jaune0"], C.prisme_plan([(-2.3, z0 - 0.05), (-3.25, z0 + 1.8), (-3.95, z0 + 1.86), (-3.5, z1 - 0.05)], 0.09))
    for (poly, m, y) in (([(-2.55, z0 + 0.35), (-3.1, z0 + 1.2), (-3.55, z0 + 1.2), (-3.4, z0 + 0.35)], "patch", 0.05),
                         ([(-3.13, z0 + 1.25), (-3.28, z0 + 1.5), (-3.75, z0 + 1.5), (-3.62, z0 + 1.25)], "rapiece", 0.05),
                         ([(-2.6, z0 + 0.35), (-3.0, z0 + 0.95), (-3.3, z0 + 0.95), (-3.2, z0 + 0.35)], "jaune1", -0.05)):
        lot.put(M[m], C.prisme_plan(poly, 0.025, y0=y))
    lot.put(M["chevron"], C.prisme_plan([(-3.27, z0 + 1.55), (-3.33, z0 + 1.72), (-3.93, z0 + 1.76), (-3.86, z0 + 1.55)], 0.11))
    lot.put(M["acier"], G.tube([(-2.3, 0.0, z0 - 0.05), (-3.25, 0.0, z0 + 1.8)], 0.05, 8))
    lot.put(M["voyant"], G.sphere((-3.6, 0.0, z0 + 1.92), 0.04, 8, 4))
    lot.put(M["acier"], G.tube([(-3.5, 0.0, z0 + 1.86), (-3.6, 0.0, z0 + 2.45)], 0.014, 5))

    # -- ailes --
    def aile(s, pts, zr, di, mat):
        poly = pts if s > 0 else list(reversed(pts))
        v, f, u = G.prisme(poly, -0.05, 0.05)
        yr = pts[0][1]
        sh = lambda q: (q[0], q[1], q[2] + zr + abs(q[1] - yr) * di)
        lot.put(mat, ([sh(q) for q in v], f, u))
        return sh
    yr = 1.88
    sh = aile(1, [(-2.65, yr), (-4.55, yr), (-5.3, 3.55), (-4.5, 3.6)], -0.42, 0.24, M["jaune0"])
    BA = lambda t: (-2.65 + (-4.5 + 2.65) * t - 0.07, yr + (3.6 - yr) * t)
    BF = lambda t: (-4.55 + (-5.3 + 4.55) * t + 0.1, yr + (3.55 - yr) * t)

    def pt(t, f_):
        a_, b_ = BA(t), BF(t)
        return (a_[0] + (b_[0] - a_[0]) * f_, a_[1] + (b_[1] - a_[1]) * f_)
    for (a0, a1, m, f0, f1) in ((0.04, 0.4, "jaune1", 0.0, 0.55), (0.04, 0.33, "rapiece", 0.6, 1.0), (0.42, 0.66, "patch", 0.0, 1.0),
                                (0.68, 0.96, "jaune2", 0.0, 0.7)):
        v, f, u = G.prisme([pt(a0, f0), pt(a1, f0), pt(a1, f1), pt(a0, f1)], 0.05, 0.075)
        lot.put(M[m], ([sh(q) for q in v], f, u))
    lot.put(M["chevron"], G.tube([sh((-4.52, 3.55, 0.06)), sh((-5.28, 3.5, 0.06))], 0.05, 6))
    lot.put(M["acier"], G.tube([sh((-2.65, yr, 0.06)), sh((-4.5, 3.6, 0.06))], 0.04, 6))
    lot.put(M["voyant"], G.sphere(sh((-4.9, 3.58, 0.1)), 0.035, 6, 3))
    sh2 = aile(-1, [(-2.7, -yr), (-4.0, -yr), (-4.25, -2.55), (-3.15, -2.62)], -0.42, 0.24, M["patch"])
    for (x, y) in ((-3.2, -2.6), (-3.55, -2.58), (-3.95, -2.54)):
        lot.put(M["acier"], G.tube([sh2((x, -2.45, 0.0)), sh2((x - 0.08, y - 0.22, 0.0))], 0.025, 5))

    # -- tuyères --
    for s, rz, ry in ((-1, 0.33, 0.14), (1, -0.1, 0.0)):
        att = (-2.05, s * 1.25, -0.42)

        def nac(p_, att=att, rz=rz, ry=ry):
            return G.add(G.rot_z(G.rot_y(p_, ry), rz), att)
        lot.xf = P.compose(nac)
        R, xav, xar = 0.74, 0.0, -2.55
        sn = C.surf_nac(R, xav, xar)
        C.noyau(lot, M["noyau"], sn, 0.05, xar - 0.02, 0.0, TAU)
        C.blindage(lot, sn, -0.04, xar, 0.0, TAU, mats_coque, r, Mriv=M["riv"], larg=(0.38, 0.7), arcs=(0.38, 0.7))
        for xb_ in (-0.62, -1.48, -2.25):
            rr_ = C.r_nacelle(xb_, R, xav, xar)
            lot.put(M["acier"], G.tour([(xb_ - 0.07, rr_ + 0.01), (xb_ - 0.06, rr_ + 0.1), (xb_ + 0.06, rr_ + 0.1), (xb_ + 0.07, rr_ + 0.01)], 32, "x"))
        re = C.r_nacelle(0.0, R, xav, xar)
        lot.put(M["acier"], G.tour([(-0.02, re * 1.03), (0.05, re * 1.06), (0.08, re * 0.85), (0.03, re * 0.62)], 32, "x"))
        lot.put(M["brule"], G.tour([(0.02, re * 0.64), (-0.18, 0.0)], 24, "x"))
        for k in range(7):
            a = TAU * k / 7
            lot.put(M["acier"], G.boite((0.0, re * 0.32 * math.cos(a), re * 0.32 * math.sin(a)), (0.03, 0.05, re * 0.62), 0.0, a))
        C.cloche(lot, M["acier"], M["acier"], M["brule"], M["anneau"], xar, R)
        lot.put(M["anneau"], G.tour([(-1.0, R + 0.02), (-1.0, R + 0.12), (-0.8, R + 0.12), (-0.8, R + 0.02)], 16, "x"))
        lot.xf = P.xf

    # -- menus de la coque (3 à 10 px) --
    mats = [M["acier"], M["noyau"], M["acier_clair"], M["riv"]]
    rm = G.Rnd(8089)
    for k in range(90):
        x, a = rm.f(-2.1, 5.0), A_TOP + rm.f(-1.0, 1.0)
        if xa + 0.05 < x < xb - 0.05:
            continue
        lot.put(mats[k % 4], C.pose_plane(G.boite((0, 0, 0.02), (rm.f(0.05, 0.14), rm.f(0.04, 0.1), 0.05), rz=rm.f(-0.7, 0.7)), C.point(x, a, 0.05),
                                          C.normale_s(sc, x, a)))
    lot.xf = None

    # -- jambes des côtes (matière au choix de l'âge) --
    return pieds


def grilles_coque(lot, M, P):
    """Trois grilles de coque (regards à lames), comme à l'âge 8."""
    for (x, a, w, l) in ((3.0, A_TOP - 0.7, 0.32, 0.4), (3.9, A_TOP + 0.95, 0.26, 0.36), (-2.9, A_TOP + 0.2, 0.3, 0.5)):
        p = P.xf(C.point(x, a, 0.07))
        n = G.norm(G.sub(P.xf(C.point(x, a, 0.3)), p))
        lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (l + 0.06, w + 0.06, 0.04)), p, n))
        lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.015), (l, w, 0.03)), p, n))
        for k in range(6):
            lot.put(M["acier"], C.pose_plane(G.boite((-l / 2 + l * (k + 0.5) / 6, 0, 0.035), (l / 6 * 0.45, w, 0.025)), p, n))


def cablage(lot, M, P, pieds, ra):
    """Faisceaux rouges et noirs le long de la cage et des flancs (mêmes attaches qu'à l'âge 8)."""
    fx = [(P.xf((COTES[i] - 0.05, 0.25, C.z_dessus(COTES[i]) + 0.4)), P.xf((COTES[i + 1] - 0.05, 0.25, C.z_dessus(COTES[i + 1]) + 0.4)), 0.32)
          for i in range(3)]
    fx += [(pieds[0][1], pieds[1][1], 0.4), (pieds[2][1], pieds[3][1], 0.34), (pieds[1][1], pieds[2][1], 0.45)]
    for (a, b, fl) in fx:
        C.faisceau(lot, M["rouge"], M["noir"], a, b, fl, 3, 0.011, 0.028, ra)
    for (a, b, fl) in ((P.xf((-1.9, -1.0, 0.2)), P.xf((0.4, -1.12, 0.1)), 0.3), (P.xf((0.4, -1.12, 0.1)), P.xf((2.0, -1.0, 0.25)), 0.25),
                       (P.xf((2.4, -0.9, 0.5)), P.xf((3.8, -0.75, 0.35)), 0.18), (P.xf((-3.3, -0.9, 0.3)), P.xf((-2.3, -1.05, 0.1)), 0.22)):
        C.faisceau(lot, M["rouge"], M["noir"], a, b, fl, 4, 0.011, 0.026, ra)


def mat_tirage(M, parts, chevron=(4.55, 4.8)):
    """Tirage des tôles : parts = [(clé, part cumulée)...], chevrons à l'avant du crâne (mêmes bandes qu'à l'âge 8)."""
    def choix(rr, xm, am):
        if chevron[0] < xm < chevron[1]:
            return M["chevron"]
        x = rr.f()
        for (k, c) in parts:
            if x < c:
                return M[k]
        return M[parts[-1][0]]
    return choix


# ================================================================================================ formes
def chanfrein(x0, x1, y0, y1, ch):
    """Plan rectangulaire à coins coupés (8 sommets, sens direct)."""
    return [(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch), (x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch), (x0, y0 + ch)]


def octogone(cx, cy, r, phase=math.pi / 8):
    return [(cx + r * math.cos(phase + G.TAU * k / 8), cy + r * math.sin(phase + G.TAU * k / 8)) for k in range(8)]


def retrait(poly, d):
    """Polygone convexe rentré de d vers son centre (d constant sur les deux axes, pour un plan allongé ; d < 0 : sorti)."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    out = []
    for (x, y) in poly:
        dx, dy = x - cx, y - cy
        ox = d if d < 0 else min(d, abs(dx))
        oy = d if d < 0 else min(d, abs(dy))
        out.append((x - math.copysign(ox, dx), y - math.copysign(oy, dy)))
    return out


def tronc(p0, p1, z0, z1, dessus=True):
    """Tronc de prisme : plan p0 à z0, plan p1 à z1 (même nombre de sommets). Chaque pan a ses propres sommets (arête
    nette, joints de tôle en unités de longueur)."""
    n = len(p0)
    verts, faces, uvs = [], [], []
    acc = 0.0
    for i in range(n):
        a, b = p0[i], p0[(i + 1) % n]
        c, d = p1[(i + 1) % n], p1[i]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        H = math.hypot(z1 - z0, math.hypot(d[0] - a[0], d[1] - a[1]))
        base = len(verts)
        verts += [(a[0], a[1], z0), (b[0], b[1], z0), (c[0], c[1], z1), (d[0], d[1], z1)]
        uvs += [(acc, 0.0), (acc + L, 0.0), (acc + L, H), (acc, H)]
        faces.append((base, base + 1, base + 2, base + 3))
        acc += L
    if dessus:
        base = len(verts)
        verts += [(p[0], p[1], z1) for p in p1]
        uvs += [(p[0], p[1]) for p in p1]
        faces.append(tuple(range(base, base + n)))
    return verts, faces, uvs


def cerceau(cx, cy, z, R, rt, segs=32, incl=(0.0, 0.0)):
    """Anneau (tore) de rayon R, section rt ; incl = pentes (dz/dx, dz/dy)."""
    pts = []
    for k in range(segs + 1):
        a = G.TAU * k / segs
        dx, dy = R * math.cos(a), R * math.sin(a)
        pts.append((cx + dx, cy + dy, z + incl[0] * dx + incl[1] * dy))
    return G.tube(pts, rt, 6)


def garde(lot, M, a, b, h=0.42):
    """Garde-corps : main courante, lisse, montants."""
    lot.put(M["acier"], G.tube([G.add(a, (0, 0, h)), G.add(b, (0, 0, h))], 0.018, 5))
    lot.put(M["acier"], G.tube([G.add(a, (0, 0, h * 0.5)), G.add(b, (0, 0, h * 0.5))], 0.012, 5))
    n = max(1, int(G.length(G.sub(b, a)) / 0.42))
    for j in range(n + 1):
        q = G.lerp(a, b, j / float(n))
        lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, h))], 0.014, 5))


def couche(mesh, q, rz, r=0.14):
    """Objet couché au sol (axe x local), tourné de rz, posé en q (x, y)."""
    v, f, u = mesh
    out = []
    for p in v:
        p = G.rot_z(p, rz)
        out.append((p[0] + q[0], p[1] + q[1], p[2] + r))
    return out, f, u


def menus_sol(lot, mats, rnd, x0, x1, y0, y1, z, n):
    """Menus détails posés à plat (3 à 10 px) : plaques, regards, cales, comme sur le ponton de l'âge 8."""
    for k in range(n):
        p = (rnd.f(x0, x1), rnd.f(y0, y1), z + 0.015)
        lot.put(mats[k % len(mats)], G.boite(p, (rnd.f(0.05, 0.15), rnd.f(0.04, 0.11), rnd.f(0.03, 0.06)), rnd.f(-0.5, 0.5)))


def menus_mur(lot, mats, rnd, x0, x1, y, z0, z1, n, normale=(0.0, -1.0, 0.0)):
    """Menus détails sur un mur vu de trois quarts : équerres, boîtiers, regards."""
    for k in range(n):
        p = (rnd.f(x0, x1), y, rnd.f(z0, z1))
        lot.put(mats[k % len(mats)], C.pose_plane(G.boite((0, 0, 0.012), (rnd.f(0.05, 0.12), rnd.f(0.04, 0.1), 0.03)), p, normale))


def butte_nez(lot, M, P, r):
    """Butte de terre poussée par le nez et ses deux mottes (la carcasse a le même accident à chaque âge)."""
    nez = P.xf((5.0, 0.0, -0.3))
    lot.put(M["boue"], G.butte_polaire((nez[0] + 0.15, nez[1] - 0.1, 0.0), 1.05, 1.5, 0.62, r, 12, 48, 0.3, 0.14))
    for (x, y, a, b) in ((nez[0] + 0.9, nez[1] - 1.2, 0.45, 0.35), (nez[0] - 0.4, nez[1] + 1.25, 0.5, 0.3)):
        lot.put(M["boue"], G.butte_polaire((x, y, 0.0), a, b, 0.2, r, 6, 28, 0.3, 0.2))


def mats_base(sf, pref, jaunes, cr, MT):
    """Matières de coque communes aux âges 7 et 9 : les jaunes de l'âge 8, chevrons, noyau, rivets, acier."""
    M = {}
    for i, c in enumerate(jaunes):
        M["jaune%d" % i] = sf("%s_jaune%d" % (pref, i), c, rough=0.48, met=0.2, coulures=0.9, rouille=(0.16, 0.06, 0.02), usure=0.85,
                              nu=(0.62, 0.6, 0.56), crasse=0.95, crasse_col=cr, pied=(0.3, 1.1, 0.5), grain=0.11, graine=81 + i)
    M["noyau"] = sf(pref + "_noyau", (0.007, 0.006, 0.005), rough=0.6, met=0.6, usure=0.2, crasse=0.8, crasse_col=(0.004, 0.003, 0.002), graine=89)
    M["brule"] = sf(pref + "_brule", (0.01, 0.0085, 0.008), rough=0.75, met=0.4, usure=0.0, crasse=0.8, crasse_col=(0.003, 0.003, 0.003), graine=90)
    M["acier"] = sf(pref + "_acier", (0.085, 0.052, 0.03), rough=0.5, met=0.75, usure=0.85, nu=(0.72, 0.68, 0.6), crasse=0.7,
                    crasse_col=cr, coulures=0.5, graine=91)
    M["acier_clair"] = sf(pref + "_acier_clair", (0.2, 0.19, 0.175), rough=0.4, met=0.85, usure=0.4, crasse=0.6, crasse_col=cr, graine=92)
    M["riv"] = sf(pref + "_riv", (0.085, 0.065, 0.035), rough=0.6, met=0.3, usure=0.3, crasse=0.5, graine=93)
    M["chevron"] = sf(pref + "_chevron", jaunes[0], rough=0.5, met=0.2, bandes=(0.19, (0.012, 0.011, 0.01), 0.5), usure=0.8,
                      nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.6, graine=94)
    M["caoutchouc"] = sf(pref + "_caoutchouc", (0.023, 0.023, 0.021), rough=0.72, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.065),
                         crasse=0.5, crasse_col=cr, graine=96)
    M["boue"] = sf(pref + "_boue", (0.075, 0.048, 0.024), rough=0.85, met=0.0, usure=0.0, crasse=0.6, crasse_col=(0.01, 0.008, 0.004),
                   grain=0.2, graine=102)
    M["rouge"] = sf(pref + "_rouge", (0.32, 0.02, 0.012), rough=0.55, met=0.0, usure=0.3, nu=(0.4, 0.2, 0.15), crasse=0.4, graine=104)
    M["noir"] = sf(pref + "_noir", (0.012, 0.012, 0.012), rough=0.7, met=0.0, usure=0.2, crasse=0.3, graine=105)
    M["verre_sombre"] = MT.verre(pref + "_verre_sombre", col=(0.01, 0.025, 0.03), reflet=(0.12, 0.2, 0.2))
    return M
