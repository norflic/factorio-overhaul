"""QG ÂGE 12 : SUPRACONDUCTEURS (reprise du 1/11, critique indépendante : REFAIRE). Emprise 14×7. NEZ À DROITE (+X).

Bible (DESIGN_EPOQUES §5, époque 12) : noyau noir vertical, anneau chromé en lévitation, pylônes, bloc flottant, givre.
Palette 60/30/10 validée par le DC (commun/ages.py, _m12) : BLANC GLACÉ teinté cyan / NOIR MIROIR et CHROME / CYAN lumineux.
Critique : un fuselage CONTINU d'une seule coque blanc givré ; UN grand anneau horizontal autour du fuselage ; un SEUL pont
cryogénique relié au fuselage, cuves et conduites givrées de longueurs différentes ; nez dégagé. Peau jaune d'origine :
environ 14 % de la coque, plus au crâne et aux nacelles (chaîne vers l'âge 13).

Lecture : le même vaisseau que les âges 10 et 11, dos fermé, côtes de chrome par-dessus, posé bas sur la même dalle mais qui
lévite d'un cheveu sur ses sabots ; le noyau noir sort du dos, l'anneau flotte autour ; au sud, le pont cryogénique collé au
flanc ; derrière la dérive, la sphère froide (le nez reste libre).
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
    MT.PATINE.update(ta=0.2, ra=0.26, ec=0.32, nu_k=1.2, ec_col=(0.05, 0.07, 0.085))
    sf = MT.surface
    cr = (0.006, 0.008, 0.01)
    gi = dict(rough=0.7, met=0.05, coulures=0.7, rouille=(0.13, 0.2, 0.23), usure=0.55, nu=(0.66, 0.78, 0.84), crasse=0.95, crasse_col=(0.012, 0.022, 0.03), pied=(0.2, 1.0, 0.35), grain=0.2)
    M["capot"] = sf("q12_givre", (0.36, 0.56, 0.64), graine=401, **gi)
    M["capot2"] = sf("q12_givre2", (0.2, 0.33, 0.39), graine=402, **gi)
    M["capot3"] = sf("q12_givre3", (0.52, 0.72, 0.79), graine=403, **gi)
    nm = dict(rough=0.22, met=0.55, coulures=0.3, rouille=(0.06, 0.09, 0.11), usure=0.85, nu=(0.55, 0.6, 0.65), crasse=0.5, crasse_col=(0.003, 0.004, 0.005), grain=0.08)
    M["noirm"] = sf("q12_noir", (0.016, 0.019, 0.026), graine=404, **nm)
    M["noir2"] = sf("q12_noir2", (0.03, 0.036, 0.048), graine=405, **nm)
    ch = dict(rough=0.28, met=0.45, usure=0.35, nu=(0.72, 0.76, 0.8), crasse=0.75, crasse_col=cr, coulures=0.25, rouille=(0.1, 0.13, 0.15), grain=0.07)
    M["chrome"] = sf("q12_chrome", (0.42, 0.46, 0.51), graine=406, **ch)
    M["chrome2"] = sf("q12_chrome2", (0.17, 0.195, 0.23), graine=407, **ch)
    M["acier"] = M["chrome2"]
    M["acier_clair"] = M["chrome"]
    M["cote"] = M["chrome2"]
    M["bague"] = M["chrome"]
    M["riv"] = sf("q12_riv", (0.12, 0.13, 0.15), rough=0.4, met=0.45, usure=0.3, crasse=0.5, graine=408)
    M["noyau"] = sf("q12_noyau", (0.005, 0.006, 0.008), rough=0.5, met=0.6, usure=0.2, crasse=0.8, crasse_col=(0.002, 0.002, 0.003), graine=409)
    M["noir"] = M["noyau"]
    M["brule"] = sf("q12_brule", (0.008, 0.009, 0.011), rough=0.7, met=0.4, usure=0.0, crasse=0.8, crasse_col=(0.002, 0.003, 0.003), graine=410)
    ja = dict(rough=0.48, met=0.2, coulures=0.9, rouille=(0.16, 0.06, 0.02), usure=0.85, nu=(0.62, 0.6, 0.56), crasse=0.95, crasse_col=cr, pied=(0.3, 1.1, 0.5), grain=0.11)
    M["jaune"] = sf("q12_jaune", (0.42, 0.24, 0.014), graine=411, **ja)
    M["jaune2"] = sf("q12_jaune2", (0.26, 0.145, 0.01), graine=418, **ja)
    M["epine"] = M["chrome"]
    M["chevron"] = sf("q12_chevron", (0.36, 0.205, 0.013), rough=0.5, met=0.2, bandes=(0.19, (0.012, 0.011, 0.012), 0.5), usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.6, graine=412)
    M["bande"] = sf("q12_bande", (0.36, 0.205, 0.013), rough=0.5, met=0.2, bandes=(0.12, (0.012, 0.011, 0.01), 0.5), usure=0.5, crasse=0.6, crasse_col=cr, graine=419)
    M["caoutchouc"] = sf("q12_caoutchouc", (0.018, 0.02, 0.024), rough=0.7, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.08), crasse=0.5, crasse_col=cr, graine=413)
    M["sarcelle"] = sf("q12_sarcelle", (0.02, 0.2, 0.26), rough=0.45, met=0.1, usure=0.4, crasse=0.5, crasse_col=cr, graine=414)
    M["mousse"] = sf("q12_mousse", (0.42, 0.6, 0.66), rough=0.85, met=0.0, tole=(0.9, 0.34), joint=0.45, joint_l=0.01, var=0.07, coulures=0.4, rouille=(0.14, 0.2, 0.22), usure=0.4, nu=(0.8, 0.9, 0.94), crasse=0.85, crasse_col=(0.012, 0.022, 0.03), relief=0.5, grain=0.3, graine=415)
    M["pierre"] = sf("q12_pierre", (0.16, 0.15, 0.13), rough=0.85, met=0.0, tole=(1.1, 0.8), joint=0.5, joint_l=0.012, var=0.16, coulures=0.5, rouille=(0.05, 0.04, 0.03), usure=0.7, nu=(0.28, 0.27, 0.25), crasse=0.85, crasse_col=cr, relief=0.4, graine=423)
    M["pierre2"] = sf("q12_pierre2", (0.07, 0.064, 0.054), rough=0.85, met=0.0, coulures=0.6, rouille=(0.03, 0.02, 0.012), usure=0.7, nu=(0.16, 0.15, 0.13), crasse=0.85, crasse_col=(0.005, 0.004, 0.003), graine=424)
    M["terre"] = sf("q12_terre", (0.11, 0.065, 0.035), rough=0.95, met=0.0, usure=0.0, crasse=0.7, crasse_col=(0.03, 0.018, 0.01), graine=425)
    M["frime"] = sf("q12_frime", (0.2, 0.3, 0.33), rough=0.85, met=0.0, usure=0.0, crasse=0.4, crasse_col=(0.06, 0.1, 0.12), grain=0.4, graine=417)
    M["verre_sombre"] = MT.verre("q12_verre_sombre", col=(0.004, 0.012, 0.018), reflet=(0.12, 0.26, 0.32))
    M["hublot"] = MT.lumiere(S, "q12_hublot", (0.07, 0.87, 1.0), 3.0, main=0.32)
    M["cyan"] = MT.lumiere(S, "q12_cyan", (0.07, 0.87, 1.0), 2.8, main=0.3)
    M["veilleuse"] = MT.verre("q12_veilleuse", col=(0.008, 0.04, 0.05), reflet=(0.2, 0.42, 0.48))
    M["voyant"] = MT.lumiere(S, "q12_voyant", (0.07, 0.87, 1.0), 7.0, main=0.4)
    M["coeur"] = MT.lumiere(S, "q12_coeur", (0.1, 0.8, 1.0), 2.6, main=0.25)
    return M


def oct_(prof, c, n=8, phase=0.3927):
    rings = [[(c[0] + r_ * math.cos(phase + TAU * j / n), c[1] + r_ * math.sin(phase + TAU * j / n), z) for j in range(n)] for (z, r_) in prof]
    return G.loft(rings, cap1=True)


def cuve(lot, M, x0, x1, y, zb, R, m, cerces=3):
    """Cuve couchée d'axe x, fonds bombés, cerces, sabots."""
    c = (0.0, y, zb + R)
    lot.put(M[m], G.tour([(x0 - R * 0.5, 0.0), (x0 - R * 0.35, R * 0.72), (x0, R), (x1, R), (x1 + R * 0.35, R * 0.72), (x1 + R * 0.5, 0.0)], 28, "x", c))
    for k in range(cerces):
        x = x0 + (x1 - x0) * (k + 0.5) / cerces
        lot.put(M["chrome2"], G.tour([(x - 0.03, R + 0.012), (x + 0.03, R + 0.012)], 28, "x", c))
    for x in (x0 + 0.12, x1 - 0.12):
        lot.put(M["noir2"], G.boite((x, y, zb + 0.1), (0.16, R * 1.4, 0.2)))


