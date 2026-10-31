"""QG ÂGE 3 : VAPEUR (ère I, emprise 8×4). NEZ À DROITE (+X). Le vaisseau presque redressé porte l'hôtel de la vapeur.

Bible (DESIGN_EPOQUES §5, époque 3) : « Hôtel de la vapeur : bâtiment à 2 étages en brique bardée de cuivre ; 2 hautes
cheminées rondes à l'arrière ; grand cadran-manomètre en façade ; tuyauterie extérieure ; mât » ; cuivre #8A5A3A, laiton
#9C7E45, fonte #3A3634, luminance 58 ; première lueur visible de jour : hublots et cadrans ambrés #FFC060 ; 2 événements.

Histoire : ce qu'a posé l'âge 2 reste (feuillards, boucliers, jambes, mât, volant) ; le bastion devient hôtel. Le cœur chauffe
une grosse chaudière rivetée couchée à l'est, foyer ouvert ; la vapeur monte à l'hôtel par des tuyaux de cuivre, fait tourner
le volant par un cylindre et un régulateur à boules à l'ouest ; le charbon arrive en wagonnet sur des rails ; un réservoir sur
trépied (ancêtre du gazomètre de l'âge 8) domine le crâne au nord-est.
"""
import math

import ere1 as R
import forme as F
import geo as G
import mat as MT
import qg00 as Q
import qg02 as Q2

TAU = G.TAU
H = dict(cx=-0.14, cy=-0.66, rz=-0.21)
HX, HY = 1.24, 0.95
UX, UY = 1.12, 0.84
Z0, Z1, Z2, Z3 = 0.2, 1.14, 1.92, 2.48
E = dict(roul_ar=-0.07, tang_ar=0.05, lacet_ar=0.09, t_ar=(-0.42, 0.34, 1.04), roul_av=0.21, tang_av=0.075, lacet_av=-0.085, t_av=(0.4, 0.15, 1.06),
         aile_pli=0.85, cant=0.25, trou_dos=False, aile_casse=False, derive_casse=False, tuyau_ar="cu0", hublot_av="ambre", hublot_ar="ambre", bosse="cu1", vitre_cassee=False)


def matieres(S):
    M = Q.matieres(S)
    cr = (0.011, 0.008, 0.005)
    sf = MT.surface
    for i, c in enumerate(((0.3, 0.125, 0.052), (0.2, 0.082, 0.036), (0.42, 0.19, 0.075), (0.15, 0.075, 0.04))):
        M["cu%d" % i] = sf("q3_cu%d" % i, c, rough=0.45, met=0.55, grain=0.18, coulures=0.85, rouille=(0.05, 0.14, 0.095), usure=0.7, nu=(0.8, 0.5, 0.28), crasse=0.75,
                           crasse_col=cr, pied=(0.0, 0.5, 0.6), graine=121 + i)
    for i, c in enumerate(((0.12, 0.11, 0.104), (0.08, 0.074, 0.068), (0.18, 0.175, 0.168), (0.095, 0.082, 0.072))):
        M["pl%d" % i] = sf("q3_pl%d" % i, c, rough=0.5, met=0.35, grain=0.18, coulures=0.85, rouille=(0.14, 0.06, 0.02), usure=0.8, nu=(0.55, 0.53, 0.5), crasse=0.75,
                           crasse_col=cr, pied=(0.0, 0.5, 0.6), graine=125 + i)
    M["cercle"] = sf("q3_cercle", (0.03, 0.027, 0.024), rough=0.5, met=0.75, grain=0.12, usure=0.85, nu=(0.34, 0.32, 0.29), crasse=0.5, crasse_col=cr, coulures=0.4, graine=129)
    M["laiton"] = sf("q3_laiton", (0.42, 0.27, 0.075), rough=0.36, met=0.88, usure=0.3, nu=(0.75, 0.6, 0.3), crasse=0.4, crasse_col=cr, graine=130)
    M["brique"] = sf("q3_brique", (0.2, 0.07, 0.038), rough=0.88, met=0.0, tole=(0.21, 0.075), joint=0.32, joint_l=0.011, var=0.24, grain=0.18, coulures=0.5, rouille=(0.02, 0.018, 0.016),
                     usure=0.45, nu=(0.34, 0.2, 0.14), crasse=0.9, crasse_col=cr, relief=0.6, graine=131)
    M["pave"] = sf("q3_pave", (0.095, 0.08, 0.066), rough=0.85, met=0.0, tole=(0.2, 0.13), joint=0.32, joint_l=0.012, var=0.28, grain=0.2, usure=0.4, nu=(0.2, 0.17, 0.14), crasse=0.8, crasse_col=cr, relief=0.8, graine=132)
    M["pierre"] = sf("q3_pierre", (0.17, 0.15, 0.125), rough=0.88, met=0.0, grain=0.2, usure=0.5, nu=(0.3, 0.27, 0.23), crasse=0.85, crasse_col=cr, coulures=0.5, rouille=(0.03, 0.03, 0.025), graine=133)
    M["ardoise"] = sf("q3_ardoise", (0.05, 0.045, 0.048), rough=0.6, met=0.2, tole=(0.13, 0.085), joint=0.5, joint_l=0.009, var=0.32, grain=0.2, usure=0.5, nu=(0.16, 0.15, 0.15), crasse=0.8, crasse_col=cr, relief=0.6, graine=134)
    M["bois"] = sf("q3_bois", (0.14, 0.085, 0.045), rough=0.82, met=0.0, tole=(0.8, 0.12), joint=0.3, var=0.2, grain=0.3, usure=0.6, nu=(0.34, 0.26, 0.17), crasse=0.8, crasse_col=cr, graine=135)
    M["cuir"] = sf("q3_cuir", (0.08, 0.04, 0.018), rough=0.6, met=0.0, grain=0.25, usure=0.5, nu=(0.22, 0.13, 0.07), crasse=0.85, crasse_col=cr, graine=136)
    M["charbon"] = sf("q3_charbon", (0.012, 0.012, 0.013), rough=0.5, met=0.2, grain=0.5, usure=0.5, nu=(0.09, 0.09, 0.095), crasse=0.4, crasse_col=cr, graine=137)
    M["lingot"] = M["pl2"]
    M["creme"] = sf("q3_creme", (0.6, 0.53, 0.38), rough=0.6, met=0.0, usure=0.0, crasse=0.3, crasse_col=cr, graine=138)
    M["ambre"] = MT.lumiere(S, "q3_ambre", (1.0, 0.56, 0.13), 3.2, main=0.5)
    M["cadran"] = MT.lumiere(S, "q3_cadran", (1.0, 0.72, 0.3), 1.5, main=0.75)
    M["fente"] = M["ambre"]
    M["int"] = sf("q3_int", (0.006, 0.0055, 0.005), rough=0.8, met=0.3, usure=0.0, crasse=0.9, graine=139)
    return M


