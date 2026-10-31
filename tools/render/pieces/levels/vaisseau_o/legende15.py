"""ÂGE 15 · LÉGENDE (bible DESIGN_EPOQUES §5, époque 15) : le centre de commandement en palais, emprise 16×8. Lot QG, 30/10.

Lecture de gauche à droite (brief QG §3) : tuyères (le passé), cœur-réacteur à nu, palais bâti sur le ventre, crâne à
chevrons et verrière qui regarde l'est. NEZ À DROITE (+X).
- Au sol : socle d'ancrage en pierre sombre, contour découpé (bastions, marches, déflecteur de souffle), la PORTE
  monumentale au sud (invariant du centre : « une porte centrale au sud »), escalier qui monte à la base flottante,
  4 pylônes d'amarrage, treuils, machines, débris.
- Base FLOTTANTE (bible : « vide sous la couronne ») : plateuse à quille étagée, consoles, cristaux de lévitation qui
  pendent, flexibles et câbles qui pendent, rochers en lévitation dans le vide, amarres tendues vers les pylônes.
- Palais : halle à loggia (arcades noires), étage en retrait à terrasse, comble mansardé, 4 tours, donjon à galerie,
  COURONNE DE 5 FLÈCHES d'or blanc (3 tailles), anneau-halo autour de la flèche maîtresse (mât de commandement).
- Squelette du vaisseau : côtes de nacre (os) inclinées vers la queue « (((( » par-dessus le palais, épine dorsale.
Palette (charte DA §6.4) : corps en bronze et pierre sombres chauds ; or blanc #E8DCB0 et nacre #D8D2C8 en ACCENTS
patinés ; peau jaune d'origine sur le crâne, les nacelles et la dérive. FO_GRIS=1 : masses grises (essai de forme).
"""
import math
import os

import geo as G
import greb as R
import l15_vaisseau as N
import mat as MT

PSI = -math.radians(8.0)        # lacet : nez vers le sud-est
PHI = math.radians(10.0)        # roulis du vaisseau : dos vers la caméra
ZP = 1.85                       # dessus de la base flottante
ZS = ZP + 1.25                  # axe du vaisseau
OY = -0.5                       # base : tout le sol dans l'emprise 16×8 (essai 2)
GRIS = os.environ.get("FO_GRIS", "") == "1"
_GRIS = [GRIS]


def F_pal(v):
    p = G.rot_z(v, PSI)
    return (p[0], p[1] + OY, max(0.0, p[2]))


def F_nav(v):
    p = G.rot_z(G.rot_x(v, PHI, (0.0, 0.0, ZS)), PSI)
    return (p[0], p[1] + OY, max(0.0, p[2]))


def F_sol(v):
    return (v[0], v[1], max(0.0, v[2]))


def matieres(S):
    def surf(name, col, **kw):
        if _GRIS[0]:
            return MT.surface("l15g_" + name, (0.13, 0.13, 0.13), rough=0.6, met=0.2, usure=0.3, crasse=0.6, graine=kw.get("graine", 0))
        return MT.surface("l15_" + name, col, **kw)
    M = {}
    MT.PATINE.update(ta=0.15, ra=0.25, ec=0.6, nu_k=1.45, ec_col=(0.03, 0.017, 0.007), sans=("_or", "nacre"))
    M["bronze"] = surf("bronze", (0.1, 0.058, 0.024), rough=0.5, met=0.5, coulures=0.55, rouille=(0.07, 0.028, 0.01), usure=0.65,
                       nu=(0.22, 0.15, 0.08), crasse=0.75, crasse_col=(0.008, 0.006, 0.004), graine=1)
    M["bronze2"] = surf("bronze2", (0.16, 0.09, 0.034), rough=0.48, met=0.5, coulures=0.45, rouille=(0.08, 0.03, 0.01), usure=0.6,
                        nu=(0.25, 0.17, 0.09), crasse=0.7, crasse_col=(0.008, 0.006, 0.004), graine=2)
    M["acier"] = surf("acier", (0.07, 0.052, 0.036), rough=0.5, met=0.6, coulures=0.4, rouille=(0.06, 0.025, 0.01), usure=0.6,
                      nu=(0.16, 0.14, 0.12), crasse=0.7, crasse_col=(0.006, 0.005, 0.004), graine=3)
    M["noyau"] = surf("noyau", (0.011, 0.009, 0.007), rough=0.55, met=0.6, usure=0.3, crasse=0.8, crasse_col=(0.002, 0.002, 0.002), graine=4)
    M["brule"] = surf("brule", (0.009, 0.006, 0.004), rough=0.7, met=0.4, usure=0.0, crasse=0.9, crasse_col=(0.001, 0.001, 0.001), graine=5)
    M["pierre"] = surf("pierre", (0.13, 0.095, 0.058), rough=0.85, met=0.0, tole=(1.55, 1.05), joint=0.55, joint_l=0.01, var=0.14,
                       coulures=0.5, rouille=(0.025, 0.016, 0.01), usure=0.7, nu=(0.13, 0.1, 0.075), crasse=0.85,
                       crasse_col=(0.006, 0.005, 0.004), relief=0.4, graine=6)
    M["pierre2"] = surf("pierre2", (0.075, 0.052, 0.032), rough=0.85, met=0.0, coulures=0.6, rouille=(0.02, 0.012, 0.008), usure=0.7,
                        nu=(0.1, 0.08, 0.06), crasse=0.85, crasse_col=(0.004, 0.003, 0.002), graine=7)
    M["or"] = surf("or", (0.86, 0.73, 0.42), rough=0.4, met=0.25, coulures=0.2, rouille=(0.3, 0.2, 0.08), usure=0.5,
                   nu=(0.95, 0.88, 0.66), crasse=0.45, crasse_col=(0.03, 0.02, 0.008), graine=8)
    M["or_sombre"] = surf("or_sombre", (0.46, 0.31, 0.11), rough=0.45, met=0.4, coulures=0.3, usure=0.6, nu=(0.7, 0.55, 0.28),
                          crasse=0.8, crasse_col=(0.02, 0.012, 0.005), graine=9)
    M["nacre"] = surf("nacre", (0.74, 0.67, 0.54), rough=0.34, met=0.0, coulures=0.45, rouille=(0.1, 0.07, 0.04), usure=0.4,
                      nu=(0.62, 0.58, 0.52), crasse=0.8, crasse_col=(0.03, 0.022, 0.014), graine=10)
    M["jaune"] = surf("jaune", (0.5, 0.29, 0.015), rough=0.55, met=0.35, coulures=0.7, rouille=(0.09, 0.035, 0.01), usure=0.7,
                      nu=(0.42, 0.38, 0.3), crasse=0.8, crasse_col=(0.012, 0.008, 0.004), graine=11)
    M["jaune2"] = surf("jaune2", (0.3, 0.16, 0.014), rough=0.6, met=0.35, coulures=0.75, rouille=(0.08, 0.03, 0.01), usure=0.7,
                       nu=(0.38, 0.33, 0.26), crasse=0.8, crasse_col=(0.012, 0.008, 0.004), graine=12)
    M["chevron"] = surf("chevron", (0.42, 0.25, 0.02), rough=0.55, met=0.35, bandes=(0.32, (0.012, 0.01, 0.008), 0.5), coulures=0.6,
                        rouille=(0.09, 0.035, 0.01), usure=0.7, nu=(0.4, 0.36, 0.3), crasse=0.8, crasse_col=(0.01, 0.007, 0.004), graine=13)
    M["ardoise"] = surf("ardoise", (0.06, 0.045, 0.032), rough=0.6, met=0.25, tole=(0.22, 0.11), joint=0.35, joint_l=0.02, var=0.25,
                        usure=0.6, nu=(0.1, 0.085, 0.07), crasse=0.7, crasse_col=(0.004, 0.003, 0.002), relief=0.6, graine=14)
    M["cuivre"] = surf("cuivre", (0.3, 0.1, 0.035), rough=0.4, met=0.9, coulures=0.4, rouille=(0.05, 0.035, 0.02), usure=0.55,
                       nu=(0.6, 0.32, 0.18), crasse=0.75, crasse_col=(0.01, 0.006, 0.003), graine=15)
    M["caoutchouc"] = surf("caoutchouc", (0.02, 0.018, 0.016), rough=0.75, met=0.0, usure=0.2, crasse=0.5, graine=16)
    M["cable_r"] = surf("cable_r", (0.28, 0.018, 0.01), rough=0.5, met=0.0, usure=0.2, crasse=0.4, graine=17)
    M["cable_n"] = surf("cable_n", (0.012, 0.011, 0.01), rough=0.55, met=0.0, usure=0.2, crasse=0.4, graine=18)
    M["riv"] = surf("riv", (0.04, 0.03, 0.02), rough=0.5, met=0.6, usure=0.4, crasse=0.4, graine=19)
    M["terre"] = surf("terre", (0.11, 0.065, 0.035), rough=0.95, met=0.0, usure=0.0, crasse=0.7, crasse_col=(0.03, 0.018, 0.01), graine=21)
    M["nacre2"] = surf("nacre2", (0.44, 0.33, 0.19), rough=0.35, met=0.15, coulures=0.55, rouille=(0.09, 0.06, 0.035), usure=0.45,
                       nu=(0.62, 0.57, 0.5), crasse=0.85, crasse_col=(0.02, 0.014, 0.008), graine=22)
    M["toit"] = surf("toit", (0.62, 0.46, 0.16), rough=0.42, met=0.35, tole=(0.16, 0.1), joint=0.3, joint_l=0.025, var=0.3, coulures=0.4,
                     rouille=(0.1, 0.06, 0.02), usure=0.55, nu=(0.85, 0.76, 0.5), crasse=0.85, crasse_col=(0.015, 0.01, 0.005), relief=0.7, graine=23)
    M["pont"] = surf("pont", (0.085, 0.06, 0.036), rough=0.7, met=0.3, tole=(0.46, 0.46), joint=0.35, joint_l=0.02, var=0.35, coulures=0.0,
                     usure=0.5, nu=(0.12, 0.1, 0.07), crasse=0.8, crasse_col=(0.004, 0.003, 0.002), relief=0.5, graine=24)
    M["bois"] = surf("bois", (0.07, 0.04, 0.02), rough=0.8, met=0.0, tole=(0.6, 0.09), joint=0.5, var=0.2, usure=0.5, crasse=0.7, graine=20)
    M["verre"] = MT.verre("l15_verre", col=(0.012, 0.01, 0.007), reflet=(0.2, 0.16, 0.09))
    M["cristal_m"] = MT.verre("l15_cristal", col=(0.05, 0.045, 0.03), reflet=(0.5, 0.45, 0.3))
    # lumières : peu de foyers forts (cœur, 3 cristaux, halo, porte), hublots petits et tous différents
    M["lum"] = MT.lumiere(S, "l15_lum", (1.0, 0.86, 0.52), 1.5, main=0.25)
    M["coeur"] = MT.lumiere(S, "l15_coeur", (1.0, 0.48, 0.1), 9.0, main=0.4)
    M["cristal"] = MT.lumiere(S, "l15_cristal_l", (1.0, 0.9, 0.62), 5.0, main=0.35)
    M["halo"] = MT.lumiere(S, "l15_halo", (1.0, 0.93, 0.72), 3.0, main=0.3)
    M["porte"] = MT.lumiere(S, "l15_porte", (1.0, 0.8, 0.45), 2.2, main=0.25)
    M["balise"] = MT.lumiere(S, "l15_balise", (1.0, 0.12, 0.04), 6.0, main=0.4)
    return M


