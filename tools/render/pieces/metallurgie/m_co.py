"""FOUR À COKE (fo-coke-oven), 3×3 (x ±1,5 ; y ±2,12). CONCEPT §2.

Lecture : un bloc de brique strié de portes verticales entre leurs poutres d'ancrage, une rangée de colonnes montantes en col de cygne
vers le barillet, une cheminée de brique ; au SUD, une porte levée montre le gâteau de coke incandescent qui tombe dans le wagon
d'extinction. Variante C : fours « en ruche », dômes de brique à bouches incandescentes.
"""
import math

import commun as K
import geo as G
import outils as O

TAU = G.TAU
VAR = {
    "a": dict(ruche=False, cheminee=(1.18, 1.62, 0.24, 3.9), tour=True, quai=False, ouvert=2, gaz_est=False),
    "b": dict(ruche=False, cheminee=(-0.62, 1.72, 0.3, 4.5), tour=False, quai=True, ouvert=3, gaz_est=True),
    "c": dict(ruche=True, cheminee=(0.0, 1.6, 0.28, 4.2), tour=False, quai=False, ouvert=None),
}
X0, X1, YS, YN, ZT = -1.42, 0.98, -0.82, 1.02, 1.3
N_FOURS = 6


def cheminee(lot, M, cx, cy, r, h):
    K.caisson(lot, M["brique"], cx, cy, 0.0, r * 2.6, r * 2.6, 0.45, 0.03)
    lot.put(M["pierre"] if "pierre" in M else M["beton"], G.boite((cx, cy, 0.47), (r * 2.75, r * 2.75, 0.05)))
    K.rev(lot, M["brique"], cx, cy, [(0.45, r), (h - 0.2, r * 0.72), (h - 0.12, r * 0.85), (h, r * 0.85)], 26, cap=False)
    K.rev(lot, M["suie"], cx, cy, [(h, r * 0.85), (h - 0.12, r * 0.62), (h - 0.2, 0.0)], 20)
    for k in range(5):
        z = 0.9 + k * (h - 1.3) / 4.0
        rr = r - (r * 0.28) * (z - 0.45) / (h - 0.65)
        K.cerclage(lot, M["acier2"], cx, cy, z, rr, 0.04, 0.016, 26)
    # paratonnerre, échelle de crinoline
    lot.put(M["cuivre"], G.tube([(cx + r * 0.8, cy, h - 0.1), (cx + r * 0.8, cy, h + 0.35)], 0.008, 4))
    K.echelle(lot, M["acier2"], (cx, cy - r - 0.02, 0.5), (cx, cy - r * 0.72 - 0.02, h - 0.15), l=0.1)


