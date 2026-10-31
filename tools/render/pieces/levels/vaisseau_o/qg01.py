"""QG ÂGE 1 : PIONNIER (ère I, emprise 8×4). NEZ À DROITE (+X). L'épave de l'âge 0 EN TRAIN D'ÊTRE RÉPARÉE.

Bible (DESIGN_EPOQUES §5, époque 1) : « Poste de pionnier : cabane en rondins à toit de tôle ondulée, sur plate-forme de
rondins ; rempart de sacs de sable en U devant la porte sud ; mât de drapeau en bois à l'arrière gauche ». Fer brut
#5A5048, bois #6B4F35, toile #8A7A5A, luminance 50. Silhouette basse, trapue, irrégulière ; 1 événement (le mât).

Histoire : les deux tronçons sont encore cassés et à peine redressés, calés sur des piles de rondins et des étais. Une
cabane à toit en appentis s'adosse au tronçon arrière, en travers de la brèche ; à côté, le cœur à nu sous un auvent fait
de l'aile arrachée. Le crâne a son échafaudage de perches, une vitre remplacée par des planches, une chèvre lève une tôle.
"""
import math

import ere1 as R
import forme as F
import geo as G
import mat as MT
import qg00 as Q

TAU = G.TAU
# cabane : centre et rotation (la face est se montre), demi-tailles, hauteurs
CAB = dict(cx=-0.78, cy=-1.02, rz=-0.2, hx=0.86, hy=0.62, z0=0.2, ze_s=1.14, ze_n=1.78)
CO = (0.72, -0.82, 0.62)
E = dict(roul_ar=-0.34, tang_ar=0.11, lacet_ar=0.27, t_ar=(-0.55, 0.36, 0.86), roul_av=0.36, tang_av=0.11, lacet_av=-0.1, t_av=(0.5, 0.12, 0.96),
         aile_pli=1.08, cant=0.05, sas=True)


def matieres(S):
    M = Q.matieres(S)                     # mêmes jaunes, même patine que l'épave
    cr = (0.012, 0.009, 0.005)
    sf = MT.surface
    M["rondin"] = sf("q1_rondin", (0.21, 0.125, 0.058), rough=0.85, met=0.0, grain=0.35, usure=0.6, nu=(0.42, 0.31, 0.2), crasse=0.8,
                     crasse_col=cr, coulures=0.3, rouille=(0.05, 0.035, 0.02), graine=31)
    M["rondin2"] = sf("q1_rondin2", (0.135, 0.08, 0.04), rough=0.85, met=0.0, grain=0.35, usure=0.6, nu=(0.34, 0.25, 0.16), crasse=0.8,
                      crasse_col=cr, graine=32)
    M["bout"] = sf("q1_bout", (0.42, 0.27, 0.12), rough=0.85, met=0.0, grain=0.25, usure=0.0, crasse=0.6, crasse_col=cr, graine=33)
    M["planche"] = sf("q1_planche", (0.2, 0.125, 0.06), rough=0.82, met=0.0, grain=0.32, usure=0.6, nu=(0.38, 0.3, 0.2), crasse=0.8,
                      crasse_col=cr, coulures=0.4, rouille=(0.06, 0.045, 0.03), tole=(0.9, 0.115), joint=0.3, var=0.22, graine=34)
    M["planche2"] = sf("q1_planche2", (0.12, 0.072, 0.034), rough=0.82, met=0.0, grain=0.32, usure=0.6, nu=(0.32, 0.25, 0.17), crasse=0.8,
                       crasse_col=cr, tole=(0.8, 0.13), joint=0.3, var=0.22, graine=35)
    M["toile"] = sf("q1_toile", (0.27, 0.21, 0.115), rough=0.92, met=0.0, grain=0.3, usure=0.0, crasse=0.85, crasse_col=cr, coulures=0.6,
                    rouille=(0.1, 0.08, 0.05), pied=(0.0, 0.9, 0.5), graine=36)
    M["toile2"] = sf("q1_toile2", (0.16, 0.125, 0.07), rough=0.92, met=0.0, grain=0.3, usure=0.0, crasse=0.9, crasse_col=cr, coulures=0.8,
                     pied=(0.0, 0.9, 0.5), graine=48)
    M["jute"] = sf("q1_jute", (0.25, 0.18, 0.09), rough=0.95, met=0.0, grain=0.35, usure=0.0, crasse=0.95, crasse_col=cr, pied=(0.0, 0.35, 0.5), graine=37)
    M["jute2"] = sf("q1_jute2", (0.13, 0.08, 0.03), rough=0.95, met=0.0, grain=0.35, usure=0.0, crasse=0.95, crasse_col=cr, pied=(0.0, 0.35, 0.5), graine=38)
    M["jute3"] = sf("q1_jute3", (0.32, 0.27, 0.16), rough=0.95, met=0.0, grain=0.35, usure=0.0, crasse=0.95, crasse_col=cr, pied=(0.0, 0.35, 0.5), graine=49)
    M["ondule"] = sf("q1_ondule", (0.2, 0.165, 0.13), rough=0.55, met=0.35, grain=0.3, coulures=1.0, usure=0.7, rouille=(0.26, 0.1, 0.04), crasse=0.7, crasse_col=cr, graine=39)
    M["ondule2"] = sf("q1_ondule2", (0.21, 0.08, 0.028), rough=0.6, met=0.45, grain=0.3, coulures=1.0, usure=0.4, crasse=0.7, crasse_col=cr, graine=40)
    M["ondule3"] = sf("q1_ondule3", (0.125, 0.11, 0.095), rough=0.55, met=0.3, grain=0.3, coulures=1.0, usure=0.7, rouille=(0.2, 0.08, 0.03), crasse=0.7, crasse_col=cr, graine=50)
    M["fer"] = sf("q1_fer", (0.1, 0.08, 0.064), rough=0.6, met=0.7, grain=0.3, coulures=1.0, usure=0.6, crasse=0.75, crasse_col=cr, graine=41)
    M["corde"] = sf("q1_corde", (0.35, 0.28, 0.17), rough=0.95, met=0.0, grain=0.2, usure=0.0, crasse=0.5, crasse_col=cr, graine=42)
    M["drapeau"] = sf("q1_drapeau", (0.55, 0.07, 0.035), rough=0.9, met=0.0, grain=0.15, usure=0.0, crasse=0.6, crasse_col=cr, graine=43)
    M["int"] = sf("q1_int", (0.008, 0.007, 0.007), rough=0.8, met=0.3, usure=0.0, crasse=0.9, graine=21)
    M["lanterne"] = MT.lumiere(S, "q1_lanterne", (1.0, 0.55, 0.2), 2.2, main=0.25)
    return M


