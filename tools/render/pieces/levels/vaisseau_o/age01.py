"""ÂGE 1 : le vaisseau RÉPARÉ, encore un vaisseau (emprise 8×4, k = 1). Nez à droite.

Blindage jaune de l'épave vanilla (trois tons, patchwork), plaques de rapiéçage en acier gris, anneau de chevrons au
nez, verrière à cadre lourd, deux nacelles et leurs tuyères, ailes en V, canards, dérive ; posé sur 4 jambes.
Les réparations racontent l'âge 1 : échafaudage de bois autour du nez, chèvre et plaque neuve suspendue, échelle à la
porte, caisses, fûts, groupe électrogène câblé par la trappe du dos, lanternes.
"""
import math

import geo as G
import mat as MT
import vaisseau as V

JAUNES = ((0.5, 0.33, 0.03), (0.44, 0.285, 0.022), (0.56, 0.38, 0.045))


def matieres(S):
    M = {}
    for i, c in enumerate(JAUNES):
        M["jaune%d" % i] = MT.surface("o1_jaune%d" % i, c, rough=0.5, met=0.25, coulures=0.6, usure=0.75,
                                      nu=(0.4, 0.38, 0.35), crasse=0.65, pied=(0.3, 0.75, 0.55), graine=1 + i)
    M["rapiece"] = MT.surface("o1_rapiece", (0.2, 0.2, 0.19), rough=0.42, met=0.8, coulures=0.7, usure=0.6, crasse=0.55, graine=4)
    M["noyau"] = MT.surface("o1_noyau", (0.03, 0.029, 0.028), rough=0.55, met=0.7, usure=0.3, crasse=0.7, graine=5)
    M["acier"] = MT.surface("o1_acier", (0.07, 0.068, 0.065), rough=0.42, met=0.85, usure=0.8, nu=(0.36, 0.35, 0.33),
                            crasse=0.55, coulures=0.4, graine=6)
    M["acier_clair"] = MT.surface("o1_acier_clair", (0.24, 0.23, 0.21), rough=0.4, met=0.85, usure=0.4, crasse=0.4, graine=7)
    M["riv"] = MT.surface("o1_riv", (0.12, 0.095, 0.05), rough=0.6, met=0.3, usure=0.3, crasse=0.5, graine=15)
    M["bague"] = MT.surface("o1_bague", (0.15, 0.145, 0.135), rough=0.38, met=0.9, usure=0.7, nu=(0.45, 0.44, 0.42),
                            crasse=0.6, coulures=0.4, graine=14)
    M["chevron"] = MT.surface("o1_chevron", JAUNES[0], rough=0.5, met=0.25, bandes=(0.17, (0.016, 0.015, 0.014), 0.5),
                              usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.55, graine=8)
    M["brule"] = MT.surface("o1_brule", (0.025, 0.021, 0.02), rough=0.7, met=0.5, usure=0.0, crasse=0.7, graine=9)
    M["verre"] = MT.verre("o1_verre")
    M["noir"] = MT.surface("o1_noir", (0.018, 0.018, 0.018), rough=0.75, met=0.0, usure=0.2, crasse=0.3, graine=10)
    M["cuivre"] = MT.surface("o1_cuivre", (0.4, 0.17, 0.075), rough=0.4, met=0.9, usure=0.4, crasse=0.6, graine=11)
    M["bois"] = MT.surface("o1_bois", (0.19, 0.115, 0.06), rough=0.85, met=0.0, tole=(1.1, 0.13), joint=0.35, var=0.18,
                           usure=0.5, nu=(0.32, 0.22, 0.13), crasse=0.6, relief=0.3, graine=12)
    M["rouge"] = MT.surface("o1_rouge", (0.28, 0.02, 0.015), rough=0.55, met=0.0, usure=0.4, nu=(0.4, 0.3, 0.25), crasse=0.4, graine=13)
    M["lampe"] = MT.lumiere(S, "o1_lampe", (1.0, 0.69, 0.376), 7.0)
    M["voyant"] = MT.lumiere(S, "o1_voyant", (1.0, 0.12, 0.04), 9.0)
    return M


