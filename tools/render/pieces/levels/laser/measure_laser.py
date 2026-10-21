"""Tourelle laser, lot V3 phase 1 : mesures D1 / D2 / F46 sur les rendus d'aperçu (Python système).

    python tools/render/pieces/levels/laser/measure_laser.py   [--json chemin]

Masque (bible §1.4, D1-3 amendé Q13) : pixels d'alpha ≥ 128 des couches PRINCIPALES (socle + tête), sans ombre,
lueur ni halo, 64 px par tuile, même origine (position de l'entité) ; ces rendus n'ont aucune couche plate au sol
(ni integration_patch, ni dalle). Niveau 1 = sprites vanilla (turrets.lua:883-1041), tête « prepared » image
0/16/32/48 pour N/E/S/O ; niveau 2 = vanilla + pièce ; niveau 2e = socle 2e + tête 2e-1.

Indicateurs (bible §1.4, OBJECTIFS D1) :
- O : dépassement du haut du masque au-dessus du bord haut de l'emprise (y = -1) ; L : largeur du masque ;
- pair : aire ajoutée par la pièce hors du masque impair (≥ 0,10 t² visée, minimum sur les poses) et IoU(2e, 2e-1) ;
- impair : IoU(2e-1, 2e-2) ≤ 0,85 (D1-1) ; IoU entre époques consécutives (impairs) ≤ 0,85 (D1-2) ;
- D1-3 : IoU(niveau 1, niveau 30) < 0,50 (cible ≤ 0,45), maximum sur les 4 poses ; IoU normalisée en échelle =
  max sur k de IoU(niveau 1 agrandi de k autour de la position de l'entité, niveau 30) (proposition ≤ 0,75) ;
- F46 recalculée : enveloppe balayée par la tête de l'époque sur 64 directions (triangles exportés par
  `run_laser.py dry`), part de la pièce paire jamais couverte par la tête ;
- D2-1 : zone de lueur de jour d'au moins 8 × 8 px hr (dès l'époque 3) ; photométrie du corps (§1.5).
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose_laser as CL  # noqa: E402
import laser_design as D  # noqa: E402

RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
GEO = os.path.join(RENDER, "cache", "levels-laser", "geo")
PPT = 64.0
DIRS = ("N", "E", "S", "W")
OX, OY = D.ORIGIN_PX
K = math.sqrt(0.5)


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / u) if u else 0.0


def bbox(m):
    ys, xs = np.nonzero(m)
    return xs.min(), xs.max() + 1, ys.min(), ys.max() + 1


def geom(m):
    x0, x1, y0, y1 = bbox(m)
    t = lambda px, o: (px - o) / PPT
    return {"top": t(y0, OY), "bottom": t(y1, OY), "left": t(x0, OX), "right": t(x1, OX),
            "O": -t(y0, OY) - 1.0, "L": (x1 - x0) / PPT, "area": float(m.sum() / PPT ** 2)}


def scaled_iou(a1, b, ks):
    """max sur k de IoU(homothétie de a1 de rapport k centrée sur l'origine, b) ; |a1·k| = k²|a1| (hors canevas compris)."""
    H, W = a1.shape
    yy, xx = np.mgrid[0:H, 0:W]
    nb = b.sum()
    na = a1.sum()
    best, bk = 0.0, 1.0
    for k in ks:
        sx = np.floor(OX + (xx + 0.5 - OX) / k).astype(int)
        sy = np.floor(OY + (yy + 0.5 - OY) / k).astype(int)
        ok = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H)
        ak = np.zeros_like(b)
        ak[ok] = a1[sy[ok], sx[ok]]
        inter = np.logical_and(ak, b).sum()
        union = na * k * k + nb - inter
        v = inter / union
        if v > best:
            best, bk = float(v), float(k)
    return best, bk