def choix_factory(M):
    def choix(rr, x, t, patch, ou):
        u = rr.f()
        if ou == "av" and x > 2.88:
            return M["chevron"]
        if patch:
            return [M["cu0"], M["cu3"], M["laiton"], M["pl3"]][int(rr.f(0, 3.99))]
        pres = (ou == "ar" and x > -2.2) or (ou == "av" and x < 1.6)
        if (pres and u < 0.72) or (ou == "ar" and u < 0.34) or (ou == "av" and u < 0.16):
            return [M["cu0"], M["cu1"], M["pl1"], M["cu2"], M["pl0"], M["cu3"]][int(rr.f(0, 5.99))]
        if u < 0.84:
            return M["j0"]
        return M["j2"] if u < 0.93 else M["j1"]
    return choix


# ------------------------------------------------------------------------------------------------ pièces de la vapeur
def manometre(lot, M, mlum, p, n, r, grad=0):
    """Manomètre : boîtier de laiton à lunette, cadran, aiguille, graduations."""
    lot.put(M["laiton"], G.oriente(G.tour([(0.0, r * 1.25), (0.03, r * 1.25), (0.05, r * 1.1), (0.045, r * 0.96)], 20, "z", cap0=True), p, n))
    lot.put(mlum, G.oriente(G.tour([(0.044, r * 0.96), (0.046, 0.0)], 20, "z"), p, n))
    lot.put(M["noir"], G.oriente(G.boite((r * 0.28, r * 0.18, 0.052), (r * 0.7, 0.018, 0.01), rz=0.65), p, n))
    for i in range(grad):
        a = -math.pi * 0.75 + 1.5 * math.pi * i / max(1, grad - 1)
        q = (math.cos(a) * r * 0.8, math.sin(a) * r * 0.8, 0.05)
        lot.put(M["noir"], G.oriente(G.boite(q, (r * 0.13, 0.012, 0.008), rz=a), p, n))


def cheminee(lot, M, c, z0, z1, r, rnd):
    """Haute cheminée ronde de cuivre (signature) : plinthe de fonte, fût conique, bagues de laiton irrégulières et rivets,
    collerette évasée, gueule noire, suie sous la collerette."""
    x, y = c
    lot.put(M["pl1"], G.tour([(z0, r * 1.5), (z0 + 0.25, r * 1.5), (z0 + 0.33, r * 1.22), (z0 + 0.35, r * 1.08)], 20, "z", (x, y, 0.0), cap0=True))
    lot.put(M["cu0"], G.tour([(z0 + 0.33, r * 1.08), (z1 - 0.2, r * 0.92)], 20, "z", (x, y, 0.0)))
    zz = z0 + 0.5
    while zz < z1 - 0.3:
        rr = r * (1.08 - 0.16 * (zz - z0) / (z1 - z0)) + 0.012
        lot.put(M["laiton"] if rnd.f() < 0.6 else M["pl1"], G.tour([(zz - 0.022, rr), (zz + 0.022, rr)], 20, "z", (x, y, 0.0)))
        pts = [((x + rr * math.cos(a), y + rr * math.sin(a), zz + 0.05), (math.cos(a), math.sin(a), 0.0)) for a in [TAU * j / 9 for j in range(9)]]
        lot.put(M["pl3"], G.rivets_le_long(pts, 0.012, 0.008))
        zz += rnd.f(0.26, 0.44)
    lot.put(M["laiton"], G.tour([(z1 - 0.22, r * 0.92), (z1 - 0.08, r * 1.15), (z1, r * 1.48), (z1 + 0.05, r * 1.48), (z1 + 0.03, r * 1.1), (z1 - 0.05, r * 0.8)], 20, "z", (x, y, 0.0)))
    lot.put(M["brule"], G.tour([(z1 - 0.05, r * 0.8), (z1 - 0.4, 0.0)], 16, "z", (x, y, 0.0)))
    lot.put(M["brule"], G.tour([(z1 - 0.62, r * 0.96), (z1 - 0.22, r * 0.935)], 20, "z", (x, y, 0.0)))


def fenetre_arc(lot, mcad, mvitre, mmen, x, y, z0, w, h):
    """Fenêtre cintrée dans un mur face au sud : vitre, arc, clé, appui, meneaux."""
    r = w / 2.0
    zc = z0 + h - r
    pts = [(x - r, y, z0)] + [(x - r * math.cos(math.pi * i / 10), y, zc + r * math.sin(math.pi * i / 10)) for i in range(11)] + [(x + r, y, z0)]
    lot.put(mvitre, (pts, [tuple(range(len(pts)))[::-1]], [(p[0], p[2]) for p in pts]))
    arc = [(x - (r + 0.03) * math.cos(math.pi * i / 12), y - 0.02, zc + (r + 0.03) * math.sin(math.pi * i / 12)) for i in range(13)]
    lot.put(mcad, G.tube([(x - r - 0.03, y - 0.02, z0 - 0.02)] + arc + [(x + r + 0.03, y - 0.02, z0 - 0.02)], 0.03, 6))
    lot.put(mcad, G.boite((x, y - 0.05, z0 - 0.03), (w + 0.12, 0.1, 0.04)))
    lot.put(mcad, G.boite((x, y - 0.03, zc + r + 0.05), (0.07, 0.06, 0.1)))
    if mmen is not None:
        lot.put(mmen, G.boite((x, y - 0.012, (z0 + zc + r) / 2), (0.022, 0.02, h)))
        lot.put(mmen, G.boite((x, y - 0.012, z0 + h * 0.4), (w, 0.02, 0.018)))


