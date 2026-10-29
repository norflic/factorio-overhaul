"""Pièce du pipeline : MUR, méthode MUR-OPUS (29/10). Trois âges clés d'abord (2, 8, 15), 8 formes de raccord chacun.

Formes (comme le mur vanilla, WallPictures) : une case ne dessine que ses bras EST, OUEST et SUD ; le bras nord est
dessiné par le voisin du nord (son bras sud va jusqu'au centre de cette case, sous le nœud de cette case).
  single (aucun), vert (S), horiz (E, O), corR (E, S), corL (O, S), tee (E, O, S), endR (E), endL (O).
Croix = tee + voisin nord ; coin bas-gauche = endR + voisin nord, etc.

Contrat d'un module d'âge aNN.py (S'exécute DANS Blender) :
  EPOQUE, NOM ; def mats(S) -> dict ; def bras(g, M, L, k) ; def noeud(g, M, forme, bras)
  bras : repère local, le bras part du centre (x = 0) et va jusqu'à x = L ; y latéral, y < 0 = côté AVANT (sud pour
         les bras est et ouest) ; k = échelle latérale (une tuile de profondeur = k unités : 1,414 pour E et O, 1,0 pour
         le bras sud) ; z vers le haut. Le bras ouest est le MIROIR du bras est (même face avant au sud).
  noeud : centré sur l'origine du monde. Formes « tour » (single, corR, corL, endR, endL : extrémités et angles) : un
         pilier qui recouvre la section du bras sud du voisin du nord. horiz : pilastre ; tee et vert : rien de plus que
         les bras (le bras sud commence 0,03 tuile AU NORD du centre et recouvre le bout du bras sud du voisin).
  Pourquoi pas de tour aux T : un mur de 2 cases d'épaisseur (courant en jeu) a une rangée de T, elle deviendrait une
  rangée de tours.
"""
import importlib
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

AGES = (2, 8, 15)
TYPES = {"single": (), "vert": ("S",), "horiz": ("E", "O"), "corR": ("E", "S"), "corL": ("O", "S"),
         "tee": ("E", "O", "S"), "endR": ("E",), "endL": ("O",)}
ORDRE = ("single", "vert", "horiz", "corR", "corL", "tee", "endR", "endL")
EPS = 0.02          # les bras est et ouest dépassent de 0,02 tuile : pas de colonne demi-transparente au raccord
SQ2 = math.sqrt(2.0)


def nom(e, f):
    return "a%02d-%s" % (e, f)


def _variants():
    v = {}
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

    def y(self, u):
        return u * self.k


def margin_px(name):
    return 20


def module(e):
    return importlib.import_module("a%02d" % e)


def build(S, C, variant):
    import geo
    v = PIECE["variants"][variant]
    ep = module(v["epoch"])
    M = ep.mats(S)
    g = geo.G(S, C, seed=100 + v["epoch"])
    for b in v["bras"]:
        # A(t) : position le long du bras pour t tuiles ; le bras couvre t de 0 à Lt (+ EPS pour E et O)
        if b == "E":
            g.push(g.T(0, 0, 0))
            ep.bras(g, M, Bras(0.5, 1.0, SQ2, EPS, b))
        elif b == "O":
            g.push(g.Sc(-1, 1, 1))
            ep.bras(g, M, Bras(0.5, 1.0, SQ2, EPS, b))
        else:
            g.push(g.Rz(-math.pi / 2))
            ep.bras(g, M, Bras(1.0, SQ2, 1.0, 0.0, b, t0=-0.03))
        g.pop()
    ep.noeud(g, M, v["forme"], v["bras"])
    return {"count": g.n}
