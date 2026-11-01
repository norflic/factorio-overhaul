"""ÈRE II LOURDE (âges 4, 5, 6 du QG, série du 31/10) : ce que les trois états ont en commun.

- la CARCASSE validée par le DC sur l'âge 8 (qg08.py, gelé : copie de ses parties 1 et 2, mêmes pose, côtes, tuyères,
  crâne, dérive, ailes), seules les matières changent (clés de M, voir matieres) ;
- l'ÉCHELLE : les états sont modélisés en unités de l'âge 8 (emprise 12×6) puis réduits à 10×5 par LotK, qui garde
  toutes les cotes de qg08 lisibles et la carcasse identique ;
- le KIT lourd de l'ère (§1.2 : cylindres, pentes, empilements) : cuves, garde-corps, échelles, vannes, fûts, écailles,
  piles d'isolateurs, tores.
Nez à droite (+X). Repère monde (avant LotK) : +X est, +Y nord, +Z haut.
"""
import math
from contextlib import contextmanager

import carcasse as C
import geo as G
import mat as MT

K = 10.0 / 12.0
POSE = dict(T=(0.0, 0.55, 1.45), lacet=-0.105, tangage=0.04, roulis=0.17)
COTES = (-1.95, -0.85, 0.55, 1.55)
BALAI = 0.48
Z_PONT = 0.45
TAU = G.TAU


class LotK:
    """Enveloppe du Lot : même put, mais tout est réduit de k après la transformation courante."""

    def __init__(self, lot, k=K):
        self.lot, self.k, self.xf = lot, k, None

    def put(self, mat, mesh, xf=None):
        v, f, u = mesh
        g = xf or self.xf
        k = self.k
        if g is not None:
            v = [g(p) for p in v]
        self.lot.put(mat, ([(p[0] * k, p[1] * k, p[2] * k) for p in v], f, u))


@contextmanager
def dans(lot, c=(0.0, 0.0, 0.0), rz=0.0):
    """Repère local : rotation rz puis translation c, composés avec le repère courant."""
    old = lot.xf

    def f(p):
        q = G.add(G.rot_z(p, rz), c)
        return old(q) if old else q
    lot.xf = f
    try:
        yield
    finally:
        lot.xf = old


