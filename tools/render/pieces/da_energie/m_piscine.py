"""PISCINE D'ENTREPOSAGE (fo-cooling-pool, 4×4, aucune boîte de fluide) : bassin de béton dont l'eau luit en bleu
(Cherenkov) au-dessus des râteliers, pont de manutention, pompes et aéroréfrigérant au nord, sas de transfert plombé au
sud (sortie des cellules). Variantes : a bassin + portique, b deux alvéoles + batardeau, c bassin rond + pont polaire.
"""
import math

import elements as E
import geo as G
import palettes as P

D = E.D
TAU = E.TAU
ZE = 0.36          # niveau de l'eau
ZB = 0.46          # arase du bassin


def _eau(S, M, R=1.62, rect=None):
    M["eau_ch"] = E.eau(S, "c_eau_ch", R, rect=rect)
    M["ch_vif"] = P.lueur(S, "c_ch_vif", (0.1, 0.55, 1.0), 1.2, 0.55, part=0.5, echelle=14.0)
    M["rack"] = P.MT.surface("c_rack", (0.045, 0.075, 0.1), rough=0.45, met=0.6, usure=0.3, nu=(0.2, 0.28, 0.34), crasse=0.6,
                             crasse_col=(0.01, 0.02, 0.03), grain=0.1, graine=61)


def _rateliers_rect(k, x0, x1, y0, y1, pas=0.26, vide=()):
    """Grille des râteliers sous l'eau : cadres sombres, têtes d'assemblages lumineuses (cases vides : moins de lueur)."""
    k.b("eau_ch", ((x0 + x1) / 2, (y0 + y1) / 2, ZE - 0.02), (x1 - x0, y1 - y0, 0.04))
    nx, ny = int((x1 - x0) / pas), int((y1 - y0) / (pas * 1.15))
    px, py = (x1 - x0) / nx, (y1 - y0) / ny
    for i in range(nx + 1):
        k.b("noyau", (x0 + i * px, (y0 + y1) / 2, ZE + 0.004), (0.026, y1 - y0, 0.012))
    for j in range(ny + 1):
        k.b("noyau", ((x0 + x1) / 2, y0 + j * py, ZE + 0.004), (x1 - x0, 0.03, 0.012))
    for i in range(nx):
        for j in range(ny):
            if (i, j) in vide or (i * 7 + j * 3) % 11 == 0:
                continue
            cx, cy = x0 + (i + 0.5) * px, y0 + (j + 0.5) * py
            k.b("ch_vif", (cx, cy, ZE + 0.001), (px * 0.5, py * 0.5, 0.01))


def _bassin_rect(k, x0, x1, y0, y1, e=0.2):
    """Murs du bassin : béton, couronnement en acier, bande à chevrons sur l'arase intérieure."""
    for (cx, cy, sx, sy) in (((x0 + x1) / 2, y0 - e / 2, x1 - x0 + 2 * e, e), ((x0 + x1) / 2, y1 + e / 2, x1 - x0 + 2 * e, e),
                             (x0 - e / 2, (y0 + y1) / 2, e, y1 - y0), (x1 + e / 2, (y0 + y1) / 2, e, y1 - y0)):
        k.caisson("beton", cx, cy, 0.0, sx, sy, ZB, 0.03)
    for (cx, cy, sx, sy) in (((x0 + x1) / 2, y0 - 0.035, x1 - x0, 0.07), ((x0 + x1) / 2, y1 + 0.035, x1 - x0, 0.07),
                             (x0 - 0.035, (y0 + y1) / 2, 0.07, y1 - y0), (x1 + 0.035, (y0 + y1) / 2, 0.07, y1 - y0)):
        k.b("chevron", (cx, cy, ZB + 0.006), (sx, sy, 0.012))
    k.b("eau_ch", ((x0 + x1) / 2, (y0 + y1) / 2, ZE - 0.12), (x1 - x0, y1 - y0, 0.2))
    # face sud du bassin : joints de reprise, échelle, plaque
    for x in (x0 + 0.6, x1 - 0.6):
        k.b("acier", (x, y0 - e - 0.006, ZB * 0.5), (0.03, 0.012, ZB * 0.8))


