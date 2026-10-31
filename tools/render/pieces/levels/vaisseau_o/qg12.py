"""QG ÂGE 12 : SUPRACONDUCTEURS (série du 31/10). Emprise 14×7. NEZ À DROITE (+X), tuyères à gauche.

Bible (DESIGN_EPOQUES §5, époque 12, ère IV) : « Nexus : noyau noir vertical ; 3 anneaux chromés horizontaux en lévitation,
espacés (vides) ; 4 pylônes » ; kit : anneau chromé (3 diamètres), noyau noir, pylône, bloc flottant, givre ; la silhouette
se fragmente. Palette 60/30/10 validée par le DC pour les familles de l'âge 12 (commun/ages.py, _m12, ronde 3) : BLANC GLACÉ
teinté CYAN (capots givrés, mousse des conduites) / NOIR MIROIR et CHROME (structure, anneaux) / CYAN lumineux.

Lecture : la carcasse (crâne, tuyères, épine, côtes de chrome) lévite sur 4 berceaux, vide franc dessous ; ses tôles se
détachent et flottent ; ailes et dérive en éclats ; le noyau noir traverse la cage, 3 anneaux chromés flottent autour sans
rien toucher ; devant, 3 blocs de glace flottent sur leur plinthe, marches flottantes au milieu ; 4 pylônes à isolateurs ;
derrière, la grande sphère cryogénique et sa mousse.
"""
import math

import carcasse as C
import ere4 as E
import geo as G
import mat as MT

POSE = dict(T=(0.0, 0.95, 2.7), lacet=-0.105, tangage=0.0, roulis=0.17)
TAU = G.TAU
TOP = math.pi / 2


def matieres(S):
    M = {}
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.2, ra=0.26, ec=0.34, nu_k=1.2, ec_col=(0.05, 0.07, 0.085))
    sf = MT.surface
    cr = (0.006, 0.008, 0.01)
    gi = dict(rough=0.72, met=0.05, coulures=0.55, rouille=(0.14, 0.22, 0.25), usure=0.55, nu=(0.62, 0.74, 0.8), crasse=0.95, crasse_col=(0.012, 0.022, 0.03), pied=(0.2, 1.0, 0.35), grain=0.2)
    M["capot"] = sf("q12_givre", (0.36, 0.56, 0.64), graine=401, **gi)
    M["capot2"] = sf("q12_givre2", (0.2, 0.33, 0.39), graine=402, **gi)
    M["capot3"] = sf("q12_givre3", (0.52, 0.72, 0.79), graine=403, **gi)
    nm = dict(rough=0.2, met=0.55, coulures=0.3, rouille=(0.06, 0.09, 0.11), usure=0.85, nu=(0.55, 0.6, 0.65), crasse=0.5, crasse_col=(0.003, 0.004, 0.005), grain=0.08)
    M["noir"] = sf("q12_noir", (0.016, 0.019, 0.026), graine=404, **nm)
    M["noir2"] = sf("q12_noir2", (0.03, 0.036, 0.048), graine=405, **nm)
    ch = dict(rough=0.26, met=0.45, usure=0.35, nu=(0.72, 0.76, 0.8), crasse=0.75, crasse_col=cr, coulures=0.25, rouille=(0.1, 0.13, 0.15), grain=0.07)
    M["chrome"] = sf("q12_chrome", (0.4, 0.44, 0.49), graine=406, **ch)
    M["chrome2"] = sf("q12_chrome2", (0.17, 0.195, 0.23), graine=407, **ch)
    M["acier"] = M["chrome2"]
    M["acier_clair"] = M["chrome"]
    M["cote"] = M["chrome2"]
    M["bague"] = M["chrome"]
    M["epine"] = M["chrome"]
    M["riv"] = sf("q12_riv", (0.12, 0.13, 0.15), rough=0.4, met=0.45, usure=0.3, crasse=0.5, graine=408)
    M["noyau"] = sf("q12_noyau", (0.005, 0.006, 0.008), rough=0.5, met=0.6, usure=0.2, crasse=0.8, crasse_col=(0.002, 0.002, 0.003), graine=409)
    M["brule"] = sf("q12_brule", (0.008, 0.009, 0.011), rough=0.7, met=0.4, usure=0.0, crasse=0.8, crasse_col=(0.002, 0.003, 0.003), graine=410)
    ja = dict(rough=0.48, met=0.2, coulures=0.9, rouille=(0.16, 0.06, 0.02), usure=0.85, nu=(0.62, 0.6, 0.56), crasse=0.95, crasse_col=cr, pied=(0.3, 1.1, 0.5), grain=0.11)
    M["jaune"] = sf("q12_jaune", (0.36, 0.205, 0.013), graine=411, **ja)
    M["chevron"] = sf("q12_chevron", (0.36, 0.205, 0.013), rough=0.5, met=0.2, bandes=(0.19, (0.012, 0.011, 0.012), 0.5), usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.6, graine=412)
    M["caoutchouc"] = sf("q12_caoutchouc", (0.018, 0.02, 0.024), rough=0.7, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.08), crasse=0.5, crasse_col=cr, graine=413)
    M["sarcelle"] = sf("q12_sarcelle", (0.02, 0.2, 0.26), rough=0.45, met=0.1, usure=0.4, crasse=0.5, crasse_col=cr, graine=414)
    M["mousse"] = sf("q12_mousse", (0.42, 0.6, 0.66), rough=0.85, met=0.0, tole=(0.9, 0.34), joint=0.45, joint_l=0.01, var=0.07, coulures=0.4, rouille=(0.14, 0.2, 0.22), usure=0.4, nu=(0.8, 0.9, 0.94), crasse=0.85, crasse_col=(0.012, 0.022, 0.03), relief=0.5, grain=0.3, graine=415)
    M["plinthe"] = sf("q12_plinthe", (0.04, 0.046, 0.058), rough=0.4, met=0.4, tole=(0.7, 0.7), joint=0.25, joint_l=0.012, var=0.2, usure=0.8, nu=(0.5, 0.55, 0.6), crasse=0.8, crasse_col=cr, relief=0.4, graine=416)
    M["frime"] = sf("q12_frime", (0.2, 0.3, 0.33), rough=0.85, met=0.0, usure=0.0, crasse=0.4, crasse_col=(0.06, 0.1, 0.12), grain=0.4, graine=417)
    M["verre_sombre"] = MT.verre("q12_verre_sombre", col=(0.004, 0.012, 0.018), reflet=(0.12, 0.26, 0.32))
    M["hublot"] = MT.lumiere(S, "q12_hublot", (0.07, 0.87, 1.0), 4.0, main=0.45)
    M["cyan"] = MT.lumiere(S, "q12_cyan", (0.07, 0.87, 1.0), 4.0, main=0.4)
    M["veilleuse"] = MT.verre("q12_veilleuse", col=(0.008, 0.04, 0.05), reflet=(0.2, 0.42, 0.48))
    M["voyant"] = MT.lumiere(S, "q12_voyant", (0.07, 0.87, 1.0), 7.0, main=0.4)
    M["coeur"] = MT.lumiere(S, "q12_coeur", (0.18, 0.9, 1.0), 3.4, main=0.32)
    return M


