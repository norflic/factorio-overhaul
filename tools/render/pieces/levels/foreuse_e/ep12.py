"""Foreuse · Âge 12 · Supraconducteurs (ère IV, 6×6, niveaux 23 et 24). Lot F4-A (25/10). S'exécute DANS Blender.

En 3 mots : « pile de tores, cryostat, glace cyan ». Un CRYOSTAT (cuve givrée blanche cerclée de chrome, quatre conduites
de mousse) porte une PILE DE TORES chromés de plus en plus petits, séparés par des entretoises et par une fente de lumière
cyan (la lévitation fermée : aucun vide, rien ne flotte) ; le trépan noir miroir traverse la pile ; plaques de givre et
GLACE CYAN sur le tablier noir miroir. Palette (ages.PALETTE[12]) : blanc glacé teinté cyan / noir miroir et chrome / cyan.
"""
import math

import ages
import corps as cp

EPOQUE = 12
NOM = ages.NOMS[12]
TRIPLET = ("pile de tores", "cryostat", "glace cyan")
FOYER = ages.FOYER[12]
HABILLAGE = dict(ages.CORPS[12], forme_tablier="octogone")
PIED = 1.05
# ronde F4-A2 (un seul corps) : embase chromée, 4 contreforts givrés sur les diagonales
EMBASE = dict(r=1.05, contreforts=4, cphase=45.0, hc=0.24, rin=0.88, haubans=0, conduites=0)


def occupe(c):
    """Bouts des conduites de mousse, givre et glace."""
    a, rt = c.a, c.rt
    out = []
    for k in range(4):
        x, y = cp.quart((rt * 1.3, -rt * 0.55), k)[:2]
        out.append((x - 0.25, y - 0.25, x + 0.25, y + 0.25))
    for (x, y, r) in ((-a * 0.62, -a * 0.55, 0.32), (a * 0.2, a * 0.7, 0.24), (-a * 0.7, a * 0.35, 0.2)):
        out.append((x - r, y - r, x + r, y + r))
    return out


def matieres(metal, M):
    ages.matieres(12, metal, M)


def tour(g, c):
    M = g.M
    rt, zt, H = c.rt, c.zt, c.H
    # cryostat : cuve givrée à 8 pans, cerclée de chrome
    zc = zt + 0.26 * H
    g.cyl((0, 0, (zt + zc) / 2), "z", rt * 0.95, zc - zt, M["frost"], n=8, phase=math.pi / 8, style="hard",
          what="cryostat")
    for z in (zt + 0.08, zc - 0.06):
        g.tube_shell((0, 0, z), "z", rt * 0.99, rt * 0.9, 0.06, M["chrome_mat"], n=8, what="cerclage")
    # ronde F4-A3 : deux voyants cyan par pan du cryostat
    for k in range(8):
        a = math.tau * k / 8
        for dz in (0.35, 0.65):
            g.dome((rt * 0.955 * math.cos(a), rt * 0.955 * math.sin(a), zt + (zc - zt) * dz), (math.cos(a), math.sin(a), 0),
                   0.03, M["emit"], what="voyant")
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        g.box((rt * 0.88 * math.cos(a), rt * 0.88 * math.sin(a), (zt + zc) / 2), (0.06, 0.06, zc - zt), M["trim"],
              "hard", R=None, what="arete")
    # pile de tores : 5 tores qui rétrécissent, fentes cyan, entretoises chromées
    z = zc
    R = rt * 0.78
    for i in range(5):
        r = 0.10 + 0.02 * (4 - i)
        g.torus((0, 0, z + r), "z", R, r, M["chrome_mat"], n=40, m=12, what="tore")
        g.torus((0, 0, z + r), "z", R - r * 0.6, r * 0.45, M["emit"], n=40, m=8, what="lueur")
        for k in range(4):
            x, y = cp.quart((R * 0.55, 0.0), k)[:2]
            cp.colonne(g, x, y, z, z + 2 * r + 0.05, 0.035, M["jacket"], n=8, what="entretoise")
        z += 2 * r + 0.05
        R *= 0.8
    # âme noir miroir (remplit le centre de la pile : aucun jour)
    cp.colonne(g, 0, 0, zc, z, rt * 0.36, M["noir_miroir"], n=24, what="ame")
    cp.colonne(g, 0, 0, z, H, 0.12, M["chrome_mat"], n=16, what="sommet")
    # 4 conduites de mousse (cryogénie) du cryostat au tablier
    for k in range(4):
        p0 = cp.quart((rt * 0.95, -rt * 0.35, zt + 0.18 * H), k)
        p1 = cp.quart((rt * 1.3, -rt * 0.55, zt + 0.08), k)
        pm = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, p0[2] + 0.05)
        g.hose([p0, pm, p1], 0.06, M["frost"])
        # ronde F4-A3 : colliers chromés le long de la conduite
        for (qa, qb) in ((p0, pm), (pm, p1)):
            for f in (0.3, 0.7):
                q = (qa[0] + (qb[0] - qa[0]) * f, qa[1] + (qb[1] - qa[1]) * f, qa[2] + (qb[2] - qa[2]) * f)
                g.cyl(q, (qb[0] - qa[0], qb[1] - qa[1], qb[2] - qa[2] + 1e-4), 0.075, 0.035, M["chrome_mat"], n=12,
                      style="hard", what="collier")
    cp.halo(g, (0, -rt * 0.9, zc + 0.3), M, 5.0)


