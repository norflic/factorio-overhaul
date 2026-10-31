"""CUIRASSÉ (famille blindée, PLAN §5 ter) : bas, large, 6 pattes courtes, dos en tuiles, bouclier frontal."""
import numpy as np

import anatomie as A
import sdf
from sdf import BRUIT, Ell, Fn, Os, Repere, rot_x, rot_y, smax, smin

NOM = "cuirasse"
DENSITE = 130.0        # px par tuile du rendu (le gros plan) ; 1 unité = 1 tuile à l'échelle de référence
CREUX = 0.05           # portée (tuiles) du creux peint
AO = 0.22              # portée du liseré de contact
ETIQUETTE = "Cuirassé"

PALETTES = {
    "carapace": dict(sombre=(0.050, 0.060, 0.078), clair=(0.150, 0.170, 0.195), f=3.2, taches=(0.085, 0.060, 0.040), force_taches=0.45,
                     usure=(0.46, 0.43, 0.36), force_usure=0.62, bord=(0.50, 0.48, 0.41), gain_bord=3.0, rude=0.46, verni=0.55, relief=0.35, creux=0.16),
    "bouclier": dict(sombre=(0.075, 0.068, 0.062), clair=(0.21, 0.19, 0.165), f=3.5, taches=(0.035, 0.028, 0.026), force_taches=0.50,
                     bord=(0.50, 0.46, 0.37), gain_bord=1.8, rude=0.46, verni=0.40, relief=0.5, creux=0.14),
    "chair": dict(sombre=(0.16, 0.070, 0.042), clair=(0.40, 0.21, 0.105), f=9.0, taches=(0.10, 0.030, 0.025), force_taches=0.55,
                  veines=(0.18, 0.040, 0.035), bout=(0.10, 0.045, 0.035), bout_de=0.45, bord=(0.56, 0.38, 0.24), gain_bord=3.0, rude=0.42, verni=0.10, relief=0.8, creux=0.22),
    "griffe": dict(sombre=(0.050, 0.040, 0.034), clair=(0.17, 0.14, 0.11), f=8.0, bout=(0.52, 0.46, 0.36), bout_de=0.5, rude=0.30, verni=0.5, relief=0.2, creux=0.4),
    "oeil": dict(sombre=(0.26, 0.09, 0.012), clair=(0.70, 0.30, 0.03), f=30.0, rude=0.12, verni=1.0, relief=0.0, creux=0.5),
}


