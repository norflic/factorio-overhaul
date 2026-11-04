"""ASSEMBLAGE du calcul (lot CALCUL-DESIGN, 01/11), âge 10 : banc de test (3×3), ligne de boîtier (3×3), ligne CMS (4×4), tour de
fibrage (3×3), atelier d'intégration des baies (4×4). Chacune se lit par son organe : tranche et portique, bobines, cartes
sur tapis, tour et bobine de fibre, pont qui lève une baie.
"""
import math

import geo as G
import organes as O
import palettes as P

D = O.D


def carte_cms(k, x, y, z, lx, ly):
    k.bz("vert", x, y, z, lx, ly, 0.02)
    for j in range(4):
        k.b("cuivre", (x, y - ly / 2.0 + ly * (j + 0.5) / 4, z + 0.024), (lx * 0.8, 0.012, 0.006))
    k.bz("noir", x - lx * 0.18, y + ly * 0.14, z + 0.02, lx * 0.26, ly * 0.28, 0.03)
    k.bz("noir", x + lx * 0.22, y - ly * 0.18, z + 0.02, lx * 0.14, ly * 0.16, 0.024)


def testeur(S, k):
    """BANC DE DÉCOUPE ET TEST : bloc de granit, plateau à tranche irisée, portique à tête de sondes qui balaie (mobile), scie de
    découpe et piles de plateaux de puces, moniteur sur bras."""
    M = k.M = P.matieres(S, "hitech")
    M["ecran"] = P.lueur(S, "c_ecran", (0.1, 0.65, 1.0), 1.5, 0.42, part=0.8, echelle=30.0)
    M["sonde"] = P.lueur(S, "c_sonde", (1.0, 0.9, 0.55), 2.8, 0.55, part=0.5, echelle=22.0, grad=(0.75, 0.95, 1.0, 0.5))
    k.sol("noir", 3, h=0.05, ch=0.18)
    cy = -0.42
    for x, y in ((-1.2, cy - 1.0), (1.2, cy - 1.0), (-1.2, cy + 1.0), (1.2, cy + 1.0)):
        k.pied("acier", x, y, 0.34, 0.07, "noir")
    k.caisson("graphite", 0.0, cy, 0.3, 2.7, 2.5, 0.34, 0.05)
    # tranche sur son plateau : grand disque, grille de puces
    wx, wy = -0.1, cy - 0.12
    k.rev("acier_clair", wx, wy, [(0.64, 0.92), (0.69, 0.92), (0.69, 0.84)], 44)
    k.rev("silicium", wx, wy, [(0.69, 0.82), (0.705, 0.82)], 44)
    for i in range(-3, 4):
        for j in range(-3, 4):
            if i * i + j * j < 12:
                v = (i * 7 + j * 3) % 5
                c = "cuivre" if v == 0 else "bleu" if v == 1 else "acier_clair" if v == 2 else "noir"
                k.b(c, (wx + i * 0.2, wy + j * 0.2, 0.71), (0.17, 0.17, 0.006))
    # portique sur rails est-ouest, tête qui balaie
    k.mobile(True)
    gy = cy + 0.0 + 0.5 * math.sin(k.phase * math.tau)
    hx = wx + 0.42 * math.cos(k.phase * math.tau)
    for sg in (-1, 1):
        k.bz("car", sg * 1.2, gy, 0.64, 0.2, 0.3, 0.66)
    k.caisson("car", 0.0, gy, 1.3, 2.6, 0.32, 0.22, 0.04)
    k.bz("noir", 0.0, gy - 0.165, 1.33, 2.4, 0.012, 0.1)
    k.bz("car_lisse", hx, gy - 0.2, 0.92, 0.3, 0.24, 0.6)
    k.cyl("acier_clair", hx, gy - 0.2, 0.8, 0.92, 0.09, 12)
    k.tore("sonde", hx, gy - 0.2, 0.76, 0.14, 0.018, 20, 6)
    for i in range(6):
        a = math.tau * i / 6
        k.axe("acier", (hx + 0.1 * math.cos(a), gy - 0.2 + 0.1 * math.sin(a), 0.8), (hx + 0.03 * math.cos(a), gy - 0.2 + 0.03 * math.sin(a), 0.72), 0.006, 4)
    k.mobile(False)
    # scie de découpe au nord-est : capot jaune et lame
    k.caisson("jaune", 0.92, 1.3, 0.05, 0.84, 1.0, 0.82, 0.06)
    k.b("verre", (0.92, 0.79, 0.56), (0.62, 0.012, 0.3))
    k.persiennes("acier", 0.92, 0.79, 0.14, 0.62, 0.2, 4)
    k.ventilo(0.92, 1.35, 0.92, 0.24, corps="noir", lames=5)
    # piles de plateaux de puces au nord-ouest
    k.caisson("car2", -0.9, 1.45, 0.05, 1.0, 0.8, 0.3, 0.03)
    for i, (x, y) in enumerate(((-1.12, 1.3), (-0.68, 1.3), (-1.12, 1.68), (-0.68, 1.65))):
        for j in range(3 + (i % 2) * 3):
            z = 0.35 + j * 0.055
            k.bz("noir" if j % 2 else "acier", x, y, z, 0.36, 0.3, 0.045)
        k.b("cuivre", (x, y, 0.36 + (3 + (i % 2) * 3) * 0.055), (0.28, 0.2, 0.006))
    # moniteur sur bras et pupitre au sud-ouest
    k.caisson("car2", -1.05, -1.98, 0.05, 0.7, 0.34, 0.5, 0.03)
    k.axe("acier_clair", (-1.05, -1.9, 0.55), (-1.05, -1.9, 0.92), 0.02, 6)
    k.b("noir", (-1.05, -1.93, 1.1), (0.56, 0.05, 0.38), rx=math.radians(-12))
    k.b("ecran", (-1.05, -1.97, 1.1), (0.48, 0.012, 0.3), rx=math.radians(-12))
    k.tuyau("bleu", [(1.35, 0.55, 0.12), (1.35, -1.6, 0.12)], r=0.04, brides=[])
    k.flexible("caoutchouc", [(0.5, gy_fixe(cy) + 0.2, 1.46), (0.9, 0.3, 1.5), (0.92, 0.8, 0.95)], 0.02)
    k.voyant("voyant", 0.72, -1.85, 0.5, 0.022) if False else None
    k.armoire("car2", 0.72, -1.92, 0.05, 0.62, 0.42, 0.14, lampe="voyant_v")


