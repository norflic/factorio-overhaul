"""Laser · Âge 14 · La Porte (ère V cosmique, 6×6, niveaux 27 et 28). Lot F1-B (25/10) ; fiche :
fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 14 (fait foi). S'exécute DANS Blender.

En 3 mots : « anneau à chevrons, indigo, étoiles ». L'affût est un OBSERVATOIRE : deux gradins larges chanfreinés d'indigo
de nuit SEMÉS D'ÉTOILES, liserés doux, 8 contreforts blanc lunaire, ombilicaux blanc lunaire à rotules, plaques de cartes
du ciel, nœuds relais ; 16 COLONNETTES blanc lunaire à étoile au sommet ; petits ANNEAUX RELAIS dressés face au sud aux
coins arrière. L'émetteur est la PORTE : l'ANNEAU de la lignée (penché de 35° vers l'avant) habillé de blanc lunaire et
de 9 CHEVRONS lumineux, et dedans un HORIZON ÉTOILÉ (disque indigo très sombre semé d'étoiles, anneau de lumière au
bord, iris au centre) d'où sort le faisceau ; caisson indigo à ombilicaux derrière.
Palette 60/30/10 (ages.PALETTE[14]) : indigo de nuit / blanc lunaire mat / blanc d'étoile semé en points ; ni or ni
orange.
"""
import math
import random

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

EPOQUE = 14
NOM = ages.NOMS[14]
TRIPLET = ("anneau à chevrons", "indigo", "étoiles")
FOYER = ages.FOYER[14]
FAISCEAU = dict(rgb=(0.957, 0.965, 1.0), rgb2=(0.749, 0.831, 1.0), forme="trait blanc stellaire, étincelles d'étoiles "
                "le long, le bout s'ouvre en petit trou de ver à l'impact", largeur=0.8)
HABILLAGE = dict(ages.CORPS[14], **E_.MAQUETTES[14])


def matieres(metal, M):
    ages.matieres(14, metal, M)


