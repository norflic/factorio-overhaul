"""Pièce du pipeline : les MACHINES DE CHIMIE à fluides (lot DA-CHIMIE, 3/11). Une variante par machine ET par direction
(« craqueur_n », « craqueur_e »… : les raccords de fluides tournent avec la machine, repere.py) ; chaque machine est modelée
à part (m_*.py), organes (organes.py, copie de calcul_o) et matières (palette.py) partagés. Format de tools/render/README.md
(PIECE + build(S, C, variant)). PHASE : phase d'animation (0 à 1) lue par les pièces mobiles (batch_blender --images).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# nom : (prototype, âge, côté, module)
MACHINES = {
    "craqueur": ("fo-steam-cracker", 4, 3, "m_craqueur"),
    "reformeur": ("fo-reformer", 8, 3, "m_reformeur"),
    "electrolyseur": ("fo-electrolyzer", 8, 3, "m_electrolyseur"),
    "colonne": ("fo-extraction-column", 12, 3, "m_colonne"),
}
DIRS = ("n", "e", "s", "w")
PIECE = {"name": "chim", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True, "AO_DISTANCE": 0.14},
         "variants": {"%s_%s" % (n, d): {"epoch": v[1], "side": v[2], "dest": "machines/chimie/" + n, "anchor_tiles": (0.0, 0.0)}
                      for n, v in MACHINES.items() for d in DIRS}}
PHASE = 0.0
ANIMES = ()


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    import organes as O
    import palette
    import repere
    nom, d = variant.rsplit("_", 1)
    mod = importlib.import_module(MACHINES[nom][3])
    lot, mob = geo.Lot(S, "chim_" + variant), geo.Lot(S, "mob_" + variant)
    M = palette.matieres(S)
    k = O.Kit(lot, M, seed=sum(ord(c) for c in nom), phase=PHASE, lot_mobile=mob)
    R = repere.Rep(k, DIRS.index(d))
    mod.build(S, k, R)
    n = lot.n + mob.n
    lot.flush()
    mob.flush()
    return {"count": {"pieces": n}, "halos": 0}
