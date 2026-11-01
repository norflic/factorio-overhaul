"""QG ÂGE 2 : FORGE (ère I, emprise 8×4). NEZ À DROITE (+X). La cassure de l'épave est bouchée par de l'acier.

Bible (DESIGN_EPOQUES §5, époque 2) : « Bastion d'acier : bloc carré à 2 étages en plaques boulonnées, cerclé ; porte blindée
centrale ; 2 échauguettes trapues aux coins avant ; mât en treillis d'acier » ; acier #5C6168, cerclage #2E2C2A, rivets en
laiton #8C7440, luminance 52 ; cubes cerclés, boucliers plats, créneaux, volant d'inertie, soufflet ; 1 à 2 événements.

Histoire : les tronçons, redressés, sont cerclés de feuillards et tiennent sur des jambes d'acier ; le bastion remplit la
brèche. Le cœur sert de foyer à la forge, dans une niche du mur sud, sous sa hotte, soufflé par un soufflet de bois et de
cuir ; le volant d'inertie entraîne le soufflet par une courroie. La lumière vient du cœur et de fentes toutes différentes.
"""
import math

import ere1 as R
import forme as F
import geo as G
import mat as MT
import qg00 as Q

TAU = G.TAU
B = dict(cx=-0.12, cy=-0.95, rz=-0.2)
COUR = dict(cx=-0.12, cy=-0.72, rz=-0.2)      # la cour reste où elle était : le bloc a reculé, pas elle
HX, HY = 1.05, 0.8          # rez-de-chaussée
UX, UY = 0.88, 0.64           # étage (en retrait)
Z0, Z1, Z2, Z3 = 0.2, 1.02, 1.74, 1.94     # dalle, plancher, haut d'étage, haut du parapet
E = dict(roul_ar=-0.2, tang_ar=0.07, lacet_ar=0.17, t_ar=(-0.46, 0.34, 0.96), roul_av=0.28, tang_av=0.09, lacet_av=-0.09, t_av=(0.42, 0.14, 1.02),
         aile_pli=0.82, cant=0.16, trou_dos=False, aile_casse=False, derive_casse=False, tuyau_ar="acier", hublot_av="fente", hublot_ar="fente", bosse="j2")


def matieres(S):
    M = Q.matieres(S)
    cr = (0.01, 0.008, 0.006)
    sf = MT.surface
    for i, c in enumerate(((0.2, 0.22, 0.25), (0.11, 0.122, 0.142), (0.42, 0.43, 0.45), (0.16, 0.15, 0.14))):
        M["pl%d" % i] = sf("q2_pl%d" % i, c, rough=0.5, met=0.35, grain=0.2, coulures=0.9, rouille=(0.16, 0.065, 0.022), usure=1.0, nu=(0.95, 0.95, 0.93), crasse=0.72,
                           crasse_col=cr, pied=(0.0, 0.5, 0.4), graine=61 + i)
    M["rou"] = sf("q2_rou", (0.3, 0.105, 0.03), rough=0.85, met=0.05, grain=0.3, coulures=0.9, rouille=(0.09, 0.035, 0.012), usure=0.8, nu=(0.62, 0.45, 0.3), crasse=0.75, crasse_col=cr, graine=74)
    M["rou2"] = sf("q2_rou2", (0.17, 0.07, 0.028), rough=0.85, met=0.05, grain=0.3, coulures=0.9, usure=0.8, nu=(0.55, 0.42, 0.3), crasse=0.75, crasse_col=cr, graine=75)
    M["cercle"] = sf("q2_cercle", (0.027, 0.025, 0.023), rough=0.5, met=0.75, grain=0.12, usure=0.85, nu=(0.34, 0.33, 0.31), crasse=0.5, crasse_col=cr, coulures=0.4, graine=65)
    M["laiton"] = sf("q2_laiton", (0.5, 0.34, 0.1), rough=0.42, met=0.85, usure=0.3, crasse=0.35, crasse_col=cr, graine=66)
    M["brique"] = sf("q2_brique", (0.17, 0.062, 0.034), rough=0.88, met=0.0, tole=(0.25, 0.09), joint=0.28, joint_l=0.012, var=0.22, grain=0.18, coulures=0.5, rouille=(0.02, 0.018, 0.016),
                     usure=0.5, nu=(0.3, 0.17, 0.12), crasse=0.9, crasse_col=cr, relief=0.6, graine=67)
    M["bois"] = sf("q2_bois", (0.15, 0.095, 0.05), rough=0.82, met=0.0, tole=(0.8, 0.12), joint=0.3, var=0.2, grain=0.3, usure=0.6, nu=(0.34, 0.26, 0.17), crasse=0.8, crasse_col=cr, graine=68)
    M["cuir"] = sf("q2_cuir", (0.1, 0.05, 0.022), rough=0.6, met=0.0, grain=0.25, usure=0.5, nu=(0.25, 0.15, 0.08), crasse=0.85, crasse_col=cr, graine=69)
    M["charbon"] = sf("q2_charbon", (0.012, 0.012, 0.013), rough=0.5, met=0.2, grain=0.5, usure=0.5, nu=(0.09, 0.09, 0.095), crasse=0.4, crasse_col=cr, graine=70)
    M["lingot"] = sf("q2_lingot", (0.16, 0.165, 0.17), rough=0.4, met=0.85, grain=0.15, usure=0.7, nu=(0.55, 0.56, 0.58), crasse=0.8, crasse_col=cr, graine=71)
    M["pierre"] = sf("q2_pierre", (0.09, 0.08, 0.07), rough=0.9, met=0.0, tole=(0.42, 0.2), joint=0.35, var=0.2, usure=0.6, nu=(0.2, 0.18, 0.16), crasse=0.85, crasse_col=cr, relief=0.6, graine=72)
    M["braise"] = S.mat_emissive("q2_braise", (1.0, 0.2, 0.02), strength=0.8, base=(0.04, 0.012, 0.003), main_scale=0.14, crust=(9.0, 0.6, 4.0))
    M["fente"] = MT.lumiere(S, "q2_fente", (1.0, 0.29, 0.05), 3.2, main=0.3)
    M["int"] = sf("q2_int", (0.006, 0.0055, 0.005), rough=0.8, met=0.3, usure=0.0, crasse=0.9, graine=73)
    return M


def choix_factory(M):
    def choix(rr, x, t, patch, ou):
        u = rr.f()
        if ou == "av" and x > 2.88:
            return M["chevron"]
        if patch:
            return [M["pl0"], M["pl1"], M["cercle"], M["pl3"]][int(rr.f(0, 3.99))]
        pres = (ou == "ar" and x > -2.2) or (ou == "av" and x < 1.5)
        if (pres and t > 5.0 and u < 0.5) or (u < 0.1):
            return [M["pl0"], M["rou"], M["pl2"], M["rou2"]][int(rr.f(0, 3.99))]
        if u < 0.62:
            return M["j0"]
        return M["j2"] if u < 0.92 else M["j3"]
    return choix


