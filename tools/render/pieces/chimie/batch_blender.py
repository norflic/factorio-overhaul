"""Rendu des machines du kit CHIMIE (lot DA-CHIMIE, 3/11) dans UNE session Blender : copie de
calcul_o/batch_blender.py (lot CALCUL-DESIGN ; même scène, caméra, passes de fo_scene ; fichiers partagés NON modifiés),
seul le module de pièce change (chimie/piece.py). TOUJOURS par le verrou de rendu (lancé par rendre.py).
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
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
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


def to_npy(png_path, npy_path):
    img = bpy.data.images.load(png_path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    np.save(npy_path, np.flipud(buf.reshape(h, w, 4)))
    bpy.data.images.remove(img)


def bornes_mobiles(objs):
    us, vs = [], []
    for o in objs:
        if o.type == "MESH" and o.name.startswith("mob_"):
            for corner in o.bound_box:
                w = o.matrix_world @ Vector(corner)
                u, v = C.blender_to_screen_px(w.x, w.y, w.z)
                us.append(u)
                vs.append(v)
    return (min(us), min(vs), max(us), max(vs)) if us else None


def reconstruit(piece, name, phase):
    S.reset()
    S.HALO_LIGHTS.clear()
    S.EXTRA_LIGHTS.clear()
    S._BLACK = S._WHITE = S._AO = None
    S._BOOSTED.clear()
    piece.PHASE = phase
    piece.build(S, C, name)
    bpy.context.view_layer.update()
    return S.piece_objects()


def images_mobiles(piece, name, a, d, W, H, ox, oy):
    """Lot CALCUL-DESIGN : N images des seules pièces mobiles. Première passe : la boîte commune à toutes les phases, puis
    une passe principale limitée à cette boîte (use_border : temps de rendu proportionnel à sa surface). Sorties :
    <nom>-img<k>-main.npy (toile entière, alpha nul hors de la boîte) ; mobiles.json : boîte en pixels."""
    n = a.images
    us0, vs0, us1, vs1 = [], [], [], []
    for k in range(n):
        b = bornes_mobiles(reconstruit(piece, name, k / float(n)))
        if b:
            us0.append(b[0]); vs0.append(b[1]); us1.append(b[2]); vs1.append(b[3])
    if not us0:
        return
    x0, y0 = max(0, int(math.floor(min(us0))) + ox - 3), max(0, int(math.floor(min(vs0))) + oy - 3)
    x1, y1 = min(W, int(math.ceil(max(us1))) + ox + 3), min(H, int(math.ceil(max(vs1))) + oy + 3)
    for k in range(n):
        t0 = time.time()
        reconstruit(piece, name, k / float(n))
        scene = bpy.context.scene
        S.setup_render(scene, W, H, samples=a.samples)
        if os.environ.get("FO_DENOISE"):
            scene.cycles.use_denoising = True
            scene.cycles.denoiser = "OPENIMAGEDENOISE"
        S.setup_camera(scene, W, H, center_px=(ox, oy))
        S.setup_world(scene)
        sun = S.add_sun(scene)
        S.add_fill(scene)
        ground = S.add_ground(scene)
        scene.render.use_border = True
        scene.render.use_crop_to_border = False
        scene.render.border_min_x, scene.render.border_max_x = x0 / float(W), x1 / float(W)
        scene.render.border_min_y, scene.render.border_max_y = 1.0 - y1 / float(H), 1.0 - y0 / float(H)
        res = S.render_passes(scene, d, "%s-img%02d" % (name, k), ["main"], sun, ground)
        scene.render.use_border = False
        for _, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        print("[FO-RENDER] %s image %d/%d, boite %dx%d, %.1fs" % (name, k + 1, n, x1 - x0, y1 - y0, time.time() - t0), flush=True)
    piece.PHASE = 0.0
    with open(os.path.join(d, "mobiles.json"), "w", encoding="utf-8") as f:
        json.dump({"images": n, "boite": [x0, y0, x1, y1]}, f)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--apercu", action="store_true")
    ap.add_argument("--images", type=int, default=0, help="lot CALCUL-DESIGN : images des pièces mobiles (piece.ANIMES)")
    ap.add_argument("--samples-passes", default="",
                    help="décision D-7 (lot A3) : échantillons PAR PASSE, ex. « shadow=32 » ; les autres passes gardent "
                         "--samples. Vide (défaut) : comportement d'avant, inchangé")
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    par_passe = {}
    for x in [x for x in a.samples_passes.split(",") if x]:
        k, v = x.split("=")
        par_passe[k.strip()] = int(v)
    if par_passe:
        # D-7 : render_passes (fo_scene.py, partagé, NON modifié) rend chaque passe par render_to(scene, chemin) ; le
        # chemin finit par « -<passe>.png ». On pose scene.cycles.samples avant ce rendu et on le remet après : les
        # autres passes sont rendues EXACTEMENT comme avant (même scène, même graine, mêmes échantillons).
        _render_to = S.render_to

        def render_to_par_passe(scene, path):
            passe = os.path.basename(path)[:-4].rsplit("-", 1)[-1]
            if passe not in par_passe:
                return _render_to(scene, path)
            avant = scene.cycles.samples
            scene.cycles.samples = par_passe[passe]
            try:
                return _render_to(scene, path)
            finally:
                scene.cycles.samples = avant

        S.render_to = render_to_par_passe
    spec = importlib.util.spec_from_file_location("chim_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    for name in [n for n in a.names.split(",") if n]:
        t0 = time.time()
        meta = piece.PIECE["variants"][name]
        head = False
        if a.quick:
            layers = ["main", "glow", "shadow"]
        elif a.apercu:
            layers = ["main", "shadow", "glow"] if head else ["main", "ao", "shadow", "glow"]
        else:
            layers = ["main", "shadow", "glow"] if head else ["main", "ao", "shadow", "glow", "light"]
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
        if os.environ.get("FO_DENOISE"):     # refonte QG : rendus débruités (OIDN), mesures du brief non flattées
            scene.cycles.use_denoising = True
            scene.cycles.denoiser = "OPENIMAGEDENOISE"
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
                "count": info_build["count"], "halos": info_build["halos"], "quick": a.quick, "apercu": a.apercu,
                                "light_holdout": bool(getattr(C, "LIGHT_HOLDOUT", False))}
        if par_passe:
            info["samples_passes"] = dict(par_passe)
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-RENDER] %s %dx%d %d sommets build %.1fs rendu %.1fs" % (name, W, H, nverts, t_build, t_render),
              flush=True)
        if a.images and name in piece.ANIMES:
            images_mobiles(piece, name, a, d, W, H, ox, oy)


main()