def _portique(k, x0, x1, yb, h=1.18):
    """Pont roulant sur les murs est et ouest : jambes en portique, deux poutres-caissons, chariot, palan qui plonge,
    cabine, gyrophare. yb : position du pont (pièce mobile)."""
    k.mobile(True)
    for x in (x0, x1):
        k.bz("acier", x, yb, ZB, 0.16, 0.62, 0.08)          # sommier sur le rail
        for sg in (-1, 1):
            k.axe("jaune", (x, yb + sg * 0.24, ZB + 0.08), (x, yb + sg * 0.08, h), 0.045, 8)
        k.bz("jaune", x, yb, h - 0.02, 0.18, 0.3, 0.12)
    for dy in (-0.11, 0.11):
        k.caisson("jaune", (x0 + x1) / 2, yb + dy, h, x1 - x0 + 0.2, 0.12, 0.14, 0.02)
    for x in (x0 + 0.05, x1 - 0.05):
        k.b("chevron", (x, yb - 0.172, h + 0.07), (0.22, 0.012, 0.12))
    xt = (x0 + x1) / 2 + 0.35
    k.caisson("car", xt, yb, h + 0.14, 0.42, 0.34, 0.2, 0.03)          # chariot
    k.echangeur(xt, yb, h + 0.18, 0.26, 0.07, "acier_clair", "acier", axe="x", cerc=1)
    k.voyant_h("voyant_o", xt - 0.14, yb + 0.1, h + 0.34, 0.026)
    k.axe("acier_clair", (xt, yb, h), (xt, yb, ZE + 0.25), 0.02, 8)     # mât du palan
    k.cyl("acier", xt, yb, ZE + 0.08, ZE + 0.25, 0.06, 12)
    k.b("ch_vif", (xt, yb, ZE + 0.04), (0.1, 0.1, 0.08))               # assemblage saisi
    # cabine sous la poutre, côté ouest
    xc = x0 + 0.42
    k.caisson("car2", xc, yb - 0.26, h - 0.3, 0.3, 0.2, 0.28, 0.02)
    k.b("verre", (xc, yb - 0.365, h - 0.15), (0.24, 0.012, 0.12))
    k.mobile(False)


def _rails(k, x0, x1, y0, y1):
    for x in (x0, x1):
        k.b("acier_clair", (x, (y0 + y1) / 2, ZB + 0.018), (0.05, y1 - y0, 0.036))
        for yy in (y0, y1):
            k.bz("jaune", x, yy, ZB, 0.12, 0.1, 0.12)


def _nord(k, y, x0=-1.7, x1=1.7):
    """Pompes de circulation, aéroréfrigérant à 2 ventilateurs et tuyaux qui plongent dans le bassin."""
    E.pompe_v(k, x0 + 0.25, y, 0.0, 0.15, 0.72)
    E.pompe_v(k, x0 + 0.72, y + 0.05, 0.0, 0.15, 0.72)
    k.caisson("car", x1 - 0.95, y + 0.05, 0.0, 1.5, 0.9, 0.62, 0.04)
    k.persiennes("acier", x1 - 0.95, y - 0.405, 0.08, 1.3, 0.42, 8)
    k.ventilo(x1 - 1.32, y + 0.08, 0.72, 0.3, corps="noir")
    k.ventilo(x1 - 0.58, y + 0.08, 0.72, 0.3, corps="noir", ph=(k.phase + 0.4) % 1.0)
    for i, x in enumerate((x0 + 0.25, x0 + 0.72)):
        k.tuyau("bleu", [(x, y, 0.62), (x, y, 0.82), (x, y - 0.6, 0.82), (x, y - 0.95, ZE - 0.05)], r=0.055, coude=0.12,
                brides=[(x, y, 0.7), (x, y - 0.3, 0.82)], bride_mat="acier")
    k.tuyau("orange", [(x0 + 0.72, y + 0.05, 0.22), (x1 - 1.7, y + 0.05, 0.22)], r=0.05, brides=[], bride_mat="acier")


def _sas_sud(k, y, x=0.0, pupitre=True):
    """Sas de transfert : bloc plombé, trappe ronde boulonnée à chevrons, trèfle, pupitre."""
    k.caisson("plomb", x, y, 0.0, 1.3, 0.62, 0.36, 0.04)
    k.cyl("acier", x - 0.15, y + 0.02, 0.36, 0.4, 0.24, 28)
    k.cyl("plomb", x - 0.15, y + 0.02, 0.4, 0.46, 0.2, 28)
    k.boulons_rond("riv", x - 0.15, y + 0.02, 0.4, 0.22, 12, 0.014)
    k.b("chevron", (x + 0.38, y + 0.02, 0.37), (0.36, 0.3, 0.02))
    E.trefle(k, x + 0.38, y - 0.31, 0.18, 0.1)
    if pupitre:
        k.armoire("car2", x + 0.95, y + 0.05, 0.0, 0.3, 0.46, 0.14, lampe="voyant_v")


