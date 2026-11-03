"""AMPLIFICATEUR DE RÉSONANCE (fo-resonance-amplifier, 3×3, balise à 3 modules, portée 3) : un grand cristal de
résonance mis en vibration par des oscillateurs (bobines de cuivre du socle) ; des lentilles focalisent le champ vers les
machines voisines. 3 logements de modules en façade sud. Variantes : a diapason + cristal + anneau orbital à 3 lentilles,
b grappe de 3 cristaux dans une sphère armillaire à 2 anneaux, c obélisque à disques de résonance, cristal au sommet.
"""
import math

import elements as E
import geo as G

D = E.D
TAU = E.TAU
HX, HY = 1.5, 1.5 * D


def _socle(k, h=0.24):
    """Socle octogonal, 3 logements de modules en façade sud (voyant de fente), 4 bornes à lentille aux coins."""
    a, b = 1.32, 1.32 * D * 0.92
    c = 0.42
    pts = [(-a + c, -b), (a - c, -b), (a, -b + c * D), (a, b - c * D), (a - c, b), (-a + c, b), (-a, b - c * D), (-a, -b + c * D)]
    k.put("car", G.prisme(pts, 0.0, h - 0.05))
    k.put("car2", G.prisme(pts, h - 0.05, h, 0.97))
    for i, x in enumerate((-0.55, 0.0, 0.55)):
        k.b("noir", (x, -b - 0.01, 0.12), (0.34, 0.03, 0.14))
        k.b("car2", (x, -b - 0.03, 0.12), (0.28, 0.02, 0.1))
        k.b("cristal_p", (x, -b - 0.045, 0.1), (0.2, 0.01, 0.018))
        k.voyant("voyant_v", x + 0.13, -b - 0.04, 0.17, 0.012)
    k.chevrons(0.0, -b - 0.012, 0.215, 1.6, 0.03)
    # bornes de focalisation aux 4 coins, lentille tournée vers l'extérieur
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * 1.12, sy * 1.12 * D * 0.86
            k.cyl("car2", x, y, h, h + 0.32, 0.07, 12)
            n = G.norm((sx, sy * 0.7, 0.0))
            p = (x + n[0] * 0.06, y + n[1] * 0.06, h + 0.38)
            k.put("acier", G.oriente(G.tour([(-0.04, 0.085), (0.04, 0.085)], 16, "z", cap0=True, cap1=True), p, n))
            k.put("cristal_p", G.oriente(G.tour([(0.0, 0.065), (0.02, 0.05), (0.03, 0.0)], 14, "z", cap0=True), G.add(p, G.mul(n, 0.04)), n))


def _bobines(k, r0=0.62, z0=0.26, n=5):
    """Bobines de cuivre du socle : tores empilés, colliers, bornes."""
    for i in range(n):
        k.tore("cuivre", 0.0, 0.0, z0 + 0.035 + i * 0.055, r0, 0.03, 48, 8)
    for i in range(6):
        a = TAU * (i + 0.5) / 6
        k.bz("noir", r0 * math.cos(a), r0 * math.sin(a), z0, 0.1, 0.1, n * 0.055 + 0.04, rz=a)


def v_a(S, k):
    M = E.matieres(S, k, "hitech")
    E.lueurs(S, M)
    _socle(k)
    _bobines(k)
    k.cyl("car2", 0.0, 0.0, 0.24, 0.85, 0.24, 24)
    k.cerclages("acier", 0.0, 0.0, (0.6, 0.8), 0.24, 0.02, 0.02, 24)
    # diapason : culasse et deux branches
    k.caisson("acier_clair", 0.0, 0.0, 0.85, 1.05, 0.22, 0.16, 0.03)
    for sg in (-1, 1):
        k.caisson("acier_clair", sg * 0.44, 0.0, 1.0, 0.13, 0.18, 1.32, 0.02)
        k.b("acier", (sg * 0.44, -0.095, 1.68), (0.14, 0.012, 0.6))
        k.axe("acier", (sg * 0.38, 0.0, 1.55), (sg * 0.24, 0.0, 1.55), 0.035, 10)      # mâchoires
        k.axe("acier", (sg * 0.38, 0.0, 1.95), (sg * 0.2, 0.0, 1.95), 0.03, 10)
        k.voyant_h("voyant", sg * 0.44, 0.0, 2.32, 0.02)
    E.bipyramide(k, "cristal", 0.0, 0.0, 1.05, 2.42, 0.25, 6, 0.26)
    # anneau orbital (pièce mobile) : moyeu, 3 bras, anneau, 3 lentilles tournées vers l'extérieur
    k.mobile(True)
    a0 = TAU * k.phase / 3.0
    k.cyl("acier", 0.0, 0.0, 0.85, 0.95, 0.3, 24)
    R, zr = 0.78, 1.5
    k.tore("acier_clair", 0.0, 0.0, zr, R, 0.032, 56, 8)
    for i in range(3):
        a = a0 + TAU * i / 3
        c, s = math.cos(a), math.sin(a)
        k.axe("acier", (0.27 * c, 0.27 * s, 0.93), (R * c, R * s, zr), 0.02, 6)
        p = (R * c, R * s, zr)
        n = (c, s, 0.0)
        k.put("car2", G.oriente(G.tour([(-0.06, 0.12), (0.06, 0.12)], 20, "z", cap0=True, cap1=True), p, n))
        k.put("cristal", G.oriente(G.tour([(0.0, 0.1), (0.03, 0.08), (0.045, 0.0)], 16, "z", cap0=True), G.add(p, G.mul(n, 0.06)), n))
    k.mobile(False)


