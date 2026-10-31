"""QG, ÂGE 0 : L'ÉPAVE DU VAISSEAU ÉCRASÉ (refonte QG du 30/10, emprise 8×4). NEZ À DROITE (+X).

Forme refaite de zéro (brief QG §3 ; vaisseau.py, le « cigare », n'est PAS utilisé). Histoire : le vaisseau a glissé
vers l'est ; il s'est cassé en DEUX TRONÇONS au ventre, coudés en « V » ouvert vers le sud (vers la caméra) :
- tronçon arrière (propulsion) couché sur son flanc nord (roulis −0,42 : flanc sud tourné vers la caméra), deux
  grosses tuyères à gauche, dérive dressée, aile nord repliée vers le haut, aile sud arrachée (moignon) ;
- tronçon avant (crâne) tordu dans l'autre sens (roulis +0,28 : dos et verrière vers la caméra), nez à chevrons
  planté dans une butte de terre poussée vers l'est, nez vers le sud-est (lacet −0,11) ;
- entre les deux, le CŒUR-RÉACTEUR à nu, orange (seul foyer fort), dans sa cage cassée ; côtes balayées vers la
  queue, câbles et flexibles arrachés ; aile sud et débris au sol (≥ 10), sillon de terre.
Toutes les cotes en unités du rendu (X = tuiles ; Y : une tuile d'écran vaut √2).
"""
import math

import forme as F
import geo as G
import mat as MT

ESSAI = {"roul_ar": -0.42, "roul_av": 0.4, "lacet_ar": 0.33, "tang_ar": 0.14, "k": 1.36, "n": 3}


def _st(lst):
    k = ESSAI["k"]
    return [(x, w * k, ht * k, hb * k, dz * k, e) for (x, w, ht, hb, dz, e) in lst]


# ------------------------------------------------------------------------------------------------ matières
JAUNES = ((0.66, 0.44, 0.022), (0.54, 0.35, 0.018), (0.76, 0.53, 0.03), (0.4, 0.25, 0.02))
TOLES = (None, (0.29, 0.21), None, (0.42, 0.15))


def matieres(S):
    M = {}
    MT.PATINE.update(ta=0.12, ra=0.2, ec=0.45, nu_k=1.5, ec_col=(0.05, 0.028, 0.01))    # m1 (ec 0,9) virait à l'olive sale
    for i, c in enumerate(JAUNES):
        M["j%d" % i] = MT.surface("q0_j%d" % i, c, rough=0.55, met=0.1, grain=0.3, coulures=0.9, usure=0.8,
                                  nu=(0.62, 0.6, 0.55), crasse=1.0, crasse_col=(0.012, 0.009, 0.005),
                                  pied=(0.0, 0.7, 0.85), rouille=(0.15, 0.06, 0.02), tole=TOLES[i], joint=0.55,
                                  joint_l=0.012, var=0.06, relief=0.4, graine=1 + i)
    M["chevron"] = MT.surface("q0_chevron", JAUNES[2], rough=0.55, met=0.1, grain=0.14,
                              bandes=(0.16, (0.014, 0.013, 0.012), 0.5), usure=0.75, nu=(0.33, 0.31, 0.28),
                              crasse=0.6, coulures=0.4, graine=6)
    M["roussi"] = MT.surface("q0_roussi", (0.085, 0.048, 0.02), rough=0.7, met=0.3, grain=0.14, usure=0.7,
                             nu=(0.25, 0.2, 0.15), crasse=0.7, coulures=0.6, graine=7)
    M["primaire"] = MT.surface("q0_primaire", (0.075, 0.07, 0.04), rough=0.6, met=0.3, grain=0.1, usure=0.6,
                               crasse=0.65, coulures=0.7, graine=8)
    M["rouille"] = MT.surface("q0_rouille", (0.15, 0.058, 0.02), rough=0.8, met=0.2, grain=0.18, usure=0.4,
                              crasse=0.6, graine=9)
    M["nu"] = MT.surface("q0_nu", (0.2, 0.19, 0.18), rough=0.4, met=0.85, grain=0.1, usure=0.3, crasse=0.6,
                         coulures=0.5, graine=10)
    M["noyau"] = MT.surface("q0_noyau", (0.007, 0.0065, 0.006), rough=0.6, met=0.6, usure=0.25, nu=(0.12, 0.11, 0.1),
                            crasse=0.8, graine=11)
    M["acier"] = MT.surface("q0_acier", (0.042, 0.04, 0.036), rough=0.45, met=0.85, usure=0.8,
                            nu=(0.3, 0.29, 0.27), crasse=0.7, coulures=0.5, graine=12)
    M["bague"] = MT.surface("q0_bague", (0.085, 0.081, 0.075), rough=0.4, met=0.9, usure=0.7, nu=(0.4, 0.39, 0.37),
                            crasse=0.7, coulures=0.4, graine=13)
    M["brule"] = MT.surface("q0_brule", (0.016, 0.013, 0.011), rough=0.75, met=0.4, usure=0.0, crasse=0.8, graine=14)
    M["riv"] = MT.surface("q0_riv", (0.03, 0.024, 0.014), rough=0.6, met=0.3, usure=0.4, nu=(0.2, 0.18, 0.15),
                          crasse=0.4, graine=15)
    M["gaine"] = MT.surface("q0_gaine", (0.028, 0.027, 0.025), rough=0.7, met=0.0, usure=0.5, nu=(0.1, 0.1, 0.095),
                            crasse=0.5, graine=16)
    M["rouge"] = MT.surface("q0_rouge", (0.3, 0.022, 0.014), rough=0.55, met=0.0, usure=0.3, crasse=0.4, graine=17)
    M["noir"] = MT.surface("q0_noir", (0.016, 0.016, 0.016), rough=0.6, met=0.0, usure=0.3, crasse=0.3, graine=18)
    M["cuivre"] = MT.surface("q0_cuivre", (0.36, 0.15, 0.065), rough=0.45, met=0.9, usure=0.4, crasse=0.7,
                             coulures=0.5, rouille=(0.06, 0.13, 0.09), graine=19)
    M["terre"] = MT.surface("q0_terre", (0.12, 0.052, 0.02), rough=1.0, met=0.0, grain=0.45, usure=0.0, crasse=0.7,
                            crasse_col=(0.025, 0.016, 0.01), graine=20)
    M["terre2"] = MT.surface("q0_terre2", (0.07, 0.032, 0.014), rough=1.0, met=0.0, grain=0.45, usure=0.0, crasse=0.7,
                             crasse_col=(0.02, 0.013, 0.008), graine=21)
    M["roc"] = MT.surface("q0_roc", (0.075, 0.066, 0.056), rough=0.9, met=0.0, grain=0.2, usure=0.6,
                          nu=(0.16, 0.14, 0.12), crasse=0.6, graine=22)
    M["verre"] = MT.verre("q0_verre", col=(0.012, 0.03, 0.035), reflet=(0.07, 0.11, 0.12))
    try:    # verre mat : pas de reflet du soleil (essai 1 : vitre blanche)
        M["verre"].node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.45
    except Exception:
        pass
    try:    # cœur : braise en croûte (essai 1 : brûlé en blanc)
        M["coeur"] = S.mat_emissive("q0_coeur", (1.0, 0.13, 0.01), strength=1.5, base=(0.05, 0.012, 0.003),
                                    main_scale=0.15, crust=(7.0, 0.65, 3.0))
    except Exception:
        M["coeur"] = MT.lumiere(S, "q0_coeur", (1.0, 0.2, 0.02), 2.6, main=0.15)
    M["voyant"] = MT.lumiere(S, "q0_voyant", (1.0, 0.07, 0.03), 8.0, main=0.4)
    M["hublot_a"] = MT.lumiere(S, "q0_hublot_a", (1.0, 0.42, 0.1), 3.0, main=0.12)
    M["hublot_r"] = MT.lumiere(S, "q0_hublot_r", (1.0, 0.16, 0.07), 1.6, main=0.3)
    return M


