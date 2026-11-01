"""TROTTE-VAPEUR (robot 1, âge 3 Vapeur, assaut léger ; PLAN §2 : 4 pattes, chaudière ronde ; image 2 tuiles, boîte ±0,4).

Idée : une petite locomotive qui a appris à trotter. Chaudière de cuivre couchée, cheminée évasée à l'avant, boîte à fumée
en fonte dont le grand manomètre ambré fait office d'œil unique ; roues motrices à rayons aux épaules et aux hanches,
reliées de chaque côté par une bielle d'accouplement (les deux côtés au quart de tour, comme une vraie locomotive) ;
pistons de cuivre sur chaque patte ; régulateur à boules de Watt qui tourne sur le dos ; queue en tuyau de cuivre recourbé,
terminée par un sifflet. Deux courts canons jumelés sur les flancs. Allure : trot, paires diagonales.
Bible (DESIGN_EPOQUES, époque 3) : cuivre #8A5A3A, laiton #9C7E45, fonte #3A3634, lueur ambrée #FFC060, luminance 58.
"""
import math

import formes as F
import geo as G
import marionette as Mr

CAP = math.radians(-146.0)      # face à la caméra, vers le sud-ouest : la lumière vient de l'ouest (F47), la face est éclairée
ECH = 1.2                       # échelle de tout le robot (image de 2 tuiles environ, boîte inchangée)
Z0 = 1.2
HX, HY, HZ = 0.40, 0.335, -0.13     # hanches, repère du corps
L1, L2 = 0.52, 0.66
PAS, BETA, LEVE = 0.96, 0.58, 0.17
PIED_Z = 0.03
ROUE_R, ROUE_Y = 0.205, 0.415
MANETON = 0.115
PATTES = (("ag", 1.0, 1.0, 0.0), ("ad", 1.0, -1.0, 0.5), ("rg", -1.0, 1.0, 0.5), ("rd", -1.0, -1.0, 0.0))
IMAGES = 8


def matieres(S):
    import mat as MT
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.14, ra=0.22, ec=0.32, nu_k=1.4, ec_col=(0.03, 0.017, 0.008), sans=("laiton",))
    cr = (0.012, 0.009, 0.006)
    M = {}
    M["cuivre"] = F.surf("rb3_cuivre", (0.62, 0.27, 0.105), rough=0.36, met=0.45, tole=(0.26, 0.17), joint=0.45, joint_l=0.012, var=0.16,
                         coulures=0.7, rouille=(0.05, 0.17, 0.11), usure=0.55, nu=(0.95, 0.62, 0.36), crasse=0.65, crasse_col=cr,
                         relief=0.6, graine=301)
    M["cuivre2"] = F.surf("rb3_cuivre2", (0.7, 0.3, 0.12), rough=0.33, met=0.5, coulures=0.5, rouille=(0.05, 0.17, 0.11), usure=0.6,
                          nu=(0.72, 0.45, 0.26), crasse=0.7, crasse_col=cr, graine=302)
    M["laiton"] = F.surf("rb3_laiton", (0.72, 0.5, 0.15), rough=0.3, met=0.5, usure=0.5, nu=(0.8, 0.65, 0.34), crasse=0.65, crasse_col=cr,
                         coulures=0.2, graine=303)
    M["fonte"] = F.surf("rb3_fonte", (0.075, 0.066, 0.06), rough=0.62, met=0.5, usure=0.75, nu=(0.25, 0.235, 0.22), crasse=0.8, crasse_col=cr,
                        coulures=0.45, rouille=(0.11, 0.05, 0.022), graine=304)
    M["fonte2"] = F.surf("rb3_fonte2", (0.13, 0.112, 0.1), rough=0.55, met=0.55, usure=0.8, nu=(0.32, 0.3, 0.27), crasse=0.8, crasse_col=cr,
                         coulures=0.45, rouille=(0.13, 0.055, 0.025), graine=305)
    M["suie"] = F.surf("rb3_suie", (0.009, 0.008, 0.008), rough=0.8, met=0.2, usure=0.0, crasse=0.6, crasse_col=(0.003, 0.003, 0.003), graine=306)
    M["acier"] = F.surf("rb3_acier", (0.34, 0.33, 0.31), rough=0.3, met=0.95, usure=0.3, crasse=0.5, crasse_col=cr, graine=307)
    M["riv"] = F.surf("rb3_riv", (0.30, 0.17, 0.06), rough=0.45, met=0.7, usure=0.3, crasse=0.4, graine=308)
    M["rouge"] = F.surf("rb3_rouge", (0.36, 0.022, 0.012), rough=0.5, met=0.1, usure=0.5, nu=(0.5, 0.3, 0.2), crasse=0.5, graine=309)
    M["verre"] = MT.verre("rb3_verre", col=(0.05, 0.035, 0.015), reflet=(0.5, 0.4, 0.22))
    M["cadran"] = MT.lumiere(S, "rb3_cadran", (1.0, 0.56, 0.14), 1.25, main=0.5)
    M["feu"] = MT.lumiere(S, "rb3_feu", (1.0, 0.36, 0.05), 1.7, main=0.5)
    return M


