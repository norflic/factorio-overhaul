"""MESURES DA-CHIMIE : la charte (tools/da/da_lib.py, mêmes clés et planchers que le script du critique
fo-logs/2026-11-04_DA-CHIMIE/critique/mesure.py), plus la photométrie de la couche principale (pixels opaques) contre
l'usine chimique et la raffinerie vanilla HR : luminance moyenne et médiane, saturation, chroma, rouge − bleu.

    py -3.9 tools/render/pieces/chimie/mesure.py --src DIR [variantes…]
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(MOD, "tools", "da"))
import da_lib as D  # noqa: E402

DATA = "F:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/data/base/graphics/entity/"
KEYS = [('laplacien_moyen', 'D1', 27, None), ('laplacien_zoom1', 'D2', 40, None), ('petites_pieces_par_tuile2', 'D3', 24, 45),
        ('contraste_local_7px', 'D4', 22, None), ('part_contours', 'D5', 0.30, None), ('grain_surfaces', 'P1', 3.4, 7.6),
        ('variance_basse_freq', 'P2', 16, None), ('part_creux_sombres', 'P3', 0.10, None),
        ('part_surfaces_planes', 'P4', None, 0.45), ('lum_p50', 'C1', 43, 76), ('lum_p95', 'C2', None, 216),
        ('part_teinte_chaude_corps', 'C3', 0.70, None), ('part_saturee', 'C4', None, 0.13),
        ('part_saturee_hors_lumineux', 'C5', None, 0.04), ('plus_grande_plage_saturee_tuiles2', 'C6', None, 0.35),
        ('part_peinte_froide_hors_lumineux', 'C7', None, 0.06), ('part_quasi_blanc', 'C8', None, 0.04),
        ('zone_lumineuse_part', 'L1', None, 0.15), ('plus_grand_foyer_lumineux_tuiles2', 'L2', None, 0.45),
        ('remplissage_emprise', 'M1', 0.60, None), ('masse_par_tuile_emprise', 'M2', 0.65, None),
        ('part_massive', 'M3', 0.88, None), ('O_depassement_haut', 'O', None, None)]


def photo(im):
    a = np.asarray(im.convert("RGBA")).astype(float) / 255.0
    rgb = a[..., :3][a[..., 3] >= 0.5]
    lum = 0.2126 * rgb[:, 0] + 0.7152 * rgb[:, 1] + 0.0722 * rgb[:, 2]
    mx, mn = rgb.max(1), rgb.min(1)
    sat = np.where(mx > 1e-3, (mx - mn) / np.maximum(mx, 1e-3), 0.0)
    return lum.mean(), np.median(lum), sat.mean(), (mx - mn).mean(), (rgb[:, 0] - rgb[:, 2]).mean()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("noms", nargs="*")
    a = ap.parse_args()
    names = a.noms or sorted(n for n in os.listdir(a.src) if os.path.exists(os.path.join(a.src, n, "spec.json")))
    print("photométrie de la couche principale : lum moy, lum méd, saturation, chroma, rouge - bleu")
    for n, im in (("van chimie", Image.open(DATA + "chemical-plant/hr-chemical-plant.png").crop((0, 0, 220, 292))),
                  ("van raffinerie", Image.open(DATA + "oil-refinery/hr-oil-refinery.png").crop((0, 0, 386, 430)))):
        print("  %-16s %.3f %.3f %.3f %.3f %.3f" % ((n,) + photo(im)))
    rows = {}
    for v in names:
        sp = json.load(open(os.path.join(a.src, v, "spec.json"), encoding="utf-8"))
        print("  %-16s %.3f %.3f %.3f %.3f %.3f" % ((v,) + photo(Image.open(os.path.join(a.src, v, sp["layers"]["main"]["file"])))))
        specs = [(sp["layers"][L]["file"], tuple(sp["layers"][L]["shift"]), "glow" if L == "glow" else "main")
                 for L in ("main", "glow") if L in sp["layers"]]
        rows[v] = D.measure(D.compose(D.from_layer_files(specs, os.path.join(a.src, v))), 3, v)
    print("charte (! = hors plancher)")
    print("id    " + " ".join("%9s" % v[:9] for v in names))
    for k, idn, lo, hi in KEYS:
        line = "%-5s " % idn
        for v in names:
            x = rows[v][k]
            bad = (lo is not None and x < lo) or (hi is not None and x > hi)
            line += "%8.3f%s" % (x, "!" if bad else " ")
        print(line, " plancher", lo, hi)
    print("hauteur totale", [round(rows[v]["hauteur_totale_tuiles"], 2) for v in names])


if __name__ == "__main__":
    main()
