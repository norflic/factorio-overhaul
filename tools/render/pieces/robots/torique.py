"""TORIQUE (robot 10, âge 13 Fusion, expérimental d'assaut, géant). Idée : une planète à anneau qui marche : grande sphère de confinement en céramique blanche, tore de plasma magenta tout autour, sans le toucher (bobines segmentées
de cuivre, cœur clair et bord sombre : pas un néon plat), 6 injecteurs, sur 6 longues pattes de céramique. Bible : céramique #D9D6CF, cuivre #B0703A, plasma #FF4FD8, cœur #FF9A3A, luminance 92."""
import math

import formes as F
import gamme as Ga
import geo as G
import marionette as Mr

CAP = math.radians(-125.0)
Z_H, Z_S = 4.7, 6.75       # anneau des hanches, centre de la sphère
R_S, R_T = 2.15, 3.35      # rayon de la sphère, grand rayon du tore
R_H, R_P = 2.1, 5.9
L1, L2 = 2.7, 6.4
PAS, BETA, LEVE = 2.3, 0.62, 1.1
IMAGES = 0
HAUTEUR_JEU = round(Z_H * Mr.PROJ, 3)
PART_JEU = (L1 + L2) / 2.0
NB = 6
TABLE = Ga.table_cercle(NB, R_H, R_P, Z_H, a0=math.pi / 6.0, genou=1.2)


def jambes_jeu():
    return Ga.jambes_jeu((30.0, 90.0, 150.0, -30.0, -90.0, -150.0), R_H, R_P)


def matieres(S):
    import mat as MT
    Ga.patine(ta=0.09, ra=0.18, ec=0.15, nu_k=1.2, ec_col=(0.06, 0.05, 0.04), sans=("cerami",))
    cr = (0.05, 0.04, 0.03)
    sf = F.surf
    M = {}
    M["cerami"] = sf("rb13_cerami", (0.66, 0.64, 0.58), rough=0.26, met=0.0, tole=(0.9, 0.55), joint=0.55, joint_l=0.006, var=0.05, coulures=0.35, rouille=(0.2, 0.15, 0.1), usure=0.3, nu=(0.82, 0.8, 0.76), crasse=0.75, crasse_col=cr, relief=0.45, graine=1301)
    M["cerami2"] = sf("rb13_cerami2", (0.74, 0.72, 0.66), rough=0.24, met=0.0, coulures=0.3, rouille=(0.22, 0.17, 0.12), usure=0.3, nu=(0.86, 0.84, 0.8), crasse=0.7, crasse_col=cr, graine=1302)
    M["cuivre"] = sf("rb13_cuivre", (0.56, 0.24, 0.08), rough=0.34, met=0.55, coulures=0.4, rouille=(0.06, 0.16, 0.11), usure=0.55, nu=(0.86, 0.56, 0.3), crasse=0.7, crasse_col=(0.015, 0.01, 0.006), graine=1303)
    M["caout"] = sf("rb13_caout", (0.025, 0.022, 0.024), rough=0.6, met=0.0, usure=0.2, crasse=0.4, graine=1306)
    M["sombre"] = sf("rb13_sombre", (0.03, 0.028, 0.03), rough=0.5, met=0.4, usure=0.4, nu=(0.28, 0.26, 0.26), crasse=0.6, crasse_col=(0.004, 0.004, 0.004), graine=1304)
    M["peint"] = sf("rb13_peint", (0.6, 0.58, 0.54), rough=0.34, met=0.15, usure=0.4, nu=(0.82, 0.8, 0.76), crasse=0.5, crasse_col=cr, graine=1305)
    M["peint"]["fo_teinte"] = 1
    M["plasma"] = S.mat_emissive("rb13_plasma", (1.0, 0.09, 0.68), strength=1.5, base=(0.12, 0.01, 0.08), main_scale=0.6, crust=(9.0, 0.45, 4.0))
    M["coeur"] = MT.lumiere(S, "rb13_coeur", (1.0, 0.33, 0.07), 1.6, main=0.55)
    M["lum"] = MT.lumiere(S, "rb13_lum", (1.0, 0.25, 0.7), 1.0, main=0.5)
    return M


