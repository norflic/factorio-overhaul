"""RÉACTEUR DE KROLL (fo-kroll-reactor), 4×4 (x ±2 ; y ±2,83). CONCEPT §5.

Lecture : un gros four-puits rond cerclé, ses regards orange ; la tête de cornue bridée, boulonnée, hérissée de piquages (TiCl₄,
argon, vide, thermocouples) ; le portique de levage au-dessus ; le râtelier de bouteilles d'argon ; le transformateur à barres de
cuivre ; au SUD, la cornue sortie et son éponge de titane grise (le produit). Variante B : puits ouvert incandescent, cornue suspendue.
Variante C : deux puits en tandem, potence. Brides factices aux 4 positions tournées de l'entrée de fluide (nord, x = -0,5).
"""
import math

import commun as K
import geo as G
import outils as O

TAU = G.TAU
PALETTE = "kroll"            # commun.PALETTES ; « calcul » = palette des états clés du 3/11
D = K.D
VAR = {
    "a": dict(puits=[(-0.2, 0.55, 1.05, "ferme")], grue="portique", eponge=(-1.3, -2.05), argon=(1.3, 2.15)),
    "b": dict(puits=[(-0.2, 0.55, 1.05, "ouvert")], grue="portique", eponge=(-1.3, -2.05), argon=(1.3, 2.15)),
    "c": dict(puits=[(-0.92, 0.75, 0.78, "ferme"), (0.92, 0.75, 0.78, "ouvert")], grue="potence", eponge=(-0.15, -2.05),
              argon=(-1.35, -1.0)),
}
# entrée de fluide du prototype : tuile (-0,5, -2,5) ; ses 3 rotations ; brides dans l'emprise (1,9 tuile du centre)
RACCORDS = [((-0.5, 1.9 * D), (0, 1)), ((1.9, 0.5 * D), (1, 0)), ((0.5, -1.9 * D), (0, -1)), ((-1.9, -0.5 * D), (-1, 0))]


