"""BOURDON, expérimental de l'âge 15 (Légende) : une CLOCHE-CATHÉDRALE en lévitation, 50 tuiles de haut à l'écran. Lot RB-V0, 31/10.

Le bourdon est la plus grosse cloche d'une cathédrale. Bible de l'âge 15 (DESIGN_EPOQUES, époque 15) : couronne de flèches,
base flottante (vide maximal), halo, or blanc et nacre ; le corps en bronze patiné, comme le QG validé le 31/10.
- Pas de marche : elle flotte, retenue au sol par 6 chaînes tendues, dont les ancres se déplacent (en jeu : 6 pattes de
  `spider-vehicle` dont la seule image est une chaîne).
- La cloche : profil de vraie cloche (pince, faussure, cerveau), côtes de nacre, cordons d'or blanc, frises, lancettes,
  3 rosaces éclairées, rampe en hélice à garde-corps (l'échelle), terrasse à pinacles, couronne de flèches, anses.
- Sous la lèvre : cristaux de lévitation, grand anneau-halo flottant, rochers arrachés au sol qui flottent.
- Le battant (variante « battant ») est rendu à part : il bat à l'écran sans refaire la cloche.

Une cloche ne tourne jamais : UNE image pour toutes les directions. FO_GRIS=1 : masses grises.
"""
import math
import os

import geo as G
import greb as R
import mat as MT

GRIS = os.environ.get("FO_GRIS", "") == "1"
Z_LEVRE = 33.0
# profil extérieur (z, rayon) : de la lèvre au cerveau
_PROF = [(Z_LEVRE, 14.2), (Z_LEVRE + 0.7, 14.9), (Z_LEVRE + 1.7, 14.0), (Z_LEVRE + 3.6, 12.0), (Z_LEVRE + 6.5, 10.0), (Z_LEVRE + 10.0, 8.6),
         (Z_LEVRE + 14.0, 7.8), (Z_LEVRE + 18.0, 7.4), (Z_LEVRE + 21.0, 7.3), (Z_LEVRE + 23.0, 6.9), (Z_LEVRE + 24.6, 5.8),
         (Z_LEVRE + 25.8, 4.1), (Z_LEVRE + 26.6, 2.1), (Z_LEVRE + 26.95, 0.0)]
_FIN = []


def _lisse():
    if _FIN:
        return _FIN
    pts = G.catmull([(p[0], p[1], 0.0) for p in _PROF], 10)
    _FIN.extend((p[0], max(0.0, p[1])) for p in pts)
    return _FIN


def rz(z):
    """Rayon de la cloche à la hauteur z (interpolation du profil lissé)."""
    prof = _lisse()
    if z <= prof[0][0]:
        return prof[0][1]
    for i in range(1, len(prof)):
        if z <= prof[i][0]:
            a, b = prof[i - 1], prof[i]
            return a[1] + (b[1] - a[1]) * (z - a[0]) / max(1e-6, b[0] - a[0])
    return 0.0


def normale(az, z):
    dr = (rz(z + 0.2) - rz(z - 0.2)) / 0.4
    return G.norm((math.cos(az), math.sin(az), -dr))


def S_pt(az, z, d=0.0):
    r = rz(z) + d
    return (r * math.cos(az), r * math.sin(az), z)


def vu(az, m=0.35):
    """Seul l'hémisphère vu de la caméra (sud) reçoit le détail fin : une image, jamais tournée."""
    return math.sin(az) < m


def matieres(S, variante="bourdon"):
    def surf(name, col, **kw):
        if GRIS:
            return MT.surface("bo_g_" + name, (0.2, 0.2, 0.2), rough=0.6, met=0.1, usure=0.3, crasse=0.6, graine=kw.get("graine", 0))
        return MT.surface("bo_" + name, col, **kw)
    MT.ECH[0] = 3.0
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.17, ra=0.2, ec=0.5, nu_k=1.4, ec_col=(0.02, 0.05, 0.04), sans=("_or", "nacre"))
    M = {}
    M["bronze"] = surf("bronze", (0.17, 0.095, 0.036), rough=0.42, met=0.6, tole=(3.1, 2.1), joint=0.5, joint_l=0.012, var=0.12, coulures=0.85,
                       rouille=(0.05, 0.16, 0.115), usure=0.6, nu=(0.46, 0.3, 0.15), crasse=0.85, crasse_col=(0.008, 0.006, 0.004), relief=0.5, graine=1)
    M["bronze2"] = surf("bronze2", (0.1, 0.056, 0.024), rough=0.46, met=0.55, coulures=0.7, rouille=(0.04, 0.12, 0.09), usure=0.6, nu=(0.34, 0.22, 0.11),
                        crasse=0.85, crasse_col=(0.006, 0.005, 0.003), graine=2)
    M["noyau"] = surf("noyau", (0.012, 0.01, 0.008), rough=0.55, met=0.6, usure=0.3, crasse=0.8, crasse_col=(0.002, 0.002, 0.002), graine=3)
    M["or"] = surf("or", (0.86, 0.73, 0.42), rough=0.34, met=0.4, coulures=0.25, rouille=(0.3, 0.2, 0.08), usure=0.5, nu=(0.98, 0.92, 0.72),
                   crasse=0.55, crasse_col=(0.03, 0.02, 0.008), graine=4)
    M["or_sombre"] = surf("or_sombre", (0.46, 0.31, 0.11), rough=0.42, met=0.5, coulures=0.35, usure=0.6, nu=(0.75, 0.6, 0.32), crasse=0.8,
                          crasse_col=(0.02, 0.012, 0.005), graine=5)
    M["nacre"] = surf("nacre", (0.74, 0.68, 0.56), rough=0.3, met=0.0, coulures=0.5, rouille=(0.1, 0.07, 0.04), usure=0.4, nu=(0.86, 0.82, 0.74), crasse=0.85,
                      crasse_col=(0.03, 0.022, 0.014), graine=6)
    M["nacre2"] = surf("nacre2", (0.44, 0.34, 0.2), rough=0.34, met=0.15, coulures=0.6, rouille=(0.09, 0.06, 0.035), usure=0.45, nu=(0.66, 0.6, 0.52), crasse=0.85,
                       crasse_col=(0.02, 0.014, 0.008), graine=7)
    M["ardoise"] = surf("ardoise", (0.06, 0.05, 0.04), rough=0.55, met=0.3, tole=(0.6, 0.32), joint=0.35, joint_l=0.03, var=0.25, usure=0.6, nu=(0.16, 0.14, 0.11),
                        crasse=0.7, crasse_col=(0.004, 0.003, 0.002), relief=0.6, graine=8)
    M["chaine"] = surf("chaine", (0.12, 0.085, 0.05), rough=0.42, met=0.7, coulures=0.3, rouille=(0.05, 0.1, 0.08), usure=0.8, nu=(0.55, 0.47, 0.34), crasse=0.5,
                       crasse_col=(0.006, 0.005, 0.004), graine=9)
    M["pierre"] = surf("pierre", (0.13, 0.095, 0.058), rough=0.85, met=0.0, tole=(1.55, 1.05), joint=0.55, joint_l=0.012, var=0.14, coulures=0.5, rouille=(0.025, 0.016, 0.01),
                       usure=0.7, nu=(0.2, 0.16, 0.12), crasse=0.85, crasse_col=(0.006, 0.005, 0.004), relief=0.4, graine=10)
    M["terre"] = surf("terre", (0.14, 0.085, 0.045), rough=0.95, met=0.0, usure=0.2, nu=(0.2, 0.13, 0.08), crasse=0.8, crasse_col=(0.03, 0.018, 0.01), graine=11)
    M["verre"] = MT.verre("bo_verre", col=(0.012, 0.01, 0.007), reflet=(0.2, 0.16, 0.09))
    M["vitrail"] = S.mat_emissive("bo_vitrail", (1.0, 0.62, 0.2), strength=1.05, base=(0.08, 0.05, 0.015), main_scale=0.3, crust=(3.0, 0.45, 2))
    M["hublot"] = MT.lumiere(S, "bo_vitrail_h", (1.0, 0.76, 0.4), 1.05, main=0.25)
    M["cristal"] = MT.lumiere(S, "bo_cristal", (1.0, 0.86, 0.52), 1.5, main=0.35)
    M["halo"] = MT.lumiere(S, "bo_halo", (1.0, 0.82, 0.48), 1.15, main=0.3)
    M["coeur"] = MT.lumiere(S, "bo_battant_c", (1.0, 0.8, 0.42), 1.6, main=0.4)
    # lot MEGA-BOURDON (11/11) : charte du DC « blindage sombre iridescent, anneaux de lévitation magnétique, cœurs et conduits à vortex cyan »
    M["blindage"] = surf("blindage", (0.022, 0.03, 0.045), rough=0.26, met=0.88, tole=(2.4, 1.6), joint=0.42, joint_l=0.018, var=0.2, usure=0.35,
                         nu=(0.3, 0.36, 0.48), crasse=0.45, crasse_col=(0.003, 0.004, 0.006), relief=0.55, graine=21)
    M["blindage2"] = surf("blindage2", (0.035, 0.022, 0.05), rough=0.26, met=0.88, tole=(2.4, 1.6), joint=0.42, joint_l=0.018, var=0.2, usure=0.35,
                          nu=(0.4, 0.3, 0.5), crasse=0.45, crasse_col=(0.004, 0.003, 0.006), relief=0.55, graine=22)
    M["canon"] = surf("canon", (0.03, 0.032, 0.036), rough=0.32, met=0.92, usure=0.5, nu=(0.42, 0.44, 0.48), crasse=0.6, crasse_col=(0.004, 0.004, 0.004), graine=23)
    M["aimant"] = surf("aimant", (0.016, 0.02, 0.028), rough=0.3, met=0.85, tole=(1.2, 0.5), joint=0.5, joint_l=0.02, var=0.15, usure=0.3,
                       nu=(0.25, 0.3, 0.38), crasse=0.4, crasse_col=(0.003, 0.003, 0.004), graine=24)
    M["vortex"] = MT.lumiere(S, "bo_vortex", (0.3, 0.92, 1.0), 2.2, main=0.45)
    if variante == "mega" or variante.startswith("tourelle-"):
        M["bronze"] = surf("mg_corps", (0.03, 0.036, 0.05), rough=0.3, met=0.85, tole=(3.1, 2.1), joint=0.45, joint_l=0.012, var=0.18, coulures=0.4,
                           rouille=(0.02, 0.05, 0.07), usure=0.4, nu=(0.32, 0.38, 0.5), crasse=0.6, crasse_col=(0.003, 0.004, 0.006), relief=0.5, graine=31)
        M["bronze2"] = surf("mg_corps2", (0.04, 0.026, 0.055), rough=0.32, met=0.85, coulures=0.35, usure=0.45, nu=(0.36, 0.3, 0.48), crasse=0.6,
                            crasse_col=(0.003, 0.003, 0.005), graine=32)
        M["vitrail"] = S.mat_emissive("bo_vitrail_mega", (0.25, 0.85, 1.0), strength=1.1, base=(0.01, 0.05, 0.07), main_scale=0.3, crust=(3.0, 0.45, 2))
        M["hublot"] = MT.lumiere(S, "bo_vitrail_h_mega", (0.35, 0.9, 1.0), 1.05, main=0.25)
    return M


