"""KAIJU CRISTALLIN, titan ENNEMI. Refonte s43 (13/11, pilier D) : silhouette TITANESQUE (15 tuiles au garrot cristaux compris, 27 du
museau au bout de la queue), corps de basalte sombre et massif sur quatre pattes en colonnes, blindage dorsal iridescent, et surtout des
GRAPPES de cristaux réfractifs : chaque cristal est une coque de verre bleu glacier (transmission, IOR du verre) qui enferme un NOYAU
émissif (couche de lueur) ; des fissures lumineuses courent de la base des grappes sur les flancs. Gueule-canon (vortex) et couronne de
cristaux sur le crâne. Les anneaux magnétiques flottants de la version du 9/11 sont retirés (ils brouillaient la silhouette).

Modèle paramétrique low-poly (kit des géants, geo.py) ANIMÉ : `build(S, lot, u, attaque=None)` construit la pose du cycle de course
u dans [0, 1[ (trot lourd : pattes en diagonale), ou de l'attaque (la tête plonge, la gueule s'ouvre, le vortex grossit, les noyaux
s'allument). Le rendu tourne le modèle sur 8 directions (batch_titans.py). Repère LOCAL : +x = avant (tête), +y = gauche, +z = haut ;
origine = sous le centre du corps, au sol.
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
from juggernaut import hexseg, pointe, plaque  # noqa: E402

PREFIX = "ka_"
GRIS = os.environ.get("FO_GRIS", "") == "1"
# Série (lue par batch_titans et feuilles_titans) : images par animation, densité du rendu (px par tuile), rayon au sol et hauteur
# englobants (cadre fixe pour toutes les images et directions), sol du rendu.
SERIE = {"course": 8, "attaque": 4, "densite": 24.0, "R": 14.5, "zmax": 15.5, "sol": 140.0}
AO = 0.7
GLOW_BLANC = True         # la lueur est rendue BLANCHE : le prototype la teinte par ère
FOULEE = 2.0 * 1.4        # distance parcourue par cycle (unités) : amplitude du pas × 2 (distance_per_frame du prototype)


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


# ------------------------------------------------------------------------------------------------ matières propres au Kaiju
def matieres(S):
    """Jeu commun des titans (titans_mat) + matières du Kaiju : basalte (peau), chair sombre, NOYAU émissif des cristaux (la coque
    `cristal` est translucide : le noyau se voit au travers, réfracté), fissures lumineuses."""
    M = TM.matieres(S, PREFIX, GRIS)
    if GRIS:
        M["noyau"] = M["conduit"]
        M["fissure"] = M["conduit"]
        return M
    import mat as MT
    M["peau"] = MT.surface(PREFIX + "basalte", (0.030, 0.034, 0.048), rough=0.62, met=0.10, tole=(0.6, 0.35), joint=0.3, joint_l=0.035,
                           var=0.22, usure=0.25, nu=(0.20, 0.24, 0.34), crasse=0.6, crasse_col=(0.008, 0.009, 0.014), relief=1.0, graine=31)
    M["chair"] = MT.surface(PREFIX + "chair2", (0.060, 0.040, 0.070), rough=0.66, met=0.05, usure=0.15, nu=(0.25, 0.18, 0.32),
                            crasse=0.55, crasse_col=(0.01, 0.006, 0.014), graine=32)
    M["ventre"] = MT.surface(PREFIX + "ventre", (0.085, 0.090, 0.110), rough=0.5, met=0.25, tole=(0.9, 0.35), joint=0.35, joint_l=0.03,
                             var=0.1, usure=0.3, nu=(0.35, 0.38, 0.45), crasse=0.5, crasse_col=(0.01, 0.01, 0.015), relief=0.8, graine=33)
    M["noyau"] = S.mat_emissive(PREFIX + "noyau", (0.12, 0.55, 1.00), strength=4.5, base=(0.05, 0.30, 0.70), main_scale=0.35)
    M["fissure"] = S.mat_emissive(PREFIX + "fissure", (0.20, 0.70, 1.00), strength=3.0, base=(0.04, 0.25, 0.40), main_scale=0.45)
    return M


def cristal(lot, M, base, d, L, r, noyau=True):
    """Un cristal réfractif : coque de verre (`cristal`) et noyau émissif plus fin à l'intérieur (lueur)."""
    lot.put(M["cristal"], pointe(base, d, L, r))
    if noyau and L > 0.7:
        lot.put(M["noyau"], pointe(G.add(base, G.mul(d, 0.1 * L)), d, L * 0.78, r * 0.42, 5))