def _anneau_v(k, mat, R, r, ax, tilt, z):
    """Anneau dans un plan vertical tourné de ax autour de Z, incliné de tilt."""
    pts = []
    for i in range(49):
        t = TAU * i / 48
        p = (R * math.cos(t), 0.0, R * math.sin(t))
        p = G.rot_x(p, tilt)
        p = G.rot_z(p, ax)
        pts.append((p[0], p[1], p[2] + z))
    k.put(mat, G.tube(pts, r, 8, False, False))


def v_b(S, k):
    M = E.matieres(S, k, "hitech")
    E.lueurs(S, M)
    _socle(k)
    _bobines(k, 0.7)
    # berceau tripode et grappe de 3 cristaux
    for i in range(3):
        a = TAU * i / 3 + 0.5
        k.axe("acier_clair", (0.55 * math.cos(a), 0.55 * math.sin(a), 0.24), (0.18 * math.cos(a), 0.18 * math.sin(a), 0.95), 0.04, 8)
    k.cyl("car2", 0.0, 0.0, 0.88, 1.0, 0.26, 24)
    E.bipyramide(k, "cristal", 0.0, 0.0, 0.95, 2.2, 0.21, 6, 0.24)
    E.bipyramide(k, "cristal", -0.16, 0.05, 0.95, 1.75, 0.14, 6, 0.28, ry=-0.35)
    E.bipyramide(k, "cristal", 0.16, -0.04, 0.95, 1.68, 0.13, 6, 0.28, ry=0.38, rx=0.15)
    # sphère armillaire : 2 anneaux qui tournent (mobiles), axe fixe et étrier
    zc = 1.55
    k.axe("acier", (0.0, 0.0, 0.98), (0.0, 0.0, 0.88), 0.05, 10)
    for sg in (-1, 1):
        k.axe("acier_clair", (sg * 0.9, 0.0, 0.24), (sg * 0.9, 0.0, zc), 0.035, 8)
        k.cyl("acier", sg * 0.9, 0.0, zc - 0.06, zc + 0.06, 0.06, 12)
    k.mobile(True)
    a = TAU * k.phase / 2.0
    _anneau_v(k, "acier_clair", 0.82, 0.03, a, 0.0, zc)
    _anneau_v(k, "cuivre", 0.72, 0.028, a + math.pi / 2, 0.45, zc)
    for t in (0.0, math.pi):
        p = G.rot_z((0.82 * math.cos(t), 0.0, 0.82 * math.sin(t)), a)
        k.sph("cristal_p", (p[0], p[1], p[2] + zc), 0.06, 12, 6)
    k.mobile(False)


