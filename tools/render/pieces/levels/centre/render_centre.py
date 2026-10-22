"""Pilote des rendus d'APERÇU du centre de commandement (lot V3-a, phase 1). Python système.

    python tools/render/with_render_lock.py -- python -P tools/render/pieces/levels/centre/render_centre.py \
        [--levels 1-15] [--samples 64] [--mask-samples 8] [--only full|masks|quick]

Toujours lancé SOUS le verrou de rendu (CLAUDE.md §4, interdit 6) : le script le VÉRIFIE avant tout appel à
Blender (un dossier <racine du jeu>/fo-render.lock.<k> dont owner.txt porte le PID d'un processus ancêtre) et
refuse de rendre sinon ; la place obtenue est tracée dans render.json (« render_lock »), avec l'empreinte
sha256 des scripts du centre (« scripts_sha256 »). N'écrit que dans :
  tools/render/out/levels/centre/   (aperçus : 4 couches hr + lr, masques, json ; ignoré par git)
  tools/render/cache/levels-centre/ (rendus 16 bits bruts, EFFACÉS après chaque niveau : disque limité)
Réutilise sans les modifier fo_blender.render (appel de Blender) et fo_post (post-traitement V0).
Différences avec render.py (pipeline partagé) : fenêtres de halo propres à chaque niveau
(centre_params.HALO), masques D1 sans couches plates (« -sil ») et sans tiges (« -mass »), purge des caches,
et surtout DEUX rendus par niveau (correction V3 du 21/10) :
  « nEE-jour » (émissifs ÉTEINTS, verre sombre de leur teinte) -> couches main, ao, shadow ;
  « nEE »      (émissifs allumés)                               -> couches glow, light.
La couche principale ne contient donc plus l'émission : la lueur draw_as_glow, additive, n'est comptée
qu'une fois (avant : main + glow doublaient l'éclat ; 79 à 96 % des pixels de lueur saturés). Aux époques 1-2
la même lueur sert de lumière de nuit seulement (draw_as_light, manifeste et planches).
Lueur bornée (tame_glow, 2e correction du 22/10) : là où main + lueur ferait du blanc (min(R, G, B) >= 238), la
lueur de ce pixel est réduite juste assez pour garder sa teinte ; nombre de pixels bornés dans render.json.
Couche light : énergie normalisée sur centre_params.light_target (croissante avec l'époque, D2-3).
Mode --only quick : aperçu de réglage (couche principale seule, out/levels/centre/quick/), seul mode permis avec
le réglage d'essai FO_CENTRE_TUNE (un rendu livré est refusé si la variable existe). Un niveau en échec n'arrête
pas les suivants (code de sortie 1 à la fin).
"""
import argparse
import glob
import hashlib
import json
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD_ROOT = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_blender  # noqa: E402
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402
import centre_params as PR  # noqa: E402

