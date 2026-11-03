"""BOBINEUSE fo-coil-winder (2×2, âge 6, électrique, UNE entrée de fluide au nord de la tuile ouest) : tour à bobiner.
Le fil de cuivre se dévide d'un touret, passe dans la tour de cuisson de l'émail (fente orange), puis un guide-fil en
va-et-vient le range sur un mandrin qui tourne : la GROSSE BOBINE DE CUIVRE est le signe de la machine. Conduite isolée et
givrée depuis la bride nord (azote liquide de la bobine supraconductrice, âge 12). a : tour horizontal ; b : bobine et
touret plus gros, bain d'émail ; c : mandrin vertical (bobine debout sur un plateau tournant, colonne et bras).
"""
import math

import communs as CO
import geo as G

Y = CO.Y
TAU = 2.0 * math.pi


def _coupleur(k, x, y):
    """Coupleur cryogénique givré contre la machine : l'arrivée de fluide vient du tronçon de raccord (pipe_picture, 4 directions,
    m_raccords.py), plus du corps (décision du lead, 3/11)."""
    k.caisson("givre", x, y, 0.0, 0.22, 0.22, 0.36, 0.03)
    k.cyl("acier", x, y, 0.36, 0.42, 0.06, 12)
    k.flexible("givre", [(x, y, 0.42), (x + 0.05, y, 0.55), (x + 0.12, y - 0.02, 0.62)], 0.03)


def _bride_nord(k, x, ty_bord=1.0):
    """Bride d'entrée au bord nord (prototype : (−0,5 ; −1,5) en coordonnées du jeu) et conduite isolée vers le sud."""
    yb = Y(ty_bord)
    k.axe("acier", (x, yb - 0.02, 0.32), (x, yb + 0.05, 0.32), 0.12, 18)
    k.axe("givre", (x, yb - 0.02, 0.32), (x, Y(0.55), 0.32), 0.075, 14)
    for yy in (Y(0.92), Y(0.62)):
        k.collier("acier", (x, yy, 0.32), (0.0, 1.0, 0.0), 0.075)
    k.bz("fonte", x, Y(0.7), 0.0, 0.12, 0.12, 0.26)


def _armoire(k, x, ty):
    k.caisson("car2", x, Y(ty), 0.0, 0.42, Y(0.2), 0.78, 0.03)
    yf = Y(ty) - Y(0.1)
    k.b("noir", (x, yf - 0.006, 0.55), (0.3, 0.012, 0.16))
    for i, m in enumerate(("voyant_v", "voyant_o", "voyant")):
        k.voyant(m, x - 0.1 + i * 0.1, yf - 0.012, 0.55, 0.022)
    k.persiennes("acier", x, yf, 0.12, 0.3, 0.18, 4)


def _tour_cuisson(k, x, ty, h=2.05):
    """Tour de cuisson de l'émail : gaine verticale isolée, fente rougeoyante au sud, poulie de renvoi en tête, évent."""
    y = Y(ty)
    k.caisson("isolant", x, y, 0.0, 0.34, 0.34, h, 0.04)
    yf = y - 0.17
    k.b("noir", (x, yf - 0.006, h * 0.5), (0.13, 0.012, h * 0.72))
    k.b("cuisson", (x, yf - 0.012, h * 0.5), (0.07, 0.012, h * 0.66))
    CO.halo(k.S, k, (x, yf - 0.6, h * 0.4), (1.0, 0.5, 0.12), 30.0, r=(0.6, 1.4))
    for i in range(8):
        k.b("acier", (x, yf - 0.016, h * 0.18 + i * h * 0.09), (0.15, 0.012, 0.018))
    k.rivets_ligne("riv", (x - 0.14, yf - 0.004, 0.1), (x - 0.14, yf - 0.004, h - 0.1), 9)
    k.cyl("rouille", x + 0.08, y + 0.08, h, h + 0.32, 0.05, 12)
    k.rev("rouille", x + 0.08, y + 0.08, [(h + 0.32, 0.075), (h + 0.36, 0.075), (h + 0.38, 0.03)], 12)
    k.volant((x - 0.04, y - 0.04, h + 0.12), 0.12, "y", larg=0.04, rayons=4, jante="acier_clair", moyeu="acier", ph=k.phase,
             ep=0.03, repere=None)
    k.bz("acier", x - 0.04, y, h - 0.05, 0.05, 0.08, 0.17)
    return (x - 0.04, y - 0.06, h + 0.12)