def choix_factory(M):
    def choix(rr, x, t, patch, ou):
        """Tôles : jaunes de l'épave ; autour de la brèche et sur les bords refaits, tôle de récupération et fer brut."""
        u = rr.f()
        if ou == "av" and x > 2.88:
            return M["chevron"]
        pres = (ou == "ar" and x > -1.6) or (ou == "av" and x < 1.1)
        if pres and 4.0 < t < 10.5 and u < 0.42:
            return M["fer"] if u < 0.2 else M["roussi"]
        if patch:
            return [M["fer"], M["rouille"], M["ondule3"], M["primaire"]][int(rr.f(0, 3.99))]
        if u < 0.07:
            return M["fer"]
        if u < 0.1:
            return M["rouille"]
        if u < 0.19:
            return M["j3"]
        return M["j0"] if u < 0.62 else (M["j2"] if u < 0.86 else M["j1"])
    return choix


def cabane(lot, M, r):
    """Cabane en rondins, adossée au tronçon arrière : rondins à bouts croisés, toit en appentis de tôle ondulée dépareillée,
    pierres posées sur le toit, tuyau de poêle, porte, hublot du vaisseau monté dans le mur, volet ouvert sur le pignon est."""
    C = CAB
    hx, hy, z0, zs, zn = C["hx"], C["hy"], C["z0"], C["ze_s"], C["ze_n"]
    lot.xf = R.repere(C["cx"], C["cy"], C["rz"])
    zr = lambda y: zs + (zn - zs) * (y + hy) / (2 * hy)
    pas, rl = 0.125, 0.07
    lot.put(M["int"], G.boite((0.0, 0.0, (z0 + zs) / 2 - 0.02), (2 * hx - 0.08, 2 * hy - 0.08, zs - z0 - 0.04)))
    k = 0
    while True:
        z = z0 + rl + k * pas
        if z > zn:
            break
        over = 0.1 + r.f(0.0, 0.07)
        mm = M["rondin"] if r.f() < 0.65 else M["rondin2"]
        rr = rl * r.f(0.92, 1.08)
        if z < zs:
            if z < z0 + 0.72:                # porte : le mur sud est coupé autour d'elle
                R.rondin(lot, mm, M["bout"], (-hx - over, -hy, z), (-0.28, -hy, z), rr)
                R.rondin(lot, mm, M["bout"], (0.16, -hy, z), (hx + over, -hy, z), rr)
            else:
                R.rondin(lot, mm, M["bout"], (-hx - over, -hy, z), (hx + over, -hy, z), rr)
        R.rondin(lot, mm, M["bout"], (-hx - over, hy, z), (hx + over, hy, z), rr)
        y1 = hy if z < zs else None
        if z >= zs:
            y1 = (z - zs) / (zn - zs) * 2 * hy - hy
        for x in (-hx, hx):
            ya = -hy - 0.08 if z < zs else y1
            R.rondin(lot, mm if x > 0 else M["rondin2"], M["bout"], (x, ya, z + pas / 2), (x, hy + 0.08, z + pas / 2), rr)
        k += 1
    # poteaux de coin, chaume de calfatage (bandes claires entre rondins, irrégulières)
    for k in range(9):
        z = z0 + rl + pas * (k + 0.5)
        if z < zs:
            xa = r.f(0.2, 0.5)
            lot.put(M["toile"], G.tube([(xa, -hy - 0.05, z), (xa + r.f(0.12, 0.3), -hy - 0.05, z)], 0.014, 4))
    # toit en appentis : feuilles inégales qui se chevauchent, dépassant au sud et à l'est
    deb = 0.22
    eu, ev = (1.0, 0.0, 0.0), G.norm((0.0, 2 * hy + 2 * deb, (zn - zs) * (2 * hy + 2 * deb) / (2 * hy)))
    Lv = G.length((0.0, 2 * hy + 2 * deb, (zn - zs) * (2 * hy + 2 * deb) / (2 * hy)))
    zb = zr(-hy - deb) + 0.07
    x = -hx - deb
    mats = [M["ondule"], M["ondule2"], M["ondule"], M["ondule3"], M["ondule"], M["ondule2"], M["ondule3"]]
    i = 0
    while x < hx + deb - 0.05:
        w = min(r.f(0.28, 0.5), hx + deb - x)
        for (v0, f) in ((0.0, r.f(0.5, 0.62)), (Lv * 0.46, 0.56)):
            o = G.add((x, -hy - deb, zb), G.mul(ev, v0))
            o = G.add(o, (0.0, 0.0, 0.016 if v0 == 0 else 0.0))
            lot.put(mats[(i + (1 if v0 else 0)) % 7], R.tole_ondulee(o, eu, ev, w + 0.03, Lv * f))
        i += 1
        x += w
    for (x_, y_, s) in ((-0.5, -0.4, 0.06), (0.12, 0.05, 0.07), (0.52, -0.55, 0.05), (-0.15, 0.45, 0.055)):        # pierres sur le toit
        lot.put(M["roc"], G.sphere((x_, y_, zr(y_) + 0.09), s, 7, 4))
    for (x_) in (-0.62, 0.0, 0.58):                                                                               # perches de maintien
        lot.put(M["rondin2"], G.tube([(x_, -hy - deb + 0.03, zb + 0.03), (x_ + 0.02, hy + deb - 0.05, zb + Lv * ev[2] - 0.0)], 0.018, 5))
    # tuyau de poêle à chapeau
    px, py = 0.42, 0.25
    lot.put(M["fer"], G.tour([(zr(py), 0.055), (zr(py) + 0.72, 0.05)], 10, "z", (px, py, 0.0)))
    lot.put(M["ondule3"], G.tour([(zr(py) + 0.04, 0.09), (zr(py) + 0.1, 0.06)], 10, "z", (px, py, 0.0)))
    lot.put(M["fer"], G.tour([(zr(py) + 0.76, 0.11), (zr(py) + 0.86, 0.02)], 10, "z", (px, py, 0.0), cap0=True))
    for a in (0.5, 2.6, 4.7):
        lot.put(M["fer"], G.tube([(px + 0.05 * math.cos(a), py + 0.05 * math.sin(a), zr(py) + 0.7), (px + 0.1 * math.cos(a), py + 0.1 * math.sin(a), zr(py) + 0.78)], 0.006, 3))
    # porte de planches, linteau, marche ; lanterne
    lot.put(M["int"], G.boite((-0.06, -hy + 0.02, z0 + 0.33), (0.42, 0.04, 0.66)))
    for (x_, w_, m) in ((-0.22, 0.09, "planche"), (-0.12, 0.1, "planche2"), (-0.01, 0.09, "planche"), (0.09, 0.08, "planche2")):
        lot.put(M[m], G.boite((x_, -hy - 0.012, z0 + 0.32), (w_, 0.03, 0.64 + 0.03 * math.sin(x_ * 20))))
    for z_ in (z0 + 0.14, z0 + 0.5):
        lot.put(M["fer"], G.boite((-0.09, -hy - 0.032, z_), (0.3, 0.012, 0.035)))
    R.rondin(lot, M["rondin"], M["bout"], (-0.36, -hy - 0.03, z0 + 0.74), (0.24, -hy - 0.03, z0 + 0.74), 0.05)
    lot.put(M["planche"], G.boite((-0.06, -hy - 0.17, z0 - 0.0), (0.56, 0.24, 0.06)))
    R.lanterne(lot, M["fer"], M["lanterne"], (0.27, -hy - 0.1, z0 + 0.76))
    lot.put(M["fer"], G.tube([(0.27, -hy - 0.01, z0 + 0.82), (0.27, -hy - 0.1, z0 + 0.82)], 0.008, 3))
    # hublot du vaisseau monté dans le mur, à l'ouest de la porte (récupération), planches autour
    lot.put(M["planche2"], G.boite((-0.56, -hy - 0.07, z0 + 0.46), (0.3, 0.02, 0.28)))
    C_n = (0.0, -1.0, 0.0)
    lot.put(M["bague"], G.oriente(G.tour([(0.0, 0.105), (0.03, 0.1), (0.035, 0.07), (0.012, 0.065)], 16, "z"), (-0.56, -hy - 0.08, z0 + 0.46), C_n))
    lot.put(M["verre"], G.oriente(G.tour([(0.014, 0.068), (0.014, 0.0)], 16, "z"), (-0.56, -hy - 0.08, z0 + 0.46), C_n))
    # pignon est : volet ouvert, fenêtre noire ; rondins d'étai contre le pignon
    lot.put(M["int"], G.boite((hx + 0.075, -0.08, z0 + 0.5), (0.02, 0.3, 0.22)))
    lot.put(M["planche"], G.boite((hx + 0.13, -0.27, z0 + 0.5), (0.14, 0.02, 0.24), 0.7))
    lot.put(M["fer"], G.boite((hx + 0.085, -0.08, z0 + 0.62), (0.014, 0.34, 0.03)))
    R.rondin(lot, M["rondin2"], M["bout"], (hx + 0.5, 0.42, 0.14), (hx + 0.06, 0.42, z0 + 0.85), 0.05)
    # outils et câble le long du mur sud
    lot.put(M["rondin2"], G.tube([(0.45, -hy - 0.09, z0), (0.52, -hy - 0.1, z0 + 0.5)], 0.012, 4))
    lot.put(M["fer"], G.boite((0.52, -hy - 0.1, z0 + 0.52), (0.1, 0.012, 0.05), 0.0, 0.0, 0.3))
    lot.put(M["rondin2"], G.tube([(0.6, -hy - 0.09, z0), (0.6, -hy - 0.11, z0 + 0.46)], 0.011, 4))
    lot.put(M["ondule3"], G.tour([(z0 + 0.0, 0.05), (z0 + 0.1, 0.04)], 8, "z", (0.6, -hy - 0.1, 0.0)))
    F.faisceau(lot, [M["noir"], M["rouge"]], (-hx, -hy - 0.07, zs - 0.05), (0.3, -hy - 0.07, zs - 0.02), 0.09, 0.009, 2, 0.02, r)
    lot.xf = None