def hotel(lot, M, r):
    b = R.repere(H["cx"], H["cy"], H["rz"])
    lot.xf = b
    lv = M["laiton"]
    cus = [M["cu0"], M["cu0"], M["cu1"], M["cu2"], M["cu3"]]
    # dalle de pierre, noyau
    lot.put(M["pierre"], G.boite((0.0, 0.0, Z0 / 2), (2 * HX + 0.36, 2 * HY + 0.34, Z0)))
    for (cx, cy, sx, sy) in ((0.0, -HY + 0.03, 2 * HX, 0.06), (HX - 0.03, 0.0, 0.06, 2 * HY), (-HX + 0.03, 0.0, 0.06, 2 * HY), (0.0, HY - 0.03, 2 * HX, 0.06)):
        lot.put(M["brique"], G.boite((cx, cy, (Z0 + Z1) / 2), (sx, sy, Z1 - Z0)))
    lot.put(M["int"], G.boite((0.0, 0.0, (Z0 + Z1) / 2), (2 * HX - 0.1, 2 * HY - 0.1, Z1 - Z0 - 0.02)))
    # chaînages de pierre aux angles, inégaux ; bandeau de fonte au plancher ; soubassement
    rq = G.Rnd(301)
    z = Z0 + 0.02
    while z < Z1 - 0.05:
        h = rq.f(0.1, 0.17)
        for (x, y, wx, wy) in ((-HX, -HY - 0.008, rq.f(0.16, 0.26), 0.03), (HX - 0.0, -HY - 0.008, rq.f(0.16, 0.26), 0.03), (HX + 0.008, -HY + 0.02, 0.03, rq.f(0.16, 0.26))):
            lot.put(M["pierre"], G.boite((x + (wx / 2 if x < 0 else -wx / 2 if wy < 0.1 else 0.0), y + (wy / 2 if wy > 0.1 else 0.0), z + h / 2), (wx, wy, h - 0.014)))
        z += h
    for (xa, xb, y, zz, h, m) in ((-HX - 0.02, HX + 0.02, -HY - 0.03, Z1 - 0.02, 0.1, "cercle"), (-HX - 0.03, HX + 0.03, -HY - 0.02, Z0 + 0.09, 0.2, "pierre")):
        lot.put(M[m], G.boite(((xa + xb) / 2, y, zz), (xb - xa, 0.06, h)))
    lot.put(M["cercle"], G.boite((HX + 0.03, 0.0, Z1 - 0.02), (0.06, 2 * HY, 0.1)))
    lot.put(lv, G.rivets_le_long([((-HX + 2 * HX * (k + 0.5) / 24, -HY - 0.062, Z1 - 0.02), (0, -1, 0)) for k in range(24)], 0.014, 0.01))
    # étage bardé de cuivre, irrégulier ; bandeau de laiton sous le toit
    lot.put(M["int"], G.boite((0.0, 0.04, (Z1 + Z2) / 2), (2 * UX - 0.03, 2 * UY - 0.03, Z2 - Z1)))
    DOOR = (-0.42, 0.44)

    def trou_u(u, v):
        x, z_ = u - UX, v + Z1
        return (-0.42 < x < 0.42)
    R.panneau(lot, cus, lv, (-UX, -UY + 0.04, Z1), (1, 0, 0), (0, 0, 1), (0, -1, 0), 2 * UX, Z2 - Z1, G.Rnd(302), lu=(0.22, 0.54), lv=(0.2, 0.42), trou=trou_u, ep=(0.012, 0.03))
    R.panneau(lot, cus, lv, (UX, -UY + 0.04, Z1), (0, 1, 0), (0, 0, 1), (1, 0, 0), 2 * UY, Z2 - Z1, G.Rnd(303), lu=(0.22, 0.5), lv=(0.2, 0.42), ep=(0.012, 0.03))
    for (x, y, sx, sy) in ((0.0, -UY + 0.015, 2 * UX + 0.06, 0.05), (UX + 0.02, 0.04, 0.05, 2 * UY + 0.06)):
        lot.put(lv, G.boite((x, y, Z2 - 0.03), (sx, sy, 0.06)))
    # terrasse devant l'étage, garde-corps
    lot.put(M["pl3"], G.boite((0.0, -HY + 0.0, Z1 + 0.04), (2 * HX + 0.06, 0.24, 0.03)))
    for (xa, xb) in ((-HX, DOOR[0] - 0.02), (DOOR[1] + 0.02, HX)):
        y = -HY - 0.1
        lot.put(M["pl1"], G.tube([(xa, y, Z1 + 0.33), (xb, y, Z1 + 0.33)], 0.012, 4))
        lot.put(M["pl1"], G.tube([(xa, y, Z1 + 0.2), (xb, y, Z1 + 0.2)], 0.008, 4))
        n = max(2, int((xb - xa) / 0.2))
        for k in range(n + 1):
            x = xa + (xb - xa) * k / float(n)
            lot.put(M["pl1"], G.tube([(x, y, Z1 + 0.05), (x, y, Z1 + 0.33)], 0.009, 3))
    # -- avant-corps central : brique jusqu'au plancher, cuivre au-dessus, fronton à cadran --
    ax, ay = 0.42, -HY - 0.2
    lot.put(M["brique"], G.boite((0.0, ay + 0.1, (Z0 + Z1) / 2), (2 * ax, 0.22, Z1 - Z0)))
    lot.put(M["cu0"], G.boite((0.0, -UY - 0.06, (Z1 + Z2 + 0.28) / 2), (2 * ax, 0.28, Z2 + 0.28 - Z1)))
    R.panneau(lot, cus, lv, (-ax, -UY - 0.205, Z1), (1, 0, 0), (0, 0, 1), (0, -1, 0), 2 * ax, Z2 + 0.28 - Z1, G.Rnd(304), lu=(0.2, 0.42), lv=(0.2, 0.34), ep=(0.012, 0.024), doub=0.1)
    # fronton : triangle de cuivre, rampants de laiton, épi
    tri = [(-ax - 0.06, -UY - 0.21, Z2 + 0.28), (ax + 0.06, -UY - 0.21, Z2 + 0.28), (0.0, -UY - 0.21, Z2 + 0.62)]
    lot.put(M["cu2"], G.merge((tri, [(0, 1, 2)], [(p[0], p[2]) for p in tri]), ([G.add(p, (0, 0.25, 0)) for p in tri], [(0, 2, 1)], [(p[0], p[2]) for p in tri])))
    for s in (-1, 1):
        q = [(s * (ax + 0.1), -UY - 0.235, Z2 + 0.26), (0.0, -UY - 0.235, Z2 + 0.66), (0.0, -UY + 0.08, Z2 + 0.66), (s * (ax + 0.1), -UY + 0.08, Z2 + 0.26)]
        top = [G.add(p, (0, 0, 0.03)) for p in q]
        lot.put(M["cu1"], G.loft([q, top], closed=True))
        lot.put(M["cu1"], (top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]))
        lot.put(lv, G.tube([q[0], q[1]], 0.016, 5))
    lot.put(lv, G.tour([(Z2 + 0.66, 0.03), (Z2 + 0.76, 0.02), (Z2 + 0.92, 0.0)], 8, "z", (0.0, -UY - 0.1, 0.0)))
    # grand cadran-manomètre (en façade, lumineux)
    pc = (0.0, -UY - 0.22, Z2 - 0.08)
    manometre(lot, M, M["cadran"], pc, (0.0, -1.0, 0.0), 0.24, 11)
    # porte cintrée à double battant, marches, lampe
    lot.put(M["int"], G.boite((0.0, ay - 0.004, Z0 + 0.36), (0.42, 0.02, 0.72)))
    lot.put(M["bois"], G.boite((-0.1, ay - 0.014, Z0 + 0.3), (0.185, 0.02, 0.6)))
    lot.put(M["bois"], G.boite((0.1, ay - 0.014, Z0 + 0.3), (0.185, 0.02, 0.6)))
    for z_ in (Z0 + 0.1, Z0 + 0.45):
        lot.put(lv, G.boite((0.0, ay - 0.026, z_), (0.4, 0.008, 0.02)))
    fenetre_arc(lot, M["pierre"], M["ambre"], M["cercle"], 0.0, ay - 0.008, Z0 + 0.61, 0.42, 0.26)
    for k in range(3):
        lot.put(M["pierre"], G.boite((0.0, ay - 0.1 - 0.12 * k, Z0 - 0.03 - k * 0.055), (0.86 + 0.1 * k, 0.13, 0.05)))
    # fenêtres : aucune identique (cintrée large, cintrée étroite, œil-de-bœuf, sombres) ; volets
    fenetre_arc(lot, M["pierre"], M["ambre"], M["cercle"], -0.82, -HY - 0.006, Z0 + 0.22, 0.34, 0.54)
    fenetre_arc(lot, M["pierre"], M["verre"], M["cercle"], 0.72, -HY - 0.006, Z0 + 0.25, 0.2, 0.48)
    Q2.Q  # noqa : le module reste importé pour ses pièces
    lot.put(lv, G.oriente(G.tour([(0.0, 0.11), (0.03, 0.105), (0.035, 0.08), (0.012, 0.075)], 16, "z"), (1.04, -HY - 0.012, Z0 + 0.54), (0, -1, 0)))
    lot.put(M["ambre"], G.oriente(G.tour([(0.014, 0.078), (0.014, 0.0)], 16, "z"), (1.04, -HY - 0.012, Z0 + 0.54), (0, -1, 0)))
    fenetre_arc(lot, M["pierre"], M["verre"], lv, -0.78, -UY + 0.015, Z1 + 0.14, 0.26, 0.46)
    fenetre_arc(lot, M["pierre"], M["int"], M["cercle"], 0.75, -UY + 0.015, Z1 + 0.14, 0.3, 0.42)
    lot.put(M["bois"], G.boite((0.54, -UY - 0.015, Z1 + 0.33), (0.1, 0.02, 0.42), 0.0, 0.0, 0.0))
    # façade est : une seule fenêtre et un tuyau de descente (volume en trois-quarts)
    lot.put(M["int"], G.boite((HX + 0.012, -0.32, Z0 + 0.45), (0.012, 0.26, 0.42)))
    lot.put(M["pierre"], G.boite((HX + 0.02, -0.32, Z0 + 0.22), (0.05, 0.34, 0.04)))
    # -- mansarde : brisis d'ardoise à pente raide, terrasson de cuivre, lucarnes différentes --
    rx, ry = UX + 0.08, UY + 0.08
    poly = [(-rx, -ry + 0.04), (rx, -ry + 0.04), (rx, ry + 0.04), (-rx, ry + 0.04)]
    lot.put(M["ardoise"], G.prisme(poly, Z2, Z3, 0.74))
    lot.put(M["cu1"], G.prisme([(-rx * 0.74, -ry * 0.74 + 0.04), (rx * 0.74, -ry * 0.74 + 0.04), (rx * 0.74, ry * 0.74 + 0.04), (-rx * 0.74, ry * 0.74 + 0.04)], Z3, Z3 + 0.12, 0.72))
    for (x, y, sx, sy) in ((0.0, -ry + 0.04, 2 * rx + 0.05, 0.05), (rx, 0.04, 0.05, 2 * ry + 0.05)):
        lot.put(M["cu2"], G.boite((x, y, Z2 + 0.012), (sx, sy, 0.04)))
    lot.put(lv, G.tube([(-rx * 0.74, -ry * 0.74 + 0.04, Z3 + 0.005), (rx * 0.74, -ry * 0.74 + 0.04, Z3 + 0.005), (rx * 0.74, ry * 0.74 + 0.04, Z3 + 0.005)], 0.014, 4))
    # crête de faîtage ajourée (petites pointes inégales)
    zt = Z3 + 0.12
    x = -rx * 0.5
    while x < rx * 0.5:
        lot.put(lv, G.tube([(x, 0.04, zt), (x, 0.04, zt + r.f(0.06, 0.13))], 0.008, 3))
        x += r.f(0.07, 0.13)
    lot.put(M["pl1"], G.tube([(-rx * 0.5, 0.04, zt + 0.06), (rx * 0.5, 0.04, zt + 0.06)], 0.007, 3))
    # lucarnes : à l'ouest cintrée éclairée, à l'est carrée à fronton, plus un évent
    for (x, kind) in ((-0.74, "arc"), (0.72, "carre")):
        y0 = -ry + 0.2
        zb = Z2 + 0.2
        lot.put(M["cu3"], G.boite((x, y0 + 0.14, zb + 0.14), (0.3, 0.3, 0.3)))
        v, f, u = G.prisme([(x - 0.19, y0 - 0.03), (x + 0.19, y0 - 0.03), (x + 0.19, y0 + 0.32), (x - 0.19, y0 + 0.32)], zb + 0.28, zb + 0.42, 0.3)
        lot.put(M["cu1"], (v, f, u))
        if kind == "arc":
            fenetre_arc(lot, lv, M["ambre"], M["cercle"], x, y0 - 0.012, zb + 0.04, 0.17, 0.2)
        else:
            lot.put(M["noir"], G.boite((x, y0 - 0.012, zb + 0.14), (0.16, 0.012, 0.16)))
            for k in range(4):
                lot.put(M["cu2"], G.boite((x, y0 - 0.024, zb + 0.08 + k * 0.04), (0.17, 0.018, 0.02), 0.0, 0.5))
    # -- tuyauterie extérieure de cuivre : 3 diamètres ; le long de la façade, en col de cygne au-dessus du toit --
    lot.xf = b
    F.tuyau(lot, M["cu2"], lv, [(UX + 0.08, -0.7, Z1 + 0.2), (UX + 0.08, -0.7, 2.38), (UX * 0.6, -0.7, 2.58), (0.42, 0.25, 2.72)], 0.05, rb=0.1)
    F.tuyau(lot, M["cu0"], lv, [(-HX - 0.03, -HY - 0.08, 0.28), (-0.94 - 0.2, -HY - 0.08, 1.0), (-1.05, -HY - 0.08, 1.05), (-0.46, -HY - 0.08, 1.06)], 0.032, rb=0.05)
    F.tuyau(lot, M["cu0"], lv, [(0.47, -HY - 0.06, 0.28), (0.47, -HY - 0.06, 1.02), (0.92, -HY - 0.06, 1.02), (0.92, -HY - 0.06, 1.1)], 0.03, rb=0.05)
    # petits manomètres groupés et soupapes sur la façade
    for (x, z_, rr, gg) in ((0.5, 0.82, 0.07, 5), (0.6, 0.66, 0.05, 0), (0.38 + 0.08, 0.53, 0.05, 0)):
        manometre(lot, M, M["creme"], (x, -HY - 0.015, z_), (0.0, -1.0, 0.0), rr, gg)
    lot.put(M["rouge"], G.tour([(0.0, 0.05), (0.01, 0.05)], 10, "y", (0.9, -HY - 0.08, 0.5)))
    lot.put(lv, G.tube([(0.9, -HY - 0.08, 0.5), (0.9, -HY - 0.015, 0.5)], 0.012, 4))
    lot.xf = None
    return b


