"""HÉLIASTE (robot 11, âge 14 Orbite, expérimental d'artillerie, géant). Idée : un satellite qui a atterri sur des pattes : le plus large de la gamme, 2 ailes de panneaux dorés dépliées (feuille d'or froissée, cellules bleues), au
centre une grande parabole dressée (l'arme, un miroir qui concentre : tir de zone), réservoirs sphériques dorés, mâts à balises rouges, 8 pattes fines. Bible : or #C9A23A froissé, blanc #CFCBC2, cellules #1E2A55, reflets #2F6BFF, balises #FF2A2A."""
import math

import formes as F
import gamme as Ga
import geo as G
import marionette as Mr

CAP = math.radians(-125.0)
Z_H, Z_C = 5.1, 6.7        # anneau des hanches, centre du corps
R_H, R_P = 2.3, 6.3
L1, L2 = 2.9, 7.0
PAS, BETA, LEVE = 2.2, 0.6, 1.15
IMAGES = 0
HAUTEUR_JEU = round(Z_H * Mr.PROJ, 3)
PART_JEU = (L1 + L2) / 2.0
NB = 8
A8 = math.pi / 8.0
TABLE = Ga.table_cercle(NB, R_H, R_P, Z_H, a0=A8, genou=1.2)


def jambes_jeu():
    return Ga.jambes_jeu((22.5, 67.5, 112.5, 157.5, -22.5, -67.5, -112.5, -157.5), R_H, R_P)


def matieres(S):
    import mat as MT
    Ga.patine(ta=0.14, ra=0.2, ec=0.15, nu_k=1.25, ec_col=(0.05, 0.04, 0.03), sans=("or", "cell"))
    cr = (0.03, 0.022, 0.012)
    sf = F.surf
    M = {}
    M["or"] = sf("rb14_or", (0.64, 0.42, 0.09), rough=0.28, met=0.6, tole=(0.3, 0.2), joint=0.8, joint_l=0.02, var=0.35, usure=0.4, nu=(0.95, 0.82, 0.42), crasse=0.65, crasse_col=cr, relief=1.0, grain=0.22, graine=1401)
    M["or2"] = sf("rb14_or2", (0.74, 0.54, 0.16), rough=0.26, met=0.55, usure=0.4, nu=(0.98, 0.88, 0.55), crasse=0.65, crasse_col=cr, grain=0.14, graine=1402)
    M["blanc"] = sf("rb14_blanc", (0.56, 0.54, 0.49), rough=0.32, met=0.05, tole=(0.8, 0.42), joint=0.55, joint_l=0.006, var=0.05, coulures=0.35, rouille=(0.18, 0.15, 0.1), usure=0.3, nu=(0.78, 0.76, 0.7), crasse=0.75, crasse_col=cr, relief=0.45, graine=1403)
    M["cell"] = sf("rb14_cell", (0.02, 0.035, 0.11), rough=0.14, met=0.35, tole=(0.3, 0.3), joint=2.4, joint_l=0.012, var=0.25, usure=0.1, nu=(0.1, 0.2, 0.5), crasse=0.25, crasse_col=(0.01, 0.01, 0.03), relief=0.3, graine=1404)
    M["sombre"] = sf("rb14_sombre", (0.032, 0.03, 0.034), rough=0.5, met=0.4, usure=0.4, nu=(0.28, 0.26, 0.26), crasse=0.6, crasse_col=(0.004, 0.004, 0.004), graine=1405)
    M["peint"] = sf("rb14_peint", (0.58, 0.56, 0.5), rough=0.34, met=0.15, usure=0.4, nu=(0.82, 0.8, 0.74), crasse=0.5, crasse_col=cr, graine=1406)
    M["peint"]["fo_teinte"] = 1
    M["reflet"] = MT.lumiere(S, "rb14_reflet", (0.03, 0.15, 1.0), 0.8, main=0.5)
    M["balise"] = MT.lumiere(S, "rb14_balise", (1.0, 0.024, 0.024), 1.6, main=0.5)
    M["foyer"] = MT.lumiere(S, "rb14_foyer", (1.0, 0.72, 0.28), 1.5, main=0.55)
    return M


def squelette_torse(cap):
    sq = Mr.Squelette()
    sq.os("racine", None, Mr.rz(cap))
    sq.os("corps", "racine")
    return sq


def squelette(phase, cap=CAP, pas=PAS):
    sq = squelette_torse(cap)
    _a, m = Ga.corps_marche(phase, 0.0, bob=0.08, tangage=0.0, roulis=0.012)
    Ga.pattes(sq, m, phase, pas, BETA, LEVE, L1, L2, TABLE, pied_z=0.0, incl=0.3)
    return sq


