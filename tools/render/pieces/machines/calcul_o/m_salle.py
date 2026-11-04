"""SALLE BLANCHE refaite (lot DA-CALCUL, 4/11), âge 10, 5×5. Concept : fo-logs/2026-11-04_DA-CALCUL/CONCEPT.md.

Le rendu du 1/11 (m_fab.salle : dôme gris, bandeau de fenêtres sous trois ventilateurs) se lisait comme un VISAGE. Ici : un
volume BLANC, lisse et rectiligne, hermétique et en surpression ; trois éléments : plafond filtrant (caissons filtre-ventilateur)
ou centrale d'air et ses GAINES rectangulaires, SAS saillant à porte inox et chevrons, HUBLOTS ambre de photolithographie,
décentrés. Aucun tuyau ne touche le bord de l'emprise : le raccord de fluide (nord) est dessiné par le moteur dans les
4 directions. Trois variantes : salle_a (hall à plafond filtrant), salle_b (fab en trois niveaux), salle_c (tour de traitement
d'air et peigne de gaines).
"""
import math

import geo as G
import mat as MT
import organes as O
import palettes as P

D = O.D


def matieres(S, k):
    """Palette hitech + matières propres à la salle blanche (blanc crème lisse, inox poli, peinture vert d'eau des centrales
    d'air, gaines galvanisées, filtres) ; ni écailles ni coulures de rouille sur le blanc et l'inox (bâtiment propre)."""
    M = k.M = P.matieres(S, "hitech")
    MT.PATINE["sans"] = tuple(MT.PATINE.get("sans", ())) + ("blanc", "inox", "filtre")
    sf = MT.surface
    cr = (0.05, 0.042, 0.03)
    M["blanc"] = sf("c_blanc", (0.4, 0.382, 0.34), rough=0.34, met=0.06, tole=(0.66, 0.92), joint=0.58, joint_l=0.011, var=0.035,
                    coulures=0.3, rouille=(0.2, 0.18, 0.14), usure=0.25, nu=(0.62, 0.6, 0.56), crasse=0.6, crasse_col=cr,
                    pied=(0.0, 0.35, 0.45), grain=0.035, graine=51)
    M["blanc_lisse"] = sf("c_blanc_lisse", (0.41, 0.392, 0.35), rough=0.26, met=0.08, usure=0.2, nu=(0.66, 0.64, 0.6), crasse=0.55,
                          crasse_col=cr, grain=0.03, graine=52)
    M["inox"] = sf("c_inox", (0.42, 0.405, 0.38), rough=0.22, met=0.95, usure=0.25, nu=(0.75, 0.74, 0.72), crasse=0.5,
                   crasse_col=(0.03, 0.028, 0.025), grain=0.04, graine=53)
    M["vert_eau"] = sf("c_vert_eau", (0.1, 0.22, 0.19), rough=0.45, met=0.3, tole=(0.55, 0.42), joint=0.55, var=0.07, coulures=0.5,
                       rouille=(0.16, 0.08, 0.035), usure=0.7, nu=(0.55, 0.53, 0.5), crasse=0.8, crasse_col=(0.01, 0.009, 0.006),
                       pied=(0.0, 0.6, 0.5), grain=0.1, graine=54)
    M["galva"] = sf("c_galva", (0.42, 0.42, 0.405), rough=0.42, met=0.35, tole=(1.0, 0.36), joint=0.55, var=0.06, coulures=0.4,
                    rouille=(0.16, 0.1, 0.05), usure=0.5, nu=(0.62, 0.6, 0.57), crasse=0.75, crasse_col=(0.012, 0.01, 0.007),
                    grain=0.08, graine=55)
    M["filtre"] = sf("c_filtre", (0.36, 0.345, 0.31), rough=0.8, met=0.0, usure=0.0, crasse=0.6, crasse_col=(0.14, 0.12, 0.09),
                     grain=0.12, graine=56)
    # ambre de photolithographie ≈ (255, 190, 70) sRGB, plus fort au bas de chaque vitre (critique du 4/11 : dégradé, ≤ 20 % écrêté)
    M["ambre"] = P.lueur(S, "c_ambre", (1.0, 0.51, 0.06), 1.5, 0.5, grad=(0.4, 1.0, 1.0, 0.42), part=0.35, echelle=9.0)
    return M


# ------------------------------------------------------------------------------------------------ organes de la salle
def gaine(k, mat, pts, w, h, bride="acier", pas=None):
    """Gaine rectangulaire le long d'une polyligne aux segments parallèles aux axes : section w (largeur) × h (hauteur, ou
    profondeur pour un segment vertical) ; colliers aux milieux des segments assez longs, ou tous les pas (critique du 4/11 :
    une bride tous les 0,4 tuile) et à chaque coude."""
    for j, (a, b) in enumerate(zip(pts[:-1], pts[1:])):
        d = [abs(b[i] - a[i]) for i in range(3)]
        ax = d.index(max(d))
        c = G.lerp(a, b, 0.5)
        L = d[ax] + (w if ax != 2 else h)
        s = [(L, w, h), (w, L, h), (w, h, d[2] + h)][ax]
        k.b(mat, c, s)
        sb = [(0.035, w + 0.045, h + 0.045), (w + 0.045, 0.035, h + 0.045), (w + 0.045, h + 0.045, 0.035)][ax]
        if pas:
            n = int(d[ax] / pas)
            for i in range(1, n + 1):
                p = G.lerp(a, b, min(1.0, i * pas / d[ax]))
                if G.length(G.sub(p, b)) > 0.12:
                    k.b(bride, p, sb)
            if j:
                k.b(bride, a, sb)
        elif d[ax] > 0.5:
            k.b(bride, c, sb)


