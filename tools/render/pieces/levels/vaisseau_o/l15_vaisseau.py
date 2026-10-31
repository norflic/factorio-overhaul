"""ÂGE 15 (Légende) : la CARCASSE du vaisseau, refaite de zéro (lot QG, 30/10 ; vaisseau.py, le cigare, n'est plus
utilisé). Repère local du vaisseau : X le long de l'axe, NEZ vers +X (la droite de l'écran), tuyères vers −X ; la pose
(lacet de −8° nez vers le sud-est, roulis qui montre le dos) est appliquée par la transformation `xf` reçue.

Carcasse commune (brief QG §3) : crâne à chevrons et verrière, épine, côtes inclinées vers la queue, 2 tuyères, dérive,
cœur-réacteur à nu (foyer fort). Ce qui reste de PEAU (10 % à l'âge 15) : le crâne, les nacelles et la dérive.
"""
import math

import geo as G
import greb as R

E = 2.0 / 1.6          # exposant des sections : < 1 sur les diagonales = section en losange aplati (coin, pas cigare)
CX0, CX1 = 3.05, 7.3    # crâne
NAC_Y, NAC_X0, NAC_X1 = 1.5, -3.45, -6.95


def _sg(v, e):
    return math.copysign(abs(v) ** e, v)


def crane_sect(x, zs):
    """Crâne en COIN : front haut (arcade) vers t = 0,25, puis bec qui plonge en pointe ; largeur qui fond en V."""
    t = min(1.0, max(0.0, (x - CX0) / (CX1 - CX0)))
    w = 0.06 + 1.25 * (1.0 - t) ** 0.85
    front = math.exp(-((t - 0.22) / 0.2) ** 2)
    ht = 0.06 + (1.15 + 0.35 * front) * (1.0 - t ** 1.25) ** 0.8
    hb = 0.08 + 0.95 * (1.0 - t ** 1.6) ** 0.7
    zc = zs - 0.05 - 0.6 * t ** 1.5
    return zc, w, ht, hb


def crane_pt(zs):
    def f(x, a, g=0.0):
        zc, w, ht, hb = crane_sect(x, zs)
        c, s = math.cos(a), math.sin(a)
        return (x, (w + g) * _sg(c, E), zc + ((ht if s > 0 else hb) + g) * _sg(s, E))
    return f


def nac_r(x):
    """Rayon de la nacelle : capot d'entrée d'air, corps, col, puis cloche de tuyère évasée."""
    pts = [(-3.45, 0.62), (-3.75, 0.9), (-4.1, 0.98), (-5.5, 0.95), (-5.85, 0.8), (-6.1, 0.82), (-6.6, 1.0), (-6.95, 1.1)]
    for i in range(1, len(pts)):
        x0, r0 = pts[i - 1]
        x1, r1 = pts[i]
        if x1 <= x <= x0:
            return r0 + (r1 - r0) * (x0 - x) / (x0 - x1)
    return pts[0][1] if x > pts[0][0] else pts[-1][1]


def nac_pt(s, zs):
    cz = zs - 0.05

    def f(x, a, g=0.0):
        r = nac_r(x) + g
        return (x, s * NAC_Y + r * math.cos(a), cz + r * math.sin(a))
    return f


def patch(surf, x0, x1, a0, a1, g, nx=4, na=6):
    rings = []
    for i in range(nx + 1):
        x = x0 + (x1 - x0) * i / nx
        rings.append([surf(x, a0 + (a1 - a0) * j / na, g) for j in range(na + 1)])
    return G.loft(rings, closed=False)


def coque(surf, xs, na=32, g=0.0, a0=0.0, a1=G.TAU):
    closed = abs(a1 - a0 - G.TAU) < 1e-9
    n = na if closed else na + 1
    rings = [[surf(x, a0 + (a1 - a0) * j / na, g) for j in range(n)] for x in xs]
    return G.loft(rings, closed=closed)