# ================================================================================================ matières
def matieres(S, pre, pal, patine):
    """Matières de la carcasse et du kit. pal : couleurs de l'âge (linéaires) ; les clés de M sont celles de qg08 :
    jaune0 à 3 et vdg, vdg2 (seconde peau), rapiece, rapiece2, conduit, toit, tole_ond, pierre, bois, poutre…"""
    MT.PATINE.clear()
    MT.PATINE.update(patine)
    sf = MT.surface
    cr = pal.get("crasse", (0.008, 0.0065, 0.004))
    rou = pal.get("rouille", (0.16, 0.06, 0.02))
    M = {}
    g = 41
    for i, c in enumerate(pal["jaunes"]):
        M["jaune%d" % i] = sf("%s_jaune%d" % (pre, i), c, rough=0.48, met=0.2, coulures=0.9, rouille=rou, usure=0.85, nu=pal.get("nu", (0.62, 0.6, 0.56)),
                              crasse=0.95, crasse_col=cr, pied=(0.3, 1.1, 0.5), grain=0.11, graine=g + i)
    M["vdg"] = sf(pre + "_sec", pal["sec"], rough=0.55, met=0.35, coulures=0.8, rouille=rou, usure=0.7, nu=pal.get("nu", (0.45, 0.45, 0.45)), crasse=0.8,
                  crasse_col=cr, pied=(0.3, 1.1, 0.55), grain=0.12, graine=g + 5)
    M["vdg2"] = sf(pre + "_sec2", pal["sec2"], rough=0.55, met=0.35, coulures=0.8, rouille=rou, usure=0.7, crasse=0.8, crasse_col=cr, grain=0.12, graine=g + 6)
    M["conduit"] = sf(pre + "_conduit", pal["conduit"], rough=0.42, met=0.55, coulures=0.7, rouille=rou, usure=0.75, nu=(0.5, 0.48, 0.44), crasse=0.75,
                      crasse_col=cr, grain=0.1, graine=g + 7)
    M["rapiece"] = sf(pre + "_rap", pal["rapiece"], rough=0.45, met=0.5, coulures=0.8, rouille=rou, usure=0.6, crasse=0.75, crasse_col=cr, grain=0.12, graine=g + 8)
    M["rapiece2"] = sf(pre + "_rap2", pal["rapiece2"], rough=0.7, met=0.3, coulures=0.6, rouille=rou, usure=0.5, nu=(0.3, 0.16, 0.08), crasse=0.75, crasse_col=cr,
                       grain=0.14, graine=g + 9)
    M["noyau"] = sf(pre + "_noyau", (0.007, 0.006, 0.005), rough=0.6, met=0.6, usure=0.2, crasse=0.8, crasse_col=(0.004, 0.003, 0.002), graine=g + 10)
    M["brule"] = sf(pre + "_brule", (0.01, 0.0085, 0.008), rough=0.75, met=0.4, usure=0.0, crasse=0.8, crasse_col=(0.003, 0.003, 0.003), graine=g + 11)
    M["acier"] = sf(pre + "_acier", pal["acier"], rough=0.5, met=0.75, usure=0.85, nu=(0.72, 0.68, 0.6), crasse=0.7, crasse_col=cr, coulures=0.5, rouille=rou, graine=g + 12)
    M["acier_clair"] = sf(pre + "_acierc", pal["acier_clair"], rough=0.4, met=0.85, usure=0.4, crasse=0.6, crasse_col=cr, graine=g + 13)
    M["riv"] = sf(pre + "_riv", pal.get("riv", (0.085, 0.065, 0.035)), rough=0.6, met=0.3, usure=0.3, crasse=0.5, graine=g + 14)
    M["chevron"] = sf(pre + "_chev", pal["jaunes"][0], rough=0.5, met=0.2, bandes=(0.19, (0.012, 0.011, 0.01), 0.5), usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.7,
                      crasse_col=cr, coulures=0.6, graine=g + 15)
    M["cuivre"] = sf(pre + "_cuivre", pal["cuivre"], rough=0.4, met=0.85, coulures=0.85, rouille=(0.05, 0.17, 0.11), usure=0.6, nu=(0.6, 0.33, 0.17), crasse=0.7,
                     crasse_col=cr, graine=g + 16)
    M["caoutchouc"] = sf(pre + "_caout", (0.023, 0.023, 0.021), rough=0.72, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.065), crasse=0.5, crasse_col=cr, graine=g + 17)
    M["bois"] = sf(pre + "_bois", pal["bois"], rough=0.85, met=0.0, tole=(0.9, 0.115), joint=0.18, var=0.28, coulures=0.4, rouille=(0.03, 0.03, 0.02), usure=0.5,
                   nu=(0.22, 0.15, 0.08), crasse=0.75, crasse_col=cr, relief=0.5, grain=0.14, graine=g + 18)
    M["poutre"] = sf(pre + "_poutre", pal["poutre"], rough=0.7, met=0.3, usure=0.6, nu=(0.3, 0.27, 0.22), crasse=0.7, crasse_col=cr, grain=0.14, graine=g + 19)
    M["pierre"] = sf(pre + "_pierre", pal["pierre"], rough=0.9, met=0.0, tole=(0.5, 0.25), joint=0.4, var=0.18, coulures=0.5, rouille=rou, usure=0.6, nu=(0.25, 0.24, 0.22),
                     crasse=0.8, crasse_col=cr, pied=(0.0, 0.4, 0.6), relief=0.6, grain=0.14, graine=g + 20)
    M["toit"] = sf(pre + "_toit", pal["toit"], rough=0.55, met=0.35, coulures=0.7, rouille=rou, usure=0.6, nu=(0.35, 0.33, 0.3), crasse=0.8, crasse_col=cr, grain=0.13, graine=g + 21)
    M["tole_ond"] = sf(pre + "_ond", pal["ond"], rough=0.55, met=0.4, tole=(0.12, 3.0), joint=0.3, var=0.08, coulures=0.9, rouille=rou, usure=0.6, nu=(0.35, 0.33, 0.3),
                       crasse=0.8, crasse_col=cr, pied=(0.5, 1.2, 0.5), relief=0.6, grain=0.12, graine=g + 22)
    M["boue"] = sf(pre + "_boue", pal["boue"], rough=0.85, met=0.0, usure=0.0, crasse=0.6, crasse_col=(0.01, 0.008, 0.004), grain=0.2, graine=g + 23)
    M["vase"] = sf(pre + "_vase", pal["flaque"], rough=0.3, met=0.0, usure=0.0, crasse=0.5, crasse_col=(0.004, 0.004, 0.003), grain=0.2, graine=g + 24)
    M["rouge"] = sf(pre + "_rouge", (0.32, 0.02, 0.012), rough=0.55, met=0.0, usure=0.3, nu=(0.4, 0.2, 0.15), crasse=0.4, graine=g + 25)
    M["noir"] = sf(pre + "_noir", (0.012, 0.012, 0.012), rough=0.7, met=0.0, usure=0.2, crasse=0.3, graine=g + 26)
    M["verre_sombre"] = MT.verre(pre + "_vsombre", col=pal.get("vitre", (0.01, 0.018, 0.02)), reflet=pal.get("vitre_r", (0.14, 0.2, 0.2)))
    M["veilleuse"] = MT.verre(pre + "_veil", col=pal.get("veil", (0.05, 0.03, 0.01)), reflet=(0.3, 0.25, 0.14))
    M["hublot"] = MT.lumiere(S, pre + "_hub", pal["lum"], pal.get("lum_f", 4.5), main=pal.get("lum_m", 0.45))
    M["voyant"] = MT.lumiere(S, pre + "_voy", pal.get("voy", pal["lum"]), pal.get("voy_f", 7.0), main=pal.get("lum_m", 0.4))
    return M


def coque(M, table):
    """Tirage des tôles de coque : table = [(seuil cumulé, clé)], chevrons au nez comme à l'âge 8."""
    def f(rr, xm, am):
        if 4.55 < xm < 4.8:
            return M["chevron"]
        x = rr.f()
        for (s, k) in table:
            if x < s:
                return M[k]
        return M[table[-1][1]]
    return f


