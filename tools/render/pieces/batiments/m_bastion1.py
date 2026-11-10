"""BASTION I (fo-bastion-1, ammo-turret 2×2, âge 1, mode cinétique) : « le rempart cinétique », premier de la lignée Bastion. Socle commun
(parenté avec les Bastion II à IV refaits par F476), sellette sombre à bague turquoise ; TÊTE TOURNANTE (64 directions, tourelle_tete.py)
: mantelet hexagonal argent biseauté, deux canons jumelés à manchons de refroidissement, coffre à bandes sur le flanc droit, capteur de
cristal, conduits cyan sur le toit, liseré magenta à l'arrière. Image 1 (tir) : canons reculés, éclair cyan aux bouches."""
import marques as MQ
import socle_tourelle as St
import tourelle_tete as T

IMAGES = 2
ZT = 0.38          # dessus de la sellette : pied de la tête


def build(S, k, M):
    z = St.socle(k, 0.86, 0.3, forme=MQ.marque("bastion1")["forme"])
    lis = "lisere" if "lisere" in k.M else "turq"
    k.rev("struct", 0.0, 0.0, [(z, 0.5), (z + 0.04, 0.48)], 40)
    k.tore(lis, 0.0, 0.0, z + 0.02, 0.5, 0.014, 64, 6)
    return {}


def tete(k, M, image):
    zt = T.couronne(k, ZT, 0.4)
    rec = 0.05 if image else 0.0
    pts = [(-0.26, -0.30), (0.26, -0.30), (0.32, -0.04), (0.22, 0.22), (-0.22, 0.22), (-0.32, -0.04)]
    k.poly("blind", pts, zt, zt + 0.26, 0.86)
    k.poly("blind2", [(x * 0.74, y * 0.74 - 0.02) for x, y in pts], zt + 0.26, zt + 0.31, 0.88)
    # conduits du toit, liseré arrière, capteur
    for sx in (-1, 1):
        k.axe("conduit", (sx * 0.17, -0.2, zt + 0.312), (sx * 0.13, 0.12, zt + 0.312), 0.012, 6)
    k.b("lisere" if "lisere" in k.M else "accent", (0.0, -0.302, zt + 0.16), (0.3, 0.012, 0.022))
    T.toit(k, MQ.marque("bastion1")["toit"], 0.0, -0.02, zt + 0.32, 0.3)
    k.sph("cristal", (0.13, -0.13, zt + 0.36), 0.055, 12, 6)
    k.sph("conduit", (0.13, -0.13, zt + 0.36), 0.022, 8, 4)
    # berceau et coffre à bandes
    zb = zt + 0.17
    k.b("struct", (0.0, 0.25, zb), (0.34, 0.08, 0.15))
    k.bz("blind2", 0.33, -0.06, zt + 0.04, 0.1, 0.26, 0.17)
    k.b("turq", (0.385, -0.06, zt + 0.13), (0.008, 0.18, 0.016))
    # canons jumelés (le long de +y)
    for sx in (-0.095, 0.095):
        T.fut_y(k, "canon", sx, zb, [(0.26 - rec, 0.05), (0.42 - rec, 0.05), (0.44 - rec, 0.04), (0.9 - rec, 0.036), (0.92 - rec, 0.048),
                                      (0.99 - rec, 0.048), (1.0 - rec, 0.0)], 14)
        for y in (0.52, 0.62, 0.72):
            T.fut_y(k, "struct", sx, zb, [(y - rec, 0.046), (y + 0.03 - rec, 0.046)], 12)
        if image:
            k.sph("halo", (sx, 1.05, zb), 0.075, 12, 6)
            k.sph("coeur", (sx, 1.03, zb), 0.035, 10, 5)
    return {"bouche": (0.0, 1.0, zb)}
