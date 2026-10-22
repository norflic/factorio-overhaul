"""Mesures D1 du mur (lot V3, famille « wall », phase 1), sur les aperçus rendus et le sprite vanilla.

    python -P tools/render/pieces/levels/wall/measure_wall.py [--md docs/epoques/planches/wall/mesures-d1.md]

Python système (numpy + Pillow). Les couches viennent de wall_layers.py (aperçus de
tools/render/out/levels/wall/, niveau 1 = sprite vanilla image 0, niveau 2 = vanilla + pièce).

Définitions (bible docs/DESIGN_EPOQUES.md §1.4, OBJECTIFS D1 amendé par Q13) :
- toile en tuiles x ∈ [-2 ; 2], y ∈ [-2,5 ; 1,5], 64 px/tuile (hr), origine = position de l'entité ;
- MASQUE = alpha ≥ 0,5 (128/255) des couches principales composées (ni ombre, ni lueur, ni halo). Le mur
  n'a AUCUNE couche plate au sol (ni socle, ni integration_patch) : rien n'est exclu en plus (Q13 a) ;
- O (masses) = dépassement au-dessus du bord haut de l'emprise (y = -0,5) de la plus haute rangée dont un
  segment continu fait au moins 0,15 tuile (les tiges plus fines ne comptent pas, bible §1.4) ;
  O (tout) = même chose avec le plus haut pixel du masque ;
- pièce paire : aire du masque pair hors du masque impair (≥ 0,10 tuile² visé, D1-1), ou changement de
  luminance d'au moins 20/255 sur au moins 0,15 tuile² ;
- IoU entre niveaux successifs, entre époques consécutives (niveaux impairs, ≤ 0,85, D1-2) ;
- D1-3 amendé : IoU(niveau 1, niveau 30) < 0,50 (cible ≤ 0,45) ET IoU normalisée en échelle
  max_k IoU(niveau 1 agrandi de k, niveau 30), k de 0,50 à 2,50 par pas de 0,01, homothétie de centre
  l'origine de l'entité (méthode E27 : échelle et shift multipliés par k) ; on rapporte aussi le maximum
  sur deux centres (origine ; milieu du bord bas du masque du niveau 1) : la valeur la plus défavorable ;
- photométrie du CORPS = pixels du masque hors zones émissives (lueur alpha ≥ 0,25 ; passe 4c), sRGB codé :
  luminance Rec. 709 p5/p50/p95 sur 255, saturation moyenne (max-min)/max ; part émissive du masque ; lueur (draw_as_glow) : aire, et meilleure fenêtre de 8 × 8 px hr
  entièrement lumineuse : luminance moyenne composée sur le corps moins la médiane du corps (≥ 80 visé, §1.6) ;
- halo : alpha maximal de la couche draw_as_light (I(N) = 0,05 + 0,02·N visé) et rayon au sol.
Chaque grandeur est donnée par pose (droit = straight_horizontal, isole = single).
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import wall_layers as WL  # noqa: E402
import wall_piece  # noqa: E402

PPT = 64
X0, X1, Y0, Y1 = -2.0, 2.0, -2.5, 1.5
W, H = int((X1 - X0) * PPT), int((Y1 - Y0) * PPT)
POSES = ("droit", "isole")
LEVELS = list(range(1, 31))
THIN = 0.15            # tuile : largeur minimale d'une « masse » (bible §1.4)


def place(img, shift):
    """Image (h, w, 4) posée sur la toile ; renvoie la toile RGBA (prémultipliée non, alpha droit)."""
    out = np.zeros((H, W, 4))
    h, w = img.shape[:2]
    x0 = (shift[0] - X0) * PPT - w / 2.0
    y0 = (shift[1] - Y0) * PPT - h / 2.0
    xi, yi = int(round(x0)), int(round(y0))
    assert abs(x0 - xi) < 1e-6 and abs(y0 - yi) < 1e-6, (shift, w, h)
    xs0, ys0 = max(0, -xi), max(0, -yi)
    xd0, yd0 = max(0, xi), max(0, yi)
    ww, hh = min(w - xs0, W - xd0), min(h - ys0, H - yd0)
    out[yd0:yd0 + hh, xd0:xd0 + ww] = img[ys0:ys0 + hh, xs0:xs0 + ww]
    return out


def compose(layers, kinds):
    """Composition « par-dessus » (sRGB codé, comme le moteur) des couches des genres demandés."""
    rgb = np.zeros((H, W, 3))
    a = np.zeros((H, W))
    for lay in layers:
        if lay["kind"] not in kinds:
            continue
        c = place(lay["img"], lay["shift"])
        ca = c[..., 3]
        rgb = c[..., :3] * ca[..., None] + rgb * (1 - ca[..., None])
        a = ca + a * (1 - ca)
    return rgb, a


def additive(layers, kind):
    acc = np.zeros((H, W, 3))
    for lay in layers:
        if lay["kind"] == kind:
            c = place(lay["img"], lay["shift"])
            acc += c[..., :3] * c[..., 3:4]
    return acc


def lum(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def to_tile_y(row):
    return Y0 + row / PPT


def max_run(row):
    best = cur = 0
    for v in row:
        cur = cur + 1 if v else 0
        best = max(best, cur)
    return best


def o_values(m):
    rows = np.nonzero(m.any(1))[0]
    if len(rows) == 0:
        return None, None
    top_all = to_tile_y(rows[0])
    top_mass = None
    for r in rows:
        if max_run(m[r]) >= THIN * PPT:
            top_mass = to_tile_y(r)
            break
    return -top_all - 0.5, (-top_mass - 0.5) if top_mass is not None else None


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / u) if u else 0.0


def scaled(m, k, center):
    """Masque m agrandi de k autour de center (tuiles) : M_k(p) = M(c + (p - c)/k) (plus proche voisin)."""
    cx, cy = center
    ys, xs = np.mgrid[0:H, 0:W]
    px = X0 + (xs + 0.5) / PPT
    py = Y0 + (ys + 0.5) / PPT
    sx = cx + (px - cx) / k
    sy = cy + (py - cy) / k
    ix = np.floor((sx - X0) * PPT).astype(int)
    iy = np.floor((sy - Y0) * PPT).astype(int)
    ok = (ix >= 0) & (ix < W) & (iy >= 0) & (iy < H)
    out = np.zeros((H, W), bool)
    out[ok] = m[iy[ok], ix[ok]]
    return out


def iou_scale_norm(m1, m30, center):
    best, kbest = 0.0, 1.0
    for k in np.arange(0.50, 2.505, 0.01):
        v = iou(scaled(m1, k, center), m30)
        if v > best:
            best, kbest = v, float(k)
    return best, kbest


def glow_stats(layers, body_rgb, body_a, body_med):
    """Zones lumineuses de jour (draw_as_glow), bible §1.6 / D2-1. Passe 4 (22/10) : on cherche la meilleure
    FENÊTRE de 8 × 8 px hr couverte au moins aux trois quarts par la lueur (alpha ≥ 0,25) : luminance moyenne de la lueur composée sur
    le corps, moins la médiane du corps (≥ 80 visé). L'ancienne mesure (médiane d'une composante connexe entière)
    noyait un tore lumineux dans le champ de plasma pâle qui le touche (niveau 26 : +3 pour une zone de 64 × 108)."""
    g = additive(layers, "glow")
    gl = g.max(-1)
    zone = gl >= 0.25
    if not zone.any():
        return None
    comp = np.clip(body_rgb + g, 0, 1)        # body_rgb est déjà composé sur noir (prémultiplié)
    L = lum(comp) * 255
    s = 8

    def integ(a):
        return np.pad(a, ((1, 0), (1, 0))).cumsum(0).cumsum(1)

    cz, cl = integ(zone.astype(np.int64)), integ(np.where(zone, L, 0.0))
    cnt = cz[s:, s:] - cz[:-s, s:] - cz[s:, :-s] + cz[:-s, :-s]
    sm = cl[s:, s:] - cl[:-s, s:] - cl[s:, :-s] + cl[:-s, :-s]
    full = cnt >= 0.75 * s * s               # fenêtre couverte aux trois quarts (un disque de 10 px passe)
    n_win = int(full.sum())
    best = round(float((sm[full] / cnt[full]).max()) - body_med, 1) if n_win else None
    return {"area_px": int(zone.sum()), "fenetres_8x8": n_win, "best_delta": best}


def light_stats(layers):
    li = None
    for lay in layers:
        if lay["kind"] == "light":
            c = place(lay["img"], lay["shift"])
            li = c[..., 3] if li is None else np.maximum(li, c[..., 3])
    if li is None or li.max() <= 0:
        return None
    ys, xs = np.nonzero(li > 0.02)
    r = np.hypot(X0 + (xs + 0.5) / PPT, Y0 + (ys + 0.5) / PPT - 0.35).max()
    return {"alpha_max": round(float(li.max()), 3), "rayon_tuiles": round(float(r), 2)}


def measure(db):
    res = {}
    masks = {}
    for pose in POSES:
        for lv in LEVELS:
            layers = WL.level_layers(lv, pose, "hr", res_db=db)
            rgb, a = compose(layers, ("main",))
            m = a >= 0.5
            masks[(lv, pose)] = (m, rgb, a)
            ys, xs = np.nonzero(m)
            # Corps = masque HORS zones émissives (lueur alpha >= 0,25). Passe 4c (22/10) : la couche principale
            # d'une surface émissive est le rendu MOINS la lueur, en sRGB codé (render_wall.py : principale + lueur
            # = rendu Blender au pixel) ; sur un cristal très émissif, ce reste est sombre et faussement saturé
            # (cristaux de l'époque 7 : RGB moyen (31, 41, 2)). Bible §1.5 règle 3 : les couleurs vives vivent dans
            # les couches émissives ; on mesure donc le corps sans elles et on rapporte leur part.
            gmax = additive(layers, "glow").max(-1)
            body = m & (gmax < 0.25)
            if body.sum() < 0.3 * m.sum():
                body = m
            l_body = lum(rgb[body]) * 255
            mx, mn = rgb[body].max(-1), rgb[body].min(-1)
            sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
            o_all, o_mass = o_values(m)
            r = {
                "part_emissive": round(float((m & (gmax >= 0.25)).sum() / max(1, m.sum())), 3),
                "aire_t2": round(m.sum() / PPT ** 2, 3),
                "x": [round(X0 + xs.min() / PPT, 3), round(X0 + (xs.max() + 1) / PPT, 3)],
                "y": [round(Y0 + ys.min() / PPT, 3), round(Y0 + (ys.max() + 1) / PPT, 3)],
                "L": round((xs.max() + 1 - xs.min()) / PPT, 3),
                "O_tout": round(o_all, 3), "O_masses": round(o_mass, 3) if o_mass is not None else None,
                "lum_p5": round(float(np.percentile(l_body, 5)), 1), "lum_p50": round(float(np.median(l_body)), 1),
                "lum_p95": round(float(np.percentile(l_body, 95)), 1), "sat": round(float(sat.mean()), 3),
            }
            r["lueur"] = glow_stats(layers, rgb, a, r["lum_p50"])
            r["halo"] = light_stats(layers)
            res[(lv, pose)] = r
    for pose in POSES:
        for lv in LEVELS[1:]:
            m, rgb, a = masks[(lv, pose)]
            mp, rgbp, ap = masks[(lv - 1, pose)]
            r = res[(lv, pose)]
            r["iou_prec"] = round(iou(m, mp), 3)
            if lv % 2 == 0:
                add = np.logical_and(m, ~mp).sum() / PPT ** 2
                both = np.logical_and(m, mp)
                dl = np.abs(lum(rgb) - lum(rgbp)) * 255
                r["piece_aire_ajoutee_t2"] = round(float(add), 3)
                r["piece_lum20_t2"] = round(float(np.logical_and(both, dl >= 20).sum() / PPT ** 2), 3)
            if lv % 2 == 1 and lv >= 3:
                r["iou_epoque_prec"] = round(iou(m, masks[(lv - 2, pose)][0]), 3)
    d13 = {}
    for pose in POSES:
        m1 = masks[(1, pose)][0]
        m30 = masks[(30, pose)][0]
        m29 = masks[(29, pose)][0]
        ys, xs = np.nonzero(m1)
        bottom = (0.0, Y0 + (ys.max() + 1) / PPT)
        sn_o = iou_scale_norm(m1, m30, (0.0, 0.0))
        sn_b = iou_scale_norm(m1, m30, bottom)
        sn29 = iou_scale_norm(m1, m29, (0.0, 0.0))
        d13[pose] = {"iou_1_30": round(iou(m1, m30), 3), "iou_1_29": round(iou(m1, m29), 3),
                     "iou_norm_origine": round(sn_o[0], 3), "k_origine": round(sn_o[1], 2),
                     "iou_norm_bas": round(sn_b[0], 3), "k_bas": round(sn_b[1], 2),
                     "iou_norm_1_29_origine": round(sn29[0], 3)}
    return res, d13


def table_md(res, d13):
    out = []
    out.append("| Niv. | Ép. | Pose | Aire t² | L | O masses | O tout | IoU préc. | IoU époque préc. | Pièce : aire ajoutée t² (Δlum≥20 t²) | Lum p5/p50/p95 | Sat | Lueur : meilleure fenêtre 8×8 px hr, Δ lum (aire px) | Halo α |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for lv in LEVELS:
        for pose in POSES:
            r = res[(lv, pose)]
            piece = ""
            if "piece_aire_ajoutee_t2" in r:
                piece = "%.3f (%.3f)" % (r["piece_aire_ajoutee_t2"], r["piece_lum20_t2"])
            g = r["lueur"]
            gs = ("%+.0f (%d px)" % (g["best_delta"], g["area_px"]) if g and g["best_delta"] is not None
                  else ("aucune fenêtre 8×8 (%d px)" % g["area_px"] if g else "—"))
            h = r["halo"]
            out.append("| %d | %d | %s | %.3f | %.2f | %s | %.3f | %s | %s | %s | %.0f/%.0f/%.0f | %.2f | %s | %s |" % (
                lv, (lv + 1) // 2, pose, r["aire_t2"], r["L"],
                "%.3f" % r["O_masses"] if r["O_masses"] is not None else "—", r["O_tout"],
                "%.3f" % r["iou_prec"] if "iou_prec" in r else "—",
                "%.3f" % r["iou_epoque_prec"] if "iou_epoque_prec" in r else "—", piece,
                r["lum_p5"], r["lum_p50"], r["lum_p95"], r["sat"], gs, "%.2f" % h["alpha_max"] if h else "—"))
    out.append("")
    out.append("**D1-3 amendé (niveau 1 contre niveau 30, même pose, même origine)**")
    out.append("")
    out.append("| Pose | IoU(1, 30) | IoU(1, 29) | IoU normalisée (centre origine, k) | IoU normalisée (centre bas, k) | IoU norm. (1, 29) |")
    out.append("|---|---|---|---|---|---|")
    for pose in POSES:
        d = d13[pose]
        out.append("| %s | %.3f | %.3f | %.3f (k=%.2f) | %.3f (k=%.2f) | %.3f |" % (
            pose, d["iou_1_30"], d["iou_1_29"], d["iou_norm_origine"], d["k_origine"], d["iou_norm_bas"], d["k_bas"],
            d["iou_norm_1_29_origine"]))
    return "\n".join(out)


def bilan(res, d13):
    """Contrôles automatiques (aident le verdict du Directeur Créatif sans le remplacer) : liste des écarts."""
    bad = []
    for pose in POSES:
        prev_o = None
        for lv in LEVELS:
            r = res[(lv, pose)]
            e = (lv + 1) // 2
            tag = "N%d %s" % (lv, pose)
            om = r["O_masses"] if r["O_masses"] is not None else r["O_tout"]
            if om > 1.0 + 1e-9:
                bad.append("%s : O des masses %.3f > plafond 1,0" % (tag, om))
            if r["O_tout"] > 1.0 + 1e-9:
                bad.append("%s : O tout %.3f > 1,0 (tiges fines comprises)" % (tag, r["O_tout"]))
            if lv % 2 == 1:
                if prev_o is not None and om < prev_o - 1e-9:
                    bad.append("%s : O des masses %.3f < époque précédente %.3f (D1-2)" % (tag, om, prev_o))
                prev_o = om
                if "iou_epoque_prec" in r and r["iou_epoque_prec"] > 0.85:
                    bad.append("%s : IoU avec l'époque précédente %.3f > 0,85 (D1-2)" % (tag, r["iou_epoque_prec"]))
                if lv >= 3 and r.get("iou_prec", 0) > 0.85:
                    bad.append("%s : IoU avec le niveau pair précédent %.3f > 0,85 (D1-1)" % (tag, r["iou_prec"]))
            elif "piece_aire_ajoutee_t2" in r:
                if r["piece_aire_ajoutee_t2"] < 0.10 and r["piece_lum20_t2"] < 0.15:
                    bad.append("%s : pièce %.3f t² < 0,10 (et Δlum≥20 sur %.3f t² < 0,15) (D1-1)" % (
                        tag, r["piece_aire_ajoutee_t2"], r["piece_lum20_t2"]))
            if lv >= 3:
                tgt = wall_piece.L50_TARGET[e]
                if abs(r["lum_p50"] - tgt) > 10:
                    bad.append("%s : luminance médiane %.0f hors de %d ± 10 (§1.5)" % (tag, r["lum_p50"], tgt))
                if r["lum_p95"] > 240:
                    bad.append("%s : p95 %.0f > 240 (§1.5)" % (tag, r["lum_p95"]))
                if r["sat"] > 0.45:
                    bad.append("%s : saturation %.2f > 0,45 (§1.5)" % (tag, r["sat"]))
            if e >= 3 and lv >= 5:
                g = r["lueur"]
                if not g or g["best_delta"] is None or g["best_delta"] < 80:
                    bad.append("%s : lueur de jour insuffisante (%s) (D2-1)" % (tag, g and g["best_delta"]))
    for pose in POSES:
        d = d13[pose]
        if d["iou_1_30"] >= 0.50:
            bad.append("D1-3 %s : IoU(1, 30) %.3f >= 0,50" % (pose, d["iou_1_30"]))
        elif d["iou_1_30"] > 0.45:
            bad.append("D1-3 %s : IoU(1, 30) %.3f > cible 0,45" % (pose, d["iou_1_30"]))
        if max(d["iou_norm_origine"], d["iou_norm_bas"]) > 0.75:
            bad.append("D1-3 %s : IoU normalisée %.3f > 0,75 proposé" % (pose, max(d["iou_norm_origine"],
                                                                                   d["iou_norm_bas"])))
    return bad


def srgb_lin(v):
    v = v / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def gains(res):
    """Gain d'albédo conseillé par époque : le rendu est linéaire en albédo (hors bornes), on corrige donc
    EGAIN par lin(cible)/lin(mesure), mesure = médiane des niveaux de l'époque rendus en entier (≥ 3)."""
    print("| Ép. | L50 mesurée (impair, pair ; droit/isolé) | cible | EGAIN actuel | EGAIN conseillé |")
    print("|---|---|---|---|---|")
    for e in range(2, 16):
        vals = [res[(lv, p)]["lum_p50"] for lv in (2 * e - 1, 2 * e) for p in POSES]
        med = float(np.median(vals))
        tgt = wall_piece.L50_TARGET[e]
        g = wall_piece.EGAIN[e]
        print("| %d | %s | %d | %.2f | %.2f |" % (e, " ".join("%.0f" % v for v in vals), tgt, g,
                                                 g * srgb_lin(tgt) / srgb_lin(med)))


