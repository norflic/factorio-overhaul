"""VAPOCRAQUEUR (fo-steam-cracker, 3×3), ronde 2 (CRITIQUE.md §1). Lecture « vapocraqueur », pas « cokerie » : HAUTE boîte de
radiation en brique réfractaire sous ossature d'acier (poteaux en I tous les 0,5 tuile, passerelle à mi-hauteur), FENTE DE
SOLE continue et rangée de brûleurs au sol à flamme rouge, regards (12 × 8 px), deux baies où l'on voit le faisceau de
TUBES VERTICAUX du serpentin radiant ; au-dessus, hotte de brique et SECTION DE CONVECTION à grille (tubes horizontaux),
cheminée d'acier à bandes rouges ; ballon de vapeur couché sur le toit ; échangeur de trempe argent (diamètre 0,6 tuile)
à l'angle sud-est, ligne de transfert de 16 px. Nuit : flaque orange devant la fente (passe halo, sources ponctuelles).
Entrées nord x = −1 (gaz) et +1 (vapeur), sortie sud x = 0 (éthylène).
"""
import habille as H

FU, FV, FSU, FSV, FZ = -0.22, -0.42, 2.2, 1.36, 2.3      # boîte de radiation
HU, HV, HSU, HSV, HZ = -0.5, -0.55, 1.3, 0.92, 2.75      # hotte (base) et section de convection
CZ1 = 3.45
SR, SZ1 = 0.17, 5.25                                     # cheminée
TU, TV, TR, TZ = 1.12, 0.95, 0.3, 2.35                   # échangeur de trempe
BU, BV0, BV1, BR, BZ = 0.55, -1.0, 0.12, 0.2, 2.36        # ballon de vapeur (le long de v)


def build(S, k, R):
    radiation(k, R, S)
    convection(k, R)
    cheminee(k, R)
    ballon(k, R)
    trempe(k, R)
    raccords(k, R)
    abords(k, R)


