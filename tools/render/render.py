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
import fo_checks  # noqa: E402
import fo_post as P  # noqa: E402

MOD_ROOT = os.path.dirname(os.path.dirname(HERE))
MOD_NAME = "factorio-overhaul"
DEFAULT_DATA = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data"
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


def light_mode(meta):
    """« v0b » : halo au sol seulement, valeurs linéaires, couche principale non découpée par le bâtiment
    porteur ; « v0 » : ancien calcul. Choisi par PIECE["light_mode"], sinon par LIGHT_HOLDOUT (surcharge de la
    pièce PIECE["calib"], sinon fo_calib : défaut False, comportement V0)."""
    if meta.get("light_mode") in ("v0", "v0b"):
        return meta["light_mode"]
    hold = (meta.get("calib") or {}).get("LIGHT_HOLDOUT", getattr(C, "LIGHT_HOLDOUT", False))
    return "v0b" if hold else "v0"


def mask_layers(vmeta):
    """Couches découpées par l'alpha du sprite vanilla porteur. V0b : la couche principale n'est plus
    découpée (le jeu dessine le bâtiment PAR-DESSUS : couches de la pièce insérées AVANT les siennes) ; la
    lueur l'est (elle alimente aussi la carte des lumières) ; le halo l'est toujours (flaque hors silhouette)."""
    return tuple(vmeta.get("mask_layers", ("glow",)))


