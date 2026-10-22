"""Rendus d'APERÇU des niveaux du mur (lot V3, phase 1), poses de référence « droit » et « isole ».

TOUJOURS sous le verrou de rendu (CLAUDE.md, interdit n° 6), depuis la racine du worktree :
    python tools/render/with_render_lock.py -- python -P tools/render/pieces/levels/wall/render_wall.py \
        [--levels 2-30] [--poses droit,isole] [--samples 48]
GARDE (correction du 22/10, désaccord mineur n° 7) : avant tout appel à Blender, le script vérifie que son
processus PARENT est le propriétaire d'un verrou <racine>/fo-render.lock.<k> (owner.txt de
with_render_lock.py). Sinon il se relance lui-même par with_render_lock.py et n'appelle jamais Blender hors
verrou. Chaque appel est consigné dans cache/levels-wall/blender.log avec le dossier du verrou tenu.

Réutilise le pipeline partagé SANS le modifier (fo_blender.render, fo_post, fo_calib) ; le post-traitement
est repris ici, avec trois différences propres à la famille :
1. fenêtres et intensité du halo PAR NIVEAU (bible §1.6 : I(N) = 0,05 + 0,02·N, rayon ≤ 1 tuile) ;
2. niveau 2 : pièce posée sur le sprite vanilla, masquée au pixel par l'alpha vanilla sous la ligne
   cut_v seulement (la chape est sous le rouleau, la face est devant) ;
3. sorties dans tools/render/out/levels/wall/ (aperçus, ignorés par git) ; cache effacé après chaque
   variante (disque H: limité).
Sortie : PNG hr (64 px/tuile) et lr (32 px/tuile) par couche, et out/levels/wall/render_results.json
(tailles, shift, durées), fusionné d'un appel à l'autre.
"""
import argparse
import glob
import json
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_blender  # noqa: E402
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import wall_piece  # noqa: E402

