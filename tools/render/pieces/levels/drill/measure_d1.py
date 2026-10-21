"""Mesures D1 (et D2-1, palette) des niveaux de la foreuse électrique (lot V3, phase 1), hors moteur.

    python -P tools/render/pieces/levels/drill/measure_d1.py [--quick] [--out <fichier .json>]

Protocole (bible §1.4, OBJECTIFS D1, amendement Q13), toutes poses de référence N, E, S, O, image 0 :
- masque = alpha >= 0,5 de la couche PRINCIPALE seule (ni ombre, ni lueur, ni halo, ni integration_patch :
  aucune couche plate au sol) ; 64 px par tuile, même origine (position de l'entité) ;
- masses = masque après ouverture morphologique par un carré de 10 px (0,156 tuile) : les tiges fines
  (< 0,15 tuile : mâts, antennes, haubans, garde-corps) ne comptent ni dans O ni dans L ;
- O = dépassement du sommet des masses au-dessus du bord haut de l'emprise (y = -1,5) ; O_tige = idem
  avec le masque complet ; L = largeur des masses ;
- niveau pair : aire ajoutée = |M(pair) \\ M(impair)| (cible >= 0,10 t²) ; IoU(pair, impair) ;
- niveau impair : IoU avec le niveau pair précédent (<= 0,85) et avec l'impair précédent (époques
  consécutives, <= 0,85) ; V = part du masque du niveau 1 laissée vide (bible §4) ;
- D1-3 : IoU(niveau 1, niveau 30) < 0,50 (cible <= 0,45), et IoU normalisée en échelle = max sur k
  (0,50 à 3,00, pas 0,01) de IoU(niveau 1 agrandi de k autour de la position de l'entité, niveau 30)
  (proposition <= 0,75) ; maximum sur les 4 poses ;
- photométrie de la couche principale (pixels d'alpha >= 0,99, sRGB) : luminance médiane, p95,
  saturation moyenne (bible §1.5) ; lueur de jour (D2-1) : part émissive du corps, plus grande zone
  connexe (px hr, cible >= 64 = 8 × 8), contraste de luminance (cible >= +80/255).
Sortie : tableau texte et JSON (par défaut tools/render/out/levels/drill/mesures_d1.json).
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import levels_io as IO  # noqa: E402

LUMA = np.array([0.2126, 0.7152, 0.0722])
# bible §4 (foreuse) : O / L / V par rang d'époque ; §1.5 : luminance médiane cible du corps
O_RANK = [0.38, 0.47, 0.55, 0.64, 0.73, 0.82, 0.90, 0.99, 1.08, 1.16, 1.25, 1.34, 1.43, 1.51, 1.60]
L_RANK = [2.94, 2.96, 2.98, 3.00, 3.01, 3.03, 3.05, 3.07, 3.09, 3.11, 3.13, 3.14, 3.16, 3.18, 3.20]
V_RANK = [0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 7, 10, 13, 17, 20]
LUM_TARGET = [50, 52, 58, 60, 42, 64, 55, 60, 56, 82, 100, 60, 92, 88, 108]
O_CEIL = 1.60
OPEN_PX = 10


def opening(m, k=OPEN_PX):
    """Ouverture binaire par un carré k × k (érosion puis dilatation), par sommes cumulées."""
    def box_all(a):
        # vrai si tout le carré k×k dont (y, x) est le coin haut-gauche est dans a
        c = np.pad(a.astype(np.int32), ((1, 0), (1, 0))).cumsum(0).cumsum(1)
        h, w = a.shape
        s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
        out = np.zeros_like(a)
        out[:h - k + 1, :w - k + 1] = s == k * k
        return out
    er = box_all(m)
    # dilatation : chaque coin retenu recouvre son carré
    c = np.pad(er.astype(np.int32), ((k, 0), (k, 0))).cumsum(0).cumsum(1)
    h, w = m.shape
    s = c[k:k + h, k:k + w] - c[0:h, k:k + w] - c[k:k + h, 0:w] + c[0:h, 0:w]
    return s > 0


def bbox(m):
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    ox, oy = IO.ORIGIN
    return ((xs.min() - ox) / 64.0, (xs.max() + 1 - ox) / 64.0, (ys.min() - oy) / 64.0, (ys.max() + 1 - oy) / 64.0)


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / u) if u else 0.0


def scaled(m, k):
    """Masque agrandi de k autour de l'origine (plus proche voisin, échantillonnage inverse)."""
    ox, oy = IO.ORIGIN
    yy, xx = np.mgrid[0:IO.H, 0:IO.W]
    sx = np.floor((xx + 0.5 - ox) / k + ox).astype(int)
    sy = np.floor((yy + 0.5 - oy) / k + oy).astype(int)
    ok = (sx >= 0) & (sx < IO.W) & (sy >= 0) & (sy < IO.H)
    out = np.zeros_like(m)
    out[ok] = m[sy[ok], sx[ok]]
    return out