def sc(poly, k, c=None):
    if c is None:
        c = (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))
    return [(c[0] + (p[0] - c[0]) * k, c[1] + (p[1] - c[1]) * k) for p in poly]


PL = [(-6.9, -2.0), (-6.2, -2.85), (3.0, -3.05), (5.6, -2.4), (7.45, -0.5), (7.45, 0.4), (5.5, 2.35), (3.0, 3.0), (-6.2, 2.85), (-6.9, 2.0)]


# ------------------------------------------------------------------------------------------------ sol
# Essai 2 : tout le sol TIENT DANS L'EMPRISE (16×8 : |x| ≤ 7,95, |y| ≤ 3,95) ; plus de dalle unique (« tout est posé
# sur des dalles en rectangle », refus v5) : un PUITS sombre sous la base flottante (le vide se lit), bordé de terrasses
# brisées de hauteurs inégales, et une butte de terre poussée devant le nez.
TERRASSES = [  # (polygone convexe, hauteur) ; A : porte et treuil ; B : palier bas de l'escalier ; C, D : sud-est
    ([(-7.9, -3.3), (-7.4, -3.95), (-4.75, -3.95), (-4.6, -3.05), (-7.6, -2.9)], 0.32),
    ([(-4.5, -3.95), (-1.15, -3.92), (-0.95, -3.35), (-4.4, -3.25)], 0.12),
    ([(-0.6, -3.9), (3.45, -3.95), (3.55, -3.45), (-0.4, -3.4)], 0.22),
    ([(3.9, -3.9), (7.3, -3.62), (7.9, -2.6), (4.0, -3.25)], 0.4),
    ([(-7.95, -2.75), (-7.2, -2.65), (-7.1, 2.25), (-7.95, 2.3)], 0.25),
    ([(-7.9, 2.4), (-6.6, 2.6), (-4.0, 3.3), (-4.2, 3.95), (-7.5, 3.95)], 0.45),
    ([(-3.6, 3.4), (1.5, 3.2), (1.7, 3.95), (-3.5, 3.95)], 0.3),
    ([(2.2, 3.0), (7.6, 2.2), (7.9, 3.2), (7.0, 3.95), (2.4, 3.95)], 0.36),
]
PUITS = [(-7.0, -2.95), (-4.0, -3.3), (3.6, -3.45), (6.9, -2.4), (7.3, -0.4), (6.6, 2.1), (1.5, 3.15), (-4.0, 3.25),
         (-6.9, 2.35)]


def socle(lot, M, r):
    xf = F_sol
    # essai 4 : plus de fond de puits (le sol et l'ombre se voient sous la base : elle flotte)
    for k in range(9):                                                      # fissures rayonnantes, à peine dorées
        a = G.TAU * (k + r.f(-0.2, 0.2)) / 9
        L = r.f(1.4, 2.6)
        p0 = (0.3 + 0.6 * math.cos(a), -0.2 + 0.4 * math.sin(a), 0.03)
        p1 = (0.3 + L * 2.2 * math.cos(a), -0.2 + L * 1.05 * math.sin(a), 0.03)
        lot.put(M["brule"], G.boite(G.lerp(p0, p1, 0.5), (G.length(G.sub(p1, p0)), 0.06, 0.012), rz=math.atan2(p1[1] - p0[1], p1[0] - p0[0])), xf)
    for poly0, h in TERRASSES:
        poly = sc(poly0, 0.95)
        lot.put(M["pierre2"], G.prisme(poly, 0.0, h - 0.07, top_scale=0.985), xf)
        lot.put(M["pierre"], G.prisme(sc(poly, 0.965), h - 0.07, h, top_scale=0.985), xf)
        # bord d'or sombre incrusté sur le côté du puits (le plus long côté intérieur)
        n = len(poly)
        best = max(range(n), key=lambda i: -abs(poly[i][1] + poly[(i + 1) % n][1]))
        a, b = poly[best], poly[(best + 1) % n]
        lot.put(M["or_sombre"], G.boite(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, h - 0.035), (math.hypot(b[0] - a[0], b[1] - a[1]) * 0.9, 0.05, 0.035),
                                        rz=math.atan2(b[1] - a[1], b[0] - a[0])), xf)
    # butte de terre poussée devant le nez (vers l'est), sillon sombre derrière
    lot.put(M["terre"], R.tertre((7.35, -0.7, 0.0), 0.75, 1.55, 0.55, r, na=44, nr=9), xf)     # polaire : geo.butte montrait un escalier
    lot.put(M["terre"], R.tertre((6.9, 1.2, 0.0), 0.6, 0.8, 0.3, r, na=30, nr=8), xf)
    # déflecteur de souffle derrière les tuyères (noirci), nervures
    for k in range(7):
        y = -2.1 + 0.62 * k + r.f(-0.06, 0.06)
        h = 0.7 + 0.32 * math.sin(k * 0.9) + r.f(0, 0.2)
        lot.put(M["brule"], G.boite((-7.55, y, h / 2), (0.16, 0.56, h), ry=-0.35), xf)
        lot.put(M["acier"], G.boite((-7.42, y + 0.29, h / 2), (0.1, 0.06, h + 0.05)), xf)
    # évents de sol sur les terrasses
    for (x, y, z) in ((-6.0, -3.55, 0.32), (5.6, -3.45, 0.4), (-6.2, 3.3, 0.45), (4.6, 3.45, 0.36), (-1.6, 3.65, 0.3)):
        R.grille(lot, M["acier"], M["noyau"], (x, y, z + 0.005), (0, 0, 1), 0.55, 0.34, 7, up=(0, 1, 0), xf=xf)
    for (x0, x1, y, z) in ((0.0, 3.2, -3.88, 0.225), (4.2, 7.0, -3.7, 0.405)):
        lot.put(M["or_sombre"], G.boite(((x0 + x1) / 2, y, z), (x1 - x0, 0.04, 0.02)), xf)


GX, GY, GZ = -3.75, -3.5, 0.12


def porte(lot, M, r):
    """LA PORTE : arche monumentale au sud, piliers à panneaux de nacre, archivolte d'or, seuil lumineux."""
    xf = F_sol
    gx, gy, z0 = GX, GY, GZ
    for s in (-1, 1):
        x = gx + s * 0.95
        lot.put(M["bronze"], G.prisme([(x - 0.3, gy - 0.32), (x + 0.3, gy - 0.32), (x + 0.3, gy + 0.32), (x - 0.3, gy + 0.32)], z0, z0 + 1.75,
                                      top_scale=0.86), xf)
        lot.put(M["nacre"], G.boite((x, gy - 0.31, z0 + 0.85), (0.32, 0.03, 0.9)), xf)
        lot.put(M["or"], G.prisme([(x - 0.34, gy - 0.36), (x + 0.34, gy - 0.36), (x + 0.34, gy + 0.36), (x - 0.34, gy + 0.36)], z0 + 1.75,
                                  z0 + 1.88, top_scale=0.9), xf)
        lot.put(M["or"], G.prisme(R.octo((x, gy), 0.14), z0 + 1.88, z0 + 2.55, top_scale=0.05), xf)
        R.hublot(lot, M["or_sombre"], M["lum"] if s < 0 else M["verre"], (x, gy - 0.33, z0 + 1.45), (0, -1, 0), "losange" if s < 0 else "demi",
                 0.08, xf=xf)
    lot.put(M["or"], G.tour([(gy - 0.3, 0.98), (gy + 0.3, 0.98), (gy + 0.3, 0.72), (gy - 0.3, 0.72)], 28, "y", (gx, 0.0, z0 + 1.2),
                            a0=-math.pi / 2, a1=math.pi / 2), xf)
    lot.put(M["porte"], G.tour([(gy - 0.31, 0.72), (gy - 0.26, 0.72), (gy - 0.26, 0.66), (gy - 0.31, 0.66)], 28, "y", (gx, 0.0, z0 + 1.2),
                               a0=-math.pi / 2, a1=math.pi / 2), xf)
    lot.put(M["or_sombre"], G.prisme(R.octo((gx, gy), 0.2, 6), z0 + 2.15, z0 + 2.55, top_scale=0.3), xf)
    lot.put(M["noyau"], G.boite((gx, gy + 0.05, z0 + 0.6), (1.3, 0.04, 1.2)), xf)          # fond sombre de la baie
    for s in (-1, 1):                                                       # vantaux ouverts, rabattus
        lot.put(M["or_sombre"], G.boite((gx + s * 0.6, gy + 0.32, z0 + 0.8), (0.06, 0.55, 1.5), rz=s * 0.35), xf)
    for k in range(2):                                                      # marches devant la porte
        lot.put(M["pierre"], G.boite((gx, gy - 0.42 - 0.12 * (1 - k), 0.05 + k * 0.04), (1.6 - 0.25 * k, 0.14, 0.1 + 0.08 * k)), xf)
    R.mat_antenne(lot, M["or_sombre"], M["bronze"], M["balise"], (gx, gy, z0 + 2.55), 0.7, r, xf=xf, lum=False)


