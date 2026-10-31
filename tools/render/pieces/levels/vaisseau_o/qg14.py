"""ÂGE 14 · ORBITE (bible DESIGN_EPOQUES §5, époque 14) : le SPATIOPORT DE COMMANDEMENT, emprise 16×8, nez à droite. Lot QG, 31/10.

Lecture de gauche à droite : tuyères (le passé), tour de contrôle, grande parabole, crâne à chevrons qui regarde l'est.
- Signature : 2 AILES de panneaux dorés dépliées (la silhouette la plus large de la série), GRANDE PARABOLE, mâts-balises
  à feu rouge, réservoirs sphériques dorés, bras articulé.
- Module de l'âge (brief QG : la Porte d'Érèbe reste un silo distinct, son ANNEAU est le module de l'âge 14) : un anneau
  de segments en cours d'assemblage sur son berceau au sud, 3 segments manquants, le portique en amène un.
- Cousin de 13 et 15 : le vaisseau est monté sur une plate-forme SUR PIEDS (les 3 lobes de la base flottante de l'âge 15,
  encore posés sur leurs jambes), côtes et épine inclinées vers la queue, terrasses brisées, pylônes aux coins.
Palette : feuille d'or #C9A23A FROISSÉE, blanc #CFCBC2, cellules #1E2A55 à reflets bleus #2F6BFF, balises rouges #FF2A2A ;
peau jaune d'origine sur le crâne, un peu sur les nacelles et la dérive (part de peau d'environ 12 %).
"""
import math

import ere5_vaisseau as N
import geo as G
import greb as R
import mat as MT
import stellaire as E

ZP = 1.12                       # dessus de la plate-forme
ZS = ZP + 1.28                  # axe du vaisseau
F_pal, F_sol = E.F_pal, E.F_sol
F_nav = E.fait_F_nav(ZS)
TX, TY = -1.45, 1.0             # axe de la tour
Z1, Z2, Z3 = ZP + 2.15, ZP + 3.55, ZP + 4.35
ZB = ZP + 3.75                  # flèche des ailes (bôme)
RX, RY = 0.75, -2.0             # anneau de la Porte
RR, RZ = 1.42, ZP + 1.76
RA = (math.sin(0.34), -math.cos(0.34), 0.48)    # axe de l'anneau : tourné vers le sud-est et basculé sur son berceau de levage
DX, DY, DZ = 1.75, 1.75, ZP + 3.95              # grande parabole


def matieres(S):
    surf = MT.surface
    M = {}
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.14, ra=0.2, ec=0.42, nu_k=1.3, ec_col=(0.04, 0.026, 0.016), sans=("_or", "cell", "blanc"))
    cr = (0.01, 0.008, 0.005)
    M["blanc"] = surf("q14_blanc", (0.72, 0.7, 0.62), rough=0.42, met=0.0, coulures=0.5, rouille=(0.2, 0.15, 0.1), usure=0.5, nu=(0.86, 0.84, 0.78),
                      crasse=0.85, crasse_col=cr, graine=1)
    M["blanc2"] = surf("q14_blanc2", (0.44, 0.42, 0.36), rough=0.45, met=0.05, coulures=0.55, rouille=(0.12, 0.08, 0.05), usure=0.55, nu=(0.7, 0.68, 0.6),
                       crasse=0.85, crasse_col=cr, graine=2)
    M["or"] = E.froisse("q14_or", (0.62, 0.39, 0.05), rough=0.32, met=0.42, coulures=0.25, rouille=(0.2, 0.1, 0.03), usure=0.4, nu=(0.95, 0.75, 0.3),
                        crasse=0.6, crasse_col=(0.03, 0.018, 0.005), grain=0.12, graine=3)
    M["or2"] = E.froisse("q14_or2", (0.36, 0.205, 0.028), rough=0.36, met=0.45, coulures=0.3, rouille=(0.14, 0.07, 0.02), usure=0.45, nu=(0.8, 0.6, 0.22),
                         crasse=0.7, crasse_col=(0.02, 0.012, 0.004), grain=0.12, graine=4)
    M["or_sombre"] = surf("q14_orsombre", (0.17, 0.105, 0.03), rough=0.45, met=0.5, coulures=0.3, usure=0.6, nu=(0.55, 0.42, 0.18), crasse=0.8, crasse_col=cr, graine=5)
    M["acier"] = surf("q14_acier", (0.075, 0.072, 0.07), rough=0.5, met=0.55, coulures=0.4, rouille=(0.07, 0.03, 0.012), usure=0.6, nu=(0.24, 0.23, 0.22),
                      crasse=0.7, crasse_col=cr, graine=6)
    M["noyau"] = surf("q14_noyau", (0.011, 0.01, 0.01), rough=0.55, met=0.5, usure=0.3, crasse=0.8, crasse_col=(0.002, 0.002, 0.002), graine=7)
    M["brule"] = surf("q14_brule", (0.009, 0.007, 0.006), rough=0.7, met=0.4, usure=0.0, crasse=0.9, crasse_col=(0.001, 0.001, 0.001), graine=8)
    M["pierre"] = surf("q14_pierre", (0.15, 0.135, 0.105), rough=0.85, met=0.0, tole=(1.55, 1.05), joint=0.5, joint_l=0.01, var=0.15, coulures=0.5,
                       rouille=(0.04, 0.025, 0.016), usure=0.7, nu=(0.24, 0.22, 0.18), crasse=0.85, crasse_col=cr, relief=0.4, graine=9)
    M["pierre2"] = surf("q14_pierre2", (0.07, 0.058, 0.043), rough=0.85, met=0.0, coulures=0.6, rouille=(0.025, 0.016, 0.01), usure=0.7, nu=(0.14, 0.12, 0.1),
                        crasse=0.85, crasse_col=(0.005, 0.004, 0.003), graine=10)
    M["pont"] = surf("q14_pont", (0.09, 0.08, 0.06), rough=0.7, met=0.3, tole=(0.46, 0.46), joint=0.35, joint_l=0.02, var=0.35, usure=0.5, nu=(0.16, 0.14, 0.11),
                     crasse=0.8, crasse_col=(0.005, 0.004, 0.003), relief=0.5, graine=11)
    M["jaune"] = surf("q14_jaune", (0.5, 0.29, 0.015), rough=0.55, met=0.35, coulures=0.7, rouille=(0.09, 0.035, 0.01), usure=0.7, nu=(0.42, 0.38, 0.3),
                      crasse=0.8, crasse_col=cr, graine=12)
    M["jaune2"] = surf("q14_jaune2", (0.3, 0.16, 0.014), rough=0.6, met=0.35, coulures=0.75, rouille=(0.08, 0.03, 0.01), usure=0.7, nu=(0.38, 0.33, 0.26),
                       crasse=0.8, crasse_col=cr, graine=13)
    M["chevron"] = surf("q14_chevron", (0.42, 0.25, 0.02), rough=0.55, met=0.35, bandes=(0.32, (0.012, 0.01, 0.008), 0.5), coulures=0.6,
                        rouille=(0.09, 0.035, 0.01), usure=0.7, nu=(0.4, 0.36, 0.3), crasse=0.8, crasse_col=cr, graine=14)
    M["cuivre"] = surf("q14_cuivre", (0.3, 0.12, 0.04), rough=0.4, met=0.7, coulures=0.4, rouille=(0.05, 0.035, 0.02), usure=0.55, nu=(0.6, 0.34, 0.18), crasse=0.75, crasse_col=cr, graine=15)
    M["caoutchouc"] = surf("q14_caoutchouc", (0.02, 0.018, 0.016), rough=0.75, met=0.0, usure=0.2, crasse=0.5, graine=16)
    M["cable_r"] = surf("q14_cable_r", (0.28, 0.018, 0.01), rough=0.5, met=0.0, usure=0.2, crasse=0.4, graine=17)
    M["cable_n"] = surf("q14_cable_n", (0.012, 0.011, 0.01), rough=0.55, met=0.0, usure=0.2, crasse=0.4, graine=18)
    M["riv"] = surf("q14_riv", (0.05, 0.04, 0.03), rough=0.5, met=0.6, usure=0.4, crasse=0.4, graine=19)
    M["bois"] = surf("q14_bois", (0.1, 0.09, 0.07), rough=0.7, met=0.1, tole=(0.5, 0.12), joint=0.5, var=0.2, usure=0.5, crasse=0.7, graine=20)
    M["terre"] = surf("q14_terre", (0.11, 0.065, 0.035), rough=0.95, met=0.0, usure=0.0, crasse=0.7, crasse_col=(0.03, 0.018, 0.01), graine=21)
    M["cell"] = surf("q14_cell", (0.013, 0.021, 0.08), rough=0.22, met=0.25, usure=0.0, crasse=0.2, crasse_col=(0.004, 0.005, 0.012), grain=0.08, graine=22)
    M["cell2"] = surf("q14_cell2", (0.024, 0.052, 0.21), rough=0.22, met=0.2, usure=0.0, crasse=0.2, crasse_col=(0.004, 0.005, 0.012), grain=0.08, graine=23)
    M["cell3"] = surf("q14_cell3", (0.05, 0.14, 0.62), rough=0.2, met=0.15, usure=0.0, crasse=0.2, crasse_col=(0.004, 0.005, 0.012), grain=0.08, graine=24)
    M["verre"] = MT.verre("q14_verre", col=(0.01, 0.014, 0.03), reflet=(0.1, 0.16, 0.3))
    M["lum"] = MT.lumiere(S, "q14_lum", (1.0, 0.68, 0.32), 0.75, main=0.15)
    M["coeur"] = MT.lumiere(S, "q14_coeur", (1.0, 0.17, 0.025), 1.4, main=0.2)
    M["balise"] = MT.lumiere(S, "q14_balise", (1.0, 0.024, 0.024), 1.6, main=0.3)
    # alias : ere5_vaisseau, greb et stellaire nomment les matières de l'âge 15
    M["bronze"], M["bronze2"], M["nacre"] = M["acier"], M["blanc2"], M["blanc"]
    return M


