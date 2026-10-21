"""Mesures D1 du centre de commandement, 15 niveaux (lot V3-a, phase 1). Python système (numpy + Pillow).

    python -P tools/render/pieces/levels/centre/mesures_d1.py [--out <json>] [--md]

Lit les aperçus de tools/render/out/levels/centre/nNN/ (render_centre.py) :
  mask-sil.npz  : masque D1-3 amendé (alpha brut du rendu principal >= 0,5, SANS couches plates au sol :
                  plate-forme, dalle, aire, émetteur ; sans liseré de contact) ;
  mask-mass.npz : idem, sans les tiges fines (mâts, antennes, drapeaux, garde-corps) : mesure de O et L ;
  hr-centre-nNN-main.png / -glow.png : photométrie (couche livrée) et part émissive.
Repère : tuiles de jeu, origine = position de l'entité, y vers le bas (bible §1.4). 64 px par tuile.

Indicateurs (bible §1.4, OBJECTIFS D1 ; le centre n'a pas de niveau pair : chaque niveau est une
silhouette, comparée au niveau précédent) :
  O, O_tige, L, aire, couverture de l'emprise 4×4, aire ajoutée / retirée par rapport au niveau précédent,
  IoU avec le niveau précédent (<= 0,85), vide V (part du masque du niveau 1 laissée transparente),
  D1-3 : IoU(1, 15) (< 0,50, cible <= 0,45) et IoU normalisée en échelle (max sur k de IoU(niveau 1
  agrandi de k autour de l'origine, niveau 15) ; proposition <= 0,75), plus une variante plus SÉVÈRE
  (échelle ET translation libres) ; dépassements comptés sur le profil du haut ; photométrie.
Aucune écriture hors du fichier --out (par défaut : mesures_d1.json à côté de ce script).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(RENDER, "out", "levels", "centre")
sys.path.insert(0, HERE)
import centre_params as PR  # noqa: E402

PPT = 64
# toile commune en tuiles : x [-6, 8), y [-9, 4)
X0, X1, Y0, Y1 = -6, 8, -9, 4
W, H = (X1 - X0) * PPT, (Y1 - Y0) * PPT
LUMA = np.array([0.2126, 0.7152, 0.0722])


def load_mask(path):
    z = np.load(path)
    h, w = (int(v) for v in z["shape"])
    m = np.unpackbits(z["mask"], axis=1)[:, :w].astype(bool)
    ox, oy = (float(v) for v in z["origin"])
    canvas = np.zeros((H, W), bool)
    x0 = int(round(-X0 * PPT - ox))
    y0 = int(round(-Y0 * PPT - oy))
    canvas[y0:y0 + h, x0:x0 + w] = m
    return canvas


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / u) if u else 0.0


# centres des pixels de la toile en tuiles
_XS = (np.arange(W) + 0.5) / PPT + X0
_YS = (np.arange(H) + 0.5) / PPT + Y0


def scaled(mask, k):
    """Agrandit un masque d'un facteur k autour de l'origine de l'entité (comme scale + shift × k d'un
    sprite : prototypes/levels/common.lua kit.scale) ; échantillonnage au plus proche."""
    xi = np.floor((_XS / k - X0) * PPT).astype(int)
    yi = np.floor((_YS / k - Y0) * PPT).astype(int)
    okx = (xi >= 0) & (xi < W)
    oky = (yi >= 0) & (yi < H)
    out = np.zeros_like(mask)
    sub = mask[np.clip(yi, 0, H - 1)][:, np.clip(xi, 0, W - 1)]
    out[np.ix_(oky, okx)] = sub[np.ix_(oky, okx)]
    return out


def iou_scale(a1, an, ks):
    best = (0.0, 1.0)
    for k in ks:
        v = iou(scaled(a1, k), an)
        if v > best[0]:
            best = (v, float(k))
    return best


def iou_scale_shift(a1, an, ks):
    """Variante sévère : max sur l'échelle k ET sur toute translation entière (corrélation par FFT)."""
    fb = np.fft.rfft2(an.astype(np.float64), s=(2 * H, 2 * W))
    nb = an.sum()
    best = (0.0, 1.0, (0, 0))
    for k in ks:
        s = scaled(a1, k)
        na = s.sum()
        if na == 0:
            continue
        fa = np.fft.rfft2(s.astype(np.float64)[::-1, ::-1], s=(2 * H, 2 * W))
        inter = np.fft.irfft2(fa * fb, s=(2 * H, 2 * W))
        i = np.unravel_index(np.argmax(inter), inter.shape)
        I = inter[i]
        v = float(I / (na + nb - I))
        if v > best[0]:
            dy, dx = i[0] - (H - 1), i[1] - (W - 1)
            best = (v, float(k), (round(dx / PPT, 3), round(dy / PPT, 3)))
    return best


def extent(mask):
    ys, xs = np.nonzero(mask)
    return (xs.min() / PPT + X0, (xs.max() + 1) / PPT + X0, ys.min() / PPT + Y0, (ys.max() + 1) / PPT + Y0)


