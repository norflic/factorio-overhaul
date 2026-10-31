"""QG ÂGE 10 : HAUTE TECHNOLOGIE (série du 31/10). Emprise 14×7. NEZ À DROITE (+X), tuyères à gauche.

Bible (DESIGN_EPOQUES §5, époque 10, ère IV) : « QG radar : coque lisse arrondie sur pieds courts ; grand radôme ; antenne
fouet très haute (tige) ; parabole » ; kit : dôme lisse, radôme, antenne fouet, parabole, pied télescopique, bandeau de
voyants ; voyants bleus #3AA8FF et écrans. Palette 60/30/10 validée par le DC pour les familles de l'âge 10
(commun/ages.py, _m10, ronde 3) : IVOIRE CHAUD (capots, carénages, dalles) / ANTHRACITE (plaques, acier, goulottes) /
câbles ROUGE et BLEU vifs et voyants bleus. La peau jaune d'origine ne survit qu'en pièces (environ 15 % de la coque).

Lecture de gauche à droite : tuyères carénées et dérive ; la cage des côtes balayées, surhaussée, qui serre le RADÔME
(descendant du grand dôme de l'âge 8) ; sous lui le ventre devenu capsule lisse sur pieds télescopiques (vide sous la
coque) ; le crâne à verrière et chevrons, nez relevé hors de la boue ; le fouet très haut. Derrière : tour à dôme lisse et
grande parabole. Devant : poste de commandement en capsule, sur pieds courts, porche et escalier au sud.
"""
import math

import bpy

import carcasse as C
import ere4 as E
import geo as G
import mat as MT

POSE = dict(T=(0.0, 0.95, 1.95), lacet=-0.105, tangage=0.03, roulis=0.17)
TAU = G.TAU
TOP = math.pi / 2


def matieres(S):
    M = {}
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.2, ra=0.3, ec=0.3, nu_k=1.25, ec_col=(0.1, 0.072, 0.042))
    sf = MT.surface
    cr = (0.012, 0.011, 0.009)
    rou = (0.12, 0.07, 0.035)
    iv = dict(rough=0.46, met=0.08, coulures=0.85, rouille=rou, usure=0.6, nu=(0.66, 0.58, 0.44), crasse=0.95, crasse_col=cr, pied=(0.2, 1.0, 0.45), grain=0.13)
    M["capot"] = sf("q10_capot", (0.55, 0.43, 0.215), graine=201, **iv)
    M["capot2"] = sf("q10_capot2", (0.36, 0.275, 0.125), graine=202, **iv)
    M["capot3"] = sf("q10_capot3", (0.68, 0.56, 0.32), graine=203, **iv)
    an = dict(rough=0.45, met=0.45, coulures=0.45, rouille=(0.07, 0.05, 0.035), usure=0.8, nu=(0.34, 0.33, 0.31), crasse=0.7, crasse_col=(0.006, 0.006, 0.006), grain=0.12)
    M["anthra"] = sf("q10_anthra", (0.032, 0.034, 0.038), graine=204, **an)
    M["gris"] = sf("q10_gris", (0.09, 0.094, 0.1), graine=205, **an)
    M["acier"] = sf("q10_acier", (0.07, 0.066, 0.062), rough=0.45, met=0.6, usure=0.85, nu=(0.62, 0.6, 0.56), crasse=0.7, crasse_col=cr, coulures=0.4, rouille=(0.1, 0.06, 0.03), graine=206)
    M["acier_clair"] = sf("q10_acier_clair", (0.3, 0.3, 0.3), rough=0.38, met=0.7, usure=0.4, crasse=0.6, crasse_col=cr, graine=207)
    M["cote"] = sf("q10_cote", (0.048, 0.05, 0.054), rough=0.42, met=0.55, usure=0.9, nu=(0.55, 0.53, 0.5), crasse=0.7, crasse_col=cr, coulures=0.35, graine=208)
    M["riv"] = sf("q10_riv", (0.12, 0.115, 0.1), rough=0.5, met=0.4, usure=0.3, crasse=0.5, graine=209)
    M["bague"] = sf("q10_bague", (0.05, 0.052, 0.056), rough=0.4, met=0.6, usure=0.9, nu=(0.6, 0.58, 0.54), crasse=0.6, crasse_col=cr, graine=210)
    M["epine"] = sf("q10_epine", (0.58, 0.5, 0.33), rough=0.46, met=0.1, usure=0.6, crasse=0.8, crasse_col=cr, graine=211)
    M["noyau"] = sf("q10_noyau", (0.007, 0.0075, 0.008), rough=0.6, met=0.6, usure=0.2, crasse=0.8, crasse_col=(0.003, 0.003, 0.003), graine=212)
    M["brule"] = sf("q10_brule", (0.01, 0.0095, 0.009), rough=0.75, met=0.4, usure=0.0, crasse=0.8, crasse_col=(0.003, 0.003, 0.003), graine=213)
    ja = dict(rough=0.48, met=0.2, coulures=0.9, rouille=(0.16, 0.06, 0.02), usure=0.85, nu=(0.62, 0.6, 0.56), crasse=0.95, crasse_col=cr, pied=(0.3, 1.1, 0.5), grain=0.11)
    M["jaune"] = sf("q10_jaune", (0.36, 0.205, 0.013), graine=214, **ja)
    M["jaune2"] = sf("q10_jaune2", (0.24, 0.135, 0.009), graine=215, **ja)
    M["chevron"] = sf("q10_chevron", (0.36, 0.205, 0.013), rough=0.5, met=0.2, bandes=(0.19, (0.012, 0.011, 0.01), 0.5), usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.6, graine=216)
    M["bleu"] = sf("q10_bleu", (0.012, 0.075, 0.38), rough=0.42, met=0.1, usure=0.5, nu=(0.3, 0.35, 0.45), crasse=0.5, crasse_col=cr, graine=217)
    M["rouge"] = sf("q10_rouge", (0.42, 0.02, 0.012), rough=0.5, met=0.0, usure=0.3, nu=(0.4, 0.2, 0.15), crasse=0.4, graine=218)
    M["noir"] = sf("q10_noir", (0.012, 0.012, 0.013), rough=0.7, met=0.0, usure=0.2, crasse=0.3, graine=219)
    M["caoutchouc"] = sf("q10_caoutchouc", (0.023, 0.023, 0.024), rough=0.72, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.07), crasse=0.5, crasse_col=cr, graine=220)
    M["dalle"] = sf("q10_dalle", (0.3, 0.25, 0.16), rough=0.7, met=0.05, tole=(0.5, 0.5), joint=0.25, joint_l=0.02, var=0.14, coulures=0.0, usure=0.5, nu=(0.5, 0.45, 0.38), crasse=0.85, crasse_col=cr, relief=0.6, grain=0.14, graine=221)
    M["bande"] = sf("q10_bande", (0.36, 0.205, 0.013), rough=0.5, met=0.2, bandes=(0.12, (0.012, 0.011, 0.01), 0.5), usure=0.5, crasse=0.6, crasse_col=cr, graine=222)
    M["verre_sombre"] = MT.verre("q10_verre_sombre", col=(0.008, 0.016, 0.028), reflet=(0.12, 0.18, 0.26))
    M["hublot"] = MT.lumiere(S, "q10_hublot", (0.08, 0.45, 1.0), 4.5, main=0.45)
    M["ecran"] = MT.lumiere(S, "q10_ecran", (0.14, 0.55, 1.0), 2.6, main=0.5)
    M["veilleuse"] = MT.verre("q10_veilleuse", col=(0.012, 0.03, 0.06), reflet=(0.2, 0.3, 0.42))
    M["voyant"] = MT.lumiere(S, "q10_voyant", (1.0, 0.09, 0.03), 7.0, main=0.4)
    M["voyant_b"] = MT.lumiere(S, "q10_voyant_b", (0.1, 0.5, 1.0), 7.0, main=0.4)
    M["coeur"] = MT.lumiere(S, "q10_coeur", (0.08, 0.5, 1.0), 2.4, main=0.25)
    return M


