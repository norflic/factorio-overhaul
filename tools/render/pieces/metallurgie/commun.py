"""COMMUN de la famille MÉTALLURGIE (lot DA-METALLURGIE) : palette (cohérente avec la chaîne du calcul : acier sombre à tôles,
patine, cuivre, chevrons ; plus la brique réfractaire, le métal en fusion, l'aluminium vif) et organes posés par toutes les machines.
Repère de geo.py : 1 unité = 1 tuile en X ; une tuile vers le sud vaut D = 1,414 unité en Y ; +Z haut (1 unité = 0,707 tuile à
l'écran). Une emprise N × N couvre x dans [-N/2, N/2], y dans [-N/2·D, N/2·D] ; le SUD est en y négatif.
"""
import math

import geo as G
import mat as MT
import outils as O

D = 1.0 / math.cos(math.radians(45.0))
TAU = G.TAU


def matieres(S):
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.16, ra=0.26, ec=0.6, nu_k=1.4, ec_col=(0.026, 0.017, 0.008),
                     sans=("verre", "alu", "cuivre", "noir", "brique", "beton", "ecume", "eponge", "coke"))
    sf = MT.surface
    cr = (0.009, 0.007, 0.005)
    M = {}
    M["acier"] = sf("m_acier", (0.15, 0.142, 0.132), rough=0.44, met=0.3, tole=(0.62, 0.41), joint=0.45, var=0.09, coulures=0.7,
                    rouille=(0.17, 0.075, 0.03), usure=0.75, nu=(0.6, 0.58, 0.54), crasse=0.9, crasse_col=cr, pied=(0.0, 0.8, 0.5),
                    grain=0.1, graine=11)
    M["acier_lisse"] = sf("m_acier_lisse", (0.15, 0.142, 0.132), rough=0.34, met=0.35, coulures=0.55, rouille=(0.17, 0.075, 0.03),
                          usure=0.6, nu=(0.62, 0.6, 0.56), crasse=0.85, crasse_col=cr, grain=0.08, graine=12)
    M["acier2"] = sf("m_acier2", (0.075, 0.07, 0.066), rough=0.5, met=0.35, tole=(0.33, 0.27), joint=0.5, var=0.1, coulures=0.7,
                     rouille=(0.16, 0.07, 0.03), usure=0.8, nu=(0.5, 0.48, 0.45), crasse=0.9, crasse_col=cr, pied=(0.0, 0.7, 0.55),
                     grain=0.11, graine=13)
    M["acier_clair"] = sf("m_acier_clair", (0.27, 0.262, 0.25), rough=0.36, met=0.8, usure=0.45, nu=(0.7, 0.68, 0.64), crasse=0.65,
                          crasse_col=cr, coulures=0.3, rouille=(0.17, 0.08, 0.035), graine=14)
    M["fonte"] = sf("m_fonte", (0.06, 0.055, 0.05), rough=0.62, met=0.3, usure=0.8, nu=(0.42, 0.39, 0.35), crasse=0.8, crasse_col=cr,
                    coulures=0.55, rouille=(0.14, 0.06, 0.022), grain=0.12, graine=15)
    M["brique"] = sf("m_brique", (0.34, 0.12, 0.062), rough=0.9, met=0.0, tole=(0.2, 0.09), joint=0.3, joint_l=0.012, var=0.26,
                     coulures=0.5, rouille=(0.025, 0.02, 0.018), usure=0.55, nu=(0.32, 0.18, 0.12), crasse=0.85, crasse_col=cr,
                     pied=(0.1, 0.6, 0.6), relief=0.7, grain=0.16, graine=16)
    M["brique_j"] = sf("m_brique_j", (0.42, 0.33, 0.2), rough=0.9, met=0.0, tole=(0.22, 0.1), joint=0.35, joint_l=0.012, var=0.2,
                       coulures=0.55, rouille=(0.05, 0.04, 0.03), usure=0.4, nu=(0.5, 0.42, 0.3), crasse=0.9, crasse_col=cr,
                       pied=(0.1, 0.6, 0.55), relief=0.6, grain=0.15, graine=17)
    M["suie"] = sf("m_suie", (0.03, 0.028, 0.026), rough=0.85, met=0.0, usure=0.3, nu=(0.1, 0.09, 0.08), crasse=0.6, crasse_col=cr,
                   grain=0.2, graine=18)
    M["beton"] = sf("m_beton", (0.24, 0.225, 0.2), rough=0.9, met=0.0, tole=(1.3, 0.55), joint=0.6, var=0.07, coulures=0.85,
                    rouille=(0.07, 0.06, 0.045), usure=0.5, nu=(0.34, 0.32, 0.29), crasse=0.8, crasse_col=cr, pied=(0.0, 1.0, 0.55),
                    relief=0.3, grain=0.16, graine=19)
    M["rouille"] = sf("m_rouille", (0.17, 0.065, 0.024), rough=0.8, met=0.25, usure=0.45, nu=(0.34, 0.2, 0.12), crasse=0.8,
                      crasse_col=cr, grain=0.2, graine=20)
    M["cuivre"] = sf("m_cuivre", (0.42, 0.17, 0.06), rough=0.32, met=0.9, coulures=0.7, rouille=(0.05, 0.17, 0.11), usure=0.55,
                     nu=(0.75, 0.42, 0.22), crasse=0.65, crasse_col=cr, graine=21)
    M["alu"] = sf("m_alu", (0.5, 0.51, 0.53), rough=0.3, met=0.95, usure=0.35, nu=(0.85, 0.86, 0.88), crasse=0.55,
                  crasse_col=(0.05, 0.05, 0.05), grain=0.06, graine=22)
    M["noir"] = sf("m_noir", (0.012, 0.0125, 0.014), rough=0.62, met=0.2, usure=0.45, nu=(0.16, 0.16, 0.16), crasse=0.6,
                   crasse_col=(0.003, 0.003, 0.003), grain=0.1, graine=23)
    M["riv"] = sf("m_riv", (0.09, 0.075, 0.05), rough=0.55, met=0.4, usure=0.3, crasse=0.5, graine=24)
    M["caoutchouc"] = sf("m_cao", (0.02, 0.02, 0.019), rough=0.72, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.065), crasse=0.5,
                         crasse_col=cr, graine=25)
    M["chevron"] = sf("m_chevron", (0.42, 0.26, 0.015), rough=0.5, met=0.2, bandes=(0.14, (0.012, 0.011, 0.01), 0.5), usure=0.8,
                      nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.5, graine=26)
    M["jaune"] = sf("m_jaune", (0.42, 0.24, 0.015), rough=0.48, met=0.2, coulures=0.7, rouille=(0.16, 0.06, 0.02), usure=0.8,
                    nu=(0.62, 0.6, 0.56), crasse=0.85, crasse_col=cr, grain=0.1, graine=27)
    M["rouge"] = sf("m_rouge", (0.3, 0.018, 0.012), rough=0.5, met=0.1, usure=0.45, nu=(0.45, 0.25, 0.18), crasse=0.5,
                    crasse_col=cr, graine=28)
    M["bleu"] = sf("m_bleu", (0.03, 0.09, 0.2), rough=0.42, met=0.35, coulures=0.5, rouille=(0.2, 0.26, 0.3), usure=0.65,
                   nu=(0.5, 0.5, 0.5), crasse=0.8, crasse_col=cr, grain=0.1, graine=29)
    M["vert"] = sf("m_vert", (0.03, 0.12, 0.06), rough=0.45, met=0.3, coulures=0.4, rouille=(0.18, 0.1, 0.04), usure=0.6,
                   nu=(0.5, 0.5, 0.45), crasse=0.75, crasse_col=cr, grain=0.1, graine=30)
    M["isolant"] = sf("m_isolant", (0.38, 0.385, 0.38), rough=0.75, met=0.0, tole=(0.3, 0.22), joint=0.55, var=0.08, coulures=0.55,
                      rouille=(0.12, 0.1, 0.08), usure=0.3, crasse=0.75, crasse_col=cr, grain=0.14, graine=31)
    M["porcelaine"] = sf("m_porcelaine", (0.24, 0.1, 0.045), rough=0.18, met=0.0, usure=0.2, crasse=0.6, crasse_col=(0.03, 0.02, 0.01),
                         grain=0.04, graine=32)
    M["verre"] = MT.verre("m_verre", col=(0.02, 0.07, 0.06), reflet=(0.22, 0.4, 0.36))
    M["charbon"] = sf("m_charbon", (0.02, 0.019, 0.02), rough=0.45, met=0.0, usure=0.6, nu=(0.1, 0.1, 0.11), crasse=0.5, grain=0.2,
                      graine=33)
    M["coke"] = sf("m_coke", (0.1, 0.095, 0.09), rough=0.85, met=0.1, usure=0.5, nu=(0.22, 0.21, 0.2), crasse=0.7,
                   crasse_col=(0.01, 0.01, 0.01), grain=0.3, graine=34)
    M["eponge"] = sf("m_eponge", (0.3, 0.3, 0.31), rough=0.8, met=0.6, usure=0.6, nu=(0.55, 0.55, 0.56), crasse=0.95,
                     crasse_col=(0.02, 0.02, 0.022), grain=0.35, graine=35)
    M["ecume"] = sf("m_ecume", (0.4, 0.37, 0.31), rough=0.3, met=0.3, usure=0.0, crasse=0.95, crasse_col=(0.03, 0.025, 0.02),
                    grain=0.3, graine=36)
    M["croute"] = sf("m_croute", (0.09, 0.085, 0.08), rough=0.9, met=0.0, usure=0.4, nu=(0.3, 0.29, 0.27), crasse=0.8,
                     crasse_col=(0.01, 0.01, 0.01), grain=0.3, graine=37)
    M["minerai"] = sf("m_minerai", (0.16, 0.1, 0.07), rough=0.8, met=0.1, usure=0.3, crasse=0.7, crasse_col=cr, grain=0.3, graine=38)
    M["sable"] = sf("m_sable", (0.36, 0.3, 0.22), rough=0.9, met=0.0, usure=0.0, crasse=0.6, crasse_col=cr, grain=0.3, graine=39)
    # lumières : le métal en fusion est la lueur de travail de la famille ; aucune surface émissive sans dégradé ni croûte
    M["fusion"] = S.mat_emissive("m_fusion", (1.0, 0.55, 0.12), strength=3.4, base=(0.08, 0.03, 0.005), main_scale=0.75,
                                 crust=(9.0, 0.45, 3.0))
    M["bain"] = S.mat_emissive("m_bain", (1.0, 0.36, 0.06), strength=2.6, base=(0.06, 0.02, 0.005), main_scale=0.7,
                               crust=(14.0, 0.6, 5.0))
    M["braise"] = S.mat_emissive("m_braise", (1.0, 0.3, 0.05), strength=2.2, base=(0.05, 0.015, 0.004), main_scale=0.7,
                                 crust=(18.0, 0.65, 7.0))
    M["laitier"] = S.mat_emissive("m_laitier", (0.95, 0.22, 0.04), strength=1.3, base=(0.06, 0.02, 0.006), main_scale=0.7,
                                  crust=(11.0, 0.7, 9.0))
    M["lampe"] = MT.degrade(S, "m_lampe", (1.0, 0.62, 0.16), (1.0, 0.3, 0.04), 4.0, main=0.6)
    M["feu_rouge"] = MT.degrade(S, "m_feu_rouge", (1.0, 0.16, 0.06), (0.7, 0.02, 0.01), 5.0, main=0.6)
    M["voyant"] = MT.degrade(S, "m_voyant", (0.4, 0.85, 1.0), (0.05, 0.4, 1.0), 4.0, main=0.55)
    M["voyant_v"] = MT.degrade(S, "m_voyant_v", (0.5, 1.0, 0.4), (0.1, 0.8, 0.15), 3.6, main=0.55)
    return M


