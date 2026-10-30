"""ÂGE 13 · FUSION (ère V Stellaire) : LA CITADELLE-RÉACTEUR bâtie sur la carcasse du vaisseau (emprise 16×8). Nez à droite.

DA (docs/DESIGN_EPOQUES.md, §0 et §5 « Époque 13 · Fusion ») : signature « tore de plasma lumineux horizontal autour
d'une sphère (planète à anneau) ; trépieds ; 5 événements » ; kit « sphère de confinement, tore de plasma (émissif),
trépied, injecteur » ; matières « céramique blanche #D9D6CF, cuivre #B0703A » ; lumière « plasma magenta #FF4FD8
(cœur #FF9A3A) » ; centre niv. 13 = « Citadelle-réacteur : sphère de confinement sur trépied ; tore de plasma
horizontal autour ; flèche ».

Composition (gauche → droite = passé → présent) : deux tuyères devenues TUYÈRES MAGNÉTIQUES (bobines de cuivre en
entonnoir, gorge au plasma), dérive dressée, ailes devenues RADIATEURS ; au milieu, sur un socle octogonal de
céramique, le CŒUR du vaisseau est devenu une SPHÈRE DE CONFINEMENT sur TRÉPIED, ceinturée d'un TORE DE PLASMA
(carter de céramique, fenêtre magenta, 12 bobines en D de cuivre), tenue par l'ÉPINE dorsale qui monte en arche
au-dessus d'elle (les CÔTES inclinées « (((( » retombent en cage autour du tore) et porte la FLÈCHE de commandement ;
injecteurs de faisceaux sur tréteaux, cryostat sous la sphère (vide ombré traversé de flexibles), halles, réservoirs
d'hélium 3, passerelle sous le tore ; à droite, le CRÂNE (nez tuilé de céramique, chevrons jaunes et noirs d'origine,
verrière) sur jambes de train.
"""
import math

import carcasse13 as K
import geo as G
import mat as MT
import outils13 as O

TAU = G.TAU
YAW = -0.13                      # nez vers le sud-est (~7,5°)

CX, CY, CZ, CR = -0.4, 0.0, 5.45, 2.3          # sphère de confinement
TZ, TR, TRC = 5.2, 3.25, 0.42                  # tore : hauteur, grand rayon, rayon du carter
Z_SOC = 0.85                                   # dessus du socle


def yaw(p):
    return G.rot_z(p, YAW)


def xf_crane(p):
    return yaw(K.roll_crane(p))


def xf_queue(p):
    return yaw(K.roll_queue(p))


# ------------------------------------------------------------------------------------------------ matières
def matieres(S):
    M = {}
    sf = MT.surface
    # céramique blanche patinée, en tuiles (bouclier thermique) : la couleur reste chaude, la suie descend
    M["ceram"] = sf("q13_ceram", (0.56, 0.465, 0.33), rough=0.58, met=0.05, tole=(0.25, 0.205), joint=0.8, joint_l=0.012,
                    var=0.09, grain=0.08, coulures=0.8, rouille=(0.075, 0.05, 0.034), usure=0.3, nu=(0.66, 0.6, 0.5),
                    crasse=0.95, crasse_col=(0.012, 0.008, 0.006), pied=(0.0, 1.0, 0.6), relief=0.3, graine=131)
    M["ceram2"] = sf("q13_ceram2", (0.44, 0.335, 0.215), rough=0.62, met=0.05, tole=(0.27, 0.22), joint=0.78, joint_l=0.012,
                     var=0.08, grain=0.09, coulures=0.85, rouille=(0.06, 0.04, 0.026), usure=0.35, nu=(0.6, 0.54, 0.45),
                     crasse=0.95, crasse_col=(0.011, 0.008, 0.006), relief=0.3, graine=132)
    M["ceram3"] = sf("q13_ceram3", (0.6, 0.51, 0.37), rough=0.55, met=0.05, tole=(0.23, 0.19), joint=0.84, joint_l=0.01, var=0.07, grain=0.07, coulures=0.7,
                     rouille=(0.08, 0.055, 0.035), usure=0.3, crasse=0.95, crasse_col=(0.012, 0.008, 0.006), relief=0.25, graine=133)
    M["noire"] = sf("q13_noire", (0.02, 0.015, 0.011), rough=0.7, met=0.05, tole=(0.3, 0.25), joint=0.3, joint_l=0.02,
                    var=0.25, grain=0.12, usure=0.4, nu=(0.12, 0.11, 0.1), crasse=0.5, relief=0.7, graine=134)
    M["cuivre"] = sf("q13_cuivre", (0.55, 0.2, 0.055), rough=0.42, met=0.9, coulures=0.6, rouille=(0.05, 0.13, 0.085),
                     usure=0.65, nu=(0.85, 0.5, 0.28), crasse=0.65, crasse_col=(0.03, 0.02, 0.012), graine=135)
    M["cuivre_s"] = sf("q13_cuivre_s", (0.19, 0.07, 0.03), rough=0.5, met=0.85, coulures=0.5, rouille=(0.04, 0.1, 0.07),
                       usure=0.6, nu=(0.6, 0.33, 0.18), crasse=0.65, graine=136)
    M["vdg"] = sf("q13_vdg", (0.07, 0.15, 0.11), rough=0.55, met=0.4, coulures=0.5, usure=0.5, nu=(0.45, 0.25, 0.14),
                  crasse=0.6, graine=137)
    M["toit"] = sf("q13_toit", (0.3, 0.115, 0.045), rough=0.45, met=0.85, tole=(0.16, 1.4), joint=0.45, coulures=0.7,
                   rouille=(0.05, 0.12, 0.08), usure=0.5, nu=(0.7, 0.4, 0.22), crasse=0.6, relief=0.4, graine=138)
    M["acier"] = sf("q13_acier", (0.06, 0.044, 0.032), rough=0.5, met=0.75, coulures=0.5, rouille=(0.12, 0.06, 0.03),
                    usure=0.7, nu=(0.24, 0.22, 0.2), crasse=0.6, graine=139)
    M["noir"] = sf("q13_noir", (0.011, 0.008, 0.006), rough=0.6, met=0.4, usure=0.4, nu=(0.1, 0.09, 0.085), crasse=0.4,
                   graine=140)
    M["grille"] = sf("q13_grille", (0.05, 0.038, 0.027), rough=0.55, met=0.6, tole=(0.07, 0.07), joint=0.15, joint_l=0.12,
                     var=0.05, usure=0.4, crasse=0.6, relief=0.8, graine=141)
    M["caout"] = sf("q13_caout", (0.02, 0.019, 0.018), rough=0.8, met=0.0, usure=0.2, crasse=0.3, graine=142)
    M["cable_r"] = sf("q13_cable_r", (0.32, 0.025, 0.014), rough=0.6, met=0.0, usure=0.2, crasse=0.3, graine=143)
    M["os"] = sf("q13_os", (0.44, 0.34, 0.2), rough=0.55, met=0.25, tole=(0.5, 0.3), joint=0.55, var=0.08,
                 coulures=0.6, rouille=(0.09, 0.055, 0.03), usure=0.6, nu=(0.45, 0.4, 0.33), crasse=0.8, relief=0.4,
                 graine=144)
    M["chevron"] = sf("q13_chevron", (0.52, 0.33, 0.02), rough=0.55, met=0.2, bandes=(0.42, (0.015, 0.013, 0.01), 0.5),
                      coulures=0.7, rouille=(0.12, 0.06, 0.02), usure=0.7, nu=(0.35, 0.3, 0.25), crasse=0.7, graine=145)
    M["jaune"] = sf("q13_jaune", (0.45, 0.29, 0.02), rough=0.55, met=0.2, coulures=0.8, rouille=(0.12, 0.06, 0.02),
                    usure=0.75, nu=(0.35, 0.3, 0.25), crasse=0.75, graine=146)
    M["terre"] = sf("q13_terre", (0.13, 0.075, 0.035), rough=0.95, met=0.0, crasse=0.5, graine=147)
    M["brule"] = sf("q13_brule", (0.02, 0.014, 0.016), rough=0.75, met=0.4, usure=0.0, crasse=0.6, graine=148)
    M["verre"] = MT.verre("q13_verre", col=(0.022, 0.012, 0.022), reflet=(0.22, 0.13, 0.2))
    M["plasma"] = _emis(S, "q13_plasma", (1.0, 0.31, 0.85), 2.4, crust=(7.0, 0.7, 13.0))
    M["coeur"] = _emis(S, "q13_coeur", (1.0, 0.6, 0.23), 3.2, crust=(9.0, 0.4, 14.0))
    M["hublot"] = _emis(S, "q13_hublot", (1.0, 0.72, 0.42), 1.8)
    M["balise"] = _emis(S, "q13_balise", (1.0, 0.3, 0.82), 3.5)
    return M


def _emis(S, name, col, force, crust=None):
    """Surface lumineuse ÉTEINTE dans la couche principale (main_scale 0, mate) : la lueur additive seule donne la couleur,
    comme le feu vanilla (essai 1 : main 0,25 + force 5 brûlait le plasma en BLANC dans la composition)."""
    m = S.mat_emissive(name, col, strength=force, base=tuple(c * 0.06 for c in col), main_scale=0.0, crust=crust)
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in p.inputs:
        p.inputs["Specular IOR Level"].default_value = 0.0
    return m


