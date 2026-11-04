"""MACHINES AMONT du calcul (lot CALCUL-DESIGN, 01/11) : four à arc à 3 électrodes (âge 6, choix A du DC), four de frittage
rotatif (âge 5, choix A du DC), imprimante de circuits (âge 4). Dessus et face sud seulement comptent.
"""
import math

import geo as G
import organes as O
import palettes as P

D = O.D


def arc(S, k):
    """FOUR À ARC : cuve ronde basculante, voûte en céramique, 3 électrodes de graphite, bras de cuivre, portique et
    transformateur à isolateurs. Lumière : les 3 trous de voûte et la goulotte de coulée, chaude vers le bas."""
    M = k.M = P.matieres(S, "elec")
    M["feu"] = P.lueur(S, "c_feu", (1.0, 0.56, 0.14), 5.0, 0.55, grad=(1.45, 1.9, 1.0, 0.25), part=0.6, echelle=18.0)
    M["coulee"] = P.lueur(S, "c_coulee", (1.0, 0.36, 0.05), 2.2, 0.45, part=0.85, echelle=10.0)
    cx, cy = -0.42, -0.35
    # sol : plancher d'acier en deux pans, rails du berceau
    k.sol("acier", 4, h=0.07, ch=0.26)
    k.bz("car2", -0.55, -2.1, 0.07, 2.5, 0.42, 0.11)
    for x in (-1.45, 0.65):
        k.bz("chevron", x, -2.28, 0.18, 0.3, 0.06, 0.012)
    # berceau basculant : deux secteurs dentés
    for sy in (-1, 1):
        y = cy + sy * 1.05
        k.b("noir", (cx, y, 0.26), (1.9, 0.12, 0.28))
        k.b("acier_clair", (cx, y, 0.42), (1.75, 0.1, 0.05))
    # cuve : fond bombé, panneaux refroidis, ceinture
    r = 1.22
    k.rev("car", cx, cy, [(0.28, 0.5), (0.36, 0.86), (0.5, 1.1), (0.7, r), (1.3, r + 0.02)], 40)
    for i in range(22):                       # côtes verticales des panneaux refroidis (face sud utile)
        a = math.pi + math.pi * i / 21.0
        x, y = cx + (r + 0.012) * math.cos(a), cy + (r + 0.012) * math.sin(a)
        k.axe("acier", (x, y, 0.72), (x, y, 1.3), 0.021, 6)
    k.cerclages("acier_clair", cx, cy, (0.72, 1.3), r, e=0.035, h=0.045, segs=40)
    k.rev("rouille", cx, cy, [(1.3, r + 0.03), (1.36, r + 0.06), (1.46, r + 0.06), (1.46, r - 0.1)], 40)
    # voûte en céramique, en coupole, couronne boulonnée
    k.rev("car2", cx, cy, [(1.46, r - 0.08), (1.52, r - 0.18), (1.72, 0.74), (1.86, 0.48), (1.9, 0.3)], 40)
    k.tore("noir", cx, cy, 1.5, r - 0.1, 0.022, 44, 6)
    k.boulons_rond("riv", cx, cy, 1.55, r - 0.14, 26, 0.018)
    # évent d'aspiration : gros coude de fumées vers le nord-ouest
    k.tuyau("rouille", [(cx - 0.65, cy + 0.42, 1.65), (cx - 0.65, cy + 0.42, 2.02), (cx - 0.65, cy + 1.45, 2.02), (cx - 0.65, 2.2, 1.2), (cx - 0.65, 2.3, 0.08)],
            r=0.2, coude=0.28, brides=[(cx - 0.65, cy + 0.42, 1.8), (cx - 0.65, cy + 1.1, 2.02), (cx - 0.65, 2.25, 0.8)], bride_mat="acier")
    # 3 électrodes : trous lumineux, graphite, colliers de cuivre, bras
    Ee = [(cx + 0.36 * math.cos(a), cy + 0.36 * math.sin(a)) for a in (math.radians(210), math.radians(330), math.radians(90))]
    Z_BRAS = (2.62, 2.78, 2.46)
    for i, (x, y) in enumerate(Ee):
        k.tore("feu", x, y, 1.885, 0.165, 0.042, 22, 8)
        k.rev("ceramique", x, y, [(1.82, 0.215), (1.97, 0.175), (1.97, 0.14)], 20, cap=False)
        k.cyl("graphite", x, y, 1.84, 3.2 + i * 0.1, 0.122, 18)
        for z in (2.2, 2.68, 3.06):
            k.cerclages("noyau", x, y, (z + i * 0.03,), 0.122, e=0.006, h=0.008, segs=18)
        z = Z_BRAS[i]
        k.rev("cuivre", x, y, [(z - 0.1, 0.17), (z + 0.1, 0.17)], 18)
        k.rev("acier", x, y, [(z - 0.11, 0.176), (z - 0.08, 0.176)], 18, cap=False)
        for sg in (-1, 1):                    # bras de cuivre : deux tubes jumelés vers le portique
            k.axe("cuivre", (x + 0.1, y + sg * 0.065, z), (1.38, y * 0.28 + 0.3 + sg * 0.065, z), 0.05, 12)
        k.axe("noir", (x + 0.62, y * 0.72 + 0.1, z - 0.07), (x + 0.62, y * 0.72 + 0.1, z + 0.07), 0.06, 8)
    # portique des bras : 2 poteaux à glissière, tête, vérins
    for y in (-0.15, 0.85):
        k.bz("car", 1.48, y, 0.07, 0.24, 0.24, 3.05)
        k.bz("noir", 1.34, y, 0.4, 0.05, 0.14, 2.5)
        k.rivets_ligne("riv", (1.48, y - 0.13, 0.25), (1.48, y - 0.13, 3.0), 12, r=0.012)
    k.caisson("car", 1.48, 0.35, 3.12, 0.42, 1.52, 0.2, 0.03)
    for z, y0 in ((2.62, 0.15), (2.78, 0.35), (2.46, 0.55)):
        k.bz("acier", 1.44, y0, z - 0.2, 0.22, 0.2, 0.38)
    # câbles souples vers le transformateur : grosses chaînettes noires
    for i, z in enumerate((2.62, 2.78, 2.46)):
        for j in (-0.07, 0.07):
            k.cable("caoutchouc", (1.58, 0.2 + i * 0.2 + j, z), (1.72, 2.05 + j, 1.5 + i * 0.12), fl=0.42, r=0.033, segs=10)
    # transformateur au nord-est : cuve, ailettes, 3 traversées en céramique
    k.caisson("car", 0.95, 2.1, 0.07, 1.3, 1.1, 1.05, 0.05)
    for i in range(14):
        k.bz("noir", 0.34 + i * 0.094, 1.52, 0.16, 0.05, 0.1, 0.78)
    for i in range(3):
        x = 0.55 + i * 0.42
        k.rev("ceramique", x, 2.2, [(1.12, 0.11), (1.2, 0.11), (1.2, 0.085), (1.26, 0.135), (1.32, 0.085), (1.38, 0.125), (1.44, 0.08), (1.5, 0.11), (1.58, 0.04)], 16)
        k.cyl("cuivre", x, 2.2, 1.58, 1.68, 0.035, 10)
    k.armoire("car2", -1.55, -2.32, 0.18, 0.62, 0.62, lampe="voyant")
    # goulotte de coulée au sud, métal en fusion
    k.bz("rouille", cx + 0.2, cy - r - 0.3, 0.56, 0.42, 0.62, 0.1)
    k.bz("acier", cx + 0.2 - 0.22, cy - r - 0.3, 0.56, 0.05, 0.66, 0.2)
    k.bz("acier", cx + 0.2 + 0.22, cy - r - 0.3, 0.56, 0.05, 0.66, 0.2)
    k.bz("coulee", cx + 0.2, cy - r - 0.3, 0.65, 0.34, 0.56, 0.012)
    k.voyant("voyant", -1.72, -2.34, 0.6, 0.024)
    k.tuyau("bleu", [(-1.82, -0.7, 0.14), (-1.82, 0.6, 0.14), (-1.25, 1.05, 0.14)], r=0.06, coude=0.2)
    k.vanne("acier", "rouge", (-1.82, -0.1, 0.2), 0.05)
    k.echelle("acier", 1.2, -1.6, 0.07, 1.25)


