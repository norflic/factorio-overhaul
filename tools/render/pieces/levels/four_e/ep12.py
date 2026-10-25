"""Four · Âge 12 · Supraconducteurs (ère IV, 5×5, niveaux 23 et 24). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 12.
S'exécute DANS Blender.

En 3 mots : « anneaux chromés, creuset flottant, givre ». La chambre est un FOUR À LÉVITATION : sur un socle hexagonal
de noir miroir à lèvre givrée, deux grosses bobines en ANNEAUX CHROMÉS (en bas posée, en haut sans appui) et un
anneau équatorial tiennent en l'air une SPHÈRE FLOTTANTE de noir miroir cerclée de cyan (le creuset) ; lueur cyan dans
l'entrefer ; derrière, un grand CRYOSTAT cylindrique blanc GIVRÉ cerclé de chrome (il ferme le fond : aucun jour) ;
à l'arrière droit, l'évent cryogénique chromé à bagues de givre (la fumée : vapeur froide).
Palette 60/30/10 (ages.PALETTE[12]) : blanc glacé teinté cyan / noir miroir et chrome / cyan lumineux.
"""
import math

import ages
import corps
import formes as F
from kit import TAU
from repere import Y

EPOQUE = 12
NOM = ages.NOMS[12]
TRIPLET = ("anneaux chromés", "creuset flottant", "givre")
FOYER = ages.FOYER[12]
HABILLAGE = dict(ages.CORPS[12], gueule="ronde", foyer="chrome_mat")
Z_SOCLE = 0.55
SX, SYN = 0.0, -0.35
CRYO_YN = 1.1


def matieres(metal, M):
    ages.matieres(12, metal, M)


def givre(g, p, n, r, spread, z):
    M = g.M
    for k in range(n):
        a = TAU * k / n + 0.37 * k
        F.lump(g, (p[0] + spread * math.cos(a), p[1] + spread * 0.7 * math.sin(a), z), r * (0.7 + 0.5 * (k % 3) / 2),
               M["frost"], sz=0.5, jit=0.35)


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    cy = Y(0.2)
    g.cyl((0, cy, (zs + Z_SOCLE) / 2), "z", 2.15, Z_SOCLE - zs, M["noir_miroir"], n=6, style="hard", what="socle")
    g.cyl((0, cy, 0.22), "z", 2.17, 0.06, M["chrome_mat"], n=6, style="hard", what="bande")
    g.cyl((0, cy, Z_SOCLE + 0.02), "z", 2.17, 0.05, M["frost"], n=6, style="hard", what="levre")
    g.cyl((0, cy, Z_SOCLE + 0.035), "z", 1.98, 0.04, M["noir_miroir2"], n=6, style="hard", what="dessus")
    givre(g, (-1.4, cy - 1.2), 6, 0.08, 0.25, Z_SOCLE + 0.03)
    givre(g, (1.3, cy - 1.25), 5, 0.07, 0.2, Z_SOCLE + 0.03)
    cryostat(g, c)
    lev(g, c)


def cryostat(g, c):
    M = g.M
    x, y = 0.0, Y(CRYO_YN)
    z0, z1, R = Z_SOCLE, 2.8, 1.0
    g.cyl((x, y, (z0 + z1) / 2), "z", R, z1 - z0, M["frost"], n=48, what="cryostat")
    for z in (0.95, 1.6, 2.25, 2.7):
        g.tube_shell((x, y, z), "z", R + 0.03, R - 0.02, 0.09, M["chrome_mat"], n=48, what="cerclage")
        for k in range(10):
            a = math.pi + math.pi * (k + 0.5) / 10
            F.lump(g, (x + (R + 0.04) * math.cos(a), y + (R + 0.04) * math.sin(a), z + 0.05), 0.045, M["frost"], sz=0.6)
    F.sphere(g, (x, y, z1), R, M["frost"], n=48, m=16, sz=0.35)
    g.cyl((x + 0.35, y, z1 + 0.38), "z", 0.1, 0.12, M["chrome_mat"], n=16, what="vanne")
    g.cyl((x - 0.3, y + 0.2, z1 + 0.36), "z", 0.14, 0.08, M["trim"], n=16, what="trappe")
    for k in range(5):
        a = math.pi + math.pi * (k + 0.5) / 5
        g.box((x + (R + 0.01) * math.cos(a), y + (R + 0.01) * math.sin(a), 2.2), (0.06, 0.03, 0.4), M["emit"], "flat",
              R=corps.Matrix.Rotation(a + math.pi / 2, 3, "Z"), what="jauge")


