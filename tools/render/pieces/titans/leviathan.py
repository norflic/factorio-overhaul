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
SERIE = {"course": 4, "attaque": 4, "densite": 22.0, "R": 13.0, "zmax": 19.5, "sol": 400.0, "dirs": 16}
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



# ======================================================================================================================================
# LEVIATHAN2 (ordre du DC, 11/11 09 h 47) : « tête blindée massive à gueule d'impulsion, 4 segments intermédiaires à crêtes dorsales et
# anneaux magnétiques externes, queue motrice effilée ; relief et ombres portées franches ». Mêmes repères et mêmes joints que
# LEVIATHAN-SEG (Z, R_CORPS, DEMI, DEBORD, rotules) : le script (serpent.lua) ne change pas. Blindage OCTOGONAL BISEAUTÉ (facettes nettes,
# reflets argent/iridescents), bandes TÉLESCOPIQUES qui se chevauchent (une lèvre en saillie par bande : marche d'ombre franche), crêtes
# dorsales en lames étagées sur une échine, anneaux magnétiques DÉTACHÉS du corps (bras, émetteurs, gorge lumineuse), cœurs à vortex
# cyan sur les flancs (lunette blindée, pales en spirale). Crêtes FIXES (en relief) : pas d'animation des segments (temps du crunch).
# Concept de référence : concept-enm9m7 (gueule circulaire à double couronne de crocs, vortex central, lames dorsales, anneaux).
# ======================================================================================================================================
SOLEIL_ANGLE = 0.6           # diamètre apparent du soleil (degrés) pour CE titan : ombres portées franches (batch_titans.anime le lit)


def sect(x, r, n=8, ch=0.2, rot=0.0, sy=1.0, sz=1.0, dz=0.0):
    """Section OCTOGONALE BISEAUTÉE autour de l'axe x (centre (x, 0, Z + dz)) : n sommets de rayon r, chaque coin coupé (ch) : 2n
    points, même sens de parcours que ring() : faces planes nettes, reflets francs."""
    zc = Z + dz
    V = []
    for k in range(n):
        a = rot + G.TAU * (k + 0.5) / n
        V.append((r * sy * math.cos(a), r * sz * math.sin(a)))
    out = []
    for k in range(n):
        p, a, b = V[k], V[k - 1], V[(k + 1) % n]
        for q in ((p[0] + (a[0] - p[0]) * ch * 0.5, p[1] + (a[1] - p[1]) * ch * 0.5), (p[0] + (b[0] - p[0]) * ch * 0.5, p[1] + (b[1] - p[1]) * ch * 0.5)):
            out.append((x, q[0], zc + q[1]))
    return out


def bande(lot, M, xa, xb, r, lip=1.2, mat="blind", n=8, rot=0.0, sy=1.0, sz=1.0, dz=0.0):
    """Bande de blindage TÉLESCOPIQUE de xa (arrière) à xb (avant) : lèvre avant en saillie (r × lip) qui retombe en biseau vers
    l'arrière ; la bande suivante la recouvre : marche d'ombre franche à chaque bande."""
    L = xb - xa
    k = lip - 1.0
    secs = [sect(xa, r, n, 0.2, rot, sy, sz, dz), sect(xa + 0.08 * L, r * (1.0 + k * 0.55), n, 0.2, rot, sy, sz, dz),
            sect(xb - 0.22 * L, r * (1.0 + k * 0.8), n, 0.2, rot, sy, sz, dz), sect(xb - 0.04 * L, r * lip, n, 0.2, rot, sy, sz, dz),
            sect(xb, r * (1.0 + k * 0.45), n, 0.2, rot, sy, sz, dz)]
    lot.put(M[mat], G.loft(secs, False, False))


def lunette_vortex(lot, M, c, n, r, pales=5):
    """Cœur à VORTEX cyan posé en c (normale n) : lunette blindée, puits sombre, disque lumineux, pales en spirale, halo."""
    n = G.norm(n)
    lot.put(M["blind"], G.oriente(anneau((0.0, 0.0, 0.0), "z", r * 0.78, r * 0.42, r * 0.22), c, n))
    lot.put(M["struct"], G.oriente(G.tour([(-0.25 * r, 0.0), (-0.25 * r, r * 0.8), (0.1 * r, r * 0.8)], 16, "z", cap0=True), c, n))
    lot.put(M["coeur"], G.oriente(G.tour([(-0.12 * r, 0.0), (-0.12 * r, r * 0.62)], 16, "z", cap0=True), c, n))
    e1 = G.norm(G.cross(n, (0.0, 0.0, 1.0) if abs(n[2]) < 0.9 else (1.0, 0.0, 0.0)))
    e2 = G.cross(n, e1)
    for k in range(pales):
        a0 = G.TAU * k / pales
        pts = []
        for j in range(6):
            t = j / 5.0
            a = a0 + 1.6 * t
            rr = r * (0.66 - 0.5 * t)
            pts.append(G.add(G.add(c, G.mul(n, -0.04 * r)), G.add(G.mul(e1, rr * math.cos(a)), G.mul(e2, rr * math.sin(a)))))
        lot.put(M["turq"], G.tube(pts, 0.045 * r + 0.02, 5))
    lot.put(M["halo"], G.sphere(G.add(c, G.mul(n, 0.05 * r)), r * 0.55, 10, 5))


