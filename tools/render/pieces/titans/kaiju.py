"""KAIJU CRISTALLIN LOURD, titan ENNEMI (lot TITANS, 9/11) : reptile colossal cyber-organique, quadrupède, épines dorsales de
cristal bleu, gueule-canon (vortex cyan dans la mâchoire), plaques de blindage sombres iridescentes sur le dos, conduits lumineux
le long des flancs, deux anneaux magnétiques flottants au garrot.

Modèle paramétrique low-poly (kit des géants, geo.py) ANIMÉ : `build(S, lot, u, attaque=None)` construit la pose du cycle de course
u dans [0, 1[ (trot : pattes en diagonale), ou de l'attaque (la tête s'abaisse, la gueule s'ouvre, le vortex grossit). Le rendu
tourne le modèle sur 8 directions (batch_titans.py, comme serie_blender.py des souches). Repère LOCAL : +x = avant (tête),
+y = gauche, +z = haut ; origine = sous le centre du corps, au sol. Longueur environ 24 tuiles du museau au bout de la queue,
6,5 tuiles au garrot (un `unit` : boîte de collision plafonnée, l'image déborde comme les écraseurs).
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

PREFIX = "ka_"
GRIS = os.environ.get("FO_GRIS", "") == "1"
# Série (lue par batch_titans et feuilles_titans) : images par animation, densité du rendu (px par tuile), rayon au sol et hauteur
# englobants (cadre fixe pour toutes les images et directions), portée du liseré de contact.
SERIE = {"course": 8, "attaque": 4, "densite": 24.0, "R": 12.6, "zmax": 9.2}
AO = 0.6
FOULEE = 2.0 * 1.3        # distance parcourue par cycle (unités) : amplitude du pas × 2 (distance_per_frame du prototype)


def pas(u, amp, levee, appui=0.55):
    """Cycle d'un pied, u dans [0, 1[ : appui (le pied recule au sol), puis vol (il revient en l'air). Rend (avance, hauteur)."""
    u = u % 1.0
    if u < appui:
        return amp * (1.0 - 2.0 * u / appui), 0.0
    v = (u - appui) / (1.0 - appui)
    s = v * v * (3.0 - 2.0 * v)
    return amp * (2.0 * s - 1.0), levee * math.sin(math.pi * v) ** 0.8


def ik2(a, c, l1, l2, pole):
    """Genou d'une patte à deux segments de a à c, plié du côté de `pole`."""
    v = G.sub(c, a)
    L = max(G.length(v), 1e-6)
    u = G.mul(v, 1.0 / L)
    L = min(L, (l1 + l2) * 0.995)
    x = (l1 * l1 - l2 * l2 + L * L) / (2.0 * L)
    h = math.sqrt(max(l1 * l1 - x * x, 0.0))
    p = G.sub(pole, G.mul(u, G.dot(pole, u)))
    p = G.norm(p)
    return G.add(G.add(a, G.mul(u, x)), G.mul(p, h))


def ellipse(c, w, h, n=10, rot=0.0):
    """Section elliptique (largeur w selon y, hauteur h selon z) autour de c, dans le plan yz, légèrement anguleuse (n côtés)."""
    ring = []
    for j in range(n):
        a = rot + G.TAU * (j + 0.5) / n
        ring.append((c[0], c[1] + w * math.cos(a), c[2] + h * math.sin(a)))
    return ring


def spine(u, bob):
    """Points de contrôle de la colonne (queue -> tête) pour la phase de course u ; `bob` : montée du corps."""
    z = bob
    sw = 0.25 * math.sin(G.TAU * u)   # ondulation latérale de la queue
    return [(-11.6, -sw * 2.2, 1.1), (-9.0, -sw * 1.4, 1.9 + z * 0.3), (-6.2, -sw * 0.6, 3.2 + z * 0.6), (-3.6, 0.0, 4.3 + z),
            (0.0, 0.0, 4.9 + z), (3.4, 0.0, 4.7 + z), (5.6, 0.0, 5.1 + z)]