def bobineuse(S, k, v):
    M = k.M = CO.matieres(S)
    k.sol("noir", 2)
    if v == "c":
        return _vertical(k)
    big = v == "b"
    # banc et poupées
    zb = 0.42
    for x in (-0.68, 0.7):
        k.caisson("car", x, Y(-0.25), 0.0, 0.36, Y(0.5), zb, 0.03)
    k.caisson("car", 0.0, Y(-0.25), zb - 0.12, 1.66, Y(0.36), 0.12, 0.02)
    yfb = Y(-0.25) - Y(0.25)
    k.persiennes("acier", -0.68, yfb, 0.06, 0.3, 0.24, 4)
    k.chevrons(0.0, Y(-0.25) - Y(0.18) - 0.002, zb - 0.06, 1.5, 0.05)
    k.caisson("car2", -0.68, Y(-0.25), zb, 0.32, Y(0.45), 0.55, 0.04)       # poupée
    k.moteur("car2", -0.68, Y(0.12), zb + 0.08, 0.36, 0.13, axe="y")
    k.caisson("car2", 0.7, Y(-0.25), zb, 0.22, Y(0.4), 0.42, 0.04)         # contre-pointe
    k.axe("acier_clair", (0.55, Y(-0.25), zb + 0.3), (0.62, Y(-0.25), zb + 0.3), 0.05, 12)
    # mandrin et bobine
    zc = zb + 0.3
    rc = 0.38 if big else 0.33
    lc = 0.86 if big else 0.78
    xc = -0.04
    k.mobile(True)
    k.axe("acier_clair", (-0.52, Y(-0.25), zc), (0.58, Y(-0.25), zc), 0.045, 14)
    k.put("fil", G.tour([(-lc / 2.0, 0.08), (-lc / 2.0, rc), (lc / 2.0, rc), (lc / 2.0, 0.08)], 44, "x", (xc, Y(-0.25), zc)))
    for sx in (-1, 1):
        x = xc + sx * (lc / 2.0 + 0.02)
        k.put("acier", G.tour([(-0.02, 0.05), (-0.02, rc + 0.07), (0.02, rc + 0.07), (0.02, 0.05)], 44, "x", (x, Y(-0.25), zc)))
    a = TAU * k.phase
    k.b("noir", (xc + 0.1 * math.cos(a), Y(-0.25) - rc * math.sin(0.7), zc + rc * math.cos(0.7)), (0.05, 0.02, 0.02))
    k.mobile(False)
    # guide-fil sur glissière, au-dessus et derrière la bobine
    zg = zc + rc + 0.32
    yg = Y(-0.02)
    for sx in (-1, 1):
        k.bz("car2", sx * 0.66, yg, zb, 0.07, 0.07, zg - zb + 0.06)
    k.axe("acier_clair", (-0.66, yg, zg), (0.66, yg, zg), 0.025, 10)
    k.axe("acier", (-0.66, yg, zg + 0.08), (0.66, yg, zg + 0.08), 0.018, 8)
    xg = xc + (lc / 2.0 - 0.05) * math.sin(TAU * k.phase)
    k.mobile(True)
    k.caisson("jaune", xg, yg, zg - 0.08, 0.14, 0.12, 0.2, 0.02)
    k.volant((xg, yg - 0.07, zg - 0.12), 0.05, "y", larg=0.02, rayons=3, jante="acier_clair", moyeu="acier", ep=0.015,
             repere=None, mobile=False)
    k.axe("cuivre", (xg, yg - 0.07, zg - 0.17), (xg, Y(-0.25) - rc * 0.3, zc + rc * 0.95), 0.012, 5)
    k.mobile(False)
    # touret d'alimentation, tour de cuisson, fil tendu
    xt, tyt = 0.48, 0.62
    rt = 0.3 if big else 0.24
    k.bz("fonte", xt, Y(tyt), 0.0, 0.3, 0.3, 0.12)
    k.cyl("acier", xt, Y(tyt), 0.12, 0.7, 0.03, 10)
    k.mobile(True)
    k.rev("fil", xt, Y(tyt), [(0.18, 0.05), (0.18, rt - 0.03), (0.42, rt - 0.03), (0.42, 0.05)], 36)
    k.mobile(False)
    for z in (0.16, 0.44):
        k.rev("acier", xt, Y(tyt), [(z, 0.04), (z, rt + 0.03), (z + 0.025, rt + 0.03), (z + 0.025, 0.04)], 36)
    pt = _tour_cuisson(k, -0.08, 0.66, 2.0 if not big else 2.15)
    k.axe("cuivre", (xt - rt * 0.7, Y(tyt) - rt * 0.7, 0.36), (pt[0], pt[1], pt[2] + 0.12), 0.012, 5)
    k.axe("cuivre", (pt[0], pt[1], pt[2] - 0.12), (xg, yg - 0.07, zg - 0.07), 0.012, 5)
    _coupleur(k, -0.9, Y(-0.45))          # là où tombe le tronçon ouest (connexion (−1,5 ; 0,5) du jeu)
    _armoire(k, 0.78, 0.15) if not big else _armoire(k, 0.82, 0.22)
    # bobines finies au sud
    for i, x in enumerate((0.55, 0.82) if not big else (0.6,)):
        k.put("fil", G.tour([(-0.09, 0.05), (-0.09, 0.14), (0.09, 0.14), (0.09, 0.05)], 28, "y", (x, Y(-0.82), 0.15)))
        k.put("acier", G.tour([(-0.1, 0.03), (-0.1, 0.06), (0.1, 0.06), (0.1, 0.03)], 20, "y", (x, Y(-0.82), 0.15)))
    if big:
        k.caisson("car2", -0.55, Y(-0.85), 0.0, 0.5, Y(0.22), 0.22, 0.02)       # bain d'émail
        k.b("vert", (-0.55, Y(-0.85), 0.215), (0.42, Y(0.17), 0.012))
        k.axe("cuivre", (-0.8, Y(-0.85), 0.24), (-0.3, Y(-0.85), 0.24), 0.012, 5)


