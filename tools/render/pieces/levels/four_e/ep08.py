"""Four · Âge 8 · Marais (ère III, 4×4, niveaux 15 et 16). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 8. S'exécute
DANS Blender.

En 3 mots : « cloche de verre, bulles de gaz, tuyaux vert-de-gris ». La chambre est un DIGESTEUR À MÉTHANE : grande CLOCHE DE
VERRE vert acide posée sur un ponton de planches à PILOTIS, nervures et ceinture de vert-de-gris, bulles et nappe de GAZ
JAUNE lumineux dans le verre, chapeau de cuivre terni à volant ; gros TUYAUX VERT-DE-GRIS couchés sur la cloche et
au pied ; tonneaux et cordages sur le ponton ; à l'arrière droit, le BRÛLEUR de méthane (tuyau dressé, flamme jaune-
vert : la fumée).
Palette 60/30/10 (ages.PALETTE[8]) : vert-de-gris / bois flotté et cuivre terni / jaune toxique.
"""
import math

import ages
import corps
import formes as F
import parts2 as P2
from kit import TAU
from repere import Y

EPOQUE = 8
NOM = ages.NOMS[8]
TRIPLET = ("cloche de verre", "bulles de gaz", "tuyaux vert-de-gris")
FOYER = ages.FOYER[8]
HABILLAGE = dict(ages.CORPS[8], gueule="ronde", foyer="cuivre_terni")
Z_PONT = 0.45
CX, CYN, RB, SZ = -0.15, 0.35, 1.3, 1.12


def matieres(metal, M):
    ages.matieres(8, metal, M)


def surf(a, phi, dr=0.0):
    """Point de la cloche à l'azimut a et à la latitude phi (0 = base), rayon + dr."""
    cy = Y(CYN)
    r = RB + dr
    return corps.V((CX + r * math.cos(phi) * math.cos(a), cy + r * math.cos(phi) * math.sin(a),
                    Z_PONT + (RB * SZ + dr) * math.sin(phi)))


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    T = c.T
    # ponton : plancher, poutre de rive, pilotis en façade, ombre sous le plancher
    x0, x1, y0, y1 = -T["xa"], T["xa"], Y(T["y_av"] + 0.05), Y(T["y_ar"])
    g.box((0, (y0 + y1) / 2, (zs + Z_PONT - 0.12) / 2), (2 * T["xa"] - 0.1, y1 - y0 - 0.1, Z_PONT - 0.12 - zs),
          M["tablier"], "flat", what="dessous")
    P = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    corps.prisme(g, P, Z_PONT - 0.12, Z_PONT, M["bois_mouille"], style="hard", what="pont")
    corps._motif(g, M, c.pont, P, Z_PONT, 0.04, 8801)
    g.box((0, y0 - 0.02, Z_PONT - 0.08), (2 * T["xa"], 0.06, 0.1), M["bois_mousse"], "hard", what="rive")
    for k in range(11):
        x = x0 + 0.1 + (x1 - x0 - 0.2) * k / 10
        g.cyl((x, y0 + 0.02, (zs + Z_PONT - 0.06) / 2), "z", 0.075, Z_PONT - 0.06 - zs, M["bois_mousse"], n=10,
              what="pilotis")
        g.tube_shell((x, y0 + 0.02, zs + 0.12), "z", 0.085, 0.06, 0.04, M["cuivre_terni"], n=10, what="bague")
    cloche(g, c)
    # tonneaux et cordages
    for (x, yn) in ((-1.55, -1.1), (-1.25, -1.2), (1.45, -0.6)):
        F.stave_barrel(g, (x, Y(yn), Z_PONT), 0.15, 0.32, M["bois_mouille"], M["cuivre_terni"])
    for (x, yn) in ((1.5, -1.15), (-1.6, 0.9)):
        for k in range(3):
            g.torus((x, Y(yn), Z_PONT + 0.025 + 0.035 * k), "z", 0.13 - 0.02 * k, 0.022, M["canvas"], n=16, m=6,
                    what="cordage")


