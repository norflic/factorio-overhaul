"""HALL DE MONTAGE (fo-robotics-bay), âge 7 · Cristal, emprise 5×5 (x ±2,5 ; y ±3,54). PLAN ROBOTS §5 bis.

Lecture : un podium de pierre fendu ; une nef ouverte de côtes de bronze inclinées vers le nord « (((( », sans mur au sud. Dans la nef, sur son
berceau, une Aiguille en montage (trépied, corps de bronze, pointe de cristal), 2 bras de bronze à son service. Au nord-ouest, jaillit de la
roche la grande grappe de cristal (signature de l'âge, point le plus haut), sertie de bronze, qui charge la pointe du robot par un rayon ;
au nord-est, une grappe plus petite. Sortie au sud par des marches, entre 2 éclats. Aucune boîte.
Bible (époque 7) : bronze #6A5236, pierre #4A4038, cristal #9A5CFF (lueur #B070FF), luminance 55. Pied presque noir, pointe claire.
"""
import math

import geo as G
import mat as MT
import outils as O

TAU = G.TAU
PI = math.pi
ZP = 0.24                  # dessus du podium
ROB = (0.25, -0.75)        # pied du robot
K_ROB = 1.3                # échelle du robot et de son berceau
PSI = -math.radians(26.0)  # la nef, le robot et ses bras regardent le sud-ouest : trois-quarts, soleil dans la nef
ZC = 1.62                  # centre du corps du robot


def matieres(S):
    M = {}
    MT.PATINE.update(ta=0.17, ra=0.26, ec=0.65, nu_k=1.4, ec_col=(0.03, 0.02, 0.014), sans=("noir", "cristal"))
    sf = MT.surface
    cr = (0.012, 0.009, 0.008)
    M["bronze"] = sf("c7_bronze", (0.3, 0.19, 0.085), rough=0.42, met=0.55, usure=0.8, nu=(0.72, 0.56, 0.32), crasse=0.85, crasse_col=cr, coulures=0.7,
                     rouille=(0.05, 0.14, 0.1), grain=0.1, graine=71)
    M["bronze2"] = sf("c7_bronze2", (0.17, 0.105, 0.05), rough=0.5, met=0.5, tole=(0.5, 0.28), joint=0.45, joint_l=0.01, var=0.1, usure=0.7, nu=(0.6, 0.46, 0.27),
                      crasse=0.85, crasse_col=cr, coulures=0.7, rouille=(0.05, 0.13, 0.09), relief=0.7, grain=0.12, graine=72)
    M["pierre"] = sf("c7_pierre", (0.145, 0.115, 0.095), rough=0.9, met=0.0, tole=(0.62, 0.36), joint=0.32, joint_l=0.012, var=0.22, coulures=0.5, rouille=(0.04, 0.03, 0.05),
                     usure=0.65, nu=(0.32, 0.27, 0.23), crasse=0.85, crasse_col=cr, pied=(0.0, 0.5, 0.5), relief=0.7, grain=0.16, graine=73)
    M["pierre2"] = sf("c7_pierre2", (0.1, 0.08, 0.068), rough=0.92, met=0.0, usure=0.7, nu=(0.28, 0.23, 0.2), crasse=0.85, crasse_col=cr, grain=0.2, graine=74)
    M["roche"] = sf("c7_roche", (0.07, 0.055, 0.06), rough=0.85, met=0.0, usure=0.6, nu=(0.22, 0.18, 0.2), crasse=0.85, crasse_col=cr, grain=0.24, graine=75)
    M["acier"] = sf("c7_acier", (0.2, 0.17, 0.14), rough=0.45, met=0.6, usure=0.6, nu=(0.62, 0.56, 0.47), crasse=0.6, crasse_col=cr, graine=76)
    M["noir"] = sf("c7_noir", (0.014, 0.012, 0.014), rough=0.6, met=0.3, usure=0.2, nu=(0.12, 0.1, 0.1), crasse=0.3, graine=77)
    M["caout"] = sf("c7_caout", (0.025, 0.022, 0.024), rough=0.7, met=0.0, usure=0.25, nu=(0.08, 0.07, 0.07), crasse=0.3, graine=78)
    M["cristal"] = MT.degrade(S, "c7_cristal", (0.6, 0.3, 1.0), (0.012, 0.004, 0.03), 0.55, main=0.85, base=(0.04, 0.012, 0.11), crust=(7.0, 0.4, 21.0), mode="hauteur")
    M["eclat"] = MT.degrade(S, "c7_eclat", (0.58, 0.28, 1.0), (0.02, 0.006, 0.05), 0.5, main=0.85, base=(0.035, 0.01, 0.1), crust=(11.0, 0.4, 23.0), mode="hauteur")
    M["rayon"] = MT.degrade(S, "c7_rayon", (0.66, 0.38, 1.0), (0.14, 0.03, 0.42), 0.65, main=0.85, crust=(16.0, 0.5, 25.0))
    M["veilleuse"] = MT.degrade(S, "c7_veilleuse", (0.6, 0.32, 1.0), (0.08, 0.015, 0.26), 0.5, main=0.85, crust=(30.0, 0.3, 27.0))
    return M


