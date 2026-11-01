"""ÂGE 13 · FUSION (bible DESIGN_EPOQUES §5, époque 13) : la CITADELLE-RÉACTEUR, emprise 16×8, nez à droite. Lot QG, 31/10.

Lecture de gauche à droite : tuyères (le passé) devenues tuyères magnétiques, cœur à nu dans la cage des côtes, sphère
de confinement à cheval sur le squelette, crâne à chevrons et verrière qui regarde l'est.
- Signature (critique du 1/11) : SPHÈRE de céramique plus petite, sur TRÉPIED, TORE segmenté de BOBINES à fenêtres de plasma
  (cœur clair, bord sombre, comme le Portique) autour d'elle, FUSELAGE à nouveau continu dessous, FLÈCHE de commandement au sommet (une seule : la couronne de 5 de
  l'âge 15 en sort).
- Dépassements : flèche, tore, dérive, radiateurs derrière le crâne, boîte d'injection, grue de chantier.
- Au sol : terrasses brisées (cousines de l'âge 15), halle en ARC concentrique à la sphère, porte au sud, réservoirs
  d'hélium 3 sur petits trépieds, bobines de cuivre, pylônes de champ.
Palette : céramique blanche #D9D6CF patinée, cuivre #B0703A, plasma magenta #FF4FD8, cœur #FF9A3A ; peau jaune d'origine
sur le crâne et les nacelles (part de peau d'environ 15 %).
"""
import math

import geo as G
import greb as R
import ere5_vaisseau as N
import mat as MT
import stellaire as E

ZS = 1.62                       # axe du vaisseau : à terre, sur ses berceaux
F_pal, F_sol = E.F_pal, E.F_sol
F_nav = E.fait_F_nav(ZS)
CX, CY = -0.85, 1.1             # axe de la sphère (repère palais), reculé : le fuselage se voit devant
HX, HY = -0.85, 0.55            # centre de la halle en arc
RS, ZC = 1.56, 5.25             # sphère (−20 %)
RT, ZT = 2.7, 5.2               # tore
RB, RP = 0.6, 0.34              # section : bobine (+50 %), plasma en retrait
Z_FL = ZC + RS


def matieres(S):
    surf = MT.surface
    M = {}
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.14, ra=0.22, ec=0.36, nu_k=1.3, ec_col=(0.05, 0.03, 0.018), sans=("plasma", "ceram"))
    cr = (0.012, 0.009, 0.006)
    M["ceram"] = surf("q13_ceram", (0.74, 0.72, 0.66), rough=0.42, met=0.0, coulures=0.5, rouille=(0.22, 0.15, 0.1), usure=0.5, nu=(0.86, 0.84, 0.78),
                      crasse=0.85, crasse_col=cr, graine=1)
    M["ceram2"] = surf("q13_ceram2", (0.46, 0.43, 0.37), rough=0.45, met=0.0, coulures=0.6, rouille=(0.14, 0.09, 0.05), usure=0.55, nu=(0.7, 0.67, 0.6),
                       crasse=0.85, crasse_col=cr, graine=2)
    M["ceram_b"] = surf("q13_ceram_b", (0.56, 0.54, 0.48), rough=0.45, met=0.0, coulures=0.5, rouille=(0.2, 0.14, 0.09), usure=0.5, nu=(0.8, 0.78, 0.72),
                        crasse=0.8, crasse_col=(0.05, 0.04, 0.03), graine=31)
    M["ceram_j"] = surf("q13_ceram_j", (0.2, 0.19, 0.165), rough=0.6, met=0.0, usure=0.2, crasse=0.4, crasse_col=(0.05, 0.04, 0.03), graine=32)
    M["ceram3"] = surf("q13_ceram3", (0.075, 0.062, 0.052), rough=0.55, met=0.1, coulures=0.4, rouille=(0.05, 0.03, 0.02), usure=0.6, nu=(0.32, 0.28, 0.22),
                       crasse=0.7, crasse_col=cr, graine=3)
    M["cuivre"] = surf("q13_cuivre", (0.4, 0.15, 0.045), rough=0.4, met=0.55, coulures=0.45, rouille=(0.05, 0.1, 0.07), usure=0.6, nu=(0.75, 0.42, 0.22),
                       crasse=0.8, crasse_col=cr, graine=4)
    M["cuivre2"] = surf("q13_cuivre2", (0.17, 0.065, 0.024), rough=0.45, met=0.5, coulures=0.5, rouille=(0.04, 0.07, 0.05), usure=0.6, nu=(0.5, 0.26, 0.13),
                        crasse=0.8, crasse_col=cr, graine=5)
    M["acier"] = surf("q13_acier", (0.085, 0.075, 0.066), rough=0.5, met=0.55, coulures=0.4, rouille=(0.07, 0.03, 0.012), usure=0.6, nu=(0.24, 0.22, 0.2),
                      crasse=0.7, crasse_col=cr, graine=6)
    M["noyau"] = surf("q13_noyau", (0.012, 0.01, 0.009), rough=0.55, met=0.5, usure=0.3, crasse=0.8, crasse_col=(0.002, 0.002, 0.002), graine=7)
    M["brule"] = surf("q13_brule", (0.009, 0.007, 0.006), rough=0.7, met=0.4, usure=0.0, crasse=0.9, crasse_col=(0.001, 0.001, 0.001), graine=8)
    M["pierre"] = surf("q13_pierre", (0.17, 0.15, 0.115), rough=0.85, met=0.0, tole=(1.2, 0.85), joint=0.5, joint_l=0.012, var=0.16, coulures=0.5,
                       rouille=(0.05, 0.03, 0.02), usure=0.7, nu=(0.28, 0.25, 0.2), crasse=0.85, crasse_col=cr, relief=0.4, graine=9)
    M["pierre2"] = surf("q13_pierre2", (0.075, 0.062, 0.045), rough=0.85, met=0.0, coulures=0.6, rouille=(0.03, 0.02, 0.012), usure=0.7, nu=(0.16, 0.14, 0.11),
                        crasse=0.85, crasse_col=(0.005, 0.004, 0.003), graine=10)
    M["jaune"] = surf("q13_jaune", (0.5, 0.29, 0.015), rough=0.55, met=0.35, coulures=0.7, rouille=(0.09, 0.035, 0.01), usure=0.7, nu=(0.42, 0.38, 0.3),
                      crasse=0.8, crasse_col=cr, graine=11)
    M["jaune2"] = surf("q13_jaune2", (0.3, 0.16, 0.014), rough=0.6, met=0.35, coulures=0.75, rouille=(0.08, 0.03, 0.01), usure=0.7, nu=(0.38, 0.33, 0.26),
                       crasse=0.8, crasse_col=cr, graine=12)
    M["chevron"] = surf("q13_chevron", (0.42, 0.25, 0.02), rough=0.55, met=0.35, bandes=(0.32, (0.012, 0.01, 0.008), 0.5), coulures=0.6,
                        rouille=(0.09, 0.035, 0.01), usure=0.7, nu=(0.4, 0.36, 0.3), crasse=0.8, crasse_col=cr, graine=13)
    M["toit"] = surf("q13_toit", (0.19, 0.075, 0.03), rough=0.42, met=0.45, tole=(0.3, 0.16), joint=0.35, joint_l=0.02, var=0.3, coulures=0.5,
                     rouille=(0.05, 0.1, 0.07), usure=0.6, nu=(0.6, 0.33, 0.17), crasse=0.85, crasse_col=cr, relief=0.7, graine=14)
    M["caoutchouc"] = surf("q13_caoutchouc", (0.02, 0.018, 0.016), rough=0.75, met=0.0, usure=0.2, crasse=0.5, graine=15)
    M["cable_r"] = surf("q13_cable_r", (0.28, 0.018, 0.01), rough=0.5, met=0.0, usure=0.2, crasse=0.4, graine=16)
    M["cable_n"] = surf("q13_cable_n", (0.012, 0.011, 0.01), rough=0.55, met=0.0, usure=0.2, crasse=0.4, graine=17)
    M["riv"] = surf("q13_riv", (0.05, 0.04, 0.03), rough=0.5, met=0.6, usure=0.4, crasse=0.4, graine=18)
    M["bois"] = surf("q13_bois", (0.09, 0.075, 0.055), rough=0.7, met=0.1, tole=(0.5, 0.12), joint=0.5, var=0.2, usure=0.5, crasse=0.7, graine=19)
    M["terre"] = surf("q13_terre", (0.11, 0.065, 0.035), rough=0.95, met=0.0, usure=0.0, crasse=0.7, crasse_col=(0.03, 0.018, 0.01), graine=20)
    M["verre"] = MT.verre("q13_verre", col=(0.012, 0.012, 0.016), reflet=(0.16, 0.14, 0.18))
    M["lum"] = MT.lumiere(S, "q13_lum", (1.0, 0.72, 0.4), 0.8, main=0.2)
    M["hublot"] = E.lumiere_degrade(S, "q13_hublot", (1.0, 0.55, 0.2), (1.0, 0.2, 0.03), (0.2, 0.02, 0.004), 1.0, main=0.25)
    M["coeur"] = E.lumiere_degrade(S, "q13_coeur", (1.0, 0.62, 0.22), (1.0, 0.2, 0.03), (0.16, 0.015, 0.003), 1.1, main=0.3)
    M["plasma"] = E.lumiere_degrade(S, "q13_plasma", (1.0, 0.5, 0.62), (1.0, 0.078, 0.69), (0.16, 0.006, 0.11), 0.85, main=0.2)
    M["balise"] = MT.lumiere(S, "q13_balise", (1.0, 0.12, 0.04), 6.0, main=0.4)
    # alias : ere5_vaisseau, greb et stellaire nomment les matières de l'âge 15
    M["or"], M["or_sombre"], M["bronze"], M["bronze2"], M["nacre"] = M["cuivre"], M["cuivre2"], M["acier"], M["ceram2"], M["ceram"]
    return M


