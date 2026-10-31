"""Rendu Blender d'une souche de biter (lot RB-V0). TOUJOURS par le verrou :
    python tools/render/with_render_lock.py -- <blender> -b --factory-startup -noaudio -P tools/render/pieces/biters/rendu_blender.py -- \
        --souche cuirasse --mode gris|peint --poses 0:225,0.25:225 --samples 16 --out <dossier>
--poses : liste de phase:cap (cap 0 = nord, 90 = est, sens horaire). Scène, caméra et passes de fo_scene (mêmes soleil, ciel, sol).
Sortie : <out>/<souche>-<ph>-<cap>/ : main, ao, shadow en .npy, render.json. Débruité (OpenImageDenoise) à partir des passes albédo et normale.
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
import anatomie  # noqa: E402
import sdf  # noqa: E402


def maillage(nom, V, Q, N):
    m = bpy.data.meshes.new(nom)
    m.vertices.add(len(V))
    m.loops.add(len(Q) * 4)
    m.polygons.add(len(Q))
    m.vertices.foreach_set("co", V.ravel())
    m.polygons.foreach_set("loop_start", np.arange(len(Q), dtype=np.int32) * 4)
    m.loops.foreach_set("vertex_index", Q.astype(np.int32).ravel())
    m.update(calc_edges=True)
    m.shade_smooth()
    m.normals_split_custom_set_from_vertices(N.tolist())
    return m


def attr_vec(m, nom, a):
    x = m.attributes.new(nom, "FLOAT_VECTOR", "POINT")
    x.data.foreach_set("vector", a.astype(np.float32).ravel())


def attr_coul(m, nom, c):
    x = m.attributes.new(nom, "FLOAT_COLOR", "POINT")
    x.data.foreach_set("color", np.concatenate([c, np.ones((len(c), 1), np.float32)], axis=1).astype(np.float32).ravel())


def matiere_peinte(echelle):
    """Toute la couleur vient des sommets ; le grain fin de la peau vient d'un bruit lu dans le repère de repos (attribut q)."""
    m = bpy.data.materials.new("fo_peau")
    m.use_nodes = True
    nt = m.node_tree
    n = nt.nodes
    l = nt.links
    p = n["Principled BSDF"]
    coul = n.new("ShaderNodeAttribute")
    coul.attribute_name = "coul"
    mat = n.new("ShaderNodeAttribute")
    mat.attribute_name = "mat"
    q = n.new("ShaderNodeAttribute")
    q.attribute_name = "q"
    l.new(coul.outputs[0], p.inputs["Base Color"])
    sep = n.new("ShaderNodeSeparateXYZ")
    l.new(mat.outputs[1], sep.inputs[0])
    l.new(sep.outputs[0], p.inputs["Roughness"])
    l.new(sep.outputs[1], p.inputs["Coat Weight"])
    p.inputs["Coat Roughness"].default_value = 0.28
    p.inputs["Specular IOR Level"].default_value = 0.5
    bruit = n.new("ShaderNodeTexNoise")
    bruit.inputs["Scale"].default_value = 22.0 / echelle
    bruit.inputs["Detail"].default_value = 5.0
    bruit.inputs["Roughness"].default_value = 0.62
    l.new(q.outputs[1], bruit.inputs["Vector"])
    bump = n.new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.010 * echelle
    l.new(bruit.outputs[0], bump.inputs["Height"])
    l.new(sep.outputs[2], bump.inputs["Strength"])
    l.new(bump.outputs[0], p.inputs["Normal"])
    return m


def bornes(objs):
    sv = C.sun_vector()
    us, vs = [], []
    for o in objs:
        if o.type != "MESH":
            continue
        for coin in o.bound_box:
            w = o.matrix_world @ Vector(coin)
            u, v = C.blender_to_screen_px(w.x, w.y, w.z)
            us.append(u)
            vs.append(v)
            if w.z > 0 and sv[2] > 1e-6:
                k = w.z / sv[2]
                u, v = C.blender_to_screen_px(w.x - sv[0] * k, w.y - sv[1] * k, 0.0)
                us.append(u)
                vs.append(v)
    return min(us), min(vs), max(us), max(vs)


