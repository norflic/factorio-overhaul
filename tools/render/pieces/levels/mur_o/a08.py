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
Z_W, Z_R = 0.90, 1.04          # haut de la maçonnerie, faîtage du chaperon de cuivre (essai e2 : section en coin)
HW0, HW1 = 0.46, 0.17
ASSISES = (0.0, 0.17, 0.32, 0.46, 0.59, 0.71, 0.81, Z_W)
SQ2 = math.sqrt(2.0)


def hw(z):
    return HW0 + (HW1 - HW0) * z / Z_W


RIV = 0.016


def mats(S):
    M = {}
    M["pierre"] = surface("m8_pierre", (0.095, 0.11, 0.085), (0.05, 0.06, 0.045), rough=0.9, var=0.7, var_scale=7.0,
                          grain=0.25, bump=0.8, bump_scale=35.0, edge=((0.27, 0.29, 0.24), 0.55, 0.035), cavity=0.75,
                          cavity_dist=0.08, streak=0.4, top=((0.10, 0.20, 0.035), 0.75, 0.32),
                          bottom=((0.005, 0.006, 0.004), 0.20, 1.0), seed=3.0,
                          stain=((0.03, 0.04, 0.025), 0.5, 5.0))
    M["pierre2"] = surface("m8_pierre2", (0.12, 0.125, 0.10), (0.065, 0.07, 0.055), rough=0.9, var=0.7, var_scale=6.0,
                           grain=0.25, bump=0.8, bump_scale=30.0, edge=((0.30, 0.31, 0.27), 0.55, 0.035), cavity=0.75,
                           cavity_dist=0.08, streak=0.4, top=((0.10, 0.20, 0.035), 0.75, 0.32),
                           bottom=((0.005, 0.006, 0.004), 0.20, 1.0), seed=9.0,
                           stain=((0.035, 0.03, 0.02), 0.5, 4.0))
    M["mortier"] = surface("m8_mortier", (0.035, 0.04, 0.032), rough=0.95, var=0.3, grain=0.2, bump=0.4, cavity=0.3,
                           top=((0.06, 0.12, 0.02), 0.7, 0.4))
    M["cuivre"] = surface("m8_cuivre", (0.16, 0.42, 0.31), (0.08, 0.24, 0.17), rough=0.55, rough2=0.8, metal=0.35,
                          var=0.8, var_scale=8.0, grain=0.2, bump=0.3, bump_scale=90.0,
                          edge=((0.45, 0.22, 0.09), 0.75, 0.02), cavity=0.45, streak=0.35,
                          stain=((0.18, 0.36, 0.28), 0.45, 6.0))
    M["cuivre_sombre"] = surface("m8_cuivre2", (0.05, 0.13, 0.10), (0.11, 0.06, 0.03), rough=0.6, metal=0.4, var=0.6,
                                 grain=0.2, edge=((0.45, 0.22, 0.09), 0.8, 0.02), cavity=0.4)
    M["chaperon"] = surface("m8_chaperon", (0.40, 0.42, 0.34), (0.24, 0.26, 0.20), rough=0.92, var=0.7,
                            var_scale=7.0, grain=0.28, bump=0.8, bump_scale=40.0, edge=((0.36, 0.38, 0.33), 0.6, 0.02),
                            cavity=0.55, streak=0.4, top=((0.16, 0.30, 0.06), 0.45, 0.35),
                            stain=((0.04, 0.05, 0.03), 0.5, 5.0))
    M["coulee"] = surface("m8_coulee", (0.10, 0.30, 0.22), (0.05, 0.16, 0.12), rough=0.5, var=0.8, var_scale=12.0,
                          grain=0.3, bump=0.3, cavity=0.2, spec=0.6)
    M["verre"] = surface("m8_verre_v", (0.09, 0.19, 0.03), (0.05, 0.11, 0.018), rough=0.06, rough2=0.12, spec=1.0,
                         var=0.5, var_scale=6.0, grain=0.05, bump=0.05, cavity=0.2,
                         edge=((0.6, 0.8, 0.35), 0.4, 0.02))
    M["liquide"] = geo.emissive(S, "m8_liquide", (0.66, 1.0, 0.23), strength=0.5, base=(0.05, 0.09, 0.01))
    M["verre_sombre"] = surface("m8_verre_s", (0.03, 0.06, 0.02), rough=0.08, spec=1.0, var=0.3, grain=0.05,
                                bump=0.0, cavity=0.0)
    M["mousse"] = surface("m8_mousse", (0.06, 0.14, 0.02), (0.03, 0.07, 0.012), rough=1.0, var=0.8, var_scale=12.0,
                          grain=0.35, bump=1.0, bump_scale=120.0, cavity=0.5, spec=0.2)
    M["vide"] = surface("m8_vide", (0.006, 0.008, 0.005), rough=1.0, var=0.0, grain=0.0, bump=0.0, cavity=0.0, spec=0.0)
    return M


