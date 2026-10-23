"""Pièce du pipeline : mitrailleuse, lot V3-E, 15 époques sur le KIT COMMUN (quatrième passe, 23/10). FICHIER GELÉ.

Format de tools/render/README.md (PIECE + build(S, C, variant)). Variantes :
  e01-piece           niveau 2 : pièce posée SOUS la mitrailleuse vanilla (niveau 1 inchangé) ; foyers de nuit ;
  eNN-socle           base du niveau impair 2N-1 (N = 2 à 15) ;
  eNN-piece           pièce du niveau pair 2N (couche ajoutée au socle, en paire aux coins avant) ;
  eNN-tete-N|E        tête (pose « prepared »), canons au nord ou à l'est ;
  kS-socle, kS-tete-N|E   TÉMOIN DU KIT (S = 2 à 6) : la lignée seule (ep00), sans organe d'époque ; avec la variable
                      FO_HABILLAGE_ESSAI=pionnier|fusion|legende (rendre.py --habillage), le témoin porte un habillage
                      d'essai (habillages.py).
Emprise par époque : epoques.COTE (Q-S1, shared/levels/config.lua L.footprints.gun = { era = { 2, 3, 4, 5, 6 } }).
Rendu : rendre.py (verrou de rendu, paquets, post-traitement) ; contrôles : ilots.py (bloquant), mesures.py,
gris.py, dominance.py, vignettes.py, apercu.py.

DÉGEL CONTRÔLÉ D-9 (lot A1, 23/10) : directions de la tête « dKK » (K = 00 à 63), pour la rose et les 64 positions du
jeu. Variantes eNN-tete-dKK (N = 2 à 15) et kS-tete-dKK, générées À LA DEMANDE (classe _Variantes) : la table
explicite reste celle des 72 variantes validées (sorted(PIECE["variants"]) inchangé, construction.py --tout aussi).
Convention de Factorio (RotatedAnimation, prototype-api.json 1.1.91 : « 8 : North (1), Northeast (2), East (3)… »,
counterclockwise = false par défaut ; RealOrientation : « starting at the top and going clockwise ») : l'indice 0
est le NORD et les indices tournent dans le SENS HORAIRE vu d'en haut. Angle de pose = −2π·K/64 (même signe que
DIRS["E"] = −π/2) : d00 = N et d16 = E EXACTEMENT (mêmes flottants : multiplication et division par des puissances de
2), d32 = S, d48 = O. La géométrie ne change pas : la pose n'est qu'une rotation d'objet (kit.Geo.rotz).
Preuve d'identité (lot A1) : d00 et d16 rendus de nouveau == tete-N et tete-E validés (fo-logs\\2026-10-23_suite\\A1).
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import epoques as E  # noqa: E402

NDIRS = 64
DIRS = {"N": 0.0, "E": -math.pi / 2}
# d00 = 0.0 (et non −0.0), puis −2π·K/64 : d16 == DIRS["E"] au bit près (vérifié ci-dessous)
DIRS.update({"d%02d" % k: (0.0 if k == 0 else -2.0 * math.pi * k / NDIRS) for k in range(NDIRS)})
assert DIRS["d00"] == DIRS["N"] and DIRS["d16"] == DIRS["E"], "convention des directions rompue"
# rose des 8 directions (lot A1) : nom de boussole -> dKK
ROSE = (("N", "d00"), ("NE", "d08"), ("E", "d16"), ("SE", "d24"), ("S", "d32"), ("SO", "d40"), ("O", "d48"),
        ("NO", "d56"))
PARTIES = ("socle", "piece", "tete-N", "tete-E")
_RE_TETE_D = re.compile(r"^(?:e(\d\d)|k(\d))-tete-(d\d\d)$")


def nom(e, partie):
    return "e%02d-%s" % (e, partie)


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
    for name, meta in v.items():
        _finir(name, meta)
    return _Variantes(v)


def _finir(name, meta):
    meta["dest"] = "levels/gun_e/" + name
    meta["anchor_tiles"] = (0.0, 0.0)
    meta["nuit"] = bool(E.FAMILLES.get(meta["epoch"], {}).get("nuit", False))
    meta["sous_vanilla"] = name == "e01-piece"
    return meta


def tete_d(name):
    """Méta d'une variante tournée eNN-tete-dKK | kS-tete-dKK (copie de celle de tete-N, direction dKK), ou None."""
    m = _RE_TETE_D.match(name)
    if not m or m.group(3) not in DIRS:
        return None
    if m.group(1) is not None:
        e = int(m.group(1))
        if not 2 <= e <= 15:
            return None
        meta = {"epoch": e, "part": "tete", "level": 2 * e - 1, "side": E.COTE[e]}
    else:
        s = int(m.group(2))
        if not 2 <= s <= 6:
            return None
        meta = {"epoch": 0, "part": "tete", "level": 0, "side": s}
    meta["dir"] = m.group(3)
    return _finir(name, meta)


