"""ÉLECTROLYSEUR (fo-electrolyzer, 3×3), ronde 2 (composition refaite, CONCEPT gardé ; CRITIQUE.md §3).

Masse centrale : EMPILEMENT de 16 cellules (axe nord-sud en vue « nord ») posé sur un berceau à pieds (pas de dalle), plaques
d'acier sombre et joints rouges en alternance (pas de 0,11 tuile, 7 px HR), une ligne cyan toutes les 2 plaques sur le
dessus et les flancs (lisible dans les 4 directions), deux flasques épais à nervures, 8 tirants LISSES à écrous hexagonaux.
Au nord : redresseur-transformateur haut à radiateurs et ventilateur ; 4 BARRES DE CUIVRE de 11 px : 2 sur le flasque
nord, 2 qui courent sur le dessus de la pile jusqu'au flasque sud (face sud = flasque et cosses de cuivre). Aux angles sud,
sur les brides de sortie : séparateurs hauts (H2 blanc à l'ouest, O2 bleu à l'est) à hublot cyan. Côtés : armoire de
commande (ouest), refroidisseur de lessive (est) ; au nord-ouest : réservoir d'eau déminéralisée (arrivée nord x = 0).
"""
import habille as H

SU0, SU1 = -0.55, 0.55          # largeur de la pile (u)
SV0, SV1 = -0.43, 1.13          # plaques (v), flasques au-delà
FL = 0.17                       # épaisseur des flasques (tuiles)
SZ0, SZ1 = 0.3, 1.5             # hauteur des plaques
NP = 14                         # plaques
RU, RV, RSU, RSV, RZ = 0.72, -0.98, 1.3, 0.7, 1.75      # redresseur
TU, TV, TR = -0.86, -0.97, 0.33                           # réservoir d'eau
SEP = ((-1.0, 0.92, "blanc"), (1.0, 0.92, "bleu"))       # séparateurs
SR, SZ = 0.3, 2.35


def build(S, k, R):
    pile(k, R)
    redresseur(k, R)
    cuivre(k, R)
    separateurs(k, R)
    reservoir(k, R)
    cotes(k, R)
    raccords(k, R)


def pile(k, R):
    vc = (SV0 + SV1) / 2.0
    L = SV1 - SV0 + 2 * FL
    # berceau : deux longerons sur trois paires de pieds
    for u in (-0.36, 0.36):
        R.box("acier", u, vc, 0.14, 0.09, L + 0.1, 0.12)
        for v in (SV0 - FL / 2.0, vc, SV1 + FL / 2.0):
            R.box("acier", u, v, 0.0, 0.14, 0.12, 0.15)
            R.box("beton", u, v, 0.0, 0.2, 0.18, 0.03)
    # plaques et joints ; une ligne cyan toutes les 2 plaques
    pas = (SV1 - SV0) / NP
    for i in range(NP):
        v = SV0 + pas * i
        R.box("plaque_pile", (SU0 + SU1) / 2.0, v + pas * 0.35, SZ0, SU1 - SU0, pas * 0.68, SZ1 - SZ0)
        if i < NP - 1:
            vg = v + pas * 0.84
            if i % 2 == 0:
                R.box("cyan", (SU0 + SU1) / 2.0, vg, SZ0 + 0.02, SU1 - SU0 + 0.012, pas * 0.2, SZ1 - SZ0 - 0.012)
            else:
                R.box("joint_pile", (SU0 + SU1) / 2.0, vg, SZ0 + 0.01, SU1 - SU0 - 0.01, pas * 0.32, SZ1 - SZ0 - 0.02)
    # flasques épais à nervures
    for sg, v in ((-1, SV0 - FL / 2.0), (1, SV1 + FL / 2.0)):
        R.caisson("car2", 0.0, v, 0.12, 1.3, FL, SZ1 + 0.14 - 0.12, 0.025)
        for du in (-0.5, -0.17, 0.17, 0.5):
            R.box("acier", du, v + sg * (FL / 2.0 + 0.025), 0.15, 0.05, 0.05, SZ1 - 0.1)
    # 8 tirants lisses, écrous hexagonaux sur les flasques
    va, vb = SV0 - FL - 0.06, SV1 + FL + 0.06
    for u, z in ((-0.6, 0.55), (0.6, 0.55), (-0.6, 1.28), (0.6, 1.28), (-0.44, SZ1 + 0.06), (0.44, SZ1 + 0.06),
                 (-0.14, SZ1 + 0.06), (0.14, SZ1 + 0.06)):
        R.axe("acier_clair", (u, va, z), (u, vb, z), 0.032, 10)
        for v in (SV0 - FL - 0.02, SV1 + FL + 0.02):
            R.cyl("chrome", u, v, z - 0.06, z + 0.06, 0.06, 6)