def anneau_magnetique(lot, M, x, r_int, stage, ouvre=0.0, bras=4, dz=0.0, r_corps=None):
    """Anneau magnétique EXTERNE détaché du corps (axe x) : couronne blindée, gorge lumineuse, émetteurs, bras de maintien."""
    c = (x, 0.0, Z + dz)
    d = (1.0, 0.0, 0.0)
    ri = r_int + 1.35 * ouvre
    rc = R_CORPS if r_corps is None else r_corps
    lot.put(M["blind2"], G.oriente(anneau((0.0, 0.0, 0.0), "z", ri, 0.55, 0.24), c, d))
    lot.put(M["struct"], G.oriente(anneau((0.0, 0.0, 0.0), "z", ri - 0.12, 0.2, 0.33), c, d))
    lot.put(M["anneau"], G.oriente(rainure((0.0, 0.0, 0.0), "z", ri + 0.57, 0.1), c, d))
    lot.put(M["conduit"], G.oriente(rainure((0.0, 0.0, 0.0), "z", ri - 0.13, 0.05), G.add(c, (0.34, 0.0, 0.0)), d))
    for k in range(bras):
        a = G.TAU * (k + 0.5) / bras
        u = (0.0, math.cos(a), math.sin(a))
        e = G.add(c, G.mul(u, ri + 0.3))
        lot.put(M["struct"], G.tube([G.add(c, G.mul(u, rc * 0.95)), G.add(c, G.mul(u, ri - 0.1))], 0.16, 6))
        lot.put(M["blind"], G.oriente(G.tour([(-0.35, 0.0), (-0.35, 0.34), (0.2, 0.28), (0.42, 0.0)], 6, "z", cap0=True), e, u))
        lot.put(M["coeur"], G.sphere(G.add(e, G.mul(u, 0.42)), 0.13, 6, 3))
        if stage >= 3:
            lot.put(M["cristal"], pointe(G.add(e, G.mul(u, 0.35)), u, 1.1, 0.16, 5))


def echine(lot, M, xa, xb, r, hauts, k_grav=2, dz=0.0):
    """CRÊTE DORSALE : échine (prisme biseauté) de xa à xb sur le dos, lames étagées (hauts : longueurs, d'avant en arrière), chacune
    gravée de circuits et flanquée de deux écailles."""
    zt = Z + dz + r
    lot.put(M["struct"], G.loft([[(x, -0.38, zt - 0.25), (x, 0.38, zt - 0.25), (x, 0.22, zt + 0.22), (x, -0.22, zt + 0.22)] for x in (xa, xb)], True, True))
    lot.put(M["conduit"], G.tube([(xa, 0.0, zt + 0.25), (xb, 0.0, zt + 0.25)], 0.07, 5))
    nb = len(hauts)
    for i, L in enumerate(hauts):
        x = xb - (xb - xa) * (i + 0.5) / nb
        lame(lot, M, (x + 0.25, 0.0, zt + 0.1), G.norm((-0.62, 0.0, 1.0)), (0.0, 1.0, 0.0), L, 0.85, k_grav)
        for s_ in (-1, 1):
            lot.put(M["blind"], plaque((x + 0.1, s_ * r * 0.42, zt - 0.12), G.norm((0.15, s_ * 0.55, 1.0)), 0.9, 1.1, 0.18, up=(1.0, 0.0, 0.0), coins=0.65))


def rotule(lot, M, xj, r, dz=0.0):
    """Joint : ROTULE (sphère du rayon du corps, partagée par les deux pièces voisines), collier biseauté et gorge turquoise."""
    p = (xj, 0.0, Z + dz)
    lot.put(M["blind2"], G.sphere(p, r * 1.02, 16, 8))
    lot.put(M["struct"], G.loft([sect(xj - 0.28, r * 1.08, 8, 0.25, dz=dz), sect(xj, r * 1.16, 8, 0.25, dz=dz), sect(xj + 0.28, r * 1.08, 8, 0.25, dz=dz)], True, True))
    lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", r * 1.17, 0.05), p, (1.0, 0.0, 0.0)))