def puits(lot, M, x, y, R, etat):
    zt = 1.0
    K.rev(lot, M["acier"], x, y, [(0.0, R + 0.04), (0.08, R), (zt, R)], 40)
    for k in range(16):
        a = TAU * (k + 0.5) / 16
        lot.put(M["acier2"], G.boite((x + (R + 0.03) * math.cos(a), y + (R + 0.03) * math.sin(a), zt / 2), (0.05, 0.05, zt), a))
    for z in (0.22, 0.62, 0.92):
        K.cerclage(lot, M["acier2"], x, y, z, R + 0.02, 0.05, 0.025, 40)
        O.rivets_anneau(lot, M["riv"], (x, y, 0.0), R + 0.045, z, 28, 0.012)
    # regards orange tout autour (la lueur de travail)
    for a in (-math.pi / 2, -math.pi / 2 - 0.75, -math.pi / 2 + 0.75, 0.15, math.pi + 0.1):
        n = (math.cos(a), math.sin(a), 0.0)
        p = (x + (R + 0.04) * n[0], y + (R + 0.04) * n[1], 0.45)
        lot.put(M["fonte"], G.oriente(G.tour([(0.0, 0.085), (0.05, 0.085), (0.06, 0.06)], 14, "z", cap1=True), p, n))
        lot.put(M["fusion"], G.oriente(G.tour([(0.06, 0.055), (0.066, 0.0)], 14, "z"), p, n))
    # bornes de chauffe (boîtes et barres de cuivre) côté est
    for k in range(3):
        a = -0.45 + k * 0.45
        p = (x + (R + 0.12) * math.cos(a), y + (R + 0.12) * math.sin(a), 0.72)
        lot.put(M["acier2"], G.boite(p, (0.18, 0.22, 0.2), a))
        lot.put(M["cuivre"], G.boite(G.add(p, (0.12 * math.cos(a), 0.12 * math.sin(a), 0.0)), (0.1, 0.06, 0.06), a))
    # couronne réfractaire du sommet
    ring = [(zt, R + 0.05), (zt + 0.08, R + 0.05), (zt + 0.08, R * 0.74), (zt, R * 0.74)]
    lot.put(M["brique_j"], G.tour(ring, 40, "z", (x, y, 0.0)))
    if etat == "ferme":
        rr = R * 0.7
        lot.put(M["braise"], G.tour([(zt + 0.07, R * 0.74), (zt + 0.075, rr + 0.02)], 40, "z", (x, y, 0.0)))
        lot.put(M["acier"], G.tour([(zt + 0.06, rr + 0.06), (zt + 0.14, rr + 0.06)], 40, "z", (x, y, 0.0), cap0=True, cap1=True))
        pts = [((x + (rr + 0.02) * math.cos(TAU * k / 28), y + (rr + 0.02) * math.sin(TAU * k / 28), zt + 0.14), (0, 0, 1)) for k in range(28)]
        lot.put(M["riv"], G.rivets_le_long(pts, 0.022, 0.03))
        pr = [(zt + 0.14 + 0.34 * math.sin(t), rr * math.cos(t)) for t in [i / 10.0 * math.pi / 2 for i in range(11)]]
        K.rev(lot, M["acier_lisse"], x, y, pr, 40)
        zd = zt + 0.14
        # piquages : alimentation TiCl4 (vanne), argon, vide (gros), 3 thermocouples, 2 oreilles de levage
        piq = []
        for (dx, dy, r, h, vanne) in ((-0.3 * R, 0.25 * R, 0.055, 0.5, True), (0.3 * R, 0.32 * R, 0.035, 0.38, True),
                                      (0.28 * R, -0.25 * R, 0.075, 0.42, True), (-0.4 * R, -0.3 * R, 0.02, 0.5, False),
                                      (0.0, -0.45 * R, 0.02, 0.45, False), (0.5 * R, 0.0, 0.02, 0.4, False)):
            px, py = x + dx, y + dy
            zz = zd + 0.34 * math.sqrt(max(0.0, 1.0 - (dx * dx + dy * dy) / (rr * rr)))
            K.rev(lot, M["acier_clair"], px, py, [(zz - 0.05, r), (zz + h, r)], 12)
            K.bride(lot, M["acier2"], (px, py, zz + h * 0.5), (0, 0, 1), r * 1.7, 0.02)
            if vanne:
                K.vanne(lot, M, (px, py, zz + h), r * 0.9, 0.1)
            piq.append((px, py, zz + h))
        for s in (-1, 1):
            q = (x + s * rr * 0.62, y, zd + 0.22)
            lot.put(M["acier2"], G.oriente(G.tour([(0.0, 0.08), (0.12, 0.08)], 12, "z", cap1=True), q, (0, 1, 0)))
            O.anneau(lot, M["acier2"], G.add(q, (0, 0.06, 0.1)), 0.06, 0.016, 14, 5, n=(1, 0, 0))
        return piq
    # puits ouvert : intérieur incandescent, la cornue est levée
    K.rev(lot, M["braise"], x, y, [(zt + 0.07, R * 0.74), (0.3, R * 0.68)], 40, cap=False)
    lot.put(M["fusion"], G.tour([(0.3, R * 0.68), (0.31, 0.0)], 40, "z", (x, y, 0.0)))
    for k in range(12):
        a = TAU * k / 12
        lot.put(M["fonte"], G.boite((x + R * 0.71 * math.cos(a), y + R * 0.71 * math.sin(a), 0.65), (0.04, 0.05, 0.5), a))
    return []


def cornue_suspendue(lot, M, x, y, R, z0):
    """Cornue levée hors du puits : bas encore rouge, tête bridée, élingues."""
    rr = R * 0.66
    K.rev(lot, M["acier"], x, y, [(z0, rr * 0.8), (z0 + 0.06, rr), (z0 + 1.1, rr)], 32)
    lot.put(M["braise"], G.tour([(z0 + 0.02, rr * 0.82), (z0 + 0.07, rr + 0.003), (z0 + 0.42, rr + 0.003)], 32, "z", (x, y, 0.0)))
    for z in (z0 + 0.55, z0 + 0.85):
        K.cerclage(lot, M["acier2"], x, y, z, rr, 0.045, 0.02, 32)
    lot.put(M["acier"], G.tour([(z0 + 1.1, rr + 0.08), (z0 + 1.18, rr + 0.08)], 32, "z", (x, y, 0.0), cap0=True, cap1=True))
    pts = [((x + (rr + 0.04) * math.cos(TAU * k / 24), y + (rr + 0.04) * math.sin(TAU * k / 24), z0 + 1.18), (0, 0, 1)) for k in range(24)]
    lot.put(M["riv"], G.rivets_le_long(pts, 0.02, 0.025))
    K.rev(lot, M["acier_lisse"], x, y, [(z0 + 1.18 + 0.3 * math.sin(t), rr * math.cos(t)) for t in [i / 8.0 * math.pi / 2 for i in range(9)]], 32)
    for (dx, dy) in ((-0.25, 0.15), (0.2, -0.2)):
        K.rev(lot, M["acier_clair"], x + dx, y + dy, [(z0 + 1.35, 0.045), (z0 + 1.62, 0.045)], 10)
        K.bride(lot, M["acier2"], (x + dx, y + dy, z0 + 1.6), (0, 0, 1), 0.07, 0.02)
    hook = (x, y, z0 + 2.0)
    for s in (-1, 1):
        lot.put(M["acier_clair"], G.tube([(x + s * rr * 0.62, y, z0 + 1.42), hook], 0.012, 4))
        lot.put(M["acier2"], G.oriente(G.tour([(0.0, 0.07), (0.1, 0.07)], 12, "z", cap1=True), (x + s * rr * 0.62, y, z0 + 1.38), (0, 1, 0)))
    return hook


