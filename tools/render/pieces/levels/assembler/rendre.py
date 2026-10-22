"""Pilote des rendus d'aperçu de la machine d'assemblage 2 (lot V3, phase 1). Python système (numpy, Pillow).

    python -P tools/render/pieces/levels/assembler/rendre.py [--levels 2-30] [--samples 48] [--mode complet|masque]

- CHAQUE appel à Blender passe par le verrou de rendu (tools/render/with_render_lock.py : 2 rendus au plus sur le PC,
  priorité basse) ; un appel par niveau, pour laisser passer les autres familles entre deux niveaux.
- Post-traitement par les fonctions de V0 (tools/render/fo_post.py, inchangé) : liseré de contact sous la couche
  principale, ombre noire, lueur et halo additifs, recadrage sur la grille paire, version 32 px/tuile.
- Niveau 2 : la pièce est masquée au pixel par l'alpha du sprite vanilla (image 0), comme la variante « four » de V0.
- Halo : borné par des fenêtres autour des sources, puis ramené au maximum visé au sol (params.halo_cible).
- Sorties (ignorées par git) : tools/render/out/levels/assembler/nNN/*.png et nNN.json ; caches effacés après usage.
- Mode complet : écrit aussi le manifeste tools/render/manifests/levels-assembler.json.
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
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_blender  # noqa: E402
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import params  # noqa: E402

DATA = os.environ.get("FO_DATA", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
OUT = os.path.join(RENDER, "out", "levels", params.FAMILLE)
CACHE = os.path.join(RENDER, "cache", "levels", params.FAMILLE)
MANIFEST = os.path.join(RENDER, "manifests", "levels-%s.json" % params.FAMILLE)
ENTRY = os.path.join(HERE, "blender_entry.py")
LOCK = os.path.join(RENDER, "with_render_lock.py")
LAYERS = ("main", "shadow", "glow", "light", "tuyaux_ns", "tuyaux_ew")


def parse_levels(s):
    out = []
    for part in s.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return [n for n in out if 2 <= n <= 30]


def vanilla_frame_alpha(key):
    v = params.VANILLA[key]
    im = np.asarray(Image.open(os.path.join(DATA, "base", "graphics", "entity", v["file"])).convert("RGBA"))
    w, h = v["frame"]
    return im[:h, :w, 3].astype(np.float64) / 255.0, v["shift"]


def place(canvas_shape, origin, alpha, shift, ppt):
    h, w = alpha.shape
    H, W = canvas_shape
    out = np.zeros((H, W))
    x0 = origin[0] + shift[0] * ppt - w / 2.0
    y0 = origin[1] + shift[1] * ppt - h / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    if abs(x0 - xi) > 1e-6 or abs(y0 - yi) > 1e-6:
        raise ValueError("masque vanilla hors grille (%.3f, %.3f)" % (x0, y0))
    xs0, ys0, xd0, yd0 = max(0, -xi), max(0, -yi), max(0, xi), max(0, yi)
    ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
    if ww > 0 and hh > 0:
        out[yd0:yd0 + hh, xd0:xd0 + ww] = alpha[ys0:ys0 + hh, xs0:xs0 + ww]
    return out


def blender_call(ns, samples, mode, cdir, log):
    """Un appel Blender (un passage par le verrou) pour un lot de niveaux."""
    # Le verrou officiel (with_render_lock.py, inchangé) est tenté avec --wait 0 toutes les secondes : il sort avec le
    # code 2 et « délai dépassé » quand les 2 places sont prises, sans rien lancer. Son attente interne interroge toutes
    # les 5 s ; d'autres lots relancent plus souvent et prenaient chaque place libérée (attentes de 25 min mesurées).
    cmd = [sys.executable, LOCK, "--wait", "0", "--", fo_blender.blender_exe(), "-b", "--factory-startup", "-noaudio",
           "-P", ENTRY, "--", "--levels", ",".join(str(n) for n in ns), "--out", cdir, "--samples", str(samples),
           "--mode", mode]
    t0 = time.time()
    while True:
        p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if not (p.returncode == 2 and "[FO-RENDER]" not in p.stdout and "[fo-render]" in p.stdout
                and "Blender" not in p.stdout):
            break
        time.sleep(1.0)
    with open(log, "a", encoding="utf-8") as f:
        f.write(" ".join(cmd) + "\n" + p.stdout[-3000:] + p.stderr[-3000:] + "\n")
    for line in p.stdout.splitlines():
        if line.startswith("[FO-ERREUR]"):
            print(line, flush=True)
    if "[FO-ERREUR]" in p.stdout:
        print(p.stdout[p.stdout.index("[FO-ERREUR]"):][:3000], flush=True)
    if p.returncode != 0 or "[FO-RENDER]" not in p.stdout:
        raise RuntimeError("échec du rendu des niveaux %s (code %s) :\n%s\n%s" % (ns, p.returncode, p.stdout[-2500:],
                                                                                  p.stderr[-2500:]))
    return time.time() - t0


def pool_layer(shape, origin, n):
    """Flaque de lumière imposée (params.flaque : rayon S(N) de la bible §1.6, alpha 0,1 à S), couleur émissive de
    l'époque, centrée sur l'entité ; couche additive codée (RGB = c / max, A = max)."""
    f = params.flaque(n)
    H_, W_ = shape
    yy, xx = np.mgrid[0:H_, 0:W_]
    d = np.hypot(xx + 0.5 - origin[0], yy + 0.5 - origin[1]) / 64.0
    a = np.where(d <= f["r0"], f["a0"], f["a0"] * np.clip((f["r1"] - d) / (f["r1"] - f["r0"]), 0.0, 1.0))
    h = params.EPOQUES[params.epoque(n)]["emissif"].lstrip("#")
    c = np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
    c = c / c.max()
    out = np.zeros((H_, W_, 4))
    out[..., :3] = c
    out[..., 3] = a
    return out


def add_max(a, b):
    """Union de deux couches additives codées : maximum des couleurs prémultipliées, canal par canal."""
    pm = np.maximum(a[..., :3] * a[..., 3:4], b[..., :3] * b[..., 3:4])
    m = pm.max(-1, keepdims=True)
    rgb = np.where(m > 1e-6, pm / np.maximum(m, 1e-6), 0)
    return np.concatenate([rgb, m], -1)


def light_layer(li, info, n, main_alpha, body_alpha=None):
    origin = info["origin_px"]
    lay = P.additive_layer(li)
    best = None
    for w in info["halo"]:
        dx, dy, z = w["at"]
        u, v = C.blender_to_screen_px(0.0, 0.0, z)
        center = (origin[0] + dx * 64.0 + u, origin[1] + dy * 64.0 + v)
        wl = P.radial_window(lay, center, w["r"][0] * 64.0, w["r"][1] * 64.0)
        best = wl if best is None else np.concatenate([wl[..., :3], np.maximum(best[..., 3:], wl[..., 3:])], -1)
    out = P.floor_alpha(P.fade_edges(best))
    ground = (main_alpha < 0.5) & (out[..., 3] > 0)
    if body_alpha is not None:          # niveau 2 : le corps vanilla n'est pas du sol
        ground &= body_alpha < 0.5
    if ground.any():
        ref = float(np.percentile(out[..., 3][ground], 99.5))
        if ref > 1e-4:
            f = float(np.clip(params.halo_cible(n) / ref, 0.25, 3.0))
            out[..., 3] = np.clip(out[..., 3] * f, 0, 1)
    # taille du halo IMPOSÉE par la bible (D2-3, correction V3 du 22/10) : la lumière rendue est bornée au disque de
    # rayon S(N) centré sur l'entité (pleine jusqu'à 0,85·S, nulle à S), puis la flaque (alpha 0,1 exactement à S)
    # est ajoutée : la surface d'alpha > 0,1 vaut π·S(N)², strictement croissante avec N
    out = clamp_disc(out, origin, n)
    out = add_max(out, pool_layer(out.shape[:2], origin, n))
    return P.floor_alpha(P.fade_edges(out, 8))


def clamp_disc(img, origin, n):
    S = params.flaque(n)["S"]
    H_, W_ = img.shape[:2]
    yy, xx = np.mgrid[0:H_, 0:W_]
    d = np.hypot(xx + 0.5 - origin[0], yy + 0.5 - origin[1]) / 64.0
    out = img.copy()
    out[..., 3] = out[..., 3] * np.clip((S - d) / (0.15 * S), 0.0, 1.0)
    return out


def rehalo(n):
    """Applique la borne du halo (clamp_disc + flaque) à la couche halo DÉJÀ rendue d'un niveau (sans relancer
    Blender) : recadrage et shift inchangés ; réécrit hr et basse résolution, et les sommes du nNN.json."""
    d = os.path.join(OUT, "n%02d" % n)
    p = os.path.join(d, "n%02d.json" % n)
    with open(p, encoding="utf-8") as f:
        rec = json.load(f)
    sd = rec["spec"].get("light")
    if not sd:
        return False
    fn = os.path.join(d, sd["hr"]["filename"])
    img = np.asarray(Image.open(fn).convert("RGBA")).astype(np.float64) / 255.0
    h, w = img.shape[:2]
    sx, sy = sd["hr"]["shift"]
    origin = (w / 2.0 - sx * 64.0, h / 2.0 - sy * 64.0)
    out = add_max(clamp_disc(img, origin, n), pool_layer((h, w), origin, n))
    out = P.floor_alpha(out)
    rec["files"][sd["hr"]["filename"]] = P.write_png(out, fn)
    lr = P.downsample2_additive(out)
    rec["files"][sd["lr"]["filename"]] = P.write_png(lr, os.path.join(d, sd["lr"]["filename"]))
    rec["halo_rebound"] = "flaque S(N) et borne au disque appliquées après rendu (rendre.py --rehalo, 22/10)"
    with open(p, "w", encoding="utf-8") as f:
        json.dump(rec, f, indent=1, sort_keys=True)
    return True


def post_level(n, cdir, odir):
    with open(os.path.join(cdir, "n%02d-render.json" % n), encoding="utf-8") as f:
        info = json.load(f)

    def npy(layer):
        p = os.path.join(cdir, "n%02d-%s.npy" % (n, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    origin = tuple(info["origin_px"])
    hr = {"main": P.compose_main(npy("main"), npy("ao"), C), "shadow": P.shadow_layer(npy("shadow"))}
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
    masked = n == 2
    m_hr = None
    if masked:
        a_hr, sh_hr = vanilla_frame_alpha("main")
        m_hr = place(hr["main"].shape[:2], origin, a_hr, sh_hr, 64)
    li = npy("light")
    if li is not None:
        hr["light"] = light_layer(li, info, n, hr["main"][..., 3], m_hr)
    for key in ("tuyaux_ns", "tuyaux_ew"):            # départs de tuyau (pipe_picture de l'époque), sans liseré
        t_ = npy(key.replace("tuyaux", "tuyau") + "-main")
        if t_ is not None and (t_[..., 3] > 1.0 / 255).any():
            hr[key] = P.compose_main(t_, None, C)
    me = npy("meca-main")                              # part visible du mécanisme animé (contrôle, pas une couche)
    if me is not None:
        os.makedirs(odir, exist_ok=True)
        Image.fromarray(np.clip(np.round(me[..., 3] * 255), 0, 255).astype(np.uint8), "L").save(
            os.path.join(odir, "n%02d-meca-alpha.png" % n), optimize=True)
    raw = dict(hr)
    if masked:
        for k in ("main", "glow"):
            if k in hr:
                hr[k] = P.mask_with(hr[k], m_hr)
    name = "%s-n%02d" % (params.FAMILLE, n)
    os.makedirs(odir, exist_ok=True)
    files, spec = {}, {}
    for layer in LAYERS:
        if layer not in hr:
            continue
        box = P.trim_box(hr[layer], origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop_hr = hr[layer][y0:y1, x0:x1]
        src = raw[layer][y0:y1, x0:x1]
        crop_lr = P.downsample2_additive(src) if layer in ("glow", "light") else P.downsample2(src)
        if masked and layer in ("main", "glow"):
            a_lr, sh_lr = vanilla_frame_alpha("main_lr")
            lr_origin = ((origin[0] - x0) / 2.0, (origin[1] - y0) / 2.0)
            crop_lr = P.mask_with(crop_lr, place(crop_lr.shape[:2], lr_origin, a_lr, sh_lr, 32))
        fn_hr, fn_lr = "hr-%s-%s.png" % (name, layer), "%s-%s.png" % (name, layer)
        files[fn_hr] = P.write_png(crop_hr, os.path.join(odir, fn_hr))
        files[fn_lr] = P.write_png(crop_lr, os.path.join(odir, fn_lr))
        spec[layer] = {"hr": dict(P.sprite_def(box, origin, 64), filename=fn_hr),
                       "lr": dict(P.sprite_def(box, origin, 32), filename=fn_lr)}
    icon = P.icon_strip(hr["main"])
    files["%s-icon.png" % name] = P.write_png(icon, os.path.join(odir, "%s-icon.png" % name))
    if me is not None:
        spec["_meca_alpha"] = {"filename": "n%02d-meca-alpha.png" % n, "origin_px": list(origin),
                               "note": "contrôle : alpha visible du module meca (8 échantillons), pas une couche de jeu"}
    rec = {"level": n, "epoch": params.epoque(n), "spec": spec, "files": files, "modules": info["modules"],
           "parts": info.get("parts", {}),
           "halo_windows": info["halo"], "masked_by_vanilla": masked,
           "render": {k: info[k] for k in ("canvas", "origin_px", "samples", "seed", "threads", "blender",
                                           "blender_hash", "objects", "seconds", "t")}}
    with open(os.path.join(odir, "n%02d.json" % n), "w", encoding="utf-8") as f:
        json.dump(rec, f, indent=1, sort_keys=True)
    return rec


def post_mask(n, cdir, odir):
    with open(os.path.join(cdir, "n%02d-render.json" % n), encoding="utf-8") as f:
        info = json.load(f)
    a = np.load(os.path.join(cdir, "n%02d-main.npy" % n))[..., 3]
    if n == 2:
        a_hr, sh_hr = vanilla_frame_alpha("main")
        a = a * (1 - place(a.shape, tuple(info["origin_px"]), a_hr, sh_hr, 64))
    os.makedirs(odir, exist_ok=True)
    Image.fromarray(np.clip(np.round(a * 255), 0, 255).astype(np.uint8), "L").save(
        os.path.join(odir, "masque-n%02d.png" % n))
    with open(os.path.join(odir, "masque-n%02d.json" % n), "w", encoding="utf-8") as f:
        json.dump({"origin_px": info["origin_px"], "canvas": info["canvas"]}, f)


def _drawing_box(spec):
    """Enveloppe visuelle (tuiles) des couches principale et lueur : proposition de drawing_box (bible §1.8-4)."""
    xs, ys = [], []
    for k in ("main", "glow"):
        d = spec.get(k)
        if not d:
            continue
        h = d["hr"]
        sx, sy = h["shift"]
        w, hh = h["width"] / 64.0, h["height"] / 64.0
        xs += [sx - w / 2, sx + w / 2]
        ys += [sy - hh / 2, sy + hh / 2]
    if not xs:
        return None
    r = lambda v: round(v * 64) / 64.0
    return [[r(min(xs)), r(min(ys))], [r(max(xs)), r(max(ys))]]


def _phase2_files(n):
    """Contrat de fichiers de la bible (§1.9) pour la phase 2 : graphics/levels/assembler/eNN/[piece/]."""
    e = params.epoque(n)
    base = "__factorio-overhaul__/graphics/levels/%s/e%02d/" % (params.FAMILLE, e)
    if n % 2 == 1:
        out = {}
        for mod in ("corps", "meca"):
            for ps in ("couleur", "ombre", "emissif", "lumiere"):
                out["%s-%s" % (mod, ps)] = base + "hr-%s-%s.png" % (mod, ps)
        # pipe_picture de l'époque (correction V3 du 22/10 : les pipe_picture vanilla flottent loin des corps levés)
        for d in ("N", "E", "S", "W"):
            out["tuyau-%s" % d] = base + "hr-tuyau-%s.png" % d
        return out
    return {"piece-%s" % ps: base + "piece/hr-piece-%s.png" % ps for ps in ("couleur", "ombre", "emissif", "lumiere")}


def write_manifest(recs, samples, seconds):
    mes = {}
    pm = os.path.join(OUT, "mesures-d1.json")
    if os.path.exists(pm):
        with open(pm, encoding="utf-8") as f:
            mes = json.load(f).get("levels", {})
    levels = []
    for n in range(1, 31):
        e = params.epoque(n)
        E = params.EPOQUES[e]
        ent = {"level": n, "epoch": e, "step": 2 if n % 2 == 0 else 1, "theme": E["theme"], "era": E["ere"],
               "kind": "vanilla" if n == 1 else ("piece" if n % 2 == 0 else "silhouette"),
               "silhouette": E["impair"], "piece": E["piece"] if n % 2 == 0 else None,
               "light": E["lumiere"], "emissive": E["emissif"], "night_only": E["nuit_seule"],
               "envelope": {"O": params.ENVELOPPE[e][0], "L": params.ENVELOPPE[e][1], "V_pct": params.ENVELOPPE[e][2]}}
        if n == 1:
            ent["layers"] = {k: v for k, v in params.VANILLA.items()}
            ent["note"] = "sprite vanilla inchangé (Q11) : aucune image produite ; référence de D1-3"
        elif n in recs:
            r = recs[n]
            ent["layers"] = r["spec"]
            ent["icon"] = {"filename": "%s-n%02d-icon.png" % (params.FAMILLE, n), "icon_size": 64, "icon_mipmaps": 4}
            ent["modules"] = r["modules"]
            ent["parts"] = r.get("parts", {})
            ent["files_sha256"] = r["files"]
            ent["halo_windows"] = r["halo_windows"]
            db = _drawing_box(r["spec"])
            if n == 2 and db:               # niveau 2 : union avec le sprite vanilla (214 × 218 hr, shift (0 ; 0,125))
                v = params.VANILLA["main"]
                w, h = v["frame"][0] / 64.0, v["frame"][1] / 64.0
                sx, sy = v["shift"]
                db = [[min(db[0][0], sx - w / 2), min(db[0][1], sy - h / 2)],
                      [max(db[1][0], sx + w / 2), max(db[1][1], sy + h / 2)]]
            ent["drawing_box"] = db
            ent["phase2_files"] = _phase2_files(n)
            ent["render"] = r["render"]
            if n == 2:
                ent["base"] = ("vanilla (couches du niveau 1, 32 images, inchangées) + pièce : couche principale masquée "
                               "au pixel par l'alpha vanilla (image 0), ombre, halo (rendu avec un volume de "
                               "remplacement du corps vanilla, F64)")
            elif n % 2 == 0:
                ent["base"] = "niveau %d + pièce (module « piece » : couche séparée en phase 2)" % (n - 1)
        m = mes.get(str(n))
        if m:
            ent["measures_d1"] = {k: m[k] for k in ("O_masses", "O_carre", "O_total", "L_masses", "area", "V_pct",
                                                     "iou_1", "niou_1", "iou_prev", "piece_added", "events",
                                                     "meca_share", "halo_surface") if k in m}
        levels.append(ent)
    man = {
        "family": params.FAMILLE, "name": params.NOM, "footprint": params.EMPRISE, "ceiling_O": params.PLAFOND_O,
        "status": "APERÇU phase 1 (échantillons réduits) : ni rendu final, ni branchement en jeu ; design NON validé "
                  "(seul le verdict du Directeur Créatif valide)",
        "dest_preview": os.path.relpath(OUT, MOD_ROOT).replace("\\", "/"),
        "conventions": {"hr_px_per_tile": 64, "hr_scale": 0.5, "lr_px_per_tile": 32,
                        "shift": "tuiles, multiples exacts de 1/64, relatifs à la position de l'entité",
                        "layers": {"main": "couche principale (liseré de contact compris)",
                                   "shadow": "draw_as_shadow (noir, alpha = part d'ombre)",
                                   "glow": "draw_as_glow, blend additive (RGB = c/max, A = max)",
                                   "light": "draw_as_light, blend additive (halo de nuit)"},
                        "animation": "phase 1 : pose de référence seule (image 0, t = 0) ; phase 2 : corps fixe "
                                     "rendu une fois + mécanisme (module meca) en 32 images, corps en cache ; pièce paire "
                                     "en couche séparée (1 image, repeat_count = 32)"},
        "interface_v2": {
            "fichier": "prototypes/levels/assembler.lua (garde de prototypes/levels/common.lua : dress ne touche que "
                       "les champs graphiques)",
            "dress(p, ctx)": [
                "e = ctx.epoch ; n = ctx.level ; ctx.step == 1 : silhouette de l'époque, ctx.step == 2 : la même + pièce",
                "p.animation = { layers = { main (hr : width, height, shift, scale = 0.5 ; phase 2 : frame_count = 32, "
                "line_length = 8), shadow (draw_as_shadow = true) } } ; niveau 2 : couches vanilla INCHANGÉES + couches "
                "de la pièce avec repeat_count = 32",
                "p.working_visualisations = { { always_draw = true, animation = glow (draw_as_glow = true, "
                "blend_mode = \"additive\") }, { always_draw = true, animation = light (draw_as_light = true, "
                "blend_mode = \"additive\") } } ; époques 1 et 2 : pas de lueur de jour (lumière de nuit seulement) ; "
                "halo proportionnel au niveau (bible §1.6, D2-3) par une LightDefinition (intensity 0,05 + 0,02·n, "
                "size 3 × (1 + 0,05·n), color = émissif d'époque) : à mesurer en jeu",
                "p.drawing_box = drawing_box du niveau (ci-dessous) ; collision_box et selection_box : INCHANGÉES (D1-4)",
                "p.icons via icons(icons, ctx) : rendu de la pose de référence (64 px, 4 mipmaps) + numéro de niveau",
                "tuyaux : fluid_boxes (0,-2) et (0,2) inchangés (secondary_draw_orders = { north = -1 } comme le "
                "vanilla) ; pipe_picture PAR ÉPOQUE (N, E, S, W : modules tuyau_ns et tuyau_ew de modeles.py, bout "
                "calé sur le tuyau vanilla au bord de l'emprise), shift relatif au point de raccord (0,-2), (2,0), "
                "(0,2), (-2,0) ; pipe_covers vanilla gardées (le bout du départ a la section du tuyau vanilla). Aperçu "
                "phase 1 : couches tuyaux_ns et tuyaux_ew des niveaux impairs (N+S et E+O ensemble). Capture en jeu "
                "avec une recette à fluide : À FAIRE en phase 2 (bible §1.8-6)",
                "lumière : la couche light contient la flaque au rayon S(N) = 0,80 × (1 + 0,05·n) (params.flaque) ; "
                "LightDefinition de phase 2 : size = 2·S(N), intensity 0,05 + 0,02·n"]},
        "preview_render": {"samples": samples, "seconds_total": round(seconds, 1),
                           "blender": C.BLENDER_VERSION, "calib": {k: getattr(C, k) for k in dir(C) if k.isupper()}},
        "sources": {"modeles": "tools/render/pieces/levels/assembler/modeles.py",
                    "kit": "tools/render/pieces/levels/assembler/kit.py",
                    "params": "tools/render/pieces/levels/assembler/params.py",
                    "rendu": "tools/render/pieces/levels/assembler/rendre.py",
                    "mesures": "tools/render/pieces/levels/assembler/mesures_d1.py",
                    "planches": "tools/render/pieces/levels/assembler/planches.py"},
        "levels": levels,
    }
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, ensure_ascii=False, sort_keys=False)


def manifest_only():
    recs = {}
    for n in range(2, 31):
        p = os.path.join(OUT, "n%02d" % n, "n%02d.json" % n)
        if os.path.exists(p):
            with open(p, encoding="utf-8") as f:
                recs[n] = json.load(f)
    smp = recs[min(recs)]["render"]["samples"] if recs else 0
    secs = sum(r["render"].get("seconds", 0) for r in recs.values())
    write_manifest(recs, smp, secs)
    print("[FO-MANIFESTE] %s (%d niveaux rendus)" % (MANIFEST, len(recs)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="2-30")
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--mode", default="complet", choices=("complet", "masque"))
    ap.add_argument("--batch", type=int, default=6, help="niveaux par appel Blender (un passage par le verrou)")
    ap.add_argument("--no-manifest", action="store_true")
    ap.add_argument("--manifest-only", action="store_true", help="réécrit le manifeste depuis les rendus existants")
    ap.add_argument("--rehalo", default="", help="niveaux dont la couche halo existante reçoit la borne S(N)")
    a = ap.parse_args()
    if a.rehalo:
        for n in parse_levels(a.rehalo):
            print("[FO-HALO] niveau %d : %s" % (n, "borné" if rehalo(n) else "sans couche halo"))
        return None
    if a.manifest_only:
        return manifest_only()
    levels = parse_levels(a.levels)
    os.makedirs(CACHE, exist_ok=True)
    log = os.path.join(CACHE, "blender.log")
    t0 = time.time()
    recs = {}
    for i in range(0, len(levels), a.batch):
        ns = levels[i:i + a.batch]
        cdir = os.path.join(CACHE, "lot")
        shutil.rmtree(cdir, ignore_errors=True)
        dt = blender_call(ns, a.samples, a.mode, cdir, log)
        for n in ns:
            if not os.path.exists(os.path.join(cdir, "n%02d-render.json" % n)):
                print("[FO-NIVEAU] niveau %d : rendu absent (erreur ci-dessus)" % n, flush=True)
                continue
            if a.mode == "masque":
                post_mask(n, cdir, os.path.join(OUT, "masques"))
            else:
                recs[n] = post_level(n, cdir, os.path.join(OUT, "n%02d" % n))
        shutil.rmtree(cdir, ignore_errors=True)
        print("[FO-NIVEAU] %s %s en %.1f s (attente du verrou comprise)" % (ns, a.mode, dt), flush=True)
    if a.mode == "complet" and not a.no_manifest:
        for n in range(2, 31):
            if n not in recs:
                p = os.path.join(OUT, "n%02d" % n, "n%02d.json" % n)
                if os.path.exists(p):
                    with open(p, encoding="utf-8") as f:
                        recs[n] = json.load(f)
        write_manifest(recs, a.samples, time.time() - t0)
    print("[FO-RENDU] %d niveau(x) en %.1f s" % (len(levels), time.time() - t0))


if __name__ == "__main__":
    main()
