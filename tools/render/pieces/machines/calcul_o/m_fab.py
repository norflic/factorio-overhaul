"""FABRICATION des tranches (lot CALCUL-DESIGN, 01/11), âge 10 : lithographe à cristal (4×4), salle blanche (5×5), tireuse de
cristal (3×3), scie à fil (3×3), graveur à plasma (3×3). Chacune a un organe qui dit ce qu'elle fait, pas une boîte.
"""
import math

import geo as G
import organes as O
import palettes as P

D = O.D


def litho(S, k):
    """LITHOGRAPHE À CRISTAL : table noire sur 4 amortisseurs, colonne d'optique en anneaux empilés, tube laser couché au
    nord (fente de cristal lumineuse), miroir de renvoi coudé, robot de chargement et boîte de tranches au sud."""
    M = k.M = P.matieres(S, "hitech")
    M["laser"] = P.lueur(S, "c_laser", (0.25, 0.72, 1.0), 4.4, 0.55, part=0.55, echelle=20.0)
    M["uv"] = P.lueur(S, "c_uv", (0.42, 0.3, 1.0), 2.6, 0.5, grad=(0.55, 1.1, 1.0, 0.1), part=0.55, echelle=26.0)
    k.sol("noir", 4, h=0.05, ch=0.24)
    # table anti-vibrations : dalle noire épaisse, amortisseurs ronds
    tx, ty = -0.2, -0.55
    for sx in (-1, 1):
        for sy in (-1, 1):
            px, py = tx + sx * 0.98, ty + sy * 0.98
            k.rev("acier_clair", px, py, [(0.05, 0.2), (0.12, 0.2), (0.14, 0.13), (0.34, 0.13)], 18)
            k.rev("caoutchouc", px, py, [(0.2, 0.15), (0.3, 0.15)], 18, cap=False)
    k.caisson("graphite", tx, ty, 0.33, 2.4, 2.5, 0.24, 0.04)
    k.b("acier", (tx, ty - 1.26, 0.45), (2.3, 0.012, 0.03))
    # platine de tranche : disque de silicium visible, chariot mobile
    k.mobile(True)
    dx = 0.22 * math.sin(k.phase * math.tau)
    k.bz("car2", tx + dx, ty - 0.46, 0.57, 1.1, 1.14, 0.06)
    k.rev("silicium", tx + dx, ty - 0.46, [(0.63, 0.46), (0.665, 0.46)], 36)
    k.rev("acier_clair", tx + dx, ty - 0.46, [(0.63, 0.5), (0.66, 0.5), (0.66, 0.47)], 36, cap=False)
    k.mobile(False)
    # colonne d'optique : anneaux décroissants vers le bas, lumière violette dans le dernier étage
    zc = 0.82
    prof = [(zc, 0.2), (zc + 0.07, 0.27), (zc + 0.07, 0.41), (zc + 0.26, 0.45), (zc + 0.3, 0.56), (zc + 0.62, 0.58), (zc + 0.66, 0.68), (zc + 1.14, 0.7), (zc + 1.18, 0.56),
            (zc + 1.62, 0.52), (zc + 1.66, 0.34)]
    k.rev("car_lisse", tx, ty, prof, 40)
    for z in (zc + 0.29, zc + 0.65, zc + 1.16):
        k.tore("noir", tx, ty, z, {zc + 0.29: 0.52, zc + 0.65: 0.64, zc + 1.16: 0.66}[z], 0.024, 40, 6)
    for z, r_ in ((zc + 0.45, 0.57), (zc + 0.9, 0.7)):
        k.boulons_rond("riv", tx, ty, z, r_, 0, 0.01) if False else None
        for i in range(10):
            a = math.pi + i * math.pi / 9
            k.b("acier", (tx + (r_ + 0.008) * math.cos(a), ty + (r_ + 0.008) * math.sin(a), z), (0.024, 0.024, 0.18), rz=a)
    k.rev("uv", tx, ty, [(0.6, 0.28), (zc + 0.05, 0.2)], 30, cap=False)
    # montants de la colonne, câbles
    for a in (math.radians(25), math.radians(155), math.radians(270)):
        k.axe("acier_clair", (tx + 0.95 * math.cos(a), ty + 0.95 * math.sin(a), 0.57), (tx + 0.56 * math.cos(a), ty + 0.56 * math.sin(a), zc + 0.72), 0.04, 10)
    # tube laser au nord, couché est-ouest : gros carter, fente lumineuse, cristal
    ly = 2.05
    k.echangeur(-0.2, ly, 0.5, 2.5, 0.42, "car", "acier_clair", cerc=2)
    for x in (-1.3, 0.92):
        k.bz("car2", x, ly, 0.05, 0.2, 0.7, 0.55)
    k.b("noir", (-0.2, ly - 0.415, 1.02), (1.36, 0.03, 0.16))
    k.b("laser", (-0.2, ly - 0.432, 1.02), (1.26, 0.012, 0.075))
    for i in range(9):
        k.b("noir", (-0.8 + i * 0.15, ly - 0.44, 1.02), (0.022, 0.012, 0.1))
    k.rev("car2", 1.3, ly, [(0.92, 0.24), (1.1, 0.26), (1.38, 0.19)], 20)
    k.moteur("car2", -1.72, ly, 0.5, 0.4, 0.2)
    # renvoi : conduit coudé, boîte de miroir au-dessus de la colonne
    k.tuyau("acier_clair", [(-0.2, ly - 0.2, 1.42), (-0.2, ly - 0.2, 2.2), (-0.2, 0.42, 2.72), (tx, ty + 0.42, 2.72)], r=0.14, coude=0.26, bride_mat="noir",
            brides=[(-0.2, ly - 0.2, 1.6), (-0.2, 1.0, 2.5)])
    k.caisson("car", tx, ty + 0.1, 2.5, 0.72, 1.0, 0.42, 0.05)
    k.b("laser", (tx + 0.27, ty - 0.405, 2.72), (0.06, 0.012, 0.1))
    k.plaque("plaque", tx - 0.13, ty - 0.405, 2.72, 0.32, 0.14)
    # gauche : robot à 2 bras qui charge la platine, boîte de tranches ; droite : baie électronique
    k.caisson("car2", -1.6, -2.3, 0.05, 0.6, 0.66, 0.56, 0.04)
    k.rev("acier_clair", -1.65, -2.3, [(0.61, 0.13), (0.72, 0.13)], 16)
    k.axe("car_lisse", (-1.65, -2.3, 0.75), (-1.2, -1.7, 0.78), 0.05, 10)
    k.axe("car_lisse", (-1.2, -1.7, 0.78), (-0.75, -1.45, 0.72), 0.04, 10)
    k.rev("noir", -1.2, -1.7, [(0.71, 0.075), (0.85, 0.075)], 12)
    k.b("acier_clair", (-0.68, -1.4, 0.7), (0.2, 0.2, 0.012))
    k.caisson("car_lisse", -0.9, -2.45, 0.05, 0.5, 0.42, 0.34, 0.03)
    k.b("verre", (-0.9, -2.66, 0.22), (0.4, 0.01, 0.2))
    k.armoire("car2", 1.58, -1.8, 0.05, 0.62, 1.15, 0.62, lampe="laser")
    k.persiennes("noir", 1.58, -1.82, 0.14, 0.42, 0.34, 5, fond="acier")
    k.voyant("voyant_v", 1.72, -1.84, 1.08, 0.02)
    # coffret eau de refroidissement, tuyau bleu, flexibles noirs
    k.tuyau("bleu", [(1.72, 2.55, 0.14), (1.72, -0.4, 0.14), (1.72, -1.1, 0.5)], r=0.055, coude=0.2)
    k.flexible("caoutchouc", [(1.25, -1.1, 1.2), (1.0, -0.6, 1.5), (0.5, -0.5, 1.5)], 0.03)
    k.flexible("caoutchouc", [(1.25, -1.3, 1.1), (0.95, -0.9, 1.28), (0.5, -0.85, 1.1)], 0.025)
    k.vanne("acier", "rouge", (1.72, 1.0, 0.2), 0.05)


