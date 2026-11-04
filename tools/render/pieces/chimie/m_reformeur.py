"""REFORMEUR (fo-reformer, 3×3) : reformeur de méthane à la vapeur. Four « grille-pain » (caisson gris calorifugé) dont la
voûte est percée par deux rangées de TUBES CATALYTIQUES rouges au pied, reliés par des queues de cochon aux collecteurs
d'entrée ; fentes de brûleurs lumineuses sur la voûte et fentes de visite sur la face sud ; collecteur de sortie au pied,
réacteur de conversion trapu, batterie de 4 colonnes d'adsorption (PSA) blanches à bandes bleues, petite cheminée de
fumées. Entrées nord x = −1 (méthane), +1 (vapeur) ; sorties sud x = −1 (hydrogène, sous les PSA), +1 (CO2).
Ronde 2 (CRITIQUE.md §2) : tubes rouge sombre (lueur (255, 120, 30)), tubes FROIDS au-dessus de la voûte (acier sombre) avec
un seul anneau lumineux de 2 px à la traversée, queues de cochon de 3 px, collecteurs de 16 px à brides boulonnées, acier
bruni au-dessus des fentes, une seule fente de brûleurs sur la voûte, adsorbeurs blanc cassé à 2 bandes bleues de 4 px en
carré 2 × 2 à l'angle sud-ouest (rang arrière plus haut : les 4 se voient en vue nord).
"""
import geo as G
import habille as H

FU, FV, FSU, FSV, FZ = -0.15, -0.6, 2.5, 1.3, 1.5
ROWS = (-0.92, -0.38)            # v des rangées de tubes
NT = 8                           # tubes par rangée
TZ1 = 2.05                       # sommet des tubes
HZ = 2.27                        # collecteurs d'entrée
SU, SV, SRR = 0.97, 0.66, 0.27   # réacteur de conversion
PSA = [(-1.22, 0.5, 1.85), (-0.76, 0.5, 1.85), (-1.22, 0.94, 1.32), (-0.76, 0.94, 1.32)]   # (u, v, hauteur)
PR = 0.14


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
            k.b("chauffe" if i != 1 else "bleui", (x, Y - 0.004, 1.43), (0.09, 0.008, 0.08))
    # voûte : plancher sombre, trois fentes de brûleurs le long de u, plaques de regard
    zt = FZ
    voute(k, R)
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


def voute(k, R):
    """Toit d'un reformeur chauffé par le haut : gaine d'air de combustion le long des rangées (entre elles), brûleurs de voûte
    (pot, tête, petite lueur à la traversée) sous la gaine et sur deux rangées extérieures alimentées par un tube de gaz,
    tôles de voûte. Contre-relecture du 4/11 : le toit nu se lisait comme un couvercle en E et O."""
    zt = FZ
    u0, u1 = FU - FSU / 2.0 + 0.2, FU + FSU / 2.0 - 0.25
    vm = (ROWS[0] + ROWS[1]) / 2.0
    zg = zt + 0.3
    # gaine d'air (caisson sur béquilles), ventilateur de tirage au bout est, raidisseurs
    R.caisson("car2", (u0 + u1) / 2.0, vm, zg, u1 - u0 + 0.3, 0.2, 0.22, 0.02)
    for u in (u0 - 0.05, (u0 + u1) / 2.0, u1 + 0.05):
        R.box("acier", u, vm, zt, 0.05, 0.05, zg - zt)
    n = 6
    for i in range(n + 1):
        R.box("acier", u0 - 0.1 + (u1 - u0 + 0.2) * i / n, vm, zg - 0.01, 0.035, 0.22, 0.24)
    R.box("car", u1 + 0.25, vm, zt, 0.24, 0.3, 0.42)
    R.ventilo(u1 + 0.25, vm, zt + 0.47, 0.11, corps="car2", lame="acier_clair", grille="acier", moyeu="acier", garde=False)
    # brûleurs sous la gaine : une descente par intervalle de tubes
    for i in range(NT - 1):
        u = u0 + (u1 - u0) * (i + 0.5) / (NT - 1)
        R.cyl("acier", u, vm, zt, zt + 0.06, 0.07, 12)
        R.tore("feu", u, vm, zt + 0.065, 0.05, 0.014, 14, 4)
        R.cyl("acier_clair", u, vm, zt + 0.06, zg, 0.04, 10)
    # deux rangées extérieures de brûleurs, tube de gaz et petites vannes
    for v in (ROWS[0] - 0.26, ROWS[1] + 0.26):
        R.tuyau("acier", [(u0 - 0.1, v, zt + 0.2), (u1 + 0.1, v, zt + 0.2)], 0.028, 0.08)
        for i in range(NT - 1):
            u = u0 + (u1 - u0) * (i + 0.5) / (NT - 1)
            R.cyl("acier", u, v, zt, zt + 0.05, 0.05, 10)
            R.tore("feu", u, v, zt + 0.055, 0.036, 0.012, 12, 4)
            R.axe("acier_clair", (u, v, zt + 0.05), (u, v, zt + 0.2), 0.016, 6)
        R.vanne("acier", "rouge", (u0 + 0.2, v, zt + 0.2), 0.026, 0.04)


