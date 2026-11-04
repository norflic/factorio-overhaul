"""Pièce du pipeline : LES ROBOTS (lots RB-V0, RB-V1). Format de tools/render/README.md (PIECE + build(S, C, variant)).
Variantes : <robot>-pose (à l'arrêt), <robot>-mNN (image NN du cycle de marche), <robot>-gros (pose à plus forte définition).
Série (lot RB-V1) : <robot>-dKK-mNN (direction KK, image NN), <robot>-dKK-tir (à l'arrêt) ; passe en plus « mask », teinte du propriétaire.
Géant : <robot>-tKK (torse, direction KK sur 16 pour ce premier passage, 1/11), <robot>-p-haut, -p-bas, -p-genou (pièces de pattes, communes aux pattes).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# ro : identifiant dans shared/content/robots.lua ; images : planche de marche (lot RB-V0) ; serie : (directions, images, tuiles par cycle en jeu),
# géant : torse = nombre de directions ; grade : étalonnage (FO_GRADE : tp,tk,sp,g,ga,s)
G0 = (0.001, 1.0, 0.42, 1.5, 1.1, 1.14)
ROBOTS = {
    "trotte": dict(ro="steam-trotter", age=3, graine=3003, images=8, gros=192.0, grade=G0, serie=(16, 8, 1.0)),
    "levite": dict(ro="levite", age=12, graine=1212, images=6, gros=None, grade=(0.001, 1.0, 0.42, 1.55, 1.12, 1.08), serie=(16, 6, 1.6)),
    "couronne": dict(ro="crowned", age=15, graine=1515, images=4, gros=None, grade=(0.001, 1.0, 0.5, 1.4, 1.1, 1.14), torse=16),
    # premier passage, 1/11 : 8 directions, 4 images, torse à 16 directions : le PC est chargé (120 à 200 s par image) et il faut toute la gamme ; repasser à (16, 6) PC libre, --reprise
    # lot RB16 (4/11, QCM du DC « 16 pour les plus vus seulement ») : 16 directions, mêmes 4 images ; les directions paires sont les 8 rendus du
    # 1/11 (θ = 2πk/n : direction k sur 8 = 2k sur 16), copiés dans fo-logs/2026-11-04_RB16 ; les impaires y sont rendues (`lot`, à GARDER)
    "ecaille": dict(ro="scalehide", age=5, graine=505, images=0, gros=None, grade=(0.001, 1.0, 0.4, 1.8, 1.05, 1.1), serie=(16, 4, 0.9), lot="2026-11-04_RB16"),
    "bobineur": dict(ro="coiler", age=6, graine=606, images=0, gros=None, grade=G0, serie=(16, 4, 1.0), lot="2026-11-04_RB16"),
    "aiguille": dict(ro="needle", age=7, graine=707, images=0, gros=None, grade=G0, serie=(8, 4, 1.3)),
    "cloche": dict(ro="bellwether", age=8, graine=808, images=0, gros=None, grade=(0.001, 1.0, 0.35, 2.0, 1.08, 1.14), serie=(8, 4, 0.86)),
    "chanfrein": dict(ro="chamfer", age=9, graine=909, images=0, gros=None, grade=G0, serie=(8, 4, 0.86)),
    "truelle": dict(ro="trowel", age=10, graine=1010, images=0, gros=None, grade=(0.001, 1.0, 0.5, 1.4, 1.12, 1.1), serie=(8, 4, 1.1)),
    "aileron": dict(ro="finback", age=11, graine=1111, images=0, gros=None, grade=(0.001, 1.0, 0.5, 1.4, 1.12, 1.1), serie=(8, 4, 2.2)),
    "torique": dict(ro="toroid", age=13, graine=1313, images=0, gros=None, grade=(0.001, 1.0, 0.5, 1.4, 1.1, 1.14), torse=16),
    "heliaste": dict(ro="heliast", age=14, graine=1414, images=0, gros=None, grade=(0.001, 1.0, 0.5, 1.4, 1.1, 1.14), torse=16),
}


def _variantes():
    v = {}
    for nom, d in ROBOTS.items():
        base = {"epoch": d["age"], "robot": nom, "anchor_tiles": (0.0, 0.0), "side": 2, "dest": "robots/" + nom, "grade": d["grade"]}
        v[nom + "-pose"] = dict(base, phase=None)
        if d.get("gros"):
            v[nom + "-gros"] = dict(base, phase=None, ppu=d["gros"])
        for i in range(d["images"]):
            v["%s-m%02d" % (nom, i)] = dict(base, phase=i / float(d["images"]), image=i)
        if d.get("serie"):
            nd, ni, dt = d["serie"]
            for k in range(nd):
                for i in range(ni):
                    v["%s-d%02d-m%02d" % (nom, k, i)] = dict(base, phase=i / float(ni), image=i, direction=(k, nd, dt), serie=True)
                v["%s-d%02d-tir" % (nom, k)] = dict(base, phase=None, direction=(k, nd, dt), serie=True)
        if d.get("torse"):
            for k in range(d["torse"]):
                v["%s-t%02d" % (nom, k)] = dict(base, torse=(k, d["torse"]), serie=True)
            for p in ("haut", "bas", "genou"):
                v["%s-p-%s" % (nom, p)] = dict(base, piece=p, serie=False)
    return v


PIECE = {"name": "rb", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True}, "variants": _variantes()}


def lot(nom):
    """Dossier de fo-logs qui garde les sources de rendu d'un robot (lot RB-V1 par défaut, RB16 pour les robots repassés à 16 directions)."""
    return ROBOTS[nom].get("lot", "2026-11-01_RBV1")


def noms_serie(nom):
    """Variantes de la série d'un robot, dans l'ordre de rendu (une image de chaque direction d'abord : un défaut se voit vite)."""
    d = ROBOTS[nom]
    if d.get("serie"):
        nd, ni, _ = d["serie"]
        ni_ = list(range(ni))
        return ["%s-d%02d-tir" % (nom, k) for k in range(nd)] + ["%s-d%02d-m%02d" % (nom, k, i) for k in range(nd) for i in ni_]
    return ["%s-p-%s" % (nom, p) for p in ("haut", "bas", "genou")] + ["%s-t%02d" % (nom, k) for k in range(d["torse"])]


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    import marionette as Mr
    meta = PIECE["variants"][variant]
    mod = importlib.import_module(meta["robot"])
    M = mod.matieres(S)
    lots = Mr.Lots(S, "rb_" + variant, geo.Lot)
    r = geo.Rnd(ROBOTS[meta["robot"]]["graine"])
    if "piece" in meta:
        sq = Mr.Squelette()
        sq.os("piece", None, Mr.tr(0.0, 0.0, Mr.Z_PIECE) if meta["piece"] == "genou" else Mr.repere_ecran(Mr.Z_PIECE))
        mod.modele_piece(lots("piece"), M, meta["piece"])
    elif "torse" in meta:
        k, nd = meta["torse"]
        sq = mod.squelette_torse(Mr.direction_jeu(k, nd, 1.0)[0])
        mod.modele(lots, M, r, torse=True)
    else:
        if "direction" in meta:
            cap, pas = Mr.direction_jeu(*meta["direction"])
            sq = mod.squelette(meta["phase"], cap, pas / getattr(mod, "ECH", 1.0))
        else:
            sq = mod.squelette(meta["phase"])
        mod.modele(lots, M, r)
    n = lots.n
    Mr.incarner(sq, lots)
    return {"count": {"pieces": n}, "halos": 0, "info": {}}