# ------------------------------------------------------------------------------------------------ outils locaux
def tore(c, R, r, n=64, m=12, b0=0.0, b1=TAU):
    """Tore d'axe z (profil : cercle de rayon r autour du point (R, z) ; arc partiel b0..b1 du petit cercle)."""
    plein = abs(b1 - b0 - TAU) < 1e-9
    k = m if plein else m
    prof = [(c[2] + r * math.sin(b0 + (b1 - b0) * i / float(k)), R + r * math.cos(b0 + (b1 - b0) * i / float(k)))
            for i in range(k + 1)]
    return G.tour(prof, n, "z", (c[0], c[1], 0.0))


def boite_ax(a, b, w, h):
    """Boîte de section w × h tendue de a à b (axe quelconque), par un tube à 4 côtés tourné de 45°."""
    d = G.norm(G.sub(b, a))
    L = G.length(G.sub(b, a))
    v, f, u = G.boite((0, 0, L / 2), (w, h, L))
    return G.oriente((v, f, u), a, d)


# ------------------------------------------------------------------------------------------------ carcasse : crâne
def crane(lot, M, r):
    xf = xf_crane
    xs = K.stations(K.X_CR0, K.X_NEZ - 0.12, 0.42, r, 0.25)
    core = [[K.surf_crane(x, TAU * j / 48, -0.004) for j in range(48)]
            for x in [K.X_CR0 + (K.X_NEZ - K.X_CR0) * i / 40.0 for i in range(41)]]
    lot.put(M["noir"], G.loft(core, closed=True), xf)
    # paroi arrière (cloison où le bâtiment a remplacé le ventre)
    ring = [K.surf_crane(K.X_CR0, TAU * j / 48, 0.05) for j in range(48)]
    lot.put(M["os"], G.loft([ring, [K.surf_crane(K.X_CR0 - 0.08, TAU * j / 48, -0.1) for j in range(48)]], cap1=True), xf)

    def mats(rr, xm, am):
        if 3.0 < xm < 3.5:
            return M["chevron"]                     # anneau de chevrons d'origine (relique de l'épave)
        if xm > 6.7:
            return M["jaune"] if rr.f() < 0.6 else M["chevron"]
        s = math.sin(am)
        if s < -0.35:
            return M["noire"]                       # dessous : tuiles noires (bouclier thermique)
        x = rr.f()
        if x < 0.08:
            return M["jaune"]                       # rapiéçages jaunes d'origine
        if x < 0.16:
            return M["cuivre_s"]
        return M["ceram"] if x < 0.62 else (M["ceram3"] if x < 0.82 else M["ceram2"])

    def saut(xm, am):                               # verrière
        return 4.15 < xm < 5.95 and abs(am - math.pi / 2) < 0.55

    K.plaques(lot, K.surf_crane, xs, 0.46, mats, r, saut=saut, rivet=M["cuivre_s"], xf=xf)
    # verrière : cadre lourd de cuivre, verre fumé magenta-noir
    rings = []
    for i in range(12):
        x = 4.15 + 1.8 * i / 11.0
        zc, w, ht, hb = K.profil_crane(x)
        bump = math.sin(math.pi * i / 11.0) ** 0.6
        ring = []
        for j in range(15):
            a = math.pi / 2 + (j / 14.0 - 0.5) * 1.12
            y, z = K.super_pt(zc, w, ht, hb, a, 0.02 + 0.16 * bump * math.sin(a) ** 4)
            ring.append((x, y, z))
        rings.append(ring)
    lot.put(M["verre"], G.loft(rings, closed=False), xf)
    for i in (0, 4, 8, 11):
        lot.put(M["cuivre"], G.tube([G.add(p, (0, 0, 0.02)) for p in rings[i]], 0.04, 6), xf)
    for j in (0, 7, 14):
        lot.put(M["cuivre"], G.tube([G.add(rg[j], (0, 0, 0.02)) for rg in rings], 0.04, 6), xf)
    # lisse de cuivre le long du flanc, hublots tous différents
    for a in (math.pi / 2 + 1.05, -0.25):
        pts = [K.surf_crane(K.X_CR0 + 0.2 + i * 0.25, a, 0.07) for i in range(int((6.6 - K.X_CR0) / 0.25))]
        lot.put(M["cuivre_s"], G.tube(pts, 0.035, 6), xf)
    for (x, a, rr_) in ((3.85, math.pi / 2 + 1.25, 0.11), (5.0, math.pi / 2 + 1.2, 0.075), (5.55, math.pi / 2 + 1.28, 0.06)):
        p = K.surf_crane(x, a, 0.06)
        n = K.normale_s(K.surf_crane, x, a)
        mesh_c = G.oriente(G.tour([(0.0, rr_ * 1.5), (0.04, rr_ * 1.38), (0.045, rr_ * 1.02), (0.02, rr_ * 0.95)], 16, "z"), p, n)
        mesh_v = G.oriente(G.tour([(0.02, rr_ * 0.98), (0.03, 0.0)], 16, "z"), p, n)
        lot.put(M["cuivre"], mesh_c, xf)
        lot.put(M["hublot"] if x < 4.5 else M["verre"], mesh_v, xf)
    # canards (petits plans) et capteur au nez
    for s in (-1, 1):
        x0 = 5.6
        zc, w, ht, hb = K.profil_crane(x0)
        poly = [(x0 + 0.85, w - 0.05), (x0 - 0.1, w - 0.05), (x0 - 0.35, w + 0.8), (x0 + 0.1, w + 0.8)]
        a = [(px, s * py, zc - 0.05) for px, py in poly]
        b = [(px, s * py, zc + 0.04) for px, py in poly]
        lot.put(M["ceram2"], G.loft([a, b], closed=True), xf)
        lot.put(M["ceram2"], (b, [(0, 1, 2, 3)], [(p[0], p[1]) for p in b]), xf)
        lot.put(M["cuivre"], G.tube([b[0], b[3]], 0.035, 6), xf)
    tip = K.surf_crane(K.X_NEZ - 0.15, math.pi / 2, 0.02)
    lot.put(M["cuivre"], G.tube([tip, G.add(tip, (0.55, 0.0, 0.12))], 0.03, 6), xf)
    for (x, a, h) in ((4.0, math.pi / 2 - 0.45, 0.9), (3.3, math.pi / 2 + 0.35, 0.55)):
        base = K.surf_crane(x, a, 0.05)
        O.antenne(lot, M["acier"], None, xf_crane(base), h, 0.025, barres=1 if h < 0.7 else 2)
    # jambes de train sous le crâne : vérins, sabots, sur la butte
    for (x, y) in ((3.4, -0.95), (3.4, 0.95), (6.1, 0.0)):
        zc, w, ht, hb = K.profil_crane(x)
        top = xf_crane((x, y * 0.8, zc - hb * 0.7))
        pied = yaw((x + 0.15, y * 1.15, 0.0))
        lot.put(M["acier"], G.tube([top, G.lerp(top, pied, 0.55)], 0.11, 10))
        lot.put(M["cuivre"], G.tube([G.lerp(top, pied, 0.5), pied], 0.07, 10))
        lot.put(M["noir"], G.tour([(0.0, 0.26), (0.06, 0.25), (0.11, 0.1), (0.2, 0.08)], 14, "z", (pied[0], pied[1], 0.0),
                                  cap0=True, cap1=True))
        lot.put(M["caout"], G.tube(G.catmull([top, G.add(G.lerp(top, pied, 0.4), (0.12, 0.0, 0.0)), G.lerp(top, pied, 0.85)], 8),
                                   0.03, 6))


