"""Foreuse · Âge 14 · La Porte (ère V, 6×6, niveaux 27 et 28). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « anneau vertical, horizon étoilé, piliers lunaires ». « Forer à travers la Porte » : deux ANNEAUX VERTICAUX
croisés (blanc lunaire, chevrons indigo) se dressent au-dessus du puits ; chacun est fermé par un HORIZON ÉTOILÉ (membrane
de l'horizon de la Porte semée de points d'étoile) : de face on lit un anneau plein d'étoiles, de profil une lame ; quatre
PILIERS LUNAIRES les tiennent par les flancs ; des étoiles sont semées sur le tablier indigo. Palette (ages.PALETTE[14]) :
indigo de nuit / blanc lunaire mat / blanc d'étoile ; ni or ni orange.
"""
import math

import ages
import corps as cp

EPOQUE = 14
NOM = ages.NOMS[14]
TRIPLET = ("anneau vertical", "horizon étoilé", "piliers lunaires")
FOYER = ages.FOYER[14]
HABILLAGE = dict(ages.CORPS[14], forme_tablier="rond")
LAMPES = 0.24   # ronde F4-A3 : plus de voyants (détail fin et nuit)
PIED = 1.12
# ronde F4-A2 : le dais et les piliers sont l'embase ; 2 conduites
EMBASE = dict(r=0.0, contreforts=0, haubans=0, conduites=2)
DENSITE = 0.7    # ronde F4-A3 : 0,3 → 0,7 (les étoiles semées ne suffisaient pas)
PAS_FIN = 0.12


def matieres(metal, M):
    ages.matieres(14, metal, M)


