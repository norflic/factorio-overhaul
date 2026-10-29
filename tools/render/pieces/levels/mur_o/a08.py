"""Mur · Âge 8 · MARAIS (ère III). MUR-OPUS, 29/10. S'exécute DANS Blender.

Une digue de pierre de marais : gros blocs verdâtres en assises réglées mais de longueurs inégales (chaque bloc taillé,
légèrement de travers), mortier sombre et humide, mousse sur les lits et au pied, eau qui noircit le bas du mur.
Couronnement en TOIT DE CUIVRE vert-de-gris (deux pentes, joints debout, faîtage roulé) : la ligne de faîte est un toit,
pas des créneaux. Contreforts de pierre au milieu des cases, gargouille de cuivre au joint de case (coulure verte).
Extrémités et angles : TOUR RONDE à toit conique de cuivre, hublot de verre où luit la lumière acide de l'âge (famille
« jaune-vert acide »). Même ADN que la mitrailleuse validée de l'âge 8 (dallage vert de pierre, cuivre vert-de-gris,
dôme jaune-vert).
"""
import math

import geo
from geo import surface

EPOQUE = 8
NOM = "Marais"
Z_W, Z_R = 1.10, 1.32          # haut de la maçonnerie, faîtage du toit
HW0, HW1 = 0.46, 0.36
ASSISES = (0.0, 0.2, 0.37, 0.53, 0.68, 0.82, 0.96, Z_W)
SQ2 = math.sqrt(2.0)


def hw(z):
    return HW0 + (HW1 - HW0) * z / Z_W


def mats(S):
    M = {}
    M["pierre"] = surface("m8_pierre", (0.13, 0.15, 0.12), (0.075, 0.085, 0.07), rough=0.9, var=0.7, var_scale=7.0,
                          grain=0.25, bump=0.8, bump_scale=35.0, edge=((0.27, 0.29, 0.24), 0.55, 0.035), cavity=0.6,
                          cavity_dist=0.08, streak=0.4, top=((0.10, 0.20, 0.035), 0.85, 0.45),
                          bottom=((0.025, 0.03, 0.022), 0.45, 0.75), seed=3.0)
    M["pierre2"] = surface("m8_pierre2", (0.16, 0.165, 0.14), (0.09, 0.095, 0.08), rough=0.9, var=0.7, var_scale=6.0,
                           grain=0.25, bump=0.8, bump_scale=30.0, edge=((0.30, 0.31, 0.27), 0.55, 0.035), cavity=0.6,
                           cavity_dist=0.08, streak=0.4, top=((0.10, 0.20, 0.035), 0.85, 0.45),
                           bottom=((0.025, 0.03, 0.022), 0.45, 0.75), seed=9.0)
    M["mortier"] = surface("m8_mortier", (0.035, 0.04, 0.032), rough=0.95, var=0.3, grain=0.2, bump=0.4, cavity=0.3,
                           top=((0.06, 0.12, 0.02), 0.7, 0.4))
    M["cuivre"] = surface("m8_cuivre", (0.10, 0.27, 0.20), (0.055, 0.16, 0.12), rough=0.55, rough2=0.8, metal=0.35,
                          var=0.8, var_scale=8.0, grain=0.2, bump=0.3, bump_scale=90.0,
                          edge=((0.42, 0.19, 0.08), 0.7, 0.025), cavity=0.45, streak=0.35)
    M["cuivre_sombre"] = surface("m8_cuivre2", (0.05, 0.13, 0.10), (0.11, 0.06, 0.03), rough=0.6, metal=0.4, var=0.6,
                                 grain=0.2, edge=((0.45, 0.22, 0.09), 0.8, 0.02), cavity=0.4)
    M["mousse"] = surface("m8_mousse", (0.06, 0.14, 0.02), (0.03, 0.07, 0.012), rough=1.0, var=0.8, var_scale=12.0,
                          grain=0.35, bump=1.0, bump_scale=120.0, cavity=0.5, spec=0.2)
    M["vide"] = surface("m8_vide", (0.006, 0.008, 0.005), rough=1.0, var=0.0, grain=0.0, bump=0.0, cavity=0.0, spec=0.0)
    M["verre"] = geo.emissive(S, "m8_verre", (0.6, 1.0, 0.04), strength=5.0, base=(0.04, 0.06, 0.01))
    return M


