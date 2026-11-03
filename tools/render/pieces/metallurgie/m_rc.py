"""CUVE D'ÉLECTROLYSE IGNÉE (fo-reduction-cell), 4×4 (x ±2 ; y ±2,83). CONCEPT §3 (Hall-Héroult).

Lecture : un caisson bas et long à nervures, ses capots inclinés ; la superstructure-pont, sa trémie d'alumine et ses piqueurs ;
les rangées de tiges d'anode serrées sur les cadres d'aluminium ; les barres omnibus d'aluminium vif et leurs montées ; au SUD, un capot
levé montre le bain orange sous la croûte, le creuset siphonne le métal. Variante C : anode continue « Söderberg » hérissée de goujons.
"""
import math

import commun as K
import geo as G
import outils as O

TAU = G.TAU
PALETTE = "cuve"            # commun.PALETTES ; « calcul » = palette des états clés du 3/11
YC = 0.25                  # axe longitudinal de la cuve
XP, Y0, Y1, ZP = 1.8, -1.45, 1.95, 0.72
VAR = {
    # RETENUE (critique du 3/11) : caisson, creuset et gaine de A ; superstructure et barres REFAITES (v2)
    "a": dict(soder=False, montees="nord", creuset=(0.45, -2.2), gaine="est", ouvert=(0.1, 0.85), v2=True),
    "b": dict(soder=False, montees="sud", creuset=(1.25, -2.3), gaine="haut", ouvert=(0.9, 1.6)),
    "c": dict(soder=True, montees="nord", creuset=(-0.35, -2.2), gaine="est", ouvert=None),
}


def caisson_cuve(lot, M):
    lot.put(M["acier"], G.prisme([(-XP, Y0), (XP, Y0), (XP, Y1), (-XP, Y1)], 0.06, ZP))
    lot.put(M["acier2"], G.prisme([(-XP - 0.05, Y0 - 0.05), (XP + 0.05, Y0 - 0.05), (XP + 0.05, Y1 + 0.05), (-XP - 0.05, Y1 + 0.05)], ZP, ZP + 0.05))
    # berceaux : nervures verticales sur les longs pans, raidisseurs aux bouts
    n = 13
    for i in range(n):
        x = -XP + 0.1 + i * (2 * XP - 0.2) / (n - 1)
        for (y, s) in ((Y0, -1), (Y1, 1)):
            lot.put(M["acier2"], G.prisme([(x - 0.035, y), (x + 0.035, y), (x + 0.035, y + s * 0.13), (x - 0.035, y + s * 0.13)], 0.0, ZP + 0.03, 1.0))
            lot.put(M["acier2"], G.boite((x, y + s * 0.1, 0.03), (0.12, 0.2, 0.06)))
    for x in (-XP, XP):
        for k in range(4):
            y = Y0 + 0.4 + k * (Y1 - Y0 - 0.8) / 3
            lot.put(M["acier2"], G.boite((x + (0.06 if x > 0 else -0.06), y, ZP / 2), (0.12, 0.07, ZP)))
    # rangées de boulons sur la bride
    pts = [((x, Y0 - 0.02, ZP + 0.052), (0, 0, 1)) for x in [-XP + 0.15 * k for k in range(25)]]
    lot.put(M["riv"], G.rivets_le_long(pts, 0.012, 0.01))