def v_a(S, k):
    E.matieres(S, k, "hitech")
    _eau(S, k.M)
    x0, x1, y0, y1 = -1.5, 1.5, E.ty(-1.2), E.ty(1.12)
    _bassin_rect(k, x0, x1, y0, y1)
    _rateliers_rect(k, x0 + 0.05, x1 - 0.05, y0 + 0.05, y1 - 0.05)
    _rails(k, x0 - 0.1, x1 + 0.1, y0, y1)
    yb = y0 + 0.4 + (y1 - y0 - 0.8) * (0.5 + 0.5 * math.sin(TAU * k.phase))
    _portique(k, x0 - 0.1, x1 + 0.1, yb)
    k.rambarde("acier", [(x0 - 0.2, y0 - 0.12, ZB), (x1 + 0.2, y0 - 0.12, ZB)], 0.16)
    k.echelle("acier", x1 - 0.3, y0 - 0.21, 0.0, ZB, 0.14)
    _nord(k, E.ty(1.55))
    _sas_sud(k, E.ty(-1.7))


def v_b(S, k):
    E.matieres(S, k, "hitech")
    _eau(S, k.M)
    y0, y1 = E.ty(-1.2), E.ty(1.12)
    for (x0, x1) in ((-1.55, -0.14), (0.14, 1.55)):
        _bassin_rect(k, x0, x1, y0, y1, 0.16)
        _rateliers_rect(k, x0 + 0.04, x1 - 0.04, y0 + 0.05, y1 - 0.05, 0.24)
    # passerelle centrale à caillebotis et batardeau (porte d'acier) entre les alvéoles
    E.caillebotis(k, 0.0, (y0 + y1) / 2, ZB + 0.03, 0.26, y1 - y0 - 0.5, 0.06)
    k.caisson("acier", 0.0, y1 - 0.18, ZB, 0.3, 0.16, 0.42, 0.02)
    k.b("chevron", (0.0, y1 - 0.265, ZB + 0.3), (0.3, 0.012, 0.08))
    k.cyl("rouge", 0.0, y1 - 0.18, ZB + 0.42, ZB + 0.48, 0.06, 14)
    _rails(k, -1.68, 1.68, y0, y1)
    yb = y0 + 0.4 + (y1 - y0 - 0.8) * (0.5 + 0.5 * math.sin(TAU * k.phase))
    _portique(k, -1.68, 1.68, yb)
    k.rambarde("acier", [(-1.7, y0 - 0.1, ZB), (1.7, y0 - 0.1, ZB)], 0.16)
    _nord(k, E.ty(1.55))
    _sas_sud(k, E.ty(-1.7), 0.3)
    # fosse à château, au sud-ouest : château à ailettes à demi immergé
    k.cyl("plomb", -1.25, E.ty(-1.72), 0.0, 0.5, 0.2, 24)
    k.cerclages("acier", -1.25, E.ty(-1.72), (0.12, 0.25, 0.38), 0.2, 0.025, 0.02, 24)
    k.cyl("acier", -1.25, E.ty(-1.72), 0.5, 0.56, 0.16, 20)


def _chateaux(k, x, y):
    """Pile de châteaux de transfert au coin : 2 fûts debout à ailettes, couvercles jaunes, un fût couché devant."""
    for (dx, dy, r) in ((-0.2, 0.12, 0.2), (0.2, 0.16, 0.18)):
        k.cyl("plomb", x + dx, y + dy, 0.0, 0.62, r, 24)
        k.cerclages("acier", x + dx, y + dy, [0.08 + 0.075 * i for i in range(7)], r, 0.03, 0.014, 24)
        k.cyl("jaune", x + dx, y + dy, 0.62, 0.68, r * 0.92, 24)
        k.boulons_rond("riv", x + dx, y + dy, 0.68, r * 0.7, 8, 0.014)
    k.echangeur(x, y - 0.3, 0.0, 0.46, 0.15, "plomb", "acier", axe="x", cerc=4)


