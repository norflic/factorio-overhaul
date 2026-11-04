"""CENTRES DE CALCUL (lot CALCUL-DESIGN, 01/11). Le centre (âge 10, 4×4) : allée de baies noires à colonnes de diodes,
ouverte sous un collecteur d'eau bleu et orange, climatiseur et radôme. Le grand centre (âge 12, 6×6) : carrousel de baies
autour d'un noyau froid, anneaux chromés en lévitation, givre. Raccords : nord (-0,5) et sud (+0,5), sortie est.
"""
import math

import geo as G
import organes as O
import palettes as P

D = O.D


def baie(k, x, y, z0, l, h, e, ouverte=False, diodes="diode", cote=-1):
    """Une baie noire debout, face vers le sud : cadre, porte à trous, colonnes de diodes, jamais identique à sa voisine."""
    k.caisson("noir", x, y + e / 2.0, z0, l, e, h, 0.012)
    k.b("acier", (x, y - 0.005, z0 + h / 2.0), (l * 0.94, 0.012, h * 0.965))
    k.b("noyau", (x, y - 0.012, z0 + h / 2.0), (l * 0.84, 0.012, h * 0.92))
    n = int(h / 0.075)
    for i in range(n):
        zz = z0 + h * (i + 0.6) / (n + 0.4)
        # plaques de serveurs : tiroirs de hauteurs inégales, certains éteints
        v = k.r.f()
        k.b("noir" if v < 0.72 else "acier", (x, y - 0.02, zz), (l * 0.78, 0.008, h / (n + 0.4) * 0.72))
        if v < 0.82:
            k.b(diodes, (x - l * 0.26 + k.r.f(0.0, 0.1), y - 0.026, zz), (l * (0.08 + 0.2 * k.r.f()), 0.006, 0.014))
        if v > 0.42:
            k.b("voyant_v" if v > 0.85 else "voyant_o" if v > 0.76 else diodes, (x + l * 0.3, y - 0.026, zz), (0.018, 0.006, 0.018))