# ================================================================================================ carcasse (copie de qg08 §1, §2)
def carcasse(lot, M, P, r, mats_coque, cuvette=None, deco_nac=None):
    """Crâne, queue, dos ouvert, épine, côtes, dérive, ailes, tuyères, jambes. deco_nac(lot, M, R, s) : ajout dans le repère
    d'une nacelle (axe x, arrière vers -x). Rend (P.xf des pieds des côtes)."""
    sc = C.surf_coque
    a_top = math.pi / 2
    lot.xf = P.xf
    verriere = (3.05, 4.3, a_top - 0.6, a_top + 0.62)
    C.noyau(lot, M["noyau"], sc, 2.2, 5.5, 0.0, TAU)
    C.blindage(lot, sc, 2.22, 5.45, -0.3, TAU - 0.3, mats_coque, r, Mriv=M["riv"], larg=(0.45, 0.95), arcs=(0.4, 0.85),
               saut=lambda x, a: verriere[0] < x < verriere[1] and verriere[2] < a < verriere[3])
    rings = []
    nx, na = 14, 16
    for i in range(nx + 1):
        x = verriere[0] + (verriere[1] - verriere[0]) * i / nx
        t = i / float(nx)
        bump = math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7
        rings.append([C.point(x, verriere[2] + (verriere[3] - verriere[2]) * j / na, 0.02 + 0.16 * bump * math.sin(math.pi * j / na) ** 0.6) for j in range(na + 1)])
    lot.put(M["verre_sombre"], G.loft(rings, closed=False))
    for i in (0, 4, 9, nx):
        lot.put(M["acier"], G.tube([G.add(p, (0, 0, 0.01)) for p in rings[i]], 0.035, 6))
    for j in (0, 6, 11, na):
        lot.put(M["acier"], G.tube([G.add(rr_[j], (0, 0, 0.01)) for rr_ in rings], 0.035, 6))
    C.bande(lot, sc, M["chevron"], 2.72, 2.9, a_top - 0.85, a_top + 0.85, 0.0, 0.08)
    tip = C.point(5.5, a_top, 0.0)
    lot.put(M["acier"], G.tour([(5.38, 0.13), (5.5, 0.12), (5.72, 0.04), (5.8, 0.0)], 12, "x", (0.0, 0.0, tip[2] - 0.05)))
    lot.put(M["voyant"], G.sphere((5.62, 0.0, tip[2] + 0.02), 0.025, 6, 3))
    for s in (-1, 1):
        y0 = s * 0.95
        poly = [(3.55, y0), (3.05, y0), (3.2, y0 + s * 0.75), (3.5, y0 + s * 0.8)]
        poly = poly if s > 0 else list(reversed(poly))
        v, f, u = G.prisme(poly, -0.03, 0.03)
        v = [(p[0], p[1], p[2] - 0.35 + abs(p[1] - y0) * 0.15) for p in v]
        lot.put(M["jaune1"] if s > 0 else M["vdg"], (v, f, u))
        lot.put(M["chevron"], G.tube([(3.22, y0 + s * 0.72, -0.24), (3.5, y0 + s * 0.78, -0.23)], 0.035, 6))
    for (x, a, forme, lum, rr_) in ((2.62, a_top + 1.0, "rond", "hublot", 0.085), (3.35, a_top + 1.12, "ovale", "veilleuse", 0.07),
                                    (4.1, a_top + 1.05, "octo", "veilleuse", 0.06), (2.55, a_top - 1.1, "carre", "veilleuse", 0.07)):
        C.hublot(lot, forme, M["acier"], M[lum], sc(x, a, 0.05), C.normale_s(sc, x, a), rr_)
    p = sc(3.7, a_top + 1.35, 0.06)
    n = C.normale_s(sc, 3.7, a_top + 1.35)
    lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (0.62, 0.5, 0.05)), p, n))
    lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.03), (0.5, 0.38, 0.03)), p, n))
    lot.put(M["jaune1"], C.pose_plane(G.boite((0.3, 0.0, 0.2), (0.06, 0.4, 0.4), 0.0, 0.9), p, n))
    # queue
    C.noyau(lot, M["noyau"], sc, -3.5, -2.18, -0.45, math.pi + 0.45)
    C.blindage(lot, sc, -2.2, -3.48, -0.42, math.pi + 0.42, mats_coque, r, Mriv=M["riv"], larg=(0.45, 0.9), arcs=(0.4, 0.85))
    lot.put(M["noyau"], G.loft([[sc(-3.5, -0.45 + (math.pi + 0.9) * j / 24.0, 0.0) for j in range(25)], [(-3.52, 0.0, -0.2)] * 25], closed=False))

    # dos du ventre ouvert
    def saut_dos(x, a):
        return -1.5 < x < 1.85 and not (a < a_top - 0.6 and (x < -1.0 or x > 0.75))
    C.noyau(lot, M["noyau"], sc, -2.2, -1.5, a_top - 0.95, a_top + 0.98, g=-0.01)
    C.noyau(lot, M["noyau"], sc, 1.85, 2.24, a_top - 0.95, a_top + 1.05, g=-0.01)
    C.blindage(lot, sc, -2.2, 2.24, a_top - 0.95, a_top + 0.98, mats_coque, r, Mriv=M["riv"], saut=saut_dos, gondole=0.3, larg=(0.42, 0.9), arcs=(0.4, 0.8))
    C.blindage(lot, sc, -2.2, -1.5, a_top + 0.98, a_top + 1.25, mats_coque, r, Mriv=M["riv"], gondole=0.5)
    for (a, rl) in ((a_top - 0.62, 0.045), (a_top + 0.6, 0.05), (a_top + 1.12, 0.04)):
        lot.put(M["acier"], G.tube([sc(x, a, 0.09) for x in [-1.55 + 0.17 * i for i in range(21)]], rl, 6))
    for (x, a, l, w) in ((-1.42, a_top + 0.4, 0.55, 0.3), (-1.4, a_top + 0.95, 0.5, 0.26), (1.92, a_top + 0.75, 0.45, 0.28), (-0.9, a_top - 0.66, 0.4, 0.3)):
        e = sc(x, a, 0.04)
        v, f, u = G.boite((w / 2 if x > 0 else -w / 2, 0.0, -l / 2), (w, 0.03, l))
        v = [G.add(e, G.rot_z(G.rot_x((q[0], q[1], q[2] + 0.05), -0.5 - 0.25 * r.f()), 0.3 * (1 if x > 0 else -1))) for q in v]
        lot.put(M["jaune1"] if r.f() < 0.6 else M["rapiece"], (v, f, u))
    # épine
    ep = [(x, 0.0, C.z_dessus(x) + 0.13) for x in [-3.45 + 0.25 * i for i in range(31)] if x < 4.3]
    lot.put(M["acier"], G.tube(ep, 0.13, 4))
    lot.put(M["jaune2"], G.tube([G.add(p, (0, 0, 0.1)) for p in ep[2:-3]], 0.05, 6))
    for x in [-3.2, -2.55] + list(COTES) + [2.2, 2.75]:
        z0 = C.z_dessus(x) + 0.2
        h = 0.28 if x in COTES else 0.18
        lot.put(M["acier"], C.prisme_plan([(x + 0.14, z0), (x - 0.2, z0), (x - 0.34, z0 + h)], 0.05))
    # côtes
    pieds = []
    for xt in COTES:
        e0, e1 = C.cote(lot, M["acier"], M["riv"], xt, -0.2, math.pi + 0.2, BALAI, g=0.1, haut=0.32)
        pieds.append((P.xf(e0), P.xf(e1)))
    for xt in (-2.2, 2.24):
        C.cote(lot, M["acier"], M["riv"], xt, -0.35, math.pi + 0.35, 0.12, g=0.06, prof=0.2, aile=0.26)
    # dérive
    z0 = C.z_dessus(-2.4)
    z1 = C.z_dessus(-3.45)
    lot.put(M["jaune0"], C.prisme_plan([(-2.3, z0 - 0.05), (-3.25, z0 + 1.8), (-3.95, z0 + 1.86), (-3.5, z1 - 0.05)], 0.09))
    for (poly, m, y) in (([(-2.55, z0 + 0.35), (-3.1, z0 + 1.2), (-3.55, z0 + 1.2), (-3.4, z0 + 0.35)], "vdg", 0.05),
                         ([(-3.13, z0 + 1.25), (-3.28, z0 + 1.5), (-3.75, z0 + 1.5), (-3.62, z0 + 1.25)], "rapiece", 0.05),
                         ([(-2.6, z0 + 0.35), (-3.0, z0 + 0.95), (-3.3, z0 + 0.95), (-3.2, z0 + 0.35)], "jaune1", -0.05)):
        lot.put(M[m], C.prisme_plan(poly, 0.025, y0=y))
    lot.put(M["chevron"], C.prisme_plan([(-3.27, z0 + 1.55), (-3.33, z0 + 1.72), (-3.93, z0 + 1.76), (-3.86, z0 + 1.55)], 0.11))
    lot.put(M["acier"], G.tube([(-2.3, 0.0, z0 - 0.05), (-3.25, 0.0, z0 + 1.8)], 0.05, 8))
    lot.put(M["voyant"], G.sphere((-3.6, 0.0, z0 + 1.92), 0.04, 8, 4))
    lot.put(M["acier"], G.tube([(-3.5, 0.0, z0 + 1.86), (-3.6, 0.0, z0 + 2.45)], 0.014, 5))

    # ailes
    def aile(s, pts, zr, di, m):
        poly = pts if s > 0 else list(reversed(pts))
        v, f, u = G.prisme(poly, -0.05, 0.05)
        yr = pts[0][1]
        sh = lambda q: (q[0], q[1], q[2] + zr + abs(q[1] - yr) * di)
        lot.put(m, ([sh(q) for q in v], f, u))
        return sh
    yr = 1.88
    sh = aile(1, [(-2.65, yr), (-4.55, yr), (-5.3, 3.55), (-4.5, 3.6)], -0.42, 0.24, M["jaune0"])
    BA = lambda t: (-2.65 + (-4.5 + 2.65) * t - 0.07, yr + (3.6 - yr) * t)
    BF = lambda t: (-4.55 + (-5.3 + 4.55) * t + 0.1, yr + (3.55 - yr) * t)
    for (a0, a1, m, f0, f1) in ((0.04, 0.4, "jaune1", 0.0, 0.55), (0.04, 0.33, "rapiece", 0.6, 1.0), (0.42, 0.66, "vdg", 0.0, 1.0), (0.68, 0.96, "jaune2", 0.0, 0.7)):
        def pt(t, f):
            a, b = BA(t), BF(t)
            return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
        v, f, u = G.prisme([pt(a0, f0), pt(a1, f0), pt(a1, f1), pt(a0, f1)], 0.05, 0.075)
        lot.put(M[m], ([sh(q) for q in v], f, u))
    lot.put(M["chevron"], G.tube([sh((-4.52, 3.55, 0.06)), sh((-5.28, 3.5, 0.06))], 0.05, 6))
    lot.put(M["acier"], G.tube([sh((-2.65, yr, 0.06)), sh((-4.5, 3.6, 0.06))], 0.04, 6))
    lot.put(M["voyant"], G.sphere(sh((-4.9, 3.58, 0.1)), 0.035, 6, 3))
    sh2 = aile(-1, [(-2.7, -yr), (-4.0, -yr), (-4.25, -2.55), (-3.15, -2.62)], -0.42, 0.24, M["vdg"])
    for (x, y) in ((-3.2, -2.6), (-3.55, -2.58), (-3.95, -2.54)):
        lot.put(M["acier"], G.tube([sh2((x, -2.45, 0.0)), sh2((x - 0.08, y - 0.22, 0.0))], 0.025, 5))
    # tuyères
    for s, rz, ry in ((-1, 0.33, 0.14), (1, -0.1, 0.0)):
        att = (-2.05, s * 1.25, -0.42)

        def nac(p, att=att, rz=rz, ry=ry):
            return G.add(G.rot_z(G.rot_y(p, ry), rz), att)
        lot.xf = P.compose(nac)
        R, xav, xar = 0.74, 0.0, -2.55
        sn = C.surf_nac(R, xav, xar)
        C.noyau(lot, M["noyau"], sn, 0.05, xar - 0.02, 0.0, TAU)
        C.blindage(lot, sn, -0.04, xar, 0.0, TAU, mats_coque, r, Mriv=M["riv"], larg=(0.38, 0.7), arcs=(0.38, 0.7))
        for xb in (-0.62, -1.48, -2.25):
            rr_ = C.r_nacelle(xb, R, xav, xar)
            lot.put(M["acier"], G.tour([(xb - 0.07, rr_ + 0.01), (xb - 0.06, rr_ + 0.1), (xb + 0.06, rr_ + 0.1), (xb + 0.07, rr_ + 0.01)], 32, "x"))
        re = C.r_nacelle(0.0, R, xav, xar)
        lot.put(M["acier"], G.tour([(-0.02, re * 1.03), (0.05, re * 1.06), (0.08, re * 0.85), (0.03, re * 0.62)], 32, "x"))
        lot.put(M["brule"], G.tour([(0.02, re * 0.64), (-0.18, 0.0)], 24, "x"))
        for k in range(7):
            a = TAU * k / 7
            lot.put(M["acier"], G.boite((0.0, re * 0.32 * math.cos(a), re * 0.32 * math.sin(a)), (0.03, 0.05, re * 0.62), 0.0, a))
        C.cloche(lot, M["acier"], M["acier"], M["brule"], M["cuivre"], xar, R)
        if deco_nac:
            deco_nac(lot, M, R, s)
    lot.xf = None
    # jambes des côtes
    for (pn, ps) in pieds:
        for p in (pn, ps):
            h = p[2]
            lot.put(M["acier"], G.boite((p[0], p[1], h / 2), (0.15, 0.17, h)))
            lot.put(M["acier"], G.boite((p[0], p[1], h - 0.15), (0.24, 0.26, 0.12)))
            lot.put(M["pierre"], G.boite((p[0], p[1], 0.17), (0.44, 0.44, 0.34), 0.1))
            lot.put(M["acier"], G.boite((p[0], p[1], 0.36), (0.26, 0.28, 0.05)))
            lot.put(M["riv"], G.rivets_le_long([((p[0] + dx, p[1] + dy, 0.385), (0, 0, 1)) for dx in (-0.09, 0.09) for dy in (-0.1, 0.1)], 0.022, 0.016))
    return pieds


