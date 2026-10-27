"""Assembleur · Âge 6 · Électricité (ère II, 4×4, niveaux 11 et 12). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md,
âge 6. Dans Blender.

En 3 mots : « soudeuse, électrodes, tours de porcelaine ». Plan en TOUR : la machine est un grand TRANSFORMATEUR de
porcelaine à bandes bleues, couronné de piles d'isolateurs et d'un tore de cuivre ; deux petites TOURS DE PORCELAINE
l'épaulent au nord-ouest et au nord-est, reliées à lui par des barres de cuivre sur isolateurs. De sa galerie sortent
les deux bras d'ÉLECTRODES de la SOUDEUSE, articulés sur des isolateurs, qui pincent le cadre d'acier posé au pied sud :
arcs bleus, gerbes d'étincelles. Tableau à interrupteurs à couteau sur le socle.
Palette 60/30/10 (ages.PALETTE[6]) : porcelaine blanche / bleu électrique / porcelaine des isolateurs ; arcs bleus.
"""
import math
import random

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
import parts as PT
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 6
NOM = ages.NOMS[6]
TRIPLET = ("soudeuse", "électrodes", "tours de porcelaine")
FOYER = ages.FOYER[6]
TRAVAIL = dict(couches=2, images=12, organe="bras d'électrodes qui pincent (8 images) ; arcs et étincelles qui "
                                           "changent à chaque image (couche glow, 12 images, aléatoires)")
HABILLAGE = dict(ages.CORPS[6], plan='tour', forme_embase='carre', forme_dos='plat', forme_joues='caisson',
                 forme_portique='aucun')
DENSITE = dict(p=0.6, lampes=0.14)


def matieres(metal, M):
    ages.matieres(6, metal, M)
    M["accent"] = M["porcelaine"]


def _arc(g, p0, p1, n=5, amp=0.05, seed=0):
    rng = random.Random(seed)
    pts = []
    for i in range(n + 1):
        p = p0.lerp(p1, i / n)
        if 0 < i < n:
            p = p + V(((rng.random() - 0.5) * amp, (rng.random() - 0.5) * amp, (rng.random() - 0.5) * amp))
        pts.append(p)
    g.tube(pts, 0.012, g.M["emit"], n=6, what="arc")


def _petite_tour(g, x, yn, z, r, hgt):
    M = g.M
    p = B(x, yn, z)
    g.cyl(p + V((0, 0, hgt / 2)), "z", r, hgt, M["porcelaine_capot"], n=24, what="petite_tour")
    for f in (0.2, 0.5, 0.8):
        g.tube_shell(p + V((0, 0, hgt * f)), "z", r + 0.015, r - 0.01, 0.06, M["bleu_machine"], n=24, what="bande")
    g.cyl(p + V((0, 0, hgt + 0.02)), "z", r * 1.1, 0.04, M["fonte_bleue"], n=24, what="chapeau")
    zt = PT.insulators(g, tuple(p + V((0, 0, hgt + 0.04))), 4, 0.05, h=0.045)
    g.sphere(p + V((0, 0, hgt + 0.3)), 0.05, M["emit"], n=12, m=6, what="boule")
    halo(g, x, yn, z + hgt + 0.3, 0.6)
    return p + V((0, 0, hgt + 0.25))