def flancs(lot, M, x0, x1, r, dz=0.0):
    """Lignes latérales turquoise et quille ventrale."""
    for s_ in (-1, 1):
        lot.put(M["turq"], G.tube([(x0, s_ * r, Z + dz - r * 0.12), (x1, s_ * r, Z + dz - r * 0.12)], 0.07, 5))
    lot.put(M["blind"], G.loft([[(x, -0.3, Z + dz - r * 0.92), (x, 0.3, Z + dz - r * 0.92), (x, 0.08, Z + dz - r * 1.28), (x, -0.08, Z + dz - r * 1.28)]
                                for x in (x0 + 0.3, x1 - 0.3)], True, True))


def segment_v2(lot, M, stage):
    """SEGMENT intermédiaire (centre à l'origine, joints à ±DEMI) : âme octogonale, trois bandes télescopiques, crête dorsale (3 lames
    étagées, 4 au stade 3), anneau magnétique EXTERNE détaché, quatre cœurs à vortex sur les flancs, quille ; stade 2+ : nageoires
    ventrales ; stade 3 : cristaux sur l'anneau."""
    r = R_CORPS
    x0, x1 = -DEMI - DEBORD, DEMI + DEBORD
    lot.put(M["struct"], G.loft([sect(x, r * 0.97, 8, 0.2, rot=G.TAU / 16) for x in (x0, x1)], True, True))
    for xa, xb in ((-2.55, -0.85), (-0.95, 0.75), (0.65, 2.45)):
        bande(lot, M, xa, xb, r, lip=1.17)
    rotule(lot, M, -DEMI, r)
    rotule(lot, M, DEMI, r)
    echine(lot, M, -2.0, 2.0, r * 1.14, (3.4, 4.3, 3.2) if stage < 3 else (3.0, 4.4, 3.8, 2.6))
    anneau_magnetique(lot, M, -0.1, r + 1.15, stage)
    for s_ in (-1, 1):
        lunette_vortex(lot, M, (1.55, s_ * r * 1.13, Z + 0.1), (0.0, float(s_), 0.12), 0.85)
        lunette_vortex(lot, M, (-1.75, s_ * r * 1.13, Z + 0.1), (0.0, float(s_), 0.12), 0.7)
    flancs(lot, M, x0, x1, r * 1.12)
    if stage >= 2:
        for s_ in (-1, 1):
            lame(lot, M, (0.9, s_ * r * 0.7, Z - r * 0.75), G.norm((-0.5, s_ * 0.9, -0.8)), (0.0, 0.0, 1.0), 3.4, 0.8, 1)


def queue_v2(lot, M, stage):
    """QUEUE MOTRICE EFFILÉE (pivot à l'origine, joint avant à +DEMI) : bandes télescopiques qui s'effilent, petite crête, anneau(x)
    magnétique(s) qui rapetissent, PROPULSEUR à tuyère (vortex, anneau lumineux, halo) entre quatre ailerons en croix ; pointe de
    cristal au stade 3."""
    xt = -6.6
    rf = lambda x: R_CORPS if x >= 0.0 else 0.75 + (R_CORPS - 0.75) * max(0.0, (x - xt) / -xt) ** 1.15
    x1 = DEMI + DEBORD
    xs = [xt + (x1 - xt) * i / 14.0 for i in range(15)]
    lot.put(M["struct"], G.loft([sect(x, rf(x) * 0.97, 8, 0.2, rot=G.TAU / 16) for x in xs], False, True))
    for xa, xb in ((1.0, 2.5), (-0.8, 1.15), (-2.6, -0.65), (-4.3, -2.45), (-5.9, -4.15)):
        bande(lot, M, xa, xb, rf(0.5 * (xa + xb)), lip=1.18)
    rotule(lot, M, DEMI, R_CORPS)
    echine(lot, M, -3.8, 1.8, R_CORPS * 0.95, (3.0, 2.4, 1.7), k_grav=1)
    anneau_magnetique(lot, M, 0.2, R_CORPS + 1.0, stage)
    if stage >= 2:
        anneau_magnetique(lot, M, -3.4, rf(-3.4) + 0.8, stage, bras=3, r_corps=rf(-3.4))
    for s_ in (-1, 1):
        lunette_vortex(lot, M, (1.6, s_ * R_CORPS * 1.12, Z + 0.1), (0.0, float(s_), 0.12), 0.75)
    # propulseur : tuyère blindée évasée, puits, vortex à pales, anneau lumineux, halo d'impulsion
    xn = xt - 0.1
    d = (-1.0, 0.0, 0.0)
    c = (xn, 0.0, Z)
    lot.put(M["canon"], G.oriente(G.tour([(0.0, 0.8), (0.5, 0.95), (1.1, 1.25), (1.35, 1.3), (1.35, 1.05), (0.6, 0.72), (0.4, 0.0)], 16, "z"), c, d))
    lot.put(M["coeur"], G.oriente(G.tour([(0.55, 0.0), (0.55, 0.78)], 16, "z", cap0=True), c, d))
    lot.put(M["anneau"], G.oriente(rainure((0.0, 0.0, 0.0), "z", 1.3, 0.06), G.add(c, G.mul(d, 1.36)), d))
    lot.put(M["halo"], G.sphere(G.add(c, G.mul(d, 1.5)), 0.95, 12, 6))
    for k in range(5):
        a0 = G.TAU * k / 5
        pts = [G.add(c, (-(0.6 + 0.12 * j), 0.95 * (1 - j / 6.0) * math.cos(a0 + 0.5 * j), 0.95 * (1 - j / 6.0) * math.sin(a0 + 0.5 * j))) for j in range(5)]
        lot.put(M["turq"], G.tube(pts, 0.05, 4))
    for k in range(4):
        a = G.TAU * (k + 0.5) / 4
        u = (0.0, math.cos(a), math.sin(a))
        base = G.add((xt + 1.4, 0.0, Z), G.mul(u, 0.85))
        lame(lot, M, base, G.norm(G.add(u, (-0.75, 0.0, 0.0))), G.norm(G.cross((1.0, 0.0, 0.0), u)), 2.5, 0.7, 1)
    if stage >= 3:
        lot.put(M["cristal"], pointe(G.add(c, G.mul(d, 0.2)), d, 2.6, 0.22))