def cristal(lot, m, pied, pointe, r, rnd, nf=6, col=0.72):
    """Cristal à facettes franches, irrégulier : fût de nf faces, épaule à col, pointe décalée. uv.x = hauteur 0..1 (dégradé)."""
    d = G.sub(pointe, pied)
    ref = (1.0, 0.0, 0.0) if abs(G.norm(d)[0]) < 0.9 else (0.0, 1.0, 0.0)
    e1 = G.norm(G.cross(ref, d))
    e2 = G.cross(G.norm(d), e1)
    ks = [1.0 + rnd.f(-0.22, 0.22) for _ in range(nf)]
    a0 = rnd.f(0.0, TAU)

    def anneau_(t, k):
        c = G.add(pied, G.mul(d, t))
        return [G.add(c, G.add(G.mul(e1, r * k * ks[j] * math.cos(a0 + TAU * j / nf)), G.mul(e2, r * k * ks[j] * math.sin(a0 + TAU * j / nf)))) for j in range(nf)]
    bas, epaule, tip = anneau_(0.0, 0.82), anneau_(col, 1.0), pointe
    verts, faces, uvs = [], [], []
    for j in range(nf):
        j2 = (j + 1) % nf
        b = len(verts)
        verts += [bas[j], bas[j2], epaule[j2], epaule[j]]
        uvs += [(0.0, 0.0), (0.0, 1.0), (col, 1.0), (col, 0.0)]
        faces.append((b, b + 1, b + 2, b + 3))
        b = len(verts)
        verts += [epaule[j], epaule[j2], tip]
        uvs += [(col, 0.0), (col, 1.0), (1.0, 0.5)]
        faces.append((b, b + 1, b + 2))
    lot.put(m, (verts, faces, uvs))


