"""Pièce du pipeline V0 : famille « mitrailleuse » (clé gun), 30 niveaux, lot V3 phase 1.

Fichier de pièce au format de tools/render/README.md (PIECE + build(S, C, variant)), lu par
tools/render/blender/render_piece.py (dans Blender) et par les scripts de ce dossier (Python système :
ce module n'importe ni bpy ni gun_kit au niveau supérieur).

Variantes (une variante = une pose = un rendu Blender, 5 passes) :
  e01-piece-avant, e01-piece-flancs   pièce du niveau 2 (sacs de sable) posée sur le socle VANILLA ;
                                      « flancs » est masquée au pixel par l'alpha du socle vanilla
                                      (méthode de la variante « four » de V0), « avant » ne l'est pas
                                      (elle passe devant le socle) ;
  eNN-socle                           socle (base_picture) du niveau impair 2e-1, e = 2..15 ;
  eNN-socle-piece                     socle + pièce du niveau pair 2e, rendus ensemble (1 pose : liseré
                                      et ombres de contact exacts entre pièce et socle) ;
  eNN-tete-N|E|S|O                    tête en position « prepared », 4 directions de référence.
Le niveau 1 est le sprite vanilla (Q11) : aucune variante.

Réglages par époque (params.json, écrit par tune.py) : zg = hauteur de l'axe des canons (suit
l'enveloppe O de la bible §4), gain = gain d'albédo (luminance médiane du corps, bible §1.5).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

DIRS = {"N": 0.0, "E": -math.pi / 2, "S": math.pi, "O": math.pi / 2}
EPOCHS = list(range(1, 16))
# bible §4, colonne Mitrailleuse : O (dépassement au-dessus du bord haut de l'emprise) et L (largeur)
O_TARGET = {1: 0.84, 2: 0.95, 3: 1.06, 4: 1.17, 5: 1.29, 6: 1.40, 7: 1.51, 8: 1.62, 9: 1.73, 10: 1.84,
            11: 1.95, 12: 2.07, 13: 2.18, 14: 2.29, 15: 2.40}
L_TARGET = {1: 1.95, 2: 1.97, 3: 1.99, 4: 2.00, 5: 2.02, 6: 2.04, 7: 2.06, 8: 2.08, 9: 2.09, 10: 2.11,
            11: 2.13, 12: 2.15, 13: 2.16, 14: 2.18, 15: 2.20}
V_TARGET = {10: 3, 11: 7, 12: 10, 13: 13, 14: 17, 15: 20}          # vide minimal (% du masque niveau 1)
O_PLAFOND, L_MAX = 2.40, 2.20
# dessus du socle (z de la couronne), doit correspondre à gun_kit.socle()
SOCLE_TOP = {2: 0.32, 3: 0.34, 4: 0.28, 5: 0.36, 6: 0.28, 7: 0.33, 8: 0.30, 9: 0.28, 10: 0.41, 11: 0.45,
             12: 0.30, 13: 0.51, 14: 0.35, 15: 0.35}
EMIT_HEX = {3: "#FFC060", 4: "#FF8C1A", 5: "#FF4A10", 6: "#60D0FF", 7: "#B070FF", 8: "#A8FF3A", 9: "#5CFF4A",
            10: "#3AA8FF", 11: "#BFE6FF", 12: "#4AF0FF", 13: "#FF4FD8", 14: "#FF2A2A", 15: "#FFF2C0"}

VANILLA_BASE_MASK = {
    "hr": {"file": "gun-turret/hr-gun-turret-base.png", "shift": (0.015625, -0.03125)},
    "lr": {"file": "gun-turret/gun-turret-base.png", "shift": (0.03125, -0.03125)},
}


def load_params():
    p = {"zg": {}, "gain": {}}
    path = os.path.join(HERE, "params.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            raw = json.load(f)
        for k in ("zg", "gain"):
            p[k] = {int(e): float(v) for e, v in raw.get(k, {}).items()}
    for e in EPOCHS:
        p["zg"].setdefault(e, (O_TARGET[e] + 1.0) / math.sqrt(0.5) - 1.45)
        p["gain"].setdefault(e, 1.9)
    return p


def level_variants(level):
    """Variantes qui composent un niveau (1..30), dans l'ordre de dessin : socle puis tête."""
    e = (level + 1) // 2
    if level == 1:
        return None
    if level == 2:
        return {"socle": ["e01-piece-flancs", "e01-piece-avant"], "tete": None}
    s = "e%02d-socle-piece" % e if level % 2 == 0 else "e%02d-socle" % e
    return {"socle": [s], "tete": {d: "e%02d-tete-%s" % (e, d) for d in DIRS}}


def _variants():
    v = {
        "e01-piece-avant": {"epoch": 1, "part": "piece-avant", "level": 2},
        "e01-piece-flancs": {"epoch": 1, "part": "piece-flancs", "level": 2, "mask": VANILLA_BASE_MASK},
    }
    for e in EPOCHS[1:]:
        v["e%02d-socle" % e] = {"epoch": e, "part": "socle", "level": 2 * e - 1}
        v["e%02d-socle-piece" % e] = {"epoch": e, "part": "socle-piece", "level": 2 * e}
        for d in DIRS:
            v["e%02d-tete-%s" % (e, d)] = {"epoch": e, "part": "tete", "dir": d, "level": 2 * e - 1}
    for name, meta in v.items():
        meta["dest"] = "levels/gun/" + name
        meta["anchor_tiles"] = (0.0, 0.0)
    return v


PIECE = {
    "name": "gun",
    "variants": _variants(),
    "margin_px": 40,
}


def build(S, C, variant):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import gun_kit as G
    v = PIECE["variants"][variant]
    e, part = v["epoch"], v["part"]
    P = load_params()
    M = G.materials(S, e, P["gain"][e])
    if part.startswith("piece-"):
        k = G.K(S, C, "p")
        G.piece_e01(k, M, part.split("-", 1)[1])
        return k
    if part in ("socle", "socle-piece"):
        k = G.K(S, C, "s")
        z0 = G.socle(k, e, M)
        assert abs(z0 - SOCLE_TOP[e]) < 1e-9, (e, z0)
        if part == "socle-piece":
            kp = G.K(S, C, "pp")
            G.piece(kp, e, M)
        return k
    import gun_heads as GH
    k = G.K(S, C, "t")
    GH.head(k, e, M, SOCLE_TOP[e], P["zg"][e])
    k.rotate(DIRS[v["dir"]])
    return k