def anneau_s(lot, m, z, ep, h, n=256):
    """Cordon en relief posé sur la cloche à la hauteur z (épaisseur ep, hauteur h)."""
    r0, r1 = rz(z - h / 2), rz(z + h / 2)
    prof = [(z - h / 2, r0 - 0.2), (z - h / 2, r0 + ep * 0.8), (z - h * 0.3, r0 + ep), (z + h * 0.3, r1 + ep), (z + h / 2, r1 + ep * 0.8), (z + h / 2, r1 - 0.2)]
    lot.put(m, G.tour(prof, n, "z"))


def cloche(lot, M):
    """Le fût de bronze et sa bouche sombre."""
    lot.put(M["bronze"], G.tour(_lisse(), 300, "z"))
    # bouche : intérieur sombre, lèvre épaisse
    prof = [(Z_LEVRE, 14.2), (Z_LEVRE - 0.2, 14.0), (Z_LEVRE - 0.1, 13.3), (Z_LEVRE + 1.2, 11.8), (Z_LEVRE + 5.0, 8.6), (Z_LEVRE + 12.0, 6.2), (Z_LEVRE + 20.0, 0.0)]
    lot.put(M["noyau"], G.tour(prof, 240, "z"))
    for (z, ep, h, m) in ((Z_LEVRE + 0.72, 0.55, 0.7, "or"), (Z_LEVRE + 2.2, 0.26, 0.26, "or_sombre"), (Z_LEVRE + 3.9, 0.3, 0.28, "or"), (Z_LEVRE + 5.8, 0.2, 0.2, "or_sombre"),
                          (Z_LEVRE + 13.0, 0.34, 0.34, "or"), (Z_LEVRE + 13.6, 0.18, 0.14, "or_sombre"), (Z_LEVRE + 20.0, 0.36, 0.4, "or"), (Z_LEVRE + 22.4, 0.3, 0.3, "or_sombre")):
        anneau_s(lot, M[m], z, ep, h)


def cotes(lot, M, r):
    """Côtes de nacre le long du profil (vues seulement) : 12 maîtresses, sculptées de pinacles, 24 secondaires."""
    for k in range(36):
        az = G.TAU * k / 36.0
        if not vu(az, 0.6):
            continue
        maitre = k % 3 == 0
        w = 0.5 if maitre else 0.16
        e = 0.42 if maitre else 0.16
        z0 = Z_LEVRE + 1.1 if maitre else Z_LEVRE + 2.3
        z1 = Z_LEVRE + 22.6 if maitre else Z_LEVRE + 19.8
        nz = 30
        rings = []
        for i in range(nz + 1):
            z = z0 + (z1 - z0) * i / float(nz)
            n_h = (math.cos(az), math.sin(az), 0.0)
            t = (-math.sin(az), math.cos(az), 0.0)
            ww = w * (1.25 - 0.45 * i / nz) * (1.25 if maitre and i < 3 else 1.0)
            p = S_pt(az, z, -0.1)
            ee = e * (1.25 - 0.4 * i / nz)
            rings.append([G.sub(p, G.mul(t, ww)), G.add(G.add(p, G.mul(n_h, ee)), G.mul(t, -ww * 0.55)), G.add(G.add(p, G.mul(n_h, ee)), G.mul(t, ww * 0.55)),
                          G.add(p, G.mul(t, ww))])
        lot.put(M["nacre"] if maitre else M["nacre2"], G.loft(rings, True, True))
        if maitre:
            # bagues d'or sur la côte, pinacle en tête, gargouille au pied
            for z in (Z_LEVRE + 6.2, Z_LEVRE + 10.4, Z_LEVRE + 16.4):
                p = S_pt(az, z, 0.1)
                lot.put(M["or"], G.oriente(G.boite((0, 0, 0.14), (1.2, 0.36, 0.42)), p, normale(az, z)))
            p = S_pt(az, Z_LEVRE + 1.2, 0.2)
            lot.put(M["or_sombre"], G.oriente(G.prisme(R.octo((0, 0), 0.5, 6), 0.0, 1.4, top_scale=0.28), p, G.norm((math.cos(az), math.sin(az), -0.35))))