def tubes(k, R):
    u0, u1 = FU - FSU / 2.0 + 0.2, FU + FSU / 2.0 - 0.25
    for j, v in enumerate(ROWS):
        hv = v - 0.17
        # collecteur d'entrée sur chevalets
        R.tuyau("isolant", [(u0 - 0.12, hv, HZ), (u1 + 0.12, hv, HZ)], 0.11, 0.1, bride_mat="acier")
        for u in (u0 + 0.6, u1 - 0.6):
            R.collier("acier", (u, hv, HZ), (1.0, 0.0, 0.0), 0.11, 0.03, 0.025)
        for u in (u0 - 0.05, (u0 + u1) / 2.0, u1 + 0.05):
            R.axe("acier", (u, hv, FZ), (u, hv, HZ - 0.05), 0.018, 6)
        for i in range(NT):
            u = u0 + (u1 - u0) * i / (NT - 1)
            # traversée de voûte (presse-étoupe), tube rouge au pied, tête et bride
            R.cyl("acier", u, v, FZ, FZ + 0.04, 0.068, 12)
            R.tore("tube_rouge", u, v, FZ + 0.045, 0.05, 0.016, 16, 5)
            R.cyl("acier", u, v, FZ + 0.04, TZ1, 0.042, 12)
            R.cyl("acier_clair", u, v, TZ1, TZ1 + 0.05, 0.058, 12)
            # queue de cochon vers le collecteur
            ctrl = [R.p(u, v, TZ1 + 0.05), R.p(u, v, TZ1 + 0.12), R.p(u, v - 0.08, HZ + 0.07), R.p(u, hv, HZ + 0.05)]
            k.put("acier_clair", G.tube(G.catmull(ctrl, 5), 0.024, 8))


zc_psa = 1.95


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
    R.tuyau("acier", [(SU, SV, 1.38), (SU, SV, 2.05), (-0.68, 0.72, 2.05), (-0.68, 0.72, zc_psa)], 0.05, 0.1)


def psa(k, R):
    # socle à vannes, 4 colonnes blanches à bandes bleues, collecteurs haut et bas
    R.box("noir", -0.99, 0.72, 0.0, 0.76, 0.7, 0.1)
    R.box("acier", -0.99, 0.72, 0.1, 0.66, 0.6, 0.03)
    for u, v, pz in PSA:
        R.cuve("blanc", u, v, 0.13, pz, PR, 0.6, 24)
        R.cyl("bleu", u, v, pz - 0.5, pz - 0.41, PR + 0.004, 24)
        R.cyl("bleu", u, v, pz - 0.68, pz - 0.59, PR + 0.004, 24)
        R.cerclages("acier", u, v, [0.24], PR + 0.002, 0.012, 0.016)
    zc = 1.95
    R.tuyau("acier", [(-1.3, 0.72, zc), (-0.68, 0.72, zc)], 0.04, 0.08)
    for u, v, pz in PSA:
        R.axe("acier", (u, v, pz - 0.02), (u, 0.72, zc), 0.024, 8)
    # vannes pilotées au pied (voyants bleus) : une rangée par colonne
    for u, v, pz in PSA:
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
