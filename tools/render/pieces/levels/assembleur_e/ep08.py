"""Assembleur · Âge 8 · Marais (ère III, 5×5, niveaux 15 et 16). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md, âge 8.
Dans Blender.

En 3 mots : « bocaux, siphon, cabane sur pieux ». Plan ROND : une CABANE ronde de planches mouillées levée sur une
couronne de PIEUX, son croissant nord bardé de planches à fenêtres jaunes et coiffé d'un auvent de cuivre terni ; deux
grandes CUVES DE VERRE cerclées de cuivre sur le croissant. Trois poutres de bois montent au moyeu ; le SIPHON y pend :
bulbe de verre lumineux, col qui plonge dans la grande jarre du lit, entourée de BOCAUX. Cordages, lanternes, mousse.
Palette 60/30/10 (ages.PALETTE[8]) : vert-de-gris / bois et cuivre terni / jaune toxique.
"""
import math
import random

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 8
NOM = ages.NOMS[8]
TRIPLET = ("bocaux", "siphon", "cabane sur pieux")
FOYER = ages.FOYER[8]
TRAVAIL = dict(couches=2, images=16, organe="bulles qui montent dans les cuves et les bocaux, niveau du siphon qui "
                                           "baisse et remonte (couche glow, 16 images)")
HABILLAGE = dict(ages.CORPS[8], capots=("bois_mouille", "vdg_capot"), plan='rond', forme_embase='carre',
                 forme_dos='plat', forme_joues='caisson', forme_portique='aucun')
DENSITE = dict(p=0.55, lampes=0.06)


def matieres(metal, M):
    ages.matieres(8, metal, M)


def _cuve(g, x, yn, z, r, hgt, seed=0):
    M = g.M
    g.cyl(B(x, yn, z + 0.04), "z", r + 0.04, 0.08, M["cuivre_terni"], n=24, what="socle_cuve")
    g.cyl(B(x, yn, z + 0.08 + hgt / 2), "z", r, hgt, M["verre_toxique"], n=28, what="cuve")
    g.cyl(B(x, yn, z + 0.08 + hgt * 0.78), "z", r * 1.005, hgt * 0.12, M["emit_soft"], n=28, what="menisque")
    for f in (0.2, 0.55, 0.92):
        g.tube_shell(B(x, yn, z + 0.08 + hgt * f), "z", r + 0.022, r - 0.005, 0.03, M["cuivre_terni"], n=28,
                     what="cerclage")
    g.cyl(B(x, yn, z + 0.1 + hgt), "z", r * 0.7, 0.06, M["cuivre_terni"], n=20, r2=r * 0.3, what="couvercle")
    rng = random.Random(seed)
    for k in range(7):
        a = rng.random() * TAU
        g.sphere(B(x + r * 0.8 * math.cos(a), yn - r * 0.55, z + 0.12 + hgt * (0.1 + 0.6 * rng.random())), 0.018,
                 M["emit"], n=8, m=5, what="bulle")
    halo(g, x, yn - r, z + hgt * 0.8, 0.9)