def escalier(lot, M, r, haut):
    """Escalier latéral du palier bas (devant la porte) à la base flottante, de profil (dents de scie), garde-corps."""
    xf = F_sol
    bas = (haut[0] - 2.6, haut[1] - 0.02, GZ)
    ang = math.atan2(haut[1] - bas[1], haut[0] - bas[0])
    n = 12
    for i in range(n):
        t0, t1 = i / float(n), (i + 1) / float(n)
        p0, p1 = G.lerp(bas, haut, t0), G.lerp(bas, haut, t1)
        lot.put(M["pierre"], G.boite(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, p1[2] - 0.06), (p1[0] - p0[0] + 0.02, 0.66, 0.12), rz=ang), xf)
    for s in (-1, 1):
        d = (-0.33 * math.sin(ang) * s, 0.33 * math.cos(ang) * s, 0.0)
        a, b = G.add(bas, d), G.add(haut, d)
        lot.put(M["bronze"], G.tube([G.add(a, (0, 0, -0.1)), G.add(b, (0, 0, -0.1))], 0.05, 6), xf)
        R.garde_corps(lot, M["or_sombre"], [a, b], h=0.32, pas=0.3, xf=xf)
    for t in (0.35, 0.7):                                                   # piles sous la rampe
        p = G.lerp(bas, haut, t)
        lot.put(M["bronze"], G.prisme(R.octo((p[0], p[1]), 0.12), GZ, p[2] - 0.1, top_scale=0.8), xf)
    return bas


def parvis(lot, M, r):
    """Pylônes d'amarrage, treuils, transformateurs, tuyaux, caisses, fûts, blocs et éclats (débris), dans l'emprise."""
    xf = F_sol
    pylones = []
    for (x, y, z0, h) in ((-7.3, -3.42, 0.32, 2.1), (7.3, -3.15, 0.4, 2.35), (-7.3, 3.3, 0.45, 2.9), (7.05, 3.0, 0.36, 2.7)):
        lot.put(M["pierre2"], G.prisme([(x - 0.4, y - 0.4), (x + 0.4, y - 0.4), (x + 0.4, y + 0.4), (x - 0.4, y + 0.4)], z0 - 0.02, z0 + 0.3,
                                       top_scale=0.85), xf)
        lot.put(M["bronze"], G.prisme([(x - 0.27, y - 0.27), (x + 0.27, y - 0.27), (x + 0.27, y + 0.27), (x - 0.27, y + 0.27)], z0 + 0.3, h,
                                      top_scale=0.55), xf)
        lot.put(M["nacre"], G.boite((x, y - 0.23, z0 + 0.3 + (h - z0 - 0.3) * 0.45), (0.2, 0.04, (h - z0 - 0.3) * 0.5), rx=0.08), xf)
        lot.put(M["or"], G.prisme([(x - 0.17, y - 0.17), (x + 0.17, y - 0.17), (x + 0.17, y + 0.17), (x - 0.17, y + 0.17)], h, h + 0.4,
                                  top_scale=0.05), xf)
        for k in range(2):
            lot.put(M["or_sombre"], G.boite((x, y, z0 + 0.65 + k * 0.55), (0.53 - 0.08 * k, 0.53 - 0.08 * k, 0.06)), xf)
        R.mat_antenne(lot, M["or_sombre"], M["bronze"], M["balise"], (x + 0.12, y + 0.1, h + 0.1), 0.65, r, xf=xf, lum=(y > 0))
        pylones.append((x, y, h - 0.3))
        R.compte("pylones")
    # treuils (tambour, bâti, câble qui part vers la base)
    treuils = []
    for (x, y, z) in ((-5.6, -3.5, 0.32), (5.0, -3.55, 0.4)):
        for s in (-1, 1):
            lot.put(M["acier"], G.boite((x + s * 0.28, y, z + 0.25), (0.08, 0.46, 0.5)), xf)
        lot.put(M["or_sombre"], G.tour([(-0.25, 0.2), (0.25, 0.2)], 16, "x", (x, y, z + 0.31), cap0=True, cap1=True), xf)
        lot.put(M["cable_n"], G.tour([(-0.2, 0.215), (0.2, 0.215)], 16, "x", (x, y, z + 0.31)), xf)
        lot.put(M["acier"], G.boite((x, y + 0.3, z + 0.12), (0.3, 0.16, 0.25)), xf)
        R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(x + 0.1, y + 0.36, z + 0.18), (x + 0.55, y + 0.5, z + 0.1), (x + 0.95, y + 0.35, z + 0.05)],
                   0.04, xf=xf)
        treuils.append((x, y, z + 0.5))
    # transformateurs à isolateurs, faisceaux vers la base
    for (x, y, z) in ((-6.4, -3.45, 0.32), (6.3, -3.4, 0.4)):
        lot.put(M["acier"], G.boite((x, y, z + 0.25), (0.66, 0.46, 0.5)), xf)
        for k in range(4):
            lot.put(M["bronze2"], G.boite((x - 0.3 + 0.2 * k, y, z + 0.25), (0.04, 0.5, 0.42)), xf)
        for k in range(3):
            xx = x - 0.21 + 0.21 * k
            lot.put(M["nacre"], G.tour([(z + 0.5, 0.05), (z + 0.55, 0.075), (z + 0.6, 0.05), (z + 0.65, 0.07), (z + 0.7, 0.045), (z + 0.75, 0.06),
                                         (z + 0.81, 0.02)], 10, "z", (xx, y, 0.0), cap0=True, cap1=True), xf)
        R.faisceau(lot, M["cable_r"], M["cable_n"], (x - 0.21, y, z + 0.81), (x + (1.0 if x < 0 else -1.0), y + 0.75, 1.55), 0.22, r, n=4, rouges=1,
                   xf=xf)
    # tuyauterie au sol, 3 diamètres, qui monte vers la base
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(-7.0, -3.12, 0.45), (-4.95, -3.12, 0.45), (-4.95, -3.12, 1.35), (-4.95, -2.6, 1.35)], 0.085, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(-7.6, -2.1, 0.38), (-7.6, -1.1, 0.38), (-7.6, -1.1, 0.95)], 0.05, xf=xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(7.6, -2.3, 0.5), (6.95, -2.25, 0.5), (6.95, -2.25, 1.1), (6.45, -2.25, 1.1)], 0.05, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(2.0, -3.72, 0.28), (3.0, -3.72, 0.28), (3.0, -3.55, 0.28), (3.0, -3.55, 0.75)], 0.03, xf=xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(4.25, -3.75, 0.46), (4.25, -3.5, 0.46), (4.25, -3.5, 0.95)], 0.03, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(-3.4, 3.7, 0.36), (-1.2, 3.6, 0.36), (-1.2, 3.6, 0.9)], 0.05, xf=xf)
    # caisses, fûts, blocs tombés, éclats de cristal (les débris)
    for (x, y, z, s, rz) in ((0.85, -3.72, 0.22, (0.4, 0.3, 0.3), 0.2), (1.28, -3.68, 0.22, (0.3, 0.28, 0.26), -0.4),
                             (6.35, 3.55, 0.36, (0.38, 0.3, 0.3), 0.15), (-5.1, 3.65, 0.45, (0.34, 0.3, 0.28), -0.3)):
        R.caisse(lot, M["bois"], M["acier"], (x, y, z), s, rz, xf=xf)
    lot.put(M["bois"], G.boite((0.95, -3.7, 0.22 + 0.3 + 0.11), (0.24, 0.22, 0.22), rz=0.5), xf)
    for (x, y, z, c, rz) in ((3.3, -3.8, 0.22, False, 0), (3.12, -3.62, 0.22, False, 0), (4.6, -3.62, 0.4, True, 0.8),
                             (-7.45, 2.9, 0.45, False, 0), (-7.6, 1.2, 0.25, True, -0.4), (2.9, 3.6, 0.36, False, 0)):
        R.fut(lot, M["cuivre"] if x > 0 else M["acier"], M["or_sombre"], (x, y, z), 0.11, 0.3, couche=c, rz=rz, xf=xf)
    for (x, y, z, s) in ((-1.6, -3.78, 0.12, (0.34, 0.28, 0.2)), (7.7, -1.95, 0.0, (0.4, 0.36, 0.26)), (-7.7, -2.45, 0.25, (0.3, 0.3, 0.2)),
                         (2.55, -3.8, 0.22, (0.28, 0.24, 0.2)), (-2.8, 3.7, 0.3, (0.36, 0.3, 0.22)), (7.6, 1.85, 0.0, (0.3, 0.26, 0.2))):
        R.bloc(lot, M["pierre2"], (x, y, z), s, r, xf=xf)
    for (x, y, z, h, rr) in ((2.2, -3.62, 0.22, 0.5, 0.09), (2.35, -3.8, 0.22, 0.3, 0.06), (-7.6, -0.4, 0.25, 0.45, 0.09),
                             (-7.5, -0.2, 0.25, 0.28, 0.06), (7.55, 0.9, 0.0, 0.42, 0.08), (7.7, 1.1, 0.0, 0.26, 0.06),
                             (-6.9, -3.75, 0.32, 0.36, 0.07), (5.8, -3.75, 0.4, 0.3, 0.06)):
        R.eclat(lot, M["cristal_m"], (x, y, z), h, rr, r, xf=xf)
    return pylones, treuils