def cerclage(lot, M, C, x, ta, tb, w, r):
    """Feuillard qui enserre la coque, sombre, rivets de laiton."""
    mesh, P = F.plaque(C, x, x + w, ta, tb, 0.0, 0.082, (r.f(-0.02, 0.02), r.f(-0.02, 0.02)))
    lot.put(M["cercle"], mesh)
    n = int((tb - ta) * 3.3)
    for k in range(n):
        ft = (k + 0.5) / n
        for fx in (0.2, 0.8):
            p = P(fx, ft, 0.085)
            q = P(fx, ft, 0.14)
            lot.put(M["laiton"], G.sphere(p, 0.017, 6, 3))
            del q


def bouclier(lot, M, C, x0, x1, ta, tb, r, m="pl0"):
    """Bouclier plat boulonné sur le flanc : grande plaque à arêtes vives, rivets de laiton sur le pourtour."""
    mesh, P = F.plaque(C, x0, x1, ta, tb, 0.0, 0.1, (r.f(-0.12, 0.12), r.f(-0.12, 0.12)))
    lot.put(M[m], mesh)
    for fx, n, ax in ((0.08, 5, "t"), (0.92, 5, "t"), (0.08, 6, "x"), (0.92, 6, "x")):
        for k in range(n):
            f = (k + 0.5) / n
            p = P(fx, f, 0.103) if ax == "t" else P(f, fx, 0.103)
            lot.put(M["laiton"], G.sphere(p, 0.02, 6, 3))


def jambe(lot, M, p):
    """Jambe d'acier de la coque (l'âge 8 en hérite) : poteau, chapiteau, semelle de pierre, rivets."""
    h = p[2]
    lot.put(M["pl1"], G.boite((p[0], p[1], h / 2), (0.14, 0.16, h)))
    lot.put(M["pl0"], G.boite((p[0], p[1], h - 0.12), (0.24, 0.26, 0.1)))
    lot.put(M["pierre"], G.boite((p[0], p[1], 0.15), (0.42, 0.42, 0.3), 0.1))
    lot.put(M["cercle"], G.boite((p[0], p[1], 0.32), (0.26, 0.28, 0.05)))
    lot.put(M["laiton"], G.rivets_le_long([((p[0] + dx, p[1] + dy, 0.345), (0, 0, 1)) for dx in (-0.09, 0.09) for dy in (-0.1, 0.1)], 0.02, 0.014))