def _vertical(k):
    """Variante c : mandrin vertical sur plateau tournant ; colonne et bras du guide-fil ; tour de cuisson derrière."""
    cx, cy = -0.12, Y(-0.22)
    k.rev("car", cx, cy, [(0.08, 0.62), (0.3, 0.6), (0.36, 0.52), (0.36, 0.0)], 40)
    k.cerclages("acier", cx, cy, (0.2,), 0.6, segs=40)
    k.chevrons(cx, cy - 0.61, 0.22, 0.6, 0.05)
    a = TAU * k.phase
    k.mobile(True)
    k.rev("acier", cx, cy, [(0.36, 0.5), (0.42, 0.5), (0.42, 0.0)], 40)
    k.rev("fil", cx, cy, [(0.42, 0.12), (0.42, 0.4), (0.98, 0.4), (0.98, 0.12)], 44)
    k.rev("acier", cx, cy, [(0.98, 0.1), (0.98, 0.46), (1.02, 0.46), (1.02, 0.1)], 44)
    k.cyl("acier_clair", cx, cy, 1.02, 1.2, 0.08, 16)
    k.b("noir", (cx + 0.43 * math.cos(a), cy + 0.43 * math.sin(a), 1.0), (0.06, 0.06, 0.04))
    k.mobile(False)
    # colonne et bras
    xcol = 0.62
    k.bz("car2", xcol, cy + 0.15, 0.08, 0.26, 0.26, 1.85)
    k.rivets_ligne("riv", (xcol - 0.1, cy + 0.15 - 0.135, 0.2), (xcol - 0.1, cy + 0.15 - 0.135, 1.8), 10)
    zg = 0.55 + 0.4 * (0.5 + 0.5 * math.sin(a))
    k.mobile(True)
    k.caisson("jaune", xcol, cy + 0.15, zg - 0.1, 0.32, 0.32, 0.2, 0.03)
    k.bz("car", (xcol + cx) / 2.0 + 0.1, cy + 0.15, zg - 0.05, xcol - cx - 0.3, 0.1, 0.1)
    k.axe("cuivre", (cx + 0.5, cy + 0.12, zg), (cx + 0.4, cy, zg - 0.02), 0.012, 5)
    k.mobile(False)
    k.caisson("car2", xcol, cy + 0.15, 1.92, 0.34, 0.34, 0.16, 0.03)
    k.voyant_h("voyant_o", xcol, cy + 0.15, 2.08, 0.035)
    # touret à plat au nord-est, tour de cuisson au nord-ouest
    xt, yt = 0.55, Y(0.62)
    k.mobile(True)
    k.rev("fil", xt, yt, [(0.1, 0.05), (0.1, 0.22), (0.3, 0.22), (0.3, 0.05)], 32)
    k.mobile(False)
    k.rev("acier", xt, yt, [(0.06, 0.26), (0.1, 0.26), (0.1, 0.0)], 32)
    k.cyl("acier", xt, yt, 0.3, 0.55, 0.025, 8)
    pt = _tour_cuisson(k, -0.22, 0.68, 2.1)
    k.axe("cuivre", (xt, yt, 0.55), (pt[0], pt[1], pt[2] + 0.12), 0.012, 5)
    k.axe("cuivre", (pt[0], pt[1], pt[2] - 0.12), (xcol - 0.1, cy + 0.15, 1.85), 0.012, 5)
    k.axe("cuivre", (xcol - 0.1, cy + 0.15, 1.85), (xcol - 0.12, cy + 0.15, zg + 0.1), 0.012, 5)
    _coupleur(k, cx - 0.42, cy + 0.2)
    _armoire(k, 0.82, -0.6)