# ------------------------------------------------------------------------------------------------ carcasse : queue
def queue(lot, M, r):
    xf = xf_queue
    core = [[K.surf_queue(x, TAU * j / 40, -0.004) for j in range(40)]
            for x in [K.X_Q0 + (K.X_Q1 - K.X_Q0) * i / 20.0 for i in range(21)]]
    lot.put(M["noir"], G.loft(core, closed=True, cap0=True, cap1=True), xf)

    def mats(rr, xm, am):
        if math.sin(am) < -0.3:
            return M["noire"]
        x = rr.f()
        if x < 0.1:
            return M["jaune"]
        if x < 0.2:
            return M["cuivre_s"]
        return M["ceram"] if x < 0.6 else M["ceram2"]

    def saut(xm, am):                                 # brèches (vieux dégâts) : on voit le noyau sombre
        return (-4.6 < xm < -4.0 and 4.0 < am < 4.6) or (-3.6 < xm < -3.2 and 0.2 < am < 0.7)

    K.plaques(lot, K.surf_queue, K.stations(K.X_Q0, K.X_Q1, 0.45, r), 0.48, mats, r, saut=saut, rivet=M["cuivre_s"], xf=xf)
    # nacelles et TUYÈRES MAGNÉTIQUES
    for s in (-1, 1):
        sf = K.surf_nac(s)
        yc = s * K.NAC_Y
        xs = [K.NAC_X0 + (K.NAC_X1 - K.NAC_X0) * i / 24.0 for i in range(25)]
        lot.put(M["noir"], G.tour([(x, K.r_nac(x) - 0.004) for x in xs], 36, "x", (0.0, yc, K.NAC_Z)), xf)

        def matn(rr, xm, am):
            if math.sin(am) < -0.4:
                return M["noire"]
            x = rr.f()
            return M["cuivre_s"] if x < 0.12 else (M["ceram"] if x < 0.6 else M["ceram3"])
        K.plaques(lot, sf, K.stations(K.NAC_X0 - 0.45, K.NAC_X1, 0.4, r), 0.5, matn, r, rivet=M["cuivre_s"], xf=xf)
        # entrée d'air : lèvre, grille
        xe = K.NAC_X0 - 0.05
        re = K.r_nac(xe)
        lot.put(M["cuivre"], G.tour([(xe - 0.03, re * 1.02), (xe + 0.05, re * 1.04), (xe + 0.07, re * 0.85), (xe + 0.03, re * 0.6)],
                                    36, "x", (0.0, yc, K.NAC_Z)), xf)
        lot.put(M["brule"], G.tour([(xe + 0.02, re * 0.62), (xe - 0.15, 0.0)], 24, "x", (0.0, yc, K.NAC_Z)), xf)
        for xb in (-4.0, -4.9, -5.75):
            R = K.r_nac(xb)
            lot.put(M["cuivre"], G.tour([(xb - 0.07, R), (xb - 0.065, R + 0.08), (xb + 0.065, R + 0.08), (xb + 0.07, R)],
                                        36, "x", (0.0, yc, K.NAC_Z)), xf)
        # tuyère : col de céramique noire, 4 bobines de cuivre en entonnoir tenues par 4 longerons, gorge au plasma
        x1 = K.NAC_X1
        R = K.r_nac(x1)
        lot.put(M["noire"], G.tour([(x1 + 0.02, R), (x1 - 0.12, R * 0.9), (x1 - 0.3, R * 0.62), (x1 - 0.32, R * 0.45),
                                    (x1 - 0.1, R * 0.4), (x1, 0.0)], 32, "x", (0.0, yc, K.NAC_Z)), xf)
        for i in range(4):
            xb = x1 - 0.42 - 0.27 * i
            rb = R * (0.55 + 0.17 * i)
            lot.put(M["cuivre"], G.tour([(xb - 0.09 + 0.12 * math.cos(u * TAU / 10), rb + 0.12 * math.sin(u * TAU / 10)) for u in range(11)],
                                        32, "x", (0.0, yc, K.NAC_Z)), xf)
            lot.put(M["noir"], G.tour([(xb - 0.1, rb - 0.1), (xb + 0.1, rb - 0.1)], 32, "x", (0.0, yc, K.NAC_Z)), xf)
        for q in range(4):
            a = q * TAU / 4 + 0.4
            p0 = (x1 - 0.1, yc + R * 0.95 * math.cos(a), K.NAC_Z + R * 0.95 * math.sin(a))
            p1 = (x1 - 1.35, yc + R * 1.25 * math.cos(a), K.NAC_Z + R * 1.25 * math.sin(a))
            lot.put(M["acier"], boite_ax(p0, p1, 0.07, 0.07), xf)
        # gorge : cœur orange, plasma qui sort en cône court
        lot.put(M["coeur"], G.tour([(x1 - 0.3, R * 0.42), (x1 - 0.42, R * 0.25), (x1 - 0.5, 0.0)], 20, "x", (0.0, yc, K.NAC_Z)), xf)
        lot.put(M["plasma"], G.tour([(x1 - 0.55, R * 0.3), (x1 - 0.9, R * 0.22), (x1 - 1.25, R * 0.08), (x1 - 1.3, 0.0)],
                                    20, "x", (0.0, yc, K.NAC_Z)), xf)
        # flexibles nacelle → fuselage, câbles
        for k in range(2):
            a = s * (math.pi / 2 + 0.25 + 0.3 * k)
            p0 = sf(-4.3 - 0.6 * k, math.pi / 2 + s * 0.6, 0.06)
            p1 = K.surf_queue(-4.0 - 0.6 * k, math.pi / 2 - s * 0.25 * 0 + s * 0.2, 0.06)
            O.flexible(lot, M["caout"] if k == 0 else M["cuivre_s"], [xf(p0), xf(G.lerp(p0, p1, 0.5)), xf(p1)], 0.055)
    # dérive dressée (céramique, bord de cuivre, bandes de chevrons au bout)
    zt = K.ZC_Q + 0.98
    poly = [(-3.95, zt), (-5.75, zt), (-6.95, zt + 2.6), (-6.15, zt + 2.75)]
    ep = 0.07
    for (pp, m) in ((poly, M["ceram"]),):
        a_ = [(x, -ep, z) for x, z in pp]
        b_ = [(x, ep, z) for x, z in pp]
        lot.put(m, G.loft([a_, b_], closed=True), xf)
        lot.put(m, (b_, [(0, 1, 2, 3)], [(x, z) for x, _, z in b_]), xf)
        lot.put(m, (list(reversed(a_)), [(0, 1, 2, 3)], [(x, z) for x, _, z in a_]), xf)
    tipp = [(-6.25, -ep - 0.01, zt + 2.2), (-6.95, -ep - 0.01, zt + 2.6), (-6.15, -ep - 0.01, zt + 2.75), (-5.85, -ep - 0.01, zt + 2.35)]
    tipn = [(p[0], -p[1], p[2]) for p in tipp]
    lot.put(M["chevron"], G.loft([tipp, tipn], closed=True), xf)
    lot.put(M["cuivre"], G.tube([(-3.95, 0, zt), (-6.15, 0, zt + 2.75)], 0.09, 8), xf)
    for i in range(5):                                       # plaques de raidissement rivetées
        x = -4.6 - 0.35 * i
        z = zt + 0.35 + 0.35 * i
        for sy in (-1, 1):
            lot.put(M["ceram2"], G.boite((x, sy * (ep + 0.02), z), (0.5, 0.04, 0.32)), xf)
    O.antenne(lot, M["acier"], None, xf((-6.3, 0.0, zt + 2.72)), 0.7, 0.025, barres=1)
    # ailes devenues RADIATEURS : cadre de céramique, lames sombres, caloducs de cuivre ; dièdre 0,2
    for s in (-1, 1):
        y_r, y_b = K.NAC_Y + 0.85, 4.75
        z_r = K.NAC_Z + 0.05
        x_ra, x_rf, x_ba, x_bf = -3.9, -5.85, -5.3, -6.75

        def pt(u, v, h, s=s):
            xa = x_ra + (x_ba - x_ra) * v
            xfu = x_rf + (x_bf - x_rf) * v
            y = y_r + (y_b - y_r) * v
            p = (xa + (xfu - xa) * u, s * y, z_r + h)
            return G.rot_x(p, s * 0.2, (0.0, s * y_r, z_r))
        q = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
        lot.put(M["noir"], G.loft([[pt(u, v, -0.04) for u, v in q], [pt(u, v, 0.04) for u, v in q]], closed=True), xf)
        lot.put(M["noir"], ([pt(u, v, 0.04) for u, v in q], [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)]), xf)
        # cadre
        for (a, b) in (((0, 0), (0, 1)), ((1, 0), (1, 1)), ((0, 1), (1, 1)), ((0, 0.5), (1, 0.5))):
            lot.put(M["ceram2"], boite_ax(pt(a[0], a[1], 0.03), pt(b[0], b[1], 0.03), 0.14, 0.1), xf)
        # lames du radiateur (pas irrégulier)
        n = 13
        for i in range(n):
            u = 0.06 + 0.88 * (i + r.f(-0.2, 0.2)) / (n - 1)
            for (v0, v1) in ((0.04, 0.47), (0.53, 0.96)):
                lot.put(M["ceram"] if i % 4 else M["cuivre_s"], boite_ax(pt(u, v0, 0.07), pt(u, v1, 0.07), 0.05, 0.08), xf)
        for v in (0.25, 0.75):                               # caloducs
            lot.put(M["cuivre"], G.tube([pt(-0.06, v, 0.12), pt(1.04, v, 0.12)], 0.045, 8), xf)
        lot.put(M["cuivre"], G.tube([pt(0.0, 0.0, 0.05), pt(0.0, 1.0, 0.05)], 0.07, 8), xf)    # bord d'attaque


# ------------------------------------------------------------------------------------------------ épine, côtes
def squelette(lot, M, r):
    pts = K.epine_pts()
    P = [yaw(p) for p in pts]
    lot.put(M["os"], G.tube(P, 0.26, 10))
    fr = G._frames(P)
    acc, last = 0.0, -1e9
    for i, p in enumerate(P):
        if i:
            acc += G.length(G.sub(p, P[i - 1]))
        if acc - last > 0.55 and 1 <= i < len(P) - 1:
            last = acc
            t = fr[i][0]
            lot.put(M["os"], G.oriente(G.tour([(-0.06, 0.29), (-0.045, 0.33), (0.045, 0.33), (0.06, 0.29)], 10, "z", cap0=True, cap1=True), p, t))
            up = G.norm(G.sub((0, 0, 1), G.mul(t, t[2])))
            tip = G.add(p, G.add(G.mul(up, 0.42 + 0.1 * r.f()), G.mul(t, -0.22)))
            if i % 2 == 0:
                lot.put(M["os"], G.tube([G.add(p, G.mul(up, 0.26)), tip], 0.06, 5))
            if r.f() < 0.35:
                lot.put(M["cuivre"], G.oriente(G.tour([(-0.04, 0.3), (0.04, 0.3)], 10, "z", cap0=True, cap1=True), p, t))
    # côtes inclinées vers la queue « (((( » : CÔTÉ NORD seulement (la face sud de la sphère reste dégagée) ; elles
    # descendent de l'épine derrière la sphère et se posent sur le carter du tore (elles le portent)
    for xr in (-2.5, -1.4, -0.3, 0.8, 1.9):
        zs = K.z_epine(pts, xr) - 0.12
        xe = xr - 1.0
        ye = math.sqrt(max(0.0, TR * TR - (xe - CX) ** 2))
        ze = TZ + TRC + 0.04
        for s in (1,):
            cp = []
            for i in range(17):
                t = i / 16.0
                ph = t * math.pi / 2
                y = s * ye * math.sin(ph) ** 0.6
                z = ze + (zs - ze) * math.cos(ph) ** 0.9
                cp.append(yaw((xr - 1.0 * t, y, z)))
            lot.put(M["os"], G.tube(cp, 0.17, 6))
            lot.put(M["os"], G.tube(cp[3:14], 0.2, 4))
            for j in (4, 9, 13):                       # colliers de cuivre
                tg = G.norm(G.sub(cp[j + 1], cp[j - 1]))
                lot.put(M["cuivre"], G.oriente(G.tour([(-0.06, 0.24), (0.06, 0.24)], 8, "z", cap0=True, cap1=True), cp[j], tg))
            foot = cp[-1]
            lot.put(M["cuivre"], G.prisme([(foot[0] - 0.24, foot[1] - 0.2), (foot[0] + 0.24, foot[1] - 0.2), (foot[0] + 0.24, foot[1] + 0.2),
                                           (foot[0] - 0.24, foot[1] + 0.2)], foot[2] - 0.12, foot[2] + 0.12, top_scale=0.6))
    return pts


