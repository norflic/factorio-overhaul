"""ÂGE 8 (Marais) : moitié vaisseau, moitié bâtiment (emprise 12×6, k = 1,5). Nez à droite.

Le ventre du vaisseau est remplacé par une halle à étage (soubassement de pierre, colombages et planches de bois
mouillé, baies à la lumière jaune toxique, toit de cuivre vert-de-gris à joints debout, deux souches de brique) ; les
couples de la coque restent DEBOUT au-dessus du toit (le squelette), reliés par l'épine dorsale. Nez et queue gardent
leur blindage (repeint vert-de-gris, plaques jaunes d'origine, anneau de chevrons) ; les deux tuyères sont devenues
des chaudières : cloches déposées, souches de cuivre, conduites vers la halle. Le tout sur pieux, ponton au sud,
bocaux toxiques, fûts.
Bible : vert-de-gris (dominante) ; bois mouillé, cuivre terni ; accent jaune toxique.
"""
import math

import age01
import bati as B
import geo as G
import mat as MT
import vaisseau as V

K = 1.5
VENTRE = (-1.15, 1.0)
COTES = (-0.753, -0.087, 0.58, 1.2)
BALAI = 0.25


def matieres(S):
    M = age01.matieres(S)
    M["vdg"] = MT.surface("o8_vdg", (0.07, 0.15, 0.115), rough=0.55, met=0.3, coulures=0.7, rouille=(0.16, 0.08, 0.04),
                          usure=0.7, nu=(0.3, 0.2, 0.12), crasse=0.65, pied=(0.4, 1.2, 0.6), graine=31)
    M["vdg2"] = MT.surface("o8_vdg2", (0.055, 0.12, 0.095), rough=0.55, met=0.3, coulures=0.7, rouille=(0.16, 0.08, 0.04),
                           usure=0.7, nu=(0.3, 0.2, 0.12), crasse=0.65, pied=(0.4, 1.2, 0.6), graine=32)
    M["vieux_jaune"] = MT.surface("o8_vieux_jaune", (0.36, 0.24, 0.03), rough=0.6, met=0.2, coulures=0.9, usure=0.8,
                                  nu=(0.3, 0.27, 0.22), crasse=0.7, pied=(0.4, 1.2, 0.6), graine=33)
    M["cuivre_t"] = MT.surface("o8_cuivre", (0.24, 0.11, 0.055), rough=0.45, met=0.85, coulures=0.8, rouille=(0.05, 0.16, 0.11),
                               usure=0.6, nu=(0.55, 0.3, 0.16), crasse=0.6, graine=34)
    M["toit"] = MT.surface("o8_toit", (0.1, 0.2, 0.15), rough=0.6, met=0.3, tole=(0.28, 1.6), joint=0.55, coulures=0.6,
                           rouille=(0.03, 0.05, 0.04), usure=0.5, nu=(0.25, 0.14, 0.08), crasse=0.6, relief=0.3, graine=35)
    M["bois_m"] = MT.surface("o8_bois", (0.16, 0.105, 0.06), rough=0.85, met=0.0, tole=(1.0, 0.11), joint=0.4, var=0.2,
                             coulures=0.4, rouille=(0.03, 0.04, 0.02), usure=0.5, nu=(0.2, 0.14, 0.08), crasse=0.6, relief=0.4, graine=36)
    M["poutre"] = MT.surface("o8_poutre", (0.085, 0.055, 0.032), rough=0.8, met=0.0, usure=0.6, nu=(0.16, 0.1, 0.06), crasse=0.6, graine=37)
    M["pierre"] = MT.surface("o8_pierre", (0.085, 0.08, 0.07), rough=0.9, met=0.0, tole=(0.42, 0.2), joint=0.45, var=0.18,
                             coulures=0.3, rouille=(0.03, 0.06, 0.03), usure=0.6, nu=(0.18, 0.17, 0.15), crasse=0.7,
                             pied=(0.0, 0.35, 0.6), relief=0.6, graine=38)
    M["brique"] = MT.surface("o8_brique", (0.17, 0.06, 0.035), rough=0.85, met=0.0, tole=(0.24, 0.08), joint=0.5, var=0.15,
                             usure=0.5, nu=(0.25, 0.12, 0.08), crasse=0.6, relief=0.5, graine=39)
    M["toxique"] = MT.lumiere(S, "o8_toxique", (0.6, 1.0, 0.04), 5.0, main=0.45)
    M["os"] = MT.surface("o8_os", (0.36, 0.34, 0.29), rough=0.45, met=0.8, coulures=0.6, usure=0.8, nu=(0.35, 0.34, 0.32),
                         crasse=0.6, graine=40)
    return M


