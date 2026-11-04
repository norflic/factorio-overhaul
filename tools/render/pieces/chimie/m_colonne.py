"""COLONNE D'EXTRACTION (fo-extraction-column, 3×3), ronde 2 (CRITIQUE.md §4) : colonne pulsée liquide-liquide, la plus HAUTE
machine de la famille, désormais POSÉE SUR UNE MASSE : grosse chambre de décantation basse (1,7 tuile), pulseur au sud-est
(jambe horizontale, cylindre à tige chromée, moteur et volant), bac à sels lilas au sud-ouest, réservoir de solvant ambre
au nord-ouest, trémie du concentré au nord-est. Fût de 0,6 tuile dans un échafaudage de 1,3 tuile, trois fenêtres d'environ
0,7 tuile où se voient les deux phases COLORÉES de jour (lilas en bas, ambre en haut, interface dans celle du milieu),
chambre de tête renflée, garde-corps laiton. Entrée nord x = 0 (solvant) ; pas de sortie de fluide (sels = objets).
"""
import math

import geo as G
import habille as H

CU, CV = 0.0, -0.25          # axe de la colonne
CR = 0.3                     # rayon du fût
DR = 0.85                    # rayon de la chambre basse
Z_BAS, Z_FUT, Z_HAUT = 1.25, 4.75, 5.72
VERRES = ((1.35, 2.3, "lilas"), (2.5, 3.45, None), (3.65, 4.6, "ambre"))
EU, EV = 0.62, 0.5           # demi-écarts des poteaux de l'échafaudage (posé sur la chambre basse)
PALIERS = (2.42, 3.57, Z_FUT)
TAU = 2.0 * math.pi


def build(S, k, R):
    chambre(k, R)
    colonne(k, R)
    echafaudage(k, R)
    pulseur(k, R)
    bac(k, R)
    decanteur(k, R)
    solvant(k, R)
    tremie(k, R)
    raccords(k, R)


def chambre(k, R):
    R.cyl("beton", CU, CV, 0.0, 0.08, DR + 0.06, 40)
    R.rev("titane", CU, CV, [(0.08, DR - 0.06), (0.16, DR), (0.92, DR), (1.1, 0.6), (Z_BAS, CR + 0.03)], 40)
    R.cerclages("acier", CU, CV, [0.3, 0.62, 0.86], DR + 0.002, 0.018, 0.026)
    R.boulons_rond("riv", CU, CV, 1.0, 0.72, 20, 0.018)
    for zz, rr in ((1.06, 0.66), (1.16, 0.47)):
        R.tore("acier", CU, CV, zz, rr, 0.012, 48, 4)
    R.boulons_rond("riv", CU, CV, 1.17, 0.42, 14, 0.016)
    # hublot de l'interface basse et trou d'homme (face sud absolue)
    x, y, _ = R.p(CU, CV)
    Y = y - DR
    k.b("acier", (x - 0.3, Y + 0.05, 0.55), (0.24, 0.1, 0.3))
    k.b("lilas", (x - 0.3, Y - 0.006, 0.55), (0.16, 0.008, 0.2))
    k.axe("acier", (x + 0.25, Y + 0.05, 0.5), (x + 0.25, Y - 0.05, 0.5), 0.15, 18)
    k.axe("acier_clair", (x + 0.25, Y - 0.05, 0.5), (x + 0.25, Y - 0.08, 0.5), 0.17, 18)
    k.b("chevron", (x, Y - 0.01, 0.13), (0.6, 0.012, 0.05))


def colonne(k, R):
    z = Z_BAS
    for z0, z1, m in VERRES:
        R.cyl("titane", CU, CV, z, z0, CR, 32)
        for zz in (z0, z1):
            R.cyl("acier_clair", CU, CV, zz - 0.04, zz + 0.04, CR + 0.055, 32)
        if m:
            R.cyl(m, CU, CV, z0 + 0.04, z1 - 0.04, CR - 0.02, 32)
        else:
            zi = z0 + (z1 - z0) * 0.42
            R.cyl("lilas", CU, CV, z0 + 0.04, zi, CR - 0.02, 32)
            R.cyl("ambre", CU, CV, zi, z1 - 0.04, CR - 0.02, 32)
            R.tore("noir", CU, CV, zi, CR - 0.02, 0.016, 40, 5)
        n = int((z1 - z0) / 0.19)
        for i in range(1, n):
            R.tore("noir", CU, CV, z0 + (z1 - z0) * i / n, CR - 0.018, 0.012, 40, 4)
        x, y, _ = R.p(CU, CV)
        for i in range(6):
            a = TAU * (i + 0.5) / 6
            px, py = x + (CR + 0.03) * math.cos(a), y + (CR + 0.03) * math.sin(a)
            k.axe("chrome", (px, py, z0), (px, py, z1), 0.018, 6)
        z = z1
    R.cyl("titane", CU, CV, z, Z_FUT, CR, 32)
    R.rev("titane", CU, CV, [(Z_FUT, CR), (Z_FUT + 0.15, 0.44), (Z_HAUT - 0.2, 0.44), (Z_HAUT - 0.05, 0.36), (Z_HAUT, 0.2),
                             (Z_HAUT + 0.03, 0.0)], 36)
    R.cerclages("acier", CU, CV, [Z_FUT + 0.35, Z_HAUT - 0.3], 0.442, 0.016, 0.024)
    x, y, _ = R.p(CU, CV)
    k.b("acier", (x, y - 0.42, Z_HAUT - 0.55), (0.18, 0.08, 0.28))
    k.b("ambre", (x, y - 0.465, Z_HAUT - 0.55), (0.11, 0.008, 0.2))
    R.tuyau("acier", [(CU + 0.12, CV, Z_HAUT - 0.02), (CU + 0.12, CV, Z_HAUT + 0.3), (CU + 0.34, CV, Z_HAUT + 0.3),
                      (CU + 0.34, CV, Z_HAUT + 0.18)], 0.035, 0.07)
    R.cyl("rouge", CU - 0.14, CV, Z_HAUT - 0.08, Z_HAUT + 0.12, 0.04, 10)


