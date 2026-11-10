"""COFFRE D'ÉQUIPE (fo-team-chest, container 1×1) : coffre blindé des compagnons. Caisson argent iridescent chanfreiné, couvercle à deux
battants en plaques secondaires séparés par une rainure-conduit cyan, quatre cornières sombres, cœur-serrure cyan sur la face sud,
liseré magenta de propriété, deux runes cyan sur le dessus. Même emprise que le coffre d'acier vanilla (0,7 tuile de large)."""
import math

import organes as O

D = O.D


def build(S, k, M):
    w, d, h = 0.74, 0.62 * D, 0.52       # largeur (x), profondeur (y), hauteur du corps
    y0 = 0.0
    # corps : caisson principal chanfreiné, socle sombre
    k.bz("struct", 0.0, y0, 0.0, w * 0.96, d * 0.96, 0.05)
    k.caisson("blind", 0.0, y0, 0.05, w, d, h - 0.05, 0.05)
    # cornières aux quatre arêtes verticales
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.b("struct", (sx * (w / 2 - 0.035), y0 + sy * (d / 2 - 0.035), (h + 0.05) / 2.0), (0.07, 0.07, h - 0.02))
    # couvercle : deux battants bombés (plaques secondaires), rainure centrale = conduit cyan
    zc = h
    for sx in (-1, 1):
        k.caisson("blind2", sx * (w / 4 + 0.01), y0, zc, w / 2 - 0.05, d - 0.06, 0.09, 0.03)
    k.b("conduit", (0.0, y0, zc + 0.07), (0.045, d - 0.1, 0.03))
    k.b("struct", (0.0, y0, zc + 0.05), (0.075, d - 0.08, 0.02))
    # runes cyan sur les battants
    for sx in (-1, 1):
        k.b("turq", (sx * 0.2, y0 + 0.08 * D, zc + 0.095), (0.09, 0.012, 0.006))
        k.b("turq", (sx * 0.2, y0 - 0.06 * D, zc + 0.095), (0.05, 0.012, 0.006))
    # face sud : plaque de serrure sombre, cœur-serrure cyan, liseré magenta au bas
    ys = y0 - d / 2.0
    k.b("struct", (0.0, ys - 0.006, h * 0.5), (0.3, 0.012, 0.22))
    k.sph("coeur", (0.0, ys - 0.02, h * 0.5), 0.05, 16, 8)
    k.sph("halo", (0.0, ys - 0.02, h * 0.5), 0.08, 16, 8)
    k.b("accent", (0.0, ys - 0.004, 0.11), (w * 0.8, 0.008, 0.02))
    # poignées latérales (acier clair), rivets des cornières
    for sx in (-1, 1):
        k.axe("canon", (sx * (w / 2 + 0.02), y0 - 0.1, h * 0.55), (sx * (w / 2 + 0.02), y0 + 0.1, h * 0.55), 0.016, 8)
        k.axe("canon", (sx * (w / 2 - 0.01), y0 - 0.1, h * 0.55), (sx * (w / 2 + 0.03), y0 - 0.1, h * 0.55), 0.012, 6)
        k.axe("canon", (sx * (w / 2 - 0.01), y0 + 0.1, h * 0.55), (sx * (w / 2 + 0.03), y0 + 0.1, h * 0.55), 0.012, 6)
    pts = [(sx * (w / 2 - 0.035), ys - 0.03, z) for sx in (-1, 1) for z in (0.12, 0.3, 0.46)]
    k.rivets("os", pts, (0.0, -1.0, 0.0), 0.011)
    return None