def corps(lot, M, u, bob):
    """Corps et queue : loft d'ellipses le long de la colonne (peau), plaques dorsales, épines de cristal, conduits de flanc."""
    ctrl = spine(u, bob)
    pts = G.catmull(ctrl, 6)
    n = len(pts)
    rings = []
    prof = []
    for i, p in enumerate(pts):
        t = i / float(n - 1)
        # rayons : queue fine, croupe large, poitrail large, cou plus fin
        if t < 0.42:
            w = 0.28 + (2.2 - 0.28) * (t / 0.42) ** 1.4
            h = 0.25 + (1.9 - 0.25) * (t / 0.42) ** 1.4
        elif t < 0.82:
            k = (t - 0.42) / 0.40
            w = 2.2 + 0.35 * math.sin(math.pi * k)
            h = 1.9 + 0.4 * math.sin(math.pi * k)
        else:
            k = (t - 0.82) / 0.18
            w = 2.2 - 1.0 * k
            h = 2.0 - 0.8 * k
        rings.append(ellipse(p, w, h, 10))
        prof.append((p, w, h, t))
    lot.put(M["peau"], G.loft(rings, True, True))
    # plaques dorsales angulaires (blindage sombre), une tous les ~1,1 unité du milieu de la queue au cou
    for i in range(3, n - 2, 2):
        p, w, h, t = prof[i]
        if t < 0.2:
            continue
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        top = (p[0], p[1], p[2] + h * 0.92)
        lot.put(M["blind"], plaque(top, (0.0, 0.0, 1.0), w * 1.1 + 0.3, 1.0, 0.22 + 0.1 * (t > 0.4), up=d, coins=0.7))
        for s in (-1, 1):
            flank = (p[0], p[1] + s * w * 0.78, p[2] + h * 0.55)
            lot.put(M["blind2"], plaque(flank, G.norm((0.0, s * 0.8, 0.6)), 1.0, 0.9 + 0.5 * (t > 0.4), 0.2, up=d, coins=0.7))
    # épines dorsales de cristal : grandes au garrot, petites sur la queue, inclinées vers l'arrière
    for i in range(2, n - 3, 2):
        p, w, h, t = prof[i]
        L = 0.7 + 3.2 * math.sin(math.pi * min(1.0, max(0.0, (t - 0.1) / 0.85))) ** 1.3
        if t > 0.5:
            L *= 1.15
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        up = G.norm((-0.55 * d[0], 0.0, 1.0))
        lot.put(M["cristal"], pointe((p[0], p[1], p[2] + h * 0.95), up, L, 0.22 + 0.16 * L / 3.5))
        if t > 0.45 and i % 4 == 2:
            for s in (-1, 1):
                lot.put(M["cristal"], pointe((p[0] - 0.3, p[1] + s * w * 0.55, p[2] + h * 0.75), G.norm((-0.6, s * 0.7, 0.8)), L * 0.5, 0.2))
    # conduits lumineux des flancs (du garrot à la croupe) et de la queue
    for s in (-1, 1):
        line = [(pts[i][0], pts[i][1] + s * prof[i][1] * 0.98, pts[i][2] + prof[i][2] * 0.1) for i in range(int(n * 0.3), int(n * 0.86), 2)]
        lot.put(M["conduit"], G.tube(line, 0.12, 6))
        line2 = [(pts[i][0], pts[i][1] + s * prof[i][1] * 0.9, pts[i][2] + prof[i][2] * 0.35) for i in range(2, int(n * 0.32), 2)]
        lot.put(M["turq"], G.tube(line2, 0.09, 6))
    # pointes d'os au bout de la queue (masse d'armes)
    tip = pts[0]
    for k in range(4):
        a = G.TAU * k / 4
        lot.put(M["os"], pointe((tip[0] + 0.6, tip[1], tip[2] + 0.1), G.norm((-0.6, 0.9 * math.cos(a), 0.9 * math.sin(a) + 0.3)), 1.1, 0.2, 5))
    lot.put(M["cristal"], pointe((tip[0] + 0.2, tip[1], tip[2]), (-1.0, 0.0, 0.15), 1.6, 0.26))
    return pts, prof