# ---------------------------------------------------------------------------------------------------- organes
def bz(lot, m, x, y, z0, sx, sy, sz, rz=0.0):
    """Boîte posée : pied en z0."""
    lot.put(m, G.boite((x, y, z0 + sz / 2.0), (sx, sy, sz), rz))


def caisson(lot, m, x, y, z0, sx, sy, sz, ch=0.05):
    """Caisson à arêtes de toit chanfreinées (le dessus accroche la lumière)."""
    hx, hy = sx / 2.0, sy / 2.0
    pz = z0 + sz - ch
    c = [(x - hx, y - hy), (x + hx, y - hy), (x + hx, y + hy), (x - hx, y + hy)]
    lot.put(m, G.prisme(c, z0, pz))
    k = 1.0 - 2.0 * ch / max(0.01, min(sx, sy))
    lot.put(m, G.prisme(c, pz, z0 + sz, k))


def rev(lot, m, x, y, prof, segs=28, cap=True):
    """Révolution verticale : prof = [(z, r)] du bas vers le haut."""
    lot.put(m, G.tour(prof, segs, "z", (x, y, 0.0), cap0=cap, cap1=cap))


def cerclage(lot, m, x, y, z, r, w=0.05, e=0.022, segs=32):
    """Cerclage saillant autour d'un fût vertical de rayon r."""
    lot.put(m, G.tour([(z - w / 2, r), (z - w / 2 + 0.008, r + e), (z + w / 2 - 0.008, r + e), (z + w / 2, r)], segs, "z", (x, y, 0.0)))


