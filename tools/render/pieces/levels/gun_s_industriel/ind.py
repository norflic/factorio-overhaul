"""Pièce du pipeline : mitrailleuse, exploration de style « INDUSTRIEL LOURD » (lot V3-S, 22/10/2026).

Approche : chaque époque est une machine de guerre plus lourde, plus blindée, plus mécanique, dans le
vocabulaire vanilla (plaques rivetées, tuyaux, engrenages, câbles, bandes de danger, usure) ; la haute
technologie se lit par des éléments lumineux LOCALISÉS et des mécanismes plus nombreux, jamais par des formes
lisses. Le corps garde la palette de la cheminée V0 validée (tôle brune rouillée, laiton, crasse) à toutes les
époques ; la couleur d'époque ne vit que dans les foyers lumineux (charte DA_FACTORIO §6.4).

Niveaux témoins (charte §6.2) : 11 (époque 6, 3×3), 21 (époque 11, 5×5), 29 (époque 15, 6×6), 30 (29 + pièce).
Variantes : eNN-socle (base_picture), e15-socle-piece (niveau 30), eNN-tete-N|E (tête, pose « prepared »).
Format de tools/render/README.md (PIECE + build(S, C, variant)) ; rendu par rendre.py (verrou de rendu).

Reprise du 22/10 après-midi (2e explorateur) : forme refaite (design.py, parts2.py, parts3.py), voir la tête de
design.py. Chaîne complète, depuis la racine du worktree (Python 3.9 : numpy manque au Python 3.14 du PC depuis
le 22/10 ; sorties hors dépôt dans FO_IND_WORK, par défaut <racine>/fo-logs/2026-10-22_V3S/industriel) :
    py -3.9 tools/render/pieces/levels/gun_s_industriel/rendre.py --samples 128      # 10 variantes, verrou
    py -3.9 .../mesure.py <outils charte> <sortie.json> --pose E|N                    # 23 planchers + cibles
    py -3.9 .../planche.py <racine>/data <dumps> <outils charte> <dossier> --pose E|N   # planches z1/z2 jour/nuit
    py -3.9 .../prog.py <outils charte> <mesures_vanilla.json> <mesures E> <dossier>   # dominance 1-11-21-29-30
    py -3.9 .../naif.py <racine>/data <dumps> <outils charte> <dossier>               # paires A/B, clé à l'écran
Essais rapides : rendre.py --quick --samples 16 (passes main, glow, shadow ; pas de liseré de contact, donc
masse et remplissage sous-estimés d'environ 10 % par rapport au rendu complet).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DIRS = {"N": 0.0, "E": -math.pi / 2}
EPOCHS = (6, 11, 15)
LEVEL = {6: 11, 11: 21, 15: 29}
SIDE = {6: 3, 11: 5, 15: 6}


def _variants():
    v = {}
    for e in EPOCHS:
        v["e%02d-socle" % e] = {"epoch": e, "part": "socle", "level": LEVEL[e]}
        for d in DIRS:
            v["e%02d-tete-%s" % (e, d)] = {"epoch": e, "part": "tete", "dir": d, "level": LEVEL[e]}
    v["e15-socle-piece"] = {"epoch": 15, "part": "socle-piece", "level": 30}
    for name, meta in v.items():
        meta["dest"] = "levels/gun_s_industriel/" + name
        meta["anchor_tiles"] = (0.0, 0.0)
    return v


PIECE = {
    "name": "gunind",
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
