"""TORCHÈRE fo-flare-stack (2×2, âge 4, électrique, UNE entrée de fluide au nord de la tuile ouest) : haute cheminée de
torchage. Le fluide en trop traverse un ballon séparateur et un pot de garde, monte dans la cheminée et brûle en flamme libre
au sommet (tête noircie, pare-vent, brûleurs pilotes). a : cheminée balisée rouge et blanc, haubanée ; b : cheminée dans un
pylône en treillis ; c : cheminée trapue à grosse tête, deux plateformes.
"""
import math

import communs as CO
import geo as G

Y = CO.Y
TAU = 2.0 * math.pi
HALO_W = 1300.0   # puissance (W) des sources de la flamme : À ÉTALONNER (pic au sol, CALIBRATION §4.2 ; cheminée : 300 W à z 2,2)


def _tete(k, x, y, z, r):
    """Tête de torchère : collerette, corps noirci, pare-vent en demi-couronne au vent (ouest), 3 brûleurs pilotes."""
    k.rev("suie", x, y, [(z - 0.12, r * 0.75), (z, r), (z + 0.32, r), (z + 0.34, r * 0.85), (z + 0.34, r * 0.6)], 22)
    k.rev("acier", x, y, [(z - 0.16, r * 1.05), (z - 0.12, r * 1.05)], 22, cap=False)
    k.put("suie", G.tour([(z + 0.02, r + 0.07), (z + 0.42, r + 0.12)], 20, "z", (x, y, 0.0), math.pi * 0.55, math.pi * 1.45))
    k.put("suie", G.tour([(z + 0.02, r + 0.09), (z + 0.42, r + 0.14)], 20, "z", (x, y, 0.0), math.pi * 0.55, math.pi * 1.45))
    for i in range(3):
        a = math.pi * 0.2 + TAU * i / 3.0
        px, py = x + (r + 0.04) * math.cos(a), y + (r + 0.04) * math.sin(a)
        k.axe("acier", (px, py, z - 0.6), (px, py, z + 0.36), 0.018, 6)
        k.cyl("suie", px, py, z + 0.34, z + 0.4, 0.03, 8)
    k.boulons_rond("riv", x, y, z - 0.11, r * 0.95, 10, 0.012)


def _pied(k, xs, ys, grand=False):
    """Pied : dalle, pot de garde vertical, ballon séparateur horizontal sur berceaux, conduite d'arrivée depuis la bride nord,
    armoire d'allumage et son voyant."""
    k.caisson("beton", -0.12, Y(-0.55), 0.0, 1.35, Y(0.42), 0.1, 0.03)
    k.rev("beton", xs, ys, [(0.0, 0.42), (0.1, 0.4), (0.1, 0.0)], 32)
    rb = 0.25 if grand else 0.21
    yb = Y(-0.55)
    k.echangeur(-0.12, yb, 0.1, 1.15 if grand else 1.0, rb, "car2", bride="acier", axe="x", cerc=3)
    k.cyl("acier", -0.55, yb, 0.1 + 2 * rb, 0.1 + 2 * rb + 0.1, 0.05, 10)          # trou d'homme
    k.vanne("acier", "rouge", (0.25, yb, 0.1 + 2 * rb), 0.04)
    k.cuve("car", xs, ys, 0.1, 0.95, 0.3, 0.3, 28)                                 # pot de garde
    k.cerclages("acier", xs, ys, (0.3, 0.7), 0.3, segs=28)
    k.tuyau("car2", [(0.4, yb, 0.1 + rb), (xs, yb, 0.1 + rb), (xs, ys - 0.28, 0.5)], r=0.07, coude=0.15, bride_mat="acier")
    # bride d'entrée au nord (tuile ouest) et conduite vers le ballon
    yn = Y(1.0)
    k.axe("acier", (-0.5, yn - 0.03, 0.3), (-0.5, yn + 0.04, 0.3), 0.12, 18)
    k.tuyau("car2", [(-0.5, yn, 0.3), (-0.5, Y(0.2), 0.3), (-0.75, Y(-0.1), 0.3), (-0.78, yb, 0.1 + rb)], r=0.07, coude=0.18,
            bride_mat="acier")
    k.vanne("acier", "jaune", (-0.5, Y(0.55), 0.3), 0.045)
    # armoire d'allumage
    k.caisson("car2", 0.72, Y(-0.82), 0.1, 0.36, Y(0.2), 0.62, 0.03)
    yf = Y(-0.82) - Y(0.1)
    k.voyant("voyant_v", 0.66, yf - 0.006, 0.6, 0.024)
    k.voyant("voyant_o", 0.78, yf - 0.006, 0.6, 0.024)
    k.plaque("plaque", 0.72, yf, 0.42, 0.18, 0.1)
    k.chevrons(0.72, yf - 0.002, 0.2, 0.3, 0.05)
    k.cable("caoutchouc", (0.72, Y(-0.75), 0.72), (xs + 0.12, ys - 0.1, 1.2), 0.15, 0.016)


