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

PIECE = {"name": "met", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True},
         "variants": {"%s_%s" % (m, v): {"epoch": 0, "side": MACHINES[m][1], "dest": "metallurgie/" + m, "anchor_tiles": (0.0, 0.0)}
                      for m in MACHINES for v in VARIANTES}}


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
