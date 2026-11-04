"""CHANFREIN (robot 6, âge 9 Atome, artillerie, classe G). Idée : une tour de refroidissement qui marche : caisse de plomb octogonale à chanfreins, portée par 6 courtes pattes à vérins, et au milieu, un énorme mortier
vertical en hyperboloïde de béton, légèrement incliné, dont la gueule luit vert uranium. Bandes jaunes d'avertissement, hublots, conduits annelés, balises. Bible : plomb #4A5058, jaune #C9A227, béton #7A7670, vert #5CFF4A."""
import math

import formes as F
import gamme as Ga
import geo as G
import marionette as Mr

CAP = math.radians(-146.0)
Z0 = 1.05
PAS, BETA, LEVE = 0.86, 0.7, 0.16
L1, L2 = 0.68, 0.74
A8 = math.pi / 8.0
TABLE = tuple((n, (hx, hy, -0.16), (hx * 1.28, hy * 1.45), d, (0.25 * (1 if hx > 0 else -1 if hx < 0 else 0), (1 if hy > 0 else -1), 0.7))
              for n, hx, hy, d in (("ag", 0.92, 0.72, 0.0), ("mg", 0.0, 1.0, 1.0 / 3.0), ("rg", -0.92, 0.72, 2.0 / 3.0),
                                   ("ad", 0.92, -0.72, 1.0 / 2.0), ("md", 0.0, -1.0, 5.0 / 6.0), ("rd", -0.92, -0.72, 1.0 / 6.0)))


def matieres(S):
    import mat as MT
    Ga.patine(ta=0.15, ra=0.25, ec=0.42, nu_k=1.45, ec_col=(0.03, 0.03, 0.028))
    cr = (0.008, 0.008, 0.008)
    sf = F.surf
    M = {}
    M["plomb"] = sf("rb9_plomb", (0.115, 0.13, 0.15), rough=0.5, met=0.45, tole=(0.5, 0.3), joint=0.45, joint_l=0.01, var=0.1, coulures=0.5, rouille=(0.1, 0.06, 0.03), usure=0.7, nu=(0.46, 0.48, 0.5), crasse=0.8, crasse_col=cr, relief=0.5, graine=901)
    M["plomb2"] = sf("rb9_plomb2", (0.16, 0.18, 0.2), rough=0.45, met=0.45, coulures=0.4, usure=0.7, nu=(0.52, 0.54, 0.56), crasse=0.75, crasse_col=cr, graine=902)
    M["beton"] = sf("rb9_beton", (0.2, 0.185, 0.165), rough=0.9, met=0.0, tole=(0.9, 0.2), joint=0.65, joint_l=0.007, var=0.08, coulures=0.7, rouille=(0.08, 0.07, 0.06), usure=0.4, nu=(0.38, 0.36, 0.33), crasse=0.8, crasse_col=cr, relief=0.5, grain=0.14, graine=903)
    M["chevron"] = sf("rb9_chevron", (0.56, 0.36, 0.03), rough=0.5, met=0.2, bandes=(0.3, (0.014, 0.013, 0.012), 0.5), usure=0.7, nu=(0.5, 0.48, 0.42), crasse=0.65, crasse_col=cr, coulures=0.4, graine=904)
    M["jaune"] = sf("rb9_jaune", (0.58, 0.37, 0.03), rough=0.48, met=0.2, usure=0.65, nu=(0.55, 0.52, 0.45), crasse=0.65, crasse_col=cr, graine=905)
    M["peint"] = sf("rb9_peint", (0.52, 0.5, 0.42), rough=0.45, met=0.25, usure=0.6, nu=(0.72, 0.7, 0.62), crasse=0.5, crasse_col=cr, graine=906)
    M["peint"]["fo_teinte"] = 1
    M["noir"] = sf("rb9_noir", (0.013, 0.013, 0.014), rough=0.6, met=0.4, usure=0.2, crasse=0.4, graine=907)
    M["riv"] = sf("rb9_riv", (0.25, 0.26, 0.27), rough=0.4, met=0.7, usure=0.3, crasse=0.4, graine=908)
    M["acier"] = sf("rb9_acier", (0.32, 0.33, 0.35), rough=0.28, met=0.75, usure=0.4, nu=(0.7, 0.72, 0.74), crasse=0.55, crasse_col=cr, graine=909)
    M["verre"] = MT.verre("rb9_verre", col=(0.01, 0.03, 0.012), reflet=(0.14, 0.26, 0.15))
    M["uranium"] = S.mat_emissive("rb9_uranium", (0.11, 1.0, 0.07), strength=1.7, base=(0.01, 0.05, 0.008), main_scale=0.55, crust=(5.0, 0.4, 3.0))
    M["hublot"] = MT.lumiere(S, "rb9_hublot", (0.11, 1.0, 0.07), 1.3, main=0.5)
    M["balise"] = MT.lumiere(S, "rb9_balise", (1.0, 0.65, 0.05), 1.5, main=0.5)
    return M


