"""Rendu de variantes de la SALLE BLANCHE dans UNE session Blender (lot CALC-SALLE-BLANCHE, 30/10). Adapté de
levels/assembleur_e/batch_blender.py (même scène, caméra, cadrage et passes ; fichiers partagés NON modifiés), sans
têtes ni options D-7. TOUJOURS par le verrou de rendu (lancé par rendre.py) :
    python tools/render/with_render_lock.py -- blender -b --factory-startup -noaudio -P <ce fichier> -- --names s1,s2
        --out <cache> --samples 12 [--apercu]
--apercu : passes de jour (main, ao, shadow, glow) ; sinon toutes (light comprise : halo de nuit, V0b).
Sortie : <out>/<variante>/<variante>-<passe>.npy et render.json (canevas, origine, durées, comptes, VOYANTS).
"""
import argparse
import importlib.util
import json
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..", "levels", "commun")))
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402


def projected_bounds(objs):
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
                u, v = C.blender_to_screen_px(w.x - sv[0] * k, w.y - sv[1] * k, 0.0)
                us.append(u)
                vs.append(v)
    return min(us), min(vs), max(us), max(vs)


def to_npy(png_path, npy_path):
    img = bpy.data.images.load(png_path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    np.save(npy_path, np.flipud(buf.reshape(h, w, 4)))
    bpy.data.images.remove(img)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--apercu", action="store_true")
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    spec = importlib.util.spec_from_file_location("sb_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    for name in [n for n in a.names.split(",") if n]:
        t0 = time.time()
        layers = ["main", "ao", "shadow", "glow"] if a.apercu else ["main", "ao", "shadow", "glow", "light"]
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        scene = bpy.context.scene
        info_build = piece.build(S, C, name)
        t_build = time.time() - t0
        bpy.context.view_layer.update()
        objs = S.piece_objects()
        nverts = sum(len(o.data.vertices) for o in objs if o.type == "MESH")
        l, t, r, b = projected_bounds(objs)
        m = piece.margin_px(name)
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
        d = os.path.join(a.out, name)
        os.makedirs(d, exist_ok=True)
        t1 = time.time()
        res = S.render_passes(scene, d, name, layers, sun, ground)
        t_render = time.time() - t1
        for k, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        info = {"variant": name, "canvas": [W, H], "origin_px": [ox, oy], "layers": sorted(res),
                "samples": scene.cycles.samples, "seed": scene.cycles.seed, "blender": bpy.app.version_string,
                "seconds": round(time.time() - t0, 2), "seconds_build": round(t_build, 2),
                "seconds_render": round(t_render, 2), "verts": nverts, "objects": len(objs),
                "count": info_build["count"], "halos": info_build["halos"], "leds": info_build["leds"],
                "apercu": a.apercu, "light_holdout": bool(getattr(C, "LIGHT_HOLDOUT", False))}
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-RENDER] %s %dx%d %d sommets build %.1fs rendu %.1fs" % (name, W, H, nverts, t_build, t_render),
              flush=True)


main()
