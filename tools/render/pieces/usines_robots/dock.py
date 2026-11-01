"""DOCK DE PILOTAGE (fo-robot-dock), âge 10 · Haute technologie, emprise 7×7 (x ±3,5 ; y ±4,95). PLAN ROBOTS §5 bis.

Lecture : un plateau rond levé sur des pieds télescopiques (le vide dessous : signature de l'ère IV). Son dôme lisse est
OUVERT, ses 4 lunes emboîtées repliées vers le nord comme une capote, tirées par 2 grands vérins : le dedans noir mat, strié
de bleu, fait un écrin. Sur le plateau tournant, un robot debout en cours d'assemblage (torse ouvert, un seul bras posé) et
3 bras de montage blancs qui travaillent sur lui. Au sud, la rampe de sortie à chevrons entre 2 balises. Autour : cabine de
pilotage à écrans, râtelier de membres, radôme, parabole, fouets. Bible (époque 10) : carénage #A8ADB3, noir mat #222428,
voyants #3AA8FF, luminance 82.
"""
import math

import geo as G
import mat as MT
import outils as O

TAU = G.TAU
ZD = 0.72          # dessus du plateau
CD = (0.0, 0.3)    # centre du plateau
RD = 3.32          # rayon du plateau
CH = (0.0, 0.75, ZD - 0.1)   # charnière du dôme
ROB = (0.0, -0.85)     # centre du plateau tournant, pied du robot (repère du dôme)
PSI = -math.radians(24.0)   # le dôme, le robot et les bras regardent le sud-ouest (trois-quarts, soleil dans l'ouverture)
K_ROB = 1.22           # échelle du robot sur le plateau


def matieres(S):
    M = {}
    MT.PATINE.update(ta=0.14, ra=0.2, ec=0.42, nu_k=1.3, ec_col=(0.13, 0.095, 0.055), sans=("noir", "ecran", "chrome"))
    sf = MT.surface
    cr = (0.012, 0.013, 0.016)
    M["car"] = sf("d10_car", (0.6, 0.46, 0.24), rough=0.42, met=0.08, tole=(1.15, 0.5), joint=0.32, joint_l=0.012, var=0.09, usure=0.55,
                  nu=(0.78, 0.7, 0.52), crasse=0.85, crasse_col=cr, coulures=0.7, rouille=(0.09, 0.065, 0.04), pied=(0.4, 1.8, 0.45), grain=0.09, relief=0.8, graine=101)
    M["car2"] = sf("d10_car2", (0.48, 0.365, 0.185), rough=0.45, met=0.08, tole=(0.8, 0.36), joint=0.32, joint_l=0.012, var=0.1, usure=0.55,
                   nu=(0.72, 0.64, 0.46), crasse=0.85, crasse_col=cr, coulures=0.7, rouille=(0.08, 0.06, 0.035), grain=0.1, relief=0.8, graine=102)
    M["uni"] = sf("d10_uni", (0.5, 0.39, 0.21), rough=0.42, met=0.08, usure=0.5, nu=(0.76, 0.68, 0.5), crasse=0.8, crasse_col=cr, coulures=0.55, rouille=(0.09, 0.065, 0.04), grain=0.08, graine=103)
    M["blanc"] = sf("d10_blanc", (0.56, 0.45, 0.27), rough=0.38, met=0.05, usure=0.45, nu=(0.8, 0.72, 0.55), crasse=0.75, crasse_col=cr, coulures=0.55, rouille=(0.09, 0.065, 0.04), grain=0.07, graine=104)
    M["noir"] = sf("d10_noir", (0.016, 0.017, 0.02), rough=0.55, met=0.3, usure=0.25, nu=(0.13, 0.135, 0.15), crasse=0.3, crasse_col=(0.004, 0.004, 0.005), graine=105)
    M["noir_p"] = sf("d10_noir_p", (0.022, 0.023, 0.027), rough=0.5, met=0.35, tole=(0.7, 0.34), joint=0.3, joint_l=0.012, var=0.15, usure=0.3,
                     nu=(0.16, 0.165, 0.18), crasse=0.3, crasse_col=(0.004, 0.004, 0.005), relief=0.7, graine=106)
    M["chrome"] = sf("d10_chrome", (0.58, 0.6, 0.63), rough=0.16, met=1.0, usure=0.0, crasse=0.3, crasse_col=cr, graine=107)
    M["acier"] = sf("d10_acier", (0.15, 0.155, 0.165), rough=0.4, met=0.85, usure=0.5, nu=(0.6, 0.61, 0.63), crasse=0.5, crasse_col=cr, graine=108)
    M["sol"] = sf("d10_sol", (0.19, 0.155, 0.1), rough=0.6, met=0.2, tole=(0.6, 0.6), joint=0.35, joint_l=0.01, var=0.14, usure=0.45, nu=(0.36, 0.31, 0.22),
                  crasse=0.85, crasse_col=cr, relief=0.5, grain=0.14, graine=109)
    M["joue"] = sf("d10_joue", (0.13, 0.115, 0.09), rough=0.85, met=0.1, usure=0.5, nu=(0.3, 0.27, 0.21), crasse=0.85, crasse_col=cr, grain=0.18, graine=114)
    M["rampe"] = sf("d10_rampe", (0.21, 0.195, 0.17), rough=0.8, met=0.12, tole=(0.9, 0.4), joint=0.4, joint_l=0.009, var=0.14, usure=0.5, nu=(0.36, 0.34, 0.3),
                    crasse=0.85, crasse_col=cr, relief=0.5, grain=0.18, graine=113)
    M["chevron"] = sf("d10_chevron", (0.3, 0.23, 0.11), rough=0.6, met=0.1, bandes=(0.22, (0.025, 0.023, 0.024), 0.5), usure=0.55, nu=(0.42, 0.38, 0.3),
                      crasse=0.8, crasse_col=cr, grain=0.14, graine=110)
    M["caout"] = sf("d10_caout", (0.02, 0.02, 0.022), rough=0.65, met=0.0, usure=0.2, nu=(0.07, 0.07, 0.075), crasse=0.3, graine=111)
    M["orange"] = sf("d10_orange", (0.55, 0.16, 0.02), rough=0.4, met=0.1, usure=0.3, nu=(0.7, 0.55, 0.4), crasse=0.5, crasse_col=cr, graine=112)
    M["bleu"] = MT.degrade(S, "d10_bleu", (0.32, 0.68, 1.0), (0.01, 0.12, 0.5), 0.72, main=0.85, crust=(14.0, 0.35, 31.0))
    M["bleu_f"] = MT.degrade(S, "d10_bleu_f", (0.26, 0.6, 1.0), (0.008, 0.1, 0.42), 0.45, main=0.85, crust=(14.0, 0.35, 33.0), mode="uv", rayon=0.12)
    M["ecran"] = MT.degrade(S, "d10_ecran", (0.22, 0.66, 1.0), (0.004, 0.05, 0.16), 0.75, main=0.82, base=(0.008, 0.03, 0.06), crust=(55.0, 0.75, 6.0), mode="uv", rayon=0.34)
    M["blanc_l"] = MT.degrade(S, "d10_blanc_l", (0.7, 0.88, 1.0), (0.05, 0.25, 0.6), 1.5, main=0.8, crust=(20.0, 0.3, 35.0))
    M["rouge"] = MT.degrade(S, "d10_rouge", (1.0, 0.2, 0.1), (0.4, 0.01, 0.005), 1.5, main=0.75, crust=(20.0, 0.3, 37.0))
    M["verre"] = MT.verre("d10_verre", col=(0.01, 0.03, 0.05), reflet=(0.25, 0.42, 0.55))
    return M