def menus_coque(lot, M, P, r, n=90):
    """Menus détails clairs et sombres sur la coque (équerres, regards)."""
    mats = [M["acier"], M["noyau"], M["acier_clair"], M["riv"]]
    old = lot.xf
    lot.xf = P.xf
    for k in range(n):
        x, a = r.f(-2.1, 5.0), math.pi / 2 + r.f(-1.0, 1.0)
        p, nn = C.point(x, a, 0.05), C.normale_s(C.surf_coque, x, a)
        lot.put(mats[k % 4], C.pose_plane(G.boite((0, 0, 0.02), (r.f(0.05, 0.14), r.f(0.04, 0.1), 0.05), rz=r.f(-0.7, 0.7)), p, nn))
    lot.xf = old


def grille_coque(lot, M, P, liste):
    """Grilles à lames posées sur la coque : (x, a, largeur, longueur)."""
    old = lot.xf
    lot.xf = None
    for (x, a, w, l) in liste:
        p = P.xf(C.point(x, a, 0.07))
        n = G.norm(G.sub(P.xf(C.point(x, a, 0.3)), p))
        lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (l + 0.06, w + 0.06, 0.04)), p, n))
        lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.015), (l, w, 0.03)), p, n))
        for k in range(6):
            lot.put(M["acier"], C.pose_plane(G.boite((-l / 2 + l * (k + 0.5) / 6, 0, 0.035), (l / 6 * 0.45, w, 0.025)), p, n))
    lot.xf = old


