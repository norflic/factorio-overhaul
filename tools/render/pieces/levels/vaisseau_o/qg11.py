"""QG ÂGE 11 : TITANE (série du 31/10). Emprise 14×7. NEZ À DROITE (+X), tuyères à gauche.

Bible (DESIGN_EPOQUES §5, époque 11, ère IV) : « Tour blanche : tour effilée ; 4 ailerons triangulaires ; posée sur 4 pieds
(vides au sol) ; flèche » ; kit : aileron (3 tailles), flèche, pied en V, bandeau lumineux ; lignes bleu-blanc #BFE6FF.
Palette 60/30/10 validée par le DC pour les familles de l'âge 11 (commun/ages.py, _m11, ronde 3, qui remplace le « tout
blanc » de la bible) : BLEU TITANE franc (capots, caissons) / ALLIAGE blanc bleuté pâle (ailerons, côtes) et BLEU NUIT de
structure / ORANGE aéronautique (repères). Peau jaune d'origine : quelques pièces au crâne et à la dérive.

Lecture : le vaisseau entier, élancé, posé sur 4 pieds en V, vide franc dessous, nez en flèche ; deux grandes ailes delta ;
la tour effilée à 4 ailerons et sa flèche sort de la cage des côtes ; devant, le hangar en flèche sur pieds ; derrière, les
aiguilles à ailerons (3 tailles).
"""
import math

import carcasse as C
import ere4 as E
import geo as G
import mat as MT

POSE = dict(T=(0.0, 0.95, 2.45), lacet=-0.105, tangage=0.0, roulis=0.17)
TAU = G.TAU
TOP = math.pi / 2


def matieres(S):
    M = {}
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.2, ra=0.3, ec=0.36, nu_k=1.25, ec_col=(0.03, 0.042, 0.075))
    sf = MT.surface
    cr = (0.008, 0.01, 0.014)
    rou = (0.1, 0.075, 0.06)
    ti = dict(rough=0.36, met=0.3, coulures=0.7, rouille=rou, usure=0.7, nu=(0.62, 0.68, 0.76), crasse=0.9, crasse_col=cr, pied=(0.3, 1.2, 0.35), grain=0.11)
    M["capot"] = sf("q11_titane", (0.16, 0.31, 0.68), graine=301, **ti)
    M["capot2"] = sf("q11_titane2", (0.1, 0.2, 0.47), graine=302, **ti)
    M["capot3"] = sf("q11_titane3", (0.27, 0.45, 0.82), graine=303, **ti)
    al = dict(rough=0.38, met=0.3, coulures=0.7, rouille=(0.14, 0.11, 0.09), usure=0.6, nu=(0.82, 0.84, 0.86), crasse=0.9, crasse_col=cr, pied=(0.2, 1.0, 0.3), grain=0.1)
    M["alliage"] = sf("q11_alliage", (0.4, 0.45, 0.53), graine=304, **al)
    M["alliage2"] = sf("q11_alliage2", (0.24, 0.29, 0.36), graine=305, **al)
    M["alliage_t"] = M["alliage"]
    M["cote"] = sf("q11_cote", (0.15, 0.19, 0.26), graine=306, **al)
    M["nuit"] = sf("q11_nuit", (0.012, 0.022, 0.058), rough=0.42, met=0.5, coulures=0.4, rouille=rou, usure=0.8, nu=(0.42, 0.46, 0.55), crasse=0.7, crasse_col=(0.004, 0.005, 0.008), grain=0.12, graine=307)
    M["orange"] = sf("q11_orange", (0.62, 0.15, 0.012), rough=0.45, met=0.1, usure=0.5, nu=(0.75, 0.6, 0.45), crasse=0.6, crasse_col=cr, coulures=0.4, graine=308)
    M["acier"] = sf("q11_acier", (0.06, 0.066, 0.078), rough=0.42, met=0.6, usure=0.85, nu=(0.66, 0.68, 0.72), crasse=0.7, crasse_col=cr, coulures=0.35, rouille=rou, graine=309)
    M["acier_clair"] = sf("q11_acier_clair", (0.34, 0.36, 0.4), rough=0.36, met=0.7, usure=0.4, crasse=0.6, crasse_col=cr, graine=310)
    M["riv"] = sf("q11_riv", (0.1, 0.11, 0.13), rough=0.5, met=0.4, usure=0.3, crasse=0.5, graine=311)
    M["bague"] = M["cote"]
    M["epine"] = M["orange"]
    M["noyau"] = sf("q11_noyau", (0.006, 0.0075, 0.011), rough=0.6, met=0.6, usure=0.2, crasse=0.8, crasse_col=(0.002, 0.003, 0.004), graine=312)
    M["brule"] = sf("q11_brule", (0.009, 0.01, 0.012), rough=0.75, met=0.4, usure=0.0, crasse=0.8, crasse_col=(0.003, 0.003, 0.003), graine=313)
    ja = dict(rough=0.48, met=0.2, coulures=0.9, rouille=(0.16, 0.06, 0.02), usure=0.85, nu=(0.62, 0.6, 0.56), crasse=0.95, crasse_col=cr, pied=(0.3, 1.1, 0.5), grain=0.11)
    M["jaune"] = sf("q11_jaune", (0.36, 0.205, 0.013), graine=314, **ja)
    M["chevron"] = sf("q11_chevron", (0.36, 0.205, 0.013), rough=0.5, met=0.2, bandes=(0.19, (0.012, 0.011, 0.012), 0.5), usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.6, graine=315)
    M["noir"] = sf("q11_noir", (0.011, 0.012, 0.014), rough=0.7, met=0.0, usure=0.2, crasse=0.3, graine=316)
    M["caoutchouc"] = sf("q11_caoutchouc", (0.02, 0.022, 0.026), rough=0.72, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.08), crasse=0.5, crasse_col=cr, graine=317)
    M["bande"] = sf("q11_bande", (0.62, 0.15, 0.012), rough=0.5, met=0.1, bandes=(0.12, (0.5, 0.54, 0.6), 0.5), usure=0.5, crasse=0.6, crasse_col=cr, graine=318)
    M["dalle"] = sf("q11_dalle", (0.11, 0.135, 0.18), rough=0.7, met=0.1, tole=(0.55, 0.55), joint=0.3, joint_l=0.02, var=0.14, usure=0.5, nu=(0.4, 0.44, 0.5), crasse=0.85, crasse_col=cr, relief=0.6, grain=0.14, graine=319)
    M["verre_sombre"] = MT.verre("q11_verre_sombre", col=(0.006, 0.014, 0.03), reflet=(0.14, 0.22, 0.34))
    M["hublot"] = MT.lumiere(S, "q11_hublot", (0.42, 0.75, 1.0), 3.0, main=0.35)
    M["ligne"] = MT.lumiere(S, "q11_ligne", (0.3, 0.68, 1.0), 2.6, main=0.3)
    M["veilleuse"] = MT.verre("q11_veilleuse", col=(0.02, 0.04, 0.07), reflet=(0.26, 0.36, 0.48))
    M["voyant"] = MT.lumiere(S, "q11_voyant", (1.0, 0.32, 0.03), 7.0, main=0.4)
    M["coeur"] = MT.lumiere(S, "q11_coeur", (0.18, 0.58, 1.0), 2.4, main=0.25)
    return M


