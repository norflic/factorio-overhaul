# -*- coding: utf-8 -*-
"""
Bibliothèque de mesure de la charte DA_FACTORIO (lot V3-S, 22/10/2026).

Tout se mesure sur le CORPS composé à 64 px par tuile (résolution hr, scale 0,5), origine au centre de
l'entité, sans les couches d'ombre (draw_as_shadow) ni de lumière (draw_as_light, blend additif).
Les couches draw_as_glow comptent à la fois dans le corps (elles sont dessinées comme un sprite) et dans
la zone lumineuse. Seules dépendances : numpy, Pillow (pas de scipy sur ce PC).
"""
import math
import os
from collections import deque

import numpy as np
from PIL import Image

PX_PER_TILE = 64.0
TEAM_TINT = (0.869, 0.5, 0.130)  # couleur de joueur par défaut (orange), pour les masques apply_runtime_tint


# ------------------------------------------------------------------------------------------------
# Lecture des dumps du banc data (tests/datastage/harness.lua --dump-proto)
# ------------------------------------------------------------------------------------------------
def parse_dump(text):
    lines = [l.rstrip() for l in text.splitlines()]
    # on saute ce qui précède la première accolade
    i = 0
    while i < len(lines) and lines[i].strip() != "{":
        i += 1
    stack = [{}]
    keys = [None]
    for raw in lines[i + 1:]:
        s = raw.strip()
        if not s:
            continue
        if s in ("}", "},"):
            if len(stack) == 1:
                break
            d = stack.pop()
            k = keys.pop()
            stack[-1][k] = d
            continue
        if " = " not in s:
            continue
        k, v = s.split(" = ", 1)
        k = k.strip()
        if v == "{":
            stack.append({})
            keys.append(k)
            continue
        v = v.rstrip(",")
        if v.startswith('"') and v.endswith('"'):
            val = v[1:-1]
        elif v in ("true", "false"):
            val = (v == "true")
        else:
            try:
                val = float(v) if any(c in v for c in ".eE") else int(v)
            except ValueError:
                val = v
        stack[-1][k] = val
    return listify(stack[0])


def listify(x):
    if isinstance(x, dict):
        x = {k: listify(v) for k, v in x.items()}
        if x and all(isinstance(k, str) and k.isdigit() for k in x):
            return [x[k] for k in sorted(x, key=int)]
        return x
    return x


def vec(v, default=(0.0, 0.0)):
    if v is None:
        return default
    if isinstance(v, list):
        return (float(v[0]), float(v[1]))
    if isinstance(v, dict):
        return (float(v.get("x", v.get("1", 0))), float(v.get("y", v.get("2", 0))))
    return default


# ------------------------------------------------------------------------------------------------
# Feuilles de sprite vanilla -> couches positionnées
# ------------------------------------------------------------------------------------------------
def leaves(node):
    if node is None or not isinstance(node, dict):
        return []
    if "layers" in node:
        out = []
        for l in node["layers"]:
            out += leaves(l)
        return out
    if "sheets" in node:
        out = []
        for l in node["sheets"]:
            out += leaves(l)
        return out
    if "hr_version" in node:
        return leaves(node["hr_version"])
    if "north" in node:
        return leaves(node["north"])
    if "sheet" in node and isinstance(node["sheet"], dict):
        return leaves(node["sheet"])
    if "filename" in node or "stripes" in node or "filenames" in node:
        return [node]
    return []