PIECE_PATH = os.path.join(HERE, "wall_piece.py")
OUT = os.path.join(RENDER, "out", "levels", "wall")
CACHE = os.path.join(RENDER, "cache", "levels-wall")
RESULTS = os.path.join(OUT, "render_results.json")
DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
LAYERS = ("main", "shadow", "glow", "light")
LOCK_SCRIPT = os.path.join(RENDER, "with_render_lock.py")
LOCK_DIR = os.environ.get("FO_RENDER_LOCK_DIR", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91")


def held_lock():
    """Dossier du verrou de rendu tenu par le processus PARENT (with_render_lock.py), sinon None."""
    ppid = os.getppid()
    for d in sorted(glob.glob(os.path.join(LOCK_DIR, "fo-render.lock.*"))):
        try:
            with open(os.path.join(d, "owner.txt"), encoding="utf-8") as f:
                if int(f.read().split()[0]) == ppid:
                    return d
        except (OSError, ValueError, IndexError):
            continue
    return None


def crop_box(img, origin):
    """P.trim_box (coin pair par rapport à l'origine), élargi pour que la largeur et la hauteur hr soient
    multiples de 4 : la version 32 px/tuile a alors une taille paire et un shift multiple de 1/32 de tuile
    (correction du 22/10, désaccord mineur n° 1 : 121 couches lr sur 220 avaient un shift hors grille)."""
    box = P.trim_box(img, origin)
    if box is None:
        return None
    x0, y0, x1, y1 = box
    H_, W_ = img.shape[:2]
    if (x1 - x0) % 4:
        if x1 + 2 <= W_:
            x1 += 2
        else:
            x0 -= 2
    if (y1 - y0) % 4:
        if y1 + 2 <= H_:
            y1 += 2
        else:
            y0 -= 2
    assert x0 >= 0 and y0 >= 0 and (x1 - x0) % 4 == 0 and (y1 - y0) % 4 == 0, (x0, y0, x1, y1)
    return x0, y0, x1, y1


def shifted(img, dx, dy):
    """Translation entière (px) d'une couche, bords à zéro."""
    out = np.zeros_like(img)
    H_, W_ = img.shape[:2]
    ys0, ys1 = max(0, -dy), min(H_, H_ - dy)
    xs0, xs1 = max(0, -dx), min(W_, W_ - dx)
    out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = img[ys0:ys1, xs0:xs1]
    return out


def vanilla_alpha(canvas_shape, origin, spec, ppt, cut_v=None):
    """Alpha de l'image 0 d'un sprite vanilla posé sur la grille (centre = origine + shift) ; rangées au-dessus
    de cut_v (écran, tuiles) mises à zéro."""
    rel, w, h, shift = spec
    a = np.asarray(Image.open(os.path.join(DATA, "base", "graphics", "entity", rel)).convert("RGBA"))[:h, :w, 3]
    a = a.astype(np.float64) / 255.0
    H, W = canvas_shape
    out = np.zeros((H, W))
    x0 = origin[0] + shift[0] * ppt - w / 2.0
    y0 = origin[1] + shift[1] * ppt - h / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    if abs(x0 - xi) > 1e-6 or abs(y0 - yi) > 1e-6:
        raise ValueError("sprite vanilla hors grille : %s" % rel)
    xs0, ys0 = max(0, -xi), max(0, -yi)
    xd0, yd0 = max(0, xi), max(0, yi)
    ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
    if ww > 0 and hh > 0:
        out[yd0:yd0 + hh, xd0:xd0 + ww] = a[ys0:ys0 + hh, xs0:xs0 + ww]
    if cut_v is not None:
        rows = (np.arange(H) + 0.5 - origin[1]) / ppt
        out[rows < cut_v, :] = 0.0
    return out


def process(variant, vmeta, info):
    d, pre = info["_dir"], info["_prefix"]

    ov = vmeta.get("overlay_on_vanilla")
    pad = 72 if ov else 0         # niveau 2 : place sous la toile pour l'ombre translatée vers le sud

    def npy(layer):
        p = os.path.join(d, "%s-%s.npy" % (pre, layer))
        if not os.path.exists(p):
            return None
        a = np.load(p).astype(np.float64)
        return np.pad(a, ((0, pad), (0, 0), (0, 0))) if pad else a

    origin = tuple(info["origin_px"])
    hr = {"main": P.compose_main(npy("main"), npy("ao"), C)}
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
        if ov:
            # niveau 2 : l'ombre du rouleau suit la direction de l'ombre VANILLA du mur qui le porte (sud-est),
            # pas le soleil du pipeline (plein est) : wall_piece.L2_SHADOW
            dx, dy = wall_piece.l2_shadow_shift_px()
            hr["shadow"] = shifted(hr["shadow"], dx, dy)
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
        # La passe main CONTIENT déjà l'émission ; la lueur (draw_as_glow) est ajoutée par-dessus de jour : sans
        # correction, les surfaces émissives comptent deux fois (aperçu du 21/10 : cristaux de l'époque 7 blancs
        # saturés). On retire la contribution de la lueur de la couche principale (espace sRGB codé, celui du
        # mélange additif du moteur et de la maquette) : principale + lueur = rendu Blender, au pixel près.
        ga = hr["glow"][..., 3:4]
        ma = hr["main"][..., 3:4]
        sub = np.where(ma > 1e-3, hr["glow"][..., :3] * ga / np.maximum(ma, 1e-3), 0.0)
        hr["main"] = np.concatenate([np.clip(hr["main"][..., :3] - sub, 0, 1), ma], -1)
    if vmeta["pose"] == "droit":
        # pièce droite : la rangée continue chez les voisines -> corps et lueur bornés à x ∈ [-0,5 ; 0,5]
        # (le liseré de contact rendu aux bouts du tronçon isolé n'existe pas dans une rangée)
        W = hr["main"].shape[1]
        xs = np.arange(W) + 0.5 - origin[0]
        keep = ((xs >= -32) & (xs <= 32)).astype(np.float64)
        for k in ("main", "glow"):
            if k in hr:
                hr[k] = hr[k].copy()
                hr[k][..., 3] = hr[k][..., 3] * keep[None, :]
    li = npy("light")
    halo = vmeta["halo"]
    if li is not None:
        lay = P.additive_layer(li)
        best = None
        for wdef in halo["windows"]:
            dx, dy, z = wdef["at"]
            u, v = C.blender_to_screen_px(0.0, 0.0, z)
            center = (origin[0] + dx * 64.0 + u, origin[1] + dy * 64.0 + v)
            wl = P.radial_window(lay, center, wdef["r"][0] * 64, wdef["r"][1] * 64)
            best = wl if best is None else np.concatenate([wl[..., :3], np.maximum(best[..., 3:], wl[..., 3:])], -1)
        best = P.fade_edges(best)
        # borne au CENTRE DE LA TUILE (origine) : alpha nul au-delà de bound[1] tuile (bible §1.6, rayon <= 1)
        b0, b1 = halo.get("bound", (0.55, 0.97))
        best = P.radial_window(best, origin, b0 * 64.0, b1 * 64.0)
        # F64 (draw_as_light révèle la couleur de jour de TOUT ce qu'il couvre) : la flaque reste hors de la
        # silhouette du mur, et, en pose droite, hors des voisines de la rangée (|x| > 0,5 au-dessus du pied
        # avant y = +0,55) ; les parties lumineuses se voient la nuit par la couche lueur (draw_as_glow).
        H_, W_ = best.shape[:2]
        cover = np.clip(hr["main"][..., 3], 0, 1)
        if vmeta["pose"] == "droit":
            us = (np.arange(W_) + 0.5 - origin[0])[None, :]
            vs = (np.arange(H_) + 0.5 - origin[1])[:, None]
            cover = np.maximum(cover, ((np.abs(us) > 32) & (vs < 0.55 * 64)).astype(np.float64))
        best = best.copy()
        best[..., 3] = best[..., 3] * (1 - cover)
        m = best[..., 3].max()
        if m > 1e-6:      # intensité du halo proportionnelle au niveau (I(N)), forme conservée
            best[..., 3] = best[..., 3] * (halo["I"] / m)
        hr["light"] = P.floor_alpha(best)
    raw = dict(hr)
    if ov:
        m_hr = vanilla_alpha(hr["main"].shape[:2], origin, ov["hr"], 64, ov["cut_v"])
        for k in ("main", "glow"):
            if k in hr:
                hr[k] = P.mask_with(hr[k], m_hr)
    dest = os.path.join(OUT, "n%02d" % vmeta["level"])
    name = "wall-n%02d-%s" % (vmeta["level"], vmeta["pose"])
    spec, files = {}, {}
    for layer in LAYERS:
        if layer not in hr:
            continue
        box = crop_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop_hr = hr[layer][y0:y1, x0:x1]
        src = raw[layer][y0:y1, x0:x1]
        crop_lr = P.downsample2_additive(src) if layer in ("glow", "light") else P.downsample2(src)
        if ov and layer in ("main", "glow"):
            lr_origin = ((origin[0] - x0) / 2.0, (origin[1] - y0) / 2.0)
            crop_lr = P.mask_with(crop_lr, vanilla_alpha(crop_lr.shape[:2], lr_origin, ov["lr"], 32, ov["cut_v"]))
        fn_hr, fn_lr = "hr-%s-%s.png" % (name, layer), "%s-%s.png" % (name, layer)
        files[fn_hr] = P.write_png(crop_hr, os.path.join(dest, fn_hr))
        files[fn_lr] = P.write_png(crop_lr, os.path.join(dest, fn_lr))
        sd_hr, sd_lr = P.sprite_def(box, origin, 64), P.sprite_def(box, origin, 32)
        spec[layer] = {"hr": dict(sd_hr, filename=fn_hr), "lr": dict(sd_lr, filename=fn_lr)}
    return {"variant": variant, "level": vmeta["level"], "pose": vmeta["pose"], "dir": "n%02d" % vmeta["level"],
            "spec": spec, "files": files, "halo": halo, "overlay_on_vanilla": bool(ov),
            "render": {"canvas": info["canvas"], "origin_px": info["origin_px"], "samples": info["samples"],
                       "seed": info["seed"], "blender": info["blender"], "blender_hash": info["blender_hash"],
                       "seconds": info.get("seconds")}}


def clean_cache(info):
    for p in glob.glob(os.path.join(info["_dir"], info["_prefix"] + "-*")):
        try:
            os.remove(p)
        except OSError:
            pass


def parse_levels(s):
    out = []
    for part in s.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="2-30")
    ap.add_argument("--poses", default="droit,isole")
    ap.add_argument("--samples", type=int, default=48)
    a = ap.parse_args()
    lock = held_lock()
    if lock is None:
        # jamais de Blender hors du verrou de rendu : relance par with_render_lock.py (mêmes arguments)
        print("[FO-WALL] hors du verrou de rendu : relance par with_render_lock.py", flush=True)
        sys.exit(subprocess.call([sys.executable, LOCK_SCRIPT, "--", sys.executable, "-P", os.path.abspath(__file__)]
                                 + sys.argv[1:]))
    print("[FO-WALL] sous le verrou %s (processus parent %d)" % (lock, os.getppid()), flush=True)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(CACHE, exist_ok=True)
    results = {}
    if os.path.exists(RESULTS):
        with open(RESULTS, encoding="utf-8") as f:
            results = json.load(f)
    log = os.path.join(CACHE, "blender.log")
    t_all = time.time()
    failed = []
    for lv in parse_levels(a.levels):
        for pose in [p for p in a.poses.split(",") if p]:
            variant = "n%02d-%s" % (lv, pose)
            vmeta = wall_piece.PIECE["variants"][variant]
            t0 = time.time()
            if held_lock() != lock:
                print("[FO-WALL] verrou perdu : arrêt avant %s" % variant, flush=True)
                sys.exit(3)
            with open(log, "a", encoding="utf-8") as f:
                f.write("[FO-WALL] %s sous le verrou %s (parent %d), %s\n" % (variant, lock, os.getppid(),
                                                                          time.strftime("%Y-%m-%d %H:%M:%S")))
            try:
                info, dt = fo_blender.render(PIECE_PATH, variant, CACHE, samples=a.samples, log=log,
                                             margin=wall_piece.PIECE["margin_px"])
            except RuntimeError as err:          # une variante en échec n'arrête pas la série : elle est signalée
                print("[FO-WALL] ECHEC %s : %s" % (variant, str(err)[-1500:]), flush=True)
                failed.append(variant)
                continue
            r = process(variant, vmeta, info)
            r["seconds_total"] = round(time.time() - t0, 1)
            clean_cache(info)
            results[variant] = r
            with open(RESULTS, "w", encoding="utf-8", newline="\n") as f:
                json.dump(results, f, indent=1, sort_keys=True)
            m = r["spec"]["main"]["hr"]
            print("[FO-WALL] %s %4.1f s  main hr %dx%d shift (%.4f, %.4f)" % (variant, r["seconds_total"], m["width"],
                                                                              m["height"], m["shift"][0], m["shift"][1]),
                  flush=True)
    print("[FO-WALL] total %.1f s ; échecs : %s" % (time.time() - t_all, failed or "aucun"), flush=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
