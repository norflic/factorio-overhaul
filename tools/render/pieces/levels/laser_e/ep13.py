"""Laser · Âge 13 · Antimatière (ère V cosmique, 6×6, niveaux 25 et 26). Lot F1-B (25/10) ; fiche :
fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 13 (fait foi). S'exécute DANS Blender.

En 3 mots : « bouteille magnétique, bobinages, point violet ». L'affût est un QUADRUPÔLE (l'aimant à 4 pôles qui confine
un faisceau) : 3 gradins chanfreinés à 4 LOBES en croix de Saint-André d'acier canon, liserés doux, BOBINAGES de cuivre
rouge qui ceignent les gradins, points violets enfermés, marques de danger, petits solénoïdes ; 16 SOLÉNOÏDES debout à
manchons de cuivre et fente au point violet ; BOUTEILLES MAGNÉTIQUES couchées sur berceaux aux coins arrière. L'émetteur
est une BOUTEILLE MAGNÉTIQUE : capsule courte d'acier canon (aussi longue que large) ceinte de 4 bobinages de cuivre, une
fente sur le dessus où brille un POINT VIOLET, lentille avant à cœur violet ; berceau ; piège de Penning derrière.
Palette 60/30/10 (ages.PALETTE[13]) : acier canon / cuivre rouge des bobinages / lueur d'annihilation violette (2/3) et
bleue (1/3), EN POINTS.
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

EPOQUE = 13
NOM = ages.NOMS[13]
TRIPLET = ("bouteille magnétique", "bobinages", "point violet")
FOYER = ages.FOYER[13]
FAISCEAU = dict(rgb=(0.561, 0.294, 1.0), rgb2=(0.29, 0.482, 1.0), forme="DOUBLE HÉLICE violet et bleu (annihilation), "
                "éclairs à l'impact", largeur=1.0)
HABILLAGE = dict(ages.CORPS[13], **E_.MAQUETTES[13])


def matieres(metal, M):
    ages.matieres(13, metal, M)


def _manchons(g, c0, axis, r, L, n, M, w=None):
    """n manchons de bobinage de cuivre (spires sombres) le long d'un axe."""
    a = V(axis).normalized()
    c0 = V(c0)
    w = w or L / (2.2 * n)
    for k in range(n):
        p = c0 + a * (-L / 2 + (k + 0.5) * L / n)
        g.tube_shell(p, a, r * 1.14, r * 0.9, w, M["cuivre_bobine"], n=24, what="manchon")
        g.tube_shell(p, a, r * 1.16, r * 1.1, w * 0.25, M["cuivre_plaque"], n=24, what="spire")


def liaison(g, pts, r):
    """Conduit solénoïde : tube d'acier canon à manchons de cuivre."""
    M = g.M
    P = g.tube(g.spline(pts, 8), r, M["acier_canon2"], n=10, what="conduit")[0]
    for i in range(1, len(P) - 1, 3):
        a = (P[min(len(P) - 1, i + 1)] - P[i - 1]).normalized()
        g.cyl(P[i], a, r * 1.3, r * 1.4, M["cuivre_bobine"], n=12, style="soft", what="manchon")


def condensateur(g, c, x, y, z, r, h):
    """Solénoïde debout : fût d'acier canon, trois manchons de cuivre, chapeau d'acier noir, fente au point violet
    tournée vers l'extérieur."""
    M = g.M
    g.cyl((x, y, z + h / 2), "z", r * 0.78, h, M["acier_canon"], n=18, style="soft", what="fut")
    _manchons(g, (x, y, z + h * 0.5), (0, 0, 1), r * 0.78, h * 0.8, 3, M)
    g.cyl((x, y, z + h + 0.02), "z", r * 0.86, 0.04, M["acier_noir"], n=18, style="hard", what="chapeau")
    d = V((x, y / SQ2, 0)).normalized()
    dd = V((d.x, d.y * SQ2, 0)).normalized()
    if d.y < 0.4:
        g.sphere(V((x, y, z + h * 0.5)) + dd * (r * 0.95), 0.028, M["emit"], n=8, m=5, what="point")
    g.cyl((x, y, z + h + 0.045), "z", r * 0.25, 0.012, M["emit2"], n=10, style="flat", what="point_haut")


def _point(g, k, h):
    """Point violet enfermé (hublot d'acier noir) et marque de danger sur le flanc."""
    M = g.M
    g.cyl((0, 0, 0.012), "z", 0.06, 0.024, M["acier_noir"], n=14, style="hard", what="hublot")
    g.sphere((0, 0, 0.026), 0.03, M["emit"] if k % 3 else M["emit2"], n=8, m=5, what="point")
    for j in range(4):
        g.box((0.12 + 0.03 * j, 0, 0.004), (0.016, h * 0.4, 0.008), M["cuivre_bobine"] if j % 2 else M["acier_noir"],
              "flat", R=Matrix.Rotation(0.5, 3, "Z"), what="danger")


