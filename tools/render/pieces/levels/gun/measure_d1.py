"""Mesures D1 de la famille gun (OBJECTIFS D1-1 à D1-4, bible §1.4 ; D1-3 amendé, Q13).

    python tools/render/pieces/levels/gun/measure_d1.py [--source final|dry] [--json <fichier>] [--md]

Pour chaque niveau (1 à 30) et chaque pose de référence (tête « prepared » N, E, S, O + socle) :
  - masque = alpha ≥ 0,5 des couches principales socle + tête (ni ombre, ni lueur, ni halo) ;
  - O (masses : tiges de moins de 0,15 tuile exclues), L, aire ;
  - niveau pair : aire ajoutée hors du masque impair (minimum sur les poses ; visée ≥ 0,10 tuile²) et IoU
    avec le niveau impair ;
  - niveau impair : IoU avec le niveau pair précédent (maximum sur les poses ; ≤ 0,85) ;
  - époques consécutives : IoU(impair e, impair e+1) (maximum sur les poses ; ≤ 0,85) ;
  - D1-3 : IoU(niveau 1, niveau 30) (max sur les poses ; < 0,50, cible ≤ 0,45) et IoU normalisée en
    échelle = max sur k de IoU(niveau 1 agrandi de k autour de l'origine, niveau 30) (max sur les poses ;
    proposition ≤ 0,75) ; idem « tête seule » à titre d'information ;
  - vide V (époques 10 à 15) : part du masque du niveau 1 laissée vide par le niveau impair (min sur poses) ;
  - photométrie (source final) : luminance médiane, p95, saturation du corps, part émissive et contraste.
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
    c = rgb[m]
    lum = D.luminance(c) * 255
    mx, mn = c.max(1), c.min(1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    glow = np.zeros(m.shape)
    for l in layers:
        if l["kind"] == "glow":
            g = D.to_canvas(l["img"], l["tl"])
            glow = np.maximum(glow, (g[..., :3] * g[..., 3:4]).max(-1))
    em = (glow > 0.25) & m
    emis_l = None
    if em.any():
        # luminance perçue de jour = corps + lueur additive
        day = np.clip(rgb + 0, 0, 1)
        for l in layers:
            if l["kind"] == "glow":
                g = D.to_canvas(l["img"], l["tl"])
                day = np.clip(day + g[..., :3] * g[..., 3:4], 0, 1)
        emis_l = float(np.median(D.luminance(day[em]) * 255))
    return {"L50": float(np.median(lum)), "L95": float(np.percentile(lum, 95)), "L05": float(np.percentile(lum, 5)),
            "sat": float(sat.mean()), "emis_part": float(em.sum() / m.sum()), "emis_px": int(em.sum()),
            "emis_L50": emis_l}


def run(source):
    masks, head_masks, info, phot = {}, {}, {}, {}
    for lv in range(1, 31):
        for pose in D.POSES:
            lays = D.level_layers(lv, pose, source)
            masks[(lv, pose)] = D.main_alpha(lays) >= 0.5
            head_masks[(lv, pose)] = D.main_alpha(lays, ("tete",)) >= 0.5
            if source == "final" and pose == "S":
                phot[lv] = photometry(lays)
    res = {"levels": {}, "epochs": {}, "d13": {}}
    for lv in range(1, 31):
        e = (lv + 1) // 2
        per = {p: D.metrics(masks[(lv, p)]) for p in D.POSES}
        r = {"epoch": e, "O": max(per[p]["O"] for p in D.POSES), "O_brut": max(per[p]["O_brut"] for p in D.POSES),
             "L": max(per[p]["L"] for p in D.POSES), "area_S": per["S"]["area"],
             "bottom": max(per[p]["bottom"] for p in D.POSES),
             "x": [min(per[p]["left"] for p in D.POSES), max(per[p]["right"] for p in D.POSES)],
             "O_poses": {p: round(per[p]["O"], 3) for p in D.POSES}}
        if lv % 2 == 0:
            added = {p: float((masks[(lv, p)] & ~masks[(lv - 1, p)]).sum() / D.PPT ** 2) for p in D.POSES}
            r["piece_added_min"] = min(added.values())
            r["piece_added"] = added
            r["iou_prev"] = max(D.iou(masks[(lv, p)], masks[(lv - 1, p)]) for p in D.POSES)
        elif lv > 1:
            r["iou_prev"] = max(D.iou(masks[(lv, p)], masks[(lv - 1, p)]) for p in D.POSES)
        if e >= 10 and lv % 2 == 1:
            r["vide_V"] = min(float((masks[(1, p)] & ~masks[(lv, p)]).sum() / masks[(1, p)].sum()) for p in D.POSES)
        if lv in phot:
            r["photo"] = phot[lv]
        res["levels"][lv] = r
    for e in range(1, 15):
        a, b = 2 * e - 1, 2 * e + 1
        res["epochs"][e] = max(D.iou(masks[(a, p)], masks[(b, p)]) for p in D.POSES)
    # D1-3
    iou30 = {p: D.iou(masks[(1, p)], masks[(30, p)]) for p in D.POSES}
    sn = {p: D.iou_scale_norm(masks[(1, p)], masks[(30, p)]) for p in D.POSES}
    iou30h = {p: D.iou(head_masks[(1, p)], head_masks[(30, p)]) for p in D.POSES}
    snh = {p: D.iou_scale_norm(head_masks[(1, p)], head_masks[(30, p)]) for p in D.POSES}
    res["d13"] = {"iou": max(iou30.values()), "iou_poses": iou30,
                  "iou_norm": max(v[0] for v in sn.values()), "iou_norm_poses": {p: v for p, v in sn.items()},
                  "iou_tete": max(iou30h.values()), "iou_norm_tete": max(v[0] for v in snh.values())}
    # D1-3 sur le niveau impair 29 aussi (dernière silhouette)
    res["d13"]["iou_29"] = max(D.iou(masks[(1, p)], masks[(29, p)]) for p in D.POSES)
    return res, masks


def table(res):
    lines = ["| Niv. | Ép. | O (cible) | L | aire S (t²) | pièce ajoutée min (t²) | IoU préc. | IoU ép. suiv. | V | L50 (cible) | p95 | sat | émissif |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for lv in range(1, 31):
        r = res["levels"][lv]
        e = r["epoch"]
        ph = r.get("photo") or {}
        pa = "%.2f" % r["piece_added_min"] if "piece_added_min" in r else ""
        ip = "%.2f" % r["iou_prev"] if "iou_prev" in r else ""
        ie = "%.2f" % res["epochs"][e] if (lv % 2 == 1 and e in res["epochs"]) else ""
        V = "%d %%" % round(100 * r["vide_V"]) if "vide_V" in r else ""
        lt = LUMA_TARGET.get(e)
        l50 = ("%.0f (%s)" % (ph["L50"], lt if lt else "-")) if ph else ""
        em = ("%.1f %%" % (100 * ph["emis_part"])) if ph and ph.get("emis_px") else ""
        lines.append("| %d | %d | %.2f (%.2f) | %.2f | %.2f | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            lv, e, r["O"], G.O_TARGET[e], r["L"], r["area_S"], pa, ip, ie, V, l50,
            ("%.0f" % ph["L95"]) if ph else "", ("%.2f" % ph["sat"]) if ph else "", em))
    d = res["d13"]
    lines.append("")
    lines.append("D1-3 (niveau 1 contre niveau 30, max sur N/E/S/O) : IoU = %.3f (%s) ; IoU normalisée en échelle = %.3f (%s)"
                 % (d["iou"], ", ".join("%s %.3f" % (p, v) for p, v in d["iou_poses"].items()), d["iou_norm"],
                    ", ".join("%s %.3f (k=%.2f)" % (p, v[0], v[1]) for p, v in d["iou_norm_poses"].items())))
    lines.append("Tête seule (information) : IoU = %.3f ; IoU normalisée = %.3f. Niveau 29 : IoU = %.3f."
                 % (d["iou_tete"], d["iou_norm_tete"], d["iou_29"]))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default="final")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    res, _ = run(a.source)
    print(table(res))
    if a.json:
        with open(a.json, "w", encoding="utf-8", newline="\n") as f:
            json.dump(res, f, indent=1, sort_keys=True, default=float)


if __name__ == "__main__":
    main()
