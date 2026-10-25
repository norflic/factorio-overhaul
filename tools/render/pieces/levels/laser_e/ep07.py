"""Laser · Âge 7 · Cristal (ère III, 4×4, niveaux 13 et 14). Lot F1-B (25/10) ; fiche : fo-logs/2026-10-24_F1/FICHES_LASER.md,
âge 7 (fait foi). S'exécute DANS Blender.

En 3 mots : « prisme de cristal, bronze, temple ». L'affût est un TEMPLE en ZIGGOURAT (4 degrés octogonaux en assises de
pierre claire, arêtes de bronze, ESCALIERS de pierre au sud, pilastres) ; 12 POINTES DE CRISTAL violet serties de bronze
sur le premier degré ; GÉODES ouvertes aux coins arrière ; guides d'onde de bronze à nœuds de cristal. L'émetteur est un
PRISME DE CRISTAL violet à 6 pans, couché dans l'axe, court et épais, pointe taillée vers l'avant (le cristal EST la
lentille), veines de lumière sur les pans du dessus, tenu par trois bandes de bronze à griffes ; berceau de bronze ;
reliquaire de bronze à petits cristaux derrière.
Palette 60/30/10 (ages.PALETTE[7]) : bronze patiné / pierre claire / violet des cristaux (le violet ne vit QUE dans
les cristaux).
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

EPOQUE = 7
NOM = ages.NOMS[7]
TRIPLET = ("prisme de cristal", "bronze", "temple")
FOYER = ages.FOYER[7]
FAISCEAU = dict(rgb=(0.69, 0.44, 1.0), forme="trait fin violet qui se décompose en arc-en-ciel au départ (prisme)",
                largeur=0.7)
HABILLAGE = dict(ages.CORPS[7], **E_.MAQUETTES[7])


def matieres(metal, M):
    ages.matieres(7, metal, M)
    # cristal violet plus clair que le « crystal » commun (il doit se lire VIOLET au zoom 1, pas noir)
    metal("cristal_v", (0.3, 0.16, 0.5), rough=0.1, met=0.1, grain=0.1, gscale=20.0, dirt=0.3, stain=0.25)


def liaison(g, pts, r):
    """Guide d'onde rectangulaire de bronze, nœud de cristal au milieu."""
    M = g.M
    P = g.tube(g.spline(pts, 8), r, M["bronze_capot"], n=4, style="hard", what="guide")[0]
    m = P[len(P) // 2]
    g.sphere(m, r * 1.4, M["bronze_sombre"], n=8, m=5, what="noeud")
    F.crystal(g, m, (0.2, -0.3, 1.0), r * 0.7, r * 3.2, M["cristal_v"], tip=0.4)


def _cristal(g, base, d, r, h, lum=True):
    """Pointe de cristal : fût violet à 6 pans, pointe lumineuse."""
    M = g.M
    d = V(d).normalized()
    base = V(base)
    hb = h * 0.68
    g.cyl(base + d * hb / 2, d, r, hb, M["cristal_v"], n=6, style="hard", what="cristal")
    g.cyl(base + d * (hb + h * 0.16), d, r, h * 0.32, M["emit_soft"] if lum else M["cristal_v"], n=6, r2=r * 0.1,
          style="hard", what="pointe")


def condensateur(g, c, x, y, z, r, h):
    """Pointe de cristal violet sertie dans une bague de bronze à griffes, éclat voisin plus petit."""
    M = g.M
    g.cyl((x, y, z + 0.04), "z", r * 1.05, 0.08, M["bronze_capot"], n=8, style="soft", what="bague")
    g.tube_shell((x, y, z + 0.085), "z", r * 1.1, r * 0.7, 0.03, M["bronze_clair"], n=8, what="sertissure")
    _cristal(g, (x, y, z + 0.06), (0.0, 0.0, 1.0), r * 0.62, h * 0.95)
    _cristal(g, (x + r * 0.5, y - r * 0.3, z + 0.06), (0.35, -0.2, 1.0), r * 0.32, h * 0.5, lum=False)
    for k in range(3):
        a = TAU * k / 3 + 0.4
        g.box((x + r * 0.62 * math.cos(a), y + r * 0.62 * math.sin(a), z + 0.14), (0.025, 0.025, 0.12),
              M["bronze_clair"], "hard", R=Matrix.Rotation(-0.25, 3, V((-math.sin(a), math.cos(a), 0))), what="griffe")


def _arete(g, k, h):
    """Arête de bronze sur un sommet de l'octogone (repère du flanc)."""
    g.box((0, 0, 0.012), (0.05, h * 0.98, 0.024), g.M["bronze_capot"], "hard", what="arete_bronze")
    g.box((0, h * 0.42, 0.03), (0.07, 0.03, 0.03), g.M["bronze_clair"], "hard", what="chapiteau")


def _niche(g, k, h):
    """Niche votive (repère du flanc) : cadre de bronze, petit cristal lumineux."""
    M = g.M
    g.box((0, 0, 0.006), (0.12, h * 0.75, 0.012), M["joint_violet"], "flat", what="niche")
    g.box((0, h * 0.37, 0.016), (0.15, 0.025, 0.02), M["bronze_capot"], "hard", what="linteau")
    for s in (-1, 1):
        g.box((s * 0.07, 0, 0.016), (0.02, h * 0.75, 0.02), M["bronze_capot"], "hard", what="montant")
    g.sphere((0, -h * 0.1, 0.02), 0.026, M["emit_soft"], n=8, m=5, what="feu")


def _brasero(g, k, w):
    """Vasque de bronze sur le dessus d'un degré : cristaux couchés, petite flamme violette."""
    M = g.M
    g.cyl((0, 0, 0.03), "z", 0.07, 0.06, M["bronze_capot"], n=10, r2=0.09, style="soft", what="vasque")
    g.cyl((0, 0, 0.062), "z", 0.075, 0.008, M["joint_violet"], n=10, style="flat", what="fond")
    _cristal(g, (0.0, 0.0, 0.05), (0.2, 0.1, 1.0), 0.026, 0.1)


def _escalier(g, c, i, w):
    """Escalier de pierre sur la face SUD du degré i (du dessus du degré i - 1, ou du sol, au dessus du degré i)."""
    M = g.M
    R0, Rt, z0, z1 = c.gradins[i]
    ya = -SQ2 * R0 * math.cos(math.pi / 8)
    if i:
        R_ = c.gradins[i - 1][1]
        yb = -SQ2 * R_ * math.cos(math.pi / 8) + 0.06
    else:
        yb = ya - 0.3
    n = 3
    for k in range(n):
        zz = z0 + (z1 - z0) * (k + 1) / n
        y_a = yb + (ya - yb) * k / n
        g.box((0, (y_a + ya) / 2, (z0 + zz) / 2), (w, ya - y_a + 0.02, zz - z0), M["pierre_claire2" if k % 2 else
              "pierre_claire"], "hard", what="marche")
        g.box((0, y_a + 0.01, zz - 0.006), (w * 0.98, 0.022, 0.014), M["bronze_sombre"], "hard", what="nez")
    for s in (-1, 1):
        g.box((s * (w / 2 + 0.03), (yb + ya) / 2, (z0 + z1) / 2 + 0.01), (0.06, ya - yb, z1 - z0 + 0.02),
              M["pierre_claire2"], "hard", what="rampe")


def _geode(g, x, y, r, M):
    """Géode ouverte : coque de pierre, tranche violette sombre tournée vers le sud, cristaux qui en sortent."""
    g.sphere((x, y, 0.0), r, M["pierre_claire2"], n=20, m=10, scale=(1.0, 1.0, 0.72), what="geode")
    nrm = V((0.0, -0.75, 0.66)).normalized()
    c0 = V((x, y, 0.0)) + nrm * (r * 0.62)
    g.push_frame(tuple(c0), tuple(nrm))
    g.cyl((0, 0, 0.0), "z", r * 0.78, 0.04, M["joint_violet"], n=20, style="soft", what="tranche")
    g.tube_shell((0, 0, 0.01), "z", r * 0.82, r * 0.7, 0.04, M["stone"], n=20, what="croute")
    for k in range(7):
        a = TAU * k / 7
        rr = r * 0.42 * (k % 2 + 0.3)
        _cristal(g, (rr * math.cos(a), rr * math.sin(a), 0.0), (0.25 * math.cos(a), 0.25 * math.sin(a), 1.0),
                 0.03 + 0.012 * (k % 3), 0.12 + 0.05 * (k % 3), lum=k % 2 == 0)
    g.pop()


def socle(g, c):
    """Escaliers au sud des degrés, arêtes de bronze, niches votives, vasques, géodes aux coins arrière, guides
    d'onde vers le pivot."""
    M = g.M
    zp = c.gradins[-1][3]
    for i in range(3):
        _escalier(g, c, i, 0.36 - 0.05 * i)
    sommets = [math.pi / 8 + TAU * k / 8 for k in range(8)]
    for i in range(4):
        O.sur_flanc(g, c, i, O.visibles(sommets, nord=0.5), _arete, f=0.5, dr=0.0)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (225, 315)], _niche, f=0.5, dr=0.012)
    O.sur_flanc(g, c, 1, [math.radians(a) for a in (200, 340)], _niche, f=0.5, dr=0.012)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (225, 315, 180, 0)], _brasero)
    O.sur_dessus(g, c, 2, [math.radians(a) for a in (240, 300)], _brasero)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        # ronde 1 (F1-B) : géode plus petite et poussée dans le coin (en pose N, sa pointe touchait la joue de la tête et
        # enfermait un jour de 32 px avec le guide d'onde)
        x, y = p["x"] + sx * 0.03, Y(p["yn"] + 0.03)
        _geode(g, x, y, 0.29, M)
        for j in range(3):
            a = 1.0 + j * 1.6
            F.lump(g, (x + 0.42 * math.cos(a), y + 0.4 * math.sin(a), 0.0), 0.07, M["pierre_claire"], sz=0.6)
        liaison(g, [(x - sx * 0.2, y - 0.3, 0.12), (x * 0.66, Y(p["yn"] * 0.6), c.gradins[1][3] + 0.1),
                    (x * 0.4, Y(p["yn"] * 0.36), zp + 0.06)], 0.035)
        g.halo((x, y - 0.3, 0.3), M["_emit_rgb"], 5.0)
    for (x, yn) in ((0.0, -1.8), (-1.4, -0.7), (1.4, -0.7)):
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 5.0)