def salle(S, k):
    """SALLE BLANCHE : coupole de pression lisse, hublot ambré à lumière de photolithographie, gaines d'air annelées qui la
    ceignent, batterie de filtres et ventilateurs au nord, sas au sud, cuves de résine à l'est : un organisme, pas un immeuble."""
    M = k.M = P.matieres(S, "hitech")
    M["ambre"] = P.lueur(S, "c_ambre", (1.0, 0.56, 0.1), 1.8, 0.4, grad=(1.1, 2.1, 1.0, 0.18), part=0.7, echelle=7.0)
    k.sol("noir", 5, h=0.06, ch=0.34)
    cx, cy = -0.28, -0.4
    # socle sur pieds courts
    for i in range(10):
        a = math.tau * i / 10
        k.pied("acier", cx + 2.0 * math.cos(a), cy + 2.0 * math.sin(a), 0.32, 0.075, "noir")
    k.rev("car2", cx, cy, [(0.28, 2.05), (0.4, 2.1), (0.5, 2.0), (0.5, 1.5)], 56)
    # corps : tambour puis coupole lisse
    R = 1.86
    k.rev("car", cx, cy, [(0.5, R), (1.12, R)], 60, cap=False)
    k.dome("car_lisse", cx, cy, 1.12, R, 0.56, 60)
    k.tore("noir", cx, cy, 1.13, R + 0.01, 0.025, 60, 6)
    for i in range(16):                        # méridiens : tôles de coupole
        a = math.pi * 0.05 + i * math.pi / 8
        pts = []
        for t in range(0, 9):
            th = t / 9.0 * math.pi / 2 * 0.9
            rr = R * math.cos(th) + 0.012
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), 1.12 + R * 0.56 * math.sin(th)))
        k.put("acier", G.tube(pts, 0.011, 5))
    # grand hublot ambré, courbe, au sud-est de la coupole : la lumière de la photolithographie
    def calotte(a0, a1, t0, t1, mat, dr=0.0, n=14, m=6):
        rings = []
        for j in range(m + 1):
            th = t0 + (t1 - t0) * j / m
            ring = []
            for i in range(n + 1):
                a = a0 + (a1 - a0) * i / n
                rr = (R + dr) * math.cos(th)
                ring.append((cx + rr * math.cos(a), cy + rr * math.sin(a), 1.12 + (R + dr) * 0.56 * math.sin(th)))
            rings.append(ring)
        k.put(mat, G.loft(rings, closed=False))
    calotte(math.radians(244), math.radians(306), 0.05, 0.5, "ambre", 0.01)
    for i in range(9):
        a = math.radians(244 + i * 62 / 8.0)
        calotte(a - 0.016, a + 0.016, 0.03, 0.53, "noir", 0.022, 1, 5)
    for t in (0.03, 0.18, 0.34, 0.52):
        calotte(math.radians(242), math.radians(308), t - 0.016, t + 0.016, "noir", 0.022, 12, 1)
    # gaine d'air annelée qui ceinture la coupole, trois descentes
    prof_gaine = math.radians
    pts = [(cx + (R + 0.14) * math.cos(a), cy + (R + 0.14) * math.sin(a), 0.78) for a in [prof_gaine(150 + 6 * i) for i in range(21)]]
    k.put("isolant", G.tube(pts, 0.17, 12, rfun=lambda s, i: 0.17 * (1.0 + 0.06 * math.sin(s / 0.22 * math.tau))))
    # batterie de filtres sur le toit : 4 ventilateurs dans un caisson en arc, plus haut que la coupole
    fy = cy + 0.62
    k.caisson("car", cx - 0.1, fy, 2.0, 2.05, 1.05, 0.34, 0.05)
    for i in range(3):
        k.ventilo(cx - 0.76 + i * 0.68, fy + 0.03, 2.47, 0.27, corps="noir", ph=(k.phase + i * 0.31) % 1.0, lames=6)
    k.persiennes("acier", cx - 0.1, fy - 0.53, 2.04, 1.9, 0.24, 4)
    # grosses gaines au nord : deux coudes annelés qui montent vers les filtres
    for x, xt in ((-1.6, cx - 0.8), (0.9, cx + 0.72)):
        ctrl = [(x, 3.2, 0.4), (x, 2.6, 0.5), (x, 2.0, 1.5), (xt, fy + 0.55, 2.16)]
        k.put("isolant", G.tube(G.catmull(ctrl, 8), 0.21, 12, rfun=lambda s, i: 0.21 * (1.0 + 0.07 * math.sin(s / 0.18 * math.tau))))
    k.caisson("car2", -0.4, 3.05, 0.06, 3.55, 0.82, 0.62, 0.04)
    k.persiennes("noir", -0.4, 2.63, 0.13, 1.1, 0.38, 5, fond="acier")
    # sas au sud : tunnel cylindrique couché, porte à sa bouche
    sx = -1.1
    k.echangeur(sx, -3.05, 0.1, 0.7, 0.55, "car", "acier_clair", axe="y", cerc=1, tetes=True)
    k.b("noyau", (sx, -3.58, 0.6), (0.58, 0.02, 0.76))
    k.b("car2", (sx - 0.14, -3.6, 0.6), (0.26, 0.012, 0.72))
    k.b("car2", (sx + 0.14, -3.6, 0.6), (0.26, 0.012, 0.72))
    k.b("ambre", (sx - 0.14, -3.61, 0.82), (0.14, 0.006, 0.14))
    k.b("ambre", (sx + 0.14, -3.61, 0.82), (0.14, 0.006, 0.14))
    k.chevrons(sx, -3.6, 0.18, 0.74, 0.06)
    # cuves de résine et d'eau ultrapure à l'est : rouge et bleu, conduites qui entrent dans la coupole
    for i, (x, y, r_, h, c) in enumerate(((2.05, -1.4, 0.36, 1.85, "orange"), (2.0, -0.28, 0.32, 1.55, "bleu"), (2.1, 0.86, 0.3, 1.3, "car2"))):
        k.cuve(c, x, y, 0.06, h, r_, 0.34, 28)
        k.cerclages("acier", x, y, (0.42, h - 0.5), r_)
        k.tuyau("acier_clair", [(x - r_, y, 0.8 + i * 0.1), (x - r_ - 0.18, y, 0.8 + i * 0.1), (cx + R - 0.02, y * 0.72 + cy * 0.2, 0.86 + i * 0.1)], r=0.03, coude=0.1, brides=[], bride_mat="acier")
    k.vanne("acier", "rouge", (1.66, -1.1, 0.88), 0.045)
    k.tuyau("orange", [(2.05, -2.5, 0.18), (2.05, -1.75, 0.18)], r=0.05, brides=[(2.05, -2.5, 0.18)], bride_mat="acier")
    # coffrets et radôme minuscule, antenne
    k.armoire("car2", 1.7, -3.15, 0.06, 0.9, 0.78, 0.3, lampe="voyant")
    k.voyant("voyant_v", 1.86, -3.17, 0.74, 0.02)
    k.dome("car_lisse", cx + 1.2, fy + 0.2, 2.0, 0.24, 0.95, 20) if False else None
    k.cyl("acier", 1.05, 1.85, 1.9, 3.5, 0.014, 6)
    k.bz("car2", 1.05, 1.85, 0.06, 0.4, 0.4, 1.92)
    k.sph("voyant_r", (1.05, 1.85, 3.52), 0.028, 8, 5)


