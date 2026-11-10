"""TOURELLE-CANON (fo-cannon-turret, ammo-turret 3×3) : « le canon de siège ». Socle commun large, sellette sombre à bague turquoise ;
TÊTE TOURNANTE (64 directions) : tourelle blindée basse à pans inclinés (argent), nuque à l'arrière, mantelet, long tube à manchon
d'évacuation et frein de bouche, conduit cyan le long du tube, trappe et viseur de cristal, liserés magenta. Une image (comme le canon
d'aujourd'hui)."""
import marques as MQ
import socle_tourelle as St
import tourelle_tete as T

IMAGES = 1
ZT = 0.46


def build(S, k, M):
    z = St.socle(k, 1.3, 0.38, forme=MQ.marque("canon")["forme"])
    lis = "lisere" if "lisere" in k.M else "turq"
    k.rev("struct", 0.0, 0.0, [(z, 0.8), (z + 0.04, 0.78)], 48)
    k.tore(lis, 0.0, 0.0, z + 0.02, 0.8, 0.016, 72, 6)
    return {}


def tete(k, M, image):
    zt = T.couronne(k, ZT, 0.74)
    pts = [(-0.6, -0.74), (0.6, -0.74), (0.7, -0.2), (0.48, 0.44), (-0.48, 0.44), (-0.7, -0.2)]
    k.poly("blind", pts, zt, zt + 0.32, 0.8)
    k.poly("blind2", [(x * 0.74, y * 0.74 - 0.06) for x, y in pts], zt + 0.32, zt + 0.37, 0.9)
    k.caisson("blind2", 0.0, -0.86, zt + 0.04, 0.86, 0.26, 0.24, 0.04)
    k.b("lisere" if "lisere" in k.M else "accent", (0.0, -0.995, zt + 0.16), (0.6, 0.012, 0.024))
    for sx in (-1, 1):
        k.axe("conduit", (sx * 0.44, -0.6, zt + 0.375), (sx * 0.3, 0.2, zt + 0.375), 0.013, 6)
    # trappe et viseur
    k.cyl("struct", 0.22, -0.28, zt + 0.37, zt + 0.43, 0.13, 20)
    T.toit(k, MQ.marque("canon")["toit"], 0.22, -0.28, zt + 0.44, 0.34)
    k.sph("cristal", (-0.3, 0.02, zt + 0.44), 0.08, 14, 7)
    k.sph("conduit", (-0.3, 0.02, zt + 0.44), 0.03, 8, 4)
    # mantelet et tube (le long de +y)
    zb = zt + 0.22
    k.b("blind2", (0.0, 0.47, zb), (0.42, 0.14, 0.26))
    T.fut_y(k, "canon", 0.0, zb, [(0.52, 0.13), (0.64, 0.12), (0.68, 0.095), (1.3, 0.082), (1.33, 0.11), (1.46, 0.11), (1.49, 0.082),
                                   (1.9, 0.078), (1.93, 0.118), (2.12, 0.118), (2.14, 0.06), (2.141, 0.0)], 18)
    for sx in (-1, 1):
        k.b("struct", (sx * 0.112, 2.03, zb), (0.012, 0.07, 0.08))
    k.axe("conduit", (0.0, 0.7, zb + 0.096), (0.0, 1.29, zb + 0.084), 0.011, 6)
    T.fut_y(k, "accent", 0.0, zb, [(1.385, 0.113), (1.405, 0.113)], 18)
    return {"bouche": (0.0, 2.14, zb)}
