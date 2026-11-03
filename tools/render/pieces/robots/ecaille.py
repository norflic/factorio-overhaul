"""ÉCAILLE (robot 2, âge 5 Volcan, assaut lourd, classe M). Idée : un pangolin de tungstène, bas et large, couvert de rangées d'écailles inclinées qui se chevauchent ;
entre les rangées, des fentes de braise ; le long de l'échine, des pointes de basalte. Devant, une gueule en tronc de pyramide où couve un obusier court. 4 pattes courtes
en piliers, pieds en dalle. Bible : tungstène #3E3D42, rouille brûlée #5A3A2A, braise #FF4A10, luminance 42 (la plus sombre)."""
import math

import formes as F
import gamme as Ga
import geo as G
import marionette as Mr

CAP = math.radians(-146.0)
Z0 = 0.95
PAS, BETA, LEVE = 0.9, 0.66, 0.14
L1, L2 = 0.52, 0.52
HX, HY, HZ = 0.72, 0.58, -0.2
TABLE = Ga.table_quatre(HX, HY, HZ, HX + 0.04, HY + 0.1, decs=(0.0, 0.5, 0.75, 0.25), genou=0.3)


def matieres(S):
    import mat as MT
    Ga.patine(ta=0.14, ra=0.2, ec=0.35, nu_k=1.5, ec_col=(0.045, 0.02, 0.01))
    cr = (0.006, 0.005, 0.005)
    sf = F.surf
    M = {}
    M["tung"] = sf("rb5_tung", (0.07, 0.068, 0.078), rough=0.5, met=0.55, usure=0.8, nu=(0.32, 0.31, 0.33), crasse=0.8, crasse_col=cr, coulures=0.5, rouille=(0.13, 0.055, 0.025), graine=501)
    M["tung2"] = sf("rb5_tung2", (0.11, 0.105, 0.11), rough=0.45, met=0.55, usure=0.8, nu=(0.42, 0.4, 0.4), crasse=0.75, crasse_col=cr, coulures=0.4, rouille=(0.14, 0.06, 0.028), graine=502)
    M["rouille"] = sf("rb5_rouille", (0.13, 0.055, 0.03), rough=0.75, met=0.2, usure=0.6, nu=(0.3, 0.17, 0.1), crasse=0.8, crasse_col=cr, graine=503)
    M["basalte"] = sf("rb5_basalte", (0.03, 0.028, 0.03), rough=0.85, met=0.0, usure=0.5, nu=(0.15, 0.14, 0.14), crasse=0.7, crasse_col=cr, grain=0.2, graine=504)
    M["riv"] = sf("rb5_riv", (0.2, 0.19, 0.19), rough=0.45, met=0.7, usure=0.3, crasse=0.4, graine=505)
    M["peint"] = sf("rb5_peint", (0.42, 0.36, 0.3), rough=0.5, met=0.25, usure=0.75, nu=(0.55, 0.5, 0.44), crasse=0.6, crasse_col=cr, graine=506)
    M["peint"]["fo_teinte"] = 1
    M["braise"] = MT.lumiere(S, "rb5_braise", (1.0, 0.1, 0.012), 2.2, main=0.55)
    M["suie"] = sf("rb5_suie", (0.008, 0.007, 0.007), rough=0.85, met=0.1, usure=0.0, crasse=0.5, crasse_col=(0.002, 0.002, 0.002), graine=507)
    return M


def squelette(phase, cap=CAP, pas=PAS):
    sq = Mr.Squelette()
    sq.os("racine", None, Mr.rz(cap))
    a, m = Ga.corps_marche(phase, Z0, bob=0.02, tangage=0.02, roulis=0.04)
    sq.os("corps", "racine", m)
    Ga.pattes(sq, m, phase, pas, BETA, LEVE, L1, L2, TABLE, incl=0.4)
    return sq


def _ecaille(lot, M, p, n, axe, w, l, mat, relief=0.05):
    """Une écaille : trapèze biseauté posé en p, normale n, sa pointe vers `axe` (l'écaille du dessus recouvre celle du dessous)."""
    poly = [(-w / 2, -l / 2), (w / 2, -l / 2), (w * 0.33, l / 2), (-w * 0.33, l / 2)]
    lot.put(mat, F.sur_face(G.prisme(poly, 0.0, relief, 0.82), p, n, axe))


