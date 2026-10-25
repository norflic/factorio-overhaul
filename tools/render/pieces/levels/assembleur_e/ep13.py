"""Assembleur · Âge 13 · Antimatière (ère V, 6×6, niveaux 25 et 26). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 13.
Dans Blender.

En 3 mots : « tore, faisceau d'annihilation, spires ». Aucun portique : un TORE de confinement couché (acier canon) flotte
au-dessus de la table sur quatre jambes de chrome, ceint de SPIRES de cuivre rouge ; de son centre tombe un FAISCEAU
D'ANNIHILATION violet qui façonne l'ouvrage (point de lumière violet et étincelles bleues). Dos en caisson bas et CLOCHE
de verre fumé violet à côtes de cuivre ; solénoïdes couchés sur les joues.
Palette 60/30/10 (ages.PALETTE[13]) : acier canon gris froid / cuivre rouge des bobinages / lueur violette (2/3) et
bleue (1/3), en points.
"""
import math

from mathutils import Vector

import ages
import corps
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 13
NOM = ages.NOMS[13]
TRIPLET = ("tore", "faisceau d'annihilation", "spires")
FOYER = ages.FOYER[13]
TRAVAIL = dict(couches=2, images=16, organe="lueur qui court dans le tore (16 images), faisceau qui pulse, étincelles "
                                           "bleues (couche glow) ; le tore reste fixe")
HABILLAGE = dict(ages.CORPS[13], forme_embase='carre', forme_dos='dome', forme_joues='caisson', forme_portique='aucun',
                 mat_dos='verre_fume')


def matieres(metal, M):
    ages.matieres(13, metal, M)


def _solenoide(g, x, yn, z, L, r):
    M = g.M
    g.cyl(B(x, yn, z + r + 0.04), "y", r, L * SQ2, M["acier_canon"], n=20, what="solenoide")
    n = int(L / 0.07)
    for k in range(n):
        g.tube_shell(B(x, yn - L / 2 + (k + 0.5) * L / n, z + r + 0.04), "y", r + 0.02, r - 0.01, 0.045,
                     M["cuivre_bobine"], n=20, what="spire")
    for s in (-1, 1):
        g.cyl(B(x, yn + s * L / 2, z + r + 0.04), "y", r * 1.1, 0.04, M["acier_noir"], n=20, what="flasque")
    g.box(B(x, yn, z + 0.02), (r * 2.2, L * SQ2 * 0.8, 0.04), M["acier_noir"], "hard", what="berceau")


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    zb_ = c.zb_dome
    ze = c.zs           # troisième jet : sol de la baie = dessus du plateau
    y0, y1 = yb, h - 0.02
    ym = (y0 + y1) / 2.0
    rx = min(h * 0.62, 0.55 * c.side)
    ry = (B(0, y1).y - B(0, y0).y) / 2.0 * 0.92
    rz = Hd - zb_
    # côtes de cuivre sur la cloche (méridiens)
    for k in range(9):
        a = math.pi * (k + 0.5) / 9
        pts = []
        for i in range(13):
            t = math.pi / 2 * i / 12
            pts.append(V((rx * 1.01 * math.cos(a) * math.cos(t), B(0, ym).y - ry * 1.01 * math.sin(a) * math.cos(t),
                          zb_ + rz * 1.01 * math.sin(t))))
        g.tube(pts, 0.025, M["cuivre_bobine"], n=6, what="cote")
    g.cyl(B(0, ym, Hd + 0.04), "z", 0.18, 0.1, M["chrome_fin"], n=20, what="lanterneau")
    g.sphere(B(0, ym, Hd + 0.12), 0.08, M["emit"], n=12, m=6, what="point_violet")
    halo(g, 0, ym, Hd + 0.2, 1.0)
    # points de lueur sur la face du caisson (violets et bleus), bandes de danger cuivre
    for k in range(9):
        x = -c.xb + 0.15 + (2 * c.xb - 0.3) * k / 8
        corps.lampe_face(g, x, yb, (ze + zb_) / 2, 0.035, M["emit"] if k % 3 else M["emit2"], M["acier_noir"])
    halo(g, 0, yb - 0.2, (ze + zb_) / 2, 0.8)
    g.hazard([B(-c.xb, yb - 0.04, ze + 0.02), B(c.xb, yb - 0.04, ze + 0.02), B(c.xb, yb - 0.04, ze + 0.09),
              B(-c.xb, yb - 0.04, ze + 0.09)], 22, t=0.01)
    # solénoïdes couchés sur les joues (avant)
    for sx in (-1, 1):
        _solenoide(g, sx * (c.xb + c.wj / 2), (c.yf + c.yt) / 2 + 0.05, c.z_joue, 0.7, 0.14)


