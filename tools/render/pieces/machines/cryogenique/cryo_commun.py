"""Organes propres à l'UNITÉ CRYOGÉNIQUE (communs aux essais a, b, c) : raccords de la raffinerie, compresseur à vis
sur son châssis, échangeur à plaques givré, dewar à double paroi, étage à dilution (« lustre » de plaques dorées).
Repère : organes.py (x en tuiles, Y(yn) pour le nord, z en hauteur)."""
import math

import geo
from organes import Y

COTE = 5
ENTREES = (-1.0, 1.0)          # x des 2 entrées, bord SUD (y de jeu +3 -> yn -2,5)
SORTIES = (-2.0, 0.0, 2.0)     # x des 3 sorties, bord NORD


def raccords(k, z=0.34, r=0.12):
    for x in ENTREES:
        k.raccord(x, -COTE / 2, -1, mat="tuyau", r=r, z=z, long=0.5)
    for x in SORTIES:
        k.raccord(x, COTE / 2, +1, mat="tuyau", r=r, z=z, long=0.5)


def compresseur(k, x, yn, z0, L=1.1, axe="x"):
    """Compresseur à vis : moteur ailetté, accouplement sous carter, corps de vis, châssis en H, séparateur d'huile."""
    y = Y(yn)
    k.box("structure", (x, y, z0 + 0.05), (L + 0.3, 0.62, 0.1))                       # châssis
    for dy in (-0.27, 0.27):
        k.box("acier", (x, y + dy, z0 + 0.13), (L + 0.3, 0.05, 0.06))
    k.moteur((x - L * 0.25, y, z0 + 0.36), "x", 0.2, L * 0.45, "moteur", 9)
    k.box("danger_j", (x + L * 0.03, y, z0 + 0.36), (0.12, 0.34, 0.3))               # carter d'accouplement
    k.box("structure", (x + L * 0.28, y, z0 + 0.35), (L * 0.36, 0.42, 0.42))           # corps de vis
    k.caisson("structure", x + L * 0.1, x + L * 0.46, y - 0.21, y + 0.21, z0 + 0.14, z0 + 0.56, pas=0.09)
    k.boulons_cercle((x + L * 0.465, y, z0 + 0.35), 0.13, 8, (1, 0, 0), 0.018)
    k.cuve_v("chrome", x + L * 0.42, y + 0.5, 0.13, z0 + 0.12, z0 + 0.62, 16, (z0 + 0.3,), "trim", 0.5)
    k.tuyau("tuyau", [(x + L * 0.42, y + 0.5, z0 + 0.66), (x + L * 0.42, y + 0.5, z0 + 0.78),
                       (x + L * 0.3, y + 0.1, z0 + 0.78), (x + L * 0.3, y + 0.1, z0 + 0.57)], 0.04, 0.06, True)
    k.box("armoire", (x - L * 0.25, y - 0.18, z0 + 0.62), (0.14, 0.1, 0.1), petite=True)  # boîte à bornes
    k.cable((x - L * 0.25, y - 0.18, z0 + 0.62), (x - L * 0.55, y - 0.3, z0 + 0.1), 0.05, 0.016)


def echangeur(k, x, yn, z0, w=0.9, d=0.5, h=1.0):
    """Échangeur à plaques brasées (aluminium givré) : bloc, têtes de collecteur demi-cylindriques, tubulures."""
    y = Y(yn)
    k.caisson("mousse", x - w / 2, x + w / 2, y - d / 2, y + d / 2, z0, z0 + h, rebord="chrome", pas=0.12)
    for i in range(5):                                   # nervures givrées du bloc (passes)
        zz = z0 + h * (i + 0.5) / 5
        k.box("capot2", (x, y - d / 2 - 0.012, zz), (w - 0.06, 0.02, 0.025), petite=True)
    for dx in (-w * 0.32, 0.0, w * 0.32):
        k.put("chrome", geo.tour([(z0 + 0.12, 0.07), (z0 + h - 0.12, 0.07)], 12, "z", (x + dx, y - d / 2 - 0.05, 0.0),
                                 cap0=True, cap1=True))
        k.tuyau("mousse", [(x + dx, y - d / 2 - 0.05, z0 + h - 0.1), (x + dx, y - d / 2 - 0.05, z0 + h + 0.2),
                           (x + dx, y + d / 2 + 0.25, z0 + h + 0.2)], 0.045, 0.08, True)