def modele_piece(lot, M, partie):
    if partie == "haut":
        lot.put(M["blanc"], F.poutre([(0.0, 0.34, 0.4), (0.6, 0.3, 0.3), (L1 - 0.2, 0.18, 0.18), (L1, 0.2, 0.2)], 0.42))
        lot.put(M["or2"], F.poutre([(0.12, 0.05, 0.03, 0.2), (L1 - 0.3, 0.04, 0.02, 0.1)]))
        for x, k in ((0.3, 0.28), (L1 - 0.3, 0.16)):
            lot.put(M["sombre"], F.bague((x, 0.0, 0.0), k * 0.5, k, 0.1, "x", 10, 0.016))
    elif partie == "bas":
        lot.put(M["blanc"], F.poutre([(0.0, 0.26, 0.28), (L2 * 0.4, 0.18, 0.2), (L2 - 0.7, 0.09, 0.1), (L2 - 0.1, 0.075, 0.08)], 0.42))
        for t, k in ((0.1, 0.22), (0.42, 0.16), (0.72, 0.11), (0.92, 0.1)):
            lot.put(M["or2"], F.bague((L2 * t, 0.0, 0.0), k * 0.5, k, 0.08, "x", 10, 0.014))
        lot.put(M["sombre"], F.pose(F.disque((L2 * 0.27, 0.0, 0.0), 0.024, L2 * 0.5, "x", 6), (0.5, 0.0, 0.12), (1.0, 0.0, -0.02)))
        lot.put(M["or2"], G.tour([(L2 - 0.5, 0.09), (L2 - 0.2, 0.17), (L2 - 0.06, 0.34), (L2 + 0.02, 0.4), (L2 + 0.1, 0.28), (L2 + 0.14, 0.0)], 8, "x"))
        lot.put(M["sombre"], F.bague((L2 - 0.12, 0.0, 0.0), 0.16, 0.3, 0.04, "x", 8, 0.008))
    else:
        lot.put(M["or2"], G.sphere((0.0, 0.0, 0.0), 0.34, 16, 8))
        lot.put(M["sombre"], F.bague((0.0, 0.0, 0.0), 0.3, 0.42, 0.1, "z", 12, 0.02))
        lot.put(M["blanc"], F.disque((0.0, 0.0, 0.6), 0.03, 1.1, "z", 6))
        lot.put(M["balise"], G.sphere((0.0, 0.0, 1.18), 0.055, 8, 4))


def _aile(c, M, s, r):
    """Une aile (s = ±1, le long de Y) : bras, 3 panneaux, chacun plié de quelques degrés (dièdre et fronce) ; or derrière, cellules dessus."""
    y0, z0 = s * 2.0, Z_C + 0.5
    c.put(M["sombre"], F.bielle((0.0, s * 0.8, Z_C + 0.3), (0.0, y0, z0), 0.2, 0.2))
    c.put(M["or2"], F.disque((0.0, y0, z0), 0.2, 0.34, "y", 12))
    largeur = (2.3, 2.1, 1.7)
    longueur = (1.55, 1.5, 1.35)
    y, z = y0 + s * 0.12, z0
    for i in range(3):
        L, W = longueur[i], largeur[i]
        pli = (0.13, 0.05, -0.04)[i]
        y1, z1 = y + s * L * math.cos(pli), z + L * math.sin(pli)
        # panneau : dessus cellules, dessous or, cadre sombre
        def coin(u_, v_, h=0.0):
            return (u_ * W / 2.0, y + (y1 - y) * v_, z + (z1 - z) * v_ + h + u_ * 0.09)
        c.put(M["or"], ([coin(-1, 0, -0.04), coin(1, 0, -0.04), coin(1, 1, -0.04), coin(-1, 1, -0.04)], [(0, 1, 2, 3)], [(0, 0), (W, 0), (W, L), (0, L)]))
        c.put(M["cell"], ([coin(-0.94, 0.03, 0.008), coin(0.94, 0.03, 0.008), coin(0.94, 0.97, 0.008), coin(-0.94, 0.97, 0.008)], [(0, 1, 2, 3)], [(0, 0), (W, 0), (W, L), (0, L)]))
        for u_a, v_a, u_b, v_b in ((-1, 0, 1, 0), (1, 0, 1, 1), (1, 1, -1, 1), (-1, 1, -1, 0)):
            c.put(M["or2"], F.bielle(coin(u_a, v_a, 0.0), coin(u_b, v_b, 0.0), 0.05, 0.05))
        # raidisseurs et reflets, feuille froissée sur le bord
        for u_ in (-0.5, 0.0, 0.5):
            c.put(M["sombre"], F.bielle(coin(u_, 0.03, 0.012), coin(u_, 0.97, 0.012), 0.02, 0.012))
        for v_ in (0.33, 0.66):
            c.put(M["reflet"], F.bielle(coin(-0.9, v_, 0.014), coin(0.9, v_, 0.014), 0.012, 0.006))
        for k_ in range(10):
            uu, vv = r.f(-1.0, 1.0), r.f(0.0, 1.0)
            c.put(M["or2"], G.boite(coin(uu, vv, -0.045), (r.f(0.08, 0.2), r.f(0.08, 0.2), 0.02), r.f(0.0, 3.0)))
        c.put(M["sombre"], F.disque((0.0, y1, z1), 0.1, 0.16, "y", 10))
        if i == 2:
            c.put(M["blanc"], F.disque((0.0, y1 + s * 0.04, z1 + 0.34), 0.03, 0.68, "z", 6))
            c.put(M["balise"], G.sphere((0.0, y1 + s * 0.04, z1 + 0.7), 0.08, 8, 4))
        y, z = y1 + s * 0.04, z1


