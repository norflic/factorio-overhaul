"""Essai C du four à arc : FOUR BASCULANT À ÉLECTRODE UNIQUE (courant continu). Cuve bleue sur 2 berceaux qui
roulent sur 2 rails, 2 vérins de basculement (nord), voûte de porcelaine refroidie et sa couronne d'eau ; une grosse
électrode de graphite tenue par un long bras de potence (mât à l'ouest), tubes de cuivre et feston de câbles vers
la maison du transformateur (nord-ouest) ; bec de coulée rougeoyant (sud-est) au-dessus d'une poche sur chariot."""
import math

import geo
from organes import Y
import arc_commun as AC


def build(S, k):
    AC.raccord(k)
    z0 = k.socle(4, 0.45, 0.16, "socle", "structure")
    xc, yc, R = 0.3, Y(-0.12), 0.88
    zb = z0 + 0.36
    # rails et berceaux
    for s in (-1, 1):
        y = yc + s * 0.5
        k.box("structure", (xc, y, z0 + 0.04), (1.9, 0.12, 0.08))
        k.box("chrome", (xc, y, z0 + 0.1), (1.85, 0.05, 0.04))
        for x in (xc - 0.8, xc - 0.3, xc + 0.2, xc + 0.7):
            k.boulon((x, y - 0.065, z0 + 0.06), (0, -1, 0), 0.02)
        pts = [(xc + 1.25 * math.cos(a), y, z0 + 1.38 + 1.25 * math.sin(a))
               for a in [math.radians(-125 + 70 * i / 12) for i in range(13)]]
        k.put("structure", geo.tube(pts, 0.07, 10))
        for i in range(0, 13, 3):
            k.box("structure", (pts[i][0], y, (pts[i][2] + zb + 0.1) / 2), (0.06, 0.06, abs(zb + 0.1 - pts[i][2]) + 0.06),
                  petite=True)
        k.box("structure", (xc, y, zb), (1.3, 0.1, 0.1))
    k.box("structure", (xc, yc, zb - 0.02), (0.18, 1.1, 0.12))
    # cuve, panneaux refroidis, ceinture
    zc = zb + 0.78
    k.put("capot2", geo.tour([(zb, R - 0.22), (zb + 0.14, R), (zc, R)], 44, "z", (xc, yc, 0.0), cap0=True))
    for i in range(20):
        a = math.pi * 0.95 + math.pi * 1.1 * (i + 0.5) / 20
        k.box("structure", (xc + (R + 0.012) * math.cos(a), yc + (R + 0.012) * math.sin(a), (zb + 0.2 + zc) / 2),
              (0.028, 0.035, zc - zb - 0.26), rz=a, petite=True)
    k.put("structure", geo.tour([(zb + 0.4, R + 0.04), (zb + 0.48, R + 0.04)], 44, "z", (xc, yc, 0.0), cap0=True,
                                cap1=True))
    k.put("structure", geo.tour([(zc - 0.02, R + 0.07), (zc + 0.1, R + 0.07), (zc + 0.1, R - 0.05)], 44, "z",
                                (xc, yc, 0.0)))
    k.boulons_cercle((xc, yc, zc + 0.1), R + 0.02, 26, (0, 0, 1), 0.02)
    k.put("feu", geo.tour([(zc + 0.1, R - 0.02), (zc + 0.13, R - 0.02)], 44, "z", (xc, yc, 0.0)))
    # voûte de porcelaine, couronne d'eau, électrode unique
    zv = zc + 0.13
    k.put("structure", geo.tour([(zv, R + 0.05), (zv + 0.1, R + 0.05), (zv + 0.1, R - 0.06)], 44, "z", (xc, yc, 0.0)))
    k.put("capot", geo.tour([(zv + 0.1, R - 0.06), (zv + 0.22, R * 0.72), (zv + 0.3, R * 0.4), (zv + 0.33, 0.26),
                             (zv + 0.33, 0.0)], 44, "z", (xc, yc, 0.0)))
    for i in range(16):
        a = geo.TAU * i / 16
        k.box("structure", (xc + (R * 0.55) * math.cos(a), yc + (R * 0.55) * math.sin(a), zv + 0.27), (0.42, 0.035, 0.03),
              rz=a, petite=True)
    k.put("tuyau", geo.tube(AC.cercle((xc, yc), R * 0.3, zv + 0.36), 0.035, 10, False, False))
    zt = zv + 0.33
    k.put("feu", geo.tour([(zt, 0.23), (zt + 0.015, 0.23), (zt + 0.015, 0.17)], 24, "z", (xc, yc, 0.0)))
    za = 2.25
    AC.electrode(k, xc, yc, zt - 0.1, za + 0.55, 0.15)
    AC.collier(k, xc, yc, za, 0.15, 0.26)
    k.halo(S, (xc, yc - R - 0.15, zc + 0.12), (0.3, 0.6, 1.0), 8.0, 0.3)
    k.halo(S, (xc, yc, zt + 0.2), (0.3, 0.6, 1.0), 5.0, 0.3)
    # potence : mât (ouest), bras caisson, tubes de cuivre
    xm = -1.3
    k.box("structure", (xm, yc, (z0 + za + 0.45) / 2), (0.2, 0.2, za + 0.45 - z0))
    k.box("structure", (xm, yc, z0 + 0.05), (0.4, 0.4, 0.1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.boulon((xm + sx * 0.15, yc + sy * 0.15, z0 + 0.1), (0, 0, 1), 0.02)
    for dz in (0.4, 0.9, 1.4):
        k.box("chrome", (xm, yc - 0.11, z0 + dz), (0.14, 0.02, 0.2), petite=True)
    k.caisson("capot2", xm - 0.1, xc - 0.2, yc - 0.1, yc + 0.1, za - 0.1, za + 0.12, pas=0.1, rebord="structure")
    for dy in (-0.05, 0.05):
        k.put("cuivre", geo.tube([(xm + 0.05, yc + dy, za + 0.16), (xc - 0.22, yc + dy, za + 0.16)], 0.026, 8))
    k.put("chrome", geo.tour([(z0 + 0.1, 0.045), (za - 0.1, 0.045)], 10, "z", (xm + 0.2, yc - 0.15, 0.0), cap1=True))
    # vérins de basculement (nord)
    for x in (xc - 0.45, xc + 0.45):
        k.box("structure", (x, yc + R + 0.25, z0 + 0.06), (0.16, 0.16, 0.12))
        p0, p1 = (x, yc + R + 0.25, z0 + 0.1), (x, yc + R + 0.02, zb + 0.44)
        k.put("moteur", geo.tube([p0, geo.lerp(p0, p1, 0.55)], 0.07, 14))
        k.put("chrome", geo.tube([geo.lerp(p0, p1, 0.5), p1], 0.035, 10))
    # maison du transformateur (nord-ouest) et feston
    bornes = AC.transformateur(k, -1.85, -0.9, Y(0.8), Y(1.85), z0, 1.1, 3, None)
    for i, (bx, by, bz) in enumerate(bornes):
        k.cable((bx, by, bz), (xm + 0.02 * i, yc + 0.11, za - 0.05), 0.4, 0.03)
    # bec de coulée (sud-est) et poche sur chariot
    a = -math.pi / 4
    e = (math.cos(a), math.sin(a), 0.0)
    p0 = (xc + R * e[0], yc + R * e[1], zc - 0.18)
    p1 = (xc + (R + 0.5) * e[0], yc + (R + 0.5) * e[1], zc - 0.3)
    k.put("structure", geo.tube([geo.add(p0, geo.mul(e, -0.1)), p1], 0.11, 12))
    k.put("feu2", geo.tube([geo.add(p0, (0, 0, 0.06)), geo.add(p1, (0, 0, 0.065))], 0.05, 8))
    k.put("feu2", geo.tube([geo.add(p1, (0, 0, 0.03)), (p1[0] + 0.05, p1[1] - 0.05, z0 + 0.7)], 0.025, 6))
    xl, yl = p1[0] + 0.05, p1[1] - 0.05
    for s in (-1, 1):
        k.box("chrome", (xl, yl + s * 0.2, z0 + 0.02), (1.1, 0.04, 0.04))
    k.caisson("structure", xl - 0.3, xl + 0.3, yl - 0.25, yl + 0.25, z0 + 0.08, z0 + 0.2, pas=0.08, rebord=None)
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.put("acier", geo.tour([(-0.025, 0.06), (0.025, 0.06)], 12, "y", (xl + sx * 0.2, yl + sy * 0.25, z0 + 0.08),
                                    cap0=True, cap1=True), True)
    AC.poche(k, xl, yl, z0 + 0.2, 0.24, 0.32)
    k.halo(S, (xl, yl - 0.3, z0 + 0.6), (1.0, 0.45, 0.1), 6.0, 0.3)
    # arrivée d'eau (raccord nord) vers la couronne de la voûte
    k.tuyau("tuyau", [(-0.5, Y(1.65), z0 + 0.03), (-0.5, Y(1.65), 1.75), (-0.5, yc + 0.2, 1.75),
                      (xc - 0.25, yc + 0.2, zv + 0.36)], 0.05, 0.12)
    k.vanne((-0.5, Y(1.65), 0.9), (0, 0, 1), 0.05, "chrome", "rouge")
    # pupitre (sud-ouest), passerelle
    k.armoire((-1.3, Y(-1.55), z0), (0.8, 0.32, 0.62), voyants=(("feu", 0.0), ("feu2", 0.08), ("feu", 0.16)))
    k.box("capot", (-1.3, Y(-1.55) + 0.25, z0 + 0.45), (0.7, 0.2, 0.05), rx=0.5)
    k.garde_corps([(-0.75, Y(-1.15), z0), (-0.75, Y(0.55), z0)], 0.4)
