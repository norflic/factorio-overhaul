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


def lanterne(g, p, s=2.4):
    """Lanterne à huile agrandie (formes.lantern × s) : verre lumineux, cage, chapeau, anse."""
    M = g.M
    x, y, z = p
    g.cyl((x, y, z - 0.07 * s), "z", 0.03 * s, 0.02 * s, M["rawiron"], n=10, what="pied")
    g.cyl((x, y, z), "z", 0.024 * s, 0.07 * s, M["emit"], n=10, what="verre")
    for k in range(4):
        a = 0.4 + 1.5708 * k
        g.box((x + math.cos(a) * 0.026 * s, y + math.sin(a) * 0.026 * s, z), (0.009 * s, 0.009 * s, 0.08 * s),
              M["rawiron"], "hard", what="cage")
    g.cyl((x, y, z + 0.05 * s), "z", 0.03 * s, 0.025 * s, M["rawiron"], n=10, r2=0.012 * s, what="chapeau")


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
    # hauban et lanterne ; phase A2 (nuit presque éteinte) : lanterne plus haute et plus grosse, deuxième lanterne au
    # râtelier, trappe de ramonage rougeoyante au pied du tuyau, halos
    g.cyl((x - 0.13, y - 0.06, 1.45), "x", 0.012, 0.18, M["steel_dk"], n=6, what="potence")
    lanterne(g, (x - 0.24, y - 0.06, 1.3))
    g.cyl((x - 0.22, y - 0.06, 1.42), "z", 0.012, 0.08, M["steel_dk"], n=6, what="suspente")   # aucun jour (A2)
    g.box((x, y - 0.12, 0.2), (0.12, 0.02, 0.1), M["emit"], "flat", what="trappe_braise")
    g.box((x, y - 0.13, 0.26), (0.15, 0.02, 0.02), M["steel_dk"], "hard", what="trappe_cadre")
    g.halo((x - 0.22, y - 0.25, 1.2), M["_emit_rgb"], 8.0)
    g.halo((x, y - 0.3, 0.25), M["_emit_rgb"], 5.0)
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
    # sur le dessus de la pile (posée sur le piquet, elle fermait un jour de 39 px entre piquet et rondins : ilots.py)
    lanterne(g, (x0 + 0.08, yb - 0.1, 1.24))
    g.halo((x0 + 0.08, yb - 0.4, 1.2), M["_emit_rgb"], 8.0)