def events(mask_mass, base_v, min_prom=0.12, min_w=0.10):
    """Dépassements de silhouette : pics du profil du haut (v le plus haut par colonne) qui s'élèvent d'au
    moins min_prom tuile au-dessus de leurs deux vallées et de base_v (haut du corps), larges d'au moins
    min_w tuile. Indicateur approché (bible §1.2 : « événements » par ère)."""
    cols = mask_mass.any(0)
    top = np.full(W, np.nan)
    idx = np.where(cols)[0]
    for c in idx:
        top[c] = -(np.argmax(mask_mass[:, c]) / PPT + Y0)   # hauteur (tuiles, vers le haut)
    h = np.nan_to_num(top, nan=-99)
    n = 0
    c = 0
    minw = int(min_w * PPT)
    peaks = []
    while c < W:
        if h[c] > -base_v + min_prom:
            d = c
            while d < W and h[d] > -base_v + min_prom:
                d += 1
            if d - c >= minw:
                peaks.append((round(c / PPT + X0, 2), round(d / PPT + X0, 2), round(float(h[c:d].max()) - 2, 2)))
                n += 1
            c = d
        else:
            c += 1
    return n, peaks


def photometry(main_png, glow_png):
    im = np.asarray(Image.open(main_png).convert("RGBA")).astype(np.float64) / 255.0
    a = im[..., 3] >= 0.5
    rgb = im[..., :3][a]
    lum = rgb @ LUMA * 255.0
    mx, mn = rgb.max(1), rgb.min(1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    out = {"L5": round(float(np.percentile(lum, 5)), 1), "L50": round(float(np.median(lum)), 1),
           "L95": round(float(np.percentile(lum, 95)), 1), "sat": round(float(sat.mean()), 3),
           "body_px": int(a.sum())}
    if glow_png and os.path.exists(glow_png):
        g = np.asarray(Image.open(glow_png).convert("RGBA")).astype(np.float64) / 255.0
        out["glow_px"] = int((g[..., 3] >= 0.25).sum())
        out["glow_share"] = round(out["glow_px"] / max(1, out["body_px"]), 4)
        # plus grande zone lumineuse (boîte 8 × 8 px hr au moins : bible §1.6, F37)
        gm = g[..., 3] >= 0.25
        out["glow_8x8"] = bool(_has_block(gm, 8))
    return out


def _has_block(m, k):
    """Vrai si le masque contient un carré plein de k × k pixels (somme glissante)."""
    if m.shape[0] < k or m.shape[1] < k:
        return False
    c = np.cumsum(np.cumsum(np.pad(m.astype(np.int32), ((1, 0), (1, 0))), 0), 1)
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return bool((s == k * k).any())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "mesures_d1.json"))
    ap.add_argument("--md", action="store_true", help="imprime le tableau Markdown")
    a = ap.parse_args()
    levels = [e for e in range(1, 16) if os.path.exists(os.path.join(OUT, "n%02d" % e, "mask-sil.npz"))]
    sil, mass, full = {}, {}, {}
    rows = []
    for e in levels:
        d = os.path.join(OUT, "n%02d" % e)
        sil[e] = load_mask(os.path.join(d, "mask-sil.npz"))
        mass[e] = load_mask(os.path.join(d, "mask-mass.npz"))
        full[e] = load_mask(os.path.join(d, "mask-full.npz"))
    fp = np.zeros((H, W), bool)
    fp[(-2 - Y0) * PPT:(2 - Y0) * PPT, (-2 - X0) * PPT:(2 - X0) * PPT] = True
    a1 = sil.get(1)
    for e in levels:
        ex_m = extent(mass[e])
        ex_s = extent(sil[e])
        O = -ex_m[2] - 2.0
        O_t = -ex_s[2] - 2.0
        Lw = ex_m[1] - ex_m[0]
        area = sil[e].sum() / PPT ** 2
        r = {"level": e, "name": PR.NAMES[e], "era": PR.ERA[e],
             "O": round(O, 2), "O_target": PR.ENVELOPE[e][0], "O_tige": round(O_t, 2),
             "L": round(Lw, 2), "L_max": PR.ENVELOPE[e][1],
             "x": [round(ex_s[0], 2), round(ex_s[1], 2)], "y": [round(ex_s[2], 2), round(ex_s[3], 2)],
             "area_t2": round(float(area), 2),
             "footprint_cover": round(float(np.logical_and(sil[e], fp).sum() / fp.sum()), 3)}
        if e - 1 in sil:
            p = sil[e - 1]
            r["iou_prev"] = round(iou(p, sil[e]), 3)
            r["added_t2"] = round(float(np.logical_and(sil[e], ~p).sum() / PPT ** 2), 2)
            r["removed_t2"] = round(float(np.logical_and(p, ~sil[e]).sum() / PPT ** 2), 2)
        if a1 is not None:
            r["V_pct"] = round(100.0 * float(np.logical_and(a1, ~sil[e]).sum() / a1.sum()), 1)
            r["V_min_pct"] = PR.ENVELOPE[e][2]
            r["iou_lvl1"] = round(iou(a1, sil[e]), 3)
        body_top = -ex_m[2]
        # haut du « corps » : ligne la plus haute couverte sur au moins 40 % de la largeur des masses
        rowcov = mass[e].sum(1) / max(1, (ex_m[1] - ex_m[0]) * PPT)
        rr = np.where(rowcov >= 0.4)[0]
        base_v = rr.min() / PPT + Y0 if len(rr) else ex_m[2]
        n_ev, peaks = events(sil[e], base_v)
        r["events"] = n_ev
        r["peaks"] = peaks
        mp = os.path.join(OUT, "n%02d" % e, "hr-centre-n%02d-main.png" % e)
        gp = os.path.join(OUT, "n%02d" % e, "hr-centre-n%02d-glow.png" % e)
        if os.path.exists(mp):
            r["photo"] = photometry(mp, gp)
            r["photo"]["L50_target"] = PR.LUM_TARGET[e]
        r["body_top_tiles"] = round(body_top, 2)
        rows.append(r)
    res = {"levels": rows, "notes": "masques alpha >= 0,5 à 64 px/tuile ; O sur mask-mass ; IoU sur mask-sil"}
    O_seq = [r["O"] for r in rows]
    res["O_monotone"] = all(b >= a - 1e-9 for a, b in zip(O_seq, O_seq[1:]))
    res["O_max_vs_ceiling"] = [max(O_seq) if O_seq else None, PR.O_CEILING]
    if 1 in sil and 15 in sil:
        ks = np.round(np.arange(0.50, 3.001, 0.01), 3)
        v, k = iou_scale(sil[1], sil[15], ks)
        res["d1_3"] = {"iou_1_15": round(iou(sil[1], sil[15]), 3),
                       "iou_1_15_full": round(iou(full[1], full[15]), 3),
                       "iou_norm_scale": round(v, 3), "k_best": k}
        ks2 = np.round(np.arange(0.50, 3.001, 0.02), 3)
        v2, k2, sh = iou_scale_shift(sil[1], sil[15], ks2)
        res["d1_3"].update({"iou_norm_scale_shift": round(v2, 3), "k2_best": k2, "shift2_tiles": sh})
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1, ensure_ascii=False)
    if a.md:
        print(table_md(res))
    else:
        print(json.dumps(res.get("d1_3", {}), ensure_ascii=False))
        print("O monotone :", res["O_monotone"], "; O max / plafond :", res["O_max_vs_ceiling"])


