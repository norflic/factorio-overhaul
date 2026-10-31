"""CARCASSE du centre-vaisseau, refonte QG (30/10) : forme refaite de zéro, outillage de vaisseau_o gardé (geo, mat).

Différences avec vaisseau.py (cigare jeté) :
- une POSE : l'axe du vaisseau est tourné (nez vers le sud-est), roulé (le dos montré à la caméra) et cabré (nez dans
  la boue, queue relevée sur ses étais) ; les parties de carcasse sont modélisées dans le repère du vaisseau puis
  posées par Pose.xf ; les bâtiments, eux, restent de niveau (Pose.niv : lacet seul) ;
- des tôles IRRÉGULIÈRES (largeurs et arcs tirés, coins relevés, doublures) au lieu de bandes à pas constant ;
- des côtes BALAYÉES vers la queue (piège n° 1 d'OPUS : une côte dans un plan x = constante est un trait vertical) ;
- des tuyères CANTÉES (cloches relevées et ouvertes vers la caméra : l'intérieur noir se voit, comme au vanilla).
Repère local : x le long de l'axe (nez vers +x), y à gauche (nord quand la pose est nulle), z vers le haut ;
angle a de section : a = 0 côté +y, a = pi/2 dessus, a = pi côté -y (sud), 3pi/2 dessous.
"""
import math

import geo as G

X_QUEUE, X_NEZ = -3.5, 5.55
X_CRANE = 2.25
NEXPO = 3.0


class Pose:
    """Repère du vaisseau -> monde. T = position de l'axe (x, y monde ; z hauteur de l'axe en x = 0)."""

    def __init__(self, T=(0.0, 0.6, 1.62), lacet=-0.12, tangage=0.075, roulis=0.16):
        self.T, self.lacet, self.tangage, self.roulis = T, lacet, tangage, roulis

    def xf(self, p):
        p = G.rot_x(p, self.roulis)
        p = G.rot_y(p, self.tangage)
        p = G.rot_z(p, self.lacet)
        return (p[0] + self.T[0], p[1] + self.T[1], max(0.0, p[2] + self.T[2]))

    def niv(self, p):
        """Bâtiments : de niveau, alignés sur l'axe (lacet seul) ; z absolu."""
        q = G.rot_z((p[0], p[1], 0.0), self.lacet)
        return (q[0] + self.T[0], q[1] + self.T[1], max(0.0, p[2]))

    def compose(self, f):
        return lambda p: self.xf(f(p))


# ------------------------------------------------------------------------------------------------ coque
def profil(x):
    """(zc, demi-largeur, haut, bas, exposant) de la section à l'abscisse x (repère local)."""
    zc, w, ht, hb, n = 0.0, 1.32, 1.12, 0.98, NEXPO
    if x > X_CRANE:                                  # crâne : ogive anguleuse, bec qui plonge
        t = min(1.0, (x - X_CRANE) / (X_NEZ - X_CRANE))
        f = math.sqrt(max(0.0, 1.0 - t ** 1.5))
        w = 0.1 + (w - 0.1) * f
        ht = 0.07 + (ht - 0.07) * max(0.0, 1.0 - t ** 1.25) ** 0.8
        hb = 0.1 + (hb - 0.1) * f
        zc = -0.28 * t * t
        n = NEXPO - 0.7 * t
    elif x < -2.3:
        t = min(1.0, (-2.3 - x) / (-2.3 - X_QUEUE))
        w -= 0.28 * t
        ht -= 0.22 * t
        hb -= 0.15 * t
    return zc, w, ht, hb, n


def point(x, a, g=0.0):
    zc, w, ht, hb, n = profil(x)
    c, s = math.cos(a), math.sin(a)
    e = 2.0 / n
    y = (w + g) * math.copysign(abs(c) ** e, c)
    z = zc + ((ht if s > 0 else hb) + g) * math.copysign(abs(s) ** e, s)
    return (x, y, z)


def surf_coque(x, a, g):
    return point(x, a, g)


def normale_s(surf, x, a):
    p = surf(x, a, 0.0)
    q = surf(x, a + 0.01, 0.0)
    r = surf(x + 0.01, a, 0.0)
    n = G.norm(G.cross(G.sub(q, p), G.sub(r, p)))
    out = G.sub(surf(x, a, 0.1), p)
    return n if G.dot(n, out) > 0 else G.mul(n, -1.0)


def _arc(surf, x, a):
    return G.length(G.sub(surf(x, a + 0.01, 0.0), surf(x, a, 0.0))) / 0.01


