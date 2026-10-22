"""Mesures D1 du mur (lot V3, famille « wall », phase 1), sur les aperçus rendus et le sprite vanilla.

    python -P tools/render/pieces/levels/wall/measure_wall.py [--compact] [--md fichier.md]

Python système (numpy + Pillow). Les couches viennent de wall_layers.py (aperçus de
tools/render/out/levels/wall/, niveau 1 = sprite vanilla image 0, niveau 2 = vanilla + pièce).

Définitions (bible docs/DESIGN_EPOQUES.md §1.4, OBJECTIFS D1 amendé par Q13) :
- toile en tuiles x ∈ [-2 ; 2], y ∈ [-2,5 ; 1,5], 64 px/tuile (hr), origine = position de l'entité ;
- MASQUE = alpha ≥ 0,5 (128/255) des couches principales composées (ni ombre, ni lueur, ni halo). Le mur
  n'a AUCUNE couche plate au sol (ni socle, ni integration_patch) : rien n'est exclu en plus (Q13 a) ;
- O (masses) = dépassement au-dessus du bord haut de l'emprise (y = -0,5) de la plus haute rangée dont un
  segment continu fait au moins 0,15 tuile (les tiges plus fines ne comptent pas, bible §1.4) ;
  O (tout) = même chose avec le plus haut pixel du masque ; enveloppe : O des niveaux impairs contre la
  table §4 (rang = époque) ;
- VIDE V (bible §1.4, §4) : part du masque du niveau 1 (même pose) que le niveau laisse transparente ;
- pièce paire (D1-1) : aire du masque pair hors du masque impair (≥ 0,10 tuile²), et mesure ROBUSTE : hors
  du masque impair DILATÉ de 1 px (les pixels d'anticrénelage du bord ne comptent plus ; cible de
  production 0,13 t², demande de vérification du 22/10) ;
- IoU entre niveaux successifs, entre époques consécutives (niveaux impairs, ≤ 0,85, D1-2) ;
- D1-3 amendé : IoU(niveau 1, niveau 30) < 0,50 (cible ≤ 0,45) ET IoU normalisée en échelle
  max_k IoU(niveau 1 agrandi de k, niveau 30), k de 0,50 à 2,50 par pas de 0,01, centre = origine de
  l'entité ou milieu du bas du masque du niveau 1 ; ET, plus sévère, le maximum sur l'échelle ET la
  translation (corrélation par FFT) : c'est la valeur à retenir pour étalonner le seuil (proposition 0,75) ;
- PROFIL DE JOINT (bible §2.5, visual_merge_group = 0) : en pose droite, haut et bas du masque dans les
  2 colonnes de pixels du bord de la tuile (x ∈ [-0,5 ; -0,469] et [0,469 ; 0,5]), contre le vanilla ;
- photométrie, DEUX définitions, toutes deux rapportées (vérification du 22/10, désaccord n° 3) :
  « vue » = TOUT le masque, couleur vue de jour (couche principale + lueur additive) : définition d'origine
  de la bible §1.5, c'est elle qui est contrôlée ; « corps » = masque hors zones émissives (lueur
  alpha ≥ 0,25), proposition de la passe 4c, NON validée. Luminance Rec. 709 p5/p50/p95 sur 255 (sRGB
  codé), saturation moyenne (max-min)/max ; part émissive du masque contre la proposition §1.6 ;
- lueur de jour (D2-1, §1.6) : fenêtres de 8 × 8 px hr ENTIÈREMENT émissives (les 64 px de lueur
  alpha ≥ 0,25) ; écart = luminance moyenne vue sur les 64 px moins la médiane vue du masque (≥ 80 exigé,
  ≥ 90 visé) ; on rapporte aussi la médiane du corps hors lueur comme référence ;
- halo (draw_as_light) : alpha maximal (I(N) = 0,05 + 0,02·N visé) et rayon = distance au CENTRE DE LA
  TUILE du plus lointain pixel d'alpha > 0,02 (≤ 1 tuile, §1.6).
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
# Bible §4, colonne « Mur » : O (tuiles) et V (part du masque du niveau 1) par rang d'époque.
O_ENV = {1: 0.25, 2: 0.30, 3: 0.36, 4: 0.41, 5: 0.46, 6: 0.52, 7: 0.57, 8: 0.62, 9: 0.68, 10: 0.73, 11: 0.79,
         12: 0.84, 13: 0.89, 14: 0.95, 15: 1.00}
V_MIN = {10: 0.04, 11: 0.08, 12: 0.12, 13: 0.17, 14: 0.21, 15: 0.25}
# Bible §1.6 (proposition ❔) : part émissive du corps 1 % (ép. 3), 3 % (5), 5 % (7), 7 % (10), 10 % (13),
# 12 à 15 % (15) ; interpolée linéairement entre ces points.
_EM = [(3, 0.01), (5, 0.03), (7, 0.05), (10, 0.07), (13, 0.10), (15, 0.15)]


def emissive_proposal(e):
    if e < 3:
        return 0.0
    for (a, va), (b, vb) in zip(_EM, _EM[1:]):
        if a <= e <= b:
            return va + (vb - va) * (e - a) / (b - a)
    return _EM[-1][1]


def place(img, shift):
    """Image (h, w, 4) posée sur la toile ; renvoie la toile RGBA (alpha droit)."""
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


def dilate1(m):
    """Dilatation de 1 px (voisinage de 8)."""
    out = m.copy()
    p = np.pad(m, 1)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out |= p[1 + dy:1 + dy + m.shape[0], 1 + dx:1 + dx + m.shape[1]]
    return out


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


def iou_scale_translate(m1, m30):
    """max sur k (0,50 à 2,50, pas 0,01) ET sur la translation entière (px) de IoU(m1 × k translaté, m30) :
    intersection pour toutes les translations par corrélation FFT (toile doublée, sans repliement)."""
    B = m30.astype(np.float64)
    nb = B.sum()
    FB = np.conj(np.fft.rfft2(B, s=(2 * H, 2 * W)))
    best = (0.0, 1.0, 0.0, 0.0)
    for k in np.arange(0.50, 2.505, 0.01):
        A = scaled(m1, k, (0.0, 0.0)).astype(np.float64)
        na = A.sum()
        if na == 0:
            continue
        corr = np.fft.irfft2(np.fft.rfft2(A, s=(2 * H, 2 * W)) * FB, s=(2 * H, 2 * W))
        i = int(np.argmax(corr))
        inter = corr.flat[i]
        v = inter / (na + nb - inter)
        if v > best[0]:
            dy, dx = np.unravel_index(i, corr.shape)
            dy = -(dy if dy < H else dy - 2 * H)      # translation qui amène A sur B
            dx = -(dx if dx < W else dx - 2 * W)
            best = (float(v), float(k), dx / PPT, dy / PPT)
    return best


def glow_stats(layers, seen_rgb, med_seen, med_body):
    """Lueur de jour (draw_as_glow), bible §1.6 / D2-1. Fenêtres de 8 × 8 px hr ENTIÈREMENT émissives (les
    64 px ont une lueur d'alpha ≥ 0,25) ; luminance moyenne VUE (principale + lueur) sur les 64 px, moins la
    médiane vue du masque (contrôlée) et moins la médiane du corps hors lueur (référence). On rapporte aussi la
    variante tolérante (au moins 48 px émissifs sur 64, moyenne sur les px émissifs) des passes 3-4."""
    g = additive(layers, "glow")
    gl = g.max(-1)
    zone = gl >= 0.25
    if not zone.any():
        return None
    L = lum(seen_rgb) * 255
    s = 8

    def integ(a):
        return np.pad(a, ((1, 0), (1, 0))).cumsum(0).cumsum(1)

    def box(c):
        return c[s:, s:] - c[:-s, s:] - c[s:, :-s] + c[:-s, :-s]

    cnt = box(integ(zone.astype(np.int64)))
    sm_all = box(integ(L))
    sm_zone = box(integ(np.where(zone, L, 0.0)))
    full = cnt == s * s
    tol = cnt >= 48
    best_full = float((sm_all[full] / (s * s)).max()) if full.any() else None
    best_tol = float((sm_zone[tol] / cnt[tol]).max()) if tol.any() else None
    return {"area_px": int(zone.sum()), "fenetres_pleines": int(full.sum()),
            "delta_plein": round(best_full - med_seen, 1) if best_full is not None else None,
            "delta_plein_corps": round(best_full - med_body, 1) if best_full is not None else None,
            "delta_48px": round(best_tol - med_seen, 1) if best_tol is not None else None}


def light_stats(layers):
    li = None
    for lay in layers:
        if lay["kind"] == "light":
            c = place(lay["img"], lay["shift"])
            li = c[..., 3] if li is None else np.maximum(li, c[..., 3])
    if li is None or li.max() <= 0:
        return None
    ys, xs = np.nonzero(li > 0.02)
    r = np.hypot(X0 + (xs + 0.5) / PPT, Y0 + (ys + 0.5) / PPT).max()
    ys10, xs10 = np.nonzero(li > 0.1 * li.max())
    r10 = np.hypot(X0 + (xs10 + 0.5) / PPT, Y0 + (ys10 + 0.5) / PPT).max()
    return {"alpha_max": round(float(li.max()), 3), "rayon_tuiles": round(float(r), 2),
            "rayon_10pc_tuiles": round(float(r10), 2)}


def joint_profile(m):
    """Haut et bas du masque dans les 2 colonnes de pixels de chaque bord de la tuile (pose droite)."""
    out = {}
    for side, cols in (("ouest", (int((-0.5 - X0) * PPT), int((-0.5 - X0) * PPT) + 2)),
                       ("est", (int((0.5 - X0) * PPT) - 2, int((0.5 - X0) * PPT)))):
        sub = m[:, cols[0]:cols[1]]
        rows = np.nonzero(sub.all(1))[0]          # rangées pleines sur les 2 colonnes
        if len(rows) == 0:
            out[side] = None
            continue
        out[side] = [round(to_tile_y(rows[0]), 3), round(to_tile_y(rows[-1] + 1), 3)]
    return out


def photometry(rgb, sel):
    l_ = lum(rgb[sel]) * 255
    mx, mn = rgb[sel].max(-1), rgb[sel].min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return (round(float(np.percentile(l_, 5)), 1), round(float(np.median(l_)), 1),
            round(float(np.percentile(l_, 95)), 1), round(float(sat.mean()), 3))


def measure(db):
    res = {}
    masks = {}
    for pose in POSES:
        for lv in LEVELS:
            layers = WL.level_layers(lv, pose, "hr", res_db=db)
            rgb, a = compose(layers, ("main",))
            m = a >= 0.5
            g = additive(layers, "glow")
            seen = np.clip(rgb + g, 0, 1)            # couleur vue de jour (rgb est déjà prémultiplié sur noir)
            masks[(lv, pose)] = (m, seen, a)
            ys, xs = np.nonzero(m)
            gmax = g.max(-1)
            body = m & (gmax < 0.25)
            if body.sum() < 0.3 * m.sum():
                body = m
            vp5, vp50, vp95, vsat = photometry(seen, m)
            cp5, cp50, cp95, csat = photometry(rgb, body)
            o_all, o_mass = o_values(m)
            r = {
                "part_emissive": round(float((m & (gmax >= 0.25)).sum() / max(1, m.sum())), 3),
                "aire_t2": round(m.sum() / PPT ** 2, 3),
                "x": [round(X0 + xs.min() / PPT, 3), round(X0 + (xs.max() + 1) / PPT, 3)],
                "y": [round(Y0 + ys.min() / PPT, 3), round(Y0 + (ys.max() + 1) / PPT, 3)],
                "L": round((xs.max() + 1 - xs.min()) / PPT, 3),
                "O_tout": round(o_all, 3), "O_masses": round(o_mass, 3) if o_mass is not None else None,
                "lum_p5": vp5, "lum_p50": vp50, "lum_p95": vp95, "sat": vsat,
                "corps_lum_p5": cp5, "corps_lum_p50": cp50, "corps_lum_p95": cp95, "corps_sat": csat,
            }
            if pose == "droit":
                r["joint"] = joint_profile(m)
            r["lueur"] = glow_stats(layers, seen, vp50, cp50)
            r["halo"] = light_stats(layers)
            res[(lv, pose)] = r
    for pose in POSES:
        m1 = masks[(1, pose)][0]
        for lv in LEVELS[1:]:
            m, seen, a = masks[(lv, pose)]
            mp, seenp, ap = masks[(lv - 1, pose)]
            r = res[(lv, pose)]
            r["iou_prec"] = round(iou(m, mp), 3)
            r["vide_V"] = round(float(np.logical_and(m1, ~m).sum() / m1.sum()), 3)
            if lv % 2 == 0:
                add = np.logical_and(m, ~mp).sum() / PPT ** 2
                add_r = np.logical_and(m, ~dilate1(mp)).sum() / PPT ** 2
                both = np.logical_and(m, mp)
                dl = np.abs(lum(seen) - lum(seenp)) * 255
                r["piece_aire_ajoutee_t2"] = round(float(add), 3)
                r["piece_aire_robuste_t2"] = round(float(add_r), 3)
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
        st30 = iou_scale_translate(m1, m30)
        st29 = iou_scale_translate(m1, m29)
        d13[pose] = {"iou_1_30": round(iou(m1, m30), 3), "iou_1_29": round(iou(m1, m29), 3),
                     "iou_norm_origine": round(sn_o[0], 3), "k_origine": round(sn_o[1], 2),
                     "iou_norm_bas": round(sn_b[0], 3), "k_bas": round(sn_b[1], 2),
                     "iou_norm_translation_1_30": round(st30[0], 3), "k_translation_1_30": round(st30[1], 2),
                     "dxdy_translation_1_30": [round(st30[2], 3), round(st30[3], 3)],
                     "iou_norm_translation_1_29": round(st29[0], 3), "k_translation_1_29": round(st29[1], 2)}
    return res, d13


def bilan(res, d13):
    """Contrôles automatiques (aident le verdict du Directeur Créatif sans le remplacer) : liste des écarts."""
    bad = []
    j1 = res[(1, "droit")]["joint"]
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
            if r["L"] > 1.0 + 1e-9:
                bad.append("%s : L %.3f > 1,00 (bible §1.4)" % (tag, r["L"]))
            if lv % 2 == 1:
                if prev_o is not None and om < prev_o - 1e-9:
                    bad.append("%s : O des masses %.3f < époque précédente %.3f (D1-2)" % (tag, om, prev_o))
                prev_o = om
                if lv >= 3 and om < O_ENV[e] - 0.03:
                    bad.append("%s : O des masses %.3f sous l'enveloppe §4 (%.2f)" % (tag, om, O_ENV[e]))
                if "iou_epoque_prec" in r and r["iou_epoque_prec"] > 0.85:
                    bad.append("%s : IoU avec l'époque précédente %.3f > 0,85 (D1-2)" % (tag, r["iou_epoque_prec"]))
                if lv >= 3 and r.get("iou_prec", 0) > 0.85:
                    bad.append("%s : IoU avec le niveau pair précédent %.3f > 0,85 (D1-1)" % (tag, r["iou_prec"]))
                if e in V_MIN and r["vide_V"] < V_MIN[e]:
                    bad.append("%s : vide V %.3f < %.2f (§4)" % (tag, r["vide_V"], V_MIN[e]))
            elif "piece_aire_ajoutee_t2" in r:
                if r["piece_aire_ajoutee_t2"] < 0.10 and r["piece_lum20_t2"] < 0.15:
                    bad.append("%s : pièce %.3f t² < 0,10 (et Δlum≥20 sur %.3f t² < 0,15) (D1-1)" % (
                        tag, r["piece_aire_ajoutee_t2"], r["piece_lum20_t2"]))
                if r["piece_aire_robuste_t2"] < 0.10:
                    bad.append("%s : pièce robuste (hors masque impair dilaté de 1 px) %.3f t² < 0,10 (D1-1)" % (
                        tag, r["piece_aire_robuste_t2"]))
            if lv >= 3:
                tgt = wall_piece.L50_TARGET[e]
                if abs(r["lum_p50"] - tgt) > 10:
                    bad.append("%s : luminance médiane vue %.0f hors de %d ± 10 (§1.5, tout le masque)" % (
                        tag, r["lum_p50"], tgt))
                if r["lum_p95"] > 240:
                    bad.append("%s : p95 %.0f > 240 (§1.5)" % (tag, r["lum_p95"]))
                if r["sat"] > 0.45:
                    bad.append("%s : saturation %.2f > 0,45 (§1.5)" % (tag, r["sat"]))
                prop = emissive_proposal(e)
                if r["part_emissive"] > prop + 0.03:
                    bad.append("%s : part émissive %.0f %% > proposition §1.6 (%.0f %%) + 3 points" % (
                        tag, 100 * r["part_emissive"], 100 * prop))
            if e >= 3 and lv >= 5:
                g = r["lueur"]
                if not g or g["delta_plein"] is None or g["delta_plein"] < 80:
                    bad.append("%s : lueur de jour insuffisante (fenêtre 8×8 pleine : %s) (D2-1)" % (
                        tag, g and g["delta_plein"]))
            h = r["halo"]
            if h and h["rayon_tuiles"] > 1.0 + 1e-9:
                bad.append("%s : rayon du halo %.2f > 1 tuile (§1.6)" % (tag, h["rayon_tuiles"]))
            if pose == "droit" and lv >= 2:
                for side in ("ouest", "est"):
                    jv, jr = r["joint"][side], j1[side]
                    if jv is None or abs(jv[0] - jr[0]) > 0.02 + 1e-9:
                        bad.append("%s : haut du joint %s %s, vanilla %.3f (± 0,02, bible §2.5)" % (
                            tag, side, jv and "%.3f" % jv[0], jr[0]))
    for pose in POSES:
        d = d13[pose]
        if d["iou_1_30"] >= 0.50:
            bad.append("D1-3 %s : IoU(1, 30) %.3f >= 0,50" % (pose, d["iou_1_30"]))
        elif d["iou_1_30"] > 0.45:
            bad.append("D1-3 %s : IoU(1, 30) %.3f > cible 0,45" % (pose, d["iou_1_30"]))
        worst = max(d["iou_norm_origine"], d["iou_norm_bas"], d["iou_norm_translation_1_30"])
        if worst > 0.75:
            bad.append("D1-3 %s : IoU normalisée %.3f > 0,75 proposé" % (pose, worst))
    return bad


def srgb_lin(v):
    v = v / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def gains(res):
    """Gain d'albédo conseillé par époque : le rendu est linéaire en albédo (hors bornes), on corrige donc
    EGAIN par lin(cible)/lin(mesure), mesure = médiane VUE des niveaux de l'époque rendus en entier (≥ 3)."""
    print("| Ép. | L50 vue (impair, pair ; droit/isolé) | cible | EGAIN actuel | EGAIN conseillé |")
    print("|---|---|---|---|---|")
    for e in range(2, 16):
        vals = [res[(lv, p)]["lum_p50"] for lv in (2 * e - 1, 2 * e) for p in POSES]
        med = float(np.median(vals))
        tgt = wall_piece.L50_TARGET[e]
        g = wall_piece.EGAIN[e]
        print("| %d | %s | %d | %.2f | %.2f |" % (e, " ".join("%.0f" % v for v in vals), tgt, g,
                                                 g * srgb_lin(tgt) / srgb_lin(med)))


def table_compacte(res, d13):
    """Une ligne par niveau, les deux poses côte à côte (droit/isolé)."""
    def f(lv, key, fmt="%.2f"):
        vals = []
        for pose in POSES:
            v = res[(lv, pose)].get(key)
            vals.append("—" if v is None else fmt % v)
        return "/".join(vals)

    def gl(lv, key):
        out = []
        for p in POSES:
            g = res[(lv, p)]["lueur"]
            out.append("—" if not g or g[key] is None else "%+.0f" % g[key])
        return "/".join(out)

    out = ["| Niv | Ép | O masses (env.) | O tout | V (min) | IoU préc. | IoU ép. préc. | pièce t² (robuste) | "
           "L50 vue / corps (cible) | p95 | sat | émissif (prop.) | lueur 8×8 pleine | halo α / rayon | joint O/E |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for lv in LEVELS:
        e = (lv + 1) // 2
        rd = res[(lv, "droit")]
        halo = "/".join("—" if not res[(lv, p)]["halo"] else "%.2f·%.2f" % (res[(lv, p)]["halo"]["alpha_max"],
                                                                            res[(lv, p)]["halo"]["rayon_tuiles"])
                        for p in POSES)
        jt = rd.get("joint") or {}
        jtxt = "/".join("—" if not jt.get(s) else "%.2f" % jt[s][0] for s in ("ouest", "est"))
        piece = ""
        if lv % 2 == 0 and lv >= 2:
            piece = "%s (%s)" % (f(lv, "piece_aire_ajoutee_t2", "%.3f"), f(lv, "piece_aire_robuste_t2", "%.3f"))
        out.append("| %d | %d | %s (%s) | %s | %s%s | %s | %s | %s | %s / %s (%s) | %s | %s | %s (%.0f %%) | %s | %s | %s |" % (
            lv, e, f(lv, "O_masses"), "%.2f" % O_ENV[e] if lv % 2 or lv == 1 else "—", f(lv, "O_tout"),
            f(lv, "vide_V"), " (%.2f)" % V_MIN[e] if e in V_MIN else "", f(lv, "iou_prec"), f(lv, "iou_epoque_prec"),
            piece, f(lv, "lum_p50", "%.0f"), f(lv, "corps_lum_p50", "%.0f"),
            wall_piece.L50_TARGET[e] if lv >= 3 else "vanilla", f(lv, "lum_p95", "%.0f"), f(lv, "sat"),
            f(lv, "part_emissive"), 100 * emissive_proposal(e), gl(lv, "delta_plein"), halo, jtxt))
    out.append("")
    out.append("| Pose | IoU(1, 30) | IoU(1, 29) | IoU norm. origine (k) | IoU norm. bas (k) | IoU norm. échelle + "
               "translation (1, 30) | idem (1, 29) |")
    out.append("|---|---|---|---|---|---|---|")
    for pose in POSES:
        d = d13[pose]
        out.append("| %s | %.3f | %.3f | %.3f (%.2f) | %.3f (%.2f) | %.3f (k %.2f, dx %+.2f, dy %+.2f) | %.3f (k %.2f) |" % (
            pose, d["iou_1_30"], d["iou_1_29"], d["iou_norm_origine"], d["k_origine"], d["iou_norm_bas"], d["k_bas"],
            d["iou_norm_translation_1_30"], d["k_translation_1_30"], d["dxdy_translation_1_30"][0],
            d["dxdy_translation_1_30"][1], d["iou_norm_translation_1_29"], d["k_translation_1_29"]))
    return "\n".join(out)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--gains", action="store_true")
    ap.add_argument("--compact", action="store_true", help="(conservé : la table est toujours compacte)")
    ap.add_argument("--md", default="")
    ap.add_argument("--json", default=os.path.join(WL.OUT, "mesures_d1.json"))
    a = ap.parse_args()
    db = WL.results()
    res, d13 = measure(db)
    if a.gains:
        gains(res)
        return
    md = table_compacte(res, d13)
    bad = bilan(res, d13)
    md += "\n\n**Écarts aux critères automatiques : %d**\n\n" % len(bad) + "\n".join("- " + x for x in bad)
    print(md)
    with open(a.json, "w", encoding="utf-8") as f:
        json.dump({"niveaux": {"%d-%s" % k: v for k, v in res.items()}, "d1_3": d13, "ecarts": bad,
                   "definitions": __doc__}, f, indent=1, sort_keys=True, ensure_ascii=False)
    if a.md:
        with open(a.md, "w", encoding="utf-8", newline="\n") as f:
            f.write(md + "\n")


if __name__ == "__main__":
    main()