def lumiere_coeur(p, energie=22.0):
    """Lueur orange du cœur : lumière ponctuelle de la seule passe principale (fo_scene.EXTRA_LIGHTS)."""
    try:
        import bpy
        import fo_scene as S
        d = bpy.data.lights.new("q0_coeur_l", "POINT")
        d.energy = energie
        d.color = (1.0, 0.32, 0.06)
        d.shadow_soft_size = 0.12
        o = bpy.data.objects.new("q0_coeur_l", d)
        bpy.context.scene.collection.objects.link(o)
        o.location = p
        S.EXTRA_LIGHTS.append(o)
    except Exception as exc:  # aperçu hors Blender
        print("[QG00] pas de lumière ponctuelle :", exc)


# ------------------------------------------------------------------------------------------------ coque et tôles
def noyau(lot, m, C, x0, x1, ouvert, pasx=0.11, past=0.5):
    nx = max(1, int((x1 - x0) / pasx))
    xs = [x0 + (x1 - x0) * i / float(nx) for i in range(nx + 1)]
    ts = [k * past for k in range(int(12 / past) + 1)]
    for i in range(nx):
        for j in range(len(ts) - 1):
            if ouvert((xs[i] + xs[i + 1]) / 2, (ts[j] + ts[j + 1]) / 2):
                continue
            q = [C(xs[i], ts[j], -0.012), C(xs[i + 1], ts[j], -0.012), C(xs[i + 1], ts[j + 1], -0.012),
                 C(xs[i], ts[j + 1], -0.012)]
            lot.put(m, (q, [(0, 1, 2, 3)], [(xs[i], ts[j]), (xs[i + 1], ts[j]), (xs[i + 1], ts[j + 1]), (xs[i], ts[j + 1])]))


def toles(lot, M, C, xs, rnd, ouvert, choix, trou=lambda x, t: False):
    """Tôles irrégulières : par bande, largeurs en t tirées de 0,7 à 1,7, origine décalée d'une bande à l'autre,
    bords transversaux biaisés, épaisseur et relevé tirés ; rivets sur le bord avant ; doublures à cheval."""
    for i in range(len(xs) - 1):
        x0, x1 = xs[i], xs[i + 1]
        xm = (x0 + x1) / 2
        t = rnd.f(-0.8, 0.0)
        t_fin = t + 12.0
        while t < t_fin - 0.3:
            w = min(rnd.f(2.2, 4.2), t_fin - t)
            ta, tb = t, t + w
            t = tb
            tm = (ta + tb) / 2
            if ouvert(xm, tm % 12) or trou(xm, tm % 12):
                continue
            g = rnd.f(0.018, 0.048)
            u = rnd.f()
            g1 = (g, g + rnd.f(0.01, 0.035)) if u < 0.3 else ((g, g + rnd.f(0.07, 0.14)) if u > 0.93 else g)
            sk = (rnd.f(-0.2, 0.2), rnd.f(-0.2, 0.2))
            mesh, P = F.plaque(C, x0 - rnd.f(-0.02, 0.1), x1 + rnd.f(-0.02, 0.1), ta + 0.045, tb - 0.045, 0.0, g1, sk)
            lot.put(choix(rnd, xm, tm % 12), mesh)
            if rnd.f() < 0.45:
                n_r = max(2, int(G.length(G.sub(C(x0, tb), C(x0, ta))) / 0.17))
                lot.put(M["riv"], F.rivets_bord(P, g if not isinstance(g1, tuple) else g1[0], n_r, 0.02, 0.0))
            if rnd.f() < 0.3:   # petite pièce : trappe, boulons, renfort
                fx, ft = rnd.f(0.25, 0.75), rnd.f(0.25, 0.75)
                o = P(fx, ft, g + 0.002 if not isinstance(g1, tuple) else g1[0] + 0.002)
                ez = G.norm(G.sub(P(fx, ft, 0.2), P(fx, ft, 0.0)))
                ex = G.norm(G.sub(P(min(1.0, fx + 0.1), ft, 0.0), P(fx, ft, 0.0)))
                ey = G.cross(ez, ex)
                kind = rnd.f()
                if kind < 0.4:
                    lot.put(M["acier"], F.local(G.boite((0, 0, 0.012), (rnd.f(0.08, 0.14), rnd.f(0.06, 0.1), 0.024)), o, ex, ey, ez))
                elif kind < 0.75:
                    for q in range(3):
                        lot.put(M["riv"], F.local(G.sphere((0.035 * q - 0.035, 0.0, 0.0), 0.02, 6, 3), o, ex, ey, ez))
                else:
                    lot.put(M["primaire"], F.local(G.boite((0, 0, 0.008), (rnd.f(0.12, 0.2), rnd.f(0.1, 0.16), 0.016), rz=rnd.f(-0.4, 0.4)),
                                                   o, ex, ey, ez))
            if rnd.f() < 0.22:   # doublure à cheval sur le joint (casse la grille)
                xd = x1 + rnd.f(-0.08, 0.04)
                td = tb + rnd.f(-0.3, 0.1)
                if not ouvert(xd, td % 12):
                    md, Pd = F.plaque(C, xd - rnd.f(0.1, 0.18), xd + rnd.f(0.08, 0.16), td - rnd.f(0.2, 0.35),
                                      td + rnd.f(0.15, 0.3), g, g + 0.022, (rnd.f(-0.05, 0.05), rnd.f(-0.05, 0.05)))
                    lot.put(choix(rnd, xd, td % 12, patch=True), md)
                    lot.put(M["riv"], F.rivets_bord(Pd, g + 0.022, 3, 0.02, 0.0))


def bords_dechires(lot, M, C, xs, rnd, ouvert, sens_x):
    """Éclats relevés au bord de la brèche : à chaque passage ouvert/fermé le long de t et de x."""
    jaunes = [M["j0"], M["j1"], M["j2"], M["roussi"], M["roussi"], M["nu"]]
    for i in range(len(xs) - 1):
        xm = (xs[i] + xs[i + 1]) / 2
        prev = ouvert(xm, 0.0)
        for k in range(1, 49):
            t = k * 0.25
            o = ouvert(xm, t)
            if o != prev:
                d = 1.0 if o else -1.0          # vers l'ouverture
                if rnd.f() < 0.55:
                    s, ha = rnd.f(-0.14, 0.14), rnd.f(0.1, 0.26)
                    a = C(xm + s - ha, t - 0.12 * d, 0.03)
                    b = C(xm + s + ha, t - 0.12 * d, 0.03)
                    c = C(xm + s + rnd.f(-0.15, 0.15), t + d * rnd.f(0.1, 0.34), rnd.f(0.02, 0.1))
                    lot.put(jaunes[int(rnd.f(0, 5.99))], F.eclat(a, b, c, 0.018))
            prev = o
    for k in range(40):
        t = 4.0 + k * 0.17
        xs_s = [x for x in [xs[0] + (xs[-1] - xs[0]) * q / 80.0 for q in range(81)]]
        for x0, x1 in zip(xs_s[:-1], xs_s[1:]):
            if ouvert(x0, t) != ouvert(x1, t):
                xb = (x0 + x1) / 2
                if k % 3 == 0:
                    a = C(xb - sens_x * 0.05, t - rnd.f(0.1, 0.3), 0.03)
                    b = C(xb - sens_x * 0.05, t + rnd.f(0.1, 0.3), 0.03)
                    c = C(xb + sens_x * rnd.f(0.08, 0.22), t + rnd.f(-0.2, 0.2), rnd.f(0.02, 0.08))
                    lot.put(jaunes[int(rnd.f(0, 5.99))], F.eclat(a, b, c, 0.018))
                break


def lambeau(lot, M, C, x0, x1, t0, t1, xf, rnd, choix):
    """Lambeau de coque arraché (peau, tôles, bords déchirés) pris dans la coque C et posé ailleurs par xf."""
    hors = lambda x, t: not (x0 < x < x1 and t0 < t < t1)
    old = lot.xf
    lot.xf = xf
    noyau(lot, M["noyau"], C, x0 - 0.05, x1 + 0.05, hors)
    xs = [x0 + (x1 - x0) * k / 3.0 for k in range(4)]
    toles(lot, M, C, xs, rnd, hors, choix)
    bords_dechires(lot, M, C, xs, rnd, hors, 1.0)
    lot.xf = old


