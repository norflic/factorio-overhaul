"""CUIRASSÉ (famille blindée, PLAN §5 ter) : un biter bas et large. Tête, grand œil noir et mandibules de la famille vanilla, sortis de la coque ;
dos en tuiles de chitine dure, bouclier frontal lisse, 6 longues pattes articulées ; la coque ondule en courant (critique du 1er novembre)."""
import numpy as np

import anatomie as A
import sdf
from sdf import BRUIT, Ell, Fn, Os, Repere, rot_x, rot_y, smax, smin

NOM = "cuirasse"
DENSITE = 120.0        # px par tuile du rendu (le gros plan) ; 1 unité = 1 tuile à l'échelle de référence
CREUX = 0.030          # portée (tuiles) du creux peint : joints fins et noirs
AO = 0.22              # portée du liseré de contact
REFLET = 1300.0        # puissance de la source vue par les seuls reflets
ETIQUETTE = "Cuirassé"

PALETTES = {
    "coque": dict(sombre=(0.10, 0.050, 0.016), clair=(0.38, 0.21, 0.060), f=2.2, trainees=(0.24, 0.040, 0.016), force_trainees=0.6, fin_force=0.24,
                  usure=(0.030, 0.012, 0.006), force_usure=0.82, bord=(0.58, 0.40, 0.18), gain_bord=1.0, rude=0.36, verni=0.55, relief=0.25, creux=0.02),
    "bouclier": dict(sombre=(0.12, 0.060, 0.018), clair=(0.42, 0.24, 0.070), f=2.0, trainees=(0.26, 0.042, 0.016), force_trainees=0.7, fin_force=0.24,
                     bord=(0.62, 0.44, 0.20), gain_bord=1.2, rude=0.34, verni=0.6, relief=0.25, creux=0.03),
    "face": dict(sombre=(0.17, 0.050, 0.040), clair=(0.52, 0.24, 0.155), f=3.5, trainees=(0.38, 0.085, 0.045), force_trainees=0.8, fin_force=0.2, bord=(0.72, 0.50, 0.34), gain_bord=1.4,
                 rude=0.30, verni=0.55, relief=0.10, creux=0.10),
    "chair": dict(sombre=(0.20, 0.022, 0.018), clair=(0.46, 0.070, 0.045), f=7.0, fin_force=0.2, rude=0.38, verni=0.25, relief=0.30, creux=0.12),
    "patte": dict(sombre=(0.34, 0.17, 0.09), clair=(0.70, 0.46, 0.28), f=13.0, trainees=(0.36, 0.05, 0.03), force_trainees=0.85, fin_force=0.22, bout=(0.40, 0.055, 0.03), bout_de=0.55,
                  bord=(0.88, 0.70, 0.48), gain_bord=2.0, rude=0.34, verni=0.45, relief=0.15, creux=0.20),
    "griffe": dict(sombre=(0.30, 0.040, 0.024), clair=(0.62, 0.13, 0.060), f=9.0, fin_force=0.12, bout=(0.13, 0.012, 0.010), bout_de=0.65, rude=0.28, verni=0.7, relief=0.05, creux=0.25),
    "oeil": dict(sombre=(0.003, 0.003, 0.004), clair=(0.010, 0.010, 0.012), f=30.0, fin_force=0.0, rude=0.34, verni=0.12, relief=0.0, creux=0.7),
}


