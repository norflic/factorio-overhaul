"""HAUT FOURNEAU (fo-blast-furnace), 4×4 (x ±2 ; y ±2,83). CONCEPT §1.

Lecture : la haute cuve tronconique cerclée (la plus haute de la famille), coiffée de 4 tubes de gaz en H et de leurs purgeurs ;
l'anneau porte-vent et la couronne de tuyères qui brillent ; le pont du skip en treillis qui monte au gueulard ; le(s) cowper(s) à
dôme ; au SUD, la rigole de fonte en fusion qui sort vers la poche (A), le wagon-torpille (B) ou le lit de coulée (C).
"""
import math

import commun as K
import geo as G
import outils as O

TAU = G.TAU
PALETTE = "four"            # commun.PALETTES ; « calcul » = palette des états clés du 3/11
SC = (0.15, 0.35)           # axe de la cuve
VAR = {
    "a": dict(cowpers=[(-1.4, 2.2)], pot=True, skip=((1.62, -2.42), (0.3, -0.3)), poche=True, torpille=False, lit=False,
              cheminee=None, bande=False, laitier=-1),
    "b": dict(cowpers=[(-1.4, 2.2), (1.45, 2.2)], pot=False, skip=((-1.65, -2.45), (-0.3, -0.3)), poche=False, torpille=True,
              lit=False, cheminee=None, bande=False, laitier=1),
    "c": dict(cowpers=[(-1.4, 2.2)], pot=False, skip=None, poche=False, torpille=False, lit=True, cheminee=(1.5, 2.05),
              bande=True, laitier=-1),
}
PROFIL = [(0.1, 0.86), (0.92, 0.86), (1.0, 0.9), (1.36, 1.02), (1.62, 1.02), (3.5, 0.72), (3.68, 0.6), (3.76, 0.52)]


