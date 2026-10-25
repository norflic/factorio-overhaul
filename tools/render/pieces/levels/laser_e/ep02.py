"""Laser · Âge 2 · Forge (ère I, 2×2, niveaux 3 et 4). Lot F1-B (25/10) ; fiche : fo-logs/2026-10-24_F1/FICHES_LASER.md,
âge 2 (fait foi). S'exécute DANS Blender.

En 3 mots : « tambour de briques, volets de fer, soufflet ». Un phare de forge : l'émetteur est un CAISSON FORGÉ presque
cubique à gros rivets clairs, une lentille de phare à ÉCHELONS (Fresnel) à l'avant, rougeoyante, et DEUX VOLETS DE FER
ouverts en V vers le haut et les côtés ; derrière, un SOUFFLET de forge couché en travers. Affût en TAMBOUR de briques
(2 gradins à 12 pans en assises), ceint de bandes de fer rivetées ; porte de foyer rougeoyante au sud ; enclume sur son
billot (coin arrière gauche), panier de charbon (coin arrière droit) ; outils pendus au flanc ; seau de trempe, lingots.
Palette 60/30/10 (ages.PALETTE[2]) : fer gris martelé / brique rouge / braise rouge (presque rien de jour).
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import epoques as E_
import formes as F
import orne as O
import parts as PT
from kit import SQ2, TAU
from repere import Y, at

V = Vector

EPOQUE = 2
NOM = ages.NOMS[2]
TRIPLET = ("tambour de briques", "volets de fer", "soufflet")
FOYER = ages.FOYER[2]
FAISCEAU = dict(rgb=(1.0, 0.35, 0.08), rgb2=(1.0, 0.13, 0.025), forme="ruban de braise rouge-orange, épais et court, "
                "cœur jaune", largeur=1.4)
HABILLAGE = dict(ages.CORPS[2], **E_.MAQUETTES[2])


def matieres(metal, M):
    ages.matieres(2, metal, M)
    M["caisson"] = M["fer_martele"]


def liaison(g, pts, r):
    """Conduit d'air carré en tôle rivetée (venu du soufflet)."""
    F.duct(g, pts, r * 2.2, r * 1.8)


def condensateur(g, c, x, y, z, r, h):
    """Cylindre de fer forgé : fût martelé, trois bandes rivetées de fer noir, couvercle boulonné, fente de braise."""
    M = g.M
    g.cyl((x, y, z + h / 2), "z", r, h, M["fer_martele"], n=18, style="soft", what="fut_forge")
    for f in (0.1, 0.5, 0.88):
        g.tube_shell((x, y, z + h * f), "z", r + 0.012, r - 0.01, 0.034, M["fer_noir"], n=18, what="bande")
        for k in range(5):
            a = TAU * k / 5 + 0.3
            g.bolt((x + (r + 0.012) * math.cos(a), y + (r + 0.012) * math.sin(a), z + h * f), (math.cos(a),
                   math.sin(a), 0), 0.011, M["fer_clair_f"])
    g.cyl((x, y, z + h + 0.015), "z", r * 1.05, 0.03, M["fer_noir"], n=18, style="hard", what="couvercle")
    F.bolts_ring(g, (x, y, z + h + 0.031), (0, 0, 1), r * 0.78, 6, M["fer_clair_f"], r=0.011)
    g.box((x, y, z + h + 0.034), (r * 0.9, 0.022, 0.01), M["emit"], "flat", what="fente_braise")


def _outils(g, k, h):
    """Outils pendus au flanc (repère du flanc) : tenailles, puis tisonnier, puis fer à cheval."""
    M = g.M
    g.box((0, h * 0.25, 0.012), (0.03, 0.03, 0.024), M["fer_noir"], "hard", what="crochet")
    if k % 3 == 0:
        for s in (-1, 1):
            g.box((s * 0.012, h * 0.0, 0.02), (0.012, h * 0.48, 0.012), M["fer_noir"], "hard",
                  R=Matrix.Rotation(s * 0.18, 3, "Z"), what="tenaille")
    elif k % 3 == 1:
        g.box((0, -h * 0.05, 0.02), (0.012, h * 0.55, 0.012), M["tole_forge"], "hard", what="tisonnier")
        g.box((0, -h * 0.32, 0.02), (0.04, 0.012, 0.012), M["tole_forge"], "hard", what="tisonnier")
    else:
        g.torus((0, h * 0.02, 0.016), "z", 0.04, 0.009, M["fer_noir"], n=14, m=5, what="fer_a_cheval")


