"""BASTION IV (fo-bastion-4, electric-turret 2×2, âge 4, mode plasma) : « le confinement ». Socle commun plus haut, quatre pylônes
de confinement argent à bobines cerclées et têtes magnétiques, deux anneaux de confinement superposés (lumineux) autour d'un orbe de
plasma (singularité cyan, halo), cuvette sombre sous l'orbe, accents magenta aux têtes. L'orbe part du centre de l'anneau : ANCRAGE
« emetteur »."""
import math

import socle_tourelle as St

D = St.D


def build(S, k, M):
    z = St.socle(k, 0.9, 0.36)
    k.rev("struct", 0.0, 0.0, [(z, 0.42), (z + 0.08, 0.4), (z + 0.14, 0.26), (z + 0.16, 0.0)], 28)
    zo = z + 0.78
    # quatre pylônes de confinement
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        c, s = math.cos(a), math.sin(a)
        x, y = 0.56 * c, 0.56 * s * D
        k.cyl("blind2", x, y, z, zo + 0.24, 0.075, 12)
        k.cerclages("canon", x, y, (z + 0.18, z + 0.3, z + 0.42), 0.06, 0.02, 0.025, 12)
        k.axe("blind", (x, y, zo + 0.24), (x * 0.7, y * 0.7, zo + 0.1), 0.05, 10)
        k.sph("accent", (x * 0.7, y * 0.7, zo + 0.1), 0.05, 10, 5)
        k.axe("conduit", (x * 1.06, y * 1.06, z + 0.04), (x * 1.06, y * 1.06, zo + 0.1), 0.014, 6)
    # anneaux de confinement et orbe
    k.tore("blind", 0.0, 0.0, zo - 0.14, 0.46, 0.045, 48, 10)
    k.tore("anneau", 0.0, 0.0, zo - 0.14, 0.46, 0.026, 48, 8)
    k.tore("blind", 0.0, 0.0, zo + 0.2, 0.38, 0.04, 48, 10)
    k.tore("anneau", 0.0, 0.0, zo + 0.2, 0.38, 0.022, 48, 8)
    k.sph("halo", (0.0, 0.0, zo), 0.34, 24, 12)
    k.sph("singularite", (0.0, 0.0, zo), 0.25, 24, 12)
    k.sph("coeur", (0.0, 0.0, zo), 0.12, 16, 8)
    return {"emetteur": (0.0, 0.0, zo)}
