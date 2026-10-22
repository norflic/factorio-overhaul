"""Localise les trous enfermés (> 8 px) et les pièces isolées d'une couche principale ; image de repérage
(rouge : trou, magenta : pièce isolée), agrandie 3×, dans <travail>/apercus/trous-<variante>.png.

    py -3.9 tools/render/pieces/levels/gun_e_haut/trous.py <outils charte> <variante> [...]
"""
import json
import os
import sys

import numpy as np
from PIL import Image

W = os.environ.get("FO_IND_WORK", "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-22_V3E/haut")


def main():
    sys.path.insert(0, sys.argv[1])
    import da_lib as D
    for nm in sys.argv[2:]:
        if "+" in nm:
            # composition socle + tête (couches principales), comme mesure.py
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import mesure as MS
            lay = []
            for part in nm.split("+"):
                lay += [l for l in MS.layers_of(D, os.path.join(W, "out"), part) if l["kind"] == "main"]
            im = D.compose(lay)["body"]
        else:
            d = os.path.join(W, "out", nm)
            spec = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
            im = np.asarray(Image.open(os.path.join(d, spec["layers"]["main"]["file"])).convert("RGBA")).astype(float) / 255
        a = im[..., 3] >= 0.5
        sizes, lab = D.components(~a, conn8=False)
        border = set(lab[0, :].tolist()) | set(lab[-1, :].tolist()) | set(lab[:, 0].tolist()) | set(lab[:, -1].tolist())
        rgb = im[..., :3] * im[..., 3:4] + np.array([0.45, 0.32, 0.2]) * (1 - im[..., 3:4])
        for k, v in sizes.items():
            if k in border or v <= 8:
                continue
            ys, xs = np.nonzero(lab == k)
            print("%s trou %d px  x %d..%d  y %d..%d" % (nm, v, xs.min(), xs.max(), ys.min(), ys.max()))
            rgb[lab == k] = (1, 0, 0)
        s2, lab2 = D.components(a, conn8=True)
        big = max(s2, key=s2.get)
        for k, v in s2.items():
            if k == big or v <= 8:
                continue
            ys, xs = np.nonzero(lab2 == k)
            print("%s isolée %d px  x %d..%d  y %d..%d" % (nm, v, xs.min(), xs.max(), ys.min(), ys.max()))
            rgb[lab2 == k] = (1, 0, 1)
        o = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
        o = o.resize((o.width * 3, o.height * 3), Image.NEAREST)
        os.makedirs(os.path.join(W, "apercus"), exist_ok=True)
        o.save(os.path.join(W, "apercus", "trous-%s.png" % nm.replace("+", "_")))


if __name__ == "__main__":
    main()
