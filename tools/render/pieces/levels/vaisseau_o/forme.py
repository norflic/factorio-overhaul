"""FORME : primitives de la refonte du QG (lot QG, 30/10), au-dessus de geo.py. Remplace la carcasse « cigare » de
vaisseau.py (jetée par le brief QG) : coque À FACETTES (section polygonale de 12 sommets, stations libres), tôles
irrégulières en parallélogrammes posées sur les facettes, côtes balayées vers la queue, grilles, tuyaux à brides,
flexibles annelés, faisceaux de câbles, éclats de tôle, débris.

Conventions de geo.py : 1 unité = une tuile en X, +X est (NEZ), +Y nord, +Z haut. Une coque est décrite dans un
repère LOCAL (axe x, centre de section en y = 0, z = 0) ; sa pose (roulis, tangage, lacet, translation) est donnée par
pose() et passée à lot.xf.
Paramètre de section t dans [0, 12) : 0 nord à mi-hauteur, 1 nord haut, 2 et 3 dos nord, 3,5 épine, 4 et 5 dos sud,
6 sud haut, 7 sud à mi-hauteur, 8 sud bas, 9 et 10 ventre, 11 nord bas.
"""
import math

import geo as G

NF = 12
_K = [(1.0, 0.0), (0.86, 0.58), (0.5, 0.94), (0.15, 1.0), (-0.15, 1.0), (-0.5, 0.94), (-0.86, 0.58), (-1.0, 0.0),
      (-0.82, -0.66), (-0.36, -1.0), (0.36, -1.0), (0.82, -0.66)]


def section(w, ht, hb, dz=0.0, epine=0.0):
    out = []
    for i, (a, b) in enumerate(_K):
        z = (ht if b >= 0 else hb) * b + dz
        if i in (3, 4):
            z += epine
        out.append((a * w, z))
    return out


class Coque:
    """Coque à facettes : stations (x, demi-largeur, haut, bas, décalage z, épine). Appel (x, t, g) : point de la
    surface décalé de g le long de la normale extérieure (lissée aux sommets de la section)."""

    def __init__(self, stations):
        self.st = sorted(stations)
        self.xs = [s[0] for s in self.st]
        self.secs = [section(*s[1:]) for s in self.st]

    def sec(self, x):
        xs = self.xs
        if x <= xs[0]:
            return self.secs[0]
        if x >= xs[-1]:
            return self.secs[-1]
        for i in range(len(xs) - 1):
            if xs[i] <= x <= xs[i + 1]:
                f = (x - xs[i]) / (xs[i + 1] - xs[i])
                a, b = self.secs[i], self.secs[i + 1]
                return [(a[j][0] + (b[j][0] - a[j][0]) * f, a[j][1] + (b[j][1] - a[j][1]) * f) for j in range(NF)]

    def p0(self, x, t):
        s = self.sec(x)
        t = t % NF
        j = min(NF - 1, int(math.floor(t)))
        f = t - j
        a, b = s[j], s[(j + 1) % NF]
        return (x, a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)

    def _n1(self, x, t):
        p, q, r = self.p0(x, t), self.p0(x, t + 0.004), self.p0(x + 0.004, t)
        n = G.norm(G.cross(G.sub(q, p), G.sub(r, p)))
        s = self.sec(x)
        cy = sum(v[0] for v in s) / NF
        cz = sum(v[1] for v in s) / NF
        return n if G.dot(n, (0.0, p[1] - cy, p[2] - cz)) > 0 else G.mul(n, -1.0)

    def n(self, x, t):
        return G.norm(G.add(self._n1(x, t - 0.02), self._n1(x, t + 0.02)))

    def __call__(self, x, t, g=0.0):
        p = self.p0(x, t)
        return p if g == 0.0 else G.add(p, G.mul(self.n(x, t), g))

    def repere(self, x, t, g=0.0):
        """(point, ex le long de l'axe, ey le long de la section, ez normale) : pour poser une pièce sur la coque."""
        p = self(x, t, g)
        ez = self.n(x, t)
        ex = G.norm(G.sub(self(x + 0.01, t, g), p))
        ey = G.norm(G.cross(ez, ex))
        ex = G.cross(ey, ez)
        return p, ex, ey, ez

    def hauteur(self, x, t):
        """Hauteur relative (0 = bas, 1 = haut) du point de section : sert au balayage des côtes."""
        s = self.sec(x)
        zs = [v[1] for v in s]
        return (self.p0(x, t)[2] - min(zs)) / max(1e-6, max(zs) - min(zs))


