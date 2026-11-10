"""MORTIER (fo-mortar-turret, ammo-turret 3×3) : « l'obusier ». Socle commun, sellette sombre à bague turquoise ; TÊTE TOURNANTE
(64 directions) : plateau tournant, deux flasques argent à conduits cyan portant les tourillons, tube court et gros levé à 55° (culasse
sombre, frette argent, bouche évasée), deux freins de recul sous le tube, viseur de cristal, liseré magenta. Une image (comme le mortier
d'aujourd'hui)."""
import math

import socle_tourelle as St
import tourelle_tete as T

IMAGES = 1
ZT = 0.42
ELEV = math.radians(55.0)


def build(S, k, M):
    z = St.socle(k, 1.25, 0.34)
    k.rev("struct", 0.0, 0.0, [(z, 0.72), (z + 0.04, 0.7)], 48)
    k.tore("turq", 0.0, 0.0, z + 0.02, 0.72, 0.012, 72, 6)
    return {}


def tete(k, M, image):
    zt = T.couronne(k, ZT, 0.66)
    k.rev("blind", 0.0, 0.0, [(zt, 0.58), (zt + 0.08, 0.56), (zt + 0.1, 0.5)], 40)
    zt += 0.1
    k.b("accent", (0.0, -0.5, zt + 0.02), (0.5, 0.012, 0.022))
    # flasques et tourillons
    zp = zt + 0.38
    py = 0.05
    for sx in (-1, 1):
        x = sx * 0.33
        k.poly("blind", [(x - 0.05, -0.36), (x + 0.05, -0.36), (x + 0.05, 0.3), (x - 0.05, 0.3)], zt, zt + 0.3, 1.0)
        k.poly("blind2", [(x - 0.05, -0.18), (x + 0.05, -0.18), (x + 0.05, 0.22), (x - 0.05, 0.22)], zt + 0.3, zp + 0.1, 0.8)
        k.axe("conduit", (x + sx * 0.052, -0.3, zt + 0.28), (x + sx * 0.052, 0.18, zp + 0.06), 0.011, 6)
    T.fut_x(k, "struct", py, zp, [(-0.42, 0.075), (0.42, 0.075)], 16)
    k.sph("cristal", (0.46, -0.1, zt + 0.36), 0.075, 14, 7)
    k.sph("conduit", (0.46, -0.1, zt + 0.36), 0.03, 8, 4)
    # tube levé (vers le nord et le haut)
    d = (0.0, math.cos(ELEV), math.sin(ELEV))
    n = (0.0, -math.sin(ELEV), math.cos(ELEV))

    def p(t, off=0.0, ox=0.0):
        return (ox, py + d[1] * t + n[1] * off, zp + d[2] * t + n[2] * off)

    k.axe("struct", p(-0.3), p(-0.04), 0.2, 20)
    k.axe("canon", p(-0.04), p(0.82), 0.15, 20)
    k.axe("blind2", p(0.26), p(0.4), 0.17, 20)
    k.axe("accent", p(0.41), p(0.43), 0.165, 20)
    k.axe("canon", p(0.82), p(0.95), 0.185, 20)
    k.axe("struct", p(0.94), p(0.952), 0.12, 16)
    for sx in (-1, 1):
        k.axe("struct", p(-0.2, -0.17, sx * 0.09), p(0.5, -0.17, sx * 0.09), 0.035, 8)
    return {"bouche": p(0.95)}
