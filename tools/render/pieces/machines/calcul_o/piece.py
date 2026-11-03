"""Pièce du pipeline : les MACHINES DU CALCUL (lot CALCUL-DESIGN, 01/11). Une variante par machine ; chacune modelée à part
(modules m_*.py), organes et matières partagés. Format de tools/render/README.md (PIECE + build(S, C, variant)). PHASE :
phase d'animation (0 à 1), lue par les organes mobiles (batch_blender --images).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# nom : (prototype, âge, côté, module)
MACHINES = {
    "centre": ("fo-data-center", 10, 4, "m_centres"), "grand_centre": ("fo-data-center-2", 12, 6, "m_centres"),
    "litho": ("fo-crystal-lithograph", 10, 4, "m_fab"), "salle": ("fo-cleanroom", 10, 5, "m_fab"),
    "tireuse": ("fo-crystal-puller", 10, 3, "m_fab"), "scie": ("fo-wire-saw", 10, 3, "m_fab"),
    "graveur": ("fo-plasma-etcher", 10, 3, "m_fab"), "testeur": ("fo-die-prober", 10, 3, "m_fab2"),
    "boitier": ("fo-packaging-line", 10, 3, "m_fab2"), "cms": ("fo-smt-line", 10, 4, "m_fab2"),
    "fibre": ("fo-fiber-tower", 10, 3, "m_fab2"), "integ": ("fo-rack-integrator", 10, 4, "m_fab2"),
    "froid": ("fo-chiller", 10, 4, "m_froid"), "tour": ("fo-cooling-tower", 10, 5, "m_froid"),
    "cryo": ("fo-cryogenic-unit", 12, 5, "m_froid"), "dilution": ("fo-dilution-fridge", 13, 3, "m_quant"),
    "qlab": ("fo-quantum-lab", 13, 5, "m_quant"), "impr": ("fo-circuit-printer", 4, 3, "m_amont"),
    "fritt": ("fo-sintering-furnace", 5, 3, "m_amont"), "arc": ("fo-arc-furnace", 6, 4, "m_amont"),
}
PIECE = {"name": "calc", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True},
         "variants": {n: {"epoch": v[1], "side": v[2], "dest": "machines/calcul/" + n, "anchor_tiles": (0.0, 0.0)} for n, v in MACHINES.items()}}
PHASE = 0.0
# Machines à pièces mobiles rendues en images (batch_blender --images) ; fond opaque derrière la pièce, sinon fantôme.
ANIMES = ("centre", "froid", "tour", "salle", "fritt", "impr", "scie", "testeur", "boitier", "cms", "fibre", "litho")


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    import organes as O
    mod = importlib.import_module(MACHINES[variant][3])
    lot, mob = geo.Lot(S, "calc_" + variant), geo.Lot(S, "mob_" + variant)
    k = O.Kit(lot, None, seed=sum(ord(c) for c in variant), phase=PHASE, lot_mobile=mob)
    getattr(mod, variant)(S, k)
    n = lot.n + mob.n
    lot.flush()
    mob.flush()
    return {"count": {"pieces": n}, "halos": 0}
