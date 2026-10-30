"""Essai B de l'unité cryogénique : BATTERIE DE 3 DEWARS verticaux (hauteurs différentes) au nord, au droit des 3
sorties ; collecteur givré et vannes au milieu ; au sud, la salle des COMPRESSEURS (caisson caréné à grilles, 2
ventilateurs de toit) et l'armoire. Silhouette en « orgue » : la plus lisible de loin, la moins « usine »."""
import math

import geo
from organes import Y
import cryo_commun as CC


def build(S, k):
    CC.raccords(k, 0.36, 0.15)
    z0 = k.socle(5, 0.42, 0.16, "socle", "structure")
    yd = 1.3
    hs = (2.2, 2.6, 1.95)
    tops = []
    for x, h in zip((-1.6, 0.0, 1.6), hs):
        tops.append(CC.dewar(k, x, yd, 0.6, z0, h, (z0 + 0.4, z0 + h * 0.55, z0 + h - 0.15), "capot"))
        k.tuyau("mousse", [(x, Y(yd) + 0.6, z0 + 0.45), (x, Y(2.3), z0 + 0.45), (x if abs(x) < 1 else x * 1.25, Y(2.3),
                                                                                     z0 + 0.45),
                           (x if abs(x) < 1 else x * 1.25, Y(2.3), 0.39)], 0.09, 0.14)
    # passerelle haute entre les dewars, garde-corps
    zp = z0 + 1.85
    k.caillebotis(-1.6, 1.6, Y(yd) - 0.95, Y(yd) - 0.62, zp)
    k.garde_corps([(-1.6, Y(yd) - 0.94, zp), (1.6, Y(yd) - 0.94, zp)], 0.36)
    for x in (-1.6, -0.8, 0.8, 1.6):
        k.box("structure", (x, Y(yd) - 0.8, (z0 + zp) / 2), (0.07, 0.07, zp - z0))
    k.echelle(-2.05, Y(yd) - 0.95, z0, zp)
    # collecteur givré au milieu (le long de x), vannes et piquages vers chaque dewar
    zc = z0 + 0.62
    k.tuyau("mousse", [(-2.2, Y(0.05), zc), (2.2, Y(0.05), zc)], 0.09, 0.1, True, "chrome", 0.9)
    for x in (-1.6, 0.0, 1.6):
        k.tuyau("mousse", [(x, Y(0.05), zc), (x, Y(yd) - 0.62, zc)], 0.055, 0.08)
        k.vanne((x + 0.25, Y(0.05), zc + 0.08), (1, 0, 0), 0.06, "chrome", "rouge")
    # salle des compresseurs (sud), carénée, grilles et ventilateurs
    x0, x1, yn0, yn1, h = -2.25, 0.55, -2.15, -0.55, 1.2
    k.caisson("capot2", x0, x1, Y(yn0), Y(yn1), z0, z0 + h, pas=0.12, rebord="chrome")
    for i in range(3):
        k.grille((x0 + 0.45 + i * 0.85, Y(yn0), z0 + h * 0.45), 0.55, 0.45)
    for x in (x0 + 0.3, x1 - 0.3):
        k.box("structure", (x, Y(yn0) - 0.015, z0 + h / 2), (0.05, 0.03, h - 0.06))
    CC.ventilateur(k, x0 + 0.75, Y((yn0 + yn1) / 2), z0 + h)
    CC.ventilateur(k, x0 + 1.75, Y((yn0 + yn1) / 2), z0 + h)
    k.panneau_danger(((x0 + x1) / 2, Y(yn0) - 0.02, z0 + 0.07), x1 - x0 - 0.1, 0.08)
    k.voyant((x1 - 0.2, Y(yn0) - 0.01, z0 + h * 0.85), "feu", 0.03, (0, -1, 0))
    # échangeur et armoire (sud-est)
    CC.echangeur(k, 1.55, -0.85, z0, 0.75, 0.4, 1.5)
    k.armoire((1.55, Y(-1.95), z0), (0.8, 0.35, 1.0), voyants=(("feu", 0.0), ("feu2", 0.09), ("feu", 0.18)))
    # entrées sud vers la salle des compresseurs et l'échangeur
    zt = 0.34
    k.tuyau("tuyau", [(-1.0, Y(-2.05), zt), (-1.0, Y(-2.0), zt)], 0.07, 0.05, False)
    k.tuyau("tuyau", [(1.0, Y(-2.05), zt), (1.0, Y(-1.5), zt), (1.25, Y(-1.5), zt), (1.25, Y(-1.1), z0 + 0.25)], 0.1)
    k.tuyau("mousse", [(0.3, Y(-0.6), z0 + 0.5), (0.3, Y(-0.3), z0 + 0.5), (0.3, Y(-0.3), zc), (0.3, Y(0.05), zc)], 0.1)
    # lueur : bagues cyan au pied des dewars
    for x in (-1.6, 0.0, 1.6):
        k.put("feu", geo.tour([(z0 + 0.15, 0.62), (z0 + 0.19, 0.62)], 32, "z", (x, Y(yd), 0.0)))
        k.halo(S, (x, Y(yd) - 0.7, z0 + 0.2), (0.3, 0.95, 1.0), 6.0, 0.2)
