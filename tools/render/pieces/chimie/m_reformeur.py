"""REFORMEUR (fo-reformer, 3×3) : reformeur de méthane à la vapeur. Four « grille-pain » (caisson gris calorifugé) dont la
voûte est percée par deux rangées de TUBES CATALYTIQUES rouges au pied, reliés par des queues de cochon aux collecteurs
d'entrée ; fentes de brûleurs lumineuses sur la voûte et fentes de visite sur la face sud ; collecteur de sortie au pied,
réacteur de conversion trapu, batterie de 4 colonnes d'adsorption (PSA) blanches à bandes bleues, petite cheminée de
fumées. Entrées nord x = −1 (méthane), +1 (vapeur) ; sorties sud x = −1 (hydrogène, sous les PSA), +1 (CO2).
"""
import geo as G
import habille as H

FU, FV, FSU, FSV, FZ = -0.15, -0.6, 2.5, 1.3, 1.5
ROWS = (-0.92, -0.38)            # v des rangées de tubes
NT = 8                           # tubes par rangée
TZ1 = 2.05                       # sommet des tubes
HZ = 2.27                        # collecteurs d'entrée
SU, SV, SRR = 0.97, 0.66, 0.27   # réacteur de conversion
PSA = [(-1.22, 0.47), (-0.78, 0.47), (-1.22, 0.86), (-0.78, 0.86)]
PR, PZ = 0.125, 1.42


def build(S, k, R):
    four(k, R)
    tubes(k, R)
    sortie(k, R)
    psa(k, R)
    raccords(k, R)
    abords(k, R)


def four(k, R):
    R.box("beton", FU, FV, 0.0, FSU + 0.12, FSV + 0.12, 0.06)
    R.caisson("gris_proc", FU, FV, 0.06, FSU, FSV, FZ - 0.06, 0.03)
    b = R.bornes(FU, FV, FSU, FSV)
    xs = H.montants(k, "acier", b, 0.06, FZ + 0.02, pas=0.4, l=0.07)
    for z in (0.5, FZ - 0.04):
        H.ceinture(k, "acier", b, z, 0.045, 0.028)
    # fentes de visite verticales : les tubes rouges se voient au travers (grille-pain)
    Y = H.yb(b[3])
    for x0, x1 in zip(xs[:-1], xs[1:]):
        n = 3
        for i in range(n):
            x = x0 + (x1 - x0) * (i + 0.5) / n
            k.b("acier", (x, Y - 0.012, 1.0), (0.06, 0.024, 0.78))
            k.b("tube_rouge", (x, Y - 0.026, 1.0), (0.03, 0.006, 0.7))
    # voûte : plancher sombre, trois fentes de brûleurs le long de u, plaques de regard
    zt = FZ
    for v in (FV - 0.52, FV - 0.0, FV + 0.52):
        p0, p1 = R.p(FU - FSU / 2.0 + 0.12, v, zt), R.p(FU + FSU / 2.0 - 0.12, v, zt)
        c = G.lerp(p0, p1, 0.5)
        L = G.length(G.sub(p1, p0))
        horiz = abs(p1[0] - p0[0]) > abs(p1[1] - p0[1])
        sx, sy = (L, 0.07) if horiz else (0.07 * 1.0, L)
        k.b("acier", (c[0], c[1], zt + 0.012), (sx + (0 if horiz else 0.06), sy + (0.06 if horiz else 0), 0.025))
        k.b("feu", (c[0], c[1], zt + 0.026), (sx * (1 if horiz else 0.6), sy * (0.6 if horiz else 1), 0.006))
    # rambarde jaune sur la voûte (côté sud absolu) et échelle
    k.rambarde("jaune", [(b[0] + 0.05, Y + 0.05, zt), (b[1] - 0.05, Y + 0.05, zt)], 0.15, 0.3)
    k.echelle("jaune", b[1] - 0.14, Y - 0.06, 0.0, zt + 0.15)
    # cheminée des fumées au coin nord-est, gaine depuis le four
    cu, cv = 1.28, -1.12
    R.box("gris_proc", 1.13, cv, 0.72, 0.18, 0.22, 0.4)
    R.rev("car2", cu, cv, [(0.0, 0.17), (0.75, 0.17), (0.95, 0.12), (3.05, 0.12)], 24)
    R.cerclages("acier", cu, cv, [1.4, 2.0, 2.6], 0.122, 0.012, 0.02)
    R.cyl("rouge", cu, cv, 2.8, 2.95, 0.126, 24)
    R.cyl("noir", cu, cv, 3.0, 3.06, 0.09, 16)