def frame_source(leaf, idx):
    """(fichier __base__, x, y) de l'image idx (direction ou image d'animation)."""
    W, H = int(leaf["width"]), int(leaf["height"])
    if "stripes" in leaf:
        rest = idx
        for st in leaf["stripes"]:
            w, h = int(st.get("width_in_frames", 1)), int(st.get("height_in_frames", 1))
            if rest < w * h:
                return st["filename"], (rest % w) * W + int(st.get("x", 0)), (rest // w) * H + int(st.get("y", 0))
            rest -= w * h
        st = leaf["stripes"][0]
        return st["filename"], 0, 0
    if "filenames" in leaf:
        lpf = int(leaf.get("lines_per_file", 1))
        ll = int(leaf.get("line_length", 1))
        per = lpf * ll
        f = leaf["filenames"][min(idx // per, len(leaf["filenames"]) - 1)]
        loc = idx % per
        return f, (loc % ll) * W, (loc // ll) * H
    ll = int(leaf.get("line_length", 0)) or 10 ** 9
    x0, y0 = int(leaf.get("x", 0)), int(leaf.get("y", 0))
    return leaf["filename"], x0 + (idx % ll) * W, y0 + (idx // ll) * H


def classify(leaf):
    fn = (leaf.get("filename") or "")
    if "stripes" in leaf:
        fn = leaf["stripes"][0]["filename"]
    if "filenames" in leaf:
        fn = leaf["filenames"][0]
    if leaf.get("draw_as_shadow"):
        return "shadow"
    bm = str(leaf.get("blend_mode", "normal"))
    if leaf.get("draw_as_light") or bm.startswith("additive"):
        return "light"
    if leaf.get("draw_as_glow"):
        return "glow"
    if leaf.get("apply_runtime_tint") or "mask" in (leaf.get("flags") or []):
        return "mask"
    return "main"


_img_cache = {}


def load_rgba(path):
    if path not in _img_cache:
        _img_cache[path] = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0
    return _img_cache[path]


def vanilla_layers(nodes, data_dir, idx=0, extra_kind=None):
    """nodes : liste de (noeud, idx ou None, kind forcé ou None). Retourne des couches prêtes à composer."""
    out = []
    for node, nidx, force in nodes:
        for leaf in leaves(node):
            li = idx if nidx is None else nidx
            if li == "E":
                li = int(leaf.get("direction_count", 4)) // 4
            fn, x, y = frame_source(leaf, li)
            path = os.path.join(data_dir, fn.replace("__base__/", "base/").replace("__core__/", "core/"))
            img = load_rgba(path)
            W, H = int(leaf["width"]), int(leaf["height"])
            if y + H > img.shape[0] or x + W > img.shape[1]:
                x, y = 0, 0
            crop = img[y:y + H, x:x + W].copy()
            scale = float(leaf.get("scale", 1.0))
            if abs(scale - 0.5) > 1e-6:
                # mise à 64 px/tuile
                f = scale * 2.0
                im = Image.fromarray((crop * 255).astype(np.uint8), "RGBA")
                im = im.resize((max(1, int(round(W * f))), max(1, int(round(H * f)))), Image.LANCZOS)
                crop = np.asarray(im, dtype=np.float32) / 255.0
            if "tint" in leaf:
                t = leaf["tint"]
                tv = (t.get("r", 1), t.get("g", 1), t.get("b", 1)) if isinstance(t, dict) else tuple(t[:3])
                if max(tv) > 1:
                    tv = tuple(c / 255.0 for c in tv)
                crop[..., :3] *= np.array(tv, dtype=np.float32)
            kind = classify(leaf)
            if force and kind not in ("shadow", "light"):
                kind = force  # le forçage ne touche que les couches dessinées comme sprite
            out.append({"img": crop, "shift": vec(leaf.get("shift")), "kind": kind,
                        "file": os.path.basename(fn)})
    return out


# ------------------------------------------------------------------------------------------------
# Composition
# ------------------------------------------------------------------------------------------------
def compose(layers, pad=8):
    """layers : dict img (H,W,4 float), shift (tuiles, centre de l'image), kind.
    Retourne body (RGBA prémultiplié -> droit), emissive (float), origin_px (x, y), bboxes."""
    boxes = []
    for l in layers:
        h, w = l["img"].shape[:2]
        cx = l["shift"][0] * PX_PER_TILE
        cy = l["shift"][1] * PX_PER_TILE
        x0 = cx - w / 2.0
        y0 = cy - h / 2.0
        boxes.append((x0, y0, x0 + w, y0 + h))
    xs0 = min(b[0] for b in boxes) - pad
    ys0 = min(b[1] for b in boxes) - pad
    xs1 = max(b[2] for b in boxes) + pad
    ys1 = max(b[3] for b in boxes) + pad
    W = int(math.ceil(xs1 - xs0))
    H = int(math.ceil(ys1 - ys0))
    ox, oy = -xs0, -ys0
    body = np.zeros((H, W, 4), np.float32)  # prémultiplié
    emis = np.zeros((H, W), np.float32)   # éclat de jour (draw_as_glow) : visible de jour
    halo = np.zeros((H, W), np.float32)   # lumière (draw_as_light / additif) : visible la nuit seulement
    team = np.zeros((H, W), np.float32)
    for l, b in zip(layers, boxes):
        img = l["img"]
        h, w = img.shape[:2]
        x0 = int(round(b[0] + ox))
        y0 = int(round(b[1] + oy))
        x0 = max(0, min(W - w, x0))
        y0 = max(0, min(H - h, y0))
        sl = (slice(y0, y0 + h), slice(x0, x0 + w))
        a = img[..., 3:4]
        rgb = img[..., :3]
        if l["kind"] == "shadow":
            continue
        if l["kind"] in ("light",):
            v = rgb.max(axis=2) * img[..., 3]
            halo[sl] = np.maximum(halo[sl], v)
            continue
        if l["kind"] == "mask":
            lum = rgb.mean(axis=2, keepdims=True)
            rgb = lum * np.array(TEAM_TINT, np.float32)
            team[sl] = np.maximum(team[sl], img[..., 3])
        if l["kind"] == "glow":
            v = rgb.max(axis=2) * img[..., 3]
            emis[sl] = np.maximum(emis[sl], v)
        pre = np.concatenate([rgb * a, a], axis=2)
        body[sl] = pre + body[sl] * (1.0 - a)
    a = body[..., 3:4]
    rgb = np.where(a > 1e-4, body[..., :3] / np.maximum(a, 1e-4), 0.0)
    straight = np.concatenate([np.clip(rgb, 0, 1), a], axis=2)
    return {"body": straight, "emis": emis, "halo": halo, "team": team, "origin": (ox, oy)}


# ------------------------------------------------------------------------------------------------
# Filtres (numpy pur)
# ------------------------------------------------------------------------------------------------
def gauss_kernel(sigma):
    r = max(1, int(math.ceil(3 * sigma)))
    x = np.arange(-r, r + 1, dtype=np.float32)
    k = np.exp(-x * x / (2 * sigma * sigma))
    return k / k.sum(), r


def conv1d(img, k, r, axis):
    pad = [(0, 0)] * img.ndim
    pad[axis] = (r, r)
    p = np.pad(img, pad, mode="edge")
    out = np.zeros_like(img)
    n = img.shape[axis]
    for i, w in enumerate(k):
        if axis == 0:
            out += w * p[i:i + n]
        else:
            out += w * p[:, i:i + n]
    return out


def gblur(img, sigma):
    k, r = gauss_kernel(sigma)
    return conv1d(conv1d(img, k, r, 0), k, r, 1)


def masked_blur(img, mask, sigma):
    num = gblur(img * mask, sigma)
    den = gblur(mask.astype(np.float32), sigma)
    return np.where(den > 1e-3, num / np.maximum(den, 1e-3), img)


def box_mean(img, k):
    r = k // 2
    w = np.ones(k, np.float32) / k
    return conv1d(conv1d(img, w, r, 0), w, r, 1)


def erode(mask, k):
    if k <= 1:
        return mask.copy()
    r = k // 2
    m = np.pad(mask, r, mode="constant", constant_values=False)
    H, W = mask.shape
    out = np.ones((H + 2 * r, W), bool)
    for i in range(k):
        out &= m[:, i:i + W]
    out2 = np.ones((H, W), bool)
    for i in range(k):
        out2 &= out[i:i + H]
    return out2


def dilate(mask, k):
    return ~erode(~mask, k)


def sobel_mag(L):
    p = np.pad(L, 1, mode="edge")
    gx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[1:-1, :-2] + p[2:, :-2])
    gy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[:-2, 1:-1] + p[:-2, 2:])
    return np.sqrt(gx * gx + gy * gy) / 8.0  # en unités de luminance par pixel


def laplacian(L):
    p = np.pad(L, 1, mode="edge")
    return p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:] - 4 * p[1:-1, 1:-1]


def components(mask, conn8=True):
    """Étiquetage par segments (union-find). Retourne la liste des tailles et la carte d'étiquettes."""
    H, W = mask.shape
    parent = []

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    runs_prev = []
    labels_runs = []
    for y in range(H):
        row = mask[y]
        if not row.any():
            runs_prev = []
            continue
        d = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
        starts = np.flatnonzero(d == 1)
        ends = np.flatnonzero(d == -1)
        runs = []
        j = 0
        for s, e in zip(starts, ends):
            lab = len(parent)
            parent.append(lab)
            lo, hi = (s - 1, e + 1) if conn8 else (s, e)
            while j < len(runs_prev) and runs_prev[j][1] <= lo:
                j += 1
            k = j
            while k < len(runs_prev) and runs_prev[k][0] < hi:
                ra, rb = find(lab), find(runs_prev[k][2])
                if ra != rb:
                    parent[max(ra, rb)] = min(ra, rb)
                k += 1
            runs.append((s, e, lab))
            labels_runs.append((y, s, e, lab))
        runs_prev = runs
    sizes = {}
    lab_map = np.full((H, W), -1, np.int32)
    for y, s, e, lab in labels_runs:
        r = find(lab)
        sizes[r] = sizes.get(r, 0) + (e - s)
        lab_map[y, s:e] = r
    return sizes, lab_map


# ------------------------------------------------------------------------------------------------
# Mesures
# ------------------------------------------------------------------------------------------------
def hsv(rgb):
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    c = mx - mn
    s = np.where(mx > 1e-4, c / np.maximum(mx, 1e-4), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    cc = np.maximum(c, 1e-6)
    h = np.where(mx == r, ((g - b) / cc) % 6, h)
    h = np.where(mx == g, (b - r) / cc + 2, h)
    h = np.where(mx == b, (r - g) / cc + 4, h)
    h = (h * 60.0) % 360.0
    return h, s, mx, c


def measure(comp, side, name="", emis_thr=0.25):
    body = comp["body"]
    ox, oy = comp["origin"]
    a = body[..., 3]
    M = a >= 0.5
    if M.sum() < 50:
        return None
    rgb = body[..., :3]
    L = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) * 255.0
    Mi = erode(M, 5)  # intérieur (2 px de marge)
    Mf = M.astype(np.float32)
    n_tiles = M.sum() / PX_PER_TILE ** 2
    sw, sh = (side, side) if isinstance(side, (int, float)) else side
    res = {"nom": name, "cote_emprise": "%gx%g" % (sw, sh)}

    # ---------------- masse ----------------
    ys, xs = np.nonzero(M)
    top = (ys.min() - oy) / PX_PER_TILE
    bot = (ys.max() + 1 - oy) / PX_PER_TILE
    left = (xs.min() - ox) / PX_PER_TILE
    right = (xs.max() + 1 - ox) / PX_PER_TILE
    half = sh / 2.0
    fx0, fx1 = int(round(ox - sw / 2.0 * 64)), int(round(ox + sw / 2.0 * 64))
    fy0, fy1 = int(round(oy - sh / 2.0 * 64)), int(round(oy + sh / 2.0 * 64))
    fp = np.zeros_like(M)
    fp[max(0, fy0):max(0, fy1), max(0, fx0):max(0, fx1)] = True
    res["remplissage_emprise"] = float((M & fp).sum() / max(1, (fy1 - fy0) * (fx1 - fx0)))
    res["masse_tuiles2"] = float(n_tiles)
    res["masse_par_tuile_emprise"] = float(n_tiles / (sw * sh))
    res["O_depassement_haut"] = float(-top - half)
    res["hauteur_totale_tuiles"] = float(bot - top)
    res["largeur_tuiles"] = float(right - left)
    res["remplissage_boite"] = float(M.sum() / ((ys.max() - ys.min() + 1) * (xs.max() - xs.min() + 1)))
    k = int(round(0.25 * PX_PER_TILE)) | 1  # ouverture carrée 17 px = 0,27 tuile
    op = dilate(erode(M, k), k) & M
    res["part_massive"] = float(op.sum() / M.sum())
    k2 = int(round(0.5 * PX_PER_TILE)) | 1  # 33 px = 0,52 tuile
    op2 = dilate(erode(M, k2), k2) & M
    res["part_tres_massive"] = float(op2.sum() / M.sum())

    # ---------------- détail ----------------
    lap = np.abs(laplacian(L))
    res["laplacien_moyen"] = float(lap[Mi].mean())
    sm = sobel_mag(gblur(L, 0.7))
    edges = (sm > 12.0) & Mi
    res["part_contours"] = float(edges.sum() / max(1, Mi.sum()))
    res["contours_par_tuile"] = float(edges.sum() / max(1e-6, Mi.sum() / PX_PER_TILE ** 2))
    Lb = masked_blur(L, Mf, 1.0)
    Lb3 = masked_blur(L, Mf, 3.0)
    dog = Lb - Lb3
    pieces = 0
    for sign in (1, -1):
        blob = ((sign * dog) > 10.0) & Mi
        sizes, _ = components(blob, conn8=True)
        pieces += sum(1 for s in sizes.values() if 4 <= s <= 256)
    res["petites_pieces"] = int(pieces)
    res["petites_pieces_par_tuile2"] = float(pieces / max(1e-6, n_tiles))
    m7 = box_mean(L * Mf, 7)
    m7d = box_mean(Mf, 7)
    mu = np.where(m7d > 1e-3, m7 / np.maximum(m7d, 1e-3), 0)
    q7 = box_mean(L * L * Mf, 7)
    var = np.where(m7d > 1e-3, q7 / np.maximum(m7d, 1e-3) - mu * mu, 0)
    res["contraste_local_7px"] = float(np.sqrt(np.maximum(var, 0))[Mi].mean())
    # même chose au zoom 1 (32 px/tuile)
    H2, W2 = (L.shape[0] // 2) * 2, (L.shape[1] // 2) * 2
    L2 = L[:H2, :W2].reshape(H2 // 2, 2, W2 // 2, 2).mean(axis=(1, 3))
    M2 = Mi[:H2, :W2].reshape(H2 // 2, 2, W2 // 2, 2).all(axis=(1, 3))
    M2 = erode(M2, 3)
    res["laplacien_zoom1"] = float(np.abs(laplacian(L2))[M2].mean()) if M2.any() else 0.0

    # ---------------- palette ----------------
    h, s, v, c = hsv(rgb)
    Lm = L[M]
    res["lum_p5"], res["lum_p50"], res["lum_p95"] = [float(x) for x in np.percentile(Lm, [5, 50, 95])]
    res["saturation_moyenne"] = float(s[M].mean())
    res["chroma_moyenne"] = float((c[M] * 255).mean())
    E = comp["emis"]
    lum_zone = dilate(E > emis_thr, 3)
    res["halo_nuit_tuiles2"] = float((comp["halo"] > emis_thr).sum() / PX_PER_TILE ** 2)
    sat = (s >= 0.5) & (v >= 0.5) & M
    res["part_saturee"] = float(sat.sum() / M.sum())
    selflit = (v >= 0.85) & (s >= 0.35) & M
    lumin = lum_zone | dilate(selflit, 3)
    res["zone_lumineuse_part"] = float((lumin & M).sum() / M.sum())
    sat_body = sat & ~lumin
    res["part_saturee_hors_lumineux"] = float(sat_body.sum() / M.sum())
    res["part_saturee_dans_lumineux"] = float((sat & lumin).sum() / M.sum())
    res["part_des_satures_qui_sont_lumineux"] = float((sat & lumin).sum() / max(1, sat.sum()))
    warm = ((h <= 70) | (h >= 330))
    cold_sat_body = sat_body & ~warm
    res["part_saturee_froide_hors_lumineux"] = float(cold_sat_body.sum() / M.sum())
    sizes, _ = components(sat_body, conn8=True)
    big = max(sizes.values()) if sizes else 0
    res["plus_grande_plage_saturee_tuiles2"] = float(big / PX_PER_TILE ** 2)
    res["plus_grande_plage_saturee_part"] = float(big / M.sum())
    sizes_all, _ = components(sat, conn8=True)
    big_all = max(sizes_all.values()) if sizes_all else 0
    res["plus_grande_plage_saturee_toutes_tuiles2"] = float(big_all / PX_PER_TILE ** 2)
    res["plus_grande_plage_saturee_toutes_part"] = float(big_all / M.sum())
    res["part_saturee_froide_toutes"] = float((sat & ~warm).sum() / M.sum())
    res["zone_lumineuse_tuiles2"] = float((lumin & M).sum() / PX_PER_TILE ** 2)
    nlum, _ = components(lumin & M, conn8=True)
    res["plus_grand_foyer_lumineux_tuiles2"] = float(max(nlum.values()) / PX_PER_TILE ** 2) if nlum else 0.0
    res["foyers_lumineux"] = int(sum(1 for v in nlum.values() if v >= 16))
    paint = (s >= 0.35) & (v >= 0.3) & M & ~lumin
    res["part_peinte_hors_lumineux"] = float(paint.sum() / M.sum())
    res["part_peinte_froide_hors_lumineux"] = float((paint & ~warm).sum() / M.sum())
    # teinte du corps hors lumineux (pixels de chroma >= 0,08)
    tint_px = M & ~lumin & (c >= 0.08)
    res["part_teinte_chaude_corps"] = float((tint_px & warm).sum() / max(1, tint_px.sum()))
    res["zone_equipe_part"] = float(((comp["team"] > 0.5) & M).sum() / M.sum())
    # pixels très clairs (blanc) du corps
    res["part_quasi_blanc"] = float(((L >= 220) & M & ~lumin).sum() / M.sum())

    # ---------------- patine ----------------
    flat = (sm < 6.0) & Mi
    res["part_surfaces_planes"] = float(flat.sum() / max(1, Mi.sum()))
    grain = np.abs(L - Lb)
    res["grain_surfaces"] = float(grain[flat].mean()) if flat.any() else 0.0
    band = masked_blur(L, Mf, 2.0) - masked_blur(L, Mf, 8.0)
    res["variance_basse_freq"] = float(band[flat].std()) if flat.any() else 0.0
    res["part_creux_sombres"] = float(((L < Lb3 - 20) & Mi).sum() / max(1, Mi.sum()))
    res["part_aretes_claires"] = float(((L > Lb3 + 20) & Mi).sum() / max(1, Mi.sum()))
    res["part_tres_sombre_lt25"] = float(((L < 25) & M).sum() / M.sum())
    return res


def from_layer_files(specs, base_dir):
    """specs : liste de (fichier, shift (tuiles), kind). Fichiers à 64 px/tuile."""
    out = []
    for fn, shift, kind in specs:
        p = os.path.join(base_dir, fn)
        if not os.path.exists(p):
            continue
        out.append({"img": load_rgba(p).copy(), "shift": shift, "kind": kind, "file": fn})
    return out


def from_canvas_files(specs, base_dir):
    """Couches en canevas complets (laser) : (fichier, origin_px, kind)."""
    out = []
    for fn, origin, kind in specs:
        p = os.path.join(base_dir, fn)
        if not os.path.exists(p):
            continue
        img = load_rgba(p).copy()
        h, w = img.shape[:2]
        cx = (w / 2.0 - origin[0]) / PX_PER_TILE
        cy = (h / 2.0 - origin[1]) / PX_PER_TILE
        out.append({"img": img, "shift": (cx, cy), "kind": kind, "file": fn})
    return out
