"""Pièce du pipeline : mitrailleuse, lot V3-E, 15 époques sur le KIT COMMUN (quatrième passe, 23/10). FICHIER GELÉ.

Format de tools/render/README.md (PIECE + build(S, C, variant)). Variantes :
  e01-piece           niveau 2 : pièce posée SOUS la mitrailleuse vanilla (niveau 1 inchangé) ; foyers de nuit ;
  eNN-socle           base du niveau impair 2N-1 (N = 2 à 15) ;
  eNN-piece           pièce du niveau pair 2N (couche ajoutée au socle, en paire aux coins avant) ;
  eNN-tete-N|E        tête (pose « prepared »), canons au nord ou à l'est ;
  kS-socle, kS-tete-N|E   TÉMOIN DU KIT (S = 2 à 6) : la lignée seule (ep00), sans organe d'époque.
Emprise par époque : epoques.COTE (Q-S1, shared/levels/config.lua L.footprints.gun = { era = { 2, 3, 4, 5, 6 } }).
Rendu : rendre.py (verrou de rendu, paquets, post-traitement) ; contrôles : ilots.py (bloquant), mesures.py,
gris.py, dominance.py, vignettes.py, apercu.py.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import epoques as E  # noqa: E402

DIRS = {"N": 0.0, "E": -math.pi / 2}
PARTIES = ("socle", "piece", "tete-N", "tete-E")


def nom(e, partie):
    return "e%02d-%s" % (e, partie)


def _variants():
    v = {"e01-piece": {"epoch": 1, "part": "piece", "level": 2, "side": 2}}
    for e in range(2, 16):
        for p in PARTIES:
            meta = {"epoch": e, "part": p.split("-")[0], "level": 2 * e - 1 + (p == "piece"), "side": E.COTE[e]}
            if p.startswith("tete"):
                meta["dir"] = p[-1]
            v[nom(e, p)] = meta
    for s in range(2, 7):
        for p in ("socle", "tete-N", "tete-E"):
            meta = {"epoch": 0, "part": p.split("-")[0], "level": 0, "side": s}
            if p.startswith("tete"):
                meta["dir"] = p[-1]
            v["k%d-%s" % (s, p)] = meta
    for name, meta in v.items():
        meta["dest"] = "levels/gun_e/" + name
        meta["anchor_tiles"] = (0.0, 0.0)
        meta["nuit"] = bool(E.FAMILLES.get(meta["epoch"], {}).get("nuit", False))
        meta["sous_vanilla"] = name == "e01-piece"
    return v


PIECE = {
    "name": "gune",
    "variants": _variants(),
    "margin_px": 40,
    "calib": {"LIGHT_HOLDOUT": True},
}


def margin_px(name):
    v = PIECE["variants"][name]
    if v["part"] != "tete":
        return 40 + int(64 * 1.3)
    return PIECE["margin_px"]


def build(S, C, variant):
    import kit as K
    import corps
    v = PIECE["variants"][variant]
    e = v["epoch"]
    ep = E.module(e)
    M = K.materials(S, e, ep)
    hab = E.habillage(ep)
    part = v["part"]
    seed = {"socle": 100, "tete": 200, "piece": 300}[part] + (e if e else 400 + v["side"])
    rot = DIRS[v["dir"]] if part == "tete" else 0.0
    g = K.Geo(S, C, M, "%s%02d" % (part[0], e if e else v["side"]), rot, seed=seed)
    c = corps.Ctx(g, e, ep, v["side"], hab)
    {"socle": corps.socle, "piece": corps.piece, "tete": corps.tete}[part](g, c)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