# ------------------------------------------------------------------------------------------------ sol
TERRASSES = [
    ([(-7.9, -3.3), (-7.4, -3.95), (-4.2, -3.95), (-4.0, -3.15), (-7.6, -2.9)], 0.3),
    ([(-3.8, -3.95), (3.3, -3.95), (3.45, -3.2), (2.3, -2.95), (-2.6, -2.95), (-3.7, -3.15)], 0.14),
    ([(3.75, -3.9), (7.3, -3.62), (7.9, -2.6), (3.9, -3.2)], 0.36),
    ([(-7.95, -2.75), (-7.2, -2.65), (-7.1, 2.25), (-7.95, 2.3)], 0.22),
    ([(-7.9, 2.4), (-6.6, 2.6), (-3.6, 2.95), (-3.8, 3.95), (-7.5, 3.95)], 0.42),
    ([(-3.3, 3.0), (2.0, 3.0), (2.2, 3.95), (-3.2, 3.95)], 0.28),
    ([(2.5, 2.1), (7.0, 1.7), (7.9, 2.6), (7.1, 3.95), (2.6, 3.95)], 0.34),
]


def sol(lot, M, r):
    xf = F_sol
    E.terrasses(lot, M, TERRASSES, r)
    # dalle de bobines sous la sphère : couronne de secteurs sombres, fissures de chaleur
    for k in range(9):
        a = G.TAU * (k + r.f(-0.2, 0.2)) / 9
        L = r.f(1.3, 2.3)
        p0 = (-0.1 + 0.9 * math.cos(a), 0.0 + 0.6 * math.sin(a), 0.03)
        p1 = (-0.1 + L * 2.2 * math.cos(a), 0.0 + L * 1.1 * math.sin(a), 0.03)
        lot.put(M["brule"], G.boite(G.lerp(p0, p1, 0.5), (G.length(G.sub(p1, p0)), 0.06, 0.012), rz=math.atan2(p1[1] - p0[1], p1[0] - p0[0])), xf)
    lot.put(M["terre"], R.tertre((7.4, -0.8, 0.0), 0.7, 1.5, 0.5, r, na=44, nr=9), xf)
    lot.put(M["terre"], R.tertre((-1.0, 3.3, 0.0), 0.9, 0.5, 0.2, r, na=30, nr=7), xf)
    for k in range(7):                                                      # déflecteur de souffle, noirci
        y = -2.1 + 0.62 * k + r.f(-0.06, 0.06)
        h = 0.62 + 0.3 * math.sin(k * 0.9) + r.f(0, 0.2)
        lot.put(M["brule"], G.boite((-7.55, y, h / 2), (0.16, 0.56, h), ry=-0.35), xf)
        lot.put(M["acier"], G.boite((-7.42, y + 0.29, h / 2), (0.1, 0.06, h + 0.05)), xf)
    for (x, y, z) in ((-6.0, -3.5, 0.3), (5.6, -3.45, 0.36), (-6.2, 3.3, 0.42), (4.6, 3.45, 0.34), (-1.8, 3.65, 0.28), (2.8, -3.65, 0.14)):
        R.grille(lot, M["acier"], M["noyau"], (x, y, z + 0.005), (0, 0, 1), 0.55, 0.34, 7, up=(0, 1, 0), xf=xf)
    for (x, y, z0, h, lum) in ((-7.35, -3.42, 0.3, 2.0, False), (7.3, -3.15, 0.36, 2.2, False), (-7.3, 3.3, 0.42, 2.7, True), (7.15, 3.1, 0.34, 2.5, True)):
        E.pylone(lot, M, x, y, z0, h, r, lum=lum)
    for (x, y, z, s) in ((-1.5, -3.8, 0.14, (0.3, 0.26, 0.2)), (7.7, -1.95, 0.0, (0.38, 0.34, 0.24)), (-7.7, -2.45, 0.22, (0.3, 0.3, 0.2)),
                         (2.9, 3.75, 0.34, (0.3, 0.24, 0.2)), (-2.8, 3.72, 0.28, (0.36, 0.3, 0.22)), (7.6, 1.5, 0.0, (0.3, 0.26, 0.2)),
                         (7.2, -0.1, 0.0, (0.24, 0.3, 0.16)), (-4.7, -3.75, 0.3, (0.28, 0.24, 0.18))):
        R.bloc(lot, M["pierre2"], (x, y, z), s, r, xf=xf)


def _bobine(lot, M, x, y, z, rr, L, rz=0.0, xf=None):
    """Bobine de cuivre couchée sur bâti : spires (anneaux serrés), joues de céramique."""
    xf = xf or F_sol
    d = (math.cos(rz), math.sin(rz), 0.0)
    c = (x, y, z + rr + 0.08)
    a = G.add(c, G.mul(d, -L / 2))
    prof = [(0.0, rr * 0.55)]
    n = int(L / 0.05)
    for i in range(n):
        t = 0.04 + (L - 0.08) * i / max(1, n - 1)
        prof.append((t, rr * (0.93 if i % 2 else 1.0)))
    prof.append((L, rr * 0.55))
    lot.put(M["cuivre"], G.oriente(G.tour(prof, 16, "z", cap0=True, cap1=True), a, d), xf)
    for t in (0.0, L):
        q = G.add(a, G.mul(d, t))
        lot.put(M["ceram2"], G.oriente(G.tour([(-0.04, rr * 1.2), (0.04, rr * 1.2)], 16, "z", cap0=True, cap1=True), q, d), xf)
        p = G.add(q, (0, 0, -rr * 0.6))
        lot.put(M["acier"], G.boite((p[0], p[1], (z + p[2]) / 2 + 0.02), (0.12, rr * 1.8, p[2] - z + 0.04), rz=rz), xf)


def _reservoir(lot, M, r, x, y, z0, rr, h, surf="ceram", xf=None):
    """Réservoir sphérique d'hélium 3 sur son petit trépied : l'écho au sol de la grande sphère."""
    xf = xf or F_sol
    c = (x, y, z0 + h + rr * 0.8)
    lot.put(M[surf], G.sphere(c, rr, 16, 9), xf)
    lot.put(M["cuivre"], G.tour([(c[2] - 0.03, rr * 1.015), (c[2] + 0.03, rr * 1.015)], 18, "z", (x, y, 0.0)), xf)
    lot.put(M["cuivre2"], G.tour([(c[2] + rr * 0.82, rr * 0.5), (c[2] + rr * 1.0, rr * 0.2), (c[2] + rr * 1.04, 0.0)], 12, "z", (x, y, 0.0)), xf)
    for k in range(3):
        a = G.TAU * k / 3 + 0.5
        p = (x + rr * 0.8 * math.cos(a), y + rr * 0.8 * math.sin(a), z0)
        q = (x + rr * 0.45 * math.cos(a), y + rr * 0.45 * math.sin(a), c[2] - rr * 0.72)
        lot.put(M["acier"], G.tube([p, q], 0.035, 6), xf)
        lot.put(M["pierre2"], G.boite((p[0], p[1], z0 + 0.03), (0.14, 0.14, 0.06)), xf)
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [(x + rr * 0.3, y - rr * 0.4, c[2] - rr * 0.75), (x + rr * 0.3, y - rr * 0.4, z0 + 0.12), (x + rr + 0.2, y - rr * 0.4, z0 + 0.12)],
            0.03, xf=xf)


