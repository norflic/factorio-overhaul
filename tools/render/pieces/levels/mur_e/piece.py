"""Pièce du pipeline : MUR, lot F6 (29/10), 14 âges (2 à 15) sur le kit commun.

Variantes eNN-<forme> (forme parmi epoques.TYPES) : poteau + bras des formes de raccord ; kN-<forme> : témoin du kit
(ep00 : la lignée seule, un mur de briques nu). Le mur ne tourne pas. Préfixe des matières Blender : « mur ».
Rendu : rendre.py ; planches : planche.py.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import epoques as E  # noqa: E402

PREFIXE = "mur"


def nom(e, forme):
    return "e%02d-%s" % (e, forme)


def _variants():
    v = {}
    for e in E.AGES:
        for t in E.ORDRE_TYPES:
            v[nom(e, t)] = {"epoch": e, "forme": t, "part": "socle", "side": 1, "level": 2 * e - 1, "nuit": False,
                            "anchor_tiles": (0.0, 0.0), "dest": "levels/mur_e/" + nom(e, t), "sous_vanilla": False}
    return v


PIECE = {"name": "mur", "variants": _variants(), "margin_px": 24, "calib": {"LIGHT_HOLDOUT": True}}


def margin_px(name):
    return 24 + 20


class Ctx:
    def __init__(self, g, e, ep):
        self.g, self.M, self.e, self.ep, self.rng = g, g.M, e, ep, g.rng


def build(S, C, variant):
    import kit as K
    K.PREFIXE = PREFIXE
    v = PIECE["variants"][variant]
    e = v["epoch"]
    ep = E.module(e)
    M = K.materials(S, e, ep)
    g = K.Geo(S, C, M, "M%02d%s" % (e, v["forme"][:3]), 0.0, seed=700 + e)
    c = Ctx(g, e, ep)
    ep.poteau(g, c)
    for b in E.TYPES[v["forme"]]:
        rz, L, n = E.BRAS[b]
        g.push((0, 0, 0), rz=rz)
        ep.bras(g, c, L, n)
        g.pop()
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos), "fumee": None}
