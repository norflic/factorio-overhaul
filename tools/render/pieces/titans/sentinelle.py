"""SENTINELLE, titan ALLIÉ (lot TITANS-RECAL, 10/11) : hexapode FLOTTANT, d'après le concept c_pohurb du DC : une SINGULARITÉ centrale
(vortex cyan dans une couronne blindée, halo), canon annulaire à gauche (fût + anneaux de focalisation flottants), tête-canon à droite
(mufle blindé, gueule turquoise), deux ailes-lames dorsales gravées de circuits, six pattes digitigrades qui se terminent en tuyères
(elle ne touche pas le sol : elle lévite, l'ombre est portée sous elle), une SPHÈRE flottante au-dessus du corps (œil-cœur, anneau).
Environ 30 tuiles de haut à l'écran, 34 de large (ailes et canons compris).

Modèle paramétrique low-poly (kit des géants, geo.py), UNE image par stade (1 à 3 = paliers 1-2, 3-4, 5-6) : anneaux de focalisation,
cristaux des ailes et couronne de la singularité s'ajoutent. Repère LOCAL : +x = face, +y = gauche, +z = haut ; PSI : lacet (elle
regarde vers le sud-est, le canon annulaire côté caméra).
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
import titans_charte as TC  # noqa: E402
from juggernaut import hexseg, pointe, plaque, anneau, anneau_seg, rainure, traces, bague  # noqa: E402

PREFIX = "se_"
PSI = -math.radians(40.0)
KE = 1.0
GRIS = os.environ.get("FO_GRIS", "") == "1"
HAUTEUR = 31.0 * KE
RAYON = 17.0 * KE
ZC = 16.5                    # centre de la singularité
# ANIMÉE (TITANS-8DIR, 10/11) : 8 directions × 8 images de marche (flottement, pattes qui ondulent) + 4 de salve (la singularité gonfle
# puis se libère) ; même contrat que juggernaut.py / ravageur.py (SERIE, AO, GLOW_BLANC, FOULEE, build_anime) pour batch_titans.anime.
# ART-16DIR (11/11) : 16 directions réelles ; densité 12 pour tenir 80 Mpx HR (lueur à demi-densité, ombre au quart)
SERIE = {"course": 8, "attaque": 4, "densite": 12.0, "R": 17.5, "zmax": 32.5, "sol": 400.0, "dirs": 16}
AO = 0.6
GLOW_BLANC = False
SKY_GLOSSY = TC.SKY_GLOSSY   # s43 (charte V3) : ciel spéculaire poussé, le blindage sombre vit de ses reflets
FOULEE = 6.0                 # tuiles par cycle de flottement (distance_per_frame du script : FOULEE / images)
BOB = 0.6                    # amplitude du flottement (unités de modèle)
ONDE = (0.6, 0.9)            # ondulation d'une patte : vers l'extérieur, vers le haut
ATTAQUE = ((1.08, 1.1, 0.0), (1.22, 1.35, 0.0), (1.35, 1.6, 0.45), (0.85, 1.9, 1.0))   # par image : singularité, halo, éclat


def XF(v):
    p = G.rot_z(v, PSI)
    return (p[0] * KE, p[1] * KE, max(0.0, p[2] * KE))


def XF0(v):
    """Repère local sans lacet : la série animée est tournée 8 fois par batch_titans.anime."""
    return (v[0] * KE, v[1] * KE, max(0.0, v[2] * KE))


def gravure(lot, M, p, n, up, w, h, k=3):
    """Circuits gravés sur une aile : k traits fins lumineux (turq) parallèles, décalés, posés sur le plan (p, n, up)."""
    ex, ey, ez = R.repere(n, up)
    for i in range(k):
        q = (i - (k - 1) / 2.0) * w * 0.28
        a = G.add(G.add(p, G.mul(ex, q)), G.add(G.mul(ey, -h * 0.35), G.mul(ez, 0.16)))
        b = G.add(G.add(p, G.mul(ex, q * 0.5)), G.add(G.mul(ey, h * (0.25 + 0.1 * i)), G.mul(ez, 0.16)))
        lot.put(M["turq"], G.tube([a, b], 0.07, 5))


def gemme(base, d, L, r, n=6, rot=0.0):
    """TITANS2 (11/11) : cristal bleu glacier TAILLÉ (concept : gemmes à facettes nettes) : bipyramide à n pans, ceinture aux 30 %
    de la longueur, table étroite, posée de `base` dans la direction `d`."""
    prof = [(0.0, r * 0.35), (L * 0.12, r * 0.9), (L * 0.3, r), (L * 0.42, r * 0.86), (L, 0.0)]
    return G.oriente(G.tour(prof, n, "z", a0=rot, a1=rot + G.TAU, cap0=True), base, d)


def grappe(lot, M, base, d, L, r, k=3):
    """Grappe de k gemmes autour d'un axe : une grande au centre, les autres inclinées, plus courtes."""
    lot.put(M["cristal"], gemme(base, d, L, r))
    t, n1, n2 = G._frames([base, G.add(base, d)])[0]
    for i in range(k - 1):
        a = G.TAU * i / max(k - 1, 1) + 0.4
        off = G.add(G.mul(n1, math.cos(a)), G.mul(n2, math.sin(a)))
        lot.put(M["cristal"], gemme(G.add(base, G.mul(off, r * 0.9)), G.norm(G.add(d, G.mul(off, 0.45))), L * (0.62 - 0.08 * i), r * 0.7, 6, 0.3 * i))