def table_md(res):
    lines = ["| Niv. | Nom | O (cible) | O tige | L (max) | Aire t² | Emprise % | IoU préc. | +aire / -aire t² | "
             "IoU niv. 1 | V % (min) | Dépass. | L50 (cible) | p95 | sat | émissif % |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in res["levels"]:
        ph = r.get("photo", {})
        lines.append("| %d | %s | %.2f (%.2f) | %.2f | %.2f (%.2f) | %.2f | %.0f | %s | %s | %s | %s | %d | %s | %s | %s | %s |" % (
            r["level"], r["name"], r["O"], r["O_target"], r["O_tige"], r["L"], r["L_max"], r["area_t2"],
            100 * r["footprint_cover"], r.get("iou_prev", "—"),
            ("%.2f / %.2f" % (r["added_t2"], r["removed_t2"])) if "added_t2" in r else "—",
            r.get("iou_lvl1", "—"), ("%.1f (%d)" % (r["V_pct"], r["V_min_pct"])) if "V_pct" in r else "—",
            r["events"], ("%.0f (%d)" % (ph["L50"], ph["L50_target"])) if ph else "—", ph.get("L95", "—"),
            ph.get("sat", "—"), ("%.1f" % (100 * ph["glow_share"])) if "glow_share" in ph else "0"))
    d = res.get("d1_3")
    if d:
        lines.append("")
        lines.append("D1-3 : IoU(1, 15) sans couches plates = %.3f (seuil < 0,50, cible <= 0,45) ; avec tout = %.3f ; "
                     "IoU normalisée en échelle = %.3f (k = %.2f ; proposition <= 0,75) ; variante sévère échelle + "
                     "translation = %.3f (k = %.2f, décalage %s tuile)." % (
                         d["iou_1_15"], d["iou_1_15_full"], d["iou_norm_scale"], d["k_best"], d["iou_norm_scale_shift"],
                         d["k2_best"], d["shift2_tiles"]))
    lines.append("O jamais décroissant : %s ; O max %.2f pour un plafond de %.2f." % (
        res["O_monotone"], res["O_max_vs_ceiling"][0], res["O_max_vs_ceiling"][1]))
    return "\n".join(lines)


if __name__ == "__main__":
    main()
