"""RENDU DES TÊTES TOURNANTES (lot POLISSAGE-3, 10/11) : batch_tetes.py par le verrou de rendu, puis assemblage hors Blender.

    py -3.9 tools/render/pieces/batiments/rendre_tetes.py --names bastion1,lourde --out DIR [--cache DIR] [--samples 32]
        [--dirs 0,16,32,48] [--post-only]

Post-traitement (même chaîne que rendre.py : fo_post, nettoyage d'alpha) : par couche (main, shadow, glow), boîte COMMUNE à toutes les
vues (union des alphas, parité paire relative au pied), puis 4 BANDES de 16 directions × IMAGES colonnes, une ligne par direction, comme
les « stripes » de la mitrailleuse vanilla (une animation à une image lit la première colonne : width_in_frames = 1). Sorties
<out>/<nom>-tete/hr-tete-<nom>-<couche>-<i>.png et spec.json (couches, bandes, taille d'image, shift, images, bouche).
"""
import argparse
import json
import os
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_post as P  # noqa: E402
import piece  # noqa: E402
import importlib.util  # noqa: E402

# rendre.py DU KIT par son chemin : piece.py met pieces/experimentaux en tête de sys.path, qui a aussi un rendre.py
_r = importlib.util.spec_from_file_location("bat_rendre", os.path.join(HERE, "rendre.py"))
R = importlib.util.module_from_spec(_r)
_r.loader.exec_module(R)
import tourelle_tete as T  # noqa: E402

BLENDER = R.BLENDER
LOCK = R.LOCK
BATCH = os.path.join(HERE, "batch_tetes.py")
RANGS = 16           # directions par bande (64 = 4 bandes) : une bande de 16 × images reste sous 8 192 px (F144)


def post(name, cache, out_root):
    d = os.path.join(cache, name + "-tete")
    info = json.load(open(os.path.join(d, "tete.json"), encoding="utf-8"))
    nd, ni = info["directions"], info["images"]
    origin = tuple(info["origin_px"])
    vues = {}            # couches post-traitées, en octets (mémoire : 128 vues × 3 couches)
    for k in range(nd):
        for i in range(ni):
            z = np.load(os.path.join(d, "%s-d%02d-i%d.npz" % (name, k, i)))
            main = z["main"].astype(np.float64) / 255.0
            glow = z["glow"].astype(np.float64) / 255.0
            om = np.zeros(main.shape)
            om[..., 3] = z["ombre"].astype(np.float64) / 255.0
            vues[(k, i)] = {"main": P.to_u8(R.nettoie(P.compose_main(main, None, None), "main")),
                            "shadow": P.to_u8(R.nettoie(P.shadow_layer(om), "shadow")),
                            "glow": P.to_u8(R.nettoie(P.additive_layer(glow), "glow"))}
    out = os.path.join(out_root, name + "-tete")
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png"):
            os.remove(os.path.join(out, f))
    spec = {"variant": name, "kit": "batiments", "directions": nd, "images": ni, "rangs": RANGS, "canvas": info["canvas"],
            "samples": info["samples"], "seconds": info["seconds"], "bouche_modele": info["bouche"],
            "bouche": T.bouche(info["bouche"]), "layers": {}}
    for layer in ("main", "shadow", "glow"):
        stack = np.zeros(vues[(0, 0)][layer].shape)
        for v in vues.values():
            stack[..., 3] = np.maximum(stack[..., 3], v[layer][..., 3] / 255.0)
        box = P.trim_box(stack, origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        w, h = x1 - x0, y1 - y0
        sd = P.sprite_def(box, origin, 64)
        files = []
        for b in range(nd // RANGS):
            sheet = np.zeros((RANGS * h, ni * w, 4))
            for r in range(RANGS):
                for i in range(ni):
                    sheet[r * h:(r + 1) * h, i * w:(i + 1) * w] = vues[(b * RANGS + r, i)][layer][y0:y1, x0:x1] / 255.0
            fn = "hr-tete-%s-%s-%d.png" % (name, layer, b + 1)
            sha = P.write_png(sheet, os.path.join(out, fn))
            files.append({"file": fn, "sha256": sha})
        spec["layers"][layer] = {"files": files, "width": w, "height": h, "shift": sd["shift"],
                                 "draw_as": {"shadow": "shadow", "glow": "glow"}.get(layer, "main")}
    json.dump(spec, open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n"), indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", default=",".join(piece.TETES))
    ap.add_argument("--out", required=True)
    ap.add_argument("--cache", default="")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--samples-glow", type=int, default=16)
    ap.add_argument("--samples-shadow", type=int, default=8)
    ap.add_argument("--dirs", default="")
    ap.add_argument("--post-only", action="store_true")
    a = ap.parse_args()
    a.cache = a.cache or os.path.join(os.path.dirname(os.path.abspath(a.out)), "cache_" + os.path.basename(a.out))
    names = [n for n in a.names.split(",") if n]
    bad = [n for n in names if n not in piece.TETES]
    if bad:
        raise SystemExit("têtes inconnues : %s" % ", ".join(bad))
    os.makedirs(a.cache, exist_ok=True)
    t0 = time.time()
    if not a.post_only:
        cmd = [sys.executable, LOCK, "--disque", a.cache, "--disque", a.out, "--", BLENDER, "-b", "--factory-startup", "-noaudio",
               "--python-exit-code", "1", "-P", BATCH, "--", "--names", ",".join(names), "--out", a.cache, "--samples", str(a.samples),
               "--samples-glow", str(a.samples_glow), "--samples-shadow", str(a.samples_shadow)] + (["--dirs", a.dirs] if a.dirs else [])
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
        log = []
        for raw in p.stdout:
            line = raw.decode("utf-8", "replace").rstrip()
            log.append(line)
            if ("[FO-RENDER]" in line and "tete" in line) or "Error" in line or "Traceback" in line or "[fo-render]" in line:
                print(line, flush=True)
        rc = p.wait()
        open(os.path.join(a.cache, "rendre_tetes.log"), "a", encoding="utf-8").write("\n".join(log[-400:]) + "\n")
        print("[FO-BATCH-TETES] %s, %.0f s, code %d" % (",".join(names), time.time() - t0, rc), flush=True)
        if rc:
            print("\n".join(log[-40:]))
            sys.exit(rc)
        if a.dirs:
            return
    for n in names:
        s = post(n, a.cache, a.out)
        print("[FO-POST-TETE] %s %s, bouche %s" % (n, {k: (v["width"], v["height"]) for k, v in s["layers"].items()}, s["bouche"]), flush=True)
    print("[FO-RENDRE-TETES] %.0f s en tout" % (time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
