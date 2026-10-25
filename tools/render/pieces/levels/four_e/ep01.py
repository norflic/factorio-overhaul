"""Four · Âge 1 · Pionnier (ère I, 2×2, niveaux 1 et 2). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 1.
S'exécute DANS Blender.

Niveau 1 : le four en acier VANILLA (jamais retouché). Niveau 2 : pièce dessinée SOUS le vanilla, qui doit DÉPASSER sa
silhouette (F42 ; le vanilla couvre x ±1,34 et monte à 1,30 tuile au nord du centre) : au nord, un TUYAU DE POÊLE de tôle
galvanisée à chapeau (coin nord-est, il monte à 1,9 tuile à l'écran) avec une lanterne pendue (lumière de nuit
seulement, famille « lanterne ») et une PILE DE BÛCHES (coin nord-ouest), sur un plancher de planches.
"""
import math

import ages
import corps
import formes as F
from repere import Y

EPOQUE = 1
NOM = ages.NOMS[1]
TRIPLET = ("four de série", "tuyau de poêle", "bûches")
FOYER = ages.FOYER[1]
HABILLAGE = {}


def matieres(metal, M):
    ages.matieres(1, metal, M)


def piece(g, c):
    M = g.M
    # plancher de planches au nord (relie les deux pièces : aucun îlot)
    for k in range(9):
        x = -0.98 + 0.22 * k
        g.box((x + 0.1, Y(0.78), 0.02), (0.2, Y(0.36), 0.04), M["wood" if k % 2 else "wood2"], "hard", what="planche")
    # tuyau de poêle : tronçons emboîtés, colliers, coude, chapeau chinois
    x, yn = 0.62, 0.8
    y = Y(yn)
    z = 0.04
    for k, (h, r) in enumerate(((0.55, 0.115), (0.5, 0.105), (0.5, 0.095))):
        g.cyl((x, y, z + h / 2), "z", r, h, M["galva"], n=18, what="troncon")
        g.tube_shell((x, y, z + h - 0.02), "z", r + 0.018, r - 0.01, 0.04, M["steel_dk"], n=18, what="collier")
        z += h
    g.cyl((x, y, z + 0.06), "z", 0.13, 0.04, M["steel_dk"], n=18, what="pied_chapeau")
    g.cyl((x, y, z + 0.14), "z", 0.2, 0.12, M["blackiron"], n=18, r2=0.02, style="hard", what="chapeau")
    for a in (0.0, 2.1, 4.2):
        g.box((x + 0.1 * math.cos(a), y + 0.1 * math.sin(a), z + 0.05), (0.015, 0.015, 0.1), M["steel_dk"], "hard",
              what="patte")
    # hauban et lanterne
    g.cyl((x - 0.13, y - 0.06, 1.25), "x", 0.012, 0.16, M["steel_dk"], n=6, what="potence")
    F.lantern(g, (x - 0.2, y - 0.06, 1.12), M["emit"])
    # râtelier de bûches (coin nord-ouest) : 7 rangs de rondins couchés entre deux paires de piquets, tranches claires
    # vers le sud ; le haut monte à 1,6 tuile à l'écran (au-dessus du vanilla)
    x0, yb = -0.6, Y(0.86)
    for i in range(7):
        for k in range(4 if i % 2 == 0 else 3):
            xx = x0 - 0.27 + 0.18 * k + (0.09 if i % 2 else 0.0)
            zz = 0.12 + i * 0.145
            g.cyl((xx, yb, zz), "y", 0.075, Y(0.4), M["wood2" if (i + k) % 2 else "wood"], n=10, what="buche")
            g.cyl((xx, yb - Y(0.2) - 0.004, zz), "y", 0.06, 0.008, M["cream"], n=10, style="flat", what="tranche")
    for sx in (-0.4, 0.4):
        for dy in (-0.2, 0.2):
            g.box((x0 + sx, yb + dy, 0.6), (0.05, 0.05, 1.18), M["wood2"], "hard", what="piquet")
    g.box((x0 + 0.05, yb - Y(0.2) - 0.02, 1.18), (0.34, 0.03, 0.035), M["wood"], "hard", what="hache_manche")
    g.box((x0 + 0.24, yb - Y(0.2) - 0.02, 1.18), (0.06, 0.035, 0.1), M["steel_hi"], "hard", what="hache_fer")