def rambarde(lot, m, pts, z, h=0.3, pas=0.32, r=0.011):
    """Garde-corps le long d'une polyligne au niveau z : montants, lisse haute et sous-lisse."""
    for k in (h, h * 0.5):
        lot.put(m, G.tube([(p[0], p[1], z + k) for p in pts], r, 5))
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(L / pas))
        for j in range(n + (1 if i == len(pts) - 2 else 0)):
            p = G.lerp((a[0], a[1], 0.0), (b[0], b[1], 0.0), j / float(n))
            lot.put(m, G.tube([(p[0], p[1], z), (p[0], p[1], z + h)], r, 5))


def echelle(lot, m, a, b, l=0.16, pas=0.09, r=0.01):
    """Échelle droite de a à b (montants écartés de l en X)."""
    for s in (-1, 1):
        lot.put(m, G.tube([G.add(a, (s * l / 2, 0, 0)), G.add(b, (s * l / 2, 0, 0))], r, 5))
    L = G.length(G.sub(b, a))
    for i in range(1, int(L / pas)):
        p = G.lerp(a, b, i * pas / L)
        lot.put(m, G.tube([G.add(p, (-l / 2, 0, 0)), G.add(p, (l / 2, 0, 0))], r * 0.8, 4))


def bride(lot, m, p, n, r, e=0.025, boulons=None, mb=None):
    """Bride boulonnée de rayon r, normale n."""
    lot.put(m, G.oriente(G.tour([(-e / 2, r * 0.7), (-e / 2, r), (e / 2, r), (e / 2, r * 0.7)], 18, "z", cap0=True, cap1=True), p, n))
    if boulons and mb is not None:
        pts = []
        for k in range(boulons):
            t = TAU * k / boulons
            q = G.oriente(([(r * 0.85 * math.cos(t), r * 0.85 * math.sin(t), e / 2)], [], []), p, n)[0][0]
            pts.append((q, n))
        lot.put(mb, G.rivets_le_long(pts, r * 0.09, r * 0.07))


