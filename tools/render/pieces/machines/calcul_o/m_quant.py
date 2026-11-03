"""QUANTIQUE (lot CALCUL-DESIGN, 01/11), âge 13, céramique et cuivre : réfrigérateur à dilution (3×3, le « chandelier » doré à
étages dans sa cage ouverte, cloche relevée) et labo quantique (5×5, sphère de confinement sur trépied, tore magenta).
"""
import math

import geo as G
import organes as O
import palettes as P

D = O.D


def lustre(k, x, y, z_haut, echelle=1.0, etages=5):
    """Le chandelier : disques dorés décroissants, tiges, serpentins de câbles coaxiaux entre les étages."""
    z = z_haut
    Rs = [0.66, 0.56, 0.46, 0.36, 0.26, 0.17][:etages]
    pas = 0.5 * echelle
    for i, R in enumerate(Rs):
        R *= echelle
        k.rev("or", x, y, [(z - 0.035, R), (z + 0.025, R), (z + 0.03, R - 0.02)], 36)
        k.tore("acier_clair", x, y, z + 0.0, R + 0.005, 0.009, 36, 4)
        k.boulons_rond("cuivre", x, y, z + 0.03, R * 0.82, 10, 0.016)
        if i < len(Rs) - 1:
            Rn = Rs[i + 1] * echelle
            for j in range(6):                # tiges
                a = math.tau * (j + 0.5) / 6
                k.axe("or", (x + R * 0.78 * math.cos(a), y + R * 0.78 * math.sin(a), z - 0.03), (x + Rn * 0.78 * math.cos(a), y + Rn * 0.78 * math.sin(a), z - pas + 0.03), 0.012, 6)
            for j in range(9):                # câbles coaxiaux : fins, courbes
                a = math.tau * j / 9
                b = a + 0.35
                ctrl = [(x + R * 0.6 * math.cos(a), y + R * 0.6 * math.sin(a), z - 0.03),
                        (x + (R * 0.9) * math.cos(a + 0.18), y + (R * 0.9) * math.sin(a + 0.18), z - pas * 0.55),
                        (x + Rn * 0.55 * math.cos(b), y + Rn * 0.55 * math.sin(b), z - pas + 0.03)]
                k.put("cuivre", G.tube(G.catmull(ctrl, 4), 0.006, 4))
        z -= pas
    # la pointe : petit porte-puce en bout du lustre
    k.rev("cuivre", x, y, [(z + pas - 0.3, 0.05), (z + pas - 0.08, 0.05), (z + pas - 0.03, 0.09)], 14)
    k.bz("qubit", x, y, z + pas - 0.34, 0.1, 0.1, 0.012)


def dilution(S, k):
    """RÉFRIGÉRATEUR À DILUTION : cage ouverte à trois montants, plaque du haut en céramique, chandelier d'or suspendu, cloche
    d'écran relevée à côté sur son chariot, pompes de mélange en céramique au nord, lignes de cuivre."""
    M = k.M = P.matieres(S, "fusion")
    M["qubit"] = P.lueur(S, "c_qubit", (1.0, 0.25, 0.85), 3.8, 0.55, part=0.4, echelle=40.0)
    k.sol("car2", 3, h=0.06, ch=0.18)
    cx, cy = -0.12, -0.38
    k.rev("noir", cx, cy, [(0.0, 0.98), (0.16, 0.94), (0.16, 0.86), (0.24, 0.82), (0.24, 0.5)], 40)
    # trépied et plaque du haut
    Z = 3.45
    for a in (90, 210, 330):
        r_ = math.radians(a)
        px, py = cx + 0.92 * math.cos(r_), cy + 0.92 * math.sin(r_)
        k.axe("car", (px, py, 0.14), (px * 0.86 + cx * 0.14, py * 0.86 + cy * 0.14, Z), 0.06, 12)
        k.rev("plaque", px, py, [(0.06, 0.1), (0.14, 0.09), (0.2, 0.07)], 12)
    k.rev("car_lisse", cx, cy, [(Z - 0.02, 0.88), (Z + 0.1, 0.88), (Z + 0.14, 0.76), (Z + 0.28, 0.52), (Z + 0.4, 0.36), (Z + 0.4, 0.14)], 40)
    k.tore("plaque", cx, cy, Z + 0.04, 0.89, 0.024, 40, 6)
    k.boulons_rond("plaque", cx, cy, Z + 0.15, 0.68, 14, 0.018)
    lustre(k, cx, cy, Z - 0.18)
    # sortie de tête, antennes de câbles, voyant
    k.cyl("plaque", cx, cy, Z + 0.4, Z + 0.62, 0.1, 14)
    for i in range(5):
        a = math.tau * i / 5
        k.cable("cuivre", (cx + 0.25 * math.cos(a), cy + 0.25 * math.sin(a), Z + 0.34), (0.4 + i * 0.16, 1.3, 1.5), 0.15, 0.011, 6)
    k.voyant_h("voyant", cx, cy, Z + 0.62, 0.035)
    # cloche d'écran, relevée à droite, posée sur son chariot : cylindre de céramique, on la voit vide
    bx, by = 1.1, -1.05
    k.bz("plaque", bx, by, 0.06, 0.62, 0.8, 0.1)
    k.cuve("car_lisse", bx, by, 0.16, 1.62, 0.27, 0.6, 28)
    k.cerclages("plaque", bx, by, (0.3, 0.9, 1.3), 0.27)
    # pompes et bouteilles de mélange au nord
    for x, y, r_ in ((-1.05, 1.32, 0.32), (-0.42, 1.62, 0.26)):
        k.cuve("car", x, y, 0.06, 1.28, r_, 0.5, 26)
        k.cerclages("plaque", x, y, (0.4, 0.86), r_)
    k.echangeur(0.72, 1.55, 0.08, 0.92, 0.28, "car2", "plaque", cerc=2)
    k.moteur("noir", 0.75, 0.82, 0.12, 0.72, 0.17, ailette="plaque")
    k.tuyau("cuivre", [(-1.05, 1.0, 1.0), (-1.05, 0.5, 1.0), (cx - 0.3, 0.3, 3.2), (cx - 0.3, cy + 0.2, Z + 0.3)], r=0.028, coude=0.22, brides=[(-1.05, 0.7, 1.0)], bride_mat="plaque")
    k.tuyau("cuivre", [(-0.42, 1.36, 0.95), (-0.42, 0.45, 0.95), (cx + 0.1, 0.3, 2.9), (cx + 0.1, cy + 0.25, Z + 0.3)], r=0.022, coude=0.22, brides=[])
    k.tuyau("cuivre", [(-1.0, 2.05, 0.12), (-1.0, 1.65, 0.12)], r=0.05, bride_mat="plaque")
    k.tuyau("cuivre", [(1.0, 2.05, 0.12), (1.0, 1.65, 0.12)], r=0.05, bride_mat="plaque")
    k.tuyau("cuivre", [(0.0, -2.05, 0.12), (0.0, -1.45, 0.14), (cx, cy - 0.45, 0.2)], r=0.05, coude=0.15, bride_mat="plaque")
    k.armoire("car", -1.05, -1.95, 0.06, 0.6, 0.58, 0.28, lampe="qubit")