def radiation(k, R, S):
    R.box("beton", FU, FV, 0.0, FSU + 0.12, FSV + 0.12, 0.08)
    R.caisson("brique", FU, FV, 0.08, FSU, FSV, FZ - 0.08, 0.03)
    b = R.bornes(FU, FV, FSU, FSV)
    Y = H.yb(b[3])
    xs = H.montants(k, "acier_clair", b, 0.08, FZ + 0.03, pas=0.5, l=0.1, e=0.06)
    for z in (0.42, FZ - 0.05):
        H.ceinture(k, "acier_clair", b, z, 0.06, 0.035)
    baies = H.entre(xs)
    # fente de sole continue (flamme rouge) dans un cadre d'acier, larmier au-dessus
    w = b[1] - b[0] - 0.1
    xc = (b[0] + b[1]) / 2.0
    k.b("noir", (xc, Y - 0.004, 0.245), (w, 0.012, 0.17))
    k.b("feu", (xc, Y - 0.012, 0.245), (w - 0.04, 0.006, 0.13))
    k.b("acier", (xc, Y - 0.04, 0.345), (w + 0.04, 0.08, 0.03))
    k.b("acier", (xc, Y - 0.03, 0.14), (w + 0.04, 0.06, 0.025))
    # acier bruni et suie au-dessus de la fente
    k.b("chauffe", (xc, Y - 0.006, 0.39), (w, 0.01, 0.05))
    # regards de flamme (12 × 8 px) entre les poteaux, coulures de suie au-dessus
    for x in baies:
        H.fenetre(k, "acier", "feu", x, b[3], 0.6, 0.19, 0.17, 0.035)
        k.b("suie", (x, Y - 0.003, 0.88), (0.1, 0.006, 0.36))
        k.b("chauffe", (x, Y - 0.004, 0.73), (0.22, 0.008, 0.035))
    # deux baies de visite : faisceau de tubes verticaux du serpentin radiant (rouge sombre)
    for x in baies[1:3] if len(baies) >= 4 else baies[:2]:
        k.b("noir", (x, Y - 0.003, 1.6), (0.3, 0.008, 0.72))
        for dx in (-0.09, 0.0, 0.09):
            k.axe("tube_rouge", (x + dx, Y + 0.02, 1.26), (x + dx, Y + 0.02, 1.94), 0.03, 10)
        k.b("acier", (x, Y - 0.02, 1.6), (0.33, 0.035, 0.03))
        for dz in (1.23, 1.97):
            k.b("acier", (x, Y - 0.02, dz), (0.36, 0.04, 0.04))
        k.b("bleui", (x, Y - 0.004, 2.08), (0.3, 0.008, 0.1))
    # passerelle à mi-hauteur : caillebotis, consoles, garde-corps laiton ; échelles
    zp, dp = 1.1, 0.22
    k.bz("acier_clair", xc, Y - dp / 2.0, zp - 0.03, b[1] - b[0] + 0.1, dp, 0.03)
    k.bz("jaune", xc, Y - dp + 0.01, zp - 0.05, b[1] - b[0] + 0.1, 0.022, 0.06)
    for x in xs[::2]:
        k.axe("acier", (x, Y, zp - 0.24), (x, Y - dp + 0.02, zp - 0.04), 0.018, 6)
    k.rambarde("laiton", [(b[0] - 0.05, Y - dp + 0.012, zp), (b[1] + 0.05, Y - dp + 0.012, zp)], 0.17, 0.32)
    k.echelle("jaune", b[0] + 0.2, Y - dp - 0.02, 0.0, zp)
    k.echelle("jaune", b[1] - 0.2, Y - 0.08, zp, FZ + 0.12)
    # rangée de brûleurs au sol : collecteur, cannes, petites vannes ; plaque chevron
    k.tuyau("acier", [(b[0] + 0.08, Y - 0.17, 0.07), (b[1] - 0.08, Y - 0.17, 0.07)], 0.032, 0.1)
    n = int(w / 0.28)
    for i in range(n):
        x = b[0] + 0.14 + (w - 0.08) * i / max(1, n - 1)
        k.axe("acier_clair", (x, Y - 0.17, 0.07), (x, Y - 0.05, 0.17), 0.02, 8)
        k.cyl("noir", x, Y - 0.08, 0.1, 0.17, 0.035, 10)
    for x in (b[0] + 0.3, b[1] - 0.3):
        k.vanne("acier", "rouge", (x, Y - 0.17, 0.08), 0.032, 0.05)
    # toit : caillebotis et rambarde laiton
    zt = FZ
    pts = [(b[0] + 0.04, Y + 0.03, zt), (b[1] - 0.04, Y + 0.03, zt)]
    k.rambarde("laiton", pts, 0.15, 0.3)
    # nuit : flaque orange devant la fente de sole (passe halo seulement)
    # 5 sources basses (0,5 W) : pic au sol visé 0,3 à 0,55, flaque d'environ 2 × 0,8 tuile (essai à 3 × 4 W : pic écrêté
    # à 1,0, 0,8 tuile²)
    for i in range(5):
        x = b[0] + 0.25 + (b[1] - b[0] - 0.5) * i / 4.0
        S.halo_light((x, Y - 0.42, 0.3), (1.0, 0.33, 0.05), 0.5, 0.08)


def convection(k, R):
    R.prisme("brique", HU, HV, FZ, HZ, HSU, HSV, 0.8)
    R.caisson("oxyde", HU, HV, HZ, HSU * 0.8, HSV * 0.8, CZ1 - HZ, 0.03)
    b = R.bornes(HU, HV, HSU * 0.8, HSV * 0.8)
    H.montants(k, "acier", b, HZ, CZ1, pas=0.35, l=0.07, e=0.04)
    H.ceinture(k, "acier", b, CZ1 - 0.06, 0.06, 0.03)
    # grille de la face sud : faisceau de tubes HORIZONTAUX de la convection, dans un creux sombre
    Y = H.yb(b[3])
    xc, w = (b[0] + b[1]) / 2.0, b[1] - b[0] - 0.16
    k.b("noir", (xc, Y - 0.004, HZ + 0.33), (w, 0.01, 0.42))
    for i in range(5):
        z = HZ + 0.16 + i * 0.085
        k.axe("acier_clair", (xc - w / 2.0, Y - 0.012, z), (xc + w / 2.0, Y - 0.012, z), 0.026, 10)
    for i in range(4):
        x = xc - w / 2.0 + w * (i + 0.5) / 4
        k.b("acier", (x, Y - 0.04, HZ + 0.33), (0.03, 0.02, 0.46))
    k.b("suie", (xc, Y - 0.003, CZ1 - 0.1), (w, 0.006, 0.12))


