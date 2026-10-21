"""Pilote des rendus d'APERÇU du centre de commandement (lot V3-a, phase 1). Python système.

    python tools/render/with_render_lock.py -- python -P tools/render/pieces/levels/centre/render_centre.py \
        [--levels 1-15] [--samples 64] [--mask-samples 8] [--only full|masks]

Toujours lancé SOUS le verrou de rendu (CLAUDE.md §4, interdit 6). N'écrit que dans :
  tools/render/out/levels/centre/   (aperçus : 4 couches hr + lr, masques, json ; ignoré par git)
  tools/render/cache/levels-centre/ (rendus 16 bits bruts, EFFACÉS après chaque niveau : disque limité)
Réutilise sans les modifier fo_blender.render (appel de Blender) et fo_post (post-traitement V0).
Différences avec render.py (pipeline partagé) : fenêtres de halo propres à chaque niveau
(centre_params.HALO), lumière de nuit seule aux époques 1-2 (variante « -nuit » : la lueur part dans la
couche halo), masques D1 sans couches plates (« -sil ») et sans tiges (« -mass »), purge des caches.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_blender  # noqa: E402
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import centre_params as PR  # noqa: E402

PIECE = os.path.join(HERE, "centre.py")
OUT = os.path.join(RENDER, "out", "levels", "centre")
CACHE = os.path.join(RENDER, "cache", "levels-centre")
MARGIN = 40


def parse_levels(s):
    out = []
    for part in s.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return out


def load_npy(info, layer):
    p = os.path.join(info["_dir"], "%s-%s.npy" % (info["_prefix"], layer))
    return np.load(p).astype(np.float64) if os.path.exists(p) else None


def purge(info):
    d, pre = info["_dir"], info["_prefix"]
    for fn in os.listdir(d):
        if fn.startswith(pre + "-") and (fn.endswith(".png") or fn.endswith(".npy")):
            os.remove(os.path.join(d, fn))


def run_blender(variant, samples, layers, log, dump=None):
    if dump:
        os.environ["FO_CENTRE_DUMP"] = dump
    else:
        os.environ.pop("FO_CENTRE_DUMP", None)
    info, dt = fo_blender.render(PIECE, variant, CACHE, samples=samples, layers=layers, margin=MARGIN, log=log)
    return info, dt


def halo_layer(light, origin, e):
    """Couche halo bornée par des fenêtres circulaires (même principe que render.py) : chaque fenêtre ne
    change que l'alpha de la même couche, donc l'union des fenêtres = maximum des alphas."""
    lay = P.additive_layer(light)
    alpha = None
    for (x, ty, z, _col, _pw, r0, r1, g0, g1) in PR.HALO.get(e, []):
        wins = [((x, ty, z), (r0, r1))]
        if g1 > 0:
            wins.append(((x, ty, 0.0), (g0, g1)))
        for (cx, cty, cz), (a, b) in wins:
            u, v = C.blender_to_screen_px(0.0, 0.0, cz)
            center = (origin[0] + cx * 64.0 + u, origin[1] + cty * 64.0 + v)
            wa = P.radial_window(lay, center, a * 64, b * 64)[..., 3]
            alpha = wa if alpha is None else np.maximum(alpha, wa)
    if alpha is None:
        return None
    out = lay.copy()
    out[..., 3] = alpha
    return P.floor_alpha(P.fade_edges(out))


def write_layer(img, origin, layer, name, dest):
    box = P.trim_box(img, origin)
    if box is None:
        return None
    x0, y0, x1, y1 = box
    crop = img[y0:y1, x0:x1]
    lr = P.downsample2_additive(crop) if layer in ("glow", "light") else P.downsample2(crop)
    fn_hr, fn_lr = "hr-%s-%s.png" % (name, layer), "%s-%s.png" % (name, layer)
    h_hr = P.write_png(crop, os.path.join(dest, fn_hr))
    h_lr = P.write_png(lr, os.path.join(dest, fn_lr))
    sd_hr, sd_lr = P.sprite_def(box, origin, 64), P.sprite_def(box, origin, 32)
    return {"hr": dict(sd_hr, filename=fn_hr, sha256=h_hr), "lr": dict(sd_lr, filename=fn_lr, sha256=h_lr)}


def save_mask(alpha, origin, path):
    """Masque binaire (alpha ≥ 0,5) recadré, avec la position de l'origine de l'entité dans le recadrage."""
    m = alpha >= 0.5
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    np.savez_compressed(path, mask=np.packbits(m[y0:y1, x0:x1], axis=1), shape=np.array([y1 - y0, x1 - x0]),
                        origin=np.array([origin[0] - x0, origin[1] - y0]))


def render_level(e, samples, mask_samples, what, log):
    name = "centre-n%02d" % e
    dest = os.path.join(OUT, "n%02d" % e)
    os.makedirs(dest, exist_ok=True)
    rec = {"level": e, "epoch": e, "name": PR.NAMES[e], "variant": "n%02d" % e}
    t0 = time.time()
    if what in ("all", "full"):
        dump = os.path.join(dest, "pieces.json")
        if e in PR.NIGHT_ONLY:
            ij, dt1 = run_blender("n%02d-jour" % e, samples, ["main", "ao", "shadow"], log, dump=dump)
            inn, dt2 = run_blender("n%02d-nuit" % e, samples, ["glow", "light"], log)
            if ij["canvas"] != inn["canvas"] or ij["origin_px"] != inn["origin_px"]:
                raise RuntimeError("jour et nuit sur des canevas différents : %s / %s" % (ij["canvas"], inn["canvas"]))
            infos = [ij, inn]
        else:
            ij, dt1 = run_blender("n%02d" % e, samples, None, log, dump=dump)
            infos = [ij]
        origin = tuple(ij["origin_px"])
        main = P.compose_main(load_npy(ij, "main"), load_npy(ij, "ao"), C)
        layers = {"main": main, "shadow": P.shadow_layer(load_npy(ij, "shadow"))}
        src = infos[-1]
        g = load_npy(src, "glow")
        if g is not None:
            layers["glow"] = P.additive_layer(g)
        li = load_npy(src, "light")
        if li is not None:
            hl = halo_layer(li, origin, e)
            if hl is not None:
                layers["light"] = hl
        spec = {}
        for layer, img in layers.items():
            sd = write_layer(img, origin, layer, name, dest)
            if sd:
                spec[layer] = sd
        save_mask(main[..., 3], origin, os.path.join(dest, "mask-full.npz"))
        rec.update({"spec": spec, "canvas": ij["canvas"], "origin_px": ij["origin_px"], "samples": ij["samples"],
                    "seed": ij["seed"], "blender": ij["blender"], "blender_hash": ij["blender_hash"]})
        for inf in infos:
            purge(inf)
    if what in ("all", "masks"):
        for suf in ("sil", "mass"):
            im, _ = run_blender("n%02d-%s" % (e, suf), mask_samples, ["main"], log)
            a = load_npy(im, "main")[..., 3]
            save_mask(a, tuple(im["origin_px"]), os.path.join(dest, "mask-%s.npz" % suf))
            purge(im)
    rec["seconds"] = round(time.time() - t0, 1)
    old = {}
    pj = os.path.join(dest, "render.json")
    if os.path.exists(pj):
        with open(pj, encoding="utf-8") as f:
            old = json.load(f)
    old.update(rec)
    with open(pj, "w", encoding="utf-8") as f:
        json.dump(old, f, indent=1, sort_keys=True)
    return old


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="1-15")
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--mask-samples", type=int, default=8)
    ap.add_argument("--only", default="all", choices=("all", "full", "masks"))
    a = ap.parse_args()
    os.makedirs(CACHE, exist_ok=True)
    log = os.path.join(CACHE, "blender.log")
    t0 = time.time()
    for e in parse_levels(a.levels):
        r = render_level(e, a.samples, a.mask_samples, a.only, log)
        print("[FO-CENTRE] n%02d %-28s %6.1f s" % (e, PR.NAMES[e], r["seconds"]), flush=True)
    # le journal Blender peut grossir : on le garde court
    if os.path.exists(log) and os.path.getsize(log) > 4_000_000:
        with open(log, "rb") as f:
            f.seek(-1_000_000, 2)
            tail = f.read()
        with open(log, "wb") as f:
            f.write(tail)
    print("[FO-CENTRE] total %.1f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
