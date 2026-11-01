"""RENDU DU MUR (MUR-OPUS, 29/10) : une session Blender par le verrou de rendu, puis post-traitement.

    py -3.9 tools/render/pieces/levels/mur_o/rendre.py --out DIR [--ages 2,8,15] [--formes single,horiz]
        [--samples 12] [--post-only]

Un seul rendu à la fois sur le PC (consigne du 29/10) : on attend qu'AUCUN verrou fo-render.lock.* ne soit pris, puis
on prend le verrou avec --slots 1. Sorties : DIR/<variante>/hr-mur-<variante>-<couche>.png (64 px/tuile),
mur-<variante>-<couche>.png (32 px/tuile), spec.json (taille, shift en px HR relatifs au centre de la case).
Liseré de contact : retiré au-delà du bord de la case du côté d'un bras E ou O (le voisin est là ; sinon son pied
serait assombri par notre liseré), comme les sprites vanilla du mur.
"""
import argparse
import glob
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
LOCK_DIR = os.environ.get("FO_RENDER_LOCK_DIR", r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91")


def attendre_pc_libre():
    t0 = time.time()
    while glob.glob(os.path.join(LOCK_DIR, "fo-render.lock.*")):
        if time.time() - t0 > 3 * 3600:
            raise SystemExit("verrou de rendu pris depuis 3 h : abandon")
        time.sleep(10)
    return time.time() - t0


def session(names, a):
    # 29/10 22 h 40 (orchestrateur) : le verrou a 2 places partagées avec le centre ; on le prend tel quel
    attente = 0.0
    cmd = [sys.executable, LOCK, "--disque", a.cache, "--", BLENDER, "-b", "--factory-startup",
           "-noaudio", "--python-exit-code", "1", "-P", os.path.join(HERE, "batch.py"), "--",
           "--names", ",".join(names), "--out", a.cache, "--samples", str(a.samples)]
    t0 = time.time()
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    log = []
    for raw in p.stdout:
        line = raw.decode("utf-8", "replace").rstrip()
        log.append(line)
        if line.startswith("[FO-RENDER]") or line.startswith("[fo-render]") or "Error" in line or "Traceback" in line:
            print(line, flush=True)
    rc = p.wait()
    with open(os.path.join(a.cache, "rendre.log"), "a", encoding="utf-8") as f:
        f.write("\n".join(log[-300:]) + "\n")
    print("[FO-BATCH] %d variantes, %.0f s (attente PC libre %.0f s), code %d" % (len(names), time.time() - t0,
                                                                                 attente, rc), flush=True)
    if rc:
        print("\n".join(log[-50:]))
    return rc


def post(name, a):
    d = os.path.join(a.cache, name)
    info = json.load(open(os.path.join(d, "render.json"), encoding="utf-8"))
    meta = piece.PIECE["variants"][name]
    ox, oy = info["origin_px"]

    def npy(layer):
        p = os.path.join(d, "%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    main_raw, ao = npy("main"), npy("ao")
    H, W = main_raw.shape[:2]
    mask = np.zeros((H, W))
    u = np.arange(W)[None, :] - ox
    if "E" in meta["bras"]:
        mask = np.maximum(mask, (u >= 31).astype(float) * np.ones((H, 1)))
    if "O" in meta["bras"]:
        mask = np.maximum(mask, (u <= -32).astype(float) * np.ones((H, 1)))
    hr = {"main": P.compose_main(main_raw, ao, C, fringe_mask=mask)}
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
        # v5b (C1) : l'ombre sous le corps opaque de la case ne se voit pas en jeu (le corps est dessiné par-dessus) ;
        # on la retire, comme les sprites d'ombre du mur vanilla (centroïde comparable, fichier plus petit)
        hr["shadow"][..., 3] *= 1.0 - np.clip(main_raw[..., 3], 0, 1)
    gl = npy("glow")
    if gl is not None:
        hr["glow"] = P.additive_layer(gl)
    out = os.path.join(a.out, name)
    os.makedirs(out, exist_ok=True)
    spec = {"variant": name, "epoch": meta["epoch"], "forme": meta["forme"], "samples": info["samples"],
            "seconds": info["seconds"], "verts": info["verts"], "objects": info["objects"], "layers": {}}
    for layer, img in hr.items():
        box = P.trim_box(img, (ox, oy))
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop = img[y0:y1, x0:x1]
        crop_lr = P.downsample2_additive(crop) if layer == "glow" else P.downsample2(crop)
        fn, fn_lr = "hr-mur-%s-%s.png" % (name, layer), "mur-%s-%s.png" % (name, layer)
        P.write_png(crop, os.path.join(out, fn))
        P.write_png(crop_lr, os.path.join(out, fn_lr))
        sd = P.sprite_def(box, (ox, oy), 64)
        spec["layers"][layer] = {"file": fn, "file_lr": fn_lr, "width": sd["width"], "height": sd["height"],
                                 "shift": sd["shift"], "box_px": [x0 - ox, y0 - oy, x1 - ox, y1 - oy]}
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    for f in os.listdir(d):
        if f.endswith(".npy") and not a.keep_npy:
            os.remove(os.path.join(d, f))
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--cache", default="")
    ap.add_argument("--ages", default="2,8,15")
    ap.add_argument("--formes", default=",".join(piece.ORDRE))
    ap.add_argument("--samples", type=int, default=12)
    ap.add_argument("--post-only", action="store_true")
    ap.add_argument("--keep-npy", action="store_true")
    a = ap.parse_args()
    a.out = os.path.abspath(a.out)
    a.cache = os.path.abspath(a.cache or os.path.join(os.path.dirname(a.out), "cache_" + os.path.basename(a.out)))
    os.makedirs(a.cache, exist_ok=True)
    names = [piece.nom(int(e), f) for e in a.ages.split(",") if e for f in a.formes.split(",") if f]
    t0 = time.time()
    rc = 0
    if not a.post_only:
        rc = session(names, a)
    for n in names:
        if os.path.exists(os.path.join(a.cache, n, "%s-main.npy" % n)):
            s = post(n, a)
            print("[FO-POST] %s %s" % (n, sorted(s["layers"])), flush=True)
    print("[FO-RENDRE] %d variantes en %.0f s, %d échantillons, code %d" % (len(names), time.time() - t0, a.samples,
                                                                            rc), flush=True)
    sys.exit(rc)


if __name__ == "__main__":
    main()