def outil(g, c):
    """Tore de confinement couché sur 4 jambes, spires de cuivre, faisceau violet vers l'ouvrage."""
    M = g.M
    yt, zt, ze = c.yt, c.zt, c.zs
    R, r = 0.78, 0.15
    zc = zt + 1.0
    ctr = B(0, yt, zc)
    g.torus(ctr, "z", R, r, M["acier_canon"], n=48, m=14, what="tore")
    g.torus(ctr - V((0, 0, 0.02)), "z", R - r * 0.75, 0.035, M["emit"], n=40, m=6, what="lueur_tore")
    for k in range(16):
        a = TAU * k / 16
        p = ctr + V((R * math.cos(a), R * math.sin(a), 0))
        tang = V((-math.sin(a), math.cos(a), 0))
        g.tube_shell(p, tang, r + 0.03, r - 0.02, 0.06, M["cuivre_bobine"], n=16, what="spire")
    for k in range(4):
        a = TAU * k / 4 + math.pi / 4
        p = ctr + V(((R + 0.05) * math.cos(a), (R + 0.05) * math.sin(a) * 0.8, -r))
        foot = V((p.x * 1.25, p.y * 1.0 + (B(0, yt).y - ctr.y) * 0.0, ze))
        g.tube([p, foot], 0.045, M["chrome_fin"], n=10, what="jambe")
        g.cyl(foot + V((0, 0, 0.03)), "z", 0.09, 0.06, M["acier_noir"], n=14, what="pied")
    g.cyl(ctr - V((0, 0, (zc - zt - 0.25) / 2)), "z", 0.035, zc - zt - 0.25, M["emit"], n=12, what="faisceau")
    g.cyl(ctr - V((0, 0, (zc - zt - 0.25) / 2)), "z", 0.06, zc - zt - 0.25, M["emit_soft"], n=12, what="halo_faisceau")
    halo(g, 0, yt, zt + 0.5, 1.6)


def ouvrage(g, c):
    """Pièce façonnée : socle d'acier noir, point d'annihilation violet, étincelles bleues."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.cyl(B(0, yt, zt + 0.06), "z", 0.34, 0.12, M["acier_noir"], n=8, style="hard", what="enclume_champ")
    g.cyl(B(0, yt, zt + 0.15), "z", 0.18, 0.08, M["chrome_fin"], n=6, style="hard", what="ebauche")
    g.sphere(B(0, yt, zt + 0.24), 0.07, M["emit"], n=14, m=8, what="point_annihilation")
    for k in range(8):
        a = TAU * k / 8
        g.box(B(0.2 * math.cos(a), yt + 0.14 * math.sin(a), zt + 0.2 + 0.04 * (k % 2)), (0.02, 0.02, 0.02), M["emit2"],
              "flat", what="etincelle")


def piece(g, c):
    """Niveau 26 : deux bouteilles magnétiques couchées sur berceaux (coins avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.05, p["z_sol"]
        g.box(B(x, yn, z + 0.05), (0.8, 0.5 * SQ2, 0.1), M["acier_noir"], "hard", what="berceau")
        g.cyl(B(x, yn, z + 0.3), "x", 0.2, 0.62, M["acier_canon"], n=24, what="bouteille")
        for s in (-1, 1):
            g.sphere(B(x + s * 0.31, yn, z + 0.3), 0.2, M["acier_canon"], n=20, m=10, scale=(0.5, 1, 1), what="fond")
        for k in range(4):
            g.tube_shell(B(x - 0.22 + 0.147 * k, yn, z + 0.3), "x", 0.23, 0.19, 0.05, M["cuivre_bobine"], n=24,
                         what="spire")
        corps.lampe_face(g, x, yn - 0.2, z + 0.3, 0.04, M["emit"], M["chrome_fin"])
        halo(g, x, yn - 0.3, z + 0.35, 0.5)