def batterie(lot, M, v, rnd):
    pas = (X1 - X0) / N_FOURS
    # fondation et massif de brique
    K.caisson(lot, M["beton"], (X0 + X1) / 2, (YS + YN) / 2, 0.0, X1 - X0 + 0.14, YN - YS + 0.2, 0.12, 0.02)
    lot.put(M["brique"], G.prisme([(X0, YS), (X1, YS), (X1, YN), (X0, YN)], 0.12, ZT))
    lot.put(M["brique_j"], G.prisme([(X0 + 0.02, YS + 0.02), (X1 - 0.02, YS + 0.02), (X1 - 0.02, YN - 0.02), (X0 + 0.02, YN - 0.02)], ZT, ZT + 0.03))
    # pignons de brique, mur d'about
    for x in (X0 - 0.06, X1 + 0.06):
        K.caisson(lot, M["brique"], x, (YS + YN) / 2, 0.1, 0.12, YN - YS + 0.12, ZT + 0.12, 0.02)
    for i in range(N_FOURS + 1):
        x = X0 + i * pas
        # poutres d'ancrage (sud et nord), tirants au-dessus
        for y in (YS - 0.05, YN + 0.05):
            lot.put(M["acier2"], G.boite((x, y, 0.85), (0.07, 0.06, 1.6)))
        lot.put(M["acier_clair"], G.tube([(x, YS - 0.05, 1.55), (x, YN + 0.05, 1.55)], 0.011, 5))
        for y in (YS - 0.05, YN + 0.05):
            lot.put(M["fonte"], G.tour([(0.0, 0.03), (0.03, 0.025)], 8, "y", (x, y + (-0.04 if y < 0 else 0.0), 1.55), cap0=True, cap1=True))
    for i in range(N_FOURS):
        xc = X0 + (i + 0.5) * pas
        # porte côté coke (sud) ou fenêtre ouverte
        if i == v["ouvert"]:
            lot.put(M["noir"], G.boite((xc, YS - 0.005, 0.66), (pas * 0.62, 0.02, 1.02)))
            lot.put(M["fusion"], G.boite((xc, YS + 0.03, 0.66), (pas * 0.56, 0.02, 0.96)))
            lot.put(M["braise"], G.boite((xc, YS - 0.012, 0.66), (pas * 0.5, 0.012, 0.9)))
            # porte levée par le dégarnisseur
            lot.put(M["fonte"], G.boite((xc, YS - 0.06, 1.62), (pas * 0.66, 0.06, 0.95)))
            for z in (1.3, 1.6, 1.9):
                lot.put(M["acier2"], G.boite((xc, YS - 0.095, z), (pas * 0.7, 0.025, 0.05)))
            # guide de coke : cage vers le wagon
            for s in (-1, 1):
                gx = xc + s * pas * 0.36
                lot.put(M["acier2"], G.tube([(gx, YS - 0.08, 0.2), (gx, YS - 0.62, 0.2), (gx, YS - 0.62, 1.0), (gx, YS - 0.08, 1.05)], 0.02, 5))
                for k in range(4):
                    lot.put(M["acier2"], G.tube([(gx, YS - 0.08 - 0.13 * k, 0.2), (gx, YS - 0.08 - 0.13 * k, 1.02)], 0.009, 4))
            for s2 in (-1, 1):
                lot.put(M["acier2"], G.tube([(xc + s2 * pas * 0.36, YS - 0.08, 1.04), (xc + s2 * pas * 0.36, YS - 0.62, 1.0)], 0.014, 4))
            # coke qui croule hors du four, en cascade vers le wagon
            K.tas(lot, M["braise"], (xc, YS - 0.3, 0.14), 0.13, 0.26, 0.12, G.Rnd(5521), 26, 0.025, 0.045)
            K.tas(lot, M["fusion"], (xc, YS - 0.12, 0.3), 0.09, 0.08, 0.2, G.Rnd(5523), 12, 0.025, 0.04)
        else:
            lot.put(M["fonte"], G.boite((xc, YS - 0.03, 0.66), (pas * 0.68, 0.05, 1.04)))
            for z in (0.3, 0.66, 1.02):
                lot.put(M["acier2"], G.boite((xc, YS - 0.07, z), (pas * 0.74, 0.03, 0.05)))
            lot.put(M["acier_clair"], G.boite((xc, YS - 0.09, 0.55), (0.06, 0.02, 0.1)))
            # joints qui fuient : petites lueurs aux coins du haut
            for s in (-1, 1):
                lot.put(M["braise"], G.boite((xc + s * pas * 0.31, YS - 0.06, 1.15), (0.035, 0.012, 0.035)))
        # couvercles d'enfournement (3 par four)
        for y in (-0.42, 0.1, 0.62):
            K.rev(lot, M["fonte"], xc, y, [(ZT + 0.03, 0.075), (ZT + 0.06, 0.07), (ZT + 0.075, 0.045)], 14)
            lot.put(M["acier_clair"], G.tube([(xc - 0.03, y, ZT + 0.09), (xc + 0.03, y, ZT + 0.09)], 0.008, 4))
        # colonne montante en col de cygne vers le barillet
        p0 = (xc, YN - 0.18, ZT + 0.03)
        p1 = (xc, YN - 0.18, ZT + 0.55)
        p2 = (xc, YN + 0.18, ZT + 0.7)
        lot.put(M["acier"], G.tube(G.coudee([p0, p1, (xc, YN - 0.18, ZT + 0.7), p2], 0.08, 5), 0.065, 10))
        K.rev(lot, M["acier2"], xc, YN - 0.18, [(ZT + 0.66, 0.08), (ZT + 0.74, 0.08), (ZT + 0.78, 0.03)], 12)
        K.bride(lot, M["acier2"], (xc, YN - 0.18, ZT + 0.3), (0, 0, 1), 0.09, 0.02)
        lot.put(M["fonte"], G.tube([(xc, YN - 0.18, ZT + 0.1), (xc, YN - 0.18, ZT + 0.22)], 0.08, 10))
    # barillet (gros tube horizontal) sur chevalets ; départ du gaz vers l'est
    zb = ZT + 0.62
    yb = YN + 0.32
    lot.put(M["acier"], G.tour([(X0 - 0.1, 0.0), (X0 - 0.09, 0.16), (X1 + 0.35, 0.16)], 26, "x", (0.0, yb, zb)))
    for x in (X0 + 0.2, (X0 + X1) / 2, X1 - 0.2):
        lot.put(M["acier2"], G.tour([(x - 0.03, 0.165), (x - 0.02, 0.185), (x + 0.02, 0.185), (x + 0.03, 0.165)], 26, "x", (0.0, yb, zb)))
        for s in (-1, 1):
            lot.put(M["acier2"], G.tube([(x, yb + s * 0.16, 0.0), (x, yb + s * 0.05, zb - 0.14)], 0.022, 5))
    if v["gaz_est"]:
        O.tuyau(lot, M["acier"], M["acier2"], [(X1 + 0.35, yb, zb), (X1 + 0.42, yb, zb), (X1 + 0.42, yb + 0.45, zb), (X1 + 0.42, yb + 0.45, 0.1)], 0.12, rb=0.15)
    else:
        O.tuyau(lot, M["acier"], M["acier2"], [(X0 + 0.02, yb, zb), (X0 + 0.02, yb + 0.5, zb), (X0 + 0.02, yb + 0.5, 0.1)], 0.12, rb=0.15)
    # enfourneuse sur rails au toit
    for y in (-0.62, 0.84):
        lot.put(M["acier_clair"], G.boite(((X0 + X1) / 2, y, ZT + 0.05), (X1 - X0, 0.035, 0.035)))
    lx = X0 + (4.5 if v["ouvert"] != 4 else 1.5) * pas
    lot.put(M["acier2"], G.boite((lx, 0.11, ZT + 0.2), (0.36, 1.6, 0.06)))
    for (wy) in (-0.62, 0.84):
        for s in (-1, 1):
            lot.put(M["fonte"], G.tour([(-0.025, 0.05), (0.025, 0.05)], 12, "x", (lx + s * 0.14, wy, ZT + 0.12), cap0=True, cap1=True))
    for y in (-0.42, 0.1, 0.62):
        K.rev(lot, M["jaune"], lx, y, [(ZT + 0.12, 0.05), (ZT + 0.24, 0.05), (ZT + 0.5, 0.15), (ZT + 0.56, 0.15)], 4, cap=False)
        K.tas(lot, M["charbon"], (lx, y, ZT + 0.5), 0.1, 0.1, 0.05, G.Rnd(int(5500 + y * 100)), 8, 0.02, 0.03)
    K.caisson(lot, M["jaune"], lx, 0.95, ZT + 0.23, 0.32, 0.22, 0.22, 0.02)
    lot.put(M["verre"], G.boite((lx, 0.835, ZT + 0.36), (0.22, 0.01, 0.07)))
    # machine défourneuse au nord : bâti, crémaillère du bélier
    K.caisson(lot, M["jaune"], 0.45, 1.78, 0.0, 0.62, 0.52, 0.8, 0.03)
    lot.put(M["acier2"], G.boite((0.45, 1.42, 0.55), (0.12, 0.4, 0.1)))
    for y in (1.62, 1.95):
        lot.put(M["acier_clair"], G.boite((0.0, y, 0.02), (2.9, 0.035, 0.035)))
    K.armoire(lot, M, 0.45, 1.95, 0.8, 0.3, 0.12, 0.2)


