"""Four · Âge 5 · Volcan (ère II, 3×3, niveaux 9 et 10). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 5. S'exécute DANS
Blender.

En 3 mots : « cratère, coulées de lave, blocs de basalte ». La chambre est un VOLCAN-CREUSET : cône raide de basalte
rugueux (surface irrégulière), CRATÈRE au sommet empli de lave (croûtes sombres qui flottent), deux ceintures de fonte
boulonnées, COULÉES DE LAVE qui descendent la pente sud jusqu'au foyer, BLOCS DE BASALTE au pied ; à l'arrière droit
une FUMEROLLE en orgues basaltiques (prismes à 6 pans de hauteurs inégales, évent rougeoyant) : la fumée.
Palette 60/30/10 (ages.PALETTE[5]) : basalte noir / fonte rouille brûlée / lave orange (braise vive, très saturée).
"""
import math

import ages
import corps
import formes as F
from kit import TAU
from repere import Y

EPOQUE = 5
NOM = ages.NOMS[5]
TRIPLET = ("cratère", "coulées de lave", "blocs de basalte")
FOYER = ages.FOYER[5]
HABILLAGE = dict(ages.CORPS[5], gueule="arche", foyer="fonte_noire")
CYN = 0.25
R0, R1, Z1 = 1.3, 0.72, 1.4


def matieres(metal, M):
    ages.matieres(5, metal, M)


def r_cone(z, zs):
    return R0 + (R1 - R0) * (z - zs) / (Z1 - zs)


def cone(g, c, n=15):
    """Cône rugueux plein : anneaux bruités, lèvre du cratère, paroi intérieure, fond (sous la lave)."""
    M = g.M
    zs = c.T["sole_h"]
    y0 = Y(CYN)
    zl = [zs, 0.36, 0.64, 0.92, 1.18, Z1]
    rings = [(r_cone(z, zs), z, 0.07) for z in zl]
    rings += [(R1 - 0.1, Z1 + 0.04, 0.03), (R1 - 0.2, 1.25, 0.02)]
    vs = []
    for (r, z, j) in rings:
        for k in range(n):
            a = TAU * k / n + 0.13 * (len(vs) % 3)
            rr = r * (1.0 + j * (g.rng.random() * 2 - 1))
            vs.append((rr * math.cos(a), y0 + rr * math.sin(a), z + (0.03 * (g.rng.random() - 0.5) if z > zs else 0)))
    m = len(rings)
    fs = [tuple(range(n))[::-1]]
    for i in range(m - 1):
        for k in range(n):
            k2 = (k + 1) % n
            fs.append((i * n + k, i * n + k2, (i + 1) * n + k2, (i + 1) * n + k))
    fs.append(tuple(range((m - 1) * n, m * n)))
    g._add(M["basalte_capot"], "hard", vs, fs, "cone")
    # lave du cratère et croûtes
    g.cyl((0, y0, 1.27), "z", R1 - 0.17, 0.02, M["emit"], n=24, style="flat", what="lave")
    for k in range(5):
        a = TAU * k / 5 + 0.4
        F.lump(g, (0.28 * math.cos(a), y0 + 0.24 * math.sin(a), 1.27), 0.08, M["basalte_dalle2"], sz=0.25)


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    y0 = Y(CYN)
    cone(g, c)
    # ceintures de fonte boulonnées
    for z in (0.45, 0.98):
        r = r_cone(z, zs) + 0.03
        g.torus((0, y0, z), "z", r, 0.045, M["fonte_v"], n=40, m=6, what="ceinture")
        for k in range(14):
            a = math.pi + math.pi * (k + 0.5) / 14
            g.bolt((r * math.cos(a), y0 + r * math.sin(a), z), (math.cos(a), math.sin(a), 0.3), 0.016,
                   M["fonte_noire"])
    # coulées de lave sur la pente sud (la plus longue descend au foyer)
    for a_deg, zf in ((236.0, 0.2), (258.0, 0.3), (282.0, 0.7), (306.0, 0.15), (322.0, 0.4)):
        a = math.radians(a_deg)
        pts = []
        for i in range(9):
            z = Z1 - 0.02 - (Z1 - zf) * i / 8
            r = r_cone(z, zs) + 0.015
            aa = a + 0.05 * math.sin(i * 1.9 + a_deg)
            pts.append((r * math.cos(aa), y0 + r * math.sin(aa), z))
        g.tube(g.spline(pts, 4), 0.032, M["emit"], n=7, style="soft", what="coulee")
    # blocs de basalte au pied et sur la pente
    for k in range(18):
        a = math.pi * 0.95 + math.pi * 1.1 * k / 17
        z = zs + 0.02 + 0.35 * (k % 3) * 0.5
        r = r_cone(z, zs) + 0.05
        F.lump(g, (r * math.cos(a), y0 + r * math.sin(a), z), 0.09 + 0.03 * (k % 2),
               M["basalte_dalle" if k % 2 else "basalte_dalle2"], sz=0.7, jit=0.3)
    g.halo((0, y0 - 0.2, 1.6), M["_emit_rgb"], 7.0)


