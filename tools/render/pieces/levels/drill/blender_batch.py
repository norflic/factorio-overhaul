"""Point d'entrée Blender À PLUSIEURS POSES (lot V3, famille drill) : rend une liste de variantes d'une
pièce dans UN SEUL processus Blender (le démarrage de Blender et le chargement coûtent plusieurs secondes,
×116 poses pour la foreuse).

    blender -b --factory-startup -noaudio -P blender_batch.py -- --piece <fichier> --out <dossier>
            --variants L03-N,L03-E,... [--samples N] [--layers main,ao,shadow,glow,light] [--margin px]

Reprend À L'IDENTIQUE la logique de tools/render/blender/render_piece.py (cadrage, caméra, monde, soleil,
appoint, sol, passes fo_scene.render_passes) : ce fichier n'en est qu'une boucle. render_piece.py n'est
pas importable (il s'exécute à l'import) et les fichiers partagés du pipeline ne sont pas modifiés (lot V0b
en parallèle). Différence : les globales de fo_scene (listes de lumières, matériaux en cache) sont remises
à zéro entre deux poses, et les PNG 16 bits sont supprimés après conversion en .npy (disque H: limité).
"""
import argparse
import importlib.util
import json
import math
import os
import sys
import time

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
for p in (RENDER, os.path.join(RENDER, "blender"), HERE):
    if p not in sys.path:
        sys.path.insert(0, p)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--piece", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--variants", required=True)
    ap.add_argument("--samples", type=int, default=None)
    ap.add_argument("--layers", default="main,ao,shadow,glow,light")
    ap.add_argument("--margin", type=int, default=64)
    return ap.parse_args(argv)


def load_piece(path):
    spec = importlib.util.spec_from_file_location("fo_piece_src", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def projected_bounds(objs):
    """Copie de render_piece.projected_bounds : boîte écran (px HR) des objets et de leurs ombres."""
    sv = C.sun_vector()
    us, vs = [], []
    for o in objs:
        if o.type != "MESH":
            continue
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            u, v = C.blender_to_screen_px(w.x, w.y, w.z)
            us.append(u)
            vs.append(v)
            if w.z > 0 and sv[2] > 1e-6:
                k = w.z / sv[2]
                gx, gy = w.x - sv[0] * k, w.y - sv[1] * k
                u, v = C.blender_to_screen_px(gx, gy, 0.0)
                us.append(u)
                vs.append(v)
    return min(us), min(vs), max(us), max(vs)


def to_npy(png_path, npy_path):
    """Copie de render_piece.to_npy : valeurs exactes du PNG 16 bits en float32 (H, W, 4)."""
    import numpy as np
    img = bpy.data.images.load(png_path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    arr = np.flipud(buf.reshape(h, w, 4))
    np.save(npy_path, arr)
    bpy.data.images.remove(img)


def reset_globals():
    S.HALO_LIGHTS.clear()
    S.EXTRA_LIGHTS.clear()
    S._BLACK = None
    S._WHITE = None
    S._AO = None
    S._BOOSTED.clear()


def render_one(piece, variant, a):
    t0 = time.time()
    scene = S.reset()
    reset_globals()
    piece.build(S, C, variant)
    bpy.context.view_layer.update()
    objs = S.piece_objects()
    l, t, r, b = projected_bounds(objs)
    m = a.margin
    left, top = int(math.floor(l)) - m, int(math.floor(t)) - m
    right, bottom = int(math.ceil(r)) + m, int(math.ceil(b)) + m
    W, H = right - left, bottom - top
    W += W % 2
    H += H % 2
    ox, oy = -left, -top
    S.setup_render(scene, W, H, samples=a.samples)
    S.setup_camera(scene, W, H, center_px=(ox, oy))
    S.setup_world(scene)
    sun = S.add_sun(scene)
    S.add_fill(scene)
    ground = S.add_ground(scene)
    prefix = "%s-%s" % (piece.PIECE["name"], variant)
    halos = []
    for hl in S.HALO_LIGHTS:
        p = hl.location
        u, v = C.blender_to_screen_px(p.x, p.y, p.z)
        ug, vg = C.blender_to_screen_px(p.x, p.y, 0.0)
        halos.append({"px": [u, v], "ground_px": [ug, vg], "z": p.z, "watts": hl.data.energy})
    t_build = time.time() - t0
    layers = [x for x in a.layers.split(",") if x]
    res = S.render_passes(scene, a.out, prefix, layers, sun, ground)
    for k, path in res.items():
        to_npy(path, path[:-4] + ".npy")
        os.remove(path)
    n_obj = len([o for o in objs if o.type == "MESH"])
    info = {
        "piece": piece.PIECE["name"], "variant": variant, "canvas": [W, H], "origin_px": [ox, oy],
        "px_per_tile": C.PX_PER_UNIT_HR, "layers": sorted(res), "halos": halos, "objects": n_obj,
        "blender": bpy.app.version_string,
        "blender_hash": bpy.app.build_hash.decode() if isinstance(bpy.app.build_hash, bytes) else str(bpy.app.build_hash),
        "samples": scene.cycles.samples, "seed": scene.cycles.seed, "threads": scene.render.threads,
        "seconds_build": round(t_build, 2), "seconds": round(time.time() - t0, 2),
    }
    with open(os.path.join(a.out, "%s-render.json" % prefix), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, sort_keys=True)
    print("[FO-RENDER] %s %dx%d origine=(%d,%d) objets=%d %.1fs" % (prefix, W, H, ox, oy, n_obj, time.time() - t0),
          flush=True)


def main():
    a = parse()
    a.out = os.path.abspath(a.out)
    os.makedirs(a.out, exist_ok=True)
    piece = load_piece(os.path.abspath(a.piece))
    for v in [x for x in a.variants.split(",") if x]:
        render_one(piece, v, a)


main()
