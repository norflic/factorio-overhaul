"""LÉVITE (robot 9, âge 12 Supraconducteurs, assaut lourd ; PLAN §2 : corps sur 2 anneaux flottants ; image 5 tuiles, boîte ±0,9).

Idée : un marcheur SANS JAMBES. Ses deux pieds sont deux grands anneaux chromés horizontaux qui flottent au-dessus du sol ;
un anneau reste immobile (appui, sans glissement) pendant que l'autre vole vers l'avant, et le corps, retenu par rien, passe
de l'un à l'autre. Rien ne touche rien : quille, coque, tête, épaulières, rails et anneaux sont séparés par des VIDES
visibles (signature de l'âge 12). Corps asymétrique : côté caméra une épaulière qui porte 2 longs rails et leurs anneaux
d'accélération ; dans le dos, un réservoir cryogénique debout, givré, et 2 aubes noires.
Bible (DESIGN_EPOQUES, époque 12) : noir #26282E, chrome #9AA3AD, givre #DDEEFF, cyan #4AF0FF.
"""
import math

import formes as F
import geo as G
import marionette as Mr

CAP = math.radians(-163.0)     # presque de profil, un peu vers la caméra : rails, vide et anneaux se lisent
Z0 = 3.0                # centre de la coque, à l'arrêt
Y_AN, Z_AN = 0.95, 0.27
R_AN = 0.86
PAS, BETA, LEVE = 2.1, 0.62, 0.6
PIEDS = (("g", 1.0, 0.0), ("d", -1.0, 0.5))
IMAGES = 6


def matieres(S):
    import mat as MT
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.1, ra=0.3, ec=0.14, nu_k=1.25, ec_col=(0.34, 0.42, 0.5), sans=("chrome", "givre"))
    cr = (0.004, 0.0045, 0.006)
    M = {}
    M["noir"] = F.surf("rb12_noir", (0.05, 0.053, 0.063), rough=0.3, met=0.45, tole=(0.62, 0.34), joint=0.3, joint_l=0.012, var=0.18,
                       usure=0.55, nu=(0.36, 0.38, 0.42), crasse=0.6, crasse_col=cr, relief=0.55, graine=121)
    M["noir2"] = F.surf("rb12_noir2", (0.085, 0.09, 0.105), rough=0.38, met=0.45, usure=0.6, nu=(0.42, 0.44, 0.48), crasse=0.6, crasse_col=cr, graine=122)
    M["chrome"] = F.surf("rb12_chrome", (0.66, 0.7, 0.76), rough=0.2, met=0.5, usure=0.25, nu=(0.86, 0.88, 0.92), crasse=0.5, crasse_col=cr, grain=0.04, graine=123)
    M["chrome2"] = F.surf("rb12_chrome2", (0.4, 0.43, 0.48), rough=0.26, met=0.5, usure=0.35, nu=(0.7, 0.72, 0.76), crasse=0.55, crasse_col=cr, grain=0.05, graine=124)
    M["givre"] = F.surf("rb12_givre", (0.74, 0.85, 0.96), rough=0.5, met=0.0, usure=0.2, nu=(0.95, 0.98, 1.0), crasse=0.3, crasse_col=(0.2, 0.28, 0.36), grain=0.2, graine=125)
    M["riv"] = F.surf("rb12_riv", (0.2, 0.22, 0.25), rough=0.3, met=0.9, usure=0.2, crasse=0.3, graine=126)
    M["verre"] = MT.verre("rb12_verre", col=(0.008, 0.02, 0.026), reflet=(0.25, 0.42, 0.5))
    M["cyan"] = MT.lumiere(S, "rb12_cyan", (0.07, 0.87, 1.0), 2.0, main=0.5)
    M["cyan2"] = MT.lumiere(S, "rb12_cyan2", (0.07, 0.87, 1.0), 1.2, main=0.45)
    return M


