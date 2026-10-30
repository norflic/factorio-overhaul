"""ÂGE 15 (Néant) : la citadelle sur la carcasse (emprise 16×8, k = 2). Nez à droite.

C'est un BÂTIMENT : talus, courtine crénelée percée de meurtrières, grande porte et escalier, contreforts, hall à
baies hautes, donjon et flèche. La carcasse du vaisseau reste le squelette visible : les couples sont devenus des
arches d'or qui sortent des contreforts et passent au-dessus du hall, l'épine dorsale d'or porte des plaques (le dos
du dinosaure), le crâne (nez blindé) garde sa verrière devenue un regard incandescent, les deux tuyères brûlent comme
des braseros. Bible : noir chaud (dominante), or chauffé, lumière incandescente blanc-or.
"""
import math

import bati as B
import geo as G
import mat as MT
import vaisseau as V

K = 2.0
VENTRE = (-1.2, 1.05)
COTES = (-0.95, -0.47, 0.42, 0.88)
BALAI = 0.25


def matieres(S):
    M = {}
    M["pierre"] = MT.surface("o15_pierre", (0.034, 0.029, 0.026), rough=0.75, met=0.05, tole=(0.5, 0.26), joint=0.5,
                             var=0.16, coulures=0.4, rouille=(0.02, 0.015, 0.012), usure=0.85, nu=(0.15, 0.13, 0.11),
                             crasse=0.5, crasse_col=(0.01, 0.008, 0.007), relief=0.6, graine=51)
    M["plaque"] = MT.surface("o15_plaque", (0.045, 0.038, 0.034), rough=0.45, met=0.65, coulures=0.3, rouille=(0.03, 0.02, 0.012),
                             usure=0.85, nu=(0.24, 0.21, 0.18), crasse=0.5, graine=52)
    M["plaque2"] = MT.surface("o15_plaque2", (0.06, 0.05, 0.044), rough=0.45, met=0.65, usure=0.85, nu=(0.26, 0.23, 0.2),
                              crasse=0.5, graine=53)
    M["noyau"] = MT.surface("o15_noyau", (0.018, 0.016, 0.015), rough=0.5, met=0.7, usure=0.4, crasse=0.6, graine=54)
    M["or"] = MT.surface("o15_or", (0.72, 0.45, 0.16), rough=0.38, met=0.95, coulures=0.35, rouille=(0.1, 0.06, 0.025),
                         usure=0.55, nu=(0.95, 0.78, 0.48), crasse=0.7, crasse_col=(0.05, 0.03, 0.012), graine=55)
    M["or_sombre"] = MT.surface("o15_or_sombre", (0.4, 0.24, 0.08), rough=0.45, met=0.9, usure=0.6, nu=(0.8, 0.6, 0.3),
                                crasse=0.7, crasse_col=(0.04, 0.025, 0.01), graine=56)
    M["ardoise"] = MT.surface("o15_ardoise", (0.028, 0.026, 0.026), rough=0.55, met=0.2, tole=(0.32, 0.18), joint=0.4,
                              var=0.2, usure=0.7, nu=(0.12, 0.11, 0.1), crasse=0.4, relief=0.5, graine=57)
    M["brule"] = MT.surface("o15_brule", (0.03, 0.022, 0.018), rough=0.7, met=0.5, usure=0.0, crasse=0.7, graine=58)
    M["lum"] = MT.lumiere(S, "o15_lum", (1.0, 0.82, 0.5), 3.2, main=0.3)
    M["feu"] = MT.lumiere(S, "o15_feu", (1.0, 0.64, 0.28), 8.0, main=0.3)
    M["oeil"] = MT.lumiere(S, "o15_oeil", (1.0, 0.7, 0.35), 4.0, main=0.3)
    M["verre"] = MT.verre("o15_verre", col=(0.03, 0.022, 0.012), reflet=(0.3, 0.22, 0.1))
    return M


