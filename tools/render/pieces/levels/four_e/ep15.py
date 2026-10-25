"""Four · Âge 15 · Néant (ère V, 6×6, niveaux 29 et 30). Lot F2-A (25/10) ; fiche : FICHES_FOUR.md, âge 15. S'exécute
DANS Blender.

En 3 mots : « étoile captive, vasque noire, griffes d'or ». La chambre est une FORGE DE SINGULARITÉ (« un Big Bang tenu
en laisse ») : sur un double socle rond de noir chaud cerclé d'or, un fût évasé porte une grande VASQUE NOIRE veinée
d'or (lèvre d'or, incandescence au bord intérieur) ; dedans, une ÉTOILE CAPTIVE blanc-or ; cinq GRIFFES D'OR montent de
la lèvre et se referment au-dessus d'elle ; à l'arrière droit, un obélisque de noir chaud veiné d'or (la fumée).
Palette 60/30/10 (ages.PALETTE[15]) : noir chaud / or chauffé / lumière incandescente blanc-or vers orange.
"""
import math

import ages
import corps
import formes as F
from kit import TAU
from repere import Y

EPOQUE = 15
NOM = ages.NOMS[15]
TRIPLET = ("étoile captive", "vasque noire", "griffes d'or")
FOYER = ages.FOYER[15]
HABILLAGE = dict(ages.CORPS[15], gueule="arche", foyer="noir_profond")
CYN = 0.3
PROFIL = ((0.46, 1.7), (0.75, 1.95), (1.15, 2.2), (1.55, 2.45), (1.85, 2.68), (2.0, 2.85))   # (rayon, z) de la vasque
R_ETOILE, Z_ETOILE = 0.58, 3.0


def matieres(metal, M):
    ages.matieres(15, metal, M)


def chambre(g, c):
    M = g.M
    zs = c.T["sole_h"]
    cy = Y(CYN)
    g.cyl((0, cy, (zs + 0.45) / 2), "z", 2.65, 0.45 - zs, M["noir_chaud"], n=64, what="socle")
    g.torus((0, cy, 0.45), "z", 2.63, 0.035, M["or_chauffe"], n=64, m=6, what="liseré")
    for k in range(28):
        a = math.pi + math.pi * (k + 0.5) / 28
        g.dome((2.5 * math.cos(a), cy + 2.5 * math.sin(a), 0.45), (0, 0, 1), 0.022, M["cendre"])
    g.cyl((0, cy, 0.62), "z", 2.05, 0.34, M["noir_chaud2"], n=64, what="socle2")
    g.torus((0, cy, 0.79), "z", 2.04, 0.03, M["or_vif"], n=64, m=6, what="liseré")
    for k in range(18):
        a = TAU * k / 18
        g.box((2.06 * math.cos(a), cy + 2.06 * math.sin(a), 0.62), (0.05, 0.03, 0.26), M["emit"], "flat",
              R=corps.Matrix.Rotation(a + math.pi / 2, 3, "Z"), what="tiret")
    # fût évasé à veines d'or
    g.cyl((0, cy, 1.25), "z", 0.75, 0.9, M["noir_profond"], n=40, r2=0.46, what="fut")
    for k in range(10):
        a = TAU * k / 10
        g.tube([corps.V((0.755 * math.cos(a), cy + 0.755 * math.sin(a), 0.8)),
                corps.V((0.465 * math.cos(a), cy + 0.465 * math.sin(a), 1.7))], 0.02, M["or_chauffe"], n=5,
               what="veine")
    # vasque : coque ouverte, fond intérieur, veines, lèvre, incandescence
    rs = [r for r, _ in PROFIL]
    zz = [z for _, z in PROFIL]
    corps.tube_v(g, 0.0, CYN, rs, zz, M["noir_chaud"], n=56, caps=False, what="vasque")
    g.cyl((0, cy, 2.3), "z", 1.2, 0.03, M["noir_profond"], n=40, what="fond")
    for k in range(14):
        a = TAU * k / 14
        pts = [corps.V(((r + 0.006) * math.cos(a), cy + (r + 0.006) * math.sin(a), z)) for r, z in PROFIL]
        g.tube(g.spline(pts, 3), 0.018, M["or_chauffe"], n=5, what="veine")
    g.torus((0, cy, zz[-1]), "z", rs[-1], 0.075, M["or_chauffe"], n=72, m=8, what="levre")
    g.torus((0, cy, zz[-1] - 0.05), "z", rs[-1] - 0.12, 0.035, M["emit_soft"], n=64, m=5, what="incandescence")
    # étoile captive
    F.sphere(g, (0, cy, Z_ETOILE), R_ETOILE, M["emit"], n=32, m=16)
    griffes(g, c)
    g.halo((0, cy - 0.9, Z_ETOILE), M["_emit_rgb"], 9.0)