def build(S, lot):
    M = matieres(S)
    V.reglage(nac_x0=-1.3)
    k = K
    r = G.Rnd(808)
    vertdg = [M["vdg"], M["vdg2"]]

    def mats(rr, i, j, zone):
        x = rr.f()
        if zone == "coque" and i == 11:
            return M["chevron"]
        if zone == "nacelle" and i == 0:
            return M["cuivre_t"]
        if x < 0.62:
            return M["vieux_jaune"]
        if x < 0.7:
            return M["cuivre_t"]
        return vertdg[int(rr.f() * 2) % 2]

    def saut(xm, am):
        if VENTRE[0] - 0.05 < xm < VENTRE[1] + 0.05:
            return True
        return 1.15 < xm < 2.5 and abs(am - math.pi / 2) < 0.95

    V.corps(lot, k, r, M["noyau"], M["cuivre_t"], M["brule"], M["riv"], mats, saut=saut, ventre=VENTRE,
            cloches=(), Mcloison=M["os"])
    sc = V.surf_coque(k)
    V.doublures(lot, sc, 7, lambda rr: M["vieux_jaune"] if rr.f() < 0.5 else M["cuivre_t"], r, (1.05, 2.8), (1.8, 3.5), M["riv"])
    V.doublures(lot, sc, 5, lambda rr: M["vdg"], r, (-2.4, -1.25), (1.6, 3.5), M["riv"])
    V.verriere(lot, M["verre"], M["cuivre_t"], k)
    V.hublots(lot, M["cuivre_t"], M["toxique"], (1.35, 1.65, 1.95), math.pi - 0.5, k, r=0.065)
    for s in (-1, 1):
        V.canard(lot, M["vdg"], M["chevron"], s, k)
        V.aile(lot, vertdg[0] if s < 0 else M["vieux_jaune"], M["noyau"], M["cuivre_t"], M["riv"], s, k, rnd=r)
    tip = V.derive(lot, M["vieux_jaune"], M["cuivre_t"], k, x0=-1.3)
    lot.put(M["toxique"], G.sphere(G.add(tip, (0, 0, 0.04)), 0.05, 8, 4))
    # ------------------------------------------------------------ le squelette : couples debout et épine
    ztop = (V.profil(0.0)[0] + V.profil(0.0)[2]) * k
    haut = 0.55
    ae = 0.4
    for x in COTES:
        V.cote(lot, M["os"], x, k, ep=0.17, prof=0.18, saillie=0.08, a0=-ae, a1=math.pi + ae, haut=haut, rond=True, balai=BALAI)
        for a in (-ae, math.pi + ae):                           # jambe de côte jusqu'à sa semelle de pierre
            p = V.point_cote(x, a, k, -0.02, 0.0, True, BALAI)
            lot.put(M["os"], G.boite((p[0], p[1], (0.36 + p[2]) / 2), (0.13, 0.16, p[2] - 0.36)))
            lot.put(M["pierre"], G.boite((p[0], p[1], 0.18), (0.4, 0.4, 0.36)))
            lot.put(M["os"], G.boite((p[0], p[1], 0.38), (0.24, 0.26, 0.05)))
    zs = ztop + haut + 0.12
    epine = [(-2.45 * k, 0.0, V.z_dessus(-2.45, 0.0) * k + 0.08), (COTES[0] * k - 0.35, 0.0, zs), (COTES[-1] * k + 0.35, 0.0, zs),
             (1.45 * k, 0.0, V.z_dessus(1.1, 0.0) * k + 0.08)]
    lot.put(M["os"], G.tube(G.coudee(epine, 0.4, 6), 0.1, 6))
    for x in COTES:
        lot.put(M["os"], G.prisme([(x * k - 0.16, -0.06), (x * k + 0.16, -0.06), (x * k + 0.06, 0.06), (x * k - 0.06, 0.06)],
                                  ztop + haut + 0.2, ztop + haut + 0.48))
    # ------------------------------------------------------------ la halle (entre les cloisons, dans la cage des côtes)
    hx0, hx1 = VENTRE[0] * k + 0.03, VENTRE[1] * k - 0.03
    yw = 1.22
    z_soc, z_et, z_ev, z_fa = 0.45, 1.5, 2.35, 2.95
    # soubassement de pierre (dépasse un peu)
    lot.put(M["pierre"], G.boite(((hx0 + hx1) / 2, 0.0, z_soc / 2), (hx1 - hx0 + 0.1, 2 * yw + 0.16, z_soc)))
    xm = (hx0 + hx1) / 2
    for s in (-1, 1):
        rez = [(xm - 1.0, 0.4, z_soc + 0.2, 1.25), (xm + 1.0, 0.4, z_soc + 0.2, 1.25)]
        if s < 0:
            rez.append((xm, 0.5, z_soc, 1.33))                  # porte
        etg = [(x, 0.34, z_et + 0.16, 2.1) for x in (-0.84, 0.16, 1.12)]
        B.mur(lot, M["bois_m"], M["poutre"], M["toxique"], "x", s * yw, hx0, hx1, z_soc, z_et, 0.1, rez, cote=s)
        B.mur(lot, M["bois_m"], M["poutre"], M["toxique"], "x", s * yw, hx0, hx1, z_et, z_ev, 0.1, etg, cote=s)
        # colombages : poteaux, sablière d'étage, jambes de force
        for x in (hx0, hx0 + (hx1 - hx0) / 3, hx0 + 2 * (hx1 - hx0) / 3, hx1):
            lot.put(M["poutre"], G.boite((x, s * (yw + 0.07), (z_soc + z_ev) / 2), (0.1, 0.06, z_ev - z_soc)))
        lot.put(M["poutre"], G.boite((xm, s * (yw + 0.12), z_et), (hx1 - hx0 + 0.2, 0.12, 0.12)))
        lot.put(M["poutre"], G.boite((xm, s * (yw + 0.1), z_ev - 0.04), (hx1 - hx0 + 0.2, 0.1, 0.1)))
        # porte : vantaux de planches et lanterne
    lot.put(M["poutre"], G.boite((xm, -yw - 0.07, z_soc + 0.45), (0.46, 0.04, 0.86)))
    lot.put(M["toxique"], G.boite((xm, -yw - 0.12, 1.42), (0.08, 0.06, 0.1)))
    B.toit(lot, M["toit"], M["cuivre_t"], hx0 - 0.05, hx1 + 0.05, -yw - 0.06, yw + 0.06, z_ev, z_fa, debord=0.16, joints=0.3,
           Mjoint=M["cuivre_t"])
    for (x, y) in ((-1.45, 0.45), (1.3, -0.4)):
        zb = z_ev + (z_fa - z_ev) * (1 - abs(y) / yw) - 0.1
        lot.put(M["brique"], G.boite((x, y, zb + 0.4), (0.3, 0.3, 0.8)))
        lot.put(M["pierre"], G.boite((x, y, zb + 0.84), (0.38, 0.38, 0.08)))
        lot.put(M["noir"], G.boite((x, y, zb + 0.86), (0.18, 0.18, 0.05)))
    # lucarnes du pan sud, lanterneau de faîtage, évents
    for xl in (xm - 0.95, xm + 0.08, xm + 1.05):
        B.lucarne(lot, M["bois_m"], M["toit"], M["poutre"], M["toxique"], xl, -0.62, z_ev + (z_fa - z_ev) * 0.27, cote=-1)
    lot.put(M["poutre"], G.boite((0.37, 0.0, z_fa + 0.18), (0.5, 0.42, 0.3)))
    lot.put(M["toxique"], G.boite((0.37, -0.215, z_fa + 0.2), (0.36, 0.02, 0.16)))
    B.toit(lot, M["cuivre_t"], M["cuivre_t"], 0.1, 0.64, -0.25, 0.25, z_fa + 0.33, z_fa + 0.5, debord=0.05, joints=0.0)
    lot.put(M["cuivre_t"], G.tube([(0.37, 0.0, z_fa + 0.52), (0.37, 0.0, z_fa + 0.8)], 0.012, 4))
    for (x, y) in ((xm + 0.6, 0.55), (hx0 + 0.25, -0.3)):
        zb = z_ev + (z_fa - z_ev) * (1 - abs(y) / yw)
        lot.put(M["cuivre_t"], G.tour([(zb - 0.05, 0.06), (zb + 0.28, 0.06), (zb + 0.3, 0.1), (zb + 0.36, 0.1), (zb + 0.4, 0.0)],
                                      10, "z", (x, y, 0.0)))
    # ------------------------------------------------------------ les tuyères devenues chaudières
    zn = V.NAC_Z * k
    for s in (-1, 1):
        y = s * V.NAC_Y * k
        xc = -1.9 * k
        r0 = V.NAC_R * k
        lot.put(M["cuivre_t"], G.tour([(zn + r0 - 0.08, 0.2), (zn + r0 + 1.7, 0.17)], 16, "z", (xc, y, 0.0), cap1=False))
        for zb in (zn + r0 + 0.35, zn + r0 + 0.95, zn + r0 + 1.55):
            lot.put(M["poutre"], G.tour([(zb - 0.03, 0.21), (zb + 0.03, 0.21)], 16, "z", (xc, y, 0.0)))
        lot.put(M["cuivre_t"], G.tour([(zn + r0 + 1.7, 0.24), (zn + r0 + 1.78, 0.24), (zn + r0 + 1.8, 0.12)], 16, "z", (xc, y, 0.0)))
        lot.put(M["noir"], G.tour([(zn + r0 + 1.6, 0.13), (zn + r0 + 1.79, 0.13)], 12, "z", (xc, y, 0.0), cap0=True))
        # conduite de vapeur vers la halle
        yo = s * (V.NAC_Y + V.NAC_R) * k + s * 0.1
        V.tuyau(lot, M["cuivre_t"], M["os"], [(-2.9, yo, zn), (hx0 + 0.6, yo, zn), (hx0 + 0.6, yo, 0.95),
                                              (hx0 + 0.6, s * (yw + 0.12), 0.95)], 0.07, pas_bride=0.5)
    # ------------------------------------------------------------ pieux sous le nez et la queue (plus de train)
    for (x, y) in ((1.4, -0.5), (1.4, 0.5), (2.3, 0.0), (-1.55, -0.3), (-1.55, 0.3)):
        zb = (V.profil(x)[0] - V.profil(x)[3]) * k
        B.pieu(lot, M["poutre"], x * k, y * k, 0.0, zb + 0.05, 0.08, M["cuivre_t"])
    for s in (-1, 1):
        y = s * V.NAC_Y * k
        for x in (-2.2, -1.45):
            B.pieu(lot, M["poutre"], x * k, y, 0.0, (V.NAC_Z - V.NAC_R) * k + 0.05, 0.09, M["cuivre_t"])
    # ------------------------------------------------------------ ponton au sud, bocaux toxiques, fûts
    dx0, dx1, dy0, dy1, dz = -3.4, 3.2, -2.7, -1.45, 0.32
    B.plancher(lot, M["bois_m"], dx0, dx1, dy0, dy1, dz, 0.05, M["poutre"], 0.8)
    for x in (dx0 + 0.1, -1.0, 1.0, dx1 - 0.1):
        for y in (dy0 + 0.08, dy1 - 0.08):
            B.pieu(lot, M["poutre"], x, y, 0.0, dz - 0.04, 0.06)
    B.garde_corps(lot, M["poutre"], [(dx0 + 0.05, dy1 - 0.05, dz), (dx0 + 0.05, dy0 + 0.05, dz), (xm - 0.5, dy0 + 0.05, dz)])
    B.garde_corps(lot, M["poutre"], [(xm + 0.5, dy0 + 0.05, dz), (dx1 - 0.05, dy0 + 0.05, dz), (dx1 - 0.05, dy1 - 0.05, dz)])
    B.escalier(lot, M["bois_m"], (xm, dy0 - 0.45, 0.0), (xm, dy0 + 0.05, dz), 0.6, 4)
    for (x, y) in ((-2.6, -2.15), (-2.05, -2.3), (-1.5, -2.1)):
        c = (x, y, dz)
        lot.put(M["toxique"], G.tour([(0.0, 0.2), (0.62, 0.2)], 16, "z", c, cap0=False, cap1=True))
        lot.put(M["verre"], G.tour([(0.0, 0.215), (0.66, 0.215), (0.7, 0.12)], 16, "z", c, cap1=True))
        for z in (0.04, 0.34, 0.64):
            lot.put(M["cuivre_t"], G.tour([(z - 0.03, 0.225), (z + 0.03, 0.225)], 16, "z", c))
        lot.put(M["cuivre_t"], G.tour([(0.68, 0.1), (0.78, 0.08), (0.8, 0.0)], 12, "z", c))
    V.tuyau(lot, M["cuivre_t"], M["os"], [(-2.6, -2.15, dz + 0.85), (-2.6, -1.6, dz + 0.85), (hx0 + 0.2, -1.6, dz + 0.85),
                                          (hx0 + 0.2, -yw - 0.05, dz + 0.85)], 0.045, pas_bride=0.6)
    lot.put(M["cuivre_t"], G.tube([(-2.05, -2.3, dz + 0.8), (-2.05, -2.3, dz + 0.95), (-2.6, -2.3, dz + 0.95)], 0.03, 8))
    for (x, y) in ((2.3, -2.2), (2.6, -2.05), (2.45, -2.45)):
        lot.put(M["vdg2"], G.tour([(0.0, 0.14), (0.4, 0.14)], 16, "z", (x, y, dz), cap1=True))
        for z in (0.08, 0.3):
            lot.put(M["poutre"], G.tour([(z - 0.015, 0.146), (z + 0.015, 0.146)], 16, "z", (x, y, dz)))
    for (x, y, sz, rz) in ((1.4, -2.2, 0.4, 0.15), (1.85, -2.35, 0.32, -0.3)):
        lot.put(M["bois_m"], G.boite((x, y, dz + sz / 2), (sz, sz, sz), rz))
    for (x, y) in ((dx0 + 0.05, dy0 + 0.05), (dx1 - 0.05, dy0 + 0.05)):
        lot.put(M["poutre"], G.tube([(x, y, dz), (x, y, dz + 1.0)], 0.03, 6))
        lot.put(M["toxique"], G.boite((x, y - 0.06, dz + 0.92), (0.07, 0.07, 0.1)))
    return {}