def gy_fixe(cy):
    return cy


def boitier(S, k):
    """LIGNE DE MISE EN BOÎTIER : deux grandes bobines de cadre (lead-frame) dressées, presse de moulage à 4 colonnes, four à
    fente, tapis de sortie à plateaux de puces noires. Les bobines tournent."""
    M = k.M = P.matieres(S, "hitech")
    M["four"] = P.lueur(S, "c_four", (1.0, 0.42, 0.08), 3.6, 0.55, part=0.6, echelle=24.0)
    k.sol("noir", 3, h=0.05, ch=0.18)
    def bobine(x, y, R, mat="cuivre"):
        """Bobine verticale, axe nord-sud : flancs, spire, moyeu tournant."""
        z = 0.2 + R
        for yy, e in ((y - 0.14, 0.02), (y + 0.14, 0.02)):
            k.put("car_lisse", G.tour([(yy - e, 0.001), (yy - e, R), (yy + e, R), (yy + e, 0.001)], 34, "y", (x, 0.0, z)))
        k.put(mat, G.tour([(y - 0.12, 0.001), (y - 0.12, R * 0.84), (y + 0.12, R * 0.84), (y + 0.12, 0.001)], 34, "y", (x, 0.0, z)))
        k.mobile(True)
        a0 = k.phase * math.tau / 5
        for i in range(5):
            a = a0 + math.tau * i / 5
            k.axe("noir", (x + 0.09 * math.cos(a), y - 0.165, z + 0.09 * math.sin(a)), (x + R * 0.82 * math.cos(a), y - 0.165, z + R * 0.82 * math.sin(a)), 0.024, 5)
        k.axe("acier_clair", (x, y - 0.18, z), (x, y - 0.14, z), 0.1, 14)
        k.mobile(False)
        k.bz("car2", x, y, 0.05, R * 1.5, 0.42, 0.18)
        for sg in (-1, 1):
            k.axe("car2", (x + sg * R * 0.62, y - 0.2, 0.2), (x, y - 0.2, z), 0.022, 5)
    bobine(-0.82, -1.3, 0.6)
    # bande métallique brillante qui descend vers la presse
    k.axe("cuivre", (-0.3, 1.2, 1.25), (0.0, -0.05, 1.1), 0.012, 4) if False else None
    k.b("cuivre", (-0.28, -0.55, 0.86), (0.2, 1.3, 0.012), rx=math.radians(-12))
    # presse de moulage : plateau bas, 4 colonnes chromées, traverse et gros vérin
    px, py = -0.32, 0.72
    k.caisson("car", px, py, 0.05, 1.5, 1.72, 0.5, 0.05)
    k.bz("noir", px, py, 0.55, 1.3, 1.5, 0.08)
    for x, y in ((px - 0.55, py - 0.62), (px + 0.55, py - 0.62), (px - 0.55, py + 0.62), (px + 0.55, py + 0.62)):
        k.cyl("chrome", x, y, 0.6, 2.05, 0.06, 12)
    k.mobile(True)
    zp = 1.12 + 0.12 * (0.5 + 0.5 * math.cos(k.phase * math.tau))
    k.caisson("car2", px, py, zp, 1.3, 1.5, 0.16, 0.03)
    k.cyl("chrome", px, py, zp + 0.16, 2.1, 0.13, 16)
    k.mobile(False)
    k.bz("acier_clair", px, py, 0.64, 0.98, 1.16, 0.03)
    k.caisson("car", px, py, 2.0, 1.5, 1.72, 0.2, 0.04)
    k.cyl("car2", px, py, 2.2, 2.75, 0.28, 22)
    k.rev("acier_clair", px, py, [(2.75, 0.32), (2.82, 0.32), (2.86, 0.14)], 22)
    k.plaque("plaque", px - 0.35, py - 0.87, 2.1, 0.3, 0.1)
    k.voyant("voyant", px + 0.3, py - 0.87, 2.1, 0.02)
    # tapis de sortie à l'est : plateau de puces noires, four de cuisson
    k.caisson("car2", 1.12, -0.6, 0.05, 0.7, 2.3, 0.4, 0.03)
    k.bz("noyau", 1.12, -0.6, 0.45, 0.58, 2.2, 0.012)
    for i in range(3):
        y = -1.48 + i * 0.5
        k.bz("acier", 1.12, y, 0.462, 0.48, 0.4, 0.02)
        for u in range(3):
            for v in range(3):
                k.bz("noyau", 1.0 + u * 0.12, y - 0.12 + v * 0.12, 0.482, 0.09, 0.09, 0.03)
    k.caisson("car", 1.08, 0.82, 0.05, 0.82, 1.18, 0.92, 0.06)
    k.b("four", (1.08, 0.22, 0.45), (0.5, 0.012, 0.07))
    k.b("noir", (1.08, 0.215, 0.45), (0.6, 0.008, 0.18))
    k.cuve("car2", 1.2, 1.1, 0.97, 1.5, 0.14, 0.25, 14)
    # devant : coffret, résine en bidon
    k.cuve("vert", 0.35, -1.75, 0.05, 0.72, 0.2, 0.2, 18)
    k.tuyau("cuivre", [(0.35, -1.75, 0.76), (0.35, -0.3, 0.9), (0.1, 0.2, 0.9)], r=0.018, coude=0.08, brides=[])
    k.armoire("car2", -1.25, 0.72, 0.05, 0.3, 0.8, 0.5, lampe="voyant_v")


