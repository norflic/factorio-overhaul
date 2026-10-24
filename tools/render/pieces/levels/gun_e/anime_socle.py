"""SOCLE ÉMISSIF ANIMÉ de la mitrailleuse (lot A4, 24/10/2026) : rendu (Blender, par le verrou) et post-traitement des
passes LUEUR et HALO, image par image, en feuilles animées. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/anime_socle.py --ages 6 --out <dossier> [--images 16] [--samples 128]
        [--post-seul]

Pour chaque âge (anim_emission.ANIM : âges 5 à 15) : anime_socle_blender.py rend eNN-socle (même scène et même
cadrage que le socle validé, passes « glow » et « light » seulement, N images ; un alpha de couche principale à 16
échantillons pour la fenêtre du halo), puis le post-traitement de rendre.post (fichier gelé, NON modifié ; mêmes
fonctions de fo_post, mêmes constantes) image par image, avec UNE différence voulue : le halo est normalisé par UNE
référence commune (99,5e centile de la MOYENNE des images au sol) et non image par image, sinon la normalisation
effacerait la pulsation. Sorties dans <dossier>/sprites/eNN-socle-anime/ : hr-gune-eNN-socle-anime-{glow,light}.png et
leurs versions normales (feuille de N images, line_length 4, cadre commun = union des images), spec.json (cadres,
shift, sha256, frame_count, line_length, animation_speed) et controle.json :
  - même canevas et même origine que le socle VALIDÉ (spec.json des sprites V3-E) : sinon refus ;
  - écart entre la MOYENNE des N images et la couche fixe validée (lueur et halo, couleur prémultipliée, hr) :
    écart moyen et 99e centile (la moyenne de m sur un cycle vaut 1 : on attend l'écart de l'échantillonnage) ;
  - amplitude de la pulsation : énergie de chaque image / énergie moyenne (min, max).
Les cache_* (.npy) sont purgés après le post-traitement.

PRODUCTION (après la production des têtes, une place de rendu ; commande exacte : NOTES.md du lot A4) :
    py -3.9 tools/render/pieces/levels/gun_e/anime_socle.py --ages 5,6,7,8,9,10,11,12,13,14,15 --out <dossier>
"""
import argparse
import hashlib
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
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import anim_emission as AE  # noqa: E402
import feuilles as FE  # noqa: E402

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
SCRIPT = os.path.join(HERE, "anime_socle_blender.py")
HALO_PEAK = 0.45          # = rendre.HALO_PEAK
LIGNE = 4


def valide(e):
    d = FE.plages(FE.VALIDES_DEFAUT)[e]
    s, dd = FE.lire_spec(d, "e%02d-socle" % e)
    return s, dd


def rendre(e, a, cache):
    name = "e%02d-socle" % e
    cmd = [sys.executable, LOCK, "--disque", cache, "--disque", a.out, "--", BLENDER, "-b", "--factory-startup",
           "-noaudio", "--python-exit-code", "1", "-P", SCRIPT, "--", "--name", name, "--out", cache,
           "--images", str(a.images), "--samples", str(a.samples)]
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    env.pop("FO_CORPS", None)              # corps de corps_choix.py, comme le rendu validé
    env.pop("FO_HABILLAGE_ESSAI", None)
    t0 = time.time()
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    log = []
    for raw in p.stdout:
        line = raw.decode("utf-8", "replace").rstrip()
        log.append(line)
        if "[FO-ANIME]" in line or "Error" in line or "Traceback" in line or "[fo-render]" in line:
            print(line, flush=True)
    rc = p.wait()
    with open(os.path.join(cache, "anime.log"), "a", encoding="utf-8") as f:
        f.write("\n".join(log[-400:]) + "\n")
    print("[FO-ANIME] %s : Blender (verrou compris) %.0f s, code %d" % (name, time.time() - t0, rc), flush=True)
    if rc:
        print("\n".join(log[-40:]))
    return rc


