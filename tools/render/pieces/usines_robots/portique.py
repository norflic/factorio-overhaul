"""PORTIQUE (fo-robot-gantry), âge 13 · Fusion, emprise 11×11 (x ±5,5 ; y ±7,78). PLAN ROBOTS §5 bis, refait après la critique du
1/11 (« anneau dressé sur disque blanc » : trop proche d'un portail d'une autre licence).

Lecture : une CALE DE CHANTIER ouverte, pas un anneau. Dalle octogonale de métal sombre filetée de cuivre ; 2 chemins de roulement
nord-sud sur colonnes de céramique à trépieds ; 2 ponts roulants qui passent au-dessus du vide. Sous eux, le géant prend forme : sphère
du Torique à moitié bardée, cœur nu, tore en cours de pose, 3 pattes sur 6, une quatrième pendue au pont arrière, une autre sur son
chariot. Le TORE DE PLASMA est COUCHÉ au ras de la dalle, ouvert au sud pour laisser sortir le géant, ses bobines ne laissant voir que des
fentes ; des arcs courts montent de lui au cœur. Derrière, la halle droite et ses radiateurs ; au sud, la rampe en gris sale.
Bible (époque 13) : céramique #D9D6CF, cuivre #B0703A, plasma #FF4FD8 (cœur #FF9A3A), luminance 92. Aucune émission sans dégradé.
"""
import math

import geo as G
import mat as MT
import outils as O

TAU = G.TAU
PI = math.pi
ZF = 0.42                 # dessus de la dalle
CF = (0.0, -0.8)          # centre du robot
TC = (0.0, -0.8, 1.28)    # centre du tore couché
RT = 3.85
GAP = (math.radians(305.0), math.radians(617.0))   # arc du tore : ouvert au sud, vers la rampe
ZS = 3.3                  # centre de la sphère du géant
RS = 1.6
RG = 2.3                  # rayon du tore du géant
ZR = 6.9                  # hauteur des chemins de roulement
XR = 4.25
PSI = math.radians(9.0)   # la charpente, le géant et les bras sont tournés : trois-quarts, pas de face


def matieres(S):
    M = {}
    MT.PATINE.update(ta=0.12, ra=0.18, ec=0.45, nu_k=1.2, ec_col=(0.1, 0.075, 0.055), sans=("noir", "poli"))
    sf = MT.surface
    cr = (0.018, 0.014, 0.011)
    M["cer"] = sf("f13_cer", (0.56, 0.54, 0.49), rough=0.38, met=0.0, tole=(0.95, 0.56), joint=0.5, joint_l=0.01, var=0.05, usure=0.35,
                  nu=(0.72, 0.7, 0.65), crasse=0.8, crasse_col=cr, coulures=0.65, rouille=(0.13, 0.085, 0.055), pied=(0.4, 2.2, 0.5), grain=0.07, relief=0.8, graine=131)
    M["cer2"] = sf("f13_cer2", (0.44, 0.42, 0.38), rough=0.4, met=0.0, tole=(0.6, 0.34), joint=0.5, joint_l=0.01, var=0.06, usure=0.35,
                   nu=(0.68, 0.66, 0.6), crasse=0.8, crasse_col=cr, coulures=0.6, rouille=(0.12, 0.08, 0.05), grain=0.08, relief=0.8, graine=132)
    M["uni"] = sf("f13_uni", (0.56, 0.54, 0.5), rough=0.34, met=0.0, usure=0.3, nu=(0.75, 0.73, 0.68), crasse=0.75, crasse_col=cr, coulures=0.5,
                  rouille=(0.13, 0.085, 0.055), grain=0.06, graine=133)
    M["cuivre"] = sf("f13_cuivre", (0.46, 0.2, 0.065), rough=0.36, met=0.8, usure=0.5, nu=(0.9, 0.58, 0.34), crasse=0.75, crasse_col=cr,
                     coulures=0.45, rouille=(0.08, 0.16, 0.11), grain=0.08, graine=134)
    M["cuivre_s"] = sf("f13_cuivre_s", (0.2, 0.085, 0.032), rough=0.45, met=0.7, usure=0.7, nu=(0.75, 0.46, 0.27), crasse=0.8, crasse_col=cr,
                       coulures=0.5, rouille=(0.05, 0.11, 0.08), grain=0.1, graine=142)
    M["poli"] = sf("f13_poli", (0.6, 0.34, 0.18), rough=0.24, met=1.0, usure=0.0, crasse=0.5, crasse_col=cr, graine=135)
    M["noir"] = sf("f13_noir", (0.018, 0.016, 0.016), rough=0.55, met=0.4, usure=0.3, nu=(0.18, 0.16, 0.14), crasse=0.3, crasse_col=(0.005, 0.004, 0.004), graine=136)
    M["noir_p"] = sf("f13_noir_p", (0.03, 0.026, 0.024), rough=0.5, met=0.4, tole=(0.5, 0.3), joint=0.3, joint_l=0.012, var=0.2, usure=0.3,
                     nu=(0.18, 0.15, 0.13), crasse=0.3, crasse_col=(0.005, 0.004, 0.004), relief=0.7, graine=137)
    M["dalle"] = sf("f13_dalle", (0.085, 0.076, 0.068), rough=0.55, met=0.45, tole=(1.45, 0.72), joint=0.35, joint_l=0.008, var=0.2, usure=0.6, nu=(0.36, 0.32, 0.27),
                    crasse=0.8, crasse_col=cr, coulures=0.0, relief=0.6, grain=0.14, graine=138)
    M["plaque"] = sf("f13_plaque", (0.135, 0.12, 0.105), rough=0.5, met=0.5, usure=0.55, nu=(0.42, 0.37, 0.31), crasse=0.8, crasse_col=cr, grain=0.13, graine=143)
    M["joue"] = sf("f13_joue", (0.12, 0.105, 0.09), rough=0.85, met=0.1, usure=0.5, nu=(0.3, 0.27, 0.22), crasse=0.85, crasse_col=cr, grain=0.18, graine=145)
    M["rampe"] = sf("f13_rampe", (0.2, 0.185, 0.165), rough=0.8, met=0.15, tole=(1.2, 0.5), joint=0.4, joint_l=0.009, var=0.14, usure=0.5, nu=(0.36, 0.34, 0.3),
                    crasse=0.85, crasse_col=cr, coulures=0.0, relief=0.5, grain=0.18, graine=144)
    M["chevron"] = sf("f13_chevron", (0.27, 0.2, 0.09), rough=0.6, met=0.1, bandes=(0.3, (0.03, 0.026, 0.024), 0.5), usure=0.6, nu=(0.42, 0.38, 0.32),
                      crasse=0.8, crasse_col=cr, grain=0.14, graine=139)
    M["acier"] = sf("f13_acier", (0.17, 0.155, 0.14), rough=0.4, met=0.8, usure=0.55, nu=(0.6, 0.57, 0.52), crasse=0.6, crasse_col=cr, coulures=0.3, graine=140)
    M["caout"] = sf("f13_caout", (0.022, 0.02, 0.02), rough=0.65, met=0.0, usure=0.2, nu=(0.08, 0.075, 0.07), crasse=0.3, graine=141)
    M["plasma"] = MT.degrade(S, "f13_plasma", (1.0, 0.26, 0.72), (0.42, 0.006, 0.24), 0.72, main=0.88, crust=(3.2, 0.6, 5.0))
    M["coeur"] = MT.degrade(S, "f13_coeur", (1.0, 0.48, 0.1), (0.5, 0.05, 0.008), 1.25, main=0.9, crust=(5.0, 0.45, 7.0))
    M["arc"] = MT.degrade(S, "f13_arc", (1.0, 0.3, 0.78), (0.5, 0.015, 0.34), 0.7, main=0.88, crust=(12.0, 0.5, 9.0))
    M["voyant"] = MT.degrade(S, "f13_voyant", (1.0, 0.3, 0.75), (0.32, 0.004, 0.2), 0.95, main=0.85, crust=(30.0, 0.3, 11.0), mode="uv", rayon=0.12)
    M["ambre"] = MT.degrade(S, "f13_ambre", (1.0, 0.52, 0.14), (0.45, 0.08, 0.008), 1.1, main=0.85, crust=(20.0, 0.3, 13.0))
    M["rouge"] = MT.degrade(S, "f13_rouge", (1.0, 0.2, 0.08), (0.4, 0.008, 0.004), 1.5, main=0.75, crust=(20.0, 0.3, 15.0))
    return M