def _bloc(g, M, x0, x1, z0, z1, k, tilt):
    """Un bloc taillé : enveloppe d'une boîte aux sommets légèrement déplacés, face avant bombée."""
    yb, yt = hw(z0) * k + 0.012, hw(z1) * k + 0.012
    j = 0.012
    pts = []
    for (x, z, yy) in ((x0, z0, yb), (x1, z0, yb), (x0, z1, yt), (x1, z1, yt)):
        pts.append((x + g.rnd(-j, j), -yy + g.rnd(-0.01, 0.006), z + g.rnd(-j, j) * 0.5))
        pts.append((x + g.rnd(-j, j), yy - g.rnd(-0.01, 0.006), z + g.rnd(-j, j) * 0.5))
    # bombé de la face avant et des faces latérales
    xm, zm = 0.5 * (x0 + x1), 0.5 * (z0 + z1)
    b = 0.018 + tilt
    pts.append((xm, -(hw(zm) * k + 0.012 + b), zm))
    pts.append((xm, (hw(zm) * k + 0.012 + b), zm))
    return g.hull(pts, M["pierre"] if g.rnd() < 0.55 else M["pierre2"], bev=0.012, seg=2)


def _maconnerie(g, M, B):
    """Assises réglées (hauteurs fixes : raccords), blocs de longueurs inégales ; joint imposé aux bords de case."""
    k = B.k
    for r in range(len(ASSISES) - 1):
        z0, z1 = ASSISES[r] + 0.006, ASSISES[r + 1] - 0.006
        # coupes en tuiles : joint obligé à 0,5 (bord de case) ; décalage d'une assise sur l'autre
        t = B.t0 + (0.0 if r % 2 else -0.11)
        cuts = []
        while t < B.t1:
            cuts.append(t)
            t += g.rnd(0.17, 0.30)
        cuts.append(B.t1)
        if B.cote != "S":
            cuts = sorted(set([c for c in cuts if abs(c - 0.5) > 0.06] + [0.5]))
        for a, b in zip(cuts[:-1], cuts[1:]):
            sp = B.span(a, b)
            if not sp:
                continue
            xa, xb = B.x(sp[0]), min(B.x(sp[1]), B.L)
            ia = 0.007 if sp[0] > B.t0 + 1e-3 else 0.0
            ib = 0.007 if sp[1] < B.t1 - 1e-3 else 0.0
            _bloc(g, M, xa + ia, xb - ib, z0, z1, k, g.rnd(0.0, 0.012))


def _toit(g, M, x0, x1, k, seams=True):
    """Toit de cuivre à deux pentes sur le mur, débord, joints debout et faîtage roulé."""
    e = 0.05
    g.prism([(-(HW1 + 0.07) * k, Z_W - 0.02), ((HW1 + 0.07) * k, Z_W - 0.02), ((HW1 + 0.07) * k, Z_W + 0.02),
             (0.0, Z_R), (-(HW1 + 0.07) * k, Z_W + 0.02)], x0, x1, M["cuivre"], bev=0.008)
    g.cyl((0.5 * (x0 + x1), 0, Z_R + 0.002), "x", 0.03, x1 - x0, M["cuivre"], n=12, bev=0)
    if seams:
        n = max(1, int(round((x1 - x0) / 0.125)))
        for i in range(n + 1):
            x = x0 + i * (x1 - x0) / n
            if i in (0, n):
                continue
            for s in (-1, 1):
                ya, yb = s * (HW1 + 0.07) * k, s * 0.02
                g.loft_z([(x - 0.008, min(ya, yb)), (x + 0.008, min(ya, yb)), (x + 0.008, max(ya, yb)),
                          (x - 0.008, max(ya, yb))], Z_W + 0.02, Z_W + 0.05, M["cuivre_sombre"], bev=0)
    # chéneau (gouttière) sous le débord avant
    g.cyl((0.5 * (x0 + x1), -(HW1 + 0.08) * k, Z_W - 0.035), "x", 0.03, x1 - x0, M["cuivre_sombre"], n=10, bev=0)