def dewar(k, x, yn, r, z0, h, anneaux=(), mat="capot", feu=True):
    """Dewar vertical à double paroi : fût givré, cerclages chromés, fond bombé, soupapes et manomètre au sommet."""
    y = Y(yn)
    k.put("structure", geo.tour([(z0, r + 0.06), (z0 + 0.14, r + 0.06), (z0 + 0.14, r + 0.02)], 32, "z", (x, y, 0.0),
                                cap0=True))                                     # jupe
    for i in range(4):                                                          # pieds
        a = math.pi / 4 + i * math.pi / 2
        k.box("acier", (x + (r + 0.05) * math.cos(a), y + (r + 0.05) * math.sin(a), z0 + 0.12), (0.08, 0.08, 0.24))
    top = k.cuve_v(mat, x, y, r, z0 + 0.14, z0 + h, 36, anneaux, "chrome", 0.3, True, "structure")
    k.box("chrome", (x, y, top + 0.03), (0.12, 0.12, 0.06), petite=True)
    for dx in (-0.12, 0.12):                                                    # soupapes
        k.put("trim", geo.tour([(top - 0.05, 0.03), (top + 0.12, 0.03), (top + 0.14, 0.045), (top + 0.18, 0.0)], 8, "z",
                               (x + dx, y - 0.05, 0.0), cap0=True), True)
    k.put("chrome", geo.oriente(geo.tour([(0, 0.06), (0.03, 0.06), (0.03, 0.0)], 14, "z", cap0=True),
                                (x + r * 0.5, y - r * 0.87, z0 + h * 0.7), (0.5, -0.87, 0.0)), True)   # manomètre
    if feu:
        k.voyant((x - r * 0.5, y - r * 0.87, z0 + h * 0.55), "feu", 0.03, (-0.5, -0.87, 0.0))
    return top


def lustre(k, x, yn, z0, h, r=0.5, plaques=5):
    """Étage à dilution (« lustre » de cryostat) : plaques dorées étagées de plus en plus petites, tiges, lignes coax
    en cuivre qui descendent en spirale ; la plaque froide du bas porte une lueur cyan."""
    y = Y(yn)
    zs = [z0 + h - h * i / (plaques - 0.5) for i in range(plaques)]
    for i, z in enumerate(zs):
        rr = r * (1.0 - 0.13 * i)
        k.put("or", geo.tour([(z - 0.025, rr), (z + 0.025, rr)], 32, "z", (x, y, 0.0), cap0=True, cap1=True))
        k.boulons_cercle((x, y, z + 0.025), rr * 0.85, 10, (0, 0, 1), 0.014, "chrome")
        if i < plaques - 1:
            zn = zs[i + 1]
            rn = r * (1.0 - 0.13 * (i + 1))
            for j in range(4):
                a = math.pi / 4 + j * math.pi / 2
                k.put("chrome", geo.tube([(x + rn * 0.75 * math.cos(a), y + rn * 0.75 * math.sin(a), zn),
                                          (x + rn * 0.75 * math.cos(a), y + rn * 0.75 * math.sin(a), z)], 0.018, 6), True)
    for j in range(6):                                       # coax en spirale
        a0 = j * math.pi / 3
        pts = []
        for i in range(25):
            t = i / 24.0
            a = a0 + t * 1.6
            rr = r * (0.92 - 0.45 * t)
            pts.append((x + rr * math.cos(a), y + rr * math.sin(a), z0 + h - h * 0.9 * t))
        k.put("cuivre", geo.tube(pts, 0.012, 5), True)
    k.put("feu", geo.tour([(zs[-1] - 0.08, r * 0.4), (zs[-1] - 0.03, r * 0.42)], 24, "z", (x, y, 0.0), cap0=True))
    return zs[-1]


def rack(k, x0, x1, yn, z, n=3, r=0.07, mats=("tuyau", "mousse", "tuyau"), pas=0.9):
    """Rack à tuyaux : portiques (poteaux et traverses) tous les `pas`, n tuyaux parallèles (le long de x) posés
    dessus, colliers, chemin de câbles au-dessus."""
    y = Y(yn)
    m = max(2, int((x1 - x0) / pas) + 1)
    for i in range(m):
        x = x0 + (x1 - x0) * i / (m - 1)
        for dy in (-0.32, 0.32):
            k.box("structure", (x, y + dy, z / 2), (0.07, 0.07, z))
            k.box("acier", (x, y + dy, 0.13), (0.14, 0.14, 0.03), petite=True)
        k.box("structure", (x, y, z), (0.08, 0.76, 0.07))
        k.box("structure", (x, y, z + 0.32), (0.06, 0.76, 0.05))
    for j in range(n):
        yy = y - 0.22 + 0.44 * j / max(1, n - 1)
        k.tuyau(mats[j % len(mats)], [(x0 - 0.05, yy, z + 0.035 + r), (x1 + 0.05, yy, z + 0.035 + r)], r, 0.1, True,
                "trim", 0.9)
    k.box("acier", ((x0 + x1) / 2, y + 0.15, z + 0.36), (x1 - x0, 0.22, 0.03))
    for j in range(3):
        k.cable((x0, y + 0.08 + j * 0.06, z + 0.4), (x1, y + 0.08 + j * 0.06, z + 0.4), 0.0, 0.018)


