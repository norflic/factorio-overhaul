"""Assembleur · Âge 10 · Haute technologie (ère IV, 6×6, niveaux 19 et 20). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge
10. Dans Blender.

En 3 mots : « bras robots, coque ivoire, écrans ». Une CELLULE ROBOTISÉE : deux BRAS ROBOTS articulés ivoire (articulations
anthracite cerclées de bleu) posés de part et d'autre de la table assemblent une carte de processeur ; aucun portique.
Dos en COQUE IVOIRE à nez arrondi, rangée d'ÉCRANS et de grilles, goulottes de câbles rouges et bleus, petite parabole
sur la pente ; joues ivoire en pente.
Palette 60/30/10 (ages.PALETTE[10]) : ivoire chaud / anthracite / câbles rouges et bleus, voyants bleus.
"""
import math

from mathutils import Vector

import ages
import corps
import formes as F
import parts3 as P3
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 10
NOM = ages.NOMS[10]
TRIPLET = ("bras robots", "coque ivoire", "écrans")
FOYER = ages.FOYER[10]
TRAVAIL = dict(couches=2, images=32, organe="deux bras robots (épaule, coude, poignet : 32 images, boucle de prise et "
                                           "pose) ; écrans et voyants qui défilent (couche glow, 8 images)")
HABILLAGE = dict(ages.CORPS[10], forme_embase='carre', forme_dos='coque', forme_joues='pente', forme_portique='aucun',
                 mat_dos='blanc_casse', mat_joues='blanc_casse')


def matieres(metal, M):
    ages.matieres(10, metal, M)


def _articulation(g, p, axe, r):
    M = g.M
    g.cyl(p, axe, r, r * 1.3, M["anthracite"], n=18, what="articulation")
    F.lit_ring(g, p + V(axe) * r * 0.66, axe, r * 0.9, M["emit"], w=0.02, t=0.01)


def _bras(g, base, coude, poignet, pince_dir):
    """Bras robot à 6 axes : socle, tourelle, bras, avant-bras, poignet, pince."""
    M = g.M
    g.cyl(base + V((0, 0, 0.06)), "z", 0.22, 0.12, M["anthracite"], n=24, what="socle_robot")
    g.cyl(base + V((0, 0, 0.2)), "z", 0.17, 0.16, M["blanc_casse"], n=24, what="tourelle")
    epaule = base + V((0, 0, 0.36))
    _articulation(g, epaule, (0, 1, 0), 0.12)
    g.tube([epaule, coude], 0.085, M["blanc_casse"], n=12, what="bras")
    _articulation(g, coude, (0, 1, 0), 0.1)
    g.tube([coude, poignet], 0.065, M["blanc_casse"], n=12, what="avant_bras")
    _articulation(g, poignet, (0, 1, 0), 0.07)
    d = V(pince_dir).normalized()
    g.cyl(poignet + d * 0.08, d, 0.05, 0.1, M["anthracite"], n=12, what="flasque")
    for s in (-1, 1):
        g.box(poignet + d * 0.17 + V((s * 0.04, 0, 0)), (0.025, 0.04, 0.1), M["acier_tech"], "hard", what="doigt")
    g.cable(epaule + V((0, -0.1, 0.05)), coude + V((0, -0.08, 0.05)), 0.06, 0.016, M["cable_b"])


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    zc = c.zc_coque
    ze = c.zs           # troisième jet : sol de la baie = dessus du plateau
    y1 = h - 0.02
    # écrans et grilles le long de la face de la coque
    for k, x in enumerate((-1.2, -0.42, 0.42, 1.2)):
        if k in (1, 2):
            P3.screen(g, B(x, yb - 0.02, zc - 0.2), (0, -1, 0), 0.5, 0.28, M, M["emit"])
            halo(g, x, yb - 0.15, zc - 0.2, 0.6)
        else:
            g.grille([B(x - 0.3, yb - 0.02, ze + 0.1), B(x + 0.3, yb - 0.02, ze + 0.1), B(x + 0.3, yb - 0.02, zc - 0.08),
                      B(x - 0.3, yb - 0.02, zc - 0.08)], 5, slat_mat=M["anthracite"])
    P3.lamp_row(g, B(-1.5, yb - 0.04, ze + 0.05), B(1.5, yb - 0.04, ze + 0.05), 10, (0, -1, 0), M["emit"], M, size=0.03)
    halo(g, 0, yb - 0.2, ze + 0.08, 0.8)
    # bandeau anthracite au pied de la pente, prises d'air
    g.box(B(0, yb - 0.02, zc + 0.02), (2 * h - 0.1, 0.05, 0.08), M["anthracite"], "hard", what="bandeau")
    # goulottes de câbles rouges et bleus du dos vers les robots
    for sx in (-1, 1):
        x0 = sx * 1.2
        for k, m in enumerate((M["cable_r"], M["cable_b"], M["cable_r"])):
            g.hose([B(x0 + 0.06 * k, yb - 0.06, ze + 0.06), B(x0 + 0.06 * k, (yb + c.yt) / 2, ze + 0.04),
                    B(sx * (c.T["table"]["tx"] + 0.3) + 0.05 * k, c.yt + 0.25, ze + 0.04)], 0.022, m, step=0.05)
    # parabole et mâts d'antenne sur la pente
    yy = yb + (y1 - yb) * 0.6
    F.dish(g, tuple(B(1.7, yy, corps.z_toit(c, 1.7, yy) + 0.3)), 0.32, 0.1, M["blanc_casse"], M["gris_tech"],
           rx=-0.5, rz=0.3)
    g.cyl(B(1.7, yy, corps.z_toit(c, 1.7, yy) + 0.12), "z", 0.04, 0.3, M["anthracite"], n=10, what="mat")
    for x in (-1.9, -1.4):
        yy2 = yb + (y1 - yb) * 0.75
        z0 = corps.z_toit(c, x, yy2)
        g.cyl(B(x, yy2, z0 + 0.25), "z", 0.015, 0.5, M["anthracite"], n=6, what="antenne")
        corps.lampe(g, B(x, yy2, z0 + 0.5), 0.025, M["emit"])


