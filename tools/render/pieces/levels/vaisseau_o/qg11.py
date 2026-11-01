"""QG ÂGE 11 : TITANE (reprise du 1/11, critique indépendante : le bleu est abandonné). Emprise 14×7. NEZ À DROITE (+X).

Bible (DESIGN_EPOQUES §5, époque 11) : « Tour blanche : tour effilée ; 4 ailerons triangulaires ; flèche » ; titane #8E9AA6,
alliage blanc #C9C6BE patiné, lignes #BFE6FF. Critique : gris titane, irisations de chauffe (or, violet) aux tuyères, dalle
à gradins soudée au fuselage par 3 hangars, dérive d'origine simplement gainée. Peau jaune d'origine : environ 22 % de la
coque, davantage au crâne et aux nacelles (chaîne des âges 9 à 13).

Lecture : le même vaisseau que l'âge 10, posé bas sur la même dalle ; la tour effilée et sa flèche sortent de la cage des
côtes à la place du radôme ; 3 hangars voûtés descendent du flanc vers le sud, le central porte la porte ; derrière, les
aiguilles à ailerons.
"""
import math

import carcasse as C
import ere4 as E
import geo as G
import mat as MT

POSE = E.POSE_BASSE
TAU = G.TAU
TOP = math.pi / 2


