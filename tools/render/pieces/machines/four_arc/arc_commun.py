"""Organes propres au FOUR À ARC (communs aux essais a, b, c) : raccord nord, électrode de graphite à nipples,
traversée de porcelaine (isolateur à ailettes, borne de cuivre), transformateur à radiateurs, poche de coulée.
Repère : organes.py."""
import math

import geo
from organes import Y

COTE = 4


def raccord(k, z=0.32, r=0.15):
    k.raccord(-0.5, COTE / 2, +1, mat="tuyau", r=r, z=z, long=0.5)


def electrode(k, x, y, z0, z1, r=0.1):
    """Électrode de graphite : colonne, joints (nipples) tous les 0,55, bout usé conique ; collier de cuivre."""
    k.put("graphite", geo.tour([(z0, r * 0.6), (z0 + 0.08, r), (z1, r), (z1 + 0.02, r * 0.8), (z1 + 0.03, 0.0)], 20, "z",
                               (x, y, 0.0)))
    z = z0 + 0.5
    while z < z1 - 0.1:
        k.put("noir", geo.tour([(z - 0.006, r + 0.004), (z + 0.006, r + 0.004)], 20, "z", (x, y, 0.0)), True)
        z += 0.55


def collier(k, x, y, z, r=0.1, h=0.2):
    """Porte-électrode : collier de cuivre refroidi, 2 mâchoires boulonnées."""
    k.put("cuivre", geo.tour([(z - h / 2, r + 0.05), (z + h / 2, r + 0.05)], 20, "z", (x, y, 0.0), cap0=True, cap1=True))
    for s in (-1, 1):
        k.box("cuivre", (x + s * (r + 0.07), y, z), (0.06, 0.1, h * 0.8), petite=True)
        k.boulon((x + s * (r + 0.1), y - 0.05, z), (0, -1, 0), 0.016)
    k.put("structure", geo.tour([(z + h / 2, r + 0.06), (z + h / 2 + 0.03, r + 0.06), (z + h / 2 + 0.03, r + 0.01)], 20,
                                "z", (x, y, 0.0)))


def traversee(k, x, y, z, h=0.42, r=0.07, n=7):
    """Traversée de porcelaine : bride, isolateur à n ailettes, borne de cuivre au sommet ; rend le z de la borne."""
    k.put("structure", geo.tour([(z, r * 1.8), (z + 0.04, r * 1.8), (z + 0.04, r)], 14, "z", (x, y, 0.0)))
    prof = [(z + 0.04, r)]
    pas = (h - 0.08) / n
    for i in range(n):
        zz = z + 0.06 + i * pas
        prof += [(zz, r), (zz + pas * 0.25, r * 1.75), (zz + pas * 0.45, r * 1.75), (zz + pas * 0.7, r)]
    prof += [(z + h, r * 0.8), (z + h, 0.0)]
    k.put("porcelaine", geo.tour(prof, 16, "z", (x, y, 0.0)))
    k.petites += n
    k.put("cuivre", geo.tour([(z + h, 0.035), (z + h + 0.1, 0.035), (z + h + 0.1, 0.0)], 10, "z", (x, y, 0.0)), True)
    k.box("cuivre", (x, y, z + h + 0.1), (0.1, 0.03, 0.04), petite=True)
    return z + h + 0.1


def transformateur(k, x0, x1, y0, y1, z0, z1, bornes=3, radiateurs="est"):
    """Transformateur en cuve : caisse grise cerclée, conservateur d'huile, traversées de porcelaine sur le
    couvercle, radiateurs à lames sur un flanc ; rend la liste des bornes (x, y, z)."""
    k.caisson("transfo", x0, x1, y0, y1, z0, z1, pas=0.11, rebord="structure")
    for i in range(1, 4):
        zz = z0 + (z1 - z0) * i / 4
        k.box("structure", ((x0 + x1) / 2, y0 - 0.012, zz), (x1 - x0, 0.024, 0.035))
    k.put("transfo", geo.tour([(x0 + 0.12, 0.09), (x1 - 0.12, 0.09)], 16, "x", (0.0, y1 - 0.12, z1 + 0.2), cap0=True,
                              cap1=True))
    for x in (x0 + 0.2, x1 - 0.2):
        k.box("structure", (x, y1 - 0.12, z1 + 0.06), (0.05, 0.08, 0.13), petite=True)
    out = []
    for i in range(bornes):
        x = x0 + (x1 - x0) * (i + 0.5) / bornes
        out.append((x, (y0 + y1) / 2 - 0.05, traversee(k, x, (y0 + y1) / 2 - 0.05, z1, 0.44, 0.06)))
    if radiateurs == "est":
        xr = x1 + 0.08
        for j in range(5):
            y = y0 + 0.1 + (y1 - y0 - 0.2) * j / 4
            k.ailettes((xr, y, (z0 + z1) / 2 - 0.02), 0.12, 0.08, (z1 - z0) * 0.8, 5)
    elif radiateurs == "ouest":
        xr = x0 - 0.08
        for j in range(5):
            y = y0 + 0.1 + (y1 - y0 - 0.2) * j / 4
            k.ailettes((xr, y, (z0 + z1) / 2 - 0.02), 0.12, 0.08, (z1 - z0) * 0.8, 5)
    k.grille(((x0 + x1) / 2, y0, z0 + (z1 - z0) * 0.3), (x1 - x0) * 0.5, (z1 - z0) * 0.25)
    k.panneau_danger(((x0 + x1) / 2, y0 - 0.02, z1 - 0.08), (x1 - x0) * 0.6, 0.06)
    return out


def poche(k, x, y, z0, r=0.26, h=0.36, feu=True):
    """Poche de coulée : fût conique cerclé, tourillons, bain rougeoyant."""
    k.put("structure", geo.tour([(z0, r * 0.8), (z0 + h, r), (z0 + h + 0.03, r + 0.03), (z0 + h + 0.03, r - 0.04),
                                 (z0 + h - 0.04, r - 0.04)], 24, "z", (x, y, 0.0), cap0=True))
    for zz in (z0 + h * 0.35, z0 + h * 0.7):
        rr = r * 0.8 + (r - r * 0.8) * (zz - z0) / h + 0.015
        k.put("chrome", geo.tour([(zz - 0.02, rr), (zz + 0.02, rr)], 24, "z", (x, y, 0.0), cap0=True, cap1=True), True)
    for s in (-1, 1):
        k.put("chrome", geo.tour([(0.0, 0.045), (0.08, 0.045)], 10, "x", (x + s * r if s > 0 else x - r - 0.08, y,
                                                                           z0 + h * 0.7), cap0=True, cap1=True), True)
    if feu:
        k.put("feu2", geo.tour([(z0 + h - 0.05, r - 0.04), (z0 + h - 0.05, 0.0)], 24, "z", (x, y, 0.0)))


def Yc(yn):
    return Y(yn)


def cercle(c, r, z, n=40):
    return [(c[0] + r * math.cos(geo.TAU * i / n), c[1] + r * math.sin(geo.TAU * i / n), z) for i in range(n + 1)]
