"""QG ÂGE 9 : ATOME (série du 31/10, brief 2026-10-31_QG). Emprise 12×6. NEZ À DROITE (+X), tuyères à gauche.

Bible (DESIGN_EPOQUES §5, époque 9) : « Bunker atomique : corps octogonal chanfreiné ; 2 tours de refroidissement ; dôme
de confinement » ; plomb #4A5058, jaune d'avertissement #C9A227, béton #7A7670, vert uranium #5CFF4A, luminance 56,
4 événements. Le QG reste le vaisseau de l'âge 8 un âge plus tard : moins de peau, plaques de plomb, mêmes côtes, même
pose ; les rondeurs de verre deviennent octogones lourds et hyperboloïdes.

Lecture de gauche à droite : tuyères et dérive ; dans la cage, l'enceinte octogonale et son dôme de plomb, sas ouvert sur
le cœur vert ; devant, sur la dalle, le bunker en gradins chanfreinés entre la piscine (eau verte) et la capsule ;
derrière, deux tours hyperboloïdes sur béquilles croisées et le pylône à balise.
"""
import math

import carcasse as C
import ere3 as E
import geo as G
import mat as MT

Z_PONT = 0.45
ENC = (-0.62, -0.46, 1.26)                         # enceinte dans la cage (repère de la halle : u, v, rayon)
PISCINE = (2.78, -2.36, 0.92)
CAPSULE = (-3.48, -2.52, 0.62)
BK = dict(x0=-2.5, x1=1.55, y0=-2.98, y1=-1.42, ch=0.42, z0=0.3)
VERT = (0.107, 1.0, 0.069)                         # #5CFF4A


def lin(h):
    def f(c):
        c /= 255.0
        return c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(int(h[1:3], 16)), f(int(h[3:5], 16)), f(int(h[5:7], 16)))


def matieres(S):
    MT.PATINE.update(ta=0.16, ra=0.28, ec=0.7, nu_k=1.45, ec_col=(0.028, 0.018, 0.008))
    sf = MT.surface
    cr = (0.008, 0.0075, 0.007)
    jaunes = [(0.36, 0.205, 0.013), (0.24, 0.135, 0.009), (0.5, 0.32, 0.025), (0.33, 0.15, 0.01)]
    M = E.mats_base(sf, "q9", jaunes, cr, MT)
    pb = lin("#4A5058")
    bt = lin("#7A7670")
    ja = lin("#C9A227")
    M["plomb"] = sf("q9_plomb", (pb[0] * 1.5, pb[1] * 1.62, pb[2] * 1.95), rough=0.5, met=0.35, coulures=0.85, rouille=(0.22, 0.21, 0.19), usure=0.8,
                    nu=(0.55, 0.57, 0.6), crasse=0.85, crasse_col=cr, pied=(0.2, 1.0, 0.5), grain=0.13, graine=110)
    M["plomb2"] = sf("q9_plomb2", (pb[0] * 0.9, pb[1] * 0.98, pb[2] * 1.2), rough=0.55, met=0.35, coulures=0.8, rouille=(0.16, 0.08, 0.04), usure=0.7,
                     nu=(0.45, 0.47, 0.5), crasse=0.85, crasse_col=cr, grain=0.14, graine=111)
    M["patch"] = M["plomb"]
    M["rapiece"] = sf("q9_rapiece", (bt[0] * 0.7, bt[1] * 0.7, bt[2] * 0.7), rough=0.82, met=0.05, coulures=0.7, rouille=(0.05, 0.045, 0.04), usure=0.5,
                      crasse=0.8, crasse_col=cr, grain=0.15, graine=87)
    M["rapiece2"] = M["plomb2"]
    M["anneau"] = sf("q9_anneau", (pb[0] * 0.6, pb[1] * 0.6, pb[2] * 0.62), rough=0.45, met=0.7, usure=0.8, nu=(0.6, 0.6, 0.6), crasse=0.7, crasse_col=cr, graine=112)
    M["beton"] = sf("q9_beton", (bt[0] * 1.1, bt[1] * 1.0, bt[2] * 0.82), rough=0.9, met=0.0, tole=(1.05, 0.42), joint=0.55, joint_l=0.01, var=0.09, coulures=0.95,
                    rouille=(0.14, 0.06, 0.022), usure=0.55, nu=(0.42, 0.4, 0.37), crasse=0.9, crasse_col=cr, pied=(0.0, 0.5, 0.55), relief=0.5, grain=0.17, graine=113)
    M["beton2"] = sf("q9_beton2", (bt[0] * 0.62, bt[1] * 0.6, bt[2] * 0.58), rough=0.9, met=0.0, usure=0.5, nu=(0.32, 0.3, 0.28), crasse=0.9, crasse_col=cr,
                     coulures=0.7, rouille=(0.035, 0.03, 0.028), grain=0.19, graine=114)
    M["dalle"] = sf("q9_dalle", (bt[0] * 0.92, bt[1] * 0.84, bt[2] * 0.7), rough=0.9, met=0.0, usure=0.55, nu=(0.34, 0.32, 0.3), crasse=0.9, crasse_col=cr, grain=0.2, graine=115)
    M["dalle2"] = sf("q9_dalle2", (bt[0] * 0.62, bt[1] * 0.57, bt[2] * 0.48), rough=0.9, met=0.0, usure=0.5, nu=(0.28, 0.26, 0.24), crasse=0.9, crasse_col=cr, grain=0.2, graine=116)
    M["tour"] = sf("q9_tour", (bt[0] * 1.35, bt[1] * 1.22, bt[2] * 1.0), rough=0.92, met=0.0, tole=(0.8, 0.34), joint=0.68, joint_l=0.008, var=0.07, coulures=1.0,
                   rouille=(0.13, 0.058, 0.022), usure=0.3, crasse=0.75, crasse_col=cr, relief=0.4, grain=0.2, graine=117)
    M["tour_int"] = sf("q9_tour_int", (0.035, 0.034, 0.033), rough=0.9, met=0.0, usure=0.0, crasse=0.9, crasse_col=(0.004, 0.004, 0.004), grain=0.25, graine=118)
    M["jaune9"] = sf("q9_jaune9", (ja[0] * 0.85, ja[1] * 0.85, ja[2] * 0.9), rough=0.48, met=0.2, coulures=0.7, rouille=(0.14, 0.06, 0.02), usure=0.8, nu=(0.5, 0.48, 0.44),
                     crasse=0.8, crasse_col=cr, grain=0.11, graine=119)
    M["danger"] = sf("q9_danger", (ja[0] * 0.85, ja[1] * 0.85, ja[2] * 0.9), rough=0.5, met=0.2, bandes=(0.26, (0.012, 0.011, 0.01), 0.5), usure=0.75, nu=(0.4, 0.38, 0.35),
                     crasse=0.75, crasse_col=cr, coulures=0.6, graine=120)
    M["gaine"] = sf("q9_gaine", (0.13, 0.135, 0.15), rough=0.48, met=0.6, usure=0.7, nu=(0.42, 0.42, 0.42), crasse=0.8, crasse_col=cr, coulures=0.6, rouille=(0.16, 0.08, 0.03), graine=121)
    M["conduit"] = sf("q9_conduit", (pb[0] * 1.1, pb[1] * 1.1, pb[2] * 1.1), rough=0.45, met=0.65, coulures=0.7, rouille=(0.16, 0.08, 0.03), usure=0.8, nu=(0.5, 0.5, 0.5),
                      crasse=0.75, crasse_col=cr, grain=0.1, graine=122)
    M["vase"] = sf("q9_vase", (0.016, 0.022, 0.012), rough=0.4, met=0.0, usure=0.0, crasse=0.5, crasse_col=(0.006, 0.008, 0.003), grain=0.2, graine=103)
    M["hublot"] = MT.lumiere(S, "q9_hublot", VERT, 2.2, main=0.4)
    M["coeur"] = S.mat_emissive("q9_coeur", VERT, strength=2.6, base=(0.02, 0.1, 0.01), main_scale=0.55, crust=(9.0, 0.45, 8.0))
    M["eau"] = S.mat_emissive("q9_eau", VERT, strength=0.42, base=(0.006, 0.035, 0.01), main_scale=0.4, crust=(7.0, 0.9, 12.0))
    M["veilleuse"] = MT.verre("q9_veilleuse", col=(0.015, 0.05, 0.02), reflet=(0.16, 0.34, 0.2))
    M["voyant"] = MT.lumiere(S, "q9_voyant", (1.0, 0.09, 0.03), 7.0, main=0.4)
    return M