def liaison(g, pts, r):
    """Ombilical blanc lunaire à rotules (sphères aux deux bouts et au milieu)."""
    M = g.M
    P = g.tube(g.spline(pts, 8), r, M["blanc_lunaire"], n=10, what="ombilical")[0]
    for i in (0, len(P) // 2, len(P) - 1):
        g.sphere(P[i], r * 1.6, M["noir_spatial"], n=10, m=6, what="rotule")
    for i in range(2, len(P) - 2, 4):
        a = (P[i + 1] - P[i - 1]).normalized()
        g.cyl(P[i], a, r * 1.2, r * 0.6, M["indigo_nuit2"], n=10, style="hard", what="bague")


def _etoile(g, p, s, mat):
    """Étoile à 4 branches (deux losanges croisés) et cœur."""
    p = V(p)
    for a in (0.0, math.pi / 2):
        g.box(p, (s, s * 0.22, s * 0.22), mat, "flat", R=Matrix.Rotation(a, 3, "Z"), what="branche")
    g.sphere(p, s * 0.2, mat, n=8, m=5, what="coeur_etoile")


def condensateur(g, c, x, y, z, r, h):
    """Colonnette blanc lunaire à bagues indigo, étoile au sommet."""
    M = g.M
    g.cyl((x, y, z + 0.04), "z", r * 0.9, 0.08, M["indigo_nuit2"], n=16, style="soft", what="base")
    g.cyl((x, y, z + h * 0.5), "z", r * 0.42, h * 0.84, M["blanc_lunaire"], n=16, r2=r * 0.34, style="soft",
          what="colonnette")
    for f in (0.3, 0.62):
        g.tube_shell((x, y, z + h * f), "z", r * 0.5, r * 0.3, 0.03, M["indigo_nuit"], n=16, what="bague")
    g.sphere((x, y, z + h * 0.94), r * 0.32, M["blanc_lunaire"], n=12, m=6, what="globe")
    _etoile(g, (x, y, z + h * 0.94 + r * 0.32 + 0.02), r * 0.8, M["emit"])


def _carte(g, k, h):
    """Plaque de carte du ciel sur le flanc : cadre blanc lunaire, fond noir spatial, étoiles."""
    M = g.M
    w = 0.34
    g.box((0, 0, 0.006), (w + 0.04, h * 0.6, 0.012), M["blanc_lunaire"], "hard", what="cadre")
    g.box((0, 0, 0.014), (w, h * 0.5, 0.006), M["noir_spatial"], "flat", what="carte")
    rng = random.Random(1400 + k)
    for j in range(6):
        g.sphere((rng.uniform(-w / 2.4, w / 2.4), rng.uniform(-h * 0.2, h * 0.2), 0.018), rng.choice((0.008, 0.012)),
                 M["emit"], n=6, m=4, what="etoile_carte")


def _relais(g, k, w):
    """Nœud relais sur le dessus : sphère blanc lunaire sur socle indigo, point d'étoile."""
    M = g.M
    g.cyl((0, 0, 0.03), "z", 0.07, 0.06, M["indigo_nuit2"], n=12, style="soft", what="socle")
    g.sphere((0, 0, 0.1), 0.055, M["blanc_lunaire"], n=12, m=6, what="noeud")
    g.sphere((0, -0.05, 0.11), 0.016, M["emit"], n=6, m=4, what="point")


def _anneau_relais(g, x, y, R, M):
    """Anneau relais dressé face au sud (axe y) : tore blanc lunaire, horizon étoilé PLEIN dedans (aucun jour),
    chevrons, socle indigo."""
    zc = R + 0.14
    g.box((x, y, 0.06), (R * 1.5, R * 0.8, 0.12), M["indigo_nuit"], "hard", what="socle")
    g.box((x, y, 0.13), (R * 0.5, R * 0.5, 0.06), M["blanc_lunaire"], "hard", what="pied")
    g.torus((x, y, zc), "y", R, R * 0.17, M["blanc_lunaire"], n=32, m=8, what="anneau_relais")
    g.cyl((x, y, zc), "y", R * 0.9, R * 0.2, M["horizon_porte"], n=32, style="soft", what="horizon")
    rng = random.Random(int(abs(x) * 100))
    for j in range(7):
        a = rng.uniform(0, TAU)
        rr = R * 0.75 * math.sqrt(rng.uniform(0.05, 1))
        g.sphere((x + rr * math.cos(a), y - R * 0.11, zc + rr * math.sin(a)), 0.012, M["emit"], n=6, m=4,
                 what="etoile")
    g.torus((x, y - R * 0.06, zc), "y", R * 0.86, 0.012, M["emit_soft"], n=32, m=4, what="bord_lumineux")
    for k in range(5):
        a = math.pi / 2 + TAU * k / 5
        g.box((x + R * math.cos(a), y - R * 0.16, zc + R * math.sin(a)), (0.04, 0.02, 0.04), M["emit"], "flat",
              R=Matrix.Rotation(-a, 3, "Y"), what="chevron")


def socle(g, c):
    """Ombilicaux blanc lunaire qui ceignent les gradins, plaques de cartes du ciel, nœuds relais, anneaux relais
    dressés (coins arrière), ombilicaux vers le pivot."""
    M = g.M
    zp = c.gradins[-1][3]
    O.ceinture(g, c, 0, 0.28, 0.026, M["blanc_lunaire"], colliers=M["noir_spatial"], pas=0.5)
    O.ceinture(g, c, 1, 0.3, 0.022, M["blanc_lunaire"], colliers=M["noir_spatial"], pas=0.45)
    O.sur_flanc(g, c, 0, [math.radians(a) for a in (200, 248, 292, 340)], _carte, f=0.62, dr=0.004)
    O.sur_flanc(g, c, 1, [math.radians(a) for a in (225, 270, 315)], _carte, f=0.62, dr=0.004)
    O.sur_dessus(g, c, 1, [math.radians(a) for a in (190, 215, 245, 295, 325, 350, 160, 20)], _relais, t=0.55)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        p = corps.place(c, nom)
        x, y = p["x"] - sx * 0.05, Y(p["yn"] - 0.05)
        _anneau_relais(g, x, y, 0.36, M)
        liaison(g, [(x - sx * 0.3, y - 0.15, 0.15), (x * 0.66, Y(p["yn"] * 0.62), c.gradins[0][3] + 0.12),
                    (x * 0.42, Y(p["yn"] * 0.4), zp + 0.06)], 0.045)
        g.halo((x, y - 0.4, 0.4), M["_emit_rgb"], 5.0)
    for (x, yn) in ((0.0, -2.6), (-2.2, -1.0), (2.2, -1.0)):
        g.halo((x, Y(yn), 0.3), M["_emit_rgb"], 5.0)


def piece(g, c):
    """Niveau 28 : deux RELAIS DE LA PORTE (petits anneaux dressés, horizon étoilé plein) aux coins avant, patin de
    tôles indigo relié au premier gradin."""
    M = g.M
    p = corps.place(c, "coin_SE")
    for sx in (-1, 1):
        x, yn = sx * p["x"], p["yn"]
        corps.patin(g, c, x - sx * 0.15, yn + 0.15, 1.1, 1.1, rz=sx * 0.785)
        g.push((0, 0, 0.035))
        _anneau_relais(g, x, Y(yn), 0.42, M)
        g.pop()
        g.halo((x, Y(yn - 0.4), 0.4), M["_emit_rgb"], 5.0)


def arriere(g, c):
    """Caisson bas indigo à OMBILICAUX à rotules blanc lunaire et grille."""
    M = g.M
    t = c.T["tete"]
    zb = O.zb(c)
    bx, y0, y1, z1 = t["bx"], t["yb0"], t["yb1"], t["zb1"]
    T = PT.hull(g, -bx, bx, y0, y1, zb, z1 - 0.1, ins=(0.04, 0.05, 0.0), panel=0.26,
                mats=[M["indigo_nuit"], M["indigo_nuit2"]], rivet_step=0.13)
    g.grille(PT.lift(PT.face_quad([V((-bx, y0, zb)), V((bx, y0, zb)), T[1], T[0]], 0.15, 0.85, 0.2, 0.75), 0.01), 5,
             slat_mat=M["blanc_lunaire"])
    for sx in (-1, 1):
        liaison(g, [(sx * bx * 0.6, (y0 + y1) / 2, z1 - 0.1), (sx * bx * 0.9, y1, z1 - 0.02),
                    (sx * bx * 1.1, y1 + 0.2 * t["re"], zb + 0.1)], 0.035)


def tete(g, c):
    """Nœuds relais à l'arrière de la platine."""
    M = g.M
    zb = O.zb(c)
    for (x, y, w) in O.pods(c):
        g.cyl((x, y, zb + w * 0.3), "z", w * 0.9, w * 0.6, M["indigo_nuit2"], n=14, style="soft", what="socle")
        g.sphere((x, y, zb + w * 1.0), w * 0.6, M["blanc_lunaire"], n=14, m=7, what="noeud")
        g.sphere((x, y - w * 0.55, zb + w * 1.05), 0.02, M["emit"], n=6, m=4, what="point")


def emetteur(g, c):
    """La PORTE, dans le repère de l'anneau penché (corps.dans_anneau) : habillage blanc lunaire de l'anneau, 9
    CHEVRONS lumineux sur son pourtour, HORIZON ÉTOILÉ (disque indigo très sombre semé d'étoiles, anneau de lumière au
    bord) posé sur le diaphragme, IRIS central d'où sort le faisceau."""
    M = g.M
    re = c.re
    Ra, ra = corps.rayons_anneau(c)
    # ronde 1 (F1-B) : la face étoilée ne regardait que l'AVANT (le faisceau) ; en pose N la caméra voit le DOS de
    # l'anneau penché, et en pose E sa tranche : la Porte se lisait comme un grand disque sombre. Les DEUX faces portent
    # désormais l'horizon étoilé, l'anneau de lumière, les chevrons et l'iris ; l'anneau est blanc lunaire des deux côtés.
    yb = -(0.3 * re + 0.0175)          # dos du diaphragme en tambour de la lignée (corps.support)
    with corps.dans_anneau(g, c):
        for (sg, y0) in ((1.0, 0.0), (-1.0, yb)):
            yo = lambda t: y0 + sg * t   # noqa: E731
            g.torus((0, yo(0.03), 0), "y", Ra, ra * 0.95, M["blanc_lunaire"], n=64, m=10, what="anneau_lunaire")
            for k in range(9):
                a = math.pi / 2 + TAU * k / 9 + (0.0 if sg > 0 else TAU / 18)
                d = V((math.cos(a), 0.0, math.sin(a)))
                p = d * Ra + V((0, yo(ra * 0.95), 0))
                Rr = Matrix((V((-d.z, 0, d.x)), V((0, 1, 0)), -d)).transposed()
                g.box(p, (ra * 2.2, ra * 0.6, ra * 1.6), M["blanc_lunaire"], "hard", R=Rr, what="chevron_bloc")
                for s in (-1, 1):
                    q = p + V((0, sg * ra * 0.32, 0)) + V((-d.z, 0, d.x)) * (s * ra * 0.42) - d * (ra * 0.1)
                    g.box(q, (ra * 1.0, 0.012, ra * 0.28), M["emit"], "flat",
                          R=Rr @ Matrix.Rotation(s * 0.7, 3, "Y"), what="chevron")
            g.cyl((0, yo(0.03), 0), "y", Ra - ra * 0.4, 0.03, M["horizon_porte"], n=64, style="soft", what="horizon")
            g.torus((0, yo(0.05), 0), "y", Ra - ra * 0.75, 0.02, M["emit_soft"], n=64, m=4, what="bord_horizon")
            rng = random.Random(1414 if sg > 0 else 1415)
            for j in range(80):
                a = rng.uniform(0, TAU)
                rr = (Ra - ra * 1.1) * math.sqrt(rng.uniform(0.04, 1.0))
                s = rng.choice((0.01, 0.013, 0.017, 0.024))
                g.cyl((rr * math.cos(a), yo(0.05), rr * math.sin(a)), "y", s, 0.01, M["emit"], n=6, style="flat",
                      what="etoile")
            for j in range(5):
                a = rng.uniform(0, TAU)
                rr = (Ra - ra * 1.2) * math.sqrt(rng.uniform(0.2, 1.0))
                _etoile(g, (rr * math.cos(a), yo(0.055), rr * math.sin(a)), 0.08, M["emit"])
            # iris central (d'où sort le faisceau ; au dos, l'iris du foyer)
            g.tube_shell((0, yo(0.06), 0), "y", 0.2 * re, 0.13 * re, 0.04, M["blanc_lunaire"], n=32, what="iris")
            g.cyl((0, yo(0.07), 0), "y", 0.12 * re, 0.012, M["emit2"], n=24, style="flat", what="pupille")
