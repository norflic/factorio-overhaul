"""CONCASSEUR fo-crusher (2×2, âge 2, combustion) : BOCARD à pilons (variantes a, b) ou moulin à meules (c).
Pierre et laitier tombent d'une trémie dans un mortier ; des pilons levés par des cames les écrasent ; la poudre sort au sud.
Un foyer à charbon et sa petite machine entraînent l'arbre à cames par un volant (face à la caméra).
"""
import math

import communs as CO
import geo as G

Y = CO.Y
TAU = 2.0 * math.pi


def _foyer(k, x, ty, haut=0.62, chem=2.55, chaudiere=False):
    """Foyer en fonte : porte à grille rougeoyante au sud, cendrier, cheminée à pare-étincelles. Rend le y de la face sud."""
    y = Y(ty)
    py = Y(0.32)
    yf = y - py / 2.0
    if chaudiere:
        k.cuve("car2", x, y, 0.0, 1.35, 0.27, 0.25, 30)
        k.cerclages("acier", x, y, (0.15, 0.62, 1.05), 0.27, segs=30)
        yf = y - 0.27
        k.b("fonte", (x, yf - 0.02, 0.27), (0.3, 0.05, 0.3))
        k.b("feu", (x, yf - 0.047, 0.27), (0.2, 0.012, 0.15))
        for i in range(5):
            k.b("noir", (x - 0.08 + i * 0.04, yf - 0.052, 0.27), (0.014, 0.012, 0.17))
        k.b("braise", (x, yf - 0.047, 0.08), (0.18, 0.012, 0.035))
        k.cyl("cuivre", x + 0.12, yf + 0.02, 0.85, 0.93, 0.05, 12)          # manomètre
        k.voyant("voyant_o", x + 0.12, yf - 0.01, 0.89, 0.03)
        _cheminee(k, x, y, 1.3, chem, (x, y, 1.33))
        return yf
    k.caisson("fonte", x, y, 0.0, 0.5, py, haut, 0.04)
    k.rev("fonte", x, y + 0.05, [(haut - 0.02, 0.2), (haut + 0.08, 0.17), (haut + 0.14, 0.09)], 20)
    k.b("acier", (x, yf - 0.012, 0.3), (0.32, 0.024, 0.26))                     # cadre de porte
    k.b("feu", (x, yf - 0.026, 0.3), (0.24, 0.012, 0.18))                       # grille
    for i in range(6):
        k.b("noir", (x - 0.1 + i * 0.04, yf - 0.032, 0.3), (0.013, 0.012, 0.2))
    k.b("braise", (x, yf - 0.026, 0.08), (0.22, 0.012, 0.04))                   # cendrier
    k.b("acier_clair", (x + 0.17, yf - 0.035, 0.32), (0.03, 0.02, 0.05))
    k.rivets_ligne("riv", (x - 0.22, yf - 0.006, haut - 0.05), (x + 0.22, yf - 0.006, haut - 0.05), 6)
    _cheminee(k, x, y, haut, chem, (x + 0.05, y + 0.05, haut - 0.05))
    return yf


def _cheminee(k, x, y, zc, chem, depart):
    """Cheminée à pare-étincelles posée DERRIÈRE le volant (au nord-est), reliée au foyer par un carneau."""
    cx, cy = x + 0.14, Y(0.62)
    k.tuyau("suie", [depart, (depart[0], depart[1], zc + 0.12), (cx, Y(0.45), zc + 0.12), (cx, cy, zc + 0.12)], r=0.06, coude=0.1, brides=[])
    k.cyl("suie", cx, cy, 0.0, chem, 0.07, 16)
    k.cerclages("acier", cx, cy, (0.5, 1.1, chem - 0.3), 0.07, segs=16)
    k.rev("suie", cx, cy, [(chem, 0.07), (chem + 0.04, 0.13), (chem + 0.16, 0.13), (chem + 0.2, 0.06)], 16)


