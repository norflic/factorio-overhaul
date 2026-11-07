"""BOUCHE DU FAISCEAU de la tourelle laser (lot F1-C, 4/11) : point d'émission de chaque âge, lu sur la GÉOMÉTRIE de la
tête (aucun rendu). Script Blender, lancé par bouches.py, TOUJOURS par le verrou de rendu :

    python tools/render/with_render_lock.py -- blender -b --factory-startup -noaudio --python-exit-code 1 \
        -P tools/render/pieces/levels/laser_e/bouche_blender.py -- --out <bouches.json> [--ages 2,3]

Pour chaque âge 2 à 15 : la tête eNN-tete-d00 (faisceau au nord, rotation nulle) est construite par piece.build (mêmes
fichiers que le rendu). La BOUCHE est le CENTRE de la pièce d'où sort le faisceau, nommée par son « what » (premier
présent de MARQUEURS) : le foyer de tir de corps.lentille (âges 2 à 6, 8 à 11, 13), le foyer de la pointe du prisme
(âge 7), la pupille de l'iris de la Porte (âge 14, dans l'anneau penché), la lentille de l'horizon (âge 15), la
lentille miroir (âge 12) ; quand la pièce a plusieurs exemplaires (pupilles des deux faces de la Porte), le plus avancé
(+Y). Contrôle croisé (sortie « axe ») : point le plus avancé de la géométrie proche de l'axe de l'émetteur (x = 0,
z = zh de corps.Ctx, tube de rayon TOL_AXE × re). Unités Blender (1 unité en X = 1 tuile).
"""
import argparse
import importlib.util
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402

TOL_AXE = 0.12      # rayon du tube autour de l'axe de l'émetteur, en fraction de re
MARQUEURS = ("foyer_tir", "foyer", "pupille", "lentille", "lentille_miroir")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--ages", default="2-15")
    a = ap.parse_args(argv)
    if "-" in a.ages:
        lo, hi = a.ages.split("-")
        ages = list(range(int(lo), int(hi) + 1))
    else:
        ages = [int(x) for x in a.ages.split(",") if x]
    spec = importlib.util.spec_from_file_location("lase_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    import corps
    import kit
    from mathutils import Vector
    ctxs = []
    pieces = []
    init0 = corps.Ctx.__init__
    add0 = kit.Geo._add

    def init_note(self, *args, **kw):
        init0(self, *args, **kw)
        ctxs.append(self)

    def add_note(self, mat, style, verts, faces, what="part"):
        if what in MARQUEURS:
            m = self.stack[-1]
            pieces.append((what, [tuple(m @ Vector(v)) for v in verts]))
        return add0(self, mat, style, verts, faces, what)

    corps.Ctx.__init__ = init_note
    kit.Geo._add = add_note
    res = {}
    for e in ages:
        name = "e%02d-tete-d00" % e
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        del ctxs[:]
        del pieces[:]
        piece.build(S, C, name)
        bpy.context.view_layer.update()
        c = ctxs[-1]
        marque = next((w for w in MARQUEURS if any(p[0] == w for p in pieces)), None)
        if marque is None:
            raise SystemExit("[FO-BOUCHE] %s : aucune pièce %s" % (name, "/".join(MARQUEURS)))
        inst = max((p[1] for p in pieces if p[0] == marque), key=lambda vs: max(v[1] for v in vs))
        cx = sum(v[0] for v in inst) / len(inst)
        cy = sum(v[1] for v in inst) / len(inst)
        cz = sum(v[2] for v in inst) / len(inst)
        zh, re_ = float(c.zh), float(c.re)
        tol = TOL_AXE * re_
        best = None
        n = 0
        for o in S.piece_objects():
            if o.type != "MESH":
                continue
            mw = o.matrix_world
            for v in o.data.vertices:
                w = mw @ v.co
                if abs(w.x) <= tol and abs(w.z - zh) <= tol:
                    n += 1
                    if best is None or w.y > best[0]:
                        best = (float(w.y), float(w.z), o.name)
        if best is None:
            raise SystemExit("[FO-BOUCHE] %s : aucun sommet sur l'axe de l'émetteur (x = 0, z = %.3f)" % (name, zh))
        res[str(e)] = {"marque": marque, "x_bouche": round(cx, 5), "y_bouche": round(cy, 5), "z_bouche": round(cz, 5),
                       "z_axe": round(zh, 5), "re": round(re_, 5),
                       "axe": {"y": round(best[0], 5), "z": round(best[1], 5), "sommets": n, "objet": best[2],
                               "tol": round(tol, 5)}}
        print("[FO-BOUCHE] âge %2d : %s centre (%.3f, %.3f, %.3f) ; axe %.3f (re %.3f) ; contrôle par l'axe : y %.3f "
              "z %.3f (%d sommets, %s)" % (e, marque, cx, cy, cz, zh, re_, best[0], best[1], n, best[2]), flush=True)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1, sort_keys=True)


main()