def piece(g, c):
    """Niveau 14 : deux GÉODES ouvertes sur socle de pierre aux coins avant, sur un patin de dalles relié au premier
    degré."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.12, yn + 0.12, 0.8, 0.8, rz=sx * 0.785)
        with at(g, x, yn, z=0.035):
            g.cyl((0, 0, 0.05), "z", 0.36, 0.1, M["pierre_claire"], n=8, style="hard", phase=math.pi / 8,
                  what="socle_geode")
            g.tube_shell((0, 0, 0.1), "z", 0.37, 0.3, 0.02, M["bronze_capot"], n=8, what="bord")
            g.push((0, 0, 0.1))
            _geode(g, 0.0, 0.0, 0.3, M)
            g.pop()
        g.halo((x, Y(yn - 0.3), 0.4), M["_emit_rgb"], 6.0)


def arriere(g, c):
    """RELIQUAIRE de bronze : coffre bas, couvercle à pans, petits cristaux sertis, ferrures."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    T = PT.hull(g, -bx, bx, y0, y1, zb, z1 - 0.08, ins=(0.05, 0.04, 0.0), panel=0.22,
                mats=[M["bronze_capot"], M["bronze_sombre"]], rivet_step=0.1)
    yc = (y0 + y1) / 2
    g.box((0, yc, z1 - 0.06), (2 * bx - 0.1, y1 - y0 - 0.08, 0.04), M["bronze_sombre"], "hard", what="couvercle")
    for k in range(3):
        _cristal(g, ((k - 1) * bx * 0.55, yc - 0.03, z1 - 0.04), (0.15 * (k - 1), -0.5, 1.0), 0.03, 0.11,
                 lum=k == 1)
    for s in (-1, 1):
        g.box((s * bx, y0 + 0.05, (zb + z1) / 2), (0.03, 0.08, z1 - zb - 0.1), M["bronze_clair"], "hard",
              what="ferrure")


