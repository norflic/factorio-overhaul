"""Lot A1 (23/10), expérience E66 : l'OMBRE de la tête à 32 échantillons est-elle indiscernable de 128 ? Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/e66.py --a32 DOSSIER_32 --a128 2-12=DOSSIER --a128 13-15=DOSSIER
        --log32 BLENDER_LOG_32 --log128 BLENDER_LOG_128 --dest DOSSIER [--ages 2,9,15]

Poses : eNN-tete-d00 et eNN-tete-d16 rendues à 32 échantillons (--a32 : rose du lot A1) contre eNN-tete-N et
eNN-tete-E validées à 128 (--a128). D00 = N et d16 = E au bit près (preuve d'identité du lot A1).
1. Écart d'ALPHA de la couche d'ombre (0..255), sur un canevas commun calé par shift et taille (hr, 64 px/tuile ; et
   normale, 32 px/tuile) : moyenne sur l'union des pixels d'ombre (alpha > 0 dans l'une des deux), maximum, centile
   99, part des pixels à plus de 4 et de 16 niveaux ; plus l'écart de l'alpha moyen (biais).
2. Temps : par passe (main, shadow, glow), lu dans les journaux Blender des deux rendus (horodatage « Saved: » de
   chaque passe ; la passe principale = rendu total − ombre − lueur, car son horodatage comprend la construction).
   ATTENTION (correcteur A1) : ces temps viennent de deux rendus FAITS SOUS DES CHARGES DIFFÉRENTES ; leur rapport
   n'est PAS le gain des échantillons (51 % annoncé, faux). Le gain se mesure dos à dos avec e66_temps.py (44,7 %).
3. Image de contrôle zoom 2 : ombre 128 | ombre 32 | écart ×8, par pose.
"""
import argparse
import json
import math
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
# lot K0 (fusion INT-K0) : compo.py et les outils communs sont dans ../commun ; gun_e reste devant
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402


def sources(specs):
    res = {}
    for s in specs:
        plage, d = s.split("=", 1)
        a, b = plage.split("-") if "-" in plage else (plage, plage)
        for e in range(int(a), int(b) + 1):
            res[e] = d
    return res


def couche(d, name, lay, lr=False):
    spec = json.load(open(os.path.join(d, name, "spec.json"), encoding="utf-8"))
    s = spec["layers"][lay]
    if lr:
        s = s["lr"]
    img = np.asarray(Image.open(os.path.join(d, name, s["file"])).convert("RGBA")).astype(np.float64)
    return img, tuple(s["shift"]), spec


def commun(a, b, ppt):
    """Deux couches (img, shift) -> deux tableaux alpha sur un canevas commun (pixels entiers)."""
    boxes = []
    for img, sh in (a, b):
        h, w = img.shape[:2]
        x0 = sh[0] * ppt - w / 2.0
        y0 = sh[1] * ppt - h / 2.0
        boxes.append((x0, y0, w, h))
    # en normale (32 px/tuile), un shift multiple de 1/64 de tuile peut tomber au demi-pixel : les deux couches sont
    # alors arrondies de la même façon si leurs demi-pixels coïncident ; sinon l'écart compte le décalage (signalé).
    frac = [(round(2 * (x0 % 1)) % 2, round(2 * (y0 % 1)) % 2) for x0, y0, _, _ in boxes]
    if frac[0] != frac[1]:
        print("ATTENTION : calage différent au demi-pixel (%s)" % (boxes,))
    def fl(v):
        return int(math.floor(v + 1e-9))

    X0 = min(fl(b[0]) for b in boxes)
    Y0 = min(fl(b[1]) for b in boxes)
    X1 = max(fl(b[0]) + b[2] for b in boxes)
    Y1 = max(fl(b[1]) + b[3] for b in boxes)
    out = []
    for (img, _), (x0, y0, w, h) in zip((a, b), boxes):
        c = np.zeros((Y1 - Y0, X1 - X0))
        xi, yi = fl(x0) - X0, fl(y0) - Y0
        c[yi:yi + h, xi:xi + w] = img[..., 3]
        out.append(c)
    return out


def ecarts(a128, a32):
    sup = (a128 > 0) | (a32 > 0)
    d = np.abs(a128 - a32)[sup]
    return {"pixels": int(sup.sum()), "moy": float(d.mean()), "max": float(d.max()), "c99": float(np.percentile(d, 99)),
            "part_gt4": float((d > 4).mean()), "part_gt16": float((d > 16).mean()),
            "biais": float(a32[sup].mean() - a128[sup].mean()), "alpha_moy_128": float(a128[sup].mean())}


RE_RENDER = re.compile(r"\[FO-RENDER\] (\S+) \d+x\d+ .* build ([\d.]+)s rendu ([\d.]+)s")
RE_SAVED = re.compile(r"^(?:(\d+):)?(\d+):([\d.]+)\s+render\s+\| Saved: '.*[\\/](\S+?)-(main|shadow|glow|ao|light)\.png'")


