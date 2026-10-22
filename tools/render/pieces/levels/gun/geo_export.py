"""Export de la géométrie (triangles en coordonnées monde) des variantes de la famille gun, dans UNE session
Blender, SANS rendu : sert aux silhouettes exactes (geo.py), au balayage de la tête sur 64 directions (zone
du socle toujours visible, F46 recalculé par époque) et au réglage des hauteurs (tune.py).

S'exécute dans Blender, TOUJOURS par le verrou de rendu (interdit n° 6) :

    python tools/render/with_render_lock.py -- "C:/Users/evan2/tools/blender-5.2.2/blender.exe" -b \
        --factory-startup -noaudio -P tools/render/pieces/levels/gun/geo_export.py -- --out <dossier> [--only a,b]

Sortie : <out>/<variante>.npz : tris (n, 3, 3) float32 en unités Blender (repère de l'entité, modificateurs
appliqués), emis (n,) bool (face d'un matériau émissif), halos (k, 3) positions des sources de halo, obj (n,)
int32 (indice de l'objet de chaque triangle) et names (noms des objets, « t_canon_012 ») : attribution du sommet
de silhouette à une pièce (pose_o.py, reprise 4).
Les têtes ne sont exportées qu'en pose N (canons vers +Y) : les autres directions sont des rotations exactes
autour de Z (gun.py, K.rotate), refaites par geo.py.
"""
import argparse
import importlib.util
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402


def export(path):
    dg = bpy.context.evaluated_depsgraph_get()
    tris, emis, objid, names = [], [], [], []
    for o in S.piece_objects():
        if o.type != "MESH":
            continue
        oe = o.evaluated_get(dg)
        me = oe.to_mesh()
        me.calc_loop_triangles()
        n = len(me.loop_triangles)
        if n:
            co = np.empty(len(me.vertices) * 3, np.float64)
            me.vertices.foreach_get("co", co)
            co = co.reshape(-1, 3)
            vi = np.empty(n * 3, np.int64)
            me.loop_triangles.foreach_get("vertices", vi)
            vi = vi.reshape(-1, 3)
            mi = np.empty(n, np.int64)
            me.loop_triangles.foreach_get("material_index", mi)
            mw = np.array(oe.matrix_world)
            wco = co @ mw[:3, :3].T + mw[:3, 3]
            tris.append(wco[vi].astype(np.float32))
            objid.append(np.full(n, len(names), np.int32))
            names.append(o.name)
            flags = [bool(s.material is not None and s.material.get("fo_kind") == "emissive") for s in o.material_slots]
            fl = np.array(flags or [False])
            emis.append(fl[np.clip(mi, 0, len(fl) - 1)])
        oe.to_mesh_clear()
    halos = np.array([tuple(h.location) for h in S.HALO_LIGHTS], np.float32).reshape(-1, 3)
    np.savez_compressed(path, tris=np.concatenate(tris) if tris else np.zeros((0, 3, 3), np.float32),
                        emis=np.concatenate(emis) if emis else np.zeros(0, bool), halos=halos,
                        obj=np.concatenate(objid) if objid else np.zeros(0, np.int32), names=np.array(names or [""]))
    return sum(len(t) for t in tris)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", default="")
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    spec = importlib.util.spec_from_file_location("gun_piece", os.path.join(HERE, "gun.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    allv = piece.PIECE["variants"]
    names = [n for n in a.only.split(",") if n] or sorted(n for n, v in allv.items()
                                                          if v["part"] != "tete" or v["dir"] == "N")
    os.makedirs(a.out, exist_ok=True)
    for name in names:
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        piece.build(S, C, name)
        bpy.context.view_layer.update()
        n = export(os.path.join(a.out, "%s.npz" % name))
        print("[FO-GEO] %s %d triangles" % (name, n), flush=True)


main()
