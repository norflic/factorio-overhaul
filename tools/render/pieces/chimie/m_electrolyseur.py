"""ÉLECTROLYSEUR (fo-electrolyzer, 3×3) : EMPILEMENT de cellules couché (plaques bipolaires bleu-noir, joints rouges, lignes
lumineuses cyan entre paquets), serré entre deux flasques à nervures par des tirants filetés ; redresseur-transformateur à
radiateurs et ventilateur (pièce mobile) ; grosses BARRES DE CUIVRE sur isolateurs ; deux SÉPARATEURS gaz-liquide à
hublots cyan (H2 blanc à l'ouest, O2 bleu à l'est) et leurs cols de cygne. Entrée nord x = 0 (eau) ; sorties sud x = −1
(H2, Cl2, D2) et +1 (O2, ou Cl2).
"""
import habille as H

PU0, PU1, PV, PSV, PZ0, PZ1 = -1.12, 0.52, -0.6, 0.6, 0.24, 1.02     # paquet de plaques
FL = 0.1                                                              # épaisseur des flasques
RU, RV, RSU, RSV, RZ = 1.1, -0.72, 0.6, 1.0, 1.0                      # redresseur
SEP = ((-1.0, 0.52, "blanc"), (1.0, 0.52, "bleu"))                   # séparateurs
SR, SZ1 = 0.25, 1.5


def build(S, k, R):
    pile(k, R)
    redresseur(k, R)
    separateurs(k, R)
    raccords(k, R)
    abords(k, R)


def pile(k, R):
    # longerons et pieds
    for v in (PV - 0.2, PV + 0.2):
        R.box("acier", (PU0 + PU1) / 2.0, v, 0.0, PU1 - PU0 + 0.5, 0.07, 0.24)
    for u in (PU0 - 0.1, (PU0 + PU1) / 2.0, PU1 + 0.1):
        R.box("beton", u, PV, 0.0, 0.16, PSV + 0.1, 0.05)
    # plaques bipolaires, joints, lignes lumineuses tous les 5 paquets
    n = 24
    pas = (PU1 - PU0) / n
    for i in range(n):
        u = PU0 + pas * (i + 0.5)
        R.box("plaque_pile", u - pas * 0.15, PV, PZ0, pas * 0.7, PSV, PZ1 - PZ0)
        if i % 5 == 2:
            R.box("cyan", u + pas * 0.35, PV, PZ0 + 0.03, pas * 0.3, PSV - 0.05, PZ1 - PZ0 - 0.06)
        else:
            R.box("joint_pile", u + pas * 0.35, PV, PZ0 + 0.015, pas * 0.3, PSV - 0.02, PZ1 - PZ0 - 0.03)
    # flasques à nervures
    for su, u in ((-1, PU0 - FL / 2.0), (1, PU1 + FL / 2.0)):
        R.caisson("car2", u, PV, 0.1, FL, PSV + 0.18, PZ1 - 0.1 + 0.12, 0.02)
        for dv in (-0.24, 0.0, 0.24):
            R.box("acier", u + su * (FL / 2.0 + 0.02), PV + dv, 0.12, 0.04, 0.05, PZ1 - 0.02)
    # tirants filetés (dessus et flancs) et écrous
    for dv, z in ((-0.33, PZ1 + 0.03), (0.33, PZ1 + 0.03), (-0.33, PZ0 + 0.08), (0.33, PZ0 + 0.08), (0.0, PZ1 + 0.05)):
        R.axe("chrome", (PU0 - FL - 0.08, PV + dv, z), (PU1 + FL + 0.08, PV + dv, z), 0.022, 8)
        for u in (PU0 - FL - 0.05, PU1 + FL + 0.05):
            R.cyl("acier_clair", u, PV + dv, z - 0.035, z + 0.035, 0.04, 6)
    # collecteur d'alimentation (eau) le long du dessus, piquages vers les paquets
    hv = PV - 0.18
    R.tuyau("acier", [(PU0 - 0.02, hv, PZ1 + 0.16), (PU1 + 0.02, hv, PZ1 + 0.16)], 0.045, 0.08)
    for i in range(0, n, 4):
        u = PU0 + pas * (i + 0.5)
        R.axe("acier_clair", (u, hv, PZ1 + 0.13), (u, hv, PZ1), 0.014, 6)
    # collecteurs de gaz (H2 et O2) sur la face sud locale de la pile
    for dz in (0.72, 0.42):
        R.tuyau("acier", [(PU0 + 0.02, PV + PSV / 2.0 + 0.06, dz), (PU1 - 0.02, PV + PSV / 2.0 + 0.06, dz)], 0.035, 0.08)