def froisser(mesh, rnd, amp=0.018):
    """Plis géométriques : sommets déplacés au hasard (mêmes positions pour les sommets confondus)."""
    v, f, u = mesh
    memo = {}
    out = []
    for q in v:
        k = (round(q[0], 4), round(q[1], 4), round(q[2], 4))
        if k not in memo:
            memo[k] = (q[0] + rnd.f(-amp, amp), q[1] + rnd.f(-amp, amp), q[2] + rnd.f(-amp, amp))
        out.append(memo[k])
    return out, f, u


def plaque(p0, ex, ey, w, h, ep=0.03):
    """Plaque rectangulaire orientée : p0, ex × w, ey × h, épaisse de ep derrière (normale −ex×ey)."""
    ez = G.norm(G.cross(ex, ey))
    pts = []
    for z in (-ep, 0.0):
        for (a, b) in ((0, 0), (w, 0), (w, h), (0, h)):
            pts.append(G.add(G.add(G.add(p0, G.mul(ex, a)), G.mul(ey, b)), G.mul(ez, z)))
    faces = [(4, 5, 6, 7), (0, 3, 2, 1), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    uv = [(a, b) for (a, b) in ((0, 0), (w, 0), (w, h), (0, h))] * 2
    return pts, faces, uv


def lerp_p(p0, ex, ey, a, b):
    return G.add(G.add(p0, G.mul(ex, a)), G.mul(ey, b))


# ------------------------------------------------------------------------------------------------ sol
TERRASSES = [
    ([(-7.9, -3.3), (-7.4, -3.95), (-3.4, -3.95), (-3.2, -3.05), (-7.6, -2.9)], 0.3),
    ([(-3.0, -3.95), (3.2, -3.95), (3.4, -3.4), (-2.9, -3.3)], 0.12),
    ([(3.7, -3.9), (7.3, -3.62), (7.9, -2.6), (3.9, -3.25)], 0.38),
    ([(-7.95, -2.75), (-7.2, -2.65), (-7.1, 2.25), (-7.95, 2.3)], 0.24),
    ([(-7.9, 2.4), (-6.6, 2.6), (-4.0, 3.3), (-4.2, 3.95), (-7.5, 3.95)], 0.44),
    ([(-3.6, 3.4), (1.5, 3.2), (1.7, 3.95), (-3.5, 3.95)], 0.3),
    ([(2.2, 3.0), (7.6, 2.2), (7.9, 3.2), (7.0, 3.95), (2.4, 3.95)], 0.36),
]


def sol(lot, M, r):
    xf = F_sol
    E.terrasses(lot, M, TERRASSES, r)
    lot.put(M["terre"], R.tertre((7.35, -0.7, 0.0), 0.75, 1.55, 0.5, r, na=44, nr=9), xf)
    lot.put(M["terre"], R.tertre((6.9, 1.2, 0.0), 0.6, 0.8, 0.28, r, na=30, nr=8), xf)
    for k in range(9):
        a = G.TAU * (k + r.f(-0.2, 0.2)) / 9
        L = r.f(1.4, 2.6)
        p0 = (0.3 + 0.6 * math.cos(a), -0.2 + 0.4 * math.sin(a), 0.03)
        p1 = (0.3 + L * 2.2 * math.cos(a), -0.2 + L * 1.05 * math.sin(a), 0.03)
        lot.put(M["brule"], G.boite(G.lerp(p0, p1, 0.5), (G.length(G.sub(p1, p0)), 0.06, 0.012), rz=math.atan2(p1[1] - p0[1], p1[0] - p0[0])), xf)
    for k in range(7):
        y = -2.1 + 0.62 * k + r.f(-0.06, 0.06)
        h = 0.7 + 0.32 * math.sin(k * 0.9) + r.f(0, 0.2)
        lot.put(M["brule"], G.boite((-7.55, y, h / 2), (0.16, 0.56, h), ry=-0.35), xf)
        lot.put(M["acier"], G.boite((-7.42, y + 0.29, h / 2), (0.1, 0.06, h + 0.05)), xf)
    for (x, y, z) in ((-6.0, -3.5, 0.3), (5.6, -3.45, 0.38), (-6.2, 3.3, 0.44), (4.6, 3.45, 0.36), (-1.6, 3.65, 0.3)):
        R.grille(lot, M["acier"], M["noyau"], (x, y, z + 0.005), (0, 0, 1), 0.55, 0.34, 7, up=(0, 1, 0), xf=xf)
    for (x, y, z0, h) in ((-7.3, -3.42, 0.3, 2.05), (7.3, -3.15, 0.38, 2.3), (-7.3, 3.3, 0.44, 2.85), (7.05, 3.0, 0.36, 2.65)):
        E.pylone(lot, M, x, y, z0, h, r, lum=True)
    for (x, y, z, s) in ((-2.4, -3.78, 0.12, (0.3, 0.26, 0.2)), (7.7, -1.95, 0.0, (0.4, 0.36, 0.26)), (-7.7, -2.45, 0.24, (0.3, 0.3, 0.2)),
                         (2.55, -3.8, 0.12, (0.28, 0.24, 0.2)), (-2.8, 3.7, 0.3, (0.36, 0.3, 0.22)), (7.6, 1.85, 0.0, (0.3, 0.26, 0.2)),
                         (6.8, 2.0, 0.0, (0.26, 0.26, 0.2))):
        R.bloc(lot, M["pierre2"], (x, y, z), s, r, xf=xf)
    # transformateurs, treuils, caisses, fûts, tuyaux
    for (x, y, z) in ((-6.0, -3.42, 0.3), (6.2, -3.4, 0.38)):
        lot.put(M["acier"], G.boite((x, y, z + 0.25), (0.66, 0.46, 0.5)), xf)
        for k in range(4):
            lot.put(M["blanc2"], G.boite((x - 0.3 + 0.2 * k, y, z + 0.25), (0.04, 0.5, 0.42)), xf)
        for k in range(3):
            xx = x - 0.21 + 0.21 * k
            lot.put(M["blanc"], G.tour([(z + 0.5, 0.05), (z + 0.55, 0.075), (z + 0.6, 0.05), (z + 0.65, 0.07), (z + 0.7, 0.045), (z + 0.75, 0.06),
                                         (z + 0.81, 0.02)], 10, "z", (xx, y, 0.0), cap0=True, cap1=True), xf)
        R.faisceau(lot, M["cable_r"], M["cable_n"], (x - 0.21, y, z + 0.81), (x + (1.2 if x < 0 else -1.1), y + 0.55, ZP - 0.1), 0.22, r, n=4, rouges=1, xf=xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(-5.2, -3.12, 0.42), (-3.6, -3.12, 0.42), (-3.6, -3.12, 0.95), (-3.6, -2.75, 0.95)], 0.085, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(-7.6, -2.1, 0.36), (-7.6, -1.1, 0.36), (-7.6, -1.1, 0.85)], 0.05, xf=xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(7.6, -2.3, 0.5), (6.95, -2.25, 0.5), (6.95, -2.25, 0.98), (6.45, -2.25, 0.98)], 0.05, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(2.0, -3.72, 0.24), (3.0, -3.72, 0.24), (3.0, -3.55, 0.24), (3.0, -3.55, 0.8)], 0.03, xf=xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(4.25, -3.75, 0.44), (4.25, -3.5, 0.44), (4.25, -3.5, 0.95)], 0.03, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(-3.4, 3.7, 0.36), (-1.2, 3.6, 0.36), (-1.2, 3.6, 0.9)], 0.05, xf=xf)
    for (x, y, z, s, rz) in ((1.75, -3.72, 0.12, (0.4, 0.3, 0.3), 0.2), (2.15, -3.68, 0.12, (0.3, 0.28, 0.26), -0.4), (6.35, 3.55, 0.36, (0.38, 0.3, 0.3), 0.15), (-5.1, 3.65, 0.44, (0.34, 0.3, 0.28), -0.3)):
        R.caisse(lot, M["bois"], M["acier"], (x, y, z), s, rz, xf=xf)
    for (x, y, z, c, rz) in ((3.3, -3.8, 0.12, False, 0), (4.6, -3.62, 0.38, True, 0.8), (-7.45, 2.9, 0.44, False, 0), (-7.6, 1.2, 0.24, True, -0.4), (2.9, 3.6, 0.36, False, 0)):
        R.fut(lot, M["cuivre"] if x > 0 else M["acier"], M["or_sombre"], (x, y, z), 0.11, 0.3, couche=c, rz=rz, xf=xf)