def cloche(g, c):
    M = g.M
    cy = Y(CYN)
    F.sphere(g, (CX, cy, Z_PONT), RB, M["verre_toxique"], n=40, m=20, sz=SZ)
    # nappe de gaz lumineux et bulles affleurantes
    zl = Z_PONT + 0.32
    rl = RB * math.sqrt(max(0.0, 1 - ((zl - Z_PONT) / (RB * SZ)) ** 2))
    g.torus((CX, cy, zl), "z", rl + 0.004, 0.035, M["emit_soft"], n=40, m=6, what="nappe")
    for k, (a_deg, phi, rb) in enumerate(((230, 0.5, 0.17), (265, 0.35, 0.13), (300, 0.62, 0.15), (250, 0.85, 0.11),
                                          (325, 0.3, 0.12), (205, 0.25, 0.1), (285, 1.05, 0.12), (215, 0.95, 0.09))):
        p = surf(math.radians(a_deg), phi, -0.62 * rb)
        F.sphere(g, p, rb, M["emit_soft"], n=12, m=6)
    # nervures et ceinture de vert-de-gris, chapeau de cuivre
    for k in range(8):
        a = TAU * k / 8 + 0.2
        pts = [surf(a, 0.02 + 1.42 * i / 9, 0.012) for i in range(10)]
        g.tube(pts, 0.035, M["vdg_capot"], n=8, what="nervure")
    g.torus((CX, cy, Z_PONT + 0.05), "z", RB + 0.02, 0.075, M["vdg_capot"], n=48, m=8, what="ceinture")
    for k in range(20):
        a = math.pi + math.pi * (k + 0.5) / 20
        g.dome((CX + (RB + 0.09) * math.cos(a), cy + (RB + 0.09) * math.sin(a), Z_PONT + 0.05),
               (math.cos(a), math.sin(a), 0.2), 0.018, M["cuivre_terni"])
    zt = Z_PONT + RB * SZ
    g.cyl((CX, cy, zt + 0.02), "z", 0.3, 0.12, M["cuivre_terni"], n=24, what="chapeau")
    g.cyl((CX, cy, zt + 0.12), "z", 0.12, 0.1, M["vdg_capot"], n=16, what="col")
    P2.handwheel(g, (CX, cy, zt + 0.2), (0, 0, 1), 0.1, M, mat=M["cuivre_terni"])
    # gros tuyaux vert-de-gris couchés sur la cloche (ouest et sud-est), puis au pied
    for a_deg in (205.0, 320.0):
        a = math.radians(a_deg)
        pts = [surf(a, 1.35 - 1.3 * i / 7, 0.07) for i in range(8)]
        pts.append(pts[-1] + corps.V((math.cos(a) * 0.25, math.sin(a) * 0.25, -0.05)))
        g.pipe(pts, 0.06, M["vdg_capot"], fl_mat=M["cuivre_terni"], bolt_mat=M["cuivre_terni"])
    g.halo((CX, cy - 1.0, 1.0), M["_emit_rgb"], 6.0)


def fumee(g, c):
    M = g.M
    x, yn = 1.18, 0.95
    y = Y(yn)
    z0, z1 = Z_PONT, 2.85
    g.cyl((x, y, z0 + 0.06), "z", 0.22, 0.12, M["cuivre_terni"], n=16, what="embase")
    g.cyl((x, y, (z0 + z1) / 2), "z", 0.12, z1 - z0, M["vdg_capot"], n=18, what="bruleur")
    for z in (1.0, 1.6, 2.2):
        g.tube_shell((x, y, z), "z", 0.145, 0.1, 0.05, M["cuivre_terni"], n=18, what="bague")
    g.cyl((x, y, z1 + 0.06), "z", 0.17, 0.12, M["cuivre_terni"], n=18, what="tete")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.12, 0.14)
    g.cyl((x, y, z1 + 0.27), "z", 0.11, 0.3, M["emit"], n=12, r2=0.0, style="soft", what="flamme")
    g.halo((x, y - 0.2, z1 + 0.25), M["_emit_rgb"], 4.0)
    g.pipe([(CX + 1.0, Y(CYN) + 0.4, Z_PONT + 0.08), (x - 0.3, y - 0.1, Z_PONT + 0.1), (x, y - 0.15, Z_PONT + 0.3)],
           0.055, M["vdg_capot"], fl_mat=M["cuivre_terni"])


def piece(g, c):
    """Bonbonnes de gaz dans des paniers d'osier."""
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        for dx in (-0.22, 0.22):
            x, y = p["x"] + dx, Y(p["yn"])
            F.sphere(g, (x, y, zs + 0.22), 0.19, M["verre_toxique"], n=18, m=10)
            g.cyl((x, y, zs + 0.11), "z", 0.2, 0.22, M["wicker"], n=18, what="panier")
            g.cyl((x, y, zs + 0.45), "z", 0.05, 0.1, M["verre_toxique"], n=10, what="col")
            g.cyl((x, y, zs + 0.51), "z", 0.055, 0.03, M["wood"], n=10, what="bouchon")
            F.sphere(g, (x + 0.06, y - 0.15, zs + 0.27), 0.07, M["emit_soft"], n=10, m=6)
            g.torus((x, y, zs + 0.24), (1, 0, 0), 0.2, 0.012, M["wicker"], n=14, m=4, what="anse")
