"""Essai A du four de frittage : FOUR TUBULAIRE ROTATIF. Virole de fonte rouillée inclinée d'ouest (alimentation,
haute) en est (brûleur, basse), sur 2 bandages et 4 galets ; couronne dentée et motoréducteur au sud ; hotte
d'alimentation de basalte et trémie à l'ouest, gaz vers un cyclone puis la sortie sud ; hotte de brûleur à l'est,
bouche rougeoyante ; arrivée nord vers la hotte d'alimentation."""
import math

import geo
from organes import Y
import fritt_commun as FC


def build(S, k):
    FC.raccords(k)
    z0 = k.socle(3, 0.4, 0.14, "socle", "capot")
    yk = Y(0.18)
    xa, za, xb, zb = -1.0, 1.02, 0.98, 0.8
    R = 0.34
    d = geo.norm((xb - xa, 0.0, zb - za))

    def P(t):
        return (xa + (xb - xa) * t, yk, za + (zb - za) * t)

    # virole, cerclages de tôle, bandages, couronne dentée
    k.put("capot2", geo.tube([P(0.0), P(1.0)], R, 36))
    for t in (0.08, 0.36, 0.62, 0.9):
        FC.anneau(k, "structure", P(t), d, R - 0.01, R + 0.018, 0.035)
    for t in (0.22, 0.78):
        FC.anneau(k, "chrome", P(t), d, R - 0.01, R + 0.06, 0.13)
        for s in (-1, 1):
            FC.anneau(k, "structure", geo.add(P(t), geo.mul(d, s * 0.08)), d, R - 0.01, R + 0.035, 0.025, petite=True)
    tg = 0.5
    FC.anneau(k, "structure", P(tg), d, R - 0.01, R + 0.1, 0.07)
    for i in range(28):                                          # dents de la couronne
        a = geo.TAU * i / 28
        n = (0.0, math.cos(a), math.sin(a))
        c = geo.add(P(tg), geo.mul(n, R + 0.115))
        if n[1] > 0.5:
            continue
        k.box("acier", c, (0.06, 0.03, 0.03), rx=a, petite=True)
    # galets (2 par bandage) sur chaises de fonte, boulonnées
    for t in (0.22, 0.78):
        c = P(t)
        for s in (-1, 1):
            rr = R + 0.06 + 0.07
            yy, zz = c[1] + s * rr * 0.62, c[2] - rr * 0.78
            k.put("chrome", geo.tour([(-0.07, 0.07), (0.07, 0.07)], 16, "x", (c[0], yy, zz), cap0=True, cap1=True))
            k.put("acier", geo.tour([(-0.12, 0.025), (0.12, 0.025)], 8, "x", (c[0], yy, zz), cap0=True, cap1=True),
                  True)
            for dx in (-0.12, 0.12):
                k.box("structure", (c[0] + dx, yy, zz - 0.03), (0.05, 0.1, 0.12), petite=True)
            k.caisson("structure", c[0] - 0.17, c[0] + 0.17, yy - 0.08, yy + 0.08, z0, zz - 0.08, pas=0.09,
                      rebord="acier")
            for dx in (-0.12, 0.12):
                k.boulon((c[0] + dx, yy - 0.09, z0 + 0.03), (0, 0, 1), 0.022)
    # motoréducteur et pignon au sud de la couronne
    xg = P(tg)[0]
    k.caisson("capot", xg - 0.2, xg + 0.2, yk - 0.75, yk - 0.42, z0, 0.62, pas=0.09, rebord="structure")
    k.put("acier", geo.tour([(-0.06, 0.08), (0.06, 0.08)], 14, "y", (xg, yk - 0.4, 0.52), cap0=True, cap1=True), True)
    k.moteur((xg + 0.42, yk - 0.6, 0.36), "x", 0.12, 0.34)
    k.box("structure", (xg + 0.42, yk - 0.6, 0.19), (0.5, 0.3, 0.05))
    k.cable((xg + 0.45, yk - 0.6, 0.52), (1.05, Y(-1.15), z0 + 0.55), 0.06, 0.018)
    # hotte d'alimentation (ouest) : caisson de basalte, trémie, garde-corps de visite
    k.caisson("capot", -1.42, -0.98, yk - 0.5, yk + 0.5, z0, 1.48, pas=0.11, rebord="structure")
    FC.anneau(k, "structure", P(0.0), d, R - 0.02, R + 0.08, 0.06)
    k.put("capot2", geo.tour([(1.48, 0.07), (1.62, 0.1), (1.82, 0.26), (1.9, 0.26)], 18, "z", (-1.2, yk + 0.12, 0.0)))
    FC.anneau(k, "structure", (-1.2, yk + 0.12, 1.86), (0, 0, 1), 0.24, 0.29, 0.05)
    for i in range(4):
        a = geo.TAU * i / 4 + 0.78
        k.box("structure", (-1.2 + 0.22 * math.cos(a), yk + 0.12 + 0.22 * math.sin(a), 1.6), (0.035, 0.035, 0.28),
              rz=a, petite=True)
    k.grille((-1.2, yk - 0.5, z0 + 0.45), 0.28, 0.3)
    FC.regard(k, (-1.2, yk - 0.5, 1.05), (0, -1, 0), 0.04, "feu2")
    k.echelle(-1.02, yk - 0.52, z0, 1.48, cage=False)
    # hotte de brûleur (est) : bouche rougeoyante, brûleur et ventilateur d'air
    k.caisson("capot", 0.98, 1.42, yk - 0.5, yk + 0.5, z0, 1.3, pas=0.11, rebord="structure")
    FC.anneau(k, "brique", P(1.0), d, R - 0.03, R + 0.05, 0.05)
    FC.anneau(k, "feu", geo.add(P(1.0), geo.mul(d, -0.03)), d, R + 0.0, R + 0.03, 0.02)
    k.put("braise", geo.oriente(geo.tour([(0.0, R - 0.03), (0.0, 0.0)], 24, "z"), geo.add(P(1.0), geo.mul(d, 0.01)), d))
    for zz in (0.62, 0.98):
        FC.regard(k, (1.2, yk - 0.5, zz), (0, -1, 0), 0.045)
    k.halo(S, (1.2, yk - 0.75, 0.8), (1.0, 0.3, 0.05), 7.0, 0.3)
    k.halo(S, (P(1.0)[0] - 0.1, yk - R - 0.2, P(1.0)[2]), (1.0, 0.35, 0.05), 4.0, 0.25)
    k.moteur((1.2, yk + 0.22, 1.5), "z", 0.13, 0.26)
    k.tuyau("tuyau", [(1.2, yk - 0.2, 1.3), (1.2, yk - 0.2, 1.48), (1.2, yk - 0.55, 1.48)], 0.05, 0.08, False)
    k.vanne((1.2, yk - 0.42, 1.48), (0, 1, 0), 0.045, "chrome", "rouge")
    # cyclone (sud-ouest) : gaz de la hotte d'alimentation, puis sortie sud
    xc, yc = -0.72, Y(-0.95)
    k.put("capot2", geo.tour([(0.42, 0.04), (0.62, 0.05), (0.98, 0.19), (1.3, 0.19), (1.34, 0.12), (1.36, 0.0)], 20, "z",
                             (xc, yc, 0.0)))
    FC.anneau(k, "structure", (xc, yc, 1.0), (0, 0, 1), 0.18, 0.215, 0.04)
    FC.anneau(k, "structure", (xc, yc, 1.28), (0, 0, 1), 0.18, 0.215, 0.04)
    for i in range(3):
        a = geo.TAU * i / 3 + 0.5
        k.box("structure", (xc + 0.2 * math.cos(a), yc + 0.2 * math.sin(a), (z0 + 1.0) / 2), (0.04, 0.04, 1.0 - z0),
              petite=True)
    k.box("structure", (xc, yc, 0.36), (0.12, 0.12, 0.1), petite=True)            # écluse rotative
    k.box("capot", (xc, yc, z0 + 0.09), (0.3, 0.26, 0.18))                        # bac à poussières
    k.tuyau("tuyau", [(-1.25, yk - 0.5, 1.15), (-1.25, yc + 0.05, 1.15), (xc - 0.2, yc + 0.05, 1.15)], 0.065, 0.12)
    k.tuyau("tuyau", [(xc, yc, 1.34), (xc, yc, 1.55), (0.0, yc, 1.55), (0.0, Y(-1.28), 1.55), (0.0, Y(-1.28), z0 + 0.03)],
            0.07, 0.14)
    k.vanne((0.0, Y(-1.28), 0.62), (0, 0, 1), 0.06, "chrome", "rouge")
    # arrivée nord vers la hotte d'alimentation
    k.tuyau("tuyau", [(0.0, Y(1.28), z0 + 0.03), (0.0, Y(1.28), 1.1), (-1.2, Y(1.28), 1.1), (-1.2, yk + 0.5, 1.1)],
            0.06, 0.12)
    k.vanne((-0.5, Y(1.28), 1.1), (1, 0, 0), 0.05, "chrome", "rouge")
    for x in (-0.95, -0.35):
        k.box("structure", (x, Y(1.28), (z0 + 1.04) / 2), (0.05, 0.05, 1.04 - z0), petite=True)
    # armoire et pupitre au sud-est
    k.armoire((0.95, Y(-1.18), z0), (0.6, 0.26, 0.55), voyants=(("feu", 0.0), ("feu2", 0.08)))
    k.garde_corps([(-0.45, Y(-0.62), z0), (0.35, Y(-0.62), z0)], 0.36)