def gueule(g, c, G):
    M = g.M
    for sx in (-1, 1):
        F.lump(g, (sx * (G["x1"] + 0.04), G["yf"] + 0.1, G["z0"] + 0.1), 0.14, M["basalte_capot"], sz=0.8, jit=0.3)
    for x in (-0.18, 0.05, 0.2):
        g.box((x, G["yf"] - 0.01, G["z1"] - 0.08), (0.03, 0.02, 0.12), M["emit"], "soft", what="goutte")


def fumee(g, c):
    """Fumerolle : orgues basaltiques (prismes à 6 pans) à l'arrière droit, évent rougeoyant."""
    M = g.M
    zs = c.T["sole_h"]
    f = c.T["fumee"]
    x, yn = f["x"], f["yn"] + 0.05
    y = Y(yn)
    for (dx, dyn, r, h) in ((-0.2, -0.05, 0.1, 1.45), (0.18, 0.02, 0.1, 1.7), (-0.05, 0.18, 0.11, 1.9),
                            (0.12, -0.16, 0.09, 1.25), (-0.17, 0.15, 0.09, 1.6)):
        g.cyl((x + dx, y + Y(dyn), (zs + h) / 2), "z", r, h - zs, M["basalte_capot"], n=6, phase=0.3, style="hard",
              what="orgue")
        g.cyl((x + dx, y + Y(dyn), h + 0.015), "z", r * 0.9, 0.03, M["basalte_dalle2"], n=6, phase=0.3, style="hard",
              what="tete")
    zt = 2.2
    g.cyl((x, y, (zs + zt) / 2), "z", 0.14, zt - zs, M["basalte_dalle"], n=6, phase=0.1, style="hard", what="orgue")
    g.torus((x, y, zt - 0.03), "z", 0.12, 0.025, M["emit"], n=12, m=5, what="event")
    corps.bouche_fumee(g, c, x, yn, zt, 0.1)
    g.halo((x, y - 0.15, zt), M["_emit_rgb"], 3.0)


def piece(g, c):
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        x, y = p["x"], Y(p["yn"])
        for k in range(3):
            a = TAU * k / 3 + 0.5
            g.tube([corps.V((x + 0.2 * math.cos(a), y + 0.17 * math.sin(a), zs)), corps.V((x, y, zs + 0.34))], 0.022,
                   M["fonte_noire"], n=6, what="pied")
        g.cyl((x, y, zs + 0.38), "z", 0.21, 0.14, M["fonte_v"], n=18, r2=0.24, what="creuset")
        g.cyl((x, y, zs + 0.45), "z", 0.2, 0.012, M["emit"], n=18, style="flat", what="lave")
        g.torus((x, y, zs + 0.45), "z", 0.225, 0.02, M["fonte_noire"], n=18, m=5, what="levre")
        g.box((x + 0.24, y, zs + 0.43), (0.1, 0.05, 0.03), M["fonte_noire"], "hard", what="bec")
        F.lump(g, (x - 0.12, y - 0.18, zs), 0.07, M["basalte_capot"], sz=0.7)