def plateforme(lot, M, r):
    """Plate-forme de rondins : longueurs inégales (le contour n'est jamais droit), planches jetées par-dessus."""
    y, k = -2.32, 0
    while y < -0.48:
        xa, xb = -2.0 + r.f(-0.2, 0.25), 1.58 + r.f(-0.3, 0.28)
        if y > -1.0:
            xa = max(xa, -1.42)
        R.rondin(lot, M["rondin"] if r.f() < 0.6 else M["rondin2"], M["bout"], (xa, y, 0.09), (xb, y + r.f(-0.02, 0.02), 0.09), 0.075 * r.f(0.92, 1.1))
        y += 0.135
        k += 1
    for (x, y0, y1) in ((-1.86, -2.35, -1.1), (-0.6, -2.4, -1.5), (0.85, -2.38, -0.6), (1.48, -2.3, -1.0)):
        lot.put(M["rondin2"], G.tube([(x, y0, 0.03), (x, y1, 0.03)], 0.04, 5))
    for (x, y, w, l, rz) in ((-1.5, -1.95, 0.22, 0.95, 0.07), (-1.25, -1.82, 0.18, 0.8, -0.05), (1.0, -1.62, 0.2, 0.95, 0.12), (0.12, -1.95, 0.2, 0.9, -0.1)):
        lot.put(M["planche"] if rz > 0 else M["planche2"], G.boite((x, y, 0.185), (w, l, 0.028), rz))


