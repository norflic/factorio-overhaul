"""Four · Âge 6 · Électricité (ère II, 3×3, niveaux 11 et 12). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 6.
S'exécute DANS Blender.

En 3 mots : « trois électrodes, cuve de porcelaine, bras de cuivre ». La chambre est un FOUR À ARC : CUVE ronde de
PORCELAINE réfractaire blanche cerclée de bleu machine, couvercle de fonte bleue ; TROIS ÉLECTRODES de graphite en
triangle traversent le couvercle (anneaux d'arc bleus à l'entrée, éclairs entre elles) ; chacune est tenue par un BRAS
porte-électrode bleu à pince et barre de CUIVRE, qui sort d'une grande ARMOIRE de transformateur bleue à l'arrière (fond
plein : aucun jour entre bras et électrodes) ; isolateurs de porcelaine sur l'armoire ; à droite la gaine
d'aspiration des fumées (le « quatrième trou ») qui monte au-dessus de l'armoire (la fumée).
Palette 60/30/10 (ages.PALETTE[6]) : porcelaine blanche / bleu machine et fonte bleue / porcelaine des isolateurs ;
arcs bleu électrique.
"""
import math

import ages
import corps
import formes as F
import parts as PT
import parts2 as P2
from kit import TAU
from repere import Y

EPOQUE = 6
NOM = ages.NOMS[6]
TRIPLET = ("trois électrodes", "cuve de porcelaine", "bras de cuivre")
FOYER = ages.FOYER[6]
HABILLAGE = dict(ages.CORPS[6], foyer="fonte_bleue")
RC = 0.95
ELEC = ((-0.3, 0.12, 1.95), (0.3, 0.12, 1.95), (0.0, -0.22, 2.08))   # x, yn, hauteur du bras


def matieres(metal, M):
    ages.matieres(6, metal, M)


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    # armoire du transformateur (fond)
    corps.boite(g, -1.35, 1.35, 0.7, 1.4, zs, 2.0, [M["bleu_machine"], M["bleu_machine"], M["fonte_bleue"]],
                ins=(0.02, 0.02, 0.02), panel=0.34, faces="ts")
    yb = Y(0.7) - 0.035
    for x in (-1.05, 1.05):
        g.grille([corps.V((x - 0.2, yb, 0.35)), corps.V((x + 0.2, yb, 0.35)), corps.V((x + 0.2, yb, 0.85)),
                  corps.V((x - 0.2, yb, 0.85))], 6, slat_mat=M["fonte_bleue"])
    for x in (-1.15, -0.95):
        P2.gauge(g, (x, yb - 0.01, 1.2), (0, -1, 0), 0.07, M, face=M["porcelaine"])
    for x in (0.95, 1.12):
        PT.lamp(g, (x, yb, 1.25), (0, -1, 0), 0.035, M["emit"])
    # cuve de porcelaine
    zt = 1.0
    g.cyl((0, 0, (zs + zt) / 2), "z", RC, zt - zs, M["porcelaine_capot"], n=48, what="cuve")
    for z in (0.3, 0.82):
        g.tube_shell((0, 0, z), "z", RC + 0.025, RC - 0.02, 0.09, M["bleu_machine"], n=48, what="cerclage")
        for k in range(16):
            a = math.pi + math.pi * (k + 0.5) / 16
            g.dome(((RC + 0.025) * math.cos(a), (RC + 0.025) * math.sin(a), z), (math.cos(a), math.sin(a), 0), 0.014,
                   M["copper_pol"])
    for k in range(8):
        a = math.pi + math.pi * (k + 0.5) / 8
        g.box((RC * math.cos(a), RC * math.sin(a), 0.56), (0.03, 0.03, 0.4), M["porcelaine"], "hard",
              what="couvre_joint")
    g.tube_shell((0, 0, zs + 0.05), "z", RC + 0.06, RC - 0.05, 0.1, M["fonte_bleue"], n=48, what="embase")
    # couvercle de fonte bleue et voûte centrale de porcelaine
    # ronde 1 : couvercle de PORCELAINE (en fonte bleue, vu de dessus, il faisait la cuve bleue : contre la palette),
    # jonc et rayons bleus
    g.cyl((0, 0, zt + 0.12), "z", RC + 0.03, 0.24, M["porcelaine_capot"], n=48, r2=0.62, style="soft", what="couvercle")
    g.torus((0, 0, zt + 0.01), "z", RC + 0.03, 0.04, M["bleu_machine"], n=48, m=6, what="jonc")
    for k in range(12):
        a = TAU * k / 12
        g.box((0.8 * math.cos(a), 0.8 * math.sin(a), zt + 0.13), (0.34, 0.05, 0.03), M["bleu_machine"], "hard",
              R=corps.Matrix.Rotation(a, 3, "Z") @ corps.Matrix.Rotation(0.6, 3, "Y"), what="rayon")
    g.cyl((0, 0, zt + 0.28), "z", 0.62, 0.08, M["fonte_bleue"], n=40, r2=0.5, what="voute")
    # bec de coulée (ouest)
    g.box((-RC - 0.12, 0, 0.88), (0.3, 0.2, 0.08), M["porcelaine_capot"], "hard", what="bec")
    g.box((-RC - 0.12, 0, 0.93), (0.26, 0.1, 0.02), M["emit"], "flat", what="coulee")
    electrodes(g, c)