def fritt(S, k):
    """FOUR DE FRITTAGE ROTATIF : tambour incliné, bandages, couronne dentée et pignon, capot de brûleur à la fente
    orange (est, bas), trémie d'alimentation (ouest, haut). Le tambour tourne (partie mobile : tôles et cordons)."""
    M = k.M = P.matieres(S, "volcan")
    M["braise"] = P.lueur(S, "c_braise", (1.0, 0.3, 0.04), 1.9, 0.4, part=0.85, echelle=14.0, grad=(0.5, 0.95, 1.0, 0.2))
    M["chaud"] = P.lueur(S, "c_chaud", (1.0, 0.2, 0.03), 1.6, 0.35, part=0.8, echelle=11.0)
    TILT = 0.085
    x0, x1 = -1.08, 1.02
    y0 = -0.32
    def zc(x):
        return 1.0 - (x + 0.1) * TILT
    def pt(x, dy=0.0, dz=0.0):
        return (x, y0 + dy, zc(x) + dz)
    R = 0.56
    k.sol("noir", 3, h=0.05, ch=0.2)
    # socles de béton réfractaire et rouleaux
    for x in (-0.68, 0.48):
        k.caisson("car2", x, y0, 0.05, 0.56, 1.5, 0.3, 0.03)
        for sg in (-1, 1):
            y = y0 + sg * 0.42
            k.axe("acier_clair", (x - 0.2, y, zc(x) - R - 0.1), (x + 0.2, y, zc(x) - R - 0.1), 0.09, 16)
            k.bz("acier", x, y, 0.35, 0.34, 0.2, zc(x) - R - 0.35)
    # tambour : corps fixe sombre, tôles mobiles autour
    def virole(mat, xa, xb, r, segs=36):
        n = max(2, int((xb - xa) / 0.2))
        pts = [pt(xa + (xb - xa) * i / n) for i in range(n + 1)]
        k.put(mat, G.tube(pts, r, segs))
    virole("rouille", x0, x1, R)
    virole("chaud", 0.58, x1 - 0.06, R + 0.005)   # zone chaude près du brûleur : tôle rougie, faible, en dégradé de bruit
    k.mobile(True)
    a0 = k.phase * math.pi * 2 / 10
    for i in range(10):                         # cordons longitudinaux : c'est eux qu'on voit tourner
        a = a0 + math.pi * 2 * i / 10
        dy, dz = (R + 0.012) * math.cos(a), (R + 0.012) * math.sin(a)
        k.axe("acier", pt(x0 + 0.08, dy, dz), pt(0.54, dy, dz), 0.016, 6)
    for x in (-0.68, 0.48):                     # bandages : anneaux de roulement
        pts = [pt(x - 0.09), pt(x + 0.09)]
        k.put("acier_clair", G.tube(pts, R + 0.08, 36))
    xg = -0.1                                   # couronne dentée
    k.put("noir", G.tube([pt(xg - 0.1), pt(xg + 0.1)], R + 0.12, 40))
    for i in range(30):
        a = a0 * 3 + math.pi * 2 * i / 30
        dy, dz = (R + 0.135) * math.cos(a), (R + 0.135) * math.sin(a)
        k.axe("acier_clair", pt(xg - 0.1, dy, dz), pt(xg + 0.1, dy, dz), 0.024, 5)
    k.mobile(False)
    # motoréducteur au sud de la couronne
    k.caisson("rouille", xg, y0 - R - 0.5, 0.05, 0.42, 0.5, 0.58, 0.04)
    k.moteur("car2", xg + 0.46, y0 - R - 0.5, 0.2, 0.5, 0.15)
    k.axe("acier_clair", (xg - 0.08, y0 - R - 0.3, zc(xg) - 0.35), (xg + 0.08, y0 - R - 0.3, zc(xg) - 0.35), 0.1, 14)
    # capot du brûleur (bas, est) : grosse hotte de tungstène, fente en braise, brûleur et tuyaux
    hx = x1 + 0.16
    k.caisson("car", hx, y0, 0.05, 0.4, 1.7, 1.5, 0.08)
    k.b("braise", (hx - 0.05, y0 - 0.86, 0.72), (0.2, 0.012, 0.42))
    for i in range(7):
        k.b("noir", (hx - 0.05, y0 - 0.875, 0.53 + i * 0.065), (0.24, 0.012, 0.028))
    k.axe("acier_clair", (hx + 0.3, y0, 0.8), (hx + 0.02, y0, 0.8), 0.13, 16)
    k.tuyau("rouge", [(hx + 0.08, y0 - 0.5, 1.56), (hx + 0.08, y0 + 0.4, 1.56), (hx + 0.08, 1.9, 1.1), (hx + 0.08, 2.0, 0.05)], r=0.055, coude=0.2)
    # hotte d'alimentation (haut, ouest) : trémie à crible et goulotte
    tx = x0 - 0.08
    k.caisson("car2", tx, y0, 0.05, 0.3, 1.5, 1.72, 0.04)
    k.poly("rouille", [(tx - 0.26, y0 - 0.55), (tx + 0.4, y0 - 0.55), (tx + 0.4, y0 + 0.5), (tx - 0.26, y0 + 0.5)], 1.9, 2.42, 1.0)
    k.poly("car2", [(tx - 0.05, y0 - 0.12), (tx + 0.07, y0 - 0.12), (tx + 0.07, y0 + 0.1), (tx - 0.05, y0 + 0.1)], 1.5, 1.9, 1.0)
    k.b("noyau", (tx + 0.07, y0, 2.43), (0.54, 0.92, 0.02))
    for i in range(7):
        k.b("acier", (tx + 0.07, y0 - 0.4 + i * 0.133, 2.45), (0.62, 0.02, 0.022))
    k.chevrons(tx + 0.07, y0 - 0.56, 2.32, 0.62, 0.09)
    # fumées : conduite au nord, cheminée courte
    k.tuyau("rouille", [(tx + 0.05, y0 + 0.75, 1.2), (tx + 0.05, 1.5, 1.2), (0.55, 1.5, 1.2), (0.55, 1.75, 1.2)], r=0.14, coude=0.2, bride_mat="acier")
    k.cuve("car2", 0.72, 1.62, 0.05, 2.5, 0.28, 0.2)
    k.cerclages("acier", 0.72, 1.62, (0.8, 1.5, 2.1), 0.28)
    k.rev("noyau", 0.72, 1.62, [(2.4, 0.2), (2.52, 0.2)], 16)
    # devant : barrière, coffret et voyants
    k.armoire("car2", -1.1, -2.03, 0.05, 0.54, 0.6, lampe="voyant_o")
    k.rambarde("acier", [(0.45, -2.02, 0.05), (1.38, -2.02, 0.05)], 0.28, 0.46)
    k.bz("chevron", 0.92, -2.0, 0.05, 0.95, 0.02, 0.05)