def chaudiere(lot, M, r, b):
    """Grande chaudière rivetée couchée à l'est : foyer ouvert sur le cœur, corps à viroles, dôme, sifflet, soupape, boîte à
    fumée à porte ronde et cheminée courte, sur berceau de fonte."""
    cz, cy, Rc = 0.62, -1.98, 0.42
    x0, x1 = 1.05, 3.05
    a = 0.06            # légère rotation : pas d'alignement sur les axes de l'écran
    pose = lambda p: (G.rot_z((p[0] - x0, p[1], 0.0), a)[0] + x0, G.rot_z((p[0] - x0, p[1], 0.0), a)[1] + cy, p[2] + cz)
    lot.xf = pose
    # corps à viroles, une sur deux dépassant (lecture des tôles)
    x = x0 + 0.42
    i = 0
    while x < x1 - 0.1:
        w = 0.3 + 0.08 * ((i * 7) % 3)
        rr = Rc + (0.012 if i % 2 else 0.0)
        lot.put(M["cu%d" % (0 if i % 3 == 0 else (1 if i % 3 == 1 else 3))], G.tour([(x, rr), (x + w, rr)], 32, "x", cap0=True))
        n = 22
        for s in (x + 0.018, x + w - 0.018):
            lot.put(M["pl3"], G.rivets_le_long([((s, (rr + 0.002) * math.cos(TAU * k / n), (rr + 0.002) * math.sin(TAU * k / n)), (0.0, math.cos(TAU * k / n), math.sin(TAU * k / n))) for k in range(n)], 0.012, 0.009))
        if i in (1, 3):
            lot.put(M["laiton"], G.tour([(x + w * 0.5 - 0.02, rr + 0.012), (x + w * 0.5 + 0.02, rr + 0.012)], 32, "x"))
        x += w
        i += 1
    # boîte à fumée (extrémité est), porte ronde à charnières, cheminée courte
    lot.put(M["pl1"], G.tour([(x1 - 0.02, Rc + 0.03), (x1 + 0.28, Rc + 0.03), (x1 + 0.3, Rc - 0.04), (x1 + 0.32, 0.0)], 32, "x"))
    lot.put(M["cercle"], G.tour([(x1 + 0.27, Rc + 0.045), (x1 + 0.29, Rc + 0.045)], 32, "x"))
    # dôme de vapeur (laiton), sifflet, soupape à levier et contrepoids, tuyau d'alimentation
    lot.put(M["laiton"], G.tour([(Rc - 0.02, 0.17), (Rc + 0.18, 0.15), (Rc + 0.28, 0.1), (Rc + 0.32, 0.0)], 18, "z", (x0 + 0.95, 0.0, 0.0)))
    lot.put(M["cu2"], G.tour([(Rc, 0.21), (Rc + 0.03, 0.21)], 18, "z", (x0 + 0.95, 0.0, 0.0)))
    lot.put(M["pl1"], G.tour([(Rc, 0.05), (Rc + 0.1, 0.04), (Rc + 0.11, 0.085), (Rc + 0.15, 0.08), (Rc + 0.17, 0.0)], 12, "z", (x0 + 1.45, 0.05, 0.0)))
    lot.put(M["laiton"], G.tube([(x0 + 1.45, 0.05, Rc + 0.14), (x0 + 1.72, 0.05, Rc + 0.1)], 0.01, 4))
    lot.put(M["pl1"], G.sphere((x0 + 1.72, 0.05, Rc + 0.07), 0.045, 8, 4))
    lot.put(M["laiton"], G.tour([(Rc, 0.022), (Rc + 0.2, 0.022), (Rc + 0.21, 0.036), (Rc + 0.34, 0.036), (Rc + 0.36, 0.0)], 10, "z", (x0 + 0.62, 0.12, 0.0)))
    lot.xf = None
    # foyer : caisson de briques cerclé, porte ouverte sur le cœur
    fx, fw = x0 + 0.2, 0.46
    lot.put(M["brique"], G.boite((fx, cy, cz - 0.08), (fw, 0.86, 1.06)))
    lot.put(M["cercle"], G.boite((fx, cy, cz + 0.45), (fw + 0.04, 0.9, 0.05)))
    lot.put(M["cercle"], G.boite((fx, cy, cz - 0.28), (fw + 0.04, 0.9, 0.05)))
    # bouche du foyer face au sud, cœur à nu derrière deux barreaux
    my = cy - 0.44
    lot.put(M["int"], G.boite((fx, my + 0.0, cz + 0.04), (0.34, 0.02, 0.42)))
    CO = (fx, my - 0.1, cz + 0.04)
    lot.put(M["coeur"], G.sphere(CO, 0.17, 14, 7))
    for x in (fx - 0.1, fx + 0.1):
        lot.put(M["pl1"], G.tube([(x, my - 0.2, cz - 0.17), (x, my - 0.23, cz + 0.05), (x, my - 0.2, cz + 0.25)], 0.014, 5))
    lot.put(M["pl1"], G.tube([(fx - 0.2, my - 0.2, cz + 0.04), (fx + 0.2, my - 0.2, cz + 0.04)], 0.012, 4))
    lot.put(M["laiton"], G.boite((fx, my - 0.02, cz + 0.29), (0.44, 0.04, 0.07)))
    lot.put(M["pl2"], G.boite((fx + 0.29, my - 0.13, cz + 0.04), (0.04, 0.26, 0.44), 0.45))        # porte de foyer ouverte
    lot.put(M["laiton"], G.tube([(fx + 0.31, my - 0.22, cz + 0.05), (fx + 0.35, my - 0.27, cz + 0.05)], 0.008, 3))
    Q.lumiere_coeur((CO[0], CO[1] - 0.3, CO[2] + 0.1), 12.0)
    # berceaux de fonte (pas réguliers évités)
    for x in (x0 + 0.72, x0 + 1.4, x0 + 1.98):
        lot.put(M["pl1"], G.prisme([(x - 0.1, cy - 0.46), (x + 0.1, cy - 0.46), (x + 0.1, cy + 0.46), (x - 0.1, cy + 0.46)], 0.0, cz - 0.18, 0.74))
        lot.put(M["pierre"], G.boite((x, cy, 0.05), (0.34, 1.0, 0.1)))
    # porte de boîte à fumée (vue un peu de biais par le lacet : posée sur l'extrémité)
    # cheminée courte de la boîte à fumée
    c1 = (x1 + 0.12, cy + a * (x1 - x0 + 0.12))
    lot.put(M["pl1"], G.tour([(cz + Rc, 0.14), (cz + Rc + 0.05, 0.11), (cz + Rc + 0.56, 0.12), (cz + Rc + 0.68, 0.17), (cz + Rc + 0.7, 0.13), (cz + Rc + 0.42, 0.0)], 16, "z", (c1[0], c1[1], 0.0)))
    # gros tuyaux : du dôme au toit de l'hôtel, de la chaudière vers le crâne ; flexibles
    dome = (x0 + 0.95, cy + a * 0.95)
    p_h = b((1.32, -0.7, 1.32))
    F.tuyau(lot, M["cu2"], M["laiton"], [(dome[0], dome[1], cz + Rc + 0.32), (dome[0], dome[1], cz + Rc + 0.6), (p_h[0] + 0.05, p_h[1] - 0.05, cz + Rc + 0.6), (p_h[0], p_h[1], p_h[2])], 0.06, rb=0.11)
    F.tuyau(lot, M["cu0"], M["laiton"], [(x0 + 1.72, cy + 0.32, cz + 0.28), (x0 + 1.72, cy + 0.62, cz + 0.28), (x0 + 1.72, cy + 0.68, 1.35)], 0.035, rb=0.07)
    # manomètres et voyant de niveau sur le flanc sud du corps
    for (x, rr, gg, lum) in ((x0 + 0.85, 0.09, 7, "cadran"), (x0 + 1.18, 0.06, 0, "creme")):
        manometre(lot, M, M[lum], (x, cy - Rc - 0.03, cz + 0.2), G.norm((0.0, -1.0, 0.45)), rr, gg)
    lot.put(M["verre"], G.tube([(x0 + 1.5, cy - Rc - 0.02, cz - 0.1), (x0 + 1.5, cy - Rc - 0.02, cz + 0.18)], 0.016, 6))
    for z_ in (cz - 0.1, cz + 0.18):
        lot.put(M["laiton"], G.boite((x0 + 1.5, cy - Rc + 0.0, z_), (0.05, 0.07, 0.04)))