def redresseur(k, R):
    R.box("beton", RU, RV, 0.0, RSU + 0.06, RSV + 0.06, 0.05)
    R.caisson("car", RU, RV, 0.05, RSU, RSV, RZ - 0.05, 0.035)
    b = R.bornes(RU, RV, RSU, RSV)
    H.ceinture(k, "acier", b, RZ - 0.07, 0.06, 0.025)
    H.ceinture(k, "acier", b, 0.08, 0.05, 0.025)
    # radiateurs : lames verticales sur la face sud absolue et sur les flancs (silhouette)
    Y = H.yb(b[3])
    n = int((b[1] - b[0]) / 0.07)
    for i in range(n):
        x = b[0] + 0.05 + (b[1] - b[0] - 0.1) * i / max(1, n - 1)
        k.bz("car2", x, Y - 0.06, 0.18, 0.022, 0.12, RZ - 0.5)
    for zz in (0.16, RZ - 0.34):
        k.bz("acier", (b[0] + b[1]) / 2.0, Y - 0.06, zz, b[1] - b[0] - 0.04, 0.13, 0.03)
    for x in (b[0], b[1]):
        sg = -1 if x == b[0] else 1
        for j in range(5):
            y = H.yb(b[2] + (b[3] - b[2]) * (j + 0.5) / 5)
            k.bz("car2", x + sg * 0.05, y, 0.2, 0.1, 0.03, RZ - 0.55)
    # plaque « haute tension » et voyants
    k.b("chevron", ((b[0] + b[1]) / 2.0, Y - 0.13, RZ - 0.24), (0.5, 0.012, 0.07))
    k.voyant("voyant_r", b[0] + 0.12, Y - 0.13, RZ - 0.24, 0.022)
    k.voyant("voyant_v", b[1] - 0.12, Y - 0.13, RZ - 0.24, 0.022)
    # ventilateur de toit (pièce mobile en phase 3), capot, traversées haute tension au nord
    R.box("noir", RU + 0.22, RV, RZ, 0.56, 0.5, 0.04)
    R.ventilo(RU + 0.22, RV, RZ + 0.13, 0.24, corps="car2", lame="acier_clair", grille="acier", moyeu="acier")
    for du in (-0.48, -0.28):
        R.rev("blanc", RU + du, RV - 0.12, [(RZ, 0.06), (RZ + 0.04, 0.06), (RZ + 0.06, 0.04), (RZ + 0.09, 0.06), (RZ + 0.11, 0.04),
                                           (RZ + 0.14, 0.06), (RZ + 0.16, 0.035), (RZ + 0.24, 0.035)], 12)


def cuivre(k, R):
    """4 barres de cuivre de 11 px : 2 (+) du toit du redresseur sur le flasque nord ; 2 (-) d'une gaine à barres accrochée
    au flanc ouest du redresseur, sur le dessus de la pile (isolateurs de laiton), retombées et cosses sur le flasque sud."""
    vn, vs = SV0 - FL / 2.0, SV1 + FL / 2.0
    zr = RZ + 0.04
    for u in (0.24, 0.44):
        R.box("cuivre", u, (-1.1 + vn) / 2.0, zr, 0.17, vn + 1.1 + 0.05, 0.05)
        R.box("cuivre", u, vn, SZ1 + 0.14, 0.17, 0.06, zr + 0.05 - SZ1 - 0.14)
    R.caisson("car", -0.09, -0.95, 0.85, 0.32, 0.5, 1.0, 0.02)
    R.box("acier", -0.2, -0.95, 0.0, 0.05, 0.05, 0.86)
    zt = 1.85
    for u in (-0.18, 0.02):
        R.box("cuivre", u, (-1.05 + vs) / 2.0, zt, 0.17, vs + 1.05, 0.05)
        R.box("cuivre", u, vs + FL / 2.0 + 0.03, 0.8, 0.17, 0.05, zt + 0.05 - 0.8)
        R.box("acier_clair", u, vs + FL / 2.0 + 0.06, 0.82, 0.1, 0.03, 0.12)
        for v in (0.0, 0.6):
            R.rev("laiton", u, v, [(SZ1 + 0.1, 0.035), (zt, 0.035)], 10)