# ------------------------------------------------------------------------------------------------ base flottante
def _dedans(q, P):
    """Point dans un polygone convexe (sens quelconque)."""
    sg = 0
    n = len(P)
    for i in range(n):
        a, b = P[i], P[(i + 1) % n]
        c = (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0])
        if c != 0:
            s = 1 if c > 0 else -1
            if sg and s != sg:
                return False
            sg = s
    return True


LOBES = [  # essai 3 : la base en 3 lobes convexes (contour brisé, marches entre lobes), dessus sombre, dessous en île renversée
    ([(-7.0, -1.9), (-6.3, -2.6), (-3.3, -2.75), (-2.6, -2.3), (-2.6, 2.3), (-3.3, 2.7), (-6.3, 2.55), (-7.0, 1.8)], -0.1),
    ([(-2.9, -2.7), (0.0, -3.0), (3.3, -2.85), (3.6, -2.2), (3.6, 2.2), (3.2, 2.45), (-2.9, 2.4)], 0.0),
    ([(3.0, -2.6), (5.0, -2.45), (6.5, -1.6), (7.45, -0.35), (7.3, 0.5), (5.8, 1.9), (3.0, 2.2)], -0.06),
]
PL = LOBES[1][0]


def base(lot, M, r):
    xf = F_pal
    for li, (P, dz) in enumerate(LOBES):
        zt = ZP + dz
        lot.put(M["bronze"], G.prisme(P, zt - 0.24, zt - 0.04), xf)
        lot.put(M["or"], G.prisme(sc(P, 1.006), zt - 0.08, zt - 0.015, top_scale=0.997), xf)
        lot.put(M["pont"], G.prisme(sc(P, 0.99), zt - 0.04, zt + 0.02, top_scale=0.996), xf)
        lot.put(M["bronze2"], G.prisme(sc(P, 0.84), zt - 0.5, zt - 0.24, top_scale=1.19), xf)
        lot.put(M["or_sombre"], G.prisme(sc(P, 0.85), zt - 0.53, zt - 0.48, top_scale=1.0), xf)
        lot.put(M["pierre2"], G.prisme(sc(P, 0.52), zt - 0.95 - 0.1 * li, zt - 0.5, top_scale=1.62), xf)
        lot.put(M["noyau"], G.prisme(sc(P, 0.14), zt - 1.3 - 0.1 * li, zt - 0.95 - 0.1 * li, top_scale=3.7), xf)
        cx = sum(p[0] for p in P) / len(P)
        cy = sum(p[1] for p in P) / len(P)
        # incrustations d'or du pont, en biais, coupées au lobe (cassent le grand aplat)
        for k in range(-4, 5):
            o = (cx + 0.7 * k + 0.2 * li, cy)
            a = 0.62 + 0.05 * li
            d = (math.cos(a), math.sin(a))
            pts = []
            for s in range(-40, 41):
                q = (o[0] + d[0] * 0.08 * s, o[1] + d[1] * 0.08 * s)
                if _dedans(q, sc(P, 0.95)):
                    pts.append(q)
            if len(pts) > 2:
                q0, q1 = pts[0], pts[-1]
                L = math.hypot(q1[0] - q0[0], q1[1] - q0[1])
                lot.put(M["or_sombre"], G.boite(((q0[0] + q1[0]) / 2, (q0[1] + q1[1]) / 2, zt + 0.024), (L, 0.03, 0.01), rz=a), xf)
        # consoles sous le bord (pas irrégulier)
        n = len(P)
        for i in range(n):
            a, b = P[i], P[(i + 1) % n]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            k = max(1, int(L / 0.55))
            for j in range(k):
                t = (j + 0.5 + r.f(-0.2, 0.2)) / k
                p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                q = (p[0] + (cx - p[0]) * 0.07, p[1] + (cy - p[1]) * 0.05)
                w = r.f(0.05, 0.08)
                lot.put(M["bronze"] if r.f() < 0.5 else M["or_sombre"],
                        G.prisme([(q[0] - w, q[1] - w), (q[0] + w, q[1] - w), (q[0] + w, q[1] + w), (q[0] - w, q[1] + w)], zt - 0.56, zt - 0.24,
                                 top_scale=2.0), xf)


    # garde-corps du bord sud et est (trouée à l'escalier)
    R.garde_corps(lot, M["or_sombre"], [(-6.2, -2.55, ZP - 0.1), (-3.4, -2.69, ZP - 0.1)], h=0.3, xf=xf)
    R.garde_corps(lot, M["or_sombre"], [(-2.8, -2.66, ZP), (-0.05, -2.95, ZP)], h=0.3, xf=xf)
    R.garde_corps(lot, M["or_sombre"], [(1.15, -2.92, ZP), (3.2, -2.8, ZP)], h=0.3, xf=xf)
    R.garde_corps(lot, M["or_sombre"], [(5.0, -2.4, ZP - 0.06), (6.45, -1.56, ZP - 0.06), (7.38, -0.35, ZP - 0.06)], h=0.3, xf=xf)
    # cristaux de lévitation qui pendent sous la quille (3 foyers), avec collier et chaînes
    for (x, y, h, rr) in ((-3.6, -1.85, 0.5, 0.22), (0.9, -2.15, 0.58, 0.25), (4.4, -1.6, 0.45, 0.19)):
        zt = ZP - 0.6
        lot.put(M["or"], G.prisme(R.octo((x, y), rr * 1.2, 6), zt - 0.14, zt, top_scale=1.25), xf)
        lot.put(M["cristal"], G.prisme(R.octo((x, y), rr, 6), zt - 0.14 - h * 0.35, zt - 0.14, top_scale=1.0), xf)
        lot.put(M["cristal"], G.prisme(R.octo((x, y), rr * 0.04, 6), zt - 0.14 - h, zt - 0.14 - h * 0.35, top_scale=25.0), xf)
        for k in range(3):
            a = G.TAU * k / 3 + 0.3
            lot.put(M["or_sombre"], G.tube([(x + rr * 1.15 * math.cos(a), y + rr * 1.15 * math.sin(a), zt - 0.12),
                                           (x + rr * 0.5 * math.cos(a), y + rr * 0.5 * math.sin(a), zt - 0.14 - h * 0.55)], 0.012, 4), xf)
        R.compte("cristaux")
    # flexibles et faisceaux qui pendent sous la base (dans le vide visible)
    for (x0, x1, y, fl) in ((-5.6, -4.6, -2.3, 0.45), (-2.4, -1.6, -2.45, 0.6), (2.1, 3.0, -2.55, 0.5), (5.2, 6.0, -1.7, 0.4), (-1.0, -0.3, -2.4, 0.35)):
        z = ZP - 0.4
        R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(x0, y, z), (x0 + 0.2, y - 0.05, z - fl), ((x0 + x1) / 2, y - 0.1, z - fl * 1.15),
                                                          (x1 - 0.15, y - 0.04, z - fl * 0.8), (x1, y, z)], 0.04)
    for (x0, x1, y, fl) in ((-4.4, -2.9, -2.55, 0.35), (-0.4, 0.6, -2.7, 0.3), (3.3, 4.0, -2.35, 0.42), (6.0, 6.9, -1.0, 0.3)):
        z = ZP - 0.32
        R.faisceau(lot, M["cable_r"], M["cable_n"], (x0, y, z), (x1, y, z), fl, r, n=4, rouges=1)
    for (a, b) in (((-5.0, -2.5, ZP - 0.4), (-5.0, -1.9, ZP - 0.85)), ((3.6, -2.35, ZP - 0.35), (3.4, -1.95, ZP - 0.85)),
                   ((6.3, -1.5, ZP - 0.4), (6.1, -0.9, ZP - 0.8))):
        R.tuyau(lot, M["cuivre"], M["or_sombre"], [a, (a[0], a[1], b[2]), b], 0.05)
    # rochers en lévitation (vide sous la base), bagués d'or
    for (x, y, z, s) in ((-5.4, -3.0, 1.15, 0.24), (-1.9, -3.5, 1.15, 0.18), (2.0, -3.6, 1.0, 0.26), (5.75, -3.1, 1.15, 0.2),
                         (1.35, -3.3, 0.95, 0.14)):
        lot.put(M["pierre2"], G.boite((x, y, z), (s, s * 0.85, s * 0.8), rz=r.f(0, 3), rx=r.f(-0.4, 0.4), ry=r.f(-0.4, 0.4)), F_sol)
        lot.put(M["or_sombre"], G.tour([(z - 0.02, s * 0.62), (z + 0.02, s * 0.62)], 12, "z", (x, y, 0.0)), F_sol)
        R.compte("debris_levitation")


def amarres(lot, M, r, pylones, treuils):
    """Amarres tendues (chaîne d'or sombre + câble) des pylônes et des treuils au bord de la base."""
    coins = [(-6.3, -2.45), (5.8, -1.95), (-6.3, 2.4), (5.6, 1.9)]
    for (px, py, pz), (lx, ly) in zip(pylones, coins):
        b = F_pal((lx, ly, ZP - 0.2))
        lot.put(M["cable_n"], G.tube(G.chainette((px, py, pz), b, 0.12, 14), 0.022, 6), F_sol)
        R.compte("amarres")
    for (tx, ty, tz), (lx, ly) in zip(treuils, ((-4.6, -2.6), (4.1, -2.4))):
        b = F_pal((lx, ly, ZP - 0.25))
        lot.put(M["cable_n"], G.tube([(tx, ty, tz), b], 0.018, 6), F_sol)