def cheminee(k, R):
    z0 = CZ1
    R.rev("acier_clair", HU, HV, [(z0, 0.3), (z0 + 0.1, 0.3), (z0 + 0.35, SR + 0.02), (SZ1, SR)], 28)
    R.cerclages("acier", HU, HV, [z0 + 0.6, z0 + 0.95, z0 + 1.3], SR + 0.004, 0.018, 0.026)
    R.cyl("rouge", HU, HV, SZ1 - 0.42, SZ1 - 0.28, SR + 0.006)
    R.cyl("blanc", HU, HV, SZ1 - 0.28, SZ1 - 0.14, SR + 0.006)
    R.cyl("rouge", HU, HV, SZ1 - 0.14, SZ1 - 0.02, SR + 0.006)
    R.rev("acier", HU, HV, [(SZ1 - 0.02, SR + 0.035), (SZ1 + 0.03, SR + 0.035), (SZ1 + 0.03, SR - 0.03), (SZ1 - 0.1, SR - 0.03)],
          28, cap=False)
    R.cyl("suie", HU, HV, SZ1 - 0.06, SZ1 + 0.01, SR - 0.035)
    zp = z0 + 1.1
    R.rev("noir", HU, HV, [(zp - 0.02, SR + 0.004), (zp - 0.02, SR + 0.16), (zp + 0.01, SR + 0.16), (zp + 0.01, SR + 0.004)],
          28, cap=False)
    R.tore("laiton", HU, HV, zp + 0.16, SR + 0.16, 0.018, 32, 6)
    x, y, _ = R.p(HU, HV)
    k.echelle("jaune", x + 0.02, y - SR - 0.04, CZ1, zp)


def ballon(k, R):
    vc, L = (BV0 + BV1) / 2.0, BV1 - BV0
    for v in (BV0 + 0.18, BV1 - 0.18):
        R.box("acier", BU, v, FZ, 0.32, 0.07, BZ - FZ + 0.06)
    R.echangeur(BU, vc, BZ, L, BR, "acier_clair", "acier", "v", True, 3)
    R.cyl("acier", BU + 0.08, vc - 0.2, BZ + 2 * BR - 0.02, BZ + 2 * BR + 0.14, 0.032, 10)
    R.cyl("rouge", BU + 0.08, vc - 0.2, BZ + 2 * BR + 0.14, BZ + 2 * BR + 0.19, 0.05, 10)
    R.cyl("acier", BU - 0.08, vc + 0.15, BZ + 2 * BR - 0.02, BZ + 2 * BR + 0.08, 0.04, 10)
    R.voyant_h("voyant", BU - 0.08, vc + 0.15, BZ + 2 * BR + 0.08, 0.026)


