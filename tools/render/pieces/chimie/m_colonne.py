"""COLONNE D'EXTRACTION (fo-extraction-column, 3×3) : colonne pulsée liquide-liquide, la plus HAUTE machine de la famille.
Fût de titane à trois sections de VERRE où se voient les deux phases lumineuses (lilas : solution aqueuse de terres rares,
en bas ; ambre : solvant, en haut ; interface dans la section du milieu), chambres de décantation renflées en pied et en
tête, échafaudage jaune à trois paliers et échelle, PULSEUR à piston chromé au pied (pièce mobile), trémie du concentré
(entrée des objets) et bacs à sels lilas et blancs (néodyme, yttrium : sortie des objets). Entrée nord x = 0 (solvant :
huile légère) ; pas de sortie de fluide.
"""
import math

import geo as G
import habille as H

CU, CV = 0.0, -0.32          # axe de la colonne
CR = 0.2                     # rayon du fût
Z_BAS, Z_FUT, Z_HAUT = 1.05, 4.45, 5.42
VERRES = ((1.38, 2.05, "lilas"), (2.3, 2.98, None), (3.23, 3.92, "ambre"))
EU, EV = 0.5, 0.42           # demi-écarts des poteaux de l'échafaudage
PALIERS = (1.22, 2.62, Z_FUT)
TAU = 2.0 * math.pi


def build(S, k, R):
    colonne(k, R)
    echafaudage(k, R)
    pulseur(k, R)
    tremie(k, R)
    bacs(k, R)
    raccords(k, R)


def colonne(k, R):
    # jupe, chambre de décantation basse, fût à sections, chambre haute, évent
    R.cyl("acier", CU, CV, 0.0, 0.2, 0.44, 32)
    R.rev("titane", CU, CV, [(0.2, 0.3), (0.3, 0.41), (0.82, 0.41), (Z_BAS, CR + 0.01)], 32)
    R.cerclages("acier", CU, CV, [0.36, 0.7], 0.412, 0.014, 0.022)
    z = Z_BAS
    for z0, z1, m in VERRES:
        R.cyl("titane", CU, CV, z, z0, CR, 28)
        # brides des deux bouts de la section, tirants, plateaux perforés devinés
        for zz in (z0, z1):
            R.cyl("acier_clair", CU, CV, zz - 0.035, zz + 0.035, CR + 0.045, 28)
        if m:
            R.cyl(m, CU, CV, z0 + 0.035, z1 - 0.035, CR - 0.02, 28)
        else:
            zi = (z0 + z1) / 2.0
            R.cyl("lilas", CU, CV, z0 + 0.035, zi, CR - 0.02, 28)
            R.cyl("ambre", CU, CV, zi, z1 - 0.035, CR - 0.02, 28)
            R.tore("noir", CU, CV, zi, CR - 0.02, 0.012, 32, 5)
        n = int((z1 - z0) / 0.13)
        for i in range(1, n):
            R.tore("noir", CU, CV, z0 + (z1 - z0) * i / n, CR - 0.018, 0.008, 32, 4)
        for i in range(6):
            a = TAU * (i + 0.5) / 6
            x, y, _ = R.p(CU, CV)
            px, py = x + (CR + 0.025) * math.cos(a), y + (CR + 0.025) * math.sin(a)
            k.axe("chrome", (px, py, z0), (px, py, z1), 0.011, 6)
        z = z1
    R.cyl("titane", CU, CV, z, Z_FUT, CR, 28)
    R.rev("titane", CU, CV, [(Z_FUT, CR), (Z_FUT + 0.15, 0.36), (Z_HAUT - 0.2, 0.36), (Z_HAUT - 0.05, 0.3), (Z_HAUT, 0.18),
                             (Z_HAUT + 0.03, 0.0)], 32)
    R.cerclages("acier", CU, CV, [Z_FUT + 0.35, Z_HAUT - 0.3], 0.362, 0.014, 0.022)
    # hublot ambre de la chambre haute (face sud absolue) et évent en col de cygne
    x, y, _ = R.p(CU, CV)
    k.b("acier", (x, y - 0.34, Z_HAUT - 0.5), (0.14, 0.06, 0.24))
    k.b("ambre", (x, y - 0.375, Z_HAUT - 0.5), (0.08, 0.008, 0.17))
    R.tuyau("acier", [(CU + 0.1, CV, Z_HAUT - 0.02), (CU + 0.1, CV, Z_HAUT + 0.3), (CU + 0.3, CV, Z_HAUT + 0.3),
                      (CU + 0.3, CV, Z_HAUT + 0.18)], 0.03, 0.06)
    R.cyl("rouge", CU - 0.12, CV, Z_HAUT - 0.06, Z_HAUT + 0.12, 0.035, 10)