def hublot(k, x, y, z, r, verre="ambre", cadre="acier_clair", n=(0.0, -1.0, 0.0)):
    """Hublot rond sur une face (normale n) : cadre saillant, joint noir, verre."""
    p0 = G.add((x, y, z), G.mul(n, -0.02))
    p1 = G.add((x, y, z), G.mul(n, 0.035))
    k.axe(cadre, p0, p1, r * 1.32, 22)
    k.axe("noir", p1, G.add(p1, G.mul(n, 0.006)), r * 1.08, 22, cap=True)
    k.put(verre, G.oriente(G.tour([(0.0, r), (r * 0.12, r * 0.6), (r * 0.16, 0.0)], 22, "z"), G.add(p1, G.mul(n, 0.006)), n))


def fenetre(k, x, y, z0, l, h, verre="ambre"):
    """Fenêtre rectangulaire sur une face sud : tableau sombre en creux, verre, appui."""
    k.b("noir", (x, y - 0.006, z0 + h / 2.0), (l + 0.06, 0.02, h + 0.06))
    k.b(verre, (x, y - 0.017, z0 + h / 2.0), (l, 0.008, h))
    k.b("acier_clair", (x, y - 0.03, z0 - 0.035), (l + 0.1, 0.05, 0.03))


def ffu(k, x, y, z, sx, sy, ph, voyant=True, anime=True):
    """Caisson filtre-ventilateur (plafond HEPA vu de dessus) : cadre, face filtrante à mailles, moteur et ventilateur
    centraux (mobiles, sauf anime=False), voyant de marche vert."""
    k.caisson("galva", x, y, z, sx, sy, 0.13, 0.025)
    k.b("filtre", (x, y, z + 0.131), (sx * 0.86, sy * 0.86, 0.004))
    for i in range(1, 5):
        k.b("acier", (x - sx * 0.43 + sx * 0.86 * i / 5.0, y, z + 0.136), (0.01, sy * 0.86, 0.006))
        k.b("acier", (x, y - sy * 0.43 + sy * 0.86 * i / 5.0, z + 0.136), (sx * 0.86, 0.012, 0.006))
    R = min(sx, sy / D) * 0.3
    k.rev("noir", x, y, [(z + 0.13, R * 1.18), (z + 0.2, R * 1.12), (z + 0.2, R * 1.02), (z + 0.15, R * 0.98)], 24, cap=False)
    k.ventilo(x, y, z + 0.22, R, corps="acier_clair", lame="acier_clair", ph=ph, lames=5, anime=anime)
    if voyant:
        k.voyant_h("voyant_v", x + sx * 0.36, y - sy * 0.36, z + 0.13, 0.022)


def sas(k, x, y_face, z0, l, prof, h, mat="blanc_lisse"):
    """Sas à douche d'air : caisson saillant au sud (face en y_face), porte inox à oculus, lampe verte, buses, chevrons."""
    k.caisson(mat, x, y_face + prof / 2.0, z0, l, prof, h, 0.04)
    k.b("noir", (x, y_face - 0.004, z0 + 0.42), (l * 0.5, 0.012, 0.8))
    k.b("inox", (x, y_face - 0.012, z0 + 0.41), (l * 0.44, 0.012, 0.76))
    k.b("verre", (x, y_face - 0.02, z0 + 0.6), (l * 0.12, 0.006, 0.26))
    k.b("acier_clair", (x + l * 0.16, y_face - 0.024, z0 + 0.42), (0.016, 0.014, 0.1))
    k.caisson("noir", x, y_face + 0.02, z0 + 0.86, 0.16, 0.06, 0.07, 0.01)
    k.voyant("voyant_v", x - 0.035, y_face - 0.012, z0 + 0.895, 0.016)
    k.voyant("voyant_r", x + 0.035, y_face - 0.012, z0 + 0.895, 0.012)
    for sg in (-1, 1):
        k.b("acier_clair", (x + sg * l * 0.36, y_face - 0.01, z0 + 0.5), (0.06, 0.012, 0.72))
        for i in range(4):
            k.b("noir", (x + sg * l * 0.36, y_face - 0.018, z0 + 0.24 + i * 0.16), (0.03, 0.006, 0.03))
    k.plaque("jaune", x - l * 0.36, y_face, z0 + h - 0.12, 0.16, 0.08)


def cheminee(k, x, y, z1, r=0.16):
    """Cheminée du laveur d'extraction : fût inox, colliers, bande de danger, chapeau, feu rouge."""
    k.cyl("inox", x, y, 0.04, z1, r, 20)
    k.cerclages("acier", x, y, (0.4, z1 * 0.45, z1 * 0.75), r, e=0.016, h=0.025, segs=20)
    k.rev("chevron", x, y, [(z1 - 0.32, r + 0.004), (z1 - 0.14, r + 0.004)], 20, cap=False)
    k.rev("acier_clair", x, y, [(z1, r * 1.25), (z1 + 0.05, r * 1.25), (z1 + 0.14, r * 0.5)], 20)
    k.cyl("noir", x, y, z1 + 0.14, z1 + 0.22, 0.012, 6)
    k.sph("voyant_r", (x, y, z1 + 0.25), 0.03, 8, 5)