# ------------------------------------------------------------------------------------------------ socle et bâtiments
def socle(lot, M, r):
    x0, x1, y0, y1, ch = -4.75, 3.35, -4.7, 4.55, 1.05
    poly = [(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch), (x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch), (x0, y0 + ch)]
    P = [yaw((x, y, 0)) for x, y in poly]
    lot.put(M["ceram2"], G.prisme([(p[0], p[1]) for p in P], 0.0, Z_SOC - 0.12, top_scale=0.975))
    Pi = [yaw((x * 0.97 - 0.02, y * 0.97, 0)) for x, y in poly]
    lot.put(M["grille"], G.prisme([(p[0], p[1]) for p in Pi], Z_SOC - 0.12, Z_SOC, top_scale=1.0))
    # rive de cuivre, pilastres et évents sur la face sud
    for i in range(len(P)):
        a, b = P[i], P[(i + 1) % len(P)]
        lot.put(M["cuivre_s"], G.tube([G.add(G.lerp(a, b, 0.0), (0, 0, Z_SOC - 0.1)), G.add(b, (0, 0, Z_SOC - 0.1))], 0.045, 6))
    for x in (-3.4, -2.1, 0.9, 2.2):
        c = yaw((x, y0 - 0.02, Z_SOC * 0.45))
        lot.put(M["noir"], G.boite(c, (0.55, 0.06, 0.32), YAW))
        for k in range(5):
            lot.put(M["acier"], G.boite(G.add(c, (0, -0.02, -0.12 + 0.06 * k)), (0.5, 0.04, 0.025), YAW))
    for x in (-4.0, -1.3, 1.6, 2.9):
        c = yaw((x, y0 - 0.03, Z_SOC * 0.5))
        lot.put(M["cuivre_s"], G.boite(c, (0.14, 0.1, Z_SOC), YAW))


def cryostat(lot, M, r):
    c = (CX, CY, 0.0)
    R = 1.55
    lot.put(M["ceram3"], G.tour([(Z_SOC, R), (2.25, R), (2.35, R - 0.12), (2.4, 0.8)], 40, "z", yaw(c), cap1=True))
    for z in (Z_SOC + 0.12, 1.55, 2.2):
        lot.put(M["cuivre"], G.tour([(z - 0.05, R + 0.04), (z + 0.05, R + 0.04)], 40, "z", yaw(c)))
    for k in range(10):                                  # nervures verticales
        a = TAU * (k + 0.5) / 10
        p = yaw((CX + (R + 0.04) * math.cos(a), CY + (R + 0.04) * math.sin(a), 0))
        lot.put(M["cuivre_s"], G.boite((p[0], p[1], (Z_SOC + 2.25) / 2), (0.08, 0.08, 2.25 - Z_SOC), a + YAW))
    # porte au sud-ouest (derrière l'escalier), encadrement de cuivre, voyant
    a = math.radians(235) + YAW
    cc = yaw(c)
    p = (cc[0] + (R + 0.05) * math.cos(a), cc[1] + (R + 0.05) * math.sin(a), 0)
    lot.put(M["cuivre"], G.boite((p[0], p[1], Z_SOC + 0.6), (0.14, 0.82, 1.2), a))
    q = (cc[0] + (R + 0.11) * math.cos(a), cc[1] + (R + 0.11) * math.sin(a), 0)
    lot.put(M["noir"], G.boite((q[0], q[1], Z_SOC + 0.55), (0.06, 0.62, 1.08), a))
    q = (cc[0] + (R + 0.15) * math.cos(a), cc[1] + (R + 0.15) * math.sin(a), 0)
    lot.put(M["hublot"], G.boite((q[0], q[1], Z_SOC + 1.3), (0.06, 0.24, 0.08), a))
    # hublots du cryostat (2, différents)
    for (aa, z, rr_) in ((-math.pi / 2 - 0.75, 1.6, 0.13), (-math.pi / 2 + 0.8, 1.75, 0.09)):
        q = (CX + R * math.cos(aa), CY + R * math.sin(aa), z)
        O.hublot(lot, M["cuivre"], M["verre"], yaw(q), yaw((math.cos(aa), math.sin(aa), 0)), rr_)
    # col vers la sphère : brides et soufflet
    lot.put(M["acier"], G.tour([(2.35, 0.72), (3.35, 0.62)], 24, "z", yaw(c)))
    for z in (2.5, 2.75, 3.0):
        lot.put(M["cuivre"], G.tour([(z - 0.04, 0.82), (z + 0.04, 0.82)], 24, "z", yaw(c), cap0=True, cap1=True))
    # flexibles cryostat → dessous de la sphère (le vide ombré)
    for k in range(6):
        a = TAU * k / 6 + 0.3
        p0 = (CX + 1.15 * math.cos(a), CY + 1.15 * math.sin(a), 2.38)
        p2 = (CX + 1.3 * math.cos(a + 0.35), CY + 1.3 * math.sin(a + 0.35), CZ - math.sqrt(CR * CR - 1.69) + 0.05)
        p1 = G.add(G.lerp(p0, p2, 0.5), (0.35 * math.cos(a), 0.35 * math.sin(a), -0.25))
        O.flexible(lot, M["caout"] if k % 2 else M["cuivre_s"], [yaw(p0), yaw(p1), yaw(p2)], 0.065 if k % 3 else 0.09, pas=0.08)


def sphere(lot, M, r):
    c = yaw((CX, CY, CZ))
    lot.put(M["noir"], G.sphere(c, CR - 0.01, 48, 24))

    def surf(u, a, g):
        rr = CR + g
        return (c[0] + rr * math.sin(u) * math.cos(a), c[1] + rr * math.sin(u) * math.sin(a), c[2] + rr * math.cos(u))

    def mats(rr, um, am):
        if um > 1.95:
            return M["noire"]
        x = rr.f()
        if x < 0.07:
            return M["cuivre_s"]
        if x < 0.1:
            return M["noire"]
        return M["ceram"] if x < 0.55 else (M["ceram3"] if x < 0.8 else M["ceram2"])

    def saut(um, am):
        return um < 0.3
    us = K.stations(0.26, 2.75, 0.19, r, 0.2)
    K.plaques(lot, surf, us, 0.42, mats, r, gap=0.028, g=(0.025, 0.07), saut=saut, rivet=M["cuivre_s"])
    # méridiens et parallèles de cuivre (frettes)
    for k in range(8):
        a = TAU * k / 8 + 0.2
        pts = [surf(0.3 + (2.55 - 0.3) * i / 30.0, a, 0.085) for i in range(31)]
        lot.put(M["cuivre"], G.tube(pts, 0.055, 6))
    for u in (0.85, 2.3):
        zz = c[2] + (CR + 0.08) * math.cos(u)
        lot.put(M["cuivre"], tore((c[0], c[1], zz), (CR + 0.08) * math.sin(u), 0.06, 64, 6))
    # coupole du haut : bride lourde où l'épine la tient
    lot.put(M["cuivre"], G.tour([(c[2] + CR * 0.93, 0.95), (c[2] + CR * 0.98, 0.95), (c[2] + CR * 1.02, 0.7), (c[2] + CR * 1.04, 0.0)],
                                32, "z", (c[0], c[1], 0.0)))
    for k in range(12):
        a = TAU * k / 12
        lot.put(M["acier"], G.sphere((c[0] + 0.85 * math.cos(a), c[1] + 0.85 * math.sin(a), c[2] + CR * 0.985), 0.05, 6, 3))
    # hublots du cœur (le foyer fort) : 2 hublots ronds de tailles différentes, plus un petit voyant
    for (a, u, rr_, m) in ((-math.pi / 2 - 0.35, 1.25, 0.24, "coeur"), (-math.pi / 2 + 0.45, 1.35, 0.15, "coeur"),
                           (-math.pi / 2 + 1.25, 1.1, 0.07, "verre")):
        p = surf(u, a + YAW, 0.08)
        n = G.norm(G.sub(p, c))
        O.hublot(lot, M["cuivre"], M[m], p, n, rr_)
    # bouches d'injection et boîtiers sur la face sud
    for (a, u) in ((-math.pi / 2 - 1.0, 1.0), (-math.pi / 2 + 1.0, 0.95), (-math.pi / 2, 0.7)):
        p = surf(u, a + YAW, 0.07)
        n = G.norm(G.sub(p, c))
        lot.put(M["acier"], G.oriente(G.boite((0, 0, 0.12), (0.34, 0.26, 0.24)), p, n))
        lot.put(M["cuivre_s"], G.oriente(G.boite((0, 0, 0.26), (0.24, 0.16, 0.06)), p, n))


