"""Rendu + post-traitement de la mitrailleuse, lot V3-E époques 1 à 9 (gun_e_bas).

    py -3.9 tools/render/pieces/levels/gun_e_bas/rendre.py [--only a,b] [--samples 128] [--quick] [--post-only]
                                                           [--cache DIR] [--out DIR]

1. Les variantes demandées sont rendues dans UNE session Blender (batch_blender.py), lancée par le verrou de
   rendu prescrit (interdit n° 6) : « python tools/render/with_render_lock.py -- <blender ...> » (2 rendus au
   plus sur le PC, priorité inférieure à la normale). Ce script ne prend qu'UNE place à la fois.
2. Post-traitement avec tools/render/fo_post.py (inchangé) : liseré de contact sous la couche principale du
   socle et de la pièce paire, ombre, lueur additive, halo V0b borné et normalisé au sol (pic 0,45).
   Époques 1 et 2 (foyers de NUIT, catalogue §A.3) : la lueur passe dans la couche halo (draw_as_light), il n'y a
   pas de couche lueur.
3. Sorties hr (64 px/tuile) ET normales (32 px/tuile : réduction 2×2 en linéaire, additive pour lueur et halo),
   spec.json (largeur, hauteur, shift, sha256, contrôles : trous enfermés, plus grand trou, éléments fins).
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
import ind  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_blender.py")
WORK = os.environ.get("FO_IND_WORK", "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-22_V3E/bas")
HALO_PEAK = 0.45
NIGHT_ONLY = (1,)


def largest_hole(alpha):
    n, _, holes = FC.enclosed_transparent(alpha)
    if not n:
        return 0, 0, 0
    sys.path.insert(0, os.path.join(MOD, "tools", "da"))
    import da_lib as D
    sizes, _ = D.components(holes, conn8=False)
    return n, len(sizes), max(sizes.values())


def merge_additive(a, b):
    """Somme de deux couches additives (RGB normalisé, A = intensité) -> même format."""
    pm = a[..., :3] * a[..., 3:4] + b[..., :3] * b[..., 3:4]
    m = np.clip(pm.max(-1, keepdims=True), 0, 1)
    rgb = np.where(m > 1e-6, pm / np.maximum(pm.max(-1, keepdims=True), 1e-6), 0)
    return np.concatenate([rgb, m], -1)


def post(name, cache, out_root):
    d = os.path.join(cache, name)
    with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
        info = json.load(f)
    meta = ind.PIECE["variants"][name]
    origin = tuple(info["origin_px"])

    def npy(layer):
        if layer not in info.get("layers", []):
            return None
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
        side = meta["side"]
        lay = P.radial_window(lay, origin, (0.5 * side + 0.15) * 64, (0.5 * side + 1.25) * 64)
        ground = (free > 0.5) & (lay[..., 3] > 0)
        ref = np.percentile(lay[..., 3][ground], 99.5) if ground.any() else 0.0
        if ref > 1e-6:
            lay[..., 3] = np.minimum(1.0, lay[..., 3] * HALO_PEAK / ref)
        hr["light"] = P.floor_alpha(P.fade_edges(lay))
    if meta["epoch"] in NIGHT_ONLY and "glow" in hr:
        gl = hr.pop("glow")
        hr["light"] = merge_additive(hr["light"], gl) if "light" in hr else gl
    out = os.path.join(out_root, name)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png"):
            os.remove(os.path.join(out, f))
    spec = {"variant": name, "level": meta["level"], "epoch": meta["epoch"], "part": meta["part"],
            "dir": meta.get("dir"), "side": meta["side"], "samples": info["samples"], "seconds": info["seconds"],
            "seconds_render": info.get("seconds_render"), "verts": info.get("verts"), "count": info.get("count"),
            "quick": info.get("quick"), "canvas": info["canvas"], "night_only": meta["epoch"] in NIGHT_ONLY,
            # pièce du niveau 2 : à dessiner SOUS la mitrailleuse vanilla (plancher de planches, muret, caisse)
            "sous_vanilla": name == "e01-piece",
            "layers": {}}
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
        fn = "hr-gune-%s-%s.png" % (name, layer)
        fn_lr = "gune-%s-%s.png" % (name, layer)
        sha = P.write_png(crop, os.path.join(out, fn))
        sha_lr = P.write_png(crop_lr, os.path.join(out, fn_lr))
        sd = P.sprite_def(box, origin, 64)
        sd_lr = P.sprite_def(box, origin, 32)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha, "draw_as": {"shadow": "shadow", "glow": "glow",
                                                            "light": "light"}.get(layer, "main"),
                                 "lr": dict(sd_lr, file=fn_lr, sha256=sha_lr)}
    n, ng, big = largest_hole(main_raw[..., 3])
    thin, thin_part = FC.thin_pixels(hr["main"][..., 3])
    spec["checks"] = {"enclosed_transparent_px": int(n), "enclosed_groups": int(ng), "largest_hole_px": int(big),
                      "holes_ok": bool(big <= 8), "thin_px": int(thin), "thin_part": float(thin_part)}
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--post-only", action="store_true")
    ap.add_argument("--keep-npy", action="store_true", help="garder les passes brutes .npy après le post-traitement")
    ap.add_argument("--cache", default=os.path.join(WORK, "cache"))
    ap.add_argument("--out", default=os.path.join(WORK, "out"))
    a = ap.parse_args()
    names = [n for n in a.only.split(",") if n] or sorted(ind.PIECE["variants"])
    os.makedirs(a.cache, exist_ok=True)
    if not a.post_only:
        cmd = [sys.executable, LOCK, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
               "-P", BATCH, "--", "--names", ",".join(names), "--out", a.cache, "--samples", str(a.samples)]
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
        with open(os.path.join(a.cache, "rendre.log"), "a", encoding="utf-8") as f:
            f.write("\n".join(log[-400:]) + "\n")
        tj = os.path.join(a.cache, "temps.json")
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
        if os.path.exists(os.path.join(a.cache, n, "render.json")):
            if not any(f.endswith(".npy") for f in os.listdir(os.path.join(a.cache, n))):
                print("[FO-POST] %s : passes déjà purgées, rien à refaire" % n, flush=True)
                continue
            s = post(n, a.cache, a.out)
            if not a.keep_npy:
                # disque H: presque plein le 22/10 à 18 h (0,15 Go libres) : les passes brutes (float32) sont purgées
                # dès que les sprites et le spec.json sont écrits ; render.json reste (durées, comptes)
                for f in os.listdir(os.path.join(a.cache, n)):
                    if f.endswith(".npy"):
                        os.remove(os.path.join(a.cache, n, f))
            c = s["checks"]
            print("[FO-POST] %s %s %.0f s ; trous %d px en %d groupes, plus grand %d px %s" % (
                n, sorted(s["layers"]), s["seconds"], c["enclosed_transparent_px"], c["enclosed_groups"],
                c["largest_hole_px"], "OK" if c["holes_ok"] else "ECHEC"), flush=True)


if __name__ == "__main__":
    main()
