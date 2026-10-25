"""Four · Âge 13 · Antimatière (ère V, 6×6, niveaux 25 et 26). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 13.
S'exécute DANS Blender.

En 3 mots : « sphère blindée, bobines, points violets ». La chambre est un FOUR À ANNIHILATION : grande SPHÈRE BLINDÉE
d'acier canon (joints de plaques, rivets chromés) enfoncée dans un socle octogonal d'acier noir et tenue par quatre
mâchoires ; BOBINES de cuivre rouge à spires (équateur, deux parallèles, un anneau méridien face au sud) ; POINTS
VIOLETS (et un tiers de bleus) aux ports d'injection, fenêtre au point d'annihilation ; à l'arrière droit, la cheminée
d'évent d'acier canon à bobines et anneau violet (la fumée).
Palette 60/30/10 (ages.PALETTE[13]) : acier canon / cuivre rouge des bobinages / lueur d'annihilation violette et bleue.
"""
import math

import ages
import corps
from kit import TAU
from repere import Y

EPOQUE = 13
NOM = ages.NOMS[13]
TRIPLET = ("sphère blindée", "bobines", "points violets")
FOYER = ages.FOYER[13]
HABILLAGE = dict(ages.CORPS[13], foyer="acier_noir")
Z_SOCLE = 0.7
CYN, CZ, RS = 0.35, 2.3, 1.75
PH = math.pi / 8


def matieres(metal, M):
    ages.matieres(13, metal, M)


def sp(a, lat, dr=0.0):
    """Point de la sphère (azimut a, latitude lat) au rayon RS + dr, et sa normale."""
    n = corps.V((math.cos(lat) * math.cos(a), math.cos(lat) * math.sin(a), math.sin(lat)))
    return corps.V((0, Y(CYN), CZ)) + n * (RS + dr), n


def bobine(g, z, R, r, axe="z", c=None):
    M = g.M
    c = c or corps.V((0, Y(CYN), z))
    g.torus(c, axe, R, r, M["cuivre_bobine"], n=64, m=10, what="bobine")
    for k in (-1, 1):
        off = corps.V((0, 0, k * r * 0.95)) if axe == "z" else corps.V((0, k * r * 0.95, 0))
        g.torus(c + off, axe, R, r * 0.35, M["cuivre_plaque"], n=64, m=6, what="spire")


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    cy = Y(CYN)
    g.cyl((0, cy, (zs + Z_SOCLE) / 2), "z", 2.75, Z_SOCLE - zs, M["acier_noir"], n=8, phase=PH, style="hard",
          what="socle")
    g.cyl((0, cy, Z_SOCLE + 0.02), "z", 2.6, 0.04, M["acier_canon"], n=8, phase=PH, style="hard", what="dessus")
    g.cyl((0, cy, 0.3), "z", 2.77, 0.08, M["cuivre_plaque"], n=8, phase=PH, style="hard", what="bande")
    for k in range(24):
        a = math.pi + math.pi * (k + 0.5) / 24
        g.dome((2.5 * math.cos(a), cy + 2.5 * math.sin(a), Z_SOCLE + 0.045), (0, 0, 1), 0.02, M["chrome_fin"])
    # mâchoires du berceau
    for a in (math.radians(d) for d in (40, 140, 220, 320)):
        p = corps.V((1.45 * math.cos(a), cy + 1.45 * math.sin(a), Z_SOCLE + 0.45))
        g.box(p, (0.55, 0.5, 0.9), M["acier_canon"], "hard", R=corps.Matrix.Rotation(a, 3, "Z"), what="machoire")
        g.box(p + corps.V((0, 0, 0.47)), (0.6, 0.55, 0.06), M["chrome_fin"], "hard", R=corps.Matrix.Rotation(a, 3, "Z"),
              what="chape")
    # sphère blindée, joints de plaques, rivets
    from formes import sphere
    sphere(g, (0, cy, CZ), RS, M["acier_canon2"], n=56, m=28)
    for k in range(12):
        a = TAU * k / 12
        pts = [sp(a, -0.35 + 1.75 * i / 12, 0.005)[0] for i in range(13)]
        g.tube(pts, 0.018, M["acier_noir"], n=5, what="joint")
    for lat in (0.55, 1.05):
        g.torus((0, cy, CZ + RS * math.sin(lat)), "z", RS * math.cos(lat) + 0.004, 0.016, M["acier_noir"], n=56, m=5,
                what="joint")
    for lat in (0.3, 0.8, 1.25):
        for k in range(20):
            a = math.pi + math.pi * (k + 0.5) / 20
            p, n = sp(a, lat, 0.0)
            g.dome(p, n, 0.02, M["chrome_fin"])
    # bobines
    bobine(g, CZ, RS + 0.06, 0.16)
    zl = CZ + 0.95
    bobine(g, zl, math.sqrt(RS * RS - 0.95 * 0.95) + 0.06, 0.13)
    bobine(g, CZ, RS + 0.05, 0.14, axe="y", c=corps.V((0, cy, CZ)))
    # points violets (2/3) et bleus (1/3) aux ports d'injection ; fenêtre d'annihilation
    k = 0
    for lat in (0.2, 0.62, 1.15):
        for i in range(7):
            a = math.pi * 1.12 + math.pi * 0.76 * (i + 0.5 * (lat > 0.5)) / 7
            p, n = sp(a, lat, 0.0)
            g.tube_shell(p, n, 0.07, 0.04, 0.04, M["chrome_fin"], n=12, what="port")
            g.dome(p + n * 0.01, n, 0.04, M["emit2"] if k % 3 == 2 else M["emit"], n=8, what="point")
            k += 1
    p, n = sp(-math.pi / 2, 0.42, 0.0)
    g.cyl(p, n, 0.2, 0.05, M["acier_noir"], n=20, what="fenetre_cadre")
    g.cyl(p + n * 0.02, n, 0.15, 0.02, M["verre_fume"], n=20, style="flat", what="fenetre")
    g.dome(p + n * 0.03, n, 0.06, M["emit"], n=10, what="point_annihilation")
    g.halo((0, cy - RS - 0.3, CZ), M["_emit_rgb"], 8.0)


