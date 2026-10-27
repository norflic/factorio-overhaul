"""Foreuse · Âge 10 · Haute technologie (ère IV, 6×6, niveaux 19 et 20). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « portique, colonne lisse, bras articulés ». Un PORTIQUE en croix (deux poutres caissons ivoire croisées au
sommet, 4 pieds carénés posés à mi-côté) porte une COLONNE LISSE ivoire à bagues anthracite qui descend dans le puits ;
deux BRAS ARTICULÉS anthracite (3 segments, rotules, pinces) manipulent les tiges sur le tablier ; voyants bleus, nappes
de câbles rouge et bleu. Palette (ages.PALETTE[10]) : ivoire chaud / anthracite / câbles rouge et bleu ; voyants bleus.
"""
import math

import ages
import corps as cp

EPOQUE = 10
NOM = ages.NOMS[10]
TRIPLET = ("portique", "colonne lisse", "bras articulés")
FOYER = ages.FOYER[10]
HABILLAGE = dict(ages.CORPS[10])
PAS_FIN = 0.12  # ronde F4-A3 : détail fin plus serré
FIN = 1.0
LAMPES = 0.26   # ronde F4-A3 : plus de voyants (détail fin et nuit)
PIED = 1.0
MOTIF_DALLE = True   # ronde F4-A4 : motif fin sur chaque dalle ivoire (corps.tablier)
# ronde F4-A2 : la tête carénée est l'embase ; les pieds du portique tiennent les diagonales ; 2 conduites
EMBASE = dict(r=0.0, contreforts=0, haubans=0, conduites=2)


def occupe(c):
    """Bras articulés (avec leur portée), râtelier, armoire de commande."""
    a = c.a
    return [(-0.62 * a - 0.3, -0.38 * a - 0.3, -0.62 * a + 1.15, -0.38 * a + 0.45),
            (0.66 * a - 1.15, 0.32 * a - 0.3, 0.66 * a + 0.3, 0.32 * a + 0.45),
            (-0.8 * a - 0.35, -0.72 * a - 0.1, -0.5 * a + 0.35, -0.72 * a + 0.1),
            (0.2 * a, -0.82 * a, 0.55 * a, -0.68 * a)]


def matieres(metal, M):
    ages.matieres(10, metal, M)


def _bras(g, c, x, y, sens, M):
    zt = c.zt
    cp.colonne(g, x, y, zt, zt + 0.22, 0.24, M["anthracite"], n=16, what="embase_bras")
    j1 = (x, y, zt + 0.75)
    j2 = (x + sens * 0.6, y + 0.3, zt + 1.25)
    j3 = (x + sens * 1.05, y + 0.05, zt + 0.7)
    cp.poutre(g, (x, y, zt + 0.22), j1, 0.17, M["anthracite"], "segment")
    cp.poutre(g, j1, j2, 0.15, M["blanc_casse"], "segment")
    cp.poutre(g, j2, j3, 0.11, M["anthracite"], "segment")
    for j in (j1, j2):
        g.sphere(j, 0.12, M["gris_tech"], n=12, m=6, what="rotule")
    for s in (-1, 1):
        cp.poutre(g, j3, (j3[0] + s * 0.06, j3[1], j3[2] - 0.16), 0.03, M["acier_tech"], "pince")
    g.sphere((j2[0], j2[1] - 0.05, j2[2] + 0.06), 0.025, M["emit"], n=8, m=4, what="voyant")
    g.cable((x, y - 0.1, zt + 0.1), (j1[0], j1[1] - 0.08, j1[2]), 0.03, 0.018, M["cable_r"])


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    # ronde 1 : portique plus bas et plus court (la poutre arrière dépassait le tablier comme un lampadaire), colonne
    # lisse épaisse (elle se lisait comme un fil), tête de forage carénée au pied
    zp = zt + 0.62 * H
    L = rt * 1.12
    # 4 pieds carénés sur les DIAGONALES (ronde 1 : à mi-côté, le pied arrière dépassait le tablier de 0,6 t à l'écran)
    q = L * 0.7071
    for k in range(4):
        x, y = cp.quart((q, q), k)[:2]
        g.box((x, y, zt + 0.06), (0.36, 0.36, 0.12), M["anthracite"], "hard", what="patin")
        cp.poutre(g, (x, y, zt + 0.1), (x * 0.96, y * 0.96, zp), 0.22, M["blanc_casse"], "pied", h=0.22)
        cp.bague(g, x * 0.98, y * 0.98, zt + 0.5, 0.13, 0.06, M["anthracite"], ep=0.02, n=4, what="bande")
        g.sphere((x, y - 0.125, zt + 0.9), 0.035, M["emit"], n=8, m=4, what="voyant")
    # deux poutres caissons croisées en X
    qb = (L + 0.1) * 0.7071
    for k in range(2):
        a, b = cp.quart((-qb, -qb, zp + 0.12), k), cp.quart((qb, qb, zp + 0.12), k)
        cp.poutre(g, a, b, 0.36, M["blanc_casse"], "caisson", h=0.28)
        for t in (0.2, 0.4, 0.6, 0.8):
            p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, zp + 0.265)
            g.box(p, (0.08, 0.08, 0.008), M["gris_tech"], "flat", what="trappe")
    # nappes de câbles rouge et bleu le long d'une poutre
    for dz, mat_ in ((0.0, "cable_r"), (0.07, "cable_b")):
        g.tube([(-q + 0.1, -q - 0.1, zp - 0.06 + dz), (0.1, -0.1, zp - 0.12 + dz), (q + 0.1, q - 0.1, zp - 0.06 + dz)],
               0.03, M[mat_], n=8, what="nappe")
    # tête de forage carénée au pied, colonne lisse épaisse, moyeu, mât
    cp.colonne(g, 0, 0, zt, zt + 0.42, rt * 0.62, M["anthracite"], n=8, phase=math.pi / 8, style="hard", what="tete")
    cp.colonne(g, 0, 0, zt + 0.42, zt + 0.52, rt * 0.55, M["blanc_casse"], n=8, phase=math.pi / 8, style="hard",
               what="capot_tete")
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        g.box((rt * 0.6 * math.cos(a), rt * 0.6 * math.sin(a), zt + 0.3), (0.07, 0.07, 0.03), M["emit"], "flat",
              what="voyant_tete")
    rc = rt * 0.3
    cp.colonne(g, 0, 0, zt + 0.52, zp - 0.05, rc, M["blanc_casse"], n=32, what="colonne")
    for i in range(3):
        z = zt + 0.75 + (zp - zt - 1.0) * i / 2.0
        cp.bague(g, 0, 0, z, rc, 0.06, M["anthracite"], ep=0.025, n=32, what="bague")
        cp.bague(g, 0, 0, z + 0.07, rc, 0.02, M["emit"], ep=0.01, n=32, what="led")
    cp.colonne(g, 0, 0, zp - 0.05, zp + 0.42, rc * 1.35, M["anthracite"], n=24, what="moyeu")
    cp.colonne(g, 0, 0, zp + 0.42, H - 0.2, 0.14, M["gris_tech"], n=16, what="mat")
    g.sphere((0, 0, H - 0.2), 0.2, M["blanc_casse"], n=20, m=10, scale=(1, 1, 0.6), what="capteur")
    cp.colonne(g, 0, 0, H - 0.1, H, 0.06, M["anthracite"], n=10, what="sommet")
    cp.halo(g, (0, -0.5, zt + 0.8), M, 4.0)


