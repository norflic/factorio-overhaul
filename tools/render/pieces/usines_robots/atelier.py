"""ATELIER D'AUTOMATES (fo-robot-workshop), âge 3 · Vapeur, emprise 3×3 (x ±1,5 ; y ±2,12). PLAN ROBOTS §5 bis.

Lecture : au fond, l'abside de brique et la chaudière rivetée couchée qui alimente tout, sa haute cheminée ronde à
collerette (signature de l'âge), son manomètre et son régulateur à boules. Au centre, sur un chariot et des rails, un
Trotte-Vapeur en cours de montage (chaudière ronde, 2 pattes posées sur 4), suspendu à une potence à contrepoids ; un bras à
vapeur le rive. Devant, les rails descendent une rampe sous un arceau de fer : la sortie, au sud. Forme originale.
Bible (époque 3) : cuivre #8A5A3A, laiton #9C7E45, fonte #3A3634, luminance 58, hublots et cadrans ambrés #FFC060.
"""
import math

import geo as G
import mat as MT
import outils as O

TAU = G.TAU
ROBOT = (0.25, -0.42, 1.14)      # centre de la chaudière du robot
RR = 0.47


def matieres(S):
    M = {}
    MT.PATINE.update(ta=0.17, ra=0.26, ec=0.65, nu_k=1.4, ec_col=(0.022, 0.014, 0.008))
    sf = MT.surface
    cr = (0.012, 0.009, 0.006)
    M["fonte"] = sf("a3_fonte", (0.115, 0.1, 0.09), rough=0.6, met=0.3, usure=0.85, nu=(0.5, 0.46, 0.41), crasse=0.8, crasse_col=cr,
                    coulures=0.5, rouille=(0.13, 0.055, 0.02), grain=0.12, graine=31)
    M["fonte2"] = sf("a3_fonte2", (0.07, 0.062, 0.056), rough=0.68, met=0.25, usure=0.7, nu=(0.38, 0.35, 0.31), crasse=0.7, crasse_col=cr, grain=0.12, graine=32)
    M["cuivre"] = sf("a3_cuivre", (0.56, 0.25, 0.1), rough=0.42, met=0.4, usure=0.55, nu=(0.85, 0.5, 0.28), crasse=0.8, crasse_col=cr,
                     coulures=0.55, rouille=(0.06, 0.17, 0.11), tole=(0.95, 0.24), joint=0.6, joint_l=0.01, var=0.09, grain=0.09, graine=33)
    M["cuivre_uni"] = sf("a3_cuivre_uni", (0.66, 0.32, 0.13), rough=0.38, met=0.45, usure=0.5, nu=(0.9, 0.55, 0.3), crasse=0.7, crasse_col=cr,
                         coulures=0.3, rouille=(0.06, 0.17, 0.11), graine=34)
    M["laiton"] = sf("a3_laiton", (0.68, 0.48, 0.17), rough=0.36, met=0.4, usure=0.45, nu=(0.85, 0.72, 0.42), crasse=0.7, crasse_col=cr, grain=0.08, graine=35)
    M["riv"] = sf("a3_riv", (0.24, 0.18, 0.12), rough=0.5, met=0.3, usure=0.5, nu=(0.55, 0.45, 0.33), crasse=0.3, graine=36)
    M["brique"] = sf("a3_brique", (0.36, 0.125, 0.065), rough=0.9, met=0.0, tole=(0.2, 0.09), joint=0.28, joint_l=0.012, var=0.26, coulures=0.5,
                     rouille=(0.025, 0.02, 0.018), usure=0.55, nu=(0.32, 0.18, 0.12), crasse=0.85, crasse_col=cr, pied=(0.1, 0.55, 0.6), relief=0.7, grain=0.16, graine=37)
    M["pierre"] = sf("a3_pierre", (0.27, 0.25, 0.21), rough=0.9, met=0.0, tole=(0.5, 0.3), joint=0.35, var=0.22, usure=0.6, nu=(0.3, 0.28, 0.25),
                     crasse=0.85, crasse_col=cr, relief=0.6, grain=0.15, graine=38)
    M["bois"] = sf("a3_bois", (0.36, 0.25, 0.145), rough=0.85, met=0.0, tole=(0.9, 0.13), joint=0.2, var=0.28, usure=0.5, nu=(0.28, 0.2, 0.12),
                   crasse=0.8, crasse_col=cr, relief=0.5, grain=0.15, graine=39)
    M["ond"] = sf("a3_ond", (0.48, 0.22, 0.095), rough=0.5, met=0.35, tole=(0.09, 3.0), joint=0.35, var=0.1, usure=0.5, nu=(0.7, 0.42, 0.25), crasse=0.8,
                  crasse_col=cr, coulures=0.8, rouille=(0.06, 0.16, 0.1), relief=0.6, grain=0.1, graine=40)
    M["acier"] = sf("a3_acier", (0.32, 0.3, 0.27), rough=0.42, met=0.55, usure=0.6, nu=(0.7, 0.67, 0.6), crasse=0.5, crasse_col=cr, graine=41)
    M["noir"] = sf("a3_noir", (0.012, 0.011, 0.01), rough=0.75, met=0.2, usure=0.1, crasse=0.3, graine=42)
    M["charbon"] = sf("a3_charbon", (0.018, 0.017, 0.018), rough=0.45, met=0.0, usure=0.6, nu=(0.09, 0.09, 0.1), crasse=0.5, grain=0.2, graine=43)
    M["caoutchouc"] = sf("a3_caout", (0.03, 0.028, 0.025), rough=0.7, met=0.0, usure=0.3, nu=(0.09, 0.085, 0.08), crasse=0.4, graine=44)
    M["cuir"] = sf("a3_cuir", (0.13, 0.05, 0.02), rough=0.7, met=0.0, usure=0.3, crasse=0.4, graine=45)
    M["cadran"] = sf("a3_cadran", (0.62, 0.55, 0.42), rough=0.3, met=0.0, usure=0.0, crasse=0.0, graine=46)
    M["ambre"] = MT.lumiere(S, "a3_ambre", (1.0, 0.42, 0.06), 1.0, main=0.72)
    M["braise"] = S.mat_emissive("a3_braise", (1.0, 0.33, 0.05), strength=2.6, base=(0.05, 0.015, 0.004), main_scale=0.7, crust=(16.0, 0.65, 3.0))
    return M


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(3303)
    ZS = 0.13       # dessus du sol de l'atelier

    # ---------------------------------------------------------------- socle : pierre, bastions, planches, rails, rampe
    lot.put(M["pierre"], G.prisme([(-1.34, -1.72), (1.34, -1.72), (1.48, -1.6), (1.48, 1.82), (1.32, 2.08), (-1.32, 2.08), (-1.48, 1.82), (-1.48, -1.6)], 0.0, ZS - 0.02))
    lot.put(M["pierre"], G.prisme([(-1.46, -2.06), (-0.55, -2.06), (-0.55, -1.5), (-1.46, -1.5)], 0.0, ZS - 0.01))
    lot.put(M["pierre"], G.prisme([(1.05, -2.06), (1.46, -2.06), (1.46, -1.5), (1.05, -1.5)], 0.0, ZS - 0.01))
    lot.put(M["bois"], G.boite((0.0, -0.62, ZS - 0.008), (2.5, 2.1, 0.02)))
    for x in (-1.2, 1.2):
        lot.put(M["fonte"], G.boite((x, -0.62, ZS + 0.005), (0.06, 2.1, 0.03)))
    rail_x = (ROBOT[0] - 0.3, ROBOT[0] + 0.3)
    for k in range(10):                                                 # traverses
        y = -1.64 + 0.27 * k
        lot.put(M["bois"], G.boite((ROBOT[0], y, ZS + 0.01), (0.86, 0.13, 0.03), r.f(-0.04, 0.04)))
    for x in rail_x:
        lot.put(M["acier"], G.boite((x, -0.45, ZS + 0.045), (0.05, 2.5, 0.05)))
    # rampe de sortie : planches en pente et fers
    ramp = [(ROBOT[0] - 0.6, -1.72, ZS - 0.005), (ROBOT[0] + 0.6, -1.72, ZS - 0.005), (ROBOT[0] + 0.6, -2.26, 0.0), (ROBOT[0] - 0.6, -2.26, 0.0)]
    for k in range(5):
        t0, t1 = k / 5.0 + 0.012, (k + 1) / 5.0 - 0.012
        a, b = G.lerp(ramp[0], ramp[3], t0), G.lerp(ramp[1], ramp[2], t0)
        c, d = G.lerp(ramp[1], ramp[2], t1), G.lerp(ramp[0], ramp[3], t1)
        q = [a, b, c, d]
        top = [G.add(p, (0, 0, 0.03)) for p in q]
        lot.put(M["bois"], G.merge((top, [(0, 1, 2, 3)], [(p[0], p[1] * 1.0) for p in top]), G.loft([[q[3], q[2]], [top[3], top[2]]], closed=False)))
    for x in rail_x:
        lot.put(M["acier"], G.tube([(x, -1.7, ZS + 0.05), (x, -2.24, 0.05)], 0.024, 6))
    # arceau de fer de la sortie, 2 lanternes ambrées
    pa, pb = (ROBOT[0] - 0.66, -1.72, ZS), (ROBOT[0] + 0.66, -1.72, ZS)
    for p in (pa, pb):
        lot.put(M["pierre"], G.boite((p[0], p[1], ZS + 0.09), (0.2, 0.2, 0.18)))
        O.profil(lot, M["fonte"], p, (0, 0, 1), [(0.14, 0.075), (0.2, 0.06), (0.95, 0.042), (1.0, 0.06), (1.02, 0.03)], 12)
    arc = [(ROBOT[0] + 0.66 * math.cos(t), -1.72, ZS + 1.02 + 0.3 * math.sin(t)) for t in [math.pi * i / 16.0 for i in range(17)]]
    lot.put(M["fonte"], G.tube(arc, 0.026, 8))
    arc2 = [(ROBOT[0] + 0.66 * math.cos(t), -1.72, ZS + 1.02 + 0.13 * math.sin(t)) for t in [math.pi * i / 16.0 for i in range(17)]]
    lot.put(M["fonte"], G.tube(arc2, 0.016, 6))
    for x in (-0.33, 0.0, 0.33):
        z = ZS + 1.02 + 0.13 * math.sqrt(1 - (x / 0.66) ** 2)
        z2 = ZS + 1.02 + 0.3 * math.sqrt(1 - (x / 0.66) ** 2)
        lot.put(M["fonte"], G.tube([(ROBOT[0] + x, -1.72, z), (ROBOT[0] + x, -1.72, z2)], 0.012, 5))
    for p in (pa, pb):
        q = G.add(p, (0.0, -0.06, 1.0))
        lot.put(M["ambre"], G.sphere(G.add(q, (0, -0.09, -0.09)), 0.062, 10, 5))
        lot.put(M["fonte"], G.tube([q, G.add(q, (0, -0.09, 0.0)), G.add(q, (0, -0.09, -0.03))], 0.012, 5))
        lot.put(M["cuivre_uni"], G.tour([(q[2] - 0.035, 0.07), (q[2] - 0.005, 0.03)], 10, "z", (q[0], q[1] - 0.09, 0.0), cap0=True))

    # ---------------------------------------------------------------- abside de brique au nord
    def ell(a, g=0.0):
        return (1.44 * math.cos(a) * (1.0 + g), 0.72 + 1.32 * math.sin(a) * (1.0 + g))
    a0, a1 = math.radians(-6.0), math.radians(186.0)
    nb = 30
    for (zb, zh, g0) in ((ZS - 0.02, 1.62, 0.0),):
        out = [(ell(a0 + (a1 - a0) * i / nb, g0)[0], ell(a0 + (a1 - a0) * i / nb, g0)[1]) for i in range(nb + 1)]
        ins = [ell(a0 + (a1 - a0) * i / nb, g0 - 0.085) for i in range(nb + 1)]
        lot.put(M["brique"], G.loft([[(p[0], p[1], zb) for p in out], [(p[0], p[1], zh) for p in out]], closed=False))
        lot.put(M["brique"], G.loft([[(p[0], p[1], zb) for p in ins], [(p[0], p[1], zh) for p in ins]], closed=False))
        lot.put(M["pierre"], G.loft([[(p[0], p[1], zh + 0.03) for p in out], [(p[0], p[1], zh + 0.03) for p in ins]], closed=False))
        lot.put(M["pierre"], G.loft([[(p[0], p[1], zh - 0.02) for p in out], [(p[0], p[1], zh + 0.03) for p in out]], closed=False))
    for a in (math.radians(32.0), math.radians(72.0), math.radians(115.0), math.radians(155.0)):             # contreforts de fer
        p, q = ell(a, 0.0), ell(a, 0.05)
        lot.put(M["fonte"], G.boite(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, 0.85), (0.1, 0.1, 1.5), math.atan2(p[1] - 0.72, p[0])))
    # toit de cuivre ondulé en demi-cône, posé sur l'abside et appuyé à la chaudière
    zs = 2.05
    rings = [[(ell(a0 + (a1 - a0) * i / nb, 0.04)[0], ell(a0 + (a1 - a0) * i / nb, 0.04)[1], 1.66) for i in range(nb + 1)],
             [(ell(a0 + (a1 - a0) * i / nb, -0.52)[0], ell(a0 + (a1 - a0) * i / nb, -0.52)[1] + 0.34, zs) for i in range(nb + 1)]]
    lot.put(M["ond"], G.loft(rings, closed=False))
    for i in range(1, nb, 5):
        lot.put(M["fonte"], G.tube([G.add(rings[0][i], (0, 0, 0.02)), G.add(rings[1][i], (0, 0, 0.02))], 0.016, 5))
    lot.put(M["fonte"], G.tube([G.add(p, (0, 0, 0.012)) for p in rings[1]], 0.022, 6))
    lot.put(M["noir"], G.loft([rings[1], [(p[0], p[1], zs - 0.04) for p in rings[1]]], closed=False))
    lot.put(M["noir"], G.loft([rings[1], [(0.0, 1.5, zs)] * (nb + 1)], closed=False))

    # ---------------------------------------------------------------- chaudière couchée, foyer, manomètre, régulateur
    by, bz, br = 1.05, 0.76, 0.58
    bx0, bx1 = -1.18, 0.88
    prof = [(bx0 - 0.1, 0.0), (bx0 - 0.09, br * 0.62), (bx0 - 0.02, br * 0.96), (bx0 + 0.04, br), (bx1 - 0.05, br), (bx1 + 0.02, br * 0.95), (bx1 + 0.09, br * 0.6), (bx1 + 0.1, 0.0)]
    lot.put(M["cuivre"], G.tour(prof, 40, "x", (0.0, by, bz)))
    for x in (bx0 + 0.08, -0.62, -0.1, 0.42, bx1 - 0.06):
        lot.put(M["fonte"], G.tour([(x - 0.045, br + 0.002), (x - 0.035, br + 0.022), (x + 0.035, br + 0.022), (x + 0.045, br + 0.002)], 40, "x", (0.0, by, bz)))
        O.rivets_anneau(lot, M["riv"], (0, by, bz), br + 0.022, x, 26, 0.016, axe="x")
    for (x, y) in ((-0.8, by), (0.55, by)):                               # berceaux
        lot.put(M["fonte"], G.boite((x, y, 0.22), (0.2, 0.92, 0.2)))
        lot.put(M["fonte"], G.boite((x, y - 0.42, 0.34), (0.2, 0.08, 0.28)))
    # foyer à porte ambrée, sur le flanc sud
    fx = 0.22
    fy = by - br - 0.06
    lot.put(M["fonte"], G.boite((fx, fy + 0.1, 0.44), (0.58, 0.32, 0.56)))
    lot.put(M["fonte2"], G.boite((fx, fy - 0.07, 0.42), (0.46, 0.04, 0.42)))
    lot.put(M["braise"], G.boite((fx, fy - 0.092, 0.4), (0.3, 0.012, 0.2)))
    for k in range(4):
        lot.put(M["fonte"], G.boite((fx - 0.12 + 0.08 * k, fy - 0.105, 0.4), (0.022, 0.02, 0.24)))
    lot.put(M["acier"], G.tube([(fx + 0.17, fy - 0.1, 0.56), (fx - 0.2, fy - 0.12, 0.64)], 0.014, 5))
    # manomètre : grand cadran ambré
    dn = G.norm((0.0, -0.78, 0.62))
    dp = G.add((-0.36, by, bz), G.mul(dn, br + 0.05))
    lot.put(M["cuivre_uni"], G.tube([G.add(dp, G.mul(dn, -0.06)), dp], 0.05, 8))
    lot.put(M["laiton"], G.oriente(G.tour([(0.0, 0.2), (0.02, 0.2), (0.05, 0.19), (0.055, 0.165), (0.03, 0.16)], 24, "z", cap0=True), dp, dn))
    lot.put(M["ambre"], G.oriente(G.tour([(0.032, 0.165), (0.036, 0.0)], 24, "z"), dp, dn))
    for k in range(8):
        t = -0.6 + k * 0.53
        lot.put(M["noir"], O.pose_plane(G.boite((0.135 * math.cos(t), 0.135 * math.sin(t), 0.038), (0.012, 0.032, 0.005), t + math.pi / 2), dp, dn))
    lot.put(M["noir"], O.pose_plane(G.boite((0.035, 0.05, 0.042), (0.012, 0.13, 0.006), -0.6), dp, dn))
    # dôme de vapeur en laiton, soupape, et régulateur à boules
    ax = 0.48
    O.profil(lot, M["laiton"], (ax, by, bz + br - 0.05), (0, 0, 1), [(0.0, 0.24), (0.05, 0.25), (0.08, 0.2), (0.3, 0.195), (0.34, 0.16), (0.42, 0.11), (0.47, 0.0)], 22)
    lot.put(M["fonte"], G.tour([(bz + br + 0.14, 0.2), (bz + br + 0.17, 0.215), (bz + br + 0.2, 0.2)], 22, "z", (ax, by, 0.0)))
    q = (ax + 0.0, by, bz + br + 0.42)
    lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, 0.14))], 0.016, 6))
    O.profil(lot, M["cuivre_uni"], G.add(q, (0, 0, 0.14)), (0, 0, 1), [(0.0, 0.035), (0.03, 0.05), (0.09, 0.022), (0.1, 0.0)], 10)
    gx = -0.1
    gz = bz + br
    lot.put(M["fonte"], G.boite((gx, by, gz + 0.02), (0.24, 0.24, 0.06)))
    lot.put(M["acier"], G.tube([(gx, by, gz), (gx, by, gz + 0.62)], 0.018, 6))
    O.profil(lot, M["laiton"], (gx, by, gz + 0.6), (0, 0, 1), [(0.0, 0.03), (0.04, 0.05), (0.08, 0.0)], 10)
    for s in (-1, 1):
        for (zb, zc) in ((gz + 0.56, gz + 0.32),):
            bal = (gx + s * 0.24, by - 0.03, zc)
            lot.put(M["acier"], G.tube([(gx, by, zb), bal], 0.011, 5))
            lot.put(M["acier"], G.tube([(gx, by, gz + 0.2), G.lerp((gx, by, zb), bal, 0.55)], 0.009, 5))
            lot.put(M["laiton"], G.sphere(bal, 0.078, 12, 6))
    # cheminée ronde à collerette : la signature de l'âge
    cx, cy = -0.96, 1.42
    O.profil(lot, M["fonte"], (cx, cy, 0.6), (0, 0, 1), [(0.0, 0.42), (0.1, 0.42), (0.14, 0.34), (0.75, 0.29), (0.82, 0.24)], 24)
    prof_c = [(1.3, 0.21), (3.55, 0.165), (3.67, 0.2), (3.8, 0.285), (3.86, 0.3), (3.88, 0.25)]
    lot.put(M["fonte"], G.tour(prof_c, 28, "z", (cx, cy, 0.0)))
    lot.put(M["noir"], G.tour([(3.88, 0.25), (3.72, 0.2), (3.7, 0.0)], 20, "z", (cx, cy, 0.0)))
    for (z, rc) in ((1.46, 0.21), (2.05, 0.2), (2.62, 0.185), (3.15, 0.175), (3.56, 0.17)):
        lot.put(M["cuivre_uni"], G.tour([(z - 0.03, rc + 0.005), (z - 0.02, rc + 0.022), (z + 0.02, rc + 0.022), (z + 0.03, rc + 0.005)], 28, "z", (cx, cy, 0.0)))
        O.rivets_anneau(lot, M["riv"], (cx, cy, 0.0), rc + 0.02, z, 14, 0.012)
    for (dx, dy) in ((0.95, -0.2), (-0.32, 0.72), (0.6, 0.65)):           # haubans
        lot.put(M["acier"], G.tube([(cx, cy, 3.12), (cx + dx, cy + dy, 1.62)], 0.006, 3))
    # conduite de vapeur vers la potence et vers le bras, sur le sol
    O.tuyau(lot, M["cuivre_uni"], M["laiton"], [(bx1 + 0.06, by, bz), (1.3, by, bz), (1.3, by, ZS + 0.09), (1.3, -0.82, ZS + 0.09), (1.14, -0.82, ZS + 0.09)], 0.043, rb=0.12, pas_bride=0.55)
    O.tuyau(lot, M["cuivre_uni"], M["laiton"], [(-1.26, by - 0.3, 0.55), (-1.26, -0.32, 0.55), (-1.26, -0.32, ZS + 0.15), (-1.2, -0.42, ZS + 0.15)], 0.036, rb=0.1, pas_bride=0.55)
    lot.put(M["fonte"], G.boite((-1.26, 0.2, 0.32), (0.06, 0.06, 0.4)))
    O.flexible(lot, M["caoutchouc"], [(-0.42, by - br + 0.02, 0.56), (-0.2, 0.05, ZS + 0.1), (-0.14, -0.52, 0.5), (ROBOT[0] - RR * 0.72, ROBOT[1] + RR * 0.2, ROBOT[2] - 0.12)], 0.028)
    # citerne d'eau en cuivre, sur 3 pieds, au nord-est
    wx, wy = 1.0, 1.28
    for a in (0.5, 2.6, 4.7):
        lot.put(M["fonte"], G.tube([(wx + 0.34 * math.cos(a), wy + 0.34 * math.sin(a), 1.42), (wx + 0.44 * math.cos(a), wy + 0.44 * math.sin(a), 0.1)], 0.03, 6))
    # (les pieds traversent le toit de l'abside côté nord : la citerne est posée sur son faîte)
    lot.put(M["cuivre"], G.tour([(1.42, 0.0), (1.44, 0.34), (1.5, 0.385), (2.05, 0.385), (2.09, 0.36), (2.27, 0.1), (2.3, 0.0)], 28, "z", (wx, wy, 0.0)))
    for z in (1.58, 1.82, 2.03):
        lot.put(M["fonte"], G.tour([(z - 0.015, 0.388), (z - 0.01, 0.4), (z + 0.01, 0.4), (z + 0.015, 0.388)], 28, "z", (wx, wy, 0.0)))
        O.rivets_anneau(lot, M["riv"], (wx, wy, 0.0), 0.4, z, 18, 0.011)
    O.tuyau(lot, M["cuivre_uni"], M["laiton"], [(wx - 0.3, wy - 0.25, 1.6), (0.4, wy - 0.25, 1.6), (0.4, by, bz + br - 0.04)], 0.032, rb=0.1)

    # ---------------------------------------------------------------- chariot, berceaux du robot
    rx, ry, rz = ROBOT
    lot.put(M["fonte"], G.boite((rx, ry, ZS + 0.2), (0.82, 0.86, 0.08)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            cw = (rx + sx * 0.3, ry + sy * 0.3, ZS + 0.12)
            lot.put(M["fonte2"], G.tour([(-0.03, 0.09), (0.03, 0.09)], 16, "x", (cw[0], cw[1], cw[2]), cap0=True, cap1=True))
    for y in (ry - 0.26, ry + 0.26):                                     # étriers qui portent la chaudière
        arc = [(rx + 0.44 * math.cos(t), y, rz + 0.44 * math.sin(t)) for t in [math.pi + 0.25 + (math.pi - 0.5) * i / 14.0 for i in range(15)]]
        lot.put(M["fonte"], G.tube(arc, 0.032, 8))
        lot.put(M["fonte"], G.boite((rx - 0.32, y, (ZS + 0.24 + rz - 0.3) / 2.0 + 0.06), (0.05, 0.05, rz - 0.3 - ZS - 0.1)))
        lot.put(M["fonte"], G.boite((rx + 0.32, y, (ZS + 0.24 + rz - 0.3) / 2.0 + 0.06), (0.05, 0.05, rz - 0.3 - ZS - 0.1)))

    # ---------------------------------------------------------------- le Trotte-Vapeur en cours de montage
    prof_r = [(rz - RR * math.cos(t) * 0.92, RR * math.sin(t)) for t in [0.15 + (math.pi - 0.3) * i / 16.0 for i in range(17)]]
    prof_r = [(rz - RR * 0.93, 0.0)] + prof_r + [(rz + RR * 0.93, 0.0)]
    lot.put(M["laiton"], G.tour(prof_r, 36, "z", (rx, ry, 0.0)))
    for z in (rz - 0.2, rz + 0.2):
        rc = RR * math.sqrt(max(0.0, 1.0 - ((z - rz) / (RR * 0.93)) ** 2))
        lot.put(M["cuivre_uni"], G.tour([(z - 0.03, rc), (z - 0.02, rc + 0.02), (z + 0.02, rc + 0.02), (z + 0.03, rc)], 36, "z", (rx, ry, 0.0)))
        O.rivets_anneau(lot, M["riv"], (rx, ry, 0.0), rc + 0.018, z, 18, 0.012)
    lot.put(M["fonte"], G.tour([(rz + 0.31, 0.27), (rz + 0.36, 0.29), (rz + 0.4, 0.23)], 24, "z", (rx, ry, 0.0)))
    # panneau ouvert sur le flanc sud-est : on voit le foyer du robot
    pn = G.norm((0.5, -0.82, 0.2))
    pc = G.add(ROBOT, G.mul(pn, RR * 0.97))
    lot.put(M["fonte"], O.pose_plane(G.boite((0, 0, 0.0), (0.34, 0.3, 0.03)), pc, pn))
    lot.put(M["braise"], O.pose_plane(G.boite((0, 0, 0.02), (0.24, 0.2, 0.012)), pc, pn))
    for k in range(3):
        lot.put(M["fonte"], O.pose_plane(G.boite((-0.08 + 0.08 * k, 0, 0.03), (0.018, 0.22, 0.012)), pc, pn))
    lot.put(M["cuivre_uni"], O.pose_plane(G.boite((0.27, 0.0, 0.1), (0.04, 0.3, 0.26), 0.0, 0.0, 1.0), pc, pn))     # le volet rabattu
    # petite cheminée à collerette du robot (rappel de la grande)
    O.profil(lot, M["fonte"], (rx - 0.1, ry + 0.1, rz + 0.3), (0, 0, 1), [(0.0, 0.09), (0.22, 0.05), (0.4, 0.05), (0.46, 0.085), (0.48, 0.05)], 12)
    # hublots-yeux du robot, vers le sud-ouest
    for a in (-2.15, -1.75):
        n = (math.cos(a), math.sin(a), 0.35)
        O.hublot(lot, M["fonte"], M["ambre"], G.add(ROBOT, G.mul(G.norm(n), RR * 0.95)), n, 0.062)
    # 2 pattes posées (nord-est, sud-est) ; 2 moyeux vides (ouest), une patte pend au palan, une attend sur l'établi
    def patte(lot, hanche, genou, pied, rp=0.058):
        lot.put(M["fonte"], G.sphere(hanche, rp * 1.8, 12, 6))
        lot.put(M["cuivre_uni"], G.tube([hanche, genou], rp, 10))
        lot.put(M["fonte"], G.tube([G.lerp(hanche, genou, 0.2), G.lerp(hanche, genou, 0.75)], rp * 1.35, 10))
        lot.put(M["laiton"], G.sphere(genou, rp * 1.6, 12, 6))
        lot.put(M["fonte"], G.tube([genou, pied], rp * 1.08, 10))
        lot.put(M["acier"], G.tube([G.lerp(genou, pied, 0.1), G.lerp(genou, pied, 0.55)], rp * 0.7, 6))
        lot.put(M["fonte"], G.tour([(pied[2] - 0.04, 0.15), (pied[2] + 0.02, 0.14), (pied[2] + 0.06, 0.07)], 14, "z", (pied[0], pied[1], 0.0), cap1=True))
    patte(lot, (rx + 0.36, ry - 0.34, rz - 0.13), (rx + 0.72, ry - 0.66, rz + 0.02), (rx + 0.85, ry - 0.78, ZS + 0.05))
    patte(lot, (rx + 0.36, ry + 0.34, rz - 0.13), (rx + 0.74, ry + 0.62, rz + 0.04), (rx + 0.86, ry + 0.8, ZS + 0.05))
    for (dx, dy) in ((-0.36, -0.34), (-0.36, 0.34)):
        h = (rx + dx, ry + dy, rz - 0.13)
        lot.put(M["fonte"], G.oriente(G.tour([(0.0, 0.11), (0.04, 0.12), (0.08, 0.08), (0.07, 0.0)], 12, "z"), h, (dx, dy, -0.1)))
    # faisceau de durites qui pend du moyeu vide sud-ouest
    O.flexible(lot, M["caoutchouc"], [(rx - 0.4, ry - 0.36, rz - 0.15), (rx - 0.56, ry - 0.46, rz - 0.42), (rx - 0.5, ry - 0.5, rz - 0.66)], 0.018)
    O.flexible(lot, M["cuivre_uni"], [(rx - 0.36, ry - 0.42, rz - 0.15), (rx - 0.46, ry - 0.5, rz - 0.36), (rx - 0.4, ry - 0.48, rz - 0.56)], 0.012)

    # ---------------------------------------------------------------- potence à contrepoids
    pc = (-1.16, -0.46)
    lot.put(M["pierre"], G.boite((pc[0], pc[1], ZS + 0.06), (0.42, 0.42, 0.12)))
    lot.put(M["fonte"], G.tour([(ZS + 0.12, 0.17), (ZS + 0.3, 0.13), (ZS + 0.42, 0.095), (3.0, 0.07), (3.34, 0.06), (3.42, 0.09), (3.46, 0.0)], 18, "z", (pc[0], pc[1], 0.0)))
    for z in (0.95, 1.8, 2.5):
        lot.put(M["cuivre_uni"], G.tour([(z - 0.022, 0.085), (z + 0.022, 0.085)], 16, "z", (pc[0], pc[1], 0.0)))
    z_j = 2.92
    jib_a, jib_b = (pc[0] - 0.36, pc[1], z_j - 0.02), (rx + 0.52, ry, z_j + 0.04)
    O.treillis(lot, M["fonte"], jib_a, jib_b, l=0.15, h=0.2, n=9, rc=0.021, rd=0.01, up=(0.0, 0.0, 1.0))
    lot.put(M["fonte"], G.tour([(z_j - 0.13, 0.13), (z_j + 0.13, 0.13)], 16, "z", (pc[0], pc[1], 0.0), cap0=True, cap1=True))
    lot.put(M["acier"], G.tube([(pc[0], pc[1], 3.4), (jib_b[0] - 0.05, jib_b[1], jib_b[2] + 0.1)], 0.012, 5))
    lot.put(M["acier"], G.tube([(pc[0], pc[1], 3.4), (jib_a[0], jib_a[1], jib_a[2] + 0.1)], 0.012, 5))
    # contrepoids en fonte accroché à la queue de la flèche
    cw = (jib_a[0] + 0.02, jib_a[1] - 0.06)
    lot.put(M["fonte2"], G.tour([(z_j - 0.62, 0.0), (z_j - 0.6, 0.11), (z_j - 0.46, 0.19), (z_j - 0.36, 0.2), (z_j - 0.27, 0.15), (z_j - 0.21, 0.04)], 16, "z", (cw[0], cw[1], 0.0)))
    lot.put(M["cuivre_uni"], G.tour([(z_j - 0.44, 0.198), (z_j - 0.39, 0.205)], 16, "z", (cw[0], cw[1], 0.0)))
    lot.put(M["acier"], G.tube([(cw[0], cw[1], z_j - 0.2), (cw[0], cw[1], z_j - 0.08)], 0.016, 5))
    # poulie, chariot, chaîne et crochet au-dessus de la chaudière du robot
    tx = rx
    lot.put(M["fonte"], G.boite((tx, ry, z_j - 0.1), (0.2, 0.17, 0.1)))
    lot.put(M["laiton"], G.tour([(ry - 0.03, 0.09), (ry + 0.03, 0.09)], 18, "y", (tx, 0.0, z_j - 0.2), cap0=True, cap1=True))
    for s in (-1, 1):
        ch = [(tx + s * 0.07, ry, z_j - 0.22), (tx + s * 0.11, ry, rz + 0.58)]
        n = 14
        for k in range(n):
            a, b = G.lerp(ch[0], ch[1], k / float(n)), G.lerp(ch[0], ch[1], (k + 1) / float(n))
            lot.put(M["acier"], G.tube([a, b], 0.012 if k % 2 else 0.016, 5))
        lot.put(M["acier"], G.tube([ch[1], (rx + s * 0.27, ry + s * 0.03, rz + 0.33)], 0.01, 4))
    # palonnier
    lot.put(M["fonte"], G.boite((tx, ry, rz + 0.6), (0.34, 0.06, 0.04)))
    # bride de vapeur sur la potence
    O.profil(lot, M["cuivre_uni"], (pc[0] - 0.04, pc[1], ZS + 0.15), (0, 0, 1), [(0.0, 0.03), (0.3, 0.03)], 8)

    # ---------------------------------------------------------------- bras à vapeur (riveteuse) à l'est du robot
    O.bras(lot, M["cuivre_uni"], M["fonte"], M["caoutchouc"], (1.14, -0.82, ZS), (1.14, -0.82, 0.74), (1.24, -0.52, 1.42), (rx + RR + 0.28, ry - 0.2, 1.42),
           (rx + RR + 0.04, ry - 0.2, rz + 0.1), r=0.082, socle=0.18, lum=M["ambre"], riv=M["laiton"])

    # ---------------------------------------------------------------- établi au sud-ouest : la patte qui attend, outils, tonneau
    bx, bzc = -0.93, 0.56
    by_ = -1.15
    lot.put(M["bois"], G.boite((bx, by_, bzc), (0.82, 0.5, 0.06)))
    for (dx, dy) in ((-0.34, -0.2), (0.34, -0.2), (-0.34, 0.2), (0.34, 0.2)):
        lot.put(M["fonte"], G.boite((bx + dx, by_ + dy, (ZS + bzc) / 2.0), (0.06, 0.06, bzc - ZS)))
    h, g, p = (bx - 0.32, by_ + 0.1, bzc + 0.1), (bx + 0.06, by_ + 0.05, bzc + 0.09), (bx + 0.34, by_ - 0.12, bzc + 0.08)
    lot.put(M["fonte"], G.sphere(h, 0.09, 12, 6))
    lot.put(M["cuivre_uni"], G.tube([h, g], 0.052, 10))
    lot.put(M["laiton"], G.sphere(g, 0.085, 12, 6))
    lot.put(M["fonte"], G.tube([g, p], 0.055, 10))
    lot.put(M["fonte"], G.boite((bx - 0.2, by_ - 0.17, bzc + 0.06), (0.14, 0.12, 0.08)))
    lot.put(M["acier"], G.boite((bx + 0.08, by_ - 0.18, bzc + 0.05), (0.26, 0.03, 0.03), 0.3))
    # tonneaux et tas de charbon : devant le foyer
    for (x, y, rt) in ((-1.28, -1.8, 0.14), (-0.98, -1.86, 0.12)):
        lot.put(M["bois"], G.tour([(ZS, rt * 0.88), (ZS + 0.14, rt), (ZS + 0.3, rt * 0.88)], 16, "z", (x, y, 0.0), cap1=True))
        for z in (ZS + 0.05, ZS + 0.24):
            lot.put(M["fonte"], G.tour([(z - 0.012, rt * 0.95), (z + 0.012, rt * 0.96)], 16, "z", (x, y, 0.0)))
    lot.put(M["fonte2"], G.boite((1.18, 0.28, ZS + 0.13), (0.46, 0.5, 0.26)))
    lot.put(M["noir"], G.boite((1.18, 0.28, ZS + 0.26), (0.38, 0.42, 0.015)))
    ra = G.Rnd(3351)
    for k in range(34):
        a, d = ra.f(0.0, TAU), ra.f(0.0, 0.19)
        p = (1.18 + d * math.cos(a) * 1.0, 0.28 + d * math.sin(a) * 1.1, ZS + 0.27 + (0.19 - d) * 0.75 + ra.f(0.0, 0.02))
        lot.put(M["charbon"], G.sphere(p, ra.f(0.035, 0.06), 5, 2))
    # pelle, caisse de boulons, ferraille
    lot.put(M["bois"], G.tube([(1.34, -0.05, ZS + 0.02), (1.1, -0.28, 0.75)], 0.016, 5))
    lot.put(M["acier"], G.boite((1.36, -0.03, ZS + 0.05), (0.12, 0.16, 0.012), 0.8, 0.4))
    lot.put(M["bois"], G.boite((1.26, -1.8, ZS + 0.12), (0.28, 0.26, 0.24), 0.25))
    lot.put(M["fonte"], G.boite((1.26, -1.8, ZS + 0.245), (0.3, 0.05, 0.015), 0.25))
    for k in range(10):
        x, y = ra.f(-1.25, 1.25), ra.f(-1.6, 0.25)
        if abs(x - rx) < 0.6 and abs(y - ry) < 0.65:
            continue
        lot.put(M["acier"] if k % 2 else M["fonte2"], G.boite((x, y, ZS + 0.015), (ra.f(0.05, 0.11), ra.f(0.03, 0.06), 0.02), ra.f(0.0, 3.0)))
    return {"robot": ROBOT}