def redresseur(k, R):
    R.box("beton", RU, RV, 0.0, RSU + 0.08, RSV + 0.08, 0.05)
    R.caisson("car", RU, RV, 0.05, RSU, RSV, RZ - 0.05, 0.03)
    b = R.bornes(RU, RV, RSU, RSV)
    H.ceinture(k, "acier", b, RZ - 0.06, 0.05, 0.02)
    # radiateurs : lames verticales sur les faces est, ouest et sud (absolues)
    Y = H.yb(b[3])
    n = int((b[1] - b[0]) / 0.06)
    for i in range(n):
        x = b[0] + 0.03 + (b[1] - b[0] - 0.06) * i / max(1, n - 1)
        k.bz("car2", x, Y - 0.05, 0.12, 0.018, 0.1, RZ - 0.3)
    k.bz("acier", (b[0] + b[1]) / 2.0, Y - 0.05, RZ - 0.18, b[1] - b[0], 0.11, 0.025)
    k.bz("acier", (b[0] + b[1]) / 2.0, Y - 0.05, 0.1, b[1] - b[0], 0.11, 0.025)
    # plaque signalétique « haute tension » (chevrons) et voyants
    k.b("chevron", ((b[0] + b[1]) / 2.0, Y - 0.11, RZ - 0.27), (0.3, 0.012, 0.06))
    k.voyant("voyant_r", b[0] + 0.06, Y - 0.11, RZ - 0.27, 0.016)
    k.voyant("voyant_v", b[1] - 0.06, Y - 0.11, RZ - 0.27, 0.016)
    # ventilateur de toit (pièce mobile) et son capot
    R.box("noir", RU, RV + 0.18, RZ, 0.46, 0.46, 0.05)
    R.ventilo(RU, RV + 0.18, RZ + 0.16, 0.2, corps="car2", lame="acier_clair", grille="acier", moyeu="acier")
    # traversées haute tension (isolateurs) sur le toit, côté nord
    for du in (-0.15, 0.15):
        R.rev("blanc", RU + du, RV - 0.32, [(RZ, 0.05), (RZ + 0.05, 0.05), (RZ + 0.07, 0.035), (RZ + 0.1, 0.05), (RZ + 0.12, 0.035),
                                             (RZ + 0.15, 0.05), (RZ + 0.17, 0.03), (RZ + 0.24, 0.03)], 12)
    # barres de cuivre : du redresseur aux deux flasques, sur isolateurs
    zb = PZ1 + 0.32
    for j, (u_fin, dv) in enumerate(((PU1 + FL / 2.0, 0.12), (PU0 - FL / 2.0, -0.12))):
        v = PV + dv
        R.box("cuivre", (RU + u_fin) / 2.0 + 0.02, v, zb + 0.04 * j, abs(RU - u_fin) + 0.04, 0.07, 0.035)
        R.box("cuivre", RU - 0.02, v, RZ + 0.02, 0.07, 0.07, zb + 0.04 * j - RZ)
        R.box("cuivre", u_fin, v, PZ1 - 0.08, 0.07, 0.07, zb + 0.04 * j - PZ1 + 0.1)
        for u in ([PU1 - 0.25, PU0 + 0.5, PU0 + 1.0] if j else [PU1 - 0.1]):
            R.rev("blanc", u, v, [(PZ1 + 0.06, 0.03), (zb + 0.04 * j, 0.03)], 10)


