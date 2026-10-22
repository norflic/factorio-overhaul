"""Exécute progression.py de la charte (outils/progression.py, lu tel quel) sur la seule famille « mitrailleuse ».

Pourquoi un lanceur : progression.py boucle sur 4 familles (mitrailleuse, laser, assembleur, centre) et s'arrête sur
une famille absente (rows[0] d'une liste vide). On exécute EXACTEMENT son code, avec le tuple des familles réduit
à ("mitrailleuse",) ; aucun calcul n'est modifié.

    python ht_progression.py <progression_entree_E.json>
"""
import sys

CHARTE = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3S\charte\outils\progression.py"
src = open(CHARTE, encoding="utf-8").read()
old = 'for f in ("mitrailleuse", "laser", "assembleur", "centre"):'
assert src.count(old) == 1
src = src.replace(old, 'for f in ("mitrailleuse",):')
sys.argv = [CHARTE] + sys.argv[1:]
exec(compile(src, CHARTE, "exec"), {"__name__": "__main__"})
