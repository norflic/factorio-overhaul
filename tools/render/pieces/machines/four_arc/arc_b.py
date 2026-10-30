"""Essai B du four à arc : FOUR À ARC SOUS VIDE (refusion du titane). Creuset de cuivre dans une chemise d'eau
bleue, chambre à vide émaillée à grosses brides boulonnées et regards (lueur bleue de l'arc), soufflet et tige
d'électrode chromée sous un haut portique à vis et moteur ; redresseur à traversées (nord-ouest) et barres de cuivre
le long du montant ; gaine à vide vers 2 pompes (sud) ; plate-forme de conduite au sud de la chambre."""
import math

import geo
from organes import Y
import arc_commun as AC


def build(S, k):
    AC.raccord(k)
    z0 = k.socle(4, 0.45, 0.16, "socle", "structure")
    xc, yc = 0.15, Y(-0.2)
    # chemise d'eau et creuset
    zj = z0 + 0.72
    k.put("structure", geo.tour([(z0, 0.72), (z0 + 0.1, 0.72), (z0 + 0.1, 0.6)], 40, "z", (xc, yc, 0.0), cap0=True))
    k.cuve_v("capot2", xc, yc, 0.6, z0 + 0.1, zj, 40, (z0 + 0.32, z0 + 0.55), "structure", dome=0.0)
    for a in (math.pi * 1.2, math.pi * 1.8):
        e = (math.cos(a), math.sin(a), 0.0)
        p = (xc + 0.6 * e[0], yc + 0.6 * e[1], z0 + 0.25)
        k.tuyau("tuyau", [p, geo.add(p, geo.mul(e, 0.25))], 0.045, 0.06, True)
    k.put("cuivre", geo.tour([(zj, 0.66), (zj + 0.08, 0.66), (zj + 0.08, 0.5)], 40, "z", (xc, yc, 0.0)))
    k.boulons_cercle((xc, yc, zj + 0.08), 0.6, 20, (0, 0, 1), 0.02)
    # chambre à vide : virole émaillée, brides, regards
    zc0, zc1, rc = zj + 0.08, zj + 0.78, 0.5
    for zz in (zc0, zc1 - 0.1):
        k.put("structure", geo.tour([(zz, rc + 0.1), (zz + 0.1, rc + 0.1), (zz + 0.1, rc)], 40, "z", (xc, yc, 0.0),
                                    cap0=True))
        k.boulons_cercle((xc, yc, zz + 0.1), rc + 0.06, 24, (0, 0, 1), 0.018)
    k.put("capot", geo.tour([(zc0 + 0.1, rc), (zc1 - 0.1, rc)], 40, "z", (xc, yc, 0.0)))
    for a in (math.pi * 1.35, math.pi * 1.65):
        e = (math.cos(a), math.sin(a), 0.0)
        p = (xc + rc * e[0], yc + rc * e[1], (zc0 + zc1) / 2)
        k.put("structure", geo.oriente(geo.tour([(0.0, 0.09), (0.12, 0.09), (0.12, 0.11), (0.15, 0.11), (0.15, 0.0)], 16,
                                                "z"), p, e))
        k.put("feu", geo.oriente(geo.sphere((0, 0, 0.0), 0.06, 10, 4, zmin=0.0), geo.add(p, geo.mul(e, 0.15)), e))
        k.boulons_cercle(geo.add(p, geo.mul(e, 0.15)), 0.09, 6, e, 0.012)
    k.halo(S, (xc, yc - rc - 0.35, (zc0 + zc1) / 2), (0.3, 0.6, 1.0), 9.0, 0.3)
    # couvercle, soufflet, tige d'électrode
    k.put("capot", geo.tour([(zc1, rc + 0.1), (zc1 + 0.05, rc + 0.1), (zc1 + 0.2, 0.25), (zc1 + 0.24, 0.2),
                             (zc1 + 0.24, 0.0)], 40, "z", (xc, yc, 0.0)))
    zs = zc1 + 0.24
    for i in range(9):
        zz = zs + i * 0.05
        k.put("noir" if i % 2 else "chrome", geo.tour([(zz, 0.17), (zz + 0.05, 0.19 if i % 2 else 0.16)], 20, "z",
                                                      (xc, yc, 0.0)), True)
    zx = 3.15
    k.put("chrome", geo.tour([(zs + 0.45, 0.11), (zx, 0.11)], 20, "z", (xc, yc, 0.0)))
    # portique : 2 montants, traverse, vis, moteur, barres de cuivre
    for x in (xc - 0.95, xc + 0.95):
        k.box("structure", (x, yc, (z0 + zx + 0.3) / 2), (0.16, 0.2, zx + 0.3 - z0))
        k.box("structure", (x, yc, z0 + 0.04), (0.32, 0.36, 0.08))
        for sx in (-1, 1):
            for sy in (-1, 1):
                k.boulon((x + sx * 0.12, yc + sy * 0.14, z0 + 0.08), (0, 0, 1), 0.018)
        for dz in (0.5, 1.2, 1.9, 2.6):
            k.box("chrome", (x, yc - 0.105, z0 + dz), (0.1, 0.02, 0.06), petite=True)
    k.caisson("capot2", xc - 1.05, xc + 1.05, yc - 0.13, yc + 0.13, zx, zx + 0.24, pas=0.1, rebord="structure")
    k.put("chrome", geo.tour([(zs, 0.035), (zx, 0.035)], 10, "z", (xc + 0.4, yc, 0.0), cap0=True), True)
    k.box("structure", (xc + 0.2, yc, zs + 0.9), (0.5, 0.12, 0.1))                       # chariot de tige
    k.moteur((xc + 0.4, yc, zx + 0.42), "z", 0.12, 0.3)
    k.put("cuivre", geo.tour([(zx - 0.1, 0.15), (zx + 0.02, 0.15)], 20, "z", (xc, yc, 0.0), cap0=True, cap1=True))
    for dy in (-0.05, 0.05):
        k.box("cuivre", (xc - 0.95 - 0.1, yc + dy, (z0 + 0.7 + zx) / 2), (0.03, 0.06, zx - z0 - 0.7))
        k.box("cuivre", (xc - 0.48, yc + dy, zx - 0.05), (0.95, 0.06, 0.03))
    # redresseur (nord-ouest) et liaisons vers le montant
    bornes = AC.transformateur(k, -1.8, -0.95, Y(0.95), Y(1.85), z0, 0.95, 3, "ouest")
    for (bx, by, bz) in bornes:
        k.cable((bx, by, bz), (xc - 1.05, yc + 0.05, z0 + 0.75), 0.18, 0.026)
    # gaine à vide vers 2 pompes (sud)
    zv = (zc0 + zc1) / 2 + 0.05
    k.tuyau("chrome", [(xc + rc, yc + 0.15, zv), (1.5, yc + 0.15, zv), (1.5, Y(-1.35), zv), (1.5, Y(-1.35), z0 + 0.62)],
            0.13, 0.22)
    k.vanne((1.5, Y(-0.8), zv), (0, 1, 0), 0.09, "chrome", "rouge")
    for x in (1.5, 0.7):
        k.caisson("capot2", x - 0.27, x + 0.27, Y(-1.82), Y(-1.12), z0, z0 + 0.45, pas=0.09, rebord="structure")
        k.moteur((x, Y(-1.47), z0 + 0.62), "x", 0.12, 0.36)
    k.tuyau("chrome", [(1.3, Y(-1.35), z0 + 0.62), (0.9, Y(-1.35), z0 + 0.62)], 0.07, 0.1, True)
    # plate-forme de conduite (sud de la chambre), échelle, pupitre
    zp = z0 + 0.8
    k.caillebotis(xc - 0.8, xc + 0.8, yc - 1.0, yc - 0.62, zp)
    k.garde_corps([(xc - 0.8, yc - 1.0, zp), (xc + 0.8, yc - 1.0, zp)], 0.38)
    for x in (xc - 0.75, xc + 0.75):
        k.box("structure", (x, yc - 0.97, (z0 + zp) / 2), (0.05, 0.05, zp - z0), petite=True)
    k.echelle(xc - 0.55, yc - 1.02, z0, zp, cage=False)
    k.armoire((-1.3, Y(-1.55), z0), (0.8, 0.32, 0.62), voyants=(("feu", 0.0), ("feu2", 0.08), ("feu", 0.16)))
    # arrivée d'eau (raccord nord) vers la chemise
    k.tuyau("tuyau", [(-0.5, Y(1.65), z0 + 0.03), (-0.5, Y(1.65), z0 + 0.42), (-0.5, yc + 0.35, z0 + 0.42),
                      (xc - 0.5, yc + 0.35, z0 + 0.42)], 0.06, 0.12)
    k.vanne((-0.5, Y(1.4), z0 + 0.42), (0, 1, 0), 0.055, "chrome", "rouge")