def portique(lot, M, x, crochet_z):
    """Portique de levage : 2 palées en A (est, ouest), poutre double, chariot, moufle."""
    zg = 3.2
    for xx in (-1.82, 1.82):
        for s in (-1, 1):
            lot.put(M["jaune"], G.tube([(xx, 0.55 + s * 1.15, 0.0), (xx, 0.55 + s * 0.12, zg)], 0.05, 6))
        lot.put(M["jaune"], G.tube([(xx, 0.55 - 0.75, 1.2), (xx, 0.55 + 0.75, 1.2)], 0.03, 5))
        for s in (-1, 1):
            K.caisson(lot, M["beton"], xx, 0.55 + s * 1.15, 0.0, 0.22, 0.28, 0.1, 0.02)
    for dy in (-0.16, 0.16):
        K.caisson(lot, M["jaune"], 0.0, 0.55 + dy, zg, 3.85, 0.13, 0.26, 0.02)
    lot.put(M["chevron"], G.boite((0.0, 0.55 - 0.23, zg + 0.13), (3.6, 0.012, 0.1)))
    # chariot et treuil
    K.caisson(lot, M["acier2"], x, 0.55, zg + 0.26, 0.5, 0.52, 0.22, 0.02)
    lot.put(M["fonte"], G.tour([(x - 0.18, 0.11), (x + 0.18, 0.11)], 16, "x", (0.0, 0.55, zg + 0.44), cap0=True, cap1=True))
    K.caisson(lot, M["acier"], x + 0.18, 0.75, zg + 0.48, 0.2, 0.16, 0.14, 0.02)
    for dx in (-0.06, 0.06):
        lot.put(M["acier_clair"], G.tube([(x + dx, 0.55, zg), (x + dx, 0.55, crochet_z + 0.12)], 0.007, 3))
    lot.put(M["jaune"], G.boite((x, 0.55, crochet_z + 0.08), (0.2, 0.12, 0.12)))
    lot.put(M["acier2"], G.tube(G.coudee([(x, 0.55, crochet_z + 0.02), (x, 0.55, crochet_z - 0.1), (x + 0.08, 0.55, crochet_z - 0.12),
                                          (x + 0.1, 0.55, crochet_z - 0.04)], 0.04, 4), 0.016, 6))
    # cabine
    K.caisson(lot, M["acier"], 1.55, 0.2, zg - 0.45, 0.32, 0.3, 0.42, 0.02)
    lot.put(M["verre"], G.boite((1.55, 0.04, zg - 0.22), (0.26, 0.01, 0.18)))


def potence(lot, M, x, y, cible):
    K.caisson(lot, M["beton"], x, y, 0.0, 0.4, 0.46, 0.12, 0.02)
    K.rev(lot, M["jaune"], x, y, [(0.12, 0.13), (0.3, 0.11), (2.9, 0.09)], 18)
    zj = 2.75
    a = (x, y, zj)
    b = (cible[0], cible[1], zj)
    O.treillis(lot, M["jaune"], a, b, l=0.16, h=0.2, n=8, rc=0.018, rd=0.009)
    lot.put(M["acier_clair"], G.tube([(x, y, 3.0), G.add(b, (0, 0, 0.1))], 0.01, 4))
    lot.put(M["jaune"], G.boite(G.add(G.lerp(a, b, 0.8), (0, 0, -0.14)), (0.18, 0.18, 0.1)))
    h = G.add(G.lerp(a, b, 0.8), (0, 0, -0.8))
    lot.put(M["acier_clair"], G.tube([G.add(G.lerp(a, b, 0.8), (0, 0, -0.18)), h], 0.007, 3))
    lot.put(M["jaune"], G.boite(h, (0.16, 0.1, 0.1)))