def _solenoide(g, k, w):
    """Petit solénoïde couché sur le dessus d'un gradin."""
    M = g.M
    g.cyl((0, 0, 0.06), "y", 0.05, 0.2, M["acier_canon"], n=14, style="soft", what="solenoide")
    _manchons(g, (0, 0, 0.06), (0, 1, 0), 0.05, 0.16, 2, M)
    for s in (-1, 1):
        g.box((0, s * 0.08, 0.02), (0.12, 0.03, 0.04), M["acier_noir"], "hard", what="berceau")


def _bouteille(g, x, y, z, r, L, axis, M):
    """Bouteille magnétique couchée : capsule d'acier canon, bobinages, fente au point violet, berceaux."""
    a = V(axis).normalized()
    p = V((x, y, z))
    g.cyl(p, a, r, L, M["acier_canon"], n=28, style="soft", what="capsule")
    for s in (-1, 1):
        q = p + a * (s * L / 2)
        sc = (0.5, 1.0, 1.0) if abs(a.x) > 0.7 else (1.0, 0.5, 1.0)
        g.sphere(q, r, M["acier_canon2"], n=24, m=12, scale=sc, what="fond")
    _manchons(g, p, a, r, L * 0.9, 3, M)
    g.box(p + V((0, 0, r * 0.98)), (0.04 if abs(a.x) < 0.7 else L * 0.6, L * 0.6 if abs(a.x) < 0.7 else 0.04, 0.02),
          M["acier_noir"], "hard", what="fente")
    g.sphere(p + V((0, 0, r * 1.0)), 0.04, M["emit"], n=10, m=6, what="point")
    for s in (-0.3, 0.3):
        q = p + a * (s * L)
        g.box(V((q.x, q.y, z * 0.45)), (0.12 if abs(a.x) > 0.7 else r * 1.6, r * 1.6 if abs(a.x) > 0.7 else 0.12, z * 0.9),
              M["acier_noir"], "hard", what="berceau")


def socle(g, c):
    """Bobinages de cuivre qui ceignent les gradins, points violets enfermés, marques de danger, petits solénoïdes,
    bouteilles magnétiques couchées (coins arrière), conduits solénoïdes vers le pivot."""
    M = g.M
    zp = c.gradins[-1][3]
    for f in (0.32, 0.68):
        O.ceinture(g, c, 0, f, 0.03, M["cuivre_bobine"], colliers=M["acier_noir"], pas=0.5)
    O.ceinture(g, c, 1, 0.5, 0.028, M["cuivre_bobine"], colliers=M["acier_noir"], pas=0.45)
    O.ceinture(g, c, 2, 0.5, 0.024, M["cuivre_bobine"])
    vallees = [math.radians(a) for a in (180, 270, 360)]
    O.sur_flanc(g, c, 0, vallees + [math.radians(a) for a in (215, 325)], _point, f=0.5, dr=0.02)
    O.sur_flanc(g, c, 1, [math.radians(a) for a in (225, 315, 250, 290)], _point, f=0.5, dr=0.02)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (200, 240, 300, 340)], _solenoide)
    O.sur_dessus(g, c, 0, O.visibles(O.entre_condensateurs(c), nord=0.2), _solenoide, t=0.5)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, y = p["x"] - sx * 0.05, Y(p["yn"] - 0.05)
        _bouteille(g, x, y, 0.36, 0.3, 0.6, (1.0, 0.0, 0.0), M)
        liaison(g, [(x - sx * 0.35, y - 0.3, 0.3), (x * 0.66, Y(p["yn"] * 0.62), c.gradins[0][3] + 0.1),
                    (x * 0.42, Y(p["yn"] * 0.4), zp + 0.06)], 0.045)
        g.halo((x, y - 0.4, 0.4), M["_emit_rgb"], 5.0)
    for (x, yn) in ((0.0, -2.6), (-2.2, -1.0), (2.2, -1.0)):
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 5.0)


