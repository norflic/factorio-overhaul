"""Rendu (par le verrou) et post-traitement des variantes de l'exploration hybride de la mitrailleuse.

    python tools/render/pieces/levels/gun_s_hybride/rendre.py [--names a,b] [--samples 128] [--post-only]
                                                               [--out <dossier des couches>]

1. UNE session Blender pour toutes les variantes demandées, lancée par la commande prescrite
   « python tools/render/with_render_lock.py -- <blender ...> » (2 rendus au plus sur le PC, priorité basse ;
   le script partagé attend lui-même une place, scrutation de 5 s).
2. Post-traitement (fonctions INCHANGÉES de tools/render/fo_post.py) : liseré de contact sous la couche
   principale du socle ; ombre (noir, alpha) ; lueur additive (RGB = c/max, A = max ; surfaces lumineuses
   ÉTEINTES dans la couche principale, main_scale = 0, comme la cheminée V0b) ; halo de nuit en valeurs
   linéaires (fo_post.light_layer), borné par une fenêtre radiale autour de la position de l'entité (plein
   jusqu'à 0,45 × côté, nul à 0,85 × côté : proposition de la charte §8.6, « rayon ≤ 1,5 × côté ») et normalisé
   au sol à LIGHT_MAX × I(N) / I(30), I(N) = 0,05 + 0,02 N (bible §1.6) ; recadrage sur la grille paire.
3. Sortie : <out>/<variante>/hr-hyb-<variante>-<couche>.png et spec.json (largeur, hauteur, shift hr, sommes).
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
MOD = os.path.normpath(os.path.join(RENDER, "..", ".."))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import design as Dz  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
CACHE = os.path.join(MOD, "tools", "render", "cache", "levels-gun-hybride")
OUT = os.path.join(MOD, "tools", "render", "out", "levels", "gun_s_hybride")
LOCK = os.path.join(RENDER, "with_render_lock.py")


def halo_target(level):
    i = lambda n: 0.05 + 0.02 * n
    return C.LIGHT_MAX * i(level) / i(30)


def light(li, main_a, origin, level):
    side = Dz.LEVELS[level]["side"]
    lay = P.light_layer(li)
    lay = P.radial_window(lay, origin, 0.45 * side * 64, 0.85 * side * 64)
    ground = (main_a < 0.05) & (lay[..., 3] > 0)
    ref = np.percentile(lay[..., 3][ground], 99.5) if ground.any() else lay[..., 3].max()
    if ref > 1e-6:
        lay[..., 3] = np.minimum(1.0, lay[..., 3] * halo_target(level) / ref)
    return P.floor_alpha(P.fade_edges(lay))


def post(name, cache, out_root):
    d = os.path.join(cache, name)
    with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
        info = json.load(f)
    meta = Dz.variants()[name]
    origin = tuple(info["origin_px"])

    def npy(layer):
        p = os.path.join(d, "hyb-%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    hr = {"main": P.compose_main(npy("main"), npy("ao"), C)}
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    gl = npy("glow")
    if gl is not None:
        hr["glow"] = P.additive_layer(gl)
    li = npy("light")
    if li is not None:
        hr["light"] = light(li, hr["main"][..., 3], origin, meta["level"])
    out = os.path.join(out_root, name)
    os.makedirs(out, exist_ok=True)
    spec = {"variant": name, "level": meta["level"], "part": meta["part"], "pose": meta.get("pose"),
            "samples": info["samples"], "seconds": info["seconds"], "seconds_by_pass": info.get("seconds_by_pass"),
            "canvas": info["canvas"], "vertices": info.get("vertices"), "counts": info.get("counts"), "layers": {}}
    for layer in ("main", "shadow", "glow", "light"):
        if layer not in hr:
            continue
        box = P.trim_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        fn = "hr-hyb-%s-%s.png" % (name, layer)
        sha = P.write_png(hr[layer][y0:y1, x0:x1], os.path.join(out, fn))
        sd = P.sprite_def(box, origin, 64)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha}
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", default="")
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--post-only", action="store_true")
    ap.add_argument("--cache", default=CACHE)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    names = [n for n in a.names.split(",") if n] or sorted(Dz.variants())
    os.makedirs(a.cache, exist_ok=True)
    log = os.path.join(a.cache, "rendre.log")
    if not a.post_only:
        # copie figée des scripts de modélisation : le rendu porte sur l'état du lancement, même après une longue
        # attente du verrou pendant laquelle design.py change
        snap = os.path.join(a.cache, "snap-%s" % time.strftime("%Y%m%d-%H%M%S"))
        os.makedirs(snap, exist_ok=True)
        for fn in ("geo.py", "kit.py", "design.py", "blender_render.py"):
            shutil.copy2(os.path.join(HERE, fn), os.path.join(snap, fn))
        cmd = [sys.executable, LOCK, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "-P",
               os.path.join(snap, "blender_render.py"), "--", "--names", ",".join(names), "--out", a.cache,
               "--samples", str(a.samples)]
        t0 = time.time()
        env = dict(os.environ, PYTHONIOENCODING="utf-8", FO_RENDER_DIR=RENDER)
        with open(log, "a", encoding="utf-8") as lf:
            lf.write("\n=== %s\n%s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), " ".join(cmd)))
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
            for raw in p.stdout:
                line = raw.decode("utf-8", "replace")
                lf.write(line)
                lf.flush()
                if line.startswith("[FO-RENDER]") or line.startswith("[fo-render]") or "Error" in line:
                    print(line.rstrip(), flush=True)
            rc = p.wait()
        print("[HYB] Blender terminé, code %d, %.0f s (attente du verrou comprise)" % (rc, time.time() - t0), flush=True)
        if rc != 0:
            sys.exit(rc)
    for n in names:
        if os.path.exists(os.path.join(a.cache, n, "render.json")):
            sp = post(n, a.cache, a.out)
            print("[HYB-POST] %s %s s=%s" % (n, sorted(sp["layers"]), sp["seconds"]), flush=True)


if __name__ == "__main__":
    main()