def _colonne(lot, M, spine, r0, r1, bandes=6, conduites=True):
    """Colonne de céramique : fût fuselé, ceintures de cuivre, conduites qui montent, trappes à fente."""
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
    for k in range(bandes):
        s = L * (0.06 + 0.9 * k / float(bandes - 1))
        i = min(range(n), key=lambda j: abs(longs[j] - s))
        rc = rr(longs[i])
        lot.put(M["cuivre"], G.oriente(G.tour([(-0.08, rc + 0.004), (-0.06, rc + 0.04), (0.06, rc + 0.04), (0.08, rc + 0.004)], 28, "z"), pts[i], fr[i][0]))
        if k % 2 == 0:
            lot.put(M["noir"], G.oriente(G.tour([(0.09, rc + 0.012), (0.17, rc + 0.012)], 28, "z"), pts[i], fr[i][0]))
    if conduites:
        for (a, rt, m) in ((-2.2, 0.05, M["cuivre"]), (-1.2, 0.07, M["poli"])):
            q = []
            for i in range(3, n - 2):
                t = fr[i][0]
                ref = G.norm(G.sub((math.cos(a), math.sin(a), 0.0), G.mul(t, G.dot((math.cos(a), math.sin(a), 0.0), t))))
                q.append(G.add(pts[i], G.mul(ref, rr(longs[i]) + rt + 0.02)))
            lot.put(m, G.tube(q, rt, 8))
    for i in range(7, n - 5, 7):
        t = fr[i][0]
        ref = G.norm(G.sub((0.2, -1.0, 0.0), G.mul(t, G.dot((0.2, -1.0, 0.0), t))))
        p = G.add(pts[i], G.mul(ref, rr(longs[i]) - 0.01))
        lot.put(M["noir"], O.pose_plane(G.boite((0, 0, 0.01), (0.34, 0.16, 0.025)), p, ref))
        lot.put(M["voyant"], O.pose_plane(G.boite((0, 0, 0.026), (0.22, 0.04, 0.012)), p, ref))


def _trepied(lot, M, c, z, R, ang, rl=0.2):
    """Trépied (signature de l'âge) : 3 jambes arquées, semelles, sous la colonne : du vide dessous."""
    for k in range(3):
        a = ang + TAU * k / 3.0
        foot = (c[0] + R * math.cos(a), c[1] + R * math.sin(a), ZF)
        head = (c[0] + 0.3 * math.cos(a), c[1] + 0.3 * math.sin(a), z)
        knee = (c[0] + R * 0.82 * math.cos(a), c[1] + R * 0.82 * math.sin(a), z * 0.62)
        pts = G.catmull([head, knee, foot], 8)
        lot.put(M["uni"], G.tube(pts, rl, 16, rfun=lambda s, i: rl * (1.25 - 0.45 * i / float(len(pts)))))
        lot.put(M["cuivre_s"], G.tour([(ZF, 0.34), (ZF + 0.06, 0.32), (ZF + 0.12, 0.2), (ZF + 0.24, 0.14)], 18, "z", (foot[0], foot[1], 0.0), cap1=True))
    lot.put(M["cuivre_s"], G.tour([(z - 0.25, 0.2), (z - 0.05, 0.56), (z + 0.1, 0.64), (z + 0.2, 0.62)], 24, "z", (c[0], c[1], 0.0)))


def _patte(lot, M, a, rh=2.05, rk=2.85, rf=3.12, zh=ZS - 0.5, zk=ZS + 0.1, c=CF, zf=ZF + 0.14):
    """Patte du géant, d'angle a autour de l'axe du robot : hanche sur la sphère, genou haut, tibia effilé, griffe."""
    x0, y0 = c
    e = (math.cos(a), math.sin(a), 0.0)
    hip = (x0 + rh * e[0], y0 + rh * e[1], zh)
    knee = (x0 + rk * e[0], y0 + rk * e[1], zk)
    foot = (x0 + rf * e[0], y0 + rf * e[1], zf)
    _membre(lot, M, hip, knee, foot)
    lot.put(M["noir"], G.tour([(zf - 0.14, 0.42), (zf - 0.06, 0.38), (zf + 0.02, 0.2)], 12, "z", (foot[0], foot[1], 0.0), cap1=True))