def build(S, lot):
    M = matieres(S)
    P = E.PoseK(**POSE)
    r = G.Rnd(1010)
    ra = G.Rnd(1011)
    niv = P.niv
    mc = E.tirage(M, [(0.36, "capot"), (0.16, "capot2"), (0.08, "capot3"), (0.14, "anthra"), (0.12, "jaune"), (0.06, "jaune2"), (0.08, "gris")])
    sc = C.surf_coque

    # ======================================================================================== 1. carcasse
    E.crane(lot, M, P, r, mc)
    E.queue(lot, M, P, r, mc)
    E.dos(lot, M, P, r, mc)
    E.epine(lot, M, P)
    E.lisses(lot, M, P)
    pieds = E.cotes(lot, M, P, haut=lambda x: 0.68 if x in (-0.85, 0.55) else 0.42)
    rb = G.Rnd(1018)

    def plus_nac(s, sn, R, xar):
        E.bazar(lot, M, sn, -0.35, -2.3, 0.9, 2.9, rb, 14, ("capot2", "gris", "acier", "capot3"))
    E.tuyeres(lot, M, P, r, mc, apres=plus_nac)
    E.menus(lot, M, P, G.Rnd(1012), n=240, cles=("acier", "gris", "acier_clair", "riv"))
    lot.xf = P.xf
    E.bazar(lot, M, sc, -3.35, -2.3, TOP - 1.1, TOP + 1.2, rb, 16, ("capot2", "gris", "acier", "capot3"))
    E.bazar(lot, M, sc, 2.3, 3.0, TOP - 1.2, TOP + 1.2, rb, 10, ("capot2", "gris", "acier", "capot3"))
    E.bazar(lot, M, sc, 4.35, 5.1, TOP - 1.0, TOP + 1.0, rb, 8, ("capot2", "gris", "acier", "capot3"))
    lot.xf = P.xf
    # canards courts, bord orange remplacé par le chevron d'origine
    for s in (-1, 1):
        y0 = s * 0.95
        poly = [(3.55, y0), (3.05, y0), (3.2, y0 + s * 0.72), (3.5, y0 + s * 0.78)]
        poly = poly if s > 0 else list(reversed(poly))
        v, f, u = G.prisme(poly, -0.03, 0.03)
        lot.put(M["capot"] if s > 0 else M["capot2"], ([(p[0], p[1], p[2] - 0.35 + abs(p[1] - y0) * 0.15) for p in v], f, u))
        lot.put(M["chevron"], G.tube([(3.22, y0 + s * 0.69, -0.24), (3.5, y0 + s * 0.75, -0.23)], 0.035, 6))
    # grilles de coque et marquages
    for (x, a, w, l) in ((3.0, TOP - 0.7, 0.32, 0.4), (3.9, TOP + 0.95, 0.26, 0.36), (-2.9, TOP + 0.2, 0.3, 0.5), (-2.6, TOP + 1.0, 0.24, 0.42)):
        p, n = C.point(x, a, 0.07), C.normale_s(sc, x, a)
        lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (l + 0.06, w + 0.06, 0.04)), p, n))
        lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.015), (l, w, 0.03)), p, n))
        for k in range(6):
            lot.put(M["acier"], C.pose_plane(G.boite((-l / 2 + l * (k + 0.5) / 6, 0, 0.035), (l / 6 * 0.45, w, 0.025)), p, n))
    for (x, a, w, l, m) in ((-2.75, TOP - 0.55, 0.1, 0.65, "bleu"), (2.5, TOP + 0.7, 0.08, 0.5, "bleu"), (4.2, TOP - 0.9, 0.09, 0.42, "anthra"), (-3.1, TOP + 0.75, 0.09, 0.4, "rouge")):
        p, n = C.point(x, a, 0.05), C.normale_s(sc, x, a)
        lot.put(M[m], C.pose_plane(G.boite((0, 0, 0.0), (l, w, 0.022)), p, n))

    # -- dérive --
    z0, z1 = C.z_dessus(-2.4), C.z_dessus(-3.45)
    lot.put(M["capot"], C.prisme_plan([(-2.3, z0 - 0.05), (-3.25, z0 + 1.8), (-3.95, z0 + 1.86), (-3.5, z1 - 0.05)], 0.09))
    for (poly, m, y) in (([(-2.55, z0 + 0.35), (-3.1, z0 + 1.2), (-3.55, z0 + 1.2), (-3.4, z0 + 0.35)], "anthra", 0.05),
                         ([(-3.13, z0 + 1.25), (-3.28, z0 + 1.5), (-3.75, z0 + 1.5), (-3.62, z0 + 1.25)], "jaune", 0.05),
                         ([(-2.6, z0 + 0.35), (-3.0, z0 + 0.95), (-3.3, z0 + 0.95), (-3.2, z0 + 0.35)], "capot2", -0.05)):
        lot.put(M[m], C.prisme_plan(poly, 0.025, y0=y))
    lot.put(M["chevron"], C.prisme_plan([(-3.27, z0 + 1.55), (-3.33, z0 + 1.72), (-3.93, z0 + 1.76), (-3.86, z0 + 1.55)], 0.11))
    lot.put(M["acier"], G.tube([(-2.3, 0.0, z0 - 0.05), (-3.25, 0.0, z0 + 1.8)], 0.05, 8))
    lot.put(M["voyant"], G.sphere((-3.6, 0.0, z0 + 1.92), 0.04, 8, 4))
    lot.put(M["acier"], G.tube([(-3.5, 0.0, z0 + 1.86), (-3.6, 0.0, z0 + 2.45)], 0.014, 5))

    # -- ailes : nord entière, carénée ; sud coupée, moignon lisse --
    def aile(s, pts, zr, di, m):
        poly = pts if s > 0 else list(reversed(pts))
        v, f, u = G.prisme(poly, -0.05, 0.05)
        yr = pts[0][1]
        sh = lambda q: (q[0], q[1], q[2] + zr + abs(q[1] - yr) * di)
        lot.put(m, ([sh(q) for q in v], f, u))
        return sh
    yr = 1.88
    sh = aile(1, [(-2.65, yr), (-4.55, yr), (-5.3, 3.55), (-4.5, 3.6)], -0.42, 0.24, M["capot2"])
    BA = lambda t: (-2.65 + (-4.5 + 2.65) * t - 0.07, yr + (3.6 - yr) * t)
    BF = lambda t: (-4.55 + (-5.3 + 4.55) * t + 0.1, yr + (3.55 - yr) * t)
    for (a0, a1, m, f0, f1) in ((0.04, 0.4, "capot", 0.0, 0.55), (0.04, 0.33, "anthra", 0.6, 1.0), (0.42, 0.66, "capot3", 0.0, 1.0), (0.68, 0.96, "jaune", 0.0, 0.7)):
        def pt(t, f):
            a, b = BA(t), BF(t)
            return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
        v, f, u = G.prisme([pt(a0, f0), pt(a1, f0), pt(a1, f1), pt(a0, f1)], 0.05, 0.075)
        lot.put(M[m], ([sh(q) for q in v], f, u))
    lot.put(M["chevron"], G.tube([sh((-4.52, 3.55, 0.06)), sh((-5.28, 3.5, 0.06))], 0.05, 6))
    lot.put(M["acier"], G.tube([sh((-2.65, yr, 0.06)), sh((-4.5, 3.6, 0.06))], 0.04, 6))
    lot.put(M["voyant_b"], G.sphere(sh((-4.9, 3.58, 0.1)), 0.035, 6, 3))
    aile(-1, [(-2.7, -yr), (-4.0, -yr), (-4.25, -2.55), (-3.15, -2.62)], -0.42, 0.24, M["capot2"])

    # ======================================================================================== 2. ventre : corps couché à la peau du vaisseau, radôme
    lot.xf = None
    mc2 = E.tirage(M, [(0.5, "capot"), (0.18, "capot2"), (0.14, "capot3"), (0.12, "anthra"), (0.06, "gris")], None)
    ce = niv((0.25, -0.08, 0.0))
    fv = E.surf_fuseau(ce, 5.7, 3.05, 1.06, 1.76, POSE["lacet"])
    C.noyau(lot, M["noyau"], fv, -2.84, 2.84, 0.0, TAU)
    C.blindage(lot, fv, -2.82, 2.82, -0.55, math.pi + 0.55, mc2, r, Mriv=M["riv"], **E.LISSE2)
    C.blindage(lot, fv, -2.82, 2.82, math.pi + 0.55, TAU - 0.55, lambda rr, xm, am: M["anthra"], r, Mriv=None, **E.LISSE)
    CL0 = ("anthra", "verre_sombre", "ecran", "acier", "noir", "gris", "voyant_b")
    E.rangee(lot, M, fv, -2.3, 2.3, math.pi - 0.25, ra, ["verre", "grille", "ecran", "boite", "verre", "porte", "grille"], CL0, sauts=((1.25, 2.15),))
    E.rangee(lot, M, fv, -2.2, 2.2, math.pi + 0.28, ra, ["grille", "boite", "boite", "grille"], CL0)
    E.bazar(lot, M, fv, -2.4, 2.4, math.pi - 1.05, math.pi - 0.5, G.Rnd(1017), 22, ("capot2", "gris", "acier", "capot3"))
    # cœur-réacteur : port rond à grille, foyer fort du vaisseau
    p, n = fv(1.7, math.pi - 0.25, 0.05), C.normale_s(fv, 1.7, math.pi - 0.25)
    lot.put(M["anthra"], G.oriente(G.tour([(0.0, 0.42), (0.05, 0.4), (0.07, 0.32), (0.02, 0.29)], 24, "z"), p, n))
    lot.put(M["coeur"], G.oriente(G.tour([(0.02, 0.29), (0.022, 0.0)], 24, "z"), p, n))
    for d in (-0.15, -0.05, 0.05, 0.15):
        lot.put(M["acier"], E.pose(G.boite((d, 0.0, 0.05), (0.028, 0.6, 0.025)), p, n))
    # radôme dans la cage
    rc = P.xf((-0.15, 0.0, 0.62 / E.K))
    E.radome(lot, [M["capot"], M["capot"], M["capot3"], M["capot2"], M["capot2"]], M["noir"], rc, 1.52, G.Rnd(1013), zmin=-0.35, gap=0.93)
    E.anneau(lot, M["anthra"], (rc[0], rc[1], rc[2] - 0.32), 1.5, 0.07, 0.05)
    tr = G.add(rc, (0.0, 0.0, 1.52))
    E.fouet(lot, M["acier"], M["voyant"], tr, 0.55, 0.022, 0.009)

    # ======================================================================================== 3. pieds et jambages
    for (pn, ps) in pieds:
        for q in (pn, ps):
            E.pied_tele(lot, M["anthra"], M["acier_clair"], M["bande"], M["gris"], (q[0], q[1], q[2]), 0.14)
    for (u, v, zt) in ((-3.6, 1.3, 1.5), (-3.9, -1.25, 1.35), (3.0, 1.05, 1.5), (3.05, -1.15, 1.25), (-5.1, 2.0, 1.55), (-5.25, -2.05, 1.5)):
        q = niv((u, v, zt))
        E.pied_tele(lot, M["anthra"], M["acier_clair"], M["bande"], M["gris"], q, 0.16)
    # chapelle de vérins : flexibles sous la coque
    for (a, b, c) in ((niv((-1.6, -1.2, 1.0)), niv((-1.9, -1.55, 0.25)), niv((-1.0, -1.7, 0.08))),
                      (niv((1.3, -1.2, 1.0)), niv((1.55, -1.6, 0.3)), niv((0.8, -1.8, 0.08))),
                      (niv((-2.9, -0.9, 1.25)), niv((-3.3, -1.5, 0.4)), niv((-3.0, -2.0, 0.08))),
                      (niv((2.75, -1.0, 1.2)), niv((3.2, -1.5, 0.4)), niv((2.75, -2.0, 0.08)))):
        C.flexible(lot, M["caoutchouc"], [a, b, c], 0.05)

    # ======================================================================================== 4. poste de commandement au sud
    cx, cy = -1.35, -3.42
    A = E.Stade((cx, cy), 5.5, 2.0)
    fa = E.surf_fuseau((cx, cy), 5.5, 2.0, 0.62, 1.04)
    C.noyau(lot, M["noyau"], fa, -2.74, 2.74, 0.0, TAU)
    C.blindage(lot, fa, -2.72, 2.72, -0.65, math.pi + 0.65, mc2, r, Mriv=M["riv"], **E.LISSE2)
    C.blindage(lot, fa, -2.72, 2.72, math.pi + 0.65, TAU - 0.65, lambda rr, xm, am: M["anthra"], r, Mriv=None, **E.LISSE)
    CL = ("anthra", "verre_sombre", "ecran", "acier", "noir", "gris", "voyant_b")
    E.rangee(lot, M, fa, -2.3, 2.2, math.pi - 0.3, ra, ["verre", "grille", "ecran", "boite", "verre", "porte", "grille", "verre"], CL, sauts=((0.0, 1.6),))
    E.rangee(lot, M, fa, -2.0, 2.1, math.pi - 0.9, ra, ["grille", "boite", "grille", "boite", "boite"], CL)
    E.bazar(lot, M, fa, -2.3, 2.3, TOP - 0.55, math.pi - 1.05, G.Rnd(1015), 40, ("capot2", "gris", "acier", "capot3"))
    for x in [-2.15, -0.95, 0.35, 1.75]:
        for yy in (-0.66, 0.66):
            E.pied_tele(lot, M["anthra"], M["acier_clair"], M["bande"], M["gris"], A.loc(x, yy, 0.46), 0.1)
    # conduites le long du flanc sud, sur colliers
    C.tuyau(lot, M["bleu"], M["acier"], [fa(-2.2, math.pi - 0.62, 0.05), fa(0.0, math.pi - 0.62, 0.05)], 0.028, rb=0.05, pas_bride=0.5)
    C.tuyau(lot, M["acier"], M["anthra"], [fa(1.55, math.pi - 0.62, 0.05), fa(2.3, math.pi - 0.62, 0.05)], 0.034, rb=0.05, pas_bride=0.3)
    C.faisceau(lot, M["rouge"], M["noir"], fa(-2.3, math.pi - 0.05, 0.03), fa(-0.1, math.pi - 0.05, 0.03), 0.04, 3, 0.01, 0.022, ra)
    # annexe basse, plus sombre, décalée : le poste n'est pas un seul boudin
    bx, by = 2.75, -3.05
    Bx = E.Stade((bx, by), 3.2, 1.55)
    fb = E.surf_fuseau((bx, by), 3.2, 1.55, 0.46, 0.84)
    C.noyau(lot, M["noyau"], fb, -1.59, 1.59, 0.0, TAU)
    C.blindage(lot, fb, -1.57, 1.57, -0.6, math.pi + 0.6, E.tirage(M, [(0.42, "anthra"), (0.2, "gris"), (0.24, "capot2"), (0.14, "capot")], None), r, Mriv=M["riv"], **E.LISSE2)
    E.rangee(lot, M, fb, -1.2, 1.25, math.pi - 0.32, ra, ["grille", "ecran", "boite", "verre", "grille", "boite"], CL)
    E.bazar(lot, M, fb, -1.3, 1.3, TOP - 0.5, math.pi - 0.95, G.Rnd(1016), 26, ("capot2", "noir", "acier", "capot"))
    for x in (-1.0, 0.1, 1.15):
        for yy in (-0.5, 0.5):
            E.pied_tele(lot, M["anthra"], M["acier_clair"], M["bande"], M["gris"], Bx.loc(x, yy, 0.42), 0.085)
    lot.put(M["anthra"], G.tour([(1.05, 0.34), (1.12, 0.38), (1.5, 0.38), (1.57, 0.34)], 16, "x", (0.0, -3.2, 0.98)))         # sas entre les deux corps
    # bandeau de voyants (inégaux, deux couleurs), sur le mur sud
    for k in range(24):
        if k % 7 == 3:
            continue
        q = fa(-2.35 + k * 0.19, math.pi - 0.62, 0.02)
        lot.put(M["voyant_b"] if ra.f() < 0.7 else M["hublot"], G.boite(G.add(q, (0.0, -0.06, 0.1)), (ra.f(0.03, 0.09), 0.012, 0.022)))
    # porche et escalier (invariant : porte centrale au sud)
    dx = -0.55
    B = E.Stade((dx, cy - 1.02), 1.7, 0.95)
    B.corps(lot, M["anthra"], [(0.44, 0.02), (1.06, 0.0)], cap=False)
    B.corps(lot, M["capot3"], [(1.06, -0.09), (1.13, -0.09), (1.22, 0.06), (1.28, 0.3)])
    B.ceinture(lot, M["acier"], 1.08, 0.02, -0.09, 0.012)
    p, n = B.mur(B.s_sud(0.0), 0.72, 0.0)
    lot.put(M["acier"], E.pose(G.boite((0, 0, 0.01), (0.66, 0.56, 0.03)), p, n))
    lot.put(M["noir"], E.pose(G.boite((0, 0, 0.022), (0.56, 0.5, 0.02)), p, n))
    lot.put(M["acier"], E.pose(G.boite((0, 0, 0.035), (0.024, 0.5, 0.02)), p, n))
    lot.put(M["ecran"], E.pose(G.boite((0.0, 0.33, 0.02), (0.4, 0.04, 0.015)), p, n))
    yp = cy - 1.5
    lot.put(M["dalle"], G.boite((dx, yp + 0.02, 0.42), (1.3, 0.34, 0.05)))
    for k in range(4):
        lot.put(M["gris"], G.boite((dx, yp - 0.22 - 0.2 * k, 0.33 - 0.1 * k), (1.0, 0.2, 0.05)))
    for sg in (-1, 1):
        lot.put(M["acier"], G.tube([(dx + sg * 0.55, yp - 0.1, 0.8), (dx + sg * 0.55, yp - 0.95, 0.42)], 0.016, 5))
        for t in (0.1, 0.5, 0.9):
            q = (dx + sg * 0.55, yp - 0.1 - 0.85 * t, 0.42 - 0.38 * t)
            lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, 0.38))], 0.012, 4))
    # -- toit du poste : dôme lisse, petite parabole, fouets, chemin de câbles --
    zt = 1.62
    d1 = (0.2, cy + 0.02, 0.0)
    lot.put(M["anthra"], G.tour([(zt - 0.15, 0.74), (zt + 0.05, 0.72), (zt + 0.08, 0.64)], 40, "z", d1))
    lot.put(M["capot3"], G.tour([(zt + 0.06, 0.62)] + [(zt + 0.08 + 0.62 * math.sin(t), 0.62 * math.cos(t)) for t in [0.1 + 1.47 * i / 10.0 for i in range(11)]] + [(zt + 0.7, 0.0)], 40, "z", d1))
    E.anneau(lot, M["bleu"], (d1[0], d1[1], zt + 0.14), 0.625, 0.012, 0.02, 48)
    E.joints_dome(lot, M["anthra"], d1, 0.62, zt + 0.08)
    q0 = (-3.2, cy + 0.02, 0.0)
    lot.put(M["anthra"], G.tour([(zt - 0.3, 0.22), (zt + 0.08, 0.18)], 12, "z", q0, cap1=True))
    E.parabole(lot, [M["capot3"], M["capot"]], M["gris"], M["acier"], M["anthra"], (q0[0], q0[1], zt + 0.2), (-0.3, -0.55, 0.78), 0.56, 0.42, nerv=10)
    for (x, h, r0) in ((-2.2, 1.25, 0.024), (-2.02, 0.8, 0.02), (-0.75, 1.55, 0.026)):
        E.fouet(lot, M["acier"], M["voyant_b"] if h > 1.4 else None, (x, cy + 0.05, zt - 0.03), h, r0, 0.008)
    lot.put(M["gris"], G.boite((-1.45, cy + 0.22, zt + 0.05), (2.0, 0.14, 0.03)))
    for x in [-2.35, -1.85, -1.35, -0.85, -0.5]:
        lot.put(M["gris"], G.boite((x, cy + 0.22, zt), (0.03, 0.16, 0.1)))
    C.faisceau(lot, M["rouge"], M["bleu"], (-2.4, cy + 0.22, zt + 0.08), (-0.45, cy + 0.22, zt + 0.08), 0.02, 3, 0.011, 0.026, ra)
    # -- pont de tuyaux du poste vers le ventre (pas de passerelle large : vide franc sous la coque) --
    ya = cy + 0.85
    C.tuyau(lot, M["capot2"], M["acier"], [(-0.55, ya, 1.3), (-0.55, -1.72, 1.3), niv((-0.55, -1.48, 1.3)), niv((-0.55, -1.3, 1.45))], 0.09, rb=0.14, pas_bride=0.45)
    C.tuyau(lot, M["anthra"], M["acier"], [(0.25, ya, 0.95), (0.25, -2.0, 0.95), niv((0.25, -1.45, 1.1)), niv((0.25, -1.3, 1.2))], 0.055, rb=0.1, pas_bride=0.4)
    C.tuyau(lot, M["acier"], M["anthra"], [(2.05, -2.42, 0.82), (2.05, -2.05, 0.82), niv((2.2, -1.25, 1.05))], 0.035, rb=0.08, pas_bride=0.35)
    C.tuyau(lot, M["bleu"], M["acier"], [(-2.65, ya, 0.9), (-2.65, -2.05, 0.9), niv((-2.4, -1.28, 1.15))], 0.035, rb=0.08, pas_bride=0.35)
    C.tuyau(lot, M["capot"], M["acier"], [(-1.6, ya, 1.15), (-1.6, -1.95, 1.15), niv((-1.6, -1.3, 1.4))], 0.065, rb=0.12, pas_bride=0.4)
    for (x, z) in ((-0.55, 1.22), (0.25, 0.87), (-2.65, 0.82), (-1.6, 1.07)):
        E.pied_tele(lot, M["anthra"], M["acier_clair"], M["bande"], M["gris"], (x, -2.2, z), 0.05)

    # ======================================================================================== 5. fond : tour à dôme, parabole
    # grande parabole au nord-est
    gx, gy = 5.15, 3.65
    lot.put(M["dalle"], G.tour([(0.0, 1.15), (0.06, 1.12), (0.08, 1.05)], 8, "z", (gx, gy, 0.0), cap1=True))
    lot.put(M["anthra"], G.tour([(0.06, 0.7), (0.34, 0.66), (0.4, 0.46)], 12, "z", (gx, gy, 0.0), cap1=True))
    lot.put(M["capot"], G.tour([(0.36, 0.42), (1.6, 0.27), (1.64, 0.34), (1.76, 0.34), (1.82, 0.2)], 24, "z", (gx, gy, 0.0), cap1=True))
    for z in (0.62, 1.05):
        lot.put(M["anthra"], G.tour([(z - 0.018, 0.42 - (z - 0.36) * 0.12 + 0.012), (z + 0.018, 0.42 - (z - 0.36) * 0.12 + 0.012)], 24, "z", (gx, gy, 0.0)))
    n_p = (-0.3, -0.62, 0.72)
    cp = (gx, gy, 2.32)
    for sg in (-1, 1):                                       # fourche
        lot.put(M["gris"], E.plan3([(gx + sg * 0.34, gy - 0.12, 1.74), (gx + sg * 0.34, gy + 0.12, 1.74), (gx + sg * 0.62, gy + 0.04, 2.38), (gx + sg * 0.62, gy - 0.2, 2.38)], 0.05))
    lot.put(M["acier"], G.tour([(-0.62, 0.12), (0.62, 0.12)], 12, "x", (gx, gy - 0.08, 2.32), cap0=True, cap1=True))
    E.parabole(lot, [M["capot3"], M["capot"], M["capot"], M["capot2"]], M["gris"], M["acier"], M["anthra"], cp, n_p, 1.42, 1.05, nerv=18)
    for k in range(9):                                        # échelle du fût
        z = 0.5 + 0.13 * k
        lot.put(M["acier"], G.tube([(gx - 0.1, gy - 0.46 + 0.012 * k, z), (gx + 0.1, gy - 0.46 + 0.012 * k, z)], 0.008, 3))
    for sg in (-1, 1):
        lot.put(M["acier"], G.tube([(gx + sg * 0.1, gy - 0.48, 0.4), (gx + sg * 0.1, gy - 0.36, 1.62)], 0.01, 4))
    lot.put(M["voyant_b"], G.sphere(G.add(cp, G.mul(G.norm(n_p), 1.15)), 0.02, 6, 3))
    # tour à dôme lisse
    tx, ty = 1.75, 4.05
    lot.put(M["dalle"], G.boite((tx, ty, 0.04), (1.8, 1.5, 0.08), 0.15))
    lot.put(M["anthra"], G.tour([(0.08, 0.86), (0.4, 0.82), (0.46, 0.66)], 16, "z", (tx, ty, 0.0)))
    lot.put(M["capot"], G.tour([(0.44, 0.64), (2.4, 0.56), (2.46, 0.66), (2.56, 0.66)], 32, "z", (tx, ty, 0.0)))
    for z in (0.9, 1.45, 2.0):
        lot.put(M["anthra"], G.tour([(z - 0.02, 0.64 - (z - 0.44) * 0.04 + 0.012), (z + 0.02, 0.64 - (z - 0.44) * 0.04 + 0.012)], 32, "z", (tx, ty, 0.0)))
    Rd = 0.68
    lot.put(M["capot3"], G.tour([(2.56, Rd)] + [(2.58 + Rd * math.sin(t), Rd * math.cos(t)) for t in [0.08 + 1.48 * i / 12.0 for i in range(13)]] + [(2.58 + Rd, 0.0)], 40, "z", (tx, ty, 0.0)))
    E.anneau(lot, M["bleu"], (tx, ty, 2.68), Rd + 0.002, 0.012, 0.022, 48)
    E.joints_dome(lot, M["anthra"], (tx, ty), Rd, 2.58)
    E.fouet(lot, M["acier"], M["voyant"], (tx, ty, 2.58 + Rd), 0.75, 0.024, 0.007)

    # le fouet très haut, signature de l'âge
    lot.xf = None
    m0 = P.xf((2.72, 0.0, C.z_dessus(2.72) + 0.1))
    fo = E.fouet(lot, M["acier_clair"], M["voyant"], m0, 5.0, 0.055, 0.018, ((0.2, 0.24), (0.36, 0.17), (0.52, 0.11), (0.7, 0.06)), M["anthra"])
    for k in range(3):
        a = TAU * k / 3 + 0.5
        lot.put(M["acier"], G.tube([G.add(m0, (0.0, 0.0, 2.1)), G.add(m0, (0.95 * math.cos(a), 0.8 * math.sin(a), -0.15))], 0.006, 3))
    for x in (-3.0, -2.1):                                    # fouets de la queue
        p = P.xf((x, 0.0, C.z_dessus(x) + 0.25))
        E.fouet(lot, M["acier"], None, p, 0.95 if x < -2.5 else 1.3, 0.02, 0.006)

    # ======================================================================================== 6. modules au sol
    # pod sud-ouest : petit dôme lisse sur jupe, bleu en ceinture
    px, py = -5.45, -3.4
    lot.put(M["dalle"], G.boite((px, py, 0.04), (1.95, 1.8, 0.08), 0.08))
    for k in range(3):
        a = TAU * k / 3 - 0.5
        E.pied_tele(lot, M["anthra"], M["acier_clair"], M["bande"], M["gris"], (px + 0.42 * math.cos(a), py + 0.42 * math.sin(a), 0.4), 0.08)
    lot.put(M["capot2"], G.tour([(0.36, 0.5), (0.48, 0.72), (0.76, 0.76), (0.82, 0.72)], 32, "z", (px, py, 0.0), cap0=True))
    R2 = 0.7
    lot.put(M["capot3"], G.tour([(0.8, R2)] + [(0.82 + R2 * math.sin(t), R2 * math.cos(t)) for t in [0.06 + 1.5 * i / 10.0 for i in range(11)]] + [(0.82 + R2, 0.0)], 36, "z", (px, py, 0.0)))
    E.anneau(lot, M["anthra"], (px, py, 0.82), R2 + 0.02, 0.02, 0.03, 40)
    E.joints_dome(lot, M["anthra"], (px, py), R2, 0.82)
    E.arc_lum(lot, M["hublot"], (px, py, 0.62), 0.765, 0.018, -2.4, -0.6, 16)
    # groupe froid sud-est : capsule à ventilateurs
    Q = E.Stade((5.6, -3.45), 1.9, 1.15, -0.1)
    lot.put(M["dalle"], G.boite((5.55, -3.45, 0.04), (2.35, 1.65, 0.08), -0.1))
    for (x, y) in ((-0.55, -0.32), (0.55, -0.32), (-0.55, 0.32), (0.55, 0.32)):
        E.pied_tele(lot, M["anthra"], M["acier_clair"], M["bande"], M["gris"], Q.loc(x, y, 0.3), 0.07)
    Q.corps(lot, M["capot2"], [(0.26, 0.1), (0.36, 0.0), (0.72, 0.0), (0.8, 0.05), (0.84, 0.14)])
    Q.ceinture(lot, M["anthra"], 0.66, 0.03)
    for x in (-0.42, 0.4):
        q = Q.loc(x, 0.0, 0.0)
        lot.put(M["anthra"], G.tour([(0.82, 0.33), (0.89, 0.33), (0.9, 0.3)], 28, "z", q))
        lot.put(M["noir"], G.tour([(0.85, 0.3), (0.86, 0.0)], 24, "z", q))
        for k in range(7):
            a = TAU * k / 7 + x
            lot.put(M["gris"], G.boite((q[0] + 0.16 * math.cos(a), q[1] + 0.16 * math.sin(a), 0.875), (0.3, 0.05, 0.012), a))
        lot.put(M["acier"], G.tour([(0.86, 0.06), (0.91, 0.05), (0.92, 0.0)], 10, "z", q))
    for x in (-0.65, -0.2, 0.3):
        p, n = Q.mur(Q.s_sud(x), 0.5, 0.0)
        E.grille(lot, M["acier"], M["noir"], p, n, 0.32, 0.2, 4)
    C.tuyau(lot, M["capot2"], M["acier"], [Q.loc(-0.95, 0.0, 0.55), (4.5, -2.3, 0.55), (3.6, -1.9, 0.75), niv((3.15, -1.0, 1.1))], 0.07, rb=0.16, pas_bride=0.5)

    # ======================================================================================== 7. réseaux, câbles, sol
    fx = [(pieds[i][1], pieds[i + 1][1], 0.3) for i in range(3)]
    fx += [(P.xf((-3.4, 0.0, C.z_dessus(-3.4) + 0.3)), P.xf((-2.2, 0.8, C.z_dessus(-2.2) + 0.2)), 0.25),
           (P.xf((2.0, -0.9, 0.6)), P.xf((3.4, -0.85, 0.3)), 0.2), (P.xf((-3.2, -1.0, 0.1)), P.xf((-2.1, -1.1, 0.0)), 0.2),
           (A.loc(-2.72, -0.2, 1.3), (-5.1, -3.0, 1.2), 0.32), ((4.2, -3.05, 1.0), Q.loc(-0.8, 0.2, 0.75), 0.2),
           ((tx - 0.6, ty - 0.1, 2.1), P.xf((1.9, 0.9, C.z_dessus(1.9) + 0.1)), 0.42), ((gx - 0.3, gy - 0.25, 1.5), (tx + 0.6, ty - 0.1, 1.9), 0.4),
           (P.xf((-1.6, 1.2, 0.6)), (tx - 0.6, ty - 0.2, 1.2), 0.32), (P.xf((3.3, 0.9, 0.4)), (gx - 0.5, gy - 0.3, 1.2), 0.35)]
    for (a, b, fl) in fx:
        C.faisceau(lot, M["rouge"], M["bleu"], a, b, fl, 3, 0.012, 0.03, r)
    # flexibles
    for (a, b, c) in (((-5.9, -2.75, 0.5), (-5.1, -2.2, 0.12), niv((-4.6, -1.6, 1.0))), ((px + 0.7, py + 0.1, 0.7), (-3.9, -3.4, 0.12), A.loc(-2.72, 0.0, 0.8)),
                      ((gx - 0.6, gy - 0.45, 0.25), (3.7, 2.7, 0.08), P.xf((3.2, 1.1, 0.0))), ((tx + 0.4, ty - 0.6, 0.3), (2.0, 2.9, 0.1), niv((1.3, 1.5, 0.9))),
                      (Q.loc(-0.3, 0.6, 0.45), (4.3, -1.9, 0.1), niv((3.5, -0.8, 1.2))), ((2.6, -2.45, 0.7), (3.25, -2.0, 0.1), (4.35, -2.35, 0.5))):
        C.flexible(lot, M["caoutchouc"], [a, b, c], 0.045)
    # goulottes au sol, dalles de service
    for (x, y, w, h, rz) in ((-2.95, -1.75, 2.4, 0.55, 0.02), (1.7, -1.8, 2.1, 0.5, -0.04), (3.75, 2.05, 1.5, 0.7, -0.2), (-4.0, 0.05, 1.4, 0.7, 0.06)):
        lot.put(M["dalle"], G.boite((x, y, 0.035), (w, h, 0.07), rz))
        q = G.rot_z((0.0, -h / 2 - 0.03, 0.0), rz)
        lot.put(M["bande"], G.boite((x + q[0], y + q[1], 0.04), (w, 0.06, 0.05), rz))
    for (a, b) in (((-4.3, -2.25, 0.09), (-1.0, -2.25, 0.09)), ((0.7, -2.2, 0.09), (3.6, -2.25, 0.09))):
        lot.put(M["anthra"], G.boite(G.lerp(a, b, 0.5), (G.length(G.sub(b, a)), 0.12, 0.09)))
    # conteneurs, bouteilles, tourets, débris (peu : le site est tenu)
    for (x, y, sz, rz, m, mk) in ((2.85, -4.45, 0.42, 0.25, "capot2", "bleu"), (3.4, -4.6, 0.34, -0.2, "anthra", "bande"), (3.3, -4.15, 0.3, 0.5, "capot", "rouge"),
                                  (-3.55, -4.55, 0.36, 0.1, "anthra", "bleu"), (-6.1, -1.85, 0.38, -0.3, "capot2", "rouge"), (6.45, -4.55, 0.34, 0.4, "capot2", "bande"),
                                  (0.15, 4.6, 0.4, 0.3, "capot2", "bleu")):
        E.cale(lot, M[m], x, y, sz, rz, M[mk])
    for (x, y) in ((-3.0, -4.75), (-2.82, -4.84), (-2.92, -4.6)):
        lot.put(M["bleu"], G.tour([(0.0, 0.075), (0.48, 0.075), (0.54, 0.05), (0.6, 0.028)], 12, "z", (x, y, 0.0), cap1=True))
    E.touret(lot, M["gris"], M["rouge"], 1.75, -4.72, 0.2, 0.16)
    E.touret(lot, M["gris"], M["bleu"], 5.9, -1.65, 0.17, 0.14)
    E.debris_sol(lot, M, G.Rnd(1014), 34, (-6.9, 6.9), (-4.9, 4.9), lambda x, y: abs(x) < 4.2 and abs(y) < 2.7, ("acier", "capot2", "anthra"))
    return {"pose": POSE}