def parvis(lot, M, r):
    xf = F_sol
    # réservoirs d'hélium 3 : 3 tailles, sud-ouest et sud-est
    _reservoir(lot, M, r, -6.05, -3.35, 0.3, 0.42, 0.22)
    _reservoir(lot, M, r, -5.1, -3.5, 0.3, 0.3, 0.16, "ceram2")
    _reservoir(lot, M, r, 4.75, -3.42, 0.36, 0.36, 0.2)
    _reservoir(lot, M, r, -6.3, 3.25, 0.42, 0.55, 0.3)
    _reservoir(lot, M, r, -4.9, 3.45, 0.42, 0.36, 0.18, "ceram2")
    # bobines de cuivre et transformateurs à isolateurs
    _bobine(lot, M, 6.4, -3.25, 0.36, 0.22, 1.05, rz=0.2)
    _bobine(lot, M, -7.2, 0.1, 0.22, 0.16, 0.8, rz=1.45)
    _bobine(lot, M, 2.75, -3.45, 0.14, 0.17, 0.75, rz=-0.1)
    for (x, y, z) in ((-3.1, -3.45, 0.14), (5.75, 2.9, 0.34)):
        lot.put(M["acier"], G.boite((x, y, z + 0.25), (0.66, 0.46, 0.5)), xf)
        for k in range(4):
            lot.put(M["ceram2"], G.boite((x - 0.3 + 0.2 * k, y, z + 0.25), (0.04, 0.5, 0.42)), xf)
        for k in range(3):
            xx = x - 0.21 + 0.21 * k
            lot.put(M["ceram"], G.tour([(z + 0.5, 0.05), (z + 0.55, 0.075), (z + 0.6, 0.05), (z + 0.65, 0.07), (z + 0.7, 0.045), (z + 0.75, 0.06),
                                         (z + 0.81, 0.02)], 10, "z", (xx, y, 0.0), cap0=True, cap1=True), xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (-3.3, -3.45, 0.95), (-5.1, -3.5, 0.95), 0.25, r, n=4, rouges=1, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (-2.9, -3.45, 0.95), (-1.4, -2.75, 1.1), 0.3, r, n=4, rouges=1, xf=xf)
    # tuyaux au sol sur 3 diamètres
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [(-5.8, -3.05, 0.45), (-4.3, -3.05, 0.45), (-4.3, -2.65, 0.45), (-3.6, -2.65, 0.45)], 0.085, xf=xf)
    R.tuyau(lot, M["acier"], M["cuivre2"], [(-7.65, -2.1, 0.34), (-7.65, -1.1, 0.34), (-7.65, -1.1, 0.85)], 0.05, xf=xf)
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [(7.6, -2.3, 0.5), (6.75, -2.25, 0.5), (6.75, -2.25, 1.0), (6.25, -2.25, 1.0)], 0.05, xf=xf)
    R.tuyau(lot, M["acier"], M["cuivre2"], [(3.5, -3.75, 0.25), (4.1, -3.72, 0.25), (4.1, -3.3, 0.25), (4.1, -3.3, 0.7)], 0.03, xf=xf)
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [(-3.2, 3.6, 0.36), (-1.2, 3.55, 0.36), (-1.2, 3.55, 0.9)], 0.05, xf=xf)
    R.tuyau(lot, M["acier"], M["cuivre2"], [(5.0, -3.15, 0.5), (5.0, -2.6, 0.5), (5.0, -2.6, 1.0)], 0.03, xf=xf)
    for (x, y, z, s, rz) in ((0.85, -3.72, 0.14, (0.4, 0.3, 0.3), 0.2), (1.28, -3.68, 0.14, (0.3, 0.28, 0.26), -0.4), (6.5, 3.55, 0.34, (0.38, 0.3, 0.3), 0.15),
                             (-3.6, 3.65, 0.42, (0.34, 0.3, 0.28), -0.3)):
        R.caisse(lot, M["bois"], M["acier"], (x, y, z), s, rz, xf=xf)
    for (x, y, z, c, rz) in ((1.9, -3.8, 0.14, False, 0), (2.1, -3.65, 0.14, False, 0), (5.45, -3.55, 0.36, True, 0.8), (-7.45, 2.9, 0.42, False, 0),
                             (-7.6, 1.5, 0.22, True, -0.4), (3.0, 3.6, 0.34, False, 0)):
        R.fut(lot, M["cuivre"] if x > 0 else M["acier"], M["cuivre2"], (x, y, z), 0.11, 0.3, couche=c, rz=rz, xf=xf)


# ------------------------------------------------------------------------------------------------ halle en arc, porte
def halle(lot, M, r):
    """Halle en ARC concentrique à la sphère : jamais une façade plane ; toit conique de cuivre, comble en retrait, piles et
    évents à pas inégal, la PORTE au milieu (invariant du centre) dans un avant-corps en proue."""
    xf = F_pal
    c = (HX, HY, 0.0)
    a0, a1 = math.radians(232), math.radians(308)
    R0, R1 = 3.05, 3.72
    z0, ze, zf = 0.12, 1.02, 1.52
    lot.put(M["ceram2"], G.tour([(z0, R1), (ze, R1 - 0.03), (ze, R0)], 40, "z", c, a0=a0, a1=a1), xf)
    lot.put(M["cuivre2"], G.tour([(ze - 0.04, R1 + 0.09), (ze + 0.03, R1 + 0.09), (ze + 0.03, R1 - 0.1)], 40, "z", c, a0=a0, a1=a1), xf)
    lot.put(M["toit"], G.tour([(ze + 0.03, R1 + 0.04), (zf, R0 + 0.06), (zf, R0)], 40, "z", c, a0=a0, a1=a1), xf)
    for s, a in ((-1, a0), (1, a1)):                                        # pignons des bouts
        ca, sa = math.cos(a), math.sin(a)
        p = [(HX + R0 * ca, HY + R0 * sa), (HX + R1 * ca, HY + R1 * sa)]
        v = [(p[0][0], p[0][1], z0), (p[1][0], p[1][1], z0), (p[1][0], p[1][1], ze + 0.03), (p[0][0], p[0][1], zf)]
        lot.put(M["ceram"], ([G.add(q, (0, 0, 0)) for q in v], [(0, 1, 2, 3)], [(q[0], q[2]) for q in v]), xf)
    # piles et creux à pas inégal le long de l'arc
    deg = [234, 241, 247, 256, 263, 277, 283, 291, 297, 306]
    for i, d in enumerate(deg):
        a = math.radians(d)
        p = (HX + (R1 + 0.04) * math.cos(a), HY + (R1 + 0.04) * math.sin(a))
        w = 0.12 + 0.05 * (i % 3)
        lot.put(M["ceram"], G.boite((p[0], p[1], (z0 + ze) / 2), (0.08, w, ze - z0 + 0.04), rz=a), xf)
    formes = [(238, "octo", 0.1, True), (244, "fente", 0.07, False), (251.5, "ogive", 0.11, True), (287, "rond", 0.09, False), (294, "losange", 0.09, True), (301, "double", 0.09, False)]
    for d, f, t, lit in formes:
        a = math.radians(d)
        n = (math.cos(a), math.sin(a), 0.0)
        p = (HX + (R1 - 0.02) * n[0], HY + (R1 - 0.02) * n[1], z0 + 0.5 + 0.08 * math.sin(d))
        R.hublot(lot, M["cuivre2"], M["lum"] if lit else M["verre"], p, n, f, t, xf=xf)
    for d in (249, 299):
        a = math.radians(d)
        n = (math.cos(a), math.sin(a), 0.0)
        R.grille(lot, M["cuivre2"], M["noyau"], (HX + R1 * n[0], HY + R1 * n[1], z0 + 0.22), n, 0.42, 0.14, 4, xf=xf)
    for d, z1, h in ((240, 1.28, 0.3), (258, 1.42, 0.26), (292, 1.36, 0.42)):                # lucarnes, évents de toit, cheminée
        a = math.radians(d)
        q = (HX + (R0 + 0.3) * math.cos(a), HY + (R0 + 0.3) * math.sin(a))
        lot.put(M["ceram2"], G.boite((q[0], q[1], z1 + h / 2), (0.22, 0.2, h), rz=a))
        lot.put(M["cuivre2"], G.prisme(E.rect(q[0], q[1], 0.15, 0.14), z1 + h, z1 + h + 0.1, top_scale=0.3), xf)
    # avant-corps de la porte (proue, plan en pointe)
    a = math.radians(270)
    gx, gy = HX, HY + R1 * math.sin(a)
    poly = [(gx - 0.85, gy + 0.1), (gx + 0.85, gy + 0.1), (gx + 0.62, gy - 0.48), (gx, gy - 0.7), (gx - 0.62, gy - 0.48)]
    lot.put(M["ceram"], G.prisme(poly, z0, 1.42, top_scale=0.97), xf)
    lot.put(M["cuivre"], G.prisme(E.sc(poly, 1.06), 1.42, 1.5, top_scale=1.0), xf)
    lot.put(M["toit"], G.prisme(E.sc(poly, 1.0), 1.5, 2.02, top_scale=0.3), xf)
    lot.put(M["cuivre"], G.tour([(2.0, 0.05), (2.3, 0.012)], 8, "z", (gx, gy - 0.22, 0.0), cap0=True), xf)
    # baie en plein cintre sur la face sud-ouest du pan coupé : noir, archivolte, seuil
    bx, by = gx, gy - 0.72
    lot.put(M["cuivre"], G.tour([(by - 0.02, 0.56), (by + 0.04, 0.56), (by + 0.04, 0.42), (by - 0.02, 0.42)], 24, "y", (bx, 0.0, 0.62), a0=-math.pi / 2, a1=math.pi / 2), xf)
    lot.put(M["noyau"], G.tour([(by + 0.01, 0.42), (by + 0.02, 0.0)], 24, "y", (bx, 0.0, 0.62), a0=-math.pi / 2, a1=math.pi / 2), xf)
    lot.put(M["noyau"], G.boite((bx, by + 0.03, 0.37), (0.84, 0.03, 0.5)), xf)
    lot.put(M["lum"], G.tour([(by - 0.03, 0.44), (by - 0.02, 0.44), (by - 0.02, 0.41), (by - 0.03, 0.41)], 20, "y", (bx, 0.0, 0.62), a0=-math.pi / 2, a1=math.pi / 2), xf)
    for s in (-1, 1):
        lot.put(M["ceram2"], G.boite((bx + s * 0.54, by + 0.03, 0.42), (0.16, 0.12, 0.72)), xf)
        lot.put(M["acier"], G.boite((bx + s * 0.27, by + 0.15, 0.4), (0.04, 0.3, 0.55), rz=s * 0.5), xf)
    for k in range(3):
        lot.put(M["pierre"], G.boite((bx, by - 0.2 - 0.14 * k, 0.1 - 0.03 * k), (1.15 + 0.2 * k, 0.16, 0.08)), xf)
    R.hublot(lot, M["cuivre2"], M["hublot"], (gx - 0.5, gy - 0.55, 1.1), (-0.5, -0.86, 0.0), "rond", 0.07, xf=xf)
    # échafaudage et tuyaux du flanc
    R.echafaudage(lot, M["acier"], M["bois"], HX + 1.5, HX + 2.15, -3.72, -3.5, 0.14, 1.6, 3, xf=xf)
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [(HX - 2.5, -2.3, 1.15), (HX - 3.0, -2.3, 1.15), (HX - 3.0, -2.0, 1.5)], 0.05, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (HX - 0.8, -3.1, 1.25), (HX + 0.8, -3.1, 1.2), 0.2, r, n=3, rouges=1, xf=xf)