def head_envelope(level):
    """Masque de l'enveloppe balayée par la tête sur 64 directions (triangles de la géométrie, sans alpha : prudent)."""
    odd = level if level % 2 else level - 1
    p = os.path.join(GEO, "geo-L%02d.npz" % odd)
    if odd < 3 or not os.path.exists(p):
        return None
    tris = np.load(p)["head"]
    img = Image.new("L", (D.CANVAS_W, D.CANVAS_H), 0)
    dr = ImageDraw.Draw(img)
    for k in range(64):
        a = -2 * math.pi * k / 64
        c, s = math.cos(a), math.sin(a)
        x = tris[..., 0] * c - tris[..., 1] * s
        y = tris[..., 0] * s + tris[..., 1] * c
        u = OX + x * PPT
        v = OY - K * (y + tris[..., 2]) * PPT
        pts = np.stack([u, v], -1)
        for tri in pts:
            dr.polygon([tuple(p) for p in tri], fill=255)
    return np.asarray(img) > 0


def lum(rgb):
    return rgb[..., :3] @ np.array([0.2126, 0.7152, 0.0722])


def photometry(level):
    """Luminance (sRGB, /255) et saturation du corps : couches principales socle + tête N, pixels d'alpha ≥ 0,5."""
    vals, sats = [], []
    for lay in CL.level_layers(level, "N", with_glow=False):
        if lay["kind"] != "main":
            continue
        im = lay["img"]
        m = im[..., 3] >= 0.5
        rgb = im[..., :3][m]
        vals.append(lum(rgb))
        mx, mn = rgb.max(-1), rgb.min(-1)
        sats.append(np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0))
    v = np.concatenate(vals) * 255
    s = np.concatenate(sats)
    return {"L_p05": float(np.percentile(v, 5)), "L_p50": float(np.percentile(v, 50)), "L_p95": float(np.percentile(v, 95)),
            "L_std": float(v.std()), "sat": float(s.mean())}