def pose(roulis=0.0, tangage=0.0, lacet=0.0, t=(0.0, 0.0, 0.0), zmin=0.004):
    """Transformation d'un repère local : roulis (autour de x ; > 0 couche le dos vers le SUD, donc vers la caméra),
    tangage (> 0 baisse le +x), lacet (> 0 tourne le +x vers le nord), puis translation ; z bloqué à zmin."""
    def f(p):
        p = G.rot_x(p, roulis)
        p = G.rot_y(p, tangage)
        p = G.rot_z(p, lacet)
        return (p[0] + t[0], p[1] + t[1], max(zmin, p[2] + t[2]))
    return f


def local(mesh, o, ex, ey, ez):
    """Pose une maille modélisée dans (x, y, z) local sur le repère (o, ex, ey, ez)."""
    v, f, u = mesh
    return [G.add(o, G.add(G.add(G.mul(ex, q[0]), G.mul(ey, q[1])), G.mul(ez, q[2]))) for q in v], f, u


# ------------------------------------------------------------------------------------------------ tôles
def _cuts(a, b, extra):
    out = sorted(set([a, b] + [c for c in extra if a < c < b]))
    return out


def plaque(surf, x0, x1, t0, t1, g0, g1, sk=(0.0, 0.0), pas=0.11, xs_extra=()):
    """Tôle épaisse sur une surface paramétrique (x, t, g) : bords transversaux biaisés (sk = décalage en x du bord
    x0 et du bord x1 entre t0 et t1 : parallélogramme hors axes) ; g1 = épaisseur extérieure, nombre ou (au bord x0,
    au bord x1) : tôle relevée d'un côté. Suit les facettes (coupes aux t entiers)."""
    ts = _cuts(t0, t1, [float(k) for k in range(int(math.floor(t0)), int(math.ceil(t1)) + 1)])
    ts2 = []
    for i in range(len(ts) - 1):
        n = max(1, int(G.length(G.sub(surf(x0, ts[i + 1]), surf(x0, ts[i]))) / pas))
        ts2 += [ts[i] + (ts[i + 1] - ts[i]) * k / float(n) for k in range(n)]
    ts2.append(ts[-1])
    nx = max(1, int(abs(x1 - x0) / pas))
    ga, gb = (g1, g1) if not isinstance(g1, tuple) else g1

    def P(fx, ft, g):
        t = t0 + (t1 - t0) * ft
        xa, xb = x0 + sk[0] * ft, x1 + sk[1] * ft
        x = xa + (xb - xa) * fx
        if g is None:
            g = ga + (gb - ga) * fx
        return surf(x, t, g)

    fts = [(t - t0) / max(1e-9, t1 - t0) for t in ts2]
    fxs = [i / float(nx) for i in range(nx + 1)]
    out = G.loft([[P(fx, ft, None) for ft in fts] for fx in fxs], closed=False)
    bords = [G.loft([[P(0.0, ft, g0) for ft in fts], [P(0.0, ft, None) for ft in fts]], closed=False),
             G.loft([[P(1.0, ft, None) for ft in fts], [P(1.0, ft, g0) for ft in fts]], closed=False),
             G.loft([[P(fx, 0.0, None) for fx in fxs], [P(fx, 0.0, g0) for fx in fxs]], closed=False),
             G.loft([[P(fx, 1.0, g0) for fx in fxs], [P(fx, 1.0, None) for fx in fxs]], closed=False)]
    return G.merge(out, *bords), P


def rivets_bord(P, g, n_pas, r=0.024, cote=0.0):
    """Rivets le long du bord transversal fx = cote d'une tôle (P rendu par plaque)."""
    pts = []
    for k in range(n_pas):
        ft = (k + 0.5) / n_pas
        fx = 0.06 if cote == 0.0 else 0.94
        p = P(fx, ft, g + 0.002)
        q = P(fx, ft, g + 0.05)
        pts.append((p, G.sub(q, p)))
    return G.rivets_le_long(pts, r, r * 0.6)