def trempe(k, R):
    R.cyl("acier", TU, TV, 0.0, 0.12, TR + 0.05, 24)
    R.cuve("isolant", TU, TV, 0.12, TZ, TR, 0.4)
    R.cerclages("acier_clair", TU, TV, [0.45, 0.85, 1.25, 1.65, 2.0], TR + 0.002, 0.014, 0.02)
    x, y, _ = R.p(TU, TV)
    k.b("noir", (x, y - TR - 0.02, 1.45), (0.13, 0.03, 0.13))
    k.b("acier_clair", (x, y - TR - 0.037, 1.45), (0.1, 0.006, 0.1))
    k.voyant("voyant", x - 0.12, y - TR + 0.02, 1.05, 0.024)
    # ligne de transfert (16 px) : flanc est de la boîte de radiation -> flanc nord de l'échangeur
    R.tuyau("isolant", [(FU + FSU / 2.0, 0.0, 2.05), (TU, 0.0, 2.05), (TU, TV - 0.1, 2.05)], 0.13, 0.2, bride_mat="acier")
    # vapeur haute pression produite par la trempe, vers le ballon
    R.tuyau("acier", [(TU - 0.1, TV - 0.15, TZ - 0.05), (TU - 0.1, TV - 0.15, TZ + 0.25), (BU, BV1 + 0.02, TZ + 0.25),
                      (BU, BV1 - 0.05, BZ + BR)], 0.04, 0.1)


def raccords(k, R):
    zr = 0.22
    # gaz (x = −1) : montée derrière la boîte jusqu'à la section de convection (face ouest)
    R.raccord(-1.0, "n", zr, vers=[(-1.0, -1.22, zr), (-1.0, -1.22, 3.1), (-1.0, HV, 3.1), (HU - HSU * 0.4 + 0.03, HV, 3.1)])
    R.vanne("acier", "rouge", (-1.0, -0.85, 3.1), 0.05, 0.06)
    R.collier("acier_clair", (-1.0, -1.22, 1.2), (0.0, 0.0, 1.0), 0.09, 0.03, 0.03)
    # vapeur de dilution (x = +1) : montée vers le ballon, puis du ballon à la convection (face est)
    R.raccord(1.0, "n", zr, vers=[(1.0, -1.22, zr), (1.0, -1.22, 2.6), (BU, -1.22, 2.6), (BU, BV0 - 0.05, 2.6),
                                  (BU, BV0 + 0.02, BZ + BR)])
    R.collier("acier_clair", (1.0, -1.22, 1.2), (0.0, 0.0, 1.0), 0.09, 0.03, 0.03)
    R.tuyau("acier", [(BU - 0.1, BV0 + 0.3, BZ + 2 * BR - 0.03), (BU - 0.1, BV0 + 0.3, 3.05), (HU + HSU * 0.4 - 0.03, BV0 + 0.3, 3.05)],
            0.05, 0.1)
    # éthylène (x = 0) : du pied de l'échangeur vers la bride sud
    R.raccord(0.0, "s", zr, vers=[(0.0, 1.22, zr), (0.78, 1.22, zr), (0.86, 1.0, zr)])
    R.vanne("acier", "bleu", (0.4, 1.22, zr), 0.05, 0.06)


def abords(k, R):
    # armoire de conduite des brûleurs au sud-ouest
    cu, cv, su, sv, h = -1.05, 1.02, 0.5, 0.34, 0.66
    R.caisson("car2", cu, cv, 0.0, su, sv, h, 0.02)
    b = R.bornes(cu, cv, su, sv)
    H.porte(k, "car2", "acier_clair", (b[0] + b[1]) / 2.0, b[3], 0.06, b[1] - b[0] - 0.1, h - 0.16)
    Y = H.yb(b[3])
    k.voyant("voyant_v", b[0] + 0.07, Y - 0.02, h - 0.07, 0.018)
    k.voyant("voyant", b[0] + 0.14, Y - 0.02, h - 0.07, 0.018)
    k.b("chevron", ((b[0] + b[1]) / 2.0, Y - 0.006, 0.035), (b[1] - b[0], 0.012, 0.05))
    k.cable("noir", ((b[0] + b[1]) / 2.0, H.yb((b[2] + b[3]) / 2.0), h), R.p(FU - 0.6, FV + FSV / 2.0, 0.6), 0.08, 0.016)
    # bouteilles d'échantillonnage près de la sortie
    R.cuve("blanc", 0.3, 1.0, 0.0, 0.46, 0.075, 0.5, 16)
    R.cuve("blanc", 0.47, 1.0, 0.0, 0.46, 0.075, 0.5, 16)
    R.box("acier", 0.385, 0.9, 0.0, 0.34, 0.05, 0.4)
