"""DÉPÔT GÉOLOGIQUE (fo-geological-repository, 6×6, container : image FIXE, F44) : on descend les colis vitrifiés
dans la roche. Chevalement à molettes (ou descenderie, ou tour d'extraction), bunker de réception blindé et sas au SUD,
château de transfert sur wagonnet. Lueurs fixes : feux, gyrophare, fenêtres. Variantes : a chevalement en treillis,
b descenderie dans une butte, c tour d'extraction en béton.
"""
import math

import elements as E
import geo as G

D = E.D
TAU = E.TAU


def _bunker(k, x, y, sx, sy, h=0.95):
    """Bunker de réception : béton, panneaux plombés, porte-sas à chevrons, trèfle, gyrophare, groupe de ventilation."""
    k.caisson("beton", x, y, 0.0, sx, sy, h, 0.06)
    ys = y - sy / 2.0
    for i in range(3):
        xx = x - sx / 2.0 + 0.28 + i * 0.3
        k.pose_tole("plomb", xx, ys, 0.12, 0.24, h - 0.3)
    xd = x + sx * 0.12
    k.b("noir", (xd, ys + 0.02, 0.36), (0.86, 0.06, 0.72))          # embrasure
    k.b("plomb", (xd, ys - 0.02, 0.34), (0.8, 0.05, 0.66))            # porte coulissante
    for dx in (-0.2, 0.2):
        k.b("acier", (xd + dx, ys - 0.05, 0.34), (0.03, 0.02, 0.62))
    E.cadre_chevrons(k, xd, ys - 0.03, 0.0, 0.86, 0.72, 0.08)
    E.trefle(k, xd, ys - 0.02, h - 0.12, 0.11)
    k.voyant_h("voyant_o", xd + 0.52, y - sy / 2.0 + 0.12, h, 0.04)
    k.voyant("voyant_v", xd - 0.55, ys - 0.02, 0.5, 0.022)
    # toit : centrale de ventilation à filtres, 2 ventilateurs
    k.caisson("car", x - sx * 0.18, y + sy * 0.12, h, sx * 0.42, sy * 0.45, 0.26, 0.03)
    k.ventilo(x - sx * 0.27, y + sy * 0.12, h + 0.36, 0.13, corps="noir")
    k.ventilo(x - sx * 0.09, y + sy * 0.12, h + 0.36, 0.13, corps="noir")
    k.rambarde("acier", [(x - sx / 2 + 0.05, ys + 0.05, h), (x + sx / 2 - 0.05, ys + 0.05, h)], 0.14)


def _chateau(k, x, y, ax="x"):
    """Château de transfert couché sur un wagonnet, sur deux rails : fût cerclé à ailettes, tourillons, fonds jaunes."""
    k.bz("car2", x, y, 0.1, 1.1, 0.5, 0.1)
    for dx in (-0.4, 0.4):
        for dy in (-0.18, 0.18):
            k.axe("noir", (x + dx, y + dy - 0.03, 0.1), (x + dx, y + dy + 0.03, 0.1), 0.07, 10)
    k.echangeur(x, y, 0.2, 0.8, 0.24, "plomb", "acier", axe=ax, cerc=9)
    for sg in (-1, 1):
        k.axe("jaune", (x + sg * 0.42, y, 0.44), (x + sg * 0.5, y, 0.44), 0.2, 20)


def _rails(k, x0, x1, y):
    for dy in (-0.18, 0.18):
        k.b("acier_clair", ((x0 + x1) / 2, y + dy, 0.03), (x1 - x0, 0.04, 0.05))
    n = int((x1 - x0) / 0.22)
    for i in range(n + 1):
        k.b("rouille", (x0 + (x1 - x0) * i / n, y, 0.012), (0.07, 0.6, 0.024))


def _cheminee(k, x, y, h=2.4, r=0.16):
    k.caisson("car2", x, y, 0.0, 0.5, 0.5, 0.36, 0.03)
    k.persiennes("acier", x, y - 0.25, 0.06, 0.4, 0.24, 5)
    k.cyl("acier_clair", x, y, 0.36, h, r, 20)
    k.cerclages("acier", x, y, [0.36 + (h - 0.36) * i / 5.0 for i in range(1, 6)], r, 0.016, 0.018, 20)
    k.rev("rouge", x, y, [(h - 0.22, r + 0.005), (h - 0.08, r + 0.005)], 20, cap=False)
    k.voyant_h("voyant_r", x, y, h, 0.035)


def _machine_extraction(k, x, y, sx, sy, h=0.8):
    """Salle des machines d'extraction : bâtiment à toit en bâtière, fenêtres éclairées, tambour visible par la baie."""
    k.caisson("car", x, y, 0.0, sx, sy, h, 0.03)
    x0, x1, ys, yn, zr = x - sx / 2 - 0.05, x + sx / 2 + 0.05, y - sy / 2 - 0.05, y + sy / 2 + 0.05, h + 0.36
    v = [(x0, ys, h), (x1, ys, h), (x1, yn, h), (x0, yn, h), (x0, y, zr), (x1, y, zr)]
    k.put("car2", (v, [(0, 1, 5, 4), (2, 3, 4, 5), (1, 2, 5), (3, 0, 4)], [(p[0], p[1] + p[2]) for p in v]))
    E.fenetres(k, "fenetre", x - sx / 2 + 0.1, x + sx / 2 - 0.1, y - sy / 2, h * 0.45, h * 0.3, 4)
    k.b("noir", (x, y - sy / 2 - 0.004, 0.2), (sx * 0.5, 0.012, 0.36))


