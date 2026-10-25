"""Assembleur · Âge 15 · Néant (ère V, 6×6, niveaux 29 et 30). Lot F3-A, ronde F3-A2 ; fiche FICHES_ASSEMBLEUR.md, âge 15.
Dans Blender.

En 3 mots : « sphère noire, serres dorées, couronne incandescente ». Plan en PORTIQUE : deux pylônes de noir chaud à
arêtes d'or et un pont-caisson couronné d'or ; entre eux, la SPHÈRE NOIRE (horizon) est tenue par trois SERRES DORÉES
(une de chaque pylône, une du pont) et ceinte d'une COURONNE INCANDESCENTE mince, penchée vers le sud ; un filet de
lumière tombe sur le lingot d'or noir du lit. (Le four du Néant a une sphère blanche dans une armille : ici, la sphère est
noire, tenue par des griffes, dans un portique.)
Palette 60/30/10 (ages.PALETTE[15]) : noir chaud / or chauffé / lumière incandescente blanc-or.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import formes as F
from corps import B, halo
from kit import SQ2, TAU

V = Vector

EPOQUE = 15
NOM = ages.NOMS[15]
TRIPLET = ("sphère noire", "serres dorées", "couronne incandescente")
FOYER = ages.FOYER[15]
TRAVAIL = dict(couches=2, images=32, organe="couronne qui tourne autour de la sphère (32 images) et serres qui se "
                                           "resserrent d'un cran ; filet de lumière qui pulse (couche glow)")
HABILLAGE = dict(ages.CORPS[15], plan='portique', forme_embase='gradins', forme_dos='bas', forme_joues='socle',
                 forme_portique='aucun')
DENSITE = dict(p=0.55, lampes=0.06)
INCLINAISON = math.radians(22.0)


def matieres(metal, M):
    ages.matieres(15, metal, M)


def _serre(g, p0, p_mid, p_tip, r0, mat, M):
    P = g.spline([p0, p_mid, p_tip], 8)
    radii = [r0 * (1 - 0.8 * i / (len(P) - 1)) + 0.012 for i in range(len(P))]
    g.tube(P, r0, mat, n=10, radii=radii, what="serre")
    g.sphere(p_mid, r0 * 1.05, M["or_chauffe"], n=14, m=7, what="phalange")


def socle(g, c):
    """Arêtes d'or et joints incandescents des pylônes, couronne d'or du pont, évents du dos bas."""
    M = g.M
    y0 = c.yt - c.dp / 2.0
    for sx in (-1, 1):
        x = sx * c.xp
        for xx in (x - c.wp / 2 + 0.02, x + c.wp / 2 - 0.02):
            g.box(B(xx, y0 - 0.03, (c.ze + c.ztop) / 2), (0.04, 0.03, c.ztop - c.ze), M["or_chauffe"], "hard",
                  what="arete_or")
        for k in range(4):
            g.box(B(x, y0 - 0.035, c.ze + 0.4 + 0.45 * k), (c.wp * 0.6, 0.02, 0.025), M["emit2"], "flat",
                  what="joint_feu")
        g.dome(B(x, y0 - 0.03, c.ztop - 0.15), (0, -1, 0), 0.05, M["or_rivet"])
    halo(g, 0, y0 - 0.2, c.ze + 1.0, 0.8)
    # couronne d'or sur le pont : fleurons
    for k in range(9):
        x = -1.8 + 0.45 * k
        g.cyl(B(x, c.yt, c.ztop + 0.08), "z", 0.05, 0.16, M["or_vif"], n=8, r2=0.01, what="fleuron")
    g.box(B(0, c.yt, c.ztop + 0.01), (4.0, 0.12 * SQ2, 0.03), M["or_chauffe"], "hard", what="bandeau_or")
    # évents incandescents du dos bas
    for x in (-1.8, -0.9, 0.9, 1.8):
        g.cyl(B(x, (c.yb + c.h) / 2, c.z_bas + 0.04), "z", 0.13, 0.08, M["cendre"], n=16, what="event")
        g.cyl(B(x, (c.yb + c.h) / 2, c.z_bas + 0.085), "z", 0.09, 0.012, M["emit2"], n=16, what="event_feu")
        c.reserves.append((x, (c.yb + c.h) / 2, 0.18))


def outil(g, c):
    """Sphère noire entre les pylônes, couronne mince, trois serres dorées."""
    M = g.M
    r = 0.42
    zc = c.zt + 0.62
    ctr = B(0, c.yt, zc)
    g.sphere(ctr, r, M["horizon"], n=40, m=20, what="sphere_noire")
    ax = Matrix.Rotation(INCLINAISON, 3, "X") @ V((0, 0, 1))
    g.torus(ctr, ax, r + 0.16, 0.025, M["emit"], n=64, m=8, what="couronne")
    g.torus(ctr, ax, r + 0.26, 0.015, M["or_blanc_chaud"], n=64, m=6, what="couronne_or")
    g.torus(ctr, ax, r + 0.08, 0.012, M["emit2"], n=48, m=6, what="couronne_orange")
    halo(g, 0, c.yt, zc, 1.6)
    xi = c.xp - c.wp / 2.0
    for sx in (-1, 1):
        p0 = B(sx * xi, c.yt, zc + 0.1)
        _serre(g, p0, B(sx * (r + 0.55), c.yt - 0.12, zc + 0.45), ctr + V((sx * r * 0.55, -0.1, r * 0.7)), 0.08,
               M["or_vif"], M)
        g.box(p0, (0.2, 0.3 * SQ2, 0.26), M["noir_chaud2"], "hard", what="poing")
    _serre(g, B(0.0, c.yt, c.zp), B(0.25, c.yt - 0.2, c.zp - 0.05), ctr + V((0.0, -r * 0.6, r * 0.75)), 0.07,
           M["or_vif"], M)


def ouvrage(g, c):
    """Lingot d'or noir sur un socle, filet de lumière qui tombe de la sphère."""
    M = g.M
    yt, zt = c.yt, c.zt
    g.cyl(B(0, yt, zt + 0.05), "z", 0.32, 0.1, M["noir_profond"], n=8, style="hard", what="socle")
    g.box(B(0, yt, zt + 0.15), (0.32, 0.17 * SQ2, 0.1), M["or_chauffe"], "hard", what="lingot")
    g.box(B(0, yt, zt + 0.205), (0.24, 0.1 * SQ2, 0.012), M["or_blanc_chaud"], "flat", what="arete")
    g.cyl(B(0, yt, zt + 0.2 + 0.1), "z", 0.012, 0.2, M["emit"], n=8, what="filet")


