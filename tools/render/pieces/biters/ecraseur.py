"""ÉCRASEUR (classe neuve, PLAN §5 ter) : massif, 2 pattes-piliers, mâchoire en marteau. La masse est en avant, tout le poids sur deux colonnes."""
import numpy as np

import anatomie as A
import sdf
from sdf import BRUIT, Ell, Fn, Os, Repere, rot_x, rot_y, smax, smin

NOM = "ecraseur"
DENSITE = 90.0
CREUX = 0.10
AO = 0.38
ETIQUETTE = "Écraseur"

PALETTES = {
    "carapace": dict(sombre=(0.040, 0.026, 0.026), clair=(0.125, 0.070, 0.060), f=1.7, taches=(0.016, 0.012, 0.014), force_taches=0.55,
                     usure=(0.36, 0.25, 0.18), force_usure=0.50, bord=(0.40, 0.29, 0.21), gain_bord=2.0, rude=0.50, verni=0.42, relief=0.5, creux=0.14),
    "chair": dict(sombre=(0.075, 0.022, 0.020), clair=(0.24, 0.085, 0.060), f=2.7, taches=(0.05, 0.012, 0.014), force_taches=0.6,
                  veines=(0.085, 0.012, 0.016), bord=(0.40, 0.20, 0.13), gain_bord=2.2, rude=0.48, verni=0.08, relief=1.0, creux=0.2),
    "os": dict(sombre=(0.050, 0.032, 0.028), clair=(0.15, 0.095, 0.072), f=2.6, taches=(0.024, 0.016, 0.016), force_taches=0.5,
               usure=(0.58, 0.50, 0.36), force_usure=0.92, bord=(0.66, 0.58, 0.44), gain_bord=1.6, rude=0.52, verni=0.25, relief=0.9, creux=0.14),
    "griffe": dict(sombre=(0.055, 0.042, 0.034), clair=(0.20, 0.16, 0.115), f=4.0, bout=(0.62, 0.55, 0.40), bout_de=0.5, rude=0.38, verni=0.35, relief=0.5, creux=0.3),
    "oeil": dict(sombre=(0.55, 0.30, 0.012), clair=(1.00, 0.72, 0.06), f=30.0, rude=0.10, verni=1.0, relief=0.0, creux=0.5),
}


