"""PETITES PIÈCES (greebles) du QG âge 13 : tuyaux à brides, flexibles annelés, faisceaux de câbles, grilles, échelles,
garde-corps, caisses, fûts, bouteilles, bobines, hublots. Tout est en mailles geo (Lot.put), repère du sol.
Convention : 1 unité = 1 tuile en x ; +Y nord (1 tuile = 1,414) ; +Z haut. Nez du vaisseau vers +X.
"""
import math

import geo as G

TAU = G.TAU


def tuyau(lot, M, Mb, poly, r, rb=0.25, pas_bride=1.1):
    """Tuyau rigide coudé à brides (début, fin et tous les pas_bride)."""
    pts = G.coudee(poly, rb, 6)
    lot.put(M, G.tube(pts, r, 12))
    fr = G._frames(pts)
    acc, last = 0.0, -1e9
    for i, p in enumerate(pts):
        if i:
            acc += G.length(G.sub(p, pts[i - 1]))
        if i in (0, len(pts) - 1) or acc - last > pas_bride:
            b = G.tour([(-0.03, r * 1.5), (0.03, r * 1.5)], 12, "z", cap0=True, cap1=True)
            lot.put(Mb, G.oriente(b, p, fr[i][0]))
            last = acc


def flexible(lot, M, ctrl, r, pas=0.07, n=14):
    """Flexible annelé (ondulation du rayon) le long d'une Catmull-Rom."""
    pts = G.catmull(ctrl, n)
    lot.put(M, G.tube(pts, r, 10, rfun=lambda s, i: r * (1.0 + 0.18 * math.cos(s * TAU / pas))))


def faisceau(lot, Mr, Mn, a, b, fl=0.25, n=3, r=0.022):
    """Faisceau de câbles qui pend entre a et b : n câbles rouges et noirs écartés, flèches inégales."""
    for i in range(n):
        d = (i - (n - 1) / 2.0) * r * 2.4
        aa = G.add(a, (0.0, d, 0.0))
        bb = G.add(b, (0.0, d, 0.0))
        lot.put(Mr if i % 2 == 0 else Mn, G.tube(G.chainette(aa, bb, fl * (1.0 + 0.18 * i)), r, 6))


def grille(lot, M, Mf, c, lx, ly, n=7, rz=0.0, h=0.05):
    """Évent horizontal : cadre, fond sombre, lames."""
    x, y, z = c
    lot.put(M, G.boite((x, y, z + h / 2), (lx + 0.06, ly + 0.06, h), rz))
    lot.put(Mf, G.boite((x, y, z + h), (lx, ly, 0.02), rz))
    for i in range(n):
        q = G.rot_z((-lx / 2 + lx * (i + 0.5) / n, 0.0, 0.0), rz)
        lot.put(M, G.boite((x + q[0], y + q[1], z + h + 0.02), (lx / n * 0.45, ly, 0.035), rz))


def grille_v(lot, M, Mf, c, w, h, n=6, cote=-1):
    """Évent vertical sur une façade d'axe x (cote −1 : façade sud)."""
    x, y, z = c
    lot.put(Mf, G.boite((x, y, z), (w, 0.04, h)))
    lot.put(M, G.boite((x, y + cote * 0.02, z + h / 2 + 0.02), (w + 0.06, 0.05, 0.04)))
    lot.put(M, G.boite((x, y + cote * 0.02, z - h / 2 - 0.02), (w + 0.06, 0.05, 0.04)))
    for i in range(n):
        lot.put(M, G.boite((x, y + cote * 0.03, z - h / 2 + h * (i + 0.5) / n), (w, 0.03, h / n * 0.4), 0.0, cote * 0.5))


def echelle(lot, M, a, b, w=0.32, pas=0.22):
    """Échelle verticale de a (bas) à b (haut), largeur le long de x."""
    for s in (-1, 1):
        lot.put(M, G.tube([G.add(a, (s * w / 2, 0, 0)), G.add(b, (s * w / 2, 0, 0))], 0.022, 6))
    n = max(2, int((b[2] - a[2]) / pas))
    for i in range(n):
        p = G.lerp(a, b, (i + 0.5) / n)
        lot.put(M, G.tube([G.add(p, (-w / 2, 0, 0)), G.add(p, (w / 2, 0, 0))], 0.016, 5))


def garde_corps(lot, M, pts, h=0.38, pas=0.5, r=0.02):
    """Garde-corps le long d'une polyligne au sol de la passerelle (main courante, lisse, poteaux)."""
    top = [G.add(p, (0, 0, h)) for p in pts]
    mid = [G.add(p, (0, 0, h * 0.5)) for p in pts]
    lot.put(M, G.tube(top, r, 6))
    lot.put(M, G.tube(mid, r * 0.8, 5))
    acc = 0.0
    last = -1e9
    for i, p in enumerate(pts):
        if i:
            acc += G.length(G.sub(p, pts[i - 1]))
        if i in (0, len(pts) - 1) or acc - last >= pas:
            lot.put(M, G.tube([p, G.add(p, (0, 0, h))], r, 6))
            last = acc


