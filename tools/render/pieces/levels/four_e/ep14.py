"""Four · Âge 14 · La Porte (ère V, 6×6, niveaux 27 et 28). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 14.
S'exécute DANS Blender.

En 3 mots : « anneau dressé, ciel étoilé, gradins indigo ». La chambre est une FORGE STELLAIRE : trois GRADINS INDIGO en
pyramide (plaques rivetées, corniches blanc lunaire, étoiles semées sur les dessus) portent, à l'arrière, l'ANNEAU
DRESSÉ de la Porte, face au sud, blanc lunaire à chevrons, contreforts à sa base ; dans l'anneau, un disque d'horizon
plein de CIEL ÉTOILÉ (étoiles fines, cinq étoiles à branches, cœur doux) : la matière fond « de l'autre côté » ; à
l'arrière droit, un obélisque blanc lunaire à incrustations indigo (la fumée).
Palette 60/30/10 (ages.PALETTE[14]) : indigo de nuit / blanc lunaire mat / blanc d'étoile.
"""
import math

from mathutils import Matrix

import ages
import corps
from kit import TAU
from repere import Y

EPOQUE = 14
NOM = ages.NOMS[14]
TRIPLET = ("anneau dressé", "ciel étoilé", "gradins indigo")
FOYER = ages.FOYER[14]
HABILLAGE = dict(ages.CORPS[14], gueule="arche", foyer="noir_spatial")
GRADINS = ((2.82, -2.3, 2.85, 0.55), (2.3, -1.55, 2.6, 1.0), (1.75, -0.85, 2.3, 1.45))
# ronde 1 : Porte agrandie et avancée (1,17 de rayon à yn 1,35 : petite devant la masse des gradins) ; plafond à
# l'écran tenu : haut de l'anneau à yn 0,75 + 0,707 × 4,97 = 4,26 (plafond 4,35)
RX, RYN, RZ, RR, RT = -0.2, 0.75, 3.2, 1.55, 0.22


def matieres(metal, M):
    ages.matieres(14, metal, M)


def etoiles(g, x0, x1, yn0, yn1, z, n, rmax=0.03):
    M = g.M
    for k in range(n):
        x = x0 + (x1 - x0) * g.rng.random()
        y = Y(yn0 + (yn1 - yn0) * g.rng.random())
        r = 0.012 + (rmax - 0.012) * g.rng.random() ** 2
        g.dome((x, y, z), (0, 0, 1), r, M["emit"], n=6, what="etoile")


def chambre(g, c):
    M = g.M
    z0 = c.T["sole_h"]
    prec = None
    with corps.habille(g, c):
        for i, (hx, yn0, yn1, z1) in enumerate(GRADINS):
            corps.boite(g, -hx, hx, yn0, yn1, z0, z1, [M["indigo_nuit"], M["indigo_nuit2"]], panel=0.5, faces="ts")
            g.box((0, Y(yn0) - 0.01, z1 - 0.02), (2 * hx + 0.04, 0.06, 0.06), M["blanc_lunaire"], "hard",
                  what="corniche")
            for sx in (-1, 1):
                g.box((sx * hx, Y((yn0 + yn1) / 2), z1 - 0.02), (0.06, Y(yn1 - yn0), 0.06), M["blanc_lunaire"], "hard",
                      what="corniche")
            if prec is not None:
                phx, pyn0 = prec
                etoiles(g, -phx + 0.1, phx - 0.1, pyn0 + 0.05, yn0 - 0.05, z0 + 0.03, int(14 * phx))
            prec = (hx, yn0)
            z0 = z1
    etoiles(g, -1.65, 1.65, -0.8, 0.75, z0 + 0.03, 26)
    porte(g, c)


