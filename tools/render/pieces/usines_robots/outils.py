"""OUTILS communs aux usines de robots : tuyaux, câbles, hublots (repris de vaisseau_o/carcasse.py, sans la coque) ;
treillis, bras de montage, anneaux, lunes de dôme (neufs). Conventions de geo.py : +X est, +Y nord, +Z haut.
Rappel de la projection (fo_calib) : une tuile de profondeur vaut 1,414 unité en Y ; 1 unité de Z vaut 0,707 tuile à l'écran.
"""
import math

import geo as G

TAU = G.TAU


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


def cyl(lot, m, a, b, r, segs=12, r2=None):
    """Cylindre (ou cône si r2) plein de a à b."""
    if r2 is None:
        lot.put(m, G.tube([a, b], r, segs))
    else:
        L = G.length(G.sub(b, a))
        lot.put(m, G.oriente(G.tour([(0.0, r), (L, r2)], segs, "z", cap0=True, cap1=True), a, G.sub(b, a)))


def profil(lot, m, a, n, prof, segs=24):
    """Révolution d'un profil [(position, rayon)] autour de l'axe n passant par a."""
    lot.put(m, G.oriente(G.tour(prof, segs, "z"), a, n))


def tuyau(lot, M, Mbride, poly, r, rb=0.16, pas_bride=0.75):
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
    lot.put(M, G.tube(pts, r, 10, rfun=lambda s, i: r * (1.0 + 0.18 * math.cos(s * TAU / pas))))


def faisceau(lot, Ma, Mb, a, b, fl, n=3, r=0.012, ecart=0.03, rnd=None):
    """Faisceau de câbles pendants, flèches légèrement différentes."""
    for i in range(n):
        d = (0.0, (i - (n - 1) / 2.0) * ecart, 0.0)
        f = fl * (1.0 + 0.12 * i) + (rnd.f(-0.03, 0.03) if rnd else 0.0)
        lot.put(Ma if i % 2 == 0 else Mb, G.tube(G.chainette(G.add(a, d), G.add(b, d), f, 18), r, 6))


def hublot(lot, Mcadre, Mv, p, n, r=0.08):
    """Hublot rond à bride boulonnée."""
    lot.put(Mcadre, G.oriente(G.tour([(0.0, r * 1.5), (0.03, r * 1.42), (0.04, r * 1.05), (0.02, r * 0.95)], 18, "z"), p, n))
    lot.put(Mv, G.oriente(G.tour([(0.02, r * 0.98), (0.026, 0.0)], 18, "z"), p, n))
    pts = [(G.oriente(([(r * 1.25 * math.cos(t), r * 1.25 * math.sin(t), 0.035)], [], []), p, n)[0][0], n)
           for t in [TAU * i / 8 for i in range(8)]]
    lot.put(Mcadre, G.rivets_le_long(pts, 0.012, 0.01))


def rivets_anneau(lot, m, c, R, z, nb, rr=0.016, axe="z"):
    """Rivets posés sur un cercle (axe z : couronne d'une virole ; axe x : couronne sur un cylindre couché)."""
    pts = []
    for k in range(nb):
        a = TAU * k / nb
        if axe == "z":
            pts.append(((c[0] + R * math.cos(a), c[1] + R * math.sin(a), z), (math.cos(a), math.sin(a), 0.0)))
        else:
            pts.append(((z, c[1] + R * math.cos(a), c[2] + R * math.sin(a)), (0.0, math.cos(a), math.sin(a))))
    lot.put(m, G.rivets_le_long(pts, rr, rr * 0.7))


def anneau(lot, m, c, R, rt, segs=64, tsegs=10, a0=0.0, a1=TAU, n=(0.0, 0.0, 1.0)):
    """Tore de centre c, de rayon R et de section rt, dans le plan de normale n (arc de a0 à a1)."""
    n = G.norm(n)
    ref = (1.0, 0.0, 0.0) if abs(n[0]) < 0.9 else (0.0, 1.0, 0.0)
    e1 = G.norm(G.cross(ref, n))
    e2 = G.cross(n, e1)
    pts = []
    for i in range(segs + 1):
        a = a0 + (a1 - a0) * i / float(segs)
        pts.append(G.add(c, G.add(G.mul(e1, R * math.cos(a)), G.mul(e2, R * math.sin(a)))))
    lot.put(m, G.tube(pts, rt, tsegs))