def cms(S, k):
    """LIGNE CMS : tapis est-ouest à cartes vertes, banque de bobines de composants au sud (rangée de disques), portique pick and
    place à deux têtes (mobiles), four de refusion à fentes orange au nord-est, moniteur."""
    M = k.M = P.matieres(S, "hitech")
    M["refusion"] = P.lueur(S, "c_refusion", (1.0, 0.38, 0.06), 3.8, 0.55, part=0.6, echelle=22.0)
    M["ecran"] = P.lueur(S, "c_ecran", (0.1, 0.65, 1.0), 2.6, 0.55, part=0.6, echelle=40.0)
    k.sol("noir", 4, h=0.05, ch=0.22)
    ty = -0.45
    # châssis de la ligne, tapis noir, 3 cartes
    for x in (-1.6, -0.5, 0.6, 1.65):
        k.pied("acier", x, ty - 0.55, 0.32, 0.06, "noir")
        k.pied("acier", x, ty + 0.55, 0.32, 0.06, "noir")
    k.caisson("car2", 0.0, ty, 0.28, 3.85, 1.3, 0.2, 0.03)
    k.bz("noyau", 0.0, ty, 0.48, 3.8, 0.74, 0.012)
    for sg in (-1, 1):
        k.bz("acier_clair", 0.0, ty + sg * 0.4, 0.48, 3.85, 0.05, 0.05)
    for x in (-1.45, 0.0, 1.45):
        carte_cms(k, x + 0.08, ty, 0.5, 0.74, 0.62)
    # banque de bobines au sud : 9 disques inclinés, tous différents
    by = ty - 1.05
    k.caisson("car", -0.55, by, 0.05, 2.72, 0.55, 0.4, 0.03)
    for i in range(10):
        x = -1.75 + i * 0.268
        z = 0.72
        c = ("noir", "bleu", "acier_clair", "orange", "noir", "vert", "jaune", "noir", "acier_clair", "rouge")[i]
        pts = [(x, by - 0.015, z), (x, by + 0.015, z)]
        k.put(c, G.tube(pts, 0.28, 22))
        k.axe("acier", (x, by - 0.03, z), (x, by + 0.03, z), 0.05, 8)
        k.axe("noir", (x + 0.03, by + 0.05, 0.42), (x + 0.03, by + 0.05, z), 0.012, 4)
    k.bz("noir", -0.55, by + 0.22, 0.45, 2.7, 0.06, 0.1)
    # portique double
    gx = -0.92
    for sg in (-1, 1):
        k.bz("car", gx + 0.0, ty + sg * 0.74, 0.48, 1.6, 0.14, 0.2)
        for sx in (-0.74, 0.74):
            k.bz("car2", gx + sx, ty + sg * 0.74, 0.68, 0.12, 0.12, 0.72)
    k.mobile(True)
    dx = 0.45 * math.sin(k.phase * math.tau)
    for n, x0 in ((0, gx - 0.3), (1, gx + 0.34)):
        xh = x0 + (dx if n == 0 else -dx) * 0.55
        k.caisson("car", xh, ty, 1.2, 0.3, 1.5, 0.16, 0.03)
        k.bz("car_lisse", xh, ty + 0.1 * math.sin(k.phase * math.tau * 2 + n), 0.82, 0.2, 0.2, 0.38)
        for i in range(3):
            k.cyl("chrome", xh - 0.06 + i * 0.06, ty + 0.1 * math.sin(k.phase * math.tau * 2 + n), 0.68, 0.84, 0.012, 6)
    k.mobile(False)
    k.bz("car", gx, ty - 0.74, 1.4, 1.66, 0.14, 0.14)
    k.bz("car", gx, ty + 0.74, 1.4, 1.66, 0.14, 0.14)
    # four de refusion à l'est : long caisson clair, 4 fentes orange, cheminée
    k.caisson("car", 1.08, ty + 0.03, 0.48, 1.55, 1.4, 0.78, 0.08)
    for i in range(4):
        x = 0.54 + i * 0.36
        k.b("noir", (x, ty - 0.68, 0.84), (0.3, 0.012, 0.2))
        k.b("refusion", (x, ty - 0.69, 0.84), (0.24, 0.008, 0.075))
    k.persiennes("acier", 1.08, ty - 0.68, 0.53, 1.3, 0.13, 3)
    k.cyl("acier", 0.72, ty + 0.3, 1.26, 1.75, 0.09, 12)
    k.rev("car2", 0.72, ty + 0.3, [(1.75, 0.13), (1.82, 0.13), (1.86, 0.03)], 12)
    k.ventilo(1.35, ty + 0.15, 1.38, 0.26, corps="noir", lames=6, ph=(k.phase + 0.5) % 1)
    # magasins au nord : armoire haute et pupitre à écran
    ny = 1.75
    k.caisson("car2", -1.05, ny, 0.05, 1.7, 1.3, 0.88, 0.05)
    k.persiennes("acier", -1.5, ny - 0.66, 0.15, 0.6, 0.5, 6)
    k.b("noir", (-0.72, ny - 0.67, 0.62), (0.8, 0.02, 0.42))
    k.b("ecran", (-0.72, ny - 0.685, 0.62), (0.7, 0.008, 0.33))
    k.voyant("voyant", -1.58, ny - 0.67, 0.78, 0.02)
    k.caisson("car", 0.95, ny + 0.2, 0.05, 1.7, 0.92, 0.72, 0.04)
    for i in range(5):
        k.bz("acier" if i % 2 else "noir", 0.3 + i * 0.32, ny - 0.3, 0.08, 0.27, 0.05, 0.62)
    k.tuyau("cuivre", [(1.4, ny, 0.78), (1.4, ny - 0.9, 1.15), (1.4, ty + 0.5, 1.15)], r=0.03, coude=0.15, brides=[])
    k.cable("caoutchouc", (-0.6, ny - 0.5, 0.93), (-0.75, ty + 0.75, 1.5), 0.08, 0.02)
    k.cable("caoutchouc", (-0.3, ny - 0.5, 0.93), (-0.55, ty + 0.75, 1.5), 0.1, 0.016)
    k.armoire("car2", 1.32, -2.42, 0.05, 0.72, 0.42, 0.28, lampe="voyant_v")