def porte(lot, M, r):
    """La PORTE au sud, sous l'anneau : proue en pointe (cousine de l'âge 13), baie cintrée, seuil ; deux escaliers montent à la plate-forme."""
    xf = F_sol
    gx, gy, z0 = 0.15, -3.42, 0.12
    poly = [(gx - 0.72, gy + 0.32), (gx + 0.72, gy + 0.32), (gx + 0.55, gy - 0.12), (gx, gy - 0.36), (gx - 0.55, gy - 0.12)]
    lot.put(M["blanc"], G.prisme(poly, z0, z0 + 0.86, top_scale=0.97), xf)
    lot.put(M["or_sombre"], G.prisme(E.sc(poly, 1.06), z0 + 0.86, z0 + 0.94, top_scale=1.0), xf)
    lot.put(M["or2"], froisser(G.prisme(E.sc(poly, 0.98), z0 + 0.94, z0 + 1.2, top_scale=0.35), r, 0.012), xf)
    by = gy - 0.38
    lot.put(M["or_sombre"], G.tour([(by - 0.02, 0.4), (by + 0.04, 0.4), (by + 0.04, 0.3), (by - 0.02, 0.3)], 20, "y", (gx, 0.0, z0 + 0.42), a0=-math.pi / 2, a1=math.pi / 2), xf)
    lot.put(M["noyau"], G.tour([(by + 0.01, 0.3), (by + 0.02, 0.0)], 20, "y", (gx, 0.0, z0 + 0.42), a0=-math.pi / 2, a1=math.pi / 2), xf)
    lot.put(M["noyau"], G.boite((gx, by + 0.03, z0 + 0.21), (0.6, 0.03, 0.42)), xf)
    lot.put(M["lum"], G.tour([(by - 0.03, 0.32), (by - 0.02, 0.32), (by - 0.02, 0.3), (by - 0.03, 0.3)], 20, "y", (gx, 0.0, z0 + 0.42), a0=-math.pi / 2, a1=math.pi / 2), xf)
    for k in range(2):
        lot.put(M["pierre"], G.boite((gx, by - 0.15 - 0.12 * k, 0.07 - 0.02 * k), (0.95 + 0.2 * k, 0.14, 0.08)), xf)
    R.mat_antenne(lot, M["or_sombre"], M["acier"], M["balise"], (gx, gy, z0 + 1.2), 0.5, r, xf=xf, lum=False)
    haut = E.F_pal((-3.05, -2.72, ZP - 0.02))
    bas = (haut[0] + 2.3, haut[1] - 0.25, z0)
    ang = math.atan2(haut[1] - bas[1], haut[0] - bas[0])
    n = 11
    for i in range(n):
        p0, p1 = G.lerp(bas, haut, i / float(n)), G.lerp(bas, haut, (i + 1) / float(n))
        lot.put(M["pierre"], G.boite(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, p1[2] - 0.05), (G.length(G.sub(p1, p0)) + 0.02, 0.56, 0.1), rz=ang), xf)
    for s in (-1, 1):
        d = (-0.28 * math.sin(ang) * s, 0.28 * math.cos(ang) * s, 0.0)
        a, b = G.add(bas, d), G.add(haut, d)
        lot.put(M["acier"], G.tube([G.add(a, (0, 0, -0.08)), G.add(b, (0, 0, -0.08))], 0.04, 6), xf)
        R.garde_corps(lot, M["or_sombre"], [a, b], h=0.28, pas=0.28, xf=xf)


# ------------------------------------------------------------------------------------------------ plate-forme
LOBES = [
    ([(-7.0, -1.9), (-6.3, -2.6), (-3.3, -2.75), (-2.6, -2.3), (-2.6, 2.3), (-3.3, 2.7), (-6.3, 2.55), (-7.0, 1.8)], -0.08),
    ([(-2.9, -2.7), (0.0, -3.0), (3.3, -2.85), (3.6, -2.2), (3.6, 2.2), (3.2, 2.45), (-2.9, 2.4)], 0.0),
    ([(3.0, -2.6), (5.0, -2.45), (6.5, -1.6), (7.3, -0.35), (7.2, 0.5), (5.8, 1.9), (3.0, 2.2)], -0.05),
]
JAMBES = [(-6.1, -2.3), (-4.6, -2.45), (-3.1, -2.45), (-1.9, -2.55), (-0.1, -2.75), (1.9, -2.7), (3.3, -2.5), (5.0, -2.2), (6.2, -1.45), (6.9, -0.2), (5.6, 1.6),
          (3.2, 2.0), (0.0, 2.15), (-3.2, 2.35), (-6.2, 2.25), (-6.75, 0.0)]


def plateforme(lot, M, r):
    xf = F_pal
    old = lot.xf
    lot.xf = xf
    for li, (P, dz) in enumerate(LOBES):
        zt = ZP + dz
        lot.put(M["acier"], G.prisme(P, zt - 0.22, zt - 0.04), xf)
        lot.put(M["or_sombre"], G.prisme(E.sc(P, 1.006), zt - 0.08, zt - 0.015, top_scale=0.997), xf)
        lot.put(M["pont"], G.prisme(E.sc(P, 0.99), zt - 0.04, zt + 0.02, top_scale=0.996), xf)
        lot.put(M["noyau"], G.prisme(E.sc(P, 0.8), zt - 0.34, zt - 0.22, top_scale=1.2), xf)
        cx = sum(p[0] for p in P) / len(P)
        cy = sum(p[1] for p in P) / len(P)
        n = len(P)
        for i in range(n):                                          # consoles sous le bord
            a, b = P[i], P[(i + 1) % n]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            k = max(1, int(L / 0.6))
            for j in range(k):
                t = (j + 0.5 + r.f(-0.2, 0.2)) / k
                p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                q = (p[0] + (cx - p[0]) * 0.07, p[1] + (cy - p[1]) * 0.05)
                w = r.f(0.05, 0.08)
                lot.put(M["acier"] if r.f() < 0.5 else M["or_sombre"], G.prisme(E.rect(q[0], q[1], w), zt - 0.42, zt - 0.22, top_scale=2.0), xf)
    # jambes télescopiques minces (ère V : le vide sous la coque ; à l'âge 15 elles disparaîtront)
    for i, (x, y) in enumerate(JAMBES):
        pied = (x + (0.25 if x > 0 else -0.25), y + (-0.28 if y < 0 else 0.25), 0.1)
        tete = (x, y, ZP - 0.18)
        E.jambe(lot, M["blanc2"], M["acier"], M["or_sombre"], M["acier"], pied, tete, 0.11 + 0.02 * (i % 2), 0.065)
        lot.put(M["pierre2"], G.tour([(0.0, 0.2), (0.07, 0.18), (0.14, 0.09)], 10, "z", pied, cap1=True), xf)
    for i in range(len(JAMBES) - 1):                                # croisillons dans le vide
        if i in (9, 13, 14):
            continue
        a, b = JAMBES[i], JAMBES[i + 1]
        if i % 2 == 0:
            lot.put(M["acier"], G.tube([(a[0], a[1], 0.34), (b[0], b[1], ZP - 0.24)], 0.018, 5), xf)
    # flexibles et faisceaux qui pendent sous la plate-forme
    for (x0, x1, y, fl) in ((-5.6, -4.6, -2.3, 0.4), (-2.4, -1.6, -2.45, 0.5), (2.1, 3.0, -2.55, 0.45), (5.2, 6.0, -1.7, 0.4), (-1.0, -0.3, -2.4, 0.35)):
        z = ZP - 0.26
        R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(x0, y, z), (x0 + 0.2, y - 0.05, z - fl), ((x0 + x1) / 2, y - 0.1, z - fl * 1.15), (x1 - 0.15, y - 0.04, z - fl * 0.8), (x1, y, z)], 0.04, xf=xf)
    for (x0, x1, y, fl) in ((-4.4, -2.9, -2.5, 0.35), (-0.4, 0.6, -2.7, 0.3), (3.3, 4.0, -2.35, 0.4), (6.0, 6.9, -1.0, 0.3)):
        R.faisceau(lot, M["cable_r"], M["cable_n"], (x0, y, ZP - 0.26), (x1, y, ZP - 0.26), fl, r, n=4, rouges=1, xf=xf)
    # garde-corps, évents, écoutilles
    R.garde_corps(lot, M["or_sombre"], [(-6.2, -2.55, ZP - 0.08), (-3.4, -2.69, ZP - 0.08)], h=0.28, xf=xf)
    R.garde_corps(lot, M["or_sombre"], [(2.3, -2.93, ZP), (3.2, -2.8, ZP)], h=0.28, xf=xf)
    R.garde_corps(lot, M["or_sombre"], [(5.0, -2.4, ZP - 0.05), (6.45, -1.56, ZP - 0.05), (7.25, -0.35, ZP - 0.05)], h=0.28, xf=xf)
    for (x, y) in ((3.25, -2.2), (5.9, -1.15), (-5.7, -2.0), (-3.7, -2.1), (-1.6, -2.15), (4.3, 1.5)):
        R.grille(lot, M["acier"], M["noyau"], (x, y, ZP + 0.03), (0, 0, 1), 0.45, 0.28, 6, up=(0, 1, 0), xf=xf)
    lot.xf = old


