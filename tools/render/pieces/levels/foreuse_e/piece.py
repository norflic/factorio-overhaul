"""Pièce du pipeline : FOREUSE ÉLECTRIQUE, lot F4-A (25/10), 15 âges sur le kit commun.

Format de tools/render/README.md (PIECE + build(S, C, variant)). Variantes :
  e01-piece           niveau 2 : pièce posée SUR la foreuse vanilla (niveau 1 inchangé), une pour les 4 directions ;
  eNN-N|E|S|O         corps du niveau impair 2N-1 (N = 2 à 15), foreuse tournée vers la direction (sortie du minerai) ;
  eNN-piece           pièce du niveau pair 2N, posée sur le sommet de la tour, UNE pour les 4 directions ;
  kS-N|E|S|O, kS-piece   TÉMOIN DU KIT (S = 3 à 6) : la lignée seule (ep00).
Directions : celles de Factorio (N, E, S, O = west) ; corps.repere tourne le repère des tuiles (cotes.py). Préfixe des
matières Blender : « fore » (kit.PREFIXE ; sans effet sur l'image). Rendu : rendre.py ; contrôles : commun/ilots.py,
gris.py, apercu.py avec --famille foreuse_e.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import epoques as E  # noqa: E402

PREFIXE = "fore"
PARTIES = ("N", "E", "S", "O", "piece")


def nom(e, partie):
    return "e%02d-%s" % (e, partie)


def _finir(name, meta):
    meta["dest"] = "levels/foreuse_e/" + name
    meta["anchor_tiles"] = (0.0, 0.0)
    meta["nuit"] = bool(E.FAMILLES.get(meta["epoch"], {}).get("nuit", False))
    meta["sous_vanilla"] = False
    return meta


def _meta(e, p, side, level):
    meta = {"epoch": e, "part": "piece" if p == "piece" else "corps", "level": level, "side": side}
    if p != "piece":
        meta["dir"] = p
    return meta


def _variants():
    v = {"e01-piece": {"epoch": 1, "part": "piece", "level": 2, "side": 3}}
    for e in range(2, 16):
        for p in PARTIES:
            v[nom(e, p)] = _meta(e, p, E.COTE[e], 2 * e - 1 + (p == "piece"))
    for s in range(3, 7):
        for p in PARTIES:
            v["k%d-%s" % (s, p)] = _meta(0, p, s, 0)
    for name, meta in v.items():
        _finir(name, meta)
    return v


PIECE = {
    "name": "fore",
    "variants": _variants(),
    "margin_px": 40 + int(64 * 1.3),
    "calib": {"LIGHT_HOLDOUT": True},
}


def margin_px(name):
    return PIECE["margin_px"]


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
    seed = {"corps": 100, "piece": 300}[part] + (e if e else 400 + v["side"])
    g = K.Geo(S, C, M, "F%s%s%02d" % (part[0], v.get("dir", "x"), e if e else v["side"]), 0.0, seed=seed)
    c = corps.Ctx(g, e, ep, v["side"], hab, v.get("dir", "N"))
    if part == "corps":
        corps.corps(g, c)
    else:
        corps.piece(g, c)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