def socle(g, c):
    """Pieux, bardage du croissant, fenêtres jaunes, auvent, cuves de verre, mousse, cordages, lanternes."""
    M = g.M
    Rd = c.Rb - 0.06
    R0 = Rd - c.ep_cr
    # couronne de PIEUX devant le flanc sud du tambour
    for k in range(17):
        a = math.radians(192 + 9.8 * k)
        x, y = (Rd + 0.03) * math.cos(a), (Rd + 0.03) * math.sin(a)
        g.cyl(B(x, y, c.zr / 2), "z", 0.055, c.zr + 0.04, M["bois_mousse"] if k % 3 else M["bois_mouille"], n=8,
              style="soft", what="pieu")
        if k % 2 == 0:
            g.torus(B(x, y, c.zr * 0.35), "z", 0.06, 0.012, M["wicker"], n=10, m=4, what="ligature")
    # fenêtres jaunes et poteaux du bardage sur la face intérieure du croissant
    for k, ad in enumerate((40, 65, 90, 115, 140)):
        a = math.radians(ad)
        x, y = (R0 - 0.02) * math.cos(a), (R0 - 0.02) * math.sin(a)
        corps.fenetre(g, x, y, (c.zr + c.Hc) / 2 + 0.05, 0.28, 0.28, M["emit_soft"], M["bois_mousse"])
        halo(g, x, y - 0.2, (c.zr + c.Hc) / 2, 0.5)
    for ad in (28, 52, 77, 103, 128, 152):
        a = math.radians(ad)
        g.box(B((R0 - 0.03) * math.cos(a), (R0 - 0.03) * math.sin(a), (c.zr + c.Hc) / 2), (0.06, 0.05, c.Hc - c.zr),
              M["bois_mousse"], "hard", what="poteau")
    # auvent de cuivre terni au sommet du croissant (bord intérieur)
    for k in range(10):
        a0, a1 = math.radians(16 + 14.8 * k), math.radians(16 + 14.8 * (k + 1))
        pa = B(R0 * math.cos(a0), R0 * math.sin(a0), c.Hc)
        pb = B(R0 * math.cos(a1), R0 * math.sin(a1), c.Hc)
        pc = B((R0 - 0.2) * math.cos(a1), (R0 - 0.2) * math.sin(a1), c.Hc - 0.12)
        pd = B((R0 - 0.2) * math.cos(a0), (R0 - 0.2) * math.sin(a0), c.Hc - 0.12)
        g.slab([pa, pb, pc, pd], (pb - pa).cross(pd - pa).normalized(), 0.025, M["cuivre_terni"], "hard", "auvent")
    # deux grandes cuves de verre sur le croissant, conduite qui les relie au moyeu
    Rm = (R0 + Rd) / 2.0
    for k, ad in enumerate((48, 132)):
        a = math.radians(ad)
        _cuve(g, Rm * math.cos(a), Rm * math.sin(a), c.Hc, 0.3, 0.65, seed=k + 1)
        c.reserves.append((Rm * math.cos(a), Rm * math.sin(a), 0.42))
        g.pipe([B(Rm * math.cos(a), Rm * math.sin(a) - 0.2, c.Hc + 0.6), c.hub + V((0.3 * (1 if k else -1), 0, 0.1))],
               0.028, M["cuivre_terni"], fl_mat=M["vdg_capot"])
    # mousse au pied du croissant, cordages lovés, lanternes
    for k in range(8):
        a = math.radians(20 + 20 * k)
        g.box(B((R0 - 0.02) * math.cos(a), (R0 - 0.02) * math.sin(a), c.zr + 0.05), (0.26, 0.06, 0.1),
              M["bois_mousse"], "soft", what="mousse")
    Ra = Rd - c.ep_an / 2.0
    for sx in (-1, 1):
        a = math.radians(270 + sx * 45)
        x, y = Ra * math.cos(a), Ra * math.sin(a)
        F.lantern(g, tuple(B(x, y, c.Ha)), M["emit"])
        halo(g, x, y, c.Ha + 0.1, 0.6)
        a2 = math.radians(270 + sx * 20)
        g.torus(B(Ra * math.cos(a2), Ra * math.sin(a2), c.Ha + 0.02), "z", 0.1, 0.025, M["wicker"], n=16, m=5,
                what="cordage")
        c.reserves += [(x, y, 0.12), (Ra * math.cos(a2), Ra * math.sin(a2), 0.15)]


def outil(g, c):
    """Siphon pendu au moyeu : bulbe de verre lumineux, col qui plonge dans la jarre, serpentins de cuivre."""
    M = g.M
    zt = c.zt
    zb = zt + 0.95
    hub = c.hub
    g.cyl(B(0, c.cy, (hub.z + zb + 0.2) / 2), "z", 0.01, hub.z - zb - 0.2, M["wicker"], n=6, what="corde")
    g.tube_shell(B(0, c.cy, zb + 0.2), "z", 0.07, 0.05, 0.05, M["cuivre_terni"], n=16, what="collier")
    g.sphere(B(0, c.cy, zb), 0.22, M["verre_toxique"], n=24, m=12, what="bulbe")
    g.sphere(B(0, c.cy - 0.03, zb - 0.04), 0.17, M["emit_soft"], n=20, m=10, scale=(1, 1, 0.7), what="liquide_bulbe")
    g.cyl(B(0.0, c.cy, (zb - 0.22 + zt + 0.45) / 2), "z", 0.035, zb - 0.22 - zt - 0.45, M["reflet_verre"], n=10,
          what="col")
    for sx in (-1, 1):
        g.tube([B(sx * 0.19, c.cy, zb + 0.05), B(sx * 0.34, c.cy - 0.05, zb - 0.15), B(sx * 0.32, c.cy - 0.08,
                                                                                      zt + 0.42)],
               0.022, M["cuivre_terni"], n=8, what="serpentin")
    halo(g, 0, c.cy, zb, 1.2)