def vortex(lot, M, C, rc, e=1.0):
    """TITANS2 : cœur à VORTEX à haute luminosité (concept : spirale cyan blanc au centre de la couronne) : trois bras en spirale
    d'Archimède devant la singularité, un noyau blanc, un disque d'accrétion fin."""
    R_ = (rc - 0.9) * e                       # rayon de la sphère de singularité : les bras épousent sa face avant
    for b in range(3):
        pts = []
        for j in range(14):
            t = j / 13.0
            a = G.TAU * b / 3 + t * 2.6 * math.pi
            rr = (0.35 + (rc - 1.4) * t) * e
            pts.append((C[0] + math.sqrt(max(R_ * R_ - rr * rr, 0.0)) + 0.14, C[1] + rr * math.cos(a), C[2] + rr * math.sin(a)))
        lot.put(M["coeur"], G.tube(pts, 0.2, 6, rfun=lambda s_, i: 0.26 * (1.0 - 0.65 * i / 13.0)))
    lot.put(M["coeur"], G.sphere((C[0] + R_ - 0.25, C[1], C[2]), 0.6 * e, 14, 7))


def corps(lot, M, stage, gonfle=(1.0, 1.0, 0.0)):
    """Couronne blindée autour de la singularité (axe x), vortex et halo, carénage dorsal, ventral et arrière."""
    C = (0.0, 0.0, ZC)
    rc = 4.6
    # couronne : anneau blindé épais (blind) à 8 crans, gorge lumineuse à l'avant
    lot.put(M["blind"], anneau(C, "x", rc, 1.4, 0.9))
    for k in range(8):
        a = G.TAU * (k + 0.5) / 8
        p = (C[0] + 0.3, C[1] + (rc + 1.1) * math.cos(a), C[2] + (rc + 1.1) * math.sin(a))
        lot.put(M["blind2"], plaque(p, G.norm((0.0, math.cos(a), math.sin(a))), 2.2, 1.6, 0.5, up=(1, 0, 0), coins=0.75))
    lot.put(M["turq"], rainure((C[0] + 0.95, C[1], C[2]), "x", rc + 0.2, 0.08))
    lot.put(M["conduit"], rainure((C[0] + 0.95, C[1], C[2]), "x", rc - 0.3, 0.06))
    # singularité : vortex (cœur) + halo large ; sous-disque sombre derrière
    # s43 (contrôle qualité du 13/11 : « grande plage cyan floue qui mange le corps ») : singularité réduite à 0,55 du rayon, posée au fond
    # d'une cuvette sombre ; les bras du vortex (cœur) restent à leur rayon et lui donnent sa forme
    lot.put(M["singularite"], G.sphere((C[0] - 0.4, C[1], C[2]), (rc - 0.9) * 0.55 * gonfle[0], 20, 10))   # FINITIONS 10/11 : profil d'accrétion, cyan profond, 30 % de jour
    lot.put(M["halo"], G.sphere(C, (rc - 1.6) * gonfle[1], 20, 10))   # s43 : halo resserré (la brume de rc + 0,6 couvrait la couronne)
    if gonfle[2] > 0:
        # TITANS-8DIR : la singularité se LIBÈRE : jet lumineux vers l'avant
        e = gonfle[2]
        lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.0), (0.2, 1.6 * e), (3.2 * e, 0.8), (5.0 * e, 0.0)], 14, "z", cap0=True), (C[0] + 1.2, C[1], C[2]), (1.0, 0.0, 0.0)))
    lot.put(M["struct"], G.tour([(-1.0, 0.0), (-0.9, rc - 0.2), (-0.4, rc + 0.3)], 24, "x", C, cap0=True))
    vortex(lot, M, C, rc, gonfle[0])
    # TITANS2 : silhouette en RELIEF (le DC : « corriger la silhouette plate ») : crête de trois lames verticales au sommet de la couronne,
    # grappes de gemmes glacier sur la couronne (haut et flancs), carène ventrale à trois échappements d'énergie vers le sol
    for k, (yy, h) in enumerate(((0.0, 6.8), (-1.7, 5.0), (1.7, 5.0))):
        b0 = (-0.6, yy, ZC + rc + 0.9)
        pts = [b0, (-1.2, yy * 1.15, b0[2] + h * 0.45), (-2.4, yy * 1.25, b0[2] + h * 0.85), (-3.6, yy * 1.3, b0[2] + h)]
        rr = (0.7, 0.52, 0.32, 0.08)
        for j in range(3):
            lot.put(M["blind2"], hexseg(pts[j], pts[j + 1], rr[j], rr[j + 1], 4, 0.785))
        lot.put(M["conduit"], G.tube([G.add(pts[0], (0.45, 0.0, 0.1)), G.add(pts[1], (0.4, 0.0, 0.0)), G.add(pts[2], (0.25, 0.0, 0.0))], 0.07, 4))
    for a_deg, L in ((90.0, 2.6), (40.0, 2.0), (140.0, 2.0), (-40.0, 1.7), (-140.0, 1.7)):
        a = math.radians(a_deg)
        p = (C[0] + 0.2, (rc + 1.5) * math.cos(a), ZC + (rc + 1.5) * math.sin(a))
        grappe(lot, M, p, G.norm((0.25, math.cos(a), math.sin(a))), L + 0.4 * (stage - 1), 0.42, 3)
    for k, (xx, yy) in enumerate(((0.8, 0.0), (-1.6, 1.9), (-1.6, -1.9))):
        b = (xx, yy, ZC - 7.0)
        lot.put(M["canon"], G.oriente(G.tour([(0.0, 0.9), (0.9, 1.05), (1.5, 0.85), (1.6, 0.65)], 12, "z", cap0=True), b, (0, 0, -1)))
        lot.put(M["turq"], G.oriente(rainure((0.0, 0.0, 0.0), "z", 0.7, 0.08), G.add(b, (0.0, 0.0, -1.55)), (0, 0, -1)))
        lot.put(M["coeur"], G.oriente(G.tour([(1.55, 0.6), (2.6, 0.42), (4.2, 0.2), (5.4, 0.0)], 10, "z", cap0=True), b, (0, 0, -1)))
        lot.put(M["halo"], G.oriente(G.tour([(1.5, 1.0), (3.0, 0.8), (5.0, 0.4), (6.2, 0.0)], 10, "z", cap0=True), b, (0, 0, -1)))
    # carénage arrière : coque octogonale derrière la couronne, cheminées et conduits
    lot.put(M["blind2"], G.loft([[(-1.0, (rc + 0.8) * math.cos(G.TAU * (k + 0.5) / 8), ZC + (rc + 0.8) * math.sin(G.TAU * (k + 0.5) / 8)) for k in range(8)],
                                 [(-4.2, (rc - 0.6) * math.cos(G.TAU * (k + 0.5) / 8), ZC + (rc - 0.6) * math.sin(G.TAU * (k + 0.5) / 8)) for k in range(8)],
                                 [(-5.6, (rc - 2.4) * math.cos(G.TAU * (k + 0.5) / 8), ZC + (rc - 2.4) * math.sin(G.TAU * (k + 0.5) / 8)) for k in range(8)]], False, True))
    for s in (-1, 1):
        lot.put(M["canon"], G.tour([(ZC + 3.5, 0.6), (ZC + 6.8, 0.55), (ZC + 7.4, 0.7), (ZC + 7.5, 0.5)], 10, "z", (-3.2, s * 1.6, 0.0), cap0=True))
        lot.put(M["turq"], G.tour([(ZC + 7.3, 0.45), (ZC + 7.35, 0.0)], 10, "z", (-3.2, s * 1.6, 0.0)))
        lot.put(M["conduit"], G.tube([(-1.5, s * (rc + 0.6), ZC - 1.0), (-4.5, s * (rc - 1.0), ZC - 2.2)], 0.1, 6))
    # bassin : plateau hexagonal sous la couronne (les hanches y sont), plaques ventrales
    lot.put(M["blind"], G.prisme(R.octo((0.0, 0.0), 4.8, 6), ZC - 7.2, ZC - 5.4, top_scale=1.25))
    lot.put(M["struct"], G.prisme(R.octo((0.0, 0.0), 3.6, 6), ZC - 5.5, ZC - 4.9, top_scale=1.1))
    lot.put(M["blind2"], plaque((3.2, 0.0, ZC - 6.0), G.norm((1.0, 0.0, -0.3)), 3.0, 2.0, 0.4, up=(0, 0, 1)))
    lot.put(M["conduit"], G.boite((3.6, 0.0, ZC - 6.0), (0.2, 1.6, 0.22)))
    # bec ventral : pointe blindée vers l'avant-bas (le « museau » du concept)
    lot.put(M["blind"], G.loft([[(1.0, -2.2, ZC - 4.8), (1.0, 2.2, ZC - 4.8), (1.0, 1.6, ZC - 2.2), (1.0, -1.6, ZC - 2.2)],
                                [(5.4, -1.2, ZC - 6.4), (5.4, 1.2, ZC - 6.4), (5.4, 0.9, ZC - 4.6), (5.4, -0.9, ZC - 4.6)],
                                [(7.8, -0.3, ZC - 7.6), (7.8, 0.3, ZC - 7.6), (7.8, 0.25, ZC - 7.0), (7.8, -0.25, ZC - 7.0)]], True, True))
    lot.put(M["conduit"], G.tube([(2.0, 0.0, ZC - 3.0), (6.5, 0.0, ZC - 5.6)], 0.1, 6))
    for s in (-1, 1):
        lot.put(M["accent"], G.boite((2.2, s * 2.0, ZC - 3.6), (0.4, 0.2, 0.3)))
    if stage >= 2:
        # anneau de lévitation autour de la couronne
        anneau_seg(lot, M, (C[0] - 0.6, 0.0, ZC), "x", rc + 2.6, 0.5, 0.22, n=8, jour=0.16, noeud=0.26)   # s43 : patins magnétiques
        lot.put(M["turq"], rainure((C[0] - 0.84, 0.0, ZC), "x", rc + 2.85, 0.06))
        for q in range(4):
            a = G.TAU * (q + 0.5) / 4
            lot.put(M["struct"], G.boite((C[0] - 0.6, (rc + 2.8) * math.cos(a), ZC + (rc + 2.8) * math.sin(a)), (0.4, 0.6, 0.5), rx=a))
    if stage >= 3:
        anneau_seg(lot, M, (C[0] - 1.6, 0.0, ZC), "x", rc + 4.0, 0.6, 0.24, n=6, jour=0.22, noeud=0.32)   # s43 : patins (tore plein : brume)
        for k in range(6):
            a = G.TAU * (k + 0.5) / 6
            p = (C[0] + 0.8, (rc + 1.6) * math.cos(a), ZC + (rc + 1.6) * math.sin(a))
            lot.put(M["cristal"], pointe(p, G.norm((0.5, math.cos(a), math.sin(a))), 1.8, 0.3))


