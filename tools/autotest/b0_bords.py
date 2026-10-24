"""Lot B0 (biomes) : mesures sur les captures du scénario b0-biomes (fo-captures.bat b0-biomes).

1. Bords « en carrés » : pour chaque capture, rapport R entre le gradient de luminance mesuré SUR les lignes de la grille
   des tuiles (bande de 1 px de part et d'autre) et le gradient ailleurs. Un bord de tuile franc, sans transition, met
   l'énergie du gradient sur la grille (R nettement > 1) ; une transition vanilla (masque irrégulier) la répartit (R ~ 1).
   La grille se déduit du centre et du zoom de la capture (index.tsv) : x_px = W/2 + (x_monde - x_centre) * 32 * zoom.
2. Nuancier (fichier b0-nuancier.json écrit par le scénario) : couleur moyenne au centre de chaque disque (3 x 3 tuiles),
   en sRGB et en CIELAB (D65), et écart CIE76 au fond.

Usage : py -3.9 tools/autotest/b0_bords.py <dossier des captures> [--json <sortie>]
"""
import argparse
import csv
import json
import math
import os

from PIL import Image


def lab(rgb):
    def lin(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116
    L = 116 * f(y) - 16
    return (L, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))


def hue(l):
    return math.degrees(math.atan2(l[2], l[1])) % 360


def lire_index(dossier):
    with open(os.path.join(dossier, "index.tsv"), encoding="utf-8") as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


QUANTILE = 0.98  # seuls les 2 % de gradients de couleur les plus forts comptent (les bords, pas le grain des textures)


def rapport_grille(chemin, cx, cy, zoom):
    """Part des gradients forts qui tombent sur la grille des tuiles, rapportée à la part attendue au hasard (largeur
    de la bande / taille d'une tuile). 1 : aucune préférence pour la grille ; bords de tuiles francs : nettement plus."""
    import numpy as np
    a = np.asarray(Image.open(chemin).convert("RGB"), dtype=np.int16)
    h, w, _ = a.shape
    t = 32.0 * zoom

    def bande(c, taille):
        m = np.zeros(taille, dtype=bool)
        k0 = math.floor(c - taille / 2 / t) - 1
        k1 = math.ceil(c + taille / 2 / t) + 1
        for k in range(k0, k1 + 1):
            q = int(round(taille / 2 + (k - c) * t))  # indice du pixel juste après la ligne de grille
            for d in (-1, 0, 1):  # tolérance d'un pixel (arrondi, anticrénelage)
                if 0 <= q + d < taille:
                    m[q + d] = True
        return m
    gx = np.abs(a[:, 1:, :] - a[:, :-1, :]).sum(axis=2)  # gx[:, x-1] = saut entre x-1 et x
    gy = np.abs(a[1:, :, :] - a[:-1, :, :]).sum(axis=2)
    cols = bande(cx, w)[1:]
    rows = bande(cy, h)[1:]
    res = []
    for g, m, axe in ((gx, cols, 1), (gy, rows, 0)):
        seuil = np.quantile(g, QUANTILE)
        fort = g > seuil
        part = (fort & (m[None, :] if axe == 1 else m[:, None])).sum() / max(1, fort.sum())
        attendu = m.mean()
        res.append(part / attendu)
    return res[0], res[1]


def moyenne(im, x0, y0, x1, y1):
    reg = im.crop((int(x0), int(y0), int(x1), int(y1)))
    n = reg.size[0] * reg.size[1]
    s = [0, 0, 0]
    for p in reg.getdata():
        s[0] += p[0]
        s[1] += p[1]
        s[2] += p[2]
    return tuple(v / n for v in s)


def nuancier(dossier, index):
    chemin = os.path.join(dossier, "b0-nuancier.json")
    if not os.path.exists(chemin):
        return None
    with open(chemin, encoding="utf-8") as fh:
        nu = json.load(fh)
    ligne = next((l for l in index if l["scene"] == "nuancier-z05"), None)
    if not ligne:
        return None
    im = Image.open(os.path.join(dossier, ligne["fichier"])).convert("RGB")
    w, h = im.size
    cx, cy, z = float(ligne["x"]), float(ligne["y"]), float(ligne["zoom"])
    t = 32 * z

    def ecran(x, y):
        return w / 2 + (x - cx) * t, h / 2 + (y - cy) * t
    res = []
    for d in nu["disques"]:
        x, y = ecran(d["x"], d["y"])
        c = moyenne(im, x - 1.5 * t, y - 1.5 * t, x + 1.5 * t, y + 1.5 * t)
        fx, fy = ecran(d["x"] + nu["pas"] / 2, d["y"])
        f = moyenne(im, fx - 1 * t, fy - 1.5 * t, fx + 1 * t, fy + 1.5 * t)
        lc, lf = lab(c), lab(f)
        de = math.sqrt(sum((a - b) ** 2 for a, b in zip(lc, lf)))
        res.append({"tuile": d["tuile"], "fond": d["fond"], "rgb": [round(v) for v in c], "lab": [round(v, 1) for v in lc],
                    "teinte": round(hue(lc)), "chroma": round(math.hypot(lc[1], lc[2]), 1),
                    "fond_rgb": [round(v) for v in f], "fond_lab": [round(v, 1) for v in lf], "dE_fond": round(de, 1)})
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dossier")
    ap.add_argument("--json")
    a = ap.parse_args()
    index = lire_index(a.dossier)
    out = {"grille": [], "nuancier": None}
    print("[FO-B0-BORDS] rapport du gradient SUR la grille des tuiles / AILLEURS (1 = pas de bord en carres)")
    for l in index:
        f = os.path.join(a.dossier, l["fichier"])
        if not os.path.exists(f) or float(l["zoom"]) < 0.5:
            continue
        rx, ry = rapport_grille(f, float(l["x"]), float(l["y"]), float(l["zoom"]))
        out["grille"].append({"scene": l["scene"], "rx": round(rx, 3), "ry": round(ry, 3), "r": round((rx + ry) / 2, 3)})
        print("  %-28s zoom %-5s Rx %.3f  Ry %.3f  R %.3f" % (l["scene"], l["zoom"], rx, ry, (rx + ry) / 2))
    nu = nuancier(a.dossier, index)
    if nu:
        out["nuancier"] = nu
        print("[FO-B0-BORDS] nuancier (centre 3 x 3 tuiles, capture au zoom 0,5, midi) :")
        for r in nu:
            print("  %-18s sur %-13s RGB %-16s Lab %-20s teinte %3d chroma %5.1f | fond RGB %-16s dE %5.1f" % (
                r["tuile"], r["fond"], r["rgb"], r["lab"], r["teinte"], r["chroma"], r["fond_rgb"], r["dE_fond"]))
    if a.json:
        with open(a.json, "w", encoding="utf-8") as fh:
            json.dump(out, fh, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
