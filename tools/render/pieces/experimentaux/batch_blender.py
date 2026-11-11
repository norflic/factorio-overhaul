"""Rendu des expérimentaux (lot RB-V0, 31/10), dans UNE session Blender, TOUJOURS par le verrou de rendu (rendre.py).
Repris de vaisseau_o/batch_blender.py. Différences, dues à la taille (72 unités de haut, ombre de 60 tuiles) :
- caméra reculée (clip) et sol agrandi ; le reste de fo_scene (partagé, non modifié) est inchangé ;
- passe d'ombre à résolution et échantillons réduits (--ombre-pct, --ombre-spp) : elle couvre 10 fois la surface du corps ;
- une passe de lueur PAR GROUPE de matières émissives (FO_GROUPES : plasma, soleil, …), pour moduler chaque lumière
  dans le temps sur les planches d'effet sans refaire de rendu.
"""
import argparse
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
import geo as G  # noqa: E402

GROUPES = {"ixion": {"plasma": ("ix_plasma",), "soleil": ("ix_soleil",), "hublots": ("ix_hublot",), "feu": ("ix_feu",)},
           "bourdon": {"vitrail": ("bo_vitrail",), "cristal": ("bo_cristal", "bo_halo")},
           "battant": {"battant": ("bo_",)},
           "corps": {"vitrail": ("bo_vitrail",), "cristal": ("bo_cristal", "bo_halo")},
           "mega": {"vitrail": ("bo_vitrail",), "cristal": ("bo_cristal", "bo_halo"), "vortex": ("bo_vortex",)},
           "tourelle": {"vortex": ("bo_vortex",)},
           "ancre": {"ancre": ("bo_halo",)}, "griffes": {}, "chaine": {}}


def projected_bounds(objs):
    """Rend le cadre total (corps + ombre) et le cadre du corps seul : les passes du corps ne rendent que celui-ci (bordure)."""
    sv = C.sun_vector()
    us, vs, su, sv2 = [], [], [], []
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
                su.append(u)
                sv2.append(v)
    return (min(us + su), min(vs + sv2), max(us + su), max(vs + sv2)), (min(us), min(vs), max(us), max(vs))


