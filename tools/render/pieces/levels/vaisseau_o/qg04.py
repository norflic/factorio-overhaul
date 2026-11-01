"""QG ÂGE 4 : PÉTROLE (ère II Lourde, série du 31/10). Emprise 10×5. NEZ À DROITE (+X), tuyères à gauche.

Bible (DESIGN_EPOQUES §5, époque 4) : « QG de raffinerie : bâtiment à toit-terrasse ; 2 cuves horizontales sur le toit ;
passerelle à garde-corps ; torchère haute à l'arrière droit » ; tôle jaune délavée #8C7A3A, acier galvanisé #6E7378,
bandes noires, voyants orange #FF8C1A, luminance 60. Hérissé de garde-corps, lignes fines, horizontales.

Lecture : la carcasse de l'âge 8, le ventre vidé pour une grande cuve galvanisée posée sur son foyer (le cœur) ; devant
elle, de biais, le bâtiment à toit-terrasse et ses 2 cuves ; derrière, le parc (grande cuve couchée, colonne de
distillation) et la torchère ; une passerelle enjambe le cou du vaisseau.
"""
import math

import carcasse as C
import ere2 as E
import geo as G
import mat as MT

PAL = dict(jaunes=[(0.4, 0.25, 0.018), (0.26, 0.16, 0.013), (0.52, 0.37, 0.04), (0.36, 0.18, 0.012)], sec=(0.19, 0.205, 0.225), sec2=(0.11, 0.12, 0.135),
           conduit=(0.13, 0.135, 0.13), rapiece=(0.27, 0.26, 0.24), rapiece2=(0.2, 0.08, 0.03), acier=(0.085, 0.06, 0.04), acier_clair=(0.2, 0.2, 0.2),
           cuivre=(0.2, 0.11, 0.05), bois=(0.17, 0.14, 0.1), poutre=(0.05, 0.042, 0.032), pierre=(0.14, 0.135, 0.115), toit=(0.17, 0.18, 0.19), ond=(0.46, 0.31, 0.04),
           boue=(0.075, 0.048, 0.024), flaque=(0.006, 0.005, 0.004), lum=(1.0, 0.2, 0.008), lum_f=2.2, voy_f=3.0, lum_m=0.25, veil=(0.06, 0.03, 0.008))
PATINE = dict(ta=0.18, ra=0.3, ec=0.7, nu_k=1.45, ec_col=(0.05, 0.035, 0.018))
COQUE = [(0.46, "jaune0"), (0.62, "jaune1"), (0.71, "jaune2"), (0.8, "jaune3"), (0.92, "vdg"), (0.96, "rapiece"), (1.0, "rapiece2")]


def matieres(S):
    M = E.matieres(S, "q4", PAL, PATINE)
    sf = MT.surface
    cr = (0.008, 0.0065, 0.004)
    M["galva"] = sf("q4_galva", (0.2, 0.215, 0.235), rough=0.42, met=0.3, coulures=0.85, rouille=(0.13, 0.06, 0.02), usure=0.6, nu=(0.55, 0.57, 0.6), crasse=0.8, crasse_col=cr,
                    pied=(0.4, 1.3, 0.5), grain=0.12, graine=71)
    M["cuve_j"] = sf("q4_cuvej", (0.46, 0.29, 0.025), rough=0.5, met=0.15, coulures=1.0, rouille=(0.14, 0.055, 0.015), usure=0.75, nu=(0.55, 0.52, 0.45), crasse=0.85, crasse_col=cr,
                     pied=(0.6, 1.8, 0.5), grain=0.12, graine=72)
    M["hazard"] = sf("q4_hazard", (0.36, 0.25, 0.03), rough=0.5, met=0.2, bandes=(0.22, (0.012, 0.011, 0.01), 0.5), usure=0.8, nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr,
                     coulures=0.6, graine=73)
    M["dalle"] = sf("q4_dalle", (0.13, 0.125, 0.11), rough=0.85, met=0.0, tole=(0.62, 0.42), joint=0.35, var=0.14, coulures=0.4, usure=0.5, nu=(0.3, 0.3, 0.28), crasse=0.85, crasse_col=cr,
                    relief=0.5, grain=0.14, graine=74)
    M["huile"] = MT.verre("q4_huile", col=(0.004, 0.003, 0.002), reflet=(0.08, 0.07, 0.06))
    M["coeur"] = S.mat_emissive("q4_coeur", (1.0, 0.2, 0.01), strength=1.5, base=(0.06, 0.02, 0.003), main_scale=0.3, crust=(9.0, 0.6, 4.0))
    M["flamme"] = MT.lumiere(S, "q4_flamme", (1.0, 0.15, 0.008), 1.3, main=0.15)
    M["flamme2"] = MT.lumiere(S, "q4_flamme2", (1.0, 0.34, 0.03), 1.8, main=0.2)
    return M


