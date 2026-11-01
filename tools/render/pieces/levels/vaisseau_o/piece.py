"""Pièce du pipeline : LE CENTRE-VAISSEAU, méthode CENTRE-OPUS (29/10, nuit). Quatre états modélisés UN PAR UN (pas de
générateur commun) : épave, âge 1 (réparé), âge 8 (moitié vaisseau, moitié bâtiment), âge 15 (citadelle sur la
carcasse). Seule la carcasse du vaisseau (vaisseau.py) est partagée ; géométrie (geo.py) et matières (mat.py) sont
propres au kit. Format de tools/render/README.md (PIECE + build(S, C, variant)). Nez vers la DROITE (+X).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

COTE = {"epave": 4, "age01": 4, "age08": 6, "age15": 8, "qg08": 6, "qg07": 6, "qg09": 6}
AGE = {"epave": 0, "age01": 1, "age08": 8, "age15": 15, "qg08": 8, "qg07": 7, "qg09": 9}
MODULE = {"epave": "epave", "age01": "age01", "age08": "age08", "age15": "age15", "qg08": "qg08", "qg07": "qg07", "qg09": "qg09"}

PIECE = {"name": "vo", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True},
         "variants": {n: {"epoch": AGE[n], "side": COTE[n], "dest": "levels/vaisseau_o/" + n, "anchor_tiles": (0.0, 0.0)}
                      for n in COTE}}


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    mod = importlib.import_module(MODULE[variant])
    lot = geo.Lot(S, "vo_" + variant)
    info = mod.build(S, lot) or {}
    n = lot.n
    lot.flush()
    return {"count": {"pieces": n}, "halos": 0, "info": info}