def bastion(lot, M, r):
    lot.xf = R.repere(B["cx"], B["cy"], B["rz"])
    pls = [M["pl0"], M["pl2"], M["rou"], M["pl1"], M["pl2"], M["rou2"], M["pl3"], M["pl0"]]
    lv = M["laiton"]
    # -- noyaux sombres (les joints des plaques sont noirs) --
    lot.put(M["int"], G.boite((0.0, 0.0, (Z0 + Z1) / 2), (2 * HX - 0.05, 2 * HY - 0.05, Z1 - Z0)))
    lot.put(M["int"], G.boite((0.0, 0.05, (Z1 + Z2) / 2), (2 * UX - 0.05, 2 * UY - 0.05, Z2 - Z1)))
    # talus du pied : plaques inclinées sur le pourtour sud et est
    lot.put(M["pierre"], G.boite((0.0, 0.0, Z0 / 2), (2 * HX + 0.5, 2 * HY + 0.42, Z0)))
    NIC = (-0.78, 0.42, Z0, 0.92)
    POR = (0.54, 0.92, Z0, 0.8)

    def trou_s(u, v):
        x, z = u - HX, v + Z0
        return (NIC[0] < x < NIC[1] and z < NIC[3]) or (POR[0] < x < POR[1] and z < POR[3])
    rS = (0.0, -1.0, 0.0)
    R.panneau(lot, pls, lv, (-HX, -HY, Z0), (1, 0, 0), (0, 0, 1), rS, 2 * HX, Z1 - Z0, G.Rnd(201), trou=trou_s)
    R.panneau(lot, pls, lv, (HX, -HY, Z0), (0, 1, 0), (0, 0, 1), (1, 0, 0), 2 * HY, Z1 - Z0, G.Rnd(202))
    R.panneau(lot, pls, lv, (-UX, -UY + 0.05, Z1), (1, 0, 0), (0, 0, 1), rS, 2 * UX, Z2 - Z1, G.Rnd(203), lu=(0.34, 0.8), lv=(0.3, 0.62))
    R.panneau(lot, pls, lv, (UX, -UY + 0.05, Z1), (0, 1, 0), (0, 0, 1), (1, 0, 0), 2 * UY, Z2 - Z1, G.Rnd(204), lu=(0.3, 0.6))
    # terrasse du rez : plaques
    R.panneau(lot, [M["pl3"], M["pl1"], M["pl2"], M["pl0"]], lv, (-HX, -HY, Z1), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2 * HX, HY - UY + 0.02, G.Rnd(205), lu=(0.24, 0.5), lv=(0.1, 0.2), riv=0.5)
    # cerclages (feuillards sombres, rivets de laiton, interrompus par la porte et la niche)
    for (xa, xb, y, z, h) in ((-HX, NIC[0], -HY - 0.03, 0.72, 0.09), (NIC[1], POR[0], -HY - 0.03, 0.72, 0.09), (POR[1], HX, -HY - 0.03, 0.72, 0.09), (-HX, HX, -HY - 0.04, Z1 - 0.03, 0.12),
                              (-UX, UX, -UY + 0.02, 1.2, 0.08)):
        lot.put(M["cercle"], G.boite(((xa + xb) / 2, y, z), (xb - xa, 0.05, h)))
        n = max(2, int((xb - xa) / 0.14))
        lot.put(lv, G.rivets_le_long([((xa + (xb - xa) * (k + 0.5) / n, y - 0.026, z), (0, -1, 0)) for k in range(n)], 0.018, 0.012))
    for (x, y, z, h, w) in ((HX + 0.03, -0.1, 0.72, 0.09, 2 * HY), (HX + 0.04, -0.0, Z1 - 0.03, 0.12, 2 * HY + 0.06), (UX + 0.02, 0.05, 1.2, 0.08, 2 * UY)):
        lot.put(M["cercle"], G.boite((x, y, z), (0.05, w, h)))
        n = int(w / 0.15)
        lot.put(lv, G.rivets_le_long([((x + 0.026, y - w / 2 + w * (k + 0.5) / n, z), (1, 0, 0)) for k in range(n)], 0.018, 0.012))
    # montants d'angle en cornières, contreforts obliques (profil non frontal)
    for (x, y) in ((-0.62, -HY), (0.72, -HY)):
        pass
    for x in (-0.93, 0.47):
        for (zb, zt, dd) in ((Z0, 0.68, 0.22),):
            v, f, u = G.prisme([(x - 0.08, -HY - dd), (x + 0.08, -HY - dd), (x + 0.08, -HY), (x - 0.08, -HY)], zb, zt, 1.0)
            v = [(p[0], p[1] + (dd * 0.85 if p[2] > (zb + zt) / 2 and p[1] < -HY - dd / 2 else 0.0), p[2]) for p in v]
            lot.put(M["pl2"], (v, f, u))
    # -- petite porte blindée à l'est de la gueule : piédroits, linteau, vantail à nervures --
    xa, xb = POR[0], POR[1]
    for x in (xa - 0.03, xb + 0.03):
        lot.put(M["pl1"], G.boite((x, -HY - 0.06, (Z0 + POR[3]) / 2), (0.07, 0.14, POR[3] - Z0)))
    lot.put(M["pl2"], G.boite(((xa + xb) / 2, -HY - 0.08, POR[3] + 0.02), (xb - xa + 0.2, 0.2, 0.07)))
    lot.put(lv, G.rivets_le_long([((xa + (xb - xa) * (k + 0.5) / 4, -HY - 0.182, POR[3] + 0.02), (0, -1, 0)) for k in range(4)], 0.018, 0.012))
    lot.put(M["pl0"], G.boite(((xa + xb) / 2, -HY - 0.03, (Z0 + POR[3]) / 2), (xb - xa, 0.05, POR[3] - Z0)))
    for z in (Z0 + 0.12, Z0 + 0.32, Z0 + 0.5):
        lot.put(M["cercle"], G.boite(((xa + xb) / 2, -HY - 0.062, z), (xb - xa - 0.02, 0.02, 0.045)))
        lot.put(lv, G.rivets_le_long([((xa + 0.04, -HY - 0.074, z), (0, -1, 0)), ((xb - 0.04, -HY - 0.074, z), (0, -1, 0))], 0.016, 0.011))
    lot.put(M["cercle"], G.tube([((xa + xb) / 2 + 0.07 * math.cos(TAU * k / 12), -HY - 0.08, 0.5 + 0.07 * math.sin(TAU * k / 12)) for k in range(13)], 0.011, 4))
    for k in range(2):
        lot.put(M["pl1"], G.boite(((xa + xb) / 2, -HY - 0.18 - 0.12 * k, Z0 - 0.04 - k * 0.06), (0.5 + 0.08 * k, 0.13, 0.05)))
    # -- la grande gueule de four, au centre (2 fois la niche d'avant) : briques réfractaires, arc de fer, cœur sur un lit de braises --
    nx0, nx1 = NIC[0], NIC[1]
    xm, wm = (nx0 + nx1) / 2, nx1 - nx0
    zb, zh = 0.3, NIC[3]
    lot.put(M["int"], G.boite((xm, -HY + 0.1, (zb + zh) / 2), (wm, 0.05, zh - zb + 0.1)))
    for (x, w) in ((nx0 - 0.03, 0.14), (nx1 + 0.03, 0.14)):                                 # piédroits de brique, chanfreinés vers le foyer
        lot.put(M["brique"], G.boite((x, -HY - 0.11, (Z0 + zh) / 2), (w, 0.42, zh - Z0)))
        lot.put(M["pl2"], G.boite((x, -HY - 0.33, (Z0 + zh) / 2), (w + 0.04, 0.03, zh - Z0)))
        lot.put(lv, G.rivets_le_long([((x, -HY - 0.35, Z0 + 0.1 + 0.13 * k), (0, -1, 0)) for k in range(5)], 0.018, 0.012))
    lot.put(M["brique"], G.boite((xm, -HY - 0.14, Z0 + 0.055), (wm + 0.1, 0.5, 0.11)))      # sole
    rb = G.Rnd(251)
    for k in range(34):                                                                     # lit de braises, inégal
        x, y = rb.f(nx0 + 0.04, nx1 - 0.04), rb.f(-HY - 0.33, -HY + 0.06)
        lot.put(M["braise"] if rb.f() < 0.4 else M["charbon"], G.sphere((x, y, Z0 + 0.11 + rb.f(0.0, 0.03)), rb.f(0.035, 0.075), 6, 3))
    CO = (xm, -HY - 0.02, 0.62)
    lot.put(M["coeur"], G.sphere(CO, 0.25, 16, 8))
    for (ax_, ang, a0, a1, rr) in (("x", 0.0, 3.3, 7.7, 0.34), ("z", 0.0, 0.3, 4.0, 0.33)):  # sa cage, vue à travers la grille
        pts = []
        for k in range(25):
            t = a0 + (a1 - a0) * k / 24.0
            u_, v_ = rr * math.cos(t), rr * math.sin(t)
            pts.append(G.add(CO, (0.0, u_, v_) if ax_ == "x" else (u_, v_, 0.0)))
        lot.put(M["bague"], G.tube(pts, 0.03, 6))
    # arc de fer au-dessus de la bouche, clé de voûte
    arc = [(xm - (wm / 2 + 0.03) * math.cos(math.pi * k / 14), -HY - 0.3, zh - 0.26 + 0.26 * math.sin(math.pi * k / 14)) for k in range(15)]
    lot.put(M["cercle"], G.tube(arc, 0.042, 6))
    for s_ in (-1, 1):                                                                       # écoinçons : la bouche se lit cintrée
        lot.put(M["pl1"], G.boite((xm + s_ * wm * 0.4, -HY - 0.27, zh - 0.05), (wm * 0.2, 0.05, 0.14)))
    lot.put(M["pl2"], G.boite((xm, -HY - 0.33, zh + 0.03), (0.13, 0.05, 0.13)))
    lot.put(lv, G.rivets_le_long([((xm + wm * (k - 3.5) / 8.0, -HY - 0.325, zh + 0.0), (0, -1, 0)) for k in range(8) if k not in (3, 4)], 0.019, 0.013))
    for k in range(7):                                                                       # grille basse, deux barreaux tordus, le haut reste ouvert
        x = nx0 + 0.08 + (wm - 0.16) * k / 6.0
        mid = (x + (0.03 if k == 2 else 0.0), -HY - 0.38 - (0.05 if k in (2, 5) else 0.0), 0.38)
        lot.put(M["cercle"], G.tube([(x, -HY - 0.34, Z0 + 0.1), mid, (x, -HY - 0.33, 0.5)], 0.014, 5))
    lot.put(M["cercle"], G.tube([(nx0, -HY - 0.35, 0.47), (nx1, -HY - 0.35, 0.47)], 0.012, 4))
    # hotte
    v, f, u = G.prisme([(nx0 - 0.14, -HY - 0.24), (nx1 + 0.14, -HY - 0.24), (nx1 + 0.14, -HY + 0.02), (nx0 - 0.14, -HY + 0.02)], zh + 0.02, zh + 0.32, 0.66, (0.0, 0.12))
    lot.put(M["pl2"], (v, f, u))
    lot.put(M["cercle"], G.boite((xm, -HY - 0.23, zh + 0.03), (wm + 0.32, 0.05, 0.06)))
    Q.lumiere_coeur(R.repere(B["cx"], B["cy"], B["rz"])((CO[0], CO[1] - 0.42, CO[2] + 0.08)), 9.0)
    # -- fentes et bouches : toutes différentes --
    lot.put(M["cercle"], G.boite((-0.42, -UY - 0.0, 1.46), (0.34, 0.05, 0.14)))
    lot.put(M["fente"], G.boite((-0.42, -UY - 0.03, 1.46), (0.28, 0.012, 0.06)))           # fente basse et large
    lot.put(M["cercle"], G.boite((0.46, -UY - 0.0, 1.42), (0.16, 0.05, 0.3)))
    lot.put(M["noir"], G.boite((0.46, -UY - 0.03, 1.42), (0.03, 0.012, 0.22)))
    lot.put(M["noir"], G.boite((0.46, -UY - 0.03, 1.47), (0.1, 0.012, 0.03)))              # archère en croix, éteinte
    lot.put(M["int"], G.boite((UX + 0.03, 0.15, 1.42), (0.02, 0.26, 0.2)))
    lot.put(M["pl2"], G.boite((UX + 0.13, -0.02, 1.42), (0.2, 0.025, 0.24), 0.5))
    # -- mâchicoulis, parapet, merlons d'acier inégaux --
    for (i, x) in enumerate([-UX + 0.1 + (2 * UX - 0.2) * k / 8.0 for k in range(9)]):
        v, f, u = G.prisme([(x - 0.04, -UY), (x + 0.04, -UY), (x + 0.04, -UY + 0.05), (x - 0.04, -UY + 0.05)], Z2 - 0.28, Z2, 1.0, (0.0, -0.06))
        lot.put(M["pl1"], (v, f, u))
    px, py = UX + 0.13, UY + 0.13
    for (cx, cy, sx, sy) in ((0.0, -py + 0.05, 2 * px, 0.12), (px, 0.05, 0.12, 2 * py), (-px, 0.05, 0.12, 2 * py), (0.0, py + 0.05, 2 * px, 0.12)):
        lot.put(M["pl0"], G.boite((cx, cy, (Z2 + Z3) / 2), (sx, sy, Z3 - Z2)))
    R.panneau(lot, pls, lv, (-px, -py - 0.01, Z2 - 0.0), (1, 0, 0), (0, 0, 1), rS, 2 * px, Z3 - Z2, G.Rnd(206), lu=(0.3, 0.55), lv=(0.3, 0.3), riv=0.7)
    x, rm = -px, G.Rnd(207)
    while x < px - 0.05:
        w = rm.f(0.14, 0.26)
        lot.put(M["pl2"] if rm.f() < 0.5 else M["pl0"], G.boite((x + w / 2, -py + 0.04, Z3 + 0.11 + rm.f(-0.01, 0.015)), (w, 0.13, 0.22)))
        lot.put(lv, G.rivets_le_long([((x + w / 2, -py - 0.03, Z3 + 0.14), (0, -1, 0))], 0.017, 0.012))
        x += w + rm.f(0.13, 0.2)
    y = -py + 0.3
    while y < py - 0.05:
        w = rm.f(0.14, 0.24)
        lot.put(M["pl0"] if rm.f() < 0.5 else M["pl1"], G.boite((px, y + w / 2, Z3 + 0.11), (0.13, w, 0.22)))
        lot.put(M["pl1"], G.boite((-px, y + w / 2, Z3 + 0.11), (0.13, w, 0.22)))
        y += w + rm.f(0.14, 0.2)
    # -- terrasse : plaques, écoutille, lanterneau, hotte à charbon, potence de levage --
    R.panneau(lot, [M["pl3"], M["pl1"], M["pl0"]], lv, (-px, -py + 0.1, Z2 + 0.01), (1, 0, 0), (0, 1, 0), (0, 0, 1), 2 * px, 2 * py - 0.1, G.Rnd(208), lu=(0.26, 0.6), lv=(0.2, 0.42), riv=0.45)
    lot.put(M["pl0"], G.boite((0.3, -0.12, Z2 + 0.12), (0.5, 0.42, 0.2)))
    lot.put(M["cercle"], G.boite((0.3, -0.12, Z2 + 0.235), (0.42, 0.34, 0.03)))
    for k in range(4):
        lot.put(M["pl2"], G.boite((0.14 + 0.11 * k, -0.12, Z2 + 0.27), (0.07, 0.34, 0.02), 0.0, 0.0, 0.35))
    v, f, u = G.prisme([(-0.26, -0.62), (0.08, -0.62), (0.08, -0.3), (-0.26, -0.3)], Z2 + 0.01, Z2 + 0.32, 0.72)
    lot.put(M["pl1"], (v, f, u))
    lot.put(M["noir"], G.boite((-0.09, -0.46, Z2 + 0.325), (0.18, 0.16, 0.01)))
    # potence
    pt = (0.72, -0.48, Z2 + 0.01)
    lot.put(M["pl1"], G.boite(G.add(pt, (0, 0, 0.42)), (0.07, 0.07, 0.84)))
    lot.put(M["pl1"], G.boite(G.add(pt, (0.28, -0.18, 0.84)), (0.74, 0.06, 0.08), -0.55))
    lot.put(M["cercle"], G.tube([G.add(pt, (0.56, -0.38, 0.8)), G.add(pt, (0.56, -0.38, 0.28))], 0.008, 3))
    lot.put(M["lingot"], G.boite(G.add(pt, (0.56, -0.38, 0.22)), (0.2, 0.12, 0.1)))
    lot.put(M["pl2"], G.tube([G.add(pt, (0, 0, 0.45)), G.add(pt, (0.35, -0.22, 0.82))], 0.014, 4))
    # chaudron renversé, caisses de la terrasse, tuyau de fumée de la hotte vers la cheminée
    R.caisse(lot, M["bois"], M["bois"], M["cercle"], (-0.66, -0.46, Z2 + 0.01), (0.24, 0.2, 0.18), 0.2)
    F.tuyau(lot, M["pl1"], M["cercle"], [(xm - 0.32, -HY - 0.08, zh + 0.24), (xm - 0.32, -HY - 0.08, 1.34), (xm - 0.32, -UY - 0.03, 1.5), (xm - 0.32, -UY - 0.03, Z2 + 0.2)], 0.075, rb=0.1)
    lot.xf = None


