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
# ARTICULÉ (LEVIATHAN-SEG, mandat du DC, 11/11) : le corps n'est plus UNE image rigide. Trois PIÈCES rendues à part, en 16 directions,
# dans le repère local de la pièce (axe le long de +x à la hauteur Z, origine = pivot de la pièce) :
#   - la TÊTE (l'entité) : SERIE, 4 images de marche (la couronne respire, le corps flotte) + 4 de salve (les anneaux s'ouvrent,
#     les drones sortent de la gueule) ; batch_titans.anime (--anime) ;
#   - le SEGMENT de corps (répété n fois par le script) et la QUEUE : PIECES, une image fixe par direction (batch_titans.anime --piece).
# Le script pose les segments le long de la trajectoire de la tête (shared/robots/serpent.lua) : premier segment à 6 tuiles du pivot de
# la tête, puis tous les 5 (longueur d'un segment), la queue 5 derrière le dernier (T.LEVIATHAN.segmente). Les pièces débordent de
# 0,4 tuile à chaque joint (collier sombre) et chaque joint porte une ROTULE (sphère du rayon du corps centrée sur le joint) : deux pièces
# voisines partagent la même sphère, aucun jour ni fond plat quel que soit l'angle entre elles.
SERIE = {"course": 4, "attaque": 4, "densite": 15.0, "R": 13.0, "zmax": 19.5, "sol": 400.0, "dirs": 16}
PIECES = {"segment": {"R": 7.0, "zmax": 16.5, "sol": 400.0, "dirs": 16}, "queue": {"R": 10.5, "zmax": 16.5, "sol": 400.0, "dirs": 16}}
AO = 0.6
GLOW_BLANC = False
FOULEE = 4.5                 # tuiles par cycle de la marche de la tête (respiration de la couronne) : vitesse d'animation du script
Z = 9.6                      # hauteur de l'axe (il flotte) : la même pour les trois pièces, les joints s'alignent
R_CORPS = 2.6                # rayon du corps (segments, base de la tête et de la queue)
DEMI = 2.5                   # demi-longueur d'un segment (joint à ±DEMI) ; espacement du script = 2 × DEMI
DEBORD = 0.4                 # débord du tube au-delà du joint
ONDE = (1.4, 0.35)           # amplitude latérale à la queue, amplitude verticale
ATTAQUE = ((0.3, 0), (0.7, 1), (1.0, 2), (0.6, 3))   # par image : ouverture des anneaux, drones sortis de la gueule
DRONE_K = 1.7                # échelle des drones de la salve (le drone d'escorte du script garde son image)


def XF(v):
    p = G.rot_z(v, PSI)
    return (p[0] * KE, p[1] * KE, max(0.0, p[2] * KE))


def XF0(v):
    """Repère local sans lacet : la série animée est tournée 8 fois par batch_titans.anime."""
    return (v[0] * KE, v[1] * KE, max(0.0, v[2] * KE))


def colonne(u):
    """Points de contrôle de la colonne : CTRL au repos ; en nage, une onde court de la tête vers la queue (phase u), plus forte à la queue."""
    if u is None:
        return CTRL
    n = len(CTRL)
    out = []
    for i, (x, y, z) in enumerate(CTRL):
        t = i / float(n - 1)
        ph = G.TAU * (u + t)
        out.append((x, y + ONDE[0] * (1.0 - 0.7 * t) * math.sin(ph), z + ONDE[1] * math.sin(ph + 1.0)))
    return out


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


def corps(lot, M, stage, u=None, ouvre=0.0):
    """Tube blindé segmenté le long de la colonne, conduits dorsal et latéraux, anneaux, nageoires, nacelle, queue."""
    pts = G.catmull(colonne(u), 6)
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
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", r + 1.3 + 1.4 * ouvre, 0.45, 0.15), p, frs[i][0]))
        if stage >= 3:
            lot.put(M["cristal"], G.oriente(rainure((0.0, 0.0, 0.0), "z", r + 1.35 + 1.4 * ouvre, 0.05), G.add(p, G.mul(frs[i][0], 0.2)), frs[i][0]))
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