def outil(g, c):
    """Deux bras robots de part et d'autre de la table, pinces au-dessus de la carte."""
    yt, zt, ze = c.yt, c.zt, c.ze
    tx = c.T["table"]["tx"]
    for sx in (-1, 1):
        base = B(sx * (tx + 0.3), yt + 0.15, c.zs)
        coude = B(sx * (tx + 0.1), yt + 0.25, zt + 0.95)
        poignet = B(sx * 0.3, yt + 0.05, zt + 0.42)
        _bras(g, base, coude, poignet, (-sx * 0.4, -0.1, -1.0))
    halo(g, 0, yt, zt + 0.6, 1.0)


def ouvrage(g, c):
    """Carte de processeur sur gabarit : plaque anthracite, puces, pistes bleues lumineuses."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.box(B(0, yt, zt + 0.04), (1.1, 0.7 * SQ2, 0.08), M["gris_tech"], "hard", what="gabarit")
    g.box(B(0, yt, zt + 0.09), (0.8, 0.5 * SQ2, 0.025), M["anthracite"], "hard", what="carte")
    g.box(B(0, yt, zt + 0.115), (0.24, 0.17 * SQ2, 0.03), M["acier_tech"], "hard", what="processeur")
    for k in range(6):
        x = -0.33 + 0.13 * k
        g.box(B(x, yt + 0.16, zt + 0.11), (0.08, 0.06 * SQ2, 0.02), M["spec"], "hard", what="puce")
        g.box(B(x, yt - 0.12, zt + 0.103), (0.012, 0.12 * SQ2, 0.004), M["emit"], "flat", what="piste")
    g.box(B(0, yt - 0.02, zt + 0.103), (0.7, 0.012, 0.004), M["emit"], "flat", what="piste")


def _baie(g, x, yn, z, w, d, hgt):
    M = g.M
    g.box(B(x, yn, z + hgt / 2), (w, d * SQ2, hgt), M["anthracite"], "hard", what="baie")
    g.box(B(x, yn - d / 2 - 0.005, z + hgt / 2), (w * 0.86, 0.01, hgt * 0.9), M["gris_tech"], "hard", what="porte")
    for k in range(6):
        zz = z + 0.1 + (hgt - 0.2) * k / 5
        g.box(B(x - w * 0.2, yn - d / 2 - 0.012, zz), (w * 0.3, 0.008, 0.012), M["emit"] if k % 2 else M["cable_r"],
              "flat", what="diode")
    g.box(B(x, yn, z + hgt + 0.01), (w + 0.03, d * SQ2 + 0.03, 0.02), M["blanc_casse"], "hard", what="toit_baie")


def piece(g, c):
    """Niveau 20 : deux baies de serveurs à diodes (coins avant)."""
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        for k in range(2):
            _baie(g, p["x"] - 0.22 + 0.44 * k, p["yn"] + 0.05, p["z_sol"], 0.36, 0.5, 0.7)
        halo(g, p["x"], p["yn"] - 0.3, p["z_sol"] + 0.4, 0.5)
    _ = math
