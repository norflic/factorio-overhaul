"""Point d'entrée Blender : rend une pièce décrite par un fichier source Python.

    blender -b --factory-startup -P tools/render/blender/render_piece.py -- \
        --piece tools/render/pieces/<piece>.py --out <dossier> [--variant <nom>] [--samples N]

Le fichier de pièce définit :
    PIECE = {"name": ..., "variants": {...}}      (métadonnées, lues aussi par le post-traitement)
    def build(S, C, variant): ...                 (S = fo_scene, C = fo_calib ; crée les objets)
Sortie : <out>/<prefix>-{main,ao,shadow,glow,light}.png (16 bits) et <out>/<prefix>-render.json
(taille du canevas, pixel de l'origine, réglages, versions).
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
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--piece", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--variant", default="default")
    ap.add_argument("--samples", type=int, default=None)
    ap.add_argument("--layers", default="main,ao,shadow,glow,light")
    ap.add_argument("--margin", type=int, default=24)
    ap.add_argument("--set", action="append", default=[], help="surcharge d'étalonnage NOM=valeur (essais)")
    return ap.parse_args(argv)


def load_piece(path):
    spec = importlib.util.spec_from_file_location("fo_piece_src", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def projected_bounds(objs):
    """Boîte écran (px HR, relatifs à l'origine) des objets et de leurs ombres au sol."""
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
            # ombre au sol du coin (projection selon la direction du soleil)
            if w.z > 0 and sv[2] > 1e-6:
                k = w.z / sv[2]
                gx, gy = w.x - sv[0] * k, w.y - sv[1] * k
                u, v = C.blender_to_screen_px(gx, gy, 0.0)
                us.append(u)
                vs.append(v)
    return min(us), min(vs), max(us), max(vs)


def to_npy(png_path, npy_path):
    """Valeurs EXACTES du PNG 16 bits (sRGB codé, alpha droit) en float32 (H, W, 4), haut en premier."""
    import numpy as np
    img = bpy.data.images.load(png_path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    arr = np.flipud(buf.reshape(h, w, 4))
    np.save(npy_path, arr)
    bpy.data.images.remove(img)


def main():
    a = parse()
    a.out = os.path.abspath(a.out)
    a.piece = os.path.abspath(a.piece)
    for kv in a.set:
        k, v = kv.split("=", 1)
        old = getattr(C, k)
        setattr(C, k, type(old)(eval(v)) if not isinstance(old, tuple) else tuple(eval(v)))
    C.recompute()
    t0 = time.time()
    piece = load_piece(a.piece)
    scene = S.reset()
    piece.build(S, C, a.variant)
    bpy.context.view_layer.update()
    objs = S.piece_objects()
    l, t, r, b = projected_bounds(objs)
    m = a.margin
    left, top = int(math.floor(l)) - m, int(math.floor(t)) - m
    right, bottom = int(math.ceil(r)) + m, int(math.ceil(b)) + m
    # canevas de dimensions paires ; origine (position de l'entité) au pixel (ox, oy), bord de pixel
    W = right - left
    H = bottom - top
    W += W % 2
    H += H % 2
    ox, oy = -left, -top
    S.setup_render(scene, W, H, samples=a.samples)
    S.setup_camera(scene, W, H, center_px=(ox, oy))
    S.setup_world(scene)
    sun = S.add_sun(scene)
    S.add_fill(scene)
    ground = S.add_ground(scene)
    prefix = "%s-%s" % (piece.PIECE["name"], a.variant)
    os.makedirs(a.out, exist_ok=True)
    layers = [x for x in a.layers.split(",") if x]
    res = S.render_passes(scene, a.out, prefix, layers, sun, ground)
    for k, path in res.items():
        to_npy(path, path[:-4] + ".npy")
    info = {
        "piece": piece.PIECE["name"],
        "variant": a.variant,
        "canvas": [W, H],
        "origin_px": [ox, oy],
        "px_per_tile": C.PX_PER_UNIT_HR,
        "layers": {k: os.path.basename(v) for k, v in res.items()},
        "blender": bpy.app.version_string,
        "blender_hash": bpy.app.build_hash.decode() if isinstance(bpy.app.build_hash, bytes) else str(bpy.app.build_hash),
        "samples": scene.cycles.samples,
        "seed": scene.cycles.seed,
        "threads": scene.render.threads,
        "calib": {k: getattr(C, k) for k in dir(C) if k.isupper()},
        "overrides": a.set,
        "seconds": round(time.time() - t0, 2),
    }
    with open(os.path.join(a.out, "%s-render.json" % prefix), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, sort_keys=True)
    print("[FO-RENDER] %s %dx%d origine=(%d,%d) %.1fs" % (prefix, W, H, ox, oy, time.time() - t0))


main()