def grappe(lot, M, base, up, L, r, n, graine, ouvert=0.55):
    """Grappe de cristaux : un grand au centre (direction `up`), n satellites plus courts écartés autour (angle doré : déterministe)."""
    cristal(lot, M, base, up, L, r)
    a0 = G.cross(up, (0.0, 0.0, 1.0) if abs(up[2]) < 0.9 else (1.0, 0.0, 0.0))
    a0 = G.norm(a0)
    b0 = G.norm(G.cross(up, a0))
    for k in range(n):
        ang = graine * 2.399 + k * G.TAU / n
        lat = G.add(G.mul(a0, math.cos(ang)), G.mul(b0, math.sin(ang)))
        dd = G.norm(G.add(up, G.mul(lat, ouvert + 0.15 * ((k * 7 + graine) % 3))))
        kk = 0.42 + 0.14 * ((k * 5 + graine * 3) % 4)
        cristal(lot, M, G.add(base, G.mul(lat, r * 0.9)), dd, L * kk, r * (0.55 + 0.1 * (k % 2)))


# ------------------------------------------------------------------------------------------------ squelette
def spine(u, bob):
    """Points de contrôle de la colonne (queue -> tête) pour la phase de course u ; `bob` : montée du corps."""
    z = bob
    sw = 0.3 * math.sin(G.TAU * u)   # ondulation latérale de la queue
    return [(-13.0, -sw * 2.4, 1.3), (-10.0, -sw * 1.6, 2.6 + z * 0.3), (-6.8, -sw * 0.7, 4.4 + z * 0.6), (-3.4, 0.0, 6.0 + z),
            (0.0, 0.0, 6.7 + z), (3.2, 0.0, 6.8 + z), (5.6, 0.0, 6.6 + z)]