def noyau(lot, M, surf, x0, x1, a0, a1, g=-0.004, pas=0.09):
    nx = max(2, int(abs(x1 - x0) / pas) + 1)
    na = max(3, int(abs(a1 - a0) * _arc(surf, (x0 + x1) / 2, (a0 + a1) / 2) / pas) + 1)
    rings = [[surf(x0 + (x1 - x0) * i / (nx - 1.0), a0 + (a1 - a0) * j / (na - 1.0), g) for j in range(na)] for i in range(nx)]
    lot.put(M, G.loft(rings, closed=False))


def plaque(surf, x0, x1, a0, a1, ep, leve=0.0, coin=0, pas=0.08):
    """Tôle épaisse posée sur la surface (bords biseautés par ses chants) ; leve > 0 relève un coin (tôle gondolée)."""
    nx = max(1, int(abs(x1 - x0) / pas))
    na = max(1, int(abs(a1 - a0) * _arc(surf, (x0 + x1) / 2, (a0 + a1) / 2) / pas))

    def gg(i, j):
        u, v = i / float(nx), j / float(na)
        if coin & 1:
            u = 1 - u
        if coin & 2:
            v = 1 - v
        return ep + leve * (u * v) ** 1.6
    xs = [x0 + (x1 - x0) * i / float(nx) for i in range(nx + 1)]
    As = [a0 + (a1 - a0) * j / float(na) for j in range(na + 1)]
    top = [[surf(xs[i], As[j], gg(i, j)) for j in range(na + 1)] for i in range(nx + 1)]
    out = G.loft(top, closed=False)
    bot = lambda x, a: surf(x, a, 0.0)
    bords = [G.loft([[bot(x0, a) for a in As], top[0]], closed=False),
             G.loft([top[-1], [bot(x1, a) for a in As]], closed=False),
             G.loft([[r[0] for r in top], [bot(x, a0) for x in xs]], closed=False),
             G.loft([[bot(x, a1) for x in xs], [r[-1] for r in top]], closed=False)]
    return G.merge(out, *bords)


def blindage(lot, surf, x0, x1, a0, a1, mats, rnd, larg=(0.32, 0.72), arcs=(0.28, 0.68), gap=0.024, ep=(0.022, 0.06),
             saut=None, Mriv=None, gondole=0.18, rivets=0.55):
    """Tôles IRRÉGULIÈRES entre x0 et x1, a0 et a1 : largeurs de bandes et arcs tirés, bords décalés, coins relevés,
    rivets (sombres, ton du blindage) sur une partie des bords transversaux seulement. mats(rnd, xm, am) -> matière ou
    None ; saut(xm, am) -> True retire la tôle (le noyau sombre ou ce qui est dessous se voit)."""
    sgn = 1.0 if x1 > x0 else -1.0
    xb = [x0]
    while abs(x1 - xb[-1]) > 1e-6:
        w = rnd.f(*larg)
        nx = xb[-1] + sgn * w
        if abs(x1 - nx) < larg[0] * 0.6 or (nx - x1) * sgn > 0:
            nx = x1
        xb.append(nx)
    for i in range(len(xb) - 1):
        xa, xc = xb[i], xb[i + 1]
        xm = (xa + xc) / 2
        L = abs(a1 - a0) * _arc(surf, xm, (a0 + a1) / 2)
        cuts = [0.0]
        acc = rnd.f(0.0, arcs[1] * 0.8)
        while acc < L - arcs[0] * 0.5:
            cuts.append(acc)
            acc += rnd.f(*arcs)
        cuts.append(L)
        cuts = sorted(set(cuts))
        for j in range(len(cuts) - 1):
            if cuts[j + 1] - cuts[j] < 0.06:
                continue
            aa = a0 + (a1 - a0) * cuts[j] / L
            ac = a0 + (a1 - a0) * cuts[j + 1] / L
            am = (aa + ac) / 2
            if saut and saut(xm, am):
                continue
            m = mats(rnd, xm, am)
            if m is None:
                continue
            da = gap / max(1e-3, _arc(surf, xm, am))
            gx = gap * sgn
            e = rnd.f(*ep)
            leve = rnd.f(0.04, 0.12) if rnd.f() < gondole else 0.0
            lot.put(m, plaque(surf, xa + gx / 2, xc - gx / 2, aa + da / 2, ac - da / 2, e, leve, rnd.i(0, 3)))
            if Mriv is not None and rnd.f() < rivets:
                arc = abs(ac - aa) * _arc(surf, xm, am)
                nr = max(2, int(arc / 0.13))
                pts = []
                xr = (xa + gx / 2 + 0.04 * sgn) if rnd.f() < 0.5 else (xc - gx / 2 - 0.04 * sgn)
                for q in range(nr):
                    a = aa + da + (ac - aa - 2 * da) * (q + 0.5) / nr
                    pts.append((surf(xr, a, e + 0.001), normale_s(surf, xr, a)))
                lot.put(Mriv, G.rivets_le_long(pts, 0.018, 0.012))


