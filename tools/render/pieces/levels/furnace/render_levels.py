"""Pilote des rendus d'APERÇU du four (lot V3, phase 1) : niveaux 2 à 30, pose de référence unique.

    python tools/render/with_render_lock.py -- python -P tools/render/pieces/levels/furnace/render_levels.py --levels 3,4
    options : --levels 2-30 | 3,4,5 ; --samples 64 (aperçu ; le final de la phase 2 sera à 256)

Réutilise le pipeline V0 SANS le modifier (fichiers partagés, lot V0b) : tools/render/fo_blender.py (appel de
Blender), blender/render_piece.py (passes main, ao, shadow, glow, light), fo_post.py (liseré de contact,
couches additives, recadrage pair, écriture), render.place_alpha (masque par un sprite vanilla).
Différences avec render.py, propres à cette famille :
- sorties dans tools/render/out/levels/furnace/nXX/ (ignoré par git), HR seulement (64 px/tuile) : la
  version 32 px/tuile se déduit par réduction en phase 2 ;
- une couche de plus, « objmask » : l'alpha de la passe principale AVANT le liseré de contact. C'est le
  masque de mesure D1 « sans couches plates au sol » (le liseré est une couche plate au sol) ;
- fenêtres de halo par niveau (furnace_levels.PIECE["variants"][v]["halo"]) et maximum du halo
  proportionnel au niveau (bible §1.6, D2-3) ;
- le cache Blender du niveau (PNG 16 bits et .npy) est supprimé après traitement (disque partagé).
"""
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_blender  # noqa: E402
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import params as PRM  # noqa: E402

PIECE_FILE = os.path.join(HERE, "furnace_levels.py")
OUT = os.path.join(RENDER, "out", "levels", "furnace")
CACHE = os.path.join(RENDER, "cache", "levels-furnace")
DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
LUMA = np.array([0.2126, 0.7152, 0.0722])


def load_piece():
    spec = importlib.util.spec_from_file_location("fo_furnace_meta", PIECE_FILE)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def parse_levels(s):
    out = []
    for part in s.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return [n for n in out if n in PRM.RENDERED]


def place_alpha(canvas_shape, origin, sprite_path, shift, px_per_tile):
    import render as R  # tools/render/render.py (lecture seule)
    return R.place_alpha(canvas_shape, origin, sprite_path, shift, px_per_tile)


def photometry(img):
    a = img[..., 3]
    m = a >= 0.5
    if not m.any():
        return {}
    L = img[..., :3] @ LUMA
    mx, mn = img[..., :3].max(-1), img[..., :3].min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    Lm = L[m]
    return {"L_p05": float(np.percentile(Lm, 5) * 255), "L_p50": float(np.percentile(Lm, 50) * 255),
            "L_p95": float(np.percentile(Lm, 95) * 255), "L_std": float(Lm.std() * 255), "sat": float(sat[m].mean())}


def light_max(n):
    """Maximum de la couche halo : croît avec le niveau (bible §1.6, D2-3) ; vanilla 0,79 (sol du four)."""
    return 0.45 + 0.35 * n / 30.0


def process(mod, n, samples, log):
    v = "n%02d" % n
    vm = mod.PIECE["variants"][v]
    cache = os.path.join(CACHE, v)
    if os.path.isdir(cache):
        shutil.rmtree(cache, ignore_errors=True)
    info, dt = fo_blender.render(PIECE_FILE, v, cache, samples=samples, log=log, margin=vm["margin_px"])
    d, pre = info["_dir"], info["_prefix"]

    def npy(layer):
        p = os.path.join(d, "%s-%s.npy" % (pre, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    origin = tuple(info["origin_px"])
    raw_main = npy("main")
    hr = {"main": P.compose_main(raw_main, npy("ao"), C)}
    om = np.zeros(raw_main.shape[:2] + (4,))
    om[..., 3] = raw_main[..., 3]
    hr["objmask"] = om
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
    li = npy("light")
    if li is not None and vm["halo"]:
        lay = P.additive_layer(li)
        best = None
        for (x, y, z, r0, r1) in vm["halo"]:
            u, vv = C.blender_to_screen_px(0.0, 0.0, z)
            center = (origin[0] + x * 64.0 + u, origin[1] + y * 64.0 + vv)
            wl = P.radial_window(lay, center, r0 * 64, r1 * 64)
            best = wl if best is None else np.concatenate([wl[..., :3], np.maximum(best[..., 3:], wl[..., 3:])], -1)
        best = P.floor_alpha(P.fade_edges(best))
        m = best[..., 3].max()
        if m > 1e-6:
            best[..., 3] = np.clip(best[..., 3] * (light_max(n) / m), 0, 1)
        hr["light"] = best
    if vm.get("mask"):
        mk = vm["mask"]["hr"]
        m_hr = place_alpha(hr["main"].shape[:2], origin, os.path.join(DATA, "base", "graphics", "entity", mk["file"]),
                           mk["shift"], 64)
        for key in ("main", "glow", "objmask"):
            if key in hr:
                hr[key] = P.mask_with(hr[key], m_hr)
    dest = os.path.join(OUT, v)
    if os.path.isdir(dest):
        shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest, exist_ok=True)
    spec = {}
    for layer in ("main", "shadow", "glow", "light", "objmask"):
        if layer not in hr:
            continue
        img = hr[layer]
        box = P.trim_box(img, origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        fn = "hr-furnace-%s-%s.png" % (v, layer)
        sha = P.write_png(img[y0:y1, x0:x1], os.path.join(dest, fn))
        sd = P.sprite_def(box, origin, 64)
        spec[layer] = dict(sd, filename=fn, sha256=sha, size_bytes=os.path.getsize(os.path.join(dest, fn)))
    res = {"level": n, "variant": v, "epoch": PRM.epoch_of(n), "layers": spec, "samples": info["samples"],
           "seed": info["seed"], "blender": info["blender"], "blender_hash": info["blender_hash"],
           "canvas": info["canvas"], "origin_px": info["origin_px"], "seconds_blender": round(dt, 1),
           "photometry_main": photometry(hr["main"]) if n != 2 else photometry(hr["main"]),
           "light_max": light_max(n) if "light" in spec else None}
    with open(os.path.join(dest, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1, sort_keys=True)
    shutil.rmtree(cache, ignore_errors=True)
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="2-30")
    ap.add_argument("--samples", type=int, default=64)
    a = ap.parse_args()
    mod = load_piece()
    os.makedirs(CACHE, exist_ok=True)
    log = os.path.join(CACHE, "blender.log")
    for n in parse_levels(a.levels):
        t0 = time.time()
        r = process(mod, n, a.samples, log)
        ph = r["photometry_main"]
        print("[FO-V3-FOUR] n%02d : %s ; L p50 %.0f (cible %d) ; %.1f s" % (
            n, ", ".join("%s %dx%d" % (k, s["width"], s["height"]) for k, s in sorted(r["layers"].items())),
            ph.get("L_p50", -1), PRM.PALETTE[PRM.epoch_of(n)]["L50"], time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