def tireuse(S, k):
    """TIREUSE DE CRISTAL (Czochralski) : chambre ronde au hublot orange, col, long tube vertical où monte le lingot, tête à
    moteur et câble au sommet ; argon et eau en lignes colorées. Haute et mince."""
    M = k.M = P.matieres(S, "hitech")
    M["bain"] = P.lueur(S, "c_bain", (1.0, 0.5, 0.1), 4.4, 0.6, part=0.6, echelle=16.0)
    k.sol("noir", 3, h=0.05, ch=0.18)
    cx, cy = -0.15, -0.28
    k.caisson("car2", cx, cy, 0.05, 2.1, 2.5, 0.28, 0.04)
    for a in (40, 140, 220, 320):
        r_ = math.radians(a)
        k.pied("acier", cx + 0.78 * math.cos(r_), cy + 0.78 * math.sin(r_), 0.72, 0.06, "noir")
    # chambre de fusion : ventrue, double paroi, deux étages boulonnés
    k.rev("car_lisse", cx, cy, [(0.55, 0.5), (0.66, 0.84), (0.72, 0.9), (1.22, 0.9), (1.32, 0.82), (1.32, 0.42)], 44)
    k.tore("noir", cx, cy, 0.72, 0.905, 0.03, 44, 6)
    k.tore("acier_clair", cx, cy, 1.26, 0.87, 0.022, 44, 6)
    for i in range(18):
        a = math.tau * i / 18
        k.axe("acier", (cx + 0.91 * math.cos(a), cy + 0.91 * math.sin(a), 0.74), (cx + 0.91 * math.cos(a), cy + 0.91 * math.sin(a), 0.82), 0.014, 5)
    # hublot : tube court vers le sud, verre brûlant
    hp = (cx + 0.35, cy - 0.86, 1.02)
    k.axe("acier_clair", (hp[0], hp[1] + 0.1, hp[2]), (hp[0], hp[1] - 0.14, hp[2]), 0.16, 18)
    k.axe("noir", (hp[0], hp[1] - 0.14, hp[2]), (hp[0], hp[1] - 0.15, hp[2]), 0.13, 18, cap=False)
    k.put("bain", G.oriente(G.tour([(0.0, 0.12), (0.01, 0.0)], 18, "z"), (hp[0], hp[1] - 0.15, hp[2]), (0.0, -1.0, 0.0)))
    k.axe("car2", (cx - 0.5, cy - 0.76, 1.0), (cx - 0.5, cy - 0.94, 1.0), 0.09, 14)
    # col et long tube vertical, à brides, la tête au sommet
    k.cyl("car_lisse", cx, cy, 1.32, 3.72, 0.27, 28)
    k.cerclages("acier_clair", cx, cy, (1.45, 2.1, 2.75, 3.4), 0.27, e=0.028, h=0.04)
    k.b("verre", (cx, cy - 0.27, 2.45), (0.16, 0.02, 0.8))
    k.b("noir", (cx, cy - 0.265, 2.45), (0.2, 0.012, 0.84))
    # lingot qu'on devine dans la fente : couleur argent, monte très lentement
    k.mobile(True)
    k.b("silicium", (cx, cy - 0.285, 2.4 + 0.05 * math.sin(k.phase * math.tau)), (0.09, 0.012, 0.7))
    k.mobile(False)
    k.rev("car", cx, cy, [(3.72, 0.34), (3.98, 0.36), (4.1, 0.3), (4.22, 0.14)], 26)
    k.moteur("car2", cx + 0.4, cy, 3.82, 0.5, 0.15)
    k.rev("noir", cx, cy, [(4.22, 0.05), (4.56, 0.05)], 10)
    k.rev("acier_clair", cx, cy, [(4.56, 0.14), (4.64, 0.14)], 16)
    k.voyant_h("voyant", cx, cy, 4.64, 0.03)
    # charpente arrière qui tient le tube, échelle
    bx = cx + 0.1
    for x in (bx - 0.45, bx + 0.45):
        k.axe("car2", (x, cy + 0.98, 0.3), (x, cy + 0.42, 3.55), 0.05, 8)
    k.treillis("acier", (bx - 0.45, cy + 0.42, 3.42), (bx + 0.45, cy + 0.42, 3.42), 0.2, 3)
    k.axe("acier", (bx - 0.3, cy + 0.34, 3.45), (bx - 0.26, cy + 0.22, 3.45), 0.02, 6)
    k.echelle("acier", cx - 0.42, cy - 0.15, 1.32, 3.6, 0.15)
    # ligne d'argon (bouteilles au nord-ouest) et eau
    for i, (x, y) in enumerate(((-1.18, 1.0), (-0.84, 1.42), (-1.2, 1.62))):
        k.cuve("bleu" if i != 1 else "vert", x, y, 0.05, 1.35, 0.14, 0.5, 14)
        k.cyl("acier", x, y, 1.35, 1.42, 0.04, 8)
    k.tuyau("acier_clair", [(-1.18, 1.0, 1.42), (-1.18, 0.62, 1.42), (cx - 0.15, 0.62, 1.42), (cx - 0.15, cy + 0.4, 1.38)], r=0.022, coude=0.12, brides=[])
    k.tuyau("bleu", [(1.32, 1.6, 0.14), (1.32, -0.3, 0.14), (cx + 0.86, cy, 0.86)], r=0.05, coude=0.2)
    k.tuyau("orange", [(1.15, 1.6, 0.14), (1.15, 0.35, 0.14), (cx + 0.78, cy + 0.3, 1.02)], r=0.05, coude=0.2)
    k.caisson("car", 0.85, 1.7, 0.05, 0.92, 0.6, 1.02, 0.05)
    k.persiennes("acier", 0.85, 1.39, 0.13, 0.72, 0.42, 5)
    k.voyant("voyant", 0.55, 1.39, 0.86, 0.02)
    k.armoire("car2", 0.95, -1.9, 0.05, 0.62, 0.6, 0.3, lampe="voyant_v")
    k.flexible("caoutchouc", [(cx + 0.2, cy + 0.2, 3.9), (0.55, 1.0, 3.2), (0.9, 1.6, 1.1)], 0.022)


