"""RÉACTEUR À SELS FONDUS (fo-molten-salt-reactor, 5×5, reactor) : cuve à modérateur graphite où circule un sel fluoré
fondu (≈ 700 °C), pompes primaires, boucles de sel incandescentes, échangeurs, collecteur de chaleur à 12 piquages aux
positions du réacteur vanilla : (±2, ±2), (0, ±2), (±2, 0) en tuiles, au bord de l'emprise. Variantes : a cuve à dôme et
4 pompes en diagonale, b enceinte cylindrique en béton à couronne ouverte, c cuve en fosse et boucles sur le pont.
"""
import math

import elements as E
import geo as G

D = E.D
TAU = E.TAU
HX, HY = 2.5, 2.5 * D
ZC = 0.26           # axe du collecteur de chaleur


def _collecteur(k, a=2.0, r=0.085):
    """Collecteur carré (tuiles ±a), 12 piquages jusqu'au bord, brides au bord. Rougeoie à chaud (chaleur)."""
    ay = a * D
    k.tuyau("acier", [(-a, -ay, ZC), (a, -ay, ZC), (a, ay, ZC), (-a, ay, ZC), (-a, -ay, ZC)], r=r, coude=0.18, brides=[], segs=16)
    pts = []
    for t in (-2.0, 0.0, 2.0):
        pts += [((t, ay, ZC), (t, HY - 0.03, ZC)), ((t, -ay, ZC), (t, -HY + 0.03, ZC)),
                ((a, t * D, ZC), (HX - 0.03, t * D, ZC)), ((-a, t * D, ZC), (-HX + 0.03, t * D, ZC))]
    for p, q in pts:
        k.axe("acier", p, q, r * 0.92, 14)
        n = G.norm(G.sub(q, p))
        k.collier("chaleur", G.sub(q, G.mul(n, 0.04)), n, r * 0.92, 0.03, 0.03)
        k.collier("acier", G.sub(q, G.mul(n, 0.14)), n, r * 0.92, 0.02, 0.02)
    for x in (-a, a):
        for y in (-ay, ay):
            k.bz("acier", x, y, 0.0, 0.2, 0.2, ZC)


def _boucle(k, pts, r=0.07, hublots=3):
    """Boucle de sel : tuyau calorifugé, hublots incandescents (sel) répartis."""
    k.tuyau("acier_clair", pts, r=r, coude=0.16, brides=[pts[0], pts[-1]], bride_mat="acier", segs=14)
    L = sum(G.length(G.sub(pts[i + 1], pts[i])) for i in range(len(pts) - 1))
    for j in range(hublots):
        s = L * (j + 1.0) / (hublots + 1.0)
        for i in range(len(pts) - 1):
            seg = G.length(G.sub(pts[i + 1], pts[i]))
            if s <= seg:
                p = G.lerp(pts[i], pts[i + 1], s / seg)
                n = G.norm(G.sub(pts[i + 1], pts[i]))
                k.collier("sel", p, n, r * 1.02, 0.012, 0.035)
                k.collier("acier", G.add(p, G.mul(n, 0.05)), n, r, 0.018, 0.012)
                k.collier("acier", G.sub(p, G.mul(n, 0.05)), n, r, 0.018, 0.012)
                break
            s -= seg


def _cuve(k, x, y, R=0.92, z0=0.2, h=1.25, dome=0.45):
    """Cuve en alliage : virole cerclée, dôme, couvercle à mécanismes de barres, hublot de sel au sommet."""
    k.rev("car2", x, y, [(0.0, R + 0.3), (0.2, R + 0.3), (0.2, R + 0.12), (z0, R + 0.12)], 40)
    k.cyl("acier_clair", x, y, z0, z0 + h, R, 40)
    k.cerclages("acier", x, y, [z0 + h * f for f in (0.12, 0.38, 0.62, 0.88)], R, 0.022, 0.03, 40)
    k.dome("acier_clair", x, y, z0 + h, R, dome / R, 40)
    zt = z0 + h + dome
    k.cyl("acier", x, y, zt - 0.06, zt + 0.06, R * 0.42, 28)
    k.boulons_rond("riv", x, y, zt + 0.06, R * 0.38, 14, 0.016)
    for i in range(4):
        a = TAU * (i + 0.5) / 4
        px, py = x + R * 0.24 * math.cos(a), y + R * 0.24 * math.sin(a)
        k.cyl("acier", px, py, zt + 0.06, zt + 0.48, 0.045, 10)
        k.cyl("car", px, py, zt + 0.48, zt + 0.58, 0.065, 12)
        k.voyant_h("voyant_v", px, py, zt + 0.58, 0.015)
    k.cyl("acier", x, y, zt + 0.06, zt + 0.12, 0.11, 16)
    k.cyl("sel", x, y, zt + 0.12, zt + 0.14, 0.085, 16)
    # anneau de hublots à mi-hauteur : le sel se voit
    for i in range(8):
        a = TAU * (i + 0.5) / 8
        if math.sin(a) > 0.3:
            continue
        p = (x + R * math.cos(a), y + R * math.sin(a), z0 + h * 0.5)
        k.put("sel", G.oriente(G.tour([(0.0, 0.07), (0.015, 0.06), (0.02, 0.0)], 12, "z", cap0=True), p, (math.cos(a), math.sin(a), 0.0)))
        k.collier("acier", p, (math.cos(a), math.sin(a), 0.0), 0.075, 0.02, 0.012)
    return zt