def fibre(S, k):
    """TOUR DE FIBRAGE : tour très haute en charpente ouverte, four rouge au sommet, le fil lumineux qui descend au milieu,
    bobineuse au pied (capstan et grosse bobine qui tourne). La plus haute des machines de 3×3."""
    M = k.M = P.matieres(S, "hitech")
    M["fil"] = P.lueur(S, "c_fil", (0.45, 0.95, 1.0), 4.0, 0.55, grad=(1.0, 5.2, 0.35, 1.0), part=0.45, echelle=24.0)
    M["four"] = P.lueur(S, "c_four", (1.0, 0.42, 0.08), 4.4, 0.55, part=0.6, echelle=20.0)
    k.sol("noir", 3, h=0.05, ch=0.18)
    cx, cy = 0.15, 0.25
    a = 0.62
    H = 5.6
    # 4 poteaux et contreventements, ouvert au sud (on voit le fil)
    pts = [(cx - a, cy - a), (cx + a, cy - a), (cx + a, cy + a), (cx - a, cy + a)]
    for x, y in pts:
        k.bz("car", x, y, 0.05, 0.1, 0.1, H)
    for z0, z1 in ((0.05, 1.4), (1.4, 2.8), (2.8, 4.2), (4.2, H)):
        for (x0, y0), (x1, y1) in ((pts[2], pts[3]), (pts[1], pts[2]), (pts[3], pts[0])):
            k.axe("acier", (x0, y0, z0), (x1, y1, z1), 0.018, 5)
        for i in range(4):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % 4]
            k.axe("car2", (x0, y0, z1), (x1, y1, z1), 0.028, 6)
    for z in (1.4, 2.8, 4.2):      # paliers à plancher, rambarde au sud
        k.bz("acier", cx, cy + 0.3, z, 1.2, 0.62, 0.025)
        k.rambarde("acier", [(cx - a, cy - a, z), (cx - 0.2, cy - a, z)], 0.2, 0.2)
    k.echelle("acier", cx + a + 0.06, cy - a + 0.1, 0.05, 5.5, 0.14, axe="y")
    # four du sommet : cylindre rouge sombre, fente lumineuse, préforme au-dessus
    k.rev("car2", cx, cy, [(4.45, 0.32), (4.98, 0.36), (5.08, 0.28)], 22)
    k.b("four", (cx, cy - 0.35, 4.7), (0.26, 0.012, 0.18))
    k.cerclages("cuivre", cx, cy, (4.55, 4.85), 0.34)
    k.rev("verre", cx, cy, [(5.08, 0.1), (5.72, 0.1), (5.78, 0.04)], 12)
    k.rev("car2", cx, cy, [(H, 0.42), (H + 0.05, 0.42), (H + 0.05, 0.3)], 22)
    k.cyl("car", cx, cy, H + 0.05, H + 0.4, 0.14, 14)
    k.voyant_h("voyant_r", cx, cy, H + 0.4, 0.03)
    # le fil : mince, lumineux en haut, pâle en bas ; bains de résine et UV en passant
    k.cyl("fil", cx, cy, 0.94, 4.45, 0.014, 8)
    for z, r_, c in ((3.45, 0.13, "car_lisse"), (2.45, 0.15, "orange"), (1.72, 0.1, "car_lisse")):
        k.cyl(c, cx, cy, z, z + 0.3, r_, 16)
        k.cerclages("acier_clair", cx, cy, (z + 0.02, z + 0.28), r_, e=0.012, h=0.016, segs=16)
    # bobineuse au pied : grosse bobine (mobile), capstan, moteur
    by = cy - a - 0.42
    k.caisson("car2", cx, by + 0.12, 0.05, 1.7, 0.92, 0.26, 0.03)
    k.put("car_lisse", G.tour([(cx - 0.3, 0.001), (cx - 0.3, 0.43), (cx - 0.27, 0.43), (cx - 0.27, 0.27), (cx + 0.27, 0.27), (cx + 0.27, 0.43), (cx + 0.3, 0.43), (cx + 0.3, 0.001)], 32, "x", (0.0, by, 0.76)))
    k.put("chrome", G.tour([(cx - 0.26, 0.28), (cx - 0.26, 0.34), (cx + 0.26, 0.34), (cx + 0.26, 0.28)], 32, "x", (0.0, by, 0.76)))
    k.mobile(True)
    a0 = k.phase * math.tau / 4
    for i in range(4):
        an = a0 + math.tau * i / 4
        k.axe("noir", (cx + 0.31, by + 0.1 * math.cos(an), 0.76 + 0.1 * math.sin(an)), (cx + 0.31, by + 0.4 * math.cos(an), 0.76 + 0.4 * math.sin(an)), 0.022, 5)
    k.mobile(False)
    k.axe("acier_clair", (cx - 0.46, by, 0.76), (cx + 0.46, by, 0.76), 0.035, 8)
    k.moteur("car", cx - 0.7, by, 0.56, 0.42, 0.2)
    k.cyl("acier_clair", cx, cy - 0.3, 0.5, 0.95, 0.09, 12)
    k.cable("fil", (cx, cy, 0.95), (cx, by + 0.2, 1.04), 0.03, 0.011, 5)
    # préparation des gaz : bouteilles et coffret à gauche
    for x, y in ((-1.18, 0.95), (-1.18, 1.4), (-0.82, 1.65)):
        k.cuve("car2", x, y, 0.05, 1.5, 0.15, 0.5, 14)
        k.cyl("rouge", x, y, 1.5, 1.56, 0.05, 8)
    k.tuyau("acier_clair", [(-1.18, 1.4, 1.56), (-0.8, 0.9, 2.95), (cx - 0.1, cy, 4.42)], r=0.018, coude=0.2, brides=[])
    k.armoire("car2", 1.05, -1.75, 0.05, 0.62, 0.78, 0.3, lampe="voyant")
    k.armoire("car", -1.08, -0.42, 0.05, 0.56, 1.05, 0.3, lampe="voyant_v")


