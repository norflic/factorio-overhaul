"""Foreuse · Âge 9 · Atome (ère III, 5×5, niveaux 17 et 18). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « silo de béton, chemise de plomb, lueur verte ». Un SILO DE BÉTON blanc cassé à trois étages en retrait couvre
le puits ; sa base est prise dans une CHEMISE DE PLOMB (plaques gris-bleu boulonnées, 8 contreforts) ; une fente de
LUEUR VERTE (uranium) ceint chaque retrait et la margelle ; évents de plomb au sommet ; fûts de plomb à l'avant gauche.
Palette (ages.PALETTE[9]) : béton blanc cassé / plomb gris-bleu / vert uranium.
"""
import math

import ages
import corps as cp

EPOQUE = 9
NOM = ages.NOMS[9]
TRIPLET = ("silo de béton", "chemise de plomb", "lueur verte")
FOYER = ages.FOYER[9]
HABILLAGE = dict(ages.CORPS[9], forme_tablier="octogone")
PIED = 1.3    # contreforts


def occupe(c):
    """Fûts de plomb."""
    a = c.a
    return [(-a * 0.7 - 0.2, -a * 0.68 - 0.2, -a * 0.42 + 0.2, -a * 0.42 + 0.2)]


def matieres(metal, M):
    ages.matieres(9, metal, M)


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    etages = [(rt * 1.0, zt, zt + 0.30 * H), (rt * 0.78, zt + 0.30 * H, zt + 0.58 * H), (rt * 0.55, zt + 0.58 * H,
                                                                                          zt + 0.82 * H)]
    for i, (r, z0, z1) in enumerate(etages):
        cp.colonne(g, 0, 0, z0, z1, r, M["beton_capot"], n=32, what="silo")
        # joints de coffrage
        for j in range(1, 3):
            cp.bague(g, 0, 0, z0 + (z1 - z0) * j / 3.0, r, 0.012, M["joint_beton"], ep=0.006, n=32, what="joint")
        # fente verte au retrait
        cp.bague(g, 0, 0, z1 + 0.012, r * 0.92, 0.025, M["emit"], ep=0.02, n=32, what="fente_verte")
    # chemise de plomb : plaques boulonnées et 8 contreforts sur l'étage bas
    r0, z0, z1 = etages[0]
    cp.colonne(g, 0, 0, z0, z0 + (z1 - z0) * 0.7, r0 + 0.04, M["lead"], n=16, style="hard", what="chemise")
    for k in range(16):
        a = math.tau * (k + 0.5) / 16
        for zz in (z0 + 0.1, z0 + (z1 - z0) * 0.6):
            g.dome(((r0 + 0.05) * math.cos(a), (r0 + 0.05) * math.sin(a), zz), (math.cos(a), math.sin(a), 0), 0.022,
                   M["plomb_sombre"])
    for k in range(8):
        a = math.tau * (k + 0.5) / 8      # décalés de 22,5° : aucun contrefort sous la goulotte
        ca, sa = math.cos(a), math.sin(a)
        cp.poutre(g, (r0 * 1.25 * ca, r0 * 1.25 * sa, zt), (r0 * 1.02 * ca, r0 * 1.02 * sa, z0 + (z1 - z0) * 0.7),
                  0.10, M["plomb_sombre"], "contrefort", h=0.16)
    # couronnement : dalle et 4 évents de plomb, coupole basse
    rh, zh = etages[2][0], etages[2][2]
    g.sphere((0, 0, zh), rh, M["beton_capot"], n=32, m=10, scale=(1, 1, 0.25), what="coupole")
    for (x, y) in cp.sym4((rh * 0.55, 0.0)):
        cp.colonne(g, x, y, zh, zh + 0.22, 0.07, M["lead"], n=10, what="event")
        g.cyl((x, y, zh + 0.25), "z", 0.1, 0.04, M["plomb_sombre"], n=10, what="chapeau_event")
    cp.colonne(g, 0, 0, zh + 0.05, H, 0.13, M["lead"], n=16, what="sommet")
    cp.bague(g, 0, 0, H - 0.1, 0.13, 0.04, M["emit"], ep=0.015, n=16, what="fente_sommet")
    # trèfle (panneau jaune patiné) sur la face sud
    g.box((0, -r0 - 0.03, zt + 0.22 * H), (0.34, 0.02, 0.34), M["yellowpaint"], "hard", what="panneau")
    for k in range(3):
        a = math.radians(90 + 120 * k)
        g.cyl((0.07 * math.cos(a), -r0 - 0.045, zt + 0.22 * H + 0.07 * math.sin(a)), (0, -1, 0), 0.055, 0.01,
              M["blackiron"], n=3, phase=a - math.pi / 2, style="flat", what="trefle")
    cp.halo(g, (0, -r0 - 0.4, zt + 0.3 * H), M, 5.0)
    cp.halo(g, (0, -rh - 0.3, zt + 0.6 * H), M, 3.0)