def _porte_foyer(g, k, h):
    """Porte de foyer au sud du premier gradin : cadre de fer noir, grille rougeoyante, poignée."""
    M = g.M
    w = 0.2
    g.box((0, 0, 0.012), (w + 0.05, h * 0.78, 0.024), M["fer_noir"], "hard", what="cadre_foyer")
    for i in range(4):
        g.box((-w / 2 + (i + 0.5) * w / 4, 0, 0.026), (0.022, h * 0.6, 0.008), M["emit"], "flat", what="grille_foyer")
    for i in range(5):
        g.box((-w / 2 + i * w / 4, 0, 0.032), (0.012, h * 0.62, 0.012), M["fer_noir"], "hard", what="barreau")
    g.box((w * 0.45, 0, 0.045), (0.016, 0.06, 0.016), M["fer_clair_f"], "hard", what="poignee")


def _dessus2(g, k, w):
    """Dessus du second gradin : seau de trempe, pile de lingots, marteau (repère : x radial)."""
    M = g.M
    if k == 0:
        F.stave_barrel(g, (0, 0, 0.0), min(0.06, w * 0.45), 0.09, M["wood"], M["fer_noir"], open_top=M["glass_dk"])
    elif k == 1:
        for i in range(3):
            g.box((0.0, (i - 1) * 0.035, 0.012), (0.09, 0.03, 0.022), M["tole_forge"], "hard", what="lingot")
        g.box((0.0, 0.0, 0.034), (0.09, 0.03, 0.022), M["tole_forge2"], "hard", what="lingot")
    else:
        g.box((0, 0, 0.012), (0.012, 0.11, 0.012), M["wood"], "hard", what="manche")
        g.box((0, 0.05, 0.02), (0.035, 0.022, 0.03), M["fer_noir"], "hard", what="tete_marteau")


def _dessus1(g, k, w):
    """Entre deux cylindres, sur le premier gradin : piles de lingots et billettes."""
    M = g.M
    for i in range(2):
        g.box((0, (i - 0.5) * 0.03, 0.01), (0.07, 0.026, 0.02), M["tole_forge2" if k % 2 else "tole_forge"], "hard",
              what="billette")


def socle(g, c):
    """Bandes de fer rivetées, porte de foyer au sud, outils pendus, enclume (NO), panier de charbon (NE), seau,
    lingots, conduits."""
    M = g.M
    O.ceinture(g, c, 0, 0.18, 0.016, M["fer_noir"], colliers=M["fer_clair_f"], pas=0.3)
    O.ceinture(g, c, 0, 0.86, 0.014, M["fer_noir"])
    O.ceinture(g, c, 1, 0.5, 0.014, M["fer_noir"], colliers=M["fer_clair_f"], pas=0.3)
    O.rivets_flanc(g, c, 1, 0.82, M["fer_clair_f"], pas=0.1, r=0.011)
    O.sur_flanc(g, c, 0, [math.radians(270)], _porte_foyer, f=0.45, dr=0.008)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (215, 240, 300, 325, 192, 348)], _outils, f=0.55, dr=0.015)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (215, 300, 255)], _dessus2, t=0.5)
    O.sur_dessus(g, c, 0, O.visibles(O.entre_condensateurs(c), nord=0.1), _dessus1, t=0.5)
    zp = c.gradins[-1][3]
    # enclume sur son billot (coin arrière gauche)
    p = corps.place(c, "coin_NO")
    with at(g, p["x"] + 0.03, p["yn"] - 0.03, -0.3):
        g.cyl((0, 0, 0.08), "z", 0.1, 0.16, M["wood"], n=14, style="soft", what="billot")
        g.tube_shell((0, 0, 0.13), "z", 0.104, 0.09, 0.02, M["fer_noir"], n=14, what="cercle")
        g.box((0, 0, 0.19), (0.1, 0.07, 0.06), M["fer_noir"], "hard", what="enclume")
        g.box((0, 0, 0.235), (0.17, 0.08, 0.03), M["tole_forge"], "hard", what="table")
        g.cyl((0.13, 0, 0.235), "x", 0.03, 0.09, M["tole_forge"], n=10, r2=0.006, style="soft", what="bigorne")
        g.box((-0.02, 0.0, 0.258), (0.012, 0.11, 0.012), M["wood"], "hard", what="manche")
        g.box((-0.02, 0.05, 0.268), (0.04, 0.025, 0.03), M["fer_noir"], "hard", what="marteau")
    # panier de charbon (coin arrière droit) : panier de fer, charbon, braises
    p = corps.place(c, "coin_NE")
    x, y = p["x"] - 0.02, Y(p["yn"] - 0.02)
    g.cyl((x, y, 0.05), "z", 0.15, 0.1, M["soot"], n=16, what="fond_panier")
    g.tube_shell((x, y, 0.1), "z", 0.16, 0.145, 0.03, M["fer_noir"], n=20, what="cercle_panier")
    for k in range(10):
        a = TAU * k / 10
        g.box((x + 0.155 * math.cos(a), y + 0.155 * math.sin(a), 0.07), (0.016, 0.016, 0.14), M["fer_noir"], "hard",
              R=Matrix.Rotation(a, 3, "Z"), what="barreau")
    for k in range(9):
        a = TAU * k / 9 + 0.4
        rr = 0.08 * (k % 3) / 2.0
        F.lump(g, (x + rr * math.cos(a), y + rr * math.sin(a), 0.11 + 0.012 * (k % 2)), 0.045, M["soot"], sz=0.55)
    for (dx, dy) in ((0.02, -0.04), (-0.05, 0.01)):
        g.sphere((x + dx, y + dy, 0.14), 0.018, M["emit_soft"], n=8, m=5, what="braise")
    g.box((x - 0.17, y - 0.05, 0.03), (0.1, 0.05, 0.016), M["fer_noir"], "hard", R=Matrix.Rotation(0.5, 3, "Z"),
          what="pelle")
    # conduits d'air de l'enclume et du panier vers le pivot
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        q = corps.place(c, nom)
        liaison(g, [(q["x"] * 0.82, Y(q["yn"] * 0.82), 0.12), (q["x"] * 0.62, Y(q["yn"] * 0.6), zp * 0.6 + 0.06),
                    (q["x"] * 0.42, Y(q["yn"] * 0.4), zp + 0.05)], 0.024)
    g.halo((0.0, Y(-0.92), 0.12), M["_emit_rgb"], 3.0)
    g.halo((x, y, 0.2), M["_emit_rgb"], 3.0)