def process_variant(piece_path, meta, variant, samples, data_dir, out_root, cache_root, log):
    vmeta = meta["variants"][variant]
    # surcharges d'étalonnage propres à la pièce (V0b, facultatif) : PIECE["calib"] = {"NOM": valeur}
    sets = ["%s=%r" % (k, v) for k, v in sorted((meta.get("calib") or {}).items())]
    info, dt = fo_blender.render(piece_path, variant, cache_root, samples=samples, log=log, margin=meta.get("margin_px"),
                                 sets=sets)
    d, pre = info["_dir"], info["_prefix"]

    def npy(layer):
        p = os.path.join(d, "%s-%s.npy" % (pre, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    origin = tuple(info["origin_px"])
    mode = light_mode(meta)
    mask = vmeta.get("mask")
    main_raw = npy("main")
    m_hr = None
    if mask:
        m_hr = place_alpha(main_raw.shape[:2], origin, os.path.join(data_dir, "base", "graphics", "entity", mask["hr"]["file"]),
                           mask["hr"]["shift"], 64)
    hr = {}
    ao = npy("ao")
    fringe_mask = None
    if m_hr is not None and ao is not None and mode == "v0b":
        # liseré de contact retiré près du bâtiment porteur (silhouette dilatée de la portée de l'AO) : un pied
        # caché ne laisse pas de salissure sans cause visible sur le flanc (rapport V0)
        fringe_mask = fo_checks.dilate(m_hr >= 0.5, C.AO_DISTANCE * C.PX_PER_UNIT_HR).astype(np.float64)
    main = P.compose_main(main_raw, ao, C, fringe_mask=fringe_mask)
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
        if mode == "v0b":
            # valeurs linéaires ; aucun halo sur la pièce elle-même (y compris ses parties cachées, visibles dans
            # la couche principale) : facteur min(alpha du rendu halo, 1 - alpha de la passe principale)
            free = np.minimum(li[..., 3], 1.0 - np.clip(main_raw[..., 3], 0, 1))
            lay = P.light_layer(np.concatenate([li[..., :3], free[..., None]], -1),
                                C.LIGHT_SCALE * float(meta.get("light_scale", 1.0)))
        else:
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
    if mode == "v0b":
        mlayers = mask_layers(vmeta) + ("light",)
    else:
        mlayers = ("main", "glow")
    if mask:
        for k in mlayers:
            if k in hr:
                hr[k] = P.mask_with(hr[k], m_hr)
        if "light" in hr and "light" in mlayers:
            hr["light"] = P.floor_alpha(hr["light"])

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
        if mask and layer in mlayers:
            lr_origin = ((origin[0] - x0) / 2.0, (origin[1] - y0) / 2.0)
            m_lr = place_alpha(crop_lr.shape[:2], lr_origin,
                               os.path.join(data_dir, "base", "graphics", "entity", mask["lr"]["file"]), mask["lr"]["shift"], 32)
            crop_lr = P.mask_with(crop_lr, m_lr)
            if layer == "light":
                crop_lr = P.floor_alpha(crop_lr)
        fn_hr = "hr-%s-%s.png" % (name, layer)
        fn_lr = "%s-%s.png" % (name, layer)
        files[fn_hr] = P.write_png(crop_hr, os.path.join(dest, fn_hr))
        files[fn_lr] = P.write_png(crop_lr, os.path.join(dest, fn_lr))
        sd_hr = P.sprite_def(box, origin, 64)
        sd_lr = P.sprite_def(box, origin, 32)
        spec[layer] = {"hr": dict(sd_hr, filename=fn_hr), "lr": dict(sd_lr, filename=fn_lr)}
    carrier = None
    if mask:
        carrier = np.asarray(Image.open(os.path.join(data_dir, "base", "graphics", "entity", mask["hr"]["file"]))
                             .convert("RGBA")).astype(np.float64) / 255.0
    checks, fails = run_checks(meta, vmeta, hr, main_raw, m_hr, origin, carrier)
    return {"name": name, "dest": vmeta["dest"], "spec": spec, "files": files, "checks": checks, "check_failures": fails,
            "render": {
                "canvas": info["canvas"], "origin_px": info["origin_px"], "seconds": round(dt, 1),
                "samples": info["samples"], "seed": info["seed"], "blender": info["blender"],
                "blender_hash": info["blender_hash"], "hidden": info.get("hidden", []),
                "occluders": info.get("occluders", []), "calib_overrides": sets}}, hr, origin


def _r(x, n=4):
    if isinstance(x, float):
        return round(x, n)
    if isinstance(x, dict):
        return {k: _r(v, n) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [_r(v, n) for v in x]
    return x


def piece_epochs(meta):
    """Époques déclarées par la pièce (PIECE["epoque"] : entier ou liste), pour les règles de la bible."""
    e = meta.get("epoque")
    if e is None:
        return []
    return [int(x) for x in (e if isinstance(e, (list, tuple)) else [e])]


def run_checks(meta, vmeta, hr, main_raw, m_hr, origin, carrier=None):
    """Contrôles V0b (fo_checks.py) sur les couches HR finales. Renvoie (mesures, échecs bloquants).
    carrier : sprite HR du bâtiment vanilla porteur (variante à masque), pour le rapport de luminance."""
    out, fails = {}, []
    a = hr["main"][..., 3]
    n, am, _ = fo_checks.enclosed_transparent(a)
    tol = int(meta.get("enclosed_tolerance_px", 0))
    out["main_enclosed_px"] = n
    out["main_enclosed_mean_alpha"] = am
    if n > tol:
        fails.append("couche principale : %d px transparents enfermés dans la silhouette (tolérance %d)" % (n, tol))
    tn, tf = fo_checks.thin_pixels(a)
    out["main_thin_px"], out["main_thin_frac"] = tn, tf
    glow = hr.get("glow")
    vis = hr["main"]
    if m_hr is not None:  # partie visible seulement (le bâtiment porteur couvre le reste)
        vis = vis.copy()
        vis[..., 3] = vis[..., 3] * (1 - m_hr)
    out["photometry"] = fo_checks.photometry(vis, glow)
    ph = out["photometry"]
    out["photometry_out_of_range"] = sorted(k for k, (lo, hi) in C.PHOTO_RANGES.items()
                                            if k in ph and not (lo <= ph[k] <= hi))
    if ph.get("n"):
        # règles de la bible (bloquantes si la pièce déclare son époque) et rapport au bâtiment porteur
        ep = piece_epochs(meta)
        if ep:
            out["bible_epochs"] = ep
            fails.extend(fo_checks.bible_rules(ph, ep, C.BIBLE_MEDIAN, C.BIBLE_TOL))
        if carrier is not None:
            cm = fo_checks.bible_median(carrier)
            ratio = ph["bible_p05_p50_p95"][1] / cm if cm > 0 else float("inf")
            out["carrier_median"], out["carrier_ratio"] = cm, ratio
            if ratio > C.CARRIER_RATIO_MAX:
                fails.append("luminance médiane pièce / bâtiment porteur %.2f > %.2f (%.0f contre %.0f /255)" % (
                    ratio, C.CARRIER_RATIO_MAX, ph["bible_p05_p50_p95"][1], cm))
    if glow is not None:
        # D2-1 : plus grand carré plein au-dessus de la médiane du corps + 80/255, sur la composition de jour
        day = np.clip(vis[..., :3] * vis[..., 3:4] + glow[..., :3] * glow[..., 3:4], 0, 1)
        thr = ph.get("p50", 0.25) + 80.0 / 255
        out["emissive_square_px"] = fo_checks.largest_full_square(fo_checks.lum(day) > thr)
    if "light" in hr:
        L = hr["light"]
        ax, ay = vmeta.get("anchor_tiles", (0.0, 0.0))
        foot = (origin[0] + ax * 64.0, origin[1] + ay * 64.0)
        out["light"] = fo_checks.light_extent(L, center=foot)
        fr, mx = fo_checks.light_on(L, np.clip(main_raw[..., 3], 0, 1))
        out["light_on_piece_frac"], out["light_on_piece_max"] = fr, mx
        blocked = main_raw[..., 3] >= 0.5
        if m_hr is not None:
            fb, mb = fo_checks.light_on(L, m_hr)
            out["light_on_building_frac"], out["light_on_building_max"] = fb, mb
            blocked = blocked | (m_hr >= 0.5)
            if fb > 0.03:
                fails.append("halo : %.1f %% de l'énergie sur le bâtiment porteur (≤ 3 %%)" % (100 * fb))
        out["light_pockets_px"] = fo_checks.light_pockets(L, blocked)
        if out["light_pockets_px"] > 0:
            fails.append("halo : poche sombre enfermée de %d px (ombre d'un objet absent)" % out["light_pockets_px"])
        if light_mode(meta) == "v0b" and fr > 0.03:
            fails.append("halo : %.1f %% de l'énergie sur la pièce (≤ 3 %%)" % (100 * fr))
        lo, hi = C.LIGHT_PEAK_RANGE
        out["light_peak_in_range"] = lo <= out["light"]["peak"] <= hi
        lo, hi = C.LIGHT_AREA_RANGE
        out["light_area_in_range"] = lo <= out["light"]["area_tiles2"] <= hi
    return _r(out), fails


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
    print_checks(m)
    if any(r.get("check_failures") for r in m["variants"]):
        sys.exit(3)


def print_checks(m):
    """Résumé lisible des contrôles V0b (détail complet dans le manifeste, clé « checks »)."""
    for r in m["variants"]:
        c = r.get("checks") or {}
        ph = c.get("photometry", {})
        print("[FO-CHECK] %s : trous enfermés %s px, fins %s px (%.1f %%), carré émissif %s px" % (
            r["name"], c.get("main_enclosed_px"), c.get("main_thin_px"), 100 * c.get("main_thin_frac", 0),
            c.get("emissive_square_px")))
        if ph.get("n"):
            print("[FO-CHECK] %s : corps L moy %.3f éc.-type %.3f p05 %.3f p50 %.3f p95 %.3f part>0,5 %.1f %% grad %.3f "
                  "lap/std %.2f sat %.3f pics %.2f %% ; hors plage vanilla (avertissement) : %s" % (
                      r["name"], ph["mean"], ph["std"], ph["p05"], ph["p50"], ph["p95"], 100 * ph["frac_gt_0_5"],
                      ph["grad"], ph["lap_over_std"], ph.get("sat", 0), 100 * ph.get("specks", 0),
                      ", ".join(c.get("photometry_out_of_range", [])) or "aucun"))
            b = ph["bible_p05_p50_p95"]
            print("[FO-CHECK] %s : bible p05/p50/p95 %.0f/%.0f/%.0f (époques %s)%s" % (
                r["name"], b[0], b[1], b[2], c.get("bible_epochs", "non déclarées"),
                (" ; porteur médiane %.0f, rapport %.2f" % (c["carrier_median"], c["carrier_ratio"]))
                if "carrier_ratio" in c else ""))
        if "light" in c:
            li = c["light"]
            print("[FO-CHECK] %s : halo pic %.3f, surface %.2f tuile², intégrale %.2f, portées N %.2f S %.2f E %.2f O %.2f ; "
                  "sur la pièce %.1f %%, sur le bâtiment %s, poches %d px" % (
                      r["name"], li["peak"], li["area_tiles2"], li["integral"], li.get("north", 0), li.get("south", 0),
                      li.get("east", 0), li.get("west", 0), 100 * c.get("light_on_piece_frac", 0),
                      ("%.1f %%" % (100 * c["light_on_building_frac"])) if "light_on_building_frac" in c else "-",
                      c.get("light_pockets_px", 0)))
        for f in r.get("check_failures", []):
            print("[FO-CHECK] ECHEC %s : %s" % (r["name"], f))


if __name__ == "__main__":
    main()