def blinde(lot, surf, xs, bandes, mats, rnd, xf, saut=None, g=(0.025, 0.06), gap=0.022, Mriv=None):
    """Plaques de blindage sur une surface : bords décalés d'une bande à l'autre (gigue), jours sombres de `gap`,
    rivets sur les bords transversaux ; `saut(xm, am)` laisse des trous (brèches, verrière)."""
    for bi, (a0, a1) in enumerate(bandes):
        xx = list(xs)
        if bi % 2:
            xx = [xx[0]] + [(xx[i] + xx[i + 1]) / 2 + rnd.f(-0.12, 0.12) for i in range(len(xx) - 1)] + [xx[-1]]
            xx = sorted(set(xx))
        for i in range(len(xx) - 1):
            x0, x1 = xx[i], xx[i + 1]
            if x1 - x0 < 0.08:
                continue
            xm, am = (x0 + x1) / 2, (a0 + a1) / 2
            if saut and saut(xm, am):
                continue
            gg = rnd.f(*g)
            p0 = surf(xm, a0)
            p1 = surf(xm, a1)
            da = gap / max(0.2, G.length(G.sub(p1, p0))) * (a1 - a0)
            lot.put(mats(rnd, bi, i), patch(surf, x0 + gap / 2, x1 - gap / 2, a0 + da / 2, a1 - da / 2, gg, 3, 5), xf)
            if Mriv is not None and rnd.f() < 0.6:
                pts = []
                for x in (x0 + 0.05, x1 - 0.05):
                    for k in range(3):
                        a = a0 + (a1 - a0) * (k + 0.5) / 3
                        p = surf(x, a, gg + 0.004)
                        n = G.norm(G.sub(surf(x, a, gg + 0.1), surf(x, a, gg)))
                        pts.append((p, n))
                lot.put(Mriv, G.rivets_le_long(pts, 0.017, 0.011), xf)
    R.compte("toles", len(bandes) * (len(xs) - 1))


def plaque_xz(poly, y0, y1):
    """Plaque définie dans le plan (x, z), épaisse de y0 à y1 (dérive, ailerons)."""
    v, f, u = G.prisme(poly, y0, y1)
    return [(p[0], p[2], p[1]) for p in v], f, u


def tore(c, Rr, m, axe=(0.0, 0.0, 1.0), nR=40, nm=8):
    ez = G.norm(axe)
    ref = (1.0, 0.0, 0.0) if abs(ez[0]) < 0.9 else (0.0, 1.0, 0.0)
    e1 = G.norm(G.cross(ref, ez))
    e2 = G.cross(ez, e1)
    rings = []
    for i in range(nR + 1):
        t = G.TAU * i / nR
        u = G.add(G.mul(e1, math.cos(t)), G.mul(e2, math.sin(t)))
        rings.append([G.add(c, G.add(G.mul(u, Rr + m * math.cos(G.TAU * j / nm)), G.mul(ez, m * math.sin(G.TAU * j / nm))))
                      for j in range(nm)])
    return G.loft(rings)


