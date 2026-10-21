"""Tourelle laser, lot V3 phase 1 : post-traitement des passes Blender en 4 couches d'aperçu (Python système).

Entrées  : tools/render/cache/levels-laser/L<NN>/<partie>-<passe>.npz (+ .json)
Sorties  : tools/render/out/levels/laser/L<NN>/<partie>-{main,shadow,glow,light}.png (canevas FIXE commun,
           64 px/tuile, origine laser_design.ORIGIN_PX) et L<NN>/<partie>.json (boîte de recadrage, taille et
           shift du sprite recadré, comme le ferait tools/render/render.py en phase 2).
Fonctions du pipeline réutilisées SANS modification : tools/render/fo_post.py (liseré, ombre, couches additives,
fenêtres radiales, recadrage aligné sur la grille paire, définition de sprite).

Niveau 2 (pièce d'époque 1 posée sur le vanilla) : procédé de la variante « four » de V0. La passe « front »
(objets derrière le socle vanilla en cache) et la passe complète donnent la contribution des objets
« derrière », masquée au pixel par l'alpha du socle vanilla hr posé à son shift (turrets.lua:953-962).
"""
import json
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, RENDER)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import laser_design as D  # noqa: E402

RAW = os.path.join(RENDER, "cache", "levels-laser")
OUT = os.path.join(RENDER, "out", "levels", "laser")
DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
K = math.sqrt(0.5)


def load(path):
    return np.load(path)["a"].astype(np.float64) / 65535.0


def vanilla_alpha(spec, canvas_shape, origin, ppt=64):
    """Alpha d'une couche vanilla posée sur le canevas (même grille)."""
    im = np.asarray(Image.open(os.path.join(DATA, "base", "graphics", "entity", spec["file"])).convert("RGBA"))
    a = im[:spec["h"], :spec["w"], 3].astype(np.float64) / 255.0
    H, W = canvas_shape
    x0 = origin[0] + spec["shift"][0] * ppt - spec["w"] / 2.0
    y0 = origin[1] + spec["shift"][1] * ppt - spec["h"] / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    assert abs(x0 - xi) < 1e-6 and abs(y0 - yi) < 1e-6, (spec, x0, y0)
    out = np.zeros((H, W))
    out[yi:yi + spec["h"], xi:xi + spec["w"]] = a
    return out


def to_pm(img):
    return np.concatenate([P.srgb_to_lin(img[..., :3]) * img[..., 3:4], img[..., 3:4]], -1)


def from_pm(pm):
    a = np.clip(pm[..., 3:4], 0, 1)
    rgb = np.where(a > 1e-8, pm[..., :3] / np.maximum(a, 1e-8), 0)
    return np.concatenate([P.lin_to_srgb(rgb), a], -1)


def screen_px(loc, origin):
    x, y, z = loc
    u, v = C.blender_to_screen_px(x, y, z)
    return origin[0] + u, origin[1] + v


def halo_layer(li, meta, level, origin):
    """Halo de nuit borné (fenêtres radiales autour du pied de chaque source et de la source) et normalisé :
    maximum au sol = LIGHT_MAX × I(N)/I(30), I(N) = 0,05 + 0,02 N (bible §1.6, D2-3)."""
    lay = P.additive_layer(li)
    S = D.halo_size(level)               # « taille » du halo en tuiles (diamètre)
    best = None
    for h in meta["halos"]:
        x, y, z = h["loc"]
        for (cz, r0, r1) in ((0.0, 0.25 * S, 0.5 * S), (z, 0.25, 0.6)):
            c = screen_px((x, y, cz), origin)
            wl = P.radial_window(lay, c, r0 * 64, r1 * 64)
            best = wl if best is None else np.concatenate([wl[..., :3], np.maximum(best[..., 3:], wl[..., 3:])], -1)
    if best is None:
        return None
    out = P.floor_alpha(P.fade_edges(best))
    return out


def normalize_light(light, main_alpha, level):
    target = C.LIGHT_MAX * D.halo_intensity(level) / D.halo_intensity(30)
    ground = light[..., 3] * (main_alpha < 0.05)
    m = ground.max()
    if m > 1e-6:
        g = min(4.0, target / m)
        light = light.copy()
        light[..., 3] = np.clip(light[..., 3] * g, 0, 1)
    return light


def write(img, path):
    return P.write_png(img, path)


def process(level, part):
    src = os.path.join(RAW, "L%02d" % level)
    jm = os.path.join(src, "%s.json" % part)
    if not os.path.exists(jm):
        return None
    with open(jm, encoding="utf-8") as f:
        meta = json.load(f)
    origin = tuple(meta["origin_px"])

    def npz(name):
        p = os.path.join(src, "%s-%s.npz" % (part, name))
        return load(p) if os.path.exists(p) else None

    main = npz("main")
    ao = npz("ao")
    lay = {}
    full = P.compose_main(main, ao, C)
    front = npz("front")
    if front is not None:
        m = vanilla_alpha(D.VANILLA["base"], full.shape[:2], origin)
        Fp, Mp = to_pm(front), to_pm(full)
        full = from_pm(Fp + (Mp - Fp) * (1.0 - m)[..., None])
    lay["main"] = full
    sh = npz("shadow")
    if sh is not None:
        lay["shadow"] = P.shadow_layer(sh)
    g = npz("glow")
    if g is not None:
        lay["glow"] = P.additive_layer(g)
    li = npz("light")
    if li is not None:
        hl = halo_layer(li, meta, level, origin)
        if hl is not None:
            lay["light"] = normalize_light(hl, full[..., 3], level)
    dst = os.path.join(OUT, "L%02d" % level)
    os.makedirs(dst, exist_ok=True)
    spec = {}
    for k, img in lay.items():
        sha = write(img, os.path.join(dst, "%s-%s.png" % (part, k)))
        box = P.trim_box(img, origin)
        if box is None:
            continue
        hr = P.sprite_def(box, origin, 64)
        lr = P.sprite_def(box, origin, 32)
        spec[k] = {"box_px": list(box), "hr": hr, "lr": lr, "sha256_canvas": sha}
    rep = {"level": level, "part": part, "epoch": meta["epoch"], "heading_deg": meta["heading_deg"],
           "layers": spec, "render": {k: meta[k] for k in ("samples", "pass_samples", "seconds", "blender", "seed",
                                                            "objects", "holdout_objects", "back_objects")},
           "halos": meta["halos"]}
    with open(os.path.join(dst, "%s.json" % part), "w", encoding="utf-8") as f:
        json.dump(rep, f, indent=1, sort_keys=True)
    return rep


def run(levels, purge=False):
    for lv in levels:
        for part in ("base", "N", "E", "S", "W"):
            r = process(lv, part)
            if r:
                print("[post] L%02d %-4s %s" % (lv, part, ",".join(sorted(r["layers"]))), flush=True)
        if purge:
            # les .npz (≈ 0,3 Mo chacun) ne servent plus : disque H: limité (cadre commun)
            d = os.path.join(RAW, "L%02d" % lv)
            if os.path.isdir(d):
                for fn in os.listdir(d):
                    if fn.endswith(".npz"):
                        os.remove(os.path.join(d, fn))


if __name__ == "__main__":
    lv = [int(x) for x in sys.argv[1:]] or list(range(2, 31))
    run(lv, purge=False)