def machine(lot, M, r):
    """Machine à vapeur à l'ouest : le volant de l'âge 2, entraîné par un cylindre et une bielle ; régulateur à boules de Watt."""
    wx, wy = -2.62, -2.42
    Q2.volant(lot, M, r, (wx, wy))
    zc = 0.74
    # cylindre de cuivre cerclé, couché vers l'est, bielle jusqu'au maneton
    cx0, cx1 = -1.72, -1.1
    lot.put(M["cu0"], G.tour([(cx0, 0.14), (cx1, 0.14)], 20, "x", (0.0, wy - 0.02, zc), cap0=True, cap1=True))
    for x, m in ((cx0, "laiton"), (cx1, "laiton"), ((cx0 + cx1) / 2 - 0.05, "pl1"), ((cx0 + cx1) / 2 + 0.1, "pl1")):
        lot.put(M[m], G.tour([(x - 0.022, 0.158), (x + 0.022, 0.158)], 20, "x", (0.0, wy - 0.02, zc)))
    lot.put(M["pl1"], G.tube([(cx0 - 0.42, wy - 0.02, zc), (cx0, wy - 0.02, zc)], 0.018, 6))
    lot.put(M["laiton"], G.boite((cx0 - 0.42, wy - 0.02, zc), (0.1, 0.07, 0.07)))
    lot.put(M["pl2"], G.tube([(cx0 - 0.42, wy - 0.02, zc), (wx + 0.2, wy - 0.17, zc + 0.14)], 0.018, 5))
    lot.put(M["laiton"], G.sphere((wx + 0.2, wy - 0.17, zc + 0.14), 0.03, 8, 4))
    # glissière, socle, boîte de distribution
    lot.put(M["pl1"], G.boite(((cx0 - 0.22), wy - 0.02, zc - 0.11), (0.5, 0.1, 0.03)))
    lot.put(M["pierre"], G.boite(((cx0 + cx1) / 2 - 0.25, wy - 0.02, 0.18), (1.25, 0.44, 0.36)))
    lot.put(M["pl1"], G.prisme([(cx0 + 0.02, wy - 0.13), (cx1 - 0.02, wy - 0.13), (cx1 - 0.02, wy + 0.09), (cx0 + 0.02, wy + 0.09)], 0.36, zc - 0.1, 0.8))
    lot.put(M["cu2"], G.boite(((cx0 + cx1) / 2, wy - 0.02, zc + 0.19), (0.28, 0.2, 0.12)))
    # régulateur de Watt : colonne, bras et 2 boules, porte-poulie
    gx, gy = -1.42, wy - 0.02
    zg = zc + 0.25
    lot.put(M["laiton"], G.tube([(gx, gy, zg), (gx, gy, zg + 0.62)], 0.012, 5))
    for s in (-1, 1):
        lot.put(M["laiton"], G.tube([(gx, gy, zg + 0.5), (gx + s * 0.13, gy, zg + 0.34)], 0.007, 3))
        lot.put(M["laiton"], G.tube([(gx, gy, zg + 0.16), (gx + s * 0.08, gy, zg + 0.26)], 0.006, 3))
        lot.put(M["laiton"], G.sphere((gx + s * 0.15, gy, zg + 0.32), 0.05, 10, 5))
    lot.put(M["pl1"], G.tour([(zg + 0.0, 0.04), (zg + 0.05, 0.04)], 10, "z", (gx, gy, 0.0)))
    lot.put(M["cuir"], G.tube([(gx, gy, zg + 0.02), (wx + 0.1, wy + 0.1, zc + 0.04)], 0.012, 4))
    # tuyau de vapeur de l'hôtel au cylindre, purge
    b = R.repere(H["cx"], H["cy"], H["rz"])
    F.tuyau(lot, M["cu0"], M["laiton"], [b((-HX - 0.03, -HY - 0.08, 0.28)), (cx1 + 0.08, wy + 0.18, zc + 0.18), ((cx0 + cx1) / 2, wy - 0.02, zc + 0.26)], 0.03, rb=0.07)
    F.tuyau(lot, M["cu3"], M["laiton"], [(cx0 + 0.05, wy - 0.16, zc - 0.05), (cx0 + 0.05, wy - 0.28, 0.18), (cx0 - 0.25, wy - 0.28, 0.06)], 0.018, rb=0.04)