def squelette(phase):
    sq = Mr.Squelette()
    bat = 0.0 if phase is None else 1.0
    ph = 0.0 if phase is None else phase
    a = G.TAU * ph
    sq.os("racine", None, Mr.rz(CAP))
    # le corps se porte au-dessus de l'anneau d'appui, plonge en avant au milieu du pas (décalage au-dessus de l'anneau, roulis, lacet)
    dy = bat * 0.17 * math.cos(a)
    m_corps = Mr.chaine(Mr.tr(0.0, dy, Z0 + bat * 0.07 * math.cos(2.0 * a + 0.5)), Mr.rz(bat * 0.07 * math.sin(a)), Mr.ry(bat * 0.035 * math.cos(2.0 * a)),
                        Mr.rx(bat * 0.055 * math.cos(a)))
    sq.os("corps", "racine", m_corps)
    # pièces flottantes : elles suivent le corps avec un retard, leur vide respire
    sq.os("tete", "corps", Mr.chaine(Mr.tr(0.0, 0.0, bat * 0.03 * math.sin(2.0 * a)), Mr.rz(bat * -0.05 * math.sin(a))))
    sq.os("quille", "corps", Mr.chaine(Mr.tr(0.0, bat * -0.03 * math.cos(a), bat * -0.03 * math.sin(2.0 * a))))
    sq.os("ep_g", "corps", Mr.tr(bat * 0.03 * math.sin(a), bat * 0.02 * math.cos(a), bat * 0.03 * math.sin(2.0 * a + 1.0)))
    sq.os("ep_d", "corps", Mr.tr(bat * -0.03 * math.sin(a), bat * 0.02 * math.cos(a), bat * 0.03 * math.sin(2.0 * a + 2.2)))
    sq.os("ceinture", "corps", Mr.chaine(Mr.rx(0.14), Mr.rz(a)))
    sq.os("satellites", "corps", Mr.rz(-a))
    sq.os("dos", "corps", Mr.tr(bat * -0.04 * math.cos(2.0 * a), 0.0, bat * 0.03 * math.sin(2.0 * a)))
    for nom, s, dec in PIEDS:
        dx, dz, appui, u = Mr.pied(phase, dec, PAS, BETA, LEVE)
        p = (0.05 + dx, s * Y_AN, Z_AN + dz)
        tang = 0.0 if appui else -0.4 * math.sin(math.pi * u)           # l'anneau en vol pique vers l'avant
        rou = 0.0 if appui else s * 0.16 * math.sin(math.pi * u)
        sq.os("an_" + nom, "racine", Mr.chaine(Mr.tr(p[0], p[1], p[2]), Mr.ry(tang), Mr.rx(rou)))
        sq.os("tourne_" + nom, "an_" + nom, Mr.rz(s * 2.0 * a))
        sq.marques[nom] = {"pied": p, "appui": appui, "tendu": False}
    return sq


