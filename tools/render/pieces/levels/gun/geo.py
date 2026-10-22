"""Silhouettes EXACTES de la famille gun à partir de la géométrie exportée (geo_export.py), Python système.

    python tools/render/pieces/levels/gun/geo.py [--sweep] [--only e05,e06]

- Projection du pipeline (CALIBRATION §2, fo_calib) : u = 64·X, v = -64·(Y·cos 45° + Z·sin 45°) px HR,
  origine = position de l'entité au sol ; rastérisation sur-échantillonnée ×4 puis couverture (comme l'alpha
  d'un rendu anticrénelé ; le masque D1 est alpha ≥ 0,5).
- Écrit dans d1lib.DRY_DIR les alphas des variantes de référence (<variante>-alpha.png, toile commune de
  d1lib : origine en (OX, OY)) et dryrun.json : d1lib.level_layers(niveau, pose, "dry") les lit tels quels.
- --sweep : union des silhouettes de la tête sur ses 64 directions (pose « prepared »), par époque :
  <DRY_DIR>/eNN-balayage-alpha.png. Sert à la zone du socle toujours visible (F46, bible §1.7 : « à recalculer
  à chaque époque avec la tête de l'époque »).
Limite : silhouette géométrique (couverture ≥ 50 % d'un pixel), sans le flou du filtre de Cycles (1,5 px) ;
écart attendu d'un demi-pixel sur les bords (vérifié contre les aperçus Cycles par measure_d1 --check-geo).
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
import d1lib as D  # noqa: E402
import gun as G  # noqa: E402

MOD_ROOT = D.MOD_ROOT
GEO_DIR = os.path.join(MOD_ROOT, "tools", "render", "cache", "levels-gun", "geo")
COS45 = math.cos(math.radians(45.0))
SIN45 = math.sin(math.radians(45.0))
SS = 4
DIR_ANGLE = {"N": 0.0, "E": -math.pi / 2, "S": math.pi, "O": math.pi / 2}


def load(name):
    z = np.load(os.path.join(GEO_DIR, "%s.npz" % name))
    return z["tris"].astype(np.float64), z["emis"], z["halos"]


def rotate(tris, angle):
    c, s = math.cos(angle), math.sin(angle)
    out = tris.copy()
    out[..., 0] = tris[..., 0] * c - tris[..., 1] * s
    out[..., 1] = tris[..., 0] * s + tris[..., 1] * c
    return out


def project(tris):
    """(n, 3, 3) Blender -> (n, 3, 2) pixels HR de la toile d1lib (origine en OX, OY)."""
    u = D.OX + 64.0 * tris[..., 0]
    v = D.OY - 64.0 * (tris[..., 1] * COS45 + tris[..., 2] * SIN45)
    return np.stack([u, v], -1)


def raster(tris, ss=SS):
    """Couverture (H, W) dans [0, 1] des triangles projetés."""
    p = project(tris) * ss
    img = Image.new("L", (D.W * ss, D.H * ss), 0)
    dr = ImageDraw.Draw(img)
    # Pillow remplit les pixels dont le centre est dans le polygone (à ±0,5 px) : décalage d'un demi-pixel
    # pour que le pixel (i, j) couvre [i, i+1) × [j, j+1) en coordonnées continues.
    p = p - 0.5
    for t in p.tolist():
        dr.polygon([tuple(t[0]), tuple(t[1]), tuple(t[2])], fill=255)
    a = np.asarray(img, np.float64).reshape(D.H, ss, D.W, ss).mean((1, 3)) / 255.0
    return a


def write_alpha(a, name, info):
    rgba = np.zeros(a.shape + (4,), np.uint8)
    rgba[..., 3] = np.clip(np.round(a * 255), 0, 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(D.DRY_DIR, "%s-alpha.png" % name), optimize=True)
    info[name] = {"canvas": [D.W, D.H], "origin_px": [D.OX, D.OY], "source": "geo"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sweep", action="store_true")
    ap.add_argument("--only", default="", help="époques (e05,e06) ou variantes")
    ap.add_argument("--dirs", type=int, default=64)
    a = ap.parse_args()
    os.makedirs(D.DRY_DIR, exist_ok=True)
    jp = os.path.join(D.DRY_DIR, "dryrun.json")
    info = {}
    if os.path.exists(jp):
        with open(jp, encoding="utf-8") as f:
            info = json.load(f)
    only = [x for x in a.only.split(",") if x]
    names = sorted(G.PIECE["variants"])
    if only:
        names = [n for n in names if any(n == o or n.startswith(o + "-") for o in only)]
    for name in names:
        v = G.PIECE["variants"][name]
        if v["part"] == "tete":
            tris, _, _ = load("e%02d-tete-N" % v["epoch"])
            tris = rotate(tris, DIR_ANGLE[v["dir"]])
        else:
            tris, _, _ = load(name)
        write_alpha(raster(tris), name, info)
        print("[FO-GEO] %s" % name, flush=True)
    if a.sweep:
        for e in range(2, 16):
            tag = "e%02d" % e
            if only and tag not in only:
                continue
            tris, _, _ = load("%s-tete-N" % tag)
            acc = np.zeros((D.H, D.W))
            for k in range(a.dirs):
                acc = np.maximum(acc, raster(rotate(tris, -2 * math.pi * k / a.dirs), ss=2))
            write_alpha(acc, "%s-balayage" % tag, info)
            print("[FO-GEO] balayage %s (%d directions)" % (tag, a.dirs), flush=True)
    with open(jp, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