def squelette_torse(cap):
    sq = Mr.Squelette()
    sq.os("racine", None, Mr.rz(cap))
    sq.os("corps", "racine")
    return sq


def squelette(phase, cap=CAP, pas=PAS):
    sq = squelette_torse(cap)
    _a, m = Ga.corps_marche(phase, 0.0, bob=0.08, tangage=0.0, roulis=0.012)
    Ga.pattes(sq, m, phase, pas, BETA, LEVE, L1, L2, TABLE, pied_z=0.0, incl=0.3)
    return sq


def modele_piece(lot, M, partie):
    if partie == "haut":
        lot.put(M["cerami"], F.poutre([(0.0, 0.46, 0.52), (0.5, 0.42, 0.42), (L1 - 0.3, 0.26, 0.26), (L1, 0.28, 0.28)], 0.42))
        for x, k in ((0.3, 0.38), (L1 * 0.48, 0.3), (L1 - 0.3, 0.2)):
            lot.put(M["cuivre"], F.bague((x, 0.0, 0.0), k * 0.5, k, 0.1, "x", 12, 0.02))
            lot.put(M["sombre"], F.bague((x + 0.08, 0.0, 0.0), k * 0.4, k * 0.86, 0.05, "x", 12))
        for s in (1.0, -1.0):
            lot.put(M["sombre"], F.poutre([(0.3, 0.05, 0.04), (L1 - 0.3, 0.04, 0.03)]), (lambda v, s=s: (v[0], v[1] + s * 0.14, v[2] + 0.17 - 0.07 * v[0] / L1)))
    elif partie == "bas":
        lot.put(M["cerami2"], F.poutre([(0.0, 0.34, 0.34), (L2 * 0.4, 0.24, 0.26), (L2 - 0.7, 0.13, 0.15), (L2 - 0.1, 0.1, 0.1)], 0.42))
        for t, k in ((0.1, 0.28), (0.3, 0.24), (0.52, 0.2), (0.76, 0.15), (0.92, 0.14)):
            x = L2 * t
            n_b = 2 if t in (0.3, 0.52) else 1
            for j in range(n_b):
                lot.put(M["cuivre"], F.bague((x + 0.18 * j, 0.0, 0.0), k * 0.5, k, 0.08, "x", 12, 0.016))
        for s in (1.0, -1.0):
            lot.put(M["lum"], F.pose(F.disque((L2 * 0.3, 0.0, 0.0), 0.016, L2 * 0.32, "x", 5), (0.3, s * 0.125, 0.0), (1.0, 0.0, 0.0)))
    else:
        lot.put(M["cerami2"], G.sphere((0.0, 0.0, 0.0), 0.48, 18, 9))
        lot.put(M["cuivre"], F.bague((0.0, 0.0, 0.0), 0.44, 0.56, 0.12, "z", 24, 0.02))
        lot.put(M["sombre"], F.disque((0.0, 0.0, 0.5), 0.08, 0.14, "z", 10))
        lot.put(M["plasma"], F.tore((0.0, 0.0, 0.0), 0.56, 0.03, "z", 28, 5))
        lot.put(M["cuivre"], F.fleche(0.1, 0.9, 6), (lambda v: (v[0], v[1], v[2] + 0.5)))


