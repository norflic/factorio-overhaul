"""RENDU DE LA FUSÉE (kit fusee_e, lot CENTRE-FUSEE, premier jet de concept) : version ALLÉGÉE de centre_e/rendre.py.

    py -3.9 tools/render/pieces/levels/fusee_e/rendre.py --names epave,age01,age04,age08,age15 --out DIR [--cache DIR]
        [--samples 32] [--post-only]

UNE session Blender pour toutes les variantes, lancée par le verrou de rendu (interdit n° 6 : « with_render_lock.py »,
une seule place prise). Passes de jour (main, ao, shadow, glow ; pas de halo de nuit : concept). Post-traitement par
fo_post (inchangé) : liseré de contact, ombre, lueur ; sorties hr-fus-<nom>-<couche>.png et spec.json (format lu par
commun/compo.py : couches, shift) dans <out>/<nom>/.
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
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import piece  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_blender.py")


def post(name, cache, out_root):
    d = os.path.join(cache, name)
    info = json.load(open(os.path.join(d, "render.json"), encoding="utf-8"))
    origin = tuple(info["origin_px"])

    def npy(layer):
        p = os.path.join(d, "%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if layer in info["layers"] and os.path.exists(p) else None

    hr = {"main": P.compose_main(npy("main"), npy("ao"), C)}
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    gl = npy("glow")
    if gl is not None:
        hr["glow"] = P.additive_layer(gl)
    out = os.path.join(out_root, name)
    os.makedirs(out, exist_ok=True)
    spec = {"variant": name, "epoch": piece.PIECE["variants"][name]["epoch"], "samples": info["samples"],
            "seconds": info["seconds"], "seconds_render": info.get("seconds_render"), "verts": info.get("verts"),
            "canvas": info["canvas"], "kit": "fusee_e", "layers": {}}
    for layer in ("main", "shadow", "glow"):
        if layer not in hr:
            continue
        box = P.trim_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop = hr[layer][y0:y1, x0:x1]
        fn = "hr-fus-%s-%s.png" % (name, layer)
        sha = P.write_png(crop, os.path.join(out, fn))
        sd = P.sprite_def(box, origin, 64)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha, "draw_as": {"shadow": "shadow", "glow": "glow"}.get(layer, "main")}
    json.dump(spec, open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n"), indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", default="epave,age01,age04,age08,age15")
    ap.add_argument("--out", required=True)
    ap.add_argument("--cache", default="")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--post-only", action="store_true")
    a = ap.parse_args()
    a.cache = a.cache or os.path.join(os.path.dirname(os.path.abspath(a.out)), "cache_" + os.path.basename(a.out))
    names = [n for n in a.names.split(",") if n]
    bad = [n for n in names if n not in piece.PIECE["variants"]]
    if bad:
        raise SystemExit("variantes inconnues : %s" % ", ".join(bad))
    os.makedirs(a.cache, exist_ok=True)
    t0 = time.time()
    if not a.post_only:
        cmd = [sys.executable, LOCK, "--disque", a.cache, "--disque", a.out, "--", BLENDER, "-b", "--factory-startup",
               "-noaudio", "--python-exit-code", "1", "-P", BATCH, "--", "--names", ",".join(names), "--out", a.cache,
               "--samples", str(a.samples), "--apercu"]
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
        log = []
        for raw in p.stdout:
            line = raw.decode("utf-8", "replace").rstrip()
            log.append(line)
            if line.startswith("[FO-RENDER]") or "Error" in line or "Traceback" in line or "line " in line:
                print(line, flush=True)
        rc = p.wait()
        open(os.path.join(a.cache, "rendre.log"), "a", encoding="utf-8").write("\n".join(log[-300:]) + "\n")
        print("[FO-BATCH] %d variante(s), %.0f s, code %d" % (len(names), time.time() - t0, rc), flush=True)
        if rc:
            print("\n".join(log[-40:]))
            sys.exit(rc)
    for n in names:
        s = post(n, a.cache, a.out)
        print("[FO-POST] %s %s %.0f s de rendu Blender" % (n, sorted(s["layers"]), s["seconds"]), flush=True)
    print("[FO-RENDRE] %.0f s en tout" % (time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