def echauguette(lot, M, r, c, s):
    """Échauguette trapue, en encorbellement sur un coin avant : consoles, plaques, cerclages, fente, toit pyramidal d'acier."""
    x, y = c
    a = 0.27
    zb, zh = 0.82, 2.08
    v, f, u = G.prisme([(x - a * 0.35, y - a * 0.35), (x + a * 0.35, y - a * 0.35), (x + a * 0.35, y + a * 0.35), (x - a * 0.35, y + a * 0.35)], 0.42, zb, 1.0 / 0.35)
    lot.put(M["pl1"], (v, f, u))
    lot.put(M["int"], G.boite((x, y, (zb + zh) / 2), (2 * a - 0.03, 2 * a - 0.03, zh - zb)))
    pls = [M["pl0"], M["pl2"], M["rou"], M["pl1"], M["pl2"]]
    R.panneau(lot, pls, M["laiton"], (x - a, y - a, zb), (1, 0, 0), (0, 0, 1), (0, -1, 0), 2 * a, zh - zb, r, lu=(0.2, 0.38), lv=(0.22, 0.44), doub=0.1)
    R.panneau(lot, pls, M["laiton"], (x + a, y - a, zb), (0, 1, 0), (0, 0, 1), (1, 0, 0), 2 * a, zh - zb, r, lu=(0.2, 0.38), lv=(0.22, 0.44), doub=0.1)
    for (z, h) in ((zb + 0.06, 0.08), (zh - 0.08, 0.1), (1.48 + s * 0.05, 0.07)):
        lot.put(M["cercle"], G.boite((x, y, z), (2 * a + 0.05, 2 * a + 0.05, h)))
        lot.put(M["laiton"], G.rivets_le_long([((x - a + 2 * a * (k + 0.5) / 5, y - a - 0.027, z), (0, -1, 0)) for k in range(5)], 0.016, 0.011))
    lot.put(M["pl2"], G.prisme([(x - a - 0.06, y - a - 0.06), (x + a + 0.06, y - a - 0.06), (x + a + 0.06, y + a + 0.06), (x - a - 0.06, y + a + 0.06)], zh, zh + 0.42, 0.14))
    lot.put(M["cercle"], G.tour([(zh + 0.42, 0.05), (zh + 0.5, 0.035), (zh + 0.56, 0.0)], 8, "z", (x, y, 0.0)))
    if s < 0:
        lot.put(M["fente"], G.boite((x + 0.02, y - a - 0.03, 1.28), (0.08, 0.012, 0.26)))
        lot.put(M["cercle"], G.boite((x + 0.02, y - a - 0.016, 1.28), (0.14, 0.03, 0.32)))
    else:
        lot.put(M["cercle"], G.boite((x - 0.02, y - a - 0.016, 1.26), (0.28, 0.03, 0.12)))
        lot.put(M["noir"], G.boite((x - 0.02, y - a - 0.03, 1.26), (0.2, 0.012, 0.03)))
        lot.put(M["fente"], G.boite((x + a + 0.02, y + 0.05, 1.3), (0.012, 0.05, 0.2)))