def cuves_eau(k, x, ys, hs, r):
    """Cuves inox d'eau ultrapure, bandes bleues, piquage vers le bâtiment."""
    for y, h in zip(ys, hs):
        k.cuve("inox", x, y, 0.04, h, r, 0.3, 26)
        k.cerclages("bleu", x, y, (0.3, h - r * 0.5), r, e=0.012, h=0.03, segs=26)
        k.cyl("noir", x, y, h, h + 0.05, 0.05, 8)


def armoire_gaz(k, x, y, l=0.62, h=1.1):
    """Armoire à gaz jaune : porte vitrée, voyant orange, pictogramme, tuyaux jaunes au-dessus."""
    k.caisson("jaune", x, y, 0.04, l, 0.5, h, 0.03)
    yf = y - 0.25
    k.b("jaune", (x, yf - 0.006, 0.04 + h * 0.5), (l * 0.86, 0.012, h * 0.84))
    k.b("verre", (x - l * 0.12, yf - 0.014, 0.04 + h * 0.62), (l * 0.36, 0.006, h * 0.32))
    k.b("noir", (x + l * 0.24, yf - 0.014, 0.04 + h * 0.62), (0.07, 0.006, 0.07), rz=0.0, ry=math.radians(45))
    k.voyant("voyant_o", x + l * 0.3, yf - 0.012, 0.04 + h * 0.86, 0.016)


# ------------------------------------------------------------------------------------------------ a : hall à plafond filtrant
def salle_a(S, k):
    """Hall blanc bas ; toit = grille 4 × 3 de caissons filtre-ventilateur ; centrale d'air vert d'eau au nord, deux gaines
    qui plongent dans le plénum ; hublots ambre à l'est de la façade sud ; sas au sud-ouest ; eau ultrapure, gaz et
    cheminée du laveur à l'est."""
    matieres(S, k)
    k.sol("noir", 5, h=0.06, ch=0.34)
    x0, x1, y0, y1, zt = -2.3, 1.6, -2.47, 2.03, 1.26
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    k.bz("noir", cx, cy, 0.0, x1 - x0 + 0.05, y1 - y0 + 0.05, 0.1)
    k.caisson("blanc", cx, cy, 0.06, x1 - x0, y1 - y0, zt - 0.06, 0.04)
    # poteaux de façade (rythme des panneaux), acrotère
    for i in range(7):
        x = x0 + 0.03 + i * (x1 - x0 - 0.06) / 6.0
        k.b("acier_clair", (x, y0 - 0.012, 0.66), (0.045, 0.022, 1.18))
    for (a, b, c_, s_) in (((cx, y0 + 0.04, zt + 0.05), None, None, (x1 - x0, 0.08, 0.1)), ((cx, y1 - 0.04, zt + 0.05), None, None, (x1 - x0, 0.08, 0.1)),
                           ((x0 + 0.04, cy, zt + 0.05), None, None, (0.08, y1 - y0, 0.1)), ((x1 - 0.04, cy, zt + 0.05), None, None, (0.08, y1 - y0, 0.1))):
        k.b("galva", a, s_)
    # plafond filtrant : 4 × 3 caissons
    sx, sy = 0.78, 0.78 * D
    for j, y in enumerate((-1.74, -0.53, 0.68)):
        for i, x in enumerate((-1.74, -0.85, 0.04, 0.93)):
            ffu(k, x, y, zt, sx, sy, (k.phase + 0.13 * i + 0.29 * j) % 1.0, voyant=(i + j) % 2 == 0)
    # plénum de reprise au nord du toit, gaines vers la centrale
    k.caisson("galva", cx + 0.05, 1.62, zt, 3.6, 0.72, 0.42, 0.03)
    k.persiennes("acier", cx - 1.1, 1.255, zt + 0.08, 0.9, 0.26, 4)
    # centrale de traitement d'air (vert d'eau) au nord
    ax, ay = -0.85, 2.82
    k.caisson("vert_eau", ax, ay, 0.04, 2.9, 1.16, 1.78, 0.06)
    for x in (ax - 1.0, ax - 0.2, ax + 0.6):
        k.b("vert_eau", (x, ay - 0.585, 1.6), (0.7, 0.012, 0.3))
        k.b("acier_clair", (x + 0.28, ay - 0.595, 1.6), (0.03, 0.012, 0.1))
    k.rev("noir", ax - 0.95, ay + 0.05, [(1.82, 0.46), (1.92, 0.46), (1.92, 0.42), (1.85, 0.41)], 28, cap=False)
    k.ventilo(ax - 0.95, ay + 0.05, 1.95, 0.42, corps="vert_eau", ph=(k.phase + 0.5) % 1.0, lames=7)
    k.caisson("galva", ax + 0.75, ay + 0.1, 1.82, 1.15, 0.86, 0.32, 0.03)
    k.persiennes("acier", ax + 0.75, ay - 0.34, 1.84, 1.05, 0.28, 5)
    gaine(k, "galva", [(ax - 0.1, ay - 0.2, 1.82), (ax - 0.1, ay - 0.2, 2.2), (ax - 0.1, 1.72, 2.2), (ax - 0.1, 1.72, zt + 0.42)], 0.52, 0.4)
    gaine(k, "galva", [(0.9, ay - 0.45, 0.6), (0.9, ay - 0.45, 1.95), (0.9, 1.7, 1.95), (0.9, 1.7, zt + 0.42)], 0.4, 0.34)
    k.b("vert_eau", (0.9, ay - 0.2, 0.36), (0.62, 0.62, 0.64))
    k.moteur("car2", 0.9, ay + 0.26, 0.08, 0.5, 0.17)
    # façade sud : hublots ambre (salle jaune) décentrés à l'est, clapets de surpression, manomètre, passe-plat
    for i in range(5):
        fenetre(k, -0.12 + i * 0.36, y0, 0.42, 0.26, 0.56)
    k.b("acier_clair", (0.6, y0 - 0.03, 1.07), (1.86, 0.05, 0.03))
    for x in (-1.05, -0.78):
        k.b("noir", (x, y0 - 0.006, 1.02), (0.2, 0.015, 0.16))
        k.persiennes("acier_clair", x, y0 - 0.008, 0.95, 0.17, 0.14, 3)
    k.axe("noir", (-0.62, y0, 0.64), (-0.62, y0 - 0.03, 0.64), 0.06, 16)
    k.axe("blanc_lisse", (-0.62, y0 - 0.03, 0.64), (-0.62, y0 - 0.034, 0.64), 0.048, 16)
    k.b("rouge", (-0.62 + 0.012, y0 - 0.038, 0.655), (0.008, 0.004, 0.04), ry=math.radians(-40))
    k.caisson("inox", -0.82, y0 - 0.14, 0.38, 0.38, 0.28, 0.34, 0.02)
    k.b("acier_clair", (-0.82, y0 - 0.282, 0.55), (0.28, 0.008, 0.24))
    # sas au sud-ouest
    sas(k, -1.62, -3.22, 0.04, 0.94, 0.77, 1.02)
    ffu(k, -1.62, -2.84, 1.06, 0.5, 0.6, (k.phase + 0.71) % 1.0, voyant=False)
    k.bz("chevron", -1.62, -3.38, 0.0, 0.84, 0.2, 0.018)
    # est : eau ultrapure, armoire à gaz, cheminée du laveur, rampe de tuyaux qui entre par le mur est
    cuves_eau(k, 2.08, (-2.15, -1.2), (1.5, 1.2), 0.3)
    armoire_gaz(k, 2.02, -0.12, 0.6, 1.08)
    cheminee(k, 2.05, 1.5, 2.7, 0.16)
    k.tuyau("galva", [(1.6, 1.5, 0.95), (1.89, 1.5, 0.95)], r=0.1, brides=[(1.7, 1.5, 0.95)], bride_mat="acier")
    for i, (m_, z) in enumerate((("bleu", 0.92), ("orange", 0.8), ("jaune", 0.68))):
        y = -2.15 + 0.95 * min(i, 1) if i < 2 else -0.12
        k.tuyau(m_, [(2.08 - 0.3 if i < 2 else 2.02, y, z), (1.72, y, z), (1.72, -0.7 + i * 0.12, z), (1.6, -0.7 + i * 0.12, z)], r=0.032,
                coude=0.08, brides=[], bride_mat="acier")
    k.armoire("car2", 2.0, 2.62, 0.04, 0.6, 0.78, 0.3, lampe="voyant")


