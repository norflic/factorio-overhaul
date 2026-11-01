"""COURONNÉ (robot 12, âge 15 Légende, expérimental final ; PLAN §2 : base flottante, couronne, 8 pattes ; image 16 tuiles).

Idée : un RELIQUAIRE MARCHANT, un ostensoir de 15 tuiles de haut. Une couronne de hanches (anneau d'or blanc ajouré, vide au
centre) porte 8 longues lances ; au-dessus, SANS AUCUN LIEN (vide de la « base flottante », lumière dessous), le palais : base
octogonale à créneaux, tambour de nacre aux baies toutes différentes, arcs-boutants, toit d'écailles d'or, couronne de 11
flèches inclinées vers l'extérieur et 2 anneaux-halos. Sous lui, une quille pendante traverse le trou des hanches. Devant, le
soleil de l'ostensoir (l'arme principale : 16 rayons autour d'un cristal), jamais un canon central. Chaque genou porte une
flèche : 8 pointes qui répètent la couronne autour du corps.
Pattes compatibles avec le moteur (spider-vehicle, PLAN §3) : 2 segments DROITS et une articulation ; aucune courbe.
Bible (DESIGN_EPOQUES, époque 15) : or blanc #E8DCB0 patiné, nacre #D8D2C8, cristal clair, lumière #FFF2C0, luminance 108.
"""
import math

import formes as F
import geo as G
import marionette as Mr

CAP = math.radians(-125.0)     # le soleil de l'ostensoir regarde la caméra et la lumière (ouest)
Z_H = 5.5                 # centre de l'anneau des hanches
R_H, R_P = 2.5, 6.75      # rayon des hanches, rayon neutre des pieds
L1, L2 = 3.06, 7.63
Z_PAL = 7.35              # dessous du palais : 1,4 tuile de vide au-dessus de l'anneau des hanches
Z_HALO1, Z_HALO2 = 13.15, 14.45
PAS, BETA, LEVE = 2.5, 0.6, 1.25
IMAGES = 4


def angle_patte(k):
    return math.radians(22.5 + 45.0 * k)


def matieres(S):
    import mat as MT
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.1, ra=0.2, ec=0.3, nu_k=1.3, ec_col=(0.06, 0.038, 0.016), sans=("or", "cristal"))
    cr = (0.03, 0.021, 0.011)
    M = {}
    M["or"] = F.surf("rb15_or", (0.86, 0.72, 0.4), rough=0.3, met=0.55, coulures=0.15, rouille=(0.3, 0.2, 0.08), usure=0.45, nu=(0.98, 0.9, 0.68),
                     crasse=0.6, crasse_col=cr, graine=151)
    M["orb"] = F.surf("rb15_or_blanc", (0.88, 0.8, 0.58), rough=0.26, met=0.4, coulures=0.2, rouille=(0.34, 0.25, 0.12), usure=0.4, nu=(1.0, 0.96, 0.82),
                      crasse=0.7, crasse_col=cr, graine=158)
    M["or_s"] = F.surf("rb15_or_s", (0.5, 0.34, 0.13), rough=0.38, met=0.6, coulures=0.3, usure=0.55, nu=(0.82, 0.68, 0.36), crasse=0.8, crasse_col=cr, graine=152)
    M["nacre"] = F.surf("rb15_nacre", (0.76, 0.71, 0.62), rough=0.3, met=0.0, tole=(0.9, 0.46), joint=0.62, joint_l=0.007, var=0.05, coulures=0.3,
                        rouille=(0.28, 0.22, 0.14), usure=0.35, nu=(0.9, 0.87, 0.8), crasse=0.8, crasse_col=cr, relief=0.45, graine=153)
    M["nacre2"] = F.surf("rb15_nacre2", (0.6, 0.53, 0.42), rough=0.33, met=0.05, coulures=0.35, rouille=(0.22, 0.16, 0.09), usure=0.4, nu=(0.86, 0.8, 0.7),
                         crasse=0.85, crasse_col=cr, graine=154)
    M["toit"] = F.surf("rb15_toit", (0.72, 0.56, 0.24), rough=0.34, met=0.5, tole=(0.2, 0.12), joint=0.35, joint_l=0.022, var=0.22, coulures=0.2, usure=0.45,
                       nu=(0.95, 0.85, 0.55), crasse=0.8, crasse_col=cr, relief=0.8, graine=155)
    M["sombre"] = F.surf("rb15_sombre", (0.05, 0.036, 0.022), rough=0.5, met=0.5, usure=0.45, nu=(0.34, 0.26, 0.14), crasse=0.7, crasse_col=(0.006, 0.004, 0.003), graine=156)
    M["riv"] = F.surf("rb15_riv", (0.62, 0.48, 0.22), rough=0.35, met=0.7, usure=0.3, crasse=0.4, graine=157)
    M["cristal_m"] = MT.verre("rb15_cristal", col=(0.09, 0.085, 0.07), reflet=(0.75, 0.72, 0.6))
    M["lum"] = MT.lumiere(S, "rb15_lum", (1.0, 0.89, 0.53), 1.3, main=0.5)
    M["baie"] = MT.lumiere(S, "rb15_baie", (1.0, 0.7, 0.3), 0.8, main=0.4)
    M["coeur"] = MT.lumiere(S, "rb15_coeur", (1.0, 0.82, 0.45), 1.35, main=0.5)
    M["dessous"] = MT.lumiere(S, "rb15_dessous", (1.0, 0.82, 0.48), 0.7, main=0.5)
    M["halo"] = MT.lumiere(S, "rb15_halo", (1.0, 0.93, 0.7), 1.5, main=0.55)
    M["part"] = MT.lumiere(S, "rb15_part", (1.0, 0.86, 0.5), 1.0, main=0.55)
    return M


