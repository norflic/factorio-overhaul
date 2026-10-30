"""Essai B du four de frittage : FOUR À CLOCHE. Cornue verticale de fonte rouillée cerclée au centre, couronne de
4 brûleurs alimentée par l'arrivée nord, regards rougeoyants ; cloche de basalte levée par un portique à palan ;
gaz chaud de la cloche vers un condenseur à ailettes (sud-est), puis la sortie sud ; armoire au sud-ouest."""
import math

import geo
from organes import Y
import fritt_commun as FC


def build(S, k):
    FC.raccords(k)
    z0 = k.socle(3, 0.4, 0.14, "socle", "capot")
    xc, yc, R = -0.12, Y(0.12), 0.56
    # embase et cornue cerclée
    k.put("structure", geo.tour([(z0, R + 0.16), (z0 + 0.1, R + 0.16), (z0 + 0.14, R + 0.06), (z0 + 0.14, 0.0)], 40, "z",
                                (xc, yc, 0.0)))
    k.boulons_cercle((xc, yc, z0 + 0.1), R + 0.11, 16, (0, 0, 1), 0.02)
    zh = 1.38
    k.cuve_v("capot2", xc, yc, R, z0 + 0.14, zh, 40, (0.42, 0.78, 1.12), "structure", dome=0.0)
    for i in range(10):                                          # raidisseurs verticaux (moitié sud)
        a = math.pi + math.pi * (i + 0.5) / 10
        k.box("structure", (xc + (R + 0.012) * math.cos(a), yc + (R + 0.012) * math.sin(a), (z0 + 0.14 + zh) / 2),
              (0.03, 0.03, zh - z0 - 0.2), rz=a, petite=True)
    # couronne de brûleurs (collecteur annulaire) et 4 brûleurs, regards
    zb = 0.46
    k.put("tuyau", geo.tube([(xc + (R + 0.24) * math.cos(geo.TAU * i / 40), yc + (R + 0.24) * math.sin(geo.TAU * i / 40),
                               zb) for i in range(41)], 0.045, 10, False, False))
    for i in range(4):
        a = geo.TAU * i / 4 + math.pi / 4
        e = (math.cos(a), math.sin(a), 0.0)
        p0 = (xc + (R + 0.24) * e[0], yc + (R + 0.24) * e[1], zb)
        p1 = (xc + (R + 0.02) * e[0], yc + (R + 0.02) * e[1], zb + 0.12)
        k.tuyau("tuyau", [p0, (p0[0], p0[1], zb + 0.12), p1], 0.035, 0.06, False)
        k.put("chrome", geo.oriente(geo.tour([(0.0, 0.07), (0.12, 0.07), (0.12, 0.0)], 12, "z"), p1, geo.mul(e, -1)))
        k.box("acier", (p0[0], p0[1], (z0 + zb) / 2), (0.05, 0.05, zb - z0), petite=True)
    for a in (math.pi * 1.25, math.pi * 1.5, math.pi * 1.75):
        e = (math.cos(a), math.sin(a), 0.0)
        FC.regard(k, (xc + R * e[0], yc + R * e[1], 0.95), e, 0.042)
    k.halo(S, (xc, yc - R - 0.25, 0.9), (1.0, 0.3, 0.05), 7.0, 0.3)
    k.tuyau("tuyau", [(0.0, Y(1.28), z0 + 0.03), (0.0, Y(1.28), zb), (0.0, yc + R + 0.3, zb)], 0.05, 0.1)
    k.vanne((0.0, Y(1.22), 0.34), (0, 0, 1), 0.05, "chrome", "rouge")
    # cloche : jupe, dôme de basalte, joint de sable rougeoyant, oreilles de levage
    k.put("structure", geo.tour([(zh - 0.02, R + 0.07), (zh + 0.08, R + 0.07), (zh + 0.08, R - 0.02)], 40, "z",
                                (xc, yc, 0.0)))
    k.put("feu", geo.tour([(zh + 0.012, R + 0.075), (zh + 0.03, R + 0.075)], 40, "z", (xc, yc, 0.0)))
    k.cuve_v("capot", xc, yc, R + 0.04, zh + 0.04, zh + 0.22, 40, (zh + 0.13,), "structure", dome=0.5)
    zt = zh + 0.22 + (R + 0.04) * 0.5
    for i in range(4):
        a = geo.TAU * i / 4
        k.box("structure", (xc + 0.3 * math.cos(a), yc + 0.3 * math.sin(a), zt - 0.02), (0.05, 0.12, 0.12), rz=a,
              petite=True)
    # portique et palan
    zp = 2.38
    for x in (xc - 0.98, xc + 1.28):
        k.box("structure", (x, yc, (z0 + zp) / 2), (0.12, 0.12, zp - z0))
        for dz in (0.5, 1.1, 1.7):
            k.box("acier", (x, yc - 0.065, z0 + dz), (0.13, 0.02, 0.05), petite=True)
        k.box("structure", (x, yc, z0 + 0.03), (0.26, 0.26, 0.06))
        for sx in (-1, 1):
            for sy in (-1, 1):
                k.boulon((x + sx * 0.1, yc + sy * 0.1, z0 + 0.06), (0, 0, 1), 0.018)
    k.box("structure", (xc + 0.15, yc, zp + 0.08), (2.42, 0.14, 0.16))
    k.rivets([((xc - 0.95 + 0.16 * i, yc - 0.075, zp + 0.08), (0, -1, 0)) for i in range(15)], "rivet", 0.016, 0.01)
    k.caisson("capot2", xc - 0.14, xc + 0.14, yc - 0.12, yc + 0.12, zp - 0.16, zp, pas=0.08, rebord=None)
    k.cable((xc - 0.05, yc, zp - 0.16), (xc - 0.05, yc, zt + 0.05), 0.0, 0.016)
    k.cable((xc + 0.05, yc, zp - 0.16), (xc + 0.05, yc, zt + 0.05), 0.0, 0.016)
    k.put("acier", geo.tour([(zt + 0.02, 0.05), (zt + 0.1, 0.05)], 10, "z", (xc, yc, 0.0), cap0=True, cap1=True), True)
    k.echelle(xc + 1.28, yc - 0.08, z0, zp - 0.2, cage=True)
    # gaz chaud : cloche -> condenseur à ailettes (sud-est) -> sortie sud
    xq, yq = 0.95, Y(-0.9)
    k.tuyau("tuyau", [(xc + 0.28, yc - 0.2, zt - 0.08), (xc + 0.28, yc - 0.2, 2.08), (xq, yc - 0.2, 2.08),
                      (xq, yq, 2.08), (xq, yq, 1.5)], 0.06, 0.12)
    k.put("chrome", geo.tour([(z0, 0.15), (1.45, 0.15), (1.5, 0.08)], 18, "z", (xq, yq, 0.0), cap1=True))
    for i in range(14):
        zz = z0 + 0.2 + i * 0.075
        k.put("ailette", geo.tour([(zz - 0.01, 0.26), (zz + 0.01, 0.26)], 18, "z", (xq, yq, 0.0), cap0=True, cap1=True),
              True)
    for i in range(3):
        a = geo.TAU * i / 3 + 0.3
        k.box("structure", (xq + 0.28 * math.cos(a), yq + 0.28 * math.sin(a), (z0 + 1.35) / 2), (0.035, 0.035, 1.35 - z0),
              petite=True)
    k.tuyau("tuyau", [(xq - 0.15, yq, z0 + 0.22), (0.0, yq, z0 + 0.22), (0.0, Y(-1.28), z0 + 0.22),
                      (0.0, Y(-1.28), z0 + 0.02)], 0.05, 0.1)
    k.vanne((0.4, yq, z0 + 0.22), (1, 0, 0), 0.045, "chrome", "rouge")
    # armoire et pupitre (sud-ouest), passerelle
    k.armoire((-0.95, Y(-1.18), z0), (0.62, 0.26, 0.55), voyants=(("feu", 0.0), ("feu2", 0.08)))
    k.cable((-0.95, Y(-1.18), z0 + 0.55), (xc - 0.98, yc, z0 + 0.6), 0.08, 0.018)
    k.garde_corps([(-1.32, Y(-0.55), z0), (-1.32, Y(0.9), z0)], 0.36)
