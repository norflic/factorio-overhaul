"""QG ÂGE 1 · PIONNIER (refonte QG du 30/10, brief fo-logs/2026-10-30_QG/BRIEF.md). Emprise 8×4, NEZ À DROITE (+X).

DA (docs/DESIGN_EPOQUES.md §5, « Époque 1 · Pionnier ») : matériaux de fortune ; silhouette basse, trapue, irrégulière ;
sacs de sable, rondins, planches, bâches, cordages ; caisse en bois, lanterne à huile, mât en bois, rouleau de barbelé ;
fer brut #5A5048, bois #6B4F35, toile #8A7A5A ; de jour aucune lueur (seul le cœur-réacteur de la carcasse, élément
commun du brief, reste le foyer). Fiche du centre : « cabane en rondins à toit de tôle ondulée, sur plate-forme de
rondins ; rempart de sacs de sable en U devant la porte sud ; mât de drapeau en bois à l'arrière gauche ».

Carcasse (brief §3, refaite de zéro : PAS le cigare de vaisseau.py) : coque à 3 volumes (bloc moteur carré, fuselage,
crâne à bosse de verrière et bec qui plonge), axe tourné de −7,5° (nez vers le sud-est), roulis de 15° (le dos se
montre), 2 grosses tuyères à gauche, ailes en flèche hors du plan, dérive dressée, épine dorsale à vertèbres, brèche
au flanc sud où la peau manque (côtes « (((( » balayées vers la queue, intérieur noir, cœur orange).
Repère : vaisseau (x le long de l'axe, a = angle de section : 0 nord, π/2 dos, π sud, 3π/2 ventre) → monde par SHIP().
Seuls geo.py, mat.py et les outils génériques de vaisseau.py (plaques sur une surface quelconque) sont réutilisés.
"""
import math

import geo as G
import mat as MT
import vaisseau as V

PI = math.pi
TAU = 2 * PI
X_Q, X_N = -2.6, 3.75
ROLL, YAW, Z_AXE = 0.26, -0.13, 1.0
NAC_Y, NAC_Z, NAC_R, NAC_X0, NAC_X1 = 1.04, 0.86, 0.6, -0.55, -2.72


def sm(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------------------------------------ coque
def sec(x):
    """(zc, demi-largeur, haut, bas, exposant) de la section à l'abscisse x (repère du vaisseau)."""
    zc, w, ht, hb, ex = Z_AXE, 0.98, 0.78, 0.64, 3.0
    tb = sm((-1.25 - x) / 0.45)                    # bloc moteur : plus large, plus haut, carré
    w += 0.1 * tb
    ht += 0.12 * tb
    ex += 1.8 * tb
    hb -= 0.04 * tb
    if 0.55 < x < 2.45:                            # bosse de la verrière
        ht += 0.2 * math.sin(PI * (x - 0.55) / 1.9) ** 1.4
    if x > 0.9:                                    # crâne : ogive anguleuse qui plonge (bec)
        t = min(1.0, (x - 0.9) / (X_N - 0.9))
        f = math.sqrt(max(0.0, 1.0 - t ** 1.7))
        w = 0.06 + (w - 0.06) * f
        ht = 0.05 + (ht - 0.05) * (1.0 - t ** 1.25) ** 0.8
        hb = 0.08 + (hb - 0.08) * f ** 0.9
        zc -= 0.34 * t * t
        ex -= 0.7 * t
    if x < -2.25:
        t = min(1.0, (-2.25 - x) / 0.35)
        w -= 0.1 * t
        ht -= 0.1 * t
    return zc, w, ht, hb, ex


def P(x, a, g=0.0):
    zc, w, ht, hb, ex = sec(x)
    c, s = math.cos(a), math.sin(a)
    e = 2.0 / ex
    y = (w + g) * math.copysign(abs(c) ** e, c)
    z = zc + ((ht if s > 0 else hb) + g) * math.copysign(abs(s) ** e, s)
    return (x, y, z)


def SHIP(p):
    q = G.rot_x(p, ROLL, (0.0, 0.0, Z_AXE))
    q = G.rot_z(q, YAW, (0.4, 0.0, 0.0))
    return (q[0] + 0.1, q[1] + 0.12, max(0.0, q[2] - 0.04))


def W(x, a, g=0.0):
    return SHIP(P(x, a, g))


def WN(x, a):
    """Normale monde de la coque."""
    p, q = W(x, a, 0.0), W(x, a, 0.1)
    return G.norm(G.sub(q, p))


def surf(x, a, g):
    return P(x, a, g)


def r_nac(x):
    if x > NAC_X0 - 0.35:
        t = sm((x - (NAC_X0 - 0.35)) / 0.45)
        return NAC_R * (1.0 - 0.42 * t)
    if x < NAC_X1 + 0.3:
        return NAC_R * (1.0 - 0.1 * sm((NAC_X1 + 0.3 - x) / 0.3))
    return NAC_R


def surf_nac(s):
    def f(x, a, g):
        r = r_nac(x) + g
        return (x, s * NAC_Y + r * math.cos(a), NAC_Z + r * math.sin(a))
    return f


# ------------------------------------------------------------------------------------------------ outils
def rondin(lot, M, Mb, a, b, r, seg=10):
    lot.put(M, G.tube([a, b], r, seg, cap0=False, cap1=False))
    d = G.norm(G.sub(b, a))
    for p, n in ((a, G.mul(d, -1.0)), (b, d)):
        lot.put(Mb, G.oriente(G.tour([(0.0, r * 0.99), (0.004, r * 0.6), (0.006, 0.0)], seg, "z", cap0=True), p, n))


def sac(c, L, Wd, H, rz=0.0, ry=0.0, n=10, m=6):
    """Sac de sable : superellipsoïde aplati, ventre affaissé."""
    rings = []
    for i in range(m + 1):
        th = -PI / 2 + PI * i / m
        ct, st = math.cos(th), math.sin(th)
        ring = []
        for j in range(n):
            ph = TAU * j / n
            cp, sp = math.cos(ph), math.sin(ph)
            x = L / 2 * math.copysign(abs(ct) ** 0.45, ct) * math.copysign(abs(cp) ** 0.3, cp)
            y = Wd / 2 * math.copysign(abs(ct) ** 0.45, ct) * math.copysign(abs(sp) ** 0.4, sp)
            z = H / 2 * math.copysign(abs(st) ** 0.6, st)
            z -= 0.18 * H * max(0.0, st) * (1.0 - abs(cp))
            p = G.rot_y((x, y, z), ry)
            p = G.rot_z(p, rz)
            ring.append(G.add(p, c))
        rings.append(ring)
    return G.loft(rings, closed=True)


def tole_ondulee(o, eu, ev, Lu, Lv, pas=0.09, amp=0.014, k=5):
    n = G.norm(G.cross(eu, ev))
    if n[2] < 0:
        n = G.mul(n, -1.0)
    nu = max(2, int(Lu / pas * k))
    verts, faces, uvs = [], [], []
    for i in range(nu + 1):
        u = Lu * i / nu
        off = amp * math.sin(TAU * u / pas)
        for v in (0.0, Lv):
            verts.append(G.add(G.add(G.add(o, G.mul(eu, u)), G.mul(ev, v)), G.mul(n, off)))
            uvs.append((u, v))
    for i in range(nu):
        a = 2 * i
        faces.append((a, a + 2, a + 3, a + 1))
    return verts, faces, uvs


def tole_plane(pts, ep=0.02):
    """Plaque à 4 coins (convexe) d'épaisseur ep vers +Z local approximé par la normale."""
    n = G.norm(G.cross(G.sub(pts[1], pts[0]), G.sub(pts[3], pts[0])))
    top = [G.add(p, G.mul(n, ep)) for p in pts]
    m = G.loft([pts, top], closed=True)
    return G.merge(m, (top, [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)]),
                   (list(reversed(pts)), [(0, 1, 2, 3)], [(0, 0), (1, 0), (1, 1), (0, 1)]))


def cables(lot, Ms, a, b, fl, n=3, r=0.013, ecart=0.03):
    for i in range(n):
        d = (i - (n - 1) / 2.0) * ecart
        lot.put(Ms[i % len(Ms)], G.tube(G.chainette(G.add(a, (0, d, 0)), G.add(b, (d * 0.5, d, 0)), fl * (1 + 0.15 * i), 16),
                                        r, 6))


def tonneau(lot, M, Mc, c, r=0.14, h=0.4, couche=False, rz=0.0):
    prof = [(0.0, r * 0.92), (0.02, r), (h * 0.5, r * 1.06), (h - 0.02, r), (h, r * 0.92)]
    if couche:
        mesh = G.tour(prof, 16, "x", cap0=True, cap1=True)
        v, f, u = mesh
        v = [G.add(G.rot_z(p, rz), c) for p in v]
        lot.put(M, (v, f, u))
        for z in (0.06, h - 0.06):
            v2, f2, u2 = G.tour([(z - 0.015, r * 1.05), (z + 0.015, r * 1.05)], 16, "x")
            lot.put(Mc, ([G.add(G.rot_z(p, rz), c) for p in v2], f2, u2))
        return
    lot.put(M, G.tour(prof, 16, "z", c, cap0=True, cap1=True))
    for z in (0.06, h * 0.5, h - 0.06):
        rr = r * (1.06 if abs(z - h * 0.5) < 0.01 else 1.0) + 0.006
        lot.put(Mc, G.tour([(z - 0.014, rr), (z + 0.014, rr)], 16, "z", c))