def dalle(c4, t):
    """Dalle épaisse sur 4 coins (dans l'ordre), épaisseur t le long de la normale."""
    n = G.norm(G.cross(G.sub(c4[1], c4[0]), G.sub(c4[3], c4[0])))
    top = [G.add(p, G.mul(n, t)) for p in c4]
    v = list(top) + list(reversed(c4))
    f = [(0, 1, 2, 3), (4, 5, 6, 7)]
    uv = [(0, 0), (1, 0), (1, 1), (0, 1)] * 2
    for i in range(4):
        a, b = c4[i], c4[(i + 1) % 4]
        ta, tb = top[i], top[(i + 1) % 4]
        base = len(v)
        v += [a, b, tb, ta]
        uv += [(0, 0), (1, 0), (1, 1), (0, 1)]
        f.append((base, base + 1, base + 2, base + 3))
    return v, f, uv


def eclat(a, b, c, t=0.02):
    """Éclat de tôle triangulaire (bord déchiré) épais de t."""
    n = G.norm(G.cross(G.sub(b, a), G.sub(c, a)))
    a2, b2, c2 = (G.add(p, G.mul(n, t)) for p in (a, b, c))
    v = [a2, b2, c2, c, b, a, a, b, b2, a2, b, c, c2, b2, c, a, a2, c2]
    f = [(0, 1, 2), (3, 4, 5), (6, 7, 8, 9), (10, 11, 12, 13), (14, 15, 16, 17)]
    uv = [(p[0], p[1]) for p in v]
    return v, f, uv


def poly_dalle(poly, t):
    """Plaque plane d'un polygone CONVEXE (x, y), épaisse de t, posée sur z = 0 (à transformer)."""
    return G.prisme(poly, 0.0, t)


# ------------------------------------------------------------------------------------------------ côtes
def cote(surf, x, ta, tb, balai, r=0.045, g=-0.02, n=18, segs=4):
    """Côte qui suit la section de ta à tb, balayée vers la queue (−x) en descendant : x − balai·(1 − h) ; à l'écran,
    une suite d'arcs « (((( » (piège n° 1 de CENTRE-OPUS : une côte dans un plan x = cte se lit en barreau)."""
    pts = []
    for k in range(n + 1):
        t = ta + (tb - ta) * k / float(n)
        h = surf.hauteur(x, t)
        pts.append(surf(x - balai * (1.0 - h), t, g))
    return G.tube(pts, r, segs)


# ------------------------------------------------------------------------------------------------ greebles
def grille(lot, m_cadre, m_lame, o, ex, ey, ez, L, H, n=6, prof=0.05):
    """Évent : cadre épais + n lames inclinées, posé sur le repère (o, ex le long de L, ey le long de H, ez normale)."""
    e = 0.035
    for (cx, cy, sx, sy) in ((0.0, H / 2 - e / 2, L, e), (0.0, -H / 2 + e / 2, L, e), (L / 2 - e / 2, 0.0, e, H),
                             (-L / 2 + e / 2, 0.0, e, H)):
        lot.put(m_cadre, local(G.boite((cx, cy, prof / 2), (sx, sy, prof)), o, ex, ey, ez))
    lot.put(m_lame, local(G.boite((0.0, 0.0, 0.004), (L - 2 * e, H - 2 * e, 0.008)), o, ex, ey, ez))
    for k in range(n):
        y = -H / 2 + e + (H - 2 * e) * (k + 0.5) / n
        lot.put(m_cadre, local(G.boite((0.0, y, prof * 0.55), (L - 2 * e, (H - 2 * e) / n * 0.55, 0.012), rx=0.7),
                               o, ex, ey, ez))


def tuyau(lot, m, m_bride, poly, r, rb=None, brides=True, segs=10):
    """Tuyau rigide à coudes arrondis et brides (aux deux bouts et au milieu de chaque segment droit long)."""
    pts = G.coudee(poly, rb or r * 2.6, 6)
    lot.put(m, G.tube(pts, r, segs))
    if not brides:
        return
    places = [(poly[0], G.norm(G.sub(poly[1], poly[0]))), (poly[-1], G.norm(G.sub(poly[-1], poly[-2])))]
    for i in range(len(poly) - 1):
        a, b = poly[i], poly[i + 1]
        if G.length(G.sub(b, a)) > 0.55:
            places.append((G.lerp(a, b, 0.5), G.norm(G.sub(b, a))))
    for p, d in places:
        lot.put(m_bride, G.tube([G.add(p, G.mul(d, -r * 0.35)), G.add(p, G.mul(d, r * 0.35))], r * 1.55, segs))


def reechantillon(pts, pas):
    out = [pts[0]]
    acc = 0.0
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        L = G.length(G.sub(b, a))
        while acc + L >= pas:
            f = (pas - acc) / max(L, 1e-9)
            a = G.lerp(a, b, f)
            out.append(a)
            L = G.length(G.sub(b, a))
            acc = 0.0
        acc += L
    out.append(pts[-1])
    return out