def tore_plasma(lot, M, r):
    c = yaw((CX, CY, TZ))
    # plasma (émissif) vu par la fenêtre du carter
    lot.put(M["plasma"], tore(c, TR, 0.24, 96, 10))
    # carter : tout le petit cercle sauf la fenêtre (de 15° à 62° au-dessus de l'horizontale, côté extérieur)
    b0, b1 = math.radians(62), math.radians(375)
    lot.put(M["ceram3"], tore(c, TR, TRC, 96, 24, b0, b1))
    lot.put(M["noire"], tore(c, TR, TRC - 0.02, 96, 10, math.radians(200), math.radians(340)))
    for b in (b0, b1):                                    # lèvres de cuivre de la fenêtre
        lot.put(M["cuivre"], tore((c[0], c[1], c[2] + TRC * math.sin(b)), TR + TRC * math.cos(b), 0.04, 96, 6))
    # brides de segment (24) et bobines en D (12)
    for k in range(24):
        th = TAU * k / 24 + YAW
        er = (math.cos(th), math.sin(th), 0.0)
        pts = []
        for i in range(17):
            b = b0 + (b1 - b0) * i / 16.0
            rr_ = TR + (TRC + 0.035) * math.cos(b)
            pts.append((c[0] + er[0] * rr_, c[1] + er[1] * rr_, c[2] + (TRC + 0.035) * math.sin(b)))
        lot.put(M["cuivre_s"], G.tube(pts, 0.035, 5, cap0=True, cap1=True))
    for k in range(12):
        th = TAU * (k + 0.5) / 12 + YAW
        er = (math.cos(th), math.sin(th), 0.0)

        def P(rad, z):
            return (c[0] + er[0] * rad, c[1] + er[1] * rad, c[2] + z)
        pts = []
        for i in range(15):
            b = math.radians(-100 + 200 * i / 14.0)
            pts.append(P(TR + 0.62 * math.cos(b), 0.62 * math.sin(b)))
        pts.append(P(TR - 0.5, 0.62 * math.sin(math.radians(100))))
        pts.append(P(TR - 0.5, -0.62 * math.sin(math.radians(100))))
        pts.append(pts[0])
        lot.put(M["cuivre"], G.tube(pts, 0.1, 4))
        lot.put(M["noir"], G.oriente(G.boite((0, 0, 0.0), (0.3, 0.22, 0.14)), P(TR + 0.7, 0.0), er))
        lot.put(M["acier"], G.oriente(G.boite((0, 0, 0.0), (0.22, 0.3, 0.1)), P(TR + 0.25, 0.66), (0, 0, 1)))
    # passerelle sous le tore : anneau de caillebotis, garde-corps extérieur, consoles
    zp = TZ - TRC - 0.55
    ring_in = [(c[0] + (TR - 0.35) * math.cos(TAU * i / 72), c[1] + (TR - 0.35) * math.sin(TAU * i / 72), zp) for i in range(72)]
    ring_out = [(c[0] + (TR + 0.55) * math.cos(TAU * i / 72), c[1] + (TR + 0.55) * math.sin(TAU * i / 72), zp) for i in range(72)]
    lot.put(M["grille"], G.loft([ring_in, ring_out, [G.add(p, (0, 0, -0.06)) for p in ring_out],
                                 [G.add(p, (0, 0, -0.06)) for p in ring_in]], closed=True))
    O.garde_corps(lot, M["acier"], ring_out + [ring_out[0]], h=0.34, pas=0.5, r=0.018)
    for k in range(12):
        th = TAU * k / 12 + YAW
        a = (c[0] + TR * math.cos(th), c[1] + TR * math.sin(th), zp - 0.04)
        b = (c[0] + TR * math.cos(th), c[1] + TR * math.sin(th), c[2] - TRC + 0.02)
        lot.put(M["acier"], G.tube([a, b], 0.05, 6))
    return zp


def trepied(lot, M, r, zp):
    """Trépied : 3 jambes de céramique et cuivre, vérins, sabots ; collier sous l'équateur."""
    c = (CX, CY)
    zc = 4.0
    rc = math.sqrt(CR * CR - (CZ - zc) ** 2)
    lot.put(M["cuivre"], tore(yaw((CX, CY, zc)), rc + 0.06, 0.13, 48, 8))
    for ang in (45, 135, 270):
        a = math.radians(ang)
        d = (math.cos(a), math.sin(a))
        foot = yaw((c[0] + 3.7 * d[0], c[1] + 3.7 * d[1], Z_SOC))
        top = yaw((c[0] + (rc + 0.1) * d[0], c[1] + (rc + 0.1) * d[1], zc))
        knee = yaw((c[0] + 3.4 * d[0], c[1] + 3.4 * d[1], 2.45))
        lot.put(M["ceram"], boite_ax(foot, knee, 0.42, 0.42))
        lot.put(M["ceram"], boite_ax(knee, top, 0.36, 0.36))
        lot.put(M["cuivre"], G.sphere(knee, 0.3, 12, 6))
        for t in (0.25, 0.6):
            lot.put(M["cuivre_s"], boite_ax(G.lerp(foot, knee, t - 0.04), G.lerp(foot, knee, t + 0.04), 0.48, 0.48))
        # vérin parallèle
        off = yaw((-d[1] * 0.32, d[0] * 0.32, 0.0))
        a0 = G.add(G.lerp(foot, knee, 0.15), off)
        a1 = G.add(G.lerp(knee, top, 0.7), off)
        lot.put(M["acier"], G.tube([a0, G.lerp(a0, a1, 0.55)], 0.09, 10))
        lot.put(M["cuivre"], G.tube([G.lerp(a0, a1, 0.5), a1], 0.055, 10))
        lot.put(M["noir"], G.prisme([(foot[0] - 0.45, foot[1] - 0.45), (foot[0] + 0.45, foot[1] - 0.45), (foot[0] + 0.45, foot[1] + 0.45),
                                     (foot[0] - 0.45, foot[1] + 0.45)], Z_SOC, Z_SOC + 0.25, top_scale=0.6))
        lot.put(M["caout"], G.tube(G.catmull([G.add(foot, (0, 0, 0.3)), G.add(knee, yaw((-d[1] * 0.25, d[0] * 0.25, -0.3))),
                                              G.add(top, (0, 0, -0.2))], 8), 0.04, 6))
    # rayons qui portent le tore depuis l'équateur de la sphère (cachés en partie)
    for k in range(6):
        a = TAU * (k + 0.5) / 6 + YAW
        p0 = yaw((CX, CY, 0.0))
        a0 = (p0[0] + (CR - 0.05) * math.cos(a), p0[1] + (CR - 0.05) * math.sin(a), TZ)
        a1 = (p0[0] + (TR - TRC + 0.05) * math.cos(a), p0[1] + (TR - TRC + 0.05) * math.sin(a), TZ)
        lot.put(M["acier"], boite_ax(a0, a1, 0.22, 0.3))
    O.echelle(lot, M["acier"], yaw((CX + TR * math.cos(math.radians(255)), CY + TR * math.sin(math.radians(255)) - 0.6, Z_SOC)),
              yaw((CX + TR * math.cos(math.radians(255)), CY + TR * math.sin(math.radians(255)) - 0.6, zp)))


def fleche(lot, M, r, pts):
    """Flèche de commandement sur l'apex de l'épine ; couronne de griffes qui tient la sphère."""
    apex = max(pts, key=lambda p: p[2])
    A = yaw(apex)
    top_s = yaw((CX, CY, CZ + CR * 1.03))
    for k in range(4):
        a = TAU * k / 4 + 0.6
        p = G.add(top_s, (0.72 * math.cos(a), 0.72 * math.sin(a), -0.05))
        lot.put(M["cuivre"], G.tube(G.coudee([p, G.add(p, (0, 0, 0.45)), G.lerp(A, G.add(A, (0, 0, -0.2)), 1.0)], 0.2, 4), 0.07, 6))
    z0 = A[2] + 0.2
    lot.put(M["ceram3"], G.tour([(z0 - 0.3, 0.42), (z0 + 0.35, 0.36), (z0 + 0.45, 0.28)], 16, "z", (A[0], A[1], 0.0), cap1=True))
    lot.put(M["cuivre"], G.tour([(z0 + 0.45, 0.32), (z0 + 0.55, 0.32)], 16, "z", (A[0], A[1], 0.0), cap0=True, cap1=True))
    lot.put(M["ceram"], G.tour([(z0 + 0.55, 0.22), (z0 + 1.6, 0.14)], 12, "z", (A[0], A[1], 0.0), cap1=True))
    for z in (z0 + 0.85, z0 + 1.25):
        lot.put(M["cuivre"], G.tour([(z - 0.04, 0.22), (z + 0.04, 0.22)], 12, "z", (A[0], A[1], 0.0)))
    lot.put(M["cuivre"], tore((A[0], A[1], z0 + 1.7), 0.3, 0.05, 24, 6))
    lot.put(M["balise"], G.sphere((A[0], A[1], z0 + 1.75), 0.13, 12, 6))
    lot.put(M["acier"], G.tube([(A[0], A[1], z0 + 1.85), (A[0], A[1], z0 + 3.0)], 0.035, 6))
    for (zz, w) in ((z0 + 2.2, 0.45), (z0 + 2.6, 0.3)):
        lot.put(M["acier"], G.tube([(A[0] - w, A[1], zz), (A[0] + w, A[1], zz)], 0.025, 5))
    # câbles de la flèche vers le crâne et la queue
    O.faisceau(lot, M["cable_r"], M["caout"], (A[0] + 0.2, A[1] - 0.2, z0 + 0.2), xf_crane((3.6, -0.6, 3.9)), fl=0.6, n=2)
    return z0 + 3.0