def _bloc(g, M, x0, x1, z0, z1, k, tilt):
    """Un bloc taillé : enveloppe d'une boîte aux sommets légèrement déplacés, face avant bombée."""
    yb, yt = hw(z0) * k + 0.012, hw(z1) * k + 0.012
    j = 0.012
    pts = []
    for (x, z, yy) in ((x0, z0, yb), (x1, z0, yb), (x0, z1, yt), (x1, z1, yt)):
        pts.append((x + g.rnd(-j, j), -yy + g.rnd(-0.01, 0.006), z + g.rnd(-j, j) * 0.5))
        pts.append((x + g.rnd(-j, j), yy - g.rnd(-0.01, 0.006), z + g.rnd(-j, j) * 0.5))
    # face avant taillée : un léger bossage plat (4 points en retrait des arêtes, en saillie de tilt)
    zm0, zm1 = z0 + 0.3 * (z1 - z0), z0 + 0.7 * (z1 - z0)
    xm0, xm1 = x0 + 0.25 * (x1 - x0), x1 - 0.25 * (x1 - x0)
    for (x, z) in ((xm0, zm0), (xm1, zm0), (xm0, zm1), (xm1, zm1)):
        pts.append((x, -(hw(z) * k + 0.012 + 0.006 + tilt * g.rnd(0.3, 1.0)), z))
    return g.hull(pts, M["pierre"] if g.rnd() < 0.55 else M["pierre2"], bev=0.016, seg=2)


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
    """Chaperon de pierre moussue à deux pentes, faîtière de cuivre vert-de-gris (couvre-joints debout)."""
    hc = HW1 + 0.045
    g.prism([(-hc * k, Z_W - 0.02), (hc * k, Z_W - 0.02), (hc * k, Z_W + 0.025), (0.06 * k, Z_R - 0.03),
             (-0.06 * k, Z_R - 0.03), (-hc * k, Z_W + 0.025)], x0, x1, M["chaperon"], bev=0.012)
    # faîtière de cuivre (petit toit sur l'arête) et boudin
    g.prism([(-0.085 * k, Z_R - 0.045), (0.085 * k, Z_R - 0.045), (0.085 * k, Z_R - 0.03), (0.0, Z_R + 0.02),
             (-0.085 * k, Z_R - 0.03)], x0, x1, M["cuivre"], bev=0.004)
    g.cyl((0.5 * (x0 + x1), 0, Z_R + 0.02), "x", 0.022, x1 - x0, M["cuivre"], n=10, bev=0)
    if seams:
        n = max(1, int(round((x1 - x0) / 0.125)))
        for i in range(1, n):
            x = x0 + i * (x1 - x0) / n
            g.prism([(-0.095 * k, Z_R - 0.05), (0.095 * k, Z_R - 0.05), (0.0, Z_R + 0.035)], x - 0.014, x + 0.014,
                    M["cuivre_sombre"], bev=0, ends=True)