def treillis_mat(lot, M, b, z0, h, w):
    """Mât en treillis d'acier (événement de silhouette) : 4 membrures effilées, entretoises en croix, plate-forme, fanal."""
    def coin(k, t):
        ww = w * (1 - t) + w * 0.18 * t
        a = TAU * k / 4 + math.pi / 4
        return (b[0] + ww * math.cos(a), b[1] + ww * math.sin(a), z0 + h * t)
    n = 7
    for k in range(4):
        lot.put(M["pl1"], G.tube([coin(k, 0.0), coin(k, 1.0)], 0.022, 5))
        for i in range(n):
            t0, t1 = i / float(n), (i + 1) / float(n)
            lot.put(M["pl1"], G.tube([coin(k, t1), coin((k + 1) % 4, t1)], 0.011, 4))
            lot.put(M["pl1"], G.tube([coin(k, t0), coin((k + 1) % 4, t1)], 0.009, 3))
            lot.put(M["pl1"], G.tube([coin((k + 1) % 4, t0), coin(k, t1)], 0.009, 3))
    zt = z0 + h
    lot.put(M["pl0"], G.boite((b[0], b[1], zt + 0.01), (0.42, 0.42, 0.03)))
    for (dx, dy) in ((-0.2, -0.2), (0.2, -0.2), (0.2, 0.2), (-0.2, 0.2)):
        lot.put(M["pl1"], G.tube([(b[0] + dx, b[1] + dy, zt), (b[0] + dx, b[1] + dy, zt + 0.2)], 0.008, 3))
    lot.put(M["pl1"], G.tube([(b[0] - 0.2, b[1] - 0.2, zt + 0.2), (b[0] + 0.2, b[1] - 0.2, zt + 0.2), (b[0] + 0.2, b[1] + 0.2, zt + 0.2), (b[0] - 0.2, b[1] + 0.2, zt + 0.2), (b[0] - 0.2, b[1] - 0.2, zt + 0.2)], 0.008, 3))
    lot.put(M["cercle"], G.tour([(zt + 0.03, 0.07), (zt + 0.22, 0.07), (zt + 0.27, 0.0)], 10, "z", (b[0], b[1], 0.0)))
    lot.put(M["fente"], G.boite((b[0], b[1] - 0.075, zt + 0.13), (0.06, 0.01, 0.07)))
    lot.put(M["pl1"], G.tube([(b[0], b[1], zt + 0.27), (b[0], b[1], zt + 0.8)], 0.008, 3))
    lot.put(M["voyant"], G.sphere((b[0], b[1], zt + 0.82), 0.024, 6, 3))


def cheminee_carree(lot, M, r, b, z0, z1):
    """Première cheminée carrée de l'ère : briques cerclées d'acier, légèrement effilée, chapeau de tôle."""
    x, y = b
    a0, a1 = 0.26, 0.2
    poly = [(x - a0, y - a0), (x + a0, y - a0), (x + a0, y + a0), (x - a0, y + a0)]
    lot.put(M["brique"], G.prisme(poly, z0, z1, a1 / a0))
    z = z0 + 0.22
    while z < z1 - 0.1:
        t = (z - z0) / (z1 - z0)
        a = a0 + (a1 - a0) * t + 0.012
        lot.put(M["cercle"], G.boite((x, y, z), (2 * a, 2 * a, 0.05)))
        lot.put(M["laiton"], G.rivets_le_long([((x - a + 2 * a * (k + 0.5) / 4, y - a - 0.004, z), (0, -1, 0)) for k in range(4)], 0.014, 0.01))
        z += r.f(0.28, 0.42)
    lot.put(M["pl2"], G.boite((x, y, z1 + 0.03), (2 * a1 + 0.1, 2 * a1 + 0.1, 0.06)))
    lot.put(M["brule"], G.boite((x, y, z1 + 0.062), (2 * a1 - 0.04, 2 * a1 - 0.04, 0.006)))
    for dx, dy in ((-a1 - 0.03, -a1 - 0.03), (a1 + 0.03, -a1 - 0.03), (a1 + 0.03, a1 + 0.03), (-a1 - 0.03, a1 + 0.03)):
        lot.put(M["cercle"], G.tube([(x + dx, y + dy, z1 + 0.05), (x + dx * 0.4, y + dy * 0.4, z1 + 0.34)], 0.012, 4))
    lot.put(M["pl1"], G.prisme([(x - a1 - 0.05, y - a1 - 0.05), (x + a1 + 0.05, y - a1 - 0.05), (x + a1 + 0.05, y + a1 + 0.05), (x - a1 - 0.05, y + a1 + 0.05)], z1 + 0.32, z1 + 0.46, 0.2))