def build(S, lot):
    M = matieres(S)
    V.reglage(nac_x0=-0.35)
    r = G.Rnd(101)
    k = 1.0
    jaunes = [M["jaune0"], M["jaune1"], M["jaune2"]]

    def mats(rr, i, j, zone):
        x = rr.f()
        if zone == "coque" and i == 11:
            return M["chevron"]                      # anneau de chevrons au nez (repère de l'épave vanilla)
        if zone == "nacelle" and i == 0:
            return M["chevron"] if x < 0.5 else jaunes[0]
        if x < 0.05:
            return M["rapiece"]
        return jaunes[int(rr.f() * 3) % 3]

    def saut(xm, am):
        return 1.15 < xm < 2.5 and abs(am - math.pi / 2) < 0.95          # place de la verrière

    V.corps(lot, k, r, M["noyau"], M["bague"], M["brule"], M["riv"], mats, saut=saut)
    sc = V.surf_coque(k)
    V.doublures(lot, sc, 9, lambda rr: M["rapiece"] if rr.f() < 0.25 else jaunes[int(rr.f() * 3) % 3], r,
                (-2.3, 1.0), (1.75, 3.6), M["riv"])
    V.doublures(lot, sc, 4, lambda rr: jaunes[int(rr.f() * 3) % 3], r, (-1.5, 0.9), (0.6, 1.5), M["riv"])
    for a in (math.pi - 0.62, math.pi / 2 + 0.38, math.pi / 2 - 0.38):
        V.lisse(lot, sc, M["acier"], M["riv"], a, -2.45, 1.1)
    for s in (-1, 1):
        V.doublures(lot, V.surf_nacelle(s, k), 3, lambda rr: M["rapiece"] if rr.f() < 0.4 else jaunes[0], r, (-2.3, -0.8),
                    (1.2, 3.0), M["riv"])
    # ------------------------------------------------------------ crâne : verrière, hublots du poste, phares, canards
    V.verriere(lot, M["verre"], M["acier"], k)
    V.hublots(lot, M["acier"], M["verre"], (1.3, 1.55, 1.8), math.pi - 0.5, k, r=0.06)
    V.hublots(lot, M["acier"], M["lampe"], (2.95,), math.pi - 0.15, k, r=0.05)
    for s in (-1, 1):
        V.canard(lot, M["jaune1"], M["chevron"], s, k)
    # ------------------------------------------------------------ ailes, dérive
    for s in (-1, 1):
        V.aile(lot, jaunes[2 if s > 0 else 0], M["noyau"], M["chevron"], M["riv"], s, k, rnd=r,
               saut=(lambda u, v: u > 0.4 and v > 0.69) if s < 0 else None)
    tip = V.derive(lot, M["jaune0"], M["chevron"], k)
    lot.put(M["voyant"], G.sphere(G.add(tip, (0, 0, 0.03)), 0.04, 8, 4))
    # ------------------------------------------------------------ épine : poutre dorsale, mât, antenne, grilles, trappe
    zt = V.profil(0.0)[0] + V.profil(0.0)[2] + 0.05
    lot.put(M["acier"], G.boite((-0.1, 0.0, zt + 0.04), (2.0, 0.18, 0.1)))
    for x in (-0.95, -0.5, -0.05, 0.4, 0.85):
        lot.put(M["acier_clair"], G.boite((x, 0.0, zt + 0.1), (0.07, 0.22, 0.03)))
    V.grille(lot, M["acier"], M["noir"], (0.15, -0.38, V.z_dessus(0.15, -0.38) + 0.02), 0.22, 0.5)
    V.grille(lot, M["acier"], M["noir"], (-0.75, 0.38, V.z_dessus(-0.75, 0.38) + 0.02), 0.2, 0.42, n=6)
    mx = -0.55
    lot.put(M["acier"], G.tube([(mx, 0.2, zt), (mx, 0.2, zt + 0.95)], 0.032, 8))
    lot.put(M["acier"], G.tube([(mx - 0.2, 0.2, zt + 0.8), (mx + 0.2, 0.2, zt + 0.8)], 0.016, 6))
    lot.put(M["acier"], G.tube([(mx - 0.13, 0.2, zt + 0.62), (mx + 0.13, 0.2, zt + 0.62)], 0.014, 6))
    lot.put(M["voyant"], G.sphere((mx, 0.2, zt + 0.99), 0.035, 8, 4))
    dish = G.tour([(0.0, 0.0), (0.03, 0.13), (0.07, 0.22), (0.08, 0.23), (0.055, 0.22), (0.02, 0.11)], 20, "z")
    zd = V.z_dessus(-1.75, -0.3)
    lot.put(M["acier"], G.tube([(-1.75, -0.3, zd), (-1.75, -0.3, zd + 0.2)], 0.028, 8))
    lot.put(M["acier_clair"], G.oriente(dish, (-1.75, -0.3, zd + 0.2), (-0.45, -0.35, 0.8)))
    zh = V.z_dessus(0.3, 0.25)
    lot.put(M["noir"], G.boite((0.3, 0.25, zh + 0.02), (0.34, 0.28, 0.06)))
    lot.put(M["jaune2"], G.boite((0.3, 0.43, zh + 0.16), (0.36, 0.035, 0.3), rx=-0.4))
    for dx, mc in ((0.0, "rouge"), (0.07, "noir")):
        V.flexible(lot, M[mc], [(0.3 + dx, 0.2, zh + 0.04), (0.25 + dx, -0.45, V.z_dessus(0.25, -0.45) + 0.06),
                                V.point(0.2 + dx, math.pi - 0.1, k, 0.09), (0.1 + dx, -1.3, 0.48), (0.0 + dx, -1.72, 0.34)], 0.018, pas=0.03)
    # ------------------------------------------------------------ flanc sud : porte, échelle, conduites
    xd, ad = 0.55, math.pi - 0.28
    V.trappe(lot, M["acier"], M["rapiece"], xd, ad, k, lum=M["lampe"])
    pd = V.point(xd, ad, k, 0.04)
    yl, zl = pd[1] - 0.04, pd[2] - 0.32
    for dx in (-0.17, 0.17):
        lot.put(M["acier_clair"], G.tube([(xd + dx, yl - 0.6, 0.0), (xd + dx, yl, zl + 0.05)], 0.02, 6))
    for i in range(1, 6):
        t = i / 6.0
        y, z = yl - 0.6 * (1 - t), zl * t
        lot.put(M["acier_clair"], G.tube([(xd - 0.17, y, z), (xd + 0.17, y, z)], 0.014, 6))
    V.tuyau(lot, M["acier"], M["acier_clair"], [(-0.25, -1.62, 0.12), (-0.25, -1.0, 0.12), (-0.25, -0.75, 0.5)], 0.045, pas_bride=0.4)
    V.flexible(lot, M["cuivre"], [V.point(-0.2, math.pi - 0.05, k, 0.04), (-0.05, -1.05, 0.62), (0.05, -1.35, 0.3), (0.05, -1.62, 0.15)],
               0.04)
    # ------------------------------------------------------------ train d'atterrissage
    for (x, y, z) in ((-1.6, -V.NAC_Y, 0.32), (-1.6, V.NAC_Y, 0.32), (1.0, -0.45, 0.5), (1.0, 0.45, 0.5)):
        V.jambe(lot, M["acier"], M["acier_clair"], M["acier"], (x, y, z), k)
    # ------------------------------------------------------------ échafaudage de bois autour du nez, chèvre, plaque neuve
    xs, ys = (1.85, 2.9), (-1.28, -0.8)
    hp = 0.78
    for x in xs:
        for y in ys:
            lot.put(M["bois"], G.boite((x, y, (hp + 0.45) / 2), (0.07, 0.07, hp + 0.45)))
    lot.put(M["bois"], G.boite(((xs[0] + xs[1]) / 2, (ys[0] + ys[1]) / 2, hp), (xs[1] - xs[0] + 0.25, ys[1] - ys[0] + 0.12, 0.04)))
    for x in (xs[0] + 0.25, xs[0] + 0.55, xs[0] + 0.85):
        lot.put(M["bois"], G.boite((x, (ys[0] + ys[1]) / 2, hp + 0.025), (0.02, ys[1] - ys[0] + 0.1, 0.012)))
    lot.put(M["bois"], G.boite(((xs[0] + xs[1]) / 2, ys[0] - 0.02, hp + 0.42), (xs[1] - xs[0] + 0.1, 0.04, 0.05)))
    lot.put(M["bois"], G.tube([(xs[0], ys[0], 0.05), (xs[1], ys[0], hp - 0.05)], 0.025, 6))
    for i in range(4):
        z = hp * (i + 0.5) / 4
        lot.put(M["bois"], G.boite((xs[0] - 0.08, ys[0] + 0.12, z), (0.03, 0.22, 0.03)))
    top = (2.4, -0.3, 2.3)
    for p in ((1.9, -1.45, 0.0), (2.9, -1.45, 0.0), (2.4, 0.9, 0.0)):
        lot.put(M["bois"], G.tube([p, top], 0.035, 6))
    lot.put(M["acier_clair"], G.boite(top, (0.12, 0.12, 0.1)))
    lot.put(M["acier"], G.tube([top, (2.4, -0.3, 1.75)], 0.011, 4))
    lot.put(M["rapiece"], V.plaque(V.surf_coque(1.0), 2.25, 2.6, 1.4, 2.0, 0.25, 0.3))
    # ------------------------------------------------------------ sol : groupe électrogène, caisses, fûts, lanternes
    V.caisson(lot, M["rapiece"], M["acier"], (0.0, -1.95, 0.0), (0.55, 0.36, 0.34), lum=M["voyant"])
    lot.put(M["acier"], G.tube([(-0.18, -1.85, 0.34), (-0.18, -1.85, 0.66)], 0.03, 8))
    for (x, y, sz, rz) in ((0.75, -2.05, 0.38, 0.2), (1.12, -2.3, 0.3, -0.15), (0.6, -2.47, 0.26, 0.5), (2.5, 1.5, 0.34, 0.1)):
        lot.put(M["bois"], G.boite((x, y, sz / 2), (sz, sz, sz), rz))
        for dz in (0.2, 0.8):
            lot.put(M["acier"], G.boite((x, y, sz * dz), (sz + 0.014, sz + 0.014, 0.03), rz))
    for (x, y) in ((1.55, -2.0), (1.78, -2.15), (-3.0, 1.6)):
        lot.put(M["rouge"], G.tour([(0.0, 0.12), (0.34, 0.12)], 16, "z", (x, y, 0.0), cap1=True))
        for z in (0.08, 0.26):
            lot.put(M["acier"], G.tour([(z - 0.015, 0.126), (z + 0.015, 0.126)], 16, "z", (x, y, 0.0)))
    for (x, y) in ((-0.45, -2.5), (3.25, -1.55)):
        lot.put(M["acier"], G.tube([(x, y, 0.0), (x, y, 0.85)], 0.022, 6))
        lot.put(M["acier"], G.tube([(x, y, 0.85), (x + 0.12, y, 0.85)], 0.015, 6))
        lot.put(M["acier_clair"], G.boite((x + 0.12, y, 0.75), (0.08, 0.08, 0.12)))
        lot.put(M["lampe"], G.boite((x + 0.12, y, 0.74), (0.05, 0.085, 0.07)))
    V.cable(lot, M["noir"], (-0.45, -2.5, 0.82), (3.25, -1.55, 0.82), 0.3, 0.01)
    return {}