def _pied(lot, M, x, y, z_h):
    """Pied télescopique : semelle, vérin à 2 étages, tête."""
    lot.put(M["noir"], G.tour([(0.0, 0.32), (0.05, 0.3), (0.09, 0.2), (0.13, 0.14)], 16, "z", (x, y, 0.0), cap1=True))
    lot.put(M["chrome"], G.tour([(0.1, 0.07), (0.3, 0.07)], 12, "z", (x, y, 0.0)))
    lot.put(M["car2"], G.tour([(0.26, 0.105), (z_h, 0.105)], 14, "z", (x, y, 0.0)))
    lot.put(M["bleu_f"], G.tour([(0.31, 0.11), (0.33, 0.11)], 14, "z", (x, y, 0.0)))


def _robot(lot, M, r):
    """Le robot en cours de montage (la Truelle : torse, dôme, jambes à genou inversé ; torse ouvert, un seul bras posé)."""
    x0, y0 = ROB
    zb = ZD + 0.18
    zh = zb + 0.92          # hanches
    zt = zh + 0.92          # épaules
    for s in (-1, 1):
        hip = (x0 + s * 0.42, y0, zh)
        knee = (x0 + s * 0.62, y0 - 0.34, zh - 0.42)
        ank = (x0 + s * 0.6, y0 + 0.22, zb + 0.16)
        foot = (x0 + s * 0.62, y0 - 0.06, zb + 0.06)
        lot.put(M["noir"], G.sphere(hip, 0.2, 12, 6))
        cuisse = G.sub(knee, hip)
        O.profil(lot, M["uni"], hip, cuisse, [(0.0, 0.11), (0.08, 0.185), (0.3, 0.19), (G.length(cuisse) - 0.05, 0.12), (G.length(cuisse), 0.09)], 14)
        lot.put(M["noir"], G.sphere(knee, 0.12, 10, 5))
        tib = G.sub(ank, knee)
        O.profil(lot, M["car2"], knee, tib, [(0.0, 0.1), (0.1, 0.15), (G.length(tib) - 0.1, 0.1), (G.length(tib), 0.07)], 14)
        lot.put(M["chrome"], G.tube([G.lerp(knee, ank, 0.1), G.add(ank, (0.0, 0.08, 0.14))], 0.026, 6))
        lot.put(M["noir"], G.sphere(ank, 0.09, 10, 5))
        lot.put(M["uni"], G.boite((foot[0], foot[1], foot[2] + 0.03), (0.34, 0.74, 0.14)))
        lot.put(M["noir"], G.boite((foot[0], foot[1] - 0.2, foot[2] + 0.1), (0.24, 0.3, 0.05), 0.0, 0.2))
        lot.put(M["bleu"], G.boite((foot[0] + s * 0.175, foot[1], foot[2] + 0.03), (0.012, 0.42, 0.03)))
    # bassin et colonne
    lot.put(M["noir"], G.boite((x0, y0, zh + 0.02), (0.72, 0.5, 0.26)))
    lot.put(M["acier"], G.tour([(zh + 0.1, 0.17), (zt - 0.25, 0.14)], 14, "z", (x0, y0, 0.0)))
    # torse : coque arrière posée, carène avant retirée (intérieur noir et voyants)
    pr = [(zh + 0.18, 0.46), (zh + 0.45, 0.62), (zt - 0.14, 0.72), (zt + 0.02, 0.64), (zt + 0.1, 0.46)]
    rings = []
    for (z, rr) in pr:
        rings.append([(x0 + rr * math.cos(a), y0 + rr * 0.72 * math.sin(a), z) for a in [-0.45 + (math.pi + 0.9) * i / 26.0 for i in range(27)]])
    lot.put(M["car2"], G.loft(rings, closed=False))
    rin = []
    for (z, rr) in pr:
        rin.append([(x0 + (rr - 0.04) * math.cos(a), y0 + (rr - 0.04) * 0.72 * math.sin(a), z) for a in [-0.45 + (math.pi + 0.9) * i / 26.0 for i in range(27)]])
    lot.put(M["noir"], G.loft(rin, closed=False))
    # cœur : cartes, bobine bleue, nappes
    lot.put(M["noir_p"], G.boite((x0, y0 + 0.02, zt - 0.28), (0.82, 0.4, 0.92)))
    lot.put(M["bleu"], G.tour([(-0.1, 0.17), (0.0, 0.17)], 18, "y", (x0 - 0.04, y0 - 0.18, zt - 0.3), cap0=True, cap1=True))
    lot.put(M["acier"], G.tour([(-0.11, 0.21), (-0.08, 0.24), (-0.01, 0.24), (0.0, 0.2)], 18, "y", (x0 - 0.04, y0 - 0.16, zt - 0.3)))
    for k in range(4):
        lot.put(M["acier"], G.boite((x0 + 0.24, y0 - 0.19, zt - 0.56 + 0.16 * k), (0.2, 0.012, 0.1)))
        lot.put(M["bleu_f"], G.boite((x0 + 0.3, y0 - 0.2, zt - 0.56 + 0.16 * k), (0.04, 0.008, 0.03)))
    for (a, b, c) in (((x0 - 0.36, y0 - 0.18, zt - 0.06), (x0 - 0.48, y0 - 0.32, zt - 0.5), (x0 - 0.3, y0 - 0.18, zh + 0.18)),
                      ((x0 + 0.34, y0 - 0.18, zt - 0.02), (x0 + 0.52, y0 - 0.32, zt - 0.42), (x0 + 0.3, y0 - 0.2, zh + 0.2))):
        O.flexible(lot, M["caout"], [a, b, c], 0.018)
    # plaque de carène encore dans la pince du bras est (voir build), plaque posée à gauche du torse
    pts = []
    for (z, rr) in pr[:4]:
        pts.append([(x0 + rr * math.cos(a), y0 + rr * 0.72 * math.sin(a), z) for a in [-math.pi + 0.0 + 0.8 * i / 8.0 for i in range(9)]])
    lot.put(M["car"], G.loft(pts, closed=False))
    # épaules et bras gauche posé : avant-bras-outil (la truelle)
    for s in (-1, 1):
        lot.put(M["noir"], G.tour([(-0.13, 0.15), (0.13, 0.15)], 14, "x", (x0 + s * 0.8, y0 + 0.02, zt - 0.08), cap0=True, cap1=True))
    sl = (x0 - 0.86, y0 + 0.02, zt - 0.08)
    el = (x0 - 1.1, y0 - 0.14, zt - 0.72)
    wr = (x0 - 0.98, y0 - 0.66, zt - 0.98)
    bd = G.sub(el, sl)
    O.profil(lot, M["uni"], sl, bd, [(0.0, 0.13), (0.1, 0.17), (G.length(bd) - 0.1, 0.13), (G.length(bd), 0.09)], 14)
    lot.put(M["noir"], G.sphere(el, 0.12, 10, 5))
    bd = G.sub(wr, el)
    O.profil(lot, M["car2"], el, bd, [(0.0, 0.1), (0.1, 0.14), (G.length(bd) - 0.05, 0.11), (G.length(bd), 0.05)], 14)
    lot.put(M["orange"], O.pose_plane(G.boite((0, 0, 0), (0.28, 0.46, 0.04)), G.add(wr, (0.0, -0.18, -0.03)), (0.05, 0.4, 0.9)))
    lot.put(M["acier"], G.tube([wr, G.add(wr, (0.0, -0.14, -0.02))], 0.04, 8))
    # tête : le dôme lisse, verre sombre et bandeau bleu
    zd = zt + 0.08
    prof = [(zd, 0.0), (zd + 0.005, 0.34), (zd + 0.05, 0.38)] + [(zd + 0.08 + 0.42 * math.sin(t), 0.4 * math.cos(t)) for t in [math.pi / 2 * i / 10.0 for i in range(11)]]
    prof[-1] = (zd + 0.5, 0.0)
    lot.put(M["blanc"], G.tour(prof, 28, "z", (x0, y0 + 0.02, 0.0)))
    lot.put(M["bleu"], G.tour([(zd + 0.075, 0.405), (zd + 0.1, 0.405)], 28, "z", (x0, y0 + 0.02, 0.0)))
    c = (x0, y0 + 0.02, zd + 0.12)
    rings = [[G.add(c, (0.415 * math.cos(a) * math.cos(t), 0.415 * math.sin(a) * math.cos(t), 0.415 * math.sin(t))) for a in [-math.pi / 2 - 0.75 + 1.5 * i / 12.0 for i in range(13)]]
             for t in [0.18 + 0.42 * j / 4.0 for j in range(5)]]
    lot.put(M["verre"], G.loft(rings, closed=False))
    lot.put(M["acier"], G.tube([(x0 + 0.26, y0 + 0.2, zd + 0.42), (x0 + 0.34, y0 + 0.22, zd + 0.92)], 0.008, 4))
    lot.put(M["rouge"], G.sphere((x0 + 0.34, y0 + 0.22, zd + 0.93), 0.02, 6, 3))
    return zt


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(1010)
    cdx, cdy = CD
    PI = math.pi

    # ---------------------------------------------------------------- plateau levé : pieds, ventre, couronne, sol
    for a in [TAU * (k + 0.5) / 10.0 for k in range(10)]:
        _pied(lot, M, cdx + (RD - 0.24) * math.cos(a), cdy + (RD - 0.24) * math.sin(a), ZD - 0.24)
    lot.put(M["noir"], G.tour([(0.2, 0.0), (0.22, 1.9), (ZD - 0.22, RD - 0.15), (ZD - 0.16, RD - 0.02)], 72, "z", (cdx, cdy, 0.0)))
    lot.put(M["uni"], G.tour([(ZD - 0.26, RD - 0.2), (ZD - 0.2, RD), (ZD - 0.03, RD + 0.03), (ZD - 0.0, RD - 0.04)], 96, "z", (cdx, cdy, 0.0)))
    lot.put(M["bleu"], G.tour([(ZD - 0.14, RD + 0.012), (ZD - 0.1, RD + 0.018)], 96, "z", (cdx, cdy, 0.0)))
    for k in range(32):                                                  # évents noirs de la couronne
        a = TAU * (k + 0.25) / 32.0
        if math.sin(a) > 0.25:
            continue
        lot.put(M["noir"], G.boite((cdx + (RD + 0.02) * math.cos(a), cdy + (RD + 0.02) * math.sin(a), ZD - 0.05), (0.22, 0.03, 0.04), a + PI / 2))
    lot.put(M["sol"], G.tour([(ZD, RD - 0.03), (ZD + 0.005, 0.0)], 96, "z", (cdx, cdy, 0.0)))
    for R in (RD - 0.22, 2.6):                                           # anneaux incrustés
        O.anneau(lot, M["noir"], (cdx, cdy, ZD + 0.004), R, 0.02, 90, 5)
    O.anneau(lot, M["bleu_f"], (cdx, cdy, ZD + 0.008), RD - 0.32, 0.012, 90, 5)
    # plateau tournant
    def rot(p):
        return G.rot_z(p, PSI, (cdx, cdy, 0.0))
    lot.xf = rot
    tx, ty = ROB
    lot.put(M["acier"], G.tour([(ZD, 1.62), (ZD + 0.05, 1.62), (ZD + 0.07, 1.56), (ZD + 0.08, 1.56), (ZD + 0.09, 1.1), (ZD + 0.1, 0.0)], 72, "z", (tx, ty, 0.0)))
    lot.put(M["noir_p"], G.tour([(ZD + 0.075, 1.54), (ZD + 0.1, 1.53), (ZD + 0.14, 1.34), (ZD + 0.14, 0.0)], 72, "z", (tx, ty, 0.0)))
    O.anneau(lot, M["bleu"], (tx, ty, ZD + 0.09), 1.58, 0.018, 90, 5)
    for k in range(24):
        a = TAU * k / 24.0
        lot.put(M["uni"], G.boite((tx + 1.44 * math.cos(a), ty + 1.44 * math.sin(a), ZD + 0.13), (0.15, 0.05, 0.03), a))
    for s in (-1, 1):                                                    # griffes qui tiennent les pieds du robot
        lot.put(M["uni"], G.boite((tx + s * 0.76, ty - 0.08, ZD + 0.17), (0.6, 1.1, 0.07)))
        lot.put(M["orange"], G.boite((tx + s * 1.08, ty - 0.08, ZD + 0.22), (0.05, 0.5, 0.12)))

    # ---------------------------------------------------------------- le dôme ouvert : 4 lunes emboîtées, repliées au nord
    lunes = ((3.42, 0.0, 0.62), (3.28, 0.52, 1.04), (3.14, 0.94, 1.38), (3.0, 1.28, 1.62))
    last = None
    for i, (R, t0, t1) in enumerate(lunes):
        ep = 0.11
        last = O.lune(lot, M["car"] if i % 2 == 0 else M["car2"], M["noir_p"], M["uni"], CH, R, t0, t1, ep, phi=1.36)
        # lèvre lumineuse et nervures méridiennes dans le creux
        def Q(f, t, g, R=R):
            rr = (R + g) * math.cos(f)
            return (CH[0] + (R + g) * math.sin(f), CH[1] + rr * math.cos(t), CH[2] + rr * math.sin(t))
        lot.put(M["bleu"], G.tube([Q(-1.34 + 2.68 * j / 48.0, t1, -ep * 0.5) for j in range(49)], 0.012, 6))
        lot.put(M["noir"], G.tube([Q(-1.34 + 2.68 * j / 48.0, t1 - 0.012, 0.015) for j in range(49)], 0.022, 6))
        for f in [-1.08 + 2.16 * k / 8.0 for k in range(9)]:
            pts = [Q(f, t0 + (t1 - t0) * j / 12.0, -ep - 0.012) for j in range(13)]
            lot.put(M["acier"], G.tube(pts, 0.024, 5))
            if i >= 2 and (k_est_impair(f)):
                lot.put(M["bleu_f"], G.tube([Q(f + 0.02, t0 + (t1 - t0) * j / 8.0, -ep - 0.02) for j in range(9)], 0.012, 5))
        # membrures, charnières de glissière et panneaux noirs sur le dessus
        for f in (-0.72, 0.1, 0.86):
            pts = [Q(f, t0 + (t1 - t0) * j / 12.0, 0.012) for j in range(13)]
            lot.put(M["uni"], G.tube(pts, 0.03, 5))
        for k in range(3):
            f = -1.0 + 0.9 * k + 0.15 * i
            t = t1 - 0.14
            p = Q(f, t, 0.0)
            n = G.sub(Q(f, t, 0.3), p)
            lot.put(M["noir"], O.pose_plane(G.boite((0, 0, 0.012), (0.42, 0.22, 0.02)), p, n))
            for j in range(4):
                lot.put(M["acier"], O.pose_plane(G.boite((-0.15 + 0.1 * j, 0, 0.027), (0.035, 0.18, 0.01)), p, n))
    # menus détails sur la peau du dôme : évents, trappes, poignées, capteurs (casse les aplats)
    rg = G.Rnd(1027)
    mats_g = [M["noir"], M["acier"], M["uni"], M["car2"]]
    for i, (R, t0, t1) in enumerate(lunes):
        def Qg(f, t, g, R=R):
            rr = (R + g) * math.cos(f)
            return (CH[0] + (R + g) * math.sin(f), CH[1] + rr * math.cos(t), CH[2] + rr * math.sin(t))
        for k in range(46):
            f, t = rg.f(-1.2, 1.2), rg.f(max(t0, 0.75), t1 - 0.05)
            p, n = Qg(f, t, 0.0), G.sub(Qg(f, t, 0.3), Qg(f, t, 0.0))
            lot.put(mats_g[k % 4], O.pose_plane(G.boite((0, 0, 0.015), (rg.f(0.07, 0.3), rg.f(0.05, 0.17), rg.f(0.03, 0.07)), rg.f(-0.3, 0.3)), p, n))
        for k in range(6):
            f, t = -1.0 + 0.4 * k + 0.1 * i, t1 - 0.09
            lot.put(M["bleu_f"], O.pose_plane(G.boite((0, 0, 0.02), (0.14, 0.03, 0.02)), Qg(f, t, 0.0), G.sub(Qg(f, t, 0.3), Qg(f, t, 0.0))))
    # écrin : mur courbe noir derrière le robot, baies, écrans, rails de lumière (fond sombre de la bouche du dôme)
    tx_, ty_ = ROB
    Az0, Az1, Rw, Hw = math.radians(16.0), math.radians(164.0), 2.86, 2.3
    wr = [[(tx_ + Rw * math.cos(Az0 + (Az1 - Az0) * j / 40.0), ty_ + Rw * math.sin(Az0 + (Az1 - Az0) * j / 40.0), z) for j in range(41)] for z in (ZD, ZD + Hw)]
    lot.put(M["noir_p"], G.loft(wr, closed=False))
    for k in range(11):
        a = Az0 + (Az1 - Az0) * (k + 0.5) / 11.0
        p = (tx_ + (Rw - 0.02) * math.cos(a), ty_ + (Rw - 0.02) * math.sin(a), ZD + 1.15)
        n = (-math.cos(a), -math.sin(a), 0.0)
        lot.put(M["acier"], O.pose_plane(G.boite((0, 0, 0.012), (0.56, 1.95, 0.025)), p, n))
        lot.put(M["noir"], O.pose_plane(G.boite((0, 0, 0.028), (0.46, 1.8, 0.02)), p, n))
        if k % 2 == 0:
            lot.put(M["ecran"], O.pose_plane(G.boite((0, 0.34, 0.04), (0.38, 0.62, 0.012)), p, n))
        else:
            for j in range(5):
                lot.put(M["uni"] if j % 2 else M["car2"], O.pose_plane(G.boite((0, -0.1 + 0.2 * j, 0.05), (0.38, 0.14, 0.05)), p, n))
        lot.put(M["bleu_f"], O.pose_plane(G.boite((0, -0.72, 0.04), (0.3, 0.03, 0.012)), p, n))
        a2 = Az0 + (Az1 - Az0) * k / 10.0
        lot.put(M["uni"], G.boite((tx_ + (Rw - 0.02) * math.cos(a2), ty_ + (Rw - 0.02) * math.sin(a2), ZD + Hw / 2), (0.1, 0.1, Hw + 0.02), a2))
    # moyeux est et ouest : gros disques, paliers sur le plateau
    for s in (-1, 1):
        hx = s * 3.28
        O.profil(lot, M["uni"], (hx - s * 0.62, CH[1], CH[2]), (s, 0, 0), [(0.0, 1.0), (0.14, 1.05), (0.42, 0.98), (0.62, 0.8), (0.74, 0.5), (0.78, 0.0)], 48)
        O.profil(lot, M["noir"], (hx - s * 0.62, CH[1], CH[2]), (s, 0, 0), [(0.53, 0.92), (0.56, 0.82), (0.58, 0.8)], 48)
        O.profil(lot, M["bleu"], (hx + s * 0.11, CH[1], CH[2]), (s, 0, 0), [(0.0, 0.32), (0.02, 0.3), (0.05, 0.0)], 24)
        for k in range(10):
            a = TAU * k / 10.0
            q = (hx + s * 0.09, CH[1] + 0.62 * math.cos(a), CH[2] + 0.62 * math.sin(a))
            lot.put(M["noir"], G.tour([(-0.02, 0.05), (0.04, 0.05)], 8, "x", q, cap1=True))
    # ---------------------------------------------------------------- 2 grands vérins qui tirent la lune avant
    for (s, f) in ((-1, -0.92), (1, 0.92)):
        Rl = lunes[3][0]
        q = (CH[0] + Rl * math.sin(f), CH[1] + Rl * math.cos(f) * math.cos(1.5), CH[2] + Rl * math.cos(f) * math.sin(1.5))
        pb = (s * 2.9, -0.55, ZD)
        lot.put(M["uni"], G.tour([(ZD, 0.28), (ZD + 0.05, 0.28), (ZD + 0.25, 0.14)], 16, "z", (pb[0], pb[1], 0.0), cap1=True))
        mid = G.lerp(pb, q, 0.54)
        lot.put(M["car2"], G.tube([G.add(pb, (0, 0, 0.14)), mid], 0.11, 14))
        lot.put(M["chrome"], G.tube([mid, q], 0.058, 12))
        for t in (0.16, 0.38):
            p = G.lerp(pb, mid, t)
            lot.put(M["noir"], G.oriente(G.tour([(-0.03, 0.128), (0.03, 0.128)], 14, "z", cap0=True, cap1=True), p, G.sub(q, pb)))
        lot.put(M["noir"], G.oriente(G.tour([(-0.05, 0.135), (0.05, 0.135)], 14, "z", cap0=True, cap1=True), mid, G.sub(q, pb)))
        lot.put(M["uni"], G.sphere(q, 0.13, 12, 6))
        O.flexible(lot, M["caout"], [G.add(pb, (s * 0.1, 0.0, 0.18)), G.add(G.lerp(pb, mid, 0.55), (s * 0.2, 0.0, -0.12)), G.add(mid, (s * 0.14, 0.0, 0.0))], 0.018)

    # ---------------------------------------------------------------- bras de montage et robot
    def echelle(p):
        return rot((ROB[0] + (p[0] - ROB[0]) * K_ROB, ROB[1] + (p[1] - ROB[1]) * K_ROB, ZD + (p[2] - ZD) * K_ROB))
    lot.xf = echelle
    zt = _robot(lot, M, r)
    zt = ZD + (zt - ZD) * K_ROB
    lot.xf = rot
    O.bras(lot, M["blanc"], M["noir"], M["caout"], (-2.42, -1.35, ZD), (-2.42, -1.35, ZD + 0.66), (-2.82, -0.75, ZD + 2.0), (-1.85, -1.25, zt + 0.35),
           (-0.95, -1.1, zt - 0.1), r=0.2, socle=0.36, lum=M["blanc_l"], riv=M["bleu"])
    O.bras(lot, M["blanc"], M["noir"], M["caout"], (2.42, -1.62, ZD), (2.42, -1.62, ZD + 0.66), (2.86, -0.7, ZD + 2.08), (2.15, -1.3, zt + 0.1),
           (1.6, -1.33, zt - 0.28), r=0.2, socle=0.36, lum=None, riv=M["bleu"])
    # le bras est tient une plaque de carène du torse et la présente
    pz = (zt - 1.02, zt - 0.72, zt - 0.42, zt - 0.2)
    pl = []
    for z in pz:
        k = 0.56 + 0.09 * (z - pz[0])
        pl.append([(1.15 + k * math.sin(a), -1.42 - k * 0.62 * math.cos(a), z) for a in [-0.72 + 1.44 * i / 12.0 for i in range(13)]])
    lot.put(M["car"], G.loft(pl, closed=False))
    lot.put(M["bleu"], G.tube([G.add(p, (0.0, -0.006, 0.0)) for p in pl[2]], 0.012, 5))
    lot.put(M["noir"], G.tube([(1.6, -1.33, zt - 0.28), (1.28, -1.74, zt - 0.5)], 0.05, 8))
    O.bras(lot, M["blanc"], M["noir"], M["caout"], (1.05, 1.0, ZD), (1.05, 1.0, ZD + 0.55), (1.5, 0.78, ZD + 1.95), (0.92, 0.08, zt + 0.5),
           (0.42, -0.52, zt + 0.28), r=0.16, socle=0.3, lum=M["blanc_l"], riv=M["bleu"])
    # rail lumineux du plateau et gaines qui montent aux bras
    for (a, b) in (((-2.42, -1.35, ZD + 0.03), (-1.3, -1.5, ZD + 0.1)), ((2.42, -1.62, ZD + 0.03), (1.3, -1.6, ZD + 0.1))):
        O.flexible(lot, M["caout"], [a, G.add(G.lerp(a, b, 0.5), (0, -0.1, 0.03)), b], 0.024)
    # portique de scan : arc fin qui enjambe le plateau tournant
    arc = [(tx + 1.9 * math.cos(t), ty + 0.72, ZD + 0.04 + 3.1 * math.sin(t)) for t in [PI * i / 40.0 for i in range(41)]]
    lot.put(M["noir"], G.tube(arc, 0.038, 8))
    for i in range(3, 39, 4):
        lot.put(M["bleu_f"], G.sphere(G.add(arc[i], (0.0, -0.042, 0.0)), 0.022, 6, 3))

    # ---------------------------------------------------------------- rampe de sortie au sud, entre 2 balises
    lot.xf = None
    rx0, rx1 = -1.42, 0.62
    y0_r, y1_r = cdy - RD + 0.25, -4.92
    q = [(rx0, y0_r, ZD + 0.01), (rx1, y0_r, ZD + 0.01), (rx1, y1_r, 0.02), (rx0, y1_r, 0.02)]
    lot.put(M["rampe"], G.loft([[q[3], q[2]], [q[0], q[1]]], closed=False))
    for k in range(9):                                                   # nervures antidérapantes et rails de sortie
        t = (k + 0.5) / 9.0
        a, b = G.lerp(q[0], q[3], t), G.lerp(q[1], q[2], t)
        lot.put(M["noir"], G.tube([G.add(G.lerp(a, b, 0.14), (0, 0, 0.012)), G.add(G.lerp(a, b, 0.86), (0, 0, 0.012))], 0.018, 5))
    for u0, u1 in ((0.0, 0.11), (0.89, 1.0)):                            # chevrons le long des bords seulement
        a, b, c, d = G.lerp(q[0], q[1], u0), G.lerp(q[0], q[1], u1), G.lerp(q[3], q[2], u1), G.lerp(q[3], q[2], u0)
        lot.put(M["chevron"], G.loft([[G.add(d, (0, 0, 0.012)), G.add(c, (0, 0, 0.012))], [G.add(a, (0, 0, 0.012)), G.add(b, (0, 0, 0.012))]], closed=False))
    lot.put(M["noir"], G.loft([[q[0], q[3]], [(rx0, y0_r, 0.0), (rx0, y1_r, 0.0)]], closed=False))
    lot.put(M["noir"], G.loft([[q[1], q[2]], [(rx1, y0_r, 0.0), (rx1, y1_r, 0.0)]], closed=False))
    for (s, x) in ((-1, rx0), (1, rx1)):                                 # joues carénées et filets bleus
        a, b = (x, y0_r, ZD + 0.01), (x, y1_r, 0.02)
        rg = [[(x + s * 0.0, y0_r, ZD + 0.14), (x + s * 0.22, y0_r, ZD + 0.14), (x + s * 0.26, y0_r, 0.0)],
              [(x + s * 0.0, y1_r - 0.04, 0.08), (x + s * 0.2, y1_r - 0.04, 0.08), (x + s * 0.24, y1_r - 0.04, 0.0)]]
        lot.put(M["joue"], G.loft(rg, closed=False))
    for (s, bx, H) in ((-1, -1.86, 1.0), (1, 1.06, 0.62)):               # balises de porte, inégales
        by = cdy - RD + 0.14
        O.profil(lot, M["uni"], (bx, by, ZD - 0.2), (0, 0, 1), [(0.0, 0.34), (0.2, 0.34), (0.4, 0.22), (1.72 * H, 0.16), (1.72 * H + 0.24, 0.12), (1.72 * H + 0.3, 0.0)], 20)
        lot.put(M["noir"], G.tour([(ZD + 0.44, 0.235), (ZD + 0.62, 0.21)], 20, "z", (bx, by, 0.0)))
        lot.put(M["bleu"], G.tour([(ZD + 0.72, 0.195), (ZD + 0.78, 0.19)], 20, "z", (bx, by, 0.0)))
        lot.put(M["blanc_l"], G.sphere((bx, by, ZD - 0.2 + 1.72 * H + 0.3), 0.05, 8, 4))

    # ---------------------------------------------------------------- cabine de pilotage au sud-ouest : capsule, écrans
    cx, cy, cz = -2.72, -3.72, 0.62
    O.profil(lot, M["blanc"], (cx - 0.85, cy, cz), (1, 0, 0), [(0.0, 0.0), (0.05, 0.22), (0.2, 0.42), (0.42, 0.5), (1.3, 0.5), (1.5, 0.42), (1.66, 0.2), (1.7, 0.0)], 28)
    for x in (cx - 0.35, cx + 0.5):
        lot.put(M["noir"], G.tour([(x - 0.02, 0.505), (x + 0.02, 0.505)], 28, "x", (0.0, cy, cz)))
    for (dx, dy) in ((-0.5, -0.28), (0.5, -0.28), (-0.5, 0.28), (0.5, 0.28)):
        _pied(lot, M, cx + dx, cy + dy, cz - 0.22)
    rg = [[(cx - 0.62 + 1.24 * i / 10.0, cy + 0.51 * math.cos(t), cz + 0.51 * math.sin(t)) for i in range(11)] for t in (-1.0, -0.6, -0.2)]
    rg = [[(cx - 0.62 + 1.24 * i / 10.0, cy - 0.51 * math.cos(t), cz + 0.51 * math.sin(t)) for i in range(11)] for t in (-0.05, 0.28, 0.62)]
    for i in range(3):
        ec = (cx - 0.4 + 0.4 * i, cy - 0.5, cz + 0.17)
        lot.put(M["noir"], O.pose_plane(G.boite((0, 0, 0.0), (0.38, 0.32, 0.02)), ec, (0.0, -0.9, 0.42)))
        lot.put(M["ecran"], O.pose_plane(G.boite((0, 0, 0.012), (0.32, 0.26, 0.012)), ec, (0.0, -0.9, 0.42)))
    lot.put(M["blanc_l"], G.sphere((cx + 0.75, cy - 0.3, cz + 0.42), 0.026, 6, 3))
    O.faisceau(lot, M["caout"], M["noir"], (cx + 0.62, cy + 0.42, cz), (-1.86, cdy - RD + 0.42, ZD - 0.15), 0.3, 3, 0.014, 0.05, r)
    # fouet haut de la cabine
    fq = (cx - 0.25, cy + 0.2, cz + 0.45)
    lot.put(M["noir"], G.tour([(fq[2], 0.08), (fq[2] + 0.18, 0.05)], 10, "z", (fq[0], fq[1], 0.0)))
    lot.put(M["acier"], G.tube([fq, G.add(fq, (0, 0, 2.9))], 0.012, 5))
    for k in range(4):
        lot.put(M["uni"], G.tour([(fq[2] + 0.5 + 0.6 * k, 0.024), (fq[2] + 0.6 + 0.6 * k, 0.024)], 8, "z", (fq[0], fq[1], 0.0)))
    lot.put(M["rouge"], G.sphere(G.add(fq, (0, 0, 2.93)), 0.03, 6, 3))

    # ---------------------------------------------------------------- râtelier de membres au sud-est (les pièces attendent)
    sx, sy = 2.65, -3.72
    lot.put(M["sol"], G.boite((sx, sy, 0.05), (1.45, 1.75, 0.1)))
    for (dx, dy) in ((-0.62, -0.72), (0.62, -0.72), (-0.62, 0.72), (0.62, 0.72)):
        lot.put(M["noir"], G.boite((sx + dx, sy + dy, 1.0), (0.08, 0.08, 1.82)))
    for (dy) in (-0.72, 0.72):
        O.treillis(lot, M["noir"], (sx - 0.66, sy + dy, 1.9), (sx + 0.66, sy + dy, 1.9), l=0.1, h=0.16, n=6, rc=0.012, rd=0.006)
    O.treillis(lot, M["noir"], (sx - 0.62, sy - 0.72, 1.9), (sx - 0.62, sy + 0.72, 1.9), l=0.1, h=0.16, n=6, rc=0.012, rd=0.006)
    O.treillis(lot, M["noir"], (sx + 0.62, sy - 0.72, 1.9), (sx + 0.62, sy + 0.72, 1.9), l=0.1, h=0.16, n=6, rc=0.012, rd=0.006)
    lot.put(M["acier"], G.boite((sx, sy - 0.28, 1.92), (1.3, 0.05, 0.05)))
    lot.put(M["bleu"], G.boite((sx, sy - 0.77, 1.9), (1.2, 0.012, 0.03)))
    for k, x in enumerate((sx - 0.36, sx + 0.02, sx + 0.38)):            # 3 jambes pendues par la hanche
        y = sy - 0.28
        lot.put(M["acier"], G.tube([(x, y, 1.9), (x, y, 1.62)], 0.018, 5))
        lot.put(M["noir"], G.sphere((x, y, 1.58), 0.12, 10, 5))
        O.profil(lot, M["uni"], (x, y, 1.56), (0.0, -0.1, -1.0), [(0.0, 0.08), (0.08, 0.14), (0.42, 0.11), (0.6, 0.07)], 12)
        q0 = (x, y - 0.06, 0.96)
        lot.put(M["noir"], G.sphere(q0, 0.075, 8, 4))
        O.profil(lot, M["car2"], q0, (0.0, 0.1, -1.0), [(0.0, 0.06), (0.1, 0.1), (0.5, 0.07), (0.6, 0.04)], 12)
        lot.put(M["uni"], G.boite((x, y - 0.04, 0.33), (0.16, 0.34, 0.08)))
    for (x, y, sz, m) in ((sx - 0.4, sy + 0.4, 0.42, "noir_p"), (sx + 0.15, sy + 0.42, 0.34, "car2"), (sx + 0.4, sy + 0.25, 0.26, "uni")):
        lot.put(M[m], G.boite((x, y, 0.1 + sz / 2), (sz, sz * 0.9, sz)))
        lot.put(M["bleu_f"], G.boite((x, y - sz * 0.46, 0.1 + sz * 0.7), (sz * 0.5, 0.01, 0.022)))
    lot.put(M["blanc"], G.sphere((sx + 0.32, sy + 0.5, 0.38), 0.26, 16, 8))     # un dôme de tête en attente, sur une caisse

    # ---------------------------------------------------------------- nord : radôme, parabole, échangeurs, antennes
    rx_, ry_ = 2.62, 3.62
    for a in (0.6, 2.7, 4.8):
        lot.put(M["uni"], G.tube([(rx_ + 0.5 * math.cos(a), ry_ + 0.5 * math.sin(a), 0.0), (rx_, ry_, 1.3)], 0.05, 8))
    lot.put(M["blanc"], G.sphere((rx_, ry_, 1.9), 0.82, 28, 14))
    lot.put(M["noir"], G.tour([(1.32, 0.42), (1.37, 0.44)], 20, "z", (rx_, ry_, 0.0)))
    for t in (-0.3, 0.3, 0.75):                                          # joints du radôme
        O.anneau(lot, M["acier"], (rx_, ry_, 1.9 + 0.825 * math.sin(t)), 0.825 * math.cos(t), 0.006, 40, 4)
    lot.put(M["bleu"], G.sphere((rx_ + 0.2, ry_ - 0.25, 2.71), 0.022, 6, 3))
    px, py = -2.74, 3.38
    lot.put(M["uni"], G.tour([(0.0, 0.26), (0.08, 0.2), (1.5, 0.08), (1.6, 0.1)], 14, "z", (px, py, 0.0)))
    dn = G.norm((-0.62, -0.4, 0.68))
    dc = G.add((px, py, 1.72), G.mul(dn, 0.1))
    prof = [(0.34 * (i / 12.0) ** 2, 0.9 * i / 12.0) for i in range(13)]
    lot.put(M["blanc"], G.oriente(G.tour(prof, 36, "z"), dc, dn))
    lot.put(M["noir"], G.oriente(G.tour([(p[0] - 0.012, p[1]) for p in prof], 36, "z"), dc, dn))
    tip = G.add(dc, G.mul(dn, 0.8))
    for a in (0.0, TAU / 3, 2 * TAU / 3):
        e = G.oriente(([(0.74 * math.cos(a), 0.74 * math.sin(a), 0.24)], [], []), dc, dn)[0][0]
        lot.put(M["acier"], G.tube([e, tip], 0.012, 5))
    lot.put(M["noir"], G.sphere(tip, 0.06, 8, 4))
    # bancs d'ailettes sur les flancs est et ouest du plateau
    for (s, a) in ((-1, 3.42), (1, -0.28)):
        ax, ay = cdx + (RD + 0.12) * math.cos(a), cdy + (RD + 0.12) * math.sin(a)
        if s < 0:
            ay = -1.15
            ax = -3.3
        else:
            ay = -1.2
            ax = 3.3
        for k in range(7):
            lot.put(M["noir"] if k % 2 else M["uni"], G.boite((ax, ay + 0.1 * k - 0.3, 0.44), (0.28, 0.04, 0.6)))
        lot.put(M["uni"], G.boite((ax, ay, 0.76), (0.32, 0.76, 0.05)))
    # petite parabole et mâts sur les moyeux
    for (s, h) in ((-1, 1.25), (1, 0.82)):
        p = (s * 3.25, CH[1] + 0.2, CH[2] + 0.98)
        lot.put(M["acier"], G.tube([p, G.add(p, (0, 0, h))], 0.016, 6))
        lot.put(M["uni"], G.tour([(p[2], 0.05), (p[2] + 0.12, 0.03)], 8, "z", (p[0], p[1], 0.0)))
        lot.put(M["rouge"] if s < 0 else M["bleu"], G.sphere(G.add(p, (0, 0, h + 0.02)), 0.024, 6, 3))
    # marquage et cônes au pied de la rampe
    for (x, y) in ((-1.8, -4.75), (0.98, -4.75)):
        lot.put(M["orange"], G.tour([(0.0, 0.08), (0.03, 0.08), (0.24, 0.02)], 10, "z", (x, y, 0.0), cap1=True))
    # menus détails : trappes, caissons, chariots et câbles sur le plateau, dans le repère du dôme
    lot.xf = rot
    rm = G.Rnd(1044)
    mats_m = [M["noir"], M["acier"], M["uni"], M["car2"], M["noir_p"]]
    for k in range(120):
        a, d = rm.f(0.0, TAU), rm.f(1.75, 3.0)
        p = (cdx + d * math.cos(a), cdy + d * math.sin(a))
        if -1.0 < p[0] < 1.0 and p[1] < -1.4:
            continue
        lot.put(mats_m[k % 5], G.boite((p[0], p[1], ZD + 0.02), (rm.f(0.07, 0.28), rm.f(0.06, 0.22), rm.f(0.02, 0.12)), rm.f(0.0, 3.0)))
    for k in range(12):                                                  # dalles de service à filet noir
        a = TAU * (k + 0.3) / 12.0
        lot.put(M["noir"], G.boite((cdx + 2.95 * math.cos(a), cdy + 2.95 * math.sin(a), ZD + 0.006), (0.46, 0.03, 0.01), a))
    lot.xf = None
    for (x, y) in ((cx - 0.62, cy - 0.4), (cx + 0.62, cy - 0.4)):         # cabine : marchepieds, conduits, évents
        lot.put(M["noir"], G.boite((x, y, 0.13), (0.3, 0.12, 0.03)))
    for x in (cx - 0.2, cx + 0.2):
        lot.put(M["noir"], O.pose_plane(G.boite((0, 0, 0.012), (0.28, 0.16, 0.03)), (x, cy - 0.12, cz + 0.49), (0.0, -0.25, 1.0)))
    lot.put(M["acier"], G.tube([(cx - 0.8, cy + 0.2, cz + 0.28), (cx + 0.85, cy + 0.2, cz + 0.28)], 0.02, 6))
    return {"robot": ROB}


def k_est_impair(f):
    return int(round((f + 1.08) / 0.27)) % 2 == 1
