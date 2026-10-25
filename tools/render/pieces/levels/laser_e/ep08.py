"""Laser · Âge 8 · Marais (ère III, 4×4, niveaux 15 et 16). Lot F1-B (25/10) ; fiche : fo-logs/2026-10-24_F1/FICHES_LASER.md,
âge 8 (fait foi). S'exécute DANS Blender.

En 3 mots : « ampoule, liquide jaune, pilotis ». L'affût est un PONTON : plateau rond de planches, large et bas, et un
petit tambour, ceints de PILOTIS ; bittes d'amarrage et cordages, caisses, tonneaux et filets sur le plateau, lanternes
jaunes ; 12 BONBONNES de verre jaune toxique cerclées de cuivre terni ; cuves de lixiviation sphériques sur trépied aux
coins arrière ; durites noires. L'émetteur est une AMPOULE de verre pleine d'un LIQUIDE JAUNE-VERT (ménisque lumineux,
bulles), culot de cuivre terni, bec court qui porte la lentille ; étrier vert-de-gris ; alambic derrière.
Palette 60/30/10 (ages.PALETTE[8]) : vert-de-gris / bois mouillé et cuivre terni / jaune toxique.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import epoques as E_
import formes as F
import orne as O
import parts as PT
from kit import SQ2, TAU
from repere import Y, at

V = Vector

EPOQUE = 8
NOM = ages.NOMS[8]
TRIPLET = ("ampoule", "liquide jaune", "pilotis")
FOYER = ages.FOYER[8]
FAISCEAU = dict(rgb=(0.6, 1.0, 0.04), forme="jet ondulant jaune-vert, gouttes d'acide qui tombent", largeur=1.1)
HABILLAGE = dict(ages.CORPS[8], **E_.MAQUETTES[8])


def matieres(metal, M):
    ages.matieres(8, metal, M)
    metal("corde", (0.3, 0.24, 0.14), rough=0.85, met=0.0, grain=0.5, gscale=50.0, dirt=0.6, stain=0.4)


def liaison(g, pts, r):
    """Durite de caoutchouc annelé noir."""
    g.hose(pts, r, g.M["rubber"], step=0.035, n=10, what="durite")


def _bonbonne(g, x, y, z, r, h, M):
    """Bonbonne de verre jaune toxique : panse, col, bouchon, cerclage de cuivre terni, bulle lumineuse."""
    g.sphere((x, y, z + r * 0.95), r, M["verre_toxique"], n=16, m=10, scale=(1.0, 1.0, h / (2 * r)), what="panse")
    g.tube_shell((x, y, z + r * 0.95), "z", r * 1.03, r * 0.9, 0.025, M["cuivre_terni"], n=16, what="cerclage")
    zt = z + r * 0.95 + h / 2
    g.cyl((x, y, zt + 0.02), "z", r * 0.3, 0.06, M["verre_toxique"], n=10, what="col")
    g.cyl((x, y, zt + 0.06), "z", r * 0.34, 0.03, M["wood"], n=10, what="bouchon")
    g.sphere((x - r * 0.35, y - r * 0.5, z + r * 1.2), r * 0.16, M["emit"], n=8, m=5, what="bulle")
    g.box((x - r * 0.55, y - r * 0.62, z + r * 0.9), (0.012, 0.01, h * 0.5), M["reflet_verre"], "flat", what="reflet")


def condensateur(g, c, x, y, z, r, h):
    """Bonbonne de verre jaune toxique sur un socle de cuivre terni."""
    M = g.M
    g.cyl((x, y, z + 0.02), "z", r * 0.9, 0.04, M["cuivre_terni"], n=14, style="soft", what="socle")
    _bonbonne(g, x, y, z + 0.04, r * 0.95, h * 0.72, M)


def _bitte(g, k, w):
    """Bitte d'amarrage et cordage lové (dessus du plateau)."""
    M = g.M
    if k % 2 == 0:
        g.cyl((0, 0, 0.06), "z", 0.04, 0.12, M["bois_mouille"], n=10, style="soft", what="bitte")
        g.cyl((0, 0, 0.125), "z", 0.05, 0.02, M["cuivre_terni"], n=10, what="chapeau")
        g.torus((0.0, 0.0, 0.03), "z", 0.07, 0.02, M["corde"], n=14, m=6, what="cordage")
    else:
        F.stave_barrel(g, (0, 0, 0.0), 0.06, 0.12, M["bois_mouille"], M["cuivre_terni"], open_top=M["verre_toxique"])


