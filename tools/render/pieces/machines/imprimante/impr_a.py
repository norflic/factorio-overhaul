"""Essai A de l'imprimante : LIGNE DE GRAVURE. Au nord, le bac d'attaque (cuve horizontale jaune, alimentée par le
raccord) et sa passerelle ; au milieu, le convoyeur de cartes sous un portique d'impression ; hotte d'aspersion
jaune ; armoire et fût au sud."""
import geo
from organes import Y
import impr_commun as IC


def build(S, k):
    IC.raccord(k, 0.34, 0.15)
    z0 = k.socle(3, 0.38, 0.13, "structure", "capot", 0.115)
    # bac d'attaque au nord (cuve horizontale) et passerelle de visite
    k.cuve_h("capot", (0.05, Y(0.78), 0.62), 0.42, 1.7, "x", 2, "structure", True, "structure")
    k.tuyau("tuyau", [(0.0, Y(1.15), 0.34), (0.0, Y(1.0), 0.34), (0.0, Y(1.0), 0.75)], 0.08, 0.1, False)
    k.vanne((0.0, Y(1.12), 0.34), (0, 1, 0), 0.06, "tuyau", "rouge")
    for x in (-0.55, 0.55):                                             # trous d'homme et évents
        k.put("structure", geo.tour([(1.02, 0.11), (1.1, 0.11), (1.1, 0.0)], 16, "z", (x, Y(0.78), 0.0)))
        k.boulons_cercle((x, Y(0.78), 1.1), 0.085, 6, (0, 0, 1), 0.016)
    k.put("tuyau", geo.tour([(1.0, 0.04), (1.35, 0.04), (1.37, 0.07), (1.42, 0.07)], 10, "z", (0.95, Y(0.9), 0.0)))
    k.caillebotis(-1.35, -0.85, Y(0.25), Y(1.35), 0.95)
    k.garde_corps([(-1.35, Y(0.27), 0.95), (-0.86, Y(0.27), 0.95)], 0.36)
    k.echelle(-1.1, Y(0.25) - 0.04, z0, 0.95, cage=False)
    for x in (-1.32, -0.88):
        k.box("structure", (x, Y(0.3), 0.5), (0.05, 0.05, 0.9))
    # convoyeur de cartes est-ouest et portique d'impression
    IC.convoyeur(k, -1.4, 1.4, -0.25, 0.42, 0.44, (-1.05, -0.35, 0.45, 1.1))
    for dy in (-0.33, 0.33):
        k.box("structure", (-0.35, Y(-0.25) + dy, 0.55), (0.09, 0.09, 1.0))
        k.panneau_danger((-0.35, Y(-0.25) + dy - 0.05, 0.25), 0.09, 0.3)
    k.box("structure", (-0.35, Y(-0.25), 1.07), (0.14, 0.82, 0.1))
    k.caisson("capot2", -0.55, -0.15, Y(-0.25) - 0.16, Y(-0.25) + 0.12, 0.72, 1.0, pas=0.09)   # tête d'impression
    k.voyant((-0.28, Y(-0.25) - 0.17, 0.92), "feu", 0.026, (0, -1, 0))
    k.cable((-0.45, Y(-0.25), 1.12), (-0.9, Y(0.3), 0.95), 0.12, 0.018)
    k.cable((-0.25, Y(-0.25), 1.12), (0.2, Y(0.35), 0.95), 0.1, 0.018, "rouge")
    # hotte d'aspersion jaune sur la moitié est du convoyeur, hublot
    IC.capot_jaune(k, 0.15, 1.4, -0.62, 0.12, 0.5, 0.92)
    k.grille((0.75, Y(-0.62), 0.72), 0.5, 0.22)
    k.put("verre", geo.boite((0.32, Y(-0.62) - 0.012, 0.72), (0.2, 0.02, 0.14)))
    k.put("tuyau", geo.tour([(0.92, 0.08), (1.3, 0.08), (1.32, 0.11), (1.38, 0.11)], 12, "z", (1.15, Y(-0.25), 0.0)))
    # armoire, fût, bac de rétention
    k.armoire((1.0, Y(-1.15), z0), (0.7, 0.3, 0.55), voyants=(("feu", 0.0), ("feu2", 0.08)))
    IC.fut(k, -1.1, -1.05, z0, 0.16, 0.48, "rouge")
    IC.fut(k, -0.7, -1.15, z0, 0.16, 0.48, "capot2")
    k.box("structure", (-0.9, Y(-1.1), z0 + 0.02), (0.85, 0.45, 0.04))
    k.cable((0.7, Y(-1.15), z0 + 0.55), (0.6, Y(-0.25), 0.45), 0.05, 0.018)
