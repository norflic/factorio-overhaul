"""Inspection de travail (lot V3-E) : le canon du haut de chaque tête, sur fond terre, agrandi, empilés.

    py -3.9 tools/render/pieces/levels/gun_e_haut/inspecte.py [E|N] [facteur] [variante-suffixe]
Sortie : <travail>/apercus/canons-<pose>.png
"""
import os
import sys

from PIL import Image

W = os.environ.get("FO_IND_WORK", "H:/Factorio.v1.1.91 Modding/Factorio.v1.1.91/fo-logs/2026-10-22_V3E/haut")


def main():
    pose = sys.argv[1] if len(sys.argv) > 1 else "E"
    k = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    tiles = []
    for e in range(10, 16):
        p = os.path.join(W, "out", "e%02d-tete-%s" % (e, pose), "hr-gune-e%02d-tete-%s-main.png" % (e, pose))
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        bg = Image.new("RGBA", im.size, (126, 84, 52, 255))
        bg.alpha_composite(im)
        c = bg.crop((0, 0, im.width, int(im.height * 0.42))) if pose == "E" else bg.crop((0, 0, im.width // 2,
                                                                                          int(im.height * 0.75)))
        tiles.append(c.resize((c.width * k, c.height * k), Image.LANCZOS))
    if pose == "E":
        sheet = Image.new("RGB", (max(t.width for t in tiles), sum(t.height for t in tiles)), (30, 30, 30))
        y = 0
        for t in tiles:
            sheet.paste(t, (0, y))
            y += t.height
    else:
        sheet = Image.new("RGB", (sum(t.width for t in tiles), max(t.height for t in tiles)), (30, 30, 30))
        x = 0
        for t in tiles:
            sheet.paste(t, (x, 0))
            x += t.width
    os.makedirs(os.path.join(W, "apercus"), exist_ok=True)
    out = os.path.join(W, "apercus", "canons-%s.png" % pose)
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
