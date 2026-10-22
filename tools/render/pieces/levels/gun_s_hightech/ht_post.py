"""Post-traitement (Python système) des rendus de ht_blender.py en couches de sprite Factorio, hr (64 px/tuile,
scale 0,5) et normale (32 px/tuile) : principale (+ liseré de contact pour le socle), ombre, lueur
(draw_as_glow), halo (draw_as_light, V0b : valeurs linéaires, pièce découpée). Fonctions de tools/render/fo_post.py
(inchangé), même logique que render.py (mode « v0b ») et render_gun.py de V3 phase 1.

    python ht_post.py --names n29-socle,n29-tete-E [--cache <dossier>] [--out <dossier>]

Sorties : <out>/<variante>/hr-ht-<variante>-<couche>.png, ht-<variante>-<couche>.png (32 px) et spec.json.
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_checks as FC  # noqa: E402
import fo_post as P  # noqa: E402
import ht_gun as H  # noqa: E402

CACHE = os.path.join(RENDER, "cache", "levels-gun-s-hightech")
OUT = os.path.join(RENDER, "out", "levels", "gun_s_hightech")
LAYERS = ("main", "shadow", "glow", "light")


def post(name, cache=CACHE, out_root=OUT):
    d = os.path.join(cache, name)
    with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
        info = json.load(f)
    meta = H.VARIANTS[name]
    lv = meta["level"]
    side = H.LEVELS[lv]["side"]
    origin = tuple(info["origin_px"])

    def npy(layer):
        p = os.path.join(d, "ht-%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    main_raw = npy("main")
    hr = {"main": P.compose_main(main_raw, npy("ao"), C)}
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
    li = npy("light")
    halo = {}
    if li is not None:
        # V0b : valeurs linéaires, aucun halo sur la pièce (min(alpha du rendu halo, 1 - alpha de la principale))
        free = np.minimum(li[..., 3], 1.0 - np.clip(main_raw[..., 3], 0, 1))
        lay = P.light_layer(np.concatenate([li[..., :3], free[..., None]], -1), C.LIGHT_SCALE)
        # fenêtre : plein jusqu'au bord de l'emprise, nul HALO_EXTRA tuile au-delà, centrée sur l'entité au sol
        r0, r1 = side / 2.0 * 64, (side / 2.0 + H.HALO_EXTRA) * 64
        lay = P.radial_window(lay, origin, r0, r1)
        # normalisation : maximum AU SOL (hors silhouette) = LIGHT_MAX × gain du niveau (charte §8.6, bible §1.6)
        ground = (hr["main"][..., 3] < 0.05) & (lay[..., 3] > 0)
        ref = float(np.percentile(lay[..., 3][ground], 99.5)) if ground.any() else float(lay[..., 3].max())
        target = C.LIGHT_MAX * H.HALO_GAIN[lv]
        if ref > 1e-6:
            lay[..., 3] = np.minimum(1.0, lay[..., 3] * target / ref)
        hr["light"] = P.floor_alpha(P.fade_edges(lay))
        halo = {"ref_p995": ref, "target": target}
    out = os.path.join(out_root, name)
    os.makedirs(out, exist_ok=True)
    spec = {"variant": name, "level": lv, "epoch": H.LEVELS[lv]["epoch"], "part": meta["part"], "dir": meta.get("dir"),
            "side": side, "render": info, "halo": halo, "layers": {}}
    for layer in LAYERS:
        if layer not in hr:
            continue
        img = hr[layer]
        box = P.trim_box(img, origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop = img[y0:y1, x0:x1]
        crop_lr = P.downsample2_additive(crop) if layer in ("glow", "light") else P.downsample2(crop)
        fn = "hr-ht-%s-%s.png" % (name, layer)
        fn_lr = "ht-%s-%s.png" % (name, layer)
        sha = P.write_png(crop, os.path.join(out, fn))
        sha_lr = P.write_png(crop_lr, os.path.join(out, fn_lr))
        sd = P.sprite_def(box, origin, 64)
        sd_lr = P.sprite_def(box, origin, 32)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha, "lr": dict(sd_lr, file=fn_lr, sha256=sha_lr)}
    # contrôle bloquant du pipeline : pixels transparents enfermés dans la silhouette (le sol se voit au travers)
    enc = FC.enclosed_transparent(hr["main"][..., 3])[0]
    thin, thin_part = FC.thin_pixels(hr["main"][..., 3])
    spec["checks"] = {"enclosed_transparent_px": int(enc), "thin_px": int(thin), "thin_part": float(thin_part)}
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    return spec


def manifest(names, out_root, path, extra=None):
    """Manifeste des sprites produits : couches (fichier, taille, shift, SHA-256 hr et 32 px), réglages et temps de
    rendu de chaque variante, contrôles du pipeline (trous enfermés, éléments fins)."""
    m = {"piece": "gun_s_hightech", "variants": {}}
    if extra:
        m.update(extra)
    for n in names:
        with open(os.path.join(out_root, n, "spec.json"), encoding="utf-8") as f:
            sp = json.load(f)
        r = sp["render"]
        m["variants"][n] = {"level": sp["level"], "epoch": sp["epoch"], "part": sp["part"], "dir": sp["dir"],
                            "side": sp["side"], "layers": sp["layers"], "checks": sp["checks"], "halo": sp["halo"],
                            "render": {k: r[k] for k in ("canvas", "origin_px", "samples", "seed", "blender",
                                                         "blender_hash", "seconds", "seconds_pass", "faces",
                                                         "primitives", "light_holdout") if k in r}}
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(m, f, indent=1, sort_keys=True, ensure_ascii=False)
    return m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--cache", default=CACHE)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    for n in [x for x in a.names.split(",") if x]:
        s = post(n, a.cache, a.out)
        print("[FO-POST] %s : %s ; trous enfermés %d px" % (n, ", ".join(sorted(s["layers"])),
                                                          s["checks"]["enclosed_transparent_px"]), flush=True)


if __name__ == "__main__":
    main()
