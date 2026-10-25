"""Assembleur · Âge 12 · Supraconducteurs (ère IV, 6×6, niveaux 23 et 24). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge
12. Dans Blender.

En 3 mots : « lévitation, rails magnétiques, conduites givrées ». Aucun portique : deux RAILS MAGNÉTIQUES chromés courent
d'une joue à l'autre au-dessus de la table, portés par des pylônes givrés, filet cyan dessous ; trois pièces flottent
entre eux. Sur la table de noir miroir, l'ouvrage (un anneau chromé et son cœur) est en LÉVITATION au-dessus d'un
patin cyan. Dos en gradins de blanc glacé, CONDUITES GIVRÉES à colliers chromés, amas de givre ; embase de noir miroir
levée sur des pieux, liseré cyan.
Palette 60/30/10 (ages.PALETTE[12]) : blanc glacé teinté cyan / noir miroir et chrome / cyan lumineux.
"""
import math

from mathutils import Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 12
NOM = ages.NOMS[12]
TRIPLET = ("lévitation", "rails magnétiques", "conduites givrées")
FOYER = ages.FOYER[12]
TRAVAIL = dict(couches=2, images=32, organe="pièces flottantes qui oscillent et tournent (32 images, boucle) ; filets "
                                           "cyan qui pulsent (couche glow)")
HABILLAGE = dict(ages.CORPS[12], forme_embase='pieds', forme_dos='gradins', forme_joues='basses',
                 forme_portique='aucun')


def matieres(metal, M):
    ages.matieres(12, metal, M)


def _flotte(g, p, r, mat):
    """Pièce flottante : bloc chromé, disque cyan sous elle (le jour de la lévitation)."""
    M = g.M
    g.box(p, (r * 2, r * 2 * SQ2, r * 1.4), mat, "soft", what="piece_flottante")
    g.cyl(p - V((0, 0, r * 0.7 + 0.05)), "z", r * 0.8, 0.012, M["emit"], n=16, style="flat", what="jour_cyan")


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    y1 = h - 0.02
    hs = c.hs_gradins
    ze = c.zs           # troisième jet : sol de la baie = dessus du plateau
    # filets cyan au bord de chaque gradin
    for k in range(3):
        yy = yb + (y1 - yb) * k / 3.0
        g.box(B(0, yy - 0.02, hs[k] - 0.05), (2 * (h - 0.06 * k) - 0.3, 0.02, 0.025), M["emit_soft"], "flat",
              what="filet_cyan")
    halo(g, 0, yb - 0.2, hs[0], 1.0)
    # conduites givrées le long de la face, colliers chromés, amas de givre au pied
    for k, z in enumerate((ze + 0.14, ze + 0.34)):
        x0 = -h + 0.2
        pts = [B(x0, yb - 0.1, z), B(-0.6, yb - 0.1, z), B(-0.3, yb - 0.25, ze + 0.06)]
        if k:
            pts = [B(-x0, yb - 0.1, z), B(0.6, yb - 0.1, z), B(0.3, yb - 0.25, ze + 0.06)]
        g.tube(pts, 0.06, M["frost"], n=12, what="conduite_givree")
        for f in (0.15, 0.4, 0.65):
            p = pts[0].lerp(pts[1], f)
            g.tube_shell(p, "x", 0.075, 0.055, 0.04, M["chrome_mat"], n=14, what="collier")
    for k in range(9):
        F.lump(g, B(-1.4 + 0.35 * k, yb - 0.25 - 0.05 * (k % 2), ze), 0.08, M["frost"])
    # grilles chromées et voyants cyan sur les gradins
    for k in range(3):
        yy = yb + (y1 - yb) * (k + 0.5) / 3.0
        for sx in (-1, 1):
            corps.lampe(g, B(sx * (h - 0.3), yy, hs[k]), 0.04, M["emit"])
    g.grille([B(-0.8, yb - 0.03, hs[0] - 0.4), B(0.8, yb - 0.03, hs[0] - 0.4), B(0.8, yb - 0.03, hs[0] - 0.15),
              B(-0.8, yb - 0.03, hs[0] - 0.15)], 8, slat_mat=M["grille_chrome"])
    # vases de Dewar sur le dernier gradin
    yd = yb + (y1 - yb) * 5 / 6.0
    for x in (-1.6, -1.0, 1.0, 1.6):
        g.cyl(B(x, yd, Hd + 0.22), "z", 0.15, 0.44, M["chrome_mat"], n=20, what="dewar")
        g.sphere(B(x, yd, Hd + 0.44), 0.15, M["chrome_mat"], n=20, m=8, scale=(1, 1, 0.5), what="dome_dewar")
        g.tube_shell(B(x, yd, Hd + 0.3), "z", 0.16, 0.14, 0.04, M["emit_soft"], n=20, what="bague_cyan")