def caisse(lot, M, M2, Mf, c, s, rz=0.0):
    x, y, z = c
    lot.put(M, G.boite((x, y, z + s[2] / 2), s, rz))
    nb = 4
    for i in range(nb):
        t = (i + 0.5) / nb - 0.5
        q = G.rot_z((t * s[0], -s[1] / 2 - 0.006, 0.0), rz)
        lot.put(M2 if i % 2 else M, G.boite((x + q[0], y + q[1], z + s[2] / 2), (s[0] / nb - 0.012, 0.012, s[2] - 0.02), rz))
    for t in (-0.42, 0.42):
        q = G.rot_z((t * s[0], 0.0, 0.0), rz)
        lot.put(Mf, G.boite((x + q[0], y + q[1], z + s[2] / 2), (0.025, s[1] + 0.02, s[2] + 0.02), rz))
    lot.put(M2, G.boite((x, y, z + s[2] + 0.006), (s[0] - 0.05, s[1] - 0.05, 0.012), rz))


def lanterne(lot, Mfer, Mverre, p):
    x, y, z = p
    lot.put(Mfer, G.tour([(0.0, 0.035), (0.012, 0.04), (0.02, 0.025), (0.09, 0.025), (0.1, 0.04), (0.13, 0.012), (0.16, 0.004)],
                         8, "z", (x, y, z - 0.16), cap0=True))
    lot.put(Mverre, G.tour([(0.02, 0.032), (0.09, 0.032)], 8, "z", (x, y, z - 0.16)))
    lot.put(Mfer, G.tube([(x, y, z), (x, y, z + 0.05)], 0.006, 4))


# ------------------------------------------------------------------------------------------------ matières
JAUNES = ((0.3, 0.17, 0.01), (0.24, 0.13, 0.008), (0.35, 0.21, 0.016), (0.21, 0.13, 0.014))


def matieres(S):
    M = {}
    for i, c in enumerate(JAUNES):
        M["j%d" % i] = MT.surface("q1_j%d" % i, c, rough=0.52, met=0.2, grain=0.32, coulures=1.0, usure=1.0,
                                  nu=(0.62, 0.55, 0.42), crasse=1.0, crasse_col=(0.005, 0.004, 0.003), pied=(0.0, 1.0, 0.85),
                                  biseau=0.03, graine=1 + i)
    M["chev"] = MT.surface("q1_chev", JAUNES[0], rough=0.5, met=0.2, grain=0.3, bandes=(0.2, (0.008, 0.007, 0.006), 0.5), usure=1.0,
                           nu=(0.36, 0.33, 0.29), crasse=0.7, graine=8)
    M["rap"] = MT.surface("q1_rap", (0.085, 0.068, 0.05), rough=0.45, met=0.8, grain=0.3, coulures=1.0, usure=0.8, crasse=1.0, graine=4)
    M["rap2"] = MT.surface("q1_rap2", (0.17, 0.065, 0.025), rough=0.55, met=0.5, grain=0.3, coulures=1.0, usure=0.6, crasse=1.0, graine=19)
    M["noyau"] = MT.surface("q1_noyau", (0.015, 0.014, 0.013), rough=0.6, met=0.6, usure=0.2, crasse=0.8, graine=5)
    M["int"] = MT.surface("q1_int", (0.008, 0.007, 0.007), rough=0.8, met=0.3, usure=0.0, crasse=0.9, graine=21)
    M["acier"] = MT.surface("q1_acier", (0.045, 0.038, 0.032), rough=0.42, met=0.85, grain=0.25, usure=1.0, nu=(0.45, 0.4, 0.34),
                            crasse=0.7, coulures=0.5, graine=6)
    M["acier_c"] = MT.surface("q1_acier_c", (0.17, 0.15, 0.125), rough=0.4, met=0.85, usure=0.5, crasse=0.55, graine=7)
    M["riv"] = MT.surface("q1_riv", (0.1, 0.075, 0.03), rough=0.6, met=0.3, usure=0.3, crasse=0.6, graine=15)
    M["brule"] = MT.surface("q1_brule", (0.02, 0.016, 0.014), rough=0.75, met=0.5, usure=0.0, crasse=0.8, graine=9)
    M["bague"] = MT.surface("q1_bague", (0.09, 0.08, 0.068), rough=0.38, met=0.9, usure=0.8, nu=(0.45, 0.43, 0.4),
                            crasse=0.7, coulures=0.5, graine=14)
    M["verre"] = MT.verre("q1_verre")
    M["noir"] = MT.surface("q1_noir", (0.014, 0.014, 0.014), rough=0.7, met=0.0, usure=0.2, crasse=0.3, graine=10)
    M["rouge"] = MT.surface("q1_rouge", (0.3, 0.02, 0.012), rough=0.55, met=0.0, usure=0.3, crasse=0.4, graine=13)
    M["cuivre"] = MT.surface("q1_cuivre", (0.42, 0.17, 0.07), rough=0.4, met=0.9, usure=0.4, crasse=0.65, graine=11)
    M["caout"] = MT.surface("q1_caout", (0.03, 0.03, 0.028), rough=0.75, met=0.0, usure=0.2, crasse=0.4, graine=22)
    # âge 1 : bois grisé, rondins, planches, toile, jute, tôle ondulée, fer brut (#5A5048), corde
    M["rondin"] = MT.surface("q1_rondin", (0.1, 0.058, 0.025), rough=0.85, met=0.0, grain=0.35, usure=0.6,
                             nu=(0.3, 0.22, 0.14), crasse=0.8, coulures=0.3, rouille=(0.05, 0.035, 0.02), graine=31)
    M["rondin2"] = MT.surface("q1_rondin2", (0.07, 0.042, 0.02), rough=0.85, met=0.0, grain=0.35, usure=0.6,
                              nu=(0.26, 0.19, 0.12), crasse=0.8, graine=32)
    M["bout"] = MT.surface("q1_bout", (0.4, 0.25, 0.1), rough=0.85, met=0.0, grain=0.25, usure=0.0, crasse=0.6, graine=33)
    M["planche"] = MT.surface("q1_planche", (0.17, 0.1, 0.042), rough=0.82, met=0.0, grain=0.32, usure=0.6,
                              nu=(0.38, 0.3, 0.2), crasse=0.75, coulures=0.4, rouille=(0.06, 0.045, 0.03), graine=34)
    M["planche2"] = MT.surface("q1_planche2", (0.115, 0.068, 0.03), rough=0.82, met=0.0, grain=0.32, usure=0.6,
                               nu=(0.32, 0.25, 0.17), crasse=0.75, graine=35)
    M["toile"] = MT.surface("q1_toile", (0.2, 0.135, 0.055), rough=0.92, met=0.0, grain=0.3, usure=0.0, crasse=0.85,
                            coulures=0.6, rouille=(0.1, 0.08, 0.05), pied=(0.0, 0.9, 0.5), graine=36)
    M["jute"] = MT.surface("q1_jute", (0.17, 0.105, 0.04), rough=0.95, met=0.0, grain=0.35, usure=0.0, crasse=0.9,
                           pied=(0.0, 0.35, 0.5), graine=37)
    M["jute2"] = MT.surface("q1_jute2", (0.13, 0.08, 0.032), rough=0.95, met=0.0, grain=0.35, usure=0.0, crasse=0.9,
                            pied=(0.0, 0.35, 0.5), graine=38)
    M["ondule"] = MT.surface("q1_ondule", (0.17, 0.16, 0.15), rough=0.45, met=0.75, coulures=1.0, usure=0.5,
                             rouille=(0.26, 0.1, 0.04), crasse=0.6, graine=39)
    M["ondule2"] = MT.surface("q1_ondule2", (0.22, 0.1, 0.045), rough=0.6, met=0.5, coulures=0.8, usure=0.4,
                              crasse=0.6, graine=40)
    M["fer"] = MT.surface("q1_fer", (0.085, 0.06, 0.04), rough=0.6, met=0.7, grain=0.3, coulures=1.0, usure=0.6, crasse=0.7, graine=41)
    M["corde"] = MT.surface("q1_corde", (0.35, 0.28, 0.17), rough=0.95, met=0.0, grain=0.2, usure=0.0, crasse=0.5, graine=42)
    M["drapeau"] = MT.surface("q1_drapeau", (0.32, 0.05, 0.03), rough=0.9, met=0.0, grain=0.15, usure=0.0, crasse=0.6,
                              graine=43)
    M["terre"] = MT.surface("q1_terre", (0.11, 0.065, 0.032), rough=0.95, met=0.0, grain=0.3, usure=0.0, crasse=0.6, graine=44)
    M["pierre"] = MT.surface("q1_pierre", (0.17, 0.155, 0.14), rough=0.85, met=0.0, grain=0.25, usure=0.3, crasse=0.7,
                             graine=45)
    M["cendre"] = MT.surface("q1_cendre", (0.03, 0.028, 0.026), rough=0.95, met=0.0, grain=0.3, usure=0.0, crasse=0.3,
                             graine=46)
    M["lanterne"] = MT.surface("q1_lanterne", (0.3, 0.2, 0.08), rough=0.2, met=0.0, usure=0.0, crasse=0.3, graine=47)
    M["coeur"] = MT.lumiere(S, "q1_coeur", (1.0, 0.36, 0.05), 4.0, main=0.0)
    M["voyant"] = MT.lumiere(S, "q1_voyant", (1.0, 0.1, 0.04), 7.0)
    return M


# ------------------------------------------------------------------------------------------------ carcasse
BRECHE = (0.12, 1.0, 1.88, 3.0)                  # x0, x1, a0, a1 : haut du flanc sud (vu de la caméra), la peau manque


def dans_breche(x, a):
    return BRECHE[0] < x < BRECHE[1] and BRECHE[2] < (a % TAU) < BRECHE[3]


