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
  - photométrie (source final, pose S) : luminance médiane, p95, saturation du corps, part émissive.
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


def photometry(layers):
    """Corps = couche principale opaque (alpha ≥ 0,5) ; émissif = lueur prémultipliée > 0,25."""
    rgb, a = D.compose_rgb(layers)
    m = a >= 0.5
    if not m.any():
        return None
    glow = np.zeros(m.shape)
    day = np.clip(rgb, 0, 1)
    for l in layers:
        if l["kind"] == "glow":
            g = D.to_canvas(l["img"], l["tl"])
            pm = g[..., :3] * g[..., 3:4]
            glow = np.maximum(glow, pm.max(-1))
            day = np.clip(day + pm, 0, 1)
    em = (glow > 0.25) & m
    # corps = couche principale opaque HORS zones émissives (la lumière est dans la lueur, D2-1 compare les deux)
    body = m & (glow <= 0.05)
    c = rgb[body if body.any() else m]
    lum = D.luminance(c) * 255
    mx, mn = c.max(1), c.min(1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    emis_l = float(np.median(D.luminance(day[em]) * 255)) if em.any() else None
    return {"L50": float(np.median(lum)), "L95": float(np.percentile(lum, 95)), "L05": float(np.percentile(lum, 5)),
            "sat": float(sat.mean()), "emis_part": float(em.sum() / m.sum()), "emis_px": int(em.sum()),
            "emis_L50": emis_l}


def run(source):
    masks, head_masks, socle_masks, phot = {}, {}, {}, {}
    for lv in range(1, 31):
        for pose in D.POSES:
            lays = D.level_layers(lv, pose, source)
            masks[(lv, pose)] = D.main_alpha(lays) >= 0.5
            head_masks[(lv, pose)] = D.main_alpha(lays, ("tete",)) >= 0.5
            socle_masks[(lv, pose)] = D.main_alpha(lays, ("socle",)) >= 0.5
            if source == "final":
                ph = photometry(lays)
                if pose == "S":
                    phot[lv] = ph
                # D2-1 : zone émissive visible de jour dans CHAQUE pose (pixels hr de lueur > 0,25 sur le corps,
                # luminance > médiane du corps + 80) ; on retient la pire pose
                phot.setdefault(("em", lv), {})[pose] = (ph["emis_px"], ph["emis_L50"], ph["L50"])
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
             "O_poses": {p: round(per[p]["O"], 3) for p in D.POSES}}
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
            r["photo"] = phot[lv]
        if ("em", lv) in phot:
            em = phot[("em", lv)]
            r["d21_px_min"] = min(v[0] for v in em.values())
            r["d21_pose_min"] = min(em, key=lambda p: em[p][0])
            r["d21_ok"] = all(v[0] >= 64 and v[1] is not None and v[1] >= v[2] + 80 for v in em.values())
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
    # O ne décroît jamais (niveaux impairs, puis tous les niveaux)
    Os = [res["levels"][2 * e - 1]["O"] for e in range(1, 16)]
    res["O_monotone_impairs"] = all(Os[i + 1] >= Os[i] - 1e-9 for i in range(14))
    res["O_sous_plafond"] = all(res["levels"][lv]["O"] <= G.O_PLAFOND + 1e-9 for lv in range(1, 31))
    return res, masks


def table(res):
    lines = ["| Niv. | Ép. | O (cible) | L | haut socle | pièce : ajout min 4 poses / visible 64 dir. (t²) | IoU préc. | IoU ép. suiv. | V | L50 (cible) | p95 | sat | émissif |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for lv in range(1, 31):
        r = res["levels"][lv]
        e = r["epoch"]
        ph = r.get("photo") or {}
        pa = ("%.2f / %.2f" % (r["piece_added_min"], r["piece_visible_64"])) if "piece_added_min" in r else ""
        ip = "%.2f" % r["iou_prev"] if "iou_prev" in r else ""
        ie = "%.2f" % res["epochs"][e] if (lv % 2 == 1 and e in res["epochs"]) else ""
        V = "%d %%" % round(100 * r["vide_V"]) if "vide_V" in r else ""
        lt = LUMA_TARGET.get(e)
        l50 = ("%.0f (%s)" % (ph["L50"], lt if lt else "-")) if ph else ""
        em = ("%.1f %%" % (100 * ph["emis_part"])) if ph and ph.get("emis_px") else ""
        if "d21_px_min" in r and e >= 3:
            em += " ; D2-1 %s (min %d px, %s)" % ("oui" if r["d21_ok"] else "NON", r["d21_px_min"], r["d21_pose_min"])
        lines.append("| %d | %d | %.2f (%.2f) | %.2f | %.2f | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            lv, e, r["O"], G.O_TARGET[e], r["L"], r["socle_top"], pa, ip, ie, V, l50,
            ("%.0f" % ph["L95"]) if ph else "", ("%.2f" % ph["sat"]) if ph else "", em))
    d = res["d13"]
    lines.append("")
    for tag, title in (("complet", "masque complet (socle + tête)"), ("tete", "tête seule (socle exclu)")):
        x = d[tag]
        lines.append("D1-3, %s : IoU(1, 30) = %.3f (%s) ; IoU normalisée = %.3f (%s) ; IoU(1, 29) = %.3f" % (
            title, x["iou"], ", ".join("%s %.3f" % (p, v) for p, v in x["iou_poses"].items()), x["iou_norm"],
            ", ".join("%s %.3f k=%.2f" % (p, v[0], v[1]) for p, v in x["iou_norm_poses"].items()), x["iou_29"]))
    lines.append("D1-3 retenu (le pire des deux) : IoU = %.3f (< 0,50, cible ≤ 0,45) ; IoU normalisée = %.3f "
                 "(proposition ≤ 0,75)" % (d["iou_retenu"], d["iou_norm_retenu"]))
    lines.append("O monotone (impairs) : %s ; O sous le plafond %.2f : %s" % (
        res["O_monotone_impairs"], G.O_PLAFOND, res["O_sous_plafond"]))
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
