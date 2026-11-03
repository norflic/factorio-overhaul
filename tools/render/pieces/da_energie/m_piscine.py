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


def _eau(S, M):
    M["eau_ch"] = P.lueur(S, "c_eau_ch", (0.1, 0.42, 1.0), 1.5, 0.55, part=0.65, echelle=5.0)
    M["ch_vif"] = P.lueur(S, "c_ch_vif", (0.35, 0.75, 1.0), 4.2, 0.6, part=0.5, echelle=14.0)


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


def _sas_sud(k, y, x=0.0):
    """Sas de transfert : bloc plombé, trappe ronde boulonnée à chevrons, trèfle, pupitre."""
    k.caisson("plomb", x, y, 0.0, 1.3, 0.62, 0.36, 0.04)
    k.cyl("acier", x - 0.15, y + 0.02, 0.36, 0.4, 0.24, 28)
    k.cyl("plomb", x - 0.15, y + 0.02, 0.4, 0.46, 0.2, 28)
    k.boulons_rond("riv", x - 0.15, y + 0.02, 0.4, 0.22, 12, 0.014)
    k.b("chevron", (x + 0.38, y + 0.02, 0.37), (0.36, 0.3, 0.02))
    E.trefle(k, x + 0.38, y - 0.31, 0.18, 0.1)
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


def v_c(S, k):
    E.matieres(S, k, "hitech")
    _eau(S, k.M)
    R = 1.62
    k.rev("beton", 0.0, 0.0, [(0.0, R + 0.24), (ZB, R + 0.24), (ZB, R), (ZE - 0.1, R)], 64, cap=False)
    k.rev("eau_ch", 0.0, 0.0, [(ZE - 0.02, R), (ZE - 0.02, 0.0)], 64)
    k.tore("chevron", 0.0, 0.0, ZB + 0.004, R + 0.04, 0.03, 64, 6)
    k.tore("acier_clair", 0.0, 0.0, ZB + 0.03, R + 0.14, 0.03, 64, 8)   # rail circulaire
    # râteliers en couronnes
    for ring, n in ((0.42, 6), (0.85, 12), (1.27, 18)):
        k.tore("noyau", 0.0, 0.0, ZE + 0.004, ring + 0.2, 0.012, 48, 4)
        for i in range(n):
            a = TAU * (i + 0.5) / n
            if (i * 5 + n) % 9 == 0:
                continue
            k.b("ch_vif", (ring * math.cos(a), ring * math.sin(a), ZE + 0.001), (0.14, 0.14, 0.01), rz=a)
            k.b("noyau", ((ring + 0.2) * math.cos(a + TAU / n / 2), (ring + 0.2) * math.sin(a + TAU / n / 2), ZE + 0.004),
                (0.36, 0.022, 0.012), rz=a + TAU / n / 2)
    k.cyl("ch_vif", 0.0, 0.0, ZE - 0.01, ZE + 0.001, 0.14, 16)
    # pont polaire : poutre diamétrale qui tourne
    a = TAU * k.phase * 0.5 + 0.5
    k.mobile(True)
    ca, sa = math.cos(a), math.sin(a)
    h = 1.08
    for sg in (-1, 1):
        px, py = sg * (R + 0.14) * ca, sg * (R + 0.14) * sa
        k.bz("acier", px, py, ZB + 0.04, 0.24, 0.24, 0.1, rz=a)
        k.axe("jaune", (px, py, ZB + 0.14), (px * 0.96, py * 0.96, h), 0.05, 8)
    for d in (-0.1, 0.1):
        k.b("jaune", (-sa * d, ca * d, h + 0.07), (2 * R + 0.5, 0.11, 0.14), rz=a)
    k.b("chevron", ((R + 0.1) * ca, (R + 0.1) * sa, h + 0.15), (0.24, 0.24, 0.02), rz=a)
    tx, tyy = 0.55 * ca, 0.55 * sa
    k.caisson("car", tx, tyy, h + 0.14, 0.4, 0.34, 0.2, 0.03)
    k.voyant_h("voyant_o", tx, tyy, h + 0.34, 0.026)
    k.axe("acier_clair", (tx, tyy, h), (tx, tyy, ZE + 0.22), 0.02, 8)
    k.b("ch_vif", (tx, tyy, ZE + 0.08), (0.1, 0.1, 0.12))
    k.mobile(False)
    _nord(k, E.ty(1.62), -1.75, 1.75)
    _sas_sud(k, E.ty(-1.66))
    k.rambarde("acier", [(-0.9, E.ty(-1.32), ZB * 0.0 + 0.36), (0.9, E.ty(-1.32), 0.36)], 0.16)
