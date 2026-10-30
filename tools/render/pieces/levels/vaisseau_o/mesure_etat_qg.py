"""MESURE D'UN ÉTAT DU QG contre le vanilla, avec les MÊMES fonctions que le brief (fo-logs/2026-10-30_QG/mesure_qg.py,
tools/da/da_lib.measure) et ses cibles chiffrées (BRIEF §3). Python 3.9.

    py -3.9 mesure_etat_qg.py --src <dossier de rendre.py> --nom qg01 --emprise 8x4
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

R = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
V = R + r"\data\base\graphics\entity"
VAN = [("V epave", V + r"\crash-site-spaceship\hr-spaceship.png", None, (15.6, 7.8)),
       ("V raffinerie", V + r"\oil-refinery\hr-oil-refinery.png", (386, 430), (5, 5)),
       ("V roboport", V + r"\roboport\hr-roboport-base.png", None, (4, 4))]
# (clé, libellé, plancher, cible, sens) ; sens +1 : au moins, -1 : au plus, 0 : intervalle (plancher, cible)
CIBLES = [("petites_pieces_par_tuile2", "D3 pièces/t²", 24, 29, 1), ("part_contours", "D5 contours", 0.24, 0.32, 1),
          ("contraste_local_7px", "D4 contraste", 18, 25, 1), ("part_tres_sombre_lt25", "noir<25", 0.15, 0.25, 1),
          ("lum_p5", "p05", None, 10, -1), ("lum_p50", "p50", 43, 58, 0), ("lum_p95", "p95", 160, 200, 0),
          ("saturation_moyenne", "saturation", 0.40, 0.50, 1), ("part_saturee_hors_lumineux", "part saturée hors lum.", None, 0.04, -1),
          ("remplissage_emprise", "M2 remplissage", 0.75, 0.75, 1), ("decoupe", "découpe", 1.6, 2.2, 1),
          ("damier", "damier", None, 0.45, -1), ("zone_lumineuse_part", "zone lumineuse", None, 0.06, -1)]


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


def mesurer(nom, main, crop, emp, glow=None):
    body = D.load_rgba(main)
    if crop:
        body = body[:crop[1], :crop[0]].copy()
    H, Wd = body.shape[:2]
    emis = np.zeros((H, Wd), np.float32)
    ng = 0
    if glow and os.path.exists(glow):
        gl = D.load_rgba(glow)
        e = gl[..., 3] * gl[..., :3].max(axis=2)
        sz, _ = D.components(e > 0.25, conn8=True)
        ng = sum(1 for v in sz.values() if v >= 4)
    comp = {"body": body, "origin": (Wd / 2.0, H / 2.0), "emis": emis, "halo": emis, "team": emis}
    r = D.measure(comp, emp, nom)
    moy, sil = extra(body)
    r["damier"] = moy / max(r["masse_tuiles2"], 1e-6)
    r["decoupe"] = sil
    r["sources_glow"] = ng
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--nom", default="qg01")
    ap.add_argument("--emprise", default="8x4")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    emp = tuple(float(q) for q in a.emprise.split("x"))
    spec = json.load(open(os.path.join(a.src, a.nom, "spec.json"), encoding="utf-8"))
    main_p = os.path.join(a.src, a.nom, spec["layers"]["main"]["file"])
    glow_p = os.path.join(a.src, a.nom, spec["layers"]["glow"]["file"]) if "glow" in spec["layers"] else None
    rows = [(n, mesurer(n, p, c, e)) for n, p, c, e in VAN]
    rows.append((a.nom, mesurer(a.nom, main_p, None, emp, glow_p)))
    print("%-24s" % "mesure" + "".join("%14s" % n[:13] for n, _ in rows) + "   plancher → cible")
    bilan = []
    for k, lib, pl, ci, sens in CIBLES:
        vals = [r.get(k, float("nan")) for _, r in rows]
        v = vals[-1]
        if sens > 0:
            ok = pl is None or v >= pl
        elif sens < 0:
            ok = v <= ci
        else:
            ok = pl <= v <= ci
        bilan.append((lib, ok))
        print("%-24s" % lib + "".join("%14.3f" % x for x in vals) + "   %s → %s  %s" % (pl, ci, "OK" if ok else "ÉCHEC"))
    r = rows[-1][1]
    print("masse %.1f t², pièces %d, sources glow %d" % (r["masse_tuiles2"], r["petites_pieces"], r["sources_glow"]))
    print("BILAN : %d plancher(s) OK sur %d ; échecs : %s" % (sum(1 for _, o in bilan if o), len(bilan),
                                                            ", ".join(l for l, o in bilan if not o) or "aucun"))
    if a.json:
        json.dump({n: {k: (float(v) if isinstance(v, (int, float, np.floating)) else str(v)) for k, v in rr.items()} for n, rr in rows},
                  open(a.json, "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
