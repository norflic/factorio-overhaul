"""Rendu de plusieurs variantes du MUR (MUR-OPUS) dans UNE session Blender. TOUJOURS par le verrou (rendre.py).

Même scène, caméra et passes que tools/render/blender/render_piece.py (fo_scene.render_passes, fichiers partagés non
modifiés) ; passes de JOUR : main, ao, shadow, glow. Sortie : <out>/<variante>/<variante>-<passe>.npy et render.json.
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
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402


def projected_bounds(objs, sv=None):
    sv = sv or C.sun_vector()
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
    ap.add_argument("--samples", type=int, default=12)
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    spec = importlib.util.spec_from_file_location("mur_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for name in [n for n in a.names.split(",") if n]:
        t0 = time.time()
        layers = ["main", "ao", "shadow", "glow"]
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        for attr in ("_BLACK", "_WHITE", "_AO"):
            if hasattr(S, attr):
                setattr(S, attr, None)
        if hasattr(S, "_BOOSTED"):
            S._BOOSTED.clear()
        scene = bpy.context.scene
        info_build = piece.build(S, C, name)
        bpy.context.view_layer.update()
        objs = S.piece_objects()
        nverts = sum(len(o.data.vertices) for o in objs if o.type == "MESH")
        l, t, r, b = projected_bounds(objs)
        # v5b (C1, critique v4) : l'ombre du MUR seul est posée comme celle du mur vanilla (vers le sud-est à l'écran),
        # avec un second soleil propre à la passe d'ombre ; la passe principale garde l'éclairage étalonné (F47).
        osol = getattr(piece, "OMBRE_SOLEIL", None)
        if os.environ.get("FO_MUR_OMBRE"):          # essais d'étalonnage : « azimut,élévation »
            osol = tuple(float(v) for v in os.environ["FO_MUR_OMBRE"].split(","))
        if osol:
            ea, aa = math.radians(osol[1]), math.radians(osol[0])
            sv2 = (math.cos(ea) * math.sin(aa), math.cos(ea) * math.cos(aa), math.sin(ea))
            l2, t2, r2, b2 = projected_bounds(objs, sv2)
            l, t, r, b = min(l, l2), min(t, t2), max(r, r2), max(b, b2)
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
        if osol:
            res = S.render_passes(scene, d, name, [x for x in layers if x != "shadow"], sun, ground)
            sun2 = S.add_sun(scene, azimuth=osol[0], elev=osol[1], name="fo_sun_ombre")
            sun.hide_render = True
            res.update(S.render_passes(scene, d, name, ["shadow"], sun2, ground))
            sun2.hide_render = True
            sun.hide_render = False
        else:
            res = S.render_passes(scene, d, name, layers, sun, ground)
        t_render = time.time() - t1
        for k, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        info = {"variant": name, "canvas": [W, H], "origin_px": [ox, oy], "layers": sorted(res),
                "samples": scene.cycles.samples, "seed": scene.cycles.seed, "blender": bpy.app.version_string,
                "seconds": round(time.time() - t0, 2), "seconds_render": round(t_render, 2), "verts": nverts,
                "objects": len(objs), "count": info_build["count"]}
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-RENDER] %s %dx%d %d sommets rendu %.1fs" % (name, W, H, nverts, t_render), flush=True)


main()
