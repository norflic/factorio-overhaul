"""Laser · Âge 12 · Supraconducteurs (ère IV, 5×5, niveaux 23 et 24). Lot F1-B (25/10) ; fiche :
fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 12 (fait foi). S'exécute DANS Blender.

En 3 mots : « arceaux chromés, givre, lévitation ». L'affût est fait de 3 gradins HEXAGONAUX qui « lévitent » sur des
INTERSTICES LUMINEUX cyan (fermés : bande en retrait et entretoises, aucun vide), dalles noir miroir, conduites givrées
cerclées de chrome, plaques de givre, voyants cyan ; 16 BOBINES SUPRACONDUCTRICES (anneaux chromés empilés sur un cœur
givré) ; CRYOSTATS aux coins arrière. L'émetteur est un CŒUR GIVRÉ pris dans DEUX ARCEAUX CHROMÉS CROISÉS (gyroscope :
l'un dans l'axe, l'autre incliné) ; à l'avant, la lentille noire miroir « lévite » sur un anneau de lumière cyan ;
étrier givré ; cryostat derrière.
Palette 60/30/10 (ages.PALETTE[12]) : blanc glacé teinté cyan / noir miroir et chrome / cyan lumineux.
"""
import math

from mathutils import Matrix, Vector

import ages
import corps
import epoques as E_
import formes as F
import orne as O
import parts as PT
import parts3 as P3
from kit import SQ2, TAU
from repere import Y, at

V = Vector

EPOQUE = 12
NOM = ages.NOMS[12]
TRIPLET = ("arceaux chromés", "givre", "lévitation")
FOYER = ages.FOYER[12]
FAISCEAU = dict(rgb=(0.29, 0.94, 1.0), forme="trait droit cyan glacé, cristaux de givre à l'impact", largeur=0.8)
HABILLAGE = dict(ages.CORPS[12], **E_.MAQUETTES[12])


def matieres(metal, M):
    ages.matieres(12, metal, M)


def liaison(g, pts, r):
    """Conduite givrée (mousse blanche) cerclée de chrome."""
    M = g.M
    P = g.tube(g.spline(pts, 8), r, M["pipe"], n=10, what="conduite_givree")[0]
    for i in range(1, len(P) - 1, 3):
        a = (P[min(len(P) - 1, i + 1)] - P[i - 1]).normalized()
        g.cyl(P[i], a, r * 1.2, r * 0.5, M["chrome_mat"], n=10, style="hard", what="collier")


def condensateur(g, c, x, y, z, r, h):
    """Bobine supraconductrice : cœur givré, anneaux chromés horizontaux empilés, chapeau noir miroir, couronne cyan."""
    M = g.M
    g.cyl((x, y, z + h * 0.45), "z", r * 0.6, h * 0.9, M["frost"], n=16, what="coeur")
    for k in range(4):
        g.torus((x, y, z + h * (0.14 + 0.2 * k)), "z", r * 0.8, r * 0.22, M["chrome_mat"], n=20, m=8, what="anneau")
    g.cyl((x, y, z + h * 0.93), "z", r * 0.85, 0.04, M["noir_miroir"], n=16, style="hard", what="chapeau")
    g.tube_shell((x, y, z + h * 0.96), "z", r * 0.6, r * 0.4, 0.014, M["emit_soft"], n=16, what="couronne_lum")
    F.lump(g, (x - r * 0.3, y - r * 0.5, z + h * 0.5), r * 0.32, M["trim"], sz=0.5, jit=0.3)


def _givre(g, k, h):
    """Plaque de givre et petit voyant cyan sur le flanc."""
    M = g.M
    F.lump(g, (0, -h * 0.1, 0.0), 0.09, M["trim"], sz=0.25, jit=0.35)
    O.lampe(g, (0.1, h * 0.15, 0.0), (0, 0, 1), 0.02, M["emit"], M["noir_miroir"])


