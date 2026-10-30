"""LE VAISSEAU (carcasse commune aux 4 états, kit vaisseau_o, lot CENTRE-OPUS).

NEZ vers +X (droite de l'écran), tuyères vers −X. Cotes données pour k = 1 (emprise 8×4) ; k = côté / 4. Le DÉTAIL
(rivets, portes, câbles, voyants) garde sa taille absolue : seul le corps grandit.
Construction (leçon de l'essai 1, cigare lisse refusé contre l'épave vanilla) : un NOYAU sombre recouvert de PLAQUES de
blindage épaisses, séparées par des jours sombres et rivetées ; deux grosses nacelles de propulsion à l'arrière ;
ailes en V attachées aux nacelles ; dérive ; canards à l'avant ; verrière à cadre lourd.
Carcasse du DC : crâne = nez et verrière ; épine = quille dorsale ; côtes = couples ; queue = les deux tuyères.
"""
import math

import geo as G

NSEC = 48
X_QUEUE, X_NEZ = -2.6, 3.35
EXPO = 3.0
NAC_Y, NAC_Z, NAC_R = 0.84, 0.9, 0.6
NAC_X0, NAC_X1 = -0.35, -2.55


def reglage(nac_x0=-0.35):
    """Réglage par état (variable de module : à reposer au début de CHAQUE build, une session rend plusieurs états) :
    avant des nacelles (les états à ventre-bâtiment raccourcissent les nacelles pour qu'elles ne percent pas la halle)."""
    global NAC_X0
    NAC_X0 = nac_x0


def profil(x):
    """(zc, demi-largeur, haut, bas) de la section à l'abscisse x (k = 1)."""
    zc, w, ht, hb = 1.05, 0.92, 0.8, 0.58
    if x > 1.0:                                    # crâne : ogive anguleuse qui plonge (bec)
        t = min(1.0, (x - 1.0) / (X_NEZ - 1.0))
        f = math.sqrt(max(0.0, 1.0 - t ** 1.6))
        w = 0.07 + (w - 0.07) * f
        ht = 0.05 + (ht - 0.05) * (1.0 - t ** 1.2) ** 0.85
        hb = 0.07 + (hb - 0.07) * f
        zc -= 0.2 * t * t
    elif x < -1.2:
        t = min(1.0, (-1.2 - x) / (-1.2 - X_QUEUE))
        w -= 0.22 * t
        ht -= 0.14 * t
        hb -= 0.08 * t
    return zc, w, ht, hb


def point(x, a, k=1.0, gonfle=0.0):
    zc, w, ht, hb = profil(x)
    c, s = math.cos(a), math.sin(a)
    e = 2.0 / EXPO
    y = (w + gonfle) * math.copysign(abs(c) ** e, c)
    z = zc + ((ht if s > 0 else hb) + gonfle) * math.copysign(abs(s) ** e, s)
    return (x * k, y * k, z * k)


def z_dessus(x, y):
    zc, w, ht, hb = profil(x)
    u = min(1.0, abs(y) / max(w, 1e-3))
    return zc + ht * (1.0 - u ** EXPO) ** (1 / EXPO)


def surf_coque(k):
    return lambda x, a, g: point(x, a, k, g)


def r_nacelle(x):
    if x > NAC_X0 - 0.35:                          # entrée d'air : capot conique
        t = max(0.0, min(1.0, (x - (NAC_X0 - 0.35)) / 0.45))
        return NAC_R * (1.0 - 0.45 * t * t)
    if x < NAC_X1 + 0.3:
        t = min(1.0, (NAC_X1 + 0.3 - x) / 0.3)
        return NAC_R * (1.0 - 0.1 * t)
    return NAC_R


def surf_nacelle(s, k):
    y, z = s * NAC_Y, NAC_Z

    def f(x, a, g):
        r = r_nacelle(x) + g
        return (x * k, (y + r * math.cos(a)) * k, (z + r * math.sin(a)) * k)
    return f


def normale_s(surf, x, a):
    p = surf(x, a, 0.0)
    q = surf(x, a + 0.01, 0.0)
    r = surf(x + 0.01, a, 0.0)
    n = G.norm(G.cross(G.sub(q, p), G.sub(r, p)))
    out = G.sub(surf(x, a, 0.1), p)
    return n if G.dot(n, out) > 0 else G.mul(n, -1.0)