# ------------------------------------------------------------------------------------------------ b : fab en trois niveaux
def salle_b(S, k):
    """La coupe d'une usine de puces : sous-fab sombre (pompes, rampe de tuyaux), salle blanche au milieu (hublots ronds ambre,
    sas sur escalier), étage des ventilateurs au-dessus (persiennes, 2 × 3 ventilateurs de toit), cuves et gaz à l'est."""
    matieres(S, k)
    k.sol("noir", 5, h=0.06, ch=0.34)
    # sous-fab
    x0, x1, y0, y1 = -2.35, 1.45, -2.62, 2.55
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    zs, zc, zf = 0.55, 1.42, 1.98
    k.caisson("car2", cx, cy, 0.0, x1 - x0, y1 - y0, zs, 0.03)
    k.persiennes("noir", cx - 1.15, y0, 0.08, 1.1, 0.34, 5, fond="acier")
    k.persiennes("noir", cx + 1.25, y0, 0.08, 0.7, 0.34, 5, fond="acier")
    for i, (m_, z) in enumerate((("bleu", 0.42), ("orange", 0.3), ("jaune", 0.18), ("galva", 0.46))):
        k.tuyau(m_, [(x0 + 0.05, y0 - 0.08 - 0.07 * (i % 2), z), (x1 - 0.05, y0 - 0.08 - 0.07 * (i % 2), z)], r=0.03 if i < 3 else 0.022,
                brides=[(x0 + 0.6 + 0.9 * j, y0 - 0.08 - 0.07 * (i % 2), z) for j in range(4)], bride_mat="acier")
    for x in (-1.75, 0.55):
        k.moteur("car", x, y0 - 0.2, 0.02, 0.5, 0.13, ailette="noir")
        k.bz("noir", x, y0 - 0.2, 0.0, 0.56, 0.2, 0.04)
    # salle blanche (retrait de 0,2), hublots ronds ambre, rangée irrégulière
    sx0, sx1, sy0, sy1 = x0 + 0.18, x1 - 0.15, y0 + 0.18, y1 - 0.22
    scx, scy = (sx0 + sx1) / 2.0, (sy0 + sy1) / 2.0
    k.caisson("blanc", scx, scy, zs, sx1 - sx0, sy1 - sy0, zc - zs, 0.03)
    k.b("acier_clair", (scx, sy0 - 0.012, zs + 0.03), (sx1 - sx0, 0.03, 0.05))
    for x in (-1.82, -1.34, 0.18, 0.62, 1.06):
        hublot(k, x, sy0, 1.0, 0.13)
    # sas sur escalier (chevrons), au centre gauche
    sas(k, -0.55, sy0 - 0.62, zs, 0.86, 0.62, zc - zs - 0.02)
    for i in range(4):
        k.bz("acier" if i % 2 else "chevron", -0.55, sy0 - 0.66 - 0.15 * (i + 1), 0.0, 0.7, 0.16, zs - 0.13 * (i + 0.6))
    k.rambarde("acier_clair", [(-0.95, sy0 - 1.25, 0.0), (-0.95, sy0 - 0.65, zs)], 0.32, 0.25)
    # étage des ventilateurs : persiennes continues, 2 × 3 ventilateurs, gaine qui descend à l'ouest
    fx0, fx1, fy0, fy1 = sx0 + 0.12, sx1 - 0.1, sy0 + 0.3, sy1 - 0.08
    fcx, fcy = (fx0 + fx1) / 2.0, (fy0 + fy1) / 2.0
    k.caisson("galva", fcx, fcy, zc, fx1 - fx0, fy1 - fy0, zf - zc, 0.04)
    k.persiennes("acier_clair", fcx + 0.25, fy0, zc + 0.08, fx1 - fx0 - 0.7, zf - zc - 0.16, 7, fond="noir")
    k.b("vert_eau", (fx0 + 0.2, fy0 - 0.01, (zc + zf) / 2.0), (0.32, 0.02, zf - zc - 0.1))
    for j, y in enumerate((fcy - 0.95, fcy + 0.75)):
        for i, x in enumerate((fcx - 1.15, fcx - 0.05, fcx + 1.02)):
            R = 0.36 if (i + j) % 2 == 0 else 0.3
            k.rev("vert_eau", x, y, [(zf, R * 1.2), (zf + 0.16, R * 1.16), (zf + 0.16, R * 1.03), (zf + 0.08, R * 1.0)], 26, cap=False)
            k.ventilo(x, y, zf + 0.18, R, corps="noir", ph=(k.phase + 0.17 * i + 0.4 * j) % 1.0, lames=6)
    gaine(k, "galva", [(x0 + 0.12, 1.4, zf - 0.1), (x0 + 0.12, 1.4, 0.3)], 0.32, 0.5)
    # est : cuves d'eau ultrapure, gaz, cheminée
    cuves_eau(k, 2.02, (-2.3, -1.35), (1.4, 1.15), 0.3)
    armoire_gaz(k, 1.98, -0.25, 0.58, 1.05)
    cheminee(k, 2.0, 1.25, 2.85, 0.15)
    k.tuyau("galva", [(1.3, 1.25, 1.75), (1.85, 1.25, 1.75)], r=0.09, brides=[(1.5, 1.25, 1.75)], bride_mat="acier")
    k.armoire("car2", 2.0, 2.55, 0.04, 0.56, 0.74, 0.3, lampe="voyant")
    for i, m_ in enumerate(("bleu", "orange")):
        k.tuyau(m_, [(1.78, -2.3 + 0.95 * i, 0.9 - 0.12 * i), (1.6, -2.3 + 0.95 * i, 0.9 - 0.12 * i), (1.6, -1.0, 0.9 - 0.12 * i),
                     (1.3, -1.0, 0.9 - 0.12 * i)], r=0.03, coude=0.08, brides=[])


