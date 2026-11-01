"""Icônes du raccourci « Armée » (lot RB-2) : une tête de robot (boîte arrondie, deux yeux, antenne, oreilles).

Même format et mêmes couleurs que tools/gui/icones_ia1i.py (barre de raccourcis du jeu de base) :
    robot-x32.png, robot-x32-white.png : 48 x 32 (32 px + mipmap 16 px), mipmap_count = 2 ;
    robot-x24.png, robot-x24-white.png : 36 x 24 (24 px + mipmap 12 px).
Dessin à 512 px puis réduction LANCZOS. Usage : py -3.9 tools/gui/icones_robots.py [dossier]
"""
import os
import sys

from PIL import Image, ImageDraw

DARK = (29, 28, 29)
WHITE = (226, 227, 226)
BIG = 512


def glyph(color):
    im = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = color + (255,)
    # Antenne : tige et boule.
    d.rectangle([BIG * 0.47, BIG * 0.10, BIG * 0.53, BIG * 0.27], fill=c)
    d.ellipse([BIG * 0.42, BIG * 0.04, BIG * 0.58, BIG * 0.20], fill=c)
    # Oreilles.
    d.rounded_rectangle([BIG * 0.06, BIG * 0.44, BIG * 0.17, BIG * 0.68], radius=BIG * 0.03, fill=c)
    d.rounded_rectangle([BIG * 0.83, BIG * 0.44, BIG * 0.94, BIG * 0.68], radius=BIG * 0.03, fill=c)
    # Tête.
    d.rounded_rectangle([BIG * 0.16, BIG * 0.26, BIG * 0.84, BIG * 0.86], radius=BIG * 0.09, fill=c)
    # Yeux et bouche en creux (transparents).
    hole = Image.new("L", (BIG, BIG), 0)
    hd = ImageDraw.Draw(hole)
    hd.rounded_rectangle([BIG * 0.27, BIG * 0.39, BIG * 0.42, BIG * 0.54], radius=BIG * 0.03, fill=255)
    hd.rounded_rectangle([BIG * 0.58, BIG * 0.39, BIG * 0.73, BIG * 0.54], radius=BIG * 0.03, fill=255)
    hd.rounded_rectangle([BIG * 0.32, BIG * 0.66, BIG * 0.68, BIG * 0.74], radius=BIG * 0.02, fill=255)
    im.putalpha(Image.composite(Image.new("L", (BIG, BIG), 0), im.getchannel("A"), hole))
    return im


def sheet(color, size):
    g = glyph(color)
    out = Image.new("RGBA", (size + size // 2, size), (0, 0, 0, 0))
    out.paste(g.resize((size, size), Image.LANCZOS), (0, 0))
    out.paste(g.resize((size // 2, size // 2), Image.LANCZOS), (size, 0))
    return out


def main():
    dest = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "graphics", "gui")
    os.makedirs(dest, exist_ok=True)
    for size in (32, 24):
        for suffix, color in (("", DARK), ("-white", WHITE)):
            path = os.path.join(dest, "robot-x%d%s.png" % (size, suffix))
            sheet(color, size).save(path)
            print("[FO-RB-ICONES] %s" % os.path.normpath(path))


if __name__ == "__main__":
    main()