# ------------------------------------------------------------------------------------------------ palais
HX0, HX1 = -2.3, 3.1
Z1, Z2, Z3 = ZP + 1.3, ZP + 2.3, ZP + 2.95


def palais(lot, M, r):
    xf = F_pal
    # halle : cœur sombre en retrait, piles entre les arches de la loggia (largeurs inégales)
    lot.put(M["nacre2"], G.boite(((HX0 + HX1) / 2, 0.075, (ZP + Z1) / 2), (HX1 - HX0, 3.85, Z1 - ZP)), xf)
    arches = [(-1.7, 0.62), (-0.8, 0.8), (0.75, 0.95), (1.85, 0.6), (2.6, 0.42)]
    bords = [HX0] + sum([[x - w / 2, x + w / 2] for x, w in arches], []) + [HX1]
    for i in range(0, len(bords), 2):
        x0, x1 = bords[i], bords[i + 1]
        lot.put(M["nacre"], G.boite(((x0 + x1) / 2, -2.0, (ZP + Z1) / 2), (x1 - x0, 0.3, Z1 - ZP)), xf)
        if x1 - x0 > 0.2:
            R.plaques(lot, [M["nacre2"], M["or_sombre"], M["nacre"]], r, x0 + 0.03, x1 - 0.03, ZP + 0.15, Z1 - 0.35, -2.15, -1, n=3, xf=xf,
                      Mjoint=M["riv"])
    for x, w in arches:
        lot.put(M["noyau"], G.boite((x, -1.86, (ZP + Z1) / 2 - 0.1), (w, 0.05, Z1 - ZP - 0.2)), xf)
        lot.put(M["or"], G.tour([(-2.17, w / 2 + 0.07), (-2.12, w / 2 + 0.07), (-2.12, w / 2), (-2.17, w / 2)], 16, "y",
                                (x, 0.0, Z1 - 0.32 - w / 2), a0=-math.pi / 2, a1=math.pi / 2), xf)
        for s in (-1, 1):
            lot.put(M["nacre"], G.tour([(ZP, 0.07), (ZP + 0.08, 0.06), (Z1 - 0.32 - w / 2, 0.05)], 10, "z", (x + s * (w / 2 + 0.03), -2.12, 0.0),
                                       cap1=True), xf)
    for x, w in arches[1:3]:                                     # lanternes au fond de deux arches
        lot.put(M["lum"], G.boite((x + 0.1, -1.83, Z1 - 0.6), (0.06, 0.03, 0.1)), xf)
    lot.put(M["or_sombre"], G.boite(((HX0 + HX1) / 2, -2.18, Z1 - 0.1), (HX1 - HX0 + 0.1, 0.12, 0.08)), xf)
    lot.put(M["bronze2"], G.boite(((HX0 + HX1) / 2, -2.2, Z1 - 0.22), (HX1 - HX0, 0.08, 0.1)), xf)
    # attique : évents à lames
    for x in (-1.25, 0.05, 2.2):
        R.grille(lot, M["or_sombre"], M["noyau"], (x, -2.16, Z1 - 0.16), (0, -1, 0), 0.34, 0.12, 4, xf=xf)
    # terrasse et étage en retrait
    R.garde_corps(lot, M["or_sombre"], [(HX0 + 0.35, -2.1, Z1), (HX1 - 0.4, -2.1, Z1)], h=0.26, pas=0.24, xf=xf)
    lot.put(M["nacre"], G.boite(((HX0 + HX1) / 2 + 0.05, 0.1, (Z1 + Z2) / 2), (HX1 - HX0 - 0.55, 3.2, Z2 - Z1)), xf)
    R.plaques(lot, [M["nacre2"], M["or_sombre"], M["bronze2"]], r, HX0 + 0.35, HX1 - 0.4, Z1 + 0.05, Z2 - 0.05, -1.5, -1, n=20, xf=xf, Mjoint=M["riv"])
    for x in (-1.85, -0.95, 0.35, 0.95, 2.05):                   # pilastres à pas irrégulier
        lot.put(M["or_sombre"], G.boite((x, -1.55, (Z1 + Z2) / 2), (0.08, 0.06, Z2 - Z1)), xf)
    fen = [(-1.5, "ogive", 0.13, True), (-1.2, "rond", 0.08, False), (-0.55, "double", 0.1, True), (0.0, "fente", 0.07, False),
           (0.65, "octo", 0.12, True), (1.3, "carre", 0.09, False), (1.65, "losange", 0.08, True), (2.5, "demi", 0.12, False)]
    for x, f, t, lit in fen:
        R.hublot(lot, M["or_sombre"], M["lum"] if lit else M["verre"], (x, -1.55, (Z1 + Z2) / 2 + r.f(-0.1, 0.15)), (0, -1, 0), f, t, xf=xf)
    lot.put(M["or"], G.boite(((HX0 + HX1) / 2 + 0.05, -1.58, Z2 - 0.04), (HX1 - HX0 - 0.45, 0.08, 0.07)), xf)
    # comble mansardé, faîtage d'or, lucarnes inégales, évents, cheminées
    roof = [(HX0 + 0.25, -1.6), (HX1 - 0.3, -1.6), (HX1 - 0.3, 1.75), (HX0 + 0.25, 1.75)]
    lot.put(M["toit"], G.prisme(roof, Z2, Z3, top_scale=0.7), xf)
    top = sc(roof, 0.7)
    lot.put(M["or"], G.prisme(sc(top, 1.02), Z3, Z3 + 0.05, top_scale=0.98), xf)
    lot.put(M["acier"], G.prisme(sc(top, 0.96), Z3 + 0.05, Z3 + 0.09, top_scale=0.97), xf)
    # essai 2 : plus de terrasse d'ardoise nue ; brisis en croupe (faîte), lanterne vitrée à côtes d'or sur le faîte
    lot.put(M["toit"], G.prisme(sc(top, 0.95), Z3 + 0.09, Z3 + 0.62, top_scale=0.22), xf)
    fx0, fx1 = HX0 + 0.25 + 0.55, HX1 - 0.3 - 0.55
    yc = (top[0][1] + top[2][1]) / 2
    for (a0, a1) in ((fx0, -0.3), (1.0, fx1)):
        lot.put(M["verre"], G.prisme([(a0, yc - 0.3), (a1, yc - 0.3), (a1, yc + 0.3), (a0, yc + 0.3)], Z3 + 0.45, Z3 + 0.72, top_scale=0.25), xf)
        k = max(2, int((a1 - a0) / 0.28))
        for j in range(k + 1):
            x = a0 + (a1 - a0) * j / k
            lot.put(M["or"], G.tube([(x, yc - 0.32, Z3 + 0.46), (x, yc, Z3 + 0.73), (x, yc + 0.32, Z3 + 0.46)], 0.018, 4), xf)
        lot.put(M["or"], G.tube([(a0, yc, Z3 + 0.74), (a1, yc, Z3 + 0.74)], 0.03, 6), xf)
    lot.put(M["lum"], G.boite((fx0 + 0.45, yc, Z3 + 0.52), (0.3, 0.1, 0.06)), xf)   # lanterne éclairée du dedans (un foyer)
    for (x, w, h) in ((-1.6, 0.3, 0.32), (1.75, 0.38, 0.4), (2.45, 0.26, 0.28)):
        y = -1.3
        z = Z2 + 0.2
        lot.put(M["bronze"], G.boite((x, y, z + h / 2), (w, 0.32, h)), xf)
        lot.put(M["ardoise"], G.prisme([(x - w / 2 - 0.05, y - 0.2), (x + w / 2 + 0.05, y - 0.2), (x + w / 2 + 0.05, y + 0.18), (x - w / 2 - 0.05, y + 0.18)],
                                       z + h, z + h + 0.18, top_scale=0.3), xf)
        R.hublot(lot, M["or_sombre"], M["lum"] if x > 0 and w > 0.3 else M["verre"], (x, y - 0.165, z + h * 0.45), (0, -1, 0),
                 "carre" if w > 0.3 else "rond", w * 0.28, xf=xf)
    for (x, y) in ((-0.9, -0.95), (1.15, -1.0), (-1.4, 1.2), (2.2, 0.9)):
        R.grille(lot, M["acier"], M["noyau"], (x, y, Z2 + 0.42), (0, -0.55, 0.83), 0.3, 0.22, 5, xf=xf)
    for (x, y, h) in ((-0.3, 1.25, 0.75), (2.6, -0.85, 0.55)):
        lot.put(M["pierre2"], G.boite((x, y, Z3 + h / 2 - 0.2), (0.22, 0.22, h + 0.2)), xf)
        lot.put(M["or_sombre"], G.boite((x, y, Z3 + h), (0.28, 0.28, 0.05)), xf)
        R.tuyau(lot, M["cuivre"], M["or_sombre"], [(x + 0.11, y, Z3 + h * 0.6), (x + 0.5, y, Z3 + h * 0.6), (x + 0.5, y - 0.6, Z2 + 0.4)], 0.03, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(-1.0, 0.4, Z3), (-1.0, 0.4, Z3 + 0.25), (-0.4, 0.4, Z3 + 0.25)], 0.03, xf=xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(1.6, 0.9, Z3), (1.6, 0.9, Z3 + 0.3), (1.6, -0.2, Z3 + 0.3)], 0.03, xf=xf)
    # tours d'angle (hauteurs et toits inégaux)
    tours = [((HX0, -2.05), 0.42, Z1 + 1.15, 0.7, 2), ((HX1, -2.05), 0.36, Z1 + 0.75, 0.55, 2), ((HX1 - 0.1, 1.95), 0.34, Z1 + 1.4, 0.65, 1),
             ((HX0 + 0.05, 1.9), 0.44, Z1 + 1.6, 0.8, 1)]
    for i, (c, rr, zt, toit, nf) in enumerate(tours):
        R.tourelle(lot, M["nacre"], M["toit"], M["or"], M["lum"] if i in (0, 2) else None, M["or_sombre"], c, rr, ZP, zt, toit, r, nf, xf=xf)
    # échafaudage contre la tour sud-est (chantier jamais fini)
    R.echafaudage(lot, M["acier"], M["bois"], HX1 - 0.95, HX1 - 0.35, -2.45, -2.25, ZP, Z1 + 0.6, 3, xf=xf)
    # côté ouest de la halle : tuyaux vers le cœur, faisceaux, évent, hublots
    for (y, z, rr) in ((-1.4, ZP + 0.45, 0.085), (-0.9, ZP + 0.9, 0.05), (1.0, ZP + 0.6, 0.03)):
        R.tuyau(lot, M["cuivre"] if rr > 0.04 else M["acier"], M["or_sombre"],
                [(HX0 - 0.05, y, z), (HX0 - 0.45, y, z), (HX0 - 0.45, y * 0.4, z + 0.35), (HX0 - 1.0, y * 0.3, z + 0.35)], rr, xf=xf)
    R.grille(lot, M["or_sombre"], M["noyau"], (HX0 - 0.01, 0.3, ZP + 0.85), (-1, 0, 0), 0.5, 0.3, 6, xf=xf)
    R.hublot(lot, M["or_sombre"], M["lum"], (HX0 - 0.01, -0.5, Z1 + 0.5), (-1, 0, 0), "rond", 0.1, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (HX0, -1.75, Z1 - 0.2), (HX0 - 1.2, -0.6, ZS + 0.3), 0.3, r, n=5, rouges=2, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (HX0 + 0.6, -2.2, Z1 - 0.15), (HX0 + 2.0, -2.2, Z1 - 0.15), 0.22, r, n=3, rouges=1, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (HX1 - 0.3, -2.2, Z1 + 0.3), (HX1 + 0.6, -1.55, ZS + 0.1), 0.25, r, n=4, rouges=1, xf=xf)
    # côté est : tuyaux qui entrent dans le crâne
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(HX1 - 0.4, -1.65, Z1 + 0.5), (HX1 + 0.35, -1.65, Z1 + 0.5), (HX1 + 0.35, -1.65, Z1 - 0.3)], 0.05, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(HX1 - 0.5, -2.2, ZP + 0.3), (HX1 + 0.6, -2.2, ZP + 0.3), (HX1 + 1.1, -1.6, ZP + 0.3)], 0.03, xf=xf)
    # parvis de la base : lampadaires bas, caisses, rouleau de flexible, évent
    for (x, y) in ((-3.35, -2.05), (4.75, -1.55)):
        R.caisse(lot, M["bois"], M["acier"], (x, y, ZP), (0.34, 0.3, 0.26), r.f(-0.4, 0.4), xf=xf)
    R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(-5.2, -2.3, ZP + 0.05), (-5.0, -2.55, ZP + 0.08), (-4.7, -2.4, ZP + 0.05),
                                                      (-4.9, -2.2, ZP + 0.1), (-4.4, -2.2, ZP + 0.3), (HX0 - 1.0, -0.8, ZS - 0.4)], 0.045, xf=xf)
    R.grille(lot, M["acier"], M["noyau"], (2.2, -2.55, ZP + 0.005), (0, 0, 1), 0.5, 0.3, 6, up=(0, 1, 0), xf=xf)