def _dewar(g, k, w):
    """Petit vase de Dewar givré à couvercle chromé, ou vanne chromée (dessus des gradins)."""
    M = g.M
    if k % 2 == 0:
        g.cyl((0, 0, 0.08), "z", 0.06, 0.16, M["frost"], n=14, style="soft", what="dewar")
        g.cyl((0, 0, 0.165), "z", 0.065, 0.02, M["chrome_mat"], n=14, style="hard", what="couvercle")
        g.tube_shell((0, 0, 0.06), "z", 0.064, 0.05, 0.016, M["chrome_mat"], n=14, what="cerclage")
    else:
        g.cyl((0, 0, 0.03), "x", 0.03, 0.16, M["pipe"], n=10, what="conduite")
        g.cyl((0, 0, 0.07), "z", 0.012, 0.06, M["chrome_mat"], n=6, what="tige")
        g.torus((0, 0, 0.1), "z", 0.035, 0.01, M["chrome_mat"], n=12, m=4, what="volant")


def _cryostat(g, x, y, r, h, M):
    """Cryostat : cuve givrée, couvercle chromé boulonné, fenêtre de niveau cyan, conduite, givre."""
    g.cyl((x, y, 0.03), "z", r + 0.05, 0.06, M["noir_miroir"], n=24, style="soft", what="socle")
    g.cyl((x, y, 0.06 + h / 2), "z", r, h, M["frost"], n=24, style="soft", what="cuve")
    for f in (0.2, 0.75):
        g.tube_shell((x, y, 0.06 + h * f), "z", r + 0.014, r - 0.01, 0.035, M["chrome_mat"], n=24, what="cerclage")
    g.cyl((x, y, 0.06 + h + 0.03), "z", r * 1.06, 0.06, M["chrome_mat"], n=24, style="hard", what="couvercle")
    F.bolts_ring(g, (x, y, 0.06 + h + 0.061), (0, 0, 1), r * 0.92, 10, M["noir_miroir"], r=0.014)
    g.cyl((x, y, 0.06 + h + 0.09), "z", r * 0.4, 0.05, M["noir_miroir"], n=16, r2=r * 0.25, what="tete")
    g.box((x, y - r - 0.005, 0.06 + h * 0.48), (0.05, 0.012, h * 0.4), M["emit"], "flat", what="niveau")
    F.lump(g, (x + r * 0.5, y - r * 0.7, 0.06 + h * 0.3), r * 0.35, M["trim"], sz=0.45)


def socle(g, c):
    """Conduites givrées cerclées de chrome, plaques de givre et voyants cyan, vases de Dewar et vannes, cryostats aux
    coins arrière, conduites vers le pivot."""
    M = g.M
    zp = c.gradins[-1][3]
    O.ceinture(g, c, 0, 0.55, 0.022, M["pipe"], colliers=M["chrome_mat"], pas=0.4)
    O.ceinture(g, c, 1, 0.55, 0.018, M["pipe"], colliers=M["chrome_mat"], pas=0.35)
    sommets = [math.pi / 6 + TAU * k / 6 for k in range(6)]
    O.sur_flanc(g, c, 0, [a + TAU / 12 for a in O.visibles(sommets, nord=0.6)], _givre, f=0.3, dr=0.004)
    O.sur_flanc(g, c, 2, [math.radians(a) for a in (210, 270, 330)], _givre, f=0.45, dr=0.004)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (195, 225, 255, 285, 315, 345)], _dewar)
    O.sur_dessus(g, c, 2, [math.radians(a) for a in (220, 270, 320)], _dewar, t=0.55)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, y = p["x"] - sx * 0.04, Y(p["yn"] - 0.04)
        _cryostat(g, x, y, 0.3, 0.62, M)
        liaison(g, [(x - sx * 0.25, y - 0.2, 0.4), (x * 0.66, Y(p["yn"] * 0.62), c.gradins[0][3] + 0.1),
                    (x * 0.42, Y(p["yn"] * 0.4), zp + 0.05)], 0.04)
        g.halo((x, y - 0.4, 0.4), M["_emit_rgb"], 5.0)
    for (x, yn) in ((0.0, -2.2), (-1.8, -0.9), (1.8, -0.9)):
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 5.0)


