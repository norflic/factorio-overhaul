"""RENDU d'une machine du kit machines (lot DESIGN-CALCUL CALC-MACHINES-AMONT) : copie de levels/vaisseau_o/rendre.py
(lot CENTRE-OPUS) ; ajoute --piece (dossier de la machine) et la couche halo de nuit (fo_post.light_layer, V0b).

    py -3.9 tools/render/pieces/machines/commun/rendre.py --piece tools/render/pieces/machines/cryogenique
        --names a,b,c --out DIR [--samples 12] [--post-only] [--jour]

UNE session Blender pour toutes les variantes, lancée par le verrou de rendu (interdit n° 6 : with_render_lock.py,
une seule place prise). Sorties : <out>/<nom>/hr-<machine>-<nom>-<couche>.png et spec.json (format lu par
levels/commun/compo.py : couches, shift en tuiles).
"""
import argparse
import importlib.util
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

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_blender.py")


def charger(piece_dir):
    p = os.path.join(piece_dir, "piece.py")
    sys.path.insert(0, piece_dir)
    spec = importlib.util.spec_from_file_location("fo_machine_meta", p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return p, mod.PIECE


def post(meta, name, cache, out_root):
    d = os.path.join(cache, name)
    info = json.load(open(os.path.join(d, "render.json"), encoding="utf-8"))
    origin = tuple(info["origin_px"])

    def npy(layer):
        p = os.path.join(d, "%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if layer in info["layers"] and os.path.exists(p) else None

    main_raw = npy("main")
    hr = {"main": P.compose_main(main_raw, npy("ao"), C)}
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    gl = npy("glow")
    if gl is not None:
        hr["glow"] = P.additive_layer(gl)
    li = npy("light")
    if li is not None:
        free = np.minimum(li[..., 3], 1.0 - np.clip(main_raw[..., 3], 0, 1))
        lay = P.light_layer(np.concatenate([li[..., :3], free[..., None]], -1),
                            C.LIGHT_SCALE * float(meta.get("light_scale", 1.0)))
        hr["light"] = P.floor_alpha(P.fade_edges(lay))
    out = os.path.join(out_root, name)
    os.makedirs(out, exist_ok=True)
    v = meta["variants"][name]
    spec = {"variant": name, "machine": meta["name"], "side": v["side"], "age": v.get("age"), "titre": v.get("titre", name),
            "samples": info["samples"], "seconds": info["seconds"], "verts": info.get("verts"),
            "canvas": info["canvas"], "kit": "machines", "count": info.get("count"), "layers": {}}
    for layer in ("main", "shadow", "glow", "light"):
        if layer not in hr:
            continue
        box = P.trim_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop = hr[layer][y0:y1, x0:x1]
        fn = "hr-%s-%s-%s.png" % (meta["name"], name, layer)
        sha = P.write_png(crop, os.path.join(out, fn))
        sd = P.sprite_def(box, origin, 64)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha}
    json.dump(spec, open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n"), indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--piece", required=True, help="dossier de la machine (contient piece.py)")
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--cache", default="")
    ap.add_argument("--samples", type=int, default=12)
    ap.add_argument("--post-only", action="store_true")
    ap.add_argument("--jour", action="store_true", help="sans passe halo (essais de forme)")
    a = ap.parse_args()
    piece_path, meta = charger(os.path.abspath(a.piece))
    a.cache = a.cache or os.path.join(os.path.dirname(os.path.abspath(a.out)), "cache_" + os.path.basename(a.out))
    names = [n for n in a.names.split(",") if n]
    bad = [n for n in names if n not in meta["variants"]]
    if bad:
        raise SystemExit("variantes inconnues : %s" % ", ".join(bad))
    os.makedirs(a.cache, exist_ok=True)
    t0 = time.time()
    if not a.post_only:
        layers = "main,ao,shadow,glow" + ("" if a.jour else ",light")
        cmd = [sys.executable, LOCK, "--disque", a.cache, "--disque", a.out, "--", BLENDER, "-b", "--factory-startup",
               "-noaudio", "--python-exit-code", "1", "-P", BATCH, "--", "--piece", piece_path, "--names", ",".join(names),
               "--out", a.cache, "--samples", str(a.samples), "--layers", layers]
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
        log = []
        for raw in p.stdout:
            line = raw.decode("utf-8", "replace").rstrip()
            log.append(line)
            if line.startswith("[FO-RENDER]") or "Error" in line or "Traceback" in line or "[FO-LOCK" in line:
                print(line, flush=True)
        rc = p.wait()
        open(os.path.join(a.cache, "rendre.log"), "a", encoding="utf-8").write("\n".join(log[-300:]) + "\n")
        print("[FO-BATCH] %d variante(s), %.0f s, code %d" % (len(names), time.time() - t0, rc), flush=True)
        if rc:
            print("\n".join(log[-40:]))
            sys.exit(rc)
    for n in names:
        s = post(meta, n, a.cache, a.out)
        print("[FO-POST] %s %s %.0f s de rendu Blender" % (n, sorted(s["layers"]), s["seconds"]), flush=True)
    print("[FO-RENDRE] %.0f s en tout" % (time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