def patte(lot, M, hanche, pied0, u, avant, s):
    """Une patte sprawlée (genou vers l'extérieur et l'avant pour les antérieures, l'arrière pour les postérieures) :
    cuisse, tibia, pied à 3 griffes ; plaque d'épaule ; conduit à la cuisse. u : phase du pied."""
    amp, levee = FOULEE / 2.0, 0.9
    dx, dz = pas(u, amp, levee)
    pied = (pied0[0] + dx, pied0[1], pied0[2] + dz)
    l1, l2 = 3.1, 3.0
    pole = G.norm((0.9 if avant else -0.9, s * 1.2, 0.35))
    genou = ik2(hanche, pied, l1, l2, pole)
    lot.put(M["chair"], G.sphere(hanche, 0.95, 10, 5))
    lot.put(M["accent"], G.boite(G.add(hanche, (0.0, s * 0.85, 0.35)), (0.22, 0.14, 0.14)))
    lot.put(M["peau"], hexseg(hanche, genou, 1.05, 0.7, 7, 0.2))
    lot.put(M["chair"], G.sphere(genou, 0.62, 8, 4))
    lot.put(M["peau"], hexseg(genou, pied, 0.62, 0.42, 7, 0.1))
    lot.put(M["blind2"], plaque(G.add(G.lerp(hanche, genou, 0.45), (0.0, s * 0.9, 0.45)), G.norm((0.0, s * 0.9, 0.6)), 1.1, 1.8, 0.2,
                                up=G.norm(G.sub(genou, hanche))))
    lot.put(M["conduit"], hexseg(G.add(hanche, (0.3, s * 0.95, -0.3)), G.add(genou, (0.2, s * 0.6, 0.1)), 0.1, 0.09))
    # pied : coussinet et 3 griffes vers l'avant, un ergot
    lot.put(M["struct"], G.sphere((pied[0], pied[1], pied[2] + 0.25), 0.5, 8, 4))
    for k, ay in enumerate((0.0, 0.7, -0.7)):
        lot.put(M["os"], pointe((pied[0] + 0.3, pied[1] + ay * 0.4, pied[2] + 0.3), G.norm((1.0, ay * 0.8, -0.35)), 1.4 if k == 0 else 1.1, 0.25, 5))
    lot.put(M["os"], pointe((pied[0] - 0.3, pied[1], pied[2] + 0.35), (-0.8, 0.0, -0.3), 0.8, 0.2, 5))


def tete(lot, M, base, ouverture, charge):
    """Tête : crâne anguleux en loft, mâchoire articulée (ouverture 0 à 1), gueule-canon (vortex, grossit avec la charge),
    cornes de cristal, yeux lumineux, deux anneaux flottants au cou."""
    bx, by, bz = base
    pitch = -0.25 * ouverture
    def P(x, y, z):
        return (bx + x * math.cos(pitch) - z * math.sin(pitch), by + y, bz + x * math.sin(pitch) + z * math.cos(pitch))
    # cou
    lot.put(M["chair"], G.loft([ellipse((bx - 1.6, by, bz - 0.3), 1.25, 1.1, 10), ellipse((bx - 0.2, by, bz), 1.1, 1.0, 10)], False, False))
    def sect(x, w, h, zc):
        return [P(x, -w, zc - h * 0.6), P(x, -w * 0.75, zc + h * 0.7), P(x, 0.0, zc + h), P(x, w * 0.75, zc + h * 0.7), P(x, w, zc - h * 0.6),
                P(x, w * 0.5, zc - h * 0.75), P(x, -w * 0.5, zc - h * 0.75)]
    lot.put(M["blind"], G.loft([sect(-0.4, 1.25, 1.0, 0.25), sect(1.2, 1.3, 1.05, 0.3), sect(2.6, 1.05, 0.8, 0.25), sect(3.9, 0.7, 0.45, 0.1),
                                sect(4.5, 0.45, 0.22, 0.0)], True, True))
    # mâchoire inférieure (pivot en x = 0,8) qui s'ouvre vers le bas
    ang = 0.75 * ouverture
    def J(x, y, z):
        xx, zz = x - 0.8, z
        return P(0.8 + xx * math.cos(ang) + zz * math.sin(ang), y, -xx * math.sin(ang) + zz * math.cos(ang))
    jaw = [[J(0.8, -1.0, -0.4), J(0.8, 1.0, -0.4), J(0.8, 0.7, -1.0), J(0.8, -0.7, -1.0)],
           [J(2.6, -0.85, -0.5), J(2.6, 0.85, -0.5), J(2.6, 0.55, -0.95), J(2.6, -0.55, -0.95)],
           [J(4.1, -0.45, -0.35), J(4.1, 0.45, -0.35), J(4.1, 0.3, -0.6), J(4.1, -0.3, -0.6)]]
    lot.put(M["blind2"], G.loft(jaw, True, True))
    # dents (os) sur les deux mâchoires
    for k in range(4):
        x = 1.4 + 0.75 * k
        for s in (-1, 1):
            lot.put(M["os"], pointe(P(x, s * (0.85 - 0.12 * k), -0.45), (0.0, 0.0, -1.0), 0.55, 0.13, 4))
            lot.put(M["os"], pointe(J(x, s * (0.75 - 0.1 * k), -0.5), (0.0, 0.0, 1.0), 0.45, 0.12, 4))
    # gueule-canon : vortex au fond de la gueule, grossit et s'avance avec la charge
    rv = 0.45 + 0.5 * charge
    lot.put(M["coeur"], G.sphere(P(1.6 + 0.6 * charge, 0.0, -0.3 - 0.3 * ouverture), rv, 12, 6))
    lot.put(M["halo"], G.sphere(P(1.8 + 0.7 * charge, 0.0, -0.3 - 0.3 * ouverture), rv * 1.9, 12, 6))
    lot.put(M["turq"], G.tour([(0.0, 0.0), (0.04, 0.5 + 0.3 * charge)], 12, "x", P(2.2 + 0.8 * charge, 0.0, -0.3 - 0.35 * ouverture), cap1=True))
    # yeux, cornes de cristal, crête
    for s in (-1, 1):
        lot.put(M["conduit"], G.boite(P(1.6, s * 1.15, 0.65), (0.5, 0.12, 0.2)))
        lot.put(M["cristal"], pointe(P(-0.2, s * 0.9, 1.1), G.norm((-0.7, s * 0.45, 0.8)), 2.4, 0.3))
        lot.put(M["cristal"], pointe(P(0.6, s * 1.2, 0.6), G.norm((-0.5, s * 0.9, 0.5)), 1.4, 0.22))
    lot.put(M["cristal"], pointe(P(0.3, 0.0, 1.25), G.norm((-0.6, 0.0, 1.0)), 1.9, 0.26))
    # anneaux magnétiques flottants autour du cou (deux, décalés)
    for k, (x, rr) in enumerate(((-1.4, 1.9), (-2.6, 2.3))):
        c = (bx + x, by, bz + 0.6 + 0.4 * k)
        lot.put(M["anneau"], anneau(c, "x", rr, 0.35, 0.12))
        lot.put(M["turq"], rainure((c[0] - 0.14, c[1], c[2]), "x", rr + 0.17, 0.05))