# ================================================================================================ pièces
def trefle(lot, M, p, n, r):
    """Trèfle de radiation : disque jaune à bord noir, trois secteurs noirs, moyeu noir (modélisé, pas peint)."""
    lot.put(M["noir"], G.oriente(G.tour([(0.0, r * 1.42), (0.012, r * 1.42), (0.014, 0.0)], 24, "z"), p, n))
    lot.put(M["jaune9"], G.oriente(G.tour([(0.012, r * 1.3), (0.018, r * 1.3), (0.02, 0.0)], 24, "z"), p, n))
    for k in range(3):
        a0 = math.pi / 2 + k * G.TAU / 3
        pts = []
        for j in range(5):
            a = a0 - 0.52 + 1.04 * j / 4.0
            pts.append((r * 0.3 * math.cos(a), r * 0.3 * math.sin(a), 0.024))
        for j in range(5):
            a = a0 + 0.52 - 1.04 * j / 4.0
            pts.append((r * 1.05 * math.cos(a), r * 1.05 * math.sin(a), 0.024))
        lot.put(M["noir"], C.pose_plane((pts, [tuple(range(10))], [(q[0], q[1]) for q in pts]), p, n))
    lot.put(M["noir"], G.oriente(G.tour([(0.02, r * 0.2), (0.026, r * 0.2), (0.028, 0.0)], 12, "z"), p, n))


def pans(lot, M, p0, p1, z0, z1, rr, mats, larg=(0.4, 0.85), haut=(0.45, 0.9), garde_p=0.12, faces=None):
    """Plaques de blindage sur les pans d'un tronc (p0 à z0, p1 à z1) : lés de largeur et hauteur tirées, rentrés d'un
    joint, décollés du mur ; une plaque sur six manque et laisse voir le béton. faces : indices des pans à garnir."""
    n = len(p0)
    cx = sum(p[0] for p in p0) / n
    cy = sum(p[1] for p in p0) / n
    for i in (faces if faces is not None else range(n)):
        i2 = (i + 1) % n
        a0, b0 = (p0[i][0], p0[i][1], z0), (p0[i2][0], p0[i2][1], z0)
        a1, b1 = (p1[i][0], p1[i][1], z1), (p1[i2][0], p1[i2][1], z1)
        L = G.length(G.sub(b0, a0))
        if L < 0.1:
            continue
        mx, my = (a0[0] + b0[0]) / 2 - cx, (a0[1] + b0[1]) / 2 - cy
        d = math.hypot(mx, my) or 1.0
        out = (mx / d * 0.018, my / d * 0.018, 0.012)
        t = garde_p / L
        while t < 1.0 - garde_p / L - 0.02:
            w = min(rr.f(*larg) / L, 1.0 - garde_p / L - t)
            s = 0.04
            while s < 0.97:
                h = min(rr.f(*haut), 0.97 - s)
                if h < 0.12:
                    break
                if rr.f() > 0.16:
                    m = mats[rr.i(0, len(mats) - 1)]
                    q = []
                    for (tt, ss) in ((t + 0.008, s + 0.012), (t + w - 0.008, s + 0.012), (t + w - 0.008, s + h - 0.012), (t + 0.008, s + h - 0.012)):
                        q.append(G.add(G.lerp(G.lerp(a0, b0, tt), G.lerp(a1, b1, tt), ss), out))
                    back = [G.sub(x, out) for x in q]
                    lot.put(m, G.merge((q, [(0, 1, 2, 3)], [(0.0, 0.0), (L * w, 0.0), (L * w, h), (0.0, h)]), G.loft([back + [back[0]], q + [q[0]]], closed=False)))
                s += h
            t += w


def anneau_poly(pts, r):
    return G.tube(pts + [pts[0]], r, 5)


def octo_pts(cx, cy, R, z):
    return [(p[0], p[1], z) for p in E.octogone(cx, cy, R)]


def enceinte(lot, M, cx, cy, R, rr):
    """Enceinte de confinement : drum octogonal de béton à fruit, pilastres de plomb, fentes vertes, dôme à 8 pans de
    plomb cerclé, sas ouvert sur le cœur (le foyer fort). Renvoie z du sommet."""
    zb = Z_PONT
    lot.put(M["beton2"], E.tronc(E.octogone(cx, cy, R + 0.3), E.octogone(cx, cy, R + 0.2), zb - 0.05, zb + 0.14))
    z0, z1 = zb + 0.14, zb + 0.9
    pb, ph = E.octogone(cx, cy, R + 0.04), E.octogone(cx, cy, R - 0.04)
    lot.put(M["beton"], E.tronc(pb, ph, z0, z1))
    for k, (x, y) in enumerate(pb):                                  # pilastres aux angles
        q = ph[k]
        lot.put(M["plomb"], G.tube([(x, y, z0), (q[0], q[1], z1)], 0.075, 6))
        lot.put(M["jaune9"], G.tour([(z1 - 0.2, 0.09), (z1 - 0.12, 0.09)], 8, "z", ((x + q[0]) / 2, (y + q[1]) / 2, 0.0)))
    pans(lot, M, pb, ph, z0, z1, rr, [M["plomb"], M["plomb2"], M["plomb"]], (0.32, 0.5), (0.28, 0.5), 0.1)
    for k in (4, 5, 6):                                              # fentes vertes, côté caméra, toutes différentes
        a, b = pb[k], pb[(k + 1) % 8]
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        d = math.hypot(m[0] - cx, m[1] - cy)
        n = ((m[0] - cx) / d, (m[1] - cy) / d, 0.12)
        p = (m[0] + n[0] * 0.04, m[1] + n[1] * 0.04, z0 + 0.42)
        C.hublot(lot, ("carre", "octo", "barreaux")[k - 4], M["acier"], M["hublot"], p, n, 0.075 + 0.012 * (k - 4))
    z2 = z1 + 0.05
    ring = octo_pts(cx, cy, R - 0.02, z1 + 0.02)
    lot.put(M["danger"], E.tronc(E.octogone(cx, cy, R - 0.02), E.octogone(cx, cy, R - 0.07), z1, z2 + 0.03))
    lot.put(M["anneau"], anneau_poly(ring, 0.03))
    Rd = R - 0.08
    zt = z2 + 1.1
    prof = [(z2 + (zt - z2) * math.sin(t), Rd * math.cos(t)) for t in [i * (math.pi / 2 * 0.72) / 9.0 for i in range(10)]]
    lot.put(M["plomb"], G.tour(prof, 8, "z", (cx, cy, 0.0), a0=math.pi / 8, a1=math.pi / 8 + G.TAU))
    for k in range(8):
        a = math.pi / 8 + G.TAU * k / 8
        lot.put(M["anneau"], G.tube([(cx + (rp + 0.015) * math.cos(a), cy + (rp + 0.015) * math.sin(a), zp + 0.012) for (zp, rp) in prof], 0.024, 5))
    for i in (4, 8):
        zp, rp = prof[i]
        lot.put(M["anneau"], anneau_poly(octo_pts(cx, cy, rp + 0.012, zp + 0.01), 0.016))
    pans_d = [prof[i] for i in range(0, 9, 2)]
    for j in range(len(pans_d) - 1):                                 # plaques rapportées sur le dôme, décalées
        (za, ra), (zc, rc) = pans_d[j], pans_d[j + 1]
        pans(lot, M, E.octogone(cx, cy, ra + 0.012), E.octogone(cx, cy, rc + 0.012), za + 0.01, zc - 0.01, rr, [M["plomb"], M["plomb"], M["plomb2"]], (0.2, 0.42), (0.6, 1.0), 0.04)
    zs, rs = prof[-1]
    lot.put(M["plomb2"], G.tour([(zs - 0.01, rs + 0.03), (zs + 0.08, rs + 0.03), (zs + 0.11, rs - 0.03), (zs + 0.1, rs * 0.72)], 8, "z", (cx, cy, 0.0), a0=math.pi / 8, a1=math.pi / 8 + G.TAU))
    lot.put(M["coeur"], G.tour([(zs + 0.06, rs * 0.74), (zs + 0.05, 0.0)], 8, "z", (cx, cy, 0.0), a0=math.pi / 8, a1=math.pi / 8 + G.TAU))
    for k in range(4):                                               # barres de combustible qui affleurent
        a = 0.6 + G.TAU * k / 4
        lot.put(M["acier_clair"], G.tour([(zs + 0.03, 0.03), (zs + 0.18, 0.03), (zs + 0.2, 0.0)], 6, "z", (cx + rs * 0.42 * math.cos(a), cy + rs * 0.42 * math.sin(a), 0.0)))
    # couvercle du sas, relevé sur sa charnière
    hx, hy = cx + rs * 0.9, cy + rs * 0.3
    v, f, u = G.tour([(0.0, rs * 0.92), (0.05, rs * 0.92), (0.07, rs * 0.3), (0.075, 0.0)], 8, "z", cap0=True)
    v = [G.add(G.rot_y((q[0] + rs * 0.9, q[1], q[2]), 1.05), (hx - rs * 0.1, hy - 0.05, zs + 0.09)) for q in v]
    lot.put(M["plomb"], (v, f, u))
    lot.put(M["jaune9"], G.tube([(hx, hy - 0.2, zs + 0.11), (hx, hy + 0.1, zs + 0.11)], 0.03, 6))
    return zs + 0.2


