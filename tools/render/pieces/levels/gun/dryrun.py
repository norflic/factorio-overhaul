"""Silhouettes rapides (alpha seul, 4 échantillons, sans rebond) de variantes de la famille gun, dans UNE
session Blender : sert au réglage des hauteurs (tune.py) avant les rendus d'aperçu. S'exécute dans Blender,
TOUJOURS par le verrou de rendu :

    python tools/render/with_render_lock.py -- "C:/Users/evan2/tools/blender-5.2.2/blender.exe" -b \
        --factory-startup -noaudio -P tools/render/pieces/levels/gun/dryrun.py -- --out <dossier> [--only a,b]

Sortie : <out>/<variante>-alpha.png (8 bits) et <out>/dryrun.json (taille du canevas, pixel de l'origine).
Même cadrage que tools/render/blender/render_piece.py (projected_bounds recopié ici, fichier partagé intact).
"""
import argparse
import importlib.util
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
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


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--margin", type=int, default=40)
    a = ap.parse_args(argv)
    # chemin ABSOLU obligatoire : Blender résout un chemin de rendu relatif depuis la racine du disque
    # (constaté le 21/10 : sortie écrite sous C:\tools\..., aussitôt supprimée)
    a.out = os.path.abspath(a.out)
    spec =importlib.util.spec_from_file_location("gun_piece", os.path.join(HERE, "gun.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    names = [n for n in a.only.split(",") if n] or sorted(piece.PIECE["variants"])
    os.makedirs(a.out, exist_ok=True)
    info = {}
    jp = os.path.join(a.out, "dryrun.json")
    if os.path.exists(jp):
        with open(jp, encoding="utf-8") as f:
            info = json.load(f)
    for name in names:
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
        m = a.margin
        left, top = int(math.floor(l)) - m, int(math.floor(t)) - m
        W, H = int(math.ceil(r)) + m - left, int(math.ceil(b)) + m - top
        W += W % 2
        H += H % 2
        S.setup_render(scene, W, H, samples=4)
        scene.cycles.max_bounces = 0
        scene.render.image_settings.color_depth = "8"
        S.setup_camera(scene, W, H, center_px=(-left, -top))
        S.setup_world(scene)
        p = os.path.join(a.out, "%s-alpha.png" % name)
        S.render_to(scene, p)
        info[name] = {"canvas": [W, H], "origin_px": [-left, -top]}
        print("[FO-DRYRUN] %s %dx%d" % (name, W, H), flush=True)
    with open(jp, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, sort_keys=True)


main()
