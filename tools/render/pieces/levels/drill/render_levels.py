"""Rendus d'APERÇU des niveaux de la foreuse (lot V3, phase 1), toujours par le verrou de rendu.

    python -P tools/render/pieces/levels/drill/render_levels.py [--levels 2-30] [--dirs N,E,S,W]
           [--samples 32] [--samples-aux 12] [--no-denoise] [--quick] [--per-call 4]

- Chaque appel Blender passe par tools/render/with_render_lock.py (2 rendus au plus sur le PC, priorité
  basse) et rend au plus `--per-call` poses (un niveau = 4 directions) avant de rendre sa place.
- Passes rendues : main (débruitée par OIDN, --samples), ao, shadow, glow (--samples-aux). La passe
  « light » n'est PLUS rendue (correction V3 du 22/10, vérification adverse D2-3 : son énergie ne croissait
  pas avec le niveau) : le halo de nuit est une LightDefinition proportionnelle au niveau
  (levels_io.level_halo, bible §1.6), composée par planches.py et mesurée par measure_d1.py.
- Post-traitement par les fonctions de tools/render/fo_post.py (liseré de contact, ombre, lueur), sans les
  modifier. Sorties compactes (PNG 8 bits HR, 64 px/tuile) :
      tools/render/out/levels/drill/LNN/<D>-<couche>.png    couches main, shadow, glow (+ light aux
                                                             époques 1 et 2 : lueur « de nuit »)
      tools/render/out/levels/drill/spec.json               tailles, shift (tuiles), réglages, durées
  Les .npy intermédiaires (tools/render/cache/levels-drill/) sont supprimés après usage (disque H:).
- Époques 1 et 2 : aucune lueur de jour (bible §5) : la passe lueur est versée dans une couche
  draw_as_light (nuit seulement).
- Niveau 2 : la pièce invariante est rendue une fois (L02-N) puis masquée par l'alpha du sprite vanilla de
  chaque direction (vanilla.py), pour les couches principale et lueur, comme la variante « four » de V0.
- --quick : couches principale et ao (liseré de contact), 4 échantillons : silhouettes pour régler hauteurs
  et largeurs (même masque que les rendus complets).
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
import shadow_clean  # noqa: E402

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


def margin_for(level, quick=False):
    """Marge du canevas (px hr) autour de la boîte projetée des objets ET de leurs ombres (blender_batch)."""
    return 16 if quick else 32


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
        # bruit isolé de l'attrape-ombre retiré (shadow_clean.py : constat du 22/10, niveau 2)
        hr["shadow"] = shadow_clean.despeckle(P.shadow_layer(sh))[0]
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
    if mask_dir is not None:
        van = vanilla.compose(mask_dir, canvas=(H, W), origin=origin)
        for k in ("main", "glow"):
            if k in hr:
                hr[k] = P.mask_with(hr[k], van["main"][..., 3])
    epoch = (level + 1) // 2
    if epoch <= 2 and "glow" in hr:
        # aucune lueur de jour aux époques 1 et 2 : la lueur passe dans la couche halo (nuit seulement)
        gl = hr.pop("glow")
        pm = np.clip(gl[..., :3] * gl[..., 3:4], 0, 1)
        m = pm.max(-1, keepdims=True)
        hr["light"] = np.concatenate([np.where(m > 1e-6, pm / np.maximum(m, 1e-6), 0), m], -1)
    dest = os.path.join(OUT, "L%02d" % level)
    # fichiers périmés de cette direction (ancienne couche « light » rendue, par exemple)
    for layer in ("main", "shadow", "glow", "light"):
        fn = os.path.join(dest, "%s-%s.png" % (d, layer))
        if layer not in hr and os.path.exists(fn):
            os.remove(fn)
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
        if layer == "shadow":
            spec[layer]["despeckled"] = True
    return spec


def post_quick(info, level, d):
    pre = os.path.join(CACHE, "drill-%s" % info["variant"])
    main = np.load("%s-main.npy" % pre).astype(np.float64)
    ao = "%s-ao.npy" % pre
    if os.path.exists(ao):
        # liseré de contact compris : le masque des aperçus rapides est alors celui des rendus complets
        # (constat du 22/10 : le liseré élargit L de 0,04 à 0,20 tuile quand une pièce touche le sol au bord)
        main = P.compose_main(main, np.load(ao).astype(np.float64), C)
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


def _ready(v):
    """Infos du rendu de la variante v si Blender l'a terminée (json écrit APRÈS les .npy), sinon None."""
    path = os.path.join(CACHE, "drill-%s-render.json" % v)
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None   # en cours d'écriture : on repassera


