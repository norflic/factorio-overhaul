"""Aperçus de la famille gun (lot V3 phase 1) : rendu Cycles par lots + post-traitement en couches hr.

    python tools/render/pieces/levels/gun/render_gun.py [--epochs 1,2,3] [--samples 32] [--batch 12]
                                                        [--post-only]

1. Les variantes demandées (poses de référence : socle, socle + pièce, tête N/E/S/O) sont rendues par
   render_batch.py, un lot de --batch variantes par session Blender, CHAQUE lot sous le verrou de rendu
   (tools/render/with_render_lock.py : 2 rendus au plus sur le PC, priorité basse). Entre deux lots, la place
   est rendue : les autres familles passent.
2. Post-traitement (fonctions de tools/render/fo_post.py, inchangé) : liseré de contact sous la couche
   principale du socle, ombre (noir, alpha), lueur et halo additifs (RGB = c/max, A = max) ; halo borné par
   une fenêtre radiale centrée sur la position de l'entité (rayon nul S(N)/2, plein jusqu'à 40 %) et normalisé
   à LIGHT_MAX × I(N)/I(30) (bible §1.6, proportionnel au niveau) ; variante e01-piece-flancs masquée au
   pixel par l'alpha du socle vanilla (méthode de la variante « four » de V0) ; recadrage aligné sur la
   grille paire, shift exact (multiple de 1/64).
3. Sortie (non versionnée) : tools/render/out/levels/gun/<variante>/hr-gun-<variante>-<couche>.png et
   spec.json (largeur, hauteur, shift hr). Les .npy du cache sont effacés après usage (disque H: limité).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import d1lib as D  # noqa: E402
import gun as G  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
CACHE = os.path.join(D.MOD_ROOT, "tools", "render", "cache", "levels-gun", "cycles")
# verrou de rendu partagé, appelé TEL QUEL (interdit n° 6 : « python tools/render/with_render_lock.py -- <commande> ») :
# lock_retry.py relance « with_render_lock.py --wait 0 -- <commande> » toutes les 0,5 s tant qu'il n'y a pas de place
# (la variante lock_poll.py de la reprise 2, qui remplaçait time.sleep DANS le module partagé, est retirée)
LOCK = os.path.join(HERE, "lock_retry.py")
BATCH = os.path.join(HERE, "render_batch.py")


def place_alpha(canvas_shape, origin, sprite_path, shift, px_per_tile):
    """Recopie de render.place_alpha : alpha d'un sprite vanilla posé sur la même grille."""
    a = np.asarray(Image.open(sprite_path).convert("RGBA")).astype(np.float64)[..., 3] / 255.0
    h, w = a.shape
    Hc, Wc = canvas_shape
    out = np.zeros((Hc, Wc))
    x0 = origin[0] + shift[0] * px_per_tile - w / 2.0
    y0 = origin[1] + shift[1] * px_per_tile - h / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    assert abs(x0 - xi) < 1e-6 and abs(y0 - yi) < 1e-6, (sprite_path, x0, y0)
    xs0, ys0 = max(0, -xi), max(0, -yi)
    xd0, yd0 = max(0, xi), max(0, yi)
    ww, hh = min(w - xs0, Wc - xd0), min(h - ys0, Hc - yd0)
    if ww > 0 and hh > 0:
        out[yd0:yd0 + hh, xd0:xd0 + ww] = a[ys0:ys0 + hh, xs0:xs0 + ww]
    return out


def light_layer(li, main_alpha, origin, lv):
    """Halo de nuit : fenêtre radiale (rayon nul S(N)/2, plein jusqu'à 40 %) puis normalisation sur la FLAQUE
    AU SOL (pixels hors de la silhouette du module) à LIGHT_MAX × I(N)/I(30). Le maximum brut est sur les
    surfaces émissives elles-mêmes (gain LIGHT_EMIT_GAIN) : normaliser dessus rendait la flaque 5 à 8 fois trop
    faible (constaté sur les premiers aperçus, 21/10) ; les surfaces émissives saturent désormais à 1."""
    r1 = G.halo_radius(lv) * 64.0
    lay = P.radial_window(P.additive_layer(li), origin, 0.4 * r1, r1)
    ground = (main_alpha < 0.05) & (lay[..., 3] > 0)
    ref = np.percentile(lay[..., 3][ground], 99.5) if ground.any() else lay[..., 3].max()
    if ref > 1e-6:
        target = C.LIGHT_MAX * G.halo_intensity(lv) / G.halo_intensity(30)
        lay[..., 3] = np.minimum(1.0, lay[..., 3] * target / ref)
    return P.floor_alpha(P.fade_edges(lay))