# ------------------------------------------------------------------------------------------------ anneau de la Porte
def anneau(lot, M, r):
    """L'ANNEAU en assemblage (module de l'âge 14) : segments de lames blanches et d'or sur un berceau, 3 manquants en haut
    à droite ; portique de chantier à 2 pieds, chariot, segment suspendu ; échafaudage ; flexibles et faisceaux."""
    xf = F_pal
    c = (RX, RY, RZ)
    ax = G.norm(RA)
    e1 = G.norm(G.cross((0.0, 0.0, 1.0), ax))     # horizontal, dans le plan de l'anneau
    e2 = G.cross(ax, e1)

    def pt(a, rr=RR, z=0.0):
        return G.add(c, G.add(G.add(G.mul(e1, rr * math.cos(a)), G.mul(e2, rr * math.sin(a))), G.mul(ax, z)))

    def seg(a0, a1, prof, o=c, ferme=True, n=6):
        """Maille d'un secteur d'anneau : prof = [(z le long de l'axe, rayon)], dans le repère (e1, e2, axe)."""
        rings = []
        for i in range(n + 1):
            a = a0 + (a1 - a0) * i / n
            rings.append([G.add(o, G.add(G.add(G.mul(e1, rr * math.cos(a)), G.mul(e2, rr * math.sin(a))), G.mul(ax, z))) for (z, rr) in prof])
        return G.loft(rings, cap0=ferme, cap1=ferme, closed=ferme)

    prof = [(-0.2, RR - 0.22), (-0.2, RR + 0.15), (-0.12, RR + 0.25), (0.12, RR + 0.25), (0.2, RR + 0.15), (0.2, RR - 0.22), (0.1, RR - 0.28), (-0.1, RR - 0.28)]
    NS = 18
    manque = (1, 2, 3)                                             # en haut à droite
    for k in range(NS):
        a0 = G.TAU * k / NS + 0.02
        a1 = G.TAU * (k + 1) / NS - 0.02
        if k in manque:
            continue
        am = (a0 + a1) / 2
        lot.put(M["blanc"] if k % 3 else M["blanc2"], seg(a0, a1, prof), xf)
        # sur la face vers la caméra : bande de feuille d'or inégale, plaque, évent ou hublot ; bobine intérieure, éclisse
        lg = (0.03, 0.09, 0.05)[k % 3]
        lot.put(M["or"], froisser(seg(a0 + lg, a1 - lg, [(0.215, RR - 0.1), (0.215, RR + 0.13)], ferme=False), r, 0.008), xf)
        lot.put(M["cuivre"], seg(am - 0.1, am + 0.1, [(-0.08, RR - 0.3), (0.08, RR - 0.3), (0.08, RR - 0.25), (-0.08, RR - 0.25)], n=3), xf)
        lot.put(M["noyau"], seg(am + 0.05, am + 0.14, [(0.218, RR - 0.17), (0.218, RR - 0.11)], ferme=False, n=2), xf)
        p = pt(a1 + 0.02, RR + 0.27)
        lot.put(M["acier"], G.oriente(G.boite((0, 0, 0), (0.12, 0.34, 0.1)), p, G.norm(G.sub(p, c))), xf)
        if k % 4 == 1:
            q = pt(am - 0.06, RR + 0.02, 0.23)
            R.hublot(lot, M["or_sombre"], M["lum"] if k % 8 == 1 else M["verre"], q, ax, ("rond", "octo", "fente", "losange", "demi")[k % 5], 0.05, xf=xf)
        if k in (6, 13):
            p = pt(am, RR + 0.26)
            R.mat_antenne(lot, M["or_sombre"], M["acier"], M["balise"], p, 0.34, r, xf=xf)
    for a, sg in ((G.TAU * 1 / NS, 1), (G.TAU * 4 / NS, -1)):      # bouts de l'anneau ouvert : câbles qui attendent
        R.faisceau(lot, M["cable_r"], M["cable_n"], pt(a - sg * 0.04, RR - 0.05, 0.15), pt(a + sg * 0.2, RR - 0.3, 0.2), 0.3, r, n=3, rouges=1, xf=xf)
        R.tuyau(lot, M["cuivre"], M["or_sombre"], [pt(a - sg * 0.05, RR + 0.08, 0.1), pt(a + sg * 0.14, RR + 0.08, 0.1)], 0.03, xf=xf)
    R.compte("anneau_segments", NS - len(manque))
    # berceau : 2 sellettes en V, vérins
    for s in (-1, 1):
        q = pt(-math.pi / 2 + s * 0.5, RR + 0.26)
        base = (q[0] + e1[0] * s * 0.25, q[1] + e1[1] * s * 0.25, ZP + 0.02)
        lot.put(M["blanc2"], G.prisme(E.rect(base[0], base[1], 0.28, 0.3), ZP + 0.02, q[2] - 0.02, top_scale=0.75), xf)
        lot.put(M["or_sombre"], G.prisme(E.rect(base[0], base[1], 0.33, 0.35), ZP + 0.02, ZP + 0.1), xf)
        lot.put(M["acier"], G.tube([(base[0] - e1[0] * s * 0.55, base[1] - e1[1] * s * 0.55, ZP + 0.04), pt(-math.pi / 2 + s * 0.2, RR + 0.26)], 0.04, 8), xf)
    # portique de chantier
    p1 = G.add(c, G.add(G.mul(e1, -RR - 0.72), (0, 0, -RZ + ZP)))
    p2 = G.add(c, G.add(G.mul(e1, RR + 0.72), (0, 0, -RZ + ZP)))
    zh = RZ + RR + 0.62
    for p in (p1, p2):
        for dy in (-0.16, 0.16):
            q = G.add(p, G.mul(ax, dy))
            lot.put(M["blanc2"], G.tube([q, (q[0], q[1], zh)], 0.035, 6), xf)
        lot.put(M["or_sombre"], G.boite((p[0], p[1], ZP + 0.05), (0.5, 0.56, 0.1)), xf)
        for k in range(5):
            z0, z1 = ZP + 0.25 + k * 0.62, ZP + 0.25 + (k + 1) * 0.62
            a, b = G.add(p, G.mul(ax, -0.16)), G.add(p, G.mul(ax, 0.16))
            if k % 2:
                a, b = b, a
            lot.put(M["acier"], G.tube([(a[0], a[1], z0), (b[0], b[1], z1)], 0.013, 4), xf)
    t1, t2 = (p1[0], p1[1], zh), (p2[0], p2[1], zh)
    lot.put(M["or"], G.tube([t1, t2], 0.075, 8), xf)
    lot.put(M["acier"], G.tube([G.add(t1, (0, 0, -0.17)), G.add(t2, (0, 0, -0.17))], 0.03, 6), xf)
    for i in range(10):
        a, b = G.lerp(t1, t2, i / 10.0), G.lerp(t1, t2, (i + 1) / 10.0)
        lot.put(M["acier"], G.tube([a if i % 2 else G.add(a, (0, 0, -0.17)), G.add(b, (0, 0, -0.17)) if i % 2 else b], 0.011, 4), xf)
    # chariot et segment suspendu
    am = G.TAU * 2.5 / NS
    decal = G.add(G.mul(e1, 0.3 * math.cos(am)), G.add(G.mul(e2, 0.3 * math.sin(am)), (0.0, 0.0, 0.1)))     # segment presque en place
    a0, a1 = am - 0.3, am + 0.3
    lot.put(M["blanc"], seg(a0, a1, prof, o=G.add(c, decal)), xf)
    lot.put(M["or"], froisser(seg(a0 + 0.05, a1 - 0.05, [(0.215, RR - 0.1), (0.215, RR + 0.13)], o=G.add(c, decal), ferme=False), r, 0.008), xf)
    q = G.add(pt(am, RR + 0.26), decal)
    tro = (q[0], q[1], zh - 0.2)
    lot.put(M["acier"], G.boite(tro, (0.3, 0.3, 0.14)), xf)
    lot.put(M["cable_n"], G.tube([tro, q], 0.012, 4), xf)
    for s_ in (-0.2, 0.2):
        q2 = G.add(pt(am + s_, RR + 0.26), decal)
        lot.put(M["cable_n"], G.tube([G.add(q, (0, 0, 0.3)), q2], 0.008, 4), xf)
    # échafaudage et faisceaux de chantier
    R.echafaudage(lot, M["acier"], M["bois"], RX - RR - 0.55, RX - RR - 0.05, RY - 0.25, RY - 0.05, ZP, RZ + 0.4, 3, xf=xf)
    R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(RX + 0.9, RY + 0.25, ZP + 0.05), (RX + 1.3, RY + 0.55, ZP + 0.1), (RX + 1.7, RY + 0.2, ZP + 0.7), pt(-0.55, RR + 0.2)], 0.05, xf=xf)
    R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(RX - 0.8, RY + 0.35, ZP + 0.05), (RX - 1.1, RY + 0.55, ZP + 0.15), pt(3.65, RR + 0.2)], 0.04, xf=xf)