def forge_cour(lot, M, r):
    """La cour de la forge, dans le repère du bastion : dalle de fonte irrégulière, enclume, soufflet, charbon, lingots, poutres."""
    b = R.repere(COUR["cx"], COUR["cy"], COUR["rz"])
    lot.xf = b
    pls = [M["pl3"], M["pl1"], M["rou2"], M["pl3"]]

    def trou(u, v):
        x, y = u - 2.0, v - 2.16
        return (y < -0.95 + 0.25 * math.sin(x * 3.1)) and abs(x) > 1.35 + 0.3 * math.sin(y * 5.0) or (y > -1.2 and abs(x) > 2.1)
    R.panneau(lot, pls, M["laiton"], (-2.0, -2.16, 0.015), (1, 0, 0), (0, 1, 0), (0, 0, 1), 3.75, 1.0, G.Rnd(221), lu=(0.3, 0.72), lv=(0.2, 0.4), ep=(0.012, 0.03), riv=0.35, trou=trou)
    # enclume sur billot
    ax, ay = -1.42, -1.7
    lot.put(M["bois"], G.tour([(0.0, 0.15), (0.3, 0.14)], 12, "z", (ax, ay, 0.0), cap1=True))
    for z in (0.08, 0.24):
        lot.put(M["cercle"], G.tour([(z - 0.012, 0.155), (z + 0.012, 0.155)], 12, "z", (ax, ay, 0.0)))
    lot.put(M["lingot"], G.prisme([(ax - 0.13, ay - 0.07), (ax + 0.13, ay - 0.07), (ax + 0.13, ay + 0.07), (ax - 0.13, ay + 0.07)], 0.3, 0.42, 0.72))
    v, f, u = G.prisme([(ax - 0.22, ay - 0.075), (ax + 0.1, ay - 0.075), (ax + 0.14, ay), (ax + 0.1, ay + 0.075), (ax - 0.22, ay + 0.075)], 0.42, 0.5)
    lot.put(M["lingot"], ([(p[0] + 0.03, p[1], p[2]) for p in v], f, u))
    lot.put(M["bois"], G.tube([(ax - 0.35, ay + 0.28, 0.02), (ax - 0.14, ay + 0.1, 0.5)], 0.012, 4))         # marteau appuyé
    lot.put(M["cercle"], G.boite((ax - 0.13, ay + 0.09, 0.54), (0.1, 0.06, 0.07), 0.6))
    # soufflet : deux planches, soufflets de cuir plissés, buse vers le cœur
    bx, by = -1.05, -1.96
    lot.xf = lambda p: b(G.add(G.rot_z(p, 0.65), (bx, by, 0.18)))
    for (ang, z, m) in ((0.26, 0.42, "bois"), (-0.02, 0.1, "bois")):
        lot.put(M[m], G.prisme([(-0.34, -0.22), (0.1, -0.22), (0.36, -0.05), (0.36, 0.05), (0.1, 0.22), (-0.34, 0.22)], z, z + 0.035), lambda p, a=ang: b(G.add(G.rot_z(G.rot_y(G.add(p, (0.3, 0, -z)), a), 0.65), (bx - 0.2, by, 0.18 + z))))
    rings = []
    for i in range(9):
        t = i / 8.0
        x = -0.36 + 0.66 * t
        hh = (0.34 * (1 - t) + 0.03 * t)
        off = 0.03 * math.cos(i * math.pi)
        rings.append([(x, s * (0.21 - 0.14 * t + off), z) for (s, z) in ((-1, 0.12), (1, 0.12), (1, 0.12 + hh), (-1, 0.12 + hh))])
    lot.put(M["cuir"], G.loft(rings, closed=True))
    lot.put(M["cercle"], G.tube([(0.3, 0.0, 0.14), (0.46, 0.0, 0.2)], 0.022, 6))
    lot.xf = b
    lot.put(M["bois"], G.boite((bx - 0.2, by - 0.1, 0.09), (0.06, 0.06, 0.18)))
    # courroie de cuir du volant au soufflet ; volant d'inertie : voir volant()
    # charbon, lingots, poutres, cuve de trempe, caisses
    for (c, rx, ry, h) in (((-1.92, -1.3 - 0.1, 0.0), 0.34, 0.3, 0.2), ((-1.6, -1.1, 0.0), 0.24, 0.2, 0.13)):
        pass
    rr = G.Rnd(223)
    lot.put(M["charbon"], F.tertre((1.3, -1.75, 0.02), 0.45, 0.32, 0.22, rr, na=26, nr=7))
    for k in range(26):
        x, y = rr.f(0.9, 1.72), rr.f(-2.02, -1.48)
        lot.put(M["charbon"], G.sphere((x, y, 0.035 + 0.14 * max(0.0, 1 - ((x - 1.3) / 0.45) ** 2 - ((y + 1.75) / 0.32) ** 2)), rr.f(0.03, 0.06), 5, 3))
    for (i, n) in ((0, 3), (1, 2), (2, 1)):
        for j in range(n):
            x = 0.46 + (j + i * 0.5) * 0.17
            lot.put(M["lingot"], G.prisme([(x - 0.075, -1.92), (x + 0.075, -1.92), (x + 0.075, -1.56), (x - 0.075, -1.56)], 0.03 + i * 0.075, 0.1 + i * 0.075, 0.8))
    for (k, (y, z)) in enumerate(((-2.02, 0.05), (-1.92, 0.05), (-1.97, 0.12))):
        lot.put(M["pl1"], G.boite((-0.28 + 0.03 * k, y - 0.25, z), (0.92 + 0.08 * k, 0.07, 0.07), 0.04 - k * 0.03))
    R.tonneau(lot, M["pl3"], M["cercle"], (0.2, -1.58, 0.03), 0.13, 0.22)
    lot.put(M["noir"], G.tour([(0.25, 0.115), (0.255, 0.0)], 12, "z", (0.2, -1.58, 0.0)))
    R.caisse(lot, M["bois"], M["bois"], M["cercle"], (1.92, -1.62, 0.02), (0.34, 0.26, 0.26), -0.2)
    R.caisse(lot, M["bois"], M["bois"], M["cercle"], (1.74, -1.9, 0.02), (0.24, 0.22, 0.2), 0.3)
    R.tonneau(lot, M["pl1"], M["cercle"], (2.1, -1.98, 0.0), 0.1, 0.32, couche=True, rz=0.7)
    R.menus(lot, [M["lingot"], M["cercle"], M["noyau"], M["laiton"]], rr, 60, -1.9, 1.7, -2.15, -1.3, 0.035)
    lot.xf = None