# ================================================================================================ pièces
def flamme(lot, M, c):
    """Flamme de torchère couchée par le vent vers l'est : 3 langues, cœur clair."""
    def langue(c0, h, r, tilt, m):
        prof = [(0.0, r * 0.45), (h * 0.14, r), (h * 0.38, r * 0.9), (h * 0.66, r * 0.5), (h * 0.86, r * 0.16), (h, 0.0)]
        v, f, u = G.tour(prof, 12, "z")
        v = [(c0[0] + p[0] + tilt * (p[2] / h) ** 1.6 * h, c0[1] + p[1], c0[2] + p[2]) for p in v]
        lot.put(M[m], (v, f, u))
    langue(c, 1.0, 0.15, 0.5, "flamme")
    langue(G.add(c, (0.06, 0.03, 0.0)), 0.72, 0.1, 0.62, "flamme")
    langue(G.add(c, (-0.06, -0.03, 0.0)), 0.6, 0.085, 0.3, "flamme")
    langue(G.add(c, (0.02, -0.08, 0.02)), 0.42, 0.07, 0.3, "flamme2")


def torchere(lot, M, x, y, h):
    """Torchère haute : massif, tige à tronçons, palier à garde-corps, haubans, nez de brûleur, flamme."""
    lot.put(M["dalle"], G.boite((x, y, 0.14), (0.56, 0.56, 0.28), 0.2))
    prof = [(0.28, 0.14), (h * 0.4, 0.12), (h * 0.4, 0.1), (h * 0.75, 0.085), (h * 0.75, 0.07), (h, 0.07)]
    lot.put(M["acier"], G.tour(prof, 10, "z", (x, y, 0.0)))
    for t in (0.2, 0.4, 0.58, 0.75, 0.9):
        lot.put(M["hazard"] if t in (0.58, 0.9) else M["acier"], G.tour([(h * t - (0.1 if t > 0.5 else 0.04), 0.135), (h * t + (0.1 if t > 0.5 else 0.04), 0.135)], 10, "z", (x, y, 0.0)))
    lot.put(M["acier"], G.tour([(h, 0.08), (h + 0.08, 0.15), (h + 0.13, 0.11)], 12, "z", (x, y, 0.0)))
    zp = h * 0.62
    lot.put(M["acier"], G.tour([(zp, 0.34), (zp + 0.03, 0.34)], 16, "z", (x, y, 0.0), cap1=True))
    pts = [(x + 0.34 * math.cos(TAU_ * k / 12), y + 0.34 * math.sin(TAU_ * k / 12), zp + 0.03) for k in range(13)]
    E.garde(lot, M, pts, 0.3, 0.17)
    E.echelle(lot, M, (x, y - 0.16, 0.25), zp + 0.3, 0.14, "x", 0.14)
    for k in range(3):
        a = TAU_ * k / 3 + 0.5
        lot.put(M["acier"], G.tube([(x, y, h * 0.78), (x + 1.25 * math.cos(a), y + 0.95 * math.sin(a), 0.03)], 0.007, 3))
    lot.put(M["voyant"], G.sphere((x + 0.12, y, zp + 0.42), 0.022, 6, 3))
    flamme(lot, M, (x, y, h + 0.1))


TAU_ = G.TAU


def colonne(lot, M, x, y, h):
    """Colonne de distillation : fût à 3 diamètres, paliers ronds à garde-corps, échelle, col de cygne."""
    lot.put(M["dalle"], G.boite((x, y, 0.13), (0.95, 0.95, 0.26), 0.3))
    prof = [(0.26, 0.42), (h * 0.45, 0.42), (h * 0.5, 0.33), (h * 0.82, 0.33), (h * 0.86, 0.24), (h, 0.24), (h + 0.12, 0.13), (h + 0.16, 0.0)]
    lot.put(M["galva"], G.tour(prof, 28, "z", (x, y, 0.0)))
    for z in [0.5 + i * 0.37 for i in range(int((h - 0.6) / 0.37))]:
        rr = 0.42 if z < h * 0.46 else (0.33 if z < h * 0.83 else 0.24)
        lot.put(M["acier"], G.tour([(z - 0.018, rr + 0.003), (z - 0.014, rr + 0.02), (z + 0.014, rr + 0.02), (z + 0.018, rr + 0.003)], 28, "z", (x, y, 0.0)))
    lot.put(M["hazard"], G.tour([(h * 0.3, 0.428), (h * 0.3 + 0.12, 0.428)], 28, "z", (x, y, 0.0)))
    for (zf, rp) in ((h * 0.47, 0.72), (h * 0.84, 0.54)):
        lot.put(M["acier"], G.tour([(zf, rp), (zf + 0.025, rp), (zf + 0.03, 0.0)], 24, "z", (x, y, 0.0)))
        pts = [(x + rp * math.cos(TAU_ * k / 16), y + rp * math.sin(TAU_ * k / 16), zf + 0.03) for k in range(17)]
        E.garde(lot, M, pts, 0.28, 0.2)
    E.echelle(lot, M, (x + 0.1, y - 0.44, 0.25), h * 0.47 + 0.3, 0.16, "x", 0.14)
    E.echelle(lot, M, (x - 0.1, y - 0.35, h * 0.47), h * 0.84 + 0.3, 0.14, "x", 0.14)
    # col de cygne de tête, descente à brides, piquages latéraux
    C.tuyau(lot, M["conduit"], M["acier"], [(x, y, h + 0.1), (x, y, h + 0.42), (x + 0.8, y - 0.1, h + 0.42), (x + 0.8, y - 0.1, 0.35)], 0.05, rb=0.14, pas_bride=0.55)
    for z in (h * 0.25, h * 0.68):
        C.tuyau(lot, M["acier"], M["acier"], [(x - 0.33, y - 0.1, z), (x - 0.75, y - 0.1, z), (x - 0.75, y - 0.1, 0.3)], 0.035, rb=0.09, pas_bride=0.6)


