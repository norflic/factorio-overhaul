"""Assembleur · Âge 6 · Électricité (ère II, 4×4, niveaux 11 et 12). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 6. Dans
Blender.

En 3 mots : « soudeuse, électrodes, tours de porcelaine ». Le dos est fait de deux TOURS DE PORCELAINE à bandes bleues
(transformateurs), coiffées de piles d'isolateurs et reliées par des barres de cuivre ; entre elles, un tableau de
commande (interrupteurs à couteau, cadrans, voyants bleus). L'outil est une SOUDEUSE : transformateur bleu sur le
chariot du portique, deux bras d'ÉLECTRODES de cuivre qui pincent l'ouvrage, ARCS bleus et gerbes d'étincelles. Joues en
colonnade de fonte bleue, sol de carreaux.
Palette 60/30/10 (ages.PALETTE[6]) : porcelaine blanche / bleu électrique (bleu machine, fonte bleue) / porcelaine des
isolateurs ; arcs bleus.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
import parts as PT
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 6
NOM = ages.NOMS[6]
TRIPLET = ("soudeuse", "électrodes", "tours de porcelaine")
FOYER = ages.FOYER[6]
TRAVAIL = dict(couches=2, images=12, organe="bras d'électrodes qui pincent (8 images) ; arcs et étincelles qui "
                                           "changent à chaque image (couche glow, 12 images, aléatoires)")
HABILLAGE = dict(ages.CORPS[6], forme_embase='carre', forme_dos='tours', forme_joues='colonnes',
                 forme_portique='poutre', mat_dos='porcelaine_capot', mat_portique='fonte_bleue')


def matieres(metal, M):
    ages.matieres(6, metal, M)
    M["accent"] = M["porcelaine"]


def _arc(g, p0, p1, n=5, amp=0.05, seed=0):
    """Arc électrique : ligne brisée lumineuse de p0 à p1."""
    import random
    rng = random.Random(seed)
    pts = []
    for i in range(n + 1):
        t = i / n
        p = p0.lerp(p1, t)
        if 0 < i < n:
            p = p + V(((rng.random() - 0.5) * amp, (rng.random() - 0.5) * amp, (rng.random() - 0.5) * amp))
        pts.append(p)
    g.tube(pts, 0.012, g.M["emit"], n=6, what="arc")


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    wt = 0.26 * c.side
    zm, zs, Ht = c.zm_tours, c.zs, c.z_tours
    ym = (yb + h) / 2.0
    # bandes bleues des tours, isolateurs au sommet, barres de cuivre entre les tours
    for sx in (-1, 1):
        xt = sx * (h - 0.02 - wt / 2)
        for z in (c.Hj + 0.06, (c.Hj + Ht) / 2, Ht - 0.1):
            g.box(B(xt, yb - 0.07, z), (wt - 0.08, 0.03, 0.07), M["bleu_machine"], "hard", what="bande")
        for k in range(3):
            F.post_insulator(g, tuple(B(xt - 0.25 + 0.25 * k, ym, Ht)), 4, 0.06, h=0.05, base=M["fonte_bleue"])
            corps.lampe(g, B(xt - 0.25 + 0.25 * k, ym, Ht + 0.36), 0.035, M["emit"])
        corps.lampe_face(g, xt, yb - 0.05, (c.Hj + Ht) / 2 + 0.06, 0.05, M["emit"], M["fonte_bleue"])
        halo(g, xt, yb - 0.15, (c.Hj + Ht) / 2, 0.6)
    # ronde 2 : des barres tendues d'une tour à l'autre AU-DESSUS du milieu bas enfermaient le ciel (1 140 px de trou) :
    # barres de cuivre posées sur le toit du milieu, sur isolateurs bas
    for k in range(3):
        y = ym - 0.2 + 0.2 * k
        g.box(B(0, y, zm + 0.1), (2 * (h - 0.02 - wt) - 0.1, 0.03 * SQ2, 0.03), M["copper_pol"], "hard",
              what="barre_cuivre")
        for x in (-0.5, 0.0, 0.5):
            PT.insulators(g, tuple(B(x, y, zm)), 1, 0.025, h=0.04)
    halo(g, 0, ym, Ht + 0.5, 1.2)
    # tableau de commande au milieu : plaque de bakélite, interrupteurs à couteau, cadrans
    g.box(B(0, yb - 0.04, (zs + zm) / 2), (2 * (h - wt) - 0.2, 0.04, zm - zs - 0.04), M["bakelite"], "hard",
          what="tableau")
    for k in range(4):
        x = -0.6 + 0.4 * k
        g.box(B(x, yb - 0.08, zm - 0.12), (0.14, 0.03, 0.1), M["porcelaine"], "hard", what="socle_couteau")
        for s in (-1, 1):
            g.box(B(x + s * 0.03, yb - 0.12, zm - 0.09), (0.015, 0.08, 0.015), M["copper_pol"], "hard",
                  R=Matrix.Rotation(0.6, 3, "X"), what="lame")
        corps.lampe_face(g, x, yb - 0.05, zs + 0.12, 0.035, M["emit"] if k % 2 else M["amber"], M["fonte_bleue"])
    # câbles des tours vers le chariot
    for sx in (-1, 1):
        g.cable(B(sx * 0.95, yb - 0.05, Ht - 0.15), B(sx * 0.12, c.yt, c.zp + c.bp + 0.08), 0.12, 0.025, M["bakelite"])


def outil(g, c):
    """Transformateur sur le chariot, bras d'électrodes, arcs et étincelles."""
    M = g.M
    yt, zt, zp, bp = c.yt, c.zt, c.zp, c.bp
    top = zp + bp
    g.box(B(0, yt, top + 0.17), (0.42, 0.28 * SQ2, 0.24), M["bleu_machine"], "hard", what="transfo")
    for k in range(5):
        g.box(B(-0.16 + 0.08 * k, yt - 0.2, top + 0.17), (0.02, 0.03, 0.2), M["fonte_bleue"], "hard", what="ailette")
    PT.insulators(g, tuple(B(-0.1, yt, top + 0.29)), 2, 0.035, h=0.03)
    PT.insulators(g, tuple(B(0.1, yt, top + 0.29)), 2, 0.035, h=0.03)
    pw = B(0, yt, zt + 0.16)
    for sx in (-1, 1):
        a0 = B(sx * 0.12, yt, zp - 0.02)
        a1 = B(sx * 0.32, yt, zt + 0.55)
        a2 = pw + V((sx * 0.07, 0, 0.08))
        g.tube([a0, a1, a2], 0.035, M["copper_pol"], n=10, what="bras_electrode")
        g.cyl(a1, "y", 0.05, 0.08, M["fonte_bleue"], n=12, what="articulation")
        g.cyl(a2 + V((0, 0, -0.02)), "z", 0.02, 0.06, M["porcelaine"], n=8, what="pointe")
        _arc(g, a2 + V((0, 0, -0.05)), pw + V((sx * 0.01, 0, 0.0)), seed=3 + sx)
    for k in range(10):
        a = 2 * math.pi * k / 10
        g.box(pw + V((0.13 * math.cos(a), 0.09 * math.sin(a), 0.02 + 0.04 * (k % 3))), (0.02, 0.02, 0.02), M["emit"],
              "flat", what="etincelle")
    halo(g, 0, yt, zt + 0.25, 1.6)


