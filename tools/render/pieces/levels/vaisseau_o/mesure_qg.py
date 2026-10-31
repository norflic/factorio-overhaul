"""MESURES DU BRIEF QG (30/10) sur un état rendu, contre l'épave vanilla et la raffinerie : mêmes définitions que
fo-logs/2026-10-30_QG/mesure_qg.py (tools/da/da_lib.measure, corps alpha >= 0,5, 64 px par tuile, « damier » =
plages de 0,06 à 1 t² bornées par des arêtes, par t² de corps ; découpe = périmètre² / 4π aire), plus les planchers
et cibles du brief, critère par critère. Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/vaisseau_o/mesure_qg.py --src <sprites> --nom qg08 --emprise 12x6 [--json f.json]

ATTENTION (brief, DA §2.3) : à 8-12 échantillons, le bruit gonfle les pièces et les contours (scores flattés) ;
seul un rendu d'au moins 32 échantillons, débruité, fait foi.
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(MOD, "tools", "da"))
import da_lib as D  # noqa: E402

DATA = os.environ.get("FO_DATA_DIR", r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data")
V = os.path.join(DATA, "base", "graphics", "entity")
VAN = [("V épave vaisseau", os.path.join(V, "crash-site-spaceship", "hr-spaceship.png"), None, (15.6, 7.8)),
       ("V raffinerie", os.path.join(V, "oil-refinery", "hr-oil-refinery.png"), (386, 430), (5, 5))]

# (clé, libellé, plancher, cible, sens) : sens +1 = plus haut est mieux, -1 = plus bas est mieux, 0 = intervalle
CRIT = [("D3", "pièces/t²", 24.0, 29.0, 1), ("pieces_masse", "pièces / masse", 25.0, 25.0, 1),
        ("D5", "contours", 0.24, 0.32, 1), ("D4", "contraste local", 18.0, 25.0, 1),
        ("noir", "noir < 25", 0.15, 0.25, 1), ("p05", "L p05", 10.0, 10.0, -1),
        ("p50", "L p50", (43.0, 58.0), None, 0), ("p95", "L p95", (160.0, 200.0), None, 0),
        ("sat", "saturation", 0.40, 0.50, 1), ("sat_hors", "saturée hors lumineux", 0.04, 0.04, -1),
        ("M2", "M2 masse/t² emprise", 0.75, 0.75, 1), ("decoupe", "découpe", 1.6, 2.2, 1),
        ("damier", "damier", 0.45, 0.45, -1), ("foyers", "foyers dominants", (3, 8), None, 0),
        ("zone_lum", "zone lumineuse", 0.06, 0.06, -1)]


def extra(body):
    """Damier et découpe : copie exacte de fo-logs/2026-10-30_QG/mesure_qg.py."""
    a = body[..., 3]
    M = a >= 0.5
    rgb = body[..., :3]
    L = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) * 255.0
    Mi = D.erode(M, 5)
    sm = D.sobel_mag(D.gblur(L, 0.7))
    reg = Mi & (sm <= 12.0)
    sizes, _ = D.components(reg, conn8=False)
    vals = np.array(list(sizes.values()) or [0])
    t2 = 64.0 * 64.0
    moy = int(((vals >= 0.06 * t2) & (vals <= 1.0 * t2)).sum())
    edge = M & ~D.erode(M, 3)
    per = edge.sum() / 3.0
    sil = float(per * per / (4 * np.pi * max(1, M.sum())))
    return moy, sil


def foyers_glow(glow_path):
    """Foyers dominants de la couche lueur : composantes (lueur > 0,25) d'au moins 0,02 t² (82 px) ; et toutes les
    sources d'au moins 4 px (méthode du brief)."""
    if not glow_path or not os.path.exists(glow_path):
        return 0, 0
    gl = D.load_rgba(glow_path)
    e = gl[..., 3] * gl[..., :3].max(axis=2)
    sz, _ = D.components(e > 0.25, conn8=True)
    return sum(1 for v in sz.values() if v >= 82), sum(1 for v in sz.values() if v >= 4)


