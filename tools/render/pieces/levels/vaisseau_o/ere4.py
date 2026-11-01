"""ÈRE IV (Haute techno, âges 10 à 12) du QG, série du 31/10 : la carcasse de l'état validé de l'âge 8 (qg08.py, mêmes
crâne, épine, côtes balayées, 2 tuyères, dérive), agrandie à 14×7, soulevée sur pieds, et le kit de l'ère (bible §5) :
radôme, parabole, fouet, pied télescopique, pied en V, aileron, anneau, pylône, bloc flottant. Langage de forme de l'ère :
lisse, élancé, sur pieds, premières pièces flottantes. Tôles plus grandes, moins de rivets, peu de gondole (« lisse »)
mais joints sombres, marquages et menus détails : une coque lisse sans détails se lit « jouet ».
"""
import math

import carcasse as C
import geo as G

K = 7.0 / 6.0
TAU = G.TAU
TOP = math.pi / 2
COTES = (-1.95, -0.85, 0.55, 1.55)
BALAI = 0.48
LISSE = dict(larg=(0.45, 1.0), arcs=(0.4, 0.9), gap=0.028, ep=(0.018, 0.045), gondole=0.08, rivets=0.45)
LISSE2 = dict(larg=(0.7, 1.5), arcs=(0.55, 1.2), gap=0.026, ep=(0.018, 0.04), gondole=0.05, rivets=0.35)   # bâtiments : grands capots


class PoseK(C.Pose):
    """Pose du vaisseau, agrandi de k (14×7 contre 12×6) ; niv : bâtiments en tuiles vraies, de niveau, z absolu."""

    def __init__(self, k=K, **kw):
        super().__init__(**kw)
        self.k = k

    def xf(self, p):
        return C.Pose.xf(self, (p[0] * self.k, p[1] * self.k, p[2] * self.k))


def tirage(M, table, chevron=(4.55, 4.8)):
    """Choix de matière d'une tôle : table = [(part, clé)], chevrons à l'abscisse du nez."""
    def f(rr, xm, am):
        if chevron and chevron[0] < xm < chevron[1]:
            return M["chevron"]
        x, acc = rr.f(), 0.0
        for (part, cle) in table:
            acc += part
            if x < acc:
                return M[cle]
        return M[table[-1][1]]
    return f


# ================================================================================================ carcasse
def crane(lot, M, P, r, mc, lisse=LISSE, saut=None):
    lot.xf = P.xf
    sc = C.surf_coque
    v = (3.05, 4.3, TOP - 0.6, TOP + 0.62)
    C.noyau(lot, M["noyau"], sc, 2.2, 5.5, 0.0, TAU)
    s2 = lambda x, a: (v[0] < x < v[1] and v[2] < a < v[3]) or (saut(x, a) if saut else False)
    C.blindage(lot, sc, 2.22, 5.45, -0.3, TAU - 0.3, mc, r, Mriv=M["riv"], saut=s2, **lisse)
    rings = []
    nx, na = 14, 16
    for i in range(nx + 1):
        x = v[0] + (v[1] - v[0]) * i / nx
        t = i / float(nx)
        bump = math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7
        ring = []
        for j in range(na + 1):
            a = v[2] + (v[3] - v[2]) * j / na
            s = math.sin(math.pi * j / na)
            ring.append(C.point(x, a, 0.02 + 0.16 * bump * s ** 0.6))
        rings.append(ring)
    lot.put(M["verre_sombre"], G.loft(rings, closed=False))
    for i in (0, 4, 9, nx):
        lot.put(M["acier"], G.tube([G.add(p, (0, 0, 0.01)) for p in rings[i]], 0.035, 6))
    for j in (0, 6, 11, na):
        lot.put(M["acier"], G.tube([G.add(q[j], (0, 0, 0.01)) for q in rings], 0.035, 6))
    C.bande(lot, sc, M["chevron"], 2.72, 2.9, TOP - 0.85, TOP + 0.85, 0.0, 0.08)
    tip = C.point(5.5, TOP, 0.0)
    lot.put(M["acier"], G.tour([(5.38, 0.13), (5.5, 0.12), (5.72, 0.04), (5.8, 0.0)], 12, "x", (0.0, 0.0, tip[2] - 0.05)))
    lot.put(M["voyant"], G.sphere((5.62, 0.0, tip[2] + 0.02), 0.025, 6, 3))
    for (x, a, forme, lum, rr_) in ((2.62, TOP + 1.0, "rond", "hublot", 0.085), (3.35, TOP + 1.12, "ovale", "veilleuse", 0.07),
                                    (4.1, TOP + 1.05, "octo", "veilleuse", 0.06), (2.55, TOP - 1.1, "carre", "veilleuse", 0.07)):
        C.hublot(lot, forme, M["acier"], M[lum], sc(x, a, 0.05), C.normale_s(sc, x, a), rr_)
    p, n = sc(3.7, TOP + 1.35, 0.06), C.normale_s(sc, 3.7, TOP + 1.35)
    lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (0.62, 0.5, 0.05)), p, n))
    lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.03), (0.5, 0.38, 0.03)), p, n))


def queue(lot, M, P, r, mc, lisse=LISSE, saut=None):
    lot.xf = P.xf
    sc = C.surf_coque
    C.noyau(lot, M["noyau"], sc, -3.5, -2.18, -0.45, math.pi + 0.45)
    C.blindage(lot, sc, -2.2, -3.48, -0.42, math.pi + 0.42, mc, r, Mriv=M["riv"], saut=saut, **lisse)
    lot.put(M["noyau"], G.loft([[sc(-3.5, -0.45 + (math.pi + 0.9) * j / 24.0, 0.0) for j in range(25)],
                                [(-3.52, 0.0, -0.2)] * 25], closed=False))


