"""TRUELLE (robot 7, âge 10 Haute technologie, ingénieur, classe M). Idée : un topographe : dôme lisse gris clair sur 4 pieds télescopiques, un radôme sur le dos, 2 antennes fouet, une petite parabole,
un bandeau de voyants bleus à la ceinture ; à l'avant, un long bras articulé qui finit par une lame-truelle et une buse de soudure, replié comme une patte de mante. Bible : carénage #A8ADB3, noir mat #222428, voyants #3AA8FF, luminance 82."""
import math

import formes as F
import gamme as Ga
import geo as G
import marionette as Mr

CAP = math.radians(-150.0)
Z0 = 1.45
PAS, BETA, LEVE = 1.1, 0.6, 0.18
L1, L2 = 0.72, 0.86
HX, HY, HZ = 0.46, 0.46, -0.2
TABLE = tuple((n, h, (h[0] * 1.5, h[1] * 1.5), d, (h[0], h[1], 0.5)) for n, h, d in
              (("ag", (HX, HY, HZ), 0.0), ("ad", (HX, -HY, HZ), 0.5), ("rg", (-HX, HY, HZ), 0.5), ("rd", (-HX, -HY, HZ), 0.0)))


def matieres(S):
    import mat as MT
    Ga.patine(ta=0.08, ra=0.18, ec=0.14, nu_k=1.2, ec_col=(0.04, 0.04, 0.045))
    cr = (0.03, 0.03, 0.032)
    sf = F.surf
    M = {}
    M["care"] = sf("rb10_care", (0.42, 0.44, 0.47), rough=0.28, met=0.15, tole=(0.9, 0.42), joint=0.55, joint_l=0.006, var=0.04, coulures=0.28, rouille=(0.14, 0.13, 0.12), usure=0.3, nu=(0.7, 0.72, 0.76), crasse=0.7, crasse_col=cr, relief=0.5, graine=1001)
    M["care2"] = sf("rb10_care2", (0.56, 0.58, 0.6), rough=0.26, met=0.1, coulures=0.2, rouille=(0.16, 0.15, 0.14), usure=0.3, nu=(0.78, 0.8, 0.82), crasse=0.65, crasse_col=cr, graine=1002)
    M["noir"] = sf("rb10_noir", (0.018, 0.019, 0.022), rough=0.5, met=0.25, usure=0.35, nu=(0.24, 0.25, 0.27), crasse=0.5, crasse_col=(0.003, 0.003, 0.003), graine=1003)
    M["acier"] = sf("rb10_acier", (0.36, 0.38, 0.41), rough=0.25, met=0.7, usure=0.35, nu=(0.78, 0.8, 0.82), crasse=0.5, crasse_col=cr, graine=1004)
    M["peint"] = sf("rb10_peint", (0.6, 0.6, 0.58), rough=0.32, met=0.2, usure=0.4, nu=(0.8, 0.8, 0.78), crasse=0.45, crasse_col=cr, graine=1005)
    M["peint"]["fo_teinte"] = 1
    M["verre"] = MT.verre("rb10_verre", col=(0.01, 0.02, 0.04), reflet=(0.25, 0.36, 0.52))
    M["voyant"] = MT.lumiere(S, "rb10_voyant", (0.04, 0.39, 1.0), 1.5, main=0.5)
    M["rouge"] = MT.lumiere(S, "rb10_rouge", (1.0, 0.08, 0.03), 1.4, main=0.5)
    M["buse"] = MT.lumiere(S, "rb10_buse", (1.0, 0.55, 0.12), 1.6, main=0.5)
    return M


def squelette(phase, cap=CAP, pas=PAS):
    sq = Mr.Squelette()
    sq.os("racine", None, Mr.rz(cap))
    a, m = Ga.corps_marche(phase, Z0, bob=0.03, tangage=0.02, roulis=0.03)
    sq.os("corps", "racine", m)
    sq.os("bras", "corps", Mr.autour((0.62, -0.1, -0.1), Mr.ry(0.05 * math.sin(a) if phase is not None else 0.0)))
    sq.os("radar", "corps", Mr.autour((-0.34, 0.0, 0.0), Mr.rz(a)))
    Ga.pattes(sq, m, phase, pas, BETA, LEVE, L1, L2, TABLE, incl=0.45)
    return sq


