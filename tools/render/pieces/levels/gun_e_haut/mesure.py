"""Mesures du lot V3-E (époques 10 à 15) avec les outils de la charte (tools/da, NON modifiés), et contrôle
BLOQUANT des trous enfermés et des pièces isolées.

    py -3.9 tools/render/pieces/levels/gun_e_haut/mesure.py <outils charte> <sortie.json> [--pose E|N] [--src out|sprites]

1. Corps seul (socle ou socle + pièce, puis tête de la pose), couches main, glow, light à 64 px par tuile ; mesure par
   da_lib.measure ; 23 planchers de la charte (seuils.py), plafonds D1 ≤ 41, D3 ≤ 45, P1 ≤ 7,6 ; cibles de
   l'époque (catalogue V3-E §A.4 : masse, pièces, O, zone lumineuse).
2. Intégrité, sur CHAQUE couche principale (socle, socle + pièce, têtes N et E) et sur la composition :
   - trous enfermés : pixels d'alpha < 0,5 non reliés au bord (4-connexité, comme juges/juge_trous.py) ; échec
     si un groupe dépasse 8 px ;
   - pièces isolées : composantes de l'alpha ≥ 0,5 (8-connexité) autres que la plus grande ; échec si l'une
     dépasse 8 px (une pièce qui ne touche rien dans l'image ne touche rien dans le jeu).
3. Dominance époque par époque (critère de progression.py : emprise, masse, pièces, foyers tous ≥, au moins 2
   strictement), densité D3 sans baisse de plus de 5 %.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.environ.get("FO_IND_WORK", "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-22_V3E/haut")
SIDE = {10: 5, 11: 5, 12: 5, 13: 6, 14: 6, 15: 6}
# catalogue V3-E §A.4
CIBLE = {10: dict(masse=18.8, pieces=488, O=2.0, lum=(0.07, 0.09), systemes=9),
         11: dict(masse=20.5, pieces=536, O=2.0, lum=(0.07, 0.10), systemes=10),
         12: dict(masse=22.5, pieces=590, O=2.0, lum=(0.08, 0.10), systemes=10),
         13: dict(masse=27.0, pieces=702, O=2.4, lum=(0.09, 0.11), systemes=11),
         14: dict(masse=29.5, pieces=772, O=2.4, lum=(0.10, 0.12), systemes=12),
         15: dict(masse=32.4, pieces=849, O=2.4, lum=(0.10, 0.12), systemes=13)}
SEUIL_PX = 8


def levels():
    out = {}
    for e in SIDE:
        out[2 * e - 1] = (e, "e%02d-socle" % e)
        out[2 * e] = (e, "e%02d-socle-piece" % e)
    return out


def layers_of(D, base, name):
    p = os.path.join(base, name, "spec.json")
    if not os.path.exists(p):
        return []
    spec = json.load(open(p, encoding="utf-8"))
    out = []
    for k in ("main", "glow", "light"):
        if k in spec["layers"]:
            s = spec["layers"][k]
            out.append({"img": D.load_rgba(os.path.join(base, name, s["file"])).copy(), "shift": tuple(s["shift"]),
                        "kind": k, "file": s["file"]})
    return out


def integrity(D, alpha):
    """(trous enfermés : total, groupes, plus grand) et (pièces isolées : nombre > 8 px, plus grande)."""
    a = alpha >= 0.5
    sizes, lab = D.components(~a, conn8=False)
    border = set(lab[0, :].tolist()) | set(lab[-1, :].tolist()) | set(lab[:, 0].tolist()) | set(lab[:, -1].tolist())
    enc = {k: v for k, v in sizes.items() if k not in border}
    s2, _ = D.components(a, conn8=True)
    comps = sorted(s2.values(), reverse=True)
    iso = comps[1:]
    return {"trous_px": int(sum(enc.values())), "trous_groupes": len(enc),
            "trou_max_px": int(max(enc.values()) if enc else 0),
            "isolees_gt8": int(sum(1 for v in iso if v > SEUIL_PX)), "isolee_max_px": int(iso[0] if iso else 0),
            "ok": (max(enc.values()) if enc else 0) <= SEUIL_PX and (iso[0] if iso else 0) <= SEUIL_PX}


def floors(r):
    import seuils
    F = [(sid, ok, v, "%s %s" % (op, p)) for sid, k, v, op, p, ok in seuils.verdict(r)]
    F.append(("D1max", r["laplacien_moyen"] <= 41, r["laplacien_moyen"], "<= 41"))
    F.append(("D3max", r["petites_pieces_par_tuile2"] <= 45, r["petites_pieces_par_tuile2"], "<= 45"))
    F.append(("D3min", r["petites_pieces_par_tuile2"] >= 26, r["petites_pieces_par_tuile2"], ">= 26"))
    F.append(("P1max", r["grain_surfaces"] <= 7.6, r["grain_surfaces"], "<= 7.6"))
    return F


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("outils")
    ap.add_argument("sortie")
    ap.add_argument("--pose", default="E")
    ap.add_argument("--src", default="out")
    ap.add_argument("--prev", default="")
    a = ap.parse_args()
    sys.path.insert(0, a.outils)
    import da_lib as D
    base = os.path.join(WORK, a.src)
    res, lines = [], []
    sprite_checks = {}
    for lvl, (e, socle) in sorted(levels().items()):
        tete = "e%02d-tete-%s" % (e, a.pose)
        lay = layers_of(D, base, socle) + layers_of(D, base, tete)
        if len(lay) < 2:
            continue
        for nm in (socle, tete):
            if nm not in sprite_checks:
                spec = json.load(open(os.path.join(base, nm, "spec.json"), encoding="utf-8"))
                al = np.asarray(Image.open(os.path.join(base, nm, spec["layers"]["main"]["file"])).convert("RGBA"))[..., 3] / 255.0
                sprite_checks[nm] = integrity(D, al)
        comp = D.compose(lay)
        side = SIDE[e]
        r = D.measure(comp, side, "gune-n%02d-%s" % (lvl, a.pose))
        r.update({"famille": "mitrailleuse", "niveau": lvl, "epoque": e, "pose": a.pose})
        F = floors(r)
        r["planchers"] = [{"id": f[0], "ok": bool(f[1]), "valeur": f[2], "seuil": f[3]} for f in F]
        r["echecs"] = [f[0] for f in F if not f[1]]
        cb = CIBLE[e]
        r["cible"] = cb
        r["cible_ok"] = {"masse": r["masse_tuiles2"] >= cb["masse"], "pieces": r["petites_pieces"] >= cb["pieces"],
                         "O": r["O_depassement_haut"] <= cb["O"],
                         "lum": cb["lum"][0] <= r["zone_lumineuse_part"] <= 0.15,
                         "pieces>=26*masse": r["petites_pieces"] >= 26 * r["masse_tuiles2"]}
        r["integrite_composition"] = integrity(D, comp["body"][..., 3])
        r["integrite_sprites"] = {socle: sprite_checks[socle], tete: sprite_checks[tete]}
        res.append(r)
        if a.prev:
            os.makedirs(a.prev, exist_ok=True)
            b = comp["body"]
            im = Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8), "RGBA")
            bg = Image.new("RGBA", im.size, (40, 40, 40, 255))
            bg.alpha_composite(im)
            bg.convert("RGB").save(os.path.join(a.prev, "gune-n%02d-%s.png" % (lvl, a.pose)))
        ic = r["integrite_composition"]
        lines.append("n%02d (ép. %d, %dx%d, pose %s) : %d plancher(s) en échec %s" % (
            lvl, e, side, side, a.pose, len(r["echecs"]), ", ".join(r["echecs"])))
        lines.append("   D1 %.1f  D2 %.1f  D3 %.1f/t² (%d pièces)  D4 %.1f  D5 %.3f  P1 %.2f  P2 %.1f  P3 %.3f  P4 %.3f"
                     % (r["laplacien_moyen"], r["laplacien_zoom1"], r["petites_pieces_par_tuile2"], r["petites_pieces"],
                        r["contraste_local_7px"], r["part_contours"], r["grain_surfaces"], r["variance_basse_freq"],
                        r["part_creux_sombres"], r["part_surfaces_planes"]))
        lines.append("   C1 %.0f  C2 %.0f  C3 %.3f  C4 %.3f  C5 %.3f  C6 %.3f  C7 %.3f  C8 %.3f  L1 %.3f  L2 %.3f (foyers %d)"
                     % (r["lum_p50"], r["lum_p95"], r["part_teinte_chaude_corps"], r["part_saturee"],
                        r["part_saturee_hors_lumineux"], r["plus_grande_plage_saturee_toutes_tuiles2"],
                        r["part_peinte_froide_hors_lumineux"], r["part_quasi_blanc"], r["zone_lumineuse_part"],
                        r["plus_grand_foyer_lumineux_tuiles2"], r["foyers_lumineux"]))
        lines.append("   M1 %.2f  M2 %.2f  M3 %.3f  masse %.2f t² (min %.1f)  pièces %d (min %d)  O %.2f (max %.1f)  halo nuit %.1f t²"
                     % (r["remplissage_emprise"], r["masse_par_tuile_emprise"], r["part_massive"], r["masse_tuiles2"],
                        cb["masse"], r["petites_pieces"], cb["pieces"], r["O_depassement_haut"], cb["O"],
                        r["halo_nuit_tuiles2"]))
        lines.append("   intégrité composition : trous %d px (%d groupes, max %d) ; pièces isolées > 8 px : %d (max %d) : %s"
                     % (ic["trous_px"], ic["trous_groupes"], ic["trou_max_px"], ic["isolees_gt8"], ic["isolee_max_px"],
                        "OK" if ic["ok"] else "ÉCHEC"))
    lines.append("intégrité par sprite (couche principale) :")
    for nm, c in sorted(sprite_checks.items()):
        lines.append("   %-22s trous %5d px (%3d groupes, max %4d) ; isolées > 8 px %d (max %d) : %s"
                     % (nm, c["trous_px"], c["trous_groupes"], c["trou_max_px"], c["isolees_gt8"], c["isolee_max_px"],
                        "OK" if c["ok"] else "ÉCHEC"))
    # dominance
    by = {r["niveau"]: r for r in res}
    odd = [l for l in sorted(by) if l % 2 == 1]
    pairs = list(zip(odd, odd[1:])) + [(l, l + 1) for l in odd if l + 1 in by]
    for x, y in pairs:
        ra, rb = by[x], by[y]
        ea, eb = SIDE[ra["epoque"]] ** 2, SIDE[rb["epoque"]] ** 2
        q = [(eb, ea), (rb["masse_tuiles2"], ra["masse_tuiles2"]), (rb["petites_pieces"], ra["petites_pieces"]),
             (rb["foyers_lumineux"], ra["foyers_lumineux"])]
        ge = all(u >= v for u, v in q)
        gt = sum(1 for u, v in q if u > v)
        dd = rb["petites_pieces_par_tuile2"] / max(1e-9, ra["petites_pieces_par_tuile2"]) - 1
        ok = ge and gt >= 2
        lines.append("dominance n%02d -> n%02d : %s (masse %.1f -> %.1f ; pièces %d -> %d ; foyers %d -> %d ; densité %+.1f %%%s)"
                     % (x, y, "OUI" if ok else "NON", ra["masse_tuiles2"], rb["masse_tuiles2"], ra["petites_pieces"],
                        rb["petites_pieces"], ra["foyers_lumineux"], rb["foyers_lumineux"], 100 * dd,
                        "" if dd >= -0.05 else " : BAISSE > 5 %"))
    json.dump({"niveaux": res, "sprites": sprite_checks}, open(a.sortie, "w", encoding="utf-8"), indent=1,
              ensure_ascii=False, default=float)
    txt = "\n".join(lines)
    with open(a.sortie[:-5] + ".txt", "w", encoding="utf-8") as f:
        f.write(txt + "\n")
    print(txt)


if __name__ == "__main__":
    main()