# ------------------------------------------------------------------------------------------------ c : tour de traitement d'air
def salle_c(S, k):
    """Tour de traitement d'air vert d'eau au nord-ouest (bancs de filtres étagés, échelle, passerelle, grand ventilateur au
    sommet), pont de gaine qui court sur le toit du hall blanc et y plonge en peigne ; hublots ronds ambre et sas au sud ;
    eau ultrapure et gaz au sud-ouest ; cheminée du laveur au nord-est."""
    matieres(S, k)
    k.sol("noir", 5, h=0.06, ch=0.34)
    # hall blanc à l'est
    x0, x1, y0, y1, zt = -1.0, 2.25, -2.62, 1.75, 1.18
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    k.bz("noir", cx, cy, 0.0, x1 - x0 + 0.05, y1 - y0 + 0.05, 0.1)
    k.caisson("blanc", cx, cy, 0.06, x1 - x0, y1 - y0, zt - 0.06, 0.035)
    for i in range(6):
        k.b("acier_clair", (x0 + 0.03 + i * (x1 - x0 - 0.06) / 5.0, y0 - 0.012, 0.62), (0.045, 0.022, 1.1))
    # toit : caissons filtrants bas en deux rangées (sans ventilateur visible), le peigne de gaines y plonge
    for j, y in enumerate((-1.75, -0.45, 0.85)):
        for i, x in enumerate((-0.55, 0.32, 1.19, 1.95)):
            if (i, j) in ((0, 2),):
                continue
            k.caisson("galva", x, y, zt, 0.66, 0.66 * D, 0.1, 0.02)
            k.b("filtre", (x, y, zt + 0.101), (0.56, 0.56 * D, 0.004))
    # tour au nord-ouest : 3 étages de filtres derrière persiennes, portes de visite, échelle, passerelle, ventilateur
    tx, ty, tl, tp, th = -1.72, 1.15, 1.3, 2.3, 2.75
    k.caisson("vert_eau", tx, ty, 0.04, tl, tp, th, 0.06)
    yf = ty - tp / 2.0
    for i, z in enumerate((0.22, 1.02, 1.82)):
        k.persiennes("galva", tx - 0.12, yf, z, tl - 0.5, 0.56, 6, fond="noir")
        k.b("vert_eau", (tx + 0.46, yf - 0.006, z + 0.28), (0.26, 0.012, 0.58))
        k.b("acier_clair", (tx + 0.38, yf - 0.016, z + 0.3), (0.016, 0.012, 0.08))
        k.plaque("blanc_lisse", tx - 0.12, yf - 0.006, z + 0.64, 0.3, 0.06)
    k.echelle("acier", tx + 0.6, yf - 0.06, 0.04, th + 0.05, 0.14)
    k.bz("acier", tx, yf - 0.12, th - 0.04, tl + 0.06, 0.25, 0.03)
    k.rambarde("acier_clair", [(tx - tl / 2.0, yf - 0.22, th), (tx + tl / 2.0, yf - 0.22, th)], 0.2, 0.3)
    k.rev("noir", tx - 0.05, ty + 0.15, [(th, 0.56), (th + 0.14, 0.55), (th + 0.14, 0.5), (th + 0.06, 0.49)], 30, cap=False)
    k.ventilo(tx - 0.05, ty + 0.15, th + 0.16, 0.5, corps="vert_eau", ph=k.phase, lames=7)
    # pont de gaine : de la tour vers l'est, au-dessus du toit, trois descentes en peigne
    gy, gz = 0.85, 1.9
    gaine(k, "galva", [(tx + tl / 2.0 - 0.1, gy, gz), (1.72, gy, gz)], 0.46, 0.42)
    for x in (-0.55, 0.32, 1.19):
        gaine(k, "galva", [(x, gy, gz), (x, gy, zt + 0.1)], 0.3, 0.42)
    gaine(k, "galva", [(1.72, gy, gz), (1.72, -0.45, gz), (1.72, -0.45, zt + 0.1)], 0.3, 0.3)
    for x in (-0.15, 0.75, 1.55):
        k.axe("acier", (x, gy, zt + 0.1), (x, gy, gz - 0.2), 0.022, 6)
    # façade sud : hublots ronds ambre, sas
    for x in (0.12, 0.62, 1.12, 1.62, 2.02):
        hublot(k, x, y0, 0.66, 0.135)
    sas(k, -0.5, -3.2, 0.04, 0.84, 0.58, 1.0)
    k.bz("chevron", -0.5, -3.36, 0.0, 0.76, 0.18, 0.018)
    for x in (0.35, 1.35):
        k.b("noir", (x + 0.25, y0 - 0.006, 1.0), (0.2, 0.015, 0.14))
        k.persiennes("acier_clair", x + 0.25, y0 - 0.008, 0.94, 0.17, 0.12, 3)
    # sud-ouest : eau ultrapure et armoire à gaz ; nord-est : cheminée et coffret
    cuves_eau(k, -2.1, (-2.75, -1.75), (1.3, 1.05), 0.27)
    armoire_gaz(k, -1.5, -2.7, 0.5, 1.0)
    for i, m_ in enumerate(("bleu", "jaune")):
        k.tuyau(m_, [(-1.85, -1.75 - 0.5 * i, 0.85 - 0.1 * i), (-1.2, -1.75 - 0.5 * i, 0.85 - 0.1 * i), (-1.2, -1.2, 0.85 - 0.1 * i),
                     (-1.0, -1.2, 0.85 - 0.1 * i)], r=0.03, coude=0.08, brides=[])
    cheminee(k, 2.0, 2.55, 2.6, 0.15)
    k.tuyau("galva", [(2.0, 1.75, 0.9), (2.0, 2.4, 0.9)], r=0.09, brides=[(2.0, 2.0, 0.9)], bride_mat="acier")
    k.armoire("car2", 0.9, 2.55, 0.04, 0.7, 0.76, 0.3, lampe="voyant")


