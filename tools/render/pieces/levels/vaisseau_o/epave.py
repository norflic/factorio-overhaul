"""ÉPAVE (âge 0) : le vaisseau écrasé (emprise 8×4, k = 1). Nez à droite, planté dans une butte de terre.

Même carcasse que l'âge 1 (on doit reconnaître le vaisseau qu'on va réparer), mais : couché sur le flanc sud
(roulis), nez enfoncé, ventre éventré sur le dessus et le flanc sud (couples à nu, pont intérieur, caissons, câbles
qui pendent, voyant rouge de secours), un quart des plaques arrachées, aile nord cassée, cloche de la tuyère nord
tombée au sol, tuyère sud qui couve encore ; débris de blindage, terre retournée.
"""
import math

import age01
import geo as G
import mat as MT
import vaisseau as V

# impacts : (x, angle, rayon) ; plaques arrachées autour, coque presque entière ailleurs
IMPACTS = ((0.0, 2.4, 0.95), (2.75, 3.3, 0.6), (-2.0, 1.4, 0.6))


def build(S, lot):
    M = age01.matieres(S)
    V.reglage(nac_x0=-0.35)
    M["terre"] = MT.surface("o0_terre", (0.085, 0.05, 0.028), rough=1.0, met=0.0, grain=0.18, usure=0.0, crasse=0.6,
                            crasse_col=(0.03, 0.02, 0.012), graine=21)
    M["roc"] = MT.surface("o0_roc", (0.07, 0.06, 0.05), rough=0.9, met=0.0, grain=0.2, usure=0.6, nu=(0.16, 0.14, 0.12),
                          crasse=0.6, graine=22)
    M["suie"] = MT.surface("o0_suie", (0.05, 0.035, 0.022), rough=0.8, met=0.3, coulures=0.8, usure=0.6,
                           nu=(0.3, 0.22, 0.12), crasse=0.6, graine=23)
    M["braise"] = MT.lumiere(S, "o0_braise", (1.0, 0.28, 0.05), 6.0, main=0.25)
    k = 1.0
    r = G.Rnd(7)
    arr = G.Rnd(70)
    jaunes = [M["jaune0"], M["jaune1"], M["jaune2"]]
    ba0, ba1 = math.pi / 2 + 0.1, math.pi + 0.5          # arc ouvert du ventre (dessus et flanc sud)
    bx0, bx1 = -0.72, 0.78

    def saut(xm, am):
        if bx0 - 0.15 < xm < bx1 + 0.15 and ba0 - 0.1 < am < ba1 + 0.1:
            return True
        if 1.15 < xm < 2.5 and abs(am - math.pi / 2) < 0.95:
            return True
        d = min(math.hypot(xm - cx, (am - ca) * 0.6) / rr_ for (cx, ca, rr_) in IMPACTS)
        return arr.f() < max(0.03, 0.95 - 1.1 * d)

    def mats(rr, i, j, zone):
        x = rr.f()
        if zone == "coque" and i == 11:
            return M["chevron"]
        if x < 0.06:
            return M["suie"]
        return jaunes[int(rr.f() * 3) % 3]

    def tilt(p):
        p = G.rot_x(p, 0.34, (0.0, 0.0, 0.6))
        p = G.rot_y(p, 0.13, (0.0, 0.0, 0.6))
        p = G.rot_z(p, -0.13)
        return (p[0], p[1], max(0.004, p[2] - 0.36))
    lot.xf = tilt
    V.corps(lot, k, r, M["noyau"], M["bague"], M["brule"], M["riv"], mats, saut=saut,
            saut_nac=lambda s, xm, am: s > 0 and arr.f() < 0.35, feu=M["braise"], breche=(bx0, bx1, ba0, ba1), cloches=(-1,))
    # couples à nu et lisses rompues dans la brèche
    for x in (-0.6, -0.2, 0.2, 0.62):
        V.cote(lot, M["acier"], x, k, ep=0.075, prof=0.13, saillie=0.0, a0=ba0 - 0.15, a1=ba1 + 0.12)
    sc = V.surf_coque(k)
    for a, (x0, x1) in ((ba0 + 0.45, (bx0, 0.1)), (ba0 + 1.1, (-0.35, bx1)), (ba1 - 0.25, (bx0, -0.3))):
        da = 0.05 / V._arc(sc, 0.0, a)
        lot.put(M["acier"], V.plaque(sc, x0, x1, a - da, a + da, -0.09, -0.01))
    # pont intérieur : plancher, caissons, réservoir, câbles qui pendent, voyant de secours
    zc = V.profil(0.0)[0]
    lot.put(M["noyau"], G.boite((0.03, -0.05, zc - 0.22), (1.5, 1.2, 0.05)))
    V.caisson(lot, M["acier"], M["noir"], (-0.4, -0.25, zc - 0.2), (0.34, 0.3, 0.36), lum=M["voyant"])
    V.caisson(lot, M["rapiece"], M["acier"], (0.38, 0.12, zc - 0.2), (0.3, 0.42, 0.28))
    lot.put(M["bague"], G.tour([(0.0, 0.17), (0.5, 0.17)], 16, "x", (-0.05, 0.25, zc - 0.02), cap0=True, cap1=True))
    lot.put(M["voyant"], G.sphere((0.05, -0.35, zc + 0.05), 0.05, 10, 5))
    for (a, b, f, m) in (((-0.6, -0.55, 1.75), (-0.2, -0.75, 1.45), 0.25, "rouge"), ((-0.2, -0.3, 1.8), (0.2, -0.8, 1.3), 0.3, "noir"),
                         ((0.2, -0.5, 1.78), (0.62, -0.7, 1.55), 0.18, "rouge"), ((0.2, 0.1, 1.9), (-0.6, -0.1, 1.85), 0.35, "noir")):
        V.cable(lot, M[m], a, b, f, 0.016)
    V.flexible(lot, M["cuivre"], [(0.62, -0.75, 1.4), (0.75, -1.0, 1.0), (0.95, -1.2, 0.6), (1.2, -1.25, 0.3)], 0.035)
    # verrière fendue (cadre seul sur la moitié avant)
    V.verriere(lot, M["verre"], M["acier"], k)
    for s in (-1, 1):
        V.canard(lot, M["jaune1"], M["chevron"], s, k)
    V.aile(lot, M["jaune0"], M["noyau"], M["chevron"], M["riv"], -1, k, rnd=r, saut=lambda u, v: v > 0.35 and u < 0.42, cassee=0.78)
    V.aile(lot, M["jaune2"], M["noyau"], M["chevron"], M["riv"], 1, k, rnd=r, cassee=0.42)
    tip = V.derive(lot, M["jaune0"], M["chevron"], k, h=0.5)
    lot.put(M["voyant"], G.sphere(G.add(tip, (0, 0, 0.03)), 0.035, 8, 4))
    # plaques arrachées, retroussées au bord de la brèche
    for (x, a, rot) in ((-0.55, ba1 + 0.15, 0.7), (0.05, ba1 + 0.12, 0.9), (0.55, ba1 + 0.18, 0.6), (-0.25, ba0 - 0.12, -0.8),
                        (0.4, ba0 - 0.1, -0.6)):
        p = V.point(x, a, k, 0.03)
        n = V.normale(x, a, k)
        pl = V.pose_plane(G.boite((0.0, 0.17, 0.0), (0.36, 0.34, 0.035), rx=rot), p, n)
        lot.put(M["jaune%d" % (int(x * 10) % 3)], pl)
    # ------------------------------------------------------------ au sol (sans renversement)
    lot.xf = None
    for (c, rx, ry, h, m) in (((3.05, -0.2, 0.0), 1.05, 1.35, 0.55, "terre"), ((0.4, -1.3, 0.0), 2.6, 0.42, 0.24, "terre"),
                              ((0.4, 1.35, 0.0), 2.4, 0.38, 0.2, "terre"), ((2.2, -1.1, 0.0), 0.7, 0.45, 0.3, "terre")):
        lot.put(M[m], G.butte(c, rx, ry, h, r, n=30))
    for i in range(14):
        x, y = r.f(1.6, 3.9), r.f(-1.9, 1.7)
        rr = r.f(0.05, 0.12)
        lot.put(M["roc"], G.sphere((x, y, rr * 0.3), rr, 8, 4))
    # cloche de la tuyère nord, tombée
    out, inn = V.cloche_seule(lot, M["bague"], M["brule"], k)

    def pose_cloche(p):
        p = G.rot_y(p, -0.35)
        p = G.rot_z(p, 2.5)
        return (p[0] - 3.35, p[1] + 1.55, p[2] + 0.42)
    lot.put(M["bague"], out, pose_cloche)
    lot.put(M["brule"], inn, pose_cloche)
    # bout de l'aile nord, arraché
    frag = G.prisme([(0.0, 0.0), (0.95, -0.15), (0.85, 0.5), (0.1, 0.55)], 0.0, 0.07)
    lot.put(M["jaune2"], frag, lambda p: G.add(G.rot_z(G.rot_x(p, 0.25), 0.4), (-2.3, 2.05, 0.05)))
    lot.put(M["chevron"], G.tube([(0.0, 0.0, 0.035), (0.95, -0.15, 0.035)], 0.045, 8),
            lambda p: G.add(G.rot_z(G.rot_x(p, 0.25), 0.4), (-2.3, 2.05, 0.05)))
    # éclats de blindage et de noyau
    for i in range(13):
        x, y = r.f(-3.6, 3.4), r.f(-2.6, 2.6)
        if abs(y) < 1.1 and -2.8 < x < 3.0:
            y = math.copysign(r.f(1.5, 2.6), y)
        m = [M["jaune0"], M["jaune1"], M["suie"], M["noyau"]][i % 4]
        lot.put(m, G.boite((x, y, 0.03), (r.f(0.18, 0.42), r.f(0.12, 0.3), 0.035), r.f(0, 3.0), r.f(-0.3, 0.3), r.f(-0.3, 0.3)))
    V.cable(lot, M["noir"], (-2.6, -1.0, 0.05), (-1.4, -2.2, 0.05), -0.05, 0.016)
    return {}
