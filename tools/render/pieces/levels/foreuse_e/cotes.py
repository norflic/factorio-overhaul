"""COTES DE LA LIGNÉE de la FOREUSE ÉLECTRIQUE (lot F4-A, 25/10), aux 4 tailles de l'emprise (3×3 à 6×6). Python pur.

Repère des cotes : le REPÈRE DE TUILES de la foreuse posée vers le NORD (sortie du minerai au nord) : x vers l'est, y vers
le NORD, en tuiles de jeu (non étirées), z en unités du monde (1 = une largeur de tuile ; 0,707 tuile à l'écran).
corps.repere() étire y de √2 et tourne le tout pour les directions E, S et O : le rendu E est EXACTEMENT le rendu N tourné
d'un quart de tour dans le plan des tuiles (comme le moteur tourne les points de jeu).

Points de jeu (signaux fixes) : règle de prototypes/levels/common.lua et shared/levels/points.lua (move_point), recopiée
ici pour la seule géométrie de rendu : depuis le 3×3 vanilla (sortie (0, −1,85) en y de jeu vers le sud ; raccords de
fluide en (−2, 0), (2, 0), (0, 2)), une coordonnée AU-DELÀ du bord garde son écart au bord, une coordonnée LE LONG du bord
est portée à la même proportion puis calée sur le centre de tuile le plus proche (côté pair : demi-entier ; à égalité, le
plus petit, donc 0 → −0,5 en y de jeu, soit +0,5 vers le nord, et 0 → −0,5 en x). Rayon d'extraction : 2,49 + (côté − 3)/2.
"""
import math

TAILLES_VALIDES = (3, 4, 5, 6)
VANILLA = dict(cote=3, sortie=(0.0, -1.85), raccords=((-2.0, 0.0), (2.0, 0.0), (0.0, 2.0)), rayon=2.49)


def _cale(v, a, b):
    """move_point, une coordonnée (y de jeu vers le sud), du côté a au côté b."""
    if abs(v) >= a / 2.0 - 1e-9:
        return math.copysign(abs(v) - a / 2.0 + b / 2.0, v)
    p = v * b / a
    if b % 2:
        cands = (math.floor(p), math.ceil(p))
    else:
        cands = (math.floor(p - 0.5) + 0.5, math.ceil(p - 0.5) + 0.5)
    return min(cands, key=lambda c: (abs(c - p), c))


def point_jeu(pt, b):
    """Point du 3×3 vanilla (x, y de jeu vers le sud) porté au côté b (même règle que points.lua)."""
    a = VANILLA["cote"]
    return (_cale(pt[0], a, b), _cale(pt[1], a, b))


def sortie(b):
    """Point de dépôt du minerai, foreuse tournée au NORD, dans le repère des cotes (x est, y NORD)."""
    x, y = point_jeu(VANILLA["sortie"], b)
    return (x, -y)


def raccords(b):
    """Raccords du fluide de minage (ouest, est, sud), foreuse au NORD, repère des cotes (x est, y NORD) : position du
    tuyau voisin (une demi-tuile hors du bord) ; le bord de la foreuse est à côté / 2."""
    noms = ("O", "E", "S")
    return {n: (point_jeu(p, b)[0], -point_jeu(p, b)[1]) for n, p in zip(noms, VANILLA["raccords"])}


def rayon_extraction(b):
    return VANILLA["rayon"] + (b - VANILLA["cote"]) / 2.0


def taille(s):
    """Cotes de la lignée au côté s (tuiles). Toutes en tuiles (z en unités du monde)."""
    if s not in TAILLES_VALIDES:
        raise ValueError("foreuse : côté %r (3 à 6)" % s)
    k = s - 3
    a = s / 2.0
    d = a - 0.10                          # demi-côté du tablier
    zt = 0.20 + 0.02 * k                  # dessus du tablier
    H = 0.62 * s                          # haut de la tour (sommet invariant par rotation, pièce paire)
    rt = 0.50 * a                         # demi-largeur du pied de la tour (ronde 1 : 0,42 → 0,50, le tablier dominait)
    rw = 0.30 + 0.08 * k                  # rayon du puits
    sx, sy = sortie(s)
    wc = 0.42 + 0.06 * k                  # largeur de la goulotte
    T = dict(
        s=s, a=a, d=d, zt=zt, H=H, rt=rt, rw=rw,
        montant=dict(w=0.24 + 0.03 * k, h=zt + 0.34 + 0.05 * k, retrait=0.16 + 0.02 * k),
        goulotte=dict(x=sx, y0=0.55 * rt, z0=zt + 0.62 + 0.06 * k, y1=a + 0.20, z1=zt + 0.14, w=wc,
                      bord=0.07, fleche=0.30 + 0.05 * k),
        moteur=dict(x=0.0, y=-(rt + 0.30 + 0.06 * k), w=0.72 + 0.12 * k, p=0.42 + 0.06 * k, h=0.40 + 0.06 * k),
        raccord=dict(r=0.085 + 0.01 * k, long=0.42 + 0.05 * k),
        trepan=dict(r=0.055 + 0.012 * k, tete=0.16 + 0.03 * k),
        sortie=(sx, sy), raccords=raccords(s), rayon=rayon_extraction(s),
    )
    # enveloppe à l'écran (règle des trous enfermés, ilots.py) : ce qui monte au-dessus du bord arrière du tablier à
    # l'écran doit être PLEIN (aucun treillis ouvert sur le sol). Le treillis reste sous cette hauteur.
    T["z_treillis_max"] = (d + zt * 0.7071 - 0.20 - 0.35 * rt) / 0.7071
    return T


# historique : premier jet du lot F4-A (25/10). Hauteur de tour 0,62 × côté : le sommet tombe à l'écran SOUS le bord
# arrière du tablier (3×3 : 1,31 t contre 1,64 t), ce qui permet un treillis sans trou enfermé.
