"""Rendu Blender de l'explorateur « haute technologie » (lot V3-S) : plusieurs variantes dans UNE session.

TOUJOURS par le verrou de rendu (lancé par ht_run.py, qui passe par with_render_lock.py) :
    blender -b --factory-startup -noaudio -P ht_blender.py -- --names n29-socle,n29-tete-E --out <cache> --samples 128

Scène, caméra, lumière, passes : celles du pipeline partagé (tools/render/blender/fo_scene.py, fo_calib.py),
INCHANGÉES ; cadrage et conversion .npy recopiés de render_piece.py (comme render_batch.py de V3 phase 1).
Passes : socle (base_picture) main, ao, shadow, glow, light ; tête main, shadow, glow (la tête ne touche pas le
sol ; la flaque de nuit est portée par le socle, F64). Halo V0b : LIGHT_HOLDOUT activé pour cette pièce (README :
« toute pièce nouvelle avec un halo doit l'activer »).
La géométrie vient de ht_gun.py (Python pur) : un objet par groupe (matériau, biseau), from_pydata, lissage par
face, modificateur de biseau du pipeline (S.bevel). La tête est un objet tourné (rotation Z) : le grain des
matériaux (coordonnées « Object ») suit la tête, il ne glisse pas d'une direction à l'autre.
"""
import argparse
import json
import math
import os
import sys
import time

import bmesh
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
import ht_gun as H  # noqa: E402

C.LIGHT_HOLDOUT = True


def add_grime(m, mottle, streak, seed):
    """Taches (bruit isotrope, ~0,08 unité) et coulures (bruit étiré selon Z) multipliées à la couleur de base d'un
    matériau de fo_scene.mat_metal (le module partagé n'est pas modifié : on insère deux nœuds avant la base)."""
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    src = p.inputs["Base Color"].links[0].from_socket
    tc = N.new("ShaderNodeTexCoord")
    n1 = N.new("ShaderNodeTexNoise")
    n1.noise_dimensions = "4D"
    n1.inputs["W"].default_value = seed + 3.1
    n1.inputs["Scale"].default_value = 7.0
    n1.inputs["Detail"].default_value = 4.0
    n1.inputs["Roughness"].default_value = 0.55
    L.new(tc.outputs["Object"], n1.inputs["Vector"])
    m1 = N.new("ShaderNodeMapRange")
    # seuil raide : taches franches de 6 à 15 px (bande 4-16 px de P2), pas un voile doux
    m1.inputs["From Min"].default_value = 0.44
    m1.inputs["From Max"].default_value = 0.58
    m1.inputs["To Min"].default_value = 1.0 - mottle
    m1.inputs["To Max"].default_value = 1.0 + 0.5 * mottle
    L.new(n1.outputs["Fac"], m1.inputs["Value"])
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 1.0, 0.18)
    L.new(tc.outputs["Object"], mp.inputs["Vector"])
    n2 = N.new("ShaderNodeTexNoise")
    n2.noise_dimensions = "4D"
    n2.inputs["W"].default_value = seed + 5.7
    n2.inputs["Scale"].default_value = 10.0
    n2.inputs["Detail"].default_value = 2.0
    L.new(mp.outputs["Vector"], n2.inputs["Vector"])
    m2 = N.new("ShaderNodeMapRange")
    m2.inputs["From Min"].default_value = 0.5
    m2.inputs["From Max"].default_value = 0.62
    m2.inputs["To Min"].default_value = 1.0
    m2.inputs["To Max"].default_value = 1.0 - streak
    L.new(n2.outputs["Fac"], m2.inputs["Value"])
    v1 = N.new("ShaderNodeVectorMath")
    v1.operation = "SCALE"
    L.new(src, v1.inputs[0])
    L.new(m1.outputs["Result"], v1.inputs["Scale"])
    v2 = N.new("ShaderNodeVectorMath")
    v2.operation = "SCALE"
    L.new(v1.outputs["Vector"], v2.inputs[0])
    L.new(m2.outputs["Result"], v2.inputs["Scale"])
    L.new(v2.outputs["Vector"], p.inputs["Base Color"])


