"""Test NOIR ET BLANC et part de forme changée entre époques voisines (lot V3-E, troisième passe, exigences (c) et (d)).

    py -3.9 tools/render/pieces/levels/gun_e_bas/gris.py <dossier out> [--json sortie.json] [--poses E,N]

Pour chaque époque (niveau impair ; époque 1 : niveau 2 = vanilla + pièce), le bâtiment seul (couches principales,
corps sans sol ni ombre) est composé à 64 px/tuile, réduit au zoom 1 (32 px/tuile, en lumière linéaire), centré sur
l'origine de l'entité, puis converti en niveaux de gris (luma Rec. 709, 0 à 255). Entre deux époques voisines :
  - MAD   : différence absolue moyenne des gris sur l'UNION des masques (hors masque = gris du sol moyen, 120) ;
  - IoU   : intersection sur union des masques alpha (> 0,5) ;
  - FORME : part de l'union des masques dont la forme change au zoom 1 : pixel présent dans un seul masque, OU
            écart de gris > 32 après un flou de 3 × 3 (c'est la mesure de l'exigence (c) : au moins 25 %).
Rien n'est écrit sur le disque sauf le JSON demandé (aucune correspondance de vignette n'y figure).
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402

GROUND = 120.0
T_SHAPE = 32.0


def lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - 0.055)


def body_z1(out, e, pose, half=6.0):
    """Corps seul au zoom 1 sur un cadre de 2*half tuiles centré sur l'origine : (gris 0-255, alpha 0-1)."""
    lays = K.level_layers(out, e, pose, e == 1, kinds=("main", "glow"))
    T = 2 * half
    W = int(T * 64)
    rgb = np.zeros((W, W, 3))
    a = np.zeros((W, W))
    # la lueur de jour (draw_as_glow) s'ajoute à la couche principale comme en jeu (vignettes de couleur comprises)
    for lay in [l for l in lays if l["kind"] == "main"] + [l for l in lays if l["kind"] == "glow"]:
        img = lay["img"]
        h, w = img.shape[:2]
        x0 = int(round(half * 64 + lay["shift"][0] * 64 - w / 2.0))
        y0 = int(round(half * 64 + lay["shift"][1] * 64 - h / 2.0))
        xs0, ys0 = max(0, -x0), max(0, -y0)
        xd0, yd0 = max(0, x0), max(0, y0)
        ww, hh = min(w - xs0, W - xd0), min(h - ys0, W - yd0)
        if ww <= 0 or hh <= 0:
            continue
        src = img[ys0:ys0 + hh, xs0:xs0 + ww]
        sa = src[..., 3]
        d = (slice(yd0, yd0 + hh), slice(xd0, xd0 + ww))
        if lay["kind"] == "glow":
            rgb[d] = np.clip(rgb[d] + src[..., :3] * sa[..., None], 0, 1)
            continue
        rgb[d] = src[..., :3] * sa[..., None] + rgb[d] * (1 - sa[..., None])
        a[d] = sa + a[d] * (1 - sa)
    # réduction 2 × 2 en lumière linéaire (prémultipliée)
    L = lin(rgb) * a[..., None]
    L = L.reshape(W // 2, 2, W // 2, 2, 3).mean((1, 3))
    A = a.reshape(W // 2, 2, W // 2, 2).mean((1, 3))
    col = srgb(np.where(A[..., None] > 1e-4, L / np.maximum(A[..., None], 1e-4), 0))
    grey = 255 * (0.2126 * col[..., 0] + 0.7152 * col[..., 1] + 0.0722 * col[..., 2])
    return grey, A


def blur3(x):
    p = np.pad(x, 1, mode="edge")
    return sum(p[i:i + x.shape[0], j:j + x.shape[1]] for i in range(3) for j in range(3)) / 9.0


def pair(ga, aa, gb, ab):
    ma, mb = aa > 0.5, ab > 0.5
    u = ma | mb
    i = ma & mb
    fa = np.where(ma, ga, GROUND)
    fb = np.where(mb, gb, GROUND)
    mad = float(np.abs(fa - fb)[u].mean())
    iou = float(i.sum() / max(1, u.sum()))
    da = blur3(fa)
    db = blur3(fb)
    changed = (ma ^ mb) | (np.abs(da - db) > T_SHAPE)
    forme = float(changed[u].mean())
    return {"MAD": round(mad, 1), "IoU": round(iou, 3), "FORME": round(forme, 3), "union_px": int(u.sum())}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--json", default="")
    ap.add_argument("--poses", default="E,N")
    ap.add_argument("--epochs", default="1,2,3,4,5,6,7,8,9")
    a = ap.parse_args()
    eps = [int(x) for x in a.epochs.split(",") if x]
    res = {}
    for pose in a.poses.split(","):
        G = {e: body_z1(a.out, e, pose) for e in eps}
        rows = []
        for e0, e1 in zip(eps, eps[1:]):
            r = pair(G[e0][0], G[e0][1], G[e1][0], G[e1][1])
            r.update({"de": e0, "a": e1, "pose": pose})
            rows.append(r)
            print("pose %s : époque %d -> %d : MAD %.1f  IoU %.3f  FORME %.1f %%  %s" % (
                pose, e0, e1, r["MAD"], r["IoU"], 100 * r["FORME"],
                "OK" if r["FORME"] >= 0.25 else "MOINS DE 25 %"))
        # matrice : chaque époque contre toutes (la plus proche en gris)
        for e0 in eps:
            best = min(((pair(G[e0][0], G[e0][1], G[e1][0], G[e1][1])["MAD"], e1) for e1 in eps if e1 != e0))
            print("pose %s : époque %d : la plus proche en gris est l'époque %d (MAD %.1f)" % (pose, e0, best[1],
                                                                                             best[0]))
        res[pose] = rows
    if a.json:
        json.dump(res, open(a.json, "w", encoding="utf-8"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
