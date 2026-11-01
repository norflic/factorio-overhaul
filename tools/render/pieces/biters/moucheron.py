"""MOUCHERON (famille essaim, PLAN §5 ter) : nain, 4 pattes, moignons d'ailes qui vibrent. Grosse tête bossue, abdomen pointu relevé."""
import numpy as np

import anatomie as A
import sdf
from sdf import BRUIT, Ell, Fn, Os, Repere, rot_x, rot_y, rot_z, smax, smin

NOM = "moucheron"
DENSITE = 340.0
CREUX = 0.016
AO = 0.075
ETIQUETTE = "Moucheron"
ECHELLE_Z1 = 1.3      # k = 0,6 du small-biter (PLAN §5 ter), soit 0,96 tuile de pattes à pattes

PALETTES = {
    "carapace": dict(sombre=(0.010, 0.009, 0.009), clair=(0.040, 0.032, 0.024), f=14.0, usure=(0.74, 0.50, 0.060), force_usure=1.0,
                     bord=(0.34, 0.25, 0.08), gain_bord=4.0, rude=0.28, verni=0.8, relief=0.2, creux=0.2),
    "chair": dict(sombre=(0.22, 0.10, 0.018), clair=(0.70, 0.40, 0.055), f=30.0, taches=(0.07, 0.03, 0.01), force_taches=0.65,
                  bout=(0.022, 0.016, 0.012), bout_de=0.35, rude=0.42, verni=0.2, relief=0.6, creux=0.28),
    "griffe": dict(sombre=(0.018, 0.012, 0.010), clair=(0.05, 0.035, 0.022), f=20.0, bout=(0.30, 0.22, 0.10), bout_de=0.6, rude=0.28, verni=0.6, relief=0.1, creux=0.4),
    "membrane": dict(sombre=(0.58, 0.52, 0.38), clair=(0.96, 0.92, 0.76), f=24.0, taches=(0.26, 0.17, 0.08), force_taches=0.45,
                     rude=0.30, verni=0.5, relief=0.2, creux=0.5),
    "oeil": dict(sombre=(0.13, 0.006, 0.005), clair=(0.42, 0.024, 0.014), f=90.0, rude=0.08, verni=1.0, relief=0.0, creux=0.5),
}


def _aile(rep, L, W, graine):
    """Moignon d'aile déchiré : membrane mince, mangée de trous, repère : +x vers le bout, plan (x, y)."""

    def fn(q):
        x = q[:, 0] - L * 0.5
        n = BRUIT(q * 26.0 + graine)
        rx = L * 0.5 * (1.0 + 0.18 * n)
        ry = W * (1.0 + 0.34 * BRUIT(q * 19.0 + graine + 4.0)) * np.clip(0.42 + 1.05 * (q[:, 0] / L), 0.15, 1.0)
        r = np.sqrt((x / rx) ** 2 + (q[:, 1] / ry) ** 2)
        d = np.minimum(r - 1.0, 0.6) * min(L * 0.5, W)
        epais = np.abs(q[:, 2] - 0.012 * np.sin(q[:, 0] * 40.0 + q[:, 1] * 25.0)) - 0.0075
        d = smax(d, epais, 0.003)
        trous = BRUIT.fbm(q * 38.0 + graine + 9.0, octaves=2) - 0.42
        return smax(d, trous * 0.06 * (q[:, 0] > L * 0.55), 0.003)

    return Fn(fn, rep, k=0.004)