def entree(g, c, p):
    """Creuset de noir profond plein de matière exotique (éclats d'or) (entrée)."""
    M = g.M
    g.cyl(B(p["x"], p["yn"], p["z"] + 0.1), "z", p["r"] * 0.8, 0.2, M["noir_profond"], n=8, r2=p["r"], style="hard",
          what="creuset")
    for k in range(7):
        F.lump(g, B(p["x"] - 0.12 + 0.04 * k, p["yn"] + 0.02 * (k % 2), p["z"] + 0.2), 0.04,
               M["or_vif"] if k % 3 == 0 else M["noir_chaud2"])


def sortie(g, c, p):
    """Écrin de noir chaud à liseré d'or : lingots d'or noir (sortie)."""
    M = g.M
    corps.bac(g, c, p, M["noir_chaud"], M["or_chauffe"], forme="lingot")
    g.box(B(p["x"], p["yn"] - p["r"] * 0.85, p["z"] + 0.14), (2 * p["r"], 0.02, 0.02), M["or_vif"], "hard",
          what="liseré")


def piece(g, c):
    """Niveau 30 (plus grand) : deux reliquaires hauts : socle noir à marches, singularité en cage d'or sur un fût
    (coins avant, en retrait du perron)."""
    M = g.M
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.22, c.ze
        g.box(B(x, yn, z + 0.06), (0.7, 0.7 * SQ2, 0.12), M["noir_chaud"], "hard", what="marche")
        g.box(B(x, yn, z + 0.17), (0.5, 0.5 * SQ2, 0.1), M["noir_chaud2"], "hard", what="marche")
        g.cyl(B(x, yn, z + 0.45), "z", 0.07, 0.45, M["noir_profond"], n=10, what="fut")
        g.sphere(B(x, yn, z + 0.86), 0.15, M["horizon"], n=20, m=10, what="singularite")
        g.torus(B(x, yn, z + 0.86), (0, 0.4, 1), 0.22, 0.014, M["emit"], n=32, m=6, what="anneau_feu")
        for k in range(4):
            a = TAU * k / 4 + 0.785
            g.tube([B(x + 0.06 * math.cos(a), yn + 0.06 * math.sin(a), z + 0.68),
                    B(x + 0.24 * math.cos(a), yn + 0.2 * math.sin(a), z + 0.86),
                    B(x + 0.07 * math.cos(a), yn + 0.06 * math.sin(a), z + 1.06)], 0.02, M["or_vif"], n=6,
                   what="cage")
        halo(g, x, yn, z + 0.86, 0.7)