def centre(S, k):
    M = k.M = P.matieres(S, "hitech")
    M["diode"] = P.lueur(S, "c_diode", (0.05, 0.42, 1.0), 4.0, 0.55, grad=(0.3, 1.9, 1.0, 0.35), part=0.55, echelle=18.0)
    # plancher technique sur pieds courts, nord plus haut
    k.sol("noir", 4, h=0.05, ch=0.22)
    for x, y in ((-1.72, -2.42), (1.72, -2.42), (-1.72, 2.42), (1.72, 2.42), (0.0, -2.42), (-1.72, 0.0), (1.72, 0.0)):
        k.pied("acier", x, y, 0.24, 0.07, "noir")
    k.poly("car2", [(-1.86, -2.58), (1.86, -2.58), (1.86, 2.58), (-1.86, 2.58)], 0.2, 0.3, 0.985)
    # allée froide : passage à plaque perforée, éclairée
    ay = -0.1
    k.bz("noyau", -0.42, ay, 0.3, 2.5, 1.14, 0.01)
    for i in range(10):
        k.b("acier", (-1.56 + i * 0.255, ay, 0.325), (0.015, 1.12, 0.012))
    # rangée nord (haute) et rangée sud (plus courte, on voit par-dessus)
    xs = [-1.42, -0.92, -0.42, 0.08, 0.58]
    for i, x in enumerate(xs):
        baie(k, x, ay + 0.58, 0.3, 0.47, 1.72 - (i % 2) * 0.1, 0.7)
    for i, x in enumerate(xs):
        if i != 3:
            baie(k, x, ay - 1.42, 0.3, 0.47, 1.05 + (i % 3) * 0.05, 0.62)
    # baie sortie, porte ouverte sur l'allée sud (le trou casse la rangée)
    k.caisson("noir", xs[3], ay - 1.12, 0.3, 0.47, 0.3, 0.32, 0.01)
    k.b("acier", (xs[3] + 0.25, ay - 1.62, 0.84), (0.015, 0.42, 0.88), rz=math.radians(18))
    k.b("noyau", (xs[3] + 0.26, ay - 1.62, 0.84), (0.012, 0.34, 0.78), rz=math.radians(18))
    # dessus des baies : chemins de câbles et flexibles entre les deux rangées
    for x in (-1.2, -0.42, 0.34):
        for dy in (-0.09, 0.0, 0.09):
            k.cable("caoutchouc", (x + dy, ay + 0.6, 1.98), (x + dy * 1.4, ay - 0.82, 1.37), 0.2, 0.02)
    k.bz("acier", -0.42, ay + 0.86, 2.02, 2.6, 0.2, 0.03)
    k.bz("jaune", -0.42, ay + 0.86, 2.05, 2.5, 0.06, 0.012)
    # collecteur d'eau : deux gros tuyaux au-dessus de la rangée nord, descentes vers chaque baie. DA-CALCUL (4/11) : ils
    # finissent dans une unité de distribution du liquide (CDU) au nord-est, DANS l'emprise (le bleu descendait au bord nord,
    # l'orange au bord est : justes face au nord seulement ; les raccords sont tracés par le moteur dans les 4 directions)
    zb = 2.24
    k.caisson("car2", 1.45, 1.5, 0.3, 0.8, 1.5, 1.35, 0.05)
    k.persiennes("acier", 1.45, 0.75, 0.42, 0.62, 0.42, 5)
    k.plaque("plaque", 1.3, 0.75, 1.12, 0.26, 0.12)
    k.voyant("voyant_v", 1.62, 0.74, 1.12, 0.02)
    k.voyant("diode", 1.7, 0.74, 1.12, 0.02)
    k.moteur("noir", 1.45, 1.95, 1.65, 0.42, 0.12, ailette="acier", axe="y")
    k.tuyau("bleu", [(-1.51, ay + 1.08, zb), (1.25, ay + 1.08, zb), (1.25, ay + 1.08, 1.65)], r=0.085, coude=0.22,
            brides=[(-1.47, ay + 1.08, zb), (-0.7, ay + 1.08, zb), (0.5, ay + 1.08, zb), (1.25, ay + 1.08, 1.78)], bride_mat="acier")
    k.tuyau("orange", [(-1.51, ay + 1.36, zb - 0.02), (1.62, ay + 1.36, zb - 0.02), (1.62, ay + 1.36, 1.65)], r=0.075, coude=0.22,
            brides=[(-1.47, ay + 1.36, zb - 0.02), (-0.2, ay + 1.36, zb - 0.02), (1.62, ay + 1.36, 1.76)], bride_mat="acier")
    for x in xs:
        k.tuyau("bleu", [(x - 0.09, ay + 1.08, zb), (x - 0.09, ay + 1.08, 1.95)], r=0.022, brides=[])
        k.tuyau("orange", [(x + 0.09, ay + 1.36, zb - 0.02), (x + 0.09, ay + 1.36, 1.95)], r=0.022, brides=[])
    k.vanne("acier", "rouge", (-0.95, ay + 1.08, zb + 0.08), 0.05)
    k.vanne("acier", "bleu", (0.32, ay + 1.36, zb + 0.06), 0.05)
    # climatiseur à l'est : caisson carrossé, ventilateurs sur le dessus, persiennes au sud
    cx = 1.38
    k.caisson("car", cx, -0.72, 0.3, 0.92, 2.2, 1.12, 0.09)
    k.persiennes("acier", cx, -1.83, 0.52, 0.74, 0.58, 8)
    k.plaque("plaque", cx - 0.16, -1.83, 1.2, 0.3, 0.1)
    k.voyant("diode", cx + 0.22, -1.84, 1.2, 0.022)
    k.voyant("voyant_v", cx + 0.32, -1.84, 1.2, 0.022)
    k.ventilo(cx, -1.2, 1.42, 0.34, corps="noir")
    k.ventilo(cx, -0.25, 1.42, 0.34, corps="noir", ph=(k.phase + 0.4) % 1.0)
    # radôme et antenne fouet au nord-ouest (signature de l'âge 10), coffret télécom
    k.caisson("car", -1.42, 2.02, 0.3, 0.8, 1.05, 0.72, 0.06)
    k.persiennes("acier", -1.42, 1.48, 0.42, 0.56, 0.36, 5)
    k.dome("car_lisse", -1.42, 2.08, 1.02, 0.42, 0.95, 30)
    k.tore("noir", -1.42, 2.08, 1.04, 0.42, 0.02, 30, 6)
    k.cyl("acier", -1.0, 2.34, 1.02, 3.1, 0.016, 6)
    k.cyl("noir", -1.0, 2.34, 1.02, 1.34, 0.038, 8)
    k.sph("voyant_r", (-1.0, 2.34, 3.12), 0.03, 8, 5)
    # groupe nord-est : armoire électrique et transfo
    k.caisson("car2", 0.5, 2.1, 0.3, 0.92, 0.98, 0.86, 0.05)
    k.persiennes("noir", 0.5, 1.6, 0.4, 0.7, 0.3, 4, fond="acier")
    k.voyant("voyant_o", 0.2, 1.6, 0.9, 0.02)
    k.chevrons(0.5, 1.6, 0.8, 0.86, 0.06)
    k.echelle("acier", 1.93, -1.1, 0.3, 1.4, axe="y")