def glow_zone(level):
    """Plus grande densité de lueur de jour : existe-t-il une fenêtre 8 × 8 px hr couverte à ≥ 75 % (valeur ≥ 0,3) ?"""
    best = {}
    for part in ("base",) + DIRS:
        if part != "base" and level < 3:
            continue
        lv = level if part == "base" else (level if level % 2 else level - 1)
        p = os.path.join(CL.OUT, "L%02d" % lv, "%s-glow.png" % part)
        if not os.path.exists(p):
            best[part] = 0
            continue
        g = CL.load_rgba(p)
        m = (g[..., 3] >= 0.3).astype(np.int32)
        ii = np.pad(m.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
        w = ii[8:, 8:] - ii[:-8, 8:] - ii[8:, :-8] + ii[:-8, :-8]
        best[part] = int(w.max()) if w.size else 0
    return best


GAIN_FILE = os.path.join(HERE, "albedo_gain.txt")


def read_gains():
    g = {}
    if os.path.exists(GAIN_FILE):
        with open(GAIN_FILE, encoding="utf-8") as f:
            for line in f:
                p = line.split("#")[0].split()
                if len(p) == 2:
                    g[int(p[0])] = float(p[1])
    return g


def calibrate():
    """Gain d'albédo par époque pour amener la luminance médiane du corps sur la cible du §1.5 (±10).
    La luminance sRGB varie à peu près comme albédo^(1/2,2) : gain × (cible / mesure)^2,2, borné à [0,5 ; 2,5].
    Mesure sur le niveau impair (socle + tête N) ; écrit albedo_gain.txt (lu par laser_model.py au rendu suivant)."""
    old = read_gains()
    lines = ["# gain d'albédo par époque (measure_laser.py --calibrate) : époque gain   # p50 mesuré -> cible"]
    for e in D.EPOCHS:
        if e == 1:
            continue
        lv = 2 * e - 1
        g0 = old.get(e, 1.0)
        try:
            ph = photometry(lv)
        except ValueError:          # niveau pas encore rendu : gain inchangé
            lines.append("%d %.3f   # non mesuré (aucun rendu)" % (e, g0))
            print(lines[-1])
            continue
        tgt = D.LUM_TARGET[e]
        g = g0 * (tgt / max(1.0, ph["L_p50"])) ** 2.2 if abs(ph["L_p50"] - tgt) > 4 else g0
        g = min(2.5, max(0.5, g))
        lines.append("%d %.3f   # p50 %.1f -> %d (gain précédent %.3f)" % (e, g, ph["L_p50"], tgt, g0))
        print(lines[-1])
    with open(GAIN_FILE, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def head_mask(level, direction, thr=0.5):
    """Masque de la tête seule (couche object), pour l'indicateur strict « tête seule » de D1-3."""
    a = np.zeros((D.CANVAS_H, D.CANVAS_W))
    for lay in CL.level_layers(level, direction, with_glow=False):
        if lay["kind"] != "main" or lay["order"] != "object":
            continue
        h, w = lay["img"].shape[:2]
        xi, yi = OX + lay["x0"], OY + lay["y0"]
        src = lay["img"][..., 3]
        a[yi:yi + h, xi:xi + w] = src + a[yi:yi + h, xi:xi + w] * (1 - src)
    return a >= thr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default=os.path.join(RENDER, "out", "levels", "laser", "mesures-d1.json"))
    ap.add_argument("--calibrate", action="store_true", help="étalonne albedo_gain.txt (luminance §1.5) et s'arrête")
    a = ap.parse_args()
    if a.calibrate:
        calibrate()
        return
    masks = {}
    for lv in D.LEVELS:
        for d in DIRS:
            masks[(lv, d)] = CL.mask_of(lv, d)
    rep = {"levels": {}, "d13": {}, "epochs": {}}
    for lv in D.LEVELS:
        e = D.epoch_of(lv)
        r = {"epoch": e, "poses": {}}
        for d in DIRS:
            r["poses"][d] = geom(masks[(lv, d)])
        r["O_max"] = max(p["O"] for p in r["poses"].values())
        r["O_N"] = r["poses"]["N"]["O"]
        r["L_N"] = r["poses"]["N"]["L"]
        r["L_max"] = max(p["L"] for p in r["poses"].values())
        r["area_N"] = r["poses"]["N"]["area"]
        if lv >= 2:
            prev = lv - 1
            r["iou_prev"] = {d: iou(masks[(lv, d)], masks[(prev, d)]) for d in DIRS}
            r["iou_prev_max"] = max(r["iou_prev"].values())
        if lv % 2 == 0:
            add = {d: float(np.logical_and(masks[(lv, d)], ~masks[(lv - 1, d)]).sum() / PPT ** 2) for d in DIRS}
            r["added_t2"] = add
            r["added_min"] = min(add.values())
            env = head_envelope(lv) if lv >= 3 else None
            if env is None and lv == 2:
                # vanilla : enveloppe de la tête = union des 64 images « prepared » (mesure directe des sprites)
                env = vanilla_head_envelope()
            piece = np.logical_and(masks[(lv, "N")], ~masks[(lv - 1, "N")])
            # pièce : pixels ajoutés au SOCLE (indépendants de la pose de la tête)
            base_add = base_added(lv)
            r["piece_visible_frac"] = float(np.logical_and(base_add, ~env).sum() / max(1, base_add.sum()))
            ys = np.nonzero(env.any(1))[0]
            r["head_env_bottom"] = float((ys.max() + 1 - OY) / PPT)
        if lv % 2 == 1 and lv >= 3:
            r["iou_epoch_prev"] = {d: iou(masks[(lv, d)], masks[(lv - 2, d)]) for d in DIRS}
            r["iou_epoch_prev_max"] = max(r["iou_epoch_prev"].values())
        r["photometry"] = photometry(lv)
        r["glow_8x8_max"] = glow_zone(lv)
        rep["levels"][lv] = r
    # D1-3 amendé
    ks = np.arange(0.70, 3.01, 0.01)
    for last in (30, 29):
        d13 = {}
        for d in DIRS:
            v, k = scaled_iou(masks[(1, d)], masks[(last, d)], ks)
            d13[d] = {"iou": iou(masks[(1, d)], masks[(last, d)]), "iou_scaled": v, "k": k}
        rep["d13"]["L01_vs_L%02d" % last] = {"poses": d13, "iou_max": max(x["iou"] for x in d13.values()),
                                             "iou_scaled_max": max(x["iou_scaled"] for x in d13.values())}
    # indicateur strict : TÊTES seules (sans aucun socle), niveau 1 vanilla contre niveau 29
    hd = {}
    for d in DIRS:
        h1, h29 = head_mask(1, d), head_mask(29, d)
        v, k = scaled_iou(h1, h29, ks)
        hd[d] = {"iou": iou(h1, h29), "iou_scaled": v, "k": k}
    rep["d13"]["tetes_L01_vs_L29"] = {"poses": hd, "iou_max": max(x["iou"] for x in hd.values()),
                                      "iou_scaled_max": max(x["iou_scaled"] for x in hd.values())}
    # contrôle de la mesure normalisée : un simple agrandissement du vanilla doit donner 1,00
    rep["d13"]["controle_homothetie"] = scaled_iou(masks[(1, "N")], homothety(masks[(1, "N")], 1.35), ks)[0]
    os.makedirs(os.path.dirname(a.json), exist_ok=True)
    with open(a.json, "w", encoding="utf-8") as f:
        json.dump(rep, f, indent=1, sort_keys=True)
    print_tables(rep)


def homothety(m, k):
    H, W = m.shape
    yy, xx = np.mgrid[0:H, 0:W]
    sx = np.floor(OX + (xx + 0.5 - OX) / k).astype(int)
    sy = np.floor(OY + (yy + 0.5 - OY) / k).astype(int)
    ok = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H)
    out = np.zeros_like(m)
    out[ok] = m[sy[ok], sx[ok]]
    return out