def modele(lots, M, r, torse=False):
    c = lots("corps")
    # anneau des hanches octogonal
    c.put(M["blanc"], G.tour([(Z_H - 0.36, 1.3), (Z_H - 0.36, 2.2), (Z_H - 0.14, 2.56), (Z_H + 0.22, 2.56), (Z_H + 0.4, 2.2), (Z_H + 0.4, 1.4)], 8, "z", a0=A8, a1=A8 + G.TAU))
    c.put(M["or2"], F.bague((0.0, 0.0, Z_H + 0.24), 2.3, 2.6, 0.07, "z", 8, 0.012, a0=A8, a1=A8 + G.TAU))
    c.put(M["peint"], F.bague((0.0, 0.0, Z_H - 0.2), 2.3, 2.6, 0.07, "z", 8, 0.012, a0=A8, a1=A8 + G.TAU))
    for k in range(NB):
        a = A8 + G.TAU * k / NB
        ca, sa = math.cos(a), math.sin(a)
        c.put(M["sombre"], F.pose(G.tour([(-0.4, 0.0), (-0.4, 0.34), (0.2, 0.36), (0.3, 0.26), (0.34, 0.0)], 8, "x"), (R_H * ca, R_H * sa, Z_H), (ca, sa, 0.0)))
    # corps : tambour blanc, feuille d'or froissée dessous, réservoirs sphériques dorés
    c.put(M["or"], G.tour([(Z_H + 0.3, 1.3), (Z_C - 0.8, 1.42), (Z_C - 0.5, 1.62)], 8, "z", a0=A8, a1=A8 + G.TAU))
    c.put(M["blanc"], G.tour([(Z_C - 0.5, 1.7), (Z_C + 0.5, 1.7), (Z_C + 0.8, 1.45), (Z_C + 0.95, 1.1), (Z_C + 0.98, 0.0)], 8, "z", a0=A8, a1=A8 + G.TAU))
    c.put(M["sombre"], F.bague((0.0, 0.0, Z_C - 0.5), 1.62, 1.76, 0.08, "z", 8, 0.014, a0=A8, a1=A8 + G.TAU))
    c.put(M["or2"], F.bague((0.0, 0.0, Z_C + 0.5), 1.62, 1.76, 0.07, "z", 8, 0.014, a0=A8, a1=A8 + G.TAU))
    for k in range(4):
        a = G.TAU * k / 4 + 0.78
        p = (2.05 * math.cos(a), 2.05 * math.sin(a), Z_C - 0.48)
        c.put(M["or2"], G.sphere(p, 0.56, 18, 10))
        c.put(M["sombre"], F.bague(p, 0.54, 0.6, 0.05, "z", 18, 0.01))
        c.put(M["sombre"], F.bielle(p, (1.5 * math.cos(a), 1.5 * math.sin(a), Z_C - 0.4), 0.1, 0.1))
    # pont : machines, conduits dorés, baies : le corps n'est pas lisse
    def pont(rr):
        a, ra = rr.f(0.0, G.TAU), rr.f(0.5, 1.42)
        return (ra * math.cos(a), ra * math.sin(a), Z_C + 0.96 - 0.3 * max(0.0, ra - 1.1) / 0.4), (0.0, 0.0, 1.0)

    def flanc(rr):
        a, z_ = rr.f(0.0, G.TAU), rr.f(Z_C - 0.42, Z_C + 0.42)
        return (1.66 * math.cos(a), 1.66 * math.sin(a), z_), (math.cos(a), math.sin(a), 0.0)

    def jupe(rr):
        a, ra = rr.f(0.0, G.TAU), rr.f(1.45, 2.45)
        return (ra * math.cos(a), ra * math.sin(a), Z_H + 0.42), (0.0, 0.0, 1.0)
    Ga.plaques(c, [M["sombre"], M["or2"], M["blanc"]], r, 70, pont, (0.1, 0.34), 0.05)
    Ga.plaques(c, [M["sombre"], M["or2"], M["blanc"], M["peint"]], r, 120, flanc, (0.07, 0.24), 0.025)
    Ga.plaques(c, [M["sombre"], M["or"], M["blanc"]], r, 80, jupe, (0.1, 0.34), 0.04)
    for k in range(8):
        a = A8 + G.TAU * k / 8
        ca, sa = math.cos(a), math.sin(a)
        c.put(M["or2"], G.tube(G.catmull([(1.7 * ca, 1.7 * sa, Z_C - 0.1), (2.0 * ca, 2.0 * sa, Z_C - 0.5), (2.1 * ca, 2.1 * sa, Z_H + 0.45)], 5), 0.04, 6))
        c.put(M["blanc"], F.fleche(0.08, 0.7, 6), (lambda v, a_=a: (v[0] + 1.62 * math.cos(a_ + 0.39), v[1] + 1.62 * math.sin(a_ + 0.39), v[2] + Z_C + 0.5)))
    # les 2 ailes
    for s in (1.0, -1.0):
        _aile(c, M, s, r)
    # parabole dressée : grand miroir blanc et or, face à l'avant et au ciel, cornet au foyer
    pd = (0.32, 0.0, Z_C + 1.22)
    d = G.norm((0.62, 0.0, 0.78))
    c.put(M["sombre"], F.bielle((0.0, 0.0, Z_C + 0.9), pd, 0.34, 0.34))
    c.put(M["or2"], F.disque((0.0, 0.0, Z_C + 1.0), 0.5, 0.14, "z", 16))
    prof = [(0.0, 0.0), (0.04, 0.5), (0.14, 1.0), (0.32, 1.5), (0.52, 1.92), (0.58, 2.02)]
    c.put(M["blanc"], F.incline(G.tour(prof, 40, "z"), pd, d))
    dos = [(q[0] - 0.05, q[1]) for q in prof]
    c.put(M["or"], F.incline(G.tour(dos, 40, "z"), pd, d))
    c.put(M["or2"], F.incline(F.bague((0.0, 0.0, 0.58), 1.96, 2.08, 0.05, "z", 40, 0.01), pd, d))
    for k in range(3):
        a = G.TAU * k / 3 + 0.5
        ri = (1.5 * math.cos(a), 1.5 * math.sin(a), 0.3)
        fo = (0.0, 0.0, 1.5)
        v_, f_, u_ = F.bielle(ri, fo, 0.05, 0.05)
        c.put(M["sombre"], F.incline((v_, f_, u_), pd, d))
    c.put(M["sombre"], F.incline(G.tour([(1.42, 0.1), (1.56, 0.22), (1.72, 0.14)], 12, "z", cap1=True), pd, d))
    c.put(M["foyer"], F.incline(G.sphere((0.0, 0.0, 1.46), 0.13, 10, 5), pd, d))
    for k in range(12):
        a = G.TAU * k / 12
        c.put(M["reflet"], F.incline(F.bielle((0.5 * math.cos(a), 0.5 * math.sin(a), 0.055), (1.85 * math.cos(a), 1.85 * math.sin(a), 0.54), 0.014, 0.012), pd, d))
    # mâts à balises derrière
    for x, y, h in ((-1.25, 0.8, 2.3), (-1.3, -0.5, 1.7)):
        c.put(M["blanc"], F.disque((x, y, Z_C + 0.5 + h / 2.0), 0.03, h, "z", 6))
        for z_ in (0.4, 0.8):
            c.put(M["sombre"], F.bague((x, y, Z_C + 0.5 + h * z_), 0.03, 0.09, 0.03, "z", 6, 0.006))
        c.put(M["balise"], G.sphere((x, y, Z_C + 0.5 + h + 0.03), 0.07, 8, 4))
    # pattes
    for k in range(0 if torse else NB):
        nom = str(k)
        modele_piece(lots("cuisse_" + nom), M, "haut")
        modele_piece(lots("tibia_" + nom), M, "bas")
        pi = lots("pied_" + nom)
        pi.put(M["or2"], G.tour([(0.0, 0.34), (0.04, 0.38), (0.14, 0.28), (0.4, 0.1), (0.56, 0.08)], 8, "z", cap1=True))
        pi.put(M["sombre"], F.bague((0.0, 0.0, 0.12), 0.2, 0.33, 0.03, "z", 8, 0.008))
