"""Pièce du pipeline : la famille MÉTALLURGIE (lot DA-METALLURGIE, 3/11), six bâtiments « à part », un design par fonction, sans
lien avec l'âge (CONCEPT : fo-logs/2026-11-04_DA-METALLURGIE/CONCEPT.md). Une variante par état clé : « <machine>_<a|b|c> ».
Géométrie, matières et outils : ceux du kit usines_robots (importés depuis son dossier, non copiés). Format de
tools/render/README.md (PIECE + build(S, C, variant)). Convention : produit et sortie au SUD.
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
USINES = os.path.join(os.path.dirname(HERE), "usines_robots")
for p in (USINES, HERE):
    if p in sys.path:
        sys.path.remove(p)
    sys.path.insert(0, p)
# HERE en tête : piece, commun et les modules des machines viennent d'ici ; geo, mat, outils du kit usines_robots.

# module : (prototype, côté de l'emprise, titre)
MACHINES = {
    "hf": ("fo-blast-furnace", 4, "Haut fourneau"),
    "co": ("fo-coke-oven", 3, "Four à coke"),
    "rc": ("fo-reduction-cell", 4, "Cuve d'électrolyse ignée"),
    "py": ("fo-ht-pylon", 2, "Pylône haute tension"),
    "kr": ("fo-kroll-reactor", 4, "Réacteur de Kroll"),
    "cc": ("fo-ore-concentrator", 2, "Concentrateur de minerai"),
}
VARIANTES = ("a", "b", "c")
MODULES = {"hf": "m_hf", "co": "m_co", "rc": "m_rc", "py": "m_py", "kr": "m_kr", "cc": "m_cc"}

# Étalonnage de la couche principale (rendre.etalonne, hors Blender, rejouable par --post-only) : « tp, tk, sp, g, ga, s » = pied
# (sous tp, puissance tk : noirs plus noirs), épaule (au-dessus de sp, pente g), gamma des tons moyens, saturation. Critique du 3/11 :
# écart-type 0,13 à 0,18 contre 0,20 à 0,24 en vanilla ; cibles p5 ≤ 0,04, p95 ≥ 0,65. Vide : aucun étalonnage (états clés du 3/11).
# Réglé le 3/11 vers 23 h 40 sur les rendus corrigés (mesure.py) : une courbe par machine, la cuve (aluminium vif) plus douce.
GRADE = {"hf": [0.22, 1.8, 0.28, 1.9, 1.0, 1.0], "co": [0.22, 1.8, 0.26, 2.1, 1.0, 1.0], "rc": [0.22, 1.8, 0.32, 1.5, 1.0, 1.1],
         "py": [0.26, 2.0, 0.28, 1.9, 1.0, 1.05], "kr": [0.22, 1.8, 0.28, 1.9, 1.0, 1.0], "cc": [0.22, 1.8, 0.3, 1.75, 1.0, 1.0]}
# Gain de la lueur par machine (émission linéaire : équivaut à baisser la force du matériau) ; petites lampes trop écrêtées.
GAIN_LUEUR = {"py": 0.55, "cc": 0.55, "kr": 0.42, "rc": 0.5}      # kr : −40 % demandé par la contre-relecture (4/11)
PIECE = {"name": "met", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True},
         "variants": {"%s_%s" % (m, v): {"epoch": 0, "side": MACHINES[m][1], "dest": "metallurgie/" + m, "anchor_tiles": (0.0, 0.0)}
                      for m in MACHINES for v in VARIANTES}}
# pylône : tête tournée pour les directions 1 à 3 du moteur (la direction 0 est « py_c »)
for _d in (1, 2, 3):
    PIECE["variants"]["py_c%d" % _d] = dict(PIECE["variants"]["py_c"])


def margin_px(name):
    return 40


def split(name):
    m, v = name.split("_")
    return m, v


def build(S, C, variant):
    import geo
    m, v = split(variant)
    mod = importlib.import_module(MODULES[m])
    lot = geo.Lot(S, "met_" + variant)
    info = mod.build(S, lot, v) or {}
    n = lot.n
    lot.flush()
    return {"count": {"pieces": n}, "halos": 0, "info": info}
