"""Four · Âge 3 · Vapeur (ère I, 2×2, niveaux 5 et 6). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 3. S'exécute DANS
Blender.

En 3 mots : « chaudière couchée, dôme de vapeur, cheminée cerclée ». La chambre est une CHAUDIÈRE DE LOCOMOTIVE couchée
d'est en ouest sur un foyer peint en vert locomotive : virole de cuivre rose cerclée de laiton, rangées de rivets, boîte
à fumée à l'est, DÔME DE VAPEUR de laiton, soupapes et sifflet, deux manomètres et un niveau d'eau ambré sur la face
sud ; caisse à charbon de bois verni derrière ; CHEMINÉE de cuivre CERCLÉE de laiton à couronne évasée (la fumée).
Palette 60/30/10 (ages.PALETTE[3]) : cuivre rose / vert locomotive / laiton ; lumière ambre.
"""
import math

import ages
import corps
import formes as F
import parts as PT
import parts2 as P2
from repere import Y

EPOQUE = 3
NOM = ages.NOMS[3]
TRIPLET = ("chaudière couchée", "dôme de vapeur", "cheminée cerclée")
FOYER = ages.FOYER[3]
HABILLAGE = dict(ages.CORPS[3], foyer="cuivre_sombre")
Z_BASE = 0.62
R_CH = 0.36
X0, X1 = -0.84, 0.6
YN_CH = 0.1


def matieres(metal, M):
    ages.matieres(3, metal, M)


def chambre(g, c):
    M = g.M
    T = c.T
    zs, xa = T["sole_h"], T["xa"]
    corps.boite(g, -xa, xa, T["y_av"], T["y_ar"], zs, Z_BASE, [M["vert_loco"], M["vert_pont"], M["vert_pont2"]],
                ins=(0.02, 0.02, 0.02), panel=0.3, faces="ts")
    g.box((0, Y(T["y_av"]) - 0.01, Z_BASE - 0.03), (2 * xa, 0.03, 0.04), M["laiton_capot"], "hard", what="liseré")
    y = Y(YN_CH)
    zc = Z_BASE + R_CH - 0.02
    # berceaux
    for x in (-0.55, 0.3):
        g.box((x, y, Z_BASE + 0.08), (0.08, 0.55, 0.16), M["cuivre_sombre"], "hard", what="berceau")
    # virole, cerclages, rivets
    L = X1 - X0
    g.cyl(((X0 + X1) / 2, y, zc), "x", R_CH, L, M["cuivre_capot"], n=36, what="virole")
    for k in range(5):
        x = X0 + 0.08 + (L - 0.16) * k / 4
        g.tube_shell((x, y, zc), "x", R_CH + 0.02, R_CH - 0.02, 0.045, M["laiton_capot"], n=36, what="cerclage")
    for a in (0.15, 0.75, 1.35):        # rangées de rivets, de la face sud vers le dessus
        nrm = corps.V((0, -math.cos(a), math.sin(a)))
        for k in range(14):
            x = X0 + 0.06 + (L - 0.12) * (k + 0.5) / 14
            g.dome(corps.V((x, y, zc)) + nrm * R_CH, nrm, 0.013, M["laiton_rivet"])
    # boîte à fumée (est) et fond de foyer (ouest)
    g.cyl((X1 + 0.08, y, zc), "x", R_CH + 0.03, 0.16, M["cuivre_sombre"], n=36, what="boite_fumee")
    g.cyl((X1 + 0.17, y, zc), "x", R_CH * 0.8, 0.03, M["laiton_capot"], n=30, what="porte")
    g.cyl((X0 - 0.03, y, zc), "x", R_CH + 0.01, 0.05, M["laiton_capot"], n=36, what="fond")
    # dôme de vapeur, soupapes, sifflet
    zt = zc + R_CH
    g.cyl((-0.3, y, zt + 0.06), "z", 0.14, 0.16, M["laiton_capot"], n=24, what="dome_pied")
    F.sphere(g, (-0.3, y, zt + 0.14), 0.14, M["laiton_capot"], sz=0.8)
    g.tube_shell((-0.3, y, zt - 0.005), "z", 0.17, 0.12, 0.04, M["laiton_pont"], n=24, what="embase")
    for x in (0.12, 0.22):
        g.cyl((x, y, zt + 0.06), "z", 0.035, 0.12, M["laiton_pont2"], n=10, what="soupape")
        g.cyl((x, y, zt + 0.13), "z", 0.05, 0.02, M["laiton_capot"], n=10, what="soupape_tete")
    g.cyl((0.4, y, zt + 0.1), "z", 0.018, 0.2, M["laiton_capot"], n=8, what="sifflet")
    g.cyl((0.4, y, zt + 0.22), "z", 0.035, 0.06, M["laiton_capot"], n=10, what="sifflet_cloche")
    # tuyau de vapeur dôme -> boîte à fumée
    g.pipe([(-0.3, y - 0.05, zt + 0.12), (-0.05, y - 0.12, zt + 0.06), (X1 + 0.05, y - 0.12, zt + 0.02)], 0.03,
           M["cuivre_sombre"], fl_mat=M["laiton_capot"], bolt_mat=M["laiton_rivet"])
    # face sud : manomètres, niveau d'eau ambré, robinet
    yf = y - R_CH - 0.01
    for x in (-0.48, -0.26):
        g.cyl((x, yf + 0.02, zc + 0.08), "y", 0.012, 0.06, M["laiton_capot"], n=6, what="piquage")
        # phase A2 (nuit presque éteinte) : cadrans éclairés
        P2.gauge(g, (x, yf - 0.02, zc + 0.08), (0, -1, 0), 0.06, M, face=M["emit_soft"])
    # phase A2 (nuit) : deux lampes de cabine ambre aux angles avant du foyer, fente du cendrier rougeoyante
    yb = Y(c.T["y_av"]) - 0.01
    for x in (-0.78, 0.78):
        g.box((x, yb + 0.02, Z_BASE + 0.02), (0.05, 0.05, 0.06), M["laiton_capot"], "hard", what="potence")
        PT.lamp(g, (x, yb - 0.02, Z_BASE - 0.06), (0, -1, 0), 0.035, M["emit"])
    for x in (-0.66, 0.66):
        g.box((x, yb - 0.004, c.T["sole_h"] + 0.12), (0.22, 0.012, 0.03), M["emit"], "flat", what="cendrier")
    g.halo((0, yb - 0.3, 0.5), M["_emit_rgb"], 3.0)
    g.box((-0.66, yf - 0.02, zc - 0.02), (0.035, 0.03, 0.2), M["emit"], "flat", what="niveau")
    g.box((-0.66, yf - 0.035, zc - 0.02), (0.06, 0.012, 0.24), M["laiton_capot"], "hard", what="niveau_cadre")
    P2.handwheel(g, (-0.05, yf - 0.06, zc - 0.12), (0, -1, 0), 0.06, M, mat=M["laiton_capot"])
    # caisse à charbon (arrière gauche)
    corps.boite(g, -0.88, -0.3, 0.5, 0.88, Z_BASE, Z_BASE + 0.3, [M["bois_verni"], M["bois_verni2"]],
                ins=(0.0, 0.0, 0.0), panel=0.2, faces="s", rivets=False)
    for k in range(14):
        F.lump(g, (-0.84 + 0.5 * g.rng.random(), Y(0.55 + 0.3 * g.rng.random()), Z_BASE + 0.3), 0.045,
               M["blackiron"], sz=0.7)