def volant(lot, M, r, c):
    """Volant d'inertie : grande roue à 6 rayons cintrés, jante épaisse, moyeu, paliers sur un socle d'acier, courroie."""
    x, y = c
    R0 = 0.62
    zc = R0 + 0.12
    TAUK = 40
    pose = lambda p: (p[0] + x, p[1] + y, p[2] + zc)
    lot.xf = pose
    for (y0, y1, ra, rb, m) in ((-0.09, 0.09, R0, R0 - 0.1, "pl1"),):
        lot.put(M[m], G.tour([(y0, rb), (y0, ra), (y1, ra), (y1, rb), (y0, rb)], TAUK, "y"))
    lot.put(M["cercle"], G.tour([(-0.1, R0 - 0.02), (-0.1, R0 + 0.008), (0.1, R0 + 0.008), (0.1, R0 - 0.02)], TAUK, "y"))
    for k in range(6):
        a = TAU * k / 6 + 0.2
        pts = [(0.15 * math.cos(a), 0.0, 0.15 * math.sin(a)), (0.33 * math.cos(a + 0.12), 0.0, 0.33 * math.sin(a + 0.12)), ((R0 - 0.08) * math.cos(a + 0.06), 0.0, (R0 - 0.08) * math.sin(a + 0.06))]
        lot.put(M["pl0"], G.tube(G.catmull(pts, 4), 0.036, 6))
    lot.put(M["pl2"], G.tour([(-0.13, 0.0), (-0.13, 0.13), (-0.06, 0.17), (0.06, 0.17), (0.13, 0.13), (0.13, 0.0)], 18, "y"))
    lot.put(M["laiton"], G.tour([(-0.145, 0.0), (-0.145, 0.07), (-0.13, 0.08)], 12, "y"))
    lot.put(M["pl1"], G.tour([(-0.05, 0.05), (0.42, 0.05)], 10, "y"))
    lot.put(M["laiton"], G.rivets_le_long([((0.1 * math.cos(TAU * k / 6), -0.135, 0.1 * math.sin(TAU * k / 6)), (0, -1, 0)) for k in range(6)], 0.014, 0.01))
    lot.xf = None
    # socle : deux paliers, semelle
    lot.put(M["pierre"], G.boite((x, y + 0.08, 0.06), (1.12, 0.62, 0.12), 0.05))
    for yy in (0.2, 0.38):
        lot.put(M["pl1"], G.prisme([(x - 0.2, y + yy - 0.05), (x + 0.2, y + yy - 0.05), (x + 0.2, y + yy + 0.05), (x - 0.2, y + yy + 0.05)], 0.12, zc - 0.03, 0.36))
        lot.put(M["cercle"], G.boite((x, y + yy, zc + 0.01), (0.14, 0.11, 0.09)))
        lot.put(M["laiton"], G.rivets_le_long([((x - 0.05, y + yy - 0.056, zc + 0.02), (0, -1, 0)), ((x + 0.05, y + yy - 0.056, zc + 0.02), (0, -1, 0))], 0.014, 0.01))
    # courroie vers le soufflet et l'arbre du mur
    bb = R.repere(B["cx"], B["cy"], B["rz"])
    p1 = bb((-1.25, -1.88, 0.3))
    lot.put(M["cuir"], G.tube([(x + 0.05, y + 0.02, zc + R0 * 0.85), (p1[0], p1[1], p1[2] + 0.1)], 0.018, 4))
    lot.put(M["cuir"], G.tube([(x + 0.1, y + 0.02, zc - R0 * 0.85), (p1[0], p1[1], p1[2] - 0.1)], 0.018, 4))


def hull_acier(lot, M, r, pose_ar, pose_av, AR, AV):
    """Sur la coque : feuillards, boucliers plats, cornières, regards ; tuyauteries et câbles de bord."""
    lot.xf = pose_ar
    for x in (-2.82, -2.14, -1.5):
        cerclage(lot, M, AR, x, 1.7, 9.0, 0.11, r)
    bouclier(lot, M, AR, -2.75, -2.2, 6.6, 8.1, r, "pl0")
    bouclier(lot, M, AR, -2.08, -1.55, 5.2, 6.4, r, "rou")
    R.coque_menus(lot, M, AR, -3.0, -1.2, 3.5, 8.8, r, 26)
    dents(lot, M, AR, -3.0, -0.3, r, saut=lambda x: -1.75 < x < -0.75)
    lot.xf = pose_av
    dents(lot, M, AV, 0.42, 3.05, r, saut=lambda x: 1.0 < x < 2.35)
    for x in (0.92, 2.42):
        cerclage(lot, M, AV, x, 1.6 if x < 2 else 1.2, 8.7, 0.11, r)
    bouclier(lot, M, AV, 1.08, 1.75, 5.6, 7.1, r, "pl0")
    bouclier(lot, M, AV, 1.42, 1.84, 3.0, 3.95, r, "pl1")                 # la vitre cassée, blindée
    R.coque_menus(lot, M, AV, 2.3, 3.1, 4.5, 8.5, r, 16)
    lot.xf = None


def dents(lot, M, C, x0, x1, r, saut=lambda x: False):
    """Créneaux d'acier dressés sur l'épine (signature de la Forge) : plaques épaisses inégales, rivets de laiton."""
    x = x0
    while x < x1:
        L = r.f(0.13, 0.24)
        if not saut(x):
            o, ex, ey, ez = C.repere(x, 3.5, 0.03)
            h = r.f(0.17, 0.33)
            lot.put(M["pl2"] if r.f() < 0.5 else M["pl0"], F.local(G.boite((0.0, 0.0, h / 2), (L, 0.07, h)), o, ex, ey, ez))
            lot.put(M["laiton"], F.local(G.sphere((0.0, -0.038, h * 0.7), 0.017, 6, 3), o, ex, ey, ez))
        x += L + r.f(0.09, 0.16)


def portique(lot, M, r, a=(1.2, 1.28), b=(3.2, 1.16), za=3.25, zb=2.72):
    """Portique d'acier au nord du crâne (il casse la ligne du dos) : deux chevalets, poutre en treillis, palan, tôle levée."""
    for (c, z) in ((a, za), (b, zb)):
        for (dx, dy) in ((-0.3, 0.2), (0.3, 0.2), (0.0, -0.35)):
            lot.put(M["pl1"], G.tube([(c[0] + dx, c[1] + dy, 0.0), (c[0], c[1], z)], 0.03, 5))
            lot.put(M["pierre"], G.boite((c[0] + dx, c[1] + dy, 0.05), (0.16, 0.16, 0.1)))
        lot.put(M["pl1"], G.tube([(c[0] - 0.14, c[1] + 0.09, z * 0.55), (c[0] + 0.14, c[1] + 0.09, z * 0.55)], 0.014, 4))
    F.treillis(lot, M["pl0"], (a[0] - 0.2, a[1], za), (b[0] + 0.15, b[1], zb), 0.26, 8, 0.016)
    q = G.lerp((a[0], a[1], za), (b[0], b[1], zb), 0.42)
    lot.put(M["cercle"], G.boite(q, (0.16, 0.1, 0.08)))
    lot.put(M["cercle"], G.tube([q, G.add(q, (0, 0, -0.62))], 0.008, 3))
    lot.put(M["pl2"], G.boite(G.add(q, (0, 0, -0.75)), (0.5, 0.035, 0.26), 0.2))
    lot.put(M["laiton"], G.rivets_le_long([(G.add(q, (-0.18 + 0.12 * k, -0.03, -0.68)), (0, -1, 0)) for k in range(4)], 0.016, 0.011))