def norm_iou(m1, m30):
    best, kb = 0.0, 1.0
    for k in np.arange(0.50, 3.0001, 0.01):
        v = iou(scaled(m1, k), m30)
        if v > best:
            best, kb = v, float(k)
    return best, kb


def components_max(m):
    """Taille de la plus grande composante connexe (4-voisinage), sans scipy."""
    seen = np.zeros_like(m)
    best = 0
    H, W = m.shape
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        if seen[y, x]:
            continue
        stack = [(y, x)]
        seen[y, x] = True
        n = 0
        while stack:
            cy, cx = stack.pop()
            n += 1
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        best = max(best, n)
    return best


def photometry(main, glow):
    a = main[..., 3]
    m = a >= 0.99
    if glow is not None:
        # corps = hors des zones émissives (bible §1.5 : règles de palette du CORPS ; les émissifs vivent
        # dans leurs couches). Aperçus rapides : pas de couche de lueur, émissifs comptés dans le corps.
        gpm = glow[..., :3] * glow[..., 3:4]
        m = m & (gpm.max(-1) < 0.05)
    rgb = main[..., :3]
    L = rgb @ LUMA * 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0)
    out = {"lum_p50": float(np.median(L[m])), "lum_p95": float(np.percentile(L[m], 95)),
           "sat": float(sat[m].mean())}
    if glow is not None:
        pm = glow[..., :3] * glow[..., 3:4]
        gm = (pm.max(-1) >= 0.25) & (a >= 0.5)
        out["glow_frac"] = float(gm.sum() / max(1, (a >= 0.5).sum()))
        out["glow_zone_px"] = int(components_max(gm)) if gm.any() else 0
        if gm.any():
            day = np.clip(rgb + pm, 0, 1)
            out["glow_contrast"] = float(np.median((day @ LUMA * 255)[gm]) - out["lum_p50"])
    return out


def measure(spec, quick=False, levels=range(1, 31)):
    masks, res = {}, {"levels": {}, "quick": quick}
    for lvl in levels:
        for d in IO.DIRS:
            lay = IO.level_layers(spec, lvl, d, quick=quick)
            if lay is None or lay["main"] is None:
                continue
            m = lay["main"][..., 3] >= 0.5
            masks[(lvl, d)] = m
            ms = opening(m)
            bb, bbm = bbox(m), bbox(ms)
            r = {"area": float(m.sum() / 4096.0), "O": -bbm[2] - 1.5, "O_tige": -bb[2] - 1.5, "L": bbm[1] - bbm[0],
                 "x": [bb[0], bb[1]], "y": [bb[2], bb[3]],
                 "cover": float(m[IO.ORIGIN[1] - 96:IO.ORIGIN[1] + 96, IO.ORIGIN[0] - 96:IO.ORIGIN[0] + 96].sum() / (192 * 192)),
                 "below": bb[3] - 1.5, "side_l": -1.5 - bb[0], "side_r": bb[1] - 1.5}
            r.update(photometry(lay["main"], lay["glow"]))
            res["levels"].setdefault("L%02d" % lvl, {})[d] = r
    # relations entre niveaux
    for lvl in levels:
        key = "L%02d" % lvl
        if key not in res["levels"]:
            continue
        for d in IO.DIRS:
            if (lvl, d) not in masks:
                continue
            r = res["levels"][key][d]
            m = masks[(lvl, d)]
            if lvl > 1 and (lvl - 1, d) in masks:
                prev = masks[(lvl - 1, d)]
                r["iou_prev"] = iou(m, prev)
                if lvl % 2 == 0:
                    r["added"] = float(np.logical_and(m, ~prev).sum() / 4096.0)
            if lvl % 2 == 1 and lvl > 1 and (lvl - 2, d) in masks:
                r["iou_epoch_prev"] = iou(m, masks[(lvl - 2, d)])
            if lvl % 2 == 1 and (1, d) in masks:
                m1 = masks[(1, d)]
                r["V"] = float(np.logical_and(m1, ~m).sum() / max(1, m1.sum()))
    # D1-3
    d13 = {}
    for d in IO.DIRS:
        if (1, d) in masks and (30, d) in masks:
            nb, kb = norm_iou(masks[(1, d)], masks[(30, d)])
            d13[d] = {"iou": iou(masks[(1, d)], masks[(30, d)]), "iou_norm": nb, "k": kb}
    res["d13"] = d13
    return res


