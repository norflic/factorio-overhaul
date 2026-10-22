"""Tourelle laser, lot V3 phase 1 : mesures D1 / D2 / F46 sur les rendus d'aperçu (Python système).

    python tools/render/pieces/levels/laser/measure_laser.py   [--json chemin]

Masque (bible §1.4, D1-3 amendé Q13) : pixels d'alpha ≥ 128 des couches PRINCIPALES (socle + tête), sans ombre,
lueur ni halo, 64 px par tuile, même origine (position de l'entité). Pour D1-3, le socle est pris SANS ses objets plats
au sol (passe « noflat » : anneau-halo du niveau 30, patins, soles ; correction V3, mineur 5). Niveau 1 = sprites
vanilla (turrets.lua:883-1041), tête « prepared » image 0/16/32/48 pour N/E/S/O ; niveau 2 = vanilla + pièce ;
niveau 2e = socle 2e + tête 2e-1.

Indicateurs (bible §1.4, OBJECTIFS D1) :
- O : sommet des MASSES au-dessus du bord haut de l'emprise (y = -1), tiges de moins de 0,15 tuile EXCLUES (bible
  §1.4 ; masses.py : ouverture horizontale de 10 px hr) ; O_brut (tiges comprises) noté à part ; L : largeur des masses
  (tiges horizontales exclues), L_brut : largeur du masque complet. Correction V3 (vérification passe 5, majeur 1) : la
  passe 5 mesurait O et L sur le masque complet, antennes et épines comprises ;
- événements de silhouette (bible §1.2, D1-2) : pics du contour haut et dépassements latéraux secondaires de
  proéminence ≥ 8 px hr (masses.silhouette_events ; comptage PROPOSÉ, la bible ne le définit pas) ;
- pair : aire ajoutée par la pièce hors du masque impair (≥ 0,10 t² visée, minimum sur les poses) et IoU(2e, 2e-1) ;
- impair : IoU(2e-1, 2e-2) ≤ 0,85 (D1-1) ; IoU entre époques consécutives (impairs) ≤ 0,85 (D1-2) ;
- D1-3 : IoU(niveau 1, niveau 30) < 0,50 (cible ≤ 0,45), maximum sur les 4 poses ; IoU normalisée en échelle =
  max sur k de IoU(niveau 1 agrandi de k autour de la position de l'entité, niveau 30) (proposition ≤ 0,75) ; variante
  plus stricte : échelle ET translation libre (|t| ≤ 32 px hr, corrélation FFT) ;
- F46 recalculée : enveloppe balayée par la tête de l'époque sur 64 directions (triangles exportés par
  `run_laser.py dry`), part de la pièce paire jamais couverte par la tête ;
- D2-1 : plus grand carré de lueur de jour ENTIÈREMENT couvert (alpha ≥ 0,3), au moins 8 × 8 px hr dès l'époque 3
  (correction V3, mineur 4 : la passe 5 acceptait une fenêtre 8 × 8 couverte à 75 %) ; photométrie du corps (§1.5) ;
- D2-3 : halo de nuit du socle : pic au sol, aire (alpha ≥ 0,02), rayon à mi-intensité (aire où alpha ≥ pic/2) comparé
  à S(N)/2 ;
- couche du socle (majeur 2) : haut du socle seul et couche proposée (« object » s'il dépasse le bord nord).
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
import masses as MS  # noqa: E402

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


VIGNETTE_SCALE = 0.2336     # échelle de la planche (d) : le plus grand masque (274 px hr) tient dans 64 px


def vignette(m, s=VIGNETTE_SCALE):
    H, W = m.shape
    im = Image.fromarray((np.asarray(m) * 255).astype(np.uint8), "L").resize(
        (max(1, int(round(W * s))), max(1, int(round(H * s)))), Image.BOX)
    return np.asarray(im) >= 128


def geom(m):
    """O et L des masses (tiges exclues), O_brut et L_brut, boîte et aire (masses.shape_metrics). Événements de
    silhouette comptés À L'ÉCHELLE DE LA VIGNETTE (test D1-2) : pics du contour haut et dépassements latéraux
    secondaires de proéminence ≥ 2 px de vignette (≈ 8,6 px hr) ; à 64 px/tuile, ailettes et rivets comptaient."""
    g = MS.shape_metrics(m, (OX, OY))
    g["events"] = MS.silhouette_events(vignette(m), (0, 0), prom_px=2)
    return g


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
    """Lueur de jour (D2-1) : côté du plus grand carré ENTIÈREMENT couvert (alpha ≥ 0,3) par partie, et luminance de
    jour (couche principale + lueur additive) d'un carré 8 × 8 entièrement couvert, comparée ensuite à la médiane du
    corps (+80/255 visés)."""
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
        m = g[..., 3] >= 0.3
        best[part] = MS.largest_square(m)
        mp = os.path.join(CL.OUT, "L%02d" % lv, "%s-main.png" % part)
        if best[part] >= 8 and os.path.exists(mp):
            mi = CL.load_rgba(mp)
            comp = np.clip(mi[..., :3] * mi[..., 3:4] + g[..., :3] * g[..., 3:4], 0, 1)
            ii = np.pad(m.astype(np.int32).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
            w = ii[8:, 8:] - ii[:-8, 8:] - ii[8:, :-8] + ii[:-8, :-8]
            li = np.pad(lum(comp).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
            s8 = (li[8:, 8:] - li[:-8, 8:] - li[8:, :-8] + li[:-8, :-8]) / 64.0
            best[part + "_lum"] = float(255 * s8[w == 64].max())
    return best


def halo_metrics(level):
    """Halo de nuit du SOCLE (couche draw_as_light, canevas des halos) : pic, aire visible (alpha ≥ 0,02, t²), rayon à
    mi-intensité (rayon du disque de même aire que la zone où alpha ≥ pic/2, tuiles) et cible S(N)/2."""
    p = os.path.join(CL.OUT, "L%02d" % level, "base-light.png")
    S = D.halo_size(level)
    if level < 2 or not os.path.exists(p):
        return {"peak": 0.0, "area": 0.0, "r_half": 0.0, "target_r_half": S / 2, "I": D.halo_intensity(level)}
    a = CL.load_rgba(p)[..., 3]
    pk = float(a.max())
    return {"peak": pk, "area": float((a >= 0.02).sum() / PPT ** 2),
            "r_half": float(math.sqrt((a >= pk / 2).sum() / math.pi) / PPT) if pk > 0 else 0.0,
            "target_r_half": S / 2, "I": D.halo_intensity(level)}


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
    """Masque de la tête seule (secondary_draw_order 1), pour l'indicateur strict « tête seule » de D1-3."""
    a = np.zeros((D.CANVAS_H, D.CANVAS_W))
    for lay in CL.level_layers(level, direction, with_glow=False):
        if lay["kind"] != "main" or lay.get("sec", 0) != 1:
            continue
        h, w = lay["img"].shape[:2]
        xi, yi = OX + lay["x0"], OY + lay["y0"]
        src = lay["img"][..., 3]
        a[yi:yi + h, xi:xi + w] = src + a[yi:yi + h, xi:xi + w] * (1 - src)
    return a >= thr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default=os.path.join(RENDER, "out", "levels", "laser", "mesures-d1.json"))
    ap.add_argument("--txt", default=os.path.join(RENDER, "..", "..", "docs", "epoques", "planches", "laser",
                                                  "laser-mesures-d1.txt"), help="tableau texte (versionné avec les planches)")
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
        r["O_brut_max"] = max(p["O_brut"] for p in r["poses"].values())
        r["O_N"] = r["poses"]["N"]["O"]
        r["L_N"] = r["poses"]["N"]["L"]
        r["L_max"] = max(p["L"] for p in r["poses"].values())
        r["L_brut_max"] = max(p["L_brut"] for p in r["poses"].values())
        r["x_extent"] = max(max(-p["left"], p["right"]) for p in r["poses"].values())
        r["area_N"] = r["poses"]["N"]["area"]
        r["events_N"] = r["poses"]["N"]["events"]["total"]
        r["events_max"] = max(p["events"]["total"] for p in r["poses"].values())
        r["halo"] = halo_metrics(lv)
        top = CL.base_north_top(lv)
        r["base_top"] = top
        r["base_layer"] = CL.base_order_of(lv)
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
    # D1-3 amendé (Q13) : masque SANS les objets plats au sol (passe noflat), échelle, puis échelle + translation
    ks = np.arange(0.70, 3.01, 0.01)
    ks_t = np.arange(0.70, 2.51, 0.02)
    for last in (30, 29):
        d13 = {}
        for d in DIRS:
            mf = CL.mask_of(last, d, noflat=True)
            v, k = scaled_iou(masks[(1, d)], mf, ks)
            vt, kt, tx, ty_ = MS.scaled_shifted_iou(masks[(1, d)], mf, (OX, OY), ks_t, tmax=32)
            # information : la translation optimale touche souvent la borne de 32 px (pieds décalés d'une demi-tuile) ;
            # variante à ±64 px pour savoir ce que la borne retient
            v64 = MS.scaled_shifted_iou(masks[(1, d)], mf, (OX, OY), ks_t, tmax=64)
            d13[d] = {"iou": iou(masks[(1, d)], mf), "iou_scaled": v, "k": k, "iou_avec_plats": iou(masks[(1, d)], masks[(last, d)]),
                      "iou_scaled_shift": vt, "k_shift": kt, "t_px": [tx, ty_],
                      "iou_scaled_shift64": v64[0], "k_shift64": v64[1], "t64_px": [v64[2], v64[3]]}
        rep["d13"]["L01_vs_L%02d" % last] = {"poses": d13, "iou_max": max(x["iou"] for x in d13.values()),
                                             "iou_scaled_max": max(x["iou_scaled"] for x in d13.values()),
                                             "iou_scaled_shift_max": max(x["iou_scaled_shift"] for x in d13.values()),
                                             "iou_scaled_shift64_max": max(x["iou_scaled_shift64"] for x in d13.values()),
                                             "iou_avec_plats_max": max(x["iou_avec_plats"] for x in d13.values())}
    # indicateur strict : TÊTES seules (sans aucun socle), niveau 1 vanilla contre niveau 29
    hd = {}
    for d in DIRS:
        h1, h29 = head_mask(1, d), head_mask(29, d)
        v, k = scaled_iou(h1, h29, ks)
        hd[d] = {"iou": iou(h1, h29), "iou_scaled": v, "k": k}
    rep["d13"]["tetes_L01_vs_L29"] = {"poses": hd, "iou_max": max(x["iou"] for x in hd.values()),
                                      "iou_scaled_max": max(x["iou_scaled"] for x in hd.values()),
                                      "iou_scaled_shift_max": float("nan"), "iou_avec_plats_max": float("nan")}
    # événements de silhouette par ère (bible §1.2 : I 1-2, II 2-3, III 3-4, IV 4-5, V 5-6), pose N, niveaux impairs
    rep["eras"] = {}
    for era in range(1, 6):
        lvls = [2 * e - 1 for e in D.EPOCHS if D.ERA[e] == era]
        rep["eras"][era] = {"levels": lvls, "events_N": [rep["levels"][lv]["events_N"] for lv in lvls],
                            "events_max": [rep["levels"][lv]["events_max"] for lv in lvls],
                            "attendu": {1: [1, 2], 2: [2, 3], 3: [3, 4], 4: [4, 5], 5: [5, 6]}[era]}
    # contrôle de la mesure normalisée : un simple agrandissement du vanilla doit donner 1,00
    rep["d13"]["controle_homothetie"] = scaled_iou(masks[(1, "N")], homothety(masks[(1, "N")], 1.35), ks)[0]
    rep["concordance"] = concordance()
    lines = print_tables(rep)          # complète aussi rep (contraste des zones lumineuses)
    os.makedirs(os.path.dirname(a.txt), exist_ok=True)
    with open(a.txt, "w", encoding="utf-8", newline="\n") as f:
        f.write("# Tourelle laser, mesures D1 sur les aperçus de phase 1 (measure_laser.py) : légende en tête du script\n")
        f.write("\n".join(lines) + "\n")
    os.makedirs(os.path.dirname(a.json), exist_ok=True)
    with open(a.json, "w", encoding="utf-8") as f:
        json.dump(rep, f, indent=1, sort_keys=True)