def oct_(prof, c, n=8, phase=0.3927):
    rings = [[(c[0] + r_ * math.cos(phase + TAU * j / n), c[1] + r_ * math.sin(phase + TAU * j / n), z) for j in range(n)] for (z, r_) in prof]
    return G.loft(rings, cap1=True)


def bloc(lot, M, x0, x1, y0, y1, z0, z1, ch, m, mh=None):
    """Bloc chanfreiné : plan rectangulaire à coins abattus, biseau en haut et en bas."""
    def plan(k):
        return [(x0 + ch + k, y0 + k), (x1 - ch - k, y0 + k), (x1 - k, y0 + ch + k), (x1 - k, y1 - ch - k), (x1 - ch - k, y1 - k), (x0 + ch + k, y1 - k), (x0 + k, y1 - ch - k), (x0 + k, y0 + ch + k)]
    ring = lambda z, k: [(p[0], p[1], z) for p in plan(k)]
    b = 0.07
    lot.put(m, G.loft([ring(z0, b), ring(z0 + b, 0.0), ring(z1 - b * 2, 0.0), ring(z1, b * 2)], cap0=True, cap1=False))
    lot.put(mh or m, G.loft([ring(z1, b * 2), ring(z1 + 0.012, b * 2 + 0.02)], cap1=True))