def porte(g, c):
    """Anneau dressé face au sud, horizon étoilé plein, chevrons, contreforts."""
    M = g.M
    cy = Y(RYN)
    for sx in (-1, 1):
        x = RX + sx * 1.1      # là où l'anneau descend à z 2,1 : le contrefort (z 2,25) le touche, aucun jour
        g.hexa([corps.V(p) for p in ((x - 0.28, cy - 0.22, 1.45), (x + 0.28, cy - 0.22, 1.45), (x + 0.28, cy + 0.22, 1.45),
                                     (x - 0.28, cy + 0.22, 1.45), (x - 0.1, cy - 0.14, 2.25),
                                     (x + 0.1, cy - 0.14, 2.25), (x + 0.1, cy + 0.14, 2.25),
                                     (x - 0.1, cy + 0.14, 2.25))], M["blanc_lunaire"], "hard", "contrefort")
    g.cyl((RX, cy, RZ), "y", RR - 0.05, 0.08, M["horizon_porte"], n=56, what="horizon")
    g.torus((RX, cy, RZ), "y", RR, RT, M["blanc_lunaire"], n=64, m=10, what="anneau")
    g.torus((RX, cy - 0.06, RZ), "y", RR - RT - 0.01, 0.02, M["emit_soft"], n=56, m=5, what="anneau_lum")
    yf = cy - 0.05
    for k in range(80):
        rr = (RR - 0.25) * math.sqrt(g.rng.random())
        a = TAU * g.rng.random()
        r = 0.012 + 0.025 * g.rng.random() ** 3
        g.dome((RX + rr * math.cos(a), yf, RZ + rr * math.sin(a)), (0, -1, 0), r, M["emit"], n=6, what="etoile")
    for (dx, dz, s) in ((-0.45, 0.3, 0.13), (0.38, -0.25, 0.1), (0.15, 0.5, 0.08), (-0.25, -0.5, 0.09),
                        (0.55, 0.25, 0.07)):
        for a in (0.0, math.pi / 2):
            g.box((RX + dx, yf - 0.005, RZ + dz), (s * 2, 0.008, 0.012), M["emit2"], "flat",
                  R=Matrix.Rotation(a + 0.2, 3, "Y"), what="branche")
    g.cyl((RX, yf - 0.006, RZ), "y", 0.13, 0.01, M["emit_soft"], n=20, style="flat", what="coeur")
    for k in range(9):
        t = math.pi / 2 + TAU * k / 9
        p = corps.V((RX + RR * math.cos(t), cy - RT * 0.9, RZ + RR * math.sin(t)))
        for s in (-1, 1):
            g.box(p + corps.V((s * 0.05 * math.sin(t), 0, -s * 0.05 * math.cos(t))) * 1.0, (0.13, 0.04, 0.035),
                  M["blanc_lunaire"], "hard", R=Matrix.Rotation(-(t + s * 0.6), 3, "Y"), what="chevron")
        g.dome(p + corps.V((0, -0.02, 0)), (0, -1, 0), 0.025, M["emit"], n=6, what="chevron_lum")
    g.halo((RX, cy - 0.8, RZ), M["_emit_rgb"], 7.0)


def socle(g, c):
    """Ronde 2 (richesse : grandes surfaces indigo unies) : plaques à chevron blanc lunaire sur les contremarches,
    pylônes-relais à étoile sur les deux premiers gradins, médaillons étoilés aux angles."""
    M = g.M
    z0 = c.T["sole_h"]
    for i, (hx, yn0, yn1, z1) in enumerate(GRADINS):
        zb = z0 if i == 0 else GRADINS[i - 1][3]
        yf = Y(yn0) - 0.035
        n = int(2 * hx / 0.55)
        for k in range(n):
            x = -hx + 0.3 + (2 * hx - 0.6) * k / max(1, n - 1)
            if abs(x) < 1.0 and i == 0:
                continue
            zm = (zb + z1) / 2
            for s in (-1, 1):
                g.box((x + s * 0.06, yf, zm), (0.14, 0.03, 0.035), M["blanc_lunaire"], "hard",
                      R=Matrix.Rotation(-s * 0.55, 3, "Y"), what="chevron")
            g.dome((x, yf - 0.01, zm + 0.07), (0, -1, 0), 0.02, M["emit"], n=6, what="point")
        if i < 2:
            for x in (-hx + 0.25, -0.6 * hx, 0.6 * hx):
                y = Y(yn0 + 0.2)
                g.box((x, y, z1 + 0.18), (0.07, 0.07, 0.36), M["blanc_lunaire"], "hard", what="pylone")
                g.box((x, y, z1 + 0.04), (0.16, 0.16, 0.08), M["noir_spatial"], "hard", what="semelle")
                g.dome((x, y, z1 + 0.37), (0, 0, 1), 0.04, M["emit2"], n=8, what="etoile_relais")
    # phase A2 (retouches légères) : plaques blanc lunaire boulonnées en quinconce sur les dessus indigo des gradins
    # (hors de la Porte et de l'obélisque)
    z0 = c.T["sole_h"]
    bandes = ((GRADINS[0][0], GRADINS[0][1], GRADINS[1][1], GRADINS[0][3], GRADINS[1][0]),
              (GRADINS[1][0], GRADINS[1][1], GRADINS[2][1], GRADINS[1][3], GRADINS[2][0]),
              (GRADINS[2][0], GRADINS[2][1], GRADINS[2][2], GRADINS[2][3], 0.0))
    for hx, yn0, yn1, z, hx_suiv in bandes:
        for x, yn in corps.semis(-hx + 0.08, hx - 0.08, yn0 + 0.05, yn1 - 0.05, 0.34,
                                 [(RX - 1.1, RYN, 0.45), (RX + 1.1, RYN, 0.45), (2.5, 1.6, 0.4), (0.0, -2.3, 0.95)]):
            if abs(yn - RYN) < 0.2 and abs(x - RX) < RR + 0.3:
                continue
            corps.ancrage(g, x, yn, z, M["blanc_lunaire"], M["noir_spatial"], s=0.065)
    for sx in (-1, 1):
        x, y = sx * 2.45, Y(2.3)
        g.cyl((x, y, GRADINS[0][3] + 0.02), "z", 0.25, 0.04, M["blanc_lunaire"], n=24, what="medaillon")
        g.cyl((x, y, GRADINS[0][3] + 0.045), "z", 0.2, 0.012, M["horizon_porte"], n=24, style="flat", what="horizon")
        for k in range(6):
            a = TAU * k / 6 + 0.3
            g.dome((x + 0.12 * math.cos(a), y + 0.12 * math.sin(a), GRADINS[0][3] + 0.05), (0, 0, 1), 0.015, M["emit"],
                   n=6, what="etoile")