def qlab(S, k):
    """LABO QUANTIQUE : grande sphère de céramique ouverte d'un hublot où l'on voit le chandelier, ceinte d'un tore de plasma
    magenta (cœur orangé) sur trépied ; injecteurs de cuivre, deux réfrigérateurs satellites, baies de contrôle."""
    M = k.M = P.matieres(S, "fusion")
    M["qubit"] = P.lueur(S, "c_qubit", (1.0, 0.25, 0.85), 3.8, 0.55, part=0.4, echelle=40.0)
    M["plasma"] = P.lueur(S, "c_plasma", (1.0, 0.1, 0.62), 2.0, 0.42, part=0.85, echelle=6.0)
    M["coeur"] = P.lueur(S, "c_coeur", (1.0, 0.38, 0.1), 2.4, 0.42, part=0.7, echelle=10.0)
    k.sol("car2", 5, h=0.07, ch=0.34)
    cx, cy = -0.1, -0.2
    ZC = 2.15
    R = 1.28
    # socle et trépied ouvert : grand vide sous la sphère
    k.rev("noir", cx, cy, [(0.0, 1.5), (0.18, 1.42), (0.18, 1.2), (0.3, 1.1), (0.3, 0.6)], 48)
    k.rev("cuivre", cx, cy, [(0.3, 0.5), (0.42, 0.48), (0.42, 0.3), (ZC - R + 0.1, 0.14)], 26)
    for a in (90, 210, 330):
        r_ = math.radians(a)
        p0 = (cx + 1.66 * math.cos(r_), cy + 1.66 * math.sin(r_), 0.25)
        p1 = (cx + 0.92 * math.cos(r_), cy + 0.92 * math.sin(r_), ZC - 0.75)
        k.axe("car", p0, p1, 0.1, 14)
        k.rev("plaque", p0[0], p0[1], [(0.2, 0.17), (0.3, 0.15), (0.42, 0.12)], 16)
        k.axe("cuivre", (p0[0], p0[1], p0[2] + 0.2), (p1[0], p1[1], p1[2] - 0.12), 0.115, 8) if False else None
    # sphère : tôles méridiennes, ceinture épaisse
    k.sph("car_lisse", (cx, cy, ZC), R, 56, 28)
    for i in range(16):
        a = i * math.tau / 16
        pts = [(cx + (R + 0.006) * math.cos(t) * math.cos(a), cy + (R + 0.006) * math.cos(t) * math.sin(a), ZC + (R + 0.006) * math.sin(t)) for t in [(-1.2 + j * 2.4 / 20) for j in range(21)]]
        k.put("plaque", G.tube(pts, 0.007, 4))
    k.rev("plaque", cx, cy, [(ZC - 0.09, R + 0.01), (ZC - 0.06, R + 0.07), (ZC + 0.06, R + 0.07), (ZC + 0.09, R + 0.01)], 56, cap=False)
    # hublot au sud : large ouverture, chandelier d'or à l'intérieur (visible, sombre autour)
    hx, hy = cx + 0.12, cy - R * 0.72
    hz = ZC + 0.62
    n = (0.1, -0.76, 0.64)
    k.put("noyau", G.oriente(G.tour([(0.0, 0.62), (0.03, 0.0)], 32, "z"), (hx, hy - 0.02, hz - 0.08), n))
    k.put("plaque", G.oriente(G.tour([(-0.02, 0.62), (0.06, 0.68), (0.06, 0.74), (-0.02, 0.74)], 36, "z"), (hx, hy - 0.02, hz - 0.08), n))
    for i in range(12):
        a = math.tau * i / 12
        e1 = G.norm(G.cross((1.0, 0.0, 0.0), n))
        e2 = G.cross(n, e1)
        p = G.add((hx, hy - 0.02, hz - 0.08), G.add(G.mul(e1, 0.7 * math.cos(a)), G.mul(e2, 0.7 * math.sin(a))))
        k.rivets("riv", [G.add(p, G.mul(n, 0.06))], n, 0.016)
    lustre(k, hx - 0.03, hy - 0.04, hz + 0.28, 0.72, 4)
    # tore de plasma magenta tournant : anneau-écrin de cuivre, tube, cœur
    Rt = R + 0.55
    k.tore("car2", cx, cy, ZC - 0.12, Rt, 0.2, 80, 14)
    k.tore("plasma", cx, cy, ZC + 0.02, Rt, 0.13, 80, 12)
    k.tore("coeur", cx, cy, ZC + 0.12, Rt, 0.03, 80, 8)
    for i in range(12):
        a = math.tau * i / 12
        k.put("cuivre", G.tour([(-0.04, 0.22), (-0.04, 0.24), (0.04, 0.24), (0.04, 0.22)], 14, "x", (0.0, 0.0, 0.0))) if False else None
        px, py = cx + Rt * math.cos(a), cy + Rt * math.sin(a)
        k.b("cuivre", (px, py, ZC - 0.02), (0.1, 0.5, 0.42), rz=a)
    # bras de liaison du tore
    for a in (30, 150, 270):
        r_ = math.radians(a)
        k.axe("car", (cx + (R + 0.02) * math.cos(r_), cy + (R + 0.02) * math.sin(r_), ZC), (cx + (Rt - 0.15) * math.cos(r_), cy + (Rt - 0.15) * math.sin(r_), ZC - 0.1), 0.09, 12)
    # sommet : couronne d'injecteurs, flèche
    k.rev("cuivre", cx, cy, [(ZC + R - 0.04, 0.32), (ZC + R + 0.16, 0.22), (ZC + R + 0.5, 0.08), (ZC + R + 1.0, 0.018)], 22)
    for i in range(6):
        a = math.tau * i / 6
        k.axe("car", (cx + 0.35 * math.cos(a), cy + 0.35 * math.sin(a), ZC + R - 0.06), (cx + 0.55 * math.cos(a), cy + 0.55 * math.sin(a), ZC + R + 0.22), 0.04, 8)
    k.sph("qubit", (cx, cy, ZC + R + 1.02), 0.035, 10, 6)
    # au nord : réfrigérateurs satellites (cuves céramique), baies noires à l'est, conduites cuivre
    for x, y, r_, h in ((-1.92, 2.5, 0.42, 2.0), (1.92, 2.65, 0.36, 1.7)):
        k.cuve("car", x, y, 0.07, h, r_, 0.5, 26)
        k.cerclages("plaque", x, y, (0.5, h * 0.6), r_)
        k.tuyau("cuivre", [(x, y - r_, h * 0.5), (x, y - r_ - 0.2, h * 0.5), (cx + (0.8 if x > 0 else -0.8), cy + 0.72, ZC + 0.72)], r=0.05, coude=0.3, bride_mat="plaque", brides=[(x, y - r_ - 0.1, h * 0.5)])
    k.caisson("noir", 1.98, -2.8, 0.07, 0.86, 1.05, 1.32, 0.03)
    k.b("noyau", (1.98, -3.33, 0.72), (0.74, 0.01, 1.18))
    for i in range(8):
        z = 0.22 + i * 0.145
        k.b("plaque", (1.98, -3.34, z), (0.66, 0.008, 0.1))
        k.b("qubit", (1.74 + (i * 3 % 4) * 0.12, -3.346, z), (0.1, 0.006, 0.016))
    k.armoire("car2", -1.9, -3.3, 0.07, 0.86, 0.72, 0.42, lampe="qubit")
    k.chevrons(0.0, -3.42, 0.14, 1.9, 0.08)
    k.tuyau("cuivre", [(-1.3, -3.3, 0.22), (-1.3, -2.45, 0.22), (cx - 1.1, cy - 1.0, 0.3)], r=0.06, coude=0.2, bride_mat="plaque", brides=[(-1.3, -2.8, 0.22)])
