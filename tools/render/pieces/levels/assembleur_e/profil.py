"""PROFIL DE LA MACHINE D'ASSEMBLAGE pour les outils communs (lot F3-A, 25/10). Python pur (3.9). Contrat :
commun/famille.py.

Variantes eNN-machine, eNN-piece (âge 1 : e01-piece PAR-DESSUS l'assembleur 2 vanilla), témoin kS-machine ; UNE pose,
« F » (fixe : l'assembleur ne tourne pas) ; référence vanilla « assembling-machine-2 » (niveau 1 de la famille,
shared/levels/config.lua : base = "assembling-machine-2"), mesurée dans docs/da/mesures_vanilla.json. Il n'existe pas de
dump de l'assembleur 2 dans fo-logs/2026-10-22_V3S/industriel/dumps (seulement l'assembleur 3) : ses couches sont lues
DIRECTEMENT dans data/base (image 0 de l'animation, valeurs de data/base/prototypes/entity/entities.lua, assembling-
machine-2 : hr 214 × 218, décalage util.by_pixel(0, 4) ; ombre 196 × 163, util.by_pixel(12, 4.75)).
Cibles de la charte : AUCUNE (CIBLE = {}) au lot F3-A ; repère des points blancs : celui de la mitrailleuse, provisoire.
"""
import os
import sys

_ICI = os.path.dirname(os.path.abspath(__file__))
if _ICI not in sys.path:
    sys.path.insert(0, _ICI)
import epoques as E  # noqa: E402

NOM = "assembleur_e"
TITRE = "machine d'assemblage"
FAMILLE_PROG = "assembleur"
AGES = tuple(range(1, 16))
COTE = {e: E.COTE[e] for e in AGES}
POSES = ("F",)
FENETRE_GRIS = 9.0
REF_VANILLA = dict(dump=None, mesure="assembling-machine-2")
CIBLE = {}
LUCIOLES_MAX = 13.2
PIECE_MIN = 0.10
TROUS_VOULUS = E.TROUS_VOULUS

_VAN_AM2 = [
    dict(filename="__base__/graphics/entity/assembling-machine-2/hr-assembling-machine-2.png", width=214, height=218,
         frame_count=32, line_length=8, shift=[0.0, 4 / 32.0], scale=0.5),
    dict(filename="__base__/graphics/entity/assembling-machine-2/hr-assembling-machine-2-shadow.png", width=196,
         height=163, frame_count=32, line_length=8, shift=[12 / 32.0, 4.75 / 32.0], scale=0.5, draw_as_shadow=True),
]
_CACHE = {}


def prefixe(e):
    return e if isinstance(e, str) else "e%02d" % e


def vanilla_niveau1(K, pose=None):
    """Couches de l'assembleur 2 vanilla (niveau 1) : image 0 de l'animation et son ombre."""
    if "am2" not in _CACHE:
        lays = K.D.vanilla_layers([(leaf, 0, None) for leaf in _VAN_AM2], K.DATA)
        import numpy as np
        _CACHE["am2"] = [{"img": l["img"].astype(np.float64), "shift": l["shift"], "kind": l["kind"]} for l in lays]
    return list(_CACHE["am2"])


def level_layers(K, out, e, pose, even=False, kinds=("shadow", "main", "glow", "light")):
    """Couches d'un niveau : machine (+ pièce paire PAR-DESSUS) ; âge 1 : vanilla (+ pièce du niveau 2 par-dessus) ;
    e = « k3 » … « k6 » : témoin du kit (lignée seule). La pose est ignorée (une seule)."""
    if e == 1:
        lays = [l for l in vanilla_niveau1(K) if l["kind"] in kinds]
        if even:
            lays = lays + K.own(out, "e01-piece", kinds)
        return lays
    pre = prefixe(e)
    lays = K.own(out, pre + "-machine", kinds)
    if even and not isinstance(e, str):
        # ronde F3-A2 : TEINTE du niveau pair sur la couche principale de la machine (epoques.teinte_pair)
        import numpy as np
        t = np.array(E.teinte_pair(e), dtype=np.float64)
        lays = [dict(l, img=np.concatenate([l["img"][..., :3] * t, l["img"][..., 3:]], -1)) if l["kind"] == "main"
                else l for l in lays]
        lays += K.own(out, pre + "-piece", kinds)
    return lays


def variantes_seules(e):
    if e == 1:
        return []
    return [("%s-machine" % prefixe(e), "machine")]


def compositions(e):
    if isinstance(e, str):
        return [("F", False)]
    if e == 1:
        return [("F", True)]
    return [("F", False), ("F", True)]


def sprites(e):
    pre = prefixe(e)
    return ["%s-%s" % (pre, p) for p in ("machine", "piece")]


def est_piece_paire(e, fichier):
    if e == 1:
        return fichier.startswith("hr-asm-e01-piece")
    return ("-%s-piece-" % prefixe(e)) in ("-" + fichier)


def besoin_vignette(e, pose):
    return ["e01-piece"] if e == 1 else ["%s-machine" % prefixe(e)]


def niveau_vignette(e):
    return 2 if e == 1 else 2 * e - 1


def ronde(e):
    """Variantes d'une ronde (rendre.py --ronde) : machine et pièce paire (âge 1 : la pièce du niveau 2)."""
    return ["e01-piece"] if e == 1 else ["%s-%s" % (prefixe(e), p) for p in ("machine", "piece")]
