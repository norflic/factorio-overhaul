"""Assembleur · Âge 13 · Antimatière (ère V, 6×6, niveaux 25 et 26). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md,
âge 13. Dans Blender.

En 3 mots : « tore, faisceau d'annihilation, spires ». Plan en TOUR : fût d'acier canon coiffé d'une cloche de verre fumé
violet à côtes de cuivre ; un grand TORE de confinement l'enserre à mi-hauteur, ceint de SPIRES de cuivre rouge ; de sa
buse avant tombe le FAISCEAU D'ANNIHILATION violet sur l'ouvrage, au pied sud. Solénoïdes couchés sur les annexes,
points violets et bleus.
Palette 60/30/10 (ages.PALETTE[13]) : acier canon gris froid / cuivre rouge des bobinages / lueur violette et bleue.
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
HABILLAGE = dict(ages.CORPS[13], plan='tour', forme_embase='carre', forme_dos='plat', forme_joues='caisson',
                 forme_portique='aucun')
DENSITE = dict(p=0.6, lampes=0.1)


def matieres(metal, M):
    ages.matieres(13, metal, M)


def _solenoide(g, p, L, r):
    """Solénoïde couché nord-sud à la place p (Vector Blender au sol de l'annexe)."""
    M = g.M
    g.cyl(p + V((0, 0, r + 0.04)), "y", r, L, M["acier_canon"], n=20, what="solenoide")
    n = int(L / 0.07)
    for k in range(n):
        g.tube_shell(p + V((0, -L / 2 + (k + 0.5) * L / n, r + 0.04)), "y", r + 0.02, r - 0.01, 0.045,
                     M["cuivre_bobine"], n=20, what="spire")
    for s in (-1, 1):
        g.cyl(p + V((0, s * L / 2, r + 0.04)), "y", r * 1.1, 0.04, M["acier_noir"], n=20, what="flasque")
    g.box(p + V((0, 0, 0.02)), (r * 2.2, L * 0.8, 0.04), M["acier_noir"], "hard", what="berceau")


def socle(g, c):
    """Cloche de verre fumé à côtes de cuivre, points de lueur du fût, solénoïdes sur les annexes."""
    M = g.M
    Rt, zr, Ht = c.Rt, c.zr, c.Ht
    rc = Rt * 1.05
    g.sphere(V((0, 0, Ht + 0.06)), rc, M["verre_fume"], n=36, m=18, scale=(1, 1, 0.75), what="cloche")
    for k in range(10):
        a = TAU * k / 10
        pts = [V((rc * 1.01 * math.cos(a) * math.cos(t), rc * 1.01 * math.sin(a) * math.cos(t),
                  Ht + 0.06 + 0.75 * rc * 1.01 * math.sin(t))) for t in [math.pi / 2 * i / 10 for i in range(11)]]
        g.tube(pts, 0.022, M["cuivre_bobine"], n=6, what="cote")
    g.sphere(V((0, 0, Ht + 0.06 + 0.75 * rc + 0.06)), 0.07, M["emit"], n=12, m=6, what="point_violet")
    halo(g, 0, 0, Ht + 0.8, 1.0)
    for k in range(9):
        a = math.radians(205 + 16 * k)
        z = zr + (0.2 if k % 2 else 0.33) * (Ht - zr)
        corps.lampe(g, V(((Rt + 0.01) * math.cos(a), (Rt + 0.01) * math.sin(a), z)), 0.03,
                    M["emit"] if k % 3 else M["emit2"])
    halo(g, 0, -Rt / SQ2 - 0.1, zr + 0.3 * (Ht - zr), 0.8)
    for sx in (-1, 1):
        xa = sx * (c.h - c.ann / 2.0)
        ya = c.h - c.ann / 2.0
        _solenoide(g, B(xa, ya - 0.1, c.Hann), 0.9, 0.16)
        c.reserves.append((xa, ya, c.ann * 0.45))


def outil(g, c):
    """Tore de confinement autour du fût, spires de cuivre, buse avant et faisceau violet vers l'ouvrage."""
    M = g.M
    Rt = c.Rt
    zc = c.zg + 0.4
    R, r = Rt + 0.5, 0.17
    ctr = V((0, 0, zc))
    g.torus(ctr, "z", R, r, M["acier_canon"], n=56, m=14, what="tore")
    g.torus(ctr - V((0, 0, 0.02)), "z", R - r * 0.75, 0.035, M["emit"], n=48, m=6, what="lueur_tore")
    for k in range(18):
        a = TAU * k / 18
        p = ctr + V((R * math.cos(a), R * math.sin(a), 0))
        g.tube_shell(p, V((-math.sin(a), math.cos(a), 0)), r + 0.03, r - 0.02, 0.06, M["cuivre_bobine"], n=16,
                     what="spire")
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        g.tube([V((Rt * math.cos(a), Rt * math.sin(a), zc)), V(((R - r) * math.cos(a), (R - r) * math.sin(a), zc))],
               0.05, M["chrome_fin"], n=8, what="entretoise")
    # buse avant (vers le sud) et faisceau vertical vers l'ouvrage
    pb = V((0, -R, zc))
    pw = B(0, c.yt, c.zt + 0.25)
    g.cyl(pb + V((0, -0.05, -r - 0.05)), "z", 0.09, 0.16, M["acier_noir"], n=16, r2=0.05, what="buse")
    top = V((pw.x, pw.y, pb.z - r - 0.14))
    g.tube([pb + V((0, -0.05, -r - 0.12)), top], 0.04, M["acier_noir"], n=8, what="guide_faisceau")
    g.cyl(V((pw.x, pw.y, (top.z + pw.z) / 2)), "z", 0.035, top.z - pw.z, M["emit"], n=12, what="faisceau")
    g.cyl(V((pw.x, pw.y, (top.z + pw.z) / 2)), "z", 0.06, top.z - pw.z, M["emit_soft"], n=12, what="halo_faisceau")
    halo(g, 0, c.yt, c.zt + 0.5, 1.4)


def ouvrage(g, c):
    """Pièce façonnée : enclume de champ d'acier noir, point d'annihilation violet, étincelles bleues."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.cyl(B(0, yt, (c.zr + zt) / 2 + 0.04), "z", 0.36, zt - c.zr + 0.08, M["acier_noir"], n=8, style="hard",
          what="enclume_champ")
    g.cyl(B(0, yt, zt + 0.12), "z", 0.18, 0.08, M["chrome_fin"], n=6, style="hard", what="ebauche")
    g.sphere(B(0, yt, zt + 0.22), 0.07, M["emit"], n=14, m=8, what="point_annihilation")
    for k in range(8):
        a = TAU * k / 8
        g.box(B(0.2 * math.cos(a), yt + 0.14 * math.sin(a), zt + 0.18 + 0.04 * (k % 2)), (0.02, 0.02, 0.02),
              M["emit2"], "flat", what="etincelle")


def entree(g, c, p):
    """Piège de Penning : bouteille courte à bobines, point violet (entrée)."""
    M = g.M
    g.cyl(B(p["x"], p["yn"], p["z"] + p["r"] * 0.6), "x", p["r"] * 0.55, 1.6 * p["r"], M["acier_canon"], n=20,
          what="piege")
    for f in (-0.5, 0.0, 0.5):
        g.tube_shell(B(p["x"] + f * p["r"], p["yn"], p["z"] + p["r"] * 0.6), "x", p["r"] * 0.62, p["r"] * 0.5, 0.06,
                     M["cuivre_bobine"], n=20, what="bobine")
    g.sphere(B(p["x"], p["yn"] - p["r"] * 0.4, p["z"] + p["r"] * 0.6), 0.035, M["emit"], n=10, m=5, what="point")


def sortie(g, c, p):
    """Écrin d'acier noir : pièces d'antimatière façonnées, liseré violet (sortie)."""
    M = g.M
    corps.bac(g, c, p, M["acier_noir"], M["chrome_fin"], forme="sphere")
    g.torus(B(p["x"], p["yn"], p["z"] + 0.17), "z", p["r"] * 0.7, 0.01, M["emit"], n=20, m=4, what="liseré")


def piece(g, c):
    """Niveau 26 (plus grande) : deux bouteilles magnétiques couchées sur berceaux, bobinées (coins avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.05, p["z_sol"]
        g.box(B(x, yn, z + 0.06), (0.9, 0.55 * SQ2, 0.12), M["acier_noir"], "hard", what="berceau")
        g.cyl(B(x, yn, z + 0.38), "x", 0.25, 0.7, M["acier_canon"], n=24, what="bouteille")
        for s in (-1, 1):
            g.sphere(B(x + s * 0.35, yn, z + 0.38), 0.25, M["acier_canon"], n=20, m=10, scale=(0.5, 1, 1), what="fond")
        for k in range(5):
            g.tube_shell(B(x - 0.26 + 0.13 * k, yn, z + 0.38), "x", 0.28, 0.24, 0.05, M["cuivre_bobine"], n=24,
                         what="spire")
        corps.lampe_face(g, x, yn - 0.25, z + 0.38, 0.045, M["emit"], M["chrome_fin"])
        halo(g, x, yn - 0.3, z + 0.4, 0.6)
