"""Rendu Cycles des variantes de l'exploration hybride (s'exécute DANS Blender, une session pour toutes les
variantes demandées). TOUJOURS par le verrou de rendu (rendre.py l'appelle par tools/render/with_render_lock.py).

    blender -b --factory-startup -noaudio -P blender_render.py -- --names a,b --out <cache> --samples 128

Scène, caméra, lumière, passes : tools/render/blender/fo_scene.py et fo_calib.py, INCHANGÉS (API publique :
reset, setup_render, setup_camera, setup_world, add_sun, add_fill, add_ground, mat_metal, mat_emissive,
halo_light, render_passes). Le cadrage et la conversion en .npy sont recopiés de render_piece.py (comme le lot
V3 phase 1). Surcharge par pièce (README V0b) : LIGHT_HOLDOUT = True pour le socle (pièce nouvelle avec halo).

La géométrie vient de design.py (Python pur) : un maillage par matériau, créé en une fois (from_pydata).
La tête est construite canons vers +Y puis tournée par la ROTATION DE L'OBJET (rotation_euler z) : les
coordonnées de texture « Object » des matériaux (grain, rouille) tournent avec elle (pas de grain qui glisse
d'une direction à l'autre).
Sortie : <out>/<variante>/hyb-<variante>-<passe>.npy et render.json (canevas, origine, halos, durées).
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
# rendre.py lance une COPIE figée des scripts (cache/…/snap-*) : on peut continuer à modifier design.py pendant
# l'attente du verrou sans changer ce qui sera rendu ; FO_RENDER_DIR désigne alors tools/render
RENDER = os.environ.get("FO_RENDER_DIR") or os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import design as Dz  # noqa: E402

EMBER_BASE = (0.008, 0.006, 0.005)


def make_materials(specs, used):
    mats = {}
    for key in sorted(used):
        kind, par = specs[key]
        p = dict(par)
        if kind == "metal":
            col = p.pop("color")
            mats[key] = S.mat_metal("hyb_" + key, col, seed=float(sum(ord(c) for c in key) % 97), **p)
        else:
            m = S.mat_emissive("hyb_" + key, p["color"], strength=p["strength"], main_scale=0.0, crust=p.get("crust"),
                               base=EMBER_BASE)
            # surface éteinte MATE dans la couche principale (cheminée V0b, README : sinon le reflet gris bleuit)
            bsdf = m.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Roughness"].default_value = 1.0
            bsdf.inputs["Specular IOR Level"].default_value = 0.0
            mats[key] = m
    return mats


def make_objects(g, mats, angle):
    objs = []
    for key in sorted(g.meshes):
        md = g.meshes[key]
        me = bpy.data.meshes.new("hyb_%s_%s" % (g.name, key))
        me.from_pydata(md.v, [], md.f)
        me.polygons.foreach_set("use_smooth", [bool(s) for s in md.s])
        me.validate(clean_customdata=False)
        me.update()
        o = bpy.data.objects.new(me.name, me)
        S.piece_collection().objects.link(o)
        o.data.materials.append(mats[key])
        o.rotation_euler = (0.0, 0.0, angle)
        objs.append(o)
    return objs


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


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--margin", type=int, default=48)
    a = ap.parse_args(argv)
    out = os.path.abspath(a.out)
    for name in [n for n in a.names.split(",") if n]:
        t0 = time.time()
        meta = Dz.variants()[name]
        head = meta["part"] == "tete"
        layers = ["main", "shadow", "glow"] if head else ["main", "ao", "shadow", "glow", "light"]
        C.LIGHT_HOLDOUT = not head
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        scene = bpy.context.scene
        g, specs, angle = Dz.build(name)
        mats = make_materials(specs, g.meshes.keys())
        objs = make_objects(g, mats, angle)
        halos = []
        if not head:
            # halo de nuit porté par le socle (base_picture : la flaque ne tourne pas avec la tête) : sources du
            # socle + sources de la tête en pose N (F64 ; même choix que le lot V3 phase 1)
            lv = meta["level"]
            gh, _, _ = Dz.build("n%02d-tete-N" % (29 if lv == 30 else lv))
            for p, col, pw in g.lights + gh.lights:
                S.halo_light(p, col, pw, radius=0.05, name="hyb_halo")
                halos.append({"xyz": list(p), "px": list(C.blender_to_screen_px(*p)), "power": pw})
        bpy.context.view_layer.update()
        l, t, r, b = projected_bounds(objs)
        m = a.margin
        if not head:
            m = max(m, int(64 * 0.85 * Dz.LEVELS[meta["level"]]["side"]) - int((r - l) / 2) + 8)
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
        d = os.path.join(out, name)
        os.makedirs(d, exist_ok=True)
        prefix = "hyb-%s" % name
        tp = {}
        res = {}
        for layer in layers:
            t1 = time.time()
            res.update(S.render_passes(scene, d, prefix, [layer], sun, ground))
            tp[layer] = round(time.time() - t1, 2)
        for k, path in res.items():
            to_npy(path, path[:-4] + ".npy")
            os.remove(path)
        nv = sum(len(md.v) for md in g.meshes.values())
        nf = sum(len(md.f) for md in g.meshes.values())
        info = {"variant": name, "canvas": [W, H], "origin_px": [ox, oy], "layers": sorted(res),
                "samples": scene.cycles.samples, "seed": scene.cycles.seed, "halos": halos,
                "blender": bpy.app.version_string, "seconds": round(time.time() - t0, 2), "seconds_by_pass": tp,
                "vertices": nv, "faces": nf, "counts": g.counts, "light_holdout": C.LIGHT_HOLDOUT}
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-RENDER] %s %dx%d %d sommets %.1fs %s" % (name, W, H, nv, time.time() - t0, tp), flush=True)


main()
