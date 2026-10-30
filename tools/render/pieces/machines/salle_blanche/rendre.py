"""RENDU DE LA SALLE BLANCHE (lot CALC-SALLE-BLANCHE, 30/10). Adapté de levels/assembleur_e/rendre.py (même
post-traitement fo_post : liseré de contact, ombre, lueur additive, halo V0b borné et normalisé au sol, pic 0,45).

    py -3.9 tools/render/pieces/machines/salle_blanche/rendre.py --out DIR [--only s1,s2] [--samples 12] [--apercu]
        [--post-only] [--keep-npy]

Blender SEULEMENT par le verrou de rendu (interdit n° 6) : une session par appel, une place au verrou.
Essais : --samples 8 à 12 --apercu (passes de jour). Rendu final : --samples 128 (toutes les passes, halo compris).
Sorties : DIR/<variante>/hr-sb-<variante>-<couche>.png (64 px/tuile) et sb-<variante>-<couche>.png (32 px/tuile),
spec.json (tailles, shift, sha256, contrôles, voyants à l'écran).
"""
import argparse
import json
import os
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_checks as FC  # noqa: E402
import fo_post as P  # noqa: E402
import piece  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_blender.py")
HALO_PEAK = 0.45
ALPHA_MIN = 12.0 / 255.0


def largest_hole(alpha):
    n, _, holes = FC.enclosed_transparent(alpha)
    if not n:
        return 0, 0, 0
    sys.path.insert(0, os.path.join(MOD, "tools", "da"))
    import da_lib as D
    sizes, _ = D.components(holes, conn8=False)
    return n, len(sizes), max(sizes.values())


