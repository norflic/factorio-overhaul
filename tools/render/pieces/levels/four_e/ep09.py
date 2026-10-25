"""Four · Âge 9 · Atome (ère III, 4×4, niveaux 17 et 18). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 9. S'exécute
DANS Blender.

En 3 mots : « tour de refroidissement, bunker, hublots verts ». La chambre est un FOUR À CŒUR ATOMIQUE : BUNKER de
béton blanc cassé à arêtes chanfreinées (dalles coffrées, bande de danger au pied), quatre HUBLOTS VERTS cerclés de
plomb sur la face sud, trèfles de radioactivité ; sur le toit, la coupole de plomb du cœur (anneau vert à sa base),
des fûts de plomb et une conduite de plomb ; à l'arrière droit, une TOUR DE REFROIDISSEMENT hyperboloïde de béton à
nervures (la fumée : vapeur).
Palette 60/30/10 (ages.PALETTE[9]) : béton blanc cassé / plomb gris-bleu / vert uranium.
"""
import math

import ages
import corps
import formes as F
import parts3 as P3
from kit import TAU
from repere import Y

EPOQUE = 9
NOM = ages.NOMS[9]
TRIPLET = ("tour de refroidissement", "bunker", "hublots verts")
FOYER = ages.FOYER[9]
HABILLAGE = dict(ages.CORPS[9], foyer="lead")
Z_TOIT = 1.45
CH = 0.22
X0, X1, YN0, YN1 = -1.85, 1.85, -1.45, 1.88


def matieres(metal, M):
    ages.matieres(9, metal, M)


def face_sud_y(z, zs):
    return Y(YN0) + CH * (z - zs) / (Z_TOIT - zs)


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    beton = [M["beton_capot"], M["beton_dalle"], M["beton_dalle2"]]
    corps.boite(g, X0, X1, YN0, YN1, zs, Z_TOIT, beton, ins=(CH, CH, CH), panel=0.46, faces="tswe", rivets=False,
                t=0.025)
    # bande de danger au pied, hublots verts cerclés de plomb, trèfles
    q = [corps.V((X0, Y(YN0) - 0.012, zs)), corps.V((X1, Y(YN0) - 0.012, zs)),
         corps.V((X1, Y(YN0) - 0.012 + 0.02, zs + 0.13)), corps.V((X0, Y(YN0) - 0.012 + 0.02, zs + 0.13))]
    g.hazard(q, 22, t=0.014)
    nrm = corps.V((0, -(Z_TOIT - zs), CH)).normalized()
    for x in (-1.42, -0.98, 0.98, 1.42):
        z = 0.78
        p = corps.V((x, face_sud_y(z, zs), z)) + nrm * 0.02
        g.cyl(p, nrm, 0.19, 0.06, M["plomb_sombre"], n=20, what="cadre_hublot")
        g.cyl(p + nrm * 0.035, nrm, 0.13, 0.012, M["emit"], n=20, style="flat", what="hublot")
        g.tube_shell(p + nrm * 0.04, nrm, 0.17, 0.13, 0.02, M["lead"], n=20, what="jonc")
        for k in range(6):
            a = TAU * k / 6 + 0.3
            u = corps.V((math.cos(a), 0, math.sin(a)))
            g.dome(p + nrm * 0.035 + u * 0.16, nrm, 0.014, M["lead"])
    for x in (-1.2, 1.2):
        z = 1.2
        F.trefoil(g, corps.V((x, face_sud_y(z, zs), z)) + nrm * 0.03, nrm, 0.09)
    g.halo((0, Y(YN0) - 0.4, 0.8), M["_emit_rgb"], 5.0)
    toit(g, c)