def build(S, lot):
    M = matieres(S)
    P = E.PoseK(**POSE)
    r = G.Rnd(1210)
    ra = G.Rnd(1211)
    rb = G.Rnd(1220)
    niv = P.niv
    mc = E.tirage(M, [(0.2, "jaune"), (0.08, "jaune2"), (0.38, "capot"), (0.14, "capot2"), (0.08, "capot3"), (0.06, "noir2"), (0.06, "chrome2")])
    mn = E.tirage(M, [(0.26, "jaune"), (0.12, "jaune2"), (0.32, "capot"), (0.14, "capot2"), (0.16, "noir2")], None)
    mv = E.tirage(M, [(0.52, "capot"), (0.2, "capot2"), (0.12, "capot3"), (0.1, "noir2"), (0.06, "chrome2")], None)
    sc = C.surf_coque
    BZ = ("capot2", "noir2", "chrome2", "capot3")

    # ======================================================================================== 1. dalle, fuselage continu
    E.terrasses(lot, M, G.Rnd(1222))
    E.butte_nez(lot, M, P, G.Rnd(1223))
    E.crane(lot, M, P, r, mc)
    E.queue(lot, M, P, r, mc)
    lot.xf = P.xf
    # dos fermé : une seule coque du crâne à la queue
    C.noyau(lot, M["noyau"], sc, -2.2, 2.24, -0.2, math.pi + 0.2, g=-0.01)
    C.blindage(lot, sc, -2.2, 2.24, -0.2, math.pi + 0.2, mv, r, Mriv=M["riv"], **E.LISSE)
    E.epine(lot, M, P)
    E.lisses(lot, M, P)
    pieds = E.cotes(lot, M, P, haut=lambda x: 0.24)

    def nac2(s, sn, R, xar):
        for (xb, rr_, er) in ((xar - 0.12, R * 1.42, 0.06),):
            lot.put(M["chrome"], G.tour([(xb - 0.09, rr_ - er), (xb - 0.09, rr_ + er), (xb + 0.09, rr_ + er), (xb + 0.09, rr_ - er), (xb - 0.09, rr_ - er)], 48, "x"))
            lot.put(M["cyan"], G.tour([(xb - 0.02, rr_ - er - 0.006), (xb + 0.02, rr_ - er - 0.006)], 48, "x", a0=0.2, a1=2.6))
        E.bazar(lot, M, sn, -0.3, -2.3, 0.9, 2.9, rb, 22, BZ)
    E.tuyeres(lot, M, P, r, mn, apres=nac2, cerclages=(-0.45, -1.4, -2.25))
    E.menus(lot, M, P, G.Rnd(1212), n=300, cles=("chrome2", "noir2", "chrome", "capot2"))
    lot.xf = P.xf
    E.bazar(lot, M, sc, -3.35, -2.3, TOP - 1.1, TOP + 1.2, rb, 26, BZ)
    E.bazar(lot, M, sc, -2.1, 2.1, TOP - 1.25, TOP + 1.25, rb, 56, BZ)
    E.bazar(lot, M, sc, 2.3, 3.0, TOP - 1.2, TOP + 1.2, rb, 14, BZ)
    E.bazar(lot, M, sc, 4.35, 5.1, TOP - 1.0, TOP + 1.0, rb, 10, BZ)
    # marques de givre : conduites de mousse le long du dos, tôles de chrome
    for (a, x0, x1, rt) in ((TOP + 0.82, -2.1, 1.9, 0.055), (TOP - 0.85, -1.7, 2.0, 0.045), (TOP + 1.3, -1.9, 0.7, 0.04)):
        lot.put(M["mousse"], G.tube([sc(x0 + (x1 - x0) * i / 18.0, a, 0.07) for i in range(19)], rt, 8))
    # 2 tôles qui se détachent seulement : le fuselage reste continu
    surf_f = lambda x, a, g: sc(x, a, g + 0.2)
    for (x0, x1, a0, a1, m) in ((2.45, 2.95, TOP + 0.6, TOP + 1.25, "capot3"), (-3.1, -2.55, TOP - 0.45, TOP + 0.2, "capot3")):
        lot.put(M[m], C.plaque(surf_f, x0, x1, a0, a1, 0.04))
        for (t, u) in ((0.2, 0.3), (0.75, 0.7)):
            lot.put(M["cyan"], G.sphere(sc(x0 + (x1 - x0) * t, a0 + (a1 - a0) * u, 0.1), 0.02, 6, 3))
    E.grilles_coque(lot, M, P)
    E.derive_ailes(lot, M, P, ("capot", "noir2", "jaune", "capot2", "voyant"))

    # ======================================================================================== 2. ventre, sabots en lévitation
    fv = E.ventre(lot, M, P, mv, r)
    CL0 = ("chrome2", "noirm", "cyan", "chrome2", "noyau", "noir2", "voyant")
    E.rangee(lot, M, fv, -2.4, 2.4, math.pi - 0.25, ra, ["verre", "grille", "ecran", "boite", "verre", "porte", "grille"], CL0, sauts=((1.45, 2.3),))
    p, n = fv(1.88, math.pi - 0.25, 0.05), C.normale_s(fv, 1.88, math.pi - 0.25)
    lot.put(M["noir2"], G.oriente(G.tour([(0.0, 0.37), (0.05, 0.35), (0.07, 0.28), (0.02, 0.25)], 24, "z"), p, n))
    lot.put(M["coeur"], G.oriente(G.tour([(0.02, 0.25), (0.022, 0.0)], 24, "z"), p, n))
    for d in (-0.13, -0.04, 0.05, 0.14):
        lot.put(M["chrome"], E.pose(G.boite((d, 0.0, 0.05), (0.024, 0.52, 0.022)), p, n))
    for (u, v, zt) in ((-1.9, 1.05, 0.5), (-1.9, -1.2, 0.48), (1.4, 1.05, 0.5), (1.4, -1.2, 0.48), (-3.9, -1.25, 0.6), (3.05, -1.15, 0.55)):
        q = niv((u, v, 0.0))
        lot.put(M["noirm"], oct_([(0.08, 0.34), (zt - 0.24, 0.24), (zt - 0.2, 0.32), (zt - 0.12, 0.34)], q))
        lot.put(M["cyan"], oct_([(zt - 0.115, 0.22), (zt - 0.105, 0.22)], q))
        lot.put(M["chrome2"], oct_([(zt - 0.03, 0.34), (zt + 0.08, 0.3), (zt + 0.28, 0.16)], q))     # le sabot ne touche pas : vide de 0,09

    # ======================================================================================== 3. noyau noir, le grand anneau
    tc = P.xf((0.1, 0.0, C.z_dessus(0.1)))
    cx, cy = tc[0], tc[1]
    c0 = (cx, cy)
    zh = 6.7
    lot.put(M["chrome2"], oct_([(2.86, 0.92), (3.02, 0.84), (3.18, 0.66)], c0))
    lot.put(M["noirm"], oct_([(3.1, 0.6), (4.4, 0.52), (zh, 0.32), (zh + 0.1, 0.15)], c0))
    lot.put(M["chrome"], E.tube_conique((cx, cy, zh + 0.08), (cx, cy, zh + 1.0), 0.12, 0.014, 12, 8))
    for (z, r0, h) in ((3.42, 0.6, 0.05), (4.1, 0.55, 0.09), (5.35, 0.44, 0.08), (zh - 0.08, 0.34, 0.05)):
        lot.put(M["chrome"], oct_([(z - h, r0), (z - h * 0.7, r0 + 0.035), (z + h * 0.7, r0 + 0.035), (z + h, r0)], c0))
    for (a, z0_, z1_, wv) in ((-TOP - 0.45, 3.5, 3.98, 0.04), (-TOP + 0.5, 3.5, 4.0, 0.035), (-TOP + 0.05, 4.3, 5.2, 0.035)):
        pts = [(cx + (0.66 - (z - 3.1) * 0.07) * math.cos(a + 0.08 * math.sin(z * 3.0)), cy + (0.66 - (z - 3.1) * 0.07) * math.sin(a + 0.08 * math.sin(z * 3.0)), z) for z in [z0_ + (z1_ - z0_) * i / 8.0 for i in range(9)]]
        lot.put(M["frime"], G.tube(pts, wv, 5))
    pc = (cx, cy - 0.56, 4.72)
    lot.put(M["chrome2"], E.pose(G.boite((0, 0, 0.01), (0.2, 0.72, 0.03)), pc, (0.0, -1.0, 0.0)))
    lot.put(M["cyan"], E.pose(G.boite((0, 0, 0.022), (0.07, 0.58, 0.012)), pc, (0.0, -1.0, 0.0)))
    # UN anneau : au-dessus du dos, autour du fuselage, sans contact
    zr, Rg, er, ez = 3.72, 3.05, 0.17, 0.1
    E.anneau(lot, M["chrome"], (cx, cy, zr), Rg, er, ez, 112)
    E.anneau(lot, M["noirm"], (cx, cy, zr + ez + 0.012), Rg, er * 0.45, 0.012, 112)
    for k in range(4):
        a0 = TAU * k / 4 + 0.5
        E.arc_lum(lot, M["cyan"], (cx, cy, zr), Rg - er - 0.006, 0.022, a0, a0 + TAU / 4 * 0.5, 20)
    for k in range(10):
        a = TAU * k / 10 + 0.15
        lot.put(M["noir2"], G.boite((cx + (Rg + er * 0.9) * math.cos(a), cy + (Rg + er * 0.9) * math.sin(a), zr), (0.26, 0.1, ez * 2.5), a + TOP))
    for (a, R_, zb, sz) in ((-0.6, 1.55, 4.55, 0.18), (-2.6, 1.65, 4.45, 0.22), (1.0, 1.4, 4.75, 0.15)):    # blocs flottants
        q = (cx + R_ * math.cos(a), cy + R_ * math.sin(a), zb)
        lot.put(M["capot3"], G.boite(q, (sz, sz, sz * 0.8), a))
        lot.put(M["noir2"], G.boite(G.add(q, (0, 0, -sz * 0.45)), (sz * 1.1, sz * 1.1, 0.03), a))

    # ======================================================================================== 4. le pont cryogénique, un seul corps collé au flanc
    poly = [(-4.75, -2.15), (-4.2, -3.72), (3.55, -3.95), (4.65, -2.95), (4.3, -1.28), (-3.85, -1.1)]
    zd0, zd1 = 0.62, 0.76
    lot.put(M["pierre2"], G.prisme(E._sc(poly, 0.9), 0.1, zd0 - 0.14))
    lot.put(M["noir2"], G.prisme(E._sc(poly, 0.97), zd0, zd1))
    lot.put(M["capot2"], G.prisme(E._sc(poly, 0.99), zd1, zd1 + 0.03, top_scale=0.985))
    fr = lambda x, a, g: (x, a, zd1 + 0.03 + g)
    mp = E.tirage(M, [(0.34, "capot"), (0.24, "capot2"), (0.1, "capot3"), (0.2, "noir2"), (0.12, "chrome2")], None)
    C.blindage(lot, fr, -3.8, 3.75, -3.5, -1.35, mp, r, Mriv=M["riv"], larg=(0.4, 0.95), arcs=(0.3, 0.7), gap=0.03, ep=(0.015, 0.03), gondole=0.03, rivets=0.4)
    E.bazar(lot, M, fr, -3.8, 3.75, -3.5, -1.35, G.Rnd(1215), 74, BZ)
    for (xp, yp) in ((-3.7, -2.9), (-3.5, -1.5), (-1.6, -3.55), (-1.6, -1.45), (1.6, -3.7), (1.6, -1.45), (3.7, -3.2), (3.7, -1.6)):
        lot.put(M["noirm"], oct_([(0.08, 0.22), (zd0 - 0.17, 0.16), (zd0 - 0.14, 0.24)], (xp, yp)))
        lot.put(M["cyan"], G.boite((xp, yp, zd0 - 0.1), (0.1, 0.1, 0.012)))
        lot.put(M["chrome2"], G.boite((xp, yp, zd0 - 0.03), (0.3, 0.26, 0.06)))
    # façade sud (une seule, pièces différentes)
    x = -3.85
    typ = ["noir", "grille", "ligne", "boite", "noir", "grille", "ligne", "noir", "boite"]
    k = 0
    n_f = G.norm((0.03, -1.0, 0.0))
    while x < 3.3:
        w = ra.f(0.3, 0.75)
        t = typ[k % len(typ)]
        k += 1
        xm = x + w / 2
        pf = (xm, -3.64 - (xm + 4.2) * 0.0285, 0.69)
        if t == "noir":
            E.ecran(lot, M["chrome2"], M["noirm"], pf, n_f, w * 0.85, 0.09)
        elif t == "ligne":
            E.ecran(lot, M["noirm"], M["cyan"], pf, n_f, w * 0.65, 0.03)
        elif t == "grille":
            E.grille(lot, M["chrome2"], M["noyau"], pf, n_f, w * 0.7, 0.09, 3)
        else:
            E.boitier(lot, M["chrome2"], M["voyant"], pf, n_f, w * 0.5, 0.1, 0.04)
        x += w + ra.f(0.05, 0.14)
    # cuves couchées, de longueurs différentes
    zc = zd1 + 0.03
    for (x0, x1, y, R_, m, nc) in ((-3.55, -1.15, -2.95, 0.36, "capot", 4), (-3.15, -2.1, -2.05, 0.27, "capot3", 2), (1.05, 3.5, -3.15, 0.31, "capot", 3), (1.75, 2.75, -2.3, 0.23, "capot2", 2), (2.95, 3.65, -1.85, 0.2, "capot3", 1)):
        cuve(lot, M, x0, x1, y, zc, R_, m, nc)
    # cuves dressées, poste central avec la porte
    for (x_, y_, R_, h, m) in ((0.62, -2.15, 0.33, 1.45, "capot"), (-1.0, -1.82, 0.24, 1.05, "capot3"), (0.95, -1.62, 0.17, 0.72, "capot2")):
        lot.put(M[m], G.tour([(zc, R_), (zc + h, R_), (zc + h + R_ * 0.45, R_ * 0.6), (zc + h + R_ * 0.62, 0.0)], 24, "z", (x_, y_, 0.0)))
        for t in (0.2, 0.55, 0.85):
            lot.put(M["chrome2"], G.tour([(zc + h * t - 0.025, R_ + 0.012), (zc + h * t + 0.025, R_ + 0.012)], 24, "z", (x_, y_, 0.0)))
    fp = E.surf_fuseau((-0.32, -2.95), 2.6, 1.5, 0.58, zc + 0.02, TOP)
    x0p = -2.6 * 0.42
    C.noyau(lot, M["noyau"], fp, x0p, 1.2, -0.08, math.pi + 0.08)
    C.blindage(lot, fp, x0p, 1.18, -0.06, math.pi + 0.06, E.tirage(M, [(0.4, "noir2"), (0.34, "capot"), (0.14, "chrome2"), (0.12, "capot2")], None), r, Mriv=M["riv"], **E.LISSE2)
    ring = [fp(x0p, -0.06 + (math.pi + 0.12) * j / 20.0, 0.01) for j in range(21)]
    lot.put(M["chrome2"], G.loft([ring, [fp(x0p, TOP, -0.3)] * 21], closed=False))
    pd = (-0.32, -2.95 + x0p - 0.012, zc + 0.26)
    nd = (0.0, -1.0, 0.0)
    lot.put(M["chrome"], E.pose(G.boite((0, 0, 0.012), (0.62, 0.5, 0.03)), pd, nd))
    lot.put(M["noyau"], E.pose(G.boite((0, 0, 0.025), (0.5, 0.44, 0.02)), pd, nd))
    lot.put(M["chrome"], E.pose(G.boite((0, 0, 0.038), (0.02, 0.44, 0.012)), pd, nd))
    lot.put(M["cyan"], E.pose(G.boite((0, 0.28, 0.03), (0.42, 0.024, 0.012)), pd, nd))
    # escalier du pont : marches flottantes vers la terrasse
    for k in range(5):
        q = (-0.32, -3.92 - 0.17 * k, 0.72 - 0.115 * k)
        lot.put(M["capot3"], G.boite(q, (0.82 - 0.02 * k, 0.15, 0.045)))
        lot.put(M["noir2"], G.boite(G.add(q, (0, 0, -0.032)), (0.66, 0.1, 0.018)))
    # conduites givrées, longueurs différentes, du pont au fuselage
    for (x_, y0, z0, r_, zf, pb) in ((-2.35, -2.1, 1.05, 0.13, 1.45, 0.42), (-0.95, -1.75, 1.25, 0.1, 1.3, 0.4), (0.62, -1.82, 1.2, 0.14, 1.5, 0.45), (2.25, -2.1, 0.98, 0.09, 1.35, 0.36), (3.3, -1.7, 0.95, 0.07, 1.15, 0.32), (-3.45, -1.75, 0.98, 0.06, 1.1, 0.3)):
        C.tuyau(lot, M["mousse"], M["chrome"], [(x_, y0, z0), (x_, -1.15, z0), niv((x_, -1.15, zf)), niv((x_, -0.82, zf + 0.12))], r_, rb=0.16, pas_bride=pb)
    C.tuyau(lot, M["mousse"], M["chrome"], [(-1.15, -2.95, 1.28), (0.75, -2.95, 1.28), (1.05, -3.15, 1.28)], 0.05, rb=0.12, pas_bride=0.4)
    C.tuyau(lot, M["mousse"], M["chrome"], [(-3.05, -2.05, 1.32), (-3.05, -2.65, 1.32)], 0.04, rb=0.08, pas_bride=0.3)
    C.tuyau(lot, M["chrome2"], M["noir2"], [(1.75, -2.3, 1.3), (1.75, -2.85, 1.3)], 0.035, rb=0.06, pas_bride=0.25)
    for (x_, y_, a, b) in ((-2.35, -1.35, 0.55, 0.22), (0.6, -1.35, 0.5, 0.22), (2.9, -2.6, 0.55, 0.25)):
        lot.put(M["frime"], G.butte_polaire((x_, y_, zc), a, b, 0.012, ra, 3, 24, 0.3, 0.25))
    # garde-corps sur les bords libres
    for (a, b) in (((-4.2, -3.72, zc), (-1.0, -3.81, zc)), ((0.35, -3.85, zc), (3.5, -3.93, zc)), ((3.6, -3.88, zc), (4.55, -2.98, zc)), ((-4.65, -2.2, zc), (-4.22, -3.66, zc))):
        lot.put(M["chrome2"], G.tube([G.add(a, (0, 0, 0.3)), G.add(b, (0, 0, 0.3))], 0.011, 4))
        nn = max(1, int(G.length(G.sub(b, a)) / 0.45))
        for j in range(nn + 1):
            q = G.lerp(a, b, j / float(nn))
            lot.put(M["chrome2"], G.tube([q, G.add(q, (0, 0, 0.3))], 0.009, 4))

    # ======================================================================================== 5. pylônes, sphère froide derrière la dérive
    for (px, py, zh_) in ((-6.2, -3.55, 2.95), (6.05, -3.4, 2.95), (-6.25, 3.3, 3.6), (4.85, 3.45, 3.8)):
        lot.put(M["noirm"], oct_([(0.1, 0.5), (0.34, 0.46), (0.44, 0.34)], (px, py)))
        zt_ = zh_ - 1.0
        cns = [(0.3, 0.3), (-0.3, 0.3), (-0.3, -0.3), (0.3, -0.3)]
        for (dx_, dy_) in cns:
            lot.put(M["noir2"], E.tube_conique((px + dx_, py + dy_, 0.4), (px + dx_ * 0.3, py + dy_ * 0.3, zt_), 0.04, 0.022, 6, 6))
        nb = 5
        for k in range(nb):
            z_a, z_b = 0.42 + (zt_ - 0.42) * k / float(nb), 0.42 + (zt_ - 0.42) * (k + 1) / float(nb)
            sa, sb = 1.0 - 0.7 * (z_a - 0.4) / (zt_ - 0.4), 1.0 - 0.7 * (z_b - 0.4) / (zt_ - 0.4)
            for j in range(4):
                a, b = cns[j], cns[(j + 1) % 4]
                lot.put(M["chrome2"], G.tube([(px + a[0] * sa, py + a[1] * sa, z_a), (px + b[0] * sb, py + b[1] * sb, z_b)], 0.011, 4))
                lot.put(M["chrome2"], G.tube([(px + a[0] * sb, py + a[1] * sb, z_b), (px + b[0] * sb, py + b[1] * sb, z_b)], 0.011, 4))
        lot.put(M["noirm"], oct_([(zt_ - 0.06, 0.15), (zt_ + 0.05, 0.12)], (px, py)))
        for k in range(7):
            z = zt_ + 0.09 + 0.1 * k
            lot.put(M["capot3"], G.tour([(z - 0.018, 0.1), (z, 0.16 - 0.006 * k), (z + 0.018, 0.1)], 14, "z", (px, py, 0.0)))
            lot.put(M["noirm"], G.tour([(z + 0.018, 0.075), (z + 0.08, 0.075)], 10, "z", (px, py, 0.0)))
        lot.put(M["chrome"], G.sphere((px, py, zh_ - 0.08), 0.12, 14, 7))
        lot.put(M["voyant"], G.sphere((px, py, zh_ + 0.06), 0.026, 6, 3))
        E.anneau(lot, M["chrome"], (px, py, zh_ + 0.18), 0.26, 0.03, 0.022, 28)
    gx, gy, gR, gz = -1.55, 3.6, 0.92, 1.42
    lot.put(M["noirm"], oct_([(0.26, 1.0), (0.4, 0.86)], (gx, gy)))
    for k in range(4):
        a = TAU * k / 4 + 0.5
        lot.put(M["noir2"], E.tube_conique((gx + 0.75 * math.cos(a), gy + 0.75 * math.sin(a), 0.36), (gx + 0.52 * math.cos(a), gy + 0.52 * math.sin(a), 0.86), 0.08, 0.055, 5, 8))
    lot.put(M["capot"], G.sphere((gx, gy, gz), gR, 40, 20))
    for k in range(8):
        a = TAU * k / 8 + 0.2
        arc = [(gx + (gR + 0.008) * math.cos(t) * math.cos(a), gy + (gR + 0.008) * math.cos(t) * math.sin(a), gz + (gR + 0.008) * math.sin(t)) for t in [-1.3 + 2.6 * i / 18.0 for i in range(19)]]
        lot.put(M["noirm"], G.tube(arc, 0.007, 4))
    E.anneau(lot, M["chrome2"], (gx, gy, gz), gR + 0.06, 0.04, 0.05, 64)
    C.tuyau(lot, M["mousse"], M["chrome"], [(gx + 0.6, gy - 0.72, 0.85), (gx + 0.6, 2.2, 0.85), (gx + 1.2, 1.9, 1.05)], 0.11, rb=0.2, pas_bride=0.4)
    # cuve et tank de la tête nord-est : petits, le nez reste dégagé
    cuve(lot, M, 3.05, 4.3, 3.35, 0.34, 0.32, "capot2", 2)

    # ======================================================================================== 6. câbles, flexibles, sol
    fx = [(pieds[i][1], pieds[i + 1][1], 0.24) for i in range(3)]
    fx += [(P.xf((-3.4, 0.0, C.z_dessus(-3.4) + 0.3)), P.xf((-2.2, 0.8, C.z_dessus(-2.2) + 0.2)), 0.22), (P.xf((2.0, -0.9, 0.6)), P.xf((3.4, -0.85, 0.3)), 0.18), (P.xf((-3.2, -1.0, 0.1)), P.xf((-2.1, -1.1, 0.0)), 0.2),
           ((-6.2, -3.55, 1.9), (-4.2, -3.5, 1.0), 0.32), ((6.05, -3.4, 1.9), (4.4, -3.1, 1.0), 0.32), ((-6.25, 3.3, 2.4), P.xf((-3.1, 1.0, 0.8)), 0.55), ((4.85, 3.45, 2.5), P.xf((3.0, 0.8, 0.5)), 0.5)]
    for (a, b, fl) in fx:
        C.faisceau(lot, M["sarcelle"], M["noyau"], a, b, fl, 3, 0.011, 0.028, r)
    for (a, b, c) in (((-4.6, -2.0, 0.65), (-5.1, -1.6, 0.25), P.xf((-3.7, -1.4, -0.6))), ((4.5, -2.0, 0.65), (5.0, -1.6, 0.2), P.xf((3.6, -0.8, -0.5))), ((3.75, 2.95, 0.5), (3.6, 2.3, 0.15), niv((2.9, 0.9, 0.8))),
                      ((-5.0, 2.9, 0.5), (-4.9, 2.3, 0.2), P.xf((-3.6, 1.5, -0.5)))):
        C.flexible(lot, M["caoutchouc"], [a, b, c], 0.045)
    for (x, y, sz, rz, m, mk) in ((5.6, -3.55, 0.36, 0.3, "noir2", "cyan"), (5.2, -3.7, 0.28, -0.2, "capot", "noirm"), (-5.7, -3.55, 0.34, 0.15, "noir2", "capot3"), (-5.35, -3.75, 0.28, 0.5, "capot2", "noirm"), (1.2, 3.5, 0.34, -0.25, "noir2", "capot3")):
        lot.put(M["pierre"], G.boite((x, y, 0.32), (sz * 1.2, sz, 0.02), rz))
        E.cale(lot, M[m], x, y, sz, rz, M[mk])
    for (x, y) in ((6.2, -2.95), (6.36, -3.02), (6.27, -2.82)):
        lot.put(M["capot3"], G.tour([(0.34, 0.075), (0.82, 0.075), (0.88, 0.05), (0.96, 0.028)], 12, "z", (x, y, 0.0), cap1=True))
    E.touret(lot, M["chrome2"], M["sarcelle"], -6.5, -2.2, 0.19, 0.15)
    E.debris_sol(lot, M, G.Rnd(1214), 30, (-6.9, 6.9), (-4.9, 4.9), lambda x, y: abs(x) < 6.6 and abs(y) < 4.1, ("chrome2", "capot2", "noir2"))
    return {"pose": POSE}
