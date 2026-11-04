"""POINTS DE FIL du pylône haute tension (tête de chat, variante C) : Lua pur de géométrie, sans Blender ; partagé par m_py.py
(modèle) et feuilles.py (connection_points du prototype). Directions du moteur (grand poteau vanilla, entities.lua) :
0 traverse est-ouest, 1 nord-ouest/sud-est, 2 nord-sud, 3 nord-est/sud-ouest : angle -45° × d autour de +Z (repère de geo.py).
Fil rouge = bout +x local de la traverse, vert = bout -x, cuivre = phase centrale (comme le grand poteau vanilla).
"""
import math

HAUT_C = 5.6                 # sommet de la poutre (m_py.VAR["c"]["haut"])
PHASES = (-1.45, 0.0, 1.45)
CHUTE = 0.98                 # du sommet de la poutre au bas des chaînes en V, pinces comprises


def angle(d):
    return -math.pi / 4.0 * d


def bas_des_chaines(d):
    """Points (x, y, z) Blender du bas des 3 chaînes, tournés pour la direction d : (vert, cuivre, rouge)."""
    a = angle(d)
    c, s = math.cos(a), math.sin(a)
    return [(x * c, x * s, HAUT_C - CHUTE) for x in PHASES]


def connection_point(d, C):
    """connection_points[d+1] en tuiles (repère écran du moteur) ; C = fo_calib (projection, soleil)."""
    vert, cuivre, rouge = bas_des_chaines(d)
    sv = C.sun_vector()

    def ecran(p):
        u, v = C.blender_to_screen_px(*p)
        return (round(u / 64.0, 4), round(v / 64.0, 4))

    def ombre(p):
        k = p[2] / sv[2]
        return ecran((p[0] - sv[0] * k, p[1] - sv[1] * k, 0.0))

    return {"wire": {"copper": ecran(cuivre), "red": ecran(rouge), "green": ecran(vert)},
            "shadow": {"copper": ombre(cuivre), "red": ombre(rouge), "green": ombre(vert)}}