def rails(lot, M, r):
    """Voie étroite sur traverses (bord irrégulier), wagonnet de charbon, tas de charbon : de la cour à la chaudière."""
    ya, yb = -2.8, -2.56
    x0, x1 = -1.05, 3.65
    x = x0
    while x < x1:
        lot.put(M["bois"], G.boite((x, (ya + yb) / 2 + r.f(-0.015, 0.015), 0.02), (0.08, 0.44, 0.03), r.f(-0.05, 0.05)))
        x += r.f(0.15, 0.2)
    for y in (ya, yb):
        lot.put(M["pl2"], G.boite(((x0 + x1) / 2, y, 0.05), (x1 - x0, 0.022, 0.025)))
    wx = 0.95
    w = (0.62, 0.34, 0.26)
    v, f, u = G.prisme([(wx - w[0] / 2, (ya + yb) / 2 - w[1] / 2), (wx + w[0] / 2, (ya + yb) / 2 - w[1] / 2), (wx + w[0] / 2, (ya + yb) / 2 + w[1] / 2), (wx - w[0] / 2, (ya + yb) / 2 + w[1] / 2)], 0.14, 0.14 + w[2], 1.15)
    lot.put(M["pl1"], (v, f, u))
    lot.put(M["charbon"], G.butte_polaire((wx, (ya + yb) / 2, 0.14 + w[2] - 0.01), w[0] * 0.5, w[1] * 0.56, 0.1, r, 3, 18, 0.35, 0.1))
    rr = G.Rnd(351)
    for k in range(12):
        lot.put(M["charbon"], G.sphere((wx + rr.f(-0.26, 0.26), (ya + yb) / 2 + rr.f(-0.14, 0.14), 0.14 + w[2] + 0.05), rr.f(0.025, 0.045), 5, 3))
    for x_ in (wx - 0.19, wx + 0.19):
        for y in (ya, yb):
            lot.put(M["pl1"], G.tour([(-0.015, 0.075), (0.015, 0.075)], 12, "y", (x_, y, 0.095)))
    lot.put(M["charbon"], F.tertre((-0.5, -2.46, 0.02), 0.42, 0.26, 0.2, rr, na=26, nr=7))
    for k in range(18):
        x_, y_ = rr.f(-0.85, -0.15), rr.f(-2.68, -2.26)
        lot.put(M["charbon"], G.sphere((x_, y_, 0.035 + 0.13 * max(0.0, 1 - ((x_ + 0.5) / 0.42) ** 2 - ((y_ + 2.46) / 0.26) ** 2)), rr.f(0.03, 0.055), 5, 3))