# ------------------------------------------------------------------------------------------------ cage et cœur
def squelette(lot, M, r):
    """Côtes de céramique (os) inclinées vers la queue « (((( », épine à vertèbres, plancher et machines dans la cage."""
    xf = F_nav
    zt = ZS + 1.4
    prof = [(-1.5, 0.12), (-1.72, 0.7), (-1.62, ZS), (-1.2, ZS + 0.85), (-0.55, zt - 0.05), (0.0, zt)]
    b = 0.75
    for i, xt in enumerate((-2.15, -0.95, 0.3, 1.45, 2.65)):
        pts = []
        for y, z in prof + [(-y, z) for y, z in reversed(prof[:-1])]:
            s = z / zt
            pts.append((xt - b * (1.0 - s), y * (0.96 + 0.03 * math.sin(i * 2.1)), z))
        lot.put(M["ceram"], G.tube(G.catmull(pts, 4), 0.085 - 0.01 * (i % 2), 8), xf)
        for y in (-1.5, 1.5):
            lot.put(M["cuivre2"], G.boite((xt - b, y, 0.16), (0.28, 0.24, 0.26)), xf)
        lot.put(M["cuivre"], G.tour([(-0.07, 0.11), (0.07, 0.11)], 10, "y", (xt, 0.0, zt)), xf)
    ep = G.catmull([(-3.7, 0.0, ZS + 0.85), (-2.6, 0.0, zt), (2.7, 0.0, zt), (3.6, 0.0, ZS + 1.1)], 10)
    lot.put(M["ceram"], G.tube(ep, 0.12, 10), xf)
    acc = 0.0
    for i in range(1, len(ep)):
        acc += G.length(G.sub(ep[i], ep[i - 1]))
        if acc > 0.36 + r.f(0, 0.1):
            acc = 0.0
            p = ep[i]
            lot.put(M["acier"], G.boite(p, (0.14, 0.27, 0.23)), xf)
            lot.put(M["cuivre2"], G.prisme([(p[0] - 0.12, p[1] - 0.03), (p[0] + 0.1, p[1] - 0.03), (p[0] + 0.02, p[1] + 0.03), (p[0] - 0.08, p[1] + 0.03)],
                                           p[2] + 0.1, p[2] + 0.3 + r.f(0, 0.12), top_scale=0.2, top_shift=(-0.1, 0.0)), xf)
    # le FUSELAGE, continu entre le cœur et le crâne (critique du 1/11) : voûte de tôles jaunes et de céramique sous les côtes,
    # une brèche au sud sur les machines
    def sf(x, a, g=0.0):
        k = 1.0 - 0.1 * ((x - 0.3) / 3.0) ** 2
        return (x, (1.44 * k + g) * math.cos(a), ZS - 0.12 + (1.3 * k + g) * math.sin(a))

    def x_(x0, x1, n):
        return [x0 + (x1 - x0) * i / float(n) for i in range(n + 1)]
    lot.put(M["noyau"], N.coque(sf, x_(-2.62, 0.2, 12), 28, a0=0.0, a1=math.pi), xf)
    lot.put(M["noyau"], N.coque(sf, x_(0.2, 1.65, 7), 20, a0=0.0, a1=2.3), xf)
    lot.put(M["noyau"], N.coque(sf, x_(1.65, 3.3, 8), 28, a0=0.0, a1=math.pi), xf)

    def saut_v(xm, am):
        return 0.2 < xm < 1.65 and am > 2.3

    def mats_v(rr, bi, i):
        x = rr.f()
        if x < 0.5:
            return M["jaune"]
        if x < 0.72:
            return M["jaune2"]
        return M["ceram_b"] if x < 0.9 else M["ceram2"]
    N.blinde(lot, sf, [-2.62, -2.05, -1.42, -0.95, -0.3, 0.2, 0.92, 1.65, 2.25, 2.75, 3.3], [(0.0, 0.34), (0.34, 0.72), (0.72, 1.06), (1.06, 1.44), (1.44, 1.8), (1.8, 2.18), (2.18, 2.58), (2.58, 2.88), (2.88, 3.14)],
             mats_v, r, xf, saut=saut_v, Mriv=M["riv"])
    for (x, a, f, t, lit) in ((-1.95, 2.25, "ogive", 0.1, True), (-0.65, 2.45, "rond", 0.08, False), (2.3, 2.3, "octo", 0.09, True), (2.95, 2.05, "fente", 0.07, False)):
        p = sf(x, a, 0.06)
        R.hublot(lot, M["cuivre2"], M["lum"] if lit else M["verre"], p, G.norm(G.sub(sf(x, a, 0.5), p)), f, t, xf=xf)
    for (x, a, w) in ((-1.25, 1.75, 0.46), (2.55, 1.6, 0.46), (-0.2, 2.55, 0.38)):
        p = sf(x, a, 0.07)
        R.grille(lot, M["cuivre2"], M["noyau"], p, G.norm(G.sub(sf(x, a, 0.5), p)), w, w * 0.45, 5, xf=xf)
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [sf(-2.3, 2.1, 0.1), sf(-0.9, 2.1, 0.1), sf(-0.45, 1.8, 0.1)], 0.045, xf=xf)
    R.tuyau(lot, M["acier"], M["cuivre2"], [sf(1.8, 1.8, 0.1), sf(3.0, 1.9, 0.1)], 0.03, xf=xf)
    # plancher et machines dans la cage : cuves, pompes, tuyaux
    lot.put(M["noyau"], G.prisme([(-3.1, -1.1), (-2.4, -1.3), (1.7, -1.25), (3.0, -0.8), (3.0, 1.0), (-3.1, 1.2)], 0.06, 0.28), xf)
    for k in range(9):                                              # caillebotis du plancher, irréguliers
        x0 = -2.9 + 0.64 * k + r.f(-0.1, 0.1)
        lot.put(M["acier"], G.boite((x0, r.f(-0.5, 0.2), 0.3), (r.f(0.32, 0.56), r.f(0.9, 1.5), 0.03), r.f(-0.04, 0.04)), xf)
    # bas de ventre encore bordé (tôles jaunes et céramique sous les côtes), collecteur le long de l'axe
    sv = (lambda x, a, g=0.0: (x, (1.58 + g) * math.cos(a), ZS - 0.1 + (1.42 + g) * math.sin(a)))
    N.blinde(lot, sv, [-2.75, -2.25, -1.55, -1.1, -0.35, 0.05, 0.75, 1.3, 1.95, 2.8], [(3.72, 3.98), (3.98, 4.22), (4.22, 4.5)],
             lambda rr, bi, i: M["jaune"] if rr.f() < 0.4 else (M["jaune2"] if rr.f() < 0.4 else (M["ceram2"] if rr.f() < 0.7 else M["ceram3"])), r, xf, Mriv=M["riv"])
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [(-2.75, -0.15, 0.62), (1.0, -0.1, 0.62), (2.7, -0.2, 0.62)], 0.13, xf=xf)
    for (x, s_) in ((-2.0, 0.2), (-0.7, 0.26), (0.6, 0.18), (1.9, 0.24)):
        lot.put(M["ceram3"], G.boite((x, -0.1, 0.48), (s_, 0.5, 0.42)), xf)
    for (x, y, rr, h) in ((-1.4, -0.75, 0.3, 0.9), (0.1, -0.85, 0.24, 1.15), (1.1, -0.7, 0.34, 0.8), (2.2, -0.8, 0.22, 1.0), (-0.5, 0.7, 0.3, 1.1), (1.6, 0.8, 0.28, 1.0)):
        lot.put(M["cuivre"] if x < 0 else M["ceram2"], G.tour([(0.34, rr), (0.34 + h, rr), (0.34 + h + 0.1, rr * 0.7), (0.34 + h + 0.14, 0.0)], 14, "z", (x, y, 0.0), cap0=True), xf)
        lot.put(M["cuivre2"], G.tour([(0.34 + h * 0.5, rr + 0.012), (0.34 + h * 0.5 + 0.05, rr + 0.012)], 14, "z", (x, y, 0.0)), xf)
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [(-1.1, -0.75, 0.75), (-0.2, -0.75, 0.75), (-0.2, -0.85, 1.25), (0.2, -0.85, 1.25)], 0.05, xf=xf)
    R.tuyau(lot, M["acier"], M["cuivre2"], [(0.4, -0.85, 0.6), (0.8, -0.8, 0.6)], 0.085, xf=xf)
    R.tuyau(lot, M["acier"], M["cuivre2"], [(1.4, -0.7, 0.55), (2.0, -0.75, 0.55), (2.0, -0.75, 1.2)], 0.03, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (-1.9, -1.3, ZS + 0.3), (-0.6, -1.3, ZS + 0.25), 0.4, r, n=5, rouges=2, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (0.6, -1.25, ZS + 0.5), (2.0, -1.2, ZS + 0.3), 0.45, r, n=4, rouges=1, xf=xf)
    R.flexible(lot, M["caoutchouc"], M["cuivre2"], [(-0.9, -1.05, 1.0), (-0.5, -1.45, 0.75), (-0.1, -1.1, 0.5)], 0.05, xf=xf)
    R.flexible(lot, M["caoutchouc"], M["cuivre2"], [(1.2, -1.05, 1.1), (1.5, -1.45, 0.75), (2.1, -1.05, 0.5)], 0.045, xf=xf)