def eponge(lot, M, x, y, rnd):
    """Cornue découpée : couronne d'acier, gâteau d'éponge grise, morceaux à côté."""
    K.rev(lot, M["acier"], x, y, [(0.0, 0.44), (0.62, 0.44)], 30, cap=False)
    K.rev(lot, M["acier2"], x, y, [(0.0, 0.47), (0.08, 0.47)], 30)
    K.cerclage(lot, M["acier2"], x, y, 0.4, 0.44, 0.04, 0.02, 30)
    lot.put(M["eponge"], G.tour([(0.5, 0.43), (0.55, 0.3), (0.58, 0.0)], 30, "z", (x, y, 0.0)))
    for k in range(70):
        a, d = rnd.f(0.0, TAU), rnd.f(0.0, 0.4)
        lot.put(M["eponge"], G.sphere((x + d * math.cos(a), y + d * math.sin(a), 0.56 + rnd.f(-0.02, 0.03)), rnd.f(0.025, 0.05), 6, 3))
    lot.put(M["braise"], G.sphere((x + 0.05, y - 0.04, 0.565), 0.07, 10, 4, zmin=0.0))
    K.tas(lot, M["eponge"], (x + 0.68, y - 0.15, 0.03), 0.18, 0.2, 0.12, rnd, 26, 0.03, 0.05)


def argon(lot, M, x, y):
    K.bz(lot, M["acier2"], x, y, 0.0, 0.62, 0.56, 0.05)
    for i in range(4):
        for j in range(2):
            bx, by = x - 0.23 + i * 0.155, y - 0.12 + j * 0.24
            K.rev(lot, M["bleu"], bx, by, [(0.05, 0.065), (0.62, 0.065), (0.68, 0.05), (0.72, 0.02)], 12)
            K.rev(lot, M["vert"], bx, by, [(0.6, 0.066), (0.66, 0.056)], 12)
            K.rev(lot, M["acier_clair"], bx, by, [(0.72, 0.02), (0.78, 0.02)], 8)
    for z in (0.3, 0.55):
        lot.put(M["acier2"], G.tube([(x - 0.31, y - 0.25, z), (x + 0.31, y - 0.25, z)], 0.012, 4))
    lot.put(M["cuivre"], G.tube([(x - 0.3, y + 0.15, 0.82), (x + 0.3, y + 0.15, 0.82)], 0.014, 5))
    for k in range(4):
        lot.put(M["cuivre"], G.tube([(x - 0.23 + k * 0.155, y + 0.12, 0.78), (x - 0.23 + k * 0.155, y + 0.15, 0.82)], 0.008, 4))
    lot.put(M["jaune"], G.boite((x, y - 0.285, 0.42), (0.2, 0.01, 0.12)))


def transfo(lot, M, x, y, cible):
    K.caisson(lot, M["vert"], x, y, 0.05, 0.6, 0.72, 0.62, 0.03)
    for k in range(7):
        lot.put(M["vert"], G.boite((x + 0.33, y - 0.3 + k * 0.1, 0.38), (0.06, 0.02, 0.5)))
        lot.put(M["vert"], G.boite((x - 0.33, y - 0.3 + k * 0.1, 0.38), (0.06, 0.02, 0.5)))
    for k in range(3):
        bx = x - 0.18 + k * 0.18
        K.rev(lot, M["porcelaine"], bx, y + 0.1, [(0.67, 0.045)] + [(0.7 + 0.05 * i + (0.02 if i % 2 else 0), 0.055 if i % 2 else 0.035) for i in range(5)] + [(0.98, 0.02)], 12)
        lot.put(M["cuivre"], G.tube(G.coudee([(bx, y + 0.1, 0.98), (bx, y + 0.1, 1.08), (cible[0], cible[1] - 0.1 + k * 0.1, 1.08),
                                              (cible[0], cible[1] - 0.1 + k * 0.1, 0.85)], 0.06, 4), 0.022, 6))
    lot.put(M["jaune"], G.boite((x, y - 0.37, 0.45), (0.2, 0.01, 0.16)))
    K.bz(lot, M["beton"], x, y, 0.0, 0.72, 0.84, 0.05)