def sertissure(lot, M, pied, pointe, r, t):
    """Bague de bronze boulonnée autour d'un cristal, à la hauteur t."""
    c = G.lerp(pied, pointe, t)
    n = G.sub(pointe, pied)
    lot.put(M["bronze"], G.oriente(G.tour([(-0.07, r + 0.02), (-0.05, r + 0.07), (0.05, r + 0.07), (0.07, r + 0.02)], 16, "z"), c, n))
    pts = [(G.oriente(([(r * 1.08 * math.cos(a) + 0.03 * math.cos(a), r * 1.08 * math.sin(a) + 0.03 * math.sin(a), 0.0)], [], []), c, n)[0][0],
            G.norm(G.oriente(([(math.cos(a), math.sin(a), 0.0)], [], []), (0, 0, 0), n)[0][0])) for a in [TAU * k / 10.0 for k in range(10)]]
    lot.put(M["acier"], G.rivets_le_long([(G.add(p, G.mul(q, 0.06)), q) for (p, q) in pts], 0.018, 0.012))


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(7070)

    # ---------------------------------------------------------------- podium fendu, dalles, marches au sud
    pod = [(-1.95, -2.92), (1.95, -2.92), (2.46, -2.3), (2.46, 2.62), (1.9, 3.46), (-1.9, 3.46), (-2.46, 2.62), (-2.46, -2.3)]
    lot.put(M["pierre2"], G.prisme(pod, 0.0, 0.12, 0.99))
    k = 0.965
    cx, cy = 0.0, sum(p[1] for p in pod) / 8.0
    lot.put(M["pierre"], G.prisme([(cx + (p[0] - cx) * k, cy + (p[1] - cy) * k) for p in pod], 0.12, ZP, 0.985))
    # fente dans la dalle, depuis la grappe vers le berceau : on y voit le cristal affleurer
    fente = [(-1.25, 1.55), (-0.95, 0.95), (-0.6, 0.65), (-0.42, 0.1), (-0.05, -0.2)]
    lot.put(M["noir"], G.tube([(p[0], p[1], ZP + 0.002) for p in fente], 0.075, 6))
    lot.put(M["veilleuse"], G.tube([(p[0], p[1], ZP + 0.03) for p in fente], 0.03, 6))
    for k_ in range(5):
        p = fente[k_]
        cristal(lot, M["eclat"], (p[0], p[1], ZP - 0.02), (p[0] + r.f(-0.05, 0.05), p[1] + r.f(-0.05, 0.05), ZP + r.f(0.12, 0.3)), 0.055, r, nf=5)
    # marches de la sortie, entre 2 éclats
    mx = ROB[0] - 0.05
    for k_ in range(5):
        y = -2.9 - 0.13 * k_
        z = ZP - k_ * (ZP / 5.0)
        lot.put(M["pierre"], G.boite((mx, y, z / 2.0), (1.55 - 0.03 * k_, 0.15, z)))
        lot.put(M["bronze2"], G.boite((mx, y - 0.075, z - 0.008), (1.5 - 0.03 * k_, 0.018, 0.016)))
    for (x, t) in ((mx - 1.02, 0.95), (mx + 1.02, 0.65)):
        lot.put(M["roche"], G.butte_polaire((x, -2.95, ZP - 0.05), 0.3, 0.25, 0.14, r, 5, 18, 0.4, 0.3))
        lot.put(M["bronze"], G.tour([(ZP, 0.15), (ZP + 0.1, 0.13), (ZP + 0.13, 0.08)], 12, "z", (x, -2.95, 0.0)))
        cristal(lot, M["eclat"], (x, -2.95, ZP + 0.04), (x + 0.04, -2.98, ZP + t), 0.1, r)
        cristal(lot, M["eclat"], (x + 0.06, -2.93, ZP + 0.04), (x + 0.18, -2.87, ZP + t * 0.55), 0.06, r, nf=5)

    # ---------------------------------------------------------------- la grande grappe, au nord-ouest, dans sa roche
    gx, gy = -1.28, 2.08
    lot.put(M["roche"], G.butte_polaire((gx, gy, ZP - 0.02), 1.15, 1.25, 0.82, r, 10, 38, 0.32, 0.18))
    lot.put(M["pierre2"], G.butte_polaire((gx + 0.5, gy - 0.72, ZP - 0.02), 0.5, 0.42, 0.28, r, 6, 24, 0.4, 0.25))
    grappes = (((gx, gy + 0.04, 0.45), (gx - 0.34, gy + 0.08, 5.6), 0.37),
               ((gx + 0.48, gy - 0.2, 0.42), (gx + 0.88, gy - 0.38, 3.45), 0.24),
               ((gx - 0.48, gy - 0.3, 0.4), (gx - 0.98, gy - 0.74, 3.0), 0.21),
               ((gx + 0.14, gy + 0.46, 0.4), (gx + 0.46, gy + 0.72, 4.05), 0.22),
               ((gx - 0.28, gy + 0.4, 0.38), (gx - 0.82, gy + 0.72, 2.45), 0.16),
               ((gx + 0.3, gy - 0.58, 0.32), (gx + 0.62, gy - 1.02, 1.85), 0.13),
               ((gx - 0.08, gy - 0.62, 0.3), (gx - 0.28, gy - 1.08, 1.45), 0.1))
    for (a, b, rc) in grappes:
        cristal(lot, M["cristal"], a, b, rc, r)
    sertissure(lot, M, grappes[0][0], grappes[0][1], 0.33, 0.28)
    sertissure(lot, M, grappes[0][0], grappes[0][1], 0.28, 0.46)
    sertissure(lot, M, grappes[1][0], grappes[1][1], 0.2, 0.34)
    sertissure(lot, M, grappes[3][0], grappes[3][1], 0.18, 0.38)
    # griffes de bronze qui tiennent le cristal maître, ancrées au podium
    for (dx, dy, t) in ((0.78, -0.52, 0.28), (-0.8, -0.62, 0.3), (0.5, 0.82, 0.26)):
        c = G.lerp(grappes[0][0], grappes[0][1], t)
        p0 = (gx + dx, gy + dy, ZP)
        lot.put(M["bronze"], G.tube(G.catmull([p0, G.add(G.lerp(p0, c, 0.55), (dx * 0.3, dy * 0.3, 0.1)), G.add(c, (dx * 0.42, dy * 0.42, 0.0))], 8), 0.05, 8))
        lot.put(M["pierre"], G.boite((p0[0], p0[1], ZP + 0.05), (0.26, 0.26, 0.1), 0.3))
    # prisme de tir au flanc de la grappe : il charge la pointe du robot
    pp = G.lerp(grappes[1][0], grappes[1][1], 0.62)
    pz = G.add(pp, (0.2, -0.22, -0.1))
    lot.put(M["bronze"], G.tube([G.add(pp, (0.02, -0.02, -0.25)), pz], 0.035, 8))
    cristal(lot, M["cristal"], G.add(pz, (-0.07, 0.07, -0.05)), G.add(pz, (0.16, -0.17, 0.05)), 0.09, r, nf=5, col=0.55)
    lot.put(M["bronze"], G.oriente(G.tour([(-0.04, 0.14), (0.04, 0.14)], 12, "z"), G.add(pz, (0.02, -0.02, 0.0)), (0.7, -0.7, 0.15)))

    # petite grappe au nord-est
    ex, ey = 1.92, 2.72
    lot.put(M["roche"], G.butte_polaire((ex, ey, ZP - 0.02), 0.72, 0.8, 0.46, r, 8, 30, 0.35, 0.2))
    for (a, b, rc) in (((ex, ey, 0.42), (ex + 0.3, ey + 0.18, 2.75), 0.19), ((ex - 0.25, ey + 0.1, 0.4), (ex - 0.5, ey + 0.34, 1.95), 0.14),
                       ((ex + 0.25, ey - 0.25, 0.36), (ex + 0.62, ey - 0.6, 1.45), 0.12), ((ex - 0.1, ey - 0.28, 0.32), (ex - 0.2, ey - 0.62, 1.05), 0.09)):
        cristal(lot, M["cristal"], a, b, rc, r)
    sertissure(lot, M, (ex, ey, 0.42), (ex + 0.3, ey + 0.18, 2.75), 0.16, 0.32)

    # ---------------------------------------------------------------- la nef : côtes de bronze inclinées vers le nord, sans mur au sud
    def rot(p):
        return G.rot_z(p, PSI, (ROB[0], ROB[1], 0.0))
    lot.xf = rot
    ribs = (-0.85, -0.05, 0.75, 1.5)
    cxn = ROB[0]
    lean = 0.34
    pts_cotes = []
    for i, y in enumerate(ribs):
        Ra = 1.56 + 0.03 * i
        H = 2.45 + 0.2 * i
        pts = []
        for t in [math.radians(-6.0) + math.radians(192.0) * j / 28.0 for j in range(29)]:
            z = max(0.0, math.sin(t)) * H
            x = cxn + Ra * math.cos(t) * (1.0 + (0.06 if math.cos(t) < 0 else -0.02))
            pts.append((x, y + lean * z, ZP + z))
        pts_cotes.append(pts)
        lot.put(M["bronze"], G.tube(pts, 0.062, 8))
        ins = [(p[0] + (cxn - p[0]) * 0.085, p[1] - 0.01, ZP + (p[2] - ZP) * 0.93) for p in pts]
        lot.put(M["bronze2"], G.loft([pts, ins], closed=False))
        for s in (-1, 1):                                                # socles de pierre, gousset
            xf = cxn + s * (Ra * (1.06 if s < 0 else 0.98))
            lot.put(M["pierre"], G.prisme([(xf - 0.2, y - 0.2), (xf + 0.2, y - 0.2), (xf + 0.2, y + 0.2), (xf - 0.2, y + 0.2)], ZP, ZP + 0.26, 0.82))
            lot.put(M["bronze"], G.tour([(ZP + 0.24, 0.09), (ZP + 0.3, 0.075)], 10, "z", (xf, y, 0.0)))
        lot.put(M["acier"], G.rivets_le_long([(G.add(pts[j], (0.0, -0.06, 0.0)), (0.0, -1.0, 0.0)) for j in range(3, 26, 2)], 0.016, 0.012))
    # lisses qui relient les côtes ; 2 travées de toit à l'arrière, ajourées
    for j in (9, 14, 19):
        lot.put(M["bronze"], G.tube([G.add(p[j], (0.0, 0.0, 0.05)) for p in pts_cotes], 0.03, 6))
    for (i0, i1) in ((2, 3),):
        for (j0, j1, m) in ((5, 9, "bronze2"), (9, 13, "bronze2"), (17, 21, "bronze2"), (21, 25, "bronze2")):
            rows = [[G.lerp(pts_cotes[i0][j], pts_cotes[i1][j], u / 4.0) for u in range(5)] for j in range(j0, j1 + 1)]
            lot.put(M[m], G.loft(rows, closed=False))
    # verrière violette entre les travées : un seul oculus à l'arrière
    cq = G.lerp(pts_cotes[3][14], pts_cotes[2][14], 0.45)
    O.hublot(lot, M["bronze"], M["veilleuse"], G.add(cq, (0.0, 0.02, 0.05)), (0.0, -0.4, 1.0), 0.12)

    # ---------------------------------------------------------------- berceau et Aiguille en montage
    def robk(p):
        return rot((ROB[0] + (p[0] - ROB[0]) * K_ROB, ROB[1] + (p[1] - ROB[1]) * K_ROB, ZP + (p[2] - ZP) * K_ROB))
    lot.xf = robk
    rx, ry = ROB
    lot.put(M["pierre"], G.tour([(ZP, 0.98), (ZP + 0.1, 0.96), (ZP + 0.14, 0.86), (ZP + 0.15, 0.0)], 40, "z", (rx, ry, 0.0)))
    O.anneau(lot, M["bronze"], (rx, ry, ZP + 0.15), 0.78, 0.028, 56, 6)
    O.anneau(lot, M["veilleuse"], (rx, ry, ZP + 0.155), 0.62, 0.012, 56, 5)
    for k_ in range(12):
        a = TAU * k_ / 12.0
        lot.put(M["noir"], G.boite((rx + 0.9 * math.cos(a), ry + 0.9 * math.sin(a), ZP + 0.13), (0.1, 0.03, 0.02), a))
    for s in (-1, 1):                                                    # étriers du berceau
        lot.put(M["bronze"], G.tube([(rx + s * 0.3, ry, ZP + 0.14), (rx + s * 0.28, ry, ZC - 0.42), (rx + s * 0.18, ry, ZC - 0.26)], 0.04, 8))
    # corps : coque en goutte de bronze, ouverte sur le flanc est
    corps = (rx, ry, ZC)
    rows = []
    for t in [-1.0 + 2.0 * i / 12.0 for i in range(13)]:
        Rk = 0.36 * math.sqrt(max(0.0, 1.0 - t * t)) + 0.02
        ring = [(rx + t * 0.62 + Rk * 0.0 + 0.0, ry + Rk * math.cos(a), ZC + Rk * 0.86 * math.sin(a)) for a in [math.radians(-55.0) + math.radians(290.0) * j / 20.0 for j in range(21)]]
        rows.append(ring)
    lot.put(M["bronze2"], G.loft(rows, closed=False))
    lot.put(M["noir"], G.tour([(-0.48, 0.2), (0.46, 0.2)], 14, "x", corps, cap0=True, cap1=True))
    lot.put(M["veilleuse"], G.tour([(-0.05, 0.11), (0.14, 0.11)], 12, "x", (rx + 0.02, ry - 0.1, ZC + 0.02), cap0=True, cap1=True))
    for k_ in range(3):
        lot.put(M["acier"], G.tour([(0.03 + 0.1 * k_ - 0.01, 0.23), (0.03 + 0.1 * k_ + 0.01, 0.23)], 14, "x", corps))
    O.anneau(lot, M["acier"], (rx - 0.2, ry, ZC), 0.335, 0.016, 28, 5, n=(1.0, 0.0, 0.0))
    O.flexible(lot, M["caout"], [(rx + 0.32, ry - 0.22, ZC - 0.1), (rx + 0.5, ry - 0.42, ZC - 0.48), (rx + 0.2, ry - 0.3, ZP + 0.2)], 0.018)
    # pointe de cristal, longue, sertie : l'arme de l'Aiguille
    base_p = (rx + 0.3, ry - 0.02, ZC + 0.22)
    tip_p = (rx + 1.05, ry - 0.42, ZC + 1.32)
    O.profil(lot, M["bronze"], G.add(base_p, (-0.06, 0.03, -0.1)), G.sub(tip_p, base_p), [(0.0, 0.16), (0.14, 0.18), (0.32, 0.115), (0.46, 0.1)], 14)
    cristal(lot, M["cristal"], G.lerp(base_p, tip_p, 0.1), tip_p, 0.095, r, col=0.82)
    for t in (0.34, 0.58):
        sertissure(lot, M, base_p, tip_p, 0.085 - 0.03 * t, t)
    # rayon de charge : du prisme à la pointe
    lot.xf = None
    lot.put(M["rayon"], G.tube([G.add(pz, (0.16, -0.17, 0.05)), robk(G.lerp(base_p, tip_p, 0.72))], 0.024, 8))
    lot.xf = robk
    # tête-capteur
    O.profil(lot, M["bronze"], (rx - 0.6, ry, ZC + 0.08), (-0.6, -0.4, 0.6), [(0.0, 0.12), (0.1, 0.14), (0.18, 0.09), (0.21, 0.0)], 12)
    lot.put(M["veilleuse"], G.sphere((rx - 0.71, ry - 0.08, ZC + 0.2), 0.045, 8, 4))
    # trépied : 2 jambes posées, une présentée par le bras ouest
    def jambe(h, g, p, rp=0.05):
        lot.put(M["acier"], G.sphere(h, rp * 1.7, 10, 5))
        lot.put(M["bronze"], G.tube([h, g], rp, 10))
        lot.put(M["noir"], G.tube([G.lerp(h, g, 0.22), G.lerp(h, g, 0.7)], rp * 1.28, 10))
        lot.put(M["acier"], G.sphere(g, rp * 1.35, 10, 5))
        lot.put(M["bronze2"], G.tube([g, p], rp * 0.82, 10, rfun=lambda s, i: rp * (0.95 - 0.5 * s / max(0.01, G.length(G.sub(p, g))))))
    pieds = []
    for (a, ext) in ((math.radians(315.0), 1.0), (math.radians(85.0), 1.0)):
        e = (math.cos(a), math.sin(a))
        jambe((rx + 0.28 * e[0], ry + 0.28 * e[1], ZC - 0.18), (rx + 0.9 * e[0], ry + 0.9 * e[1], ZC + 0.22), (rx + 1.16 * e[0], ry + 1.16 * e[1], ZP + 0.13))
        lot.put(M["noir"], G.tour([(ZP + 0.1, 0.11), (ZP + 0.16, 0.09), (ZP + 0.2, 0.03)], 10, "z", (rx + 1.16 * e[0], ry + 1.16 * e[1], 0.0), cap1=True))
    # moyeu vide (sud-ouest)
    a = math.radians(205.0)
    h = (rx + 0.28 * math.cos(a), ry + 0.28 * math.sin(a), ZC - 0.18)
    lot.put(M["acier"], G.oriente(G.tour([(0.0, 0.09), (0.05, 0.1), (0.09, 0.05), (0.08, 0.0)], 10, "z"), h, (math.cos(a), math.sin(a), -0.2)))

    # ---------------------------------------------------------------- 2 bras de montage de bronze
    lot.xf = rot
    wb = (-1.05, -1.38, ZP)
    O.bras(lot, M["bronze"], M["acier"], M["caout"], wb, (wb[0], wb[1], ZP + 0.5), (-1.35, -1.08, 1.75), (-0.82, -1.34, 1.62), (-0.48, -1.22, 1.22), r=0.11, socle=0.21, riv=M["bronze2"])
    # jambe tenue par la pince, prête à poser
    jambe((-0.42, -1.22, 1.22), (-0.3, -1.65, 1.5), (-0.15, -2.05, ZP + 0.16), rp=0.046)
    eb = (2.05, -1.62, ZP)
    O.bras(lot, M["bronze"], M["acier"], M["caout"], eb, (eb[0], eb[1], ZP + 0.5), (2.2, -1.1, 2.0), (1.6, -1.2, 2.45), (rx + 0.58, ry - 0.4, 2.3), r=0.11, socle=0.21, lum=M["rayon"], riv=M["bronze2"])

    # ---------------------------------------------------------------- pierres, caisses de cristal, conduites
    lot.xf = None
    # caisse de cristaux bruts au sud-est, cristaux bruts empilés
    for (x, y, sz) in ((2.02, -2.42, 0.42), (1.56, -2.55, 0.32)):
        lot.put(M["bronze2"], G.boite((x, y, ZP + sz * 0.3), (sz, sz * 0.8, sz * 0.6), 0.25))
        for k_ in range(4):
            q = (x + r.f(-0.1, 0.1), y + r.f(-0.08, 0.08), ZP + sz * 0.55)
            cristal(lot, M["eclat"], q, G.add(q, (r.f(-0.08, 0.08), r.f(-0.08, 0.08), r.f(0.18, 0.34))), 0.05, r, nf=5)
    # établi de pierre au sud-ouest, pièces et moules
    lot.put(M["pierre"], G.boite((-1.82, -2.1, ZP + 0.2), (0.86, 0.5, 0.4), 0.0))
    lot.put(M["bronze2"], G.boite((-1.82, -2.1, ZP + 0.415), (0.92, 0.56, 0.03)))
    for (x, y, l) in ((-2.08, -2.14, 0.22), (-1.78, -2.02, 0.3), (-1.55, -2.16, 0.18)):
        lot.put(M["acier"], G.tour([(-l / 2.0, 0.035), (l / 2.0, 0.035)], 8, "x", (x, y, ZP + 0.47), cap0=True, cap1=True))
    cristal(lot, M["eclat"], (-1.98, -1.98, ZP + 0.43), (-1.92, -1.96, ZP + 0.78), 0.05, r, nf=5)
    # chandelier de bronze à veilleuses sur l'avant, à l'ouest de la sortie
    q = (-2.08, -1.25, ZP)
    O.profil(lot, M["bronze"], q, (0, 0, 1), [(0.0, 0.14), (0.05, 0.11), (0.12, 0.04), (1.15, 0.025), (1.18, 0.06), (1.2, 0.0)], 10)
    lot.put(M["veilleuse"], G.sphere((q[0], q[1], ZP + 1.27), 0.05, 8, 4))
    # conduites de bronze, de la grappe au berceau et aux bras
    O.tuyau(lot, M["bronze"], M["acier"], [(-0.55, 1.1, ZP + 0.08), (-0.2, 1.1, ZP + 0.08), (-0.2, 0.1, ZP + 0.08), (0.0, 0.0, ZP + 0.12)], 0.04, rb=0.1, pas_bride=0.42)
    O.tuyau(lot, M["bronze"], M["acier"], [(1.3, 1.85, ZP + 0.08), (1.3, 0.25, ZP + 0.08), (0.95, 0.0, ZP + 0.12)], 0.034, rb=0.1, pas_bride=0.42)
    O.tuyau(lot, M["bronze"], M["acier"], [(2.28, 1.0, ZP + 0.07), (2.28, -1.62, ZP + 0.07), (2.12, -1.62, ZP + 0.07)], 0.03, rb=0.08, pas_bride=0.42)
    O.flexible(lot, M["caout"], [(-1.05, -1.38, ZP + 0.02), (-0.52, -1.7, ZP + 0.03), (-0.1, -1.4, ZP + 0.14)], 0.022)
    # dalles disjointes et éclats épars
    ru = G.Rnd(7191)
    for k_ in range(70):
        x, y = ru.f(-2.25, 2.25), ru.f(-2.75, 3.2)
        if math.hypot(x - rx, y - ry) < 1.05:
            continue
        m = [M["pierre2"], M["acier"], M["bronze2"], M["noir"]][k_ % 4]
        lot.put(m, G.boite((x, y, ZP + 0.012), (ru.f(0.06, 0.22), ru.f(0.05, 0.16), ru.f(0.015, 0.06)), ru.f(0.0, 3.0)))
    for k_ in range(14):
        x, y = ru.f(-2.2, 2.2), ru.f(-2.6, 1.0)
        if math.hypot(x - rx, y - ry) < 1.1:
            continue
        cristal(lot, M["eclat"], (x, y, ZP - 0.01), (x + ru.f(-0.06, 0.06), y + ru.f(-0.06, 0.06), ZP + ru.f(0.07, 0.18)), 0.035, ru, nf=5)
    return {"robot": ROB}