def call_blender(variants, samples, layers, log, margin=64, on_ready=None, retries=2, samples_aux=None, denoise=False):
    """Rend les variantes dans UN processus Blender (une seule prise du verrou) et post-traite chaque pose
    dès qu'elle est finie (on_ready), pour que le cache ne garde qu'une pose ou deux (disque H: limité).
    Si Blender s'arrête en cours de lot, relance les variantes restantes (au plus `retries` fois)."""
    t0 = time.time()
    todo = list(variants)
    handled = set()

    def drain():
        for v in todo:
            if v not in handled and _ready(v) is not None:
                if on_ready:
                    on_ready(v)
                handled.add(v)

    rest = list(todo)
    for attempt in range(retries + 1):
        # Le verrou partagé (with_render_lock.py, non modifié) attend en sondant toutes les 5 s ; d'autres
        # lots sondent toutes les 0,5 s et prennent chaque place libérée (attente de 40 min et plus le
        # 21/10). On le relance donc avec --wait 0 (un seul essai, code 2 et message « aucune place libre »
        # si les 2 places sont prises) toutes les 0,5 s : même règle (2 rendus au plus, priorité basse),
        # même fréquence de sondage que les autres lots.
        rest = [v for v in todo if v not in handled]
        cmd = [sys.executable, LOCK, "--wait", "0", "--", fo_blender.blender_exe(), "-b", "--factory-startup",
               "-noaudio", "-P", BATCH, "--", "--piece", PIECE_FILE, "--out", CACHE, "--variants", ",".join(rest),
               "--samples", str(samples), "--layers", layers, "--margin", str(margin)]
        if samples_aux:
            cmd += ["--samples-aux", str(samples_aux)]
        if denoise:
            cmd += ["--denoise"]
        out_path = os.path.join(CACHE, "blender-run.txt")
        while True:
            with open(out_path, "w", encoding="utf-8") as fo:
                p = subprocess.Popen(cmd, stdout=fo, stderr=subprocess.STDOUT)
                while p.poll() is None:
                    drain()
                    time.sleep(1.0)
            with open(out_path, encoding="utf-8", errors="replace") as fi:
                txt = fi.read()
            if p.returncode == 2 and "aucune place libre" in txt:
                time.sleep(0.5)
                continue
            break
        drain()
        with open(log, "a", encoding="utf-8") as f:
            f.write(" ".join(cmd) + "\n[code %d]\n" % p.returncode + txt[-6000:] + "\n")
        rest = [v for v in todo if v not in handled]
        if p.returncode == 0 and not rest:
            return time.time() - t0
        print("[FO-V3-DRILL] Blender code %d, reste %s (essai %d)" % (p.returncode, rest, attempt + 1), flush=True)
        if not rest:
            return time.time() - t0
    raise RuntimeError("échec Blender pour %s (voir %s)" % (rest, log))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="2-30")
    ap.add_argument("--dirs", default="N,E,S,W")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--samples-aux", type=int, default=12, help="échantillons des passes ao, ombre, lueur")
    ap.add_argument("--no-denoise", action="store_true", help="sans débruitage OIDN de la passe principale")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--per-call", type=int, default=4)
    ap.add_argument("--post-only", action="store_true",
                    help="post-traiter les rendus déjà présents dans le cache (sans Blender)")
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
    layers = "main,ao" if a.quick else "main,ao,shadow,glow"
    t_all = time.time()
    def post(v):
        lvl, d = int(v[1:3]), v.split("-")[1]
        info = _ready(v)
        if a.quick:
            spec["quick"][v] = post_quick(info, lvl, d)
        elif lvl == 2:
            for dd in dirs:
                spec["levels"].setdefault("L02", {})[dd] = post_variant(info, 2, dd, mask_dir=dd)
            spec["levels"]["L02"]["render"] = {"seconds": info["seconds"], "samples": info["samples"],
                                               "samples_aux": info.get("samples_aux"),
                                               "denoise": info.get("denoise", False),
                                               "canvas": info["canvas"], "objects": info["objects"]}
        else:
            spec["levels"].setdefault("L%02d" % lvl, {})[d] = post_variant(info, lvl, d)
            spec["levels"]["L%02d" % lvl][d]["render"] = {"seconds": info["seconds"], "samples": info["samples"],
                                                         "samples_aux": info.get("samples_aux"),
                                                         "denoise": info.get("denoise", False),
                                                         "canvas": info["canvas"], "objects": info["objects"]}
        clean(v)
        os.remove(os.path.join(CACHE, "drill-%s-render.json" % v))
        save_spec(spec)
        print("[FO-V3-DRILL] %s post-traité (%.1f s de rendu)" % (v, info["seconds"]), flush=True)

    for i in range(0, len(jobs), a.per_call):
        chunk = jobs[i:i + a.per_call]
        variants = ["L%02d-%s" % (lvl, d) for lvl, d in chunk]
        if a.post_only:
            for v in variants:
                if _ready(v) is not None:
                    post(v)
            continue
        dt = call_blender(variants, samples, layers, log, margin=max(margin_for(l, a.quick) for l, _ in chunk),
                          on_ready=post, samples_aux=None if a.quick else a.samples_aux,
                          denoise=not (a.quick or a.no_denoise))
        print("[FO-V3-DRILL] %s : %.1f s (attente du verrou comprise)" % (",".join(variants), dt), flush=True)
    print("[FO-V3-DRILL] total %.1f s" % (time.time() - t_all))


if __name__ == "__main__":
    main()