def echafaudage(k, R):
    coins = [(CU + su * EU, CV + sv * EV) for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    for u, v in coins:
        R.box("jaune", u, v, 0.0, 0.05, 0.05, Z_FUT + 0.2)
        R.box("beton", u, v, 0.0, 0.12, 0.12, 0.05)
    lv = [0.0] + list(PALIERS)
    for i, z in enumerate(PALIERS):
        # plancher en caillebotis (cadre autour de la colonne), lisses
        ring = [R.p(u, v, z) for u, v in coins] + [R.p(*coins[0], z)]
        for a, b in zip(ring[:-1], ring[1:]):
            k.axe("jaune", a, b, 0.018, 6)
        for dv in (-EV + 0.12, EV - 0.12):
            R.box("noir", CU, CV + dv, z - 0.02, 2 * EU, 0.22, 0.02)
        for du in (-EU + 0.15, EU - 0.15):
            R.box("noir", CU + du, CV, z - 0.02, 0.28, 2 * EV, 0.02)
        k.rambarde("jaune", ring, 0.17, 0.3)
        # croix de contreventement entre deux paliers, sur deux faces opposées
        z0 = lv[i]
        for (ua, va), (ub, vb) in ((coins[0], coins[1]), (coins[3], coins[2]), (coins[0], coins[3]), (coins[1], coins[2])):
            k.axe("jaune", R.p(ua, va, z0 + 0.05), R.p(ub, vb, z - 0.05), 0.011, 5)
    # échelle sur la face sud absolue de l'échafaudage, côté est
    b = R.bornes(CU, CV, 2 * EU, 2 * EV)
    k.echelle("jaune", b[1] - 0.18, H.yb(b[3]) - 0.06, 0.0, Z_FUT + 0.15)
    # supports de la colonne à chaque palier
    for z in PALIERS:
        R.tore("acier", CU, CV, z + 0.02, CR + 0.06, 0.025, 28, 6)


def pulseur(k, R):
    # jambe de pulsation (sort de la chambre basse), corps du pulseur, piston chromé, moteur et volant
    pu, pv = 0.92, 0.38
    R.tuyau("titane", [(CU + 0.3, CV + 0.2, 0.55), (pu, CV + 0.2, 0.55), (pu, pv, 0.55), (pu, pv, 0.62)], 0.075, 0.12,
            bride_mat="acier_clair")
    R.caisson("car2", pu, pv, 0.0, 0.42, 0.36, 0.62, 0.02)
    R.cyl("acier", pu, pv, 0.62, 0.74, 0.12, 20)
    R.cyl("chrome", pu, pv, 0.74, 1.06, 0.04, 12)
    R.cyl("acier", pu, pv, 1.06, 1.12, 0.09, 16)
    R.box("acier", pu - 0.15, pv, 0.62, 0.05, 0.08, 0.55)
    R.box("acier", pu + 0.15, pv, 0.62, 0.05, 0.08, 0.55)
    R.box("acier", pu, pv, 1.15, 0.38, 0.1, 0.05)
    R.moteur("bleu", pu, pv + 0.32, 0.03, 0.3, 0.1, "noir", "u")
    x, y, _ = R.p(pu, pv)
    k.voyant("voyant_v", x - 0.12, y - 0.36 * H.D / 2.0 - 0.01, 0.48, 0.016)
    k.b("chevron", (x, y - 0.36 * H.D / 2.0 - 0.006, 0.08), (0.42, 0.012, 0.05))


def tremie(k, R):
    # trémie du concentré (entrée des objets) sur pieds, poudre lilas, vis vers la chambre basse
    tu, tv = -0.95, 0.42
    for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        R.box("acier", tu + su * 0.2, tv + sv * 0.17, 0.0, 0.04, 0.04, 0.98)
    R.prisme("car2", tu, tv, 0.62, 1.12, 0.18, 0.16, 2.6)
    R.box("car2", tu, tv, 1.12, 0.48, 0.42, 0.12)
    R.box("sel_lilas", tu, tv, 1.2, 0.42, 0.36, 0.05)
    R.box("acier", tu, tv, 1.24, 0.5, 0.03, 0.025)
    R.tuyau("car2", [(tu, tv, 0.62), (tu, tv, 0.45), (tu + 0.45, CV + 0.15, 0.45), (CU - 0.25, CV + 0.15, 0.45)], 0.055, 0.12)
    # pompe de charge et longue montée vers la chambre haute (phase aqueuse entre en tête)
    R.cyl("bleu", tu + 0.32, tv - 0.32, 0.0, 0.32, 0.09, 16)
    R.tuyau("acier", [(tu + 0.32, tv - 0.32, 0.32), (tu + 0.32, tv - 0.32, 0.55), (-EU - 0.08, CV + EV + 0.1, 0.55),
                      (-EU - 0.08, CV + EV + 0.1, Z_FUT + 0.6), (CU - 0.3, CV + 0.1, Z_FUT + 0.6)], 0.04, 0.12)


def bacs(k, R):
    # bacs à sels (sortie des objets) : néodyme lilas, yttrium blanc ; goulotte depuis la chambre basse
    for bu, m in ((0.05, "sel_lilas"), (0.45, "blanc")):
        bv = 1.08
        R.caisson("acier", bu, bv, 0.0, 0.36, 0.32, 0.22, 0.015)
        R.box("noir", bu, bv, 0.2, 0.3, 0.26, 0.02)
        x, y, _ = R.p(bu, bv)
        mesh = G.butte_polaire((x, y, 0.21), 0.14, 0.15, 0.09, G.Rnd(int(bu * 100) + 7), nr=6, na=20)
        k.put(m, mesh)
    R.tuyau("titane", [(CU + 0.12, CV + 0.25, 0.32), (CU + 0.12, 0.7, 0.32), (0.05, 0.85, 0.3)], 0.045, 0.1)
    # solvant chargé : descente de la tête vers le bac (phase organique sortante)
    R.tuyau("acier", [(CU + 0.36, CV - 0.05, Z_HAUT - 0.4), (EU + 0.1, CV - 0.05, Z_HAUT - 0.4), (EU + 0.1, CV - 0.05, 0.4),
                      (EU + 0.1, 0.85, 0.4), (0.45, 0.85, 0.32)], 0.04, 0.12)


def raccords(k, R):
    zr = 0.22
    # solvant (x = 0) : entre en pied de colonne (la phase légère monte)
    R.raccord(0.0, "n", zr, vers=[(0.0, -0.75, zr), (0.0, -0.75, 0.45), (0.0, CV - 0.2, 0.45)])
    R.vanne("acier", "rouge", (0.0, -0.95, zr + 0.09), 0.04, 0.06)
