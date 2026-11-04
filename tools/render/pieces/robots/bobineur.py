"""BOBINEUR (robot 3, âge 6 Électricité, anti-essaim en zone, classe P). Idée : un échassier électrique : une grosse bobine de cuivre couchée comme un corps d'oiseau, 2 longues pattes à
genou inversé, un mât d'isolateurs de céramique crantés dressé sur le dos, un tore de Tesla au sommet et un arc cyan entre 2 cornes d'éclateur devant. Bible : céramique #D8D4C8 patinée,
cuivre de bobine #B0703A, acier #5C6168, arcs cyan #60D0FF, luminance 64."""
import math

import formes as F
import gamme as Ga
import geo as G
import marionette as Mr

CAP = math.radians(-150.0)
ECH = 1.15
Z0 = 1.15
PAS, BETA, LEVE = 0.86, 0.56, 0.2
L1, L2 = 0.56, 0.72
TABLE = (("g", (-0.04, 0.26, -0.14), (0.0, 0.3), 0.0, (-1.0, 0.0, 0.05)), ("d", (-0.04, -0.26, -0.14), (0.0, -0.3), 0.5, (-1.0, 0.0, 0.05)))


def matieres(S):
    import mat as MT
    Ga.patine(ta=0.12, ra=0.22, ec=0.3, nu_k=1.3, ec_col=(0.05, 0.03, 0.02), sans=("cerami",))
    cr = (0.012, 0.01, 0.008)
    sf = F.surf
    M = {}
    M["cerami"] = sf("rb6_cerami", (0.68, 0.64, 0.54), rough=0.26, met=0.0, usure=0.4, nu=(0.85, 0.82, 0.74), crasse=0.8, crasse_col=(0.1, 0.07, 0.05), coulures=0.5, rouille=(0.22, 0.16, 0.1), graine=601)
    M["cuivre"] = sf("rb6_cuivre", (0.56, 0.24, 0.08), rough=0.33, met=0.5, tole=(3.0, 0.042), joint=0.25, joint_l=0.1, var=0.08, usure=0.5, nu=(0.85, 0.55, 0.3), crasse=0.7, crasse_col=cr, relief=0.8, graine=602)
    M["cuivre2"] = sf("rb6_cuivre2", (0.5, 0.21, 0.07), rough=0.35, met=0.55, coulures=0.4, rouille=(0.05, 0.17, 0.11), usure=0.5, nu=(0.8, 0.52, 0.3), crasse=0.7, crasse_col=cr, graine=603)
    M["acier"] = sf("rb6_acier", (0.13, 0.14, 0.155), rough=0.42, met=0.65, usure=0.75, nu=(0.5, 0.52, 0.56), crasse=0.75, crasse_col=cr, coulures=0.3, graine=604)
    M["acier2"] = sf("rb6_acier2", (0.26, 0.275, 0.3), rough=0.35, met=0.6, usure=0.6, nu=(0.62, 0.64, 0.68), crasse=0.65, crasse_col=cr, graine=605)
    M["peint"] = sf("rb6_peint", (0.55, 0.52, 0.46), rough=0.42, met=0.25, usure=0.5, nu=(0.72, 0.7, 0.64), crasse=0.5, crasse_col=cr, graine=606)
    M["peint"]["fo_teinte"] = 1
    M["riv"] = sf("rb6_riv", (0.3, 0.3, 0.3), rough=0.4, met=0.7, usure=0.3, crasse=0.4, graine=607)
    M["arc"] = MT.lumiere(S, "rb6_arc", (0.14, 0.62, 1.0), 2.0, main=0.55)
    M["voyant"] = MT.lumiere(S, "rb6_voyant", (0.14, 0.62, 1.0), 1.3, main=0.5)
    return M


def squelette(phase, cap=CAP, pas=PAS):
    sq = Mr.Squelette()
    sq.os("racine", None, Mr.chaine(Mr.rz(cap), Mr.ech(ECH)))
    a, m = Ga.corps_marche(phase, Z0, bob=0.045, tangage=0.05, roulis=0.05, lacet=0.06)
    sq.os("corps", "racine", m)
    sq.os("mat", "corps", Mr.autour((-0.08, 0.0, 0.3), Mr.chaine(Mr.ry(0.05 * math.sin(2.0 * a) if phase is not None else 0.0))))
    sq.os("tore", "mat", Mr.autour((-0.08, 0.0, 1.0), Mr.rz(a)))
    Ga.pattes(sq, m, phase, pas, BETA, LEVE, L1, L2, TABLE, incl=0.8)
    return sq