def tour_oct(prof, c, n=8, phase=0.3927):
    """Fût à n pans : prof = [(z, r)], pans francs (arêtes vives par l'angle d'adoucissement)."""
    rings = []
    for (z, r_) in prof:
        rings.append([(c[0] + r_ * math.cos(phase + TAU * j / n), c[1] + r_ * math.sin(phase + TAU * j / n), z) for j in range(n)])
    return G.loft(rings, cap1=True)


def build(S, lot):
    M = matieres(S)
    P = E.PoseK(**POSE)
    r = G.Rnd(1110)
    ra = G.Rnd(1111)
    niv = P.niv
    mc = E.tirage(M, [(0.4, "capot"), (0.2, "capot2"), (0.1, "capot3"), (0.1, "cote"), (0.09, "nuit"), (0.08, "jaune"), (0.03, "alliage2")])
    sc = C.surf_coque

    # ======================================================================================== 1. carcasse
    E.crane(lot, M, P, r, mc, lisse=E.LISSE2)
    E.queue(lot, M, P, r, mc, lisse=E.LISSE2)
    E.dos(lot, M, P, r, mc, lisse=E.LISSE2)
    E.epine(lot, M, P)
    E.lisses(lot, M, P)
    pieds = E.cotes(lot, M, P, haut=lambda x: 0.42)
    rn = G.Rnd(1112)

    def fins_nac(s, sn, R, xar):
        for (ang, h, x0, x1) in ((TOP + 0.05, 0.75, -1.2, -2.45), (TOP + 1.9, 0.5, -1.45, -2.45)):
            E.aileron(lot, M["alliage"], M["capot"], M["acier_clair"], None, sn(x0, ang, 0.0), sn(x1, ang, 0.0), sn(xar - 0.25, ang, h), rn, 0.04)
        lot.put(M["orange"], G.tour([(xar + 0.1, R * 0.98), (xar + 0.2, R * 0.98)], 32, "x"))
        E.bazar(lot, M, sn, -0.35, -2.3, 0.9, 2.9, rn, 16, ("capot2", "cote", "acier", "capot3"))
    E.tuyeres(lot, M, P, r, mc, lisse=E.LISSE2, apres=fins_nac)
    E.menus(lot, M, P, G.Rnd(1113), n=280, cles=("acier", "cote", "acier_clair", "nuit"))
    lot.xf = P.xf
    E.bazar(lot, M, sc, -3.35, -2.3, TOP - 1.1, TOP + 1.2, rn, 22, ("capot2", "cote", "acier", "capot3"))
    E.bazar(lot, M, sc, 2.3, 3.0, TOP - 1.2, TOP + 1.2, rn, 14, ("capot2", "cote", "acier", "capot3"))
    E.bazar(lot, M, sc, 4.35, 5.1, TOP - 1.0, TOP + 1.0, rn, 10, ("capot2", "cote", "acier", "capot3"))
    # nez en flèche : aiguille de pitot, canards triangulaires
    tip = C.point(5.5, TOP, 0.0)
    lot.put(M["acier_clair"], E.tube_conique((5.74, 0.0, tip[2] - 0.05), (6.2, 0.0, tip[2] + 0.02), 0.035, 0.012, 10, 6))
    lot.put(M["orange"], E.tube_conique((5.86, 0.0, tip[2] - 0.04), (5.95, 0.0, tip[2] - 0.035), 0.036, 0.034, 3, 6))
    for s in (-1, 1):
        E.aileron(lot, M["alliage"], M["capot"], M["acier_clair"], M["ligne"], (3.75, s * 0.9, -0.28), (2.75, s * 1.1, -0.34), (2.55, s * 2.05, -0.12), rn, 0.04)
    # grilles et marquages
    for (x, a, w, l) in ((3.0, TOP - 0.7, 0.32, 0.4), (3.9, TOP + 0.95, 0.26, 0.36), (-2.9, TOP + 0.2, 0.3, 0.5), (-2.6, TOP + 1.0, 0.24, 0.42)):
        p, n = C.point(x, a, 0.07), C.normale_s(sc, x, a)
        lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (l + 0.06, w + 0.06, 0.04)), p, n))
        lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.015), (l, w, 0.03)), p, n))
        for k in range(6):
            lot.put(M["acier"], C.pose_plane(G.boite((-l / 2 + l * (k + 0.5) / 6, 0, 0.035), (l / 6 * 0.45, w, 0.025)), p, n))
    for (x, a, w, l, m) in ((-2.75, TOP - 0.55, 0.08, 0.7, "orange"), (2.45, TOP + 0.7, 0.07, 0.55, "orange"), (4.2, TOP - 0.9, 0.09, 0.42, "alliage"), (-3.1, TOP + 0.75, 0.08, 0.45, "alliage")):
        p, n = C.point(x, a, 0.05), C.normale_s(sc, x, a)
        lot.put(M[m], C.pose_plane(G.boite((0, 0, 0.0), (l, w, 0.022)), p, n))

    # -- dérive haute, triangulaire --
    z0 = C.z_dessus(-2.4)
    E.aileron(lot, M["alliage"], M["capot"], M["acier_clair"], M["ligne"], (-2.1, 0.0, z0 - 0.05), (-3.55, 0.0, z0 - 0.12), (-4.35, 0.0, z0 + 2.35), rn, 0.09)
    lot.put(M["chevron"], E.plan3([(-3.94, 0.0, z0 + 1.45), (-3.48, 0.0, z0 + 1.45), (-3.9, 0.0, z0 + 2.0), (-4.2, 0.0, z0 + 2.0)], 0.11))
    lot.put(M["voyant"], G.sphere((-4.35, 0.0, z0 + 2.38), 0.04, 8, 4))
    # -- ailes delta --
    for (s, tp) in ((1, (-6.0, 4.15, 0.55)), (-1, (-5.7, -3.75, 0.0))):
        a, b = (-0.9, s * 1.32, -0.22), (-3.95, s * 1.32, -0.34)
        lot.put(M["alliage"], E.plan3([a, b, tp], 0.07))
        for t in (0.12, 0.28, 0.44, 0.6, 0.76):
            lot.put(M["nuit"], G.tube([G.add(G.lerp(a, tp, t), (0, 0, 0.038)), G.add(G.lerp(b, tp, t), (0, 0, 0.038))], 0.009, 4))
        for t in (0.3, 0.6):
            lot.put(M["nuit"], G.tube([G.add(G.lerp(a, b, t), (0, 0, 0.038)), G.add(tp, (0, 0, 0.038))], 0.009, 4))
        lot.put(M["acier_clair"], E.tube_conique(a, tp, 0.045, 0.014, 12, 6))
        E.chenillard(lot, M["ligne"], G.lerp(a, tp, 0.08), G.lerp(a, tp, 0.92), rn, r=0.016)
        off = (0.0, 0.0, 0.042)
        # panneaux rapportés : bleu près de l'emplanture, orange en bout
        tri = lambda u, v: G.add(G.add(G.add(G.mul(a, 1 - u - v), G.mul(b, u)), G.mul(tp, v)), off)
        for (ps, m) in (([(0.08, 0.04), (0.62, 0.04), (0.5, 0.26), (0.1, 0.26)], "capot"), ([(0.2, 0.32), (0.45, 0.32), (0.34, 0.52), (0.22, 0.52)], "capot2"),
                        ([(0.06, 0.72), (0.2, 0.72), (0.12, 0.88), (0.05, 0.88)], "orange"), ([(0.66, 0.05), (0.84, 0.05), (0.7, 0.2)], "nuit")):
            lot.put(M[m], E.plan3([tri(u, v) for (u, v) in ps], 0.012))
        lot.put(M["voyant"], G.sphere(G.add(tp, (0.0, 0.0, 0.04)), 0.035, 6, 3))

    # ======================================================================================== 2. quille, 4 pieds en V
    lot.xf = None
    ce = niv((0.25, -0.05, 0.0))
    mc2 = E.tirage(M, [(0.4, "capot"), (0.22, "capot2"), (0.1, "capot3"), (0.2, "nuit"), (0.08, "cote")], None)
    fv = E.surf_fuseau(ce, 6.0, 2.1, 0.66, 2.05, POSE["lacet"])
    C.noyau(lot, M["noyau"], fv, -2.98, 2.98, 0.0, TAU)
    C.blindage(lot, fv, -2.95, 2.95, -0.6, math.pi + 0.6, mc2, r, Mriv=M["riv"], **E.LISSE2)
    C.blindage(lot, fv, -2.95, 2.95, math.pi + 0.6, TAU - 0.6, lambda rr, xm, am: M["nuit"], r, Mriv=None, **E.LISSE)
    CL0 = ("nuit", "verre_sombre", "ligne", "acier", "noir", "cote", "voyant")
    E.rangee(lot, M, fv, -2.5, 2.5, math.pi - 0.2, ra, ["verre", "grille", "ecran", "boite", "verre", "porte", "grille"], CL0, sauts=((1.45, 2.3),))
    E.rangee(lot, M, fv, -2.2, 2.2, math.pi + 0.4, ra, ["grille", "boite", "boite", "grille"], CL0)
    E.bazar(lot, M, fv, -2.5, 2.5, math.pi - 1.0, math.pi - 0.45, G.Rnd(1115), 22, ("capot2", "cote", "acier", "capot3"))
    # cœur : port rond à grille, sur le flanc
    p, n = fv(1.88, math.pi - 0.2, 0.05), C.normale_s(fv, 1.88, math.pi - 0.2)
    lot.put(M["nuit"], G.oriente(G.tour([(0.0, 0.37), (0.05, 0.35), (0.07, 0.28), (0.02, 0.25)], 24, "z"), p, n))
    lot.put(M["coeur"], G.oriente(G.tour([(0.02, 0.25), (0.022, 0.0)], 24, "z"), p, n))
    for d in (-0.13, -0.04, 0.05, 0.14):
        lot.put(M["acier_clair"], E.pose(G.boite((d, 0.0, 0.05), (0.024, 0.52, 0.022)), p, n))
    # 4 pieds en V sous les côtes
    for (i, j, fx, ny) in ((0, 1, -2.05, 1), (2, 3, 0.75, 1), (0, 1, -2.05, -1), (2, 3, 0.75, -1)):
        q0, q1 = pieds[i][0 if ny > 0 else 1], pieds[j][0 if ny > 0 else 1]
        foot = niv((fx, ny * 2.05, 0.0))
        a, b = G.add(q0, (0.0, 0.0, 0.05)), G.add(q1, (0.0, 0.0, 0.05))
        E.pied_v(lot, M["alliage2"], M["nuit"], M["orange"], (foot[0], foot[1]), a, b, 0.095)
        lot.put(M["dalle"], G.tour([(0.0, 0.62), (0.05, 0.6)], 6, "z", (foot[0], foot[1], 0.0), cap1=True))
    # tirants (les nacelles et le nez restent en porte-à-faux)
    for (a, b) in ((pieds[0][1], P.xf((-3.6, -1.25, -0.8))), (pieds[0][0], P.xf((-3.6, 1.25, -0.8))), (pieds[3][1], P.xf((3.0, -0.7, -0.5))), (pieds[3][0], P.xf((3.0, 0.7, -0.5)))):
        lot.put(M["acier_clair"], G.tube([a, b], 0.018, 5))
    # flexibles et conduites qui descendent au sol
    for (a, b, c) in ((niv((-1.5, -0.85, 1.6)), niv((-1.9, -1.45, 0.6)), niv((-2.05, -2.05, 0.12))), (niv((0.95, -0.85, 1.6)), niv((1.15, -1.45, 0.6)), niv((0.75, -2.05, 0.12))),
                      (niv((-1.5, 0.85, 1.6)), niv((-1.9, 1.45, 0.6)), niv((-2.05, 2.05, 0.12))), (niv((0.95, 0.85, 1.6)), niv((1.15, 1.45, 0.6)), niv((0.75, 2.05, 0.12)))):
        C.flexible(lot, M["caoutchouc"], [a, b, c], 0.045)

    # ======================================================================================== 3. la tour effilée et sa flèche
    tc = P.xf((0.1, 0.0, 0.35))
    cx, cy = tc[0], tc[1]
    z0t = 2.55
    lot.put(M["capot"], tour_oct([(z0t, 0.84), (3.45, 0.8), (3.6, 0.66), (4.75, 0.45)], (cx, cy)))
    lot.put(M["capot3"], tour_oct([(4.75, 0.45), (4.9, 0.37), (6.15, 0.21)], (cx, cy)))
    lot.put(M["alliage"], tour_oct([(6.15, 0.21), (6.3, 0.15), (7.1, 0.085)], (cx, cy)))
    lot.put(M["alliage"], E.tube_conique((cx, cy, 7.1), (cx, cy, 10.0), 0.085, 0.016, 18, 8))     # la flèche
    lot.put(M["orange"], tour_oct([(7.05, 0.096), (7.22, 0.086)], (cx, cy)))
    lot.put(M["orange"], E.tube_conique((cx, cy, 8.3), (cx, cy, 8.42), 0.06, 0.056, 3, 8))
    lot.put(M["voyant"], G.sphere((cx, cy, 10.02), 0.03, 6, 3))
    for (z, r0) in ((3.5, 0.81), (4.78, 0.45), (6.17, 0.21)):
        lot.put(M["nuit"], tour_oct([(z - 0.03, r0 + 0.012), (z + 0.03, r0 + 0.012)], (cx, cy)))
    # galerie d'observation (anneau d'alliage, vitrage continu, vide autour)
    E.anneau(lot, M["cote"], (cx, cy, 4.36), 0.76, 0.1, 0.05, 48)
    E.anneau(lot, M["verre_sombre"], (cx, cy, 4.44), 0.72, 0.05, 0.05, 48)
    E.anneau(lot, M["alliage"], (cx, cy, 4.52), 0.76, 0.1, 0.03, 48)
    for k in range(4):
        a = TAU * k / 4 + 0.78
        lot.put(M["acier"], G.tube([(cx + 0.5 * math.cos(a), cy + 0.5 * math.sin(a), 4.05), (cx + 0.73 * math.cos(a), cy + 0.73 * math.sin(a), 4.34)], 0.016, 4))
    # plaques et menus de la tour
    for k in range(40):
        z, a = ra.f(2.9, 6.0), -TOP + ra.f(-1.1, 1.1)
        rz = 0.84 - (z - 2.55) * 0.18 if z < 4.75 else 0.45 - (z - 4.75) * 0.19
        q = (cx + rz * math.cos(a), cy + rz * math.sin(a), z)
        lot.put(M[("nuit", "acier", "cote", "alliage")[k % 4]], E.pose(G.boite((0, 0, 0.012), (ra.f(0.05, 0.14), ra.f(0.05, 0.2), 0.025)), q, (math.cos(a), math.sin(a), 0.15)))
    # 4 ailerons triangulaires (2 tailles sur la tour)
    for k in range(4):
        a = TAU * k / 4 + 0.785
        ca, sa = math.cos(a), math.sin(a)
        i0, i1, tp_ = (cx + 0.7 * ca, cy + 0.7 * sa, 2.95), (cx + 0.3 * ca, cy + 0.3 * sa, 5.5), (cx + 2.15 * ca, cy + 2.15 * sa, 2.6)
        E.aileron(lot, M["alliage"], M["capot2"] if k % 2 else M["nuit"], M["acier_clair"], M["ligne"], i0, i1, tp_, rn, 0.07)
        lot.put(M["orange"], E.plan3([G.lerp(tp_, i0, 0.16), G.lerp(tp_, i1, 0.16), tp_], 0.08))
        for t in (0.3, 0.5, 0.7):
            lot.put(M["nuit"], G.tube([G.lerp(i0, tp_, t), G.lerp(i1, tp_, t)], 0.009, 4))
    # hublots tous différents, échelle, bandeau
    for (z, a, forme, lum, rr_) in ((3.1, -TOP - 0.4, "rond", "hublot", 0.09), (3.3, -TOP + 0.4, "carre", "veilleuse", 0.07), (3.95, -TOP + 0.25, "ovale", "hublot", 0.06), (5.3, -TOP - 0.1, "octo", "veilleuse", 0.05)):
        rz = {3.1: 0.83, 3.3: 0.82, 3.95: 0.58, 5.3: 0.33}[z]
        n = (math.cos(a), math.sin(a), 0.12)
        C.hublot(lot, forme, M["acier"], M[lum], (cx + rz * math.cos(a), cy + rz * math.sin(a), z), n, rr_)
    for sg in (-1, 1):
        lot.put(M["acier"], G.tube([(cx + sg * 0.07, cy - 0.83, 3.0), (cx + sg * 0.07, cy - 0.47, 4.7)], 0.009, 4))
    for k in range(12):
        t = k / 11.0
        q = G.lerp((cx, cy - 0.84, 3.05), (cx, cy - 0.48, 4.65), t)
        lot.put(M["acier"], G.tube([G.add(q, (-0.07, 0, 0)), G.add(q, (0.07, 0, 0))], 0.007, 3))
    E.fouet(lot, M["acier"], None, (cx + 0.14, cy - 0.1, 6.02), 0.8, 0.016, 0.008)
    lot.put(M["ligne"], G.tour([(2.8, 0.86), (2.86, 0.86)], 8, "z", (cx, cy, 0.0), a0=-2.6, a1=-0.5))

    # ======================================================================================== 4. hangar en flèche au sud
    hb = [(-5.05, -3.72), (-3.95, -4.62), (3.1, -4.46), (5.75, -3.4), (3.1, -2.72), (-3.95, -2.84)]
    hc = (sum(p[0] for p in hb) / 6, sum(p[1] for p in hb) / 6)
    z0h, z1h, z2h = 0.62, 1.08, 1.34
    hb_r = list(reversed(hb))
    lot.put(M["nuit"], G.prisme(hb_r, z0h - 0.1, z0h, 1.0))
    lot.put(M["capot"], G.prisme(hb_r, z0h, z1h, 1.0))
    lot.put(M["capot2"], G.prisme([(hc[0] + (p[0] - hc[0]) * 1.0, hc[1] + (p[1] - hc[1]) * 1.0) for p in hb_r], z1h, z2h, 0.8))
    # toit plaqué : tôles irrégulières, bric-à-brac (le toit plat se lisait « dalle »)
    fr = lambda x, a, g: (x, a, z2h + g)
    mc3 = E.tirage(M, [(0.42, "capot"), (0.16, "alliage2"), (0.22, "capot2"), (0.1, "nuit"), (0.1, "capot3")], None)
    C.blindage(lot, fr, -3.15, 3.05, -4.22, -3.0, mc3, r, Mriv=M["riv"], larg=(0.4, 0.95), arcs=(0.3, 0.7), gap=0.03, ep=(0.02, 0.04), gondole=0.03, rivets=0.5)
    E.bazar(lot, M, fr, -3.0, 3.0, -4.15, -3.05, G.Rnd(1116), 64, ("capot2", "nuit", "acier", "cote"))
    for (x0_, y0_, x1_, y1_, m_) in ((3.1, -4.05, 3.75, -3.18, "capot"), (3.8, -3.85, 4.2, -3.3, "orange"), (-3.95, -4.1, -3.2, -3.05, "alliage2")):
        lot.put(M[m_], G.boite(((x0_ + x1_) / 2, (y0_ + y1_) / 2, z2h + 0.012), (x1_ - x0_, y1_ - y0_, 0.024)))
    lot.put(M["alliage2"], G.prisme(hb_r, z1h - 0.015, z1h + 0.035, 1.02))
    lot.put(M["orange"], G.prisme([(hc[0] + (p[0] - hc[0]) * 1.005, hc[1] + (p[1] - hc[1]) * 1.005) for p in hb_r], z0h + 0.04, z0h + 0.08, 1.0))
    # pieds en V courts du hangar
    for (fx, fy, ax, bx, y) in ((-3.3, -4.4, -3.8, -2.8, -4.3), (-0.95, -4.5, -1.5, -0.4, -4.45), (1.5, -4.45, 1.0, 2.0, -4.42), (3.9, -4.05, 3.4, 4.3, -4.1), (-3.3, -3.0, -3.8, -2.8, -3.05), (1.5, -3.0, 1.0, 2.0, -3.0), (4.4, -3.25, 4.0, 4.8, -3.3)):
        E.pied_v(lot, M["alliage2"], M["nuit"], M["orange"], (fx, fy), (ax, y, z0h - 0.08), (bx, y, z0h - 0.08), 0.05)
    # façade sud : pièces différentes
    x = -3.7
    typ = ["verre", "grille", "ligne", "boite", "verre", "grille", "verre", "ligne", "boite"]
    i = 0
    yf = lambda xx: -4.62 + (xx + 3.95) * (0.16 / 7.05)
    nf = G.norm((0.0226, -1.0, 0.0))
    while x < 2.8:
        w = ra.f(0.35, 0.95)
        t = typ[i % len(typ)]
        i += 1
        xm = x + w / 2
        if abs(xm + 0.75) < 0.7:
            x += w
            continue
        p = (xm, yf(xm) - 0.002, 0.86)
        if t == "verre":
            E.ecran(lot, M["nuit"], M["verre_sombre"], p, nf, w * 0.9, 0.23)
        elif t == "ligne":
            E.ecran(lot, M["nuit"], M["ligne"], p, nf, w * 0.82, 0.05)
        elif t == "grille":
            E.grille(lot, M["acier"], M["noir"], p, nf, w * 0.75, 0.22, 4)
        else:
            E.boitier(lot, M["alliage2"], M["voyant"], p, nf, w * 0.7, 0.26, 0.07)
        x += w + ra.f(0.04, 0.16)
    for k, xx in enumerate((-3.45, -2.6, -1.9, 0.15, 0.9, 1.75, 2.45)):
        q = (xx, yf(xx) - 0.004, z0h + 0.02)
        lot.put(M["nuit"], G.tube([q, G.add(q, (0, 0, z1h - z0h - 0.04))], 0.009, 4))
    # porte centrale, escalier
    dx = -0.75
    pd = (dx, yf(dx) - 0.01, 0.84)
    lot.put(M["alliage2"], E.pose(G.boite((0, 0, 0.012), (0.86, 0.5, 0.03)), pd, nf))
    lot.put(M["noir"], E.pose(G.boite((0, 0, 0.025), (0.72, 0.44, 0.02)), pd, nf))
    lot.put(M["acier"], E.pose(G.boite((0, 0, 0.038), (0.022, 0.44, 0.02)), pd, nf))
    lot.put(M["ligne"], E.pose(G.boite((0, 0.28, 0.03), (0.6, 0.03, 0.015)), pd, nf))
    yy = yf(dx) - 0.22
    lot.put(M["alliage2"], E.plan3([(dx - 0.5, yy, 0.6), (dx + 0.5, yy, 0.6), (dx + 0.5, yy + 0.2, 0.6), (dx - 0.5, yy + 0.2, 0.6)], 0.05))
    for k in range(5):
        lot.put(M["nuit"], G.boite((dx, yy - 0.09 - 0.16 * k, 0.5 - 0.1 * k), (0.84, 0.16, 0.04)))
    for sg in (-1, 1):
        lot.put(M["acier"], G.tube([(dx + sg * 0.46, yy - 0.02, 0.95), (dx + sg * 0.46, yy - 0.86, 0.42)], 0.013, 5))
    # toit : dorsale en flèche, verrière longue, évents, chenillard
    a, b, tp = (-2.95, -3.68, z2h - 0.02), (2.2, -3.6, z2h - 0.02), (-3.45, -3.68, 2.55)
    E.aileron(lot, M["capot"], M["alliage"], M["acier_clair"], M["ligne"], b, a, tp, rn, 0.07)
    for (pts, m) in (([(-2.6, -4.1), (-0.2, -4.08), (-0.2, -3.95), (-2.6, -3.97)], "verre_sombre"), ([(0.5, -4.04), (2.3, -4.0), (2.3, -3.88), (0.5, -3.92)], "verre_sombre"),
                     ([(-2.1, -3.36), (1.2, -3.3), (1.2, -3.2), (-2.1, -3.26)], "capot2"), ([(2.9, -3.8), (4.2, -3.52), (4.2, -3.42), (2.9, -3.66)], "orange")):
        zz = z2h + 0.05
        q = [(p[0], p[1], zz - 0.09 * max(0.0, abs(p[1] + 3.6) - 0.4) * 0.0) for p in pts]
        lot.put(M[m], E.plan3(q, 0.02))
    C.evente(lot, M["acier"], M["noir"], (2.65, -3.2, z2h - 0.05), 0.22, 0.44, 4, 0.05, 0.14)
    C.evente(lot, M["alliage2"], M["noir"], (-3.2, -3.25, z2h - 0.05), 0.2, 0.36, 3, -0.05, 0.14)
    E.fouet(lot, M["acier"], None, (1.4, -3.75, z2h), 1.05, 0.018, 0.008)
    E.fouet(lot, M["acier"], M["voyant"], (3.55, -3.6, z2h - 0.05), 1.5, 0.02, 0.008)
    E.chenillard(lot, M["ligne"], (-3.8, -4.65, 1.1), (3.0, -4.49, 1.1), rn, r=0.014, pas=(0.2, 0.42))
    E.chenillard(lot, M["ligne"], (3.2, -4.47, 1.1), (5.7, -3.42, 1.1), rn, r=0.014, pas=(0.2, 0.42))
    # ailerons de bout du hangar (3e taille)
    for s in (-1, 1):
        y0 = -3.7 + s * 0.6
        E.aileron(lot, M["alliage"], M["capot2"], M["acier_clair"], None, (-4.05, y0, z1h), (-4.95, y0 + s * 0.05 - 0.02, z1h - 0.1), (-5.7, y0 + s * 0.9, z1h + 0.75), rn, 0.04)
    # conduites vers la quille (pas de passerelle large : vide franc sous la coque)
    C.tuyau(lot, M["alliage2"], M["acier"], [(-0.45, -2.84, 0.92), (-0.45, -1.9, 0.92), (-0.45, -1.3, 1.3), niv((-0.45, -0.78, 1.5))], 0.08, rb=0.14, pas_bride=0.45)
    C.tuyau(lot, M["capot2"], M["acier"], [(0.35, -2.82, 0.82), (0.35, -1.9, 0.82), niv((0.35, -0.82, 1.42))], 0.05, rb=0.12, pas_bride=0.4)
    C.tuyau(lot, M["acier"], M["nuit"], [(2.35, -2.76, 0.8), (2.35, -1.95, 0.8), niv((2.35, -0.8, 1.45))], 0.032, rb=0.08, pas_bride=0.35)

    # ======================================================================================== 5. aiguilles à ailerons (3 tailles), fond
    for (ax, ay, zh, rb_, kbase) in ((5.0, 3.95, 5.15, 0.55, 0.7), (-1.9, 4.35, 3.65, 0.42, 0.35)):
        lot.put(M["dalle"], G.tour([(0.0, 1.05), (0.06, 1.0)], 6, "z", (ax, ay, 0.0), cap1=True))
        for k in range(3):
            a = TAU * k / 3 + kbase
            E.pied_v(lot, M["alliage2"], M["nuit"], M["orange"], (ax + 0.8 * math.cos(a), ay + 0.8 * math.sin(a)),
                     (ax + 0.25 * math.cos(a + 0.5), ay + 0.25 * math.sin(a + 0.5), 0.72), (ax + 0.25 * math.cos(a - 0.5), ay + 0.25 * math.sin(a - 0.5), 0.72), 0.05)
        lot.put(M["capot"], tour_oct([(0.7, rb_), (zh * 0.45, rb_ * 0.52)], (ax, ay), 6, 0.2))
        lot.put(M["alliage"], tour_oct([(zh * 0.45, rb_ * 0.52), (zh * 0.75, rb_ * 0.24)], (ax, ay), 6, 0.2))
        lot.put(M["alliage"], E.tube_conique((ax, ay, zh * 0.75), (ax, ay, zh), rb_ * 0.24, 0.01, 10, 6))
        lot.put(M["orange"], tour_oct([(zh * 0.72, rb_ * 0.28), (zh * 0.75, rb_ * 0.25)], (ax, ay), 6, 0.2))
        for k in range(3):
            a = TAU * k / 3 + kbase + 0.5
            ca, sa = math.cos(a), math.sin(a)
            E.aileron(lot, M["alliage"], M["capot2"], M["acier_clair"], M["ligne"] if k == 0 else None, (ax + rb_ * 0.85 * ca, ay + rb_ * 0.85 * sa, 0.82), (ax + rb_ * 0.45 * ca, ay + rb_ * 0.45 * sa, zh * 0.5),
                      (ax + (rb_ + 0.75) * ca, ay + (rb_ + 0.75) * sa, 0.72), rn, 0.04)
        lot.put(M["voyant"], G.sphere((ax, ay, zh + 0.02), 0.024, 6, 3))
    fouet_b = P.xf((2.72, 0.0, C.z_dessus(2.72) + 0.1))
    E.fouet(lot, M["acier_clair"], None, fouet_b, 1.4, 0.026, 0.007, ((0.45, 0.14),), M["nuit"])
    for x in (-3.0,):
        E.fouet(lot, M["acier"], None, P.xf((x, 0.0, C.z_dessus(x) + 0.25)), 0.9, 0.018, 0.006)

    # ======================================================================================== 6. réseaux, câbles, sol
    fx = [(pieds[i][1], pieds[i + 1][1], 0.28) for i in range(3)]
    fx += [(pieds[i][0], pieds[i + 1][0], 0.28) for i in range(3)]
    fx += [(P.xf((-3.4, 0.0, C.z_dessus(-3.4) + 0.3)), P.xf((-2.2, 0.8, C.z_dessus(-2.2) + 0.2)), 0.22), (P.xf((2.0, -0.9, 0.6)), P.xf((3.4, -0.85, 0.3)), 0.18),
           (P.xf((-3.2, -1.0, 0.1)), P.xf((-2.1, -1.1, 0.0)), 0.2), ((5.0, 3.4, 2.6), P.xf((3.1, 0.7, 0.8)), 0.5), ((-1.9, 3.9, 1.9), P.xf((-1.1, 1.0, 0.6)), 0.45),
           ((3.55, -3.6, 1.8), P.xf((2.8, -0.9, -0.3)), 0.4), ((-3.45, -3.68, 2.2), P.xf((-3.1, -1.25, -0.5)), 0.32), ((1.4, -3.75, 2.0), niv((1.4, -0.85, 2.2)), 0.42)]
    for (a, b, fl) in fx:
        C.faisceau(lot, M["orange"], M["noir"], a, b, fl, 3, 0.011, 0.028, r)
    for (a, b, c) in (((-5.2, -3.3, 0.55), (-5.45, -2.7, 0.1), P.xf((-3.7, -1.5, -0.8))), ((4.6, 3.3, 0.5), (3.9, 2.5, 0.08), niv((2.6, 0.9, 1.45))), ((-1.95, 3.75, 0.5), (-1.4, 2.9, 0.08), niv((-0.9, 0.9, 1.4))),
                      ((4.9, -3.2, 0.72), (5.2, -2.4, 0.1), P.xf((3.6, -0.9, -0.7))), ((-4.3, -2.82, 0.75), (-4.6, -2.2, 0.08), P.xf((-3.0, -1.6, -0.9)))):
        C.flexible(lot, M["caoutchouc"], [a, b, c], 0.042)
    # dalles triangulaires, marquages
    for (pts, m) in (([(-6.6, -4.7), (-5.2, -4.8), (-6.2, -2.9)], "dalle"), ([(6.6, -4.4), (6.5, -2.2), (5.0, -4.6)], "dalle"), ([(-6.7, 2.2), (-5.2, 4.7), (-6.7, 4.6)], "dalle"), ([(2.3, 3.1), (3.8, 4.7), (1.9, 4.7)], "dalle")):
        lot.put(M[m], E.plan3([(p[0], p[1], 0.04) for p in pts], 0.08))
    for (x, y, sz, rz, m, mk) in ((-6.0, -4.2, 0.4, 0.1, "capot", "orange"), (-5.65, -4.4, 0.32, -0.3, "alliage2", "orange"), (5.95, -3.85, 0.42, 0.5, "alliage2", "orange"), (6.0, -3.2, 0.3, 0.2, "nuit", "orange"),
                                  (2.75, 4.2, 0.36, 0.4, "capot2", "orange"), (-6.15, 3.6, 0.34, -0.2, "capot", "orange")):
        E.cale(lot, M[m], x, y, sz, rz, M[mk])
    for (x, y) in ((5.5, -4.25), (5.68, -4.32), (5.58, -4.1)):
        lot.put(M["orange"], G.tour([(0.0, 0.07), (0.46, 0.07), (0.52, 0.045), (0.58, 0.025)], 12, "z", (x, y, 0.0), cap1=True))
    E.touret(lot, M["acier"], M["orange"], -6.05, -2.5, 0.19, 0.15)
    E.touret(lot, M["acier"], M["noir"], 6.15, -2.35, 0.16, 0.13)
    E.debris_sol(lot, M, G.Rnd(1114), 34, (-6.9, 6.9), (-4.9, 4.9), lambda x, y: abs(x) < 4.2 and abs(y) < 2.7, ("acier", "alliage2", "capot"))
    return {"pose": POSE}