def v_c(S, k):
    """Bassin rond (le seul plan d'eau rond du jeu), pont polaire tournant sur rail circulaire (corrections du 3/11)."""
    E.matieres(S, k, "hitech", "piscine")
    R = 1.62
    _eau(S, k.M, R)
    # bassin : couronne de béton usé, paroi intérieure, rail circulaire sur l'arase
    k.rev("beton", 0.0, 0.0, [(0.0, R + 0.28), (ZB, R + 0.28), (ZB, R), (ZE - 0.1, R)], 64, cap=False)
    k.rev("eau_ch", 0.0, 0.0, [(ZE - 0.02, R), (ZE - 0.02, 0.0)], 64)
    k.tore("acier", 0.0, 0.0, ZB + 0.035, R + 0.14, 0.036, 72, 8)
    for i in range(24):
        a = TAU * i / 24
        k.b("acier", ((R + 0.14) * math.cos(a), (R + 0.14) * math.sin(a), ZB + 0.01), (0.07, 0.22, 0.02), rz=a)
    # râteliers : têtes d'assemblages sombres vues sous l'eau, la lueur vient des alvéoles (l'eau)
    for ring, n in ((0.38, 6), (0.78, 12), (1.18, 18)):
        for i in range(n):
            a = TAU * (i + 0.5) / n
            if (i * 5 + n) % 9 == 0:
                continue
            k.b("rack", (ring * math.cos(a), ring * math.sin(a), ZE - 0.005), (0.15, 0.15, 0.02), rz=a)
    k.cyl("rack", 0.0, 0.0, ZE - 0.02, ZE + 0.005, 0.1, 16)
    # pont polaire : poutre-caisson jaune de 0,4 × 0,4, sur 2 sommiers à galets, qui tourne (pièce mobile)
    a = TAU * k.phase * 0.5 + 0.5
    ca, sa = math.cos(a), math.sin(a)
    Lb = R + 0.14
    zb = ZB + 0.18
    k.mobile(True)
    k.b("jaune", (0.0, 0.0, zb + 0.2), (2 * Lb - 0.1, 0.42, 0.4), rz=a)
    k.b("car2", (0.0, 0.0, zb + 0.41), (2 * Lb - 0.3, 0.3, 0.02), rz=a)
    for sg in (-1, 1):
        px, py = sg * Lb * ca, sg * Lb * sa
        k.b("car2", (px, py, ZB + 0.12), (0.34, 0.62, 0.16), rz=a)                   # sommier
        for d in (-0.22, 0.22):
            q = (px - sa * d, py + ca * d)
            k.axe("noir", (q[0] - ca * 0.09, q[1] - sa * 0.09, ZB + 0.08), (q[0] + ca * 0.09, q[1] + sa * 0.09, ZB + 0.08), 0.065, 12)
        k.b("chevron", (px * 0.9, py * 0.9, zb + 0.405), (0.28, 0.43, 0.02), rz=a)
    t = -0.42
    tx, tyy = t * ca, t * sa
    k.b("car", (tx, tyy, zb + 0.54), (0.42, 0.5, 0.24), rz=a)                      # chariot
    for d in (-0.255, 0.255):
        k.b("chevron", (tx - sa * d, tyy + ca * d, zb + 0.54), (0.42, 0.02, 0.1), rz=a)
    k.voyant_h("voyant_o", tx + ca * 0.12, tyy + sa * 0.12, zb + 0.66, 0.04)
    hx, hy = tx - sa * 0.42, tyy + ca * 0.42                                          # palan en porte-à-faux
    k.b("car", ((tx + hx) / 2, (tyy + hy) / 2, zb + 0.6), (0.12, 0.5, 0.1), rz=a)
    k.axe("noir", (hx, hy, zb + 0.6), (hx, hy, ZE + 0.24), 0.018, 6)
    k.b("acier", (hx, hy, ZE + 0.22), (0.16, 0.16, 0.06), rz=a)
    k.b("rack", (hx, hy, ZE + 0.07), (0.11, 0.11, 0.24), rz=a)                       # assemblage à demi immergé
    k.mobile(False)
    _nord(k, E.ty(1.62), -1.75, 1.75)
    _sas_sud(k, E.ty(-1.66), 0.0, pupitre=False)
    _chateaux(k, -1.48, E.ty(-1.62))
    # coffret électrique agrandi (0,6 × 0,6 tuile), au sud-est
    ys = E.ty(-1.66)
    k.caisson("car2", 1.45, ys, 0.0, 0.6, 0.6 * D, 0.62, 0.04)
    for dx in (-0.14, 0.14):
        k.b("car2", (1.45 + dx, ys - 0.3 * D - 0.006, 0.31), (0.26, 0.014, 0.54))
        k.b("acier_clair", (1.45 + dx + 0.09, ys - 0.3 * D - 0.016, 0.33), (0.025, 0.014, 0.08))
    k.voyant("voyant_v", 1.3, ys - 0.3 * D - 0.02, 0.55, 0.022)
    k.voyant("voyant_o", 1.38, ys - 0.3 * D - 0.02, 0.55, 0.022)
    E.trefle(k, 1.6, ys - 0.3 * D - 0.016, 0.52, 0.06)
    k.tuyau("noir", [(1.45, ys + 0.2, 0.62), (1.45, ys + 0.2, 0.75), (1.0, ys + 0.6, 0.75), (1.0, ys + 0.6, 0.0)], r=0.03, coude=0.08, brides=[])