def table(res):
    lines = []
    hdr = ("Niv", "Ép", "O N", "O max", "O cible", "O tige", "L max", "aire N", "ajout min", "IoU préc max",
           "IoU ép. max", "V min", "lum N", "cible", "p95", "sat", "lueur %", "zone px", "contraste")
    lines.append(" | ".join(hdr))
    for key in sorted(res["levels"]):
        lvl = int(key[1:])
        e = (lvl + 1) // 2
        rs = res["levels"][key]
        ds = [d for d in IO.DIRS if d in rs]
        rN = rs.get("N", rs[ds[0]])

        def mx(k, f=max):
            v = [rs[d][k] for d in ds if k in rs[d]]
            return f(v) if v else None

        def fmt(v, p=2):
            return "—" if v is None else ("%.*f" % (p, v))
        row = [key, str(e), fmt(rN["O"]), fmt(mx("O")), fmt(O_RANK[e - 1]), fmt(mx("O_tige")), fmt(mx("L")),
               fmt(rN["area"]), fmt(mx("added", min)), fmt(mx("iou_prev")), fmt(mx("iou_epoch_prev")),
               fmt(None if mx("V", min) is None else 100 * mx("V", min), 0), fmt(rN["lum_p50"], 0),
               str(LUM_TARGET[e - 1]), fmt(rN["lum_p95"], 0), fmt(rN["sat"]),
               fmt(None if rN.get("glow_frac") is None else 100 * rN["glow_frac"], 1),
               str(rN.get("glow_zone_px", "—")), fmt(rN.get("glow_contrast"), 0)]
        lines.append(" | ".join(row))
    lines.append("")
    for d, v in sorted(res["d13"].items()):
        lines.append("D1-3 %s : IoU(1, 30) = %.3f ; IoU normalisée = %.3f (k = %.2f)" % (d, v["iou"], v["iou_norm"], v["k"]))
    if res["d13"]:
        lines.append("D1-3 max sur les poses : IoU = %.3f ; IoU normalisée = %.3f" % (
            max(v["iou"] for v in res["d13"].values()), max(v["iou_norm"] for v in res["d13"].values())))
    lines.append("")
    lines += checks(res)
    return "\n".join(lines)