def _membre(lot, M, hip, knee, foot, k=1.0):
    d = G.sub(knee, hip)
    Ld = G.length(d)
    lot.put(M["noir"], G.sphere(hip, 0.4 * k, 14, 7))
    O.profil(lot, M["uni"], hip, d, [(0.0, 0.2 * k), (0.14, 0.34 * k), (0.55 * Ld, 0.32 * k), (Ld - 0.15, 0.24 * k), (Ld, 0.18 * k)], 18)
    lot.put(M["cuivre"], G.oriente(G.tour([(-0.05, 0.36 * k), (0.05, 0.36 * k)], 18, "z", cap0=True, cap1=True), G.lerp(hip, knee, 0.45), d))
    lot.put(M["cuivre"], G.sphere(knee, 0.27 * k, 14, 7))
    d = G.sub(foot, knee)
    Ld = G.length(d)
    O.profil(lot, M["cer2"], knee, d, [(0.0, 0.16 * k), (0.14, 0.26 * k), (0.4 * Ld, 0.25 * k), (0.86 * Ld, 0.12 * k), (Ld - 0.08, 0.08 * k), (Ld, 0.0)], 18)
    lot.put(M["noir"], G.oriente(G.tour([(0.55 * Ld, 0.22 * k), (0.62 * Ld, 0.21 * k)], 16, "z"), knee, d))


