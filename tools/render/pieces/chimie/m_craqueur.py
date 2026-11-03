"""VAPOCRAQUEUR (fo-steam-cracker, 3×3) : four de craquage (zone radiante en caisson rouge oxyde, regards de flamme), hotte
et zone de convection, cheminée haute à bandes, échangeur de trempe calorifugé et ballon de vapeur. Entrées nord x = −1
(gaz) et +1 (vapeur), sortie sud x = 0 (éthylène). Repère local de repere.py (u est, v sud, tuiles ; z en unités).
"""
import math

import habille as H

# four (zone radiante)
FU, FV, FSU, FSV, FZ = -0.35, -0.22, 1.8, 1.62, 2.0
# zone de convection et cheminée
CU, CV, CSU, CSV, CZ0, CZ1 = -0.35, -0.42, 0.95, 0.72, 2.45, 3.15
SR, SZ1 = 0.165, 5.0
# échangeur de trempe et ballon de vapeur
TU, TV, TR = 0.98, -0.02, 0.235
BU, BV, BR, BL, BZ = 0.95, -1.02, 0.19, 0.58, 1.42


def build(S, k, R):
    four(k, R)
    convection(k, R)
    cheminee(k, R)
    trempe(k, R)
    raccords(k, R)
    abords(k, R)


def four(k, R):
    R.box("beton", FU, FV, 0.0, FSU + 0.16, FSV + 0.16, 0.07)
    R.caisson("oxyde", FU, FV, 0.07, FSU, FSV, FZ - 0.07, 0.04)
    b = R.bornes(FU, FV, FSU, FSV)
    xs = H.montants(k, "acier", b, 0.07, FZ + 0.02, pas=0.42)
    for z in (0.62, 1.32, FZ - 0.04):
        H.ceinture(k, "acier", b, z, 0.05, 0.03)
    # regards de flamme : rangée basse (brûleurs de sole) et rangée haute (serpentins), entre les montants
    for x in H.entre(xs):
        # gueule de brûleur (basse, large et basse) et deux petits regards ronds à volet (un ouvert, un fermé)
        H.fenetre(k, "acier", "feu", x, b[3], 0.3, 0.16, 0.06)
        Y = H.yb(b[3])
        for dx, ouvert in ((-0.07, True), (0.07, False)):
            k.axe("acier", (x + dx, Y + 0.01, 0.95), (x + dx, Y - 0.05, 0.95), 0.04, 10)
            if ouvert:
                k.axe("feu", (x + dx, Y - 0.05, 0.95), (x + dx, Y - 0.052, 0.95), 0.026, 10)
            else:
                k.axe("noir", (x + dx, Y - 0.05, 0.95), (x + dx, Y - 0.06, 0.95), 0.036, 10)
            k.b("acier_clair", (x + dx, Y - 0.06, 0.95 + 0.045), (0.03, 0.012, 0.02))
    # passerelle de visite au-dessus des regards hauts : caillebotis, consoles, garde-corps
    Y0 = H.yb(b[3])
    zp, dp = 1.42, 0.24
    k.bz("noir", (b[0] + b[1]) / 2.0, Y0 - dp / 2.0, zp - 0.02, b[1] - b[0] + 0.1, dp, 0.025)
    k.bz("jaune", (b[0] + b[1]) / 2.0, Y0 - dp + 0.008, zp - 0.035, b[1] - b[0] + 0.1, 0.016, 0.045)
    for x in xs[::2]:
        k.axe("acier", (x, Y0, zp - 0.2), (x, Y0 - dp + 0.02, zp - 0.03), 0.012, 5)
    k.rambarde("jaune", [(b[0] - 0.05, Y0 - dp + 0.01, zp), (b[1] + 0.05, Y0 - dp + 0.01, zp)], 0.16, 0.3)
    # fente de sole : lueur continue au pied, sous un larmier
    Y = H.yb(b[3])
    k.b("feu", (sum(b[:2]) / 2.0, Y - 0.006, 0.13), (b[1] - b[0] - 0.12, 0.008, 0.035))
    k.b("acier", (sum(b[:2]) / 2.0, Y - 0.03, 0.17), (b[1] - b[0] - 0.05, 0.05, 0.02))
    # brûleurs : collecteur de gaz au pied de la face sud et une canne par travée
    xm = H.entre(xs)
    k.tuyau("acier", [(b[0] + 0.05, Y - 0.1, 0.09), (b[1] - 0.05, Y - 0.1, 0.09)], 0.026, 0.1)
    for x in xm:
        k.axe("acier_clair", (x, Y - 0.1, 0.09), (x, Y - 0.03, 0.21), 0.018, 8)
        k.cyl("noir", x, Y - 0.1, 0.0, 0.07, 0.03, 8)
    k.vanne("acier", "rouge", (b[0] + 0.2, Y - 0.1, 0.12), 0.03, 0.05)
    # toit du four : plancher caillebotis et rambarde jaune autour de la hotte
    hb = R.bornes(FU, FV, FSU - 0.06, FSV - 0.06)
    zt = FZ
    k.bz("noir", (hb[0] + hb[1]) / 2.0, H.yb((hb[2] + hb[3]) / 2.0), zt, hb[1] - hb[0], (hb[3] - hb[2]) * H.D, 0.02)
    pts = [(hb[0], H.yb(hb[3]), zt), (hb[1], H.yb(hb[3]), zt), (hb[1], H.yb(hb[2]), zt), (hb[0], H.yb(hb[2]), zt),
           (hb[0], H.yb(hb[3]), zt)]
    k.rambarde("jaune", pts, 0.16, 0.28)
    # échelle sur la face sud, côté ouest
    k.echelle("jaune", b[0] + 0.16, Y - 0.27, 0.0, 1.42)
    k.echelle("jaune", b[1] - 0.16, Y - 0.07, 1.42, FZ + 0.16)
    # plaque d'identification et chevrons au pied
    k.b("chevron", ((b[0] + b[1]) / 2.0 + 0.25, Y - 0.006, 0.52), (0.42, 0.012, 0.06))


