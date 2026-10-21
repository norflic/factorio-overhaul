"""Rendus d'APERÇU des niveaux de la foreuse (lot V3, phase 1), toujours par le verrou de rendu.

    python -P tools/render/pieces/levels/drill/render_levels.py [--levels 2-30] [--dirs N,E,S,W]
           [--samples 32] [--quick] [--per-call 4]

- Chaque appel Blender passe par tools/render/with_render_lock.py (2 rendus au plus sur le PC, priorité
  basse) et rend au plus `--per-call` poses (un niveau = 4 directions) avant de rendre sa place.
- Post-traitement par les fonctions de tools/render/fo_post.py (liseré de contact, ombre, lueur, halo
  borné), sans les modifier. Sorties compactes (PNG 8 bits HR, 64 px/tuile) :
      tools/render/out/levels/drill/LNN/<D>-<couche>.png    couches main, shadow, glow, light
      tools/render/out/levels/drill/spec.json               tailles, shift (tuiles), réglages, durées
  Les .npy intermédiaires (tools/render/cache/levels-drill/) sont supprimés après usage (disque H:).
- Époques 1 et 2 : aucune lueur de jour (bible §5) : la passe lueur est versée dans la couche halo
  (draw_as_light, nuit seulement).
- Niveau 2 : la pièce invariante est rendue une fois (L02-N) puis masquée par l'alpha du sprite vanilla de
  chaque direction (vanilla.py), pour les couches principale et lueur, comme la variante « four » de V0.
- --quick : couche principale seule, 4 échantillons, sans liseré : silhouettes pour régler les hauteurs.
"""
import argparse
import json
import os
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import fo_blender  # noqa: E402
import vanilla  # noqa: E402

OUT = os.path.join(RENDER, "out", "levels", "drill")
CACHE = os.path.join(RENDER, "cache", "levels-drill")
PIECE_FILE = os.path.join(HERE, "drill_levels.py")
BATCH = os.path.join(HERE, "blender_batch.py")
LOCK = os.path.join(RENDER, "with_render_lock.py")
DIRS = ("N", "E", "S", "W")
SPEC = os.path.join(OUT, "spec.json")


def parse_levels(s):
    out = []
    for part in s.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return out


def halo_windows(level):
    """Fenêtres du halo (tuiles) : flaque au sol autour du pied, croissante avec le niveau (bible §1.6,
    D2-3 : S(N) ∝ 1 + 0,05·N), et cœurs autour de chaque source déclarée par le modèle."""
    g0 = 1.10 + 0.03 * level
    g1 = 2.10 + 0.05 * level
    return (g0, g1), (0.45, 1.0)


def post_variant(info, level, d, mask_dir=None):
    pre = os.path.join(CACHE, "drill-%s" % info["variant"])

    def npy(layer):
        p = "%s-%s.npy" % (pre, layer)
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    origin = tuple(info["origin_px"])
    H, W = info["canvas"][1], info["canvas"][0]
    hr = {"main": P.compose_main(npy("main"), npy("ao"), C)}
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
    li = npy("light")
    if li is not None:
        lay = P.additive_layer(li)
        (g0, g1), (c0, c1) = halo_windows(level)
        best = P.radial_window(lay, origin, g0 * 64, g1 * 64)
        for hsrc in info.get("halos", []):
            ctr = (origin[0] + hsrc["px"][0], origin[1] + hsrc["px"][1])
            wl = P.radial_window(lay, ctr, c0 * 64, c1 * 64)
            best = np.concatenate([wl[..., :3], np.maximum(best[..., 3:], wl[..., 3:])], -1)
        hr["light"] = P.floor_alpha(P.fade_edges(best))
    if mask_dir is not None:
        van = vanilla.compose(mask_dir, canvas=(H, W), origin=origin)
        for k in ("main", "glow"):
            if k in hr:
                hr[k] = P.mask_with(hr[k], van["main"][..., 3])
    epoch = (level + 1) // 2
    if epoch <= 2 and "glow" in hr:
        # aucune lueur de jour aux époques 1 et 2 : la lueur passe dans la couche halo (nuit seulement)
        gl = hr.pop("glow")
        pm = gl[..., :3] * gl[..., 3:4]
        if "light" in hr:
            pm = pm + hr["light"][..., :3] * hr["light"][..., 3:4]
        pm = np.clip(pm, 0, 1)
        m = pm.max(-1, keepdims=True)
        hr["light"] = np.concatenate([np.where(m > 1e-6, pm / np.maximum(m, 1e-6), 0), m], -1)
    dest = os.path.join(OUT, "L%02d" % level)
    spec = {}
    for layer in ("main", "shadow", "glow", "light"):
        if layer not in hr:
            continue
        box = P.trim_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        fn = os.path.join(dest, "%s-%s.png" % (d, layer))
        sha = P.write_png(hr[layer][y0:y1, x0:x1], fn)
        sd = P.sprite_def(box, origin, 64)
        spec[layer] = {"file": os.path.relpath(fn, RENDER).replace("\\", "/"), "width": sd["width"],
                       "height": sd["height"], "shift": sd["shift"], "sha256": sha}
    return spec


