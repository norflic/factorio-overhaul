"""O par pose et attribution du sommet des masses à une pièce, à partir de la géométrie exportée (Python système).

    python tools/render/pieces/levels/gun/pose_o.py [--geo <dossier npz>] [--only 3,7,9] [--top 3]

Pourquoi (reprise 4, 22/10, vérification adverse : majeur 1) : « O jamais décroissant » n'était vrai que pour le
MAXIMUM sur les 4 poses ; pose par pose, la tourelle rapetissait d'une époque à l'autre (époque 3 en pose N :
O = 0,55 contre 0,94 à l'époque 2). Pour régler la géométrie, il faut savoir QUELLE pièce porte le sommet des
masses dans chaque pose : un élément dorsal (cheminée, bulbe, tour) monte en pose S (l'arrière de la tête est au
nord), un élément frontal en pose N, un élément latéral gauche en pose E (y' = -x), droit en pose O (y' = +x).

Méthode : pour chaque tête (pose N exportée par geo_export.py, avec l'indice d'objet de chaque triangle), rotation
exacte autour de Z (geo.rotate), rastérisation (geo.raster), masque alpha ≥ 0,5 ; union avec le socle (silhouette
« dry » de l'époque) ; masses = ouverture horizontale de 10 px (d1lib.opening_h, définition de O de la bible §1.4) ;
sommet d'une pièce = plus haute ligne où les masses recouvrent la rastérisation de cette pièce seule.
Simulation (--zg e:valeur,...) : translation verticale de tout ce qui est au-dessus du plateau tournant, le fût
s'étirant (sommets au-dessus de la coupe déplacés) : O dépend alors linéairement de zg (0,707 tuile par unité).
"""
import argparse
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import d1lib as D  # noqa: E402
import geo  # noqa: E402
import gun as G  # noqa: E402

GEO0 = os.path.join(D.MOD_ROOT, "tools", "render", "cache", "levels-gun", "geo")


def load(geo_dir, e):
    z = np.load(os.path.join(geo_dir, "e%02d-tete-N.npz" % e))
    obj = z["obj"] if "obj" in z.files else np.zeros(len(z["tris"]), np.int32)
    names = [str(n) for n in z["names"]] if "names" in z.files else ["?"]
    return z["tris"].astype(np.float64), obj, names


def socle_mask(e):
    lv = 2 * e - 1
    return D.main_alpha(D.level_layers(lv, "N", "dry"), ("socle",)) >= 0.5


def per_pose(tris, obj, names, e, top_n=3):
    out = {}
    sm = socle_mask(e)
    for pose in D.POSES:
        t = geo.rotate(tris, geo.DIR_ANGLE[pose])
        m = (geo.raster(t, ss=2) >= 0.5) | sm
        op = D.opening_h(m)
        rows = np.nonzero(op.any(1))[0]
        O = (D.OY - rows.min()) / D.PPT - 1.0
        # attribution : sommet des masses par pièce (nom sans numéro)
        tops = {}
        for i in np.unique(obj):
            sel = obj == i
            mi = geo.raster(t[sel], ss=2) >= 0.25
            r = np.nonzero((op & mi).any(1))[0]
            if len(r):
                base = names[i].split("_")[1] if "_" in names[i] else names[i]
                v = (D.OY - r.min()) / D.PPT - 1.0
                tops[base] = max(tops.get(base, -9), v)
        best = sorted(tops.items(), key=lambda kv: -kv[1])[:top_n]
        out[pose] = {"O": round(O, 3), "sommet": [(k, round(v, 3)) for k, v in best]}
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--geo", default=GEO0)
    ap.add_argument("--only", default="")
    ap.add_argument("--top", type=int, default=3)
    a = ap.parse_args()
    eps = [int(x) for x in a.only.split(",") if x] or list(range(2, 16))
    P = G.load_params()
    for e in eps:
        tris, obj, names = load(a.geo, e)
        r = per_pose(tris, obj, names, e, a.top)
        print("e%02d zg=%.3f cible O %.2f" % (e, P["zg"][e], G.O_TARGET[e]))
        for pose in D.POSES:
            print("   %s O=%.2f  %s" % (pose, r[pose]["O"], ", ".join("%s %.2f" % kv for kv in r[pose]["sommet"])))


if __name__ == "__main__":
    main()