def trepan(g, c):
    return None


def socle(g, c):
    M = g.M
    a = c.a
    _bras(g, c, -a * 0.62, -a * 0.38, 1, M)
    _bras(g, c, a * 0.66, a * 0.32, -1, M)
    # râtelier de tiges ivoire à l'avant gauche du bras
    for i in range(4):
        g.cyl((-a * 0.8 + 0.1 * i, -a * 0.72, c.zt + 0.08), "x", 0.045, 0.6, M["acier_tech"], n=10, what="tige")
    # armoire de commande (écran bleu)
    cp.dalle(g, a * 0.2, -a * 0.82, a * 0.55, -a * 0.68, c.zt, c.zt + 0.5, M["anthracite"], what="armoire")
    g.box((a * 0.375, -a * 0.82 - 0.005, c.zt + 0.33), (0.25, 0.01, 0.14), M["emit"], "flat", what="ecran")


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r, M["gris_tech"], fl_mat=M["anthracite"], bolt_mat=None, what="raccord")
    g.tube(g.spline([(p[0], p[1] + 0.12, p[2] - 0.02) for p in pts], 6), r * 0.35, M["cable_b"], n=6, what="cable")


def piece(g, c):
    """Radôme ivoire sur mât court, couronne de voyants bleus."""
    M = g.M
    z = c.H
    cp.colonne(g, 0, 0, z, z + 0.14, 0.06, M["anthracite"], n=12, what="mat")
    g.sphere((0, 0, z + 0.3), 0.2, M["blanc_casse"], n=24, m=12, scale=(1, 1, 0.8), what="radome")
    cp.bague(g, 0, 0, z + 0.2, 0.19, 0.03, M["anthracite"], ep=0.02, n=24, what="joint")
    # ronde F4-A3 : collier plein sous le joint (deux jours de 18 px entre le radôme et la bague en ronde A2)
    cp.colonne(g, 0, 0, z + 0.12, z + 0.215, 0.185, M["anthracite"], n=24, what="collier")
    for k in range(8):
        a = math.tau * k / 8
        g.sphere((0.2 * math.cos(a), 0.2 * math.sin(a), z + 0.2), 0.022, M["emit"], n=8, m=4, what="voyant")
    cp.halo(g, (0, -0.25, z + 0.25), M, 3.0)