def donjon_couronne(lot, M, r):
    """Donjon à galerie et COURONNE DE 5 FLÈCHES (3 tailles), arcs-boutants, anneau-halo (mât de commandement)."""
    xf = F_pal
    kc, kr = (0.3, 0.3), 0.78
    zk0, zk1 = Z2, ZP + 3.75
    lot.put(M["bronze"], G.prisme(R.octo(kc, kr), zk0, zk1, top_scale=0.93), xf)
    for i, a in enumerate((-math.pi / 2 - 0.39, -math.pi / 2 + 0.39, -math.pi / 2 + 1.18)):
        p = (kc[0] + kr * 0.93 * math.cos(a), kc[1] + kr * 0.93 * math.sin(a), Z3 + 0.25)
        n = (math.cos(a), math.sin(a), 0.0)
        lot.put(M["nacre"], R.pose(G.boite((0, 0, 0), (0.36, 0.55, 0.03)), p, n), xf)
        R.hublot(lot, M["or_sombre"], M["lum"] if i != 1 else M["verre"], G.add(p, G.mul(n, 0.02)), n, ("ogive", "rond", "fente")[i],
                 (0.09, 0.07, 0.06)[i], xf=xf)
    lot.put(M["or"], G.prisme(R.octo(kc, kr * 1.3), zk1, zk1 + 0.08, top_scale=0.98), xf)
    for i in range(16):
        a = G.TAU * (i + 0.5) / 16
        p = (kc[0] + kr * 1.12 * math.cos(a), kc[1] + kr * 1.12 * math.sin(a))
        lot.put(M["bronze2"], G.prisme([(p[0] - 0.05, p[1] - 0.05), (p[0] + 0.05, p[1] - 0.05), (p[0] + 0.05, p[1] + 0.05), (p[0] - 0.05, p[1] + 0.05)],
                                       zk1 - 0.3, zk1, top_scale=2.0), xf)
    R.garde_corps(lot, M["or_sombre"], [(p[0], p[1], zk1 + 0.08) for p in R.octo(kc, kr * 1.24) + [R.octo(kc, kr * 1.24)[0]]], h=0.22,
                  pas=0.2, xf=xf)
    # couronne : 5 flèches d'or blanc en arc (maîtresse au centre), tailles 3 / 2 / 1
    spec = [((kc[0], kc[1] + 0.1), zk1 + 0.08, 4.5, 0.44),
            ((-0.75, 0.3), ZP + 3.15, 3.4, 0.32), ((1.4, 0.3), ZP + 3.1, 3.15, 0.31),
            ((-1.75, 0.0), ZP + 2.6, 2.55, 0.25), ((2.35, 0.05), ZP + 2.55, 2.35, 0.24)]
    pointes = []
    for i, (c, z0, h, rr) in enumerate(spec):
        if i:
            lot.put(M["bronze"], G.prisme(R.octo(c, rr * 1.15), Z2 - 0.3, z0, top_scale=0.95), xf)
            lot.put(M["or_sombre"], G.prisme(R.octo(c, rr * 1.3), z0 - 0.06, z0, top_scale=0.95), xf)
        pointes.append(R.fleche(lot, M["nacre2"], M["or"], M["nacre"], M["verre"], M["cristal_m"] if i else M["cristal"], c, z0, h, rr, r,
                                3 if i < 3 else 2, xf=xf, Mlum=M["lum"] if i in (0, 2) else None))
    # arcs-boutants du donjon vers les flèches latérales
    for i in (1, 2):
        c, z0 = spec[i][0], spec[i][1]
        a = (kc[0] + (c[0] - kc[0]) * 0.45, kc[1], zk1 - 0.1)
        b = (c[0], c[1], z0 + 0.4)
        m = G.add(G.lerp(a, b, 0.5), (0, 0, 0.35))
        lot.put(M["or_sombre"], G.tube(G.catmull([a, m, b], 8), 0.05, 6), xf)
    # anneau-halo autour de la flèche maîtresse (incliné), anneau d'or plus bas, faisceaux entre les flèches
    zc = zk1 + 0.08 + 4.5 * 0.5
    hax = (0.0, -0.32, 1.0)
    lot.put(M["or"], N.tore((kc[0], kc[1] + 0.1, zc), 0.95, 0.035, hax, 48, 6), xf)
    ez = G.norm(hax)
    e1 = G.norm(G.cross((1.0, 0.0, 0.0), ez))
    e2 = G.cross(ez, e1)
    for k in range(12):
        a = G.TAU * k / 12
        p = G.add((kc[0], kc[1] + 0.1, zc), G.add(G.mul(e1, 0.95 * math.cos(a)), G.mul(e2, 0.95 * math.sin(a))))
        lot.put(M["halo"] if k % 3 == 0 else M["or"], G.sphere(p, 0.05 if k % 3 == 0 else 0.04, 8, 4), xf)
    R.compte("halo_perles", 12)
    lot.put(M["or"], N.tore((kc[0], kc[1] + 0.1, zc - 0.85), 0.62, 0.035, (0.08, -0.15, 1.0), 40, 6), xf)
    for k in range(4):
        a = G.TAU * k / 4 + 0.4
        lot.put(M["or_sombre"], G.tube([(kc[0] + 0.6 * math.cos(a), kc[1] + 0.1 + 0.6 * math.sin(a), zc - 0.85),
                                        (kc[0] + 0.92 * math.cos(a), kc[1] + 0.1 + 0.92 * math.sin(a) * 0.95, zc - 0.3 * math.sin(a))], 0.012, 4), xf)
    for (i, j) in ((1, 0), (0, 2), (3, 1)):
        a = G.add(pointes[i], (0, 0, -0.9 if i else -1.7))
        b = G.add(pointes[j], (0, 0, -0.9 if j else -1.7))
        R.faisceau(lot, M["cable_r"], M["cable_n"], a, b, 0.2, r, n=3, rouges=1, xf=xf)
    R.mat_antenne(lot, M["or_sombre"], M["bronze"], M["balise"], (-1.6, 1.3, Z3), 0.8, r, xf=xf)
    R.mat_antenne(lot, M["or_sombre"], M["bronze"], None, (2.0, 1.2, Z3), 0.6, r, xf=xf, lum=False)
    return pointes