def _lancette(lot, Mcad, Mv, az, z, w, h, Mfil):
    """Lancette gothique : ébrasement, arc brisé, vitrail, meneau."""
    n = normale(az, z + h / 2)
    p = S_pt(az, z + h / 2, 0.04)
    up = (0.0, 0.0, 1.0)
    # ébrasement sombre et cadre
    cad = G.merge(G.boite((0, -h * 0.13, 0.05), (w * 1.28, h * 0.72, 0.14)),
                  G.prisme([(-w * 0.64, h * 0.23), (w * 0.64, h * 0.23), (w * 0.3, h * 0.43), (-w * 0.3, h * 0.43)], 0.0, 0.14))
    v, f, u = cad
    # (prisme modélisé dans le plan XY, z sortant : pose() l'oriente)
    lot.put(Mcad, R.pose((v, f, u), p, n, up))
    vit = G.merge(G.boite((0, -h * 0.13, 0.15), (w, h * 0.68, 0.02)), G.prisme([(-w * 0.5, h * 0.21), (w * 0.5, h * 0.21), (w * 0.18, h * 0.4), (-w * 0.18, h * 0.4)], 0.14, 0.16))
    lot.put(Mv, R.pose(vit, p, n, up))
    mene = G.merge(G.boite((0, 0, 0.18), (w * 0.07, h * 0.82, 0.05)), G.boite((0, -h * 0.05, 0.18), (w * 1.0, h * 0.04, 0.05)), G.boite((0, -h * 0.28, 0.18), (w * 1.0, h * 0.04, 0.05)))
    lot.put(Mfil, R.pose(mene, p, n, up))


def fenetres(lot, M, r):
    """Registres de lancettes entre les côtes, rangée de petites baies (l'échelle), frises."""
    for k in range(24):
        az = G.TAU * (k + 0.5) / 12.0 / 2.0
        if not vu(az, 0.55):
            continue
        if k % 2 == 0:
            for dz in (-0.42, 0.0, 0.42):
                _lancette(lot, M["bronze2"], M["vitrail"], az + dz / 10.0 * 1.2, Z_LEVRE + 6.5, 0.64, 3.6, M["or_sombre"])
        # registre haut : hautes lancettes sous le cordon
        for dz in (-0.5, 0.5):
            _lancette(lot, M["bronze2"], M["vitrail"], az + dz / 9.2 * 1.4, Z_LEVRE + 14.4, 0.82, 4.9, M["or_sombre"])
    # petites baies du registre bas (une centaine, éteintes pour certaines)
    formes = ["ogive", "carre", "fente", "double", "rond", "octo"]
    n = 170
    for i in range(n):
        az = G.TAU * i / n
        if not vu(az, 0.5):
            continue
        for z, ouv in ((Z_LEVRE + 4.8, 0.74), (Z_LEVRE + 11.4, 0.66)):
            if r.f() > ouv:
                continue
            R.hublot(lot, M["or_sombre"], M["hublot"] if r.f() < 0.72 else M["verre"], S_pt(az, z, 0.02), normale(az, z), formes[r.i(0, 5)], t=r.f(0.14, 0.2))
    # frise de la pince : une « inscription », losanges et croix d'or
    n = 150
    for i in range(n):
        az = G.TAU * i / n
        if not vu(az, 0.55):
            continue
        z = Z_LEVRE + 2.92
        x = i % 5
        m = G.boite((0, 0, 0.1), (0.3, 0.48, 0.16), rz=math.pi / 4) if x in (0, 2) else G.boite((0, 0, 0.08), (0.14, 0.62, 0.12)) if x == 1 else G.prisme([(-0.2, -0.28), (0.2, -0.28), (0.1, 0.3), (-0.1, 0.3)], 0.0, 0.14)
        lot.put(M["or"] if x != 3 else M["or_sombre"], R.pose(m, S_pt(az, z), normale(az, z)))
    # arcature sous la terrasse
    n = 96
    for i in range(n):
        az = G.TAU * i / n
        if not vu(az, 0.55):
            continue
        z = Z_LEVRE + 21.0
        lot.put(M["or_sombre"], R.pose(G.merge(G.boite((0, 0, 0.08), (0.12, 0.8, 0.14)), G.boite((0, 0.44, 0.08), (0.42, 0.1, 0.14))), S_pt(az, z), normale(az, z)))


def rosace(lot, M, az, z, ray):
    """Rosace : disque de vitrail, 2 couronnes de pierre, 12 meneaux, 12 médaillons."""
    n = normale(az, z)
    p = S_pt(az, z, 0.05)
    lot.put(M["or"], R.pose(G.tour([(0.0, ray + 0.42), (0.42, ray + 0.34), (0.5, ray + 0.12), (0.26, ray), (0.26, ray - 0.2)], 72, "z"), p, n))
    lot.put(M["noyau"], R.pose(G.tour([(0.1, ray + 0.02), (0.1, 0.0)], 72, "z"), p, n))
    lot.put(M["vitrail"], R.pose(G.tour([(0.2, ray - 0.02), (0.2, 0.0)], 72, "z"), p, n))
    for i in range(12):
        a = G.TAU * i / 12.0
        ca, sa = math.cos(a), math.sin(a)
        lot.put(M["nacre"], R.pose(G.tube([(ca * 0.55, sa * 0.55, 0.3), (ca * ray, sa * ray, 0.3)], 0.075, 6), p, n))
        q = (ca * ray * 0.68, sa * ray * 0.68, 0.32)
        lot.put(M["or_sombre"], R.pose(G.tour([(-0.08, 0.34), (0.08, 0.34), (0.08, 0.26), (-0.08, 0.26), (-0.08, 0.34)], 16, "z", q), p, n))
    lot.put(M["or"], R.pose(G.tour([(0.25, 0.62), (0.45, 0.45), (0.5, 0.0)], 24, "z", cap0=True), p, n))
    lot.put(M["nacre"], R.pose(G.tour([(0.26, ray * 0.48), (0.36, ray * 0.48), (0.36, ray * 0.42), (0.26, ray * 0.42), (0.26, ray * 0.48)], 48, "z"), p, n))


def rampe(lot, M, r):
    """Rampe hélicoïdale autour de la faussure : une marche à l'échelle d'un personnage, garde-corps, arcs-boutants."""
    z0, z1 = Z_LEVRE + 4.3, Z_LEVRE + 20.2
    tours = 2.1
    az0 = -0.3
    n = 200
    rings, pts = [], []
    for i in range(n + 1):
        t = i / float(n)
        az = az0 + G.TAU * tours * t
        z = z0 + (z1 - z0) * t
        rr = rz(z)
        ca, sa = math.cos(az), math.sin(az)
        rings.append([((rr - 0.1) * ca, (rr - 0.1) * sa, z), ((rr + 1.0) * ca, (rr + 1.0) * sa, z), ((rr + 1.0) * ca, (rr + 1.0) * sa, z - 0.18), ((rr - 0.1) * ca, (rr - 0.1) * sa, z - 0.18)])
        pts.append(((rr + 0.96) * ca, (rr + 0.96) * sa, z))
    lot.put(M["ardoise"], G.loft(rings, True, True))
    for i in range(0, n, 8):
        a0, a1 = pts[i], pts[min(n, i + 8)]
        if vu(math.atan2(a0[1], a0[0]), 0.65):
            R.garde_corps(lot, M["or_sombre"], [a0, a1], h=0.42, pas=0.42, r=0.03)
    for i in range(0, n, 5):
        az = az0 + G.TAU * tours * i / float(n)
        if not vu(az, 0.6):
            continue
        z = z0 + (z1 - z0) * i / float(n)
        rr = rz(z)
        ca, sa = math.cos(az), math.sin(az)
        lot.put(M["bronze2"], G.tube([((rr + 0.85) * ca, (rr + 0.85) * sa, z - 0.18), (rz(z - 1.5) * ca, rz(z - 1.5) * sa, z - 1.5)], 0.08, 6))