def toit(g, c):
    M = g.M
    # coupole de plomb du cœur
    cx, cy = -0.7, Y(0.4)
    F.sphere(g, (cx, cy, Z_TOIT), 0.74, M["plomb_sombre"], n=32, m=16, sz=0.72)
    g.torus((cx, cy, Z_TOIT + 0.03), "z", 0.76, 0.06, M["lead"], n=36, m=6, what="embase")
    g.torus((cx, cy, Z_TOIT + 0.1), "z", 0.74, 0.028, M["emit"], n=36, m=6, what="anneau_vert")
    for k in range(4):
        a = TAU * k / 4 + 0.4
        g.box((cx + 0.42 * math.cos(a), cy + 0.42 * math.sin(a), Z_TOIT + 0.47), (0.08, 0.05, 0.1), M["lead"], "hard",
              what="oreille")
    g.cyl((cx, cy, Z_TOIT + 0.56), "z", 0.16, 0.06, M["lead"], n=16, what="bouchon")
    g.cyl((cx, cy, Z_TOIT + 0.6), "z", 0.07, 0.02, M["emit"], n=12, style="flat", what="voyant")
    # fûts de plomb sur le toit, conduite de plomb vers la tour
    for (x, yn) in ((0.35, -0.75), (0.65, -0.82), (0.5, -0.5)):
        F.drum(g, (x, Y(yn), Z_TOIT), 0.12, 0.3, M["lead"], M["plomb_sombre"], top=M["plomb_sombre"], trefoil=True)
    g.pipe([(cx + 0.6, cy - 0.3, Z_TOIT + 0.12), (0.4, Y(0.2), Z_TOIT + 0.1), (1.0, Y(0.55), Z_TOIT + 0.12)], 0.06,
           M["lead"], fl_mat=M["plomb_sombre"], bolt_mat=M["lead"])
    P3.lamp_row(g, (-1.5, Y(YN0) + CH + 0.1, Z_TOIT + 0.02), (-0.2, Y(YN0) + CH + 0.1, Z_TOIT + 0.02), 4, (0, 0, 1),
                M["emit"], M, size=0.03)


def gueule(g, c, G):
    q = [corps.V((G["x0"], G["yf"] - 0.012, G["z1"] - 0.1)), corps.V((G["x1"], G["yf"] - 0.012, G["z1"] - 0.1)),
         corps.V((G["x1"], G["yf"] - 0.012, G["z1"] - 0.02)), corps.V((G["x0"], G["yf"] - 0.012, G["z1"] - 0.02))]
    g.hazard(q, 10, t=0.012)


def fumee(g, c):
    """Tour de refroidissement hyperboloïde sur le toit (vapeur)."""
    M = g.M
    x, yn = 1.0, 0.92
    zs_ = [Z_TOIT - 0.02, 1.75, 2.1, 2.45, 2.75, 3.0]
    rs = [0.64, 0.55, 0.47, 0.45, 0.48, 0.53]
    corps.tube_v(g, x, yn, rs, zs_, M["beton_capot"], n=36, caps=False, what="tour")
    y = Y(yn)
    for k in range(16):
        a = TAU * k / 16
        pts = [corps.V((x + (r + 0.008) * math.cos(a), y + (r + 0.008) * math.sin(a), z)) for r, z in zip(rs, zs_)]
        g.tube(g.spline(pts, 3), 0.014, M["beton_dalle2"], n=5, what="nervure")
    for z, r in ((1.6, 0.6), (2.62, 0.47)):
        g.torus((x, y, z), "z", r + 0.01, 0.025, M["joint_beton"], n=36, m=5, what="bague")
    g.torus((x, y, zs_[-1]), "z", rs[-1], 0.035, M["beton_dalle"], n=36, m=6, what="rive")
    corps.bouche_fumee(g, c, x, yn, zs_[-1], rs[-1] - 0.02, levre=False)
    g.cyl((x, y, zs_[-1] - 0.25), "z", rs[-1] * 0.95, 0.02, M["void"], n=24, style="flat", what="fond_tour")


def piece(g, c):
    """Châteaux de plomb (conteneurs de combustible) à voyant vert."""
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        for dx in (-0.26, 0.26):
            x, y = p["x"] + dx, Y(p["yn"])
            g.cyl((x, y, zs + 0.2), "z", 0.22, 0.4, M["lead"], n=24, what="chateau")
            for k in range(10):
                a = TAU * k / 10
                g.box((x + 0.225 * math.cos(a), y + 0.225 * math.sin(a), zs + 0.2), (0.03, 0.03, 0.34),
                      M["plomb_sombre"], "hard", R=F.Rz(a), what="ailette")
            g.cyl((x, y, zs + 0.42), "z", 0.18, 0.05, M["plomb_sombre"], n=20, what="couvercle")
            g.cyl((x, y, zs + 0.45), "z", 0.06, 0.02, M["emit"], n=12, style="flat", what="voyant")
            F.trefoil(g, (x, y - 0.235, zs + 0.24), (0, -1, 0), 0.07)