def ouvrage(g, c):
    """Cadre d'acier en croix soudé : cordon de soudure qui rougeoie."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.box(B(0, yt, zt + 0.05), (0.8, 0.1 * SQ2, 0.1), M["fonte_bleue"], "hard", what="profile")
    g.box(B(0, yt, zt + 0.05), (0.1, 0.6 * SQ2, 0.1), M["fonte_bleue"], "hard", what="profile")
    g.box(B(0, yt - 0.06, zt + 0.105), (0.14, 0.02, 0.012), M["emit_soft"], "flat", what="cordon")
    for sx in (-1, 1):
        g.box(B(sx * 0.33, yt, zt + 0.12), (0.08, 0.14 * SQ2, 0.06), M["copper_pol"], "hard", what="bride_serrage")


def piece(g, c):
    """Niveau 12 : touret de câble et armoire à fusibles (coin avant gauche), caisse d'isolateurs (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    x, yn = po["x"], po["yn"]
    for s in (-1, 1):
        g.cyl(B(x - 0.1 + s * 0.1, yn, z + 0.2), "x", 0.2, 0.03, M["wood"], n=20, style="hard", what="joue_touret")
    g.cyl(B(x - 0.1, yn, z + 0.2), "x", 0.15, 0.18, M["bakelite"], n=20, what="cable_enroule")
    g.box(B(x + 0.22, yn + 0.1, z + 0.22), (0.18, 0.14 * SQ2, 0.44), M["bleu_machine"], "hard", what="armoire")
    for k in range(3):
        g.cyl(B(x + 0.22, yn + 0.0, z + 0.12 + 0.11 * k), "y", 0.025, 0.04, M["porcelaine"], n=8, what="fusible")
    corps.lampe_face(g, x + 0.22, yn + 0.0, z + 0.4, 0.025, M["emit"], M["fonte_bleue"])
    corps.caisse(g, c, pe["x"], pe["yn"] + 0.05, z, 0.34, M["wood"])
    for k in range(4):
        PT.insulators(g, tuple(B(pe["x"] - 0.1 + 0.07 * k, pe["yn"] + 0.05, z + 0.35)), 2, 0.03, h=0.03)
    halo(g, x + 0.22, yn - 0.05, z + 0.4, 0.4)