def tete(lot, M, pts, frs, prof, stage, ouvre=0.0):
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
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", rc + 2.2 + 1.2 * ouvre, 0.5, 0.16), G.add(p, G.mul(d, -0.8)), d))
    if stage >= 3:
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", rc + 3.4 + 1.6 * ouvre, 0.6, 0.2), G.add(p, G.mul(d, -2.2)), d))
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


def build(S, lot, stage=1, u=None, attaque=None, dirs=False):
    """Construit le Léviathan au stade `stage` (1 à 3), ou son drone d'escorte (stage = « drone ») : repos (lacet PSI), nage (u) ou
    salve (attaque) sans lacet (dirs : 8 directions)."""
    M = TM.matieres(S, PREFIX, GRIS)
    xf = XF0 if dirs else XF
    lot.xf = xf
    R.raz()
    if stage == "drone":
        drone(lot, M)
        return {"stage": "drone", "pieces": lot.n}
    ouvre, n_dr = 0.0, 0
    if attaque is not None:
        ouvre, n_dr = ATTAQUE[int(round(attaque * SERIE["attaque"])) % SERIE["attaque"]]
        u = None
    pts, frs, prof = corps(lot, M, stage, u, ouvre)
    tete(lot, M, pts, frs, prof, stage, ouvre)
    # salve : les drones sortent de la gueule, en éventail devant la tête (un de plus par image)
    p, d = prof[-1][0], frs[-1][0]
    for k in range(n_dr):
        s = 1 if k % 2 == 0 else -1
        off = G.add(G.add(p, G.mul(d, 3.0 + 2.2 * k)), (0.0, s * (1.2 + 0.8 * k), 1.5 + 1.1 * k - 1.5))
        lot.xf = (lambda v, o=off: xf((v[0] * DRONE_K + o[0], v[1] * DRONE_K + o[1], v[2] * DRONE_K + o[2])))   # grossis : lisibles à 32 px/tuile
        drone(lot, M)
    lot.xf = xf
    return {"stage": stage, "pieces": lot.n, "u": u, "attaque": attaque}


def droite(x0, x1, z, pas=0.6):
    """Colonne DROITE le long de +x, de x0 à x1 à la hauteur z, un point tous les `pas` environ."""
    n = max(2, int(round((x1 - x0) / pas)) + 1)
    return [(x0 + (x1 - x0) * i / float(n - 1), 0.0, z) for i in range(n)]


