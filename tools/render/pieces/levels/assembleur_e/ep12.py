"""Assembleur · Âge 12 · Supraconducteurs (ère IV, 6×6, niveaux 23 et 24). Lot F3-A, ronde F3-A2 ; fiche
FICHES_ASSEMBLEUR.md, âge 12. Dans Blender.

En 3 mots : « lévitation, rails magnétiques, conduites givrées ». Plan ROND : tambour de blanc glacé, croissant nord
couronné de vases de Dewar. Autour du lit, un RAIL MAGNÉTIQUE circulaire chromé (filet cyan dessous) porté par six
pylônes givrés ; trois pièces y glissent en LÉVITATION. Au centre, l'ouvrage (anneau chromé et cœur noir) flotte au-dessus
d'un patin cyan. Des CONDUITES GIVRÉES à colliers chromés descendent du croissant aux pylônes.
Palette 60/30/10 (ages.PALETTE[12]) : blanc glacé teinté cyan / noir miroir et chrome / cyan lumineux.
"""
import math

from mathutils import Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 12
NOM = ages.NOMS[12]
TRIPLET = ("lévitation", "rails magnétiques", "conduites givrées")
FOYER = ages.FOYER[12]
TRAVAIL = dict(couches=2, images=32, organe="pièces qui glissent sur le rail et oscillent (32 images, boucle) ; filets "
                                           "cyan qui pulsent (couche glow)")
HABILLAGE = dict(ages.CORPS[12], capots=("frost", "chrome_mat"), plan='rond', forme_embase='carre', forme_dos='plat',
                 forme_joues='caisson', forme_portique='aucun')
DENSITE = dict(p=0.55, lampes=0.1)
RAYONS = False          # le rail circulaire et ses pylônes remplacent les rayons du croissant
RR = 1.25               # rayon du rail (Blender)


def matieres(metal, M):
    ages.matieres(12, metal, M)


def socle(g, c):
    """Vases de Dewar sur le croissant, conduites givrées, filets cyan, grilles chromées."""
    M = g.M
    Rd = c.Rb - 0.06
    R0 = Rd - c.ep_cr
    Rm = (R0 + Rd) / 2.0
    for k, ad in enumerate((35, 65, 115, 145)):
        a = math.radians(ad)
        x, y = Rm * math.cos(a), Rm * math.sin(a)
        g.cyl(B(x, y, c.Hc + 0.25), "z", 0.17, 0.5, M["chrome_mat"], n=20, what="dewar")
        g.sphere(B(x, y, c.Hc + 0.5), 0.17, M["chrome_mat"], n=20, m=8, scale=(1, 1, 0.5), what="dome_dewar")
        g.tube_shell(B(x, y, c.Hc + 0.32), "z", 0.18, 0.16, 0.04, M["emit_soft"], n=20, what="bague_cyan")
        c.reserves.append((x, y, 0.28))
    halo(g, 0, Rm, c.Hc + 0.5, 1.0)
    # filets cyan au bord du croissant et de l'anneau avant
    for k in range(10):
        a0, a1 = math.radians(16 + 14.8 * k), math.radians(16 + 14.8 * (k + 1))
        g.tube([B(R0 * math.cos(a0), R0 * math.sin(a0) - 0.02, c.Hc - 0.04),
                B(R0 * math.cos(a1), R0 * math.sin(a1) - 0.02, c.Hc - 0.04)], 0.012, M["emit"], n=5, what="filet")
    # conduites givrées du croissant vers les pylônes du rail, colliers chromés, amas de givre
    for k, ad in enumerate((60, 120)):
        a = math.radians(ad)
        p0 = B((R0 + 0.1) * math.cos(a), (R0 + 0.1) * math.sin(a), c.Hc - 0.1)
        b = math.radians(ad + (25 if k else -25))
        p1 = V((RR * math.cos(b), B(0, c.cy).y + RR * math.sin(b), c.zt + 0.3))
        g.tube([p0, p0.lerp(p1, 0.5) + V((0, 0, 0.15)), p1], 0.07, M["frost"], n=12, what="conduite_givree")
        for f in (0.2, 0.45, 0.7):
            q = p0.lerp(p1, f) + V((0, 0, 0.1 * math.sin(math.pi * f)))
            g.tube_shell(q, (p1 - p0).normalized(), 0.085, 0.065, 0.04, M["chrome_mat"], n=14, what="collier")
        F.lump(g, p1 - V((0, 0, p1.z - c.zr)), 0.1, M["frost"])
    g.grille([B(-0.9, R0 - 0.03, c.zr + 0.15), B(0.9, R0 - 0.03, c.zr + 0.15), B(0.9, R0 - 0.03, c.zr + 0.45),
              B(-0.9, R0 - 0.03, c.zr + 0.45)], 8, slat_mat=M["grille_chrome"])