# ------------------------------------------------------------------------------------------------ tour, ailes, parabole
def tour(lot, M, r):
    xf = F_pal
    c = (TX, TY)
    # socle à contreforts, fût blanc étagé, manchon de feuille d'or, galerie, cabine évasée
    lot.put(M["blanc2"], G.prisme(R.octo(c, 1.02), ZP, ZP + 0.5, top_scale=0.88), xf)
    lot.put(M["or_sombre"], G.prisme(R.octo(c, 0.95), ZP + 0.5, ZP + 0.56, top_scale=0.97), xf)
    lot.put(M["blanc"], G.prisme(R.octo(c, 0.76), ZP + 0.56, Z1 - 0.1, top_scale=0.78), xf)
    for a_ in (math.radians(205), math.radians(260), math.radians(322)):
        p = (c[0] + 0.98 * math.cos(a_), c[1] + 0.98 * math.sin(a_))
        q = (c[0] + 0.62 * math.cos(a_), c[1] + 0.62 * math.sin(a_))
        lot.put(M["blanc2"], G.tube([(p[0], p[1], ZP + 0.48), (q[0], q[1], Z1 - 0.4)], 0.08, 6), xf)
    lot.put(M["acier"], G.prisme(R.octo(c, 0.64), Z1 - 0.1, Z1, top_scale=1.08), xf)
    lot.put(M["or"], froisser(G.prisme(R.octo(c, 0.58), Z1, Z2 - 0.06, top_scale=0.84), r, 0.018), xf)
    for z in (Z1 + 0.45, Z1 + 0.95):                               # sangles sur la feuille d'or
        rr = 0.58 - 0.09 * (z - Z1) / (Z2 - Z1) * 1.0
        lot.put(M["blanc2"], G.prisme(R.octo(c, rr + 0.0), z, z + 0.05, top_scale=1.0), xf)
    lot.put(M["blanc2"], G.prisme(R.octo(c, 0.56), Z2 - 0.06, Z2, top_scale=1.5), xf)
    lot.put(M["blanc"], G.prisme(R.octo(c, 0.78), Z2, Z3 - 0.28, top_scale=1.1), xf)
    # vitrage en bande inclinée, pans inégaux (pas une rangée de fenêtres)
    vit = R.octo(c, 0.84)
    lot.put(M["verre"], G.prisme(R.octo(c, 0.8), Z2 + 0.14, Z3 - 0.38, top_scale=1.09), xf)
    for i, (a_, lit) in enumerate(((math.radians(202.5), False), (math.radians(247.5), True), (math.radians(292.5), False), (math.radians(337.5), False))):
        ca, sa = math.cos(a_), math.sin(a_)
        for s in (-0.2, 0.2) if i != 1 else (-0.28, -0.08, 0.2):
            x0 = c[0] + 0.78 * ca - s * sa
            y0 = c[1] + 0.78 * sa + s * ca
            x1 = c[0] + 0.86 * ca - s * sa
            y1 = c[1] + 0.86 * sa + s * ca
            lot.put(M["blanc2"], G.tube([(x0, y0, Z2 + 0.1), (x1, y1, Z3 - 0.34)], 0.014, 4), xf)
        if lit:
            lot.put(M["lum"], G.boite((c[0] + 0.83 * ca, c[1] + 0.83 * sa, Z2 + 0.35), (0.16, 0.02, 0.2), rz=a_ + math.pi / 2, rx=0.0), xf)
    lot.put(M["or_sombre"], G.prisme(R.octo(c, 0.92), Z3 - 0.28, Z3 - 0.2, top_scale=1.0), xf)
    lot.put(M["blanc2"], G.prisme(R.octo(c, 0.88), Z3 - 0.2, Z3, top_scale=0.62), xf)
    R.garde_corps(lot, M["or_sombre"], [(p[0], p[1], Z3 - 0.2) for p in vit + [vit[0]]], h=0.2, pas=0.2, xf=xf)
    # hublots, grilles, tuyaux, faisceaux du fût
    for (a_, z, f, t, lit) in ((225, ZP + 1.0, "octo", 0.09, True), (262, ZP + 1.45, "ogive", 0.1, False), (300, ZP + 0.85, "rond", 0.08, True), (200, ZP + 1.6, "fente", 0.07, False), (335, ZP + 1.55, "losange", 0.08, True)):
        a = math.radians(a_)
        n = (math.cos(a), math.sin(a), 0.0)
        p = (c[0] + 0.71 * n[0], c[1] + 0.71 * n[1], z)
        R.hublot(lot, M["or_sombre"], M["lum"] if lit else M["verre"], p, n, f, t, xf=xf)
    R.grille(lot, M["or_sombre"], M["noyau"], (c[0] + 0.1, c[1] - 0.88, ZP + 0.27), (0, -1, 0), 0.5, 0.2, 5, xf=xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(c[0] - 0.65, c[1] - 0.5, ZP + 0.6), (c[0] - 0.65, c[1] - 0.5, Z1 - 0.15), (c[0] - 0.42, c[1] - 0.32, Z1 + 0.4)], 0.05, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(c[0] + 0.55, c[1] - 0.6, ZP + 0.6), (c[0] + 0.55, c[1] - 0.6, Z1 + 0.25)], 0.03, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (c[0] - 0.72, c[1] - 0.55, Z1 - 0.2), (c[0] + 0.72, c[1] - 0.6, Z1 - 0.2), 0.45, r, n=5, rouges=2, xf=xf)
    # mât de commandement : le point le plus haut, balise, antennes, sonde
    z = Z3
    lot.put(M["or_sombre"], G.prisme(R.octo(c, 0.2), z - 0.05, z + 0.2, top_scale=0.8), xf)
    lot.put(M["blanc"], G.tour([(z + 0.2, 0.1), (z + 1.2, 0.06), (z + 2.1, 0.022)], 10, "z", (c[0], c[1], 0.0), cap0=True), xf)
    for k, zz in enumerate((z + 0.6, z + 1.1, z + 1.55)):
        L = 0.44 - 0.11 * k
        lot.put(M["or_sombre"], G.tube([(c[0] - L, c[1] + 0.03, zz), (c[0] + L, c[1] - 0.03, zz)], 0.012, 5), xf)
        lot.put(M["balise"] if k == 1 else M["acier"], G.sphere((c[0] + L, c[1] - 0.03, zz), 0.028, 8, 4), xf)
    lot.put(M["balise"], G.sphere((c[0], c[1], z + 2.15), 0.05, 10, 5), xf)
    R.compte("mats")
    R.mat_antenne(lot, M["or_sombre"], M["acier"], M["balise"], (c[0] + 0.55, c[1] + 0.25, Z3 - 0.1), 0.65, r, xf=xf, lum=False)
    # petite parabole de la cabine
    parabole(lot, M, r, (c[0] - 0.75, c[1] - 0.15, Z3 + 0.2), (-0.35, -0.65, 0.65), 0.34, 0.26, sup=True)


def parabole(lot, M, r, c, axe, Rd, f, sup=False, xf=None):
    """Parabole : dessous en coque, pétales de feuille d'or et de blanc, nervures, lèvre, source sur 3 bras, feu."""
    xf = xf or F_pal
    ez = G.norm(axe)
    e1 = G.norm(G.cross((0.0, 0.0, 1.0), ez))
    e2 = G.cross(ez, e1)

    def surf(rho, a, g=0.0):
        z = rho * rho / (4.0 * f)
        return G.add(c, G.add(G.add(G.mul(e1, rho * math.cos(a)), G.mul(e2, rho * math.sin(a))), G.mul(ez, z + g)))

    rhos = [Rd * x for x in (0.08, 0.26, 0.45, 0.63, 0.82, 1.0)]
    # coque arrière
    rings = [[surf(rh, G.TAU * j / 36, -0.03) for j in range(36)] for rh in rhos]
    lot.put(M["blanc2"], G.loft(rings), xf)
    ns = 6
    for bi in range(len(rhos) - 1):
        ns = max(ns, int(G.TAU * rhos[bi + 1] / (0.42 if Rd > 1 else 0.2)))
        d0 = r.f(0, 1.0)
        for k in range(ns):
            a0 = d0 + G.TAU * k / ns + 0.012
            a1 = d0 + G.TAU * (k + 1) / ns - 0.012
            m = M["or"] if (k + bi) % 5 else (M["blanc"] if (k * 3 + bi) % 7 else M["or2"])
            lot.put(m, froisser(N.patch(surf, rhos[bi] + 0.006, rhos[bi + 1] - 0.006, a0, a1, r.f(0.002, 0.012), 3, 3), r, 0.012 if Rd > 1 else 0.004), xf)
    lot.put(M["blanc"], N.tore(surf(Rd, 0.0, 0.0)[0:0] or G.add(c, G.mul(ez, Rd * Rd / (4.0 * f))), Rd, 0.05 if Rd > 1 else 0.018, ez, 64 if Rd > 1 else 28, 6), xf)
    for k in range(8 if Rd > 1 else 4):
        a = G.TAU * k / (8.0 if Rd > 1 else 4.0) + 0.2
        pts = [surf(rhos[0] + (Rd - rhos[0]) * j / 8.0, a, 0.02) for j in range(9)]
        lot.put(M["blanc2"], G.tube(pts, 0.022 if Rd > 1 else 0.008, 5), xf)
    foyer = G.add(c, G.mul(ez, f))
    for k in range(3):
        a = G.TAU * k / 3 + 0.5
        lot.put(M["acier"], G.tube([surf(Rd * 0.66, a, 0.03), foyer], 0.022 if Rd > 1 else 0.008, 5), xf)
    h = 0.34 if Rd > 1 else 0.1
    lot.put(M["or_sombre"], G.oriente(G.tour([(0.0, h * 0.5), (h * 0.3, h * 0.36), (h, h * 0.16), (h * 1.05, 0.0)], 12, "z", cap0=True), G.add(foyer, G.mul(ez, -h * 0.6)), ez), xf)
    if Rd > 1:
        lot.put(M["balise"], G.sphere(G.add(foyer, G.mul(ez, h * 0.6)), 0.05, 10, 5), xf)
    R.compte("paraboles")


def grande_parabole(lot, M, r):
    xf = F_pal
    ax = (0.2, -0.68, 0.7)
    Rd = 1.62
    f = 1.28
    c = (DX, DY, DZ)
    parabole(lot, M, r, c, ax, Rd, f)
    # pied : fût, tête de pivot, secteur d'élévation à dents, contrefiches, tuyaux
    bx, by = DX + 0.1, DY + 0.7
    lot.put(M["blanc2"], G.prisme(R.octo((bx, by), 0.62), ZP, ZP + 0.45, top_scale=0.86), xf)
    lot.put(M["or_sombre"], G.prisme(R.octo((bx, by), 0.56), ZP + 0.45, ZP + 0.5, top_scale=1.0), xf)
    lot.put(M["blanc"], G.prisme(R.octo((bx, by), 0.4), ZP + 0.5, DZ - 0.55, top_scale=0.72), xf)
    for z in (ZP + 1.2, ZP + 2.1):
        lot.put(M["or_sombre"], G.prisme(R.octo((bx, by), 0.38), z, z + 0.06), xf)
    for a_ in (210, 300, 30, 130):
        a = math.radians(a_)
        p = (bx + 0.58 * math.cos(a), by + 0.58 * math.sin(a), ZP + 0.45)
        q = (bx + 0.26 * math.cos(a), by + 0.26 * math.sin(a), DZ - 1.1)
        lot.put(M["acier"], G.tube([p, q], 0.04, 6), xf)
    head = (bx, by, DZ - 0.45)
    lot.put(M["acier"], G.tour([(-0.34, 0.26), (0.34, 0.26)], 18, "x", head, cap0=True, cap1=True), xf)
    lot.put(M["or_sombre"], G.tour([(-0.4, 0.14), (0.4, 0.14)], 12, "x", head, cap0=True, cap1=True), xf)
    for s in (-1, 1):
        a = G.add(head, (s * 0.3, 0, 0))
        b = G.add(c, (s * 0.65, 0.3, 0.1))
        lot.put(M["blanc2"], G.tube([a, b], 0.06, 8), xf)
    lot.put(M["blanc2"], G.tube([G.add(head, (0, -0.1, -0.25)), G.add(c, (0.0, 0.25, -0.2))], 0.05, 8), xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(bx - 0.5, by - 0.5, ZP + 0.3), (bx - 0.5, by - 0.5, ZP + 1.2), (bx - 0.28, by - 0.3, ZP + 1.8)], 0.04, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (bx + 0.38, by - 0.35, ZP + 0.9), (bx + 0.2, by - 0.25, DZ - 0.8), 0.25, r, n=3, rouges=1, xf=xf)