def modele(lots, M, r, torse=False):
    c = lots("corps")
    # dôme lisse, ceinture noire à voyants, jupe
    c.put(M["care"], G.tour([(0.08, 0.84), (0.22, 0.84), (0.44, 0.76), (0.66, 0.56), (0.8, 0.32), (0.86, 0.0)], 32, "z"))
    c.put(M["noir"], G.tour([(-0.04, 0.86), (0.08, 0.86)], 32, "z"))
    c.put(M["care"], G.tour([(-0.3, 0.38), (-0.2, 0.68), (-0.1, 0.84), (-0.04, 0.86)], 32, "z", cap0=True))
    c.put(M["peint"], F.bague((0.0, 0.0, 0.14), 0.83, 0.865, 0.08, "z", 32, 0.008))
    for k in range(20):
        a = G.TAU * k / 20
        col = M["rouge"] if k % 10 == 3 else M["voyant"]
        c.put(col, G.boite((0.865 * math.cos(a), 0.865 * math.sin(a), 0.02), (0.012, 0.09, 0.04), a))
    # verrière de l'avant : visière courbe
    c.put(M["verre"], G.tour([(0.3, 0.8), (0.42, 0.775), (0.56, 0.67), (0.66, 0.565)], 18, "z", a0=-0.62, a1=0.62))
    c.put(M["noir"], G.tour([(0.27, 0.81), (0.3, 0.805)], 18, "z", a0=-0.66, a1=0.66))
    # plaques de carénage et trappes, à peine en relief
    for k in range(6):
        a = 1.3 + k * 0.72
        n = (math.cos(a) * 0.87, math.sin(a) * 0.87, 0.5)
        p = (0.68 * math.cos(a), 0.68 * math.sin(a), 0.5)
        c.put(M["care2"], F.sur_face(F.plaque([(-0.13, -0.09), (0.13, -0.09), (0.1, 0.09), (-0.1, 0.09)], 0.012), p, n))
    # le chargé : regards, boîtiers, conduits et un paquetage dans le dos (le DC préfère le chargé au propre)
    def dome(rr):
        a, p_ = rr.f(0.0, G.TAU), rr.f(0.15, 1.0)
        n = (math.cos(p_) * math.cos(a), math.cos(p_) * math.sin(a), math.sin(p_))
        return (0.83 * n[0], 0.83 * n[1], 0.1 + 0.76 * n[2]), n
    Ga.plaques(c, [M["care2"], M["noir"], M["acier"], M["care"]], r, 70, dome, (0.04, 0.14), 0.012)
    for x, y, z in ((-0.72, 0.2, 0.4), (-0.72, -0.2, 0.4), (-0.62, 0.0, 0.62)):
        c.put(M["noir"], G.boite((x, y, z), (0.24, 0.18, 0.2)))
        c.put(M["care2"], G.boite((x - 0.13, y, z), (0.03, 0.14, 0.16)))
        c.put(M["voyant"], G.boite((x - 0.15, y, z + 0.05), (0.008, 0.08, 0.016)))
    for s in (1.0, -1.0):
        c.put(M["noir"], G.tube(G.catmull([(-0.6, s * 0.3, 0.42), (-0.2, s * 0.8, 0.28), (0.3, s * 0.82, 0.2), (0.55, s * 0.6, 0.0)], 5), 0.02, 6))
        c.put(M["acier"], F.pose(F.disque((0.0, 0.0, 0.0), 0.05, 0.1, "x", 10), (0.62, s * 0.34, 0.24), (1.0, s * 0.3, 0.06)))
        c.put(M["voyant"], F.pose(F.disque((0.05, 0.0, 0.0), 0.036, 0.01, "x", 10), (0.62, s * 0.34, 0.24), (1.0, s * 0.3, 0.06)))
    # sommet : radôme qui tourne (dans le dos)
    b = lots("radar")
    x0 = -0.34
    c.put(M["noir"], F.disque((x0, 0.0, 0.78), 0.13, 0.08, "z", 14))
    b.put(M["care2"], G.tour([(0.84, 0.0), (0.84, 0.2), (0.9, 0.24), (0.98, 0.2), (1.04, 0.0)], 18, "z", (x0, 0.0, 0.0)))
    b.put(M["voyant"], F.bague((x0, 0.0, 0.905), 0.235, 0.245, 0.02, "z", 18))
    # parabole sur un mât, sur le flanc
    pm = (0.05, 0.56, 0.5)
    d_p = G.norm((0.5, 0.45, 0.75))
    c.put(M["acier"], F.disque((pm[0], pm[1], pm[2] + 0.1), 0.022, 0.3, "z", 8))
    pd = (pm[0], pm[1], pm[2] + 0.26)
    c.put(M["care2"], F.incline(G.tour([(0.0, 0.0), (0.05, 0.14), (0.1, 0.22), (0.11, 0.24)], 18, "z"), pd, d_p))
    c.put(M["noir"], F.incline(F.disque((0.0, 0.0, 0.02), 0.09, 0.015, "z", 12), pd, d_p))
    c.put(M["acier"], F.incline(F.disque((0.0, 0.0, 0.14), 0.01, 0.26, "z", 6), pd, d_p))
    c.put(M["voyant"], F.incline(G.sphere((0.0, 0.0, 0.27), 0.022, 8, 4), pd, d_p))
    # antennes fouet, inégales, tendues et courbes
    for y, h, dx in ((-0.3, 1.5, -0.2), (-0.46, 1.0, -0.12)):
        base = (-0.18, y, 0.62)
        ct = [base, (base[0] + dx * 0.25, y - 0.02, base[2] + h * 0.45), (base[0] + dx, y - 0.05, base[2] + h)]
        c.put(M["noir"], G.tube(G.catmull(ct, 5), 0.012, 5, rfun=lambda s_, i: 0.014 - 0.0009 * i))
        c.put(M["noir"], F.disque((base[0], y, base[2] + 0.02), 0.04, 0.05, "z", 8))
        c.put(M["rouge"], G.sphere(ct[-1], 0.018, 6, 3))
    # épaule du bras, sous la visière
    ep = (0.64, -0.1, -0.1)
    c.put(M["noir"], F.disque((ep[0], ep[1], ep[2]), 0.13, 0.22, "y", 12))
    # bras : mante, repliée
    a_ = lots("bras")
    b0 = ep
    b1 = (1.12, -0.1, 0.4)
    b2 = (1.5, -0.1, -0.32)
    a_.put(M["care"], F.bielle(b0, b1, 0.14, 0.17))
    a_.put(M["noir"], F.pose(F.disque((0.5, 0.0, 0.0), 0.03, 0.5, "x", 8), G.add(b0, (0.0, 0.1, 0.0)), G.sub(b1, b0)))
    a_.put(M["acier"], F.disque(b1, 0.1, 0.18, "y", 12))
    a_.put(M["care2"], F.bielle(b1, b2, 0.09, 0.11))
    a_.put(M["peint"], F.pose(F.bague((0.0, 0.0, 0.0), 0.05, 0.08, 0.05, "x", 8, 0.01), G.lerp(b1, b2, 0.32), G.sub(b2, b1)))
    a_.put(M["voyant"], F.pose(G.boite((0.5, 0.0, 0.0), (0.2, 0.02, 0.116)), b1, G.sub(b2, b1)))
    # lame-truelle : losange plat, poignée
    a_.put(M["noir"], F.disque(b2, 0.06, 0.13, "y", 10))
    d_l = G.norm((0.72, 0.0, -0.7))
    lame = F.plaque([(0.0, -0.16), (0.36, -0.13), (0.62, 0.0), (0.36, 0.13), (0.0, 0.16)], 0.018)
    v, f_, u = lame
    v = [(q[0], q[1], q[2] - 0.009) for q in v]
    a_.put(M["acier"], F.pose((v, f_, u), b2, d_l, (d_l[2], 0.0, -d_l[0])))
    # buse de soudure, à côté de la lame
    a_.put(M["noir"], F.pose(F.disque((0.09, 0.0, 0.0), 0.022, 0.18, "x", 8), G.add(b2, (0.0, 0.12, 0.0)), (0.5, 0.0, -0.86)))
    a_.put(M["buse"], F.pose(F.cristal((0.2, 0.0, 0.0), 0.022, 0.05), G.add(b2, (0.0, 0.12, 0.0)), (0.5, 0.0, -0.86)))
    # pieds télescopiques
    for nom, _h, _p, _d, _po in TABLE:
        cu = lots("cuisse_" + nom)
        cu.put(M["noir"], F.disque((0.0, 0.0, 0.0), 0.1, 0.16, "y", 10))
        cu.put(M["care"], F.poutre([(0.0, 0.14, 0.15), (L1 - 0.1, 0.1, 0.1), (L1 + 0.04, 0.1, 0.1)], 0.42))
        ti = lots("tibia_" + nom)
        ti.put(M["noir"], F.disque((0.0, 0.0, 0.0), 0.075, 0.13, "y", 10))
        ti.put(M["care2"], F.disque((0.25, 0.0, 0.0), 0.058, 0.5, "x", 12))
        ti.put(M["acier"], F.disque((0.55, 0.0, 0.0), 0.04, 0.3, "x", 12))
        ti.put(M["noir"], F.disque((L2 - 0.1, 0.0, 0.0), 0.028, 0.2, "x", 10))
        ti.put(M["voyant"], F.bague((0.42, 0.0, 0.0), 0.058, 0.062, 0.02, "x", 12))
        pi = lots("pied_" + nom)
        pi.put(M["care"], G.tour([(0.0, 0.15), (0.015, 0.17), (0.05, 0.14), (0.09, 0.05)], 16, "z", cap1=True))
        pi.put(M["noir"], F.bague((0.0, 0.0, 0.012), 0.14, 0.175, 0.024, "z", 16, 0.003))