# ------------------------------------------------------------------------------------------------ crâne
def crane(lot, M, zs, rnd, xf):
    surf = crane_pt(zs)
    xs = [CX0 + (CX1 - CX0) * i / 26.0 for i in range(27)]
    lot.put(M["noyau"], coque(surf, xs, 36), xf)
    tip = surf(CX1, 0.0)
    lot.put(M["noyau"], G.sphere((CX1 - 0.02, 0.0, tip[2]), 0.12, 10, 5, zmin=-1.0), xf)

    def saut(xm, am):
        if 3.95 < xm < 5.25 and abs(am - math.pi / 2) < 0.52:      # verrière (courte, sous l'arcade du front)
            return True
        if 3.2 < xm < 4.1 and 3.3 < am < 3.9:                       # brèche du flanc sud : mécanique à nu
            return True
        return False

    def mats(rr, bi, i):
        x = rr.f()
        if bi in (2, 3, 4) and i >= 8:
            return M["chevron"]
        if x < 0.1:
            return M["bronze2"]
        if x < 0.16:
            return M["or_sombre"]
        return M["jaune"] if x < 0.7 else M["jaune2"]

    bandes = [(-0.35, 0.3), (0.3, 0.85), (0.85, 1.32), (1.32, 1.84), (1.84, 2.32), (2.32, 2.8), (2.8, 3.25), (3.25, 3.75),
              (3.75, 4.2)]
    xb0 = [CX0, 3.45, 3.9, 4.3, 4.68, 5.05, 5.4, 5.75, 6.05, 6.35, 6.62, 6.88, 7.1, CX1 - 0.06]
    xb = sorted(set(xb0 + [(xb0[i] + xb0[i + 1]) / 2 for i in range(len(xb0) - 1) if xb0[i + 1] - xb0[i] > 0.3]))
    blinde(lot, surf, xb, bandes, mats, rnd, xf, saut=saut, Mriv=M["riv"])
    # verrière : courte, raked, 2 × 2 vitres à cadre lourd d'or patiné (pas une grille de fenêtres)
    lot.put(M["verre"], patch(surf, 3.95, 5.25, math.pi / 2 - 0.5, math.pi / 2 + 0.5, 0.035, 6, 6), xf)
    for a in (math.pi / 2 - 0.52, math.pi / 2 + 0.04, math.pi / 2 + 0.52):
        lot.put(M["or"], G.tube([surf(x, a, 0.06) for x in (3.92, 4.3, 4.7, 5.0, 5.28)], 0.04, 6), xf)
    for x in (3.95, 4.62, 5.25):
        lot.put(M["or"], G.tube([surf(x, math.pi / 2 - 0.52 + 1.04 * j / 6, 0.06) for j in range(7)], 0.035, 6), xf)
    # chevrons du front : deux V en relief sur le dessus du bec
    for k, x in enumerate((6.6, 7.0)):
        for s in (-1, 1):
            p0, p1 = surf(x, math.pi / 2, 0.075), surf(x - 0.42, math.pi / 2 + s * 0.85, 0.075)
            lot.put(M["chevron"] if k else M["or_sombre"], G.tube([p0, p1], 0.05, 6), xf)
    # crête : lames dorsales décroissantes sur l'arête du crâne (continuent l'épine jusqu'au bec)
    for k, x in enumerate((3.35, 3.7, 5.55, 5.95, 6.35)):
        p = surf(x, math.pi / 2, 0.02)
        h = 0.42 - 0.06 * k
        lot.put(M["or_sombre"] if k % 2 else M["bronze"],
                G.prisme([(x - 0.16, -0.035), (x + 0.12, -0.035), (x + 0.02, 0.035), (x - 0.1, 0.035)], p[2] - 0.05, p[2] + h, top_scale=0.2,
                         top_shift=(-0.12, 0.0)), xf)
    # brèche du flanc sud : membrures et câbles à nu, foyer intérieur sombre
    for x in (3.3, 3.55, 3.8, 4.05):
        lot.put(M["bronze"], G.tube([surf(x, 3.3 + 0.12 * j, -0.04) for j in range(6)], 0.025, 5), xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], surf(3.25, 3.4, 0.02), surf(4.05, 3.75, 0.02), 0.22, rnd, n=5, rouges=2, xf=xf)
    R.flexible(lot, M["caoutchouc"], M["or_sombre"], [surf(3.3, 3.7, 0.0), surf(3.6, 3.95, 0.25), surf(4.0, 3.8, 0.05)], 0.05, xf=xf)
    # mandibules : plaques latérales sous le crâne, évents
    for s in (-1, 1):
        a = math.pi + 0.55 if s < 0 else -0.55
        p = surf(5.1, a, 0.09)
        n = G.norm(G.sub(surf(5.1, a, 0.4), p))
        R.grille(lot, M["bronze"], M["noyau"], p, n, 0.5, 0.26, 6, xf=xf)
    # hublots du crâne (3 formes)
    for x, a, f, t, lit in ((4.5, 2.45, "octo", 0.1, True), (5.45, 2.6, "fente", 0.07, False), (6.2, 2.45, "rond", 0.07, True)):
        p = surf(x, a, 0.07)
        n = G.norm(G.sub(surf(x, a, 0.4), p))
        R.hublot(lot, M["or_sombre"], M["lum"] if lit else M["verre"], p, n, f, t, xf=xf)
    # capteur (dôme à lentille) et 2 antennes sur le crâne
    p = surf(5.6, math.pi / 2 + 0.35, 0.05)
    lot.put(M["bronze"], G.tour([(0, 0.17), (0.08, 0.17), (0.12, 0.13)], 14, "z", (p[0], p[1], p[2])), xf)
    lot.put(M["verre"], G.sphere((p[0], p[1], p[2] + 0.1), 0.11, 12, 5, zmin=0.0), xf)
    for x, a, h in ((3.55, math.pi / 2 + 0.45, 0.9), (5.9, math.pi / 2 - 0.4, 0.55)):
        R.mat_antenne(lot, M["or_sombre"], M["bronze"], M["balise"], surf(x, a, 0.04), h, rnd, xf=xf, lum=h > 0.8)
    # tuyau et flexible sous le crâne (vers la halle)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [surf(3.1, 3.9, 0.12), surf(4.4, 3.95, 0.12), surf(5.2, 3.6, 0.12)], 0.05, xf=xf)


