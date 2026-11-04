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
# LOT F1-C (CONCEPT §4) : liserés CONTINUS de lave de la lignée retirés (L2 1,04 t² en ronde 2 : les anneaux de lave des
# arêtes et les coulées formaient un seul foyer) ; la lave vit en coulées courtes et séparées, fentes et cratère
HABILLAGE["forme_affut"] = dict(HABILLAGE["forme_affut"], lisere=None)


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


def _coulee_longue(g, c, a0, n_g, k, branche, large=False):
    """LOT F1-C : coulée de lave du haut du dernier gradin vers le bas, sur n_g gradins, qui serpente (l'angle dérive
    d'un gradin à l'autre), s'élargit vers le bas ; branche facultative sur le gradin le plus bas atteint."""
    M = g.M
    ng = len(c.gradins)
    pts = []
    a = a0
    for j, i in enumerate(range(ng - 1, ng - 1 - n_g, -1)):
        for f in (0.95, 0.7, 0.45, 0.2, 0.02):
            a += 0.018 * math.sin(3.1 * f + k + j)
            p, nrm, _ = O.flanc(c, i, a, f, 0.006)
            pts.append(p)
        if i > 0:
            # traverse le dessus du gradin inférieur (du pied du gradin i à l'arête du gradin i-1)
            q = O.dessus(c, i - 1, a, 0.5)
            pts.append(V((q.x, q.y, q.z + 0.004)))
    r0 = (0.026 if large else 0.014) + 0.003 * n_g
    g.tube(pts, r0, M["emit"], n=6, style="soft", what="coulee")
    # croûtes sombres posées sur la coulée (lave qui fige par plaques) : un flot, pas un fil
    for q in pts[2::3]:
        F.lump(g, (q.x, q.y, q.z + r0 * 0.6), r0 * 1.3, M["basalte_dalle2"], sz=0.45, jit=0.4)
    if branche:
        i = ng - n_g
        b = []
        ab = a
        for f in (0.75, 0.5, 0.25, 0.05):
            ab -= 0.06
            p, nrm, _ = O.flanc(c, i, ab, f, 0.006)
            b.append(p)
        g.tube(b, r0 * 0.75, M["emit"], n=6, style="soft", what="branche")


def _event(g, k, h):
    """Évent rougeoyant sur le flanc (repère du flanc) : couronne de fonte, gueule de lave."""
    M = g.M
    g.cyl((0, 0, 0.01), "z", 0.07, 0.03, M["fonte_noire"], n=12, style="soft", what="event")
    g.cyl((0, 0, 0.026), "z", 0.042, 0.008, M["emit"], n=12, style="flat", what="gueule")
    for j in range(3):
        F.lump(g, (0.08 * math.cos(j * 2.1), 0.06 * math.sin(j * 2.1), 0.01), 0.03, M["basalte_capot"], sz=0.5)


def _cratere(g, c):
    """LOT F1-C : CRATÈRE sur le dernier gradin, autour du pivot : lèvre de blocs de basalte de hauteurs inégales, et
    entre les blocs, au fond, des éclats de lave SÉPARÉS (petits foyers)."""
    M = g.M
    i = len(c.gradins) - 1
    n = 13
    for k in range(n):
        a = TAU * (k + 0.2) / n
        p = O.dessus(c, i, a, 0.88)     # ronde 3c : lèvre au BORD du dernier gradin (visible devant la tête)
        # ronde 3b (critique : « le cratère n'existe pas visuellement ») : lèvre DENTELÉE plus haute que le pied de la
        # tête, blocs de 0,11 à 0,2
        hk = 0.11 + 0.045 * ((k * 5) % 3)
        F.lump(g, (p.x, p.y, p.z - 0.01), hk, M["basalte_capot" if k % 2 else "basalte_dalle2"], sz=1.5, jit=0.4)
        if math.sin(a + TAU / (2 * n)) < 0.5 and k % 2 == 0:
            q = O.dessus(c, i, a + TAU / (2 * n), 0.15)
            g.box((q.x, q.y, q.z + 0.004), (0.07, 0.02, 0.01), M["emit"], "flat", R=Matrix.Rotation(a, 3, "Z"),
                  what="eclat_lave")