def temps(log):
    """{variante: {"total": s, "main": s, "shadow": s, "glow": s}} depuis un journal Blender de rendre.py."""
    res, sav = {}, {}
    for ln in open(log, encoding="utf-8", errors="replace"):
        m = RE_RENDER.search(ln)
        if m:
            res.setdefault(m.group(1), {})["total"] = float(m.group(3))
            continue
        m = RE_SAVED.search(ln.strip())
        if m:
            t = (int(m.group(1) or 0) * 3600) + int(m.group(2)) * 60 + float(m.group(3))
            sav.setdefault(m.group(4), []).append((m.group(5), t))
    for n, lst in sav.items():
        d = dict(lst)
        r = res.setdefault(n, {})
        if "shadow" in d and "main" in d:
            r["shadow"] = d["shadow"] - d["main"]
        if "glow" in d and "shadow" in d:
            r["glow"] = d["glow"] - d["shadow"]
        if "total" in r and "shadow" in r and "glow" in r:
            r["main"] = r["total"] - r["shadow"] - r["glow"]
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--a32", required=True)
    ap.add_argument("--a128", action="append", required=True)
    ap.add_argument("--log32", action="append", required=True)
    ap.add_argument("--log128", action="append", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--ages", default="2,9,15")
    a = ap.parse_args()
    R = sources(a.a128)
    T32, T128 = {}, {}
    for lg in a.log32:
        T32.update(temps(lg))
    for lg in a.log128:
        T128.update(temps(lg))
    os.makedirs(a.dest, exist_ok=True)
    lignes, res, vues = [], [], []
    for e in [int(x) for x in a.ages.split(",") if x]:
        for dkk, pose in (("d00", "N"), ("d16", "E")):
            n32, n128 = "e%02d-tete-%s" % (e, dkk), "e%02d-tete-%s" % (e, pose)
            ligne = {"age": e, "pose": pose}
            for lr, ppt in ((False, 64), (True, 32)):
                i32, s32, sp32 = couche(a.a32, n32, "shadow", lr)
                i128, s128, sp128 = couche(R[e], n128, "shadow", lr)
                A128, A32 = commun((i128, s128), (i32, s32), ppt)
                ligne["lr" if lr else "hr"] = ecarts(A128, A32)
                if not lr:
                    ligne["samples"] = (sp32["samples"], sp128["samples"])
                    ligne["taille"] = (list(i32.shape[:2]), list(i128.shape[:2]))
                    dif = np.abs(A128 - A32)
                    vues.append((e, pose, A128, A32, dif))
            t32, t128 = T32.get(n32, {}), T128.get(n128.replace("-N", "-d00").replace("-E", "-d16"), {})
            ligne["temps32"], ligne["temps128"] = t32, t128
            res.append(ligne)
            h = ligne["hr"]
            lignes.append("%-3d %s  hr : écart moyen %.2f, max %.0f, c99 %.1f, >4 : %.2f %%, >16 : %.3f %%, biais %+.2f "
                          "(alpha moyen 128 : %.1f ; %d px) | normale : moyen %.2f, max %.0f, >4 : %.2f %% | ombre "
                          "%.1f s (128) contre %.1f s (32) ; tête %.1f s (128) ; main %.1f, lueur %.1f" % (
                              e, pose, h["moy"], h["max"], h["c99"], 100 * h["part_gt4"], 100 * h["part_gt16"],
                              h["biais"], h["alpha_moy_128"], h["pixels"], ligne["lr"]["moy"], ligne["lr"]["max"],
                              100 * ligne["lr"]["part_gt4"], t128.get("shadow", float("nan")),
                              t32.get("shadow", float("nan")), t128.get("total", float("nan")),
                              t128.get("main", float("nan")), t128.get("glow", float("nan"))))
    # temps gagné : ombre seule à 32, main et lueur à 128
    gains = []
    for r in res:
        t1, t3 = r["temps128"], r["temps32"]
        if all(k in t1 for k in ("total", "shadow")) and "shadow" in t3:
            gains.append((r["age"], r["pose"], t1["total"], t1["total"] - t1["shadow"] + t3["shadow"], t1["shadow"],
                          t3["shadow"]))
    lignes.append("")
    lignes.append("Temps (s, journaux Blender ; 2 sessions en parallèle dans les deux cas) : âge pose ; tête à 128 ; tête "
                  "avec l'ombre seule à 32 ; ombre 128 -> 32 ; gain")
    s1 = s2 = 0.0
    for e, p, a1, a2, o1, o2 in gains:
        s1, s2 = s1 + a1, s2 + a2
        lignes.append("%-3d %s  %.1f -> %.1f  (ombre %.1f -> %.1f)  gain %.0f %%" % (e, p, a1, a2, o1, o2, 100 * (1 - a2 / a1)))
    if s1:
        lignes.append("TOTAL des %d poses : %.0f s -> %.0f s, gain %.0f %% (rendu seul, sans le démarrage de Blender ni la "
                      "construction de la scène)" % (len(gains), s1, s2, 100 * (1 - s2 / s1)))
    txt = "\n".join(lignes)
    print(txt)
    with open(os.path.join(a.dest, "e66.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(txt + "\n")
    with open(os.path.join(a.dest, "e66.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1)
    # planche de contrôle zoom 2 (hr) : ombre 128 | 32 | écart x8, sur fond clair
    tiles = []
    for e, pose, A128, A32, dif in vues:
        def im(x):
            return Image.fromarray(np.clip(255 - x, 0, 255).astype(np.uint8), "L").convert("RGB")
        row = [im(A128), im(A32), im(np.clip(dif * 8, 0, 255))]
        h = A128.shape[0]
        w = sum(r.size[0] for r in row) + 20
        t = Image.new("RGB", (w, h + 22), (40, 40, 44))
        x = 0
        for r in row:
            t.paste(r, (x, 22))
            x += r.size[0] + 10
        ImageDraw.Draw(t).text((4, 4), "âge %d pose %s : ombre 128 | ombre 32 | écart x8" % (e, pose), fill=(230, 230, 230),
                               font=K.font(14, bold=False))
        tiles.append(t)
    W = max(t.size[0] for t in tiles)
    H = sum(t.size[1] + 8 for t in tiles)
    pl = Image.new("RGB", (W, H), (40, 40, 44))
    y = 0
    for t in tiles:
        pl.paste(t, (0, y))
        y += t.size[1] + 8
    pl.save(os.path.join(a.dest, "e66-ombres-z2.png"))


if __name__ == "__main__":
    main()