def tete(g, c):
    """Petites coupes de bronze à éclats de cristal à l'arrière de la platine."""
    M = g.M
    zb = O.zb(c)
    for (x, y, w) in O.pods(c):
        g.cyl((x, y, zb + 0.03), "z", w, 0.06, M["bronze_capot"], n=8, r2=w * 1.2, style="soft", what="coupe")
        _cristal(g, (x, y, zb + 0.05), (0.1 if x > 0 else -0.1, -0.3, 1.0), w * 0.4, w * 1.6)


def _veine(g, p, nrm, L, w):
    g.push_frame(tuple(p), tuple(nrm), (0.0, 1.0, 0.0))
    g.box((0, 0, 0.0), (L, w, 0.01), g.M["emit"], "flat", what="veine")
    g.pop()


def emetteur(g, c):
    """PRISME DE CRISTAL violet à 6 pans couché dans l'axe (court et épais, pointe taillée vers l'avant : le cristal
    est la lentille), veines lumineuses sur les trois pans du dessus, trois bandes de bronze à griffes."""
    M = g.M
    re, zh = c.re, c.zh
    r = 0.72 * re
    y0, yb = -0.62 * re, 0.42 * re
    g.cyl((0, (y0 + yb) / 2, zh), "y", r, yb - y0, M["cristal_v"], n=6, style="hard", what="prisme")
    g.cyl((0, yb + 0.3 * re, zh), "y", r, 0.6 * re, M["cristal_v"], n=6, r2=0.08 * re, style="hard",
          what="pointe")
    g.cyl((0, y0 - 0.04, zh), "y", r * 0.9, 0.08, M["bronze_sombre"], n=6, style="hard", what="culot")
    # veines de lumière sur les trois pans du dessus (centres des faces à 0,866 r)
    for ang in (210.0, 270.0, 330.0):
        a = math.radians(ang)
        nrm = V((math.cos(a), 0.0, -math.sin(a)))
        p = V((0, (y0 + yb) / 2 + 0.05 * re, zh)) + nrm * (0.866 * r + 0.004)
        _veine(g, p, nrm, (yb - y0) * 0.8, 0.05 * re)
    # point lumineux à la pointe (rôle de la lentille)
    g.sphere((0, yb + 0.58 * re, zh), 0.07 * re, M["emit"], n=10, m=6, what="foyer")
    # trois bandes de bronze à griffes
    for k, yy in enumerate((y0 + 0.12 * re, (y0 + yb) / 2, yb - 0.06 * re)):
        g.tube_shell((0, yy, zh), "y", r * 1.08, r * 0.92, 0.09 * re, M["bronze_capot"], n=6, what="bande")
        F.bolts_ring(g, (0, yy, zh), (0, 1, 0), r * 1.05, 6, M["bronze_clair"], r=0.014)
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = V((sx * 0.62 * r, yb - 0.06 * re, zh + sz * 0.62 * r))
            b = V((sx * 0.3 * r, yb + 0.32 * re, zh + sz * 0.3 * r))
            d = b - a
            g.box((a + b) / 2, (0.05 * re, d.length, 0.05 * re), M["bronze_clair"], "hard",
                  R=Matrix.Rotation(math.atan2(-d.x, d.y), 3, "Z") @ Matrix.Rotation(math.atan2(d.z, math.hypot(d.x, d.y)),
                                                                                     3, "X"), what="griffe")