def torchere(S, k, v):
    xs, ys = 0.22, Y(0.32)
    if v == "a":
        zt, rs = 4.05, 0.11
    elif v == "b":
        zt, rs = 4.25, 0.1
    else:
        zt, rs = 3.05, 0.15
    rt = rs * (1.55 if v != "c" else 1.6)
    CO.FLAMME_Z = (zt + 0.34, zt + 0.34 + (1.35 if v != "c" else 1.15))
    M = k.M = CO.matieres(S)
    k.sol("noir", 2)
    _pied(k, xs, ys, grand=(v == "c"))
    # cheminée
    if v == "a":
        k.bandes_cyl(("rouge_vif", "blanc"), xs, ys, 0.95, zt - 0.12, rs, 8, 22)
        for z in (1.6, 2.4, 3.2):
            k.cerclages("acier", xs, ys, (z,), rs, segs=22)
        # haubans vers trois ancrages
        zh = zt - 0.9
        for (ax, ay) in ((-0.88, Y(-0.85)), (0.92, Y(-0.88)), (-0.85, Y(0.9))):
            k.bz("beton", ax, ay, 0.0, 0.14, 0.14, 0.14)
            k.hauban("noir", (ax, ay, 0.14), (xs, ys, zh), 0.016, 0.06)
        k.rev("acier", xs, ys, [(zh - 0.03, rs + 0.03), (zh + 0.03, rs + 0.03)], 22, cap=False)
        # plateforme et crinoline
        zp = zt - 0.62
        k.rev("acier", xs, ys, [(zp, rs), (zp, 0.36), (zp + 0.025, 0.36), (zp + 0.025, rs)], 32)
        for i in range(12):
            a = TAU * i / 12
            k.axe("acier", (xs + 0.35 * math.cos(a), ys + 0.35 * math.sin(a), zp), (xs + 0.35 * math.cos(a), ys + 0.35 * math.sin(a), zp + 0.2), 0.009, 4)
        k.tore("acier", xs, ys, zp + 0.2, 0.35, 0.011, 32, 5)
        k.echelle("acier", xs, ys - rs - 0.07, 0.95, zp, l=0.12)
        for z in [1.3 + i * 0.3 for i in range(int((zp - 1.3) / 0.3) + 1)]:
            k.put("acier", G.tour([(z - 0.008, 0.13), (z + 0.008, 0.13)], 12, "z", (xs, ys - rs - 0.1, 0.0), math.pi * 1.05, math.pi * 1.95))
    elif v == "b":
        k.bandes_cyl(("rouge_vif", "blanc"), xs, ys, 0.95, zt - 0.12, rs, 9, 22)
        # pylône en treillis à 3 pieds autour de la cheminée
        pieds = [(xs + 0.55 * math.cos(a), ys + 0.55 * math.sin(a)) for a in (math.radians(215), math.radians(325), math.radians(90))]
        zh = zt - 0.5
        hauts = [(xs + 0.16 * math.cos(a), ys + 0.16 * math.sin(a)) for a in (math.radians(215), math.radians(325), math.radians(90))]
        for (px, py), (hx, hy) in zip(pieds, hauts):
            k.bz("beton", px, py, 0.0, 0.14, 0.14, 0.14)
            k.axe("car", (px, py, 0.14), (hx, hy, zh), 0.024, 6)
        n = 6
        for j in range(n):
            t0, t1 = j / float(n), (j + 1) / float(n)
            for i in range(3):
                a0p, a1p = pieds[i], pieds[(i + 1) % 3]
                a0h, a1h = hauts[i], hauts[(i + 1) % 3]
                p0 = (a0p[0] + (a0h[0] - a0p[0]) * t0, a0p[1] + (a0h[1] - a0p[1]) * t0, 0.14 + (zh - 0.14) * t0)
                q1 = (a1p[0] + (a1h[0] - a1p[0]) * t1, a1p[1] + (a1h[1] - a1p[1]) * t1, 0.14 + (zh - 0.14) * t1)
                q0 = (a1p[0] + (a1h[0] - a1p[0]) * t0, a1p[1] + (a1h[1] - a1p[1]) * t0, 0.14 + (zh - 0.14) * t0)
                k.axe("car", p0, q1, 0.012, 5)
                k.axe("car", p0, q0, 0.013, 5)
        zp = zh
        k.rev("acier", xs, ys, [(zp, rs), (zp, 0.32), (zp + 0.025, 0.32), (zp + 0.025, rs)], 32)
        k.tore("acier", xs, ys, zp + 0.2, 0.31, 0.011, 32, 5)
        for i in range(10):
            a = TAU * i / 10
            k.axe("acier", (xs + 0.31 * math.cos(a), ys + 0.31 * math.sin(a), zp), (xs + 0.31 * math.cos(a), ys + 0.31 * math.sin(a), zp + 0.2), 0.009, 4)
        k.voyant_h("voyant_r", xs + 0.25, ys - 0.1, zp + 0.22, 0.03)
    else:
        k.cyl("car", xs, ys, 0.95, zt - 0.12, rs, 24)
        k.bandes_cyl(("rouge_vif", "blanc"), xs, ys, zt - 1.1, zt - 0.12, rs + 0.006, 4, 24)
        k.cerclages("acier", xs, ys, (1.4, 1.9), rs, segs=24)
        for zp in (1.35, zt - 0.7):
            k.rev("acier", xs, ys, [(zp, rs), (zp, 0.42), (zp + 0.025, 0.42), (zp + 0.025, rs)], 32)
            k.tore("acier", xs, ys, zp + 0.2, 0.41, 0.011, 32, 5)
            for i in range(12):
                a = TAU * i / 12
                k.axe("acier", (xs + 0.41 * math.cos(a), ys + 0.41 * math.sin(a), zp), (xs + 0.41 * math.cos(a), ys + 0.41 * math.sin(a), zp + 0.2), 0.009, 4)
        k.echelle("acier", xs, ys - rs - 0.08, 0.95, zt - 0.7, l=0.12)
        # anneau d'injection de vapeur
        k.tore("cuivre", xs, ys, zt - 0.2, rt + 0.06, 0.022, 28, 6)
        k.tuyau("cuivre", [(xs + rs + 0.03, ys, 1.1), (xs + rs + 0.03, ys, zt - 0.22)], r=0.022, coude=0.05, brides=[])
    _tete(k, xs, ys, zt, rt)
    k.voyant_h("voyant_r", xs - rt - 0.05, ys, zt + 0.1, 0.022)
    # flamme (lot à part : passes glow et light seulement)
    zf = CO.FLAMME_Z[0]
    k.flamme("flamme", xs + 0.02, ys, zf - 0.04, CO.FLAMME_Z[1] - zf, rt * 1.5, langues=6, penche=(0.16, 0.05))
    # halo de nuit : deux sources dans la flamme (la flamme elle-même n'est pas rendue dans la passe light)
    hf = CO.FLAMME_Z[1] - zf
    for t, part in ((0.25, 0.6), (0.6, 0.4)):
        CO.halo(S, k, (xs + 0.05, ys, zf + hf * t), (1.0, 0.58, 0.22), HALO_W * part, r=(2.2, 5.0))
