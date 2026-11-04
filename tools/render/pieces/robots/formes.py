"""FORMES communes des robots (lot RB-V0), au-dessus de geo.py (kit du QG, validé par le DC le 31/10). Python pur."""
import math
import os

import geo as G

TAU = G.TAU
GRIS = bool(os.environ.get("FO_GRIS"))     # masses grises : toutes les surfaces en gris moyen, seules les lumières restent


def surf(name, col, **kw):
    import mat as MT
    if GRIS:
        return MT.surface("g_" + name, (0.16, 0.16, 0.16), rough=0.6, met=0.2, usure=0.3, crasse=0.6, graine=kw.get("graine", 0))
    return MT.surface(name, col, **kw)


def pose(mesh, o, x, haut=(0.0, 0.0, 1.0)):
    """Pose une maille : son +X local le long de x, son +Z au plus près de haut, son origine en o."""
    ex = G.norm(x)
    h = haut if abs(G.dot(ex, G.norm(haut))) < 0.98 else (1.0, 0.0, 0.0)
    ey = G.norm(G.cross(h, ex))
    ez = G.cross(ex, ey)
    v, f, u = mesh
    return [G.add(o, G.add(G.add(G.mul(ex, p[0]), G.mul(ey, p[1])), G.mul(ez, p[2]))) for p in v], f, u


def sur_face(mesh, p, n, haut=(0.0, 0.0, 1.0)):
    """Pose une maille plate modélisée autour de +Z (X largeur, Y hauteur) sur une face de normale n, son Y vers `haut`."""
    n = G.norm(n)
    h = haut if abs(G.dot(n, G.norm(haut))) < 0.98 else (1.0, 0.0, 0.0)
    ex = G.norm(G.cross(h, n))
    ey = G.cross(n, ex)
    v, f, u = mesh
    return [G.add(p, G.add(G.add(G.mul(ex, q[0]), G.mul(ey, q[1])), G.mul(n, q[2]))) for q in v], f, u


def incline(mesh, base, d):
    """Maille modélisée autour de +Z, de pied à l'origine : pied en base, axe le long de d (flèche inclinée)."""
    return G.oriente(mesh, base, d)


def tore(c, R, r, axe="z", seg=48, segr=8, a0=0.0, a1=TAU):
    prof = [(r * math.sin(TAU * i / segr), R + r * math.cos(TAU * i / segr)) for i in range(segr)]
    prof.append(prof[0])
    return G.tour(prof, seg, axe, c, a0, a1)


def bague(c, ri, re, h, axe="z", seg=48, chanfrein=0.0, a0=0.0, a1=TAU):
    """Anneau à section rectangulaire (chanfreiné), d'axe `axe`, centré en c."""
    k = chanfrein
    prof = [(-h / 2 + k, ri), (-h / 2, ri + k), (-h / 2, re - k), (-h / 2 + k, re), (h / 2 - k, re), (h / 2, re - k), (h / 2, ri + k),
            (h / 2 - k, ri), (-h / 2 + k, ri)]
    return G.tour(prof, seg, axe, c, a0, a1)


def disque(c, r, h, axe="z", seg=24):
    """Cylindre plein et fermé, d'épaisseur h."""
    return G.tour([(-h / 2, 0.0), (-h / 2, r), (h / 2, r), (h / 2, 0.0)], seg, axe, c)


def poutre(secs, chanfrein=0.28):
    """Barre le long de +X à section octogonale : secs = [(x, largeur y, hauteur z[, décalage z])]. Fonte, bielles, lames."""
    rings = []
    for s in secs:
        x, w, h = s[0], s[1], s[2]
        dz = s[3] if len(s) > 3 else 0.0
        a, b = w / 2.0, h / 2.0
        c = min(a, b) * chanfrein * 2.0
        rings.append([(x, -a + c, -b + dz), (x, a - c, -b + dz), (x, a, -b + c + dz), (x, a, b - c + dz), (x, a - c, b + dz),
                      (x, -a + c, b + dz), (x, -a, b - c + dz), (x, -a, -b + c + dz)])
    return G.loft(rings, True, True)


def bielle(a, b, w, h, haut=(0.0, 0.0, 1.0)):
    """Barre droite de a à b."""
    d = G.sub(b, a)
    L = G.length(d)
    return pose(poutre([(0.0, w, h), (L, w, h)]), a, d, haut)


def fleche(r, h, n=8, socle=1.3, ventre=0.0):
    """Flèche à n pans autour de +Z, pied en z = 0 : socle, fût effilé, pointe. ventre : renflement au tiers."""
    return G.tour([(0.0, r * socle), (0.05 * h, r * socle), (0.07 * h, r), (0.3 * h, r * (0.74 + ventre)), (0.62 * h, r * 0.4),
                   (0.88 * h, r * 0.12), (h, 0.0)], n, "z", cap0=True)


def ogive(w, h):
    """Contour d'arc brisé convexe (X largeur, Y hauteur, pied en y = 0) : baie gothique."""
    return [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, h * 0.58), (w * 0.36, h * 0.78), (w * 0.17, h * 0.92), (0.0, h), (-w * 0.17, h * 0.92),
            (-w * 0.36, h * 0.78), (-w / 2, h * 0.58)]


def plaque(poly, ep):
    """Plaque d'épaisseur ep sur un contour convexe (dessus en z = ep)."""
    return G.prisme(poly, 0.0, ep)


def rivets_anneau(x, r, n, phase=0.0, rr=0.018, a0=0.0, a1=TAU):
    """Rivets sur un cercle de rayon r, autour de l'axe X, à l'abscisse x."""
    pts = []
    for i in range(n):
        a = a0 + (a1 - a0) * (i + phase) / n
        nrm = (0.0, math.cos(a), math.sin(a))
        pts.append(((x, r * nrm[1], r * nrm[2]), nrm))
    return G.rivets_le_long(pts, rr, rr * 0.6)


def rivets_ligne(a, b, n, nrm, rr=0.016):
    return G.rivets_le_long([(G.lerp(a, b, (i + 0.5) / n), nrm) for i in range(n)], rr, rr * 0.6)


def cristal(c, r, h=None):
    """Petite pierre à 8 faces (bipyramide) : particules, gemmes."""
    h = h if h is not None else r
    return G.tour([(-h, 0.0), (0.0, r), (h, 0.0)], 4, "z", c)