# ------------------------------------------------------------------------------------------------ RETENUE : a + tour d'air de c
def fenetre_litho(k, x, y, z0, l, h):
    """Hublot de la salle jaune (critique du 4/11) : vitre ambre en dégradé, silhouettes sombres des machines de
    photolithographie derrière (colonne d'optique, banc, bras), meneaux et cadre saillant qui donnent la profondeur."""
    k.b("noir", (x, y - 0.006, z0 + h / 2.0), (l + 0.08, 0.02, h + 0.08))
    k.b("ambre", (x, y - 0.018, z0 + h / 2.0), (l, 0.006, h))
    yy = y - 0.026
    k.b("noir", (x - l * 0.18, yy, z0 + h * 0.2), (l * 0.5, 0.008, h * 0.4))          # banc de l'insolateur
    k.b("noir", (x - l * 0.08, yy, z0 + h * 0.5), (l * 0.16, 0.008, h * 0.62))        # colonne d'optique
    k.b("noir", (x - l * 0.08, yy, z0 + h * 0.78), (l * 0.3, 0.008, h * 0.1))
    k.b("noir", (x + l * 0.3, yy, z0 + h * 0.16), (l * 0.22, 0.008, h * 0.32))        # piste de résine
    k.b("noir", (x + l * 0.24, yy, z0 + h * 0.4), (l * 0.05, 0.008, h * 0.3), ry=math.radians(-35))
    for sg in (-1, 1):
        k.b("acier_clair", (x + sg * (l / 2.0 + 0.02), y - 0.05, z0 + h / 2.0), (0.035, 0.06, h + 0.06))
    k.b("acier_clair", (x, y - 0.05, z0 + h + 0.02), (l + 0.08, 0.06, 0.035))
    k.b("acier_clair", (x, y - 0.06, z0 - 0.03), (l + 0.12, 0.08, 0.035))
    k.b("noir", (x, y - 0.03, z0 + h * 0.62), (l, 0.01, 0.012))