# ================================================================================================ kit de l'ère
def garde(lot, M, pts, h=0.42, pas=0.42):
    """Garde-corps le long d'une polyligne : main courante, lisse, montants."""
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        lot.put(M["acier"], G.tube([G.add(a, (0, 0, h)), G.add(b, (0, 0, h))], 0.018, 5))
        lot.put(M["acier"], G.tube([G.add(a, (0, 0, h * 0.5)), G.add(b, (0, 0, h * 0.5))], 0.012, 5))
        n = max(1, int(G.length(G.sub(b, a)) / pas))
        for j in range(n + 1):
            q = G.lerp(a, b, j / float(n))
            lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, h))], 0.014, 5))


def echelle(lot, M, a, z1, w=0.2, axe="x", pas=0.15):
    """Échelle verticale de a (x, y, z0) à z1, montants écartés de w le long de l'axe x ou y."""
    d = (w / 2, 0, 0) if axe == "x" else (0, w / 2, 0)
    for s in (-1, 1):
        q = G.add(a, G.mul(d, s))
        lot.put(M["acier"], G.tube([q, (q[0], q[1], z1)], 0.012, 4))
    n = int((z1 - a[2]) / pas)
    for k in range(1, n + 1):
        z = a[2] + pas * k
        lot.put(M["acier"], G.tube([(a[0] - d[0], a[1] - d[1], z), (a[0] + d[0], a[1] + d[1], z)], 0.008, 3))