def cryostat(lot, M, r):
    """Colonne sous la sphère, de la cage à son pôle sud : étages cerclés, flexibles qui pendent dans le vide."""
    xf = F_pal
    z0, z1 = ZS + 0.75, ZC - RS + 0.1
    lot.put(M["ceram2"], G.tour([(z0, 0.46), (z0 + 0.2, 0.42), (z0 + 0.25, 0.3), (z1 - 0.15, 0.3), (z1, 0.62)], 18, "z", (CX, CY, 0.0), cap0=True, cap1=True), xf)
    for t in (0.2, 0.4, 0.62, 0.8):
        z = z0 + (z1 - z0) * t
        lot.put(M["cuivre"], G.tour([(z - 0.05, 0.36), (z + 0.05, 0.36)], 18, "z", (CX, CY, 0.0), cap0=True, cap1=True), xf)
    lot.put(M["noyau"], G.tour([(z0 + 0.35, 0.31), (z1 - 0.25, 0.31)], 18, "z", (CX, CY, 0.0), a0=math.radians(245), a1=math.radians(265)), xf)
    for (a, Rp, zb, m) in ((3.5, 1.05, 0.75, "caoutchouc"), (4.2, 1.2, 1.05, "caoutchouc"), (5.0, 0.95, 0.7, "caoutchouc"), (5.8, 1.1, 0.95, "caoutchouc")):
        p0 = (CX + 0.32 * math.cos(a), CY + 0.32 * math.sin(a), z1 - 0.15)
        p3 = (CX + Rp * 1.5 * math.cos(a), CY + Rp * 1.5 * math.sin(a), ZC - RS * 0.62)
        m1 = (CX + Rp * 0.75 * math.cos(a), CY + Rp * 0.75 * math.sin(a), z1 - zb)
        m2 = (CX + Rp * 1.35 * math.cos(a), CY + Rp * 1.35 * math.sin(a), z1 - zb * 0.8)
        R.flexible(lot, M[m], M["cuivre2"], [p0, m1, m2, p3], 0.05, xf=xf)
    # conduits de transfert du cœur à la colonne
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [(-2.3, -0.5, ZS + 0.6), (-1.0, -0.5, ZS + 0.6), (-1.0, 0.35, ZS + 1.5), (CX - 0.4, 0.35, ZS + 1.5)], 0.085, xf=xf)
    R.tuyau(lot, M["acier"], M["cuivre2"], [(-2.2, 0.5, ZS + 0.7), (-0.6, 0.8, ZS + 0.9), (-0.6, 0.8, ZS + 1.75), (CX - 0.3, 0.7, ZS + 1.75)], 0.05, xf=xf)