def dos(lot, M, P, r, mc, lisse=LISSE, x0=-1.5, x1=1.85):
    """Peau dorsale : restes aux deux bouts du ventre, cage ouverte de x0 à x1."""
    lot.xf = P.xf
    sc = C.surf_coque

    def saut_dos(x, a):
        return x0 < x < x1 and not (a < TOP - 0.6 and (x < -1.0 or x > 0.75))
    C.noyau(lot, M["noyau"], sc, -2.2, x0, TOP - 0.95, TOP + 0.98, g=-0.01)
    C.noyau(lot, M["noyau"], sc, x1, 2.24, TOP - 0.95, TOP + 1.05, g=-0.01)
    C.blindage(lot, sc, -2.2, 2.24, TOP - 0.95, TOP + 0.98, mc, r, Mriv=M["riv"], saut=saut_dos, **lisse)
    C.blindage(lot, sc, -2.2, x0, TOP + 0.98, TOP + 1.25, mc, r, Mriv=M["riv"], **lisse)


def epine(lot, M, P, x1=4.3):
    lot.xf = P.xf
    ep = [(x, 0.0, C.z_dessus(x) + 0.13) for x in [-3.45 + 0.25 * i for i in range(31)] if x < x1]
    lot.put(M["acier"], G.tube(ep, 0.13, 4))
    lot.put(M["epine"], G.tube([G.add(p, (0, 0, 0.1)) for p in ep[2:-3]], 0.05, 6))
    for x in [-3.2, -2.55] + list(COTES) + [2.2, 2.75]:
        z0 = C.z_dessus(x) + 0.2
        h = 0.28 if x in COTES else 0.18
        lot.put(M["acier"], C.prisme_plan([(x + 0.14, z0), (x - 0.2, z0), (x - 0.34, z0 + h)], 0.05))


def cotes(lot, M, P, haut=None, liste=COTES):
    """Côtes balayées « (((( » ; haut(x) : surhausse de l'arche. Renvoie les pieds (monde) : [(nord, sud)]."""
    lot.xf = P.xf
    pieds = []
    for xt in liste:
        e0, e1 = C.cote(lot, M["cote"], M["riv"], xt, -0.2, math.pi + 0.2, BALAI, g=0.1, haut=haut(xt) if haut else 0.32)
        pieds.append((P.xf(e0), P.xf(e1)))
    for xt in (-2.2, 2.24):
        C.cote(lot, M["cote"], M["riv"], xt, -0.35, math.pi + 0.35, 0.12, g=0.06, prof=0.2, aile=0.26)
    return pieds


def lisses(lot, M, P, angles=((TOP + 1.12, 0.04), (TOP - 1.12, 0.04))):
    lot.xf = P.xf
    sc = C.surf_coque
    for (a, rl) in angles:
        lot.put(M["acier"], G.tube([sc(x, a, 0.09) for x in [-1.55 + 0.17 * i for i in range(21)]], rl, 6))


def tuyeres(lot, M, P, r, mc, R=0.74, lisse=LISSE, apres=None, cerclages=(-0.62, -1.48, -2.25)):
    """Les deux tuyères, nacelles cantées, cloches relevées vers la caméra (comme l'âge 8)."""
    for s, rz, ry in ((-1, 0.33, 0.14), (1, -0.1, 0.0)):
        att = (-2.05, s * 1.25, -0.42)

        def nac(p, att=att, rz=rz, ry=ry):
            return G.add(G.rot_z(G.rot_y(p, ry), rz), att)
        lot.xf = P.compose(nac)
        xav, xar = 0.0, -2.55
        sn = C.surf_nac(R, xav, xar)
        C.noyau(lot, M["noyau"], sn, 0.05, xar - 0.02, 0.0, TAU)
        C.blindage(lot, sn, -0.04, xar, 0.0, TAU, mc, r, Mriv=M["riv"], **lisse)
        for xb in cerclages:
            rr_ = C.r_nacelle(xb, R, xav, xar)
            lot.put(M["bague"], G.tour([(xb - 0.07, rr_ + 0.01), (xb - 0.06, rr_ + 0.08), (xb + 0.06, rr_ + 0.08), (xb + 0.07, rr_ + 0.01)], 32, "x"))
        re = C.r_nacelle(0.0, R, xav, xar)
        lot.put(M["acier"], G.tour([(-0.02, re * 1.03), (0.05, re * 1.06), (0.08, re * 0.85), (0.03, re * 0.62)], 32, "x"))
        lot.put(M["brule"], G.tour([(0.02, re * 0.64), (-0.18, 0.0)], 24, "x"))
        for k in range(7):
            a = TAU * k / 7
            lot.put(M["acier"], G.boite((0.0, re * 0.32 * math.cos(a), re * 0.32 * math.sin(a)), (0.03, 0.05, re * 0.62), 0.0, a))
        C.cloche(lot, M["acier"], M["acier"], M["brule"], M["bague"], xar, R)
        for (x, a, w, l) in ((-1.05, 1.9, 0.26, 0.42), (-1.85, 2.2, 0.22, 0.34)):       # grilles de nacelle
            p, n = sn(x, a, 0.05), C.normale_s(sn, x, a)
            lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (l + 0.06, w + 0.06, 0.04)), p, n))
            lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.015), (l, w, 0.03)), p, n))
            for k in range(5):
                lot.put(M["acier"], C.pose_plane(G.boite((-l / 2 + l * (k + 0.5) / 5, 0, 0.035), (l / 5 * 0.45, w, 0.025)), p, n))
        if apres:
            apres(s, sn, R, xar)
    lot.xf = P.xf