def vanne(lot, M, p, r=0.05, haut=0.14):
    """Vanne à volant posée en p (axe vertical) : corps, tige, volant rouge."""
    lot.put(M["fonte"], G.sphere(p, r * 1.1, 10, 5))
    lot.put(M["acier_clair"], G.tube([p, G.add(p, (0, 0, haut))], r * 0.18, 5))
    O.anneau(lot, M["rouge"], G.add(p, (0, 0, haut)), r * 1.5, r * 0.22, 16, 5)
    for t in (0.0, math.pi / 2):
        q = G.add(p, (0, 0, haut))
        lot.put(M["rouge"], G.tube([G.add(q, (r * 1.5 * math.cos(t), r * 1.5 * math.sin(t), 0)),
                                    G.add(q, (-r * 1.5 * math.cos(t), -r * 1.5 * math.sin(t), 0))], r * 0.12, 4))


def armoire(lot, M, x, y, z0, sx, sy, sz, lampe=True, face=(0.0, -1.0, 0.0)):
    """Armoire électrique face au sud : caisson, porte, voyants et feu de travail sur le toit."""
    caisson(lot, M["acier2"], x, y, z0, sx, sy, sz, 0.02)
    yf = y - sy / 2 - 0.006
    lot.put(M["acier"], G.boite((x, yf, z0 + sz * 0.5), (sx * 0.86, 0.012, sz * 0.8)))
    for k in range(3):
        lot.put(M["voyant" if k != 1 else "voyant_v"], G.boite((x - sx * 0.25 + k * sx * 0.12, yf - 0.008, z0 + sz * 0.78),
                                                               (0.035, 0.012, 0.035)))
    lot.put(M["noir"], G.boite((x + sx * 0.2, yf - 0.008, z0 + sz * 0.6), (0.03, 0.012, 0.09)))
    if lampe:
        rev(lot, M["fonte"], x + sx * 0.25, y, [(z0 + sz, 0.05), (z0 + sz + 0.03, 0.05)], 12)
        lot.put(M["lampe"], G.sphere((x + sx * 0.25, y, z0 + sz + 0.075), 0.05, 12, 6))
        for t in range(4):
            a = TAU * t / 4
            lot.put(M["fonte"], G.tube([(x + sx * 0.25 + 0.052 * math.cos(a), y + 0.052 * math.sin(a), z0 + sz + 0.03),
                                        (x + sx * 0.25 + 0.052 * math.cos(a), y + 0.052 * math.sin(a), z0 + sz + 0.12)], 0.006, 3))