def tour_ref(lot, M, cx, cy, R0, Rw, H, zw, rr, nleg=20):
    """Tour de refroidissement : coque hyperboloïde r(z) = Rw √(1 + ((z - zw) / c)²), béquilles croisées au pied, plis de
    coffrage, coulures, intérieur sombre, bague et passerelle du haut, échelle côté caméra."""
    zb = 0.62
    c = (zw - zb) / math.sqrt((R0 / Rw) ** 2 - 1.0)

    def rz(z):
        return Rw * math.sqrt(1.0 + ((z - zw) / c) ** 2)
    n = 16
    prof = [(zb + (H - zb) * i / float(n), rz(zb + (H - zb) * i / float(n))) for i in range(n + 1)]
    lot.put(M["tour"], G.tour(prof, 48, "z", (cx, cy, 0.0)))
    lot.put(M["tour_int"], G.tour([(z, r_ - 0.05) for (z, r_) in reversed(prof)] + [(zb + 0.2, 0.0)], 48, "z", (cx, cy, 0.0)))
    lot.put(M["gaine"], G.tour([(H - 0.05, rz(H) - 0.07), (H + 0.03, rz(H) - 0.07), (H + 0.06, rz(H) + 0.0), (H + 0.03, rz(H) + 0.07), (H - 0.04, rz(H) + 0.05)], 48, "z", (cx, cy, 0.0)))
    lot.put(M["danger"], G.tour([(H - 0.42, rz(H - 0.42) + 0.012), (H - 0.22, rz(H - 0.22) + 0.012)], 48, "z", (cx, cy, 0.0)))
    z = zb + 0.32                                                    # plis de coffrage
    while z < H - 0.5:
        r_ = rz(z)
        lot.put(M["beton2"], G.tour([(z - 0.014, r_ + 0.002), (z, r_ + 0.016), (z + 0.014, r_ + 0.002)], 48, "z", (cx, cy, 0.0)))
        z += rr.f(0.3, 0.46)
    # bague du pied et béquilles croisées
    lot.put(M["beton2"], G.tour([(zb - 0.09, R0 + 0.07), (zb + 0.03, R0 + 0.07), (zb + 0.05, R0 - 0.03)], 48, "z", (cx, cy, 0.0)))
    for k in range(nleg):
        a0, a1 = G.TAU * k / nleg, G.TAU * (k + 1) / nleg
        p0 = (cx + (R0 + 0.12) * math.cos(a0), cy + (R0 + 0.12) * math.sin(a0), 0.0)
        p1 = (cx + R0 * math.cos(a1), cy + R0 * math.sin(a1), zb - 0.05)
        q0 = (cx + (R0 + 0.12) * math.cos(a1), cy + (R0 + 0.12) * math.sin(a1), 0.0)
        q1 = (cx + R0 * math.cos(a0), cy + R0 * math.sin(a0), zb - 0.05)
        lot.put(M["beton"], G.tube([p0, p1], 0.038, 5))
        lot.put(M["beton"], G.tube([q0, q1], 0.038, 5))
    lot.put(M["dalle2"], G.tour([(0.0, R0 + 0.24), (0.1, R0 + 0.22), (0.12, R0 - 0.2)], 48, "z", (cx, cy, 0.0), cap1=True))
    lot.put(M["noir"], G.tour([(0.12, R0 - 0.18), (0.13, R0 - 0.18), (0.14, 0.0)], 32, "z", (cx, cy, 0.0)))
    # échelle sur la coque, côté sud-ouest
    la = -math.pi / 2 - 0.55
    for s in (-0.07, 0.07):
        pts = [(cx + (rz(z_) + 0.05) * math.cos(la + s / rz(z_)), cy + (rz(z_) + 0.05) * math.sin(la + s / rz(z_)), z_) for z_ in [zb + (H - zb) * i / 12.0 for i in range(13)]]
        lot.put(M["acier"], G.tube(pts, 0.01, 4))
    z = zb + 0.08
    while z < H - 0.05:
        r_ = rz(z) + 0.05
        lot.put(M["acier"], G.tube([(cx + r_ * math.cos(la - 0.07 / r_), cy + r_ * math.sin(la - 0.07 / r_), z), (cx + r_ * math.cos(la + 0.07 / r_), cy + r_ * math.sin(la + 0.07 / r_), z)], 0.007, 3))
        z += 0.13
    # garde-corps du haut, côté caméra
    pts = [(cx + (rz(H) + 0.09) * math.cos(a), cy + (rz(H) + 0.09) * math.sin(a), H + 0.2) for a in [-math.pi + math.pi * i / 16.0 for i in range(17)]]
    lot.put(M["jaune9"], G.tube(pts, 0.012, 4))
    for p in pts[::2]:
        lot.put(M["jaune9"], G.tube([(p[0], p[1], H), p], 0.009, 3))
    return rz


