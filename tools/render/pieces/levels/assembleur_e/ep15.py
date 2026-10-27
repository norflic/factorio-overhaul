"""Assembleur · Âge 15 · Néant (ère V, 6×6, niveaux 29 et 30). Lot F3-A, rondes F3-A2 et F3-A3 ; fiche
FICHES_ASSEMBLEUR.md, âge 15. Dans Blender. Ronde F3-A3 : plan en U (la baie est le sol), sphère sur DISQUE D'OR en
contre-jour et liseré incandescent, serres épaissies, reliquaires du niveau pair plus hauts, garniture plus dense.

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
DENSITE = dict(p=0.75, lampes=0.06, pas=0.16)     # ronde F3-A3 : densité vers la mitrailleuse
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
    """Sphère noire entre les pylônes, couronne mince, trois serres dorées. Ronde F3-A3 (sphère illisible sur le corps
    noir) : la sphère se détache sur un DISQUE D'OR en contre-jour (face à la caméra, derrière elle) et un liseré
    incandescent qui suit son bord ; serres plus épaisses, griffes d'or vif ; la baie est le sol (plan en U)."""
    M = g.M
    r = 0.38
    zc = min(c.zt + 0.68, c.zp - r - 0.05)
    # essai rapide a4q : sous le pont, la sphère était à moitié CACHÉE par la face sud du pont (vue de trois quarts) :
    # elle flotte DEVANT le pont, au-dessus de l'avant de la table
    ys = sphere_y(c)
    ctr = B(0, ys, zc)
    g.sphere(ctr, r, M["horizon"], n=40, m=20, what="sphere_noire")
    vue = V((0.0, -1.0, 1.0)).normalized()          # vers la caméra (vue de trois quarts depuis le sud)
    # disque reculé de 0,6 le long de la vue : il passe DERRIÈRE le lingot de l'ouvrage (et entre dans la table)
    g.cyl(ctr - vue * 0.6, vue, r + 0.14, 0.025, M["or_vif"], n=48, what="disque_contre_jour")
    g.torus(ctr - vue * 0.58, vue, r + 0.15, 0.022, M["or_chauffe"], n=48, m=6, what="bord_disque")
    g.torus(ctr, vue, r + 0.015, 0.012, M["emit2"], n=48, m=6, what="liseré")
    ax = Matrix.Rotation(INCLINAISON, 3, "X") @ V((0, 0, 1))
    g.torus(ctr, ax, r + 0.16, 0.025, M["emit"], n=64, m=8, what="couronne")
    g.torus(ctr, ax, r + 0.26, 0.015, M["or_blanc_chaud"], n=64, m=6, what="couronne_or")
    halo(g, 0, ys, zc, 1.6)
    xi = c.xp - c.wp / 2.0
    for sx in (-1, 1):
        p0 = B(sx * xi, c.yt, zc + 0.1)
        tip = ctr + V((sx * r * 0.55, -0.1, r * 0.7))
        _serre(g, p0, B(sx * (r + 0.55), c.yt - 0.12, zc + 0.45), tip, 0.11, M["or_vif"], M)
        g.sphere(tip, 0.05, M["or_blanc_chaud"], n=10, m=5, what="griffe")
        g.box(p0, (0.24, 0.34 * SQ2, 0.3), M["noir_chaud2"], "hard", what="poing")
        g.box(p0 - V((0, 0.25, 0)), (0.2, 0.02, 0.06), M["or_vif"], "hard", what="bague_poing")
    tip = ctr + V((0.0, -r * 0.6, r * 0.75))
    _serre(g, B(0.0, c.yt, c.zp), B(0.25, c.yt - 0.2, c.zp - 0.05), tip, 0.09, M["or_vif"], M)
    g.sphere(tip, 0.045, M["or_blanc_chaud"], n=10, m=5, what="griffe")


def sphere_y(c):
    """yn de la sphère : devant la face sud du pont (largeur 0,13 s), rayon 0,38 et marge."""
    return c.yt - 0.065 * c.side - 0.46


def ouvrage(g, c):
    """Lingot d'or noir sur un socle, filet de lumière qui tombe de la sphère (sous elle, à l'avant de la table)."""
    M = g.M
    yt, zt = sphere_y(c) + 0.15, c.zt
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
    # ronde F3-A3 (niveau pair peu visible) : reliquaires plus HAUTS (1,5), singularité plus grosse sur disque d'or
    for nom in ("coin_SO", "coin_SE"):
        p = corps.place(c, nom)
        x, yn, z = p["x"], p["yn"] + 0.1, c.ze
        g.box(B(x, yn, z + 0.07), (0.9, 0.9 * SQ2, 0.14), M["noir_chaud"], "hard", what="marche")
        g.box(B(x, yn, z + 0.2), (0.66, 0.66 * SQ2, 0.12), M["noir_chaud2"], "hard", what="marche")
        g.box(B(x, yn - 0.335, z + 0.2), (0.6, 0.012, 0.03), M["or_vif"], "hard", what="filet_or")
        g.cyl(B(x, yn, z + 0.62), "z", 0.09, 0.72, M["noir_profond"], n=12, what="fut")
        for f in (0.35, 0.75):
            g.tube_shell(B(x, yn, z + 0.26 + 0.72 * f), "z", 0.11, 0.085, 0.04, M["or_vif"], n=12, what="bague")
        zs_ = z + 1.22
        vue = V((0.0, -1.0, 1.0)).normalized()
        g.cyl(B(x, yn, zs_) - vue * 0.3, vue, 0.3, 0.02, M["or_vif"], n=32, what="disque_or")
        g.sphere(B(x, yn, zs_), 0.21, M["horizon"], n=24, m=12, what="singularite")
        g.torus(B(x, yn, zs_), (0, 0.4, 1), 0.3, 0.016, M["emit"], n=32, m=6, what="anneau_feu")
        for k in range(4):
            a = TAU * k / 4 + 0.785
            g.tube([B(x + 0.08 * math.cos(a), yn + 0.08 * math.sin(a), zs_ - 0.26),
                    B(x + 0.3 * math.cos(a), yn + 0.26 * math.sin(a), zs_),
                    B(x + 0.09 * math.cos(a), yn + 0.08 * math.sin(a), zs_ + 0.27)], 0.024, M["or_vif"], n=6,
                   what="cage")
        halo(g, x, yn, zs_, 0.8)
