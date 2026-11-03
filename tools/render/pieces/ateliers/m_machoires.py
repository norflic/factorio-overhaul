"""BROYEUR À MÂCHOIRES fo-jaw-crusher (3×3, âge 6, électrique) : bâti d'acier trapu, gueule pleine de roches, arbre excentrique
nord-sud porté par DEUX GRANDS VOLANTS (sud : volant d'inertie ; nord : poulie à gorges menée par le moteur, courroies
trapézoïdales), bielle (mâchoire mobile) à l'est, goulotte de gravier au sud-ouest. a : référence ; b : alimentateur incliné
et passerelle ; c : bâti peint en jaune d'engin et convoyeur de sortie.
"""
import math

import communs as CO
import geo as G

Y = CO.Y
TAU = 2.0 * math.pi


def machoires(S, k, v):
    M = k.M = CO.matieres(S)
    corps = "jaune" if v == "c" else "car"
    vol = "rouge_vif" if v == "c" else "fonte"
    k.sol("noir", 3)
    # socles de béton
    for yy in (Y(-0.62), Y(0.62)):
        k.caisson("beton", -0.25, yy, 0.0, 1.7, Y(0.5), 0.14, 0.03)
    k.caisson("beton", -1.05, Y(1.05), 0.0, 0.7, Y(0.75), 0.22, 0.03)
    # bâti : joue ouest (mâchoire fixe), joues nord et sud, bloc est
    zt = 1.12
    xw0, xw1 = -1.0, -0.42
    k.caisson(corps, (xw0 + xw1) / 2.0, Y(0.0), 0.14, xw1 - xw0, Y(1.75), zt - 0.14, 0.05)
    for i in range(5):                                                       # nervures de la joue fixe
        yy = Y(-0.7 + i * 0.35)
        k.poly(corps, [(xw0 - 0.07, yy - 0.035), (xw0, yy - 0.035), (xw0, yy + 0.035), (xw0 - 0.07, yy + 0.035)], 0.14, zt - 0.1)
    for sg in (-1, 1):
        yc = Y(sg * 0.8)
        k.caisson(corps, 0.0, yc, 0.14, 1.2, Y(0.16), zt + 0.08 - 0.14, 0.03)
        k.bz("fonte", 0.55, yc, zt - 0.05, 0.3, Y(0.2), 0.38)                  # paliers de l'arbre
        k.boulons_rond("riv", 0.55, yc, zt + 0.33, 0.1, 6, 0.014)
    yS = Y(-0.8) - Y(0.08)
    k.rivets_ligne("riv", (-0.55, yS - 0.006, zt - 0.03), (0.55, yS - 0.006, zt - 0.03), 9)
    k.chevrons(0.0, yS - 0.002, zt - 0.14, 1.05, 0.09)
    k.plaque("plaque", -0.35, yS, 0.55, 0.22, 0.12)
    # chambre : plaques de mâchoire striées et roches
    k.b("noyau", (-0.12, 0.0, zt - 0.2), (0.62, Y(1.42), 0.3))
    for i in range(9):
        yy = Y(-0.62 + i * 0.155)
        k.b("acier", (-0.38, yy, zt - 0.08), (0.06, 0.06, 0.2))
    k.roches("pierre", -0.38, 0.18, Y(-0.62), Y(0.62), zt + 0.02, 34, 0.06, 0.12, mats=("pierre", "pierre2", "pierre"))
    # bielle (mâchoire mobile) : grosse pièce de fonte suspendue à l'arbre, plaque de genouillère, tirant et ressort
    a = TAU * k.phase
    dz = 0.03 * math.sin(a)
    k.mobile(True)
    k.caisson("fonte", 0.42, Y(0.0), 0.3 + dz, 0.3, Y(1.25), zt - 0.12, 0.05)
    k.axe("fonte", (0.55, Y(-0.62), zt + 0.12 + dz), (0.55, Y(0.62), zt + 0.12 + dz), 0.17, 22)
    k.mobile(False)
    k.axe("acier_clair", (0.55, Y(-1.3), zt + 0.12), (0.55, Y(1.3), zt + 0.12), 0.07, 16)
    k.bz(corps, 0.95, Y(0.0), 0.14, 0.24, Y(0.5), 0.5)
    k.axe("acier_clair", (0.62, Y(0.0), 0.4), (1.0, Y(0.0), 0.4), 0.03, 8)
    k.put("acier", G.tube([(0.7, Y(0.0), 0.4), (0.92, Y(0.0), 0.4)], 0.07, 14,
                                         rfun=lambda s, i: 0.06 * (1.0 + 0.25 * math.sin(s / 0.035 * TAU))))
    # volants : sud (inertie, face à la caméra) et nord (poulie à gorges)
    zc = zt + 0.12
    R = 0.72
    k.volant((0.55, Y(-1.2), zc), R, "y", larg=0.16, rayons=6, jante=vol, ph=k.phase, ep=0.14)
    k.volant((0.55, Y(1.18), zc), R * 0.95, "y", larg=0.2, rayons=5, jante=vol, ph=k.phase, ep=0.12, repere=None)
    k.mobile(True)
    for i in range(4):                                                       # gorges et courroies trapézoïdales
        yy = Y(1.18) - 0.07 + i * 0.045
        k.put("caoutchouc", G.tour([(-0.012, R * 0.95 - 0.01), (-0.012, R * 0.95 + 0.012), (0.012, R * 0.95 + 0.012),
                                                    (0.012, R * 0.95 - 0.01)], 44, "y", (0.55, yy, zc)))
    k.mobile(False)
    # moteur au nord-ouest, poulie motrice, courroies
    xm, zm = -1.05, 0.22
    k.moteur("car2", xm, Y(0.95), zm, 0.62, 0.2, axe="y")
    k.cyl("noir", xm, Y(0.95) - 0.2, zm + 0.2, zm + 0.42, 0.05, 10)
    k.axe("acier_clair", (xm, Y(1.18) - 0.1, zm + 0.2), (xm, Y(1.18) + 0.1, zm + 0.2), 0.11, 18)
    for i in range(4):
        yy = Y(1.18) - 0.07 + i * 0.045
        k.courroie("caoutchouc", (xm, yy, zm + 0.2), 0.11, (0.55, yy, zc), R * 0.95, (0.0, 1.0, 0.0), larg=0.03, e=0.02)
    k.armoire("car2", -1.2, Y(0.55) - 0.08, 0.22, 0.38, 0.5, lampe="voyant_v")
    # goulotte de sortie et tas de gravier au sud-ouest
    if v == "c":
        k.caisson("acier", -0.55, Y(-1.15), 0.12, 0.42, Y(0.75), 0.16, 0.02)
        k.b("caoutchouc", (-0.55, Y(-1.15), 0.29), (0.34, Y(0.75), 0.02))
        k.roches("gravier", -0.7, -0.4, Y(-1.45), Y(-0.85), 0.32, 14, 0.025, 0.04)
        for yy in (Y(-1.45), Y(-0.85)):
            k.axe("acier_clair", (-0.78, yy, 0.22), (-0.32, yy, 0.22), 0.06, 12)
    else:
        k.b("acier", (-0.6, Y(-0.98), 0.32), (0.4, 0.5, 0.03), rx=math.radians(30))
        for sx in (-1, 1):
            k.b("acier", (-0.6 + sx * 0.2, Y(-0.98), 0.38), (0.03, 0.5, 0.14), rx=math.radians(30))
        k.tas("gravier", -0.6, Y(-1.28), 0.42, 0.28, 0.18)
        k.roches("gravier", -0.9, -0.3, Y(-1.42), Y(-1.12), 0.06, 16, 0.025, 0.04)
    # trémie évasée sur la gueule
    if v == "b":
        k.tremie("acier", -0.12, Y(0.0), zt + 0.02, zt + 0.45, 0.7, Y(1.45), 1.15, Y(1.75))
        k.roches("pierre", -0.6, 0.35, Y(-0.7), Y(0.75), zt + 0.36, 30, 0.06, 0.11, mats=("pierre", "pierre2"))
        # alimentateur vibrant incliné depuis le nord-ouest, passerelle et échelle
        k.b("car", (-0.55, Y(1.15), zt + 0.62), (0.55, Y(0.9), 0.06), rx=math.radians(12))
        for sx in (-1, 1):
            k.b("car", (-0.55 + sx * 0.28, Y(1.15), zt + 0.7), (0.04, Y(0.92), 0.16), rx=math.radians(12))
            k.bz("acier", -0.55 + sx * 0.25, Y(1.4), 0.22, 0.06, 0.06, zt + 0.5)
        k.roches("pierre", -0.75, -0.35, Y(0.85), Y(1.4), zt + 0.72, 12, 0.04, 0.07)
        k.bz("acier", 1.22, Y(-0.2), 0.14, 0.38, Y(1.6), 0.04)
        k.bz("chevron", 1.22, Y(-0.2), zt + 0.4, 0.4, Y(1.6), 0.03)
        for yy in (Y(-0.95), Y(0.55)):
            k.bz("acier", 1.38, yy, 0.14, 0.05, 0.05, zt + 0.3)
        k.rambarde("acier", [(1.4, Y(-0.95), zt + 0.43), (1.4, Y(0.55), zt + 0.43)], 0.3, 0.4)
        k.echelle("acier", 1.25, Y(-1.05), 0.14, zt + 0.43)
    else:
        k.tremie(corps if v == "c" else "acier", -0.12, Y(0.0), zt + 0.02, zt + 0.3, 0.7, Y(1.45), 1.0, Y(1.6))
        k.roches("pierre", -0.5, 0.25, Y(-0.65), Y(0.7), zt + 0.22, 22, 0.06, 0.11, mats=("pierre", "pierre2"))
    # gyrophare ambre sur mât et projecteur dans la gueule
    k.cyl("acier", 1.2, Y(1.0), 0.14, 2.2, 0.035, 10)
    k.cyl("noir", 1.2, Y(1.0), 2.2, 2.26, 0.07, 14)
    k.rev("gyro", 1.2, Y(1.0), [(2.26, 0.06), (2.36, 0.06), (2.42, 0.03), (2.44, 0.0)], 14)
    CO.halo(S, k, (1.2, Y(1.0) - 0.12, 2.34), (1.0, 0.55, 0.1), 90.0, r=(0.7, 1.8))
    k.axe("acier", (1.2, Y(1.0), 1.95), (0.6, Y(0.4), 2.0), 0.022, 8)
    k.axe("noir", (0.62, Y(0.42), 2.02), (0.5, Y(0.3), 1.94), 0.08, 14)
    k.put("projecteur", G.oriente(G.tour([(0.0, 0.065), (0.01, 0.06), (0.02, 0.0)], 14, "z"),
                                                   (0.48, Y(0.28), 1.93), (-0.4, -0.55, -0.6)))