def impr(S, k):
    """IMPRIMANTE DE CIRCUITS (âge 4, tôle jaune délavée) : tapis est-ouest où passent de grandes cartes vertes à pistes de
    cuivre, portique de sérigraphie avec son cadre et sa raclette, fûts d'encre et étuve à fente orange."""
    M = k.M = P.matieres(S, "petrole")
    M["etuve"] = P.lueur(S, "c_etuve", (1.0, 0.45, 0.07), 3.5, 0.5, part=0.5, echelle=26.0)
    k.sol("acier", 3, h=0.05, ch=0.18)
    # tapis : châssis, rouleaux, bande
    ty = -0.72
    k.caisson("car", 0.0, ty, 0.05, 2.9, 1.5, 0.34, 0.03)
    k.bz("noyau", 0.0, ty, 0.38, 2.8, 1.25, 0.02)
    for i in range(10):
        k.axe("acier_clair", (-1.38 + i * 0.306, ty - 0.68, 0.4), (-1.38 + i * 0.306, ty + 0.68, 0.4), 0.018, 6)
    for x in (-1.45, 1.45):
        k.axe("acier", (x, ty - 0.75, 0.3), (x, ty + 0.75, 0.3), 0.12, 16)
    k.persiennes("car2", -0.9, ty - 0.76, 0.1, 0.9, 0.24, 5)
    k.chevrons(0.72, ty - 0.76, 0.21, 1.1, 0.1)
    # deux grandes cartes vertes, le signe de la machine
    def carte(x, y, lx, ly):
        k.bz("vert", x, y, 0.42, lx, ly, 0.03)
        for j in range(5):
            yy = y - ly / 2.0 + ly * (j + 0.5) / 5
            k.b("cuivre", (x - lx * 0.08, yy, 0.455), (lx * 0.62, 0.028, 0.008))
            k.b("cuivre", (x + lx * 0.28, yy + 0.05, 0.455), (0.03, 0.12, 0.008))
        for j in range(2):
            k.bz("noir", x - lx * 0.28 + j * lx * 0.4, y + ly * 0.2 - j * 0.3, 0.45, 0.14, 0.14, 0.05)
        k.b("or", (x, y - ly / 2.0 + 0.03, 0.452), (lx * 0.8, 0.03, 0.006))
    carte(-0.82, ty, 0.84, 1.08)
    carte(0.98, ty, 0.84, 1.08)
    # portique : 2 montants, traverse, cadre de sérigraphie, raclette
    for sg in (-1, 1):
        k.bz("car2", 0.08 + sg * 0.53, ty + 0.0, 0.39, 0.15, 1.5, 1.08)
        k.bz("noir", 0.08 + sg * 0.53, ty - 0.76, 0.5, 0.1, 0.03, 0.82)
    k.caisson("car", 0.08, ty + 0.05, 1.42, 1.28, 1.32, 0.34, 0.06)
    k.persiennes("acier", 0.3, ty - 0.62, 1.47, 0.62, 0.22, 4)
    k.plaque("plaque", -0.3, ty - 0.62, 1.6, 0.24, 0.12)
    k.voyant("voyant", -0.3, ty - 0.63, 1.53, 0.02)
    k.b("acier_clair", (0.08, ty, 0.78), (0.98, 1.3, 0.05))         # cadre
    k.b("verre_ambre", (0.08, ty, 0.81), (0.84, 1.12, 0.012))
    k.mobile(True)
    yr = ty - 0.45 + 0.9 * (0.5 - 0.5 * math.cos(k.phase * 2 * math.pi))
    k.b("jaune", (0.08, yr, 0.92), (0.92, 0.1, 0.17))              # raclette, va-et-vient
    k.b("caoutchouc", (0.08, yr, 0.82), (0.86, 0.04, 0.06))
    k.mobile(False)
    # au nord : fûts d'encre et étuve
    ny = 0.95
    for x, h in ((-1.1, 1.0), (-0.62, 1.0)):
        k.cuve("car2", x, ny, 0.05, h, 0.24, 0.16, 22)
        k.cerclages("acier", x, ny, (0.35, 0.72), 0.24)
        k.cyl("rouge", x + 0.06, ny, h - 0.02, h + 0.04, 0.05, 10)
    k.tuyau("cuivre", [(-1.1, ny, 1.05), (-1.1, ny - 0.55, 1.2), (-0.32, ny - 0.55, 1.45)], r=0.022, coude=0.12, brides=[])
    k.caisson("car", 0.72, ny + 0.2, 0.05, 1.48, 1.1, 1.3, 0.07)
    k.b("etuve", (0.72, ny - 0.37, 0.72), (1.1, 0.012, 0.06))
    k.b("noir", (0.72, ny - 0.365, 0.72), (1.2, 0.01, 0.16))
    k.persiennes("acier", 0.72, ny - 0.36, 0.2, 1.2, 0.34, 5)
    k.ventilo(0.42, ny + 0.28, 1.45, 0.3, corps="car2")
    k.cyl("rouille", 1.12, ny + 0.32, 1.3, 1.85, 0.12, 14)
    k.rev("acier", 1.12, ny + 0.32, [(1.85, 0.16), (1.92, 0.16), (1.98, 0.03)], 14)
    k.cable("caoutchouc", (-0.45, ty + 0.65, 1.5), (0.06, ny + 0.2, 1.36), 0.12, 0.02)
    k.cable("caoutchouc", (-0.25, ty + 0.65, 1.5), (0.22, ny + 0.2, 1.36), 0.1, 0.016)