def tubes(k, R):
    u0, u1 = FU - FSU / 2.0 + 0.2, FU + FSU / 2.0 - 0.25
    for j, v in enumerate(ROWS):
        hv = v - 0.17
        # collecteur d'entrée sur chevalets
        R.tuyau("isolant", [(u0 - 0.12, hv, HZ), (u1 + 0.12, hv, HZ)], 0.06, 0.1, bride_mat="acier")
        for u in (u0 - 0.05, (u0 + u1) / 2.0, u1 + 0.05):
            R.axe("acier", (u, hv, FZ), (u, hv, HZ - 0.05), 0.018, 6)
        for i in range(NT):
            u = u0 + (u1 - u0) * i / (NT - 1)
            # traversée de voûte (presse-étoupe), tube rouge au pied, tête et bride
            R.cyl("acier", u, v, FZ, FZ + 0.05, 0.065, 12)
            R.cyl("tube_rouge", u, v, FZ + 0.05, FZ + 0.24, 0.042, 12)
            R.cyl("acier_clair", u, v, FZ + 0.24, TZ1, 0.042, 12)
            R.cyl("acier", u, v, TZ1, TZ1 + 0.05, 0.058, 12)
            # queue de cochon vers le collecteur
            ctrl = [R.p(u, v, TZ1 + 0.05), R.p(u, v, TZ1 + 0.12), R.p(u, v - 0.08, HZ + 0.07), R.p(u, hv, HZ + 0.05)]
            k.put("acier_clair", G.tube(G.catmull(ctrl, 5), 0.014, 6))


def sortie(k, R):
    # collecteur de sortie (gaz de synthèse) au pied de la face sud locale, calorifugé
    v = FV + FSV / 2.0 + 0.12
    R.tuyau("isolant", [(FU - FSU / 2.0 + 0.1, v, 0.2), (SU, v, 0.2), (SU, SV - 0.12, 0.2)], 0.075, 0.12, bride_mat="acier")
    for u in (-1.0, -0.45, 0.1, 0.6):
        R.box("acier", u, v, 0.0, 0.05, 0.16, 0.14)
    # réacteur de conversion (CO -> CO2) : cuve trapue, trou d'homme, cerclages
    R.cyl("acier", SU, SV, 0.0, 0.1, SRR + 0.04, 24)
    R.cuve("car2", SU, SV, 0.1, 1.32, SRR, 0.45)
    R.cerclages("acier", SU, SV, [0.4, 0.8], SRR + 0.002, 0.014, 0.02)
    x, y, _ = R.p(SU, SV)
    k.axe("acier", (x, y - SRR + 0.02, 0.62), (x, y - SRR - 0.06, 0.62), 0.09, 14)
    k.axe("acier_clair", (x, y - SRR - 0.06, 0.62), (x, y - SRR - 0.09, 0.62), 0.11, 14)
    k.voyant("voyant_b", x + 0.14, y - SRR + 0.02, 1.0, 0.02)
    # gaz converti vers la tête des PSA
    R.tuyau("acier", [(SU, SV, 1.38), (SU, SV, 1.62), (-1.0, SV, 1.62), (-1.0, 0.66, 1.52)], 0.05, 0.1)