def normale(x, a, k=1.0):
    return normale_s(surf_coque(k), x, a)


def _arc(surf, x, a):
    return G.length(G.sub(surf(x, a + 0.01, 0.0), surf(x, a, 0.0))) / 0.01


def plaque(surf, x0, x1, a0, a1, g0, g1, pas=0.07):
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


def plaques(lot, surf, xs, n_sect, mats, rnd, gap=0.018, g=(0.015, 0.055), saut=None, rivet=None, pas_riv=0.14,
            a_min=0.0, a_max=G.TAU, decal=0.5):
    """Blindage : bandes entre les stations xs, n_sect(i) plaques par bande (bords décalés d'une bande à l'autre,
    gigue), jour de « gap » entre plaques, épaisseur tirée dans g ; mats(rnd, i, j) choisit la matière ; saut(x0, x1,
    am) retire une plaque (abscisse et angle du milieu) ; rivet = matière des rivets (rangées le long des bords transversaux)."""
    plein = abs(a_max - a_min - G.TAU) < 1e-9
    for i in range(len(xs) - 1):
        x0, x1 = xs[i], xs[i + 1]
        n = n_sect(i)
        ph = (decal * (i % 2) + rnd.f(-0.15, 0.15)) / n
        bornes = []
        for j in range(n + (0 if plein else 1)):
            t = (j + (ph if plein else 0.0)) / float(n)
            if 0 < j < n or plein:
                t += rnd.f(-0.3, 0.3) / n
            bornes.append(a_min + (a_max - a_min) * t)
        if plein:
            bornes.append(bornes[0] + G.TAU)
        xm = (x0 + x1) / 2
        for j in range(len(bornes) - 1):
            a0, a1 = bornes[j], bornes[j + 1]
            if saut and saut(xm, ((a0 + a1) / 2) % G.TAU):
                continue
            da = gap / max(1e-3, _arc(surf, xm, (a0 + a1) / 2))
            gx = gap * (1.0 if x1 > x0 else -1.0)
            ep = rnd.f(*g)
            m = mats(rnd, i, j)
            if m is None:
                continue
            lot.put(m, plaque(surf, x0 + gx / 2, x1 - gx / 2, a0 + da / 2, a1 - da / 2, 0.0, ep))
            if rivet is not None:
                arc = (a1 - a0) * _arc(surf, xm, (a0 + a1) / 2)
                nr = max(2, int(arc / pas_riv))
                pts = []
                for xr in (x0 + gx / 2 + 0.035, x1 - gx / 2 - 0.035):
                    for q in range(nr):
                        a = a0 + da + (a1 - a0 - 2 * da) * (q + 0.5) / nr
                        pts.append((surf(xr, a, ep + 0.001), normale_s(surf, xr, a)))
                lot.put(rivet, G.rivets_le_long(pts, 0.017, 0.011))


def secteurs_coque(k, largeur=0.55):
    def f(i):
        return max(6, int(round(5.0 * k / largeur)))
    return f


def noyau(lot, mat, x0, x1, k=1.0, pas=0.08, gonfle=0.0, a0=0.0, a1=G.TAU):
    n = max(2, int((x1 - x0) / pas) + 1)
    plein = abs(a1 - a0 - G.TAU) < 1e-9
    m = NSEC if plein else max(4, int(NSEC * (a1 - a0) / G.TAU) + 1)
    rings = [[point(x0 + (x1 - x0) * i / float(n - 1), a0 + (a1 - a0) * j / float(m if plein else m - 1), k, gonfle)
              for j in range(m)] for i in range(n)]
    lot.put(mat, G.loft(rings, closed=plein))