def trepan(g, c):
    M = g.M
    cp.colonne(g, 0, 0, c.zt, c.zt + 0.14, c.rw * 0.85, M["noir_miroir2"], n=24, what="bouchon")
    cp.bague(g, 0, 0, c.zt + 0.14, c.rw * 0.7, 0.03, M["emit"], ep=0.02, n=24, what="joint_cyan")


def socle(g, c):
    M = g.M
    a, zt = c.a, c.zt
    # plaques de givre et blocs de glace cyan
    for (x, y, r) in ((-a * 0.62, -a * 0.55, 0.32), (a * 0.2, a * 0.7, 0.24), (-a * 0.7, a * 0.35, 0.2)):
        g.cyl((x, y, zt + 0.01), "z", r, 0.02, M["frost"], n=10, style="flat", what="givre")
        g.box((x, y, zt + 0.12), (r * 0.7, r * 0.6, 0.2), M["emit_soft"], "hard", what="glace")
        g.box((x + r * 0.3, y - r * 0.2, zt + 0.08), (r * 0.4, r * 0.35, 0.12), M["frost"], "hard", what="glace2")


def liaison(g, pts, r):
    M = g.M
    g.hose(pts, r * 1.15, M["frost"])
    g.cyl(pts[0], (pts[1][0] - pts[0][0], pts[1][1] - pts[0][1], 0.0001), r * 1.6, 0.06, M["chrome_mat"], n=16,
          style="hard", what="bride")


def piece(g, c):
    """Petit tore chromé en lévitation sur trois tenons, cœur cyan."""
    M = g.M
    z = c.H
    for k in range(3):
        a = math.tau * k / 3
        cp.colonne(g, 0.1 * math.cos(a), 0.1 * math.sin(a), z, z + 0.18, 0.02, M["chrome_mat"], n=6, what="tenon")
    cp.colonne(g, 0, 0, z, z + 0.22, 0.06, M["noir_miroir"], n=12, what="axe")
    g.torus((0, 0, z + 0.22), "z", 0.2, 0.05, M["chrome_mat"], n=32, m=10, what="tore")
    cp.colonne(g, 0, 0, z + 0.2, z + 0.24, 0.17, M["noir_miroir"], n=32, what="voile")   # ferme le tore (ronde 1)
    g.torus((0, 0, z + 0.22), "z", 0.15, 0.025, M["emit"], n=32, m=8, what="lueur")
    g.sphere((0, 0, z + 0.3), 0.08, M["emit"], n=16, m=8, what="coeur")
    cp.halo(g, (0, -0.2, z + 0.25), M, 3.0)
