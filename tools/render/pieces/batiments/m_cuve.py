"""CUVE D'ÉLECTROLYSE IGNÉE (fo-reduction-cell, assembling-machine 4×4, 6 MW, procédé Hall-Héroult) : cuve octogonale blindée argent sur
socle sombre, pont d'anodes (deux rails porte-anodes, six anodes de graphite plongeantes), bain d'alumine fondue visible entre les anodes
(cœur cyan à croûte, lueur de nuit), quatre tours d'angle à conduits cyan montant vers des collecteurs, jeux de barres (canon),
hotte d'aspiration sud à persiennes, accents magenta, voyants. Emprise 3,4 × 3,4 au sol (la collision d'X3)."""
import math

import geo as G
import organes as O

D = O.D


def _octo(r, n=8):
    return [(r * math.cos(math.pi / 8 + 2 * math.pi * i / n), r * math.sin(math.pi / 8 + 2 * math.pi * i / n) * D) for i in range(n)]


def build(S, k, M):
    R, H = 1.62, 1.05
    # socle et cuve octogonale
    k.poly("struct", _octo(R + 0.08), 0.0, 0.08)
    k.poly("blind", _octo(R), 0.08, H, 0.97)
    k.poly("blind2", _octo(R - 0.06), H, H + 0.06)
    k.poly("struct", _octo(R - 0.22), H + 0.06, H + 0.1)        # bord intérieur
    # bain : disque de cœur cyan (couche lueur) au fond du cratère
    k.cyl("coeur", 0.0, 0.0, H - 0.02, H + 0.04, R - 0.3, 24)
    k.cyl("halo", 0.0, 0.0, H + 0.04, H + 0.12, R - 0.32, 24)
    # plaques de blindage verticales (joints sombres) autour de la cuve, rivetées
    pts = _octo(R + 0.002)
    for i in range(8):
        a, b = pts[i], pts[(i + 1) % 8]
        for t in (0.2, 0.5, 0.8):
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            n = (-(b[1] - a[1]), (b[0] - a[0]))
            L = math.hypot(*n)
            n = (n[0] / L, n[1] / L)
            k.put("struct", G.boite((x + n[0] * 0.01, y + n[1] * 0.01, H * 0.55), (0.03, 0.03, H * 0.8)))
    # pont d'anodes : deux rails sur portiques, six anodes de graphite (sombres) plongeant dans le bain, barres de connexion
    for sy in (-1, 1):
        yr = sy * 0.5 * D
        k.b("canon", (0.0, yr, H + 0.62), (2.5, 0.09, 0.09))
        for sx in (-1, 1):
            k.b("struct", (sx * 1.18, yr, (H + 0.6) / 2.0 + 0.3), (0.1, 0.1, H + 0.6 - 0.6))
        for i in range(3):
            x = -0.8 + 0.8 * i
            k.b("struct", (x, yr, H + 0.5), (0.08, 0.08, 0.3))
            k.b("struct", (x, yr, H + 0.2), (0.3, 0.26, 0.55))      # anode de graphite
            k.b("turq", (x, yr - 0.14, H + 0.52), (0.24, 0.01, 0.04))   # témoin de courant
    k.b("canon", (0.0, 0.0, H + 0.7), (0.12, 1.1 * D, 0.06))             # barre de liaison des deux rails
    # tours d'angle : conduits cyan montants vers des collecteurs argent
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (R - 0.25), sy * (R - 0.25) * D
            k.cyl("struct", x, y, 0.08, H + 0.5, 0.11, 12)
            k.cyl("conduit", x, y, 0.3, H + 0.45, 0.045, 8)
            k.cerclages("blind", x, y, (0.5, 0.9, H + 0.2), 0.11, 0.02, 0.025, 12)
            k.sph("blind2", (x, y, H + 0.56), 0.16, 14, 7)
            k.sph("accent", (x, y - 0.14, H + 0.5), 0.03, 8, 4)
    # jeux de barres entre les tours (nord), tuyaux d'alimentation (ouest), hotte sud à persiennes
    for z in (H + 0.3, H + 0.42):
        k.b("canon", (0.0, (R - 0.25) * D, z), (2 * (R - 0.25) - 0.3, 0.05, 0.05))
    k.tuyau("canon", [(-R - 0.1, -0.3 * D, 0.25), (-R + 0.2, -0.3 * D, 0.25), (-R + 0.2, -0.3 * D, 0.9)], 0.07)
    k.tuyau("canon", [(-R - 0.1, 0.3 * D, 0.25), (-R + 0.2, 0.3 * D, 0.25), (-R + 0.2, 0.3 * D, 0.9)], 0.07)
    ys = -R * D * 0.92
    k.caisson("blind2", 0.0, ys + 0.2, 0.08, 1.4, 0.4, 0.75, 0.03)
    k.persiennes("canon", 0.0, ys, 0.2, 1.1, 0.42, 6)
    k.voyant("accent", -0.6, ys, 0.68, 0.025)
    k.voyant("turq", 0.6, ys, 0.68, 0.025)
    k.b("accent", (0.0, ys - 0.004, 0.14), (1.2, 0.008, 0.025))
    # cheminée d'évent au nord-est (acier clair, cerclages), échelle sud-ouest
    k.cyl("canon", R - 0.6, (R - 0.5) * D, 0.1, H + 1.1, 0.12, 14)
    k.cerclages("struct", R - 0.6, (R - 0.5) * D, (0.6, 1.2, 1.8), 0.12, 0.016, 0.02, 14)
    k.echelle("os", -R + 0.5, ys + 0.02, 0.1, H + 0.05, 0.16)
    return None