def ailes(lot, M, stage):
    """Deux ailes-lames dorsales (croissants) gravées de circuits, partant des épaules vers le haut-arrière."""
    for s in (-1, 1):
        base = (-2.0, s * 4.2, ZC + 3.6)
        d = G.norm((-0.35, s * 0.55, 1.0))
        n = G.norm((1.0, -s * 0.35, 0.3))      # la face de l'aile regarde vers l'avant : vue de face par la caméra, comme sur le concept
        # lame : loft de 3 sections fines (plan presque vertical), effilée
        def sec(t, w):
            p = G.add(base, G.mul(d, t))
            ex, ey, ez = R.repere(n, d)
            return [G.add(p, G.add(G.mul(ex, -w), G.mul(ez, -0.15))), G.add(p, G.add(G.mul(ex, w), G.mul(ez, -0.15))),
                    G.add(p, G.add(G.mul(ex, w * 0.8), G.mul(ez, 0.15))), G.add(p, G.add(G.mul(ex, -w * 0.8), G.mul(ez, 0.15)))]
        lot.put(M["blind"], G.loft([sec(0.0, 1.6), sec(3.0, 2.6), sec(6.5, 2.2), sec(9.5, 1.2), sec(11.5, 0.2)], True, True))
        gravure(lot, M, G.add(base, G.mul(d, 5.0)), n, d, 3.0, 7.0, 3)
        lot.put(M["conduit"], G.tube([G.add(base, G.mul(d, 1.0)), G.add(base, G.mul(d, 10.5))], 0.08, 5))
        # racine blindée et articulation
        lot.put(M["struct"], G.sphere(base, 1.0, 10, 5))
        lot.put(M["blind2"], plaque(G.add(base, (0.6, s * 0.4, -0.8)), G.norm((0.4, s * 0.8, 0.4)), 2.2, 2.6, 0.4, up=(0, 0, 1)))
        if stage >= 2:
            for k in range(3 if stage == 2 else 5):
                t = 3.5 + 1.6 * k
                p = G.add(base, G.mul(d, t))
                lot.put(M["cristal"], pointe(G.add(p, G.mul(n, -0.2)), G.norm(G.add(G.mul(n, -1.0), G.mul(d, 0.4))), 1.5 - 0.1 * k, 0.24))
        if stage >= 3:
            lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", 1.2, 0.25, 0.1), G.add(base, G.mul(d, 7.5)), n))


