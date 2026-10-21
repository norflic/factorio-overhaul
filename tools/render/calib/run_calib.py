"""Étalonnage par la mesure : rend les formes simples (pieces/calib_shapes.py) et les compare aux sprites
vanilla qui leur correspondent. Écrit un rapport JSON et des planches de comparaison.

    python tools/render/calib/run_calib.py "<racine>/data" [--set NOM=valeur ...] [--tag essai]

Sorties : tools/render/out/calib/<tag>/ (ignoré par git) : calib.json, planches *.png.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import fo_blender  # noqa: E402
import fo_calib as C  # noqa: E402
import fo_post  # noqa: E402
from fitlib import load, luminance, mid_boundary, fit_ellipse_axis, column_edge, fit_arc, save_png  # noqa: E402

RENDER = os.path.dirname(HERE)
PIECE = os.path.join(RENDER, "pieces", "calib_shapes.py")


def vanilla(data_dir, rel):
    return load(os.path.join(data_dir, "base", "graphics", "entity", rel))


def place(canvas, img, center, shift_px):
    """Pose img (H,W,4, alpha droit) sur canvas avec son centre en center + shift (px HR)."""
    h, w = img.shape[:2]
    x0 = int(round(center[0] + shift_px[0] - w / 2.0))
    y0 = int(round(center[1] + shift_px[1] - h / 2.0))
    out = canvas.copy()
    a = img[..., 3:4]
    sub = out[y0:y0 + h, x0:x0 + w]
    sub[..., :3] = img[..., :3] * a + sub[..., :3] * (1 - a)
    sub[..., 3:4] = a + sub[..., 3:4] * (1 - a)
    return out


def rendered(info, layer):
    return np.load(os.path.join(info["_dir"], "%s-%s.npy" % (info["_prefix"], layer)))


def in_frame(img, info, size=256):
    """Recadre un rendu dans un cadre size×size centré sur la position de l'entité."""
    ox, oy = info["origin_px"]
    H, W = img.shape[:2]
    out = np.zeros((size, size, 4), np.float32)
    x0, y0 = size // 2 - ox, size // 2 - oy
    xs0, ys0 = max(0, -x0), max(0, -y0)
    xd0, yd0 = max(0, x0), max(0, y0)
    w = min(W - xs0, size - xd0)
    h = min(H - ys0, size - yd0)
    out[yd0:yd0 + h, xd0:xd0 + w] = img[ys0:ys0 + h, xs0:xs0 + w]
    return out


def vanilla_frame(img, shift, size=256):
    return place(np.zeros((size, size, 4), np.float32), img, (size / 2, size / 2), (shift[0] * 64, shift[1] * 64))


def iou(a, b, lvl=0.5):
    A, B = a[..., 3] >= lvl, b[..., 3] >= lvl
    return float((A & B).sum() / max(1, (A | B).sum()))


def on_bg(img, bg=(0.35, 0.33, 0.30)):
    out = np.empty(img.shape[:2] + (3,), np.float32)
    a = img[..., 3:4]
    out[:] = np.array(bg) * (1 - a) + img[..., :3] * a
    return out


def sheet(path, images, scale=2, labels=None):
    """Planche horizontale d'images RGB (même hauteur), agrandies au plus proche voisin."""
    hs = max(i.shape[0] for i in images)
    tiles = []
    for i in images:
        pad = np.zeros((hs, i.shape[1], 3), np.float32) + 0.1
        pad[:i.shape[0]] = i
        tiles.append(pad)
        tiles.append(np.zeros((hs, 4, 3), np.float32) + 1.0)
    s = np.concatenate(tiles[:-1], axis=1)
    im = Image.fromarray(np.clip(s * 255 + 0.5, 0, 255).astype(np.uint8), "RGB")
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)


def shadow_on_ground(shadow, ground=(0.45, 0.42, 0.36), factor=0.5):
    """Ombre affichée comme le moteur : sol × (1 − 0,5 × alpha) (shadow-a8.frag)."""
    a = shadow[..., 3:4]
    return np.array(ground) * (1 - factor * a)


