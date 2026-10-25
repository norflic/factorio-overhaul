"""Foreuse · Âge 6 · Électricité (ère II, 4×4, niveaux 11 et 12). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « pylône, électrodes, moteur bleu ». Un PYLÔNE de fonte bleue (treillis carré effilé) porte au sommet 4 bras
garnis de chaînes d'isolateurs de porcelaine ; quatre ÉLECTRODES de cuivre plongent dans le sol autour du puits, reliées
au pylône par des câbles, avec un arc bleu au pied de chacune ; à l'arrière, un gros MOTEUR BLEU à flasques de porcelaine
et bobinage de cuivre apparent. Palette (ages.PALETTE[6]) : porcelaine blanche / bleu électrique et bleu nuit / cuivre des
bobines ; lumière arcs bleus.
"""
import math

import ages
import corps as cp

EPOQUE = 6
NOM = ages.NOMS[6]
TRIPLET = ("pylône", "électrodes", "moteur bleu")
FOYER = ages.FOYER[6]
HABILLAGE = dict(ages.CORPS[6])


def matieres(metal, M):
    ages.matieres(6, metal, M)


def _isolateur(g, x, y, z, n, M):
    for i in range(n):
        g.cyl((x, y, z - 0.055 * i), "z", 0.045, 0.02, M["porcelaine"], n=12, what="assiette")
    cp.colonne(g, x, y, z - 0.055 * n, z + 0.02, 0.012, M["copper_pol"], n=6, what="tige_iso")


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    hb = min(H - 0.35, c.T["z_treillis_max"])
    rb, rh = rt * 0.92, rt * 0.24     # ronde 1 : pylône élargi (0,7 → 0,92), il se perdait sur le carrelage blanc
    w = 0.085
    # transformateur bleu au pied du pylône, traversées de porcelaine
    cp.dalle(g, -rt * 0.5, -rt * 0.5, rt * 0.5, rt * 0.5, zt, zt + 0.42, M["bleu_machine"], what="transfo")
    for i in range(6):
        g.box((0, -rt * 0.5 - 0.012, zt + 0.06 + 0.06 * i), (rt * 0.9, 0.025, 0.025), M["fonte_bleue"], "hard",
              what="ailette")
    for (x, y) in ((-rt * 0.25, -rt * 0.25), (rt * 0.25, -rt * 0.25)):
        for i in range(4):
            g.cyl((x, y, zt + 0.47 + 0.06 * i), "z", 0.07, 0.03, M["porcelaine"], n=12, what="traversee")
    for k in range(4):
        cp.poutre(g, cp.quart((rb, rb, zt), k), cp.quart((rh, rh, hb), k), w, M["fonte_bleue"], "jambe")
    n = 6
    for i in range(n):
        z0 = zt + (hb - zt) * i / n
        z1 = zt + (hb - zt) * (i + 1) / n
        r0 = rb + (rh - rb) * i / n
        r1 = rb + (rh - rb) * (i + 1) / n
        for k in range(4):
            cp.poutre(g, cp.quart((r0, r0, z0), k), cp.quart((r1, -r1, z1), k), w * 0.55, M["fonte_bleue"], "zigzag")
            cp.poutre(g, cp.quart((r1, r1, z1), k), cp.quart((r1, -r1, z1), k), w * 0.6, M["bleu_machine"], "ceinture")
    # tête pleine : caisson bleu, 4 bras porcelaine, isolateurs pendus
    cp.dalle(g, -rh - 0.1, -rh - 0.1, rh + 0.1, rh + 0.1, hb, hb + 0.16, M["bleu_machine"], what="tete")
    for k in range(4):
        p1 = cp.quart((rt * 1.1, 0.0, hb + 0.08), k)
        cp.poutre(g, cp.quart((rh, 0.0, hb + 0.08), k), p1, 0.09, M["fonte_bleue"], "bras", h=0.12)
        _isolateur(g, p1[0] * 0.92, p1[1] * 0.92, hb + 0.02, 5, M)
    cp.colonne(g, 0, 0, hb + 0.16, H, 0.09, M["porcelaine_capot"], n=12, what="sommet")
    for i in range(3):
        g.cyl((0, 0, hb + 0.24 + i * (H - hb - 0.3) / 3), "z", 0.13, 0.03, M["porcelaine"], n=14, what="jupe")


