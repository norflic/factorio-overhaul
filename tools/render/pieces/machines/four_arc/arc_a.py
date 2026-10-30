"""Essai A du four à arc : FOUR TRIPHASÉ À 3 ÉLECTRODES (Héroult). Cuve bleue à panneaux refroidis et collecteur
d'eau, voûte réfractaire, 3 électrodes de graphite tenues par 3 bras sur 3 mâts (nord), câbles souples vers le
transformateur à traversées de porcelaine (nord-ouest) ; gaine de fumées coudée vers un dépoussiéreur (est) ; bec de
coulée et poche de laitier rougeoyante au sud ; pupitre (sud-ouest), centrale hydraulique (sud-est)."""
import math

import geo
from organes import Y
import arc_commun as AC


def build(S, k):
    AC.raccord(k)
    z0 = k.socle(4, 0.45, 0.16, "socle", "structure")
    xc, yc, R = 0.2, Y(-0.2), 1.0
    # cuve : creuset, virole bleue, panneaux refroidis, collecteur d'eau, ceinture
    zc = z0 + 0.82
    k.put("structure", geo.tour([(z0, R - 0.2), (z0 + 0.16, R - 0.04), (z0 + 0.2, R + 0.03), (z0 + 0.24, R + 0.03),
                                 (z0 + 0.24, R)], 48, "z", (xc, yc, 0.0), cap0=True))
    k.put("capot2", geo.tour([(z0 + 0.24, R), (zc, R)], 48, "z", (xc, yc, 0.0)))
    for i in range(24):
        a = math.pi * 0.95 + math.pi * 1.1 * (i + 0.5) / 24
        k.box("structure", (xc + (R + 0.012) * math.cos(a), yc + (R + 0.012) * math.sin(a), (z0 + 0.28 + zc) / 2),
              (0.028, 0.035, zc - z0 - 0.32), rz=a, petite=True)
    k.put("tuyau", geo.tube(AC.cercle((xc, yc), R + 0.09, z0 + 0.62), 0.04, 10, False, False))
    for i in range(12):
        a = geo.TAU * (i + 0.5) / 12
        if math.sin(a) > 0.6:
            continue
        p = (xc + (R + 0.09) * math.cos(a), yc + (R + 0.09) * math.sin(a), z0 + 0.62)
        q = (xc + (R + 0.01) * math.cos(a), yc + (R + 0.01) * math.sin(a), z0 + 0.5)
        k.put("tuyau", geo.tube([p, q], 0.018, 6), True)
    k.put("structure", geo.tour([(zc - 0.02, R + 0.07), (zc + 0.1, R + 0.07), (zc + 0.1, R - 0.05)], 48, "z",
                                (xc, yc, 0.0)))
    k.boulons_cercle((xc, yc, zc + 0.1), R + 0.02, 30, (0, 0, 1), 0.02)
    # arc visible dans le joint cuve-voûte (lueur bleue), voûte réfractaire, anneau de voûte
    k.put("feu", geo.tour([(zc + 0.1, R - 0.02), (zc + 0.14, R - 0.02)], 48, "z", (xc, yc, 0.0)))
    zv = zc + 0.14
    k.put("structure", geo.tour([(zv, R + 0.04), (zv + 0.12, R + 0.04), (zv + 0.12, R - 0.08)], 48, "z", (xc, yc, 0.0)))
    k.put("brique", geo.tour([(zv + 0.12, R - 0.08), (zv + 0.24, R * 0.75), (zv + 0.33, R * 0.45), (zv + 0.36, 0.0)], 48,
                             "z", (xc, yc, 0.0)))
    k.boulons_cercle((xc, yc, zv + 0.12), R - 0.02, 30, (0, 0, 1), 0.02)
    zt = zv + 0.36
    k.put("capot", geo.tour([(zt - 0.04, 0.48), (zt + 0.06, 0.48), (zt + 0.06, 0.0)], 32, "z", (xc, yc, 0.0)))
    # 3 électrodes, colliers, bras et mâts (nord)
    ym = Y(1.32)
    es = []
    for j, (a, za) in enumerate(((math.pi / 2, 2.05), (math.pi * 7 / 6, 1.9), (-math.pi / 6, 2.2))):
        ex, ey = xc + 0.34 * math.cos(a), yc + 0.34 * math.sin(a)
        es.append((ex, ey))
        k.put("feu", geo.tour([(zt + 0.06, 0.15), (zt + 0.075, 0.15), (zt + 0.075, 0.11)], 20, "z", (ex, ey, 0.0)))
        k.put("capot", geo.tour([(zt + 0.06, 0.17), (zt + 0.16, 0.15), (zt + 0.16, 0.12)], 20, "z", (ex, ey, 0.0)))
        AC.electrode(k, ex, ey, zt - 0.1, za + 0.42, 0.1)
        AC.collier(k, ex, ey, za, 0.1, 0.2)
        # bras : poutre-caisson bleue, tubes de cuivre dessus
        k.caisson("capot2", ex - 0.075, ex + 0.075, ey + 0.17, ym + 0.05, za - 0.07, za + 0.09, pas=0.1, rebord=None)
        for dx in (-0.04, 0.04):
            k.put("cuivre", geo.tube([(ex + dx, ey + 0.12, za + 0.12), (ex + dx, ym - 0.05, za + 0.12)], 0.022, 8))
        # mât et sa glissière
        k.box("structure", (ex, ym + 0.05, (z0 + za + 0.35) / 2), (0.15, 0.15, za + 0.35 - z0))
        for dz in (0.3, 0.8, 1.3):
            k.box("chrome", (ex, ym - 0.04, z0 + dz), (0.12, 0.03, 0.18), petite=True)
        k.box("structure", (ex, ym + 0.05, z0 + 0.04), (0.26, 0.26, 0.08))
        k.put("chrome", geo.tour([(z0 + 0.08, 0.035), (za - 0.07, 0.035)], 10, "z", (ex, ym - 0.12, 0.0), cap1=True))
    # transformateur (nord-ouest) et câbles souples refroidis vers les bras
    bornes = AC.transformateur(k, -1.78, -0.95, Y(0.95), Y(1.88), z0, 1.0, 3, "ouest")
    for (bx, by, bz), (ex, ey), za in zip(bornes, es, (2.05, 1.9, 2.2)):
        k.cable((bx, by, bz), (ex - 0.04, ym - 0.05, za + 0.14), 0.32, 0.03, "cable")
    k.put("structure", geo.tube([(-1.9, Y(1.25), 1.75), (0.6, Y(1.25), 1.75)], 0.03, 6))
    for x in (-1.85, -0.95):
        k.box("structure", (x, Y(1.25), (1.0 + 1.75) / 2), (0.05, 0.05, 0.75), petite=True)
    # gaine de fumées (4e trou) vers le dépoussiéreur (est)
    fx, fy = xc + 0.5, yc + 0.32
    k.put("capot", geo.tour([(zt - 0.12, 0.17), (zt + 0.12, 0.17)], 20, "z", (fx, fy, 0.0), cap1=False))
    k.tuyau("capot2", [(fx, fy, zt + 0.1), (fx, fy, 1.95), (1.62, fy, 1.95), (1.62, fy, 1.25)], 0.15, 0.25)
    k.caisson("transfo", 1.32, 1.92, Y(-0.35), Y(1.6), z0, 1.15, pas=0.12, rebord="structure")
    for i in range(4):
        y = Y(-0.2) + i * 0.6
        k.put("transfo", geo.tour([(0.42, 0.04), (0.6, 0.12), (0.62, 0.12)], 14, "z", (1.62, y, 0.0)), True)
        k.box("structure", (1.62, y, 0.3), (0.12, 0.12, 0.2), petite=True)
    k.grille((1.62, Y(-0.35), z0 + 0.6), 0.36, 0.3)
    k.put("tuyau", geo.tour([(1.15, 0.09), (1.55, 0.09), (1.57, 0.12), (1.62, 0.12)], 14, "z", (1.75, Y(1.35), 0.0)))
    # bec de coulée et poche de laitier (sud)
    yb = yc - R
    k.put("structure", geo.prisme([(xc - 0.17, yb + 0.1), (xc + 0.17, yb + 0.1), (xc + 0.13, yb - 0.5), (xc - 0.13, yb - 0.5)],
                                  z0 + 0.5, z0 + 0.62))
    k.put("braise", geo.prisme([(xc - 0.1, yb), (xc + 0.1, yb), (xc + 0.08, yb - 0.48), (xc - 0.08, yb - 0.48)],
                               z0 + 0.62, z0 + 0.64))
    k.put("feu2", geo.prisme([(xc - 0.04, yb), (xc + 0.04, yb), (xc + 0.03, yb - 0.46), (xc - 0.03, yb - 0.46)],
                             z0 + 0.64, z0 + 0.65))
    for s in (-1, 1):
        k.box("brique", (xc + s * 0.15, yb - 0.22, z0 + 0.66), (0.04, 0.48, 0.08))
    AC.poche(k, xc, Y(-1.5), z0, 0.27, 0.36)
    k.halo(S, (xc, Y(-1.5), z0 + 0.6), (1.0, 0.45, 0.1), 6.0, 0.3)
    k.halo(S, (xc, yc - R - 0.15, zc + 0.12), (0.3, 0.6, 1.0), 9.0, 0.3)
    k.halo(S, (xc, yc, zt + 0.25), (0.3, 0.6, 1.0), 5.0, 0.3)
    # arrivée d'eau (raccord nord) vers le collecteur
    k.tuyau("tuyau", [(-0.5, Y(1.65), z0 + 0.03), (-0.5, Y(1.65), z0 + 0.62), (-0.5, yc + 0.8, z0 + 0.62)], 0.06, 0.12)
    k.vanne((-0.5, Y(1.45), z0 + 0.62), (0, 1, 0), 0.055, "chrome", "rouge")
    # pupitre (sud-ouest), centrale hydraulique (sud-est), passerelle
    k.armoire((-1.35, Y(-1.55), z0), (0.8, 0.32, 0.62), voyants=(("feu", 0.0), ("feu2", 0.08), ("feu", 0.16)))
    k.box("capot", (-1.35, Y(-1.55) + 0.25, z0 + 0.45), (0.7, 0.2, 0.05), rx=0.5)
    k.caisson("capot2", 1.05, 1.75, Y(-1.82), Y(-1.15), z0, z0 + 0.42, pas=0.1, rebord="structure")
    k.moteur((1.4, Y(-1.5), z0 + 0.62), "x", 0.12, 0.38)
    k.cuve_h("transfo", (1.4, Y(-1.25), z0 + 0.62), 0.12, 0.45, "x", 2, "structure", False)
    k.tuyau("tuyau", [(1.05, Y(-1.4), z0 + 0.3), (-0.2, Y(-1.4), z0 + 0.3), (-0.2, yc - R + 0.1, z0 + 0.3)], 0.03, 0.06,
            False)
    k.garde_corps([(-1.85, Y(0.6), z0), (-1.85, Y(-1.0), z0), (-0.9, Y(-1.0), z0)], 0.4)
    k.caillebotis(-1.85, -1.0, Y(-0.95), Y(0.6), z0 + 0.03)