def base_added(level):
    """Pixels du socle de niveau pair absents du socle impair (niveau 2 : la pièce seule)."""
    def base_alpha(lv):
        a = np.zeros((D.CANVAS_H, D.CANVAS_W))
        for lay in CL.level_layers(lv, "N", with_glow=False):
            if lay["kind"] != "main" or lay["order"] != "lower":
                continue
            h, w = lay["img"].shape[:2]
            xi, yi = OX + lay["x0"], OY + lay["y0"]
            src = lay["img"][..., 3]
            a[yi:yi + h, xi:xi + w] = src + a[yi:yi + h, xi:xi + w] * (1 - src)
        return a >= 0.5
    return np.logical_and(base_alpha(level), ~base_alpha(level - 1))


def vanilla_head_envelope():
    env = np.zeros((D.CANVAS_H, D.CANVAS_W), bool)
    for fr in range(64):
        lay = CL.vanilla_layer("head", frame=fr, order="object")
        h, w = lay["img"].shape[:2]
        xi, yi = OX + lay["x0"], OY + lay["y0"]
        env[yi:yi + h, xi:xi + w] |= lay["img"][..., 3] >= 0.5
    return env


def print_tables(rep):
    L = rep["levels"]
    print("niv ép | O_N   O_max cible plaf | L_N  L_max cible | aire_N | IoU préc | ajout pièce min t² | pièce visible | IoU ép. préc | lum p50 cible p95 sat | lueur 8x8")
    for lv in D.LEVELS:
        r = L[lv]
        e = r["epoch"]
        ph = r["photometry"]
        gz = r["glow_8x8_max"]
        gzs = max(gz.values()) if gz else 0
        print("%3d %2d | %5.2f %5.2f %5.2f %4.2f | %4.2f %5.2f %5.2f | %5.2f | %s | %s | %s | %s | %5.1f %4d %5.1f %4.2f | %s" % (
            lv, e, r["O_N"], r["O_max"], D.O_TARGET[e], D.O_CEILING, r["L_N"], r["L_max"], D.L_TARGET[e], r["area_N"],
            "%5.3f" % r["iou_prev_max"] if "iou_prev_max" in r else "  -  ",
            "%6.3f" % r["added_min"] if "added_min" in r else "   -  ",
            "%4.0f %%" % (100 * r["piece_visible_frac"]) if "piece_visible_frac" in r else "  -  ",
            "%5.3f" % r["iou_epoch_prev_max"] if "iou_epoch_prev_max" in r else "  -  ",
            ph["L_p50"], D.LUM_TARGET[e], ph["L_p95"], ph["sat"], "%d/64" % gzs))
    for k, v in rep["d13"].items():
        if isinstance(v, dict):
            print("D1-3 %s : IoU max %.3f, IoU normalisée max %.3f ; %s" % (k, v["iou_max"], v["iou_scaled_max"], ", ".join(
                "%s %.3f/%.3f (k %.2f)" % (d, x["iou"], x["iou_scaled"], x["k"]) for d, x in v["poses"].items())))
        else:
            print("D1-3 %s : %.3f (attendu 1,000)" % (k, v))


if __name__ == "__main__":
    main()
