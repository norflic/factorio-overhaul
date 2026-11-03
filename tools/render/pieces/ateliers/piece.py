"""Pièce du pipeline : les BÂTIMENTS D'ATELIER « à part » (lot DA-ATELIERS, 3/11) : concasseur, broyeur à mâchoires, bobineuse,
torchère, taillerie. Un seul design par bâtiment, sans lien avec l'âge (retour du DC, BRIEF_DA) ; phase 2 : trois variantes
(a, b, c) par bâtiment. Géométrie, organes et matières : copies du kit calcul_o (worktree calcul-design), pour rester cohérent
avec la chaîne du calcul. Format de tools/render/README.md (PIECE + build(S, C, variant)). Vue unique, façade au SUD.
PHASE : phase d'animation (0 à 1), lue par les organes mobiles (batch_blender --images).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# bâtiment : (prototype, côté, module, fonction)
BATIMENTS = {
    "concasseur": ("fo-crusher", 2, "m_concasseur", "concasseur"),
    "machoires": ("fo-jaw-crusher", 3, "m_machoires", "machoires"),
    "bobineuse": ("fo-coil-winder", 2, "m_bobineuse", "bobineuse"),
    "torchere": ("fo-flare-stack", 2, "m_torchere", "torchere"),
    "taillerie": ("fo-lapidary", 3, "m_taillerie", "taillerie"),
}
VARIANTES = ("a", "b", "c")
MACHINES = {"%s_%s" % (b, v): (p[0], 0, p[1], p[2], p[3], v) for b, p in BATIMENTS.items() for v in VARIANTES}
PIECE = {"name": "at", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True},
         "variants": {n: {"epoch": 0, "side": v[2], "dest": "machines/ateliers/" + n, "anchor_tiles": (0.0, 0.0)}
                      for n, v in MACHINES.items()}}
PHASE = 0.0
ANIMES = ()


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    import organes as O
    proto, _, side, modname, fn, v = MACHINES[variant]
    mod = importlib.import_module(modname)
    lot, mob, flam = geo.Lot(S, "at_" + variant), geo.Lot(S, "mob_" + variant), geo.Lot(S, "flam_" + variant)
    k = O.Kit(lot, None, seed=sum(ord(c) for c in variant), phase=PHASE, lot_mobile=mob)
    k.lot_flamme = flam
    getattr(mod, fn)(S, k, v)
    n = lot.n + mob.n + flam.n
    lot.flush()
    mob.flush()
    flam.flush()
    return {"count": {"pieces": n}, "halos": 0}
