"""PYLÔNE HAUTE TENSION (fo-ht-pylon), 2×2 (x ±1 ; y ±1,41). CONCEPT §4.

Lecture : un pylône en treillis galvanisé plus haut que le grand poteau vanilla, 4 pieds sur massifs de béton, dispositif
anti-escalade et plaque « danger » ; consoles et longues chaînes de disques de verre PENDANTES, pinces à faisceau double ; pic du câble
de garde et feu de balisage rouge (lueur de jour). Direction 0 (consoles est-ouest) ; la tête tournera en phase 3 (4 directions).
"""
import math

import commun as K
import geo as G
import outils as O

TAU = G.TAU
PALETTE = "pylone"            # commun.PALETTES ; « calcul » = palette des états clés du 3/11
D = K.D
BASE = (0.72, 0.72 * D)       # demi-côtés au pied (x, y)
VAR = {
    "a": dict(taille=4.6, haut=6.6, consoles=[(4.95, 1.7), (5.95, 1.15)], tete="pic"),
    "b": dict(taille=4.0, haut=7.2, consoles=[(4.3, 1.25), (5.25, 1.7), (6.2, 1.1)], tete="pic"),
    "c": dict(taille=3.9, haut=5.6, consoles=[], tete="chat"),
}
TAILLE = (0.22, 0.22 * D)


def demi(z, taille):
    if z >= taille:
        return TAILLE
    t = z / taille
    return (BASE[0] + (TAILLE[0] - BASE[0]) * t, BASE[1] + (TAILLE[1] - BASE[1]) * t)


def coins(z, taille):
    hx, hy = demi(z, taille)
    return [(-hx, -hy, z), (hx, -hy, z), (hx, hy, z), (-hx, hy, z)]


def fut(lot, M, taille, haut):
    niv = [0.2, 0.85, 1.5, 2.1, 2.65, 3.15, 3.6] + [z for z in (4.0, 4.3, 4.6, 5.0, 5.4, 5.8, 6.2, 6.6, 7.0) if z <= haut]
    niv = sorted(set([z for z in niv if z < taille] + [taille] + [z for z in niv if z > taille]))
    for k in range(4):
        pts = [coins(z, taille)[k] for z in niv]
        lot.put(M["acier_clair"], G.tube(pts, 0.032, 5))
    for i, z in enumerate(niv):
        c = coins(z, taille)
        lot.put(M["acier_clair"], G.tube(c + [c[0]], 0.016, 4))
        if i + 1 < len(niv):
            c2 = coins(niv[i + 1], taille)
            for k in range(4):
                a, b = c[k], c[(k + 1) % 4]
                a2, b2 = c2[k], c2[(k + 1) % 4]
                lot.put(M["acier_clair"], G.tube([a, b2], 0.011, 4))
                lot.put(M["acier_clair"], G.tube([b, a2], 0.011, 4))
    # massifs de béton et cornières d'ancrage
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        K.caisson(lot, M["beton"], sx * BASE[0], sy * BASE[1], 0.0, 0.3, 0.36, 0.2, 0.03)
        lot.put(M["acier2"], G.boite((sx * BASE[0], sy * BASE[1], 0.215), (0.12, 0.14, 0.03)))
    # dispositif anti-escalade (piques) et plaque danger au sud
    z = 1.5
    c = coins(z, taille)
    for k in range(4):
        a, b = c[k], c[(k + 1) % 4]
        out = G.norm(G.sub(G.lerp(a, b, 0.5), (0.0, 0.0, z)))
        for j in range(7):
            p = G.lerp(a, b, j / 6.0)
            lot.put(M["acier2"], G.tube([p, G.add(p, G.add(G.mul(out, 0.13), (0, 0, 0.05)))], 0.006, 3))
    hx, hy = demi(1.05, taille)
    lot.put(M["jaune"], G.boite((0.0, -hy - 0.01, 1.05), (0.26, 0.012, 0.26), math.pi / 4 * 0, 0.0, 0.0))
    eclair = [(-0.03, 0.09), (0.03, 0.01), (-0.01, 0.0), (0.04, -0.09), (-0.03, -0.01), (0.0, 0.0)]
    lot.put(M["noir"], G.tube([(p[0], -hy - 0.02, 1.05 + p[1]) for p in eclair], 0.008, 3))
    # échelons de grimpe sur un pied
    for k in range(18):
        zz = 0.3 + k * 0.22
        p = coins(zz, taille)[0]
        lot.put(M["acier2"], G.tube([p, G.add(p, (-0.07, -0.02, 0.0))], 0.007, 3))


def chaine(lot, M, p, L=0.78, n=11, double=True):
    """Chaîne d'isolateurs pendante (disques de verre), pinces et faisceau double de conducteurs."""
    lot.put(M["acier2"], G.tube([p, G.add(p, (0, 0, -0.08))], 0.012, 4))
    for i in range(n):
        z = p[2] - 0.1 - i * (L - 0.16) / (n - 1)
        lot.put(M["verre"], G.tour([(z - 0.012, 0.03), (z - 0.004, 0.068), (z + 0.006, 0.062), (z + 0.014, 0.022)], 14, "z", (p[0], p[1], 0.0), cap0=True, cap1=True))
        lot.put(M["acier2"], G.tour([(z + 0.014, 0.018), (z + 0.03, 0.016)], 8, "z", (p[0], p[1], 0.0)))
    zb = p[2] - L
    O.anneau(lot, M["acier_clair"], (p[0], p[1], zb + 0.08), 0.1, 0.008, 18, 4, n=(0.0, 1.0, 0.0))
    lot.put(M["acier2"], G.tube([(p[0], p[1], zb + 0.06), (p[0], p[1], zb)], 0.012, 4))
    if double:
        lot.put(M["acier2"], G.boite((p[0], p[1], zb - 0.01), (0.26, 0.04, 0.03)))
        for s in (-1, 1):
            q = (p[0] + s * 0.12, p[1], zb - 0.03)
            lot.put(M["fonte"], G.boite(q, (0.04, 0.08, 0.04)))
            lot.put(M["alu"], G.tube([G.add(q, (0, -0.3, -0.01)), G.add(q, (0, 0.3, -0.01))], 0.016, 6))
    return (p[0], p[1], zb - 0.03)


