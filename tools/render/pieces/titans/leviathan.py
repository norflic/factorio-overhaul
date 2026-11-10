"""LÉVIATHAN, titan ALLIÉ (lot TITANS-RECAL, 10/11) : serpent blindé FLOTTANT, d'après les concepts c_re9biv et c_enm9m7 du DC : tube
blindé argent segmenté qui ondule en S au-dessus du sol (l'ombre portée est décalée : il lévite), VORTEX frontal (gueule circulaire,
couronne de crocs et de pointes, halo), anneaux de lévitation le long du corps, nageoires-lames dorsales et ventrales gravées de
circuits, nacelle-canon rotatif sur le flanc arrière, queue effilée en cristal. Environ 38 tuiles de long à l'écran.
Escorte : 2 à 3 DRONES (petites flèches blindées à œil cyan), rendus à part (`build(S, lot, "drone")`) et posés par le script en
`rendering` orbitant autour du corps (aucune entité).

Modèle paramétrique low-poly (kit des géants), UNE image par stade (1 à 3) : nageoires, anneaux, canon et cristaux s'ajoutent.
Repère LOCAL : +x = face (tête), +y = gauche, +z = haut ; PSI : lacet (la tête vers le sud-est, côté caméra).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
XP = os.path.normpath(os.path.join(HERE, "..", "experimentaux"))
if XP not in sys.path:
    sys.path.insert(0, XP)
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import geo as G  # noqa: E402
import greb as R  # noqa: E402
import titans_mat as TM  # noqa: E402
from juggernaut import hexseg, pointe, plaque, anneau, rainure  # noqa: E402

PREFIX = "le_"
PSI = -math.radians(40.0)
KE = 1.0
GRIS = os.environ.get("FO_GRIS", "") == "1"
HAUTEUR = 21.0 * KE
RAYON = 19.0 * KE
CTRL = [(-17.5, 4.5, 8.4), (-13.5, 5.6, 8.9), (-9.5, 3.2, 9.5), (-5.5, -1.4, 10.1), (-1.5, -3.0, 10.5), (2.5, -1.6, 10.7), (6.5, 0.9, 10.5),
        (10.5, 1.6, 10.2), (13.5, 0.6, 10.0)]


def XF(v):
    p = G.rot_z(v, PSI)
    return (p[0] * KE, p[1] * KE, max(0.0, p[2] * KE))


def rayon(t):
    """Rayon du corps selon la position t (0 = queue, 1 = tête)."""
    if t < 0.35:
        return 0.45 + (2.5 - 0.45) * (t / 0.35) ** 1.3
    if t < 0.88:
        return 2.5 + 0.25 * math.sin(math.pi * (t - 0.35) / 0.53)
    return 2.5 + 0.9 * ((t - 0.88) / 0.12) ** 1.5


def ring(p, fr, r, n=10, rot=0.0):
    t, n1, n2 = fr
    out = []
    for j in range(n):
        a = rot + G.TAU * (j + 0.5) / n
        out.append(G.add(p, G.add(G.mul(n1, r * math.cos(a)), G.mul(n2, r * math.sin(a)))))
    return out


def lame(lot, M, p, d, n, L, w, k_grav=2):
    """Nageoire-lame : croissant effilé le long de d (longueur L, demi-largeur w à la base), normale n ; circuits gravés."""
    ex, ey, ez = R.repere(n, d)
    def sec(t, ww):
        q = G.add(p, G.mul(d, t))
        return [G.add(q, G.add(G.mul(ex, -ww), G.mul(ez, -0.12))), G.add(q, G.add(G.mul(ex, ww), G.mul(ez, -0.12))),
                G.add(q, G.add(G.mul(ex, ww * 0.8), G.mul(ez, 0.12))), G.add(q, G.add(G.mul(ex, -ww * 0.8), G.mul(ez, 0.12)))]
    lot.put(M["blind"], G.loft([sec(0.0, w), sec(L * 0.3, w * 1.25), sec(L * 0.65, w * 0.9), sec(L * 0.9, w * 0.4), sec(L, 0.08)], True, True))
    for i in range(k_grav):
        s = (i - (k_grav - 1) / 2.0) * w * 0.6
        a = G.add(G.add(p, G.mul(ex, s)), G.add(G.mul(d, L * 0.15), G.mul(ez, 0.14)))
        b = G.add(G.add(p, G.mul(ex, s * 0.4)), G.add(G.mul(d, L * (0.6 + 0.15 * i)), G.mul(ez, 0.14)))
        lot.put(M["turq"], G.tube([a, b], 0.06, 5))


def corps(lot, M, stage):
    """Tube blindé segmenté le long de la colonne, conduits dorsal et latéraux, anneaux, nageoires, nacelle, queue."""
    pts = G.catmull(CTRL, 6)
    frs = G._frames(pts)
    n = len(pts)
    rings, prof = [], []
    for i, p in enumerate(pts):
        t = i / float(n - 1)
        r = rayon(t)
        rings.append(ring(p, frs[i], r, 10, 0.3 if (i // 3) % 2 else 0.0))
        prof.append((p, r, t))
    lot.put(M["blind2"], G.loft(rings, True, True))
    # segments de blindage : couronnes plus larges, une tous les 3 points, avec un joint sombre (struct) entre deux
    for i in range(3, n - 4, 3):
        p, r, t = prof[i]
        fr = frs[i]
        d = fr[0]
        seg = [ring(G.add(p, G.mul(d, -0.75)), fr, r * 1.04, 10), ring(G.add(p, G.mul(d, -0.55)), fr, r * 1.22, 10),
               ring(G.add(p, G.mul(d, 0.55)), fr, r * 1.22, 10), ring(G.add(p, G.mul(d, 0.75)), fr, r * 1.04, 10)]
        lot.put(M["blind"], G.loft(seg, False, False))
        lot.put(M["struct"], G.loft([ring(G.add(p, G.mul(d, 0.95)), fr, r * 1.06, 10), ring(G.add(p, G.mul(d, 1.3)), fr, r * 1.0, 10)], False, False))
        if t > 0.3:
            # plaques dorsales en écailles (deux par couronne) et accent magenta au joint
            for s in (-1, 1):
                q = G.add(p, G.add(G.mul(fr[2], r * 0.95), G.mul(fr[1], s * r * 0.45)))
                lot.put(M["blind"], plaque(q, G.norm(G.add(fr[2], G.mul(fr[1], s * 0.5))), r * 0.7, 1.3, 0.3, up=d, coins=0.7))
            lot.put(M["accent"], G.boite(G.add(p, G.add(G.mul(d, 1.1), G.mul(fr[1], r * 1.02))), (0.3, 0.2, 0.35)))
    # conduits : crête dorsale continue (cyan), deux lignes latérales (turquoise)
    dors = [G.add(pts[i], G.mul(frs[i][2], prof[i][1] * 1.0 + 0.05)) for i in range(2, n - 2)]
    lot.put(M["conduit"], G.tube(dors, 0.11, 6))
    for s in (-1, 1):
        lat = [G.add(pts[i], G.add(G.mul(frs[i][1], s * prof[i][1] * 0.98), G.mul(frs[i][2], -prof[i][1] * 0.1))) for i in range(4, n - 3)]
        lot.put(M["turq"], G.tube(lat, 0.08, 6))
    # anneaux de lévitation autour du corps (3, puis 4, puis 5)
    n_an = 3 + (stage >= 2) + (stage >= 3)
    for k in range(n_an):
        i = int(round((0.22 + 0.62 * k / float(n_an - 1)) * (n - 1)))
        p, r, t = prof[i]
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", r + 1.3, 0.45, 0.15), p, frs[i][0]))
        if stage >= 3:
            lot.put(M["cristal"], G.oriente(rainure((0.0, 0.0, 0.0), "z", r + 1.35, 0.05), G.add(p, G.mul(frs[i][0], 0.2)), frs[i][0]))
    # nageoires-lames dorsales (3, puis 4, puis 5), ventrales (2), pectorales-lames à la tête
    nd = 3 + (stage >= 2) + (stage >= 3)
    for k in range(nd):
        i = int(round((0.40 + 0.42 * k / float(nd - 1)) * (n - 1)))
        p, r, t = prof[i]
        fr = frs[i]
        base = G.add(p, G.mul(fr[2], r * 0.9))
        d = G.norm(G.add(G.mul(fr[2], 1.0), G.mul(fr[0], -0.55)))
        lame(lot, M, base, d, fr[1], 5.6 - 0.4 * abs(k - nd / 2.0), 1.3, 2)
    for k in range(2):
        i = int(round((0.5 + 0.25 * k) * (n - 1)))
        p, r, t = prof[i]
        fr = frs[i]
        for s in (-1, 1):
            base = G.add(p, G.add(G.mul(fr[2], -r * 0.6), G.mul(fr[1], s * r * 0.6)))
            d = G.norm(G.add(G.add(G.mul(fr[2], -0.8), G.mul(fr[1], s * 0.9)), G.mul(fr[0], -0.5)))
            lame(lot, M, base, d, fr[2], 4.2, 1.0, 1)
    # nacelle-canon rotatif sur le flanc arrière droit (stade 2+)
    if stage >= 2:
        i = int(round(0.42 * (n - 1)))
        p, r, t = prof[i]
        fr = frs[i]
        c = G.add(p, G.add(G.mul(fr[1], -(r + 0.9)), G.mul(fr[2], -0.3)))
        d = fr[0]
        lot.put(M["struct"], G.sphere(c, 0.9, 10, 5))
        for q in range(5):
            a = G.TAU * q / 5
            off = G.add(G.mul(fr[1], 0.55 * math.cos(a)), G.mul(fr[2], 0.55 * math.sin(a)))
            lot.put(M["canon"], G.tube([G.add(c, off), G.add(G.add(c, off), G.mul(d, 3.2))], 0.26, 8))
        lot.put(M["coeur"], G.tube([G.add(c, G.mul(d, 2.6)), G.add(c, G.mul(d, 3.3))], 0.2, 8))
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", 1.2, 0.25, 0.1), G.add(c, G.mul(d, 1.6)), d))
    # queue : pointe de cristal, deux lames
    tip = pts[0]
    fr0 = frs[0]
    lot.put(M["cristal"], pointe(G.add(tip, G.mul(fr0[0], 0.3)), G.mul(fr0[0], -1.0), 3.0, 0.4))
    for s in (-1, 1):
        lame(lot, M, G.add(pts[3], G.mul(fr0[1], s * 0.5)), G.norm(G.add(G.mul(fr0[1], s * 0.9), G.mul(fr0[0], -0.6))), fr0[2], 2.6, 0.6, 1)
    return pts, frs, prof


def tete(lot, M, pts, frs, prof, stage):
    """Gueule circulaire : couronne blindée, vortex (cœur) et halo, crocs (os) en cercle, pointes de cristal rayonnantes, lames pectorales."""
    p, r, t = prof[-1]
    d = frs[-1][0]
    fr = frs[-1]
    rc = r + 0.3
    lot.put(M["blind"], G.oriente(anneau((0.0, 0.0, 0.0), "z", rc, 1.1, 0.8), p, d))
    lot.put(M["struct"], G.oriente(G.tour([(-0.2, 0.0), (-0.1, rc - 0.1)], 20, "z", cap0=True), p, d))
    lot.put(M["chair"], G.oriente(anneau((0.0, 0.0, 0.0), "z", rc - 0.9, 0.9, 0.5), G.add(p, G.mul(d, 0.3)), d))
    lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.0), (0.3, rc - 1.3)], 20, "z", cap1=True), G.add(p, G.mul(d, 0.45)), d))
    lot.put(M["halo"], G.sphere(G.add(p, G.mul(d, 1.2)), rc + 0.4, 18, 9))
    lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", rc + 0.35, 0.08), G.add(p, G.mul(d, 0.85)), d))
    for k in range(14):
        a = G.TAU * k / 14
        off = G.add(G.mul(fr[1], math.cos(a)), G.mul(fr[2], math.sin(a)))
        lot.put(M["os"], pointe(G.add(G.add(p, G.mul(off, rc - 0.8)), G.mul(d, 0.7)), G.norm(G.add(G.mul(off, -0.5), d)), 0.8, 0.14, 4))
        if k % 2 == 0:
            lot.put(M["cristal"], pointe(G.add(G.add(p, G.mul(off, rc + 0.9)), G.mul(d, -0.2)), G.norm(G.add(off, G.mul(d, 0.35))), 2.2 if k % 4 == 0 else 1.4, 0.26))
    if stage >= 2:
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", rc + 2.2, 0.5, 0.16), G.add(p, G.mul(d, -0.8)), d))
    if stage >= 3:
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", rc + 3.4, 0.6, 0.2), G.add(p, G.mul(d, -2.2)), d))
    # lames pectorales derrière la tête
    i = len(pts) - 8
    q, rq, _ = prof[i]
    for s in (-1, 1):
        base = G.add(q, G.mul(frs[i][1], s * rq * 0.9))
        dd = G.norm(G.add(G.add(G.mul(frs[i][1], s * 1.0), G.mul(frs[i][0], -0.7)), G.mul(frs[i][2], 0.25)))
        lame(lot, M, base, dd, frs[i][2], 6.0, 1.2, 2)


def drone(lot, M):
    """Drone d'escorte : flèche blindée (2,6 unités), œil-cœur, deux ailettes, tuyère turquoise ; flotte à 1,5 unité."""
    z = 1.5
    sec = lambda x, w, h: [(x, -w, z - h), (x, w, z - h), (x, w * 0.7, z + h), (x, -w * 0.7, z + h)]
    lot.put(M["blind"], G.loft([sec(-1.3, 0.35, 0.25), sec(-0.4, 0.6, 0.4), sec(0.6, 0.45, 0.3), sec(1.4, 0.08, 0.06)], True, True))
    lot.put(M["coeur"], G.sphere((0.1, 0.0, z + 0.25), 0.28, 8, 4))
    lot.put(M["halo"], G.sphere((0.1, 0.0, z + 0.25), 0.6, 8, 4))
    for s in (-1, 1):
        lot.put(M["blind2"], plaque((-0.5, s * 0.9, z), G.norm((0.2, 0.0, 1.0)), 0.5, 1.6, 0.1, up=(1, 0, 0)))
        lot.put(M["conduit"], G.tube([(-1.0, s * 0.45, z + 0.12), (0.4, s * 0.3, z + 0.12)], 0.04, 5))
    lot.put(M["turq"], G.oriente(G.tour([(0.0, 0.0), (0.05, 0.22)], 8, "z", cap1=True), (-1.35, 0.0, z), (-1, 0, 0)))
    lot.put(M["cristal"], pointe((1.2, 0.0, z), (1.0, 0.0, 0.0), 0.9, 0.12))


def build(S, lot, stage=1):
    """Construit le Léviathan au stade `stage` (1 à 3), ou son drone d'escorte (stage = « drone »)."""
    M = TM.matieres(S, PREFIX, GRIS)
    lot.xf = XF
    R.raz()
    if stage == "drone":
        drone(lot, M)
        return {"stage": "drone", "pieces": lot.n}
    pts, frs, prof = corps(lot, M, stage)
    tete(lot, M, pts, frs, prof, stage)
    return {"stage": stage, "pieces": lot.n}