def mise_en_scene(lot, M, r, pose_ar, pose_av):
    # jambes d'acier sous les tronçons
    for p in (pose_ar((-2.75, -1.0, -0.72)), pose_ar((-1.6, -1.15, -0.7)), pose_av((1.75, -1.0, -0.72)), pose_av((2.7, -0.6, -0.5)), pose_ar((-2.75, 1.25, -0.5)), pose_av((2.2, 1.05, -0.7))):
        jambe(lot, M, p)
    # berceaux des tuyères : cadre d'acier sous le capot
    for (x, y) in ((-2.95, -1.25), (-3.0, 1.1)):
        lot.put(M["pl1"], G.boite((x, y, 0.28), (0.6, 0.1, 0.5)))
        lot.put(M["pl3"], G.boite((x, y - 0.12, 0.06), (0.8, 0.28, 0.1)))
    # conduites de la forge : 3 diamètres, à brides ; le long du mur et vers les tronçons
    bb = R.repere(B["cx"], B["cy"], B["rz"])
    F.tuyau(lot, M["pl1"], M["cercle"], [bb((HX, -0.5, 0.8)), bb((HX + 0.3, -0.5, 0.8)), bb((HX + 0.3, -0.5, 0.35)), (2.35, -1.45, 0.35), (2.5, -1.25, 0.72)], 0.07)
    F.tuyau(lot, M["cuivre"], M["cercle"], [bb((-HX, -0.3, 0.85)), bb((-HX - 0.34, -0.3, 0.85)), pose_ar((-2.0, -1.2, 0.0))], 0.045)
    F.tuyau(lot, M["pl3"], M["cercle"], [bb((HX - 0.06, -HY, 0.3)), bb((HX - 0.06, -HY - 0.17, 0.3)), bb((HX + 0.2, -HY - 0.17, 0.3)), bb((HX + 0.2, -HY - 0.17, 0.12))], 0.035)
    F.flexible(lot, M["gaine"], [pose_av((1.5, -1.05, -0.2)), (1.9, -1.72, 0.28), bb((HX + 0.02, -HY - 0.02, 0.45))], 0.04)
    F.flexible(lot, M["gaine"], [pose_ar((-1.5, -1.1, -0.35)), (-2.05, -1.8, 0.12), bb((-HX - 0.02, -HY + 0.02, 0.3))], 0.045)
    F.flexible(lot, M["gaine"], [bb((HX - 0.1, -HY - 0.02, 0.25)), bb((HX + 0.1, -HY - 0.3, 0.05)), (2.05, -1.72, 0.02), pose_av((2.0, -0.9, -0.55))], 0.035)
    F.faisceau(lot, [M["rouge"], M["noir"], M["noir"]], bb((UX, 0.5, 2.1)), pose_av((0.9, 0.3, 1.0)), 0.25, 0.012, 3, 0.026, r)
    F.faisceau(lot, [M["noir"], M["rouge"], M["noir"]], bb((-UX, 0.4, 2.1)), pose_ar((-1.2, 0.2, 1.05)), 0.22, 0.012, 3, 0.026, r)
    F.faisceau(lot, [M["rouge"], M["noir"]], bb((-HX, -HY, 0.8)), pose_ar((-1.8, -1.28, 0.3)), 0.12, 0.011, 2, 0.024, r)
    # échelle sur le coin est du mur sud
    for (a, b) in ((bb((1.0, -HY - 0.07, Z0)), bb((1.0, -HY - 0.07, Z1 + 0.05))),):
        R.echelle(lot, M["pl1"], a, b, 0.14, 0.14, 0.011, 0.007)


def sol(lot, M, r):
    R.butte_nez(lot, M, r, 0.8)
    lot.xf = F.pose(zmin=0.002)
    lot.put(M["terre2"], F.tertre((-1.9, 2.0, 0.0), 2.0, 0.3, 0.1, r, na=34, nr=9))
    lot.xf = None
    R.cailloux(lot, M, r, 16, -4.3, 4.5, -3.0, 2.4, sauf=lambda x, y: abs(y) < 2.3 and abs(x) < 3.0)
    R.toles_sol(lot, M, r, (((3.5, -1.95), 0.3, "pl0", 0.5), ((-3.75, -2.25), 0.3, "pl1", 0.0), ((-3.45, 2.2), 0.34, "j0", 0.0), ((2.0, 1.95), 0.36, "pl3", 0.4), ((3.05, 2.2), 0.24, "j3", 0.0), ((3.2, -2.35), 0.24, "pl2", 0.0)))
    rr = G.Rnd(233)
    R.menus(lot, [M["pl1"], M["cercle"], M["noyau"], M["lingot"]], rr, 40, -4.3, 4.6, -3.0, 2.5, 0.0)
    for (x, y) in ((-3.4, -3.0), (2.7, -2.55), (3.3, -2.05)):             # scories
        lot.put(M["charbon"], G.butte_polaire((x, y, 0.0), 0.2, 0.15, 0.06, rr, 3, 16, 0.3, 0.2))


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(2230)
    ra = G.Rnd(2231)
    E["choix"] = choix_factory(M)
    pose_ar, pose_av, AR, AV = R.carcasse(lot, M, r, ra, E)
    hull_acier(lot, M, G.Rnd(2232), pose_ar, pose_av, AR, AV)
    bastion(lot, M, G.Rnd(2233))
    bb = R.repere(B["cx"], B["cy"], B["rz"])
    lot.xf = bb
    echauguette(lot, M, G.Rnd(2234), (-HX - 0.04, -HY - 0.02), -1)
    echauguette(lot, M, G.Rnd(2235), (HX + 0.04, -HY - 0.02), 1)
    cheminee_carree(lot, M, G.Rnd(2236), (-0.5, 0.3), Z2, 3.3)
    lot.xf = None
    treillis_mat(lot, M, pose_av((1.05, 0.0, 0.0))[:2], 1.55, 2.5, 0.28)
    portique(lot, M, G.Rnd(2241))
    forge_cour(lot, M, G.Rnd(2237))
    volant(lot, M, G.Rnd(2238), (-2.62, -2.42))
    mise_en_scene(lot, M, G.Rnd(2239), pose_ar, pose_av)
    sol(lot, M, G.Rnd(2240))
    return {"pose": {k: v for k, v in E.items() if k != "choix"}}