def menus(lot, M, P, r, n=110, cles=("acier", "noyau", "acier_clair", "riv")):
    """Menus détails de coque (3 à 10 px), clairs et sombres."""
    mats = [M[k] for k in cles]
    lot.xf = P.xf
    for k in range(n):
        x, a = r.f(-3.3, 5.0), TOP + r.f(-1.2, 1.2)
        if -1.4 < x < 1.8:
            continue
        p, n_ = C.point(x, a, 0.05), C.normale_s(C.surf_coque, x, a)
        lot.put(mats[k % len(mats)], C.pose_plane(G.boite((0, 0, 0.02), (r.f(0.05, 0.16), r.f(0.04, 0.1), 0.05), rz=r.f(-0.7, 0.7)), p, n_))


# ================================================================================================ pose sur un mur
def repere(n, up=(0.0, 0.0, 1.0)):
    ez = G.norm(n)
    u = G.sub(up, G.mul(ez, G.dot(up, ez)))
    if G.length(u) < 1e-4:
        u = G.sub((0.0, 1.0, 0.0), G.mul(ez, ez[1]))
    ey = G.norm(u)
    return G.cross(ey, ez), ey, ez


def pose(mesh, p, n, up=(0.0, 0.0, 1.0)):
    """Maille modélisée à plat (X droite, Y haut, Z sortant) posée en p, Z le long de n."""
    ex, ey, ez = repere(n, up)
    v, f, u = mesh
    return [G.add(p, G.add(G.add(G.mul(ex, q[0]), G.mul(ey, q[1])), G.mul(ez, q[2]))) for q in v], f, u


def grille(lot, Mc, Mf, p, n, w, h, lames=6):
    lot.put(Mc, pose(G.boite((0, 0, 0.012), (w + 0.05, h + 0.05, 0.03)), p, n))
    lot.put(Mf, pose(G.boite((0, 0, 0.022), (w, h, 0.02)), p, n))
    for k in range(lames):
        lot.put(Mc, pose(G.boite((0, -h / 2 + h * (k + 0.5) / lames, 0.035), (w, h / lames * 0.5, 0.012)), p, n))


def ecran(lot, Mc, Ml, p, n, w, h):
    """Écran encadré : plaque lumineuse (pas une fenêtre)."""
    lot.put(Mc, pose(G.boite((0, 0, 0.012), (w + 0.05, h + 0.05, 0.03)), p, n))
    lot.put(Ml, pose(G.boite((0, 0, 0.026), (w, h, 0.012)), p, n))


def boitier(lot, M, Mv, p, n, w, h, d=0.07):
    lot.put(M, pose(G.boite((0, 0, d / 2), (w, h, d)), p, n))
    if Mv is not None:
        lot.put(Mv, pose(G.boite((w * 0.28, h * 0.28, d + 0.003), (0.025, 0.025, 0.008)), p, n))


# ================================================================================================ formes lisses
def stade_pt(s, L, W):
    """Point du contour d'un stade de longueur L, largeur W, à l'abscisse réduite s ; rend (x, y, nx, ny), départ au sud-ouest."""
    R = W / 2.0
    ls = max(0.0, L - W)
    per = 2 * ls + TAU * R
    d = (s % 1.0) * per
    if d < ls:
        return (-ls / 2 + d, -R, 0.0, -1.0)
    d -= ls
    if d < math.pi * R:
        a = -TOP + d / R
        return (ls / 2 + R * math.cos(a), R * math.sin(a), math.cos(a), math.sin(a))
    d -= math.pi * R
    if d < ls:
        return (ls / 2 - d, R, 0.0, 1.0)
    d -= ls
    a = TOP + d / R
    return (-ls / 2 + R * math.cos(a), R * math.sin(a), math.cos(a), math.sin(a))


class Stade:
    """Capsule lisse à plan en stade : prof = [(z, retrait)] ; loc(x, y, z) -> monde ; mur(s, z, g, ret) -> (p, n)."""

    def __init__(self, c, L, W, rz=0.0):
        self.c, self.L, self.W, self.rz = c, L, W, rz

    def loc(self, x, y, z):
        q = G.rot_z((x, y, z), self.rz)
        return (q[0] + self.c[0], q[1] + self.c[1], q[2])

    def anneau(self, z, ret, n=72):
        out = []
        for j in range(n):
            x, y, nx, ny = stade_pt(j / float(n), self.L, self.W)
            out.append(self.loc(x - nx * ret, y - ny * ret, z))
        return out

    def corps(self, lot, M, prof, cap=True, n=72):
        lot.put(M, G.loft([self.anneau(z, ret, n) for (z, ret) in prof], cap1=cap))

    def ceinture(self, lot, M, z, h, ret=0.0, sail=0.02, n=72):
        self.corps(lot, M, [(z - h / 2, ret), (z - h / 2, ret - sail), (z + h / 2, ret - sail), (z + h / 2, ret)], cap=False, n=n)

    def s_sud(self, x):
        """Abscisse réduite du point de la face sud d'abscisse locale x."""
        ls = max(0.0, self.L - self.W)
        per = 2 * ls + TAU * self.W / 2.0
        return (x + ls / 2.0) / per

    def mur(self, s, z, g=0.0, ret=0.0):
        x, y, nx, ny = stade_pt(s, self.L, self.W)
        p = self.loc(x + nx * (g - ret), y + ny * (g - ret), z)
        q = G.rot_z((nx, ny, 0.0), self.rz)
        return p, q


def surf_fuseau(c, L, W, H, zc, rz=0.0, n=2.7, pe=4.5):
    """Corps couché lisse (x le long, a = 0 côté +y, pi/2 dessus, pi côté sud), même paramétrage que la coque : les tôles
    irrégulières de C.blindage s'y posent, un bâtiment de l'ère a donc la peau du vaisseau et non une boîte."""
    def surf(x, a, g):
        t = min(1.0, abs(2.0 * x / L))
        f = max(0.03, (1.0 - t ** pe) ** (1.0 / pe))
        ca, sa = math.cos(a), math.sin(a)
        e = 2.0 / n
        y = (W / 2.0 * f + g) * math.copysign(abs(ca) ** e, ca)
        z = zc + (H * f ** 0.55 + g) * math.copysign(abs(sa) ** e, sa)
        q = G.rot_z((x, y, 0.0), rz)
        return (q[0] + c[0], q[1] + c[1], z)
    return surf


