"""RENDU DES EXPÉRIMENTAUX (lot RB-V0, 31/10). Blender par le verrou de rendu (interdit n° 6), TEMP/TMP sur F: (C: est plein le 31/10).

    py -3.9 tools/render/pieces/experimentaux/rendre.py --names ixion,bourdon,battant --out DIR --cache DIR
        [--samples 16] [--px 16] [--gris] [--denoise] [--post-only] [--grade tp,tk,sp,g,ga,s]

Sorties : <out>/<nom>/{main,shadow,glow_<groupe>}.png (RGBA 8 bits, recadrés, shift en tuiles depuis la position au sol) et spec.json.
"""
import argparse
import json
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, RENDER)
import fo_post as P  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_blender.py")
TMP = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-31_ROBOTS\experimentaux\tmp"


def etalonne(img, grade):
    """Même courbe que le QG validé (vaisseau_o/rendre.py) : pied, épaule, gamma, saturation ; hors Blender."""
    tp, tk, sp, g, ga, sat = grade
    out = img.copy()
    rgb = np.clip(out[..., :3], 0.0, 1.0)
    lu = np.maximum((0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2])[..., None], 1e-5)
    l2 = lu ** ga
    l2 = np.where(l2 < tp, tp * (l2 / tp) ** tk, l2)
    l2 = np.where(l2 > sp, sp + (l2 - sp) * g, l2)
    rgb = rgb * l2 / lu
    rgb = l2 + (rgb - l2) * sat
    out[..., :3] = np.clip(rgb, 0.0, 1.0)
    return out


def ecrit(img8, path):
    Image.fromarray(img8, "RGBA").save(path, compress_level=4)


def post(name, cache, out_root, grade):
    d = os.path.join(cache, name)
    info = json.load(open(os.path.join(d, "render.json"), encoding="utf-8"))
    ox, oy = info["origin_px"]
    px = float(info["px"])
    out = os.path.join(out_root, name)
    os.makedirs(out, exist_ok=True)
    spec = {"variant": name, "px": px, "samples": info["samples"], "seconds": info["seconds"], "verts": info["verts"], "canvas": info["canvas"], "layers": {}}
    for layer in info["layers"]:
        a = np.load(os.path.join(d, "%s-%s.npy" % (name, layer))).astype(np.float32)
        if layer == "main":
            if grade:
                a = etalonne(a, grade).astype(np.float32)
        elif layer == "shadow":
            s = np.zeros(a.shape, np.float32)
            s[..., 3] = np.clip(a[..., 3], 0, 1)
            a = s
        else:
            a = P.additive_layer(a).astype(np.float32)
        if layer == "shadow" and info.get("ombre_pct", 100) != 100:
            # l'ombre est rendue en réduit : recalage sur la grille du corps
            H, W = info["canvas"][1], info["canvas"][0]
            im = Image.fromarray(np.clip(a[..., 3] * 255, 0, 255).astype(np.uint8), "L").resize((W, H), Image.BILINEAR)
            s = np.zeros((H, W, 4), np.float32)
            s[..., 3] = np.asarray(im, np.float32) / 255.0
            a = s
        mask = a[..., 3] >= 1.0 / 255
        if not mask.any():
            continue
        ys, xs = np.nonzero(mask)
        x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
        crop = np.clip(np.round(a[y0:y1, x0:x1] * 255), 0, 255).astype(np.uint8)
        fn = "%s.png" % layer
        ecrit(crop, os.path.join(out, fn))
        spec["layers"][layer] = {"file": fn, "width": x1 - x0, "height": y1 - y0, "shift": [((x0 + x1) / 2.0 - ox) / px, ((y0 + y1) / 2.0 - oy) / px]}
    json.dump(spec, open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n"), indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", default="ixion,bourdon,battant")
    ap.add_argument("--out", required=True)
    ap.add_argument("--cache", required=True)
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--px", type=float, default=64.0)
    ap.add_argument("--ombre-spp", type=int, default=16)
    ap.add_argument("--ombre-pct", type=int, default=50)
    ap.add_argument("--lueur-spp", type=int, default=16)
    ap.add_argument("--gris", action="store_true")
    ap.add_argument("--denoise", action="store_true")
    ap.add_argument("--post-only", action="store_true")
    ap.add_argument("--sans-ombre", action="store_true")  # lot ART-MEGA2 : les tourelles du Méga-Bourdon n'ont pas d'ombre en jeu
    ap.add_argument("--grade", default="")
    a = ap.parse_args()
    names = [n for n in a.names.split(",") if n]
    t0 = time.time()
    if not a.post_only:
        os.makedirs(TMP, exist_ok=True)
        cmd = [sys.executable, LOCK, "--disque", a.cache, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1", "-P", BATCH, "--", "--names",
               ",".join(names), "--out", a.cache, "--samples", str(a.samples), "--px", str(a.px), "--ombre-spp", str(a.ombre_spp), "--ombre-pct", str(a.ombre_pct),
               "--lueur-spp", str(a.lueur_spp)] + (["--sans-ombre"] if a.sans_ombre else [])
        env = dict(os.environ, PYTHONIOENCODING="utf-8", TEMP=TMP, TMP=TMP, TMPDIR=TMP)
        if a.gris:
            env["FO_GRIS"] = "1"
        if a.denoise:
            env["FO_DENOISE"] = "1"
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
        log = []
        for raw in p.stdout:
            line = raw.decode("utf-8", "replace").rstrip()
            log.append(line)
            if line.startswith("[FO-RENDER]") or "Error" in line or "Traceback" in line or "[fo-render]" in line:
                print(line, flush=True)
        rc = p.wait()
        os.makedirs(a.cache, exist_ok=True)
        open(os.path.join(a.cache, "rendre.log"), "a", encoding="utf-8").write("\n".join(log[-300:]) + "\n")
        print("[FO-BATCH] %d variante(s), %.0f s, code %d" % (len(names), time.time() - t0, rc), flush=True)
        if rc:
            print("\n".join(log[-30:]))
            sys.exit(rc)
    grade = [float(x) for x in a.grade.split(",")] if a.grade else None
    for n in names:
        s = post(n, a.cache, a.out, grade)
        print("[FO-POST] %s %s" % (n, sorted(s["layers"])), flush=True)
    print("[FO-RENDRE] %.0f s en tout" % (time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
