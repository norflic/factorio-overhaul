"""Époque 1 · Pionnier (ère I, 2×2, niveaux 1 et 2). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 1) : « sacs, bois, bricolé ».
Le niveau 1 est la mitrailleuse VANILLA, jamais retouchée ; ce module ne fournit que la pièce du niveau 2
(variante e01-piece, dessinée SOUS la mitrailleuse vanilla), foyers de NUIT seulement (lanterne).
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, parts4.py ; outil de portage, code d'origine mot pour mot).
"""
import math

from mathutils import Matrix, Vector

import corps
import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from corps import Y, at
from kit import SQ2, TAU, axv, basis

V = Vector

EPOQUE = 1
NOM = "Pionnier"
FOYER = dict(rgb=(1.0, 0.69, 0.376), nuit=True)


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


def piece(g, c):
    """Niveau 2 (époque 1, Pionnier) : arc de sacs de sable sur les coins avant et les flancs du vanilla (dépasse de
    0,10 sur les côtés et de 0,15 sous l'emprise), caisse en bois cerclée de fer ouverte au coin avant gauche, bandes
    de cartouches qui pendent, lanterne de nuit."""
    M = g.M
    # plancher de planches cloutées sous l'emprise : cette couche est dessinée SOUS la mitrailleuse vanilla (le
    # vanilla la recouvre), elle ferme les jours entre le pied vanilla et le muret (trous enfermés : 61 px hr sinon)
    F.deck_e(g, 2, -1.04, 1.04, Y(-1.08), Y(0.62), 0.05)
    for sx in (-1, 1):
        pts = [(sx * 1.08, Y(0.25), 0.0), (sx * 1.08, Y(-0.45), 0.0), (sx * 1.0, Y(-0.88), 0.0),
               (sx * 0.72, Y(-1.13), 0.0), (sx * 0.4, Y(-1.15), 0.0)]
        sandbag_wall(g, pts, rows=2)
    with at(g, -0.68, -0.86, 0.25):
        wood_crate(g, (0, 0, 0.0), (0.3, 0.24, 0.17))
    F.lantern(g, (0.78, Y(-0.95), 0.15), M["emit"])
    g.box((0.78, Y(-0.95), 0.07), (0.1, 0.1, 0.15), M["wood"], "hard", what="billot")
    _halo(g, [(0.78, Y(-0.95), 0.3)], 6.0)


def sandbag(g, c, rz, L=0.26, w=0.13, h=0.08, mat=None):
    """Sac de sable : coussin aplati à plis (coutures, coins pincés)."""
    M = g.M
    m = mat or M["canvas"]
    g.push(c, rz=rz)
    n, mseg = 14, 7
    vs = []
    for i in range(mseg + 1):
        t = -1 + 2 * i / mseg
        for j in range(n):
            a = TAU * j / n
            sx = math.cos(a)
            sz = math.sin(a)
            k = (1 - 0.35 * abs(t) ** 3)
            vs.append((t * L / 2 * (1 - 0.08 * abs(sz)), sx * w / 2 * k, h / 2 + sz * h / 2 * k * (0.9 + 0.1 * math.cos(9 * t))))
    fs = []
    for i in range(mseg):
        for j in range(n):
            j2 = (j + 1) % n
            fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
    fs.append(tuple(range(n))[::-1])
    fs.append(tuple(range(mseg * n, (mseg + 1) * n)))
    g._add(m, "smooth", vs, fs, "sac")
    g.box((L * 0.47, 0, h * 0.55), (0.02, w * 0.5, h * 0.4), M["canvas2"], "soft", what="ligature")
    g.pop()


def sandbag_wall(g, pts, rows=2, L=0.26, w=0.13, h=0.075):
    """Muret de sacs de sable le long d'une polyligne (sol), rangs décalés."""
    M = g.M
    P = F.polyline_pts(pts)
    k = 0
    for row in range(rows):
        for i in range(len(P) - 1):
            a, b = P[i], P[i + 1]
            d = b - a
            n = max(1, int(round(d.length / (L * 0.92))))
            ang = math.atan2(d.y, d.x)
            for s in range(n):
                t = (s + 0.5 + 0.5 * (row % 2)) / (n + 0.5 * (row % 2))
                if t > 1.0:
                    continue
                p = a + d * t
                inset = row * 0.02
                nrm = V((-d.y, d.x, 0)).normalized()
                p = p + nrm * inset
                k += 1
                sandbag(g, (p.x, p.y, row * h * 0.86), ang + 0.08 * ((k * 7) % 3 - 1), L, w, h,
                        M["canvas"] if (k % 3) else M["canvas2"])


def wood_crate(g, c, size, rz=0.0, open_=True, belts=True):
    """Caisse de munitions en bois cerclée de fer, ouverte, bandes de cartouches laiton qui pendent."""
    M = g.M
    sx, sy, sz = size
    g.push(c, rz=rz)
    n = max(2, int(sz / 0.05))
    for side in ((0, -sy / 2, sx, 0.025), (0, sy / 2, sx, 0.025)):
        for k in range(n):
            g.box((side[0], side[1], sz * (k + 0.5) / n), (side[2], side[3], sz / n - 0.006),
                  M["wood"] if k % 2 else M["wood2"], "hard", what="planche")
    for xx in (-sx / 2, sx / 2):
        for k in range(n):
            g.box((xx, 0, sz * (k + 0.5) / n), (0.025, sy, sz / n - 0.006), M["wood"] if k % 2 else M["wood2"], "hard",
                  what="planche")
    g.box((0, 0, sz * 0.45), (sx - 0.04, sy - 0.04, sz * 0.9), M["seam"], "flat", what="fond")
    for zz in (0.03, sz - 0.03):
        for (cx, cy, w_, d_) in ((0, -sy / 2 - 0.014, sx + 0.03, 0.012), (0, sy / 2 + 0.014, sx + 0.03, 0.012),
                                 (-sx / 2 - 0.014, 0, 0.012, sy + 0.03), (sx / 2 + 0.014, 0, 0.012, sy + 0.03)):
            g.box((cx, cy, zz), (w_, d_, 0.025), M["rawiron"], "hard", what="cerclage")
    for (cx, cy) in ((-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)):
        g.box((cx, cy, sz / 2), (0.035, 0.035, sz + 0.01), M["rawiron"], "hard", what="cornière")
        g.dome((cx, cy - 0.02 if cy < 0 else cy + 0.02, sz * 0.5), (0, -1 if cy < 0 else 1, 0), 0.012, M["rivet"])
    if open_:
        nx = max(1, int((sx - 0.06) / 0.05))
        ny = max(1, int((sy - 0.06) / 0.05))
        for i in range(nx):
            for j in range(ny):
                x = -(nx - 1) * 0.025 + i * 0.05
                y = -(ny - 1) * 0.025 + j * 0.05
                g.cyl((x, y, sz - 0.02), "z", 0.016, 0.04, M["brass"], n=8, what="etui")
                g.cyl((x, y, sz + 0.012), "z", 0.012, 0.024, M["copper"], n=8, r2=0.004, what="balle")
        g.box((0, sy / 2 + 0.03, sz + 0.09), (sx * 0.96, 0.025, 0.2), M["wood"], "hard",
              R=Matrix.Rotation(-0.3, 3, "X"), what="couvercle")
    if belts:
        PT.belt(g, [(-sx * 0.3, -sy / 2 + 0.02, sz + 0.02), (-sx * 0.32, -sy / 2 - 0.05, sz * 0.6),
                    (-sx * 0.2, -sy / 2 - 0.1, 0.03)], scale=0.6)
    g.pop()