def bande(lot, surf, M, x0, x1, a0, a1, g, h, pas=0.08):
    """Bande en relief (cerclage, lisse) : loft de la surface décalée de g à g + h, avec chants."""
    lot.put(M, plaque(surf, x0, x1, a0, a1, g + h, 0.0, 0, pas))


# ------------------------------------------------------------------------------------------------ nacelles
def r_nacelle(x, R, x_av, x_ar):
    """Rayon de la nacelle (repère propre : axe x, entrée d'air en x_av, arrière en x_ar < x_av)."""
    if x > x_av - 0.4:
        t = max(0.0, min(1.0, (x - (x_av - 0.4)) / 0.4))
        return R * (1.0 - 0.38 * t * t)
    if x < x_ar + 0.35:
        t = min(1.0, (x_ar + 0.35 - x) / 0.35)
        return R * (1.0 - 0.12 * t)
    return R


def surf_nac(R, x_av, x_ar):
    return lambda x, a, g: (x, (r_nacelle(x, R, x_av, x_ar) + g) * math.cos(a), (r_nacelle(x, R, x_av, x_ar) + g) * math.sin(a))


def cloche(lot, Mext, Mint, Mbrule, Manneau, x_ar, R, L=0.95, prof=True):
    """Tuyère : cloche évasée, cerclée ; intérieur brûlé presque noir, anneaux concentriques et cône central (vanilla)."""
    out = [(x_ar + 0.03, R * 0.9), (x_ar - 0.1 * L, R * 0.82), (x_ar - 0.5 * L, R * 0.92), (x_ar - 0.88 * L, R * 1.14),
           (x_ar - L, R * 1.22), (x_ar - L - 0.04, R * 1.22)]
    inn = [(x_ar - L - 0.04, R * 1.13), (x_ar - L + 0.02, R * 1.09), (x_ar - 0.6 * L, R * 0.86), (x_ar - 0.22 * L, R * 0.7),
           (x_ar - 0.05, R * 0.64), (x_ar - 0.02, R * 0.3), (x_ar - 0.04, 0.0)]
    lot.put(Mext, G.tour(out, 32, "x"))
    lot.put(Mbrule, G.tour(inn, 32, "x"))
    for f, rr in ((0.12, 0.72), (0.38, 0.8), (0.66, 0.95)):          # anneaux de la gorge (lus en ellipses)
        xb = x_ar - f * L
        lot.put(Mint, G.tour([(xb - 0.025, rr * R - 0.005), (xb, rr * R - 0.05), (xb + 0.025, rr * R - 0.005)], 32, "x"))
    lot.put(Mint, G.tour([(x_ar - 0.05, R * 0.34), (x_ar - 0.42 * L, R * 0.14), (x_ar - 0.5 * L, 0.0)], 20, "x"))  # cône
    for f in (0.32, 0.72, 0.97):                                      # cerclages extérieurs
        xb = x_ar - f * L
        rr = R * (0.86 + 0.36 * f * f)
        lot.put(Manneau, G.tour([(xb - 0.05, rr + 0.005), (xb - 0.045, rr + 0.06), (xb + 0.045, rr + 0.06), (xb + 0.05, rr + 0.005)],
                                32, "x"))


# ------------------------------------------------------------------------------------------------ côtes, épine
def point_cote(xt, a, g, balai, haut=0.0):
    """Arche elliptique d'une côte : x incliné vers la queue en descendant (balai), au-dessus de l'axe ; sous l'axe,
    elle suit la section de coque."""
    x = xt - balai * (1.0 - math.sin(a))
    zc, w, ht, hb, n = profil(x)
    s = math.sin(a)
    h = (ht if s > 0 else hb) + g + (haut * s ** 1.5 if s > 0 else 0.0)
    return (x, (w + g) * math.cos(a), zc + h * s)