def _anneau(lots, nom, M, r):
    """Pied : anneau extérieur chromé (fixe), ceinture noire à griffes, bande cyan, couronne intérieure qui tourne."""
    a = lots("an_" + nom)
    a.put(M["chrome"], G.tour([(-0.09, R_AN - 0.02), (-0.13, R_AN + 0.05), (-0.1, R_AN + 0.12), (0.03, R_AN + 0.15), (0.11, R_AN + 0.12), (0.13, R_AN + 0.04),
                               (0.09, R_AN - 0.02), (-0.09, R_AN - 0.02)], 64, "z"))
    a.put(M["noir"], F.bague((0.0, 0.0, 0.0), R_AN - 0.1, R_AN - 0.015, 0.17, "z", 64, 0.012))
    a.put(M["cyan"], F.bague((0.0, 0.0, -0.095), R_AN - 0.07, R_AN - 0.03, 0.022, "z", 64))
    a.put(M["cyan2"], F.bague((0.0, 0.0, 0.094), R_AN - 0.065, R_AN - 0.04, 0.014, "z", 64))
    for i in range(8):     # griffes de chrome qui mordent le bord, et leur plot noir
        ang = G.TAU * (i + 0.5) / 8
        c, s = math.cos(ang), math.sin(ang)
        a.put(M["chrome2"], G.boite(((R_AN + 0.12) * c, (R_AN + 0.12) * s, 0.0), (0.25, 0.1, 0.27), ang))
        a.put(M["noir2"], G.boite(((R_AN + 0.2) * c, (R_AN + 0.2) * s, 0.0), (0.12, 0.17, 0.19), ang))
        a.put(M["cyan"], G.boite(((R_AN + 0.265) * c, (R_AN + 0.265) * s, 0.0), (0.012, 0.09, 0.05), ang))
    for i in range(14):    # givre sur le dessus du rebord (quelques plaques)
        ang = r.f(0.0, G.TAU)
        c, s = math.cos(ang), math.sin(ang)
        a.put(M["givre"], G.boite(((R_AN + r.f(0.03, 0.09)) * c, (R_AN + r.f(0.03, 0.09)) * s, 0.13), (r.f(0.03, 0.08), r.f(0.08, 0.2), 0.012), ang))
    t = lots("tourne_" + nom)
    t.put(M["chrome2"], F.bague((0.0, 0.0, 0.0), R_AN - 0.34, R_AN - 0.23, 0.07, "z", 48, 0.012))
    for i in range(6):     # couronne : blocs séparés par des vides, qui tournent dans l'anneau
        ang = G.TAU * i / 6
        t.put(M["noir2"], G.boite(((R_AN - 0.17) * math.cos(ang), (R_AN - 0.17) * math.sin(ang), 0.0), (0.09, 0.24, 0.11), ang))
    for i in range(3):
        ang = G.TAU * i / 3 + 0.2
        t.put(M["cyan2"], G.boite(((R_AN - 0.42) * math.cos(ang), (R_AN - 0.42) * math.sin(ang), 0.0), (0.05, 0.05, 0.05), ang))