def socle(g, c):
    """Bandes bleues et voyants du fût, couronne d'isolateurs et tore, petites tours, barres de cuivre, tableau."""
    M = g.M
    Rt, zr, Ht = c.Rt, c.zr, c.Ht
    for f in (0.1, 0.32, 0.75, 0.93):
        g.tube_shell(V((0, 0, zr + f * (Ht - zr))), "z", Rt + 0.02, Rt - 0.01, 0.07, M["bleu_machine"], n=36,
                     what="bande")
    for k in range(5):
        a = math.radians(200 + 35 * k)
        corps.lampe(g, V(((Rt + 0.02) * math.cos(a), (Rt + 0.02) * math.sin(a), zr + 0.2 * (Ht - zr))), 0.03,
                    M["emit"])
    halo(g, 0, -Rt / SQ2 - 0.1, zr + 0.25 * (Ht - zr), 0.8)
    # couronne d'isolateurs et tore de cuivre au sommet
    for k in range(8):
        a = TAU * k / 8
        PT.insulators(g, (Rt * 0.7 * math.cos(a), Rt * 0.7 * math.sin(a), Ht + 0.06), 3, 0.045, h=0.04)
    g.torus(V((0, 0, Ht + 0.3)), "z", Rt * 0.75, 0.05, M["copper_pol"], n=36, m=8, what="tore_cuivre")
    g.sphere(V((0, 0, Ht + 0.35)), 0.09, M["emit"], n=14, m=7, what="boule_tete")
    halo(g, 0, 0, Ht + 0.4, 1.2)
    # deux petites tours de porcelaine, reliées au fût par des barres de cuivre
    for sx in (-1, 1):
        # sur les annexes des coins arrière (plan tour)
        x, y = sx * (c.h - c.ann / 2.0), c.h - c.ann / 2.0
        tete = _petite_tour(g, x, y, c.Hann, 0.2, 0.75)
        c.reserves.append((x, y, 0.3))
        p1 = V((sx * Rt * 0.9, Rt * 0.4, c.zg + 0.15))
        g.tube([tete, tete.lerp(p1, 0.5) + V((0, 0, 0.05)), p1], 0.02, M["copper_pol"], n=6, what="barre_cuivre")
        PT.insulators(g, tuple(tete.lerp(p1, 0.5) - V((0, 0, 0.02))), 1, 0.03, h=0.03)
    # tableau à interrupteurs à couteau sur le socle (sud-ouest)
    xt, yt = -0.85, -0.55
    g.box(B(xt, yt, zr + 0.2), (0.5, 0.06 * SQ2, 0.4), M["bakelite"], "hard", what="tableau")
    for k in range(3):
        x = xt - 0.15 + 0.15 * k
        g.box(B(x, yt - 0.05, zr + 0.3), (0.1, 0.03, 0.08), M["porcelaine"], "hard", what="socle_couteau")
        for s in (-1, 1):
            g.box(B(x + s * 0.025, yt - 0.08, zr + 0.33), (0.012, 0.07, 0.012), M["copper_pol"], "hard",
                  R=Matrix.Rotation(0.6, 3, "X"), what="lame")
        corps.lampe_face(g, x, yt - 0.03, zr + 0.12, 0.03, M["emit"] if k % 2 else M["amber"], M["fonte_bleue"])
    c.reserves.append((xt, yt, 0.3))


def outil(g, c):
    """Deux bras d'électrodes sortis de la galerie, articulés sur isolateurs, arcs et étincelles sur l'ouvrage."""
    M = g.M
    Rt, zg = c.Rt, c.zg
    pw = B(0, c.yt, c.zt + 0.16)
    for sx in (-1, 1):
        a0 = V((sx * Rt * 0.55, -Rt * 0.8, zg + 0.05))
        a1 = B(sx * 0.42, (c.yt - Rt / SQ2) / 2, zg - 0.05)
        a2 = pw + V((sx * 0.08, 0, 0.1))
        g.cyl(a0, "z", 0.07, 0.1, M["fonte_bleue"], n=14, what="pivot")
        g.tube([a0, a1, a2], 0.04, M["copper_pol"], n=10, what="bras_electrode")
        PT.insulators(g, tuple(a1 - V((0, 0, 0.04))), 2, 0.04, h=0.035)
        g.cyl(a2 + V((0, 0, -0.03)), "z", 0.022, 0.07, M["porcelaine"], n=8, what="pointe")
        _arc(g, a2 + V((0, 0, -0.06)), pw + V((sx * 0.01, 0, 0.0)), seed=3 + sx)
        g.cable(a0 + V((0, 0, 0.05)), a1 + V((0, 0, 0.05)), 0.05, 0.015, M["bakelite"])
    for k in range(12):
        a = TAU * k / 12
        g.box(pw + V((0.15 * math.cos(a), 0.1 * math.sin(a), 0.02 + 0.04 * (k % 3))), (0.02, 0.02, 0.02), M["emit"],
              "flat", what="etincelle")
    halo(g, 0, c.yt, c.zt + 0.25, 1.6)


