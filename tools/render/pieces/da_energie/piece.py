"""Pièce du pipeline : les 5 BÂTIMENTS D'ÉNERGIE, DE NUCLÉAIRE ET DE GÉOLOGIE (lot DA-ENERGIE, 3-4/11). Un design par
bâtiment, sans lien avec l'âge ; phase 2 : 3 variantes (a, b, c) par bâtiment. Format de tools/render/README.md
(PIECE + build(S, C, variant)). Infrastructure (geo, organes, mat, palettes, batch_blender) recopiée du kit calcul_o
(worktree calcul-design, non commité) pour rester cohérent avec la chaîne du calcul : palette et vocabulaire de formes.
PHASE : phase d'animation (0 à 1), lue par les organes mobiles. DIR : direction de pose (capteur géothermique, raccord).

Convention de vue : une vue, sortie et raccords au SUD (comme les usines de robots) ; le capteur géothermique (foreuse
orientable à sortie de fluide) est rendu en direction « south » (sortie en (-1, 2)) pour la planche.
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# bâtiment : (prototype, âge, côté, module, sprite vanilla remplacé)
BATIMENTS = {
    "piscine": ("fo-cooling-pool", 9, 4, "m_piscine", "assembleur2"),
    "depot": ("fo-geological-repository", 9, 6, "m_depot", "coffre_acier"),
    "msr": ("fo-molten-salt-reactor", 12, 5, "m_msr", "reacteur"),
    "geo": ("fo-geothermal-tap", 5, 3, "m_geo", "chevalet"),
    "reso": ("fo-resonance-amplifier", 7, 3, "m_reso", "balise"),
}
VARIANTES = ("a", "b", "c")
MACHINES = {"%s_%s" % (b, v): (p[0], p[1], p[2], p[3]) for b, p in BATIMENTS.items() for v in VARIANTES}
PIECE = {"name": "den", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True},
         "variants": {n: {"epoch": m[1], "side": m[2], "dest": "da/energie/" + n, "anchor_tiles": (0.0, 0.0)}
                      for n, m in MACHINES.items()}}
PHASE = 0.0
DIR = "south"
# Pièces mobiles rendues en images (batch_blender --images) : phase 3.
ANIMES = tuple(n for n in MACHINES if n.split("_")[0] in ("piscine", "geo", "reso"))


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    import organes as O
    bat, v = variant.split("_")
    mod = importlib.import_module(MACHINES[variant][3])
    lot, mob = geo.Lot(S, "den_" + variant), geo.Lot(S, "mob_" + variant)
    k = O.Kit(lot, None, seed=sum(ord(c) for c in variant), phase=PHASE, lot_mobile=mob)
    k.dir = DIR
    getattr(mod, "v_" + v)(S, k)
    n = lot.n + mob.n
    lot.flush()
    mob.flush()
    return {"count": {"pieces": n}, "halos": 0}