def squelette(phase):
    sq = Mr.Squelette()
    ph = 0.0 if phase is None else phase
    bat = 0.0 if phase is None else 1.0
    a = G.TAU * ph
    bob = bat * 0.024 * math.cos(2.0 * a)
    tangage = bat * 0.035 * math.sin(a)
    roulis = bat * 0.03 * math.sin(a + 0.6)
    sq.os("racine", None, Mr.chaine(Mr.rz(CAP), Mr.ech(ECH)))
    m_corps = Mr.chaine(Mr.tr(0.0, 0.0, Z0 + bob), Mr.ry(tangage), Mr.rx(roulis))
    sq.os("corps", "racine", m_corps)
    sq.os("regul", "corps", Mr.autour((-0.3, 0.0, 0.0), Mr.rz(a * 3.0 + 0.5)))
    sq.os("queue", "corps", Mr.autour((-0.62, 0.0, 0.14), Mr.ry(bat * 0.09 * math.sin(2.0 * a))))
    for cote, nom, dec in ((1.0, "g", 0.0), (-1.0, "d", math.pi / 2.0)):
        tour_ = -a * 2.0 + dec    # 2 tours de roue par cycle : les bielles se lisent en mouvement
        for av, n2 in ((1.0, "a"), (-1.0, "r")):
            sq.os("roue_%s%s" % (n2, nom), "corps", Mr.chaine(Mr.tr(av * HX, cote * ROUE_Y, HZ), Mr.ry(tour_)))
        sq.os("bielle_" + nom, "corps", Mr.tr(MANETON * math.cos(tour_), 0.0, -MANETON * math.sin(tour_)))
    for nom, av, cote, dec in PATTES:
        dx, dz, appui, u = Mr.pied(phase, dec, PAS, BETA, LEVE)
        h = Mr.app(m_corps, (av * HX, cote * HY, HZ))
        p = (av * HX + 0.03 * av + dx, cote * (HY + 0.02), PIED_Z + dz)
        g, tendu = Mr.ik2(h, p, L1, L2, (av, 0.0, 0.12))
        sq.os("cuisse_" + nom, "racine", Mr.repere(h, G.sub(g, h)))
        sq.os("tibia_" + nom, "racine", Mr.repere(g, G.sub(p, g)))
        incl = 0.0 if appui else -0.75 * math.sin(math.pi * u) * 1.0
        sq.os("sabot_" + nom, "racine", Mr.chaine(Mr.tr(p[0], p[1], p[2]), Mr.ry(incl)))
        # piston : du corps à un point du tibia
        pa = Mr.app(m_corps, (av * (HX - 0.2), cote * (HY - 0.015), HZ + 0.13))
        pb = G.lerp(g, p, 0.27)
        d = G.sub(pb, pa)
        sq.os("cyl_" + nom, "racine", Mr.repere(pa, d))
        sq.os("tige_" + nom, "racine", Mr.repere(pb, G.mul(d, -1.0)))
        sq.marques[nom] = {"pied": p, "appui": appui, "tendu": tendu}
    return sq


def _cuisse(L1_):
    return F.poutre([(-0.09, 0.075, 0.13), (0.0, 0.085, 0.17), (0.2, 0.075, 0.115), (L1_ - 0.05, 0.065, 0.08), (L1_ + 0.05, 0.065, 0.095)])