def convection(k, R):
    # hotte en tronc de pyramide, puis caisson de convection, collecteurs des serpentins
    R.prisme("oxyde", FU, FV, FZ, CZ0, FSU - 0.26, FSV - 0.26, 0.58)
    # traversées : 3 lignes de croisement (convection -> serpentins radiants) qui plongent dans la voûte, de chaque côté
    for j, du in enumerate((-0.55, 0.0, 0.55)):
        for sv in (-1, 1):
            v0 = CV + sv * (CSV / 2.0 - 0.1)
            v1 = FV + sv * (FSV / 2.0 - 0.18)
            u = CU + du * 0.75
            R.tuyau("isolant", [(u, v0, CZ0 + 0.2), (u, v1, CZ0 + 0.2), (u, v1, FZ - 0.05)], 0.04, 0.09, bride_mat="acier")
    R.caisson("oxyde", CU, CV, CZ0, CSU, CSV, CZ1 - CZ0, 0.035)
    b = R.bornes(CU, CV, CSU, CSV)
    H.montants(k, "acier", b, CZ0, CZ1, pas=0.3, l=0.06, e=0.04)
    H.ceinture(k, "acier", b, CZ1 - 0.05, 0.05, 0.03)
    # coudes des serpentins de convection qui dépassent à l'est et à l'ouest (épingles)
    for i in range(4):
        z = CZ0 + 0.14 + i * 0.15
        for su in (-1, 1):
            u = CU + su * (CSU / 2.0 + 0.03)
            R.tuyau("acier_clair", [(u, CV - 0.2, z), (u + su * 0.07, CV - 0.2, z), (u + su * 0.07, CV + 0.2, z),
                                    (u, CV + 0.2, z)], 0.028, 0.06, brides=[])