def matieres(S):
    M = {}
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.2, ra=0.34, ec=0.34, nu_k=1.25, ec_col=(0.06, 0.055, 0.05))
    sf = MT.surface
    cr = (0.009, 0.009, 0.01)
    rou = (0.1, 0.07, 0.05)
    ti = dict(rough=0.38, met=0.42, coulures=0.75, rouille=rou, usure=0.75, nu=(0.66, 0.68, 0.7), crasse=0.92, crasse_col=cr, pied=(0.2, 1.0, 0.4), grain=0.12)
    M["capot"] = sf("q11_titane", (0.34, 0.365, 0.4), graine=301, **ti)
    M["capot2"] = sf("q11_titane2", (0.2, 0.22, 0.25), graine=302, **ti)
    M["capot3"] = sf("q11_titane3", (0.5, 0.52, 0.55), graine=303, **ti)
    al = dict(rough=0.4, met=0.2, coulures=0.8, rouille=(0.15, 0.11, 0.07), usure=0.6, nu=(0.8, 0.79, 0.76), crasse=0.92, crasse_col=cr, pied=(0.2, 1.0, 0.3), grain=0.1)
    M["alliage"] = sf("q11_alliage", (0.62, 0.6, 0.555), graine=304, **al)
    M["alliage2"] = sf("q11_alliage2", (0.4, 0.39, 0.36), graine=305, **al)
    M["cote"] = sf("q11_cote", (0.055, 0.06, 0.068), rough=0.42, met=0.55, usure=0.9, nu=(0.6, 0.6, 0.6), crasse=0.7, crasse_col=cr, coulures=0.35, rouille=rou, graine=306)
    M["nuit"] = sf("q11_nuit", (0.024, 0.027, 0.034), rough=0.42, met=0.5, coulures=0.4, rouille=rou, usure=0.8, nu=(0.42, 0.43, 0.46), crasse=0.7, crasse_col=(0.004, 0.005, 0.006), grain=0.12, graine=307)
    M["acier"] = sf("q11_acier", (0.07, 0.07, 0.075), rough=0.42, met=0.6, usure=0.85, nu=(0.66, 0.66, 0.66), crasse=0.7, crasse_col=cr, coulures=0.35, rouille=rou, graine=309)
    M["acier_clair"] = sf("q11_acier_clair", (0.34, 0.35, 0.37), rough=0.36, met=0.7, usure=0.4, crasse=0.6, crasse_col=cr, graine=310)
    M["riv"] = sf("q11_riv", (0.1, 0.105, 0.115), rough=0.5, met=0.4, usure=0.3, crasse=0.5, graine=311)
    M["bague"] = M["cote"]
    M["noyau"] = sf("q11_noyau", (0.006, 0.0065, 0.008), rough=0.6, met=0.6, usure=0.2, crasse=0.8, crasse_col=(0.002, 0.003, 0.004), graine=312)
    M["brule"] = sf("q11_brule", (0.009, 0.0095, 0.011), rough=0.75, met=0.4, usure=0.0, crasse=0.8, crasse_col=(0.003, 0.003, 0.003), graine=313)
    ja = dict(rough=0.48, met=0.2, coulures=0.9, rouille=(0.16, 0.06, 0.02), usure=0.85, nu=(0.62, 0.6, 0.56), crasse=0.95, crasse_col=cr, pied=(0.3, 1.1, 0.5), grain=0.11)
    M["jaune"] = sf("q11_jaune", (0.42, 0.24, 0.014), graine=314, **ja)
    M["jaune2"] = sf("q11_jaune2", (0.26, 0.145, 0.01), graine=320, **ja)
    M["epine"] = M["jaune2"]
    M["chevron"] = sf("q11_chevron", (0.36, 0.205, 0.013), rough=0.5, met=0.2, bandes=(0.19, (0.012, 0.011, 0.012), 0.5), usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.6, graine=315)
    M["bande"] = sf("q11_bande", (0.36, 0.205, 0.013), rough=0.5, met=0.2, bandes=(0.12, (0.012, 0.011, 0.01), 0.5), usure=0.5, crasse=0.6, crasse_col=cr, graine=318)
    M["orange"] = sf("q11_orange", (0.42, 0.13, 0.02), rough=0.48, met=0.1, usure=0.5, nu=(0.7, 0.58, 0.45), crasse=0.65, crasse_col=cr, coulures=0.4, graine=308)
    M["noir"] = sf("q11_noir", (0.011, 0.012, 0.014), rough=0.7, met=0.0, usure=0.2, crasse=0.3, graine=316)
    M["caoutchouc"] = sf("q11_caoutchouc", (0.02, 0.022, 0.026), rough=0.72, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.08), crasse=0.5, crasse_col=cr, graine=317)
    M["pierre"] = sf("q11_pierre", (0.17, 0.155, 0.125), rough=0.85, met=0.0, tole=(1.1, 0.8), joint=0.5, joint_l=0.012, var=0.16, coulures=0.5, rouille=(0.05, 0.03, 0.02), usure=0.7, nu=(0.28, 0.25, 0.2), crasse=0.85, crasse_col=cr, relief=0.4, graine=323)
    M["pierre2"] = sf("q11_pierre2", (0.075, 0.064, 0.05), rough=0.85, met=0.0, coulures=0.6, rouille=(0.03, 0.02, 0.012), usure=0.7, nu=(0.16, 0.14, 0.11), crasse=0.85, crasse_col=(0.005, 0.004, 0.003), graine=324)
    M["terre"] = sf("q11_terre", (0.11, 0.065, 0.035), rough=0.95, met=0.0, usure=0.0, crasse=0.7, crasse_col=(0.03, 0.018, 0.01), graine=325)
    # irisations de chauffe des tuyères : paille, bronze, violet, bleu (bandes le long de la cloche)
    ir = dict(rough=0.3, met=0.75, usure=0.3, crasse=0.5, crasse_col=cr, grain=0.14)
    M["ir_or"] = sf("q11_ir_or", (0.62, 0.38, 0.09), graine=330, **ir)
    M["ir_bronze"] = sf("q11_ir_bronze", (0.4, 0.15, 0.08), graine=331, **ir)
    M["ir_violet"] = sf("q11_ir_violet", (0.2, 0.07, 0.32), graine=332, **ir)
    M["ir_bleu"] = sf("q11_ir_bleu", (0.07, 0.12, 0.34), graine=333, **ir)
    M["verre_sombre"] = MT.verre("q11_verre_sombre", col=(0.008, 0.013, 0.02), reflet=(0.14, 0.18, 0.24))
    M["hublot"] = MT.lumiere(S, "q11_hublot", (0.42, 0.75, 1.0), 2.6, main=0.3)
    M["ligne"] = MT.lumiere(S, "q11_ligne", (0.42, 0.75, 1.0), 2.0, main=0.22)
    M["veilleuse"] = MT.verre("q11_veilleuse", col=(0.02, 0.035, 0.06), reflet=(0.26, 0.34, 0.44))
    M["voyant"] = MT.lumiere(S, "q11_voyant", (1.0, 0.25, 0.03), 7.0, main=0.4)
    M["coeur"] = MT.lumiere(S, "q11_coeur", (0.18, 0.58, 1.0), 2.4, main=0.25)
    return M


