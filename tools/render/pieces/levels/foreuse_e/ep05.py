"""Foreuse · Âge 5 · Volcan (ère II, 4×4, niveaux 9 et 10). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « cloche blindée, lance thermique, scories ». Une CLOCHE BLINDÉE de basalte (tronc de cône à 8 pans, plaques à
rivets lourds, 8 nervures de fonte) couvre le puits ; une fente de lave court à son pied ; une LANCE THERMIQUE de
tungstène noirci la traverse et monte au sommet entre quatre pinces ; des rigoles de SCORIES rougeoyantes descendent du
pied de la cloche vers un creuset à l'angle avant gauche. Palette (ages.PALETTE[5]) : basalte noir / rouille brûlée
(fonte) / lave orange (la SATURATION la sépare de l'âge 4, la forme aussi : cloche pleine contre derrick ajouré).
"""
import math

import ages
import corps as cp

EPOQUE = 5
NOM = ages.NOMS[5]
TRIPLET = ("cloche blindée", "lance thermique", "scories")
FOYER = ages.FOYER[5]
HABILLAGE = dict(ages.CORPS[5])


def matieres(metal, M):
    ages.matieres(5, metal, M)


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    r0, r1 = rt * 1.08, rt * 0.52
    zc = zt + 0.56 * H
    # cloche à 8 pans
    g.cyl((0, 0, (zt + zc) / 2), "z", r0, zc - zt, M["basalte_capot"], n=8, r2=r1, style="hard", phase=math.pi / 8,
          what="cloche")
    for k in range(8):
        a = math.tau * k / 8
        ca, sa = math.cos(a), math.sin(a)
        p0 = (r0 * 1.02 * ca, r0 * 1.02 * sa, zt + 0.02)
        p1 = (r1 * 1.04 * ca, r1 * 1.04 * sa, zc)
        cp.poutre(g, p0, p1, 0.08, M["fonte_v"], "nervure", h=0.10)
        for t in (0.25, 0.5, 0.75):
            q = (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, p0[2] + (p1[2] - p0[2]) * t)
            g.dome(q, (ca, sa, 0.45), 0.03, M["burnrust"])
    # fente de lave au pied, couronne de fonte
    cp.bague(g, 0, 0, zt + 0.05, r0 * 0.98, 0.06, M["emit"], ep=0.03, n=8, what="fente_lave")
    cp.colonne(g, 0, 0, zc, zc + 0.10, r1 * 1.1, M["fonte_noire"], n=8, style="hard", phase=math.pi / 8, what="col")
    # lance thermique et 4 pinces
    cp.colonne(g, 0, 0, zc, H - 0.05, 0.075, M["fonte_noire"], n=8, style="hard", what="lance")
    for i in range(3):
        cp.bague(g, 0, 0, zc + 0.3 + i * (H - zc - 0.5) / 2.0, 0.075, 0.05, M["fonte_v"], ep=0.025, n=8,
                 what="collier")
    for k in range(4):
        p0 = cp.quart((r1 * 0.8, 0.0, zc + 0.10), k)
        p1 = cp.quart((0.10, 0.0, zc + 0.75), k)
        cp.poutre(g, p0, p1, 0.07, M["fonte_v"], "pince")
    g.cyl((0, 0, H - 0.02), "z", 0.12, 0.08, M["fonte_noire"], n=8, style="hard", what="tete_lance")
    g.cyl((0, 0, zc + 0.12), "z", 0.11, 0.04, M["emit"], n=12, style="flat", what="braise_lance")
    cp.halo(g, (0, -0.4, zc + 0.2), M, 3.0)


def trepan(g, c):
    """La lance thermique EST le trépan (tour) : rien de plus au puits."""
    return None


def socle(g, c):
    M = g.M
    a, zt, rt = c.a, c.zt, c.rt
    # creuset à scories (avant gauche) et rigoles de lave depuis la cloche
    cx, cy = -a * 0.6, -a * 0.55
    cp.colonne(g, cx, cy, zt, zt + 0.32, 0.26, M["fonte_noire"], n=12, r2=0.30, what="creuset")
    cp.colonne(g, cx, cy, zt + 0.30, zt + 0.33, 0.24, M["braise_sombre"], n=12, style="flat", what="croute")
    for k in range(3):
        g.box((cx + 0.06 * (k - 1), cy + 0.03 * k - 0.03, zt + 0.335), (0.22 - 0.05 * k, 0.025, 0.01), M["emit"],
              "flat", R=None, what="fissure")
    cp.halo(g, (cx, cy - 0.3, zt + 0.4), M, 4.0)
    for (ex, ey) in ((-rt * 0.75, -rt * 0.75), (-rt * 1.05, 0.0)):
        cp.poutre(g, (ex, ey, zt + 0.03), (cx + 0.12, cy + 0.12, zt + 0.05), 0.09, M["fonte_v"], "rigole", h=0.05)
        cp.poutre(g, (ex, ey, zt + 0.06), (cx + 0.12, cy + 0.12, zt + 0.08), 0.04, M["emit"], "lave", h=0.02)
    # tas de scories sombres
    for i, (dx, dy, r) in enumerate(((0.45, 0.2, 0.12), (0.55, 0.0, 0.09), (0.36, -0.08, 0.08))):
        g.sphere((cx + dx, cy + dy, zt + r * 0.3), r, M["braise_sombre"], n=7, m=5, scale=(1, 1, 0.5), what="scorie")


def liaison(g, pts, r):
    M = g.M
    P = g.tube(g.spline(pts, 8), r, M["fonte_noire"], n=10, what="conduit")[0]
    for i in range(2, len(P) - 1, 4):
        a = (P[min(len(P) - 1, i + 1)] - P[i - 1]).normalized()
        g.cyl(P[i], a, r * 1.25, r * 0.6, M["fonte_v"], n=10, style="hard", what="collier")


def piece(g, c):
    """Couronne de pointes de tungstène à fentes de braise sur la tête de lance."""
    M = g.M
    z = c.H + 0.06
    cp.colonne(g, 0, 0, z, z + 0.10, 0.17, M["fonte_noire"], n=8, style="hard", phase=math.pi / 8, what="couronne")
    cp.bague(g, 0, 0, z + 0.05, 0.17, 0.03, M["emit"], ep=0.012, n=8, what="fente")
    for k in range(8):
        a = math.tau * k / 8
        g.cyl((0.12 * math.cos(a), 0.12 * math.sin(a), z + 0.22), "z", 0.04, 0.24, M["fonte_noire"], n=6, r2=0.005,
              style="hard", what="pointe")
    g.cyl((0, 0, z + 0.32), "z", 0.06, 0.44, M["basalte_capot"], n=6, r2=0.005, style="hard", what="pointe_centrale")
    cp.halo(g, (0, -0.15, z + 0.1), M, 3.0)
