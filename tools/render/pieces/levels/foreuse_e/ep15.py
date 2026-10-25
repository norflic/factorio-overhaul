"""Foreuse · Âge 15 · Néant (ère V, 6×6, niveaux 29 et 30). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « singularité, spirale d'or, couronne noire ». Une SINGULARITÉ (sphère noir profond) plane au-dessus du puits,
tenue par une COURONNE NOIRE de 8 griffes recourbées ; autour d'elle, un disque d'accrétion d'or chauffé dont les bras
lumineux dessinent une SPIRALE D'OR ; des filets d'or aspirés montent du tablier vers le disque. Lumière incandescente
blanc-or vers orange, en disque (ère V). Palette (ages.PALETTE[15]) : noir chaud / or chauffé / lumière incandescente.
"""
import math

import ages
import corps as cp

EPOQUE = 15
NOM = ages.NOMS[15]
TRIPLET = ("singularité", "spirale d'or", "couronne noire")
FOYER = ages.FOYER[15]
HABILLAGE = dict(ages.CORPS[15], forme_tablier="octogone")
PIED = 1.02


def occupe(c):
    """Sources des filets d'or aspirés."""
    out = []
    r0 = c.a * 0.82
    for k in range(5):
        ang = k * math.tau / 5 + 0.4
        x, y = r0 * math.cos(ang), r0 * math.sin(ang)
        out.append((x - 0.2, y - 0.2, x + 0.2, y + 0.2))
    return out


def matieres(metal, M):
    ages.matieres(15, metal, M)


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    rs = rt * 0.52
    zs = H - rs - 0.02
    # socle noir à 8 pans et anneau de base des griffes
    cp.colonne(g, 0, 0, zt, zt + 0.2, rt * 0.95, M["noir_chaud"], n=8, phase=math.pi / 8, style="hard", what="socle")
    g.torus((0, 0, zt + 0.24), "z", rt * 0.82, 0.07, M["or_chauffe"], n=48, m=8, what="anneau_or")
    # 8 griffes recourbées de la base au bas de la sphère
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        ca, sa = math.cos(a), math.sin(a)
        pts = [(rt * 0.85 * ca, rt * 0.85 * sa, zt + 0.2), (rt * 1.0 * ca, rt * 1.0 * sa, zt + 0.9),
               (rs * 1.25 * ca, rs * 1.25 * sa, zs - rs * 0.6), (rs * 0.75 * ca, rs * 0.75 * sa, zs - rs * 0.75)]
        g.tube(g.spline(pts, 8), 0.09, M["noir_profond"], n=8, radii=None, what="griffe")
        g.sphere(pts[1], 0.1, M["noir_chaud2"], n=10, m=6, what="articulation")
        g.box((pts[1][0], pts[1][1], pts[1][2] + 0.11), (0.05, 0.05, 0.02), M["or_rivet"], "hard", what="rivet_or")
    # disque d'accrétion (touche la sphère : aucun jour), spirale lumineuse
    cp.colonne(g, 0, 0, zs - 0.025, zs + 0.025, rt * 1.0, M["or_chauffe"], n=64, what="disque")
    for bras in range(3):
        for i in range(14):
            t = i / 13.0
            ang = bras * math.tau / 3 + t * 2.4
            rr = rs * 1.02 + (rt * 0.96 - rs * 1.02) * t
            g.box((rr * math.cos(ang), rr * math.sin(ang), zs + 0.03), (0.13 - 0.05 * t, 0.13 - 0.05 * t, 0.012),
                  M["emit"] if i % 2 == 0 else M["emit2"], "flat", what="spirale")
    g.torus((0, 0, zs), "z", rt * 1.0, 0.035, M["or_blanc_chaud"], n=64, m=6, what="bord_disque")
    g.sphere((0, 0, zs), rs, M["noir_profond"], n=40, m=20, what="singularite")
    cp.bague(g, 0, 0, zs, rs, 0.02, M["emit"], ep=0.015, n=40, what="horizon")
    cp.halo(g, (0, -rt * 1.1, zs), M, 6.0)
    cp.halo(g, (0, rt * 0.5, zs + 0.1), M, 3.0, cle="_emit2_rgb")


def trepan(g, c):
    """Le puits est la base de la singularité : dalle noire à fente d'or."""
    M = g.M
    cp.bague(g, 0, 0, c.zt + 0.02, c.rw * 0.85, 0.03, M["emit2"], ep=0.02, n=32, what="fente_or")


def socle(g, c):
    M = g.M
    a, zt, rt = c.a, c.zt, c.rt
    zs = c.H - rt * 0.52 - 0.02
    # filets d'or aspirés du tablier vers le disque
    for k in range(5):
        ang = k * math.tau / 5 + 0.4
        r0 = a * 0.82
        pts = [(r0 * math.cos(ang), r0 * math.sin(ang), zt + 0.01)]
        for j in range(1, 5):
            t = j / 4.0
            rr = r0 + (rt * 1.0 - r0) * t
            ag = ang + 0.7 * t
            pts.append((rr * math.cos(ag), rr * math.sin(ag), zt + (zs - zt) * t * t))
        g.tube(g.spline(pts, 6), 0.02, M["or_vif"], n=6, what="filet")
        g.cyl(pts[0], "z", 0.08, 0.015, M["emit2"], n=10, style="flat", what="source")


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r, M["noir_chaud2"], fl_mat=M["or_chauffe"], bolt_mat=M["or_rivet"], what="raccord")


def piece(g, c):
    """Couronne d'or à 8 pointes posée sur la singularité."""
    M = g.M
    z = c.H
    g.torus((0, 0, z + 0.03), "z", 0.2, 0.035, M["or_chauffe"], n=32, m=8, what="cercle")
    g.sphere((0, 0, z - 0.02), 0.19, M["noir_profond"], n=24, m=8, scale=(1, 1, 0.45), what="calotte")   # ronde 1
    for k in range(8):
        a = math.tau * k / 8
        g.cyl((0.2 * math.cos(a), 0.2 * math.sin(a), z + 0.13), "z", 0.035, 0.2, M["or_blanc_chaud"], n=6, r2=0.004,
              style="hard", what="pointe")
    g.sphere((0, 0, z + 0.08), 0.06, M["emit"], n=12, m=6, what="joyau")
    cp.halo(g, (0, -0.25, z + 0.1), M, 3.0)