def tour_oct(prof, c, n=8, phase=0.3927):
    """Fût à n pans : prof = [(z, r)], pans francs."""
    rings = [[(c[0] + r_ * math.cos(phase + TAU * j / n), c[1] + r_ * math.sin(phase + TAU * j / n), z) for j in range(n)] for (z, r_) in prof]
    return G.loft(rings, cap1=True)


def hangar(lot, M, r, ra, c, L, W, H, rz, zb, graine, porte=False):
    """Hangar voûté : axe vers le fuselage, tôles du vaisseau, pignon plat au sud, soudé à la coque (le bout nord y entre)."""
    f = E.surf_fuseau(c, L, W, H, zb, rz)
    x0 = -L * 0.42
    mt = E.tirage(M, [(0.4, "capot"), (0.14, "capot2"), (0.2, "alliage2"), (0.16, "capot3"), (0.1, "nuit")], None)
    C.noyau(lot, M["noyau"], f, x0, L * 0.48, -0.1, math.pi + 0.1)
    C.blindage(lot, f, x0, L * 0.47, -0.08, math.pi + 0.08, mt, r, Mriv=M["riv"], **E.LISSE2)
    # pignon
    ring = [f(x0, -0.08 + (math.pi + 0.16) * j / 24.0, 0.012) for j in range(25)]
    centre = f(x0, TOP, -H * 0.6)
    lot.put(M["nuit"], G.loft([ring, [centre] * 25], closed=False))
    for k in range(3):      # cerces de la voûte
        x = x0 + (L * 0.82) * (k + 0.35) / 3.0
        lot.put(M["cote"], G.tube([f(x, -0.08 + (math.pi + 0.16) * j / 20.0, 0.05) for j in range(21)], 0.024, 5))
    # rideau du pignon, ligne de lumière
    pa, pb = f(x0, 0.22, 0.03), f(x0, math.pi - 0.22, 0.03)
    n_ = G.rot_z((-1.0, 0.0, 0.0), rz)
    pm = G.lerp(pa, pb, 0.5)
    h_p = H * (0.72 if porte else 0.55)
    q = (pm[0], pm[1], zb + h_p / 2 + 0.04)
    w_p = W * (0.56 if porte else 0.46)
    lot.put(M["alliage2"], E.pose(G.boite((0, 0, 0.02), (w_p + 0.14, h_p + 0.1, 0.04)), q, n_))
    lot.put(M["noir"], E.pose(G.boite((0, 0, 0.035), (w_p, h_p, 0.03)), q, n_))
    for k in range(3 if porte else 2):
        lot.put(M["acier"], E.pose(G.boite((0.0, -h_p / 2 + h_p * (k + 1) / (4.0 if porte else 3.0), 0.052), (w_p, 0.018, 0.012)), q, n_))
    lot.put(M["acier"], E.pose(G.boite((0.0, 0.0, 0.055), (0.022, h_p, 0.012)), q, n_))
    lot.put(M["ligne"], E.pose(G.boite((0.0, h_p / 2 + 0.03, 0.05), (w_p * 0.8, 0.022, 0.012)), q, n_))
    # flancs et dos
    CL = ("nuit", "verre_sombre", "ligne", "acier", "noir", "cote", "voyant")
    E.rangee(lot, M, f, x0 + 0.25, L * 0.28, 0.42, ra, ["grille", "verre", "boite", "ecran", "grille"], CL)
    E.rangee(lot, M, f, x0 + 0.25, L * 0.28, math.pi - 0.42, ra, ["verre", "grille", "boite", "porte", "ecran"], CL)
    E.bazar(lot, M, f, x0 + 0.25, L * 0.3, 0.75, math.pi - 0.75, G.Rnd(graine), 26, ("capot2", "cote", "acier", "capot3"))
    return f, x0


