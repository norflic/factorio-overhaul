"""CARCASSE du vaisseau pour le QG de l'âge 13 (emprise 16×8), refaite de zéro selon le BRIEF QG du 30/10 :
crâne (nez à chevrons jaunes et noirs, verrière) À DROITE (+X), 2 grosses tuyères À GAUCHE, dérive dressée, ailes en
flèche hors du plan (dièdre 0,2), épine continue, côtes inclinées vers la queue « (((( », un cœur (ici : la sphère de
confinement, posée par age13.py). Le crâne et la queue sont roulés de ~15° (le dos se montre) ; tout l'ensemble est
tourné de ~7,5° (nez vers le sud-est) par la transformation globale du lot.

Coordonnées : 1 unité = 1 tuile en x ; +Y nord (1 tuile = 1,414 u) ; +Z haut (1 u = 45 px HR à l'écran).
"""
import math

import geo as G

TAU = G.TAU


# ------------------------------------------------------------------------------------------------ plaques sur surface
def _arc(surf, x, a):
    return G.length(G.sub(surf(x, a + 0.01, 0.0), surf(x, a, 0.0))) / 0.01


def normale_s(surf, x, a):
    p = surf(x, a, 0.0)
    q = surf(x, a + 0.01, 0.0)
    r = surf(x + 0.01, a, 0.0)
    n = G.norm(G.cross(G.sub(q, p), G.sub(r, p)))
    out = G.sub(surf(x, a, 0.1), p)
    return n if G.dot(n, out) > 0 else G.mul(n, -1.0)


def plaque(surf, x0, x1, a0, a1, g0, g1, pas=0.08):
    nx = max(1, int(abs(x1 - x0) / pas))
    na = max(1, int(abs(a1 - a0) * _arc(surf, (x0 + x1) / 2, (a0 + a1) / 2) / pas))
    xs = [x0 + (x1 - x0) * i / float(nx) for i in range(nx + 1)]
    As = [a0 + (a1 - a0) * j / float(na) for j in range(na + 1)]
    out = G.loft([[surf(x, a, g1) for a in As] for x in xs], closed=False)
    bords = [G.loft([[surf(x0, a, g0) for a in As], [surf(x0, a, g1) for a in As]], closed=False),
             G.loft([[surf(x1, a, g1) for a in As], [surf(x1, a, g0) for a in As]], closed=False),
             G.loft([[surf(x, a0, g1) for x in xs], [surf(x, a0, g0) for x in xs]], closed=False),
             G.loft([[surf(x, a1, g0) for x in xs], [surf(x, a1, g1) for x in xs]], closed=False)]
    return G.merge(out, *bords)


def plaques(lot, surf, xs, larg, mats, rnd, gap=0.022, g=(0.02, 0.06), saut=None, rivet=None, pas_riv=0.15,
            a_min=0.0, a_max=TAU, xf=None):
    """Blindage en tuiles de céramique ÉPAISSES sur un noyau : bandes entre les stations xs (pas irrégulier), tuiles de
    largeur ~larg (gigue ±35 %, bords décalés d'une bande à l'autre), jours sombres, épaisseurs tirées dans g."""
    plein = abs(a_max - a_min - TAU) < 1e-9
    for i in range(len(xs) - 1):
        x0, x1 = xs[i], xs[i + 1]
        xm = (x0 + x1) / 2
        circ = _arc(surf, xm, (a_min + a_max) / 2) * (a_max - a_min)
        n = max(3, int(round(circ / larg)))
        ph = rnd.f(0.0, 1.0) / n
        bornes = []
        for j in range(n + (0 if plein else 1)):
            t = (j + (ph if plein else 0.0)) / float(n)
            if 0 < j < n or plein:
                t += rnd.f(-0.35, 0.35) / n
            bornes.append(a_min + (a_max - a_min) * t)
        if plein:
            bornes.append(bornes[0] + TAU)
        for j in range(len(bornes) - 1):
            a0, a1 = bornes[j], bornes[j + 1]
            am = ((a0 + a1) / 2) % TAU
            if saut and saut(xm, am):
                continue
            m = mats(rnd, xm, am)
            if m is None:
                continue
            da = gap / max(1e-3, _arc(surf, xm, (a0 + a1) / 2))
            gx = gap * (1.0 if x1 > x0 else -1.0)
            ep = rnd.f(*g)
            lot.put(m, plaque(surf, x0 + gx / 2, x1 - gx / 2, a0 + da / 2, a1 - da / 2, 0.0, ep), xf)
            if rivet is not None and rnd.f() < 0.55:
                arc = (a1 - a0) * _arc(surf, xm, (a0 + a1) / 2)
                nr = max(2, int(arc / pas_riv))
                pts = []
                for xr in (x0 + gx / 2 + 0.04, x1 - gx / 2 - 0.04):
                    for q in range(nr):
                        a = a0 + da + (a1 - a0 - 2 * da) * (q + 0.5) / nr
                        pts.append((surf(xr, a, ep + 0.001), normale_s(surf, xr, a)))
                lot.put(rivet, G.rivets_le_long(pts, 0.018, 0.011), xf)