def sas_final(k, x, y_face, z0, l, prof, h):
    """Sas à douche d'air saillant (0,6 tuile) : caisson blanc lisse, porte inox à oculus, linteau à chevrons jaunes et noirs
    de 0,22 (0,16 tuile à l'écran), lampes verte et rouge, manomètre, petit caisson filtrant sur le toit."""
    k.caisson("blanc_lisse", x, y_face + prof / 2.0, z0, l, prof, h, 0.04)
    hc = 0.22
    k.b("chevron", (x, y_face - 0.008, z0 + h - 0.06 - hc / 2.0), (l * 0.96, 0.014, hc))
    hp = h - 0.1 - hc
    k.b("noir", (x, y_face - 0.004, z0 + hp / 2.0), (l * 0.5, 0.012, hp))
    k.b("inox", (x, y_face - 0.012, z0 + hp / 2.0 - 0.01), (l * 0.44, 0.012, hp - 0.04))
    k.b("verre", (x, y_face - 0.02, z0 + hp * 0.66), (l * 0.12, 0.006, hp * 0.32))
    k.b("acier_clair", (x + l * 0.16, y_face - 0.024, z0 + hp * 0.5), (0.016, 0.014, 0.1))
    k.voyant("voyant_v", x - l * 0.38, y_face - 0.006, z0 + hp * 0.82, 0.02)
    k.voyant("voyant_r", x - l * 0.38, y_face - 0.006, z0 + hp * 0.66, 0.016)
    k.axe("noir", (x + l * 0.37, y_face, z0 + hp * 0.7), (x + l * 0.37, y_face - 0.025, z0 + hp * 0.7), 0.05, 14)
    k.axe("blanc_lisse", (x + l * 0.37, y_face - 0.025, z0 + hp * 0.7), (x + l * 0.37, y_face - 0.029, z0 + hp * 0.7), 0.04, 14)
    k.b("rouge", (x + l * 0.37 + 0.01, y_face - 0.032, z0 + hp * 0.7 + 0.01), (0.007, 0.004, 0.032), ry=math.radians(-40))
    ffu(k, x, y_face + prof / 2.0, z0 + h, l * 0.56, prof * 0.62, 0.71, voyant=False, anime=False)


def tour_air(k, tx, ty, tl, tp, th):
    """Tour de traitement d'air vert d'eau (reprise de la variante c) : 3 étages de filtres derrière persiennes, portes de
    visite, échelle, passerelle à garde-corps, grand ventilateur au sommet (la seule pièce mobile)."""
    k.caisson("vert_eau", tx, ty, 0.04, tl, tp, th, 0.06)
    yf = ty - tp / 2.0
    for z in (0.22, 1.0, 1.78):
        k.persiennes("galva", tx - 0.12, yf, z, tl - 0.5, 0.56, 6, fond="noir")
        k.b("vert_eau", (tx + 0.44, yf - 0.006, z + 0.28), (0.26, 0.012, 0.58))
        k.b("acier_clair", (tx + 0.36, yf - 0.016, z + 0.3), (0.016, 0.012, 0.08))
        k.plaque("blanc_lisse", tx - 0.12, yf - 0.006, z + 0.64, 0.3, 0.06)
    k.echelle("acier", tx + 0.58, yf - 0.06, 0.04, th + 0.05, 0.14)
    k.bz("acier", tx, yf - 0.12, th - 0.04, tl + 0.06, 0.25, 0.03)
    k.rambarde("acier_clair", [(tx - tl / 2.0, yf - 0.22, th), (tx + tl / 2.0, yf - 0.22, th)], 0.2, 0.3)
    k.rev("noir", tx - 0.05, ty + 0.12, [(th, 0.54), (th + 0.14, 0.53), (th + 0.14, 0.48), (th + 0.06, 0.47)], 30, cap=False)
    k.ventilo(tx - 0.05, ty + 0.12, th + 0.16, 0.48, corps="vert_eau", ph=k.phase, lames=7)