def _pont(lot, M, y, l=0.44, h=0.56):
    """Pont roulant : poutre treillis d'un chemin à l'autre, sommiers et galets sur les 2 chemins."""
    O.treillis(lot, M["cuivre_s"], (-XR, y, ZR + 0.1), (XR, y, ZR + 0.1), l=l, h=h, n=20, rc=0.045, rd=0.022)
    lot.put(M["acier"], G.boite((0.0, y - l / 2.0, ZR + 0.1 + h / 2.0 + 0.02), (2 * XR, 0.06, 0.04)))
    for s in (-1, 1):
        lot.put(M["acier"], G.boite((s * XR, y, ZR + 0.42), (0.74, 1.3, 0.34)))
        lot.put(M["noir"], G.boite((s * XR, y - 0.66, ZR + 0.42), (0.6, 0.03, 0.2)))
        for dy in (-0.42, 0.42):
            lot.put(M["cuivre"], G.tour([(-0.12, 0.17), (0.12, 0.17)], 14, "x", (s * XR, y + dy, ZR + 0.28), cap0=True, cap1=True))


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(1313)
    x0, y0 = CF

    # ---------------------------------------------------------------- dalle octogonale de métal sombre filetée de cuivre
    oc = [(-3.9, -6.1), (3.9, -6.1), (5.42, -4.4), (5.42, 6.4), (4.3, 7.7), (-4.3, 7.7), (-5.42, 6.4), (-5.42, -4.4)]
    lot.put(M["acier"], G.prisme(oc, 0.0, ZF - 0.05, 0.985))
    k = 0.985
    cx_, cy_ = sum(p[0] for p in oc) / 8.0, sum(p[1] for p in oc) / 8.0
    oc2 = [(cx_ + (p[0] - cx_) * k, cy_ + (p[1] - cy_) * k) for p in oc]
    lot.put(M["dalle"], G.prisme(oc2, ZF - 0.05, ZF, 0.992))
    pr = [(cx_ + (p[0] - cx_) * 0.965, cy_ + (p[1] - cy_) * 0.965, ZF + 0.006) for p in oc]
    lot.put(M["cuivre_s"], G.tube(pr + [pr[0]], 0.03, 5))
    for p in pr:
        lot.put(M["noir"], G.sphere(p, 0.07, 8, 4))
    rv = G.Rnd(1341)
    for i in range(8):                                                   # rivets du filet de cuivre
        a, b = pr[i], pr[(i + 1) % 8]
        n = int(G.length(G.sub(b, a)) / 0.55)
        lot.put(M["acier"], G.rivets_le_long([(G.add(G.lerp(a, b, j / float(max(1, n))), (0.0, -0.06, 0.0)), (0.0, 0.0, 1.0)) for j in range(n)], 0.024, 0.018))
    for y in (-4.4, -2.2, 1.7, 3.9):                                     # fers plats de la dalle
        lot.put(M["noir"], G.boite((0.0, y, ZF + 0.002), (10.2, 0.03, 0.006)))
    for (x, y, w, h) in ((-4.1, -5.2, 0.9, 0.7), (3.9, -3.7, 0.8, 1.1), (-4.25, 0.9, 0.7, 1.2), (4.2, 0.6, 0.8, 0.9), (2.6, 4.0, 1.2, 0.5), (-2.3, 3.75, 1.1, 0.6)):
        lot.put(M["plaque"], G.boite((x, y, ZF + 0.008), (w, h, 0.016), rv.f(-0.04, 0.04)))     # plaques rapportées
        lot.put(M["noir"], G.boite((x, y, ZF + 0.018), (w * 0.72, 0.022, 0.006)))
    # plaque d'assemblage : ronde, sombre, griffes de cuivre, joints rayonnants
    lot.put(M["plaque"], G.tour([(ZF, 3.1), (ZF + 0.12, 3.08), (ZF + 0.16, 2.92), (ZF + 0.17, 0.0)], 72, "z", (x0, y0, 0.0)))
    for k_ in range(24):
        a = TAU * k_ / 24.0
        lot.put(M["noir"], G.boite((x0 + 1.6 * math.cos(a), y0 + 1.6 * math.sin(a), ZF + 0.174), (2.5, 0.016, 0.008), a))
    for R in (2.1, 2.72):
        O.anneau(lot, M["cuivre_s"], (x0, y0, ZF + 0.172), R, 0.022, 96, 5)
    for k_ in range(9):
        a = TAU * k_ / 9.0 + 0.2
        lot.put(M["cuivre"], G.boite((x0 + 2.74 * math.cos(a), y0 + 2.74 * math.sin(a), ZF + 0.22), (0.5, 0.26, 0.09), a))

    # ---------------------------------------------------------------- halle droite au nord (2 ailes décalées), terrasse, radiateurs
    def plan(u, d):
        x = -5.1 + 10.2 * u
        kink = 0.45 * max(0.0, min(1.0, (u - 0.5) / 0.05))
        return (x, 4.35 + kink + d)

    def rg(d, z, N=44):
        return [(plan(i / float(N), d)[0], plan(i / float(N), d)[1], z) for i in range(N + 1)]
    lot.put(M["cer"], G.loft([rg(2.75, ZF), rg(2.75, 1.65)], closed=False))
    lot.put(M["cer2"], G.loft([rg(2.75, 1.65), rg(2.2, 2.15)], closed=False))
    lot.put(M["noir_p"], G.loft([rg(2.2, 2.15), rg(1.0, 2.15)], closed=False))
    lot.put(M["cer"], G.loft([rg(1.0, 2.15), rg(1.0, 3.1)], closed=False))
    lot.put(M["cer2"], G.loft([rg(1.0, 3.1), rg(0.0, 3.25)], closed=False))
    lot.put(M["cer"], G.loft([rg(0.0, ZF), rg(0.0, 3.25)], closed=False))
    lot.put(M["cuivre_s"], G.tube([G.add(p, (0.0, -0.03, 0.0)) for p in rg(0.0, 3.27)], 0.04, 6))
    for k_ in range(13):
        u = (k_ + 0.5) / 13.0
        p = plan(u, -0.03)
        n = (0.0, -1.0, 0.0)
        pc = (p[0], p[1], ZF + 1.42)
        lot.put(M["noir"], O.pose_plane(G.boite((0, 0, 0.012), (0.56, 1.5, 0.03)), pc, n))
        lot.put(M["voyant"] if k_ % 3 else M["ambre"], G.tube([(p[0] - 0.18, p[1] - 0.04, ZF + 1.72), (p[0] + 0.18, p[1] - 0.04, ZF + 1.72)], 0.018, 6))
        for j in range(3):
            lot.put(M["acier"], O.pose_plane(G.boite((0, -0.45 + 0.28 * j, 0.03), (0.42, 0.05, 0.015)), pc, n))
    for k_ in range(14):
        u = k_ / 13.0
        a, b, c = plan(u, -0.04), plan(u, 1.0), plan(u, 2.77)
        lot.put(M["cuivre_s"], G.tube([(a[0], a[1], ZF), (a[0], a[1], 3.27), (b[0], b[1], 3.12), (b[0], b[1], 2.17), (c[0], c[1], 2.0), (c[0], c[1], ZF)], 0.045, 6))
    # radiateurs à lames, en rang inégal sur la terrasse
    for k_ in range(10):
        u = 0.07 + 0.86 * k_ / 9.0
        p = plan(u, 0.5)
        h = 1.1 + 0.42 * math.sin(k_ * 1.9) + (0.42 if k_ in (3, 4) else 0.0)
        for s in (-0.38, 0.38):
            lot.put(M["noir"], G.boite((p[0] + s, p[1], 3.2 + h / 2.0), (0.06, 0.1, h)))
        for j in range(int(h / 0.13)):
            lot.put(M["cuivre_s"] if j % 3 == 0 else M["plaque"], G.boite((p[0], p[1], 3.28 + 0.13 * j), (0.76, 0.14, 0.05), 0.0, 0.45))
        lot.put(M["noir"], G.boite((p[0], p[1], 3.2 + h + 0.03), (0.84, 0.12, 0.05)))
    # injecteurs : ampoules de cuivre sur le toit bas
    for (u, h) in ((0.2, 0.75), (0.42, 0.55), (0.64, 0.7), (0.84, 0.5)):
        p = plan(u, 1.6)
        O.profil(lot, M["cuivre"], (p[0], p[1], 2.15), (0, 0, 1), [(0.0, 0.3), (0.08, 0.28), (0.2, 0.18), (h, 0.14), (h + 0.12, 0.09), (h + 0.24, 0.0)], 16)
        lot.put(M["uni"], G.tour([(2.15 + 0.38, 0.2), (2.15 + 0.46, 0.2)], 16, "z", (p[0], p[1], 0.0)))

    # ---------------------------------------------------------------- chemins de roulement sur colonnes à trépieds
    def rot(p):
        return G.rot_z(p, PSI, (x0, y0, 0.0))
    lot.xf = rot
    for (sx, ys, rc) in ((-1, (-4.75, -0.1, 4.2), 0.56), (1, (-4.75, 1.45, 4.9), 0.46)):
        for y in ys:
            x = sx * XR
            _trepied(lot, M, (x + 0.02 * sx, y), 1.45, 0.78, 0.5 if sx < 0 else 2.7, rl=0.19)
            _colonne(lot, M, [(x, y, 1.3), (x, y, 3.0), (x, y, 5.0), (x, y, ZR - 0.15)], rc, rc * 0.68, bandes=6, conduites=(y < 3.0))
            lot.put(M["cuivre_s"], G.tour([(ZR - 0.32, rc * 0.74), (ZR - 0.2, rc * 0.95), (ZR - 0.14, rc * 0.95)], 22, "z", (x, y, 0.0), cap1=True))
        O.treillis(lot, M["cuivre_s"], (sx * XR, -5.2, ZR + 0.1), (sx * XR, 5.75, ZR + 0.1), l=0.5, h=0.56, n=24, rc=0.05, rd=0.025, up=(0.0, 0.0, 1.0))
        lot.put(M["acier"], G.boite((sx * XR, 0.275, ZR + 0.4), (0.1, 10.95, 0.05)))
        for y in (-5.2, 5.75):
            lot.put(M["acier"], G.boite((sx * XR, y, ZR + 0.1), (0.62, 0.14, 0.7)))
    # mât de signalisation et voyant sur le chemin ouest
    q = (-XR - 0.05, 2.4, ZR + 0.42)
    lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, 1.5))], 0.024, 6))
    lot.put(M["rouge"], G.sphere(G.add(q, (0, 0, 1.53)), 0.055, 8, 4))
    # les 2 ponts roulants
    _pont(lot, M, -1.2)
    _pont(lot, M, 3.3, l=0.38, h=0.48)
    # chariot du pont avant : mât télescopique, bras de montage qui descend sur le géant
    tx, ty = -0.82, -1.2
    lot.put(M["acier"], G.boite((tx, ty, ZR - 0.3), (0.86, 0.74, 0.34)))
    lot.put(M["noir"], G.boite((tx, ty - 0.38, ZR - 0.3), (0.62, 0.02, 0.16)))
    lot.put(M["uni"], G.tube([(tx, ty, ZR - 0.42), (tx, ty, ZR - 0.92)], 0.15, 14))
    lot.put(M["poli"], G.tube([(tx, ty, ZR - 0.92), (tx, ty, 5.65)], 0.09, 12))
    O.bras(lot, M["acier"], M["cuivre"], M["caout"], (tx, ty, 5.64), (tx, ty, 5.65), (-1.82, -1.55, 5.28), (-1.25, -1.85, 4.5), (-0.68, -1.62, 4.2), r=0.26, socle=0.12,
           lum=M["coeur"], riv=M["noir"])
    # chariot du pont arrière : palan, palonnier et la patte suivante pendue
    hx, hy = 1.55, 3.3
    lot.put(M["acier"], G.boite((hx, hy, ZR - 0.26), (0.8, 0.66, 0.3)))
    lot.put(M["cuivre"], G.tour([(hy - 0.26, 0.17), (hy + 0.26, 0.17)], 16, "y", (hx, 0.0, ZR - 0.3), cap0=True, cap1=True))
    for s in (-0.16, 0.16):
        lot.put(M["noir"], G.tube([(hx + s, hy, ZR - 0.4), (hx + s, hy, 5.55)], 0.016, 5))
    lot.put(M["acier"], G.boite((hx, hy, 5.5), (0.74, 0.12, 0.1)))
    for s in (-0.3, 0.3):
        lot.put(M["noir"], G.tube([(hx + s, hy, 5.46), (hx + s * 0.25, hy, 5.08)], 0.012, 4))
    _membre(lot, M, (hx, hy, 4.98), (hx + 0.85, hy - 0.06, 3.9), (hx + 0.55, hy - 0.1, 1.78), k=0.92)

    # ---------------------------------------------------------------- le tore de plasma COUCHÉ, ouvert au sud
    lot.xf = None
    a0, a1 = GAP
    O.anneau(lot, M["plasma"], TC, RT, 0.3, 110, 16, a0, a1)
    nb = 15
    for k_ in range(nb):
        a = a0 + (a1 - a0) * (k_ + 0.5) / nb
        da = (a1 - a0) / nb * 0.31
        O.anneau(lot, M["cer2"], TC, RT, 0.42, 10, 18, a - da, a + da)
        for s in (-1, 1):
            O.anneau(lot, M["cuivre"], TC, RT, 0.46, 3, 18, a + s * da - 0.022, a + s * da + 0.022)
        O.anneau(lot, M["cuivre_s"], TC, RT, 0.438, 3, 18, a - 0.035, a + 0.035)
        p = (TC[0] + RT * math.cos(a), TC[1] + RT * math.sin(a))
        for s in (-1, 1):                                                # chevalets : 2 jambes sous chaque bobine
            q = (p[0] + s * 0.34 * math.cos(a), p[1] + s * 0.34 * math.sin(a))
            lot.put(M["acier"], G.tube([(q[0], q[1], TC[2] - 0.34), (q[0] + s * 0.16 * math.cos(a), q[1] + s * 0.16 * math.sin(a), ZF)], 0.042, 8))
        if k_ % 2 == 0:
            q = (p[0], p[1], TC[2] + 0.42)
            O.profil(lot, M["cuivre"], q, (0, 0, 1), [(0.0, 0.13), (0.06, 0.11), (0.3, 0.075), (0.36, 0.1), (0.42, 0.0)], 12)
    for (a, sgn) in ((a0, 1), (a1, -1)):                                 # brides aux 2 bouts de l'ouverture
        e = (TC[0] + RT * math.cos(a), TC[1] + RT * math.sin(a), TC[2])
        t = (-math.sin(a) * sgn, math.cos(a) * sgn, 0.0)
        lot.put(M["noir"], G.oriente(G.tour([(-0.07, 0.5), (0.1, 0.5), (0.14, 0.34)], 18, "z", cap0=True, cap1=True), G.add(e, G.mul(t, -0.08)), t))
        lot.put(M["uni"], G.oriente(G.tour([(0.0, 0.54), (0.1, 0.54)], 18, "z", cap0=True, cap1=True), G.add(e, G.mul(t, -0.12)), t))
        lot.put(M["acier"], G.boite((e[0], e[1], (ZF + TC[2] - 0.4) / 2.0), (0.42, 0.42, TC[2] - 0.4 - ZF)))
    # sphère de confinement entre 2 colonnes ouest, sur son trépied, reliée au tore
    lot.xf = rot
    sc = (-4.05, 2.05, 3.05)
    Rc = 0.98
    lot.put(M["uni"], G.sphere(sc, Rc, 36, 18))
    lot.put(M["cuivre"], G.tour([(sc[2] - 0.07, Rc + 0.002), (sc[2] - 0.04, Rc + 0.05), (sc[2] + 0.04, Rc + 0.05), (sc[2] + 0.07, Rc + 0.002)], 40, "z", (sc[0], sc[1], 0.0)))
    for t in (-0.55, 0.62, 1.05):
        O.anneau(lot, M["acier"], (sc[0], sc[1], sc[2] + Rc * math.sin(t)), Rc * math.cos(t) + 0.004, 0.012, 56, 4)
    for (a, e) in ((-1.1, 0.5), (-1.75, 0.5)):
        n = (math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))
        O.hublot(lot, M["cuivre"], M["coeur"], G.add(sc, G.mul(n, Rc)), n, 0.11)
    for a in (0.2, 2.3, 4.4):
        lot.put(M["uni"], G.tube([(sc[0] + 0.55 * math.cos(a), sc[1] + 0.55 * math.sin(a), sc[2] - 0.75), (sc[0] + 0.85 * math.cos(a), sc[1] + 0.85 * math.sin(a), ZF)], 0.075, 10))
    O.tuyau(lot, M["poli"], M["cuivre"], [(sc[0] + 0.4, sc[1] - 0.72, sc[2] - 0.52), (-2.95, 0.95, 1.95), (-2.95, 0.95, TC[2] + 0.4)], 0.09, rb=0.2, pas_bride=0.55)

    # ---------------------------------------------------------------- le géant en cours de montage
    lot.put(M["noir"], G.tour([(ZF + 0.16, 0.86), (ZF + 0.36, 0.62), (ZS - RS + 0.1, 0.5)], 24, "z", (x0, y0, 0.0)))
    lot.put(M["poli"], G.tour([(ZF + 0.5, 0.42), (ZS - RS + 0.15, 0.42)], 20, "z", (x0, y0, 0.0)))
    for a in (-2.45, -0.5, 1.5):
        lot.put(M["cuivre"], G.tube([(x0 + 1.35 * math.cos(a), y0 + 1.35 * math.sin(a), ZF + 0.18), (x0 + 0.78 * math.cos(a), y0 + 0.78 * math.sin(a), ZS - RS + 0.2)], 0.09, 12))

    def Ps(az, el, g=0.0):
        rr = (RS + g) * math.cos(el)
        return (x0 + rr * math.cos(az), y0 + rr * math.sin(az), ZS + (RS + g) * math.sin(el))
    bas = [[Ps(TAU * j / 48.0, -PI / 2 + (PI / 2 + 0.02) * i / 10.0) for j in range(49)] for i in range(11)]
    lot.put(M["cer2"], G.loft(bas, closed=False))
    lot.put(M["noir_p"], G.tour([(ZS + 0.01, RS - 0.02), (ZS + 0.02, 0.0)], 48, "z", (x0, y0, 0.0)))
    haut_int = [[Ps(math.radians(25.0) + math.radians(205.0) * j / 40.0, 1.5 * i / 8.0, -0.2) for j in range(41)] for i in range(9)]
    lot.put(M["noir_p"], G.loft(haut_int, closed=False))
    co = (x0 + 0.1, y0 - 0.42, ZS + 0.46)
    lot.put(M["coeur"], G.sphere(co, 0.72, 32, 16))
    for k_ in range(5):
        O.anneau(lot, M["cuivre_s"], co, 0.79, 0.03, 40, 5, n=(math.cos(k_ * 0.63), math.sin(k_ * 0.63), 0.15))
    for k_ in range(14):
        az = TAU * k_ / 14.0
        lot.put(M["uni"], G.tube([Ps(az, (PI / 2 - 0.12) * i / 12.0, 0.02) for i in range(13)], 0.046, 6))
    for e in (0.42, 0.82, 1.2):
        O.anneau(lot, M["uni"], (x0, y0, ZS + RS * math.sin(e)), RS * math.cos(e) + 0.02, 0.032, 60, 6)
    for (e0, e1) in ((0.02, 0.42), (0.42, 0.82), (0.82, 1.2), (1.2, 1.45)):
        n_pl = int(max(4, 12 * math.cos(e0)))
        azs = [math.radians(35.0) + math.radians(185.0) * j / n_pl for j in range(n_pl + 1)]
        for j in range(n_pl):
            if r.f() < 0.1 and e0 > 0.3:
                continue
            a0p, a1p = azs[j] + 0.012, azs[j + 1] - 0.012
            rows = [[Ps(a0p + (a1p - a0p) * u / 6.0, e0 + 0.012 + (e1 - e0 - 0.024) * v / 4.0, 0.05) for u in range(7)] for v in range(5)]
            lot.put(M["cer"] if r.f() < 0.75 else M["cer2"], G.loft(rows, closed=False))
    lot.put(M["uni"], G.tour([(ZS + RS - 0.14, 0.48), (ZS + RS, 0.44), (ZS + RS + 0.09, 0.26), (ZS + RS + 0.13, 0.0)], 24, "z", (x0, y0, 0.0)))
    # ceinture et tore du géant : 210° posés, le reste n'est qu'un cerceau d'échafaudage
    lot.put(M["noir"], G.tour([(ZS - 0.2, RS + 0.02), (ZS - 0.15, RS + 0.09), (ZS + 0.15, RS + 0.09), (ZS + 0.2, RS + 0.02)], 48, "z", (x0, y0, 0.0)))
    lot.put(M["cuivre"], G.tour([(ZS - 0.25, RS - 0.03), (ZS - 0.2, RS + 0.05)], 48, "z", (x0, y0, 0.0)))
    for k_ in range(6):
        a = TAU * (k_ + 0.5) / 6.0
        lot.put(M["uni"], G.tube([Ps(a, 0.0, 0.08), (x0 + (RG - 0.2) * math.cos(a), y0 + (RG - 0.2) * math.sin(a), ZS)], 0.075, 8))
    tz = (x0, y0, ZS)
    a0t, a1t = math.radians(75.0), math.radians(285.0)
    nt = 11
    O.anneau(lot, M["plasma"], tz, RG, 0.17, 80, 12, a0t, a1t)
    for k_ in range(nt):
        a = a0t + (a1t - a0t) * (k_ + 0.5) / nt
        da = (a1t - a0t) / nt * 0.4
        O.anneau(lot, M["cer"], tz, RG, 0.29, 8, 14, a - da, a + da)
        for s in (-1, 1):
            O.anneau(lot, M["cuivre"], tz, RG, 0.32, 2, 14, a + s * da - 0.02, a + s * da + 0.02)
    O.anneau(lot, M["acier"], tz, RG, 0.04, 60, 6, a1t, a0t + TAU)
    for a in (a1t, a0t + TAU):
        lot.put(M["noir"], G.oriente(G.tour([(-0.05, 0.28), (0.05, 0.28)], 14, "z", cap0=True, cap1=True),
                                     (x0 + RG * math.cos(a), y0 + RG * math.sin(a), ZS), (-math.sin(a), math.cos(a), 0.0)))
    for a in (math.radians(205.0), math.radians(325.0), math.radians(90.0)):
        _patte(lot, M, a)
    for a in (math.radians(265.0), math.radians(30.0), math.radians(150.0)):
        hp = (x0 + 1.72 * math.cos(a), y0 + 1.72 * math.sin(a), ZS - 0.5)
        lot.put(M["noir"], G.oriente(G.tour([(0.0, 0.28), (0.1, 0.32), (0.2, 0.2), (0.19, 0.0)], 14, "z"), hp, (math.cos(a), math.sin(a), -0.2)))
    # arcs courts entre le tore couché et le cœur du géant (zigzags déterministes)
    ra = G.Rnd(1377)
    for (a, rt, n) in ((math.radians(315.0), 0.034, 8), (math.radians(345.0), 0.028, 8), (math.radians(235.0), 0.03, 8), (math.radians(205.0), 0.024, 7)):
        p0 = (TC[0] + (RT - 0.3) * math.cos(a), TC[1] + (RT - 0.3) * math.sin(a), TC[2] + 0.12)
        pts = [p0]
        for i in range(1, n):
            t = i / float(n)
            q = G.lerp(p0, co, t)
            w = 0.26 * math.sin(PI * t)
            pts.append((q[0] + ra.f(-w, w), q[1] + ra.f(-w, w), q[2] + ra.f(-0.1, 0.1) + 0.5 * math.sin(PI * t)))
        pts.append(G.add(co, (0.0, -0.1, 0.0)))
        lot.put(M["arc"], G.tube(pts, rt, 6))

    # ---------------------------------------------------------------- 2 bras de montage au sol et sur colonne
    O.bras(lot, M["acier"], M["cuivre"], M["caout"], (XR - 0.03, -2.55, 2.75), (XR - 0.38, -2.88, 3.05), (3.2, -4.05, 4.9), (2.5, -3.4, 3.98), (1.96, -3.02, 3.42), r=0.26, socle=0.42,
           lum=None, riv=M["noir"])
    lot.put(M["acier"], G.tube([(XR, -4.75, 2.75), (XR, 1.45, 2.75)], 0.09, 10))
    a_s = math.radians(305.0)
    O.anneau(lot, M["cer"], (x0, y0 - 0.05, ZS + 0.05), RG + 0.04, 0.29, 8, 14, a_s - 0.24, a_s + 0.24)
    for s in (-1, 1):
        O.anneau(lot, M["cuivre"], (x0, y0 - 0.05, ZS + 0.05), RG + 0.04, 0.32, 2, 14, a_s + s * 0.24 - 0.02, a_s + s * 0.24 + 0.02)
    O.bras(lot, M["acier"], M["cuivre"], M["caout"], (-3.0, -5.0, ZF), (-3.0, -5.0, ZF + 0.9), (-3.8, -4.3, 3.35), (-2.9, -3.3, 4.32), (-1.42, -2.26, 3.58), r=0.26, socle=0.56,
           lum=M["coeur"], riv=M["noir"])
    O.flexible(lot, M["caout"], [(-3.0, -5.0, ZF + 0.02), (-2.0, -4.85, ZF + 0.06), (-0.75, -4.75, ZF + 0.02)], 0.05)

    # ---------------------------------------------------------------- rampe en gris sale, voie, chariot avec une patte
    lot.xf = None
    rx0, rx1 = -1.75, 3.15
    yr0, yr1 = -6.1, -7.72
    q = [(rx0, yr0, ZF + 0.005), (rx1, yr0, ZF + 0.005), (rx1, yr1, 0.02), (rx0, yr1, 0.02)]
    lot.put(M["rampe"], G.loft([[q[3], q[2]], [q[0], q[1]]], closed=False))
    for k_ in range(7):
        t = (k_ + 0.5) / 7.0
        a, b = G.lerp(q[0], q[3], t), G.lerp(q[1], q[2], t)
        lot.put(M["noir"], G.tube([G.add(G.lerp(a, b, 0.13), (0, 0, 0.012)), G.add(G.lerp(a, b, 0.87), (0, 0, 0.012))], 0.022, 5))
    for u0, u1 in ((0.0, 0.1), (0.9, 1.0)):                               # chasse-roues hachurés
        a, b, c, d = G.lerp(q[0], q[1], u0), G.lerp(q[0], q[1], u1), G.lerp(q[3], q[2], u1), G.lerp(q[3], q[2], u0)
        lot.put(M["chevron"], G.loft([[G.add(d, (0, 0, 0.016)), G.add(c, (0, 0, 0.016))], [G.add(a, (0, 0, 0.016)), G.add(b, (0, 0, 0.016))]], closed=False))
    for (s, x) in ((-1, rx0), (1, rx1)):
        rg_ = [[(x, yr0 + 0.02, ZF + 0.2), (x + s * 0.34, yr0 + 0.02, ZF + 0.2), (x + s * 0.42, yr0 + 0.02, 0.0)],
               [(x, yr1 - 0.05, 0.1), (x + s * 0.3, yr1 - 0.05, 0.1), (x + s * 0.38, yr1 - 0.05, 0.0)]]
        lot.put(M["joue"], G.loft(rg_, closed=False))
    for (x, h) in ((rx0 - 0.25, 1.15), (rx1 + 0.25, 0.75)):               # 2 bornes de porte, inégales
        O.profil(lot, M["cuivre_s"], (x, yr0 + 0.05, 0.3), (0, 0, 1), [(0.0, 0.42), (0.26, 0.4), (0.46, 0.27), (h, 0.24), (h + 0.05, 0.17), (h + 0.3, 0.09), (h + 0.32, 0.0)], 20)
        lot.put(M["ambre"], G.sphere((x, yr0 + 0.05, 0.3 + h + 0.28), 0.055, 8, 4))
    for x in (0.2, 1.2):
        lot.put(M["acier"], G.boite((x, -4.5, ZF + 0.03), (0.08, 3.2, 0.05)))
    for k_ in range(9):
        lot.put(M["noir"], G.boite((0.7, -5.9 + 0.38 * k_, ZF + 0.012), (1.26, 0.09, 0.02)))
    cx, cy = 0.7, -4.95
    lot.put(M["acier"], G.boite((cx, cy, ZF + 0.28), (1.5, 2.1, 0.14)))
    lot.put(M["cuivre_s"], G.boite((cx, cy - 1.04, ZF + 0.28), (1.54, 0.05, 0.16)))
    for dx in (-0.5, 0.5):
        for dy in (-0.72, 0.72):
            lot.put(M["noir"], G.tour([(-0.1, 0.17), (0.1, 0.17)], 14, "x", (cx + dx, cy + dy, ZF + 0.17), cap0=True, cap1=True))
    for (y, h) in ((cy + 0.55, 0.3), (cy - 0.5, 0.4)):
        lot.put(M["cuivre_s"], G.boite((cx, y, ZF + 0.35 + h / 2.0), (0.86, 0.12, h)))
    _membre(lot, M, (cx - 0.58, cy + 0.72, ZF + 0.72), (cx + 0.46, cy + 0.02, ZF + 0.86), (cx - 0.22, cy - 1.0, ZF + 0.5), k=0.86)

    # ---------------------------------------------------------------- hélium 3 au sud-ouest ; bloc de commande au sud-est
    for (x, y, R, z) in ((-3.72, -7.0, 0.62, 0.98), (-2.62, -7.2, 0.42, 0.72), (-4.78, -5.85, 0.36, 0.66)):
        lot.put(M["uni"], G.sphere((x, y, z), R, 28, 14))
        lot.put(M["cuivre"], G.tour([(z - 0.03, R + 0.002), (z - 0.01, R + 0.03), (z + 0.01, R + 0.03), (z + 0.03, R + 0.002)], 28, "z", (x, y, 0.0)))
        for k_ in range(3):
            a = TAU * k_ / 3.0 + 0.5
            lot.put(M["cuivre_s"], G.tube([(x + R * 0.6 * math.cos(a), y + R * 0.6 * math.sin(a), z - R * 0.6), (x + R * 1.05 * math.cos(a), y + R * 1.05 * math.sin(a), 0.0)], 0.05, 8))
        lot.put(M["poli"], G.tour([(z + R - 0.04, 0.11), (z + R + 0.09, 0.075), (z + R + 0.13, 0.0)], 12, "z", (x, y, 0.0)))
    O.tuyau(lot, M["poli"], M["cuivre"], [(-3.4, -6.45, 0.6), (-3.4, -5.3, 0.6), (-3.4, -5.3, ZF + 0.08), (-2.9, -4.2, ZF + 0.08)], 0.07, rb=0.16)
    O.tuyau(lot, M["poli"], M["cuivre"], [(-2.62, -6.82, 0.42), (-2.62, -6.45, 0.42), (-3.3, -6.45, 0.5)], 0.05, rb=0.1)
    lot.put(M["acier"], G.prisme([(3.95, -7.5), (5.4, -7.5), (5.45, -5.6), (3.95, -5.6)], 0.0, 1.0, 0.96))
    for k_ in range(4):
        lot.put(M["noir"], G.boite((4.7, -7.2 + 0.42 * k_, 1.005), (1.3, 0.02, 0.01)))
    lot.put(M["noir"], G.boite((4.7, -7.5, 0.56), (1.1, 0.03, 0.5)))
    lot.put(M["voyant"], G.tube([(4.25, -7.53, 0.68), (5.15, -7.53, 0.68)], 0.018, 6))
    for (dx, dy, h) in ((-0.4, -0.3, 0.42), (0.1, 0.25, 0.6), (0.48, -0.25, 0.3)):
        O.profil(lot, M["cuivre"], (4.7 + dx, -6.55 + dy, 1.0), (0, 0, 1), [(0.0, 0.22), (0.06, 0.2), (h, 0.14), (h + 0.08, 0.0)], 14)
    # conduites et câbles ; menus détails sur la dalle
    for (a, b, rt) in (((-2.2, 4.3, 0.55), (-3.1, 1.2, 0.62), 0.09), ((2.6, 4.7, 0.55), (3.05, 1.65, 0.62), 0.11), ((0.9, 4.5, 0.55), (0.65, 2.9, 0.62), 0.07)):
        O.tuyau(lot, M["poli"], M["cuivre"], [a, G.add(G.lerp(a, b, 0.5), (0.0, 0.0, 0.1)), b], rt, rb=0.26, pas_bride=0.8)
    for (a, b) in (((-0.2, 3.1, ZF + 0.03), (-0.1, 1.9, ZF + 0.2)), ((1.2, 3.0, ZF + 0.03), (1.0, 1.8, ZF + 0.2))):
        for dy in (-0.09, 0.09):
            O.flexible(lot, M["caout"], [G.add(a, (dy, 0, 0)), G.add(G.lerp(a, b, 0.5), (dy, 0, 0.1)), G.add(b, (dy, 0, 0))], 0.035)
    ru = G.Rnd(1391)
    mats = [M["acier"], M["noir"], M["plaque"], M["cuivre_s"]]
    for k_ in range(170):
        x, y = ru.f(-5.1, 5.1), ru.f(-5.7, 4.2)
        d = math.hypot(x - x0, y - y0)
        if d < 3.2 or (-0.1 < x < 1.5 and y < -2.5):
            continue
        lot.put(mats[k_ % 4], G.boite((x, y, ZF + 0.03), (ru.f(0.1, 0.32), ru.f(0.08, 0.24), ru.f(0.03, 0.13)), ru.f(0.0, 3.0)))
    for (x, y, sz) in ((-4.9, -2.8, 0.42), (-4.55, -3.2, 0.34), (4.95, -3.4, 0.46), (4.95, 3.3, 0.5), (3.9, 3.35, 0.38), (-4.85, 3.2, 0.44)):
        lot.put(M["acier"] if sz > 0.4 else M["plaque"], G.boite((x, y, ZF + sz / 2.0), (sz, sz * 0.85, sz), 0.2))
        lot.put(M["cuivre_s"], G.boite((x, y, ZF + sz + 0.012), (sz * 1.03, sz * 0.2, 0.024), 0.2))
    return {"tore": TC}