def cheminee(k, R):
    z0 = CZ1
    R.rev("car2", CU, CV, [(z0, 0.3), (z0 + 0.12, 0.3), (z0 + 0.35, SR + 0.02), (SZ1, SR)], 28)
    R.cerclages("acier", CU, CV, [z0 + 0.6, z0 + 0.95, z0 + 1.3], SR + 0.004, 0.016, 0.025)
    # bandes de balisage rouge et blanche en tête, couronne
    R.cyl("rouge", CU, CV, SZ1 - 0.42, SZ1 - 0.28, SR + 0.006)
    R.cyl("blanc", CU, CV, SZ1 - 0.28, SZ1 - 0.14, SR + 0.006)
    R.cyl("rouge", CU, CV, SZ1 - 0.14, SZ1 - 0.02, SR + 0.006)
    R.rev("acier", CU, CV, [(SZ1 - 0.02, SR + 0.03), (SZ1 + 0.03, SR + 0.03), (SZ1 + 0.03, SR - 0.03), (SZ1 - 0.1, SR - 0.03)],
          28, cap=False)
    R.cyl("noir", CU, CV, SZ1 - 0.06, SZ1 + 0.01, SR - 0.035)
    # palier d'échantillonnage : plancher en couronne, garde-corps, échelle
    zp = z0 + 1.15
    R.tore("acier", CU, CV, zp, SR + 0.13, 0.02, 32, 6)
    R.rev("noir", CU, CV, [(zp - 0.015, SR + 0.004), (zp - 0.015, SR + 0.15), (zp + 0.005, SR + 0.15), (zp + 0.005, SR + 0.004)],
          28, cap=False)
    R.tore("jaune", CU, CV, zp + 0.15, SR + 0.15, 0.011, 32, 5)
    x, y, _ = R.p(CU, CV)
    for i in range(8):
        a = 6.2832 * (i + 0.5) / 8
        px, py = x + (SR + 0.15) * math.cos(a), y + (SR + 0.15) * math.sin(a)
        k.axe("jaune", (px, py, zp), (px, py, zp + 0.15), 0.009, 5)
    k.echelle("jaune", x + 0.02, y - SR - 0.035, CZ1, zp)


def trempe(k, R):
    # échangeur de trempe vertical calorifugé (tôle d'aluminium), pied et tête bombée
    R.cyl("acier", TU, TV, 0.0, 0.12, TR + 0.04, 24)
    R.cuve("isolant", TU, TV, 0.12, 2.28, TR, 0.4)
    R.cerclages("acier_clair", TU, TV, [0.45, 0.85, 1.25, 1.65, 2.0], TR + 0.002, 0.012, 0.018)
    # ligne de transfert : sortie de la hotte, coude, entrée en tête d'échangeur
    R.tuyau("isolant", [(FU + 0.62, FV, FZ + 0.25), (FU + 0.62, FV, 2.66), (TU, FV, 2.66), (TU, TV, 2.66), (TU, TV, 2.3)],
            0.085, 0.18, bride_mat="acier")
    # ballon de vapeur couché sur berceaux, tubes montants et descendants vers l'échangeur
    R.box("acier", BU - 0.25, BV, 0.0, 0.07, 0.3, BZ + 0.05)
    R.box("acier", BU + 0.25, BV, 0.0, 0.07, 0.3, BZ + 0.05)
    R.echangeur(BU, BV, BZ, BL, BR, "car2", "acier", "u", True, 3)
    R.tuyau("acier", [(BU + 0.3, BV, BZ + 0.05), (BU + 0.3, BV, 0.75), (TU - 0.05, TV - 0.12, 0.75)], 0.035, 0.08)
    R.tuyau("acier", [(TU + 0.05, TV - 0.1, 2.1), (BU + 0.38, BV, 2.1), (BU + 0.38, BV, BZ + 2 * BR - 0.02)], 0.035, 0.08)
    # soupape et évent du ballon
    R.cyl("acier_clair", BU - 0.2, BV, BZ + 2 * BR - 0.02, BZ + 2 * BR + 0.16, 0.03, 10)
    R.cyl("rouge", BU - 0.2, BV, BZ + 2 * BR + 0.16, BZ + 2 * BR + 0.2, 0.045, 10)
    # manomètre et voyant sur la face visible de l'échangeur
    x, y, _ = R.p(TU, TV)
    k.voyant("voyant", x, y - TR - 0.01, 1.05, 0.026)
    k.b("noir", (x, y - TR - 0.02, 1.45), (0.11, 0.03, 0.11))
    k.b("acier_clair", (x, y - TR - 0.037, 1.45), (0.08, 0.006, 0.08))