def terrasse_couronne(lot, M, r):
    """Terrasse à pinacles, dôme d'ardoise, anses, couronne de flèches, anneau-halo."""
    zt = Z_LEVRE + 21.8
    RT = rz(zt)
    lot.put(M["bronze2"], G.tour([(zt - 0.9, RT + 0.1), (zt - 0.1, RT + 1.1), (zt, RT + 1.7), (zt + 0.22, RT + 1.7), (zt + 0.22, RT - 0.7)], 160, "z"))
    lot.put(M["pierre"], G.tour([(zt + 0.22, RT + 1.5), (zt + 0.3, RT + 1.5), (zt + 0.3, RT - 0.7)], 120, "z"))
    n = 32
    pts = [((RT + 1.45) * math.cos(G.TAU * i / n), (RT + 1.45) * math.sin(G.TAU * i / n), zt + 0.3) for i in range(n + 1)]
    R.garde_corps(lot, M["or_sombre"], pts, h=0.46, pas=0.55, r=0.035)
    for i in range(12):
        az = G.TAU * i / 12.0
        c = ((RT + 1.3) * math.cos(az), (RT + 1.3) * math.sin(az))
        R.fleche(lot, M["bronze2"], M["or"], M["nacre"], M["verre"], M["cristal"], c, zt - 0.2, 4.4 if i % 2 else 5.8, 0.5 if i % 2 else 0.62, r, etages=3, Mlum=M["hublot"])
    # dôme : côtes d'ardoise entre nervures d'or, lucarnes
    zd = Z_LEVRE + 23.0
    for i in range(24):
        az = G.TAU * i / 24.0
        pp = [S_pt(az, zd + (Z_LEVRE + 26.7 - zd) * t / 10.0, 0.04) for t in range(11)]
        lot.put(M["or"] if i % 3 == 0 else M["or_sombre"], G.tube(pp, 0.13 if i % 3 == 0 else 0.07, 6))
    lot.put(M["ardoise"], G.tour([(z, rz(z) + 0.03) for z in [zd + (Z_LEVRE + 26.9 - zd) * t / 20.0 for t in range(21)]], 200, "z"))
    for i in range(8):
        az = G.TAU * (i + 0.5) / 8.0
        if not vu(az, 0.7):
            continue
        z = Z_LEVRE + 24.1
        n_h = normale(az, z)
        p = S_pt(az, z, 0.1)
        lot.put(M["bronze2"], R.pose(G.boite((0, 0, 0.45), (1.25, 1.1, 0.95)), p, n_h))
        lot.put(M["vitrail"], R.pose(G.boite((0, -0.08, 0.95), (0.76, 0.74, 0.02)), p, n_h))
        lot.put(M["or"], R.pose(G.prisme([(-0.75, 0.52), (0.75, 0.52), (0.0, 1.05)], 0.05, 0.98), p, n_h))
    # couronne : flèche maîtresse et 5 flèches, anses de bronze qui les relient (les « canons » d'une cloche)
    zc = Z_LEVRE + 25.6
    R.fleche(lot, M["bronze2"], M["or"], M["nacre"], M["verre"], M["cristal"], (0.0, 0.0), Z_LEVRE + 26.1, 11.3, 1.5, r, etages=3, Mlum=M["hublot"])
    for i in range(5):
        az = G.TAU * i / 5.0 + math.pi / 2 + math.pi
        c = (3.7 * math.cos(az), 3.7 * math.sin(az))
        tip = R.fleche(lot, M["bronze2"], M["or"], M["nacre"], M["verre"], M["cristal"], c, zc - 0.7, 7.4 if i % 2 == 0 else 5.8, 0.8, r, etages=3, Mlum=M["hublot"])
        arc = []
        for t in range(13):
            u = t / 12.0
            d = 0.8 + 2.6 * u
            arc.append((d * math.cos(az), d * math.sin(az), Z_LEVRE + 29.2 + 1.9 * math.sin(math.pi * u) - 2.0 * u))
        lot.put(M["or"], G.tube(arc, 0.34, 10))
        lot.put(M["bronze2"], G.tube([G.add(p, (0, 0, -0.26)) for p in arc], 0.2, 8))
    # anneau-halo de couronne, en 18 arcs flottants avec perles
    zh = Z_LEVRE + 31.6
    for i in range(18):
        a0 = G.TAU * i / 18.0 + 0.02
        a1 = a0 + G.TAU / 18.0 - 0.05
        prof = [(zh - 0.11, 5.2), (zh - 0.11, 5.52), (zh + 0.11, 5.52), (zh + 0.11, 5.2), (zh - 0.11, 5.2)]
        lot.put(M["or"], G.tour(prof, 8, "z", a0=a0, a1=a1))
        p = (5.36 * math.cos(a1 + 0.018), 5.36 * math.sin(a1 + 0.018), zh)
        lot.put(M["halo"], G.sphere(p, 0.21, 10, 5))


def arcs_boutants(lot, M, r):
    """Arcs-boutants de la faussure vers des pinacles plantés sur la pince : ils cassent la silhouette de soucoupe et font la cathédrale."""
    for k in range(12):
        az = G.TAU * k / 12.0
        if not vu(az, 0.72):
            continue
        ca, sa = math.cos(az), math.sin(az)
        zh, zb = Z_LEVRE + 14.6, Z_LEVRE + 2.4
        ctrl = [(rz(zh) * ca, rz(zh) * sa, zh), ((rz(zh) + 2.6) * ca, (rz(zh) + 2.6) * sa, zh - 1.4), ((rz(zh) + 5.2) * ca, (rz(zh) + 5.2) * sa, zh - 5.6), (14.5 * ca, 14.5 * sa, zb + 2.4)]
        pts = G.catmull(ctrl, 7)
        lot.put(M["nacre"], G.tube(pts, 0.32, 8, rfun=lambda s_, i: 0.36 - 0.012 * s_))
        lot.put(M["or_sombre"], G.tube([G.add(p, (0, 0, -0.34)) for p in pts], 0.14, 6))
        # pinacle sur la pince
        R.fleche(lot, M["bronze2"], M["or"], M["nacre"], M["verre"], M["cristal"], (14.5 * ca, 14.5 * sa), zb - 1.0, 6.6, 0.72, r, etages=3, Mlum=M["hublot"])


def levre(lot, M, r):
    """Sous la lèvre : créneaux, consoles, pointes inversées, cristaux de lévitation, grand anneau-halo flottant."""
    zl = Z_LEVRE + 0.6
    for i in range(72):
        az = G.TAU * i / 72.0
        if i % 2 == 0:
            c = (15.25 * math.cos(az), 15.25 * math.sin(az))
            lot.put(M["or_sombre"], G.oriente(G.boite((0, 0, 0.0), (0.76, 0.46, 0.9)), (c[0], c[1], zl + 0.2), (math.cos(az), math.sin(az), 0.0)))
    # consoles et cristaux
    for i in range(16):
        az = G.TAU * i / 16.0 + 0.1
        ca, sa = math.cos(az), math.sin(az)
        rc = 13.9
        L = 2.6 + 1.6 * ((i * 7) % 3)
        lot.put(M["bronze2"], G.tour([(Z_LEVRE + 0.2, 0.8), (Z_LEVRE - 1.0, 0.65), (Z_LEVRE - 1.6, 0.26)], 10, "z", (rc * ca, rc * sa, 0.0), cap0=True, cap1=True))
        lot.put(M["or"], G.tour([(Z_LEVRE - 0.95, 0.72), (Z_LEVRE - 1.2, 0.72)], 10, "z", (rc * ca, rc * sa, 0.0), cap0=True, cap1=True))
        v, f, u = G.prisme(R.octo((0.0, 0.0), 0.34, 6), Z_LEVRE - 1.6 - L, Z_LEVRE - 1.7, top_scale=2.0 / 3.0)
        lot.put(M["cristal"], ([(q[0] * (1.0 if q[2] > Z_LEVRE - 1.8 else 0.1) + rc * ca, q[1] * (1.0 if q[2] > Z_LEVRE - 1.8 else 0.1) + rc * sa, q[2]) for q in v], f, u))
    # grand anneau-halo, légèrement basculé, en 24 arcs flottants
    tilt = 0.06
    for i in range(24):
        a0 = G.TAU * i / 24.0 + 0.012
        a1 = a0 + G.TAU / 24.0 - 0.03
        prof = [(-0.2, 18.0), (-0.2, 18.9), (0.2, 18.9), (0.2, 18.0), (-0.2, 18.0)]
        v, f, u = G.tour(prof, 14, "z", a0=a0, a1=a1)
        v = [G.add(G.rot_x(q, tilt), (0.0, 0.0, 25.2)) for q in v]
        lot.put(M["or"] if i % 2 else M["nacre"], (v, f, u))
        v, f, u = G.tour([(0.21, 18.25), (0.21, 18.62)], 14, "z", a0=a0 + 0.02, a1=a1 - 0.02)
        v = [G.add(G.rot_x(q, tilt), (0.0, 0.0, 25.2)) for q in v]
        lot.put(M["halo"], (v, f, u))
        p = G.add(G.rot_x((18.45 * math.cos(a1), 18.45 * math.sin(a1), 0.0), tilt), (0.0, 0.0, 25.2))
        lot.put(M["bronze2"], G.sphere(p, 0.42, 10, 5))


