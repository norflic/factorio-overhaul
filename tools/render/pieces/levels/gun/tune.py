"""Réglage des hauteurs de tête (zg) sur l'enveloppe O de la bible §4, à partir des silhouettes rapides
(dryrun.py) ; écrit params.json avec --apply. Écrit aussi une planche de contrôle des silhouettes.

    python tools/render/pieces/levels/gun/tune.py [--apply] [--sheet <png>]

O d'un niveau = maximum sur les 4 poses du dépassement des MASSES (tiges de moins de 0,15 tuile exclues)
au-dessus du bord haut de l'emprise. O dépend linéairement de zg (la tête monte d'un bloc) : 0,707 tuile
d'écran par unité de hauteur, d'où zg += (O_cible - O) / 0,707.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import d1lib as D  # noqa: E402
import gun as G  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--sheet", default=os.path.join(D.DRY_DIR, "_silhouettes.png"))
    a = ap.parse_args()
    P = G.load_params()
    rows = []
    masks = {}
    for e in range(1, 16):
        lv = 2 * e - 1
        per = {}
        for pose in D.POSES:
            m = D.main_alpha(D.level_layers(lv, pose, "dry")) >= 0.5
            masks[(lv, pose)] = m
            per[pose] = D.metrics(m)
        O = max(per[p]["O"] for p in D.POSES)
        L = max(per[p]["L"] for p in D.POSES)
        rows.append((e, P["zg"].get(e), O, G.O_TARGET[e], L, {p: round(per[p]["O"], 2) for p in D.POSES}))
        print("e%02d zg=%.3f O=%.3f (cible %.2f) L=%.2f (max %.2f) par pose %s" % (
            e, P["zg"].get(e, 0), O, G.O_TARGET[e], L, G.L_TARGET[e], rows[-1][5]))
    if a.apply:
        new = {"zg": {}, "gain": {str(e): P["gain"][e] for e in range(1, 16)}}
        for e, zg, O, Ot, L, _ in rows:
            if e == 1:
                continue
            new["zg"][str(e)] = round(zg + (Ot - O) / math.sqrt(0.5), 4)
        path = os.path.join(HERE, "params.json")
        old = {}
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                old = json.load(f)
        old.update(new)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(old, f, indent=1, sort_keys=True)
        print("params.json mis à jour")
    # planche des silhouettes (impairs, 4 poses) : noir sur blanc, 1 px = 1 px hr / 2
    cells = []
    for pose in D.POSES:
        row = []
        for e in range(1, 16):
            m = masks[(2 * e - 1, pose)]
            crop = m[D.OY - 4 * D.PPT:D.OY + int(1.4 * D.PPT), D.OX - int(1.3 * D.PPT):D.OX + int(1.3 * D.PPT)]
            row.append(crop)
        cells.append(np.concatenate(row, 1))
    sheet = np.concatenate(cells, 0)
    img = Image.fromarray(np.where(sheet, 0, 255).astype(np.uint8), "L")
    img = img.resize((img.width // 2, img.height // 2), Image.BILINEAR)
    img.save(a.sheet)
    print("planche :", a.sheet)


if __name__ == "__main__":
    main()