def socle(g, c):
    """Ronde 2 (richesse : le socle octogonal était nu à côté de la MG 13) : huit colonnes de confinement à bobines et
    point violet sur le pourtour, câbles de cuivre vers le berceau, grilles d'évent."""
    M = g.M
    cy = Y(CYN)
    z0 = Z_SOCLE + 0.04
    for a_deg in (0, 60, 118, 160, 200, 236, 304, 340):
        a = math.radians(a_deg)
        x, y = 2.3 * math.cos(a), cy + 2.3 * math.sin(a)
        g.cyl((x, y, z0 + 0.04), "z", 0.17, 0.08, M["chrome_fin"], n=8, phase=PH, style="hard", what="embase")
        g.cyl((x, y, z0 + 0.36), "z", 0.11, 0.6, M["acier_noir"], n=16, what="colonne")
        for z in (z0 + 0.22, z0 + 0.42):
            g.torus((x, y, z), "z", 0.125, 0.045, M["cuivre_bobine"], n=16, m=6, what="bobine")
        g.cyl((x, y, z0 + 0.68), "z", 0.13, 0.05, M["acier_canon"], n=16, what="chapeau")
        g.dome((x, y, z0 + 0.71), (0, 0, 1), 0.06, M["emit2"] if a_deg % 3 == 0 else M["emit"], n=8, what="point")
        d = corps.V((math.cos(a), math.sin(a), 0))
        g.tube([corps.V((x, y, z0 + 0.05)) - d * 0.12, corps.V((x, y, z0 + 0.04)) - d * 0.45,
                corps.V((0, cy, z0 + 0.06)) + d * (RS - 0.1)], 0.03, M["cuivre_plaque"], n=6, what="cable")
    for a_deg in (215, 325):
        a = math.radians(a_deg)
        x, y = 1.95 * math.cos(a), cy + 1.95 * math.sin(a)
        g.grille([corps.V((x - 0.2, y - 0.01, z0)), corps.V((x + 0.2, y - 0.01, z0)), corps.V((x + 0.2, y + 0.3, z0)),
                  corps.V((x - 0.2, y + 0.3, z0))], 5, slat_mat=M["acier_noir"])


def gueule(g, c, G):
    M = g.M
    zc = (G["bz0"] + G["bz1"]) / 2
    R = max(G["bx1"], (G["bz1"] - G["bz0"]) / 2) + 0.12
    g.torus((0, G["yf"] - 0.05, zc), "y", R, 0.07, M["cuivre_bobine"], n=40, m=8, what="bobine_gueule")
    for k in range(8):
        a = TAU * k / 8
        g.dome((R * math.cos(a), G["yf"] - 0.12, zc + R * math.sin(a)), (0, -1, 0), 0.03, M["emit"] if k % 2 else
               M["chrome_fin"], n=8)


def fumee(g, c):
    M = g.M
    x, yn = 1.98, 1.3
    y = Y(yn)
    zs = c.T["sole_h"]
    z1 = 3.5
    g.cyl((x, y, zs + 0.15), "z", 0.45, 0.3, M["acier_noir"], n=8, phase=PH, style="hard", what="embase")
    g.cyl((x, y, (zs + z1) / 2), "z", 0.3, z1 - zs, M["acier_canon"], n=28, what="evente")
    for z in (1.3, 2.1, 2.9):
        g.torus((x, y, z), "z", 0.33, 0.07, M["cuivre_bobine"], n=28, m=8, what="bobine")
    g.torus((x, y, 3.3), "z", 0.31, 0.04, M["emit"], n=28, m=6, what="anneau_violet")
    g.cyl((x, y, z1 + 0.06), "z", 0.36, 0.12, M["acier_noir"], n=28, what="tete")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.12, 0.28)


def piece(g, c):
    """Pièges magnétiques : bouteilles couchées à bobines et point violet, sur berceaux."""
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        for dy in (-0.14, 0.2):
            x, y, z = p["x"], Y(p["yn"]) + dy, zs + 0.32
            L = 2 * p["rw"] * 0.7
            for sx in (-0.35, 0.35):
                g.box((x + sx * L, y, zs + 0.12), (0.12, 0.3, 0.24), M["acier_noir"], "hard", what="berceau")
            g.cyl((x, y, z), "x", 0.17, L, M["acier_canon"], n=24, what="bouteille")
            from formes import sphere
            for sx in (-1, 1):
                sphere(g, (x + sx * L / 2, y, z), 0.17, M["acier_canon2"], n=20, m=10)
            for f in (-0.3, 0.0, 0.3):
                g.torus((x + f * L, y, z), "x", 0.18, 0.045, M["cuivre_bobine"], n=24, m=6, what="bobine")
            g.dome((x + 0.15 * L, y - 0.17, z + 0.03), (0, -1, 0.4), 0.04, M["emit"], n=8)