def construire(phase=0.0):
    f = sdf.Forme(NOM, ((-1.60, -1.62, -0.02), (1.78, 1.62, 1.10)), 0.009)
    f.marge = 0.05
    t = 2.0 * np.pi * phase
    corps = Repere((0.015 * np.sin(2 * t), 0, 0.42 + 0.018 * np.cos(2 * t)), rot_x(0.016 * np.sin(t)) @ rot_y(0.012 * np.sin(2 * t)))

    # Carapace : dôme fuselé vers l'arrière, tuiles imbriquées, jupe ondulée.
    def carapace(q):
        x = q[:, 0]
        fuseau = 1.0 + 0.20 * np.clip(x, -1.0, 0.25)
        qq = q + 0.045 * np.stack([BRUIT(q * 1.1 + 1), BRUIT(q * 1.1 + 5), BRUIT(q * 1.1 + 9)], axis=1)
        p = np.stack([qq[:, 0] / 1.04, qq[:, 1] / (0.92 * fuseau), qq[:, 2] / 0.44], axis=1)
        k0 = np.linalg.norm(p, axis=1)
        k1 = np.linalg.norm(p / np.array([1.04, 0.92, 0.44], np.float32), axis=1)
        base = k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)
        d, _u = A.plaques(q, base, 1.05, 7.0, 7.0, 0.058, 0.018, gouttiere=0.012, alea=0.024, deforme=(0.40, 0.42), stries=0.0006)
        # jupe : bord festonné qui couvre le haut des pattes
        feston = -0.19 + 0.022 * np.sin(q[:, 0] * 15.0 + 1.5 * np.sign(q[:, 1])) + 0.010 * BRUIT(q * 7.0)
        return smax(d, feston - q[:, 2], 0.022)

    def usure_carapace(q):
        p = np.stack([q[:, 0] / 1.04, q[:, 1] / 0.92, q[:, 2] / 0.44], axis=1)
        base = np.linalg.norm(p, axis=1) - 1.0
        return A.plaques(q, base, 1.05, 7.0, 7.0, 0.058, 0.018, gouttiere=0.012, alea=0.024, deforme=(0.40, 0.42))[1]

    f.groupe("carapace", k=0.02).append(Fn(carapace, corps, fn_g=usure_carapace))

    # Bouclier frontal : DEUX LOBES et une quille, jamais un disque ; un bossage décentré, des tubercules, une corne latérale cassée.
    bouclier = corps.compose((0.90, 0.0, -0.06), rot_y(-0.42))

    def fn_bouclier(q):
        qq = q + 0.028 * np.stack([BRUIT(q * 2.2 + 13), BRUIT(q * 2.2 + 17), BRUIT(q * 2.2 + 19)], axis=1)
        lobe_g = A.ell(qq, (0.0, 0.40, 0.07), (0.25, 0.56, 0.42))
        lobe_d = A.ell(qq, (0.0, -0.37, 0.03), (0.25, 0.53, 0.46))
        quille = A.ell(qq, (0.05, 0.02, -0.06), (0.28, 0.21, 0.49))
        d = smin(smin(lobe_g, lobe_d, 0.09), quille, 0.10)
        tuber = 0.011 * np.clip(BRUIT(q * 8.0 + 5.0) * 3.2 - 1.0, 0.0, 1.0)
        stries = 0.0028 * np.sin(np.hypot(q[:, 1] / 0.9, q[:, 2] / 0.5) * 46.0 + 3.0 * BRUIT(q * 2.5 + 3.0))
        d = d - tuber - stries - 0.0035 * BRUIT.fbm(q * 19.0, octaves=2)
        return smax(d, -(q[:, 0] + 0.07), 0.03)

    f.groupe("bouclier", k=0.022).append(Fn(fn_bouclier, bouclier, fn_g=lambda q: np.zeros(len(q), np.float32)))
    bvols = f.groupes[-1][2]
    for a_, b_, ra, rb in (((0.06, 0.78, 0.10), (0.30, 1.02, 0.03), 0.125, 0.018),      # corne entière
                           ((0.06, -0.74, 0.08), (0.22, -0.90, 0.02), 0.120, 0.070)):   # corne cassée, bout émoussé
        bvols.append(Os(bouclier.monde(a_), bouclier.monde(b_), ra, rb, k=0.05, peau=(0.006, 16.0, 7.0), g0=0.0, g1=0.0, graine=ra * 40))
    bvols.append(Ell(bouclier.monde((0.19, 0.13, 0.09)), (0.09, 0.16, 0.13), k=0.06, peau=(0.006, 16.0, 5.0)))     # bossage
    # Ébréchures et balafres, jamais symétriques
    f.creuse(Ell(bouclier.monde((0.10, 0.02, -0.62)), (0.32, 0.25, 0.17)), k=0.05)       # échancrure des mandibules
    f.creuse(Ell(bouclier.monde((0.10, 0.70, 0.42)), (0.20, 0.14, 0.11)), k=0.03)        # éclat du lobe gauche
    for a_, b_, r in (((0.30, -0.50, 0.26), (0.20, -0.16, -0.14), 0.016), ((0.30, 0.46, 0.30), (0.26, 0.68, 0.06), 0.012),
                      ((0.28, -0.12, -0.26), (0.24, 0.20, -0.36), 0.009)):
        f.creuse(Os(bouclier.monde(a_), bouclier.monde(b_), r, r * 0.5), k=0.010)

    # Dessous, tête et mandibules : la tête dépasse sous le bouclier, mandibules longues et dentées, ce qui mord se voit.
    chair = f.groupe("chair", k=0.03)
    griffes = f.groupe("griffe", k=0.012)
    yeux = f.groupe("oeil", k=0.004)
    carapace = f.groupes[0][2]
    peau = (0.010, 9.0, 40.0)
    chair.append(Ell((-0.05, 0, -0.17), (0.92, 0.70, 0.16), corps, k=0.06, peau=peau))
    chair.append(Ell((0.96, 0, -0.24), (0.40, 0.44, 0.14), corps, k=0.06, peau=peau))
    for s in (-1.0, 1.0):
        lg = 1.0 if s > 0 else 0.92                     # une mandibule plus courte
        m0 = corps.monde((1.08, 0.24 * s, -0.25))
        m1 = corps.monde((1.38, 0.34 * s * lg, -0.28))
        m2 = corps.monde((1.61 * lg, 0.11 * s, -0.33))
        griffes.append(Os(m0, m1, 0.086, 0.062, k=0.020, g0=0.1, g1=0.6, graine=7.0 * s))
        griffes.append(Os(m1, m2, 0.062, 0.012, k=0.014, g0=0.6, g1=1.0, graine=9.0 * s))
        for tt, lon in ((0.25, 0.07), (0.6, 0.09)):
            c = m1 + (m0 - m1) * tt
            griffes.append(Os(c, c + np.array([0.035, -s * lon, -0.005]), 0.028, 0.006, k=0.012, g0=0.6, g1=1.0, graine=tt))
    for pos, ray in (((1.10, 0.40, -0.14), 0.040), ((1.12, -0.44, -0.16), 0.034), ((1.19, 0.28, -0.17), 0.022)):
        yeux.append(Ell(corps.monde(pos), (ray, ray, ray * 0.8), k=0.003))

    # Quille dorsale : tubercules irréguliers sur le dos, épines de flanc qui découpent la silhouette.
    for x, y, h, r in ((0.52, 0.03, 0.09, 0.055), (0.24, -0.04, 0.12, 0.066), (-0.05, 0.02, 0.10, 0.060), (-0.32, -0.03, 0.13, 0.062), (-0.60, 0.03, 0.08, 0.048)):
        z = 0.44 * np.sqrt(max(1.0 - (x / 1.04) ** 2, 0.0)) - 0.015
        carapace.append(Os(corps.monde((x, y, z)), corps.monde((x - 0.05, y, z + h)), r, r * 0.34, k=0.035, g0=0.9, g1=0.9, graine=x * 11))
    for x, lon, sgn in ((0.42, 0.11, 1), (0.02, 0.16, 1), (-0.36, 0.13, 1), (-0.70, 0.09, 1), (0.30, 0.15, -1), (-0.14, 0.12, -1), (-0.52, 0.16, -1)):
        fus = 1.0 + 0.20 * min(max(x, -1.0), 0.25)
        y = sgn * 0.90 * fus * np.sqrt(max(1.0 - (x / 1.04) ** 2, 0.0))
        c = corps.monde((x, y * 0.97, -0.09))
        carapace.append(Os(c, c + np.array([-0.05, sgn * lon, -0.018]), 0.052, 0.012, k=0.030, g0=0.9, g1=0.9, graine=x * 7 + sgn))

    # Six pattes trapues : cuisse armée d'une plaque, tibia à ergots, tarse crochu au sol ; tripode alterné.
    rangs = ((0.58, 0.26, 0.0), (0.02, 0.0, 0.5), (-0.54, -0.28, 0.0))
    for ir, (xh, ouv, dephasage) in enumerate(rangs):
        for s in (-1.0, 1.0):
            u = phase + dephasage + (0.5 if s > 0 else 0.0)
            dx, dz = A.pas(u, 0.21, 0.15, appui=0.56)
            hanche = corps.monde((xh, 0.60 * s, -0.20))
            pied = np.array([xh + ouv + dx, s * (1.27 - 0.05 * abs(ir - 1)), dz + 0.010])
            graine = ir * 3.1 + s * 11.0
            ch, gr, genou, cheville = A.patte(hanche, pied, 0.53, 0.47, (0.0, s * 0.85, 1.0), 0.098, 0.066, 0.036, griffe=0.17,
                                              rep_graine=graine, peau=(0.006, 22.0, 60.0), ventre=0.020, griffe_r=0.011,
                                              griffe_dir=(0.0, -s * 0.62, 1.0))
            chair.extend(ch)
            griffes.extend(gr)
            haut = (0.0, s * 0.5, 1.0)
            carapace.append(sdf.ell_sur(hanche + (genou - hanche) * 0.45, genou + (genou - hanche) * 0.05, 0.075, 0.046, haut, k=0.018, peau=(0.004, 26.0, graine)))
            carapace.append(sdf.ell_sur(genou - (cheville - genou) * 0.06, genou + (cheville - genou) * 0.46, 0.058, 0.032, (0.0, s, 0.35), k=0.014, peau=(0.004, 26.0, graine + 2.0)))
            for tt, ep in ((0.48, 0.070), (0.74, 0.052)):
                pv = genou + (cheville - genou) * tt
                griffes.append(Os(pv, pv + np.array([0.012, s * ep, ep * 0.52]), 0.024, 0.006, k=0.010, g0=0.55, g1=1.0, graine=graine + tt))
    return f


def sdf_lisse(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
