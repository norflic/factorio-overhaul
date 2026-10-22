"""Pièce du pipeline : mitrailleuse, lot V3-E « une DA par époque », époques 1 à 9 (ères I, II, III), 22/10/2026.

Lignée retenue par le Directeur Créatif : « industriel lourd » (gun_s_industriel, commit 265574d). Ce dossier
(gun_e_bas) en est une copie : corps inchangé, canons, tuyaux, accents, foyers et pièces de signature par époque
(design.py, parts4.py ; catalogue fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md).

Variantes (format de tools/render/README.md : PIECE + build(S, C, variant)) :
  e01-piece           niveau 2 : pièce posée sur la mitrailleuse vanilla (niveau 1 inchangé) ;
  eNN-socle           base_picture du niveau impair 2N-1 (N = 2 à 9) ;
  eNN-piece           pièce du niveau pair 2N (couche ajoutée au socle, coins avant) ;
  eNN-tete-N|E        tête (pose « prepared »), canons au nord ou à l'est.
Emprises (Q-S1, shared/levels/config.lua L.footprints.gun) : époques 1 à 3 en 2×2, 4 à 6 en 3×3, 7 à 9 en 4×4.

Chaîne (depuis la racine du worktree ; Python 3.9 pour numpy ; sorties hors dépôt dans FO_IND_WORK, par défaut
<racine>/fo-logs/2026-10-22_V3E/bas) :
    py -3.9 .../gun_e_bas/lots.py --cache C --out O --samples 128 --per 4   # paquets, verrou de rendu, purge .npy
    py -3.9 .../gun_e_bas/rendre.py --only e02-socle,... --samples 128      # une session (lots.py l'appelle)
    py -3.9 .../gun_e_bas/trous.py O --diag D --json J        # contrôle BLOQUANT des trous enfermés (code 1)
    py -3.9 .../gun_e_bas/mesure_e.py O mesures.json --prev P # charte tools/da, poses E et N, pièces paires
    py -3.9 .../gun_e_bas/prog_e.py <tools/da> <docs/da/mesures_vanilla.json> mesures.json D  # progression.py
    py -3.9 .../gun_e_bas/planches_e.py O <planches>          # planches (a) à (d)
    py -3.9 .../gun_e_bas/vignettes_e.py O <vignettes>        # test à l'aveugle (correspondance sur stdout)
    py -3.9 .../gun_e_bas/voir.py O <dossier> <préfixe>       # aperçus de travail au zoom 2
mesure.py, planche.py, prog.py et naif.py sont ceux de la lignée (niveaux 11, 21, 29, 30) : non utilisés ici.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DIRS = {"N": 0.0, "E": -math.pi / 2}
EPOCHS = tuple(range(2, 10))
SIDE = {1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4}


def level_odd(e):
    return 2 * e - 1


def _variants():
    v = {"e01-piece": {"epoch": 1, "part": "piece", "level": 2}}
    for e in EPOCHS:
        v["e%02d-socle" % e] = {"epoch": e, "part": "socle", "level": level_odd(e)}
        v["e%02d-piece" % e] = {"epoch": e, "part": "piece", "level": level_odd(e) + 1}
        for d in DIRS:
            v["e%02d-tete-%s" % (e, d)] = {"epoch": e, "part": "tete", "dir": d, "level": level_odd(e)}
    for name, meta in v.items():
        meta["dest"] = "levels/gun_e_bas/" + name
        meta["anchor_tiles"] = (0.0, 0.0)
        meta["side"] = SIDE[meta["epoch"]]
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
    if v["part"] == "socle":
        g = K.Geo(S, C, M, "s%02d" % e, 0.0, seed=100 + e)
        D.socle(g, e)
    elif v["part"] == "piece":
        g = K.Geo(S, C, M, "p%02d" % e, 0.0, seed=300 + e)
        D.piece(g, e)
    else:
        g = K.Geo(S, C, M, "t%02d" % e, DIRS[v["dir"]], seed=200 + e)
        D.tete(g, e)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
