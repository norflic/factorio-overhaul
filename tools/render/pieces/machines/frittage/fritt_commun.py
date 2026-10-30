"""Organes propres au FOUR DE FRITTAGE (communs aux essais a, b, c) : raccords nord (entrée) et sud (sortie),
anneau autour d'un axe quelconque, regard rougeoyant, porte de four. Repère : organes.py."""
import math

import geo
from organes import Y

COTE = 3


def raccords(k, z=0.32, r=0.14):
    k.raccord(0.0, COTE / 2, +1, mat="tuyau", r=r, z=z, long=0.45)
    k.raccord(0.0, -COTE / 2, -1, mat="tuyau", r=r, z=z, long=0.45)


def anneau(k, mat, c, n, r0, r1, w, segs=32, petite=False):
    """Anneau (bandage, cerclage, couronne) d'axe n centré en c : rayon intérieur r0, extérieur r1, largeur w."""
    prof = [(-w / 2, r0), (-w / 2, r1), (w / 2, r1), (w / 2, r0)]
    k.put(mat, geo.oriente(geo.tour(prof, segs, "z"), c, n), petite)


def regard(k, p, n=(0, -1, 0), r=0.045, mat="feu"):
    """Regard de four : couronne de fonte boulonnée, verre rougeoyant (matière lumineuse)."""
    k.put("structure", geo.oriente(geo.tour([(0.0, r * 1.7), (0.03, r * 1.7), (0.03, r * 1.15), (0.012, r * 1.15)], 14,
                                            "z", cap0=True), p, n), True)
    k.put(mat, geo.oriente(geo.sphere((0, 0, 0.0), r, 10, 4, zmin=0.0), p, n))
    k.boulons_cercle(geo.add(p, geo.mul(geo.norm(n), 0.03)), r * 1.45, 4, n, 0.012)


def porte(k, x, y, z, w, h, volant=True):
    """Porte de four sur une face sud (y = face) : cadre de fonte, vantail de fonte rouillée, fente rougeoyante en
    pied et en tête, barre de serrage à volant, charnières."""
    k.box("structure", (x, y - 0.03, z), (w + 0.12, 0.06, h + 0.12))
    k.box("capot2", (x, y - 0.075, z), (w, 0.05, h))
    for dz in (-h / 2 - 0.025, h / 2 + 0.025):
        k.put("feu", geo.boite((x, y - 0.065, z + dz), (w * 0.9, 0.02, 0.022)))
    for i in range(3):                                          # raidisseurs du vantail
        k.box("structure", (x - w / 2 + w * (i + 0.5) / 3, y - 0.105, z), (0.035, 0.02, h * 0.92), petite=True)
    k.box("structure", (x, y - 0.13, z + h * 0.1), (w + 0.2, 0.035, 0.05))     # barre de serrage
    for sx in (-1, 1):
        k.box("acier", (x + sx * (w / 2 + 0.08), y - 0.12, z + h * 0.1), (0.05, 0.05, 0.1), petite=True)
        for dz in (-h * 0.3, h * 0.3):
            k.box("acier", (x - w / 2 - 0.03, y - 0.09, z + dz), (0.05, 0.04, 0.07), petite=True)
    if volant:
        R = 0.07
        c = (x, y - 0.16, z + h * 0.1)
        k.put("rouge", geo.tube([(c[0] + R * math.cos(geo.TAU * i / 16), c[1], c[2] + R * math.sin(geo.TAU * i / 16))
                                 for i in range(17)], 0.014, 6, False, False), True)
        for i in range(4):
            a = geo.TAU * i / 4 + 0.4
            k.put("rouge", geo.tube([c, (c[0] + R * math.cos(a), c[1], c[2] + R * math.sin(a))], 0.011, 5))
    k.rivets([((x + dx, y - 0.1, z + dz), (0, -1, 0)) for dx in (-w / 2 + 0.04, w / 2 - 0.04)
              for dz in (-h / 2 + 0.04, 0.0, h / 2 - 0.04)], "rivet", 0.016, 0.01)


def poutre_h(k, x, y, z0, z1, face=-1, w=0.07, mat="structure"):
    """Poutre en H verticale (montant de massif) contre une face nord/sud : âme et 2 ailes, boulons de tirant."""
    k.box(mat, (x, y + face * 0.03, (z0 + z1) / 2), (0.022, 0.06, z1 - z0))
    for dx in (-w / 2, w / 2):
        k.box(mat, (x + dx, y + face * 0.06, (z0 + z1) / 2), (0.018, 0.022, z1 - z0))
    k.boulon((x, y + face * 0.075, z1 - 0.08), (0, face, 0), 0.022)
    k.boulon((x, y + face * 0.075, z0 + 0.1), (0, face, 0), 0.022)


def Yc(yn):
    return Y(yn)