def post(name, cache, out_root):
    d = os.path.join(cache, name)
    with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
        info = json.load(f)
    meta = piece.PIECE["variants"][name]
    origin = tuple(info["origin_px"])

    def npy(layer):
        if layer not in info.get("layers", []):
            return None
        p = os.path.join(d, "%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    main_raw = npy("main")
    hr = {"main": P.compose_main(main_raw, npy("ao"), C)}
    # bruit du liseré de contact à faible échantillonnage : pixels isolés presque transparents loin du corps (essai
    # r2b à 12 échantillons : un pixel d'alpha 10/255 à 1,4 tuile du corps élargissait la feuille de 80 px)
    hr["main"][..., 3] = np.where(hr["main"][..., 3] < ALPHA_MIN, 0.0, hr["main"][..., 3])
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
    li = npy("light")
    if li is not None:
        free = np.minimum(li[..., 3], 1.0 - np.clip(main_raw[..., 3], 0, 1))
        lay = P.light_layer(np.concatenate([li[..., :3], free[..., None]], -1), C.LIGHT_SCALE)
        side = meta["side"]
        lay = P.radial_window(lay, origin, (0.5 * side + 0.15) * 64, (0.5 * side + 1.25) * 64)
        ground = (free > 0.5) & (lay[..., 3] > 0)
        ref = np.percentile(lay[..., 3][ground], 99.5) if ground.any() else 0.0
        if ref > 1e-6:
            lay[..., 3] = np.minimum(1.0, lay[..., 3] * HALO_PEAK / ref)
        hr["light"] = P.floor_alpha(P.fade_edges(lay))
    out = os.path.join(out_root, name)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png"):
            os.remove(os.path.join(out, f))
    spec = {"variant": name, "epoch": meta["epoch"], "side": meta["side"], "samples": info["samples"],
            "seconds": info["seconds"], "verts": info.get("verts"), "count": info.get("count"),
            "apercu": info.get("apercu"), "canvas": info["canvas"], "origin_px": info["origin_px"],
            "leds": info.get("leds", []), "kit": "salle_blanche", "layers": {}}
    for layer in ("main", "shadow", "glow", "light"):
        if layer not in hr:
            continue
        img = hr[layer]
        box = P.trim_box(img, origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop = img[y0:y1, x0:x1]
        crop_lr = P.downsample2_additive(crop) if layer in ("glow", "light") else P.downsample2(crop)
        fn = "hr-sb-%s-%s.png" % (name, layer)
        fn_lr = "sb-%s-%s.png" % (name, layer)
        sha = P.write_png(crop, os.path.join(out, fn))
        sha_lr = P.write_png(crop_lr, os.path.join(out, fn_lr))
        sd = P.sprite_def(box, origin, 64)
        sd_lr = P.sprite_def(box, origin, 32)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "box": [int(x0), int(y0), int(x1), int(y1)], "sha256": sha,
                                 "lr": dict(sd_lr, file=fn_lr, sha256=sha_lr)}
    n, ng, big = largest_hole(main_raw[..., 3])
    thin, thin_part = FC.thin_pixels(hr["main"][..., 3])
    spec["checks"] = {"enclosed_transparent_px": int(n), "enclosed_groups": int(ng), "largest_hole_px": int(big),
                      "holes_ok": bool(big <= 8), "thin_px": int(thin), "thin_part": float(thin_part)}
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    return spec


def session(names, a):
    cmd = [sys.executable, LOCK, "--disque", a.cache, "--disque", a.out, "--", BLENDER, "-b", "--factory-startup",
           "-noaudio", "--python-exit-code", "1",
           "-P", BATCH, "--", "--names", ",".join(names), "--out", a.cache, "--samples", str(a.samples)]
    if a.apercu:
        cmd.append("--apercu")
    t0 = time.time()
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    env.pop("FO_CORPS", None)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    log = []
    for raw in p.stdout:
        line = raw.decode("utf-8", "replace").rstrip()
        log.append(line)
        if line.startswith("[FO-RENDER]") or "Error" in line or "Traceback" in line or "verrou" in line.lower():
            print(line, flush=True)
    rc = p.wait()
    with open(os.path.join(a.cache, "rendre.log"), "a", encoding="utf-8") as f:
        f.write("\n".join(log[-400:]) + "\n")
    print("[FO-BATCH] %d variantes, %.0f s, code %d" % (len(names), time.time() - t0, rc), flush=True)
    if rc != 0:
        print("\n".join(log[-60:]))
    return rc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=",".join(piece.VARIANTES))
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--apercu", action="store_true")
    ap.add_argument("--post-only", action="store_true")
    ap.add_argument("--keep-npy", action="store_true")
    ap.add_argument("--out", required=True)
    ap.add_argument("--cache", default="")
    a = ap.parse_args()
    a.cache = a.cache or os.path.join(os.path.dirname(os.path.abspath(a.out)), "cache_" + os.path.basename(a.out))
    names = [n for n in a.only.split(",") if n]
    bad = [n for n in names if n not in piece.PIECE["variants"]]
    if bad:
        raise SystemExit("variantes inconnues : %s" % ", ".join(bad))
    os.makedirs(a.cache, exist_ok=True)
    rc = 0
    if not a.post_only:
        rc = session(names, a)
    for n in names:
        if not os.path.exists(os.path.join(a.cache, n, "render.json")):
            continue
        if not any(f.endswith(".npy") for f in os.listdir(os.path.join(a.cache, n))):
            print("[FO-POST] %s : passes déjà purgées" % n)
            continue
        s = post(n, a.cache, a.out)
        if not a.keep_npy:
            for f in os.listdir(os.path.join(a.cache, n)):
                if f.endswith(".npy"):
                    os.remove(os.path.join(a.cache, n, f))
        c = s["checks"]
        print("[FO-POST] %s %s ; trous %d px (plus grand %d) %s ; voyants %d" % (
            n, sorted(s["layers"]), c["enclosed_transparent_px"], c["largest_hole_px"],
            "OK" if c["holes_ok"] else "ECHEC", len(s["leds"])), flush=True)
    sys.exit(rc)


if __name__ == "__main__":
    main()