def integ(S, k):
    """ATELIER D'INTÉGRATION DES BAIES : pont roulant à poutres jaunes qui lève une baie noire au-dessus d'un poste, deux
    baies en cours porte ouverte, établi à bras robot, servantes d'outils, sol à bandes de danger. Une baie se lit tout de suite."""
    M = k.M = P.matieres(S, "hitech")
    M["diode"] = P.lueur(S, "c_diode", (0.05, 0.42, 1.0), 3.6, 0.55, part=0.55, echelle=20.0)
    M["soudure"] = P.lueur(S, "c_soudure", (0.7, 0.85, 1.0), 4.5, 0.6, part=0.6, echelle=30.0)
    k.bz("beton", 0.0, -0.3, 0.0, 3.5, 4.9, 0.05)
    for x in (-1.58, 1.58):
        k.bz("chevron", x, -0.3, 0.08, 0.1, 3.8, 0.006)
    k.bz("chevron", 0.0, -2.22, 0.08, 3.1, 0.1, 0.006)
    # baies posées, porte vitrée : même grammaire que le centre (diodes), ici à moitié garnies
    def baie(x, y, h, ouverte):
        k.caisson("noir", x, y, 0.08, 0.72, 0.7, h, 0.02)
        k.b("noyau", (x, y - 0.355, 0.08 + h / 2.0), (0.6, 0.01, h - 0.08))
        for i in range(int(h / 0.12)):
            z = 0.16 + i * 0.12
            if k.r.f() < 0.65:
                k.b("acier", (x, y - 0.363, z), (0.56, 0.008, 0.09))
                k.b("diode", (x - 0.18 + k.r.f(0, 0.2), y - 0.369, z), (0.1, 0.006, 0.016))
        if ouverte:
            k.b("acier", (x + 0.48, y - 0.58, 0.08 + h / 2.0), (0.015, 0.45, h - 0.06), rz=math.radians(-28))
    baie(-1.05, -1.2, 1.65, True)
    baie(0.95, -1.35, 1.5, False)
    # établi central : plateau, bras robot, lueur de soudure sur la carte
    k.caisson("car", 0.0, 0.42, 0.06, 1.1, 0.8, 0.5, 0.03)
    carte_cms(k, -0.06, 0.32, 0.56, 0.6, 0.46)
    k.sph("soudure", (0.05, 0.3, 0.68), 0.022, 8, 5)
    k.rev("car2", 0.42, 0.55, [(0.56, 0.12), (0.7, 0.1)], 14)
    k.axe("car_lisse", (0.42, 0.55, 0.72), (0.22, 0.42, 1.08), 0.045, 10)
    k.axe("car_lisse", (0.22, 0.42, 1.08), (0.05, 0.3, 0.76), 0.033, 10)
    k.rev("noir", 0.22, 0.42, [(1.02, 0.07), (1.14, 0.07)], 12)
    # pont roulant : deux poutres en treillis jaunes sur 4 poteaux, palan et baie qui lève
    Z = 3.05
    for x, y in ((-1.74, -2.5), (1.74, -2.5), (-1.74, 2.3), (1.74, 2.3)):
        k.bz("jaune", x, y, 0.06, 0.2, 0.2, Z)
        k.rivets_ligne("riv", (x, y - 0.085, 0.2), (x, y - 0.085, Z - 0.1), 12, r=0.011)
    for x in (-1.74, 1.74):
        k.treillis("jaune", (x, -2.55, Z), (x, 2.35, Z), 0.3, 7, 0.032)
    k.mobile(True)
    yp = -0.1
    zb = 1.5
    for dy in (-0.14, 0.14):
        k.bz("jaune", 0.0, yp + dy, Z + 0.14, 3.6, 0.12, 0.2)
    k.caisson("car2", 0.0, yp, Z - 0.1, 0.42, 0.42, 0.22, 0.03)
    for dx in (-0.08, 0.08):
        k.axe("acier_clair", (dx, yp, Z - 0.1), (dx, yp, zb + 1.02), 0.009, 4)
    k.bz("jaune", 0.0, yp, zb + 0.98, 0.64, 0.5, 0.06)
    # la baie suspendue, entière
    k.caisson("noir", 0.0, yp, zb, 0.62, 0.48, 1.0, 0.015)
    k.b("noyau", (0.0, yp - 0.245, zb + 0.5), (0.52, 0.01, 0.92))
    for i in range(7):
        z = zb + 0.1 + i * 0.13
        k.b("acier", (0.0, yp - 0.25, z), (0.48, 0.008, 0.095))
        k.b("diode", (-0.16 + (i % 3) * 0.1, yp - 0.256, z), (0.1, 0.006, 0.016))
    k.mobile(False)
    # au nord : magasin de serveurs et chariots, armoire basse, voyant tournant
    k.caisson("car2", -0.7, 2.25, 0.06, 1.6, 0.9, 0.82, 0.04)
    for i in range(5):
        k.bz("noir", -1.32 + i * 0.31, 1.78, 0.14, 0.27, 0.03, 0.66)
        k.b("diode", (-1.32 + i * 0.31, 1.762, 0.7), (0.05, 0.006, 0.014))
    k.caisson("orange", 1.0, 2.05, 0.06, 0.62, 0.56, 0.72, 0.03)
    for i in range(3):
        k.b("noir", (1.0, 1.765, 0.22 + i * 0.2), (0.54, 0.01, 0.015))
    k.voyant_h("voyant_o", 1.74, 2.3, Z + 0.26, 0.035, boitier="jaune")
    k.axe("caoutchouc", (1.74, 2.3, Z), (1.74, 2.3, Z + 0.26), 0.012, 5)
    k.flexible("caoutchouc", [(-1.65, 2.2, 3.0), (-1.0, 2.0, 2.5), (-0.5, 2.2, 0.9)], 0.02)