def canon_annulaire(lot, M, stage):
    """Bras gauche (+y, côté caméra après le lacet) : épaule, fût cannelé, anneaux de focalisation flottants, vortex à la bouche."""
    s = 1
    E = (0.5, s * 5.6, ZC + 0.8)
    Mz = (9.8, s * 6.4, ZC + 0.4)
    d = G.norm(G.sub(Mz, E))
    lot.put(M["struct"], G.sphere(E, 1.3, 10, 5))
    lot.put(M["accent"], G.boite(G.add(E, (0.0, s * 1.0, 0.9)), (0.4, 0.3, 0.25)))
    lot.put(M["blind"], hexseg(E, G.lerp(E, Mz, 0.35), 1.5, 1.35, 8))
    lot.put(M["canon"], hexseg(G.lerp(E, Mz, 0.33), G.lerp(E, Mz, 0.78), 1.15, 0.95, 10))
    lot.put(M["struct"], G.tube([G.lerp(E, Mz, 0.75), Mz], 0.6, 10))
    lot.put(M["coeur"], G.tube([G.lerp(E, Mz, 0.4), G.add(Mz, G.mul(d, 0.3))], 0.32, 8))
    for k in range(4):
        a = G.TAU * (k + 0.5) / 4
        fr = G._frames([E, Mz])[0]
        off = G.add(G.mul(fr[1], 1.05 * math.cos(a)), G.mul(fr[2], 1.05 * math.sin(a)))
        lot.put(M["conduit"], G.tube([G.add(G.lerp(E, Mz, 0.36), off), G.add(G.lerp(E, Mz, 0.76), off)], 0.08, 5))
    n_an = 2 + (stage >= 2) + (stage >= 3)
    for k in range(n_an):
        t = 0.55 + 0.16 * k
        c = G.lerp(E, Mz, t)
        ra = 1.9 + 0.5 * k
        lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", ra, 0.45, 0.16), c, d))
        for q in range(3):
            a = G.TAU * (q + 0.5) / 3
            lot.put(M["struct"], G.oriente(G.boite((ra + 0.45, 0.0, 0.0), (0.5, 0.4, 0.3), rz=a), c, d))
    lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.0), (0.05, 0.75)], 16, "z", cap1=True), G.add(Mz, G.mul(d, 0.2)), d))
    lot.put(M["halo"], G.sphere(G.add(Mz, G.mul(d, 0.6)), 1.6, 14, 7))
    lot.put(M["blind2"], R.pose(G.prisme([(-1.6, -0.8), (1.8, -0.8), (2.2, 0.0), (1.8, 0.8), (-1.6, 0.8)], 0.0, 0.7, 0.8), G.add(G.lerp(E, Mz, 0.3), (0.0, 0.0, 1.5)), (0, 0, 1), (1, 0, 0)))


