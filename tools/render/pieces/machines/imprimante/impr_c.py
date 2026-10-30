"""Essai C de l'imprimante : FOUR DE REFUSION. Tunnel caréné jaune est-ouest (4 zones de chauffe, regards orange
au sud), convoyeur qui en sort des deux côtés, hotte et cheminée d'extraction au nord-est ; cuve d'azote
horizontale au nord sur le raccord ; pupitre au sud."""
import geo
from organes import Y
import impr_commun as IC


def build(S, k):
    IC.raccord(k, 0.34, 0.15)
    z0 = k.socle(3, 0.38, 0.13, "structure", "capot", 0.115)
    yt0, yt1 = -0.6, 0.35
    # convoyeur traversant, cartes à l'entrée et à la sortie
    IC.convoyeur(k, -1.45, 1.45, (yt0 + yt1) / 2, 0.4, 0.4, (-1.25, 1.25))
    # tunnel : socle noir, capot jaune en 4 zones, regards de chauffe
    k.caisson("structure", -1.0, 1.0, Y(yt0), Y(yt1), z0, 0.36, pas=0.1)
    zs = (-1.0, -0.5, 0.0, 0.5, 1.0)
    for i in range(4):
        x0, x1 = zs[i] + 0.02, zs[i + 1] - 0.02
        IC.capot_jaune(k, x0, x1, yt0 - 0.02, yt1 + 0.02, 0.36, 0.86, bandes=False)
        k.box("structure", ((x0 + x1) / 2, Y(yt0) - 0.03, 0.6), (0.32, 0.02, 0.14))
        k.put("feu", geo.boite(((x0 + x1) / 2, Y(yt0) - 0.042, 0.6), (0.24, 0.012, 0.05)))
        k.box("trim", ((x0 + x1) / 2, Y((yt0 + yt1) / 2), 0.9), (0.34, 0.5, 0.06), petite=True)   # trappe de zone
        k.put("tuyau", geo.tour([(0.9, 0.05), (1.02, 0.05)], 10, "z", ((x0 + x1) / 2, Y(yt1) - 0.1, 0.0), cap1=True),
              True)
    for x in zs:
        k.box("structure", (x, Y(yt0) - 0.02, 0.62), (0.05, 0.04, 0.52), petite=True)
    k.panneau_danger((0.0, Y(yt0) - 0.03, 0.42), 2.0, 0.06)
    k.halo(S, (0.0, Y(yt0) - 0.25, 0.6), (1.0, 0.45, 0.12), 6.0, 0.3)
    # hotte et cheminée (nord-est)
    k.tuyau("tuyau", [(-0.75, Y(yt1) - 0.1, 1.02), (-0.75, Y(0.6), 1.05), (1.0, Y(0.6), 1.05)], 0.06, 0.08, True)
    k.put("tuyau", geo.tour([(z0, 0.15), (1.75, 0.13), (1.78, 0.17), (1.84, 0.17)], 16, "z", (1.1, Y(0.75), 0.0)))
    k.put("structure", geo.tour([(1.92, 0.22), (1.96, 0.24), (2.0, 0.0)], 16, "z", (1.1, Y(0.75), 0.0)))   # chapeau
    for z in (0.6, 1.2):
        k.put("structure", geo.tour([(z - 0.03, 0.17), (z + 0.03, 0.17)], 16, "z", (1.1, Y(0.75), 0.0), cap0=True,
                                    cap1=True))
    k.put("structure", geo.tube([(1.1, Y(0.75), 1.88), (1.1, Y(0.75), 1.96)], 0.03, 6))
    # cuve d'azote au nord-ouest sur le raccord
    k.cuve_h("galva", (-0.55, Y(1.0), 0.45), 0.27, 0.9, "x", 2, "structure", True, "structure")
    k.tuyau("tuyau", [(0.0, Y(1.15), 0.34), (-0.1, Y(1.15), 0.34), (-0.1, Y(1.0), 0.34)], 0.07, 0.06, False)
    k.vanne((0.05, Y(1.15), 0.34), (1, 0, 0), 0.05, "tuyau", "rouge")
    k.tuyau("tuyau", [(-0.55, Y(1.0), 0.72), (-0.55, Y(0.6), 0.72), (-0.55, Y(0.42), 0.86)], 0.035, 0.06, False)
    # pupitre et armoire au sud
    k.armoire((0.8, Y(-1.2), z0), (0.8, 0.28, 0.5), voyants=(("feu", 0.0), ("feu2", 0.08), ("feu", 0.16)))
    k.box("structure", (-0.8, Y(-1.15), 0.42), (0.5, 0.3, 0.05), rx=0.4)
    k.box("verre", (-0.8, Y(-1.15) + 0.0, 0.45), (0.36, 0.2, 0.02), rx=0.4)
    k.box("structure", (-0.8, Y(-1.15), 0.2), (0.12, 0.12, 0.38))
