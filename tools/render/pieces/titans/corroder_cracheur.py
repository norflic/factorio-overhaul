"""CORRODER CRACHEUR (s43) : variante cracheur du Corroder (corroder.py) : grosse POCHE D'ACIDE dorsale cerclée de côtes rongées (le
réservoir, qui se vide à l'attaque) et TROMPE DE CRACHAT annelée à la place des mandibules (elle se dresse, la goutte d'acide grossit).
Même gabarit, même série (8 directions, course 8, attaque 4) et même cadavre que le déchiqueteur ; lu par les cracheurs de la famille
(champ corps3d_cracheur de shared/content/enemies.lua).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import corroder as C  # noqa: E402

C.CRACHEUR = True
PREFIX = C.PREFIX
GRIS = C.GRIS
SERIE = {"course": 8, "attaque": 4, "densite": 48.0, "R": 2.2, "zmax": 1.9, "sol": 30.0}
AO = C.AO
GLOW_BLANC = True
FOULEE = 2 * 0.32
PIECES = C.PIECES


def build_anime(S, lot, stage, u, attaque):
    return C.build(S, lot, u, attaque)


def build_piece(S, lot, stage, piece):
    return C.build(S, lot, mort=True)