def escalier(lot, M, a, b, w=0.3, pas=0.09):
    """Volée droite de a à b (points bas et haut, axes x, y quelconques) : limons, marches, rampe."""
    d = G.sub(b, a)
    L = math.hypot(d[0], d[1])
    ex = (d[0] / L, d[1] / L, 0.0)
    ey = (-ex[1], ex[0], 0.0)
    n = max(2, int(abs(d[2]) / pas))
    for s in (-1, 1):
        o = G.mul(ey, s * w / 2)
        lot.put(M["acier"], G.tube([G.add(a, o), G.add(b, o)], 0.025, 4))
        lot.put(M["acier"], G.tube([G.add(G.add(a, o), (0, 0, 0.36)), G.add(G.add(b, o), (0, 0, 0.36))], 0.014, 4))
        for t in (0.0, 0.34, 0.67, 1.0):
            q = G.add(G.lerp(a, b, t), o)
            lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, 0.36))], 0.012, 4))
    rz = math.atan2(ex[1], ex[0])
    for k in range(n):
        q = G.lerp(a, b, (k + 0.5) / n)
        lot.put(M["acier_clair"], G.boite(q, (L / n * 0.7, w, 0.02), rz))


def caillebotis(lot, M, c, sx, sy, z, rz=0.0, h=0.03, pas=0.1):
    """Plancher de passerelle : lames serrées (ajouré, lit en ligne fine), longerons."""
    with dans(lot, (c[0], c[1], z), rz):
        n = max(2, int(sx / pas))
        for i in range(n):
            lot.put(M["acier"], G.boite((-sx / 2 + sx * (i + 0.5) / n, 0.0, 0.0), (sx / n * 0.72, sy, h)))
        for s in (-1, 1):
            lot.put(M["acier"], G.boite((0.0, s * sy / 2, -0.03), (sx, 0.04, 0.07)))


def cuve(lot, M, kc, c, L, R, rz=0.0, bandes=(), kb="noir", cercles=None, selles=True, zs=None):
    """CUVE HORIZONTALE (axe x local, signature de l'âge 4) : fonds bombés, viroles soudées, cerclages rivetés, bandes,
    trou d'homme, soupape, selles. c = centre de l'axe (monde). zs : niveau de pose (défaut 0 relatif au repère courant)."""
    e = R * 0.5
    prof = [(-L / 2 - e * math.cos(t), R * math.sin(t)) for t in [0.08 + (math.pi / 2 - 0.08) * i / 6.0 for i in range(7)]]
    prof += [(L / 2 + e * math.sin(t), R * math.cos(t)) for t in [(math.pi / 2 - 0.08) * i / 6.0 for i in range(7)]]
    prof = [(-L / 2 - e, 0.0)] + prof + [(L / 2 + e, 0.0)]
    with dans(lot, c, rz):
        lot.put(M[kc], G.tour(prof, 40, "x"))
        for (x0, x1) in bandes:
            lot.put(M[kb], G.tour([(x0, R + 0.002), (x0 + 0.005, R + 0.012), (x1 - 0.005, R + 0.012), (x1, R + 0.002)], 40, "x"))
        nc = cercles if cercles is not None else max(2, int(L / 0.7))
        for i in range(nc):
            x = -L / 2 + L * (i + 0.5) / nc + (0.06 if i % 2 else -0.04)
            lot.put(M["acier"], G.tour([(x - 0.035, R + 0.004), (x - 0.03, R + 0.03), (x + 0.03, R + 0.03), (x + 0.035, R + 0.004)], 40, "x"))
            pts = [((x, (R + 0.03) * math.cos(t), (R + 0.03) * math.sin(t)), (0.0, math.cos(t), math.sin(t))) for t in [-0.5 + 3.8 * k / 22.0 for k in range(23)]]
            lot.put(M["riv"], G.rivets_le_long(pts, 0.016, 0.01))
        for x in (-L / 2, L / 2):                                       # soudures des fonds
            lot.put(M["acier"], G.tour([(x - 0.02, R + 0.002), (x, R + 0.016), (x + 0.02, R + 0.002)], 40, "x"))
        xm = -L * 0.18                                                  # trou d'homme boulonné, soupape, piquage
        lot.put(M["acier"], G.tour([(R - 0.02, 0.2), (R + 0.09, 0.2), (R + 0.09, 0.26), (R + 0.13, 0.26), (R + 0.135, 0.0)], 16, "z", (xm, 0.0, 0.0)))
        pts = [((xm + 0.22 * math.cos(TAU * k / 10), 0.22 * math.sin(TAU * k / 10), R + 0.135), (0, 0, 1)) for k in range(10)]
        lot.put(M["riv"], G.rivets_le_long(pts, 0.014, 0.012))
        xs = L * 0.26
        lot.put(M["acier"], G.tour([(R - 0.02, 0.05), (R + 0.2, 0.05), (R + 0.2, 0.09), (R + 0.24, 0.09), (R + 0.3, 0.03), (R + 0.36, 0.0)], 10, "z", (xs, 0.0, 0.0)))
        if selles:
            for x in (-L * 0.32, L * 0.32):
                lot.put(M["pierre"], G.boite((x, 0.0, -R * 0.78 - c[2] * 0.0), (0.28, R * 1.5, R * 0.6)))
                lot.put(M["acier"], G.boite((x, 0.0, -R * 0.5), (0.1, R * 1.65, 0.05)))


