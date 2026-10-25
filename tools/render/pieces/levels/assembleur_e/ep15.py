"""Assembleur · Âge 15 · Néant (ère V, 6×6, niveaux 29 et 30). Lot F3-A ; fiche FICHES_ASSEMBLEUR.md, âge 15. Dans
Blender.

En 3 mots : « sphère noire, serres dorées, couronne incandescente ». Aucun portique : au-dessus de la table flotte une
SPHÈRE NOIRE (horizon) ceinte d'une COURONNE INCANDESCENTE blanc-or penchée vers le sud ; quatre SERRES DORÉES montent
des coins de la table et la tiennent ; un filet de lumière tombe sur le lingot d'or noir posé sous elle. Dos en voûte de
noir chaud à côtes d'or chauffé et joints incandescents, perron à deux marches, joues basses.
Palette 60/30/10 (ages.PALETTE[15]) : noir chaud / or chauffé / lumière incandescente blanc-or.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 15
NOM = ages.NOMS[15]
TRIPLET = ("sphère noire", "serres dorées", "couronne incandescente")
FOYER = ages.FOYER[15]
TRAVAIL = dict(couches=2, images=32, organe="couronne qui tourne autour de la sphère (32 images) et serres qui se "
                                           "resserrent d'un cran ; filet de lumière qui pulse (couche glow)")
HABILLAGE = dict(ages.CORPS[15], forme_embase='gradins', forme_dos='voute', forme_joues='basses',
                 forme_portique='aucun', mat_dos='noir_chaud')
INCLINAISON = math.radians(22.0)


def matieres(metal, M):
    ages.matieres(15, metal, M)


def socle(g, c):
    M = g.M
    h, yb, ze, Hd = c.h, c.yb, c.ze, c.Hd
    zw = c.zw_voute
    ze = c.zs           # troisième jet : sol de la baie = dessus du plateau
    y0, y1 = yb, h - 0.02
    ry = (B(0, y1).y - B(0, y0).y) / 2.0
    rz = Hd - zw
    yc = (B(0, y0).y + B(0, y1).y) / 2.0
    # côtes d'or chauffé sur la voûte (par-dessus les cerclages de la lignée)
    for k in range(7):
        x = -h + 0.3 + (2 * h - 0.6) * k / 6
        pts = [V((x, yc + (ry + 0.045) * math.cos(math.pi * i / 16), zw + (rz + 0.045) * math.sin(math.pi * i / 16)))
               for i in range(17)]
        g.tube(pts, 0.035, M["or_chauffe"], n=6, what="cote_or")
    # joints incandescents au pied de la voûte et tirets lumineux sur la face
    g.box(V((0, B(0, y0).y - 0.03, zw + 0.02)), (2 * h - 0.2, 0.02, 0.025), M["emit"], "flat", what="joint_feu")
    for k in range(9):
        x = -c.xb + 0.15 + (2 * c.xb - 0.3) * k / 8
        g.box(B(x, yb - 0.03, ze + 0.08 + 0.1 * (k % 2)), (0.16, 0.02, 0.03), M["emit"] if k % 3 else M["or_vif"],
              "flat", what="tiret")
        g.dome(B(x, yb - 0.02, zw - 0.12), (0, -1, 0), 0.02, M["or_rivet"])
    halo(g, 0, yb - 0.2, ze + 0.15, 1.0)
    g.box(B(0, yb - 0.04, zw - 0.04), (2 * h - 0.1, 0.04, 0.05), M["or_chauffe"], "hard", what="corniche_or")
    # couronne d'évents incandescents au sommet de la voûte
    for x in (-1.6, -0.8, 0.8, 1.6):
        g.cyl(V((x, yc, Hd + 0.03)), "z", 0.12, 0.08, M["cendre"], n=16, what="event")
        g.cyl(V((x, yc, Hd + 0.075)), "z", 0.08, 0.012, M["emit"], n=16, what="event_feu")
    halo(g, 0, (y0 + y1) / 2, Hd + 0.2, 1.0)


def outil(g, c):
    """Sphère noire, couronne incandescente penchée, quatre serres dorées."""
    M = g.M
    yt, zt = c.yt, c.zt
    tx, ty = c.T["table"]["tx"], c.T["table"]["ty"]
    r = 0.42
    ctr = B(0, yt, zt + 1.05)
    g.sphere(ctr, r, M["horizon"], n=40, m=20, what="sphere_noire")
    ax = Matrix.Rotation(INCLINAISON, 3, "X") @ V((0, 0, 1))
    g.torus(ctr, ax, r + 0.2, 0.035, M["emit"], n=64, m=8, what="couronne")
    g.torus(ctr, ax, r + 0.32, 0.018, M["or_blanc_chaud"], n=64, m=6, what="couronne_or")
    g.torus(ctr, ax, r + 0.03, 0.02, M["emit_soft"], n=48, m=6, what="liseré_horizon")
    halo(g, 0, yt, zt + 1.05, 2.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            base = B(sx * tx * 0.78, yt + sy * ty * 0.72, zt)
            mid = B(sx * tx * 0.92, yt + sy * ty * 0.85, zt + 0.7)
            tip = ctr + V((sx * (r + 0.05) * 0.75, sy * (r + 0.05) * 0.6, 0.2))
            hook = ctr + V((sx * r * 0.45, sy * r * 0.35, r * 0.85))
            pts = [base, mid, tip, hook]
            P = g.spline(pts, 8)
            radii = [0.075 * (1 - 0.8 * i / (len(P) - 1)) + 0.01 for i in range(len(P))]
            g.tube(P, 0.07, M["or_vif"], n=10, radii=radii, what="serre")
            g.sphere(mid, 0.075, M["or_chauffe"], n=14, m=7, what="phalange")
            g.cyl(base + V((0, 0, 0.04)), "z", 0.1, 0.08, M["noir_profond"], n=14, what="socle_serre")


def ouvrage(g, c):
    """Lingot d'or noir sur un socle, filet de lumière qui tombe de la sphère."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.cyl(B(0, yt, zt + 0.05), "z", 0.3, 0.1, M["noir_profond"], n=8, style="hard", what="socle")
    g.box(B(0, yt, zt + 0.15), (0.3, 0.16 * SQ2, 0.1), M["or_chauffe"], "hard", what="lingot")
    g.box(B(0, yt, zt + 0.205), (0.22, 0.1 * SQ2, 0.012), M["or_blanc_chaud"], "flat", what="arete")
    g.cyl(B(0, yt, zt + 0.42), "z", 0.012, 0.36, M["emit"], n=8, what="filet")
    _ = TAU