def concordance():
    """Toutes les parties rendues portent-elles l'empreinte du code ACTUEL (laser_design.code_hash) ?"""
    cur = D.code_hash()
    ok, bad = 0, []
    for lv in range(2, 31):
        for part in ("base",) + DIRS:
            p = os.path.join(CL.OUT, "L%02d" % lv, "%s.json" % part)
            if not os.path.exists(p):
                continue
            with open(p, encoding="utf-8") as f:
                h = json.load(f).get("render", {}).get("code_sha256")
            if h == cur:
                ok += 1
            else:
                bad.append("L%02d %s" % (lv, part))
    return {"code_sha256": cur, "parties_conformes": ok, "parties_non_conformes": bad}


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
            if lay["kind"] != "main" or lay.get("sec", 0) != 0:
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


def print_tables(rep, out=None):
    out = [] if out is None else out
    import builtins
    _print = builtins.print

    def print(line):  # noqa: A001 : chaque ligne va à l'écran ET au fichier texte des mesures
        out.append(line)
        _print(line)
    L = rep["levels"]
    print("Colonnes : O = sommet des MASSES (tiges < 0,15 tuile exclues, bible §1.4), max sur N, E, S, O ; Obrut = tiges")
    print("comprises ; L = largeur des masses, max sur les poses ; Lbrut = masque complet ; x = demi-largeur maximale (|x|) ;")
    print("ajout = aire ajoutée par la pièce hors du masque impair (min sur les poses) ; vis = part de la pièce hors de")
    print("l'enveloppe balayée par la tête (F46) ; ev = événements de silhouette (pose N / max des poses) ; lueur = côté du")
    print("plus grand carré de lueur de jour entièrement couvert (px hr) et contraste avec la médiane du corps ; halo =")
    print("rayon à mi-intensité du halo du socle / S(N)/2 (tuiles), aire visible (t²) et pic ; socle = haut du socle seul")
    print("(tuiles, y vers le bas) et couche proposée (lower = lower-object vanilla ; object = correction du majeur 2).")
    print("Événements (ev) : comptage PROPOSÉ (la bible ne le définit pas), non étalonné : le vanilla (niveau 1) en compte déjà")
    print("plusieurs ; à lire comme une tendance par ère, pas comme un critère.")
    print("niv ép | O     Obrut cible | L    Lbrut cible  x    | aire_N | IoU préc | ajout t² | vis  | IoU ép. | ev N/max | p50 cible p95 sat | lueur px contr | halo r½/cible aire pic | socle haut couche")
    for lv in D.LEVELS:
        r = L[lv]
        e = r["epoch"]
        ph = r["photometry"]
        gz = r["glow_8x8_max"]
        # V3 : dans CHAQUE pose, au moins une zone (socle ou tête de la pose) de 8 × 8 px hr entièrement couverte :
        # minimum sur les poses du meilleur carré visible dans la pose
        gzs = min(max(gz.get("base", 0), gz.get(d, 0)) for d in DIRS) if lv >= 3 else gz.get("base", 0)
        glum = max([v for k, v in gz.items() if k.endswith("_lum")] or [float("nan")])
        r["glow_contrast"] = glum - ph["L_p50"]
        r["glow_square"] = gzs
        h = r["halo"]
        print("%3d %2d | %5.2f %5.2f %5.2f | %4.2f %5.2f %4.2f %5.2f | %5.2f | %s | %s | %s | %s | %2d / %2d | %5.1f %4d %5.1f %4.2f | %3d %+5.0f | %4.2f/%4.2f %5.2f %4.2f | %s %s" % (
            lv, e, r["O_max"], r["O_brut_max"], D.O_TARGET[e], r["L_max"], r["L_brut_max"], D.L_TARGET[e],
            r["x_extent"], r["area_N"],
            "%5.3f" % r["iou_prev_max"] if "iou_prev_max" in r else "  -  ",
            "%6.3f" % r["added_min"] if "added_min" in r else "   -  ",
            "%3.0f%%" % (100 * r["piece_visible_frac"]) if "piece_visible_frac" in r else "  - ",
            "%5.3f" % r["iou_epoch_prev_max"] if "iou_epoch_prev_max" in r else "  -  ",
            r["events_N"], r["events_max"],
            ph["L_p50"], D.LUM_TARGET[e], ph["L_p95"], ph["sat"], gzs, r["glow_contrast"],
            h["r_half"], h["target_r_half"], h["area"], h["peak"],
            "%+5.2f" % r["base_top"] if r["base_top"] is not None else "  -  ", r["base_layer"]))
    for k, v in rep["d13"].items():
        if isinstance(v, dict):
            print("D1-3 %s : IoU max %.3f (avec les plats au sol : %.3f), normalisée (échelle) max %.3f, normalisée (échelle + "
                  "translation ±32 px) max %.3f (±64 px : %s) ; %s" % (
                      k, v["iou_max"], v["iou_avec_plats_max"], v["iou_scaled_max"], v["iou_scaled_shift_max"],
                      "%.3f" % v["iou_scaled_shift64_max"] if "iou_scaled_shift64_max" in v else "-", ", ".join(
                          "%s %.3f/%.3f (k %.2f)%s" % (d, x["iou"], x["iou_scaled"], x["k"],
                                                       " /%.3f (k %.2f, t %s)" % (x["iou_scaled_shift"], x["k_shift"], x["t_px"])
                                                       if "iou_scaled_shift" in x else "")
                          for d, x in v["poses"].items())))
        else:
            print("D1-3 %s : %.3f (attendu 1,000)" % (k, v))
    c = rep.get("concordance")
    if c:
        print("Concordance code / aperçus : %d parties rendues avec le code actuel (empreinte %s...), %d non conformes %s" % (
            c["parties_conformes"], c["code_sha256"][:12], len(c["parties_non_conformes"]), c["parties_non_conformes"][:10]))
    for era, v in rep.get("eras", {}).items():
        print("D1-2 ère %d (niveaux %s) : événements pose N %s, max des poses %s ; attendu %d à %d" % (
            era, ",".join(str(x) for x in v["levels"]), v["events_N"], v["events_max"], v["attendu"][0], v["attendu"][1]))
    return out


if __name__ == "__main__":
    main()
