"""Pièce du pipeline : TOURELLE LASER, lot F1-A (24/10), 15 âges sur le kit commun. FICHIER GELÉ (kit de famille).

Format de tools/render/README.md (PIECE + build(S, C, variant)). Variantes (même contrat que gun_e/piece.py) :
  e01-piece           niveau 2 : pièce posée SOUS le laser vanilla (niveau 1 inchangé) ;
  eNN-socle           base du niveau impair 2N-1 (N = 2 à 15) ;
  eNN-piece           pièce du niveau pair 2N (couche ajoutée au socle, en paire aux coins avant) ;
  eNN-tete-N|E        tête, faisceau au nord ou à l'est ;
  eNN-tete-dKK        tête tournée (K = 00 à 63 ; d00 = nord, sens horaire, d16 = E exactement), à la demande ;
  kS-socle, kS-tete-N|E (et kS-tete-dKK)   TÉMOIN DU KIT (S = 2 à 6) : la lignée seule (ep00) ;
  mNN-socle, mNN-tete-N|E (et mNN-tete-dKK)   MAQUETTE de l'âge NN (2 à 15, quatrième jet, M-6) : la lignée habillée
                      aux matières de l'âge avec la silhouette d'affût et la forme de tête de epoques.MAQUETTES[NN],
                      sans organe d'âge (gris.py sur les socles avant d'écrire les fichiers d'âge).
Directions : convention de Factorio (RotatedAnimation : indice 0 = nord, sens horaire), mêmes flottants que gun_e
(d00 = 0.0, d16 = −π/2 au bit près). Emprise : epoques.COTE. Préfixe des matières Blender : « lase » (kit.PREFIXE ;
sans effet sur l'image). Rendu : rendre.py ; contrôles : commun/ilots.py, gris.py, mesures.py, dominance.py,
vignettes.py, apercu.py avec --famille laser_e.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import epoques as E  # noqa: E402

PREFIXE = "lase"
NDIRS = 64
DIRS = {"N": 0.0, "E": -math.pi / 2}
DIRS.update({"d%02d" % k: (0.0 if k == 0 else -2.0 * math.pi * k / NDIRS) for k in range(NDIRS)})
assert DIRS["d00"] == DIRS["N"] and DIRS["d16"] == DIRS["E"], "convention des directions rompue"
ROSE = (("N", "d00"), ("NE", "d08"), ("E", "d16"), ("SE", "d24"), ("S", "d32"), ("SO", "d40"), ("O", "d48"),
        ("NO", "d56"))
PARTIES = ("socle", "piece", "tete-N", "tete-E")
_RE_TETE_D = re.compile(r"^(?:e(\d\d)|k(\d)|m(\d\d))-tete-(d\d\d)$")


def nom(e, partie):
    return "e%02d-%s" % (e, partie)


def _finir(name, meta):
    meta["dest"] = "levels/laser_e/" + name
    meta["anchor_tiles"] = (0.0, 0.0)
    meta["nuit"] = bool(E.FAMILLES.get(meta["epoch"], {}).get("nuit", False))
    meta["sous_vanilla"] = name == "e01-piece"
    return meta


def _variants():
    v = {"e01-piece": {"epoch": 1, "part": "piece", "level": 2, "side": 2}}
    for e in range(2, 16):
        for p in PARTIES:
            meta = {"epoch": e, "part": p.split("-")[0], "level": 2 * e - 1 + (p == "piece"), "side": E.COTE[e]}
            if p.startswith("tete"):
                meta["dir"] = p.split("-", 1)[1]
            v[nom(e, p)] = meta
    for s in range(2, 7):
        for p in ("socle", "tete-N", "tete-E"):
            meta = {"epoch": 0, "part": p.split("-")[0], "level": 0, "side": s}
            if p.startswith("tete"):
                meta["dir"] = p.split("-", 1)[1]
            v["k%d-%s" % (s, p)] = meta
    for e in sorted(E.MAQUETTES):
        for p in ("socle", "tete-N", "tete-E"):
            meta = {"epoch": e, "part": p.split("-")[0], "level": 0, "side": E.COTE[e], "maquette": True}
            if p.startswith("tete"):
                meta["dir"] = p.split("-", 1)[1]
            v["m%02d-%s" % (e, p)] = meta
    for name, meta in v.items():
        _finir(name, meta)
    return _Variantes(v)


def tete_d(name):
    m = _RE_TETE_D.match(name)
    if not m or m.group(4) not in DIRS:
        return None
    if m.group(1) is not None:
        e = int(m.group(1))
        if not 2 <= e <= 15:
            return None
        meta = {"epoch": e, "part": "tete", "level": 2 * e - 1, "side": E.COTE[e]}
    elif m.group(3) is not None:
        e = int(m.group(3))
        if e not in E.MAQUETTES:
            return None
        meta = {"epoch": e, "part": "tete", "level": 0, "side": E.COTE[e], "maquette": True}
    else:
        s = int(m.group(2))
        if not 2 <= s <= 6:
            return None
        meta = {"epoch": 0, "part": "tete", "level": 0, "side": s}
    meta["dir"] = m.group(4)
    return _finir(name, meta)


class _Variantes(dict):
    """Table des variantes explicites (72 + 42 maquettes), plus les têtes tournées dKK construites à la demande."""

    def __missing__(self, key):
        meta = tete_d(key)
        if meta is None:
            raise KeyError(key)
        return meta

    def __contains__(self, key):
        return dict.__contains__(self, key) or tete_d(key) is not None


PIECE = {
    "name": "lase",
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
    K.PREFIXE = PREFIXE
    v = PIECE["variants"][variant]
    e = v["epoch"]
    ep = E.maquette(e) if v.get("maquette") else E.module(e)
    M = K.materials(S, e, ep)
    hab = E.habillage(ep)
    part = v["part"]
    seed = {"socle": 100, "tete": 200, "piece": 300}[part] + (e if e else 400 + v["side"]) + (500 if v.get("maquette")
                                                                                               else 0)
    rot = DIRS[v["dir"]] if part == "tete" else 0.0
    g = K.Geo(S, C, M, "L%s%s%02d" % (part[0], "m" if v.get("maquette") else "", e if e else v["side"]), rot,
              seed=seed)
    c = corps.Ctx(g, e, ep, v["side"], hab)
    {"socle": corps.socle, "piece": corps.piece, "tete": corps.tete}[part](g, c)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