ANCRES = [(-math.pi * 0.86, 34.0), (-math.pi * 0.5, 31.0), (-math.pi * 0.14, 34.0), (math.pi * 0.2, 32.0), (math.pi * 0.5, 30.0), (math.pi * 0.8, 32.0)]


def chaines(lot, M, r):
    """6 chaînes tendues vers 6 ancres de pierre et d'or (planches du lot RB-V0 ; en jeu : variantes corps, chaine, ancre, griffes)."""
    for (az, ra) in ANCRES:
        ca, sa = math.cos(az), math.sin(az)
        a = (14.7 * ca, 14.7 * sa, Z_LEVRE + 0.0)
        b = (ra * ca, ra * sa, 3.0)
        # manille et pont sur la lèvre
        lot.put(M["or"], G.oriente(G.boite((0, 0, 0), (1.8, 1.1, 0.9)), G.add(a, (0, 0, 0.1)), (ca, sa, 0.0)))
        d = G.sub(b, a)
        L = G.length(d)
        u = G.norm(d)
        pas = 1.5
        n = int(L / pas)
        fl = 1.6
        pts = []
        for i in range(n + 1):
            t = i / float(n)
            pts.append(G.add(G.lerp(a, b, t), (0.0, 0.0, -fl * 4 * t * (1 - t))))
        for i in range(n):
            p, q = pts[i], pts[i + 1]
            c = G.lerp(p, q, 0.5)
            ax = G.norm(G.sub(q, p))
            e1 = G.norm(G.cross(ax, (0.0, 0.0, 1.0)))
            e2 = G.cross(ax, e1)
            ee = e1 if i % 2 == 0 else e2
            lb, ha = pas * 0.72, 0.42
            boucle = []
            for j in range(14):
                th = G.TAU * j / 14.0
                ct, st = math.cos(th), math.sin(th)
                xx = ct * (lb - ha + ha * 1.0) if abs(ct) > 0.5 else ct * lb
                boucle.append(G.add(c, G.add(G.mul(ax, xx), G.mul(ee, st * ha))))
            boucle.append(boucle[0])
            lot.put(M["chaine"], G.tube(boucle, 0.13, 6, cap0=False, cap1=False))
        # ancre : socle à pans, griffes de pierre levées, soc d'or, éclats de terre
        c = (ra * ca, ra * sa)
        lot.put(M["pierre"], G.prisme(R.octo(c, 2.8, 8), 0.0, 1.7, top_scale=0.72))
        lot.put(M["bronze2"], G.prisme(R.octo(c, 2.0, 8), 1.7, 2.6, top_scale=0.72))
        lot.put(M["or"], G.prisme(R.octo(c, 2.15, 8), 1.65, 1.86))
        lot.put(M["or"], G.tour([(2.6, 1.3), (3.1, 0.95), (3.5, 0.35), (3.5, 0.0)], 16, "z", (c[0], c[1], 0.0), cap0=True))
        lot.put(M["halo"], G.sphere((c[0], c[1], 3.45), 0.24, 10, 5))
        rr = G.Rnd(int(ra * 11 + (az + 4) * 31))
        for i in range(11):
            th = G.TAU * i / 11.0 + rr.f(0, 0.4)
            q = (c[0] + (3.2 + rr.f(0.2, 2.2)) * math.cos(th), c[1] + (3.2 + rr.f(0.2, 2.2)) * math.sin(th), 0.0)
            R.eclat(lot, M["terre"] if i % 3 else M["pierre"], q, rr.f(0.7, 2.0), rr.f(0.35, 0.8), rr, inc=0.5)


def rochers(lot, M, r):
    """Rochers arrachés au sol, en lévitation sous la cloche (ils s'élèvent en spirale, en jeu : compagnons animés)."""
    for i in range(16):
        th = G.TAU * i * 0.382 + 0.5
        rad = r.f(4.5, 16.0)
        z = r.f(6.0, 22.0) + 0.5
        s = r.f(0.6, 1.9)
        c = (rad * math.cos(th), rad * math.sin(th), z)
        verts = []
        rr = G.Rnd(70 + i)
        v, f, u = G.sphere((0.0, 0.0, 0.0), s, 8, 5)
        ph = (rr.f(0, 6), rr.f(0, 6), rr.f(0, 6))
        for q in v:
            k = 1.0 + 0.32 * math.sin(q[0] * 2.3 / s + ph[0]) * math.sin(q[1] * 3.1 / s + ph[1]) + 0.2 * math.sin(q[2] * 3.7 / s + ph[2])
            verts.append(G.add(c, (q[0] * k, q[1] * k * 0.9, q[2] * k * 0.7)))
        lot.put(M["terre"] if i % 3 else M["pierre"], (verts, f, u))
        # racines de terre qui pendent
        for j in range(3):
            d = (rr.f(-0.5, 0.5) * s, rr.f(-0.5, 0.5) * s)
            lot.put(M["terre"], G.tour([(z - 0.3 * s, 0.26 * s), (z - s * rr.f(0.9, 1.5), 0.0)], 5, "z", (c[0] + d[0], c[1] + d[1], 0.0), cap0=True))


def manilles(lot, M):
    """Les 6 ponts d'or sur la lèvre (lot BOURDON, 1er/11) : la chaîne en jeu en sort, elle est dessinée à part."""
    for (az, _) in ANCRES:
        ca, sa = math.cos(az), math.sin(az)
        a = (14.7 * ca, 14.7 * sa, Z_LEVRE + 0.0)
        lot.put(M["or"], G.oriente(G.boite((0, 0, 0), (1.8, 1.1, 0.9)), G.add(a, (0, 0, 0.1)), (ca, sa, 0.0)))


def chaine_seule(lot, M, longueur=36.0):
    """Une chaîne droite dans le plan de l'écran (axe (0, -√½, -√½) : vue sans raccourci), `longueur` tuiles à l'écran. En jeu : 1 image tournée
    vers chaque ancre, glissée dans la cloche quand elle se replie."""
    u = (0.0, -math.sqrt(0.5), -math.sqrt(0.5))
    pas = 1.5
    n = int(longueur / pas)
    haut = (0.0, 0.0, longueur * math.sqrt(0.5) + 4.0)
    for i in range(n):
        c = G.add(haut, G.mul(u, (i + 0.5) * pas))
        e1 = (1.0, 0.0, 0.0)
        e2 = G.cross(u, e1)
        ee = e1 if i % 2 == 0 else e2
        lb, ha = pas * 0.72, 0.42
        boucle = []
        for j in range(14):
            th = G.TAU * j / 14.0
            ct, st = math.cos(th), math.sin(th)
            xx = ct * (lb - ha + ha * 1.0) if abs(ct) > 0.5 else ct * lb
            boucle.append(G.add(c, G.add(G.mul(u, xx), G.mul(ee, st * ha))))
        boucle.append(boucle[0])
        lot.put(M["chaine"], G.tube(boucle, 0.13, 6, cap0=False, cap1=False))


def ancre_seule(lot, M):
    """L'ancre en jeu : socle à pans, soc d'or, tête lumineuse, sans les griffes de terre (elles restent au sol quand elle remonte)."""
    c = (0.0, 0.0)
    lot.put(M["pierre"], G.prisme(R.octo(c, 2.8, 8), 0.0, 1.7, top_scale=0.72))
    lot.put(M["bronze2"], G.prisme(R.octo(c, 2.0, 8), 1.7, 2.6, top_scale=0.72))
    lot.put(M["or"], G.prisme(R.octo(c, 2.15, 8), 1.65, 1.86))
    lot.put(M["or"], G.tour([(2.6, 1.3), (3.1, 0.95), (3.5, 0.35), (3.5, 0.0)], 16, "z", (c[0], c[1], 0.0), cap0=True))
    lot.put(M["halo"], G.sphere((c[0], c[1], 3.45), 0.24, 10, 5))


