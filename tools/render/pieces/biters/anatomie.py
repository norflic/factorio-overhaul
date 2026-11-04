"""Anatomie commune des biters (lot RB-V0) : pattes articulées, cycle de course, plaques de chitine, peinture de la peau.
Numpy pur. Aucune trigonométrie de simulation ici : ce sont des outils de rendu, hors du jeu."""
import numpy as np

import sdf
from sdf import BRUIT, Ell, Fn, Os, smax, smin, _v


def ell(q, c, r):
    """Distance approchée à un ellipsoïde (points q, centre c, rayons r)."""
    r = np.asarray(r, np.float32)
    p = (q - np.asarray(c, np.float32)) / r
    k0 = np.linalg.norm(p, axis=1)
    k1 = np.linalg.norm(p / r, axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def ik2(a, c, l1, l2, pole):
    """Genou d'une patte à 2 segments de a à c, plié du côté de pole."""
    a, c, pole = np.asarray(a, float), np.asarray(c, float), np.asarray(pole, float)
    v = c - a
    L = max(np.linalg.norm(v), 1e-6)
    u = v / L
    L = min(L, (l1 + l2) * 0.998)
    x = (l1 * l1 - l2 * l2 + L * L) / (2.0 * L)
    h = np.sqrt(max(l1 * l1 - x * x, 0.0))
    p = pole - pole.dot(u) * u
    p = p / max(np.linalg.norm(p), 1e-6)
    return a + u * x + p * h


def pas(u, foulee, levee, appui=0.55):
    """Cycle d'un pied, u dans [0, 1[ : appui (le pied recule au sol), puis vol. Renvoie (décalage avant, hauteur)."""
    u = u % 1.0
    if u < appui:
        return foulee * (1.0 - 2.0 * u / appui), 0.0
    v = (u - appui) / (1.0 - appui)
    s = v * v * (3.0 - 2.0 * v)
    return foulee * (2.0 * s - 1.0), levee * np.sin(np.pi * v) ** 0.8


def plaques(q, base, rx, n_rangs, n_cols, a_rang, a_dome, centre_z=0.0, gouttiere=0.012, deforme=(0.3, 0.3), graine=3.1,
            alea=0.015, stries=0.0, puissance=3.0, pente=0.14):
    """Peau en plaques imbriquées sur un champ de base : chaque rang recouvre le suivant vers l'arrière, comme un toit vivant.
    q : points du repère du corps (+x avant) ; base : champ sans plaques. Renvoie (distance, usure 0 à 1 du bord libre)."""
    x, y, z = q[:, 0], q[:, 1], q[:, 2]
    n = BRUIT(q * 1.7 + graine)
    n2 = BRUIT(q * 3.3 + graine + 9.0)
    u = (x + rx) / (2.0 * rx) * n_rangs + deforme[0] * n
    rang = np.floor(u)
    fu = u - rang
    w = 1.0 - fu                                    # 0 au bord avant de la plaque, 1 à son bord libre arrière
    saw = np.minimum(w / (1.0 - pente), fu / pente)
    saw = np.clip(saw, 0.0, 1.0)
    theta = np.arctan2(y, z - centre_z + 0.35) / np.pi
    decal = (rang % 2) * 0.5 + (rang * 0.37) % 0.3
    v = theta * n_cols + decal + deforme[1] * n2
    col = np.floor(v)
    fv = v - col
    bombe = 1.0 - np.abs(2.0 * fv - 1.0) ** puissance     # 0 dans la gouttière, 1 au milieu de la plaque
    ident = (rang * 7.0 + col * 13.0) % 17.0
    jitter = (np.sin(ident * 12.9898) * 43758.5453) % 1.0
    surface = a_rang * saw ** 1.2 * (0.55 + 0.45 * bombe) + a_dome * bombe + alea * (jitter - 0.5) - gouttiere * (1.0 - np.minimum(bombe * 3.0, 1.0))
    if stries:
        surface = surface + stries * np.sin(fu * 2.0 * np.pi * 7.0) * bombe     # lignes de croissance, parallèles au bord libre
    usure = np.clip(saw ** 3.0, 0.0, 1.0) * np.minimum(bombe * 1.4, 1.0) * (0.6 + 0.4 * jitter)
    return base - surface, usure.astype(np.float32)


def anneaux(q, base, bornes, levres, largeur=0.05, courbe=0.0, graine=2.0):
    """Coque de la famille vanilla : grandes plaques transversales lisses et dures, chacune recouvre la suivante vers l'arrière.
    bornes : abscisses croissantes des bords ; levres : hauteur du bord libre de chaque plaque. Renvoie (distance, bande du bord)."""
    b = np.asarray(bornes, np.float32)
    h = np.asarray(levres, np.float32)
    x = q[:, 0] + courbe * q[:, 1] * q[:, 1] + 0.018 * BRUIT(q * 1.3 + graine)
    i = np.clip(np.searchsorted(b, x) - 1, 0, len(h) - 1)
    a0, a1 = b[i], b[i + 1]
    fu = (x - a0) / (a1 - a0)
    dedans = (fu >= 0.0) & (fu <= 1.0)
    w = np.clip(1.0 - fu, 0.0, 1.0)
    pied = np.clip((x - a0) / largeur, 0.0, 1.0)
    surface = h[i] * w ** 1.7 * pied * dedans
    bande = (_lisse(0.82, 0.97, w) * pied * dedans).astype(np.float32)
    return base - surface, bande


def tete_biter(rep, e, face, griffes, yeux, ouvre=0.0, graine=0.0):
    """Tête de la famille vanilla : crâne, museau effilé à quille, grand œil noir de chaque côté, mandibules rouges et palpes.
    rep : +x vers l'avant de la tête ; e : échelle. Formes propres, mêmes signes distinctifs."""
    peau = (0.007 * e, 7.0 / e, graine + 2.0)
    face.append(Ell((0.0, 0.0, 0.0), (0.50 * e, 0.41 * e, 0.36 * e), rep, k=0.10 * e, peau=peau))
    face.append(Os(rep.monde((0.14 * e, 0, -0.04 * e)), rep.monde((0.74 * e, 0, -0.20 * e)), 0.33 * e, 0.10 * e, k=0.12 * e, g0=0.0, g1=0.6, graine=graine, peau=peau))
    face.append(Os(rep.monde((-0.02 * e, 0, 0.32 * e)), rep.monde((0.68 * e, 0, -0.08 * e)), 0.055 * e, 0.030 * e, k=0.06 * e, g0=0.0, g1=0.2, graine=graine + 1.0))
    for s, gros in ((1.0, 1.0), (-1.0, 0.94)):
        face.append(Ell((0.14 * e, s * 0.29 * e, 0.06 * e), (0.25 * e, 0.11 * e, 0.20 * e), rep, k=0.05 * e))     # orbite
        yeux.append(Ell((0.15 * e, s * 0.385 * e, 0.04 * e), (0.25 * e * gros, 0.115 * e, 0.195 * e * gros), rep, k=0.006 * e))
        m0 = rep.monde((0.62 * e, s * 0.13 * e, -0.20 * e))
        m1 = rep.monde(((0.92 + 0.03 * ouvre) * e, s * (0.20 + 0.05 * ouvre) * e, -0.30 * e))
        m2 = rep.monde((1.05 * e, s * (0.05 + 0.08 * ouvre) * e, -0.40 * e))
        griffes.append(Os(m0, m1, 0.070 * e, 0.052 * e, k=0.025 * e, g0=0.15, g1=0.6, graine=graine + 2.0 * s))
        griffes.append(Os(m1, m2, 0.052 * e, 0.012 * e, k=0.015 * e, g0=0.6, g1=1.0, graine=graine + 3.0 * s))
        griffes.append(Os(rep.monde((0.66 * e, s * 0.06 * e, -0.26 * e)), rep.monde((0.80 * e, s * 0.10 * e, -0.47 * e)), 0.032 * e, 0.012 * e, k=0.012 * e, g0=0.3, g1=1.0, graine=graine + 4.0 * s))


def patte(hanche, pied, l1, l2, pole, r_cuisse, r_genou, r_cheville, griffe, rep_graine=0.0, peau=None, ventre=0.0, plis=None,
          griffe_r=None, griffe_dir=None, k=0.025):
    """Une patte : cuisse, tibia, griffe posée au sol. Renvoie (volumes de chair, volumes de griffe, genou, cheville)."""
    hanche, pied = np.asarray(hanche, float), np.asarray(pied, float)
    d = griffe_dir if griffe_dir is not None else np.array([0.0, 0.0, 1.0])
    d = np.asarray(d, float) / max(np.linalg.norm(d), 1e-6)
    cheville = pied + d * griffe
    genou = ik2(hanche, cheville, l1, l2, pole)
    chair = [Os(hanche, genou, r_cuisse, r_genou, k=k, ventre=ventre, peau=peau, g0=0.0, g1=0.45, graine=rep_graine + 1.0, plis=plis),
             Os(genou, cheville, r_genou, r_cheville, k=k, ventre=ventre * 0.6, peau=peau, g0=0.45, g1=0.85, graine=rep_graine + 2.3, plis=plis)]
    griffes = [Os(cheville, pied + np.array([0, 0, griffe_r if griffe_r else r_cheville * 0.28]), r_cheville, griffe_r if griffe_r else r_cheville * 0.28,
                  k=k * 0.5, g0=0.75, g1=1.0, graine=rep_graine + 3.7)]
    return chair, griffes, genou, cheville


def _melange(a, b, t):
    t = np.clip(t, 0.0, 1.0)[..., None]
    return a * (1.0 - t) + b * t


def _lisse(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def peindre(forme, P, N, palettes, echelle_creux):
    """Peau par sommet, en couleur linéaire. palettes[groupe] : dict(sombre, clair, f, taches, bout, bord, gain_bord, rude, verni,
    relief, creux, veines). Renvoie (couleur (N,3), matiere (N,3) : rugosité, vernis, relief ; q)."""
    poids, q, g = forme.attributs(P, forme.selection(P, forme.voxel * 6.0))
    ouv, rel = sdf.creux_et_relief(forme, P, N, echelle_creux)
    n = len(P)
    coul = np.zeros((n, 3), np.float32)
    mat = np.zeros((n, 3), np.float32)
    for ig, (nom, _k, _v_) in enumerate(forme.groupes):
        pal = palettes[nom]
        f = pal.get("f", 6.0)
        grand = 0.5 + 0.5 * BRUIT.fbm(q * f + 4.2 + ig, octaves=4) * 1.6
        fin = 0.5 + 0.5 * BRUIT.fbm(q * f * 5.0 + 8.8 + ig, octaves=3) * 1.5
        c = _melange(np.asarray(pal["sombre"], np.float32), np.asarray(pal["clair"], np.float32), _lisse(0.25, 0.8, grand))
        ff = pal.get("fin_force", 0.44)
        c = c * (1.0 - ff / 2.0 + ff * np.clip(fin, 0, 1))[:, None]
        if "trainees" in pal:
            # longues traînées de couleur dans le sens du membre ou du corps, comme la peau vanilla
            qa = q * np.array([f * 0.28, f * 2.6, f * 2.6], np.float32)
            tr = _lisse(0.52, 0.74, 0.5 + 0.5 * BRUIT.fbm(qa + 41.0 + ig, octaves=3) * 1.8)
            c = _melange(c, np.asarray(pal["trainees"], np.float32), tr * pal.get("force_trainees", 0.7))
        if "taches" in pal:
            ta = _lisse(0.56, 0.66, 0.5 + 0.5 * BRUIT.fbm(q * f * 2.4 + 21.0 + ig, octaves=3) * 1.7)
            c = _melange(c, np.asarray(pal["taches"], np.float32), ta * pal.get("force_taches", 0.8))
        if "veines" in pal:
            ve = 1.0 - np.abs(BRUIT.fbm(q * f * 1.6 + 31.0 + ig, octaves=2)) * 9.0
            c = _melange(c, np.asarray(pal["veines"], np.float32), _lisse(0.0, 0.9, ve) * 0.75)
        if "bout" in pal:
            c = _melange(c, np.asarray(pal["bout"], np.float32), _lisse(pal.get("bout_de", 0.55), 1.0, g))
        if "usure" in pal:
            c = _melange(c, np.asarray(pal["usure"], np.float32), _lisse(0.25, 0.95, g) * pal.get("force_usure", 0.8))
        if "bord" in pal:
            c = _melange(c, np.asarray(pal["bord"], np.float32), np.clip(rel * pal.get("gain_bord", 4.0), 0.0, 1.0))
        cmin = pal.get("creux", 0.3)
        c = c * (cmin + (1.0 - cmin) * np.clip(ouv, 0.0, 1.0) ** 1.3)[:, None]
        m = np.stack([np.full(n, pal.get("rude", 0.5), np.float32) + 0.12 * (fin - 0.5),
                      np.full(n, pal.get("verni", 0.0), np.float32) * np.clip(0.4 + ouv * 0.6, 0, 1),
                      np.full(n, pal.get("relief", 0.5), np.float32)], axis=1)
        coul += c * poids[:, ig:ig + 1]
        mat += m * poids[:, ig:ig + 1]
    return coul, mat, q


__all__ = ["ell", "ik2", "pas", "plaques", "anneaux", "tete_biter", "patte", "peindre", "Fn", "Os", "smin", "smax", "_v"]