def squelette(phase):
    sq = Mr.Squelette()
    bat = 0.0 if phase is None else 1.0
    ph = 0.0 if phase is None else phase
    a = G.TAU * ph
    sq.os("racine", None, Mr.rz(CAP))
    m_a = Mr.chaine(Mr.tr(0.0, 0.0, bat * 0.1 * math.cos(2.0 * a)), Mr.rx(bat * 0.012 * math.sin(2.0 * a)))
    sq.os("hanches", "racine", m_a)
    # le palais flotte : son propre balancement, en retard sur les hanches (son vide respire)
    sq.os("palais", "racine", Mr.chaine(Mr.tr(0.0, 0.0, bat * 0.1 * math.cos(2.0 * a - 1.0) + 0.04 * math.sin(a)), Mr.rx(bat * 0.009 * math.sin(2.0 * a - 1.0))))
    sq.os("halo1", "palais", Mr.autour((0.0, 0.0, Z_HALO1), Mr.chaine(Mr.rz(a), Mr.rx(0.12))))
    sq.os("halo2", "palais", Mr.autour((0.0, 0.0, Z_HALO2), Mr.chaine(Mr.rz(-a * 2.0), Mr.ry(0.24))))
    sq.os("part", "palais", Mr.tr(0.0, 0.0, bat * 0.06 * math.sin(a)))     # en jeu, les particules sont une feuille à part (DESIGN §5, époque 15)
    for k in range(8):
        nom = str(k)
        ang = angle_patte(k)
        c, s = math.cos(ang), math.sin(ang)
        dec = 0.0 if k % 2 == 0 else 0.5
        dx, dz, appui, u = Mr.pied(phase, dec, PAS, BETA, LEVE)
        h = Mr.app(m_a, (R_H * c, R_H * s, Z_H))
        p = (R_P * c + dx, R_P * s, dz)
        g, tendu = Mr.ik2(h, p, L1, L2, (c, s, 1.2))
        sq.os("cuisse" + nom, "racine", Mr.repere(h, G.sub(g, h), (-s, c, 0.0)))
        sq.os("tibia" + nom, "racine", Mr.repere(g, G.sub(p, g), (-s, c, 0.0)))
        sq.os("genou" + nom, "racine", Mr.chaine(Mr.tr(g[0], g[1], g[2]), Mr.rz(ang)))
        sq.os("pied" + nom, "racine", Mr.chaine(Mr.tr(p[0], p[1], p[2]), Mr.rz(ang), Mr.ry(0.0 if appui else 0.3 * math.sin(math.pi * u))))
        sq.marques[nom] = {"pied": p, "appui": appui, "tendu": tendu}
    return sq


