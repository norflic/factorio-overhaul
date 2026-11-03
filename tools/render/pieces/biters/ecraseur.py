"""ÉCRASEUR (classe neuve, PLAN §5 ter) : un biter colossal. Coque de grandes plaques dures, tête de la famille vanilla (grand œil noir, mandibules
rouges), deux pattes-piliers et, verdict de la critique du 1er novembre, deux avant-bras massifs à massue au lieu de la mâchoire en marteau."""
import numpy as np

import anatomie as A
import sdf
from sdf import BRUIT, Ell, Fn, Os, Repere, rot_x, rot_y, smax, smin

NOM = "ecraseur"
DENSITE = 80.0
CREUX = 0.055
AO = 0.38
REFLET = 1300.0
ETIQUETTE = "Écraseur"
SERIE = {"course": 6, "attaque": 3, "densite": 48.0, "R": 5.5, "zmax": 5.1}      # lot BI-V1 : images, densité, rayon et hauteur du cadre
K_JEU = 0.5            # unités du modèle -> tuiles = K_JEU × échelle de jeu (le modèle vaut l'échelle 2 de vanilla)
FOULEE = 3.17          # tuiles du modèle par cycle : pied d'appui fixe au sol
MASQUE = ("coque",)    # ce que la teinte du palier recolore

PALETTES = {
    "coque": dict(sombre=(0.085, 0.009, 0.009), clair=(0.33, 0.036, 0.024), f=1.1, trainees=(0.46, 0.085, 0.040), force_trainees=0.6, fin_force=0.24,
                  usure=(0.022, 0.006, 0.006), force_usure=0.82, bord=(0.56, 0.24, 0.13), gain_bord=0.9, rude=0.36, verni=0.55, relief=0.28, creux=0.02),
    "armure": dict(sombre=(0.045, 0.020, 0.014), clair=(0.20, 0.090, 0.045), f=1.6, trainees=(0.33, 0.070, 0.030), force_trainees=0.6, fin_force=0.24,
                   usure=(0.62, 0.46, 0.28), force_usure=0.6, bord=(0.60, 0.40, 0.24), gain_bord=1.4, rude=0.42, verni=0.32, relief=0.34, creux=0.03),
    "face": dict(sombre=(0.17, 0.050, 0.040), clair=(0.52, 0.24, 0.155), f=1.6, trainees=(0.38, 0.085, 0.045), force_trainees=0.8, fin_force=0.2, bord=(0.72, 0.50, 0.34), gain_bord=1.4,
                 rude=0.30, verni=0.55, relief=0.12, creux=0.10),
    "chair": dict(sombre=(0.17, 0.018, 0.016), clair=(0.44, 0.066, 0.042), f=2.6, trainees=(0.10, 0.008, 0.010), force_trainees=0.5, fin_force=0.2, rude=0.36, verni=0.3, relief=0.3, creux=0.10),
    "patte": dict(sombre=(0.34, 0.17, 0.09), clair=(0.70, 0.46, 0.28), f=5.0, trainees=(0.36, 0.05, 0.03), force_trainees=0.85, fin_force=0.22, bout=(0.40, 0.055, 0.03), bout_de=0.55,
                  bord=(0.88, 0.70, 0.48), gain_bord=2.0, rude=0.34, verni=0.45, relief=0.15, creux=0.2),
    "griffe": dict(sombre=(0.30, 0.040, 0.024), clair=(0.62, 0.13, 0.060), f=3.0, fin_force=0.12, bout=(0.13, 0.012, 0.010), bout_de=0.65, rude=0.28, verni=0.7, relief=0.05, creux=0.25),
    "oeil": dict(sombre=(0.003, 0.003, 0.004), clair=(0.010, 0.010, 0.012), f=12.0, fin_force=0.0, rude=0.34, verni=0.12, relief=0.0, creux=0.7),
}

BORNES = (-2.40, -1.96, -1.54, -1.10, -0.54, 0.66, 1.90)
LEVRES = (0.055, 0.065, 0.080, 0.10, 0.13, 0.12)


