"""Pièce du pipeline : ÉTATS CLÉS DES ROBOTS (lot RB-V0, 31/10). Format de tools/render/README.md (PIECE + build(S, C, variant)).
Variantes : <robot>-pose (à l'arrêt), <robot>-mNN (image NN du cycle de marche), <robot>-gros (pose à plus forte définition).
Série (lot RB-V1) : <robot>-dKK-mNN (direction KK sur 16, image NN) et <robot>-dKK-tir (à l'arrêt) ; passe en plus « mask », teinte du propriétaire.
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# module, âge, graine du détail, images du cycle, px par tuile du gros plan, étalonnage (FO_GRADE : tp,tk,sp,g,ga,s)
# serie : (directions, images de marche, tuiles par cycle en jeu)
ROBOTS = {"trotte": dict(age=3, graine=3003, images=8, gros=192.0, grade=(0.001, 1.0, 0.42, 1.5, 1.1, 1.14), serie=(16, 8, 1.0)),
          "levite": dict(age=12, graine=1212, images=6, gros=None, grade=(0.001, 1.0, 0.42, 1.55, 1.12, 1.08)),
          "couronne": dict(age=15, graine=1515, images=4, gros=None, grade=(0.001, 1.0, 0.5, 1.4, 1.1, 1.14))}


def _variantes():
    v = {}
    for nom, d in ROBOTS.items():
        base = {"epoch": d["age"], "robot": nom, "anchor_tiles": (0.0, 0.0), "side": 2, "dest": "robots/" + nom, "grade": d["grade"]}
        v[nom + "-pose"] = dict(base, phase=None)
        if d["gros"]:
            v[nom + "-gros"] = dict(base, phase=None, ppu=d["gros"])
        for i in range(d["images"]):
            v["%s-m%02d" % (nom, i)] = dict(base, phase=i / float(d["images"]), image=i)
        if d.get("serie"):
            nd, ni, dt = d["serie"]
            for k in range(nd):
                for i in range(ni):
                    v["%s-d%02d-m%02d" % (nom, k, i)] = dict(base, phase=i / float(ni), image=i, direction=(k, nd, dt), serie=True)
                v["%s-d%02d-tir" % (nom, k)] = dict(base, phase=None, direction=(k, nd, dt), serie=True)
    return v


PIECE = {"name": "rb", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True}, "variants": _variantes()}


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    import marionette as Mr
    meta = PIECE["variants"][variant]
    mod = importlib.import_module(meta["robot"])
    M = mod.matieres(S)
    if "direction" in meta:
        import marionette as Mr_
        cap, pas = Mr_.direction_jeu(*meta["direction"])
        sq = mod.squelette(meta["phase"], cap, pas / getattr(mod, "ECH", 1.0))
    else:
        sq = mod.squelette(meta["phase"])
    lots = Mr.Lots(S, "rb_" + variant, geo.Lot)
    mod.modele(lots, M, geo.Rnd(ROBOTS[meta["robot"]]["graine"]))
    n = lots.n
    Mr.incarner(sq, lots)
    return {"count": {"pieces": n}, "halos": 0, "info": {}}