def scie(S, k):
    """SCIE À FIL : grosses bobines et rouleaux cannelés, nappe de fils brillants tendue entre eux, lingot serré au-dessus,
    bac à boue en dessous. Le rouleau tourne. DA-CALCUL (4/11) : lueur de travail lisible (rampe de LED sous le portique qui
    éclaire la nappe, pupitre à écran, colonne lumineuse)."""
    import m_froid as F
    M = k.M = P.matieres(S, "hitech")
    F.lueurs_travail(S, M)
    k.sol("noir", 3, h=0.05, ch=0.18)
    cy = -0.42
    k.caisson("car2", 0.0, cy, 0.05, 2.75, 2.65, 0.42, 0.05)
    k.bz("orange", 0.0, cy, 0.47, 1.3, 1.6, 0.03)
    k.bz("noyau", 0.0, cy, 0.5, 1.15, 1.44, 0.015)
    # deux rouleaux cannelés est et ouest, axe nord-sud, sur paliers
    def rouleau(x, r_):
        k.put("car_lisse", G.tour([(cy - 0.88, 0.001), (cy - 0.88, r_), (cy + 0.88, r_), (cy + 0.88, 0.001)], 28, "y", (x, 0.0, 1.02)))
        k.mobile(True)
        a0 = k.phase * math.tau / 8
        for i in range(8):
            a = a0 + math.tau * i / 8
            x1, z1 = x + (r_ + 0.008) * math.cos(a), 1.02 + (r_ + 0.008) * math.sin(a)
            k.axe("acier", (x1, cy - 0.86, z1), (x1, cy + 0.86, z1), 0.012, 5)
        k.mobile(False)
        for i in range(11):
            yy = cy - 0.72 + i * 0.144
            k.put("acier_clair", G.tour([(yy - 0.03, r_), (yy - 0.03, r_ + 0.006), (yy + 0.03, r_ + 0.006), (yy + 0.03, r_)], 28, "y", (x, 0.0, 1.02)))
        for yy in (cy - 1.02, cy + 1.02):
            k.bz("car", x, yy, 0.47, 0.5, 0.22, 0.94)
            k.axe("acier_clair", (x, yy - 0.13, 1.02), (x, yy + 0.13, 1.02), 0.12, 16)
            k.rivets("riv", [(x + 0.2 * sg, yy - 0.112, z) for sg in (-1, 1) for z in (0.6, 1.3)], (0, -1, 0), 0.016)
    rouleau(-0.92, 0.33)
    rouleau(0.92, 0.33)
    # nappe de fils : 11 fils brillants, en haut et en bas
    for i in range(11):
        yy = cy - 0.72 + i * 0.144
        for z in (1.355, 0.69):
            k.axe("chrome", (-0.92, yy, z), (0.92, yy, z), 0.0085, 4)
    # lingot : gros cylindre de silicium couché nord-sud, serré dans sa poutre au-dessus de la nappe
    k.put("silicium", G.tour([(cy - 0.82, 0.001), (cy - 0.82, 0.37), (cy + 0.82, 0.37), (cy + 0.82, 0.001)], 32, "y", (0.0, 0.0, 1.72)))
    k.bz("car", 0.0, cy, 2.04, 0.74, 1.95, 0.22)
    k.bz("noir", 0.0, cy, 2.24, 0.4, 1.7, 0.08)
    for yy in (cy - 0.7, cy + 0.7):
        k.bz("acier", 0.0, yy, 1.98, 0.84, 0.1, 0.12)
    # glissières de la poutre : 4 colonnes chromées, vérin au-dessus
    for x, y in ((-1.2, cy - 0.98), (1.2, cy - 0.98), (-1.2, cy + 0.98), (1.2, cy + 0.98)):
        k.cyl("chrome", x, y, 0.47, 2.88, 0.045, 10)
    k.caisson("car", 0.0, cy, 2.86, 2.72, 2.2, 0.2, 0.04) if False else None
    for y in (cy - 0.98, cy + 0.98):
        k.bz("car", 0.0, y, 2.84, 2.62, 0.2, 0.14)
    for x in (-1.2, 1.2):
        k.bz("car", x, cy, 2.84, 0.2, 1.9, 0.14)
    k.cyl("chrome", 0.0, cy, 2.3, 2.9, 0.06, 10)
    k.bz("car2", 0.0, cy, 2.86, 0.62, 0.62, 0.32)
    # bobines de fil neuf et usé au nord : gros disques, moteur
    by = 1.45
    for x, m_ in ((-0.72, "cuivre"), (0.72, "acier_clair")):
        k.put(m_, G.tour([(by - 0.2, 0.001), (by - 0.2, 0.28), (by + 0.2, 0.28), (by + 0.2, 0.001)], 26, "y", (x, 0.0, 0.62)))
        for yy in (by - 0.2, by + 0.2):
            k.put("noir", G.tour([(yy - 0.02, 0.001), (yy - 0.02, 0.4), (yy + 0.02, 0.4), (yy + 0.02, 0.001)], 30, "y", (x, 0.0, 0.62)))
    k.bz("car2", 0.0, by, 0.05, 2.5, 0.76, 0.22)
    k.cable("chrome", (-0.72, by - 0.1, 0.88), (-0.92, cy + 0.72, 1.36), 0.02, 0.0085, 5)
    k.cable("chrome", (0.72, by - 0.1, 0.88), (0.92, cy + 0.72, 1.36), 0.02, 0.0085, 5)
    # boue d'abrasif : tuyau orange, pompe, bidon
    k.cuve("orange", 1.15, -1.98, 0.05, 0.72, 0.26, 0.22, 20)
    k.tuyau("orange", [(1.15, -1.75, 0.6), (1.32, -1.0, 0.6), (1.32, cy, 1.6), (0.46, cy, 1.6)], r=0.03, coude=0.14, brides=[(1.32, -0.9, 0.72)], bride_mat="acier")
    k.armoire("car2", -0.82, -1.9, 0.05, 0.62, 0.44, 0.2, lampe="voyant")
    k.chevrons(0.25, -1.76, 0.2, 0.9, 0.08)
    # lueur de travail : rampe de LED sur la face sud de la traverse basse du portique, pupitre à écran, colonne lumineuse
    yt = cy - 0.98 - 0.1
    k.b("noir", (0.0, yt - 0.006, 2.88), (2.3, 0.014, 0.075))
    k.b("led", (0.0, yt - 0.015, 2.88), (2.2, 0.006, 0.048))
    k.caisson("car2", -0.82, -1.62, 0.49, 0.5, 0.16, 0.4, 0.02)
    F.ecran(k, -0.82, -1.7, 0.71, 0.4, 0.24)
    F.colonne_lumineuse(k, 1.2, cy - 0.98, 2.98)