def nacelle(lot, Mnoyau, Mband, Mint, s, k=1.0, feu=None, bouchee=None, cloche=True):
    """Nacelle de propulsion (noyau et cerclages ; les plaques sont posées par plaques()) + cloche + fond."""
    y, z = s * NAC_Y * k, NAC_Z * k
    xs = [NAC_X0 + 0.12 - (NAC_X0 + 0.12 - NAC_X1) * i / 24.0 for i in range(25)]
    lot.put(Mnoyau, G.tour([(x * k, r_nacelle(x) * k) for x in xs], 36, "x", (0.0, y, z)))
    # entrée d'air : lèvre et grille sombre
    xe = (NAC_X0 + 0.12) * k
    re = r_nacelle(NAC_X0 + 0.12) * k
    lot.put(Mband, G.tour([(xe - 0.02, re * 1.02), (xe + 0.04, re * 1.04), (xe + 0.06, re * 0.85), (xe + 0.02, re * 0.6)],
                          36, "x", (0.0, y, z)))
    lot.put(Mint, G.tour([(xe + 0.01, re * 0.62), (xe - 0.12, 0.0)], 24, "x", (0.0, y, z)))
    for xb in (NAC_X0 - 0.42, -1.35, NAC_X1 + 0.32):
        R = r_nacelle(xb) * k
        bp = [((xb - 0.065) * k, R + 0.0), ((xb - 0.06) * k, R + 0.075), ((xb + 0.06) * k, R + 0.075), ((xb + 0.065) * k, R)]
        lot.put(Mband, G.tour(bp, 36, "x", (0.0, y, z)))
    if not cloche:
        xc, R = NAC_X1 * k, r_nacelle(NAC_X1) * k
        lot.put(Mint, G.tour([(xc + 0.02, R * 0.97), (xc - 0.01, R * 0.9), (xc + 0.12, R * 0.5), (xc + 0.1, 0.0)], 24, "x", (0.0, y, z)))
        return
    # cloche (tuyère) : extérieur cerclé, intérieur brûlé
    xc = NAC_X1 * k
    R = r_nacelle(NAC_X1) * k
    L = 0.66 * k
    out = [(xc + 0.02, R * 0.96), (xc - 0.08 * L, R * 0.86), (xc - 0.5 * L, R * 0.93), (xc - 0.92 * L, R * 1.12),
           (xc - L, R * 1.16), (xc - L - 0.025, R * 1.16)]
    inn = [(xc - L - 0.025, R * 1.08), (xc - L + 0.01, R * 1.05), (xc - 0.6 * L, R * 0.84), (xc - 0.2 * L, R * 0.66),
           (xc - 0.04, R * 0.6)]
    lot.put(Mband, G.tour(out, 36, "x", (0.0, y, z)))
    lot.put(Mint, G.tour(inn, 36, "x", (0.0, y, z)))
    for f in (0.35, 0.7):
        xb = xc - f * L
        rb = R * (0.88 + 0.28 * f * f) + 0.02
        lot.put(Mband, G.tour([(xb - 0.03, rb - 0.01), (xb - 0.025, rb + 0.035), (xb + 0.025, rb + 0.035), (xb + 0.03, rb - 0.01)],
                              36, "x", (0.0, y, z)))
    lot.put(Mint, G.tour([(xc - 0.04, R * 0.62), (xc - 0.3 * L, R * 0.3), (xc - 0.42 * L, 0.0)], 24, "x", (0.0, y, z)))
    if feu is not None:
        lot.put(feu, G.tour([(xc - 0.3 * L, R * 0.33), (xc - 0.44 * L, R * 0.05), (xc - 0.45 * L, 0.0)], 16, "x", (0.0, y, z)))
    if bouchee is not None:
        lot.put(bouchee, G.tour([(xc - L + 0.05, 0.0), (xc - L + 0.05, R * 1.1), (xc - L - 0.03, R * 1.1), (xc - L - 0.03, 0.0)],
                                36, "x", (0.0, y, z)))