def build(S, lot):
    M = matieres(S)
    P = E.PoseK(**POSE)
    r = G.Rnd(1110)
    ra = G.Rnd(1111)
    rn = G.Rnd(1112)
    niv = P.niv
    mc = E.tirage(M, [(0.3, "jaune"), (0.1, "jaune2"), (0.3, "capot"), (0.12, "capot2"), (0.06, "capot3"), (0.06, "nuit"), (0.06, "alliage2")])
    mn = E.tirage(M, [(0.32, "jaune"), (0.14, "jaune2"), (0.26, "capot"), (0.14, "capot2"), (0.14, "nuit")], None)
    mv = E.tirage(M, [(0.44, "capot"), (0.2, "capot2"), (0.1, "capot3"), (0.1, "alliage2"), (0.06, "nuit"), (0.1, "jaune")], None)
    sc = C.surf_coque

    # ======================================================================================== 1. dalle, carcasse
    E.terrasses(lot, M, G.Rnd(1117))
    E.butte_nez(lot, M, P, G.Rnd(1118))
    E.crane(lot, M, P, r, mc, lisse=E.LISSE2)
    E.queue(lot, M, P, r, mc, lisse=E.LISSE2)
    E.dos(lot, M, P, r, mc, lisse=E.LISSE2)
    E.epine(lot, M, P)
    E.lisses(lot, M, P)
    pieds = E.cotes(lot, M, P, haut=lambda x: 0.42)
    L_ = 0.95

    def nac(s, sn, R, xar):
        # irisations : anneaux de chauffe posés sur la cloche, du col à la lèvre
        prof = lambda f: R * (0.82 + (0.92 - 0.82) * f / 0.5) if f < 0.5 else R * (0.92 + (1.14 - 0.92) * (f - 0.5) / 0.38)
        for (f0, f1, m) in ((0.04, 0.2, "ir_or"), (0.2, 0.34, "ir_bronze"), (0.34, 0.5, "ir_violet"), (0.5, 0.66, "ir_bleu"), (0.66, 0.78, "ir_violet"), (0.78, 0.88, "ir_bronze")):
            pr = [(xar - f * L_, prof(f) + 0.012) for f in [f0 + (f1 - f0) * i / 3.0 for i in range(4)]]
            lot.put(M[m], G.tour(pr, 32, "x"))
        lot.put(M["ir_or"], G.tour([(xar + 0.1, R * 0.98), (xar + 0.02, R * 0.92)], 32, "x"))
        E.aileron(lot, M["alliage"], M["capot"], M["acier_clair"], None, sn(-1.5, TOP + 0.05, 0.0), sn(-2.45, TOP + 0.05, 0.0), sn(xar - 0.2, TOP + 0.05, 0.55), rn, 0.04)
        E.bazar(lot, M, sn, -0.35, -2.3, 0.9, 2.9, rn, 16, ("capot2", "cote", "acier", "capot3"))
    E.tuyeres(lot, M, P, r, mn, lisse=E.LISSE2, apres=nac)
    E.menus(lot, M, P, G.Rnd(1113), n=280, cles=("acier", "cote", "acier_clair", "nuit"))
    lot.xf = P.xf
    E.bazar(lot, M, sc, -3.35, -2.3, TOP - 1.1, TOP + 1.2, rn, 22, ("capot2", "cote", "acier", "capot3"))
    E.bazar(lot, M, sc, 2.3, 3.0, TOP - 1.2, TOP + 1.2, rn, 14, ("capot2", "cote", "acier", "capot3"))
    E.bazar(lot, M, sc, 4.35, 5.1, TOP - 1.0, TOP + 1.0, rn, 10, ("capot2", "cote", "acier", "capot3"))
    for s in (-1, 1):        # canards triangulaires (kit de l'âge)
        E.aileron(lot, M["alliage"], M["capot"], M["acier_clair"], None, (3.75, s * 0.9, -0.28), (2.75, s * 1.1, -0.34), (2.55, s * 1.95, -0.14), rn, 0.04)
    E.grilles_coque(lot, M, P)
    E.derive_ailes(lot, M, P, ("alliage", "capot2", "jaune", "capot", "voyant"))

    # ======================================================================================== 2. ventre, tour effilée
    fv = E.ventre(lot, M, P, mv, r)
    CL0 = ("nuit", "verre_sombre", "ligne", "acier", "noir", "cote", "voyant")
    E.rangee(lot, M, fv, -2.4, 2.4, math.pi - 0.25, ra, ["verre", "grille", "ecran", "boite", "verre", "porte", "grille"], CL0, sauts=((1.45, 2.3),))
    E.bazar(lot, M, fv, -2.5, 2.5, math.pi - 1.05, math.pi - 0.5, G.Rnd(1115), 22, ("capot2", "cote", "acier", "capot3"))
    p, n = fv(1.88, math.pi - 0.25, 0.05), C.normale_s(fv, 1.88, math.pi - 0.25)
    lot.put(M["nuit"], G.oriente(G.tour([(0.0, 0.37), (0.05, 0.35), (0.07, 0.28), (0.02, 0.25)], 24, "z"), p, n))
    lot.put(M["coeur"], G.oriente(G.tour([(0.02, 0.25), (0.022, 0.0)], 24, "z"), p, n))
    for d in (-0.13, -0.04, 0.05, 0.14):
        lot.put(M["acier_clair"], E.pose(G.boite((d, 0.0, 0.05), (0.024, 0.52, 0.022)), p, n))
    # berceaux courts, pieds en V sous les côtes : pas d'échasses
    for (i, j, fx) in ((0, 1, -2.05), (2, 3, 0.75)):
        for (cote_, ny) in ((0, 1), (1, -1)):
            q0, q1 = pieds[i][cote_], pieds[j][cote_]
            foot = niv((fx, ny * 1.85, 0.0))
            E.pied_v(lot, M["alliage2"], M["nuit"], M["orange"], (foot[0], foot[1]), G.add(q0, (0.0, 0.0, 0.05)), G.add(q1, (0.0, 0.0, 0.05)), 0.085)
    for (u, v, zt) in ((-3.6, 1.3, 0.75), (-3.9, -1.25, 0.6), (3.0, 1.05, 0.8), (3.05, -1.15, 0.55), (-5.1, 2.0, 0.75), (-5.25, -2.05, 0.65)):
        E.pied_tele(lot, M["nuit"], M["acier_clair"], M["bande"], M["capot2"], niv((u, v, zt)), 0.15)

    tc = P.xf((0.1, 0.0, 0.2))
    cx, cy = tc[0], tc[1]
    z0t = 1.9
    lot.put(M["capot"], tour_oct([(z0t, 0.84), (2.85, 0.8), (3.0, 0.66), (4.15, 0.45)], (cx, cy)))
    lot.put(M["capot3"], tour_oct([(4.15, 0.45), (4.3, 0.37), (5.55, 0.21)], (cx, cy)))
    lot.put(M["alliage"], tour_oct([(5.55, 0.21), (5.7, 0.15), (6.5, 0.085)], (cx, cy)))
    lot.put(M["alliage"], E.tube_conique((cx, cy, 6.5), (cx, cy, 8.9), 0.085, 0.016, 18, 8))     # la flèche
    lot.put(M["orange"], tour_oct([(6.45, 0.096), (6.62, 0.086)], (cx, cy)))
    lot.put(M["voyant"], G.sphere((cx, cy, 8.92), 0.03, 6, 3))
    for (z, r0) in ((2.9, 0.81), (4.18, 0.45), (5.57, 0.21)):
        lot.put(M["nuit"], tour_oct([(z - 0.03, r0 + 0.012), (z + 0.03, r0 + 0.012)], (cx, cy)))
    E.anneau(lot, M["cote"], (cx, cy, 3.76), 0.76, 0.1, 0.05, 48)
    E.anneau(lot, M["verre_sombre"], (cx, cy, 3.84), 0.72, 0.05, 0.05, 48)
    E.anneau(lot, M["alliage"], (cx, cy, 3.92), 0.76, 0.1, 0.03, 48)
    for k in range(4):
        a = TAU * k / 4 + 0.78
        lot.put(M["acier"], G.tube([(cx + 0.5 * math.cos(a), cy + 0.5 * math.sin(a), 3.45), (cx + 0.73 * math.cos(a), cy + 0.73 * math.sin(a), 3.74)], 0.016, 4))
    for k in range(44):
        z, a = ra.f(2.3, 5.4), -TOP + ra.f(-1.1, 1.1)
        rz = 0.84 - (z - 1.9) * 0.18 if z < 4.15 else 0.45 - (z - 4.15) * 0.19
        q = (cx + rz * math.cos(a), cy + rz * math.sin(a), z)
        lot.put(M[("nuit", "acier", "cote", "alliage")[k % 4]], E.pose(G.boite((0, 0, 0.012), (ra.f(0.05, 0.14), ra.f(0.05, 0.2), 0.025)), q, (math.cos(a), math.sin(a), 0.15)))
    for k in range(4):       # 4 ailerons triangulaires
        a = TAU * k / 4 + 0.785
        ca, sa = math.cos(a), math.sin(a)
        i0, i1, tp_ = (cx + 0.7 * ca, cy + 0.7 * sa, 2.35), (cx + 0.3 * ca, cy + 0.3 * sa, 4.9), (cx + 2.05 * ca, cy + 2.05 * sa, 2.1)
        E.aileron(lot, M["alliage"], M["capot2"] if k % 2 else M["nuit"], M["acier_clair"], None, i0, i1, tp_, rn, 0.07)
        E.chenillard(lot, M["ligne"], G.lerp(i1, tp_, 0.08), G.lerp(i1, tp_, 0.9), rn, r=0.009, part=0.35, pas=(0.2, 0.42))
        lot.put(M["orange"], E.plan3([G.lerp(tp_, i0, 0.14), G.lerp(tp_, i1, 0.14), tp_], 0.08))
        for t in (0.3, 0.5, 0.7):
            lot.put(M["nuit"], G.tube([G.lerp(i0, tp_, t), G.lerp(i1, tp_, t)], 0.009, 4))
    for (z, a, forme, lum, rr_, rz) in ((2.5, -TOP - 0.4, "rond", "hublot", 0.09, 0.83), (2.7, -TOP + 0.4, "carre", "veilleuse", 0.07, 0.82), (3.35, -TOP + 0.25, "ovale", "hublot", 0.06, 0.58), (4.7, -TOP - 0.1, "octo", "veilleuse", 0.05, 0.33)):
        C.hublot(lot, forme, M["acier"], M[lum], (cx + rz * math.cos(a), cy + rz * math.sin(a), z), (math.cos(a), math.sin(a), 0.12), rr_)
    E.fouet(lot, M["acier"], None, (cx + 0.14, cy - 0.1, 5.42), 0.8, 0.016, 0.008)

    # ======================================================================================== 3. les 3 hangars, soudés au flanc
    fc, xc = hangar(lot, M, r, ra, (-0.55, -2.4), 4.9, 2.3, 1.14, TOP, 0.14, 1119, porte=True)
    fw, xw = hangar(lot, M, r, ra, (-3.55, -2.15), 3.7, 1.5, 0.8, TOP - 0.2, 0.3, 1120)
    fe, xe = hangar(lot, M, r, ra, (2.75, -2.25), 3.9, 1.7, 0.9, TOP + 0.2, 0.36, 1121)
    # ailerons dorsaux aux 3 tailles
    for (f_, x0_, x1_, h, rl) in ((fc, xc + 0.55, 0.9, 1.15, M["alliage"]), (fw, xw + 0.4, 0.55, 0.72, M["alliage2"]), (fe, xe + 0.4, 0.6, 0.85, M["alliage"])):
        a = f_(x1_, TOP, 0.0)
        b = f_(x0_ + 0.5, TOP, 0.0)
        tp_ = G.add(f_(x0_, TOP, 0.0), (0.0, 0.0, h))
        E.aileron(lot, rl, M["capot2"], M["acier_clair"], None, a, b, tp_, rn, 0.05)
    # escalier et palier de la porte
    yy = -2.4 - 4.9 * 0.42
    lot.put(M["pierre"], G.boite((-0.55, yy - 0.15, 0.18), (1.7, 0.3, 0.1)))
    # liens du ventre vers les voûtes : colliers, conduites
    for (x, z, r_, mt) in ((-1.95, 1.1, 0.06, "alliage2"), (0.95, 1.05, 0.05, "capot2"), (-2.45, 0.85, 0.04, "acier"), (1.5, 0.8, 0.07, "alliage2")):
        C.tuyau(lot, M[mt], M["acier"], [(x, -1.75, z - 0.12), (x, -1.25, z), (x, -0.75, z + 0.2), (x, -0.35, z + 0.25)], r_, rb=0.1, pas_bride=0.36)
    for (x, w) in ((-2.05, 0.15), (1.2, 0.14)):
        E.passerelle(lot, M["nuit"], M["acier"], (x, -2.1, 0.95), (x, -0.62, 1.18), w)

    # ======================================================================================== 4. aiguilles à ailerons, fond
    for (ax, ay, zh, rb_, kbase) in ((5.0, 3.75, 4.9, 0.55, 0.7), (-1.9, 3.75, 3.5, 0.42, 0.35)):
        for k in range(3):
            a = TAU * k / 3 + kbase
            E.pied_v(lot, M["alliage2"], M["nuit"], M["orange"], (ax + 0.8 * math.cos(a), ay + 0.8 * math.sin(a)),
                     (ax + 0.25 * math.cos(a + 0.5), ay + 0.25 * math.sin(a + 0.5), 0.72), (ax + 0.25 * math.cos(a - 0.5), ay + 0.25 * math.sin(a - 0.5), 0.72), 0.05)
        lot.put(M["capot"], tour_oct([(0.7, rb_), (zh * 0.45, rb_ * 0.52)], (ax, ay), 6, 0.2))
        lot.put(M["alliage"], tour_oct([(zh * 0.45, rb_ * 0.52), (zh * 0.75, rb_ * 0.24)], (ax, ay), 6, 0.2))
        lot.put(M["alliage"], E.tube_conique((ax, ay, zh * 0.75), (ax, ay, zh), rb_ * 0.24, 0.012, 10, 6))
        lot.put(M["orange"], tour_oct([(zh * 0.72, rb_ * 0.28), (zh * 0.75, rb_ * 0.25)], (ax, ay), 6, 0.2))
        for k in range(3):
            a = TAU * k / 3 + kbase + 0.5
            ca, sa = math.cos(a), math.sin(a)
            E.aileron(lot, M["alliage"], M["capot2"], M["acier_clair"], None, (ax + rb_ * 0.85 * ca, ay + rb_ * 0.85 * sa, 0.82), (ax + rb_ * 0.45 * ca, ay + rb_ * 0.45 * sa, zh * 0.5),
                      (ax + (rb_ + 0.75) * ca, ay + (rb_ + 0.75) * sa, 0.72), rn, 0.04)
        lot.put(M["voyant"], G.sphere((ax, ay, zh + 0.02), 0.024, 6, 3))
    E.fouet(lot, M["acier_clair"], None, P.xf((2.72, 0.0, C.z_dessus(2.72) + 0.1)), 1.3, 0.026, 0.008, ((0.45, 0.14),), M["nuit"])
    E.fouet(lot, M["acier"], None, P.xf((-3.0, 0.0, C.z_dessus(-3.0) + 0.25)), 0.9, 0.018, 0.008)

    # ======================================================================================== 5. câbles, flexibles, sol
    fx = [(pieds[i][1], pieds[i + 1][1], 0.24) for i in range(3)]
    fx += [(pieds[i][0], pieds[i + 1][0], 0.24) for i in range(3)]
    fx += [(P.xf((-3.4, 0.0, C.z_dessus(-3.4) + 0.3)), P.xf((-2.2, 0.8, C.z_dessus(-2.2) + 0.2)), 0.22), (P.xf((2.0, -0.9, 0.6)), P.xf((3.4, -0.85, 0.3)), 0.18),
           ((5.0, 3.2, 2.4), P.xf((3.1, 0.7, 0.8)), 0.45), ((-1.9, 3.3, 1.8), P.xf((-1.1, 1.0, 0.6)), 0.4)]
    for (a, b, fl) in fx:
        C.faisceau(lot, M["orange"], M["noir"], a, b, fl, 3, 0.011, 0.028, r)
    for (a, b, c) in (((-4.6, -3.4, 0.5), (-5.2, -2.7, 0.3), P.xf((-3.7, -1.5, -0.6))), ((4.6, 3.1, 0.5), (3.9, 2.4, 0.2), niv((2.6, 0.9, 1.0))), ((-1.95, 3.15, 0.5), (-1.4, 2.5, 0.15), niv((-0.9, 0.9, 1.0))),
                      ((4.1, -3.4, 0.55), (5.0, -2.4, 0.2), P.xf((3.6, -0.9, -0.6))), ((1.6, -3.9, 0.3), (1.05, -3.1, 0.18), (1.0, -2.6, 0.5)), ((-2.2, -3.6, 0.3), (-2.15, -3.05, 0.18), (-1.85, -2.6, 0.5))):
        C.flexible(lot, M["caoutchouc"], [a, b, c], 0.042)
    for (x, y, sz, rz, m, mk) in ((-6.0, -3.5, 0.38, 0.1, "capot", "orange"), (-5.6, -3.75, 0.3, -0.3, "alliage2", "orange"), (5.85, -3.5, 0.4, 0.5, "alliage2", "orange"), (5.5, -3.75, 0.3, 0.2, "nuit", "orange"),
                                  (3.05, 3.65, 0.36, 0.4, "capot2", "orange"), (-5.95, 3.35, 0.34, -0.2, "capot", "orange"), (2.6, -4.1, 0.32, 0.3, "capot2", "orange")):
        E.cale(lot, M[m], x, y, sz, rz, M[mk])
    for (x, y) in ((6.05, -3.05), (6.22, -3.12), (6.12, -2.92)):
        lot.put(M["orange"], G.tour([(0.3, 0.07), (0.76, 0.07), (0.82, 0.045), (0.88, 0.025)], 12, "z", (x, y, 0.0), cap1=True))
    E.touret(lot, M["acier"], M["orange"], -6.45, -2.25, 0.19, 0.15)
    E.debris_sol(lot, M, G.Rnd(1114), 30, (-6.9, 6.9), (-4.9, 4.9), lambda x, y: abs(x) < 6.6 and abs(y) < 4.1, ("acier", "alliage2", "capot"))
    return {"pose": POSE}