def outil(g, c):
    """Rail magnétique circulaire sur six pylônes givrés, trois pièces en lévitation."""
    M = g.M
    zr_ = c.zt + 0.55
    ctr = B(0, c.cy, zr_)
    c.reserves.append((0.0, c.cy, RR * 0.78 + 0.2))
    g.torus(ctr, "z", RR, 0.07, M["chrome_mat"], n=64, m=10, what="rail")
    g.torus(ctr - V((0, 0, 0.09)), "z", RR, 0.025, M["emit"], n=64, m=6, what="filet_rail")
    for k in range(6):
        a = TAU * k / 6 + math.pi / 6
        p = ctr + V((RR * math.cos(a), RR * math.sin(a), 0))
        g.box(V((p.x, p.y, (c.zr + zr_) / 2)), (0.12, 0.12, zr_ - c.zr), M["frost"], "soft", what="pylone")
        g.tube_shell(V((p.x, p.y, zr_ - 0.15)), "z", 0.1, 0.07, 0.05, M["chrome_mat"], n=14, what="bague")
    halo(g, 0, c.cy, zr_ - 0.1, 1.6)
    for k, (ad, dz, r, m) in enumerate(((250, 0.16, 0.1, "chrome_mat"), (310, 0.2, 0.08, "noir_miroir"),
                                        (20, 0.18, 0.11, "chrome_mat"))):
        a = math.radians(ad)
        p = ctr + V((RR * math.cos(a), RR * math.sin(a), dz + r))
        g.box(p, (r * 2, r * 2, r * 1.4), M[m], "soft", what="piece_flottante")
        g.cyl(p - V((0, 0, r * 0.7 + 0.05)), "z", r * 0.9, 0.012, M["emit"], n=16, style="flat", what="jour_cyan")


def ouvrage(g, c):
    """Anneau chromé et cœur en lévitation au-dessus d'un patin cyan."""
    M = g.M
    zt = c.zt
    g.cyl(B(0, c.cy, zt + 0.03), "z", 0.4, 0.06, M["noir_miroir"], n=32, what="patin")
    F.lit_ring(g, B(0, c.cy, zt + 0.065), "z", 0.36, M["emit"], w=0.035, t=0.012)
    zf = zt + 0.42
    g.torus(B(0, c.cy, zf), "y", 0.24, 0.055, M["chrome_mat"], n=32, m=10, what="anneau")
    g.sphere(B(0, c.cy, zf), 0.11, M["noir_miroir"], n=20, m=10, what="coeur")
    g.torus(B(0, c.cy, zf), "z", 0.13, 0.012, M["emit"], n=24, m=5, what="equateur")
    halo(g, 0, c.cy, zt + 0.2, 1.0)


def entree(g, c, p):
    """Bobine de fil supraconducteur sur dévidoir givré (entrée)."""
    M = g.M
    g.cyl(B(p["x"], p["yn"], p["z"] + 0.05), "z", p["r"], 0.1, M["frost"], n=20, what="devidoir")
    g.cyl(B(p["x"], p["yn"], p["z"] + 0.18), "z", p["r"] * 0.75, 0.16, M["chrome_mat"], n=20, what="bobine")
    for k in range(4):
        g.torus(B(p["x"], p["yn"], p["z"] + 0.12 + 0.035 * k), "z", p["r"] * 0.76, 0.01, M["noir_miroir"], n=20, m=4,
                what="spire")


def sortie(g, c, p):
    """Plateau de noir miroir : aimants supraconducteurs finis à bague cyan (sortie)."""
    M = g.M
    corps.bac(g, c, p, M["noir_miroir"], M["chrome_mat"], forme="sphere")
    g.torus(B(p["x"], p["yn"], p["z"] + 0.18), "z", p["r"] * 0.7, 0.012, M["emit"], n=20, m=4, what="bague_cyan")


def piece(g, c):
    """Niveau 24 (plus grande, hors du tambour) : grande bobine supraconductrice dressée sur traîneau givré (coins
    avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"], p["z_sol"]
        for s in (-1, 1):
            g.box(B(x + s * 0.3, yn, z + 0.03), (0.06, 0.8 * SQ2, 0.06), M["chrome_mat"], "hard", what="patin")
        g.box(B(x, yn, z + 0.09), (0.7, 0.7 * SQ2, 0.06), M["frost"], "soft", what="traineau")
        g.torus(B(x, yn, z + 0.48), "y", 0.32, 0.09, M["chrome_mat"], n=36, m=10, what="bobine")
        g.cyl(B(x, yn + 0.02, z + 0.48), "y", 0.3, 0.04, M["noir_miroir"], n=36, what="flasque")   # pas de jour enfermé
        g.torus(B(x, yn - 0.05, z + 0.48), "y", 0.32, 0.03, M["emit"], n=36, m=6, what="bague_cyan")
        g.box(B(x, yn, z + 0.15), (0.2, 0.2 * SQ2, 0.1), M["frost"], "soft", what="pied_bobine")
        F.lump(g, B(x - 0.25, yn - 0.25, z + 0.12), 0.08, M["frost"])
        halo(g, x, yn, z + 0.5, 0.7)