def bunker(lot, M, rr):
    """Bunker en gradins chanfreinés : assise de béton à fruit gainée de plomb, toit ; donjon en retrait ; tourelle
    octogonale à hublot ; portique jaune. Vu de trois quarts : les toits et les pans coupés se lisent, pas de façade plate."""
    K = BK
    z0 = K["z0"]
    P0 = E.chanfrein(K["x0"], K["x1"], K["y0"], K["y1"], K["ch"])
    P1 = E.retrait(P0, 0.15)
    P2 = E.retrait(P0, 0.22)
    lot.put(M["beton"], E.tronc(P0, P1, z0, 1.02))
    pans(lot, M, P0, P1, z0 + 0.1, 1.02, rr, [M["plomb"], M["plomb2"], M["plomb"], M["gaine"]], (0.36, 0.78), (0.28, 0.5), 0.1, faces=(0, 1, 7, 2, 6))
    Pp = E.retrait(P0, -0.015)
    lot.put(M["danger"], E.tronc(Pp, Pp, z0, z0 + 0.1, False))
    lot.put(M["plomb2"], E.tronc(P1, P2, 1.02, 1.08))
    lot.put(M["anneau"], anneau_poly([(p[0], p[1], 1.03) for p in P1], 0.025))
    # dalle du toit, tôlée
    for (xa, xb) in ((K["x0"] + 0.25, -1.45), (0.62, K["x1"] - 0.25)):
        x = xa
        while x < xb - 0.05:
            w = min(rr.f(0.28, 0.55), xb - x)
            y = K["y0"] + 0.25
            while y < K["y1"] - 0.25:
                h = min(rr.f(0.3, 0.55), K["y1"] - 0.25 - y)
                if not ((x < K["x0"] + 0.5 or x + w > K["x1"] - 0.5) and (y < K["y0"] + 0.45 or y + h > K["y1"] - 0.45)):
                    lot.put(M["plomb"] if rr.f() < 0.6 else M["plomb2"], G.boite((x + w / 2, y + h / 2, 1.09), (w - 0.016, h - 0.016, 0.02)))
                y += h
            x += w
    # donjon
    Pd = E.chanfrein(-1.42, 0.58, -2.66, -1.58, 0.3)
    Pd1 = E.retrait(Pd, 0.09)
    lot.put(M["beton"], E.tronc(Pd, Pd1, 1.06, 1.64))
    pans(lot, M, Pd, Pd1, 1.08, 1.62, rr, [M["plomb"], M["plomb2"], M["gaine"]], (0.3, 0.6), (0.4, 0.7), 0.08, faces=(0, 1, 7))
    lot.put(M["danger"], E.tronc(Pd1, E.retrait(Pd1, 0.05), 1.64, 1.68))
    lot.put(M["plomb"], E.tronc(E.retrait(Pd1, 0.05), E.retrait(Pd1, 0.09), 1.66, 1.7))
    # tourelle octogonale
    tx, ty = -0.62, -2.12
    lot.put(M["plomb"], E.tronc(E.octogone(tx, ty, 0.44), E.octogone(tx, ty, 0.38), 1.68, 2.05))
    lot.put(M["anneau"], anneau_poly(octo_pts(tx, ty, 0.4, 2.02), 0.02))
    lot.put(M["beton2"], G.tour([(2.05, 0.38), (2.14, 0.34), (2.26, 0.14), (2.3, 0.0)], 8, "z", (tx, ty, 0.0), a0=math.pi / 8, a1=math.pi / 8 + G.TAU))
    C.hublot(lot, "octo", M["acier"], M["hublot"], (tx - 0.05, ty - 0.385, 1.86), (0.0, -1.0, 0.2), 0.095)
    lot.put(M["acier"], G.tube([(tx + 0.14, ty + 0.1, 2.2), (tx + 0.14, ty + 0.1, 2.85)], 0.012, 4))
    lot.put(M["voyant"], G.sphere((tx + 0.14, ty + 0.1, 2.87), 0.022, 6, 3))
    # portique jaune sur le toit de l'aile ouest, palan
    for x in (-2.18, -1.55):
        for y in (-2.68, -1.72):
            lot.put(M["jaune9"], G.boite((x, y, 1.42), (0.07, 0.07, 0.66)))
    for y in (-2.68, -1.72):
        lot.put(M["jaune9"], G.boite((-1.87, y, 1.74), (0.76, 0.08, 0.07)))
    lot.put(M["danger"], G.boite((-1.82, -2.2, 1.79), (0.09, 1.06, 0.09)))
    lot.put(M["acier"], G.boite((-1.82, -2.42, 1.71), (0.14, 0.14, 0.09)))
    lot.put(M["noir"], G.tube([(-1.82, -2.42, 1.68), (-1.82, -2.42, 1.2)], 0.006, 3))
    lot.put(M["jaune9"], G.tour([(1.08, 0.09), (1.2, 0.09), (1.22, 0.0)], 8, "z", (-1.82, -2.42, 0.0)))
    # évents, champignons, gaine sur le toit de l'aile est
    C.evente(lot, M["gaine"], M["noir"], (1.05, -2.5, 1.1), 0.26, 0.42, 5, 0.0, 0.14)
    C.evente(lot, M["plomb2"], M["noir"], (1.1, -1.92, 1.1), 0.22, 0.3, 4, 0.0, 0.12)
    C.evente(lot, M["gaine"], M["noir"], (-0.92, -2.48, 1.68), 0.2, 0.3, 4, 0.0, 0.1)
    for (x, y, z, r0) in ((0.72, -2.15, 1.1, 0.085), (0.25, -2.42, 1.7, 0.075), (0.3, -1.9, 1.7, 0.09), (-1.2, -1.9, 1.7, 0.07), (-2.15, -1.62, 1.1, 0.08)):
        lot.put(M["gaine"], G.tour([(z - 0.04, r0), (z + 0.18, r0)], 10, "z", (x, y, 0.0)))
        lot.put(M["plomb2"], G.tour([(z + 0.17, r0 * 1.9), (z + 0.21, r0 * 1.7), (z + 0.26, 0.02)], 12, "z", (x, y, 0.0)))
        lot.put(M["noir"], G.tour([(z + 0.13, r0 * 1.05), (z + 0.17, r0 * 1.05)], 10, "z", (x, y, 0.0)))
    for (x, y) in ((-1.0, -1.72), (0.15, -2.45)):                    # trappes rondes à volant
        lot.put(M["plomb2"], G.tour([(1.66, 0.14), (1.72, 0.14), (1.74, 0.0)], 12, "z", (x, y, 0.0)))
        lot.put(M["jaune9"], E.cerceau(x, y, 1.77, 0.08, 0.01, 12))
    # façade sud : sas blindé, porche, trèfle, grilles, fenêtre, armoires
    dx0, dx1 = -0.92, -0.1
    ys = K["y0"]
    lot.put(M["beton2"], E.tronc([(dx0 - 0.14, ys - 0.14), (dx1 + 0.14, ys - 0.14), (dx1 + 0.14, ys + 0.14), (dx0 - 0.14, ys + 0.14)],
                                 [(dx0 - 0.08, ys - 0.1), (dx1 + 0.08, ys - 0.1), (dx1 + 0.08, ys + 0.14), (dx0 - 0.08, ys + 0.14)], z0, 1.12))
    lot.put(M["noir"], G.boite(((dx0 + dx1) / 2, ys - 0.115, z0 + 0.3), (dx1 - dx0 - 0.06, 0.02, 0.56)))
    lot.put(M["danger"], G.boite((dx0 + 0.13, ys - 0.13, z0 + 0.3), (0.26, 0.03, 0.56)))
    lot.put(M["plomb"], G.boite((dx1 - 0.2, ys - 0.135, z0 + 0.3), (0.38, 0.04, 0.54)))
    lot.put(M["acier_clair"], G.tour([(-0.01, 0.07), (0.02, 0.07)], 10, "y", (dx1 - 0.2, ys - 0.16, z0 + 0.3)))
    lot.put(M["danger"], G.boite(((dx0 + dx1) / 2, ys - 0.14, z0 + 0.62), (dx1 - dx0, 0.04, 0.07)))
    trefle(lot, M, ((dx0 + dx1) / 2, ys - 0.1, 0.99), (0.0, -1.0, 0.25), 0.11)
    lot.put(M["voyant"], G.boite((dx0 - 0.1, ys - 0.15, z0 + 0.5), (0.04, 0.012, 0.04)))
    # rampe vers la dalle
    lot.put(M["beton2"], G.prisme([(dx0 - 0.02, ys - 0.72), (dx1 + 0.02, ys - 0.72), (dx1 + 0.02, ys - 0.12), (dx0 - 0.02, ys - 0.12)], 0.2, z0 + 0.04))
    for (x, y, wy) in ((-2.05, ys + 0.1, 0.42), (0.75, ys + 0.03, 0.5)):      # grilles dans le mur à fruit
        n = (0.0, -1.0, 0.3)
        p = (x, y, 0.72)
        lot.put(M["acier"], C.pose_plane(G.boite((0, 0, 0.0), (wy + 0.08, 0.32, 0.03)), p, n))
        lot.put(M["noir"], C.pose_plane(G.boite((0, 0, 0.012), (wy, 0.24, 0.025)), p, n))
        for k in range(6):
            lot.put(M["acier"], C.pose_plane(G.boite((-wy / 2 + wy * (k + 0.5) / 6, 0, 0.03), (wy / 6 * 0.45, 0.24, 0.02)), p, n))
    C.hublot(lot, "double", M["acier"], M["hublot"], (0.3, ys + 0.04, 0.74), (0.0, -1.0, 0.25), 0.07)
    C.hublot(lot, "rond", M["acier"], M["veilleuse"], (-1.45, ys + 0.04, 0.74), (0.0, -1.0, 0.25), 0.075)
    trefle(lot, M, (1.18, ys + 0.1, 0.72), (0.0, -1.0, 0.3), 0.12)
    # pans coupés de l'est et de l'ouest : armoires et descente
    C.tuyau(lot, M["conduit"], M["anneau"], [(K["x1"] + 0.02, -2.2, 1.0), (K["x1"] + 0.12, -2.2, 0.9), (K["x1"] + 0.12, -2.2, 0.36)], 0.045, rb=0.08, pas_bride=0.3)
    for (x, y) in ((1.42, -2.82), (-2.36, -2.84)):
        lot.put(M["plomb2"], G.boite((x, y, z0 + 0.2), (0.3, 0.2, 0.4), 0.78 if x > 0 else -0.78))
        lot.put(M["voyant"], G.boite((x + (-0.06 if x < 0 else 0.06), y - 0.08, z0 + 0.32), (0.025, 0.012, 0.025)))