def _bocard(k, n, xs, ty_tige, h_cadre, phase):
    """Batterie de n pilons : mortier, portique, guides, arbre à cames, tiges, sabots. xs : abscisses des tiges."""
    y = Y(ty_tige)
    x0, x1 = min(xs) - 0.3, max(xs) + 0.3
    xm, lx = (x0 + x1) / 2.0, x1 - x0
    # fondation et mortier
    k.caisson("beton", xm, y + 0.05, 0.0, lx + 0.12, Y(0.78), 0.16, 0.03)
    k.caisson("fonte", xm, y + 0.02, 0.16, lx, Y(0.56), 0.42, 0.04)
    yf = y + 0.02 - Y(0.56) / 2.0
    k.rivets_ligne("riv", (x0 + 0.04, yf - 0.006, 0.54), (x1 - 0.04, yf - 0.006, 0.54), int(lx / 0.12))
    # grille de décharge et tablier vers le tas de sable
    k.b("noir", (xm, yf - 0.006, 0.42), (lx - 0.2, 0.012, 0.16))
    for i in range(int((lx - 0.2) / 0.05)):
        k.b("acier", (x0 + 0.12 + i * 0.05, yf - 0.014, 0.42), (0.012, 0.012, 0.16))
    k.b("acier", (xm, yf - 0.16, 0.24), (0.32, 0.34, 0.025), rx=math.radians(34))
    for sx in (-1, 1):
        k.b("acier", (xm + sx * 0.16, yf - 0.16, 0.28), (0.025, 0.34, 0.08), rx=math.radians(34))
    k.tas("sable", xm, yf - 0.48, lx * 0.42, 0.34, 0.15)
    # portique (bois cerclé de fer) : poteaux, contre-fiches, chapeau
    for x in (x0 - 0.06, x1 + 0.06):
        k.bz("bois", x, y, 0.16, 0.13, 0.15, h_cadre - 0.16)
        k.axe("bois", (x, y + 0.65, 0.16), (x, y + 0.06, h_cadre * 0.62), 0.045, 6)
        for z in (0.6, h_cadre * 0.5, h_cadre - 0.2):
            k.b("acier", (x, y - 0.078, z), (0.15, 0.012, 0.04))
    k.bz("bois", xm, y, h_cadre, lx + 0.32, 0.17, 0.13)
    for z in (1.0, h_cadre - 0.3):                                              # traverses-guides
        k.bz("bois", xm, y, z, lx + 0.2, 0.2, 0.1)
        for x in xs:
            k.bz("acier", x, y, z - 0.01, 0.13, 0.22, 0.12)
    # arbre à cames, derrière les tiges
    za = 1.42
    ya = y + 0.27
    k.axe("acier_clair", (x0 - 0.15, ya, za), (x1 + 0.35, ya, za), 0.05, 14)
    for x in (x0 - 0.06, x1 + 0.06):
        k.bz("fonte", x, ya, za - 0.12, 0.16, 0.16, 0.2)
    k.mobile(True)
    lifts = []
    for i, x in enumerate(xs):
        t = (phase + i / float(n)) % 1.0
        lift = 0.2 * (t / 0.7) if t < 0.7 else 0.2 * (1.0 - (t - 0.7) / 0.3) ** 3
        lifts.append(lift)
        a = TAU * t
        k.b("acier", (x, ya - 0.06 * math.cos(a), za + 0.06 * math.sin(a)), (0.05, 0.16, 0.05), rx=a)   # came
        z0 = 0.58 + lift
        k.rev("fonte", x, y, [(z0, 0.1), (z0 + 0.03, 0.115), (z0 + 0.2, 0.115), (z0 + 0.24, 0.07)], 18)  # sabot
        k.cyl("acier_clair", x, y, z0 + 0.22, z0 + h_cadre + 0.28, 0.035, 12)                         # tige
        k.cyl("fonte", x, y, za - 0.06 + lift, za + 0.04 + lift, 0.07, 14)                           # taquet
        k.cyl("acier", x, y, z0 + h_cadre + 0.26, z0 + h_cadre + 0.32, 0.05, 12)
    k.mobile(False)
    return ya, za, x1