def capots(lot, M, ouvert):
    """Capots inclinés de part et d'autre de la superstructure ; un panneau levé (ouvert = (x0, x1)) montre le bain."""
    n = 12
    w = (2 * XP - 0.1) / n
    for side, (ya, yb) in (("s", (Y0 + 0.02, YC - 0.36)), ("n", (Y1 - 0.02, YC + 0.36))):
        for i in range(n):
            x = -XP + 0.05 + (i + 0.5) * w
            if side == "s" and ouvert and ouvert[0] <= x <= ouvert[1]:
                continue
            q = [(x - w * 0.47, ya, ZP + 0.05), (x + w * 0.47, ya, ZP + 0.05), (x + w * 0.47, yb, 1.0), (x - w * 0.47, yb, 1.0)]
            lot.put(M["acier"], G.merge((q, [(0, 1, 2, 3)], [(p[0], p[1]) for p in q]), G.loft([q, [G.add(p, (0, 0, -0.025)) for p in q]], closed=True)))
            m = G.lerp(G.lerp(q[0], q[1], 0.5), G.lerp(q[2], q[3], 0.5), 0.35)
            lot.put(M["acier_clair"], G.tube([G.add(m, (-0.06, 0, 0.03)), G.add(m, (0.06, 0, 0.03))], 0.009, 4))
    if ouvert:
        x0, x1 = ouvert
        # bain sous la croûte : fissures orange, croûte sombre en plaques
        # croûte sombre fendue : la lueur n'est que dans les fissures
        cy0, cy1 = Y0 + 0.04, YC - 0.4
        lot.put(M["croute"], G.boite(((x0 + x1) / 2, (cy0 + cy1) / 2, ZP + 0.06), (x1 - x0 - 0.04, cy1 - cy0, 0.02)))
        r = G.Rnd(6611)
        for k in range(5):
            px, py = r.f(x0 + 0.08, x1 - 0.08), cy0 + 0.05
            ang = math.pi / 2 + r.f(-0.5, 0.5)
            for j in range(7):
                L = r.f(0.1, 0.2)
                qx = min(x1 - 0.04, max(x0 + 0.04, px + L * math.cos(ang)))
                qy = min(cy1 - 0.02, py + L * math.sin(ang))
                lot.put(M["bain"], G.boite(((px + qx) / 2, (py + qy) / 2, ZP + 0.072), (math.hypot(qx - px, qy - py) + 0.03, 0.035, 0.008),
                                           math.atan2(qy - py, qx - px)))
                px, py = qx, qy
                ang += r.f(-0.7, 0.7)
                if py >= cy1 - 0.03:
                    break
        lot.put(M["bain"], G.boite(((x0 + x1) / 2 + 0.05, cy0 + 0.25, ZP + 0.073), (0.09, 0.07, 0.008), 0.4))
        # le panneau levé, posé debout contre la superstructure
        lot.put(M["acier"], G.boite(((x0 + x1) / 2, YC - 0.5, 1.45), (x1 - x0 - 0.05, 0.03, 0.42), 0.0, 0.25))


def superstructure(lot, M, v):
    zg = 1.3
    K.caisson(lot, M["acier"], 0.0, YC, zg, 2 * XP - 0.1, 0.5, 0.34, 0.03)
    for x in (-XP + 0.12, XP - 0.12):
        for s in (-1, 1):
            lot.put(M["acier2"], G.tube([(x, YC + s * 1.0, ZP + 0.05), (x, YC + s * 0.18, zg + 0.1)], 0.045, 6))
        lot.put(M["acier2"], G.boite((x, YC, zg - 0.2), (0.12, 0.5, 0.4)))
    # cadres anodiques d'aluminium, crics, tiges d'anode serrées
    for s in (-1, 1):
        ya = YC + s * 0.4
        lot.put(M["alu"], G.boite((0.0, ya, 1.36), (2 * XP - 0.3, 0.12, 0.16)))
        for x in (-1.2, 0.0, 1.2):
            lot.put(M["acier2"], G.tube([(x, ya, 1.44), (x, YC + s * 0.22, zg + 0.3)], 0.03, 6))
        for i in range(9):
            x = -1.48 + i * 0.37
            lot.put(M["alu"], G.boite((x, ya + s * 0.09, 1.14), (0.075, 0.075, 0.56)))
            lot.put(M["acier2"], G.boite((x, ya + s * 0.075, 1.36), (0.14, 0.05, 0.13)))
            lot.put(M["acier_clair"], G.tube([(x - 0.05, ya + s * 0.11, 1.36), (x + 0.05, ya + s * 0.11, 1.36)], 0.012, 4))
            K.rev(lot, M["acier2"], x, ya + s * 0.09, [(0.98, 0.07), (1.02, 0.07)], 8)
    # trémie d'alumine et piqueurs de croûte
    zt = zg + 0.34
    lot.put(M["acier"], G.prisme([(-0.32, YC - 0.24), (0.32, YC - 0.24), (0.32, YC + 0.24), (-0.32, YC + 0.24)], zt, zt + 0.12))
    lot.put(M["acier"], G.prisme([(-0.32, YC - 0.24), (0.32, YC - 0.24), (0.32, YC + 0.24), (-0.32, YC + 0.24)], zt + 0.12, zt + 0.62, 1.3))
    lot.put(M["acier2"], G.prisme([(-0.42, YC - 0.32), (0.42, YC - 0.32), (0.42, YC + 0.32), (-0.42, YC + 0.32)], zt + 0.62, zt + 0.67))
    K.rev(lot, M["acier_clair"], 0.15, YC, [(zt + 0.67, 0.07), (zt + 0.85, 0.07), (zt + 0.9, 0.0)], 12)
    O.tuyau(lot, M["acier_clair"], M["acier2"], [(0.15, YC, zt + 0.86), (0.15, YC + 0.5, zt + 0.86), (0.15, Y1 + 0.5, zt + 0.86)], 0.04)
    for x in (-0.95, 0.95):
        K.rev(lot, M["jaune"], x, YC, [(zt - 0.02, 0.07), (zt + 0.42, 0.07), (zt + 0.46, 0.05)], 14)
        lot.put(M["acier_clair"], G.tube([(x, YC, zt + 0.46), (x, YC, zt + 0.56)], 0.015, 5))
        O.flexible(lot, M["caoutchouc"], [(x + 0.07, YC, zt + 0.35), (x + 0.25, YC + 0.1, zt + 0.25), (x + 0.4, YC + 0.12, zt + 0.05)], 0.012)
    K.rambarde(lot, M["jaune"], [(-XP + 0.2, YC - 0.25), (XP - 0.2, YC - 0.25)], zt, 0.18, 0.4)
    return zt