def _etoiles(g, M, pts):
    for (x, y, z, nx, ny, nz) in pts:
        g.dome((x, y, z), (nx, ny, nz), 0.022, M["emit"], n=6)


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    R, r = rt * 0.84, 0.10
    zr = H - R - r
    # dais circulaire à deux degrés
    cp.colonne(g, 0, 0, zt, zt + 0.14, rt * 0.95, M["indigo_nuit"], n=40, what="dais")
    cp.colonne(g, 0, 0, zt + 0.14, zt + 0.26, rt * 0.75, M["blanc_lunaire"], n=40, what="dais")
    cp.bague(g, 0, 0, zt + 0.14, rt * 0.95, 0.02, M["emit_soft"], ep=0.01, n=40, what="lisere")
    # ronde F4-A3 : inserts indigo et rivets sur le degré blanc du dais, points d'étoile sur le degré indigo
    for i in range(24):
        a = math.tau * (i + 0.5) / 24
        g.box((rt * 0.62 * math.cos(a), rt * 0.62 * math.sin(a), zt + 0.262), (0.07, 0.07, 0.008), M["indigo_nuit"],
              "flat", what="insert")
        g.dome((rt * 0.7 * math.cos(a + 0.13), rt * 0.7 * math.sin(a + 0.13), zt + 0.262), (0, 0, 1), 0.018,
               M["acier_bleui"], what="rivet")
    for (rr, nn) in ((0.24, 10), (0.38, 14), (0.5, 18)):
        for i in range(nn):
            a = math.tau * (i + 0.5 * (nn % 4)) / nn
            g.box((rt * rr * math.cos(a), rt * rr * math.sin(a), zt + 0.262), (0.05, 0.05, 0.008), M["indigo_nuit"],
                  "flat", what="insert")
    for i in range(40):
        a = math.tau * (i + 0.25) / 40
        g.dome((rt * 0.86 * math.cos(a), rt * 0.86 * math.sin(a), zt + 0.142), (0, 0, 1), 0.016, M["emit"], n=6)
    # pied central jusqu'au bas des anneaux (la tige y descend)
    cp.colonne(g, 0, 0, zt + 0.26, zr - R + 0.05, 0.26, M["indigo_nuit2"], n=16, what="pied")
    for k, axe in enumerate(("y", "x")):
        # anneau vertical, membrane d'horizon, chevrons
        g.torus((0, 0, zr), axe, R, r, M["blanc_lunaire"], n=48, m=10, what="anneau")
        g.cyl((0, 0, zr), axe, R - r * 0.4, 0.05, M["horizon_porte"], n=48, what="horizon")
        for i in range(24):     # ronde F4-A3 : 12 → 24 chevrons
            a = math.tau * i / 24
            u, w = R * math.cos(a), R * math.sin(a)
            p = (u, 0.0, zr + w) if axe == "y" else (0.0, u, zr + w)
            g.box(p, (0.07, 0.07, 0.07) if i % 2 else (0.09, 0.09, 0.09), M["indigo_nuit"], "hard", what="chevron")
        # étoiles semées sur les deux faces de la membrane
        rng = (7 + 13 * k)
        pts = []
        for i in range(64):     # ronde F4-A3 : 26 → 64 étoiles par face (détail fin, charte D3)
            rng = (rng * 1103515245 + 12345) % 2147483648
            a = math.tau * (rng % 1000) / 1000.0
            rr = (R - 0.2) * math.sqrt(((rng // 1000) % 1000) / 1000.0)
            u, w = rr * math.cos(a), rr * math.sin(a)
            for s in (-1, 1):
                if axe == "y":
                    pts.append((u, s * 0.03, zr + w, 0, s, 0))
                else:
                    pts.append((s * 0.03, u, zr + w, s, 0, 0))
        _etoiles(g, M, pts)
    # quatre piliers lunaires qui tiennent les anneaux par les flancs
    for (x, y) in cp.sym4((R + r + 0.14, 0.0)):
        cp.dalle(g, x - 0.13, y - 0.13, x + 0.13, y + 0.13, zt, zr + 0.12, M["blanc_lunaire"], what="pilier")
        cp.dalle(g, x - 0.16, y - 0.16, x + 0.16, y + 0.16, zt, zt + 0.2, M["indigo_nuit"], what="base_pilier")
        cp.dalle(g, x - 0.16, y - 0.16, x + 0.16, y + 0.16, zr + 0.12, zr + 0.22, M["indigo_nuit"], what="chapiteau")
        for zz in (0.35, 0.55, 0.75):
            g.box((x, y, zt + (zr - zt) * zz), (0.28, 0.28, 0.03), M["indigo_nuit2"], "hard", what="bande")
        cp.poutre(g, (x * 0.98, y * 0.98, zr), (x * 0.82, y * 0.82, zr), 0.08, M["acier_bleui"], "tenon")
        cp.halo(g, (x, y - 0.25, zr + 0.25), M, 1.5)
    cp.colonne(g, 0, 0, zr + R - 0.02, H, 0.10, M["blanc_lunaire"], n=12, what="sommet")
    cp.halo(g, (0, -0.6, zr), M, 4.0)


def trepan(g, c):
    return None


def socle(g, c):
    M = g.M
    a, zt = c.a, c.zt
    rng = 99
    for i in range(240):    # ronde F4-A3 : 46 → 240 étoiles semées
        rng = (rng * 1103515245 + 12345) % 2147483648
        x = (((rng >> 4) % 1000) / 1000.0 - 0.5) * 2 * (a - 0.3)
        y = (((rng >> 14) % 1000) / 1000.0 - 0.5) * 2 * (a - 0.3)
        if (abs(x) < c.rt and abs(y) < c.rt) or not cp.dans_tablier(c, x, y, 0.03):
            continue
        g.dome((x, y, zt + 0.003), (0, 0, 1), 0.018 + 0.01 * (i % 3), M["emit"], n=6)


def montant(g, c, x, y):
    """Petit obélisque lunaire à pointe d'étoile."""
    M = g.M
    w = c.T["montant"]["w"]
    h = c.T["montant"]["h"] + 0.25
    g.cyl((x, y, h / 2), "z", w * 0.6, h, M["blanc_lunaire"], n=4, r2=w * 0.35, phase=math.pi / 4, style="hard",
          what="obelisque")
    g.dome((x, y, h), (0, 0, 1), 0.04, M["emit"], n=6)


def liaison(g, pts, r):
    M = g.M
    g.pipe(pts, r, M["indigo_nuit2"], fl_mat=M["blanc_lunaire"], bolt_mat=M["blanc_lunaire"], what="raccord")


def piece(g, c):
    """Étoile à 4 branches (blanc d'étoile) sur un petit anneau couché."""
    M = g.M
    z = c.H
    g.torus((0, 0, z + 0.06), "z", 0.16, 0.04, M["blanc_lunaire"], n=32, m=8, what="anneau")
    cp.colonne(g, 0, 0, z + 0.04, z + 0.08, 0.14, M["indigo_nuit"], n=32, what="voile")   # ferme l'anneau (ronde 1)
    cp.colonne(g, 0, 0, z, z + 0.12, 0.08, M["indigo_nuit"], n=12, what="moyeu")
    for k in range(4):
        x, y = cp.quart((1.0, 0.0), k)[:2]
        cp.lame(g, [(0, 0, z + 0.14), (x * 0.26, y * 0.26, z + 0.30), (0, 0, z + 0.46), (-x * 0.02, -y * 0.02, z + 0.30)],
                0.03, M["emit"], "branche")
    cp.halo(g, (0, -0.2, z + 0.3), M, 3.0)
