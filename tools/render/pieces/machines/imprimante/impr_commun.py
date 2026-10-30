"""Organes propres à l'IMPRIMANTE DE CIRCUITS (communs aux essais a, b, c) : raccord nord, carte imprimée (verte,
pistes de cuivre, puces), convoyeur à rouleaux, fût. Repère : organes.py."""
import math

import geo
from organes import Y

COTE = 3


def raccord(k, z=0.32, r=0.15):
    k.raccord(0.0, COTE / 2, +1, mat="tuyau", r=r, z=z, long=0.45)


def carte(k, x, y, z, w=0.42, d=0.3):
    """Carte imprimée vue d'en haut : stratifié vert, pistes de cuivre, 2 puces noires, connecteur doré."""
    k.box("carte", (x, y, z), (w, d, 0.02))
    for i in range(4):
        k.box("cuivre", (x - w * 0.3 + i * w * 0.08, y + d * 0.1, z + 0.011), (0.012, d * 0.6, 0.004), petite=i % 2 == 0)
    k.box("noir", (x + w * 0.15, y + d * 0.05, z + 0.02), (0.1, 0.08, 0.02), petite=True)
    k.box("noir", (x - w * 0.1, y - d * 0.25, z + 0.02), (0.06, 0.05, 0.02), petite=True)
    k.box("cuivre", (x, y - d / 2 + 0.02, z + 0.012), (w * 0.6, 0.03, 0.005))


def convoyeur(k, x0, x1, yn, z, w=0.42, cartes=()):
    """Convoyeur à rouleaux : longerons, rouleaux tous les 0,09, pieds ; cartes posées aux x donnés."""
    y = Y(yn)
    for dy in (-w / 2, w / 2):
        k.box("structure", ((x0 + x1) / 2, y + dy, z), (x1 - x0, 0.04, 0.08))
    n = int((x1 - x0) / 0.09)
    for i in range(n):
        x = x0 + (x1 - x0) * (i + 0.5) / n
        k.put("chrome", geo.tube([(x, y - w / 2, z + 0.02), (x, y + w / 2, z + 0.02)], 0.022, 8), True)
    for x in (x0 + 0.08, x1 - 0.08):
        for dy in (-w / 2, w / 2):
            k.box("structure", (x, y + dy, z / 2), (0.05, 0.05, z))
    for x in cartes:
        carte(k, x, y, z + 0.055, 0.34, w * 0.8)


def fut(k, x, yn, z0, r=0.17, h=0.5, mat="rouge"):
    """Fût de 200 l : virole, 2 bourrelets, bonde."""
    y = Y(yn)
    k.put(mat, geo.tour([(z0, r), (z0 + h, r), (z0 + h, 0.0)], 20, "z", (x, y, 0.0)))
    for zz in (z0 + h * 0.33, z0 + h * 0.66):
        k.put(mat, geo.tour([(zz - 0.02, r + 0.015), (zz + 0.02, r + 0.015)], 20, "z", (x, y, 0.0), cap0=True, cap1=True),
              True)
    k.put("trim", geo.tour([(z0 + h, 0.035), (z0 + h + 0.025, 0.035), (z0 + h + 0.025, 0.0)], 8, "z",
                           (x + r * 0.5, y, 0.0)), True)
    k.put("trim", geo.tour([(z0 + h - 0.01, r + 0.01), (z0 + h + 0.02, r + 0.01)], 20, "z", (x, y, 0.0), cap1=True))


def capot_jaune(k, x0, x1, yn0, yn1, z0, z1, bandes=True):
    """Capot jaune délavé riveté, bande noire en pied (jaune et noir de la lignée de l'âge 4)."""
    y0, y1 = Y(yn0), Y(yn1)
    k.caisson("capot", x0, x1, y0, y1, z0, z1, pas=0.11, rebord="structure")
    if bandes:
        k.box("structure", ((x0 + x1) / 2, y0 - 0.006, z0 + 0.06), (x1 - x0, 0.014, 0.1))