def corps(lot, M, u, bob, eclat):
    """Corps et queue : loft massif (basalte), écailles ventrales, blindage dorsal, grappes de cristaux, fissures lumineuses."""
    ctrl = spine(u, bob)
    pts = G.catmull(ctrl, 6)
    n = len(pts)
    rings, prof = [], []
    for i, p in enumerate(pts):
        t = i / float(n - 1)
        if t < 0.40:                         # queue : fine au bout, épaisse à la croupe
            k = (t / 0.40) ** 1.25
            w, h = 0.35 + (3.0 - 0.35) * k, 0.30 + (2.7 - 0.30) * k
        elif t < 0.84:                       # tronc : croupe -> poitrail, bombé
            k = (t - 0.40) / 0.44
            w, h = 3.0 + 0.45 * math.sin(math.pi * k) + 0.25 * k, 2.7 + 0.5 * math.sin(math.pi * k) + 0.2 * k
        else:                                # garrot -> cou épais
            k = (t - 0.84) / 0.16
            w, h = 3.25 - 1.2 * k, 3.0 - 1.0 * k
        rings.append(ellipse((p[0], p[1], p[2] - 0.1 * h), w, h, 12))
        prof.append((p, w, h, t))
    lot.put(M["peau"], G.loft(rings, True, True))
    # écailles ventrales claires (lisibles sous le corps, la nuit comme le jour)
    for i in range(4, n - 2, 2):
        p, w, h, t = prof[i]
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        lot.put(M["ventre"], plaque((p[0], p[1], p[2] - h * 1.02), (0.0, 0.0, -1.0), w * 1.1, 1.2, 0.18, up=d, coins=0.7))
    # blindage dorsal : grandes plaques imbriquées, et plaques de flanc
    for i in range(3, n - 1, 2):
        p, w, h, t = prof[i]
        if t < 0.15:
            continue
        d = G.norm(G.sub(pts[min(n - 1, i + 1)], pts[i - 1]))
        top = (p[0], p[1], p[2] + h * 0.86)
        lot.put(M["blind"], plaque(top, G.norm((-0.25 * d[0], 0.0, 1.0)), w * 1.25 + 0.4, 1.6, 0.3 + 0.12 * (t > 0.4), up=d, coins=0.65))
        if t > 0.35:
            for s in (-1, 1):
                flank = (p[0], p[1] + s * w * 0.82, p[2] + h * 0.42)
                lot.put(M["blind2"], plaque(flank, G.norm((0.0, s * 0.85, 0.5)), 1.5, 1.4, 0.26, up=d, coins=0.65))
    # grappes de cristaux dorsales : la crête de la silhouette, géante au garrot et à la croupe
    for j, i in enumerate(range(3, n - 2, 2)):
        p, w, h, t = prof[i]
        f = math.sin(math.pi * min(1.0, max(0.0, (t - 0.08) / 0.86))) ** 1.1
        L = 1.0 + 4.6 * f + 0.8 * (t > 0.55)
        d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
        up = G.norm((-0.45 * d[0], 0.0, 1.0))
        base = (p[0], p[1], p[2] + h * 0.93)
        grappe(lot, M, base, up, L, 0.48 + 0.22 * L / 4.0, 2 if L > 2.5 else 1, j, ouvert=0.45)
        # fissure lumineuse de la grappe sur les deux flancs (zigzag vers le bas)
        if t > 0.3 and j % 2 == 0:
            for s in (-1, 1):
                z = [(p[0] + 0.15 * ((k % 2) * 2 - 1), p[1] + s * w * (0.5 + 0.45 * k / 4.0), p[2] + h * (0.85 - 0.55 * k / 4.0))
                     for k in range(5)]
                lot.put(M["fissure"], G.tube(z, 0.07 + 0.03 * eclat, 5))
    # grappes d'épaules (au-dessus des pattes avant) et de hanches, ouvertes vers l'extérieur
    for x, kz, LL, gg in ((3.4, 0.55, 3.4, 7), (-3.4, 0.5, 2.6, 11)):
        i = min(range(n), key=lambda q: abs(pts[q][0] - x))
        p, w, h, t = prof[i]
        for s in (-1, 1):
            grappe(lot, M, (p[0], p[1] + s * w * 0.62, p[2] + h * kz), G.norm((-0.2, s * 0.75, 0.8)), LL, 0.45, 2, gg + (s > 0))
    # bout de queue : massue de cristal
    tip = pts[0]
    grappe(lot, M, (tip[0] + 0.4, tip[1], tip[2] + 0.2), G.norm((-1.0, 0.0, 0.35)), 2.2, 0.32, 4, 5, ouvert=0.9)
    return pts, prof