def carcasse(lot, M, r):
    J = [M["j0"], M["j1"], M["j2"], M["j3"]]
    lot.xf = SHIP
    # noyau sombre (hors brèche), intérieur de la brèche, cloisons
    n = 70
    xs = [X_Q + (X_N - X_Q) * i / (n - 1) for i in range(n)]
    for x0, x1, a0, a1 in ((X_Q, BRECHE[0], 0.0, TAU), (BRECHE[1], X_N, 0.0, TAU), (BRECHE[0], BRECHE[1], BRECHE[3], BRECHE[2] + TAU)):
        xx = [x for x in xs if x0 <= x <= x1] or [x0, x1]
        xx = [x0] + [x for x in xx if x0 < x < x1] + [x1]
        m = max(6, int(48 * (a1 - a0) / TAU))
        plein = abs(a1 - a0 - TAU) < 1e-6
        lot.put(M["noyau"], G.loft([[P(x, a0 + (a1 - a0) * j / float(m if plein else m - 1), -0.006) for j in range(m)] for x in xx],
                                   closed=plein))
    bx0, bx1, ba0, ba1 = BRECHE
    xx = [bx0 + (bx1 - bx0) * i / 12.0 for i in range(13)]
    aa = [ba0 - 0.08 + (ba1 - ba0 + 0.16) * j / 16.0 for j in range(17)]
    lot.put(M["int"], G.loft([[P(x, a, -0.42) for a in aa] for x in xx], closed=False))
    for xv in (bx0, bx1):
        lot.put(M["int"], G.loft([[P(xv, a, -0.42) for a in aa], [P(xv, a, 0.0) for a in aa]], closed=False))
    # cœur-réacteur au fond de la brèche (le foyer de la carcasse), vu entre les côtes
    am = (ba0 + ba1) / 2
    xm = (bx0 + bx1) / 2
    cc = P(xm, am, -0.36)
    lot.put(M["acier"], G.tour([(-0.34, 0.15), (-0.3, 0.2), (0.3, 0.2), (0.34, 0.15)], 20, "x", cc, cap0=True, cap1=True))
    for xb in (-0.2, 0.0, 0.2):
        lot.put(M["coeur"], G.tour([(xb - 0.045, 0.206), (xb + 0.045, 0.206)], 20, "x", cc))
    for xb in (-0.28, -0.1, 0.1, 0.28):
        lot.put(M["bague"], G.tour([(xb - 0.018, 0.225), (xb + 0.018, 0.225)], 20, "x", cc))
    # tuyauterie intérieure de la brèche (3 diamètres) et faisceaux arrachés qui pendent
    V.tuyau(lot, M["acier"], M["acier_c"], [P(bx0 + 0.02, ba1 - 0.1, -0.2), P(xm - 0.2, ba1 - 0.1, -0.2), G.add(cc, (-0.36, 0, -0.05))],
            0.065, rb=0.1, pas_bride=0.3)
    V.tuyau(lot, M["cuivre"], M["acier_c"], [P(bx1 - 0.02, ba0 + 0.15, -0.15), P(xm + 0.2, ba0 + 0.15, -0.15), G.add(cc, (0.36, 0, 0.05))],
            0.042, rb=0.08, pas_bride=0.25)
    V.tuyau(lot, M["acier_c"], M["acier"], [P(bx0 + 0.02, am, -0.08), P(bx1 - 0.02, am, -0.08)], 0.026, pas_bride=0.3)
    V.flexible(lot, M["caout"], [G.add(cc, (-0.15, -0.1, 0.18)), P(xm - 0.25, am + 0.25, 0.05), P(xm - 0.3, ba1 + 0.05, 0.08)], 0.03,
               pas=0.05)
    for k, mc in enumerate(("rouge", "noir", "rouge")):
        d = 0.03 * k
        lot.put(M[mc], G.tube(G.catmull([P(bx1 - 0.08 - d, ba0 + 0.1, -0.05), P(bx1 - 0.18 - d, am + 0.1, 0.1),
                                         P(bx1 - 0.12 - d, ba1 + 0.15, 0.12)], 6), 0.013, 6))
    # blindage : bandes irrégulières, jours sombres, rivets ; trous pour la brèche, la verrière et la trappe
    XS = [-2.6, -2.3, -2.02, -1.7, -1.38, -1.08, -0.78, -0.5, -0.18, 0.12, 0.45, 0.78, 1.05, 1.32, 1.6, 1.9, 2.18, 2.46, 2.72, 3.0, 3.25, 3.48, 3.65, 3.75]

    def n_sect(i):
        zc, w, ht, hb, ex = sec((XS[i] + XS[i + 1]) / 2)
        return max(4, int(round(math.pi * (w + (ht + hb) / 2) * 1.1 / 0.46)) + (i % 3) - 1)

    def saut(xm, am):
        if dans_breche(xm, am):
            return True
        if 1.02 < xm < 2.4 and abs(am - PI / 2) < 0.62:          # verrière
            return True
        return False

    def mats(rr, i, j):
        if 2.7 < XS[i] < 3.05:
            return M["chev"]
        x = rr.f()
        if x < 0.12:
            return M["rap"]
        if x < 0.17:
            return M["rap2"]
        if x < 0.24:
            return M["acier"]
        return J[int(rr.f() * 4) % 4]
    V.plaques(lot, surf, XS, n_sect, mats, r, gap=0.042, g=(0.02, 0.075), saut=saut, rivet=M["riv"], pas_riv=0.12)
    V.doublures(lot, surf, 14, lambda rr: (M["rap"] if rr.f() < 0.35 else J[int(rr.f() * 4) % 4]), r, (-2.4, 0.4),
                (PI / 2 - 0.5, PI + 0.6), M["riv"])
    V.doublures(lot, surf, 6, lambda rr: J[int(rr.f() * 4) % 4], r, (1.0, 2.6), (PI / 2 + 0.7, PI + 0.5), M["riv"])
    # plaques arrachées au bord de la brèche (relevées, tordues)
    for (x0, x1, a0, a1, lift) in ((bx0 - 0.02, bx0 + 0.3, ba1 - 0.05, ba1 + 0.25, 0.5), (bx1 - 0.3, bx1 + 0.02, ba0 - 0.25, ba0 + 0.06, 0.45),
                                   (bx0 + 0.35, bx0 + 0.6, ba1 - 0.02, ba1 + 0.2, 0.35)):
        vv, ff, uu = V.plaque(surf, x0, x1, a0, a1, 0.0, 0.04)
        o = P((x0 + x1) / 2, a0 if a0 > ba0 else a1, 0.0)
        vv = [G.add(p, G.mul((0.0, -0.6, 0.35), lift * G.length(G.sub(p, o)))) for p in vv]
        lot.put(J[1], (vv, ff, uu))
    # côtes balayées vers la queue (lisibles « (((( » à l'écran) dans la brèche
    for xr in [bx0 + 0.1 + k * (bx1 - bx0 - 0.2) / 3.0 for k in range(4)]:
        rr_ = []
        for g in (0.04, -0.06):
            for dx in (-0.035, 0.035):
                ring = []
                for j in range(17):
                    a = ba0 - 0.12 + (ba1 - ba0 + 0.24) * j / 16.0
                    xx_ = xr + dx - 0.22 * (1.0 - math.sin(a)) * 0.5
                    ring.append(P(xx_, a, g))
                rr_.append(ring)
        rr_ = [rr_[0], rr_[1], rr_[3], rr_[2], rr_[0]]
        lot.put(M["acier"], G.loft(rr_, closed=False))
    for a in (2.2, 2.55, 2.85):                       # lisses (longerons) dans la brèche
        lot.put(M["acier"], G.tube([P(bx0, a, -0.02), P(bx1, a, -0.02)], 0.03, 6))
    # lisses extérieures (cassent la grille), épine dorsale à vertèbres
    for a, x0, x1 in ((PI - 0.55, -2.5, -2.0), (PI - 0.55, -0.3, 1.0), (0.62, -2.5, 1.1), (PI + 0.6, 0.0, 2.6)):
        V.lisse(lot, surf, M["acier"], M["riv"], a, x0, x1)
    sp = [P(x, PI / 2, 0.075) for x in [-2.5 + 0.1 * i for i in range(36)]]
    lot.put(M["acier"], G.tube(sp, 0.06, 8))
    for i in range(12):
        x = -2.4 + 0.3 * i
        if 1.0 < x < 2.4:
            continue
        p = P(x, PI / 2, 0.14)
        lot.put(M["bague"], G.boite(p, (0.11, 0.3, 0.1)))
        lot.put(M["acier"], G.boite(G.add(p, (0, 0, 0.1)), (0.07, 0.1, 0.16), ry=0.45))
    # nacelles : noyau, entrée d'air, cerclages, plaques, tuyères (intérieur brûlé)
    for s in (-1, 1):
        y, z = s * NAC_Y, NAC_Z
        xs_n = [NAC_X0 + 0.12 - (NAC_X0 + 0.12 - NAC_X1) * i / 24.0 for i in range(25)]
        lot.put(M["noyau"], G.tour([(x, r_nac(x) - 0.006) for x in xs_n], 36, "x", (0.0, y, z)))
        xe, re = NAC_X0 + 0.12, r_nac(NAC_X0 + 0.12)
        lot.put(M["bague"], G.tour([(xe - 0.02, re * 1.02), (xe + 0.05, re * 1.05), (xe + 0.07, re * 0.84), (xe + 0.02, re * 0.6)], 36, "x", (0, y, z)))
        lot.put(M["int"], G.tour([(xe + 0.01, re * 0.62), (xe - 0.16, 0.0)], 24, "x", (0, y, z)))
        for k in range(8):                         # aubes d'entrée d'air
            a = TAU * k / 8
            lot.put(M["acier"], G.tube([(xe - 0.02, y + 0.05 * math.cos(a), z + 0.05 * math.sin(a)),
                                        (xe + 0.02, y + re * 0.6 * math.cos(a), z + re * 0.6 * math.sin(a))], 0.012, 4))
        sn = surf_nac(s)
        XN = [NAC_X0 + 0.07, -0.95, -1.28, -1.7, -2.05, -2.42, NAC_X1 + 0.05]
        V.plaques(lot, sn, XN, lambda i: 8 + (i % 2), lambda rr, i, j: (M["rap"] if rr.f() < 0.14 else (M["acier"] if rr.f() < 0.1 else J[int(rr.f() * 4) % 4])),
                  r, gap=0.02, g=(0.02, 0.05), rivet=M["riv"], pas_riv=0.13)
        for xb in (NAC_X0 - 0.4, -1.5, NAC_X1 + 0.32):
            R = r_nac(xb) + 0.05
            lot.put(M["bague"], G.tour([(xb - 0.06, R - 0.02), (xb - 0.055, R + 0.04), (xb + 0.055, R + 0.04), (xb + 0.06, R - 0.02)],
                                       36, "x", (0, y, z)))
        xc, R, L = NAC_X1, r_nac(NAC_X1), 0.7
        out = [(xc + 0.02, R * 0.96), (xc - 0.08 * L, R * 0.84), (xc - 0.5 * L, R * 0.93), (xc - 0.92 * L, R * 1.12), (xc - L, R * 1.17),
               (xc - L - 0.03, R * 1.17)]
        inn = [(xc - L - 0.03, R * 1.08), (xc - L + 0.01, R * 1.05), (xc - 0.6 * L, R * 0.84), (xc - 0.2 * L, R * 0.66), (xc - 0.04, R * 0.6)]
        lot.put(M["bague"], G.tour(out, 36, "x", (0, y, z)))
        lot.put(M["brule"], G.tour(inn, 36, "x", (0, y, z)))
        lot.put(M["int"], G.tour([(xc - 0.04, R * 0.62), (xc - 0.3 * L, R * 0.3), (xc - 0.42 * L, 0.0)], 24, "x", (0, y, z)))
        for f in (0.3, 0.62, 0.9):
            xb = xc - f * L
            rb = R * (0.86 + 0.3 * f * f) + 0.03
            lot.put(M["acier"], G.tour([(xb - 0.03, rb - 0.02), (xb - 0.025, rb + 0.03), (xb + 0.025, rb + 0.03), (xb + 0.03, rb - 0.02)],
                                       36, "x", (0, y, z)))
        # tuyaux de nacelle à brides (moyen diamètre) le long du flanc
        a = PI / 2 + s * 0.9
        V.tuyau(lot, M["acier"], M["bague"], [(NAC_X0 - 0.3, y + (R + 0.07) * math.cos(a), z + (R + 0.07) * math.sin(a)),
                                              (NAC_X1 + 0.1, y + (R + 0.07) * math.cos(a), z + (R + 0.07) * math.sin(a))], 0.04, pas_bride=0.45)
    # ailes en flèche hors du plan (dièdre 0,2), saumons relevés ; aile sud tordue, posée sur un tréteau
    for s in (-1, 1):
        aile(lot, M, J, r, s)
    # dérive dressée
    x0, zt = -1.72, sec(-1.72)[0] + sec(-1.72)[2] - 0.02
    poly = [(x0, zt), (x0 - 0.85, zt + 1.3), (x0 - 1.2, zt + 1.34), (x0 - 1.32, zt - 0.05)]
    for (u0, u1, mm) in ((0.0, 0.55, J[0]), (0.55, 1.0, J[2])):
        q = [G.lerp((poly[0][0], 0, poly[0][1]), (poly[1][0], 0, poly[1][1]), u0),
             G.lerp((poly[0][0], 0, poly[0][1]), (poly[1][0], 0, poly[1][1]), u1),
             G.lerp((poly[3][0], 0, poly[3][1]), (poly[2][0], 0, poly[2][1]), u1),
             G.lerp((poly[3][0], 0, poly[3][1]), (poly[2][0], 0, poly[2][1]), u0)]
        a_ = [(p[0], -0.06, p[2]) for p in q]
        b_ = [(p[0], 0.06, p[2]) for p in q]
        lot.put(mm, G.loft([a_, b_], closed=True))
        lot.put(mm, (a_, [(0, 1, 2, 3)], [(p[0], p[2]) for p in a_]))
        lot.put(mm, (list(reversed(b_)), [(0, 1, 2, 3)], [(p[0], p[2]) for p in b_]))
    lot.put(M["chev"], G.tube([(poly[0][0] + 0.03, 0, poly[0][1]), (poly[1][0] + 0.03, 0, poly[1][1])], 0.085, 8))
    for t in (0.3, 0.6):
        pa = G.lerp((poly[0][0], -0.07, poly[0][1]), (poly[1][0], -0.07, poly[1][1]), t)
        pb = G.lerp((poly[3][0], -0.07, poly[3][1]), (poly[2][0], -0.07, poly[2][1]), t)
        lot.put(M["acier"], G.tube([pa, pb], 0.02, 6))
    lot.put(M["voyant"], G.sphere((poly[2][0] + 0.1, 0, poly[2][1] + 0.04), 0.035, 8, 4))
    # crâne : verrière à cadre lourd (2 vitres condamnées par des planches), canards, antenne tordue, grilles
    verriere(lot, M)
    for s in (-1, 1):
        x0 = 1.95
        zc, w, ht, hb, ex = sec(x0)
        poly2 = [(x0 + 0.5, w - 0.05), (x0 - 0.05, w - 0.05), (x0 - 0.22, w + 0.38), (x0 + 0.04, w + 0.42)]
        z = zc - 0.08
        a_ = [(px, s * py, z - 0.04) for px, py in poly2]
        b_ = [(px, s * py, z + 0.04) for px, py in poly2]
        lot.put(J[1], G.loft([a_, b_], closed=True))
        lot.put(J[1], (b_, [(0, 1, 2, 3)], [(p[0], p[1]) for p in b_]))
        lot.put(M["chev"], G.tube([b_[0], b_[3]], 0.04, 8))
    pa = P(2.6, PI / 2, 0.02)
    lot.put(M["acier"], G.tube([pa, G.add(pa, (0.05, 0.0, 0.42)), G.add(pa, (0.35, -0.05, 0.6))], 0.016, 6))
    lot.put(M["acier_c"], G.sphere(G.add(pa, (0.35, -0.05, 0.6)), 0.03, 8, 4))
    for (x, a, ww, ll) in ((-2.2, PI / 2 - 0.2, 0.32, 0.36), (-0.1, PI / 2 + 0.35, 0.24, 0.42), (0.6, PI / 2 + 0.3, 0.22, 0.3),
                           (-2.25, 0.5, 0.25, 0.3)):
        p = P(x, a, 0.07)
        n = G.norm(G.sub(P(x, a, 0.2), p))
        grille_posee(lot, M, p, n, ww, ll)
    # trappe d'accès au flanc sud (la porte) : cadre lourd et porte ouverte
    for (x, a) in ((1.5, PI - 0.5),):
        p = P(x, a, 0.05)
        n = G.norm(G.sub(P(x, a, 0.2), p))
        w_, h_ = 0.42, 0.6
        cad = G.merge(G.boite((0, -h_ / 2 - 0.04, 0.03), (w_ + 0.16, 0.08, 0.07)), G.boite((0, h_ / 2 + 0.04, 0.03), (w_ + 0.16, 0.08, 0.07)),
                      G.boite((-w_ / 2 - 0.04, 0, 0.03), (0.08, h_ + 0.16, 0.07)), G.boite((w_ / 2 + 0.04, 0, 0.03), (0.08, h_ + 0.16, 0.07)))
        lot.put(M["acier"], V.pose_plane(cad, p, n))
        lot.put(M["int"], V.pose_plane(G.boite((0, 0, -0.02), (w_, h_, 0.03)), p, n))
        lot.put(M["rap"], V.pose_plane(G.boite((w_ / 2 + 0.2, 0.0, 0.18), (0.04, h_, w_), ry=0.0), p, n))
        lot.put(M["voyant"], V.pose_plane(G.boite((0, h_ / 2 + 0.13, 0.05), (0.1, 0.05, 0.05)), p, n))
    # hublots (vitres sombres, sans lueur de jour : DA de l'âge 1)
    for (x, a, rr) in ((0.95, PI - 0.62, 0.07), (1.7, PI - 0.5, 0.06), (-1.2, PI - 0.6, 0.055), (2.3, PI - 0.4, 0.05)):
        p, n = P(x, a, 0.05), G.norm(G.sub(P(x, a, 0.2), P(x, a, 0.05)))
        lot.put(M["bague"], G.oriente(G.tour([(0.0, rr * 1.45), (0.03, rr * 1.35), (0.035, rr * 1.02), (0.015, rr * 0.95)], 16, "z"), p, n))
        lot.put(M["verre"], G.oriente(G.tour([(0.015, rr * 0.98), (0.02, 0.0)], 16, "z"), p, n))
    lot.xf = None


