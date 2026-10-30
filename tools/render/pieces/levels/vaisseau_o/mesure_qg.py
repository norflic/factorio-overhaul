"""MESURES DU BRIEF QG (30/10) sur nos sprites et sur le vanilla, au même instrument (tools/da/da_lib.measure, plus
« damier » et « découpe » du script de diagnostic fo-logs/2026-10-30_QG/mesure_qg.py), avec l'ORIGINE VRAIE du
sprite (lue au shift du spec.json ; le diagnostic prenait le centre de l'image). Rend un tableau et un verdict par
cible (plancher / cible du brief §3).

    py -3.9 tools/render/pieces/levels/vaisseau_o/mesure_qg.py --src <sprites> --noms qg00 [--json sortie.json]
"""
import argparse
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "da")))
import da_lib as D  # noqa: E402

DATA = os.environ.get("FO_DATA_DIR", r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
ENT = os.path.join(DATA, "base", "graphics", "entity")
VAN = {"V epave vaisseau": ("crash-site-spaceship/hr-spaceship.png", None, (-13, 34), (15.6, 7.8)),
       "V raffinerie": ("oil-refinery/hr-oil-refinery.png", (386, 430), (0, -7.5), (5, 5))}

# (clé, libellé, plancher, cible, sens) ; sens +1 : plus haut vaut mieux, -1 : plus bas, 0 : intervalle
CIBLES = [("pieces_t2", "pièces/t² (D3)", 24.0, 29.0, 1), ("pieces_masse", "pièces ÷ masse", 25.0, 25.0, 1),
          ("contours", "contours (D5)", 0.24, 0.32, 1), ("contraste", "contraste local (D4)", 18.0, 25.0, 1),
          ("noir25", "noir < 25", 0.15, 0.25, 1), ("p05", "L p05", 10.0, 10.0, -1), ("p50", "L p50", (43.0, 58.0), None, 0),
          ("p95", "L p95", (160.0, 200.0), None, 0), ("sat", "saturation", 0.40, 0.50, 1),
          ("sat_hors", "saturé hors lumineux", 0.04, 0.04, -1), ("remplissage", "remplissage emprise (M2)", 0.75, 0.75, 1),
          ("decoupe", "découpe (épave ≥ 2,0)", 2.0, 2.2, 1), ("damier", "damier", 0.45, 0.45, -1),
          ("foyers", "foyers lumineux (corps)", (3.0, 8.0), None, 0), ("zone_lum", "zone lumineuse", 0.06, 0.06, -1)]


def extra(body):
    a = body[..., 3]
    M = a >= 0.5
    rgb = body[..., :3]
    L = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) * 255.0
    Mi = D.erode(M, 5)
    sm = D.sobel_mag(D.gblur(L, 0.7))
    sizes, _ = D.components(Mi & (sm <= 12.0), conn8=False)
    vals = np.array(list(sizes.values()) or [0])
    t2 = 64.0 * 64.0
    moy = int(((vals >= 0.06 * t2) & (vals <= 1.0 * t2)).sum())
    edge = M & ~D.erode(M, 3)
    per = edge.sum() / 3.0
    return moy, float(per * per / (4 * np.pi * max(1, M.sum())))


def sources_glow(path):
    if not path or not os.path.exists(path):
        return 0
    gl = D.load_rgba(path)
    e = gl[..., 3] * gl[..., :3].max(axis=2)
    sz, _ = D.components(e > 0.25, conn8=True)
    return sum(1 for v in sz.values() if v >= 4)


def mesurer(body, origin, emp, nom, glow=None):
    comp = {"body": body, "origin": origin, "emis": np.zeros(body.shape[:2], np.float32)}
    comp["halo"] = comp["team"] = comp["emis"]
    r = D.measure(comp, emp, nom)
    moy, dec = extra(body)
    m = r["masse_tuiles2"]
    return {"nom": nom, "masse": m, "pieces": r["petites_pieces"], "pieces_t2": r["petites_pieces_par_tuile2"],
            "pieces_masse": r["petites_pieces"] / max(m, 1e-6), "contours": r["part_contours"],
            "contraste": r["contraste_local_7px"], "noir25": r["part_tres_sombre_lt25"], "p05": r["lum_p5"],
            "p50": r["lum_p50"], "p95": r["lum_p95"], "sat": r["saturation_moyenne"],
            "sat_hors": r["part_saturee_hors_lumineux"], "remplissage": r["remplissage_emprise"], "decoupe": dec,
            "damier": moy / max(m, 1e-6), "foyers": r["foyers_lumineux"], "zone_lum": r["zone_lumineuse_part"],
            "depassement_haut": r["O_depassement_haut"], "sources_glow": sources_glow(glow)}


def verdict(v, plancher, cible, sens):
    if sens == 0:
        lo, hi = plancher
        return "OK" if lo <= v <= hi else "ÉCHEC"
    if sens > 0:
        return "cible" if v >= cible else ("OK" if v >= plancher else "ÉCHEC")
    return "OK" if v <= plancher else "ÉCHEC"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--noms", default="qg00")
    ap.add_argument("--emprise", default="8x4")
    ap.add_argument("--json", default="")
    ap.add_argument("--sans-vanilla", action="store_true")
    a = ap.parse_args()
    emp = tuple(float(x) for x in a.emprise.split("x"))
    rows = []
    if not a.sans_vanilla:
        for nom, (f, crop, sh, e) in VAN.items():
            body = D.load_rgba(os.path.join(ENT, f))
            if crop:
                body = body[:crop[1], :crop[0]]
            body = body.copy()
            H, W = body.shape[:2]
            rows.append(mesurer(body, (W / 2.0 - sh[0] * 2, H / 2.0 - sh[1] * 2), e, nom))
    for n in [x for x in a.noms.split(",") if x]:
        d = os.path.join(a.src, n)
        spec = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
        L = spec["layers"]["main"]
        body = D.load_rgba(os.path.join(d, L["file"])).copy()
        H, W = body.shape[:2]
        org = (W / 2.0 - L["shift"][0] * 64, H / 2.0 - L["shift"][1] * 64)
        g = spec["layers"].get("glow")
        rows.append(mesurer(body, org, emp, n, os.path.join(d, g["file"]) if g else None))
    print("| mesure | " + " | ".join(r["nom"] for r in rows) + " | plancher → cible | verdict (dernier) |")
    print("|---|" + "---|" * (len(rows) + 2))
    print("| masse t² | " + " | ".join("%.1f" % r["masse"] for r in rows) + " | | |")
    print("| pièces | " + " | ".join("%d" % r["pieces"] for r in rows) + " | | |")
    for k, lib, pl, ci, sens in CIBLES:
        cell = (("%g à %g" % pl) if sens == 0 else ("≤ %g" % pl if sens < 0 else "%g → %g" % (pl, ci)))
        v = rows[-1][k]
        print("| %s | %s | %s | %s |" % (lib, " | ".join("%.3g" % r[k] for r in rows), cell, verdict(v, pl, ci, sens)))
    print("| dépassement haut (t) | " + " | ".join("%.2f" % r["depassement_haut"] for r in rows) + " | | |")
    print("| sources de lueur | " + " | ".join("%d" % r["sources_glow"] for r in rows) + " | | |")
    if a.json:
        json.dump(rows, open(a.json, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