def graveur(S, k):
    """GRAVEUR À PLASMA (grappe) : chambre de transfert hexagonale au centre, quatre chambres rondes aux couvercles bobinés,
    hublots magenta qui brillent, boîte à gaz à vannes rouges. Vue du dessus, une fleur de métal."""
    M = k.M = P.matieres(S, "hitech")
    M["plasma"] = P.lueur(S, "c_plasma", (0.9, 0.2, 1.0), 4.6, 0.6, part=0.65, echelle=15.0)
    k.sol("noir", 3, h=0.05, ch=0.18)
    cx, cy = 0.0, -0.32
    # hexagone central sur pieds
    hexa = [(cx + 0.72 * math.cos(math.radians(30 + 60 * i)), cy + 0.72 * math.sin(math.radians(30 + 60 * i))) for i in range(6)]
    for x, y in hexa:
        k.pied("acier", x, y, 0.5, 0.06, "noir")
    k.poly("car2", hexa, 0.44, 0.92, 1.0)
    k.poly("car_lisse", hexa, 0.92, 1.02, 0.92)
    k.rev("acier_clair", cx, cy, [(1.02, 0.36), (1.08, 0.36), (1.08, 0.2), (1.16, 0.14)], 26)
    k.boulons_rond("riv", cx, cy, 1.03, 0.54, 12, 0.016)
    # 4 chambres rondes : sud-ouest, sud-est, nord-ouest, nord-est
    def chambre(a, R, r_, h, plasma=True):
        x, y = cx + R * math.cos(math.radians(a)), cy + R * math.sin(math.radians(a))
        k.pied("acier", x, y, 0.42, 0.08, "noir")
        k.rev("car_lisse", x, y, [(0.36, r_ * 0.7), (0.46, r_), (h, r_), (h + 0.06, r_ + 0.02)], 30)
        k.tore("acier_clair", x, y, h, r_ + 0.012, 0.024, 30, 6)
        k.dome("car2", x, y, h + 0.06, r_ * 0.84, 0.6, 28)
        for i in range(5):                  # bobine de cuivre sur le couvercle
            k.tore("cuivre", x, y, h + 0.17 + 0.04 * i, r_ * (0.68 - 0.1 * i), 0.024, 22, 6)
        k.cyl("noir", x, y, h + 0.36, h + 0.5, 0.05, 8)
        if plasma:
            k.axe("acier_clair", (x, y - r_ + 0.06, 0.78), (x, y - r_ - 0.09, 0.78), 0.13, 18)
            k.put("plasma", G.oriente(G.tour([(0.0, 0.1), (0.008, 0.0)], 16, "z"), (x, y - r_ - 0.09, 0.78), (0.0, -1.0, 0.0)))
        # liaison vers le centre
        k.axe("car2", (cx + 0.55 * math.cos(math.radians(a)), cy + 0.55 * math.sin(math.radians(a)), 0.74), (x, y, 0.74), 0.15, 12)
    chambre(138, 1.2, 0.47, 1.22)
    chambre(42, 1.2, 0.47, 1.22)
    chambre(232, 1.2, 0.47, 1.05)
    chambre(308, 1.2, 0.47, 1.05)
    # boîte à gaz au sud, vannes, lignes de cuivre : chacune vers sa chambre
    k.caisson("car", 0.0, -1.98, 0.05, 1.38, 0.44, 0.34, 0.03)
    for i in range(4):
        x = -0.5 + i * 0.33
        k.vanne("acier", "rouge", (x, -1.95, 0.39), 0.035, 0.05)
    k.tuyau("cuivre", [(-0.4, -1.76, 0.3), (-0.4, -1.5, 0.3), (-0.72, -1.4, 0.72)], r=0.022, coude=0.1, brides=[])
    k.tuyau("cuivre", [(0.4, -1.76, 0.3), (0.4, -1.5, 0.3), (0.72, -1.4, 0.72)], r=0.022, coude=0.1, brides=[])
    # générateurs HF et pompes à vide au nord, câbles
    k.caisson("car2", 0.72, 1.7, 0.05, 1.3, 0.55, 0.72, 0.04)
    k.persiennes("acier", 0.72, 1.42, 0.15, 1.0, 0.36, 5)
    k.voyant("plasma", 0.25, 1.41, 0.65, 0.024)
    k.voyant("voyant", 0.42, 1.41, 0.65, 0.02)
    for x in (-0.95, -0.42):
        k.cuve("car", x, 1.72, 0.05, 0.92, 0.22, 0.2, 18)
        k.cerclages("acier", x, 1.72, (0.3, 0.7), 0.22)
    k.tuyau("acier_clair", [(-0.42, 1.5, 0.6), (-0.42, 0.9, 0.6), (0.4, 0.55, 0.5)], r=0.05, coude=0.2, bride_mat="noir", brides=[(-0.42, 1.2, 0.6)])
    for dx in (-0.1, 0.1):
        k.cable("caoutchouc", (0.3 + dx, 1.45, 0.72), (0.9 + dx, 0.55, 1.75), 0.05, 0.018)
    k.tuyau("bleu", [(-1.42, 1.9, 0.12), (-1.42, -1.3, 0.12)], r=0.05, brides=[])
    k.armoire("car2", 1.1, -1.97, 0.05, 0.56, 0.48, 0.2, lampe="voyant_v")