def grille_posee(lot, M, p, n, w, l, k=6):
    lot.put(M["acier"], V.pose_plane(G.boite((0, 0, 0.0), (l + 0.06, w + 0.06, 0.04)), p, n))
    lot.put(M["int"], V.pose_plane(G.boite((0, 0, 0.022), (l, w, 0.01)), p, n))
    for i in range(k):
        lot.put(M["acier_c"], V.pose_plane(G.boite((-l / 2 + l * (i + 0.5) / k, 0, 0.03), (l / k * 0.45, w, 0.025)), p, n))


def aile(lot, M, J, r, s):
    y_rac, z_rac = NAC_Y + NAC_R * 0.8, NAC_Z + 0.08
    x_rac, x_bout, y_bout = (-0.75, -2.45), (-2.05, -2.75), 2.75
    die = 0.2

    def pt(u, v, h):
        xa = x_rac[0] + (x_bout[0] - x_rac[0]) * v
        xf = x_rac[1] + (x_bout[1] - x_rac[1]) * v
        y = y_rac + (y_bout - y_rac) * v
        ep = 0.1 - 0.055 * v
        p = (xa + (xf - xa) * u, s * y, z_rac + h * ep)
        p = G.rot_x(p, s * die, (0.0, s * y_rac, z_rac))
        if s < 0:                                   # aile sud tordue vers le bas au bout (posée sur un tréteau)
            p = (p[0], p[1], p[2] - 0.12 * max(0.0, v - 0.55) / 0.45)
        return p

    def dalle(u0, u1, v0, v1, h0, h1, m):
        q = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        bot = [pt(u, v, h0) for u, v in q]
        top = [pt(u, v, h1) for u, v in q]
        lot.put(m, G.loft([bot, top], closed=True))
        lot.put(m, (top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]))
        lot.put(m, (list(reversed(bot)), [(0, 1, 2, 3)], [(p[0], p[1]) for p in bot]))
    dalle(0.02, 0.98, 0.0, 1.0, -1.0, 0.6, M["noyau"])
    g = 0.022
    cuts = [(0.05, 0.3), (0.3, 0.52), (0.52, 0.76)]
    vc = [(0.0, 0.3), (0.3, 0.55), (0.55, 0.8), (0.8, 1.0)]
    for i, (u0, u1) in enumerate(cuts):
        for j, (v0, v1) in enumerate(vc):
            if s > 0 and i == 1 and j == 2:
                continue                            # plaque manquante (âme sombre visible)
            m = M["rap"] if r.f() < 0.12 else J[(i + 2 * j + (s > 0)) % 4]
            dalle(u0 + g, u1 - g, v0 + g * 0.5, v1 - g * 0.5, 0.6, 1.1 + r.f(0, 0.5), m)
            pts = [(pt(u0 + g + 0.025, v0 + (v1 - v0) * (k + 0.5) / 5, 1.2), (0, 0, 1)) for k in range(5)]
            lot.put(M["riv"], G.rivets_le_long(pts, 0.015, 0.01))
    dalle(0.79, 0.97, 0.03, 0.95, -0.6, 0.9, M["acier"])         # volet
    lot.put(M["acier"], G.tube([pt(0.03, 0.0, 0.2), pt(0.03, 1.0, 0.2)], 0.075, 10))
    a, b = pt(0.12, 1.0, 0.0), pt(0.95, 1.0, 0.0)
    up = G.rot_x((0, 0, 0.45), s * die)
    poly = [a, b, G.add(G.add(b, up), (-0.14, 0, 0)), G.add(G.add(a, G.mul(up, 0.55)), (-0.38, 0, 0))]
    inner = [G.add(p, (0.0, -s * 0.045, 0.0)) for p in poly]
    lot.put(J[2], G.loft([poly, inner], closed=True))
    lot.put(J[2], (poly, [(0, 1, 2, 3)], [(p[0], p[2]) for p in poly]))
    lot.put(J[2], (list(reversed(inner)), [(0, 1, 2, 3)], [(p[0], p[2]) for p in poly]))
    return pt