def trepan(g, c):
    """Margelle doublée d'une fente verte (le cœur chaud du forage)."""
    M = g.M
    cp.bague(g, 0, 0, c.zt + 0.02, c.rw * 0.9, 0.03, M["emit"], ep=0.03, n=32, what="coeur")


def socle(g, c):
    M = g.M
    a, zt = c.a, c.zt
    for i, (x, y) in enumerate(((-a * 0.62, -a * 0.42), (-a * 0.42, -a * 0.62), (-a * 0.7, -a * 0.68))):
        cp.colonne(g, x, y, zt, zt + 0.5, 0.17, M["lead"], n=16, what="fut")
        for zz in (0.08, 0.42):
            cp.bague(g, x, y, zt + zz, 0.17, 0.035, M["plomb_sombre"], ep=0.015, n=16, what="cercle")
        g.cyl((x, y, zt + 0.505), "z", 0.13, 0.012, M["yellowpaint"], n=16, style="flat", what="couvercle")


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r * 1.1, M["lead"], fl_mat=M["plomb_sombre"], bolt_mat=M["plomb_sombre"], what="raccord")


def moteur(g, c):
    """Moteur sous un capot de béton à grille de plomb."""
    M = g.M
    T = c.T["moteur"]
    mx, my, w, p, h = 0.42 * c.a, T["y"], T["w"], T["p"], T["h"]
    cp.dalle(g, mx - w / 2, my - p / 2, mx + w / 2, my + p / 2, c.zt, c.zt + h, M["beton_capot"], what="capot")
    q = [(mx - w * 0.38, my - p / 2 - 0.004, c.zt + h * 0.25), (mx + w * 0.38, my - p / 2 - 0.004, c.zt + h * 0.25),
         (mx + w * 0.38, my - p / 2 - 0.004, c.zt + h * 0.8), (mx - w * 0.38, my - p / 2 - 0.004, c.zt + h * 0.8)]
    g.grille(q, 5, depth=0.02, slat_mat=M["lead"])


def piece(g, c):
    """Phare vert d'alarme dans une cage de plomb, sur le sommet du silo."""
    M = g.M
    z = c.H
    cp.colonne(g, 0, 0, z, z + 0.08, 0.16, M["plomb_sombre"], n=16, what="embase")
    cp.colonne(g, 0, 0, z + 0.08, z + 0.34, 0.11, M["emit"], n=16, style="flat", what="phare")
    for k in range(6):
        a = math.tau * k / 6
        cp.colonne(g, 0.14 * math.cos(a), 0.14 * math.sin(a), z + 0.08, z + 0.38, 0.018, M["lead"], n=6, what="cage")
    g.cyl((0, 0, z + 0.4), "z", 0.17, 0.05, M["lead"], n=16, what="chapeau")
    cp.halo(g, (0, -0.25, z + 0.22), M, 4.0)
