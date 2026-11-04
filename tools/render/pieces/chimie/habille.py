"""HABILLAGE des faces visibles (lot DA-CHIMIE) : posé dans le repère ABSOLU (tuiles, y vers le sud), sur l'emprise absolue
d'une boîte (Rep.bornes) : montants, ceintures, fenêtres de foyer, portes. Seules la face SUD et les faces est/ouest (vues
par la tranche, elles font la silhouette) comptent ; la face nord n'est jamais vue.
"""
import math

D = 1.0 / math.cos(math.radians(45.0))


def yb(y):
    """y absolu (tuiles) -> Blender."""
    return -y * D


def montants(k, mat, b, z0, z1, pas=0.45, l=0.075, e=0.05, faces="sew"):
    """Poteaux en I (raidisseurs de four) le long des faces de l'emprise b = (x0, x1, y0, y1)."""
    x0, x1, y0, y1 = b
    xs = []
    if "s" in faces:
        n = max(2, int(round((x1 - x0) / pas)))
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            k.bz(mat, x, yb(y1) - e / 2.0, z0, l, e, z1 - z0)
            k.bz(mat, x, yb(y1) - e, z0, l * 1.6, 0.018, z1 - z0)
            xs.append(x)
    for f, x in (("e", x1), ("w", x0)):
        if f not in faces:
            continue
        n = max(2, int(round((y1 - y0) / pas)))
        sg = 1.0 if f == "e" else -1.0
        for i in range(n + 1):
            y = y0 + (y1 - y0) * i / n
            k.bz(mat, x + sg * e / 2.0, yb(y), z0, e, l * D, z1 - z0)
            k.bz(mat, x + sg * e, yb(y), z0, 0.018, l * 1.6 * D, z1 - z0)
    return xs


def ceinture(k, mat, b, z, h=0.06, e=0.035):
    """Ceinture horizontale autour de l'emprise (4 faces)."""
    x0, x1, y0, y1 = b
    k.bz(mat, (x0 + x1) / 2.0, yb(y1) - e / 2.0, z, x1 - x0 + 2 * e, e, h)
    k.bz(mat, (x0 + x1) / 2.0, yb(y0) + e / 2.0, z, x1 - x0 + 2 * e, e, h)
    k.bz(mat, x1 + e / 2.0, yb((y0 + y1) / 2.0), z, e, (y1 - y0) * D, h)
    k.bz(mat, x0 - e / 2.0, yb((y0 + y1) / 2.0), z, e, (y1 - y0) * D, h)


def fenetre(k, cadre, vitre, x, y, z, w=0.13, h=0.1, e=0.03):
    """Regard sur une face sud (y absolu de la face) : cadre saillant, vitre lumineuse en retrait, deux boulons."""
    Y = yb(y)
    k.b(cadre, (x, Y - e / 2.0, z), (w + 0.05, e, h + 0.05))
    k.b(vitre, (x, Y - e - 0.002, z), (w, 0.006, h))
    k.b(cadre, (x, Y - e - 0.006, z + h / 2.0 + 0.005), (w + 0.03, 0.012, 0.018))


def entre(xs, n_max=99):
    """Milieux entre montants consécutifs."""
    return [(xs[i] + xs[i + 1]) / 2.0 for i in range(min(len(xs) - 1, n_max))]


def porte(k, mat, poignee, x, y, z0, w, h):
    """Porte sur une face sud : vantail, charnières, poignée."""
    Y = yb(y)
    k.b(mat, (x, Y - 0.008, z0 + h / 2.0), (w, 0.016, h))
    k.b("noir", (x, Y - 0.002, z0 + h / 2.0), (w + 0.025, 0.006, h + 0.025))
    for zz in (z0 + 0.2 * h, z0 + 0.8 * h):
        k.b(poignee, (x - w / 2.0 + 0.012, Y - 0.02, zz), (0.02, 0.016, 0.04))
    k.b(poignee, (x + w / 2.0 - 0.04, Y - 0.022, z0 + 0.5 * h), (0.016, 0.014, 0.08))