def cote(lot, M, Mriv, xt, a0, a1, balai, g=0.07, ep=0.075, prof=0.24, aile=0.19, haut=0.0, m=40):
    """Côte en I (âme + deux semelles) balayée ; renvoie les deux extrémités (repère local) pour les jambes."""
    As = [a0 + (a1 - a0) * j / float(m - 1) for j in range(m)]

    def ring(dx, gg):
        return [G.add(point_cote(xt, a, gg, balai, haut), (dx, 0.0, 0.0)) for a in As]
    ame = [ring(-ep / 2, g), ring(ep / 2, g), ring(ep / 2, g - prof), ring(-ep / 2, g - prof)]
    lot.put(M, G.loft(ame + [ame[0]], closed=False))
    for gg in (g, g - prof + 0.04):                                  # semelles extérieure et intérieure
        sem = [ring(-aile / 2, gg + 0.04), ring(aile / 2, gg + 0.04), ring(aile / 2, gg), ring(-aile / 2, gg)]
        lot.put(M, G.loft(sem + [sem[0]], closed=False))
    if Mriv is not None:
        pts = []
        for j in range(2, m - 2, 2):
            for dx in (-aile * 0.32, aile * 0.32):
                p = G.add(point_cote(xt, As[j], g + 0.04, balai, haut), (dx, 0.0, 0.0))
                q = point_cote(xt, As[j], g + 0.2, balai, haut)
                pts.append((p, G.sub(q, point_cote(xt, As[j], g, balai, haut))))
        lot.put(Mriv, G.rivets_le_long(pts, 0.02, 0.014))
    return point_cote(xt, a0, g - prof / 2, balai, haut), point_cote(xt, a1, g - prof / 2, balai, haut)


def z_dessus(x):
    zc, w, ht, hb, n = profil(x)
    return zc + ht


# ------------------------------------------------------------------------------------------------ plans
def prisme_plan(poly, ep, plan="xz", y0=0.0):
    """Prisme sur un polygone convexe tracé dans le plan xz (dérive) ou xy (aile) ; épaisseur ep centrée sur y0/z0."""
    v, f, u = G.prisme(poly, y0 - ep / 2, y0 + ep / 2)
    if plan == "xz":
        v = [(p[0], p[2], p[1]) for p in v]
    return v, f, u


def tube_droit(a, b, r, segs=8):
    return G.tube([a, b], r, segs)


# ------------------------------------------------------------------------------------------------ tuyauterie
def tuyau(lot, M, Mbride, poly, r, rb=0.16, pas_bride=0.75, boulons=None):
    """Tuyau rigide à coudes arrondis, brides aux bouts, aux coudes et tous les pas_bride."""
    pts = G.coudee(poly, rb, 6)
    lot.put(M, G.tube(pts, r, 12))
    fr = G._frames(pts)
    acc, last = 0.0, -1e9
    for i, p in enumerate(pts):
        if i:
            acc += G.length(G.sub(p, pts[i - 1]))
        if i in (0, len(pts) - 1) or acc - last > pas_bride:
            b = G.tour([(-0.022, r * 1.5), (0.022, r * 1.5)], 12, "z", cap0=True, cap1=True)
            lot.put(Mbride, G.oriente(b, p, fr[i][0]))
            last = acc


def flexible(lot, M, ctrl, r, pas=0.045):
    pts = G.catmull(ctrl, 14)
    lot.put(M, G.tube(pts, r, 10, rfun=lambda s, i: r * (1.0 + 0.18 * math.cos(s * G.TAU / pas))))


def faisceau(lot, Mrouge, Mnoir, a, b, fl, n=3, r=0.012, ecart=0.03, rnd=None):
    """Faisceau de câbles pendants, rouges et noirs, flèches légèrement différentes."""
    for i in range(n):
        d = (0.0, (i - (n - 1) / 2.0) * ecart, 0.0)
        f = fl * (1.0 + 0.12 * i) + (rnd.f(-0.03, 0.03) if rnd else 0.0)
        lot.put(Mrouge if i % 2 == 0 else Mnoir, G.tube(G.chainette(G.add(a, d), G.add(b, d), f, 18), r, 6))


def pose_plane(mesh, p, n):
    """Pose une maille plane (X local le long de +X monde projeté, Y local vers le haut de la surface, Z = n)."""
    n = G.norm(n)
    ex = G.norm(G.sub((1.0, 0.0, 0.0), G.mul(n, n[0])))
    ey = G.cross(n, ex)
    if ey[2] < 0:
        ey = G.mul(ey, -1.0)
        ex = G.mul(ex, -1.0)
    v, f, u = mesh
    return [G.add(p, G.add(G.add(G.mul(ex, q[0]), G.mul(ey, q[1])), G.mul(n, q[2]))) for q in v], f, u