def _pompe(k, x, y, h=1.55):
    """Pompe primaire : bol à brides (hublot de sel), long arbre gainé, moteur à ailettes, capot."""
    k.cuve("car2", x, y, 0.0, 0.42, 0.26, 0.25, 28)
    k.cerclages("acier", x, y, (0.1, 0.3), 0.26, 0.02, 0.02, 28)
    k.rev("sel", x, y, [(0.18, 0.268), (0.24, 0.268)], 28, cap=False)
    k.cyl("acier", x, y, 0.42, h - 0.55, 0.09, 14)
    k.cyl("acier", x, y, h - 0.6, h - 0.55, 0.16, 18)
    E.pompe_v(k, x, y, h - 0.55, 0.15, 0.55, corps="acier", moteur="car")


def _echangeur(k, x, y, L, ax):
    k.echangeur(x, y, 0.12, L, 0.2, "car", "acier", axe=ax, cerc=4)


def v_a(S, k):
    M = E.matieres(S, k, "hitech")
    E.lueurs(S, M)
    _collecteur(k)
    zt = _cuve(k, 0.0, 0.1)
    d = 1.42
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * d, sy * d * D * 0.92
            _pompe(k, x, y)
            _boucle(k, [(x * 0.6, y * 0.6, 0.85), (x - sx * 0.18, y - sy * 0.18, 0.85), (x - sx * 0.18, y - sy * 0.18, 0.38)], 0.065, 1)
            _boucle(k, [(0.0, 0.1, 0.25 + 1.25 * 0.3), (x * 0.45, y * 0.45, 0.6), (x * 0.6, y * 0.6, 0.85)], 0.075, 1)
    # échangeurs : nord et sud (axe x), est et ouest (axe y), reliés au collecteur
    _echangeur(k, 0.0, 1.86 * D - 0.05, 1.3, "x")
    _echangeur(k, 0.0, -1.86 * D + 0.05, 1.3, "x")
    _echangeur(k, 1.86 - 0.05, 0.0, 1.5, "y")
    _echangeur(k, -1.86 + 0.05, 0.0, 1.5, "y")
    for (a, b) in (((0.0, 0.9, 0.5), (0.0, 2.3, 0.5)), ((0.0, -0.75, 0.5), (0.0, -2.3, 0.5)),
                   ((0.88, 0.1, 0.5), (1.6, 0.1, 0.5)), ((-0.88, 0.1, 0.5), (-1.6, 0.1, 0.5))):
        _boucle(k, [a, b], 0.06, 1)
    # cheminée des gaz de fission (nord-est) et vanne gelée du réservoir de vidange (sud-ouest)
    k.cyl("car2", 1.05, 2.55, 0.0, 2.4, 0.09, 16)
    k.voyant_h("voyant_r", 1.05, 2.55, 2.4, 0.03)
    k.cyl("acier", -1.0, -1.75, 0.0, 0.36, 0.13, 16)
    k.cyl("givre", -1.0, -1.75, 0.36, 0.44, 0.15, 16)
    k.ventilo(-0.55, -1.95, 0.4, 0.14, corps="noir")


