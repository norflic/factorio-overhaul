"""Pièce du pipeline : CENTRE DE COMMANDEMENT, lot F5-A (27/10), 15 âges sur le kit commun.

Format de tools/render/README.md (PIECE + build(S, C, variant)). Variantes :
  eNN-centre          le centre de l'âge N (N = 1 à 15) : NIVEAU = ÂGE (shared/levels/config.lua : 15 niveaux, pas de
                      pièce paire) ; le niveau 1 aussi est dessiné (il n'existe pas de centre vanilla : le niveau 1 actuel
                      est un roboport surmonté d'un radar, prototypes/levels/command.lua) ;
  kS-centre           TÉMOIN DU KIT (S = 4 à 8) : la lignée seule (ep00).
Une seule pose (« F » : un conteneur ne tourne pas ; la PORTE est au sud). Emprise : epoques.COTE (4, 5, 6, 7, 8 par
ère). Préfixe des matières Blender : « cen ». Rendu : rendre.py ; contrôles : commun/ilots.py --famille centre_e.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import epoques as E  # noqa: E402

PREFIXE = "cen"
PARTIES = ("centre",)


def nom(e, partie="centre"):
    return "e%02d-%s" % (e, partie)


def _finir(name, meta):
    meta["dest"] = "levels/centre_e/" + name
    meta["anchor_tiles"] = (0.0, 0.0)
    meta["nuit"] = bool(E.FAMILLES.get(meta["epoch"], {}).get("nuit", False))
    meta["sous_vanilla"] = False
    return meta


def _variants():
    v = {}
    for e in range(1, 16):
        v[nom(e)] = {"epoch": e, "part": "centre", "level": e, "side": E.COTE[e]}
    for s in range(4, 9):
        v["k%d-centre" % s] = {"epoch": 0, "part": "centre", "level": 0, "side": s}
    for name, meta in v.items():
        _finir(name, meta)
    return v


PIECE = {
    "name": "cen",
    "variants": _variants(),
    "margin_px": 40,
    "calib": {"LIGHT_HOLDOUT": True},
}


def margin_px(name):
    return 40 + int(64 * 1.6)


def build(S, C, variant):
    import kit as K
    import corps
    K.PREFIXE = PREFIXE
    v = PIECE["variants"][variant]
    e = v["epoch"]
    ep = E.module(e)
    M = K.materials(S, e, ep)
    hab = E.habillage(ep)
    seed = 100 + (e if e else 400 + v["side"])
    g = K.Geo(S, C, M, "C%02d" % (e if e else v["side"]), 0.0, seed=seed)
    c = corps.Ctx(g, e, ep, v["side"], hab)
    corps.centre(g, c)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