def wagon(lot, M, x, y, rnd, plein=True):
    """Wagon d'extinction sur rails (sud) : caisse ouverte, coke incandescent."""
    for yy in (y - 0.2, y + 0.2):
        lot.put(M["acier_clair"], G.boite((0.0, yy, 0.03), (2.95, 0.035, 0.04)))
    for k in range(11):
        lot.put(M["fonte"], G.boite((-1.38 + 0.276 * k, y, 0.012), (0.08, 0.56, 0.025)))
    K.caisson(lot, M["acier"], x, y, 0.12, 0.62, 0.5, 0.3, 0.02)
    lot.put(M["noir"], G.boite((x, y, 0.415), (0.54, 0.42, 0.01)))
    if plein:
        K.tas(lot, M["braise"], (x, y, 0.4), 0.24, 0.18, 0.08, rnd, 28, 0.025, 0.045)
        K.tas(lot, M["coke"], (x + 0.12, y - 0.05, 0.4), 0.14, 0.14, 0.06, rnd, 12, 0.025, 0.04)
    for s in (-1, 1):
        for t in (-1, 1):
            lot.put(M["fonte"], G.tour([(-0.025, 0.07), (0.025, 0.07)], 12, "y", (x + s * 0.2, y + t * 0.23, 0.08), cap0=True, cap1=True))
    lot.put(M["chevron"], G.boite((x, y - 0.255, 0.22), (0.6, 0.012, 0.06)))


