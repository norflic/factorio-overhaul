"""Four · Âge 2 · Forge (ère I, 2×2, niveaux 3 et 4). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 2. S'exécute DANS
Blender.

En 3 mots : « hotte de fer, briques rouges, soufflet de cuir ». La chambre est une FORGE DE MARÉCHAL : âtre de BRIQUES
rouges en assises, lit de charbon rougeoyant à découvert sur le devant de l'âtre, grande HOTTE de fer martelé en tronc
de pyramide (plaques rivetées, deux bandes de fer noir) qui monte vers l'arrière droit et finit en cheminée carrée de
briques (la fumée) ; SOUFFLET DE CUIR plissé couché sur l'âtre à gauche, buse de fer vers les braises, perche de
manœuvre ; tenailles et tisonnier pendus à la barre de la hotte. Gueule en plein cintre au pied de l'âtre (cendrier).
Palette 60/30/10 (ages.PALETTE[2]) : fer martelé / brique rouge / braise rouge.
"""
import math

import ages
import corps
import formes as F
import parts as PT
from repere import Y

EPOQUE = 2
NOM = ages.NOMS[2]
TRIPLET = ("hotte de fer", "briques rouges", "soufflet de cuir")
FOYER = ages.FOYER[2]
HABILLAGE = dict(ages.CORPS[2], gueule="arche", foyer="fer_noir")
Z_ATRE = 0.72


def matieres(metal, M):
    ages.matieres(2, metal, M)


def _bande(g, q, t0, t1, mat, ep=0.018):
    q = [corps.V(p) for p in q]
    g.slab(PT.face_quad(q, 0.0, 1.0, t0, t1), (q[1] - q[0]).cross(q[3] - q[0]).normalized(), ep, mat, "hard", "bande")


def chambre(g, c):
    M = g.M
    T = c.T
    zs, xa = T["sole_h"], T["xa"]
    briques = [M["brique"], M["brique_pave"], M["brique_pave2"], M["brique"]]
    # âtre de briques
    g.box((0, Y((T["y_av"] + T["y_ar"]) / 2), (zs + Z_ATRE) / 2), (2 * xa, Y(T["y_ar"] - T["y_av"]), Z_ATRE - zs),
          M["mortier"], "flat", what="atre")
    corps.briques_sud(g, -xa, xa, T["y_av"], zs, Z_ATRE, briques)
    g.box((0, Y(T["y_av"]) - 0.01, Z_ATRE - 0.02), (2 * xa + 0.04, 0.05, 0.05), M["fer_noir"], "hard", what="corniere")
    g.box((0, Y((T["y_av"] + T["y_ar"]) / 2), Z_ATRE + 0.01), (2 * xa, Y(T["y_ar"] - T["y_av"]), 0.02), M["fer_noir"],
          "hard", what="table")
    # lit de charbon : blocs noirs, braises (emit) clairsemées
    for k in range(34):
        x = -0.18 + 0.9 * g.rng.random()
        yn = -0.52 + 0.62 * g.rng.random()
        chaud = k % 4 == 0
        F.lump(g, (x, Y(yn), Z_ATRE + 0.02), 0.045 + 0.02 * g.rng.random(), M["emit"] if chaud else M["blackiron"],
               sz=0.6)
    # mur du fond et poteaux de la hotte
    g.box((0, Y(0.82), (Z_ATRE + 1.0) / 2), (2 * xa, Y(0.2), 1.0 - Z_ATRE), M["brique"], "hard", what="mur_fond")
    corps.briques_sud(g, -xa, xa, 0.72, Z_ATRE, 1.0, briques)
    for sx in (-1, 1):
        g.box((sx * 0.86, Y(-0.2), (Z_ATRE + 1.0) / 2), (0.05, 0.05, 1.0 - Z_ATRE), M["fer_noir"], "hard", what="poteau")
    # hotte en tronc de pyramide vers l'arrière droit
    B = [corps.P(-0.92, -0.26, 1.0), corps.P(0.92, -0.26, 1.0), corps.P(0.92, 0.9, 1.0), corps.P(-0.92, 0.9, 1.0)]
    Tt = [corps.P(0.36, 0.26, 1.55), corps.P(0.74, 0.26, 1.55), corps.P(0.74, 0.58, 1.55), corps.P(0.36, 0.58, 1.55)]
    corps.tronc(g, B, Tt, M["fer_martele"], mats=[M["fer_martele"], M["fer_martele"], M["tole_forge"]], faces="swe",
                panel=0.28)
    for t0 in (0.12, 0.62):
        _bande(g, [B[0], B[1], Tt[1], Tt[0]], t0, t0 + 0.07, M["fer_noir"])
        _bande(g, [B[3], B[0], Tt[0], Tt[3]], t0, t0 + 0.07, M["fer_noir"])
    # bord roulé de la hotte et barre aux outils
    g.box((0, Y(-0.27), 0.99), (1.88, 0.06, 0.06), M["fer_noir"], "hard", what="bord")
    g.cyl((0, Y(-0.33), 0.92), "x", 0.016, 1.7, M["fer_clair_f"], n=8, what="barre")
    for x, L in ((-0.5, 0.42), (-0.38, 0.5), (0.3, 0.45), (0.42, 0.36)):
        g.box((x, Y(-0.34), 0.92 - L / 2), (0.022, 0.022, L), M["fer_noir"], "hard", what="outil")
    g.box((-0.44, Y(-0.34), 0.92 - 0.5), (0.1, 0.02, 0.03), M["fer_noir"], "hard", what="mors")
    for x in (0.0, 0.14):
        g.torus((x, Y(-0.34), 0.86), "y", 0.04, 0.012, M["fer_clair_f"], n=12, m=5, what="fer_a_cheval")
    soufflet(g, c)


