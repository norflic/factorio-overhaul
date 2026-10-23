"""Profil FACTICE (test commun/tests/test_famille.py) : il fait « import epoques » comme gun_e/profil.py et comme le
prescrit commun/LISEZMOI.md. Contrat : commun/famille.py."""
import os
import sys

_ICI = os.path.dirname(os.path.abspath(__file__))
if _ICI not in sys.path:
    sys.path.insert(0, _ICI)
import epoques as E  # noqa: E402

NOM = "fam_essai"
TITRE = "famille d'essai"
FAMILLE_PROG = "essai"
AGES = tuple(range(1, 16))
COTE = {e: E.COTE[e] for e in AGES}
POSES = ("E",)
FENETRE_GRIS = 4.0
REF_VANILLA = dict(dump="aucun", mesure="aucun")
CIBLE = {}
LUCIOLES_MAX = 13.2
PIECE_MIN = 0.10
TROUS_VOULUS = E.TROUS_VOULUS


def prefixe(e):
    return e if isinstance(e, str) else "x%02d" % e


def level_layers(K, out, e, pose, even=False, kinds=("shadow", "main", "glow", "light")):
    return K.own(out, "%s-corps" % prefixe(e), kinds)


def variantes_seules(e):
    return [("%s-corps" % prefixe(e), "corps")]


def compositions(e):
    return [("E", False)]


def sprites(e):
    return ["%s-corps" % prefixe(e)]


def est_piece_paire(e, fichier):
    return False


def besoin_vignette(e, pose):
    return ["%s-corps" % prefixe(e)]


def niveau_vignette(e):
    return 2 * e - 1


def ronde(e):
    return ["%s-corps" % prefixe(e)]