def modele(lots, M, r, torse=False):
    c = lots("corps")
    # coque : voûte de tronc de pyramide (section à 10 pans), rangées d'écailles
    sections = [(-1.05, 0.38, 0.28), (-0.72, 0.68, 0.46), (-0.2, 0.84, 0.62), (0.3, 0.84, 0.58), (0.74, 0.66, 0.42), (1.02, 0.42, 0.24)]
    rings = []
    for x, a, b in sections:
        rings.append([(x, a * math.cos(G.TAU * j / 10 + 0.31), b * math.sin(G.TAU * j / 10 + 0.31) + 0.02) for j in range(10)])
    c.put(M["tung"], G.loft(rings, True, True))
    # le plat du ventre, contreforts
    c.put(M["rouille"], G.boite((0.0, 0.0, -0.46), (1.5, 1.0, 0.16)))
    for s in (1.0, -1.0):
        c.put(M["tung"], F.pose(F.poutre([(0.0, 0.2, 0.34), (1.3, 0.14, 0.2)], 0.3), (-0.65, s * 0.62, -0.28), (1.0, 0.0, 0.0)))
    # écailles : 7 rangées d'arrière en avant, se chevauchent, fente de braise sous la lèvre de chaque 2e rangée
    xs = (-0.86, -0.56, -0.26, 0.04, 0.34, 0.62, 0.86)
    for ir, x in enumerate(xs):
        a_ = 0.84 - 0.42 * (abs(x + 0.05) / 0.95) ** 2
        b_ = 0.6 - 0.32 * (abs(x + 0.05) / 0.95) ** 2
        nb = 7 + (ir % 2)
        for j in range(nb):
            t = math.pi * (j + 0.5 + 0.5 * (ir % 2)) / nb
            cy, sz = math.cos(t), math.sin(t)
            p = (x, a_ * cy * 1.01, b_ * sz * 1.01 + 0.02)
            n = (0.1, cy, sz + 0.25)
            mat = M["tung2"] if (j + ir) % 3 else (M["peint"] if j in (3, 4) and ir % 2 == 0 else M["rouille"])
            _ecaille(c, M, p, n, (-1.0, 0.0, 0.0), 0.36 - 0.02 * abs(j - nb / 2.0), 0.4, mat)
            if (j + ir) % 4 == 0:
                c.put(M["riv"], G.rivets_le_long([(G.add(p, (-0.13, 0.0, 0.05)), n)], 0.024, 0.016))
            if ir % 2 == 1 and j in (1, 2, nb - 2, nb - 3):
                c.put(M["braise"], F.sur_face(F.plaque([(-0.11, -0.012), (0.11, -0.012), (0.11, 0.012), (-0.11, 0.012)], 0.012), G.add(p, (0.22, 0.0, -0.01)), n, (-1.0, 0.0, 0.0)))
    # échine : pointes de basalte, plus hautes au garrot
    for i in range(9):
        x = -0.9 + 0.22 * i
        h = 0.2 + 0.32 * math.sin(math.pi * (i + 0.5) / 9.0)
        z = 0.6 - 0.32 * ((x + 0.05) / 0.95) ** 2
        c.put(M["basalte"], F.incline(G.tour([(0.0, 0.09), (0.05, 0.08), (h, 0.0)], 5, "z", cap0=True), (x, 0.03 * ((-1) ** i), z), (-0.18, 0.0, 1.0)))
    # gueule : tronc de pyramide vers l'avant, foyer de braise, obusier court
    x0 = 1.0
    gueule = [[(x0 + 0.0, -0.36, -0.28), (x0 + 0.0, 0.36, -0.28), (x0 + 0.0, 0.3, 0.2), (x0 + 0.0, -0.3, 0.2)],
              [(x0 + 0.3, -0.28, -0.22), (x0 + 0.3, 0.28, -0.22), (x0 + 0.3, 0.22, 0.12), (x0 + 0.3, -0.22, 0.12)]]
    c.put(M["tung2"], G.loft(gueule, False, False))
    c.put(M["suie"], G.boite((x0 + 0.29, 0.0, -0.05), (0.03, 0.4, 0.26)))
    c.put(M["braise"], G.boite((x0 + 0.305, 0.0, -0.05), (0.012, 0.26, 0.04)))
    c.put(M["tung"], F.disque((x0 + 0.42, 0.0, -0.06), 0.1, 0.36, "x", 10))
    c.put(M["suie"], F.disque((x0 + 0.605, 0.0, -0.06), 0.07, 0.02, "x", 10))
    for x in (x0 + 0.34, x0 + 0.55):
        c.put(M["peint"], F.bague((x, 0.0, -0.06), 0.09, 0.125, 0.05, "x", 10, 0.01))
    for s in (1.0, -1.0):
        c.put(M["basalte"], F.incline(G.tour([(0.0, 0.07), (0.28, 0.0)], 5, "z", cap0=True), (x0 + 0.28, s * 0.24, 0.1), (0.5, s * 0.3, 0.6)))
    # pattes : piliers à plaques, pieds en dalle
    for nom, _h, _p, _d, _po in TABLE:
        cu = lots("cuisse_" + nom)
        cu.put(M["tung"], F.poutre([(-0.1, 0.22, 0.3), (0.0, 0.25, 0.32), (L1 - 0.04, 0.2, 0.22), (L1 + 0.06, 0.19, 0.2)], 0.3))
        cu.put(M["tung2"], F.disque((0.0, 0.0, 0.0), 0.15, 0.3, "y", 10))
        cu.put(M["riv"], F.rivets_ligne((0.08, 0.13, 0.0), (L1 - 0.08, 0.1, 0.0), 3, (0, 1, 0), 0.022))
        cu.put(M["riv"], F.rivets_ligne((0.08, -0.13, 0.0), (L1 - 0.08, -0.1, 0.0), 3, (0, -1, 0), 0.022))
        ti = lots("tibia_" + nom)
        ti.put(M["tung2"], F.disque((0.0, 0.0, 0.0), 0.12, 0.27, "y", 10))
        ti.put(M["tung"], F.poutre([(0.0, 0.2, 0.2), (L2 - 0.12, 0.16, 0.15), (L2, 0.18, 0.16)], 0.3))
        ti.put(M["braise"], G.boite((L2 * 0.5, 0.0, 0.098), (0.22, 0.02, 0.012)))
        pi = lots("pied_" + nom)
        pi.put(M["tung"], G.prisme([(0.2, -0.13), (0.2, 0.13), (0.06, 0.2), (-0.18, 0.18), (-0.2, -0.18), (0.06, -0.2)], 0.0, 0.1, 0.72))
        pi.put(M["rouille"], G.boite((0.0, 0.0, 0.115), (0.2, 0.2, 0.05)))
        for s in (-1.0, 0.0, 1.0):
            pi.put(M["basalte"], F.incline(G.tour([(0.0, 0.04), (0.14, 0.0)], 4, "z", cap0=True), (0.18, s * 0.1, 0.02), (1.0, s * 0.25, -0.06)))