def squelette(lot, M, r):
    """Côtes de nacre (os) inclinées vers la queue, épine dorsale à vertèbres, du crâne à la dérive."""
    xf = F_pal
    zt = ZS + 2.05
    ye = -0.6                                                    # l'épine passe devant le donjon et la couronne
    prof = [(-2.34, ZP + 0.05), (-2.38, ZP + 0.9), (-2.3, Z1 + 0.35), (-1.95, Z2 + 0.1), (-1.35, Z3 + 0.12), (-0.65, zt - 0.05), (0.0, zt)]
    b = 0.95
    for xt in (-3.1, -1.2, 2.0):                                 # entre les tours et les socles des flèches
        pts = []
        for y, z in prof + [(-y, z) for y, z in reversed(prof[:-1])]:
            s = (z - ZP) / (zt - ZP)
            pts.append((xt - b * (1.0 - s), y + ye * s, z))
        pts = G.catmull(pts, 4)
        lot.put(M["nacre"], G.tube(pts, 0.075, 8), xf)
        for y in (-2.36, 2.36):
            lot.put(M["or_sombre"], G.boite((xt - b, y, ZP + 0.12), (0.26, 0.22, 0.24)), xf)
        lot.put(M["or"], G.tour([(-0.06, 0.1), (0.06, 0.1)], 10, "y", (xt, ye, zt)), xf)
    ep = G.catmull([(-3.6, -0.15, ZS + 1.0), (-2.6, ye, zt), (2.9, ye, zt), (3.6, -0.25, ZS + 1.35)], 10)
    lot.put(M["nacre"], G.tube(ep, 0.11, 10), xf)
    acc = 0.0
    for i in range(1, len(ep)):
        acc += G.length(G.sub(ep[i], ep[i - 1]))
        if acc > 0.38 + r.f(0, 0.1):
            acc = 0.0
            p = ep[i]
            lot.put(M["bronze"], G.boite(p, (0.14, 0.26, 0.22)), xf)
            lot.put(M["or_sombre"], G.prisme([(p[0] - 0.12, p[1] - 0.03), (p[0] + 0.1, p[1] - 0.03), (p[0] + 0.02, p[1] + 0.03),
                                              (p[0] - 0.08, p[1] + 0.03)], p[2] + 0.1, p[2] + 0.32 + r.f(0, 0.12), top_scale=0.2,
                                             top_shift=(-0.1, 0.0)), xf)
    # deux côtes autour de la racine du crâne (repère du vaisseau)
    surf = N.crane_pt(ZS)
    for xt in (3.55, 4.25):
        pts = [surf(xt - 0.3 * (1.0 - math.sin(a)), a, 0.13) for a in [-0.35 + (math.pi + 0.7) * j / 14.0 for j in range(15)]]
        lot.put(M["nacre"], G.tube(pts, 0.06, 8), F_nav)


def pont(lot, M, r):
    """Le pont de la base hors du palais : vérins sous le crâne, grue de chargement, citernes (est) ; pompes, vannes,
    cuve près du cœur (ouest). Casse les pans de pont nus vus à l'aperçu."""
    xf = F_pal
    surf = N.crane_pt(ZS)
    for x in (3.7, 4.6, 5.5):                                     # vérins (repère palais, tête sous le crâne roulé)
        for s in (-1, 1):
            a = math.pi + 0.75 if s < 0 else -0.75
            q = F_nav(surf(x, a, 0.0))
            loc = G.rot_z((q[0], q[1] - OY, 0.0), -PSI)
            pied = (loc[0] - 0.15, loc[1] + s * 0.35, ZP)
            tete = (loc[0], loc[1], q[2] - 0.05)
            lot.put(M["bronze"], G.tube([pied, G.lerp(pied, tete, 0.55)], 0.07, 10), xf)
            lot.put(M["or"], G.tube([G.lerp(pied, tete, 0.5), tete], 0.045, 10), xf)
            lot.put(M["acier"], G.tour([(ZP, 0.16), (ZP + 0.07, 0.15), (ZP + 0.1, 0.07)], 12, "z", (pied[0], pied[1], 0.0), cap1=True), xf)
    # grue de chargement : fût, flèche, câble, crochet et caisse suspendue
    gx, gy = 5.5, -1.75
    lot.put(M["acier"], G.prisme(R.octo((gx, gy), 0.16), ZP, ZP + 1.6, top_scale=0.7), xf)
    lot.put(M["or_sombre"], G.tour([(ZP + 1.55, 0.2), (ZP + 1.7, 0.2)], 12, "z", (gx, gy, 0.0), cap0=True, cap1=True), xf)
    bout = (gx + 1.25, gy - 0.6, ZP + 1.95)
    lot.put(M["jaune"], G.tube([(gx - 0.35, gy + 0.15, ZP + 1.7), bout], 0.05, 6), xf)
    lot.put(M["acier"], G.tube([(gx, gy, ZP + 2.2), bout], 0.012, 4), xf)
    lot.put(M["acier"], G.tube([(gx, gy, ZP + 1.7), (gx, gy, ZP + 2.2)], 0.03, 6), xf)
    lot.put(M["cable_n"], G.tube([bout, (bout[0], bout[1], ZP + 0.95)], 0.01, 4), xf)
    R.caisse(lot, M["bois"], M["acier"], (bout[0], bout[1], ZP + 0.55), (0.3, 0.26, 0.38), 0.3, xf=xf)
    R.mat_antenne(lot, M["or_sombre"], M["bronze"], None, (gx, gy, ZP + 1.7), 0.5, r, xf=xf, lum=False)
    # citernes couchées à cerclages, près du bord est
    for (x, y, rr, L) in ((6.15, -1.15, 0.24, 1.0), (4.3, -2.15, 0.2, 0.85)):
        lot.put(M["cuivre"], G.tour([(x - L / 2, rr * 0.7), (x - L / 2 + 0.06, rr), (x + L / 2 - 0.06, rr), (x + L / 2, rr * 0.7)], 16, "x",
                                    (0.0, y, ZP + rr + 0.06), cap0=True, cap1=True), xf)
        for k in range(3):
            xx = x - L / 2 + 0.15 + (L - 0.3) * k / 2
            lot.put(M["or_sombre"], G.tour([(xx - 0.03, rr + 0.012), (xx + 0.03, rr + 0.012)], 16, "x", (0.0, y, ZP + rr + 0.06)), xf)
        for s in (-1, 1):
            lot.put(M["acier"], G.boite((x + s * L * 0.3, y, ZP + 0.05), (0.08, rr * 1.6, 0.1)), xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(6.65, -1.15, ZP + 0.3), (6.95, -1.15, ZP + 0.3), (6.95, -0.2, ZP + 0.3), (6.5, 0.1, ZP + 0.3)], 0.03,
            xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(3.85, -2.15, ZP + 0.26), (3.3, -2.15, ZP + 0.26), (3.3, -2.0, ZP + 0.7)], 0.05, xf=xf)
    # ouest, près du cœur : pompes, roues de vannes, cuve
    for (x, y) in ((-3.9, -2.4), (-2.85, -2.5)):
        lot.put(M["acier"], G.boite((x, y, ZP + 0.16), (0.42, 0.3, 0.3)), xf)
        lot.put(M["bronze2"], G.tour([(-0.18, 0.12), (0.18, 0.12)], 12, "y", (x, 0.0, ZP + 0.36), cap0=True, cap1=True), xf)
        lot.put(M["or"], N.tore((x + 0.12, y - 0.17, ZP + 0.45), 0.07, 0.012, (0.0, 1.0, 0.0), 14, 5), xf)
    lot.put(M["bronze"], G.tour([(ZP, 0.3), (ZP + 0.65, 0.3), (ZP + 0.8, 0.18), (ZP + 0.85, 0.0)], 16, "z", (-4.9, -2.3, 0.0), cap0=True), xf)
    lot.put(M["or_sombre"], G.tour([(ZP + 0.3, 0.315), (ZP + 0.35, 0.315)], 16, "z", (-4.9, -2.3, 0.0)), xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(-4.6, -2.3, ZP + 0.5), (-3.9, -2.3, ZP + 0.5), (-3.9, -2.4, ZP + 0.32)], 0.04, xf=xf)


def menus(lot, M, r):
    """Menus détails (3 à 10 px), clairs et sombres : ponts, terrasses, tranche de la base, dos du crâne."""
    mats = [M["acier"], M["noyau"], M["or_sombre"], M["cuivre"], M["nacre2"]]
    for (xf, z, xr, yr, n) in ((F_pal, ZP, (2.95, 6.9), (-2.7, -0.95), 130), (F_pal, ZP, (-6.4, -2.4), (-2.75, -1.75), 70),
                               (F_pal, ZP, (3.2, 6.3), (0.9, 2.2), 40), (F_sol, 0.32, (-7.5, -4.9), (-3.75, -3.1), 26),
                               (F_sol, 0.12, (-4.3, -1.3), (-3.8, -3.4), 24), (F_sol, 0.22, (-0.4, 3.3), (-3.8, -3.5), 24),
                               (F_sol, 0.4, (4.2, 7.2), (-3.7, -3.1), 26)):
        for k in range(n):
            lot.put(mats[k % 5], G.boite((r.f(*xr), r.f(*yr), z + 0.015), (r.f(0.05, 0.15), r.f(0.04, 0.11), 0.05), r.f(-0.5, 0.5)), xf)
    for k in range(120):        # tranche de la base, côté caméra
        x = r.f(-6.0, 5.6)
        y = -2.72 if x < -3.0 else -2.9
        p = (x, y, r.f(ZP - 0.45, ZP - 0.04))
        lot.put(mats[k % 5], G.boite(p, (r.f(0.05, 0.13), 0.04, r.f(0.04, 0.1))), F_pal)
    surf = N.crane_pt(ZS)
    for k in range(80):         # dos du crâne
        x, a = r.f(2.6, 6.6), r.f(0.5, 2.6)
        p = surf(x, a, 0.04)
        lot.put(mats[k % 5], G.boite(p, (r.f(0.05, 0.12), r.f(0.04, 0.09), 0.05), r.f(-0.5, 0.5)), F_nav)