def terrasse(lot, M, ra):
    """Bâtiment à toit-terrasse, repère local : u (est), v (nord). Corps haut à l'ouest, aile basse à l'est, retrait."""
    u0, um, u1, v0, v1 = -2.25, 0.85, 2.15, -0.92, 0.92
    zh, zb = 1.3, 0.82
    lot.put(M["dalle"], G.boite(((u0 + u1) / 2, 0.0, 0.08), (u1 - u0 + 0.22, v1 - v0 + 0.22, 0.16)))
    # corps haut : ossature, panneaux inégaux, bandeau de sécurité au pied
    x = u0
    pas = ra
    while x < um - 0.02:
        w = min(pas.f(0.36, 0.78), um - x)
        m = M["tole_ond"] if pas.f() < 0.68 else (M["galva"] if pas.f() < 0.7 else M["vdg2"])
        lot.put(m, G.boite((x + w / 2, v0, (0.34 + zh) / 2), (w - 0.012, 0.07, zh - 0.34)))
        lot.put(M["poutre"], G.boite((x, v0 - 0.03, (0.16 + zh) / 2), (0.075, 0.08, zh - 0.16)))
        x += w
    lot.put(M["hazard"], G.boite(((u0 + um) / 2, v0 - 0.004, 0.25), (um - u0, 0.07, 0.18)))
    for (xa, l, m) in ((u0, 0.0, "tole_ond"),):
        lot.put(M[m], G.boite((u0, (v0 + v1) / 2, (0.16 + zh) / 2), (0.07, v1 - v0, zh - 0.16)))
    lot.put(M["tole_ond"], G.boite((um, 0.0, (zb + zh) / 2), (0.07, v1 - v0, zh - zb)))
    lot.put(M["poutre"], G.boite(((u0 + um) / 2, v0 - 0.04, zh - 0.05), (um - u0 + 0.12, 0.1, 0.1)))
    lot.put(M["poutre"], G.boite(((u0 + um) / 2, v0 - 0.04, 0.72), (um - u0 + 0.04, 0.06, 0.05)))
    # toit-terrasse : dalles, acrotère à garde-corps
    lot.put(M["dalle"], G.boite(((u0 + um) / 2, 0.0, zh - 0.02), (um - u0 + 0.18, v1 - v0 + 0.18, 0.08)))
    t0, t1 = zh + 0.02, zh + 0.02
    bord = [(u0 - 0.06, v0 - 0.06, t0), (um + 0.06, v0 - 0.06, t0), (um + 0.06, v1 + 0.06, t0), (u0 - 0.06, v1 + 0.06, t0), (u0 - 0.06, v0 - 0.06, t0)]
    E.garde(lot, M, bord, 0.32, 0.3)
    # LES 2 CUVES DU TOIT
    E.cuve(lot, M, "cuve_j", (-0.75, 0.4, t1 + 0.56), 1.95, 0.42, rz=0.0, bandes=((-0.7, -0.5), (0.72, 0.84)), cercles=3)
    E.cuve(lot, M, "cuve_j", (-0.85, -0.42, t1 + 0.45), 1.62, 0.32, rz=0.0, bandes=((0.22, 0.42),), cercles=2)
    # passerelle sur les cuves, échelles, tuyau de liaison
    zw = t1 + 1.08
    E.caillebotis(lot, M, (-0.75, 0.05), 1.7, 0.3, zw - 0.02)
    E.garde(lot, M, [(-1.6, -0.1, zw), (0.1, -0.1, zw)], 0.3, 0.3)
    E.garde(lot, M, [(-1.6, 0.2, zw), (0.1, 0.2, zw)], 0.3, 0.3)
    for (x, y) in ((-1.6, 0.05), (0.1, 0.05)):
        lot.put(M["acier"], G.boite((x, y, (t1 + zw) / 2), (0.05, 0.05, zw - t1)))
    E.echelle(lot, M, (0.32, -0.02, t1), zw + 0.3, 0.2, "y", 0.14)
    C.tuyau(lot, M["conduit"], M["acier"], [(0.28, 0.4, t1 + 0.56), (0.5, 0.4, t1 + 0.56), (0.5, -0.42, t1 + 0.25), (-0.0, -0.42, t1 + 0.25)], 0.045, rb=0.09, pas_bride=0.4)
    E.vanne(lot, M, (0.5, 0.0, t1 + 0.4), 0.09, 0.2)
    # aile basse à l'est, toit en pente vers le sud (vu de trois-quarts), cuve de tête en bout
    lot.put(M["tole_ond"], G.boite(((um + u1) / 2, v0 + 0.15, (0.16 + zb) / 2), (u1 - um, 0.07, zb - 0.16)))
    lot.put(M["tole_ond"], G.boite((u1, 0.0, (0.16 + zb) / 2), (0.07, v1 - v0 - 0.3, zb - 0.16)))
    lot.put(M["hazard"], G.boite(((um + u1) / 2, v0 + 0.146, 0.25), (u1 - um, 0.07, 0.16)))
    x = um - 0.06
    pas2 = G.Rnd(4141)
    while x < u1 + 0.1:
        w = min(pas2.f(0.2, 0.36), u1 + 0.12 - x)
        q = [(x + 0.01, v0 + 0.02, zb - 0.02), (x + w - 0.01, v0 + 0.02, zb - 0.02), (x + w - 0.01, v1 - 0.1, zb + 0.32), (x + 0.01, v1 - 0.1, zb + 0.32)]
        top = [G.add(p, (0, 0, 0.035)) for p in q]
        m = M["toit"] if pas2.f() < 0.72 else (M["galva"] if pas2.f() < 0.5 else M["rapiece2"])
        lot.put(m, G.merge((top, [(0, 1, 2, 3)], [(p[0], p[1]) for p in top]), G.loft([[q[0], q[1]], [top[0], top[1]]], closed=False)))
        lot.put(M["toit"], G.tube([G.add(q[0], (0, 0, 0.045)), G.add(q[3], (0, 0, 0.045))], 0.013, 4))
        x += w
    C.evente(lot, M["acier"], M["noir"], (1.25, -0.3, zb + 0.14), 0.26, 0.38, 4, 0.0, 0.12)
    lot.put(M["acier"], G.tour([(zb, 0.06), (zb + 0.72, 0.06), (zb + 0.74, 0.13), (zb + 0.82, 0.12), (zb + 0.86, 0.0)], 10, "z", (1.82, 0.2, 0.0)))
    # façade sud : porte à auvent, trois fenêtres différentes, armoire, grille, descentes
    lot.put(M["noir"], G.boite((-1.25, v0 - 0.045, 0.56), (0.5, 0.04, 0.8)))
    lot.put(M["poutre"], G.boite((-1.25, v0 - 0.055, 0.56), (0.03, 0.05, 0.8)))
    lot.put(M["poutre"], G.boite((-1.25, v0 - 0.07, 1.0), (0.6, 0.08, 0.07)))
    lot.put(M["toit"], G.boite((-1.25, v0 - 0.26, 1.08), (0.72, 0.44, 0.035), 0.0, -0.22))
    lot.put(M["acier"], G.tube([(-1.58, v0 - 0.44, 0.16), (-1.58, v0 - 0.44, 1.02)], 0.016, 5))
    lot.put(M["acier"], G.tube([(-0.92, v0 - 0.44, 0.16), (-0.92, v0 - 0.44, 1.02)], 0.016, 5))
    C.hublot(lot, "carre", M["acier"], M["hublot"], (-0.42, v0 - 0.04, 0.92), (0.0, -1.0, 0.0), 0.095)
    C.hublot(lot, "barreaux", M["acier"], M["verre_sombre"], (0.28, v0 - 0.04, 0.95), (0.0, -1.0, 0.0), 0.09)
    C.hublot(lot, "rond", M["acier"], M["veilleuse"], (-1.95, v0 - 0.04, 0.92), (0.0, -1.0, 0.0), 0.075)
    C.hublot(lot, "double", M["acier"], M["verre_sombre"], (1.55, v0 + 0.1, 0.55), (0.0, -1.0, 0.0), 0.07)
    lot.put(M["acier"], G.boite((0.05, v0 - 0.07, 0.5), (0.3, 0.1, 0.36)))
    lot.put(M["noir"], G.boite((0.05, v0 - 0.125, 0.5), (0.2, 0.012, 0.22)))
    lot.put(M["voyant"], G.boite((0.14, v0 - 0.13, 0.6), (0.03, 0.01, 0.03)))
    lot.put(M["acier"], G.boite((1.15, v0 + 0.08, 0.52), (0.5, 0.05, 0.3)))
    for k in range(4):
        lot.put(M["noir"], G.boite((1.15, v0 + 0.05, 0.42 + 0.065 * k), (0.42, 0.015, 0.03)))
    C.tuyau(lot, M["conduit"], M["acier"], [(-2.15, v0 - 0.12, 1.22), (-2.15, v0 - 0.12, 0.42), (-1.7, v0 - 0.12, 0.42), (-1.7, v0 - 0.34, 0.2)], 0.05, rb=0.1, pas_bride=0.45)
    C.tuyau(lot, M["acier"], M["acier"], [(0.48, v0 - 0.08, 1.25), (0.48, v0 - 0.08, 0.28)], 0.03, rb=0.06, pas_bride=0.4)
    # escalier extérieur : sol -> palier de l'aile basse -> terrasse
    E.escalier(lot, M, (2.45, -0.75, 0.08), (2.45, 0.35, zb + 0.14))
    E.caillebotis(lot, M, (2.0, 0.55), 1.15, 0.34, zb + 0.34)
    E.garde(lot, M, [(2.58, 0.38, zb + 0.34), (2.58, 0.72, zb + 0.34), (1.42, 0.72, zb + 0.34)], 0.3, 0.25)
    E.escalier(lot, M, (1.5, 0.58, zb + 0.34), (0.98, 0.58, zh + 0.03), 0.26)
    for (x, y) in ((2.5, 0.42), (1.55, 0.42)):
        lot.put(M["acier"], G.boite((x, y, (zb + 0.34) / 2), (0.06, 0.06, zb + 0.34)))
    # petits équipements de terrasse
    E.fut(lot, M, "jaune3", -2.0, 0.65, t1, 0.11, 0.32)
    E.fut(lot, M, "vdg2", -1.8, 0.72, t1, 0.11, 0.32)
    lot.put(M["acier"], G.boite((-2.0, -0.55, t1 + 0.14), (0.3, 0.42, 0.28)))
    C.evente(lot, M["acier"], M["noir"], (0.45, -0.68, t1), 0.2, 0.3, 3, 0.0, 0.1)