def to_npy(png_path, npy_path):
    img = bpy.data.images.load(png_path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    np.save(npy_path, np.flipud(buf.reshape(h, w, 4)))
    bpy.data.images.remove(img)


def construire(name):
    import ixion
    import bourdon
    lot = G.Lot(S, "xp_" + name)
    info = ixion.build(S, lot) if name == "ixion" else bourdon.build(S, lot, name)
    n = lot.n
    lot.flush()
    return n, info or {}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--px", type=float, default=64.0)
    ap.add_argument("--ombre-pct", type=int, default=50)
    ap.add_argument("--ombre-spp", type=int, default=16)
    ap.add_argument("--lueur-spp", type=int, default=16)
    ap.add_argument("--sans-ombre", action="store_true")
    a = ap.parse_args(argv)
    a.out = os.path.abspath(a.out)
    C.PX_PER_UNIT_HR = a.px
    C.LIGHT_HOLDOUT = True
    for name in [n for n in a.names.split(",") if n]:
        t0 = time.time()
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        scene = bpy.context.scene
        n_pieces, info_build = construire(name)
        t_build = time.time() - t0
        bpy.context.view_layer.update()
        objs = S.piece_objects()
        nverts = sum(len(o.data.vertices) for o in objs if o.type == "MESH")
        (l, t, r, b), corps = projected_bounds(objs)
        m = int(a.px)
        left, top = int(math.floor(l)) - m, int(math.floor(t)) - m
        right, bottom = int(math.ceil(r)) + m, int(math.ceil(b)) + m
        W, H = right - left, bottom - top
        W += W % 2
        H += H % 2
        ox, oy = -left, -top
        S.setup_render(scene, W, H, samples=a.samples)
        if os.environ.get("FO_DENOISE"):
            scene.cycles.use_denoising = True
            scene.cycles.denoiser = "OPENIMAGEDENOISE"
        cam = S.setup_camera(scene, W, H, center_px=(ox, oy))
        # recul de la caméra (projection orthographique : l'image ne change pas), sans quoi le haut du géant est coupé
        kk = 320.0 / 60.0
        cam.location = (cam.location[0], cam.location[1] * kk, cam.location[2] * kk)
        cam.data.clip_end = 900.0
        canons, canons_sol = [], []
        if name == "mega":
            # lot MEGA-BOURDON : pivots des tourelles à l'écran, et le point du sol sous chacun, en tuiles depuis la position au sol
            import bourdon
            from bpy_extras.object_utils import world_to_camera_view
            bpy.context.view_layer.update()

            def ecran(q):
                u = world_to_camera_view(scene, cam, Vector(q))
                return [round((u.x * W - ox) / a.px, 3), round(((1.0 - u.y) * H - oy) / a.px, 3)]
            for q in bourdon.MEGA_PIVOTS:
                canons.append(ecran(q))
                canons_sol.append(ecran((q[0], q[1], 0.0)))
        S.setup_world(scene)
        sun = S.add_sun(scene)
        S.add_fill(scene)
        ground = S.add_ground(scene, size=700.0)
        d = os.path.join(a.out, name)
        os.makedirs(d, exist_ok=True)
        rd = scene.render
        rd.use_border = True
        rd.use_crop_to_border = False
        rd.border_min_x = max(0.0, (corps[0] - left - m) / float(W))
        rd.border_max_x = min(1.0, (corps[2] - left + m) / float(W))
        rd.border_min_y = max(0.0, 1.0 - (corps[3] - top + m) / float(H))
        rd.border_max_y = min(1.0, 1.0 - (corps[1] - top - m) / float(H))
        t1 = time.time()
        res = S.render_passes(scene, d, name, ["main"], sun, ground)
        print("[FO-RENDER] %s main %dx%d %.1fs" % (name, W, H, time.time() - t1), flush=True)
        # lueurs par groupe : tout le reste en noir (il occulte), ciel et soleil coupés, sol caché
        world = scene.world
        bg = world.node_tree.nodes["Background"]
        sky = bg.inputs["Strength"].default_value
        sun.hide_render = True
        for x in S.EXTRA_LIGHTS:
            x.hide_render = True
        bg.inputs["Strength"].default_value = 0.0
        S._sync_sky(world)
        ground.visible_camera = False
        ground.is_shadow_catcher = False
        for o in objs:
            o.visible_camera = True
        scene.cycles.samples = a.lueur_spp
        groupes = GROUPES.get(name) or (GROUPES["tourelle"] if name.startswith("tourelle-") else {})
        for g, noms in groupes.items():
            def fn(mat, noms=noms):
                if mat is not None and mat.get("fo_kind") == "emissive" and any(mat.name.startswith(x) for x in noms):
                    return mat
                return S._black_mat()
            saved = S._swap_materials(objs, fn)
            p = os.path.join(d, "%s-glow_%s.png" % (name, g))
            t2 = time.time()
            S.render_to(scene, p)
            res["glow_" + g] = p
            S._restore(saved)
            print("[FO-RENDER] %s glow_%s %.1fs" % (name, g, time.time() - t2), flush=True)
        if not a.sans_ombre:
            rd.use_border = False
            scene.cycles.samples = a.ombre_spp
            scene.render.resolution_percentage = a.ombre_pct
            ground.is_shadow_catcher = True
            ground.visible_camera = True
            sun.hide_render = False
            for o in objs:
                o.visible_camera = False
            p = os.path.join(d, "%s-shadow.png" % name)
            t2 = time.time()
            S.render_to(scene, p)
            res["shadow"] = p
            scene.render.resolution_percentage = 100
            print("[FO-RENDER] %s shadow %.1fs" % (name, time.time() - t2), flush=True)
        bg.inputs["Strength"].default_value = sky
        for k, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        info = {"variant": name, "canvas": [W, H], "origin_px": [ox, oy], "layers": sorted(res), "px": a.px, "ombre_pct": a.ombre_pct, "samples": a.samples,
                "blender": bpy.app.version_string, "seconds": round(time.time() - t0, 2), "seconds_build": round(t_build, 2), "verts": nverts, "objects": len(objs),
                "pieces": n_pieces, "count": {k: v for k, v in sorted(info_build.items()) if isinstance(v, (int, float))}, "canons": canons,
                "canons_sol": canons_sol}
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-RENDER] %s %dx%d %d sommets, %d pièces, build %.1fs, total %.1fs" % (name, W, H, nverts, n_pieces, t_build, time.time() - t0), flush=True)


main()