def cour(lot, M, r, b):
    """Cour pavée (contour irrégulier), fûts, caisses, bouteilles de vapeur."""
    lot.xf = b

    def trou(u, v):
        x, y = u - 2.3, v - 1.75
        return abs(x) > 2.12 + 0.15 * math.sin(y * 7.0) or y < -1.72 + 0.12 * math.sin(x * 2.3)
    lot.xf = None
    mesh = G.boite((-0.2, -2.0, 0.012), (3.8, 1.25, 0.024), H["rz"] * 0.5)
    lot.put(M["pave"], mesh)
    rr = G.Rnd(361)
    for k in range(9):                                                   # bord de pavés disjoints
        x, y = rr.f(-2.2, 1.7), rr.f(-2.74, -2.6)
        lot.put(M["pave"], G.boite((x, y, 0.012), (rr.f(0.14, 0.24), rr.f(0.1, 0.16), 0.024), rr.f(-0.4, 0.4)))
    for (c, s, rz) in (((-0.75, -1.98, 0.024), (0.3, 0.26, 0.26), 0.2), ((-0.42, -2.08, 0.024), (0.24, 0.22, 0.2), -0.3), ((-0.72, -2.0, 0.284), (0.2, 0.18, 0.15), 0.45)):
        R.caisse(lot, M["bois"], M["bois"], M["cercle"], c, s, rz)
    for (c, h, co, rz) in (((0.36, -2.25, 0.024), 0.3, False, 0.0), ((0.58, -2.18, 0.024), 0.34, False, 0.0), ((0.12, -2.35, 0.024), 0.34, True, 0.4)):
        R.tonneau(lot, M["pl1"] if h > 0.31 else M["cu3"], M["laiton"] if h < 0.32 else M["cercle"], c, 0.09, h, couche=co, rz=rz)
    R.menus(lot, [M["pl1"], M["cercle"], M["noyau"], M["laiton"]], rr, 60, -2.1, 1.0, -2.55, -1.75, 0.024)


def reservoir(lot, M, r, c):
    """Réservoir d'eau sur trépied riveté, au nord-est : ancêtre du gazomètre de l'âge 8."""
    x, y = c
    R0, z0, z1 = 0.62, 1.62, 2.5
    for k in range(4):
        a = TAU * k / 4 + 0.5
        lot.put(M["pl1"], G.tube([(x + 0.72 * math.cos(a), y + 0.72 * math.sin(a), 0.0), (x + 0.5 * math.cos(a), y + 0.5 * math.sin(a), z0)], 0.03, 5))
        lot.put(M["pierre"], G.boite((x + 0.72 * math.cos(a), y + 0.72 * math.sin(a), 0.07), (0.22, 0.22, 0.14)))
        for (z, f) in ((0.55, 0.65), (1.1, 0.58)):
            b0 = TAU * (k + 1) / 4 + 0.5
            pa = (x + f * 1.04 * math.cos(a), y + f * 1.04 * math.sin(a), z)
            pb = (x + f * 1.04 * math.cos(b0), y + f * 1.04 * math.sin(b0), z)
            lot.put(M["pl1"], G.tube([pa, pb], 0.014, 4))
    lot.put(M["cu1"], G.tour([(z0, R0), (z1, R0)], 32, "z", (x, y, 0.0)))
    z = z0
    i = 0
    while z < z1 - 0.02:
        lot.put(M["pl1"] if i % 2 else M["laiton"], G.tour([(z - 0.018, R0 + 0.012), (z + 0.018, R0 + 0.012)], 32, "z", (x, y, 0.0)))
        n = 18
        lot.put(M["pl3"], G.rivets_le_long([((x + (R0 + 0.006) * math.cos(TAU * k / n), y + (R0 + 0.006) * math.sin(TAU * k / n), z + 0.05), (math.cos(TAU * k / n), math.sin(TAU * k / n), 0.0)) for k in range(n)], 0.012, 0.008))
        z += r.f(0.25, 0.38)
        i += 1
    lot.put(M["cu2"], G.tour([(z1, R0 + 0.01), (z1 + 0.1, R0 - 0.04), (z1 + 0.3, 0.14), (z1 + 0.36, 0.0)], 32, "z", (x, y, 0.0)))
    lot.put(M["laiton"], G.tour([(z1 + 0.34, 0.03), (z1 + 0.5, 0.012)], 8, "z", (x, y, 0.0)))
    F.tuyau(lot, M["cu0"], M["laiton"], [(x - 0.35, y - 0.42, z0 - 0.01), (x - 0.35, y - 0.42, 0.4), (x - 0.9, y - 0.5, 0.35)], 0.04, rb=0.08)
    R.echelle(lot, M["pl1"], (x + 0.3, y - R0 - 0.16, 0.0), (x + 0.3, y - R0 - 0.02, z1 + 0.05), 0.15, 0.14, 0.009, 0.006)