def piscine(lot, M, cx, cy, R, rr):
    """Piscine de refroidissement : cuve octogonale de béton, margelle, eau verte (foyer), barres de combustible en rangs
    tirés, pont roulant jaune au-dessus, garde-corps."""
    z0 = 0.3
    Pe = E.octogone(cx, cy, R + 0.2)
    Pm = E.octogone(cx, cy, R + 0.14)
    Pi = E.octogone(cx, cy, R - 0.02)
    lot.put(M["beton"], E.tronc(Pe, Pm, z0, 0.76, False))
    pans(lot, M, Pe, Pm, z0 + 0.02, 0.74, rr, [M["plomb2"], M["plomb"]], (0.3, 0.5), (0.5, 0.8), 0.06, faces=(4, 5, 6))
    v, f, u = E.tronc(Pm, Pi, 0.76, 0.78, False)
    lot.put(M["dalle"], (v, f, u))
    lot.put(M["danger"], E.tronc(E.octogone(cx, cy, R + 0.105), E.octogone(cx, cy, R + 0.04), 0.783, 0.787, False))
    lot.put(M["tour_int"], E.tronc(Pi, E.octogone(cx, cy, R - 0.05), 0.78, 0.5, False))
    lot.put(M["eau"], G.prisme(E.octogone(cx, cy, R - 0.04), 0.48, 0.52))
    for i in range(-3, 4):
        for j in range(-3, 4):
            x, y = cx + i * 0.21 + (0.1 if j % 2 else 0.0), cy + j * 0.19
            if math.hypot(x - cx, y - cy) < R - 0.2 and rr.f() < 0.72:
                h = rr.f(0.05, 0.11)
                lot.put(M["anneau"], G.tour([(0.5, 0.042), (0.52 + h, 0.042), (0.53 + h, 0.0)], 6, "z", (x, y, 0.0)))
    # caillebotis : passerelles au travers de la cuve, moins de néon, plus de pièces
    for (xc, yc, w, l, rz) in ((cx + 0.32, cy, 0.34, 2 * R - 0.2, 0.0), (cx - 0.28, cy - 0.3, 0.72, 0.28, 0.0), (cx - 0.1, cy + 0.34, 0.48, 0.3, 0.0)):
        lot.put(M["anneau"], G.boite((xc, yc, 0.76), (w, l, 0.025), rz))
        k = int(l / 0.07)
        for j in range(k):
            lot.put(M["noir"], G.boite((xc, yc - l / 2 + l * (j + 0.5) / k, 0.775), (w - 0.04, l / k * 0.5, 0.008), rz))
    # pont roulant
    for s in (-1, 1):
        y = cy + s * (R + 0.1)
        for x in (cx - 0.95, cx + 0.95):
            lot.put(M["jaune9"], G.boite((x, y, 0.82), (0.07, 0.07, 1.04)))
        lot.put(M["jaune9"], G.boite((cx, y, 1.36), (2.0, 0.08, 0.07)))
    lot.put(M["danger"], G.boite((cx - 0.15, cy, 1.42), (0.12, 2 * R + 0.3, 0.1)))
    lot.put(M["plomb2"], G.boite((cx - 0.15, cy - 0.2, 1.32), (0.22, 0.28, 0.14)))
    lot.put(M["noir"], G.tube([(cx - 0.15, cy - 0.2, 1.25), (cx - 0.15, cy - 0.2, 0.86)], 0.007, 3))
    lot.put(M["acier_clair"], G.tour([(0.62, 0.05), (0.86, 0.05)], 6, "z", (cx - 0.15, cy - 0.2, 0.0), cap1=True))
    pts = [(p[0], p[1], 0.78) for p in Pm]
    for k in (3, 4, 5, 6, 7):
        E.garde(lot, {"acier": M["jaune9"]}, pts[k], pts[(k + 1) % 8], 0.26)


def capsule(lot, M, cx, cy, R, rr):
    """Capsule de combustible : drum octogonal de plomb, bandes d'avertissement, dôme, hublot faible, trèfle."""
    z0 = 0.3
    lot.put(M["beton2"], E.tronc(E.octogone(cx, cy, R + 0.2), E.octogone(cx, cy, R + 0.14), z0, 0.46))
    pb, ph = E.octogone(cx, cy, R), E.octogone(cx, cy, R - 0.05)
    lot.put(M["plomb"], E.tronc(pb, ph, 0.46, 1.1))
    lot.put(M["danger"], E.tronc(E.octogone(cx, cy, R + 0.005), E.octogone(cx, cy, R - 0.012), 0.86, 0.95, False))
    pans(lot, M, pb, ph, 0.47, 0.84, rr, [M["plomb2"], M["gaine"]], (0.2, 0.34), (0.5, 0.9), 0.05, faces=(4, 5, 6))
    lot.put(M["plomb2"], G.tour([(1.1, R - 0.03), (1.2, R - 0.1), (1.38, R * 0.55), (1.46, 0.0)], 8, "z", (cx, cy, 0.0), a0=math.pi / 8, a1=math.pi / 8 + G.TAU))
    lot.put(M["anneau"], anneau_poly(octo_pts(cx, cy, R - 0.02, 1.1), 0.022))
    trefle(lot, M, (cx + 0.05, cy - R * 0.93, 0.68), (0.0, -1.0, 0.05), 0.11)
    C.hublot(lot, "ovale", M["acier"], M["veilleuse"], (cx + R * 0.72, cy - R * 0.55, 0.72), (0.75, -0.65, 0.05), 0.06)
    lot.put(M["acier"], G.tube([(cx, cy, 1.46), (cx, cy, 1.95)], 0.014, 4))
    lot.put(M["jaune9"], G.tour([(1.72, 0.04), (1.78, 0.04)], 6, "z", (cx, cy, 0.0)))


def pylone(lot, M, x, y, h, rr):
    """Pylône treillis à balise de radiation : 4 montants resserrés, croix, plateforme, balise verte, trèfle au pied."""
    b = 0.34
    t = 0.07
    cs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]

    def p(c, z):
        k = b + (t - b) * z / h
        return (x + c[0] * k, y + c[1] * k, z)
    for c in cs:
        lot.put(M["acier"], G.tube([p(c, 0.0), p(c, h)], 0.018, 5))
    nz = 7
    for i in range(nz):
        za, zb = h * i / nz, h * (i + 1) / nz
        for j in range(4):
            a, b_ = cs[j], cs[(j + 1) % 4]
            lot.put(M["acier"], G.tube([p(a, za), p(b_, zb)], 0.009, 3))
            lot.put(M["acier"], G.tube([p(b_, za), p(a, zb)], 0.009, 3))
            lot.put(M["acier"], G.tube([p(a, zb), p(b_, zb)], 0.009, 3))
    lot.put(M["danger"], G.boite((x, y, h + 0.03), (0.34, 0.34, 0.05)))
    lot.put(M["plomb2"], G.tour([(h + 0.05, 0.08), (h + 0.2, 0.07)], 8, "z", (x, y, 0.0), cap1=True))
    lot.put(M["hublot"], G.sphere((x, y, h + 0.27), 0.075, 10, 5))
    for k in range(4):
        a = G.TAU * k / 4 + 0.4
        lot.put(M["acier"], G.tube([(x + 0.09 * math.cos(a), y + 0.09 * math.sin(a), h + 0.18), (x + 0.09 * math.cos(a), y + 0.09 * math.sin(a), h + 0.38)], 0.006, 3))
    lot.put(M["beton2"], E.tronc(E.chanfrein(x - 0.5, x + 0.5, y - 0.5, y + 0.5, 0.14), E.chanfrein(x - 0.42, x + 0.42, y - 0.42, y + 0.42, 0.12), 0.0, 0.2))
    trefle(lot, M, (x, y - 0.1, 0.72), (0.0, -1.0, 0.0), 0.1)
    lot.put(M["plomb2"], C.pose_plane(G.boite((0, 0, -0.01), (0.34, 0.34, 0.012)), (x, y - 0.1, 0.72), (0.0, -1.0, 0.0)))