def soderberg(lot, M):
    """Anode continue : grand caisson d'aluminium cerclé, pâte noire au sommet hérissée de goujons, jupe de gaz, bain en couronne."""
    ax, ay = 1.35, 0.68
    lot.put(M["croute"], G.prisme([(-XP + 0.05, Y0 + 0.05), (XP - 0.05, Y0 + 0.05), (XP - 0.05, Y1 - 0.05), (-XP + 0.05, Y1 - 0.05)], ZP + 0.04, ZP + 0.06))
    # bain visible dans la fente autour de l'anode et par quelques trous de piquage
    g = 0.07
    for (cx, cy, sx, sy) in ((0.0, YC - ay - 0.06 - g / 2, 2 * ax + 0.12, g), (0.0, YC + ay + 0.06 + g / 2, 2 * ax + 0.12, g),
                             (-ax - 0.06 - g / 2, YC, g, 2 * ay + 0.12 + 2 * g), (ax + 0.06 + g / 2, YC, g, 2 * ay + 0.12 + 2 * g)):
        lot.put(M["bain"], G.boite((cx, cy, ZP + 0.065), (sx, sy, 0.012)))
    r = G.Rnd(6633)
    for k in range(9):
        cx = r.f(-XP + 0.2, XP - 0.2)
        cy = YC - ay - 0.3 - r.f(0.0, 0.35) if k % 2 else YC + ay + 0.3 + r.f(0.0, 0.5)
        lot.put(M["bain"], G.boite((cx, cy, ZP + 0.066), (r.f(0.06, 0.12), r.f(0.05, 0.1), 0.012), r.f(0.0, 3.0)))
    for k in range(70):
        cx, cy = r.f(-XP + 0.1, XP - 0.1), r.f(Y0 + 0.1, Y1 - 0.1)
        if abs(cx) < ax + 0.2 and abs(cy - YC) < ay + 0.2:
            continue
        lot.put(M["croute"], G.boite((cx, cy, ZP + 0.075), (r.f(0.08, 0.2), r.f(0.06, 0.18), 0.03), r.f(0.0, 3.0)))
    lot.put(M["acier2"], G.prisme([(-ax - 0.06, YC - ay - 0.06), (ax + 0.06, YC - ay - 0.06), (ax + 0.06, YC + ay + 0.06), (-ax - 0.06, YC + ay + 0.06)], ZP + 0.05, ZP + 0.22))
    lot.put(M["alu"], G.prisme([(-ax, YC - ay), (ax, YC - ay), (ax, YC + ay), (-ax, YC + ay)], ZP + 0.22, 1.75))
    for z in (0.95, 1.2, 1.45, 1.7):
        lot.put(M["acier2"], G.prisme([(-ax - 0.025, YC - ay - 0.025), (ax + 0.025, YC - ay - 0.025), (ax + 0.025, YC + ay + 0.025), (-ax - 0.025, YC + ay + 0.025)], z - 0.025, z + 0.025))
    lot.put(M["noir"], G.prisme([(-ax + 0.03, YC - ay + 0.03), (ax - 0.03, YC - ay + 0.03), (ax - 0.03, YC + ay - 0.03), (-ax + 0.03, YC + ay - 0.03)], 1.75, 1.77))
    for i in range(10):
        for j in range(4):
            x = -ax + 0.15 + i * (2 * ax - 0.3) / 9
            y = YC - ay + 0.2 + j * (2 * ay - 0.4) / 3
            lot.put(M["acier_clair"], G.tube([(x, y, 1.6), (x, y, 2.0 + 0.04 * ((i + j) % 2))], 0.022, 6))
            lot.put(M["cuivre"], G.boite((x, y, 1.98 + 0.04 * ((i + j) % 2)), (0.06, 0.06, 0.04)))
        lot.put(M["cuivre"], G.boite((-ax + 0.15 + i * (2 * ax - 0.3) / 9, YC, 2.06), (0.05, 2 * ay - 0.3, 0.04)))
    # cadre de levage et crics
    for x in (-XP + 0.12, XP - 0.12):
        for s in (-1, 1):
            lot.put(M["acier2"], G.tube([(x, YC + s * 1.0, ZP + 0.05), (x, YC + s * 0.2, 2.35)], 0.045, 6))
    lot.put(M["acier"], G.boite((0.0, YC, 2.4), (2 * XP - 0.1, 0.36, 0.18)))
    for x in (-0.9, 0.0, 0.9):
        K.rev(lot, M["jaune"], x, YC, [(2.1, 0.06), (2.32, 0.06)], 12)
    return 2.49


