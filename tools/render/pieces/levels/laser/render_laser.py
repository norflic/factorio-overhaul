"""Tourelle laser, lot V3 phase 1 : rendu d'APERÇU des poses de référence (s'exécute DANS Blender).

TOUJOURS par le verrou de rendu (CLAUDE.md, interdit n° 6) ; le pilote run_laser.py s'en charge :
    python tools/render/with_render_lock.py -- <blender> -b --factory-startup -noaudio \
        -P tools/render/pieces/levels/laser/render_laser.py -- --jobs L03:base,L03:N --out <dossier> [--samples 32]
    ... -- --dry --levels 2-30 --out <dossier>    (aucun rendu : boîtes projetées et triangles des têtes)

Pourquoi un pilote propre à la famille (et pas tools/render/render.py) :
- la tête se rend avec le socle en CACHE (holdout) : en jeu la tête (object) est dessinée par-dessus le
  socle (lower-object), le cache la troue exactement là où le socle est devant elle ;
- plusieurs poses dans un seul Blender (démarrage payé une fois) ;
- émissifs « de nuit seulement » (époques 1-2) : éteints dans la lueur, allumés dans le halo ;
- canevas FIXE pour toutes les poses (même origine) : couches superposables sans recalcul.
Les fichiers partagés du pipeline (tools/render/*.py, blender/*) sont importés, jamais modifiés.

Sorties : <out>/L<NN>/<partie>-<passe>.npz (uint16 = valeurs exactes du PNG 16 bits, sRGB codé, alpha
droit) et <out>/L<NN>/<partie>.json (halos, réglages, durée). Partie = base, N, E, S, W.
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
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import laser_design as D  # noqa: E402
import laser_model as M  # noqa: E402

PASS_SAMPLES = {"main": 1.0, "front": 1.0, "ao": 0.5, "shadow": 0.25, "glow": 0.25, "light": 0.5}
HALO_W = 14.0          # puissance (W) d'une source de halo de poids 1 (normalisée ensuite au post-traitement)


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--jobs", default="")
    ap.add_argument("--levels", default="")
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--dry", action="store_true")
    return ap.parse_args(argv)


def levels_from(spec):
    out = []
    for part in spec.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return out


def reset_state():
    S.reset()
    S.HALO_LIGHTS.clear()
    S.EXTRA_LIGHTS.clear()
    S._BLACK = None
    S._WHITE = None
    S._AO = None
    S._BOOSTED.clear()
    return bpy.context.scene


def mesh_objs():
    return [o for o in S.piece_objects() if o.type == "MESH"]


# ------------------------------------------------------------------------------------------------
# matériaux de substitution par passe
# ------------------------------------------------------------------------------------------------
_EMIT = {}


def emit_copy(mat, gain):
    key = (mat.name, gain)
    if key not in _EMIT:
        m = bpy.data.materials.new(mat.name + "_x%.1f" % gain)
        m.use_nodes = True
        p = m.node_tree.nodes["Principled BSDF"]
        col = mat["fo_emit_color"]
        p.inputs["Base Color"].default_value = (0.05, 0.05, 0.05, 1)
        p.inputs["Emission Color"].default_value = (col[0], col[1], col[2], 1)
        p.inputs["Emission Strength"].default_value = float(mat["fo_emit_strength"]) * gain
        m.cycles.emission_sampling = "NONE"
        m["fo_kind"] = "emissive"
        _EMIT[key] = m
    return _EMIT[key]


def kind(mat):
    return mat.get("fo_kind") if mat is not None else None


def glow_swap(mat):
    return mat if kind(mat) == "emissive" else S._black_mat()


def light_swap(mat):
    if kind(mat) in ("emissive", "night"):
        return emit_copy(mat, C.LIGHT_EMIT_GAIN)
    return S._white_mat()


# ------------------------------------------------------------------------------------------------
def save_npz(png, npz):
    img = bpy.data.images.load(png, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    arr = np.flipud(buf.reshape(h, w, 4))
    bpy.data.images.remove(img)
    np.savez_compressed(npz, a=np.round(np.clip(arr, 0, 1) * 65535).astype(np.uint16))
    os.remove(png)


def render_pass(scene, name, out_dir, prefix, samples):
    scene.cycles.samples = max(4, int(round(samples * PASS_SAMPLES[name])))
    png = os.path.join(out_dir, "%s-%s.png" % (prefix, name))
    S.render_to(scene, png)
    save_npz(png, png[:-4] + ".npz")
    return name


def render_job(level, part, out_root, samples):
    t0 = time.time()
    scene = reset_state()
    _EMIT.clear()
    heading = D.DIRECTIONS.get(part, 0.0)
    info = M.build(S, C, level, "base" if part == "base" else "head", heading)
    objs = mesh_objs()
    hold = set(o.name for o in info["holdout"])
    back = set(o.name for o in info["back"])
    W, H = D.CANVAS_W, D.CANVAS_H
    S.setup_render(scene, W, H, samples=samples)
    S.setup_camera(scene, W, H, center_px=D.ORIGIN_PX)
    S.setup_world(scene)
    sun = S.add_sun(scene)
    S.add_fill(scene)
    ground = S.add_ground(scene)
    for h in info["halos"]:
        S.halo_light(h["loc"], h["color"], HALO_W * h["power"], radius=0.05, name="halo")
    bg = scene.world.node_tree.nodes["Background"]
    sky = bg.inputs["Strength"].default_value
    out_dir = os.path.join(out_root, "L%02d" % level)
    os.makedirs(out_dir, exist_ok=True)
    prefix = part
    mats = [s.material for o in objs for s in o.material_slots]
    has_day = any(kind(m) == "emissive" for m in mats)
    has_any = has_day or any(kind(m) == "night" for m in mats)
    done = []

    def state(sun_on, sky_on, fill_on, catcher, ground_cam, obj_cam, holdout_mode):
        sun.hide_render = not sun_on
        for x in S.EXTRA_LIGHTS:
            x.hide_render = not fill_on
        bg.inputs["Strength"].default_value = sky if sky_on else 0.0
        ground.is_shadow_catcher = catcher
        ground.visible_camera = ground_cam
        for o in objs:
            o.visible_camera = obj_cam
            o.is_holdout = False
            o.hide_render = False
            if o.name in hold:
                if holdout_mode == "holdout":
                    o.is_holdout = True
                elif holdout_mode == "hide":
                    o.hide_render = True

    # couche principale
    state(True, True, True, False, False, True, "holdout")
    done.append(render_pass(scene, "main", out_dir, prefix, samples))
    if back:
        # niveau 2 : la même SANS les objets « derrière le socle vanilla » (mis en cache) ; le post-traitement
        # masque la différence par l'alpha du socle vanilla
        for o in objs:
            if o.name in back:
                o.is_holdout = True
        done.append(render_pass(scene, "front", out_dir, prefix, samples))
        for o in objs:
            o.is_holdout = False
    # liseré de contact (socle seulement : la tête ne touche pas le sol)
    if part == "base":
        gsaved = S._swap_materials([ground], lambda m: S._ao_ground_mat())
        state(False, False, False, False, True, False, "hide")
        done.append(render_pass(scene, "ao", out_dir, prefix, samples))
        S._restore(gsaved)
    # ombre portée du soleil seul
    state(True, False, False, True, True, False, "hide")
    done.append(render_pass(scene, "shadow", out_dir, prefix, samples))
    # lueur de jour (draw_as_glow)
    if has_day:
        saved = S._swap_materials(objs, glow_swap)
        state(False, False, False, False, False, True, "holdout")
        done.append(render_pass(scene, "glow", out_dir, prefix, samples))
        S._restore(saved)
    # halo de nuit (draw_as_light) : éclairage direct des seules sources de halo
    if has_any and info["halos"]:
        saved = S._swap_materials(objs, light_swap)
        gsaved = S._swap_materials([ground], lambda m: S._white_mat())
        state(False, False, False, False, True, True, "none")
        for x in S.HALO_LIGHTS:
            x.hide_render = False
        emit_objs = [o for o in objs if any(kind(sl.material) == "emissive" for sl in o.material_slots)]
        for o in emit_objs:
            o.visible_diffuse = False
            o.visible_glossy = False
        cyc = scene.cycles
        bounces = (cyc.max_bounces, cyc.diffuse_bounces, cyc.glossy_bounces)
        cyc.max_bounces, cyc.diffuse_bounces, cyc.glossy_bounces = 0, 0, 0
        done.append(render_pass(scene, "light", out_dir, prefix, samples))
        cyc.max_bounces, cyc.diffuse_bounces, cyc.glossy_bounces = bounces
        for o in emit_objs:
            o.visible_diffuse = True
            o.visible_glossy = True
        for x in S.HALO_LIGHTS:
            x.hide_render = True
        S._restore(saved)
        S._restore(gsaved)
    meta = {"level": level, "part": part, "epoch": info["epoch"], "heading_deg": heading, "passes": done,
            "canvas": [W, H], "origin_px": list(D.ORIGIN_PX), "samples": samples,
            "pass_samples": {k: max(4, int(round(samples * v))) for k, v in PASS_SAMPLES.items()},
            "halos": [{"loc": list(h["loc"]), "power": h["power"]} for h in info["halos"]],
            "objects": len(objs), "holdout_objects": len(hold), "back_objects": len(back),
            "blender": bpy.app.version_string, "seed": scene.cycles.seed, "seconds": round(time.time() - t0, 2)}
    with open(os.path.join(out_dir, "%s.json" % prefix), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
    print("[FO-LASER] L%02d %-4s %s %.1fs" % (level, part, ",".join(done), time.time() - t0), flush=True)


# ------------------------------------------------------------------------------------------------
# mode « sec » : géométrie seulement (boîtes projetées, triangles pour l'enveloppe de la tête)
# ------------------------------------------------------------------------------------------------
def tris_of(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for o in objs:
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        mw = o.matrix_world
        vs = [mw @ v.co for v in me.vertices]
        for t in me.loop_triangles:
            out.append([tuple(vs[i]) for i in t.vertices])
        ev.to_mesh_clear()
    return np.array(out, dtype=np.float32).reshape(-1, 3, 3)


def dry(levels, out_root):
    os.makedirs(out_root, exist_ok=True)
    rep = {}
    for lv in levels:
        e = D.epoch_of(lv)
        reset_state()
        if lv == 2:
            M.build(S, C, lv, "base")
            base = tris_of(mesh_objs())
            np.savez_compressed(os.path.join(out_root, "geo-L%02d.npz" % lv), base=base)
            rep[lv] = {"epoch": e, "base_tris": int(len(base))}
            continue
        info = M.build(S, C, lv, "head", 0.0)
        head = tris_of(info["head"])
        base = tris_of(info["base"])
        if lv % 2 == 0:
            reset_state()
            M.build(S, C, lv, "base")
            base = tris_of(mesh_objs())
        np.savez_compressed(os.path.join(out_root, "geo-L%02d.npz" % lv), head=head, base=base)
        rep[lv] = {"epoch": e, "head_tris": int(len(head)), "base_tris": int(len(base))}
        print("[FO-LASER-DRY] L%02d tête %d triangles, socle %d" % (lv, len(head), len(base)), flush=True)
    with open(os.path.join(out_root, "geo.json"), "w", encoding="utf-8") as f:
        json.dump(rep, f, indent=1)


def main():
    a = parse()
    out = os.path.abspath(a.out)
    if a.dry:
        dry(levels_from(a.levels), out)
        return
    for job in [j for j in a.jobs.split(",") if j]:
        lv, part = job.split(":")
        render_job(int(lv.lstrip("L")), part, out, a.samples)


main()