def injecteur(lot, M, r, th, L=2.4, appui=Z_SOC):
    """Injecteur de faisceau neutre : cylindre cerclé, source d'ions, soufflet vers le tore, tréteau."""
    a = th + YAW
    er = (math.cos(a), math.sin(a), 0.0)
    c = yaw((CX, CY, TZ))
    p0 = (c[0] + er[0] * (TR + 0.75), c[1] + er[1] * (TR + 0.75), TZ - 0.1)
    p1 = (c[0] + er[0] * (TR + 0.75 + L), c[1] + er[1] * (TR + 0.75 + L), TZ - 0.1)
    lot.put(M["ceram3"], G.oriente(G.tour([(0.0, 0.38), (L, 0.38)], 20, "z", cap0=True, cap1=True), p0, er))
    for i in range(6):
        t = 0.15 + 0.7 * i / 5
        lot.put(M["cuivre"], G.oriente(G.tour([(t * L - 0.05, 0.43), (t * L + 0.05, 0.43)], 20, "z", cap0=True, cap1=True), p0, er))
    lot.put(M["acier"], G.oriente(G.boite((0, 0, 0.0), (0.95, 0.95, 0.85)), G.add(p1, G.mul(er, 0.4)), er))
    lot.put(M["noir"], G.oriente(G.boite((0, 0, 0.0), (0.6, 0.6, 0.12)), G.add(p1, G.mul(er, 0.86)), er))
    O.flexible(lot, M["acier"], [G.add(p0, G.mul(er, 0.02)), G.add(p0, G.mul(er, -0.35)), G.add(p0, G.mul(er, -0.62))], 0.2, pas=0.06, n=6)
    # tréteau
    for t in (0.2, 0.85):
        q = G.lerp(p0, p1, t)
        side = (-er[1] * 0.4, er[0] * 0.4, 0.0)
        for sg in (-1, 1):
            f = (q[0] + sg * side[0], q[1] + sg * side[1], appui)
            lot.put(M["acier"], boite_ax(f, G.add(q, (0, 0, -0.35)), 0.11, 0.11))
        lot.put(M["acier"], G.oriente(G.boite((0, 0, 0), (0.9, 0.2, 0.18)), G.add(q, (0, 0, -0.38)), er))
    # boîtier et câbles
    O.faisceau(lot, M["cable_r"], M["caout"], G.add(p1, (0, 0, 0.3)), G.add(G.lerp(p0, p1, 0.4), (0, 0, 0.36)), fl=0.25, n=3)
    O.antenne(lot, M["acier"], None, G.add(p1, (0, 0, 0.43)), 0.5, 0.02, barres=1)
    return p0, p1


def halles(lot, M, r):
    """Halle A (sud-ouest, cryogénie) à toit en croupe de cuivre ; halle B (sud-est, alimentation des bobines) à
    toit plat de radiateurs et transformateurs."""
    # --- halle A
    x0, x1, y0, y1, z1 = -3.75, -2.2, -4.45, -2.55, 2.55
    C_ = yaw(((x0 + x1) / 2, (y0 + y1) / 2, 0))
    lot.put(M["ceram"], G.boite((C_[0], C_[1], (Z_SOC + z1) / 2), (x1 - x0, y1 - y0, z1 - Z_SOC), YAW))
    lot.put(M["cuivre_s"], G.boite((C_[0], C_[1], z1 + 0.04), (x1 - x0 + 0.16, y1 - y0 + 0.16, 0.08), YAW))
    poly = [yaw((x0 - 0.1, y0 - 0.1, 0)), yaw((x1 + 0.1, y0 - 0.1, 0)), yaw((x1 + 0.1, y1 + 0.1, 0)), yaw((x0 - 0.1, y1 + 0.1, 0))]
    lot.put(M["toit"], G.prisme([(p[0], p[1]) for p in poly], z1 + 0.08, z1 + 0.75, top_scale=0.35))
    for (x, w, h, z) in ((-3.4, 0.36, 0.42, 1.65), (-2.85, 0.24, 0.24, 1.9)):   # 2 fenêtres différentes, porte
        p = yaw((x, y0 - 0.02, z))
        lot.put(M["cuivre"], G.boite(p, (w + 0.1, 0.06, h + 0.1), YAW))
        lot.put(M["verre"], G.boite(G.add(p, yaw((0, -0.03, 0))), (w, 0.05, h), YAW))
    p = yaw((-2.45, y0 - 0.02, Z_SOC + 0.55))
    lot.put(M["cuivre"], G.boite(p, (0.6, 0.08, 1.12), YAW))
    lot.put(M["noir"], G.boite(G.add(p, yaw((0, -0.03, 0))), (0.46, 0.06, 1.02), YAW))
    c = yaw((-2.95, (y0 + y1) / 2 + 0.3, z1 + 0.5))
    O.grille(lot, M["acier"], M["noir"], (c[0], c[1], z1 + 0.42), 0.45, 0.35, 6, YAW)
    O.antenne(lot, M["acier"], None, yaw((-3.5, -3.1, z1 + 0.5)), 0.8, 0.025, barres=2)
    lot.put(M["cuivre"], G.tour([(z1 + 0.3, 0.16), (z1 + 1.1, 0.13), (z1 + 1.15, 0.18), (z1 + 1.22, 0.18)], 12, "z",
                                yaw((-2.45, -3.2, 0.0)), cap1=True))      # cheminée de ventilation
    # --- halle B
    x0, x1, y0, y1, z1 = 1.05, 3.1, -4.5, -2.6, 1.95
    C_ = yaw(((x0 + x1) / 2, (y0 + y1) / 2, 0))
    lot.put(M["ceram2"], G.boite((C_[0], C_[1], (Z_SOC + z1) / 2), (x1 - x0, y1 - y0, z1 - Z_SOC), YAW))
    lot.put(M["cuivre_s"], G.boite((C_[0], C_[1], z1 + 0.04), (x1 - x0 + 0.12, y1 - y0 + 0.12, 0.08), YAW))
    for i in range(9):                                       # radiateur du toit
        x = x0 + 0.2 + (x1 - x0 - 0.4) * (i + r.f(-0.15, 0.15)) / 8
        lot.put(M["ceram3"] if i % 3 else M["cuivre"], G.boite(yaw((x, -3.9, z1 + 0.3)), (0.05, 0.85, 0.42), YAW))
    for (x, y) in ((1.45, -2.95), (2.55, -2.95)):            # transformateurs
        c = yaw((x, y, z1 + 0.08))
        lot.put(M["acier"], G.boite((c[0], c[1], c[2] + 0.3), (0.55, 0.42, 0.6), YAW))
        for k in range(3):
            lot.put(M["ceram3"], G.tour([(c[2] + 0.6, 0.06), (c[2] + 0.9, 0.05), (c[2] + 0.92, 0.08)], 8, "z",
                                        (c[0] - 0.15 + 0.15 * k, c[1], 0.0), cap1=True))
    p = yaw((1.6, y0 - 0.02, Z_SOC + 0.5))
    lot.put(M["cuivre"], G.boite(p, (0.55, 0.08, 1.0), YAW))
    lot.put(M["noir"], G.boite(G.add(p, yaw((0, -0.03, 0))), (0.42, 0.06, 0.9), YAW))
    p = yaw((2.55, y0 - 0.02, 1.45))
    lot.put(M["cuivre"], G.boite(p, (0.4, 0.06, 0.28), YAW))
    lot.put(M["verre"], G.boite(G.add(p, yaw((0, -0.03, 0))), (0.3, 0.05, 0.2), YAW))
    # parabole sur la halle B
    dc = yaw((2.75, -3.6, z1 + 0.9))
    lot.put(M["acier"], G.tube([yaw((2.75, -3.6, z1 + 0.08)), dc], 0.05, 6))
    dish = G.tour([(0.0, 0.0), (0.06, 0.25), (0.15, 0.42), (0.17, 0.45)], 16, "z")
    lot.put(M["ceram3"], G.oriente(dish, dc, G.norm((-0.4, -0.6, 0.7))))


