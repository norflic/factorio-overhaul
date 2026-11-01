"""PORTIQUE (fo-robot-gantry), âge 13 · Fusion, emprise 11×11 (x ±5,5 ; y ±7,78). PLAN ROBOTS §5 bis.

Lecture : 2 tours de céramique blanche, inégales et décalées en diagonale (trois-quarts, pas d'arche frontale), courbes comme
des défenses, chacune sur un trépied, portent en l'air un TORE DE PLASMA horizontal. Dans le VIDE central, le géant prend forme :
sphère du Torique à moitié bardée, cœur nu relié au tore par des arcs, tore du robot en cours de pose, 3 pattes sur 6, une
quatrième en chemin sur son chariot. 3 grands bras le montent. Derrière, une halle en croissant et ses ailettes ; au sud, la
rampe. Bible (époque 13) : céramique #D9D6CF, cuivre #B0703A, plasma #FF4FD8 (cœur #FF9A3A), luminance 92.
"""
import math

import geo as G
import mat as MT
import outils as O

TAU = G.TAU
PI = math.pi
ZF = 0.42                 # dessus du plancher
CF = (0.0, -0.8)          # centre du plancher et du robot
RF = 4.95
CT = (0.0, 0.2, 8.9)      # centre du tore de plasma
RT = 3.35
ZS = 3.75                 # centre de la sphère du géant
RS = 1.75
RG = 2.5                  # rayon du tore du géant


def matieres(S):
    M = {}
    MT.PATINE.update(ta=0.07, ra=0.08, ec=0.25, nu_k=1.15, ec_col=(0.28, 0.26, 0.23), sans=("noir", "poli"))
    sf = MT.surface
    cr = (0.022, 0.018, 0.014)
    M["cer"] = sf("f13_cer", (0.6, 0.58, 0.53), rough=0.36, met=0.0, tole=(0.95, 0.56), joint=0.62, joint_l=0.009, var=0.035, usure=0.3,
                  nu=(0.78, 0.76, 0.7), crasse=0.7, crasse_col=cr, coulures=0.35, rouille=(0.2, 0.13, 0.08), grain=0.05, relief=0.8, graine=131)
    M["cer2"] = sf("f13_cer2", (0.5, 0.48, 0.44), rough=0.38, met=0.0, tole=(0.6, 0.34), joint=0.62, joint_l=0.009, var=0.05, usure=0.3,
                   nu=(0.72, 0.7, 0.65), crasse=0.7, crasse_col=cr, coulures=0.35, rouille=(0.18, 0.12, 0.08), grain=0.06, relief=0.8, graine=132)
    M["uni"] = sf("f13_uni", (0.63, 0.61, 0.56), rough=0.3, met=0.0, usure=0.25, nu=(0.82, 0.8, 0.75), crasse=0.65, crasse_col=cr, grain=0.04, graine=133)
    M["cuivre"] = sf("f13_cuivre", (0.5, 0.2, 0.06), rough=0.32, met=0.9, usure=0.45, nu=(0.95, 0.62, 0.36), crasse=0.65, crasse_col=cr,
                     coulures=0.3, rouille=(0.1, 0.18, 0.13), grain=0.07, graine=134)
    M["poli"] = sf("f13_poli", (0.68, 0.38, 0.2), rough=0.2, met=1.0, usure=0.0, crasse=0.4, crasse_col=cr, graine=135)
    M["noir"] = sf("f13_noir", (0.018, 0.016, 0.016), rough=0.55, met=0.4, usure=0.25, nu=(0.16, 0.14, 0.12), crasse=0.3, crasse_col=(0.005, 0.004, 0.004), graine=136)
    M["noir_p"] = sf("f13_noir_p", (0.03, 0.026, 0.024), rough=0.5, met=0.4, tole=(0.5, 0.3), joint=0.3, joint_l=0.012, var=0.2, usure=0.3,
                     nu=(0.18, 0.15, 0.13), crasse=0.3, crasse_col=(0.005, 0.004, 0.004), relief=0.7, graine=137)
    M["dalle"] = sf("f13_dalle", (0.38, 0.36, 0.32), rough=0.55, met=0.0, usure=0.35, nu=(0.5, 0.47, 0.42),
                    crasse=0.75, crasse_col=cr, coulures=0.0, relief=0.6, grain=0.08, graine=138)
    M["chevron"] = sf("f13_chevron", (0.6, 0.58, 0.53), rough=0.45, met=0.0, bandes=(0.3, (0.04, 0.032, 0.03), 0.5), usure=0.45, nu=(0.7, 0.68, 0.63),
                      crasse=0.6, crasse_col=cr, grain=0.06, graine=139)
    M["acier"] = sf("f13_acier", (0.18, 0.165, 0.15), rough=0.38, met=0.85, usure=0.5, nu=(0.62, 0.6, 0.55), crasse=0.5, crasse_col=cr, graine=140)
    M["caout"] = sf("f13_caout", (0.022, 0.02, 0.02), rough=0.65, met=0.0, usure=0.2, nu=(0.08, 0.075, 0.07), crasse=0.3, graine=141)
    M["plasma"] = S.mat_emissive("f13_plasma", (1.0, 0.078, 0.69), strength=1.05, base=(0.25, 0.02, 0.17), main_scale=0.95, crust=(3.2, 0.7, 5.0))
    M["coeur"] = S.mat_emissive("f13_coeur", (1.0, 0.26, 0.035), strength=1.25, base=(0.25, 0.08, 0.01), main_scale=0.9, crust=(5.0, 0.4, 7.0))
    M["arc"] = MT.lumiere(S, "f13_arc", (1.0, 0.16, 0.74), 2.6, main=0.9)
    M["voyant"] = MT.lumiere(S, "f13_voyant", (1.0, 0.08, 0.69), 1.5, main=0.8)
    M["ambre"] = MT.lumiere(S, "f13_ambre", (1.0, 0.4, 0.06), 1.7, main=0.8)
    M["rouge"] = MT.lumiere(S, "f13_rouge", (1.0, 0.06, 0.03), 2.5, main=0.6)
    return M


