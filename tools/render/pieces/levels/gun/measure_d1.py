"""Mesures D1 de la famille gun (OBJECTIFS D1-1 à D1-4, bible §1.4 ; D1-3 amendé, Q13).

    python tools/render/pieces/levels/gun/measure_d1.py [--source final|dry] [--json <fichier>]

Sources : « final » = aperçus Cycles (render_gun.py) ; « dry » = silhouettes géométriques exactes (geo.py).
Pour chaque niveau (1 à 30) et chaque pose de référence (tête « prepared » N, E, S, O + socle) :
  - masque = alpha ≥ 0,5 des couches principales socle + tête (ni ombre, ni lueur, ni halo, bible §1.4) ;
  - O (masses : structures de moins de 0,15 tuile de large exclues), L, aire, bas, haut du socle à l'écran ;
  - niveau pair : aire ajoutée hors du masque impair (minimum sur les 4 poses ; visée ≥ 0,10 tuile²), IoU avec
    le niveau impair, et aire de la pièce JAMAIS couverte par la tête sur ses 64 directions (balayage de
    geo.py : F46 recalculé à chaque époque, bible §1.7) ;
  - niveau impair : IoU avec le niveau pair précédent (maximum sur les poses ; ≤ 0,85) ;
  - époques consécutives : IoU(impair e, impair e+1) (maximum sur les poses ; ≤ 0,85) ;
  - D1-3 : IoU(niveau 1, niveau 30) (max sur les poses ; < 0,50, cible ≤ 0,45) et IoU normalisée en échelle
    = max sur k de IoU(niveau 1 agrandi de k autour de l'origine, niveau 30) (max sur les poses ; proposition
    ≤ 0,75). Masque complet (le socle d'une tourelle est un volume de 0,4 tuile, pas une couche plate) ET
    masque « tête seule » (lecture stricte de « socle exclu de la silhouette », Q13) : on retient le PIRE ;
  - vide V (époques 10 à 15) : part du masque du niveau 1 laissée vide par le niveau impair (min sur poses) ;
  - O PAR POSE (reprise 4) : O_p non décroissant d'une époque à l'autre pour CHAQUE pose (pas seulement le maximum),
    et O « masses 2D » (ouverture carrée de 10 px : un anneau fin horizontal ne porte pas le sommet), information ;
  - photométrie (source final, LES 4 POSES, reprise 4 ; avant : pose S seule, ce que le tableau ne disait pas) :
    luminance médiane (L50) par pose, p95 maximal sur les poses, saturation maximale, part émissive ;
  - D2-1 (reprise 4, bible §1.6 : « chaque zone fait au moins 8 × 8 px hr ») : lueur VISIBLE (la lueur du socle
    est cachée par la couche principale de la tête, ordre lower-object puis object), seuil 0,25 (prémultipliée),
    puis ouverture morphologique 8 × 8 : il faut au moins un bloc plein de 8 × 8 px hr dans CHAQUE pose, de
    luminance médiane ≥ médiane du corps + 80. Avant : total des pixels ≥ 64, ce qui laissait passer des fentes
    de 2 à 3 px (F37).
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import d1lib as D  # noqa: E402
import gun as G  # noqa: E402

LUMA_TARGET = {1: None, 2: 52, 3: 58, 4: 60, 5: 42, 6: 64, 7: 55, 8: 60, 9: 56, 10: 82, 11: 100, 12: 60, 13: 92,
               14: 88, 15: 108}


def visible_glow(layers):
    """Lueur visible (prémultipliée, maximum des canaux) dans l'ordre de dessin du moteur : une couche principale
    dessinée APRÈS une lueur la cache (la tête, couche object, passe sur la lueur du socle, lower-object)."""
    g = np.zeros((D.H, D.W))
    for l in layers:
        if l["kind"] == "main":
            g = g * (1 - D.to_canvas(l["img"], l["tl"])[..., 3])
        elif l["kind"] == "glow":
            c = D.to_canvas(l["img"], l["tl"])
            g = np.maximum(g, (c[..., :3] * c[..., 3:4]).max(-1))
    return g


def open_square(mask, n=8):
    """Ouverture morphologique par un carré n × n : union des fenêtres n × n entièrement vraies."""
    m = mask.astype(np.int32)
    ii = np.zeros((m.shape[0] + 1, m.shape[1] + 1), np.int64)
    ii[1:, 1:] = m.cumsum(0).cumsum(1)
    full = (ii[n:, n:] - ii[:-n, n:] - ii[n:, :-n] + ii[:-n, :-n]) == n * n   # coin haut-gauche (i, j)
    f = np.zeros((m.shape[0] + 1, m.shape[1] + 1), np.int64)
    f[1:full.shape[0] + 1, 1:full.shape[1] + 1] = full.cumsum(0).cumsum(1)
    Hm, Wm = mask.shape
    ys, xs = np.mgrid[0:Hm, 0:Wm]
    y0, x0 = np.maximum(0, ys - n + 1), np.maximum(0, xs - n + 1)
    y1, x1 = np.minimum(ys, full.shape[0] - 1), np.minimum(xs, full.shape[1] - 1)
    ok = (y1 >= y0) & (x1 >= x0)
    y1c, x1c = np.maximum(y1, y0), np.maximum(x1, x0)
    cnt = f[y1c + 1, x1c + 1] - f[y0, x1c + 1] - f[y1c + 1, x0] + f[y0, x0]
    return ok & (cnt > 0)


def o2d(mask, n=10):
    """O des masses avec une ouverture CARRÉE de n px (information) : un anneau ou une barre fine horizontale ne
    porte plus le sommet (vérification adverse, mineur 6 : l'anneau-halo de l'époque 15)."""
    rows = np.nonzero(open_square(mask, n).any(1))[0]
    return float((D.OY - rows.min()) / D.PPT - 1.0) if len(rows) else None


def photometry(layers):
    """Corps = couche principale opaque (alpha ≥ 0,5) hors lueur visible ; émissif = lueur visible > 0,25.
    D2-1 : blocs pleins de 8 × 8 px hr de lueur visible > 0,25 (ouverture), luminance de jour ≥ L50 du corps + 80."""
    rgb, a = D.compose_rgb(layers)
    m = a >= 0.5
    if not m.any():
        return None
    gv = visible_glow(layers)
    day = np.clip(rgb, 0, 1)
    for l in layers:
        if l["kind"] == "glow":
            g = D.to_canvas(l["img"], l["tl"])
            day = np.clip(day + g[..., :3] * g[..., 3:4], 0, 1)
    em = gv > 0.25
    body = m & (gv <= 0.05)
    c = rgb[body if body.any() else m]
    lum = D.luminance(c) * 255
    mx, mn = c.max(1), c.min(1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    L50 = float(np.median(lum))
    blk = open_square(em, 8)
    blk_l50 = float(np.median(D.luminance(day[blk]) * 255)) if blk.any() else None
    side = 0   # côté du plus grand carré plein de lueur (information : « 6 × 6 au mieux »)
    for n in (16, 12, 10, 8, 6, 4, 2):
        if open_square(em, n).any():
            side = n
            break
    return {"L50": L50, "L95": float(np.percentile(lum, 95)), "L05": float(np.percentile(lum, 5)),
            "L99": float(np.percentile(lum, 99)), "px_ge_245": int((lum >= 245).sum()),
            "sat": float(sat.mean()), "emis_part": float((em & m).sum() / m.sum()), "emis_px": int(em.sum()),
            "d21_block_px": int(blk.sum()), "d21_block_L50": blk_l50, "d21_carre_max": side,
            "d21_ok": bool(blk.any() and blk_l50 is not None and blk_l50 >= L50 + 80)}


def run(source):
    masks, head_masks, socle_masks, phot = {}, {}, {}, {}
    for lv in range(1, 31):
        for pose in D.POSES:
            lays = D.level_layers(lv, pose, source)
            masks[(lv, pose)] = D.main_alpha(lays) >= 0.5
            head_masks[(lv, pose)] = D.main_alpha(lays, ("tete",)) >= 0.5
            socle_masks[(lv, pose)] = D.main_alpha(lays, ("socle",)) >= 0.5
            if source == "final":
                phot.setdefault(lv, {})[pose] = photometry(lays)
    sweeps = {e: D.head_sweep(e) >= 0.5 for e in range(1, 16)}
    res = {"source": source, "levels": {}, "epochs": {}, "d13": {}}
    for lv in range(1, 31):
        e = (lv + 1) // 2
        per = {p: D.metrics(masks[(lv, p)]) for p in D.POSES}
        sm = D.metrics(socle_masks[(lv, "N")])
        r = {"epoch": e, "O": max(per[p]["O"] for p in D.POSES), "O_brut": max(per[p]["O_brut"] for p in D.POSES),
             "L": max(per[p]["L"] for p in D.POSES), "area_S": per["S"]["area"],
             "bottom": max(per[p]["bottom"] for p in D.POSES),
             "x": [min(per[p]["left"] for p in D.POSES), max(per[p]["right"] for p in D.POSES)],
             "top": min(per[p]["top"] for p in D.POSES),
             "socle_top": sm["top"], "socle_x": [sm["left"], sm["right"]], "socle_bottom": sm["bottom"],
             "O_poses": {p: round(per[p]["O"], 3) for p in D.POSES},
             "O_masses_2D": max(o2d(masks[(lv, p)]) for p in D.POSES)}
        if lv % 2 == 0:
            added = {p: float((masks[(lv, p)] & ~masks[(lv - 1, p)]).sum() / D.PPT ** 2) for p in D.POSES}
            r["piece_added_min"] = min(added.values())
            r["piece_added"] = added
            r["iou_prev"] = max(D.iou(masks[(lv, p)], masks[(lv - 1, p)]) for p in D.POSES)
            piece_px = socle_masks[(lv, "N")] & ~socle_masks[(lv - 1, "N")]
            r["piece_area"] = float(piece_px.sum() / D.PPT ** 2)
            r["piece_visible_64"] = float((piece_px & ~sweeps[e]).sum() / D.PPT ** 2)
        elif lv > 1:
            r["iou_prev"] = max(D.iou(masks[(lv, p)], masks[(lv - 1, p)]) for p in D.POSES)
        if e >= 10 and lv % 2 == 1:
            r["vide_V"] = min(float((masks[(1, p)] & ~masks[(lv, p)]).sum() / masks[(1, p)].sum()) for p in D.POSES)
        if lv in phot:
            ph = phot[lv]
            r["photo_poses"] = ph
            r["photo"] = {"L50_poses": {p: ph[p]["L50"] for p in D.POSES},
                          "L50_min": min(ph[p]["L50"] for p in D.POSES), "L50_max": max(ph[p]["L50"] for p in D.POSES),
                          "L95_max": max(ph[p]["L95"] for p in D.POSES),
                          "L95_pose": max(D.POSES, key=lambda p: ph[p]["L95"]),
                          "px_ge_245_max": max(ph[p]["px_ge_245"] for p in D.POSES),
                          "sat_max": max(ph[p]["sat"] for p in D.POSES),
                          "emis_min": min(ph[p]["emis_part"] for p in D.POSES),
                          "emis_max": max(ph[p]["emis_part"] for p in D.POSES)}
            if e >= 3:
                r["d21_ok"] = all(ph[p]["d21_ok"] for p in D.POSES)
                r["d21_poses_ok"] = [p for p in D.POSES if ph[p]["d21_ok"]]
                r["d21_carre_min"] = min(ph[p]["d21_carre_max"] for p in D.POSES)
        res["levels"][lv] = r
    for e in range(1, 15):
        a, b = 2 * e - 1, 2 * e + 1
        res["epochs"][e] = max(D.iou(masks[(a, p)], masks[(b, p)]) for p in D.POSES)
    # D1-3 : niveau 1 contre niveau 30 (et contre 29, dernière silhouette d'époque)
    d = {}
    for tag, mk in (("complet", masks), ("tete", head_masks)):
        io = {p: D.iou(mk[(1, p)], mk[(30, p)]) for p in D.POSES}
        sn = {p: D.iou_scale_norm(mk[(1, p)], mk[(30, p)]) for p in D.POSES}
        d[tag] = {"iou": max(io.values()), "iou_poses": io, "iou_norm": max(v[0] for v in sn.values()),
                  "iou_norm_poses": {p: [v[0], v[1]] for p, v in sn.items()},
                  "iou_29": max(D.iou(mk[(1, p)], mk[(29, p)]) for p in D.POSES)}
    d["iou_retenu"] = max(d["complet"]["iou"], d["tete"]["iou"])
    d["iou_norm_retenu"] = max(d["complet"]["iou_norm"], d["tete"]["iou_norm"])
    res["d13"] = d
    # O ne décroît jamais (niveaux impairs) : sur le maximum ET pose par pose (reprise 4)
    Os = [res["levels"][2 * e - 1]["O"] for e in range(1, 16)]
    res["O_monotone_impairs"] = all(Os[i + 1] >= Os[i] - 1e-9 for i in range(14))
    rec = []
    for p in D.POSES:
        for e in range(2, 16):
            a, b = res["levels"][2 * e - 3]["O_poses"][p], res["levels"][2 * e - 1]["O_poses"][p]
            if b < a - 1e-9:
                rec.append("ép. %d pose %s : %.2f < %.2f" % (e, p, b, a))
    res["O_monotone_par_pose"] = not rec
    res["O_reculs_par_pose"] = rec
    res["O_sous_plafond"] = all(res["levels"][lv]["O"] <= G.O_PLAFOND + 1e-9 for lv in range(1, 31))
    return res, masks


def table(res):
    P = G.load_params()
    lines = ["Tableau 1 : géométrie (masque = alpha ≥ 0,5 des couches principales socle + tête ; O, L en tuiles ; "
             "pièce en tuiles²)", "",
             "| Niv. | Ép. | O max (cible) | O par pose N / E / S / O | O 2D | L | haut socle | pièce : ajout min 4 poses / visible 64 dir. | IoU préc. | IoU ép. suiv. | V |",
             "|---|---|---|---|---|---|---|---|---|---|---|"]
    for lv in range(1, 31):
        r = res["levels"][lv]
        e = r["epoch"]
        pa = ("%.2f / %.2f" % (r["piece_added_min"], r["piece_visible_64"])) if "piece_added_min" in r else ""
        ip = "%.2f" % r["iou_prev"] if "iou_prev" in r else ""
        ie = "%.2f" % res["epochs"][e] if (lv % 2 == 1 and e in res["epochs"]) else ""
        V = "%d %%" % round(100 * r["vide_V"]) if "vide_V" in r else ""
        op = " / ".join("%.2f" % r["O_poses"][p] for p in D.POSES)
        lines.append("| %d | %d | %.2f (%.2f) | %s | %.2f | %.2f | %.2f | %s | %s | %s | %s |" % (
            lv, e, r["O"], G.O_TARGET[e], op, r["O_masses_2D"], r["L"], r["socle_top"], pa, ip, ie, V))
    if any("photo" in res["levels"][lv] for lv in range(1, 31)):
        lines += ["", "Tableau 2 : photométrie sur les 4 poses (corps = couche principale opaque hors lueur ; "
                  "luminances sRGB sur 255 ; D2-1 = bloc plein de 8 × 8 px hr de lueur visible dans chaque pose)", "",
                  "| Niv. | Ép. | L50 N / E / S / O (cible ± 10) | p95 max (pose) | px ≥ 245 max | sat max | émissif min-max | D2-1 (poses OK ; plus grand carré) |",
                  "|---|---|---|---|---|---|---|---|"]
        for lv in range(1, 31):
            r = res["levels"][lv]
            e = r["epoch"]
            ph = r.get("photo")
            if not ph:
                continue
            lt = LUMA_TARGET.get(e)
            l50 = " / ".join("%.0f" % ph["L50_poses"][p] for p in D.POSES) + (" (%s)" % (lt if lt else "-"))
            em = "%.1f-%.1f %%" % (100 * ph["emis_min"], 100 * ph["emis_max"]) if ph["emis_max"] > 0 else ""
            d21 = ""
            if "d21_ok" in r:
                d21 = "%s (%s ; %d px)" % ("oui" if r["d21_ok"] else "NON", ",".join(r["d21_poses_ok"]) or "aucune",
                                           r["d21_carre_min"])
            lines.append("| %d | %d | %s | %.0f (%s) | %d | %.2f | %s | %s |" % (
                lv, e, l50, ph["L95_max"], ph["L95_pose"], ph["px_ge_245_max"], ph["sat_max"], em, d21))
    d = res["d13"]
    lines.append("")
    for tag, title in (("complet", "masque complet (socle + tête)"), ("tete", "tête seule (socle exclu)")):
        x = d[tag]
        lines.append("D1-3, %s : IoU(1, 30) = %.3f (%s) ; IoU normalisée = %.3f (%s) ; IoU(1, 29) = %.3f" % (
            title, x["iou"], ", ".join("%s %.3f" % (p, v) for p, v in x["iou_poses"].items()), x["iou_norm"],
            ", ".join("%s %.3f k=%.2f" % (p, v[0], v[1]) for p, v in x["iou_norm_poses"].items()), x["iou_29"]))
    lines.append("D1-3 retenu (le pire des deux) : IoU = %.3f (< 0,50, cible ≤ 0,45) ; IoU normalisée = %.3f "
                 "(proposition ≤ 0,75, seuil NON étalonné)" % (d["iou_retenu"], d["iou_norm_retenu"]))
    lines.append("O monotone (maximum des poses, impairs) : %s ; O monotone POSE PAR POSE : %s%s ; O sous le plafond "
                 "%.2f : %s" % (res["O_monotone_impairs"], res["O_monotone_par_pose"],
                                (" (" + " ; ".join(res["O_reculs_par_pose"]) + ")") if res["O_reculs_par_pose"] else "",
                                G.O_PLAFOND, res["O_sous_plafond"]))
    lines.append("Hauteur d'axe des canons zg (unités Blender) : " + ", ".join(
        "é%d %.3f" % (e, P["zg"][e]) for e in range(2, 16)))
    return "\n".join(lines)


def check_geo(final_masks):
    """Accord entre silhouettes géométriques (geo.py) et aperçus Cycles : IoU par niveau, pire pose."""
    out = {}
    for lv in range(2, 31):
        out[lv] = min(D.iou(D.main_alpha(D.level_layers(lv, p, "dry")) >= 0.5, final_masks[(lv, p)]) for p in D.POSES)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default="final")
    ap.add_argument("--json", default="")
    ap.add_argument("--check-geo", action="store_true")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    res, masks = run(a.source)
    print(table(res))
    if a.check_geo and a.source == "final":
        cg = check_geo(masks)
        res["accord_geo_cycles"] = cg
        worst = min(cg, key=cg.get)
        print("Accord silhouettes géométriques / Cycles : IoU min %.4f (niveau %d), médiane %.4f" % (
            cg[worst], worst, float(np.median(list(cg.values())))))
    if a.json:
        with open(a.json, "w", encoding="utf-8", newline="\n") as f:
            json.dump(res, f, indent=1, sort_keys=True, default=float)


if __name__ == "__main__":
    main()
