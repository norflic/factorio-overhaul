"""Commande unique du pipeline de rendu (lot V0, H-V1) : pièce source -> sprites Factorio prêts à charger.

    python tools/render/render.py tools/render/pieces/<piece>.py [--variants a,b] [--samples N]
                                  [--data "<racine>/data"] [--check]

Pour chaque variante déclarée dans PIECE["variants"] :
  1. Blender (sans interface) rend les passes main, ao, shadow, glow, light (fo_scene.render_passes) ;
  2. post-traitement : liseré de contact sous la couche principale, masque éventuel par un sprite
     vanilla, recadrage aligné sur la grille, version 32 px/tuile par réduction 2× ;
  3. écriture des PNG dans graphics/<dest>/, d'un fichier Lua de description des sprites
     (graphics/<dest>/sprites.lua : tailles, shift, drapeaux) et d'un manifeste (sommes SHA-256).
--check : refait tout dans un dossier temporaire et compare les octets au manifeste (déterminisme).
"""
import argparse
import hashlib
import importlib.util
import json
import os
import sys
import time

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fo_blender  # noqa: E402
import fo_calib as C  # noqa: E402
import fo_post as P  # noqa: E402

MOD_ROOT = os.path.dirname(os.path.dirname(HERE))
MOD_NAME = "factorio-overhaul"
DEFAULT_DATA = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data"
LAYERS = ("main", "shadow", "glow", "light")