def piece(g, c):
    """Niveau 24 : deux CRYOSTATS (vases de Dewar) aux coins avant, patin de dalles noir miroir relié au premier
    gradin."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.14, yn + 0.14, 0.95, 0.95, rz=sx * 0.785)
        g.push((0, 0, 0.035))
        _cryostat(g, x, Y(yn), 0.26, 0.55, M)
        g.pop()
        g.halo((x, Y(yn - 0.4), 0.4), M["_emit_rgb"], 5.0)


def arriere(g, c):
    """CRYOSTAT bas : deux vases givrés couchés côte à côte, couvercles chromés, conduite givrée."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    yc = (y0 + y1) / 2
    g.box((0, yc, zb + 0.03), (2 * bx, y1 - y0, 0.06), M["noir_miroir"], "hard", what="semelle")
    r = min(bx * 0.48, (z1 - zb) * 0.3)
    for sx in (-1, 1):
        g.cyl((sx * bx * 0.5, yc, zb + 0.06 + r), "y", r, (y1 - y0) * 0.9, M["frost"], n=20, style="soft",
              what="vase")
        g.cyl((sx * bx * 0.5, y0 + 0.02, zb + 0.06 + r), "y", r * 1.06, 0.04, M["chrome_mat"], n=20, style="hard",
              what="couvercle")
        g.tube_shell((sx * bx * 0.5, yc, zb + 0.06 + r), "y", r + 0.012, r - 0.01, 0.03, M["chrome_mat"], n=20,
                     what="cerclage")
    g.cyl((0, yc, zb + 0.06 + 2 * r + 0.02), "y", 0.03, (y1 - y0) * 0.8, M["pipe"], n=10, what="conduite")


def tete(g, c):
    """Petits vases givrés et vannes chromées à l'arrière de la platine ; givre sur les joues."""
    M = g.M
    zb = O.zb(c)
    for (x, y, w) in O.pods(c):
        g.cyl((x, y, zb + w), "z", w * 0.8, w * 2.0, M["frost"], n=14, style="soft", what="vase")
        g.cyl((x, y, zb + w * 2.05), "z", w * 0.85, 0.03, M["chrome_mat"], n=14, style="hard", what="couvercle")
    t = c.T["tete"]
    for sx in (-1, 1):
        F.lump(g, (sx * (t["xc"] + t["tc"]), -0.2 * t["re"], c.zh + 0.35 * t["re"]), 0.07 * t["re"] + 0.03, M["trim"],
               sz=0.5)


def emetteur(g, c):
    """CŒUR GIVRÉ dans DEUX ARCEAUX CHROMÉS CROISÉS (l'un dans le plan de l'axe, l'autre incliné ; ils serrent le cœur :
    aucun jour), LENTILLE NOIRE MIROIR qui « lévite » à l'avant sur un anneau de lumière cyan, givre sur les arceaux."""
    M = g.M
    re, zh = c.re, c.zh
    rc = 0.62 * re
    g.sphere((0, 0, zh), rc, M["frost"], n=32, m=16, what="coeur")
    for (ax, k) in (((1.0, 0.0, 0.0), 0), ((0.0, 0.55, 0.83), 1)):
        g.torus((0, 0, zh), ax, 0.66 * re, 0.075 * re, M["chrome_mat"], n=48, m=10, what="arceau")
        g.torus((0, 0, zh), ax, 0.66 * re + 0.07 * re, 0.012, M["ring"], n=48, m=4, what="filet")
    g.torus((0, 0, zh), (0.0, 0.0, 1.0), 0.64 * re, 0.05 * re, M["noir_miroir"], n=48, m=8, what="equateur")
    for k in range(5):
        a = TAU * k / 5 + 0.3
        F.lump(g, (0.66 * re * math.cos(a) * 0.0 + 0.0, 0.66 * re * math.cos(a), zh + 0.66 * re * math.sin(a)),
               0.06 * re, M["trim"], sz=0.6)
    # lévitation : collerette, anneau de lumière cyan, lentille noire miroir
    g.cyl((0, 0.55 * re, zh), "y", 0.36 * re, 0.2 * re, M["noir_miroir"], n=28, style="soft", what="collerette")
    g.cyl((0, 0.67 * re, zh), "y", 0.4 * re, 0.04 * re, M["emit"], n=28, style="flat", what="levitation")
    g.cyl((0, 0.72 * re, zh), "y", 0.44 * re, 0.06 * re, M["noir_miroir2"], n=32, style="soft", what="lentille_miroir")
    F.lit_ring(g, (0, 0.76 * re, zh), "y", 0.3 * re, M["emit_soft"], w=0.03)
    for k in range(4):
        a = TAU * k / 4 + math.pi / 4
        d = V((math.cos(a), 0, math.sin(a)))
        g.box(V((0, 0.66 * re, zh)) + d * 0.42 * re, (0.03, 0.14 * re, 0.03), M["chrome_mat"], "hard",
              what="entretoise")