def fumee(g, c):
    M = g.M
    f = c.T["fumee"]
    x, yn = f["x"], f["yn"] + 0.02
    y = Y(yn)
    z0, z1 = Z_BASE, 1.95
    r = 0.12
    g.cyl((x, y, (z0 + z1) / 2), "z", r, z1 - z0, M["cuivre_sombre"], n=24, what="cheminee")
    for k in range(5):
        z = z0 + 0.25 + (z1 - z0 - 0.3) * k / 4
        g.tube_shell((x, y, z), "z", r + 0.022, r - 0.01, 0.045, M["laiton_capot"], n=24, what="cerclage")
    g.cyl((x, y, z1 + 0.07), "z", r, 0.14, M["cuivre_capot"], n=24, r2=0.19, what="couronne")
    g.tube_shell((x, y, z1 + 0.15), "z", 0.2, 0.15, 0.04, M["laiton_capot"], n=24, what="levre")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.18, 0.15, levre=False)


def piece(g, c):
    M = g.M
    zs = c.T["sole_h"] + 0.03
    p = corps.coin(c, "coin_SO")
    corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
    w, l = 2 * p["rw"] * 0.75, p["prof"] * 0.65
    corps.boite(g, p["x"] - w / 2, p["x"] + w / 2, p["yn"] - l / 2, p["yn"] + l / 2, zs, zs + 0.24,
                [M["bois_verni"], M["bois_verni2"]], panel=0.15, faces="s", rivets=False)
    for x in (p["x"] - w / 2, p["x"] + w / 2):
        g.box((x, Y(p["yn"]), zs + 0.12), (0.03, Y(l) + 0.02, 0.26), M["laiton_capot"], "hard", what="cornière")
    for k in range(10):
        F.lump(g, (p["x"] - w * 0.4 + w * 0.8 * g.rng.random(), Y(p["yn"] - l * 0.3 + l * 0.6 * g.rng.random()),
                   zs + 0.24), 0.045, M["blackiron"], sz=0.7)
    p = corps.coin(c, "coin_SE")
    corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
    x, y = p["x"], Y(p["yn"])
    g.cyl((x, y, zs + 0.17), "z", 0.13, 0.34, M["cuivre_capot"], n=24, what="citerne")
    for z in (zs + 0.06, zs + 0.28):
        g.tube_shell((x, y, z), "z", 0.145, 0.12, 0.03, M["laiton_capot"], n=24, what="cerclage")
    F.sphere(g, (x, y, zs + 0.34), 0.13, M["cuivre_capot"], sz=0.45)
    # phase A2 : volant de cuivre sombre (en laiton, 5 reflets : 14,8 points blancs par t², seuil 13,2)
    P2.handwheel(g, (x, y - 0.15, zs + 0.18), (0, -1, 0), 0.05, M, mat=M["cuivre_sombre"])