def soufflet(g, c):
    """Soufflet de cuir couché sur l'âtre, à gauche : planches, cuir plissé, buse, perche."""
    M = g.M
    z0 = Z_ATRE + 0.02
    y0, y1 = Y(-0.5), Y(-0.08)
    xw, xe = -0.86, -0.3
    g.box(((xw + xe) / 2, (y0 + y1) / 2, z0 + 0.02), (xe - xw, y1 - y0, 0.04), M["wood"], "hard", what="planche")
    hw, he = 0.28, 0.07
    B = [(xw, y0, z0 + 0.04), (xe, y0 + 0.08, z0 + 0.04), (xe, y1 - 0.08, z0 + 0.04), (xw, y1, z0 + 0.04)]
    Tt = [(xw, y0, z0 + 0.04 + hw), (xe, y0 + 0.08, z0 + 0.04 + he), (xe, y1 - 0.08, z0 + 0.04 + he),
          (xw, y1, z0 + 0.04 + hw)]
    g.hexa([corps.V(p) for p in B + Tt], M["leather"], "soft", "cuir")
    for k in range(1, 5):
        f = k / 5.0
        x = xw + (xe - xw) * f
        h = hw + (he - hw) * f
        g.box((x, y0 + 0.08 * f - 0.012, z0 + 0.04 + h / 2), (0.018, 0.02, h * 0.9), M["fer_noir"], "hard",
              what="pli")
    top = [corps.V(p) for p in Tt]
    g.slab([top[0], top[1], top[2], top[3]], (0, 0, 1), 0.035, M["wood2"], "hard", "planche_haut")
    g.cyl((xe + 0.09, (y0 + y1) / 2, z0 + 0.08), "x", 0.045, 0.2, M["fer_noir"], n=10, r2=0.025, what="buse")
    g.tube([corps.V((xw + 0.04, (y0 + y1) / 2, z0 + 0.04 + hw + 0.04)), corps.V((xw - 0.02, (y0 + y1) / 2 + 0.1,
                                                                                 z0 + 0.6))],
           0.018, M["wood2"], n=8, what="perche")


def gueule(g, c, G):
    M = g.M
    for sx in (-1, 1):
        g.torus((sx * (G["x1"] - 0.08), G["yf"] - 0.02, G["z1"] - 0.12), "y", 0.035, 0.01, M["fer_clair_f"], n=10,
                m=5, what="anneau")


def fumee(g, c):
    M = g.M
    x0, x1, yn0, yn1 = 0.4, 0.7, 0.29, 0.55
    z0, z1 = 1.5, 2.08
    g.box(((x0 + x1) / 2, Y((yn0 + yn1) / 2), (z0 + z1) / 2), (x1 - x0, Y(yn1 - yn0), z1 - z0), M["mortier"], "flat",
          what="cheminee")
    corps.briques_sud(g, x0, x1, yn0, z0, z1, [M["brique"], M["brique_pave2"], M["brique_pave"]], bw=0.1, bh=0.055)
    g.box(((x0 + x1) / 2, Y((yn0 + yn1) / 2), z1 + 0.02), (x1 - x0 + 0.05, Y(yn1 - yn0) + 0.05, 0.05), M["fer_noir"],
          "hard", what="couronne")
    corps.bouche_fumee(g, c, (x0 + x1) / 2, (yn0 + yn1) / 2, z1 + 0.06, 0.1)


def piece(g, c):
    M = g.M
    zs = c.T["sole_h"]
    # enclume sur billot (SO)
    p = corps.coin(c, "coin_SO")
    corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
    x, y = p["x"], Y(p["yn"])
    g.cyl((x, y, zs + 0.03 + 0.15), "z", 0.13, 0.3, M["wood"], n=14, style="soft", what="billot")
    g.tube_shell((x, y, zs + 0.27), "z", 0.14, 0.12, 0.03, M["fer_noir"], n=14, what="cercle")
    z = zs + 0.33
    g.box((x, y, z + 0.03), (0.12, 0.08, 0.06), M["fer_noir"], "hard", what="enclume_pied")
    g.box((x + 0.02, y, z + 0.1), (0.26, 0.11, 0.08), M["fer_noir"], "hard", what="enclume_table")
    g.cyl((x - 0.16, y, z + 0.11), "x", 0.045, 0.1, M["fer_noir"], n=10, r2=0.008, what="bigorne")
    g.box((x + 0.05, y - 0.03, z + 0.15), (0.12, 0.02, 0.02), M["fer_clair_f"], "hard", what="marteau")
    # baquet de trempe cerclé (SE), eau sombre, barres de fer
    p = corps.coin(c, "coin_SE")
    corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
    x, y = p["x"], Y(p["yn"])
    F.stave_barrel(g, (x, y, zs + 0.03), 0.15, 0.3, M["wood"], M["fer_noir"], open_top=M["glass_dk"])
    for k, a in enumerate((0.3, 0.9)):
        g.cyl((x - 0.03 + 0.05 * k, y + 0.02, zs + 0.3), (math.cos(a) * 0.3, 0.2, 1.0), 0.012, 0.36, M["fer_clair_f"],
              n=6, what="barre")