# ------------------------------------------------------------------------------------------------ sphère, tore, trépied
def sphere(lot, M, r):
    xf = F_pal
    c = (CX, CY, ZC)
    surf = E.sph_pt(c, RS)
    lot.put(M["ceram_j"], G.sphere(c, RS - 0.012, 40, 20), xf)
    d = math.radians

    def saut(la, lo):
        lo = lo % G.TAU
        if abs(la - 0.08) < 0.11:                                 # ceinture équatoriale
            return True
        if d(52) < la and abs((lo - d(250)) % G.TAU) < 0.5:      # trappe de chantier du dessus : mécanique à nu
            return False
        return la > d(72)

    def mats(rr, la, lo):                                          # contraste réduit de moitié : aucune tuile noire
        x = rr.f()
        if x < 0.03:
            return M["cuivre"]
        return M["ceram"] if x < 0.62 else (M["ceram_b"] if x < 0.9 else M["ceram2"])
    lats = [d(x) for x in (-76, -62, -49, -36, -23, -10, -2, 12, 24, 36, 48, 60, 74)]
    E.tuiles_sphere(lot, surf, lats, 0.38, mats, r, xf, gap=0.014, g=(0.006, 0.02), saut=saut)
    # ceinture de cuivre, calotte, méridiens à pas inégal, colliers
    z = ZC + RS * math.sin(0.08)
    rb = RS * math.cos(0.08)
    lot.put(M["cuivre"], G.tour([(z - 0.15, rb + 0.0), (z - 0.1, rb + 0.06), (z + 0.1, rb + 0.06), (z + 0.15, rb + 0.0)], 56, "z", (CX, CY, 0.0)), xf)
    lot.put(M["cuivre2"], G.tour([(z - 0.03, rb + 0.08), (z + 0.03, rb + 0.08)], 56, "z", (CX, CY, 0.0)), xf)
    for lo in (205, 252, 296, 340):
        a = d(lo)
        pts = [surf(d(-70 + 6.0 * k), a, 0.05) for k in range(25)]
        lot.put(M["cuivre"] if lo % 2 else M["cuivre2"], G.tube(pts, 0.04 + 0.012 * (lo % 3), 6), xf)
        for la in (-44, -18, 30, 56):
            q = surf(d(la + (lo % 7)), a, 0.08)
            lot.put(M["acier"], G.boite(q, (0.13, 0.13, 0.13)), xf)
    for k in range(34):                                            # petites pièces sur les tuiles (3 à 8 px)
        la, lo = d(r.f(-60, 62)), d(r.f(195, 345))
        q = surf(la, lo, 0.05)
        lot.put([M["ceram2"], M["cuivre2"], M["ceram_b"]][k % 3], G.oriente(G.boite((0, 0, 0), (r.f(0.05, 0.13), r.f(0.04, 0.1), 0.04)), q, G.norm(G.sub(q, c))), xf)
    # calotte du sommet, étagée
    zp = ZC + RS * math.sin(d(72))
    rp = RS * math.cos(d(72))
    lot.put(M["cuivre"], G.tour([(zp - 0.05, rp + 0.08), (zp + 0.1, rp + 0.08), (zp + 0.24, rp * 0.78), (zp + 0.32, rp * 0.72), (zp + 0.46, rp * 0.45)], 28, "z", (CX, CY, 0.0), cap1=True), xf)
    # hublots de contrôle orange (le cœur se voit par 2 hublots), trappes, grilles, échelle
    for (la, lo, t) in ((26, 238, 0.17), (34, 292, 0.12)):
        p = surf(d(la), d(lo), 0.03)
        n = G.norm(G.sub(p, c))
        lot.put(M["cuivre2"], G.oriente(G.tour([(0.0, t * 1.6), (0.05, t * 1.5), (0.09, t * 1.2), (0.05, t * 1.05), (0.03, t)], 18, "z"), p, n), xf)
        lot.put(M["hublot"], G.oriente(G.tour([(0.03, t), (0.06 + t * 0.3, t * 0.72), (0.05 + t * 0.55, 0.0)], 18, "z"), p, n), xf)
    for (la, lo, f, t, lit) in ((-24, 262, "fente", 0.08, True), (46, 215, "octo", 0.09, False), (-38, 300, "carre", 0.07, False), (20, 330, "double", 0.08, True),
                                (57, 262, "losange", 0.08, False), (-14, 212, "demi", 0.1, True)):
        p = surf(d(la), d(lo), 0.05)
        R.hublot(lot, M["cuivre2"], M["lum"] if lit else M["verre"], p, G.norm(G.sub(p, c)), f, t, xf=xf)
    for (la, lo, w) in ((-52, 250, 0.44), (42, 262, 0.38), (-30, 225, 0.3), (-42, 320, 0.36), (52, 305, 0.3)):
        p = surf(d(la), d(lo), 0.06)
        R.grille(lot, M["cuivre2"], M["noyau"], p, G.norm(G.sub(p, c)), w, w * 0.5, 5, xf=xf)
    pts = [surf(d(-10 + 6.0 * k), d(272), 0.11) for k in range(13)]
    q = [surf(d(-10 + 6.0 * k), d(278), 0.11) for k in range(13)]
    lot.put(M["acier"], G.tube(pts, 0.012, 4), xf)
    lot.put(M["acier"], G.tube(q, 0.012, 4), xf)
    for a, b in zip(pts, q):
        lot.put(M["acier"], G.tube([a, b], 0.009, 4), xf)
    # faisceaux et tuyaux plaqués (jamais propres)
    R.faisceau(lot, M["cable_r"], M["cable_n"], surf(d(38), d(205), 0.1), surf(d(14), d(250), 0.1), 0.26, r, n=4, rouges=1, xf=xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], surf(d(24), d(300), 0.1), surf(d(52), d(345), 0.1), 0.22, r, n=3, rouges=1, xf=xf)
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [surf(d(-36), d(205), 0.12), surf(d(-28), d(244), 0.12), surf(d(-40), d(264), 0.12)], 0.045, xf=xf)
    R.tuyau(lot, M["acier"], M["cuivre2"], [surf(d(48), d(235), 0.1), surf(d(58), d(285), 0.1)], 0.03, xf=xf)
    # échafaudage et grue de chantier sur le dos de la sphère (dépassement, jamais fini)
    R.echafaudage(lot, M["acier"], M["bois"], CX - 1.02, CX - 0.48, CY - 0.92, CY - 0.72, ZC + 0.38, ZC + 1.2, 3, xf=xf)


def _arc(R0, z, a0, a1, n=8):
    return [(CX + R0 * math.cos(a0 + (a1 - a0) * i / n), CY + R0 * math.sin(a0 + (a1 - a0) * i / n), z) for i in range(n + 1)]


def tore(lot, M, r):
    """TORE SEGMENTÉ (critique du 1/11, sur le modèle du Portique) : tube de plasma en retrait, à cœur clair et bord sombre, vu par
    10 fenêtres ; entre elles, de grosses bobines de céramique à brides de cuivre, pions sur une sur deux, couronne de maintien."""
    xf = F_pal
    c = (CX, CY, ZT)
    nb = 10
    da = 0.066                                                      # demi-fenêtre : 0,36 tuile de plasma visible
    decal = [0.0, 0.03, -0.02, 0.02, 0.0, -0.03, 0.02, 0.0, -0.02, 0.03]
    fen = [G.TAU * (k + 0.5) / nb + decal[k] for k in range(nb)]
    lot.put(M["plasma"], E.anneau(c, RT, RP, 0.0, G.TAU, 140, 14), xf)
    for k in range(nb):
        a0, a1 = fen[k] + da, fen[(k + 1) % nb] - da + (G.TAU if k == nb - 1 else 0.0)
        am = (a0 + a1) / 2
        # bobine : manchon, deux tons selon le rang, sangle, bride de cuivre à chaque bout
        lot.put(M["ceram_b"] if k % 3 else M["ceram2"], E.anneau(c, RT, RB, a0 + 0.02, a1 - 0.02, 16, 18), xf)
        for s_ in (a0 + 0.015, a1 - 0.015):
            lot.put(M["cuivre"], E.anneau(c, RT, RB + 0.045, s_ - 0.012, s_ + 0.012, 2, 18), xf)
        for t in (0.3, 0.62) if k % 2 else (0.5,):
            b = a0 + (a1 - a0) * t
            lot.put(M["cuivre2"], E.anneau(c, RT, RB + 0.02, b - 0.016, b + 0.016, 2, 18), xf)
        # boîte extérieure, plaques rapportées et conduit le long de la bobine
        u = (math.cos(am), math.sin(am))
        lot.put(M["ceram3"], G.boite((CX + (RT + RB + 0.02) * u[0], CY + (RT + RB + 0.02) * u[1], ZT), (0.12, 0.42, 0.3), rz=am), xf)
        for j in range(9):
            b = r.f(a0 + 0.04, a1 - 0.04)
            ang = r.f(-0.6, 1.5)
            rr = RT + (RB + 0.012) * math.cos(ang)
            q = (CX + rr * math.cos(b), CY + rr * math.sin(b), ZT + (RB + 0.012) * math.sin(ang))
            nn = G.norm((math.cos(ang) * math.cos(b), math.cos(ang) * math.sin(b), math.sin(ang)))
            lot.put([M["acier"], M["cuivre2"], M["ceram2"], M["ceram_b"]][j % 4], G.oriente(G.boite((0, 0, 0), (r.f(0.08, 0.26), r.f(0.06, 0.16), 0.025)), q, nn), xf)
        if k % 2 == 0:
            q = (CX + RT * u[0], CY + RT * u[1], ZT + RB - 0.03)
            lot.put(M["cuivre"], G.tour([(q[2], 0.17), (q[2] + 0.06, 0.15), (q[2] + 0.34, 0.09), (q[2] + 0.42, 0.13), (q[2] + 0.48, 0.0)], 12, "z", (q[0], q[1], 0.0), cap0=True), xf)
        p0 = (CX + (RT + RB + 0.06) * math.cos(a0 + 0.08), CY + (RT + RB + 0.06) * math.sin(a0 + 0.08), ZT + 0.2)
        p1 = (CX + (RT + RB + 0.06) * math.cos(a1 - 0.08), CY + (RT + RB + 0.06) * math.sin(a1 - 0.08), ZT + 0.2)
        pm = (CX + (RT + RB + 0.1) * math.cos(am), CY + (RT + RB + 0.1) * math.sin(am), ZT + 0.2)
        if k % 2:
            R.tuyau(lot, M["acier"] if k % 4 == 1 else M["cuivre"], M["cuivre2"], [p0, pm, p1], 0.03, xf=xf)
        # bras de la sphère à la bobine, sous le plasma
        q0 = (CX + (RS * 0.98) * u[0], CY + (RS * 0.98) * u[1], ZT - 0.05)
        q1 = (CX + (RT - RB + 0.05) * u[0], CY + (RT - RB + 0.05) * u[1], ZT - 0.05)
        if k % 2 == 0:
            lot.put(M["ceram2"], G.boite(G.lerp(q0, q1, 0.5), (G.length(G.sub(q1, q0)), 0.14, 0.16), rz=am), xf)
            lot.put(M["acier"], G.tube([G.add(q0, (0, 0, 0.12)), G.add(q1, (0, 0, 0.12))], 0.025, 6), xf)
    R.compte("bobines_d", nb)
    # couronne de maintien, attaches, faisceaux en festons, passerelle sous le tore
    Rc = RT + RB + 0.22
    lot.put(M["acier"], E.anneau(c, Rc, 0.032, 0.0, G.TAU, 120, 6), xf)
    for k in range(nb):
        a = fen[k] + 0.3
        lot.put(M["acier"], G.tube([(CX + (RT + RB) * math.cos(a), CY + (RT + RB) * math.sin(a), ZT), (CX + Rc * math.cos(a), CY + Rc * math.sin(a), ZT)], 0.018, 5), xf)
    for (a0, a1) in ((math.radians(208), math.radians(245)), (math.radians(258), math.radians(292)), (math.radians(302), math.radians(335))):
        p = (CX + (RT + 0.3) * math.cos(a0), CY + (RT + 0.3) * math.sin(a0), ZT - RB + 0.05)
        q = (CX + (RT + 0.3) * math.cos(a1), CY + (RT + 0.3) * math.sin(a1), ZT - RB + 0.05)
        R.faisceau(lot, M["cable_r"], M["cable_n"], p, q, 0.34, r, n=3, rouges=1, xf=xf)
    zp = ZT - RB - 0.1
    R.garde_corps(lot, M["cuivre2"], _arc(RT + 0.2, zp, math.radians(248), math.radians(290), 5), h=0.22, xf=xf)
    lot.put(M["acier"], G.tour([(zp - 0.04, RT + 0.32), (zp, RT + 0.32), (zp, RT - 0.1), (zp - 0.04, RT - 0.1)], 12, "z", (CX, CY, 0.0), a0=math.radians(248), a1=math.radians(290)), xf)