def raccords(k, R):
    zr = 0.22
    # entrée gaz (x = −1) : montée derrière le four jusqu'à la zone de convection (face ouest)
    R.raccord(-1.0, "n", zr, vers=[(-1.0, -1.2, zr), (-1.0, -1.2, 2.78), (-1.0, CV, 2.78), (CU - CSU / 2.0, CV, 2.78)])
    R.vanne("acier", "rouge", (-1.0, -0.8, 2.78), 0.05, 0.06)
    R.collier("acier_clair", (-1.0, -1.2, 1.0), (0.0, 0.0, 1.0), 0.09, 0.03, 0.03)
    # entrée vapeur (x = +1) : montée vers le ballon de vapeur
    R.raccord(1.0, "n", zr, vers=[(1.0, -1.25, zr), (1.0, -1.25, 1.15), (1.0, BV, 1.15), (1.0, BV, BZ + 0.02)])
    R.collier("acier_clair", (1.0, -1.25, 0.7), (0.0, 0.0, 1.0), 0.09, 0.03, 0.03)
    # vapeur de dilution du ballon vers la convection (face est)
    R.tuyau("acier", [(BU - 0.3, BV, BZ + 2 * BR - 0.02), (BU - 0.3, BV, 2.86), (BU - 0.3, CV + 0.15, 2.86),
                      (CU + CSU / 2.0, CV + 0.15, 2.86)], 0.05, 0.1)
    # sortie éthylène (x = 0) : du pied de l'échangeur vers la bride sud
    R.raccord(0.0, "s", zr, vers=[(0.0, 1.2, zr), (0.0, 0.92, zr), (TU, 0.92, zr), (TU, 0.92, 0.42), (TU, TV + 0.12, 0.42)])
    R.vanne("acier", "bleu", (0.5, 0.92, zr), 0.05, 0.06)


def abords(k, R):
    # armoire de conduite (brûleurs) au sud-ouest, face visible habillée
    cu, cv, su, sv, h = -1.05, 1.02, 0.5, 0.34, 0.62
    R.caisson("car2", cu, cv, 0.0, su, sv, h, 0.02)
    b = R.bornes(cu, cv, su, sv)
    H.porte(k, "car2", "acier_clair", (b[0] + b[1]) / 2.0, b[3], 0.06, b[1] - b[0] - 0.1, h - 0.14)
    Y = H.yb(b[3])
    k.voyant("voyant_v", b[0] + 0.07, Y - 0.02, h - 0.07, 0.016)
    k.voyant("voyant", b[0] + 0.13, Y - 0.02, h - 0.07, 0.016)
    k.b("chevron", ((b[0] + b[1]) / 2.0, Y - 0.006, 0.035), (b[1] - b[0], 0.012, 0.05))
    # câbles de l'armoire vers le four
    k.cable("noir", ((b[0] + b[1]) / 2.0, H.yb((b[2] + b[3]) / 2.0), h), R.p(FU - 0.5, FV + FSV / 2.0, 0.8), 0.08, 0.014)
    # bouteille d'analyse et petit poste d'échantillonnage près de la sortie
    R.cuve("blanc", 0.45, 1.22, 0.0, 0.42, 0.07, 0.5, 16)
    R.cuve("blanc", 0.6, 1.24, 0.0, 0.42, 0.07, 0.5, 16)
    R.box("acier", 0.53, 1.12, 0.0, 0.32, 0.05, 0.36)
