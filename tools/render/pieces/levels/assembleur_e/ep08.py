"""Assembleur · Âge 8 · Marais (ère III, 5×5, niveaux 15 et 16). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 8. Dans
Blender.

En 3 mots : « bocaux, siphon, cabane sur pieux ». Une CABANE SUR PIEUX : embase de planches mouillées levée sur des
pieux, dos de planches à fenêtres jaunes, deux grandes CUVES DE VERRE cerclées de cuivre terni sur le toit (liquide jaune
toxique, bulles). Une poutre de bois porte le SIPHON : bulbe de verre et long col qui plonge dans la grande jarre de la
table, entourée de BOCAUX lumineux. Cordages, lanternes, paniers d'osier.
Palette 60/30/10 (ages.PALETTE[8]) : vert-de-gris / bois et cuivre terni / jaune toxique.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 8
NOM = ages.NOMS[8]
TRIPLET = ("bocaux", "siphon", "cabane sur pieux")
FOYER = ages.FOYER[8]
TRAVAIL = dict(couches=2, images=16, organe="bulles qui montent dans les cuves et les bocaux, niveau du siphon qui "
                                           "baisse et remonte (couche glow, 16 images) ; chariot immobile")
HABILLAGE = dict(ages.CORPS[8], forme_embase='pieds', forme_dos='plat', forme_joues='basses', forme_portique='poutre',
                 mat_dos='bois_mouille', mat_joues='vdg_capot', mat_portique='bois_mouille')


def matieres(metal, M):
    ages.matieres(8, metal, M)


def _cuve(g, x, yn, z, r, hgt, seed=0):
    """Cuve de verre debout : liquide jaune (lumineux en tête), cerclages et couvercle de cuivre terni, bulles."""
    M = g.M
    g.cyl(B(x, yn, z + 0.04), "z", r + 0.04, 0.08, M["cuivre_terni"], n=24, what="socle_cuve")
    g.cyl(B(x, yn, z + 0.08 + hgt / 2), "z", r, hgt, M["verre_toxique"], n=28, what="cuve")
    g.cyl(B(x, yn, z + 0.08 + hgt * 0.78), "z", r * 1.005, hgt * 0.12, M["emit_soft"], n=28, what="menisque")
    for f in (0.2, 0.55, 0.92):
        g.tube_shell(B(x, yn, z + 0.08 + hgt * f), "z", r + 0.022, r - 0.005, 0.03, M["cuivre_terni"], n=28,
                     what="cerclage")
    g.cyl(B(x, yn, z + 0.1 + hgt), "z", r * 0.7, 0.06, M["cuivre_terni"], n=20, r2=r * 0.3, what="couvercle")
    import random
    rng = random.Random(seed)
    for k in range(7):
        a = rng.random() * 2 * math.pi
        g.sphere(B(x + r * 0.8 * math.cos(a), yn - r * 0.55, z + 0.12 + hgt * (0.1 + 0.6 * rng.random())), 0.018,
                 M["emit"], n=8, m=5, what="bulle")
    halo(g, x, yn - r, z + hgt * 0.8, 0.9)


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    ym = (yb + h) / 2.0
    # fenêtres jaunes, conduites de cuivre terni, cordages et mousse sur la face
    for x in (-1.5, -0.55, 0.55, 1.5):
        corps.fenetre(g, x, yb, (c.zs + Hd) / 2 + 0.05, 0.36, 0.3, M["emit_soft"], M["bois_mousse"])
        halo(g, x, yb - 0.2, (c.zs + Hd) / 2, 0.5)
    g.pipe([B(-h + 0.2, yb - 0.08, Hd - 0.2), B(0, yb - 0.08, Hd - 0.25), B(h - 0.2, yb - 0.08, Hd - 0.2)], 0.035,
           M["cuivre_terni"], fl_mat=M["vdg_capot"], bolt_mat=M["cuivre_terni"])
    for x in (-1.0, 1.0):
        g.cable(B(x - 0.3, yb - 0.06, Hd - 0.08), B(x + 0.3, yb - 0.06, Hd - 0.08), 0.12, 0.012, M["wicker"])
    for k in range(6):
        g.box(B(-h + 0.3 + 0.8 * k, yb - 0.05, c.zs + 0.06 + 0.05 * (k % 2)), (0.3, 0.02, 0.16), M["bois_mousse"], "soft",
              what="mousse")
    # deux grandes cuves de verre sur le toit, conduite qui les relie
    _cuve(g, -1.15, ym, Hd, 0.32, 0.72, seed=1)
    _cuve(g, 1.15, ym, Hd, 0.32, 0.72, seed=2)
    g.pipe([B(-0.85, ym, Hd + 0.7), B(0, ym - 0.1, Hd + 0.85), B(0.85, ym, Hd + 0.7)], 0.03, M["cuivre_terni"],
           fl_mat=M["cuivre_terni"])
    # lanternes aux coins de la baie
    for sx in (-1, 1):
        F.lantern(g, tuple(B(sx * (c.xb - 0.15), c.yf + 0.1, c.z_joue)), M["emit"])
        halo(g, sx * (c.xb - 0.15), c.yf + 0.1, c.z_joue + 0.1, 0.5)


def outil(g, c):
    """Siphon : poulie et chariot de bois, bulbe de verre lumineux, col qui plonge dans la jarre."""
    M = g.M
    yt, zt, zp, bp = c.yt, c.zt, c.zp, c.bp
    top = zp + bp
    g.cyl(B(0, yt, top + 0.1), "y", 0.09, 0.08, M["cuivre_terni"], n=16, what="poulie")
    zb = zt + 0.95
    g.cyl(B(0, yt, (top + zb + 0.2) / 2), "z", 0.008, top - zb - 0.2, M["wicker"], n=6, what="corde")
    g.tube_shell(B(0, yt, zb + 0.2), "z", 0.07, 0.05, 0.05, M["cuivre_terni"], n=16, what="collier")
    g.sphere(B(0, yt, zb), 0.2, M["verre_toxique"], n=24, m=12, what="bulbe")
    g.sphere(B(0, yt - 0.03, zb - 0.04), 0.15, M["emit_soft"], n=20, m=10, scale=(1, 1, 0.7), what="liquide_bulbe")
    g.cyl(B(0.0, yt, (zb - 0.2 + zt + 0.45) / 2), "z", 0.035, zb - 0.2 - zt - 0.45, M["reflet_verre"], n=10,
          what="col")
    for sx in (-1, 1):
        g.tube([B(sx * 0.17, yt, zb + 0.05), B(sx * 0.32, yt - 0.05, zb - 0.15), B(sx * 0.3, yt - 0.08, zt + 0.42)],
               0.022, M["cuivre_terni"], n=8, what="serpentin")
    halo(g, 0, yt, zb, 1.2)


def ouvrage(g, c):
    """Grande jarre sous le siphon, six bocaux lumineux à couvercle de cuivre."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.cyl(B(0, yt, zt + 0.2), "z", 0.17, 0.4, M["verre_toxique"], n=24, r2=0.12, what="jarre")
    g.cyl(B(0, yt, zt + 0.3), "z", 0.172, 0.12, M["emit_soft"], n=24, what="niveau_jarre")
    k = 0
    for sx in (-1, 1):
        for j in range(3):
            x = sx * (0.38 + 0.13 * (j % 2))
            y = yt - 0.2 + 0.2 * j
            g.cyl(B(x, y, zt + 0.1), "z", 0.07, 0.2, M["verre_toxique"], n=16, what="bocal")
            g.cyl(B(x, y, zt + 0.12), "z", 0.072, 0.1, M["emit"] if k % 2 else M["emit_soft"], n=16, what="contenu")
            g.cyl(B(x, y, zt + 0.21), "z", 0.06, 0.03, M["cuivre_terni"], n=12, what="couvercle")
            k += 1
    halo(g, 0, yt - 0.2, zt + 0.3, 0.8)