def build(S, lot):
    M = matieres(S)
    P = E.PoseK(**POSE)
    r = G.Rnd(1210)
    ra = G.Rnd(1211)
    niv = P.niv
    mc = E.tirage(M, [(0.3, "capot"), (0.2, "capot2"), (0.08, "capot3"), (0.16, "noir"), (0.14, "noir2"), (0.06, "chrome2"), (0.06, "jaune")])
    sc = C.surf_coque

    # ======================================================================================== 1. carcasse fragmentée
    E.crane(lot, M, P, r, mc)
    E.queue(lot, M, P, r, mc)
    E.dos(lot, M, P, r, mc, x0=-1.75, x1=2.0)
    E.epine(lot, M, P)
    E.lisses(lot, M, P)
    pieds = E.cotes(lot, M, P, haut=lambda x: 0.5)

    def rings_nac(s, sn, R, xar):
        for (xb, rr_, er) in ((xar - 0.12, R * 1.42, 0.06), (-1.05, R + 0.26, 0.05)):
            lot.put(M["chrome"], G.tour([(xb - 0.09, rr_ - er), (xb - 0.09, rr_ + er), (xb + 0.09, rr_ + er), (xb + 0.09, rr_ - er), (xb - 0.09, rr_ - er)], 48, "x"))
            lot.put(M["cyan"], G.tour([(xb - 0.025, rr_ - er - 0.006), (xb + 0.025, rr_ - er - 0.006)], 48, "x", a0=0.2, a1=2.6))
    rb = G.Rnd(1220)

    def nac2(s, sn, R, xar):
        rings_nac(s, sn, R, xar)
        E.bazar(lot, M, sn, -0.3, -2.3, 0.9, 2.9, rb, 30, ("noir2", "noyau", "chrome2", "capot"))
    E.tuyeres(lot, M, P, r, mc, apres=nac2, cerclages=(-0.45, -2.25))
    E.menus(lot, M, P, G.Rnd(1212), n=320, cles=("chrome2", "noyau", "chrome", "noir2"))
    lot.xf = P.xf
    E.bazar(lot, M, sc, -3.35, -2.3, TOP - 1.1, TOP + 1.2, rb, 34, ("noir2", "noyau", "chrome2", "capot"))
    E.bazar(lot, M, sc, 2.3, 3.0, TOP - 1.2, TOP + 1.2, rb, 16, ("noir2", "noyau", "chrome2", "capot2"))
    E.bazar(lot, M, sc, 4.35, 5.1, TOP - 1.0, TOP + 1.0, rb, 12, ("noir2", "noyau", "chrome2", "capot2"))
    # tôles détachées : elles flottent à 0,2 au-dessus de la coque
    surf_f = lambda x, a, g: sc(x, a, g + 0.22)
    for (x0, x1, a0, a1, m) in ((2.45, 3.0, TOP + 0.6, TOP + 1.35, "capot"), (3.0, 3.75, TOP - 1.35, TOP - 0.78, "capot3"), (4.4, 4.95, TOP - 0.5, TOP + 0.5, "noir2"), (-3.2, -2.5, TOP - 0.55, TOP + 0.2, "capot"),
                                (-2.45, -1.95, TOP + 0.3, TOP + 1.05, "capot3"), (2.35, 2.75, TOP - 0.6, TOP + 0.25, "noir2")):
        lot.put(M[m], C.plaque(surf_f, x0, x1, a0, a1, 0.04))
        for (t, u) in ((0.2, 0.3), (0.75, 0.7)):
            q = sc(x0 + (x1 - x0) * t, a0 + (a1 - a0) * u, 0.1)
            lot.put(M["cyan"], G.sphere(q, 0.022, 6, 3))
    # marquages, grilles
    for (x, a, w, l) in ((3.0, TOP - 0.3, 0.3, 0.38), (3.9, TOP + 0.95, 0.26, 0.36), (-2.9, TOP + 0.9, 0.28, 0.46), (-2.6, TOP - 0.9, 0.24, 0.42)):
        p, n = C.point(x, a, 0.07), C.normale_s(sc, x, a)
        lot.put(M["chrome2"], C.pose_plane(G.boite((0, 0, 0.0), (l + 0.06, w + 0.06, 0.04)), p, n))
        lot.put(M["noyau"], C.pose_plane(G.boite((0, 0, 0.015), (l, w, 0.03)), p, n))
        for k in range(6):
            lot.put(M["chrome2"], C.pose_plane(G.boite((-l / 2 + l * (k + 0.5) / 6, 0, 0.035), (l / 6 * 0.45, w, 0.025)), p, n))

    # dérive et ailes en éclats : le contour d'origine se lit, chaque éclat flotte
    z0 = C.z_dessus(-2.4)
    for (poly, m) in (([(-2.42, z0 + 0.12), (-2.8, z0 + 0.72), (-3.55, z0 + 0.72), (-3.42, z0 + 0.12)], "noir2"),
                      ([(-2.9, z0 + 0.88), (-3.18, z0 + 1.32), (-3.75, z0 + 1.32), (-3.63, z0 + 0.88)], "capot"),
                      ([(-3.27, z0 + 1.48), (-3.4, z0 + 1.78), (-3.98, z0 + 1.84), (-3.85, z0 + 1.48)], "chevron")):
        lot.put(M[m], C.prisme_plan(poly, 0.09))
    lot.put(M["chrome"], G.tube([(-2.3, 0.0, z0 - 0.02), (-3.75, 0.0, z0 + 1.9)], 0.022, 6))
    lot.put(M["voyant"], G.sphere((-3.9, 0.0, z0 + 1.96), 0.03, 6, 3))
    yr = 1.88

    def eclat(pts, zr, di, m, s=1):
        poly = pts if s > 0 else list(reversed(pts))
        v, f, u = G.prisme(poly, -0.05, 0.05)
        lot.put(m, ([(q[0], q[1], q[2] + zr + abs(q[1] - s * yr) * di) for q in v], f, u))
    for (pts, m) in (([(-2.8, 2.0), (-4.35, 2.0), (-4.55, 2.55), (-3.2, 2.55)], "noir2"), ([(-3.32, 2.72), (-4.62, 2.72), (-4.85, 3.08), (-3.62, 3.08)], "capot"),
                     ([(-3.8, 3.25), (-4.95, 3.25), (-5.3, 3.62), (-4.45, 3.68)], "capot3")):
        eclat(pts, -0.42, 0.24, M[m])
    for (pts, m) in (([(-2.85, -2.0), (-4.05, -2.0), (-4.15, -2.42), (-3.05, -2.42)], "noir2"), ([(-3.15, -2.58), (-4.2, -2.58), (-4.45, -3.0), (-3.5, -3.0)], "capot")):
        eclat(pts, -0.42, 0.24, M[m], -1)
    lot.put(M["chrome"], G.tube([(-2.65, yr, -0.36), (-4.55, 3.65, 0.08)], 0.022, 6))
    lot.put(M["chrome"], G.tube([(-2.7, -yr, -0.36), (-4.1, -3.05, -0.1)], 0.022, 6))

    # ======================================================================================== 2. ventre en éclats, berceaux de lévitation
    lot.xf = None
    fv = E.surf_fuseau(niv((0.25, -0.08, 0.0)), 5.5, 3.0, 1.0, 2.05, POSE["lacet"])
    me = E.tirage(M, [(0.42, "capot"), (0.22, "capot2"), (0.24, "noir2"), (0.12, "chrome2")], None)
    rs = G.Rnd(1221)
    trou = lambda x, a: rs.f() < 0.42 or abs(x - 0.0) < 0.75
    C.blindage(lot, fv, -2.6, 2.6, math.pi - 0.95, math.pi + 0.7, me, r, Mriv=M["riv"], saut=trou, larg=(0.5, 1.0), arcs=(0.4, 0.8), gap=0.05, ep=(0.03, 0.06), gondole=0.1, rivets=0.5)
    C.blindage(lot, fv, -2.6, 2.6, -0.7, 0.95, me, r, Mriv=M["riv"], saut=trou, larg=(0.5, 1.0), arcs=(0.4, 0.8), gap=0.05, ep=(0.03, 0.06), gondole=0.1, rivets=0.5)
    for (u, v, zb) in ((-1.9, 1.05, 1.48), (-1.9, -1.15, 1.42), (1.4, 1.05, 1.5), (1.4, -1.15, 1.45)):
        q = niv((u, v, 0.0))
        lot.put(M["plinthe"], oct_([(0.0, 0.62), (0.1, 0.56), (0.18, 0.4)], q))
        lot.put(M["noir"], oct_([(0.16, 0.3), (zb - 0.42, 0.21), (zb - 0.38, 0.32), (zb - 0.26, 0.34)], q))
        for z in (0.5, 0.74):
            lot.put(M["chrome"], oct_([(z - 0.03, 0.27), (z + 0.03, 0.26)], q))
        lot.put(M["cyan"], oct_([(zb - 0.255, 0.24), (zb - 0.24, 0.24)], q))
        # le sabot, en haut, ne touche pas le pied : vide de 0,2
        lot.put(M["chrome2"], oct_([(zb - 0.03, 0.34), (zb + 0.12, 0.3), (zb + 0.36, 0.14)], q))

    # ======================================================================================== 3. le noyau et ses 3 anneaux
    tc = P.xf((0.1, 0.0, 0.3))
    cx, cy = tc[0], tc[1]
    c0 = (cx, cy)
    zh = 7.75
    lot.put(M["plinthe"], oct_([(0.0, 1.3), (0.1, 1.24), (0.24, 1.0), (0.42, 0.84)], c0))
    lot.put(M["noir"], oct_([(0.4, 0.72), (3.5, 0.62), (5.6, 0.54), (zh, 0.34), (zh + 0.1, 0.16)], c0))
    lot.put(M["chrome"], E.tube_conique((cx, cy, zh + 0.08), (cx, cy, zh + 1.0), 0.13, 0.012, 12, 8))
    for (z, r0, h) in ((0.68, 0.74, 0.08), (1.1, 0.72, 0.03), (3.5, 0.64, 0.05), (4.72, 0.59, 0.1), (5.88, 0.53, 0.09), (6.9, 0.44, 0.08), (zh - 0.08, 0.36, 0.05)):
        lot.put(M["chrome"], oct_([(z - h, r0), (z - h * 0.7, r0 + 0.035), (z + h * 0.7, r0 + 0.035), (z + h, r0)], c0))
    # veines de givre et lignes cyan sur le noyau (côté caméra)
    for (a, z0_, z1_, wv) in ((-TOP - 0.45, 1.25, 3.4, 0.05), (-TOP + 0.5, 1.2, 2.7, 0.04), (-TOP + 0.05, 3.65, 4.55, 0.04), (-TOP - 0.3, 4.95, 5.7, 0.035), (-TOP + 0.3, 5.05, 5.75, 0.03)):
        for (t0, rz0) in ((0.0, 0.0),):
            pts = [(cx + (0.7 - z * 0.022) * math.cos(a + 0.08 * math.sin(z * 3.0)), cy + (0.7 - z * 0.022) * math.sin(a + 0.08 * math.sin(z * 3.0)), z) for z in [z0_ + (z1_ - z0_) * i / 12.0 for i in range(13)]]
            lot.put(M["frime"], G.tube(pts, wv, 5))
    for (a, z0_, z1_) in ((-TOP - 0.15, 1.3, 3.35), (-TOP + 0.2, 3.65, 4.5), (-TOP - 0.1, 4.95, 5.7), (-TOP + 0.05, 6.1, 6.7)):
        E.chenillard(lot, M["cyan"], (cx + (0.72 - z0_ * 0.022) * math.cos(a), cy + (0.72 - z0_ * 0.022) * math.sin(a), z0_), (cx + (0.72 - z1_ * 0.022) * math.cos(a), cy + (0.72 - z1_ * 0.022) * math.sin(a), z1_), ra, r=0.012)
    # cœur : fente au pied du noyau
    pc = (cx, cy - 0.74, 2.15)
    lot.put(M["chrome2"], E.pose(G.boite((0, 0, 0.01), (0.46, 0.92, 0.04)), pc, (0.0, -1.0, 0.0)))
    lot.put(M["coeur"], E.pose(G.boite((0, 0, 0.03), (0.24, 0.74, 0.02)), pc, (0.0, -1.0, 0.0)))
    # les 3 anneaux, à 3 diamètres, sans contact
    for (zr, R, er, ez, nl) in ((4.72, 2.85, 0.15, 0.09, 4), (5.88, 2.1, 0.12, 0.08, 3), (6.9, 1.4, 0.09, 0.065, 2)):
        E.anneau(lot, M["chrome"], (cx, cy, zr), R, er, ez, 96)
        E.anneau(lot, M["noir"], (cx, cy, zr + ez + 0.012), R, er * 0.45, 0.012, 96)
        for k in range(nl):
            a0 = TAU * k / nl + 0.2 * R
            E.arc_lum(lot, M["cyan"], (cx, cy, zr), R - er - 0.006, 0.026, a0, a0 + TAU / nl * 0.55, 20)
        for k in range(8):                                     # sabots magnétiques posés sur l'anneau
            a = TAU * k / 8 + 0.15
            lot.put(M["noir2"], G.boite((cx + (R + er * 0.9) * math.cos(a), cy + (R + er * 0.9) * math.sin(a), zr), (0.2, 0.09, ez * 2.6), a + TOP))
    # 4 petits blocs flottants entre les anneaux
    for (a, R, zb, sz) in ((-0.5, 1.5, 5.3, 0.17), (-2.5, 1.65, 5.2, 0.21), (-1.5, 1.25, 6.4, 0.14), (0.9, 1.4, 6.3, 0.15)):
        q = (cx + R * math.cos(a), cy + R * math.sin(a), zb)
        lot.put(M["capot3"], G.boite(q, (sz, sz, sz * 0.8), a))
        lot.put(M["noir2"], G.boite(G.add(q, (0, 0, -sz * 0.45)), (sz * 1.1, sz * 1.1, 0.03), a))
    # cage basse autour du noyau : couronne au niveau du ventre
    E.anneau(lot, M["chrome2"], (cx, cy, 1.62), 1.15, 0.07, 0.05, 64)
    for k in range(6):
        a = TAU * k / 6 + 0.3
        C.tuyau(lot, M["mousse"], M["chrome"], [(cx + 0.72 * math.cos(a), cy + 0.72 * math.sin(a), 1.35), (cx + 1.08 * math.cos(a), cy + 1.08 * math.sin(a), 1.35), (cx + 1.08 * math.cos(a), cy + 1.08 * math.sin(a), 0.12)], 0.05, rb=0.1, pas_bride=0.5)

    # ======================================================================================== 4. 3 blocs de glace flottants au sud
    zp1 = 0.3
    tr = ((-5.25, -2.0, -2.95, -4.3, 0.6, 1.1), (-1.75, 1.3, -2.85, -4.75, 0.62, 1.42), (1.6, 4.25, -3.15, -4.5, 0.58, 1.18))
    CL = ("chrome2", "noir", "cyan", "chrome2", "noyau", "noir2", "voyant")
    for (i, (x0, x1, y1, y0, zv0, zv1)) in enumerate(tr):
        bloc(lot, M, x0 + 0.12, x1 - 0.12, y0 + 0.12, y1 - 0.12, 0.0, zp1, 0.22, M["plinthe"])
        bloc(lot, M, x0, x1, y0, y1, zv0, zv1, 0.34, M["capot2"], M["capot"])
        # interstice : un fil de lumière et des sabots
        E.chenillard(lot, M["cyan"], (x0 + 0.4, y0 + 0.2, zp1 + 0.012), (x1 - 0.4, y0 + 0.2, zp1 + 0.012), ra, r=0.011, part=0.6, pas=(0.3, 0.7))
        for xx in [x0 + 0.5 + (x1 - x0 - 1.0) * t for t in (0.0, 0.33, 0.66, 1.0)]:
            for yy in (y0 + 0.42, y1 - 0.42):
                lot.put(M["noir2"], G.boite((xx, yy, zv0 - 0.035), (0.26, 0.2, 0.07)))
                lot.put(M["chrome2"], G.boite((xx, yy, zp1 + 0.03), (0.26, 0.2, 0.06)))
        # toit plaqué, bric-à-brac
        fr = lambda x, a, g, z_=zv1: (x, a, z_ + 0.012 + g)
        mt = E.tirage(M, [(0.32, "capot"), (0.2, "capot2"), (0.1, "capot3"), (0.26, "noir"), (0.12, "chrome2")], None)
        C.blindage(lot, fr, x0 + 0.3, x1 - 0.3, y0 + 0.28, y1 - 0.28, mt, r, Mriv=M["riv"], larg=(0.34, 0.8), arcs=(0.26, 0.6), gap=0.03, ep=(0.015, 0.035), gondole=0.03, rivets=0.4)
        E.bazar(lot, M, fr, x0 + 0.34, x1 - 0.34, y0 + 0.3, y1 - 0.3, G.Rnd(1215 + i), 40 if i != 1 else 56, ("noir2", "noyau", "chrome2", "capot2"))
        # façades : pièces différentes, sangles, tuyau
        fs = lambda x, a, g, y_=y0, zb=zv0, zh=zv1: (x, y_ - g, zb + (zh - zb) * a)
        x = x0 + 0.38
        typ = ["noir", "grille", "ligne", "boite", "noir", "grille"]
        k = 0
        zm = (zv0 + zv1) / 2
        while x < x1 - 0.5:
            w = ra.f(0.28, 0.72)
            t = typ[(k + i) % len(typ)]
            k += 1
            xm = x + w / 2
            if i == 1 and abs(xm + 0.22) < 0.62:
                x += w
                continue
            p, n = (xm, y0 - 0.002, zm), (0.0, -1.0, 0.0)
            if t == "noir":
                E.ecran(lot, M["chrome2"], M["noir"], p, n, w * 0.88, (zv1 - zv0) * 0.5)
            elif t == "ligne":
                E.ecran(lot, M["noir"], M["cyan"], p, n, w * 0.7, 0.04)
            elif t == "grille":
                E.grille(lot, M["chrome2"], M["noyau"], p, n, w * 0.76, (zv1 - zv0) * 0.42, 4)
            else:
                E.boitier(lot, M["noir2"], M["voyant"], p, n, w * 0.7, (zv1 - zv0) * 0.5, 0.07)
            x += w + ra.f(0.05, 0.16)
        for xx in [x0 + (x1 - x0) * t for t in ((0.27, 0.73) if i != 1 else (0.14, 0.86))]:
            lot.put(M["chrome2"], G.boite((xx, y0 - 0.008, zm), (0.08, 0.03, zv1 - zv0 - 0.12)))
        C.faisceau(lot, M["sarcelle"], M["noyau"], (x0 + 0.35, y0 - 0.03, zv0 + 0.07), (x1 - 0.35, y0 - 0.03, zv0 + 0.07), 0.03, 3, 0.009, 0.02, ra)
    # bloc-chapeau flottant au-dessus du bloc central
    bloc(lot, M, -1.15, 0.72, -4.3, -3.3, 1.66, 1.92, 0.22, M["noir2"], M["capot"])
    for (x_, y_) in ((-0.9, -4.05), (0.45, -4.05), (-0.9, -3.55), (0.45, -3.55)):
        lot.put(M["cyan"], G.boite((x_, y_, 1.54), (0.09, 0.09, 0.012)))
        lot.put(M["chrome2"], G.boite((x_, y_, 1.47), (0.14, 0.14, 0.08)))
    fr2 = lambda x, a, g: (x, a, 1.93 + g)
    E.bazar(lot, M, fr2, -0.95, 0.5, -4.15, -3.45, G.Rnd(1219), 12, ("noir2", "noyau", "chrome2", "capot2"))
    # réservoirs givrés couchés sur le bloc ouest
    for (y_, R_) in ((-3.95, 0.17), (-3.45, 0.21)):
        lot.put(M["capot3"], G.tour([(-4.75, 0.0), (-4.65, R_ * 0.8), (-4.5, R_), (-3.0, R_), (-2.85, R_ * 0.8), (-2.75, 0.0)], 18, "x", (0.0, y_, 1.34)))
        for x_ in (-4.1, -3.4):
            lot.put(M["chrome2"], G.tour([(x_ - 0.03, R_ + 0.012), (x_ + 0.03, R_ + 0.012)], 18, "x", (0.0, y_, 1.34)))
    # anneau vertical flottant au-dessus du bloc est, noyau-témoin au centre
    rv = (2.95, -3.8, 2.02)
    lot.put(M["chrome"], G.tour([(rv[1] - 0.08, 0.6), (rv[1] - 0.08, 0.72), (rv[1] + 0.08, 0.72), (rv[1] + 0.08, 0.6), (rv[1] - 0.08, 0.6)], 48, "y", (rv[0], 0.0, rv[2])))
    lot.put(M["cyan"], G.tour([(rv[1] - 0.02, 0.594), (rv[1] + 0.02, 0.594)], 28, "y", (rv[0], 0.0, rv[2]), a0=0.6, a1=2.6))
    lot.put(M["noir"], G.sphere(rv, 0.2, 18, 9))
    lot.put(M["chrome2"], G.tour([(rv[1] - 0.02, 0.21), (rv[1] + 0.02, 0.21)], 24, "y", (rv[0], 0.0, rv[2])))
    lot.put(M["noir2"], G.boite((rv[0], rv[1], 1.27), (0.44, 0.34, 0.08)))
    lot.put(M["cyan"], G.boite((rv[0], rv[1], 1.33), (0.14, 0.1, 0.012)))
    # marches flottantes et porte (invariant : porte centrale au sud)
    dx = -0.22
    pd = (dx, -4.755, 0.98)
    lot.put(M["chrome2"], E.pose(G.boite((0, 0, 0.012), (0.82, 0.58, 0.03)), pd, (0.0, -1.0, 0.0)))
    lot.put(M["noyau"], E.pose(G.boite((0, 0, 0.025), (0.7, 0.52, 0.02)), pd, (0.0, -1.0, 0.0)))
    lot.put(M["chrome"], E.pose(G.boite((0, 0, 0.038), (0.022, 0.52, 0.02)), pd, (0.0, -1.0, 0.0)))
    lot.put(M["cyan"], E.pose(G.boite((0, 0.32, 0.03), (0.56, 0.03, 0.015)), pd, (0.0, -1.0, 0.0)))
    for k in range(4):
        q = (dx, -4.9 - 0.2 * k, 0.56 - 0.13 * k)
        lot.put(M["capot3"], G.boite(q, (0.82 - 0.02 * k, 0.16, 0.05)))
        lot.put(M["noir2"], G.boite(G.add(q, (0, 0, -0.035)), (0.66, 0.1, 0.02)))
    # liaisons vers le vaisseau : mousse froide, sous la coque
    for (x, yy, rr_) in ((-3.2, -2.95, 0.11), (0.1, -2.85, 0.13), (3.1, -3.13, 0.1)):
        C.tuyau(lot, M["mousse"], M["chrome"], [(x, yy, 0.98), (x, -2.0, 0.98), niv((x, -1.25, 1.4)), niv((x, -0.85, 1.75))], rr_, rb=0.2, pas_bride=0.42)

    # ======================================================================================== 5. pylônes à isolateurs
    for (px, py, zh_) in ((-4.9, -2.05, 4.3), (5.15, -2.15, 4.3), (-2.6, 4.55, 5.0), (2.3, 4.5, 5.0)):
        lot.put(M["plinthe"], oct_([(0.0, 0.62), (0.08, 0.58), (0.16, 0.42)], (px, py)))
        zt_ = zh_ - 1.0
        cns = [(0.34, 0.34), (-0.34, 0.34), (-0.34, -0.34), (0.34, -0.34)]
        for (dx_, dy_) in cns:
            lot.put(M["noir2"], E.tube_conique((px + dx_, py + dy_, 0.14), (px + dx_ * 0.3, py + dy_ * 0.3, zt_), 0.042, 0.022, 6, 6))
        n = 6
        for k in range(n):
            z_a, z_b = 0.2 + (zt_ - 0.2) * k / float(n), 0.2 + (zt_ - 0.2) * (k + 1) / float(n)
            sa, sb = 1.0 - 0.7 * (z_a - 0.14) / (zt_ - 0.14), 1.0 - 0.7 * (z_b - 0.14) / (zt_ - 0.14)
            for j in range(4):
                a, b = cns[j], cns[(j + 1) % 4]
                pa = (px + a[0] * sa, py + a[1] * sa, z_a)
                pb = (px + b[0] * sb, py + b[1] * sb, z_b)
                lot.put(M["chrome2"], G.tube([pa, pb], 0.012, 4))
                lot.put(M["chrome2"], G.tube([(px + a[0] * sb, py + a[1] * sb, z_b), (px + b[0] * sb, py + b[1] * sb, z_b)], 0.012, 4))
        lot.put(M["noir"], oct_([(zt_ - 0.06, 0.15), (zt_ + 0.05, 0.12)], (px, py)))
        for k in range(7):
            z = zt_ + 0.09 + 0.1 * k
            lot.put(M["capot3"], G.tour([(z - 0.018, 0.1), (z, 0.16 - 0.006 * k), (z + 0.018, 0.1)], 14, "z", (px, py, 0.0)))
            lot.put(M["noir"], G.tour([(z + 0.018, 0.075), (z + 0.08, 0.075)], 10, "z", (px, py, 0.0)))
        lot.put(M["chrome"], G.sphere((px, py, zh_ - 0.08), 0.12, 14, 7))
        lot.put(M["voyant"], G.sphere((px, py, zh_ + 0.06), 0.026, 6, 3))
        E.anneau(lot, M["chrome"], (px, py, zh_ + 0.18), 0.26, 0.03, 0.022, 28)

    # ======================================================================================== 6. sphère cryogénique et mousse (nord-est), réservoirs
    gx, gy, gR = 5.35, 3.85, 1.12
    gz = 1.6
    lot.put(M["plinthe"], oct_([(0.0, 1.35), (0.08, 1.3), (0.2, 1.08)], (gx, gy)))
    lot.put(M["frime"], G.butte_polaire((gx, gy - 0.25, 0.0), 1.7, 1.25, 0.022, ra, 3, 36, 0.3, 0.25))
    for k in range(4):
        a = TAU * k / 4 + 0.5
        lot.put(M["noir2"], E.tube_conique((gx + 0.9 * math.cos(a), gy + 0.9 * math.sin(a), 0.16), (gx + 0.62 * math.cos(a), gy + 0.62 * math.sin(a), 0.86), 0.09, 0.06, 5, 8))
    lot.put(M["capot"], G.sphere((gx, gy, gz), gR, 48, 24))
    for k in range(8):
        a = TAU * k / 8 + 0.2
        arc = [(gx + (gR + 0.008) * math.cos(t) * math.cos(a), gy + (gR + 0.008) * math.cos(t) * math.sin(a), gz + (gR + 0.008) * math.sin(t)) for t in [-1.3 + 2.6 * i / 18.0 for i in range(19)]]
        lot.put(M["noir"], G.tube(arc, 0.008, 4))
    E.anneau(lot, M["chrome"], (gx, gy, gz + 0.02), gR + 0.2, 0.06, 0.055, 72)     # anneau flottant de la sphère
    E.arc_lum(lot, M["cyan"], (gx, gy, gz + 0.02), gR + 0.134, 0.018, -2.8, -0.3, 24)
    lot.put(M["chrome2"], G.tour([(gz + gR - 0.03, 0.22), (gz + gR + 0.05, 0.2), (gz + gR + 0.09, 0.08), (gz + gR + 0.32, 0.05), (gz + gR + 0.35, 0.0)], 14, "z", (gx, gy, 0.0)))
    C.tuyau(lot, M["mousse"], M["chrome"], [(gx - 0.9, gy - 0.75, 1.1), (3.75, 2.75, 1.1), (3.75, 1.75, 1.1), niv((3.2, 0.95, 1.55))], 0.15, rb=0.28, pas_bride=0.42)
    C.tuyau(lot, M["mousse"], M["chrome"], [(gx - 0.2, gy - 1.12, 0.55), (gx - 0.2, 2.1, 0.55), (4.6, 1.4, 0.55), niv((3.6, 0.75, 1.1))], 0.08, rb=0.18, pas_bride=0.4)
    # réservoirs couchés, à l'ouest
    for (x, y, L, R, m) in ((-5.75, 2.1, 1.6, 0.42, "capot2"),):
        lot.put(M[m], G.tour([(y - L / 2 - R * 0.5, 0.0), (y - L / 2 - R * 0.35, R * 0.7), (y - L / 2, R), (y + L / 2, R), (y + L / 2 + R * 0.35, R * 0.7), (y + L / 2 + R * 0.5, 0.0)], 28, "y", (x, 0.0, R + 0.24)))
        for t in (-0.28, 0.0, 0.28):
            lot.put(M["chrome2"], G.tour([(y + t * L - 0.025, R + 0.012), (y + t * L + 0.025, R + 0.012)], 28, "y", (x, 0.0, R + 0.24)))
        for t in (-0.3, 0.3):
            lot.put(M["noir"], G.boite((x, y + t * L, 0.13), (R * 1.5, 0.14, 0.26)))
        lot.put(M["frime"], G.butte_polaire((x, y, 0.0), R + 0.45, L / 2 + 0.5, 0.018, ra, 3, 28, 0.3, 0.25))

    # ======================================================================================== 7. réseaux, câbles, sol
    fx = [(pieds[i][1], pieds[i + 1][1], 0.26) for i in range(3)]
    fx += [(P.xf((-3.4, 0.0, C.z_dessus(-3.4) + 0.3)), P.xf((-2.2, 0.8, C.z_dessus(-2.2) + 0.2)), 0.22), (P.xf((2.0, -0.9, 0.6)), P.xf((3.4, -0.85, 0.3)), 0.18), (P.xf((-3.2, -1.0, 0.1)), P.xf((-2.1, -1.1, 0.0)), 0.2),
           ((-4.9, -2.05, 3.0), P.xf((-3.2, -0.95, 0.5)), 0.4), ((5.15, -2.15, 3.0), P.xf((3.3, -0.85, 0.2)), 0.4), ((-2.6, 4.55, 3.5), P.xf((-1.8, 1.1, 0.8)), 0.55), ((2.3, 4.5, 3.5), P.xf((2.4, 1.0, 0.9)), 0.55),
           ((-4.9, -2.05, 2.2), (-3.6, -3.1, 1.32), 0.32), ((5.15, -2.15, 2.2), (3.6, -3.0, 1.32), 0.32)]
    for (a, b, fl) in fx:
        C.faisceau(lot, M["sarcelle"], M["noyau"], a, b, fl, 3, 0.011, 0.028, r)
    for (a, b, c) in ((niv((-1.5, -0.9, 1.9)), niv((-2.2, -1.5, 0.7)), (-2.9, -2.95, 0.7)), (niv((1.2, -0.9, 1.9)), niv((1.6, -1.6, 0.7)), (2.3, -2.95, 0.7)), (niv((-2.8, -1.0, 1.8)), (-3.9, -1.95, 0.5), (-4.3, -2.98, 0.7)),
                      (P.xf((3.6, -0.8, -0.5)), (4.4, -1.85, 0.5), (4.55, -2.95, 0.7)), ((cx - 1.2, cy - 0.3, 0.3), (-2.3, -0.4, 0.1), niv((-1.9, -1.15, 1.2))), ((cx + 1.2, cy - 0.3, 0.3), (1.5, -0.6, 0.1), niv((1.4, -1.15, 1.2)))):
        C.flexible(lot, M["caoutchouc"], [a, b, c], 0.045)
    for (x, y, a, b) in ((cx, cy, 1.75, 1.3), (-0.2, -2.25, 0.9, 0.3)):
        lot.put(M["frime"], G.butte_polaire((x, y, 0.0), a, b, 0.016, ra, 3, 30, 0.3, 0.28))
    for (x, y, sz, rz, m, mk) in ((5.75, -4.1, 0.4, 0.3, "noir2", "cyan"), (6.15, -3.85, 0.32, -0.2, "capot", "noir"), (-5.85, -4.45, 0.38, 0.15, "noir2", "capot3"), (-6.35, -4.1, 0.3, 0.6, "capot2", "noir"), (0.35, 4.55, 0.38, -0.25, "noir2", "capot3")):
        E.cale(lot, M[m], x, y, sz, rz, M[mk])
    for (x, y) in ((6.25, -3.3), (6.42, -3.38), (6.33, -3.15)):
        lot.put(M["capot3"], G.tour([(0.0, 0.075), (0.48, 0.075), (0.54, 0.05), (0.62, 0.028)], 12, "z", (x, y, 0.0), cap1=True))
        lot.put(M["chrome2"], G.tour([(0.3, 0.078), (0.34, 0.078)], 12, "z", (x, y, 0.0)))
    E.touret(lot, M["chrome2"], M["sarcelle"], -6.45, -3.15, 0.19, 0.15)
    E.debris_sol(lot, M, G.Rnd(1214), 34, (-6.9, 6.9), (-4.9, 4.9), lambda x, y: abs(x) < 4.2 and abs(y) < 2.7, ("chrome2", "capot2", "noir2"))
    return {"pose": POSE}