def verriere(lot, M):
    x0, x1 = 1.05, 2.4
    n, m = 14, 18
    rings = []
    for i in range(n):
        x = x0 + (x1 - x0) * i / float(n - 1)
        t = i / float(n - 1)
        bump = math.sin(PI * min(1.0, t * 1.1)) ** 0.7
        zc, w, ht, hb, ex = sec(x)
        wg = w * (0.62 - 0.26 * t)
        ring = []
        for j in range(m):
            a = PI * j / float(m - 1)
            y = wg * math.cos(a)
            u = min(1.0, abs(y) / max(w, 1e-3))
            zt = zc + ht * (1.0 - u ** ex) ** (1.0 / ex)
            ring.append((x, y, zt + (0.05 + 0.18 * bump) * math.sin(a) ** 0.8 - 0.02))
        rings.append(ring)
    lot.put(M["verre"], G.loft(rings, closed=False))
    for i in (0, 4, 9, n - 1):
        lot.put(M["acier"], G.tube([G.add(p, (0, 0, 0.018)) for p in rings[i]], 0.034, 6))
    for j in (0, 5, 12, m - 1):
        lot.put(M["acier"], G.tube([G.add(r[j], (0, 0, 0.018)) for r in rings], 0.034, 6))
    # deux vitres condamnées par des planches clouées (pionniers)
    for (i0, i1, j0, j1) in ((4, 9, 9, 12), (9, 13, 12, 17)):
        for k in range(3):
            t = (k + 0.5) / 3.0
            jj = int(round(j0 + (j1 - j0) * t))
            a_, b_ = rings[i0][jj], rings[i1][jj]
            lot.put(M["planche"] if k % 2 else M["planche2"], G.boite(G.add(G.lerp(a_, b_, 0.5), (0, 0, 0.04)),
                                                                      (G.length(G.sub(b_, a_)) + 0.08, 0.075, 0.02),
                                                                      rz=math.atan2(b_[1] - a_[1], b_[0] - a_[0])))


# ------------------------------------------------------------------------------------------------ hauteur de la coque
_GRILLE = None


def dessus_z(xw, yw, rayon=0.09):
    """Hauteur monde du dessus de la coque à la verticale de (xw, yw) (0 si rien)."""
    global _GRILLE
    if _GRILLE is None:
        _GRILLE = []
        for i in range(160):
            x = X_Q + (X_N - X_Q) * i / 159.0
            for j in range(90):
                a = -0.4 + (PI + 0.8) * j / 89.0
                _GRILLE.append(W(x, a, 0.05))
    best = 0.0
    for p in _GRILLE:
        if abs(p[0] - xw) < rayon and abs(p[1] - yw) < rayon and p[2] > best:
            best = p[2]
    return best