def bras(g, M, B):
    k, x0, L = B.k, B.x0, B.L
    S_ = B.cote == "S"
    # âme de mortier (continue ; se voit dans les joints)
    g.prism([(-(HW0 - 0.01) * k, 0.0), ((HW0 - 0.01) * k, 0.0), ((HW1 - 0.01) * k, Z_W), (-(HW1 - 0.01) * k, Z_W)],
            x0, L, M["mortier"], bev=0)
    _maconnerie(g, M, B)
    _toit(g, M, x0, L, k)
    # contrefort de pierre au joint de case (v3 : DANS le pied, aucune saillie au sud du pied ; moitié par case)
    if B.t0 < 0.5 < B.t1:
        xj = B.x(0.5)
        for s in ((1, -1) if S_ else (1,)):
            g.push(g.Sc(1, s, 1))
            zt = 0.74
            pa = [(xj - 0.11, -HW0 * k), (xj + 0.11, -HW0 * k), (xj + 0.11, -0.1 * k), (xj - 0.11, -0.1 * k)]
            pb = [(xj - 0.06, -(hw(zt) + 0.07) * k), (xj + 0.06, -(hw(zt) + 0.07) * k), (xj + 0.06, -0.1 * k),
                  (xj - 0.06, -0.1 * k)]
            g.loft_z(pa, 0.0, zt, M["pierre2"], poly1=pb, bev=0.012)
            g.box(xj - 0.075, xj + 0.075, -(hw(zt) + 0.09) * k, -0.1 * k, zt, zt + 0.035, M["chaperon"], bev=0.008)
            g.pop()
    for s_ in ((1, -1) if S_ else (1,)):
        g.push(g.Sc(1, s_, 1))
        geo.eboulis(g, (M["pierre"], M["pierre2"], M["mousse"]), max(x0, 0.0), L - B.eps, -HW0 * k - 0.01, 3, r=0.035)
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
    """Contrefort de pierre à deux ressauts au milieu de la case, tirant de cuivre riveté, mousse au pied."""
    k = SQ2
    for (z0, z1, d0, d1, w) in ((0.0, 0.40, 0.11, 0.08, 0.12), (0.40, 0.76, 0.07, 0.03, 0.10)):
        pa = [(-w, -(hw(z0) + d0) * k), (w, -(hw(z0) + d0) * k), (w, -0.1 * k), (-w, -0.1 * k)]
        pb = [(-w + 0.01, -(hw(z1) + d1) * k), (w - 0.01, -(hw(z1) + d1) * k), (w - 0.01, -0.1 * k),
              (-w + 0.01, -0.1 * k)]
        g.loft_z(pa, z0, z1, M["pierre2"], poly1=pb, bev=0.015)  # (v2, non utilisé en v3)
        g.box(-w - 0.012, w + 0.012, -(hw(z1) + d1 + 0.025) * k, -0.1 * k, z1, z1 + 0.035, M["pierre"], bev=0.01)
    # tirant de cuivre (plaque rivetée) sur le ressaut haut
    y = -(hw(0.58) + 0.055) * k
    g.box(-0.075, 0.075, y - 0.018, y + 0.02, 0.52, 0.64, M["cuivre"], bev=0.005)
    g.rivets([(x, y - 0.02, z, "y") for x in (-0.05, 0.05) for z in (0.55, 0.61)], RIV, M["cuivre_sombre"])
    _mousse(g, M, 0.04, -(HW0 + 0.09) * k, 0.0, 0.1)


def _gargouille(g, M):
    """Variante du segment droit : gargouille de cuivre au milieu, coulée verte de vert-de-gris, mousse épaisse."""
    k = SQ2
    y = -(HW1 + 0.05) * k
    g.cyl((0, y - 0.09, Z_W - 0.07), "y", 0.04, 0.22, M["cuivre"], n=12, r2=0.03, bev=0)
    g.box(-0.05, 0.05, y - 0.004, y + 0.04, Z_W - 0.15, Z_W - 0.01, M["cuivre_sombre"], bev=0.004)
    g.rivets([(x, y - 0.006, z, "y") for x in (-0.03, 0.03) for z in (Z_W - 0.12, Z_W - 0.04)], RIV,
             M["cuivre_sombre"])
    # coulée de vert-de-gris le long du talus (plaque mince qui suit la pente)
    for (z0, z1, w) in ((0.30, Z_W - 0.16, 0.035), (0.10, 0.30, 0.05)):
        pa = [(-w, -(hw(z0) * k + 0.004)), (w, -(hw(z0) * k + 0.004)), (w, -(hw(z0) * k - 0.02)),
              (-w, -(hw(z0) * k - 0.02))]
        pb = [(-w * 0.7, -(hw(z1) * k + 0.004)), (w * 0.7, -(hw(z1) * k + 0.004)), (w * 0.7, -(hw(z1) * k - 0.02)),
              (-w * 0.7, -(hw(z1) * k - 0.02))]
        g.loft_z(pa, z0, z1, M["coulee"], poly1=pb, bev=0)
    _mousse(g, M, -0.05, -(HW0 + 0.02) * k, 0.0, 0.13)
    _mousse(g, M, 0.12, -(HW0 + 0.0) * k, 0.0, 0.08)