def tete_canon(lot, M, stage):
    """Bras droit (-y) : mufle blindé en loft (gueule turquoise, crocs), flexibles jusqu'à l'épaule."""
    s = -1
    E = (0.5, s * 5.6, ZC + 0.8)
    lot.put(M["struct"], G.sphere(E, 1.3, 10, 5))
    lot.put(M["accent"], G.boite(G.add(E, (0.0, s * 1.0, 0.9)), (0.4, 0.3, 0.25)))
    A = (3.4, s * 7.2, ZC + 1.0)
    lot.put(M["blind"], hexseg(E, A, 1.4, 1.2, 8))
    lot.put(M["struct"], G.sphere(A, 1.1, 10, 5))
    def sec(x, w, h, dz):
        y = s * 7.4
        return [(x, y - w, ZC + dz - h * 0.6), (x, y - w * 0.7, ZC + dz + h * 0.75), (x, y, ZC + dz + h), (x, y + w * 0.7, ZC + dz + h * 0.75),
                (x, y + w, ZC + dz - h * 0.6), (x, y + w * 0.5, ZC + dz - h * 0.8), (x, y - w * 0.5, ZC + dz - h * 0.8)]
    lot.put(M["blind"], G.loft([sec(3.8, 1.3, 1.2, 1.0), sec(6.0, 1.5, 1.35, 1.1), sec(8.6, 1.2, 1.0, 0.8), sec(10.6, 0.8, 0.55, 0.4), sec(11.4, 0.45, 0.25, 0.2)], True, True))
    lot.put(M["blind2"], G.loft([[(5.0, s * 7.4 - 1.1, ZC), (5.0, s * 7.4 + 1.1, ZC), (5.0, s * 7.4 + 0.8, ZC - 0.9), (5.0, s * 7.4 - 0.8, ZC - 0.9)],
                                 [(9.4, s * 7.4 - 0.8, ZC - 0.1), (9.4, s * 7.4 + 0.8, ZC - 0.1), (9.4, s * 7.4 + 0.5, ZC - 0.8), (9.4, s * 7.4 - 0.5, ZC - 0.8)],
                                 [(11.0, s * 7.4 - 0.35, ZC - 0.2), (11.0, s * 7.4 + 0.35, ZC - 0.2), (11.0, s * 7.4 + 0.25, ZC - 0.5), (11.0, s * 7.4 - 0.25, ZC - 0.5)]], True, True))
    lot.put(M["turq"], G.sphere((9.0, s * 7.4, ZC + 0.15), 0.7, 10, 5))
    lot.put(M["halo"], G.sphere((9.6, s * 7.4, ZC + 0.1), 1.3, 10, 5))
    for k in range(3):
        x = 7.4 + 1.1 * k
        for q in (-1, 1):
            lot.put(M["os"], pointe((x, s * 7.4 + q * (0.9 - 0.15 * k), ZC + 0.2), (0.0, 0.0, -1.0), 0.6, 0.14, 4))
    for q in (-1, 1):
        lot.put(M["conduit"], G.boite((6.4, s * 7.4 + q * 1.2, ZC + 1.6), (0.6, 0.12, 0.2)))
        lot.put(M["cristal"], pointe((4.6, s * 7.4 + q * 1.0, ZC + 2.0), G.norm((-0.6, q * 0.5, 0.8)), 1.8, 0.26))
    # flexibles (turq) entre l'épaule et la nuque du mufle
    for q in (-0.5, 0.5):
        lot.put(M["turq"], G.tube(G.catmull([G.add(E, (0.4, s * 0.6, 0.6)), (2.6, s * 6.0 + q, ZC + 2.6), (4.6, s * 7.4 + q, ZC + 2.1)], 5), 0.1, 6))
    if stage >= 3:
        lot.put(M["anneau"], anneau((5.2, s * 7.4, ZC + 0.6), "x", 2.0, 0.3, 0.12))


