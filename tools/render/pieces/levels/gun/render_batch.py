"""Rendu d'APERÇU de plusieurs variantes de la famille gun dans UNE session Blender (lot V3 phase 1).

Même scène, même caméra, mêmes passes que tools/render/blender/render_piece.py (fichier partagé, NON modifié :
son cadrage et sa conversion en .npy sont recopiés ici), mais en boucle sur des variantes, avec un nombre
d'échantillons réduit, et des passes choisies par module :
  - socle (base_picture)  : main, ao, shadow, glow, light (halo de nuit : flaque au sol, ne tourne pas) ;
  - tête (pose prepared)  : main, shadow, glow (ni liseré de contact : la tête ne touche pas le sol, sinon
    une tache sombre se poserait sur le socle ; ni halo : la flaque est portée par le socle, F64).
TOUJOURS par le verrou de rendu (lancé par render_gun.py) :

    python tools/render/with_render_lock.py -- blender -b --factory-startup -noaudio \
        -P tools/render/pieces/levels/gun/render_batch.py -- --names a,b --out <cache> --samples 32
Sortie : <out>/<variante>/gun-<variante>-<passe>.npy (valeurs exactes des PNG 16 bits, comme render_piece)
et <out>/<variante>/render.json (canevas, origine, halos projetés, durées).
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


def projected_bounds(objs):
    """Recopie de render_piece.projected_bounds : boîte écran des objets et de leurs ombres au sol."""
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
    """Recopie de render_piece.to_npy : valeurs exactes du PNG 16 bits en float32 (H, W, 4)."""
    img = bpy.data.images.load(png_path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    np.save(npy_path, np.flipud(buf.reshape(h, w, 4)))
    bpy.data.images.remove(img)


def light_pass(scene, out_dir, prefix, sun, ground):
    """Passe halo, recopie de la branche « light » de fo_scene.render_passes, SANS la condition « la pièce a
    un matériau émissif » : le socle porte la source de halo de la tête (gun.py) même quand il n'a lui-même
    aucune surface lumineuse (époque 3, par exemple). Éclairage direct seul, sol blanc, pièce gris clair."""
    objs = S.piece_objects()
    bg = scene.world.node_tree.nodes["Background"]
    sky = bg.inputs["Strength"].default_value
    saved = S._swap_materials(objs, S._emissive_or_white)
    gsaved = S._swap_materials([ground], lambda m: S._white_mat())
    sun.hide_render = True
    for x in S.EXTRA_LIGHTS:
        x.hide_render = True
    bg.inputs["Strength"].default_value = 0.0
    ground.is_shadow_catcher = False
    ground.visible_camera = True
    for o in objs:
        o.visible_camera = True
    for x in S.HALO_LIGHTS:
        x.hide_render = False
    emit_objs = [o for o in objs if o.type == "MESH" and any(
        sl.material is not None and sl.material.get("fo_kind") == "emissive" for sl in o.material_slots)]
    for o in emit_objs:
        o.visible_diffuse = False
        o.visible_glossy = False
    cyc = scene.cycles
    bounces = (cyc.max_bounces, cyc.diffuse_bounces, cyc.glossy_bounces)
    cyc.max_bounces, cyc.diffuse_bounces, cyc.glossy_bounces = 0, 0, 0
    p = os.path.join(out_dir, "%s-light.png" % prefix)
    S.render_to(scene, p)
    cyc.max_bounces, cyc.diffuse_bounces, cyc.glossy_bounces = bounces
    for o in emit_objs:
        o.visible_diffuse = True
        o.visible_glossy = True
    for x in S.HALO_LIGHTS:
        x.hide_render = True
    S._restore(saved)
    S._restore(gsaved)
    sun.hide_render = False
    for x in S.EXTRA_LIGHTS:
        x.hide_render = False
    bg.inputs["Strength"].default_value = sky
    ground.visible_camera = False
    return p


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=32)
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    spec = importlib.util.spec_from_file_location("gun_piece", os.path.join(HERE, "gun.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for name in [n for n in a.names.split(",") if n]:
        t0 = time.time()
        meta = piece.PIECE["variants"][name]
        head = meta["part"] == "tete"
        layers = ["main", "shadow", "glow"] if head else ["main", "ao", "shadow", "glow"]
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
        S.setup_render(scene, W, H, samples=a.samples)
        S.setup_camera(scene, W, H, center_px=(ox, oy))
        S.setup_world(scene)
        sun = S.add_sun(scene)
        S.add_fill(scene)
        ground = S.add_ground(scene)
        d = os.path.join(a.out, name)
        os.makedirs(d, exist_ok=True)
        prefix = "gun-%s" % name
        res = S.render_passes(scene, d, prefix, layers, sun, ground)
        if not head and S.HALO_LIGHTS:
            res["light"] = light_pass(scene, d, prefix, sun, ground)
        for k, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        halos = []
        for hl in S.HALO_LIGHTS:
            x, y, z = hl.location
            halos.append({"xyz": [x, y, z], "px": list(C.blender_to_screen_px(x, y, z)),
                          "ground_px": list(C.blender_to_screen_px(x, y, 0.0))})
        info = {"variant": name, "canvas": [W, H], "origin_px": [ox, oy], "layers": sorted(res),
                "samples": scene.cycles.samples, "seed": scene.cycles.seed, "halos": halos,
                "blender": bpy.app.version_string, "seconds": round(time.time() - t0, 2)}
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-RENDER] %s %dx%d %.1fs" % (name, W, H, time.time() - t0), flush=True)


main()