def v_b(S, k):
    M = E.matieres(S, k, "hitech")
    E.lueurs(S, M)
    _collecteur(k)
    R = 1.55
    # enceinte de béton, couronne ouverte : on voit le couvercle de la cuve et les moteurs des pompes
    k.rev("beton", 0.0, 0.1, [(0.0, R + 0.08), (1.3, R + 0.08), (1.3, R - 0.14), (0.9, R - 0.14)], 56, cap=False)
    k.rev("noyau", 0.0, 0.1, [(0.9, R - 0.14), (0.9, 0.0)], 56)
    k.tore("acier", 0.0, 0.1, 1.33, R - 0.03, 0.06, 56, 8)
    k.cerclages("acier", 0.0, 0.1, (0.35, 0.8), R + 0.08, 0.02, 0.04, 56)
    k.cyl("acier_clair", 0.0, 0.1, 0.9, 1.15, 0.72, 36)
    k.rev("sel", 0.0, 0.1, [(1.15, 0.74), (1.17, 0.74), (1.17, 0.62)], 36, cap=False)
    k.cyl("acier", 0.0, 0.1, 1.15, 1.3, 0.6, 32)
    k.boulons_rond("riv", 0.0, 0.1, 1.3, 0.55, 16, 0.016)
    for i in range(4):
        a = TAU * (i + 0.5) / 4
        E.pompe_v(k, 0.98 * math.cos(a), 0.1 + 0.98 * math.sin(a), 0.9, 0.13, 0.75, corps="acier", moteur="car")
    k.cyl("acier", 0.0, 0.1, 1.3, 1.75, 0.06, 10)
    k.cyl("sel", 0.0, 0.1, 1.75, 1.78, 0.05, 10)
    # 4 échangeurs dehors, traversées dans le béton, boucles de sel
    for (x, y, ax, L) in ((0.0, 1.86 * D - 0.05, "x", 1.6), (0.0, -1.86 * D + 0.05, "x", 1.6), (1.88, 0.0, "y", 1.4), (-1.88, 0.0, "y", 1.4)):
        _echangeur(k, x, y, L, ax)
    for (a, b) in (((0.0, R + 0.1, 0.65), (0.0, 2.55, 0.65)), ((0.0, -R + 0.1, 0.65), (0.0, -2.4, 0.65)),
                   ((R, 0.1, 0.65), (1.75, 0.1, 0.65)), ((-R, 0.1, 0.65), (-1.75, 0.1, 0.65))):
        _boucle(k, [a, (a[0], a[1], 0.85), (b[0], b[1], 0.85), b], 0.07, 2)
    E.trefle(k, 0.0, -R + 0.02, 0.6, 0.12)
    k.cyl("car2", -1.6, 2.6, 0.0, 2.3, 0.09, 16)
    k.voyant_h("voyant_r", -1.6, 2.6, 2.3, 0.03)


def v_c(S, k):
    M = E.matieres(S, k, "hitech")
    E.lueurs(S, M)
    _collecteur(k)
    # cuve en fosse : margelle basse, bouchon rotatif excentré au ras du pont
    xc, yc = -0.45, 0.55
    k.rev("beton", xc, yc, [(0.0, 1.32), (0.32, 1.32), (0.32, 1.12)], 48, cap=False)
    k.cyl("acier", xc, yc, 0.24, 0.34, 1.12, 48)
    k.cyl("acier_clair", xc + 0.18, yc + 0.1, 0.34, 0.42, 0.72, 40)
    k.boulons_rond("riv", xc + 0.18, yc + 0.1, 0.42, 0.66, 18, 0.015)
    k.cyl("car2", xc - 0.3, yc - 0.1, 0.42, 0.5, 0.3, 28)
    k.cyl("sel", xc - 0.3, yc - 0.1, 0.5, 0.52, 0.2, 28)
    k.rev("sel", xc, yc, [(0.34, 1.13), (0.36, 1.13), (0.36, 1.08)], 48, cap=False)
    for i in range(3):
        a = 0.6 + TAU * i / 3
        px, py = xc + 0.18 + 0.4 * math.cos(a), yc + 0.1 + 0.4 * math.sin(a)
        k.cyl("acier", px, py, 0.42, 0.85, 0.045, 10)
        k.cyl("car", px, py, 0.85, 0.95, 0.065, 12)
    # 2 pompes, 2 échangeurs, boucles qui courent sur le pont
    _pompe(k, 1.25, 1.75, 1.45)
    _pompe(k, 1.3, -0.6, 1.3)
    _echangeur(k, 1.55, 0.6, 1.0, "y")
    _echangeur(k, -0.4, -1.9, 1.6, "x")
    _boucle(k, [(xc + 0.9, yc + 0.6, 0.45), (1.0, 1.75, 0.6), (1.0, 1.75, 0.3)], 0.08, 2)
    _boucle(k, [(xc + 1.0, yc - 0.3, 0.45), (1.05, -0.6, 0.55), (1.05, -0.6, 0.3)], 0.08, 2)
    _boucle(k, [(1.25, -0.85, 0.35), (1.25, -1.6, 0.35), (0.5, -1.9, 0.5)], 0.07, 2)
    _boucle(k, [(1.25, 1.5, 0.35), (1.55, 1.25, 0.6), (1.55, 1.1, 0.6)], 0.07, 1)
    # réservoirs de vidange en fosse (sud-ouest) à bouchon gelé
    for y in (-0.95, -1.35):
        k.echangeur(-1.55, y, 0.02, 0.9, 0.17, "car2", "acier", axe="x", cerc=2)
    k.cyl("givre", -0.9, -1.15, 0.0, 0.5, 0.09, 14)
    k.ventilo(-0.9, -1.15, 0.58, 0.12, corps="noir")
    k.cyl("car2", -1.75, 2.5, 0.0, 2.3, 0.09, 16)
    k.voyant_h("voyant_r", -1.75, 2.5, 2.3, 0.03)