def _cuisse(lot, M):
    """Segment haut : 2 longerons de nacre, arcs d'or entre eux. Droit : tient dans le segment étiré du moteur."""
    L = L1
    for s in (1.0, -1.0):
        lot.put(M["nacre2"], F.poutre([(0.1, 0.14, 0.2), (L - 0.15, 0.1, 0.13)]), (lambda v, s=s: (v[0], v[1] + s * (0.2 - 0.05 * v[0] / L), v[2])))
    lot.put(M["sombre"], F.poutre([(0.1, 0.06, 0.34), (L - 0.15, 0.05, 0.24)]))
    for i in range(4):
        x = 0.42 + 0.56 * i
        hw = 0.2 - 0.05 * x / L
        lot.put(M["or_s"], G.boite((x, 0.0, 0.0), (0.07, hw * 2.0 + 0.1, 0.07 + 0.2 * (1.0 - x / L))))
        lot.put(M["or"], F.pose(F.fleche(0.04, 0.2, 6), (x, 0.0, 0.1 - 0.02 * i), (0.0, 0.0, 1.0), (1.0, 0.0, 0.0)))
    lot.put(M["or"], F.bague((0.14, 0.0, 0.0), 0.0, 0.3, 0.13, "x", 12, 0.02))
    lot.put(M["or_s"], F.disque((0.0, 0.0, 0.0), 0.32, 0.24, "y", 14))


def _tibia(lot, M):
    """Segment bas : longue lance effilée, arête d'or, bagues et flancs ajourés (baies étroites). Droit."""
    L = L2
    lot.put(M["nacre"], F.poutre([(0.0, 0.42, 0.42), (0.7, 0.38, 0.44), (L * 0.42, 0.24, 0.3), (L - 0.9, 0.14, 0.17), (L - 0.15, 0.1, 0.12)], 0.42))
    for s in (1.0, -1.0):
        for z_ in (1.0, -1.0):
            lot.put(M["or"], F.poutre([(0.12, 0.022, 0.022), (L - 0.3, 0.014, 0.014)]), (lambda v, s=s, z_=z_: (v[0], v[1] + s * (0.21 - 0.15 * v[0] / L) * 0.72, v[2] + z_ * (0.23 - 0.17 * v[0] / L) * 0.72)))
    for t, k_ in ((0.12, 1.15), (0.34, 1.05), (0.55, 1.0), (0.76, 0.95), (0.9, 1.0)):
        x = L * t
        rr_ = (0.27 - 0.2 * t) * k_
        lot.put(M["or"], F.bague((x, 0.0, 0.0), rr_ * 0.5, rr_, 0.09, "x", 12, 0.016))
        lot.put(M["sombre"], F.bague((x + 0.07, 0.0, 0.0), rr_ * 0.4, rr_ * 0.86, 0.04, "x", 12))
    for t, h_ in ((0.2, 0.75), (0.44, 0.52)):      # baies étroites, sur les 2 flancs
        x = L * t
        ww = 0.18 - 0.08 * t
        for s in (1.0, -1.0):
            lot.put(M["baie"], F.sur_face(F.plaque(F.ogive(0.07, h_), 0.012), (x, s * ww * 0.86, 0.0), (0.0, s, 0.0), (1.0, 0.0, 0.0)))
    # bas de la lance : ergot (un pli au-dessus du sabot)
    lot.put(M["or_s"], F.pose(F.fleche(0.07, 0.42, 6), (L - 0.46, 0.0, 0.1), (0.0, 0.0, 1.0), (1.0, 0.0, 0.0)))


def _genou(lot, M):
    """Articulation : boule d'or à 8 pans, écusson, et la flèche qui répète la couronne autour du corps."""
    lot.put(M["or"], G.tour([(-0.34, 0.0), (-0.3, 0.2), (-0.1, 0.36), (0.12, 0.34), (0.28, 0.2), (0.36, 0.0)], 8, "z"))
    lot.put(M["sombre"], F.bague((0.0, 0.0, 0.0), 0.2, 0.42, 0.06, "z", 8, 0.012))
    lot.put(M["orb"], F.fleche(0.15, 1.75, 6), (lambda v: (v[0], v[1], v[2] + 0.28)))
    lot.put(M["or"], F.bague((0.0, 0.0, 0.47), 0.05, 0.145, 0.05, "z", 6, 0.01))
    lot.put(M["or"], F.bague((0.0, 0.0, 0.95), 0.03, 0.1, 0.04, "z", 6, 0.008))
    lot.put(M["lum"], F.cristal((0.0, 0.0, 2.1), 0.05, 0.08))