def separateurs(k, R):
    for u, v, m in SEP:
        R.cyl("acier", u, v, 0.0, 0.12, SR + 0.04, 24)
        R.cuve(m, u, v, 0.12, SZ1, SR, 0.5)
        R.cerclages("acier", u, v, [0.3, SZ1 - 0.35], SR + 0.002, 0.012, 0.02)
        # hublot vertical (face sud absolue) : cadre, verre lumineux où bouillonne le liquide
        x, y, _ = R.p(u, v)
        Y = y - SR
        k.b("acier", (x, Y + 0.02, 0.78), (0.15, 0.06, 0.62))
        k.b("cyan", (x, Y - 0.012, 0.75), (0.08, 0.008, 0.5))
        for dz in (0.47, 1.03):
            k.b("acier_clair", (x, Y - 0.018, dz), (0.17, 0.02, 0.035))
        k.rivets("riv", [(x + sx * 0.06, Y - 0.014, 0.78 + sz * 0.27) for sx in (-1, 1) for sz in (-1, 1)], (0.0, -1.0, 0.0), 0.012)
        # indicateur de niveau à tube de verre sur le côté
        xs = x + (SR + 0.05) * (1 if u < 0 else -1)
        k.axe("cyan", (xs, y - 0.03, 0.35), (xs, y - 0.03, 1.15), 0.016, 6)
        for z in (0.32, 1.18):
            k.axe("acier", (xs, y - 0.03, z), (x, y - 0.03, z), 0.014, 6)
        # col de cygne : gaz du haut vers la bride, soupape
        uc = u + (0.12 if u < 0 else -0.12)
        R.cyl("acier_clair", uc, v, SZ1 - 0.05, SZ1 + 0.12, 0.025, 10)
        R.cyl("rouge", uc, v, SZ1 + 0.12, SZ1 + 0.18, 0.04, 10)


def raccords(k, R):
    zr = 0.22
    hv = PV - 0.18
    # eau (x = 0) : montée derrière la pile vers le collecteur du dessus
    R.raccord(0.0, "n", zr, vers=[(0.0, -1.18, zr), (0.0, -1.18, PZ1 + 0.16), (0.0, hv, PZ1 + 0.16)])
    R.collier("acier_clair", (0.0, -1.18, 0.62), (0.0, 0.0, 1.0), 0.09, 0.03, 0.03)
    # gaz de la pile vers chaque séparateur (entrée en tête)
    for (u, v, m), dz, us in zip(SEP, (0.72, 0.42), (-0.85, 0.35)):
        R.tuyau(m if m == "blanc" else "acier", [(us, PV + PSV / 2.0 + 0.06, dz), (us, 0.06, dz), (us, 0.06, SZ1 + 0.22),
                                                (u, 0.06, SZ1 + 0.22), (u, v, SZ1 + 0.22), (u, v, SZ1 + 0.1)], 0.045, 0.1)
    # sorties (x = −1 et +1) : sous chaque séparateur ; retour de liquide vers la pile
    for u, v, m in SEP:
        R.raccord(u, "s", zr, vers=[(u, 0.78, zr)], mat_suite=m)
        R.tuyau("acier", [(u, v - 0.1, 0.18), (u, PV + PSV / 2.0 + 0.12, 0.18), (u * 0.6, PV + PSV / 2.0 + 0.12, 0.18)],
                0.03, 0.08)


def abords(k, R):
    # pupitre de conduite entre les séparateurs : écran cyan, voyants, chevrons
    cu, cv, su, sv, h = 0.0, 0.92, 0.5, 0.3, 0.58
    R.caisson("car2", cu, cv, 0.0, su, sv, h, 0.02)
    b = R.bornes(cu, cv, su, sv)
    Y = H.yb(b[3])
    xc = (b[0] + b[1]) / 2.0
    H.porte(k, "car2", "acier_clair", xc, b[3], 0.05, b[1] - b[0] - 0.1, h - 0.24)
    k.b("noir", (xc, Y - 0.012, h - 0.1), (b[1] - b[0] - 0.08, 0.012, 0.12))
    k.b("cyan", (xc - 0.05, Y - 0.02, h - 0.1), (0.14, 0.004, 0.07))
    k.voyant("voyant_v", xc + 0.13, Y - 0.02, h - 0.08, 0.015)
    k.voyant("voyant_r", xc + 0.13, Y - 0.02, h - 0.13, 0.015)
    k.b("chevron", (xc, Y - 0.006, 0.03), (b[1] - b[0], 0.012, 0.05))
    # câbles du pupitre vers le redresseur
    k.cable("noir", (xc, H.yb((b[2] + b[3]) / 2.0), h), R.p(RU - RSU / 2.0, RV + RSV / 2.0 - 0.1, 0.5), 0.1, 0.012)