def gueule(g, c, G):
    M = g.M
    zt = G["z1"] + 0.06
    for s in (-1, 1):
        g.box((s * 0.12, G["yf"] - 0.03, zt), (0.3, 0.05, 0.05), M["blanc_lunaire"], "hard",
              R=Matrix.Rotation(-s * 0.45, 3, "Y"), what="chevron")
    g.dome((0, G["yf"] - 0.06, zt + 0.02), (0, -1, 0), 0.04, M["emit"], n=6)


def fumee(g, c):
    """Obélisque blanc lunaire à incrustations indigo."""
    M = g.M
    x, yn = 2.5, 1.6
    y = Y(yn)
    z0, z1 = GRADINS[0][3], 2.9
    g.cyl((x, y, (z0 + z1) / 2), "z", 0.27, z1 - z0, M["blanc_lunaire"], n=4, r2=0.18, phase=math.pi / 4,
          style="hard", what="obelisque")
    for z in (1.3, 2.1):
        g.cyl((x, y, z), "z", 0.25 - 0.04 * (z - 1.3), 0.1, M["indigo_nuit"], n=4, phase=math.pi / 4, style="hard",
              what="incrustation")
    g.dome((x, y - 0.17, 2.55), (0, -1, 0.2), 0.04, M["emit2"], n=8)
    g.cyl((x, y, z1 + 0.03), "z", 0.2, 0.06, M["noir_spatial"], n=4, phase=math.pi / 4, style="hard", what="tete")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.06, 0.13)


def piece(g, c):
    """Relais de la Porte : petits anneaux dressés pleins d'étoiles sur piédestaux indigo."""
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        for dx in (-0.45, 0.45):
            x, y = p["x"] + dx, Y(p["yn"])
            g.box((x, y, zs + 0.12), (0.42, 0.3, 0.24), M["indigo_nuit"], "hard", what="piedestal")
            g.box((x, y - 0.155, zs + 0.22), (0.44, 0.02, 0.04), M["blanc_lunaire"], "hard", what="corniche")
            zc = zs + 0.24 + 0.26
            g.cyl((x, y, zc), "y", 0.22, 0.05, M["horizon_porte"], n=28, what="horizon")
            g.torus((x, y, zc), "y", 0.25, 0.05, M["blanc_lunaire"], n=32, m=6, what="anneau")
            for k in range(9):
                rr = 0.18 * math.sqrt(g.rng.random())
                a = TAU * g.rng.random()
                g.dome((x + rr * math.cos(a), y - 0.03, zc + rr * math.sin(a)), (0, -1, 0), 0.014, M["emit"], n=6)
