"""Essai A de l'unité cryogénique : l'usine réelle. Au nord-ouest, la BOÎTE FROIDE (tour isolée où se fait la
distillation, ossature noire, panneaux givrés) ; au nord-est, le CRYOSTAT À DILUTION (dewar chromé) coiffé d'un écran
annulaire en lévitation (signature de l'âge 12, anneau cyan) ; au sud, le COMPRESSEUR à vis et l'ÉCHANGEUR à plaques
givré, l'armoire de commande. Tuyauterie givrée des 2 entrées sud aux 3 sorties nord."""
import math

import geo
from organes import Y
import cryo_commun as CC


def boite_froide(k, x0, x1, yn0, yn1, z0, z1):
    y0, y1 = Y(yn0), Y(yn1)
    # panneaux givrés en retrait dans l'ossature noire
    k.box("capot", ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0 - 0.06, y1 - y0 - 0.06, z1 - z0))
    for x in (x0, x1):                                   # poteaux d'angle (IPN)
        for y in (y0, y1):
            k.box("structure", (x, y, (z0 + z1) / 2), (0.13, 0.13, z1 - z0 + 0.02))
    nz = 5
    for i in range(nz + 1):                               # lisses horizontales (ceinture tous les 0,47)
        z = z0 + (z1 - z0) * i / nz
        k.box("structure", ((x0 + x1) / 2, y0 - 0.01, z), (x1 - x0, 0.09, 0.08))
        k.box("structure", (x1 + 0.01, (y0 + y1) / 2, z), (0.09, y1 - y0, 0.08))
        k.box("structure", (x0 - 0.01, (y0 + y1) / 2, z), (0.09, y1 - y0, 0.08))
        if 0 < i:
            zp = z - (z1 - z0) / nz / 2
            pn = [(p, (0, -1, 0)) for p in k.ligne((x0 + 0.08, y0 - 0.03, z - 0.02), (x1 - 0.08, y0 - 0.03, z - 0.02), 0.13)]
            pn += [(p, (1, 0, 0)) for p in k.ligne((x1 + 0.03, y0 + 0.08, z - 0.02), (x1 + 0.03, y1 - 0.08, z - 0.02), 0.17)]
            k.rivets(pn)
            # raidisseurs verticaux et joints de panneaux (sud)
            n = 4
            for j in range(1, n):
                x = x0 + (x1 - x0) * j / n
                k.box("structure", (x, y0 - 0.02, zp), (0.035, 0.035, (z1 - z0) / nz - 0.08), petite=True)
            for j in range(1, 3):
                y = y0 + (y1 - y0) * j / 3
                k.box("structure", (x1 + 0.02, y, zp), (0.035, 0.035, (z1 - z0) / nz - 0.08), petite=True)
    # plaque signalétique, hublot d'inspection, givre qui coule des joints (taches claires)
    k.box("chrome", (x0 + 0.35, y0 - 0.03, z0 + 0.62), (0.32, 0.02, 0.18), petite=True)
    k.panneau_danger(((x0 + x1) / 2, y0 - 0.04, z0 + 0.1), x1 - x0 - 0.14, 0.09)
    k.put("chrome", geo.oriente(geo.tour([(0, 0.11), (0.04, 0.11), (0.04, 0.08)], 18, "z", cap0=True),
                                (x1 - 0.5, y0 - 0.03, z0 + 1.3), (0, -1, 0)), True)
    k.put("feu2", geo.oriente(geo.sphere((0, 0, 0.0), 0.075, 14, 4, zmin=0.0), (x1 - 0.5, y0 - 0.04, z0 + 1.3), (0, -1, 0)))
    # toit : caillebotis, garde-corps, évents et potence
    k.caillebotis(x0 + 0.05, x1 - 0.05, y0 + 0.05, y1 - 0.05, z1 + 0.04)
    k.garde_corps([(x0 + 0.06, y0 + 0.06, z1 + 0.05), (x1 - 0.06, y0 + 0.06, z1 + 0.05), (x1 - 0.06, y1 - 0.06, z1 + 0.05)],
                  0.36)
    for (dx, dy, r) in ((0.35, 0.6, 0.07), (0.7, 0.9, 0.055), (1.1, 0.55, 0.07)):
        x, y = x0 + dx, y0 + dy
        k.put("chrome", geo.tour([(z1, r), (z1 + 0.32, r), (z1 + 0.34, r * 1.5), (z1 + 0.4, r * 1.5), (z1 + 0.42, 0.0)],
                                 12, "z", (x, y, 0.0)), True)
        k.bride((x, y, z1 + 0.12), (0, 0, 1), r)
    xp, yp = x0 + 0.25, y1 - 0.3
    k.put("structure", geo.tube([(xp, yp, z1), (xp, yp, z1 + 0.7), (xp + 0.55, yp - 0.2, z1 + 0.7)], 0.03, 8))
    k.put("chrome", geo.tube([(xp + 0.5, yp - 0.18, z1 + 0.68), (xp + 0.5, yp - 0.18, z1 + 0.45)], 0.01 + 0.006, 5))
    k.echelle(x1 - 0.32, y0 - 0.12, z0, z1, cage=True)