def concasseur(S, k, v):
    M = k.M = CO.matieres(S)
    k.sol("noir", 2)
    if v in ("a", "b"):
        n = 3 if v == "a" else 4
        xs = [-0.66 + i * 0.36 for i in range(n)] if v == "a" else [-0.78 + i * 0.3 for i in range(n)]
        hc = 2.0 if v == "a" else 2.25
        # trémie de pierres derrière la batterie
        xm = sum(xs) / n
        k.tremie("bois", xm, Y(0.72), 0.8, 1.62, 0.5 * n * 0.36, Y(0.2), n * 0.42, Y(0.46))
        k.roches("pierre", xm - n * 0.18, xm + n * 0.18, Y(0.53), Y(0.92), 1.55, 30, 0.05, 0.09, mats=("pierre", "pierre2", "laitier"))
        for sx in (-1, 1):
            k.bz("bois", xm + sx * n * 0.17, Y(0.72), 0.0, 0.1, 0.1, 0.85)
        k.axe("fonte", (xm, Y(0.6), 0.85), (xm, Y(0.25), 0.62), 0.09, 10)
        ya, za, x1 = _bocard(k, n, xs, 0.0, hc, k.phase)
        # foyer et machine à l'est ; volant face à la caméra, renvoi d'angle vers l'arbre à cames
        xf = 0.74
        _foyer(k, xf, -0.62, chaudiere=(v == "b"), chem=2.6 if v == "a" else 2.85)
        zv, R = za - 0.12, 0.42
        yv = Y(-0.12)
        k.bz("fonte", xf, yv + 0.18, 0.0, 0.14, 0.2, zv)                          # palier du volant
        k.axe("acier_clair", (xf, yv - 0.08, zv), (xf, ya + 0.06, zv), 0.045, 12)
        k.caisson("fonte", xf, ya, za - 0.3, 0.26, 0.26, 0.42, 0.04)              # renvoi d'angle
        k.axe("acier_clair", (xf, ya, zv), (xf, ya, za), 0.04, 10)
        k.axe("acier_clair", (x1 + 0.3, ya, za), (xf - 0.1, ya, za), 0.05, 12)
        k.volant((xf, yv, zv), R, "y", larg=0.08, rayons=6, jante="fonte", ph=k.phase)
        # bielle de la machine : du maneton au cylindre posé sur le foyer
        a = TAU * k.phase
        pm = (xf + R * 0.55 * math.cos(a), yv - 0.07, zv + R * 0.55 * math.sin(a))
        zc = 0.9 if v == "a" else 1.15
        k.cyl("car2", xf - 0.02, Y(-0.38), 0.62 if v == "a" else 0.9, zc, 0.085, 16)
        k.cerclages("acier", xf - 0.02, Y(-0.38), (zc - 0.05,), 0.085, segs=16)
        k.mobile(True)
        k.axe("acier_clair", (xf - 0.02, Y(-0.38), zc), pm, 0.022, 8)
        k.mobile(False)
        # tas de charbon et pelle
        k.tas("charbon", 0.25, Y(-0.95), 0.2, 0.16, 0.08)
        if v == "b":
            for i in range(3):
                k.chevrons(xs[0] - 0.24 + i * 0.36, Y(0.02) - Y(0.56) / 2.0 - 0.008, 0.25, 0.3, 0.06)
            k.tuyau("cuivre", [(xf, Y(-0.6) + 0.1, 1.2), (xf - 0.02, Y(-0.38), zc + 0.1)], r=0.025, coude=0.08)
    else:
        _moulin(k)