def piece(g, c):
    """Niveau 30 : deux reliquaires : socle noir à marches, singularité en cage d'or (coins avant, en retrait du
    perron)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.22, c.ze
        g.box(B(x, yn, z + 0.05), (0.62, 0.62 * SQ2, 0.1), M["noir_chaud"], "hard", what="marche")
        g.box(B(x, yn, z + 0.14), (0.44, 0.44 * SQ2, 0.08), M["noir_chaud2"], "hard", what="marche")
        g.cyl(B(x, yn, z + 0.3), "z", 0.06, 0.24, M["noir_profond"], n=10, what="fut")
        g.sphere(B(x, yn, z + 0.55), 0.12, M["horizon"], n=20, m=10, what="singularite")
        g.torus(B(x, yn, z + 0.55), (0, 0.4, 1), 0.18, 0.015, M["emit"], n=32, m=6, what="anneau_feu")
        for k in range(4):
            a = TAU * k / 4 + 0.785
            g.tube([B(x + 0.05 * math.cos(a), yn + 0.05 * math.sin(a), z + 0.4),
                    B(x + 0.2 * math.cos(a), yn + 0.17 * math.sin(a), z + 0.55),
                    B(x + 0.06 * math.cos(a), yn + 0.05 * math.sin(a), z + 0.72)], 0.018, M["or_vif"], n=6,
                   what="cage")
        halo(g, x, yn, z + 0.55, 0.8)