def _pile(lot, M, base, d, n, r0=0.09, pas_=0.05):
    """Pile d'isolateurs : disques crantés de céramique autour d'un axe d."""
    d = G.norm(d)
    for i in range(n):
        p = G.add(base, G.mul(d, pas_ * i))
        rr = r0 if i % 2 == 0 else r0 * 0.68
        lot.put(M["cerami"], F.incline(G.tour([(0.0, rr * 0.6), (pas_ * 0.3, rr), (pas_ * 0.7, rr), (pas_, rr * 0.6)], 10, "z"), p, d))


def modele(lots, M, r, torse=False):
    c = lots("corps")
    # corps : bobine couchée, spires visibles, joues d'acier, joues de céramique
    c.put(M["cuivre"], G.tour([(-0.42, 0.0), (-0.42, 0.26), (-0.4, 0.29), (0.32, 0.29), (0.34, 0.26), (0.34, 0.0)], 28, "x"))
    for x, re_ in ((-0.44, 0.32), (0.36, 0.3)):
        c.put(M["acier"], F.disque((x, 0.0, 0.0), re_, 0.05, "x", 14))
        c.put(M["acier2"], F.bague((x, 0.0, 0.0), re_ - 0.04, re_ + 0.01, 0.065, "x", 14, 0.008))
        c.put(M["riv"], F.rivets_anneau(x + (0.03 if x > 0 else -0.03), re_ - 0.02, 7, 0.0, 0.018))
    for x in (-0.26, -0.08, 0.1, 0.24):
        c.put(M["peint"] if x in (-0.08, 0.1) else M["acier"], F.bague((x, 0.0, 0.0), 0.27, 0.305, 0.03, "x", 28, 0.005))
    # bec : éclateur à 2 cornes, l'arc entre elles
    x0 = 0.42
    c.put(M["acier"], F.pose(F.poutre([(0.0, 0.26, 0.2), (0.3, 0.14, 0.1)], 0.3), (x0 - 0.04, 0.0, 0.0), (1.0, 0.0, -0.05)))
    tip = {}
    for s in (1.0, -1.0):
        b = (x0 + 0.2, s * 0.08, 0.02)
        ct = [b, (x0 + 0.38, s * 0.13, 0.1), (x0 + 0.52, s * 0.15, 0.2), (x0 + 0.6, s * 0.11, 0.28)]
        pts = G.catmull(ct, 3)
        c.put(M["cuivre2"], G.tube(pts, 0.018, 6, rfun=lambda s_, i: 0.022 - 0.0012 * i))
        c.put(M["acier2"], G.sphere(ct[-1], 0.028, 8, 4))
        tip[s] = ct[-1]
        _pile(c, M, (x0 + 0.08, s * 0.1, -0.12), (0.5, s * 0.05, -0.75), 4, 0.05, 0.035)
    a, b_ = tip[1.0], tip[-1.0]
    zig = [G.add(G.lerp(a, b_, i / 6.0), (0.012 * ((-1) ** i), 0.0, 0.02 * ((-1) ** i) + 0.016 * math.sin(i * 2.1))) for i in range(7)]
    c.put(M["arc"], G.tube(zig, 0.01, 5))
    # flancs : condensateurs et isolateurs tournés vers l'extérieur
    for s in (1.0, -1.0):
        _pile(c, M, (-0.2, s * 0.3, 0.05), (0.0, s, 0.5), 4, 0.06, 0.038)
        c.put(M["acier2"], F.disque((-0.2, s * 0.38, 0.17), 0.012, 0.06, "z", 6))
        c.put(M["cuivre2"], G.tube(G.coudee([(-0.2, s * 0.29, -0.05), (-0.3, s * 0.33, -0.14), (-0.42, s * 0.2, -0.28)], 0.04, 3), 0.014, 6))
        c.put(M["voyant"], F.pose(F.disque((0.0, 0.0, 0.0), 0.022, 0.01, "x", 8), (0.15, s * 0.31, 0.04), (0.0, s, 0.1)))
    # queue : batterie plate, longue
    c.put(M["acier"], F.pose(F.poutre([(0.0, 0.28, 0.2), (0.34, 0.22, 0.12), (0.5, 0.1, 0.05)], 0.3), (-0.45, 0.0, 0.0), (-1.0, 0.0, -0.22)))
    for k in range(3):
        c.put(M["peint" if k == 1 else "cerami"], F.pose(G.boite((0.1 + 0.11 * k, 0.0, 0.0), (0.05, 0.3 - 0.03 * k, 0.21 - 0.03 * k)), (-0.45, 0.0, 0.0), (-1.0, 0.0, -0.22)))
    # mât d'isolateurs : se balance, porte le tore
    m = lots("mat")
    x_m = -0.08
    m.put(M["acier"], F.disque((x_m, 0.0, 0.31), 0.16, 0.05, "z", 12))
    _pile(m, M, (x_m, 0.0, 0.33), (0.0, 0.0, 1.0), 12, 0.11, 0.055)
    m.put(M["acier2"], F.disque((x_m, 0.0, 0.99), 0.05, 0.07, "z", 10))
    t = lots("tore")
    t.put(M["acier2"], F.tore((x_m, 0.0, 1.05), 0.2, 0.062, "z", 24, 8))
    t.put(M["cuivre2"], F.tore((x_m, 0.0, 1.05), 0.2, 0.066, "z", 24, 4, 0.0, 0.35))
    for i in range(4):
        an = G.TAU * i / 4 + 0.4
        q0 = (x_m + 0.2 * math.cos(an), 0.2 * math.sin(an), 1.06)
        pts = [G.add(q0, (0.022 * i_ * math.cos(an) + 0.008 * ((-1) ** i_), 0.022 * i_ * math.sin(an), 0.012 * ((-1) ** i_))) for i_ in range(5)]
        t.put(M["arc"], G.tube(pts, 0.006, 4))
    t.put(M["voyant"], F.disque((x_m, 0.0, 1.05), 0.06, 0.02, "z", 10))
    # pattes : cuisse d'acier, tibia à ressort, griffes
    for nom, _h, _p, _d, _po in TABLE:
        cu = lots("cuisse_" + nom)
        cu.put(M["acier"], F.poutre([(-0.06, 0.09, 0.14), (0.05, 0.1, 0.16), (L1 - 0.04, 0.06, 0.07), (L1 + 0.04, 0.06, 0.08)], 0.3))
        cu.put(M["acier2"], F.disque((0.0, 0.0, 0.0), 0.08, 0.13, "y", 10))
        cu.put(M["cuivre2"], F.bague((L1 * 0.45, 0.0, 0.0), 0.05, 0.08, 0.05, "x", 8, 0.008))
        ti = lots("tibia_" + nom)
        ti.put(M["acier2"], F.disque((0.0, 0.0, 0.0), 0.05, 0.1, "y", 10))
        ti.put(M["acier"], F.disque((L2 / 2.0, 0.0, 0.0), 0.022, L2, "x", 8))
        for i in range(5):
            ti.put(M["cuivre2"], F.tore((0.16 + 0.05 * i, 0.0, 0.0), 0.034, 0.009, "x", 10, 4))
        ti.put(M["peint"], F.bague((L2 - 0.08, 0.0, 0.0), 0.022, 0.04, 0.04, "x", 8, 0.006))
        pi = lots("pied_" + nom)
        pi.put(M["acier"], F.disque((0.0, 0.0, 0.03), 0.05, 0.06, "z", 8))
        for ang, lg in ((0.0, 0.2), (0.75, 0.14), (-0.75, 0.14), (math.pi, 0.11)):
            d = (math.cos(ang), math.sin(ang), -0.08)
            pi.put(M["acier2"], F.pose(F.poutre([(0.0, 0.04, 0.03), (lg, 0.012, 0.012, -0.012)], 0.3), (0.0, 0.0, 0.025), d))