def _caisse(g, k, w):
    """Caisses de planches, filets, lanterne jaune (dessus du second gradin)."""
    M = g.M
    if k % 3 == 0:
        g.box((0, 0, 0.05), (0.1, 0.12, 0.1), M["bois_mousse"], "hard", what="caisse")
        g.box((0, 0, 0.1), (0.104, 0.02, 0.008), M["cuivre_terni"], "hard", what="feuillard")
    elif k % 3 == 1:
        g.cyl((0, 0, 0.05), "z", 0.012, 0.1, M["bois_mouille"], n=6, what="poteau")
        g.cyl((0, 0, 0.11), "z", 0.025, 0.035, M["emit"], n=8, what="lanterne")
        g.cyl((0, 0, 0.133), "z", 0.03, 0.012, M["cuivre_terni"], n=8, what="toit")
    else:
        g.sphere((0, 0, 0.02), 0.07, M["corde"], n=12, m=6, scale=(1.0, 1.3, 0.4), what="filet")


def _mousse(g, k, h):
    """Plaque de vert-de-gris et cordage cloué sur le flanc."""
    M = g.M
    g.box((0, 0, 0.004), (0.18, h * 0.5, 0.008), M["vdg_capot"], "flat", what="plaque")
    for s in (-1, 1):
        g.bolt((s * 0.07, 0, 0.01), (0, 0, 1), 0.012, M["cuivre_terni"])


def _cuve_lixiviation(g, x, y, r, M):
    """Cuve sphérique de verre jaune sur trépied vert-de-gris, cerclage, bulles, tubulure."""
    for k in range(3):
        a = TAU * k / 3 + 0.5
        d = V((math.cos(a), math.sin(a), 0))
        g.box(V((x, y, 0.16)) + d * r * 0.62, (0.04, 0.04, 0.34), M["vdg_capot"], "hard",
              R=Matrix.Rotation(0.22, 3, V((-d.y, d.x, 0))), what="pied")
    g.sphere((x, y, 0.3 + r * 0.8), r, M["verre_toxique"], n=24, m=12, what="cuve")
    g.tube_shell((x, y, 0.3 + r * 0.8), "z", r * 1.03, r * 0.9, 0.035, M["cuivre_terni"], n=24, what="cerclage")
    g.torus((x, y, 0.3 + r * 0.8 + r * 0.45), "z", r * 0.88, 0.012, M["emit_soft"], n=24, m=4, what="menisque")
    for j in range(4):
        g.sphere((x + r * 0.45 * math.cos(j * 1.3), y - r * 0.6, 0.3 + r * (0.6 + 0.2 * j)), r * 0.09, M["emit"],
                 n=8, m=5, what="bulle")
    g.cyl((x, y, 0.3 + r * 1.85), "z", r * 0.25, 0.08, M["cuivre_terni"], n=10, what="col")


def socle(g, c):
    """Plaques de vert-de-gris et cordes sur le flanc des planches, bittes d'amarrage, tonneaux, caisses, lanternes,
    cuves de lixiviation (coins arrière), durites."""
    M = g.M
    zp = c.gradins[-1][3]
    O.ceinture(g, c, 0, 0.72, 0.016, M["corde"], colliers=M["cuivre_terni"], pas=0.4)
    O.ceinture(g, c, 1, 0.55, 0.014, M["corde"])
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (200, 240, 300, 340)], _mousse, f=0.38, dr=0.004)
    O.sur_dessus(g, c, 0, O.visibles(O.entre_condensateurs(c), nord=0.45), _bitte, t=0.5)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (190, 220, 250, 290, 320, 350)], _caisse)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, y = p["x"] - sx * 0.04, Y(p["yn"] - 0.04)
        _cuve_lixiviation(g, x, y, 0.27, M)
        liaison(g, [(x - sx * 0.1, y - 0.25, 0.35), (x * 0.66, Y(p["yn"] * 0.62), c.gradins[0][3] + 0.12),
                    (x * 0.42, Y(p["yn"] * 0.4), zp + 0.06)], 0.035)
        g.halo((x, y - 0.3, 0.4), M["_emit_rgb"], 5.0)
    for (x, yn) in ((0.0, -1.85), (-1.45, -0.6), (1.45, -0.6)):
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 4.0)