def aile(lot, Mplaque, Mnoyau, Mbord, Mriv, s, k=1.0, rnd=None, diedre=0.2, cassee=None, saut=None):
    """Aile en V attachée au flanc de la nacelle (s = −1 sud, +1 nord) : âme sombre, 6 plaques de blindage, volet,
    bord d'attaque en chevrons, saumon relevé."""
    y_rac, z_rac = NAC_Y + NAC_R * 0.85, NAC_Z + 0.12
    x_rac, x_bout, y_bout = (min(-0.55, NAC_X0 - 0.25), -2.3), (-1.95, -2.62), 2.6
    yb = y_bout if cassee is None else y_rac + (y_bout - y_rac) * cassee
    tb = (yb - y_rac) / (y_bout - y_rac)
    xb = (x_rac[0] + (x_bout[0] - x_rac[0]) * tb, x_rac[1] + (x_bout[1] - x_rac[1]) * tb)

    def pt(u, v, h):
        """u = corde (0 bord d'attaque, 1 bord de fuite), v = envergure (0 racine, 1 bout), h = hauteur sur l'âme."""
        xa = x_rac[0] + (xb[0] - x_rac[0]) * v
        xf = x_rac[1] + (xb[1] - x_rac[1]) * v
        y = y_rac + (yb - y_rac) * v
        ep = 0.09 - 0.05 * v
        p = (xa + (xf - xa) * u, s * y, z_rac + h * ep)
        p = G.rot_x(p, s * diedre, (0.0, s * y_rac, z_rac))
        return (p[0] * k, p[1] * k, p[2] * k)

    def dalle(u0, u1, v0, v1, h0, h1, m):
        if m is None:
            return
        q = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        bot = [pt(u, v, h0) for u, v in q]
        top = [pt(u, v, h1) for u, v in q]
        lot.put(m, G.loft([bot, top], closed=True))
        lot.put(m, (top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]))
        lot.put(m, (list(reversed(bot)), [(0, 1, 2, 3)], [(p[0], p[1]) for p in bot]))
    dalle(0.02, 0.98, 0.0, 1.0, -1.0, 0.6, Mnoyau)
    g = 0.025
    for (u0, u1) in ((0.06, 0.42), (0.42, 0.74)):
        for (v0, v1) in ((0.0, 0.36), (0.36, 0.7), (0.7, 1.0)):
            if saut and saut(u0, v0):
                continue
            dalle(u0 + g, u1 - g, v0 + g * 0.6, v1 - g * 0.6, 0.6, 1.15 + (rnd.f(0, 0.4) if rnd else 0.0), Mplaque)
            if Mriv is not None:
                pts = [(pt(u0 + g + 0.03, v0 + (v1 - v0) * (i + 0.5) / 5, 1.2), (0, 0, 1)) for i in range(5)]
                pts += [(pt(u1 - g - 0.03, v0 + (v1 - v0) * (i + 0.5) / 5, 1.2), (0, 0, 1)) for i in range(5)]
                lot.put(Mriv, G.rivets_le_long(pts, 0.016, 0.01))
    dalle(0.77, 0.97, 0.03, 0.97, -0.6, 0.85, Mplaque)                       # volet
    lot.put(Mbord, G.tube([pt(0.03, 0.0, 0.2), pt(0.03, 1.0, 0.2)], 0.075 * k, 10))
    if cassee is None:
        a, b = pt(0.15, 1.0, 0.0), pt(0.95, 1.0, 0.0)
        up = G.rot_x((0, 0, 0.42 * k), s * diedre)
        poly = [a, b, G.add(G.add(b, up), (-0.12 * k, 0, 0)), G.add(G.add(a, G.mul(up, 0.6)), (-0.35 * k, 0, 0))]
        inner = [G.add(p, (0.0, -s * 0.04 * k, 0.0)) for p in poly]
        lot.put(Mplaque, G.loft([poly, inner], closed=True))
        lot.put(Mplaque, (poly, [(0, 1, 2, 3)], [(p[0], p[2]) for p in poly]))
        lot.put(Mplaque, (list(reversed(inner)), [(0, 1, 2, 3)], [(p[0], p[2]) for p in poly]))
    return pt


def canard(lot, M, Mbord, s, k=1.0):
    """Petit plan canard à l'avant (casse la silhouette du nez)."""
    x0 = 1.15
    zc, w, ht, hb = profil(x0)
    poly = [(x0 + 0.55, w - 0.05), (x0 - 0.05, w - 0.05), (x0 - 0.2, w + 0.55), (x0 + 0.08, w + 0.55)]
    z = zc - 0.05
    a = [(px * k, s * py * k, (z - 0.035) * k) for px, py in poly]
    b = [(px * k, s * py * k, (z + 0.035) * k) for px, py in poly]
    lot.put(M, G.loft([a, b], closed=True))
    lot.put(M, (b, [(0, 1, 2, 3)], [(p[0], p[1]) for p in b]))
    lot.put(M, (list(reversed(a)), [(0, 1, 2, 3)], [(p[0], p[1]) for p in a]))
    lot.put(Mbord, G.tube([b[0], b[3]], 0.035 * k, 8))


