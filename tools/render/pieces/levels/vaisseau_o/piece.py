"""Pièce du pipeline : LE CENTRE-VAISSEAU (kit vaisseau_o). Format de tools/render/README.md (PIECE + build(S, C,
variant)). Nez vers la DROITE (+X).

Lot QG (30/10) : l'âge 15 est REFAIT de zéro (legende15.py + l15_vaisseau.py + greb.py : forme, échelle, pièces
fonctionnelles du brief QG) ; « age15_opus » garde l'essai 7 de CENTRE-OPUS (citadelle sur le cigare) pour comparaison.
Les autres états (épave, âges 1 et 8) sont ceux de CENTRE-OPUS, refusés par le brief QG (à refaire par leurs lots).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

COTE = {"epave": 4, "age01": 4, "age08": 6, "age15": 8, "age15g": 8, "age15_opus": 8}
AGE = {"epave": 0, "age01": 1, "age08": 8, "age15": 15, "age15g": 15, "age15_opus": 15}
MODULE = {"epave": "epave", "age01": "age01", "age08": "age08", "age15": "legende15", "age15g": "legende15", "age15_opus": "age15"}

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
    count = {"pieces": n}
    count.update({k: v for k, v in sorted(info.items()) if isinstance(v, (int, float))})
    return {"count": count, "halos": 0, "info": info}