# ------------------------------------------------------------------------------------------------ âge 1 : pionniers
def cabane(lot, M, r):
    """Cabane en rondins à toit de tôle ondulée, sur plate-forme de rondins posée de niveau sur le dos du vaisseau."""
    c = W(-0.72, PI / 2, 0.0)
    cxw, cyw = c[0], c[1] + 0.2
    rz = YAW
    Lu, Lv = 1.7, 1.36

    def L2W(u, v, z):
        q = G.rot_z((u, v, 0.0), rz)
        return (cxw + q[0], cyw + q[1], z)
    # niveau de la plate-forme : au-dessus du plus haut point de coque sous elle
    zmax = 0.0
    for u in (-0.95, -0.45, 0.0, 0.45, 0.95):
        for v in (-0.75, 0.0, 0.75):
            p = L2W(u, v, 0)
            zmax = max(zmax, dessus_z(p[0], p[1]))
    zp = zmax + 0.12
    # poteaux de rondins jusqu'à la coque (longueurs inégales), contrefiches
    for u in (-0.92, -0.3, 0.3, 0.92):
        for v in (-0.7, 0.7):
            p = L2W(u, v, 0)
            zb = dessus_z(p[0], p[1]) or 0.0
            if zb <= 0.05:
                zb = 0.0
            rondin(lot, M["rondin2"], M["bout"], (p[0], p[1], zb - 0.05), (p[0], p[1], zp - 0.05), 0.045)
            if v < 0:
                q = L2W(u + 0.3, v, 0)
                lot.put(M["planche2"], G.tube([(p[0], p[1], zb + 0.05), (q[0], q[1], zp - 0.08)], 0.02, 4))
    # plancher : 2 longrines + planches
    for v in (-0.7, 0.7):
        rondin(lot, M["rondin"], M["bout"], L2W(-1.05, v, zp - 0.02), L2W(1.05, v, zp - 0.02), 0.05)
    nb = 19
    for i in range(nb):
        u = -1.04 + 2.08 * (i + 0.5) / nb
        m = M["planche"] if r.f() < 0.6 else M["planche2"]
        lot.put(m, G.boite(L2W(u, r.f(-0.03, 0.03), zp + 0.045), (2.08 / nb - 0.012, 1.6 + r.f(-0.06, 0.06), 0.03), rz + r.f(-0.02, 0.02)))
    # murs en rondins, coins croisés qui dépassent
    hr_ = 0.042
    rows = 9
    for k in range(rows):
        z = zp + 0.08 + hr_ + k * 2 * hr_ * 0.92
        if k % 2 == 0:
            for v in (-Lv / 2, Lv / 2):
                if v < 0 and 2 <= k <= 6:          # porte au sud
                    rondin(lot, M["rondin"], M["bout"], L2W(-Lu / 2 - 0.1, v, z), L2W(-0.12, v, z), hr_)
                    rondin(lot, M["rondin"], M["bout"], L2W(0.26, v, z), L2W(Lu / 2 + 0.1, v, z), hr_)
                else:
                    rondin(lot, M["rondin"] if r.f() < 0.6 else M["rondin2"], M["bout"], L2W(-Lu / 2 - 0.1, v, z), L2W(Lu / 2 + 0.1, v, z), hr_)
        else:
            for u in (-Lu / 2, Lu / 2):
                if u > 0 and 3 <= k <= 5:          # fenêtre à l'est
                    rondin(lot, M["rondin"], M["bout"], L2W(u, -Lv / 2 - 0.1, z), L2W(u, -0.18, z), hr_)
                    rondin(lot, M["rondin"], M["bout"], L2W(u, 0.2, z), L2W(u, Lv / 2 + 0.1, z), hr_)
                else:
                    rondin(lot, M["rondin2"] if r.f() < 0.5 else M["rondin"], M["bout"], L2W(u, -Lv / 2 - 0.1, z), L2W(u, Lv / 2 + 0.1, z), hr_)
    zw = zp + 0.08 + rows * 2 * hr_ * 0.92
    # porte de planches (entrouverte), chambranle, volet de la fenêtre
    for i in range(4):
        u = -0.1 + 0.36 * (i + 0.5) / 4
        lot.put(M["planche2"], G.boite(L2W(u, -Lv / 2 - 0.03, zp + 0.34), (0.08, 0.025, 0.46), rz))
    lot.put(M["fer"], G.boite(L2W(0.08, -Lv / 2 - 0.05, zp + 0.22), (0.34, 0.012, 0.025), rz))
    lot.put(M["fer"], G.boite(L2W(0.08, -Lv / 2 - 0.05, zp + 0.46), (0.34, 0.012, 0.025), rz))
    lot.put(M["int"], G.boite(L2W(Lu / 2, 0.01, zp + 0.42), (0.03, 0.36, 0.2), rz))
    lot.put(M["planche"], G.boite(L2W(Lu / 2 + 0.1, -0.32, zp + 0.42), (0.02, 0.18, 0.22), rz + 0.6))
    # toit à deux pans en tôle ondulée (feuilles dépareillées), faîtière, débord, chevrons
    zf = zw + 0.42
    deb = 0.16
    for sgn in (-1, 1):
        nfe = 4
        for i in range(nfe):
            u0 = -Lu / 2 - deb + (Lu + 2 * deb) * i / nfe - 0.02
            a_ = L2W(u0, 0.0, zf)
            ev = G.norm(G.sub(L2W(u0, sgn * (Lv / 2 + deb), zw - 0.05), a_))
            eu = G.norm(G.sub(L2W(u0 + 1.0, 0.0, zf), a_))
            lv = G.length(G.sub(L2W(u0, sgn * (Lv / 2 + deb), zw - 0.05), a_)) + r.f(-0.04, 0.03)
            m = M["ondule2"] if (i + (sgn > 0)) % 3 == 0 else M["ondule"]
            lot.put(m, tole_ondulee(G.add(a_, (0, 0, 0.012 * (i % 2))), eu, ev, (Lu + 2 * deb) / nfe + 0.05, lv))
        for u in (-Lu / 2, 0.0, Lu / 2):
            rondin(lot, M["rondin2"], M["bout"], L2W(u, 0.0, zf - 0.04), L2W(u, sgn * (Lv / 2 + deb), zw - 0.08), 0.03)
    lot.put(M["fer"], G.tube([L2W(-Lu / 2 - deb, 0.0, zf + 0.02), L2W(Lu / 2 + deb, 0.0, zf + 0.02)], 0.035, 6))
    # pignons en planches
    for u in (-Lu / 2, Lu / 2):
        for i in range(5):
            v = -Lv / 2 + Lv * (i + 0.5) / 5
            hgt = (zf - zw) * (1 - abs(v) / (Lv / 2))
            lot.put(M["planche"], G.boite(L2W(u + 0.02 * (1 if u > 0 else -1), v, zw + hgt / 2), (0.02, Lv / 5 - 0.01, hgt), rz))
    # tuyau de poêle, chapeau chinois, haubans ; pierres qui lestent le toit
    pc = L2W(-0.3, 0.3, 0)
    lot.put(M["fer"], G.tube([(pc[0], pc[1], zf - 0.2), (pc[0], pc[1], zf + 0.75)], 0.045, 10))
    for z in (zf + 0.25, zf + 0.55):
        lot.put(M["fer"], G.tour([(z - 0.012, 0.052), (z + 0.012, 0.052)], 10, "z", (pc[0], pc[1], 0)))
    lot.put(M["fer"], G.tour([(0.0, 0.0), (0.0, 0.11), (0.08, 0.0)], 10, "z", (pc[0], pc[1], zf + 0.8), cap0=True))
    for q in (L2W(-0.75, 0.6, zf - 0.2), L2W(0.2, 0.7, zf - 0.25)):
        lot.put(M["corde"], G.tube([(pc[0], pc[1], zf + 0.6), q], 0.006, 4))
    for (u, v) in ((-0.5, -0.35), (0.35, -0.42), (0.1, -0.25), (0.55, 0.3)):
        p = L2W(u, v, zf - (zf - zw) * abs(v) / (Lv / 2) + 0.05)
        lot.put(M["pierre"], G.sphere(p, 0.05 + r.f(0, 0.02), 7, 4, zmin=-0.3))
    # garde-corps de corde et échelle de la plate-forme
    for u in (-1.04, -0.5, 1.04):
        p = L2W(u, -0.82, zp)
        lot.put(M["rondin2"], G.tube([p, G.add(p, (0, 0, 0.4))], 0.022, 6))
    lot.put(M["corde"], G.tube(G.chainette(G.add(L2W(-1.04, -0.82, zp), (0, 0, 0.38)), G.add(L2W(-0.5, -0.82, zp), (0, 0, 0.38)), 0.05, 8),
                               0.008, 4))
    return zp, L2W, zw, zf


def echelle(lot, M, a, b, larg=0.3, pas=0.17):
    d = G.sub(b, a)
    Ln = G.length(d)
    side = G.norm(G.cross(d, (0, 0, 1)))
    for s in (-1, 1):
        o = G.mul(side, s * larg / 2)
        lot.put(M["rondin2"], G.tube([G.add(a, o), G.add(b, o)], 0.022, 6))
    n = int(Ln / pas)
    for i in range(1, n):
        p = G.lerp(a, b, i / float(n))
        lot.put(M["planche"], G.tube([G.add(p, G.mul(side, -larg / 2)), G.add(p, G.mul(side, larg / 2))], 0.014, 5))