def derive(lot, M, Mbord, k=1.0, x0=-0.95, h=1.05):
    zt = profil(x0)[0] + profil(x0)[2] - 0.04
    poly = [(x0, zt), (x0 - 0.95, zt + h), (x0 - 1.35, zt + h), (x0 - 1.5, zt - 0.1)]
    ep = 0.055
    a = [(x * k, -ep * k, z * k) for x, z in poly]
    b = [(x * k, ep * k, z * k) for x, z in poly]
    lot.put(M, G.loft([a, b], closed=True))
    lot.put(M, (b, [(0, 1, 2, 3)], [(x, z) for x, z in poly]))
    lot.put(M, (list(reversed(a)), [(0, 1, 2, 3)], [(x, z) for x, z in poly]))
    lot.put(Mbord, G.tube([(poly[0][0] * k + 0.02, 0, poly[0][1] * k), (poly[1][0] * k + 0.02, 0, poly[1][1] * k)], ep * 1.3 * k, 8))
    return ((poly[2][0] + 0.1) * k, 0.0, (poly[2][1] + 0.02) * k)


def verriere(lot, Mv, Mcadre, k=1.0, x0=1.2, x1=2.45):
    """Crâne : verrière bombée sur le dessus du nez, cadre lourd."""
    rings = []
    n, m = 14, 20
    for i in range(n):
        x = x0 + (x1 - x0) * i / float(n - 1)
        t = i / float(n - 1)
        bump = math.sin(math.pi * min(1.0, t * 1.12)) ** 0.7
        w = profil(x)[1]
        wg = w * (0.66 - 0.28 * t)
        hg = 0.04 + 0.2 * bump
        ring = []
        for j in range(m):
            a = math.pi * j / float(m - 1)
            y = wg * math.cos(a)
            ring.append((x * k, y * k, (z_dessus(x, y) + hg * math.sin(a) ** 0.8 - 0.015) * k))
        rings.append(ring)
    lot.put(Mv, G.loft(rings, closed=False))
    for i in (0, 4, 8, n - 1):
        lot.put(Mcadre, G.tube([G.add(p, (0, 0, 0.015)) for p in rings[i]], 0.03 * k ** 0.5, 6))
    for j in (0, 5, 14, m - 1):
        lot.put(Mcadre, G.tube([G.add(r[j], (0, 0, 0.015)) for r in rings], 0.03 * k ** 0.5, 6))
    return rings


def point_cote(x, a, k, g, haut=0.0, rond=False, balai=0.0):
    """Point d'un couple : section de coque (superellipse) ou, rond = True, ARCHE ELLIPTIQUE ; haut > 0 surélève le
    sommet ; balai > 0 incline la côte vers la queue en descendant (x − balai × (1 − sin a)). Un couple contenu dans un
    plan x = constante se projette en trait VERTICAL dans la caméra du jeu (u ne dépend que de x) : seul le balayage
    fait lire la courbe d'une côte à l'écran."""
    x = x - balai * (1.0 - math.sin(a))
    if rond:
        zc, w, ht, hb = profil(x)
        s = math.sin(a)
        p = (x * k, (w + g) * k * math.cos(a), (zc + ((ht if s > 0 else hb) + g) * s) * k)
    else:
        p = point(x, a, k, g)
    if haut:
        p = (p[0], p[1], p[2] + haut * max(0.0, math.sin(a)) ** 1.5)
    return p


def cote(lot, mat, x, k=1.0, ep=0.07, prof=0.09, saillie=0.02, a0=0.0, a1=G.TAU, haut=0.0, rond=False, balai=0.0):
    """Couple (côte) : anneau à section rectangulaire qui suit la section de coque ; haut > 0 : arche surélevée."""
    plein = abs(a1 - a0 - G.TAU) < 1e-9
    m = NSEC if plein else max(4, int(NSEC * (a1 - a0) / G.TAU) + 1)

    def ring(dx, g):
        out = []
        for j in range(m):
            a = a0 + (a1 - a0) * j / float(m if plein else m - 1)
            out.append(point_cote(x + dx / k, a, k, g, haut, rond, balai))
        return out
    rr = [ring(-ep / 2, saillie), ring(ep / 2, saillie), ring(ep / 2, saillie - prof), ring(-ep / 2, saillie - prof)]
    rr.append(rr[0])
    if plein:
        lot.put(mat, G.loft(rr, closed=True))
    else:
        lot.put(mat, G.loft(rr, closed=False))
        for j in (0, m - 1):
            q = [r[j] for r in rr[:4]]
            lot.put(mat, (q, [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)]))