def v_a(S, k):
    M = E.matieres(S, k, "hitech")
    E.lueurs(S, M)
    E.croute(k, "terre", 0.0, E.ty(1.2), 2.35, 2.1, 0.08, 7, 0.3)
    xs, ys = 0.6, E.ty(1.05)
    # collet du puits et recette
    k.caisson("beton", xs, ys, 0.0, 1.5, 1.4, 0.32, 0.05)
    k.b("noir", (xs, ys - 0.2, 0.33), (0.7, 0.6, 0.012))
    # chevalement : 4 montants en treillis, jambes de force vers la machine d'extraction (ouest)
    H = 3.3
    cs = [(xs + dx, ys + dy) for dx in (-0.42, 0.42) for dy in (-0.4, 0.4)]
    for (px, py) in cs:
        k.axe("rouge", (px, py, 0.32), (px * 0.94 + xs * 0.06, py * 0.94 + ys * 0.06, H), 0.04, 8)
    for i in range(6):
        z0, z1 = 0.32 + (H - 0.32) * i / 6.0, 0.32 + (H - 0.32) * (i + 1) / 6.0
        for (a, b) in ((cs[0], cs[2]), (cs[1], cs[3]), (cs[0], cs[1]), (cs[2], cs[3])):
            k.axe("rouge", (a[0], a[1], z0), (b[0], b[1], z1), 0.016, 5)
            k.axe("rouge", (a[0], a[1], z1), (b[0], b[1], z1), 0.018, 5)
    for py in (ys - 0.4, ys + 0.4):
        k.axe("rouge", (xs - 0.42, py, H - 0.2), (xs - 2.25, py, 0.0), 0.05, 8)
        for t in (0.3, 0.6):
            p = G.lerp((xs - 0.42, py, H - 0.2), (xs - 2.25, py, 0.0), t)
            k.axe("rouge", p, (xs - 0.42, py, p[2] * 0.6), 0.016, 5)
    # plate-forme et 2 molettes face à la caméra
    k.caisson("car2", xs, ys, H, 1.1, 1.0, 0.1, 0.02)
    k.rambarde("acier", [(xs - 0.55, ys - 0.5, H + 0.1), (xs + 0.55, ys - 0.5, H + 0.1)], 0.13)
    for dy, ph in ((0.18, 0.1), (-0.18, 0.0)):
        E.roue_xz(k, "acier_clair", xs + 0.02, ys + dy, H + 0.5, 0.42, 0.028, 8, ph=ph)
        k.axe("acier", (xs - 0.4, ys + dy, H + 0.92), (xs - 2.0, ys + dy, 1.1), 0.012, 4)      # câbles
        k.axe("acier", (xs + 0.44, ys + dy, H + 0.5), (xs + 0.44, ys + dy, 0.4), 0.012, 4)
    k.voyant_h("voyant_r", xs + 0.45, ys - 0.45, H + 0.1, 0.035)
    _machine_extraction(k, -2.2, E.ty(1.25), 1.2, 1.5)
    _bunker(k, 1.35, E.ty(-1.3), 2.9, 2.2)
    _rails(k, -2.8, 2.4, E.ty(-2.45))
    _chateau(k, -0.6, E.ty(-2.45))
    _cheminee(k, 2.55, E.ty(2.3))