PIECE = os.path.join(HERE, "centre.py")
LOCK_DIR = os.environ.get("FO_RENDER_LOCK_DIR", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91")
OUT = os.path.join(RENDER, "out", "levels", "centre")
CACHE = os.path.join(RENDER, "cache", "levels-centre")
MARGIN = 40


def scripts_sha256():
    """Empreinte des scripts qui fixent la géométrie et les matériaux (preuve de correspondance avec le commit)."""
    out = {}
    for p in sorted(glob.glob(os.path.join(HERE, "centre*.py")) + [os.path.join(HERE, "render_centre.py")]):
        with open(p, "rb") as f:
            out[os.path.basename(p)] = hashlib.sha256(f.read()).hexdigest()
    return out


def lock_held():
    """Vérifie que ce processus tourne SOUS with_render_lock.py : un dossier fo-render.lock.<k> dont owner.txt
    porte le PID d'un de nos ancêtres (le script du verrou lance la commande en sous-processus). Renvoie la
    trace (dossier, PID, ligne de owner.txt) ou None. Lecture seule : ne prend ni ne libère aucun verrou."""
    try:
        import psutil
        anc = set()
        p = psutil.Process(os.getpid())
        for _ in range(6):
            p = p.parent()
            if p is None:
                break
            anc.add(p.pid)
    except Exception:  # psutil absent : parent direct seulement
        anc = {os.getppid()}
    for d in sorted(glob.glob(os.path.join(LOCK_DIR, "fo-render.lock.*"))):
        try:
            with open(os.path.join(d, "owner.txt"), encoding="utf-8") as f:
                line = f.read().strip()
            pid = int(line.split()[0])
        except (OSError, ValueError, IndexError):
            continue
        if pid in anc:
            return {"slot": os.path.basename(d), "owner_pid": pid, "owner": line[:400],
                    "checked": time.strftime("%Y-%m-%d %H:%M:%S")}
    return None


def parse_levels(s):
    out = []
    for part in s.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return out


def load_npy(info, layer):
    p = os.path.join(info["_dir"], "%s-%s.npy" % (info["_prefix"], layer))
    return np.load(p).astype(np.float64) if os.path.exists(p) else None


def purge(info):
    d, pre = info["_dir"], info["_prefix"]
    for fn in os.listdir(d):
        if fn.startswith(pre + "-") and (fn.endswith(".png") or fn.endswith(".npy")):
            os.remove(os.path.join(d, fn))


def run_blender(variant, samples, layers, log, dump=None):
    if dump:
        os.environ["FO_CENTRE_DUMP"] = dump
    else:
        os.environ.pop("FO_CENTRE_DUMP", None)
    info, dt = fo_blender.render(PIECE, variant, CACHE, samples=samples, layers=layers, margin=MARGIN, log=log)
    return info, dt


def halo_layer(light, origin, e):
    """Couche halo bornée par des fenêtres circulaires (même principe que render.py) : chaque fenêtre ne
    change que l'alpha de la même couche, donc l'union des fenêtres = maximum des alphas."""
    lay = P.additive_layer(light)
    alpha = None
    for (x, ty, z, _col, _pw, r0, r1, g0, g1) in PR.HALO.get(e, []):
        wins = [((x, ty, z), (r0, r1))]
        if g1 > 0:
            wins.append(((x, ty, 0.0), (g0, g1)))
        for (cx, cty, cz), (a, b) in wins:
            u, v = C.blender_to_screen_px(0.0, 0.0, cz)
            center = (origin[0] + cx * 64.0 + u, origin[1] + cty * 64.0 + v)
            wa = P.radial_window(lay, center, a * 64, b * 64)[..., 3]
            alpha = wa if alpha is None else np.maximum(alpha, wa)
    if alpha is None:
        return None
    out = lay.copy()
    out[..., 3] = alpha
    return P.floor_alpha(P.fade_edges(out))


LUMA = np.array([0.2126, 0.7152, 0.0722])


def normalize_light(lay, target):
    """Couche additive (codée c / max, A = max) dont l'ÉNERGIE (somme de la luminance émise / 64², en t²) est
    ramenée à `target` par un gain (dichotomie ; écrêtage à 1 compris). D2-3 : halo de nuit croissant avec le
    niveau (centre_params.light_target). Renvoie (couche, gain)."""
    pm = lay[..., :3] * lay[..., 3:4]

    def energy(g):
        return float((np.clip(pm * g, 0, 1) @ LUMA).sum() / 64.0 ** 2)
    if energy(1.0) <= 0:
        return lay, 1.0
    lo, hi = 0.0, 40.0
    if energy(hi) < target:
        g = hi
    else:
        for _ in range(40):
            mid = (lo + hi) / 2
            if energy(mid) < target:
                lo = mid
            else:
                hi = mid
        g = (lo + hi) / 2
    c = np.clip(pm * g, 0, 1)
    m = c.max(-1, keepdims=True)
    rgb = np.where(m > 1e-6, c / np.maximum(m, 1e-6), 0)
    return np.concatenate([rgb, m], -1), g


WHITE_T = 238.0 / 255.0


def tame_glow(glow, main, t=WHITE_T):
    """Lueur additive BORNÉE sur les surfaces claires (2e correction V3 du 22/10) : là où main + lueur donnerait du
    blanc (min(R, G, B) >= 238/255 : le halo du cœur déborde sur l'alliage blanc, la nacre ou un reflet), la lueur
    de CE pixel est réduite juste assez pour qu'un canal au moins reste sous le seuil (sa teinte garde la couleur
    de la bible) ; sur un pixel déjà blanc dans la couche principale (reflet spéculaire), la lueur est retirée.
    Ailleurs, rien ne change. Les deux couches sont sur le même canevas. Renvoie (lueur, nombre de pixels bornés)."""
    base = main[..., :3] * main[..., 3:4]
    add = glow[..., :3] * glow[..., 3:4]
    hot = (base + add).min(-1) >= t
    if not hot.any():
        return glow, 0
    with np.errstate(divide="ignore", invalid="ignore"):
        sj = np.where((base < t) & (add > 1e-6), (t - 2e-3 - base) / np.maximum(add, 1e-6), -1.0)
    s = np.where(hot, np.clip(sj.max(-1), 0.0, 1.0), 1.0)
    c = add * s[..., None]
    m = c.max(-1, keepdims=True)
    rgb = np.where(m > 1e-6, c / np.maximum(m, 1e-6), 0)
    return np.concatenate([rgb, m], -1), int(hot.sum())


def dilate(m, r):
    """Dilatation d'un masque booléen par un carré de côté 2r+1 (décalages successifs, numpy seul)."""
    out = m.copy()
    for _ in range(r):
        o = out.copy()
        o[1:, :] |= out[:-1, :]
        o[:-1, :] |= out[1:, :]
        o[:, 1:] |= out[:, :-1]
        o[:, :-1] |= out[:, 1:]
        out = o
    return out


def compose_main_clean(main_raw, ao):
    """Couche principale = rendu + liseré de contact (fo_post.compose_main, inchangé), MAIS le liseré est
    borné à 14 px hr autour de la pièce : aux échantillons réduits, le bruit de la passe AO laisse des
    pixels isolés (alpha 0,01 à 0,09) loin de la pièce, qui agrandissaient le recadrage et la drawing_box
    (constaté sur le premier aperçu du niveau 15 : 3 pixels à 22/255 jusqu'à 5 tuiles à l'est)."""
    near = dilate(main_raw[..., 3] > 0.02, 14)
    ao = ao.copy()
    ao[~near, 3] = 0.0
    return P.compose_main(main_raw, ao, C)


def write_layer(img, origin, layer, name, dest):
    box = P.trim_box(img, origin)
    if box is None:
        return None
    x0, y0, x1, y1 = box
    crop = img[y0:y1, x0:x1]
    lr = P.downsample2_additive(crop) if layer in ("glow", "light") else P.downsample2(crop)
    fn_hr, fn_lr = "hr-%s-%s.png" % (name, layer), "%s-%s.png" % (name, layer)
    h_hr = P.write_png(crop, os.path.join(dest, fn_hr))
    h_lr = P.write_png(lr, os.path.join(dest, fn_lr))
    sd_hr, sd_lr = P.sprite_def(box, origin, 64), P.sprite_def(box, origin, 32)
    return {"hr": dict(sd_hr, filename=fn_hr, sha256=h_hr), "lr": dict(sd_lr, filename=fn_lr, sha256=h_lr)}


def save_mask(alpha, origin, path):
    """Masque binaire (alpha ≥ 0,5) recadré, avec la position de l'origine de l'entité dans le recadrage."""
    m = alpha >= 0.5
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    np.savez_compressed(path, mask=np.packbits(m[y0:y1, x0:x1], axis=1), shape=np.array([y1 - y0, x1 - x0]),
                        origin=np.array([origin[0] - x0, origin[1] - y0]))


def render_level(e, samples, mask_samples, what, log, lock):
    name = "centre-n%02d" % e
    dest = os.path.join(OUT, "n%02d" % e)
    os.makedirs(dest, exist_ok=True)
    rec = {"level": e, "epoch": e, "name": PR.NAMES[e], "variant": "n%02d" % e}
    t0 = time.time()
    if what in ("all", "full"):
        dump = os.path.join(dest, "pieces.json")
        # main, ao, shadow : émissifs éteints ; glow, light : émissifs allumés (même géométrie, même canevas)
        ij, dt1 = run_blender("n%02d-jour" % e, samples, ["main", "ao", "shadow"], log, dump=dump)
        inn, dt2 = run_blender("n%02d" % e, samples, ["glow", "light"], log)
        if ij["canvas"] != inn["canvas"] or ij["origin_px"] != inn["origin_px"]:
            raise RuntimeError("jour et lueur sur des canevas différents : %s / %s" % (ij["canvas"], inn["canvas"]))
        infos = [ij, inn]
        origin = tuple(ij["origin_px"])
        main = compose_main_clean(load_npy(ij, "main"), load_npy(ij, "ao"))
        layers = {"main": main, "shadow": P.shadow_layer(load_npy(ij, "shadow"))}
        src = inn
        g = load_npy(src, "glow")
        if g is not None:
            gl, n_tamed = tame_glow(P.additive_layer(g), main)
            rec["glow_tamed_px"] = n_tamed
            layers["glow"] = gl
        li = load_npy(src, "light")
        if li is not None:
            hl = halo_layer(li, origin, e)
            if hl is not None:
                hl, lg = normalize_light(hl, PR.light_target(e))
                rec["light_gain"] = round(lg, 4)
                rec["light_target_t2"] = PR.light_target(e)
                layers["light"] = hl
        spec = {}
        for layer, img in layers.items():
            sd = write_layer(img, origin, layer, name, dest)
            if sd:
                spec[layer] = sd
        save_mask(main[..., 3], origin, os.path.join(dest, "mask-full.npz"))
        rec.update({"spec": spec, "canvas": ij["canvas"], "origin_px": ij["origin_px"], "samples": ij["samples"],
                    "seed": ij["seed"], "blender": ij["blender"], "blender_hash": ij["blender_hash"],
                    "variants": {"main_ao_shadow": ij["variant"], "glow_light": inn["variant"]},
                    "main_sans_emission": True})
        for inf in infos:
            purge(inf)
    if what == "quick":
        # aperçu rapide de réglage (photométrie) : couche principale seule, dans out/levels/centre/quick/,
        # suffixé par FO_CENTRE_TAG (réglage d'essai FO_CENTRE_TUNE)
        iq, _ = run_blender("n%02d-jour" % e, samples, ["main", "ao"], log)
        mq = compose_main_clean(load_npy(iq, "main"), load_npy(iq, "ao"))
        qd = os.path.join(OUT, "quick")
        os.makedirs(qd, exist_ok=True)
        box = P.trim_box(mq, tuple(iq["origin_px"]))
        x0, y0, x1, y1 = box
        tag = os.environ.get("FO_CENTRE_TAG", "")
        P.write_png(mq[y0:y1, x0:x1], os.path.join(qd, "n%02d%s-main.png" % (e, ("-" + tag) if tag else "")))
        purge(iq)
        rec = {"quick": True}
    if what in ("all", "masks"):
        for suf in ("sil", "mass"):
            im, _ = run_blender("n%02d-%s" % (e, suf), mask_samples, ["main"], log)
            a = load_npy(im, "main")[..., 3]
            save_mask(a, tuple(im["origin_px"]), os.path.join(dest, "mask-%s.npz" % suf))
            purge(im)
    rec["seconds"] = round(time.time() - t0, 1)
    if what == "quick":
        return rec
    rec["render_lock"] = lock
    rec["scripts_sha256"] = scripts_sha256()
    rec["rendered_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
    old = {}
    pj = os.path.join(dest, "render.json")
    if os.path.exists(pj):
        with open(pj, encoding="utf-8") as f:
            old = json.load(f)
    old.update(rec)
    with open(pj, "w", encoding="utf-8") as f:
        json.dump(old, f, indent=1, sort_keys=True)
    return old


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="1-15")
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--mask-samples", type=int, default=8)
    ap.add_argument("--only", default="all", choices=("all", "full", "masks", "quick"))
    a = ap.parse_args()
    if a.only != "quick" and os.environ.get("FO_CENTRE_TUNE"):
        print("[FO-CENTRE] REFUS : FO_CENTRE_TUNE (réglage d'essai) est défini ; un rendu livré n'en dépend jamais.",
              flush=True)
        sys.exit(4)
    lock = lock_held()
    if lock is None:
        print("[FO-CENTRE] REFUS : pas lancé sous tools/render/with_render_lock.py (aucun fo-render.lock.<k> "
              "tenu par un processus ancêtre dans %s). CLAUDE.md §4, interdit 6." % LOCK_DIR, flush=True)
        sys.exit(3)
    print("[FO-CENTRE] verrou de rendu : %s (PID %d)" % (lock["slot"], lock["owner_pid"]), flush=True)
    os.makedirs(CACHE, exist_ok=True)
    log = os.path.join(CACHE, "blender.log")
    t0 = time.time()
    failed = []
    for e in parse_levels(a.levels):
        try:
            r = render_level(e, a.samples, a.mask_samples, a.only, log, lock)
        except Exception as exc:  # un niveau en échec n'arrête pas les suivants (le verrou est tenu)
            failed.append(e)
            print("[FO-CENTRE] n%02d ÉCHEC : %s" % (e, str(exc)[-1500:]), flush=True)
            continue
        print("[FO-CENTRE] n%02d %-28s %6.1f s" % (e, PR.NAMES[e], r["seconds"]), flush=True)
    if failed:
        print("[FO-CENTRE] niveaux en échec : %s" % failed, flush=True)
    # le journal Blender peut grossir : on le garde court
    if os.path.exists(log) and os.path.getsize(log) > 4_000_000:
        with open(log, "rb") as f:
            f.seek(-1_000_000, 2)
            tail = f.read()
        with open(log, "wb") as f:
            f.write(tail)
    print("[FO-CENTRE] total %.1f s" % (time.time() - t0))
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