def epine(lot, M, C, x0, x1, rnd, saut=lambda x: False):
    """Vertèbres de l'épine dorsale (t = 3,5) : blocs inégaux tous les 0,26 à 0,34."""
    x = x0
    while x < x1:
        if not saut(x):
            o, ex, ey, ez = C.repere(x, 3.5, 0.03)
            L = rnd.f(0.12, 0.2)
            lot.put(M["acier"] if rnd.f() < 0.6 else M["primaire"],
                    F.local(G.boite((0.0, 0.0, 0.04), (L, rnd.f(0.1, 0.16), rnd.f(0.06, 0.11)), ry=-0.25), o, ex, ey, ez))
        x += rnd.f(0.26, 0.34)


def surcouche(lot, M, C, x0, x1, rnd, jaunes):
    """Ce qui passe PAR-DESSUS les tôles et casse leur trame : blindages épais en biais, sangles tordues qui font le
    tour du flanc (bouts pendants), flexibles et conduits couchés sur le flanc côté caméra, boîtiers et bouches."""
    for k in range(6):   # blindages : grandes pièces en relief, à cheval sur plusieurs bandes
        xa = rnd.f(x0, x1 - 0.7)
        L, ta = rnd.f(0.55, 1.05), rnd.f(4.6, 8.4)
        tb = ta + rnd.f(0.8, 1.7)
        g = rnd.f(0.07, 0.12)
        mesh, P = F.plaque(C, xa, xa + L, ta, tb, 0.0, (g, g + rnd.f(-0.02, 0.05)), (rnd.f(-0.25, 0.25), rnd.f(-0.25, 0.25)))
        lot.put(jaunes[int(rnd.f(0, 3.99))] if k % 3 else M["primaire"], mesh)
    for k in range(5):   # sangles
        x = rnd.f(x0, x1)
        ta, tb = rnd.f(4.2, 5.6), rnd.f(7.6, 9.2)
        dx = rnd.f(-0.5, 0.5)
        ctrl = [C(x + dx * q / 5.0 + rnd.f(-0.03, 0.03), ta + (tb - ta) * q / 5.0, 0.085 + 0.03 * (q % 2)) for q in range(6)]
        if k % 2:     # bout arraché qui pend
            ctrl.append(G.add(ctrl[-1], (rnd.f(-0.2, 0.2), -0.22, rnd.f(-0.35, -0.1))))
        F.membrure(lot, M["nu"] if k % 3 == 0 else M["acier"], ctrl, 0.014, rnd.f(0.04, 0.065))
    for k in range(3):   # flexibles et conduit couchés sur le flanc
        t0 = rnd.f(5.8, 7.8)
        xa, xb = rnd.f(x0, x0 + 0.4), rnd.f(x1 - 0.5, x1)
        ctrl = [C(xa + (xb - xa) * q / 4.0, t0 + rnd.f(-0.45, 0.45), 0.09 + 0.02 * (q % 2)) for q in range(5)]
        if k == 2:
            F.tuyau(lot, M["cuivre"], M["bague"], ctrl[:4], 0.04)
        else:
            F.flexible(lot, M["gaine"], ctrl, rnd.f(0.035, 0.055))
    for k in range(24):  # menus : équerres, boulons, regards (3 à 10 px), clairs et sombres
        o, ex, ey, ez = C.repere(rnd.f(x0, x1), rnd.f(3.0, 9.2), 0.05)
        sx, sy = rnd.f(0.05, 0.13), rnd.f(0.04, 0.1)
        lot.put([M["acier"], M["noyau"], M["nu"], M["bague"]][k % 4], F.local(G.boite((0, 0, 0.02), (sx, sy, 0.05), rz=rnd.f(-0.8, 0.8)), o, ex, ey, ez))
    for k in range(4):   # boîtiers et bouches sombres
        o, ex, ey, ez = C.repere(rnd.f(x0, x1), rnd.f(5.0, 8.6), 0.09)
        Lx, Ly = rnd.f(0.14, 0.34), rnd.f(0.12, 0.26)
        if k % 2:
            F.grille(lot, M["acier"], M["noir"], o, ex, ey, ez, Lx * 1.3, Ly * 1.3, 4, 0.04)
        else:
            lot.put(M["acier"], F.local(G.boite((0, 0, 0.05), (Lx, Ly, 0.1), rz=rnd.f(-0.4, 0.4)), o, ex, ey, ez))
            lot.put(M["bague"], F.local(G.boite((0, 0, 0.105), (Lx * 0.5, Ly * 0.4, 0.016), rz=rnd.f(-0.4, 0.4)), o, ex, ey, ez))


# ------------------------------------------------------------------------------------------------ pièces
def nacelle(lot, M, rnd, cy, cz, r=0.5, x_av=-1.25, x_ar=-3.75, chev=False):
    """Tuyère : capot, entrée d'air à grille, tôles, bagues, cloche brûlée (intérieur noir)."""
    def surf(x, a, g=0.0):
        rr = R(x) + g
        return (x, cy + rr * math.cos(a), cz + rr * math.sin(a))

    def R(x):
        if x > x_av - 0.65:
            f = (x - (x_av - 0.65)) / 0.65
            return r * (1.0 - 0.42 * f * f)
        return r
    prof = [(x_av, r * 0.55), (x_av - 0.3, r * 0.86), (x_av - 0.65, r), (x_ar + 0.42, r), (x_ar + 0.2, r * 1.02),
            (x_ar, r * 1.1)]
    lot.put(M["noyau"], G.tour([(p[0], p[1] - 0.012) for p in prof], 28, "x", (0.0, cy, cz)))
    xs = [x_av - 0.62, x_av - 1.05, x_av - 1.5, x_av - 1.95, x_ar + 0.42]
    for i in range(len(xs) - 1):
        a = rnd.f(0, 1.0)
        a_fin = a + G.TAU - 0.2
        while a < a_fin:
            w = rnd.f(0.7, 1.3)
            mesh, P = F.plaque(surf, xs[i] - 0.012, xs[i + 1] + 0.012, a + 0.03, a + w - 0.03, 0.0, rnd.f(0.015, 0.04),
                               (rnd.f(-0.06, 0.06), rnd.f(-0.06, 0.06)))
            m = M["chevron"] if chev and i == 0 else [M["j0"], M["j1"], M["j2"], M["j3"], M["primaire"]][int(rnd.f(0, 4.4))]
            lot.put(m, mesh)
            lot.put(M["riv"], F.rivets_bord(P, 0.03, 4, 0.022, 0.0))
            a += w
    for x in (x_av - 0.62, x_ar + 0.42, x_ar + 0.1):
        rr = R(x) + 0.05
        lot.put(M["bague"], G.tour([(x + 0.05, rr - 0.03), (x + 0.04, rr), (x - 0.04, rr), (x - 0.05, rr - 0.03)], 28,
                                   "x", (0.0, cy, cz)))
    # cloche : lèvre et intérieur brûlé
    lot.put(M["nu"], G.tour([(x_ar + 0.1, r * 1.11), (x_ar + 0.02, r * 1.13), (x_ar - 0.04, r * 1.14), (x_ar - 0.04, r * 0.96)], 28, "x",
                            (0.0, cy, cz)))
    lot.put(M["brule"], G.tour([(x_ar - 0.03, r * 0.98), (x_ar + 0.2, r * 0.85), (x_ar + 0.45, r * 0.55),
                                (x_ar + 0.55, 0.0)], 28, "x", (0.0, cy, cz)))
    for k in range(3):   # anneaux de la tuyère (relief sombre)
        xx = x_ar + 0.08 + 0.12 * k
        rr = r * (0.94 - 0.13 * k)
        lot.put(M["nu"], G.tour([(xx - 0.02, rr), (xx + 0.03, rr - 0.045)], 24, "x", (0.0, cy, cz)))
    for k in range(12):     # aubes dans la gorge
        a = G.TAU * k / 12.0
        for (rr0, rr1, xa, xb) in ((r * 0.34, r * 0.62, x_ar + 0.42, x_ar + 0.24),):
            lot.put(M["acier"], G.tube([(xa, cy + rr0 * math.cos(a), cz + rr0 * math.sin(a)), (xb, cy + rr1 * math.cos(a + 0.2), cz + rr1 * math.sin(a + 0.2))], 0.016, 4))
    # entrée d'air : grille radiale
    lot.put(M["brule"], G.tour([(x_av + 0.01, r * 0.5), (x_av + 0.01, 0.0)], 20, "x", (0.0, cy, cz)))
    for k in range(9):
        a = G.TAU * k / 9.0
        p0 = (x_av + 0.03, cy + 0.08 * math.cos(a), cz + 0.08 * math.sin(a))
        p1 = (x_av + 0.03, cy + r * 0.52 * math.cos(a), cz + r * 0.52 * math.sin(a))
        lot.put(M["acier"], G.tube([p0, p1], 0.018, 4))
    return surf