def v_b(S, k):
    M = E.matieres(S, k, "hitech")
    E.lueurs(S, M)
    # butte : la descenderie entre sous terre ; le portail regarde le sud
    k.put("terre", G.butte_polaire((0.0, 1.84, 0.0), 2.85, 2.3, 1.35, G.Rnd(5), nr=12, na=48, bosses=0.12, bord=0.08, expo=1.1))
    E.croute(k, "beton", 0.0, E.ty(-0.9), 1.3, 0.9, 0.05, 3, 0.05)
    # tête de tunnel : mur de front en béton, voûte, lumière au fond
    yf = E.ty(-0.65)
    k.caisson("beton", 0.0, yf + 0.2, 0.0, 2.3, 0.5, 1.15, 0.05)
    for sg in (-1, 1):
        k.put("beton", G.prisme([(sg * 1.15, yf - 0.05), (sg * 1.75, yf + 0.45), (sg * 1.15, yf + 0.45)], 0.0, 0.9, 0.9))
    k.put("noyau", G.tour([(yf + 0.6, 0.55), (yf - 0.04, 0.55)], 24, "y", (0.0, 0.0, 0.0), -math.pi / 2, math.pi / 2, cap0=True))
    k.put("beton", G.tour([(yf - 0.06, 0.66), (yf - 0.06, 0.55), (yf + 0.44, 0.55), (yf + 0.44, 0.66)], 24, "y", (0.0, 0.0, 0.0), -math.pi / 2, math.pi / 2))
    k.put("chevron", G.tour([(yf - 0.08, 0.72), (yf - 0.08, 0.66), (yf - 0.06, 0.66), (yf - 0.06, 0.72)], 24, "y", (0.0, 0.0, 0.0), -math.pi / 2, math.pi / 2))
    for z in (0.18, 0.32, 0.44):
        k.b("fenetre", (0.0, yf + 0.5, z), (0.08, 0.02, 0.03))
    k.b("fenetre", (0.0, yf + 0.55, 0.45), (0.5, 0.02, 0.05))
    E.trefle(k, 0.0, yf - 0.06, 0.92, 0.12)
    k.voyant_h("voyant_o", 0.85, yf, 1.15, 0.04)
    k.voyant_h("voyant_o", -0.85, yf, 1.15, 0.04)
    # rampe et transbordeur porte-château devant le portail
    k.b("noir", (0.0, E.ty(-1.6), 0.008), (1.0, 1.9, 0.016))
    for x in (-0.48, 0.48):
        k.b("chevron", (x, E.ty(-1.6), 0.02), (0.06, 1.9, 0.02))
    xc, yc = 0.0, E.ty(-2.1)
    for sg in (-1, 1):
        k.caisson("jaune", xc + sg * 0.55, yc, 0.0, 0.16, 0.9, 0.85, 0.02)
        for dy in (-0.33, 0.33):
            k.axe("caoutchouc", (xc + sg * 0.62, yc + dy, 0.12), (xc + sg * 0.48, yc + dy, 0.12), 0.12, 14)
    k.caisson("jaune", xc, yc, 0.85, 1.3, 0.9, 0.14, 0.02)
    k.caisson("car2", xc + 0.45, yc - 0.3, 0.99, 0.32, 0.28, 0.22, 0.02)
    k.b("verre", (xc + 0.45, yc - 0.445, 1.12), (0.26, 0.012, 0.1))
    k.cuve("plomb", xc, yc + 0.05, 0.12, 0.8, 0.27, 0.25, 24)
    k.cerclages("acier", xc, yc + 0.05, [0.2 + 0.07 * i for i in range(8)], 0.27, 0.025, 0.012, 24)
    # sur la butte : 2 cheminées de ventilation et une guérite
    _cheminee(k, -1.6, E.ty(1.6), 2.3, 0.14)
    _cheminee(k, 1.55, E.ty(1.9), 2.1, 0.13)
    k.caisson("car", 0.4, E.ty(1.3), 1.0, 0.7, 0.55, 0.42, 0.03)
    E.fenetres(k, "fenetre", 0.12, 0.68, E.ty(1.3) - 0.275, 1.18, 0.12, 2)


def v_c(S, k):
    M = E.matieres(S, k, "hitech")
    E.lueurs(S, M)
    E.croute(k, "terre", 0.0, E.ty(1.2), 2.6, 2.0, 0.07, 9, 0.3)
    # tour d'extraction (Koepe) : fût de béton, salle des machines en tête, molettes intégrées, feux
    xt, yt = 0.5, E.ty(1.15)
    H = 3.4
    k.caisson("beton", xt, yt, 0.0, 1.35, 1.35 * D * 0.75, H, 0.04)
    for z in (0.9, 1.8, 2.7):
        k.b("acier", (xt, yt - 0.72, z), (1.38, 0.03, 0.05))
    E.fenetres(k, "fenetre", xt - 0.5, xt + 0.5, yt - 0.716, 1.2, 0.18, 3)
    k.caisson("car", xt, yt, H, 1.65, 1.5, 0.62, 0.04)
    E.fenetres(k, "fenetre", xt - 0.7, xt + 0.7, yt - 0.75, H + 0.18, 0.24, 5)
    k.put("car2", G.prisme([(xt - 0.86, yt - 0.78), (xt + 0.86, yt - 0.78), (xt + 0.86, yt + 0.78), (xt - 0.86, yt + 0.78)], H + 0.62, H + 0.82, 0.8))
    for sg in (-1, 1):
        k.voyant_h("voyant_r", xt + sg * 0.7, yt - 0.6, H + 0.82, 0.035)
    E.trefle(k, xt, yt - 0.716, 0.55, 0.13)
    # passerelle couverte de la tour au bunker
    k.caisson("car2", 0.5, 0.27, 0.62, 0.36, 1.3, 0.3, 0.02)
    k.persiennes("acier", 0.5, 0.27 - 0.65, 0.66, 0.3, 0.2, 4)
    for x in (0.38, 0.62):
        k.axe("acier", (x, 0.27, 0.0), (x, 0.27, 0.62), 0.035, 8)
    _bunker(k, 1.3, E.ty(-1.15), 2.9, 2.5, 1.0)
    _rails(k, -2.8, 2.4, E.ty(-2.45))
    _chateau(k, -1.0, E.ty(-2.45))
    _cheminee(k, -2.4, E.ty(2.3), 2.2)