def vanne(lot, M, c, r=0.13, h=0.26, kv="rouge", axe="z"):
    """Vanne à volant : corps, tige, volant à rayons (signature pétrole)."""
    with dans(lot, c):
        lot.put(M["acier"], G.tour([(0.0, 0.05), (0.12, 0.06), (0.14, 0.03), (h, 0.016)], 8, "z"))
        rt = 0.016
        prof = [(h + rt * math.sin(TAU * k / 8), r + rt * math.cos(TAU * k / 8)) for k in range(9)]
        lot.put(M[kv], G.tour(prof, 14, "z"))
        for k in range(3):
            a = TAU * k / 3 + 0.4
            lot.put(M[kv], G.tube([(0, 0, h), (r * math.cos(a), r * math.sin(a), h)], 0.011, 4))


def fut(lot, M, km, x, y, z=0.0, r=0.15, h=0.44):
    lot.put(M[km], G.tour([(z, r), (z + h, r)], 16, "z", (x, y, 0.0), cap1=True))
    for dz in (0.08, h - 0.08):
        lot.put(M["acier"], G.tour([(z + dz - 0.015, r + 0.006), (z + dz + 0.015, r + 0.006)], 16, "z", (x, y, 0.0)))
    lot.put(M["acier"], G.tour([(z + h, 0.03), (z + h + 0.03, 0.03)], 8, "z", (x + 0.07, y, 0.0), cap1=True))


def couche(mesh, q, rz, r=0.14):
    v, f, u = mesh
    return [G.add(G.rot_z(p, rz), (q[0], q[1], r)) for p in v], f, u


def tore(R, rt, c=(0.0, 0.0, 0.0), axe="z", segs=40, n=10):
    prof = [(rt * math.sin(TAU * k / n), R + rt * math.cos(TAU * k / n)) for k in range(n + 1)]
    return G.tour(prof, segs, axe, c)


def dalle(pts, n, g0, g1, gs=None):
    """Plaque convexe plane pts (ordre quelconque cohérent), épaisseur de g0 à g1 le long de n ; gs : relevé du dessus,
    sommet par sommet (écaille : bord bas soulevé)."""
    n = G.norm(n)
    e1 = G.norm(G.sub(pts[1], pts[0]))
    e2 = G.cross(n, e1)
    m = len(pts)
    top = [G.add(p, G.mul(n, g1 + (gs[i] if gs else 0.0))) for i, p in enumerate(pts)]
    bot = [G.add(p, G.mul(n, g0)) for p in pts]
    v = top + bot
    uv = [(G.dot(p, e1), G.dot(p, e2)) for p in top] + [(G.dot(p, e1), G.dot(p, e2)) for p in bot]
    f = [tuple(range(m))]
    for i in range(m):
        j = (i + 1) % m
        f.append((i, m + i, m + j, j))
    return v, f, uv


def ecailles(lot, mats, A, B, Cc, D, rnd, rangs, larg=(0.28, 0.44), saut=0.0, trou=None, rivet=None):
    """ÉCAILLES de blindage (signature de l'âge 5) sur le quadrilatère A, B (bas), Cc, D (haut) : rangées de bas en haut,
    pointes vers le bas qui recouvrent la rangée d'en dessous, largeurs tirées, quinconce, tons tirés. mats(rnd) -> M."""
    n = G.norm(G.cross(G.sub(B, A), G.sub(D, A)))
    S = lambda u, v: G.lerp(G.lerp(A, B, u), G.lerp(D, Cc, u), v)
    Lb = G.length(G.sub(B, A))
    for i in range(rangs):
        v0, v1 = i / float(rangs), (i + 1) / float(rangs)
        dv = v1 - v0
        u = -rnd.f(0.0, larg[1] / max(Lb, 0.1))
        while u < 1.0:
            w = rnd.f(*larg) / max(Lb, 0.1)
            u0, u1 = max(0.0, u), min(1.0, u + w)
            u += w
            if u1 - u0 < 0.25 * w or rnd.f() < saut:
                continue
            um = (u0 + u1) / 2
            if trou and trou(um, (v0 + v1) / 2):
                continue
            vb = max(0.0, v0 - dv * 0.28)
            tip = max(0.0, v0 - dv * 0.62)
            pts = [S(u0, v1 + dv * 0.1 if v1 < 1 else v1), S(u0, vb), S(um, tip), S(u1, vb), S(u1, v1 + dv * 0.1 if v1 < 1 else v1)]
            leve = rnd.f(0.035, 0.075)
            gs = [0.0, leve * 0.7, leve, leve * 0.7, 0.0]
            lot.put(mats(rnd), dalle(pts, n, -0.01, 0.018, gs))
            if rivet is not None and rnd.f() < 0.75:
                p = G.add(S(um, v0 + dv * 0.62), G.mul(n, 0.022 + leve * 0.45))
                lot.put(rivet, G.rivets_le_long([(p, n)], 0.032, 0.022))