def reservoirs(lot, M, r):
    """Réservoirs d'hélium 3 (nord-ouest, couchés sur berceaux) et râtelier de bouteilles (nord-est)."""
    for (y, L) in ((3.6, 2.4), (4.2, 1.9)):
        x0 = -4.3
        p = yaw((x0, y, Z_SOC + 0.48))
        ax = yaw((1, 0, 0))
        prof = [(0.0, 0.0), (0.04, 0.26), (0.16, 0.39), (0.3, 0.42), (L - 0.3, 0.42), (L - 0.16, 0.39), (L - 0.04, 0.26), (L, 0.0)]
        lot.put(M["ceram"], G.oriente(G.tour(prof, 24, "z"), p, ax))
        for t in (0.35, L - 0.35):
            q = G.add(p, G.mul(ax, t))
            lot.put(M["cuivre"], G.oriente(G.tour([(-0.05, 0.5), (0.05, 0.5)], 24, "z"), q, ax))
            lot.put(M["acier"], G.boite((q[0], q[1], Z_SOC + 0.2), (0.16, 0.8, 0.4), YAW))
    for i in range(7):
        x = 0.2 + 0.3 * (i % 4)
        y = 3.3 + 0.42 * (i // 4)
        O.bouteille(lot, M["ceram3"] if i % 3 else M["cuivre_s"], M["cuivre"], yaw((x, y, Z_SOC)), r=0.13, h=1.0 + 0.1 * (i % 2))
    lot.put(M["acier"], G.boite(yaw((0.65, 3.5, Z_SOC + 0.85)), (1.4, 0.06, 0.06), YAW))


def tuyauterie(lot, M, r):
    """Tuyaux de cuivre sur 3 diamètres, à coudes et brides ; flexibles ; faisceaux de câbles ; pylônes."""
    T = lambda pts: [yaw(p) for p in pts]
    # gros : réservoirs → cryostat, halle A → nacelle sud
    O.tuyau(lot, M["cuivre"], M["acier"], T([(-1.9, 3.6, Z_SOC + 0.48), (-1.3, 3.6, Z_SOC + 0.48), (-1.3, 1.9, Z_SOC + 0.48),
                                            (-0.9, 1.2, Z_SOC + 0.48)]), 0.2)
    O.tuyau(lot, M["cuivre"], M["acier"], T([(-3.8, -3.6, 1.3), (-4.5, -3.6, 1.3), (-4.5, -3.25, 1.3), (-4.5, -2.92, 1.6)]), 0.18)
    # moyens : cryostat → passerelle (le long des jambes), halle B → injecteur sud-est
    O.tuyau(lot, M["cuivre_s"], M["acier"], T([(-1.45, -1.1, 1.3), (-2.3, -1.6, 1.3), (-2.3, -1.6, 3.9), (-2.2, -2.0, 4.15)]), 0.11)
    O.tuyau(lot, M["cuivre_s"], M["acier"], T([(0.75, -1.25, 1.1), (1.6, -1.9, 1.1), (1.6, -1.9, 3.95), (1.55, -2.25, 4.15)]), 0.11)
    O.tuyau(lot, M["cuivre"], M["acier"], T([(2.2, -2.6, 1.5), (2.2, -2.2, 1.5), (2.2, -2.2, 2.4), (2.5, -1.6, 2.4)]), 0.12)
    # petits : le long du socle et des halles
    O.tuyau(lot, M["cuivre"], M["acier"], T([(-3.6, -4.55, 1.15), (-2.3, -4.55, 1.15), (-2.3, -4.55, 0.95)]), 0.06, pas_bride=0.7)
    O.tuyau(lot, M["cuivre"], M["acier"], T([(0.4, -4.6, 1.0), (1.0, -4.6, 1.0)]), 0.06)
    O.tuyau(lot, M["vdg"], M["acier"], T([(-2.3, -2.6, 2.2), (-2.3, -1.9, 2.2), (-1.7, -1.3, 2.2)]), 0.07)
    O.tuyau(lot, M["cuivre"], M["acier"], T([(3.15, -2.7, 1.2), (3.15, -1.6, 1.2), (3.4, -1.2, 1.7)]), 0.06)
    O.tuyau(lot, M["cuivre_s"], M["acier"], T([(-3.5, 2.9, Z_SOC + 0.2), (-2.0, 2.4, Z_SOC + 0.2), (-1.6, 1.6, Z_SOC + 0.2)]), 0.08)
    # flexibles supplémentaires (annelés)
    O.flexible(lot, M["caout"], T([(-2.15, -3.0, 2.0), (-1.95, -2.4, 1.4), (-1.55, -1.3, 1.9)]), 0.07)
    O.flexible(lot, M["caout"], T([(1.1, -2.9, 1.7), (0.9, -2.2, 1.2), (0.65, -1.45, 1.6)]), 0.06)
    O.flexible(lot, M["cuivre_s"], T([(3.2, -0.9, 1.6), (2.8, -0.2, 0.95), (1.1, 0.4, 1.5)]), 0.08)
    O.flexible(lot, M["caout"], T([(-3.2, 2.6, 1.9), (-2.3, 2.2, 1.4), (-1.6, 1.2, 2.0)]), 0.07)
    # pylônes et faisceaux de câbles rouges et noirs (sud)
    tops = []
    for (x, y, h) in ((-5.6, -4.95, 2.4), (-0.9, -5.05, 2.0), (3.9, -4.6, 2.2)):
        b = yaw((x, y, 0.0))
        t = (b[0], b[1], h)
        lot.put(M["acier"], G.tube([b, t], 0.06, 6))
        lot.put(M["acier"], G.tube([G.add(t, (-0.35, 0, -0.1)), G.add(t, (0.35, 0, -0.1))], 0.03, 5))
        for sx in (-0.3, 0.3):
            lot.put(M["ceram3"], G.tour([(h - 0.1, 0.04), (h + 0.05, 0.035)], 8, "z", (t[0] + sx, t[1], 0.0), cap1=True))
        tops.append(t)
    O.faisceau(lot, M["cable_r"], M["caout"], G.add(tops[0], (0.3, 0, 0)), yaw((-3.75, -3.6, 2.45)), fl=0.4, n=3)
    O.faisceau(lot, M["cable_r"], M["caout"], G.add(tops[1], (-0.3, 0, 0)), yaw((-2.6, -3.9, 2.4)), fl=0.35, n=2)
    O.faisceau(lot, M["cable_r"], M["caout"], G.add(tops[1], (0.3, 0, 0)), yaw((1.2, -4.2, 1.9)), fl=0.3, n=3)
    O.faisceau(lot, M["cable_r"], M["caout"], G.add(tops[2], (-0.3, 0, 0)), yaw((3.0, -3.3, 1.95)), fl=0.25, n=2)
    O.faisceau(lot, M["cable_r"], M["caout"], yaw((-3.6, -2.55, 2.5)), yaw((-2.6, -1.9, 4.3)), fl=0.4, n=3)
    O.faisceau(lot, M["cable_r"], M["caout"], yaw((2.9, -2.7, 1.95)), xf_crane((3.2, -1.2, 2.4)), fl=0.3, n=2)
    O.faisceau(lot, M["cable_r"], M["caout"], xf_queue((-3.4, -0.9, 2.8)), yaw((-2.4, -1.7, 4.25)), fl=0.35, n=2)


def sol(lot, M, r):
    """Butte de terre sous le nez, plaques au sol, caisses, fûts, bouteilles, tourets, pièces de rechange (≥ 24)."""
    pos = [(4.0, -3.1), (4.5, -3.5), (4.6, -2.75), (5.3, -3.3), (-6.5, -4.0), (-6.0, -4.6), (-1.9, -5.2), (2.4, -5.3),
           (5.6, 2.9), (6.1, 3.4), (-6.9, 3.7), (0.9, 5.0)]
    for i, (x, y) in enumerate(pos):
        rz = r.f(-0.5, 0.5)
        if i % 3 == 0:
            O.caisse(lot, M["ceram2"] if i % 2 else M["vdg"], M["cuivre_s"], yaw((x, y, 0.0)), (0.5, 0.42, 0.38), rz)
            if i % 2:
                O.caisse(lot, M["acier"], M["cuivre_s"], yaw((x + 0.05, y + 0.02, 0.38)), (0.36, 0.3, 0.28), rz + 0.3)
        elif i % 3 == 1:
            for k in range(2 + i % 2):
                O.fut(lot, M["cuivre_s"] if k % 2 else M["jaune"], M["acier"], yaw((x + 0.36 * k, y + 0.1 * (k % 2), 0.0)))
        else:
            O.bouteille(lot, M["ceram3"], M["cuivre"], yaw((x, y, 0.0)), r=0.12, h=0.85, couche=True, rz=rz + YAW)
            O.bouteille(lot, M["ceram3"], M["cuivre"], yaw((x + 0.05, y + 0.32, 0.0)), r=0.12, h=0.85, couche=True, rz=rz + YAW + 0.2)
    O.bobine(lot, M["acier"], M["cable_r"], yaw((4.9, 3.4, 0.0)), rz=0.4)
    O.bobine(lot, M["acier"], M["cuivre"], yaw((-5.8, 3.0, 0.0)), r=0.28, rz=-0.3)
    # pièce de rechange : segment de bobine en D posé au sol, plaques de céramique empilées
    pts = [yaw((-6.4 + 0.5 * math.cos(math.radians(b)), -2.0, 0.1 + 0.5 + 0.5 * math.sin(math.radians(b)))) for b in range(-90, 91, 15)]
    lot.put(M["cuivre"], G.tube([(p[0], p[1], max(0.09, p[2] - 0.5)) for p in pts], 0.09, 4))
    for k in range(4):
        lot.put(M["ceram"] if k % 2 else M["noire"], G.boite(yaw((5.0, -4.3, 0.04 + 0.05 * k)), (0.5, 0.42, 0.045), YAW + 0.15 * k))
    for (x, y, rz) in ((-2.6, 5.0, 0.3), (3.7, 4.7, -0.4)):
        lot.put(M["noire"], G.boite(yaw((x, y, 0.03)), (0.7, 0.5, 0.06), rz))
    # escalier sud vers le socle
    x = -1.65
    n = 5
    for i in range(n):
        y = -5.55 + 0.85 * (i + 0.5) / n
        z = Z_SOC * (i + 1) / n
        lot.put(M["ceram2"], G.boite(yaw((x, y, z / 2)), (1.1, 0.85 / n + 0.02, z), YAW))
    for s in (-1, 1):
        O.garde_corps(lot, M["acier"], [yaw((x + s * 0.55, -5.55, 0.2)), yaw((x + s * 0.55, -4.7, Z_SOC + 0.05))], h=0.42, pas=0.4)


def echangeur(lot, M, r):
    """Échangeur de chaleur au nord-est (coin vide de l'emprise) : caisson de céramique, deux rangées d'ailettes,
    conduites de cuivre sur pilotis vers le cryostat, évents ; il fait monter la masse à droite derrière le crâne."""
    bx, by = 4.7, 3.7
    c = yaw((bx, by, 0.0))
    lot.put(M["ceram2"], G.boite((c[0], c[1], 0.55), (1.6, 1.7, 1.1), YAW))
    lot.put(M["cuivre_s"], G.boite((c[0], c[1], 1.13), (1.7, 1.8, 0.08), YAW))
    for row in (-0.45, 0.45):
        for i in range(9):
            x = bx - 0.7 + 1.4 * (i + r.f(-0.15, 0.15)) / 8
            h = 1.5 + 0.25 * math.sin(i * 1.7)
            q = yaw((x, by + row, 0.0))
            lot.put(M["ceram3"] if i % 3 else M["cuivre"], G.boite((q[0], q[1], 1.17 + h / 2), (0.06, 0.62, h), YAW))
    for row in (-0.45, 0.45):
        q = yaw((bx, by + row, 0.0))
        lot.put(M["cuivre"], G.boite((q[0], q[1], 1.3), (1.55, 0.08, 0.08), YAW))
    T = lambda pts: [yaw(p) for p in pts]
    O.tuyau(lot, M["cuivre"], M["acier"], T([(3.85, 3.3, 0.7), (3.0, 3.3, 0.7), (3.0, 2.2, 1.3), (1.2, 1.2, 1.3)]), 0.16)
    O.tuyau(lot, M["cuivre_s"], M["acier"], T([(3.85, 4.1, 0.9), (2.4, 4.1, 0.9), (2.4, 4.1, 1.6), (0.6, 4.1, 1.6), (-1.6, 4.1, 1.6)]), 0.1)
    O.tuyau(lot, M["vdg"], M["acier"], T([(5.5, 3.2, 0.5), (5.9, 3.2, 0.5), (5.9, 2.2, 0.5), (5.2, 1.4, 0.5)]), 0.08)
    for x in (2.4, 0.9, -0.6):
        q = yaw((x, 4.1, 0.0))
        lot.put(M["acier"], G.tube([(q[0], q[1], Z_SOC), (q[0], q[1], 1.5)], 0.05, 6))
    O.grille_v(lot, M["acier"], M["noir"], yaw((4.4, by - 0.87, 0.6)), 0.5, 0.4, 6, -1)
    O.grille_v(lot, M["acier"], M["noir"], yaw((5.1, by - 0.87, 0.6)), 0.4, 0.4, 5, -1)
    O.antenne(lot, M["acier"], M["balise"], yaw((5.35, 4.3, 1.17)), 1.3, 0.03, barres=2, lum=None)


def events(lot, M, r):
    """Évents et grilles supplémentaires (façades des halles, socle, nacelles)."""
    O.grille_v(lot, M["acier"], M["noir"], yaw((-3.05, -4.48, 1.45)), 0.4, 0.5, 6, -1)
    O.grille_v(lot, M["acier"], M["noir"], yaw((2.1, -4.53, 1.35)), 0.6, 0.35, 5, -1)
    O.grille_v(lot, M["acier"], M["noir"], yaw((2.9, -4.53, 1.15)), 0.3, 0.3, 4, -1)
    O.grille(lot, M["acier"], M["noir"], yaw((-1.4, -3.7, Z_SOC)), 0.6, 0.45, 7, YAW)
    O.grille(lot, M["acier"], M["noir"], yaw((0.9, -3.75, Z_SOC)), 0.5, 0.4, 6, YAW)
    O.grille(lot, M["acier"], M["noir"], yaw((-3.0, 1.8, Z_SOC)), 0.55, 0.5, 6, YAW + 0.3)
    for s in (-1, 1):
        p = xf_queue((-4.6, s * K.NAC_Y, K.NAC_Z + 1.0))
        O.grille(lot, M["acier"], M["noir"], (p[0], p[1], p[2] - 0.02), 0.5, 0.3, 6, YAW)
    p = xf_queue((-4.2, 0.0, K.ZC_Q + 1.0))
    O.grille(lot, M["acier"], M["noir"], (p[0], p[1], p[2] - 0.03), 0.45, 0.45, 5, YAW)


def cables_plus(lot, M, r, pts):
    """Faisceaux supplémentaires : épine → dérive, flèche → halle A, crâne → échangeur, poteaux du socle."""
    apex = yaw(max(pts, key=lambda p: p[2]))
    O.faisceau(lot, M["cable_r"], M["caout"], yaw((-4.4, 0.2, 4.6)), xf_queue((-5.6, 0.1, K.ZC_Q + 1.6)), fl=0.2, n=2)
    O.faisceau(lot, M["cable_r"], M["caout"], G.add(apex, (-0.25, -0.1, 0.0)), yaw((-3.0, -3.3, 3.2)), fl=0.9, n=2)
    O.faisceau(lot, M["cable_r"], M["caout"], xf_crane((3.5, 0.9, 3.6)), yaw((4.0, 3.2, 1.2)), fl=0.4, n=3)
    O.faisceau(lot, M["cable_r"], M["caout"], yaw((2.9, 4.1, 1.6)), yaw((1.3, 3.35, 1.9)), fl=0.15, n=2)
    O.faisceau(lot, M["cable_r"], M["caout"], yaw((-4.3, 3.6, 1.4)), yaw((-3.0, 2.7, 2.7)), fl=0.3, n=3)
    O.faisceau(lot, M["cable_r"], M["caout"], yaw((1.8, -4.6, 1.7)), yaw((3.0, -4.6, 1.7)), fl=0.12, n=2)
    for (x, y) in ((-4.1, 4.2), (3.0, 4.3), (3.1, -1.7)):
        q = yaw((x, y, 0.0))
        lot.put(M["acier"], G.tube([(q[0], q[1], Z_SOC), (q[0], q[1], 2.2)], 0.045, 6))
        lot.put(M["acier"], G.tube([(q[0] - 0.25, q[1], 2.1), (q[0] + 0.25, q[1], 2.1)], 0.025, 5))


def tuyaux_plus(lot, M, r):
    """Tuyaux supplémentaires (trois diamètres) pour la densité de la raffinerie : colonnes montantes le long des
    halles, nourrices du tore, purges."""
    T = lambda pts: [yaw(p) for p in pts]
    O.tuyau(lot, M["cuivre_s"], M["acier"], T([(-2.25, -2.6, 1.0), (-2.25, -2.6, 2.4), (-2.0, -2.3, 2.7)]), 0.06)
    O.tuyau(lot, M["cuivre"], M["acier"], T([(-3.7, -2.6, 1.0), (-3.7, -2.6, 2.3)]), 0.05)
    O.tuyau(lot, M["cuivre_s"], M["acier"], T([(1.1, -2.65, 1.0), (1.1, -2.65, 2.2), (0.9, -2.3, 2.4)]), 0.07)
    O.tuyau(lot, M["cuivre"], M["acier"], T([(3.05, -2.65, 1.0), (3.05, -2.65, 1.8)]), 0.05)
    O.tuyau(lot, M["cuivre"], M["acier"], T([(-1.0, -1.45, 2.38), (-1.6, -2.3, 2.6), (-1.6, -2.3, 4.0), (-1.4, -2.7, 4.25)]), 0.08)
    O.tuyau(lot, M["cuivre"], M["acier"], T([(0.3, -1.45, 2.38), (0.8, -2.4, 2.6), (0.8, -2.4, 4.0), (0.7, -2.8, 4.25)]), 0.08)
    O.tuyau(lot, M["acier"], M["cuivre"], T([(-4.5, 2.6, Z_SOC + 0.15), (-4.5, -2.4, Z_SOC + 0.15)]), 0.09, pas_bride=0.9)
    O.tuyau(lot, M["cuivre_s"], M["acier"], T([(3.2, 2.6, Z_SOC + 0.12), (3.2, -1.9, Z_SOC + 0.12)]), 0.07, pas_bride=0.8)
    O.tuyau(lot, M["cuivre"], M["acier"], T([(-0.2, 3.0, Z_SOC + 0.3), (-0.2, 1.5, Z_SOC + 0.3), (-0.3, 1.45, 1.6)]), 0.12)


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(1313)
    crane(lot, M, r)
    queue(lot, M, r)
    pts = squelette(lot, M, r)
    socle(lot, M, r)
    cryostat(lot, M, r)
    sphere(lot, M, r)
    zp = tore_plasma(lot, M, r)
    trepied(lot, M, r, zp)
    fleche(lot, M, r, pts)
    injecteur(lot, M, r, math.radians(232), L=2.1, appui=2.62)
    injecteur(lot, M, r, math.radians(-52), L=2.0, appui=1.95 + 0.05)
    halles(lot, M, r)
    reservoirs(lot, M, r)
    tuyauterie(lot, M, r)
    sol(lot, M, r)
    echangeur(lot, M, r)
    events(lot, M, r)
    cables_plus(lot, M, r, pts)
    tuyaux_plus(lot, M, r)
    return {}