def modele(lots, M, r):
    # ---------------------------------------------------------------------------- pieds
    for nom, s, dec in PIEDS:
        _anneau(lots, nom, M, r)
    # ---------------------------------------------------------------------------- coque en ogive (10 pans), origine au centre
    c = lots("corps")
    a0 = math.pi / 10.0
    prof = [(-0.75, 0.3), (-0.46, 0.62), (-0.05, 0.84), (0.42, 0.88), (0.78, 0.66), (1.0, 0.36), (1.03, 0.0)]
    c.put(M["noir"], G.tour(prof, 10, "z", a0=a0, a1=a0 + G.TAU))
    c.put(M["chrome"], F.bague((0.0, 0.0, -0.75), 0.2, 0.36, 0.07, "z", 10, 0.015, a0=a0, a1=a0 + G.TAU))
    c.put(M["chrome"], F.bague((0.0, 0.0, 1.0), 0.15, 0.4, 0.05, "z", 10, 0.012, a0=a0, a1=a0 + G.TAU))
    c.put(M["cyan2"], F.bague((0.0, 0.0, -0.79), 0.14, 0.26, 0.02, "z", 20))
    # arêtes de chrome, plaques de givre basses, panneaux rivetés
    for i in range(10):
        ang = G.TAU * i / 10 + a0
        cs, sn = math.cos(ang), math.sin(ang)
        ct = [(r0 * cs, r0 * sn, z) for z, r0 in ((-0.46, 0.645), (-0.05, 0.865), (0.42, 0.905), (0.78, 0.685), (0.98, 0.39))]
        c.put(M["chrome2"], G.tube(G.catmull(ct, 3), 0.019, 5))
        mid = ang + math.pi / 10.0
        n = (math.cos(mid) * 0.9, math.sin(mid) * 0.9, -0.42)
        if i % 3 != 1:
            c.put(M["givre"], F.sur_face(F.plaque(((-0.15, -0.07), (0.13, -0.09), (0.17, 0.05), (0.03, 0.12), (-0.14, 0.07)), 0.01),
                                         (0.68 * math.cos(mid), 0.68 * math.sin(mid), -0.28), n))
        nm = (math.cos(mid), math.sin(mid), 0.1)
        c.put(M["noir2"], F.sur_face(F.plaque(((-0.17, -0.2), (0.17, -0.2), (0.17, 0.2), (-0.17, 0.2)), 0.018), (0.81 * math.cos(mid), 0.81 * math.sin(mid), 0.2), nm))
        c.put(M["riv"], G.rivets_le_long([((0.83 * math.cos(mid) + dx * -math.sin(mid), 0.83 * math.sin(mid) + dx * math.cos(mid), 0.2 + dz), nm)
                                          for dx, dz in ((-0.14, 0.16), (0.14, 0.16), (-0.14, -0.16), (0.14, -0.16))], 0.012, 0.007))
    # poitrine : réacteur à lames, le point fort vu de face
    n_av = (0.97, 0.0, 0.1)
    p_av = (0.83, 0.0, 0.26)
    c.put(M["chrome"], F.pose(F.bague((0.0, 0.0, 0.0), 0.2, 0.32, 0.07, "x", 24, 0.012), p_av, n_av))
    c.put(M["noir2"], F.pose(F.disque((-0.005, 0.0, 0.0), 0.21, 0.04, "x", 24), p_av, n_av))
    c.put(M["cyan"], F.pose(F.disque((0.022, 0.0, 0.0), 0.11, 0.012, "x", 20), p_av, n_av))
    for i in range(6):
        ang = G.TAU * i / 6
        c.put(M["chrome2"], F.pose(G.boite((0.03, 0.16 * math.cos(ang), 0.16 * math.sin(ang)), (0.01, 0.024, 0.1), 0.0, ang), p_av, n_av))
    # ---------------------------------------------------------------------------- quille : pointe vers le bas, séparée de la coque
    q = lots("quille")
    q.put(M["noir2"], G.tour([(-1.75, 0.0), (-1.55, 0.09), (-1.25, 0.15), (-1.08, 0.28), (-0.96, 0.33), (-0.9, 0.0)], 10, "z"))
    q.put(M["chrome"], F.bague((0.0, 0.0, -1.1), 0.2, 0.36, 0.035, "z", 20, 0.006))
    q.put(M["chrome2"], F.bague((0.0, 0.0, -1.42), 0.1, 0.17, 0.03, "z", 16, 0.006))
    q.put(M["cyan"], G.tour([(-1.88, 0.0), (-1.81, 0.05), (-1.74, 0.0)], 8, "z"))
    # ---------------------------------------------------------------------------- tête : prisme bas, fente cyan, séparée de la coque par un vide
    t = lots("tete")
    hexa = [(0.56, 0.0), (0.27, 0.36), (-0.28, 0.4), (-0.46, 0.0), (-0.28, -0.4), (0.27, -0.36)]
    zt = 1.22
    t.put(M["noir"], G.prisme(hexa, zt, zt + 0.36, 0.74))
    t.put(M["chrome2"], G.prisme(hexa, zt - 0.05, zt + 0.01, 0.98))
    t.put(M["chrome"], G.prisme(((0.36, 0.0), (0.18, 0.18), (-0.2, 0.2), (-0.3, 0.0), (-0.2, -0.2), (0.18, -0.18)), zt + 0.36, zt + 0.4, 0.8))
    t.put(M["cyan"], G.boite((0.46, 0.0, zt + 0.17), (0.02, 0.44, 0.05)))
    t.put(M["cyan"], G.boite((0.39, 0.2, zt + 0.17), (0.2, 0.02, 0.05), -0.9))
    t.put(M["cyan"], G.boite((0.39, -0.2, zt + 0.17), (0.2, 0.02, 0.05), 0.9))
    for s, h in ((1.0, 0.72), (-1.0, 0.46)):   # 2 pylônes inégaux sur la tête
        t.put(M["chrome2"], F.incline(F.fleche(0.05, h, 6), (-0.1, s * 0.2, zt + 0.37), (-0.1, s * 0.12, 1.0)))
        t.put(M["cyan"], F.cristal((-0.1 - 0.1 * h, s * (0.2 + 0.12 * h), zt + 0.37 + h * 0.98), 0.024))
    # ---------------------------------------------------------------------------- ceinture : anneau de 3e diamètre qui tourne, ajouré, vide autour de la coque
    b = lots("ceinture")
    for i in range(3):
        a1 = G.TAU * i / 3 + 0.35
        b.put(M["chrome"], F.bague((0.0, 0.0, -0.1), 1.18, 1.3, 0.06, "z", 18, 0.012, a0=a1, a1=a1 + 1.65))
        b.put(M["cyan2"], F.bague((0.0, 0.0, -0.066), 1.21, 1.27, 0.012, "z", 18, a0=a1 + 0.12, a1=a1 + 1.5))
        ax = a1 + 1.65
        b.put(M["noir2"], G.boite((1.24 * math.cos(ax), 1.24 * math.sin(ax), -0.1), (0.22, 0.09, 0.11), ax + math.pi / 2))
    sa = lots("satellites")
    for i in range(5):     # blocs flottants qui orbitent sous la ceinture
        ang = G.TAU * i / 5 + 0.4
        rr_ = 0.92 + 0.08 * (i % 2)
        z = -0.72 + 0.06 * (i % 3)
        sa.put(M["noir2"], G.boite((rr_ * math.cos(ang), rr_ * math.sin(ang), z), (0.16, 0.1, 0.13), ang, 0.3))
        sa.put(M["chrome2"], G.boite((rr_ * math.cos(ang), rr_ * math.sin(ang), z + 0.082), (0.11, 0.07, 0.018), ang, 0.3))
    # ---------------------------------------------------------------------------- épaulière gauche (+Y, côté caméra) et ses 2 longs rails
    g = lots("ep_g")
    yg, zg = 1.28, 0.62
    bloc = [(0.5, -0.22), (0.5, 0.22), (0.14, 0.32), (-0.46, 0.28), (-0.56, 0.0), (-0.46, -0.28), (0.14, -0.3)]
    bloc_g = [(x, yg + y) for x, y in bloc]
    g.put(M["noir"], G.prisme(bloc_g, zg - 0.22, zg + 0.18, 0.86))
    g.put(M["chrome"], G.prisme(bloc_g, zg - 0.27, zg - 0.21, 0.98))
    g.put(M["cyan2"], F.bague((0.0, yg, zg - 0.295), 0.08, 0.15, 0.012, "z", 16))
    cz = zg + 0.33
    for dy in (-0.15, 0.15):
        y = yg + dy
        g.put(M["chrome"], F.poutre([(-0.8, 0.08, 0.14), (2.75, 0.06, 0.1)], 0.2), (lambda v, y=y, z=cz: (v[0], v[1] + y, v[2] + z)))
        g.put(M["noir2"], F.poutre([(-0.77, 0.03, 0.18), (2.65, 0.022, 0.13)], 0.2), (lambda v, y=y, z=cz: (v[0], v[1] + y, v[2] + z)))
        g.put(M["chrome2"], F.disque((2.77, y, cz), 0.06, 0.08, "x", 10))
    for x, ep, k in ((-0.05, 0.11, 1.0), (0.72, 0.08, 1.0), (1.36, 0.08, 0.95), (1.98, 0.08, 0.9), (2.54, 0.08, 0.85)):     # anneaux d'accélération, vides autour des rails
        g.put(M["chrome"], F.bague((x, yg, cz), 0.27 * k, 0.34 * k, ep, "x", 28, 0.012))
        g.put(M["cyan"], F.bague((x, yg, cz), 0.255 * k, 0.27 * k, ep * 0.6, "x", 28))
        g.put(M["noir"], F.bielle((x, yg - 0.33 * k, cz), (x, yg - 0.15, cz), 0.04, 0.07))
        g.put(M["noir"], F.bielle((x, yg + 0.33 * k, cz), (x, yg + 0.15, cz), 0.04, 0.07))
    g.put(M["noir"], G.boite((-0.46, yg, zg + 0.22), (0.5, 0.46, 0.09)))
    for x in (-0.64, -0.46, -0.28):
        g.put(M["cyan2"], G.boite((x, yg + 0.235, zg + 0.22), (0.07, 0.008, 0.04)))
    # ---------------------------------------------------------------------------- épaulière droite (-Y) : bloc nu et évents, contrepoids des rails
    d = lots("ep_d")
    yd, zd = -1.2, -0.12
    bloc_d = [(x, yd + y) for x, y in bloc]
    d.put(M["noir"], G.prisme(bloc_d, zd - 0.22, zd + 0.18, 0.86))
    d.put(M["chrome"], G.prisme(bloc_d, zd - 0.27, zd - 0.21, 0.98))
    for x in (-0.3, -0.1, 0.1, 0.3):
        d.put(M["chrome2"], G.boite((x, yd, zd + 0.2), (0.07, 0.34, 0.03)))
    # ---------------------------------------------------------------------------- dos : réservoir cryogénique debout, givré, séparé de la coque, et 2 aubes
    u = lots("dos")
    xr, zr0, zr1 = -1.32, -0.62, 0.88
    u.put(M["givre"], G.tour([(zr0, 0.0), (zr0 + 0.04, 0.17), (zr0 + 0.14, 0.27), (zr0 + 0.26, 0.31), (zr1 - 0.22, 0.31), (zr1 - 0.1, 0.25), (zr1 - 0.02, 0.13), (zr1, 0.0)], 22, "z", (xr, 0.0, 0.0)))
    for z in (zr0 + 0.26, zr0 + 0.62, zr0 + 0.98, zr1 - 0.24):
        u.put(M["chrome"], F.bague((xr, 0.0, z), 0.3, 0.345, 0.055, "z", 22, 0.01))
    u.put(M["noir2"], F.disque((xr, 0.0, zr1 + 0.03), 0.08, 0.1, "z", 10))
    u.put(M["cyan"], F.cristal((xr, 0.0, zr1 + 0.14), 0.04, 0.07))
    u.put(M["noir"], G.boite((xr + 0.3, 0.0, 0.25), (0.14, 0.24, 0.1)))     # plots tournés vers la coque, sans la toucher
    u.put(M["noir"], G.boite((xr + 0.3, 0.0, -0.3), (0.14, 0.24, 0.1)))
    for i in range(46):    # cristaux de givre sur le réservoir
        z, ang = r.f(zr0 + 0.2, zr1 - 0.2), r.f(0.0, G.TAU)
        n = (math.cos(ang), math.sin(ang), 0.0)
        p = (xr + 0.31 * n[0], 0.31 * n[1], z)
        u.put(M["givre"], G.oriente(G.tour([(0.0, 0.02), (r.f(0.05, 0.12), 0.0)], 4, "z"), p, (n[0], n[1], r.f(-0.3, 0.3))))
    for s, hh in ((1.0, 1.35), (-1.0, 1.0)):
        y = s * 0.42
        pied = (-1.05, y, 0.2)
        haut = (-1.05 - 0.42 * hh, y + s * 0.1, 0.2 + hh)
        u.put(M["chrome2"], F.bielle(pied, haut, 0.04, 0.04))
        u.put(M["noir2"], F.pose(F.plaque([(0.0, -0.05), (hh, -0.04), (hh + 0.1, 0.05), (hh * 0.55, 0.26), (0.08, 0.17)], 0.035), pied, G.sub(haut, pied), (s * 0.2, 1.0, 0.0)))
        u.put(M["cyan2"], F.bielle(G.lerp(pied, haut, 0.15), G.lerp(pied, haut, 0.75), 0.012, 0.012))