def rangee(lot, M, surf, x0, x1, a, rnd, types, cles, sauts=()):
    """Pièces différentes le long d'un flanc : verre, écran, grille, boîtier, porte de service ; jamais une rangée égale.
    cles = (cadre, verre, lumière, acier, fond, boîtier, voyant) ; sauts = [(x0, x1)] laissés libres."""
    cad, ver, lum, aci, fon, boi, voy = [M[k] for k in cles]
    x, i = x0, 0
    while x < x1:
        w = rnd.f(0.26, 0.72)
        xm = x + w / 2
        if any(s0 < xm < s1 for (s0, s1) in sauts):
            x += w
            continue
        t = types[i % len(types)]
        i += 1
        p, n = surf(xm, a, 0.03), C.normale_s(surf, xm, a)
        if t == "verre":
            ecran(lot, cad, ver, p, n, w * 0.9, 0.2 + 0.06 * rnd.f())
        elif t == "ecran":
            ecran(lot, cad, lum, p, n, w * 0.62, 0.075)
        elif t == "grille":
            grille(lot, aci, fon, p, n, w * 0.8, 0.22, 4)
        elif t == "boite":
            boitier(lot, boi, voy, p, n, w * 0.72, 0.26, 0.08)
        else:
            ecran(lot, aci, fon, p, n, 0.3, 0.36)
        x += w + rnd.f(0.03, 0.14)


def bazar(lot, M, surf, x0, x1, a0, a1, rnd, n, cles):
    """Bric-à-brac de toit posé sur une surface : caissons, aérateurs, plaques, trappes, câbles courts (3 à 25 px).
    cles = (caisson, sombre, acier, plaque)."""
    cai, som, aci, pla = [M[k] for k in cles]
    for k in range(n):
        x, a = rnd.f(x0, x1), rnd.f(a0, a1)
        p, nr = surf(x, a, 0.0), C.normale_s(surf, x, a)
        t = k % 5
        if t == 0:
            w, l = rnd.f(0.14, 0.34), rnd.f(0.16, 0.42)
            lot.put(cai, pose(G.boite((0, 0, 0.05), (l, w, 0.11)), p, nr, (0.0, 1.0, 0.0)))
            lot.put(som, pose(G.boite((0, 0, 0.108), (l * 0.8, w * 0.7, 0.012)), p, nr, (0.0, 1.0, 0.0)))
        elif t == 1:
            rr = rnd.f(0.04, 0.08)
            lot.put(aci, G.oriente(G.tour([(0.0, rr), (0.14, rr), (0.145, rr * 1.8), (0.175, rr * 1.6), (0.2, 0.0)], 10, "z"), p, nr))
        elif t == 2:
            lot.put(pla, pose(G.boite((0, 0, 0.012), (rnd.f(0.2, 0.55), rnd.f(0.12, 0.3), 0.022)), p, nr, (0.0, 1.0, 0.0)))
        elif t == 3:
            lot.put(som, pose(G.boite((0, 0, 0.008), (rnd.f(0.1, 0.24), rnd.f(0.1, 0.2), 0.016)), p, nr, (0.0, 1.0, 0.0)))
            lot.put(aci, pose(G.boite((0, 0, 0.018), (rnd.f(0.04, 0.09), 0.03, 0.02)), p, nr, (0.0, 1.0, 0.0)))
        else:
            q = surf(x + rnd.f(0.2, 0.5), a + rnd.f(-0.15, 0.15), 0.025)
            lot.put(aci, G.tube([G.add(p, G.mul(nr, 0.03)), q], rnd.f(0.012, 0.026), 5))


def joint(lot, M, st, z0, ret0, z1, ret1, s, r=0.012):
    """Couvre-joint d'un toit ou d'un mur de capsule, de (z0, ret0) à (z1, ret1), à l'abscisse réduite s."""
    a = st.mur(s, z0, 0.012, ret0)[0]
    b = st.mur(s, z1, 0.012, ret1)[0]
    lot.put(M, G.tube([a, b], r, 4))


def tube_conique(a, b, r0, r1, n=14, segs=8):
    pts = [G.lerp(a, b, i / float(n - 1)) for i in range(n)]
    return G.tube(pts, r0, segs, rfun=lambda s, i: r0 + (r1 - r0) * i / float(n - 1))


def plan3(pts, ep):
    """Prisme sur un polygone plan convexe donné en 3D (aileron, dalle inclinée) ; épaisseur ep centrée."""
    n = G.norm(G.cross(G.sub(pts[1], pts[0]), G.sub(pts[2], pts[0])))
    d = G.mul(n, ep / 2.0)
    top = [G.add(p, d) for p in pts]
    bot = [G.sub(p, d) for p in pts]
    ex = G.norm(G.sub(pts[1], pts[0]))
    ey = G.cross(n, ex)
    uv = lambda p: (G.dot(G.sub(p, pts[0]), ex), G.dot(G.sub(p, pts[0]), ey))
    v, f, u = list(top), [tuple(range(len(top)))], [uv(p) for p in top]
    b = len(v)
    v += list(reversed(bot))
    u += [uv(p) for p in reversed(bot)]
    f.append(tuple(range(b, b + len(bot))))
    m, acc = len(pts), 0.0
    for i in range(m):
        a0, a1, t1, t0 = bot[i], bot[(i + 1) % m], top[(i + 1) % m], top[i]
        L = G.length(G.sub(a1, a0))
        b = len(v)
        v += [a0, a1, t1, t0]
        u += [(acc, 0.0), (acc + L, 0.0), (acc + L, ep), (acc, ep)]
        f.append((b, b + 1, b + 2, b + 3))
        acc += L
    return v, f, u