def tete_v2(lot, M, stage, u=None, attaque=None):
    """TÊTE BLINDÉE MASSIVE à GUEULE D'IMPULSION (pivot à l'origine, joint arrière à -(DEMI + 1)) : cou télescopique, crâne octogonal
    biseauté évasé (plus large que haut), arcades blindées, quatre mandibules, gueule circulaire à double couronne de crocs, VORTEX
    central à pales en spirale, anneaux d'impulsion devant la gueule (la salve les écarte), crête de trois lames, yeux et évents cyan,
    lames pectorales ; stade 2+ : anneau magnétique du cou ; stade 3 : couronne de cristaux."""
    ouvre, n_dr, dz = 0.0, 0, 0.0
    if attaque is not None:
        ouvre, n_dr = ATTAQUE[int(round(attaque * SERIE["attaque"])) % SERIE["attaque"]]
    elif u is not None:
        ouvre = 0.12 * (0.5 - 0.5 * math.cos(G.TAU * u))
        dz = 0.15 * math.sin(G.TAU * u)
    r = R_CORPS
    xj = -(DEMI + 1.0)
    zc = Z + dz
    # cou : âme, deux bandes, rotule
    lot.put(M["struct"], G.loft([sect(x, r * 0.97, 8, 0.2, rot=G.TAU / 16, dz=dz) for x in (xj - DEBORD, -0.6)], True, False))
    bande(lot, M, -3.1, -1.75, r, lip=1.17, dz=dz)
    bande(lot, M, -1.95, -0.55, r * 1.04, lip=1.2, dz=dz)
    rotule(lot, M, xj, r, dz=dz)
    # crâne : octogone biseauté qui s'évase vers la gueule, aplati (sy > sz), trois bandes en recouvrement
    RF = 4.6      # 0.6.96 : tête MASSIVE (1,5 fois les bandes du corps ; 3,75 au premier essai, trop proche du corps)
    sk = [(-0.8, r * 1.05), (0.2, 3.5), (1.3, 4.2), (2.4, RF), (3.0, RF * 1.04)]

    def rk(x):
        """Rayon du crâne en x (interpolé sur sk) : les pièces posées dessus suivent le crâne."""
        if x <= sk[0][0]:
            return sk[0][1]
        for (xa, ra), (xb, rb) in zip(sk, sk[1:]):
            if x <= xb:
                return ra + (rb - ra) * (x - xa) / (xb - xa)
        return sk[-1][1]
    lot.put(M["blind2"], G.loft([sect(x, rr, 8, 0.28, sy=1.12, sz=0.92, dz=dz) for x, rr in sk], False, False))
    bande(lot, M, -0.7, 0.55, rk(-0.1), lip=1.12, sy=1.12, sz=0.92, dz=dz)
    bande(lot, M, 0.45, 1.75, rk(1.1), lip=1.1, sy=1.12, sz=0.92, dz=dz)
    bande(lot, M, 1.65, 3.05, RF, lip=1.1, sy=1.12, sz=0.92, dz=dz)
    c = (3.05, 0.0, zc)
    d = (1.0, 0.0, 0.0)
    # gueule : collerette blindée épaisse, gencive (chair), double couronne de crocs, puits, vortex et pales en spirale, halo
    lot.put(M["blind"], G.oriente(G.tour([(-0.2, RF * 1.12), (0.25, RF * 1.12), (0.55, RF * 1.02), (0.55, RF * 0.8), (0.3, RF * 0.72)], 32, "z"), c, d))
    lot.put(M["chair"], G.oriente(G.tour([(0.32, RF * 0.74), (-0.1, RF * 0.6), (-0.6, RF * 0.5)], 32, "z"), c, d))
    lot.put(M["struct"], G.oriente(G.tour([(-0.6, RF * 0.5), (-1.3, RF * 0.42), (-1.45, 0.0)], 24, "z"), c, d))
    for k in range(18):
        a = G.TAU * k / 18
        off = (0.0, math.cos(a), math.sin(a))
        lot.put(M["os"], pointe(G.add(c, G.add(G.mul(off, RF * 0.72), (0.2, 0.0, 0.0))), G.norm(G.add(G.mul(off, -1.0), (0.45, 0.0, 0.0))), 0.95, 0.16, 4))
    for k in range(12):
        a = G.TAU * (k + 0.5) / 12
        off = (0.0, math.cos(a), math.sin(a))
        lot.put(M["os"], pointe(G.add(c, G.add(G.mul(off, RF * 0.52), (-0.45, 0.0, 0.0))), G.norm(G.add(G.mul(off, -1.0), (0.3, 0.0, 0.0))), 0.7, 0.12, 4))
    vc = G.add(c, (-1.25, 0.0, 0.0))
    lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.0), (0.05, RF * 0.36)], 20, "z", cap1=True), vc, d))
    lot.put(M["coeur"], G.sphere(G.add(vc, (0.35, 0.0, 0.0)), 0.62, 14, 7))
    for k in range(6):
        a0 = G.TAU * k / 6
        pts = [G.add(vc, (0.1 + 0.12 * j, RF * (0.4 - 0.05 * j) * math.cos(a0 + 0.45 * j), RF * (0.4 - 0.05 * j) * math.sin(a0 + 0.45 * j))) for j in range(6)]
        lot.put(M["turq"], G.tube(pts, 0.06, 4))
    lot.put(M["halo"], G.sphere(G.add(c, (-0.3, 0.0, 0.0)), RF * 0.62, 18, 9))
    # anneaux d'impulsion devant la gueule (la salve les écarte)
    for k, (dx, rr) in enumerate(((0.9, RF * 0.62), (1.7, RF * 0.48), (2.4, RF * 0.36))):
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", rr * (1.0 + 0.25 * ouvre), 0.16, 0.06), G.add(c, (dx + 1.6 * ouvre * (k + 1), 0.0, 0.0)), d))
    # quatre mandibules blindées (en X), courbées vers l'axe, croc au bout
    for k in range(4):
        a = G.TAU * (k + 0.5) / 4
        off = (0.0, math.cos(a) * 1.12, math.sin(a) * 0.92)
        base = G.add(c, G.add(G.mul(off, RF * 0.95), (-0.3, 0.0, 0.0)))
        dd = G.norm(G.add(d, G.mul(off, -0.32)))
        nn = G.norm(G.cross(dd, off))
        lame(lot, M, base, dd, nn, 2.6, 0.75, 1)
        lot.put(M["os"], pointe(G.add(base, G.mul(dd, 2.3)), G.norm(G.add(dd, G.mul(off, -0.5))), 0.8, 0.14, 4))
    # arcades : deux plaques épaisses au-dessus de la gueule, yeux cyan, évents latéraux
    for s_ in (-1, 1):
        lot.put(M["blind"], plaque((2.1, s_ * RF * 0.45, zc + RF * 0.88), G.norm((0.35, s_ * 0.45, 1.0)), RF * 0.6, RF * 0.7, 0.45, up=(1.0, 0.0, 0.0), coins=0.6))
        e = (2.5, s_ * RF * 0.98, zc + RF * 0.33)
        lot.put(M["struct"], G.oriente(G.tour([(-0.2, 0.0), (-0.2, 0.42), (0.12, 0.4)], 10, "z", cap0=True), e, G.norm((0.3, s_ * 1.0, 0.2))))
        lot.put(M["coeur"], G.sphere(e, 0.27, 10, 5))
        for j in range(3):
            x = 0.55 * j
            yv = 0.924 * 1.12 * rk(x) * 1.1
            lot.put(M["struct"], G.boite((x, s_ * yv, zc - 0.2), (0.34, 0.2, 1.4)))
            lot.put(M["turq"], G.boite((x, s_ * (yv + 0.12), zc - 0.2), (0.12, 0.08, 1.1)))
    # crête : trois lames balayées vers l'arrière sur une échine
    zh = lambda x: zc + 0.924 * 0.92 * rk(x) * 1.1     # dessus du crâne (lèvre des bandes comprise)
    xs = (-0.4, 0.6, 1.6, 2.6)
    lot.put(M["struct"], G.loft([[(x, -0.5, zh(x) - 0.3), (x, 0.5, zh(x) - 0.3), (x, 0.28, zh(x) + 0.3), (x, -0.28, zh(x) + 0.3)] for x in xs], True, True))
    lot.put(M["conduit"], G.tube([(x, 0.0, zh(x) + 0.33) for x in xs], 0.09, 5))
    for x, L in ((2.0, 4.6), (0.9, 5.6), (-0.2, 4.4)):
        lame(lot, M, (x, 0.0, zh(x) + 0.1), G.norm((-0.7, 0.0, 1.0)), (0.0, 1.0, 0.0), L, 1.1, 2)
    # lames pectorales sur le cou, vortex des tempes
    for s_ in (-1, 1):
        lame(lot, M, (-1.6, s_ * r, zc - 0.2), G.norm((-0.75, s_ * 1.0, -0.15)), (0.0, 0.0, 1.0), 4.6, 1.0, 2)
        lunette_vortex(lot, M, (-0.2, s_ * (0.924 * 1.12 * rk(-0.2) * 1.12 + 0.05), zc - 0.1), (0.0, float(s_), 0.15), 0.9)
    flancs(lot, M, xj, -0.5, r * 1.12, dz=dz)
    if stage >= 2:
        anneau_magnetique(lot, M, -2.4, r + 1.25, stage, ouvre=ouvre, dz=dz)
    if stage >= 3:
        for k in range(8):
            a = G.TAU * (k + 0.5) / 8
            off = (0.0, math.cos(a) * 1.12, math.sin(a) * 0.92)
            lot.put(M["cristal"], pointe(G.add(c, G.add(G.mul(off, RF * 1.12), (-0.1, 0.0, 0.0))), G.norm(G.add(off, (0.25, 0.0, 0.0))), 1.6 if k % 2 else 1.1, 0.22, 5))
    # salve : les drones sortent de la gueule (un de plus par image)
    for k in range(n_dr):
        s_ = 1 if k % 2 == 0 else -1
        off = G.add(G.add(c, (3.0 + 2.2 * k, 0.0, 0.0)), (0.0, s_ * (1.2 + 0.8 * k), 1.1 * k))
        lot.xf = (lambda v, o=off: XF0((v[0] * DRONE_K + o[0], v[1] * DRONE_K + o[1], v[2] * DRONE_K + o[2])))
        drone(lot, M)
    lot.xf = XF0