def piece(g, c):
    """Niveau 26 : deux PIÈGES DE CONFINEMENT debout (cylindre bobiné sur trépied, hublot au point violet, trèfle
    d'annihilation), patin de tôles d'acier canon relié au premier gradin."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.15, yn + 0.15, 1.1, 1.1, rz=sx * 0.785)
        with at(g, x, yn, z=0.035):
            for k in range(3):
                a = TAU * k / 3 + 0.5
                d = V((math.cos(a), math.sin(a), 0))
                g.box(d * 0.22 + V((0, 0, 0.12)), (0.05, 0.05, 0.26), M["acier_noir"], "hard",
                      R=Matrix.Rotation(0.3, 3, V((-d.y, d.x, 0))), what="pied")
            g.cyl((0, 0, 0.5), "z", 0.22, 0.56, M["acier_canon"], n=24, style="soft", what="piege")
            _manchons(g, (0, 0, 0.5), (0, 0, 1), 0.22, 0.5, 3, M)
            g.cyl((0, 0, 0.8), "z", 0.24, 0.05, M["acier_noir"], n=24, style="hard", what="chapeau")
            g.cyl((0, -0.215, 0.5), "y", 0.06, 0.03, M["acier_noir"], n=14, what="hublot")
            g.sphere((0, -0.235, 0.5), 0.035, M["emit"], n=8, m=5, what="point")
            F.trefoil(g, (0, 0, 0.83), (0, 0, 1), 0.14)
        g.halo((x, Y(yn - 0.4), 0.4), M["_emit_rgb"], 5.0)


def arriere(g, c):
    """PIÈGE DE PENNING : cube bas d'acier canon, bobines de cuivre sur ses faces, hublot au point violet."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    T = PT.hull(g, -bx, bx, y0, y1, zb, z1 - 0.08, ins=(0.04, 0.04, 0.0), panel=0.24,
                mats=[M["acier_canon"], M["acier_canon2"]], rivet_step=0.12)
    yc = (y0 + y1) / 2
    rr = min(bx, (y1 - y0) / 2) * 0.62
    g.torus((0, yc, z1 - 0.05), "z", rr, 0.05, M["cuivre_bobine"], n=28, m=8, what="bobine")
    g.torus((0, y0 - 0.02, (zb + z1) / 2), "y", rr * 0.8, 0.045, M["cuivre_bobine"], n=28, m=8, what="bobine")
    g.cyl((0, y0 - 0.03, (zb + z1) / 2), "y", rr * 0.55, 0.03, M["acier_noir"], n=20, what="fond")
    g.sphere((0, y0 - 0.05, (zb + z1) / 2), 0.035, M["emit"], n=8, m=5, what="point")
    g.cyl((0, yc, z1 - 0.04), "z", rr * 0.7, 0.03, M["acier_noir"], n=20, what="couvercle")


def tete(g, c):
    """Petits pièges de confinement couchés à l'arrière de la platine."""
    M = g.M
    zb = O.zb(c)
    for (x, y, w) in O.pods(c):
        g.cyl((x, y, zb + w * 0.8), "y", w * 0.7, w * 2.2, M["acier_canon"], n=16, style="soft", what="piege")
        _manchons(g, (x, y, zb + w * 0.8), (0, 1, 0), w * 0.7, w * 1.8, 2, M)
        g.sphere((x, y - w * 1.1, zb + w * 0.8), 0.025, M["emit"], n=8, m=5, what="point")


def emetteur(g, c):
    """BOUTEILLE MAGNÉTIQUE : capsule courte d'acier canon (fonds bombés), 4 BOBINAGES de cuivre, fente sur le dessus au
    POINT VIOLET, lentille avant à cœur violet ; brides boulonnées."""
    M = g.M
    re, zh = c.re, c.zh
    r = 0.66 * re
    yc = 0.08 * re
    L = 0.55 * re
    g.cyl((0, yc, zh), "y", r, L, M["acier_canon"], n=36, style="soft", what="capsule")
    for s in (-1, 1):
        g.sphere((0, yc + s * L / 2, zh), r, M["acier_canon2"], n=36, m=16, scale=(1.0, 0.62, 1.0), what="fond")
        F.bolts_ring(g, (0, yc + s * L / 2, zh), (0, s, 0), r * 0.98, 16, M["chrome_fin"], r=0.016)
    _manchons(g, (0, yc, zh), (0, 1, 0), r, L + 0.5 * r, 4, M, w=0.13 * re)
    # fente du dessus et point violet
    g.box((0, yc, zh + r * 1.13), (0.12 * re, L + 0.5 * r, 0.03), M["acier_noir"], "hard", what="fente")
    g.box((0, yc, zh + r * 1.15), (0.05 * re, L + 0.4 * r, 0.01), M["emit2"], "flat", what="lueur_fente")
    g.sphere((0, yc, zh + r * 1.16), 0.07 * re, M["emit"], n=12, m=6, what="point_violet")
    # lentille avant à cœur violet
    corps.lentille(g, c, yc + L / 2 + 0.62 * r - 0.02, 0.22 * re, verre=M["verre_fume"], cercle=M["acier_noir"])