def psa(k, R):
    # socle à vannes, 4 colonnes blanches à bandes bleues, collecteurs haut et bas
    R.box("noir", -1.0, 0.665, 0.0, 0.72, 0.62, 0.1)
    R.box("acier", -1.0, 0.665, 0.1, 0.62, 0.52, 0.03)
    for u, v in PSA:
        R.cuve("blanc", u, v, 0.13, PZ, PR, 0.6, 24)
        R.cyl("bleu", u, v, 0.85, 0.97, PR + 0.004, 24)
        R.cyl("bleu", u, v, 0.33, 0.39, PR + 0.004, 24)
        R.cerclages("acier", u, v, [0.2, PZ - 0.2], PR + 0.002, 0.01, 0.015)
    R.tuyau("acier", [(-1.22, 0.665, PZ + 0.05), (-0.78, 0.665, PZ + 0.05)], 0.035, 0.08)
    for u, v in PSA:
        R.axe("acier", (u, v, PZ - 0.02), (u, 0.665, PZ + 0.05), 0.022, 6)
    # vannes pilotées au pied (voyants bleus) : une rangée par colonne
    for u, v in PSA:
        x, y, _ = R.p(u, v)
        for dz, m in ((0.0, "voyant_b"), (0.07, "voyant_v")):
            k.cyl("acier_clair", x + 0.14, y - 0.02, 0.13, 0.19 + dz, 0.022, 8)
            k.voyant_h(m, x + 0.14, y - 0.02, 0.19 + dz, 0.016)


def raccords(k, R):
    zr = 0.22
    u0, u1 = FU - FSU / 2.0 + 0.2, FU + FSU / 2.0 - 0.25
    # méthane (x = −1) : montée derrière le four vers le collecteur de la rangée nord
    hv0, hv1 = ROWS[0] - 0.17, ROWS[1] - 0.17
    R.raccord(-1.0, "n", zr, vers=[(-1.0, -1.32, zr), (-1.0, -1.32, HZ + 0.25), (u0 - 0.12, -1.32, HZ + 0.25),
                                   (u0 - 0.12, hv0, HZ + 0.25), (u0 - 0.12, hv0, HZ)])
    # vapeur (x = +1) : montée vers le collecteur de la rangée sud, mélangeur sur la voûte
    R.raccord(1.0, "n", zr, vers=[(1.0, -1.34, zr), (1.0, -1.34, HZ + 0.35), (1.0, hv1, HZ + 0.35), (u1 + 0.12, hv1, HZ + 0.35),
                                  (u1 + 0.12, hv1, HZ)])
    R.tuyau("acier", [(u0 - 0.12, hv0, HZ + 0.25), (u0 - 0.12, hv1, HZ + 0.25), (u0 - 0.12, hv1, HZ)], 0.05, 0.08)
    R.vanne("acier", "rouge", (1.0, -0.9, HZ + 0.35), 0.05, 0.06)
    R.vanne("acier", "rouge", (u0 - 0.12, -1.05, HZ + 0.25), 0.05, 0.06)
    # hydrogène (x = −1, sud) : sous le socle des PSA
    R.raccord(-1.0, "s", zr, vers=[(-1.0, 0.9, zr)], mat_suite="blanc")
    # CO2 (x = +1, sud) : pied du réacteur de conversion
    R.raccord(1.0, "s", zr, vers=[(1.0, 1.0, zr), (1.0, 1.0, 0.36), (1.0, SV + 0.1, 0.36)])


def abords(k, R):
    # armoire de conduite entre les PSA et le réacteur, écrans bleus
    cu, cv, su, sv, h = 0.05, 1.08, 0.46, 0.3, 0.6
    R.caisson("car2", cu, cv, 0.0, su, sv, h, 0.02)
    b = R.bornes(cu, cv, su, sv)
    Y = H.yb(b[3])
    xc = (b[0] + b[1]) / 2.0
    H.porte(k, "car2", "acier_clair", xc, b[3], 0.05, b[1] - b[0] - 0.08, h - 0.22)
    k.b("noir", (xc, Y - 0.012, h - 0.09), (b[1] - b[0] - 0.08, 0.012, 0.1))
    k.b("voyant_b", (xc - 0.06, Y - 0.02, h - 0.09), (0.12, 0.004, 0.06))
    k.voyant("voyant_v", xc + 0.12, Y - 0.02, h - 0.09, 0.015)
    k.b("chevron", (xc, Y - 0.006, 0.03), (b[1] - b[0], 0.012, 0.05))