def rayon(z):
    for (z0, r0), (z1, r1) in zip(PROFIL, PROFIL[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / max(1e-6, z1 - z0)
    return PROFIL[-1][1]


def cuve(lot, M):
    x, y = SC
    K.rev(lot, M["fonte"], x, y, PROFIL[:3], 40)
    K.rev(lot, M["acier"], x, y, PROFIL[2:], 40)
    # cerclages rivetés sur toute la hauteur
    for z in (0.3, 0.6, 1.12, 1.5, 1.85, 2.15, 2.45, 2.75, 3.05, 3.32):
        r = rayon(z)
        K.cerclage(lot, M["acier2"], x, y, z, r, 0.05, 0.024, 40)
        O.rivets_anneau(lot, M["riv"], (x, y, 0.0), r + 0.024, z, 30, 0.013)
    # plaques de refroidissement du creuset : rangées de tubulures d'eau
    for k in range(24):
        a = TAU * (k + 0.5) / 24
        for z in (0.42, 0.72):
            p = (x + 0.87 * math.cos(a), y + 0.87 * math.sin(a), z)
            lot.put(M["cuivre"], G.oriente(G.tour([(0.0, 0.022), (0.05, 0.022), (0.06, 0.012)], 6, "z", cap1=True), p, (math.cos(a), math.sin(a), 0.0)))
    # tubes d'eau des étalages (verticaux)
    for k in range(18):
        a = TAU * k / 18
        pts = [(x + (rayon(z) + 0.03) * math.cos(a), y + (rayon(z) + 0.03) * math.sin(a), z) for z in (1.02, 1.2, 1.36)]
        lot.put(M["acier_clair"], G.tube(pts, 0.014, 5))


def tuyeres(lot, M, n=12):
    """Anneau porte-vent, descentes et tuyères ; un regard orange au dos de chaque tuyère (la lueur de travail)."""
    x, y = SC
    zb, R = 1.6, 1.42
    O.anneau(lot, M["acier"], (x, y, zb), R, 0.13, 72, 12)
    for k in range(6):
        a = TAU * k / 6 + 0.3
        O.anneau(lot, M["acier2"], (x + R * math.cos(a), y + R * math.sin(a), zb), 0.15, 0.025, 14, 5, n=(-math.sin(a), math.cos(a), 0.0))
    for k in range(n):
        a = TAU * (k + 0.5) / n
        c, s = math.cos(a), math.sin(a)
        p0 = (x + R * c, y + R * s, zb - 0.1)
        p1 = (x + 1.32 * c, y + 1.32 * s, 1.12)
        p2 = (x + 1.08 * c, y + 1.08 * s, 0.9)
        p3 = (x + 0.9 * c, y + 0.9 * s, 0.84)
        lot.put(M["acier2"], G.tube(G.coudee([p0, p1, p2], 0.08, 4), 0.045, 8))
        lot.put(M["fonte"], G.tube([p2, p3], 0.035, 8))
        lot.put(M["acier_clair"], G.tube([G.add(p1, (0, 0, -0.04)), G.add(p2, (0, 0, 0.06))], 0.012, 4))
        # regard : disque incandescent au dos du coude
        q = (x + 1.37 * c, y + 1.37 * s, 1.16)
        lot.put(M["fonte"], G.oriente(G.tour([(0.0, 0.05), (0.035, 0.05), (0.04, 0.035)], 10, "z", cap1=True), q, (c, s, 0.55)))
        lot.put(M["fusion"], G.oriente(G.tour([(0.04, 0.032), (0.046, 0.0)], 10, "z"), q, (c, s, 0.55)))


def gueulard(lot, M, v):
    x, y = SC
    zt = 3.76
    # plate-forme octogonale du gueulard, garde-corps
    oc = [(x + 0.98 * math.cos(TAU * (k + 0.5) / 8), y + 0.98 * math.sin(TAU * (k + 0.5) / 8)) for k in range(8)]
    lot.put(M["acier2"], G.prisme(oc, zt - 0.05, zt))
    K.rambarde(lot, M["jaune"], oc + [oc[0]], zt, 0.26, 0.3)
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        lot.put(M["acier2"], G.tube([(x + 0.9 * math.cos(a), y + 0.9 * math.sin(a), zt - 0.04),
                                     (x + rayon(3.1) * math.cos(a), y + rayon(3.1) * math.sin(a), 3.1)], 0.022, 5))
    # trémie de réception et chevalement de la cloche
    K.rev(lot, M["acier"], x, y, [(zt, 0.34), (zt + 0.32, 0.34), (zt + 0.58, 0.52), (zt + 0.62, 0.53)], 28, cap=False)
    K.rev(lot, M["noir"], x, y, [(zt + 0.6, 0.5), (zt + 0.4, 0.2)], 24)
    K.cerclage(lot, M["acier2"], x, y, zt + 0.15, 0.34, 0.05, 0.02)
    for s in (-1, 1):
        lot.put(M["acier2"], G.tube([(x + s * 0.55, y - 0.05, zt), (x + s * 0.1, y - 0.05, zt + 1.25)], 0.028, 6))
        lot.put(M["acier2"], G.tube([(x + s * 0.55, y + 0.25, zt), (x + s * 0.1, y + 0.25, zt + 1.25)], 0.028, 6))
    lot.put(M["acier2"], G.boite((x, y + 0.1, zt + 1.27), (0.3, 0.42, 0.06)))
    lot.put(M["fonte"], G.tour([(y - 0.03, 0.12), (y + 0.03, 0.12)], 18, "y", (x, 0.0, zt + 1.36), cap0=True, cap1=True))
    # 4 tubes de gaz montants (en H), purgeurs au sommet
    tops = []
    for k in range(4):
        a = math.radians(45 + 90 * k)
        b = (x + 0.5 * math.cos(a), y + 0.5 * math.sin(a), 3.62)
        t = (x + 0.62 * math.cos(a), y + 0.62 * math.sin(a), 4.95)
        lot.put(M["acier"], G.tube([b, (b[0], b[1], 3.95), t], 0.1, 14))
        K.cerclage(lot, M["acier2"], t[0], t[1], 4.4, 0.1, 0.04, 0.018, 14)
        K.rev(lot, M["acier2"], t[0], t[1], [(4.95, 0.12), (5.0, 0.12), (5.04, 0.06), (5.25, 0.05), (5.28, 0.09), (5.32, 0.0)], 14)
        tops.append(t)
    zH = 4.72
    for i, j in ((0, 1), (2, 3)):
        lot.put(M["acier"], G.tube([(tops[i][0], tops[i][1], zH), (tops[j][0], tops[j][1], zH)], 0.09, 12))
    lot.put(M["acier"], G.tube([(x, tops[0][1], zH), (x, tops[3][1], zH)], 0.09, 12))
    return (x, tops[0][1], zH)


def skip(lot, M, pied, haut):
    """Pont du skip : poutre en treillis inclinée, chevalet, wagonnet, câble ; fosse et soutes au pied."""
    a = (pied[0], pied[1], 0.3)
    b = (haut[0], haut[1], 4.5)
    O.treillis(lot, M["acier2"], a, b, l=0.36, h=0.24, n=14, rc=0.022, rd=0.011)
    d = G.norm(G.sub(b, a))
    for s in (-1, 1):
        off = (-d[1] * s * 0.11 / max(0.3, math.hypot(d[0], d[1])), d[0] * s * 0.11 / max(0.3, math.hypot(d[0], d[1])), 0.14)
        lot.put(M["acier_clair"], G.tube([G.add(a, off), G.add(b, off)], 0.012, 5))
    # chevalet au tiers bas
    m = G.lerp(a, b, 0.38)
    for sx in (-1, 1):
        for sy in (-1, 1):
            lot.put(M["acier2"], G.tube([(m[0] + sx * 0.32, m[1] + sy * 0.32, 0.02), (m[0] + sx * 0.1, m[1] + sy * 0.1, m[2] - 0.1)], 0.026, 6))
    lot.put(M["acier2"], G.boite((m[0], m[1], m[2] - 0.12), (0.34, 0.34, 0.05)))
    for z in (0.6, 1.1):
        k = z / (m[2] - 0.1)
        w = 0.32 - 0.22 * k
        sq = [(m[0] - w, m[1] - w, z), (m[0] + w, m[1] - w, z), (m[0] + w, m[1] + w, z), (m[0] - w, m[1] + w, z)]
        lot.put(M["acier2"], G.tube(sq + [sq[0]], 0.012, 4))
    # wagonnet (benne) aux deux tiers
    p = G.lerp(a, b, 0.66)
    ang = math.atan2(d[1], d[0])
    lot.put(M["fonte"], G.boite(G.add(p, (0, 0, 0.26)), (0.3, 0.24, 0.2), ang - math.pi / 2, 0.0, 0.0))
    K.tas(lot, M["minerai"], G.add(p, (0, 0, 0.37)), 0.1, 0.08, 0.06, G.Rnd(71), 10, 0.02, 0.035)
    lot.put(M["acier_clair"], G.tube([G.add(p, (0, 0, 0.38)), G.add(b, (0, 0, 0.72))], 0.006, 3))
    # poulie de tête
    lot.put(M["fonte"], G.oriente(G.tour([(-0.04, 0.12), (0.04, 0.12)], 18, "z", cap0=True, cap1=True), G.add(b, (0, 0, 0.72)), (-d[1], d[0], 0.0)))
    lot.put(M["acier2"], G.tube([G.add(b, (0, 0, 0.1)), G.add(b, (0, 0, 0.7))], 0.025, 6))
    # fosse et soutes (coke, minerai) au pied
    K.caisson(lot, M["beton"], a[0], a[1] + 0.05, 0.0, 0.62, 0.62, 0.16, 0.03)
    for (dx, mat) in ((-0.32, "coke"), (0.32, "minerai")):
        bx = a[0] + dx * (1 if a[0] < 0 else -1)
        by = a[1] + 0.55
        K.rev(lot, M["acier"], bx, by, [(0.25, 0.06), (0.5, 0.2), (0.82, 0.2)], 4, cap=False)
        K.tas(lot, M[mat], (bx, by, 0.72), 0.14, 0.14, 0.09, G.Rnd(int(91 + dx * 10)), 14, 0.02, 0.035)
        for sx in (-1, 1):
            lot.put(M["acier2"], G.tube([(bx + sx * 0.14, by - 0.14, 0.0), (bx + sx * 0.14, by - 0.14, 0.6)], 0.016, 4))
    return a, b


def bande(lot, M):
    """Bande transporteuse couverte (galerie) du sud-est au gueulard."""
    a = (1.75, -2.5, 0.35)
    b = (SC[0] + 0.45, SC[1] - 0.05, 4.4)
    d = G.norm(G.sub(b, a))
    L = G.length(G.sub(b, a))
    ang = math.atan2(d[1], d[0])
    pitch = math.asin(d[2])
    for t in [i / 12.0 for i in range(12)]:
        p = G.lerp(a, b, t + 1 / 24.0)
        lot.put(M["acier"], G.boite(G.add(p, (0, 0, 0.12)), (L / 12.0 * 1.01, 0.34, 0.03), ang, 0.0, -pitch))
        lot.put(M["acier2"], G.boite(G.add(p, (0, 0, 0.0)), (L / 12.0 * 0.96, 0.36, 0.2), ang, 0.0, -pitch))
    for t in (0.25, 0.55):
        m = G.lerp(a, b, t)
        for s in (-1, 1):
            lot.put(M["acier2"], G.tube([(m[0] - s * 0.18, m[1] + s * 0.12, 0.0), (m[0], m[1], m[2] - 0.08)], 0.026, 6))
    K.caisson(lot, M["acier2"], a[0] - 0.05, a[1] + 0.05, 0.0, 0.5, 0.5, 0.5, 0.03)


def cowper(lot, M, x, y):
    zt = 3.1
    K.rev(lot, M["acier"], x, y, [(0.05, 0.58), (0.18, 0.55), (zt, 0.55)], 36)
    pr = [(zt + 0.55 * math.sin(t), 0.55 * math.cos(t)) for t in [i / 10.0 * math.pi / 2 for i in range(11)]]
    K.rev(lot, M["acier_lisse"], x, y, pr, 36)
    for z in (0.5, 1.0, 1.5, 2.0, 2.5, 2.95):
        K.cerclage(lot, M["acier2"], x, y, z, 0.55, 0.045, 0.02, 36)
        O.rivets_anneau(lot, M["riv"], (x, y, 0.0), 0.59, z, 20, 0.012)
    # couronne de garde-corps au sommet, échelle, brûleur à regard orange
    K.rambarde(lot, M["jaune"], [(x + 0.66 * math.cos(t), y + 0.66 * math.sin(t)) for t in [TAU * i / 16 for i in range(17)]], zt, 0.22, 0.3)
    lot.put(M["acier2"], G.prisme([(x + 0.68 * math.cos(t), y + 0.68 * math.sin(t)) for t in [TAU * i / 16 for i in range(16)]], zt - 0.04, zt - 0.005))
    K.echelle(lot, M["acier2"], (x + 0.1, y - 0.6, 0.1), (x + 0.1, y - 0.6, zt))
    bp = (x + 0.42, y - 0.42, 0.55)
    lot.put(M["fonte"], G.oriente(G.tour([(0.0, 0.14), (0.16, 0.14), (0.2, 0.1)], 14, "z", cap1=True), bp, (0.7, -0.7, 0.0)))
    lot.put(M["braise"], G.oriente(G.tour([(0.2, 0.08), (0.205, 0.0)], 14, "z"), bp, (0.7, -0.7, 0.0)))
    K.vanne(lot, M, (x - 0.3, y - 0.62, 1.55), 0.06)


def coulee(lot, M, v, rnd):
    """Cour de coulée : trou de coulée au sud du creuset, rigole de fonte, laitier, poche / wagon-torpille / lit de coulée."""
    x, y = SC
    zc = 0.55                                     # plancher de coulée (au niveau des tuyères) : la fonte DESCEND vers le sud
    # plancher surélevé sur poteaux, lit de sable réfractaire
    lot.put(M["acier2"], G.prisme([(x - 1.0, -1.62), (x + 1.05, -1.62), (x + 1.05, y - 0.7), (x - 1.0, y - 0.7)], zc - 0.06, zc))
    lot.put(M["sable"], G.prisme([(x - 0.9, -1.55), (x + 0.95, -1.55), (x + 0.95, y - 0.75), (x - 0.9, y - 0.75)], zc, zc + 0.012))
    for (px_, py_) in ((x - 0.95, -1.57), (x + 1.0, -1.57), (x - 0.95, -0.95), (x + 1.0, -0.95), (x + 0.02, -1.57)):
        lot.put(M["acier2"], G.boite((px_, py_, zc / 2), (0.08, 0.08, zc - 0.05)))
    K.rambarde(lot, M["jaune"], [(x + 0.25, -1.6), (x + 1.03, -1.6), (x + 1.03, -0.8)], zc, 0.22, 0.3)
    # avant-creuset et trou de coulée
    K.caisson(lot, M["brique"], x, y - 0.98, zc, 0.5, 0.36, 0.12, 0.03)
    lot.put(M["fusion"], G.boite((x, y - 0.93, zc + 0.11), (0.16, 0.24, 0.02)))
    tgt = {"poche": (x - 0.12, -2.2, 0.41), "torpille": (x - 0.12, -2.3, 0.47), "lit": (x - 0.12, -1.78, 0.12)}
    cible = tgt["poche"] if v["poche"] else tgt["torpille"] if v["torpille"] else tgt["lit"]
    pts = [(x, y - 1.05, zc + 0.05), (x, -1.2, zc + 0.04), (x - 0.12, -1.52, zc + 0.03)]
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        r = math.atan2(b[1] - a[1], b[0] - a[0]) - math.pi / 2
        lot.put(M["brique"], G.boite(G.lerp(a, b, 0.5), (0.3, G.length(G.sub(b, a)) + 0.04, 0.1), r))
        lot.put(M["fusion"], G.boite(G.add(G.lerp(a, b, 0.5), (0, 0, 0.052)), (0.15, G.length(G.sub(b, a)) + 0.02, 0.012), r))
    # rigole basculante (bec) au bord du plancher, puis le jet qui tombe dans la poche / la torpille / le lit
    a = (x - 0.12, -1.55, zc + 0.03)
    b = (cible[0], cible[1] + 0.12, max(cible[2] + 0.1, 0.22))
    d = G.sub(b, a)
    L = G.length(d)
    ang, pitch = math.atan2(d[1], d[0]), math.asin(d[2] / L)
    lot.put(M["fonte"], G.boite(G.lerp(a, b, 0.5), (L, 0.2, 0.07), ang, 0.0, -pitch))
    lot.put(M["fusion"], G.boite(G.add(G.lerp(a, b, 0.5), (0, 0, 0.04)), (L * 0.95, 0.1, 0.01), ang, 0.0, -pitch))
    lot.put(M["fusion"], G.tube([G.add(b, (0, -0.06, 0.0)), (cible[0], cible[1] + 0.04, cible[2])], 0.03, 8))
    # écrémeur et rigole de laitier vers le pot de laitier, au sol
    s = v["laitier"]
    lot.put(M["fonte"], G.boite((x, -0.85, zc + 0.08), (0.38, 0.05, 0.1)))
    sl = [(x, -0.75, zc + 0.04), (x + s * 0.7, -0.95, zc + 0.03), (x + s * 0.95, -1.5, zc + 0.02), (x + s * 1.2, -1.75, 0.5)]
    for i in range(len(sl) - 1):
        a, b = sl[i], sl[i + 1]
        dd = G.sub(b, a)
        r = math.atan2(dd[1], dd[0])
        pt = math.asin(dd[2] / G.length(dd))
        lot.put(M["brique"], G.boite(G.lerp(a, b, 0.5), (G.length(dd) + 0.04, 0.22, 0.08), r, 0.0, -pt))
        lot.put(M["laitier"], G.boite(G.add(G.lerp(a, b, 0.5), (0, 0, 0.042)), (G.length(dd), 0.1, 0.01), r, 0.0, -pt))
    px, py = x + s * 1.3, -1.95
    K.rev(lot, M["fonte"], px, py, [(0.0, 0.18), (0.08, 0.24), (0.4, 0.3), (0.44, 0.31)], 20, cap=False)
    K.rev(lot, M["laitier"], px, py, [(0.42, 0.29), (0.43, 0.0)], 20)
    for t in (0.0, math.pi):
        lot.put(M["fonte"], G.tour([(-0.03, 0.05), (0.03, 0.05)], 10, "x", (px + 0.33 * math.cos(t), py, 0.32), cap0=True, cap1=True))
    # machine à boucher (canon à argile) à l'ouest du trou de coulée, foreuse à l'est, sur le plancher
    O.bras(lot, M["acier"], M["fonte"], M["caoutchouc"], (x - 0.75, y - 1.25, zc), (x - 0.75, y - 1.25, zc + 0.3), (x - 0.5, y - 1.15, zc + 0.42),
           (x - 0.25, y - 1.05, zc + 0.28), (x - 0.1, y - 0.98, zc + 0.16), r=0.06, socle=0.12)
    lot.put(M["acier2"], G.tube([(x + 0.7, y - 1.3, zc + 0.25), (x + 0.12, y - 1.0, zc + 0.16)], 0.03, 6))
    K.caisson(lot, M["jaune"], x + 0.78, y - 1.34, zc, 0.22, 0.2, 0.3, 0.02)
    if v["poche"]:
        lx, ly, lz = cible
        K.rev(lot, M["fonte"], lx, ly, [(0.0, 0.3), (0.03, 0.33), (lz - 0.02, 0.41), (lz + 0.02, 0.42)], 28, cap=False)
        # fonte sous une peau de laitier : bain orange, plaques sombres
        K.rev(lot, M["bain"], lx, ly, [(lz - 0.01, 0.4), (lz, 0.0)], 28)
        rl = G.Rnd(4433)
        for k in range(16):
            a, d = rl.f(0.0, TAU), rl.f(0.1, 0.34)
            lot.put(M["croute"], G.boite((lx + d * math.cos(a), ly + d * math.sin(a), lz + 0.005), (rl.f(0.07, 0.14), rl.f(0.06, 0.12), 0.012), rl.f(0.0, 3.0)))
        for z in (0.12, 0.3):
            K.cerclage(lot, M["acier2"], lx, ly, z, 0.33 + 0.08 * z / lz, 0.04, 0.018)
        for t in (0.0, math.pi):
            lot.put(M["acier2"], G.tour([(-0.04, 0.06), (0.04, 0.06)], 10, "x", (lx + 0.43 * math.cos(t), ly, 0.3), cap0=True, cap1=True))
        arc = [(lx + 0.47 * math.cos(t), ly, 0.3 + 0.5 * math.sin(t)) for t in [i / 12.0 * math.pi for i in range(13)]]
        lot.put(M["acier2"], G.tube(arc, 0.03, 6))
    if v["torpille"]:
        ty = -2.33
        for yy in (ty - 0.24, ty + 0.24):
            lot.put(M["acier_clair"], G.boite((0.0, yy, 0.03), (3.9, 0.05, 0.05)))
        for k in range(14):
            lot.put(M["fonte"], G.boite((-1.82 + 0.28 * k, ty, 0.01), (0.1, 0.66, 0.03)))
        prof = [(-1.1, 0.0), (-1.07, 0.1), (-0.9, 0.19), (-0.5, 0.24), (0.5, 0.24), (0.9, 0.19), (1.07, 0.1), (1.1, 0.0)]
        lot.put(M["acier"], G.tour(prof, 30, "x", (0.15, ty, 0.24)))
        K.rev(lot, M["fonte"], x - 0.12, ty, [(0.36, 0.15), (0.49, 0.15)], 18, cap=False)
        K.rev(lot, M["bain"], x - 0.12, ty, [(0.46, 0.13), (0.47, 0.0)], 18)
        for xx in (-0.72, 1.02):
            K.bz(lot, M["acier2"], xx, ty, 0.06, 0.62, 0.54, 0.1)
            for dx in (-0.2, 0.2):
                lot.put(M["fonte"], G.tour([(ty - 0.3, 0.09), (ty - 0.24, 0.09)], 12, "y", (xx + dx, 0.0, 0.12), cap0=True, cap1=True))
                lot.put(M["fonte"], G.tour([(ty + 0.24, 0.09), (ty + 0.3, 0.09)], 12, "y", (xx + dx, 0.0, 0.12), cap0=True, cap1=True))
        for z in (0.2, 0.42):
            lot.put(M["acier2"], G.tube([(-0.45, ty - 0.37, z), (0.75, ty - 0.37, z)], 0.012, 4))
    if v["lit"]:
        # lit de coulée : lingotières en rangées, les plus proches de la rigole encore incandescentes
        for i in range(3):
            for j in range(6):
                mx, my = -1.25 + 0.5 * j, -1.75 - 0.36 * i
                if abs(mx - (x - 0.12)) < 0.2 and i == 0:
                    continue
                K.caisson(lot, M["fonte"], mx, my, 0.0, 0.42, 0.28, 0.1, 0.02)
                hot = (i + abs(j - 2.5)) < 2.6
                lot.put(M["fusion" if hot else "croute"], G.boite((mx, my, 0.095), (0.32, 0.18, 0.012)))
        lot.put(M["sable"], G.boite((0.0, -2.1, 0.0), (3.9, 1.3, 0.02)))


def build(S, lot, v):
    M = K.matieres(S, PALETTE)
    v = VAR[v]
    rnd = G.Rnd(4401)
    x, y = SC
    # sol de la halle : dalle, plancher de tuyères, sable
    lot.put(M["beton"], G.prisme([(-1.96, -2.7), (1.96, -2.7), (1.96, 2.7), (-1.96, 2.7)], 0.0, 0.03))
    lot.put(M["sable"], G.prisme([(-1.0, -2.6), (1.0, -2.6), (1.0, -0.6), (-1.0, -0.6)], 0.03, 0.04))
    deck = [(x + 1.62 * math.cos(TAU * (k + 0.5) / 16), y + 1.62 * math.sin(TAU * (k + 0.5) / 16)) for k in range(16)]
    lot.put(M["acier2"], G.prisme(deck, 0.48, 0.53))
    for k in range(0, 16, 2):
        a = TAU * (k + 0.5) / 16
        lot.put(M["acier2"], G.tube([(x + 1.5 * math.cos(a), y + 1.5 * math.sin(a), 0.0), (x + 1.5 * math.cos(a), y + 1.5 * math.sin(a), 0.5)], 0.03, 6))
    K.rambarde(lot, M["jaune"], deck[9:16] + deck[0:3], 0.53, 0.24, 0.32)
    cuve(lot, M)
    tuyeres(lot, M)
    h = gueulard(lot, M, v)
    # plate-forme intermédiaire de la cuve
    zp = 2.35
    pl = [(x + 1.08 * math.cos(TAU * k / 16), y + 1.08 * math.sin(TAU * k / 16)) for k in range(16)]
    lot.put(M["acier2"], G.prisme(pl, zp - 0.04, zp))
    K.rambarde(lot, M["jaune"], pl[7:16] + [pl[0], pl[1]], zp, 0.22, 0.3)
    K.echelle(lot, M["acier2"], (x - 1.2, y - 0.2, 0.53), (x - 1.05, y - 0.15, zp))
    for (cx, cy) in v["cowpers"]:
        cowper(lot, M, cx, cy)
        # conduite de vent chaud vers l'anneau, vanne
        d = G.norm((x - cx, y - cy, 0.0))
        a = (cx + 0.55 * d[0], cy + 0.55 * d[1], 1.6)
        b = (x - 1.42 * d[0], y - 1.42 * d[1], 1.6)
        O.tuyau(lot, M["acier"], M["acier2"], [a, b], 0.11, pas_bride=0.3)
        K.vanne(lot, M, G.add(G.lerp(a, b, 0.5), (0, 0, 0.12)), 0.07)
    if v["pot"]:
        px, py = 1.45, 2.05
        K.rev(lot, M["acier"], px, py, [(0.65, 0.08), (1.25, 0.42), (2.35, 0.42), (2.62, 0.16), (2.7, 0.14)], 28)
        for z in (1.5, 1.95, 2.3):
            K.cerclage(lot, M["acier2"], px, py, z, 0.42, 0.04, 0.018, 28)
        for k in range(4):
            a = TAU * (k + 0.5) / 4
            lot.put(M["acier2"], G.tube([(px + 0.5 * math.cos(a), py + 0.5 * math.sin(a), 0.0), (px + 0.4 * math.cos(a), py + 0.4 * math.sin(a), 1.3)], 0.03, 6))
        O.tuyau(lot, M["acier"], M["acier2"], [h, (h[0] + 0.3, h[1] + 0.25, h[2]), (px, py, 2.9), (px, py, 2.66)], 0.1, rb=0.2, pas_bride=0.5)
        lot.put(M["fonte"], G.tour([(0.4, 0.06), (0.65, 0.08)], 10, "z", (px, py, 0.0), cap0=True))
    else:
        # conduite de gaz vers l'ouest (hors de l'emprise, vers l'épuration)
        O.tuyau(lot, M["acier"], M["acier2"], [h, (h[0] - 0.2, h[1] + 0.3, h[2]), (-1.85, 2.55, 3.4), (-1.98, 2.6, 3.4)], 0.1, rb=0.2, pas_bride=0.5)
    if v["cheminee"]:
        cx, cy = v["cheminee"]
        K.caisson(lot, M["brique"], cx, cy, 0.0, 0.66, 0.66, 0.5, 0.04)
        K.rev(lot, M["brique"], cx, cy, [(0.5, 0.29), (5.6, 0.2), (5.7, 0.24), (5.85, 0.24)], 24, cap=False)
        K.rev(lot, M["suie"], cx, cy, [(5.85, 0.24), (5.7, 0.18), (5.6, 0.0)], 20)
        for z in (1.4, 2.4, 3.4, 4.4, 5.3):
            r = 0.29 - 0.09 * (z - 0.5) / 5.1
            K.cerclage(lot, M["acier2"], cx, cy, z, r, 0.04, 0.016, 24)
        O.tuyau(lot, M["acier"], M["acier2"], [(cx - 0.6, cy - 0.3, 1.0), (cx - 0.3, cy, 1.0)], 0.09)
    if v["skip"]:
        skip(lot, M, v["skip"][0], (x + v["skip"][1][0], y + v["skip"][1][1]))
    if v["bande"]:
        bande(lot, M)
    coulee(lot, M, v, rnd)
    # menus objets de la halle : lingotières vides, outils de piquage, tas de sable
    lot.put(M["acier_clair"], G.tube([(-1.75, -0.4, 0.04), (-1.1, -0.15, 0.06)], 0.012, 4))
    lot.put(M["acier_clair"], G.tube([(-1.72, -0.5, 0.04), (-1.05, -0.3, 0.06)], 0.012, 4))
    K.tas(lot, M["sable"], (-1.55, -1.1, 0.03), 0.25, 0.22, 0.12, G.Rnd(4411), 30, 0.03, 0.05)
    # pile de briques réfractaires, bouteilles d'oxygène de la lance de piquage, garde-corps du bord sud de la halle
    for i in range(3):
        for j in range(2):
            lot.put(M["brique"], G.boite((1.25 + 0.12 * j, -0.95 + 0.0, 0.06 + 0.06 * i), (0.11, 0.22, 0.055), 0.05 * (i - 1)))
    for k in range(3):
        K.rev(lot, M["bleu"], -1.82, -0.75 + 0.12 * k, [(0.03, 0.05), (0.5, 0.05), (0.55, 0.03)], 10)
    lot.put(M["caoutchouc"], G.tube(G.catmull([(-1.82, -0.63, 0.5), (-1.4, -0.8, 0.06), (-0.7, -1.0, 0.1), (-0.25, -0.6, 0.35)], 6), 0.012, 5))
    for k in range(5):
        lot.put(M["fonte"], G.boite((-1.75 + 0.12 * k, -2.55, 0.06), (0.1, 0.24, 0.06), 0.1 * k))
    return {"axe": SC}