def coque(lot, M, r, pose_ar, pose_av, AR, AV):
    """Ce que l'âge 2 a laissé (feuillards, boucliers), plus la vapeur : tuyaux de cuivre sur le dos, hublots de cuivre."""
    lot.xf = pose_ar
    for x in (-2.82, -2.14, -1.5):
        Q2.cerclage(lot, M, AR, x, 1.7, 9.0, 0.1, r)
    Q2.bouclier(lot, M, AR, -2.75, -2.2, 6.6, 8.1, r, "cu1")
    Q2.bouclier(lot, M, AR, -2.08, -1.55, 4.4, 5.9, r, "pl2")
    Q2.bouclier(lot, M, AR, -2.1, -1.6, 2.1, 3.3, r, "cu3")
    F.tuyau(lot, M["cu0"], M["laiton"], [AR(-3.0, 4.4, 0.13), AR(-2.1, 4.5, 0.17), AR(-1.2, 4.6, 0.15), AR(-0.75, 4.3, 0.12)], 0.05)
    Q.hublot(lot, M, AR, -1.85, 7.65, "rond", M["ambre"])
    R.coque_menus(lot, M, AR, -3.0, -1.2, 3.5, 8.8, r, 26)
    lot.xf = pose_av
    for x in (0.92, 2.42):
        Q2.cerclage(lot, M, AV, x, 1.6 if x < 2 else 1.2, 8.7, 0.1, r)
    Q2.bouclier(lot, M, AV, 1.08, 1.75, 5.6, 7.1, r, "cu0")
    Q2.bouclier(lot, M, AV, 0.42, 0.88, 1.6, 2.9, r, "pl2")
    F.tuyau(lot, M["cu2"], M["laiton"], [AV(0.55, 4.7, 0.12), AV(1.15, 5.15, 0.14), AV(2.4, 5.2, 0.1), AV(2.72, 5.35, 0.04)], 0.035)
    o, ex, ey, ez = AV.repere(1.5, 7.75, 0.05)
    manometre(lot, M, M["creme"], o, ez, 0.08, 6)
    R.coque_menus(lot, M, AV, 2.3, 3.1, 4.5, 8.5, r, 16)
    lot.xf = None


def mise_en_scene(lot, M, r, b, pose_ar, pose_av):
    for p in (pose_ar((-2.75, -1.0, -0.72)), pose_ar((-1.6, -1.15, -0.7)), pose_av((2.7, -0.6, -0.5)), pose_ar((-2.75, 1.25, -0.5)), pose_av((2.2, 1.05, -0.7))):
        Q2.jambe(lot, M, p)
    for (x, y) in ((-2.95, -1.2), (-3.05, 1.1)):
        lot.put(M["pl1"], G.boite((x, y, 0.28), (0.6, 0.1, 0.5)))
        lot.put(M["pl3"], G.boite((x, y - 0.12, 0.06), (0.8, 0.28, 0.1)))
    F.flexible(lot, M["gaine"], [pose_ar((-1.3, -1.15, -0.25)), (-1.9, -1.82, 0.14), b((-1.28, -0.95, 0.3))], 0.045)
    F.flexible(lot, M["gaine"], [pose_av((0.95, -0.95, -0.3)), (1.05, -1.42, 0.36), (1.28, -1.52, 0.6)], 0.04)
    F.faisceau(lot, [M["rouge"], M["noir"], M["noir"]], b((UX, 0.5, 2.0)), pose_av((0.9, 0.3, 1.0)), 0.22, 0.012, 3, 0.026, r)
    F.faisceau(lot, [M["noir"], M["rouge"], M["noir"]], b((-UX, 0.4, 2.0)), pose_ar((-1.2, 0.2, 1.05)), 0.2, 0.012, 3, 0.026, r)
    F.faisceau(lot, [M["rouge"], M["noir"]], pose_av((1.05, 0.0, 2.9)), b((UX * 0.5, 0.5, Z3 + 0.1)), 0.32, 0.01, 2, 0.022, r)
    # lampadaires à gaz le long de la cour, éteints sauf un
    for (x, y, lum) in ((-2.05, -2.82, "veil"), (0.38, -2.92, "ambre")):
        lot.put(M["pl1"], G.tube([(x, y, 0.0), (x, y, 0.98)], 0.018, 5))
        lot.put(M["pierre"], G.tour([(0.0, 0.05), (0.08, 0.04)], 8, "z", (x, y, 0.0), cap1=True))
        lot.put(M["pl1"], G.tube([(x - 0.1, y, 0.84), (x + 0.1, y, 0.84)], 0.006, 3))
        R.lanterne(lot, M["pl1"], M["ambre"] if lum == "ambre" else M["verre"], (x, y, 1.1))


def sol(lot, M, r):
    R.butte_nez(lot, M, r, 0.68)
    R.cailloux(lot, M, r, 16, -4.3, 4.5, -3.1, 2.5, sauf=lambda x, y: abs(y) < 2.5 and abs(x) < 3.2)
    R.toles_sol(lot, M, r, (((-3.75, -2.25), 0.3, "pl1", 0.0), ((-3.45, 2.2), 0.34, "j0", 0.0), ((3.65, -2.2), 0.24, "cu3", 0.3), ((1.1, 2.15), 0.3, "pl3", 0.3), ((-0.5, 2.15), 0.26, "cu3", 0.0)))
    rr = G.Rnd(371)
    R.menus(lot, [M["pl1"], M["cercle"], M["noyau"], M["cu3"]], rr, 44, -4.3, 4.6, -3.1, 2.5, 0.0)


def build(S, lot):
    M = matieres(S)
    r = G.Rnd(2330)
    ra = G.Rnd(2331)
    E["choix"] = choix_factory(M)
    pose_ar, pose_av, AR, AV = R.carcasse(lot, M, r, ra, E)
    coque(lot, M, G.Rnd(2332), pose_ar, pose_av, AR, AV)
    b = hotel(lot, M, G.Rnd(2333))
    # 2 hautes cheminées rondes à l'arrière de l'hôtel (l'événement de l'âge), hauteurs inégales
    lot.xf = b
    cheminee(lot, M, (-0.62, 0.55), Z2, 4.72, 0.2, G.Rnd(2334))
    cheminee(lot, M, (0.42, 0.64), Z2, 4.2, 0.165, G.Rnd(2335))
    for (cx, zh) in ((-0.62, 4.0), (0.42, 3.6)):
        pass
    lot.xf = None
    Q2.treillis_mat(lot, M, pose_av((1.75, 0.2, 0.0))[:2], 1.72, 1.65, 0.2)
    cour(lot, M, G.Rnd(2336), b)
    chaudiere(lot, M, G.Rnd(2337), b)
    machine(lot, M, G.Rnd(2338))
    rails(lot, M, G.Rnd(2339))
    reservoir(lot, M, G.Rnd(2340), (3.0, 1.55))
    mise_en_scene(lot, M, G.Rnd(2341), b, pose_ar, pose_av)
    sol(lot, M, G.Rnd(2342))
    return {"pose": {k: v for k, v in E.items() if k != "choix"}}