def construire(phase=0.0):
    f = sdf.Forme(NOM, ((-0.64, -0.60, -0.01), (0.66, 0.60, 0.78)), 0.004)
    f.marge = 0.03
    t = 2.0 * np.pi * phase
    # Le corps BONDIT : tangage et rebond forts, c'est ce qui se lit à zoom 1.
    corps = Repere((0.012 * np.sin(2 * t), 0.0, 0.215 + 0.034 * np.cos(2 * t)), rot_y(-0.20 + 0.07 * np.sin(2 * t)) @ rot_x(0.05 * np.sin(t)))
    tete = corps.compose((0.155, 0.0, 0.015), rot_y(0.30 + 0.05 * np.cos(2 * t)))

    carapace = f.groupe("carapace", k=0.012)
    chair = f.groupe("chair", k=0.012)
    griffes = f.groupe("griffe", k=0.004)
    membrane = f.groupe("membrane", k=0.003)
    yeux = f.groupe("oeil", k=0.002)

    # Tête en enclume : large, plate, front bas ; jamais une boule. Deux gros yeux de travers, à fleur des côtés.
    def fn_tete(q):
        qq = q + 0.007 * np.stack([BRUIT(q * 9 + 2), BRUIT(q * 9 + 6), BRUIT(q * 9 + 8)], axis=1)
        d = A.ell(qq, (0.0, 0.0, 0.0), (0.108, 0.142, 0.082))
        d = smin(d, A.ell(qq, (0.070, 0.0, -0.034), (0.074, 0.098, 0.044)), 0.030)     # museau
        d = smin(d, A.ell(qq, (0.030, 0.052, 0.060), (0.060, 0.038, 0.024)), 0.020)    # arcade gauche
        d = smin(d, A.ell(qq, (0.024, -0.058, 0.056), (0.066, 0.042, 0.026)), 0.020)   # arcade droite
        return d - 0.0006 * BRUIT.fbm(q * 70.0, octaves=2)

    def chevron(q):
        return (np.exp(-((q[:, 0] - 0.045 + 0.55 * np.abs(q[:, 1])) / 0.014) ** 2) * (q[:, 2] > 0)).astype(np.float32)

    carapace.append(Fn(fn_tete, tete, k=0.034, fn_g=chevron))
    for s, dy, r in ((1.0, 0.108, 0.050), (-1.0, 0.102, 0.056)):
        c = tete.monde((0.038, s * dy, 0.014))
        yeux.append(Ell(c, (r, r * 0.78, r * 0.88), k=0.002, plis=None))
    for s in (-1.0, 1.0):
        m0 = tete.monde((0.105, 0.045 * s, -0.045))
        m1 = tete.monde((0.190, 0.058 * s, -0.052))
        m2 = tete.monde((0.235, 0.010 * s, -0.068))
        griffes.append(Os(m0, m1, 0.0270, 0.0170, k=0.008, g0=0.2, g1=0.7, graine=3 * s))
        griffes.append(Os(m1, m2, 0.0170, 0.0040, k=0.005, g0=0.7, g1=1.0, graine=5 * s))
        # antennes courtes, coudées
        a0 = tete.monde((0.085, 0.065 * s, 0.070))
        a1 = tete.monde((0.150, 0.150 * s, 0.135))
        a2 = tete.monde((0.235, 0.185 * s, 0.100))
        griffes.append(Os(a0, a1, 0.0075, 0.0055, k=0.003, g0=0.2, g1=0.5, graine=8 * s))
        griffes.append(Os(a1, a2, 0.0055, 0.0030, k=0.003, g0=0.5, g1=0.9, graine=10 * s))

    # Thorax bossu : un vrai dos de bossu, qui porte les moignons.
    def fn_thorax(q):
        d = np.linalg.norm((q - np.array([0.0, 0.0, 0.015], np.float32)) / np.array([0.112, 0.102, 0.104], np.float32), axis=1)
        d = (d - 1.0) * 0.102
        bosse = np.linalg.norm((q - np.array([-0.025, 0.0, 0.085], np.float32)) / np.array([0.072, 0.072, 0.056], np.float32), axis=1)
        bosse = (bosse - 1.0) * 0.056
        d = smin(d, bosse, 0.03)
        rainure = 0.005 * np.exp(-(q[:, 1] / 0.010) ** 2)
        return d + rainure - 0.0006 * BRUIT.fbm(q * 70.0, octaves=2)

    def rayures(q):
        return (np.exp(-((np.abs(q[:, 1]) - 0.050 - 0.10 * q[:, 0]) / 0.012) ** 2) * (q[:, 2] > 0.02)).astype(np.float32)

    carapace.append(Fn(fn_thorax, corps, k=0.030, fn_g=rayures))
    chair.append(Ell((0.085, 0.0, -0.005), (0.060, 0.065, 0.056), corps, k=0.016, peau=(0.002, 60.0, 3.0)))

    # Abdomen : poire annelée relevée vers l'arrière, anneaux jaunes (usure = bandes claires), pointe d'aiguillon.
    abdo = corps.compose((-0.100, 0.0, 0.020), rot_y(-0.42 + 0.06 * np.cos(2 * t + 0.8)) @ rot_x(0.07 * np.sin(t)))

    def fn_abdo(q):
        x = -q[:, 0]
        l = 0.215
        tt = np.clip(x / l, 0.0, 1.0)
        rayon = 0.114 * np.sin(np.pi * (0.10 + 0.86 * tt) ** 0.82) ** 0.72 + 0.003
        rr = np.sqrt(q[:, 1] ** 2 + (q[:, 2] * 1.08) ** 2)
        d = rr - rayon
        d = np.where(x < 0, np.hypot(np.maximum(rr - rayon, 0), x) + np.minimum(rr - rayon, 0), d)
        d = np.where(x > l, np.hypot(np.maximum(rr - rayon, 0), x - l) + np.minimum(rr - rayon, 0), d)
        anneau = np.abs(np.sin(tt * np.pi * 5.0))
        return d * 0.8 + 0.0065 * (1.0 - anneau ** 0.5) - 0.0005 * BRUIT.fbm(q * 80.0, octaves=2)

    def bandes(q):
        tt = np.clip(-q[:, 0] / 0.215, 0.0, 1.0)
        a = 0.5 + 0.5 * np.cos(tt * np.pi * 10.0)
        return np.clip((a - 0.45) * 3.0, 0.0, 1.0).astype(np.float32) * (tt > 0.04)

    carapace.append(Fn(fn_abdo, abdo, k=0.010, fn_g=bandes))
    griffes.append(Os(abdo.monde((-0.205, 0, 0.002)), abdo.monde((-0.272, 0, 0.022)), 0.0140, 0.0030, k=0.005, g0=0.3, g1=1.0, graine=12.0))

    # Quatre pattes longues et grêles, trot (diagonales), posture sur la pointe.
    pattes = (((0.075, 0.098), (0.30, 0.35), 0.0), ((-0.065, 0.098), (-0.26, 0.37), 0.5))
    for (hx, hy), (px, py), dep in pattes:
        for s in (-1.0, 1.0):
            u = phase + dep + (0.5 if s > 0 else 0.0)
            dx, dz = A.pas(u, 0.115, 0.10, appui=0.42)
            hanche = corps.monde((hx, hy * s, -0.035))
            pied = np.array([px + dx, py * s, dz + 0.004])
            ch, gr, genou, cheville = A.patte(hanche, pied, 0.205, 0.255, (0.0, s * 0.85, 0.65), 0.0300, 0.0175, 0.0095, griffe=0.040,
                                              rep_graine=hx * 40 + s * 7, peau=(0.0007, 90.0, 5.0), ventre=0.0055, griffe_r=0.0028, griffe_dir=(0.06, s * -0.15, 1.0))
            chair.extend(ch)
            griffes.extend(gr)
            griffes.append(sdf.ell_sur(hanche + (genou - hanche) * 0.5, genou + (genou - hanche) * 0.04, 0.0235, 0.015, (0.0, s * 0.5, 1.0), k=0.006, g=0.1))

    # Deux moignons par côté ; battement rapide (dérive 3 fois par foulée) : c'est leur signature.
    for s in (-1.0, 1.0):
        for ia, (rx0, L, W, azim, leve, dep) in enumerate(((0.010, 0.225, 0.074, -0.70, 0.46, 0.0), (-0.040, 0.150, 0.052, -1.42, 0.26, 0.30))):
            bat = np.sin(2.0 * np.pi * (phase * 3.0 + dep + (0.08 if s > 0 else 0.0)))
            base = corps.monde((rx0, 0.058 * s, 0.100))
            R = corps.R @ rot_z(s * (np.pi * 0.5 + azim * -1.0)) @ rot_x(s * (leve + 0.48 * bat))
            rep = Repere(base, R)
            membrane.append(_aile(rep, L, W, 11.0 + ia * 3.0 + s * 2.0))
            griffes.append(Os(rep.monde((0.0, 0, 0)), rep.monde((L * 0.36, 0.010, 0.0)), 0.0115, 0.0035, k=0.004, g0=0.1, g1=0.4, graine=20 + ia))
            griffes.append(Os(rep.monde((0.0, 0, 0)), rep.monde((L * 0.62, -W * 0.34, 0.0)), 0.0065, 0.0022, k=0.003, g0=0.1, g1=0.4, graine=24 + ia))
    return f
