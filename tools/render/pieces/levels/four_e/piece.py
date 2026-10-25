"""Pièce du pipeline : FOUR, lot F2-A (25/10), 15 âges sur le kit commun.

Format de tools/render/README.md (PIECE + build(S, C, variant)). Variantes :
  e01-piece      niveau 2 : pièce posée SOUS le four en acier vanilla (niveau 1 inchangé) ; elle doit DÉPASSER sa
                 silhouette (F42) ;
  eNN-socle      four du niveau impair 2N−1 (N = 2 à 15) : sole, chambre de l'âge, foyer et gueule, fumée ;
  eNN-piece      pièce du niveau pair 2N (couche ajoutée au socle, en paire sur les places avant) ;
  kS-socle, kS-piece   TÉMOIN DU KIT (S = 2 à 6) : la lignée seule (ep00).
Le four ne tourne pas : aucune direction. Emprise : epoques.COTE. Préfixe des matières Blender : « four ». Rendu :
rendre.py ; contrôles : commun/ilots.py, gris.py, mesures.py, apercu.py avec --famille four_e.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import epoques as E  # noqa: E402

PREFIXE = "four"
PARTIES = ("socle", "piece")


def nom(e, partie):
    return "e%02d-%s" % (e, partie)


def _finir(name, meta):
    meta["dest"] = "levels/four_e/" + name
    meta["anchor_tiles"] = (0.0, 0.0)
    meta["nuit"] = bool(E.FAMILLES.get(meta["epoch"], {}).get("nuit", False))
    meta["sous_vanilla"] = name == "e01-piece"
    return meta


def _variants():
    v = {"e01-piece": {"epoch": 1, "part": "piece", "level": 2, "side": 2}}
    for e in range(2, 16):
        for p in PARTIES:
            v[nom(e, p)] = {"epoch": e, "part": p, "level": 2 * e - 1 + (p == "piece"), "side": E.COTE[e]}
    for s in range(2, 7):
        for p in PARTIES:
            v["k%d-%s" % (s, p)] = {"epoch": 0, "part": p, "level": 0, "side": s}
    for name, meta in v.items():
        _finir(name, meta)
    return v


PIECE = {
    "name": "four",
    "variants": _variants(),
    "margin_px": 40,
    "calib": {"LIGHT_HOLDOUT": True},
}


def margin_px(name):
    return 40 + int(64 * 1.3)


def build(S, C, variant):
    import kit as K
    import corps
    K.PREFIXE = PREFIXE
    v = PIECE["variants"][variant]
    e = v["epoch"]
    ep = E.module(e)
    M = K.materials(S, e, ep)
    hab = E.habillage(ep)
    part = v["part"]
    seed = {"socle": 100, "piece": 300}[part] + (e if e else 400 + v["side"])
    g = K.Geo(S, C, M, "F%s%02d" % (part[0], e if e else v["side"]), 0.0, seed=seed)
    c = corps.Ctx(g, e, ep, v["side"], hab)
    {"socle": corps.socle, "piece": corps.piece}[part](g, c)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos), "fumee": c.fumee}