def make_materials(pal):
    mats = {}
    for i, k in enumerate(sorted(pal)):
        spec = dict(pal[k])
        kind = spec.pop("kind")
        col = spec.pop("color")
        if kind == "metal":
            mats[k] = S.mat_metal("ht_%s" % k, col, seed=float(3 * i + 1), **spec)
            if k in H.GRIME:
                add_grime(mats[k], H.GRIME[k][0], H.GRIME[k][1], float(3 * i + 1))
        else:
            m = S.mat_emissive("ht_%s" % k, col, strength=spec.get("strength", 1.0), main_scale=0.0,
                               base=(0.006, 0.005, 0.004))
            # surface éteinte MATE dans la couche principale (README, braises de la cheminée : sinon reflet gris)
            p = m.node_tree.nodes["Principled BSDF"]
            p.inputs["Roughness"].default_value = 1.0
            p.inputs["Specular IOR Level"].default_value = 0.0
            mats[k] = m
    return mats


def instantiate(b, mats, tag, rot):
    objs = []
    for key in sorted(b.groups, key=lambda k: (k[0], -1.0 if k[1] is None else k[1])):
        mat, bev = key
        g = b.groups[key]
        V = np.concatenate(g["v"])
        me = bpy.data.meshes.new("%s_%s_%s" % (tag, mat, bev))
        me.from_pydata(V.tolist(), [], g["f"])
        me.polygons.foreach_set("use_smooth", [bool(x) for x in g["s"]])
        me.validate()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        o = bpy.data.objects.new(me.name, me)
        S.piece_collection().objects.link(o)
        o.data.materials.append(mats[mat])
        if bev:
            S.bevel(o, bev)
        o.rotation_euler = (0.0, 0.0, rot)
        objs.append(o)
    return objs


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


def margin_px(name):
    v = H.VARIANTS[name]
    if v["part"] == "socle":
        return int(64 * H.HALO_EXTRA) + 8
    return 40


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=128)
    a = ap.parse_args(argv)
    out = os.path.abspath(a.out)
    for name in [n for n in a.names.split(",") if n]:
        t0 = time.time()
        meta = H.VARIANTS[name]
        lv = meta["level"]
        head = meta["part"] == "tete"
        layers = ["main", "shadow", "glow"] if head else ["main", "ao", "shadow", "glow", "light"]
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        scene = bpy.context.scene
        b, rot = H.build(name)
        mats = make_materials(H.palette(H.LEVELS[lv]["epoch"]))
        objs = instantiate(b, mats, "s" if not head else "t", rot)
        if not head:
            # sources du halo : foyers du socle + foyers de la tête (au repos, pose N : près de l'axe)
            bh, _ = H.build("n%02d-tete-N" % (29 if lv == 30 else lv))
            for (p, col, pw) in b.lights + bh.lights:
                S.halo_light(p, col, pw * H.HALO_GAIN[lv], radius=0.06)
        bpy.context.view_layer.update()
        t_geo = time.time() - t0
        l, t, r, bt = projected_bounds(objs)
        m = margin_px(name)
        left, top = int(math.floor(l)) - m, int(math.floor(t)) - m
        right, bottom = int(math.ceil(r)) + m, int(math.ceil(bt)) + m
        W, Hh = right - left, bottom - top
        W += W % 2
        Hh += Hh % 2
        ox, oy = -left, -top
        S.setup_render(scene, W, Hh, samples=a.samples)
        S.setup_camera(scene, W, Hh, center_px=(ox, oy))
        S.setup_world(scene)
        sun = S.add_sun(scene)
        S.add_fill(scene)
        ground = S.add_ground(scene)
        d = os.path.join(out, name)
        os.makedirs(d, exist_ok=True)
        prefix = "ht-%s" % name
        times = {}
        res = {}
        for layer in layers:
            t1 = time.time()
            res.update(S.render_passes(scene, d, prefix, [layer], sun, ground))
            times[layer] = round(time.time() - t1, 2)
        for k, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        nfaces = sum(len(o.data.polygons) for o in objs)
        info = {"variant": name, "canvas": [W, Hh], "origin_px": [ox, oy], "layers": sorted(res),
                "samples": scene.cycles.samples, "seed": scene.cycles.seed, "blender": bpy.app.version_string,
                "blender_hash": bpy.app.build_hash.decode() if isinstance(bpy.app.build_hash, bytes) else str(bpy.app.build_hash),
                "seconds": round(time.time() - t0, 2), "seconds_geometry": round(t_geo, 2), "seconds_pass": times,
                "objects": len(objs), "faces": nfaces, "primitives": b.nprim, "halo_lights": len(S.HALO_LIGHTS),
                "light_holdout": bool(C.LIGHT_HOLDOUT)}
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-RENDER] %s %dx%d %.1fs (géométrie %.1fs, %d faces)" % (name, W, Hh, time.time() - t0, t_geo, nfaces),
              flush=True)


main()