def ouvrage(g, c):
    """Grande jarre sous le siphon, huit bocaux lumineux en couronne."""
    M = g.M
    zt = c.zt
    g.cyl(B(0, c.cy, zt + 0.22), "z", 0.18, 0.44, M["verre_toxique"], n=24, r2=0.13, what="jarre")
    g.cyl(B(0, c.cy, zt + 0.32), "z", 0.182, 0.12, M["emit_soft"], n=24, what="niveau_jarre")
    for k in range(8):
        a = math.radians(190 + 23 * k)
        x, y = 0.55 * math.cos(a), c.cy + 0.42 * math.sin(a)
        g.cyl(B(x, y, zt + 0.1), "z", 0.07, 0.2, M["verre_toxique"], n=16, what="bocal")
        g.cyl(B(x, y, zt + 0.12), "z", 0.072, 0.1, M["emit"] if k % 2 else M["emit_soft"], n=16, what="contenu")
        g.cyl(B(x, y, zt + 0.21), "z", 0.06, 0.03, M["cuivre_terni"], n=12, what="couvercle")
    halo(g, 0, c.cy - 0.2, zt + 0.3, 0.8)


def entree(g, c, p):
    """Panier d'osier plein de roseaux (entrée)."""
    M = g.M
    r, z = p["r"], p["z"]
    g.cyl(B(p["x"], p["yn"], z + 0.14), "z", r, 0.28, M["wicker"], n=20, r2=r * 1.1, what="panier")
    for k in range(12):
        a = TAU * k / 12
        g.box(B(p["x"] + 0.5 * r * math.cos(a), p["yn"] + 0.4 * r * math.sin(a), z + 0.38), (0.02, 0.02, 0.24),
              M["bois_mousse"], "hard", R=Matrix.Rotation(0.2 * math.cos(a), 3, "Y"), what="roseau")


def sortie(g, c, p):
    """Casier de bois aux bocaux bouchés de cuivre (sortie)."""
    M = g.M
    corps.bac(g, c, p, M["bois_mouille"], M["verre_toxique"], forme="sphere")
    g.box(B(p["x"], p["yn"], p["z"] + 0.12), (0.03, 2 * p["r"] * SQ2 * 0.85, 0.02), M["bois_mousse"], "hard",
          what="croisillon")


def piece(g, c):
    """Niveau 16 (plus grande, hors de la cabane) : paniers d'osier pleins de bocaux sur une claie (coin avant gauche),
    tonneaux et cordage (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    g.box(B(po["x"], po["yn"], z + 0.03), (0.74, 0.62 * SQ2, 0.06), M["bois_mouille"], "hard", what="claie")
    for k, (dx, dy) in enumerate(((-0.17, 0.1), (0.18, 0.06), (0.0, -0.18))):
        x, y = po["x"] + dx, po["yn"] + dy
        g.cyl(B(x, y, z + 0.16), "z", 0.17, 0.2, M["wicker"], n=18, r2=0.19, what="panier")
        for j in range(3):
            a = TAU * j / 3 + k
            g.cyl(B(x + 0.07 * math.cos(a), y + 0.05 * math.sin(a), z + 0.33), "z", 0.055, 0.16, M["verre_toxique"],
                  n=12, what="bocal")
            g.cyl(B(x + 0.07 * math.cos(a), y + 0.05 * math.sin(a), z + 0.34), "z", 0.057, 0.08, M["emit_soft"], n=12,
                  what="contenu")
    halo(g, po["x"], po["yn"] - 0.1, z + 0.4, 0.6)
    for k, (dx, dy) in enumerate(((-0.16, 0.12), (0.16, 0.12), (0.0, 0.0))):
        F.stave_barrel(g, tuple(B(pe["x"] + dx, pe["yn"] + dy, z + (0.34 if k == 2 else 0.0))), 0.15, 0.32,
                       M["bois_mouille"], M["cuivre_terni"])
    g.torus(B(pe["x"], pe["yn"] - 0.22, z + 0.03), "z", 0.13, 0.03, M["wicker"], n=20, m=6, what="cordage")
    # contrôle d'îlots (ronde F3-A2) : le sol vu au cœur du cordage lové était un trou enfermé : fond de cordage
    g.cyl(B(pe["x"], pe["yn"] - 0.22, z + 0.02), "z", 0.12, 0.04, M["wicker"], n=16, what="coeur_cordage")