def tour_extinction(lot, M, x, y):
    K.caisson(lot, M["beton"], x, y, 0.0, 0.6, 0.8, 1.9, 0.03)
    for k in range(6):
        lot.put(M["acier2"], G.boite((x, y - 0.405, 1.0 + 0.13 * k), (0.5, 0.03, 0.04), 0.0, 0.5))
    K.rev(lot, M["beton"], x, y, [(1.9, 0.3), (2.3, 0.26), (2.32, 0.27)], 4, cap=False)
    lot.put(M["noir"], G.boite((x, y, 2.24), (0.36, 0.36, 0.01)))
    lot.put(M["noir"], G.boite((x, y - 0.405, 0.35), (0.4, 0.02, 0.5)))
    O.tuyau(lot, M["acier"], M["acier2"], [(x + 0.32, y + 0.2, 0.1), (x + 0.32, y + 0.2, 2.0), (x + 0.1, y + 0.2, 2.1)], 0.045)


def ruches(lot, M, rnd):
    """Fours en ruche : banc de brique, 4 dômes à bouche arquée incandescente, rails de chargement au faîte."""
    K.caisson(lot, M["beton"], 0.0, 0.25, 0.0, 2.95, 1.75, 0.1, 0.02)
    lot.put(M["brique"], G.prisme([(-1.45, -0.55), (1.45, -0.55), (1.45, 1.05), (-1.45, 1.05)], 0.1, 0.5))
    for i, xc in enumerate((-1.08, -0.36, 0.36, 1.08)):
        yc, r = 0.25, 0.36
        pr = [(0.5 + r * math.sin(t), r * math.cos(t) + 0.0) for t in [k / 10.0 * math.pi / 2 for k in range(11)]]
        K.rev(lot, M["brique"], xc, yc, [(0.5, r + 0.02)] + pr, 30)
        K.rev(lot, M["brique_j"], xc, yc, [(0.5 + r - 0.02, 0.12), (0.5 + r + 0.04, 0.1), (0.5 + r + 0.06, 0.0)], 14)
        lot.put(M["suie"], G.sphere((xc, yc, 0.5 + r - 0.01), 0.1, 12, 4, zmin=0.0))
        # bouche arquée au sud, cadre de brique jaune, coke incandescent
        my = yc - r - 0.02
        lot.put(M["brique_j"], G.boite((xc, -0.56, 0.32), (0.4, 0.06, 0.44)))
        lot.put(M["noir"], G.boite((xc, -0.6, 0.33), (0.24, 0.02, 0.32)))
        hot = "fusion" if i in (1, 2) else "braise"
        lot.put(M[hot], G.boite((xc, -0.585, 0.3), (0.2, 0.02, 0.24)))
        arc = [(xc + 0.16 * math.cos(t), -0.6, 0.46 + 0.1 * math.sin(t)) for t in [k / 10.0 * math.pi for k in range(11)]]
        lot.put(M["brique_j"], G.tube(arc, 0.03, 6))
        lot.put(M[hot], G.boite((xc, -0.6, 0.47), (0.2, 0.012, 0.06)))
        K.tas(lot, M["coke"], (xc, -0.78, 0.0), 0.16, 0.14, 0.08, rnd, 10, 0.025, 0.04)
    for y in (0.05, 0.45):
        lot.put(M["acier_clair"], G.boite((0.0, y, 0.92), (2.9, 0.035, 0.035)))
        for x in (-1.44, -0.72, 0.0, 0.72, 1.44):
            lot.put(M["acier2"], G.boite((x, y, 0.71), (0.05, 0.05, 0.42)))
    # wagonnet de houille sur le pont
    K.caisson(lot, M["acier"], 0.7, 0.25, 0.95, 0.42, 0.46, 0.22, 0.02)
    K.tas(lot, M["charbon"], (0.7, 0.25, 1.15), 0.18, 0.18, 0.06, rnd, 14, 0.02, 0.035)
    # carneau vers la cheminée
    lot.put(M["brique"], G.prisme([(-0.25, 1.05), (0.25, 1.05), (0.25, 1.5), (-0.25, 1.5)], 0.1, 0.45))
    # brouette de coke et rails au sud
    for yy in (-1.55, -1.85):
        lot.put(M["acier_clair"], G.boite((0.0, yy, 0.03), (2.95, 0.035, 0.04)))
    for k in range(11):
        lot.put(M["fonte"], G.boite((-1.38 + 0.276 * k, -1.7, 0.012), (0.08, 0.5, 0.025)))
    wagon(lot, M, -0.5, -1.7, rnd)