def hublots(lot, Mcadre, Mv, xs, a, k=1.0, r=0.07, g=0.03):
    for x in xs:
        p = point(x, a, k, g)
        n = normale(x, a, k)
        ring = G.tour([(0.0, r * 1.4), (0.03, r * 1.32), (0.035, r * 1.02), (0.015, r * 0.95)], 16, "z")
        lot.put(Mcadre, G.oriente(ring, p, n))
        lot.put(Mv, G.oriente(G.tour([(0.015, r * 0.98), (0.02, 0.0)], 16, "z"), p, n))


def pose_plane(mesh, p, n):
    """Pose une maille plane (X local le long de +X monde, Y local vers le haut de la surface, Z local = n)."""
    n = G.norm(n)
    ex = G.norm(G.sub((1.0, 0.0, 0.0), G.mul(n, n[0])))
    ey = G.cross(n, ex)
    if ey[2] < 0:
        ey = G.mul(ey, -1.0)
    v, f, u = mesh
    return [G.add(p, G.add(G.add(G.mul(ex, q[0]), G.mul(ey, q[1])), G.mul(n, q[2]))) for q in v], f, u


def trappe(lot, Mcadre, Mporte, x, a, k=1.0, w=0.4, h=0.6, lum=None, g=0.04):
    p = point(x, a, k, g)
    n = normale(x, a, k)
    cad = G.merge(G.boite((0, -h / 2 - 0.035, 0.025), (w + 0.14, 0.07, 0.06)), G.boite((0, h / 2 + 0.035, 0.025), (w + 0.14, 0.07, 0.06)),
                  G.boite((-w / 2 - 0.035, 0, 0.025), (0.07, h + 0.14, 0.06)), G.boite((w / 2 + 0.035, 0, 0.025), (0.07, h + 0.14, 0.06)))
    lot.put(Mcadre, pose_plane(cad, p, n))
    lot.put(Mporte, pose_plane(G.merge(G.boite((0, 0, -0.01), (w, h, 0.03)), G.boite((0.12, 0, 0.015), (0.05, 0.12, 0.03)),
                                       G.boite((0, 0.12, 0.008), (w * 0.8, 0.03, 0.012)), G.boite((0, -0.12, 0.008), (w * 0.8, 0.03, 0.012))), p, n))
    if lum is not None:
        lot.put(lum, pose_plane(G.boite((0, h / 2 + 0.14, 0.04), (0.12, 0.05, 0.05)), p, n))


def grille(lot, M, Mfente, c, w, l, n=7):
    x, y, z = c
    lot.put(M, G.boite((x, y, z + 0.02), (l + 0.06, w + 0.06, 0.05)))
    lot.put(Mfente, G.boite((x, y, z + 0.04), (l, w, 0.02)))
    for i in range(n):
        lot.put(M, G.boite((x - l / 2 + l * (i + 0.5) / n, y, z + 0.055), (l / n * 0.45, w, 0.03)))


def caisson(lot, M, Mdet, c, s, rz=0.0, boulons=True, lum=None):
    x, y, z = c
    lot.put(M, G.boite((x, y, z + s[2] / 2), s, rz))
    lot.put(Mdet, G.boite((x, y, z + s[2] + 0.015), (s[0] * 0.82, s[1] * 0.82, 0.03), rz))
    if boulons:
        pts = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                q = G.rot_z((sx * s[0] * 0.44, sy * s[1] * 0.44, 0.0), rz)
                pts.append(((x + q[0], y + q[1], z + s[2] + 0.002), (0, 0, 1)))
        lot.put(Mdet, G.rivets_le_long(pts, 0.02, 0.015))
    if lum is not None:
        q = G.rot_z((s[0] * 0.3, -s[1] / 2 - 0.006, s[2] * 0.75), rz)
        lot.put(lum, G.boite((x + q[0], y + q[1], z + q[2]), (0.05, 0.02, 0.05), rz))