def piece(g, c):
    """Niveau 4 : deux BRASEROS aux coins avant (panier de fer sur trois pieds, charbon rougeoyant), sur un patin de
    pavés relié au premier gradin."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * (p["x"] + 0.02), p["yn"] + 0.02
        corps.patin(g, c, x - sx * 0.08, yn + 0.08, 0.42, 0.42, rz=sx * 0.785)
        with at(g, x, yn, z=0.035):
            for k in range(3):
                a = TAU * k / 3 + 0.5
                d = V((math.cos(a), math.sin(a), 0))
                g.box(d * 0.1 + V((0, 0, 0.1)), (0.024, 0.024, 0.22), M["fer_noir"], "hard",
                      R=Matrix.Rotation(0.3, 3, V((-d.y, d.x, 0))), what="pied")
                g.box(d * 0.15 + V((0, 0, 0.012)), (0.05, 0.05, 0.024), M["fer_noir"], "hard", what="sabot")
            g.cyl((0, 0, 0.21), "z", 0.13, 0.06, M["soot"], n=16, r2=0.15, what="vasque")
            g.tube_shell((0, 0, 0.245), "z", 0.16, 0.14, 0.03, M["fer_noir"], n=18, what="bord_vasque")
            for k in range(8):
                a = TAU * k / 8
                F.lump(g, (0.07 * math.cos(a) * (k % 2), 0.07 * math.sin(a) * (k % 2), 0.25), 0.05, M["soot"],
                       sz=0.6)
            for (dx, dy) in ((0.03, -0.03), (-0.04, 0.02), (0.0, 0.05)):
                g.sphere((dx, dy, 0.28), 0.022, M["emit"], n=8, m=5, what="braise")
        g.halo((x, Y(yn), 0.35), M["_emit_rgb"], 5.0)


def arriere(g, c):
    """SOUFFLET DE FORGE couché en travers : deux planches cerclées de fer, cuir plissé, buse de fer vers l'émetteur."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    L = 2 * bx + 0.06
    g.box((0, (y0 + y1) / 2, zb + 0.02), (L, y1 - y0, 0.04), M["wood"], "hard", what="planche")
    hz = z1 - zb - 0.08
    for k in range(4):
        f = (k + 0.5) / 4
        g.box((0, (y0 + y1) / 2 - 0.01 * k, zb + 0.04 + hz * f), (L * (0.96 - 0.04 * (k % 2)), (y1 - y0) * (0.98 - 0.12 * f),
              hz / 4 * 0.9), M["leather"], "soft", what="pli")
    g.box((0, (y0 + y1) / 2 - 0.03, z1 - 0.02), (L, (y1 - y0) * 0.86, 0.04), M["wood"], "hard",
          R=Matrix.Rotation(-0.1, 3, "X"), what="planche")
    for xx in (-L * 0.35, L * 0.35):
        g.box((xx, (y0 + y1) / 2 - 0.03, z1 + 0.002), (0.02, (y1 - y0) * 0.9, 0.012), M["fer_noir"], "hard",
              R=Matrix.Rotation(-0.1, 3, "X"), what="cercle")
    g.box((0, y0 + 0.02, z1 + 0.03), (0.03, 0.08, 0.03), M["wood"], "hard", what="poignee")
    g.cyl((0, y1 + 0.03, zb + 0.06), "y", 0.03, 0.08, M["fer_noir"], n=10, r2=0.02, what="buse")