def load_piece_meta(path):
    """Lit PIECE sans importer bpy (le module de pièce n'importe rien au niveau supérieur)."""
    spec = importlib.util.spec_from_file_location("fo_piece_meta", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.PIECE


def place_alpha(canvas_shape, origin, sprite_path, shift, px_per_tile):
    """Alpha d'un sprite vanilla posé sur un canevas (même grille), centre = origine + shift."""
    a = np.asarray(Image.open(sprite_path).convert("RGBA")).astype(np.float64)[..., 3] / 255.0
    h, w = a.shape
    H, W = canvas_shape
    out = np.zeros((H, W))
    x0 = origin[0] + shift[0] * px_per_tile - w / 2.0
    y0 = origin[1] + shift[1] * px_per_tile - h / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    if abs(x0 - xi) > 1e-6 or abs(y0 - yi) > 1e-6:
        raise ValueError("masque hors grille : %s (%.3f, %.3f)" % (sprite_path, x0, y0))
    xs0, ys0 = max(0, -xi), max(0, -yi)
    xd0, yd0 = max(0, xi), max(0, yi)
    ww = min(w - xs0, W - xd0)
    hh = min(h - ys0, H - yd0)
    if ww > 0 and hh > 0:
        out[yd0:yd0 + hh, xd0:xd0 + ww] = a[ys0:ys0 + hh, xs0:xs0 + ww]
    return out


def process_variant(piece_path, meta, variant, samples, data_dir, out_root, cache_root, log):
    vmeta = meta["variants"][variant]
    info, dt = fo_blender.render(piece_path, variant, cache_root, samples=samples, log=log, margin=meta.get("margin_px"))
    d, pre = info["_dir"], info["_prefix"]

    def npy(layer):
        p = os.path.join(d, "%s-%s.npy" % (pre, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    origin = tuple(info["origin_px"])
    hr = {}
    main = P.compose_main(npy("main"), npy("ao"), C)
    hr["main"] = main
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
    li = npy("light")
    if li is not None:
        # halo borné par des fenêtres circulaires (PIECE["halo"] : centre relatif à l'ancre, hauteur z,
        # rayons plein/nul en tuiles) ; sans fenêtre déclarée : C.LIGHT_RADIUS_TILES autour du pied
        ax, ay = vmeta.get("anchor_tiles", (0.0, 0.0))
        lay = P.additive_layer(li)
        wins = meta.get("halo") or [{"at": (0.0, 0.0, 0.0), "r": C.LIGHT_RADIUS_TILES}]
        best = None
        for wdef in wins:
            dx, dy, z = wdef["at"]
            u, v = C.blender_to_screen_px(0.0, 0.0, z)
            center = (origin[0] + (ax + dx) * 64.0 + u, origin[1] + (ay + dy) * 64.0 + v)
            wl = P.radial_window(lay, center, wdef["r"][0] * 64, wdef["r"][1] * 64)
            best = wl if best is None else np.concatenate([wl[..., :3], np.maximum(best[..., 3:], wl[..., 3:])], -1)
        hr["light"] = P.floor_alpha(P.fade_edges(best))

    raw = dict(hr)  # avant masque : sert à la version 32 px/tuile, masquée ensuite par le sprite LR vanilla
    mask = vmeta.get("mask")
    if mask:
        m_hr = place_alpha(main.shape[:2], origin, os.path.join(data_dir, "base", "graphics", "entity", mask["hr"]["file"]),
                           mask["hr"]["shift"], 64)
        for k in ("main", "glow"):
            if k in hr:
                hr[k] = P.mask_with(hr[k], m_hr)

    name = "%s-%s" % (meta["name"], variant)
    dest = os.path.join(out_root, *vmeta["dest"].split("/"))
    files, spec = {}, {}
    for layer in LAYERS:
        if layer not in hr:
            continue
        img = hr[layer]
        box = P.trim_box(img, origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop_hr = img[y0:y1, x0:x1]
        # version 32 px/tuile : réduction 2× de l'image NON masquée, puis masque par le sprite vanilla LR
        src = raw[layer][y0:y1, x0:x1]
        crop_lr = P.downsample2_additive(src) if layer in ("glow", "light") else P.downsample2(src)
        if mask and layer in ("main", "glow"):
            lr_origin = ((origin[0] - x0) / 2.0, (origin[1] - y0) / 2.0)
            m_lr = place_alpha(crop_lr.shape[:2], lr_origin,
                               os.path.join(data_dir, "base", "graphics", "entity", mask["lr"]["file"]), mask["lr"]["shift"], 32)
            crop_lr = P.mask_with(crop_lr, m_lr)
        fn_hr = "hr-%s-%s.png" % (name, layer)
        fn_lr = "%s-%s.png" % (name, layer)
        files[fn_hr] = P.write_png(crop_hr, os.path.join(dest, fn_hr))
        files[fn_lr] = P.write_png(crop_lr, os.path.join(dest, fn_lr))
        sd_hr = P.sprite_def(box, origin, 64)
        sd_lr = P.sprite_def(box, origin, 32)
        spec[layer] = {"hr": dict(sd_hr, filename=fn_hr), "lr": dict(sd_lr, filename=fn_lr)}
    return {"name": name, "dest": vmeta["dest"], "spec": spec, "files": files, "render": {
        "canvas": info["canvas"], "origin_px": info["origin_px"], "seconds": round(dt, 1),
        "samples": info["samples"], "seed": info["seed"], "blender": info["blender"],
        "blender_hash": info["blender_hash"]}}, hr, origin


def lua_value(v, ind=""):
    if isinstance(v, dict):
        items = []
        for k in sorted(v):
            key = k if k.isidentifier() else '["%s"]' % k
            items.append('%s  %s = %s' % (ind, key, lua_value(v[k], ind + "  ")))
        return "{\n" + ",\n".join(items) + "\n" + ind + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_value(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(float(v)) if isinstance(v, float) and not float(v).is_integer() else str(int(v))
    return '"%s"' % v


def write_spec_lua(path, meta, results, icon_file):
    root = "__%s__/graphics/" % MOD_NAME
    data = {"icon": {"filename": root + results[0]["dest"] + "/" + icon_file, "icon_size": 64, "icon_mipmaps": 4},
            "variants": {}}
    for r in results:
        v = {}
        for layer, sd in r["spec"].items():
            v[layer] = {
                "lr": {"filename": root + r["dest"] + "/" + sd["lr"]["filename"], "width": sd["lr"]["width"],
                       "height": sd["lr"]["height"], "shift": sd["lr"]["shift"]},
                "hr": {"filename": root + r["dest"] + "/" + sd["hr"]["filename"], "width": sd["hr"]["width"],
                       "height": sd["hr"]["height"], "shift": sd["hr"]["shift"]},
            }
        data["variants"][r["name"]] = v
    txt = ("-- FICHIER GÉNÉRÉ par tools/render/render.py (pièce « %s ») : ne pas modifier à la main.\n"
           "-- Tailles en pixels, shift en tuiles (multiples exacts de 1/64). hr = 64 px/tuile (scale 0,5).\n"
           "return " % meta["name"]) + lua_value(data) + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(txt)


def run(piece_path, variants, samples, data_dir, out_root, cache_root, manifest_path):
    meta = load_piece_meta(piece_path)
    variants = variants or sorted(meta["variants"])
    log = os.path.join(cache_root, "blender.log")
    os.makedirs(cache_root, exist_ok=True)
    t0 = time.time()
    results, hrs = [], {}
    for v in variants:
        r, hr, origin = process_variant(piece_path, meta, v, samples, data_dir, out_root, cache_root, log)
        results.append(r)
        hrs[v] = (hr, origin)
    # icône (64 px + mipmaps) à partir de la première variante
    first = variants[0]
    icon = P.icon_strip(hrs[first][0]["main"])
    icon_file = "%s-icon.png" % meta["name"]
    dest = os.path.join(out_root, *meta["variants"][first]["dest"].split("/"))
    icon_hash = P.write_png(icon, os.path.join(dest, icon_file))
    write_spec_lua(os.path.join(dest, "sprites.lua"), meta, results, icon_file)
    with open(os.path.join(dest, "sprites.lua"), "rb") as f:
        spec_hash = hashlib.sha256(f.read()).hexdigest()
    manifest = {
        "piece": meta["name"], "piece_source": os.path.relpath(piece_path, MOD_ROOT).replace("\\", "/"),
        "variants": results, "icon": {icon_file: icon_hash}, "sprites_lua": spec_hash,
        "calib": {k: getattr(C, k) for k in dir(C) if k.isupper()},
        "seconds_total": round(time.time() - t0, 1),
    }
    if manifest_path:
        os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
        with open(manifest_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(manifest, f, indent=1, sort_keys=True)
    return manifest


def all_hashes(m):
    h = {}
    for r in m["variants"]:
        h.update(r["files"])
    h.update(m["icon"])
    h["sprites.lua"] = m["sprites_lua"]
    return h


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("piece")
    ap.add_argument("--variants", default="")
    ap.add_argument("--samples", type=int, default=C.SAMPLES)
    ap.add_argument("--data", default=os.environ.get("FO_DATA", DEFAULT_DATA))
    ap.add_argument("--check", action="store_true", help="refaire le rendu ailleurs et comparer les octets")
    a = ap.parse_args()
    piece = os.path.abspath(a.piece)
    meta = load_piece_meta(piece)
    variants = [v for v in a.variants.split(",") if v]
    manifest_path = os.path.join(HERE, "manifests", "%s.json" % meta["name"])
    if a.check:
        out_root = os.path.join(HERE, "out", "check", "graphics")
        m2 = run(piece, variants, a.samples, a.data, out_root, os.path.join(HERE, "cache", "check"), None)
        with open(manifest_path, encoding="utf-8") as f:
            m1 = json.load(f)
        h1, h2 = all_hashes(m1), all_hashes(m2)
        same = sorted(k for k in h1 if h2.get(k) == h1[k])
        diff = sorted(k for k in h1 if h2.get(k) != h1[k])
        print("[FO-RENDER-CHECK] %d fichiers identiques, %d différents %s (%.1f s)" % (len(same), len(diff), diff, m2["seconds_total"]))
        sys.exit(0 if not diff else 1)
    m = run(piece, variants, a.samples, a.data, os.path.join(MOD_ROOT, "graphics"), os.path.join(HERE, "cache", meta["name"]),
            manifest_path)
    n = sum(len(r["files"]) for r in m["variants"]) + 1
    print("[FO-RENDER] %s : %d PNG + sprites.lua en %.1f s" % (meta["name"], n, m["seconds_total"]))
    for r in m["variants"]:
        for layer, sd in sorted(r["spec"].items()):
            print("  %-16s %-6s hr %3dx%-3d shift (%.6f, %.6f)" % (r["name"], layer, sd["hr"]["width"], sd["hr"]["height"],
                                                                 sd["hr"]["shift"][0], sd["hr"]["shift"][1]))


if __name__ == "__main__":
    main()