def relight(name, info, meta, origin, li):
    """Refait la seule couche halo d'un aperçu déjà post-traité (cache réduit au halo brut)."""
    out = os.path.join(D.OUT_DIR, name)
    with open(os.path.join(out, "spec.json"), encoding="utf-8") as f:
        spec = json.load(f)
    m = spec["layers"]["main"]
    img = np.asarray(Image.open(os.path.join(out, m["file"])).convert("RGBA")).astype(np.float64) / 255.0
    Hc, Wc = li.shape[:2]
    main_a = np.zeros((Hc, Wc))
    x0 = int(round(origin[0] + m["shift"][0] * 64 - m["width"] / 2.0))
    y0 = int(round(origin[1] + m["shift"][1] * 64 - m["height"] / 2.0))
    main_a[y0:y0 + m["height"], x0:x0 + m["width"]] = img[..., 3]
    lay = light_layer(li, main_a, origin, meta["level"])
    box = P.trim_box(lay, origin)
    bx0, by0, bx1, by1 = box
    fn = "hr-gun-%s-light.png" % name
    sha = P.write_png(lay[by0:by1, bx0:bx1], os.path.join(out, fn))
    sd = P.sprite_def(box, origin, 64)
    spec["layers"]["light"] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"], "sha256": sha}
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)


def post(name):
    d = os.path.join(CACHE, name)
    with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
        info = json.load(f)
    meta = G.PIECE["variants"][name]
    origin = tuple(info["origin_px"])

    def npy(layer):
        p = os.path.join(d, "gun-%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    if npy("main") is None:      # re-post du halo seul (cache réduit) : couche principale relue de l'aperçu
        return relight(name, info, meta, origin, npy("light"))
    hr = {"main": P.compose_main(npy("main"), npy("ao"), C)}
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
        # Le moteur dessine la lueur (draw_as_glow, additive) PAR-DESSUS la couche principale ; or la passe main
        # contient déjà l'émission : sans correction, la lumière compte deux fois et sature en blanc (aperçus du
        # 21/10). On retire de la couche principale la part émise (valeurs codées, comme le mélange additif du
        # moteur) : principale + lueur = rendu complet, et la couleur d'époque est conservée.
        gp = hr["glow"][..., :3] * hr["glow"][..., 3:4]
        m = hr["main"].copy()
        m[..., :3] = np.clip(m[..., :3] - gp, 0.0, 1.0)
        hr["main"] = m
    li = npy("light")
    if li is not None:
        hr["light"] = light_layer(li, hr["main"][..., 3], origin, meta["level"])
    mask = meta.get("mask")
    if mask:
        m_hr = place_alpha(hr["main"].shape[:2], origin,
                           os.path.join(D.DATA, "base", "graphics", "entity", mask["hr"]["file"]), mask["hr"]["shift"], 64)
        for k in ("main", "glow"):
            if k in hr:
                hr[k] = P.mask_with(hr[k], m_hr)
    out = os.path.join(D.OUT_DIR, name)
    os.makedirs(out, exist_ok=True)
    spec = {"variant": name, "level": meta["level"], "epoch": meta["epoch"], "part": meta["part"],
            "dir": meta.get("dir"), "samples": info["samples"], "seconds": info["seconds"],
            "halos": info["halos"], "layers": {}}
    for layer in ("main", "shadow", "glow", "light"):
        if layer not in hr:
            continue
        box = P.trim_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        fn = "hr-gun-%s-%s.png" % (name, layer)
        sha = P.write_png(hr[layer][y0:y1, x0:x1], os.path.join(out, fn))
        sd = P.sprite_def(box, origin, 64)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha}
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    # disque H: limité : on ne garde du cache que le halo brut (réglage de la normalisation sans re-rendu)
    if li is None:
        shutil.rmtree(d, ignore_errors=True)
    else:
        for fn in os.listdir(d):
            if fn.endswith(".npy") and not fn.endswith("-light.npy"):
                os.remove(os.path.join(d, fn))


def run_batch(names, samples, log):
    cmd = [sys.executable, LOCK, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "-P", BATCH, "--",
           "--names", ",".join(names), "--out", CACHE, "--samples", str(samples)]
    t0 = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    with open(log, "a", encoding="utf-8") as f:
        f.write(" ".join(cmd) + "\n" + p.stdout[-20000:] + p.stderr[-5000:] + "\n")
    done = [l.split()[1] for l in p.stdout.splitlines() if l.startswith("[FO-RENDER]")]
    return p.returncode, done, time.time() - t0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", default="")
    ap.add_argument("--only", default="")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--batch", type=int, default=12)
    ap.add_argument("--post-only", action="store_true")
    a = ap.parse_args()
    eps = [int(x) for x in a.epochs.split(",") if x] or list(range(1, 16))
    names = sorted(n for n, v in G.PIECE["variants"].items() if v["epoch"] in eps)
    if a.only:
        names = [n for n in a.only.split(",") if n]
    os.makedirs(CACHE, exist_ok=True)
    log = os.path.join(CACHE, "render_gun.log")
    if a.post_only:
        for n in names:
            if os.path.exists(os.path.join(CACHE, n, "render.json")):
                post(n)
                print("[FO-POST] %s" % n, flush=True)
        return
    for i in range(0, len(names), a.batch):
        chunk = names[i:i + a.batch]
        rc, done, dt = run_batch(chunk, a.samples, log)
        print("[FO-BATCH] %d/%d variantes en %.0f s (code %d)" % (len(done), len(chunk), dt, rc), flush=True)
        for n in done:
            post(n)
            print("[FO-POST] %s" % n, flush=True)
        if rc != 0:
            print("échec du lot : voir %s" % log, flush=True)
            sys.exit(rc)


if __name__ == "__main__":
    main()