def console(lot, M, z, L):
    """Console en treillis de -L à L, triangulée vers le fût."""
    O.treillis(lot, M["acier_clair"], (-L, 0.0, z), (L, 0.0, z), l=0.28, h=0.16, n=int(L * 7), rc=0.018, rd=0.008)
    hx, hy = TAILLE
    for s in (-1, 1):
        for t in (-1, 1):
            lot.put(M["acier_clair"], G.tube([(s * L, 0.0, z + 0.08), (s * hx, t * hy, z + 0.55)], 0.014, 4))
    pts = []
    for s in (-1, 1):
        pts.append(chaine(lot, M, (s * (L - 0.05), 0.0, z - 0.08)))
    return pts


def tete_chat(lot, M, taille, haut):
    """Tête de chat : deux bras divergents, poutre haute, 3 phases en V, 2 pics de garde."""
    hx, hy = TAILLE
    zb = taille
    for s in (-1, 1):
        for t in (-1, 1):
            lot.put(M["acier_clair"], G.tube([(s * hx, t * hy, zb), (s * 1.25, t * 0.2, haut - 0.4), (s * 1.55, t * 0.2, haut)], 0.028, 5))
            lot.put(M["acier_clair"], G.tube([(s * hx, t * hy, zb), (s * 0.45, t * 0.2, haut)], 0.022, 5))
        for k in range(4):
            za = zb + k * (haut - zb) / 4
            x0 = hx + (1.25 - hx) * k / 4
            lot.put(M["acier_clair"], G.tube([(s * x0, -0.2, za), (s * x0, 0.2, za)], 0.01, 4))
    O.treillis(lot, M["acier_clair"], (-1.75, 0.0, haut), (1.75, 0.0, haut), l=0.36, h=0.2, n=22, rc=0.02, rd=0.009)
    pts = []
    for x in (-1.45, 0.0, 1.45):
        top = (x, 0.0, haut - 0.08)
        bot = (x, 0.0, haut - 0.95)
        for d in (-0.32, 0.32):
            a = (x + d, 0.0, haut - 0.08)
            m = G.lerp(a, bot, 0.5)
            lot.put(M["acier2"], G.tube([a, bot], 0.01, 4))
            for i in range(9):
                p = G.lerp(a, bot, 0.08 + i * 0.1)
                lot.put(M["verre"], G.oriente(G.tour([(-0.012, 0.028), (-0.003, 0.062), (0.007, 0.056), (0.014, 0.02)], 12, "z", cap0=True, cap1=True), p, G.sub(bot, a)))
        lot.put(M["acier2"], G.boite(bot, (0.26, 0.04, 0.03)))
        for s in (-1, 1):
            lot.put(M["alu"], G.tube([(x + s * 0.12, -0.3, bot[2] - 0.03), (x + s * 0.12, 0.3, bot[2] - 0.03)], 0.016, 6))
        pts.append(bot)
    for s in (-1, 1):
        K.rev(lot, M["acier_clair"], s * 1.6, 0.0, [(haut + 0.1, 0.08), (haut + 0.55, 0.02)], 4)
        lot.put(M["feu_rouge"], G.sphere((s * 1.6, 0.0, haut + 0.62), 0.07, 12, 6))
    return pts


def build(S, lot, v):
    M = K.matieres(S, PALETTE)
    v = VAR[v]
    fut(lot, M, v["taille"], v["haut"] if v["tete"] == "pic" else v["taille"])
    if v["tete"] == "pic":
        pts = []
        for (z, L) in v["consoles"]:
            pts += console(lot, M, z, L)
        # pic du câble de garde, feu de balisage
        h = v["haut"]
        c = coins(h, v["taille"])
        for k in range(4):
            lot.put(M["acier_clair"], G.tube([c[k], (0.0, 0.0, h + 0.85)], 0.022, 5))
        lot.put(M["acier_clair"], G.tube([(0.0, -0.25, h + 0.82), (0.0, 0.25, h + 0.82)], 0.014, 4))
        K.rev(lot, M["fonte"], 0.0, 0.0, [(h + 0.85, 0.05), (h + 0.92, 0.05)], 12)
        lot.put(M["feu_rouge"], G.sphere((0.0, 0.0, h + 1.0), 0.08, 14, 7))
        for s in (-1, 1):
            lot.put(M["feu_rouge"], G.sphere((s * (v["consoles"][0][1] - 0.02), 0.0, v["consoles"][0][0] + 0.12), 0.05, 10, 5))
    else:
        pts = tete_chat(lot, M, v["taille"], v["haut"])
    return {"fils": pts}