def piece(g, c):
    """Niveau 16 : deux BONBONNES dans des paniers d'osier aux coins avant, sur un patin de planches relié au plateau."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.12, yn + 0.12, 0.8, 0.8, rz=sx * 0.785)
        with at(g, x, yn, z=0.035):
            g.cyl((0, 0, 0.12), "z", 0.27, 0.24, M["wicker"], n=20, r2=0.3, style="soft", what="panier")
            for f in (0.06, 0.2):
                g.tube_shell((0, 0, f), "z", 0.29, 0.25, 0.025, M["bois_mouille"], n=20, what="cercle")
            _bonbonne(g, 0.0, 0.0, 0.08, 0.24, 0.5, M)
            g.torus((0, 0, 0.55), "z", 0.1, 0.018, M["wicker"], n=14, m=5, what="anse")
        g.halo((x, Y(yn - 0.3), 0.4), M["_emit_rgb"], 5.0)


def arriere(g, c):
    """ALAMBIC bas : cuve de cuivre terni, col de cygne court courbé vers l'arrière, serpentin."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    yc = (y0 + y1) / 2
    hz = z1 - zb
    g.cyl((0, yc, zb + 0.03), "z", bx * 0.95, 0.06, M["vdg_capot"], n=20, style="soft", what="foyer")
    g.sphere((0, yc, zb + hz * 0.45), bx * 0.85, M["cuivre_terni"], n=24, m=12, scale=(1.0, 0.8, hz * 0.5 / (bx * 0.85)),
             what="cuve")
    g.tube_shell((0, yc, zb + hz * 0.45), "z", bx * 0.88, bx * 0.7, 0.03, M["vdg_capot"], n=24, what="cerclage")
    g.tube([V((0, yc, zb + hz * 0.85)), V((0, yc - 0.06, zb + hz * 0.98)), V((0, y0 - 0.02, zb + hz * 0.8)),
            V((0, y0 - 0.05, zb + hz * 0.45))], 0.03, M["cuivre_terni"], n=10, what="col_de_cygne")
    for k in range(3):
        g.torus((0, y0 - 0.05, zb + 0.08 + k * 0.06), "z", 0.06, 0.012, M["cuivre_terni"], n=14, m=5, what="serpentin")


def tete(g, c):
    """Petites fioles de verre jaune et réchaud à l'arrière de la platine."""
    M = g.M
    zb = O.zb(c)
    (xl, yl, wl), (xr, yr, wr) = O.pods(c)
    _bonbonne(g, xl, yl, zb, wl * 0.9, wl * 2.2, M)
    g.box((xr, yr, zb + 0.04), (wr * 2, wr * 1.6, 0.08), M["bois_mousse"], "hard", what="caisse")
    g.cyl((xr, yr, zb + 0.09), "z", wr * 0.5, 0.02, M["emit"], n=8, what="rechaud")


def emetteur(g, c):
    """AMPOULE de verre jaune-vert (sphère étirée dans l'axe), ménisque lumineux, BULLES, reflets, culot de cuivre terni
    à l'arrière, bec court à l'avant qui porte la lentille, cerclages de cuivre."""
    M = g.M
    re, zh = c.re, c.zh
    ra = 0.8 * re
    yc = 0.08 * re
    g.sphere((0, yc, zh), ra, M["verre_toxique"], n=36, m=18, scale=(1.0, 1.1, 1.0), what="ampoule")
    # ménisque (surface du liquide) : anneau lumineux à 0,35 ra au-dessus de l'axe, juste hors du verre
    zm = 0.35 * ra
    rm = math.sqrt(ra * ra - zm * zm)
    g.push((0, yc, zh + zm))
    g.push((0, 0, 0))
    g.torus((0, 0, 0), "z", rm * 1.0, 0.016, M["emit_soft"], n=40, m=4, what="menisque")
    g.pop()
    g.pop()
    # bulles qui montent (sur la face vue)
    for k, (bx, by, bz, br) in enumerate(((-0.4, -0.2, 0.55, 0.07), (-0.15, -0.55, 0.62, 0.05), (0.3, -0.5, 0.5, 0.06),
                                          (0.55, -0.1, 0.62, 0.045), (0.1, 0.1, 0.92, 0.05), (-0.55, 0.3, 0.6, 0.04))):
        d = V((bx, by * 1.1, bz)).normalized()
        g.sphere(V((0, yc, zh)) + V((d.x * ra, d.y * ra * 1.1, d.z * ra)) * 0.99, br * re, M["emit"], n=8, m=5,
                 what="bulle")
    # reflets du verre
    g.torus((-0.5 * ra, yc, zh), (1, 0, 0), 0.868 * ra, 0.009, M["reflet_verre"], n=40, m=4, what="reflet")
    # cerclages de cuivre terni
    for yy in (-0.35 * re, 0.5 * re):
        rr = ra * math.sqrt(max(0.0, 1 - ((yy - yc) / (1.1 * ra)) ** 2))
        g.tube_shell((0, yy, zh), "y", rr + 0.02, rr - 0.03, 0.04, M["cuivre_terni"], n=36, what="cerclage")
    # culot de cuivre terni (arrière)
    g.cyl((0, -0.74 * re, zh), "y", 0.42 * re, 0.14 * re, M["cuivre_terni"], n=24, style="soft", what="culot")
    for k in range(3):
        g.tube_shell((0, -0.7 * re + k * 0.04 * re, zh), "y", 0.45 * re, 0.35 * re, 0.015, M["vdg_capot"], n=24,
                     what="filet_culot")
    # bec court (avant) et lentille
    g.cyl((0, 0.98 * re, zh), "y", 0.26 * re, 0.22 * re, M["cuivre_terni"], n=20, r2=0.2 * re, style="soft", what="bec")
    corps.lentille(g, c, 1.1 * re, 0.17 * re, verre=M["verre_toxique"], cercle=M["cuivre_terni"])