def _panneau(lot, M, r, xf, p0, ex, ey, w, h, kind):
    """Un panneau d'aile : dos blanc, cadre de feuille d'or, puis cellules (type « c ») ou feuille d'or plissée (type « o »)."""
    ez = G.norm(G.cross(ex, ey))
    lot.put(M["blanc2"], plaque(p0, ex, ey, w, h, 0.05), xf)
    b = 0.11
    if kind == "o":
        for (a0, b0, ww, hh, m) in ((0.0, 0.0, w, h, M["or"]),):
            p = G.add(lerp_p(p0, ex, ey, a0 + 0.02, b0 + 0.02), G.mul(ez, 0.01))
            lot.put(m, E.feuille(p, ex, ey, ww - 0.04, hh - 0.04, r, 0.035, 0.12), xf)
        # sangles et rapiéçages
        for t in (0.33, 0.68):
            q = G.add(lerp_p(p0, ex, ey, 0.0, h * t), G.mul(ez, 0.03))
            lot.put(M["blanc2"], plaque(q, ex, ey, w, 0.03, 0.01), xf)
        q = G.add(lerp_p(p0, ex, ey, w * 0.5 + r.f(-0.2, 0.1), h * 0.1), G.mul(ez, 0.035))
        lot.put(M["or2"], E.feuille(q, ex, ey, w * 0.34, h * 0.4, r, 0.03, 0.1), xf)
    else:
        # cadre d'or, épine d'or au milieu, cellules à reflet en diagonale
        for (a0, b0, ww, hh) in ((0.0, 0.0, w, b), (0.0, h - b, w, b), (0.0, 0.0, b, h), (w - b, 0.0, b, h), (w * 0.5 - 0.05, 0.0, 0.1, h)):
            q = G.add(lerp_p(p0, ex, ey, a0, b0), G.mul(ez, 0.012))
            lot.put(M["or"], E.feuille(q, ex, ey, ww, hh, r, 0.012, 0.09), xf)
        pas = 0.2
        ph = r.f(0, 3)
        for side in (0, 1):
            ax0 = b + 0.015 if side == 0 else w * 0.5 + 0.065
            ax1 = w * 0.5 - 0.065 if side == 0 else w - b - 0.015
            nx = max(1, int((ax1 - ax0) / pas))
            ny = max(1, int((h - 2 * b - 0.03) / pas))
            dx = (ax1 - ax0) / nx
            dy = (h - 2 * b - 0.03) / ny
            for i in range(nx):
                for j in range(ny):
                    t = (ax0 + i * dx) * 0.7 + (b + j * dy) * 1.0 + ph
                    streak = math.sin(t * 2.2)
                    m = M["cell3"] if streak > 0.93 else (M["cell2"] if streak > 0.55 or r.f() < 0.08 else M["cell"])
                    q = G.add(lerp_p(p0, ex, ey, ax0 + i * dx + 0.008, b + 0.015 + j * dy + 0.008), G.mul(ez, 0.014))
                    lot.put(m, plaque(q, ex, ey, dx - 0.016, dy - 0.016, 0.006), xf)
    R.compte("panneaux")


def aile_doree(lot, M, r, s, sections, z0, y0):
    """Une aile : bôme, panneaux de tailles inégales (« 2 tailles »), en éventail, charnières, haubans, feu au bout."""
    xf = F_pal
    x0 = TX + s * 0.55 if s < 0 else DX + 0.55
    x = x0
    pts = [(x, y0, z0)]
    tau0 = math.radians(47)
    for i, (w, h, kind, dt, dv) in enumerate(sections):
        # pente de l'aile : dièdre léger, l'aile remonte vers le bout
        x1 = x + s * w
        y1 = y0 + 0.03 * abs(x1 - x0)
        z1 = z0 + 0.1 * abs(x1 - x0)
        a = (x, y0 + 0.03 * abs(x - x0), z0 + 0.1 * abs(x - x0))
        b = (x1, y1, z1)
        ex = G.norm(G.sub(b, a))
        tau = tau0 + dt
        ey = G.norm((0.0, math.cos(tau), math.sin(tau)))
        if ex[0] < 0:
            p0 = G.add(b, G.mul(ey, -h * (0.5 + dv)))
            exx = G.mul(ex, -1.0)
        else:
            p0 = G.add(a, G.mul(ey, -h * (0.5 + dv)))
            exx = ex
        _panneau(lot, M, r, xf, p0, exx, ey, G.length(G.sub(b, a)) - 0.06, h, kind)
        # charnière et contrefiche
        lot.put(M["acier"], G.sphere(a, 0.07, 8, 4), xf)
        lot.put(M["acier"], G.tube([G.add(a, G.mul(ey, h * 0.42)), G.add(G.lerp(a, b, 0.5), (0, 0.05, 0.02))], 0.012, 4), xf)
        lot.put(M["acier"], G.tube([G.add(b, G.mul(ey, h * 0.42)), G.add(G.lerp(a, b, 0.5), (0, 0.05, 0.02))], 0.012, 4), xf)
        pts.append(b)
        x = x1
    bb = [G.add(p, (0.0, 0.05, 0.0)) for p in pts]
    lot.put(M["blanc"], G.tube(bb, 0.055, 8), xf)
    # hauban du mât de la tour à la bôme, feu de bout d'aile, mât
    R.mat_antenne(lot, M["or_sombre"], M["acier"], M["balise"], pts[-1], 0.45, r, xf=xf)
    if s < 0:
        lot.put(M["cable_n"], G.tube([(TX, TY, Z3 + 1.0), pts[2]], 0.009, 4), xf)
        lot.put(M["cable_n"], G.tube([(TX, TY, Z3 + 1.0), pts[1]], 0.009, 4), xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], G.add(pts[0], (0, -0.02, -0.15)), G.add(pts[1], (0, -0.02, -0.15)), 0.14, r, n=3, rouges=1, xf=xf)
    return pts


def ailes(lot, M, r):
    # (largeur, hauteur, type, écart d'angle, décalage) : jamais 2 pareils de suite
    ouest = [(1.15, 1.4, "o", 0.05, 0.0), (1.6, 2.05, "c", -0.06, 0.03), (1.6, 2.05, "c", 0.07, -0.02), (1.2, 1.5, "o", -0.05, 0.05)]
    est = [(0.8, 1.35, "o", 0.0, 0.0), (1.55, 2.0, "c", 0.06, -0.03), (1.15, 1.45, "o", -0.08, 0.05), (1.5, 1.95, "c", 0.05, 0.0)]
    aile_doree(lot, M, r, -1, ouest, ZB, TY + 0.1)
    aile_doree(lot, M, r, 1, est, ZB, DY + 0.8)
    # raccord de la bôme : caissons sur la tour et sur le pied de parabole
    lot.put(M["blanc2"], G.boite((TX - 0.62, TY + 0.1, ZB), (0.34, 0.34, 0.34)), F_pal)
    lot.put(M["acier"], G.boite((DX + 0.5, DY + 0.8, ZB), (0.34, 0.3, 0.3)), F_pal)
    lot.put(M["blanc"], G.tube([(TX + 0.45, TY + 0.2, ZB + 0.05), (DX + 0.1, DY + 0.75, ZB)], 0.05, 8), F_pal)
    # contrefiches en treillis sous chaque aile : du pont (ouest), de la terrasse (est)
    for (b, h, dd) in (((-4.2, 2.35, ZP), (-4.85, TY + 0.18, ZB + 0.26), 0.26), ((4.75, 3.25, 0.36), (5.1, DY + 0.88, ZB + 0.26), 0.3)):
        for s in (-1, 1):
            lot.put(M["blanc2"], G.tube([G.add(b, (s * dd, 0, 0)), G.add(h, (s * 0.07, 0, 0))], 0.035, 6), F_pal)
        for k in range(7):
            t0, t1 = k / 7.0, (k + 1) / 7.0
            sg = 1 if k % 2 else -1
            a0 = G.lerp(G.add(b, (sg * dd, 0, 0)), G.add(h, (sg * 0.07, 0, 0)), t0)
            a1 = G.lerp(G.add(b, (-sg * dd, 0, 0)), G.add(h, (-sg * 0.07, 0, 0)), t1)
            lot.put(M["acier"], G.tube([a0, a1], 0.012, 4), F_pal)
    # petits panneaux et petite parabole sur la terrasse nord-est (les « 2 tailles » de la bible)
    for (x, y, w, h) in ((3.1, 3.35, 1.05, 0.72), (5.75, 3.05, 0.85, 0.6)):
        p0 = (x, y - 0.25, 0.72)
        _panneau(lot, M, r, F_sol, p0, (1.0, 0.0, 0.0), (0.0, 0.72, 0.69), w, h, "c")
        for dx_ in (0.15, w - 0.15):
            lot.put(M["acier"], G.tube([(x + dx_, y - 0.1, 0.36), (x + dx_, y - 0.05, 0.9)], 0.025, 6), F_sol)
    parabole(lot, M, r, (4.55, 3.2, 0.95), (-0.3, -0.62, 0.72), 0.42, 0.3, xf=F_sol)
    lot.put(M["blanc2"], G.tour([(0.36, 0.16), (0.5, 0.13), (0.95, 0.06)], 10, "z", (4.55, 3.2, 0.0), cap1=True), F_sol)


