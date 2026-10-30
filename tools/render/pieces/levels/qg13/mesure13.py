"""MESURE du QG âge 13 contre les cibles chiffrées du BRIEF QG (30/10, §3), avec la même mesure que mesure_qg.py
(tools/da/da_lib.measure : corps alpha ≥ 0,5, 64 px/tuile ; plages « damier », découpe, sources de lueur).

    py -3.9 tools/render/pieces/levels/qg13/mesure13.py <dossier de sprites> [nom=age13] [emprise=16x8]

Rappel (DA §2.3) : à 8-10 échantillons, le bruit FLATTE D3 et D1 ; seuls les rendus ≥ 32 échantillons font foi.
"""
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(MOD, "tools", "da"))
import da_lib as D  # noqa: E402


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
    noir = float((L[M] < 25).mean())
    return moy, sil, noir


def main():
    d = sys.argv[1]
    nom = sys.argv[2] if len(sys.argv) > 2 else "age13"
    emp = tuple(float(x) for x in (sys.argv[3] if len(sys.argv) > 3 else "16x8").split("x"))
    spec = json.load(open(os.path.join(d, nom, "spec.json"), encoding="utf-8"))
    body = D.load_rgba(os.path.join(d, nom, spec["layers"]["main"]["file"]))
    H, W = body.shape[:2]
    emis = np.zeros((H, W), np.float32)
    ng = 0
    if "glow" in spec["layers"]:
        gl = D.load_rgba(os.path.join(d, nom, spec["layers"]["glow"]["file"]))
        e = gl[..., 3] * gl[..., :3].max(axis=2)
        sz, _ = D.components(e > 0.25, conn8=True)
        ng = sum(1 for v in sz.values() if v >= 4)
        ngf = sum(1 for v in sz.values() if v >= 64)
        # foyers « vus » : composantes après fermeture de 10 px (un anneau coupé par ses bobines reste UN foyer)
        szd, _ = D.components(D.dilate(e > 0.25, 10), conn8=True)
        ngd = sum(1 for v in szd.values() if v >= 400)
        # lueur posée sur la grille du corps (même origine de l'entité) : zone lumineuse de jour
        sm, sg = spec["layers"]["main"], spec["layers"]["glow"]
        ox = int(round((sg["shift"][0] - sm["shift"][0]) * 64 + (W - gl.shape[1]) / 2.0))
        oy = int(round((sg["shift"][1] - sm["shift"][1]) * 64 + (H - gl.shape[0]) / 2.0))
        y0, x0 = max(0, oy), max(0, ox)
        y1, x1 = min(H, oy + gl.shape[0]), min(W, ox + gl.shape[1])
        emis[y0:y1, x0:x1] = e[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    comp = {"body": body, "origin": (W / 2.0, H / 2.0), "emis": emis, "halo": np.zeros_like(emis), "team": np.zeros_like(emis)}
    r = D.measure(comp, emp, nom)
    moy, sil, noir = extra(body)
    m = r["masse_tuiles2"]
    damier = moy / m
    rows = [
        ("D3 pièces/t²", r["petites_pieces_par_tuile2"], ">= 24 (cible 29, plafond 45)", 24 <= r["petites_pieces_par_tuile2"] <= 45),
        ("pièces / masse", r["petites_pieces"] / m, ">= 25", r["petites_pieces"] / m >= 25),
        ("D5 contours", r["part_contours"], ">= 0,24 (cible 0,32)", r["part_contours"] >= 0.24),
        ("D4 contraste 7px", r["contraste_local_7px"], ">= 18 (cible 25)", r["contraste_local_7px"] >= 18),
        ("noir < 25", noir, ">= 0,15 (cible 0,25)", noir >= 0.15),
        ("L p05", r["lum_p5"], "<= 10", r["lum_p5"] <= 10),
        ("L p50", r["lum_p50"], "43 à 58 (bible âge 13 : 92)", 43 <= r["lum_p50"] <= 58),
        ("L p95", r["lum_p95"], "160 à 200", 160 <= r["lum_p95"] <= 200),
        ("saturation", r["saturation_moyenne"], ">= 0,40 (cible 0,50)", r["saturation_moyenne"] >= 0.40),
        ("saturée hors lumineux", r["part_saturee_hors_lumineux"], "<= 0,04", r["part_saturee_hors_lumineux"] <= 0.04),
        ("M2 masse/emprise", r["masse_par_tuile_emprise"], ">= 0,75", r["masse_par_tuile_emprise"] >= 0.75),
        ("découpe silhouette", sil, ">= 1,6 (cible 2,2)", sil >= 1.6),
        ("damier (plages/t²)", damier, "<= 0,45", damier <= 0.45),
        ("zone lumineuse jour", r["zone_lumineuse_part"], "<= 0,06", r["zone_lumineuse_part"] <= 0.06),
        ("sources de lueur (>=64 px)", ngf if ng else 0, "info : composantes brutes", True),
        ("foyers vus (fermeture 10 px)", ngd if ng else 0, "3 à 8 foyers dominants", 3 <= (ngd if ng else 0) <= 8),
        ("O dépassement haut", r["O_depassement_haut"], "info (bible 3,14)", True),
    ]
    print("QG %s  emprise %gx%g  masse %.1f t²  pièces %d" % (nom, emp[0], emp[1], m, r["petites_pieces"]))
    ko = 0
    for k, v, c, ok in rows:
        ko += 0 if ok else 1
        print("  %-28s %8.3f   %-30s %s" % (k, v, c, "OK" if ok else "ÉCHEC"))
    print("  planchers échoués : %d / %d" % (ko, len(rows) - 1))
    out = dict(r, damier=damier, decoupe=sil, noir_lt25=noir, sources_glow=ng)
    json.dump(out, open(os.path.join(d, nom, "mesure13.json"), "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