def table_compacte(res):
    """Une ligne par niveau, les deux poses côte à côte (droit/isolé)."""
    def f(lv, key, fmt="%.2f"):
        vals = []
        for pose in POSES:
            v = res[(lv, pose)].get(key)
            vals.append("—" if v is None else fmt % v)
        return "/".join(vals)
    out = ["| Niv | Ép | O masses | O tout | IoU préc. | IoU ép. préc. | pièce t² | L50 (cible) | p95 | lueur Δ8×8 | x | y bas |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for lv in LEVELS:
        e = (lv + 1) // 2
        rd = res[(lv, "droit")]
        gl = "/".join("—" if not res[(lv, p)]["lueur"] or res[(lv, p)]["lueur"]["best_delta"] is None else
                      "%+.0f" % res[(lv, p)]["lueur"]["best_delta"] for p in POSES)
        out.append("| %d | %d | %s | %s | %s | %s | %s | %s (%s) | %s | %s | %s | %s |" % (
            lv, e, f(lv, "O_masses"), f(lv, "O_tout"), f(lv, "iou_prec"), f(lv, "iou_epoque_prec"),
            f(lv, "piece_aire_ajoutee_t2", "%.3f"), f(lv, "lum_p50", "%.0f"),
            wall_piece.L50_TARGET[e] if lv >= 3 else "vanilla", f(lv, "lum_p95", "%.0f"), gl,
            "[%.2f ; %.2f]" % tuple(rd["x"]), "/".join("%.2f" % res[(lv, p)]["y"][1] for p in POSES)))
    return "\n".join(out)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--gains", action="store_true")
    ap.add_argument("--compact", action="store_true", help="table compacte (une ligne par niveau)")
    ap.add_argument("--md", default="")
    ap.add_argument("--json", default=os.path.join(WL.OUT, "mesures_d1.json"))
    a = ap.parse_args()
    db = WL.results()
    res, d13 = measure(db)
    if a.gains:
        gains(res)
        return
    md = table_compacte(res) if a.compact else table_md(res, d13)
    bad = bilan(res, d13)
    md += "\n\n**Écarts aux critères automatiques : %d**\n\n" % len(bad) + "\n".join("- " + x for x in bad)
    print(md)
    with open(a.json, "w", encoding="utf-8") as f:
        json.dump({"niveaux": {"%d-%s" % k: v for k, v in res.items()}, "d1_3": d13, "ecarts": bad}, f, indent=1,
                  sort_keys=True, ensure_ascii=False)
    if a.md:
        with open(a.md, "w", encoding="utf-8", newline="\n") as f:
            f.write(md + "\n")


if __name__ == "__main__":
    main()
