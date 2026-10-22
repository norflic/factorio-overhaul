"""Pièce du pipeline : mitrailleuse, lot V3-E, époques 10 à 15 (ères IV et V), DA par époque sur la lignée de
l'industriel lourd (gun_s_industriel, commit 265574d, retenue par le Directeur Créatif le 22/10 à 16 h 45).

Variantes (24) : eNN-socle (base_picture du niveau impair 2N-1), eNN-socle-piece (niveau pair 2N : socle + la
pièce du niveau pair, en paire aux coins avant), eNN-tete-N et eNN-tete-E (tête, pose « prepared »).
Format de tools/render/README.md (PIECE + build(S, C, variant)) ; rendu par rendre.py (verrou de rendu).

Chaîne, depuis la racine du worktree (Python 3.9 : numpy manque au Python 3.14 du PC) ; sorties hors dépôt dans
FO_IND_WORK, par défaut <racine>/fo-logs/2026-10-22_V3E/haut :
    py -3.9 tools/render/pieces/levels/gun_e_haut/rendre.py --only e10-socle,e10-tete-E --samples 128
    py -3.9 .../mesure.py <outils charte> <sortie.json> --pose E|N        # planchers, D3, trous, pièces isolées
    py -3.9 .../planche.py <racine>/data <dumps> <dossier> ...            # planches (a) à (d)
    py -3.9 .../prog.py <outils charte> <mesures E> <dossier>             # dominance époque par époque
    py -3.9 .../vignettes.py ...                                          # vignettes à l'aveugle
Essais rapides : rendre.py --quick --samples 16 (passes main, glow, shadow ; pas de liseré de contact).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DIRS = {"N": 0.0, "E": -math.pi / 2}
EPOCHS = (10, 11, 12, 13, 14, 15)
LEVEL = {e: 2 * e - 1 for e in EPOCHS}
SIDE = {10: 5, 11: 5, 12: 5, 13: 6, 14: 6, 15: 6}


def _variants():
    v = {}
    for e in EPOCHS:
        v["e%02d-socle" % e] = {"epoch": e, "part": "socle", "level": LEVEL[e]}
        v["e%02d-socle-piece" % e] = {"epoch": e, "part": "socle-piece", "level": LEVEL[e] + 1}
        for d in DIRS:
            v["e%02d-tete-%s" % (e, d)] = {"epoch": e, "part": "tete", "dir": d, "level": LEVEL[e]}
    for name, meta in v.items():
        meta["dest"] = "levels/gun_e_haut/" + name
        meta["anchor_tiles"] = (0.0, 0.0)
    return v


PIECE = {
    "name": "gune",
    "variants": _variants(),
    "margin_px": 40,
    "calib": {"LIGHT_HOLDOUT": True},
}


def margin_px(name):
    v = PIECE["variants"][name]
    if v["part"] != "tete":
        return 40 + int(64 * 1.3)
    return PIECE["margin_px"]


def build(S, C, variant):
    if HERE not in sys.path:
        sys.path.insert(0, HERE)
    import kit as K
    import design as D
    v = PIECE["variants"][variant]
    e = v["epoch"]
    M = K.materials(S, e)
    if v["part"] in ("socle", "socle-piece"):
        g = K.Geo(S, C, M, "s%02d" % e, 0.0, seed=100 + e)
        D.socle(g, e, piece=(v["part"] == "socle-piece"))
    else:
        g = K.Geo(S, C, M, "t%02d" % e, DIRS[v["dir"]], seed=200 + e)
        D.tete(g, e)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