def griffes(g, c):
    M = g.M
    cy = Y(CYN)
    for a_deg in (90.0, 200.0, 250.0, 292.0, 340.0):
        a = math.radians(a_deg)
        prof = ((1.97, 2.86), (1.82, 3.15), (1.45, 3.45), (1.0, 3.58), (0.68, 3.5), (0.5, 3.3))
        pts = [corps.V((r * math.cos(a), cy + r * math.sin(a), z)) for r, z in prof]
        P = g.spline(pts, 4)
        radii = [0.1 - 0.075 * i / (len(P) - 1) for i in range(len(P))]
        g.tube(P, 0.1, M["or_chauffe"], n=8, radii=radii, what="griffe")
        g.tube(P[-5:], 0.03, M["or_blanc_chaud"], n=6, radii=[0.04, 0.035, 0.03, 0.028, 0.025], what="ongle")
        g.dome(pts[0] + corps.V((0, 0, 0.05)), (0, 0, 1), 0.06, M["or_rivet"], n=8)


def gueule(g, c, G):
    M = g.M
    zr = G.get("zr", (G["bz0"] + G["bz1"]) / 2)
    R = G["bx1"] + 0.1
    n = 14
    pts = [corps.V((R * math.cos(math.pi * k / n), G["yf"] - 0.04, zr + R * math.sin(math.pi * k / n)))
           for k in range(n + 1)]
    g.tube(pts, 0.04, M["or_chauffe"], n=8, what="arche_or")
    for p in pts[1:-1:2]:
        g.dome(p + corps.V((0, -0.035, 0)), (0, -1, 0), 0.025, M["emit"], n=6)


def fumee(g, c):
    M = g.M
    x, yn = 2.3, 1.9
    y = Y(yn)
    z0, z1 = c.T["sole_h"], 2.6
    g.cyl((x, y, (z0 + z1) / 2), "z", 0.32, z1 - z0, M["noir_chaud"], n=4, r2=0.2, phase=math.pi / 4, style="hard",
          what="obelisque")
    for k in range(4):
        a = math.pi / 4 + TAU * k / 4
        if math.sin(a) > 0.2:
            continue
        g.tube([corps.V((x + 0.3 * math.cos(a), y + 0.3 * math.sin(a), 0.4)),
                corps.V((x + 0.2 * math.cos(a), y + 0.2 * math.sin(a), z1 - 0.1))], 0.016, M["or_chauffe"], n=5,
               what="veine")
    g.cyl((x, y, z1 - 0.15), "z", 0.215, 0.06, M["emit"], n=4, phase=math.pi / 4, style="hard", what="liseré")
    g.cyl((x, y, z1 + 0.03), "z", 0.24, 0.06, M["or_chauffe"], n=4, phase=math.pi / 4, style="hard", what="tete")
    corps.bouche_fumee(g, c, x, yn, z1 + 0.06, 0.15)


def piece(g, c):
    """Petites étoiles captives dans des griffes d'or, sur piédestaux de noir chaud."""
    M = g.M
    zs = c.T["sole_h"] + 0.03
    for nom in ("coin_SO", "coin_SE"):
        p = corps.coin(c, nom)
        corps.patin(g, c, p["x"], p["yn"], 2 * p["rw"] * 0.9, p["prof"] * 0.85)
        for dx in (-0.45, 0.45):
            x, y = p["x"] + dx, Y(p["yn"])
            g.cyl((x, y, zs + 0.12), "z", 0.22, 0.24, M["noir_chaud"], n=24, r2=0.16, what="piedestal")
            g.torus((x, y, zs + 0.24), "z", 0.17, 0.02, M["or_chauffe"], n=24, m=5, what="liseré")
            g.cyl((x, y, zs + 0.32), "z", 0.1, 0.16, M["noir_chaud2"], n=20, r2=0.2, what="coupe")
            F.sphere(g, (x, y, zs + 0.46), 0.12, M["emit"], n=16, m=8)
            for k in range(3):
                a = TAU * k / 3 + 0.5
                pts = [corps.V((x + r * math.cos(a), y + r * math.sin(a), z)) for r, z in
                       ((0.2, zs + 0.4), (0.18, zs + 0.52), (0.1, zs + 0.6))]
                g.tube(g.spline(pts, 3), 0.025, M["or_chauffe"], n=6, radii=[0.03 - 0.02 * i / 6 for i in range(7)],
                       what="griffe")
