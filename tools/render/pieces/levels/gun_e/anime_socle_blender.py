"""SOCLE ÉMISSIF ANIMÉ (lot A4, 24/10/2026) : rendu Blender des passes LUEUR et HALO d'un socle, image par image.
Lancé par anime_socle.py, TOUJOURS par le verrou de rendu (CLAUDE.md §4 n° 6) :
    python tools/render/with_render_lock.py -- blender -b --factory-startup -noaudio --python-exit-code 1
        -P tools/render/pieces/levels/gun_e/anime_socle_blender.py -- --name e06-socle --out <cache> --images 16
        [--samples 128] [--samples-alpha 16]

Scène, caméra, cadrage, matières : EXACTEMENT ceux de batch_blender.py (fichier gelé, non modifié ; mêmes appels dans le
même ordre : piece.build, projected_bounds, piece.margin_px, setup_render, setup_camera, setup_world, add_sun,
add_fill, add_ground) : même canevas et même origine que le socle validé (contrôlé par anime_socle.py contre le
spec.json validé). Puis :
  1. passe principale à --samples-alpha échantillons (seul son ALPHA sert : la fenêtre du halo du post-traitement ;
     l'alpha ne dépend pas des matières, F141) ;
  2. commun/anim_emission.installer : force d'émission × m(x, y, t) dans chaque matière émissive ; pour chaque image
     k = 0 … N−1 (t = k / N) : sources du halo × m à leur position, passes « glow » et « light » de fo_scene.render_passes
     (inchangé), en .npy.
render.json : canevas, origine, échantillons, durées, nombre de matières animées et de sources de halo.
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

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import anim_emission as AE  # noqa: E402

# mêmes fonctions de cadrage et de conversion que batch_blender.py (copiées : batch_blender exécute main() à l'import)
from mathutils import Vector  # noqa: E402


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
    ap.add_argument("--name", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--images", type=int, default=AE.IMAGES)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--samples-alpha", type=int, default=16)
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    spec = importlib.util.spec_from_file_location("gune_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    name = a.name
    meta = piece.PIECE["variants"][name]
    age = meta["epoch"]
    if meta["part"] != "socle" or age not in AE.ANIM:
        raise SystemExit("%s : pas un socle d'un âge animé (%s)" % (name, sorted(AE.ANIM)))
    t0 = time.time()
    S.reset()
    S.HALO_LIGHTS.clear()
    S.EXTRA_LIGHTS.clear()
    S._BLACK = S._WHITE = S._AO = None
    S._BOOSTED.clear()
    scene = bpy.context.scene
    info_build = piece.build(S, C, name)
    bpy.context.view_layer.update()
    objs = S.piece_objects()
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
    # 1. alpha de la couche principale (échantillons réduits)
    t1 = time.time()
    scene.cycles.samples = a.samples_alpha
    res = S.render_passes(scene, d, "%s-alpha" % name, ["main"], sun, ground)
    for k, path in res.items():
        to_npy(path, path[:-4] + ".npy")
        os.remove(path)
    scene.cycles.samples = a.samples
    t_alpha = time.time() - t1
    # 2. animation
    pose_t, n_mat = AE.installer(bpy, age, C.COS_T)
    halos = [(o, o.data.energy, o.location.x, -o.location.y * C.COS_T) for o in S.HALO_LIGHTS]
    durees = []
    for k in range(a.images):
        t = k / float(a.images)
        pose_t(t)
        for o, e0, hx, hy in halos:
            o.data.energy = e0 * AE.facteur(age, hx, hy, t)
        t2 = time.time()
        res = S.render_passes(scene, d, "%s-f%02d" % (name, k), ["glow", "light"], sun, ground)
        for kk, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        durees.append(round(time.time() - t2, 2))
        print("[FO-ANIME] %s image %d/%d (t = %.4f) : %s en %.1f s" % (name, k + 1, a.images, t, sorted(res),
                                                                      durees[-1]), flush=True)
    info = {"variant": name, "age": age, "canvas": [W, H], "origin_px": [ox, oy], "images": a.images,
            "samples": a.samples, "samples_alpha": a.samples_alpha, "seed": scene.cycles.seed,
            "blender": bpy.app.version_string, "secondes": round(time.time() - t0, 2),
            "secondes_alpha": round(t_alpha, 2), "secondes_images": durees, "matieres_animees": n_mat,
            "sources_halo": len(halos), "halos_build": info_build["halos"], "anim": AE.ANIM[age]}
    with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, sort_keys=True)
    print("[FO-ANIME] %s %dx%d : %d matières animées, %d sources de halo, %.1f s" % (
        name, W, H, n_mat, len(halos), time.time() - t0), flush=True)


main()