def reservoir(lot, M, r, x, y, rr, h, mat="or", xf=None):
    """Réservoir sphérique doré, à ceinture et pieds, feuille d'or froissée."""
    xf = xf or F_pal
    z0 = ZP
    c = (x, y, z0 + h + rr)
    lot.put(M[mat], froisser(G.sphere(c, rr, 18, 10), r, 0.022), xf)
    lot.put(M["blanc2"], G.tour([(c[2] - 0.04, rr * 1.02), (c[2] + 0.04, rr * 1.02)], 20, "z", (x, y, 0.0)), xf)
    lot.put(M["or_sombre"], G.tour([(c[2] + rr * 0.84, rr * 0.45), (c[2] + rr * 1.02, rr * 0.22), (c[2] + rr * 1.06, 0.0)], 12, "z", (x, y, 0.0)), xf)
    for k in range(4):
        a = G.TAU * k / 4 + 0.4
        p = (x + rr * 0.72 * math.cos(a), y + rr * 0.72 * math.sin(a), z0)
        q = (x + rr * 0.85 * math.cos(a), y + rr * 0.85 * math.sin(a), c[2])
        lot.put(M["acier"], G.tube([p, q], 0.032, 6), xf)
        lot.put(M["or_sombre"], G.boite((p[0], p[1], z0 + 0.03), (0.13, 0.13, 0.06)), xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(x + rr * 0.2, y - rr * 0.6, c[2] - rr * 0.8), (x + rr * 0.2, y - rr * 0.6, z0 + 0.11), (x + rr + 0.3, y - rr * 0.6, z0 + 0.11)], 0.03, xf=xf)


def bras(lot, M, r, p, seg, xf=None):
    """Bras articulé : colonne, épaule, 2 segments blancs à manchon d'or, poignet, pince et panneau tenu."""
    xf = xf or F_pal
    lot.put(M["blanc2"], G.prisme(R.octo(p[:2], 0.28), p[2], p[2] + 0.2, top_scale=0.8), xf)
    a = G.add(p, (0, 0, 0.32))
    lot.put(M["acier"], G.sphere(a, 0.14, 12, 6), xf)
    for q0, q1 in zip([a] + seg[:-1], seg):
        lot.put(M["blanc"], G.tube([q0, q1], 0.075, 10), xf)
        m0 = G.lerp(q0, q1, 0.35)
        d = G.norm(G.sub(q1, q0))
        lot.put(M["or"], G.oriente(G.tour([(0.0, 0.085), (0.32, 0.085)], 10, "z", cap0=True, cap1=True), m0, d), xf)
        lot.put(M["acier"], G.sphere(q1, 0.11, 10, 5), xf)
    q = seg[-1]
    lot.put(M["acier"], G.tube([q, G.add(q, (0.14, -0.05, -0.2))], 0.04, 6), xf)
    pp = G.add(q, (0.14, -0.05, -0.2))
    for s in (-1, 1):
        lot.put(M["or_sombre"], G.tube([pp, G.add(pp, (s * 0.13, 0.0, -0.13))], 0.022, 5), xf)
    R.compte("bras")


def pont(lot, M, r):
    """Le pont : réservoirs dorés, bras articulé, petite parabole, machines près du crâne et des nacelles."""
    xf = F_pal
    reservoir(lot, M, r, -5.6, -1.95, 0.42, 0.12)
    reservoir(lot, M, r, -4.55, -2.2, 0.3, 0.1, "or2")
    reservoir(lot, M, r, 5.65, -1.25, 0.34, 0.1)
    reservoir(lot, M, r, 3.0, 1.6, 0.48, 0.14)
    reservoir(lot, M, r, -3.5, 1.95, 0.38, 0.1, "or2")
    bras(lot, M, r, (3.25, -2.35, ZP), [(3.75, -2.2, ZP + 1.05), (4.75, -1.9, ZP + 0.95)])
    lot.put(M["blanc2"], plaque((4.5, -2.15, ZP + 0.42), (0.95, 0.3, 0.0), (0.0, 0.5, 0.86), 0.65, 0.4, 0.02), xf)
    parabole(lot, M, r, (6.0, 0.9, ZP + 0.32), (0.3, -0.6, 0.75), 0.46, 0.34)
    lot.put(M["blanc2"], G.tour([(ZP, 0.18), (ZP + 0.1, 0.15), (ZP + 0.3, 0.07)], 10, "z", (6.0, 0.9, 0.0), cap1=True), xf)
    # pompes et vannes, cuve ; tuyaux vers les réservoirs, faisceaux
    for (x, y) in ((-3.2, -2.05), (-2.3, -2.2), (2.65, -2.45)):
        lot.put(M["acier"], G.boite((x, y, ZP + 0.16), (0.42, 0.3, 0.3)), xf)
        lot.put(M["blanc2"], G.tour([(-0.18, 0.12), (0.18, 0.12)], 12, "y", (x, 0.0, ZP + 0.36), cap0=True, cap1=True), xf)
        lot.put(M["or"], N.tore((x + 0.12, y - 0.17, ZP + 0.45), 0.07, 0.012, (0.0, 1.0, 0.0), 14, 5), xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(-4.2, -2.3, ZP + 0.3), (-3.4, -2.3, ZP + 0.3), (-3.4, -2.1, ZP + 0.42)], 0.05, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [(-2.1, -2.2, ZP + 0.24), (-1.75, -2.2, ZP + 0.24), (-1.75, -0.6, ZP + 0.24), (-1.75, -0.6, ZP + 0.9)], 0.085, xf=xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(4.3, 1.1, ZP + 0.2), (5.3, 0.95, ZP + 0.2), (5.3, 0.95, ZP + 0.65)], 0.03, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (-1.9, -1.9, ZP + 0.5), (RX - RR - 0.3, RY, ZP + 0.3), 0.2, r, n=3, rouges=1, xf=xf)
    R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(-5.2, -2.3, ZP + 0.05), (-5.0, -2.55, ZP + 0.08), (-4.7, -2.4, ZP + 0.05), (-4.9, -2.2, ZP + 0.1), (-4.4, -2.2, ZP + 0.3)], 0.045, xf=xf)
    R.echafaudage(lot, M["acier"], M["bois"], DX + 0.65, DX + 1.3, DY + 0.1, DY + 0.3, ZP, ZP + 2.1, 3, xf=xf)


def squelette(lot, M, r):
    """Côtes blanches inclinées vers la queue « (((( », épine à vertèbres ; la tour et la parabole poussent au travers."""
    xf = F_pal
    zt = ZS + 2.0
    ye = -0.65
    prof = [(-2.34, ZP + 0.05), (-2.4, ZP + 0.9), (-2.3, ZP + 1.65), (-1.95, ZP + 2.4), (-1.35, ZP + 2.95), (-0.65, zt - 0.05), (0.0, zt)]
    b = 0.95
    for xt in (-3.3, -0.05, 3.0):
        pts = []
        for y, z in prof + [(-y, z) for y, z in reversed(prof[:-1])]:
            s = (z - ZP) / (zt - ZP)
            pts.append((xt - b * (1.0 - s), y + ye * s, z))
        lot.put(M["blanc"], G.tube(G.catmull(pts, 4), 0.07, 8), xf)
        for y in (-2.36, 2.36):
            lot.put(M["or_sombre"], G.boite((xt - b, y, ZP + 0.12), (0.26, 0.22, 0.24)), xf)
        lot.put(M["or"], G.tour([(-0.06, 0.1), (0.06, 0.1)], 10, "y", (xt, ye, zt)), xf)
    ep = G.catmull([(-3.7, -0.15, ZS + 1.0), (-2.7, ye, zt), (2.6, ye, zt), (3.6, -0.25, ZS + 1.35)], 10)
    lot.put(M["blanc"], G.tube(ep, 0.1, 10), xf)
    acc = 0.0
    for i in range(1, len(ep)):
        acc += G.length(G.sub(ep[i], ep[i - 1]))
        if acc > 0.38 + r.f(0, 0.1):
            acc = 0.0
            p = ep[i]
            lot.put(M["acier"], G.boite(p, (0.14, 0.26, 0.22)), xf)
            lot.put(M["or_sombre"], G.prisme([(p[0] - 0.12, p[1] - 0.03), (p[0] + 0.1, p[1] - 0.03), (p[0] + 0.02, p[1] + 0.03), (p[0] - 0.08, p[1] + 0.03)],
                                             p[2] + 0.1, p[2] + 0.3 + r.f(0, 0.12), top_scale=0.2, top_shift=(-0.1, 0.0)), xf)
    surf = N.crane_pt(ZS)
    for xt in (3.55, 4.25):
        pts = [surf(xt - 0.3 * (1.0 - math.sin(a)), a, 0.13) for a in [-0.35 + (math.pi + 0.7) * j / 14.0 for j in range(15)]]
        lot.put(M["blanc"], G.tube(pts, 0.055, 8), F_nav)


