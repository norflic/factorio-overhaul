"""Mesures de la charte DA_FACTORIO (tools/da, NON modifié) sur la mitrailleuse V3-E, époques 1 à 9.

    py -3.9 tools/render/pieces/levels/gun_e_bas/mesure_e.py <dossier out> <sortie.json> [--prev <dossier>]

Corps seul (couches main, glow, light ; pas d'ombre), socle (+ pièce paire) + tête, poses E et N, à 64 px/tuile :
da_lib.compose puis da_lib.measure. Niveau 2 : mitrailleuse vanilla + pièce de l'époque 1. Pour chaque niveau :
les 23 planchers de la charte (§5, outils/seuils.py), les plafonds anti-bouillie (D1 <= 41, D3 <= 45, P1 <= 7,6),
la bande D3 du lot (26 à 45), la cible d'emprise (catalogue §A.4 : masse, pièces, O, zone lumineuse de jour).
Puis la dominance époque par époque (niveaux impairs, même pose : emprise, masse, pièces, foyers ; densité qui ne
baisse pas de plus de 5 %) et, pour chaque époque, la pièce paire (masque nouveau hors du masque impair, en t²).
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402

D = K.D
sys.path.insert(0, K.OUTILS)
import seuils  # noqa: E402

# catalogue DA_PAR_EPOQUE §A.4 (époque : masse min, pièces min, O max, zone lumineuse de jour)
CIBLE = {1: (3.5, 156, 0.8, (0.0, 0.02)), 2: (3.6, 172, 0.8, (0.0, 0.03)), 3: (3.7, 189, 0.8, (0.02, 0.04)),
         4: (6.8, 208, 1.2, (0.03, 0.05)), 5: (7.4, 228, 1.2, (0.03, 0.06)), 6: (8.1, 251, 1.2, (0.04, 0.06)),
         7: (12.0, 312, 1.6, (0.05, 0.07)), 8: (13.1, 343, 1.6, (0.05, 0.08)), 9: (14.4, 378, 1.6, (0.06, 0.08))}
KIND = ("main", "glow", "light")


def floors(r):
    F = [(sid, ok, v, "%s %s" % (op, p)) for sid, k, v, op, p, ok in seuils.verdict(r)]
    F.append(("D1max", r["laplacien_moyen"] <= 41, r["laplacien_moyen"], "<= 41"))
    F.append(("D3max", r["petites_pieces_par_tuile2"] <= 45, r["petites_pieces_par_tuile2"], "<= 45"))
    F.append(("D3lot", r["petites_pieces_par_tuile2"] >= 26, r["petites_pieces_par_tuile2"], ">= 26"))
    F.append(("P1max", r["grain_surfaces"] <= 7.6, r["grain_surfaces"], "<= 7.6"))
    return F


def body_alpha(lays):
    comp = D.compose([dict(l) for l in lays if l["kind"] == "main"])
    return comp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("sortie")
    ap.add_argument("--prev", default="")
    a = ap.parse_args()
    rows, lines = [], []
    for e in range(1, 10):
        side = K.SIDE[e]
        for pose in ("E", "N"):
            for even in (False, True):  # époque 1 : niveau 1 = mitrailleuse vanilla mesurée de la même façon
                lays = K.level_layers(a.out, e, pose, even, kinds=KIND)
                if len(lays) < 2:
                    continue
                comp = D.compose([dict(l) for l in lays])
                lvl = 2 * e - 1 + int(even)
                r = D.measure(comp, side, "gun-e-n%02d-%s" % (lvl, pose))
                r.update({"famille": "mitrailleuse", "niveau": lvl, "epoque": e, "pose": pose, "pair": even})
                F = floors(r)
                r["planchers"] = [{"id": f[0], "ok": bool(f[1]), "valeur": f[2], "seuil": f[3]} for f in F]
                r["echecs"] = [f[0] for f in F if not f[1]]
                m, p, O, lum = CIBLE[e]
                r["cible"] = {"masse_min": m, "pieces_min": p, "O_max": O, "lum": lum}
                r["cible_ok"] = {"masse": r["masse_tuiles2"] >= m, "pieces": r["petites_pieces"] >= p,
                                 "O": r["O_depassement_haut"] <= O,
                                 "lum": lum[0] - 1e-9 <= r["zone_lumineuse_part"] <= max(lum[1], 0.15)}
                if a.prev:
                    os.makedirs(a.prev, exist_ok=True)
                    b = comp["body"]
                    im = np.clip(b, 0, 1)
                    bg = np.ones_like(im[..., :3]) * 0.16
                    rgb = im[..., :3] * im[..., 3:4] + bg * (1 - im[..., 3:4])
                    K.to_im(rgb).save(os.path.join(a.prev, "n%02d-%s.png" % (lvl, pose)))
                rows.append(r)
                lines.append("n%02d ép.%d %s %dx%d %s: %d échec(s) %s" % (
                    lvl, e, pose, side, side, "(pair) " if even else "", len(r["echecs"]), ",".join(r["echecs"])))
                lines.append("   D1 %.1f D2 %.1f D3 %.1f/t² (%d pièces) D4 %.1f D5 %.3f P1 %.2f P2 %.1f P3 %.3f P4 %.3f" % (
                    r["laplacien_moyen"], r["laplacien_zoom1"], r["petites_pieces_par_tuile2"], r["petites_pieces"],
                    r["contraste_local_7px"], r["part_contours"], r["grain_surfaces"], r["variance_basse_freq"],
                    r["part_creux_sombres"], r["part_surfaces_planes"]))
                lines.append("   C1 %.0f C2 %.0f C3 %.3f C4 %.3f C5 %.3f C6 %.3f C7 %.3f C8 %.3f L1 %.3f L2 %.3f (foyers %d)" % (
                    r["lum_p50"], r["lum_p95"], r["part_teinte_chaude_corps"], r["part_saturee"],
                    r["part_saturee_hors_lumineux"], r["plus_grande_plage_saturee_toutes_tuiles2"],
                    r["part_peinte_froide_hors_lumineux"], r["part_quasi_blanc"], r["zone_lumineuse_part"],
                    r["plus_grand_foyer_lumineux_tuiles2"], r["foyers_lumineux"]))
                ck = r["cible_ok"]
                lines.append("   M1 %.2f M2 %.2f M3 %.3f masse %.2f t² (min %.1f %s) pièces %d (min %d %s) O %.2f (max %.1f %s)"
                             " zone lum. %.3f (bande %.2f-%.2f %s)" % (
                                 r["remplissage_emprise"], r["masse_par_tuile_emprise"], r["part_massive"],
                                 r["masse_tuiles2"], m, "ok" if ck["masse"] else "BAS", r["petites_pieces"], p,
                                 "ok" if ck["pieces"] else "BAS", r["O_depassement_haut"], O, "ok" if ck["O"] else "HAUT",
                                 r["zone_lumineuse_part"], lum[0], lum[1],
                                 "ok" if lum[0] - 1e-9 <= r["zone_lumineuse_part"] <= lum[1] + 1e-9 else "hors bande"))
    # pièce paire : masque nouveau (alpha >= 0,5 du pair, hors masque de l'impair), poses E et N
    lines.append("")
    lines.append("Pièce du niveau pair : masque nouveau hors du niveau impair (catalogue §A.5 : >= 0,10 t²)")
    piece_rows = []
    for e in range(1, 10):
        for pose in ("E", "N"):
            odd = K.level_layers(a.out, e, pose, False, kinds=("main",))
            ev = K.level_layers(a.out, e, pose, True, kinds=("main",))
            if not odd or len(ev) <= len(odd):
                continue
            ca = D.compose([dict(l) for l in ev])
            # même canevas : on recompose l'impair dans le repère du pair (ajout d'une couche vide de même boîte)
            pad = [dict(l) for l in ev]
            for l in pad:
                if "-piece-" in l.get("file", ""):
                    l["img"] = np.zeros_like(l["img"])
            cb = D.compose(pad)
            new = (ca["body"][..., 3] >= 0.5) & ~(cb["body"][..., 3] >= 0.5)
            t2 = float(new.sum()) / 64.0 ** 2
            piece_rows.append({"epoque": e, "pose": pose, "masque_nouveau_t2": t2, "ok": t2 >= 0.10})
            lines.append("   ép.%d %s : %.3f t² %s" % (e, pose, t2, "ok" if t2 >= 0.10 else "TROP PETIT"))
    # dominance époque par époque (niveaux impairs ; époque 1 = niveau 1, la mitrailleuse vanilla)
    lines.append("")
    lines.append("Dominance époque par époque (emprise, masse, pièces, foyers : tous >= et au moins 2 >; densité D3 >= 0,95 x)")
    dom_rows = []
    for pose in ("E", "N"):
        seq = [r for r in rows if r["pose"] == pose and not r["pair"]]
        seq.sort(key=lambda r: r["epoque"])
        for ra, rb in zip(seq, seq[1:]):
            q = [(K.SIDE[rb["epoque"]] ** 2, K.SIDE[ra["epoque"]] ** 2), (rb["masse_tuiles2"], ra["masse_tuiles2"]),
                 (rb["petites_pieces"], ra["petites_pieces"]), (rb["foyers_lumineux"], ra["foyers_lumineux"])]
            ge = all(x >= y for x, y in q)
            gt = sum(1 for x, y in q if x > y)
            dd = rb["petites_pieces_par_tuile2"] / max(1e-9, ra["petites_pieces_par_tuile2"]) - 1
            ok = ge and gt >= 2
            dom_rows.append({"pose": pose, "de": ra["niveau"], "a": rb["niveau"], "domine": ok, "densite": dd,
                             "densite_ok": dd >= -0.05})
            lines.append("   %s n%02d -> n%02d : masse %.2f -> %.2f, pièces %d -> %d, foyers %d -> %d, D3 %+.1f %% : %s%s" % (
                pose, ra["niveau"], rb["niveau"], ra["masse_tuiles2"], rb["masse_tuiles2"], ra["petites_pieces"],
                rb["petites_pieces"], ra["foyers_lumineux"], rb["foyers_lumineux"], 100 * dd,
                "DOMINE" if ok else "NE DOMINE PAS", "" if dd >= -0.05 else " ; DENSITÉ EN BAISSE > 5 %"))
    json.dump({"niveaux": rows, "pieces_paires": piece_rows, "dominance": dom_rows}, open(a.sortie, "w", encoding="utf-8"),
              indent=1, ensure_ascii=False, default=float)
    txt = "\n".join(lines)
    with open(a.sortie[:-5] + ".txt", "w", encoding="utf-8") as f:
        f.write(txt + "\n")
    print(txt)


if __name__ == "__main__":
    main()