def pionniers(lot, M, r):
    zp, L2W, zw, zf = cabane(lot, M, r)
    # échelle de la plate-forme (du sol au plancher, côté sud)
    top = L2W(-0.75, -0.8, zp + 0.05)
    echelle(lot, M, (top[0] - 0.15, top[1] - 1.05, 0.0), top)
    # porte : rampe de planches du sol à la trappe, U de sacs de sable devant
    td = W(1.5, PI - 0.5, 0.05)
    pied = (td[0] + 0.05, td[1] - 1.15, 0.0)
    seuil = (td[0], td[1] - 0.08, td[2] - 0.32)
    d = G.sub(seuil, pied)
    for s in (-1, 1):
        lot.put(M["rondin2"], G.tube([G.add(pied, (s * 0.24, 0, 0.03)), G.add(seuil, (s * 0.24, 0, 0))], 0.035, 6))
    n = 9
    for i in range(n):
        p = G.lerp(pied, seuil, (i + 0.5) / n)
        lot.put(M["planche"] if i % 3 else M["planche2"], G.boite(G.add(p, (0, 0, 0.04)), (0.56 + r.f(-0.04, 0.04), 0.1, 0.025),
                                                                   rx=math.atan2(d[2], d[1])))
    for s in (-1, 1):
        p0 = G.add(pied, (s * 0.3, 0.05, 0.0))
        lot.put(M["rondin2"], G.tube([p0, G.add(p0, (0, 0, 0.55))], 0.02, 5))
        lot.put(M["corde"], G.tube([G.add(p0, (0, 0, 0.5)), G.add(seuil, (s * 0.3, 0, 0.45))], 0.007, 4))
    # U de sacs de sable (2 rangs, 3 variantes), ouverture à l'est
    ux0, ux1, uy0, uy1 = pied[0] - 0.85, pied[0] + 0.75, pied[1] - 0.55, pied[1] + 0.55
    murs = [((ux0, uy1), (ux0, uy0)), ((ux0, uy0), (ux1 - 0.35, uy0)), ((ux1, uy0 + 0.25), (ux1, uy1 - 0.05))]
    for (a, b) in murs:
        Lm = math.hypot(b[0] - a[0], b[1] - a[1])
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        for rang in range(3):
            nb = int(Lm / 0.3) + (0 if rang % 2 == 0 else -1)
            off = 0.0 if rang % 2 == 0 else 0.15
            for i in range(max(1, nb)):
                t = (off + 0.15 + 0.3 * i) / max(Lm, 0.3)
                if t > 1.0:
                    continue
                c = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, 0.075 + 0.13 * rang)
                v = r.i(0, 2)
                m = M["jute"] if (i + rang) % 3 else M["jute2"]
                lot.put(m, sac(G.add(c, (r.f(-0.02, 0.02), r.f(-0.03, 0.03), 0)), 0.31 + 0.03 * v, 0.2 + 0.02 * v, 0.15 - 0.01 * v,
                               rz=ang + r.f(-0.15, 0.15), ry=r.f(-0.08, 0.08)))
    # rouleau de barbelé devant le U
    bx0, bx1, by = ux0 - 0.1, ux1 - 0.2, uy0 - 0.3
    pts = []
    for i in range(160):
        t = i / 159.0
        a = t * 13 * TAU
        pts.append((bx0 + (bx1 - bx0) * t + 0.03 * math.cos(a), by + 0.12 * math.cos(a), 0.13 + 0.12 * math.sin(a)))
    lot.put(M["fer"], G.tube(pts, 0.008, 4))
    for x in (bx0, (bx0 + bx1) / 2, bx1):
        lot.put(M["rondin2"], G.tube([(x - 0.08, by, 0.0), (x + 0.08, by, 0.32)], 0.018, 5))
        lot.put(M["rondin2"], G.tube([(x + 0.08, by, 0.0), (x - 0.08, by, 0.32)], 0.018, 5))
    # berceaux de rondins sous le vaisseau (nacelle nord surélevée, ventre)
    for xs_ in (-1.75, 0.3, 1.6):
        p = W(xs_, 3 * PI / 2, 0.0)
        zb = p[2]
        if zb > 0.12:
            k = int(zb / 0.1)
            for i in range(k):
                z = 0.05 + i * 0.1
                if i % 2 == 0:
                    rondin(lot, M["rondin"], M["bout"], (p[0] - 0.35, p[1] - 0.2 + 0.05 * i, z), (p[0] - 0.35, p[1] + 0.55, z), 0.05)
                    rondin(lot, M["rondin"], M["bout"], (p[0] + 0.35, p[1] - 0.2 + 0.05 * i, z), (p[0] + 0.35, p[1] + 0.55, z), 0.05)
                else:
                    rondin(lot, M["rondin2"], M["bout"], (p[0] - 0.5, p[1] + 0.1, z), (p[0] + 0.5, p[1] + 0.1, z), 0.05)
    pn = SHIP((-1.6, NAC_Y, NAC_Z - NAC_R))
    for i in range(int(pn[2] / 0.1) + 1):
        z = 0.05 + i * 0.1
        if i % 2 == 0:
            for dx in (-0.3, 0.3):
                rondin(lot, M["rondin"], M["bout"], (pn[0] + dx, pn[1] - 0.45, z), (pn[0] + dx, pn[1] + 0.45, z), 0.05)
        else:
            for dy in (-0.25, 0.25):
                rondin(lot, M["rondin2"], M["bout"], (pn[0] - 0.42, pn[1] + dy, z), (pn[0] + 0.42, pn[1] + dy, z), 0.05)
    # tréteau sous le bout de l'aile sud tordue
    pa = SHIP((-2.2, -2.35, NAC_Z + 0.08 + 0.2 * (2.35 - NAC_Y - NAC_R * 0.8) - 0.12))
    for dx in (-0.2, 0.2):
        lot.put(M["rondin2"], G.tube([(pa[0] + dx, pa[1] - 0.15, 0.0), (pa[0] + dx * 0.4, pa[1], max(0.1, pa[2] - 0.08))], 0.03, 6))
        lot.put(M["rondin2"], G.tube([(pa[0] + dx, pa[1] + 0.15, 0.0), (pa[0] + dx * 0.4, pa[1], max(0.1, pa[2] - 0.08))], 0.03, 6))
    rondin(lot, M["rondin"], M["bout"], (pa[0] - 0.2, pa[1], max(0.1, pa[2] - 0.06)), (pa[0] + 0.2, pa[1], max(0.1, pa[2] - 0.06)), 0.04)
    # bâche tendue sur la moitié arrière de la brèche, cordes et piquets
    rings = []
    for i in range(9):
        t = i / 8.0
        x = BRECHE[0] - 0.04 + 0.34 * t
        ring = []
        for j in range(12):
            u = j / 11.0
            a = BRECHE[2] - 0.15 + (BRECHE[3] - BRECHE[2] + 0.3) * u
            g = 0.05 - 0.22 * math.sin(PI * u) * (0.4 + 0.6 * math.sin(PI * t))
            ring.append(W(x, a, g + 0.02 * math.sin(7 * u + 3 * t)))
        rings.append(ring)
    lot.put(M["toile"], G.loft(rings, closed=False))
    lot.put(M["toile"], G.loft([[G.add(p, (0, 0, -0.012)) for p in rr] for rr in rings], closed=False))
    for j in (0, 5, 11):
        p = rings[-1][j]
        q = (p[0] + 0.2, p[1] - 0.6, 0.0)
        lot.put(M["corde"], G.tube([p, q], 0.007, 4))
        lot.put(M["rondin2"], G.tube([q, G.add(q, (0.02, 0.02, 0.12))], 0.015, 4))
    # planches clouées sur la moitié basse avant de la brèche
    for k in range(4):
        a = 2.55 + 0.13 * k
        p0, p1 = W(0.62, a, 0.07), W(1.02, a + 0.04, 0.07)
        lot.put(M["planche"] if k % 2 else M["planche2"], G.tube([p0, p1], 0.035, 4))
    # mât de drapeau en bois à l'arrière gauche (nord-ouest), haubans, fanion
    pm = W(-2.35, PI / 2 - 0.55, 0.04)
    hm = 2.55
    rondin(lot, M["rondin"], M["bout"], pm, G.add(pm, (0, 0, hm)), 0.045)
    lot.put(M["rondin2"], G.tube([G.add(pm, (-0.12, 0, hm - 0.35)), G.add(pm, (0.12, 0, hm - 0.35))], 0.018, 5))
    for q in (W(-2.55, PI / 2 + 0.2, 0.05), W(-1.95, PI / 2 - 0.9, 0.05), W(-2.1, PI / 2 + 0.6, 0.05)):
        lot.put(M["corde"], G.tube([G.add(pm, (0, 0, hm - 0.3)), q], 0.006, 4))
    fl = []
    for i in range(10):
        t = i / 9.0
        ring = []
        for j in range(5):
            u = j / 4.0
            ring.append(G.add(pm, (0.05 + 0.62 * t, 0.04 * math.sin(4 * t + u), hm - 0.05 - 0.36 * u * (1 - 0.35 * t) - 0.08 * t * t)))
        fl.append(ring)
    lot.put(M["drapeau"], G.loft(fl, closed=False))
    # vigie : perche, lanterne, girouette sur le crâne
    # échafaudage de bois autour du nez (côté sud), plancher, échelle, chèvre qui soulève une tôle neuve
    xs, ys = (2.05, 3.0), None
    p0, p1 = W(2.5, PI, 0.0), W(3.4, PI, 0.0)
    y_out = min(p0[1], p1[1]) - 0.32
    y_in = y_out + 0.42
    hp = 0.85
    for (x, y) in ((p0[0], y_out), (p1[0], y_out), (p0[0], y_in), (p1[0], y_in)):
        lot.put(M["rondin2"], G.tube([(x, y, 0.0), (x, y, hp + 0.5)], 0.03, 6))
    for z in (0.4, hp):
        for y in (y_out, y_in):
            lot.put(M["rondin"], G.tube([(p0[0] - 0.08, y, z), (p1[0] + 0.08, y, z)], 0.025, 6))
    for i in range(7):
        x = p0[0] + (p1[0] - p0[0]) * (i + 0.5) / 7
        lot.put(M["planche"] if i % 2 else M["planche2"], G.boite((x, (y_out + y_in) / 2, hp + 0.04), ((p1[0] - p0[0]) / 7 - 0.015, 0.5, 0.025)))
    lot.put(M["rondin2"], G.tube([(p0[0], y_out, 0.05), (p1[0], y_out, hp - 0.05)], 0.02, 5))
    lot.put(M["rondin2"], G.tube([(p0[0], y_out, hp + 0.42), (p1[0], y_out, hp + 0.42)], 0.02, 5))
    echelle(lot, M, (p1[0] + 0.35, y_out - 0.3, 0.0), (p1[0] + 0.1, y_out + 0.05, hp + 0.25), larg=0.24)
    tp = (p0[0] + 0.45, y_in - 0.1, hp + 1.25)
    for q in ((p0[0], y_out, hp), (p1[0], y_out, hp), (p0[0] + 0.45, y_in + 0.35, hp)):
        lot.put(M["rondin2"], G.tube([q, tp], 0.025, 5))
    lot.put(M["corde"], G.tube([tp, G.add(tp, (0, 0.05, -0.5))], 0.007, 4))
    pl = [G.add(tp, (-0.25, 0.08, -0.52)), G.add(tp, (0.25, 0.08, -0.52)), G.add(tp, (0.25, 0.12, -0.95)), G.add(tp, (-0.25, 0.12, -0.95))]
    lot.put(M["rap"], tole_plane(pl, 0.025))
    # sol : butte devant le nez, caisses, tonneaux, tas de rondins, chevalet, feu de camp éteint, poteaux à lanterne, débris
    lot.put(M["terre"], G.butte((3.75, -0.45, 0.0), 0.45, 0.8, 0.2, r, n=20, bosses=0.4))
    lot.put(M["terre"], G.butte((3.45, 0.45, 0.0), 0.35, 0.45, 0.12, r, n=14))
    for i in range(9):
        lot.put(M["terre"], G.sphere((r.f(3.4, 4.1), r.f(-1.2, 0.6), 0.0), r.f(0.04, 0.08), 7, 4, zmin=-0.3))
    for (x, y, s_, rz_) in ((-0.95, -2.35, 0.32, 0.25), (-0.62, -2.5, 0.26, -0.2), (-0.8, -2.15, 0.22, 0.6), (2.65, -1.95, 0.3, 0.1),
                            (-3.5, -1.1, 0.3, -0.3)):
        caisse(lot, M["planche"], M["planche2"], M["fer"], (x, y, 0.0), (s_, s_, s_ * 0.85), rz_)
    caisse(lot, M["planche2"], M["planche"], M["fer"], (-0.8, -2.36, 0.272), (0.24, 0.24, 0.2), 0.5)
    for (x, y, rr, c_) in ((1.05, -2.6, 0.13, False), (2.75, -2.45, 0.12, False), (3.0, -2.6, 0.13, True), (-3.2, 1.9, 0.13, False),
                           (-3.4, -1.65, 0.13, True)):
        tonneau(lot, M["fer"] if not c_ else M["rap2"], M["acier"], (x, y, 0.0 if not c_ else 0.13), rr, 0.38, couche=c_, rz=0.6)
    for i, (dy, dz) in enumerate(((-0.1, 0.06), (0.0, 0.06), (0.1, 0.06), (-0.05, 0.15), (0.05, 0.15), (0.0, 0.24))):
        y0 = 2.2 + dy * 1.0
        rondin(lot, M["rondin"] if i % 2 else M["rondin2"], M["bout"], (-1.2, y0 + dy, dz), (0.0, y0 + dy + 0.05, dz), 0.055)
    for (x, y) in ((-2.3, -2.25), ):
        for dx in (-0.25, 0.25):
            lot.put(M["planche2"], G.tube([(x + dx, y - 0.12, 0.0), (x + dx, y, 0.3)], 0.018, 4))
            lot.put(M["planche2"], G.tube([(x + dx, y + 0.12, 0.0), (x + dx, y, 0.3)], 0.018, 4))
        rondin(lot, M["rondin"], M["bout"], (x - 0.4, y, 0.33), (x + 0.45, y + 0.05, 0.33), 0.06)
        lot.put(M["planche"], G.tube([(x + 0.1, y, 0.38), (x + 0.12, y - 0.05, 0.62)], 0.012, 4))
        lot.put(M["fer"], G.boite((x + 0.12, y - 0.05, 0.62), (0.1, 0.02, 0.06)))
    fc = (-1.75, -2.45, 0.0)
    for i in range(9):
        a = TAU * i / 9
        lot.put(M["pierre"], G.sphere((fc[0] + 0.17 * math.cos(a), fc[1] + 0.17 * math.sin(a), 0.0), 0.05 + 0.01 * (i % 3), 7, 4, zmin=-0.2))
    lot.put(M["cendre"], G.sphere(fc, 0.13, 10, 3, zmin=0.0))
    for a in (0.3, 2.4, 4.4):
        lot.put(M["rondin2"], G.tube([(fc[0] + 0.25 * math.cos(a), fc[1] + 0.25 * math.sin(a), 0.0), (fc[0], fc[1], 0.55)], 0.012, 4))
    lot.put(M["fer"], G.tour([(0.0, 0.06), (0.1, 0.08), (0.12, 0.07)], 10, "z", (fc[0], fc[1], 0.22), cap0=True))
    postes = [(-2.2, -1.75), (1.65, -2.75), (-3.55, 0.6)]
    for (x, y) in postes:
        lot.put(M["rondin2"], G.tube([(x, y, 0.0), (x, y, 1.0)], 0.03, 6))
        lot.put(M["rondin2"], G.tube([(x, y, 0.95), (x + 0.18, y, 0.95)], 0.018, 5))
        lanterne(lot, M["fer"], M["lanterne"], (x + 0.18, y, 0.92))
    # câbles du vaisseau (rouges et noirs) jusqu'aux poteaux et à la cabane : le cœur alimente le camp
    src = W(0.3, 2.95, -0.05)
    cables(lot, [M["rouge"], M["noir"]], src, (-2.2, -1.75, 0.98), 0.25)
    cables(lot, [M["noir"], M["rouge"]], W(0.9, 2.9, -0.05), (1.65, -2.75, 0.98), 0.3, n=3)
    cables(lot, [M["rouge"], M["noir"]], W(-1.8, PI - 0.9, 0.03), L2W(-0.7, -0.6, zw - 0.1), 0.12, n=2)
    cables(lot, [M["noir"]], W(-2.4, PI - 0.4, 0.03), (-3.55, 0.6, 0.98), 0.3, n=2)
    # flexibles annelés : du ventre aux tonneaux, de la nacelle au sol
    V.flexible(lot, M["caout"], [W(-0.85, PI + 0.35, 0.02), (-0.4, -1.9, 0.25), (0.6, -2.4, 0.08), (1.05, -2.6, 0.38)], 0.04, pas=0.05)
    V.flexible(lot, M["caout"], [W(-1.95, PI + 0.5, 0.02), (-2.3, -1.75, 0.15), (-3.0, -1.65, 0.05), (-3.35, -1.65, 0.13)], 0.035, pas=0.05)
    V.flexible(lot, M["cuivre"], [W(2.0, PI + 0.3, 0.03), (2.4, -1.5, 0.2), (2.8, -2.3, 0.05), (3.0, -2.47, 0.13)], 0.03, pas=0.04)
    V.flexible(lot, M["caout"], [W(-2.5, PI / 2 + 0.6, 0.02), (-3.1, -0.4, 0.6), (-3.4, -0.9, 0.05)], 0.035, pas=0.05)
    # tuyaux coudés à brides (3 diamètres) du flanc sud vers une citerne bricolée
    V.tuyau(lot, M["acier"], M["acier_c"], [W(1.7, PI + 0.15, 0.02), (2.05, -1.55, 0.35), (2.05, -1.8, 0.1), (2.45, -1.8, 0.1)], 0.055,
            rb=0.12, pas_bride=0.4)
    V.tuyau(lot, M["cuivre"], M["acier"], [W(-2.4, PI - 0.1, 0.03), (-2.75, -1.55, 0.6), (-2.75, -1.55, 0.05)], 0.035, pas_bride=0.3)
    # appentis de toile au sud-ouest, tente en A au nord-est, tas de tôles récupérées au sud-est
    ap = (-3.05, -1.85)
    for dx in (-0.45, 0.45):
        lot.put(M["rondin2"], G.tube([(ap[0] + dx, ap[1] - 0.45, 0.0), (ap[0] + dx, ap[1] - 0.45, 0.62)], 0.025, 6))
    rings = []
    for i in range(7):
        t = i / 6.0
        x = ap[0] - 0.5 + 1.0 * t
        rings.append([(x, ap[1] - 0.45 + 0.95 * u, 0.62 - 0.6 * u - 0.06 * math.sin(PI * u) * (0.5 + 0.5 * math.sin(PI * t))) for u in
                      [k / 7.0 for k in range(8)]])
    lot.put(M["toile"], G.loft(rings, closed=False))
    lot.put(M["toile"], G.loft([[G.add(p, (0, 0, -0.01)) for p in rr] for rr in rings], closed=False))
    caisse(lot, M["planche2"], M["planche"], M["fer"], (ap[0] - 0.15, ap[1] - 0.1, 0.0), (0.26, 0.26, 0.22), 0.2)
    tonneau(lot, M["fer"], M["acier"], (ap[0] + 0.25, ap[1] - 0.05, 0.0), 0.11, 0.32)
    tn = (3.0, 2.05)
    a_, b_ = (tn[0] - 0.5, tn[1], 0.55), (tn[0] + 0.5, tn[1], 0.55)
    for p in (a_, b_):
        for dy in (-0.32, 0.32):
            lot.put(M["rondin2"], G.tube([(p[0], p[1] + dy, 0.0), p], 0.02, 5))
    for sgn in (-1, 1):
        rr = [[(tn[0] - 0.55 + 1.1 * i / 6.0, tn[1] + sgn * 0.42 * u, 0.55 * (1 - u) - 0.03 * math.sin(PI * u)) for u in (0.0, 0.33, 0.66, 1.0)]
              for i in range(7)]
        lot.put(M["jute2"], G.loft(rr, closed=False))
    for (x, y, z, rz_, m) in ((3.25, -1.95, 0.0, 0.3, "rap"), (3.3, -1.9, 0.04, 0.6, "j1"), (3.2, -2.0, 0.08, -0.2, "j3"),
                              (3.35, -1.95, 0.12, 0.1, "rap2"), (3.28, -1.92, 0.16, 0.9, "j0")):
        lot.put(M[m], G.boite((x, y, z + 0.02), (0.6, 0.42, 0.035), rz_))
    # chemin de rondins (rondins couchés en travers) de l'appentis à l'échafaudage, au sud
    xr_ = -3.3
    while xr_ < 3.3:
        if not (pied[0] - 0.9 < xr_ < pied[0] + 0.85):
            yy = -2.25 + 0.06 * math.sin(xr_ * 2.3)
            rondin(lot, M["rondin"] if int(xr_ * 10) % 3 else M["rondin2"], M["bout"], (xr_, yy - 0.3, 0.045),
                   (xr_ + r.f(-0.03, 0.03), yy + 0.3, 0.045), 0.045)
        xr_ += 0.105
    lot.put(M["fer"], G.tube([(tn[0] - 0.55, tn[1], 0.56), (tn[0] + 0.55, tn[1], 0.56)], 0.02, 5))
    # débris au sol
    for i in range(10):
        x = r.f(-3.8, 3.6)
        y = r.f(-2.75, 2.7)
        if -2.4 < x < 2.4 and -1.4 < y < 1.6:
            continue
        s_ = r.f(0.12, 0.3)
        a = r.f(0, TAU)
        pts = [(x + s_ * math.cos(a + k * 1.7 + r.f(-0.3, 0.3)) * (0.6 + r.f(0, 0.5)), y + s_ * math.sin(a + k * 1.7) * (0.6 + r.f(0, 0.5)),
                0.01 + 0.04 * (k % 2)) for k in range(4)]
        lot.put([M["j1"], M["rap"], M["planche2"], M["acier"]][i % 4], tole_plane(pts, 0.02))
    for i in range(14):
        x, y = r.f(-3.9, 3.9), r.f(-2.8, -1.2)
        lot.put(M["acier"] if i % 2 else M["fer"], G.boite((x, y, 0.02), (0.05, 0.04, 0.04), rz=r.f(0, 3)))


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(1101)
    carcasse(lot, M, r)
    pionniers(lot, M, r)
    return {}