def dalles(lot, M, xa, xb, ya, yb, z, rr, trou=0.03):
    """Grande dalle de béton coulé : panneaux larges à joints de dilatation, quelques-uns plus sombres, bouchons."""
    lot.put(M["noyau"], G.boite(((xa + xb) / 2, (ya + yb) / 2, z - 0.05), (xb - xa, yb - ya, 0.06)))
    y = ya
    while y < yb - 0.02:
        hy = min(rr.f(0.48, 0.92), yb - y)
        x = xa
        while x < xb - 0.02:
            w = min(rr.f(0.62, 1.25), xb - x)
            if rr.f() > trou:
                m = M["dalle"] if rr.f() < 0.74 else M["dalle2"]
                lot.put(m, G.boite((x + w / 2, y + hy / 2, z - 0.03), (w - 0.028, hy - 0.028, 0.06)))
                if rr.f() < 0.3:
                    lot.put(M["plomb2"], G.tour([(z, 0.05), (z + 0.012, 0.05), (z + 0.014, 0.0)], 8, "z", (x + w * rr.f(0.2, 0.8), y + hy * rr.f(0.2, 0.8), 0.0)))
            x += w
        y += hy


def bloc_chicane(lot, M, x, y, rz, L=0.72):
    """Séparateur de béton à profil en K (chicane), bande d'avertissement sur le dessus."""
    prof = [(-0.12, 0.0), (0.12, 0.0), (0.07, 0.1), (0.04, 0.3), (-0.04, 0.3), (-0.07, 0.1)]
    v = []
    for s in (-L / 2, L / 2):
        for (py, pz) in prof:
            v.append(G.add(G.rot_z((s, py, pz), rz), (x, y, 0.3)))
    rings = [v[:6], v[6:]]
    lot.put(M["beton"], G.loft(rings, cap0=True, cap1=True))
    lot.put(M["danger"], G.boite((x, y, 0.605), (L * 0.98, 0.08, 0.012), rz))