def flexible(lot, m, ctrl, r, pas_anneau=None):
    """Flexible annelé (gaine) le long d'une Catmull-Rom : anneaux de pas ≈ 1,6 r."""
    pa = pas_anneau or r * 1.6
    pts = reechantillon(G.catmull(ctrl, 14), pa / 4.0)
    lot.put(m, G.tube(pts, r, 10, rfun=lambda s, i: r * (1.0 + 0.2 * (1 if (i % 4) < 2 else -0.4))))


def faisceau(lot, mats, a, b, fl, r=0.014, n=3, ecart=0.035, rnd=None):
    """Faisceau de câbles pendants (rouges et noirs) de a à b, flèche fl ; légers écarts entre les brins."""
    for k in range(n):
        dy = (k - (n - 1) / 2.0) * ecart
        dz = (rnd.f(-0.5, 0.5) * ecart) if rnd else 0.0
        aa = G.add(a, (0.0, dy, dz))
        bb = G.add(b, (dy * 0.6, dy, -dz))
        lot.put(mats[k % len(mats)], G.tube(G.chainette(aa, bb, fl * (1.0 + 0.15 * k), 16), r, 6))


def membrure(lot, m, ctrl, ep=0.022, larg=0.05):
    """Membrure ou sangle arrachée : barre plate tordue le long d'une Catmull-Rom (section rectangulaire)."""
    pts = G.catmull(ctrl, 8)
    fr = G._frames(pts)
    rings = []
    for p, (t, n1, n2) in zip(pts, fr):
        rings.append([G.add(p, G.add(G.mul(n1, sx * larg), G.mul(n2, sy * ep))) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    lot.put(m, G.loft(rings, True, True))


def treillis(lot, m, a, b, h, n=5, r=0.018, haut=(0.0, 0.0, 1.0), casse=None):
    """Poutre en treillis (deux membrures, montants et diagonales) de a à b, hauteur h dans la direction « haut » ;
    casse = indice du panneau rompu (diagonale et membrure haute absentes)."""
    up = G.norm(haut)
    a2, b2 = G.add(a, G.mul(up, h)), G.add(b, G.mul(up, h))
    for k in range(n):
        p0, p1 = G.lerp(a, b, k / float(n)), G.lerp(a, b, (k + 1) / float(n))
        q0, q1 = G.lerp(a2, b2, k / float(n)), G.lerp(a2, b2, (k + 1) / float(n))
        lot.put(m, G.tube([p0, p1], r * 1.3, 5))
        if k != casse:
            lot.put(m, G.tube([q0, q1], r * 1.3, 5))
            lot.put(m, G.tube([p0, q1] if k % 2 == 0 else [q0, p1], r, 4))
        lot.put(m, G.tube([p0, q0], r, 4))
    lot.put(m, G.tube([b, b2], r, 4))


def tertre(c, rx, ry, h, rnd, na=40, nr=10, bord=0.18, bosses=0.25, pente=1.3):
    """Tertre de terre en grille POLAIRE (contour lisse et bosselé, pas d'escalier comme geo.butte) ; c = pied."""
    ph = [rnd.f(0, G.TAU) for _ in range(8)]
    verts, faces, uvs = [(c[0], c[1], c[2] + h)], [], [(c[0], c[1])]
    for i in range(1, nr + 1):
        f = i / float(nr)
        for j in range(na):
            a = G.TAU * j / na
            k = 1.0 + bord * (0.6 * math.sin(3 * a + ph[0]) + 0.4 * math.sin(7 * a + ph[1]))
            x, y = c[0] + rx * k * f * math.cos(a), c[1] + ry * k * f * math.sin(a)
            b = 1.0 + bosses * math.sin(5.1 * f * math.cos(a) + ph[2]) * math.sin(4.3 * f * math.sin(a) + ph[3])
            z = c[2] + max(0.0, h * (1.0 - f * f) ** pente * b) - (0.01 if i == nr else 0.0)
            verts.append((x, y, z))
            uvs.append((x, y))
    for j in range(na):
        faces.append((0, 1 + j, 1 + (j + 1) % na))
    for i in range(nr - 1):
        b0, b1 = 1 + i * na, 1 + (i + 1) * na
        for j in range(na):
            faces.append((b0 + j, b1 + j, b1 + (j + 1) % na, b0 + (j + 1) % na))
    return verts, faces, uvs