# ------------------------------------------------------------------------------------------------ V3 (s43, 13/11)
# Refonte (le DC : « laid et sans retour visuel »). Vu du dessus (la caméra de Factorio), la V2 n'offrait qu'un tube rayé de bandes
# étroites et de dizaines d'anneaux et de traits cyan fins. V3 : CARAPACE dorsale à grandes plaques lisses très spéculaires (deux par
# segment, en recouvrement : le dos se lit comme un cloporte blindé), UN anneau de lévitation épais par segment posé sur la jointure des
# plaques, une COURONNE DE LÉVITATION horizontale sous le ventre (elle déborde du corps vu du dessus : il flotte), UN gros cœur à vortex
# par flanc, une ligne d'échine cyan continue d'une pièce à l'autre (elle dessine la trajectoire). Mêmes joints, même Z, mêmes rotules,
# mêmes cadres (PIECES, SERIE) : serpent.lua, titans_serpent.lua, T.LEVIATHAN et le format des feuilles sont inchangés.
import titans_v3 as V3  # noqa: E402

RC = 1.32            # rayon de la carapace / rayon du corps


def echine_v3(lot, M, xa, xb, rfun, stage, pointes=()):
    """Arête d'échine sur le dos de la carapace (prisme sombre) et sa ligne cyan ; pointes (os, cristal au stade 3) aux x donnés."""
    xs = [xa + (xb - xa) * i / 6.0 for i in range(7)]
    zt = lambda x: Z + rfun(x) * RC * 1.06
    lot.put(M["struct"], G.loft([[(x, -0.42, zt(x) - 0.35), (x, 0.42, zt(x) - 0.35), (x, 0.2, zt(x) + 0.28), (x, -0.2, zt(x) + 0.28)] for x in xs], True, True))
    lot.put(M["conduit"], G.tube([(x, 0.0, zt(x) + 0.3) for x in xs], 0.1, 6))
    for x in pointes:
        mat = "cristal" if stage >= 3 else "os"
        lot.put(M[mat], pointe((x, 0.0, zt(x) + 0.2), G.norm((-0.55, 0.0, 1.0)), 1.3 + 0.35 * stage, 0.24, 5))


