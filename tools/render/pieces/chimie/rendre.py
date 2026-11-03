"""RENDU des machines du kit CHIMIE (lot DA-CHIMIE, 3/11) : copie de calcul_o/rendre.py (lot CALCUL-DESIGN).

    py -3.9 tools/render/pieces/chimie/rendre.py --names craqueur_n,craqueur_e --out DIR [--cache DIR] [--samples 16]
        [--post-only] [--images N]

UNE session Blender pour toutes les variantes, lancée par le verrou de rendu (interdit n° 6 : « with_render_lock.py »).
Passes de jour (main, ao, shadow, glow). Sorties hr-chim-<variante>-<couche>.png et spec.json (format de commun/compo.py)
dans <out>/<variante>/.
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
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import piece  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_blender.py")


def etalonne(img, grade):
    """Étalonnage de la couche principale (refonte QG, 31/10), hors Blender, rejouable par --post-only. Il n'agit que sur
    les EXTRÉMITÉS de la courbe : pied (sous tp, puissance tk : noirs plus noirs), épaule (au-dessus de sp, pente g :
    clairs plus clairs), puis gamma ga des tons moyens et saturation s. Une courbe en S sur les tons moyens ferme des
    cellules (mesure « damier » : de 0,45 à 0,62). FO_GRADE="tp,tk,sp,g,ga,s"."""
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


def post(name, cache, out_root):
    d = os.path.join(cache, name)
    info = json.load(open(os.path.join(d, "render.json"), encoding="utf-8"))
    origin = tuple(info["origin_px"])

    def npy(layer):
        p = os.path.join(d, "%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if layer in info["layers"] and os.path.exists(p) else None

    hr = {"main": P.compose_main(npy("main"), npy("ao"), C)}
    if os.environ.get("FO_GRADE"):
        hr["main"] = etalonne(hr["main"], [float(x) for x in os.environ["FO_GRADE"].split(",")])
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
            "canvas": info["canvas"], "kit": "chimie", "layers": {}}
    for layer in ("main", "shadow", "glow"):
        if layer not in hr:
            continue
        box = P.trim_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop = hr[layer][y0:y1, x0:x1]
        fn = "hr-chim-%s-%s.png" % (name, layer)
        sha = P.write_png(crop, os.path.join(out, fn))
        sd = P.sprite_def(box, origin, 64)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha, "draw_as": {"shadow": "shadow", "glow": "glow"}.get(layer, "main")}
    mob = os.path.join(d, "mobiles.json")
    if os.path.exists(mob):
        m = json.load(open(mob, encoding="utf-8"))
        grade = [float(x) for x in os.environ["FO_GRADE"].split(",")] if os.environ.get("FO_GRADE") else None
        x0, y0, x1, y1 = m["boite"]
        cases = []
        for k in range(m["images"]):
            im = np.load(os.path.join(d, "%s-img%02d-main.npy" % (name, k))).astype(np.float64)
            im = etalonne(im, grade) if grade else im
            cases.append(im[y0:y1, x0:x1])
        w, h = x1 - x0, y1 - y0
        fn = "hr-chim-%s-mobile.png" % name
        sha = P.write_png(np.concatenate(cases, 1), os.path.join(out, fn))
        sd = P.sprite_def((x0, y0, x1, y1), origin, 64)
        spec["layers"]["mobile"] = {"file": fn, "width": w, "height": h, "shift": sd["shift"], "images": m["images"], "sha256": sha,
                                    "draw_as": "main"}
    json.dump(spec, open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n"), indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", default="craqueur_n")
    ap.add_argument("--out", required=True)
    ap.add_argument("--cache", default="")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--post-only", action="store_true")
    ap.add_argument("--quick", action="store_true", help="passes main, glow, shadow seulement (essais)")
    ap.add_argument("--images", type=int, default=0, help="images des pièces mobiles (final)")
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
               "--samples", str(a.samples), "--images", str(a.images)] + (["--quick"] if a.quick else ["--apercu"])
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
