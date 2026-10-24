"""Laser · Âge 1 · Pionnier (ère I, 2×2, niveaux 1 et 2). Kit laser_e (lot F1-A). S'exécute DANS Blender.

Le niveau 1 est le laser VANILLA, jamais retouché ; ce module ne fournit que la pièce du niveau 2 (variante e01-piece,
dessinée SOUS le laser vanilla), foyers de NUIT seulement (lanterne). En 3 mots : « sacs de sable, bocaux de Leyde,
caisse de bois » : un muret de sacs de sable devant le pied en ciseaux du vanilla, et au coin avant gauche une caisse
de bois cerclée de fer pleine de BOCAUX DE LEYDE (bouteilles de verre à feuille de cuivre, tige et boule de laiton) :
la réserve d'énergie bricolée du pionnier. Fiche : fo-logs/2026-10-24_F1/FICHES_LASER.md, âge 1.
Sacs de sable : même dessin que la mitrailleuse 1 (gun_e/ep01.py, recopié : une famille ne charge jamais les modules
d'une autre).
"""
import math

from mathutils import Vector

import ages
import formes as F
from kit import TAU
from repere import Y, at

V = Vector

EPOQUE = 1
NOM = ages.NOMS[1]
TRIPLET = ("sacs de sable", "bocaux de Leyde", "caisse de bois")
FOYER = ages.FOYER[1]
FAISCEAU = dict(rgb=(1.0, 0.25, 0.2), forme="vanilla (niveaux 1 et 2)", largeur=1.0)


def piece(g, c):
    """Niveau 2 : plancher de planches sous l'emprise (sous le vanilla), muret de sacs de sable en arc sur l'avant et
    les flancs, caisse de bocaux de Leyde au coin avant gauche, lanterne de nuit au coin avant droit."""
    M = g.M
    F.deck_e(g, 2, -1.04, 1.04, Y(-1.08), Y(0.62), 0.05)
    for sx in (-1, 1):
        pts = [(sx * 1.08, Y(0.3), 0.0), (sx * 1.08, Y(-0.4), 0.0), (sx * 1.0, Y(-0.85), 0.0),
               (sx * 0.75, Y(-1.12), 0.0), (sx * 0.42, Y(-1.15), 0.0)]
        sandbag_wall(g, pts, rows=2)
    with at(g, -0.66, -0.84, 0.2):
        caisse_leyde(g, (0, 0, 0.0), (0.34, 0.26, 0.15))
    F.lantern(g, (0.78, Y(-0.95), 0.15), M["emit"])
    g.box((0.78, Y(-0.95), 0.07), (0.1, 0.1, 0.15), M["wood"], "hard", what="billot")
    g.halo((0.78, Y(-0.95), 0.3), M["_emit_rgb"], 6.0)


def caisse_leyde(g, c, size, rz=0.0):
    """Caisse de bois cerclée de fer, ouverte, pleine de BOCAUX DE LEYDE (verre sombre, feuille de cuivre sur le bas,
    bouchon de bois, tige et boule de laiton), reliés par un fil de cuivre."""
    M = g.M
    sx, sy, sz = size
    g.push(c, rz=rz)
    n = max(2, int(sz / 0.05))
    for (cx, cy, w, d) in ((0, -sy / 2, sx, 0.025), (0, sy / 2, sx, 0.025), (-sx / 2, 0, 0.025, sy),
                           (sx / 2, 0, 0.025, sy)):
        for k in range(n):
            g.box((cx, cy, sz * (k + 0.5) / n), (w, d, sz / n - 0.006), M["wood"] if k % 2 else M["wood2"], "hard",
                  what="planche")
    g.box((0, 0, sz * 0.4), (sx - 0.04, sy - 0.04, sz * 0.8), M["seam"], "flat", what="fond")
    for zz in (0.03, sz - 0.03):
        for (cx, cy, w_, d_) in ((0, -sy / 2 - 0.014, sx + 0.03, 0.012), (0, sy / 2 + 0.014, sx + 0.03, 0.012),
                                 (-sx / 2 - 0.014, 0, 0.012, sy + 0.03), (sx / 2 + 0.014, 0, 0.012, sy + 0.03)):
            g.box((cx, cy, zz), (w_, d_, 0.025), M["rawiron"], "hard", what="cerclage")
    tops = []
    for i in range(3):
        for j in range(2):
            x = (i - 1) * sx * 0.3
            y = (j - 0.5) * sy * 0.45
            r, h = 0.045, 0.17
            g.cyl((x, y, sz * 0.4 + h / 2), "z", r, h, M["glass_dk"], n=14, style="smooth", what="bocal")
            g.cyl((x, y, sz * 0.4 + h * 0.3), "z", r + 0.004, h * 0.55, M["copper"], n=14, what="feuille")
            g.cyl((x, y, sz * 0.4 + h + 0.012), "z", r * 0.8, 0.024, M["wood2"], n=12, what="bouchon")
            g.cyl((x, y, sz * 0.4 + h + 0.05), "z", 0.006, 0.07, M["brass"], n=6, what="tige")
            g.sphere((x, y, sz * 0.4 + h + 0.09), 0.016, M["brass"], n=10, m=6, what="boule")
            tops.append(V((x, y, sz * 0.4 + h + 0.09)))
    for a, b in zip(tops[:-1], tops[1:]):
        g.cable(a, b, 0.02, 0.005, M["copper"], what="fil")
    g.pop()


def sandbag(g, c, rz, L=0.26, w=0.13, h=0.08, mat=None):
    """Sac de sable : coussin aplati à plis (recopié de gun_e/ep01.py)."""
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
            vs.append((t * L / 2 * (1 - 0.08 * abs(sz)), sx * w / 2 * k,
                       h / 2 + sz * h / 2 * k * (0.9 + 0.1 * math.cos(9 * t))))
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
    """Muret de sacs de sable le long d'une polyligne (sol), rangs décalés (recopié de gun_e/ep01.py)."""
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
                nrm = V((-d.y, d.x, 0)).normalized()
                p = p + nrm * row * 0.02
                k += 1
                sandbag(g, (p.x, p.y, row * h * 0.86), ang + 0.08 * ((k * 7) % 3 - 1), L, w, h,
                        M["canvas"] if (k % 3) else M["canvas2"])