def outil(g, c):
    """Deux rails magnétiques d'une joue à l'autre, pylônes givrés, trois pièces en lévitation."""
    M = g.M
    yt, zt = c.yt, c.zt
    zr = zt + 1.0
    L = 2 * c.xm
    for sy in (-1, 1):
        y = yt + sy * 0.4
        g.box(B(0, y, zr), (L, 0.1 * SQ2, 0.1), M["chrome_mat"], "soft", what="rail")
        g.box(B(0, y, zr - 0.065), (L - 0.2, 0.05 * SQ2, 0.02), M["emit"], "flat", what="filet_rail")
        for sx in (-1, 1):
            x = sx * c.xm
            g.box(B(x, y, (c.z_joue + zr) / 2), (0.16, 0.16 * SQ2, zr - c.z_joue), M["frost"], "soft", what="pylone")
            g.tube_shell(B(x, y, zr - 0.25), "z", 0.13, 0.1, 0.05, M["chrome_mat"], n=16, what="bague")
            F.lump(g, B(x, y - 0.12, c.z_joue), 0.09, M["frost"])
    halo(g, 0, yt, zr - 0.1, 1.4)
    for k, (x, dz, r) in enumerate(((-0.7, -0.3, 0.09), (0.15, -0.42, 0.07), (0.85, -0.25, 0.1))):
        _flotte(g, B(x, yt + (0.08 if k % 2 else -0.08), zr + dz), r, M["chrome_mat"] if k != 1 else M["noir_miroir"])


def ouvrage(g, c):
    """Anneau chromé et cœur en lévitation au-dessus d'un patin cyan."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.cyl(B(0, yt, zt + 0.03), "z", 0.36, 0.06, M["noir_miroir"], n=32, what="patin")
    F.lit_ring(g, B(0, yt, zt + 0.065), "z", 0.32, M["emit"], w=0.03, t=0.012)
    g.cyl(B(0, yt, zt + 0.07), "z", 0.2, 0.008, M["emit_soft"], n=24, style="flat", what="lueur_patin")
    zf = zt + 0.36
    g.torus(B(0, yt, zf), "y", 0.22, 0.05, M["chrome_mat"], n=32, m=10, what="anneau")
    g.sphere(B(0, yt, zf), 0.1, M["noir_miroir"], n=20, m=10, what="coeur")
    g.torus(B(0, yt, zf), "z", 0.12, 0.012, M["emit"], n=24, m=5, what="equateur")
    halo(g, 0, yt, zt + 0.2, 1.0)
    _ = math


def piece(g, c):
    """Niveau 24 : bobine supraconductrice couchée sur un traîneau givré (coins avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.05, p["z_sol"]
        for s in (-1, 1):
            g.box(B(x + s * 0.3, yn, z + 0.03), (0.06, 0.8 * SQ2, 0.06), M["chrome_mat"], "hard", what="patin")
        g.box(B(x, yn, z + 0.09), (0.7, 0.7 * SQ2, 0.06), M["frost"], "soft", what="traineau")
        g.torus(B(x, yn, z + 0.2), "z", 0.25, 0.08, M["chrome_mat"], n=32, m=10, what="bobine")
        g.tube_shell(B(x, yn, z + 0.28), "z", 0.2, 0.17, 0.02, M["emit"], n=28, what="bague_cyan")
        F.lump(g, B(x - 0.25, yn - 0.25, z + 0.12), 0.08, M["frost"])
        halo(g, x, yn, z + 0.35, 0.6)