def tuyau(lot, M, Mbride, poly, r, rb=0.15, brides=True, pas_bride=0.9):
    pts = G.coudee(poly, rb, 6)
    lot.put(M, G.tube(pts, r, 12))
    if brides:
        fr = G._frames(pts)
        acc, last = 0.0, -1e9
        for i, p in enumerate(pts):
            if i:
                acc += G.length(G.sub(p, pts[i - 1]))
            if i in (0, len(pts) - 1) or acc - last > pas_bride:
                b = G.tour([(-0.025, r * 1.45), (0.025, r * 1.45)], 12, "z", cap0=True, cap1=True)
                lot.put(Mbride, G.oriente(b, p, fr[i][0]))
                last = acc


def flexible(lot, M, ctrl, r, pas=0.05):
    pts = G.catmull(ctrl, 12)
    lot.put(M, G.tube(pts, r, 10, rfun=lambda s, i: r * (1.0 + 0.16 * math.cos(s * G.TAU / pas))))


def cable(lot, M, a, b, fl=0.12, r=0.014):
    lot.put(M, G.tube(G.chainette(a, b, fl), r, 6))


def jambe(lot, M, Mverin, Mpied, c, k=1.0):
    x, y, z = c
    pied = (x, y + (0.22 if y > 0 else -0.22) * k, 0.03)
    tete = (x, y, z)
    lot.put(M, G.tube([tete, G.lerp(tete, pied, 0.55)], 0.065 * k ** 0.5, 10))
    lot.put(Mverin, G.tube([G.lerp(tete, pied, 0.5), pied], 0.042 * k ** 0.5, 10))
    lot.put(Mpied, G.tour([(0.0, 0.17 * k ** 0.5), (0.05, 0.16 * k ** 0.5), (0.08, 0.06), (0.14, 0.05)], 16, "z", (pied[0], pied[1], 0.0),
                          cap0=True, cap1=True))


XS_COQUE = [-2.6, -2.1, -1.62, -1.15, -0.66, -0.16, 0.34, 0.8, 1.2, 1.6, 2.0, 2.4, 2.78, 3.1, 3.35]
XS_NAC = [-0.28, -0.72, -1.06, -1.4, -1.8, -2.2, -2.52]


def corps(lot, k, rnd, Mnoyau, Mband, Mint, Mriv, mats, saut=None, saut_nac=None, nacelles=(-1, 1), feu=None,
          bouchee=None, x_noyau=(X_QUEUE, X_NEZ), breche=None, cloches=(-1, 1), ventre=None, Mcloison=None):
    """Le corps du vaisseau : noyau sombre, blindage de la coque, deux nacelles blindées et leurs tuyères.
    mats(rnd, i, j, zone) choisit la matière d'une plaque (zone = "coque" ou "nacelle") ; saut(xm, am) retire une
    plaque de coque (verrière, brèche, ventre remplacé par le bâtiment)."""
    if ventre is not None:                         # ventre remplacé par le bâtiment : coque aux deux bouts, cloisons
        noyau(lot, Mnoyau, x_noyau[0], ventre[0], k, gonfle=-0.005)
        noyau(lot, Mnoyau, ventre[1], x_noyau[1], k, gonfle=-0.005)
        for xv in ventre:
            ring = [point(xv, G.TAU * j / NSEC, k, 0.03) for j in range(NSEC)]
            lot.put(Mcloison or Mnoyau, G.loft([ring, [point(xv, G.TAU * j / NSEC, k, -0.02) for j in range(NSEC)]], cap1=True))
    elif breche is None:
        noyau(lot, Mnoyau, x_noyau[0], x_noyau[1], k, gonfle=-0.005)
    else:
        bx0, bx1, ba0, ba1 = breche                    # ventre ouvert : le noyau manque sur l'arc [ba0, ba1]
        noyau(lot, Mnoyau, x_noyau[0], bx0, k, gonfle=-0.005)
        noyau(lot, Mnoyau, bx1, x_noyau[1], k, gonfle=-0.005)
        noyau(lot, Mnoyau, bx0, bx1, k, gonfle=-0.005, a0=ba1, a1=ba0 + G.TAU)
        noyau(lot, Mint, bx0, bx1, k, gonfle=-0.04, a0=ba1, a1=ba0 + G.TAU)
    xs = [x for x in XS_COQUE if x_noyau[0] - 1e-6 <= x <= x_noyau[1] + 1e-6]

    def n_sect(i):
        zc, w, ht, hb = profil((xs[i] + xs[i + 1]) / 2)
        return max(4, int(round(math.pi * (w + (ht + hb) / 2) * 1.08 * k / 0.6)))
    plaques(lot, surf_coque(k), xs, n_sect, lambda r, i, j: mats(r, i, j, "coque"), rnd, saut=saut, rivet=Mriv)
    for s in nacelles:
        nacelle(lot, Mnoyau, Mband, Mint, s, k, feu=feu if s in cloches else None, bouchee=bouchee, cloche=s in cloches)
        sn = (lambda xm, am, s=s: saut_nac(s, xm, am)) if saut_nac else None
        xs_n = [NAC_X0 + 0.07] + [x for x in XS_NAC if x < NAC_X0 - 0.12]
        plaques(lot, surf_nacelle(s, k), xs_n, lambda i: 9, lambda r, i, j: mats(r, i, j, "nacelle"), rnd, saut=sn,
                rivet=Mriv)