def couronne_ventrale(lot, M, x, rr, dz=0.0, r_corps=None):
    """COURONNE DE LÉVITATION sous le ventre : tore horizontal épais (cadre blindé, gorge lumineuse), pylône, disque d'impulsion vers le
    sol : elle déborde du corps vu du dessus et dit « il flotte »."""
    rc = R_CORPS if r_corps is None else r_corps
    zr = Z + dz - rc - 1.3
    lot.put(M["blind2"], anneau((x, 0.0, zr), "z", rr, 0.42, 0.2))
    lot.put(M["anneau"], anneau((x, 0.0, zr - 0.05), "z", rr - 0.28, 0.3, 0.12))
    lot.put(M["conduit"], rainure((x, 0.0, zr + 0.22), "z", rr + 0.2, 0.06))
    lot.put(M["struct"], G.tube([(x, 0.0, Z + dz - rc * 0.8), (x, 0.0, zr)], 0.42, 8))
    for k in range(3):
        a = G.TAU * k / 3 + 0.5
        lot.put(M["struct"], G.tube([(x, 0.0, zr + 0.15), (x + rr * math.cos(a), rr * math.sin(a), zr + 0.1)], 0.13, 5))
    lot.put(M["coeur"], G.tour([(0.0, 0.0), (0.0, 0.62)], 16, "z", (x, 0.0, zr - 0.22), cap0=True))
    lot.put(M["halo"], G.sphere((x, 0.0, zr - 0.3), 1.0, 12, 6))