def turbine(k, x, yn, z0, r=0.22, h=0.8):
    """Turbine de détente (froid par détente) : carter vertical, volute, bride, frein à huile."""
    y = Y(yn)
    k.box("structure", (x, y, z0 + 0.06), (r * 2.6, r * 2.6, 0.12))
    k.put("chrome", geo.tour([(z0 + 0.12, r), (z0 + h * 0.55, r), (z0 + h * 0.6, r * 1.35), (z0 + h * 0.75, r * 1.35),
                              (z0 + h * 0.8, r * 0.7), (z0 + h, r * 0.7), (z0 + h, 0.0)], 24, "z", (x, y, 0.0)))
    k.boulons_cercle((x, y, z0 + h * 0.75), r * 1.2, 10, (0, 0, 1), 0.018)
    k.put("structure", geo.tube([(x + r * 1.3, y, z0 + h * 0.67), (x + r * 2.2, y, z0 + h * 0.67)], r * 0.45, 14))
    k.bride((x + r * 2.2, y, z0 + h * 0.67), (1, 0, 0), r * 0.45)
    k.voyant((x - r * 0.7, y - r * 0.75, z0 + h * 0.4), "feu", 0.026, (-0.7, -0.7, 0.0))


def ventilateur(k, x, y, z, r=0.28):
    k.put("structure", geo.tour([(z, r + 0.05), (z + 0.12, r + 0.05), (z + 0.12, r), (z + 0.02, r)], 28, "z", (x, y, 0.0),
                                cap0=True))
    k.put("noir", geo.tour([(z + 0.03, r), (z + 0.04, 0.0)], 28, "z", (x, y, 0.0)))
    for i in range(7):                                   # pales
        a = i * math.tau / 7
        k.box("chrome", (x + r * 0.5 * math.cos(a), y + r * 0.5 * math.sin(a), z + 0.06), (r * 0.8, 0.07, 0.015),
              rz=a, rx=0.35, petite=True)
    for i in range(6):                                   # grille (barreaux nord-sud, longueur dans le cercle)
        u = -r + (i + 0.5) * 2 * r / 6
        k.box("grille", (x + u, y, z + 0.13), (0.022, 2 * math.sqrt(max(0.0, r * r - u * u)), 0.022), petite=True)
    k.put("grille", geo.tube([(x + r * math.cos(a), y + r * math.sin(a), z + 0.13)
                              for a in [math.tau * i / 24 for i in range(25)]], 0.016, 5, False, False))
    k.box("chrome", (x, y, z + 0.14), (0.1, 0.1, 0.04), petite=True)


def salle(k, x0, x1, yn0, yn1, z0, h, ventilateurs=2):
    """Salle des compresseurs : caisson caréné (ossature noire), grilles d'aération au sud, porte, ventilateurs des
    refroidisseurs d'huile sur le toit, cheminée d'évent, garde-corps de toit."""
    y0, y1 = Y(yn0), Y(yn1)
    k.caisson("capot2", x0, x1, y0, y1, z0, z0 + h, pas=0.12, rebord="structure")
    w = x1 - x0
    n = max(2, int(w / 0.8))
    for i in range(n):
        xg = x0 + w * (i + 0.5) / n
        k.grille((xg, y0, z0 + h * 0.55), min(0.5, w / n - 0.2), h * 0.4)
        k.box("structure", (x0 + w * i / n, y0 - 0.02, z0 + h / 2), (0.06, 0.04, h), petite=True)
    k.box("structure", (x1 - 0.3, y0 - 0.015, z0 + 0.38), (0.32, 0.03, 0.62))           # porte
    k.box("trim", (x1 - 0.2, y0 - 0.035, z0 + 0.38), (0.03, 0.03, 0.1), petite=True)
    k.panneau_danger(((x0 + x1) / 2, y0 - 0.02, z0 + 0.08), w - 0.1, 0.08)
    k.voyant((x0 + 0.15, y0 - 0.01, z0 + h * 0.88), "feu", 0.03, (0, -1, 0))
    for i in range(ventilateurs):
        ventilateur(k, x0 + w * (i + 0.5) / (ventilateurs + 0.6), (y0 + y1) / 2 - 0.1, z0 + h, min(0.3, w / 6))
    xs = x1 - 0.22
    k.put("tuyau", geo.tour([(z0 + h, 0.09), (z0 + h + 0.55, 0.09), (z0 + h + 0.57, 0.12), (z0 + h + 0.62, 0.12)], 14, "z",
                            (xs, y1 - 0.25, 0.0)))
    k.bride((xs, y1 - 0.25, z0 + h + 0.2), (0, 0, 1), 0.09)
    k.garde_corps([(x0 + 0.05, y0 + 0.05, z0 + h), (x1 - 0.05, y0 + 0.05, z0 + h)], 0.32)
