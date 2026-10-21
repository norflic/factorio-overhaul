"""Point d'entrée Blender des niveaux de la machine d'assemblage 2 (lot V3, phase 1).

    blender -b --factory-startup -noaudio -P blender_entry.py -- --levels 3,4 --out <dossier>
            [--samples N] [--mode complet|masque] [--margin PX] [--t 0.0]

Ne se lance QUE par le pilote rendre.py, lui-même passé par le verrou de rendu (tools/render/with_render_lock.py).
Reprend la scène étalonnée de V0 (tools/render/blender/fo_scene.py, inchangé) et ses passes, avec deux ajouts
locaux, sans modifier le pipeline partagé :
- les surfaces lumineuses « de nuit seulement » (époques 1 et 2, bible §5) sont éteintes dans la passe principale
  et absentes de la lueur, mais présentes dans le halo ;
- le canevas englobe aussi les fenêtres du halo.
Mode « masque » : passe principale seule à 2 échantillons (silhouette rapide pour la mesure D1).
Sorties : <out>/nNN-<couche>.npy (valeurs exactes des PNG 16 bits) et <out>/nNN-render.json.
"""
import argparse
import json
import math
import os
import sys
import time

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import modeles  # noqa: E402
import params  # noqa: E402


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--mode", default="complet")
    ap.add_argument("--margin", type=int, default=24)
    ap.add_argument("--t", type=float, default=0.0)
    return ap.parse_args(argv)


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
    import numpy as np
    img = bpy.data.images.load(png_path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    np.save(npy_path, np.flipud(buf.reshape(h, w, 4)))
    bpy.data.images.remove(img)
    os.remove(png_path)


def reset_scene_state():
    S.HALO_LIGHTS.clear()
    S.EXTRA_LIGHTS.clear()
    S._BLACK = None
    S._WHITE = None
    S._AO = None
    S._BOOSTED.clear()


def vanilla_proxy(scene):
    """Volume de remplacement du corps vanilla (niveau 2 seulement : la pièce est posée sur le sprite vanilla).

    Fait F64 (RD_LOG, E31) : la couche draw_as_light révèle la couleur de jour de TOUT ce qu'elle couvre ; rendue
    sans le bâtiment porteur, elle laisse passer la lumière « à travers » lui et y dessine des trous. Ce volume :
    - passe principale : invisible à la caméra mais porte ombre (le bas du mât de la potence est dans l'ombre du
      corps, comme il le serait) ;
    - passe halo : visible, gris clair mat, il RECOIT la lumière de la lanterne (le toit vanilla s'éclaire) et
      bloque la flaque au sol derrière lui ;
    - liseré, ombre et lueur : absent (le sprite vanilla a déjà les siens ; la lueur est masquée au pixel).
    Boîte mesurée sur le sprite vanilla image 0 (bible §2.8 : L 2,56, haut à -1,56 à l'écran, 77 % de l'emprise) :
    x ±1,26, y de -1,22 à +1,40 (tuiles), toit à z = 0,50 (haut du toit à l'écran : -1,22 - 0,354 = -1,57)."""
    mat = bpy.data.materials.new("fo_proxy_vanilla")
    mat.use_nodes = True
    p = mat.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (0.20, 0.18, 0.16, 1.0)
    p.inputs["Roughness"].default_value = 0.7
    y0, y1 = -1.22, 1.40
    loc = (0.0, -(y0 + y1) / 2.0 * C.TILE_DEPTH_UNITS, 0.25)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.scale = (2.52, (y1 - y0) * C.TILE_DEPTH_UNITS, 0.50)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.name = "fo_proxy_vanilla"
    for c in list(o.users_collection):
        c.objects.unlink(o)
    scene.collection.objects.link(o)       # hors de la collection de la pièce : ni cadrage, ni masque
    o.data.materials.append(mat)
    return o


def proxy_state(o, stage):
    if o is None:
        return
    if stage == "main":
        o.hide_render = False
        o.visible_camera = False
    elif stage == "light":
        o.hide_render = False
        o.visible_camera = True
        o.material_slots[0].material = S._white_mat()
    else:
        o.hide_render = True


def render_level(n, a):
    t0 = time.time()
    reset_scene_state()
    scene = S.reset()
    meta = modeles.build_level(S, C, n, a.t)
    bpy.context.view_layer.update()
    objs = S.piece_objects()
    proxy = vanilla_proxy(scene) if n == 2 else None
    l, t, r, b = projected_bounds(objs)
    if a.mode == "complet":
        for w in meta["halo"]:
            dx, dy, z = w["at"]
            u, v = C.blender_to_screen_px(0.0, 0.0, z)
            cx, cy = dx * 64.0 + u, dy * 64.0 + v
            r1 = w["r"][1] * 64.0
            l, t, r, b = min(l, cx - r1), min(t, cy - r1), max(r, cx + r1), max(b, cy + r1)
    m = a.margin
    left, top = int(math.floor(l)) - m, int(math.floor(t)) - m
    right, bottom = int(math.ceil(r)) + m, int(math.ceil(b)) + m
    W, Hh = right - left, bottom - top
    W += W % 2
    Hh += Hh % 2
    ox, oy = -left, -top
    samples = 2 if a.mode == "masque" else a.samples
    S.setup_render(scene, W, Hh, samples=samples)
    S.setup_camera(scene, W, Hh, center_px=(ox, oy))
    S.setup_world(scene)
    sun = S.add_sun(scene)
    S.add_fill(scene)
    ground = S.add_ground(scene)
    prefix = "n%02d" % n
    os.makedirs(a.out, exist_ok=True)
    night = [mm for mm in bpy.data.materials if mm.get("fo_night_only")]
    emissive = [mm for mm in bpy.data.materials if mm.get("fo_kind") == "emissive"]
    res = {}
    # 1) principale : surfaces « de nuit » éteintes
    for mm in night:
        mm.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 0.0
    proxy_state(proxy, "main")
    res.update(S.render_passes(scene, a.out, prefix, ["main"], sun, ground))
    for mm in night:
        mm.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = mm["fo_emit_strength"]
    if a.mode == "complet":
        proxy_state(proxy, "autre")
        # 2) lueur de jour : sans les surfaces « de nuit »
        if len(night) < len(emissive):
            for mm in night:
                mm["fo_kind"] = "surface"
            res.update(S.render_passes(scene, a.out, prefix, ["glow"], sun, ground))
            for mm in night:
                mm["fo_kind"] = "emissive"
        # 3) liseré de contact, ombre (sans le volume vanilla), puis halo (avec lui : F64)
        res.update(S.render_passes(scene, a.out, prefix, ["ao", "shadow"], sun, ground))
        proxy_state(proxy, "light")
        res.update(S.render_passes(scene, a.out, prefix, ["light"], sun, ground))
        proxy_state(proxy, "autre")
    for k, path in res.items():
        to_npy(path, path[:-4] + ".npy")
    info = {
        "level": n, "epoch": params.epoque(n), "canvas": [W, Hh], "origin_px": [ox, oy], "mode": a.mode,
        "layers": sorted(res), "halo": meta["halo"], "modules": meta["modules"], "parts": meta.get("parts", {}),
        "t": a.t,
        "blender": bpy.app.version_string,
        "blender_hash": bpy.app.build_hash.decode() if isinstance(bpy.app.build_hash, bytes) else str(bpy.app.build_hash),
        "samples": scene.cycles.samples, "seed": scene.cycles.seed, "threads": scene.render.threads,
        "objects": len(objs), "seconds": round(time.time() - t0, 2),
    }
    with open(os.path.join(a.out, "%s-render.json" % prefix), "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, sort_keys=True)
    print("[FO-RENDER] %s %dx%d origine=(%d,%d) objets=%d %.1fs" % (prefix, W, Hh, ox, oy, len(objs), time.time() - t0),
          flush=True)


def main():
    a = parse()
    a.out = os.path.abspath(a.out)
    import traceback
    for tok in a.levels.split(","):
        try:
            render_level(int(tok), a)
        except Exception:                      # un niveau en erreur ne fait pas perdre le passage par le verrou
            print("[FO-ERREUR] niveau %s :
%s" % (tok, traceback.format_exc()), flush=True)


main()
