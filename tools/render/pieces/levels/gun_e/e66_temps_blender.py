"""Lot A1, correcteur (23/10) : E66, TEMPS de l'ombre à 32 contre 128 échantillons, DOS À DOS dans UNE session Blender.

Lancé UNIQUEMENT par e66_temps.py (qui tient les DEUX places du verrou de rendu : aucun autre rendu pendant la mesure) :
    blender -b --factory-startup -noaudio --python-exit-code 1 -P e66_temps_blender.py -- --names e02-tete-N,…
        --out DIR [--reps 3]

Pour chaque variante : la scène est construite UNE fois, exactement comme batch_blender.py (même construction, même
cadrage, mêmes réglages de rendu : fo_scene.setup_render, sans échantillonnage adaptatif ni débruitage), puis chaque
passe est rendue SEULE par fo_scene.render_passes(…, [passe], …) avec scene.cycles.samples posé avant l'appel. C'est
le rendu « ombre seule à 32 » que ferait le réglage d'échantillons par passe (D-7), chronométré pour de vrai.
1. Chauffe : main, shadow, glow à 4 échantillons (compilation des noyaux et des nuanciers ; non comptée).
2. --reps répétitions, ordre alterné (dérive de charge compensée) :
     impaire : shadow 32, shadow 128, main 128, glow 128, shadow 1
     paire   : shadow 128, shadow 32, glow 128, main 128, shadow 1
   « shadow 1 » mesure le coût fixe d'un rendu (synchronisation de la scène, BVH, écriture du PNG).
Sortie : une ligne « [E66-T] variante rep passe échantillons secondes sha256-des-pixels » par rendu ; à la répétition 1,
les passes d'ombre 32 et 128 sont aussi gardées en .npy (<out>/<variante>/shadow-32.npy, shadow-128.npy) et
<out>/<variante>/cadre.json (canevas, origine) pour la preuve d'identité faite par e66_temps.py.
"""
import argparse
import hashlib
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
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402


def projected_bounds(objs):
    """Copie exacte de batch_blender.projected_bounds (batch_blender.py lance main() à l'import : pas d'import)."""
    from mathutils import Vector
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


def sha(p):
    """sha256 des PIXELS (float32 lus par Blender), pas du fichier : Blender écrit dans le PNG des métadonnées (durée
    du rendu…) qui changent d'un rendu à l'autre (constaté au premier passage du 23/10, 17 h 07)."""
    img = bpy.data.images.load(p, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return hashlib.sha256(buf.tobytes()).hexdigest()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--reps", type=int, default=3)
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    spec = importlib.util.spec_from_file_location("gune_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    for name in [n for n in a.names.split(",") if n]:
        meta = piece.PIECE["variants"][name]
        assert meta["part"] == "tete", name
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        scene = bpy.context.scene
        piece.build(S, C, name)
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
        S.setup_render(scene, W, H, samples=128)
        S.setup_camera(scene, W, H, center_px=(ox, oy))
        S.setup_world(scene)
        sun = S.add_sun(scene)
        S.add_fill(scene)
        ground = S.add_ground(scene)
        d = os.path.join(a.out, name)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "cadre.json"), "w", encoding="utf-8") as f:
            json.dump({"variant": name, "canvas": [W, H], "origin_px": [ox, oy],
                       "seed": scene.cycles.seed, "blender": bpy.app.version_string,
                       "adaptive": bool(scene.cycles.use_adaptive_sampling),
                       "denoising": bool(scene.cycles.use_denoising), "threads": scene.render.threads}, f, indent=1)

        def un_rendu(layer, samples, tag):
            scene.cycles.samples = samples
            sub = os.path.join(d, tag)
            os.makedirs(sub, exist_ok=True)
            t0 = time.perf_counter()
            res = S.render_passes(scene, sub, name, [layer], sun, ground)
            dt = time.perf_counter() - t0
            p = res.get(layer)
            h = sha(p) if p else "-"
            return dt, p, h

        for layer in ("main", "shadow", "glow"):
            dt, p, h = un_rendu(layer, 4, "chauffe")
            print("[E66-CHAUFFE] %s %s 4 %.2f" % (name, layer, dt), flush=True)
            if p:
                os.remove(p)
        for rep in range(1, a.reps + 1):
            if rep % 2:
                seq = [("shadow", 32), ("shadow", 128), ("main", 128), ("glow", 128), ("shadow", 1)]
            else:
                seq = [("shadow", 128), ("shadow", 32), ("glow", 128), ("main", 128), ("shadow", 1)]
            for layer, samples in seq:
                dt, p, h = un_rendu(layer, samples, "rep%d" % rep)
                print("[E66-T] %s %d %s %d %.3f %s %s" % (name, rep, layer, samples, dt, h,
                                                          time.strftime("%H:%M:%S")), flush=True)
                if p:
                    if rep == 1 and layer == "shadow" and samples in (32, 128):
                        to_npy(p, os.path.join(d, "shadow-%d.npy" % samples))
                    os.remove(p)
        S.reset()


main()
