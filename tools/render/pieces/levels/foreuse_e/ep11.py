"""Foreuse · Âge 11 · Titane (ère IV, 6×6, niveaux 21 et 22). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « tripode, ailerons, balises orange ». Un TRIPODE de titane bleu (trois jambes effilées en profil d'aile,
pieds à rotule) se rejoint au sommet sur un moyeu rond ; chaque jambe porte un AILERON blanc bleuté ; trois BALISES
ORANGE aéronautiques marquent les pieds ; au centre, une tige fuselée descend dans le puits par un manchon à ailettes.
Palette (ages.PALETTE[11]) : bleu titane / alliage blanc bleuté et bleu nuit / orange aéronautique ; lumière bleu-blanc.
"""
import math

import ages
import corps as cp

EPOQUE = 11
NOM = ages.NOMS[11]
TRIPLET = ("tripode", "ailerons", "balises orange")
FOYER = ages.FOYER[11]
HABILLAGE = dict(ages.CORPS[11])


def matieres(metal, M):
    ages.matieres(11, metal, M)


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    zm = H - 0.30
    R = rt * 1.55
    for k in range(3):
        a = math.radians(30 + 120 * k)             # jambes à 30°, 150° et 270° : aucune le long de la goulotte (nord)
        ca, sa = math.cos(a), math.sin(a)
        p0 = (R * ca, R * sa, zt + 0.12)
        p1 = (0.16 * ca, 0.16 * sa, zm)
        # jambe en profil d'aile : section aplatie, effilée vers le haut
        g.tube([p0, ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2), p1], 0.1, M["titane_cl"], n=10,
               radii=[0.12, 0.09, 0.06], what="jambe")
        # aileron (lame dans le plan de la jambe, vers l'extérieur)
        t0, t1 = 0.18, 0.55
        q0 = [p0[i] + (p1[i] - p0[i]) * t0 for i in range(3)]
        q1 = [p0[i] + (p1[i] - p0[i]) * t1 for i in range(3)]
        pts = [(q0[0], q0[1], q0[2]), (q1[0], q1[1], q1[2]), (q1[0] + 0.32 * ca, q1[1] + 0.32 * sa, q1[2] - 0.35),
               (q0[0] + 0.42 * ca, q0[1] + 0.42 * sa, q0[2] - 0.05)]
        cp.lame(g, pts, 0.025, M["ring"], "aileron")
        g.tube([pts[2], pts[3]], 0.014, M["orange_aero"], n=6, what="bord_aileron")
        # pied à rotule et balise orange
        g.sphere(p0, 0.13, M["titane_dk"], n=14, m=7, what="rotule")
        g.box((p0[0], p0[1], zt + 0.03), (0.34, 0.34, 0.06), M["bleu_nuit"], "hard", what="semelle")
        cp.colonne(g, p0[0] + 0.2 * ca, p0[1] + 0.2 * sa, zt, zt + 0.35, 0.035, M["titane_dk"], n=8, what="mat_balise")
        g.sphere((p0[0] + 0.2 * ca, p0[1] + 0.2 * sa, zt + 0.40), 0.065, M["orange_aero"], n=12, m=6, what="balise")
        g.cyl((p0[0] + 0.2 * ca, p0[1] + 0.2 * sa, zt + 0.40), "z", 0.07, 0.025, M["emit"], n=12, style="flat",
              what="feu")
        cp.halo(g, (p0[0] + 0.2 * ca, p0[1] + 0.2 * sa - 0.2, zt + 0.45), M, 2.5)
    # moyeu rond (sommet invariant)
    cp.colonne(g, 0, 0, zm - 0.18, zm + 0.12, 0.26, M["titane_md"], n=24, what="moyeu")
    cp.bague(g, 0, 0, zm - 0.04, 0.26, 0.04, M["orange_aero"], ep=0.015, n=24, what="bande")
    cp.colonne(g, 0, 0, zm + 0.12, H, 0.14, M["titane_cl"], n=20, r2=0.10, what="sommet")
    # ronde 1 : le tripode seul se lisait mince et plat ; il tient désormais un FUSELAGE de titane (la masse de la tour)
    # à 3 grands ailerons de queue, bandes orange, hublots bleu-blanc
    rf = rt * 0.30
    zf0, zf1 = zt + 0.30, zm - 0.45
    cp.colonne(g, 0, 0, zf0, zf1, rf, M["titane_cl"], n=32, what="fuselage")
    g.cyl((0, 0, zf1 + 0.2), "z", rf, 0.4, M["titane_md"], n=32, r2=0.17, what="ogive")
    for zz in (0.18, 0.62):
        cp.bague(g, 0, 0, zf0 + (zf1 - zf0) * zz, rf, 0.07, M["orange_aero"], ep=0.012, n=32, what="bande")
    for i in range(3):
        g.cyl((0, -rf - 0.004, zf0 + 0.35 + 0.3 * i), (0, -1, 0), 0.05, 0.012, M["emit"], n=12, style="flat",
              what="hublot")
    for k in range(3):
        a = math.radians(90 + 120 * k)
        ca, sa = math.cos(a), math.sin(a)
        cp.lame(g, [(rf * ca, rf * sa, zf0 + 0.02), (rf * 2.6 * ca, rf * 2.6 * sa, zf0 - 0.1),
                    (rf * 2.4 * ca, rf * 2.4 * sa, zf0 + 0.25), (rf * ca, rf * sa, zf0 + 0.95)], 0.05, M["ring"],
                "aileron_queue")
        g.tube([(rf * 2.6 * ca, rf * 2.6 * sa, zf0 - 0.1), (rf * 2.4 * ca, rf * 2.4 * sa, zf0 + 0.25)], 0.03,
               M["orange_aero"], n=6, what="bord")
    cp.colonne(g, 0, 0, zt, zf0, rf * 0.8, M["titane_dk"], n=24, what="tuyere")
    cp.halo(g, (0, -0.6, zt + 0.8), M, 3.0)