def _lisse(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def construire(phase=0.0):
    f = sdf.Forme(NOM, ((-2.15, -2.05, -0.02), (2.30, 2.05, 1.45)), 0.0095)
    f.marge = 0.06
    t = 2.0 * np.pi * phase
    bob = 0.048 * np.cos(2 * t)
    corps = Repere((0.045 * np.sin(2 * t), 0.018 * np.sin(t), 0.58 + bob), rot_x(0.055 * np.sin(t)) @ rot_y(0.035 * np.sin(2 * t + 0.7)))

    def _coque_base(q):
        x = q[:, 0]
        ondule = 0.028 * np.sin(x * 3.4 - 2.0 * t)              # la coque roule : 2 à 3 px à zoom 1 avec le rebond
        fuseau = 1.0 + 0.24 * np.clip(x, -1.0, 0.2)
        qq = np.stack([x + 0.010 * BRUIT(q * 1.2 + 1), q[:, 1] / fuseau, q[:, 2] - ondule], axis=1)
        return A.ell(qq, (0, 0, 0), (1.02, 0.82, 0.40)), np.stack([x, q[:, 1], q[:, 2] - ondule], axis=1)

    def fn_coque(q):
        base, qq = _coque_base(q)
        d, _u = A.plaques(qq, base, 1.02, 5.0, 6.0, 0.055, 0.010, centre_z=-0.1, gouttiere=0.012, deforme=(0.10, 0.12), alea=0.012, puissance=6.0, pente=0.10)
        d = d - 0.0045 * BRUIT.fbm(q * 9.0 + 2.0, octaves=3)                     # chitine cabossée : le reflet se casse, plus de plastique
        feston = -0.17 + 0.012 * np.sin(q[:, 0] * 13.0 + 1.5 * np.sign(q[:, 1]))
        return smax(d, feston - q[:, 2], 0.012)

    def g_coque(q):
        base, qq = _coque_base(q)
        return A.plaques(qq, base, 1.02, 5.0, 6.0, 0.055, 0.010, centre_z=-0.1, gouttiere=0.012, deforme=(0.10, 0.12), alea=0.012, puissance=6.0, pente=0.10)[1]

    f.groupe("coque", k=0.008).append(Fn(fn_coque, corps, fn_g=g_coque, k=0.008))

    # Bouclier frontal : plaque lisse, large, à lèvre épaisse, échancrée pour la tête ; une corne de flanc, l'autre cassée.
    b = corps.compose((0.60, 0.0, 0.03), rot_y(0.10))

    def fn_bouclier(q):
        d = A.ell(q + 0.008 * BRUIT(q * 1.5 + 3)[:, None], (0, 0, 0), (0.50, 0.93, 0.50))
        r = np.sqrt((q[:, 1] / 0.93) ** 2 + (q[:, 0] / 0.50) ** 2)
        d = d - 0.034 * _lisse(0.70, 0.93, r) - 0.016 * np.exp(-(q[:, 1] / 0.07) ** 2) * _lisse(-0.2, 0.2, q[:, 2])
        d = d - 0.0045 * BRUIT.fbm(q * 9.0 + 7.0, octaves=3)
        d = smax(d, -A.ell(q, (0.48, 0.0, -0.14), (0.30, 0.40, 0.34)), 0.022)    # échancrure de la tête
        return smax(d, -0.17 - q[:, 2], 0.015)

    vols = f.groupe("bouclier", k=0.006)
    vols.append(Fn(fn_bouclier, b, k=0.010))
    vols.append(Os(b.monde((0.10, 0.82, -0.04)), b.monde((0.30, 1.14, -0.03)), 0.105, 0.012, k=0.04))
    vols.append(Os(b.monde((0.08, -0.82, -0.05)), b.monde((0.18, -1.00, -0.04)), 0.105, 0.060, k=0.04))

    # Tête, nettement hors du bouclier, légèrement baissée.
    face = f.groupe("face", k=0.012)
    chair = f.groupe("chair", k=0.020)
    pattes = f.groupe("patte", k=0.012)
    griffes = f.groupe("griffe", k=0.010)
    yeux = f.groupe("oeil", k=0.002)
    tete = corps.compose((1.20, 0.0, -0.13), rot_y(0.20 + 0.04 * np.sin(2 * t)))
    A.tete_biter(tete, 0.64, face, griffes, yeux, ouvre=0.5 + 0.5 * np.sin(2 * t), graine=4.0)

    # Dessous et joints : chair rouge.
    chair.append(Ell((-0.05, 0, -0.17), (0.92, 0.68, 0.17), corps, k=0.05, peau=(0.006, 8.0, 40.0)))
    chair.append(Ell((0.90, 0, -0.14), (0.34, 0.36, 0.17), corps, k=0.05, peau=(0.006, 8.0, 41.0)))

    # Six longues pattes à deux articulations visibles, genoux hauts, tripode alterné à grande foulée.
    rangs = ((0.60, 0.46, 0.0), (0.04, 0.03, 0.5), (-0.50, -0.52, 0.0))
    for ir, (xh, ouv, dephasage) in enumerate(rangs):
        for s in (-1.0, 1.0):
            u = phase + dephasage + (0.5 if s > 0 else 0.0)
            dx, dz = A.pas(u, 0.33, 0.26, appui=0.50)
            hanche = corps.monde((xh, 0.60 * s, -0.17))
            pied = np.array([xh + ouv + dx, s * (1.66 - 0.07 * abs(ir - 1)), dz + 0.008])
            graine = ir * 3.1 + s * 11.0
            ch, gr, genou, cheville = A.patte(hanche, pied, 0.72, 0.66, (0.0, s * 0.7, 1.0), 0.088, 0.048, 0.027, griffe=0.30,
                                              rep_graine=graine, ventre=0.012, peau=(0.004, 30.0, 11.0), griffe_r=0.008, griffe_dir=(0.0, -s * 0.42, 1.0), k=0.014)
            pattes.extend(ch)
            griffes.extend(gr)
            pattes.append(sdf.ell_sur(genou - (genou - hanche) * 0.24, genou + (genou - hanche) * 0.05, 0.060, 0.052, (0.0, s * 0.5, 1.0), k=0.02, peau=(0.004, 30.0, 13.0), g=0.40))
            chair.append(Ell(hanche, (0.115, 0.105, 0.09), k=0.03))
    return f
