"""Rendu de plusieurs variantes des ROBOTS (lot RB-V0) dans UNE session Blender. COPIE de vaisseau_o/batch_blender.py (même
scène, caméra, passes de fo_scene ; fichiers partagés NON modifiés) ; en plus : la définition par variante (meta["ppu"], gros
plan). TOUJOURS par le verrou de rendu (lancé par rendre.py).
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


def projected_bounds(objs, ombre=True):
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
            if ombre and w.z > 0 and sv[2] > 1e-6:
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


def passe_masque(scene, d, name, sun, ground):
    """Série (RB-V1) : pièces peintes (matière marquée fo_teinte) en blanc, tout le reste en noir et opaque (il cache la peinture
    derrière lui), sans aucune lumière. La proportion de blanc d'un pixel devient l'alpha de la couche de teinte du propriétaire."""
    objs = S.piece_objects()
    blanc = S.mat_emissive("fo_masque", (1.0, 1.0, 1.0), strength=1.0, base=(1.0, 1.0, 1.0))
    world = scene.world
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Strength"].default_value = 0.0
    S._sync_sky(world)
    sun.hide_render = True
    for x in S.EXTRA_LIGHTS:
        x.hide_render = True
    ground.is_shadow_catcher = False
    ground.visible_camera = False
    S._swap_materials(objs, lambda m: blanc if (m is not None and m.get("fo_teinte")) else S._black_mat())
    p = os.path.join(d, "%s-mask.png" % name)
    S.render_to(scene, p)
    return p


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--apercu", action="store_true")
    ap.add_argument("--reprise", action="store_true", help="saute les variantes déjà rendues")
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
    spec = importlib.util.spec_from_file_location("rb_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    for name in [n for n in a.names.split(",") if n]:
        if a.reprise and os.path.isfile(os.path.join(a.out, name, "render.json")):     # série : un lancement interrompu reprend ici
            continue
        t0 = time.time()
        meta = piece.PIECE["variants"][name]
        C.PX_PER_UNIT_HR = float(meta.get("ppu", 64.0))
        head = False
        if a.quick:
            layers = ["main", "glow", "shadow"]
        elif a.apercu:
            layers = ["main", "shadow", "glow"] if head else ["main", "ao", "shadow", "glow"]
        else:
            layers = ["main", "shadow", "glow"] if head else ["main", "ao", "shadow", "glow", "light"]
        if "piece" in meta:
            layers = ["main", "glow"]
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
        l, t, r, b = projected_bounds(objs, "piece" not in meta)
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
        if meta.get("serie"):
            res["mask"] = passe_masque(scene, d, name, sun, ground)
        t_render = time.time() - t1
        for k, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        info = {"variant": name, "canvas": [W, H], "origin_px": [ox, oy], "layers": sorted(res),
                "samples": scene.cycles.samples, "seed": scene.cycles.seed, "blender": bpy.app.version_string,
                "seconds": round(time.time() - t0, 2), "seconds_build": round(t_build, 2),
                "seconds_render": round(t_render, 2), "verts": nverts, "ppu": C.PX_PER_UNIT_HR,
                "tris": sum(sum(max(0, len(p.vertices) - 2) for p in o.data.polygons) for o in objs if o.type == "MESH"), "objects": len(objs),
                "count": info_build["count"], "halos": info_build["halos"], "quick": a.quick, "apercu": a.apercu,
                                "light_holdout": bool(getattr(C, "LIGHT_HOLDOUT", False))}
        if par_passe:
            info["samples_passes"] = dict(par_passe)
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-RENDER] %s %dx%d %d sommets build %.1fs rendu %.1fs" % (name, W, H, nverts, t_build, t_render),
              flush=True)


main()
