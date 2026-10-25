"""Laser · Âge 5 · Volcan (ère II, 3×3, niveaux 9 et 10). Lot F1-B (25/10) ; fiche : fo-logs/2026-10-24_F1/FICHES_LASER.md,
âge 5 (fait foi). S'exécute DANS Blender.

En 3 mots : « volcan, orgues de basalte, fente de lave ». L'affût est un VOLCAN (cône à 3 gradins de basalte, fêlures de
lave sur les arêtes, coulées qui descendent les pentes, évents rougeoyants) ceint d'une palissade d'ORGUES BASALTIQUES
(les 12 condensateurs, prismes à 6 pans de hauteurs inégales, sommet fendu de lave). L'émetteur est un CAPOT
TRAPÉZOÏDAL de basalte CEINT d'une FENTE DE LAVE qui court sur la face avant, les flancs et le dessus ; lentille
d'obsidienne à l'avant ; fourche de tungstène noirci ; caisson arrière à écailles de fonte. Coins arrière : coulées de
lave figée.
Palette 60/30/10 (ages.PALETTE[5]) : basalte noir / rouille brûlée (fonte) / lave orange (braise vive, très saturée :
c'est la SATURATION qui la sépare de l'âge 4).
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

EPOQUE = 5
NOM = ages.NOMS[5]
TRIPLET = ("volcan", "orgues de basalte", "fente de lave")
FOYER = ages.FOYER[5]
FAISCEAU = dict(rgb=(1.0, 0.3, 0.02), rgb2=(1.0, 0.55, 0.1), forme="jet de magma orange-rouge très saturé, épais, "
                "gouttes de magma qui tombent le long du trait", largeur=1.5)
HABILLAGE = dict(ages.CORPS[5], **E_.MAQUETTES[5])


def matieres(metal, M):
    ages.matieres(5, metal, M)
    M["capot_basalte"] = M["basalte_capot"]


def liaison(g, pts, r):
    """Conduit de fonte noire à fentes rougeoyantes."""
    M = g.M
    P = g.tube(g.spline(pts, 8), r, M["fonte_noire"], n=10, what="conduit")[0]
    for i in range(2, len(P) - 1, 3):
        a = (P[min(len(P) - 1, i + 1)] - P[i - 1]).normalized()
        g.cyl(P[i], a, r * 1.12, r * 0.5, M["emit"], n=10, style="flat", what="fente")


def condensateur(g, c, x, y, z, r, h):
    """Orgue basaltique : prisme à 6 pans de basalte (hauteur inégale), chapeau fendu de lave, colonnette voisine."""
    M = g.M
    k = (int(round(1000 * (x * 3.1 + y * 1.7))) % 5) / 4.0
    hh = h * (0.82 + 0.36 * k)
    g.cyl((x, y, z + hh / 2), "z", r, hh, M["basalte_capot"], n=6, style="hard", phase=0.3, what="orgue")
    g.cyl((x, y, z + hh + 0.015), "z", r * 0.92, 0.03, M["basalte_dalle2"], n=6, style="hard", phase=0.3, what="tete")
    g.box((x, y, z + hh + 0.032), (r * 1.3, 0.024, 0.012), M["emit"], "flat", R=Matrix.Rotation(0.3 + k, 3, "Z"),
          what="fente_lave")
    g.tube_shell((x, y, z + hh * 0.35), "z", r + 0.008, r - 0.01, 0.025, M["fonte_v"], n=6, what="cerclage")
    d = V((x, y / SQ2, 0)).normalized()
    t = V((-d.y, d.x * SQ2, 0)).normalized()
    p = V((x, y, z)) + t * (r * 1.55)
    g.cyl((p.x, p.y, z + hh * 0.33), "z", r * 0.55, hh * 0.66, M["basalte_dalle"], n=6, style="hard", phase=0.1,
          what="colonnette")


def _coulee(g, c, i, a, f0=0.92, f1=0.12, r=0.014):
    """Coulée de lave le long de la pente du gradin i (tube lumineux collé au flanc)."""
    pts = []
    for k in range(7):
        f = f0 + (f1 - f0) * k / 6
        p, nrm, tan = O.flanc(c, i, a + 0.02 * math.sin(k * 1.7), f, r * 0.3)
        pts.append(p)
    g.tube(pts, r, g.M["emit"], n=6, style="soft", what="coulee")


def _event(g, k, h):
    """Évent rougeoyant sur le flanc (repère du flanc) : couronne de fonte, gueule de lave."""
    M = g.M
    g.cyl((0, 0, 0.01), "z", 0.07, 0.03, M["fonte_noire"], n=12, style="soft", what="event")
    g.cyl((0, 0, 0.026), "z", 0.042, 0.008, M["emit"], n=12, style="flat", what="gueule")
    for j in range(3):
        F.lump(g, (0.08 * math.cos(j * 2.1), 0.06 * math.sin(j * 2.1), 0.01), 0.03, M["basalte_capot"], sz=0.5)


def socle(g, c):
    """Coulées de lave sur les pentes, évents, blocs de basalte au pied, coulées figées aux coins arrière, conduits de
    fonte vers le pivot."""
    M = g.M
    zp = c.gradins[-1][3]
    for i, angs in ((0, (204, 236, 262, 291, 318, 343)), (1, (222, 276, 330)), (2, (248, 300))):
        for a in angs:
            _coulee(g, c, i, math.radians(a), f1=0.1 if i else 0.2, r=0.016 - 0.002 * i)
    O.sur_flanc(g, c, 1, [math.radians(a) for a in (198, 250, 342)], _event, f=0.45, dr=0.0)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (186, 278, 354)], _event, f=0.4, dr=0.0)
    # blocs de basalte au pied du cône, entre les orgues
    for k in range(14):
        a = TAU * (k + 0.37) / 14
        if math.sin(a) > 0.5:
            continue
        p, nrm, _ = O.flanc(c, 0, a, 0.05, 0.03)
        F.lump(g, (p.x, p.y, 0.02), 0.05 + 0.015 * (k % 3), M["basalte_dalle" if k % 2 else "basalte_capot"], sz=0.6)
    # coulées figées aux coins arrière : gros blocs, fentes lumineuses, flaque
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, y = p["x"] - sx * 0.04, Y(p["yn"] - 0.04)
        F.lump(g, (x, y, 0.0), 0.26, M["basalte_capot"], sz=0.55, jit=0.3)
        F.lump(g, (x + sx * 0.18, y - 0.16, 0.0), 0.15, M["basalte_dalle2"], sz=0.6)
        F.lump(g, (x - sx * 0.22, y - 0.1, 0.0), 0.12, M["fonte_v"], sz=0.5)
        for j in range(3):
            a = 0.6 + j * 1.9
            g.box((x + 0.1 * math.cos(a), y + 0.1 * math.sin(a), 0.13), (0.16, 0.018, 0.01), M["emit"], "flat",
                  R=Matrix.Rotation(a + 0.8, 3, "Z"), what="fente")
        g.cyl((x - sx * 0.05, y - 0.26, 0.012), "z", 0.07, 0.02, M["emit"], n=14, style="flat", what="flaque")
        g.torus((x - sx * 0.05, y - 0.26, 0.022), "z", 0.075, 0.015, M["basalte_dalle2"], n=14, m=5, what="croute")
        liaison(g, [(x - sx * 0.12, y - 0.2, 0.18), (x * 0.66, Y(p["yn"] * 0.62), c.gradins[0][3] + 0.15),
                    (x * 0.4, Y(p["yn"] * 0.38), zp + 0.08)], 0.034)
        g.halo((x, y - 0.25, 0.25), M["_emit_rgb"], 6.0)
    for (x, yn) in ((0.0, -1.35), (-1.1, -0.5), (1.1, -0.5)):
        g.halo((x, Y(yn), 0.25), M["_emit_rgb"], 5.0)


def piece(g, c):
    """Niveau 10 : deux CREUSETS DE LAVE (fonte sur trois pieds, surface de lave et croûtes) aux coins avant, sur un
    patin de dalles de basalte."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.1, yn + 0.1, 0.62, 0.62, rz=sx * 0.785)
        with at(g, x, yn, z=0.035):
            for k in range(3):
                a = TAU * k / 3 + 0.4
                d = V((math.cos(a), math.sin(a), 0))
                g.box(d * 0.15 + V((0, 0, 0.1)), (0.04, 0.04, 0.22), M["fonte_noire"], "hard",
                      R=Matrix.Rotation(0.28, 3, V((-d.y, d.x, 0))), what="pied")
            g.cyl((0, 0, 0.27), "z", 0.17, 0.16, M["fonte_noire"], n=20, r2=0.22, style="soft", what="creuset")
            g.tube_shell((0, 0, 0.34), "z", 0.235, 0.2, 0.04, M["fonte_v"], n=20, what="bord")
            g.cyl((0, 0, 0.345), "z", 0.2, 0.012, M["emit"], n=20, style="flat", what="lave")
            for j in range(4):
                F.lump(g, (0.09 * math.cos(j * 1.6), 0.09 * math.sin(j * 1.6), 0.35), 0.04, M["basalte_dalle2"], sz=0.4)
            g.box((0.0, -0.24, 0.3), (0.06, 0.08, 0.025), M["fonte_v"], "hard", what="bec")
        g.halo((x, Y(yn), 0.4), M["_emit_rgb"], 7.0)