def chargement(lot, M, r):
    """Ce qui vit sur les ponts et les terrasses : caisses, fûts, bollards, trappes, écoutilles, rampes de lumière
    éteintes. Remplit les pans nus vus à m1 (mesures « pièces » et « damier ») sans les quadriller."""
    zones = [(F_pal, ZP, (2.95, 6.9), (-2.7, -0.95), 34), (F_pal, ZP, (-6.4, -2.4), (-2.75, -1.75), 22), (F_pal, ZP, (3.2, 6.3), (0.9, 2.2), 14)]
    for (x0, x1, y0, y1, h) in ((-7.5, -4.9, -3.75, -3.1, 0.32), (-4.3, -1.3, -3.8, -3.4, 0.12), (-0.4, 3.3, -3.8, -3.5, 0.22),
                                (4.2, 7.2, -3.7, -3.1, 0.4), (-7.9, -7.2, -2.5, 2.1, 0.25)):
        zones.append((F_sol, h, (x0, x1), (y0, y1), 9))
    for (xf, z, xr, yr, n) in zones:
        for k in range(n):
            x, y = r.f(*xr), r.f(*yr)
            u = r.f()
            rz = r.f(-0.5, 0.5)
            if u < 0.28:
                R.caisse(lot, M["bois"] if k % 3 else M["acier"], M["acier"], (x, y, z + 0.13), (r.f(0.18, 0.34), r.f(0.16, 0.3), 0.26), rz, xf=xf)
            elif u < 0.48:
                R.fut(lot, M["cuivre"] if k % 2 else M["bronze"], M["or_sombre"], (x, y, z), r.f(0.07, 0.1), r.f(0.2, 0.3), couche=(k % 5 == 0), rz=rz, xf=xf)
            elif u < 0.68:      # bollard à collier
                lot.put(M["acier"], G.tour([(z, 0.06), (z + 0.14, 0.05), (z + 0.17, 0.075), (z + 0.2, 0.0)], 8, "z", (x, y, 0.0), cap0=True), xf)
            elif u < 0.86:      # trappe : cadre et volet
                lot.put(M["or_sombre"], G.boite((x, y, z + 0.015), (0.36, 0.26, 0.03), rz), xf)
                lot.put(M["noyau"], G.boite((x, y, z + 0.032), (0.28, 0.18, 0.006), rz), xf)
            else:               # tronçon de conduit au ras du pont, à brides
                R.tuyau(lot, M["cuivre"] if k % 2 else M["acier"], M["or_sombre"], [(x, y, z + 0.09), (x + r.f(0.3, 0.7), y + r.f(-0.1, 0.1), z + 0.09)], 0.04, xf=xf)


def complements(lot, M, r):
    """Essai 3 : minimums du brief × 4 (emprise 128 t² / 32) : échafaudages (4), flexibles (≥ 16), faisceaux (≥ 16),
    évents (≥ 16). Chantiers jamais finis : couronne, tour ouest, dérive."""
    xf = F_pal
    kc, zk1 = (0.3, 0.3), ZP + 3.75
    R.echafaudage(lot, M["acier"], M["bois"], kc[0] - 0.45, kc[0] + 0.35, kc[1] - 1.12, kc[1] - 0.92, zk1 + 0.08, zk1 + 1.25, 3, xf=xf)
    R.echafaudage(lot, M["acier"], M["bois"], HX0 - 0.95, HX0 - 0.4, -2.45, -2.2, ZP, Z1 + 0.75, 4, xf=xf)
    R.echafaudage(lot, M["acier"], M["bois"], -5.35, -4.45, -0.42, -0.2, ZS + 0.7, ZS + 1.95, 3, xf=F_nav)
    # flexibles d'énergie : des pylônes sud à la quille (pendent dans le vide), de l'attique au pont
    for (p, q) in (((-7.05, -3.15, 0.95), (-6.0, -2.3, ZP - 0.55)), ((7.05, -2.9, 1.0), (5.6, -2.0, ZP - 0.5))):
        b = F_pal(q)
        m = G.add(G.lerp(p, b, 0.5), (0.0, -0.15, -0.55))
        R.flexible(lot, M["caoutchouc"], M["or_sombre"], [p, G.lerp(p, m, 0.6), m, G.lerp(m, b, 0.5), b], 0.05, xf=F_sol)
    for (x0, x1) in ((HX0 + 0.75, HX0 + 1.55), (HX1 - 1.25, HX1 - 0.55)):
        R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(x0, -2.18, Z1 - 0.35), (x0 + 0.1, -2.35, ZP + 0.45), ((x0 + x1) / 2, -2.5, ZP + 0.06),
                                                          (x1, -2.45, ZP + 0.05)], 0.04, xf=xf)
    R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(4.3, -1.6, ZS - 0.7), (4.2, -2.0, ZP + 0.6), (4.0, -2.3, ZP + 0.5)], 0.045, xf=xf)
    # faisceaux : tours sud entre elles (au-dessus de la loggia), porte → rampe, pylône → bord de la base
    R.faisceau(lot, M["cable_r"], M["cable_n"], (HX0, -2.3, Z1 + 0.9), (HX1, -2.3, Z1 + 0.6), 0.35, r, n=4, rouges=1, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (GX + 0.95, GY, GZ + 1.6), (GX + 2.4, GY + 0.1, 1.2), 0.25, r, n=3, rouges=1, xf=F_sol)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (7.3, -3.15, 2.0), F_pal((5.9, -2.2, ZP - 0.15)), 0.3, r, n=3, rouges=2, xf=F_sol)
    # évents : sur la quille (face sud) et la façade est de la halle
    for (x, y, z) in ((-4.6, -2.7, ZP - 0.25), (-1.2, -2.886, ZP - 0.15), (2.4, -2.9, ZP - 0.15)):
        R.grille(lot, M["or_sombre"], M["noyau"], (x, y, z), (0, -1, 0), 0.5, 0.15, 4, xf=xf)
    R.grille(lot, M["or_sombre"], M["noyau"], (HX1 + 0.01, -0.6, ZP + 0.7), (1, 0, 0), 0.6, 0.32, 6, xf=xf)


def build(S, lot):
    R.raz()
    _GRIS[0] = GRIS or lot.prefix.endswith("g")
    M = matieres(S)
    r = G.Rnd(1515)
    lot.xf = F_pal
    socle(lot, M, r)
    porte(lot, M, r)
    haut = F_pal((0.55, -2.93, ZP - 0.02))
    escalier(lot, M, r, haut)
    pylones, treuils = parvis(lot, M, r)
    base(lot, M, r)
    amarres(lot, M, r, pylones, treuils)
    palais(lot, M, r)
    donjon_couronne(lot, M, r)
    squelette(lot, M, r)
    pont(lot, M, r)
    complements(lot, M, r)
    chargement(lot, M, G.Rnd(1516))
    menus(lot, M, G.Rnd(1517))
    # le vaisseau (roulis + lacet) : crâne, nacelles, ailes, dérive, cœur-réacteur
    N.crane(lot, M, ZS, r, F_nav)
    N.nacelles(lot, M, ZS, r, F_nav)
    for s in (-1, 1):
        N.aile(lot, M, s, ZS, F_nav)
    N.derive(lot, M, ZS, r, F_nav)
    c = (-3.05, 0.0, ZS - 0.4)
    N.coeur(lot, M, c, r, F_nav)
    for (y, z, rr, cible) in ((-0.35, -0.2, 0.085, (-3.75, -1.0, ZS - 0.3)), (0.35, -0.25, 0.085, (-3.75, 1.0, ZS - 0.3)),
                              (-0.2, 0.45, 0.05, (-2.2, -0.6, ZS + 0.55))):
        a = (c[0] + (0.62 if cible[0] > c[0] else -0.62), c[1] + y, c[2] + z)
        R.tuyau(lot, M["cuivre"], M["or_sombre"], [a, (cible[0], a[1], a[2]), cible], rr, xf=F_nav)
    for (dy, dz) in ((-0.5, -0.4), (-0.15, -0.55), (0.3, 0.6)):
        R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(c[0] + 0.2, c[1] + dy, c[2] + dz), (c[0] + 0.7, c[1] + dy - 0.35, c[2] + dz - 0.3),
                                                          (HX0 - 0.1, dy * 2.5, ZP + 0.6 + dz * 0.5)], 0.045, xf=F_nav)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (c[0] - 0.4, -0.6, c[2] + 0.4), (-4.2, -1.0, ZS + 0.75), 0.25, r, n=4, rouges=2, xf=F_nav)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (c[0] + 0.2, -0.65, c[2] - 0.4), (HX0 - 0.1, -1.6, ZP + 0.5), 0.3, r, n=4, rouges=1, xf=F_nav)
    # berceaux sous les nacelles
    for s in (-1, 1):
        for x in (-4.3, -5.6):
            p = F_nav((x, s * N.NAC_Y, ZS - 0.05 - N.nac_r(x) + 0.08))
            q = G.rot_z((x, s * N.NAC_Y, 0.0), PSI)
            h = p[2] - ZP
            lot.put(M["bronze"], G.boite((q[0], q[1] + OY, ZP + h / 2), (0.42, 0.7, h), rz=PSI), F_sol)
            lot.put(M["or_sombre"], G.boite((q[0], q[1] + OY, ZP + 0.1), (0.5, 0.78, 0.08), rz=PSI), F_sol)
    return dict(R.COMPTE)