def modele(lots, M, r):
    c = lots("corps")
    # ---------------------------------------------------------------------------- chaudière et ses deux fonds
    c.put(M["cuivre"], G.tour([(-0.40, 0.335), (0.30, 0.325)], 36, "x"))
    c.put(M["fonte"], G.tour([(0.30, 0.0), (0.30, 0.335), (0.32, 0.365), (0.56, 0.365), (0.60, 0.345), (0.625, 0.30), (0.635, 0.0)], 36, "x"))
    c.put(M["fonte2"], G.tour([(-0.40, 0.0), (-0.40, 0.355), (-0.42, 0.38), (-0.60, 0.38), (-0.645, 0.33), (-0.665, 0.22), (-0.67, 0.0)], 36, "x"))
    for x, re_, w in ((-0.385, 0.358, 0.05), (-0.17, 0.35, 0.036), (0.05, 0.347, 0.036), (0.27, 0.349, 0.05)):
        c.put(M["laiton"], F.bague((x, 0.0, 0.0), 0.3, re_, w, "x", 36, 0.006))
    for x, rr_, n in ((-0.385, 0.358, 22), (-0.17, 0.35, 20), (0.05, 0.347, 20), (0.27, 0.349, 22), (0.335, 0.365, 22), (0.54, 0.365, 22), (-0.44, 0.38, 22),
                      (-0.58, 0.38, 22)):
        c.put(M["riv"], F.rivets_anneau(x, rr_, n, 0.5))
    # ---------------------------------------------------------------------------- porte de boîte à fumée, le grand manomètre
    xp = 0.63
    c.put(M["fonte2"], F.bague((xp, 0.0, 0.0), 0.2, 0.3, 0.035, "x", 32, 0.008))
    c.put(M["laiton"], F.tore((xp + 0.02, 0.0, 0.0), 0.2, 0.024, "x", 32))
    c.put(M["suie"], F.disque((xp + 0.012, 0.0, 0.0), 0.195, 0.02, "x", 32))
    c.put(M["cadran"], F.disque((xp + 0.02, 0.0, 0.0), 0.168, 0.012, "x", 32))
    for i in range(9):      # graduations
        a = math.radians(-120 + 30 * i + 90)
        c.put(M["suie"], G.boite((xp + 0.027, 0.135 * math.cos(a), 0.135 * math.sin(a)), (0.004, 0.018, 0.038), 0.0, a - math.pi / 2.0))
    c.put(M["suie"], G.boite((xp + 0.031, -0.035, 0.05), (0.006, 0.02, 0.14), 0.0, 0.62))
    c.put(M["laiton"], F.disque((xp + 0.034, 0.0, 0.0), 0.022, 0.012, "x", 12))
    for s in (1.0, -1.0):
        c.put(M["fonte"], G.boite((xp + 0.01, s * 0.3, 0.075), (0.03, 0.09, 0.03)))
        c.put(M["fonte"], G.boite((xp + 0.01, s * 0.3, -0.075), (0.03, 0.09, 0.03)))
    # chasse-pierres à l'avant, sous la porte : profil de locomotive, se lit de loin
    for i in range(7):
        y = -0.21 + 0.07 * i
        c.put(M["fonte2"], F.bielle((0.60, y * 0.9, -0.34), (0.82, y * 0.36, -0.58), 0.032, 0.022))
    c.put(M["fonte2"], F.bielle((0.82, -0.09, -0.585), (0.82, 0.09, -0.585), 0.04, 0.03))
    c.put(M["laiton"], F.bielle((0.60, -0.2, -0.33), (0.60, 0.2, -0.33), 0.035, 0.035))
    # ---------------------------------------------------------------------------- cheminée à collerette (ronde, évasée) : le signe de l'âge
    xc = 0.42
    prof = [(0.0, 0.135), (0.035, 0.15), (0.055, 0.105), (0.15, 0.09), (0.38, 0.082), (0.46, 0.1), (0.56, 0.17), (0.61, 0.215), (0.655, 0.225),
            (0.67, 0.205), (0.66, 0.175), (0.5, 0.075), (0.42, 0.06)]
    c.put(M["fonte"], G.tour(prof, 28, "z", (xc, 0.0, 0.335), cap1=True))
    c.put(M["laiton"], F.bague((xc, 0.0, 0.335 + 0.25), 0.082, 0.103, 0.03, "z", 28, 0.006))
    c.put(M["laiton"], F.bague((xc, 0.0, 0.335 + 0.655), 0.198, 0.235, 0.022, "z", 28, 0.005))
    c.put(M["suie"], F.disque((xc, 0.0, 0.335 + 0.56), 0.13, 0.02, "z", 20))
    # ---------------------------------------------------------------------------- dôme de vapeur, soupape, sifflet
    xd = 0.02
    c.put(M["laiton"], G.tour([(0.0, 0.17), (0.03, 0.155), (0.055, 0.125), (0.13, 0.118), (0.175, 0.095), (0.205, 0.05), (0.218, 0.0)], 24, "z",
                              (xd, 0.0, 0.31)))
    c.put(M["fonte"], F.bague((xd, 0.0, 0.33), 0.12, 0.17, 0.028, "z", 24, 0.006))
    c.put(M["riv"], G.rivets_le_long([((xd + 0.15 * math.cos(G.TAU * i / 12), 0.15 * math.sin(G.TAU * i / 12), 0.346), (0, 0, 1)) for i in range(12)], 0.012, 0.008))
    c.put(M["laiton"], F.disque((xd, 0.0, 0.54), 0.012, 0.06, "z", 8))
    c.put(M["rouge"], F.disque((xd, 0.0, 0.575), 0.038, 0.02, "z", 12))
    # soupape à levier
    xs = 0.2
    c.put(M["acier"], F.disque((xs, 0.0, 0.37), 0.03, 0.09, "z", 10))
    c.put(M["laiton"], G.sphere((xs, 0.0, 0.42), 0.035, 10, 5))
    c.put(M["fonte"], F.bielle((xs - 0.13, 0.0, 0.415), (xs + 0.03, 0.0, 0.44), 0.016, 0.016))
    c.put(M["rouge"], G.sphere((xs - 0.14, 0.0, 0.415), 0.022, 8, 4))
    # manomètre secondaire sur le flanc, côté caméra
    for s in (1.0, -1.0):
        p = (-0.14, s * 0.335, 0.17)
        c.put(M["laiton"], F.pose(F.disque((0.0, 0.0, 0.0), 0.062, 0.03, "x", 16), p, (0.0, s * 0.89, 0.46)))
        c.put(M["cadran"], F.pose(F.disque((0.018, 0.0, 0.0), 0.046, 0.006, "x", 16), p, (0.0, s * 0.89, 0.46)))
        # hublot du foyer
        c.put(M["fonte"], F.pose(F.disque((0.0, 0.0, 0.0), 0.075, 0.04, "x", 16), (-0.52, s * 0.37, 0.03), (0.0, s, 0.1)))
        c.put(M["feu"], F.pose(F.disque((0.022, 0.0, 0.0), 0.05, 0.01, "x", 16), (-0.52, s * 0.37, 0.03), (0.0, s, 0.1)))
    # ---------------------------------------------------------------------------- tuyaux de cuivre coudés, du dôme aux cylindres
    for s in (1.0, -1.0):
        for ctrl in ([(xd + 0.09, s * 0.08, 0.4), (xd + 0.14, s * 0.31, 0.28), (0.2, s * 0.38, 0.12), (0.2, s * 0.385, 0.0)],
                     [(xd - 0.09, s * 0.08, 0.4), (xd - 0.15, s * 0.31, 0.28), (-0.2, s * 0.38, 0.12), (-0.2, s * 0.385, 0.0)]):
            c.put(M["cuivre2"], G.tube(G.coudee(ctrl, 0.09, 5), 0.021, 8))
        c.put(M["cuivre2"], G.tube([(-0.35, s * 0.385, 0.0), (0.35, s * 0.385, 0.0)], 0.03, 10))
        for x in (-0.35, -0.2, 0.2, 0.35):
            c.put(M["laiton"], F.bague((x, s * 0.385, 0.0), 0.03, 0.04, 0.03, "x", 10, 0.004))
        # canons jumelés, courts, bas sur le flanc
        for dz in (0.035, -0.035):
            yc = s * 0.44
            c.put(M["fonte"], F.disque((0.42, yc, -0.31 + dz), 0.03, 0.56, "x", 10))
            c.put(M["suie"], F.disque((0.71, yc, -0.31 + dz), 0.019, 0.006, "x", 8))
            c.put(M["laiton"], F.bague((0.685, yc, -0.31 + dz), 0.03, 0.037, 0.035, "x", 10, 0.004))
            c.put(M["laiton"], F.bague((0.5, yc, -0.31 + dz), 0.03, 0.036, 0.02, "x", 10, 0.004))
        c.put(M["fonte2"], G.boite((0.22, s * 0.44, -0.31), (0.2, 0.1, 0.17)))
        c.put(M["riv"], F.rivets_ligne((0.14, s * 0.492, -0.26), (0.3, s * 0.492, -0.26), 4, (0, s, 0)))
        c.put(M["cuivre2"], G.tube(G.coudee([(0.14, s * 0.44, -0.24), (0.1, s * 0.42, -0.14), (0.15, s * 0.385, -0.02)], 0.05, 4), 0.014, 6))
        # bras et palier des roues
        for av in (1.0, -1.0):
            c.put(M["fonte"], F.disque((av * HX, s * 0.35, HZ), 0.1, 0.09, "y", 16))
    # corps bas : caisson à charbon, sous la chaudière (lit la masse entre les pattes)
    c.put(M["fonte"], G.boite((-0.02, 0.0, -0.32), (0.62, 0.42, 0.16)))
    c.put(M["fonte2"], G.boite((-0.02, 0.0, -0.405), (0.5, 0.3, 0.05)))
    # lanterne arrière
    c.put(M["fonte"], F.disque((-0.66, 0.0, 0.2), 0.05, 0.08, "x", 12))
    c.put(M["feu"], F.disque((-0.70, 0.0, 0.2), 0.036, 0.01, "x", 12))
    # ---------------------------------------------------------------------------- régulateur à boules de Watt, sur le dos, tourne
    x0 = -0.3
    b = lots("regul")
    c.put(M["fonte"], F.disque((x0, 0.0, 0.345), 0.06, 0.03, "z", 12))
    b.put(M["acier"], F.disque((x0, 0.0, 0.54), 0.012, 0.38, "z", 8))
    b.put(M["laiton"], F.disque((x0, 0.0, 0.59), 0.03, 0.022, "z", 10))
    b.put(M["laiton"], G.sphere((x0, 0.0, 0.735), 0.018, 8, 4))
    for s in (1.0, -1.0):
        b.put(M["acier"], F.bielle((x0, 0.0, 0.72), (x0, s * 0.145, 0.555), 0.012, 0.012))
        b.put(M["acier"], F.bielle((x0, 0.0, 0.59), (x0, s * 0.08, 0.63), 0.009, 0.009))
        b.put(M["laiton"], G.sphere((x0, s * 0.155, 0.545), 0.05, 12, 6))
    # ---------------------------------------------------------------------------- queue : tuyau recourbé, sifflet au bout
    q = lots("queue")
    ctrl = [(-0.645, 0.0, 0.12), (-0.8, 0.0, 0.1), (-0.93, 0.0, 0.2), (-0.96, 0.0, 0.38), (-0.87, 0.0, 0.5), (-0.76, 0.0, 0.46)]
    pts = G.catmull(ctrl, 6)
    q.put(M["cuivre2"], G.tube(pts, 0.026, 8, rfun=lambda s, i: 0.03 - 0.009 * i / float(len(pts))))
    for i in (5, 14, 22):
        q.put(M["laiton"], F.pose(F.bague((0.0, 0.0, 0.0), 0.024, 0.036, 0.022, "x", 10, 0.003), pts[i], G.sub(pts[i + 1], pts[i])))
    q.put(M["laiton"], F.pose(G.tour([(0.0, 0.022), (0.05, 0.026), (0.1, 0.05), (0.115, 0.058)], 10, "x"), pts[-1], G.sub(pts[-1], pts[-2])))
    # ---------------------------------------------------------------------------- roues motrices à rayons, bielles d'accouplement
    for s, nom in ((1.0, "g"), (-1.0, "d")):
        for av, n2 in ((1.0, "a"), (-1.0, "r")):
            w = lots("roue_%s%s" % (n2, nom))
            w.put(M["fonte2"], F.bague((0.0, 0.0, 0.0), ROUE_R - 0.04, ROUE_R, 0.05, "y", 28, 0.008))
            w.put(M["fonte"], F.disque((0.0, 0.0, 0.0), 0.048, 0.07, "y", 14))
            w.put(M["laiton"], F.disque((0.0, s * 0.036, 0.0), 0.022, 0.012, "y", 10))
            for i in range(8):
                a = G.TAU * i / 8
                w.put(M["fonte2"], F.bielle((0.04 * math.cos(a), 0.0, 0.04 * math.sin(a)), ((ROUE_R - 0.03) * math.cos(a), 0.0, (ROUE_R - 0.03) * math.sin(a)), 0.024, 0.016))
            # contrepoids et maneton
            w.put(M["fonte"], G.boite((-0.115, 0.0, 0.0), (0.09, 0.04, 0.12)))
            w.put(M["laiton"], F.disque((MANETON, s * 0.03, 0.0), 0.026, 0.05, "y", 10))
        bi = lots("bielle_" + nom)
        yb = s * (ROUE_Y + 0.056)
        bi.put(M["acier"], F.bielle((-HX - 0.03, yb, HZ), (HX + 0.03, yb, HZ), 0.018, 0.042))
        for av in (1.0, -1.0):
            bi.put(M["acier"], F.disque((av * HX, yb, HZ), 0.04, 0.024, "y", 12))
            bi.put(M["laiton"], F.disque((av * HX, yb + s * 0.014, HZ), 0.018, 0.012, "y", 8))
    # ---------------------------------------------------------------------------- pattes
    for nom, av, cote, dec in PATTES:
        cu = lots("cuisse_" + nom)
        cu.put(M["fonte"], _cuisse(L1))
        cu.put(M["fonte2"], F.disque((0.0, 0.0, 0.0), 0.075, 0.11, "y", 14))
        cu.put(M["fonte2"], F.disque((L1, 0.0, 0.0), 0.058, 0.1, "y", 12))
        cu.put(M["laiton"], F.disque((L1, 0.0, 0.0), 0.028, 0.116, "y", 10))
        cu.put(M["riv"], F.rivets_ligne((0.07, 0.04, 0.0), (L1 - 0.09, 0.034, 0.0), 4, (0, 1, 0), 0.012))
        cu.put(M["riv"], F.rivets_ligne((0.07, -0.04, 0.0), (L1 - 0.09, -0.034, 0.0), 4, (0, -1, 0), 0.012))
        ti = lots("tibia_" + nom)
        ti.put(M["fonte2"], F.poutre([(0.0, 0.058, 0.082), (0.14, 0.05, 0.062), (L2 - 0.1, 0.038, 0.04), (L2 - 0.02, 0.046, 0.05)]))
        ti.put(M["laiton"], F.bague((L2 * 0.27, 0.0, 0.0), 0.028, 0.044, 0.025, "x", 10, 0.004))
        ti.put(M["cuivre2"], F.bague((L2 - 0.07, 0.0, 0.0), 0.02, 0.036, 0.03, "x", 10, 0.004))
        sa = lots("sabot_" + nom)
        sa.put(M["fonte"], G.tour([(0.0, 0.07), (0.016, 0.085), (0.04, 0.078), (0.07, 0.05), (0.11, 0.032), (0.13, 0.028)], 14, "z", cap1=True))
        sa.put(M["laiton"], F.bague((0.0, 0.0, 0.045), 0.055, 0.076, 0.012, "z", 14, 0.003))
        sa.put(M["acier"], G.boite((0.045, 0.0, 0.01), (0.08, 0.08, 0.018), 0.0))
        cy = lots("cyl_" + nom)
        cy.put(M["cuivre2"], F.disque((0.085, 0.0, 0.0), 0.04, 0.17, "x", 12))
        cy.put(M["laiton"], F.bague((0.015, 0.0, 0.0), 0.04, 0.05, 0.022, "x", 12, 0.004))
        cy.put(M["laiton"], F.bague((0.17, 0.0, 0.0), 0.04, 0.05, 0.022, "x", 12, 0.004))
        tg = lots("tige_" + nom)
        tg.put(M["acier"], F.disque((0.25, 0.0, 0.0), 0.014, 0.5, "x", 8))
        tg.put(M["fonte"], F.disque((0.0, 0.0, 0.0), 0.026, 0.05, "y", 10))
