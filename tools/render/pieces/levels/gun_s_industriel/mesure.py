"""Mesure des niveaux « industriel lourd » avec le code de la charte DA_FACTORIO (lot V3-S), sans le modifier.

    python tools/render/pieces/levels/gun_s_industriel/mesure.py <dossier outils de la charte> <sortie.json>
           [--prev <dossier d'aperçus>] [--pose E]

Composition identique à la mitrailleuse de V3 phase 1 dans outils/mesure_apercus.py : socle (ou socle + pièce)
+ tête en pose E, couches main, glow, light, à 64 px/tuile ; mesure par da_lib.measure (corps seul, alpha ≥ 0,5).
Puis : verdict par plancher (seuils de la charte §5, recopiés de outils/seuils.py) et contrôle de la cible de
l'époque (§6.2 : emprise, masse, pièces, O, zone lumineuse).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
WORK = os.environ.get("FO_IND_WORK", "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-22_V3S/industriel")
OUT = os.path.join(WORK, "out")
LEVELS = {11: (6, "e06-socle", "e06-tete"), 21: (11, "e11-socle", "e11-tete"), 29: (15, "e15-socle", "e15-tete"),
          30: (15, "e15-socle-piece", "e15-tete")}
SIDE = {6: 3, 11: 5, 15: 6}
# charte §6.2 (époques 6, 11, 15)
CIBLE = {6: dict(masse=8.1, pieces=251, O=1.2, lum=(0.04, 0.06), systemes=6, anim=3),
         11: dict(masse=20.5, pieces=536, O=2.0, lum=(0.07, 0.10), systemes=10, anim=4),
         15: dict(masse=32.4, pieces=849, O=2.4, lum=(0.10, 0.12), systemes=13, anim=6)}


def layers_of(name, D):
    p = os.path.join(OUT, name, "spec.json")
    if not os.path.exists(p):
        return []
    spec = json.load(open(p, encoding="utf-8"))
    out = []
    for k in ("main", "glow", "light"):
        if k in spec["layers"]:
            s = spec["layers"][k]
            out.append({"img": D.load_rgba(os.path.join(OUT, name, s["file"])).copy(), "shift": tuple(s["shift"]),
                        "kind": k, "file": s["file"]})
    return out


def floors(r, big):
    """Les 23 planchers de la charte §5, par outils/seuils.py (importé tel quel), plus les plafonds anti-bouillie
    (D1 <= 41, D3 <= 45, P1 <= 7,6)."""
    import seuils
    F = [(sid, ok, v, "%s %s" % (op, p)) for sid, k, v, op, p, ok in seuils.verdict(r)]
    F.append(("D1max", r["laplacien_moyen"] <= 41, r["laplacien_moyen"], "<= 41"))
    F.append(("D3max", r["petites_pieces_par_tuile2"] <= 45, r["petites_pieces_par_tuile2"], "<= 45"))
    F.append(("P1max", r["grain_surfaces"] <= 7.6, r["grain_surfaces"], "<= 7.6"))
    return F


def save_preview(comp, path):
    b = comp["body"]
    im = Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8), "RGBA")
    bg = Image.new("RGBA", im.size, (40, 40, 40, 255))
    bg.alpha_composite(im)
    bg.convert("RGB").save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("outils")
    ap.add_argument("sortie")
    ap.add_argument("--prev", default="")
    ap.add_argument("--pose", default="E")
    a = ap.parse_args()
    sys.path.insert(0, a.outils)
    import da_lib as D
    res = []
    lines = []
    for lvl, (e, socle, tete) in sorted(LEVELS.items()):
        lay = layers_of(socle, D) + layers_of("%s-%s" % (tete, a.pose), D)
        if not lay:
            continue
        comp = D.compose(lay)
        side = SIDE[e]
        r = D.measure(comp, side, "industriel-n%02d" % lvl)
        r.update({"famille": "mitrailleuse-industriel", "niveau": lvl, "epoque": e, "pose": a.pose})
        F = floors(r, side >= 4)
        r["planchers"] = [{"id": f[0], "ok": f[1], "valeur": f[2], "seuil": f[3]} for f in F]
        r["echecs"] = [f[0] for f in F if not f[1]]
        cb = CIBLE[e]
        r["cible"] = {"masse_min": cb["masse"], "pieces_min": cb["pieces"], "O_max": cb["O"], "lum": cb["lum"]}
        r["cible_ok"] = {"masse": r["masse_tuiles2"] >= cb["masse"], "pieces": r["petites_pieces"] >= cb["pieces"],
                         "O": r["O_depassement_haut"] <= cb["O"],
                         "lum": cb["lum"][0] <= r["zone_lumineuse_part"] <= 0.15}
        res.append(r)
        if a.prev:
            os.makedirs(a.prev, exist_ok=True)
            save_preview(comp, os.path.join(a.prev, "industriel-n%02d-%s.png" % (lvl, a.pose)))
        lines.append("n%02d (ép. %d, %dx%d) : %d plancher(s) en échec %s" % (lvl, e, side, side, len(r["echecs"]),
                                                                           ", ".join(r["echecs"]) or ""))
        lines.append("   D1 %.1f  D2 %.1f  D3 %.1f/t² (%d pièces)  D4 %.1f  D5 %.3f  P1 %.2f  P2 %.1f  P3 %.3f  P4 %.3f"
                     % (r["laplacien_moyen"], r["laplacien_zoom1"], r["petites_pieces_par_tuile2"], r["petites_pieces"],
                        r["contraste_local_7px"], r["part_contours"], r["grain_surfaces"], r["variance_basse_freq"],
                        r["part_creux_sombres"], r["part_surfaces_planes"]))
        lines.append("   C1 %.0f  C2 %.0f  C3 %.3f  C4 %.3f  C5 %.3f  C6 %.3f  C7 %.3f  C8 %.3f  L1 %.3f  L2 %.3f (foyers %d)"
                     % (r["lum_p50"], r["lum_p95"], r["part_teinte_chaude_corps"], r["part_saturee"],
                        r["part_saturee_hors_lumineux"], r["plus_grande_plage_saturee_toutes_tuiles2"],
                        r["part_peinte_froide_hors_lumineux"], r["part_quasi_blanc"], r["zone_lumineuse_part"],
                        r["plus_grand_foyer_lumineux_tuiles2"], r["foyers_lumineux"]))
        lines.append("   M1 %.2f  M2 %.2f  M3 %.3f  masse %.2f t² (cible %.1f)  pièces %d (cible %d)  O %.2f (max %.1f)  halo nuit %.1f t²"
                     % (r["remplissage_emprise"], r["masse_par_tuile_emprise"], r["part_massive"], r["masse_tuiles2"],
                        cb["masse"], r["petites_pieces"], cb["pieces"], r["O_depassement_haut"], cb["O"],
                        r["halo_nuit_tuiles2"]))
    # dominance (charte §6.1) entre témoins successifs (indicateurs mesurables sur l'image)
    by = {r["niveau"]: r for r in res}
    for a_, b_ in ((11, 21), (21, 29), (29, 30)):
        if a_ in by and b_ in by:
            ra, rb = by[a_], by[b_]
            keys = ("masse_tuiles2", "petites_pieces", "zone_lumineuse_tuiles2")
            down = [k for k in keys if rb[k] < ra[k] - 1e-9]
            up = [k for k in keys if rb[k] > ra[k] + 1e-9]
            dd = rb["petites_pieces_par_tuile2"] / max(1e-9, ra["petites_pieces_par_tuile2"]) - 1
            ok = (not down) and len(up) >= 2 and ("masse_tuiles2" in up or "petites_pieces" in up) and dd >= -0.05 \
                and rb["petites_pieces_par_tuile2"] >= 26
            lines.append("dominance n%02d -> n%02d : %s (hausse %s ; baisse %s ; densité %+.1f %%)"
                         % (a_, b_, "OUI" if ok else "NON", ",".join(up) or "-", ",".join(down) or "-", 100 * dd))
    json.dump(res, open(a.sortie, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    txt = "\n".join(lines)
    with open(a.sortie[:-5] + ".txt", "w", encoding="utf-8") as f:
        f.write(txt + "\n")
    print(txt)


if __name__ == "__main__":
    main()
