"""AIGUILLE (robot 4, âge 7 Cristal, tireur à longue portée, classe M). Idée : un compas de géomètre : trépied de 3 longues jambes de bronze, nacelle de pierre sertie, et de son épaule une
grande aiguille de cristal violet dressée de biais comme une lance au repos (jamais un canon central : elle part de l'épaule, vers le haut) ; grappes de cristaux irrégulières sur la nacelle.
Bible : bronze #6A5236, pierre #4A4038, cristal #9A5CFF opaque, luisant #B070FF."""
import math

import formes as F
import gamme as Ga
import geo as G
import marionette as Mr

CAP = math.radians(-150.0)
Z0 = 2.1
PAS, BETA, LEVE = 1.3, 0.72, 0.24
L1, L2 = 1.05, 1.5
TABLE = (("av", (0.34, 0.0, -0.12), (0.72, 0.0), 0.0, (1.0, 0.0, 0.8)),
         ("rg", (-0.2, 0.3, -0.12), (-0.42, 0.72), 1.0 / 3.0, (-0.5, 0.85, 0.8)),
         ("rd", (-0.2, -0.3, -0.12), (-0.42, -0.72), 2.0 / 3.0, (-0.5, -0.85, 0.8)))


def matieres(S):
    import mat as MT
    Ga.patine(ta=0.14, ra=0.22, ec=0.35, nu_k=1.4, ec_col=(0.03, 0.02, 0.012), sans=("cristal",))
    cr = (0.01, 0.008, 0.006)
    sf = F.surf
    M = {}
    M["bronze"] = sf("rb7_bronze", (0.26, 0.16, 0.07), rough=0.38, met=0.6, coulures=0.5, rouille=(0.06, 0.13, 0.09), usure=0.6, nu=(0.62, 0.45, 0.22), crasse=0.8, crasse_col=cr, graine=701)
    M["bronze2"] = sf("rb7_bronze2", (0.38, 0.24, 0.1), rough=0.32, met=0.65, usure=0.55, nu=(0.75, 0.56, 0.3), crasse=0.7, crasse_col=cr, graine=702)
    M["pierre"] = sf("rb7_pierre", (0.11, 0.085, 0.065), rough=0.85, met=0.0, tole=(0.34, 0.2), joint=0.35, joint_l=0.012, var=0.2, coulures=0.4, usure=0.6, nu=(0.24, 0.2, 0.16), crasse=0.8, crasse_col=cr, relief=0.6, grain=0.15, graine=703)
    M["peint"] = sf("rb7_peint", (0.5, 0.45, 0.38), rough=0.42, met=0.25, usure=0.5, nu=(0.7, 0.65, 0.56), crasse=0.5, crasse_col=cr, graine=704)
    M["peint"]["fo_teinte"] = 1
    M["riv"] = sf("rb7_riv", (0.4, 0.28, 0.12), rough=0.4, met=0.7, usure=0.3, crasse=0.4, graine=705)
    M["cristal"] = sf("rb7_cristal", (0.2, 0.06, 0.62), rough=0.18, met=0.05, usure=0.25, nu=(0.62, 0.42, 1.0), crasse=0.55, crasse_col=(0.03, 0.01, 0.07), grain=0.12, graine=706)
    M["lueur"] = MT.lumiere(S, "rb7_lueur", (0.44, 0.16, 1.0), 1.6, main=0.55)
    return M


def squelette(phase, cap=CAP, pas=PAS):
    sq = Mr.Squelette()
    sq.os("racine", None, Mr.rz(cap))
    a, m = Ga.corps_marche(phase, Z0, bob=0.05, tangage=0.035, roulis=0.05, lacet=0.05)
    sq.os("corps", "racine", Mr.mm(m, Mr.ech(1.25)))     # nacelle et aiguille plus grandes ; les hanches restent calculées sur m
    Ga.pattes(sq, m, phase, pas, BETA, LEVE, L1, L2, TABLE, incl=0.5)
    return sq


def _grappe(lot, M, base, r, n, h0, h1, axe=(0.0, 0.0, 1.0), ec=0.5):
    """Grappe irrégulière : pointes à 5 pans, de tailles différentes, un cœur lumineux sur la plus grande."""
    for i in range(n):
        d = G.norm((axe[0] + r.f(-ec, ec), axe[1] + r.f(-ec, ec), axe[2] + r.f(-0.1, 0.2)))
        h = h1 if i == 0 else r.f(h0, h1 * 0.7)
        rr = h * r.f(0.13, 0.19)
        b = G.add(base, (r.f(-0.08, 0.08), r.f(-0.08, 0.08), 0.0))
        lot.put(M["cristal"], F.incline(G.tour([(0.0, rr * 0.7), (h * 0.14, rr), (h * 0.72, rr * 0.75), (h, 0.0)], 5, "z", cap0=True), b, d))
        if i < 2:
            lot.put(M["lueur"], F.incline(G.tour([(h * 0.1, rr * 1.01), (h * 0.5, rr * 0.86), (h * 0.5, rr * 0.3)], 5, "z", a0=0.0, a1=1.2), b, d))


