"""Assembleur · Âge 9 · Atome (ère III, 5×5, niveaux 17 et 18). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 9. Dans
Blender.

En 3 mots : « cellule chaude, télémanipulateurs, vitre verte ». Sur la table, une CELLULE CHAUDE de plomb (murs épais,
toit à hublots), percée au sud d'une grande VITRE VERTE inclinée où l'on devine la lueur de l'uranium ; deux
TÉLÉMANIPULATEURS articulés passent par-dessus la vitre, poignées côté opérateur. Dos en COQUE de béton blanc cassé
(nez arrondi, trèfles, châteaux de plomb sur la pente), joues de béton, embase à dalles et liseré vert.
Ronde F3-A3 (verdict du DC : âge resté « presque pareil ») : plan en L VRAI, tout le quart nord-est est du SOL (le dos
ne couvre que la moitié ouest) ; HAUTE CHEMINÉE DE VENTILATION de béton à bague verte et feu d'obstacle sur l'aile de
blindage (silhouette nouvelle).
Palette 60/30/10 (ages.PALETTE[9]) : béton blanc cassé / plomb gris-bleu / vert uranium.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2

V = Vector

EPOQUE = 9
NOM = ages.NOMS[9]
TRIPLET = ("cellule chaude", "télémanipulateurs", "vitre verte")
FOYER = ages.FOYER[9]
TRAVAIL = dict(couches=2, images=16, organe="les deux télémanipulateurs (bras et pinces, 16 images) ; lueur de la vitre "
                                           "qui pulse doucement (couche glow)")
HABILLAGE = dict(ages.CORPS[9], plan='L', forme_embase='carre', forme_dos='coque', forme_joues='caisson',
                 forme_portique='aucun', mat_dos='beton_capot', mat_joues='beton_capot')
DENSITE = dict(p=0.58, lampes=0.08)


def matieres(metal, M):
    ages.matieres(9, metal, M)


def _chateau(g, x, yn, z, r, hgt):
    M = g.M
    g.cyl(B(x, yn, z + hgt / 2), "z", r, hgt, M["lead"], n=20, what="chateau")
    for f in (0.25, 0.6):
        g.tube_shell(B(x, yn, z + hgt * f), "z", r + 0.02, r - 0.01, 0.05, M["plomb_sombre"], n=20, what="frette")
    g.cyl(B(x, yn, z + hgt + 0.03), "z", r * 0.92, 0.06, M["plomb_sombre"], n=20, what="couvercle")
    F.trefoil(g, B(x, yn, z + hgt + 0.065), (0, 0, 1), r * 0.5)


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    zc = c.zc_coque
    ze = c.zs           # troisième jet : sol de la baie = dessus du plateau
    y1 = h - 0.02
    # face : trèfles, bandes de danger, voyants verts, grilles de ventilation (ronde F3-A3 : le dos s'arrête au coin vide
    # nord-est, en x = c.Lx)
    xd = min(c.xb, c.Lx - 0.02)
    for x in (-1.05, 0.12):
        F.trefoil(g, B(x, yb - 0.04, (ze + zc) / 2), (0, -1, 0), 0.14)
    g.hazard([B(-c.xb, yb - 0.04, ze + 0.02), B(xd, yb - 0.04, ze + 0.02), B(xd, yb - 0.04, ze + 0.09),
              B(-c.xb, yb - 0.04, ze + 0.09)], 18, t=0.01)
    for x in (-0.6, -0.25):
        g.grille([B(x - 0.14, yb - 0.03, ze + 0.12), B(x + 0.14, yb - 0.03, ze + 0.12), B(x + 0.14, yb - 0.03, zc - 0.06),
                  B(x - 0.14, yb - 0.03, zc - 0.06)], 4, slat_mat=M["plomb_sombre"])
    for x in (-1.25, -0.85, 0.3):
        corps.lampe_face(g, x, yb, zc - 0.1, 0.045, M["emit"], M["plomb_sombre"])
        halo(g, x, yb - 0.15, zc - 0.1, 0.4)
    # châteaux de plomb sur la pente de la coque
    for k, x in enumerate((-1.95, -1.3)):
        yn = yb + (y1 - yb) * (0.45 if k % 2 else 0.7)
        _chateau(g, x, yn, corps.z_toit(c, x, yn) - 0.02, 0.2, 0.42)
        c.reserves.append((x, yn, 0.28))
    # ronde F3-A3 (silhouette nouvelle) : HAUTE CHEMINÉE DE VENTILATION de béton sur l'aile, bague verte et feu d'obstacle
    xs_, ys_ = (-c.h + 0.02 - c.xb) / 2.0, c.yb - 0.22
    za = c.z_aile
    Hs = 1.7
    g.box(B(xs_, ys_, za + 0.06), (0.4, 0.4 * SQ2, 0.12), M["plomb_sombre"], "hard", what="pied_cheminee")
    g.cyl(B(xs_, ys_, za + 0.12 + Hs / 2), "z", 0.2, Hs, M["beton_capot"], n=24, r2=0.15, what="cheminee")
    for f in (0.3, 0.62, 0.9):
        g.tube_shell(B(xs_, ys_, za + 0.12 + Hs * f), "z", 0.2 - 0.05 * f + 0.02, 0.2 - 0.05 * f - 0.01, 0.05,
                     M["plomb_sombre"], n=24, what="cerclage")
    g.tube_shell(B(xs_, ys_, za + 0.12 + Hs * 0.78), "z", 0.183, 0.16, 0.07, M["uranium"], n=24, what="bague_verte")
    g.cyl(B(xs_, ys_, za + 0.12 + Hs + 0.03), "z", 0.17, 0.06, M["plomb_sombre"], n=24, what="couronne")
    corps.lampe(g, B(xs_, ys_, za + 0.12 + Hs + 0.06), 0.045, M["emit"])
    halo(g, xs_, ys_, za + Hs + 0.3, 0.6)
    c.reserves.append((xs_, ys_, 0.3))
    # AILE de blindage (plan L, ouest) : porte de cellule à volant, trèfle, voyants, bandes de danger
    xa, xz, yf = -h + 0.02, -c.xb, c.yf
    xw = (xa + xz) / 2.0
    g.box(B(xw, yf - 0.04, c.ze + 0.42), (0.62, 0.05, 0.76), M["plomb_sombre"], "hard", what="porte_blindee")
    g.box(B(xw, yf - 0.07, c.ze + 0.42), (0.5, 0.02, 0.64), M["lead"], "hard", what="vantail")
    g.torus(B(xw, yf - 0.1, c.ze + 0.45), "y", 0.1, 0.018, M["steel_hi"], n=16, m=5, what="volant")
    F.trefoil(g, B(xw, yf - 0.06, c.ze + 0.98), (0, -1, 0), 0.16)
    g.hazard([B(xa + 0.05, yf - 0.05, c.ze + 0.04), B(xz - 0.05, yf - 0.05, c.ze + 0.04),
              B(xz - 0.05, yf - 0.05, c.ze + 0.13), B(xa + 0.05, yf - 0.05, c.ze + 0.13)], 8, t=0.008)
    for z in (c.ze + 1.2, c.ze + 1.32):
        corps.lampe_face(g, xw - 0.2, yf, z, 0.04, M["emit"], M["plomb_sombre"])
        corps.lampe_face(g, xw + 0.2, yf, z, 0.04, M["emit"], M["plomb_sombre"])
    halo(g, xw, yf - 0.2, c.ze + 1.25, 0.8)
    # conduits de ventilation de l'aile vers la cellule (liaisons de l'âge)
    for k, dz in enumerate((0.0, 0.18)):
        p0 = B(-c.xb - 0.02, c.yt + 0.25, c.z_aile - 0.3 + dz)
        p1 = B(-c.T["table"]["tx"] * 0.9, c.yt + 0.1, c.zt + 0.6 + dz)
        g.pipe([p0, p0.lerp(p1, 0.5) + V((0, 0, 0.1)), p1], 0.045, M["plomb_sombre"], fl_mat=M["lead"],
               bolt_mat=M["steel_hi"])
    xf = -0.4
    g.box(B(xf, (yb + y1) / 2 + 0.2, corps.z_toit(c, xf, (yb + y1) / 2 + 0.2) + 0.15), (0.8, 0.3 * SQ2, 0.3),
          M["plomb_sombre"], "hard", what="filtres")
    corps.lampe(g, B(xf, (yb + y1) / 2 + 0.1, corps.z_toit(c, xf, (yb + y1) / 2 + 0.2) + 0.3), 0.05, M["emit"])
    halo(g, xf, (yb + y1) / 2, corps.z_toit(c, xf, (yb + y1) / 2) + 0.4, 0.8)
    c.reserves.append((xf, (yb + y1) / 2 + 0.2, 0.45))


def outil(g, c):
    """Cellule chaude de plomb sur la table, vitre verte inclinée, deux télémanipulateurs."""
    M = g.M
    yt, zt = c.yt, c.zt
    tx, ty = c.T["table"]["tx"], c.T["table"]["ty"]
    wx, y0, y1 = tx * 0.95, yt - ty * 0.55, yt + ty * 0.9
    zh = zt + 0.78
    # murs et toit de plomb
    g.box(B(0, (y0 + y1) / 2, (zt + zh) / 2), (2 * wx, (y1 - y0) * SQ2, zh - zt), M["lead"], "hard", what="cellule")
    corps.face_s(g, -wx, wx, y0 - 0.005, zh - 0.12, zh, M["plomb_sombre"], nv=1)
    g.box(B(0, (y0 + y1) / 2, zh + 0.04), (2 * wx + 0.08, (y1 - y0) * SQ2 + 0.08, 0.08), M["plomb_sombre"], "hard",
          what="toit_cellule")
    for sx in (-1, 1):
        corps.lampe(g, B(sx * wx * 0.5, (y0 + y1) / 2, zh + 0.08), 0.06, M["emit_soft"], cage=M["plomb_sombre"])
    # vitre verte inclinée : épais cadre de plomb, verre vert, lueur de l'intérieur
    zv0, zv1 = zt + 0.12, zh - 0.14
    q = [B(-wx * 0.8, y0 - 0.12, zv0), B(wx * 0.8, y0 - 0.12, zv0), B(wx * 0.8, y0 - 0.01, zv1),
         B(-wx * 0.8, y0 - 0.01, zv1)]
    nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
    g.slab([p + nrm * 0.0 for p in q], nrm, 0.04, M["plomb_sombre"], "hard", "cadre_vitre")
    qi = [q[0].lerp(q[2], 0.08), q[1].lerp(q[3], 0.08), q[2].lerp(q[0], 0.08), q[3].lerp(q[1], 0.08)]
    g.slab([p + nrm * 0.04 for p in qi], nrm, 0.012, M["uranium"], "flat", "vitre_verte")
    qg = [qi[0].lerp(qi[2], 0.22), qi[1].lerp(qi[3], 0.22), qi[2].lerp(qi[0], 0.22), qi[3].lerp(qi[1], 0.22)]
    g.slab([p + nrm * 0.052 for p in qg], nrm, 0.006, M["emit_soft"], "flat", "lueur")
    halo(g, 0, y0 - 0.3, (zv0 + zv1) / 2, 1.4)
    # télémanipulateurs : poignées côté sud, bras articulés qui passent par-dessus la vitre
    for sx in (-1, 1):
        x = sx * wx * 0.55
        p0 = B(x, y0 - 0.45, zt + 0.35)
        p1 = B(x, y0 - 0.38, zh + 0.12)
        p2 = B(x * 0.9, (y0 + y1) / 2, zh + 0.22)
        g.tube([p0, p1], 0.028, M["steel_hi"], n=8, what="bras_maitre")
        g.tube([p1, p2], 0.032, M["steel_hi"], n=8, what="bras_traversant")
        for p in (p1, p2):
            g.sphere(p, 0.05, M["plomb_sombre"], n=12, m=6, what="rotule")
        g.box(p0 + V((0, -0.02, -0.06)), (0.05, 0.05, 0.12), M["rubber"], "hard",
              R=Matrix.Rotation(0.3, 3, "X"), what="poignee")
        g.box(p0 + V((0, -0.04, 0.0)), (0.08, 0.03, 0.03), M["plomb_sombre"], "hard", what="gachette")
        g.cyl(B(x, (y0 + y1) / 2, zh + 0.12), "z", 0.07, 0.12, M["plomb_sombre"], n=14, what="traversee")


def entree(g, c, p):
    """Râtelier de crayons de combustible verts sur l'aile (entrée)."""
    M = g.M
    r, z = p["r"], p["z"]
    g.box(B(p["x"], p["yn"], z + 0.04), (2 * r, 2 * r * SQ2, 0.08), M["plomb_sombre"], "hard", what="socle_ratelier")
    for i in range(4):
        for j in range(3):
            g.cyl(B(p["x"] - r * 0.6 + r * 0.4 * i, p["yn"] - r * 0.5 + r * 0.5 * j, z + 0.16), "z", 0.025, 0.18,
                  M["uranium"] if (i + j) % 2 else M["emit_soft"], n=8, what="crayon")


