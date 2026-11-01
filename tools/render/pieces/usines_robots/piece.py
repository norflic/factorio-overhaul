"""Pièce du pipeline : LES USINES DE ROBOTS (lot US-V0, 31/10), trois états clés modélisés un par un, chacun à son âge
(PLAN ROBOTS §5 bis) : Atelier d'automates (âge 3, 3×3), Dock de pilotage (âge 10, 7×7), Portique (âge 13, 11×11).
Géométrie (geo.py) et matières (mat.py) : copies du kit vaisseau_o validé par le DC (QG du 31/10). Format de
tools/render/README.md (PIECE + build(S, C, variant)).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

COTE = {"atelier": 3, "dock": 7, "portique": 11}
AGE = {"atelier": 3, "dock": 10, "portique": 13}

PIECE = {"name": "ur", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True},
         "variants": {n: {"epoch": AGE[n], "side": COTE[n], "dest": "usines_robots/" + n, "anchor_tiles": (0.0, 0.0)}
                      for n in COTE}}


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    mod = importlib.import_module(variant)
    lot = geo.Lot(S, "ur_" + variant)
    info = mod.build(S, lot) or {}
    n = lot.n
    lot.flush()
    return {"count": {"pieces": n}, "halos": 0, "info": info}