def build(S, lot, u=0.0, attaque=None):
    """Pose du Kaiju : u = phase de course ; attaque = phase d'attaque (0 à 1) ou None."""
    M = TM.matieres(S, "ka_", GRIS)
    r = G.Rnd(3000)
    R.raz()
    bob = 0.12 * math.sin(G.TAU * 2.0 * u) if attaque is None else 0.0
    pts, prof = corps(lot, M, u, bob)
    # pattes : antérieures aux épaules, postérieures aux hanches ; trot (diagonales en phase)
    hanches = {"AG": (3.3, 2.1, 3.5 + bob), "AD": (3.3, -2.1, 3.5 + bob), "PG": (-3.6, 2.0, 3.0 + bob), "PD": (-3.6, -2.0, 3.0 + bob)}
    pieds = {"AG": (4.6, 3.6, 0.0), "AD": (4.6, -3.6, 0.0), "PG": (-4.4, 3.5, 0.0), "PD": (-4.4, -3.5, 0.0)}
    phase = {"AG": 0.0, "PD": 0.0, "AD": 0.5, "PG": 0.5}
    if attaque is not None:
        # à l'attaque, les pattes campées (phase d'appui fixe), le poitrail bas
        for k in phase:
            phase[k] = 0.1 if k in ("AG", "PD") else 0.35
        u = 0.0
    for k in ("PG", "PD", "AG", "AD"):
        patte(lot, M, hanches[k], pieds[k], u + phase[k], k[0] == "A", 1 if k[1] == "G" else -1)
    # tête : au bout du cou ; attaque = la tête plonge, la gueule s'ouvre puis la charge monte
    if attaque is None:
        tete(lot, M, (6.8, 0.0, 5.6 + bob), 0.15, 0.0)
    else:
        a = attaque
        ouverture = min(1.0, a * 2.2)
        charge = max(0.0, (a - 0.25) / 0.75)
        tete(lot, M, (7.0, 0.0, 5.6 - 1.2 * ouverture), ouverture, charge)
    return {"pieces": lot.n, "u": u, "attaque": attaque}