# ------------------------------------------------------------------------------------------------ nacelles
def nacelles(lot, M, zs, rnd, xf):
    for s in (-1, 1):
        surf = nac_pt(s, zs)
        xs = [NAC_X0 - (NAC_X0 - NAC_X1) * i / 24.0 for i in range(25)]
        lot.put(M["noyau"], coque(surf, xs, 28), xf)
        # cloche : intérieur brûlé (surface intérieure) et cône central
        cz = zs - 0.05
        lot.put(M["brule"], G.tour([(-6.94, 1.03), (-6.5, 0.86), (-6.1, 0.7), (-6.05, 0.3)], 24, "x", (0.0, s * NAC_Y, cz),
                                   cap1=True), xf)
        lot.put(M["bronze"], G.tour([(-6.15, 0.36), (-6.55, 0.22), (-6.75, 0.05)], 14, "x", (0.0, s * NAC_Y, cz)), xf)
        lot.put(M["or_sombre"], G.tour([(-6.92, 1.11), (-7.0, 1.14), (-7.0, 1.04), (-6.92, 1.03)], 28, "x", (0.0, s * NAC_Y, cz)), xf)

        def saut(xm, am, s=s):
            if xm < -5.88:
                return am > 0.0 and rnd.f() < 0.15
            return False

        def mats(rr, bi, i):
            x = rr.f()
            if i == 2 and bi in (1, 2):
                return M["chevron"]
            if x < 0.12:
                return M["bronze2"]
            return M["jaune"] if x < 0.68 else M["jaune2"]

        bandes = [(-0.4 + 0.415 * k, -0.4 + 0.415 * (k + 1)) for k in range(12)]
        blinde(lot, surf, [-3.5, -3.78, -4.05, -4.33, -4.6, -4.88, -5.15, -5.42, -5.65, -5.88], bandes, mats, rnd, xf, saut=saut, Mriv=M["riv"])
        blinde(lot, surf, [-6.1, -6.52, -6.92], bandes, lambda rr, bi, i: M["bronze"] if rr.f() < 0.7 else M["or_sombre"], rnd, xf)
        for x in (-3.95, -4.9, -5.88):                                  # cerclages d'or patiné
            r = nac_r(x) + 0.075
            lot.put(M["or"], G.tour([(x - 0.05, r), (x + 0.05, r)], 28, "x", (0.0, s * NAC_Y, cz)), xf)
        # entrée d'air : fond noir, grille radiale
        lot.put(M["noyau"], G.tour([(-3.42, 0.62), (-3.44, 0.0)], 20, "x", (0.0, s * NAC_Y, cz)), xf)
        for k in range(10):
            a = G.TAU * k / 10
            lot.put(M["bronze"], G.tube([(-3.4, s * NAC_Y, cz), (-3.4, s * NAC_Y + 0.6 * math.cos(a), cz + 0.6 * math.sin(a))], 0.022, 4), xf)
        R.compte("grilles")
        lot.put(M["or_sombre"], G.tour([(-3.36, 0.18), (-3.25, 0.1), (-3.2, 0.0)], 12, "x", (0.0, s * NAC_Y, cz)), xf)
        # tuyau le long de la nacelle (dessus) et flexible de l'échappement
        R.tuyau(lot, M["cuivre"], M["or_sombre"], [surf(-3.7, 1.25, 0.13), surf(-5.6, 1.25, 0.13), surf(-5.9, 1.6, 0.13)], 0.045, xf=xf)
        R.flexible(lot, M["caoutchouc"], M["or_sombre"], [surf(-4.2, 2.3 if s < 0 else 0.4, 0.05), surf(-4.8, 2.6 if s < 0 else 0.2, 0.3),
                                                          surf(-5.5, 2.2 if s < 0 else 0.6, 0.05)], 0.045, xf=xf)