def _tour(g, M):
    """Tour ronde de pierre en talus, toit conique de cuivre à nervures, hublot et épi à lumière acide."""
    R0, R1, zt, HT = 0.47, 0.37, 1.04, 0.42
    g.cyl((0, 0, 0.05), "z", R0 + 0.03, 0.10, M["pierre2"], n=40, r2=R0 + 0.01, bev=0.01)
    zs = (0.10, 0.27, 0.43, 0.58, 0.72, 0.85, 0.95, zt)
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
                    bulge = 0.014 if a == 0.5 * (a0 + a1) else 0.0
                    pts.append(((r + bulge) * math.cos(a), (r + bulge) * math.sin(a), z))
                    pts.append(((r - 0.12) * math.cos(a), (r - 0.12) * math.sin(a), z))
            g.hull(pts, M["pierre"] if g.rnd() < 0.5 else M["pierre2"], bev=0.01, seg=2)
    g.cyl((0, 0, 0.5 * zt), "z", R1 - 0.02, zt - 0.02, M["mortier"], n=32, bev=0)
    # corniche, égout et toit conique
    g.cyl((0, 0, zt + 0.02), "z", R1 + 0.05, 0.04, M["pierre2"], n=40, bev=0.01)
    g.cyl((0, 0, zt + 0.07), "z", R1 + 0.08, 0.06, M["cuivre"], n=40, r2=R1 + 0.05, bev=0.006)
    g.cyl((0, 0, zt + 0.10 + HT / 2), "z", R1 + 0.05, HT, M["cuivre"], n=40, r2=0.03, bev=0.004)
    import mathutils
    for j in range(12):
        a = j * 2 * math.pi / 12
        p0 = ((R1 + 0.055) * math.cos(a), (R1 + 0.055) * math.sin(a), zt + 0.10)
        p1 = (0.04 * math.cos(a), 0.04 * math.sin(a), zt + 0.10 + HT)
        v = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
        ln = math.sqrt(sum(c * c for c in v))
        o = g.cyl((0, 0, 0), "z", 0.014, ln, M["cuivre_sombre"], n=6, bev=0)
        rot = mathutils.Vector((0, 0, 1)).rotation_difference(mathutils.Vector(v).normalized()).to_matrix().to_4x4()
        o.data.transform(mathutils.Matrix.Translation(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2,
                                                         (p0[2] + p1[2]) / 2)) @ rot)
    # épi de faîtage : boule de verre acide
    g.cyl((0, 0, zt + 0.10 + HT + 0.05), "z", 0.014, 0.10, M["cuivre_sombre"], n=8, bev=0)
    g.sphere((0, 0, zt + 0.10 + HT + 0.12), 0.04, M["verre"])
    # hublot sur la face avant (dans le talus)
    zh = 0.70
    rh = R0 + (R1 - R0) * (zh / zt)
    g.cyl((0, -rh - 0.005, zh), "y", 0.075, 0.04, M["cuivre"], n=20, bev=0.004)
    g.cyl((0, -rh - 0.025, zh), "y", 0.052, 0.012, M["verre_sombre"], n=20, bev=0)
    for a in range(8):
        ang = a * math.pi / 4
        g.rivets([(0.075 * math.cos(ang), -rh - 0.028, zh + 0.075 * math.sin(ang), "y")], 0.013, M["cuivre_sombre"])
    _mousse(g, M, -0.3, -0.32, 0.0, 0.12)
    _mousse(g, M, 0.33, -0.25, 0.0, 0.09)