def _lisse(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _ell(q, c, r):
    p = (q - np.asarray(c, np.float32)) / np.asarray(r, np.float32)
    k0 = np.linalg.norm(p, axis=1)
    k1 = np.linalg.norm(p / np.asarray(r, np.float32), axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def construire(phase=0.0):
    f = sdf.Forme(NOM, ((-2.95, -2.75, -0.03), (3.85, 2.75, 4.85)), 0.018)
    f.marge = 0.12
    t = 2.0 * np.pi * phase
    # Démarche de colosse : tout le corps bascule sur la jambe d'appui, retombe à chaque pas.
    bascule = np.sin(t)
    rebond = np.cos(2.0 * t)
    corps = Repere((0.03 * rebond, -0.13 * bascule, 2.35 + 0.09 * rebond), rot_x(-0.075 * bascule) @ rot_y(0.05 + 0.035 * rebond))

    carapace = f.groupe("carapace", k=0.05)
    chair = f.groupe("chair", k=0.08)
    os_ = f.groupe("os", k=0.05)
    griffes = f.groupe("griffe", k=0.03)
    yeux = f.groupe("oeil", k=0.01)

    # Masse du dos : tas de bosses fondues, irrégulier ; énormes plaques qui se recouvrent, jupe déchiquetée.
    def base_dos(q):
        qq = q + 0.11 * np.stack([BRUIT(q * 0.75 + 1), BRUIT(q * 0.75 + 5), BRUIT(q * 0.75 + 9)], axis=1)
        d = _ell(qq, (0.0, 0.0, 0.42), (1.30, 1.22, 1.00))
        d = smin(d, _ell(qq, (0.55, 0.08, 0.82), (0.72, 0.98, 0.66)), 0.35)     # garrot, décalé : colosse de travers
        d = smin(d, _ell(qq, (-1.05, -0.06, 0.05), (0.95, 0.95, 0.88)), 0.40)   # croupe basse
        return d

    def fn_dos(q):
        d, _u = A.plaques(q, base_dos(q), 2.1, 7.0, 6.0, 0.13, 0.040, centre_z=0.1, gouttiere=0.030, deforme=(0.25, 0.28), graine=5.7, alea=0.035, stries=0.003)
        d = d - 0.012 * BRUIT.fbm(q * 6.0 + 2.0, octaves=3)
        jupe = -0.06 + 0.085 * np.sin(q[:, 0] * 4.2 + 1.1 * np.sign(q[:, 1])) + 0.05 * BRUIT(q * 2.6 + 3.0) + 0.30 * np.clip(q[:, 0] - 0.5, 0.0, 1.0)
        return smax(d, jupe - q[:, 2], 0.05)

    def g_dos(q):
        return A.plaques(q, base_dos(q), 2.1, 7.0, 6.0, 0.13, 0.040, centre_z=0.1, gouttiere=0.030, deforme=(0.25, 0.28), graine=5.7, alea=0.035, stries=0.003)[1]

    carapace.append(Fn(fn_dos, corps, k=0.05, fn_g=g_dos))

    # Ventre, cou : chair ridée, plis profonds.
    def plis_cou(t_, a):
        return 0.014 * np.abs(np.sin(t_ * 7.0 + 1.4 * np.sin(a * 2.0) + 0.9 * np.sin(a * 5.0 + 1.0)))

    chair.append(Ell((0.15, 0, -0.04), (1.12, 0.96, 0.62), corps, k=0.14, peau=(0.040, 2.5, 6.0)))
    chair.append(Os(corps.monde((0.92, 0.0, 0.28)), corps.monde((1.86, 0.0, -0.24)), 0.84, 0.64, k=0.16, peau=(0.030, 2.6, 8.0), plis=plis_cou))

    # Scutes du cou, irrégulières, jamais un anneau complet.
    for a_, b_, rl, rm, y_ in (((0.98, 0.0, 0.92), (1.42, 0.0, 0.70), 0.62, 0.15, 0.04), ((1.38, 0.0, 0.72), (1.80, 0.0, 0.46), 0.56, 0.14, -0.07),
                               ((1.20, 0.0, 0.42), (1.60, 0.0, 0.20), 0.26, 0.10, 0.74), ((1.28, 0.0, 0.34), (1.62, 0.0, 0.12), 0.24, 0.10, -0.76)):
        aa = corps.monde((a_[0], y_, a_[2]))
        bb = corps.monde((b_[0], y_, b_[2]))
        carapace.append(sdf.ell_sur(aa, bb, rl, rm, corps.R @ np.array([0.35, y_ * 0.9, 1.0], np.float32), k=0.05, peau=(0.012, 5.0, y_ * 5.0)))

    # Crâne bas, enfoncé dans les épaules, front de chitine, 3 petits yeux de travers.
    crane = corps.compose((2.04, 0.0, -0.20), rot_y(0.18 + 0.05 * rebond))

    def fn_crane(q):
        d = _ell(q + 0.03 * BRUIT(q * 3.0)[:, None], (0, 0, 0), (0.68, 0.84, 0.48))
        d = smin(d, _ell(q, (-0.06, 0.0, 0.28), (0.50, 0.50, 0.28)), 0.14)
        d = smin(d, _ell(q, (0.26, 0.40, 0.22), (0.36, 0.34, 0.15)), 0.08)       # arcades lourdes, inégales
        d = smin(d, _ell(q, (0.22, -0.44, 0.19), (0.40, 0.36, 0.18)), 0.08)
        return d - 0.011 * BRUIT.fbm(q * 7.0 + 1.0, octaves=3)

    carapace.append(Fn(fn_crane, crane, k=0.09, fn_g=lambda q: np.zeros(len(q), np.float32)))
    for pos, r in (((0.57, 0.30, 0.06), 0.072), ((0.50, -0.44, 0.03), 0.090), ((0.64, -0.08, 0.10), 0.050)):
        yeux.append(Ell(crane.monde(pos), (r, r, r), k=0.012))

    # MÂCHOIRE EN MARTEAU : une seule masse d'os, racine épaisse sous le crâne, barre transversale, deux têtes de masse évasées
    # à face plate, inégales, cloutées. Ce n'est ni un bras ni deux boules : la barre se lit d'un bloc.
    m_rep = corps.compose((2.66, 0.0, -1.32), rot_y(0.20 + 0.14 * rebond) @ rot_x(0.05 * bascule))

    def fn_marteau(q):
        y = q[:, 1] + 0.05
        ay = np.abs(y)
        rayon = np.hypot(q[:, 0], q[:, 2] / 0.92)
        R = 0.33 + 0.30 * _lisse(0.46, 1.00, ay)
        dr = rayon - R
        dy = ay - 1.32 - 0.06 * (y < 0)
        d = np.minimum(np.maximum(dr, dy), 0.0) + np.hypot(np.maximum(dr, 0.0), np.maximum(dy, 0.0)) - 0.075
        racine = _ell(q, (-0.52, 0.0, 0.18), (0.86, 0.72, 0.50))
        d = smin(d, racine, 0.24)
        clous = 0.040 * np.clip(BRUIT(q * 4.2 + 11.0) * 3.0 - 0.9, 0.0, 1.0)
        return d - clous - 0.014 * BRUIT.fbm(q * 5.5 + 3.0, octaves=3)

    def usure_marteau(q):
        # les deux têtes sont polies par les coups ; le milieu reste de la chitine sombre, qui prolonge le crâne
        return (_lisse(0.72, 1.22, np.abs(q[:, 1] + 0.05)) * (0.72 + 0.28 * BRUIT(q * 3.0 + 7.0))).astype(np.float32)

    os_.append(Fn(fn_marteau, m_rep, k=0.05, fn_g=usure_marteau))
    f.creuse(Os(m_rep.monde((0.48, 0.42, 0.26)), m_rep.monde((0.40, 0.02, -0.26)), 0.034, 0.016), k=0.022)      # fente du coup
    f.creuse(Os(m_rep.monde((0.40, -0.96, 0.44)), m_rep.monde((0.52, -1.20, -0.14)), 0.030, 0.014), k=0.020)
    for s in (1.0, -1.0):
        a = crane.monde((-0.10, s * 0.58, -0.08))
        b = m_rep.monde((-0.52, s * 0.52, 0.22))
        chair.append(Os(a, b, 0.30, 0.30, k=0.14, peau=(0.020, 4.0, 3.0 * s), ventre=0.02, plis=lambda t_, a_: 0.014 * np.abs(np.sin(t_ * 12.0 + a_))))
    chair.append(Ell(m_rep.monde((-0.34, 0, 0.56)), (0.36, 0.52, 0.16), k=0.06, peau=(0.02, 4.0, 2.0)))    # gueule, fond sombre
    # Défenses plantées dans la barre, inégales : cassées d'un côté.
    for y, h, r, inc in ((0.74, 0.60, 0.12, 0.08), (0.28, 0.40, 0.09, -0.04), (-0.26, 0.50, 0.10, 0.05), (-0.80, 0.24, 0.13, -0.08)):
        griffes.append(Os(m_rep.monde((0.12, y, 0.28)), m_rep.monde((0.22 + inc, y + inc, 0.82 + h)), r * 1.15, r * 0.22, k=0.04, g0=0.3, g1=1.0, graine=y * 9))

    # Deux moignons de bras repliés sous le cou : vestige vivant, jamais une pièce.
    for s, le in ((1.0, 1.0), (-1.0, 0.86)):
        e = corps.monde((1.08, s * 1.02, -0.30))
        c = corps.monde((1.22, s * 1.34, -0.82 * le))
        m = corps.monde((1.66, s * 1.26, -0.84 * le))
        chair.append(Os(e, c, 0.25, 0.17, k=0.12, peau=(0.018, 5.0, 5.0 * s), ventre=0.02, g0=0.0, g1=0.4, graine=2 * s))
        chair.append(Os(c, m, 0.17, 0.12, k=0.08, peau=(0.014, 5.0, 8.0 * s), g0=0.4, g1=0.7, graine=4 * s))
        griffes.append(Os(m, m + np.array([0.30, s * 0.05, -0.08]), 0.10, 0.018, k=0.03, g0=0.4, g1=1.0, graine=5 * s))
        griffes.append(Os(m, m + np.array([0.22, s * -0.16, -0.14]), 0.08, 0.016, k=0.03, g0=0.4, g1=1.0, graine=6 * s))

    # Crête dorsale : éperons d'os irréguliers, plantés de travers.
    for x, y, z, h, r, inc in ((0.98, 0.08, 1.14, 0.44, 0.18, -0.10), (0.42, -0.10, 1.38, 0.62, 0.22, -0.18), (-0.22, 0.13, 1.34, 0.50, 0.20, -0.20),
                               (-0.84, -0.05, 0.90, 0.38, 0.18, -0.22), (-1.44, 0.08, 0.66, 0.26, 0.14, -0.20)):
        griffes.append(Os(corps.monde((x, y, z)), corps.monde((x + inc, y + inc * 0.5, z + h)), r, r * 0.20, k=0.06, g0=0.20, g1=1.0, graine=x * 3))

    # Pattes-piliers : colonnes d'éléphant, genoux ridés, cnémides de chitine, pied large à ongles épais.
    def plis_genou(t_, a):
        return 0.012 * _lisse(0.15, 0.0, np.abs(t_ - 0.5) - 0.28) * np.abs(np.sin(t_ * 21.0 + 1.6 * np.sin(a * 3.0))) + 0.006 * np.abs(np.sin(t_ * 9.0 + a))

    for s in (-1.0, 1.0):
        u = phase + (0.5 if s > 0 else 0.0)
        dx, dz = A.pas(u, 0.62, 0.46, appui=0.60)
        hanche = corps.monde((-0.05, s * 1.04, -0.30))
        cheville = np.array([-0.02 + dx, s * 1.26, 0.30 + dz])
        genou = A.ik2(hanche, cheville, 1.02, 1.00, (1.0, s * 0.12, 0.0))
        chair.append(Os(hanche, genou, 0.62, 0.45, k=0.16, ventre=0.06, peau=(0.030, 2.8, 4.0 * s), plis=plis_genou, g0=0.0, g1=0.2, graine=s * 2.0))
        chair.append(Os(genou, cheville, 0.45, 0.36, k=0.10, ventre=0.03, peau=(0.030, 2.8, 7.0 * s), plis=plis_genou, g0=0.2, g1=0.3, graine=s * 3.3))
        chair.append(Ell(genou, (0.48, 0.48, 0.48), k=0.10, peau=(0.03, 3.5, 9.0 * s), plis=None, g=0.2))
        # cnémide : grande plaque courbe sur le devant du tibia
        axe = (cheville - genou) / np.linalg.norm(cheville - genou)
        centre = genou + axe * 0.46 + np.array([0.27, s * 0.08, 0.0])
        ang = np.arctan2(axe[0], -axe[2])
        carapace.append(Ell(centre, (0.15, 0.34, 0.58), R=rot_y(ang), k=0.06, peau=(0.014, 6.0, 3.0 * s)))
        # pied large, ongles
        pied_c = cheville + np.array([0.08, 0.0, -0.17])
        chair.append(Ell(pied_c, (0.60, 0.50, 0.19), k=0.09, peau=(0.018, 5.0, 2.0 * s), plis=None, g=0.3))
        for j, (ax, ay) in enumerate(((0.48, 0.30), (0.58, 0.0), (0.46, -0.30), (-0.36, s * 0.08))):
            griffes.append(Os(pied_c + np.array([ax * 0.62, ay, 0.05]), pied_c + np.array([ax * 1.28, ay * 1.16, -0.085]), 0.19, 0.045, k=0.05, g0=0.15, g1=0.95, graine=j + s))
    return f


def sdf_bosses(q):
    return np.clip(BRUIT(q * 4.2 + 11.0) * 2.2, -0.4, 1.0)