def tas(lot, m, c, rx, ry, h, rnd, n=40, rmin=0.025, rmax=0.05):
    """Tas de morceaux (charbon, coke, minerai) en cône bosselé."""
    for _ in range(n):
        a, d = rnd.f(0.0, TAU), rnd.f(0.0, 1.0) ** 0.7
        p = (c[0] + d * rx * math.cos(a), c[1] + d * ry * math.sin(a), c[2] + (1.0 - d) * h + rnd.f(0.0, 0.015))
        lot.put(m, G.sphere(p, rnd.f(rmin, rmax), 5, 2))


def chevrons(lot, M, x0, x1, y, z, e=0.06):
    """Bande de sécurité jaune et noire au sol."""
    lot.put(M["chevron"], G.boite(((x0 + x1) / 2, y, z + 0.004), (x1 - x0, e, 0.008)))


def ru(lot, m, pts, l, h, z0=None):
    """Rigole (auge en U) le long d'une polyligne au sol : deux joues et un fond ; renvoie le centre des points."""
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        d = G.norm(G.sub(b, a))
        s = (-d[1], d[0], 0.0)
        for k in (-1, 1):
            o = G.mul(s, k * l / 2)
            lot.put(m, G.tube([G.add(a, o), G.add(b, o)], h / 2, 6))