def aile(lot, M, s, zs, xf):
    """Aile en flèche courte (les grandes ailes font place à la couronne, bible §5), dièdre 0,2, au-dessus du vide."""
    y0 = s * (NAC_Y + 0.85)
    cz = zs - 0.15
    poly = [(-4.1, 0.0), (-5.6, 0.0), (-6.5, 1.45), (-6.0, 1.5)]
    v, f, u = G.prisme([(p[0], p[1]) for p in poly], -0.045, 0.045)
    out = []
    for q in v:
        yy = s * q[1]
        z = q[2] + 0.2 * q[1]
        out.append((q[0], y0 + yy, cz + z))
    lot.put(M["jaune"], (out, f, u), xf)
    bord = [(-4.1, y0, cz + 0.05), (-6.0, y0 + s * 1.5, cz + 0.35)]
    lot.put(M["or"], G.tube(bord, 0.05, 8), xf)
    for k, t in enumerate((0.3, 0.62)):
        a = G.lerp((-4.6, y0, cz + 0.06), (-6.3, y0 + s * 1.45, cz + 0.34), t)
        lot.put(M["bronze2"], G.boite(G.add(a, (-0.2, 0, 0.03)), (0.55, 0.28, 0.03), rz=s * 0.5), xf)
    lot.put(M["balise"], G.sphere((-6.27, y0 + s * 1.5, cz + 0.36), 0.04, 8, 4), xf)


def derive(lot, M, zs, rnd, xf):
    poly = [(-3.6, zs + 0.7), (-5.5, zs + 0.7), (-6.35, zs + 3.05), (-5.75, zs + 3.12)]
    lot.put(M["jaune"], plaque_xz(poly, -0.07, 0.07), xf)
    lot.put(M["or"], G.tube([(-3.62, 0.0, zs + 0.72), (-5.72, 0.0, zs + 3.1)], 0.06, 8), xf)
    # bandes de chevrons et pièces rapportées, décalées (pas de grille)
    for (x, z, w, h, m) in ((-4.75, zs + 1.25, 0.9, 0.38, "chevron"), (-5.25, zs + 1.95, 0.6, 0.45, "bronze2"),
                            (-5.6, zs + 2.55, 0.42, 0.3, "jaune2")):
        for s in (-1, 1):
            lot.put(M[m], G.boite((x, s * 0.085, z), (w, 0.02, h), ry=0.35), xf)
    tip = (-5.95, 0.0, zs + 3.15)
    R.mat_antenne(lot, M["or_sombre"], M["bronze"], M["balise"], tip, 0.75, rnd, xf=xf)
    return tip


def coeur(lot, M, c, rnd, xf):
    """Cœur-réacteur à nu : sphère incandescente dans une cage d'anneaux, demi-coque nord, colliers et serre-joints."""
    lot.put(M["coeur"], G.sphere(c, 0.48, 20, 10), xf)
    for k, ax in enumerate(((0.0, 0.3, 1.0), (1.0, 0.2, 0.3), (0.6, -0.8, 0.4), (-0.5, 0.6, 0.7))):
        lot.put(M["or"] if k % 2 == 0 else M["bronze"], tore(c, 0.62 + 0.04 * k, 0.035, ax, 36, 6), xf)
    # demi-coque côté nord (ouverte vers la caméra)
    lot.put(M["noyau"], G.tour([(-0.6, 0.72), (0.6, 0.72)], 20, "x", c, a0=-0.6, a1=math.pi * 0.62, cap0=False), xf)
    for dx in (-0.62, 0.62):
        lot.put(M["or_sombre"], G.tour([(dx - 0.06, 0.8), (dx + 0.06, 0.8), (dx + 0.06, 0.55), (dx - 0.06, 0.55)], 24, "x", c), xf)
    for k in range(5):
        a = -0.4 + 0.5 * k
        p = (c[0], c[1] + 0.84 * math.cos(a), c[2] + 0.84 * math.sin(a))
        lot.put(M["bronze"], G.boite(p, (0.32, 0.12, 0.12), rx=a), xf)