def pattes(lot, M, stage, u=None):
    """Six pattes digitigrades autour du bassin : hanche, cuisse vers l'extérieur-haut, tibia vers le bas, tuyère cyan vers le sol."""
    for k, ang in enumerate((35.0, 90.0, 145.0, -35.0, -90.0, -145.0)):
        a = math.radians(ang)
        s = 1 if ang > 0 else -1
        H = (4.0 * math.cos(a), 4.0 * math.sin(a), ZC - 6.2)
        K = (7.4 * math.cos(a), 7.4 * math.sin(a), ZC - 3.4)
        T = (9.6 * math.cos(a), 9.6 * math.sin(a), 3.6)
        if u is not None:
            # TITANS-8DIR : l'onde fait le tour des six pattes (une phase par patte) ; le genou suit à demi
            ph = G.TAU * (u + k / 6.0)
            ro, dz = ONDE[0] * math.sin(ph), ONDE[1] * math.cos(ph)
            T = (T[0] + ro * math.cos(a), T[1] + ro * math.sin(a), T[2] + dz)
            K = (K[0], K[1], K[2] + 0.45 * dz)
        lot.put(M["struct"], G.sphere(H, 1.0, 10, 5))
        lot.put(M["blind"], hexseg(H, K, 1.25, 0.95, 6, 0.2))
        lot.put(M["struct"], G.sphere(K, 0.95, 10, 5))
        lot.put(M["accent"], G.boite(G.add(K, (0.0, 0.0, 0.9)), (0.35, 0.35, 0.2)))
        lot.put(M["blind2"], hexseg(K, T, 1.0, 0.7, 6, 0.1))
        out = G.norm((math.cos(a), math.sin(a), 0.0))
        lot.put(M["blind"], plaque(G.add(G.lerp(K, T, 0.4), G.mul(out, 0.8)), G.norm(G.add(out, (0, 0, 0.3))), 1.6, 3.0, 0.3, up=G.norm(G.sub(K, T))))
        lot.put(M["conduit"], hexseg(G.add(G.lerp(H, K, 0.2), G.mul(out, 0.0)), G.add(T, G.mul(out, 0.7)), 0.1, 0.1))
        # TITANS2 : conduits haute densité, bague au genou, échappement d'énergie sous la tuyère
        traces(lot, M, H, K, (1.25 * 0.866, 0.95 * 0.866), [0.2 + G.TAU * j / 6 for j in (0, 2, 3, 5)], rt=0.08, jog=0.3)
        traces(lot, M, K, T, (1.0 * 0.866, 0.7 * 0.866), [0.1 + G.TAU * j / 6 for j in (1, 3, 4)], rt=0.075, jog=0.25)
        bague(lot, M, K, G.norm(G.sub(T, H)), 1.1)
        lot.put(M["halo"], G.oriente(G.tour([(1.6, 0.55), (2.6, 0.45), (3.6, 0.0)], 8, "z", cap0=True), T, (0, 0, -1)))
        # tuyère : cône vers le bas, jet turquoise
        lot.put(M["canon"], G.oriente(G.tour([(0.0, 0.6), (1.0, 0.75), (1.6, 0.55), (1.7, 0.4)], 10, "z", cap0=True), T, (0, 0, -1)))
        lot.put(M["turq"], G.oriente(G.tour([(1.55, 0.35), (1.6, 0.0)], 10, "z"), T, (0, 0, -1)))
        lot.put(M["cristal"], G.oriente(G.tour([(1.6, 0.3), (3.4, 0.0)], 8, "z", cap0=True), T, (0, 0, -1)))
        if stage >= 2 and k % 3 == 1:
            lot.put(M["cristal"], pointe(G.add(K, G.mul(out, 0.8)), G.norm(G.add(out, (0, 0, 0.9))), 1.6, 0.26))