def _tour(lot, M, spine, r0, r1, rnd, bandes=7, cote=1, lame=True):
    """Tour courbe de céramique : fût fuselé sur une courbe, ceintures de cuivre, fentes, conduites qui montent, lame extérieure."""
    pts = G.catmull(spine, 12)
    n = len(pts)
    longs = [0.0]
    for i in range(1, n):
        longs.append(longs[-1] + G.length(G.sub(pts[i], pts[i - 1])))
    L = longs[-1]

    def rr(s, i=None):
        t = s / L
        return r0 + (r1 - r0) * t ** 0.85 + 0.09 * r0 * math.exp(-((t - 0.08) / 0.06) ** 2)
    lot.put(M["cer"], G.tube(pts, r0, 28, rfun=rr))
    fr = G._frames(pts)
    for k in range(bandes):                                              # ceintures
        s = L * (0.06 + 0.9 * k / float(bandes - 1))
        i = min(range(n), key=lambda j: abs(longs[j] - s))
        rc = rr(longs[i])
        lot.put(M["cuivre"], G.oriente(G.tour([(-0.09, rc + 0.004), (-0.07, rc + 0.05), (0.07, rc + 0.05), (0.09, rc + 0.004)], 28, "z"), pts[i], fr[i][0]))
        if k % 2 == 0:
            lot.put(M["noir"], G.oriente(G.tour([(0.1, rc + 0.012), (0.2, rc + 0.012)], 28, "z"), pts[i], fr[i][0]))
    # conduites de cuivre et chemin de câbles le long du fût (côté caméra)
    for (a, rt, m) in ((-2.25, 0.055, M["cuivre"]), (-1.75, 0.04, M["acier"]), (-1.0, 0.075, M["poli"])):
        q = []
        for i in range(3, n - 2):
            t, n1, n2 = fr[i]
            # direction radiale choisie vers le sud (la caméra) à a près
            ref = G.norm(G.sub((math.cos(a), math.sin(a), 0.0), G.mul(t, G.dot((math.cos(a), math.sin(a), 0.0), t))))
            q.append(G.add(pts[i], G.mul(ref, rr(longs[i]) + rt + 0.02)))
        lot.put(m, G.tube(q, rt, 8))
        for i in range(0, len(q), 7):
            lot.put(M["noir"], G.oriente(G.tour([(-0.02, rt * 1.5), (0.02, rt * 1.5)], 8, "z", cap0=True, cap1=True), q[i], fr[i + 3][0]))
    # fentes lumineuses et trappes sur la face sud
    for i in range(6, n - 4, 5):
        t, n1, n2 = fr[i]
        ref = G.norm(G.sub((0.25 * cote, -1.0, 0.0), G.mul(t, G.dot((0.25 * cote, -1.0, 0.0), t))))
        p = G.add(pts[i], G.mul(ref, rr(longs[i]) - 0.01))
        lot.put(M["noir"], O.pose_plane(G.boite((0, 0, 0.01), (0.46 * r0, 0.2, 0.025)), p, ref))
        lot.put(M["voyant"], O.pose_plane(G.boite((0, 0, 0.026), (0.34 * r0, 0.05, 0.012)), p, ref))
    # lame extérieure : aile mince de céramique qui suit la tour
    bl0, bl1 = [], []
    for i in (range(3, n - 5) if lame else ()):
        t, n1, n2 = fr[i]
        ref = G.norm(G.sub((cote, 0.1, 0.0), G.mul(t, G.dot((cote, 0.1, 0.0), t))))
        bl0.append(G.add(pts[i], G.mul(ref, rr(longs[i]) * 0.8)))
        bl1.append(G.add(pts[i], G.mul(ref, rr(longs[i]) + 0.2 * math.sin(PI * (i - 3) / float(n - 8)) ** 0.7 + 0.02)))
    if lame:
        lot.put(M["uni"], G.loft([bl0, bl1], closed=False))
        lot.put(M["cuivre"], G.tube(bl1, 0.035, 6))
    return pts, fr, longs, rr


def _trepied(lot, M, c, z, R, ang, rl=0.2):
    """Trépied (signature de l'âge) : 3 jambes arquées, semelles, sous la tête de la tour : du vide dessous."""
    for k in range(3):
        a = ang + TAU * k / 3.0
        foot = (c[0] + R * math.cos(a), c[1] + R * math.sin(a), ZF)
        head = (c[0] + 0.35 * math.cos(a), c[1] + 0.35 * math.sin(a), z)
        knee = (c[0] + R * 0.82 * math.cos(a), c[1] + R * 0.82 * math.sin(a), z * 0.62)
        pts = G.catmull([head, knee, foot], 8)
        lot.put(M["uni"], G.tube(pts, rl, 16, rfun=lambda s, i: rl * (1.25 - 0.45 * i / float(len(pts)))))
        lot.put(M["cuivre"], G.tour([(ZF, 0.5), (ZF + 0.08, 0.48), (ZF + 0.16, 0.3), (ZF + 0.32, 0.2)], 18, "z", (foot[0], foot[1], 0.0), cap1=True))
        lot.put(M["noir"], G.oriente(G.tour([(-0.05, rl * 1.12), (0.05, rl * 1.12)], 14, "z", cap0=True, cap1=True), knee, G.sub(foot, head)))
    # bulbe de tête
    lot.put(M["cuivre"], G.tour([(z - 0.25, 0.2), (z - 0.05, 0.62), (z + 0.1, 0.72), (z + 0.2, 0.7)], 24, "z", (c[0], c[1], 0.0)))