def salle(S, k):
    """SALLE BLANCHE RETENUE (critique du 4/11 : variante a, avec la tour d'air de c) : hall blanc réduit à plafond filtrant de
    3 × 3 caissons, tour de traitement d'air vert d'eau au nord-ouest, deux gaines galvanisées longues et minces à brides qui
    courent sur le bord nord du toit et plongent dans le plénum par un coude, hublots ambre décentrés à l'est avec les
    silhouettes des machines, sas saillant à l'ouest de la façade sud, cuves inox, armoire à gaz et cheminée à l'est, pompes à
    vide et transformateur au sud-ouest. Aucun tuyau ne touche le bord de l'emprise. Seul le ventilateur de la tour tourne."""
    matieres(S, k)
    k.sol("noir", 5, h=0.06, ch=0.34, patins=[(-0.4, -2.1, 2.0), (1.2, -2.1, 2.0)])
    # hall
    x0, x1, y0, y1, zt = -1.0, 1.62, -2.3, 2.2, 1.26
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    k.bz("noir", cx, cy, 0.0, x1 - x0 + 0.05, y1 - y0 + 0.05, 0.1)
    k.caisson("blanc", cx, cy, 0.06, x1 - x0, y1 - y0, zt - 0.06, 0.04)
    for i in range(5):
        k.b("acier_clair", (x0 + 0.03 + i * (x1 - x0 - 0.06) / 4.0, y0 - 0.012, 0.66), (0.045, 0.022, 1.18))
    for c_, s_ in (((cx, y0 + 0.035, zt + 0.045), (x1 - x0, 0.07, 0.09)), ((cx, y1 - 0.035, zt + 0.045), (x1 - x0, 0.07, 0.09)),
                   ((x0 + 0.035, cy, zt + 0.045), (0.07, y1 - y0, 0.09)), ((x1 - 0.035, cy, zt + 0.045), (0.07, y1 - y0, 0.09))):
        k.b("galva", c_, s_)
    # plafond filtrant 3 × 3 (petits ventilateurs fixes sous grille)
    sx, sy = 0.74, 0.74 * D
    for j, y in enumerate((-1.7, -0.56, 0.58)):
        for i, x in enumerate((-0.55, 0.31, 1.17)):
            ffu(k, x, y, zt, sx, sy, (0.13 * i + 0.29 * j) % 1.0, voyant=(i + j) % 2 == 0, anime=False)
    # plénum de reprise au nord du toit
    k.caisson("galva", 0.31, 1.67, zt, 2.46, 0.86, 0.32, 0.03)
    k.persiennes("acier", -0.35, 1.24, zt + 0.07, 0.8, 0.2, 3)
    # tour d'air au nord-ouest, deux gaines longues à brides vers le plénum (coude à 90°)
    tx, ty, tl, tp, th = -1.77, 1.62, 1.2, 2.15, 2.7
    tour_air(k, tx, ty, tl, tp, th)
    xe = tx + tl / 2.0 - 0.05
    gaine(k, "galva", [(xe, 2.0, 2.28), (0.05, 2.0, 2.28), (0.05, 2.0, zt + 0.32)], 0.42, 0.34, pas=0.4)
    gaine(k, "galva", [(xe, 1.42, 1.98), (1.08, 1.42, 1.98), (1.08, 1.42, zt + 0.32)], 0.42, 0.3, pas=0.4)
    for x in (-0.6, 0.6):
        k.axe("acier", (x, 1.42, zt + 0.32), (x, 1.42, 1.83), 0.02, 6)
        k.axe("acier", (x - 0.4, 2.0, zt + 0.32), (x - 0.4, 2.0, 2.11), 0.02, 6)
    # façade sud : hublots de la salle jaune, décentrés à l'est
    for i in range(4):
        fenetre_litho(k, 0.21 + i * 0.37, y0, 0.4, 0.27, 0.58)
    k.b("acier_clair", (0.76, y0 - 0.03, 1.08), (1.5, 0.05, 0.03))
    # sas saillant (0,6 tuile) à l'ouest de la façade sud, chevrons au sol
    sas_final(k, -0.5, y0 - 0.85, 0.04, 0.88, 0.85, 1.0)
    k.bz("chevron", -0.5, y0 - 1.0, 0.0, 0.84, 0.24, 0.02)
    # est : eau ultrapure, armoire à gaz, cheminée du laveur, piquages dans le mur est
    cuves_eau(k, 2.08, (-2.2, -1.25), (1.45, 1.15), 0.3)
    armoire_gaz(k, 2.04, -0.2, 0.6, 1.08)
    cheminee(k, 2.06, 1.45, 2.7, 0.16)
    k.tuyau("galva", [(1.62, 1.45, 0.95), (1.9, 1.45, 0.95)], r=0.1, brides=[(1.72, 1.45, 0.95)], bride_mat="acier")
    for i, (m_, y, z) in enumerate((("bleu", -2.2, 0.9), ("bleu", -1.25, 0.78), ("jaune", -0.2, 0.66))):
        xs = 1.78 if i < 2 else 1.74
        k.tuyau(m_, [(xs, y, z), (1.72, y, z), (1.72, -0.75 + 0.14 * i, z), (1.62, -0.75 + 0.14 * i, z)], r=0.032, coude=0.07, brides=[])
    k.armoire("car2", 2.0, 2.7, 0.04, 0.6, 0.78, 0.3, lampe="voyant")
    # sud-ouest : pompes à vide et transformateur (au pied de la tour)
    for y in (-2.6, -1.85):
        k.bz("noir", -1.8, y, 0.04, 0.9, 0.42, 0.06)
        k.moteur("bleu", -1.95, y, 0.1, 0.5, 0.15, ailette="noir")
        k.rev("bleu", -1.5, y, [(0.1, 0.17), (0.42, 0.17), (0.47, 0.11)], 18)
        k.tuyau("acier_clair", [(-1.5, y, 0.47), (-1.5, y, 0.62), (-1.0, y + 0.2, 0.62)], r=0.03, coude=0.08, brides=[])
    k.caisson("car2", -1.8, -0.55, 0.04, 0.95, 0.9, 0.95, 0.03)
    for i in range(6):
        k.b("acier", (-2.18 + i * 0.152, -1.012, 0.48), (0.05, 0.03, 0.78))
    k.voyant("voyant_o", -1.45, -1.01, 0.88, 0.018)
    k.plaque("jaune", -1.6, -1.0, 0.86, 0.14, 0.08)
    for x in (-2.05, -1.8, -1.55):
        k.cyl("acier_clair", x, -0.55, 0.99, 1.14, 0.045, 10)
        k.cyl("noir", x, -0.55, 1.14, 1.2, 0.03, 8)
    k.armoire("vert_eau", 0.3, 2.75, 0.04, 0.9, 1.0, 0.36, lampe="voyant_v")