def build(S, lot, v):
    M = K.matieres(S)
    v = VAR[v]
    rnd = G.Rnd(5503)
    lot.put(M["beton"], G.prisme([(-1.48, -2.08), (1.48, -2.08), (1.48, 2.08), (-1.48, 2.08)], 0.0, 0.025))
    if v["ruche"]:
        ruches(lot, M, rnd)
    else:
        batterie(lot, M, v, rnd)
        pas = (X1 - X0) / N_FOURS
        xo = X0 + (v["ouvert"] + 0.5) * pas
        if v["quai"]:
            # quai de coke incliné au sud : coke étalé, incandescent près du four
            lot.put(M["brique"], G.loft([[(X0, YS - 0.1, 0.25), (X1, YS - 0.1, 0.25)], [(X0, -1.55, 0.06), (X1, -1.55, 0.06)]], closed=False))
            for k in range(60):
                x = rnd.f(X0 + 0.05, X1 - 0.05)
                t = rnd.f(0.0, 1.0)
                y = YS - 0.1 - t * (1.45 + YS)
                hot = abs(x - xo) < 0.45 and t < 0.6
                lot.put(M["braise" if hot else "coke"], G.sphere((x, y, 0.25 - t * 0.19 + 0.03), rnd.f(0.03, 0.05), 5, 2))
            wagon(lot, M, xo + 0.6, -1.85, rnd, plein=False)
        else:
            wagon(lot, M, xo, -1.5, rnd)
    cx, cy, cr, ch = v["cheminee"]
    cheminee(lot, M, cx, cy, cr, ch)
    if v["tour"]:
        tour_extinction(lot, M, 1.12, -1.52)
    return {}