# ================================================================================================ build
def build(S, lot):
    M = matieres(S)
    P = C.Pose(**E.POSE)
    r = G.Rnd(9099)
    niv = P.niv
    TAU = G.TAU
    choix = E.mat_tirage(M, [("jaune0", 0.36), ("jaune1", 0.52), ("jaune2", 0.6), ("jaune3", 0.67), ("plomb", 0.84), ("plomb2", 0.94), ("rapiece", 1.0)])

    # ======================================================================================== 1. carcasse
    pieds = E.carcasse(lot, M, P, r, choix, ouverture=(-1.72, 2.0))
    E.grilles_coque(lot, M, P)
    for (pn, ps) in pieds:                                           # jambes : poteau de plomb, bague jaune, dé de béton chanfreiné
        for p in (pn, ps):
            h = p[2]
            lot.put(M["plomb2"], G.boite((p[0], p[1], h / 2), (0.15, 0.17, h)))
            lot.put(M["anneau"], G.boite((p[0], p[1], h - 0.15), (0.24, 0.26, 0.12)))
            lot.put(M["jaune9"], G.boite((p[0], p[1], 0.62), (0.17, 0.19, 0.08)))
            lot.put(M["beton"], E.tronc(E.chanfrein(p[0] - 0.24, p[0] + 0.24, p[1] - 0.24, p[1] + 0.24, 0.08), E.chanfrein(p[0] - 0.18, p[0] + 0.18, p[1] - 0.18, p[1] + 0.18, 0.06), 0.0, 0.36))
            pts = [((p[0] + dx, p[1] + dy, 0.365), (0, 0, 1)) for dx in (-0.09, 0.09) for dy in (-0.1, 0.1)]
            lot.put(M["riv"], G.rivets_le_long(pts, 0.022, 0.016))
    # blindage de plomb rapporté sur la queue et le crâne : bandes chanfreinées qui recouvrent la peau jaune
    lot.xf = P.xf
    for (xa_, xb_, a0, a1) in ((-3.3, -2.7, E.A_TOP + 0.45, E.A_TOP + 1.2), (2.35, 2.72, E.A_TOP - 1.0, E.A_TOP + 1.05)):
        C.bande(lot, C.surf_coque, M["plomb2"], xa_, xb_, a0, a1, 0.05, 0.05)
    lot.xf = None

    # ======================================================================================== 2. dans la cage : l'enceinte
    lot.xf = niv
    lot.put(M["beton2"], E.tronc(E.chanfrein(-2.5, 2.0, -1.8, 1.3, 0.5), E.chanfrein(-2.42, 1.92, -1.72, 1.22, 0.5), 0.0, Z_PONT))
    lot.xf = None
    rc = G.Rnd(9191)
    ec = niv((ENC[0], ENC[1], 0.0))
    zt = enceinte(lot, M, ec[0], ec[1], ENC[2], rc)
    # conduite de relevage vers le dos (l'enceinte reste branchée au vaisseau)
    sp = P.xf((ENC[0] + 0.5, 0.0, C.z_dessus(ENC[0] + 0.5) + 0.05))
    C.tuyau(lot, M["conduit"], M["jaune9"], [(ec[0] + 0.7, ec[1] + 0.35, Z_PONT + 1.25), (ec[0] + 0.7, ec[1] + 0.35, zt + 0.1), (sp[0], ec[1] + 0.4, zt + 0.1), (sp[0], sp[1], sp[2] - 0.05)], 0.07, rb=0.15, pas_bride=0.5)
    # mâts chargés sur le crâne, antennes de la cage
    m0 = P.xf((2.9, 0.0, C.z_dessus(2.9) + 0.12))
    lot.put(M["acier"], G.tube([m0, G.add(m0, (0, 0, 1.3))], 0.03, 6))
    for k in range(4):
        a = TAU * k / 4 + 0.4
        lot.put(M["acier"], G.tube([G.add(m0, (0.13 * math.cos(a), 0.13 * math.sin(a), 0.0)), G.add(m0, (0.02 * math.cos(a), 0.02 * math.sin(a), 1.25))], 0.012, 4))
    for z in (0.5, 0.9):
        lot.put(M["acier"], G.tube([G.add(m0, (-0.26, 0, z)), G.add(m0, (0.26, 0, z))], 0.013, 4))
    lot.put(M["voyant"], G.sphere(G.add(m0, (0, 0, 1.33)), 0.03, 6, 3))
    for x in (-1.3, 1.1):
        p = P.xf((x, 0.0, C.z_dessus(x) + 0.25))
        lot.put(M["acier"], G.tube([p, G.add(p, (0.0, 0.0, 0.9))], 0.012, 4))
        lot.put(M["acier"], G.tour([(p[2], 0.04), (p[2] + 0.08, 0.035)], 8, "z", (p[0], p[1], 0.0)))
    q = P.xf(C.point(-3.0, E.A_TOP + 0.85, 0.11))                    # trèfle peint sur la queue
    trefle(lot, M, q, G.norm(G.sub(P.xf(C.point(-3.0, E.A_TOP + 0.85, 0.4)), q)), 0.13)

    # ======================================================================================== 3. les deux tours et le pylône
    t1x, t1y = 4.1, 2.95
    rt = G.Rnd(9292)
    tour_ref(lot, M, t1x, t1y, 1.2, 0.74, 3.75, 2.75, rt, 24)
    t2x, t2y = -1.25, 3.25
    tour_ref(lot, M, t2x, t2y, 0.92, 0.58, 2.95, 2.15, rt, 20)
    pylone(lot, M, 1.5, 3.55, 3.05, rt)
    # bornes et trèfle du pied de la grande tour
    trefle(lot, M, (t1x - 0.36, t1y - 0.7, 2.62), G.norm((-0.45, -0.88, 0.08)), 0.17)
    # gaines annelées : grande tour vers le dos, petite tour vers l'enceinte (annelé fort, supports)
    for (a, b, c_, rg) in (((t1x - 1.15, t1y - 0.55, 0.3), (2.8, 2.15, 0.55), P.xf((1.95, 0.6, C.z_dessus(1.95) - 0.02)), 0.095),
                           ((t2x + 0.4, t2y - 0.85, 0.3), (t2x + 0.5, 2.1, 1.25), P.xf((ENC[0] + 0.3, 0.7, C.z_dessus(ENC[0]) - 0.1)), 0.08)):
        pts = G.catmull([a, b, c_], 14)
        lot.put(M["gaine"], G.tube(pts, rg, 10, rfun=lambda s, i, rg=rg: rg * (1.0 + 0.16 * math.cos(s * TAU / 0.08))))
    for (x, y, z) in ((2.8, 2.15, 0.45), (3.4, 2.32, 0.3)):
        lot.put(M["plomb2"], G.boite((x, y, z / 2), (0.1, 0.1, z)))
    C.tuyau(lot, M["conduit"], M["jaune9"], [(t1x - 0.95, t1y - 0.86, 0.5), (t1x - 0.95, 1.55, 0.5), (2.72, 1.55, 0.5), (2.72, 1.55, 1.0)], 0.085, rb=0.2)
    C.tuyau(lot, M["conduit"], M["anneau"], [(t2x + 0.9, t2y - 0.3, 0.42), (0.6, t2y - 0.3, 0.42), (0.6, 2.05, 0.42), (0.6, 2.05, 0.95)], 0.065, rb=0.15, pas_bride=0.45)

    # ======================================================================================== 4. bunker, piscine, capsule
    rv = G.Rnd(9303)
    bunker(lot, M, rv)
    piscine(lot, M, PISCINE[0], PISCINE[1], PISCINE[2], rv)
    capsule(lot, M, CAPSULE[0], CAPSULE[1], CAPSULE[2], rv)

    # ======================================================================================== 5. dalle
    zw = 0.3
    rd = G.Rnd(9404)
    K = BK
    segs = ((-4.85, -2.3, -3.4, zw, -1.45), (-2.3, 1.15, -3.82, zw + 0.0, K["y0"] + 0.1), (1.15, 3.95, -3.5, zw, -1.45))
    for (dx, dy, R) in (PISCINE, CAPSULE):                           # bastions chanfreinés sous la piscine et la capsule
        Pb = E.octogone(dx, dy - 0.15, R + 0.72)
        lot.put(M["beton"], E.tronc(E.retrait(Pb, -0.05), Pb, 0.0, zw + 0.01))
        lot.put(M["dalle"], G.prisme(E.retrait(Pb, 0.03), zw - 0.01, zw + 0.015))
        lot.put(M["danger"], E.tronc(Pb, E.retrait(Pb, 0.05), zw + 0.016, zw + 0.022, False))
    for (xa, xb, ya, za, yb) in segs:
        dalles(lot, M, xa, xb, ya + 0.04, yb, za, rd)
        lot.put(M["beton"], E.tronc([(xa, ya - 0.08), (xb, ya - 0.08), (xb, ya + 0.06), (xa, ya + 0.06)], [(xa, ya - 0.02), (xb, ya - 0.02), (xb, ya + 0.06), (xa, ya + 0.06)], 0.0, za + 0.02))
        lot.put(M["danger"], G.boite(((xa + xb) / 2, ya - 0.0, za + 0.024), (xb - xa, 0.09, 0.012)))
    for (x, rz) in ((-1.95, 0.04), (-1.3, -0.05), (0.55, 0.06), (1.05, -0.03)):
        bloc_chicane(lot, M, x, -3.72, rz)
    for (x, y, rz) in ((-4.68, -3.3, 0.2), (3.8, -3.42, -0.15), (4.05, -2.85, 1.2), (-5.0, -2.75, 1.45)):
        bloc_chicane(lot, M, x, y, rz, 0.62)
    E.garde(lot, {"acier": M["jaune9"]}, (-4.3, -3.28, zw), (-2.75, -3.28, zw), 0.32)
    E.garde(lot, {"acier": M["jaune9"]}, (1.55, -3.38, zw), (3.2, -3.38, zw), 0.32)

    for (x0_, y0_, x1_, y1_) in ((-2.3, -3.28, 1.15, -3.28), (-4.3, -1.72, -2.75, -1.72), (1.6, -1.55, 3.9, -1.55)):      # lignes jaunes au sol
        lot.put(M["jaune9"], G.boite(((x0_ + x1_) / 2, y0_, zw + 0.004), (x1_ - x0_, 0.035, 0.008)))
    rm = G.Rnd(9606)
    petits = [M["plomb2"], M["noyau"], M["anneau"], M["riv"], M["dalle2"]]
    E.menus_sol(lot, petits, rm, -2.3, 1.15, -3.72, -3.05, zw, 40)
    E.menus_sol(lot, petits, rm, -4.7, -2.65, -3.25, -1.6, zw, 28)
    E.menus_sol(lot, petits, rm, 1.6, 3.85, -3.4, -1.6, zw, 28)
    E.menus_sol(lot, petits, rm, -2.2, -1.45, -2.7, -1.7, 1.1, 14)
    E.menus_sol(lot, petits, rm, 0.65, 1.3, -2.75, -1.65, 1.1, 14)
    E.menus_sol(lot, petits, rm, -1.3, 0.45, -2.5, -1.7, 1.7, 22)
    E.menus_mur(lot, [M["anneau"], M["noyau"], M["plomb2"]], rm, BK["x0"] + 0.3, BK["x1"] - 0.3, BK["y0"] + 0.06, 0.45, 0.95, 40, (0.0, -1.0, 0.3))
    for (x, y) in ((-3.95, -1.95), (2.2, -3.1), (-0.95, -3.45)):      # regards de sol à grille
        lot.put(M["anneau"], G.boite((x, y, zw + 0.012), (0.42, 0.3, 0.02)))
        lot.put(M["noir"], G.boite((x, y, zw + 0.022), (0.36, 0.24, 0.006)))
        for k in range(5):
            lot.put(M["anneau"], G.boite((x - 0.14 + 0.07 * k, y, zw + 0.028), (0.025, 0.24, 0.008)))

    # ======================================================================================== 6. tuyauterie, flexibles, câbles
    x0, x1 = K["x0"], K["x1"]
    y1 = K["y1"]
    pv = niv
    C.tuyau(lot, M["conduit"], M["jaune9"], [(-3.1, -1.55, 1.05), (-2.75, -1.55, 1.05), (-2.75, -2.05, 0.75), (x0 + 0.02, -2.05, 0.75)], 0.1, rb=0.2)
    C.tuyau(lot, M["conduit"], M["anneau"], [pv((-3.3, 0.15, 2.15)), pv((-2.65, 0.15, 2.15)), pv((-2.35, -0.45, 2.0)), pv((-2.0, -0.45, 1.6)), pv((-2.0, -0.45, 0.6))], 0.07)
    C.tuyau(lot, M["gaine"], M["jaune9"], [(CAPSULE[0] + 0.45, CAPSULE[1] + 0.3, 0.72), (x0 - 0.02, CAPSULE[1] + 0.3, 0.72), (x0 + 0.08, -2.3, 0.72)], 0.055, rb=0.12, pas_bride=0.4)
    C.tuyau(lot, M["gaine"], M["jaune9"], [(PISCINE[0] - 0.95, PISCINE[1] + 0.2, 0.62), (x1 - 0.02, PISCINE[1] + 0.2, 0.62), (x1 - 0.1, -2.1, 0.8)], 0.06, rb=0.1, pas_bride=0.4)
    C.tuyau(lot, M["conduit"], M["anneau"], [(-1.2, y1 + 0.05, 1.05), (-1.2, y1 + 0.05, 1.42), (-1.2, ec[1] - 1.4, 1.42), (-1.2, ec[1] - 1.4, Z_PONT + 0.3)], 0.08, rb=0.16, pas_bride=0.5)
    C.tuyau(lot, M["conduit"], M["anneau"], [(0.35, y1 + 0.05, 1.05), (0.35, y1 + 0.05, 1.3), (0.35, ec[1] - 1.25, 1.3), (0.35, ec[1] - 1.25, Z_PONT + 0.3)], 0.06, rb=0.14, pas_bride=0.5)
    for (a, b, c_) in (((-4.55, -1.4, 1.2), (-4.65, -2.05, zw + 0.1), (-4.1, -2.5, zw + 0.25)),
                       ((-3.6, -1.15, 1.15), (-3.9, -1.65, 0.35), (CAPSULE[0] - 0.3, CAPSULE[1] + 0.5, 0.55)),
                       (pv((2.45, -0.9, 1.2)), (3.1, -1.1, 0.75), (PISCINE[0] + 0.2, PISCINE[1] + 1.05, 0.55)),
                       ((ec[0] - 0.9, ec[1] - 1.05, Z_PONT + 0.2), (ec[0] - 1.15, ec[1] - 1.3, 0.4), (-1.75, y1 + 0.02, 0.85)),
                       (P.xf((-0.3, 1.3, 0.25)), pv((-0.25, 1.35, 1.0)), pv((0.1, 1.2, 0.5))),
                       ((PISCINE[0] + 0.75, PISCINE[1] + 0.85, 0.55), (PISCINE[0] + 1.0, PISCINE[1] + 1.15, 0.2), (4.05, -0.5, 0.25))):
        C.flexible(lot, M["caoutchouc"], [a, b, c_], 0.048)
    for (x, y, rr_) in ((-5.0, -1.7, 0.2), (1.8, -3.25, 0.16)):       # rouleaux de flexible
        for k in range(3):
            rk = rr_ - 0.032 * k
            lot.put(M["caoutchouc"], G.tube([(x + rk * math.cos(TAU * j / 18), y + rk * math.sin(TAU * j / 18), zw + 0.035 + 0.055 * k) for j in range(19)], 0.028, 6))
    ra = G.Rnd(9505)
    E.cablage(lot, M, P, pieds, ra)
    C.faisceau(lot, M["rouge"], M["noir"], P.xf((-1.2, 0.0, C.z_dessus(-1.2) + 0.3)), (t2x + 0.3, t2y - 0.5, 1.5), 0.22, 3, 0.011, 0.028, ra)
    C.faisceau(lot, M["rouge"], M["noir"], (t1x - 0.8, t1y - 0.8, 1.6), P.xf((2.9, 0.4, C.z_dessus(2.9) + 0.6)), 0.3, 3, 0.011, 0.028, ra)
    C.faisceau(lot, M["rouge"], M["noir"], (x1 - 0.1, -2.3, 1.05), (PISCINE[0] - 1.0, PISCINE[1], 1.36), 0.2, 3, 0.011, 0.028, ra)
    C.faisceau(lot, M["rouge"], M["noir"], (1.5, 3.1, 1.9), (t1x - 1.05, t1y - 0.3, 1.5), 0.22, 3, 0.011, 0.028, ra)
    C.faisceau(lot, M["rouge"], M["noir"], (x0 + 0.1, -2.3, 1.0), (CAPSULE[0] + 0.1, CAPSULE[1], 1.3), 0.22, 3, 0.011, 0.028, ra)

    # ======================================================================================== 7. objets de la dalle
    for (x, y, m) in ((-4.75, -2.05, "jaune9"), (-4.95, -1.82, "jaune9"), (-4.55, -1.8, "plomb2"), (1.85, -3.0, "jaune9"), (-2.15, -3.05, "jaune9"), (-1.9, -3.2, "jaune9")):
        lot.put(M[m], G.tour([(zw, 0.15), (zw + 0.44, 0.15)], 12, "z", (x, y, 0.0), cap1=True))
        for z in (0.08, 0.36):
            lot.put(M["anneau"], G.tour([(zw + z - 0.015, 0.156), (zw + z + 0.015, 0.156)], 12, "z", (x, y, 0.0)))
        lot.put(M["noir"], G.boite((x, y - 0.148, zw + 0.22), (0.1, 0.012, 0.1)))
    for (x, y, sx, sy, sz, rz) in ((-1.5, -3.32, 0.62, 0.36, 0.36, 0.08), (0.7, -3.3, 0.56, 0.34, 0.34, -0.1), (3.75, -1.72, 0.7, 0.4, 0.4, 0.3)):   # conteneurs plombés
        lot.put(M["plomb"], G.boite((x, y, zw + sz / 2), (sx, sy, sz), rz))
        lot.put(M["danger"], G.boite((x, y, zw + sz * 0.78), (sx * 1.01, sy * 1.01, 0.05), rz))
        lot.put(M["plomb2"], G.boite((x, y, zw + sz + 0.015), (sx * 0.94, sy * 0.94, 0.03), rz))
    trefle(lot, M, (-1.5 + 0.02, -3.32 - 0.19, zw + 0.17), (0.08, -1.0, 0.0), 0.08)

    # ======================================================================================== 8. sol
    E.butte_nez(lot, M, P, r)
    for (x, y, a, b) in ((4.7, -3.75, 0.7, 0.4), (-5.7, -0.4, 0.55, 1.0), (2.1, 4.05, 0.8, 0.28)):
        lot.put(M["vase"], G.butte_polaire((x, y, 0.0), a, b, 0.025, r, 3, 36, 0.2, 0.22))
    for (x, y) in ((-3.4, -1.2), (-3.6, 1.95), (-4.5, -1.75), (-4.6, 2.0)):      # cales de béton sous les tuyères
        lot.put(M["beton"], E.tronc(E.chanfrein(x - 0.46, x + 0.46, y - 0.38, y + 0.38, 0.12), E.chanfrein(x - 0.3, x + 0.3, y - 0.26, y + 0.26, 0.08), 0.0, 0.72))
        lot.put(M["danger"], E.tronc(E.chanfrein(x - 0.3, x + 0.3, y - 0.26, y + 0.26, 0.08), E.chanfrein(x - 0.27, x + 0.27, y - 0.24, y + 0.24, 0.07), 0.72, 0.76))
        lot.put(M["acier"], G.tour([(0.75, 0.07), (1.05, 0.06)], 8, "z", (x, y, 0.0), cap1=True))
    for k in range(18):
        x, y = ra.f(-5.8, 5.8), ra.f(-4.1, 4.1)
        if abs(y) < 3.0 and abs(x) < 4.6:
            continue
        if ra.f() < 0.5:
            lot.put(M["plomb2"] if ra.f() < 0.5 else M["jaune1"], G.boite((x, y, 0.02), (ra.f(0.08, 0.2), ra.f(0.05, 0.12), 0.03), ra.f(0, 3.0), ra.f(-0.3, 0.3)))
        else:
            lot.put(M["acier"], G.boite((x, y, 0.03), (ra.f(0.25, 0.45), 0.04, 0.04), ra.f(0, 3.0)))
    for (x, y, rz) in ((5.3, -3.05, 1.4), (-5.8, -3.85, 0.3), (5.55, 2.25, 0.0), (5.0, -2.2, 2.2)):      # fûts jaunes couchés
        lot.put(M["jaune9"], E.couche(G.tour([(-0.22, 0.14), (0.22, 0.14)], 12, "x", cap0=True, cap1=True), (x, y), rz))
        lot.put(M["anneau"], E.couche(G.tour([(-0.13, 0.148), (-0.1, 0.148)], 12, "x"), (x, y), rz))
        lot.put(M["noir"], E.couche(G.tour([(0.02, 0.146), (0.1, 0.146)], 12, "x"), (x, y), rz))
    for (x, y, sx, sy, sz, rz) in ((-5.72, -1.3, 0.5, 0.36, 0.22, 0.3), (5.3, -1.45, 0.42, 0.32, 0.22, -0.5), (-5.45, 3.5, 0.5, 0.36, 0.24, 0.8), (1.2, 4.05, 0.42, 0.3, 0.18, 0.4)):
        lot.put(M["beton2"], G.boite((x, y, sz / 2 - 0.02), (sx, sy, sz), rz, 0.1, 0.08))
    for (x, y, a, b, rz) in ((-5.5, -1.95, 0.55, 0.38, 0.4), (4.85, -3.95, 0.5, 0.32, -0.7), (2.75, 4.08, 0.5, 0.3, 0.3)):
        lot.put(M["jaune1"] if a > 0.52 else M["plomb"], G.boite((x, y, 0.06), (a, b, 0.03), rz, 0.35, 0.15))
    lot.put(M["gaine"], E.couche(G.tour([(-0.45, 0.1), (0.45, 0.1)], 10, "x", cap0=True, cap1=True), (4.3, -4.05), 0.25, 0.1))
    lot.put(M["caoutchouc"], G.tour([(0.0, 0.17), (0.06, 0.195), (0.12, 0.17)], 16, "z", (-2.4, -4.05, 0.0)))
    return {"pose": E.POSE}