def trepan(g, c):
    """Manchon à 4 ailettes sur la margelle."""
    M = g.M
    zt, rw = c.zt, c.rw
    cp.colonne(g, 0, 0, zt, zt + 0.32, 0.2, M["titane_md"], n=20, r2=0.15, what="manchon")
    for k in range(4):
        x, y = cp.quart((0.17, 0.0), k)[:2]
        x2, y2 = cp.quart((rw * 0.95, 0.0), k)[:2]
        cp.lame(g, [(x, y, zt + 0.02), (x2, y2, zt + 0.02), (x2, y2, zt + 0.08), (x, y, zt + 0.30)], 0.02,
                M["orange_aero"], "ailette")


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r * 0.9, M["titane_cl"], fl_mat=M["titane_dk"], bolt_mat=M["rivet_ti"], what="raccord")


def piece(g, c):
    """Pointe aérodynamique à 4 ailettes, nez orange, feu bleu-blanc."""
    M = g.M
    z = c.H
    g.cyl((0, 0, z + 0.3), "z", 0.1, 0.6, M["titane_cl"], n=20, r2=0.03, what="pointe")
    g.cyl((0, 0, z + 0.66), "z", 0.035, 0.12, M["orange_aero"], n=12, r2=0.004, what="nez")
    for k in range(4):
        x, y = cp.quart((1.0, 0.0), k)[:2]
        cp.lame(g, [(x * 0.08, y * 0.08, z + 0.02), (x * 0.26, y * 0.26, z + 0.02), (x * 0.26, y * 0.26, z + 0.06),
                    (x * 0.08, y * 0.08, z + 0.32)], 0.02, M["orange_aero"], "ailette")
    cp.bague(g, 0, 0, z + 0.18, 0.08, 0.03, M["emit"], ep=0.012, n=16, what="feu")
    cp.halo(g, (0, -0.2, z + 0.2), M, 3.0)