def rempart(lot, M, r):
    """Rempart de sacs en U devant la porte, ouvert à l'est ; un créneau à la place d'un sac ; rouleaux de barbelé devant."""
    jutes = [M["jute"], M["jute"], M["jute2"], M["jute3"]]
    rs = G.Rnd(107)
    a, b, c, d = (-1.72, -1.72), (-1.72, -2.42), (-0.2, -2.56), (0.36, -2.28)
    R.rang_sacs(lot, jutes, a, b, 0.16, 4, rs)
    R.rang_sacs(lot, jutes, b, c, 0.16, 4, rs)
    R.rang_sacs(lot, jutes, c, d, 0.16, 3, rs)
    # barbelé : hélice sur piquets en croix
    for (a, b) in (((-3.35, -2.68), (-1.95, -2.82)), ((0.65, -2.72), (2.35, -2.58))):
        L = G.length(G.sub((a[0], a[1], 0.0), (b[0], b[1], 0.0)))
        n = int(L / 0.022)
        pts = []
        for k in range(n + 1):
            t = k / float(n)
            ang = k * 0.42
            pts.append((a[0] + (b[0] - a[0]) * t + 0.03 * math.sin(ang), a[1] + (b[1] - a[1]) * t + 0.12 * math.cos(ang), 0.15 + 0.13 * math.sin(ang)))
        lot.put(M["fer"], G.tube(pts, 0.0065, 3))
        for q in range(4):
            t = (q + 0.5) / 4.0
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            lot.put(M["rondin2"], G.tube([(x - 0.13, y, 0.0), (x + 0.11, y + 0.02, 0.32)], 0.018, 4))
            lot.put(M["rondin"], G.tube([(x + 0.13, y, 0.0), (x - 0.11, y - 0.02, 0.32)], 0.018, 4))


def auvent(lot, M, r):
    """Le cœur dans sa cage, calé sur des traverses, sous l'aile sud arrachée, relevée en auvent sur deux perches."""
    R.coeur(lot, M, CO, 0.27, 20.0)
    for (a, b) in (((CO[0] - 0.42, CO[1] - 0.38, 0.2), (CO[0] + 0.42, CO[1] - 0.38, 0.2)), ((CO[0] - 0.42, CO[1] + 0.34, 0.2), (CO[0] + 0.42, CO[1] + 0.34, 0.2))):
        R.rondin(lot, M["rondin2"], M["bout"], a, b, 0.06)
    # aile : pan incliné, tôles et chevrons de l'âge 0
    hz = lambda y: 1.5 + (y + 0.1) * 0.32
    A, B, B1, A1 = (0.02, 0.1, hz(0.1)), (1.62, 0.1, hz(0.1)), (1.32, -1.0, hz(-1.0)), (0.22, -1.08, hz(-1.08))
    Q.aile_panneau(lot, M, r, A, B, B1, A1, ep=0.05, casse=False)
    for (p, h) in (((0.26, -1.03), hz(-1.03)), ((1.28, -0.96), hz(-0.96))):
        R.rondin(lot, M["rondin"], M["bout"], (p[0], p[1], 0.17), (p[0], p[1], h - 0.02), 0.05)
        lot.put(M["corde"], G.tour([(h - 0.14, 0.058), (h - 0.08, 0.058)], 8, "z", (p[0], p[1], 0.0)))
    lot.put(M["rondin2"], G.tube([(0.26, -1.03, 0.75), (1.28, -0.96, 0.92)], 0.02, 4))
    # flexibles, câbles et conduits : le cœur reste branché au vaisseau par ce qui a survécu
    F.flexible(lot, M["gaine"], [G.add(CO, (0.05, -0.22, -0.2)), (1.15, -1.28, 0.25), (1.75, -1.42, 0.32), (2.05, -1.05, 0.55)], 0.045)
    F.flexible(lot, M["gaine"], [G.add(CO, (-0.25, 0.1, -0.15)), (0.0, -0.45, 0.38), (-0.2, -0.32, 0.68)], 0.04)
    F.faisceau(lot, [M["rouge"], M["noir"], M["noir"]], G.add(CO, (0.3, 0.1, 0.32)), (1.45, 0.05, 1.05), 0.1, 0.013, 3, 0.03, r)
    F.faisceau(lot, [M["noir"], M["rouge"]], G.add(CO, (-0.3, 0.05, 0.3)), (-0.05, -0.15, 1.42), 0.16, 0.012, 2, 0.028, r)
    # lambeaux qui pendent de l'auvent, seau, pelle, boîte à outils devant le cœur
    R.tonneau(lot, M["ondule3"], M["fer"], (1.05, -1.5, 0.17), 0.075, 0.13)
    lot.put(M["rondin2"], G.tube([(0.2, -1.7, 0.17), (0.65, -1.45, 0.42)], 0.012, 4))
    lot.put(M["fer"], G.boite((0.68, -1.43, 0.44), (0.1, 0.09, 0.02), 0.5, 0.5))


