"""MESURES DU BRIEF QG (30/10) sur un état rendu, à côté de l'épave vanilla et de la raffinerie, avec le verdict par
plancher. Mêmes fonctions que fo-logs/2026-10-30_QG/mesure_qg.py (tools/da/da_lib.measure, corps alpha ≥ 0,5,
64 px/tuile ; « damier » et « découpe » recopiés de mesure_qg.extra), plus les foyers DOMINANTS (composantes de la
couche lueur ≥ 0,05 tuile²) et le contrôle « nez à droite » (centre de la lueur du cœur et masse à droite).

    py -3.9 tools/render/pieces/levels/vaisseau_o/mesure15.py --src <sprites> --noms age15[,age15g] [--autres o7=<dir>]
        [--emprise 16x8] [--json sortie.json]
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(MOD, "tools", "da"))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "commun"))
import da_lib as D  # noqa: E402
import compo as K  # noqa: E402

V = os.path.join(K.DATA, "base", "graphics", "entity")
VAN = [("V épave vaisseau", "crash-site-spaceship/hr-spaceship.png", None, (15.6, 7.8)),
       ("V raffinerie", "oil-refinery/hr-oil-refinery.png", (386, 430), (5, 5))]

# (clé, libellé, plancher, cible, sens) ; sens +1 : au moins, −1 : au plus, 0 : intervalle (plancher, cible) = (min, max)
CRIT = [("d3", "pièces/t²", 24.0, 29.0, 1), ("pieces_masse", "pièces / masse", 25.0, 25.0, 1), ("d5", "contours", 0.24, 0.32, 1),
        ("d4", "contraste local", 18.0, 25.0, 1), ("noir", "noir<25", 0.15, 0.25, 1), ("p05", "L p05", 10.0, 10.0, -1),
        ("p50", "L p50", 43.0, 58.0, 0), ("p95", "L p95", 160.0, 200.0, 0), ("sat", "saturation", 0.40, 0.50, 1),
        ("sat_hors", "saturé hors lumineux", 0.04, 0.04, -1), ("m2", "remplissage emprise", 0.75, 0.75, 1),
        ("decoupe", "découpe", 1.6, 2.2, 1), ("damier", "damier", 0.45, 0.45, -1), ("foyers_dom", "foyers dominants", 3, 8, 0),
        ("zone_lum", "zone lumineuse", 0.06, 0.06, -1)]


def extra(body):
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


def ligne(nom, comp, emp, glow=None):
    r = D.measure(comp, emp, nom)
    moy, sil = extra(comp["body"])
    m = r["masse_tuiles2"]
    dom = tot = 0
    if glow is not None:
        e = glow[..., 3] * glow[..., :3].max(axis=2)
        sz, _ = D.components(e > 0.25, conn8=True)
        tot = sum(1 for v in sz.values() if v >= 4)
        dom = sum(1 for v in sz.values() if v >= 0.05 * 64 * 64)
    body = comp["body"]
    ys, xs = np.nonzero(body[..., 3] >= 0.5)
    ox = comp["origin"][0]
    droite = float((xs > ox).mean())
    return {"nom": nom, "emprise": "%gx%g" % emp, "masse": m, "d3": r["petites_pieces_par_tuile2"], "pieces": r["petites_pieces"],
            "pieces_masse": r["petites_pieces"] / max(1e-6, m), "d5": r["part_contours"], "d4": r["contraste_local_7px"],
            "noir": r["part_tres_sombre_lt25"], "p05": r["lum_p5"], "p50": r["lum_p50"], "p95": r["lum_p95"],
            "sat": r["saturation_moyenne"], "sat_hors": r["part_saturee_hors_lumineux"], "m2": r["remplissage_emprise"],
            "decoupe": sil, "damier": moy / max(1e-6, m), "foyers_main": r["foyers_lumineux"], "foyers_dom": dom, "sources_glow": tot,
            "zone_lum": r["zone_lumineuse_part"], "O_haut": r["O_depassement_haut"], "part_masse_droite": droite,
            "teinte_chaude": r["part_teinte_chaude_corps"], "quasi_blanc": r["part_quasi_blanc"]}


def verdict(row):
    out = []
    for k, lib, lo, hi, sens in CRIT:
        v = row[k]
        if sens > 0:
            ok, cible = v >= lo, v >= hi
        elif sens < 0:
            ok, cible = v <= lo, v <= hi
        else:
            ok = cible = lo <= v <= hi
        out.append((lib, v, "OK" if cible else ("plancher" if ok else "ÉCHEC")))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--noms", default="age15")
    ap.add_argument("--autres", default="")
    ap.add_argument("--emprise", default="16x8")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    emp = tuple(float(x) for x in a.emprise.split("x"))
    autres = dict(x.split("=", 1) for x in a.autres.split(",") if x)
    rows = []
    for nom, f, crop, e in VAN:
        img = D.load_rgba(os.path.join(V, f))
        if crop:
            img = img[:crop[1], :crop[0]]
        img = img.copy()
        H, W = img.shape[:2]
        z = np.zeros((H, W), np.float32)
        rows.append(ligne(nom, {"body": img, "origin": (W / 2.0, H / 2.0), "emis": z, "halo": z, "team": z}, e))
    for n in [x for x in a.noms.split(",") if x]:
        src = a.src
        if ":" in n:
            pre, n2 = n.split(":", 1)
            src, nn = autres[pre], n2
        else:
            nn = n
        lays = K.own(src, nn, ("main", "glow"))
        comp = K.body_comp(lays)
        glow = [l["img"] for l in lays if l["kind"] == "glow"]
        rows.append(ligne(n, comp, emp, glow[0] if glow else None))
    keys = ["masse", "d3", "pieces", "pieces_masse", "d5", "d4", "noir", "p05", "p50", "p95", "sat", "sat_hors", "m2", "decoupe",
            "damier", "foyers_main", "foyers_dom", "sources_glow", "zone_lum", "O_haut", "part_masse_droite"]
    print("| état | " + " | ".join(keys) + " |")
    for r in rows:
        print("| %s | " % r["nom"] + " | ".join(("%.3f" % r[k]) if isinstance(r[k], float) else str(r[k]) for k in keys) + " |")
    for r in rows[len(VAN):]:
        v = verdict(r)
        ech = [x for x in v if x[2] == "ÉCHEC"]
        print("\n%s : %d plancher(s) en échec sur %d" % (r["nom"], len(ech), len(v)))
        for lib, val, st in v:
            print("  %-22s %8.3f  %s" % (lib, val, st))
        r["verdict"] = v
    if a.json:
        json.dump(rows, open(a.json, "w", encoding="utf-8"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