def pile_iso(lot, M, x, y, z0, n, r=0.2, pas=0.12, ke="pierre_cer", ka="acier"):
    """PILE D'ISOLATEURS (signature de l'âge 6) : disques de céramique empilés, colonne crantée ; brides d'acier."""
    prof = []
    for k in range(n):
        z = z0 + pas * k
        prof += [(z, r * 0.5), (z + pas * 0.18, r * 0.95), (z + pas * 0.3, r), (z + pas * 0.42, r * 0.92), (z + pas * 0.62, r * 0.56), (z + pas, r * 0.5)]
    lot.put(M[ke], G.tour(prof, 20, "z", (x, y, 0.0)))
    z1 = z0 + pas * n
    lot.put(M[ka], G.tour([(z0 - 0.07, r * 0.85), (z0 - 0.02, r * 0.85), (z0, r * 0.52)], 16, "z", (x, y, 0.0)))
    lot.put(M[ka], G.tour([(z1, r * 0.52), (z1 + 0.02, r * 0.72), (z1 + 0.06, r * 0.72), (z1 + 0.09, r * 0.3), (z1 + 0.11, 0.0)], 14, "z", (x, y, 0.0)))
    return z1 + 0.1


def eclair(lot, M, a, b, rnd, n=9, amp=0.14, r=0.012, branches=2):
    """Arc électrique : ligne brisée, tirée, entre a et b ; 1 à 2 branches courtes."""
    pts = [a]
    for i in range(1, n):
        q = G.lerp(a, b, i / float(n))
        pts.append(G.add(q, (rnd.f(-amp, amp), rnd.f(-amp, amp) * 0.5, rnd.f(-amp, amp))))
    pts.append(b)
    lot.put(M, G.tube(pts, r, 5))
    for k in range(branches):
        i = rnd.i(2, n - 2)
        c = G.add(pts[i], (rnd.f(-amp, amp) * 2, 0.0, rnd.f(-amp, amp) * 2))
        lot.put(M, G.tube([pts[i], G.lerp(pts[i], c, 0.5), c], r * 0.6, 4))


def debris(lot, M, liste):
    """Débris au sol : (genre, x, y, …) comme à l'âge 8 ; km : clés de M des plaques (claire si grande, seconde sinon)."""
    for d in liste:
        k, x, y = d[0], d[1], d[2]
        if k == "plaque":
            lot.put(M["jaune1"] if d[3] > 0.52 else M["vdg"], G.boite((x, y, 0.06), (d[3], d[4], 0.03), d[5], 0.35, 0.15))
        elif k == "fut":
            lot.put(M["rapiece2"], couche(G.tour([(-0.22, 0.14), (0.22, 0.14)], 14, "x", cap0=True, cap1=True), (x, y), d[3]))
            lot.put(M["acier"], couche(G.tour([(-0.13, 0.148), (-0.1, 0.148)], 14, "x"), (x, y), d[3]))
        elif k == "caisse":
            lot.put(M["bois"], G.boite((x, y, d[3] / 2), (d[3], d[4], d[3]), d[5], 0.0, 0.08))
        elif k == "tuyau":
            lot.put(M["conduit"], couche(G.tour([(-d[3] / 2, d[4] * 2), (d[3] / 2, d[4] * 2)], 10, "x", cap0=True, cap1=True), (x, y), d[5], d[4] * 2))
        elif k == "pneu":
            lot.put(M["caoutchouc"], G.tour([(0.0, d[3]), (0.06, d[3] + 0.025), (0.12, d[3])], 16, "z", (x, y, 0.0)))


def ferraille(lot, M, ra, n=22, zone=(-5.8, 5.8, -4.0, 3.9), garde_x=4.5, garde_y=3.0):
    """Ferraille au sol hors du pied du bâtiment : éclats et cornières."""
    for k in range(n):
        x, y = ra.f(zone[0], zone[1]), ra.f(zone[2], zone[3])
        if abs(y) < garde_y and abs(x) < garde_x:
            continue
        if ra.f() < 0.5:
            lot.put(M["acier"] if ra.f() < 0.5 else M["jaune1"], G.boite((x, y, 0.02), (ra.f(0.08, 0.2), ra.f(0.05, 0.12), 0.03), ra.f(0, 3.0), ra.f(-0.3, 0.3)))
        else:
            lot.put(M["acier"], G.boite((x, y, 0.03), (ra.f(0.25, 0.45), 0.04, 0.04), ra.f(0, 3.0)))


def mat_nez(lot, M, P):
    """Mât treillis sur le crâne (âge 8), voyant au sommet."""
    m0 = P.xf((2.9, 0.0, C.z_dessus(2.9) + 0.12))
    lot.put(M["acier"], G.tube([m0, G.add(m0, (0, 0, 1.3))], 0.03, 6))
    for k in range(4):
        a = TAU * k / 4 + 0.4
        lot.put(M["acier"], G.tube([G.add(m0, (0.13 * math.cos(a), 0.13 * math.sin(a), 0.0)), G.add(m0, (0.02 * math.cos(a), 0.02 * math.sin(a), 1.25))], 0.012, 4))
    for z in (0.5, 0.9):
        lot.put(M["acier"], G.tube([G.add(m0, (-0.26, 0, z)), G.add(m0, (0.26, 0, z))], 0.013, 4))
    lot.put(M["voyant"], G.sphere(G.add(m0, (0, 0, 1.33)), 0.03, 6, 3))