def ouvrage(g, c):
    """Établi de fonte bleue et cadre d'acier en croix ; cordon de soudure qui rougeoie."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.box(B(0, yt, (c.zr + zt) / 2), (0.8, 0.45 * SQ2, zt - c.zr), M["fonte_bleue"], "hard", what="etabli")
    g.box(B(0, yt, zt + 0.05), (0.7, 0.09 * SQ2, 0.1), M["steel_dk"], "hard", what="profile")
    g.box(B(0, yt, zt + 0.05), (0.09, 0.4 * SQ2, 0.1), M["steel_dk"], "hard", what="profile")
    g.box(B(0, yt - 0.05, zt + 0.105), (0.14, 0.02, 0.012), M["emit_soft"], "flat", what="cordon")
    for sx in (-1, 1):
        g.box(B(sx * 0.3, yt, zt + 0.12), (0.08, 0.14 * SQ2, 0.06), M["copper_pol"], "hard", what="bride_serrage")


def entree(g, c, p):
    """Râtelier de barres d'acier sur tréteaux de fonte bleue (entrée)."""
    M = g.M
    r, z = p["r"], p["z"]
    for s in (-1, 1):
        g.box(B(p["x"], p["yn"] + s * r * 0.6, z + 0.1), (2 * r, 0.04 * SQ2, 0.2), M["fonte_bleue"], "hard",
              what="treteau")
    for k in range(5):
        g.cyl(B(p["x"] - r * 0.6 + r * 0.3 * k, p["yn"], z + 0.22), "y", 0.025, 2 * r * SQ2 * 0.9, M["steel"], n=8,
              what="barre")


def sortie(g, c, p):
    """Bac de fonte bleue : cadres soudés empilés (sortie)."""
    corps.bac(g, c, p, g.M["fonte_bleue"], g.M["steel_dk"], forme="plaque")


def piece(g, c):
    """Niveau 12 (plus grande) : grand touret de câble et armoire à fusibles (coin avant gauche), caisse d'isolateurs et
    petit transformateur (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    x, yn = po["x"], po["yn"]
    for s in (-1, 1):
        g.cyl(B(x - 0.1 + s * 0.12, yn, z + 0.26), "x", 0.26, 0.035, M["wood"], n=20, style="hard", what="joue_touret")
    g.cyl(B(x - 0.1, yn, z + 0.26), "x", 0.2, 0.22, M["bakelite"], n=20, what="cable_enroule")
    g.box(B(x + 0.24, yn + 0.12, z + 0.28), (0.2, 0.16 * SQ2, 0.56), M["bleu_machine"], "hard", what="armoire")
    for k in range(3):
        g.cyl(B(x + 0.24, yn + 0.0, z + 0.14 + 0.13 * k), "y", 0.025, 0.04, M["porcelaine"], n=8, what="fusible")
    corps.lampe_face(g, x + 0.24, yn + 0.0, z + 0.52, 0.03, M["emit"], M["fonte_bleue"])
    halo(g, x + 0.24, yn - 0.05, z + 0.5, 0.5)
    corps.caisse(g, c, pe["x"] - 0.12, pe["yn"] + 0.05, z, 0.34, M["wood"])
    for k in range(4):
        PT.insulators(g, tuple(B(pe["x"] - 0.22 + 0.07 * k, pe["yn"] + 0.05, z + 0.35)), 2, 0.03, h=0.03)
    _petite_tour(g, pe["x"] + 0.22, pe["yn"] + 0.1, z, 0.12, 0.45)