def montees(lot, M, cote):
    """Barres omnibus au sol le long des pans, montées vers les cadres anodiques."""
    yn = Y1 + 0.22 if cote == "nord" else Y0 - 0.22
    for y in (Y1 + 0.22, Y0 - 0.22):
        lot.put(M["alu"], G.boite((0.0, y, 0.12), (2 * XP + 0.3, 0.22, 0.12)))
        lot.put(M["alu"], G.boite((0.0, y, 0.25), (2 * XP + 0.1, 0.16, 0.1)))
    s = 1 if cote == "nord" else -1
    for x in (-1.3, -0.45, 0.45, 1.3):
        lot.put(M["alu"], G.boite((x, yn, 0.75), (0.2, 0.12, 1.2)))
        lot.put(M["alu"], G.boite((x, (yn + YC + s * 0.46) / 2, 1.4), (0.2, abs(yn - YC - s * 0.46), 0.1)))
        lot.put(M["cuivre"], G.boite((x, YC + s * 0.47, 1.4), (0.24, 0.08, 0.16)))
        lot.put(M["acier2"], G.boite((x, yn, 0.6), (0.24, 0.16, 0.06)))
        for z in (0.95, 1.2):
            lot.put(M["riv"], G.boite((x, yn - s * 0.065, z), (0.12, 0.01, 0.02)))
    for x in (-1.75, 1.75):
        lot.put(M["cuivre"], G.boite((x, yn, 0.2), (0.16, 0.26, 0.08)))