JAMBES = [(math.radians(208), (-4.45, -2.95)), (math.radians(332), (2.95, -2.85)), (math.radians(92), (-0.95, 3.5))]


def trepied(lot, M, r):
    """Trois jambes télescopiques massives (fourreau de céramique, tige d'acier, colliers de cuivre), sabots à griffes,
    vérin d'appoint, faisceau. Elles enjambent le vaisseau."""
    xf = F_pal
    old = lot.xf
    lot.xf = xf
    for (a, pied) in JAMBES:
        hd = (CX + (RT - 0.1) * math.cos(a), CY + (RT - 0.1) * math.sin(a), ZT - RB + 0.06)
        p = (pied[0], pied[1], 0.32)
        E.jambe(lot, M["ceram2"], M["acier"], M["cuivre"], M["cuivre2"], p, hd, 0.27, 0.15)
        lot.put(M["pierre2"], G.prisme(E.rect(pied[0], pied[1], 0.66, 0.55), 0.0, 0.14, top_scale=0.9), xf)
        lot.put(M["cuivre2"], G.prisme(E.rect(pied[0], pied[1], 0.5, 0.42), 0.14, 0.36, top_scale=0.72), xf)
        for k in range(4):                                         # griffes d'ancrage
            b = 0.7 + G.TAU * k / 4
            q = (pied[0] + 0.5 * math.cos(b), pied[1] + 0.42 * math.sin(b))
            lot.put(M["acier"], G.prisme(E.rect(q[0], q[1], 0.08), 0.14, 0.23, top_scale=0.5), xf)
        # plaques, boîtes de jonction et conduit plaqués sur le fourreau (jamais une colonne lisse)
        du = G.norm(G.sub(hd, p))
        nn = G.norm(G.cross(du, (0.0, 0.0, 1.0)))
        if nn[1] > 0:
            nn = G.mul(nn, -1.0)
        for k in range(22):
            t = r.f(0.06, 0.6)
            ang = r.f(-1.2, 1.2)
            bb = G.cross(du, nn)
            q = G.add(G.add(G.lerp(p, hd, t), G.mul(nn, 0.27 * math.cos(ang))), G.mul(bb, 0.27 * math.sin(ang)))
            lot.put([M["acier"], M["ceram3"], M["cuivre2"], M["ceram"]][k % 4], G.oriente(G.boite((0, 0, 0), (r.f(0.06, 0.17), r.f(0.06, 0.28), 0.03)), q, G.add(G.mul(nn, math.cos(ang)), G.mul(bb, math.sin(ang)))), xf)
        q0, q1 = G.add(G.lerp(p, hd, 0.08), G.mul(nn, 0.3)), G.add(G.lerp(p, hd, 0.6), G.mul(nn, 0.28))
        R.tuyau(lot, M["cuivre"], M["cuivre2"], [q0, q1], 0.03, xf=xf)
        # vérin d'appoint et flexible d'énergie
        hd2 = G.lerp(p, hd, 0.5)
        base = (pied[0] + 0.55 * (0.9 if pied[0] < 0 else -0.9), pied[1] + 0.35, 0.3)
        lot.put(M["acier"], G.tube([base, G.lerp(base, hd2, 0.55)], 0.055, 8), xf)
        lot.put(M["cuivre"], G.tube([G.lerp(base, hd2, 0.5), hd2], 0.03, 8), xf)
        R.flexible(lot, M["caoutchouc"], M["cuivre2"], [(pied[0] + 0.3, pied[1] - 0.3, 0.3), G.add(G.lerp(p, hd, 0.3), (0.34, -0.18, -0.16)), G.add(G.lerp(p, hd, 0.68), (0.28, -0.14, -0.06))],
                   0.05, xf=xf)
        R.faisceau(lot, M["cable_r"], M["cable_n"], G.add(G.lerp(p, hd, 0.45), (-0.2, -0.3, 0.0)), G.add(G.lerp(p, hd, 0.85), (-0.2, -0.25, 0.0)), 0.3, r, n=3, rouges=1, xf=xf)
    lot.xf = old


def fleche(lot, M, r):
    """La flèche de commandement (une seule) : le point le plus haut, cousine de la flèche maîtresse de l'âge 15."""
    xf = F_pal
    z0 = ZC + RS * math.sin(math.radians(72)) + 0.42
    pt = R.fleche(lot, M["ceram2"], M["cuivre"], M["ceram"], M["verre"], M["cuivre2"], (CX, CY), z0, 1.85, 0.24, r, 3, xf=xf, Mlum=M["lum"])
    R.mat_antenne(lot, M["cuivre2"], M["acier"], M["balise"], pt, 0.5, r, xf=xf)
    R.mat_antenne(lot, M["cuivre2"], M["acier"], M["balise"], (CX + 0.6, CY + 0.2, ZC + RS * 0.82), 0.7, r, xf=xf, lum=False)
    R.mat_antenne(lot, M["cuivre2"], M["acier"], None, (CX - 0.62, CY + 0.25, ZC + RS * 0.82), 0.45, r, xf=xf, lum=False)


