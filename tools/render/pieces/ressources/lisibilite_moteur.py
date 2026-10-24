"""Lisibilité du tungstène MESURÉE SUR LES CAPTURES EN MOTEUR (correction du lot M1, 24/10). Python système (py -3.9).

    py -3.9 tools/render/pieces/ressources/lisibilite_moteur.py "<dossier des captures de fo-captures.bat m1-minerai>"
        [--json sortie.json]

Pourquoi : la planche hors moteur de mesure.py approche la nuit par « image × 0,2 + effet » ; sur le commit a9038a9 elle
annonçait le tungstène PLUS lisible que le fer de nuit (contraste 16,1 contre 13,5), et les captures en moteur disaient
l'inverse (7,5 contre 11,2 ; ΔE76 4,4 du fer). Seul le moteur fait foi : ce script mesure les captures du scénario
greffé m1-minerai (géométrie : tools/autotest/fo-autotest/scenarios/m1-minerai.lua ; écran 1600 × 900).

Mesures, sur le MÊME sol (planche « cendres », tous les gisements sur fo-volcanic-ash) :
  - couleur moyenne d'un disque centré sur chaque gisement (zoom 1 : 120 px, 3,75 tuiles ; zoom 2 : 250 px) ;
  - contraste au sol : écart absolu moyen (RGB, /255) entre les pixels du disque et le sol nu ;
  - pixels clairs : part des pixels du disque dont la luminance dépasse celle du sol de plus de 40 ;
  - ΔE76 (Lab D65) entre la couleur moyenne du tungstène et celle de chaque voisin.

Critères (fixés AVANT les essais de la correction, d'après le défaut MAJEUR 1 de la vérification) :
  NUIT, zoom 1 (004) et zoom 2 (010, fer à côté) :
    N1  ΔE76(tungstène, fer) >= 10 aux deux zooms ;
    N2  ΔE76(tungstène, charbon) >= 10 et ΔE76(tungstène, pierre) >= 10 au zoom 1 ;
    N3  contraste au sol du tungstène >= celui du fer aux deux zooms ;
    N4  pixels clairs du tungstène >= 2 × ceux du fer aux deux zooms ;
    N5  toutes les captures de nuit du tungstène sur cendres (004, 010, 012) : ΔE76 au fer de 004 >= 10 (stabilité de
        la pulsation sur les instants capturés ; une période entière n'est PAS couverte : 100 ticks sur 360).
  JOUR, zoom 1 (003) et zoom 2 (009), non-régression contre a9038a9 (ΔE fer 10,7, charbon 8,5) :
    J1  ΔE76(tungstène, fer) >= 10 ; J2  ΔE76(tungstène, charbon) >= 8.
Code 0 si tout passe, 1 sinon.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mesure import lab  # noqa: E402

W, H = 1600, 900
# Zoom 1 : planche entière, 32 px par tuile, centres des gisements à 11 tuiles (352 px), rangées à ± 5,5 tuiles.
Z1 = {"fer": (448, 274), "tungstene": (800, 274), "charbon": (1152, 274), "cuivre": (448, 626),
      "pierre": (800, 626), "uranium": (1152, 626)}
Z1_SOL = (slice(440, 470), slice(600, 660))
# Zoom 2 : deux gisements côte à côte, centres à ± 352 px du milieu.
Z2_SOL = (slice(780, 840), slice(760, 840))
CAPTURES = {
    "z1-jour": "003-planche-cendres-z1-jour.png", "z1-nuit": "004-planche-cendres-z1-nuit.png",
    "z2-fer-jour": "009-cendres-fer-tungstene-z2-jour.png", "z2-fer-nuit": "010-cendres-fer-tungstene-z2-nuit.png",
    "z2-charbon-jour": "011-cendres-tungstene-charbon-z2-jour.png",
    "z2-charbon-nuit": "012-cendres-tungstene-charbon-z2-nuit.png",
}
LUM = np.array([0.2126, 0.7152, 0.0722])


def mesurer(im, centres, sol_sl, rayon):
    yy, xx = np.mgrid[0:im.shape[0], 0:im.shape[1]]
    sol = im[sol_sl].reshape(-1, 3).mean(0)
    lsol = float(sol @ LUM)
    r = {"sol": [round(float(x), 1) for x in sol]}
    for k, (x, y) in centres.items():
        px = im[(xx - x) ** 2 + (yy - y) ** 2 < rayon ** 2]
        r[k] = {"moy": [round(float(v), 1) for v in px.mean(0)],
                "contraste": round(float(np.abs(px - sol).mean()), 2),
                "clairs": round(float(((px @ LUM) > lsol + 40).mean()), 4)}
    return r


def de(a, b):
    return round(float(np.linalg.norm(lab(np.array(a) / 255.0) - lab(np.array(b) / 255.0))), 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("captures")
    ap.add_argument("--json")
    a = ap.parse_args()
    im = {}
    for k, fn in CAPTURES.items():
        p = os.path.join(a.captures, fn)
        if not os.path.exists(p):
            print("[FO-LISIBILITE] ECHEC capture absente : %s" % p)
            sys.exit(1)
        im[k] = np.asarray(Image.open(p).convert("RGB")).astype(np.float64)
        if im[k].shape[:2] != (H, W):
            print("[FO-LISIBILITE] ECHEC %s : %s au lieu de 1600 x 900" % (fn, im[k].shape[:2]))
            sys.exit(1)
    m = {}
    for k in ("z1-jour", "z1-nuit"):
        m[k] = mesurer(im[k], Z1, Z1_SOL, 120)
    for k, voisin in (("z2-fer-jour", "fer"), ("z2-fer-nuit", "fer"), ("z2-charbon-jour", "charbon"),
                      ("z2-charbon-nuit", "charbon")):
        if voisin == "fer":
            centres = {"fer": (448, 450), "tungstene": (1152, 450)}
        else:
            centres = {"tungstene": (448, 450), "charbon": (1152, 450)}
        m[k] = mesurer(im[k], centres, Z2_SOL, 250)
    for k, r in m.items():
        t = r["tungstene"]["moy"]
        r["dE"] = {v: de(t, r[v]["moy"]) for v in r if v not in ("sol", "tungstene", "dE")}
    ok, ko = 0, 0
    lignes = []

    def check(c, quoi):
        nonlocal ok, ko
        ok, ko = ok + (1 if c else 0), ko + (0 if c else 1)
        lignes.append("[FO-LISIBILITE] %s %s" % ("OK    " if c else "ECHEC ", quoi))

    for k in ("z1-jour", "z1-nuit", "z2-fer-jour", "z2-fer-nuit", "z2-charbon-jour", "z2-charbon-nuit"):
        r = m[k]
        print("[FO-LISIBILITE] %-16s sol %s | %s | ΔE76 tungstène / %s" % (
            k, r["sol"], " | ".join("%s moy %s contraste %.1f clairs %.2f %%" % (
                v, r[v]["moy"], r[v]["contraste"], 100 * r[v]["clairs"]) for v in r if v not in ("sol", "dE")),
            ", ".join("%s %.1f" % (v, d) for v, d in r["dE"].items())))
    # Référence : écarts ENTRE minerais vanilla sur la même capture (pourquoi 10 : de nuit, aucune paire vanilla sans
    # lueur n'atteint 10 ; fer / charbon 8,9 et fer / pierre 7,0 sur la capture 004 du commit a9038a9 ; l'uranium, qui
    # luit, est à plus de 20 de tous).
    for k in ("z1-jour", "z1-nuit"):
        r = m[k]
        van = ("fer", "charbon", "cuivre", "pierre", "uranium")
        paires = ["%s/%s %.1f" % (x, y, de(r[x]["moy"], r[y]["moy"])) for i, x in enumerate(van) for y in van[i + 1:]]
        print("[FO-LISIBILITE] référence vanilla %-8s ΔE76 : %s" % (k, ", ".join(paires)))
    n1, n2 = m["z1-nuit"], m["z2-fer-nuit"]
    check(n1["dE"]["fer"] >= 10 and n2["dE"]["fer"] >= 10,
          "N1 nuit : ΔE76 tungstène / fer >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (n1["dE"]["fer"], n2["dE"]["fer"]))
    check(n1["dE"]["charbon"] >= 10 and n1["dE"]["pierre"] >= 10,
          "N2 nuit, zoom 1 : ΔE76 tungstène / charbon >= 10 (%.1f) et / pierre >= 10 (%.1f)" % (
              n1["dE"]["charbon"], n1["dE"]["pierre"]))
    check(n1["tungstene"]["contraste"] >= n1["fer"]["contraste"] and n2["tungstene"]["contraste"] >= n2["fer"]["contraste"],
          "N3 nuit : contraste au sol tungstène >= fer (zoom 1 : %.1f / %.1f ; zoom 2 : %.1f / %.1f)" % (
              n1["tungstene"]["contraste"], n1["fer"]["contraste"], n2["tungstene"]["contraste"], n2["fer"]["contraste"]))
    check(n1["tungstene"]["clairs"] >= 2 * n1["fer"]["clairs"] and n2["tungstene"]["clairs"] >= 2 * n2["fer"]["clairs"],
          "N4 nuit : pixels clairs tungstène >= 2 x fer (zoom 1 : %.2f %% / %.2f %% ; zoom 2 : %.2f %% / %.2f %%)" % (
              100 * n1["tungstene"]["clairs"], 100 * n1["fer"]["clairs"], 100 * n2["tungstene"]["clairs"],
              100 * n2["fer"]["clairs"]))
    fer_nuit = n1["fer"]["moy"]
    stab = [de(m[k]["tungstene"]["moy"], fer_nuit) for k in ("z1-nuit", "z2-fer-nuit", "z2-charbon-nuit")]
    check(min(stab) >= 10, "N5 nuit, 3 instants (ticks 150, 210, 230) : ΔE76 tungstène / fer de 004 >= 10 (%s)" % (
        ", ".join("%.1f" % x for x in stab)))
    j1, j2 = m["z1-jour"], m["z2-fer-jour"]
    check(j1["dE"]["fer"] >= 10 and j2["dE"]["fer"] >= 10,
          "J1 jour : ΔE76 tungstène / fer >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (j1["dE"]["fer"], j2["dE"]["fer"]))
    check(j1["dE"]["charbon"] >= 8 and m["z2-charbon-jour"]["dE"]["charbon"] >= 8,
          "J2 jour : ΔE76 tungstène / charbon >= 8 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (
              j1["dE"]["charbon"], m["z2-charbon-jour"]["dE"]["charbon"]))
    for l in lignes:
        print(l)
    print("[FO-LISIBILITE] BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"mesures": m, "ok": ok, "echecs": ko}, f, indent=1, ensure_ascii=False)
    sys.exit(0 if ko == 0 else 1)


if __name__ == "__main__":
    main()