def to_npy(png, npy):
    img = bpy.data.images.load(png, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    np.save(npy, np.flipud(buf.reshape(h, w, 4)))
    bpy.data.images.remove(img)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--souche", required=True)
    ap.add_argument("--mode", default="gris")
    ap.add_argument("--poses", default="0:225")
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--out", required=True)
    ap.add_argument("--densite", type=float, default=0.0)
    ap.add_argument("--samples-sol", type=int, default=16, help="échantillons des passes ao et shadow (au sol, sans détail à garder)")
    a = ap.parse_args(argv)
    _render_to = S.render_to

    def render_to_par_passe(scene, path):
        avant = scene.cycles.samples
        if not path.endswith("-main.png"):
            scene.cycles.samples = min(avant, a.samples_sol)
        try:
            return _render_to(scene, path)
        finally:
            scene.cycles.samples = avant

    S.render_to = render_to_par_passe
    mod = __import__(a.souche)
    C.PX_PER_UNIT_HR = a.densite or mod.DENSITE
    C.AO_DISTANCE = mod.AO
    for pose in a.poses.split(","):
        ph, cap = pose.split(":")
        ph, cap = float(ph), float(cap)
        t0 = time.time()
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        scene = bpy.context.scene
        forme = mod.construire(ph)
        V, Q, nb = sdf.extraire(forme)
        t_champ = time.time() - t0
        N = sdf.normales(forme, V, forme.voxel * 0.8)
        yaw = math.atan2(math.cos(math.radians(cap)), math.sin(math.radians(cap)))    # +x local -> cap
        Rz = np.array([[math.cos(yaw), -math.sin(yaw), 0], [math.sin(yaw), math.cos(yaw), 0], [0, 0, 1]], np.float32)
        m = maillage(a.souche, V @ Rz.T, Q, N @ Rz.T)
        if a.mode == "gris":
            mat = S.mat_flat("fo_gris", (0.40, 0.40, 0.40), rough=0.55)
        else:
            coul, att, q = anatomie.peindre(forme, V, N, mod.PALETTES, mod.CREUX)
            attr_coul(m, "coul", coul)
            attr_vec(m, "mat", att)
            attr_vec(m, "q", q)
            mat = matiere_peinte(mod.CREUX / 0.05)
        ob = bpy.data.objects.new(a.souche, m)
        bpy.context.scene.collection.objects.link(ob)
        S._adopt(ob, mat, a.souche)
        t_mesh = time.time() - t0
        bpy.context.view_layer.update()
        objs = S.piece_objects()
        l, t, r, b = bornes(objs)
        marge = 24
        left, top = int(math.floor(l)) - marge, int(math.floor(t)) - marge
        right, bottom = int(math.ceil(r)) + marge, int(math.ceil(b)) + marge
        W, H = right - left, bottom - top
        W += W % 2
        H += H % 2
        ox, oy = -left, -top
        S.setup_render(scene, W, H, samples=a.samples)
        cy = scene.cycles
        cy.use_denoising = True
        cy.denoiser = "OPENIMAGEDENOISE"
        cy.denoising_input_passes = "RGB_ALBEDO_NORMAL"
        cy.denoising_prefilter = "ACCURATE"
        S.setup_camera(scene, W, H, center_px=(ox, oy))
        S.setup_world(scene)
        sun = S.add_sun(scene)
        S.add_fill(scene)
        ground = S.add_ground(scene)
        nom = "%s-%03d-%03d" % (a.souche, round(ph * 1000) % 1000, round(cap))
        d = os.path.join(a.out, nom)
        os.makedirs(d, exist_ok=True)
        res = S.render_passes(scene, d, nom, ["main", "ao", "shadow"], sun, ground)
        for k, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        info = {"souche": a.souche, "mode": a.mode, "phase": ph, "cap": cap, "canvas": [W, H], "origin_px": [ox, oy], "densite": C.PX_PER_UNIT_HR,
                "samples": a.samples, "layers": sorted(res), "sommets": len(V), "quads": len(Q), "points_calcules": nb, "voxel": forme.voxel,
                "seconds_champ": round(t_champ, 1), "seconds_maillage": round(t_mesh, 1), "seconds": round(time.time() - t0, 1), "blender": bpy.app.version_string}
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-BITER] %s %dx%d %d sommets ; champ %.0fs, maillage %.0fs, total %.0fs" % (nom, W, H, len(V), t_champ, t_mesh, time.time() - t0), flush=True)


main()