def grand_centre(S, k):
    M = k.M = P.matieres(S, "supra")
    M["cyan"] = P.lueur(S, "c_cyan", (0.08, 0.86, 1.0), 4.0, 0.55, part=0.5, echelle=14.0)
    M["diode"] = P.lueur(S, "c_diode", (0.08, 0.72, 1.0), 3.8, 0.55, grad=(0.4, 3.2, 1.0, 0.3), part=0.55, echelle=18.0)
    k.sol("car2", 6, h=0.08, ch=0.5)
    cx, cy = -0.2, -0.45
    # socle circulaire à gradins
    k.rev("car2", cx, cy, [(0.05, 2.5), (0.26, 2.42), (0.26, 2.2), (0.42, 2.12), (0.42, 1.42)], 56)
    k.boulons_rond("plaque", cx, cy, 0.27, 2.31, 42, 0.022)
    # carrousel : 14 baies noires en rond, dos vers le noyau ; on ne monte que la moitié sud, le nord fait fond
    R = 1.62
    n = 16
    for i in range(n):
        a = math.tau * (i + 0.5) / n
        px, py = cx + R * math.cos(a), cy + R * math.sin(a)
        h = 2.3 + (i % 3) * 0.12
        rz = a + math.pi / 2
        k.b("noir", (px, py, 0.42 + h / 2.0), (0.56, 0.42, h), rz=rz)
        f = (px + 0.215 * math.cos(a), py + 0.215 * math.sin(a))
        k.b("plaque", (f[0], f[1], 0.42 + h / 2.0), (0.5, 0.012, h * 0.96), rz=rz)
        k.b("noyau", (f[0] + 0.006 * math.cos(a), f[1] + 0.006 * math.sin(a), 0.42 + h / 2.0), (0.44, 0.012, h * 0.92), rz=rz)
        if math.sin(a) < 0.2:
            for j in range(int(h / 0.13)):
                z = 0.5 + j * 0.13
                v = k.r.f()
                e = (px + 0.232 * math.cos(a), py + 0.232 * math.sin(a))
                dx = (k.r.f(-0.14, 0.14))
                if v < 0.78:
                    k.b("diode" if v < 0.64 else "voyant_o", (e[0] + dx * math.cos(rz), e[1] + dx * math.sin(rz), z), (0.05 + 0.12 * k.r.f(), 0.008, 0.02), rz=rz)
    # noyau noir froid, au-dessus des baies
    k.rev("noyau", cx, cy, [(0.42, 1.2), (2.65, 1.18), (2.85, 0.94), (3.1, 0.88), (3.1, 0.42), (3.62, 0.36), (3.76, 0.1)], 40)
    k.rev("plaque", cx, cy, [(2.86, 1.0), (2.9, 1.0), (2.9, 0.95)], 40, cap=False)
    # 3 anneaux chromés en lévitation : le signe de l'âge 12, vides visibles dessous
    for z, Ra, r_ in ((3.05, 2.1, 0.07), (3.45, 1.6, 0.06), (3.86, 1.1, 0.05)):
        k.mobile(True)
        k.tore("chrome", cx, cy, z, Ra, r_, 72, 12)
        for i in range(6):
            a = math.tau * (i + k.phase) / 6
            k.b("noyau", (cx + Ra * math.cos(a), cy + Ra * math.sin(a), z), (0.12, 0.2, 0.15), rz=a)
        k.mobile(False)
        k.tore("cyan", cx, cy, z - r_ * 1.05, Ra - r_ * 0.2, 0.011, 72, 6)
    # 4 pylônes noirs qui portent les anneaux (sans les toucher), nord et est plus hauts
    for x, y, h in ((-2.45, -2.95, 2.5), (2.05, -2.95, 2.5), (2.2, 2.2, 3.85), (-2.55, 2.1, 3.85)):
        k.poly("noir", [(x - 0.14, y - 0.14), (x + 0.14, y - 0.14), (x + 0.14, y + 0.14), (x - 0.14, y + 0.14)], 0.08, h, 0.55)
        k.cyl("chrome", x, y, h, h + 0.14, 0.05, 12)
        k.voyant_h("cyan", x, y, h + 0.14, 0.04)
    # conduites froides givrées. DA-CALCUL (4/11) : la grosse conduite part du groupe froid (elle venait du bord nord) ; les
    # tronçons qui touchaient les bords sud et est sont retirés (raccords : tracés par le moteur dans les 4 directions)
    k.tuyau("givre", [(0.42, 3.25, 0.5), (-0.5, 3.25, 0.5), (-0.5, 2.8, 0.5), (-0.5, 2.2, 1.0), (cx - 0.3, cy + 1.2, 2.8)], r=0.13, coude=0.3,
            bride_mat="plaque", brides=[(0.3, 3.25, 0.5), (-0.5, 2.5, 0.72)])
    k.tuyau("givre", [(1.95, -0.2, 0.42), (2.55, -0.2, 0.42), (2.55, 1.55, 0.42), (2.55, 1.95, 1.5)], r=0.09, coude=0.2, bride_mat="plaque")
    # groupe froid au nord-est, dewar givré
    k.cuve("givre", 2.1, 3.0, 0.08, 2.0, 0.5, 0.35)
    k.cerclages("plaque", 2.1, 3.0, (0.4, 0.95, 1.5), 0.5)
    k.caisson("noir", 1.0, 3.25, 0.08, 1.2, 1.1, 0.72, 0.05)
    k.persiennes("plaque", 1.0, 2.69, 0.16, 0.9, 0.4, 5)
    k.voyant("cyan", 0.55, 2.68, 0.66, 0.024)
    # armoires au sud-ouest et sud-est, chevrons
    k.armoire("car2", -2.1, -3.95, 0.08, 0.86, 0.72, 0.42, lampe="voyant")
    k.armoire("car2", 2.0, -3.95, 0.08, 0.7, 0.62, 0.42, lampe="voyant_o")
    k.chevrons(0.0, -3.92, 0.17, 2.0, 0.09)