def build(S, k):
    CC.raccords(k, 0.36, 0.15)
    z0 = k.socle(5, 0.42, 0.16, "socle", "structure")
    # boîte froide (nord-ouest)
    boite_froide(k, -2.2, -0.5, 0.35, 2.1, z0, 2.45)
    # cryostat à dilution (nord-est) et son écran annulaire en lévitation
    xc, ync, rc = 1.32, 1.05, 0.74
    top = CC.dewar(k, xc, ync, rc, z0, 2.2, (z0 + 0.45, z0 + 1.1, z0 + 1.75, z0 + 2.05), "capot")
    zr = z0 + 2.2 + 0.3
    k.put("structure", geo.tour([(zr, rc + 0.22), (zr + 0.12, rc + 0.22), (zr + 0.12, rc + 0.06), (zr, rc + 0.06)], 40,
                                "z", (xc, Y(ync), 0.0), cap0=False))
    k.put("chrome", geo.tour([(zr + 0.12, rc + 0.06), (zr + 0.12, rc + 0.23), (zr + 0.15, rc + 0.23), (zr + 0.15, rc + 0.06)], 40,
                             "z", (xc, Y(ync), 0.0)))
    k.put("feu", geo.tour([(zr - 0.015, rc + 0.18), (zr - 0.005, rc + 0.1)], 40, "z", (xc, Y(ync), 0.0)))
    for i in range(4):                                       # pylônes qui portent l'écran (vide visible dessous)
        a = math.pi / 4 + i * math.pi / 2
        px, py = xc + (rc + 0.32) * math.cos(a), Y(ync) + (rc + 0.32) * math.sin(a)
        k.box("structure", (px, py, (z0 + zr) / 2), (0.07, 0.07, zr - z0))
        k.box("chrome", (px, py, zr - 0.08), (0.11, 0.11, 0.06), petite=True)
        k.put("feu", geo.boite((px, py, zr - 0.2), (0.04, 0.04, 0.12)))
    k.halo(S, (xc, Y(ync) - rc, zr), (0.3, 0.95, 1.0), 18.0, 0.2)
    # compresseur (sud-ouest), échangeur (sud-est), armoire
    CC.salle(k, -2.3, -0.42, -2.25, -0.7, z0, 1.05)
    CC.echangeur(k, 0.75, -0.75, z0, 0.8, 0.45, 1.6)
    k.armoire((1.75, Y(-1.55), z0), (0.55, 0.42, 1.1), voyants=(("feu", 0.0), ("feu2", 0.08)))
    # tuyauterie : entrée ouest -> compresseur -> boîte froide ; entrée est -> échangeur -> cryostat
    zt = 0.34
    k.tuyau("tuyau", [(-1.0, Y(-2.05), zt), (-1.0, Y(-1.7), zt), (-0.6, Y(-1.7), zt), (-0.6, Y(-1.35), z0 + 0.35)], 0.1)
    k.tuyau("mousse", [(-0.45, Y(-1.2), z0 + 0.55), (-0.45, Y(-0.3), z0 + 0.55), (-0.45, Y(-0.3), 1.2),
                       (-0.45, Y(0.3), 1.2)], 0.1)
    k.tuyau("tuyau", [(1.0, Y(-2.05), zt), (1.0, Y(-1.15), zt), (0.75, Y(-1.15), zt), (0.75, Y(-0.95), z0 + 0.2)], 0.1)
    k.tuyau("mousse", [(0.75, Y(-0.25), z0 + 1.15), (0.75, Y(0.2), z0 + 1.15), (0.6, Y(0.2), z0 + 1.15),
                       (0.6, Y(0.65), z0 + 1.15)], 0.06)
    # sorties nord : boîte froide -> (−2) et (0) ; cryostat -> (2)
    for x in (-2.0, 0.0):
        k.tuyau("mousse", [(x if x < -1 else -0.6, Y(2.1), 0.9), (x if x < -1 else -0.6, Y(2.3), 0.9),
                           (x, Y(2.3), 0.9), (x, Y(2.3), zt + 0.05)], 0.09, 0.14)
    k.tuyau("mousse", [(2.0, Y(1.2), z0 + 0.6), (2.0, Y(2.25), z0 + 0.6), (2.0, Y(2.25), zt + 0.05)], 0.09, 0.14)
    # chemin de câbles de l'armoire au compresseur, au sol
    k.box("acier", (0.3, Y(-2.0), z0 + 0.04), (2.2, 0.12, 0.05))
    for i in range(6):
        k.cable((-0.75 + i * 0.35, Y(-2.0) + 0.03, z0 + 0.08), (-0.75 + (i + 1) * 0.35, Y(-2.0) + 0.03, z0 + 0.08), 0.0, 0.02)
    # garde-corps de la plate-forme du cryostat, vannes sur les entrées
    k.vanne((-1.0, Y(-1.7) + 0.0, zt), (0, 1, 0), 0.06, "chrome", "rouge")
    k.vanne((1.0, Y(-1.5), zt), (0, 1, 0), 0.06, "chrome", "rouge")
    # rack à tuyaux au milieu (est-ouest) et turbine de détente (sud)
    CC.rack(k, -0.35, 2.3, 0.0, 0.85, 3, 0.07)
    CC.turbine(k, -0.1, -1.8, z0, 0.2, 0.75)