def reparations(lot, M, r, pose_ar, pose_av, AR, AV):
    """Sur la coque : planches clouées au bord de la brèche, toile sur la tuyère sud, vitre remplacée, cordages, étais."""
    # planches sur le crâne, en travers de la brèche
    lot.xf = pose_av
    for (x, ta, tb) in ((0.82, 5.0, 8.9), (0.97, 5.5, 9.3), (1.14, 4.85, 8.4), (1.3, 5.3, 8.1)):
        w = r.f(0.11, 0.15)
        mesh, _ = F.plaque(AV, x, x + w, ta, tb, 0.0, 0.05, (r.f(-0.06, 0.06), r.f(-0.06, 0.06)))
        lot.put(M["planche"] if r.f() < 0.5 else M["planche2"], mesh)
    mesh, _ = F.plaque(AV, 1.47, 1.82, 3.05, 3.95, 0.05, 0.075, (0.0, 0.0))              # planches sur la vitre cassée
    lot.put(M["planche"], mesh)
    mesh, _ = F.plaque(AV, 1.5, 1.75, 3.2, 3.65, 0.075, 0.095, (0.02, 0.0))
    lot.put(M["planche2"], mesh)
    # toile sur l'échine du crâne, sanglée par des cordes
    mesh, _ = F.plaque(AV, 0.42, 0.94, 1.8, 4.4, 0.05, 0.07, (0.08, -0.06))
    lot.put(M["toile"], mesh)
    for x in (0.52, 0.8):
        lot.put(M["corde"], G.tube([AV(x, t, 0.085) for t in [1.6 + k * 0.28 for k in range(11)]], 0.012, 4))
    R.coque_menus(lot, M, AV, 2.3, 3.1, 4.5, 8.5, r, 14)
    # tronçon arrière : planches sur le dos troué, grosse toile sur le flanc près de la brèche
    lot.xf = pose_ar
    for (x, ta, tb) in ((-2.1, 1.9, 3.3), (-1.92, 2.05, 3.35), (-1.72, 1.95, 3.2), (-1.55, 2.15, 3.4)):
        mesh, _ = F.plaque(AR, x, x + 0.13, ta, tb, 0.0, 0.05, (r.f(-0.05, 0.05), r.f(-0.05, 0.05)))
        lot.put(M["planche2"] if r.f() < 0.5 else M["planche"], mesh)
    R.coque_menus(lot, M, AR, -3.0, -1.2, 3.8, 8.6, r, 22)
    lot.xf = None
    # toile sur le capot de la tuyère sud, cordes
    ps = pose_ar
    nc, nz, nr = -1.12, -0.05, 0.6

    def surf(x, a, g=0.0):
        rr = nr + 0.05 + g + 0.02 * math.sin(x * 9 + a * 5)
        return (x, nc + rr * math.cos(a), nz + rr * math.sin(a))
    lot.xf = lambda p: ps((G.rot_z((p[0] + 1.25, p[1], p[2]), E["cant"])[0] - 1.25, G.rot_z((p[0] + 1.25, p[1], p[2]), E["cant"])[1], p[2]))
    mesh, _ = F.plaque(surf, -2.75, -1.75, 0.5, 2.95, 0.0, 0.02, (0.08, -0.1))
    # plaque travaille en t : t → angle (un t vaut un radian ici)
    lot.put(M["toile2"], mesh)
    for (x) in (-2.6, -2.25, -1.92):
        lot.put(M["corde"], G.tube([surf(x, a, 0.035) for a in [0.4 + k * 0.28 for k in range(10)]], 0.012, 4))
    lot.xf = None


def etais(lot, M, r, pose_ar, pose_av, AR, AV):
    """Piles de rondins croisés sous les tronçons, étais obliques contre les flancs : l'épave est calée."""
    # piles
    for (x, y, n) in ((-2.05, -2.15, 0), (-3.1, -2.3, 5), (2.45, -1.62, 5), (1.72, -1.72, 4), (-3.1, 1.15, 5), (-1.9, 1.75, 4), (3.1, 0.65, 3)):
        for k in range(n):
            z = 0.075 + k * 0.125
            if k % 2:
                for dx in (-0.2, 0.2):
                    R.rondin(lot, M["rondin"], M["bout"], (x + dx, y - 0.38, z), (x + dx + r.f(-0.03, 0.03), y + 0.38, z), 0.07)
            else:
                for dy in (-0.2, 0.2):
                    R.rondin(lot, M["rondin2"], M["bout"], (x - 0.38, y + dy, z), (x + 0.38, y + dy + r.f(-0.03, 0.03), z), 0.07)
    # étais obliques : pied au sol calé par un pieu, tête sur une semelle de bois sur la coque
    for (pied, tete) in (((-2.5, -2.45), pose_ar((-2.5, -1.6, 0.25))), ((-3.65, -2.25), pose_ar((-3.0, -1.5, -0.1))), ((2.05, -1.95), pose_av((2.1, -0.75, -0.35))),
                         ((3.05, -1.75), pose_av((2.75, -0.5, -0.25)))):
        R.rondin(lot, M["rondin"], M["bout"], (pied[0], pied[1], 0.04), tete, 0.052)
        lot.put(M["rondin2"], G.tour([(0.0, 0.03), (0.2, 0.025)], 6, "z", (pied[0] - 0.08, pied[1] - 0.1, 0.0), cap1=True))
        lot.put(M["planche2"], G.oriente(G.boite((0, 0, 0), (0.2, 0.2, 0.05)), tete, G.norm(G.sub(tete, (pied[0], pied[1], 0.04)))))