def flanc_v3(lot, M, x, r, dz=0.0, rv=1.05):
    """Gros cœur à vortex sur chaque flanc, sous le bord de la carapace."""
    for s_ in (-1, 1):
        lunette_vortex(lot, M, (x, s_ * r * 1.04, Z + dz - r * 0.42), (0.0, float(s_), -0.38), rv, pales=5)


def segment_v3(lot, M, stage):
    """SEGMENT V3 (centre à l'origine, joints à ±DEMI) : âme, ventre en bandes sombres, deux plaques de CARAPACE en recouvrement,
    anneau magnétique épais sur la jointure, couronne de lévitation ventrale, deux cœurs à vortex (flancs), échine
    cyan ; stade 2 : pointes d'échine ; stade 3 : pointes et anneau en cristal."""
    r = R_CORPS
    x0, x1 = -DEMI - DEBORD, DEMI + DEBORD
    lot.put(M["struct"], G.loft([sect(x, r * 0.97, 8, 0.2, rot=G.TAU / 16) for x in (x0, x1)], True, True))
    for xa, xb in ((-2.55, -0.1), (-0.05, 2.45)):
        bande(lot, M, xa, xb, r, lip=1.1, mat="blind2")
    rotule(lot, M, -DEMI, r)
    rotule(lot, M, DEMI, r)
    for xa, xb in ((-2.75, 0.05), (-0.15, 2.75)):
        V3.carapace(lot, M["blind"], xa, xb, r * RC, Z, ouv=1.6, ep=0.55, lip=1.1, n=6, sy=1.12)
    echine_v3(lot, M, -2.4, 2.4, lambda x: r, stage, pointes=((-1.2, 1.3) if stage >= 2 else ()))
    anneau_magnetique(lot, M, -0.05, r * RC + 0.55, stage, bras=4)
    couronne_ventrale(lot, M, 0.0, 3.5)
    flanc_v3(lot, M, 1.25, r)
    flanc_v3(lot, M, -1.35, r, rv=0.8)


