"""Pièce du pipeline : MUR, méthode MUR-OPUS (29/10), série des 15 âges (1/11).

Formes (comme le mur vanilla, WallPictures) : une case ne dessine que ses bras EST, OUEST et SUD ; le bras nord est
dessiné par le voisin du nord (son bras sud va jusqu'au centre de cette case, sous le nœud de cette case).
  single (aucun), vert (S), horiz (E, O), corR (E, S), corL (O, S), tee (E, O, S), endR (E), endL (O).
Croix = tee + voisin nord ; coin bas-gauche = endR + voisin nord, etc.

Contrat d'un âge : classe de chassis.py (ere1.py à ere5.py) ; mats(S), bras(g, M, B), noeud(g, M, forme, bras).
  bras : repère local, le bras part du centre (x = 0) ; y latéral, y < 0 = côté AVANT ; z vers le haut. Le bras ouest est
         le MIROIR du bras est.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

AGES = tuple(range(2, 16))
TYPES = {"single": (), "vert": ("S",), "horiz": ("E", "O"), "horiz2": ("E", "O"), "horiz3": ("E", "O"),
         "corR": ("E", "S"), "corL": ("O", "S"), "tee": ("E", "O", "S"), "endR": ("E",), "endL": ("O",),
         # série 1/11 : bouche-trou, raccords vers une porte ou l'eau (4 directions), pièce du niveau pair
         "filling": (), "jN": (), "jE": (), "jS": (), "jO": (), "piece": ()}
# horiz, horiz2, horiz3 : trois variantes du segment droit est-ouest (DESIGN_EPOQUES §4.7 : 3 pour les droits)
ORDRE = ("single", "vert", "horiz", "horiz2", "horiz3", "corR", "corL", "tee", "endR", "endL", "filling", "jN", "jE",
         "jS", "jO", "piece")
# v3 : graine des motifs (taches, coulures) par forme : trois segments droits qui ne se répètent pas à l'identique
GRAINES = {"single": 1.7, "vert": 2.9, "horiz": 0.0, "horiz2": 5.3, "horiz3": 8.1, "corR": 3.7, "corL": 4.4, "tee": 6.2,
           "endR": 7.4, "endL": 9.6, "filling": 12.1, "jN": 13.3, "jE": 14.7, "jS": 15.9, "jO": 16.3, "piece": 17.9}
K_SUD = 0.74       # v2 : échelle latérale du bras sud ; le mur vanilla nord-sud fait 47-48 px HR de large au pied
                   # (0,75 tuile), le v1 en faisait 62-68 (+35 %)
OMBRE_SOLEIL = (342.0, 37.0)   # v5b (C1) : (azimut, élévation) du soleil de la seule passe d'ombre ; None = F47
EPS = 0.02          # les bras est et ouest dépassent de 0,02 tuile : pas de colonne demi-transparente au raccord
SQ2 = math.sqrt(2.0)


def nom(e, f):
    return "a%02d-%s" % (e, f)


def _variants():
    v = {nom(1, "piece"): {"epoch": 1, "forme": "piece", "bras": ()}}     # âge 1 : le mur vanilla, sa pièce paire seule
    for e in AGES:
        for f in ORDRE:
            v[nom(e, f)] = {"epoch": e, "forme": f, "bras": TYPES[f]}
    return v


PIECE = {"name": "mur", "variants": _variants()}


class Bras:
    """Repère d'un bras : Lt = longueur en tuiles (0,5 pour E et O, 1 pour S) ; ka = unités par tuile LE LONG du bras
    (1 pour E et O, 1,414 pour S) ; k = unités par tuile EN TRAVERS (1,414 pour E et O, 1 pour S) ; eps = dépassement.
    x(t) = t × ka ; y(u) = u × k ; L = longueur en unités (dépassement compris)."""

    def __init__(self, Lt, ka, k, eps, cote, t0=0.0):
        self.Lt, self.ka, self.k, self.eps, self.cote = Lt, ka, k, eps, cote
        self.L = Lt * ka + eps
        self.x0 = t0 * ka           # début du bras (unités) ; < 0 pour le bras sud
        self.t0 = t0
        self.t1 = Lt + eps / ka     # fin (tuiles)

    def span(self, a, b):
        """Intervalle [a, b] (tuiles) borné au bras ; None s'il est vide."""
        a, b = max(a, self.t0), min(b, self.t1)
        return (a, b) if b - a > 1e-4 else None

    def x(self, t):
        return t * self.ka

    def ts(self, *ts):
        """Positions (unités) des instants t (tuiles) qui tombent dans ce bras."""
        return [t * self.ka for t in ts if self.t0 <= t <= self.Lt]

    def y(self, u):
        return u * self.k


def margin_px(name):
    return 20


def module(e):
    import chassis
    return chassis.age(e)


def build(S, C, variant):
    import geo
    v = PIECE["variants"][variant]
    ep = module(v["epoch"])
    geo.GRAINE = GRAINES[v["forme"]]
    ep.FORME = v["forme"]       # certaines matières et détails tirent leur motif d'après la forme
    M = ep.mats(S)
    g = geo.G(S, C, seed=100 + v["epoch"] + int(GRAINES[v["forme"]] * 10))
    for b in v["bras"]:
        # le bras couvre t de 0 à Lt (+ EPS pour E et O)
        if b == "E":
            g.push(g.T(0, 0, 0))
            ep.bras(g, M, Bras(0.5, 1.0, SQ2, EPS, b))
        elif b == "O":
            g.push(g.Sc(-1, 1, 1))
            ep.bras(g, M, Bras(0.5, 1.0, SQ2, EPS, b))
        else:
            g.push(g.Rz(-math.pi / 2))
            ep.bras(g, M, Bras(1.0, SQ2, K_SUD, 0.0, b, t0=-0.03))
        g.pop()
    ep.noeud(g, M, v["forme"], v["bras"])
    return {"count": g.n}