def electrodes(g, c):
    M = g.M
    yarm = Y(0.7)
    for i, (x, yn, za) in enumerate(ELEC):
        y = Y(yn)
        z0, z1 = 1.25, za + 0.32
        g.cyl((x, y, (z0 + z1) / 2), "z", 0.13, z1 - z0, M["castiron"], n=16, what="electrode")
        for z in (z0 + 0.3, z0 + 0.65):
            g.tube_shell((x, y, z), "z", 0.135, 0.12, 0.025, M["steel_hi"], n=16, what="raccord")
        g.cyl((x, y, z1 + 0.04), "z", 0.13, 0.08, M["castiron"], n=16, r2=0.08, what="bout")
        g.torus((x, y, 1.34), "z", 0.13, 0.03, M["emit"], n=16, m=6, what="arc")
        g.tube_shell((x, y, 1.3), "z", 0.16, 0.1, 0.05, M["porcelaine"], n=16, what="joint_isolant")
        # bras porte-électrode : poutre bleue, barre de cuivre, pince
        L = yarm - y
        g.box((x, (y + yarm) / 2 + 0.06, za), (0.13, L + 0.12, 0.14), M["bleu_machine"], "hard", what="bras")
        g.box((x, (y + yarm) / 2 + 0.06, za + 0.09), (0.11, L + 0.1, 0.04), M["copper_pol"], "hard", what="barre")
        g.tube_shell((x, y, za), "z", 0.2, 0.125, 0.2, M["copper_pol"], n=16, what="pince")
        for sx in (-1, 1):
            g.bolt((x + sx * 0.12, y - 0.12, za + 0.09), (0, 0, 1), 0.016, M["steel_hi"])
    # éclairs entre les électrodes, au ras du couvercle
    for (a, b) in ((0, 2), (1, 2), (0, 1)):
        xa, ya = ELEC[a][0], Y(ELEC[a][1])
        xb, yb = ELEC[b][0], Y(ELEC[b][1])
        pts = []
        for k in range(6):
            t = k / 5
            j = 0.0 if k in (0, 5) else 0.05 * (1 if k % 2 else -1)
            pts.append(corps.V((xa + (xb - xa) * t + j, ya + (yb - ya) * t, 1.38 + 0.05 * math.sin(t * math.pi))))
        g.tube(pts, 0.012, M["emit"], n=5, style="flat", what="eclair")
    g.halo((0, -0.4, 1.5), M["_emit_rgb"], 7.0)


def gueule(g, c, G):
    M = g.M
    for sx in (-1, 1):
        F.post_insulator(g, (sx * (G["x1"] + 0.12), G["yf"] + 0.08, c.T["sole_h"]), 4, 0.06, h=0.05,
                         base=M["fonte_bleue"])


def fumee(g, c):
    M = g.M
    x, yn = 0.86, 0.52
    y = Y(yn)
    zs = c.T["sole_h"]
    z1 = 2.55
    g.box((x, y, (zs + z1) / 2), (0.3, 0.3, z1 - zs), M["fonte_bleue"], "hard", what="gaine")
    for z in (0.6, 1.3, 2.0):
        g.box((x, y, z), (0.36, 0.36, 0.06), M["bleu_machine"], "hard", what="bride")
    g.box(((x + 0.35) / 2, Y(0.3), 1.2), (x - 0.35 + 0.1, 0.24, 0.24), M["fonte_bleue"], "hard", what="coude")
    g.box((x, y, z1 + 0.03), (0.38, 0.38, 0.06), M["porcelaine_capot"], "hard", what="chapeau")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.07, 0.13)
    # isolateurs de porcelaine sur l'armoire, barre de cuivre couchée
    for xi in (-1.05, -0.45, 0.25):
        F.post_insulator(g, (xi, Y(1.0), 2.0), 5, 0.07, h=0.055, base=M["fonte_bleue"])
    g.box((-0.4, Y(1.0), 2.03), (1.4, 0.06, 0.03), M["copper_pol"], "hard", what="barre_cuivre")


def piece(g, c):
    """Électrodes de rechange couchées sur berceaux bleus."""
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        x, y = p["x"], Y(p["yn"])
        w = 2 * p["rw"] * 0.8
        for dx in (-w * 0.35, w * 0.35):
            g.box((x + dx, y, zs + 0.06), (0.07, 0.42, 0.12), M["bleu_machine"], "hard", what="berceau")
        for (dy, dz) in ((-0.1, 0.17), (0.1, 0.17), (0.0, 0.33)):
            g.cyl((x, y + dy, zs + dz), "x", 0.085, w, M["castiron"], n=14, what="electrode")
            g.cyl((x + w / 2 + 0.01, y + dy, zs + dz), "x", 0.05, 0.03, M["copper_pol"], n=10, what="filetage")