def injecteurs(lot, M, r):
    """Boîte d'injection ouest sur tréteau (dépassement), radiateurs derrière le crâne."""
    xf = F_pal
    # boîte d'injection ouest, à l'arrière du vaisseau : tambour couché à bobines, sur tréteau, ligne de faisceau vers le tore
    bx, by, bz = -5.45, 2.65, 3.45
    a = math.radians(160)
    hd = (CX + (RT + RB) * math.cos(a), CY + (RT + RB) * math.sin(a), ZT - 0.05)
    dd = (math.cos(0.3), math.sin(0.3), 0.0)
    p_ = G.add((bx, by, bz), G.mul(dd, -0.85))
    lot.put(M["ceram2"], G.oriente(G.tour([(0.0, 0.2), (0.06, 0.42), (0.16, 0.46), (0.5, 0.46), (0.55, 0.52), (0.72, 0.52), (0.78, 0.46), (1.25, 0.46), (1.3, 0.52), (1.42, 0.52), (1.5, 0.4),
                                           (1.7, 0.2)], 20, "z", cap0=True, cap1=True), p_, dd), xf)
    for t in (0.22, 0.32, 0.42, 0.88, 0.98, 1.08):
        lot.put(M["cuivre"], G.oriente(G.tour([(-0.035, 0.49), (0.035, 0.49)], 20, "z", cap0=True, cap1=True), G.add(p_, G.mul(dd, t)), dd), xf)
    R.grille(lot, M["cuivre2"], M["noyau"], (bx + 0.1, by - 0.5, bz + 0.1), (0.15, -1, 0.35), 0.5, 0.2, 5, xf=xf)
    p0 = G.add(p_, G.mul(dd, 1.68))
    d = G.norm(G.sub(hd, p0))
    L = G.length(G.sub(hd, p0))
    lot.put(M["ceram"], G.oriente(G.tour([(0.0, 0.2), (0.2, 0.17), (L * 0.5, 0.14), (L * 0.54, 0.2), (L * 0.62, 0.2), (L * 0.66, 0.13), (L, 0.12)], 16, "z", cap0=True, cap1=True), p0, d), xf)
    for s in (-1, 1):                                              # tréteau
        for t in (-1, 1):
            lot.put(M["acier"], G.tube([(bx + s * 0.75, by + t * 0.72, 0.42), (bx + s * 0.35, by + t * 0.22, bz - 0.4)], 0.05, 8), xf)
    lot.put(M["acier"], G.tube([(bx - 0.75, by - 0.72, 1.5), (bx + 0.75, by - 0.72, 2.1)], 0.03, 6), xf)
    lot.put(M["acier"], G.tube([(bx + 0.75, by - 0.72, 1.5), (bx - 0.75, by - 0.72, 2.1)], 0.03, 6), xf)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (bx - 0.3, by - 0.42, bz - 0.4), (bx + 0.5, by - 0.5, 0.6), 0.3, r, n=4, rouges=2, xf=xf)
    R.mat_antenne(lot, M["cuivre2"], M["acier"], M["balise"], (bx - 0.45, by, bz + 0.45), 0.7, r, xf=xf)
    # radiateurs en persiennes derrière le crâne : plaques de céramique de hauteurs inégales, faces au soleil, caloducs de cuivre
    rz = 0.62
    n_, w_ = (math.cos(rz + math.pi), math.sin(rz + math.pi), 0.0), (-math.sin(rz), math.cos(rz), 0.0)
    for k, (x, h) in enumerate(((3.25, 1.6), (4.05, 2.25), (4.85, 1.75), (5.65, 2.4), (6.4, 1.45))):
        y = 2.65 - 0.1 * k
        c_ = (x, y, 0.3 + h / 2)
        lot.put(M["ceram"] if k % 2 else M["ceram2"], G.boite(c_, (0.08, 0.95, h), rz=rz), xf)
        for j in range(4):
            q = G.add(G.add(c_, G.mul(n_, 0.055)), G.mul(w_, -0.36 + 0.24 * j))
            lot.put(M["cuivre"], G.tube([(q[0], q[1], 0.4), (q[0], q[1], 0.3 + h * (0.78 + 0.05 * j))], 0.018, 5), xf)
        for t in (0.35, 0.72):
            lot.put(M["cuivre2"], G.boite(G.add((x, y, 0.3 + h * t), G.mul(n_, 0.05)), (0.02, 0.9, 0.06), rz=rz), xf)
        lot.put(M["acier"], G.boite((x, y, 0.3 + h - 0.04), (0.13, 1.0, 0.08), rz=rz), xf)
    R.tuyau(lot, M["cuivre"], M["cuivre2"], [(2.85, 1.95, 0.75), (6.1, 1.65, 0.75)], 0.085, xf=xf)
    R.tuyau(lot, M["acier"], M["cuivre2"], [(3.2, 2.0, 1.2), (5.65, 1.8, 1.2)], 0.05, xf=xf)
    R.flexible(lot, M["caoutchouc"], M["cuivre2"], [(2.85, 1.95, 0.75), (2.1, 1.5, 1.1), (1.5, 1.2, ZS + 0.3)], 0.06, xf=xf)


def train(lot, M, r):
    """Berceaux sous les nacelles, trains sous le crâne (le vaisseau à terre, pas posé en lévitation)."""
    surf = N.crane_pt(ZS)
    xf_n = F_nav
    for x in (3.6, 4.9, 6.1):
        for s in (-1, 1):
            a = math.pi + 0.8 if s < 0 else -0.8
            q = surf(x, a, 0.0)
            pied = (x - 0.1, q[1] + s * 0.28, 0.0)
            tete = (q[0], q[1], q[2])
            lot.put(M["acier"], G.tube([pied, G.lerp(pied, tete, 0.6)], 0.07, 10), xf_n)
            lot.put(M["cuivre"], G.tube([G.lerp(pied, tete, 0.55), tete], 0.045, 10), xf_n)
            lot.put(M["pierre2"], G.tour([(0.0, 0.24), (0.06, 0.22), (0.12, 0.1)], 12, "z", (pied[0], pied[1], 0.0), cap1=True), xf_n)
    cz = ZS - 0.05
    for s in (-1, 1):
        for x in (-4.3, -5.6):
            rr = N.nac_r(x)
            h = cz - rr + 0.1
            lot.put(M["acier"], G.boite((x, s * N.NAC_Y, h / 2), (0.46, 0.8, h)), xf_n)
            lot.put(M["cuivre2"], G.boite((x, s * N.NAC_Y, 0.08), (0.6, 0.95, 0.16)), xf_n)
        for x in (-6.25, -6.5, -6.75):                              # tuyères magnétiques : bobines de cuivre sur la cloche
            rr = N.nac_r(x) + 0.06
            lot.put(M["cuivre"], G.tour([(x - 0.08, rr), (x + 0.08, rr)], 28, "x", (0.0, s * N.NAC_Y, cz), cap0=True, cap1=True), xf_n)
        lot.put(M["plasma"], G.tour([(-6.5, 0.2), (-6.65, 0.1), (-6.72, 0.0)], 14, "x", (0.0, s * N.NAC_Y, cz)), xf_n)


def vaisseau(lot, M, r):
    M2 = dict(M)
    M2["chevron"] = M["ceram"]                                      # nacelles : céramique et jaune, sans chevrons
    N.crane(lot, M, ZS, r, F_nav)
    N.nacelles(lot, M2, ZS, r, F_nav)
    N.derive(lot, M, ZS, r, F_nav, corde=0.55)
    for s in (-1, 1):
        N.aile(lot, M, s, ZS, F_nav)
    c = (-3.0, 0.0, ZS - 0.15)
    N.coeur(lot, M, c, r, F_nav)
    for (y, z, rr, cible) in ((-0.35, -0.2, 0.085, (-3.75, -1.0, ZS - 0.3)), (0.35, -0.25, 0.085, (-3.75, 1.0, ZS - 0.3))):
        a = (c[0] - 0.62, c[1] + y, c[2] + z)
        R.tuyau(lot, M["cuivre"], M["cuivre2"], [a, (cible[0], a[1], a[2]), cible], rr, xf=F_nav)
    for (dy, dz) in ((-0.5, -0.4), (-0.15, -0.55), (0.3, 0.6)):
        R.flexible(lot, M["caoutchouc"], M["cuivre2"], [(c[0] + 0.2, c[1] + dy, c[2] + dz), (c[0] + 0.7, c[1] + dy - 0.35, c[2] + dz - 0.3), (-1.4, dy * 2.0, ZS - 0.7 + dz * 0.5)], 0.045, xf=F_nav)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (c[0] - 0.4, -0.6, c[2] + 0.4), (-4.2, -1.0, ZS + 0.75), 0.25, r, n=4, rouges=2, xf=F_nav)
    R.faisceau(lot, M["cable_r"], M["cable_n"], (c[0] + 0.2, -0.65, c[2] - 0.4), (-1.2, -1.4, ZS - 0.2), 0.3, r, n=4, rouges=1, xf=F_nav)


def build(S, lot):
    R.raz()
    M = matieres(S)
    r = G.Rnd(1313)
    lot.xf = F_pal
    sol(lot, M, r)
    parvis(lot, M, r)
    vaisseau(lot, M, r)
    squelette(lot, M, r)
    train(lot, M, r)
    halle(lot, M, r)
    cryostat(lot, M, r)
    trepied(lot, M, r)
    sphere(lot, M, r)
    tore(lot, M, r)
    fleche(lot, M, r)
    injecteurs(lot, M, r)
    zones = [(F_sol, 0.3, (-7.5, -4.3), (-3.75, -3.1), 12), (F_sol, 0.14, (-3.4, -1.0), (-3.85, -3.3), 8), (F_sol, 0.14, (1.0, 3.2), (-3.85, -3.3), 8),
             (F_sol, 0.36, (3.9, 7.2), (-3.7, -3.1), 12), (F_sol, 0.22, (-7.9, -7.2), (-2.5, 2.1), 8), (F_sol, 0.42, (-7.4, -3.9), (2.8, 3.9), 8),
             (F_sol, 0.34, (2.7, 7.0), (2.6, 3.9), 8), (F_sol, 0.28, (-3.2, 2.0), (3.1, 3.9), 8)]
    E.chargement(lot, M, G.Rnd(1314), zones)
    mats = [M["acier"], M["noyau"], M["cuivre2"], M["ceram2"], M["cuivre"]]
    E.menus(lot, mats, G.Rnd(1315), [(z[0], z[1], z[2], z[3], z[4] * 3) for z in zones])
    return dict(R.COMPTE)