def _patte(lot, M, a, rh=2.25, rk=3.25, rf=3.7, zh=ZS - 0.55, zk=ZS + 0.15, c=CF, zf=ZF + 0.14):
    """Patte du géant, d'angle a autour de l'axe du robot : hanche sur la sphère, genou haut, tibia effilé, griffe."""
    x0, y0 = c
    e = (math.cos(a), math.sin(a), 0.0)
    hip = (x0 + rh * e[0], y0 + rh * e[1], zh)
    knee = (x0 + rk * e[0], y0 + rk * e[1], zk)
    foot = (x0 + rf * e[0], y0 + rf * e[1], zf)
    d = G.sub(knee, hip)
    Ld = G.length(d)
    lot.put(M["noir"], G.sphere(hip, 0.42, 14, 7))
    O.profil(lot, M["uni"], hip, d, [(0.0, 0.2), (0.14, 0.34), (0.55 * Ld, 0.32), (Ld - 0.15, 0.24), (Ld, 0.18)], 18)
    lot.put(M["cuivre"], G.oriente(G.tour([(-0.05, 0.36), (0.05, 0.36)], 18, "z", cap0=True, cap1=True), G.lerp(hip, knee, 0.45), d))
    lot.put(M["cuivre"], G.sphere(knee, 0.27, 14, 7))
    d = G.sub(foot, knee)
    Ld = G.length(d)
    O.profil(lot, M["cer2"], knee, d, [(0.0, 0.16), (0.14, 0.26), (0.4 * Ld, 0.25), (0.86 * Ld, 0.12), (Ld - 0.08, 0.08), (Ld, 0.0)], 18)
    lot.put(M["noir"], G.oriente(G.tour([(0.55 * Ld, 0.22), (0.62 * Ld, 0.21)], 16, "z"), knee, d))
    lot.put(M["voyant"], G.oriente(G.tour([(0.3 * Ld, 0.265), (0.34 * Ld, 0.265)], 16, "z"), knee, d))
    # griffe au sol
    lot.put(M["noir"], G.tour([(zf - 0.14, 0.44), (zf - 0.06, 0.4), (zf + 0.02, 0.2)], 12, "z", (foot[0], foot[1], 0.0), cap1=True))


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(1313)
    x0, y0 = CF

    # ---------------------------------------------------------------- plancher : dalles, incrustations, plaque d'assemblage, ventre
    lot.put(M["noir"], G.tour([(0.0, RF - 0.4), (0.2, RF - 0.05), (ZF - 0.08, RF)], 96, "z", (x0, y0, 0.0)))
    lot.put(M["uni"], G.tour([(ZF - 0.1, RF), (ZF - 0.03, RF + 0.04), (ZF, RF - 0.03)], 128, "z", (x0, y0, 0.0)))
    lot.put(M["dalle"], G.tour([(ZF, RF - 0.03), (ZF + 0.002, 0.0)], 96, "z", (x0, y0, 0.0)))
    for R in (4.55, 3.0):
        O.anneau(lot, M["cuivre"], (x0, y0, ZF + 0.006), R, 0.035, 128, 5)
    O.anneau(lot, M["voyant"], (x0, y0, ZF + 0.014), 4.42, 0.016, 128, 5)
    for k in range(24):
        a = TAU * (k + 0.5) / 24.0
        lot.put(M["noir"], G.boite((x0 + 3.8 * math.cos(a), y0 + 3.8 * math.sin(a), ZF + 0.006), (0.7, 0.05, 0.015), a))
    for k in range(48):                                                  # joints des dalles du plancher
        a = TAU * k / 48.0
        lot.put(M["noir"], G.boite((x0 + 3.75 * math.cos(a), y0 + 3.75 * math.sin(a), ZF + 0.004), (1.5, 0.018, 0.008), a))
    for R in (3.4, 3.95):
        O.anneau(lot, M["noir"], (x0, y0, ZF + 0.003), R, 0.009, 128, 4)
    lot.put(M["uni"], G.tour([(ZF, 2.72), (ZF + 0.14, 2.7), (ZF + 0.18, 2.5), (ZF + 0.19, 0.0)], 72, "z", (x0, y0, 0.0)))
    for k in range(18):
        a = TAU * k / 18.0
        lot.put(M["noir"], G.boite((x0 + 1.5 * math.cos(a), y0 + 1.5 * math.sin(a), ZF + 0.195), (2.0, 0.016, 0.008), a))
    O.anneau(lot, M["noir"], (x0, y0, ZF + 0.195), 2.15, 0.05, 72, 5)
    for k in range(9):                                                   # griffes de la plaque
        a = TAU * k / 9.0 + 0.2
        lot.put(M["cuivre"], G.boite((x0 + 2.42 * math.cos(a), y0 + 2.42 * math.sin(a), ZF + 0.24), (0.55, 0.3, 0.09), a))

    # ---------------------------------------------------------------- halle en croissant au nord : terrasses et ailettes
    def ell(a, A, B):
        return (x0 + A * math.cos(a), y0 + 0.0 + B * math.sin(a))
    a0, a1 = math.radians(14.0), math.radians(166.0)
    N = 60

    def rg(A, B, z):
        return [(ell(a0 + (a1 - a0) * i / N, A, B)[0], ell(a0 + (a1 - a0) * i / N, A, B)[1], z) for i in range(N + 1)]
    lot.put(M["cer"], G.loft([rg(5.42, 8.5, 0.0), rg(5.42, 8.5, 1.5)], closed=False))
    lot.put(M["cer2"], G.loft([rg(5.42, 8.5, 1.5), rg(5.0, 7.6, 2.0)], closed=False))
    lot.put(M["noir_p"], G.loft([rg(5.0, 7.6, 2.0), rg(4.72, 7.0, 2.0)], closed=False))
    lot.put(M["cer"], G.loft([rg(4.72, 7.0, 2.0), rg(4.72, 7.0, 3.1)], closed=False))
    lot.put(M["cer2"], G.loft([rg(4.72, 7.0, 3.1), rg(4.35, 6.25, 3.25)], closed=False))
    lot.put(M["cer"], G.loft([rg(4.35, 6.25, ZF), rg(4.35, 6.25, 3.25)], closed=False))
    # baies noires et voyants sur la paroi intérieure, côtes de cuivre
    for k in range(13):
        a = a0 + (a1 - a0) * (k + 0.5) / 13.0
        p = ell(a, 4.32, 6.2)
        n = G.norm((-math.cos(a) * 1.6, -math.sin(a), 0.0))
        lot.put(M["noir"], O.pose_plane(G.boite((0, 0, 0.012), (0.62, 1.5, 0.03)), (p[0], p[1], ZF + 1.45), n))
        lot.put(M["voyant"] if k % 3 else M["ambre"], O.pose_plane(G.boite((0, 0.3, 0.03), (0.4, 0.06, 0.012)), (p[0], p[1], ZF + 1.45), n))
        for j in range(3):
            lot.put(M["acier"], O.pose_plane(G.boite((0, -0.45 + 0.28 * j, 0.03), (0.46, 0.05, 0.015)), (p[0], p[1], ZF + 1.45), n))
    for k in range(14):
        a = a0 + (a1 - a0) * k / 13.0
        rib = [(*ell(a, 4.3, 6.18), ZF), (*ell(a, 4.3, 6.18), 3.26), (*ell(a, 4.72, 7.0), 3.14), (*ell(a, 4.72, 7.0), 2.02), (*ell(a, 5.0, 7.6), 2.02), (*ell(a, 5.44, 8.5), 1.5), (*ell(a, 5.44, 8.5), 0.0)]
        lot.put(M["cuivre"], G.tube(rib, 0.05, 6))
    # ailettes radiantes sur le croissant : silhouette au nord, derrière le tore
    for k in range(11):
        a = math.radians(30.0) + math.radians(120.0) * k / 10.0
        p = ell(a, 4.95, 7.45)
        h = 1.65 + 0.55 * math.sin(k * 1.9) + (0.6 if k in (3, 4) else 0.0)
        ang = a
        h = h * 0.72
        ca, sa = math.cos(ang + PI / 2), math.sin(ang + PI / 2)
        for s in (-0.42, 0.42):
            lot.put(M["noir"], G.boite((p[0] + s * ca, p[1] + s * sa, 3.25 + h / 2.0), (0.06, 0.1, h), ang + PI / 2))
        for j in range(int(h / 0.13)):
            lot.put(M["cuivre"] if j % 3 == 0 else M["acier"], G.boite((p[0], p[1], 3.32 + 0.13 * j), (0.84, 0.14, 0.05), ang + PI / 2, 0.45))
        lot.put(M["noir"], G.boite((p[0], p[1], 3.25 + h + 0.03), (0.92, 0.12, 0.05), ang + PI / 2))
    # 4 injecteurs sur la terrasse : ampoules de cuivre, conduites vers les tours
    for (a, h) in ((math.radians(52.0), 1.2), (math.radians(78.0), 0.95), (math.radians(105.0), 1.1), (math.radians(130.0), 0.85)):
        p = ell(a, 4.55, 6.65)
        O.profil(lot, M["cuivre"], (p[0], p[1], 3.2), (0, 0, 1), [(0.0, 0.32), (0.08, 0.3), (0.2, 0.2), (h, 0.16), (h + 0.15, 0.1), (h + 0.3, 0.0)], 16)
        lot.put(M["uni"], G.tour([(3.2 + 0.45, 0.22), (3.2 + 0.55, 0.22)], 16, "z", (p[0], p[1], 0.0)))
        lot.put(M["voyant"], G.tour([(3.2 + h - 0.1, 0.17), (3.2 + h - 0.05, 0.165)], 16, "z", (p[0], p[1], 0.0)))

    # ---------------------------------------------------------------- 2 tours inégales, décalées en diagonale, sur trépieds
    wc = (-4.0, 2.25)
    _trepied(lot, M, wc, 2.5, 1.32, 0.6, rl=0.28)
    w_spine = [(wc[0], wc[1], 2.2), (wc[0] - 0.42, wc[1] - 0.05, 4.1), (-4.3, 1.8, 6.4), (-3.72, 1.12, 8.25), (-3.28, 0.9, 8.9)]
    wp, wf, wl, wr = _tour(lot, M, w_spine, 1.0, 0.44, r, bandes=8, cote=-1)
    ec = (4.05, -2.2)
    _trepied(lot, M, ec, 1.9, 1.05, 2.7, rl=0.22)
    e_spine = [(ec[0], ec[1], 1.7), (ec[0] + 0.48, ec[1] + 0.1, 3.6), (4.32, -1.85, 5.8), (3.72, -1.25, 7.9), (3.22, -0.95, 8.9)]
    ep, ef, el, er = _tour(lot, M, e_spine, 0.74, 0.36, r, bandes=6, cote=1, lame=False)
    # sphère de confinement accrochée au flanc ouest de la grande tour
    sc = (-4.85, 3.45, 4.8)
    Rc = 1.15
    lot.put(M["uni"], G.sphere(sc, Rc, 40, 20))
    for t in (-0.55, 0.62, 1.05):
        O.anneau(lot, M["acier"], (sc[0], sc[1], sc[2] + Rc * math.sin(t)), Rc * math.cos(t) + 0.004, 0.012, 56, 4)
    lot.put(M["cuivre"], G.tour([(sc[2] - 0.08, Rc + 0.002), (sc[2] - 0.05, Rc + 0.06), (sc[2] + 0.05, Rc + 0.06), (sc[2] + 0.08, Rc + 0.002)], 40, "z", (sc[0], sc[1], 0.0)))
    O.anneau(lot, M["plasma"], (sc[0], sc[1], sc[2] + 0.12), Rc * 0.99, 0.05, 56, 6)
    for (a, e) in ((-1.1, 0.55), (-1.75, 0.55), (-2.4, 0.55)):
        n = (math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))
        O.hublot(lot, M["cuivre"], M["coeur"], G.add(sc, G.mul(n, Rc)), n, 0.13)
    O.tuyau(lot, M["poli"], M["cuivre"], [(sc[0] + 0.3, sc[1] - 1.1, sc[2] - 0.4), (-4.35, 1.85, sc[2] - 0.6)], 0.12)
    lot.put(M["cuivre"], G.tube([(sc[0] + 0.6, sc[1] - 0.45, sc[2]), (-4.45, 2.2, 5.05)], 0.2, 16))
    # 3 pieds sous la sphère de confinement
    for a in (0.2, 2.3, 4.4):
        lot.put(M["uni"], G.tube([(sc[0] + 0.6 * math.cos(a), sc[1] + 0.6 * math.sin(a), sc[2] - 0.9), (sc[0] + 0.72 * math.cos(a), min(7.2, sc[1] + 1.3 * math.sin(a)), 3.2)], 0.09, 10))

    # ---------------------------------------------------------------- le tore de plasma, en l'air
    lot.xf = None
    O.anneau(lot, M["plasma"], CT, RT, 0.31, 128, 16)
    O.anneau(lot, M["coeur"], CT, RT - 0.2, 0.15, 128, 10)
    nb = 16
    for k in range(nb):
        a = TAU * k / nb
        da = 0.1
        O.anneau(lot, M["cer"], CT, RT, 0.43, 14, 18, a - da, a + da)
        for s in (-1, 1):
            O.anneau(lot, M["cuivre"], CT, RT, 0.47, 3, 18, a + s * da - 0.025, a + s * da + 0.025)
        p = (CT[0] + (RT + 0.42) * math.cos(a), CT[1] + (RT + 0.42) * math.sin(a), CT[2])
        lot.put(M["noir"], G.boite((p[0], p[1], p[2]), (0.1, 0.34, 0.28), a))
        if k % 2 == 0:
            q = (CT[0] + RT * math.cos(a), CT[1] + RT * math.sin(a), CT[2] + 0.42)
            O.profil(lot, M["cuivre"], q, (0, 0, 1), [(0.0, 0.14), (0.06, 0.12), (0.34, 0.08), (0.42, 0.11), (0.48, 0.0)], 12)
    O.anneau(lot, M["acier"], CT, RT + 0.62, 0.04, 128, 6)              # couronne de maintien
    for k in range(nb):
        a = TAU * (k + 0.5) / nb
        lot.put(M["acier"], G.tube([(CT[0] + (RT + 0.47) * math.cos(a), CT[1] + (RT + 0.47) * math.sin(a), CT[2]),
                                    (CT[0] + (RT + 0.62) * math.cos(a), CT[1] + (RT + 0.62) * math.sin(a), CT[2])], 0.02, 5))
    # flèche d'injection, au-dessus de la grande tour
    wt = w_spine[-1]
    O.profil(lot, M["uni"], (wt[0], wt[1], wt[2] - 0.1), (0, 0, 1), [(0.0, 0.56), (0.25, 0.58), (0.5, 0.36), (1.3, 0.14), (1.9, 0.03), (1.95, 0.0)], 20)
    lot.put(M["cuivre"], G.tour([(wt[2] + 0.38, 0.48), (wt[2] + 0.45, 0.42)], 20, "z", (wt[0], wt[1], 0.0)))
    lot.put(M["rouge"], G.sphere((wt[0], wt[1], wt[2] + 1.87), 0.05, 6, 3))
    et = e_spine[-1]
    O.profil(lot, M["uni"], (et[0], et[1], et[2] - 0.1), (0, 0, 1), [(0.0, 0.48), (0.2, 0.5), (0.42, 0.3), (0.72, 0.1), (0.78, 0.0)], 18)

    # ---------------------------------------------------------------- le géant en cours de montage
    cz = (x0, y0, ZS)
    # berceau central : colonne et 3 étais
    lot.put(M["noir"], G.tour([(ZF + 0.18, 0.92), (ZF + 0.4, 0.68), (ZS - RS + 0.1, 0.56)], 24, "z", (x0, y0, 0.0)))
    lot.put(M["poli"], G.tour([(ZF + 0.6, 0.46), (ZS - RS + 0.15, 0.46)], 20, "z", (x0, y0, 0.0)))
    for a in (-2.45, -0.5, 1.5):
        lot.put(M["cuivre"], G.tube([(x0 + 1.5 * math.cos(a), y0 + 1.5 * math.sin(a), ZF + 0.2), (x0 + 0.85 * math.cos(a), y0 + 0.85 * math.sin(a), ZS - RS + 0.2)], 0.1, 12))
    # moitié basse bardée
    def Ps(az, el, g=0.0):
        rr = (RS + g) * math.cos(el)
        return (x0 + rr * math.cos(az), y0 + rr * math.sin(az), ZS + (RS + g) * math.sin(el))
    bas = [[Ps(TAU * j / 48.0, -PI / 2 + (PI / 2 + 0.02) * i / 10.0) for j in range(49)] for i in range(11)]
    lot.put(M["cer2"], G.loft(bas, closed=False))
    # intérieur noir de la moitié haute, cœur nu dans sa cage
    haut_int = [[Ps(math.radians(25.0) + math.radians(205.0) * j / 40.0, 0.0 + 1.5 * i / 8.0, -0.2) for j in range(41)] for i in range(9)]
    lot.put(M["noir_p"], G.tour([(ZS + 0.01, RS - 0.02), (ZS + 0.02, 0.0)], 48, "z", (x0, y0, 0.0)))
    lot.put(M["noir_p"], G.loft(haut_int, closed=False))
    lot.put(M["coeur"], G.sphere((x0 + 0.1, y0 - 0.45, ZS + 0.5), 0.78, 28, 14))
    # ouverture : la peau noire s'efface devant le cœur vu de la caméra
    for k in range(5):
        O.anneau(lot, M["cuivre"], (x0 + 0.1, y0 - 0.45, ZS + 0.5), 0.86, 0.03, 40, 5, n=(math.cos(k * 0.63), math.sin(k * 0.63), 0.15))
    # meridiens de la moitié haute et plaques posées à l'ouest et au nord (quartier est-sud ouvert)
    for k in range(14):
        az = TAU * k / 14.0
        pts = [Ps(az, 0.0 + (PI / 2 - 0.12) * i / 12.0, 0.02) for i in range(13)]
        lot.put(M["uni"], G.tube(pts, 0.05, 6))
    for e in (0.42, 0.82, 1.2):
        rr = RS * math.cos(e)
        O.anneau(lot, M["uni"], (x0, y0, ZS + RS * math.sin(e)), rr + 0.02, 0.035, 60, 6)
    # plaques : azimut de 40° (nord-est) à 215° (ouest-sud-ouest), elles laissent le quart sud-est ouvert, sur le cœur
    for (e0, e1) in ((0.02, 0.42), (0.42, 0.82), (0.82, 1.2), (1.2, 1.45)):
        n_pl = int(max(4, 12 * math.cos(e0)))
        azs = [math.radians(35.0) + math.radians(185.0) * j / n_pl for j in range(n_pl + 1)]
        for j in range(n_pl):
            if r.f() < 0.1 and e0 > 0.3:
                continue
            a0p, a1p = azs[j] + 0.012, azs[j + 1] - 0.012
            rows = [[Ps(a0p + (a1p - a0p) * u / 6.0, e0 + 0.012 + (e1 - e0 - 0.024) * v / 4.0, 0.05) for u in range(7)] for v in range(5)]
            lot.put(M["cer"] if r.f() < 0.75 else M["cer2"], G.loft(rows, closed=False))
    lot.put(M["uni"], G.tour([(ZS + RS - 0.16, 0.52), (ZS + RS + 0.0, 0.48), (ZS + RS + 0.1, 0.28), (ZS + RS + 0.14, 0.0)], 24, "z", (x0, y0, 0.0)))
    # ceinture et tore du géant : 210° posés, le reste n'est qu'un cerceau d'échafaudage
    lot.put(M["noir"], G.tour([(ZS - 0.2, RS + 0.02), (ZS - 0.15, RS + 0.1), (ZS + 0.15, RS + 0.1), (ZS + 0.2, RS + 0.02)], 48, "z", (x0, y0, 0.0)))
    lot.put(M["cuivre"], G.tour([(ZS - 0.26, RS - 0.03), (ZS - 0.2, RS + 0.05)], 48, "z", (x0, y0, 0.0)))
    for k in range(6):
        a = TAU * (k + 0.5) / 6.0
        lot.put(M["uni"], G.tube([Ps(a, 0.0, 0.08), (x0 + (RG - 0.22) * math.cos(a), y0 + (RG - 0.22) * math.sin(a), ZS)], 0.08, 8))
    tz = (x0, y0, ZS)
    a0t, a1t = math.radians(75.0), math.radians(285.0)
    nt = 11
    O.anneau(lot, M["plasma"], tz, RG, 0.17, 80, 12, a0t, a1t)
    for k in range(nt):
        a = a0t + (a1t - a0t) * (k + 0.5) / nt
        da = (a1t - a0t) / nt * 0.38
        O.anneau(lot, M["cer"], tz, RG, 0.31, 8, 14, a - da, a + da)
        for s in (-1, 1):
            O.anneau(lot, M["cuivre"], tz, RG, 0.34, 2, 14, a + s * da - 0.02, a + s * da + 0.02)
    O.anneau(lot, M["acier"], tz, RG, 0.04, 60, 6, a1t, a0t + TAU)        # cerceau : la partie à poser
    for a in (a1t, a0t + TAU):
        lot.put(M["noir"], G.oriente(G.tour([(-0.05, 0.3), (0.05, 0.3)], 14, "z", cap0=True, cap1=True),
                                     (x0 + RG * math.cos(a), y0 + RG * math.sin(a), ZS), (-math.sin(a), math.cos(a), 0.0)))
    # 3 pattes posées sur 6, 3 moyeux vides
    for a in (math.radians(205.0), math.radians(325.0), math.radians(90.0)):
        _patte(lot, M, a)
    for a in (math.radians(265.0), math.radians(30.0), math.radians(150.0)):
        hp = (x0 + 1.88 * math.cos(a), y0 + 1.88 * math.sin(a), ZS - 0.55)
        lot.put(M["noir"], G.oriente(G.tour([(0.0, 0.3), (0.1, 0.34), (0.2, 0.2), (0.19, 0.0)], 14, "z"), hp, (math.cos(a), math.sin(a), -0.2)))
    # arcs entre le tore de plasma et le cœur (zigzags déterministes)
    ra = G.Rnd(1377)
    co = (x0 + 0.1, y0 - 0.45, ZS + 0.5)
    for (a, rt, n) in ((-1.1, 0.03, 9), (-0.55, 0.022, 8), (-1.7, 0.026, 9), (-2.3, 0.018, 7), (-0.1, 0.018, 7)):
        p0 = (CT[0] + (RT - 0.3) * math.cos(a), CT[1] + (RT - 0.3) * math.sin(a), CT[2] - 0.3)
        pts = [p0]
        for i in range(1, n):
            t = i / float(n)
            q = G.lerp(p0, co, t)
            w = 0.34 * math.sin(PI * t)
            pts.append((q[0] + ra.f(-w, w), q[1] + ra.f(-w, w), q[2] + ra.f(-0.1, 0.1)))
        pts.append(G.add(co, (0.0, 0.0, 0.5)))
        lot.put(M["arc"], G.tube(pts, rt, 5))

    # ---------------------------------------------------------------- 3 grands bras de montage
    O.bras(lot, M["acier"], M["cuivre"], M["caout"], (-4.45, 2.0, 3.95), (-4.2, 1.6, 4.25), (-3.35, -0.75, 7.1), (-1.7, -1.55, 6.8), (-0.75, -1.6, 5.75), r=0.36, socle=0.6,
           lum=M["coeur"], riv=M["noir"])
    O.bras(lot, M["acier"], M["cuivre"], M["caout"], (4.55, -2.35, 3.55), (4.1, -2.85, 3.85), (3.3, -4.25, 5.6), (2.72, -3.55, 4.35), (2.25, -3.18, 3.82), r=0.3, socle=0.5,
           lum=None, riv=M["noir"])
    # le bras est présente le segment suivant du tore du géant
    a_s = math.radians(305.0)
    O.anneau(lot, M["cer"], (x0, y0 - 0.05, ZS + 0.05), RG + 0.04, 0.31, 8, 14, a_s - 0.24, a_s + 0.24)
    for s in (-1, 1):
        O.anneau(lot, M["cuivre"], (x0, y0 - 0.05, ZS + 0.05), RG + 0.04, 0.34, 2, 14, a_s + s * 0.24 - 0.02, a_s + s * 0.24 + 0.02)
    O.bras(lot, M["acier"], M["cuivre"], M["caout"], (-3.1, -4.15, ZF), (-3.1, -4.15, ZF + 0.9), (-4.05, -3.55, 3.55), (-2.95, -2.95, 4.75), (-1.55, -2.4, 3.95), r=0.28, socle=0.62,
           lum=M["coeur"], riv=M["noir"])
    for (a, b) in (((-3.1, -4.15, ZF + 0.02), (-1.55, -3.2, ZF + 0.2)), ((-0.1, -3.6, ZF + 0.2), (1.0, -3.42, ZF + 0.02))):
        O.flexible(lot, M["caout"], [a, G.add(G.lerp(a, b, 0.5), (0, -0.1, 0.05)), b], 0.05)

    # ---------------------------------------------------------------- rampe au sud, rails, chariot avec la patte suivante
    rx0, rx1 = -1.75, 3.15
    yr0, yr1 = y0 - RF + 0.28, -7.72
    q = [(rx0, yr0, ZF + 0.01), (rx1, yr0, ZF + 0.01), (rx1, yr1, 0.02), (rx0, yr1, 0.02)]
    lot.put(M["dalle"], G.loft([[q[3], q[2]], [q[0], q[1]]], closed=False))
    for k in range(14):
        t = (k + 0.5) / 14.0
        a, b = G.lerp(q[0], q[3], t), G.lerp(q[1], q[2], t)
        lot.put(M["noir"], G.tube([G.add(G.lerp(a, b, 0.13), (0, 0, 0.015)), G.add(G.lerp(a, b, 0.87), (0, 0, 0.015))], 0.024, 5))
    for u0, u1 in ((0.0, 0.1), (0.9, 1.0)):
        a, b, c, d = G.lerp(q[0], q[1], u0), G.lerp(q[0], q[1], u1), G.lerp(q[3], q[2], u1), G.lerp(q[3], q[2], u0)
        lot.put(M["chevron"], G.loft([[G.add(d, (0, 0, 0.015)), G.add(c, (0, 0, 0.015))], [G.add(a, (0, 0, 0.015)), G.add(b, (0, 0, 0.015))]], closed=False))
    for (s, x) in ((-1, rx0), (1, rx1)):
        rg_ = [[(x, yr0 + 0.25, ZF + 0.3), (x + s * 0.38, yr0 + 0.25, ZF + 0.3), (x + s * 0.46, yr0 + 0.25, 0.0)],
               [(x, yr1 - 0.05, 0.12), (x + s * 0.34, yr1 - 0.05, 0.12), (x + s * 0.42, yr1 - 0.05, 0.0)]]
        lot.put(M["uni"], G.loft(rg_, closed=False))
        lot.put(M["voyant"], G.tube([(x + s * 0.18, yr0 + 0.25, ZF + 0.32), (x + s * 0.18, yr1 - 0.02, 0.14)], 0.022, 6))
    for (x, h) in ((rx0 - 0.25, 1.35), (rx1 + 0.25, 0.85)):               # 2 bornes de porte, inégales
        O.profil(lot, M["uni"], (x, yr0 + 0.25, 0.3), (0, 0, 1), [(0.0, 0.45), (0.3, 0.42), (0.55, 0.3), (h, 0.27), (h + 0.06, 0.2), (h + 0.42, 0.1), (h + 0.44, 0.0)], 20)
        lot.put(M["cuivre"], G.tour([(0.3 + h - 0.25, 0.2), (0.3 + h - 0.12, 0.19)], 18, "z", (x, yr0 + 0.25, 0.0)))
        lot.put(M["ambre"], G.sphere((x, yr0 + 0.25, 0.3 + h + 0.38), 0.06, 8, 4))
    # voie sur la plaque, de la rampe au robot, et chariot
    for x in (0.2, 1.2):
        lot.put(M["acier"], G.boite((x, -4.9, ZF + 0.04), (0.08, 3.1, 0.06)))
    cx, cy = 0.7, -5.05
    lot.put(M["acier"], G.boite((cx, cy, ZF + 0.28), (1.5, 2.3, 0.14)))
    lot.put(M["cuivre"], G.boite((cx, cy - 1.14, ZF + 0.28), (1.54, 0.05, 0.16)))
    for dx in (-0.5, 0.5):
        for dy in (-0.8, 0.8):
            lot.put(M["acier"], G.tour([(-0.1, 0.17), (0.1, 0.17)], 14, "x", (cx + dx, cy + dy, ZF + 0.17), cap0=True, cap1=True))
    # la patte couchée sur le chariot
    hip = (cx - 0.5, cy + 0.85, ZF + 0.7)
    knee = (cx + 0.48, cy + 0.1, ZF + 0.86)
    foot = (cx - 0.28, cy - 1.15, ZF + 0.48)
    lot.put(M["noir"], G.sphere(hip, 0.32, 12, 6))
    d = G.sub(knee, hip)
    O.profil(lot, M["uni"], hip, d, [(0.0, 0.16), (0.1, 0.28), (0.6, 0.26), (G.length(d), 0.15)], 16)
    lot.put(M["cuivre"], G.sphere(knee, 0.22, 12, 6))
    d = G.sub(foot, knee)
    O.profil(lot, M["cer2"], knee, d, [(0.0, 0.14), (0.15, 0.22), (0.7, 0.14), (G.length(d), 0.03)], 16)
    for (y, h) in ((cy + 0.6, 0.3), (cy - 0.5, 0.4)):
        lot.put(M["cuivre"], G.boite((cx, y, ZF + 0.35 + h / 2.0), (0.86, 0.12, h)))

    # ---------------------------------------------------------------- réservoirs d'hélium 3 au sud-ouest (3 sphères sur trépieds)
    for (x, y, R, z) in ((-4.05, -6.05, 0.82, 1.25), (-2.72, -6.75, 0.56, 0.92), (-4.72, -4.65, 0.42, 0.8)):
        lot.put(M["uni"], G.sphere((x, y, z), R, 28, 14))
        lot.put(M["cuivre"], G.tour([(z - 0.03, R + 0.002), (z - 0.01, R + 0.03), (z + 0.01, R + 0.03), (z + 0.03, R + 0.002)], 28, "z", (x, y, 0.0)))
        for k in range(3):
            a = TAU * k / 3.0 + 0.5
            lot.put(M["uni"], G.tube([(x + R * 0.6 * math.cos(a), y + R * 0.6 * math.sin(a), z - R * 0.6), (x + R * 1.05 * math.cos(a), y + R * 1.05 * math.sin(a), 0.0)], 0.05, 8))
        lot.put(M["voyant"], G.sphere((x + R * 0.5, y - R * 0.7, z + R * 0.5), 0.04, 6, 3))
        lot.put(M["poli"], G.tour([(z + R - 0.04, 0.12), (z + R + 0.1, 0.08), (z + R + 0.14, 0.0)], 12, "z", (x, y, 0.0)))
    O.tuyau(lot, M["poli"], M["cuivre"], [(-3.5, -5.5, 0.55), (-3.5, -4.9, 0.55), (-3.5, -4.9, ZF + 0.08)], 0.07)
    O.tuyau(lot, M["poli"], M["cuivre"], [(-2.72, -6.2, 0.4), (-2.72, -5.65, 0.25), (-3.4, -5.65, 0.25)], 0.05)
    # blocs techniques au sud-est : baie de commande à fente magenta, caisses de segments
    lot.put(M["uni"], G.prisme([(3.95, -7.5), (5.4, -7.5), (5.45, -5.6), (3.95, -5.6)], 0.0, 1.0, 0.96))
    for k in range(4):
        lot.put(M["noir"], G.boite((4.7, -7.2 + 0.42 * k, 1.005), (1.3, 0.02, 0.01)))
    lot.put(M["noir"], G.boite((4.7, -7.5, 0.56), (1.1, 0.03, 0.5)))
    lot.put(M["voyant"], G.boite((4.7, -7.52, 0.68), (0.85, 0.012, 0.05)))
    for (dx, dy, h) in ((-0.4, -0.3, 0.42), (0.1, 0.25, 0.6), (0.48, -0.25, 0.3)):
        O.profil(lot, M["cuivre"], (4.7 + dx, -6.55 + dy, 1.0), (0, 0, 1), [(0.0, 0.22), (0.06, 0.2), (h, 0.14), (h + 0.08, 0.0)], 14)
    lot.put(M["acier"], G.boite((4.5, -5.0, 0.55), (0.9, 0.7, 0.3), 0.15))
    # mât de signalisation au nord-ouest
    lot.put(M["uni"], G.tour([(0.0, 0.4), (0.2, 0.3), (4.2, 0.06), (5.3, 0.015)], 12, "z", (-5.15, 6.0, 0.0)))
    lot.put(M["rouge"], G.sphere((-5.15, 6.0, 5.32), 0.05, 6, 3))
    # menus détails sur le plancher : regards, caissons, câbles
    ru = G.Rnd(1391)
    mats = [M["acier"], M["noir"], M["uni"], M["cuivre"]]
    for (a, b, rt) in (((-2.2, 4.6, 0.4), (-3.2, 3.1, 0.55), 0.09), ((2.6, 4.6, 0.4), (3.7, -0.4, 0.55), 0.11), ((1.0, 5.0, 0.4), (3.3, 1.6, 0.55), 0.07)):
        O.tuyau(lot, M["poli"], M["cuivre"], [a, G.add(G.lerp(a, b, 0.5), (0.0, 0.0, 0.12)), b], rt, rb=0.3, pas_bride=0.9)
    for (a, b) in (((-3.2, 0.2, ZF + 0.03), (-1.9, 0.4, ZF + 0.2)), ((3.4, -0.2, ZF + 0.03), (2.0, -0.1, ZF + 0.2)), ((-0.2, 3.2, ZF + 0.03), (-0.1, 1.9, ZF + 0.2))):
        for dy in (-0.09, 0.09):
            O.flexible(lot, M["caout"], [G.add(a, (0, dy, 0)), G.add(G.lerp(a, b, 0.5), (0, dy, 0.1)), G.add(b, (0, dy, 0))], 0.035)
    for k in range(150):
        a, d = ru.f(0.0, TAU), ru.f(3.05, 4.8)
        p = (x0 + d * math.cos(a), y0 + d * math.sin(a))
        if abs(p[0] - 0.7) < 1.1 and p[1] < -2.5 and p[1] > -7.0:
            continue
        lot.put(mats[k % 4], G.boite((p[0], p[1], ZF + 0.03), (ru.f(0.1, 0.34), ru.f(0.08, 0.26), ru.f(0.03, 0.14)), ru.f(0.0, 3.0)))
    return {"tore": CT}