def patte(lot, M, hanche, pied0, u, avant, s):
    """Patte en colonne (pachyderme) : cuisse massive blindée, tibia épais, grand pied à quatre griffes, cristaux au coude."""
    amp, levee = FOULEE / 2.0, 0.8
    dx, dz = pas(u, amp, levee)
    pied = (pied0[0] + dx, pied0[1], pied0[2] + dz)
    cheville = (pied[0], pied[1], pied[2] + 1.1)
    l1, l2 = 3.0, 2.9
    pole = G.norm((0.8 if avant else -0.8, s * 0.35, 0.0))
    genou = ik2(hanche, cheville, l1, l2, pole)
    lot.put(M["peau"], G.sphere(hanche, 1.55, 12, 6))
    lot.put(M["peau"], hexseg(hanche, genou, 1.55, 1.1, 8, 0.2))
    lot.put(M["chair"], G.sphere(genou, 1.0, 10, 5))
    lot.put(M["peau"], hexseg(genou, cheville, 1.05, 0.9, 8, 0.1))
    lot.put(M["blind"], plaque(G.add(G.lerp(hanche, genou, 0.4), (0.0, s * 1.35, 0.3)), G.norm((0.0, s * 0.9, 0.45)), 1.9, 2.6, 0.3,
                               up=G.norm(G.sub(genou, hanche))))
    lot.put(M["blind2"], plaque(G.add(genou, (0.75 if avant else -0.75, s * 0.4, 0.0)), G.norm((1.0 if avant else -1.0, s * 0.4, 0.2)),
                                1.4, 1.6, 0.24, up=(0.0, 0.0, 1.0)))
    cristal(lot, M, G.add(genou, (-0.3, s * 0.8, 0.4)), G.norm((-0.5, s * 0.8, 0.6)), 1.6, 0.26)
    # pied : large coussinet (contact au sol) et quatre griffes, un ergot
    lot.put(M["struct"], G.loft([ellipse((pied[0] - 0.9, pied[1], pied[2] + 0.05), 1.0, 0.25, 10),
                                 ellipse((pied[0] + 0.1, pied[1], pied[2] + 0.55), 1.2, 0.6, 10),
                                 ellipse((pied[0] + 0.6, pied[1], pied[2] + 1.1), 0.95, 0.5, 10)], True, True))
    for k, ay in enumerate((-0.75, -0.25, 0.25, 0.75)):
        lot.put(M["os"], pointe((pied[0] + 0.9, pied[1] + ay, pied[2] + 0.35), G.norm((1.0, ay * 0.5, -0.4)), 1.2 + 0.3 * (abs(ay) < 0.5), 0.26, 5))
    lot.put(M["os"], pointe((pied[0] - 0.9, pied[1], pied[2] + 0.4), (-0.85, 0.0, -0.3), 0.9, 0.22, 5))


def tete(lot, M, base, ouverture, charge):
    """Tête massive : crâne anguleux en loft, arcade sourcilière, mâchoire articulée, gueule-canon (vortex), couronne de cristaux, yeux."""
    bx, by, bz = base
    pitch = -0.28 * ouverture
    K = 1.35

    def P(x, y, z):
        x, y, z = x * K, y * K, z * K
        return (bx + x * math.cos(pitch) - z * math.sin(pitch), by + y, bz + x * math.sin(pitch) + z * math.cos(pitch))
    # cou (raccord au corps)
    lot.put(M["peau"], G.loft([ellipse((bx - 2.6, by, bz - 0.2), 2.0, 1.9, 12), ellipse((bx - 0.6, by, bz + 0.1), 1.6, 1.45, 12)], False, False))

    def sect(x, w, h, zc):
        return [P(x, -w, zc - h * 0.6), P(x, -w * 0.8, zc + h * 0.7), P(x, 0.0, zc + h), P(x, w * 0.8, zc + h * 0.7), P(x, w, zc - h * 0.6),
                P(x, w * 0.5, zc - h * 0.75), P(x, -w * 0.5, zc - h * 0.75)]
    lot.put(M["blind"], G.loft([sect(-0.5, 1.3, 1.05, 0.25), sect(1.0, 1.35, 1.1, 0.35), sect(2.4, 1.1, 0.85, 0.25), sect(3.6, 0.75, 0.5, 0.1),
                                sect(4.3, 0.5, 0.25, 0.0)], True, True))
    # arcade sourcilière (plaques), yeux lumineux enfoncés dessous
    for s in (-1, 1):
        lot.put(M["blind2"], plaque(P(1.9, s * 0.95, 0.8), G.norm((0.3, s * 0.7, 0.7)), 1.6, 0.7, 0.2, up=(1.0, 0.0, 0.0), coins=0.6))
        lot.put(M["noyau"], G.boite(P(2.0, s * 1.08, 0.5), (0.36 * K, 0.10 * K, 0.11 * K)))
    # mâchoire inférieure (pivot en x = 0,8) qui s'ouvre vers le bas
    ang = 0.8 * ouverture

    def J(x, y, z):
        xx, zz = x - 0.8, z
        return P(0.8 + xx * math.cos(ang) + zz * math.sin(ang), y, -xx * math.sin(ang) + zz * math.cos(ang))
    jaw = [[J(0.8, -1.05, -0.4), J(0.8, 1.05, -0.4), J(0.8, 0.75, -1.05), J(0.8, -0.75, -1.05)],
           [J(2.6, -0.9, -0.5), J(2.6, 0.9, -0.5), J(2.6, 0.6, -1.0), J(2.6, -0.6, -1.0)],
           [J(4.1, -0.5, -0.35), J(4.1, 0.5, -0.35), J(4.1, 0.35, -0.62), J(4.1, -0.35, -0.62)]]
    lot.put(M["blind2"], G.loft(jaw, True, True))
    for k in range(4):
        x = 1.4 + 0.75 * k
        for s in (-1, 1):
            lot.put(M["os"], pointe(P(x, s * (0.9 - 0.12 * k), -0.45), (0.0, 0.0, -1.0), 0.6 * K, 0.14 * K, 4))
            lot.put(M["os"], pointe(J(x, s * (0.78 - 0.1 * k), -0.5), (0.0, 0.0, 1.0), 0.5 * K, 0.13 * K, 4))
    # gueule-canon : vortex au fond de la gueule, grossit et s'avance avec la charge
    rv = (0.45 + 0.55 * charge) * K
    lot.put(M["coeur"], G.sphere(P(1.6 + 0.6 * charge, 0.0, -0.3 - 0.3 * ouverture), rv, 12, 6))
    lot.put(M["halo"], G.sphere(P(1.8 + 0.7 * charge, 0.0, -0.3 - 0.3 * ouverture), rv * 1.9, 12, 6))
    # couronne de cristaux : vers l'arrière, la plus haute au centre
    grappe(lot, M, P(0.2, 0.0, 1.15), G.norm((-0.75, 0.0, 0.85)), 3.2, 0.36, 4, 3, ouvert=0.7)
    for s in (-1, 1):
        cristal(lot, M, P(0.9, s * 1.1, 0.75), G.norm((-0.6, s * 0.8, 0.45)), 2.0, 0.28)
        cristal(lot, M, P(2.8, s * 0.7, 0.55), G.norm((-0.3, s * 0.6, 0.8)), 0.9, 0.18, noyau=False)


