"""Mémoire vidéo des têtes à 64 directions (lot A3-jeu, 24/10) : atlas mesurés contre pixels des feuilles, et
extrapolation aux 15 âges. Python 3.9 (numpy, Pillow).

    py -3.9 tools/render/pieces/levels/gun_e/vram64.py --avant JOURNAL --apres JOURNAL --feuilles DIR --qualite hr|lr
        [--repli DIR] [--estimation A3/estimation/estimation.txt]

- AVANT, APRÈS : journaux du jeu (factorio.log) de deux passages D4m de même qualité (avant = têtes à 4 directions,
  après = feuilles de --feuilles) ; lignes « Created atlas bitmap LxH [drapeaux] » : pixels par famille d'atlas
  (objets « none », ombres « shadow », autres).
- Pixels des têtes dans les feuilles : par cellule, feuille ENTIÈRE (largeur × hauteur de la cellule) et ROGNÉE
  (boîte des pixels d'alpha non nul de la cellule) ; couches principale et lueur (atlas « none ») et ombre (« shadow »).
  --repli : un dossier de feuilles à 4 directions (feuilles.py --ages-64 aucun) pour la soustraction.
- Rapport « mesuré / prévu » pour les âges passés à 64 : il dit si le moteur range les images ENTIÈRES ou ROGNÉES
  dans l'atlas (A3 : « rognage NON prouvé ») et avec quel surcoût de rangement.
- Extrapolation aux 15 âges : ajout prévu par estimation.txt d'A3 (Mpx rognés ou entiers des feuilles, hr ou normale)
  × le rapport mesuré, ajouté au total d'atlas d'AVANT ; octets par pixel de vram.py (rapport estimation / Gpx du
  passage).
"""
import argparse
import json
import os
import re
import sys

import numpy as np
from PIL import Image

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PREFIX = "__factorio-overhaul__/graphics/levels/gun/"
RE_ATLAS = re.compile(r"Created atlas bitmap (\d+)x(\d+) \[([^\]]*)\]")
RE_VIRTUEL = re.compile(r"Created virtual atlas pages (\d+)x(\d+)x(\d+)")


def atlas(p):
    """Pixels par famille d'atlas. « virtuel » : pages de l'atlas virtuel (plancher, --video-memory low : les objets y
    sont servis à la demande, taille FIXE ; leurs pixels n'apparaissent alors dans aucun atlas « none »)."""
    fam = {"none": 0, "shadow": 0, "autres": 0, "virtuel": 0}
    for ln in open(p, encoding="utf-8", errors="replace"):
        mv = RE_VIRTUEL.search(ln)
        if mv:
            fam["virtuel"] += int(mv.group(1)) * int(mv.group(2)) * int(mv.group(3))
            continue
        m = RE_ATLAS.search(ln)
        if not m:
            continue
        w, h, dr = int(m.group(1)), int(m.group(2)), [x.strip() for x in m.group(3).split(",")]
        k = "none" if dr == ["none"] else ("shadow" if "shadow" in dr else "autres")
        fam[k] += w * h
    return fam


