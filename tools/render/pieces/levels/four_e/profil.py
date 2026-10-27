"""PROFIL DU FOUR pour les outils communs (lot F2-A, 25/10). Python pur (3.9). Contrat : commun/famille.py.

Variantes eNN-socle, eNN-piece (âge 1 : e01-piece SOUS le four en acier vanilla), témoin kS-… ; le four ne tourne pas :
UNE seule pose, nommée « E » pour que les outils communs (vignettes jeu « E », gris.py --pose E) la prennent ; la
couche est la même quelle que soit la pose demandée. Référence vanilla « steel-furnace » (dump du lot :
fo-logs/2026-10-25_F2/ref/furnace_steel-furnace.txt, lu ici et non dans le dossier des dumps de V3-S) ; CIBLE vide :
aucune charte de masse propre au four n'est fixée (dit dans NOTES.md).
"""
import os
import sys

_ICI = os.path.dirname(os.path.abspath(__file__))
if _ICI not in sys.path:
    sys.path.insert(0, _ICI)
import epoques as E  # noqa: E402

NOM = "four_e"
TITRE = "four"
FAMILLE_PROG = "four"
AGES = tuple(range(1, 16))
COTE = {e: E.COTE[e] for e in AGES}
POSES = ("E",)
FENETRE_GRIS = 10.0
REF_VANILLA = dict(dump="furnace_steel-furnace", mesure="steel-furnace")
DUMP_VANILLA = "F:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-25_F2/ref/furnace_steel-furnace.txt"
CIBLE = {}
LUCIOLES_MAX = 13.2
PIECE_MIN = 0.10
TROUS_VOULUS = E.TROUS_VOULUS
_VAN = {}


def prefixe(e):
    return e if isinstance(e, str) else "e%02d" % e


def vanilla_niveau1(K):
    """Couches du four en acier vanilla (niveau 1) : animation (corps et ombre), image 0."""
    if "v" not in _VAN:
        D = K.D
        d = D.parse_dump(open(DUMP_VANILLA, encoding="utf-8", errors="replace").read())
        lays = D.vanilla_layers([(d["animation"], 0, None)], K.DATA)
        import numpy as np
        _VAN["v"] = [{"img": l["img"].astype(np.float64), "shift": l["shift"], "kind": l["kind"], "file": l["file"]}
                     for l in lays]
    return [dict(l) for l in _VAN["v"]]


def level_layers(K, out, e, pose, even=False, kinds=("shadow", "main", "glow", "light")):
    """Couches d'un niveau : four (+ pièce paire) ; âge 1 : vanilla (+ pièce du niveau 2, SOUS le vanilla) ;
    e = « k2 » … « k6 » : témoin du kit (lignée seule)."""
    if e == 1:
        lays = [l for l in vanilla_niveau1(K) if l["kind"] in kinds]
        if even:
            lays = K.own(out, "e01-piece", kinds) + lays
        return lays
    pre = prefixe(e)
    lays = K.own(out, pre + "-socle", kinds)
    if even:
        lays += K.own(out, pre + "-piece", kinds)
    return lays


def variantes_seules(e):
    if e == 1:
        return []
    return [("%s-socle" % prefixe(e), "socle")]


def compositions(e):
    if e == 1:
        return [("E", True)]
    if isinstance(e, str):
        return [("E", False)]
    return [("E", False), ("E", True)]


def sprites(e):
    pre = prefixe(e)
    return ["%s-%s" % (pre, p) for p in ("socle", "piece")]


def est_piece_paire(e, fichier):
    if e == 1:
        return fichier.startswith("hr-four-e01-piece")
    return ("-%s-piece-" % prefixe(e)) in ("-" + fichier)


def besoin_vignette(e, pose):
    return ["e01-piece"] if e == 1 else ["%s-socle" % prefixe(e)]


def niveau_vignette(e):
    return 2 if e == 1 else 2 * e - 1


def ronde(e):
    """Variantes d'une ronde (rendre.py --ronde) : le socle (âge 1 : la pièce) et la pièce paire."""
    return ["e01-piece"] if e == 1 else ["%s-socle" % prefixe(e), "%s-piece" % prefixe(e)]