def modele(lots, M, r, torse=False):
    c = lots("corps")
    # anneau des hanches, bas sous la sphère : céramique et 6 logements
    c.put(M["cerami"], G.tour([(Z_H - 0.4, 1.2), (Z_H - 0.4, 2.1), (Z_H - 0.15, 2.4), (Z_H + 0.25, 2.4), (Z_H + 0.42, 2.1), (Z_H + 0.42, 1.4)], 12, "z", a0=0.26, a1=0.26 + G.TAU))
    c.put(M["cuivre"], F.bague((0.0, 0.0, Z_H + 0.26), 2.2, 2.44, 0.07, "z", 12, 0.012, a0=0.26, a1=0.26 + G.TAU))
    c.put(M["sombre"], F.bague((0.0, 0.0, Z_H - 0.24), 2.18, 2.44, 0.05, "z", 12, 0.01, a0=0.26, a1=0.26 + G.TAU))
    for k in range(NB):
        a = math.pi / 6.0 + G.TAU * k / NB
        ca, sa = math.cos(a), math.sin(a)
        c.put(M["sombre"], F.pose(G.tour([(-0.4, 0.0), (-0.4, 0.42), (0.16, 0.46), (0.3, 0.36), (0.36, 0.0)], 10, "x"), (R_H * ca, R_H * sa, Z_H), (ca, sa, 0.0)))
    # socle : du bas de la sphère à l'anneau, 3 étages
    c.put(M["cuivre"], G.tour([(Z_H - 0.1, 1.2), (Z_H + 0.5, 1.3), (Z_H + 0.74, 1.0)], 18, "z"))
    c.put(M["cerami2"], F.bague((0.0, 0.0, Z_H + 0.5), 1.1, 1.42, 0.14, "z", 18, 0.02))
    # la sphère de confinement, méridiens de cuivre, panneaux, hublots
    c.put(M["cerami"], G.sphere((0.0, 0.0, Z_S), R_S, 40, 22))
    for k in range(6):
        a = G.TAU * k / 6 + 0.26
        pts = [(R_S * 1.006 * math.cos(p_) * math.cos(a), R_S * 1.006 * math.cos(p_) * math.sin(a), Z_S + R_S * 1.006 * math.sin(p_)) for p_ in [(-0.9 + 2.28 * i / 16.0) for i in range(17)]]
        c.put(M["cuivre"], G.tube(pts, 0.04, 6))
    for p_ in (-0.15, 0.52):
        rr_ = R_S * math.cos(p_)
        c.put(M["sombre"] if p_ < 0 else M["peint"], F.bague((0.0, 0.0, Z_S + R_S * math.sin(p_)), rr_ - 0.04, rr_ + 0.03, 0.09, "z", 40, 0.012))
    for k in range(12):
        a = G.TAU * (k + 0.5) / 12 + 0.26
        p_ = 0.2
        n = (math.cos(p_) * math.cos(a), math.cos(p_) * math.sin(a), math.sin(p_))
        p = (R_S * n[0], R_S * n[1], Z_S + R_S * n[2])
        c.put(M["sombre"], F.sur_face(F.plaque([(-0.16, -0.12), (0.16, -0.12), (0.12, 0.12), (-0.12, 0.12)], 0.02), p, n))
        c.put(M["coeur"], F.sur_face(F.plaque([(-0.08, -0.06), (0.08, -0.06), (0.06, 0.06), (-0.06, 0.06)], 0.03), p, n))
    # calotte : injecteur du sommet
    c.put(M["cuivre"], G.tour([(Z_S + R_S - 0.05, 0.6), (Z_S + R_S + 0.12, 0.42), (Z_S + R_S + 0.36, 0.28), (Z_S + R_S + 0.8, 0.14), (Z_S + R_S + 1.0, 0.0)], 12, "z"))
    c.put(M["sombre"], F.bague((0.0, 0.0, Z_S + R_S + 0.2), 0.26, 0.48, 0.1, "z", 12, 0.02))
    # le tore : 18 bobines de cuivre segmentées sur un boudin de plasma ; il ne touche pas la sphère (6 injecteurs le visent)
    c.put(M["plasma"], F.tore((0.0, 0.0, Z_S), R_T, 0.34, "z", 72, 12))
    c.put(M["coeur"], F.bague((0.0, 0.0, Z_S), R_T - 0.42, R_T - 0.3, 0.05, "z", 72))
    for k in range(28):    # bobines : il ne reste que des fentes de plasma (règle de la critique : aucun néon en aplat)
        a = G.TAU * k / 28
        c.put(M["sombre"] if k % 4 == 0 else M["cuivre"], F.pose(F.bague((0.0, 0.0, 0.0), 0.33, 0.47 if k % 2 else 0.42, 0.56, "x", 14, 0.03), (R_T * math.cos(a), R_T * math.sin(a), Z_S), (-math.sin(a), math.cos(a), 0.0)))
        if k % 4 == 0:      # étrier et câble vers la sphère
            c.put(M["sombre"], G.boite(((R_T + 0.5) * math.cos(a), (R_T + 0.5) * math.sin(a), Z_S), (0.22, 0.2, 0.3), a))
        if k % 4 == 2:
            q = ((R_T - 0.42) * math.cos(a), (R_T - 0.42) * math.sin(a), Z_S + 0.2)
            q2 = (R_S * 0.92 * math.cos(a), R_S * 0.92 * math.sin(a), Z_S + 0.65)
            c.put(M["caout"], G.tube(G.chainette(q, q2, 0.12, 8), 0.028, 5))
    # blindage : 3 ceintures de plaques épaisses sur la sphère, greebles, mitrailleuses de bord
    def surf_s(rr):
        a, p_ = rr.f(0.0, G.TAU), rr.f(-0.65, 1.15)
        n = (math.cos(p_) * math.cos(a), math.cos(p_) * math.sin(a), math.sin(p_))
        return (R_S * n[0], R_S * n[1], Z_S + R_S * n[2]), n
    Ga.plaques(c, [M["sombre"], M["cerami2"], M["cuivre"], M["cerami"]], r, 190, surf_s, (0.08, 0.36), 0.025)
    for p_, nb, hb in ((0.95, 10, 0.3), (0.32, 14, 0.2), (-0.42, 14, 0.2)):
        for k in range(nb):
            a = G.TAU * k / nb + 0.1
            n = (math.cos(p_) * math.cos(a), math.cos(p_) * math.sin(a), math.sin(p_))
            c.put(M["cerami2"], F.sur_face(G.prisme([(-0.26, -hb), (0.26, -hb), (0.2, hb), (-0.2, hb)], 0.0, 0.07, 0.86), (R_S * n[0], R_S * n[1], Z_S + R_S * n[2]), n))
    for k in range(6):
        a = G.TAU * (k + 0.5) / 6
        n = (math.cos(0.1) * math.cos(a), math.cos(0.1) * math.sin(a), math.sin(0.1))
        b0 = (R_S * n[0], R_S * n[1], Z_S - 0.75 + R_S * 0.1)
        c.put(M["sombre"], G.sphere(G.add(b0, (0.0, 0.0, 0.0)), 0.26, 10, 5))
        for dz in (-0.07, 0.07):
            c.put(M["cuivre"], F.pose(F.disque((0.36, 0.0, 0.0), 0.035, 0.7, "x", 8), G.add(b0, (0.0, 0.0, dz)), (math.cos(a), math.sin(a), 0.15)))
    for k in range(NB):
        a = G.TAU * k / NB
        ca, sa = math.cos(a), math.sin(a)
        b0 = (R_S * 0.96 * ca, R_S * 0.96 * sa, Z_S)
        c.put(M["sombre"], F.pose(G.tour([(0.0, 0.26), (0.18, 0.24), (0.34, 0.15), (0.52, 0.11)], 8, "x"), b0, (ca, sa, 0.0)))
        c.put(M["coeur"], F.pose(F.disque((0.55, 0.0, 0.0), 0.08, 0.03, "x", 8), b0, (ca, sa, 0.0)))
    # pattes
    for k in range(0 if torse else NB):
        nom = str(k)
        modele_piece(lots("cuisse_" + nom), M, "haut")
        modele_piece(lots("tibia_" + nom), M, "bas")
        lots("cuisse_" + nom).put(M["cerami2"], F.disque((0.0, 0.0, 0.0), 0.3, 0.4, "y", 12))
        pi = lots("pied_" + nom)
        pi.put(M["cerami"], G.tour([(0.0, 0.4), (0.04, 0.46), (0.16, 0.34), (0.42, 0.14), (0.6, 0.1)], 12, "z", cap1=True))
        pi.put(M["cuivre"], F.bague((0.0, 0.0, 0.14), 0.26, 0.4, 0.03, "z", 12, 0.008))