def lev(g, c):
    """Pile de lévitation : bobine basse, sphère flottante cerclée de cyan, anneau équatorial, bobine haute."""
    M = g.M
    x, y = SX, Y(SYN)
    g.cyl((x, y, Z_SOCLE + 0.1), "z", 0.68, 0.2, M["noir_miroir2"], n=36, what="embase")
    g.torus((x, y, Z_SOCLE + 0.24), "z", 0.86, 0.2, M["chrome_mat"], n=48, m=12, what="bobine_basse")
    g.torus((x, y, Z_SOCLE + 0.32), "z", 0.64, 0.05, M["emit"], n=40, m=6, what="anneau_cyan")
    # ronde 2 (plus grand foyer 0,64 t², au-delà de 0,45) : entrefer sombre, lueur en couronne fine seulement
    g.cyl((x, y, Z_SOCLE + 0.36), "z", 0.6, 0.02, M["noir_miroir2"], n=36, style="flat", what="entrefer")
    g.torus((x, y, Z_SOCLE + 0.38), "z", 0.42, 0.03, M["emit_soft"], n=36, m=5, what="entrefer_lum")
    zc, rs = 1.78, 0.6
    F.sphere(g, (x, y, zc), rs, M["noir_miroir2"], n=36, m=18)
    for dz in (-0.3, 0.0, 0.3):
        r = math.sqrt(rs * rs - dz * dz)
        g.torus((x, y, zc + dz), "z", r + 0.004, 0.022, M["emit"], n=40, m=5, what="cerclage_cyan")
    for k in range(7):
        a = TAU * k / 7
        F.lump(g, (x + 0.2 * math.cos(a), y + 0.2 * math.sin(a), zc + rs - 0.06), 0.07, M["frost"], sz=0.5)
    g.torus((x, y, zc), "z", 0.8, 0.07, M["trim"], n=48, m=8, what="anneau_equateur")
    g.torus((x, y, 2.66), "z", 0.82, 0.17, M["chrome_mat"], n=48, m=12, what="bobine_haute")
    g.torus((x, y, 2.58), "z", 0.62, 0.045, M["emit"], n=40, m=6, what="anneau_cyan")
    for k in range(12):
        a = TAU * k / 12
        g.box((x + 0.82 * math.cos(a), y + 0.82 * math.sin(a), 2.66), (0.05, 0.05, 0.36), M["noir_miroir"], "hard",
              what="spire")
        g.box((x + 0.86 * math.cos(a), y + 0.86 * math.sin(a), Z_SOCLE + 0.24), (0.05, 0.05, 0.42), M["noir_miroir"],
              "hard", what="spire")
    g.halo((x, y - 0.6, 1.4), M["_emit_rgb"], 7.0)


