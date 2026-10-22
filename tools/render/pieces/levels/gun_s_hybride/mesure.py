"""Mesure des niveaux de l'exploration hybride avec les indicateurs de la charte DA_FACTORIO (même code :
<charte>/outils/da_lib.py, seuils.py), en pose E (méthode de la charte) et en pose N.

    python mesure.py <dossier des couches (rendre.py --out)> <sortie.json> [dossier des composés]

Composition d'un niveau : socle (couches main, glow, light) PUIS tête (main, glow), dans cet ordre (la tête est
dessinée par-dessus le socle, comme en jeu). Niveau 30 : socle du niveau 30 + tête du niveau 29.
Écrit aussi le verdict par seuil (planchers ≤ 3×3 / ≥ 4×4 de la charte), les cibles §6.2 (masse, pièces,
dépassement O, zone lumineuse) et la dominance §6.1 entre niveaux témoins successifs.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
CHARTE = os.environ.get("FO_CHARTE", r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-22_V3S\charte\outils")
sys.path.insert(0, CHARTE)
import da_lib as D  # noqa: E402
import seuils as SE  # noqa: E402
import design as Dz  # noqa: E402

# cibles de la charte §6.2 (mitrailleuse, époque -> (masse min, pièces min, O max, zone lumineuse (min, max)))
TARGET = {6: (8.1, 251, 1.2, (0.04, 0.06)), 11: (20.5, 536, 2.0, (0.07, 0.10)), 15: (32.4, 849, 2.4, (0.10, 0.12))}
KIND = {"main": "main", "glow": "glow", "light": "light"}


def layers_of(root, name, kinds=("main", "glow", "light")):
    d = os.path.join(root, name)
    spec = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
    out = []
    for k in kinds:
        if k in spec["layers"]:
            s = spec["layers"][k]
            out.append({"img": D.load_rgba(os.path.join(d, s["file"])).copy(), "shift": tuple(s["shift"]),
                        "kind": KIND[k], "file": s["file"]})
    return out, spec


def level_layers(root, lv, pose):
    sl, ss = layers_of(root, "n%02d-socle" % lv)
    hl, hs = layers_of(root, "n%02d-tete-%s" % (29 if lv == 30 else lv, pose), ("main", "glow"))
    return sl + hl, (ss, hs)


def save_preview(comp, path):
    b = comp["body"]
    im = Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8), "RGBA")
    bg = Image.new("RGBA", im.size, (40, 40, 40, 255))
    bg.alpha_composite(im)
    bg.convert("RGB").save(path)


def main():
    root, out_json = sys.argv[1], sys.argv[2]
    prev = sys.argv[3] if len(sys.argv) > 3 else None
    if prev:
        os.makedirs(prev, exist_ok=True)
    res = []
    comps = {}
    for lv in (11, 21, 29, 30):
        if not os.path.exists(os.path.join(root, "n%02d-socle" % lv, "spec.json")):
            continue
        for pose in ("E", "N"):
            hn = "n%02d-tete-%s" % (29 if lv == 30 else lv, pose)
            if not os.path.exists(os.path.join(root, hn, "spec.json")):
                continue
            lay, (ss, hs) = level_layers(root, lv, pose)
            comp = D.compose(lay)
            side = Dz.LEVELS[lv]["side"]
            r = D.measure(comp, side, "hybride-n%02d-%s" % (lv, pose))
            ep = Dz.LEVELS[lv]["epoch"]
            r.update({"famille": "mitrailleuse-hybride", "niveau": lv, "epoque": ep, "pose": pose,
                      "systemes": len(Dz.SYSTEMS[lv]), "animations": len(Dz.ANIMATIONS[lv]),
                      "samples": ss["samples"], "secondes_rendu": ss["seconds"] + hs["seconds"]})
            v = SE.verdict(r)
            r["echecs"] = [s[0] for s in v if not s[5]]
            res.append(r)
            comps[(lv, pose)] = comp
            if prev:
                save_preview(comp, os.path.join(prev, "corps-n%02d-%s.png" % (lv, pose)))
    # aire de la pièce du niveau 30 (pixels du corps qui changent entre 29 et 30, même pose)
    for pose in ("E", "N"):
        if (29, pose) in comps and (30, pose) in comps:
            a, b = comps[(29, pose)]["body"], comps[(30, pose)]["body"]
            if a.shape == b.shape:
                diff = (np.abs(a - b).max(-1) > 0.08) & ((a[..., 3] >= 0.5) | (b[..., 3] >= 0.5))
                for r in res:
                    if r["niveau"] == 30 and r["pose"] == pose:
                        r["piece_aire_tuiles2"] = float(diff.sum() / 64.0 ** 2)
                        r["piece_masse_ajoutee_tuiles2"] = float(((b[..., 3] >= 0.5) & (a[..., 3] < 0.5)).sum() / 64.0 ** 2)
    json.dump(res, open(out_json, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    # rapport texte
    lines = []
    for r in res:
        ep = r["epoque"]
        mm, pm, om, (l0, l1) = TARGET[ep]
        lines.append(
            "n%02d %s (%s) : échecs %d %s | masse %.1f t² (min %.1f) ; pièces %d (min %d) ; %.1f/t² ; O %.2f (max %.1f) ; "
            "lum %.3f (cible %.2f-%.2f) ; foyer max %.2f t² ; D1 %.1f D2 %.1f D4 %.1f D5 %.3f ; P1 %.2f P2 %.1f P3 %.3f "
            "P4 %.3f ; C1 %.0f C2 %.0f C3 %.2f C4 %.3f C5 %.3f C6 %.2f C7 %.3f C8 %.3f ; M1 %.2f M2 %.2f M3 %.2f%s" % (
                r["niveau"], r["pose"], r["cote_emprise"], len(r["echecs"]), ",".join(r["echecs"]),
                r["masse_tuiles2"], mm, r["petites_pieces"], pm, r["petites_pieces_par_tuile2"], r["O_depassement_haut"],
                om, r["zone_lumineuse_part"], l0, l1, r["plus_grand_foyer_lumineux_tuiles2"], r["laplacien_moyen"],
                r["laplacien_zoom1"], r["contraste_local_7px"], r["part_contours"], r["grain_surfaces"],
                r["variance_basse_freq"], r["part_creux_sombres"], r["part_surfaces_planes"], r["lum_p50"],
                r["lum_p95"], r["part_teinte_chaude_corps"], r["part_saturee"], r["part_saturee_hors_lumineux"],
                r["plus_grande_plage_saturee_toutes_tuiles2"], r["part_peinte_froide_hors_lumineux"],
                r["part_quasi_blanc"], r["remplissage_emprise"], r["masse_par_tuile_emprise"], r["part_massive"],
                (" ; pièce n30 : aire %.2f t², masse ajoutée %.2f t²" % (r["piece_aire_tuiles2"],
                                                                          r["piece_masse_ajoutee_tuiles2"])
                 if "piece_aire_tuiles2" in r else "")))
    # dominance §6.1 entre témoins successifs (pose E), vanilla n01 compris
    van = None
    vj = os.path.join(os.path.dirname(CHARTE), "mesures_vanilla.json")
    if os.path.exists(vj):
        for r in json.load(open(vj, encoding="utf-8")):
            if r["nom"] == "gun-turret":
                van = dict(r, niveau=1, epoque=1, systemes=3, animations=1)
    for pose in ("E", "N"):
        seq = ([van] if van else []) + [r for r in res if r["pose"] == pose and r["niveau"] in (11, 21, 29)]
        for a, b in zip(seq, seq[1:]):
            ea = float(a["cote_emprise"].split("x")[0]) ** 2
            eb = float(b["cote_emprise"].split("x")[0]) ** 2
            q = [("emprise", eb, ea), ("masse", b["masse_tuiles2"], a["masse_tuiles2"]),
                 ("pièces", b["petites_pieces"], a["petites_pieces"]), ("systèmes", b["systemes"], a["systemes"]),
                 ("zone lumineuse", b["zone_lumineuse_part"], a["zone_lumineuse_part"]),
                 ("animations", b["animations"], a["animations"])]
            ge = all(x >= y for _, x, y in q)
            gt = sum(1 for _, x, y in q if x > y)
            dens = b["petites_pieces_par_tuile2"] >= 0.95 * a["petites_pieces_par_tuile2"] and b["petites_pieces_par_tuile2"] >= 26
            dom = ge and gt >= 2 and (b["masse_tuiles2"] > a["masse_tuiles2"] or b["petites_pieces"] > a["petites_pieces"]) and dens
            lines.append("dominance %s n%02d -> n%02d : %s (%s ; densité %.1f -> %.1f %s)" % (
                pose, a["niveau"], b["niveau"], "DOMINE" if dom else "NON",
                ", ".join("%s %s->%s" % (k, ("%.3f" % y) if isinstance(y, float) else y,
                                        ("%.3f" % x) if isinstance(x, float) else x) for k, x, y in q),
                a["petites_pieces_par_tuile2"], b["petites_pieces_par_tuile2"], "ok" if dens else "EN BAISSE"))
    txt = "\n".join(lines) + "\n"
    open(os.path.splitext(out_json)[0] + ".txt", "w", encoding="utf-8").write(txt)
    sys.stdout.buffer.write(txt.encode("utf-8"))


if __name__ == "__main__":
    main()
