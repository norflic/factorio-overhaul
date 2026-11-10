"""TOURELLE LOURDE (fo-heavy-gun-turret, ammo-turret 3×3) : « la gatling de bastion ». Socle commun large, sellette sombre à bague
turquoise ; TÊTE TOURNANTE (64 directions) : caisson argent à joues blindées, faisceau rotatif de six canons tenu par trois colliers,
tambour de munitions sur le flanc gauche et goulotte, conduits cyan, capteur de cristal, liseré magenta. Image 1 (tir) : faisceau tourné
d'un douzième de tour, éclair cyan à la bouche."""
import math

import marques as MQ
import socle_tourelle as St
import tourelle_tete as T

IMAGES = 2
ZT = 0.46


def build(S, k, M):
    z = St.socle(k, 1.3, 0.38, forme=MQ.marque("lourde")["forme"])
    lis = "lisere" if "lisere" in k.M else "turq"
    k.rev("struct", 0.0, 0.0, [(z, 0.74), (z + 0.04, 0.72)], 48)
    k.tore(lis, 0.0, 0.0, z + 0.02, 0.74, 0.016, 72, 6)
    return {}


def tete(k, M, image):
    zt = T.couronne(k, ZT, 0.66)
    k.caisson("blind", 0.0, -0.18, zt, 0.92, 0.86, 0.4, 0.06)
    for sx in (-1, 1):
        k.poly("blind2", [(sx * 0.46, -0.58), (sx * 0.56, -0.5), (sx * 0.56, 0.12), (sx * 0.46, 0.22)], zt + 0.02, zt + 0.34, 0.9)
        k.axe("conduit", (sx * 0.5, -0.5, zt + 0.35), (sx * 0.5, 0.14, zt + 0.35), 0.013, 6)
    k.b("lisere" if "lisere" in k.M else "accent", (0.0, -0.612, zt + 0.22), (0.5, 0.012, 0.024))
    T.toit(k, MQ.marque("lourde")["toit"], 0.12, -0.3, zt + 0.405, 0.42)
    k.sph("cristal", (0.24, -0.34, zt + 0.46), 0.07, 14, 7)
    k.sph("conduit", (0.24, -0.34, zt + 0.46), 0.028, 8, 4)
    k.cyl("struct", -0.18, -0.4, zt + 0.4, zt + 0.44, 0.1, 16)
    # tambour de munitions (flanc gauche) et goulotte
    zm = zt + 0.26
    T.fut_x(k, "struct", -0.2, zm, [(-0.74, 0.0), (-0.74, 0.25), (-0.52, 0.25), (-0.52, 0.0)], 22)
    T.fut_x(k, "turq", -0.2, zm, [(-0.64, 0.255), (-0.62, 0.255)], 22)
    k.axe("struct", (-0.52, -0.1, zm), (-0.14, 0.22, zt + 0.3), 0.04, 8)
    # faisceau rotatif de six canons (le long de +y)
    zb = zt + 0.3
    spin = math.pi / 6 if image else 0.0
    T.fut_y(k, "struct", 0.0, zb, [(0.2, 0.0), (0.2, 0.2), (0.34, 0.2), (0.34, 0.0)], 20)
    T.fut_y(k, "blind2", 0.0, zb, [(1.1, 0.0), (1.1, 0.165), (1.18, 0.165), (1.18, 0.0)], 20)
    T.fut_y(k, "canon", 0.0, zb, [(1.46, 0.0), (1.46, 0.15), (1.54, 0.15), (1.54, 0.0)], 20)
    T.fut_y(k, "struct", 0.0, zb, [(0.34, 0.05), (1.5, 0.05)], 10)
    for i in range(6):
        a = spin + i * math.pi / 3
        x, z = 0.1 * math.cos(a), zb + 0.1 * math.sin(a)
        T.fut_y(k, "canon", x, z, [(0.34, 0.034), (1.58, 0.034), (1.6, 0.0)], 10)
    T.fut_y(k, "conduit", 0.0, zb, [(1.13, 0.168), (1.15, 0.168)], 20)
    if image:
        k.sph("halo", (0.0, 1.68, zb), 0.13, 14, 7)
        k.sph("coeur", (0.0, 1.64, zb), 0.06, 10, 5)
    return {"bouche": (0.0, 1.6, zb)}
