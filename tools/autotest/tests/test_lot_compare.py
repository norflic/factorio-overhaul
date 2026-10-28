#!/usr/bin/env python3
"""Tests hors jeu de tools/autotest/lot_compare.py (lot MESURES) : règle de verdict, alertes de mort.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_lot_compare.py   -> « BILAN : N OK, 0 ECHEC(S) »
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import lot_compare as L  # noqa: E402

ok = fail = 0


def check(c, msg):
    global ok, fail
    if c:
        ok += 1
    else:
        fail += 1
        print("  ECHEC : " + msg)


check(L.verdict([-1, -2, -3, 4])[0] == "REGRESSION", "3 négatifs sur 4 et médiane négative : régression")
check(L.verdict([1, 2, 0.5, -4])[0] == "GAIN", "3 positifs sur 4 : gain")
check(L.verdict([-1, -2, 3, 4])[0] == "INDISTINCT", "2 contre 2 : indistinct")
check(L.verdict([-1, -1, 0, 5])[0] == "INDISTINCT", "un zéro ne compte pas : 2 négatifs seulement")
check(L.verdict([None, None])[0] == "SANS DONNEE", "aucun écart apparié")
check(L.verdict([-1, -2, -3])[0] == "INDISTINCT" or L.verdict([-1, -2, -3])[0] == "REGRESSION", "3 graines : défini")
check(L.verdict([5, 6, 7, -1], lower_is_better=True)[0] == "REGRESSION", "plus court = mieux : 3 écarts positifs = plus long = régression")
check(L.verdict([-5, -6, -7, 1], lower_is_better=True)[0] == "GAIN", "plus court = mieux : 3 écarts négatifs = gain")
base = {"forces": {"azure": {60: {"morte": False, "ind": {}}}, "player": {60: {"morte": False, "ind": {}}}}}
lot = {"forces": {"azure": {60: {"morte": True, "ind": {}}}}}
check(L.deaths(base, lot, 60) == ["azure", "player"], "force morte ou absente dans le lot : alerte")
print("BILAN : %d OK, %d ECHEC(S)" % (ok, fail))
sys.exit(0 if fail == 0 else 1)