def _pied(lot, M):
    """Sabot : cloche renversée en or, 4 griffes, anneau bas sombre."""
    lot.put(M["or"], G.tour([(0.0, 0.52), (0.05, 0.58), (0.12, 0.54), (0.26, 0.28), (0.5, 0.16), (0.72, 0.12), (0.76, 0.1)], 8, "z", cap1=True))
    lot.put(M["sombre"], F.bague((0.0, 0.0, 0.14), 0.3, 0.52, 0.035, "z", 8, 0.008))
    for i in range(4):
        a = G.TAU * (i + 0.5) / 4
        d = (math.cos(a), math.sin(a), 0.0)
        lot.put(M["nacre2"], F.pose(F.poutre([(0.0, 0.1, 0.13), (0.55, 0.04, 0.04, -0.05)]), (d[0] * 0.48, d[1] * 0.48, 0.07), d))


def _face_octo(ang, r0):
    return (r0 * math.cos(ang), r0 * math.sin(ang)), (math.cos(ang), math.sin(ang), 0.0)


def modele(lots, M, r):
    h = lots("hanches")
    a8 = math.pi / 8.0
    # ---------------------------------------------------------------------------- anneau des hanches : vide au centre
    prof = [(-0.45, 1.75), (-0.45, 2.55), (-0.2, 2.85), (0.25, 2.85), (0.42, 2.55), (0.42, 1.87), (0.2, 1.65), (-0.45, 1.75)]
    h.put(M["nacre"], G.tour(prof, 8, "z", (0.0, 0.0, Z_H), a0=a8, a1=a8 + G.TAU))
    h.put(M["or"], F.bague((0.0, 0.0, Z_H + 0.26), 2.55, 2.89, 0.07, "z", 8, 0.012, a0=a8, a1=a8 + G.TAU))
    h.put(M["or"], F.bague((0.0, 0.0, Z_H - 0.2), 2.55, 2.89, 0.06, "z", 8, 0.012, a0=a8, a1=a8 + G.TAU))
    h.put(M["or_s"], F.bague((0.0, 0.0, Z_H + 0.42), 1.8, 2.0, 0.05, "z", 8, 0.01, a0=a8, a1=a8 + G.TAU))
    h.put(M["sombre"], F.bague((0.0, 0.0, Z_H + 0.425), 1.9, 2.53, 0.02, "z", 8, 0.0, a0=a8, a1=a8 + G.TAU))
    apo = 2.85 * math.cos(a8)
    for k in range(8):
        am = math.radians(45.0 * k)                  # milieu d'un pan (entre 2 hanches)
        for i in range(5):                            # arcature sur le flanc de l'anneau, baies inégales
            dt = (i - 2) * 0.4
            c, n = _face_octo(am, apo)
            p = (c[0] - math.sin(am) * dt, c[1] + math.cos(am) * dt, Z_H - 0.14)
            ht = 0.34 if i % 2 else 0.26
            h.put(M["or_s"], F.sur_face(F.plaque(F.ogive(0.28, ht + 0.05), 0.014), p, n))
            h.put(M["baie" if (i + k) % 3 else "sombre"], F.sur_face(F.plaque(F.ogive(0.2, ht), 0.028), p, n))
        # pendentif sous le pan
        pp = (2.5 * math.cos(am), 2.5 * math.sin(am), Z_H - 0.44)
        h.put(M["or"], F.incline(F.fleche(0.1, 0.8, 6), pp, (0.0, 0.0, -1.0)))
        h.put(M["lum"], F.cristal((pp[0], pp[1], pp[2] - 0.86), 0.04, 0.07))
        ah = angle_patte(k)
        cs, sn = math.cos(ah), math.sin(ah)
        # hanche : logement à pans et rosace
        h.put(M["or_s"], F.pose(G.tour([(-0.5, 0.0), (-0.5, 0.42), (0.1, 0.45), (0.3, 0.36), (0.36, 0.0)], 8, "x"), (R_H * cs, R_H * sn, Z_H), (cs, sn, 0.0)))
        rp = (2.78 * cs, 2.78 * sn, Z_H)
        h.put(M["or"], F.sur_face(G.tour([(0.0, 0.24), (0.04, 0.2), (0.07, 0.0)], 12, "z", cap0=True), rp, (cs, sn, 0.0)))
    # ---------------------------------------------------------------------------- PALAIS : tout ceci flotte, aucun lien avec l'anneau
    b = lots("palais")
    z0 = Z_PAL
    base_prof = [(0.0, 2.2), (0.12, 2.75), (0.3, 3.05), (0.52, 3.12), (0.68, 3.02), (0.72, 2.35)]
    b.put(M["nacre2"], G.tour(base_prof, 8, "z", (0.0, 0.0, z0), a0=a8, a1=a8 + G.TAU))
    b.put(M["or"], F.bague((0.0, 0.0, z0 + 0.5), 3.0, 3.17, 0.1, "z", 8, 0.02, a0=a8, a1=a8 + G.TAU))
    b.put(M["or"], F.bague((0.0, 0.0, z0 + 0.3), 2.92, 3.07, 0.05, "z", 8, 0.01, a0=a8, a1=a8 + G.TAU))
    b.put(M["sombre"], F.bague((0.0, 0.0, z0 + 0.72), 1.2, 2.42, 0.03, "z", 8, 0.0, a0=a8, a1=a8 + G.TAU))
    # lumière du dessous : c'est elle qui dit « flotte »
    b.put(M["dessous"], F.bague((0.0, 0.0, z0 - 0.015), 1.75, 2.42, 0.03, "z", 32))
    b.put(M["halo"], F.bague((0.0, 0.0, z0 + 0.1), 2.68, 2.74, 0.02, "z", 32))
    # quille pendante, qui traverse le trou des hanches
    b.put(M["nacre2"], G.tour([(z0 + 0.02, 1.68), (z0 - 0.32, 1.22), (z0 - 0.5, 1.2), (z0 - 0.92, 0.72), (z0 - 1.5, 0.42), (z0 - 2.4, 0.2), (z0 - 3.4, 0.0)], 8, "z", a0=a8, a1=a8 + G.TAU))
    b.put(M["or"], F.bague((0.0, 0.0, z0 - 0.5), 0.95, 1.27, 0.09, "z", 8, 0.02, a0=a8, a1=a8 + G.TAU))
    b.put(M["or"], F.bague((0.0, 0.0, z0 - 1.5), 0.25, 0.48, 0.06, "z", 8, 0.012, a0=a8, a1=a8 + G.TAU))
    b.put(M["coeur"], F.cristal((0.0, 0.0, z0 - 3.62), 0.14, 0.28))
    for k in range(8):
        ak = a8 + k * G.TAU / 8
        c0, s0 = math.cos(ak), math.sin(ak)
        b.put(M["or_s"], G.tube([(1.6 * c0, 1.6 * s0, z0), (1.15 * c0, 1.15 * s0, z0 - 0.55), (0.46 * c0, 0.46 * s0, z0 - 1.48), (0.02 * c0, 0.02 * s0, z0 - 3.35)], 0.028, 5))
    # créneaux flottants tout autour : séparés de la base (vide)
    for k in range(8):
        am = math.radians(45.0 * k)
        for i in (-2, -1, 0, 1, 2):
            dt = i * 0.42
            cx, cy = 3.02 * math.cos(am) - math.sin(am) * dt, 3.02 * math.sin(am) + math.cos(am) * dt
            hh = 0.34 if i % 2 == 0 else 0.22
            b.put(M["or"], G.boite((cx, cy, z0 + 0.82 + hh / 2), (0.1, 0.24, hh), am))
            b.put(M["nacre"], G.boite((cx, cy, z0 + 0.84 + hh + 0.04), (0.13, 0.27, 0.04), am))
    # ---------------------------------------------------------------------------- tambour : octogone de nacre, baies toutes différentes
    z1, z2 = z0 + 0.72, z0 + 2.95
    rt = 2.15
    b.put(M["nacre"], G.tour([(z1, rt + 0.12), (z1 + 0.14, rt + 0.04), (z1 + 0.2, rt), (z2 - 0.1, rt - 0.14), (z2, rt - 0.02), (z2 + 0.07, rt + 0.1)], 8, "z", a0=a8, a1=a8 + G.TAU, cap1=True))
    b.put(M["or"], F.bague((0.0, 0.0, z1 + 0.16), rt - 0.05, rt + 0.085, 0.05, "z", 8, 0.012, a0=a8, a1=a8 + G.TAU))
    b.put(M["or"], F.bague((0.0, 0.0, z2 + 0.03), rt - 0.1, rt + 0.13, 0.09, "z", 8, 0.015, a0=a8, a1=a8 + G.TAU))
    apo_t = rt * math.cos(a8)
    motifs = (((-0.46, 1.34), (0.0, 1.76), (0.46, 1.34)), ((-0.3, 1.5), (0.3, 1.5)), ((-0.52, 1.0), (-0.17, 1.62), (0.17, 1.62), (0.52, 1.0)), ((0.0, 1.8),),
              ((-0.46, 1.5), (0.0, 1.0), (0.46, 1.5)), ((-0.3, 1.2), (0.3, 1.66)), ((-0.48, 1.6), (0.0, 1.3), (0.48, 1.6)), ((-0.28, 1.72), (0.28, 1.72)))
    for k in range(8):
        am = math.radians(45.0 * k)
        n = (math.cos(am), math.sin(am), 0.05)
        base = (apo_t * math.cos(am), apo_t * math.sin(am), z1 + 0.24)
        for dt, ht in motifs[k]:
            p = (base[0] - math.sin(am) * dt, base[1] + math.cos(am) * dt, base[2])
            wi = 0.24 if len(motifs[k]) > 1 else 0.42
            b.put(M["or_s"], F.sur_face(F.plaque(F.ogive(wi + 0.1, ht + 0.1), 0.02), p, n))
            b.put(M["baie"], F.sur_face(F.plaque(F.ogive(wi, ht), 0.034), (p[0], p[1], p[2] + 0.02), n))
            b.put(M["or"], F.sur_face(F.plaque([(-0.012, 0.0), (0.012, 0.0), (0.012, ht * 0.95), (-0.012, ht * 0.95)], 0.042), (p[0], p[1], p[2] + 0.02), n))
        # pilastre d'angle
        ac = am + a8
        pc = (rt * 0.985 * math.cos(ac), rt * 0.985 * math.sin(ac), z1 + 0.2)
        b.put(M["or_s"], F.poutre([(0.0, 0.14, 0.14), (2.0, 0.09, 0.09)]), (lambda v, pc=pc: (pc[0] + v[1], pc[1] + v[2], pc[2] + v[0])))
    # ---------------------------------------------------------------------------- arcs-boutants et pinacles sur la base
    for k in range(8):
        ac = a8 + k * G.TAU / 8
        c0, s0 = math.cos(ac), math.sin(ac)
        pied_ = (2.88 * c0, 2.88 * s0, z0 + 0.72)
        b.put(M["orb"], F.fleche(0.16, 1.9, 8), (lambda v, p=pied_: (v[0] + p[0], v[1] + p[1], v[2] + p[2])))
        b.put(M["or"], F.bague((pied_[0], pied_[1], pied_[2] + 0.5), 0.04, 0.15, 0.05, "z", 8, 0.01))
        b.put(M["lum"], F.cristal((pied_[0], pied_[1], pied_[2] + 2.0), 0.035, 0.07))
        ctrl = [(2.82 * c0, 2.82 * s0, z0 + 1.42), (2.5 * c0, 2.5 * s0, z0 + 2.22), (2.14 * c0, 2.14 * s0, z0 + 2.6)]
        pts = G.catmull(ctrl, 5)
        b.put(M["nacre"], G.tube(pts, 0.05, 6))
        b.put(M["or"], G.tube([G.add(q, (0.0, 0.0, 0.055)) for q in pts], 0.014, 5))
    # ---------------------------------------------------------------------------- toit d'écailles d'or
    z3 = z2 + 0.06
    b.put(M["toit"], G.tour([(z3, rt + 0.06), (z3 + 0.34, rt - 0.42), (z3 + 0.75, rt - 0.98), (z3 + 1.0, 1.0)], 8, "z", a0=a8, a1=a8 + G.TAU))
    b.put(M["or"], F.bague((0.0, 0.0, z3 + 1.0), 0.72, 1.06, 0.1, "z", 8, 0.02, a0=a8, a1=a8 + G.TAU))
    for k in range(8):
        ac = a8 + k * G.TAU / 8
        c0, s0 = math.cos(ac), math.sin(ac)
        b.put(M["or"], G.tube([((rt + 0.06) * c0, (rt + 0.06) * s0, z3 + 0.01), ((rt - 0.42) * c0, (rt - 0.42) * s0, z3 + 0.36), ((rt - 0.98) * c0, (rt - 0.98) * s0, z3 + 0.77), (1.0 * c0, 1.0 * s0, z3 + 1.0)], 0.024, 5))
    # ---------------------------------------------------------------------------- couronne : flèches inclinées vers l'extérieur (3 tailles) + une flèche maîtresse
    z4 = z3 + 1.0
    b.put(M["orb"], F.fleche(0.5, 4.45, 8, 1.2), (lambda v: (v[0], v[1], v[2] + z4)))
    for z_, re_ in ((0.5, 0.42), (1.25, 0.31), (2.3, 0.2)):
        b.put(M["or"], F.bague((0.0, 0.0, z4 + z_), 0.1, re_, 0.09, "z", 8, 0.02, a0=a8, a1=a8 + G.TAU))
    b.put(M["coeur"], F.cristal((0.0, 0.0, z4 + 4.65), 0.11, 0.24))
    for k in range(5):
        ak = G.TAU * k / 5 + 0.42
        c0, s0 = math.cos(ak), math.sin(ak)
        bp = (1.0 * c0, 1.0 * s0, z4 + 0.02)
        d = (0.2 * c0, 0.2 * s0, 1.0)
        b.put(M["orb"], F.incline(F.fleche(0.3, 3.3, 8), bp, d))
        b.put(M["or"], F.incline(F.bague((0.0, 0.0, 0.8), 0.06, 0.25, 0.08, "z", 8, 0.015), bp, d))
        b.put(M["or"], F.incline(F.bague((0.0, 0.0, 1.7), 0.04, 0.16, 0.06, "z", 8, 0.012), bp, d))
        tip = G.add(bp, G.mul(G.norm(d), 3.42))
        b.put(M["cristal_m"], F.cristal(tip, 0.075, 0.15))
    for k in range(5):
        ak = G.TAU * (k + 0.5) / 5 + 0.42
        c0, s0 = math.cos(ak), math.sin(ak)
        bp = (1.08 * c0, 1.08 * s0, z4 - 0.02)
        d = (0.34 * c0, 0.34 * s0, 1.0)
        b.put(M["or"], F.incline(F.fleche(0.16, 1.7, 6), bp, d))
    # ---------------------------------------------------------------------------- soleil de l'ostensoir (l'arme), à l'avant, face à +X
    ct = (2.95, 0.0, z0 + 1.95)
    x_av = (1.0, 0.0, 0.06)
    b.put(M["or"], F.pose(F.bague((0.0, 0.0, 0.0), 0.56, 0.78, 0.14, "x", 28, 0.025), ct, x_av))
    b.put(M["or_s"], F.pose(F.bague((0.0, 0.0, 0.0), 0.8, 0.86, 0.06, "x", 28, 0.01), ct, x_av))
    b.put(M["or_s"], F.pose(F.disque((-0.05, 0.0, 0.0), 0.6, 0.05, "x", 28), ct, x_av))
    b.put(M["coeur"], F.pose(G.tour([(-0.02, 0.5), (0.1, 0.4), (0.26, 0.0)], 8, "x"), ct, x_av))
    for i in range(8):      # griffes qui tiennent la pierre
        a = G.TAU * (i + 0.5) / 8
        q0 = (0.1, 0.62 * math.cos(a), 0.62 * math.sin(a))
        q1 = (0.2, 0.34 * math.cos(a), 0.34 * math.sin(a))
        b.put(M["or"], F.pose(F.bielle(q0, q1, 0.05, 0.05, (1.0, 0.0, 0.0)), ct, x_av))
    for i in range(16):
        a = G.TAU * i / 16
        lg = 2.05 if i % 2 == 0 else 1.32
        wd = 0.3 if i % 2 == 0 else 0.2
        ca, sa = math.cos(a), math.sin(a)
        # rayon : losange effilé, à plat dans le plan du disque (Y, Z locaux), mince en X
        v, fa, uv = G.tour([(0.8, wd), (0.92, wd * 0.82), (lg, 0.0)], 4, "x")
        v = [(q[1] * 0.3, q[0] * ca - q[2] * sa, q[0] * sa + q[2] * ca) for q in v]
        b.put(M["or" if i % 2 == 0 else "or_s"], F.pose((v, fa, uv), ct, x_av))
    # ---------------------------------------------------------------------------- 4 lanternes-prismes sur les angles avant et arrière de la base
    for ang_d, s_ in ((55.0, 1.0), (-55.0, 1.0), (125.0, 0.85), (-125.0, 0.85)):
        ac = math.radians(ang_d)
        c0, s0 = math.cos(ac), math.sin(ac)
        pt = (2.62 * c0, 2.62 * s0, z0 + 0.72)
        b.put(M["or_s"], F.disque((pt[0], pt[1], pt[2] + 0.1), 0.22 * s_, 0.2, "z", 8))
        b.put(M["cristal_m"], G.tour([(pt[2] + 0.2, 0.0), (pt[2] + 0.5, 0.2 * s_), (pt[2] + 0.92, 0.0)], 6, "z", (pt[0], pt[1], 0.0)))
        b.put(M["lum"], F.cristal((pt[0], pt[1], pt[2] + 0.5), 0.1 * s_, 0.17))
        for i in range(4):
            ax = G.TAU * i / 4 + 0.3
            b.put(M["or"], F.bielle((pt[0] + 0.22 * s_ * math.cos(ax), pt[1] + 0.22 * s_ * math.sin(ax), pt[2] + 0.2),
                                    (pt[0] + 0.03 * math.cos(ax), pt[1] + 0.03 * math.sin(ax), pt[2] + 1.02), 0.022, 0.022))
    # ---------------------------------------------------------------------------- 2 anneaux-halos, séparés de la couronne, tournent
    h1 = lots("halo1")
    h1.put(M["or"], F.tore((0.0, 0.0, Z_HALO1), 2.45, 0.045, "z", 80, 8))
    h1.put(M["halo"], F.tore((0.0, 0.0, Z_HALO1), 2.32, 0.018, "z", 80, 6))
    for i in range(12):
        ai = G.TAU * i / 12
        h1.put(M["cristal_m"], F.cristal((2.45 * math.cos(ai), 2.45 * math.sin(ai), Z_HALO1), 0.06, 0.13))
    h2 = lots("halo2")
    h2.put(M["or"], F.tore((0.0, 0.0, Z_HALO2), 1.15, 0.03, "z", 60, 6))
    h2.put(M["halo"], F.tore((0.0, 0.0, Z_HALO2), 1.06, 0.012, "z", 60, 5))
    # ---------------------------------------------------------------------------- halo de particules (fixe dans l'image, tourne lentement)
    p = lots("part")
    for i in range(22):
        a = r.f(0.0, G.TAU)
        rr_ = r.f(2.7, 4.1)
        z = r.f(9.2, 15.0)
        p.put(M["part"], F.cristal((rr_ * math.cos(a), rr_ * math.sin(a), z), r.f(0.04, 0.075), r.f(0.07, 0.13)))
    # ---------------------------------------------------------------------------- pattes
    for k in range(8):
        nom = str(k)
        _cuisse(lots("cuisse" + nom), M)
        _tibia(lots("tibia" + nom), M)
        _genou(lots("genou" + nom), M)
        _pied(lots("pied" + nom), M)