def face_ratio(img, top_rows, front_rows):
    L = luminance(img)
    a = img[..., 3] >= 0.99
    t = np.median(L[top_rows][a[top_rows]])
    f = np.median(L[front_rows][a[front_rows]])
    return float(t), float(f), float(f / t)


def fringe_profile(img, n=12):
    """Liseré de contact : alpha médian sous le dernier pixel opaque de chaque colonne, d = 1..n px."""
    a = img[..., 3]
    h, w = a.shape
    prof = []
    for x in range(w // 4, 3 * w // 4):
        idx = np.nonzero(a[:, x] >= 0.99)[0]
        if len(idx) == 0:
            continue
        y = idx.max()
        prof.append([a[y + d, x] if y + d < h else 0 for d in range(1, n + 1)])
    return [round(float(v), 3) for v in np.median(np.array(prof), 0)]


def vanilla_fringe(data_dir):
    """Médiane du liseré de six bâtiments vanilla (four en acier, four en pierre, machine
    d'assemblage 2, mitrailleuse, réservoir, labo)."""
    rows = []
    for rel, box in [("steel-furnace/hr-steel-furnace.png", None), ("stone-furnace/hr-stone-furnace.png", None),
                     ("assembling-machine-2/hr-assembling-machine-2.png", (0, 0, 214, 218)),
                     ("gun-turret/hr-gun-turret-base.png", None),
                     ("storage-tank/hr-storage-tank.png", (0, 0, 219, 215)), ("lab/hr-lab.png", (0, 0, 194, 174))]:
        im = vanilla(data_dir, rel)
        if box:
            im = im[box[1]:box[3], box[0]:box[2]]
        rows.append(fringe_profile(im))
    return [round(float(v), 3) for v in np.median(np.array(rows), 0)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data")
    ap.add_argument("--set", action="append", default=[])
    ap.add_argument("--tag", default="current")
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--only", default="chest,pipes,pole,stack,dome")
    a = ap.parse_args()
    out = os.path.join(RENDER, "out", "calib", a.tag)
    cache = os.path.join(RENDER, "cache", "calib", a.tag)
    os.makedirs(out, exist_ok=True)
    for kv in a.set:  # surcharges aussi côté post-traitement (AO_STRENGTH, AO_GAMMA...)
        k, v = kv.split("=", 1)
        old = getattr(C, k)
        setattr(C, k, tuple(eval(v)) if isinstance(old, tuple) else type(old)(eval(v)))
    C.recompute()
    rep = {"overrides": a.set}
    only = a.only.split(",")

    # --- coffre : rapport dessus/façade, silhouette, ombre ---------------------------------------
    if "chest" in only:
        info, dt = fo_blender.render(PIECE, "chest", cache, samples=a.samples, sets=a.set)
        main_raw = in_frame(rendered(info, "main"), info)
        ao_raw = in_frame(rendered(info, "ao"), info)
        main_r = fo_post.compose_main(main_raw, ao_raw, C).astype(np.float32)
        sh_r = in_frame(rendered(info, "shadow"), info)
        res = {"seconds": round(dt, 1)}
        # rangées des faces dans le cadre 256 : bord avant à +30,5 px, dessus 37 px, façade 31 px
        c = 128
        top_rows = slice(int(c + 30.5 - 31 - 37 + 6), int(c + 30.5 - 31 - 4))
        front_rows = slice(int(c + 30.5 - 31 + 5), int(c + 30.5 - 4))
        res["render_top_front"] = face_ratio(main_r, top_rows, front_rows)
        for name, rel, shift, srel, sshift in [
            ("wooden", "wooden-chest/hr-wooden-chest.png", (0.015625, -0.0625), "wooden-chest/hr-wooden-chest-shadow.png", (0.3125, 0.203125)),
            ("iron", "iron-chest/hr-iron-chest.png", (-0.015625, -0.015625), "iron-chest/hr-iron-chest-shadow.png", (0.328125, 0.1875)),
            ("steel", "steel-chest/hr-steel-chest.png", (-0.0078125, -0.015625), "steel-chest/hr-steel-chest-shadow.png", (0.3828125, 0.25)),
        ]:
            v = vanilla_frame(vanilla(a.data, rel), shift)
            vs = vanilla_frame(vanilla(a.data, srel), sshift)
            res[name] = {
                "top_front": face_ratio(v, top_rows, front_rows),
                "iou_silhouette": iou(v, main_raw),
                "iou_shadow": iou(vs, sh_r),
                "shadow_right_px": float(np.nonzero((vs[..., 3] > 0.5).any(0))[0].max() + 1 - c),
            }
            if name == "wooden":
                vw, vsw = v, vs
        res["render_shadow_right_px"] = float(np.nonzero((sh_r[..., 3] > 0.5).any(0))[0].max() + 1 - c)
        res["fringe_below_edge"] = fringe_profile(main_r[64:192, 96:160])
        res["fringe_below_edge_vanilla"] = vanilla_fringe(a.data)
        rep["chest"] = res
        crop = (slice(64, 192), slice(80, 224))
        g1 = shadow_on_ground(vsw)
        g2 = shadow_on_ground(sh_r)
        comp_v = on_bg(vw, (0, 0, 0)) * vw[..., 3:4] + g1 * (1 - vw[..., 3:4])
        comp_r = on_bg(main_r, (0, 0, 0)) * main_r[..., 3:4] + g2 * (1 - main_r[..., 3:4])
        sheet(os.path.join(out, "chest_vanilla_vs_rendu.png"), [comp_v[crop], comp_r[crop]], 3)

    # --- tuyaux : profils de luminance -----------------------------------------------------------
    if "pipes" in only:
        info, dt = fo_blender.render(PIECE, "pipes", cache, samples=a.samples, sets=a.set)
        m = rendered(info, "main")
        ox, oy = info["origin_px"]
        L = luminance(m)
        r = 19.5
        # nord-sud à x = -1,5 tuile
        cx = ox - 96
        prof_ns = [float(np.median(L[oy - 20:oy + 20, cx + d])) for d in range(-19, 20)]
        # est-ouest à x = +1,5 tuile, axe à l'écran v = -(r·sin θ) px
        cxe = ox + 96
        col = m[:, cxe, 3] > 0.5
        ys = np.nonzero(col)[0]
        prof_ew = [float(np.median(L[y, cxe - 20:cxe + 20])) for y in range(ys.min(), ys.max() + 1)]
        v_ns = vanilla(a.data, "pipe/hr-pipe-straight-vertical.png")
        Lv = luminance(v_ns)
        vprof_ns = [float(np.median(Lv[50:90, 64 + d][v_ns[50:90, 64 + d, 3] > 0.99])) for d in range(-19, 20)]
        v_ew = vanilla(a.data, "pipe/hr-pipe-straight-horizontal.png")
        Lh = luminance(v_ew)
        vprof_ew = [float(np.median(Lh[y, 30:100][v_ew[y, 30:100, 3] > 0.99])) for y in range(44, 82)]

        def peak(p, n):
            p = np.array(p)
            i = int(np.argmax(np.convolve(p, np.ones(3) / 3, "same")))
            return (i - (len(p) - 1) / 2.0) / ((len(p) - 1) / 2.0)

        def corr(p, q):
            p, q = np.array(p), np.array(q)
            n = min(len(p), len(q))
            p = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(p)), p)
            q = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(q)), q)
            return float(np.corrcoef(p, q)[0, 1])

        rep["pipes"] = {
            "seconds": round(dt, 1),
            "ns_peak_rel": peak(prof_ns, 39), "ns_peak_rel_vanilla": peak(vprof_ns, 39),
            "ew_peak_rel": peak(prof_ew, len(prof_ew)), "ew_peak_rel_vanilla": peak(vprof_ew, len(vprof_ew)),
            "ns_corr": corr(prof_ns, vprof_ns), "ew_corr": corr(prof_ew, vprof_ew),
            "ns_mean": float(np.mean(prof_ns)), "ns_mean_vanilla": float(np.mean(vprof_ns)),
            "ew_thickness_px": int(ys.max() - ys.min() + 1),
            "ns_width_px": int((m[oy, :, 3] > 0.5)[: ox].sum()),
            "profiles": {"ns": prof_ns, "ns_vanilla": vprof_ns, "ew": prof_ew, "ew_vanilla": vprof_ew},
        }
        vimg = np.concatenate([on_bg(v_ns), on_bg(v_ew)], 1)
        pad = np.pad(m, ((128, 128), (256, 256), (0, 0)))
        rimg = on_bg(pad)[oy + 128 - 64:oy + 128 + 64, ox + 256 - 160:ox + 256 + 160]
        sheet(os.path.join(out, "tuyaux_vanilla_vs_rendu.png"), [vimg, rimg], 2)

    # --- poteau : ombre ---------------------------------------------------------------------------
    if "pole" in only:
        info, dt = fo_blender.render(PIECE, "pole", cache, samples=32, sets=a.set, layers=["main", "shadow"])
        m = rendered(info, "main")
        s = rendered(info, "shadow")
        ox, oy = info["origin_px"]
        ys, xs = np.nonzero(m[..., 3] > 0.5)
        top = ys.min() - oy
        sy, sx = np.nonzero(s[..., 3] > 0.5)
        tip = sx.max() + 1 - ox
        rep["pole"] = {"top_px": float(top), "shadow_tip_px": float(tip),
                       "tan_elev_equiv": float(-top / (tip * 0.7071067811865476))}

    # --- cheminée et disque : ellipses -------------------------------------------------------------
    if "stack" in only:
        info, dt = fo_blender.render(PIECE, "stack", cache, samples=32, sets=a.set, layers=["main"])
        m = rendered(info, "main")
        ox, oy = info["origin_px"]
        al = m[..., 3]
        # sommet de la cheminée : arc supérieur de la silhouette (x autour de -0,6 tuile)
        cx = ox - int(0.6 * 64)
        pts = []
        for x in range(cx - 15, cx + 16):
            e = column_edge(al, x, "top", 0.5)
            if e is not None:
                pts.append((x + 0.5, e))
        xc, yc, aa, bb, rms = fit_arc(np.array(pts), "top")
        # disque face caméra : ellipse complète de la silhouette (x autour de +0,6 tuile)
        sub = al[:, ox + 6:]
        e2 = fit_ellipse_axis(mid_boundary(sub >= 0.5))
        rep["stack"] = {"top_arc_b_over_a": float(bb / aa), "disc_b_over_a": float(e2[3] / e2[2]),
                        "expected_cos": 0.7071, "expected_sin": 0.7071}

    # --- demi-sphère : contour --------------------------------------------------------------------
    if "dome" in only:
        info, dt = fo_blender.render(PIECE, "dome", cache, samples=32, sets=a.set, layers=["main"])
        m = rendered(info, "main")
        pts = mid_boundary(m[..., 3] >= 0.5)
        ox, oy = info["origin_px"]
        up = pts[pts[:, 1] < oy - 2]
        A = np.c_[2 * up[:, 0], 2 * up[:, 1], np.ones(len(up))]
        sol = np.linalg.lstsq(A, up[:, 0] ** 2 + up[:, 1] ** 2, rcond=None)[0]
        R = float(np.sqrt(sol[2] + sol[0] ** 2 + sol[1] ** 2))
        rep["dome"] = {"radius_px": R, "expected": 64.0}

    with open(os.path.join(out, "calib.json"), "w", encoding="utf-8") as f:
        json.dump(rep, f, indent=1)
    slim = {k: ({kk: vv for kk, vv in v.items() if kk != "profiles"} if isinstance(v, dict) else v) for k, v in rep.items()}
    print(json.dumps(slim, indent=1))


if __name__ == "__main__":
    main()
