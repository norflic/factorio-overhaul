"""Lisibilité de la MONAZITE mesurée sur les CAPTURES EN MOTEUR du scénario greffé x2-supra (lot X2, 25/10).
Python système (py -3.9). Méthode et mesures du lot M1 (tools/render/pieces/ressources/lisibilite_moteur.py : disque
autour de chaque gisement, contraste au sol, pixels clairs, ΔE76 Lab D65), géométrie de x1_lisibilite.py (écran
1600 × 900, planches de 3 × 2 gisements de 9 × 9 à 11 tuiles, zoom 1 ; paires au zoom 2).

    py -3.9 tools/autotest/x2_lisibilite.py "<dossier des captures de fo-captures.bat x2-supra>" [--json sortie.json]

Planches, TOUTES sur le sol des sables noirs : « sables » (rangée du haut fer, MONAZITE, cuivre ; du bas charbon, pierre,
uranium) et « mod » (haut tungstène, MONAZITE, ilménite ; bas cristal, pierre, cuivre). Zoom 2 : monazite à côté du
cuivre, du fer, de l'ilménite.

Critères, écrits AVANT les premières captures (25/10, lot X2) :
  JOUR  J1 ΔE76(monazite, cuivre) >= 10 aux zooms 1 et 2 ; J2 (monazite, pierre) >= 10 au zoom 1 ; J3 (monazite, fer)
        >= 10 aux zooms 1 et 2 ; J4 (monazite, charbon) >= 10 et (monazite, uranium) >= 10 au zoom 1 ; J5 (monazite,
        ilménite) >= 10 aux zooms 1 et 2 ; J6 (monazite, tungstène) >= 10 au zoom 1.
  NUIT  N1 (monazite, cuivre) >= 10 aux zooms 1 et 2 ; N2 (monazite, pierre) >= 10 au zoom 1 ; N3 (monazite, fer) >= 10
        aux zooms 1 et 2 ; N4 (monazite, ilménite) >= 10 aux zooms 1 et 2, (monazite, tungstène) >= 10 au zoom 1 ;
        N5 contraste au sol monazite >= fer au zoom 1 (elle se voit) ;
        N6 PAS le défaut de l'ilménite (trop claire la nuit) : luminance de nuit de la monazite <= celle de l'ilménite
        (planche mod, zoom 1) ET rapport nuit / jour de la monazite <= 1,25 × celui du cuivre (aucune lueur au-delà
        d'un minerai ordinaire).
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
from lisibilite_moteur import mesurer, de, LUM  # noqa: E402

W, H = 1600, 900
Z1_SABLES = {"fer": (448, 274), "monazite": (800, 274), "cuivre": (1152, 274), "charbon": (448, 626),
             "pierre": (800, 626), "uranium": (1152, 626)}
Z1_MOD = {"tungstene": (448, 274), "monazite": (800, 274), "ilmenite": (1152, 274), "cristal": (448, 626),
          "pierre": (800, 626), "cuivre": (1152, 626)}
Z1_SOL = (slice(440, 470), slice(600, 660))
Z2_SOL = (slice(780, 840), slice(760, 840))


def trouve(dossier, scene):
    for fn in sorted(os.listdir(dossier)):
        if fn.endswith("-" + scene + ".png"):
            return os.path.join(dossier, fn)
    return None


def lum(rgb):
    return float(np.array(rgb) @ LUM)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("captures")
    ap.add_argument("--json")
    a = ap.parse_args()
    scenes = {}
    for moment in ("jour", "nuit"):
        scenes["sables-" + moment] = "planche-sables-z1-" + moment
        scenes["mod-" + moment] = "planche-mod-z1-" + moment
        scenes["z2cu-" + moment] = "monazite-cuivre-z2-" + moment
        scenes["z2fe-" + moment] = "fer-monazite-z2-" + moment
        scenes["z2il-" + moment] = "monazite-ilmenite-z2-" + moment
    im = {}
    for k, sc in scenes.items():
        p = trouve(a.captures, sc)
        if not p:
            print("[FO-X2-LISIBILITE] ECHEC capture absente : %s" % sc)
            sys.exit(1)
        im[k] = np.asarray(Image.open(p).convert("RGB")).astype(np.float64)
        if im[k].shape[:2] != (H, W):
            print("[FO-X2-LISIBILITE] ECHEC %s : %s au lieu de 1600 x 900" % (p, im[k].shape[:2]))
            sys.exit(1)
    m = {}
    for moment in ("jour", "nuit"):
        m["sables-" + moment] = mesurer(im["sables-" + moment], Z1_SABLES, Z1_SOL, 120)
        m["mod-" + moment] = mesurer(im["mod-" + moment], Z1_MOD, Z1_SOL, 120)
        m["z2cu-" + moment] = mesurer(im["z2cu-" + moment], {"monazite": (448, 450), "cuivre": (1152, 450)}, Z2_SOL, 250)
        m["z2fe-" + moment] = mesurer(im["z2fe-" + moment], {"fer": (448, 450), "monazite": (1152, 450)}, Z2_SOL, 250)
        m["z2il-" + moment] = mesurer(im["z2il-" + moment], {"monazite": (448, 450), "ilmenite": (1152, 450)}, Z2_SOL, 250)
    for k, r in m.items():
        t = r["monazite"]["moy"]
        r["dE"] = {v: de(t, r[v]["moy"]) for v in r if v not in ("sol", "monazite", "dE")}
        print("[FO-X2-LISIBILITE] %-12s sol %s | %s | ΔE76 monazite / %s" % (
            k, r["sol"], " | ".join("%s moy %s contraste %.1f clairs %.2f %%" % (
                v, r[v]["moy"], r[v]["contraste"], 100 * r[v]["clairs"]) for v in r if v not in ("sol", "dE")),
            ", ".join("%s %.1f" % (v, d) for v, d in r["dE"].items())))
    ok, ko, lignes = 0, 0, []

    def check(c, quoi):
        nonlocal ok, ko
        ok, ko = ok + (1 if c else 0), ko + (0 if c else 1)
        lignes.append("[FO-X2-LISIBILITE] %s %s" % ("OK    " if c else "ECHEC ", quoi))

    for moment, L in (("jour", "J"), ("nuit", "N")):
        s, md = m["sables-" + moment], m["mod-" + moment]
        cu, fe, il = m["z2cu-" + moment], m["z2fe-" + moment], m["z2il-" + moment]
        check(s["dE"]["cuivre"] >= 10 and cu["dE"]["cuivre"] >= 10,
              "%s1 %s : ΔE76 monazite / cuivre >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (L, moment, s["dE"]["cuivre"], cu["dE"]["cuivre"]))
        check(s["dE"]["pierre"] >= 10, "%s2 %s, zoom 1 : ΔE76 monazite / pierre >= 10 (%.1f)" % (L, moment, s["dE"]["pierre"]))
        check(s["dE"]["fer"] >= 10 and fe["dE"]["fer"] >= 10,
              "%s3 %s : ΔE76 monazite / fer >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (L, moment, s["dE"]["fer"], fe["dE"]["fer"]))
        if moment == "jour":
            check(s["dE"]["charbon"] >= 10 and s["dE"]["uranium"] >= 10,
                  "J4 jour, zoom 1 : ΔE76 monazite / charbon >= 10 (%.1f) et / uranium >= 10 (%.1f)" % (s["dE"]["charbon"], s["dE"]["uranium"]))
            check(md["dE"]["ilmenite"] >= 10 and il["dE"]["ilmenite"] >= 10,
                  "J5 jour : ΔE76 monazite / ilménite >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f)" % (md["dE"]["ilmenite"], il["dE"]["ilmenite"]))
            check(md["dE"]["tungstene"] >= 10, "J6 jour, zoom 1 : ΔE76 monazite / tungstène >= 10 (%.1f)" % md["dE"]["tungstene"])
        else:
            check(md["dE"]["ilmenite"] >= 10 and il["dE"]["ilmenite"] >= 10 and md["dE"]["tungstene"] >= 10,
                  "N4 nuit : ΔE76 monazite / ilménite >= 10 (zoom 1 : %.1f ; zoom 2 : %.1f) et / tungstène >= 10 (%.1f)" % (
                      md["dE"]["ilmenite"], il["dE"]["ilmenite"], md["dE"]["tungstene"]))
            check(s["monazite"]["contraste"] >= s["fer"]["contraste"],
                  "N5 nuit, zoom 1 : contraste au sol monazite >= fer (%.1f / %.1f)" % (s["monazite"]["contraste"], s["fer"]["contraste"]))
            lmz, lil = lum(md["monazite"]["moy"]), lum(md["ilmenite"]["moy"])
            rmz = lum(m["sables-nuit"]["monazite"]["moy"]) / max(1e-6, lum(m["sables-jour"]["monazite"]["moy"]))
            rcu = lum(m["sables-nuit"]["cuivre"]["moy"]) / max(1e-6, lum(m["sables-jour"]["cuivre"]["moy"]))
            check(lmz <= lil and rmz <= 1.25 * rcu,
                  "N6 nuit : pas trop claire (luminance monazite %.1f <= ilménite %.1f ; nuit / jour monazite %.3f <= 1,25 x cuivre %.3f)" % (
                      lmz, lil, rmz, rcu))
    for l in lignes:
        print(l)
    print("[FO-X2-LISIBILITE] BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"mesures": m, "ok": ok, "echecs": ko}, f, indent=1, ensure_ascii=False)
    sys.exit(0 if ko == 0 else 1)


if __name__ == "__main__":
    main()