def build(S, lot0):
    M = matieres(S)
    lot = E.LotK(lot0)
    P = C.Pose(**E.POSE)
    r = G.Rnd(4044)
    niv = P.niv
    mc = E.coque(M, COQUE)
    pieds = E.carcasse(lot, M, P, r, mc)
    E.menus_coque(lot, M, P, G.Rnd(4089))
    E.grille_coque(lot, M, P, ((3.0, math.pi / 2 - 0.7, 0.32, 0.4), (3.9, math.pi / 2 + 0.95, 0.26, 0.36), (-2.9, math.pi / 2 + 0.2, 0.3, 0.5)))
    E.mat_nez(lot, M, P)
    zp = E.Z_PONT

    # ======================================================================== le ventre : plancher, foyer, grande cuve
    lot.xf = niv
    lot.put(M["dalle"], G.boite((-0.15, 0.0, zp - 0.03), (4.9, 2.5, 0.06)))
    for u in (-2.5, -1.4, -0.3, 0.8, 1.9):
        for v in (-1.15, 0.0, 1.15):
            lot.put(M["poutre"], G.tour([(0.0, 0.07), (zp - 0.06, 0.065)], 8, "z", (u, v, 0.0), cap1=True))
    # foyer sous la cuve (LE CŒUR : fente orange vue depuis le sud, entre les jambes des côtes)
    lot.put(M["pierre"], G.boite((-0.1, -0.15, zp + 0.17), (3.1, 1.5, 0.34)))
    lot.put(M["coeur"], G.boite((-0.1, -0.9, zp + 0.17), (2.1, 0.03, 0.16)))
    for u in (-1.0, -0.55, -0.1, 0.35, 0.8):
        lot.put(M["acier"], G.boite((u + 0.03, -0.925, zp + 0.17), (0.05, 0.03, 0.24)))
    lot.put(M["acier"], G.boite((-0.1, -0.93, zp + 0.3), (2.3, 0.06, 0.05)))
    lot.put(M["acier"], G.boite((-0.1, -0.93, zp + 0.05), (2.3, 0.06, 0.05)))
    E.cuve(lot, M, "galva", (-0.1, -0.1, zp + 1.26), 2.65, 0.92, bandes=((-1.05, -0.86), (0.2, 0.32), (1.02, 1.2)), cercles=4, selles=False)
    for u in (-1.0, 0.0, 0.9):
        lot.put(M["acier"], G.boite((u, -0.1, zp + 0.42), (0.12, 1.3, 0.1)))
    # conduites de la cuve vers les côtés et le crâne
    C.tuyau(lot, M["conduit"], M["acier"], [(1.75, 0.2, zp + 1.4), (2.3, 0.2, zp + 1.4), (2.3, 0.2, zp + 0.6)], 0.075, rb=0.14)
    C.tuyau(lot, M["cuivre"], M["acier"], [(1.75, -0.5, zp + 0.95), (2.15, -0.72, zp + 0.95), (2.15, -1.2, zp + 0.3)], 0.05, rb=0.12, pas_bride=0.4)
    lot.xf = None

    # ======================================================================== le bâtiment à toit-terrasse, de biais
    ra = G.Rnd(4303)
    cB, rB = (-0.55, -2.32, 0.0), -0.17
    with E.dans(lot, cB, rB):
        terrasse(lot, M, ra)

    # ======================================================================== parc arrière : grande cuve, petite cuve au-dessus, colonne, torchère
    cP, rP = (2.75, 2.65, 0.0), 0.16
    with E.dans(lot, cP, rP):
        lot.put(M["dalle"], G.boite((0.0, 0.0, 0.1), (3.4, 1.7, 0.2)))
        E.cuve(lot, M, "cuve_j", (0.0, 0.0, 0.2 + 0.86), 2.5, 0.74, bandes=((-1.05, -0.86), (-0.08, 0.05), (0.92, 1.1)), cercles=4)
        for x in (-0.95, 0.95):
            lot.put(M["acier"], G.boite((x, 0.0, 1.95), (0.08, 1.0, 0.04)))
            lot.put(M["acier"], G.boite((x, 0.0, 1.85), (0.08, 0.08, 0.26)))
        E.caillebotis(lot, M, (0.0, -0.28), 2.5, 0.32, 1.92)
        E.garde(lot, M, [(-1.25, -0.44, 1.92), (1.25, -0.44, 1.92), (1.25, -0.12, 1.92)], 0.3, 0.32)
        E.echelle(lot, M, (1.5, -0.3, 0.2), 2.2, 0.18, "y", 0.14)
        E.vanne(lot, M, (-1.3, -0.72, 0.2), 0.12, 0.3)
        E.vanne(lot, M, (-0.2, -0.78, 0.2), 0.1, 0.26, "acier_clair")
    colonne(lot, M, -1.0, 2.55, 3.35)
    torchere(lot, M, 5.0, 2.55, 3.65)
    C.tuyau(lot, M["conduit"], M["acier"], [(4.45, 2.55, 0.5), (4.85, 2.55, 0.5), (4.85, 2.55, 0.32)], 0.05, rb=0.1)
    C.tuyau(lot, M["acier"], M["acier"], [(0.7, 2.7, 0.75), (0.2, 2.7, 0.75), (0.2, 2.3, 0.4), (-0.6, 2.3, 0.4)], 0.07, rb=0.15)
    C.tuyau(lot, M["conduit"], M["acier"], [(0.9, 2.4, 1.15), (0.3, 2.0, 1.15), (0.3, 1.75, 1.15)], 0.055, rb=0.12, pas_bride=0.4)

    # ======================================================================== passerelles : le long du dos (est-ouest), lue en lignes fines
    zg = 2.62
    a, b = (-0.72, 2.28), (1.42, 2.58)
    dv = G.sub((b[0], b[1], 0), (a[0], a[1], 0))
    Lp = G.length(dv)
    with E.dans(lot, (a[0], a[1], zg), math.atan2(dv[1], dv[0])):
        E.caillebotis(lot, M, (Lp / 2, 0.0), Lp, 0.32, 0.0, 0.0, 0.025, 0.07)
        for s_ in (-1, 1):
            E.garde(lot, M, [(0.0, s_ * 0.16, 0.0), (Lp, s_ * 0.16, 0.0)], 0.3, 0.26)
        for t in (0.12, 0.5, 0.88):
            lot.put(M["acier"], G.boite((Lp * t, 0.0, -zg / 2), (0.07, 0.07, zg)))
            lot.put(M["acier"], G.tube([(Lp * t - 0.3, 0.0, -zg), (Lp * t, 0.0, -zg * 0.55)], 0.016, 4))
            lot.put(M["acier"], G.tube([(Lp * t + 0.3, 0.0, -zg), (Lp * t, 0.0, -zg * 0.55)], 0.016, 4))
    E.escalier(lot, M, (1.42, 2.1, 1.92), (0.62, 2.1, zg))
    # du toit du bâtiment à la cage : courte passerelle, rampes, sur 2 jambes
    with E.dans(lot, (-1.05, -1.42, 1.5), 1.45):
        E.caillebotis(lot, M, (0.3, 0.0), 0.95, 0.3, 0.0, 0.0, 0.025, 0.07)
        for s_ in (-1, 1):
            E.garde(lot, M, [(-0.15, s_ * 0.15, 0.0), (0.78, s_ * 0.15, 0.0)], 0.3, 0.24)

    # ======================================================================== le radier : 3 dalles décalées qui rassemblent le front (bord jamais droit)
    for (cx, cy, sx, sy, rz, h) in ((-4.15, -2.72, 2.55, 1.75, 0.24, 0.05), (-0.3, -3.05, 5.9, 1.6, -0.1, 0.06), (3.65, -2.55, 2.2, 1.95, -0.2, 0.05)):
        lot.put(M["dalle"], G.boite((cx, cy, h / 2), (sx, sy, h), rz))
        lot.put(M["hazard"], G.boite(G.add((cx, cy, 0.06), G.rot_z((0.0, -sy / 2, 0.0), rz)), (sx * 0.5, 0.05, 0.09), rz))
    for (x, y, rz, L) in ((-2.45, -3.6, 0.1, 1.35), (1.95, -3.72, -0.25, 1.05)):           # murets de cuvette, caniveau à grille
        lot.put(M["pierre"], G.boite((x, y, 0.09), (L, 0.12, 0.18), rz))
    with E.dans(lot, (-0.55, -3.92, 0.0), -0.1):
        lot.put(M["noir"], G.boite((0.0, 0.0, 0.03), (3.1, 0.14, 0.06)))
        for k in range(26):
            lot.put(M["acier"], G.boite((-1.5 + k * 0.12, 0.0, 0.065), (0.05, 0.14, 0.02)))
    # pont de tuyaux bas entre le bâtiment et le four de craquage (colonnes, 3 lignes)
    for (x, y) in ((2.05, -2.55), (2.75, -2.65)):
        lot.put(M["acier"], G.boite((x, y, 0.55), (0.06, 0.32, 1.1)))
        lot.put(M["acier"], G.boite((x, y, 1.08), (0.08, 0.46, 0.05)))
    for (dy, rt, m) in ((-0.14, 0.045, "conduit"), (0.0, 0.03, "acier"), (0.14, 0.05, "cuve_j")):
        C.tuyau(lot, M[m], M["acier"], [(1.75, -2.5 + dy, 1.14), (3.1, -2.68 + dy, 1.14)], rt, rb=0.1, pas_bride=0.42)

    # ======================================================================== collecteur à volants, sud-ouest (kit d'époque)
    with E.dans(lot, (-4.55, -2.75, 0.0), 0.28):
        lot.put(M["dalle"], G.boite((0.0, 0.0, 0.07), (1.8, 1.25, 0.14)))
        E.garde(lot, M, [(-0.9, -0.62, 0.14), (0.9, -0.62, 0.14)], 0.3, 0.45)
        for (x, kv) in ((-0.55, "rouge"), (0.0, "acier_clair"), (0.5, "rouge")):
            C.tuyau(lot, M["conduit"], M["acier"], [(x, 0.5, 0.3), (x, 0.12, 0.3), (x, 0.12, 0.14)], 0.045, rb=0.08, pas_bride=0.3)
            E.vanne(lot, M, (x, -0.1, 0.14), 0.1, 0.24, kv)
        lot.put(M["conduit"], G.tour([(-0.85, 0.075), (0.85, 0.075)], 12, "x", (0.0, 0.5, 0.3), cap0=True, cap1=True))
        for x in (-0.75, 0.75):
            lot.put(M["acier"], G.boite((x, 0.5, 0.2), (0.1, 0.14, 0.14)))
        for (x, y, m) in ((-0.5, -0.42, "jaune3"), (-0.2, -0.45, "vdg2"), (0.62, -0.38, "rapiece2")):
            E.fut(lot, M, m, x, y, 0.14)
    # ======================================================================== four de craquage, sud-est (cheminée, brûleur)
    h0 = (3.65, -2.3)
    lot.put(M["dalle"], G.boite((h0[0], h0[1], 0.08), (1.45, 1.35, 0.16), -0.2))
    lot.put(M["galva"], G.tour([(0.16, 0.56), (1.0, 0.56), (1.2, 0.38), (1.28, 0.2)], 28, "z", (h0[0], h0[1], 0.0)))
    for z in (0.34, 0.62, 0.9):
        lot.put(M["acier"], G.tour([(z - 0.022, 0.565), (z - 0.016, 0.585), (z + 0.016, 0.585), (z + 0.022, 0.565)], 28, "z", (h0[0], h0[1], 0.0)))
    lot.put(M["acier"], G.tour([(1.28, 0.15), (2.45, 0.11), (2.5, 0.14), (2.58, 0.13)], 12, "z", (h0[0], h0[1], 0.0)))
    lot.put(M["hazard"], G.tour([(2.15, 0.122), (2.3, 0.118)], 12, "z", (h0[0], h0[1], 0.0)))
    lot.put(M["coeur"], G.boite((h0[0] - 0.08, h0[1] - 0.545, 0.34), (0.24, 0.03, 0.16)))
    lot.put(M["acier"], G.boite((h0[0] - 0.08, h0[1] - 0.565, 0.44), (0.34, 0.05, 0.04)))
    for x in (-0.16, -0.08, 0.0):
        lot.put(M["acier"], G.boite((h0[0] + x, h0[1] - 0.565, 0.34), (0.02, 0.02, 0.18)))
    E.vanne(lot, M, (h0[0] + 0.62, h0[1] - 0.25, 0.16), 0.1, 0.24)
    C.tuyau(lot, M["conduit"], M["acier"], [(h0[0] - 0.5, h0[1] + 0.25, 0.75), (h0[0] - 1.05, h0[1] + 0.25, 0.75), (h0[0] - 1.05, h0[1] + 0.25, 0.35)], 0.05, rb=0.11, pas_bride=0.4)

    # ======================================================================== tuyauterie longue, flexibles, câbles
    pv = niv
    C.tuyau(lot, M["conduit"], M["acier"], [(-3.3, -1.35, 0.5), (-3.3, -2.1, 0.5), (-3.3, -2.1, 0.32), (-3.75, -2.55, 0.32)], 0.08, rb=0.16, pas_bride=0.5)
    C.tuyau(lot, M["acier"], M["acier"], [pv((1.95, -1.1, 1.0)), pv((2.75, -1.25, 1.0)), (2.95, -1.75, 0.8), (3.1, -1.95, 0.72)], 0.06, rb=0.14, pas_bride=0.45)
    C.tuyau(lot, M["cuivre"], M["acier"], [(-5.15, -3.4, 0.22), (-2.9, -3.75, 0.22), (0.0, -3.75, 0.22), (3.15, -3.25, 0.22)], 0.04, rb=0.14, pas_bride=0.55)
    for (a_, b_, c_) in (((-4.55, -1.4, 1.15), (-4.7, -1.95, 0.3), (-4.35, -2.28, 0.32)), ((-3.6, -1.15, 1.15), (-3.65, -1.6, 0.4), (-3.1, -1.75, 0.5)),
                         (pv((2.45, -0.9, 1.2)), (2.75, -1.25, 0.65), (3.25, -1.85, 0.72)), ((0.3, 2.2, 0.3), (0.55, 1.75, 0.1), (1.1, 1.85, 0.25)),
                         ((3.1, 1.75, 0.28), (3.6, 1.45, 0.1), (4.35, 1.65, 0.35)), (pv((-1.8, -1.05, 0.9)), (-2.4, -1.45, 0.3), (-2.75, -1.6, 0.4))):
        C.flexible(lot, M["caoutchouc"], [a_, b_, c_], 0.048)
    for (x, y, rr_) in ((-5.15, -2.15, 0.2), (2.75, -3.45, 0.16)):
        for k in range(3):
            rk = rr_ - 0.032 * k
            lot.put(M["caoutchouc"], G.tube([(x + rk * math.cos(TAU_ * j / 18), y + rk * math.sin(TAU_ * j / 18), 0.035 + 0.055 * k) for j in range(19)], 0.028, 6))
    fx = [(P.xf((E.COTES[i] - 0.05, 0.25, C.z_dessus(E.COTES[i]) + 0.4)), P.xf((E.COTES[i + 1] - 0.05, 0.25, C.z_dessus(E.COTES[i + 1]) + 0.4)), 0.3) for i in range(3)]
    fx += [(pieds[0][1], pieds[1][1], 0.4), (pieds[2][1], pieds[3][1], 0.34), (pieds[1][1], pieds[2][1], 0.45)]
    fx += [(P.xf((-3.4, 0.0, C.z_dessus(-3.4) + 0.3)), (-1.0, 2.1, 2.2), 0.3), ((5.0, 2.55, 2.4), P.xf((3.5, 0.3, C.z_dessus(3.5) + 0.1)), 0.35)]
    fx += [(P.xf((2.4, -0.9, 0.5)), P.xf((3.8, -0.75, 0.35)), 0.18), (P.xf((-3.3, -0.9, 0.3)), P.xf((-2.3, -1.05, 0.1)), 0.22)]
    ra2 = G.Rnd(4305)
    for (a_, b_, fl) in fx:
        C.faisceau(lot, M["rouge"], M["noir"], a_, b_, fl, 3, 0.011, 0.028, ra2)

    # ======================================================================== fouets d'antenne, lampadaires, objets
    for x in (-1.3, 1.1):
        p = P.xf((x, 0.0, C.z_dessus(x) + 0.25))
        lot.put(M["acier"], G.tube([p, G.add(p, (0.0, 0.0, 0.9))], 0.012, 4))
        lot.put(M["acier"], G.tour([(p[2], 0.04), (p[2] + 0.08, 0.035)], 8, "z", (p[0], p[1], 0.0)))
    for (x, y) in ((-3.2, -3.5), (2.75, -3.75)):
        q = (x, y, 0.0)
        lot.put(M["acier"], G.tube([q, G.add(q, (0, 0, 1.55))], 0.025, 6))
        lot.put(M["acier"], G.tube([G.add(q, (0, 0, 1.53)), G.add(q, (0.0, -0.22, 1.57))], 0.015, 4))
        lot.put(M["veilleuse"], G.sphere(G.add(q, (0.0, -0.22, 1.49)), 0.045, 8, 4))
    for (x, y, m) in ((-2.9, -3.2, "jaune3"), (-2.62, -3.3, "rapiece2"), (-2.78, -3.48, "vdg2"), (1.98, -3.6, "vdg2"), (2.25, -3.45, "jaune3")):
        E.fut(lot, M, m, x, y, 0.0)
    E.fut(lot, M, "jaune3", -2.8, -3.28, 0.44)

    # ======================================================================== sol : butte, flaques d'huile, berceaux, débris
    nez = P.xf((5.0, 0.0, -0.3))
    lot.put(M["boue"], G.butte_polaire((nez[0] + 0.15, nez[1] - 0.1, 0.0), 1.05, 1.5, 0.62, r, 12, 48, 0.3, 0.14))
    for (x, y, a_, b_) in ((nez[0] + 0.9, nez[1] - 1.2, 0.45, 0.35), (nez[0] - 0.4, nez[1] + 1.25, 0.5, 0.3)):
        lot.put(M["boue"], G.butte_polaire((x, y, 0.0), a_, b_, 0.2, r, 6, 28, 0.3, 0.2))
    for (x, y, a_, b_) in ((-5.5, -0.4, 0.7, 1.05), (-2.2, -3.9, 0.85, 0.32), (5.35, -3.1, 0.62, 0.42), (1.2, 3.9, 0.9, 0.34), (-0.1, -3.62, 0.5, 0.2)):
        lot.put(M["vase"], G.butte_polaire((x, y, 0.0), a_, b_, 0.022, r, 3, 36, 0.2, 0.25))
    for (x, y) in ((-3.4, -1.2), (-3.6, 1.95), (-4.5, -1.75), (-4.6, 2.0)):
        for k in range(4):
            lot.put(M["poutre"], G.boite((x, y, 0.09 + 0.17 * k), (0.95 if k % 2 == 0 else 0.22, 0.22 if k % 2 == 0 else 0.95, 0.15), -0.1 + 0.06 * k))
        lot.put(M["acier"], G.tour([(0.7, 0.07), (1.05, 0.06)], 8, "z", (x, y, 0.0), cap1=True))
    E.debris(lot, M, [("plaque", -5.75, -1.3, 0.55, 0.38, 0.4), ("plaque", 5.1, -3.75, 0.5, 0.32, -0.7), ("plaque", -5.5, 3.3, 0.6, 0.42, 0.9),
                      ("fut", 5.45, -2.55, 1.4), ("fut", -5.8, -3.8, 0.3), ("fut", 5.55, 1.55, 0.0), ("caisse", 5.05, -1.6, 0.34, 0.3, 0.5),
                      ("caisse", -5.55, 1.5, 0.3, 0.3, -0.2), ("caisse", 1.3, 4.0, 0.32, 0.3, 0.7), ("tuyau", 3.95, -3.85, 0.9, 0.05, 0.25),
                      ("tuyau", -3.75, -3.95, 0.7, 0.04, -0.15), ("pneu", -1.3, -3.95, 0.17), ("plaque", 2.6, 4.0, 0.5, 0.3, 0.3)])
    E.ferraille(lot, M, G.Rnd(4306))
    return {"pose": E.POSE}