def doublures(lot, surf, n, mats, rnd, xr, ar, Mriv=None, g=(0.06, 0.085)):
    """Doublures : petites plaques posées PAR-DESSUS le blindage, à cheval sur les joints (cassent la grille)."""
    for q in range(n):
        xm = rnd.f(*xr)
        am = rnd.f(*ar)
        lx = rnd.f(0.22, 0.5)
        arc = _arc(surf, xm, am)
        la = rnd.f(0.25, 0.55) / max(arc, 1e-3)
        ep = rnd.f(*g)
        m = mats(rnd)
        if m is None:
            continue
        x0, x1, a0, a1 = xm - lx / 2, xm + lx / 2, am - la / 2, am + la / 2
        lot.put(m, plaque(surf, x0, x1, a0, a1, 0.0, ep))
        if Mriv is not None:
            pts = []
            for i in range(4):
                for xr_ in (x0 + 0.03, x1 - 0.03):
                    a = a0 + (a1 - a0) * (i + 0.5) / 4
                    pts.append((surf(xr_, a, ep + 0.001), normale_s(surf, xr_, a)))
            lot.put(Mriv, G.rivets_le_long(pts, 0.016, 0.01))


def lisse(lot, surf, M, Mriv, a, x0, x1, larg=0.07, ep=0.08):
    """Lisse longitudinale (rail en relief rivé) le long de la coque, à l'angle a."""
    da = larg / max(1e-3, _arc(surf, (x0 + x1) / 2, a))
    lot.put(M, plaque(surf, x0, x1, a - da / 2, a + da / 2, 0.0, ep))
    if Mriv is not None:
        n = max(2, int(abs(x1 - x0) / 0.16))
        pts = [(surf(x0 + (x1 - x0) * (i + 0.5) / n, a, ep + 0.001), normale_s(surf, x0 + (x1 - x0) * (i + 0.5) / n, a))
               for i in range(n)]
        lot.put(Mriv, G.rivets_le_long(pts, 0.018, 0.012))


def cloche_seule(lot, Mband, Mint, k=1.0):
    """Cloche de tuyère détachée (épave), modélisée autour de l'axe X à l'origine, ouverture vers −X."""
    R = NAC_R * 0.9 * k
    L = 0.66 * k
    out = [(0.0, R * 0.96), (-0.08 * L, R * 0.86), (-0.5 * L, R * 0.93), (-0.92 * L, R * 1.12), (-L, R * 1.16), (-L - 0.025, R * 1.16)]
    inn = [(-L - 0.025, R * 1.08), (-L + 0.01, R * 1.05), (-0.6 * L, R * 0.84), (-0.2 * L, R * 0.66), (0.0, R * 0.6)]
    return G.tour(out, 32, "x"), G.tour(inn, 32, "x")
