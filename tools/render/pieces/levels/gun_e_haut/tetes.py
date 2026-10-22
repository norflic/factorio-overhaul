"""Aperçu de travail (lot V3-E) : une partie des 6 époques côte à côte, sur fond terre, hr (zoom 2) ou lr (zoom 1,
agrandi 2× au plus proche pour la lecture).

    py -3.9 tools/render/pieces/levels/gun_e_haut/tetes.py <tete-E|tete-N|socle|socle-piece> <sortie.png> [--lr]
Sortie : <travail>/apercus/<sortie.png>.
"""
import os
import sys

from PIL import Image

W = os.environ.get("FO_IND_WORK", "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-22_V3E/haut")


def main():
    part, out = sys.argv[1], sys.argv[2]
    lr = "--lr" in sys.argv
    tiles = []
    for e in range(10, 16):
        nm = "e%02d-%s" % (e, part)
        fn = ("gune-%s-main.png" if lr else "hr-gune-%s-main.png") % nm
        p = os.path.join(W, "out", nm, fn)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        bg = Image.new("RGBA", im.size, (122, 82, 50, 255))
        bg.alpha_composite(im)
        if lr:
            bg = bg.resize((bg.width * 2, bg.height * 2), Image.NEAREST)
        tiles.append(bg)
    sheet = Image.new("RGB", (sum(t.width for t in tiles) + 10 * len(tiles), max(t.height for t in tiles)),
                      (25, 25, 25))
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0))
        x += t.width + 10
    os.makedirs(os.path.join(W, "apercus"), exist_ok=True)
    sheet.save(os.path.join(W, "apercus", out))
    print(out, sheet.size)


if __name__ == "__main__":
    main()