def chantier(lot, M, r):
    """Le chantier devant le crâne : chèvre en trois perches qui lève une tôle jaune, échafaudage de perches, tas de bois."""
    # chèvre
    t = (2.32, -2.15, 1.85)
    for (x, y) in ((1.86, -2.5), (2.82, -2.48), (2.34, -1.55)):
        R.rondin(lot, M["rondin"], M["bout"], (x, y, 0.0), t, 0.042)
    lot.put(M["corde"], G.tour([(t[2] - 0.1, 0.06), (t[2] - 0.02, 0.06)], 8, "z", (t[0], t[1], 0.0)))
    q = (t[0], t[1], 0.86)
    lot.put(M["corde"], G.tube([t, q], 0.008, 4))
    lot.put(M["fer"], G.tour([(-0.03, 0.05), (0.03, 0.05)], 10, "y", (q[0], q[1], q[2])))
    for s in (-1, 1):
        lot.put(M["corde"], G.tube([q, (q[0] + s * 0.2, q[1] - 0.02, q[2] - 0.26)], 0.006, 3))
    lot.put(M["j1"], G.boite((q[0], q[1], q[2] - 0.36), (0.56, 0.03, 0.26), 0.2, 0.08))
    lot.put(M["riv"], G.rivets_le_long([((q[0] - 0.18 + 0.12 * k, q[1] - 0.06, q[2] - 0.29), (0, -1, 0)) for k in range(4)], 0.016, 0.01))
    lot.put(M["corde"], G.tube(G.chainette((t[0] - 0.02, t[1], 1.7), (1.92, -2.46, 0.3), 0.04, 8), 0.007, 3))
    # échafaudage de perches le long du flanc du crâne : perches, longrines, planches, liens
    ys, yn = -1.35, -0.92
    for x in (1.72, 2.48, 3.15):
        h = 1.62 - (x - 1.72) * 0.34
        lot.put(M["rondin2"], G.tube([(x, ys - 0.02, 0.0), (x + 0.02, ys, h)], 0.024, 5))
        lot.put(M["rondin"], G.tube([(x, yn, 0.0), (x - 0.01, yn, h + 0.15)], 0.024, 5))
        lot.put(M["rondin2"], G.tube([(x, ys, 0.55), (x, yn, 0.57)], 0.018, 4))
        lot.put(M["rondin"], G.tube([(x, ys, 1.0), (x, yn, 1.01)], 0.018, 4))
        for z in (0.55, 1.0):
            lot.put(M["corde"], G.tour([(z - 0.03, 0.033), (z + 0.03, 0.033)], 6, "z", (x, ys, 0.0)))
    lot.put(M["rondin"], G.tube([(1.68, ys, 0.58), (3.2, ys, 0.6)], 0.018, 4))
    lot.put(M["rondin2"], G.tube([(1.68, ys, 1.03), (3.2, ys, 1.02)], 0.018, 4))
    lot.put(M["rondin"], G.tube([(1.72, ys, 0.1), (2.48, ys, 0.95)], 0.013, 4))
    for (x, w) in ((1.78, 0.36), (2.18, 0.3), (2.52, 0.36), (2.92, 0.26)):
        lot.put(M["planche"] if x < 2.3 else M["planche2"], G.boite((x + w / 2, (ys + yn) / 2, 1.04), (w - 0.015, 0.34 + r.f(-0.04, 0.04), 0.024), r.f(-0.04, 0.04)))
    R.echelle(lot, M["rondin"], (3.24, ys - 0.2, 0.0), (3.24, ys + 0.05, 1.05))
    # tas de planches, tas de rondins aux bouts clairs (tous de face, c'est leur intérêt)
    for k in range(5):
        lot.put(M["planche"] if k % 2 else M["planche2"], G.boite((3.05 + r.f(-0.04, 0.04), -2.42, 0.02 + 0.03 * k), (0.72 + r.f(-0.1, 0.05), 0.2, 0.026), 0.2 + r.f(-0.05, 0.05)))
    for (i, n, z) in ((0, 4, 0.06), (1, 3, 0.165), (2, 2, 0.27), (3, 1, 0.375)):
        for j in range(n):
            x = -3.42 + 0.115 * (j + i * 0.5)
            R.rondin(lot, M["rondin"] if (i + j) % 2 else M["rondin2"], M["bout"], (x, -3.05 + r.f(-0.08, 0.03), z), (x + r.f(-0.04, 0.04), -2.36 + r.f(-0.05, 0.05), z), 0.058)