def v_c(S, k):
    """Obélisque de résonance sans dalle (corrections du 3/11) : socle rond à bobines de 2 tuiles, 3 logements de modules
    en façade sud, 4 jambes vers les coins avec leurs feux cyan, disques de résonance épais à liseré cyan, diapason de a
    et grand cristal facetté (0,8 × 1,2 tuile), anneau de 3 lentilles qui tourne."""
    M = E.matieres(S, k, "hitech", "reso")
    E.lueurs(S, M)
    # socle rond, bobines de cuivre, fût central
    k.rev("car", 0.0, 0.0, [(0.0, 1.0), (0.16, 1.0), (0.22, 0.94), (0.22, 0.0)], 48)
    k.cerclages("acier", 0.0, 0.0, (0.08,), 1.0, 0.02, 0.03, 48)
    for i in range(5):
        k.tore("cuivre", 0.0, 0.0, 0.27 + i * 0.058, 0.76, 0.034, 56, 8)
    for i in range(8):
        a = TAU * (i + 0.5) / 8
        k.bz("car2", 0.76 * math.cos(a), 0.76 * math.sin(a), 0.22, 0.09, 0.09, 0.32, rz=a)
    k.cyl("car2", 0.0, 0.0, 0.22, 0.6, 0.56, 36)
    # 3 logements de modules, séparés, en façade sud
    for a_deg in (-125, -90, -55):
        a = math.radians(a_deg)
        px, py = 1.06 * math.cos(a), 1.06 * math.sin(a)
        k.b("car2", (px, py, 0.17), (0.3, 0.26, 0.34), rz=a + math.pi / 2)
        n = (math.cos(a), math.sin(a), 0.0)
        k.b("noir", (px + n[0] * 0.13, py + n[1] * 0.13, 0.19), (0.2, 0.02, 0.2), rz=a + math.pi / 2)
        k.b("cristal_p", (px + n[0] * 0.145, py + n[1] * 0.145, 0.15), (0.13, 0.01, 0.03), rz=a + math.pi / 2)
        k.voyant("voyant_v", px + n[0] * 0.14 + 0.08, py + n[1] * 0.14, 0.3, 0.016)
    # 4 jambes vers les coins, semelles, bornes à lentille cyan
    for sx in (-1, 1):
        for sy in (-1, 1):
            fx, fy = sx * 1.2, sy * 1.2 * D * 0.86
            a = math.atan2(fy, fx)
            k.axe("car", (0.85 * math.cos(a), 0.85 * math.sin(a), 0.18), (fx, fy, 0.1), 0.06, 10)
            k.bz("beton", fx, fy, 0.0, 0.24, 0.24, 0.1)
            k.cyl("car2", fx, fy, 0.1, 0.42, 0.065, 12)
            n = (math.cos(a), math.sin(a), 0.0)
            p = (fx + n[0] * 0.05, fy + n[1] * 0.05, 0.48)
            k.put("acier", G.oriente(G.tour([(-0.04, 0.085), (0.04, 0.085)], 16, "z", cap0=True, cap1=True), p, n))
            k.put("cristal_p", G.oriente(G.tour([(0.0, 0.065), (0.02, 0.05), (0.03, 0.0)], 14, "z", cap0=True), G.add(p, G.mul(n, 0.04)), n))
    # disques de résonance épais, à liseré cyan
    for i, z in enumerate((0.7, 0.88, 1.05, 1.2)):
        r = 0.66 - i * 0.07
        k.rev("acier_clair", 0.0, 0.0, [(z - 0.05, 0.15), (z - 0.05, r), (z + 0.05, r), (z + 0.05, 0.15)], 44)
        k.tore("cristal_p", 0.0, 0.0, z, r + 0.008, 0.03, 44, 6)
    k.cyl("car2", 0.0, 0.0, 0.6, 1.32, 0.16, 20)
    # diapason (de a) : culasse et deux branches, mâchoires
    k.caisson("acier_clair", 0.0, 0.0, 1.3, 1.2, 0.26, 0.18, 0.03)
    for sg in (-1, 1):
        k.caisson("acier_clair", sg * 0.53, 0.0, 1.45, 0.15, 0.22, 1.72, 0.02)
        k.b("car", (sg * 0.53, -0.115, 2.4), (0.15, 0.02, 0.9))
        k.axe("acier", (sg * 0.46, 0.0, 1.95), (sg * 0.34, 0.0, 1.95), 0.04, 10)
        k.axe("acier", (sg * 0.46, 0.0, 2.6), (sg * 0.28, 0.0, 2.6), 0.035, 10)
        k.voyant_h("voyant", sg * 0.53, 0.0, 3.17, 0.025)
    E.bipyramide(k, "cristal", 0.0, 0.0, 1.45, 3.15, 0.4, 6, 0.27)
    # anneau orbital de 3 lentilles (pièce mobile)
    k.mobile(True)
    a0 = TAU * k.phase / 3.0
    R, zr = 0.8, 2.2
    k.tore("acier_clair", 0.0, 0.0, zr, R, 0.045, 64, 10)
    k.tore("car", 0.0, 0.0, 1.47, 0.3, 0.035, 32, 8)
    for i in range(3):
        a = a0 + TAU * i / 3
        c, s = math.cos(a), math.sin(a)
        k.axe("acier", (0.3 * c, 0.3 * s, 1.47), (R * c, R * s, zr), 0.022, 6)
        p = (R * c, R * s, zr)
        n = (c, s, 0.0)
        k.put("car", G.oriente(G.tour([(-0.07, 0.13), (0.07, 0.13)], 20, "z", cap0=True, cap1=True), p, n))
        k.put("cristal_p", G.oriente(G.tour([(0.0, 0.11), (0.03, 0.09), (0.05, 0.0)], 16, "z", cap0=True), G.add(p, G.mul(n, 0.07)), n))
    k.mobile(False)