def sortie(g, c, p):
    """Château de plomb ouvert : barres d'uranium enrichi (sortie)."""
    M = g.M
    _chateau(g, p["x"], p["yn"], p["z"], p["r"] * 0.85, 0.3)
    g.cyl(B(p["x"], p["yn"], p["z"] + 0.36), "z", p["r"] * 0.5, 0.03, M["emit"], n=16, what="lueur")


def ouvrage(g, c):
    """Plateau de pastilles d'uranium au pied de la vitre (sas de sortie)."""
    M = g.M
    yt, zt = c.yt, c.zt
    ty = c.T["table"]["ty"]
    y = yt - ty * 0.82
    g.box(B(0, y, zt + 0.03), (0.5, 0.14 * SQ2, 0.06), M["plomb_sombre"], "hard", what="sas")
    for k in range(7):
        g.cyl(B(-0.18 + 0.06 * k, y, zt + 0.07), "z", 0.022, 0.03, M["emit"] if k % 2 else M["uranium"], n=8,
              what="pastille")


def piece(g, c):
    """Niveau 18 (plus grande) : six fûts de déchets jaunes à trèfle sur deux niveaux de palettes (coins avant)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.06, p["z_sol"]
        F.drum(g, tuple(B(x, yn + 0.0, z + 0.44 + 0.08)), 0.14, 0.36, M["yellowpaint"], M["plomb_sombre"], trefoil=True)
        g.box(B(x, yn, z + 0.48), (0.5, 0.42 * SQ2, 0.06), M["wood"], "hard", what="palette_haute")
        g.box(B(x, yn, z + 0.04), (0.72, 0.6 * SQ2, 0.08), M["wood"], "hard", what="palette")
        for k, (dx, dy) in enumerate(((-0.17, 0.12), (0.17, 0.12), (-0.17, -0.14), (0.17, -0.14))):
            F.drum(g, tuple(B(x + dx, yn + dy, z + 0.08)), 0.14, 0.36, M["yellowpaint"], M["plomb_sombre"],
                   trefoil=True)
        corps.lampe(g, B(x, yn - 0.3, z), 0.04, M["emit"])
        halo(g, x, yn - 0.3, z + 0.1, 0.4)
    _ = math