def socle(g, c):
    """Coulées de lave sur les pentes, évents, blocs de basalte au pied, coulées figées aux coins arrière, conduits de
    fonte vers le pivot."""
    M = g.M
    zp = c.gradins[-1][3]
    # LOT F1-C ronde 3b (critique : 40 tirets identiques en rangées radiales = « agrafes », pas des coulées) : SIX
    # COULÉES irrégulières qui partent de la lèvre du cratère et DESCENDENT les gradins en serpentant, de longueurs
    # inégales, avec une branche ; chaque coulée est un foyer séparé (L2)
    # ronde 3c (critique : encore des « tirets radiaux réguliers ») : TROIS grandes coulées, larges, de longueurs
    # inégales, ramifiées, et deux filets courts
    for k, (a0, n_g, br) in enumerate(((228.0, 3, True), (275.0, 3, True), (318.0, 2, True), (252.0, 1, False),
                                       (343.0, 1, False))):
        _coulee_longue(g, c, math.radians(a0), n_g, k, br, large=(k < 3))
    # trois gros PRISMES de basalte couchés de travers au pied (cassent la jupe régulière)
    for k, av in enumerate((205.0, 292.0, 336.0)):
        p, nrm, _ = O.flanc(c, 0, math.radians(av), 0.05, 0.12)
        g.cyl((p.x, p.y, 0.09), (math.cos(0.7 * k + 0.4), math.sin(0.7 * k + 0.4), 0.35), 0.09, 0.42,
              M["basalte_capot"], n=6, style="hard", phase=0.2 * k, what="prisme_basalte")
    O.sur_flanc(g, c, 1, [math.radians(a) for a in (198, 250, 342)], _event, f=0.45, dr=0.0)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (186, 278, 354)], _event, f=0.4, dr=0.0)
    # blocs de basalte au pied du cône, entre les orgues ; LOT F1-C (« plateforme ronde à lignes de lave, pas une
    # montagne » en ronde 2 ; masse sous l'âge 4) : ÉBOULIS plus gros tout autour du pied, blocs sur les pentes des deux
    # premiers gradins (la silhouette devient irrégulière), CRATÈRE à lèvre déchiquetée autour du pivot
    for k in range(22):
        a = TAU * (k + 0.37) / 22
        if math.sin(a) > 0.6:
            continue
        p, nrm, _ = O.flanc(c, 0, a, 0.05, 0.05)
        F.lump(g, (p.x, p.y, 0.02), 0.08 + 0.025 * (k % 3), M["basalte_dalle" if k % 2 else "basalte_capot"], sz=0.65,
               jit=0.3)
    for i, n in ((0, 16), (1, 11)):
        for k in range(n):
            a = TAU * (k + 0.61) / n
            if math.sin(a) > 0.35:
                continue
            p, nrm, _ = O.flanc(c, i, a, 0.45 + 0.2 * (k % 2), 0.02)
            F.lump(g, (p.x, p.y, p.z), 0.05 + 0.02 * (k % 3), M["basalte_capot" if k % 3 else "fonte_v"], sz=0.6,
                   jit=0.35)
    _cratere(g, c)
    # ronde 3c (P4 0,52 ; masse à 0,987 × l'âge 4) : scories et blocs sur les DESSUS des deux premiers gradins
    for i, angs in ((0, (192, 218, 250, 282, 312, 338, 358, 172)), (1, (205, 240, 300, 335))):
        for k, av in enumerate(angs):
            q = O.dessus(c, i, math.radians(av), 0.4 + 0.25 * (k % 2))
            F.lump(g, (q.x, q.y, q.z - 0.005), 0.06 + 0.02 * (k % 3), M["basalte_capot" if k % 2 else "fonte_v"],
                   sz=0.7, jit=0.35)
    # coulées figées aux coins arrière : gros blocs, fentes lumineuses, flaque
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, y = p["x"] - sx * 0.04, Y(p["yn"] - 0.04)
        F.lump(g, (x, y, 0.0), 0.34, M["basalte_capot"], sz=0.7, jit=0.3)       # LOT F1-C : coulée figée plus massive
        F.lump(g, (x + sx * 0.2, y - 0.2, 0.0), 0.2, M["basalte_dalle2"], sz=0.65)
        F.lump(g, (x - sx * 0.26, y - 0.12, 0.0), 0.16, M["fonte_v"], sz=0.55)
        F.lump(g, (x - sx * 0.05, y + 0.22, 0.0), 0.18, M["basalte_dalle"], sz=0.6)
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
    # dessus : LOT F1-C ronde 3b (pose N : la fente axiale de lave se lisait « aiguille lumineuse dressée ») : GRILLE DE
    # BRAISES (barreaux de fonte en travers, braises entre eux), aucune ligne dans l'axe
    yt0, yt1 = y0 + 0.2 * re, y1 - 0.34 * re
    nb = 5
    for j in range(nb + 1):
        yy = yt0 + (yt1 - yt0) * j / nb
        g.box((0, yy, zh + 0.6 * re + 0.015), (0.5 * re, 0.035, 0.03), M["fonte_noire"], "hard", what="barreau")
    for j in range(nb):
        yy = yt0 + (yt1 - yt0) * (j + 0.5) / nb
        for sx in (-1, 1):
            F.lump(g, (sx * 0.1 * re, yy, zh + 0.6 * re), 0.03, M["emit"], sz=0.6, jit=0.3)
    # lentille d'obsidienne (verre noir lisse, cœur de lave) sur la face avant
    g.cyl((0, y1 - 0.06 * re, zh - 0.02 * re), "y", 0.42 * re, 0.14 * re, M["fonte_noire"], n=24, style="soft",
          what="collerette")
    corps.lentille(g, c, y1 + 0.02 * re, 0.36 * re, verre=M["glass_dk"], cercle=M["fonte_v"])
    # griffes de fonte aux coins avant du capot
    for sx in (-1, 1):
        g.box((sx * 0.86 * re, y1 - 0.08 * re, zh - 0.38 * re), (0.08 * re, 0.18 * re, 0.6 * re), M["fonte_noire"],
              "hard", what="arete_avant")