def build(S, lot, v):
    M = K.matieres(S, PALETTE)
    v = VAR[v]
    rnd = G.Rnd(7707)
    lot.put(M["beton"], G.prisme([(-1.97, -2.78), (1.97, -2.78), (1.97, 2.78), (-1.97, 2.78)], 0.0, 0.03))
    piqs = []
    for (x, y, R, etat) in v["puits"]:
        # caillebotis autour du puits
        lot.put(M["acier2"], G.prisme([(x + (R + 0.3) * math.cos(TAU * k / 20), y + (R + 0.3) * math.sin(TAU * k / 20)) for k in range(20)], 0.03, 0.06))
        piqs += puits(lot, M, x, y, R, etat)
        if etat == "ouvert" and v["grue"] == "portique":
            cornue_suspendue(lot, M, x + 1.0, y - 0.1, R, 1.25)
    # cuve et pompe doseuse de TiCl4 au nord-ouest, ligne depuis l'entrée nord
    tx, ty = -1.42, 2.25
    K.rev(lot, M["acier_clair"], tx, ty, [(0.03, 0.34), (1.1, 0.34)] + [(1.1 + 0.2 * math.sin(t), 0.34 * math.cos(t)) for t in [i / 8.0 * math.pi / 2 for i in range(1, 9)]], 28)
    for z in (0.35, 0.75):
        K.cerclage(lot, M["acier2"], tx, ty, z, 0.34, 0.04, 0.018, 28)
    lot.put(M["chevron"], G.tour([(0.52, 0.343), (0.6, 0.343)], 28, "z", (tx, ty, 0.0)))
    K.caisson(lot, M["acier2"], tx + 0.5, ty - 0.35, 0.03, 0.26, 0.2, 0.2, 0.02)
    feed = piqs[0] if piqs else (v["puits"][0][0], v["puits"][0][1], 2.0)
    O.tuyau(lot, M["acier_clair"], M["acier2"], [(tx + 0.5, ty - 0.35, 0.23), (tx + 0.5, ty - 0.35, 2.05), (feed[0], ty - 0.35, 2.05),
                                                 (feed[0], feed[1], 2.05), (feed[0], feed[1], feed[2])], 0.03, rb=0.1, pas_bride=0.6)
    for (p, n) in RACCORDS:
        q = (p[0], p[1], 0.22)
        K.bride(lot, M["acier2"], G.add(q, (n[0] * 0.18, n[1] * 0.18, 0.0)), (n[0], n[1], 0.0), 0.11, 0.03)
        lot.put(M["acier_clair"], G.tube([q, G.add(q, (n[0] * 0.2, n[1] * 0.2, 0.0))], 0.07, 12))
        K.vanne(lot, M, q, 0.06, 0.12)
        lot.put(M["acier2"], G.boite((p[0], p[1], 0.11), (0.14, 0.14, 0.2)))
    O.tuyau(lot, M["acier_clair"], M["acier2"], [RACCORDS[0][0] + (0.3,), (RACCORDS[0][0][0], ty, 0.3), (tx + 0.3, ty, 0.3)], 0.04, rb=0.1)
    ax, ay = v["argon"]
    argon(lot, M, ax, ay)
    if piqs and len(piqs) > 1:
        O.tuyau(lot, M["cuivre"], M["acier2"], [(ax, ay + 0.15, 0.82), (ax, ay + 0.15, 1.75), (piqs[1][0], ay + 0.15, 1.75), (piqs[1][0], piqs[1][1], 1.75),
                                               (piqs[1][0], piqs[1][1], piqs[1][2])], 0.016, rb=0.08, pas_bride=2.0)
    px, py, R, _ = v["puits"][-1]
    transfo(lot, M, 1.5, -1.0, (px + R + 0.25, py - 0.25))
    if v["grue"] == "portique":
        if any(e == "ouvert" for (_, _, _, e) in v["puits"]):
            portique(lot, M, 0.8, 3.25)
        else:
            portique(lot, M, -0.2, 2.25)
    else:
        potence(lot, M, 0.0, 2.35, (0.92, 0.75))
    ex, ey = v["eponge"]
    eponge(lot, M, ex, ey, rnd)
    # soutirage du chlorure de magnésium : rigole et pot rougeoyant au sud du puits
    x0, y0, R0, _ = v["puits"][0]
    mx, my = x0 + 0.55, y0 - R0 - 0.65
    lot.put(M["fonte"], G.tube([(x0 + 0.3, y0 - R0 + 0.05, 0.28), (mx, my + 0.15, 0.42)], 0.04, 8))
    K.rev(lot, M["fonte"], mx, my, [(0.03, 0.2), (0.38, 0.24), (0.4, 0.25)], 20, cap=False)
    K.rev(lot, M["bain"], mx, my, [(0.37, 0.23), (0.375, 0.0)], 20)
    for k in range(9):
        a, d = rnd.f(0.0, TAU), rnd.f(0.05, 0.18)
        lot.put(M["croute"], G.boite((mx + d * math.cos(a), my + d * math.sin(a), 0.38), (rnd.f(0.05, 0.1), rnd.f(0.05, 0.09), 0.01), rnd.f(0.0, 3.0)))
    K.armoire(lot, M, 1.55, -2.35, 0.03, 0.4, 0.22, 0.5)
    return {}