def contour(lot, M, r, pose_ar, pose_av, AV):
    """Ce qui casse la ligne du dos : perches d'échafaudage côté nord du crâne, planches sur le dos, mirador de perches dans le
    creux de la cassure, chevalet au-dessus du tronçon arrière ; c'est du bois, pas un événement de plus."""
    # perches nord : elles dépassent du dos à l'écran, inégales
    tops = ((1.15, 3.25), (1.72, 3.5), (2.3, 3.1), (2.85, 2.75), (3.3, 2.1))
    yn = 1.05
    for i, (x, h) in enumerate(tops):
        R.rondin(lot, M["rondin"] if i % 2 else M["rondin2"], M["bout"], (x, yn + r.f(-0.05, 0.05), 0.0), (x + r.f(-0.03, 0.03), yn - 0.05, h), 0.036)
    for (xa, xb, z) in ((1.1, 3.35, 1.75), (1.1, 2.9, 2.5)):
        R.rondin(lot, M["rondin2"], M["bout"], (xa, yn - 0.06, z), (xb, yn - 0.04, z + r.f(-0.05, 0.05)), 0.024)
    for i, (x, h) in enumerate(tops[:4]):
        for z in (1.75, 2.5):
            if z < h:
                lot.put(M["corde"], G.tour([(z - 0.035, 0.044), (z + 0.035, 0.044)], 6, "z", (x, yn - 0.05, 0.0)))
    # perches qui reviennent sur le dos, passerelle de planches
    dos = [pose_av((x, 0.15, 1.28 - 0.3 * max(0.0, x - 1.4))) for x in (0.95, 1.5, 2.05)]
    for (p, x) in zip(dos, (1.15, 1.72, 2.3)):
        lot.put(M["rondin2"], G.tube([(x, yn - 0.05, 2.5), p], 0.022, 4))
    for (x, y, z, w, l, rz) in ((1.55, 0.72, 2.56, 0.32, 0.72, 0.08), (1.92, 0.76, 2.56, 0.28, 0.66, -0.06), (2.24, 0.72, 2.56, 0.3, 0.62, 0.1)):
        lot.put(M["planche"] if rz > 0 else M["planche2"], G.boite((x, y, z), (w, l, 0.026), rz))
    # mirador en trois perches dans le creux de la cassure, plate-forme, toit de toile
    c = (0.02, 0.85)
    zp = 2.72
    for (dx, dy) in ((-0.5, 0.42), (0.5, 0.48), (0.04, -0.55)):
        R.rondin(lot, M["rondin"], M["bout"], (c[0] + dx, c[1] + dy, 0.0), (c[0] + dx * 0.32, c[1] + dy * 0.32, zp + 0.44), 0.04)
    for (a, b) in (((-0.32, 0.26), (0.32, 0.3)), ((0.32, 0.3), (0.02, -0.34)), ((0.02, -0.34), (-0.32, 0.26))):
        lot.put(M["rondin2"], G.tube([(c[0] + a[0], c[1] + a[1], zp - 0.02), (c[0] + b[0], c[1] + b[1], zp - 0.02)], 0.024, 4))
    lot.put(M["planche"], G.boite((c[0], c[1] + 0.03, zp + 0.012), (0.66, 0.6, 0.026), 0.2))
    for (a, b) in (((-0.3, -0.26), (0.32, -0.28)), ((0.32, -0.28), (0.33, 0.3))):
        lot.put(M["rondin2"], G.tube([(c[0] + a[0], c[1] + a[1], zp + 0.26), (c[0] + b[0], c[1] + b[1], zp + 0.26)], 0.012, 4))
    # plate-forme ouverte : garde-corps sur trois côtés, toile roulée, caisse, fanion
    for (a_, b_) in (((-0.32, 0.3), (-0.32, -0.26)),):
        lot.put(M["rondin2"], G.tube([(c[0] + a_[0], c[1] + a_[1], zp + 0.26), (c[0] + b_[0], c[1] + b_[1], zp + 0.26)], 0.012, 4))
    lot.put(M["toile"], G.tube([(c[0] - 0.26, c[1] + 0.24, zp + 0.08), (c[0] + 0.24, c[1] + 0.27, zp + 0.08)], 0.055, 8))
    R.caisse(lot, M["planche2"], M["planche"], M["fer"], (c[0] - 0.14, c[1] - 0.08, zp + 0.025), (0.2, 0.17, 0.15), 0.3)
    R.lanterne(lot, M["fer"], M["lanterne"], (c[0] + 0.2, c[1] - 0.2, zp + 0.3))
    R.echelle(lot, M["rondin2"], (c[0] + 0.18, c[1] - 0.72, 1.0), (c[0] + 0.1, c[1] - 0.3, zp + 0.02), 0.22, 0.2, 0.016, 0.01)
    # chevalet sur le tronçon arrière : deux perches en A, barre, tôle suspendue
    p0, p1 = pose_ar((-2.6, 0.8, 1.05)), pose_ar((-2.6, -0.65, 1.2))
    t = pose_ar((-2.45, 0.05, 2.25))
    lot.put(M["rondin"], G.tube([p0, t], 0.03, 5))
    lot.put(M["rondin2"], G.tube([p1, t], 0.03, 5))
    lot.put(M["corde"], G.tube([t, G.add(t, (0.05, -0.2, -0.45))], 0.008, 3))
    lot.put(M["j2"], G.boite(G.add(t, (0.05, -0.2, -0.62)), (0.34, 0.03, 0.3), 0.4, 0.3))