def stations(x0, x1, pas, rnd, gigue=0.3):
    n = max(2, int(round(abs(x1 - x0) / pas)))
    xs = [x0]
    for i in range(1, n):
        xs.append(x0 + (x1 - x0) * (i + rnd.f(-gigue, gigue)) / n)
    xs.append(x1)
    return xs


# ------------------------------------------------------------------------------------------------ superellipse
def super_pt(zc, w, ht, hb, a, g=0.0, e=2.6):
    c, s = math.cos(a), math.sin(a)
    k = 2.0 / e
    y = (w + g) * math.copysign(abs(c) ** k, c)
    z = zc + ((ht if s > 0 else hb) + g) * math.copysign(abs(s) ** k, s)
    return y, z


# ------------------------------------------------------------------------------------------------ crâne
X_CR0, X_NEZ = 2.55, 7.55
ZC_CR = 2.75
ROLL = 0.26


def profil_crane(x):
    zc, w, ht, hb = ZC_CR, 1.5, 1.22, 0.95
    if x > 3.0:
        t = min(1.0, (x - 3.0) / (X_NEZ - 3.0))
        f = math.sqrt(max(0.0, 1.0 - t ** 1.7))
        w = 0.1 + (w - 0.1) * f
        ht = 0.08 + (ht - 0.08) * (1.0 - t ** 1.25) ** 0.8
        hb = 0.1 + (hb - 0.1) * f
        zc -= 0.55 * t * t
    return zc, w, ht, hb


def surf_crane(x, a, g):
    zc, w, ht, hb = profil_crane(x)
    y, z = super_pt(zc, w, ht, hb, a, g)
    return (x, y, z)


def roll_crane(p):
    return G.rot_x(p, ROLL, (0.0, 0.0, ZC_CR))


# ------------------------------------------------------------------------------------------------ fuselage de queue
X_Q0, X_Q1 = -6.0, -2.9
ZC_Q = 2.45


def profil_queue(x):
    t = (x - X_Q0) / (X_Q1 - X_Q0)
    return ZC_Q, 1.0 + 0.2 * t, 0.95 + 0.15 * t, 0.7


def surf_queue(x, a, g):
    zc, w, ht, hb = profil_queue(x)
    y, z = super_pt(zc, w, ht, hb, a, g)
    return (x, y, z)


def roll_queue(p):
    return G.rot_x(p, ROLL * 0.6, (0.0, 0.0, ZC_Q))


# ------------------------------------------------------------------------------------------------ nacelles
NAC_Y, NAC_Z = 1.95, 2.05
NAC_X0, NAC_X1 = -3.3, -6.25


def r_nac(x):
    R = 1.02
    if x > NAC_X0 - 0.5:
        t = max(0.0, min(1.0, (x - (NAC_X0 - 0.5)) / 0.5))
        return R * (1.0 - 0.4 * t * t)
    return R


def surf_nac(s):
    yc = s * NAC_Y

    def f(x, a, g):
        r = r_nac(x) + g
        return (x, yc + r * math.cos(a), NAC_Z + r * math.sin(a))
    return f


# ------------------------------------------------------------------------------------------------ épine et côtes
def epine_pts():
    """Épine dorsale : du dos de la queue, elle monte en arche au-dessus de la sphère (elle la tient), puis redescend
    sur le dos du crâne."""
    ctrl = [(-6.0, 0.0, 3.45), (-4.9, 0.0, 4.3), (-3.9, 0.0, 6.35), (-2.6, 0.0, 7.65), (-0.4, 0.0, 8.9), (1.8, 0.0, 7.75),
            (3.0, 0.0, 6.35), (3.9, 0.0, 4.6), (4.6, 0.0, 4.05)]
    return G.catmull(ctrl, 10)


def z_epine(pts, x):
    best = min(pts, key=lambda p: abs(p[0] - x))
    return best[2]
