"""Copie les rendus de PRODUCTION (≥ 128 échantillons, toutes les passes) de <travail>/out vers <travail>/sprites,
une variante par dossier avec son spec.json ; refuse une variante rendue en essai rapide ou à moins de 128
échantillons.

    py -3.9 tools/render/pieces/levels/gun_e_haut/livrer.py
"""
import json
import os
import shutil
import sys

W = os.environ.get("FO_IND_WORK", "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-22_V3E/haut")


def main():
    src, dst = os.path.join(W, "out"), os.path.join(W, "sprites")
    os.makedirs(dst, exist_ok=True)
    bad = []
    for name in sorted(os.listdir(src)):
        p = os.path.join(src, name, "spec.json")
        if not os.path.exists(p):
            continue
        spec = json.load(open(p, encoding="utf-8"))
        if spec.get("quick") or spec.get("samples", 0) < 128:
            bad.append((name, spec.get("samples"), spec.get("quick")))
            continue
        d = os.path.join(dst, name)
        if os.path.exists(d):
            shutil.rmtree(d)
        shutil.copytree(os.path.join(src, name), d)
        print("%-18s %s couches, %d échantillons, %.0f s" % (name, ",".join(sorted(spec["layers"])), spec["samples"],
                                                            spec["seconds"]))
    for b in bad:
        print("REFUSÉ (pas de production) :", b)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