def aile_panneau(lot, M, rnd, A, B, B1, A1, ep=0.055, chev=True, casse=False):
    """Panneau d'aile : âme sombre, 2 à 3 tôles inégales par-dessus, bord d'attaque à chevrons, rivets."""
    if G.cross(G.sub(B, A), G.sub(A1, A))[2] < 0:     # tôles toujours du côté du ciel (repère local)
        A, B, B1, A1 = B, A, A1, B1
    lot.put(M["noyau"], F.dalle([A, B, B1, A1], ep))
    n = G.norm(G.cross(G.sub(B, A), G.sub(A1, A)))
    cuts = sorted([0.0, rnd.f(0.3, 0.45), rnd.f(0.6, 0.75), 1.0])
    for i in range(3):
        f0, f1 = cuts[i] + 0.012, cuts[i + 1] - 0.012
        a0, b0 = G.lerp(A, A1, f0), G.lerp(B, B1, f0)
        a1, b1 = G.lerp(A, A1, f1), G.lerp(B, B1, f1)
        q = [G.add(p, G.mul(n, ep)) for p in (G.lerp(a0, b0, 0.03), G.lerp(a0, b0, 0.97), G.lerp(a1, b1, 0.97),
                                              G.lerp(a1, b1, 0.03))]
        lot.put([M["j0"], M["j1"], M["j2"], M["j3"]][int(rnd.f(0, 3.99))], F.dalle(q, rnd.f(0.015, 0.03)))
        pts = [(G.add(G.lerp(q[0], q[1], (k + 0.5) / 7.0), G.mul(n, 0.03)), n) for k in range(7)]
        lot.put(M["riv"], G.rivets_le_long(pts, 0.022, 0.013))
    if chev:
        lot.put(M["chevron"], G.tube([G.add(B, G.mul(n, ep / 2)), G.add(B1, G.mul(n, ep / 2))], 0.04, 6))
    if casse:   # bout déchiré
        for k in range(3):
            a = G.lerp(A1, B1, k / 3.0)
            b = G.lerp(A1, B1, (k + 1) / 3.0)
            d = G.norm(G.sub(A1, A))
            c = G.add(G.lerp(a, b, rnd.f(0.3, 0.7)), G.add(G.mul(d, rnd.f(0.1, 0.22)), G.mul(n, rnd.f(-0.05, 0.08))))
            lot.put([M["j1"], M["roussi"], M["nu"]][k], F.eclat(a, b, c, 0.02))


def hublot(lot, M, C, x, t, forme, lum):
    o, ex, ey, ez = C.repere(x, t, 0.03)
    if forme == "rond":
        lot.put(M["bague"], F.local(G.tour([(0.0, 0.1), (0.035, 0.1), (0.035, 0.07), (0.01, 0.065)], 18, "z"), o, ex, ey, ez))
        lot.put(lum, F.local(G.tour([(0.012, 0.068), (0.012, 0.0)], 18, "z"), o, ex, ey, ez))
        for k in range(6):
            a = G.TAU * k / 6
            lot.put(M["riv"], F.local(G.sphere((0.085 * math.cos(a), 0.085 * math.sin(a), 0.036), 0.012, 6, 3), o, ex, ey, ez))
    elif forme == "carre":
        lot.put(M["bague"], F.local(G.boite((0.0, 0.0, 0.02), (0.24, 0.15, 0.04)), o, ex, ey, ez))
        lot.put(lum, F.local(G.boite((0.0, 0.0, 0.042), (0.18, 0.095, 0.006)), o, ex, ey, ez))
        lot.put(M["acier"], F.local(G.boite((0.0, 0.0, 0.047), (0.012, 0.1, 0.008)), o, ex, ey, ez))
    else:  # fente basse en trapèze, cassée
        lot.put(M["bague"], F.local(G.prisme([(-0.13, -0.04), (0.13, -0.04), (0.09, 0.05), (-0.09, 0.05)], 0.0, 0.035), o, ex, ey, ez))
        lot.put(lum, F.local(G.prisme([(-0.1, -0.025), (0.0, -0.025), (-0.02, 0.035), (-0.07, 0.035)], 0.035, 0.04), o, ex, ey, ez))
        lot.put(M["noir"], F.local(G.prisme([(0.0, -0.025), (0.1, -0.025), (0.07, 0.035), (-0.02, 0.035)], 0.03, 0.036), o, ex, ey, ez))


def antenne(lot, M, C, x, t, h, coude, rnd, plat=False):
    o, ex, ey, ez = C.repere(x, t, 0.02)
    p1 = G.add(o, G.mul(ez, h * 0.6))
    p2 = G.add(p1, G.add(G.mul(ez, h * 0.25), G.mul(ex, -coude)))
    p3 = G.add(p2, G.add(G.mul(ez, h * 0.1), G.mul(ex, -coude * 0.8)))
    lot.put(M["acier"], F.local(G.tour([(0.0, 0.07), (0.06, 0.06), (0.08, 0.0)], 10, "z", cap0=True), o, ex, ey, ez))
    lot.put(M["bague"], G.tube([o, p1, p2, p3], 0.018, 6))
    for k in (0.3, 0.55):
        lot.put(M["acier"], G.tube([G.lerp(o, p1, k - 0.04), G.lerp(o, p1, k + 0.04)], 0.03, 6))
    if plat:   # parabole (capteur)
        d = G.norm(G.sub(p3, p2))
        lot.put(M["bague"], F.local(G.tour([(0.0, 0.0), (0.03, 0.09), (0.07, 0.16), (0.075, 0.165)], 16, "z", cap0=False),
                                    p3, *_rep(d)))
        lot.put(M["acier"], G.tube([p3, G.add(p3, G.mul(d, 0.14))], 0.01, 4))
    lot.put(M["voyant"], G.sphere(p3, 0.026, 8, 4))


def _rep(d):
    ref = (1.0, 0.0, 0.0) if abs(d[0]) < 0.9 else (0.0, 1.0, 0.0)
    e1 = G.norm(G.cross(ref, d))
    return e1, G.cross(d, e1), d


def caisson(lot, M, p, s, rz, rnd, voyant=False):
    lot.put(M["acier"], G.boite(p, s, rz))
    lot.put(M["primaire"], G.boite(G.add(p, (0, 0, s[2] / 2 + 0.01)), (s[0] * 0.8, s[1] * 0.8, 0.02), rz))
    if voyant:
        lot.put(M["voyant"], G.sphere(G.add(p, (s[0] * 0.3, -s[1] / 2 - 0.005, s[2] * 0.25)), 0.022, 6, 3))


def machinerie(lot, M, rnd, xr, yr, zr, n):
    """Machinerie sombre vue par la brèche : blocs, réservoirs, conduits verticaux, boîtes à voyant (profondeur)."""
    for k in range(n):
        x, y, z = rnd.f(*xr), rnd.f(*yr), rnd.f(*zr)
        u = rnd.f()
        if u < 0.45:
            s = (rnd.f(0.12, 0.3), rnd.f(0.1, 0.26), rnd.f(0.1, 0.3))
            lot.put(M["acier"] if k % 3 else M["noyau"], G.boite((x, y, z), s, rnd.f(-0.5, 0.5)))
            lot.put(M["bague"], G.boite((x, y, z + s[2] / 2 + 0.008), (s[0] * 0.5, s[1] * 0.35, 0.016), rnd.f(-0.5, 0.5)))
        elif u < 0.7:
            r = rnd.f(0.05, 0.1)
            lot.put([M["primaire"], M["cuivre"], M["acier"]][k % 3],
                    G.tour([(0.0, r), (rnd.f(0.2, 0.4), r), (rnd.f(0.42, 0.46), r * 0.5)], 12, "z", (x, y, z - 0.1),
                           cap0=True, cap1=True))
        elif u < 0.88:
            lot.put(M["acier"], G.tube([(x, y, z - 0.25), (x, y, z + 0.3), (x + rnd.f(-0.2, 0.2), y + 0.15, z + 0.38)],
                                       rnd.f(0.018, 0.035), 6))
        else:
            caisson(lot, M, (x, y, z), (0.16, 0.14, 0.18), rnd.f(0, 1), rnd, voyant=(k % 2 == 0))


