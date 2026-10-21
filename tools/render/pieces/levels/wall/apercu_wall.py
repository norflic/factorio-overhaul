"""Aperçu de travail du mur (lot V3, phase 1) : quelques niveaux au zoom 2 (64 px/tuile), jour et nuit,
recadrés serré, agrandis pour l'inspection. Sortie dans tools/render/out/levels/wall/apercu/ (non versionné).

    python -P tools/render/pieces/levels/wall/apercu_wall.py 1,3,4 [--x 2] [--nuit] [--tag nom]

Chaque niveau : 2 pièces droites (raccord), puis une pièce isolée. Composition : tools/render/calib/maquette.py.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(RENDER, "calib"))
sys.path.insert(0, RENDER)
import maquette  # noqa: E402
import wall_layers as WL  # noqa: E402


def compose_levels(levels, db, n_run=2, gap=1, top=2, bottom=2):
    ents = []
    x = 1
    starts = []
    for lv in levels:
        starts.append(x)
        for i in range(n_run):
            ents.append({"pos": (x + i + 0.5, top + 0.5), "layers": WL.level_layers(lv, "droit", res_db=db)})
        ents.append({"pos": (x + n_run + 1 + 0.5, top + 0.5), "layers": WL.level_layers(lv, "isole", res_db=db)})
        x += n_run + 2 + gap
    W = x
    day, night = maquette.compose(WL.DATA, os.path.join(WL.DATA, "core"), ents, W, top + bottom)
    return day, night, starts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("levels")
    ap.add_argument("--x", type=int, default=2)
    ap.add_argument("--tag", default="")
    a = ap.parse_args()
    levels = [int(v) for v in a.levels.split(",")]
    db = WL.results()
    day, night, starts = compose_levels(levels, db)
    out = os.path.join(WL.OUT, "apercu")
    os.makedirs(out, exist_ok=True)
    tag = a.tag or "-".join(str(v) for v in levels)
    for name, rgb in (("jour", day), ("nuit", night)):
        im = Image.fromarray(np.clip(np.round(rgb * 255), 0, 255).astype(np.uint8), "RGB")
        d = ImageDraw.Draw(im)
        for lv, x in zip(levels, starts):
            d.text((int(x * 64) + 2, 2), "N%d" % lv, fill=(255, 240, 200))
        im = im.resize((im.width * a.x, im.height * a.x), Image.NEAREST)
        p = os.path.join(out, "z2-%s-%s.png" % (tag, name))
        im.save(p)
        print(p)


if __name__ == "__main__":
    main()
