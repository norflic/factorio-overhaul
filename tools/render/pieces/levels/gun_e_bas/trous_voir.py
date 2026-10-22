"""Planche de diagnostic des trous enfermés (lot V3-E) : pour chaque image de diagnostic de trous.py (trous en
rouge, ×3), un recadrage autour de chaque groupe de plus de 8 px hr, avec sa position en tuiles depuis l'origine.

    py -3.9 trous_voir.py <dossier diag> <sortie.png>
"""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compo as K  # noqa: E402


def main():
    src, dst = sys.argv[1:3]
    tiles = []
    for p in sorted(glob.glob(os.path.join(src, "trous-*.png"))):
        im = Image.open(p).convert("RGB")
        a = np.asarray(im)
        red = (a[..., 0] == 255) & (a[..., 1] == 0) & (a[..., 2] == 0)
        sizes, lab = K.D.components(red, conn8=True)
        for k, s in sorted(sizes.items(), key=lambda kv: -kv[1]):
            if s < 9 * 9:  # 8 px hr = 72 px à ×3 (on montre les groupes en échec)
                continue
            ys, xs = np.nonzero(lab == k)
            cy, cx = int(ys.mean()), int(xs.mean())
            box = (max(0, cx - 90), max(0, cy - 90), min(im.size[0], cx + 90), min(im.size[1], cy + 90))
            t = im.crop(box).resize((360, 360), Image.NEAREST)
            d = ImageDraw.Draw(t)
            d.text((4, 4), "%s (%d,%d) %d px hr" % (os.path.basename(p)[6:-4], cx // 3, cy // 3, s // 9),
                   fill=(255, 255, 0))
            tiles.append(t)
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 364, max(1, rows) * 364), (0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * 364, (i // cols) * 364))
    sheet.save(dst)
    print(dst, len(tiles))


if __name__ == "__main__":
    main()