def build(S, lot, u=0.0, attaque=None):
    """Pose du Kaiju : u = phase de course ; attaque = phase d'attaque (0 à 1) ou None."""
    M = matieres(S)
    R.raz()
    bob = 0.14 * math.sin(G.TAU * 2.0 * u) if attaque is None else 0.0
    eclat = 0.0 if attaque is None else max(0.0, (attaque - 0.25) / 0.75)
    pts, prof = corps(lot, M, u, bob, eclat)
    hanches = {"AG": (3.4, 2.4, 5.4 + bob), "AD": (3.4, -2.4, 5.4 + bob), "PG": (-3.6, 2.3, 5.0 + bob), "PD": (-3.6, -2.3, 5.0 + bob)}
    pieds = {"AG": (4.2, 3.5, 0.0), "AD": (4.2, -3.5, 0.0), "PG": (-4.0, 3.4, 0.0), "PD": (-4.0, -3.4, 0.0)}
    phase = {"AG": 0.0, "PD": 0.0, "AD": 0.5, "PG": 0.5}
    if attaque is not None:
        for k in phase:
            phase[k] = 0.1 if k in ("AG", "PD") else 0.35
        u = 0.0
    for k in ("PG", "PD", "AG", "AD"):
        patte(lot, M, hanches[k], pieds[k], u + phase[k], k[0] == "A", 1 if k[1] == "G" else -1)
    if attaque is None:
        tete(lot, M, (7.6, 0.0, 6.5 + bob), 0.15, 0.0)
    else:
        a = attaque
        ouverture = min(1.0, a * 2.2)
        charge = max(0.0, (a - 0.25) / 0.75)
        tete(lot, M, (7.9, 0.0, 6.5 - 1.6 * ouverture), ouverture, charge)
    return {"pieces": lot.n, "u": u, "attaque": attaque}


def build_anime(S, lot, stage, u, attaque):
    """Entrée commune des titans animés (batch_titans.anime) : le Kaiju n'a pas de stade (un prototype par ère : l'échelle vient du jeu)."""
    return build(S, lot, u, attaque)
