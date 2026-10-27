"""Rendu + post-traitement de la mitrailleuse « industriel lourd » (lot V3-S).

    python tools/render/pieces/levels/gun_s_industriel/rendre.py [--only a,b] [--samples 128] [--quick]
                                                                 [--post-only]

1. Les variantes demandées sont rendues dans UNE session Blender (batch_blender.py), lancée par le verrou de
   rendu prescrit (interdit n° 6) : « python tools/render/with_render_lock.py -- <blender ...> » (2 rendus au
   plus sur le PC, priorité inférieure à la normale ; attente interne à 5 s, aucun essai en boucle serrée).
2. Post-traitement avec tools/render/fo_post.py (inchangé) : liseré de contact sous la couche principale du
   socle, ombre (noir, alpha), lueur additive (RGB = c/max, A = max), halo V0b (valeurs linéaires, pièce
   découpée) borné par une fenêtre radiale autour de l'entité et normalisé au sol (pic 0,45 : plage vanilla
   0,30-0,55, fo_calib.LIGHT_PEAK_RANGE) ; recadrage sur la grille paire, shift exact.
3. Sortie (non versionnée) : tools/render/out/levels/gun_s_industriel/<variante>/hr-gunind-<variante>-<couche>.png
   et spec.json (largeur, hauteur, shift hr, durées). Journal des durées : <cache>/temps.json.
"""
import argparse
import json
import os
import shutil
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
import fo_post as P  # noqa: E402
import ind  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_blender.py")
WORK = os.environ.get("FO_IND_WORK", "F:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-22_V3S/industriel")
CACHE = os.path.join(WORK, "cache")
OUT = os.path.join(WORK, "out")
HALO_PEAK = 0.45


def post(name):
    d = os.path.join(CACHE, name)
    with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
        info = json.load(f)
    meta = ind.PIECE["variants"][name]
    origin = tuple(info["origin_px"])

    def npy(layer):
        if layer not in info.get("layers", []):
            return None  # passe d'un rendu précédent (autre canevas) : ignorée
        p = os.path.join(d, "%s-%s.npy" % (name, layer))
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
    if li is not None:
        free = np.minimum(li[..., 3], 1.0 - np.clip(main_raw[..., 3], 0, 1))
        lay = P.light_layer(np.concatenate([li[..., :3], free[..., None]], -1), C.LIGHT_SCALE)
        side = ind.SIDE[meta["epoch"]]
        lay = P.radial_window(lay, origin, (0.5 * side + 0.15) * 64, (0.5 * side + 1.25) * 64)
        ground = (free > 0.5) & (lay[..., 3] > 0)
        ref = np.percentile(lay[..., 3][ground], 99.5) if ground.any() else 0.0
        if ref > 1e-6:
            lay[..., 3] = np.minimum(1.0, lay[..., 3] * HALO_PEAK / ref)
        hr["light"] = P.floor_alpha(P.fade_edges(lay))
    out = os.path.join(OUT, name)
    os.makedirs(out, exist_ok=True)
    spec = {"variant": name, "level": meta["level"], "epoch": meta["epoch"], "part": meta["part"],
            "dir": meta.get("dir"), "samples": info["samples"], "seconds": info["seconds"],
            "seconds_render": info.get("seconds_render"), "verts": info.get("verts"), "count": info.get("count"),
            "quick": info.get("quick"), "canvas": info["canvas"], "layers": {}}
    for layer in ("main", "shadow", "glow", "light"):
        if layer not in hr:
            continue
        box = P.trim_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        fn = "hr-gunind-%s-%s.png" % (name, layer)
        sha = P.write_png(hr[layer][y0:y1, x0:x1], os.path.join(out, fn))
        sd = P.sprite_def(box, origin, 64)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha}
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--post-only", action="store_true")
    a = ap.parse_args()
    names = [n for n in a.only.split(",") if n] or sorted(ind.PIECE["variants"])
    os.makedirs(CACHE, exist_ok=True)
    if not a.post_only:
        cmd = [sys.executable, LOCK, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1", "-P", BATCH, "--",
               "--names", ",".join(names), "--out", CACHE, "--samples", str(a.samples)]
        if a.quick:
            cmd.append("--quick")
        t0 = time.time()
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
        log = []
        t_lock = None
        for raw in p.stdout:
            line = raw.decode("utf-8", "replace").rstrip()
            log.append(line)
            if t_lock is None and ("Blender" in line or "[FO-RENDER]" in line or "Read prefs" in line):
                t_lock = time.time() - t0
            if line.startswith("[FO-RENDER]") or line.startswith("[fo-render]") or "Error" in line or "Traceback" in line:
                print(line, flush=True)
        rc = p.wait()
        dt = time.time() - t0
        with open(os.path.join(CACHE, "rendre.log"), "a", encoding="utf-8") as f:
            f.write("\n".join(log[-400:]) + "\n")
        tj = os.path.join(CACHE, "temps.json")
        hist = json.load(open(tj, encoding="utf-8")) if os.path.exists(tj) else []
        hist.append({"date": time.strftime("%Y-%m-%d %H:%M:%S"), "names": names, "samples": a.samples, "quick": a.quick,
                     "total_s": round(dt, 1), "attente_verrou_et_demarrage_s": round(t_lock or 0, 1), "code": rc})
        with open(tj, "w", encoding="utf-8") as f:
            json.dump(hist, f, indent=1)
        print("[FO-BATCH] %d variantes, %.0f s en tout (dont %.0f s avant la 1re sortie de Blender), code %d"
              % (len(names), dt, t_lock or 0, rc), flush=True)
        if rc != 0:
            print("\n".join(log[-60:]))
            sys.exit(rc)
    for n in names:
        if os.path.exists(os.path.join(CACHE, n, "render.json")):
            s = post(n)
            print("[FO-POST] %s %s %.0f s" % (n, sorted(s["layers"]), s["seconds"]), flush=True)


if __name__ == "__main__":
    main()