def queue_v3(lot, M, stage):
    """QUEUE V3 (pivot à l'origine, joint avant à +DEMI) : carapace qui s'effile en trois plaques, anneau magnétique, couronne ventrale,
    propulseur à tuyère et vortex (V2), deux stabilisateurs horizontaux et un aileron dorsal ; stade 2 : 2e anneau ; stade 3 : dard de
    cristal."""
    xt = -6.6
    rf = lambda x: R_CORPS if x >= 0.0 else 0.75 + (R_CORPS - 0.75) * max(0.0, (x - xt) / -xt) ** 1.15
    x1 = DEMI + DEBORD
    xs = [xt + (x1 - xt) * i / 14.0 for i in range(15)]
    lot.put(M["struct"], G.loft([sect(x, rf(x) * 0.97, 8, 0.2, rot=G.TAU / 16) for x in xs], False, True))
    for xa, xb in ((0.4, 2.5), (-2.0, 0.55), (-4.4, -1.85), (-6.0, -4.25)):
        bande(lot, M, xa, xb, rf(0.5 * (xa + xb)), lip=1.1, mat="blind2")
    rotule(lot, M, DEMI, R_CORPS)
    for xa, xb in ((0.1, 2.75), (-2.5, 0.25), (-4.9, -2.3)):
        V3.carapace(lot, M["blind"], xa, xb, rf(0.5 * (xa + xb)) * RC, Z, ouv=1.6, ep=0.5, lip=1.1, n=6, sy=1.12)
    echine_v3(lot, M, -4.6, 2.4, rf, stage, pointes=((-3.3, -0.8) if stage >= 2 else ()))
    anneau_magnetique(lot, M, 0.18, R_CORPS * RC + 0.5, stage)
    if stage >= 2:
        anneau_magnetique(lot, M, -2.4, rf(-2.4) * RC + 0.45, stage, bras=3, r_corps=rf(-2.4))
    couronne_ventrale(lot, M, 1.2, 3.2)
    flanc_v3(lot, M, 1.3, R_CORPS, rv=0.85)
    # propulseur (V2) : tuyère blindée évasée, puits, vortex à pales, anneau lumineux, halo d'impulsion
    xn = xt - 0.1
    d = (-1.0, 0.0, 0.0)
    c = (xn, 0.0, Z)
    lot.put(M["canon"], G.oriente(G.tour([(0.0, 0.8), (0.5, 0.95), (1.1, 1.25), (1.35, 1.3), (1.35, 1.05), (0.6, 0.72), (0.4, 0.0)], 16, "z"), c, d))
    lot.put(M["coeur"], G.oriente(G.tour([(0.55, 0.0), (0.55, 0.78)], 16, "z", cap0=True), c, d))
    lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", 1.3, 0.22, 0.08), G.add(c, G.mul(d, 1.36)), d))
    lot.put(M["halo"], G.sphere(G.add(c, G.mul(d, 1.5)), 0.95, 12, 6))
    for k in range(5):
        a0 = G.TAU * k / 5
        pts = [G.add(c, (-(0.6 + 0.12 * j), 0.95 * (1 - j / 6.0) * math.cos(a0 + 0.5 * j), 0.95 * (1 - j / 6.0) * math.sin(a0 + 0.5 * j))) for j in range(5)]
        lot.put(M["turq"], G.tube(pts, 0.05, 4))
    for s_ in (-1, 1):
        lame(lot, M, (xt + 1.6, s_ * 0.8, Z), G.norm((-0.8, s_ * 0.75, 0.0)), (0.0, 0.0, 1.0), 3.0, 0.8, 1)
    lame(lot, M, (xt + 1.8, 0.0, Z + 0.8), G.norm((-0.8, 0.0, 0.7)), (0.0, 1.0, 0.0), 2.4, 0.7, 1)
    if stage >= 3:
        lot.put(M["cristal"], pointe(G.add(c, G.mul(d, 0.2)), d, 2.6, 0.22))


def tete_v3(lot, M, stage, u=None, attaque=None):
    """TÊTE V3 : la tête V2 (crâne massif, gueule d'impulsion, mandibules, crête) dans la palette V3, plus une plaque de carapace sur le
    cou, l'échine cyan qui se prolonge et la couronne de lévitation ventrale."""
    tete_v2(lot, M, stage, u=u, attaque=attaque)
    dz = 0.0
    if attaque is None and u is not None:
        dz = 0.15 * math.sin(G.TAU * u)
    lot.xf = (lambda v: XF0((v[0], v[1], v[2] + dz))) if dz else XF0
    r = R_CORPS
    V3.carapace(lot, M["blind"], -(DEMI + 1.25), -0.7, r * RC, Z, ouv=1.6, ep=0.55, lip=1.1, n=6, sy=1.12)
    echine_v3(lot, M, -(DEMI + 1.0), -0.9, lambda x: r, stage)
    couronne_ventrale(lot, M, -1.9, 3.5)
    lot.xf = XF0


def build_anime(S, lot, stage, u, attaque):
    """Entrée des titans animés (batch_titans.anime) : la TÊTE seule (LEVIATHAN-SEG), phase de marche ou de salve, sans lacet."""
    M = V3.matieres(S, PREFIX, GRIS)
    lot.xf = XF0
    R.raz()
    tete_v3(lot, M, stage, u=u if attaque is None else None, attaque=attaque)
    return {"stage": stage, "pieces": lot.n, "u": u, "attaque": attaque}


def build_piece(S, lot, stage, piece):
    """Pièce fixe (batch_titans.anime --piece) : « segment » ou « queue », sans lacet (16 directions)."""
    M = V3.matieres(S, PREFIX, GRIS)
    lot.xf = XF0
    R.raz()
    {"segment": segment_v3, "queue": queue_v3}[piece](lot, M, stage)
    return {"stage": stage, "piece": piece, "pieces": lot.n}