def _moulin(k):
    """Variante c : moulin à meules verticales (broyeur à meules) : cuve ronde, deux meules de pierre sur un essieu qui tourne
    autour d'un arbre vertical ; couronne d'engrenage en haut ; foyer et volant à l'est."""
    cx, cy = -0.28, Y(0.05)
    R = 0.66
    k.rev("beton", cx, cy, [(0.0, R + 0.1), (0.14, R + 0.08), (0.14, 0.0)], 40)
    k.rev("fonte", cx, cy, [(0.14, R), (0.48, R), (0.48, R - 0.06), (0.22, R - 0.06)], 40, cap=False)   # cuve
    k.cerclages("acier", cx, cy, (0.24, 0.42), R, e=0.02, segs=40)
    k.rev("sable", cx, cy, [(0.2, R - 0.06), (0.26, R - 0.1), (0.3, 0.2), (0.3, 0.0)], 40)
    k.roches("pierre", cx - 0.4, cx + 0.4, cy - 0.35, cy + 0.45, 0.31, 18, 0.03, 0.06, mats=("pierre", "laitier", "pierre2"))
    # arbre vertical, couronne, essieu et deux meules
    k.cyl("acier_clair", cx, cy, 0.25, 1.72, 0.05, 14)
    a0 = TAU * k.phase * 0.25 + 0.35
    k.mobile(True)
    for sg in (-1, 1):
        a = a0 + (0 if sg > 0 else math.pi)
        dx, dy = math.cos(a), math.sin(a)
        c = (cx + dx * 0.36, cy + dy * 0.36, 0.3 + 0.3)
        prof = [(-0.1, 0.0), (-0.1, 0.27), (-0.08, 0.3), (0.08, 0.3), (0.1, 0.27), (0.1, 0.0)]
        mesh = G.tour(prof, 30, "x", (0.0, 0.0, 0.0))
        vv, ff, uu = mesh
        rot = [(c[0] + p[0] * dx - p[1] * dy, c[1] + p[0] * dy + p[1] * dx, c[2] + p[2]) for p in vv]
        k.put("pierre", (rot, ff, uu))
        k.axe("acier", (cx, cy, 0.6), c, 0.04, 10)
        k.put("acier", G.oriente(G.tour([(-0.12, 0.08), (0.12, 0.08)], 14, "z"), c, (dx, dy, 0.0)))
    k.mobile(False)
    # portique en fonte : deux montants et chapeau qui portent la couronne
    for sg in (-1, 1):
        k.bz("fonte", cx + sg * (R + 0.02), cy + 0.25, 0.14, 0.12, 0.14, 1.55)
    k.bz("fonte", cx, cy + 0.25, 1.62, 2 * R + 0.24, 0.16, 0.14)
    k.put("acier", G.tour([(1.75, 0.0), (1.75, 0.3), (1.82, 0.3), (1.82, 0.0)], 32, "z", (cx, cy, 0.0)))
    k.boulons_rond("riv", cx, cy, 1.83, 0.24, 16, 0.014)
    k.axe("acier_clair", (cx, cy, 1.88), (0.74, cy, 1.88), 0.045, 12)
    # trémie qui verse dans la cuve
    k.tremie("fonte", cx - 0.35, Y(0.55), 0.7, 1.3, 0.24, 0.24, 0.62, Y(0.36))
    k.roches("pierre", cx - 0.6, cx - 0.1, Y(0.43), Y(0.68), 1.24, 12, 0.05, 0.08, mats=("pierre", "laitier"))
    k.axe("fonte", (cx - 0.35, Y(0.45), 0.72), (cx - 0.2, Y(0.25), 0.5), 0.07, 10)
    # goulotte de sortie au sud et tas de sable
    k.b("acier", (cx + 0.1, cy - R - 0.12, 0.3), (0.22, 0.3, 0.025), rx=math.radians(30))
    k.tas("sable", cx + 0.15, cy - R - 0.42, 0.34, 0.22, 0.13)
    # foyer, machine, volant
    xf = 0.74
    _foyer(k, xf, -0.55, chem=2.5)
    k.bz("fonte", xf, Y(0.1), 0.0, 0.16, 0.18, 1.88)
    k.volant((xf, Y(-0.12), 1.2), 0.3, "y", larg=0.08, jante="fonte", ph=k.phase)
    k.axe("acier_clair", (xf, Y(-0.12) - 0.06, 1.2), (xf, Y(0.1), 1.2), 0.04, 10)
    k.axe("acier", (xf, Y(0.1), 1.2), (xf, Y(0.1), 1.88), 0.035, 10)
    k.tas("charbon", 0.3, Y(-0.95), 0.18, 0.14, 0.07)