def lit_png(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float64) / 255.0


def post(e, a, cache):
    name = "e%02d-socle" % e
    d = os.path.join(cache, name)
    info = json.load(open(os.path.join(d, "render.json"), encoding="utf-8"))
    sv, dv = valide(e)
    if list(sv["canvas"]) != list(info["canvas"]):
        raise SystemExit("[FO-ANIME] %s : canevas %s ≠ validé %s (scène différente : refus)" % (
            name, info["canvas"], sv["canvas"]))
    origin = tuple(info["origin_px"])
    main_alpha = np.load(os.path.join(d, "%s-alpha-main.npy" % name)).astype(np.float64)[..., 3]
    side = sv["side"]
    glows, lights_raw = [], []
    for k in range(info["images"]):
        g = np.load(os.path.join(d, "%s-f%02d-glow.npy" % (name, k))).astype(np.float64)
        glows.append(P.additive_layer(g))
        li = np.load(os.path.join(d, "%s-f%02d-light.npy" % (name, k))).astype(np.float64)
        free = np.minimum(li[..., 3], 1.0 - np.clip(main_alpha, 0, 1))
        lay = P.light_layer(np.concatenate([li[..., :3], free[..., None]], -1), C.LIGHT_SCALE)
        lay = P.radial_window(lay, origin, (0.5 * side + 0.15) * 64, (0.5 * side + 1.25) * 64)
        lights_raw.append((lay, free))
    # référence COMMUNE du halo : 99,5e centile de la moyenne des images, au sol (rendre.post : image par image)
    moy = np.mean([l[..., :3] * l[..., 3:4] for l, _ in lights_raw], axis=0)
    mm = moy.max(-1)
    ground = (np.mean([f for _, f in lights_raw], axis=0) > 0.5) & (mm > 0)
    ref = float(np.percentile(mm[ground], 99.5)) if ground.any() else 0.0
    lights = []
    for lay, _ in lights_raw:
        lay = lay.copy()
        if ref > 1e-6:
            lay[..., 3] = np.minimum(1.0, lay[..., 3] * HALO_PEAK / ref)
        lights.append(P.floor_alpha(P.fade_edges(lay)))
    out = os.path.join(a.out, "sprites", "%s-anime" % name)
    os.makedirs(out, exist_ok=True)
    spec = {"variant": name + "-anime", "age": e, "images": info["images"], "line_length": LIGNE,
            "animation_speed": round(AE.IMAGES / float(AE.CYCLE_TICKS), 6) if info["images"] == AE.IMAGES else None,
            "anim": AE.ANIM[e], "samples": info["samples"], "canvas": info["canvas"], "render": info, "layers": {}}
    controle = {"variant": name + "-anime"}
    for layer, frames in (("glow", glows), ("light", lights)):
        # cadre commun : union des boîtes de toutes les images
        tot = np.max([f[..., 3] for f in frames], axis=0)
        fake = np.zeros(frames[0].shape)
        fake[..., 3] = tot
        box = P.trim_box(fake, origin)
        x0, y0, x1, y1 = box
        w, h = x1 - x0, y1 - y0
        n = len(frames)
        rows = -(-n // LIGNE)
        hr = np.zeros((rows * h, LIGNE * w, 4))
        lr = np.zeros((rows * h // 2, LIGNE * w // 2, 4))
        for k, f in enumerate(frames):
            c = f[y0:y1, x0:x1]
            r0, c0 = (k // LIGNE) * h, (k % LIGNE) * w
            hr[r0:r0 + h, c0:c0 + w] = c
            lr[r0 // 2:r0 // 2 + h // 2, c0 // 2:c0 // 2 + w // 2] = P.downsample2_additive(c)
        fn, fn_lr = "hr-gune-%s-anime-%s.png" % (name, layer), "gune-%s-anime-%s.png" % (name, layer)
        sha, sha_lr = P.write_png(hr, os.path.join(out, fn)), P.write_png(lr, os.path.join(out, fn_lr))
        sd, sd_lr = P.sprite_def(box, origin, 64), P.sprite_def(box, origin, 32)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha, "frame_count": n, "line_length": LIGNE,
                                 "lr": dict(sd_lr, file=fn_lr, sha256=sha_lr)}
        if max(LIGNE * w, rows * h) > FE.LIMITE_PX:
            raise SystemExit("[FO-ANIME] %s %s : feuille au-delà de %d px" % (name, layer, FE.LIMITE_PX))
        # contrôle : moyenne des images contre la couche fixe validée (hr, couleur prémultipliée)
        Lv = sv["layers"][layer]
        vimg = lit_png(os.path.join(dv, Lv["file"]))
        gx, gy, _, _ = FE.boite_px(Lv)
        vpm = np.zeros(frames[0].shape[:2] + (3,))
        vy0, vx0 = gy + origin[1], gx + origin[0]
        vpm[vy0:vy0 + vimg.shape[0], vx0:vx0 + vimg.shape[1]] = vimg[..., :3] * vimg[..., 3:4]
        # les images animées passent par le même codage 8 bits que le PNG validé
        pms = [np.round(f * 255) / 255 for f in frames]
        pms = [f[..., :3] * f[..., 3:4] for f in pms]
        mpm = np.mean(pms, axis=0)
        zone = (vpm.max(-1) > 2 / 255) | (mpm.max(-1) > 2 / 255)
        ecart = np.abs(mpm - vpm).max(-1)[zone]
        energie = [float(f.sum()) for f in pms]
        e_moy = float(np.mean(energie))
        controle[layer] = {"pixels": int(zone.sum()), "ecart_moyen": round(float(ecart.mean()), 5),
                           "ecart_p99": round(float(np.percentile(ecart, 99)), 5),
                           "ecart_max": round(float(ecart.max()), 5),
                           "energie_validee_sur_moyenne": round(float(vpm.sum()) / max(e_moy, 1e-9), 4),
                           "pulsation_min": round(min(energie) / e_moy, 4),
                           "pulsation_max": round(max(energie) / e_moy, 4)}
        print("[FO-ANIME] %s %s : feuille %d x %d (%d images de %d x %d hr) ; moyenne des images contre la couche "
              "validée : écart moyen %.4f, 99e centile %.4f, max %.4f, énergie validée / moyenne %.3f ; pulsation "
              "%.2f à %.2f" % (name, layer, LIGNE * w, rows * h, n, w, h, controle[layer]["ecart_moyen"],
                               controle[layer]["ecart_p99"], controle[layer]["ecart_max"],
                               controle[layer]["energie_validee_sur_moyenne"], controle[layer]["pulsation_min"],
                               controle[layer]["pulsation_max"]), flush=True)
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    with open(os.path.join(out, "controle.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(controle, f, indent=1, sort_keys=True)
    return spec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ages", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--images", type=int, default=AE.IMAGES)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--post-seul", action="store_true")
    ap.add_argument("--garder-npy", action="store_true")
    a = ap.parse_args()
    a.out = os.path.abspath(a.out)
    cache = os.path.join(a.out, "cache")
    os.makedirs(cache, exist_ok=True)
    rc_all = 0
    for e in [int(x) for x in a.ages.split(",") if x]:
        if e not in AE.ANIM:
            raise SystemExit("âge %d non animé (anim_emission.ANIM : %s)" % (e, sorted(AE.ANIM)))
        if not a.post_seul:
            rc = rendre(e, a, cache)
            if rc:
                rc_all = rc
                continue
        post(e, a, cache)
        if not a.garder_npy:
            d = os.path.join(cache, "e%02d-socle" % e)
            for f in os.listdir(d):
                if f.endswith(".npy"):
                    os.remove(os.path.join(d, f))
    return rc_all


if __name__ == "__main__":
    sys.exit(main())
