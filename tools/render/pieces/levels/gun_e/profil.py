"""PROFIL DE LA MITRAILLEUSE pour les outils communs (lot K0, 23/10). Python pur (3.9). Contrat : commun/famille.py.

Ce fichier reprend, SANS les changer, les règles que les outils de gun_e avaient en dur avant le lot K0 (compo.py,
ilots.py, gris.py, mesures.py, dominance.py, vignettes.py, rendre.py --ronde) : variantes eNN-socle, eNN-piece,
eNN-tete-E, eNN-tete-N (âge 1 : e01-piece SOUS la mitrailleuse vanilla), témoin du kit kS-…, poses E et N, référence
vanilla « gun-turret », cibles du catalogue §A.4. Un changement des poses de la tête (lot A1 : directions dNN) se fait
ICI (prefixe, level_layers, variantes_seules, besoin_vignette, ronde), pas dans les outils.
"""
import os
import sys

_ICI = os.path.dirname(os.path.abspath(__file__))
if _ICI not in sys.path:
    sys.path.insert(0, _ICI)
import epoques as E  # noqa: E402

NOM = "gun_e"
TITRE = "mitrailleuse"
FAMILLE_PROG = "mitrailleuse"
AGES = tuple(range(1, 16))
COTE = {e: E.COTE[e] for e in AGES}
POSES = ("E", "N")
FENETRE_GRIS = 14.0   # la plus grande emprise, 6×6, avec ses canons, y tient
REF_VANILLA = dict(dump="ammo-turret_gun-turret", mesure="gun-turret")
# cibles du catalogue §A.4 (masse t², petites pièces, O, bande de la zone lumineuse de jour)
CIBLE = {1: (3.5, 156, 0.8, (0.0, 0.02)), 2: (3.6, 172, 0.8, (0.0, 0.03)), 3: (3.7, 189, 0.8, (0.02, 0.04)),
         4: (6.8, 208, 1.2, (0.03, 0.05)), 5: (7.4, 228, 1.2, (0.03, 0.06)), 6: (8.1, 251, 1.2, (0.04, 0.06)),
         7: (12.0, 312, 1.6, (0.05, 0.07)), 8: (13.1, 343, 1.6, (0.05, 0.08)), 9: (14.4, 378, 1.6, (0.06, 0.08)),
         10: (18.8, 488, 2.0, (0.07, 0.09)), 11: (20.5, 536, 2.0, (0.07, 0.10)), 12: (22.5, 590, 2.0, (0.08, 0.10)),
         13: (27.0, 702, 2.4, (0.09, 0.11)), 14: (29.5, 772, 2.4, (0.10, 0.12)), 15: (32.4, 849, 2.4, (0.10, 0.12))}
LUCIOLES_MAX = 13.2   # feuille HR de la mitrailleuse vanilla (juge_lucioles.txt de la passe 3)
PIECE_MIN = 0.10
TROUS_VOULUS = E.TROUS_VOULUS


def prefixe(e):
    """« e05 » ; témoin du kit : « k5 » (e donné comme chaîne « k5 »)."""
    return e if isinstance(e, str) else "e%02d" % e


def vanilla_niveau1(K, pose):
    """Couches de la mitrailleuse vanilla (niveau 1) en pose E ou N (dump du lot V3-S)."""
    return K.vanilla(REF_VANILLA["dump"],
                     lambda d: [(d["base_picture"], 0, None), (d["prepared_animation"], 0 if pose == "N" else pose, None)],
                     "gun-" + pose)


def level_layers(K, out, e, pose, even=False, kinds=("shadow", "main", "glow", "light")):
    """Couches d'un niveau : socle (+ pièce paire) + tête ; époque 1 : vanilla (+ pièce du niveau 2, dessinée SOUS
    le vanilla) ; e = « k2 » … « k6 » : témoin du kit (lignée seule). La passe 3 (plage haute) rendait le niveau pair
    en une seule variante « eNN-socle-piece » : reconnue."""
    if e == 1:
        lays = list(vanilla_niveau1(K, pose))
        if even:
            lays = K.own(out, "e01-piece", kinds) + lays
        return lays
    pre = prefixe(e)
    if even and K.spec_of(out, pre + "-socle-piece"):
        lays = K.own(out, pre + "-socle-piece", kinds)
    else:
        lays = K.own(out, pre + "-socle", kinds)
        if even:
            lays += K.own(out, pre + "-piece", kinds)
    lays += K.own(out, "%s-tete-%s" % (pre, pose), kinds)
    return lays


def variantes_seules(e):
    """Sprites contrôlés SEULS par ilots.py (la pièce paire seule ne l'est pas : ses deux moitiés ne se rejoignent
    qu'à travers le socle) ; âge 1 : aucun (vanilla + pièce)."""
    if e == 1:
        return []
    pre = prefixe(e)
    return [("%s-%s" % (pre, p), p.split("-")[0]) for p in ("socle", "tete-E", "tete-N")]


def compositions(e):
    """Niveaux composés contrôlés : poses E et N, impair et pair ; âge 1 : pair seulement (le niveau 1 est vanilla) ;
    témoin : impair seulement."""
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
        return fichier.startswith("hr-gune-e01-piece")
    return ("-%s-piece-" % prefixe(e)) in ("-" + fichier)


def besoin_vignette(e, pose):
    return ["e01-piece"] if e == 1 else ["%s-socle" % prefixe(e), "%s-tete-%s" % (prefixe(e), pose)]


def niveau_vignette(e):
    return 2 if e == 1 else 2 * e - 1


def ronde(e):
    """Variantes d'une ronde de lecture (rendre.py --ronde) : celles des vignettes E et N du niveau impair."""
    return ["e01-piece"] if e == 1 else ["%s-%s" % (prefixe(e), p) for p in ("socle", "tete-E", "tete-N")]
