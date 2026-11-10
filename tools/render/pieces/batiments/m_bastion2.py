"""BASTION II (fo-bastion-2, electric-turret 2×2, âge 2, mode laser) : « le prisme ». Sur le socle commun, un berceau de trois bras
argent qui tient une colonne de cristal hexagonale bleu glacier (le prisme qui concentre le faisceau), cœur cyan au centre de la
colonne, bague cyan lumineuse et lentille de tête ; trois condensateurs sombres à liseré turquoise au pied du berceau. Le faisceau
part du sommet de la lentille : ANCRAGE « emetteur »."""
import math

import socle_tourelle as St

D = St.D


def build(S, k, M):
    z = St.socle(k, 0.86, 0.3)
    # moyeu du berceau
    k.rev("blind", 0.0, 0.0, [(z, 0.36), (z + 0.1, 0.34), (z + 0.16, 0.24), (z + 0.22, 0.22)], 24)
    zc0, zc1 = z + 0.22, z + 1.32
    # trois bras du berceau (à 120°), griffes en haut
    for i in range(3):
        a = math.pi / 2 + 2 * math.pi * i / 3
        c, s = math.cos(a), math.sin(a)
        p0 = (0.3 * c, 0.3 * s, z + 0.12)
        p1 = (0.4 * c, 0.4 * s, zc1 - 0.22)
        p2 = (0.22 * c, 0.22 * s, zc1 - 0.04)
        k.axe("blind2", p0, p1, 0.05, 10)
        k.axe("canon", p1, p2, 0.035, 8)
        k.axe("conduit", (p0[0] * 1.12, p0[1] * 1.12, p0[2] + 0.04), (p1[0] * 1.12, p1[1] * 1.12, p1[2] - 0.05), 0.012, 6)
        # condensateurs au pied du bras
        x, y = 0.56 * c, 0.56 * s * D
        k.cyl("struct", x, y, z, z + 0.24, 0.085, 12)
        k.cerclages("turq", x, y, (z + 0.18,), 0.085, 0.012, 0.012, 12)
    # colonne de cristal hexagonale (prisme), cœur cyan au centre
    k.rev("cristal", 0.0, 0.0, [(zc0, 0.16), (zc0 + 0.1, 0.23), (zc1 - 0.16, 0.23), (zc1, 0.08)], 6)
    k.rev("coeur", 0.0, 0.0, [(zc0 + 0.18, 0.07), (zc1 - 0.22, 0.07)], 12)
    k.cerclages("anneau", 0.0, 0.0, ((zc0 + zc1) / 2.0,), 0.23, 0.025, 0.025, 24)
    # lentille de tête
    k.rev("canon", 0.0, 0.0, [(zc1, 0.15), (zc1 + 0.04, 0.18), (zc1 + 0.08, 0.13)], 20)
    k.sph("halo", (0.0, 0.0, zc1 + 0.1), 0.1, 14, 7)
    k.sph("coeur", (0.0, 0.0, zc1 + 0.1), 0.06, 12, 6)
    return {"emetteur": (0.0, 0.0, zc1 + 0.1)}