def treillis(lot, m, a, b, l=0.18, h=0.18, n=8, rc=0.018, rd=0.009, up=(0.0, 0.0, 1.0)):
    """Poutre en treillis de a à b : 4 membrures, montants, diagonales alternées. Section l × h."""
    d = G.norm(G.sub(b, a))
    s = G.norm(G.cross(d, up))
    t = G.cross(s, d)
    c = [G.add(G.mul(s, sx * l / 2.0), G.mul(t, sy * h / 2.0)) for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    for q in c:
        lot.put(m, G.tube([G.add(a, q), G.add(b, q)], rc, 5))
    for i in range(n + 1):
        p = G.lerp(a, b, i / float(n))
        for j in range(4):
            lot.put(m, G.tube([G.add(p, c[j]), G.add(p, c[(j + 1) % 4])], rd, 4))
        if i < n:
            p2 = G.lerp(a, b, (i + 1) / float(n))
            for j in range(4):
                k = j if i % 2 == 0 else (j + 1) % 4
                lot.put(m, G.tube([G.add(p, c[k]), G.add(p2, c[(k + 1) % 4 if i % 2 == 0 else j])], rd, 4))


def bras(lot, Mc, Mj, Mn, base, epaule, coude, poignet, bout, r=0.12, socle=0.26, lum=None, riv=None):
    """Bras de montage articulé : socle tournant, segment fuselé, coude à moyeu, avant-bras fuselé, poignet, outil.
    Mc carénage, Mj articulations, Mn noir (gaines) ; r : rayon du bras à l'épaule ; lum : matière de l'étincelle."""
    profil(lot, Mj, base, (0, 0, 1), [(0.0, socle * 1.15), (0.04, socle * 1.15), (0.07, socle), (G.length(G.sub(epaule, base)) * 0.65, socle * 0.7),
                                      (G.length(G.sub(epaule, base)), socle * 0.55)], 20)
    for (a, b, r0, r1) in ((epaule, coude, r, r * 0.72), (coude, poignet, r * 0.72, r * 0.42)):
        L = G.length(G.sub(b, a))
        d = G.sub(b, a)
        prof = [(0.0, r0 * 0.7), (0.06 * L, r0), (0.55 * L, (r0 + r1) / 2.0 * 1.05), (0.94 * L, r1), (L, r1 * 0.7)]
        lot.put(Mc, G.oriente(G.tour(prof, 16, "z", cap0=True, cap1=True), a, d))
    # moyeux : disques perpendiculaires au plan du bras
    n = G.norm(G.cross(G.sub(coude, epaule), G.sub(poignet, coude)))
    if G.length(n) < 0.5:
        n = (0.0, 1.0, 0.0)
    for (p, k) in ((epaule, 1.25), (coude, 1.0), (poignet, 0.62)):
        rj = r * k
        lot.put(Mj, G.oriente(G.tour([(-rj * 0.9, rj * 0.72), (-rj * 0.75, rj), (rj * 0.75, rj), (rj * 0.9, rj * 0.72)], 16, "z", cap0=True, cap1=True), p, n))
        if riv is not None:
            lot.put(riv, G.oriente(G.tour([(rj * 0.9, rj * 0.45), (rj * 0.98, rj * 0.32), (rj * 1.02, 0.0)], 10, "z"), p, n))
    # gaines qui suivent le bras
    off = G.mul(n, r * 0.75)
    pm = G.lerp(epaule, coude, 0.5)
    lot.put(Mn, G.tube(G.catmull([G.add(epaule, off), G.add(pm, G.add(off, (0.0, 0.0, r * 0.75))), G.add(coude, off)], 8), max(0.012, r * 0.13), 6))
    # outil : cône et pointe
    d = G.norm(G.sub(bout, poignet))
    L = G.length(G.sub(bout, poignet))
    lot.put(Mj, G.oriente(G.tour([(0.0, r * 0.42), (L * 0.4, r * 0.4), (L * 0.75, r * 0.18), (L, r * 0.06)], 12, "z", cap1=True), poignet, d))
    if lum is not None:
        lot.put(lum, G.sphere(bout, r * 0.22, 8, 4))


def lune(lot, Mext, Mint, Mlevre, c, R, th0, th1, ep, phi=1.33, nphi=56, nth=16):
    """Lune de dôme à charnière est-ouest passant par c : th angle autour de X depuis le nord (0) vers le haut (pi/2) ;
    phi : demi-ouverture en longitude autour des moyeux. Rend la fonction du point de la surface extérieure (phi, th)."""
    def P(r, f, t):
        rr = r * math.cos(f)
        return (c[0] + r * math.sin(f), c[1] + rr * math.cos(t), c[2] + rr * math.sin(t))

    def nappe(r):
        return [[P(r, -phi + 2.0 * phi * j / nphi, th0 + (th1 - th0) * i / float(nth)) for j in range(nphi + 1)] for i in range(nth + 1)]
    lot.put(Mext, G.loft(nappe(R), closed=False))
    lot.put(Mint, G.loft(nappe(R - ep), closed=False))
    lot.put(Mlevre, G.loft([[P(R, -phi + 2.0 * phi * j / nphi, th1) for j in range(nphi + 1)],
                            [P(R - ep, -phi + 2.0 * phi * j / nphi, th1) for j in range(nphi + 1)]], closed=False))
    return lambda f, t, g=0.0: P(R + g, f, t)