def separateurs(k, R):
    for u, v, m in SEP:
        R.cyl("acier", u, v, 0.0, 0.12, SR + 0.04, 24)
        R.cuve(m, u, v, 0.12, SZ, SR, 0.5)
        R.cerclages("acier", u, v, [0.32, 1.1, SZ - 0.4], SR + 0.002, 0.014, 0.022)
        x, y, _ = R.p(u, v)
        Y = y - SR
        # hublot vertical (face sud absolue) : cadre boulonné, verre où bouillonne le liquide cyan
        k.b("acier", (x, Y + 0.03, 1.15), (0.2, 0.07, 1.0))
        k.b("cyan", (x, Y - 0.006, 1.12), (0.12, 0.008, 0.82))
        for dz in (0.68, 1.58):
            k.b("acier_clair", (x, Y - 0.012, dz), (0.22, 0.02, 0.04))
        k.rivets("riv", [(x + sx * 0.085, Y - 0.01, 1.15 + sz * 0.42) for sx in (-1, 1) for sz in (-1, 1)], (0.0, -1.0, 0.0), 0.014)
        # indicateur de niveau à tube de verre sur le côté extérieur
        xs = x + (SR + 0.06) * (-1 if u < 0 else 1)
        k.axe("cyan", (xs, y - 0.05, 0.45), (xs, y - 0.05, 1.7), 0.02, 8)
        for z in (0.42, 1.73):
            k.axe("acier", (xs, y - 0.05, z), (x, y - 0.05, z), 0.018, 6)
        # soupape et plate-forme de tête
        uc = u + (0.14 if u < 0 else -0.14)
        R.cyl("acier_clair", uc, v, SZ - 0.06, SZ + 0.12, 0.03, 10)
        R.cyl("rouge", uc, v, SZ + 0.12, SZ + 0.19, 0.05, 10)


def reservoir(k, R):
    R.cyl("acier", TU, TV, 0.0, 0.1, TR + 0.04, 24)
    R.cuve("isolant", TU, TV, 0.1, 1.7, TR, 0.4)
    R.cerclages("acier", TU, TV, [0.45, 0.9, 1.35], TR + 0.002, 0.014, 0.022)
    x, y, _ = R.p(TU, TV)
    k.axe("bleu", (x + 0.18, y - TR - 0.02, 0.35), (x + 0.18, y - TR - 0.02, 1.4), 0.022, 8)
    k.echelle("jaune", x - 0.12, y - TR - 0.05, 0.1, 1.72)


def cotes(k, R):
    # armoire de commande à l'ouest
    cu, cv, su, sv, h = -1.12, 0.2, 0.44, 0.5, 1.0
    R.caisson("car2", cu, cv, 0.0, su, sv, h, 0.02)
    b = R.bornes(cu, cv, su, sv)
    Y = H.yb(b[3])
    xc = (b[0] + b[1]) / 2.0
    H.porte(k, "car2", "acier_clair", xc, b[3], 0.05, b[1] - b[0] - 0.08, h - 0.3)
    k.b("noir", (xc, Y - 0.012, h - 0.12), (b[1] - b[0] - 0.08, 0.012, 0.13))
    k.b("cyan", (xc - 0.04, Y - 0.02, h - 0.12), (0.16, 0.004, 0.07))
    k.voyant("voyant_v", xc + 0.13, Y - 0.02, h - 0.1, 0.017)
    k.b("chevron", (xc, Y - 0.006, 0.03), (b[1] - b[0], 0.012, 0.05))
    k.cable("noir", (xc, H.yb((b[2] + b[3]) / 2.0), h), R.p(RU - RSU / 2.0, RV + RSV / 2.0, 0.6), 0.12, 0.016)
    # refroidisseur de lessive à l'est, sur berceaux
    R.box("acier", 1.12, -0.35, 0.0, 0.3, 0.07, 0.24)
    R.box("acier", 1.12, 0.35, 0.0, 0.3, 0.07, 0.24)
    R.echangeur(1.12, 0.0, 0.18, 0.95, 0.2, "car2", "acier", "v", True, 3)


def raccords(k, R):
    zr = 0.22
    # eau (x = 0) : vers le réservoir, puis du réservoir au flasque nord
    R.raccord(0.0, "n", zr, vers=[(0.0, -1.22, zr), (TU + 0.3, -1.22, zr)])
    R.tuyau("acier", [(TU + 0.25, TV + 0.12, 1.25), (-0.4, TV + 0.12, 1.25), (-0.4, SV0 - FL - 0.04, 1.25)], 0.05, 0.1)
    # gaz : flancs de la pile vers la tête de chaque séparateur (H2 blanc, O2 bleu)
    for u, v, m in SEP:
        su = -1 if u < 0 else 1
        R.tuyau(m, [(su * 0.66, 0.35, 1.2), (u, 0.35, 1.2), (u, 0.35, SZ + 0.18), (u, v, SZ + 0.18), (u, v, SZ - 0.05)],
                0.055, 0.1, bride_mat="acier")
        # retour de lessive (pied du séparateur vers le pied de la pile)
        R.tuyau("acier", [(u, v - 0.2, 0.22), (u, 0.62, 0.22), (su * 0.6, 0.62, 0.22)], 0.035, 0.08)
        # sortie (x = ±1) : sous le séparateur
        R.raccord(u, "s", zr, vers=[(u, 1.05, zr)], mat_suite=m)