def socle(g, c):
    """Ronde 2 (richesse : socle de noir miroir nu) : pompes cryogéniques givrées aux angles avant du socle, conduites
    chromées couchées vers la pile, boîtiers à voyant cyan."""
    M = g.M
    for sx in (-1, 1):
        x, y = sx * 1.35, Y(-0.3)
        g.cyl((x, y, Z_SOCLE + 0.2), "z", 0.2, 0.36, M["trim"], n=20, what="pompe")
        g.torus((x, y, Z_SOCLE + 0.3), "z", 0.21, 0.04, M["frost"], n=20, m=6, what="givre")
        F.sphere(g, (x, y, Z_SOCLE + 0.38), 0.2, M["chrome_mat"], n=20, m=8, sz=0.5)
        g.torus((x, y, Z_SOCLE + 0.12), "z", 0.205, 0.02, M["emit"], n=20, m=5, what="anneau_cyan")
        g.pipe([(x - sx * 0.15, y + 0.12, Z_SOCLE + 0.1), (sx * 0.95, Y(SYN) + 0.1, Z_SOCLE + 0.08)], 0.04,
               M["chrome_mat"], fl_mat=M["frost"])
        corps.boite(g, x - 0.18, x + 0.18, 0.15, 0.45, Z_SOCLE, Z_SOCLE + 0.22, [M["noir_miroir2"], M["chrome_mat"]],
                    panel=0.2, faces="ts")
        g.dome((x, Y(0.15) - 0.01, Z_SOCLE + 0.14), (0, -1, 0), 0.025, M["emit"], n=8, what="voyant")
    givre(g, (0.0, Y(-1.0)), 7, 0.06, 0.6, Z_SOCLE + 0.04)
    # phase A2 (retouches légères) : plaques boulonnées chromées en quinconce sur le dessus de noir miroir, dans
    # l'hexagone, hors de la pile, du cryostat et des pompes
    exclus = [(0.0, CRYO_YN, 1.1), (SX, SYN, 1.12), (1.35, -0.3, 0.32), (-1.35, -0.3, 0.32), (1.35, 0.3, 0.3),
              (-1.35, 0.3, 0.3), (0.0, -1.3, 0.55)]
    cy = 0.2
    for x, yn in corps.semis(-1.9, 1.9, -1.15, 1.6, 0.3, exclus):
        if math.hypot(x, Y(yn - cy)) > 1.82:
            continue
        corps.ancrage(g, x, yn, Z_SOCLE + 0.055, M["noir_miroir"], M["chrome_mat"], s=0.07)


def fumee(g, c):
    M = g.M
    x, yn = 1.6, 1.08
    y = Y(yn)
    zs = c.T["sole_h"]
    z1 = 3.15
    g.cyl((x, y, zs + 0.08), "z", 0.3, 0.16, M["noir_miroir"], n=6, style="hard", what="embase")
    g.cyl((x, y, (zs + z1) / 2), "z", 0.2, z1 - zs, M["chrome_mat"], n=24, what="event")
    for z in (0.8, 1.6, 2.4):
        g.torus((x, y, z), "z", 0.22, 0.05, M["frost"], n=24, m=6, what="givre")
    g.torus((x, y, 2.95), "z", 0.21, 0.03, M["emit"], n=24, m=5, what="anneau_cyan")
    g.cyl((x, y, z1 + 0.05), "z", 0.26, 0.1, M["trim"], n=24, what="tete")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.1, 0.2)
    g.pipe([(x - 0.15, y + 0.05, 0.9), (x - 0.6, y + 0.25, 0.95), (0.9, Y(CRYO_YN) - 0.1, 1.0)], 0.06, M["chrome_mat"],
           fl_mat=M["frost"])


def piece(g, c):
    """Vases de Dewar givrés à bague cyan."""
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        for dx in (-0.38, 0.0, 0.38):
            x, y = p["x"] + dx, Y(p["yn"]) + (0.08 if dx == 0 else -0.05)
            h = 0.5 if dx == 0 else 0.4
            g.cyl((x, y, zs + h / 2), "z", 0.16, h, M["frost"], n=24, what="dewar")
            F.sphere(g, (x, y, zs + h), 0.16, M["frost"], n=20, m=8, sz=0.4)
            g.cyl((x, y, zs + h + 0.06), "z", 0.07, 0.08, M["chrome_mat"], n=12, what="col")
            g.torus((x, y, zs + h * 0.7), "z", 0.165, 0.02, M["emit"], n=24, m=5, what="bague_cyan")
            g.tube_shell((x, y, zs + 0.06), "z", 0.175, 0.14, 0.06, M["chrome_mat"], n=24, what="pied")