def echafaudage(k, R):
    coins = [(CU + su * EU, CV + sv * EV) for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    z0 = 1.0
    for u, v in coins:
        R.box("jaune", u, v, z0 - 0.1, 0.06, 0.06, Z_FUT + 0.22 - z0 + 0.1)
        R.box("acier", u, v, z0 - 0.12, 0.12, 0.12, 0.05)
    lv = [z0] + list(PALIERS)
    for i, z in enumerate(PALIERS):
        ring = [R.p(u, v, z) for u, v in coins] + [R.p(*coins[0], z)]
        for a, b in zip(ring[:-1], ring[1:]):
            k.axe("jaune", a, b, 0.022, 6)
        for dv in (-EV + 0.13, EV - 0.13):
            R.box("noir", CU, CV + dv, z - 0.03, 2 * EU, 0.24, 0.03)
        for du in (-EU + 0.16, EU - 0.16):
            R.box("noir", CU + du, CV, z - 0.03, 0.3, 2 * EV, 0.03)
        k.rambarde("laiton", ring, 0.17, 0.32)
        za = lv[i]
        for (ua, va), (ub, vb) in ((coins[0], coins[1]), (coins[3], coins[2]), (coins[0], coins[3]), (coins[1], coins[2])):
            k.axe("jaune", R.p(ua, va, za + 0.05), R.p(ub, vb, z - 0.05), 0.016, 5)
    b = R.bornes(CU, CV, 2 * EU, 2 * EV)
    k.echelle("jaune", b[1] - 0.2, H.yb(b[3]) - 0.07, z0, Z_FUT + 0.15)
    for z in PALIERS:
        R.tore("acier", CU, CV, z + 0.02, CR + 0.07, 0.028, 32, 6)


def pulseur(k, R):
    # jambe de pulsation horizontale (de la chambre basse), cylindre à tige chromée, moteur et volant au sud-est
    pu, pv = 1.02, 0.78
    R.tuyau("titane", [(CU + 0.6, CV + 0.35, 0.45), (pu, CV + 0.35, 0.45), (pu, pv - 0.3, 0.45)], 0.1, 0.14, bride_mat="acier_clair")
    R.caisson("car2", pu, pv, 0.0, 0.5, 0.62, 0.32, 0.02)
    R.echangeur(pu, pv - 0.05, 0.3, 0.42, 0.17, "acier_clair", "acier", "v", True, 2)
    R.axe("chrome", (pu, pv + 0.2, 0.47), (pu, pv + 0.42, 0.47), 0.045, 12)
    R.box("acier", pu, pv + 0.44, 0.32, 0.22, 0.05, 0.3)
    R.moteur("bleu", pu - 0.3, pv + 0.1, 0.32, 0.32, 0.11, "noir", "v")
    R.tore("acier", pu + 0.27, pv + 0.25, 0.48, 0.15, 0.025, 28, 6)
    R.axe("acier", (pu + 0.27, pv + 0.25, 0.32), (pu + 0.27, pv + 0.25, 0.5), 0.02, 8)
    x, y, _ = R.p(pu, pv)
    k.voyant("voyant_v", x - 0.18, y - 0.31 * H.D - 0.01, 0.24, 0.018)


def bac(k, R):
    # bac à sels (sortie des objets) : néodyme lilas en tas, rebord d'acier, goulotte depuis la chambre basse
    bu, bv = -1.02, 0.98
    R.caisson("acier", bu, bv, 0.0, 0.86, 0.8, 0.32, 0.02)
    R.box("noir", bu, bv, 0.3, 0.76, 0.7, 0.02)
    x, y, _ = R.p(bu, bv)
    k.put("sel_lilas", G.butte_polaire((x, y, 0.31), 0.33, 0.45, 0.19, G.Rnd(11), nr=8, na=28))
    k.put("blanc", G.butte_polaire((x + 0.22, y + 0.3, 0.31), 0.11, 0.13, 0.09, G.Rnd(5), nr=5, na=18))
    R.tuyau("titane", [(CU - 0.55, CV + 0.4, 0.45), (bu + 0.2, bv - 0.3, 0.45), (bu + 0.2, bv - 0.15, 0.38)], 0.06, 0.12)


def decanteur(k, R):
    """Mélangeur-décanteur au sud (fonction : étage de lavage du solvant) : bac bas à 3 compartiments, couvercles, 3 agitateurs,
    regard où se voit la couche ambre sur la couche lilas. Remplit le sud de l'emprise (charte M1)."""
    du, dv, su, sv, h = 0.08, 1.1, 1.05, 0.56, 0.36
    R.caisson("car2", du, dv, 0.0, su, sv, h, 0.02)
    b = R.bornes(du, dv, su, sv)
    Y = H.yb(b[3])
    H.ceinture(k, "acier", b, h - 0.04, 0.04, 0.02)
    x0, x1 = b[0], b[1]
    for i in range(3):
        x = x0 + (x1 - x0) * (i + 0.5) / 3
        # couvercle, moteur d'agitateur, voyant
        cx, cy = x, H.yb((b[2] + b[3]) / 2.0)
        k.bz("acier_clair", cx, cy, h, (x1 - x0) / 3 - 0.06, (b[3] - b[2]) * H.D - 0.1, 0.025)
        k.cyl("bleu", cx, cy, h + 0.025, h + 0.2, 0.065, 14)
        k.cyl("acier", cx, cy, h + 0.2, h + 0.24, 0.045, 10)
        if i < 2:
            k.b("noir", (x + (x1 - x0) / 6, Y - 0.006, h / 2.0), (0.025, 0.01, h - 0.08))
    # regard horizontal : deux couches de liquide
    k.b("acier", ((x0 + x1) / 2.0, Y - 0.02, 0.2), ((x1 - x0) * 0.7, 0.03, 0.17))
    k.b("ambre", ((x0 + x1) / 2.0, Y - 0.036, 0.235), ((x1 - x0) * 0.62, 0.006, 0.05))
    k.b("lilas", ((x0 + x1) / 2.0, Y - 0.036, 0.175), ((x1 - x0) * 0.62, 0.006, 0.05))
    k.b("chevron", ((x0 + x1) / 2.0, Y - 0.006, 0.03), (x1 - x0, 0.012, 0.045))


def solvant(k, R):
    # réservoir de solvant (huile légère) au nord-ouest, peint ambre, jauge
    su, sv, sr = -1.02, -1.02, 0.4
    R.cyl("acier", su, sv, 0.0, 0.1, sr + 0.04, 24)
    R.cuve("jaune", su, sv, 0.1, 1.35, sr, 0.4)
    R.cerclages("acier", su, sv, [0.4, 0.9], sr + 0.002, 0.014, 0.022)
    x, y, _ = R.p(su, sv)
    k.axe("ambre", (x + 0.15, y - sr - 0.02, 0.3), (x + 0.15, y - sr - 0.02, 1.15), 0.022, 8)
    R.tuyau("acier", [(su + 0.3, sv + 0.2, 0.4), (CU - 0.45, CV - 0.35, 0.4)], 0.05, 0.1)


def tremie(k, R):
    # trémie du concentré (entrée des objets) au nord-est, sur pieds ; pompe de charge et montée vers la tête
    tu, tv = 1.02, -0.98
    for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        R.box("acier", tu + su * 0.2, tv + sv * 0.17, 0.0, 0.05, 0.05, 1.05)
    R.prisme("car2", tu, tv, 0.7, 1.22, 0.18, 0.16, 2.6)
    R.box("car2", tu, tv, 1.22, 0.5, 0.44, 0.12)
    R.box("sel_lilas", tu, tv, 1.3, 0.44, 0.38, 0.05)
    R.box("acier", tu, tv, 1.34, 0.52, 0.03, 0.03)
    R.cyl("bleu", tu - 0.3, tv + 0.35, 0.0, 0.3, 0.09, 16)
    R.tuyau("acier", [(tu, tv, 0.7), (tu, tv, 0.5), (tu - 0.3, tv + 0.35, 0.3)], 0.045, 0.08)
    R.tuyau("acier", [(tu - 0.3, tv + 0.35, 0.3), (EU + 0.16, CV - EV - 0.1, 0.3), (EU + 0.16, CV - EV - 0.1, Z_FUT + 0.6),
                      (CU + 0.3, CV - 0.1, Z_FUT + 0.6)], 0.045, 0.12)
    # solvant chargé : descente de la tête vers le bac à sels (ouest)
    R.tuyau("acier", [(CU - 0.42, CV + 0.05, Z_HAUT - 0.45), (-EU - 0.1, CV + 0.05, Z_HAUT - 0.45), (-EU - 0.1, CV + 0.05, 1.18),
                      (-0.85, 0.62, 1.18), (-0.85, 0.62, 0.5)], 0.045, 0.12)


def raccords(k, R):
    zr = 0.22
    # solvant (x = 0) : vers le réservoir ambre
    R.raccord(0.0, "n", zr, vers=[(0.0, -1.22, zr), (-0.72, -1.22, zr)])
    R.vanne("acier", "rouge", (-0.4, -1.22, zr), 0.05, 0.06)
