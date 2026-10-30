"""Essai B de l'imprimante : PRESSE DE SÉRIGRAPHIE. Portique hydraulique noir et jaune (2 colonnes, traverse, 2
vérins chromés) qui presse un cadre d'écran sur la table ; centrale hydraulique (moteur + bâche) au nord ; cuve
verticale d'encre à l'est, alimentée par le raccord nord ; pupitre au sud."""
import geo
from organes import Y
import impr_commun as IC


def build(S, k):
    IC.raccord(k, 0.34, 0.15)
    z0 = k.socle(3, 0.38, 0.13, "structure", "capot", 0.115)
    yc = Y(-0.15)
    # table et cadre d'écran
    k.caisson("structure", -0.95, 0.75, yc - 0.6, yc + 0.6, z0, 0.5, pas=0.11)
    IC.carte(k, -0.1, yc, 0.52, 0.8, 0.55)
    k.box("chrome", (-0.1, yc, 0.68), (1.0, 0.8, 0.03))                      # cadre
    k.box("grille", (-0.1, yc, 0.69), (0.86, 0.66, 0.012))                    # toile
    k.box("rouge", (-0.1, yc - 0.2, 0.74), (0.9, 0.05, 0.07), petite=True)   # raclette
    # portique : colonnes, traverse, vérins
    for x in (-1.15, 0.95):
        k.caisson("capot", x - 0.13, x + 0.13, yc - 0.2, yc + 0.2, z0, 1.55, pas=0.1, rebord="structure")
        k.panneau_danger((x, yc - 0.21, 0.3), 0.26, 0.35)
    k.caisson("capot", -1.3, 1.1, yc - 0.22, yc + 0.22, 1.42, 1.72, pas=0.1, rebord="structure")
    for x in (-0.55, 0.35):
        k.put("structure", geo.tour([(1.4, 0.11), (1.0, 0.11)], 18, "z", (x, yc, 0.0), cap0=True, cap1=True))
        k.put("chrome", geo.tour([(1.0, 0.05), (0.78, 0.05)], 12, "z", (x, yc, 0.0), cap1=True))
        k.box("structure", (x, yc, 0.77), (0.22, 0.22, 0.04), petite=True)
        k.boulons_cercle((x, yc, 1.4), 0.09, 6, (0, 0, -1), 0.014)
    k.tuyau("tuyau", [(-0.55, yc + 0.12, 1.3), (-0.55, Y(0.75), 1.3), (-0.55, Y(0.75), 0.8)], 0.035, 0.08, False)
    k.tuyau("tuyau", [(0.35, yc + 0.12, 1.25), (0.35, Y(0.75), 1.25), (-0.3, Y(0.75), 1.25), (-0.3, Y(0.75), 0.8)], 0.035,
            0.08, False)
    k.voyant((-1.15, yc - 0.21, 1.3), "feu", 0.028, (0, -1, 0))
    # centrale hydraulique (nord-ouest) : bâche, moteur vertical
    k.caisson("capot2", -1.4, 0.1, Y(0.45), Y(1.35), z0, 0.62, pas=0.11)
    k.moteur((-0.9, Y(0.9), 0.95), "z", 0.15, 0.5, "moteur", 7)
    k.box("structure", (-0.35, Y(0.9), 0.7), (0.3, 0.3, 0.16), petite=True)
    k.put("chrome", geo.oriente(geo.tour([(0, 0.06), (0.025, 0.06), (0.025, 0.0)], 14, "z", cap0=True),
                                (-0.15, Y(0.45) - 0.01, 0.45), (0, -1, 0)), True)
    # cuve d'encre verticale (est), raccord nord
    top = k.cuve_v("capot", 1.0, Y(0.7), 0.36, z0, 1.25, 28, (z0 + 0.3, 1.0), "structure", 0.3, True, "structure")
    k.tuyau("tuyau", [(0.0, Y(1.1), 0.34), (0.55, Y(1.1), 0.34), (0.55, Y(0.7), 0.34), (0.66, Y(0.7), 0.34)], 0.07, 0.08)
    k.vanne((0.3, Y(1.1), 0.34), (1, 0, 0), 0.055, "tuyau", "rouge")
    k.echelle(1.0, Y(0.7) - 0.4, z0, 1.25, cage=False)
    k.garde_corps([(0.72, Y(0.55), top), (1.28, Y(0.55), top)], 0.28, plinthe=False)
    # pupitre au sud
    k.armoire((0.95, Y(-1.2), z0), (0.55, 0.28, 0.5), voyants=(("feu", 0.0), ("feu2", 0.08), ("feu", 0.16)))
    IC.fut(k, -1.15, -1.15, z0, 0.16, 0.48, "rouge")