def arriere(g, c):
    """Caisson arrière à ÉCAILLES de fonte : caisson bas de fonte noire, écailles de rouille brûlée qui se recouvrent,
    grille rougeoyante au dos."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    T = PT.hull(g, -bx, bx, y0, y1, zb, z1 - 0.03, ins=(0.04, 0.06, 0.0), panel=0.3,
                mats=[M["fonte_noire"], M["basalte_capot"]], rivet_step=0.13)
    rows, cols = 3, max(3, int(2 * bx / 0.12))
    for i in range(rows):
        for j in range(cols):
            x = -bx + 0.06 + (j + 0.5 * (i % 2)) * (2 * bx - 0.12) / cols
            yy = y0 + 0.08 + i * (y1 - y0 - 0.12) / rows
            g.box((x, yy, z1 - 0.01 + 0.006 * i), (0.11, 0.1, 0.018), M["fonte_v"], "hard",
                  R=Matrix.Rotation(0.18, 3, "X"), what="ecaille")
    g.grille(PT.lift(PT.face_quad([V((-bx, y0, zb)), V((bx, y0, zb)), T[1], T[0]], 0.15, 0.85, 0.2, 0.75), 0.01), 4,
             slat_mat=M["fonte_noire"])
    g.box((0, y0 - 0.002, zb + (z1 - zb) * 0.45), (2 * bx * 0.6, 0.006, (z1 - zb) * 0.4), M["emit"], "flat",
          what="lueur_grille")


def tete(g, c):
    """Blocs d'obsidienne et petit creuset à l'arrière de la platine ; écailles sur les bras de la fourche."""
    M = g.M
    zb = O.zb(c)
    for (x, y, w) in O.pods(c):
        F.lump(g, (x, y, zb), w * 1.3, M["basalte_capot"], sz=0.7)
        g.box((x, y - w * 0.5, zb + w * 0.7), (w * 1.6, 0.01, 0.012), M["emit"], "flat", what="fente")


def emetteur(g, c):
    """CAPOT TRAPÉZOÏDAL de basalte (plus large que long), CEINT d'une FENTE DE LAVE horizontale (avant, flancs) et
    d'une fente sur le dessus (de l'arrière à l'avant) ; lentille d'obsidienne cerclée de fonte ; plaques de rouille
    brûlée ; arêtes de fonte."""
    M = g.M
    re, zh = c.re, c.zh
    y0, y1 = -0.7 * re, 0.86 * re
    PT.hull(g, -0.95 * re, 0.95 * re, y0, y1, zh - 0.75 * re, zh - 0.05 * re, ins=(0.08 * re, 0.04 * re, 0.08 * re),
            panel=0.2, mats=[M["basalte_capot"], M["fonte_v"]], rivet_step=0.11)
    # fente de lave (le corps de lave dépasse à peine entre les deux moitiés du capot)
    g.box((0, (y0 + y1) / 2 - 0.02 * re, zh), (1.74 * re, (y1 - y0) * 0.86, 0.1 * re), M["emit"], "flat",
          what="fente_lave")
    PT.hull(g, -0.86 * re, 0.86 * re, y0 + 0.04 * re, y1 - 0.08 * re, zh + 0.05 * re, zh + 0.6 * re,
            ins=(0.22 * re, 0.12 * re, 0.22 * re), panel=0.2, mats=[M["basalte_capot"], M["basalte_dalle2"]],
            rivet_step=0.11)
    # fente du dessus (de l'arrière à l'avant), bordée de deux arêtes de fonte
    yt0, yt1 = y0 + 0.2 * re, y1 - 0.34 * re
    g.box((0, (yt0 + yt1) / 2, zh + 0.6 * re + 0.004), (0.09 * re, yt1 - yt0, 0.012), M["emit"], "flat",
          what="fente_dessus")
    for sx in (-1, 1):
        g.box((sx * 0.1 * re, (yt0 + yt1) / 2, zh + 0.6 * re + 0.015), (0.06 * re, yt1 - yt0, 0.03),
              M["fonte_noire"], "hard", what="arete")
    # lentille d'obsidienne (verre noir lisse, cœur de lave) sur la face avant
    g.cyl((0, y1 - 0.06 * re, zh - 0.02 * re), "y", 0.42 * re, 0.14 * re, M["fonte_noire"], n=24, style="soft",
          what="collerette")
    corps.lentille(g, c, y1 + 0.02 * re, 0.36 * re, verre=M["glass_dk"], cercle=M["fonte_v"])
    # griffes de fonte aux coins avant du capot
    for sx in (-1, 1):
        g.box((sx * 0.86 * re, y1 - 0.08 * re, zh - 0.38 * re), (0.08 * re, 0.18 * re, 0.6 * re), M["fonte_noire"],
              "hard", what="arete_avant")
