"""Laser · Âge 1 · Pionnier (ère I, 2×2, niveaux 1 et 2). Kit laser_e (lot F1-A). S'exécute DANS Blender.

Le niveau 1 est le laser VANILLA, jamais retouché ; ce module ne fournit que la pièce du niveau 2 (variante e01-piece,
dessinée SOUS le laser vanilla), foyers de NUIT seulement (lanterne). En 3 mots (corrigés, M-2, puis à la reprise) :
« tube ambré, plancher de bois, pied en ciseaux » (le tube ambré est la tête du vanilla) ; dessin : un muret de sacs de sable devant le pied en ciseaux du vanilla, et au coin avant DROIT une caisse
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
# correction F1-A (M-2) : la caisse de bocaux est dessinée SOUS le laser vanilla, dont la base la recouvre presque
# entière (F42), quel que soit le coin (avant gauche au premier essai, avant droit ensuite : rendu r0c du 24/10) ; le
# triplet nomme ce que la vignette E montre : le muret, le plancher qui dépasse et le pied du vanilla
# reprise de la correction (24/10, après-midi) : « sacs de sable » → « tube ambré » ; au zoom 1, le muret de sacs ne se
# lit que comme un rebord gris autour du plancher (vignette E, correction/planches_final)
TRIPLET = ("tube ambré", "plancher de bois", "pied en ciseaux")
FOYER = ages.FOYER[1]
FAISCEAU = dict(rgb=(1.0, 0.25, 0.2), forme="vanilla (niveaux 1 et 2)", largeur=1.0)


def piece(g, c):
    """Niveau 2 : plancher de planches sous toute l'emprise (sous le vanilla), muret de sacs de sable en arc sur l'avant
    et les flancs, RÂTELIER DE BOCAUX DE LEYDE à l'arrière (lot F1-B), lanterne de nuit au coin avant gauche.
    Lot F1-B (25/10) : la caisse de bocaux du lot F1-A, posée SOUS la base du vanilla, restait cachée (F42) ; les bocaux
    passent sur un râtelier de planches dressé au NORD du plancher. Il remplit aussi, vu de la caméra, le trou du laser
    vanilla (F165 : 846 px hr en pose E, entre le câble de la tête et le pied, x de −0,89 à 0,14 tuile, de 0,62 à 1,27
    tuile au-dessus du centre à l'écran ; outil fo-logs/2026-10-25_F1B/outils/f1b_trou_vanilla.py) : le plancher va
    jusqu'au bord nord (il remplit le bas du trou) et le râtelier, haut de 0,66, le haut."""
    M = g.M
    F.deck_e(g, 2, -1.04, 1.04, Y(-1.08), Y(0.98), 0.05)
    for sx in (-1, 1):
        pts = [(sx * 1.08, Y(0.3), 0.0), (sx * 1.08, Y(-0.4), 0.0), (sx * 1.0, Y(-0.85), 0.0),
               (sx * 0.75, Y(-1.12), 0.0), (sx * 0.42, Y(-1.15), 0.0)]
        sandbag_wall(g, pts, rows=2)
    # ronde 1 (F1-B) : 72 px restaient sous le canon du vanilla (x de 0,66 à 0,78 tuile, jusqu'à 1,45 tuile au-dessus du
    # centre) : râtelier plus large (jusqu'à x = 0,9) et plus haut (quatre étagères)
    ratelier_leyde(g, -0.98, 0.9, 0.9)
    F.lantern(g, (-0.8, Y(-0.95), 0.15), M["emit"])
    g.box((-0.8, Y(-0.95), 0.07), (0.1, 0.1, 0.15), M["wood"], "hard", what="billot")
    g.halo((-0.8, Y(-0.95), 0.3), M["_emit_rgb"], 6.0)


def ratelier_leyde(g, x0, x1, yn):
    """Râtelier de planches dressé au nord du plancher (de x0 à x1, face au sud) : dos de planches PLEIN (aucun jour),
    deux montants, trois étagères chargées de BOCAUX DE LEYDE (verre sombre, feuille de cuivre, boule de laiton) reliés
    par un fil de cuivre, la réserve d'énergie bricolée du pionnier."""
    M = g.M
    y = Y(yn)
    H = 0.9
    L = x1 - x0
    xc = (x0 + x1) / 2
    nb = 6
    for k in range(nb):
        g.box((xc, y + 0.06, H * (k + 0.5) / nb), (L, 0.03, H / nb - 0.008), M["wood"] if k % 2 else M["wood2"],
              "hard", what="dos")
    for xx in (x0 + 0.03, x1 - 0.03):
        g.box((xx, y, H / 2 + 0.02), (0.05, 0.14, H + 0.04), M["wood2"], "hard", what="montant")
    for j, zz in enumerate((0.05, 0.27, 0.49, 0.71)):
        g.box((xc, y - 0.01, zz), (L - 0.06, 0.14, 0.025), M["wood"], "hard", what="etagere")
        tops = []
        n = int((L - 0.12) / 0.11)
        for i in range(n):
            x = x0 + 0.09 + i * (L - 0.18) / max(1, n - 1)
            h = 0.15 + 0.02 * ((i + j) % 2)
            g.cyl((x, y - 0.02, zz + 0.012 + h / 2), "z", 0.035, h, M["glass_dk"], n=12, style="smooth", what="bocal")
            g.cyl((x, y - 0.02, zz + 0.012 + h * 0.3), "z", 0.038, h * 0.55, M["copper"], n=12, what="feuille")
            g.cyl((x, y - 0.02, zz + 0.012 + h + 0.03), "z", 0.006, 0.05, M["brass"], n=6, what="tige")
            g.sphere((x, y - 0.02, zz + 0.012 + h + 0.06), 0.014, M["brass"], n=8, m=5, what="boule")
            tops.append(V((x, y - 0.02, zz + 0.012 + h + 0.06)))
        for a, b in zip(tops[:-1], tops[1:]):
            g.cable(a, b, 0.015, 0.005, M["copper"], what="fil")
    g.box((xc, y - 0.08, H + 0.03), (L + 0.04, 0.06, 0.03), M["rawiron"], "hard", what="chapeau")


def caisse_leyde(g, c, size, rz=0.0, r=0.045, h=0.17):
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
            g.cyl((x, y, sz * 0.4 + h / 2), "z", r, h, M["glass_dk"], n=14, style="smooth", what="bocal")
            g.cyl((x, y, sz * 0.4 + h * 0.3), "z", r + 0.004, h * 0.55, M["copper"], n=14, what="feuille")
            g.cyl((x, y, sz * 0.4 + h + 0.012), "z", r * 0.8, 0.024, M["wood2"], n=12, what="bouchon")
            g.cyl((x, y, sz * 0.4 + h + 0.05), "z", 0.009, 0.07, M["brass"], n=6, what="tige")
            g.sphere((x, y, sz * 0.4 + h + 0.09), r * 0.4, M["brass"], n=10, m=6, what="boule")
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