def entree(g, c):
    """Panier d'osier plein de roseaux (entrée)."""
    M = g.M
    p = corps.place(c, "joue_O")
    r, z = p["r"], c.z_joue
    g.cyl(B(p["x"], p["yn"], z + 0.14), "z", r, 0.28, M["wicker"], n=20, r2=r * 1.1, what="panier")
    for k in range(14):
        a = 2 * math.pi * k / 14
        g.box(B(p["x"] + 0.5 * r * math.cos(a), p["yn"] + 0.4 * r * math.sin(a), z + 0.38), (0.02, 0.02, 0.24),
              M["bois_mousse"], "hard", R=Matrix.Rotation(0.2 * math.cos(a), 3, "Y"), what="roseau")


def piece(g, c):
    """Niveau 16 : paniers d'osier pleins de bocaux (coin avant gauche), tonneaux et cordage (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    # ronde 3 : le sol vu entre les trois paniers faisait un trou enfermé (29 px) : claie de planches dessous
    g.box(B(po["x"], po["yn"] - 0.03, z + 0.03), (0.66, 0.6 * SQ2, 0.06), M["bois_mouille"], "hard", what="claie")
    z += 0.06
    for k, (dx, dy) in enumerate(((-0.15, 0.1), (0.18, 0.05), (0.0, -0.22))):
        x, y = po["x"] + dx, po["yn"] + dy
        g.cyl(B(x, y, z + 0.1), "z", 0.16, 0.2, M["wicker"], n=18, r2=0.18, what="panier")
        for j in range(3):
            a = 2 * math.pi * j / 3 + k
            g.cyl(B(x + 0.07 * math.cos(a), y + 0.05 * math.sin(a), z + 0.26), "z", 0.05, 0.14, M["verre_toxique"],
                  n=12, what="bocal")
            g.cyl(B(x + 0.07 * math.cos(a), y + 0.05 * math.sin(a), z + 0.27), "z", 0.052, 0.07, M["emit_soft"], n=12,
                  what="contenu")
    halo(g, po["x"], po["yn"] - 0.1, z + 0.35, 0.6)
    for k, (dx, dy) in enumerate(((-0.15, 0.12), (0.15, 0.12))):
        F.stave_barrel(g, tuple(B(pe["x"] + dx, pe["yn"] + dy, z)), 0.15, 0.32, M["bois_mouille"], M["cuivre_terni"])
    g.torus(B(pe["x"], pe["yn"] - 0.2, z + 0.03), "z", 0.13, 0.03, M["wicker"], n=20, m=6, what="cordage")
    g.torus(B(pe["x"], pe["yn"] - 0.2, z + 0.08), "z", 0.1, 0.03, M["wicker"], n=20, m=6, what="cordage")
