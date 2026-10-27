"""Pièce du pipeline : MACHINE D'ASSEMBLAGE, lot F3-A (25/10), 15 âges sur le kit commun.

Format de tools/render/README.md (PIECE + build(S, C, variant)). Variantes :
  e01-piece           niveau 2 : pièce posée PAR-DESSUS l'assembleur 2 vanilla (niveau 1 inchangé), aux coins avant ;
  eNN-machine         machine du niveau impair 2N−1 (N = 2 à 15) ;
  eNN-piece           pièce du niveau pair 2N (couche ajoutée PAR-DESSUS la machine, en paire aux coins avant) ;
  kS-machine          TÉMOIN DU KIT (S = 3 à 6) : la lignée seule (ep00).
Une seule pose (l'assembleur ne tourne pas ; ses brides N et S sont fixes). Emprise : epoques.COTE. Préfixe des
matières Blender : « asm » (kit.PREFIXE ; sans effet sur l'image). Rendu : rendre.py ; contrôles : commun/ilots.py,
apercu.py avec --famille assembleur_e.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import epoques as E  # noqa: E402

PREFIXE = "asm"
PARTIES = ("machine", "piece")


def nom(e, partie):
    return "e%02d-%s" % (e, partie)


def _finir(name, meta):
    meta["dest"] = "levels/assembleur_e/" + name
    meta["anchor_tiles"] = (0.0, 0.0)
    meta["nuit"] = bool(E.FAMILLES.get(meta["epoch"], {}).get("nuit", False))
    meta["sous_vanilla"] = False      # la pièce de l'âge 1 se pose PAR-DESSUS le vanilla (profil.level_layers)
    return meta


def _variants():
    v = {"e01-piece": {"epoch": 1, "part": "piece", "level": 2, "side": 3}}
    for e in range(2, 16):
        for p in PARTIES:
            v[nom(e, p)] = {"epoch": e, "part": p, "level": 2 * e - 1 + (p == "piece"), "side": E.COTE[e]}
    for s in range(3, 7):
        v["k%d-machine" % s] = {"epoch": 0, "part": "machine", "level": 0, "side": s}
    for name, meta in v.items():
        _finir(name, meta)
    return v


PIECE = {
    "name": "asm",
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
    seed = {"machine": 100, "piece": 300}[part] + (e if e else 400 + v["side"])
    g = K.Geo(S, C, M, "A%s%02d" % (part[0], e if e else v["side"]), 0.0, seed=seed)
    c = corps.Ctx(g, e, ep, v["side"], hab)
    {"machine": corps.machine, "piece": corps.piece}[part](g, c)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
