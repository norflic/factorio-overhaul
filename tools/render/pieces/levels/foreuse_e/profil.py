"""PROFIL DE LA FOREUSE pour les outils communs (lot F4-A, 25/10). Python pur (3.9). Contrat : commun/famille.py.

Variantes eNN-N|E|S|O (corps tourné), eNN-piece (pièce paire, une pour les 4 directions) ; âge 1 : foreuse vanilla +
e01-piece ; témoin kS-…. Poses contrôlées E et N (S et O se lisent sur les planches du lot). Référence vanilla
« electric-mining-drill » : dump du prototype (harness --dump-proto mining-drill/electric-mining-drill) dans
fo-logs/2026-10-25_F4/vanilla/raw.txt (DUMP ci-dessous ; à refaire par la même commande s'il manque). Couches vanilla
d'une direction : graphics_set.animation[direction] (corps, flèche de sortie, ombre) puis les visualisations
« always_draw » qui ne sont pas des lumières (tête de forage, image 0 ; avants E, S, O). Cibles de la charte : aucune
(PROVISOIRE : la foreuse n'a pas de cibles au catalogue ; mesures.py ne juge rien).
"""
import os
import sys

_ICI = os.path.dirname(os.path.abspath(__file__))
if _ICI not in sys.path:
    sys.path.insert(0, _ICI)
import epoques as E  # noqa: E402

NOM = "foreuse_e"
TITRE = "foreuse électrique"
FAMILLE_PROG = "foreuse"
AGES = tuple(range(1, 16))
COTE = {e: E.COTE[e] for e in AGES}
POSES = ("E", "N")
FENETRE_GRIS = 10.0
DUMP = "F:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-25_F4/vanilla/raw.txt"
REF_VANILLA = dict(dump=DUMP, mesure="electric-mining-drill")
CIBLE = {}
LUCIOLES_MAX = 13.2
PIECE_MIN = 0.10
TROUS_VOULUS = E.TROUS_VOULUS
_VAN = {}


def prefixe(e):
    return e if isinstance(e, str) else "e%02d" % e


def vanilla_niveau1(K, pose):
    """Couches de la foreuse vanilla (niveau 1) tournée vers pose (N, E, S, O)."""
    if pose in _VAN:
        return _VAN[pose]
    d = K.D.parse_dump(open(DUMP, encoding="utf-8", errors="replace").read())
    dn = E.VANILLA_DIR[pose]
    gs = d["graphics_set"]
    nodes = [(gs["animation"][dn], 0, None)]
    wv = gs.get("working_visualisations") or {}
    items = sorted(wv.items(), key=lambda kv: int(kv[0])) if isinstance(wv, dict) else list(enumerate(wv))
    for _, v in items:
        if v.get("always_draw") and not v.get("draw_as_light") and v.get(dn + "_animation"):
            nodes.append((v[dn + "_animation"], 0, None))
    lays = K.D.vanilla_layers(nodes, K.DATA)
    r = [{"img": l["img"].astype("float64"), "shift": l["shift"], "kind": l["kind"]} for l in lays]
    _VAN[pose] = r
    return r


def _teinte(lays, e):
    """Teinte du niveau pair appliquée au corps (couches main), comme le ferait le prototype (multiplication)."""
    t = E.TEINTE_PAIR.get(e) if isinstance(e, int) else None
    if not t:
        return lays
    out = []
    for l in lays:
        if l["kind"] == "main":
            img = l["img"].copy()
            for i in range(3):
                img[..., i] = img[..., i] * t[i]
            l = dict(l, img=img)
        out.append(l)
    return out


def level_layers(K, out, e, pose, even=False, kinds=("shadow", "main", "glow", "light")):
    """Couches d'un niveau : corps tourné vers pose (+ pièce paire, + teinte du niveau pair sur le corps) ; âge 1 : vanilla
    (+ e01-piece par-dessus)."""
    if e == 1:
        lays = list(vanilla_niveau1(K, pose))
        if even:
            lays = _teinte(lays, e) + K.own(out, "e01-piece", kinds)
        return lays
    pre = prefixe(e)
    lays = K.own(out, "%s-%s" % (pre, pose), kinds)
    if even:
        lays = _teinte(lays, e) + K.own(out, pre + "-piece", kinds)
    return lays


def variantes_seules(e):
    if e == 1:
        return []
    pre = prefixe(e)
    return [("%s-%s" % (pre, p), "corps") for p in POSES]


def compositions(e):
    out = []
    for pose in POSES:
        for even in ((False, True) if not isinstance(e, str) else (False,)):
            if e == 1 and not even:
                continue
            out.append((pose, even))
    return out


def sprites(e):
    pre = prefixe(e)
    return ["%s-%s" % (pre, p) for p in ("N", "E", "piece")]


def est_piece_paire(e, fichier):
    if e == 1:
        return fichier.startswith("hr-fore-e01-piece")
    return ("-%s-piece-" % prefixe(e)) in ("-" + fichier)


def besoin_vignette(e, pose):
    return ["e01-piece"] if e == 1 else ["%s-%s" % (prefixe(e), pose)]


def niveau_vignette(e):
    return 2 if e == 1 else 2 * e - 1


def ronde(e):
    """Variantes d'une ronde de lecture : corps N et E et pièce paire (âge 1 : e01-piece)."""
    return ["e01-piece"] if e == 1 else ["%s-%s" % (prefixe(e), p) for p in ("N", "E", "piece")]
