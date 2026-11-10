"""TOURELLE LASER LOURDE (fo-heavy-laser-turret, electric-turret 3×3) : « le dôme focal ». Socle commun large, couronne de six
lentilles-satellites (cristal sur fûts argent) autour d'un dôme facetté de cristal bleu glacier (six facettes) qui laisse voir le
cœur cyan, bague lumineuse à la base du dôme, focaliseur de tête (bague argent et lentille-cœur). Le faisceau part du focaliseur :
ANCRAGE « emetteur »."""
import math

import socle_tourelle as St

D = St.D


def build(S, k, M):
    z = St.socle(k, 1.3, 0.38)
    k.poly("blind2", St.octo(0.78, n=6, rot=0.0, ky=1.0), z, z + 0.14, 0.92)
    zd = z + 0.14
    # dôme facetté et cœur
    k.dome("cristal", 0.0, 0.0, zd, 0.58, 0.9, 6)
    k.sph("coeur", (0.0, 0.0, zd + 0.26), 0.16, 20, 10)
    k.sph("halo", (0.0, 0.0, zd + 0.26), 0.24, 20, 10)
    k.tore("anneau", 0.0, 0.0, zd + 0.02, 0.6, 0.02, 60, 8)
    # couronne de six lentilles-satellites
    for i in range(6):
        a = math.pi / 6 + 2 * math.pi * i / 6
        c, s = math.cos(a), math.sin(a)
        x, y = 0.98 * c, 0.98 * s * D * 0.82
        k.cyl("blind", x, y, z, z + 0.32, 0.07, 12)
        k.cerclages("struct", x, y, (z + 0.1,), 0.07, 0.015, 0.02, 12)
        k.sph("cristal", (x, y, z + 0.39), 0.08, 14, 7)
        k.sph("conduit", (x, y, z + 0.39), 0.035, 10, 5)
    # focaliseur de tête
    zt = zd + 0.58 * 0.9
    k.rev("blind", 0.0, 0.0, [(zt - 0.04, 0.16), (zt + 0.02, 0.18), (zt + 0.08, 0.12)], 24)
    k.cerclages("accent", 0.0, 0.0, (zt + 0.01,), 0.18, 0.01, 0.01, 24)
    k.sph("halo", (0.0, 0.0, zt + 0.12), 0.08, 14, 7)
    k.sph("coeur", (0.0, 0.0, zt + 0.12), 0.05, 12, 6)
    return {"emetteur": (0.0, 0.0, zt + 0.12)}