def modele(lots, M, r, torse=False):
    c = lots("corps")
    # nacelle de pierre sertie de bronze, à 6 pans, ramassée
    c.put(M["pierre"], G.tour([(-0.34, 0.0), (-0.3, 0.3), (-0.12, 0.52), (0.14, 0.56), (0.32, 0.42), (0.42, 0.18), (0.44, 0.0)], 6, "z", a0=0.26, a1=0.26 + G.TAU))
    c.put(M["bronze2"], F.bague((0.0, 0.0, 0.02), 0.5, 0.6, 0.07, "z", 6, 0.012, a0=0.26, a1=0.26 + G.TAU))
    c.put(M["bronze"], F.bague((0.0, 0.0, -0.2), 0.36, 0.44, 0.05, "z", 6, 0.01, a0=0.26, a1=0.26 + G.TAU))
    c.put(M["peint"], F.bague((0.0, 0.0, 0.2), 0.36, 0.46, 0.05, "z", 6, 0.01, a0=0.26, a1=0.26 + G.TAU))
    for i in range(12):
        a = G.TAU * i / 12
        c.put(M["riv"], G.rivets_le_long([((0.6 * math.cos(a), 0.6 * math.sin(a), 0.02), (math.cos(a), math.sin(a), 0.0))], 0.02, 0.012))
    # hublot-viseur sur l'avant
    c.put(M["bronze2"], F.pose(F.bague((0.0, 0.0, 0.0), 0.08, 0.14, 0.08, "x", 10, 0.012), (0.5, 0.0, 0.12), (1.0, 0.0, 0.1)))
    c.put(M["lueur"], F.pose(F.disque((0.02, 0.0, 0.0), 0.08, 0.02, "x", 10), (0.5, 0.0, 0.12), (1.0, 0.0, 0.1)))
    # grappes irrégulières
    _grappe(c, M, (-0.1, -0.2, 0.32), r, 6, 0.2, 0.62, (-0.15, -0.3, 1.0))
    _grappe(c, M, (-0.32, 0.16, 0.22), r, 4, 0.14, 0.4, (-0.5, 0.3, 0.9))
    _grappe(c, M, (0.18, 0.28, 0.2), r, 3, 0.1, 0.26, (0.2, 0.4, 0.9))
    # l'aiguille : part de l'épaule gauche (+Y), de biais vers l'avant et le haut
    pe = (0.12, 0.46, 0.18)
    d = G.norm((0.55, 0.05, 0.84))
    c.put(M["bronze"], F.disque((pe[0], pe[1] - 0.02, pe[2] - 0.1), 0.16, 0.2, "y", 12))
    c.put(M["bronze2"], F.pose(F.poutre([(-0.1, 0.22, 0.2), (0.5, 0.16, 0.15)], 0.3), pe, d))
    c.put(M["cristal"], F.incline(G.tour([(0.0, 0.07), (0.25, 0.11), (1.6, 0.075), (2.5, 0.042), (2.95, 0.0)], 5, "z", cap0=True), G.add(pe, G.mul(d, 0.2)), d))
    # veine lumineuse le long de l'aiguille, et anneaux de sertissure qui rétrécissent
    for t_, rr in ((0.45, 0.145), (1.0, 0.13), (1.6, 0.112), (2.15, 0.09)):
        p = G.add(pe, G.mul(d, t_))
        c.put(M["bronze2"], F.incline(F.bague((0.0, 0.0, 0.0), rr * 0.6, rr, 0.05, "z", 8, 0.01), p, d))
    c.put(M["lueur"], F.incline(G.tour([(0.3, 0.117), (1.6, 0.078), (2.4, 0.046), (2.9, 0.006)], 5, "z", a0=1.0, a1=1.55), G.add(pe, G.mul(d, 0.2)), d))
    c.put(M["lueur"], F.incline(G.tour([(0.3, 0.117), (1.6, 0.078), (2.4, 0.046), (2.9, 0.006)], 5, "z", a0=3.5, a1=3.95), G.add(pe, G.mul(d, 0.2)), d))
    # jambes : compas de bronze, longues et fines, sabot pointu
    for nom, _h, _p, _d, _po in TABLE:
        cu = lots("cuisse_" + nom)
        cu.put(M["bronze"], F.poutre([(-0.1, 0.12, 0.18), (0.08, 0.13, 0.2), (L1 - 0.05, 0.08, 0.09), (L1 + 0.05, 0.08, 0.1)], 0.3))
        cu.put(M["bronze2"], F.disque((0.0, 0.0, 0.0), 0.11, 0.17, "y", 10))
        cu.put(M["riv"], F.rivets_ligne((0.15, 0.065, 0.0), (L1 - 0.1, 0.045, 0.0), 4, (0, 1, 0), 0.016))
        ti = lots("tibia_" + nom)
        ti.put(M["bronze2"], F.disque((0.0, 0.0, 0.0), 0.08, 0.14, "y", 10))
        ti.put(M["bronze"], F.poutre([(0.0, 0.1, 0.12), (0.4, 0.075, 0.09), (L2 - 0.25, 0.042, 0.05), (L2 - 0.05, 0.03, 0.035)], 0.3))
        for t_ in (0.42, 0.92):
            ti.put(M["peint" if t_ < 0.5 else "bronze2"], F.bague((t_, 0.0, 0.0), 0.03, 0.06 - 0.018 * t_, 0.05, "x", 8, 0.008))
        ti.put(M["cristal"], F.pose(G.tour([(0.0, 0.0), (0.05, 0.04), (0.18, 0.0)], 5, "x"), (0.55, 0.0, 0.08), (0.8, 0.0, 0.6)))
        pi = lots("pied_" + nom)
        pi.put(M["bronze2"], G.tour([(0.0, 0.0), (0.03, 0.05), (0.11, 0.075), (0.16, 0.04)], 6, "z", cap1=True))
        pi.put(M["bronze"], F.bague((0.0, 0.0, 0.09), 0.05, 0.095, 0.02, "z", 6, 0.005))