def tete(g, c):
    """Seau à charbon et caisse à outils à l'arrière de la platine, chaîne de la trappe."""
    M = g.M
    zb = O.zb(c)
    (xl, yl, wl), (xr, yr, wr) = O.pods(c)
    g.cyl((xl, yl, zb + 0.05), "z", wl, 0.1, M["fer_noir"], n=12, r2=wl * 1.2, what="seau")
    for k in range(3):
        F.lump(g, (xl + 0.02 * (k - 1), yl + 0.01 * (k % 2), zb + 0.1), 0.03, M["soot"], sz=0.5)
    g.box((xr, yr, zb + 0.04), (wr * 2, wr * 1.6, 0.08), M["wood"], "hard", what="caisse_outils")
    g.box((xr, yr, zb + 0.085), (wr * 2.1, 0.02, 0.012), M["fer_noir"], "hard", what="ferrure")


def emetteur(g, c):
    """CAISSON FORGÉ presque cubique (plaques rivetées, gros rivets clairs), LENTILLE À ÉCHELONS rougeoyante à l'avant,
    deux VOLETS DE FER à charnières ouverts en V vers le haut et les côtés, poignées."""
    M = g.M
    re, zh = c.re, c.zh
    x0, x1, y0, y1 = -0.82 * re, 0.82 * re, -0.62 * re, 0.72 * re
    z0, z1 = zh - 0.78 * re, zh + 0.72 * re
    PT.hull(g, x0, x1, y0, y1, z0, z1, ins=(0.03, 0.03, 0.02), panel=0.16,
            mats=[M["fer_martele"], M["tole_forge"]], rivet_step=0.07)
    for zz in (z0 + 0.04, z1 - 0.04):
        g.box((0, (y0 + y1) / 2, zz), (x1 - x0 + 0.03, y1 - y0 + 0.03, 0.03), M["fer_noir"], "hard", what="cornieres")
    # lentille de phare à échelons (Fresnel) : trois marches concentriques sur le verre, sertissure de fer noir
    rl = 0.6 * re
    corps.lentille(g, c, y1, rl, verre=M["glass_dk"], cercle=M["fer_noir"])
    for k, f in enumerate((0.78, 0.55, 0.32)):
        g.tube_shell((0, y1 + 0.012 + 0.008 * k, zh), "y", rl * f + 0.012, rl * f - 0.006, 0.018, M["fer_noir"], n=32,
                     what="echelon")
    # volets : charnière sur l'arête haute de la face avant, ouverts vers le haut, l'avant et les côtés
    for sx in (-1, 1):
        h0 = V((sx * 0.05 * re, y1 - 0.01, z1 - 0.01))
        h1 = V((sx * 0.8 * re, y1 - 0.01, z1 - 0.01))
        d = V((sx * 0.45, 0.5, 0.74)).normalized() * (0.62 * re)
        q = [h0, h1, h1 + d + V((sx * 0.05, 0, 0)), h0 + d]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
        g.slab(q, nrm, 0.022, M["fer_noir"], "hard", "volet")
        for f in (0.3, 0.75):
            a, b = q[0].lerp(q[3], f), q[1].lerp(q[2], f)
            g.box((a + b) / 2 + nrm * 0.024, ((b - a).length * 0.95, 0.018, 0.01), M["fer_clair_f"], "hard",
                  R=Matrix(((b - a).normalized(), nrm.cross((b - a).normalized()), nrm)).transposed(), what="penture")
        g.cyl(h0.lerp(h1, 0.5), (1, 0, 0), 0.022, (h1 - h0).length, M["fer_noir"], n=10, what="charniere")
    # poignées latérales et gros rivets clairs
    for sx in (-1, 1):
        g.box((sx * (x1 + 0.02), 0.05 * re, zh + 0.3 * re), (0.02, 0.4 * re, 0.025), M["fer_noir"], "hard",
              what="poignee")