def bras(g, M, B):
    k, x0, L = B.k, B.x0, B.L
    S_ = B.cote == "S"
    # âme de mortier (continue ; se voit dans les joints)
    g.prism([(-(HW0 - 0.01) * k, 0.0), ((HW0 - 0.01) * k, 0.0), ((HW1 - 0.01) * k, Z_W), (-(HW1 - 0.01) * k, Z_W)],
            x0, L, M["mortier"], bev=0)
    _maconnerie(g, M, B)
    _toit(g, M, x0, L, k)
    # gargouille de cuivre au joint de case et coulure verte (face avant ; les deux flancs du bras sud)
    tj = 0.5
    xj = B.x(tj)
    for s in ((-1, 1) if S_ else (-1,)):
        g.push(g.Sc(1, s, 1))
        y = -(HW1 + 0.06) * k
        g.cyl((xj, y - 0.06, Z_W - 0.09), "y", 0.028, 0.16, M["cuivre"], n=10, r2=0.022, bev=0)
        g.box(xj - 0.03, xj + 0.03, y - 0.004, y + 0.03, Z_W - 0.14, Z_W - 0.04, M["cuivre_sombre"], bev=0.004)
        g.pop()
    # touffes de mousse au pied
    if not S_:
        for t in (0.18, 0.41):
            x = B.x(t) + g.rnd(-0.04, 0.04)
            _mousse(g, M, x, -(HW0 * k + 0.01), 0.0, 0.09)


def _mousse(g, M, x, y, z, r):
    pts = []
    for i in range(14):
        a = g.rnd(0, 2 * math.pi)
        rr = r * g.rnd(0.4, 1.0)
        pts.append((x + rr * math.cos(a), y + 0.8 * rr * math.sin(a), z + g.rnd(0, r * 0.7)))
    g.hull(pts, M["mousse"], bev=0.01, seg=2)


def _contrefort(g, M):
    """Contrefort de pierre au milieu de la case, hublot à lumière acide cerclé de cuivre."""
    k = SQ2
    yb = -(HW0 + 0.13) * k
    for (z0, z1, d0, d1, w) in ((0.0, 0.42, 0.13, 0.11, 0.13), (0.42, 0.82, 0.10, 0.05, 0.115)):
        pa = [(-w, -(HW0 + d0) * k), (w, -(HW0 + d0) * k), (w, -0.1 * k), (-w, -0.1 * k)]
        pb = [(-w + 0.01, -(hw(z1) + d1) * k), (w - 0.01, -(hw(z1) + d1) * k), (w - 0.01, -0.1 * k),
              (-w + 0.01, -0.1 * k)]
        g.loft_z(pa, z0, z1, M["pierre2"], poly1=pb, bev=0.015)
        g.box(-w - 0.012, w + 0.012, -(hw(z1) + d1 + 0.02) * k, -0.1 * k, z1, z1 + 0.035, M["pierre"], bev=0.01)
    # hublot (dans la maçonnerie, au-dessus du contrefort)
    yf = -(hw(0.95) + 0.012) * k
    g.cyl((0, yf - 0.004, 0.95), "y", 0.07, 0.03, M["cuivre"], n=20, bev=0.004)
    g.cyl((0, yf - 0.02, 0.95), "y", 0.05, 0.012, M["verre"], n=20, bev=0)
    for a in range(6):
        ang = a * math.pi / 3
        g.rivets([(0.072 * math.cos(ang), yf - 0.022, 0.95 + 0.072 * math.sin(ang), "y")], 0.008, M["cuivre_sombre"])
    _mousse(g, M, 0.04, -(HW0 + 0.1) * k, 0.0, 0.1)