def caisse(lot, M, Md, c, s, rz=0.0):
    x, y, z = c
    lot.put(M, G.boite((x, y, z + s[2] / 2), s, rz))
    for dz in (0.12, s[2] - 0.12):
        lot.put(Md, G.boite((x, y, z + dz), (s[0] + 0.02, s[1] + 0.02, 0.05), rz))
    lot.put(Md, G.boite((x, y, z + s[2] + 0.01), (s[0] * 0.8, s[1] * 0.8, 0.02), rz))


def fut(lot, M, Md, c, r=0.17, h=0.42):
    x, y, z = c
    lot.put(M, G.tour([(z, r), (z + h, r)], 14, "z", (x, y, 0.0), cap0=True, cap1=True))
    for dz in (0.08, h * 0.5, h - 0.08):
        lot.put(Md, G.tour([(z + dz - 0.02, r + 0.012), (z + dz + 0.02, r + 0.012)], 14, "z", (x, y, 0.0)))


def bouteille(lot, M, Mt, c, r=0.13, h=0.9, couche=False, rz=0.0):
    """Bouteille de gaz (hélium 3) debout ou couchée (couche=True, axe tourné de rz)."""
    prof = [(0.0, r * 0.9), (0.03, r), (h - r, r), (h - r * 0.4, r * 0.75), (h, r * 0.3), (h + 0.05, r * 0.3), (h + 0.06, 0.0)]
    m = G.tour(prof, 12, "z", (0.0, 0.0, 0.0), cap0=True)
    v, f, u = m
    if couche:
        v = [G.rot_z(G.rot_y(p, math.pi / 2), rz) for p in v]
        v = [(p[0] + c[0], p[1] + c[1], p[2] + c[2] + r) for p in v]
    else:
        v = [(p[0] + c[0], p[1] + c[1], p[2] + c[2]) for p in v]
    lot.put(M, (v, f, u))
    if not couche:
        lot.put(Mt, G.tour([(c[2] + h * 0.55, r + 0.01), (c[2] + h * 0.62, r + 0.01)], 12, "z", (c[0], c[1], 0.0)))


def bobine(lot, M, Mc, c, r=0.32, w=0.3, rz=0.0):
    """Touret de câble couché."""
    x, y, z = c
    ax = G.rot_z((1.0, 0.0, 0.0), rz)
    for s in (-1, 1):
        d = G.mul(ax, s * w / 2)
        lot.put(M, G.oriente(G.tour([(-0.02, r), (0.02, r)], 16, "z", cap0=True, cap1=True), (x + d[0], y + d[1], z + r), ax))
    lot.put(Mc, G.oriente(G.tour([(-w / 2, r * 0.7), (w / 2, r * 0.7)], 16, "z", cap0=True, cap1=True), (x, y, z + r), ax))


def hublot(lot, Mcadre, Mv, p, n, r=0.08):
    ring = G.tour([(0.0, r * 1.45), (0.035, r * 1.35), (0.04, r * 1.02), (0.02, r * 0.95)], 16, "z")
    lot.put(Mcadre, G.oriente(ring, p, n))
    lot.put(Mv, G.oriente(G.tour([(0.02, r * 0.98), (0.025, 0.0)], 16, "z"), p, n))


def antenne(lot, M, Ml, base, h, r=0.03, barres=2, lum=None):
    top = G.add(base, (0, 0, h))
    lot.put(M, G.tube([base, top], r, 6))
    lot.put(M, G.tour([(base[2], r * 3), (base[2] + 0.08, r * 3)], 8, "z", (base[0], base[1], 0.0), cap1=True))
    for i in range(barres):
        p = G.lerp(base, top, 0.55 + 0.18 * i)
        w = 0.28 - 0.08 * i
        lot.put(M, G.tube([G.add(p, (-w, 0, 0)), G.add(p, (w, 0, 0))], r * 0.6, 5))
    if lum is not None:
        lot.put(lum, G.sphere(top, r * 2.2, 8, 4))


def boite_tourne(c, s, axe):
    """Boîte de tailles s (long, large, haut) dont la longueur suit le vecteur horizontal axe."""
    rz = math.atan2(axe[1], axe[0])
    return G.boite(c, s, rz)


def poutre(lot, M, a, b, w=0.12, h=None):
    """Poutre de section carrée de a à b (tube à 4 côtés)."""
    lot.put(M, G.tube([a, b], (w if h is None else h) * 0.7071, 4))