# ------------------------------------------------------------------------------------------------ état
def build(S, lot):
    M = matieres(S)
    r = G.Rnd(2030)
    ra = G.Rnd(2031)
    jaunes = [M["j0"], M["j1"], M["j2"], M["j3"]]

    def choix(rr, x, t, patch=False, roussi_x=None, chev_x=None):
        u = rr.f()
        if chev_x is not None and x > chev_x:
            return M["chevron"]
        if roussi_x and roussi_x(x, t) and u < 0.45:
            return M["roussi"]
        if patch:
            return [M["primaire"], M["rouille"], M["nu"], M["j3"]][int(rr.f(0, 3.99))]
        if u < 0.04:
            return M["primaire"]
        if u < 0.07:
            return M["rouille"]
        if u < 0.16:
            return M["j3"]
        return M["j0"] if u < 0.62 else (M["j2"] if u < 0.86 else M["j1"])

    # ================================================================ TRONÇON ARRIÈRE (propulsion)
    AR = F.Coque(_st([(-3.3, 0.8, 0.7, 0.58, 0.0, 0.0), (-2.9, 0.88, 0.8, 0.64, 0.0, 0.04), (-2.45, 0.95, 0.88, 0.7, 0.0, 0.06),
                  (-2.0, 1.0, 0.94, 0.72, 0.0, 0.08), (-1.55, 1.03, 0.95, 0.72, 0.0, 0.08),
                  (-1.1, 1.0, 0.92, 0.72, 0.0, 0.07), (-0.65, 0.98, 0.9, 0.72, 0.0, 0.06), (0.0, 0.96, 0.88, 0.72, 0.0, 0.05)]))

    def lim_ar(t):
        return -1.05 + 0.2 * math.sin(t * 2.7) + 0.1 * math.sin(t * 5.3 + 1.0)

    def ouvert_ar(x, t):
        t %= 12
        return 5.2 < t < 9.8 and x > lim_ar(t)

    def trou_ar(x, t):     # impact sur le dos : tôles arrachées, noyau visible
        return -2.15 < x < -1.45 and 2.0 < t < 3.3

    pose_ar = F.pose(roulis=ESSAI["roul_ar"], tangage=ESSAI["tang_ar"], lacet=ESSAI["lacet_ar"], t=(-0.58, 0.36, 0.8))
    lot.xf = pose_ar
    xs_ar = [-3.3, -2.5, -1.72, -1.08, -0.5, 0.0]
    noyau(lot, M["noyau"], AR, -3.3, 0.0, ouvert_ar)
    lot.put(M["noyau"], G.loft([[AR(-3.3, k * 0.5, -0.012) for k in range(24)]], cap0=True))  # culot
    toles(lot, M, AR, xs_ar, r, ouvert_ar, lambda rr, x, t, patch=False: choix(
        rr, x, t, patch, roussi_x=lambda x, t: x > -1.6 and 4.5 < t < 10.5), trou_ar)
    bords_dechires(lot, M, AR, xs_ar, ra, ouvert_ar, 1.0)
    epine(lot, M, AR, -3.1, -0.15, r, saut=lambda x: -2.15 < x < -1.45)
    # côtes à nu dans la brèche, balayées vers la queue ; cadre de rupture
    for x, tb in ((-0.9, 10.1), (-0.58, 9.3), (-0.26, 10.1)):
        lot.put(M["acier"], F.cote(AR, x, 4.9, tb, 0.3, r=0.042))
    lot.put(M["bague"], F.cote(AR, -0.03, -2.0, 5.3, 0.12, r=0.05, n=30))
    # dans l'impact du dos : couples et câbles
    for x in (-2.0, -1.62):
        lot.put(M["acier"], F.cote(AR, x, 2.0, 3.3, 0.12, r=0.03, g=0.0))
    # pont intérieur, machines, bouteilles
    lot.put(M["acier"], G.boite((-0.55, -0.05, -0.36), (1.1, 1.35, 0.04)))
    caisson(lot, M, (-0.75, -0.35, -0.22), (0.3, 0.26, 0.26), 0.2, r, voyant=True)
    caisson(lot, M, (-0.35, 0.3, -0.2), (0.26, 0.34, 0.3), -0.1, r)
    for k, (y, z) in enumerate(((-0.5, -0.25), (-0.25, -0.27))):
        lot.put(M["primaire"] if k else M["cuivre"], G.tour([(0.0, 0.07), (0.32, 0.07), (0.36, 0.035)], 12, "x",
                                                           (-0.42 + 0.06 * k, y, z), cap0=True, cap1=True))
    F.tuyau(lot, M["acier"], M["bague"], [(-1.2, 0.55, 0.35), (-0.6, 0.62, 0.32), (-0.3, 0.55, 0.05), (-0.1, 0.4, -0.25)],
            0.05)
    # tuyères (deux grosses, à gauche)
    sn = nacelle(lot, M, r, 1.12, -0.12, 0.62, chev=True)
    ss = nacelle(lot, M, r, -1.12, -0.05, 0.6)
    # tuyaux à brides le long du flanc sud (3 diamètres)
    F.tuyau(lot, M["acier"], M["bague"], [AR(-3.0, 7.0, 0.02), AR(-2.85, 7.0, 0.12), AR(-1.55, 7.25, 0.12),
                                           AR(-1.3, 7.25, 0.03)], 0.034)
    F.tuyau(lot, M["cuivre"], M["bague"], [AR(-2.75, 7.75, 0.02), AR(-2.62, 7.75, 0.14), AR(-1.25, 7.85, 0.14),
                                            G.add(AR(-1.0, 7.9, 0.14), (0.05, -0.12, -0.25))], 0.05)
    F.tuyau(lot, M["acier"], M["bague"], [(-1.75, -1.32, -0.28), (-1.3, -1.25, -0.42), (-0.9, -0.95, -0.45),
                                          (-0.55, -0.55, -0.38)], 0.085)
    # bosse dorsale (caisson d'équipement) et caisson latéral : des masses qui dépassent du fuseau
    for (x, t, L, W, Hh, m) in ((-1.25, 4.1, 1.55, 0.95, 0.42, "j2"), (-2.45, 8.5, 0.8, 0.38, 0.24, "j0")):
        o, ex, ey, ez = AR.repere(x, t, 0.03)
        poly = [(-L / 2, -W / 2), (L / 2, -W / 2), (L / 2, W / 2), (-L / 2, W / 2)]
        lot.put(M["primaire"], F.local(G.prisme(poly, 0.0, Hh * 0.45, top_scale=0.95), o, ex, ey, ez))
        lot.put(M[m], F.local(G.prisme([(p[0] * 0.95, p[1] * 0.95) for p in poly], Hh * 0.42, Hh, top_scale=0.62), o, ex, ey, ez))
        oo = G.add(o, G.mul(ez, Hh + 0.005))
        F.grille(lot, M["acier"], M["noir"], oo, ex, ey, ez, L * 0.45, W * 0.5, 4, 0.04)
        lot.put(M["riv"], G.rivets_le_long([(G.add(oo, G.add(G.mul(ex, L * (0.25 + 0.06 * q)), G.mul(ey, -W * 0.3))), ez)
                                            for q in range(4)], 0.026, 0.015))
    # évents
    for (x, t, L, H, n) in ((-2.45, 6.45, 0.44, 0.28, 6), (-1.75, 8.25, 0.36, 0.22, 5), (-2.75, 2.4, 0.34, 0.26, 5)):
        o, ex, ey, ez = AR.repere(x, t, 0.05)
        F.grille(lot, M["acier"], M["noir"], o, ex, ey, ez, L, H, n)
    hublot(lot, M, AR, -2.0, 6.7, "fente", M["hublot_r"])
    # dérive dressée, grande (silhouette : elle MONTE au-dessus de l'emprise), peau jaune côté caméra, bout déchiré,
    # brûlure rouge à l'emplanture (foyer, comme l'épave vanilla)
    z0 = AR(-2.4, 3.5)[2] - 0.02
    Ad, Bd, B1d, A1d = (-3.2, -0.04, z0), (-1.4, -0.04, z0), (-2.85, -0.04, z0 + 2.45), (-3.75, -0.04, z0 + 2.3)
    aile_panneau(lot, M, r, Ad, Bd, B1d, A1d, ep=0.07, casse=True)
    lot.put(M["chevron"], G.tube([G.add(Bd, (0, -0.05, 0)), G.add(B1d, (0, -0.05, 0))], 0.06, 6))
    F.membrure(lot, M["nu"], [(-2.9, -0.12, z0 + 0.5), (-2.6, -0.2, z0 + 1.0), (-2.75, -0.3, z0 + 1.5)], 0.016, 0.05)
    lot.put(M["voyant"], G.sphere((-3.1, -0.05, z0 + 2.32), 0.04, 8, 4))
    lot.put(M["coeur"], G.boite((-2.25, -0.13, z0 + 0.22), (0.5, 0.02, 0.2), 0.0))
    for k in range(4):
        lot.put(M["acier"], G.boite((-2.45 + k * 0.13, -0.16, z0 + 0.22), (0.035, 0.03, 0.26)))
    machinerie(lot, M, G.Rnd(2041), (-1.0, -0.05), (-0.85, 0.55), (-0.62, 0.3), 14)
    # aile nord repliée vers le haut, bout cassé
    A, B = AR(-2.75, 0.7, 0.0), AR(-0.75, 0.7, 0.0)
    d1 = (0.0, math.cos(0.45), math.sin(0.45))
    A1 = G.add(A, G.add((-0.45, 0, 0), G.mul(d1, 1.15)))
    B1 = G.add(B, G.add((-0.95, 0, 0), G.mul(d1, 1.15)))
    aile_panneau(lot, M, r, A, B, B1, A1)
    d2 = (0.0, math.cos(1.2), math.sin(1.2))
    A2 = G.add(A1, G.add((-0.3, 0, 0), G.mul(d2, 1.1)))
    B2 = G.add(B1, G.add((-0.7, 0, 0), G.mul(d2, 1.1)))
    aile_panneau(lot, M, r, A1, B1, B2, A2, casse=True)
    lot.put(M["bague"], G.tube([G.lerp(A1, B1, 0.1), G.lerp(A1, B1, 0.9)], 0.05, 8))    # charnière du pli
    # moignon de l'aile sud : bord arraché, longeron qui dépasse, câbles pendants
    A, B = AR(-2.25, 6.55, 0.0), AR(-1.35, 6.55, 0.0)
    d = (0.0, -math.cos(0.3), math.sin(0.3))
    A1, B1 = G.add(A, G.mul(d, 0.62)), G.add(B, G.add((-0.25, 0, 0), G.mul(d, 0.78)))
    aile_panneau(lot, M, r, A, B, B1, A1, chev=False, casse=True)
    lot.put(M["acier"], G.tube([G.lerp(A, B, 0.5), G.add(G.lerp(A1, B1, 0.5), G.mul(d, 0.32))], 0.035, 6))
    F.faisceau(lot, [M["rouge"], M["noir"], M["noir"]], G.lerp(A1, B1, 0.3), G.add(G.lerp(A1, B1, 0.3), (0.2, -0.35, -0.7)),
               0.15, 0.014, 3, 0.03, r)
    surcouche(lot, M, AR, -3.0, -1.15, r, jaunes)
    # mât et capteur sur le dos (antenne 1), flexible tuyère nord -> coque
    antenne(lot, M, AR, -0.85, 2.5, 0.62, 0.18, r, plat=True)
    F.flexible(lot, M["gaine"], [(-1.6, 1.3, 0.1), (-1.35, 1.2, 0.45), (-1.05, 0.95, 0.72)], 0.04)

    # ================================================================ TRONÇON AVANT (crâne)
    AV = F.Coque(_st([(0.0, 0.96, 0.88, 0.72, 0.0, 0.05), (0.5, 1.0, 0.94, 0.72, 0.0, 0.06), (1.0, 0.99, 1.02, 0.7, 0.0, 0.04),
                  (1.5, 0.93, 1.06, 0.66, 0.0, 0.02), (2.0, 0.83, 0.98, 0.6, -0.03, 0.03), (2.5, 0.68, 0.8, 0.5, -0.07, 0.04),
                  (2.9, 0.52, 0.62, 0.4, -0.12, 0.04), (3.25, 0.34, 0.42, 0.3, -0.16, 0.03), (3.5, 0.19, 0.25, 0.19, -0.2, 0.02),
                  (3.68, 0.05, 0.07, 0.06, -0.22, 0.0)]))

    def lim_av(t):
        return 0.78 + 0.16 * math.sin(t * 2.9) + 0.08 * math.sin(t * 6.1 + 2.0)

    def ouvert_av(x, t):
        t %= 12
        return (4.6 < t < 9.8 and x < lim_av(t)) or (3.3 < t < 4.6 and x < 0.35)

    def verriere(x, t):
        return 1.0 < x < 2.35 and 1.9 < t < 5.1

    pose_av = F.pose(roulis=ESSAI["roul_av"], tangage=0.12, lacet=-0.11, t=(0.52, 0.12, 0.92))
    lot.xf = pose_av
    xs_av = [0.0, 0.62, 1.32, 2.1, 2.72, 3.24, 3.68]
    noyau(lot, M["noyau"], AV, 0.0, 3.68, ouvert_av)
    toles(lot, M, AV, xs_av, r, ouvert_av, lambda rr, x, t, patch=False: choix(
        rr, x, t, patch, roussi_x=lambda x, t: x < 1.1 and 4.0 < t < 10.5, chev_x=2.88), verriere)
    bords_dechires(lot, M, AV, xs_av, ra, ouvert_av, -1.0)
    epine(lot, M, AV, 0.45, 1.0, r)
    epine(lot, M, AV, 2.35, 3.2, r)
    for x, tb in ((0.3, 9.8), (0.62, 8.9)):
        lot.put(M["acier"], F.cote(AV, x, 4.4, tb, 0.3, r=0.042))
    lot.put(M["bague"], F.cote(AV, 0.03, -2.0, 4.6, 0.12, r=0.05, n=30))
    surcouche(lot, M, AV, 0.9, 3.1, G.Rnd(2052), jaunes)
    # verrière : vitres inégales (aucune rangée régulière), cadres lourds, une vitre cassée
    rangs = (((2.0, 3.0), (1.12, 1.6, 2.2)), ((3.0, 4.0), (1.05, 1.42, 1.86, 2.3)), ((4.0, 5.0), (1.15, 1.72, 2.22)))
    for (ta, tb), cuts in rangs:
        for i in range(len(cuts) - 1):
            casse = (ta, i) == (3.0, 1)
            mesh, P = F.plaque(AV, cuts[i] + 0.02, cuts[i + 1] - 0.02, ta + 0.04, tb - 0.04, 0.0, 0.05, (0.06, -0.04))
            if not casse:
                lot.put(M["verre"], mesh)
            lot.put(M["bague"], G.tube([AV(cuts[i], ta, 0.06), AV(cuts[i] + 0.06, tb, 0.06)], 0.026, 4))
        lot.put(M["bague"], G.tube([AV(cuts[0], ta, 0.065), AV(cuts[-1], ta, 0.065)], 0.03, 4))
    lot.put(M["bague"], G.tube([AV(1.05, 5.0, 0.065), AV(2.25, 5.0, 0.065)], 0.03, 4))
    for k in range(5):
        lot.put(M["riv"], G.sphere(AV(1.2 + 0.22 * k, 1.95, 0.07), 0.02, 6, 3))
    # hublots tous différents (2 éclairés faiblement, 1 mort), canards, antenne 2, évent, voyants
    hublot(lot, M, AV, 1.32, 6.2, "carre", M["hublot_a"])
    o, ex, ey, ez = AV.repere(0.95, 6.55, 0.06)     # sas ouvert, éclairé de l'intérieur : foyer lisible au zoom 1
    lot.put(M["bague"], F.local(G.boite((0, 0, 0.02), (0.52, 0.36, 0.04)), o, ex, ey, ez))
    lot.put(M["hublot_a"], F.local(G.boite((0, 0, 0.043), (0.44, 0.28, 0.006)), o, ex, ey, ez))
    lot.put(M["acier"], F.local(G.boite((0.04, 0, 0.05), (0.03, 0.24, 0.01)), o, ex, ey, ez))
    hublot(lot, M, AV, 1.85, 6.35, "carre", M["hublot_r"])
    hublot(lot, M, AV, 2.45, 6.1, "rond", M["noir"])
    o, ex, ey, ez = AV.repere(2.05, 7.35, 0.05)
    F.grille(lot, M["acier"], M["noir"], o, ex, ey, ez, 0.36, 0.2, 5)
    for tt, L, cas in ((0.35, 1.35, False), (6.7, 0.75, True)):
        A, B = AV(2.3, tt, 0.0), AV(2.85, tt, 0.0)
        nn = AV.n(2.55, tt)
        dd = G.norm(G.add(nn, (0, 0, -0.3)))
        A1, B1 = G.add(A, G.add((-0.25, 0, 0), G.mul(dd, L))), G.add(B, G.add((-0.38, 0, 0), G.mul(dd, L)))
        aile_panneau(lot, M, r, A, B, B1, A1, ep=0.045, casse=cas)
    antenne(lot, M, AV, 0.62, 2.8, 0.55, 0.3, r)
    lot.put(M["voyant"], G.sphere(AV(2.95, 5.6, 0.06), 0.03, 8, 4))
    # intérieur avant : console aux voyants, pont
    lot.put(M["acier"], G.boite((0.4, 0.0, -0.38), (0.8, 1.3, 0.04)))
    machinerie(lot, M, G.Rnd(2042), (0.08, 0.75), (-0.85, 0.5), (-0.62, 0.25), 10)
    caisson(lot, M, (0.42, -0.3, -0.22), (0.34, 0.24, 0.26), 0.15, r, voyant=True)
    F.tuyau(lot, M["acier"], M["bague"], [(0.05, 0.5, 0.4), (0.6, 0.55, 0.45), (0.95, 0.4, 0.2)], 0.034)

    # ================================================================ LE CŒUR (entre les tronçons)
    lot.xf = F.pose()
    CO = (0.0, -0.5, 0.58)
    lot.put(M["coeur"], G.sphere(CO, 0.29, 16, 8))
    for (axe, ang, a0, a1, rr) in (("x", 0.0, 3.3, 7.7, 0.4), ("y", 0.4, 2.5, 6.9, 0.43), ("z", 0.0, 0.3, 4.0, 0.39)):
        pts = []
        for k in range(25):
            a = a0 + (a1 - a0) * k / 24.0
            u, v = rr * math.cos(a), rr * math.sin(a)
            p = {"x": (0.0, u, v), "y": (u, 0.0, v), "z": (u, v, 0.0)}[axe]
            p = G.rot_z(p, ang)
            pts.append(G.add(CO, p))
        lot.put(M["bague"], G.tube(pts, 0.04, 8))
    for k in range(6):   # barreaux de la cage, dont deux tordus
        a = G.TAU * k / 6.0 + 0.3
        top = G.add(CO, (0.3 * math.cos(a), 0.3 * math.sin(a), 0.32))
        bot = G.add(CO, (0.33 * math.cos(a), 0.33 * math.sin(a), -0.38))
        mid = G.add(G.lerp(top, bot, 0.5), (0.12 * math.cos(a), 0.12 * math.sin(a), 0.0))
        if math.sin(a) < -0.2:     # côté caméra : barreaux arrachés (le cœur doit se voir)
            lot.put(M["acier"], G.tube([bot, G.lerp(bot, mid, 0.5)], 0.025, 5))
            continue
        if k in (1, 2):
            top = G.add(mid, (0.25 * math.cos(a + 0.8), 0.25 * math.sin(a + 0.8), 0.2))
        lot.put(M["acier"], G.tube([bot, mid, top], 0.025, 5))
    for (dx, dy, rz) in ((-0.22, 0.0, 0.2), (0.24, 0.02, -0.1)):   # berceau
        lot.put(M["acier"], G.boite((CO[0] + dx, CO[1] + dy, 0.12), (0.14, 0.7, 0.24), rz))
    lot.put(M["roussi"], F.eclat(G.add(CO, (-0.32, -0.25, 0.2)), G.add(CO, (-0.1, -0.35, 0.3)), G.add(CO, (-0.4, -0.55, 0.55)), 0.025))
    lot.put(M["brule"], F.eclat(G.add(CO, (0.15, -0.3, 0.25)), G.add(CO, (0.35, -0.2, 0.15)), G.add(CO, (0.45, -0.55, 0.45)), 0.025))
    lumiere_coeur(G.add(CO, (0.0, -0.32, 0.18)))
    # flexibles, câbles et conduits arrachés entre les tronçons et vers le sol
    F.flexible(lot, M["gaine"], [G.add(CO, (0.0, -0.25, -0.15)), (0.15, -0.9, 0.3), (0.4, -1.32, 0.06), (0.85, -1.6, 0.04)], 0.05)
    F.flexible(lot, M["gaine"], [G.add(CO, (-0.2, -0.25, -0.25)), (-0.42, -0.95, 0.12), (-0.85, -1.22, 0.05), (-1.35, -1.32, 0.04)], 0.04)
    F.flexible(lot, M["gaine"], [pose_ar((-0.12, -0.3, -0.25)), G.add(CO, (0.0, 0.1, -0.42)), pose_av((0.12, -0.25, -0.3))], 0.045)
    F.flexible(lot, M["gaine"], [pose_av((0.06, -0.7, -0.05)), (0.5, -1.15, 0.18), (0.62, -1.42, 0.04), (1.25, -1.55, 0.04)], 0.035)
    F.faisceau(lot, [M["rouge"], M["noir"]], pose_ar((-0.05, -0.55, 0.25)), (-0.8, -1.5, 0.03), 0.12, 0.015, 4, 0.03, r)
    F.faisceau(lot, [M["noir"], M["rouge"], M["noir"]], pose_ar((-0.05, 0.25, 0.7)), pose_av((0.05, 0.15, 0.7)), 0.3, 0.014, 3, 0.035, r)
    F.faisceau(lot, [M["rouge"], M["rouge"], M["noir"]], pose_av((0.1, -0.55, 0.25)), G.add(CO, (0.25, 0.0, 0.25)), 0.1, 0.013, 3, 0.03, r)
    F.tuyau(lot, M["acier"], M["bague"], [pose_av((0.15, 0.35, -0.3)), G.add(CO, (0.3, 0.25, -0.2)), G.add(CO, (0.05, 0.15, -0.35))], 0.06)

    # membrures tordues qui sortent des cassures, treillis rompu en travers de la brèche, voyants de secours
    for (a, b, c, m) in ((pose_ar((0.0, -0.6, 0.55)), (-0.5, -0.9, 1.35), (-0.78, -1.0, 1.28), "nu"),
                         (pose_ar((0.0, 0.5, 0.75)), (0.25, 0.65, 1.45), (0.05, 0.9, 1.55), "j1"),
                         (pose_ar((-0.05, -0.85, -0.2)), (0.15, -1.25, 0.25), (0.35, -1.45, 0.12), "roussi"),
                         (pose_av((0.0, 0.7, 0.6)), (-0.35, 0.95, 1.4), (-0.2, 1.15, 1.6), "nu"),
                         (pose_av((0.0, -0.75, 0.45)), (0.2, -1.0, 1.1), (0.45, -1.1, 1.22), "j2"),
                         (pose_av((0.02, 0.1, 1.0)), (-0.2, 0.15, 1.75), (-0.5, 0.3, 1.85), "acier"),
                         (pose_av((0.05, -0.9, -0.3)), (-0.1, -1.4, 0.1), (-0.25, -1.75, 0.05), "roussi"),
                         (pose_ar((-0.4, -1.05, 0.25)), (-0.55, -1.55, 0.7), (-0.75, -1.7, 0.55), "acier")):
        F.membrure(lot, M[m], [a, b, c], 0.014, 0.04)
    F.treillis(lot, M["acier"], pose_ar((-0.1, 0.8, 0.75)), pose_av((0.1, 0.85, 0.7)), 0.22, 4, 0.016,
               haut=(0.0, 0.3, 1.0), casse=2)
    for p in (pose_ar((-0.7, -0.4, -0.18)), pose_av((0.45, -0.38, -0.2)), pose_ar((-1.9, -1.32, 0.15))):
        lot.put(M["voyant"], G.sphere(p, 0.025, 6, 3))

    # ================================================================ AU SOL : butte, sillon, aile arrachée, débris
    lot.xf = F.pose(zmin=0.002)
    for (c, rx, ry, h, m, n) in (((4.0, -0.45, 0.0), 0.72, 1.15, 0.48, "terre", 48), ((3.3, -1.55, 0.0), 0.6, 0.45, 0.22, "terre2", 18),
                                 ((-1.9, 1.55, 0.0), 2.1, 0.32, 0.16, "terre", 34), ((-1.3, -1.8, 0.0), 2.3, 0.3, 0.14, "terre2", 34),
                                 ((3.55, 0.75, 0.0), 0.55, 0.5, 0.25, "terre2", 18)):
        lot.put(M[m], F.tertre(c, rx, ry, h, r, na=max(28, n), nr=9))
    for i in range(22):
        x, y = (r.f(3.0, 4.5), r.f(-2.2, 1.2)) if i < 12 else (r.f(-3.8, 0.0), r.f(-2.4, 2.3))
        if abs(y) < 1.1 and x < 3.0:
            y = math.copysign(r.f(1.3, 2.4), y)
        rr = r.f(0.04, 0.11)
        lot.put(M["roc"] if i % 3 else M["terre2"], G.sphere((x, y, rr * 0.25), rr, 7, 4))
    choix_l = lambda rr, x, t, patch=False: choix(rr, x, t, patch)
    lambeau(lot, M, AV, 0.7, 1.75, -0.6, 2.2, F.pose(roulis=-1.25, tangage=0.0, lacet=0.5, t=(2.3, 1.45, 0.05), zmin=0.003),
            G.Rnd(77), choix_l)
    lambeau(lot, M, AR, -1.6, -0.6, 7.6, 10.4, F.pose(roulis=2.3, tangage=0.1, lacet=0.3, t=(-0.75, -2.55, -0.1), zmin=0.003),
            G.Rnd(78), choix_l)
    for (c, rx, ry, h, m, n) in (((2.55, 2.05, 0.0), 1.25, 0.5, 0.22, "terre", 26), ((0.6, -2.35, 0.0), 1.3, 0.4, 0.13, "terre2", 24)):
        lot.put(M[m], F.tertre(c, rx, ry, h, r, na=max(28, n), nr=9))
    # aile sud arrachée, au sol (un bord relevé), feu de bout d'aile
    def pose_aile(p):
        p = G.rot_x(p, 0.16)
        p = G.rot_z(p, 0.38)
        return (p[0] + 1.15, p[1] - 2.2, max(0.002, p[2] + 0.07))
    A, B, B1, A1 = (-0.7, 0.36, 0.0), (0.7, 0.36, 0.0), (0.25, -0.5, 0.0), (-0.85, -0.42, 0.0)
    lot.xf = pose_aile
    aile_panneau(lot, M, r, A, B, B1, A1, ep=0.05, casse=False)
    for k in range(4):   # emplanture déchirée
        a, b = G.lerp(A, B, k / 4.0), G.lerp(A, B, (k + 1) / 4.0)
        lot.put([M["j2"], M["roussi"], M["nu"], M["j1"]][k], F.eclat(a, b, G.add(G.lerp(a, b, 0.5), (r.f(-0.05, 0.05), r.f(0.08, 0.2), r.f(0.0, 0.08))), 0.02))
    for x in (-0.3, 0.25):
        lot.put(M["acier"], G.tube([(x, 0.2, 0.03), (x + 0.05, 0.55, 0.06)], 0.03, 6))
    lot.put(M["voyant"], G.sphere((0.25, -0.38, 0.06), 0.03, 8, 4))
    lot.xf = F.pose(zmin=0.002)
    # tôles arrachées (inégales, certaines appuyées sur la tranche)
    plaques = (((-2.6, -2.3), 0.4, "j0", 0.5), ((-0.4, -2.45), 0.32, "roussi", 0.0), ((2.35, -2.35), 0.3, "j2", 0.6),
               ((-3.45, 2.2), 0.36, "primaire", 0.0), ((2.1, 1.75), 0.42, "j1", 0.4), ((3.0, 2.25), 0.26, "j3", 0.0),
               ((-0.9, 2.45), 0.3, "j0", 0.7), ((0.85, 2.15), 0.24, "nu", 0.0), ((-3.6, -1.15), 0.28, "j2", 0.3))
    for (x, y), s, m, lev in plaques:
        n = r.i(5, 7)
        poly = [(s * (0.7 + 0.3 * r.f()) * math.cos(G.TAU * k / n), s * 0.7 * (0.7 + 0.3 * r.f()) * math.sin(G.TAU * k / n))
                for k in range(n)]
        rz, rx = r.f(0, 3.0), lev
        lot.put(M[m], F.poly_dalle(poly, 0.03), lambda p, x=x, y=y, rz=rz, rx=rx: (
            G.rot_z(G.rot_x(p, rx), rz)[0] + x, G.rot_z(G.rot_x(p, rx), rz)[1] + y,
            max(0.002, G.rot_z(G.rot_x(p, rx), rz)[2] + 0.02 + (s * 0.5 * math.sin(rx) if rx else 0.0))))
        if not rx:
            lot.put(M["riv"], G.rivets_le_long([((x + s * 0.45 * math.cos(rz + 0.35 * k), y + s * 0.3 * math.sin(rz + 0.35 * k),
                                                  0.05), (0, 0, 1)) for k in range(4)], 0.022, 0.012))
    # tronçon de côte, anneau de tuyère cassé, conduit à brides, fûts, caisse, parabole tombée
    lot.put(M["acier"], G.tube([(-2.2 + 0.5 * math.cos(a), -2.55 + 0.25 * math.sin(a), 0.05 + 0.25 * math.sin(a) ** 2)
                                for a in [k * 0.25 for k in range(9)]], 0.04, 5))
    lot.put(M["bague"], G.tube([(-3.35 + 0.36 * math.cos(a), -2.05 + 0.36 * math.sin(a) * 0.8, 0.05 + 0.14 * (1 + math.sin(a)))
                                for a in [k * 0.3 for k in range(17)]], 0.055, 8))
    F.tuyau(lot, M["acier"], M["bague"], [(2.0, 2.45, 0.08), (2.8, 2.6, 0.08), (3.05, 2.35, 0.08)], 0.07)
    for (x, y, rz) in ((-2.95, 1.85, 0.4), (-3.25, 1.6, 1.4)):
        lot.put(M["rouge"] if rz > 1 else M["primaire"], G.tour([(0.0, 0.09), (0.32, 0.09)], 12, "x", (0, 0, 0), cap0=True, cap1=True),
                lambda p, x=x, y=y, rz=rz: (G.rot_z(p, rz)[0] + x, G.rot_z(p, rz)[1] + y, p[2] + 0.09))
    caisson(lot, M, (3.15, -2.45, 0.13), (0.3, 0.26, 0.26), 0.6, r)
    lot.put(M["bague"], G.tour([(0.0, 0.0), (0.04, 0.12), (0.09, 0.22), (0.095, 0.225)], 16, "z", (0, 0, 0)),
            lambda p: G.add(G.rot_y(p, 1.2), (2.7, 1.55, 0.2)))
    F.faisceau(lot, [M["noir"], M["rouge"]], (-2.6, -2.0, 0.04), (-1.6, -2.45, 0.04), -0.04, 0.016, 2, 0.04, r)
    lot.xf = None
    return {"essai": dict(ESSAI)}