def mesure(nom, main, crop, emp, glow=None):
    body = D.load_rgba(main)
    if crop:
        body = body[:crop[1], :crop[0]].copy()
    H, W = body.shape[:2]
    z = np.zeros((H, W), np.float32)
    r = D.measure({"body": body, "origin": (W / 2.0, H / 2.0), "emis": z, "halo": z, "team": z}, emp, nom)
    moy, sil = extra(body)
    fd, fs = foyers_glow(glow)
    m = r["masse_tuiles2"]
    return {"nom": nom, "masse": m, "D3": r["petites_pieces_par_tuile2"], "pieces": r["petites_pieces"], "pieces_masse": r["petites_pieces"] / m,
            "D5": r["part_contours"], "D4": r["contraste_local_7px"], "noir": r["part_tres_sombre_lt25"], "p05": r["lum_p5"],
            "p50": r["lum_p50"], "p95": r["lum_p95"], "sat": r["saturation_moyenne"], "sat_hors": r["part_saturee_hors_lumineux"],
            "M2": r["masse_par_tuile_emprise"], "boite": r["remplissage_boite"], "decoupe": sil, "damier": moy / m, "foyers": fd, "sources": fs,
            "zone_lum": r["zone_lumineuse_part"], "depasse_haut": r["O_depassement_haut"], "brut": r}


def verdict(k, v):
    for (kk, lib, pl, ci, sens) in CRIT:
        if kk != k:
            continue
        if sens == 0:
            ok = pl[0] <= v <= pl[1]
            return ("OK" if ok else "ÉCHEC"), lib, "%g–%g" % pl
        if sens > 0:
            return ("OK" if v >= pl else "ÉCHEC") + (" (cible atteinte)" if v >= ci and ci != pl else ""), lib, "≥ %g (cible %g)" % (pl, ci)
        return ("OK" if v <= pl else "ÉCHEC"), lib, "≤ %g" % pl
    return "", k, ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--nom", default="qg08")
    ap.add_argument("--emprise", default="12x6")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    emp = tuple(float(x) for x in a.emprise.split("x"))
    spec = json.load(open(os.path.join(a.src, a.nom, "spec.json"), encoding="utf-8"))
    main_p = os.path.join(a.src, a.nom, spec["layers"]["main"]["file"])
    glow_p = os.path.join(a.src, a.nom, spec["layers"]["glow"]["file"]) if "glow" in spec["layers"] else None
    rows = [mesure(n, p, c, e) for (n, p, c, e) in VAN]
    rows.append(mesure(a.nom, main_p, None, emp, glow_p))
    keys = ["masse", "pieces", "D3", "pieces_masse", "D5", "D4", "noir", "p05", "p50", "p95", "sat", "sat_hors", "M2", "decoupe",
            "damier", "foyers", "sources", "zone_lum", "depasse_haut", "boite"]
    print("%-22s" % "mesure" + "".join("%18s" % r["nom"][:17] for r in rows) + "   verdict (plancher, cible)")
    echecs = []
    for k in keys:
        v = rows[-1][k]
        vd, lib, seuil = verdict(k, v)
        if vd.startswith("ÉCHEC"):
            echecs.append(lib)
        print("%-22s" % (lib if lib != k else k) + "".join("%18.3f" % r[k] for r in rows) + "   %s %s" % (vd, seuil))
    print("échantillons du rendu : %s ; planchers échoués : %d %s" % (spec.get("samples"), len(echecs), ", ".join(echecs)))
    if a.json:
        json.dump({"samples": spec.get("samples"), "rows": [{k: v for k, v in r.items() if k != "brut"} for r in rows],
                   "brut": rows[-1]["brut"], "echecs": echecs}, open(a.json, "w", encoding="utf-8"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
