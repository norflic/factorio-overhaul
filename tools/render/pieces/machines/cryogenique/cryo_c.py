"""Essai C de l'unité cryogénique : GRAND CRYOSTAT ouvert. L'enveloppe à vide (chromée, givrée au pied) est
descendue à mi-hauteur pour montrer l'ÉTAGE À DILUTION (lustre de plaques dorées, lignes coax en cuivre) : c'est
l'objet que la machine fabrique. Plaque supérieure portée par 4 pylônes ; écran thermique annulaire en lévitation
(anneau cyan de l'âge 12) ; compresseur et boîte froide basse autour, armoire au sud."""
import math

import geo
from organes import Y
import cryo_commun as CC


def build(S, k):
    CC.raccords(k, 0.36, 0.15)
    z0 = k.socle(5, 0.42, 0.16, "socle", "structure")
    xc, ync, R = 0.25, 0.55, 1.15
    yc = Y(ync)
    # enveloppe à vide basse : jupe, fût chromé cerclé, bord supérieur épais (on voit dedans)
    k.put("structure", geo.tour([(z0, R + 0.1), (z0 + 0.16, R + 0.1), (z0 + 0.16, R + 0.03)], 48, "z", (xc, yc, 0.0),
                                cap0=True))
    zb = z0 + 1.25
    k.put("chrome", geo.tour([(z0 + 0.16, R), (zb, R)], 48, "z", (xc, yc, 0.0)))
    k.put("mousse", geo.tour([(z0 + 0.16, R + 0.012), (z0 + 0.42, R + 0.012)], 48, "z", (xc, yc, 0.0)))   # givre au pied
    k.put("noir", geo.tour([(zb - 0.6, R - 0.04), (zb - 0.45, R - 0.04), (zb - 0.45, 0.0)], 48, "z", (xc, yc, 0.0)))
    k.put("structure", geo.tour([(zb - 0.02, R + 0.07), (zb + 0.06, R + 0.07), (zb + 0.06, R - 0.06), (zb - 0.02, R - 0.06)],
                                48, "z", (xc, yc, 0.0)))
    k.boulons_cercle((xc, yc, zb + 0.06), R + 0.0, 24, (0, 0, 1), 0.018)
    for zz in (z0 + 0.5, z0 + 0.75):
        k.put("trim", geo.tour([(zz - 0.025, R + 0.02), (zz + 0.025, R + 0.02)], 48, "z", (xc, yc, 0.0), cap0=True,
                               cap1=True))
    # étage à dilution visible au-dessus de l'enveloppe
    zt = zb + 1.25
    CC.lustre(k, xc, ync, zb - 0.15, zt - zb + 0.05, 0.72, 5)
    # plaque supérieure (bride de 300 K) portée par 4 pylônes, passages étanches et câbles
    # r2 : bride supérieure ANNULAIRE (ouverte) et croisillon : le lustre doré se voit d'en haut
    k.put("structure", geo.tour([(zt, R + 0.05), (zt + 0.14, R + 0.05), (zt + 0.14, R - 0.2), (zt, R - 0.2)], 48, "z",
                                (xc, yc, 0.0)))
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        k.box("structure", (xc + (R - 0.2) / 2 * math.cos(a), yc + (R - 0.2) / 2 * math.sin(a), zt + 0.08),
              (R - 0.15, 0.09, 0.1), rz=a)
    k.put("chrome", geo.tour([(zt + 0.02, 0.2), (zt + 0.22, 0.2), (zt + 0.24, 0.12), (zt + 0.3, 0.0)], 24, "z", (xc, yc, 0.0),
                             cap0=True))
    k.boulons_cercle((xc, yc, zt + 0.14), R - 0.08, 20, (0, 0, 1), 0.018)
    for i in range(5):
        a = 0.3 + i * math.tau / 5
        px, py = xc + R * 0.75 * math.cos(a), yc + R * 0.75 * math.sin(a)
        k.put("chrome", geo.tour([(zt + 0.14, 0.05), (zt + 0.3, 0.05), (zt + 0.32, 0.07), (zt + 0.36, 0.07)], 10, "z",
                                 (px, py, 0.0), cap1=True), True)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        px, py = xc + (R + 0.28) * math.cos(a), yc + (R + 0.28) * math.sin(a)
        k.box("structure", (px, py, (z0 + zt + 0.1) / 2), (0.12, 0.12, zt + 0.1 - z0))
        for zz in (z0 + 0.4, z0 + 1.0, z0 + 1.6):
            k.box("chrome", (px, py, zz), (0.15, 0.15, 0.04), petite=True)
        k.box("structure", ((px + xc) / 2, (py + yc) / 2, zt + 0.07), (R + 0.28, 0.08, 0.08), rz=a)   # poutre radiale
    # écran thermique annulaire en lévitation (vide au-dessus de l'enveloppe), anneau cyan dessous
    zr = zb + 0.3
    k.put("structure", geo.tour([(zr, R + 0.2), (zr + 0.09, R + 0.2), (zr + 0.09, R + 0.1), (zr, R + 0.1)], 48, "z",
                                (xc, yc, 0.0)))
    k.put("chrome", geo.tour([(zr + 0.09, R + 0.1), (zr + 0.09, R + 0.21), (zr + 0.12, R + 0.21), (zr + 0.12, R + 0.1)], 48, "z",
                             (xc, yc, 0.0)))
    k.put("feu", geo.tour([(zr - 0.012, R + 0.17), (zr - 0.004, R + 0.12)], 48, "z", (xc, yc, 0.0)))
    k.halo(S, (xc, yc - R, zr), (0.3, 0.95, 1.0), 16.0, 0.2)
    k.halo(S, (xc, yc, zb), (0.3, 0.95, 1.0), 6.0, 0.2)
    # boîte froide basse (nord-ouest) et compresseur (sud-ouest), armoire (sud-est)
    k.caisson("capot", -2.3, -1.35, Y(0.6), Y(2.2), z0, z0 + 1.9, pas=0.12, rebord="chrome")
    k.grille((-1.82, Y(0.6), z0 + 0.6), 0.5, 0.4)
    k.echelle(-1.5, Y(0.6) - 0.1, z0, z0 + 1.9, cage=True)
    CC.salle(k, -2.3, -0.3, -2.25, -0.75, z0, 1.0)
    k.armoire((1.7, Y(-1.6), z0), (0.6, 0.4, 1.05), voyants=(("feu", 0.0), ("feu2", 0.08)))
    CC.echangeur(k, 1.9, -0.45, z0, 0.55, 0.4, 1.4)
    # tuyauterie
    zt0 = 0.34
    k.tuyau("tuyau", [(-1.0, Y(-2.05), zt0), (-1.0, Y(-1.85), zt0), (-0.35, Y(-1.85), zt0), (-0.35, Y(-1.45), z0 + 0.35)],
            0.1)
    k.tuyau("mousse", [(-0.3, Y(-1.3), z0 + 0.55), (-0.3, Y(-0.4), z0 + 0.55), (xc - 0.6, Y(-0.4), z0 + 0.55),
                       (xc - 0.6, yc - R * 0.8, z0 + 0.55)], 0.1)
    k.tuyau("tuyau", [(1.0, Y(-2.05), zt0), (1.0, Y(-1.1), zt0), (1.9, Y(-1.1), zt0), (1.9, Y(-0.7), z0 + 0.2)], 0.1)
    k.tuyau("mousse", [(1.9, Y(-0.2), z0 + 0.95), (1.9, Y(0.35), z0 + 0.95), (xc + R * 0.9, Y(0.35), z0 + 0.95)], 0.055)
    k.tuyau("mousse", [(-1.6, Y(2.2), z0 + 0.7), (-1.6, Y(2.32), z0 + 0.7), (-2.0, Y(2.32), z0 + 0.7),
                       (-2.0, Y(2.32), zt0 + 0.05)], 0.09, 0.14)
    k.tuyau("mousse", [(xc, yc + R, z0 + 0.6), (xc, Y(2.3), z0 + 0.6), (0.0, Y(2.3), z0 + 0.6), (0.0, Y(2.3), zt0 + 0.05)],
            0.06, 0.08)
    k.tuyau("mousse", [(xc + R * 0.7, yc + R * 0.7, z0 + 0.45), (2.0, yc + R * 0.7, z0 + 0.45), (2.0, Y(2.3), z0 + 0.45),
                       (2.0, Y(2.3), zt0 + 0.05)],
            0.06, 0.08)
    k.vanne((-1.0, Y(-1.85), zt0), (0, 1, 0), 0.06, "chrome", "rouge")
    k.vanne((1.45, Y(-1.1), zt0), (1, 0, 0), 0.06, "chrome", "rouge")
    k.garde_corps([(-0.6, Y(-0.85), z0), (0.9, Y(-0.85), z0)], 0.4)
