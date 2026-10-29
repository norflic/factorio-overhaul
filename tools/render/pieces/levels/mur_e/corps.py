"""Aides de forme du MUR (lot F6, 29/10) : boîtes par bornes, tronc de pyramide, cellules. S'exécute DANS Blender (ne
dépend que de kit.Geo). Les designs d'âge (epNN.py) les utilisent ; aucune valeur du kit commun n'est modifiée."""


def B(g, x0, x1, y0, y1, z0, z1, mat, style="hard", what="bloc"):
    """Boîte alignée par bornes."""
    g.box(((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), mat,
          style, what=what)


def tronc(g, x0, x1, y0, y1, z0, z1, k, mat, style="hard", ky=None, what="tronc"):
    """Tronc de pyramide : base [x0,x1]×[y0,y1] à z0, dessus réduit de k (kx) et ky autour du centre à z1."""
    ky = k if ky is None else ky
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    hx, hy = (x1 - x0) / 2.0, (y1 - y0) / 2.0
    bas = [(cx - hx, cy - hy, z0), (cx + hx, cy - hy, z0), (cx + hx, cy + hy, z0), (cx - hx, cy + hy, z0)]
    haut = [(cx - hx * k, cy - hy * ky, z1), (cx + hx * k, cy - hy * ky, z1), (cx + hx * k, cy + hy * ky, z1),
            (cx - hx * k, cy + hy * ky, z1)]
    g.hexa(bas + haut, mat, style, what)


def cellules(L, n):
    return [(L * i / n, L * (i + 1) / n) for i in range(n)]


def alea(g, a, b):
    return a + (b - a) * g.rng.random()