def squelette(phase, cap=CAP, pas=PAS):
    sq = Mr.Squelette()
    sq.os("racine", None, Mr.rz(cap))
    a, m = Ga.corps_marche(phase, Z0, bob=0.022, tangage=0.018, roulis=0.022)
    sq.os("corps", "racine", m)
    Ga.pattes(sq, m, phase, pas, BETA, LEVE, L1, L2, TABLE, incl=0.35)
    return sq


def modele(lots, M, r, torse=False):
    c = lots("corps")
    # caisse octogonale : côtés chanfreinés
    prof = [(-0.3, 0.86), (-0.2, 1.12), (-0.05, 1.28), (0.32, 1.28), (0.48, 1.12), (0.54, 0.86), (0.56, 0.0)]
    c.put(M["plomb"], G.tour(prof, 8, "z", a0=A8, a1=A8 + G.TAU, cap0=True))
    c.put(M["chevron"], F.bague((0.0, 0.0, 0.0), 1.24, 1.32, 0.12, "z", 8, 0.015, a0=A8, a1=A8 + G.TAU))
    c.put(M["plomb2"], F.bague((0.0, 0.0, 0.5), 0.72, 1.14, 0.05, "z", 8, 0.012, a0=A8, a1=A8 + G.TAU))
    apo = 1.28 * math.cos(A8)
    # par pan : plaque rivetée, hublot sur 1 pan sur 2, ou trappe
    for k in range(8):
        am = math.radians(45.0 * k)
        n = (math.cos(am), math.sin(am), 0.0)
        p = (apo * n[0], apo * n[1], 0.17)
        c.put(M["plomb2"], F.sur_face(F.plaque([(-0.36, -0.1), (0.36, -0.1), (0.36, 0.1), (-0.36, 0.1)], 0.018), p, n))
        c.put(M["riv"], G.rivets_le_long([(G.add(p, (-n[1] * dt, n[0] * dt, dz)), n) for dt in (-0.32, 0.32) for dz in (-0.07, 0.07)], 0.018, 0.012))
        if k % 2 == 0:
            q = G.add(p, G.mul(n, 0.02))
            c.put(M["acier"], F.pose(F.bague((0.0, 0.0, 0.0), 0.055, 0.09, 0.03, "x", 12, 0.008), q, n))
            c.put(M["hublot"], F.pose(F.disque((0.006, 0.0, 0.0), 0.06, 0.012, "x", 12), q, n))
        else:
            for dt in (-0.18, 0.0, 0.18):
                c.put(M["noir"], F.sur_face(F.plaque([(-0.05, -0.05), (0.05, -0.05), (0.05, 0.05), (-0.05, 0.05)], 0.008), G.add(p, (-n[1] * dt, n[0] * dt, 0.0)), n))
    # dessus : jupe et embase du mortier
    c.put(M["jaune"], F.bague((0.0, 0.0, 0.56), 0.7, 0.8, 0.03, "z", 8, 0.008, a0=A8, a1=A8 + G.TAU))
    c.put(M["plomb"], G.tour([(0.54, 0.78), (0.62, 0.74), (0.72, 0.62)], 16, "z"))
    # le mortier : hyperboloïde de béton incliné de 6°, gueule d'uranium, cerclages. Il tient dans sa jupe.
    base = (0.0, 0.0, 0.62)
    d = G.norm((0.1, 0.0, 1.0))
    h = 1.72
    pr = [(0.0, 0.72), (0.3, 0.6), (0.65, 0.5), (0.98, 0.46), (1.3, 0.5), (1.6, 0.6), (h, 0.66)]
    c.put(M["beton"], F.incline(G.tour(pr, 28, "z"), base, d))
    c.put(M["beton"], F.incline(G.tour([(h, 0.66), (h + 0.03, 0.62), (h - 0.3, 0.46), (h - 0.6, 0.38)], 28, "z"), base, d))
    c.put(M["uranium"], F.incline(F.disque((0.0, 0.0, h - 0.56), 0.26, 0.02, "z", 16), base, d))
    c.put(M["noir"], F.incline(F.disque((0.0, 0.0, h - 0.6), 0.44, 0.02, "z", 24), base, d))
    for k in range(7):      # barres de combustible : la lueur passe entre elles
        a = G.TAU * k / 7
        c.put(M["acier"], F.incline(F.disque((0.2 * math.cos(a), 0.2 * math.sin(a), h - 0.42), 0.055, 0.3, "z", 8), base, d))
        c.put(M["hublot"], F.incline(F.disque((0.2 * math.cos(a), 0.2 * math.sin(a), h - 0.26), 0.038, 0.012, "z", 8), base, d))
    c.put(M["noir"], F.incline(F.bague((0.0, 0.0, h - 0.34), 0.34, 0.42, 0.28, "z", 24), base, d))
    for z_, rr_ in ((0.12, 0.665), (0.7, 0.495), (1.25, 0.505), (1.66, 0.655)):
        c.put(M["acier"] if z_ != 0.7 else M["peint"], F.incline(F.bague((0.0, 0.0, z_), rr_ - 0.03, rr_ + 0.03, 0.05, "z", 28, 0.01), base, d))
    # coulures de béton : bandes verticales (taches) et trèfle jaune sur le fût
    for k in range(5):
        a = 0.5 + k * 1.25
        z_ = 0.85 + 0.1 * (k % 2)
        rr_ = 0.47
        p = F.incline(([(rr_ * math.cos(a), rr_ * math.sin(a), z_)], [], [(0.0, 0.0)]), base, d)[0][0]
        c.put(M["noir"], G.oriente(G.boite((0.0, 0.0, 0.0), (0.03, 0.3, 0.003)), p, (math.cos(a), math.sin(a), 0.0)))
    tp = (0.5, 0.05, 0.6 + 0.62)
    n_t = (0.87, 0.1, 0.0)
    c.put(M["jaune"], F.sur_face(F.disque((0.0, 0.0, 0.006), 0.18, 0.012, "z", 16), tp, n_t))
    for k in range(3):
        a = G.TAU * k / 3 + math.pi / 2.0
        pts = [(0.0, 0.0), (0.16 * math.cos(a - 0.5), 0.16 * math.sin(a - 0.5)), (0.16 * math.cos(a + 0.5), 0.16 * math.sin(a + 0.5))]
        c.put(M["noir"], F.sur_face(F.plaque(pts, 0.016), tp, n_t))
    # conduits annelés, de la caisse à la jupe du mortier, et tours de balise
    for k in range(4):
        a = G.TAU * k / 4 + 0.7
        ca, sa = math.cos(a), math.sin(a)
        ct = [(1.0 * ca, 1.0 * sa, 0.55), (0.92 * ca, 0.92 * sa, 0.84), (0.62 * ca, 0.62 * sa, 0.98), (0.56 * ca, 0.56 * sa, 0.92)]
        pts = G.catmull(ct, 5)
        c.put(M["acier"], G.tube(pts, 0.05, 8, rfun=lambda s_, i: 0.042 + 0.012 * (i % 2)))
        c.put(M["plomb2"], F.bague((1.0 * ca, 1.0 * sa, 0.56), 0.04, 0.09, 0.05, "z", 10, 0.01))
    for x, y in ((0.74, 0.72), (-0.74, -0.72)):
        c.put(M["plomb2"], F.disque((x, y, 0.7), 0.04, 0.3, "z", 8))
        c.put(M["balise"], G.sphere((x, y, 0.88), 0.05, 8, 4))
    # dessous
    c.put(M["noir"], G.boite((0.0, 0.0, -0.32), (1.6, 1.1, 0.06)))
    # pattes : vérins courts
    for nom, _h, _p, _d, _po in TABLE:
        cu = lots("cuisse_" + nom)
        cu.put(M["plomb"], F.poutre([(-0.12, 0.2, 0.26), (0.05, 0.22, 0.28), (L1 - 0.05, 0.13, 0.14), (L1 + 0.05, 0.14, 0.15)], 0.3))
        cu.put(M["plomb2"], F.disque((0.0, 0.0, 0.0), 0.14, 0.24, "y", 10))
        cu.put(M["jaune"], F.bague((L1 * 0.5, 0.0, 0.0), 0.06, 0.12, 0.05, "x", 8, 0.008))
        ti = lots("tibia_" + nom)
        ti.put(M["plomb2"], F.disque((0.0, 0.0, 0.0), 0.1, 0.17, "y", 10))
        ti.put(M["plomb"], F.disque((0.25, 0.0, 0.0), 0.085, 0.5, "x", 10))
        ti.put(M["acier"], F.disque((L2 - 0.15, 0.0, 0.0), 0.05, 0.42, "x", 10))
        ti.put(M["peint"], F.bague((0.5, 0.0, 0.0), 0.05, 0.095, 0.04, "x", 10, 0.008))
        pi = lots("pied_" + nom)
        pi.put(M["plomb"], G.tour([(0.0, 0.2), (0.025, 0.22), (0.07, 0.18), (0.12, 0.08)], 8, "z", a0=A8, a1=A8 + G.TAU, cap1=True))
        pi.put(M["chevron"], F.bague((0.0, 0.0, 0.055), 0.12, 0.2, 0.012, "z", 8, 0.003, a0=A8, a1=A8 + G.TAU))
