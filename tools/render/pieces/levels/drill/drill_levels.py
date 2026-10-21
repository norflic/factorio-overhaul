"""Pièce « niveaux de la foreuse électrique » (lot V3, phase 1) au format des pièces du pipeline V0.

Variantes « LNN-D » : niveau NN (2 à 30), direction D (N, E, S, W), pose de référence image 0.
- Niveau 1 = sprite vanilla inchangé (Q11) : aucune variante.
- Niveau 2 = chevalement en bois seul (pièce invariante, rendue une fois : « L02-N »), posé sur le sprite
  vanilla et masqué au pixel par l'alpha vanilla de chaque direction (comme la variante « four » de V0).
- Niveaux 3 à 30 = modèles complets de epoques.py.
Le module n'importe bpy qu'à la construction : le Python système peut lire PIECE (render.py, mesures).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS = list(range(2, 31))
DIRS = ("N", "E", "S", "W")


def parse_variant(v):
    lvl, d = v.split("-")
    return int(lvl[1:]), d


def _variants():
    out = {}
    for lvl in LEVELS:
        for d in DIRS:
            if lvl == 2 and d != "N":
                continue
            out["L%02d-%s" % (lvl, d)] = {"dest": "levels/drill/e%02d" % ((lvl + 1) // 2), "anchor_tiles": (0.0, 0.0),
                                          "level": lvl, "dir": d}
    return out


PIECE = {
    "name": "drill",
    "variants": _variants(),
    "margin_px": 64,
}


def build(S, C, variant):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import kit
    import epoques
    lvl, d = parse_variant(variant)
    ctx = kit.Ctx(S, C, d)
    epoques.build_level(ctx, lvl)
