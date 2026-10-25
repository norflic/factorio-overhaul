"""Assembleur · Âge 10 · Haute technologie (ère IV, 6×6, niveaux 19 et 20). Lot F3-A, ronde F3-A3 ; fiche
FICHES_ASSEMBLEUR.md, âge 10. Dans Blender.

En 3 mots : « bras robots, coque ivoire, écrans ». Ronde F3-A3 (verdict du DC : âge resté « presque pareil », silhouette
nouvelle demandée) : plan en H. Deux SALLES BLANCHES en coque ivoire (ailes pleine profondeur, nez arrondi, ÉCRANS et
rampes de voyants sur leurs faces sud, groupes de climatisation, parabole et antennes sur leurs toits) encadrent le bâti
central ; deux BRAS ROBOTS ivoire montés sur le BORD INTÉRIEUR des ailes plongent vers la carte de processeur ; goulottes
de câbles rouges et bleus des ailes aux robots. Le sol se voit devant et derrière le bâti.
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
HABILLAGE = dict(ages.CORPS[10], plan='H', forme_embase='carre', forme_dos='plat', forme_joues='hautes',
                 forme_portique='aucun',
                 mat_dos='blanc_casse', mat_joues='blanc_casse')

DENSITE = dict(p=0.75, lampes=0.16, pas=0.17)     # ronde F3-A3 : densité vers la mitrailleuse, nuit plus claire
GARNIR = ("bati",)          # toits des ailes : garniture dense seulement (hors des réserves des robots et des toits)


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


def _clim(g, x, yn, z):
    """Groupe de climatisation sur un toit : caisson anthracite, deux ventilateurs à grille, voyant."""
    M = g.M
    g.box(B(x, yn, z + 0.12), (0.62, 0.36 * SQ2, 0.24), M["gris_tech"], "hard", what="clim")
    for s in (-1, 1):
        g.cyl(B(x + s * 0.15, yn, z + 0.245), "z", 0.12, 0.012, M["anthracite"], n=20, what="ventilateur")
        g.torus(B(x + s * 0.15, yn, z + 0.25), "z", 0.12, 0.012, M["blanc_casse"], n=20, m=4, what="grille_vent")
    corps.lampe(g, B(x + 0.26, yn - 0.12, z + 0.24), 0.02, M["emit"])


def socle(g, c):
    """Plan H : faces sud des ailes (écrans, rampes de voyants, bandeau lumineux), toits (climatisation, parabole,
    antennes), goulottes de câbles des ailes aux robots."""
    M = g.M
    h, ze, Hd = c.h, c.ze, c.z_joue
    yf = c.yf
    for sx in (-1, 1):
        x0, x1 = sorted((sx * c.xb, sx * (h - 0.02)))
        xm = (x0 + x1) / 2.0
        # face sud de l'aile : grand écran, grille, rampe de voyants, bandeau lumineux bleu sous le nez
        P3.screen(g, B(xm - 0.15 * sx, yf - 0.02, ze + 0.75), (0, -1, 0), 0.7, 0.42, M, M["emit"])
        halo(g, xm, yf - 0.2, ze + 0.75, 0.8)
        g.grille([B(xm + 0.35 * sx - 0.16, yf - 0.02, ze + 0.15), B(xm + 0.35 * sx + 0.16, yf - 0.02, ze + 0.15),
                  B(xm + 0.35 * sx + 0.16, yf - 0.02, ze + 0.5), B(xm + 0.35 * sx - 0.16, yf - 0.02, ze + 0.5)], 4,
                 slat_mat=M["anthracite"])
        P3.lamp_row(g, B(x0 + 0.12, yf - 0.04, ze + 0.08), B(x1 - 0.12, yf - 0.04, ze + 0.08), 7, (0, -1, 0), M["emit"],
                    M, size=0.03)
        g.box(B(xm, yf - 0.06, Hd - 0.2), (x1 - x0 - 0.1, 0.02, 0.03), M["emit"], "flat", what="bandeau_lumineux")
        halo(g, xm, yf - 0.3, Hd - 0.2, 0.7)
        # toit : climatisation, parabole (aile est) ou antennes (aile ouest), bandeau anthracite
        for yy in (1.2, 2.2):
            _clim(g, xm, yy, Hd)
            c.reserves.append((xm, yy, 0.42))
        if sx > 0:
            F.dish(g, tuple(B(xm + 0.1, -0.95, Hd + 0.32)), 0.36, 0.1, M["blanc_casse"], M["gris_tech"], rx=-0.5, rz=0.3)
            g.cyl(B(xm + 0.1, -0.95, Hd + 0.14), "z", 0.045, 0.28, M["anthracite"], n=10, what="mat")
            c.reserves.append((xm + 0.1, -0.95, 0.45))
        else:
            for yy in (-1.05, -0.6):
                g.cyl(B(xm - 0.15, yy, Hd + 0.35), "z", 0.018, 0.7, M["anthracite"], n=6, what="antenne")
                corps.lampe(g, B(xm - 0.15, yy, Hd + 0.7), 0.028, M["emit"])
                c.reserves.append((xm - 0.15, yy, 0.1))
        # goulottes de câbles rouges et bleus du bord de l'aile au socle du robot
        for k, m in enumerate((M["cable_r"], M["cable_b"], M["cable_r"])):
            xa = sx * (c.xb + 0.25 + 0.06 * k)
            g.hose([B(xa, -0.9, Hd + 0.03), B(xa, -0.3, Hd + 0.05), B(sx * (c.xb + 0.12), 0.2 + 0.05 * k, Hd + 0.06)],
                   0.024, m, step=0.05)


def outil(g, c):
    """Deux bras robots montés sur le BORD INTÉRIEUR des ailes, qui plongent vers la carte."""
    yt, zt = c.yt, c.zt
    Hd = c.z_joue
    for sx in (-1, 1):
        base = B(sx * (c.xb + 0.3), yt + 0.3, Hd)
        coude = B(sx * (c.xb - 0.15), yt + 0.35, Hd + 0.75)
        poignet = B(sx * 0.32, yt + 0.05, zt + 0.48)
        _bras(g, base, coude, poignet, (-sx * 0.4, -0.1, -1.0))
        c.reserves.append((sx * (c.xb + 0.3), yt + 0.3, 0.32))
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


def entree(g, c, p):
    """Chargeur de galettes de silicium : colonne de plateaux gris, voyant bleu (entrée)."""
    M = g.M
    g.box(B(p["x"], p["yn"], p["z"] + 0.04), (2 * p["r"], 2 * p["r"] * SQ2, 0.08), M["anthracite"], "hard",
          what="socle_chargeur")
    for k in range(6):
        g.cyl(B(p["x"], p["yn"], p["z"] + 0.1 + 0.035 * k), "z", p["r"] * 0.7, 0.02, M["spec"] if k % 2 else
              M["gris_tech"], n=24, what="galette")
    corps.lampe(g, B(p["x"] + p["r"] * 0.8, p["yn"] - p["r"] * 0.6, p["z"] + 0.08), 0.03, M["emit"])


def sortie(g, c, p):
    """Plateau antistatique ivoire : processeurs finis (sortie)."""
    corps.bac(g, c, p, g.M["blanc_casse"], g.M["acier_tech"], forme="plaque")
    corps.lampe(g, B(p["x"] - p["r"] * 0.8, p["yn"] - p["r"] * 0.6, p["z"] + 0.12), 0.03, g.M["emit"])


def piece(g, c):
    """Niveau 20 (plus grande) : trois baies de serveurs HAUTES à diodes et chemin de câbles (coins avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        # rendu a4 (plan H) : baies JOINTIVES et rangée collée à l'aile (des jours de sol entre elles, sous le chemin de
        # câbles, faisaient des trous de 27 à 86 px)
        sx = 1 if p["x"] > 0 else -1
        # F3-B : la conduite du port S passe au raccord de jeu (x = −0,5 sur ce 6×6) : DEUX baies à l'ouest, trois à l'est
        n = 3 if sx > 0 else 2
        w = 0.36
        tot = n * w - (n - 1) * 0.01
        x = sx * (c.xb - tot / 2)
        for k in range(n):
            _baie(g, x + (k - (n - 1) / 2.0) * (w - 0.01), p["yn"] + 0.08, p["z_sol"], w, 0.5, 1.0)
        g.box(B(x, p["yn"] + 0.08, p["z_sol"] + 1.06), (tot, 0.3 * SQ2, 0.05), M["anthracite"], "hard",
              what="chemin_cables")
        for k in range(n + 1):
            xa = x - tot / 2 + 0.1 + (tot - 0.3) * k / n
            g.cable(B(xa, p["yn"], p["z_sol"] + 1.08), B(xa + 0.15, p["yn"], p["z_sol"] + 1.08), 0.04, 0.015,
                    M["cable_r"] if k % 2 else M["cable_b"])
        halo(g, x, p["yn"] - 0.3, p["z_sol"] + 0.5, 0.6)
    _ = math
