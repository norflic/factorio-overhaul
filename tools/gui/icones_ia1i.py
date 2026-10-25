"""Icônes du raccourci « Équipe et factions » (lot IA1-i) : trois silhouettes (une devant, deux derrière).

Même format que les icônes de la barre de raccourcis du jeu de base (base/graphics/icons/shortcut-toolbar/mip) :
    team-x32.png, team-x32-white.png : 48 x 32 (32 px + mipmap 16 px), mipmap_count = 2 ;
    team-x24.png, team-x24-white.png : 36 x 24 (24 px + mipmap 12 px).
Couleurs relevées sur toggle-personal-roboport-x32*.png : sombre (29, 28, 29), clair (226, 227, 226).
Dessin à 512 px puis réduction LANCZOS (bords lissés). Usage : py -3.9 tools/gui/icones_ia1i.py [dossier]
"""
import os
import sys

from PIL import Image, ImageDraw

DARK = (29, 28, 29)
WHITE = (226, 227, 226)
BIG = 512


def silhouette(draw, cx, top, s, fill):
    """Tête (disque) et épaules (demi-ovale) d'une personne, centrée en cx, haut de tête en top, échelle s."""
    r = 0.16 * s
    draw.ellipse([cx - r, top, cx + r, top + 2 * r], fill=fill)
    w = 0.34 * s
    y0 = top + 2 * r + 0.05 * s
    draw.chord([cx - w, y0, cx + w, y0 + 0.62 * s], 180, 360, fill=fill)
    draw.rectangle([cx - w, y0 + 0.31 * s - 1, cx + w, y0 + 0.36 * s], fill=fill)


def glyph(color):
    im = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = BIG * 0.62
    # Deux silhouettes derrière, puis un liseré transparent et la silhouette de devant.
    silhouette(d, BIG * 0.27, BIG * 0.14, s * 0.82, color + (255,))
    silhouette(d, BIG * 0.73, BIG * 0.14, s * 0.82, color + (255,))
    halo = Image.new("L", (BIG, BIG), 0)
    hd = ImageDraw.Draw(halo)
    silhouette(hd, BIG * 0.5, BIG * 0.27 - BIG * 0.035, s * 1.12, 255)
    im.putalpha(Image.composite(Image.new("L", (BIG, BIG), 0), im.getchannel("A"), halo))
    d = ImageDraw.Draw(im)
    silhouette(d, BIG * 0.5, BIG * 0.27, s, color + (255,))
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
            path = os.path.join(dest, "team-x%d%s.png" % (size, suffix))
            sheet(color, size).save(path)
            print("[FO-IA1I-ICONES] %s" % os.path.normpath(path))


if __name__ == "__main__":
    main()