def griffes_seules(lot, M):
    """Les griffes de terre et de pierre levées par l'ancre à l'impact : posées au sol, elles restent un moment."""
    rr = G.Rnd(341)
    for i in range(11):
        th = G.TAU * i / 11.0 + rr.f(0, 0.4)
        q = ((3.2 + rr.f(0.2, 2.2)) * math.cos(th), (3.2 + rr.f(0.2, 2.2)) * math.sin(th), 0.0)
        R.eclat(lot, M["terre"] if i % 3 else M["pierre"], q, rr.f(0.7, 2.0), rr.f(0.35, 0.8), rr, inc=0.5)


def battant(lot, M):
    """Le battant : tige à colliers, poire de nacre et d'or à cœur lumineux (rendu à part, il oscille à l'écran)."""
    zp = Z_LEVRE + 7.0
    lot.put(M["bronze2"], G.tour([(9.0, 0.8), (zp, 0.8)], 24, "z", cap0=True, cap1=True))
    for z in (12.0, 16.0, 20.0, 24.0, 28.0, 32.0):
        lot.put(M["or"], G.tour([(z - 0.3, 0.9), (z - 0.18, 1.2), (z + 0.18, 1.2), (z + 0.3, 0.9)], 24, "z", cap0=True, cap1=True))
    prof = [(1.8, 0.0), (2.2, 1.0), (3.4, 2.6), (5.0, 3.5), (7.0, 3.7), (9.0, 3.2), (10.4, 2.1), (11.4, 1.1)]
    lot.put(M["nacre2"], G.tour(prof, 64, "z"))
    for (z, ep, m) in ((4.2, 3.28, "or"), (8.8, 3.34, "or"), (6.4, 3.84, "or_sombre")):
        lot.put(M[m], G.tour([(z - 0.3, ep - 0.1), (z - 0.2, ep + 0.14), (z + 0.2, ep + 0.14), (z + 0.3, ep - 0.1)], 64, "z"))
    for i in range(12):
        a = G.TAU * i / 12.0
        p = (3.76 * math.cos(a), 3.76 * math.sin(a), 6.4)
        lot.put(M["coeur"], G.oriente(G.tour([(0.0, 0.36), (0.3, 0.26), (0.36, 0.0)], 10, "z", cap0=True), p, (math.cos(a), math.sin(a), 0.0)))
    lot.put(M["or"], G.tour([(0.8, 0.0), (1.3, 0.3), (2.1, 1.0)], 20, "z"))


# ------------------------------------------------------------------------------------------------ le Méga-Bourdon (lot MEGA-BOURDON, 11/11)
# La même cloche (même lèvre : les 6 chaînes et ancres du Bourdon s'y attachent), cuirassée : corps en acier sombre irisé, vitraux cyan,
# ceinture de plaques taillées sur la faussure, épaulières, anneau de lévitation magnétique sous la lèvre, et 4 casemates en arc avant.
# Sur chaque casemate, une TOURELLE lourde (canons jumeaux à plasma, cœur à vortex cyan) rendue À PART en 16 directions (variantes
# « tourelle-00 » à « tourelle-15 ») : en jeu elle pivote vers sa cible (script/robots/bourdon.lua). Le lot de rendu projette les pivots
# (MEGA_PIVOTS) dans render.json : « canons » (pivot à l'écran, d'où partent les orbes) et « canons_sol » (le point du sol sous le pivot,
# origine des feuilles de tourelle), en tuiles depuis la position au sol de la cloche.
MEGA_CANONS = [-math.pi * 0.92, -math.pi * 0.64, -math.pi * 0.36, -math.pi * 0.08]
Z_CASEMATE = Z_LEVRE + 9.0
H_CAISSON = 2.6
MEGA_PIVOTS = []
N_DIR_TOURELLE = 16