def _tour(g, M):
    """Tour ronde de pierre, toit conique de cuivre, hublot."""
    R0, R1, zt = 0.48, 0.44, 1.30
    g.cyl((0, 0, 0.06), "z", R0 + 0.03, 0.12, M["pierre2"], n=40, r2=R0 + 0.01, bev=0.01)
    # assises de la tour : anneaux de blocs
    zs = (0.12, 0.33, 0.52, 0.70, 0.87, 1.04, 1.20, zt)
    for i in range(len(zs) - 1):
        z0, z1 = zs[i] + 0.006, zs[i + 1] - 0.006
        r0 = R0 + (R1 - R0) * (z0 / zt)
        r1 = R0 + (R1 - R0) * (z1 / zt)
        nb = 9
        ph = (0.5 if i % 2 else 0.0) + g.rnd(-0.1, 0.1)
        for j in range(nb):
            a0 = (j + ph) * 2 * math.pi / nb + 0.025
            a1 = (j + 1 + ph) * 2 * math.pi / nb - 0.025
            pts = []
            for a in (a0, 0.5 * (a0 + a1), a1):
                for (z, r) in ((z0, r0), (z1, r1)):
                    bulge = 0.012 if a == 0.5 * (a0 + a1) else 0.0
                    pts.append(((r + bulge) * math.cos(a), (r + bulge) * math.sin(a), z))
                    pts.append(((r - 0.12) * math.cos(a), (r - 0.12) * math.sin(a), z))
            g.hull(pts, M["pierre"] if g.rnd() < 0.5 else M["pierre2"], bev=0.01, seg=2)
    g.cyl((0, 0, 0.5 * zt), "z", R1 - 0.02, zt - 0.02, M["mortier"], n=32, bev=0)
    # corniche et toit conique
    g.cyl((0, 0, zt + 0.02), "z", R1 + 0.06, 0.04, M["pierre2"], n=40, bev=0.01)
    g.cyl((0, 0, zt + 0.08), "z", R1 + 0.09, 0.08, M["cuivre"], n=40, r2=R1 + 0.05, bev=0.006)
    g.cyl((0, 0, zt + 0.12 + 0.27), "z", R1 + 0.05, 0.54, M["cuivre"], n=40, r2=0.03, bev=0.004)
    # nervures du toit
    for j in range(12):
        a = j * 2 * math.pi / 12
        p0 = ((R1 + 0.055) * math.cos(a), (R1 + 0.055) * math.sin(a), zt + 0.12)
        p1 = (0.04 * math.cos(a), 0.04 * math.sin(a), zt + 0.64)
        v = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
        ln = math.sqrt(sum(c * c for c in v))
        o = g.cyl((0, 0, 0), "z", 0.012, ln, M["cuivre_sombre"], n=6, bev=0)
        import mathutils
        rot = mathutils.Vector((0, 0, 1)).rotation_difference(mathutils.Vector(v).normalized()).to_matrix().to_4x4()
        o.data.transform(mathutils.Matrix.Translation(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2))
                         @ rot)
    # épi de faîtage : boule de verre acide dans une cage de cuivre
    g.cyl((0, 0, zt + 0.70), "z", 0.012, 0.14, M["cuivre_sombre"], n=8, bev=0)
    g.sphere((0, 0, zt + 0.80), 0.045, M["verre"])
    # hublot sur la face avant
    g.cyl((0, -R1 - 0.005, 0.86), "y", 0.08, 0.04, M["cuivre"], n=20, bev=0.004)
    g.cyl((0, -R1 - 0.025, 0.86), "y", 0.058, 0.012, M["verre"], n=20, bev=0)
    for a in range(8):
        ang = a * math.pi / 4
        g.rivets([(0.082 * math.cos(ang), -R1 - 0.028, 0.86 + 0.082 * math.sin(ang), "y")], 0.008, M["cuivre_sombre"])
    # mousse au pied
    _mousse(g, M, -0.3, -0.32, 0.0, 0.12)
    _mousse(g, M, 0.33, -0.25, 0.0, 0.09)


def noeud(g, M, forme, bras):
    if forme in ("single", "corR", "corL", "endR", "endL"):
        _tour(g, M)
    elif forme == "horiz":
        _contrefort(g, M)