class _Variantes(dict):
    """Table des variantes : les 72 explicites, plus les têtes tournées dKK construites à la demande (jamais stockées :
    l'itération et sorted() ne voient que les 72)."""

    def __missing__(self, key):
        meta = tete_d(key)
        if meta is None:
            raise KeyError(key)
        return meta

    def __contains__(self, key):
        return dict.__contains__(self, key) or tete_d(key) is not None


PIECE = {
    "name": "gune",
    "variants": _variants(),
    "margin_px": 40,
    "calib": {"LIGHT_HOLDOUT": True},
}


# BOUCHON ARRIÈRE (lot A2, 24/10 ; corps.bouchon_arriere) : âges où la rose d'A1 montre une fente enfermée vue de dos
# (SE d24, S d32, SO d40 ; E d16 et O d48 passaient). Posé seulement dans le SECTEUR arrière d20 à d44 : hors de lui,
# il se voit (en O : bloc sombre au coin arrière, rendu rapide du lot A2) sans rien boucher. Jamais dans les poses
# VALIDÉES N et E (d00, d16), hors du secteur : elles restent identiques octet à octet. Les bornes d20 et d44 sont
# CHOISIES (milieux entre poses rendues), non vérifiées pose par pose : à revoir avec les 64 directions (lot A3).
# Variable FO_BOUCHON : « force » le pose dans toute direction (mesure de sa visibilité, jamais en production), « non »
# le retire.
BOUCHON_AGES = (4, 5, 6, 7)
BOUCHON_SECTEUR = range(20, 45)


def bouchon(e, d):
    mode = os.environ.get("FO_BOUCHON", "").strip()
    if e not in BOUCHON_AGES or mode == "non":
        return False
    if mode == "force":
        return True
    return bool(re.match(r"^d\d\d$", d or "")) and int(d[1:]) in BOUCHON_SECTEUR


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
    essai = os.environ.get("FO_HABILLAGE_ESSAI", "").strip()
    if essai:
        # habillage d'essai du kit (habillages.py, rendre.py --habillage) : TÉMOIN seulement
        if e != 0:
            raise ValueError("FO_HABILLAGE_ESSAI=%s ne s'applique qu'au témoin du kit (kS-…), pas à %s" % (essai, variant))
        import habillages
        ep = habillages.temoin(essai, ep)
    M = K.materials(S, e, ep)
    hab = E.habillage(ep)
    part = v["part"]
    seed = {"socle": 100, "tete": 200, "piece": 300}[part] + (e if e else 400 + v["side"])
    rot = DIRS[v["dir"]] if part == "tete" else 0.0
    g = K.Geo(S, C, M, "%s%02d" % (part[0], e if e else v["side"]), rot, seed=seed)
    c = corps.Ctx(g, e, ep, v["side"], hab)
    c.bouchon = part == "tete" and bouchon(e, v["dir"])
    {"socle": corps.socle, "piece": corps.piece, "tete": corps.tete}[part](g, c)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
