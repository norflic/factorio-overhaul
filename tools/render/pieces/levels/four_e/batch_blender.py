"""Rendu de plusieurs variantes du FOUR (kit four_e, lot F2-A, 25/10) dans UNE session Blender : COPIE de
laser_e/batch_blender.py (lui-même copie de gun_e), seuls changent le chemin de la pièce (four_e/piece.py), le nom du
module chargé et la bouche de fumée écrite dans render.json (« fumee » : x, yn, z). Le four n'a pas de tête.

Texte d'origine (gun_e) :

TOUJOURS par le verrou de rendu (lancé par rendre.py) :
    python tools/render/with_render_lock.py -- blender -b --factory-startup -noaudio         -P tools/render/pieces/levels/laser_e/batch_blender.py -- --names a,b --out <cache> --samples 128

Même scène, caméra et passes que tools/render/blender/render_piece.py (fichiers partagés NON modifiés ; cadrage et
conversion en .npy repris de V3 phase 1, render_batch.py, puis des plages de la passe 3) :
  socle et pièce : main, ao, shadow, glow, light (halo V0b : LIGHT_HOLDOUT vrai, pièce découpée) ;
  tête           : main, shadow, glow (ni liseré de contact ni halo : la flaque est portée par le socle).
--quick : passes main, glow et shadow seulement (essais de forme et de mesure).
--samples-passes shadow=32 (décision D-7, lot A3) : échantillons propres à une passe (les autres gardent --samples) ;
render.json le dit (« samples_passes »). Sans l'option, rien ne change (preuve d'identité : fo-logs/2026-10-24_A3/d7).
--apercu (passe 5, rondes de lecture) : toutes les passes de JOUR (socle et pièce : main, ao, shadow, glow ; tête :
main, shadow, glow), sans la passe light (halo de nuit) : l'image de jour est celle d'un rendu complet.
render.json dit la variante de corps utilisée (« corps » : A ou B, kit.corps_choisi) et l'habillage d'essai du
témoin (« habillage », variable FO_HABILLAGE_ESSAI posée par rendre.py --habillage ; None sinon).
Sortie : <out>/<variante>/<variante>-<passe>.npy et render.json (canevas, origine, durées, comptes de pièces).
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
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))   # lot K0 : kit commun (kit.py, parts*.py…)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import kit as kit_mod  # noqa: E402


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


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--apercu", action="store_true")
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
    spec = importlib.util.spec_from_file_location("four_piece", os.path.join(HERE, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    for name in [n for n in a.names.split(",") if n]:
        t0 = time.time()
        meta = piece.PIECE["variants"][name]
        head = meta["part"] == "tete"
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
                "corps": kit_mod.corps_choisi(), "habillage": os.environ.get("FO_HABILLAGE_ESSAI", "") or None,
                "light_holdout": bool(getattr(C, "LIGHT_HOLDOUT", False)),
                "fumee": [round(float(v), 4) for v in info_build["fumee"]] if info_build.get("fumee") else None}
        if par_passe:
            info["samples_passes"] = dict(par_passe)
        with open(os.path.join(d, "render.json"), "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1, sort_keys=True)
        print("[FO-RENDER] %s %dx%d %d sommets build %.1fs rendu %.1fs" % (name, W, H, nverts, t_build, t_render),
              flush=True)


main()
