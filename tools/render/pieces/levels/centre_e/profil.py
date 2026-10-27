"""PROFIL DU CENTRE DE COMMANDEMENT pour les outils communs (lot F5-A, 27/10). Python pur (3.9). Contrat :
commun/famille.py.

Variantes eNN-centre (N = 1 à 15 : niveau = âge, 15 niveaux, aucune pièce paire), témoin kS-centre (S = 4 à 8) ; UNE
pose, « F ». Référence vanilla de la charte : « roboport » (docs/da/mesures_vanilla.json ; le centre actuel en jeu est un
roboport surmonté d'un radar). Cibles de la charte : AUCUNE (ronde 1) ; repère des points blancs : celui de la
mitrailleuse, provisoire.
"""
import os
import sys

_ICI = os.path.dirname(os.path.abspath(__file__))
if _ICI not in sys.path:
    sys.path.insert(0, _ICI)
import epoques as E  # noqa: E402

NOM = "centre_e"
TITRE = "centre de commandement"
FAMILLE_PROG = "centre"
AGES = tuple(range(1, 16))
COTE = {e: E.COTE[e] for e in AGES}
POSES = ("F",)
FENETRE_GRIS = 11.0
REF_VANILLA = dict(dump=None, mesure="roboport")
CIBLE = {}
LUCIOLES_MAX = 13.2
PIECE_MIN = 0.10
TROUS_VOULUS = E.TROUS_VOULUS


def prefixe(e):
    return e if isinstance(e, str) else "e%02d" % e


def vanilla_niveau1(K, pose=None):
    """Pas de niveau vanilla dessiné à part : le niveau 1 est l'âge 1 (eNN-centre)."""
    return []


def level_layers(K, out, e, pose, even=False, kinds=("shadow", "main", "glow", "light")):
    """Couches d'un niveau (niveau = âge) : le centre de l'âge ; e = « k4 » … « k8 » : témoin. Pose ignorée."""
    return K.own(out, "%s-centre" % prefixe(e), kinds)


def variantes_seules(e):
    return [("%s-centre" % prefixe(e), "centre")]


def compositions(e):
    return [("F", False)]


def sprites(e):
    return ["%s-centre" % prefixe(e)]


def est_piece_paire(e, fichier):
    return False


def besoin_vignette(e, pose):
    return ["%s-centre" % prefixe(e)]


def niveau_vignette(e):
    return e


def ronde(e):
    return ["%s-centre" % prefixe(e)]