def troncon(lot, M, stage, x0, x1, z, rfun, couronnes, joints, anneaux, dorsales, ventrales, ouvre=0.0, t0=0.4, t1=0.85):
    """Tronçon DROIT du corps le long de +x (de x0 à x1, hauteur z, rayon rfun(x)) : tube blindé, couronnes de blindage (plaques en
    écailles, accent magenta), crête cyan, lignes latérales turquoise, colliers de joint, anneaux de lévitation, nageoires.
    Mêmes pièces et mêmes repères (_frames) que le corps d'un seul tenant (corps()) : matière et éclairage identiques."""
    pts = droite(x0, x1, z)
    frs = G._frames(pts)
    n = len(pts)
    prof = [(p, rfun(p[0]), t0 + (t1 - t0) * i / float(n - 1)) for i, p in enumerate(pts)]
    lot.put(M["blind2"], G.loft([ring(p, frs[i], prof[i][1], 10, 0.3 if (i // 3) % 2 else 0.0) for i, p in enumerate(pts)], True, True))
    fr = frs[0]
    d = fr[0]

    def a_x(x):
        return (x, 0.0, z)
    for xc in couronnes:
        p, r = a_x(xc), rfun(xc)
        seg = [ring(G.add(p, G.mul(d, -0.75)), fr, r * 1.04, 10), ring(G.add(p, G.mul(d, -0.55)), fr, r * 1.22, 10),
               ring(G.add(p, G.mul(d, 0.55)), fr, r * 1.22, 10), ring(G.add(p, G.mul(d, 0.75)), fr, r * 1.04, 10)]
        lot.put(M["blind"], G.loft(seg, False, False))
        lot.put(M["struct"], G.loft([ring(G.add(p, G.mul(d, 0.95)), fr, r * 1.06, 10), ring(G.add(p, G.mul(d, 1.3)), fr, r * 1.0, 10)], False, False))
        for s_ in (-1, 1):
            q = G.add(p, G.add(G.mul(fr[2], r * 0.95), G.mul(fr[1], s_ * r * 0.45)))
            lot.put(M["blind"], plaque(q, G.norm(G.add(fr[2], G.mul(fr[1], s_ * 0.5))), r * 0.7, 1.3, 0.3, up=d, coins=0.7))
        lot.put(M["accent"], G.boite(G.add(p, G.add(G.mul(d, 1.1), G.mul(fr[1], r * 1.02))), (0.3, 0.2, 0.35)))
    for xj in joints:
        p, r = a_x(xj), rfun(xj)
        # ROTULE : sphère de blindage centrée sur le joint, du rayon du corps : deux pièces voisines ont la même sphère au même endroit du
        # monde, quel que soit l'angle entre elles et l'ordre de dessin ; elle cache les fonds plats des tubes
        lot.put(M["blind2"], G.sphere(p, r * 1.02, 16, 8))
        lot.put(M["struct"], G.loft([ring(G.add(p, G.mul(d, -0.25)), fr, r * 1.10, 10), ring(p, fr, r * 1.16, 10),
                                     ring(G.add(p, G.mul(d, 0.25)), fr, r * 1.10, 10)], True, True))
        lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", r * 1.17, 0.05), p, d))
    dors = [G.add(pts[i], G.mul(frs[i][2], prof[i][1] * 1.0 + 0.05)) for i in range(1, n - 1)]
    lot.put(M["conduit"], G.tube(dors, 0.11, 6))
    for s_ in (-1, 1):
        lat = [G.add(pts[i], G.add(G.mul(frs[i][1], s_ * prof[i][1] * 0.98), G.mul(frs[i][2], -prof[i][1] * 0.1))) for i in range(1, n - 1)]
        lot.put(M["turq"], G.tube(lat, 0.08, 6))
    for xa in anneaux:
        p, r = a_x(xa), rfun(xa)
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", r + 1.3 + 1.4 * ouvre, 0.45, 0.15), p, d))
        if stage >= 3:
            lot.put(M["cristal"], G.oriente(rainure((0.0, 0.0, 0.0), "z", r + 1.35 + 1.4 * ouvre, 0.05), G.add(p, G.mul(d, 0.2)), d))
    for xd, L in dorsales:
        p, r = a_x(xd), rfun(xd)
        base = G.add(p, G.mul(fr[2], r * 0.9))
        dd = G.norm(G.add(G.mul(fr[2], 1.0), G.mul(fr[0], -0.55)))
        lame(lot, M, base, dd, fr[1], L, 1.3, 2)
    if stage >= 2:
        for xv in ventrales:
            p, r = a_x(xv), rfun(xv)
            for s_ in (-1, 1):
                base = G.add(p, G.add(G.mul(fr[2], -r * 0.6), G.mul(fr[1], s_ * r * 0.6)))
                dd = G.norm(G.add(G.add(G.mul(fr[2], -0.8), G.mul(fr[1], s_ * 0.9)), G.mul(fr[0], -0.5)))
                lame(lot, M, base, dd, fr[2], 4.2, 1.0, 1)
    return pts, frs, prof


def tete_piece(lot, M, stage, u=None, attaque=None):
    """TÊTE seule (pivot à l'origine) : tronçon qui s'évase vers la gueule (joint arrière à -(DEMI + 1)), gueule et lames pectorales de
    tete() ; marche : la couronne respire (anneaux à peine ouverts) et la tête flotte ; salve : ATTAQUE (anneaux ouverts, drones)."""
    ouvre, n_dr, dz = 0.0, 0, 0.0
    if attaque is not None:
        ouvre, n_dr = ATTAQUE[int(round(attaque * SERIE["attaque"])) % SERIE["attaque"]]
    elif u is not None:
        ouvre = 0.12 * (0.5 - 0.5 * math.cos(G.TAU * u))
        dz = 0.15 * math.sin(G.TAU * u)
    z = Z + dz
    xj = -(DEMI + 1.0)
    rf = lambda x: R_CORPS + 0.8 * max(0.0, (x + 0.5) / 3.0) ** 1.5
    pts, frs, prof = troncon(lot, M, stage, xj - DEBORD, 2.5, z, rf, couronnes=(-1.6,), joints=(xj,), anneaux=(), dorsales=((-0.9, 5.2),),
                             ventrales=(-1.0,), ouvre=ouvre, t0=0.86, t1=1.0)
    tete(lot, M, pts, frs, prof, stage, ouvre)
    p, d = prof[-1][0], frs[-1][0]
    for k in range(n_dr):
        s_ = 1 if k % 2 == 0 else -1
        off = G.add(G.add(p, G.mul(d, 3.0 + 2.2 * k)), (0.0, s_ * (1.2 + 0.8 * k), 1.5 + 1.1 * k - 1.5))
        lot.xf = (lambda v, o=off: XF0((v[0] * DRONE_K + o[0], v[1] * DRONE_K + o[1], v[2] * DRONE_K + o[2])))
        drone(lot, M)
    lot.xf = XF0


def segment_piece(lot, M, stage):
    """SEGMENT de corps (centre à l'origine, joints à ±DEMI) : deux couronnes, un anneau de lévitation au milieu, une nageoire dorsale,
    deux ventrales (stade 2+), cristal sur l'anneau (stade 3)."""
    troncon(lot, M, stage, -DEMI - DEBORD, DEMI + DEBORD, Z, lambda x: R_CORPS, couronnes=(-1.55, 1.55), joints=(-DEMI, DEMI), anneaux=(0.0,),
            dorsales=((-0.4, 5.0),), ventrales=(0.9,), t0=0.4, t1=0.6)


def queue_piece(lot, M, stage):
    """QUEUE (pivot à l'origine, joint avant à +DEMI) : tube qui s'effile jusqu'à la pointe de cristal (x = -6,5), deux lames ; un anneau
    de lévitation (stade 2+)."""
    xt = -6.5
    rf = lambda x: R_CORPS if x >= 0.0 else 0.45 + (R_CORPS - 0.45) * max(0.0, (x - xt) / -xt) ** 1.3
    pts, frs, prof = troncon(lot, M, stage, xt, DEMI + DEBORD, Z, rf, couronnes=(1.2,), joints=(DEMI,), anneaux=((-0.8,) if stage >= 2 else ()),
                             dorsales=((-1.6, 3.6),), ventrales=(), t0=0.0, t1=0.3)
    fr0 = frs[0]
    tip = pts[0]
    lot.put(M["cristal"], pointe(G.add(tip, G.mul(fr0[0], 0.3)), G.mul(fr0[0], -1.0), 3.0, 0.4))
    for s_ in (-1, 1):
        lame(lot, M, G.add(pts[3], G.mul(fr0[1], s_ * 0.5)), G.norm(G.add(G.mul(fr0[1], s_ * 0.9), G.mul(fr0[0], -0.6))), fr0[2], 2.6, 0.6, 1)


def build_anime(S, lot, stage, u, attaque):
    """Entrée des titans animés (batch_titans.anime) : la TÊTE seule (LEVIATHAN-SEG), phase de marche ou de salve, sans lacet."""
    M = TM.matieres(S, PREFIX, GRIS)
    lot.xf = XF0
    R.raz()
    tete_piece(lot, M, stage, u=u if attaque is None else None, attaque=attaque)
    return {"stage": stage, "pieces": lot.n, "u": u, "attaque": attaque}


def build_piece(S, lot, stage, piece):
    """Pièce fixe (batch_titans.anime --piece) : « segment » ou « queue », sans lacet (16 directions)."""
    M = TM.matieres(S, PREFIX, GRIS)
    lot.xf = XF0
    R.raz()
    {"segment": segment_piece, "queue": queue_piece}[piece](lot, M, stage)
    return {"stage": stage, "piece": piece, "pieces": lot.n}