def checks(res):
    """Contrôles automatiques (indicateurs de la bible §1.4 ; ils aident le verdict, ne le remplacent pas)."""
    out = ["Contrôles (max ou min sur les 4 poses) :"]
    lv = res["levels"]
    fails = []

    def worst(key, k, f):
        v = [lv[key][d][k] for d in IO.DIRS if d in lv.get(key, {}) and k in lv[key][d]]
        return f(v) if v else None
    # pièce paire >= 0,10 t² ajoutée, dans chaque pose
    for lvl in range(2, 31, 2):
        a = worst("L%02d" % lvl, "added", min)
        if a is not None and a < 0.10:
            fails.append("L%02d : pièce paire %.3f t² < 0,10" % (lvl, a))
    # niveau impair : IoU avec le pair précédent <= 0,85 ; avec l'impair précédent <= 0,85
    for lvl in range(3, 31, 2):
        for k, lab in (("iou_prev", "IoU avec le niveau pair précédent"), ("iou_epoch_prev", "IoU entre époques")):
            v = worst("L%02d" % lvl, k, max)
            if v is not None and v > 0.85:
                fails.append("L%02d : %s %.3f > 0,85" % (lvl, lab, v))
    # O : niveaux impairs jamais décroissants (pose N et max des poses) ; tous les niveaux sous le plafond
    prev = None
    for lvl in range(1, 31, 2):
        key = "L%02d" % lvl
        if key not in lv or "N" not in lv[key]:
            continue
        o = lv[key]["N"]["O"]
        if prev is not None and o < prev[1] - 1.0 / 64:
            fails.append("%s : O (pose N) %.2f < %.2f (%s)" % (key, o, prev[1], prev[0]))
        prev = (key, o)
    for key in sorted(lv):
        o = worst(key, "O", max)
        if o is not None and o > O_CEIL + 1.0 / 64:
            fails.append("%s : O %.2f > plafond %.2f" % (key, o, O_CEIL))
    # emprise : rien ne dépasse de plus de 0,25 tuile sur les côtés ni au sud (F42 : 0,10 à 0,25 permis)
    for key in sorted(lv):
        for d in IO.DIRS:
            r = lv[key].get(d)
            if r is None:
                continue
            over = max(r["side_l"], r["side_r"], r["below"])
            if over > 0.25 + 1.0 / 64 and key != "L01":
                fails.append("%s %s : dépasse l'emprise de %.2f tuile (côté ou sud)" % (key, d, over))
    # palette (bible §1.5) : luminance médiane du corps = cible ± 10 et dans [40, 110], p95 <= 240,
    # saturation <= 0,45 ; pose N ; L01 et L02 portent le sprite vanilla (hors règle)
    for lvl in range(3, 31):
        r = lv.get("L%02d" % lvl, {}).get("N")
        if r is None:
            continue
        e = (lvl + 1) // 2
        t = LUM_TARGET[e - 1]
        if abs(r["lum_p50"] - t) > 10 or not 40 <= r["lum_p50"] <= 110:
            fails.append("L%02d : luminance médiane %.0f (cible %d ± 10, dans [40, 110])" % (lvl, r["lum_p50"], t))
        if r["lum_p95"] > 240:
            fails.append("L%02d : luminance p95 %.0f > 240" % (lvl, r["lum_p95"]))
        if r["sat"] > 0.45:
            fails.append("L%02d : saturation %.2f > 0,45" % (lvl, r["sat"]))
        # D2-1 (rendus complets seulement) : une zone émissive de jour >= 8 × 8 px hr dès l'époque 3
        if not res.get("quick") and e >= 3:
            z = r.get("glow_zone_px", 0)
            if z < 64:
                fails.append("L%02d : plus grande zone de lueur de jour %d px < 64 (D2-1)" % (lvl, z))
            elif (r.get("glow_contrast") or 0) < 80:
                fails.append("L%02d : contraste de la lueur %+.0f < +80 (D2-1)" % (lvl, r.get("glow_contrast") or 0))
    d13 = res.get("d13", {})
    if d13:
        mi = max(v["iou"] for v in d13.values())
        mn = max(v["iou_norm"] for v in d13.values())
        if mi >= 0.50:
            fails.append("D1-3 : IoU(1, 30) %.3f >= 0,50" % mi)
        elif mi > 0.45:
            out.append("  avertissement : D1-3 IoU %.3f > cible 0,45" % mi)
        if mn > 0.75:
            fails.append("D1-3 : IoU normalisée %.3f > 0,75 (seuil proposé, à étalonner)" % mn)
    out += ["  ÉCHEC " + f for f in fails] if fails else ["  aucun échec"]
    res["checks"] = fails
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    spec = IO.load_spec()
    res = measure(spec, quick=a.quick)
    out = a.out or os.path.join(IO.OUT, "mesures_d1%s.json" % ("_quick" if a.quick else ""))
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1, sort_keys=True)
    txt = table(res)
    with open(out[:-5] + ".txt", "w", encoding="utf-8", newline="\n") as f:
        f.write(txt + "\n")
    print(txt)


if __name__ == "__main__":
    main()