def pixels(dossier, res):
    """Par âge : {"n": directions, "none": (entier, rogné), "shadow": (entier, rogné)} en pixels."""
    spr = json.load(open(os.path.join(dossier, "sprites.json"), encoding="utf-8"))
    out = {}
    for e in range(2, 16):
        A = spr["ages"][str(e)]
        r = {"n": A["tete"]["main"][res]["direction_count"], "none": [0, 0], "shadow": [0, 0]}
        for lay, cd in A["tete"].items():
            d = cd[res]
            im = np.asarray(Image.open(os.path.join(dossier, d["filename"][len(PREFIX):])).convert("RGBA"))[..., 3]
            n, ll, W, H = d["direction_count"], d["line_length"], d["width"], d["height"]
            fam = "shadow" if lay == "shadow" else "none"
            for c in range(n):
                cell = im[(c // ll) * H:(c // ll + 1) * H, (c % ll) * W:(c % ll + 1) * W]
                r[fam][0] += W * H
                ys, xs = np.nonzero(cell)
                if len(xs):
                    r[fam][1] += (xs.max() - xs.min() + 1) * (ys.max() - ys.min() + 1)
        out[e] = r
    return out


def estimation_a3(p, res, couches=("main", "glow", "shadow")):
    """estimation.txt d'A3 : par âge, Mpx (entier, rogné) des 3 couches à 64 directions, et Mpx à 4 directions."""
    out = {}
    for ln in open(p, encoding="utf-8"):
        m = re.match(r"\s*(\d+)\s+(main|glow|shadow)\s+\d+\s+\S+ x \S+\s+\S+ x \S+\s+\d+\s+([\d.]+) /\s+([\d.]+)\s+"
                     r"([\d.]+)\s+\|\s+([\d.]+) /\s+([\d.]+)", ln)
        if not m:
            continue
        if m.group(2) not in couches:
            continue
        e = int(m.group(1))
        o = out.setdefault(e, [0.0, 0.0, 0.0])
        if res == "hr":
            o[0] += float(m.group(3))
            o[1] += float(m.group(4))
            o[2] += float(m.group(6))
        else:
            o[0] += float(m.group(5))
            o[1] += float(m.group(5)) * float(m.group(4)) / float(m.group(3))
            o[2] += float(m.group(7))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--avant", required=True)
    ap.add_argument("--apres", required=True)
    ap.add_argument("--feuilles", required=True)
    ap.add_argument("--repli", required=True)
    ap.add_argument("--qualite", choices=("hr", "lr"), default="hr")
    ap.add_argument("--estimation", default=r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-24_A3\estimation\estimation.txt")
    ap.add_argument("--go-par-gpx", default="", help="bornes octets/px (Go par Gpx) lues dans le rapport vram.py, ex. 1.03,1.17")
    a = ap.parse_args()
    av, apr = atlas(a.avant), atlas(a.apres)
    P, R = pixels(a.feuilles, a.qualite), pixels(a.repli, a.qualite)
    ages64 = [e for e in range(2, 16) if P[e]["n"] == 64]
    print("[FO-VRAM64] qualité %s ; âges à 64 directions : %s" % (a.qualite, ages64))
    tot_m = 0
    for fam in ("none", "shadow"):
        mes = apr[fam] - av[fam]
        ent = sum(P[e][fam][0] - R[e][fam][0] for e in ages64)
        rog = sum(P[e][fam][1] - R[e][fam][1] for e in ages64)
        tot_m += mes
        print("[FO-VRAM64] atlas %-6s : AVANT %.1f Mpx, APRÈS %.1f Mpx, mesuré +%.2f Mpx ; prévu feuilles ENTIÈRES "
              "+%.2f Mpx (rapport %.2f), ROGNÉES +%.2f Mpx (rapport %.2f)" % (
                  fam, av[fam] / 1e6, apr[fam] / 1e6, mes / 1e6, ent / 1e6, mes / max(ent, 1), rog / 1e6,
                  mes / max(rog, 1)))
    print("[FO-VRAM64] autres atlas : %+.2f Mpx (rangement) ; total %.4f -> %.4f Gpx" % (
        (apr["autres"] - av["autres"]) / 1e6, sum(av.values()) / 1e9, sum(apr.values()) / 1e9))
    if av["virtuel"] or apr["virtuel"]:
        print("[FO-VRAM64] ATLAS VIRTUEL : AVANT %.1f Mpx, APRÈS %.1f Mpx (pages de taille fixe : les objets, têtes "
              "comprises, y sont servis à la demande ; le rapport « none » et l'extrapolation ci-dessous ne valent que "
              "pour les ombres ; la mémoire réelle se lit sur le compteur du passage)" % (
                  av["virtuel"] / 1e6, apr["virtuel"] / 1e6))
    ent = sum(P[e][f][0] - R[e][f][0] for e in ages64 for f in ("none", "shadow"))
    rog = sum(P[e][f][1] - R[e][f][1] for e in ages64 for f in ("none", "shadow"))
    mes_tot = sum(apr.values()) - sum(av.values())
    k_rog = mes_tot / max(rog, 1)
    print("[FO-VRAM64] tous atlas : mesuré %+.2f Mpx ; rapport mesuré / rogné %.2f ; mesuré / entier %.2f" % (
        mes_tot / 1e6, k_rog, mes_tot / max(ent, 1)))
    # extrapolation : âges restants à 4 directions, d'après l'estimation d'A3
    est = estimation_a3(a.estimation, a.qualite)
    reste = [e for e in range(2, 16) if e not in ages64]
    aj_rog = sum(est[e][1] - est[e][2] for e in reste)
    aj_ent = sum(est[e][0] - est[e][2] for e in reste)
    fin_rog = sum(apr.values()) / 1e9 + k_rog * aj_rog / 1e3
    print("[FO-VRAM64] extrapolation aux 15 âges (âges restants %s ; estimation A3 rognée +%.1f Mpx, entière +%.1f Mpx) :"
          " %.3f Gpx (rogné × %.2f)" % (reste, aj_rog, aj_ent, fin_rog, k_rog))
    if av["virtuel"] or apr["virtuel"]:
        # plancher : seules les ombres grandissent dans un atlas mesurable
        mes_s = apr["shadow"] - av["shadow"]
        rog_s = sum(P[e]["shadow"][1] - R[e]["shadow"][1] for e in ages64)
        k_s = mes_s / max(rog_s, 1)
        est_s = estimation_a3(a.estimation, a.qualite, ("shadow",))
        aj_s = sum(est_s[e][1] - est_s[e][2] for e in reste)
        print("[FO-VRAM64] PLANCHER, ombres seules : mesuré %+.2f Mpx (rapport mesuré / rogné %.2f) ; ajout prévu aux "
              "15 âges %+.1f Mpx ; atlas d'ombres %.1f -> %.1f Mpx ; objets : atlas virtuel FIXE %.1f Mpx" % (
                  mes_s / 1e6, k_s, k_s * aj_s, apr["shadow"] / 1e6, apr["shadow"] / 1e6 + k_s * aj_s,
                  apr["virtuel"] / 1e6))
    if a.go_par_gpx:
        lo, hi = (float(x) for x in a.go_par_gpx.split(","))
        print("[FO-VRAM64] mémoire estimée (octets/px de vram.py, %.3f à %.3f Go/Gpx) : %.2f à %.2f Go" % (
            lo, hi, fin_rog * lo, fin_rog * hi))
    return 0


if __name__ == "__main__":
    sys.exit(main())