def post_quick(info, level, d):
    pre = os.path.join(CACHE, "drill-%s" % info["variant"])
    main = np.load("%s-main.npy" % pre).astype(np.float64)
    origin = tuple(info["origin_px"])
    box = P.trim_box(main, origin)
    x0, y0, x1, y1 = box
    fn = os.path.join(OUT, "quick", "L%02d-%s.png" % (level, d))
    P.write_png(main[y0:y1, x0:x1], fn)
    sd = P.sprite_def(box, origin, 64)
    return {"main": {"file": os.path.relpath(fn, RENDER).replace("\\", "/"), "width": sd["width"],
                     "height": sd["height"], "shift": sd["shift"]}}


def clean(variant):
    pre = os.path.join(CACHE, "drill-%s" % variant)
    for layer in ("main", "ao", "shadow", "glow", "light"):
        for ext in (".npy", ".png"):
            p = "%s-%s%s" % (pre, layer, ext)
            if os.path.exists(p):
                os.remove(p)


def load_spec():
    if os.path.exists(SPEC):
        with open(SPEC, encoding="utf-8") as f:
            return json.load(f)
    return {"levels": {}, "quick": {}}


def save_spec(spec):
    os.makedirs(OUT, exist_ok=True)
    with open(SPEC, "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)


def call_blender(variants, samples, layers, log, retries=2):
    """Rend les variantes ; si Blender s'arrête en cours de lot (code non nul), relance les variantes
    restantes dans un nouveau processus (au plus `retries` fois)."""
    t0 = time.time()
    todo = list(variants)
    for attempt in range(retries + 1):
        cmd = [sys.executable, LOCK, "--", fo_blender.blender_exe(), "-b", "--factory-startup", "-noaudio", "-P",
               BATCH, "--", "--piece", PIECE_FILE, "--out", CACHE, "--variants", ",".join(todo), "--samples",
               str(samples), "--layers", layers, "--margin", "64"]
        p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        with open(log, "a", encoding="utf-8") as f:
            f.write(" ".join(cmd) + "\n[code %d]\n" % p.returncode + p.stdout[-6000:] + p.stderr[-6000:] + "\n")
        done = [ln.split()[1][len("drill-"):] for ln in p.stdout.splitlines() if ln.startswith("[FO-RENDER]")]
        todo = [v for v in todo if v not in done]
        if p.returncode == 0 and not todo:
            return time.time() - t0
        print("[FO-V3-DRILL] Blender code %d, reste %s (essai %d)" % (p.returncode, todo, attempt + 1), flush=True)
        if not todo:
            return time.time() - t0
    raise RuntimeError("échec Blender pour %s (voir %s)" % (todo, log))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="2-30")
    ap.add_argument("--dirs", default="N,E,S,W")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--per-call", type=int, default=4)
    a = ap.parse_args()
    os.makedirs(CACHE, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    log = os.path.join(CACHE, "blender.log")
    dirs = [x for x in a.dirs.split(",") if x]
    jobs = []
    for lvl in parse_levels(a.levels):
        for d in (["N"] if lvl == 2 else dirs):
            jobs.append((lvl, d))
    spec = load_spec()
    samples = 4 if a.quick else a.samples
    layers = "main" if a.quick else "main,ao,shadow,glow,light"
    t_all = time.time()
    for i in range(0, len(jobs), a.per_call):
        chunk = jobs[i:i + a.per_call]
        variants = ["L%02d-%s" % (lvl, d) for lvl, d in chunk]
        dt = call_blender(variants, samples, layers, log)
        for lvl, d in chunk:
            v = "L%02d-%s" % (lvl, d)
            with open(os.path.join(CACHE, "drill-%s-render.json" % v), encoding="utf-8") as f:
                info = json.load(f)
            if a.quick:
                spec["quick"]["L%02d-%s" % (lvl, d)] = post_quick(info, lvl, d)
            elif lvl == 2:
                for dd in dirs:
                    spec["levels"].setdefault("L02", {})[dd] = post_variant(info, 2, dd, mask_dir=dd)
                spec["levels"]["L02"]["render"] = {"seconds": info["seconds"], "samples": info["samples"],
                                                   "canvas": info["canvas"], "objects": info["objects"]}
            else:
                spec["levels"].setdefault("L%02d" % lvl, {})[d] = post_variant(info, lvl, d)
                spec["levels"]["L%02d" % lvl][d]["render"] = {"seconds": info["seconds"], "samples": info["samples"],
                                                             "canvas": info["canvas"], "objects": info["objects"]}
            clean(v)
            os.remove(os.path.join(CACHE, "drill-%s-render.json" % v))
        save_spec(spec)
        print("[FO-V3-DRILL] %s : %.1f s (attente du verrou comprise)" % (",".join(variants), dt), flush=True)
    print("[FO-V3-DRILL] total %.1f s" % (time.time() - t_all))


if __name__ == "__main__":
    main()