def creuset(lot, M, x, y, cible):
    """Creuset de coulée sur chariot, siphon dans le bain (le produit sort au sud)."""
    K.bz(lot, M["acier2"], x, y, 0.0, 0.86, 0.66, 0.12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            lot.put(M["fonte"], G.tour([(-0.03, 0.07), (0.03, 0.07)], 12, "x", (x + sx * 0.3, y + sy * 0.26, 0.07), cap0=True, cap1=True))
    K.rev(lot, M["acier"], x, y, [(0.12, 0.36), (0.16, 0.4), (0.68, 0.4), (0.72, 0.36), (0.8, 0.3)], 28)
    for z in (0.3, 0.55):
        K.cerclage(lot, M["acier2"], x, y, z, 0.4, 0.04, 0.018)
    K.rev(lot, M["fonte"], x + 0.1, y, [(0.8, 0.09), (0.86, 0.09)], 12)
    lot.put(M["fusion"], G.tour([(0.86, 0.07), (0.865, 0.0)], 12, "z", (x + 0.1, y, 0.0)))
    s = [(x + 0.1, y, 0.86), (x + 0.1, y, 1.25), (cible[0], (y + cible[1]) / 2, 1.3), (cible[0], cible[1], 1.0), (cible[0], cible[1], ZP - 0.05)]
    lot.put(M["fonte"], G.tube(G.coudee(s, 0.12, 5), 0.04, 8))
    lot.put(M["bain"], G.tube([(cible[0], cible[1], ZP - 0.02), (cible[0], cible[1], ZP + 0.08)], 0.045, 8))
    for t in (0.0, math.pi):
        lot.put(M["acier2"], G.tour([(-0.03, 0.05), (0.03, 0.05)], 10, "x", (x + 0.42 * math.cos(t), y, 0.6), cap0=True, cap1=True))
    lot.put(M["chevron"], G.boite((x, y - 0.335, 0.1), (0.8, 0.012, 0.06)))


def build(S, lot, v):
    M = K.matieres(S, PALETTE)
    v = VAR[v]
    lot.put(M["beton"], G.prisme([(-1.97, -2.78), (1.97, -2.78), (1.97, 2.78), (-1.97, 2.78)], 0.0, 0.03))
    K.chevrons(lot, M, -1.9, 1.9, -2.7, 0.03)
    caisson_cuve(lot, M)
    if v.get("v2"):
        barres_v2(lot, M)
    else:
        montees(lot, M, v["montees"])
    if v["soder"]:
        zt = soderberg(lot, M)
        cible = (-0.35, Y0 + 0.18)
    else:
        capots(lot, M, v["ouvert"])
        zt = superstructure_v2(lot, M) if v.get("v2") else superstructure(lot, M, v)
        o = v["ouvert"]
        cible = ((o[0] + o[1]) / 2, Y0 + 0.25)
    cx, cy = v["creuset"]
    creuset(lot, M, cx, cy, cible)
    # gaine d'aspiration des fumées
    if v["gaine"] == "est":
        O.tuyau(lot, M["acier"], M["acier2"], [(XP - 0.2, YC, zt - 0.1), (XP + 0.12, YC, zt - 0.1), (XP + 0.12, YC + 1.0, zt - 0.1),
                                               (XP + 0.12, 2.75, zt - 0.1)], 0.15, rb=0.2, pas_bride=0.45)
    else:
        O.tuyau(lot, M["acier"], M["acier2"], [(XP - 0.25, YC, zt - 0.1), (XP - 0.25, YC, 2.75), (XP - 0.25, 2.75, 2.75)], 0.17, rb=0.25, pas_bride=0.45)
        lot.put(M["acier"], G.tour([(-1.9, 0.0), (-1.88, 0.24), (1.9, 0.24)], 26, "x", (0.0, 2.75, 2.75)))
        for x in (-1.6, 0.0, 1.6):
            lot.put(M["acier2"], G.tube([(x, 2.75, 0.0), (x, 2.75, 2.52)], 0.04, 6))
    # armoire de court-circuit et plaque « courant continu »
    K.armoire(lot, M, -1.55, -2.35, 0.03, 0.42, 0.24, 0.5)
    lot.put(M["jaune"], G.boite((-1.0, Y0 - 0.08, 0.45), (0.22, 0.01, 0.16)))
    return {}


# ------------------------------------------------------------------------------------------------- v2 (critique du 3/11)
def superstructure_v2(lot, M):
    """Poutre-portique d'acier, deux cadres anodiques d'aluminium vif, peigne de 2 × 9 tiges d'anode serrées par des pinces
    de cuivre ; deux trémies d'alumine (poudre blanche visible) et deux piqueurs de croûte."""
    zg0, zg1 = 1.7, 1.98
    K.caisson(lot, M["acier"], 0.0, YC, zg0, 2 * XP - 0.15, 0.3, zg1 - zg0, 0.03)
    for x in (-XP + 0.1, XP - 0.1):
        for s in (-1, 1):
            lot.put(M["acier2"], G.tube([(x, YC + s * 1.05, ZP + 0.05), (x, YC + s * 0.12, zg0 + 0.05)], 0.05, 6))
        lot.put(M["acier2"], G.boite((x, YC, zg0 - 0.25), (0.14, 0.34, 0.5)))
        lot.put(M["chevron"], G.boite((x, YC - 0.175, zg0 - 0.25), (0.14, 0.012, 0.18)))
    for s in (-1, 1):
        yb = YC + s * 0.27
        lot.put(M["alu"], G.boite((0.0, yb, 1.52), (2 * XP - 0.35, 0.15, 0.2)))
        for x in (-1.1, 0.0, 1.1):
            K.rev(lot, M["jaune"], x, YC + s * 0.17, [(1.6, 0.045), (zg0 + 0.02, 0.045)], 10)
        yt = YC + s * 0.4
        for i in range(9):
            x = -1.44 + i * 0.36
            lot.put(M["alu"], G.boite((x, yt, 1.3), (0.085, 0.085, 0.76)))
            lot.put(M["cuivre"], G.boite((x, yb + s * 0.09, 1.55), (0.14, 0.08, 0.12)))
            lot.put(M["acier_clair"], G.tube([(x - 0.06, yb + s * 0.13, 1.55), (x + 0.06, yb + s * 0.13, 1.55)], 0.016, 5))
            K.rev(lot, M["acier2"], x, yt, [(1.0, 0.075), (1.05, 0.075)], 8)
    # trémies d'alumine
    for x in (-0.85, 0.85):
        base = [(x - 0.2, YC - 0.18), (x + 0.2, YC - 0.18), (x + 0.2, YC + 0.18), (x - 0.2, YC + 0.18)]
        lot.put(M["acier"], G.prisme(base, zg1, zg1 + 0.12))
        lot.put(M["acier"], G.prisme(base, zg1 + 0.12, zg1 + 0.55, 1.4))
        lot.put(M["acier2"], G.prisme([(x - 0.3, YC - 0.27), (x + 0.3, YC - 0.27), (x + 0.3, YC + 0.27), (x - 0.3, YC + 0.27)], zg1 + 0.55, zg1 + 0.6))
        lot.put(M["alumine"], G.prisme([(x - 0.25, YC - 0.22), (x + 0.25, YC - 0.22), (x + 0.25, YC + 0.22), (x - 0.25, YC + 0.22)], zg1 + 0.56, zg1 + 0.62, 0.7))
        lot.put(M["chevron"], G.boite((x, YC - 0.255, zg1 + 0.4), (0.4, 0.012, 0.08)))
    O.tuyau(lot, M["acier_clair"], M["acier2"], [(-0.85, YC + 0.2, zg1 + 0.66), (-0.85, YC + 0.2, zg1 + 0.78), (0.85, YC + 0.2, zg1 + 0.78),
                                                 (0.85, YC + 0.2, zg1 + 0.66)], 0.035, rb=0.08, pas_bride=0.6)
    # piqueurs de croûte : vérins jaunes, tige jusqu'au bain
    for x in (-0.36, 0.36):
        K.rev(lot, M["jaune"], x, YC, [(zg1, 0.07), (zg1 + 0.42, 0.07), (zg1 + 0.46, 0.05)], 14)
        lot.put(M["acier_clair"], G.tube([(x, YC, zg1 + 0.46), (x, YC, zg1 + 0.56)], 0.02, 5))
        lot.put(M["acier_clair"], G.tube([(x, YC, zg0), (x, YC, 0.95)], 0.025, 6))
        O.flexible(lot, M["caoutchouc"], [(x + 0.07, YC, zg1 + 0.35), (x + 0.22, YC + 0.12, zg1 + 0.2), (x + 0.3, YC + 0.15, zg1 + 0.02)], 0.016)
    K.rambarde(lot, M["jaune"], [(-XP + 0.25, YC - 0.15), (XP - 0.25, YC - 0.15)], zg1, 0.22)
    return zg1 - 0.05


def barres_v2(lot, M):
    """Deux barres omnibus massives en aluminium vif le long des grands côtés, 4 montées en paquets de plaques vers le cadre
    anodique nord, souples de cuivre, plaques « danger »."""
    for y in (Y1 + 0.24, Y0 - 0.24):
        lot.put(M["alu"], G.boite((0.0, y, 0.15), (2 * XP + 0.3, 0.26, 0.2)))
        for x in (-1.6, -0.6, 0.6, 1.6):
            lot.put(M["acier2"], G.boite((x, y, 0.03), (0.1, 0.3, 0.06)))
    yb = YC + 0.27
    for x in (-1.3, -0.45, 0.45, 1.3):
        yr = Y1 + 0.24
        for k in range(5):
            xx = x - 0.09 + k * 0.045
            lot.put(M["alu"], G.boite((xx, yr, 0.95), (0.03, 0.14, 1.3)))
            lot.put(M["alu"], G.boite((xx, (yr + yb + 0.15) / 2, 1.65), (0.03, yr - yb - 0.1, 0.1)))
        lot.put(M["acier2"], G.boite((x, yr, 0.62), (0.28, 0.18, 0.06)))
        lot.put(M["acier2"], G.boite((x, yr, 1.25), (0.28, 0.18, 0.06)))
        lot.put(M["chevron"], G.boite((x, yr - 0.1, 0.9), (0.2, 0.012, 0.14)))
        for k in range(3):
            xx = x - 0.07 + k * 0.07
            O.flexible(lot, M["cuivre"], [(xx, yb + 0.22, 1.66), (xx, yb + 0.16, 1.74), (xx, yb + 0.08, 1.6)], 0.02)