def build(S, lot):
    M = matieres(S)
    V.reglage(nac_x0=-1.35)
    k = K
    r = G.Rnd(1515)
    noirs = [M["plaque"], M["plaque2"]]

    def mats(rr, i, j, zone):
        x = rr.f()
        if zone == "coque" and i in (8, 11):
            return M["or"]
        if zone == "nacelle" and i == 0:
            return M["or"]
        if x < 0.1:
            return M["or_sombre"]
        return noirs[int(rr.f() * 2) % 2]

    def saut(xm, am):
        if VENTRE[0] - 0.05 < xm < VENTRE[1] + 0.05:
            return True
        return 1.15 < xm < 2.5 and abs(am - math.pi / 2) < 0.95

    V.corps(lot, k, r, M["noyau"], M["or"], M["brule"], M["or_sombre"], mats, saut=saut, ventre=VENTRE, feu=M["feu"],
            Mcloison=M["plaque"])
    sc = V.surf_coque(k)
    V.doublures(lot, sc, 6, lambda rr: M["or_sombre"] if rr.f() < 0.3 else M["plaque2"], r, (1.3, 2.9), (1.8, 3.4), M["or_sombre"])
    V.verriere(lot, M["verre"], M["or"], k)
    for x in (1.45, 1.75, 2.05):                                  # le regard : fentes incandescentes sous la verrière
        p = V.point(x, math.pi / 2 + 0.55, k, 0.03)
        lot.put(M["oeil"], V.pose_plane(G.boite((0, 0, 0.0), (0.34, 0.07, 0.04)), p, V.normale(x, math.pi / 2 + 0.55, k)))
    V.hublots(lot, M["or"], M["lum"], (1.35, 1.6, 1.85), math.pi - 0.5, k, r=0.06)
    for s in (-1, 1):
        V.canard(lot, M["plaque"], M["or"], s, k)
        V.aile(lot, M["plaque"], M["noyau"], M["or"], M["or_sombre"], s, k, rnd=r)
    tip = V.derive(lot, M["plaque2"], M["or"], k, x0=-1.3)
    lot.put(M["lum"], G.sphere(G.add(tip, (0, 0, 0.06)), 0.07, 10, 5))
    # piles de pierre sous le crâne et sous les tuyères, bagues d'or
    for (x, y) in ((1.45, -0.45), (1.45, 0.45), (2.35, 0.0)):
        zb = (V.profil(x)[0] - V.profil(x)[3]) * k
        lot.put(M["pierre"], G.boite((x * k, y * k, zb / 2), (0.42, 0.42, zb)))
        lot.put(M["or"], G.boite((x * k, y * k, zb - 0.06), (0.5, 0.5, 0.08)))
    for s in (-1, 1):
        for x in (-2.25, -1.6):
            zb = (V.NAC_Z - V.NAC_R) * k
            lot.put(M["pierre"], G.boite((x * k, s * V.NAC_Y * k, zb / 2), (0.5, 0.5, zb)))
            lot.put(M["or"], G.boite((x * k, s * V.NAC_Y * k, zb - 0.06), (0.58, 0.58, 0.08)))
    # ------------------------------------------------------------ la citadelle
    hx0, hx1 = VENTRE[0] * k, VENTRE[1] * k
    xm = (hx0 + hx1) / 2
    y1, y2 = 1.95, 1.35
    z0, z1, z2, z3, z4 = 0.55, 2.25, 3.5, 4.1, 5.9
    # talus
    lot.put(M["pierre"], G.prisme([(hx0 - 0.35, -y1 - 0.45), (hx1 + 0.35, -y1 - 0.45), (hx1 + 0.35, y1 + 0.45), (hx0 - 0.35, y1 + 0.45)],
                                  0.0, z0, top_scale=0.97))
    lot.put(M["or_sombre"], G.boite((xm, -y1 - 0.33, z0 + 0.02), (hx1 - hx0 + 0.5, 0.06, 0.05)))
    # courtine : meurtrières et grande porte au sud
    mur_s = [(x, 0.15, z0 + 0.45, z1 - 0.4) for x in (-1.9, -0.99, 0.83, 1.8)]
    gx = -0.4
    porte = (gx, 0.8, z0, z0 + 1.25)
    for s in (-1, 1):
        B.mur(lot, M["pierre"], M["or"], M["lum"], "x", s * y1, hx0, hx1, z0, z1, 0.3, mur_s + ([porte] if s < 0 else []),
              cote=s, appui=False)
    for x in (hx0, hx1):
        lot.put(M["pierre"], G.boite((x, 0.0, (z0 + z1) / 2), (0.3, 2 * y1, z1 - z0)))
    # arc de la porte (or), vantaux, lanterne
    lot.put(M["or"], G.tour([(-y1 - 0.2, 0.46), (-y1 + 0.02, 0.46), (-y1 + 0.02, 0.36), (-y1 - 0.2, 0.36)], 24, "y",
                            (gx, 0.0, z0 + 1.25), a0=-math.pi / 2, a1=math.pi / 2))
    lot.put(M["or_sombre"], G.boite((gx, -y1 + 0.05, z0 + 0.62), (0.76, 0.06, 1.22)))
    lot.put(M["lum"], G.boite((gx, -y1 - 0.04, z0 + 1.5), (0.3, 0.05, 0.12)))
    # créneaux
    for s in (-1, 1):
        n = int((hx1 - hx0) / 0.5)
        for i in range(n + 1):
            x = hx0 + (hx1 - hx0) * i / n
            lot.put(M["pierre"], G.boite((x, s * y1, z1 + 0.16), (0.26, 0.32, 0.32)))
            lot.put(M["or_sombre"], G.boite((x, s * y1, z1 + 0.34), (0.3, 0.36, 0.04)))
        lot.put(M["or"], G.boite((xm, s * (y1 + 0.16), z1 - 0.06), (hx1 - hx0 + 0.3, 0.06, 0.08)))
    # contreforts aux couples, consoles d'or où les côtes sortent du mur
    for x in COTES:
        xx = V.point_cote(x, 0.05, k, 0.08, 0.0, True, BALAI)[0]
        for s in (-1, 1):
            lot.put(M["pierre"], G.prisme([(xx - 0.24, s * y1), (xx + 0.24, s * y1), (xx + 0.24, s * (y1 + 0.55)), (xx - 0.24, s * (y1 + 0.55))],
                                          0.0, 1.2, top_scale=0.9, top_shift=(0.0, -s * 0.05)))
            lot.put(M["pierre"], G.prisme([(xx - 0.2, s * y1), (xx + 0.2, s * y1), (xx + 0.2, s * (y1 + 0.32)), (xx - 0.2, s * (y1 + 0.32))],
                                          1.2, z1 + 0.1, top_scale=0.9))
            lot.put(M["or"], G.boite((xx, s * (y1 + 0.27), 1.24), (0.5, 0.58, 0.07)))
            lot.put(M["or"], G.prisme([(xx - 0.28, s * (y1 - 0.15)), (xx + 0.28, s * (y1 - 0.15)), (xx + 0.28, s * (y1 + 0.4)),
                                       (xx - 0.28, s * (y1 + 0.4))], z1 + 0.1, z1 + 0.3, top_scale=0.85))
    # hall haut : pilastres d'or, baies hautes, toit d'ardoise à faîtière d'or
    baies = [(x, 0.24, z1 + 0.25, z2 - 0.25) for x in (-1.6, -1.2, -0.45, 0.25, 1.3)]
    B.plancher(lot, M["pierre"], hx0, hx1, -y1, y1, z1 + 0.02, 0.1)
    for s in (-1, 1):
        B.mur(lot, M["pierre"], M["or_sombre"], M["lum"], "x", s * y2, hx0 + 0.3, hx1 - 0.3, z1, z2, 0.22, baies, cote=s)
        for x in [V.point_cote(c, 0.6, k, 0.0, 0.0, True, BALAI)[0] for c in COTES]:
            lot.put(M["or_sombre"], G.boite((x, s * (y2 + 0.08), (z1 + z2) / 2), (0.1, 0.08, z2 - z1)))
        lot.put(M["or"], G.boite((xm, s * (y2 + 0.1), z2 - 0.04), (hx1 - hx0 - 0.5, 0.1, 0.08)))
    for x in (hx0 + 0.3, hx1 - 0.3):
        lot.put(M["pierre"], G.boite((x, 0.0, (z1 + z2) / 2), (0.22, 2 * y2, z2 - z1)))
    B.toit(lot, M["ardoise"], M["or"], hx0 + 0.3, hx1 - 0.3, -y2, y2, z2, z3, debord=0.14, joints=0.0)
    for xl in (-1.75, -1.2, 0.95, 1.5):
        B.lucarne(lot, M["pierre"], M["or_sombre"], M["or"], M["lum"], xl, -0.75, z2 + (z3 - z2) * 0.23, w=0.34, h=0.42,
                  prof=0.45, cote=-1)
    # donjon et flèche (traversé par l'épine)
    tx, tw = -0.1, 0.55
    lot.put(M["pierre"], G.boite((tx, 0.0, (z2 + z4) / 2), (2 * tw - 0.1, 2 * tw - 0.1, z4 - z2)))
    for s in (-1, 1):
        B.mur(lot, M["pierre"], M["or"], M["lum"], "x", s * (tw + 0.01), tx - tw, tx + tw, z3 + 0.3, z4 - 0.3, 0.04,
              [(tx, 0.22, z3 + 0.6, z4 - 0.55)], cote=s)
    lot.put(M["or"], G.boite((tx, 0.0, z4 + 0.05), (2 * tw + 0.16, 2 * tw + 0.16, 0.1)))
    for (dx, dy) in ((-1, -1), (1, -1), (-1, 1), (1, 1), (0, -1), (0, 1), (-1, 0), (1, 0)):
        lot.put(M["pierre"], G.boite((tx + dx * (tw - 0.06), dy * (tw - 0.06), z4 + 0.27), (0.18, 0.18, 0.34)))
        lot.put(M["or"], G.boite((tx + dx * (tw - 0.06), dy * (tw - 0.06), z4 + 0.46), (0.22, 0.22, 0.04)))
    lot.put(M["or"], G.prisme([(tx - 0.4, -0.4), (tx + 0.4, -0.4), (tx + 0.4, 0.4), (tx - 0.4, 0.4)], z4 + 0.1, z4 + 1.5, top_scale=0.04))
    lot.put(M["lum"], G.sphere((tx, 0.0, z4 + 1.55), 0.09, 12, 6))
    # ------------------------------------------------------------ le squelette : arches d'or, épine à plaques dorsales
    haut = 1.1
    for x in COTES:
        V.cote(lot, M["or"], x, k, ep=0.26, prof=0.16, saillie=0.08, a0=0.05, a1=math.pi - 0.05, haut=haut, rond=True, balai=BALAI)
    zs = V.point(COTES[0], math.pi / 2, k, 0.08)[2] + haut + 0.1
    epine = [(-2.45 * k, 0.0, V.z_dessus(-2.45, 0.0) * k + 0.1), (COTES[0] * k - 0.6, 0.0, zs), (COTES[-1] * k + 0.6, 0.0, zs),
             (1.6 * k, 0.0, V.z_dessus(1.15, 0.0) * k + 0.1)]
    pts = G.coudee(epine, 0.7, 8)
    lot.put(M["or"], G.tube(pts, 0.15, 8))
    for i in range(9):
        t = (i + 0.5) / 9
        x = COTES[0] * k - 0.4 + (COTES[-1] * k - COTES[0] * k + 0.8) * t
        h = 0.35 + 0.25 * math.sin(math.pi * t)
        if abs(x - tx) < tw + 0.15:
            continue
        lot.put(M["or_sombre"], G.prisme([(x - 0.2, -0.04), (x + 0.2, -0.04), (x + 0.05, 0.04), (x - 0.05, 0.04)], zs + 0.1, zs + 0.1 + h,
                                         top_scale=0.15, top_shift=(-0.08, 0.0)))
    # braseros aux angles du talus, grand escalier au sud
    for (x, y) in ((hx1 + 0.15, -y1 - 0.25), (hx1 + 0.15, y1 + 0.25)):
        lot.put(M["pierre"], G.prisme([(x - 0.2, y - 0.2), (x + 0.2, y - 0.2), (x + 0.2, y + 0.2), (x - 0.2, y + 0.2)], z0, z0 + 1.1, top_scale=0.8))
        lot.put(M["or"], G.tour([(z0 + 1.1, 0.12), (z0 + 1.18, 0.24), (z0 + 1.3, 0.26), (z0 + 1.3, 0.2)], 16, "z", (x, y, 0.0)))
        lot.put(M["feu"], G.tour([(z0 + 1.22, 0.2), (z0 + 1.34, 0.12), (z0 + 1.4, 0.0)], 12, "z", (x, y, 0.0)))
    B.escalier(lot, M["pierre"], (gx, -y1 - 1.35, 0.0), (gx, -y1 - 0.45, z0), 1.0, 5, M["or"])
    return {}