def sphere_flottante(lot, M, stage, dz=0.0):
    """Sphère-œil flottante au-dessus du corps : coque blindée fendue, cœur, anneau incliné, pétales."""
    C = (0.6, 0.0, ZC + 12.4 + dz)
    lot.put(M["blind2"], G.sphere(C, 1.5, 12, 6))
    lot.put(M["coeur"], G.sphere(C, 1.0, 12, 6))
    lot.put(M["halo"], G.sphere(C, 2.0, 12, 6))
    lot.put(M["anneau"], G.oriente(anneau((0.0, 0.0, 0.0), "z", 2.3, 0.3, 0.1), C, G.norm((0.6, 0.3, 1.0))))
    for k in range(3):
        a = G.TAU * k / 3 + 0.5
        p = (C[0] + 2.2 * math.cos(a), C[1] + 2.2 * math.sin(a), C[2] + 0.4)
        lot.put(M["blind"], plaque(p, G.norm((math.cos(a), math.sin(a), 0.6)), 1.2, 2.0, 0.3, up=(0, 0, 1)))
    lot.put(M["struct"], G.tube([(C[0], C[1], C[2] - 1.5), (C[0] - 0.4, C[1], C[2] - 3.2)], 0.12, 6))
    if stage >= 3:
        for k in range(4):
            a = G.TAU * (k + 0.5) / 4
            lot.put(M["cristal"], pointe((C[0] + 1.3 * math.cos(a), C[1] + 1.3 * math.sin(a), C[2] + 0.8), G.norm((math.cos(a) * 0.5, math.sin(a) * 0.5, 1.0)), 1.4, 0.2))