def retreci(pts, k):
    c = G.mul(tuple(sum(p[i] for p in pts) for i in range(3)), 1.0 / len(pts))
    return [G.lerp(c, p, k) for p in pts]


def chenillard(lot, Ml, a, b, rnd, r=0.018, part=0.55, pas=(0.14, 0.3)):
    """Ligne de lumière segmentée le long de a -> b (segments inégaux)."""
    L = G.length(G.sub(b, a))
    t = rnd.f(0.0, 0.1)
    while t < L - 0.03:
        w = rnd.f(*pas)
        e = min(L, t + w * part)
        lot.put(Ml, G.tube([G.lerp(a, b, t / L), G.lerp(a, b, e / L)], r, 4))
        t += w


# ================================================================================================ kit d'époque
def icosa(sub=2):
    """Triangles d'une sphère géodésique unité (sub subdivisions de l'icosaèdre)."""
    t = (1.0 + math.sqrt(5.0)) / 2.0
    V = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
         (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    V = [G.norm(v) for v in V]
    F = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
         (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    tris = [(V[a], V[b], V[c]) for (a, b, c) in F]
    for _ in range(sub):
        out = []
        for (a, b, c) in tris:
            ab, bc, ca = G.norm(G.add(a, b)), G.norm(G.add(b, c)), G.norm(G.add(c, a))
            out += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        tris = out
    return tris


def tri3(top, bot):
    v = list(top) + list(bot)
    u = [(p[0], p[1]) for p in v]
    f = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    return v, f, u


def radome(lot, mats, Mfond, c, R, rnd, zmin=-0.25, sub=2, gap=0.95, ep=0.03):
    """Radôme : sphère géodésique à panneaux triangulaires (2 à 3 tons), joints sombres par la sphère de fond."""
    lot.put(Mfond, G.sphere(c, R * 0.992, 40, 20, zmin=zmin))
    for (a, b, d) in icosa(sub):
        cen = G.norm(G.add(G.add(a, b), d))
        if cen[2] < zmin:
            continue
        pts = [G.add(c, G.mul(q, R)) for q in retreci([a, b, d], gap)]
        top = [G.add(p, G.mul(cen, ep)) for p in pts]
        lot.put(mats[rnd.i(0, len(mats) - 1)], tri3(top, pts))
    return c


def parabole(lot, Mint, Mdos, Mbras, Mcornet, c, n, R, f=1.0, nerv=14):
    """Parabole de centre c (fond de la coupe) et d'axe n : coupe, nervures radiales, couronnes, source à 4 bras."""
    h = lambda r_: r_ * r_ / (4.0 * f)
    prof_i = [(h(r_), r_) for r_ in [R * i / 12.0 for i in range(13)]]
    tons = Mint if isinstance(Mint, (list, tuple)) else [Mint]
    for k in range(nerv):                                # secteurs de tons voisins : la coupe n'est pas un aplat
        lot.put(tons[(k * 5 + k // 3) % len(tons)], G.oriente(G.tour(prof_i, 8, "z", a0=TAU * k / nerv, a1=TAU * (k + 1) / nerv), c, n))
    lot.put(Mdos, G.oriente(G.tour([(p[0] - 0.06, p[1]) for p in reversed(prof_i)], 48, "z"), c, n))
    lot.put(Mbras, G.oriente(G.tour([(h(R) - 0.05, R), (h(R) + 0.02, R + 0.03), (h(R) + 0.04, R)], 48, "z"), c, n))
    for k in range(nerv):
        a = TAU * k / nerv
        arc = [(r_ * math.cos(a), r_ * math.sin(a), h(r_) + 0.012) for r_ in [R * (0.14 + 0.86 * i / 8.0) for i in range(9)]]
        lot.put(Mbras, G.oriente(G.tube(arc, 0.012, 4), c, n))
    for rf in (0.42, 0.72):
        r_ = R * rf
        lot.put(Mbras, G.oriente(G.tour([(h(r_) + 0.004, r_ - 0.02), (h(r_) + 0.02, r_), (h(r_) + 0.004, r_ + 0.02)], 48, "z"), c, n))
    foy = G.add(c, G.mul(G.norm(n), f))
    for k in range(4):
        a = TAU * k / 4 + 0.6
        q = G.oriente(([(R * 0.72 * math.cos(a), R * 0.72 * math.sin(a), h(R * 0.72))], [], []), c, n)[0][0]
        lot.put(Mbras, G.tube([q, foy], 0.018, 5))
    lot.put(Mcornet, G.oriente(G.tour([(-0.18, 0.05), (0.0, 0.09), (0.06, 0.09), (0.09, 0.0)], 12, "z"), foy, n))
    return foy


def fouet(lot, Mt, Ml, base, h, r0=0.045, r1=0.009, barres=(), Mcol=None):
    """Antenne fouet : tige effilée, embase, barres de loin en loin, feu au sommet."""
    top = G.add(base, (0.0, 0.0, h))
    lot.put(Mt, tube_conique(base, top, r0, r1, 18, 6))
    lot.put(Mcol or Mt, G.tour([(base[2] - 0.02, r0 * 3.0), (base[2] + 0.06, r0 * 2.6), (base[2] + 0.1, r0 * 1.3)], 10, "z", (base[0], base[1], 0.0)))
    for (t, w) in barres:
        q = G.add(base, (0.0, 0.0, h * t))
        lot.put(Mt, G.tube([G.add(q, (-w, 0.0, 0.0)), G.add(q, (w, 0.0, 0.0))], 0.009, 4))
    if Ml is not None:
        lot.put(Ml, G.sphere(top, r1 * 3.2, 6, 3))
    return top


def pied_tele(lot, M1, M2, Mband, Mpad, top, r=0.15):
    """Pied télescopique : semelle, 3 étages emboîtés, collier, vérin latéral."""
    x, y, zt = top
    c = (x, y, 0.0)
    lot.put(Mpad, G.tour([(0.0, r * 2.5), (0.05, r * 2.45), (0.09, r * 1.7), (0.13, r * 1.45)], 8, "z", c, cap1=True))
    z1, z2 = zt * 0.5, zt * 0.78
    lot.put(M1, G.tour([(0.1, r), (z1, r), (z1 + 0.02, r * 1.2), (z1 + 0.07, r * 1.2), (z1 + 0.08, r * 0.76)], 14, "z", c))
    lot.put(M2, G.tour([(z1, r * 0.74), (z2, r * 0.74), (z2 + 0.02, r * 0.9), (z2 + 0.06, r * 0.9), (z2 + 0.07, r * 0.52)], 12, "z", c))
    lot.put(M2, G.tour([(z2, r * 0.5), (zt + 0.05, r * 0.5)], 10, "z", c))
    if z1 > 0.25:
        lot.put(Mband, G.tour([(z1 - 0.1, r * 1.03), (z1 - 0.02, r * 1.03)], 14, "z", c))
    lot.put(M2, G.tube([(x - r * 1.3, y - r * 0.5, 0.14), (x - r * 1.3, y - r * 0.5, z2)], r * 0.17, 5))
    lot.put(M1, G.tube([(x - r * 1.3, y - r * 0.5, 0.14), (x - r * 1.3, y - r * 0.5, z1)], r * 0.27, 5))


def pied_v(lot, Ms, Mpad, Mband, foot, a, b, r=0.075):
    """Pied en V : semelle, deux bras effilés vers a et b, entretoise, repère."""
    x, y = foot
    lot.put(Mpad, G.tour([(0.0, 0.36), (0.05, 0.34), (0.1, 0.2), (0.14, 0.16)], 6, "z", (x, y, 0.0), cap1=True))
    o = (x, y, 0.13)
    for q in (a, b):
        lot.put(Ms, tube_conique(o, q, r * 1.25, r * 0.7, 12, 6))
        lot.put(Mband, tube_conique(G.lerp(o, q, 0.3), G.lerp(o, q, 0.36), r * 1.3, r * 1.25, 3, 6))
    lot.put(Ms, G.tube([G.lerp(o, a, 0.55), G.lerp(o, b, 0.55)], r * 0.45, 5))


def aileron(lot, M, Mpan, Mbord, Ml, a, b, tip, rnd, ep=0.06):
    """Aileron triangulaire : a et b à l'emplanture, tip à la pointe ; panneau rapporté, bord d'attaque, ligne de lumière."""
    lot.put(M, plan3([a, b, tip], ep))
    n = G.norm(G.cross(G.sub(b, a), G.sub(tip, a)))
    for sg in (1, -1):
        p = [G.add(q, G.mul(n, sg * (ep / 2 + 0.006))) for q in retreci([a, b, tip], 0.6)]
        lot.put(Mpan, plan3(p, 0.012))
    lot.put(Mbord, tube_conique(a, tip, 0.03, 0.012, 10, 5))
    if Ml is not None:
        chenillard(lot, Ml, G.lerp(b, tip, 0.05), G.lerp(b, tip, 0.9), rnd, r=0.014)


def joints_dome(lot, M, c, R, zb, n=9, rj=0.009, cer=(0.55, 1.0)):
    """Méridiens et cerces d'un dôme lisse de rayon R posé à la cote zb, centre c (x, y)."""
    for k in range(n):
        a = TAU * k / n + 0.2
        arc = [(c[0] + (R + 0.006) * math.cos(t) * math.cos(a), c[1] + (R + 0.006) * math.cos(t) * math.sin(a), zb + (R + 0.006) * math.sin(t)) for t in [0.05 + 1.3 * i / 9.0 for i in range(10)]]
        lot.put(M, G.tube(arc, rj, 4))
    for t in cer:
        rr = (R + 0.006) * math.cos(t)
        lot.put(M, G.tour([(zb + (R + 0.006) * math.sin(t) - rj, rr), (zb + (R + 0.006) * math.sin(t) + rj, rr)], 40, "z", (c[0], c[1], 0.0)))


def anneau(lot, M, c, R, er, ez, segs=72):
    """Anneau horizontal à section rectangulaire arrondie, centre c."""
    x, y, z = c
    prof = [(z - ez, R - er), (z - ez, R + er * 0.7), (z - ez * 0.6, R + er), (z + ez * 0.6, R + er), (z + ez, R + er * 0.7), (z + ez, R - er), (z - ez, R - er)]
    lot.put(M, G.tour(prof, segs, "z", (x, y, 0.0)))


def arc_lum(lot, Ml, c, R, h, a0, a1, segs=24):
    x, y, z = c
    lot.put(Ml, G.tour([(z - h, R), (z + h, R)], segs, "z", (x, y, 0.0), a0=a0, a1=a1))


# ================================================================================================ sol, réseaux
def debris_sol(lot, M, r, n, xr, yr, zone_libre, cles=("acier", "capot2")):
    for k in range(n):
        x, y = r.f(*xr), r.f(*yr)
        if zone_libre(x, y):
            continue
        m = M[cles[k % len(cles)]]
        if r.f() < 0.55:
            lot.put(m, G.boite((x, y, 0.02), (r.f(0.08, 0.22), r.f(0.05, 0.13), 0.03), r.f(0, 3.0), r.f(-0.25, 0.25)))
        else:
            lot.put(M["acier"], G.boite((x, y, 0.03), (r.f(0.25, 0.5), 0.04, 0.04), r.f(0, 3.0)))


def cale(lot, M, x, y, sz, rz, marque=None):
    """Conteneur de service, couvercle et repère."""
    lot.put(M, G.boite((x, y, sz / 2), (sz, sz * 0.8, sz), rz))
    lot.put(M, G.boite((x, y, sz + 0.012), (sz * 1.04, sz * 0.84, 0.024), rz))
    if marque is not None:
        q = G.rot_z((0.0, -sz * 0.41, 0.0), rz)
        lot.put(marque, G.boite((x + q[0], y + q[1], sz * 0.55), (sz * 0.7, 0.012, sz * 0.14), rz))


def touret(lot, Mj, Mc, x, y, R=0.2, w=0.18):
    """Touret de câble posé sur champ."""
    lot.put(Mj, G.tour([(y - w, R), (y - w + 0.025, R)], 16, "y", (x, 0.0, R), cap0=True, cap1=True))
    lot.put(Mj, G.tour([(y + w - 0.025, R), (y + w, R)], 16, "y", (x, 0.0, R), cap0=True, cap1=True))
    lot.put(Mc, G.tour([(y - w, R * 0.72), (y + w, R * 0.72)], 16, "y", (x, 0.0, R)))


# ================================================================================================ reprise du 1/11 : continuité
# Critique du 1/11 : la chaîne du vaisseau cassait aux âges 10 à 12. Même fuselage posé bas sur ses berceaux, nacelles et
# crâne qui gardent le jaune d'origine, et la même dalle à gradins que les âges 13 à 15 (stellaire.terrasses, 16×8 ramené à 14×7).
POSE_BASSE = dict(T=(0.0, 0.85, 1.62), lacet=-0.105, tangage=0.04, roulis=0.17)
TERRASSES14 = [
    ([(-6.9, -3.1), (-6.5, -4.1), (-4.0, -4.15), (-3.7, -3.2), (-6.6, -2.75)], 0.3),
    ([(-3.5, -4.45), (2.9, -4.45), (3.05, -3.3), (2.1, -2.95), (-2.4, -2.95), (-3.4, -3.2)], 0.14),
    ([(3.3, -4.2), (6.4, -3.9), (6.9, -2.7), (3.4, -3.25)], 0.36),
    ([(-6.95, -2.6), (-6.3, -2.5), (-6.2, 2.2), (-6.95, 2.25)], 0.22),
    ([(-6.9, 2.35), (-5.8, 2.55), (-3.2, 2.95), (-3.3, 4.0), (-6.6, 4.0)], 0.42),
    ([(-2.9, 3.0), (1.8, 3.0), (1.95, 4.1), (-2.8, 4.1)], 0.28),
    ([(2.2, 2.1), (6.1, 1.7), (6.9, 2.6), (6.2, 4.1), (2.3, 4.1)], 0.34),
    ([(-6.1, -2.5), (-3.4, -2.85), (3.3, -2.85), (6.3, -2.5), (6.3, 1.6), (2.0, 2.85), (-3.1, 2.85), (-6.1, 2.2)], 0.1),
]


def _sc(poly, k):
    cx, cy = sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly)
    return [(cx + (p[0] - cx) * k, cy + (p[1] - cy) * k) for p in poly]


def terrasses(lot, M, r, liste=TERRASSES14, fentes=24):
    """Dalle à gradins, même recette que les âges 13 à 15 : pied sombre, dessus de pierre à joints, liseré au bord sud,
    plus des trappes et des goulottes (un sol vide se lit « bande de terre »)."""
    lot.xf = None
    for (poly0, h) in liste:
        poly = _sc(poly0, 0.97)
        lot.put(M["pierre2"], G.prisme(poly, 0.0, h - 0.06, top_scale=0.985))
        lot.put(M["pierre"], G.prisme(_sc(poly, 0.97), h - 0.06, h, top_scale=0.985))
        n = len(poly)
        best = min(range(n), key=lambda i: poly[i][1] + poly[(i + 1) % n][1])
        a, b = poly[best], poly[(best + 1) % n]
        lot.put(M["bande"], G.boite(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, h - 0.03), (math.hypot(b[0] - a[0], b[1] - a[1]) * 0.9, 0.06, 0.04),
                                    rz=math.atan2(b[1] - a[1], b[0] - a[0])))
    for k in range(fentes):
        x, y = r.f(-6.0, 6.0), r.f(-2.7, 2.6)
        w, l, rz = r.f(0.2, 0.5), r.f(0.14, 0.34), r.f(-0.1, 0.1)
        lot.put(M["acier"], G.boite((x, y, 0.115), (w, l, 0.03), rz))
        lot.put(M["noyau"], G.boite((x, y, 0.132), (w * 0.8, l * 0.7, 0.006), rz))


def butte_nez(lot, M, P, r):
    """Le nez reste planté dans sa butte, comme de l'âge 0 à l'âge 15."""
    lot.xf = None
    nez = P.xf((5.0, 0.0, -0.3))
    lot.put(M["terre"], G.butte_polaire((nez[0] + 0.2, nez[1] - 0.05, 0.0), 0.95, 1.3, 0.42, r, 12, 48, 0.3, 0.14))


def ventre(lot, M, P, mc, r):
    """Le ventre du vaisseau, le même aux 3 âges : la coque continue sous la cage ; rend la surface."""
    lot.xf = None
    fv = surf_fuseau(P.niv((0.25, -0.08, 0.0)), 5.8, 3.1, 0.98, 1.46, P.lacet)
    C.noyau(lot, M["noyau"], fv, -2.88, 2.88, 0.0, TAU)
    C.blindage(lot, fv, -2.86, 2.86, -0.5, math.pi + 0.5, mc, r, Mriv=M["riv"], **LISSE)
    C.blindage(lot, fv, -2.86, 2.86, math.pi + 0.5, TAU - 0.5, lambda rr, xm, am: M["noyau"], r, Mriv=None, **LISSE2)
    return fv


def derive_ailes(lot, M, P, t):
    """Dérive et ailes D'ORIGINE, gainées (critique : la dérive ne se refait pas). t : clés (base, sombre, jaune, second, voyant)."""
    lot.xf = P.xf
    z0, z1 = C.z_dessus(-2.4), C.z_dessus(-3.45)
    lot.put(M[t[0]], C.prisme_plan([(-2.3, z0 - 0.05), (-3.25, z0 + 1.8), (-3.95, z0 + 1.86), (-3.5, z1 - 0.05)], 0.09))
    for (poly, m, y) in (([(-2.55, z0 + 0.35), (-3.1, z0 + 1.2), (-3.55, z0 + 1.2), (-3.4, z0 + 0.35)], t[1], 0.05),
                         ([(-3.13, z0 + 1.25), (-3.28, z0 + 1.5), (-3.75, z0 + 1.5), (-3.62, z0 + 1.25)], t[2], 0.05),
                         ([(-2.6, z0 + 0.35), (-3.0, z0 + 0.95), (-3.3, z0 + 0.95), (-3.2, z0 + 0.35)], t[3], -0.05)):
        lot.put(M[m], C.prisme_plan(poly, 0.025, y0=y))
    lot.put(M["chevron"], C.prisme_plan([(-3.27, z0 + 1.55), (-3.33, z0 + 1.72), (-3.93, z0 + 1.76), (-3.86, z0 + 1.55)], 0.11))
    lot.put(M["acier"], G.tube([(-2.3, 0.0, z0 - 0.05), (-3.25, 0.0, z0 + 1.8)], 0.05, 8))
    lot.put(M[t[4]], G.sphere((-3.6, 0.0, z0 + 1.92), 0.04, 8, 4))
    lot.put(M["acier"], G.tube([(-3.5, 0.0, z0 + 1.86), (-3.6, 0.0, z0 + 2.45)], 0.014, 5))

    def aile(s, pts, zr, di, m):
        poly = pts if s > 0 else list(reversed(pts))
        v, f, u = G.prisme(poly, -0.05, 0.05)
        yr_ = pts[0][1]
        sh_ = lambda q: (q[0], q[1], q[2] + zr + abs(q[1] - yr_) * di)
        lot.put(M[m], ([sh_(q) for q in v], f, u))
        return sh_
    yr = 1.88
    sh = aile(1, [(-2.65, yr), (-4.55, yr), (-5.3, 3.55), (-4.5, 3.6)], -0.42, 0.24, t[3])
    BA = lambda u: (-2.65 + (-4.5 + 2.65) * u - 0.07, yr + (3.6 - yr) * u)
    BF = lambda u: (-4.55 + (-5.3 + 4.55) * u + 0.1, yr + (3.55 - yr) * u)
    for (a0, a1, m, f0, f1) in ((0.04, 0.4, t[0], 0.0, 0.55), (0.04, 0.33, t[1], 0.6, 1.0), (0.42, 0.66, t[2], 0.0, 1.0), (0.68, 0.96, t[0], 0.0, 0.7)):
        def pt(u, f):
            a, b = BA(u), BF(u)
            return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
        v, f_, u_ = G.prisme([pt(a0, f0), pt(a1, f0), pt(a1, f1), pt(a0, f1)], 0.05, 0.075)
        lot.put(M[m], ([sh(q) for q in v], f_, u_))
    lot.put(M["chevron"], G.tube([sh((-4.52, 3.55, 0.06)), sh((-5.28, 3.5, 0.06))], 0.05, 6))
    lot.put(M["acier"], G.tube([sh((-2.65, yr, 0.06)), sh((-4.5, 3.6, 0.06))], 0.04, 6))
    lot.put(M[t[4]], G.sphere(sh((-4.9, 3.58, 0.1)), 0.035, 6, 3))
    aile(-1, [(-2.7, -yr), (-4.0, -yr), (-4.25, -2.55), (-3.15, -2.62)], -0.42, 0.24, t[3])


def grilles_coque(lot, M, P):
    lot.xf = P.xf
    sc = C.surf_coque
    for (x, a, w, l) in ((3.0, TOP - 0.7, 0.32, 0.4), (3.9, TOP + 0.95, 0.26, 0.36), (-2.9, TOP + 0.2, 0.3, 0.5), (-2.6, TOP + 1.0, 0.24, 0.42)):
        p, n = C.point(x, a, 0.07), C.normale_s(sc, x, a)
        lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (l + 0.06, w + 0.06, 0.04)), p, n))
        lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.015), (l, w, 0.03)), p, n))
        for k in range(6):
            lot.put(M["acier"], C.pose_plane(G.boite((-l / 2 + l * (k + 0.5) / 6, 0, 0.035), (l / 6 * 0.45, w, 0.025)), p, n))


def passerelle(lot, Mp, Mg, a, b, w):
    """Passerelle étroite à garde-corps, de a à b (le pont entre un bâtiment et le fuselage)."""
    lot.put(Mp, plan3([(a[0] - w, a[1], a[2]), (a[0] + w, a[1], a[2]), (b[0] + w, b[1], b[2]), (b[0] - w, b[1], b[2])], 0.04))
    for sg in (-1, 1):
        lot.put(Mg, G.tube([(a[0] + sg * w, a[1], a[2] + 0.3), (b[0] + sg * w, b[1], b[2] + 0.3)], 0.012, 4))
        for t in (0.0, 0.33, 0.66, 1.0):
            q = G.lerp((a[0] + sg * w, a[1], a[2]), (b[0] + sg * w, b[1], b[2]), t)
            lot.put(Mg, G.tube([q, G.add(q, (0, 0, 0.3))], 0.009, 4))
