"""Assembleur · Âge 3 · Vapeur (ère I, 3×3, niveaux 5 et 6). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 3. Dans Blender.

En 3 mots : « grand volant, chaudière couchée, bielle ». Le dos est une CHAUDIÈRE COUCHÉE (berceau vert locomotive cerclé
de cuivre sombre, dôme de vapeur et soupape de laiton, porte de foyer rougeoyante, manomètres). L'outil est une PRESSE À
VOLANT : un GRAND VOLANT dressé face au sud, entraîné par un cylindre à vapeur couché ; sa BIELLE descend au coulisseau
qui frappe la tôle de cuivre sur la matrice. Embase chanfreinée à tôles vertes, joues de cuivre.
Palette 60/30/10 (ages.PALETTE[3]) : cuivre rose / vert locomotive / laiton ; lumière ambre.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
import parts2 as P2
import parts3 as P3
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 3
NOM = ages.NOMS[3]
TRIPLET = ("grand volant", "chaudière couchée", "bielle")
FOYER = ages.FOYER[3]
TRAVAIL = dict(couches=2, images=24, organe="volant qui tourne (24 positions de rayons), bielle et coulisseau qui "
                                           "montent et descendent ; jet de vapeur à la soupape (couche glow)")
HABILLAGE = dict(ages.CORPS[3], forme_embase='chanfrein', forme_dos='voute', forme_joues='caisson',
                 forme_portique='poutre', mat_dos='vert_loco', mat_joues='cuivre_capot')


def matieres(metal, M):
    ages.matieres(3, metal, M)


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    zw = c.zw_voute
    zs = c.zs
    ym = (yb + h - 0.02) / 2.0
    # boîte à feu posée sur le plateau devant la chaudière : grille rougeoyante
    xf = -0.45
    g.box(B(xf, yb - 0.1, zs + 0.15), (0.42, 0.2 * SQ2, 0.3), M["cuivre_sombre"], "hard", what="boite_feu")
    for k in range(5):
        g.box(B(xf - 0.14 + 0.07 * k, yb - 0.21, zs + 0.13), (0.035, 0.02, 0.16), M["emit"], "soft", what="grille")
    g.box(B(xf, yb - 0.215, zs + 0.25), (0.38, 0.03, 0.04), M["laiton_capot"], "hard", what="linteau")
    halo(g, xf, yb - 0.3, zs + 0.15, 1.6)
    # panneau de manomètres et tube de niveau
    g.box(B(0.5, yb - 0.05, zs + 0.2), (0.48, 0.04, 0.4), M["bois_verni"], "hard", what="panneau")
    for x in (0.38, 0.6):
        P2.gauge(g, B(x, yb - 0.08, zs + 0.27), (0, -1, 0), 0.075, M)
    g.box(B(0.68, yb - 0.09, zs + 0.13), (0.05, 0.03, 0.18), M["laiton_capot"], "hard", what="tube_niveau")
    g.box(B(0.68, yb - 0.11, zs + 0.13), (0.025, 0.02, 0.12), M["emit_soft"], "flat", what="niveau")
    # dôme de vapeur, soupape, sifflet sur la chaudière
    g.cyl(B(-0.15, ym, Hd + 0.05), "z", 0.17, 0.14, M["laiton_capot"], n=24, what="dome_vapeur")
    g.sphere(B(-0.15, ym, Hd + 0.12), 0.17, M["laiton_capot"], n=24, m=12, scale=(1, 1, 0.55), what="dome")
    g.cyl(B(0.45, ym, Hd + 0.06), "z", 0.05, 0.16, M["laiton_capot"], n=12, what="soupape")
    g.cyl(B(0.45, ym, Hd + 0.15), "z", 0.07, 0.03, M["cuivre_sombre"], n=12, what="chapeau")
    g.cyl(B(0.8, ym - 0.1, Hd - 0.02), "z", 0.03, 0.2, M["laiton_capot"], n=10, what="sifflet")
    # conduite de vapeur du dôme vers le cylindre de la presse
    g.pipe([B(-0.15, ym - 0.05, Hd + 0.15), B(-0.15, yb - 0.1, Hd + 0.05), B(-0.35, c.yt + 0.3, c.zp - 0.15),
            B(-0.45, c.yt + 0.25, c.zp - 0.3)], 0.035, M["copper"], fl_mat=M["laiton_capot"], bolt_mat=M["laiton_rivet"])
    # fonds de chaudière boulonnés (vus de trois quarts aux bouts) et rivets de virole
    for sx in (-1, 1):
        F.bolts_ring(g, B(sx * (h - 0.03), ym, zw + 0.1), (sx, 0, 0), 0.25, 10, M["laiton_rivet"])
    # caisse à charbon dans la baie
    g.box(B(-0.52, -1.02, zs + 0.08), (0.24, 0.18 * SQ2, 0.16), M["bois_verni"], "hard", what="caisse_charbon")
    for k in range(6):
        F.lump(g, B(-0.6 + 0.05 * k, -1.02, zs + 0.15), 0.045, M["soot"])


def outil(g, c):
    """Presse à volant : grand volant face au sud, cylindre à vapeur couché, bielle, coulisseau et matrice."""
    M = g.M
    yt, zt, zp = c.yt, c.zt, c.zp
    xv, yv, zv, Rv = 0.42, yt + 0.22, zt + 0.5, 0.33
    F.disc_wheel(g, B(xv, yv, zv), "y", Rv, 0.08, M["cuivre_sombre"], M["vert_loco"], spokes=6,
                 hub_mat=M["laiton_capot"])
    g.cyl(B(xv, yv, zv), "y", 0.05, 0.22, M["laiton_capot"], n=12, what="moyeu")
    # paliers du volant sur la joue est
    g.box(B(xv + 0.05, yv + 0.12, (c.zs + zv) / 2), (0.08, 0.06 * SQ2, zv - c.zs + 0.05), M["cuivre_sombre"],
          "hard", what="palier")
    # maneton et BIELLE vers le coulisseau
    a = 2.4
    pin = B(xv + 0.22 * math.cos(a), yv - 0.06, zv + 0.22 * math.sin(a))
    cross = B(0.0, yt, zt + 0.42)
    g.cyl(pin, "y", 0.035, 0.05, M["laiton_capot"], n=10, what="maneton")
    g.tube([pin, cross], 0.028, M["cuivre_sombre"], n=8, what="bielle")
    # coulisseau entre deux guides sous la poutre
    for sx in (-1, 1):
        g.cyl(B(sx * 0.17, yt, (zt + 0.1 + zp) / 2), "z", 0.025, zp - zt - 0.1, M["laiton_capot"], n=8, what="guide")
    g.box(cross + V((0, 0, 0.02)), (0.38, 0.1 * SQ2, 0.09), M["cuivre_sombre"], "hard", what="traverse")
    g.box(B(0, yt, zt + 0.26), (0.18, 0.12 * SQ2, 0.24), M["vert_loco"], "hard", what="coulisseau")
    g.box(B(0, yt, zt + 0.13), (0.22, 0.14 * SQ2, 0.04), M["steel"], "hard", what="poincon")
    # cylindre à vapeur couché, tige vers le maneton
    g.cyl(B(-0.45, yv, zv), "x", 0.09, 0.32, M["laiton_capot"], n=18, what="cylindre_vapeur")
    for x in (-0.6, -0.3):
        g.cyl(B(x, yv, zv), "x", 0.105, 0.03, M["cuivre_sombre"], n=18, what="bride_cyl")
    g.tube([B(-0.29, yv, zv), pin + V((0, 0.02, 0))], 0.015, M["steel_hi"], n=6, what="tige")
    g.box(B(-0.45, yv, (c.zs + zv) / 2 - 0.05), (0.06, 0.05 * SQ2, zv - c.zs - 0.1), M["cuivre_sombre"],
          "hard", what="support_cyl")


def ouvrage(g, c):
    M = g.M
    yt, zt = c.yt, c.zt
    g.box(B(0, yt, zt + 0.04), (0.34, 0.24 * SQ2, 0.08), M["steel_dk"], "hard", what="matrice")
    g.cyl(B(0, yt, zt + 0.09), "z", 0.1, 0.02, M["cuivre_capot"], n=20, what="flan")
    for k in range(4):
        g.cyl(B(-0.32, yt - 0.05, zt + 0.015 + 0.02 * k), "z", 0.08, 0.016, M["cuivre_capot"], n=16, what="pile")
    g.box(B(0.3, yt + 0.02, zt + 0.03), (0.12, 0.18 * SQ2, 0.06), M["bois_verni"], "hard", what="cale")


def piece(g, c):
    """Niveau 6 : seaux à charbon, pelle et burette (coin avant gauche) ; réservoir d'eau d'appoint (coin avant droit)."""
    M = g.M
    po, pe = corps.place(c, "coin_SO"), corps.place(c, "coin_SE")
    z = po["z_sol"]
    for k, (dx, dy) in enumerate(((-0.08, 0.06), (0.12, 0.0))):
        g.cyl(B(po["x"] + dx, po["yn"] + dy, z + 0.08), "z", 0.09, 0.16, M["cuivre_sombre"], n=16, r2=0.075,
              what="seau")
        for j in range(4):
            F.lump(g, B(po["x"] + dx - 0.04 + 0.03 * j, po["yn"] + dy, z + 0.15), 0.035, M["soot"])
    g.box(B(po["x"] - 0.05, po["yn"] - 0.16, z + 0.02), (0.36, 0.03 * SQ2, 0.02), M["bois_verni"], "hard",
          R=Matrix.Rotation(0.3, 3, "Z"), what="pelle")
    g.cyl(B(po["x"] + 0.18, po["yn"] - 0.14, z + 0.06), "z", 0.045, 0.1, M["laiton_capot"], n=12, r2=0.02,
          what="burette")
    P3.vtank(g, pe["x"], Y_(pe["yn"]), 0.16, 0.42, M, paint=M["vert_loco"], z0=z, gauges=1, band=M["laiton_capot"])
    halo(g, pe["x"], pe["yn"] - 0.2, z + 0.3, 0.6)


def Y_(yn):
    return yn * SQ2