def build(S, lot, stage=1, u=None, attaque=None, dirs=False):
    """Construit la Sentinelle au stade `stage` (1 à 3) : repos (une image, lacet PSI), marche (u) ou salve (attaque) sans lacet (dirs)."""
    M = TC.charte(S, TM.matieres(S, PREFIX, GRIS), PREFIX, GRIS)
    xf = XF0 if dirs else XF
    R.raz()
    gonfle, bob, dz = (1.0, 1.0, 0.0), 0.0, 0.0
    if attaque is not None:
        gonfle = ATTAQUE[int(round(attaque * SERIE["attaque"])) % SERIE["attaque"]]
        u = None
    elif u is not None:
        bob = BOB * math.sin(G.TAU * u)
        dz = 0.5 * math.sin(G.TAU * u + 1.6)
    lot.xf = (lambda v: xf((v[0], v[1], v[2] + bob))) if bob else xf
    corps(lot, M, stage, gonfle)
    ailes(lot, M, stage)
    canon_annulaire(lot, M, stage)
    tete_canon(lot, M, stage)
    pattes(lot, M, stage, u)
    sphere_flottante(lot, M, stage, dz)
    lot.xf = xf
    return {"stage": stage, "pieces": lot.n, "u": u, "attaque": attaque}


def build_anime(S, lot, stage, u, attaque):
    """Entrée commune des titans animés (batch_titans.anime) : stade, phase de marche ou de salve, sans lacet (8 directions)."""
    return build(S, lot, stage, u=u if attaque is None else None, attaque=attaque, dirs=True)