def trepan(g, c):
    """Électrodes de cuivre autour du puits, câbles vers le pylône, arc bleu au pied."""
    M = g.M
    zt, rw, rt = c.zt, c.rw, c.rt
    hb = min(c.H - 0.35, c.T["z_treillis_max"])
    for k in range(4):
        x, y = cp.quart((rt * 0.64, rt * 0.64), k)[:2]     # hors du transformateur (ronde 1)
        cp.colonne(g, x, y, zt - 0.02, zt + 0.62, 0.05, M["copper_pol"], n=10, what="electrode")
        for i in range(3):
            g.cyl((x, y, zt + 0.48 + 0.04 * i), "z", 0.075, 0.018, M["porcelaine"], n=12, what="iso")
        g.cable((x, y, zt + 0.62), (x * 0.3, y * 0.3, hb * 0.7), 0.04, 0.016, M["bakelite"])
        g.cyl((x * 1.12, y * 1.12, zt + 0.05), "z", 0.06, 0.1, M["emit"], n=8, r2=0.01, style="flat", what="arc")
        g.cable((x, y, zt + 0.3), (x * 1.12, y * 1.12, zt + 0.08), 0.0, 0.012, M["emit"])
    cp.halo(g, (0, -rt * 0.8, zt + 0.25), M, 5.0)


def moteur(g, c):
    """Gros moteur bleu : carcasse nervurée, flasques de porcelaine, bobinage de cuivre apparent, boîte à bornes."""
    M = g.M
    T = c.T["moteur"]
    mx, my, w, p = 0.42 * c.a, T["y"], T["w"] * 1.15, T["p"] * 1.25
    zt = c.zt
    rr = p * 0.5
    zc = zt + 0.08 + rr
    g.box((mx, my, zt + 0.04), (w, p * 0.9, 0.08), M["fonte_bleue"], "hard", what="berceau")
    g.cyl((mx, my, zc), "x", rr, w * 0.72, M["bleu_machine"], n=24, what="carcasse")
    for i in range(9):
        g.tube_shell((mx - w * 0.32 + w * 0.64 * i / 8.0, my, zc), "x", rr * 1.08, rr * 0.95, 0.02, M["fonte_bleue"],
                     n=24, what="nervure")
    for s in (-1, 1):
        g.cyl((mx + s * w * 0.40, my, zc), "x", rr * 0.92, 0.07, M["porcelaine_capot"], n=24, what="flasque")
    g.torus((mx - w * 0.46, my, zc), "x", rr * 0.55, 0.035, M["copper_pol"], n=20, m=6, what="bobinage")
    g.box((mx, my, zc + rr + 0.08), (w * 0.3, p * 0.4, 0.14), M["porcelaine_capot"], "hard", what="bornes")
    for s in (-1, 1):
        g.cyl((mx + s * 0.06, my, zc + rr + 0.2), "z", 0.025, 0.1, M["copper_pol"], n=8, what="borne")
    g.cable((mx, my + p * 0.25, zc + rr + 0.15), (c.rt * 0.5, -c.rt * 0.5, zt + 0.6), 0.05, 0.022, M["bakelite"])


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r, M["fonte_bleue"], fl_mat=M["copper_pol"], bolt_mat=M["copper_pol"], what="raccord")


def piece(g, c):
    """Boule de décharge sur une colonne d'isolateurs, halo bleu."""
    M = g.M
    z = c.H
    for i in range(4):
        g.cyl((0, 0, z + 0.04 + 0.06 * i), "z", 0.09, 0.025, M["porcelaine"], n=16, what="assiette")
    cp.colonne(g, 0, 0, z, z + 0.3, 0.025, M["copper_pol"], n=8, what="tige")
    g.sphere((0, 0, z + 0.38), 0.11, M["copper_pol"], n=20, m=10, what="boule")
    g.torus((0, 0, z + 0.38), "z", 0.13, 0.012, M["emit"], n=24, m=6, what="arc")
    cp.halo(g, (0, -0.2, z + 0.38), M, 4.0)