def hublot(lot, forme, Mcadre, Mv, p, n, r=0.08):
    """Hublots tous différents : rond à bride boulonnée, carré à coins, ovale, à barreaux, double, octogone."""
    if forme == "rond":
        lot.put(Mcadre, G.oriente(G.tour([(0.0, r * 1.5), (0.03, r * 1.42), (0.04, r * 1.05), (0.02, r * 0.95)], 16, "z"), p, n))
        lot.put(Mv, G.oriente(G.tour([(0.02, r * 0.98), (0.026, 0.0)], 16, "z"), p, n))
        pts = [(G.oriente(([(r * 1.25 * math.cos(t), r * 1.25 * math.sin(t), 0.035)], [], []), p, n)[0][0], n)
               for t in [G.TAU * i / 8 for i in range(8)]]
        lot.put(Mcadre, G.rivets_le_long(pts, 0.012, 0.01))
    elif forme == "octo":
        lot.put(Mcadre, G.oriente(G.tour([(0.0, r * 1.45), (0.035, r * 1.4), (0.045, r * 1.0), (0.02, r * 0.95)], 8, "z"), p, n))
        lot.put(Mv, G.oriente(G.tour([(0.02, r * 0.98), (0.028, 0.0)], 8, "z"), p, n))
    elif forme == "carre":
        lot.put(Mcadre, pose_plane(G.boite((0, 0, 0.015), (r * 2.6, r * 2.2, 0.05)), p, n))
        lot.put(Mv, pose_plane(G.boite((0, 0, 0.03), (r * 1.9, r * 1.5, 0.04)), p, n))
        lot.put(Mcadre, pose_plane(G.boite((0, 0, 0.045), (0.02, r * 1.5, 0.03)), p, n))
    elif forme == "ovale":
        v, f, u = G.tour([(0.0, r * 1.4), (0.03, r * 1.3), (0.04, r * 1.0), (0.02, r * 0.92)], 16, "z")
        lot.put(Mcadre, G.oriente(([(q[0] * 1.6, q[1], q[2]) for q in v], f, u), p, n))
        v, f, u = G.tour([(0.02, r * 0.95), (0.026, 0.0)], 16, "z")
        lot.put(Mv, G.oriente(([(q[0] * 1.6, q[1], q[2]) for q in v], f, u), p, n))
    elif forme == "barreaux":
        lot.put(Mcadre, G.oriente(G.tour([(0.0, r * 1.5), (0.03, r * 1.4), (0.04, r * 1.05), (0.02, r * 0.95)], 16, "z"), p, n))
        lot.put(Mv, G.oriente(G.tour([(0.02, r * 0.98), (0.026, 0.0)], 16, "z"), p, n))
        for d in (-0.45, 0.0, 0.45):
            lot.put(Mcadre, pose_plane(G.boite((d * r, 0, 0.045), (0.016, r * 2.0, 0.02)), p, n))
    else:  # "double" : deux petits ronds dans une plaque
        lot.put(Mcadre, pose_plane(G.boite((0, 0, 0.012), (r * 3.6, r * 1.8, 0.04)), p, n))
        for d in (-0.85, 0.85):
            q = G.add(p, G.mul(G.norm(G.sub((1.0, 0.0, 0.0), G.mul(G.norm(n), G.norm(n)[0]))), d * r))
            lot.put(Mv, G.oriente(G.tour([(0.03, r * 0.62), (0.036, 0.0)], 12, "z"), q, n))


def evente(lot, M, Mfente, c, w, l, n=6, rz=0.0, h=0.12):
    """Évent à volets (caisson et lames inclinées) posé sur un toit ou un pont."""
    x, y, z = c
    lot.put(M, G.boite((x, y, z + h / 2), (l, w, h), rz))
    lot.put(Mfente, G.boite((x, y, z + h + 0.005), (l * 0.86, w * 0.84, 0.012), rz))
    for i in range(n):
        q = G.rot_z((-l * 0.43 + l * 0.86 * (i + 0.5) / n, 0.0, 0.0), rz)
        lot.put(M, G.boite((x + q[0], y + q[1], z + h + 0.02), (l * 0.86 / n * 0.55, w * 0.84, 0.025), rz, 0.0, 0.5))