def hangar(lot, M, r):
    """Le VENTRE du vaisseau devenu hangar : voûte en berceau d'axe x, sous les côtes, entre le cœur et le crâne ; bâches de
    feuille d'or et plaques blanches rapiécées, jours sombres, ouverture de chantier côté sud (machines visibles dans l'anneau)."""
    xf = F_pal
    zc = ZP + 0.18
    Rv = 1.38

    def surf(x, a, g=0.0):
        k = 1.0 - 0.14 * ((x - 0.4) / 2.9) ** 2
        return (x, (Rv * k + g) * math.cos(a), zc + (Rv * k * 0.92 + g) * math.sin(a))
    xs = [-2.5 + 5.8 * i / 26.0 for i in range(27)]
    lot.put(M["noyau"], N.coque(surf, xs, 28, a0=0.0, a1=math.pi), xf)

    def saut(xm, am):
        return 0.5 < xm < 1.75 and am > 2.55                       # brèche sud : on voit dedans, par l'anneau

    def mats(rr, bi, i):
        x = rr.f()
        if x < 0.42:
            return M["or"]
        if x < 0.56:
            return M["or2"]
        if x < 0.84:
            return M["blanc"] if bi % 2 else M["blanc2"]
        return M["jaune"]
    bandes = [(0.0, 0.3), (0.3, 0.68), (0.68, 1.02), (1.02, 1.38), (1.38, 1.76), (1.76, 2.14), (2.14, 2.54), (2.54, 2.86), (2.86, 3.14)]
    xb = [-2.5, -1.95, -1.3, -0.82, -0.2, 0.25, 0.92, 1.4, 1.95, 2.35, 3.3]
    N.blinde(lot, surf, xb, bandes, mats, r, xf, saut=saut, Mriv=M["riv"])
    # membrures, sangles et machines de la brèche
    for x in (-1.3, 0.25, 1.95):
        lot.put(M["blanc2"], G.tube([surf(x, 0.04 + j * 0.3, 0.05) for j in range(11)], 0.035, 6), xf)
    for (x, y, rr, h) in ((0.85, -1.05, 0.24, 0.8), (1.42, -0.85, 0.3, 1.0), (0.3, -0.7, 0.2, 0.9)):
        lot.put(M["blanc2"], G.tour([(ZP, rr), (ZP + h, rr), (ZP + h + 0.1, rr * 0.7), (ZP + h + 0.14, 0.0)], 14, "z", (x, y, 0.0), cap0=True), xf)
        lot.put(M["or_sombre"], G.tour([(ZP + h * 0.5, rr + 0.012), (ZP + h * 0.5 + 0.05, rr + 0.012)], 14, "z", (x, y, 0.0)), xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [(0.3, -0.95, ZP + 0.5), (0.85, -1.3, ZP + 0.5), (1.42, -1.2, ZP + 0.5)], 0.05, xf=xf)
    R.flexible(lot, M["caoutchouc"], M["or_sombre"], [surf(0.55, 2.5, 0.05), surf(0.9, 2.9, 0.2), surf(1.6, 2.5, 0.05)], 0.05, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], surf(0.5, 2.4, 0.03), surf(1.75, 2.42, 0.03), 0.5, r, n=5, rouges=2, xf=xf)
    # hublots tous différents, évents, antenne sur la voûte
    for (x, a, f, t, lit) in ((-1.9, 2.2, "ogive", 0.1, True), (-0.5, 2.3, "rond", 0.08, False), (2.15, 2.25, "octo", 0.09, True), (2.75, 2.0, "fente", 0.07, False), (-1.05, 1.85, "carre", 0.07, False)):
        p = surf(x, a, 0.06)
        n = G.norm(G.sub(surf(x, a, 0.5), p))
        R.hublot(lot, M["or_sombre"], M["lum"] if lit else M["verre"], p, n, f, t, xf=xf)
    for (x, a, w) in ((-1.55, 1.5, 0.5), (0.6, 1.72, 0.42), (2.55, 1.45, 0.5), (-0.2, 2.5, 0.4)):
        p = surf(x, a, 0.07)
        R.grille(lot, M["or_sombre"], M["noyau"], p, G.norm(G.sub(surf(x, a, 0.5), p)), w, w * 0.45, 5, xf=xf)
    R.tuyau(lot, M["cuivre"], M["or_sombre"], [surf(-2.2, 2.05, 0.1), surf(-0.9, 2.05, 0.1), surf(-0.5, 1.8, 0.1)], 0.045, xf=xf)
    R.tuyau(lot, M["acier"], M["or_sombre"], [surf(1.9, 1.75, 0.1), surf(3.0, 1.85, 0.1)], 0.03, xf=xf)
    R.mat_antenne(lot, M["or_sombre"], M["acier"], None, surf(2.7, 1.4, 0.05), 0.6, r, xf=xf, lum=False)


def vaisseau(lot, M, r):
    M2 = dict(M)
    M2["chevron"] = M["or"]                                         # nacelles : feuille d'or, blanc et jaune, sans chevrons
    M2["jaune2"] = M["blanc2"]
    N.crane(lot, M, ZS, r, F_nav)
    N.nacelles(lot, M2, ZS, r, F_nav)
    N.derive(lot, M, ZS, r, F_nav)
    for s in (-1, 1):
        N.aile(lot, M, s, ZS, F_nav)
    c = (-3.05, 0.0, ZS - 0.4)
    N.coeur(lot, M, c, r, F_nav)
    for (y, z, rr, cible) in ((-0.35, -0.2, 0.085, (-3.75, -1.0, ZS - 0.3)), (0.35, -0.25, 0.085, (-3.75, 1.0, ZS - 0.3)), (-0.2, 0.45, 0.05, (-2.2, -0.6, ZS + 0.55))):
        a = (c[0] + (0.62 if cible[0] > c[0] else -0.62), c[1] + y, c[2] + z)
        R.tuyau(lot, M["cuivre"], M["or_sombre"], [a, (cible[0], a[1], a[2]), cible], rr, xf=F_nav)
    for (dy, dz) in ((-0.5, -0.4), (-0.15, -0.55), (0.3, 0.6)):
        R.flexible(lot, M["caoutchouc"], M["or_sombre"], [(c[0] + 0.2, c[1] + dy, c[2] + dz), (c[0] + 0.7, c[1] + dy - 0.35, c[2] + dz - 0.3), (-1.7, dy * 2.5, ZP + 0.6 + dz * 0.5)], 0.045, xf=F_nav)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (c[0] - 0.4, -0.6, c[2] + 0.4), (-4.2, -1.0, ZS + 0.75), 0.25, r, n=4, rouges=2, xf=F_nav)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (c[0] + 0.2, -0.65, c[2] - 0.4), (-1.7, -1.6, ZP + 0.5), 0.3, r, n=4, rouges=1, xf=F_nav)
    # berceaux sous les nacelles, vérins sous le crâne
    for s in (-1, 1):
        for x in (-4.3, -5.6):
            p = F_nav((x, s * N.NAC_Y, ZS - 0.05 - N.nac_r(x) + 0.08))
            q = G.rot_z((x, s * N.NAC_Y, 0.0), E.PSI)
            h = p[2] - ZP
            lot.put(M["acier"], G.boite((q[0], q[1] + E.OY, ZP + h / 2), (0.42, 0.7, h), rz=E.PSI), F_sol)
            lot.put(M["or_sombre"], G.boite((q[0], q[1] + E.OY, ZP + 0.1), (0.5, 0.78, 0.08), rz=E.PSI), F_sol)
    surf = N.crane_pt(ZS)
    for x in (3.7, 4.6, 5.5):
        for s in (-1, 1):
            a = math.pi + 0.75 if s < 0 else -0.75
            q = F_nav(surf(x, a, 0.0))
            loc = G.rot_z((q[0], q[1] - E.OY, 0.0), -E.PSI)
            pied = (loc[0] - 0.15, loc[1] + s * 0.35, ZP)
            tete = (loc[0], loc[1], q[2] - 0.05)
            lot.put(M["acier"], G.tube([pied, G.lerp(pied, tete, 0.55)], 0.07, 10), F_pal)
            lot.put(M["blanc"], G.tube([G.lerp(pied, tete, 0.5), tete], 0.045, 10), F_pal)
            lot.put(M["blanc2"], G.tour([(ZP, 0.16), (ZP + 0.07, 0.15), (ZP + 0.1, 0.07)], 12, "z", (pied[0], pied[1], 0.0), cap1=True), F_pal)


def build(S, lot):
    R.raz()
    M = matieres(S)
    r = G.Rnd(1414)
    lot.xf = F_pal
    sol(lot, M, r)
    porte(lot, M, r)
    plateforme(lot, M, r)
    hangar(lot, M, r)
    squelette(lot, M, r)
    vaisseau(lot, M, r)
    pont(lot, M, r)
    anneau(lot, M, r)
    tour(lot, M, r)
    grande_parabole(lot, M, r)
    ailes(lot, M, r)
    zones = [(F_sol, 0.3, (-7.5, -3.6), (-3.75, -3.1), 12), (F_sol, 0.12, (-2.8, -0.9), (-3.85, -3.45), 6), (F_sol, 0.12, (1.1, 3.2), (-3.85, -3.45), 6),
             (F_sol, 0.38, (3.9, 7.2), (-3.7, -3.1), 10), (F_sol, 0.24, (-7.9, -7.2), (-2.5, 2.1), 8), (F_pal, ZP, (-6.4, -2.4), (-2.6, -1.5), 18),
             (F_pal, ZP, (2.9, 6.6), (-2.5, -0.95), 18), (F_pal, ZP, (3.3, 5.6), (0.9, 1.9), 8), (F_sol, 0.36, (2.6, 7.0), (3.05, 3.9), 14), (F_sol, 0.44, (-7.4, -4.3), (2.9, 3.9), 6)]
    E.chargement(lot, M, G.Rnd(1415), zones)
    mats = [M["acier"], M["noyau"], M["or_sombre"], M["blanc2"], M["cuivre"]]
    E.menus(lot, mats, G.Rnd(1416), [(z[0], z[1], z[2], z[3], z[4] * 3) for z in zones])
    return dict(R.COMPTE)