def _panneau(g, M, xc=0.0, w=0.28, z0=0.28, z1=0.62):
    """Panneau de verre épais à sommet bombé dans le talus (DA époque 8) : armature vert-de-gris de 3 px, verre vert
    (#8FBF4A), liquide luminescent dans le bas du verre (lueur fixe, ≤ 10 % de la surface)."""
    k = SQ2

    def contour(dw, dz, n=9):
        pts = [(xc - w - dw, z0 - dz), (xc + w + dw, z0 - dz)]
        r = w + dw
        for i in range(n + 1):
            a = i * math.pi / n
            pts.append((xc + r * math.cos(a), z1 + 0.45 * r * math.sin(a) + dz))
        return pts

    def coque(pts, d0, d1):
        out = []
        for (x, z) in pts:
            y = hw(z) * k
            out.append((x, -(y + d0), z))
            out.append((x, -(y - d1), z))
        return out
    g.hull(coque(contour(0.045, 0.045), 0.012, 0.03), M["cuivre"], bev=0.006, seg=1)
    g.hull(coque(contour(0.0, 0.0), 0.024, 0.0), M["verre"], bev=0.01, seg=2)
    # liquide luminescent : bande basse du verre
    liq = [(xc - w + 0.04, z0 + 0.03), (xc + w - 0.04, z0 + 0.03), (xc + w - 0.04, z0 + 0.09), (xc - w + 0.04, z0 + 0.09)]
    g.hull(coque(liq, 0.030, 0.0), M["liquide"], bev=0, seg=1)
    # rivets de l'armature
    g.rivets([(xc + sx * (w + 0.022), -(hw(z) * k + 0.016), z, "y") for sx in (-1, 1) for z in (z0 + 0.05, z1 - 0.02)],
             0.016, M["cuivre_sombre"])


def _bulbe(g, M):
    """Extrémité : fût bas de pierre cerclé de vert-de-gris et BULBE de verre (Ø ≈ 30 px) au liquide luminescent."""
    ky = SQ2
    g.cyl((0, 0, 0.36), "z", 0.44, 0.72, M["pierre"], n=32, r2=0.36, bev=0.01)
    for z in (0.24, 0.66):
        r = 0.44 + (0.36 - 0.44) * (z / 0.72)
        g.cyl((0, 0, z), "z", r + 0.02, 0.05, M["cuivre"], n=32, bev=0.004)
    g.cyl((0, 0, 0.75), "z", 0.30, 0.06, M["cuivre"], n=32, r2=0.26, bev=0.004)
    g.sphere((0, 0, 0.98), 0.235, M["verre"], seg=32, rings=16)
    g.sphere((0, 0, 0.90), 0.242, M["liquide"], seg=32, rings=12, sz=0.42)   # ceinture de liquide qui affleure
    # armature : 4 côtes de vert-de-gris sur le bulbe et chapeau
    import mathutils
    for j in range(4):
        a = j * math.pi / 2 + math.pi / 4
        o = g.S.torus(0.24, 0.014, (0, 0, 0.98), M["cuivre_sombre"], rot=(math.pi / 2, 0, a), major_seg=40, minor_seg=6)
    g.cyl((0, 0, 1.22), "z", 0.05, 0.04, M["cuivre"], n=16, bev=0.003)
    _mousse(g, M, -0.3, -0.3, 0.0, 0.11)
    _mousse(g, M, 0.32, -0.22, 0.0, 0.08)
    geo.eboulis(g, (M["pierre"], M["pierre2"], M["mousse"]), -0.35, 0.35, -0.45, 3, r=0.035)


def _pile(g, M):
    """Angle : pile de blocs au même talus que le mur, chapeau pyramidal de cuivre (≤ +15 % de la crête)."""
    ky = SQ2
    a0, a1 = HW0 + 0.01, HW1 + 0.03

    def carre(h):
        return [(-h, -h * ky), (h, -h * ky), (h, h * ky), (-h, h * ky)]
    g.loft_z(carre(a0), 0.0, Z_W, M["pierre2"], poly1=carre(a1), bev=0.016)
    g.loft_z(carre(a1 + 0.05), Z_W - 0.01, Z_W + 0.03, M["chaperon"], poly1=carre(a1 + 0.04), bev=0.01)
    g.loft_z(carre(a1 + 0.03), Z_W + 0.03, Z_R + 0.08, M["cuivre"], poly1=carre(0.02), bev=0.004)


def noeud(g, M, forme, bras):
    if forme in ("single", "endR", "endL"):
        _bulbe(g, M)
    elif forme in ("corR", "corL"):
        _pile(g, M)
    elif forme == "horiz":
        _panneau(g, M)
    elif forme == "horiz2":
        _panneau(g, M)
        _gargouille(g, M)
    elif forme == "horiz3":
        _panneau(g, M, w=0.24, z1=0.58)
        _mousse(g, M, -0.2, -(HW0 + 0.02) * SQ2, 0.0, 0.12)
        _mousse(g, M, 0.25, -(HW0 + 0.0) * SQ2, 0.0, 0.09)
