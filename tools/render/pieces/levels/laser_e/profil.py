"""PROFIL DE LA TOURELLE LASER pour les outils communs (lot F1-A, 24/10). Python pur (3.9). Contrat : commun/famille.py.

Variantes eNN-socle, eNN-piece, eNN-tete-E, eNN-tete-N (âge 1 : e01-piece SOUS le laser vanilla), témoin kS-… ; poses
E et N ; référence vanilla « laser-turret » (dump fo-logs/2026-10-22_V3S/industriel/dumps/electric-turret_laser-turret.txt
et docs/da/mesures_vanilla.json) ; cibles de la charte REPRISES de la mitrailleuse à emprise égale (catalogue §A.4 :
des minimums par taille ; PROVISOIRE, à revoir après la ronde 0 : le laser vanilla pèse 2,54 t² contre 3,5 visés en
2×2) ; repère des points blancs : celui de la mitrailleuse, provisoire (voir LUCIOLES_MAX).
"""
import os
import sys

_ICI = os.path.dirname(os.path.abspath(__file__))
if _ICI not in sys.path:
    sys.path.insert(0, _ICI)
import epoques as E  # noqa: E402

NOM = "laser_e"
TITRE = "tourelle laser"
FAMILLE_PROG = "laser"
AGES = tuple(range(1, 16))
COTE = {e: E.COTE[e] for e in AGES}
POSES = ("E", "N")
FENETRE_GRIS = 10.0   # la plus grande emprise, 6×6, sans canon : tient dans 10 tuiles
REF_VANILLA = dict(dump="electric-turret_laser-turret", mesure="laser-turret")
# cibles du catalogue §A.4 (masse t², petites pièces, O, bande de la zone lumineuse de jour) : celles de la
# mitrailleuse à la même emprise (PROVISOIRE)
CIBLE = {1: (3.5, 156, 0.8, (0.0, 0.02)), 2: (3.6, 172, 0.8, (0.0, 0.03)), 3: (3.7, 189, 0.8, (0.02, 0.04)),
         4: (6.8, 208, 1.2, (0.03, 0.05)), 5: (7.4, 228, 1.2, (0.03, 0.06)), 6: (8.1, 251, 1.2, (0.04, 0.06)),
         7: (12.0, 312, 1.6, (0.05, 0.07)), 8: (13.1, 343, 1.6, (0.05, 0.08)), 9: (14.4, 378, 1.6, (0.06, 0.08)),
         10: (18.8, 488, 2.0, (0.07, 0.09)), 11: (20.5, 536, 2.0, (0.07, 0.10)), 12: (22.5, 590, 2.0, (0.08, 0.10)),
         13: (27.0, 702, 2.4, (0.09, 0.11)), 14: (29.5, 772, 2.4, (0.10, 0.12)), 15: (32.4, 849, 2.4, (0.10, 0.12))}
# points blancs par t² : repère de la MITRAILLEUSE (13,2, feuille hr-gun-turret-shooting-1.png), gardé PROVISOIREMENT.
# Mesure du laser vanilla (mesures.lucioles, 24/10, E81) : hr-laser-turret-shooting.png 2,99 par t² (184 points),
# base 4,96 : le laser vanilla est 4 fois plus « propre ». Le prendre pour plafond refuserait le style validé de la
# mitrailleuse (12,3 au plus en production) : décision à faire trancher (NOTES.md du lot F1-A).
LUCIOLES_MAX = 13.2
PIECE_MIN = 0.10
TROUS_VOULUS = E.TROUS_VOULUS


def prefixe(e):
    return e if isinstance(e, str) else "e%02d" % e


def vanilla_niveau1(K, pose):
    """Couches du laser vanilla (niveau 1) en pose E ou N : socle (base_picture) + tête levée (prepared_animation,
    64 directions : N = image 0, E = image 16)."""
    return K.vanilla(REF_VANILLA["dump"],
                     lambda d: [(d["base_picture"], 0, None), (d["prepared_animation"], 0 if pose == "N" else pose, None)],
                     "laser-" + pose)


def level_layers(K, out, e, pose, even=False, kinds=("shadow", "main", "glow", "light")):
    """Couches d'un niveau : socle (+ pièce paire) + tête ; âge 1 : vanilla (+ pièce du niveau 2, SOUS le vanilla) ;
    e = « k2 » … « k6 » : témoin du kit (lignée seule)."""
    if e == 1:
        lays = list(vanilla_niveau1(K, pose))
        if even:
            lays = K.own(out, "e01-piece", kinds) + lays
        return lays
    pre = prefixe(e)
    lays = K.own(out, pre + "-socle", kinds)
    if even:
        lays += K.own(out, pre + "-piece", kinds)
    lays += K.own(out, "%s-tete-%s" % (pre, pose), kinds)
    return lays


def variantes_seules(e):
    if e == 1:
        return []
    pre = prefixe(e)
    return [("%s-%s" % (pre, p), p.split("-")[0]) for p in ("socle", "tete-E", "tete-N")]


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
    return ["%s-%s" % (pre, p) for p in ("socle", "piece", "tete-E", "tete-N")]


def est_piece_paire(e, fichier):
    if e == 1:
        return fichier.startswith("hr-lase-e01-piece")
    return ("-%s-piece-" % prefixe(e)) in ("-" + fichier)


def besoin_vignette(e, pose):
    return ["e01-piece"] if e == 1 else ["%s-socle" % prefixe(e), "%s-tete-%s" % (prefixe(e), pose)]


def niveau_vignette(e):
    return 2 if e == 1 else 2 * e - 1


def ronde(e):
    """Variantes d'une ronde de lecture (rendre.py --ronde) : celles des vignettes E et N du niveau impair."""
    return ["e01-piece"] if e == 1 else ["%s-%s" % (prefixe(e), p) for p in ("socle", "tete-E", "tete-N")]