def mat_drapeau(lot, M, r):
    """Mât de drapeau en bois à l'arrière gauche (l'événement de silhouette) : tige, haubans, drapeau de toile usée."""
    b = (-4.42, 0.4)
    h = 5.4
    R.rondin(lot, M["rondin"], M["bout"], (b[0], b[1], 0.0), (b[0] + 0.03, b[1], h), 0.03)
    for k in range(4):
        z = 0.1 + k * 0.1
        lot.put(M["rondin2"], G.boite((b[0], b[1], z), (0.46 if k % 2 == 0 else 0.1, 0.1 if k % 2 == 0 else 0.46, 0.09)))
    for (dx, dy) in ((-0.7, 0.45), (0.7, 0.55), (-0.2, -0.85)):
        lot.put(M["corde"], G.tube([(b[0], b[1], 3.6), (b[0] + dx, b[1] + dy, 0.0)], 0.006, 3))
    # drapeau : deux bandes qui ondulent, déchiré au bout
    rings = []
    for i in range(11):
        t = i / 10.0
        x = b[0] + 0.05 + 0.92 * t
        dz = -0.13 * t + 0.035 * math.sin(t * 8.0)
        dy = 0.07 * math.sin(t * 6.5 + 0.4)
        h1, h0 = h - 0.02 + dz, h - 0.5 + dz + 0.1 * t * (1 if i % 3 else 0)
        rings.append([(x, b[1] + dy, h1), (x, b[1] + dy, (h1 + h0) / 2), (x, b[1] + dy, h0)])
    lot.put(M["drapeau"], G.loft(rings, closed=False))


def sol(lot, M, r):
    R.butte_nez(lot, M, r, 0.95)
    lot.xf = F.pose(zmin=0.002)
    for (c, rx, ry, h, m, n) in (((-1.9, 1.75, 0.0), 2.1, 0.3, 0.14, "terre", 34), ((0.2, 2.05, 0.0), 1.3, 0.3, 0.12, "terre2", 24)):
        lot.put(M[m], F.tertre(c, rx, ry, h, r, na=max(28, n), nr=9))
    lot.xf = None
    R.cailloux(lot, M, r, 18, -4.1, 4.5, -3.0, 2.4, sauf=lambda x, y: abs(y) < 2.3 and abs(x) < 3.0)
    R.toles_sol(lot, M, r, (((-3.65, -2.85), 0.34, "j0", 0.0), ((3.65, -2.05), 0.3, "j2", 0.5), ((-3.45, 2.2), 0.36, "primaire", 0.0), ((2.0, 1.85), 0.42, "j1", 0.4),
                            ((3.0, 2.25), 0.26, "j3", 0.0), ((0.6, 2.25), 0.26, "roussi", 0.0), ((1.1, -3.0), 0.24, "j1", 0.35)))
    # caisses, tonneaux, aire d'outils, foyer de pierres
    rr = G.Rnd(131)
    for (c, s, rz) in (((-1.42, -2.0, 0.17), (0.34, 0.28, 0.3), 0.2), ((-1.05, -2.1, 0.17), (0.26, 0.22, 0.2), -0.25), ((-1.22, -2.05, 0.47), (0.22, 0.2, 0.17), 0.5),
                       ((1.25, -2.0, 0.17), (0.3, 0.26, 0.26), 0.4), ((3.55, -1.35, 0.0), (0.4, 0.3, 0.3), -0.3)):
        R.caisse(lot, M["planche2"], M["planche"], M["fer"], c, s, rz)
    for (c, h, co) in (((-0.55, -2.05, 0.17), 0.34, False), ((-0.32, -1.98, 0.17), 0.3, False), ((3.55, -2.15, 0.0), 0.36, True), ((-3.75, -1.2, 0.0), 0.34, True)):
        R.tonneau(lot, M["planche2"] if h > 0.31 else M["ondule2"], M["fer"], c, 0.105, h, couche=co, rz=0.6)
    R.menus(lot, [M["fer"], M["planche"], M["noyau"], M["bague"]], rr, 46, -2.0, 1.5, -2.3, -1.6, 0.17)
    R.menus(lot, [M["fer"], M["j1"], M["noyau"], M["nu"]], rr, 40, -4.3, 4.6, -3.1, 2.5, 0.0)
    for k in range(7):                                                                                   # foyer de pierres, cendres
        a = TAU * k / 7
        lot.put(M["roc"], G.sphere((-2.7 + 0.2 * math.cos(a), -2.92 + 0.14 * math.sin(a), 0.05), 0.065, 6, 3))
    lot.put(M["brule"], G.butte_polaire((-2.7, -2.92, 0.0), 0.14, 0.1, 0.035, rr, 3, 14, 0.2, 0.1))
    lot.put(M["fer"], G.tube([(-2.9, -2.92, 0.0), (-2.7, -2.92, 0.4), (-2.5, -2.92, 0.0)], 0.009, 3))
    lot.put(M["fer"], G.tour([(0.2, 0.08), (0.32, 0.075), (0.34, 0.0)], 8, "z", (-2.7, -2.92, 0.0)))
    # cordes qui courent du crâne à la chèvre et de la cabane à la queue
    lot.put(M["corde"], G.tube(G.chainette((3.15, -1.33, 1.3), (3.62, -2.0, 0.02), 0.08, 8), 0.007, 3))


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(2130)
    ra = G.Rnd(2131)
    E["choix"] = choix_factory(M)
    pose_ar, pose_av, AR, AV = R.carcasse(lot, M, r, ra, E)
    reparations(lot, M, G.Rnd(2132), pose_ar, pose_av, AR, AV)
    plateforme(lot, M, G.Rnd(2133))
    cabane(lot, M, G.Rnd(2134))
    rempart(lot, M, G.Rnd(2135))
    auvent(lot, M, G.Rnd(2136))
    etais(lot, M, G.Rnd(2137), pose_ar, pose_av, AR, AV)
    chantier(lot, M, G.Rnd(2138))
    contour(lot, M, G.Rnd(2141), pose_ar, pose_av, AV)
    mat_drapeau(lot, M, G.Rnd(2139))
    sol(lot, M, G.Rnd(2140))
    return {"pose": {k: v for k, v in E.items() if k != "choix"}}