def _quad(verts, faces, uvs, a, b, c, d):
    base = len(verts)
    verts += [a, b, c, d]
    uvs += [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    faces.append((base, base + 1, base + 2, base + 3))


def plaque(az0, az1, z0, z1, d0, ep, biseau):
    """Plaque taillée posée sur la cloche, d'az0 à az1 et de z0 à z1, à d0 de la surface, épaisse de ep ; sa face extérieure est rentrée de
    biseau (en fraction) : arêtes chanfreinées, aspect taillé."""
    i00, i10, i11, i01 = S_pt(az0, z0, d0), S_pt(az1, z0, d0), S_pt(az1, z1, d0), S_pt(az0, z1, d0)
    da, dz = (az1 - az0) * biseau, (z1 - z0) * biseau
    o00, o10 = S_pt(az0 + da, z0 + dz, d0 + ep), S_pt(az1 - da, z0 + dz, d0 + ep)
    o11, o01 = S_pt(az1 - da, z1 - dz * 0.6, d0 + ep * 0.8), S_pt(az0 + da, z1 - dz * 0.6, d0 + ep * 0.8)
    v, f, u = [], [], []
    _quad(v, f, u, o00, o10, o11, o01)
    _quad(v, f, u, i01, i11, i10, i00)
    _quad(v, f, u, i00, i10, o10, o00)
    _quad(v, f, u, i10, i11, o11, o10)
    _quad(v, f, u, i11, i01, o01, o11)
    _quad(v, f, u, i01, i00, o00, o01)
    return v, f, u


def blindage(lot, M):
    """Ceinture de 24 plaques sur la faussure, en deux rangs décalés, et une épaulière au-dessus de chaque casemate."""
    n = 24
    for rang, (z0, z1, dec) in enumerate(((Z_LEVRE + 1.5, Z_LEVRE + 4.4, 0.0), (Z_LEVRE + 4.0, Z_LEVRE + 7.2, 0.5))):
        for k in range(n):
            a0 = G.TAU * (k + dec) / n + 0.012
            a1 = G.TAU * (k + 1 + dec) / n - 0.012
            if not vu((a0 + a1) / 2, 0.75):
                continue
            m = M["blindage"] if (k + rang) % 2 == 0 else M["blindage2"]
            lot.put(m, plaque(a0, a1, z0, z1, 0.15 + 0.2 * rang, 0.55, 0.12))
    for az in MEGA_CANONS:
        lot.put(M["blindage2"], plaque(az - 0.3, az + 0.3, Z_CASEMATE + 4.2, Z_CASEMATE + 8.2, 0.25, 0.85, 0.16))


def pivot(az):
    """Pivot d'une tourelle (monde) : sur le toit du caisson de la casemate d'azimut az."""
    ca, sa = math.cos(az), math.sin(az)
    r0 = rz(Z_CASEMATE)
    return (r0 * ca + ca * 1.7, r0 * sa + sa * 1.7, Z_CASEMATE + H_CAISSON)


def casemate(lot, M, az):
    """Casemate fixe : caisson anguleux en console sur l'épaule (il porte la tourelle), cœur à vortex sur sa face, conduits cyan jusqu'à la lèvre."""
    ca, sa = math.cos(az), math.sin(az)
    n = (ca, sa, 0.0)
    zc = Z_CASEMATE
    r0 = rz(zc)
    c = (r0 * ca, r0 * sa, zc)
    # caisson : bloc taillé de 4 × 4,2 tuiles, assis sur la cloche, toit plat où pivote la tourelle
    pv = pivot(az)
    poly = [(-2.0, -1.6), (2.0, -1.6), (2.3, 0.6), (1.3, 2.1), (-1.3, 2.1), (-2.3, 0.6)]
    v, f, u = G.prisme(poly, 0.0, H_CAISSON, top_scale=0.86)
    v = [(q[0], q[1], q[2]) for q in v]
    # repère du caisson : son +y local vers l'extérieur (normale), +x tangent ; posé au pied du pivot
    t = (-sa, ca, 0.0)
    v = [G.add((pv[0], pv[1], zc), G.add(G.mul(t, -q[0]), G.add(G.mul(n, q[1]), (0.0, 0.0, q[2])))) for q in v]
    lot.put(M["blindage"], (v, f, u))
    # console sous le caisson, jusqu'à la cloche
    lot.put(M["aimant"], G.oriente(G.prisme(R.octo((0.0, 0.0), 1.3, 6), 0.0, 2.2, top_scale=0.7), G.add(c, (0.0, 0.0, -1.6)), G.norm((ca, sa, 0.6))))
    # cœur à vortex sur la face extérieure du caisson
    face = G.add((pv[0], pv[1], zc + H_CAISSON * 0.45), G.mul(n, 2.05))
    lot.put(M["aimant"], G.oriente(G.tour([(0.0, 0.45), (0.0, 0.95), (0.3, 0.95), (0.3, 0.45), (0.0, 0.45)], 24, "z"), face, n))
    lot.put(M["vortex"], G.oriente(G.tour([(0.06, 0.55), (0.06, 0.85), (0.26, 0.85), (0.26, 0.55), (0.06, 0.55)], 24, "z"), G.add(face, G.mul(n, 0.02)), n))
    lot.put(M["vortex"], G.oriente(G.sphere((0.0, 0.0, 0.0), 0.32, 12, 6), G.add(face, G.mul(n, 0.12)), n))
    # conduits cyan de la casemate à la lèvre
    for k in (-1, 1):
        a = az + 0.12 * k
        pts = [S_pt(a, z, 0.32) for z in (zc - 0.4, zc - 2.5, zc - 4.5, zc - 6.5, Z_LEVRE + 1.3)]
        lot.put(M["vortex"], G.tube(pts, 0.12, 8))
        lot.put(M["aimant"], G.tube([S_pt(a, z, 0.2) for z in (zc - 0.4, zc - 2.5, zc - 4.5, zc - 6.5, Z_LEVRE + 1.3)], 0.22, 8))


def anneau_magnetique(lot, M):
    """Anneau de lévitation magnétique sous la lèvre : 18 voussoirs sombres cerclés d'un liseré cyan sur leur tranche extérieure."""
    zc = Z_LEVRE - 3.4
    for i in range(18):
        a0 = G.TAU * i / 18.0 + 0.02
        a1 = a0 + G.TAU / 18.0 - 0.05
        lot.put(M["aimant"], G.tour([(zc - 0.55, 15.6), (zc - 0.55, 17.1), (zc + 0.55, 17.1), (zc + 0.55, 15.6), (zc - 0.55, 15.6)], 10, "z", a0=a0, a1=a1))
        lot.put(M["vortex"], G.tour([(zc - 0.14, 17.12), (zc + 0.14, 17.12)], 10, "z", a0=a0 + 0.03, a1=a1 - 0.03))
        lot.put(M["vortex"], G.tour([(zc + 0.56, 16.1), (zc + 0.56, 16.6)], 10, "z", a0=a0 + 0.05, a1=a1 - 0.05))


def tourelle(lot, M, k):
    """Tourelle lourde, direction k sur 16 (0 = nord, sens des aiguilles ; monde : +y nord, +x est) : masque taillé, canons jumeaux à plasma
    légèrement plongeants, frettes et bouches cyan, cœur à vortex sur la culasse. Posée au-dessus de l'origine, à la hauteur d'un pivot (le
    jeu la place sur le pivot de sa casemate : feuilles_mega.py, « canons_sol »)."""
    th = G.TAU * k / float(N_DIR_TOURELLE)
    h = Z_CASEMATE + H_CAISSON

    def xf(q):
        p = G.rot_z(q, -th)
        return (p[0], p[1], p[2] + h)

    # embase tournante
    lot.put(M["aimant"], G.tour([(0.0, 1.55), (0.35, 1.55), (0.45, 1.35), (0.45, 0.0)], 32, "z", cap1=True), xf)
    lot.put(M["vortex"], G.tour([(0.12, 1.57), (0.24, 1.57)], 32, "z"), xf)
    # masque taillé : prisme en coin, nez vers +y
    poly = [(-1.5, -1.6), (1.5, -1.6), (1.7, 0.2), (0.9, 1.9), (-0.9, 1.9), (-1.7, 0.2)]
    v, f, u = G.prisme(poly, 0.45, 2.0, top_scale=0.7, top_shift=(0.0, -0.25))
    lot.put(M["blindage"], (v, f, u), xf)
    lot.put(M["blindage2"], G.boite((0.0, -1.2, 2.15), (2.0, 1.2, 0.35)), xf)
    # cœur à vortex sur la culasse (arrière, vers -y)
    lot.put(M["aimant"], G.oriente(G.tour([(0.0, 0.35), (0.0, 0.8), (0.25, 0.8), (0.25, 0.35), (0.0, 0.35)], 24, "z"), (0.0, -1.65, 1.25), (0.0, -1.0, 0.0)), xf)
    lot.put(M["vortex"], G.oriente(G.tour([(0.04, 0.45), (0.04, 0.72), (0.2, 0.72), (0.2, 0.45), (0.04, 0.45)], 24, "z"), (0.0, -1.67, 1.25), (0.0, -1.0, 0.0)), xf)
    # canons jumeaux, plongée de 12°
    d = G.norm((0.0, 0.978, -0.208))
    for sx in (-0.62, 0.62):
        o = (sx, 1.4, 1.25)
        lot.put(M["canon"], G.oriente(G.tour([(0.0, 0.42), (1.2, 0.42), (1.3, 0.36), (5.6, 0.32)], 18, "z", cap0=True, cap1=True), o, d), xf)
        for z0 in (1.6, 3.0, 4.4):
            lot.put(M["aimant"], G.oriente(G.tour([(z0, 0.44), (z0 + 0.3, 0.44)], 18, "z", cap0=True, cap1=True), o, d), xf)
            lot.put(M["vortex"], G.oriente(G.tour([(z0 + 0.1, 0.455), (z0 + 0.2, 0.455)], 18, "z"), o, d), xf)
        lot.put(M["canon"], G.oriente(G.tour([(5.3, 0.5), (6.2, 0.5)], 18, "z", cap0=True, cap1=True), o, d), xf)
        lot.put(M["vortex"], G.oriente(G.tour([(6.18, 0.24), (6.24, 0.24)], 14, "z", cap0=True, cap1=True), o, d), xf)


# Lot ART-MEGA2 (11/11, ordre du DC de 9 h 47) : « une taille strictement 2 fois supérieure (minimum 200 % à 250 % de l'échelle du Bourdon) ;
# plaques de blindage angulaires lourdes et une double paire de réacteurs à impulsion cyan ». Le modèle reste celui du Bourdon (même lèvre) ;
# l'ÉCHELLE est celle du rendu : rendre.py --px (MEGA_ECHELLE × 40) rend la même géométrie 2,2 fois plus grande à 40 px par tuile du jeu
# (feuilles_mega.py lit px / MEGA_ECHELLE), et le jeu multiplie par shared/robots/bourdon.lua B.MEGA.ECHELLE (même valeur, vérifiée par
# tests/megabourdon_test.lua sur sprites.lua) tout ce qu'il emprunte au Bourdon : chaînes, ancres, battant, boîtes.
MEGA_ECHELLE = 2.2
# réacteurs : (azimut, hauteur du bas de la tuyère, écart radial du profil de la cloche, rayon, longueur) ; deux paires, est et ouest
MEGA_REACTEURS = [(-0.06, Z_LEVRE + 1.2, 7.4, 1.75, 6.4), (math.pi + 0.06, Z_LEVRE + 1.2, 7.4, 1.75, 6.4),
                  (-0.10, Z_LEVRE + 12.5, 6.6, 1.4, 5.2), (math.pi + 0.10, Z_LEVRE + 12.5, 6.6, 1.4, 5.2)]


def reacteur(lot, M, az, z0, ecart, ray, lon):
    """Réacteur à impulsion : nacelle sombre à axe vertical, tuyère vers le sol, frettes et anneaux d'impulsion cyan sous la tuyère,
    capot taillé, deux mâts jusqu'à la cloche."""
    ca, sa = math.cos(az), math.sin(az)
    zm = z0 + lon * 0.55
    r0 = rz(zm) + ecart
    c = (r0 * ca, r0 * sa, z0)

    def xf(q):
        return (q[0] + c[0], q[1] + c[1], q[2] + c[2])
    prof = [(0.0, ray * 0.62), (0.35, ray * 0.86), (1.1, ray), (lon * 0.78, ray), (lon * 0.92, ray * 0.74), (lon, ray * 0.3), (lon + 0.12, 0.0)]
    lot.put(M["aimant"], G.tour(prof, 28, "z"), xf)
    for zf in (lon * 0.32, lon * 0.55):
        lot.put(M["blindage2"], G.tour([(zf, ray + 0.02), (zf, ray + 0.16), (zf + 0.42, ray + 0.16), (zf + 0.42, ray + 0.02)], 28, "z"), xf)
        lot.put(M["vortex"], G.tour([(zf + 0.14, ray + 0.17), (zf + 0.28, ray + 0.17)], 28, "z"), xf)
    # tuyère : bouche cyan et deux anneaux d'impulsion détachés dessous
    lot.put(M["vortex"], G.tour([(0.02, 0.0), (0.02, ray * 0.6)], 28, "z"), xf)
    lot.put(M["canon"], G.tour([(0.0, ray * 0.6), (-0.5, ray * 0.78), (-0.5, ray * 0.7), (0.0, ray * 0.52)], 28, "z"), xf)
    for k, (dz, rr) in enumerate(((-1.25, 0.95), (-2.5, 0.78))):
        e = 0.16 - 0.04 * k
        lot.put(M["vortex"], G.tour([(dz - e, ray * rr - e), (dz - e, ray * rr + e), (dz + e, ray * rr + e), (dz + e, ray * rr - e), (dz - e, ray * rr - e)],
                                    28, "z"), xf)
    # capot taillé sur le dessus
    lot.put(M["blindage"], G.prisme(R.octo((0.0, 0.0), ray * 1.12, 6), lon * 0.7, lon + 0.5, top_scale=0.45), xf)
    # deux mâts jusqu'à la cloche, et une lame de blindage sur le mât haut
    for k, zz in enumerate((zm - lon * 0.25, zm + lon * 0.2)):
        a = S_pt(az, zz + 1.5 * (1 - k), -0.3)
        b = (c[0] - ca * ray * 0.7, c[1] - sa * ray * 0.7, zz)
        lot.put(M["aimant"], G.tube([a, b], 0.5 - 0.1 * k, 8))
        lot.put(M["vortex"], G.tube([G.lerp(a, b, 0.15), G.lerp(a, b, 0.85)], 0.14, 6))
    t = (-sa, ca, 0.0)
    pa = S_pt(az, zm + lon * 0.2 + 0.6, -0.2)
    pb = (c[0] - ca * ray * 0.5, c[1] - sa * ray * 0.5, zm + lon * 0.2 + 1.0)
    tip = G.add(pb, (ca * 1.2, sa * 1.2, 2.6))
    v, f, u = [], [], []
    w = 0.45
    q = [pa, pb, tip, S_pt(az, zm + lon * 0.2 + 3.2, -0.2)]
    qa = [G.add(x, G.mul(t, -w)) for x in q]
    qb = [G.add(x, G.mul(t, w * 0.6)) for x in q]
    _quad(v, f, u, qa[0], qa[1], qa[2], qa[3])
    _quad(v, f, u, qb[3], qb[2], qb[1], qb[0])
    for i in range(4):
        j = (i + 1) % 4
        _quad(v, f, u, qa[i], qb[i], qb[j], qa[j])
    lot.put(M["blindage2"], (v, f, u))


def lame(lot, M, az, z0, z1, saillie, montee, ep, mat):
    """Plaque de blindage lourde en lame : chevron taillé qui sort de la cloche (de z0 à z1 sur la surface) jusqu'à une pointe à saillie
    tuiles de la surface et montee tuiles au-dessus de z1 ; épaisse de ep, face extérieure chanfreinée."""
    ca, sa = math.cos(az), math.sin(az)
    n = (ca, sa, 0.0)
    t = (-sa, ca, 0.0)
    pts = [S_pt(az, z0, 0.1), G.add(S_pt(az, z0 + (z1 - z0) * 0.3, 0.1), G.mul(n, saillie * 0.42)),
           G.add(S_pt(az, z1, 0.1), G.add(G.mul(n, saillie), (0.0, 0.0, montee))),
           G.add(S_pt(az, z1, 0.1), G.mul(n, saillie * 0.32)), S_pt(az, z1, 0.1)]
    v, f, u = [], [], []
    a = [G.add(p, G.mul(t, -ep / 2)) for p in pts]
    b = [G.add(p, G.mul(t, ep / 2)) for p in pts]
    m = [G.add(p, G.mul(n, ep * 0.35)) for p in pts]
    k = len(pts)
    for i in range(k):
        j = (i + 1) % k
        _quad(v, f, u, a[i], a[j], m[j], m[i])
        _quad(v, f, u, m[i], m[j], b[j], b[i])
    base = len(v)
    v += a
    u += [(0.0, 0.0)] * k
    f.append(tuple(range(base + k - 1, base - 1, -1)))
    base = len(v)
    v += b
    u += [(0.0, 0.0)] * k
    f.append(tuple(range(base, base + k)))
    lot.put(mat, (v, f, u))


def blindage_lourd(lot, M):
    """Ceinture haute de 16 plaques épaisses (1,5 tuile) sur l'épaule, et 6 lames de blindage en chevron dressées autour du cerveau."""
    n = 16
    for k in range(n):
        a0 = G.TAU * (k + 0.25) / n + 0.02
        a1 = G.TAU * (k + 1.25) / n - 0.02
        if not vu((a0 + a1) / 2, 0.8):
            continue
        lot.put(M["blindage"] if k % 2 == 0 else M["blindage2"], plaque(a0, a1, Z_LEVRE + 13.6, Z_LEVRE + 19.4, 0.3, 1.5, 0.2))
        if k % 2 == 0:
            lot.put(M["vortex"], G.tube([S_pt((a0 + a1) / 2, Z_LEVRE + 14.4, 1.5), S_pt((a0 + a1) / 2, Z_LEVRE + 18.4, 1.35)], 0.09, 6))
    for az in (-math.pi / 2 - 0.62, -math.pi / 2 + 0.62, -math.pi / 2 - 1.3, -math.pi / 2 + 1.3, -math.pi / 2 - 2.05, -math.pi / 2 + 2.05):
        lame(lot, M, az, Z_LEVRE + 19.0, Z_LEVRE + 24.2, 6.2, 5.0, 0.8, M["blindage2"])


def mega(lot, M):
    del MEGA_PIVOTS[:]
    blindage(lot, M)
    blindage_lourd(lot, M)
    for az in MEGA_CANONS:
        casemate(lot, M, az)
        MEGA_PIVOTS.append(pivot(az))
    for (az, z0, ecart, ray, lon) in MEGA_REACTEURS:
        reacteur(lot, M, az, z0, ecart, ray, lon)
    anneau_magnetique(lot, M)


def build(S, lot, variante="bourdon"):
    M = matieres(S, variante)
    if variante.startswith("tourelle-"):
        tourelle(lot, M, int(variante.split("-")[1]))
        return {}
    r = G.Rnd(1515)
    R.raz()
    if variante == "battant":
        battant(lot, M)
        return {}
    if variante == "chaine":
        chaine_seule(lot, M)
        return {}
    if variante == "ancre":
        ancre_seule(lot, M)
        return {}
    if variante == "griffes":
        griffes_seules(lot, M)
        return {}
    cloche(lot, M)
    cotes(lot, M, r)
    fenetres(lot, M, r)
    for (az, z, ray) in ((-math.pi / 2, Z_LEVRE + 8.4, 2.7), (-math.pi / 2 - 0.88, Z_LEVRE + 8.5, 2.15), (-math.pi / 2 + 0.88, Z_LEVRE + 8.5, 2.15), (-math.pi / 2, Z_LEVRE + 17.3, 1.85)):
        rosace(lot, M, az, z, ray)
    rampe(lot, M, r)
    terrasse_couronne(lot, M, r)
    arcs_boutants(lot, M, r)
    levre(lot, M, r)
    if variante in ("corps", "mega"):
        manilles(lot, M)
    if variante == "mega":
        mega(lot, M)
    if variante not in ("corps", "mega"):
        chaines(lot, M, r)
    rochers(lot, M, r)
    return dict(R.COMPTE)