def _lisse(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def construire(phase=0.0, attaque=None):
    f = sdf.Forme(NOM, ((-4.2, -3.9, -0.03), (5.4, 3.9, 5.2)), 0.021)
    f.marge = 0.10
    leve = None
    if attaque is not None:           # coup de massue : les deux bras montent, le corps se cabre, puis tout retombe devant lui
        phase = 0.12
        leve = float(np.interp(attaque, (0.0, 0.25, 0.5, 0.75, 1.0), (0.2, 1.0, 0.6, 0.0, 0.2)))
    t = 2.0 * np.pi * phase
    bascule = np.sin(t)
    rebond = np.cos(2.0 * t)
    if leve is None:
        corps = Repere((0.13 * rebond, -0.17 * bascule, 2.80 + 0.15 * rebond), rot_x(-0.09 * bascule) @ rot_y(0.16 + 0.05 * rebond))
    else:
        corps = Repere((0.13 * rebond + 0.22 * (1.0 - leve), -0.17 * bascule, 2.72 + 0.26 * leve), rot_x(-0.09 * bascule) @ rot_y(0.30 - 0.30 * leve))

    def base_coque(q):
        x = q[:, 0]
        fuseau = 1.0 + 0.30 * np.clip(x + 0.4, -2.0, 0.0) / 2.0
        qq = np.stack([x, q[:, 1] / fuseau, q[:, 2]], axis=1) + 0.030 * np.stack([BRUIT(q * 0.8 + 1), BRUIT(q * 0.8 + 5), BRUIT(q * 0.8 + 9)], axis=1)
        d = A.ell(qq, (0, 0, 0), (2.40, 1.46, 1.16))
        return smin(d, A.ell(qq, (0.62, 0.0, 0.26), (1.30, 1.44, 1.02)), 0.30)

    def fn_coque(q):
        d, _b = A.anneaux(q, base_coque(q), BORNES, LEVRES, largeur=0.07, courbe=0.11, graine=2.0)
        d = d - 0.022 * np.exp(-(q[:, 1] / 0.13) ** 2) - 0.011 * BRUIT.fbm(q * 4.0 + 5.0, octaves=3)   # quille, chitine cabossée : le reflet se casse
        d = smax(d, q[:, 0] - 1.80 - 0.12 * np.cos(q[:, 1] * 1.5), 0.04)                               # la coque s'arrête : la tête sort devant
        jupe = -0.60 + 0.05 * np.sin(q[:, 0] * 3.1) + 0.03 * BRUIT(q * 2.0 + 3.0)
        return smax(d, jupe - q[:, 2], 0.03)

    def g_coque(q):
        return A.anneaux(q, base_coque(q), BORNES, LEVRES, largeur=0.07, courbe=0.11, graine=2.0)[1]

    f.groupe("coque", k=0.012).append(Fn(fn_coque, corps, k=0.012, fn_g=g_coque))
    armure = f.groupe("armure", k=0.012)
    face = f.groupe("face", k=0.02)
    chair = f.groupe("chair", k=0.03)
    pattes = f.groupe("patte", k=0.012)
    griffes = f.groupe("griffe", k=0.015)
    yeux = f.groupe("oeil", k=0.004)

    # Dessous, cou, tête de la famille, baissée.
    chair.append(Ell((0.0, 0, -0.45), (2.05, 1.15, 0.64), corps, k=0.10, peau=(0.018, 2.8, 6.0)))
    chair.append(Ell((1.86, 0, -0.30), (0.92, 0.92, 0.66), corps, k=0.14, peau=(0.014, 3.0, 7.0)))
    tete = corps.compose((2.62, 0.0, -0.24), rot_y(0.30 + 0.05 * rebond))
    A.tete_biter(tete, 1.55, face, griffes, yeux, ouvre=(0.5 + 0.5 * rebond) if leve is None else 1.0 - leve, graine=9.0)

    # DEUX AVANT-BRAS À MASSUE : épaule de chair, bras de chitine, avant-bras qui s'évase, massue de chitine usée aux jointures.
    # Ils balancent à grande amplitude, à contretemps des jambes.
    def levres_bras(t_, a):
        return 0.035 * np.clip((t_ * 3.0) % 1.0, 0.0, 1.0) ** 2.0

    for s, a_ in ((1.0, t), (-1.0, t + np.pi)):
        balance = np.sin(a_)
        haut = max(0.0, np.cos(a_))
        epaule = corps.monde((1.22, s * 1.20, -0.44))
        poing = np.array([2.72 + 1.15 * balance, s * 2.50, 0.74 + 0.86 * haut])
        if leve is not None:
            poing = np.array([3.30 - 0.5 * leve, s * 1.75, 0.62 + 2.90 * leve])
        coude = A.ik2(epaule, poing, 1.62, 1.55, (-0.25, s * 0.85, 0.75))
        chair.append(Ell(epaule, (0.52, 0.48, 0.48), k=0.10, peau=(0.014, 3.5, s)))
        armure.append(Os(epaule, coude, 0.44, 0.33, k=0.04, ventre=0.04, g0=0.0, g1=0.0, graine=s, plis=levres_bras, peau=(0.012, 4.0, 5.0 * s)))
        chair.append(Ell(coude, (0.36, 0.36, 0.36), k=0.05, peau=(0.012, 3.5, 2.0 * s)))
        armure.append(Os(coude, poing, 0.34, 0.52, k=0.04, g0=0.0, g1=0.12, graine=2.0 * s, plis=levres_bras, peau=(0.008, 5.0, 4.0 * s)))
        axe = (poing - coude) / np.linalg.norm(poing - coude)
        armure.append(sdf.ell_sur(poing - axe * 0.40, poing + axe * 0.92, 0.66, 0.46, (0.0, 0.0, 1.0), k=0.05, peau=(0.012, 5.0, 3.0 * s), g=0.12))
        lat = np.cross(axe, np.array([0.0, 0.0, 1.0]))
        lat = lat / max(np.linalg.norm(lat), 1e-6)
        for j, dec in enumerate((-0.42, 0.0, 0.42)):
            armure.append(Os(poing + axe * 0.26 + lat * dec + np.array([0, 0, 0.30]), poing + axe * 0.84 + lat * dec * 1.05 + np.array([0, 0, 0.10]), 0.20, 0.16, k=0.05, g0=0.55, g1=0.85, graine=j + s))
            griffes.append(Os(poing + axe * 0.78 + lat * dec * 1.05, poing + axe * 1.24 + lat * dec * 1.1 + np.array([0, 0, -0.14]), 0.17, 0.030, k=0.04, g0=0.1, g1=1.0, graine=j + 3 * s))

    # DEUX PATTES-PILIERS : cuisse de chitine, genou de chair rouge, tibia annelé, pied large à ongles. Grande foulée.
    def lips_jambe(t_, a):
        return 0.028 * np.clip((t_ * 3.0) % 1.0, 0.0, 1.0) ** 2.0

    for s in (-1.0, 1.0):
        u = phase + (0.5 if s > 0 else 0.0)
        dx, dz = A.pas(u, 0.92, 0.66, appui=0.58)
        hanche = corps.monde((-0.82, s * 1.14, -0.66))
        cheville = np.array([-0.82 + dx, s * 1.50, 0.34 + dz])
        genou = A.ik2(hanche, cheville, 1.16, 1.10, (1.0, s * 0.20, 0.05))
        armure.append(Os(hanche, genou, 0.68, 0.46, k=0.05, ventre=0.05, g0=0.0, g1=0.0, graine=s * 3.0, peau=(0.010, 4.0, 6.0 * s)))
        chair.append(Ell(genou, (0.45, 0.43, 0.43), k=0.06, peau=(0.012, 3.5, 4.0 * s)))
        armure.append(Os(genou, cheville, 0.44, 0.36, k=0.05, ventre=0.02, g0=0.0, g1=0.0, graine=s * 5.0, plis=lips_jambe, peau=(0.010, 4.0, 8.0 * s)))
        pied_c = cheville + np.array([0.08, 0.0, -0.17])
        armure.append(Ell(pied_c, (0.66, 0.54, 0.19), k=0.07, peau=(0.006, 5.0, 2.0 * s), g=0.25))
        for j, (ax, ay) in enumerate(((0.52, 0.32), (0.64, 0.0), (0.50, -0.32), (-0.40, s * 0.08))):
            griffes.append(Os(pied_c + np.array([ax * 0.62, ay, 0.05]), pied_c + np.array([ax * 1.30, ay * 1.16, -0.085]), 0.17, 0.035, k=0.04, g0=0.0, g1=0.8, graine=j + s))

    # Deux pattes grêles repliées sous le flanc : le rappel direct du biter vanilla, qui trottent dans le vide.
    for s, a_ in ((1.0, t + 1.3), (-1.0, t + 1.3 + np.pi)):
        hanche = corps.monde((0.25, s * 1.22, -0.70))
        pied = np.array([0.55 + 0.42 * np.sin(a_), s * 2.42, 0.95 + 0.26 * max(0.0, np.cos(a_))])
        ch, gr, genou, cheville = A.patte(hanche, pied, 0.92, 0.82, (0.0, s * 0.8, 0.9), 0.20, 0.11, 0.060, griffe=0.42, rep_graine=s + 40.0, ventre=0.02, peau=(0.008, 10.0, 11.0),
                                          griffe_r=0.018, griffe_dir=(0.0, -s * 0.4, 1.0), k=0.03)
        pattes.extend(ch)
        griffes.extend(gr)
        pattes.append(sdf.ell_sur(genou - (genou - hanche) * 0.24, genou + (genou - hanche) * 0.05, 0.135, 0.12, (0.0, s * 0.5, 1.0), k=0.05, g=0.4))
    return f
