"""Lisibilité de l'ILMÉNITE mesurée sur les CAPTURES EN MOTEUR du scénario greffé x1-titane (lot X1-TITANE, 25/10).
Python système (py -3.9). Méthode et mesures du lot M1 (tools/render/pieces/ressources/lisibilite_moteur.py : disque
autour de chaque gisement, contraste au sol, pixels clairs, ΔE76 Lab D65) ; seul le moteur fait foi pour la nuit.

    py -3.9 tools/autotest/x1_lisibilite.py "<dossier des captures de fo-captures.bat x1-titane>" [--json sortie.json]

Géométrie : celle de m1-minerai (écran 1600 × 900, planche de 3 × 2 gisements de 9 × 9 à 11 tuiles), sur le SOL DES
CRATÈRES pour tous (planche « crateres ») : rangée du haut fer, ILMÉNITE, tungstène ; rangée du bas charbon, pierre,
uranium. Zoom 2 : ilménite à côté du fer, puis à côté du tungstène.

Critères, fixés AVANT les captures (ceux du tungstène au lot M1, plus le tungstène comme voisin à distinguer) :
  NUIT  N1 ΔE76(ilménite, fer) >= 10 aux zooms 1 et 2 ; N2 ΔE76(ilménite, charbon) >= 10 et (ilménite, pierre) >= 10
        au zoom 1 ; N3 contraste au sol ilménite >= fer aux zooms 1 et 2 ; N4 pixels clairs ilménite >= 2 × fer aux
        zooms 1 et 2 ; N6 ΔE76(ilménite, tungstène) >= 10 aux zooms 1 et 2.
  JOUR  J1 ΔE76(ilménite, fer) >= 10 aux zooms 1 et 2 ; J2 ΔE76(ilménite, charbon) >= 8 au zoom 1 ; J3 ΔE76(ilménite,
        tungstène) >= 10 aux zooms 1 et 2 ; J4 ΔE76(ilménite, pierre) >= 8 au zoom 1.
Code 0 si tout passe, 1 sinon.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "render", "pieces", "ressources"))
from lisibilite_moteur import mesurer, de  # noqa: E402

W, H = 1600, 900
Z1 = {"fer": (448, 274), "ilmenite": (800, 274), "tungstene": (1152, 274), "charbon": (448, 626),
      "pierre": (800, 626), "uranium": (1152, 626)}
Z1_SOL = (slice(440, 470), slice(600, 660))
Z2_SOL = (slice(780, 840), slice(760, 840))


def trouve(dossier, scene):
    for fn in sorted(os.listdir(dossier)):
        if fn.endswith("-" + scene + ".png"):
            return os.path.join(dossier, fn)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("captures")
    ap.add_argument("--json")
    a = ap.parse_args()
    scenes = {"z1-jour": "planche-crateres-z1-jour", "z1-nuit": "planche-crateres-z1-nuit",
              "z2-fer-jour": "crateres-fer-ilmenite-z2-jour", "z2-fer-nuit": "crateres-fer-ilmenite-z2-nuit",
              "z2-w-jour": "crateres-ilmenite-tungstene-z2-jour", "z2-w-nuit": "crateres-ilmenite-tungstene-z2-nuit"}
    im = {}
    for k, sc in scenes.items():
        p = trouve(a.captures, sc)
        if not p:
            print("[FO-X1-LISIBILITE] ECHEC capture absente : %s" % sc)
            sys.exit(1)
        im[k] = np.asarray(Image.open(p).convert("RGB")).astype(np.float64)
        if im[k].shape[:2] != (H, W):
            print("[FO-X1-LISIBILITE] ECHEC %s : %s au lieu de 1600 x 900" % (p, im[k].shape[:2]))
            sys.exit(1)
    m = {}
    for k in ("z1-jour", "z1-nuit"):
        m[k] = mesurer(im[k], Z1, Z1_SOL, 120)
    for k in ("z2-fer-jour", "z2-fer-nuit"):
        m[k] = mesurer(im[k], {"fer": (448, 450), "ilmenite": (1152, 450)}, Z2_SOL, 250)
    for k in ("z2-w-jour", "z2-w-nuit"):
        m[k] = mesurer(im[k], {"ilmenite": (448, 450), "tungstene": (1152, 450)}, Z2_SOL, 250)
    for k, r in m.items():
        t = r["ilmenite"]["moy"]
        r["dE"] = {v: de(t, r[v]["moy"]) for v in r if v not in ("sol", "ilmenite", "dE")}
        print("[FO-X1-LISIBILITE] %-12s sol %s | %s | ΔE76 ilménite / %s" % (
            k, r["sol"], " | ".join("%s moy %s contraste %.1f clairs %.2f %%" % (
                v, r[v]["moy"], r[v]["contraste"], 100 * r[v]["clairs"]) for v in r if v not in ("sol", "dE")),
            ", ".join("%s %.1f" % (v, d) for v, d in r["dE"].items())))
    for k in ("z1-jour", "z1-nuit"):
        r = m[k]
        van = ("fer", "charbon", "pierre", "uranium", "tungstene")
        paires = ["%s/%s %.1f" % (x, y, de(r[x]["moy"], r[y]["moy"])) for i, x in enumerate(van) for y in van[i + 1:]]
        print("[FO-X1-LISIBILITE] référence (même sol) %-8s ΔE76 : %s" % (k, ", ".join(paires)))
    ok, ko, lignes = 0, 0, []

    def check(c, quoi):
        nonlocal ok, ko
        ok, ko = ok + (1 if c else 0), ko + (0 if c else 1)
        lignes.append("[FO-X1-LISIBILITE] %s %s" % ("OK    " if c else "ECHEC ", quoi))

    n1, nf, nw = m["z1-nuit"], m["z2-fer-nuit"], m["z2-w-nuit"]
    j1, jf, jw = m["z1-jour"], m["z2-fer-jour"], m["z2-w-jour"]
    check(n1["dE"]["fer"] >= 10 and nf["dE"]["fer"] >= 10,
          "N1 nuit : ΔE76 ilménite / fer >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (n1["dE"]["fer"], nf["dE"]["fer"]))
    check(n1["dE"]["charbon"] >= 10 and n1["dE"]["pierre"] >= 10,
          "N2 nuit, zoom 1 : ΔE76 ilménite / charbon >= 10 (%.1f) et / pierre >= 10 (%.1f)" % (n1["dE"]["charbon"], n1["dE"]["pierre"]))
    check(n1["ilmenite"]["contraste"] >= n1["fer"]["contraste"] and nf["ilmenite"]["contraste"] >= nf["fer"]["contraste"],
          "N3 nuit : contraste au sol ilménite >= fer (zoom 1 : %.1f / %.1f ; zoom 2 : %.1f / %.1f)" % (
              n1["ilmenite"]["contraste"], n1["fer"]["contraste"], nf["ilmenite"]["contraste"], nf["fer"]["contraste"]))
    check(n1["ilmenite"]["clairs"] >= 2 * n1["fer"]["clairs"] and nf["ilmenite"]["clairs"] >= 2 * nf["fer"]["clairs"],
          "N4 nuit : pixels clairs ilménite >= 2 x fer (zoom 1 : %.2f %% / %.2f %% ; zoom 2 : %.2f %% / %.2f %%)" % (
              100 * n1["ilmenite"]["clairs"], 100 * n1["fer"]["clairs"], 100 * nf["ilmenite"]["clairs"], 100 * nf["fer"]["clairs"]))
    check(n1["dE"]["tungstene"] >= 10 and nw["dE"]["tungstene"] >= 10,
          "N6 nuit : ΔE76 ilménite / tungstène >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (n1["dE"]["tungstene"], nw["dE"]["tungstene"]))
    check(j1["dE"]["fer"] >= 10 and jf["dE"]["fer"] >= 10,
          "J1 jour : ΔE76 ilménite / fer >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (j1["dE"]["fer"], jf["dE"]["fer"]))
    check(j1["dE"]["charbon"] >= 8, "J2 jour, zoom 1 : ΔE76 ilménite / charbon >= 8 (%.1f)" % j1["dE"]["charbon"])
    check(j1["dE"]["tungstene"] >= 10 and jw["dE"]["tungstene"] >= 10,
          "J3 jour : ΔE76 ilménite / tungstène >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (j1["dE"]["tungstene"], jw["dE"]["tungstene"]))
    check(j1["dE"]["pierre"] >= 8, "J4 jour, zoom 1 : ΔE76 ilménite / pierre >= 8 (%.1f)" % j1["dE"]["pierre"])
    for l in lignes:
        print(l)
    print("[FO-X1-LISIBILITE] BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"mesures": m, "ok": ok, "echecs": ko}, f, indent=1, ensure_ascii=False)
    sys.exit(0 if ko == 0 else 1)


if __name__ == "__main__":
    main()
