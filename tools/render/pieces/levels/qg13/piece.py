"""Pièce du pipeline : LE QG / CENTRE DE COMMANDEMENT À L'ÂGE 13 (Fusion), refonte du 30/10 (BRIEF QG).
Outillage repris du kit vaisseau_o (geo, mat, rendre, batch_blender, planche, mesure) ; forme refaite de zéro
(carcasse13.py + age13.py). Nez vers la DROITE (+X). Emprise 16×8 (socle 2:1 de l'ère V).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

COTE = {"age13": 8}
AGE = {"age13": 13}
MODULE = {"age13": "age13"}

PIECE = {"name": "qg13", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True},
         "variants": {n: {"epoch": AGE[n], "side": COTE[n], "dest": "levels/qg13/" + n, "anchor_tiles": (0.0, 0.0)}
                      for n in COTE}}


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    mod = importlib.import_module(MODULE[variant])
    importlib.reload(mod)
    lot = geo.Lot(S, "q13_" + variant)
    info = mod.build(S, lot) or {}
    n = lot.n
    lot.flush()
    return {"count": {"pieces": n}, "halos": 0, "info": info}
